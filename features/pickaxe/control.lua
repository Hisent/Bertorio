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

local logic = require("features.pickaxe.logic")

local MATERIALS = {
  { item = "bertorio-upgrade-material-1", setting = "bertorio-drop-chance-mat1" },
  { item = "bertorio-upgrade-material-2", setting = "bertorio-drop-chance-mat2" },
}

-- Roll one material: drop on a random hit OR once the dry streak reaches the
-- pity threshold (guaranteed at least once per ceil(1/chance) ore). Returns the
-- new dry-streak count.
local function roll(player, mat, dry)
  local chance = settings.global[mat.setting].value
  dry = dry + 1
  if math.random() < chance or dry >= logic.pity_for(chance) then
    player.insert({ name = mat.item, count = 1 })
    notify(player, mat.item)
    return 0
  end
  return dry
end

local function on_mined(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.type == "resource") then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  storage.dry = storage.dry or {}
  local dry = storage.dry[event.player_index] or { 0, 0 }
  -- ponytail: create_local_flying_text shows one popup at a time per player, so
  -- a rare double-drop (both materials at once) only shows the second. Fine.
  dry[1] = roll(player, MATERIALS[1], dry[1])
  dry[2] = roll(player, MATERIALS[2], dry[2])
  storage.dry[event.player_index] = dry
end

local function init()
  storage.dry = storage.dry or {}
end

return {
  on_init = init,
  on_configuration_changed = init,
  events = {
    [defines.events.on_player_mined_entity] = on_mined,
  },
}
