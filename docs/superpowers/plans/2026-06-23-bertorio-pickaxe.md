# Bertorio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Factorio 2.0 mod that provides a feature-docking framework plus a craftable, 3-tier hand-mining pickaxe whose upgrade materials drop while mining ore.

**Architecture:** A feature registry (`features.lua`) lists active features; `data.lua` and `control.lua` loop it and load each feature's stage file. Control-stage event composition uses Factorio's native `__core__/lualib/event_handler`. The pickaxe feature lives entirely under `features/pickaxe/`, with pure logic split into a standalone-testable `logic.lua`.

**Tech Stack:** Lua, Factorio 2.0 modding API. Optional dev tool: standalone `lua` (for `logic.lua` tests + syntax checks).

## Global Constraints

- `factorio_version` is `"2.0"`; target build 2.0.77; dependency `base >= 2.0.0`.
- No runtime dependencies beyond `base` and `__core__` lualibs.
- All mod-defined prototype names are prefixed `bertorio-`.
- Speed comes from `force.manual_mining_speed_modifier`, set **absolutely** (force-wide; per-player speed is not in scope).
- Tier→modifier: T1=`1.0` (2×), T2=`2.0` (3×), T3=`3.0` (4×), none=`0.0`.
- Material drops only on hand-mining resources (`on_player_mined_entity`, `entity.type == "resource"`).
- Recipes are enabled from game start (no research gating).
- Every feature ships **both** `data.lua` and `control.lua` (an unused stage is an empty stub). Loaders `require` them directly — no optional/pcall loading.

---

### Task 1: Pure logic module + standalone test

**Files:**
- Create: `features/pickaxe/logic.lua`
- Test: `features/pickaxe/test_logic.lua`

**Interfaces:**
- Produces:
  - `logic.TIER_BY_ITEM` — table mapping pickaxe item name → tier int.
  - `logic.tier_of(item_name: string) -> integer|nil`
  - `logic.modifier_for(tier: integer|nil) -> number` (0 when nil/0)
  - `logic.max_tier(tiers: integer[]) -> integer` (0 for empty dense list)

**Dev-tool note:** running the test needs standalone `lua`. If missing:
`winget install --id DEVCOM.Lua -e` then open a NEW shell (PATH update). If
`lua` still cannot be installed, skip the run steps — the logic is small and is
also exercised in-game in Task 6 — but still author the test file.

- [ ] **Step 1: Write the failing test**

`features/pickaxe/test_logic.lua`:
```lua
-- Run from features/pickaxe/:  lua test_logic.lua
local logic = require("logic")

assert(logic.tier_of("bertorio-pickaxe-1") == 1)
assert(logic.tier_of("bertorio-pickaxe-2") == 2)
assert(logic.tier_of("bertorio-pickaxe-3") == 3)
assert(logic.tier_of("iron-plate") == nil)

assert(logic.modifier_for(0) == 0)
assert(logic.modifier_for(1) == 1)
assert(logic.modifier_for(3) == 3)
assert(logic.modifier_for(nil) == 0)

assert(logic.max_tier({}) == 0)
assert(logic.max_tier({1}) == 1)
assert(logic.max_tier({1, 3, 2}) == 3)
assert(logic.max_tier({2, 2}) == 2)

print("logic.lua: all asserts passed")
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `cd features/pickaxe && lua test_logic.lua`
Expected: FAIL — `module 'logic' not found` (file not created yet).

- [ ] **Step 3: Write the implementation**

`features/pickaxe/logic.lua`:
```lua
-- Pure helpers, no Factorio API. Standalone-unit-testable (see test_logic.lua).
local logic = {}

-- pickaxe item name -> tier
logic.TIER_BY_ITEM = {
  ["bertorio-pickaxe-1"] = 1,
  ["bertorio-pickaxe-2"] = 2,
  ["bertorio-pickaxe-3"] = 3,
}

