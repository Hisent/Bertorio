local handler = require("__core__.lualib.event_handler")
local features = require("features")

local libs = {}
for _, name in ipairs(features) do
  libs[#libs + 1] = require("features." .. name .. ".control")
end
handler.add_libraries(libs)
