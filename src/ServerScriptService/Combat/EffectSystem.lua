--!strict
-- Generic effect/modifier engine. Every gameplay verb a spell can perform
-- (damage, heal, buff, debuff, gauge/AP manipulation, stun, shield) is
-- expressed as data (see SpellCatalog.EffectSpec) and dispatched here.
--
-- This is the module that makes task requirement 5 possible: adding a new
-- kind of tempo manipulation should mean adding a new EffectType case here
-- (or, for the common case of "existing verb, new numbers", nothing at all
-- -- just a new spell entry in the catalog) rather than special-casing a
-- spell inside the combat engine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))
local ActionGauge = require(script.Parent:WaitForChild("ActionGauge"))
local ApManager = require(script.Parent:WaitForChild("ApManager"))
local DamageCalculator = require(script.Parent:WaitForChild("DamageCalculator"))

local EffectSystem = {}

export type AppliedEffectLog = {
	effectType: string,
	targetId: string,
	amount: number?,
}

local DEFAULT_DOT_HOT_INTERVAL_TICKS = 10

-- Resolves an effect spec's declarative `target` into concrete Combatants.
-- `roster` is every combatant in the session (both teams), so team-wide
-- effects (AllEnemies/AllAllies) can be computed relative to the caster.
function EffectSystem.resolveTargets(
	effectTarget: string,
	caster: Combatant.CombatantObject,
	primaryTarget: Combatant.CombatantObject?,
	roster: { Combatant.CombatantObject },
	rng: Random
): { Combatant.CombatantObject }
	if effectTarget == "Caster" then
		return { caster }
	elseif effectTarget == "PrimaryTarget" then
		if primaryTarget then
			return { primaryTarget }
		end
		return {}
	elseif effectTarget == "AllEnemies" then
		local results = {}
		for _, c in roster do
			if c.teamId ~= caster.teamId and c:isAlive() then
				table.insert(results, c)
			end
		end
		return results
	elseif effectTarget == "AllAllies" then
		local results = {}
		for _, c in roster do
			if c.teamId == caster.teamId and c:isAlive() then
				table.insert(results, c)
			end
		end
		return results
	elseif effectTarget == "RandomAlly" then
		local candidates = {}
		for _, c in roster do
			if c.teamId == caster.teamId and c:isAlive() then
				table.insert(candidates, c)
			end
		end
		if #candidates == 0 then
			return {}
		end
		return { candidates[rng:NextInteger(1, #candidates)] }
	end
	return {}
end

function EffectSystem.applyDamage(target: Combatant.CombatantObject, rawAmount: number, currentTick: number): (number, number)
	local remaining = rawAmount
	local totalAbsorbed = 0

	for _, effect in target.activeEffects do
		if remaining <= 0 then
			break
		end
		if effect.type == Enums.EffectType.Shield and effect.expiresAtTick > currentTick and (effect.remainingAmount or 0) > 0 then
			local afterShield, absorbed = DamageCalculator.applyShieldAbsorption(remaining, effect.remainingAmount :: number)
			effect.remainingAmount = (effect.remainingAmount :: number) - absorbed
			remaining = afterShield
			totalAbsorbed += absorbed
		end
	end

	target:setHealth(target.currentHealth - remaining, currentTick)
	return remaining, totalAbsorbed
end

function EffectSystem.applyHeal(target: Combatant.CombatantObject, amount: number, currentTick: number): number
	local maxHealth = target:getEffectiveStat(Enums.StatId.MaxHealth, currentTick)
	local before = target.currentHealth
	target:setHealth(target.currentHealth + amount, currentTick)
	return target.currentHealth - before
end

-- Applies one EffectSpec (from a resolved spell outcome) to whichever
-- combatants its `target` field resolves to. Returns a log of what
-- actually happened, for the combat log / client replication.
function EffectSystem.applyEffectSpec(
	spec: { [string]: any },
	caster: Combatant.CombatantObject,
	primaryTarget: Combatant.CombatantObject?,
	roster: { Combatant.CombatantObject },
	currentTick: number,
	rng: Random
): { AppliedEffectLog }
	local targets = EffectSystem.resolveTargets(spec.target, caster, primaryTarget, roster, rng)
	local logs: { AppliedEffectLog } = {}

	local getCasterStat = function(statId: string): number
		return caster:getEffectiveStat(statId, currentTick)
	end

	for _, target in targets do
		if spec.type == Enums.EffectType.Damage then
			local amount = DamageCalculator.computeAmount(spec, getCasterStat)
			local applied = select(1, EffectSystem.applyDamage(target, amount, currentTick))
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = applied })
		elseif spec.type == Enums.EffectType.Heal then
			local amount = DamageCalculator.computeAmount(spec, getCasterStat)
			local applied = EffectSystem.applyHeal(target, amount, currentTick)
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = applied })
		elseif spec.type == Enums.EffectType.StatModifier then
			local duration = spec.duration or math.huge
			target:addStatModifier({
				id = Combatant.generateEffectId(),
				stat = spec.stat,
				amount = spec.amount or 0,
				percent = spec.percent == true,
				expiresAtTick = currentTick + duration,
				sourceSpellId = spec.sourceSpellId,
			})
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = spec.amount })
		elseif spec.type == Enums.EffectType.GaugeModifier
			or spec.type == Enums.EffectType.DelayAction
			or spec.type == Enums.EffectType.HasteAction
		then
			local granted = ActionGauge.applyDelta(target, spec.amount or 0)
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = spec.amount })
			if granted > 0 and target.actionState == Enums.CombatState.Charging then
				target.actionState = Enums.CombatState.ActionReady
			end
		elseif spec.type == Enums.EffectType.ApModifier then
			ApManager.grant(target, spec.amount or 0)
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = spec.amount })
			if target.actionPoints > 0 and target.actionState == Enums.CombatState.Charging then
				target.actionState = Enums.CombatState.ActionReady
			end
		elseif spec.type == Enums.EffectType.ApCostModifier then
			local duration = spec.duration or math.huge
			target:addActiveEffect({
				id = Combatant.generateEffectId(),
				type = spec.type,
				amount = spec.amount or 0,
				expiresAtTick = currentTick + duration,
				lastTickAtTick = currentTick,
				targetSpellId = spec.targetSpellId,
			})
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = spec.amount })
		elseif spec.type == Enums.EffectType.Stun then
			local duration = spec.duration or DEFAULT_DOT_HOT_INTERVAL_TICKS
			target:addActiveEffect({
				id = Combatant.generateEffectId(),
				type = Enums.EffectType.Stun,
				expiresAtTick = currentTick + duration,
				lastTickAtTick = currentTick,
				statusEffectId = spec.statusEffectId,
			})
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = duration })
		elseif spec.type == Enums.EffectType.DamageOverTime or spec.type == Enums.EffectType.HealOverTime then
			local perTick = DamageCalculator.computeAmount(spec, getCasterStat)
			local duration = spec.duration or DEFAULT_DOT_HOT_INTERVAL_TICKS * 3
			target:addActiveEffect({
				id = Combatant.generateEffectId(),
				type = spec.type,
				amount = perTick,
				expiresAtTick = currentTick + duration,
				tickIntervalTicks = spec.tickIntervalTicks or DEFAULT_DOT_HOT_INTERVAL_TICKS,
				lastTickAtTick = currentTick,
				statusEffectId = spec.statusEffectId,
				sourceCombatantId = caster.id,
			})
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = perTick })
		elseif spec.type == Enums.EffectType.Shield then
			local amount = DamageCalculator.computeAmount(spec, getCasterStat)
			local duration = spec.duration or DEFAULT_DOT_HOT_INTERVAL_TICKS * 3
			target:addActiveEffect({
				id = Combatant.generateEffectId(),
				type = Enums.EffectType.Shield,
				remainingAmount = amount,
				expiresAtTick = currentTick + duration,
				lastTickAtTick = currentTick,
				statusEffectId = spec.statusEffectId,
			})
			table.insert(logs, { effectType = spec.type, targetId = target.id, amount = amount })
		else
			warn(`[EffectSystem] Unknown effect type "{tostring(spec.type)}"`)
		end
	end

	return logs
end

-- Called once per combat tick per combatant to pulse DoT/HoT effects whose
-- interval has elapsed, and to prune anything that has expired.
function EffectSystem.tickPeriodicEffects(combatant: Combatant.CombatantObject, currentTick: number): { AppliedEffectLog }
	local logs: { AppliedEffectLog } = {}

	for _, effect in combatant.activeEffects do
		if effect.expiresAtTick > currentTick and effect.tickIntervalTicks then
			if currentTick - effect.lastTickAtTick >= effect.tickIntervalTicks then
				effect.lastTickAtTick = currentTick
				if effect.type == Enums.EffectType.DamageOverTime then
					local applied = select(1, EffectSystem.applyDamage(combatant, effect.amount or 0, currentTick))
					table.insert(logs, { effectType = effect.type, targetId = combatant.id, amount = applied })
				elseif effect.type == Enums.EffectType.HealOverTime then
					local applied = EffectSystem.applyHeal(combatant, effect.amount or 0, currentTick)
					table.insert(logs, { effectType = effect.type, targetId = combatant.id, amount = applied })
				end
			end
		end
	end

	combatant:pruneExpired(currentTick)
	return logs
end

return EffectSystem
