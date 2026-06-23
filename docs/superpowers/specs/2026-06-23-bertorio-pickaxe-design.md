# Bertorio — Design

Factorio 2.0 mod. A **base framework** for docking small features onto, plus
the first feature: a craftable **pickaxe** that speeds up hand-mining, upgradeable
across three tiers, with upgrade materials that drop while mining ore.

**Target game version:** Factorio 2.0.77 (`factorio_version "2.0"`).

## Goal

Ship a minimal, idiomatic Factorio mod whose architecture makes adding the next
feature trivial (drop a folder, add one line), and which delivers the pickaxe
feature end to end.

## Architecture — the framework

Use Factorio's own `__core__/lualib/event_handler` — the engine's native
mechanism for composing multiple event-handling modules into one mod. No
custom event bus.

A single feature registry lists active features:

```lua
-- features.lua
return { "pickaxe" }
```

- `data.lua` loops the list and requires `features/<name>/data.lua` (if present).
- `control.lua` loops the list and calls `event_handler.add_lib(require("features/<name>/control"))`.

**Adding a feature = create `features/<name>/` and add its name to `features.lua`.**

### File structure

```
bertorio/
  info.json              -- factorio_version "2.0", dependency: base
  features.lua           -- active feature list
  data.lua               -- requires each feature's data.lua
  control.lua            -- event_handler.add_lib per feature control
  settings.lua           -- mod settings (drop chances)
  features/
    pickaxe/
      data.lua           -- items + recipes
      control.lua        -- event-handler lib { events=..., on_init=... }
      logic.lua          -- pure helpers (no Factorio API): tier_of, modifier_for, max_tier
      test_logic.lua     -- standalone-lua assert self-check for logic.lua
  locale/
    en/bertorio.cfg
    de/bertorio.cfg
```

Each feature stage file is optional; the loaders skip a feature that lacks a
`data.lua` or `control.lua`.

## Feature: pickaxe

### Items

- `bertorio-pickaxe-1`, `bertorio-pickaxe-2`, `bertorio-pickaxe-3` — inventory tokens (`type="item"`).
- `bertorio-upgrade-material-1` — needed for the T2 upgrade.
- `bertorio-upgrade-material-2` — needed for the T3 upgrade.

### Recipes (all enabled from start, no research)

| Recipe | Ingredients |
|---|---|
| `bertorio-pickaxe-1` | 10 × iron-plate |
| `bertorio-pickaxe-2` | 1 × `bertorio-pickaxe-1` + 10 × `bertorio-upgrade-material-1` |
| `bertorio-pickaxe-3` | 1 × `bertorio-pickaxe-2` + 10 × `bertorio-upgrade-material-2` |

Recipe costs are defaults, tunable later.

### Mining-speed mechanic

Mining speed is governed by `force.manual_mining_speed_modifier`, which is
**force-wide** (not per-player) — per-player speed is not natively possible
without swapping character prototypes, which is out of scope.

`control.lua` recomputes the force modifier on:
- `on_player_main_inventory_changed`
- `on_player_joined_game`, `on_player_left_game`
- `on_init` / `on_configuration_changed`

Computation: for the affected force, find the **maximum pickaxe tier currently
held** across all players of that force whose character exists, then set the
modifier:

| Highest tier held | Modifier | Effective speed |
|---|---|---|
| none | 0.0 | 1× (vanilla) |
| T1 | +1.0 | 2× |
| T2 | +2.0 | 3× |
| T3 | +3.0 | 4× |

Stateless: derived from live inventories each event, so no `storage` is needed.

`ponytail:` we set the modifier **absolutely**, which clobbers any other mod
that writes the same force modifier. Acceptable for now; upgrade path is to
track a delta if a conflict ever appears.

### Upgrade-material drops

On `on_player_mined_entity`, only when `entity.type == "resource"`:
- independent roll for each material against its drop chance;
- a hit inserts 1 of that material into the mining player.

Defaults: `upgrade-material-1` at 2%, `upgrade-material-2` at 0.5%.

## Settings (`runtime-global`, adjustable in-game)

- `bertorio-drop-chance-mat1` — double, default `0.02`.
- `bertorio-drop-chance-mat2` — double, default `0.005`.

## Error handling

Nil-guard: players without a character, force lookups, missing inventory.
Drop logic guards `event.entity` validity and `entity.type`.

## Testing

`features/pickaxe/logic.lua` holds pure functions with no Factorio API
dependency: `tier_of(item_name)`, `modifier_for(tier)`, `max_tier(list)`.
`test_logic.lua` runs under standalone `lua`/`luajit` and asserts their
behavior. In-game event wiring is not unit-testable without the game and is
verified by manual playtest.

## Out of scope

- Per-player mining speed in multiplayer (engine limitation).
- Research/technology gating (recipes are available from start).
- Drops from mining drills / machines (hand-mining only).
- A second upgrade material source beyond mining.
