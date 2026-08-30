--!strict
-- Server-authoritative probability resolution for spell casts. This is the
-- ONLY place a spell's outcome is rolled. The client never sees random
-- numbers used for combat resolution -- it only ever receives the final,
-- already-decided CastResult.
--
-- Design goals from the spec:
--   * Configurable per-spell distributions (SpellCatalog.outcomeTable).
--   * Stat-driven modifiers (CritChanceBonus, FailureResistance) rather
--     than special-cased per spell, so talents/equipment/buffs can shift
--     odds uniformly.
--   * Deterministic when given a seeded `Random`, so the exact same
--     (spell, stats, roll) reproduces the same outcome -- useful for
--     debugging and for the ProbabilitySimulator dev tool, which mass-
--     simulates casts to inspect the realized distribution.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local SpellCatalog = require(Shared:WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))
local ApManager = require(script.Parent:WaitForChild("ApManager"))
local EffectSystem = require(script.Parent:WaitForChild("EffectSystem"))

local SpellResolver = {}

export type OutcomeModifiers = {
	critChanceBonus: number,
	failureResistance: number,
}

export type CastResult = {
	spellId: string,
	casterId: string,
	primaryTargetId: string?,
	outcome: string,
	logMessageKey: string,
	appliedEffects: { EffectSystem.AppliedEffectLog },
}

-- Produces a copy of the spell's outcome table with weights nudged by the
-- caster's stats. Weights are only ever adjusted, never allowed to go
-- negative; the table does not need to sum to any particular total since
-- SpellResolver.rollOutcome normalizes at roll time.
function SpellResolver.buildAdjustedOutcomeTable(
	outcomeTable: { SpellCatalog.OutcomeEntry },
	modifiers: OutcomeModifiers
): { SpellCatalog.OutcomeEntry }
	local adjusted = {}
	for _, entry in outcomeTable do
		local weight = entry.weight
		if entry.outcome == Enums.SpellOutcome.CriticalSuccess then
			weight += modifiers.critChanceBonus
		elseif entry.outcome == Enums.SpellOutcome.CriticalFailure then
			weight -= modifiers.failureResistance
		end
		weight = math.max(0, weight)

		table.insert(adjusted, {
			outcome = entry.outcome,
			weight = weight,
			effects = entry.effects,
			logMessageKey = entry.logMessageKey,
		})
	end
	return adjusted
end

-- `rng` needs only a `:NextNumber(): number` method (duck-typed), so tests
-- can pass a fake sequence generator instead of a real Random instance.
function SpellResolver.rollOutcome(adjustedOutcomeTable: { SpellCatalog.OutcomeEntry }, rng: { NextNumber: (any) -> number }): SpellCatalog.OutcomeEntry
	local totalWeight = 0
	for _, entry in adjustedOutcomeTable do
		totalWeight += entry.weight
	end
	assert(totalWeight > 0, "SpellResolver.rollOutcome: total weight must be positive")

	local roll = rng:NextNumber() * totalWeight
	local cumulative = 0
	for _, entry in adjustedOutcomeTable do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry
		end
	end
	-- Floating point fallback: return the last entry rather than nil.
	return adjustedOutcomeTable[#adjustedOutcomeTable]
end

export type ResolveCastParams = {
	spellDef: SpellCatalog.SpellDef,
	caster: Combatant.CombatantObject,
	primaryTarget: Combatant.CombatantObject?,
	roster: { Combatant.CombatantObject },
	currentTick: number,
	rng: Random,
}

function SpellResolver.resolveCast(params: ResolveCastParams): CastResult
	local caster = params.caster
	local currentTick = params.currentTick

	local modifiers: OutcomeModifiers = {
		critChanceBonus = caster:getEffectiveStat(Enums.StatId.CritChanceBonus, currentTick),
		failureResistance = caster:getEffectiveStat(Enums.StatId.FailureResistance, currentTick),
	}

	local adjustedTable = SpellResolver.buildAdjustedOutcomeTable(params.spellDef.outcomeTable, modifiers)
	local chosenOutcome = SpellResolver.rollOutcome(adjustedTable, params.rng)

	local appliedEffects: { EffectSystem.AppliedEffectLog } = {}
	for _, effectSpec in chosenOutcome.effects do
		local logs = EffectSystem.applyEffectSpec(effectSpec, caster, params.primaryTarget, params.roster, currentTick, params.rng)
		for _, log in logs do
			table.insert(appliedEffects, log)
		end
	end

	if params.spellDef.cooldownTicks then
		caster:setCooldown(params.spellDef.id, currentTick)
	end

	return {
		spellId = params.spellDef.id,
		casterId = caster.id,
		primaryTargetId = params.primaryTarget and params.primaryTarget.id or nil,
		outcome = chosenOutcome.outcome,
		logMessageKey = chosenOutcome.logMessageKey,
		appliedEffects = appliedEffects,
	}
end

return SpellResolver
