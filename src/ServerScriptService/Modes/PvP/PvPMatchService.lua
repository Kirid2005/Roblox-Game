--!strict
-- Builds and resolves 1v1 PvP matches on top of the shared CombatEngine.
-- Rating changes, rewards, and leaderboard updates are computed entirely
-- from server-held profile/session state -- nothing here ever trusts a
-- client-reported result.
--
-- Scoped to 2-player matches for this foundational version (matching
-- Constants.PVP_MATCH_MAX_PLAYERS); team PvP would mean swapping
-- RatingService's pairwise Elo for a team-rating algorithm, not
-- restructuring this service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local ServerScriptService = game:GetService("ServerScriptService")
local CombatEngine = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatEngine"))
local CombatSession = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatSession"))
local CombatantFactory = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatantFactory"))
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local RewardService = require(ServerScriptService:WaitForChild("Rewards"):WaitForChild("RewardService"))
local MonetizationService = require(ServerScriptService:WaitForChild("Monetization"):WaitForChild("MonetizationService"))

local RatingService = require(script.Parent:WaitForChild("RatingService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))

local PvPMatchService = {}

export type ActiveMatch = {
	session: CombatSession.CombatSessionObject,
	playerA: Player,
	playerB: Player,
}

local activeMatches: { [string]: ActiveMatch } = {}

local function handleMatchEnd(activeMatch: ActiveMatch, winningTeamId: string?)
	local session = activeMatch.session
	local season = SeasonService.getCurrentSeason()

	local profileA = PlayerDataService.getProfile(activeMatch.playerA)
	local profileB = PlayerDataService.getProfile(activeMatch.playerB)

	if profileA and profileB then
		local scoreA = 0.5
		if winningTeamId == Enums.TeamId.Alpha then
			scoreA = 1
		elseif winningTeamId == Enums.TeamId.Beta then
			scoreA = 0
		end

		local newRatingA, newRatingB = RatingService.computeNewRatings(profileA.data.pvp.rating, profileB.data.pvp.rating, scoreA)
		profileA.data.pvp.rating = newRatingA
		profileB.data.pvp.rating = newRatingB

		if scoreA == 1 then
			profileA.data.pvp.wins += 1
			profileB.data.pvp.losses += 1
		elseif scoreA == 0 then
			profileB.data.pvp.wins += 1
			profileA.data.pvp.losses += 1
		end

		local ledgerKeyA = `pvp_match:{session.id}:{activeMatch.playerA.UserId}`
		local ledgerKeyB = `pvp_match:{session.id}:{activeMatch.playerB.UserId}`
		RewardService.grantFromTable(profileA.data, ledgerKeyA, scoreA == 1 and "pvp_win" or "pvp_loss", MonetizationService.getActiveXpMultiplier(profileA.data))
		RewardService.grantFromTable(profileB.data, ledgerKeyB, scoreA == 0 and "pvp_win" or "pvp_loss", MonetizationService.getActiveXpMultiplier(profileB.data))

		SeasonService.reportMatchResult(season.id, activeMatch.playerA.UserId, newRatingA)
		SeasonService.reportMatchResult(season.id, activeMatch.playerB.UserId, newRatingB)

		PlayerDataService.markDirty(activeMatch.playerA)
		PlayerDataService.markDirty(activeMatch.playerB)
	end

	CombatEngine.endSession(session)
	activeMatches[session.id] = nil
end

function PvPMatchService.startMatch(players: { Player }): CombatSession.CombatSessionObject?
	assert(#players == 2, "PvPMatchService.startMatch: expected exactly 2 players")
	local playerA, playerB = players[1], players[2]

	local profileA = PlayerDataService.getProfile(playerA)
	local profileB = PlayerDataService.getProfile(playerB)
	if not profileA or not profileB then
		warn("[PvPMatchService] Cannot start match: a profile is not loaded")
		return nil
	end

	SeasonService.ensurePlayerOnCurrentSeason(profileA.data)
	SeasonService.ensurePlayerOnCurrentSeason(profileB.data)

	local combatantA = CombatantFactory.fromPlayer(playerA, profileA.data, `player_{playerA.UserId}`, Enums.TeamId.Alpha)
	local combatantB = CombatantFactory.fromPlayer(playerB, profileB.data, `player_{playerB.UserId}`, Enums.TeamId.Beta)

	local activeMatch: ActiveMatch = {
		session = nil :: any,
		playerA = playerA,
		playerB = playerB,
	}

	local session = CombatEngine.createSession(Enums.GameMode.PvP, { combatantA, combatantB }, {
		minPlayers = 2,
		maxPlayers = 2,
		onVictory = function(winningTeamId: string?)
			handleMatchEnd(activeMatch, winningTeamId)
		end,
	})

	activeMatch.session = session
	activeMatches[session.id] = activeMatch

	return session
end

return PvPMatchService
