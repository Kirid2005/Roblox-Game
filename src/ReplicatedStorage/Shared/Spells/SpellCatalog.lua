--!strict
-- Data-driven spell/ability definitions.
--
-- This table is intentionally safe to replicate to clients: it contains no
-- executable probability-*resolution* logic, only the numbers that
-- describe a spell (cost, targeting, and the outcome distribution).
-- Showing players their real odds is a design goal (see task requirement
-- 8 -- "player trust" / no hidden manipulation of displayed probabilities),
-- so clients read straight from this catalog to render tooltips.
--
-- The actual dice roll, RNG seeding, and modifier stacking (talents,
-- equipment, buffs changing these odds) happens exclusively on the server
-- in ServerScriptService/Combat/SpellResolver.lua. The client never rolls
-- and never decides the result.
--
-- Adding a new spell should almost always mean adding a new entry here,
-- not writing a new script. Only give a spell a `customResolverId` when it
-- needs genuinely bespoke behavior no combination of generic Effects can
-- express; SpellResolver looks that id up in a small registry of one-off
-- handlers.

local Enums = require(script.Parent.Parent.Enums)

export type EffectTarget = "Caster" | "PrimaryTarget" | "AllEnemies" | "AllAllies" | "RandomAlly"

export type EffectSpec = {
	type: string, -- Enums.EffectType
	target: EffectTarget,
	amount: number?, -- flat component
	scalingStat: string?, -- Enums.StatId; scales `amount` by casterStat * scalingFactor
	scalingFactor: number?,
	percent: boolean?, -- when true, `amount` is a fraction (e.g. Speed +0.2 = +20%)
	duration: number?, -- in combat ticks, for DoT/HoT/StatModifier/Stun/Shield
	stat: string?, -- Enums.StatId, for StatModifier
	statusEffectId: string?, -- optional reference into StatusEffectCatalog for a bundled buff/debuff
	targetSpellId: string?, -- for ApCostModifier: which spell id this cost change applies to; nil = applies to all of the target's spells
}

export type OutcomeEntry = {
	outcome: string, -- Enums.SpellOutcome
	weight: number, -- relative weight; the table's weights are normalized at roll time
	effects: { EffectSpec },
	logMessageKey: string, -- localization/combat-log key, e.g. "spell_crit_success"
}

export type SpellDef = {
	id: string,
	displayName: string,
	description: string,
	element: string, -- Enums.SpellElement
	apCost: number,
	targetType: string, -- Enums.TargetType
	range: number?, -- nil = melee/no range gating for now; reserved for future map-aware modes
	rarity: string, -- Enums.SpellRarity
	requiredLevel: number,
	skillTreeNodeId: string?, -- must be unlocked in SkillTreeCatalog to learn this spell
	cooldownTicks: number?, -- nil = no cooldown
	outcomeTable: { OutcomeEntry },
	customResolverId: string?,
}

local SpellCatalog: { [string]: SpellDef } = {}

