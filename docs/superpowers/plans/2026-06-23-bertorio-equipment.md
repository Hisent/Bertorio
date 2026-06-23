# Bertorio Equipment Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pickaxe mining-speed bonus apply only while a pickaxe is equipped in a character-screen GUI slot, instead of merely carried in the inventory.

**Architecture:** A new `equipment` feature owns the equip state, the relative-GUI slot (a `choose-elem-button` anchored to the controller screen), and the force mining-speed modifier. The existing `pickaxe` feature is refactored down to items/recipes/drops only — its inventory-scan modifier logic moves to `equipment`. Shared tier math stays in `features/pickaxe/logic.lua` and is reused.

**Tech Stack:** Lua, Factorio 2.0 modding API (`player.gui.relative`, `choose-elem-button`, `storage`, `event_handler`). Dev tool: standalone `lua` at `~/AppData/Local/Programs/Lua/bin/lua.exe` for parse checks.

## Global Constraints

- `factorio_version` is `"2.0"`; target build 2.0.77.
- Prototype names prefixed `bertorio-`; pickaxe items are `bertorio-pickaxe-1|2|3`.
- Speed via `force.manual_mining_speed_modifier`, set **absolutely** (force-wide; per-player not in scope). `ponytail:` comment notes the clobber.
- Tier→modifier: T1=`1.0`, T2=`2.0`, T3=`3.0`, none=`0.0` (via `logic.modifier_for`).
- Bonus applies **only** when equipped in the slot; inventory presence no longer grants it.
- Equip/unequip moves are balanced: remove 1 from inventory on equip, insert 1 back on unequip/switch — no net item gain/loss.
- Every feature ships both `data.lua` and `control.lua` (empty stub allowed). Loaders `require` them directly.
- Lua parse check: `"/c/Users/zaK/AppData/Local/Programs/Lua/bin/lua.exe" -e "assert(loadfile('PATH'))"`.

---

### Task 1: Refactor `pickaxe` feature to drops-only

Remove the inventory-scan + modifier logic from the pickaxe control stage; it
now only handles ore-mining material drops. The modifier moves to `equipment`
(Task 2).

**Files:**
- Modify (replace whole file): `features/pickaxe/control.lua`

**Interfaces:**
- Produces: the `pickaxe` control lib now exposes only `events =
  { [on_player_mined_entity] = ... }` (no `on_init`, no modifier).
- `features/pickaxe/logic.lua` is unchanged and remains the home of
  `tier_of`, `modifier_for`, `max_tier` (consumed by Task 2).

- [ ] **Step 1: Replace `features/pickaxe/control.lua`**

```lua
-- Pickaxe feature: ore-mining material drops only.
-- The mining-speed modifier lives in the `equipment` feature.
local function on_mined(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.type == "resource") then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local c1 = settings.global["bertorio-drop-chance-mat1"].value
  local c2 = settings.global["bertorio-drop-chance-mat2"].value
  if math.random() < c1 then
    player.insert({ name = "bertorio-upgrade-material-1", count = 1 })
  end
  if math.random() < c2 then
    player.insert({ name = "bertorio-upgrade-material-2", count = 1 })
  end
end

return {
  events = {
    [defines.events.on_player_mined_entity] = on_mined,
  },
}
```

- [ ] **Step 2: Parse-check**

Run: `"/c/Users/zaK/AppData/Local/Programs/Lua/bin/lua.exe" -e "assert(loadfile('features/pickaxe/control.lua'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add features/pickaxe/control.lua
git commit -m "refactor(pickaxe): drops-only; modifier moves to equipment feature"
```

---

### Task 2: `equipment` feature — GUI slot, equip state, modifier

**Files:**
- Create: `features/equipment/data.lua` (empty stub)
- Create: `features/equipment/control.lua`
- Modify: `features.lua` (add `"equipment"`)

**Interfaces:**
- Consumes: `features.pickaxe.logic` (`tier_of(name)->tier|nil`,
  `modifier_for(tier|nil)->number`, `max_tier(tiers[])->number`); pickaxe item
  names `bertorio-pickaxe-1|2|3`; locale keys `bertorio.equip-title`,
  `bertorio.equip-missing` (Task 3).
- Produces: `storage.equipped` table `{ [player_index] = tier }`; an
  `event_handler` lib with `on_init`, `on_configuration_changed`, and `events`
  for `on_player_created`, `on_player_joined_game`, `on_gui_elem_changed`.

