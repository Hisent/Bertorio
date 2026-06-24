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

-- Pity threshold: guarantee a drop at least once per ceil(1/chance) ore.
-- chance <= 0 disables drops entirely (returns math.huge -> never forced).
function logic.pity_for(chance)
  if not chance or chance <= 0 then return math.huge end
  return math.ceil(1 / chance)
end

-- Effective tier: a quality level counts as +1 tier, capped at Mk3.
function logic.effective_tier(tier, qlevel)
  return math.min((tier or 0) + (qlevel or 0), 3)
end

-- True when `interval` ticks have passed since `last` (nil last = never -> due).
function logic.due(now, last, interval)
  return (now - (last or 0)) >= interval
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
