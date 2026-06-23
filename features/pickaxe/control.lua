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
  force.character_mining_speed_modifier = logic.modifier_for(logic.max_tier(tiers))
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
