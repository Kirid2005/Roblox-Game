--!strict
-- Runtime combat state for one participant (player or NPC) inside a
-- CombatSession. Deliberately a plain Luau object with no dependency on
-- Roblox Instances, Players, or DataStores -- it is pure in-memory state
-- so the combat engine can be unit tested and reused across PvE, co-op,
-- and PvP without change.
--
-- Combatant is mostly a data holder plus a few read helpers (effective
-- stat, alive/stunned checks). Mutation of health/AP/gauge/effects is done
-- by the "systems" (ActionGauge, ApManager, EffectSystem) so all business
-- rules for how those numbers change live in one place each, instead of
-- being duplicated across every call site that happens to touch a
-- combatant.

local Enums = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Enums"))

local Combatant = {}
Combatant.__index = Combatant

export type StatModifier = {
	id: string,
	stat: string, -- Enums.StatId
	amount: number,
	percent: boolean,
	expiresAtTick: number,
	sourceSpellId: string?,
}

export type ActiveEffect = {
	id: string,
	type: string, -- Enums.EffectType
	amount: number?, -- pre-computed per-application amount (already scaled)
	remainingAmount: number?, -- for Shield: absorb pool left
	expiresAtTick: number,
	tickIntervalTicks: number?,
	lastTickAtTick: number,
	statusEffectId: string?,
	targetSpellId: string?, -- for ApCostModifier effects: which spell id this applies to (nil = all)
	sourceCombatantId: string?,
}

export type CombatantParams = {
	id: string,
	kind: string, -- Enums.CombatantKind
	teamId: string, -- Enums.TeamId
	displayName: string,
	player: Player?,
	baseStats: { [string]: number },
	spellIds: { string },
	cooldownTicksBySpell: { [string]: number }?,
}

export type CombatantObject = typeof(setmetatable(
	{} :: {
		id: string,
		kind: string,
		teamId: string,
		displayName: string,
		player: Player?,
		baseStats: { [string]: number },
		spellIds: { string },
		spellIdSet: { [string]: boolean },
		cooldownTicksBySpell: { [string]: number },
		cooldownExpiresAtTick: { [string]: number },
		currentHealth: number,
		currentMana: number,
		actionGauge: number,
		actionPoints: number,
		activeStatModifiers: { StatModifier },
		activeEffects: { ActiveEffect },
		actionState: string, -- Enums.CombatState, scoped to this combatant's action cycle
		isDefeated: boolean,
	},
	Combatant
))

local nextEffectId = 0
local function generateEffectId(): string
	nextEffectId += 1
	return "fx_" .. tostring(nextEffectId)
end

function Combatant.new(params: CombatantParams): CombatantObject
	local spellIdSet = {}
	for _, id in params.spellIds do
		spellIdSet[id] = true
	end

	local self = setmetatable({
		id = params.id,
		kind = params.kind,
		teamId = params.teamId,
		displayName = params.displayName,
		player = params.player,
		baseStats = params.baseStats,
		spellIds = params.spellIds,
		spellIdSet = spellIdSet,
		cooldownTicksBySpell = params.cooldownTicksBySpell or {},
		cooldownExpiresAtTick = {},
		currentHealth = params.baseStats[Enums.StatId.MaxHealth] or 1,
		currentMana = params.baseStats[Enums.StatId.MaxMana] or 0,
		actionGauge = 0,
		actionPoints = 0,
		activeStatModifiers = {},
		activeEffects = {},
		actionState = Enums.CombatState.Charging,
		isDefeated = false,
	}, Combatant)

	return self :: any
end

-- Effective stat = (base + sum of flat modifiers) * (1 + sum of percent
-- modifiers). Percent modifiers are computed against the character's base
-- value rather than compounding against each other, which keeps stacking
-- predictable and easy to reason about/balance.
function Combatant.getEffectiveStat(self: CombatantObject, statId: string, currentTick: number): number
	local base = self.baseStats[statId] or 0
	local flatSum = 0
	local percentSum = 0
	for _, mod in self.activeStatModifiers do
		if mod.stat == statId and mod.expiresAtTick > currentTick then
			if mod.percent then
				percentSum += mod.amount
			else
				flatSum += mod.amount
			end
		end
	end
	return (base + flatSum) * (1 + percentSum)
end

function Combatant.isAlive(self: CombatantObject): boolean
	return not self.isDefeated and self.currentHealth > 0
end

function Combatant.isStunned(self: CombatantObject, currentTick: number): boolean
	for _, effect in self.activeEffects do
		if effect.type == Enums.EffectType.Stun and effect.expiresAtTick > currentTick then
			return true
		end
	end
	return false
end

function Combatant.setHealth(self: CombatantObject, value: number, currentTick: number)
	local maxHealth = self:getEffectiveStat(Enums.StatId.MaxHealth, currentTick)
	self.currentHealth = math.clamp(value, 0, maxHealth)
	if self.currentHealth <= 0 then
		self.isDefeated = true
	end
end

function Combatant.addStatModifier(self: CombatantObject, mod: StatModifier)
	table.insert(self.activeStatModifiers, mod)
end

function Combatant.addActiveEffect(self: CombatantObject, effect: ActiveEffect)
	table.insert(self.activeEffects, effect)
end

function Combatant.pruneExpired(self: CombatantObject, currentTick: number)
	local keptModifiers = {}
	for _, mod in self.activeStatModifiers do
		if mod.expiresAtTick > currentTick then
			table.insert(keptModifiers, mod)
		end
	end
	self.activeStatModifiers = keptModifiers

	local keptEffects = {}
	for _, effect in self.activeEffects do
		local expired = effect.expiresAtTick <= currentTick
		local depleted = effect.type == Enums.EffectType.Shield and (effect.remainingAmount or 0) <= 0
		if not expired and not depleted then
			table.insert(keptEffects, effect)
		end
	end
	self.activeEffects = keptEffects
end

function Combatant.setCooldown(self: CombatantObject, spellId: string, currentTick: number)
	local cooldownTicks = self.cooldownTicksBySpell[spellId]
	if cooldownTicks and cooldownTicks > 0 then
		self.cooldownExpiresAtTick[spellId] = currentTick + cooldownTicks
	end
end

function Combatant.isOnCooldown(self: CombatantObject, spellId: string, currentTick: number): boolean
	local expiresAt = self.cooldownExpiresAtTick[spellId]
	return expiresAt ~= nil and expiresAt > currentTick
end

Combatant.generateEffectId = generateEffectId

return Combatant