- [ ] **Step 1: Create `features/equipment/data.lua` (stub)**

```lua
-- Equipment feature has no prototypes; it adds a GUI + control logic only.
```

- [ ] **Step 2: Create `features/equipment/control.lua`**

```lua
local logic = require("features.pickaxe.logic")

local FRAME = "bertorio-equip-frame"
local BUTTON = "bertorio-equip-button"
local TIER_ITEMS = { "bertorio-pickaxe-1", "bertorio-pickaxe-2", "bertorio-pickaxe-3" }

local function item_for_tier(tier)
  return tier and TIER_ITEMS[tier] or nil
end

-- Build (or rebuild) the relative GUI slot for one player. Idempotent.
local function build_gui(player)
  if not player then return end
  local rel = player.gui.relative
  if rel[FRAME] then rel[FRAME].destroy() end
  local frame = rel.add({
    type = "frame",
    name = FRAME,
    caption = { "bertorio.equip-title" },
    anchor = {
      gui = defines.relative_gui_type.controller_gui,
      position = defines.relative_gui_position.right,
    },
  })
  local inner = frame.add({ type = "flow", direction = "vertical" })
  local btn = inner.add({
    type = "choose-elem-button",
    name = BUTTON,
    elem_type = "item",
    elem_filters = { { filter = "name", name = TIER_ITEMS } },
  })
  btn.elem_value = item_for_tier(storage.equipped[player.index])
end

local function build_all()
  for _, player in pairs(game.players) do build_gui(player) end
end

-- Force-wide modifier from the highest EQUIPPED tier across the force's players.
-- ponytail: set absolutely, clobbering other mods writing the same modifier.
local function recompute_force(force)
  if not (force and force.valid) then return end
  local tiers = {}
  for _, player in pairs(force.players) do
    local t = storage.equipped[player.index]
    if t then tiers[#tiers + 1] = t end
  end
  force.manual_mining_speed_modifier = logic.modifier_for(logic.max_tier(tiers))
end

local function recompute_all()
  for _, force in pairs(game.forces) do recompute_force(force) end
end

local function setup()
  storage.equipped = storage.equipped or {}
  build_all()
  recompute_all()
end

local function on_player_setup(event)
  storage.equipped = storage.equipped or {}
  build_gui(game.get_player(event.player_index))
end

local function on_elem_changed(event)
  if event.element.name ~= BUTTON then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  storage.equipped = storage.equipped or {}
  local idx = player.index
  local inv = player.get_main_inventory()
  local chosen = event.element.elem_value -- item name or nil
  local old_tier = storage.equipped[idx]

  -- Unequip: return previously equipped pickaxe to inventory.
  if chosen == nil then
    if old_tier and inv then
      inv.insert({ name = item_for_tier(old_tier), count = 1 })
    end
    storage.equipped[idx] = nil
    recompute_force(player.force)
    return
  end

  local new_tier = logic.tier_of(chosen)
  if not new_tier then
    event.element.elem_value = item_for_tier(old_tier)
    return
  end
  if new_tier == old_tier then return end

  -- Must own the chosen pickaxe to equip it.
  if not inv or inv.get_item_count(chosen) < 1 then
    event.element.elem_value = item_for_tier(old_tier)
    player.print({ "bertorio.equip-missing" })
    return
  end

  -- Return the old one, consume the new one.
  if old_tier then inv.insert({ name = item_for_tier(old_tier), count = 1 }) end
  inv.remove({ name = chosen, count = 1 })
  storage.equipped[idx] = new_tier
  recompute_force(player.force)
end

return {
  on_init = setup,
  on_configuration_changed = setup,
  events = {
    [defines.events.on_player_created] = on_player_setup,
    [defines.events.on_player_joined_game] = on_player_setup,
    [defines.events.on_gui_elem_changed] = on_elem_changed,
  },
}
```

- [ ] **Step 3: Register the feature in `features.lua`**

```lua
-- Active features. Dock a new feature: create features/<name>/{data,control}.lua
-- and add "<name>" here.
return { "pickaxe", "equipment", "cheat" }
```

- [ ] **Step 4: Parse-check all three files**

```bash
LUA="/c/Users/zaK/AppData/Local/Programs/Lua/bin/lua.exe"
for f in features.lua features/equipment/data.lua features/equipment/control.lua; do
  "$LUA" -e "assert(loadfile('$f'))" && echo "$f OK"
done
```
Expected: each prints `... OK`.

