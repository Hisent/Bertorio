-- Pickaxe feature: ore-mining material drops only.
-- The mining-speed modifier lives in the `equipment` feature.

-- Floating "found" popup at the player (local = only that player sees it).
-- Offset up to sit where the vanilla "+N item" pickup text appears (head height),
-- not at the character's feet. ponytail: -1.5 tiles matches the vanilla pickup
-- text; nudge if a future character model differs.
local function notify(player, item_name)
  player.create_local_flying_text({
    text = { "bertorio.found-material", "[item=" .. item_name .. "]" },
    position = { player.position.x, player.position.y - 1.5 },
  })
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
    notify(player, "bertorio-upgrade-material-1")
  end
  -- ponytail: create_local_flying_text shows one popup at a time per player, so
  -- a rare double-drop (both rolls hit) only shows the second. Acceptable.
  if math.random() < c2 then
    player.insert({ name = "bertorio-upgrade-material-2", count = 1 })
    notify(player, "bertorio-upgrade-material-2")
  end
end

return {
  events = {
    [defines.events.on_player_mined_entity] = on_mined,
  },
}
