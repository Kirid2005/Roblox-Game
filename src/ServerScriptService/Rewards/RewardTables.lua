--!strict
-- Server-only reward payouts per mode/encounter. Referenced by id (e.g.
-- an EncounterDef's `rewardTableId`, or a literal id used by PvP) rather
-- than duplicating numbers inline in mode services, so balancing rewards
-- never requires touching gameplay code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

export type RewardSpec = {
	experience: number?,
	currencies: { [string]: number }?,
	itemIds: { string }?,
}

local RewardTables: { [string]: RewardSpec } = {}

RewardTables.dungeon_trash = {
	experience = 40,
	currencies = { [Enums.RewardCurrency.Gold] = 15 },
}

RewardTables.dungeon_elite = {
	experience = 90,
	currencies = { [Enums.RewardCurrency.Gold] = 35, [Enums.RewardCurrency.ArcaneDust] = 5 },
}

RewardTables.academy_boss = {
	experience = 400,
	currencies = { [Enums.RewardCurrency.Gold] = 150, [Enums.RewardCurrency.ArcaneDust] = 25 },
	itemIds = { "gamblers_charm" },
}

RewardTables.pvp_win = {
	experience = 120,
	currencies = { [Enums.RewardCurrency.SeasonToken] = 20, [Enums.RewardCurrency.Gold] = 25 },
}

RewardTables.pvp_loss = {
	experience = 40,
	currencies = { [Enums.RewardCurrency.SeasonToken] = 5 },
}

return RewardTables
