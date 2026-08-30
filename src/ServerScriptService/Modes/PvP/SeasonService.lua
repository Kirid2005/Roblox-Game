--!strict
-- Monthly (configurable) PvP season lifecycle. A single cross-server
-- "current season" record lives in DataStoreService so every server
-- agrees on the season id/boundaries; individual profiles are migrated
-- onto the new season (with a soft rating reset and season-end reward)
-- lazily, the next time SeasonService.ensurePlayerOnCurrentSeason runs for
-- them, rather than requiring a global fan-out job the moment a season
-- ends.
--
-- Season length is entirely config-driven (Constants.SEASON_DURATION_DAYS)
-- -- changing it does not require touching rating/leaderboard code.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local ServerStorage = game:GetService("ServerStorage")
local SeasonRewardTiers = require(ServerStorage:WaitForChild("GameData"):WaitForChild("SeasonRewardTiers"))

local ServerScriptService = game:GetService("ServerScriptService")
local DataSchema = require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataSchema"))
local RewardService = require(ServerScriptService:WaitForChild("Rewards"):WaitForChild("RewardService"))

local RatingService = require(script.Parent:WaitForChild("RatingService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local SeasonService = {}

export type SeasonRecord = {
	id: string,
	seasonNumber: number,
	startsAt: number,
	endsAt: number,
}

local SEASON_STORE_NAME = "PvPSeasonMeta"
local SEASON_KEY = "CurrentSeason"
local seasonStore = DataStoreService:GetDataStore(SEASON_STORE_NAME)

local cachedSeason: SeasonRecord? = nil

local function buildSeasonId(seasonNumber: number): string
	return "season_" .. tostring(seasonNumber)
end

-- Atomically reads the current season record, rolling a new one if none
-- exists yet or the previous one has expired. Safe to call from multiple
-- servers concurrently -- UpdateAsync guarantees only one roll happens.
function SeasonService.refreshCurrentSeason(): SeasonRecord
	local now = os.time()
	local result: SeasonRecord? = nil

	local ok, err = pcall(function()
		seasonStore:UpdateAsync(SEASON_KEY, function(existing: SeasonRecord?)
			if existing ~= nil and existing.endsAt > now then
				result = existing
				return existing
			end

			local nextNumber = (existing and existing.seasonNumber or 0) + 1
			local newSeason: SeasonRecord = {
				id = buildSeasonId(nextNumber),
				seasonNumber = nextNumber,
				startsAt = now,
				endsAt = now + Constants.SEASON_DURATION_DAYS * 24 * 60 * 60,
			}
			result = newSeason
			return newSeason
		end)
	end)

	if not ok or result == nil then
		warn(`[SeasonService] Failed to refresh season, falling back to cached/default: {tostring(err)}`)
		if cachedSeason then
			return cachedSeason
		end
		result = {
			id = buildSeasonId(1),
			seasonNumber = 1,
			startsAt = now,
			endsAt = now + Constants.SEASON_DURATION_DAYS * 24 * 60 * 60,
		}
	end

	cachedSeason = result
	return result :: SeasonRecord
end

function SeasonService.getCurrentSeason(): SeasonRecord
	if cachedSeason == nil or cachedSeason.endsAt <= os.time() then
		return SeasonService.refreshCurrentSeason()
	end
	return cachedSeason
end

function SeasonService.startPeriodicRefresh()
	task.spawn(function()
		while true do
			SeasonService.refreshCurrentSeason()
			task.wait(60 * 60) -- hourly is plenty; season boundaries are day-granularity
		end
	end)
end

local function grantSeasonEndReward(profileData: DataSchema.ProfileData, seasonId: string, finalRating: number)
	local tier = SeasonRewardTiers[1]
	for _, candidate in SeasonRewardTiers do
		if finalRating >= candidate.minRating then
			tier = candidate
			break
		end
	end

	local ledgerKey = `pvp_season_end:{seasonId}`
	RewardService.grant(profileData, ledgerKey, {
		currencies = tier.currencyRewards,
	})
	for _, cosmeticId in tier.cosmeticItemIds do
		profileData.achievements.unlocked[cosmeticId] = true
	end
end

-- Called whenever a profile touches PvP (queueing, match end, login). If
-- the profile is still tagged with a past season, archives its final
-- stats, grants the season-end reward tier, applies the soft rating
-- reset, and rolls it onto the current season.
function SeasonService.ensurePlayerOnCurrentSeason(profileData: DataSchema.ProfileData)
	local current = SeasonService.getCurrentSeason()

	if profileData.pvp.currentSeasonId == current.id then
		return
	end

	if profileData.pvp.currentSeasonId ~= nil then
		local oldSeasonId = profileData.pvp.currentSeasonId
		profileData.pvp.seasonStats[oldSeasonId] = {
			wins = profileData.pvp.wins,
			losses = profileData.pvp.losses,
			rating = profileData.pvp.rating,
		}
		grantSeasonEndReward(profileData, oldSeasonId, profileData.pvp.rating)
		profileData.pvp.rating = RatingService.computeSeasonSoftReset(profileData.pvp.rating)
		profileData.pvp.wins = 0
		profileData.pvp.losses = 0
	end

	profileData.pvp.currentSeasonId = current.id
end

function SeasonService.reportMatchResult(seasonId: string, userId: number, rating: number)
	LeaderboardService.updatePlayerScore(seasonId, userId, rating)
end

return SeasonService
