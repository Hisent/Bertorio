local features = require("features")
for _, name in ipairs(features) do
  require("features." .. name .. ".data")
end
