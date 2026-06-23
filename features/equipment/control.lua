local logic = require("features.pickaxe.logic")

local FRAME = "bertorio-equip-frame"
local BUTTON = "bertorio-equip-button"
local TIER_ITEMS = { "bertorio-pickaxe-1", "bertorio-pickaxe-2", "bertorio-pickaxe-3" }

local function item_for_tier(tier)
  return tier and TIER_ITEMS[tier] or nil
end

local function quality_level(quality)
  local proto = quality and prototypes.quality[quality]
  return proto and proto.level or 0
end

-- Effective tier of an equipped entry {name, quality} (or nil) -> 0..3.
local function eff_tier(eq)
  if not eq then return 0 end
  local t = logic.tier_of(eq.name)
  if not t then return 0 end
  return logic.effective_tier(t, quality_level(eq.quality))
end

-- manual_mining_speed_modifier for an effective tier 0..3, from settings.
local function speed_for(tier)
  if tier <= 0 then return 0 end
  return settings.global["bertorio-speed-mk" .. tier].value
end

-- Count a pickaxe of a specific quality across main inventory AND the cursor.
local function count_owned(player, name, quality)
  local q = quality or "normal"
  local n = 0
  local inv = player.get_main_inventory()
  if inv then n = n + inv.get_item_count({ name = name, quality = q }) end
  local cs = player.cursor_stack
  if cs and cs.valid_for_read and cs.name == name and cs.quality.name == q then
    n = n + cs.count
  end
  return n
end

local function remove_one(player, name, quality)
  local q = quality or "normal"
  local inv = player.get_main_inventory()
  if inv and inv.get_item_count({ name = name, quality = q }) > 0 then
    inv.remove({ name = name, count = 1, quality = q })
    return
  end
  local cs = player.cursor_stack
  if cs and cs.valid_for_read and cs.name == name and cs.quality.name == q then
    cs.count = cs.count - 1
  end
end

local function give_one(player, name, quality)
  local q = quality or "normal"
  if player.insert({ name = name, count = 1, quality = q }) == 0 then
    player.surface.spill_item_stack({
      position = player.position,
      stack = { name = name, count = 1, quality = q },
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

-- Restrict the chooser to owned tiers, sync the value + bonus tooltip.
local function update_slot(player)
  local btn = get_button(player)
  if not btn then return end
  local names = {}
  for _, name in ipairs(TIER_ITEMS) do
    if count_owned(player, name, "normal") > 0 then names[#names + 1] = name end
  end
  local eq = storage.equipped[player.index]
  -- keep the equipped item selectable even if its only copy is now in the slot
  if eq and not names[1] then names[1] = eq.name end
  btn.elem_filters = { { filter = "name", name = names } }
  btn.elem_value = eq and { name = eq.name, quality = eq.quality or "normal" } or nil
  local t = eff_tier(eq)
  if t > 0 then
    btn.tooltip = { "bertorio.equip-bonus", math.floor(speed_for(t) * 100) }
  else
    btn.tooltip = { "bertorio.equip-hint" }
  end
end

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
    elem_type = "item-with-quality",
    elem_filters = { { filter = "name", name = {} } },
  })
  update_slot(player)
end

local function build_all()
  for _, player in pairs(game.players) do build_gui(player) end
end

local function recompute_force(force)
  if not (force and force.valid) then return end
  local effs = {}
  for _, player in pairs(force.players) do
    effs[#effs + 1] = eff_tier(storage.equipped[player.index])
  end
  force.manual_mining_speed_modifier = speed_for(logic.max_tier(effs))
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
  local chosen = event.element.elem_value -- {name, quality} or nil
  local old = storage.equipped[idx]

  if chosen == nil then
    if old then give_one(player, old.name, old.quality) end
    storage.equipped[idx] = nil
    recompute_force(player.force)
    update_slot(player)
    return
  end

  if not logic.tier_of(chosen.name) then
    update_slot(player)
    return
  end
  if old and old.name == chosen.name and old.quality == chosen.quality then return end

  if count_owned(player, chosen.name, chosen.quality) < 1 then
    player.print({ "bertorio.equip-missing" })
    update_slot(player)
    return
  end

  if old then give_one(player, old.name, old.quality) end
  remove_one(player, chosen.name, chosen.quality)
  storage.equipped[idx] = { name = chosen.name, quality = chosen.quality }
  recompute_force(player.force)
  update_slot(player)
end

-- Cycle the equipped pickaxe through owned NORMAL-quality tiers:
-- none -> lowest owned -> ... -> highest owned -> none.
local function on_cycle(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  storage.equipped = storage.equipped or {}
  local idx = player.index
  local old = storage.equipped[idx]
  local cur_tier = old and logic.tier_of(old.name) or 0

  local function set_tier(tier)
    if old then give_one(player, old.name, old.quality) end
    if tier then
      remove_one(player, item_for_tier(tier), "normal")
      storage.equipped[idx] = { name = item_for_tier(tier), quality = "normal" }
    else
      storage.equipped[idx] = nil
    end
    recompute_force(player.force)
    update_slot(player)
  end

  for step = 1, 4 do
    local t = (cur_tier + step) % 4 -- 0..3
    if t == 0 then
      set_tier(nil)
      return
    elseif count_owned(player, item_for_tier(t), "normal") > 0 then
      set_tier(t)
      return
    end
  end
end

return {
  on_init = setup,
  on_configuration_changed = setup,
  events = {
    [defines.events.on_player_created] = on_player_setup,
    [defines.events.on_player_joined_game] = on_player_setup,
    [defines.events.on_player_main_inventory_changed] = on_inventory_changed,
    [defines.events.on_gui_elem_changed] = on_elem_changed,
    ["bertorio-cycle-pickaxe"] = on_cycle,
  },
}
