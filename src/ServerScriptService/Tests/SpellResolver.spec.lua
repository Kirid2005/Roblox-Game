--!strict
local SpellResolver = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("SpellResolver"))
local TestRunner = require(script.Parent:WaitForChild("TestRunner"))

local SpellResolverSpec = {}

-- A fake rng that returns a fixed queue of values, so rollOutcome's bucket
-- selection can be tested deterministically without relying on real
-- randomness.
local function fakeRng(values: { number })
	local index = 0
	return {
		NextNumber = function()
			index += 1
			return values[index]
		end,
	}
end

local SAMPLE_TABLE = {
	{ outcome = "CriticalSuccess", weight = 5, effects = {}, logMessageKey = "" },
	{ outcome = "NormalSuccess", weight = 60, effects = {}, logMessageKey = "" },
	{ outcome = "NormalFailure", weight = 30, effects = {}, logMessageKey = "" },
	{ outcome = "CriticalFailure", weight = 5, effects = {}, logMessageKey = "" },
}

function SpellResolverSpec.run(): boolean
	local results = TestRunner.run({
		["buildAdjustedOutcomeTable adds crit chance bonus to CriticalSuccess"] = function()
			local adjusted = SpellResolver.buildAdjustedOutcomeTable(SAMPLE_TABLE, { critChanceBonus = 10, failureResistance = 0 })
			assert(adjusted[1].weight == 15, `expected 15, got {adjusted[1].weight}`)
		end,

		["buildAdjustedOutcomeTable subtracts failure resistance from CriticalFailure, floored at 0"] = function()
			local adjusted = SpellResolver.buildAdjustedOutcomeTable(SAMPLE_TABLE, { critChanceBonus = 0, failureResistance = 100 })
			assert(adjusted[4].weight == 0, `expected 0, got {adjusted[4].weight}`)
		end,

		["rollOutcome picks the bucket the roll falls into, low end"] = function()
			-- total weight 100; roll * total = 0.0 -> falls into first bucket (weight 5)
			local rng = fakeRng({ 0.0 })
			local chosen = SpellResolver.rollOutcome(SAMPLE_TABLE, rng)
			assert(chosen.outcome == "CriticalSuccess", `expected CriticalSuccess, got {chosen.outcome}`)
		end,

		["rollOutcome picks the bucket the roll falls into, mid range"] = function()
			-- roll * total = 50 -> cumulative after bucket 1 (5) and bucket 2 (65) -> NormalSuccess
			local rng = fakeRng({ 0.50 })
			local chosen = SpellResolver.rollOutcome(SAMPLE_TABLE, rng)
			assert(chosen.outcome == "NormalSuccess", `expected NormalSuccess, got {chosen.outcome}`)
		end,

		["rollOutcome picks the last bucket at the top of the range"] = function()
			local rng = fakeRng({ 0.999999 })
			local chosen = SpellResolver.rollOutcome(SAMPLE_TABLE, rng)
			assert(chosen.outcome == "CriticalFailure", `expected CriticalFailure, got {chosen.outcome}`)
		end,

		["statistical: realized distribution over many rolls approximates configured weights"] = function()
			local rng = Random.new(1234) -- fixed seed for reproducibility
			local counts = { CriticalSuccess = 0, NormalSuccess = 0, NormalFailure = 0, CriticalFailure = 0 }
			local iterations = 20000
			for _ = 1, iterations do
				local chosen = SpellResolver.rollOutcome(SAMPLE_TABLE, rng)
				counts[chosen.outcome] += 1
			end
			-- Configured: 5% / 60% / 30% / 5%. Allow +-2 percentage points of slack.
			local successFraction = counts.NormalSuccess / iterations
			assert(successFraction > 0.58 and successFraction < 0.62, `NormalSuccess fraction out of range: {successFraction}`)
		end,
	})
	return TestRunner.report("SpellResolver", results)
end

return SpellResolverSpec
