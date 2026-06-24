local logic = require("features.pickaxe.logic")

local RADIUS = 8

local function active(player)
  if not settings.global["bertorio-bert-enabled"].value then return false end
  if not (player and player.valid and player.character) then return false end
  return (storage.equipped and storage.equipped[player.index] ~= nil) or false
end

local function destroy_render(idx)
  local r = storage.bert_render[idx]
  if r and r.valid then r.destroy() end
  storage.bert_render[idx] = nil
end

local function ensure_render(player)
  local idx = player.index
  local r = storage.bert_render[idx]
  if r and r.valid then return end
  storage.bert_render[idx] = rendering.draw_sprite({
    sprite = "bertorio-bert",
    target = { entity = player.character, offset = { 1.2, -1.5 } },
    surface = player.surface,
    x_scale = 0.4,
    y_scale = 0.4,
  })
end

-- Give items to the player, spilling the remainder on the ground (no loss).
local function give(player, name, count)
  local inserted = player.insert({ name = name, count = count })
  local rest = count - inserted
  if rest > 0 then
    player.surface.spill_item_stack({
      position = player.position,
      stack = { name = name, count = rest },
      enable_looted = true,
      force = player.force,
    })
  end
end

-- Bert mines one nearby ore for the player.
local function bert_mine(player)
  local ents = player.surface.find_entities_filtered({
    type = "resource", position = player.position, radius = RADIUS,
  })
  local best, bestd
  for _, e in pairs(ents) do
    if e.valid and (e.amount or 0) > 0 then
      local dx = e.position.x - player.position.x
      local dy = e.position.y - player.position.y
      local d = dx * dx + dy * dy
      if not bestd or d < bestd then best, bestd = e, d end
    end
  end
  if not best then return end
  local products = best.prototype.mineable_properties.products
  if not products then return end
  local first
  for _, p in pairs(products) do
    local amt = p.amount or p.amount_min or 1
    give(player, p.name, amt)
    first = first or p.name
  end
  if not best.prototype.infinite_resource then
    best.amount = best.amount - 1
    if best.amount <= 0 then best.destroy() end
  end
  if first then
    player.create_local_flying_text({
      text = { "bertorio.bert-mined", "[item=" .. first .. "]" },
      position = { player.position.x, player.position.y - 2 },
    })
    player.play_sound({ path = "utility/inventory_move" })
  end
end

local function on_mined(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.type == "resource") then return end
  local player = game.get_player(event.player_index)
  if not active(player) then return end
  if math.random() < settings.global["bertorio-bert-mine-chance"].value then
    bert_mine(player)
  end
end

local function on_tick30()
  storage.bert_render = storage.bert_render or {}
  storage.bert_last = storage.bert_last or {}
  local interval = settings.global["bertorio-bert-interval"].value
  for _, player in pairs(game.connected_players) do
    if active(player) then
      ensure_render(player)
      if logic.due(game.tick, storage.bert_last[player.index], interval) then
        bert_mine(player)
        storage.bert_last[player.index] = game.tick
      end
    else
      destroy_render(player.index)
    end
  end
end

local function init()
  storage.bert_render = storage.bert_render or {}
  storage.bert_last = storage.bert_last or {}
end

return {
  on_init = init,
  on_configuration_changed = init,
  events = {
    [defines.events.on_player_mined_entity] = on_mined,
  },
  on_nth_tick = { [30] = on_tick30 },
}
