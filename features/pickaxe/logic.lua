-- Pure helpers, no Factorio API. Standalone-unit-testable (see test_logic.lua).
local logic = {}

-- pickaxe item name -> tier
logic.TIER_BY_ITEM = {
  ["bertorio-pickaxe-1"] = 1,
  ["bertorio-pickaxe-2"] = 2,
  ["bertorio-pickaxe-3"] = 3,
}

function logic.tier_of(item_name)
  return logic.TIER_BY_ITEM[item_name]
end

-- tier value doubles as the character_mining_speed_modifier (T1->+1.0 = 2x ...)
function logic.modifier_for(tier)
  return tier or 0
end

-- highest tier in a dense list (no nil holes); 0 if empty
function logic.max_tier(tiers)
  local best = 0
  for _, t in ipairs(tiers) do
    if t > best then best = t end
  end
  return best
end

return logic
