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
