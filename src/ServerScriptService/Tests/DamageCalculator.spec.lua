--!strict
local DamageCalculator = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("DamageCalculator"))
local TestRunner = require(script.Parent:WaitForChild("TestRunner"))

local DamageCalculatorSpec = {}

function DamageCalculatorSpec.run(): boolean
	local results = TestRunner.run({
		["flat amount with no scaling stat"] = function()
			local amount = DamageCalculator.computeAmount({ amount = 10 }, function()
				return 0
			end)
			assert(amount == 10, `expected 10, got {amount}`)
		end,

		["scaling stat multiplies factor and adds to flat amount"] = function()
			local amount = DamageCalculator.computeAmount({ amount = 8, scalingStat = "Power", scalingFactor = 1.5 }, function(stat)
				assert(stat == "Power")
				return 20
			end)
			assert(amount == 8 + 20 * 1.5, `expected {8 + 20 * 1.5}, got {amount}`)
		end,

		["amount never goes negative"] = function()
			local amount = DamageCalculator.computeAmount({ amount = -50 }, function()
				return 0
			end)
			assert(amount == 0, `expected 0, got {amount}`)
		end,

		["shield fully absorbs when capacity exceeds damage"] = function()
			local remainder, absorbed = DamageCalculator.applyShieldAbsorption(30, 100)
			assert(remainder == 0, "remainder should be 0")
			assert(absorbed == 30, "absorbed should equal the full raw amount")
		end,

		["shield partially absorbs when capacity is less than damage"] = function()
			local remainder, absorbed = DamageCalculator.applyShieldAbsorption(30, 10)
			assert(remainder == 20, `expected remainder 20, got {remainder}`)
			assert(absorbed == 10, `expected absorbed 10, got {absorbed}`)
		end,
	})
	return TestRunner.report("DamageCalculator", results)
end

return DamageCalculatorSpec