SpellCatalog.firebolt = {
	id = "firebolt",
	displayName = "Firebolt",
	description = "A basic bolt of flame. Cheap, but the wand can misfire.",
	element = Enums.SpellElement.Fire,
	apCost = 1,
	targetType = Enums.TargetType.SingleEnemy,
	rarity = Enums.SpellRarity.Common,
	requiredLevel = 1,
	skillTreeNodeId = nil,
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 5,
			logMessageKey = "spell_crit_success",
			effects = {
				{
					type = Enums.EffectType.Damage,
					target = "PrimaryTarget",
					amount = 10,
					scalingStat = Enums.StatId.Power,
					scalingFactor = 2.4,
				},
				{
					type = Enums.EffectType.DamageOverTime,
					target = "PrimaryTarget",
					amount = 4,
					duration = 30,
				},
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 60,
			logMessageKey = "spell_success",
			effects = {
				{
					type = Enums.EffectType.Damage,
					target = "PrimaryTarget",
					amount = 8,
					scalingStat = Enums.StatId.Power,
					scalingFactor = 1.2,
				},
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 30,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
		{
			outcome = Enums.SpellOutcome.CriticalFailure,
			weight = 5,
			logMessageKey = "spell_crit_failure",
			effects = {
				{
					type = Enums.EffectType.Damage,
					target = "Caster",
					amount = 6,
					scalingStat = Enums.StatId.Power,
					scalingFactor = 0.5,
				},
			},
		},
	},
}

SpellCatalog.arc_lance = {
	id = "arc_lance",
	displayName = "Arc Lance",
	description = "A focused lance of arcane energy. Moderate cost, moderate risk.",
	element = Enums.SpellElement.Arcane,
	apCost = 2,
	targetType = Enums.TargetType.SingleEnemy,
	rarity = Enums.SpellRarity.Uncommon,
	requiredLevel = 3,
	skillTreeNodeId = "offense_arcane_1",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 8,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "PrimaryTarget", amount = 18, scalingStat = Enums.StatId.Power, scalingFactor = 2.6 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 65,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "PrimaryTarget", amount = 16, scalingStat = Enums.StatId.Power, scalingFactor = 1.6 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 22,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
		{
			outcome = Enums.SpellOutcome.CriticalFailure,
			weight = 5,
			logMessageKey = "spell_crit_failure",
			effects = {
				{ type = Enums.EffectType.Damage, target = "Caster", amount = 10, scalingStat = Enums.StatId.Power, scalingFactor = 0.6 },
			},
		},
	},
}

SpellCatalog.inferno_wave = {
	id = "inferno_wave",
	displayName = "Inferno Wave",
	description = "A wide burst of fire that scorches every enemy. Powerful but risky at scale.",
	element = Enums.SpellElement.Fire,
	apCost = 3,
	targetType = Enums.TargetType.AllEnemies,
	rarity = Enums.SpellRarity.Rare,
	requiredLevel = 8,
	skillTreeNodeId = "offense_fire_2",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 5,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "AllEnemies", amount = 22, scalingStat = Enums.StatId.Power, scalingFactor = 2.0 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 55,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "AllEnemies", amount = 18, scalingStat = Enums.StatId.Power, scalingFactor = 1.3 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 30,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
		{
			outcome = Enums.SpellOutcome.CriticalFailure,
			weight = 10,
			logMessageKey = "spell_crit_failure",
			effects = {
				{ type = Enums.EffectType.Damage, target = "Caster", amount = 20, scalingStat = Enums.StatId.Power, scalingFactor = 0.8 },
			},
		},
	},
}

SpellCatalog.meteor_call = {
	id = "meteor_call",
	displayName = "Meteor Call",
	description = "Calls down a devastating meteor. The academy's most dangerous spell to cast.",
	element = Enums.SpellElement.Fire,
	apCost = 4,
	targetType = Enums.TargetType.SingleEnemy,
	rarity = Enums.SpellRarity.Epic,
	requiredLevel = 15,
	skillTreeNodeId = "offense_fire_3",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 10,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "PrimaryTarget", amount = 60, scalingStat = Enums.StatId.Power, scalingFactor = 3.5 },
				{ type = Enums.EffectType.Damage, target = "AllEnemies", amount = 15, scalingStat = Enums.StatId.Power, scalingFactor = 0.8 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 50,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.Damage, target = "PrimaryTarget", amount = 45, scalingStat = Enums.StatId.Power, scalingFactor = 2.5 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 30,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
		{
			outcome = Enums.SpellOutcome.CriticalFailure,
			weight = 10,
			logMessageKey = "spell_crit_failure",
			effects = {
				{ type = Enums.EffectType.Damage, target = "Caster", amount = 35, scalingStat = Enums.StatId.Power, scalingFactor = 1.2 },
				{ type = Enums.EffectType.Stun, target = "Caster", duration = 20 },
			},
		},
	},
}

SpellCatalog.minor_heal = {
	id = "minor_heal",
	displayName = "Minor Heal",
	description = "Restores health to an ally. Rarely fizzles.",
	element = Enums.SpellElement.Light,
	apCost = 1,
	targetType = Enums.TargetType.SingleAlly,
	rarity = Enums.SpellRarity.Common,
	requiredLevel = 1,
	skillTreeNodeId = nil,
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 10,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.Heal, target = "PrimaryTarget", amount = 20, scalingStat = Enums.StatId.Power, scalingFactor = 1.8 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 80,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.Heal, target = "PrimaryTarget", amount = 15, scalingStat = Enums.StatId.Power, scalingFactor = 1.1 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 10,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
	},
}

