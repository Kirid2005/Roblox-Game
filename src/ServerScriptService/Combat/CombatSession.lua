--!strict
-- A single active combat encounter: a bag of Combatants, a session-level
-- state machine, a bounded combat log, and the signals that let network
-- code (or anything else) react to what happened without the combat
-- engine needing to know who's listening.
--
-- CombatSession is mode-agnostic: PvE dungeon fights, 8-player boss
-- encounters, and 1v1 PvP matches are all just a CombatSession with
-- different combatant rosters and a different `mode` tag. See
-- ServerScriptService/Modes/* for the mode-specific rules layered on top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))

local CombatSession = {}
CombatSession.__index = CombatSession

export type SessionConfig = {
	minPlayers: number?,
	maxPlayers: number?,
	onVictory: ((winningTeamId: string?) -> ())?,
	-- Generic extension point for mode-specific per-tick logic (e.g. boss
	-- phase transitions at HP thresholds) that must react to combat state
	-- every frame without requiring changes to CombatEngine itself. See
	-- Modes/PvE/BossEncounterService.lua for an example.
	onTick: ((session: any) -> ())?,
}

export type LogEntry = {
	tick: number,
	kind: string, -- "Cast" | "StateChange" | "Info"
	data: { [string]: any },
}

export type CombatSessionObject = typeof(setmetatable(
	{} :: {
		id: string,
		mode: string,
		combatants: { [string]: Combatant.CombatantObject },
		combatantOrder: { string }, -- stable iteration order for replication
		state: string,
		currentTick: number,
		rng: Random,
		combatLog: { LogEntry },
		config: SessionConfig,
		StateChanged: Signal.Signal<string, string>, -- (oldState, newState)
		LogAppended: Signal.Signal<LogEntry>,
	},
	CombatSession
))

local MAX_LOG_ENTRIES = 200

function CombatSession.new(id: string, mode: string, combatantList: { Combatant.CombatantObject }, config: SessionConfig?, seed: number?): CombatSessionObject
	local combatants = {}
	local order = {}
	for _, combatant in combatantList do
		combatants[combatant.id] = combatant
		table.insert(order, combatant.id)
	end

	local self = setmetatable({
		id = id,
		mode = mode,
		combatants = combatants,
		combatantOrder = order,
		state = Enums.CombatState.Waiting,
		currentTick = 0,
		rng = Random.new(seed or os.time()),
		combatLog = {},
		config = config or {},
		StateChanged = Signal.new(),
		LogAppended = Signal.new(),
	}, CombatSession)

	return self :: any
end

function CombatSession.getCombatant(self: CombatSessionObject, id: string): Combatant.CombatantObject?
	return self.combatants[id]
end

function CombatSession.getRoster(self: CombatSessionObject): { Combatant.CombatantObject }
	local roster = {}
	for _, id in self.combatantOrder do
		table.insert(roster, self.combatants[id])
	end
	return roster
end

function CombatSession.getAliveByTeam(self: CombatSessionObject, teamId: string): { Combatant.CombatantObject }
	local results = {}
	for _, combatant in self:getRoster() do
		if combatant.teamId == teamId and combatant:isAlive() then
			table.insert(results, combatant)
		end
	end
	return results
end

function CombatSession.setState(self: CombatSessionObject, newState: string)
	if self.state == newState then
		return
	end
	local old = self.state
	self.state = newState
	self:log("StateChange", { from = old, to = newState })
	self.StateChanged:Fire(old, newState)
end

function CombatSession.start(self: CombatSessionObject)
	assert(self.state == Enums.CombatState.Waiting, "CombatSession.start: session already started")
	self:setState(Enums.CombatState.Charging)
end

function CombatSession.log(self: CombatSessionObject, kind: string, data: { [string]: any })
	local entry: LogEntry = { tick = self.currentTick, kind = kind, data = data }
	table.insert(self.combatLog, entry)
	if #self.combatLog > MAX_LOG_ENTRIES then
		table.remove(self.combatLog, 1)
	end
	self.LogAppended:Fire(entry)
end

-- Generic victory condition: if exactly one distinct team among the
-- roster still has living members, that team wins. Works unmodified for
-- PvE (players vs NPC team), co-op (players vs NPC team, any headcount),
-- and PvP (player team vs player team). Draws (all teams wiped
-- simultaneously) resolve to Ended with no winner.
function CombatSession.checkVictoryConditions(self: CombatSessionObject): boolean
	if self.state ~= Enums.CombatState.Charging then
		return false
	end

	local teamsAlive: { [string]: boolean } = {}
	for _, combatant in self:getRoster() do
		if combatant:isAlive() then
			teamsAlive[combatant.teamId] = true
		end
	end

	local aliveTeamCount = 0
	local onlyTeam: string? = nil
	for teamId in teamsAlive do
		aliveTeamCount += 1
		onlyTeam = teamId
	end

	if aliveTeamCount > 1 then
		return false
	end

	if aliveTeamCount == 1 then
		self:setState(onlyTeam == Enums.TeamId.Alpha and Enums.CombatState.Victory or Enums.CombatState.Defeat)
	else
		self:setState(Enums.CombatState.Ended)
	end

	if self.config.onVictory then
		self.config.onVictory(onlyTeam)
	end

	return true
end

-- A compact, replication-friendly snapshot of the session. This is what
-- Network/CombatRemotes.lua sends to clients -- never the raw Combatant
-- objects, and never anything the client didn't already have a right to
-- see (e.g. no hidden enemy cooldown internals beyond what's listed here).
function CombatSession.toSnapshot(self: CombatSessionObject): { [string]: any }
	local combatantsSnapshot = {}
	for _, combatant in self:getRoster() do
		table.insert(combatantsSnapshot, {
			id = combatant.id,
			displayName = combatant.displayName,
			kind = combatant.kind,
			teamId = combatant.teamId,
			isAlive = combatant:isAlive(),
			actionState = combatant.actionState,
			currentHealth = combatant.currentHealth,
			maxHealth = combatant:getEffectiveStat(Enums.StatId.MaxHealth, self.currentTick),
			currentMana = combatant.currentMana,
			maxMana = combatant:getEffectiveStat(Enums.StatId.MaxMana, self.currentTick),
			speed = combatant:getEffectiveStat(Enums.StatId.Speed, self.currentTick),
			actionGauge = combatant.actionGauge,
			actionPoints = combatant.actionPoints,
			spellIds = combatant.spellIds,
			activeEffectTypes = (function()
				local types = {}
				for _, effect in combatant.activeEffects do
					table.insert(types, effect.type)
				end
				return types
			end)(),
		})
	end

	return {
		id = self.id,
		mode = self.mode,
		state = self.state,
		tick = self.currentTick,
		combatants = combatantsSnapshot,
	}
end

return CombatSession
