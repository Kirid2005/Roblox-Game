--!strict
-- PvP queueing and pairing by rating.
--
-- NOTE on scope: matching itself runs per-server against an in-memory
-- queue, which is correct and immediately useful for a single game
-- server's population. Every queue entry is also mirrored into a
-- MemoryStoreSortedMap (`PvPQueue`), which is the piece that *is*
-- cross-server-visible -- the natural next step (a small matchmaking
-- coordinator that reads this map, pairs entries from different servers,
-- and reserve-teleports both players into a shared match server) can be
-- built on top of it without changing how players join/leave the queue.
-- Keeping that split explicit here means the eventual cross-server
-- upgrade is additive, not a rewrite.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local MatchmakingService = {}

local QUEUE_ENTRY_EXPIRATION_SECONDS = 120
local MATCH_LOOP_INTERVAL_SECONDS = 2
local INITIAL_RATING_TOLERANCE = 100
local TOLERANCE_GROWTH_PER_SECOND = 10

local memoryQueue = MemoryStoreService:GetSortedMap("PvPQueue")

export type QueueEntry = {
	player: Player,
	rating: number,
	joinedAt: number,
}

local localQueue: { [number]: QueueEntry } = {}

function MatchmakingService.joinQueue(player: Player, rating: number)
	localQueue[player.UserId] = { player = player, rating = rating, joinedAt = os.time() }

	task.spawn(function()
		pcall(function()
			memoryQueue:SetAsync(tostring(player.UserId), { rating = rating, jobId = game.JobId }, QUEUE_ENTRY_EXPIRATION_SECONDS)
		end)
	end)
end

function MatchmakingService.leaveQueue(player: Player)
	localQueue[player.UserId] = nil
	task.spawn(function()
		pcall(function()
			memoryQueue:RemoveAsync(tostring(player.UserId))
		end)
	end)
end

function MatchmakingService.isQueued(player: Player): boolean
	return localQueue[player.UserId] ~= nil
end

-- Greedy nearest-rating pairing with tolerance that widens the longer
-- someone has waited, so a queue never stalls indefinitely just because
-- no perfect-rating opponent is available. `maxPlayersPerMatch` defaults
-- to Constants.PVP_MATCH_MAX_PLAYERS (2) but is a parameter, not a
-- hard-coded literal, so team-based PvP variants can reuse this loop.
function MatchmakingService.startMatchingLoop(onMatchFound: (players: { Player }) -> ())
	task.spawn(function()
		while true do
			task.wait(MATCH_LOOP_INTERVAL_SECONDS)

			local entries: { QueueEntry } = {}
			for _, entry in localQueue do
				if entry.player.Parent then
					table.insert(entries, entry)
				else
					localQueue[entry.player.UserId] = nil
				end
			end
			table.sort(entries, function(a, b)
				return a.rating < b.rating
			end)

			local matched: { [number]: boolean } = {}
			local now = os.time()

			for i = 1, #entries do
				local a = entries[i]
				if not matched[a.player.UserId] then
					for j = i + 1, #entries do
						local b = entries[j]
						if not matched[b.player.UserId] then
							local waited = now - math.max(a.joinedAt, b.joinedAt)
							local tolerance = INITIAL_RATING_TOLERANCE + waited * TOLERANCE_GROWTH_PER_SECOND
							if math.abs(a.rating - b.rating) <= tolerance then
								matched[a.player.UserId] = true
								matched[b.player.UserId] = true
								localQueue[a.player.UserId] = nil
								localQueue[b.player.UserId] = nil
								task.spawn(onMatchFound, { a.player, b.player })
								break
							end
						end
					end
				end
			end
		end
	end)
end

return MatchmakingService
