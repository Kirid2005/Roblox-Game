--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local StatCalculator = require(script.Parent.Parent:WaitForChild("Progression"):WaitForChild("StatCalculator"))
local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))
local TestRunner = require(script.Parent:WaitForChild("TestRunner"))

local StatCalculatorSpec = {}

local function freshProfile(): DataSchema.ProfileData
	return DataSchema.newDefaults()
end

function StatCalculatorSpec.run(): boolean
	local results = TestRunner.run({
		["base stats pass through unmodified with no equipment/skills"] = function()
			local profile = freshProfile()
			profile.equipment = { Wand = nil, Robe = nil, Trinket = nil }
			local derived = StatCalculator.computeDerivedStats(profile)
			assert(derived[Enums.StatId.Power] == profile.baseStats[Enums.StatId.Power], "Power should be unmodified")
		end,

		["equipment stat modifiers are added"] = function()
			local profile = freshProfile()
			local basePower = profile.baseStats[Enums.StatId.Power]
			local derived = StatCalculator.computeDerivedStats(profile)
			-- default profile ships with apprentice_wand (+2 Power)
			assert(derived[Enums.StatId.Power] == basePower + 2, `expected {basePower + 2}, got {derived[Enums.StatId.Power]}`)
		end,

		["skill tree grants stack on top of equipment"] = function()
			local profile = freshProfile()
			profile.skillTree.unlockedNodeIds["offense_arcane_1"] = true -- +5 Power
			local derived = StatCalculator.computeDerivedStats(profile)
			local expected = profile.baseStats[Enums.StatId.Power] + 2 + 5
			assert(derived[Enums.StatId.Power] == expected, `expected {expected}, got {derived[Enums.StatId.Power]}`)
		end,

		["spell AP cost never drops below 1"] = function()
			local profile = freshProfile()
			local cost = StatCalculator.computeSpellApCost(profile, "firebolt", 1)
			assert(cost >= 1, "AP cost must be at least 1")
		end,

		["hasLearnedSpell reflects learnedSpells table"] = function()
			local profile = freshProfile()
			assert(StatCalculator.hasLearnedSpell(profile, "firebolt") == true, "firebolt should be learned by default")
			assert(StatCalculator.hasLearnedSpell(profile, "meteor_call") == false, "meteor_call should not be learned by default")
		end,
	})
	return TestRunner.report("StatCalculator", results)
end

return StatCalculatorSpec
