local logic = require("features.pickaxe.logic")
local mod_gui = require("__core__.lualib.mod-gui")

local BUTTON = "bertorio-stats-toggle"
local FRAME = "bertorio-stats-frame"

local function enabled()
  return settings.global["bertorio-stats-enabled"].value
end

local function remove_gui(player)
  if not player then return end
  local flow = mod_gui.get_button_flow(player)
  if flow[BUTTON] then flow[BUTTON].destroy() end
  local frame = player.gui.screen[FRAME]
  if frame then frame.destroy() end
end

local function build_button(player)
  if not player then return end
  if not enabled() then remove_gui(player); return end
  local flow = mod_gui.get_button_flow(player)
  if flow[BUTTON] then return end
  flow.add({ type = "button", name = BUTTON, caption = { "bertorio.stats-button" } })
end

local function streak(n, setting, pity_on)
  if not pity_on then return "-" end
  local p = logic.pity_for(settings.global[setting].value)
  if p == math.huge then return "-" end
  return n .. "/" .. p
end

local function refresh(player)
  local frame = player.gui.screen[FRAME]
  if not frame then return end
  local s = (storage.stats and storage.stats[player.index]) or { ore = 0, alloy = 0, crystal = 0 }
  local d = (storage.dry and storage.dry[player.index]) or { 0, 0 }
  local pity_on = settings.global["bertorio-pity-enabled"].value
  frame.content.caption = {
    "bertorio.stats-body",
    s.ore or 0, s.alloy or 0, s.crystal or 0,
    streak(d[1] or 0, "bertorio-drop-chance-mat1", pity_on),
    streak(d[2] or 0, "bertorio-drop-chance-mat2", pity_on),
  }
end

local function open_window(player)
  if player.gui.screen[FRAME] then return end
  local frame = player.gui.screen.add({
    type = "frame", name = FRAME, direction = "vertical",
    caption = { "bertorio.stats-title" },
  })
  frame.auto_center = true
  frame.add({ type = "label", name = "content" })
  refresh(player)
end

local function on_click(event)
  if event.element.name ~= BUTTON then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local frame = player.gui.screen[FRAME]
  if frame then frame.destroy() else open_window(player) end
end

local function on_mined(event)
  refresh(game.get_player(event.player_index))
end

local function on_player_setup(event)
  build_button(game.get_player(event.player_index))
end

local function setup()
  for _, player in pairs(game.players) do build_button(player) end
end

local function on_setting_changed(event)
  if event.setting ~= "bertorio-stats-enabled" then return end
  for _, player in pairs(game.players) do build_button(player) end
end

return {
  on_init = setup,
  on_configuration_changed = setup,
  events = {
    [defines.events.on_player_created] = on_player_setup,
    [defines.events.on_player_joined_game] = on_player_setup,
    [defines.events.on_gui_click] = on_click,
    [defines.events.on_player_mined_entity] = on_mined,
    [defines.events.on_runtime_mod_setting_changed] = on_setting_changed,
  },
}
