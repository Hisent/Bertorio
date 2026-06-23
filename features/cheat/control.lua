-- Testing cheat: /bertorio-cheat gives a pickaxe test kit so smoke tests don't
-- require mining ore first. Re-runnable (tops up). Using it disables
-- achievements (vanilla console-command behavior).
commands.add_command(
  "bertorio-cheat",
  "Bertorio: give a pickaxe test kit (100 iron plates + 50/50 upgrade materials)",
  function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player then return end
    player.insert({ name = "iron-plate", count = 100 })
    player.insert({ name = "bertorio-upgrade-material-1", count = 50 })
    player.insert({ name = "bertorio-upgrade-material-2", count = 50 })
    player.print("[Bertorio] Test kit added: 100 iron plates, 50 Alloy, 50 Crystal.")
  end
)

return {}