function logic.tier_of(item_name)
  return logic.TIER_BY_ITEM[item_name]
end

-- tier value doubles as the manual_mining_speed_modifier (T1->+1.0 = 2x ...)
function logic.modifier_for(tier)
  return tier or 0
end

-- highest tier in a dense list (no nil holes); 0 if empty
function logic.max_tier(tiers)
  local best = 0
  for _, t in ipairs(tiers) do
    if t > best then best = t end
  end
  return best
end

return logic
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `cd features/pickaxe && lua test_logic.lua`
Expected: PASS — prints `logic.lua: all asserts passed`.

- [ ] **Step 5: Commit**

```bash
git add features/pickaxe/logic.lua features/pickaxe/test_logic.lua
git commit -m "feat(pickaxe): pure tier/modifier logic + standalone test"
```

---

### Task 2: Mod manifest + framework loaders + settings

**Files:**
- Create: `info.json`
- Create: `features.lua`
- Create: `data.lua`
- Create: `control.lua`
- Create: `settings.lua`

**Interfaces:**
- Produces:
  - `features.lua` returns a string array of active feature names, e.g. `{ "pickaxe" }`.
  - `data.lua` / `control.lua` iterate that array and `require("features." .. name .. ".data" | ".control")`.
  - Settings `bertorio-drop-chance-mat1` (default `0.02`) and `bertorio-drop-chance-mat2` (default `0.005`), both `runtime-global` doubles.
- Consumes (at load time, provided by Tasks 3 & 4): `features/pickaxe/data.lua` and `features/pickaxe/control.lua`.

**Note:** Standalone `lua` can syntax-check these files via `loadfile` (parse
only, does not execute), but they cannot fully load outside Factorio
(`data:extend`, `require("__core__...")`, `defines` are game globals). Full load
is verified in Factorio in Task 6.

- [ ] **Step 1: Create `info.json`**

```json
{
  "name": "bertorio",
  "version": "0.1.0",
  "title": "Bertorio",
  "author": "zaK",
  "factorio_version": "2.0",
  "dependencies": ["base >= 2.0.0"]
}
```

- [ ] **Step 2: Create `features.lua`**

```lua
-- Active features. Dock a new feature: create features/<name>/{data,control}.lua
-- and add "<name>" here.
return { "pickaxe" }
```

- [ ] **Step 3: Create `data.lua`**

```lua
local features = require("features")
for _, name in ipairs(features) do
  require("features." .. name .. ".data")
end
```

- [ ] **Step 4: Create `control.lua`**

```lua
local handler = require("__core__.lualib.event_handler")
local features = require("features")

local libs = {}
for _, name in ipairs(features) do
  libs[#libs + 1] = require("features." .. name .. ".control")
end
handler.add_libraries(libs)
```

- [ ] **Step 5: Create `settings.lua`**

```lua
data:extend({
  {
    type = "double-setting",
    name = "bertorio-drop-chance-mat1",
    setting_type = "runtime-global",
    default_value = 0.02,
    minimum_value = 0,
    maximum_value = 1,
    order = "a",
  },
  {
    type = "double-setting",
    name = "bertorio-drop-chance-mat2",
    setting_type = "runtime-global",
    default_value = 0.005,
    minimum_value = 0,
    maximum_value = 1,
    order = "b",
  },
})
```

- [ ] **Step 6: Validate JSON + Lua syntax**

Run: `node -e "JSON.parse(require('fs').readFileSync('info.json','utf8')); console.log('info.json OK')"`
Expected: `info.json OK`

If `lua` is available, run (parse-only, expect no output / no error):
```bash
for f in features.lua settings.lua; do lua -e "assert(loadfile('$f'))" && echo "$f OK"; done
```
Expected: `features.lua OK` and `settings.lua OK`.
(`data.lua`/`control.lua` reference game globals only at runtime, so `loadfile` parse also succeeds: `lua -e "assert(loadfile('data.lua'))" && echo data.lua OK`.)

