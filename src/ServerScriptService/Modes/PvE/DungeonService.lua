--!strict
-- Orchestrates PvE dungeon encounters: validates the requesting party
-- against an EncounterDef's configurable player-count range, builds the
-- combat session (players as team Alpha vs the encounter's NPCs as team
-- Beta), and applies PvE-specific rules on completion (progression
-- tracking + rewards). Reuses the same CombatEngine that PvP and boss
-- fights use -- only the roster and the win/loss handling differ.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local EncounterCatalog = require(ServerStorage:WaitForChild("GameData"):WaitForChild("EncounterCatalog"))

local ServerScriptService = game:GetService("ServerScriptService")
local CombatEngine = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatEngine"))
local CombatSession = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatSession"))
local CombatantFactory = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatantFactory"))
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local RewardService = require(ServerScriptService:WaitForChild("Rewards"):WaitForChild("RewardService"))
local MonetizationService = require(ServerScriptService:WaitForChild("Monetization"):WaitForChild("MonetizationService"))

local EncounterFactory = require(script.Parent:WaitForChild("EncounterFactory"))

local DungeonService = {}

export type ActiveDungeon = {
	session: CombatSession.CombatSessionObject,
	encounterDef: EncounterCatalog.EncounterDef,
	players: { Player },
}

local activeDungeons: { [string]: ActiveDungeon } = {} -- sessionId -> ActiveDungeon

export type StartFailureReason = "UnknownEncounter" | "PartySizeInvalid" | "ProfileNotLoaded"

local function handleDungeonEnd(activeDungeon: ActiveDungeon, winningTeamId: string?)
	local encounterDef = activeDungeon.encounterDef
	local session = activeDungeon.session

	if winningTeamId == Enums.TeamId.Alpha then
		for _, player in activeDungeon.players do
			local profile = PlayerDataService.getProfile(player)
			if profile then
				local ledgerKey = `dungeon:{encounterDef.id}:{session.id}`
				local xpMultiplier = MonetizationService.getActiveXpMultiplier(profile.data)
				RewardService.grantFromTable(profile.data, ledgerKey, encounterDef.rewardTableId, xpMultiplier)
				profile.data.pve.completedEncounters[encounterDef.id] = true
				PlayerDataService.markDirty(player)
			end
		end
	end

	CombatEngine.endSession(session)
	activeDungeons[session.id] = nil
end

-- `encounterId` selects the content; `players` is the party attempting it.
-- Player count is validated against the *encounter's own* configured
-- range (never a hard-coded 1-4), so a future "5-player trial" encounter
-- needs no engine changes.
function DungeonService.startEncounter(
	players: { Player },
	encounterId: string,
	extraConfig: { onTick: ((session: CombatSession.CombatSessionObject) -> ())? }?
): (CombatSession.CombatSessionObject?, StartFailureReason?)
	local encounterDef = EncounterCatalog[encounterId]
	if not encounterDef then
		return nil, "UnknownEncounter"
	end

	if #players < encounterDef.minPlayers or #players > encounterDef.maxPlayers then
		return nil, "PartySizeInvalid"
	end

	local playerCombatants = {}
	for _, player in players do
		local profile = PlayerDataService.getProfile(player)
		if not profile then
			return nil, "ProfileNotLoaded"
		end
		local combatantId = `player_{player.UserId}`
		table.insert(playerCombatants, CombatantFactory.fromPlayer(player, profile.data, combatantId, Enums.TeamId.Alpha))
	end

	local npcCombatants = EncounterFactory.buildNpcCombatants(encounterDef)

	local combined = table.clone(playerCombatants)
	for _, npcParams in npcCombatants do
		table.insert(combined, npcParams)
	end

	local mode = encounterDef.isBossEncounter and Enums.GameMode.Boss or Enums.GameMode.Dungeon

	local activeDungeon: ActiveDungeon = {
		session = nil :: any,
		encounterDef = encounterDef,
		players = players,
	}

	local session = CombatEngine.createSession(mode, combined, {
		minPlayers = encounterDef.minPlayers,
		maxPlayers = encounterDef.maxPlayers,
		onVictory = function(winningTeamId: string?)
			handleDungeonEnd(activeDungeon, winningTeamId)
		end,
		onTick = extraConfig and extraConfig.onTick or nil,
	})

	activeDungeon.session = session
	activeDungeons[session.id] = activeDungeon

	return session
end

function DungeonService.getActiveDungeon(sessionId: string): ActiveDungeon?
	return activeDungeons[sessionId]
end

return DungeonService
