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

## Smoke test (in-game)

1. Craft `Pickaxe Mk1` (10 iron plates) → in inventory.
2. Hand-mine ore → ~2× faster. Drop the pickaxe → speed back to normal.
3. Map settings: set `Pickaxe Alloy drop chance` to `1.0`, mine ore → get Alloy.
   Same for Crystal. Collect 10 Alloy + 10 Crystal.
4. Craft `Pickaxe Mk2` (Mk1 + 10 Alloy) → ~3×; `Pickaxe Mk3` (Mk2 + 10 Crystal) → ~4×.
