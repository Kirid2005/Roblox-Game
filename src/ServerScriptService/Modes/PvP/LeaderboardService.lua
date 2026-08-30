--!strict
-- Thin wrapper around OrderedDataStore for PvP rating leaderboards. Kept
-- separate from RatingService (pure math) and SeasonService (season
-- lifecycle) so each has one job. One OrderedDataStore per season means
-- last season's leaderboard stays queryable (e.g. for a "hall of fame")
-- without being polluted by the new season's resets.

local DataStoreService = game:GetService("DataStoreService")

local LeaderboardService = {}

local function storeNameForSeason(seasonId: string): string
	return "PvPLeaderboard_" .. seasonId
end

function LeaderboardService.updatePlayerScore(seasonId: string, userId: number, rating: number)
	local store = DataStoreService:GetOrderedDataStore(storeNameForSeason(seasonId))
	local ok, err = pcall(function()
		store:SetAsync(tostring(userId), rating)
	end)
	if not ok then
		warn(`[LeaderboardService] Failed to update score for {userId} in {seasonId}: {err}`)
	end
end

export type LeaderboardEntry = { userId: number, rating: number }

function LeaderboardService.getTopN(seasonId: string, n: number): { LeaderboardEntry }
	local store = DataStoreService:GetOrderedDataStore(storeNameForSeason(seasonId))
	local results: { LeaderboardEntry } = {}

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, n)
	end)
	if not ok then
		warn(`[LeaderboardService] Failed to fetch leaderboard for {seasonId}: {pages}`)
		return results
	end

	local page = pages:GetCurrentPage()
	for _, entry in page do
		table.insert(results, { userId = tonumber(entry.key) :: number, rating = entry.value })
	end
	return results
end

return LeaderboardService
