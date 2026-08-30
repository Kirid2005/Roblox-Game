--!strict
-- Every check a "cast spell X on target Y" request must pass before the
-- server executes anything. This is the concrete answer to task
-- requirement 11's checklist -- each bullet point there maps to one
-- condition below. A client can only ever ask; this module (called from
-- CombatEngine.requestCastSpell) is what actually decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local SpellCatalog = require(Shared:WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))
local CombatSession = require(script.Parent:WaitForChild("CombatSession"))
local ApManager = require(script.Parent:WaitForChild("ApManager"))

local CombatValidator = {}

export type ValidationFailureReason =
	"SessionNotActive"
	| "UnknownCombatant"
	| "NotYourCombatant"
	| "CombatantDefeated"
	| "ActionInFlight"
	| "UnknownSpell"
	| "SpellNotOwned"
	| "NotEnoughAP"
	| "OnCooldown"
	| "InvalidTarget"

export type ValidatedCast = {
	spellDef: SpellCatalog.SpellDef,
	apCost: number,
	primaryTarget: Combatant.CombatantObject?,
}

local function targetSatisfiesType(
	targetType: string,
	caster: Combatant.CombatantObject,
	target: Combatant.CombatantObject?
): boolean
	if targetType == Enums.TargetType.Self then
		return true -- caller substitutes caster as the target, no client-provided target needed
	elseif targetType == Enums.TargetType.AllEnemies or targetType == Enums.TargetType.AllAllies then
		return true -- resolved against the whole roster later, no single target required
	end

	if not target or not target:isAlive() then
		return false
	end

	if targetType == Enums.TargetType.SingleEnemy then
		return target.teamId ~= caster.teamId
	elseif targetType == Enums.TargetType.SingleAlly then
		return target.teamId == caster.teamId
	elseif targetType == Enums.TargetType.AnySingle then
		return true
	end

	return false
end

-- `requestingPlayer` is nil when the cast is being issued by server-side
-- AI on behalf of an NPC combatant; player-issued casts must always pass a
-- real Player so we can check combatant ownership.
function CombatValidator.validateCast(
	session: CombatSession.CombatSessionObject,
	requestingPlayer: Player?,
	casterId: string,
	spellId: string,
	primaryTargetId: string?
): (boolean, ValidationFailureReason?, ValidatedCast?)
	if session.state ~= Enums.CombatState.Charging then
		return false, "SessionNotActive"
	end

	local caster = session:getCombatant(casterId)
	if not caster then
		return false, "UnknownCombatant"
	end

	if requestingPlayer ~= nil and (caster.kind ~= Enums.CombatantKind.Player or caster.player ~= requestingPlayer) then
		return false, "NotYourCombatant"
	end

	if not caster:isAlive() then
		return false, "CombatantDefeated"
	end

	if caster.actionState ~= Enums.CombatState.Charging and caster.actionState ~= Enums.CombatState.ActionReady then
		return false, "ActionInFlight"
	end

	local spellDef = SpellCatalog[spellId]
	if not spellDef then
		return false, "UnknownSpell"
	end

	if not caster.spellIdSet[spellId] then
		return false, "SpellNotOwned"
	end

	if caster:isOnCooldown(spellId, session.currentTick) then
		return false, "OnCooldown"
	end

	local apCost = ApManager.getEffectiveApCost(caster, spellId, spellDef.apCost, session.currentTick)
	if not ApManager.canAfford(caster, apCost) then
		return false, "NotEnoughAP"
	end

	local primaryTarget = primaryTargetId and session:getCombatant(primaryTargetId) or nil
	if spellDef.targetType == Enums.TargetType.Self then
		primaryTarget = caster
	end

	if not targetSatisfiesType(spellDef.targetType, caster, primaryTarget) then
		return false, "InvalidTarget"
	end

	return true, nil, { spellDef = spellDef, apCost = apCost, primaryTarget = primaryTarget }
end

return CombatValidator