- [ ] **Step 7: Commit**

```bash
git add info.json features.lua data.lua control.lua settings.lua
git commit -m "feat: mod manifest, feature-loader framework, drop-chance settings"
```

---

### Task 3: Pickaxe data stage (items + recipes)

**Files:**
- Create: `features/pickaxe/data.lua`

**Interfaces:**
- Produces these prototypes (consumed at runtime by Task 4 and by the player):
  - items: `bertorio-pickaxe-1`, `bertorio-pickaxe-2`, `bertorio-pickaxe-3`, `bertorio-upgrade-material-1`, `bertorio-upgrade-material-2`
  - recipes: `bertorio-pickaxe-1` (10 iron-plate), `bertorio-pickaxe-2` (pickaxe-1 + 10 material-1), `bertorio-pickaxe-3` (pickaxe-2 + 10 material-2)

**Note:** Icons reuse existing `__base__` icons (guaranteed present in 2.0) to
avoid shipping art. All recipes `enabled = true`.

- [ ] **Step 1: Create `features/pickaxe/data.lua`**

```lua
local function item(name, icon)
  return {
    type = "item",
    name = name,
    icon = "__base__/graphics/icons/" .. icon,
    icon_size = 64,
    stack_size = 50,
    subgroup = "intermediate-product",
    order = name,
  }
end

data:extend({
  -- pickaxe tiers (inventory tokens; reuse repair-pack icon)
  item("bertorio-pickaxe-1", "repair-pack.png"),
  item("bertorio-pickaxe-2", "repair-pack.png"),
  item("bertorio-pickaxe-3", "repair-pack.png"),
  -- upgrade materials
  item("bertorio-upgrade-material-1", "advanced-circuit.png"),
  item("bertorio-upgrade-material-2", "processing-unit.png"),

  -- recipes (available from start)
  {
    type = "recipe",
    name = "bertorio-pickaxe-1",
    enabled = true,
    ingredients = { { type = "item", name = "iron-plate", amount = 10 } },
    results = { { type = "item", name = "bertorio-pickaxe-1", amount = 1 } },
  },
  {
    type = "recipe",
    name = "bertorio-pickaxe-2",
    enabled = true,
    ingredients = {
      { type = "item", name = "bertorio-pickaxe-1", amount = 1 },
      { type = "item", name = "bertorio-upgrade-material-1", amount = 10 },
    },
    results = { { type = "item", name = "bertorio-pickaxe-2", amount = 1 } },
  },
  {
    type = "recipe",
    name = "bertorio-pickaxe-3",
    enabled = true,
    ingredients = {
      { type = "item", name = "bertorio-pickaxe-2", amount = 1 },
      { type = "item", name = "bertorio-upgrade-material-2", amount = 10 },
    },
    results = { { type = "item", name = "bertorio-pickaxe-3", amount = 1 } },
  },
})
```

- [ ] **Step 2: Syntax-check + verify prototype names present**

If `lua` available: `lua -e "assert(loadfile('features/pickaxe/data.lua'))" && echo "data.lua parses"`
Expected: `data.lua parses`

Always: confirm the five item names and three recipe names appear:
```bash
grep -c "bertorio-pickaxe-[123]\|bertorio-upgrade-material-[12]" features/pickaxe/data.lua
```
Expected: a count `>= 8` (5 item defs + 3 recipe names + ingredient refs).

- [ ] **Step 3: Commit**

```bash
git add features/pickaxe/data.lua
git commit -m "feat(pickaxe): items + tiered upgrade recipes"
```

---

### Task 4: Pickaxe control stage (events)

**Files:**
- Create: `features/pickaxe/control.lua`

