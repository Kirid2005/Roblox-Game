--!strict
-- PvP queueing, match-found notification, and leaderboard reads. Actual
-- match creation happens in PvPMatchService; this module is the glue
-- between the queue and the RemoteEvents clients see.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local RateLimiter = require(ServerScriptService:WaitForChild("Security"):WaitForChild("RateLimiter"))

local MatchmakingService = require(script.Parent.Parent:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("MatchmakingService"))
local PvPMatchService = require(script.Parent.Parent:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("PvPMatchService"))
local SeasonService = require(script.Parent.Parent:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("SeasonService"))
local LeaderboardService = require(script.Parent.Parent:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("LeaderboardService"))

local PvPRemotes = {}

local function onMatchFound(players: { Player })
	local session = PvPMatchService.startMatch(players)
	if not session then
		return
	end

	local remote = Net.getRemote("PvpMatchFound") :: RemoteEvent
	for _, player in players do
		local combatantId = `player_{player.UserId}`
		remote:FireClient(player, { sessionId = session.id, yourCombatantId = combatantId })
	end
end

function PvPRemotes.setup()
	MatchmakingService.startMatchingLoop(onMatchFound)

	local joinQueue = Net.getRemote("RequestJoinPvpQueue") :: RemoteEvent
	joinQueue.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.checkAndConsume(player, "RequestJoinPvpQueue", 1) then
			return
		end
		local profile = PlayerDataService.getProfile(player)
		if not profile then
			return
		end
		SeasonService.ensurePlayerOnCurrentSeason(profile.data)
		MatchmakingService.joinQueue(player, profile.data.pvp.rating)
	end)

	local leaveQueue = Net.getRemote("RequestLeavePvpQueue") :: RemoteEvent
	leaveQueue.OnServerEvent:Connect(function(player: Player)
		MatchmakingService.leaveQueue(player)
	end)

	local leaderboardRequest = Net.getRemote("LeaderboardSnapshotRequest") :: RemoteFunction
	leaderboardRequest.OnServerInvoke = function(player: Player, topN: unknown)
		local n = 20
		if typeof(topN) == "number" then
			n = math.clamp(math.floor(topN), 1, 100)
		end
		local season = SeasonService.getCurrentSeason()
		return {
			seasonId = season.id,
			entries = LeaderboardService.getTopN(season.id, n),
		}
	end
end

return PvPRemotes