-- Support spell: grants an ally instant Action Points and a brief Speed
-- boost. This is expressed purely with generic ApModifier / StatModifier
-- effects -- no special-cased "buff ally AP" code path exists in the
-- combat engine (see task requirement 5).
SpellCatalog.haste_chant = {
	id = "haste_chant",
	displayName = "Haste Chant",
	description = "Channels tempo into an ally, instantly granting Action Points and hastening their gauge.",
	element = Enums.SpellElement.Support,
	apCost = 2,
	targetType = Enums.TargetType.SingleAlly,
	rarity = Enums.SpellRarity.Uncommon,
	requiredLevel = 5,
	skillTreeNodeId = "support_tempo_1",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 10,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.ApModifier, target = "PrimaryTarget", amount = 2 },
				{ type = Enums.EffectType.StatModifier, target = "PrimaryTarget", stat = Enums.StatId.Speed, amount = 0.3, percent = true, duration = 150 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 75,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.ApModifier, target = "PrimaryTarget", amount = 1 },
				{ type = Enums.EffectType.StatModifier, target = "PrimaryTarget", stat = Enums.StatId.Speed, amount = 0.15, percent = true, duration = 100 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 15,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
	},
}

-- Support spell: delays an enemy's Action Gauge, an example of altering
-- turn order/combat tempo rather than dealing damage.
SpellCatalog.temporal_delay = {
	id = "temporal_delay",
	displayName = "Temporal Delay",
	description = "Warps time around an enemy, setting back their Action Gauge.",
	element = Enums.SpellElement.Arcane,
	apCost = 2,
	targetType = Enums.TargetType.SingleEnemy,
	rarity = Enums.SpellRarity.Uncommon,
	requiredLevel = 6,
	skillTreeNodeId = "support_tempo_2",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 8,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.GaugeModifier, target = "PrimaryTarget", amount = -600 },
				{ type = Enums.EffectType.ApModifier, target = "PrimaryTarget", amount = -1 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 62,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.GaugeModifier, target = "PrimaryTarget", amount = -350 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 25,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
		{
			outcome = Enums.SpellOutcome.CriticalFailure,
			weight = 5,
			logMessageKey = "spell_crit_failure",
			effects = {
				{ type = Enums.EffectType.GaugeModifier, target = "Caster", amount = -400 },
			},
		},
	},
}

-- Support spell: raises a shield that absorbs damage, showing the Shield
-- effect type and a purely defensive support use case.
SpellCatalog.arcane_shield = {
	id = "arcane_shield",
	displayName = "Arcane Shield",
	description = "Wraps an ally in a barrier that absorbs incoming damage.",
	element = Enums.SpellElement.Arcane,
	apCost = 2,
	targetType = Enums.TargetType.SingleAlly,
	rarity = Enums.SpellRarity.Uncommon,
	requiredLevel = 4,
	skillTreeNodeId = "defense_arcane_1",
	outcomeTable = {
		{
			outcome = Enums.SpellOutcome.CriticalSuccess,
			weight = 10,
			logMessageKey = "spell_crit_success",
			effects = {
				{ type = Enums.EffectType.Shield, target = "PrimaryTarget", amount = 60, scalingStat = Enums.StatId.Resilience, scalingFactor = 1.5, duration = 300 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalSuccess,
			weight = 75,
			logMessageKey = "spell_success",
			effects = {
				{ type = Enums.EffectType.Shield, target = "PrimaryTarget", amount = 40, scalingStat = Enums.StatId.Resilience, scalingFactor = 1.0, duration = 250 },
			},
		},
		{
			outcome = Enums.SpellOutcome.NormalFailure,
			weight = 15,
			logMessageKey = "spell_fizzle",
			effects = {},
		},
	},
}

return SpellCatalog