**Interfaces:**
- Consumes: `features/pickaxe/logic.lua` (`logic.TIER_BY_ITEM`, `logic.tier_of`, `logic.modifier_for`, `logic.max_tier`).
- Produces: an `event_handler` library table with `on_init`, `on_configuration_changed`, and `events` for `on_player_main_inventory_changed`, `on_player_joined_game`, `on_player_mined_entity`.

**Note:** `on_player_left_game` is intentionally omitted — a leaving player's
inventory persists and is still counted, so leaving changes nothing. Recompute
is driven by inventory changes and joins.

- [ ] **Step 1: Create `features/pickaxe/control.lua`**

```lua
local logic = require("features.pickaxe.logic")

-- Recompute the force-wide mining-speed modifier from the highest pickaxe tier
-- currently held by any player of the force.
-- ponytail: modifier is set ABSOLUTELY, clobbering other mods that write the
-- same force modifier. Acceptable for now; track a delta if a conflict appears.
local function recompute_force(force)
  if not (force and force.valid) then return end
  local tiers = {}
  for _, player in pairs(force.players) do
    local inv = player.get_main_inventory()
    if inv then
      for item_name in pairs(logic.TIER_BY_ITEM) do
        if inv.get_item_count(item_name) > 0 then
          tiers[#tiers + 1] = logic.tier_of(item_name)
        end
      end
    end
  end
  force.manual_mining_speed_modifier = logic.modifier_for(logic.max_tier(tiers))
end

local function recompute_for_player(player_index)
  local player = game.get_player(player_index)
  if player then recompute_force(player.force) end
end

local function recompute_all()
  for _, force in pairs(game.forces) do recompute_force(force) end
end

local function on_inventory_changed(event)
  recompute_for_player(event.player_index)
end

local function on_joined(event)
  recompute_for_player(event.player_index)
end

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
  on_init = recompute_all,
  on_configuration_changed = recompute_all,
  events = {
    [defines.events.on_player_main_inventory_changed] = on_inventory_changed,
    [defines.events.on_player_joined_game] = on_joined,
    [defines.events.on_player_mined_entity] = on_mined,
  },
}
```

- [ ] **Step 2: Syntax-check**

If `lua` available: `lua -e "assert(loadfile('features/pickaxe/control.lua'))" && echo "control.lua parses"`
Expected: `control.lua parses`

- [ ] **Step 3: Commit**

```bash
git add features/pickaxe/control.lua
git commit -m "feat(pickaxe): inventory-driven mining-speed modifier + material drops"
```

---

### Task 5: Locale

**Files:**
- Create: `locale/en/bertorio.cfg`
- Create: `locale/de/bertorio.cfg`

- [ ] **Step 1: Create `locale/en/bertorio.cfg`**

```ini
[item-name]
bertorio-pickaxe-1=Pickaxe Mk1
bertorio-pickaxe-2=Pickaxe Mk2
bertorio-pickaxe-3=Pickaxe Mk3
bertorio-upgrade-material-1=Pickaxe Alloy
bertorio-upgrade-material-2=Pickaxe Crystal

[recipe-name]
bertorio-pickaxe-1=Pickaxe Mk1
bertorio-pickaxe-2=Pickaxe Mk2
bertorio-pickaxe-3=Pickaxe Mk3

[mod-setting-name]
bertorio-drop-chance-mat1=Pickaxe Alloy drop chance (per ore mined)
bertorio-drop-chance-mat2=Pickaxe Crystal drop chance (per ore mined)
```

- [ ] **Step 2: Create `locale/de/bertorio.cfg`**

```ini
[item-name]
bertorio-pickaxe-1=Spitzhacke Mk1
bertorio-pickaxe-2=Spitzhacke Mk2
bertorio-pickaxe-3=Spitzhacke Mk3
bertorio-upgrade-material-1=Spitzhacken-Legierung
bertorio-upgrade-material-2=Spitzhacken-Kristall

[recipe-name]
bertorio-pickaxe-1=Spitzhacke Mk1
bertorio-pickaxe-2=Spitzhacke Mk2
bertorio-pickaxe-3=Spitzhacke Mk3

[mod-setting-name]
bertorio-drop-chance-mat1=Drop-Chance Spitzhacken-Legierung (pro abgebautem Erz)
bertorio-drop-chance-mat2=Drop-Chance Spitzhacken-Kristall (pro abgebautem Erz)
```

