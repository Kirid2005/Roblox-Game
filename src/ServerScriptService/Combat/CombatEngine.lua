--!strict
-- The reusable, mode-agnostic combat orchestrator. Mode services (PvE
-- dungeon, boss encounters, PvP matches) call CombatEngine.createSession
-- with a roster and get back a live CombatSession; the network layer calls
-- CombatEngine.requestCastSpell for every client cast request;
-- TurnScheduler calls CombatEngine.tick every server frame.
--
-- Nothing in this module knows about RemoteEvents, DataStores, UI, or any
-- specific game mode's win/loss rewards -- it only knows the combat state
-- machine described in the task spec (Waiting -> Charging -> ... ->
-- Victory/Defeat/Ended) and how to move combatants through it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))
local CombatSession = require(script.Parent:WaitForChild("CombatSession"))
local CombatRegistry = require(script.Parent:WaitForChild("CombatRegistry"))
local CombatValidator = require(script.Parent:WaitForChild("CombatValidator"))
local ActionGauge = require(script.Parent:WaitForChild("ActionGauge"))
local ApManager = require(script.Parent:WaitForChild("ApManager"))
local EffectSystem = require(script.Parent:WaitForChild("EffectSystem"))
local SpellResolver = require(script.Parent:WaitForChild("SpellResolver"))

local CombatEngine = {}

function CombatEngine.createSession(
	mode: string,
	combatantParamsList: { Combatant.CombatantParams },
	config: CombatSession.SessionConfig?,
	seed: number?
): CombatSession.CombatSessionObject
	local combatants = {}
	for _, params in combatantParamsList do
		table.insert(combatants, Combatant.new(params))
	end

	local id = CombatRegistry.generateSessionId(mode)
	local session = CombatSession.new(id, mode, combatants, config, seed)
	CombatRegistry.register(session)
	session:start()
	return session
end

function CombatEngine.endSession(session: CombatSession.CombatSessionObject)
	if session.state ~= Enums.CombatState.Victory and session.state ~= Enums.CombatState.Defeat then
		session:setState(Enums.CombatState.Ended)
	end
	CombatRegistry.unregister(session.id)
end

export type CastRequestResult = {
	ok: boolean,
	reason: CombatValidator.ValidationFailureReason?,
	castResult: SpellResolver.CastResult?,
}

-- The single entrypoint for "I want to cast spell X on target Y". Every
-- client-triggered cast (see Network/CombatRemotes.lua) and every
-- server-driven NPC/AI cast goes through this same path, so validation can
-- never be accidentally skipped for one call site but not another.
function CombatEngine.requestCastSpell(
	session: CombatSession.CombatSessionObject,
	requestingPlayer: Player?,
	casterId: string,
	spellId: string,
	primaryTargetId: string?
): CastRequestResult
	local ok, reason, validated = CombatValidator.validateCast(session, requestingPlayer, casterId, spellId, primaryTargetId)
	if not ok or not validated then
		return { ok = false, reason = reason, castResult = nil }
	end

	local caster = session:getCombatant(casterId) :: Combatant.CombatantObject
	caster.actionState = Enums.CombatState.ResolvingAction

	local spent = ApManager.spend(caster, validated.apCost)
	if not spent then
		-- Defensive: validation already checked affordability; this would
		-- only trip on an engine bug, not a client exploit.
		caster.actionState = Enums.CombatState.Charging
		return { ok = false, reason = "NotEnoughAP", castResult = nil }
	end

	local castResult = SpellResolver.resolveCast({
		spellDef = validated.spellDef,
		caster = caster,
		primaryTarget = validated.primaryTarget,
		roster = session:getRoster(),
		currentTick = session.currentTick,
		rng = session.rng,
	})

	caster.actionState = Enums.CombatState.ApplyingEffects
	session:log("Cast", castResult :: any)

	caster.actionState = Enums.CombatState.WaitingForNextAction
	caster.actionState = Enums.CombatState.Charging

	session:checkVictoryConditions()

	return { ok = true, reason = nil, castResult = castResult }
end

-- Advances one session by `dt` seconds of server time. Called by
-- TurnScheduler for every active session on a fixed cadence.
function CombatEngine.tick(session: CombatSession.CombatSessionObject, dt: number)
	if session.state ~= Enums.CombatState.Charging then
		return
	end

	session.currentTick += 1

	for _, combatant in session:getRoster() do
		if combatant:isAlive() then
			ActionGauge.advance(combatant, dt, session.currentTick)
			if combatant.actionPoints > 0 and combatant.actionState == Enums.CombatState.Charging then
				combatant.actionState = Enums.CombatState.ActionReady
			end
			EffectSystem.tickPeriodicEffects(combatant, session.currentTick)
		end
	end

	if session.config.onTick then
		session.config.onTick(session)
	end

	session:checkVictoryConditions()
end

return CombatEngine
