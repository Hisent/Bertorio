# Bertorio — Equipment Feature Design

Second feature for Bertorio. Adds an **equip slot in the character screen**:
the pickaxe mining-speed bonus applies only while a pickaxe is equipped in that
slot — carrying it loose in the inventory no longer grants the bonus.

**Target game version:** Factorio 2.0.77.

## Goal

Make the pickaxe an equipped item rather than an inventory-presence buff, via a
mod GUI slot anchored to the character (controller) screen, chosen through
Factorio's native item picker.

## Behavior change

- Bonus is granted **only** when a pickaxe is equipped in the slot.
- Equipping removes **one** pickaxe of that tier from the player's main
  inventory (it now "lives" in the slot). Unequipping / switching returns it.
- This replaces the previous inventory-scan behavior in the `pickaxe` feature.

## Architecture (framework docking + refactor)

- **New feature `equipment`** owns: equipped state, the GUI, and the
  mining-speed modifier recompute.
- **`pickaxe` feature** keeps: item + recipe prototypes and the ore-mining
  material drops. It **loses** the inventory-scan + modifier logic and its
  inventory/join event handlers (those move to `equipment`).
- `equipment` reuses `features.pickaxe.logic` (`tier_of`, `modifier_for`,
  `max_tier`). This is a deliberate cross-feature dependency on the core
  `pickaxe` feature; documented here.

## Components

### 1. GUI

A frame in `player.gui.relative`, anchored to
`defines.relative_gui_type.controller_gui` so it appears beside the inventory
when the character screen is open. Title "Pickaxe" / "Spitzhacke". Contains a
single `choose-elem-button`:

- `elem_type = "item"`
- `elem_filters = { { filter = "name", name = { "bertorio-pickaxe-1", "bertorio-pickaxe-2", "bertorio-pickaxe-3" } } }`

The button's `elem_value` reflects the currently equipped pickaxe (or empty).

### 2. State

`storage.equipped` is a table `{ [player_index] = tier }` where tier is `1|2|3`
or `nil` when nothing is equipped. Persisted in `storage`.

### 3. Equip / unequip (`on_gui_elem_changed`)

On change of the equip button (guard: it is our button):
- **Selected a pickaxe item** (`element.elem_value` is a name):
  - resolve tier via `logic.tier_of`.
  - if the player's main inventory has ≥1 of that item:
    - if a different tier was already equipped, insert one of the old tier back
      into the inventory;
    - remove 1 of the new tier from the inventory; set `storage.equipped[idx]`.
  - else (does not own it): revert `elem_value` to the previously equipped
    item name (or nil) and `player.print` a hint; make no state change.
- **Cleared** (`elem_value` is `nil`): if a tier was equipped, insert one of
  that tier back into the inventory and clear `storage.equipped[idx]`.
- After any state change, recompute the player's force modifier.

### 4. Modifier recompute

`force.manual_mining_speed_modifier = logic.modifier_for(max equipped tier
across the force's players)`. Iterate `force.players`, read each player's
`storage.equipped[player.index]`, take the max via `logic.max_tier`.
Set absolutely (same `ponytail:` caveat as before — clobbers other mods writing
the same modifier).

### 5. Lifecycle

Build (or rebuild) the GUI for a player on: `on_init` (all players),
`on_configuration_changed` (all players — destroy stale frame, rebuild),
`on_player_created`, `on_player_joined_game`. Recompute all forces on `on_init`
and `on_configuration_changed`. Building is idempotent: destroy any existing
frame by name first, then create.

## Error handling

- Nil-guard player / character / missing GUI element (rebuild if missing).
- Picking a tier the player does not own: revert button, hint message, no state
  change (no item duplication).
- Equip/unequip item moves are balanced (remove on equip, insert on unequip) so
  no net item creation or loss.
- Force-wide modifier remains an engine limitation (no per-player mining speed).

## Testing

`features/pickaxe/logic.lua` is already unit-tested and is reused unchanged; no
new pure logic is introduced. GUI behavior and inventory moves are verified by
in-game smoke test (`/bertorio-cheat` provides pickaxe materials):

1. Open character screen → "Spitzhacke" slot visible beside inventory.
2. Craft Mk1, click slot → pick Mk1 → it leaves inventory, mining is ~2×.
3. Switch slot to Mk2 → Mk1 returns to inventory, Mk2 leaves, mining ~3×.
4. Clear the slot → pickaxe returns, mining back to normal.
5. Try selecting a tier you do not own → button reverts, hint shown, no item gained.

## Out of scope

- Per-player mining speed in multiplayer (engine limitation; stays force-wide).
- Drag-and-drop cursor equip (chooser picker chosen instead).
- Multiple simultaneous equipped pickaxes / set bonuses.