- [ ] **Step 3: Verify both locales have all five item keys**

```bash
for f in locale/en/bertorio.cfg locale/de/bertorio.cfg; do
  printf "%s: " "$f"; grep -c "^bertorio-" "$f"
done
```
Expected: each prints `10` (5 item + 3 recipe + 2 mod-setting keys) — and both files print the SAME number.

- [ ] **Step 4: Commit**

```bash
git add locale/en/bertorio.cfg locale/de/bertorio.cfg
git commit -m "feat: English + German locale"
```

---

### Task 6: In-game smoke test + README

**Files:**
- Create: `README.md`

This task verifies the whole mod end-to-end in Factorio 2.0.77 (the only place
`data:extend`, `event_handler`, and `defines` actually run) and documents
install/test. The playtest is manual.

- [ ] **Step 1: Link the mod into Factorio's mods folder**

Factorio loads an unzipped mod folder named exactly `bertorio`. Symlink the repo:
```bash
ln -s "/e/Programmierung/Bertorio" "$APPDATA/Factorio/mods/bertorio" 2>/dev/null \
  || cmd.exe /c mklink /D "%APPDATA%\\Factorio\\mods\\bertorio" "E:\\Programmierung\\Bertorio"
```
(The extra `docs/`, `.git/` in the folder are ignored by Factorio.)

- [ ] **Step 2: Launch Factorio, enable the mod, start a freeplay game**

Confirm: no load error dialog; mod `Bertorio 0.1.0` is enabled in Mods list.

- [ ] **Step 3: Verify the pickaxe feature in-game**

Manual checklist (record results in the commit message):
1. Craft `Pickaxe Mk1` (10 iron plates) → appears in inventory.
2. Hand-mine an ore patch → noticeably faster (~2×). Drop it from inventory → speed returns to normal.
3. Open Settings → Mod settings → Map: set `Pickaxe Alloy drop chance` to `1.0`, mine one ore → receive a Pickaxe Alloy.
4. Likewise raise the Crystal chance, collect 10 Alloy + 10 Crystal.
5. Craft `Pickaxe Mk2` (Mk1 + 10 Alloy) → mining ~3×; craft `Pickaxe Mk3` (Mk2 + 10 Crystal) → mining ~4×.

- [ ] **Step 4: Write `README.md`**

```markdown
# Bertorio

A Factorio 2.0 mod: a small feature-docking framework plus a craftable,
3-tier hand-mining pickaxe.

## Features

- **Pickaxe** — craft `Pickaxe Mk1` (10 iron plates) to hand-mine ore at 2×.
  Upgrade to Mk2 (3×) and Mk3 (4×) using Alloy / Crystal that drop while
  mining ore. Speed is force-wide and active only while a pickaxe is carried.

## Install (dev)

Symlink this folder into Factorio's mods directory as `bertorio`:

    mklink /D "%APPDATA%\Factorio\mods\bertorio" "E:\Programmierung\Bertorio"

Enable **Bertorio** in the in-game Mods list.

## Settings (Map / runtime-global)

- Pickaxe Alloy drop chance — default 0.02
- Pickaxe Crystal drop chance — default 0.005

## Adding a feature

Create `features/<name>/data.lua` and `features/<name>/control.lua`
(`control.lua` returns an `event_handler` library table), then add `"<name>"`
to `features.lua`.

## Tests

`features/pickaxe/logic.lua` has pure helpers; run their asserts with
standalone Lua: `cd features/pickaxe && lua test_logic.lua`.
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: README + in-game smoke-test results"
```
