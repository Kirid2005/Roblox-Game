--!strict
-- Server-only PvP season-end reward tiers, keyed by minimum rating. Kept
-- in ServerStorage since the exact reward thresholds are competitively
-- sensitive info (no reason to hand exact rating breakpoints to clients
-- ahead of time). SeasonService walks this list, highest threshold first,
-- and grants the first tier a player's final rating qualifies for.

local Enums = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Enums"))

export type SeasonRewardTier = {
	id: string,
	minRating: number,
	currencyRewards: { [string]: number },
	cosmeticItemIds: { string },
}

local SeasonRewardTiers: { SeasonRewardTier } = {
	{
		id = "grandmaster",
		minRating = 1800,
		currencyRewards = { [Enums.RewardCurrency.SeasonToken] = 500, [Enums.RewardCurrency.Gems] = 100 },
		cosmeticItemIds = { "season_title_grandmaster" },
	},
	{
		id = "diamond",
		minRating = 1500,
		currencyRewards = { [Enums.RewardCurrency.SeasonToken] = 300, [Enums.RewardCurrency.Gems] = 50 },
		cosmeticItemIds = { "season_title_diamond" },
	},
	{
		id = "gold",
		minRating = 1200,
		currencyRewards = { [Enums.RewardCurrency.SeasonToken] = 150 },
		cosmeticItemIds = {},
	},
	{
		id = "unranked",
		minRating = 0,
		currencyRewards = { [Enums.RewardCurrency.SeasonToken] = 50 },
		cosmeticItemIds = {},
	},
}

-- Ordered highest-minRating-first so callers can walk it and take the
-- first match.
table.sort(SeasonRewardTiers, function(a, b)
	return a.minRating > b.minRating
end)

return SeasonRewardTiers
