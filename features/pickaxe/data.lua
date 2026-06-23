local function item(name, icon)
  return {
    type = "item",
    name = name,
    icon = "__base__/graphics/icons/" .. icon,
    icon_size = 64,
    stack_size = 50,
    subgroup = "intermediate-product",
    order = name,
  }
end

data:extend({
  -- pickaxe tiers (inventory tokens; reuse repair-pack icon)
  item("bertorio-pickaxe-1", "repair-pack.png"),
  item("bertorio-pickaxe-2", "repair-pack.png"),
  item("bertorio-pickaxe-3", "repair-pack.png"),
  -- upgrade materials
  item("bertorio-upgrade-material-1", "advanced-circuit.png"),
  item("bertorio-upgrade-material-2", "processing-unit.png"),

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
