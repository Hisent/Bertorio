local logic = require("features.pickaxe.logic")

local MATERIALS = {
  { item = "bertorio-upgrade-material-1", setting = "bertorio-drop-chance-mat1", stat = "alloy" },
  { item = "bertorio-upgrade-material-2", setting = "bertorio-drop-chance-mat2", stat = "crystal" },
}

-- Floating "found" popup at head height (where the vanilla pickup text shows)
-- plus a short sound. Local = only that player sees/hears it.
local function notify(player, item_name)
  player.create_local_flying_text({
    text = { "bertorio.found-material", "[item=" .. item_name .. "]" },
    position = { player.position.x, player.position.y - 1.5 },
  })
  player.play_sound({ path = "utility/inventory_move" })
end

-- Roll one material: drop on a random hit OR, when pity is on, once the dry
-- streak reaches ceil(1/chance). Bumps the stat counter on a drop. Returns the
-- new dry-streak count.
local function roll(player, mat, dry, stats)
  local chance = settings.global[mat.setting].value
  dry = dry + 1
  local pity = settings.global["bertorio-pity-enabled"].value
      and logic.pity_for(chance) or math.huge
  if math.random() < chance or dry >= pity then
    player.insert({ name = mat.item, count = 1 })
    notify(player, mat.item)
    stats[mat.stat] = (stats[mat.stat] or 0) + 1
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
  storage.stats = storage.stats or {}
  local idx = event.player_index
  local dry = storage.dry[idx] or { 0, 0 }
  local stats = storage.stats[idx] or { ore = 0, alloy = 0, crystal = 0 }
  stats.ore = (stats.ore or 0) + 1
  dry[1] = roll(player, MATERIALS[1], dry[1], stats)
  dry[2] = roll(player, MATERIALS[2], dry[2], stats)
  storage.dry[idx] = dry
  storage.stats[idx] = stats
end

local function init()
  storage.dry = storage.dry or {}
  storage.stats = storage.stats or {}
end

return {
  on_init = init,
  on_configuration_changed = init,
  events = {
    [defines.events.on_player_mined_entity] = on_mined,
  },
}
