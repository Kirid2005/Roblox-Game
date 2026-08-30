--!strict
-- Server-authoritative, idempotent reward granting. Every reward source
-- (PvE clear, PvP result, season payout, monetization bonus) calls
-- through here with a unique `ledgerKey` describing *why* the reward is
-- being granted (e.g. "dungeon:academy_corridor_1:sess_42" or
-- "pvp_season:season_2026_08:final"). If that key has already been
-- recorded in the player's profile, the grant is skipped entirely -- so a
-- client retry, a reconnect, or a duplicated network message can never pay
-- out twice for the same event.
--
-- This module never talks to Roblox services directly; it only mutates
-- the profile table it's given, which the caller is responsible for
-- persisting (PlayerDataService.markDirty + the normal save cycle).

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))
local ExperienceService = require(script.Parent.Parent:WaitForChild("Progression"):WaitForChild("ExperienceService"))
local InventoryService = require(script.Parent.Parent:WaitForChild("Progression"):WaitForChild("InventoryService"))
local RewardTables = require(script.Parent:WaitForChild("RewardTables"))

local RewardService = {}

export type GrantOutcome = {
	granted: boolean, -- false means this ledgerKey was already paid out (no-op)
	levelsGained: number,
	newLevel: number,
}

function RewardService.grant(profileData: DataSchema.ProfileData, ledgerKey: string, spec: RewardTables.RewardSpec, bonusXpMultiplier: number?): GrantOutcome
	if profileData.rewardLedger[ledgerKey] then
		return { granted = false, levelsGained = 0, newLevel = profileData.level }
	end

	local levelsGained = 0
	local newLevel = profileData.level

	if spec.currencies then
		for currency, amount in spec.currencies do
			profileData.currencies[currency] = (profileData.currencies[currency] or 0) + amount
		end
	end

	if spec.experience and spec.experience > 0 then
		local result = ExperienceService.grantExperience(profileData, spec.experience, bonusXpMultiplier)
		levelsGained = result.levelsGained
		newLevel = result.newLevel
	end

	if spec.itemIds then
		for _, itemId in spec.itemIds do
			InventoryService.addItem(profileData, itemId, 1)
		end
	end

	profileData.rewardLedger[ledgerKey] = true

	return { granted = true, levelsGained = levelsGained, newLevel = newLevel }
end

function RewardService.grantFromTable(profileData: DataSchema.ProfileData, ledgerKey: string, tableId: string, bonusXpMultiplier: number?): GrantOutcome
	local spec = RewardTables[tableId]
	assert(spec, `RewardService.grantFromTable: unknown reward table "{tableId}"`)
	return RewardService.grant(profileData, ledgerKey, spec, bonusXpMultiplier)
end

return RewardService
