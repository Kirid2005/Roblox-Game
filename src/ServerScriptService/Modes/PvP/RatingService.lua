--!strict
-- Pure Elo-style rating math. No Roblox APIs, no Player references -- easy
-- to unit test (see Tests/RatingService.spec.lua) and safe to reuse for
-- any future ranked mode without dragging PvP session plumbing along.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local RatingService = {}

function RatingService.computeExpectedScore(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

-- `scoreA` is 1 for a win, 0 for a loss, 0.5 for a draw, from A's
-- perspective. Returns rounded integer ratings for both sides.
function RatingService.computeNewRatings(ratingA: number, ratingB: number, scoreA: number, kFactor: number?): (number, number)
	local k = kFactor or Constants.PVP_K_FACTOR
	local expectedA = RatingService.computeExpectedScore(ratingA, ratingB)
	local expectedB = 1 - expectedA
	local scoreB = 1 - scoreA

	local newA = ratingA + k * (scoreA - expectedA)
	local newB = ratingB + k * (scoreB - expectedB)

	return math.round(newA), math.round(newB)
end

-- Soft rating reset applied between seasons: pulls a player's rating
-- halfway back toward the starting rating rather than wiping it outright,
-- so skill carries over somewhat but the ladder isn't frozen season to
-- season.
function RatingService.computeSeasonSoftReset(rating: number): number
	return math.round(Constants.PVP_STARTING_RATING + (rating - Constants.PVP_STARTING_RATING) * 0.5)
end

return RatingService
