local function item(name, icon)
  return {
    type = "item",
    name = name,
    icon = icon,
    icon_size = 64,
    stack_size = 50,
    subgroup = "intermediate-product",
    order = name,
  }
end

local G = "__bertorio__/features/pickaxe/graphics/"
local B = "__base__/graphics/icons/"

data:extend({
  -- pickaxe tiers (own tier-colored icons)
  item("bertorio-pickaxe-1", G .. "pickaxe-1.png"),
  item("bertorio-pickaxe-2", G .. "pickaxe-2.png"),
  item("bertorio-pickaxe-3", G .. "pickaxe-3.png"),
  -- upgrade materials (reuse base icons)
  item("bertorio-upgrade-material-1", B .. "advanced-circuit.png"),
  item("bertorio-upgrade-material-2", B .. "processing-unit.png"),

  -- recipes (available from start)
  {
    type = "recipe",
    name = "bertorio-pickaxe-1",
    enabled = true,
    ingredients = { { type = "item", name = "iron-plate", amount = 10 } },
    results = { { type = "item", name = "bertorio-pickaxe-1", amount = 1 } },
  },
  {
    type = "recipe",
    name = "bertorio-pickaxe-2",
    enabled = true,
    ingredients = {
      { type = "item", name = "bertorio-pickaxe-1", amount = 1 },
      { type = "item", name = "bertorio-upgrade-material-1", amount = 10 },
    },
    results = { { type = "item", name = "bertorio-pickaxe-2", amount = 1 } },
  },
  {
    type = "recipe",
    name = "bertorio-pickaxe-3",
    enabled = true,
    ingredients = {
      { type = "item", name = "bertorio-pickaxe-2", amount = 1 },
      { type = "item", name = "bertorio-upgrade-material-2", amount = 10 },
    },
    results = { { type = "item", name = "bertorio-pickaxe-3", amount = 1 } },
  },
})