- [ ] **Step 5: Commit**

```bash
git add features.lua features/equipment/data.lua features/equipment/control.lua
git commit -m "feat(equipment): character-screen equip slot drives mining-speed bonus"
```

---

### Task 3: Locale for the equip GUI

**Files:**
- Modify: `locale/en/bertorio.cfg`
- Modify: `locale/de/bertorio.cfg`

**Interfaces:**
- Produces locale keys `bertorio.equip-title` and `bertorio.equip-missing`
  consumed by Task 2.

- [ ] **Step 1: Append a `[bertorio]` section to `locale/en/bertorio.cfg`**

Add at end of file:
```ini

[bertorio]
equip-title=Pickaxe
equip-missing=You don't have that pickaxe in your inventory.
```

- [ ] **Step 2: Append a `[bertorio]` section to `locale/de/bertorio.cfg`**

Add at end of file:
```ini

[bertorio]
equip-title=Spitzhacke
equip-missing=Du hast diese Spitzhacke nicht im Inventar.
```

- [ ] **Step 3: Verify both files contain both keys**

```bash
for f in locale/en/bertorio.cfg locale/de/bertorio.cfg; do
  printf "%s: " "$f"; grep -c "^equip-" "$f"
done
```
Expected: each prints `2`.

- [ ] **Step 4: Commit**

```bash
git add locale/en/bertorio.cfg locale/de/bertorio.cfg
git commit -m "feat(equipment): en/de locale for equip slot"
```

---

### Task 4: In-game smoke test + README update

Verify the whole feature in Factorio 2.0.77 and document it.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rebuild the mod zip and copy it into Factorio's mods folder**

```bash
SCRATCH="/c/Users/zaK/AppData/Local/Temp/claude/e--Programmierung/37ef6b94-f2fe-438e-a340-4b5414b54086/scratchpad"
STAGE="$SCRATCH/bertorio"
# refresh changed files in the staging tree
cp features.lua "$STAGE/"
cp features/pickaxe/control.lua "$STAGE/features/pickaxe/"
mkdir -p "$STAGE/features/equipment"
cp features/equipment/*.lua "$STAGE/features/equipment/"
cp locale/en/bertorio.cfg "$STAGE/locale/en/"
cp locale/de/bertorio.cfg "$STAGE/locale/de/"
```
Then (PowerShell):
```powershell
$s="C:\Users\zaK\AppData\Local\Temp\claude\e--Programmierung\37ef6b94-f2fe-438e-a340-4b5414b54086\scratchpad"
Compress-Archive -Path "$s\bertorio" -DestinationPath "$s\bertorio_0.1.0.zip" -Force
Copy-Item "$s\bertorio_0.1.0.zip" "$env:APPDATA\Factorio\mods\bertorio_0.1.0.zip" -Force
```

- [ ] **Step 2: Launch Factorio, confirm load**

No error dialog; `Bertorio 0.1.0` enabled.

- [ ] **Step 3: Manual checklist (record in commit message)**

1. `/bertorio-cheat`, craft `Pickaxe Mk1`.
2. Open character screen (`E`) → "Spitzhacke" frame visible on the right.
3. Click the slot → pick Mk1 → Mk1 leaves the inventory; hand-mine ore ≈ 2×.
4. Switch the slot to Mk2 (craft it first) → Mk1 returns to inventory, Mk2 leaves; mining ≈ 3×. Mk3 → ≈ 4×.
5. Clear the slot → pickaxe returns to inventory; mining back to normal.
6. With an empty inventory of Mk3, select Mk3 in the slot → button reverts, hint printed, no item gained.

- [ ] **Step 4: Update `README.md`**

Replace the `## Features` pickaxe bullet and add an equip note:
```markdown
## Features

- **Pickaxe** — craft `Pickaxe Mk1` (10 iron plates); upgrade to Mk2 / Mk3
  using Alloy / Crystal that drop while hand-mining ore.
- **Equip slot** — open the character screen (`E`); a "Pickaxe" slot appears on
  the right. Equip a pickaxe there to gain its mining-speed bonus
  (Mk1 2×, Mk2 3×, Mk3 4×). Equipping takes the pickaxe out of your inventory;
  the bonus is force-wide and applies only while equipped.
- **`/bertorio-cheat`** — gives a test kit (100 iron plates + 50/50 upgrade
  materials). Disables achievements (vanilla console-command behavior).
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: README equip-slot feature + smoke-test results"
```
