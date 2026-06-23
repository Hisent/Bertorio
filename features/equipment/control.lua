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
