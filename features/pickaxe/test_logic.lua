-- Run from features/pickaxe/:  lua test_logic.lua
local logic = require("logic")

assert(logic.tier_of("bertorio-pickaxe-1") == 1)
assert(logic.tier_of("bertorio-pickaxe-2") == 2)
assert(logic.tier_of("bertorio-pickaxe-3") == 3)
assert(logic.tier_of("iron-plate") == nil)

assert(logic.modifier_for(0) == 0)
assert(logic.modifier_for(1) == 1)
assert(logic.modifier_for(3) == 3)
assert(logic.modifier_for(nil) == 0)

assert(logic.pity_for(0.04) == 25)
assert(logic.pity_for(0.01) == 100)
assert(logic.pity_for(0.5) == 2)
assert(logic.pity_for(0) == math.huge)
assert(logic.pity_for(nil) == math.huge)

assert(logic.max_tier({}) == 0)
assert(logic.max_tier({1}) == 1)
assert(logic.max_tier({1, 3, 2}) == 3)
assert(logic.max_tier({2, 2}) == 2)

print("logic.lua: all asserts passed")
