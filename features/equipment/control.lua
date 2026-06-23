local logic = require("features.pickaxe.logic")

local FRAME = "bertorio-equip-frame"
local BUTTON = "bertorio-equip-button"
local TIER_ITEMS = { "bertorio-pickaxe-1", "bertorio-pickaxe-2", "bertorio-pickaxe-3" }

local function item_for_tier(tier)
  return tier and TIER_ITEMS[tier] or nil
end

-- Count a pickaxe across main inventory AND the cursor (clicking the slot while
-- holding the item is the natural equip gesture).
local function count_owned(player, name)
  local n = 0
  local inv = player.get_main_inventory()
  if inv then n = n + inv.get_item_count(name) end
  local cs = player.cursor_stack
  if cs and cs.valid_for_read and cs.name == name then n = n + cs.count end
  return n
end

-- Remove one pickaxe, preferring main inventory then the cursor.
local function remove_one(player, name)
  local inv = player.get_main_inventory()
  if inv and inv.get_item_count(name) > 0 then
    inv.remove({ name = name, count = 1 })
    return
  end
  local cs = player.cursor_stack
  if cs and cs.valid_for_read and cs.name == name then
    cs.count = cs.count - 1
  end
end

-- Give one pickaxe back; spill on the ground if the inventory is full (no loss).
local function give_one(player, name)
  if player.insert({ name = name, count = 1 }) == 0 then
    player.surface.spill_item_stack({
      position = player.position,
      stack = { name = name, count = 1 },
      enable_looted = true,
      force = player.force,
    })
  end
end

local function get_button(player)
  if not player then return nil end
  local frame = player.gui.relative[FRAME]
  return frame and frame[BUTTON] or nil
end

-- Restrict the chooser to the pickaxe tiers the player currently has, and keep
-- the displayed value in sync with what is equipped.
local function update_slot(player)
  local btn = get_button(player)
  if not btn then return end
  local names = {}
  for _, name in ipairs(TIER_ITEMS) do
    if count_owned(player, name) > 0 then names[#names + 1] = name end
  end
  btn.elem_filters = { { filter = "name", name = names } }
  btn.elem_value = item_for_tier(storage.equipped[player.index])
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
  frame.add({
    type = "choose-elem-button",
    name = BUTTON,
    elem_type = "item",
    elem_filters = { { filter = "name", name = {} } },
  })
  update_slot(player)
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

local function on_inventory_changed(event)
  update_slot(game.get_player(event.player_index))
end

local function on_elem_changed(event)
  if event.element.name ~= BUTTON then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  storage.equipped = storage.equipped or {}
  local idx = player.index
  local chosen = event.element.elem_value -- item name or nil
  local old_tier = storage.equipped[idx]

  -- Unequip: return previously equipped pickaxe.
  if chosen == nil then
    if old_tier then give_one(player, item_for_tier(old_tier)) end
    storage.equipped[idx] = nil
    recompute_force(player.force)
    update_slot(player)
    return
  end

  local new_tier = logic.tier_of(chosen)
  if not new_tier then
    update_slot(player)
    return
  end
  if new_tier == old_tier then return end

  -- Must own the chosen pickaxe (main inventory or cursor) to equip it.
  if count_owned(player, chosen) < 1 then
    player.print({ "bertorio.equip-missing" })
    update_slot(player)
    return
  end

  -- Return the old one, consume the new one (from inventory or cursor).
  if old_tier then give_one(player, item_for_tier(old_tier)) end
  remove_one(player, chosen)
  storage.equipped[idx] = new_tier
  recompute_force(player.force)
  update_slot(player)
end

return {
  on_init = setup,
  on_configuration_changed = setup,
  events = {
    [defines.events.on_player_created] = on_player_setup,
    [defines.events.on_player_joined_game] = on_player_setup,
    [defines.events.on_player_main_inventory_changed] = on_inventory_changed,
    [defines.events.on_gui_elem_changed] = on_elem_changed,
  },
}
