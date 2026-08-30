--!strict
-- Pure damage/heal amount math, isolated so it can be unit tested without
-- spinning up a whole combat session (see Tests/DamageCalculator.spec.lua).
-- EffectSystem is the only caller in production code.

local DamageCalculator = {}

export type ScalingSpec = {
	amount: number?,
	scalingStat: string?,
	scalingFactor: number?,
}

-- `getCasterStat` is a function (statId) -> number rather than a plain
-- stat table so callers can pass a live `Combatant:getEffectiveStat`
-- closure in production while tests pass a trivial stub.
function DamageCalculator.computeAmount(spec: ScalingSpec, getCasterStat: (statId: string) -> number): number
	local base = spec.amount or 0
	local scaling = 0
	if spec.scalingStat then
		scaling = getCasterStat(spec.scalingStat) * (spec.scalingFactor or 0)
	end
	return math.max(0, base + scaling)
end

-- Shield absorption: returns (damageToHealth, amountAbsorbed) given a raw
-- incoming amount and however much shield capacity remains.
function DamageCalculator.applyShieldAbsorption(rawAmount: number, shieldRemaining: number): (number, number)
	local absorbed = math.min(rawAmount, shieldRemaining)
	local remainder = rawAmount - absorbed
	return remainder, absorbed
end

return DamageCalculator
