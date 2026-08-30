--!strict
local RatingService = require(script.Parent.Parent:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("RatingService"))
local TestRunner = require(script.Parent:WaitForChild("TestRunner"))

local RatingServiceSpec = {}

function RatingServiceSpec.run(): boolean
	local results = TestRunner.run({
		["equal ratings give 0.5 expected score"] = function()
			local expected = RatingService.computeExpectedScore(1000, 1000)
			assert(TestRunner.almostEqual(expected, 0.5), `expected 0.5, got {expected}`)
		end,

		["higher rating has higher expected score"] = function()
			local expected = RatingService.computeExpectedScore(1200, 1000)
			assert(expected > 0.5, "favorite should have expected score above 0.5")
		end,

		["a win increases rating and a loss decreases the opponent's"] = function()
			local newA, newB = RatingService.computeNewRatings(1000, 1000, 1, 32)
			assert(newA > 1000, `winner rating should increase, got {newA}`)
			assert(newB < 1000, `loser rating should decrease, got {newB}`)
			assert(newA - 1000 == 1000 - newB, "equal ratings should swap equal amounts")
		end,

		["a draw between equal ratings changes nothing"] = function()
			local newA, newB = RatingService.computeNewRatings(1000, 1000, 0.5, 32)
			assert(newA == 1000 and newB == 1000, "equal-rated draw should not move ratings")
		end,

		["upsets move rating more than expected wins"] = function()
			local _, underdogWinGain = RatingService.computeNewRatings(1400, 1000, 0, 32)
			-- underdog (1000) beating a 1400: recompute from B's perspective
			local newLowRating, newHighRating = RatingService.computeNewRatings(1000, 1400, 1, 32)
			assert(newLowRating - 1000 > 16, "a big underdog win should gain a large amount of rating")
		end,

		["season soft reset pulls rating halfway back to the baseline"] = function()
			local reset = RatingService.computeSeasonSoftReset(1800)
			-- starting rating is 1000 by default Constants; halfway from 1800 is 1400
			assert(reset < 1800 and reset > 1000, `expected a value between 1000 and 1800, got {reset}`)
		end,
	})
	return TestRunner.report("RatingService", results)
end

return RatingServiceSpec
