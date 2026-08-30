--!strict
-- Plain string-keyed tables used as enums throughout the project. Luau has
-- no native enum type; using tables of constants gives us typo-safety
-- (referencing Enums.CombatState.Victory instead of a bare string) while
-- staying trivially replicable and serializable.

local Enums = {}

Enums.CombatState = {
	Waiting = "Waiting", -- session created, waiting for combatants / start signal
	Charging = "Charging", -- action gauges filling, no one has a full turn yet
	ActionReady = "ActionReady", -- one or more combatants have AP and may act
	SelectingAction = "SelectingAction", -- a specific combatant is choosing what to do
	ResolvingAction = "ResolvingAction", -- server is rolling outcomes / computing effects
	ApplyingEffects = "ApplyingEffects", -- damage/heal/status effects being applied & replicated
	WaitingForNextAction = "WaitingForNextAction", -- brief settle state before returning to Charging
	Victory = "Victory",
	Defeat = "Defeat",
	Ended = "Ended", -- terminal: session cleaned up (draw, abandoned, etc.)
}

Enums.CombatantKind = {
	Player = "Player",
	NPC = "NPC",
}

Enums.TeamId = {
	Alpha = "Alpha", -- players / attackers by convention
	Beta = "Beta", -- enemies / defenders by convention
}

Enums.TargetType = {
	SingleEnemy = "SingleEnemy",
	SingleAlly = "SingleAlly",
	Self = "Self",
	AllEnemies = "AllEnemies",
	AllAllies = "AllAllies",
	AnySingle = "AnySingle",
}

Enums.SpellElement = {
	Fire = "Fire",
	Water = "Water",
	Earth = "Earth",
	Air = "Air",
	Arcane = "Arcane",
	Light = "Light",
	Shadow = "Shadow",
	Support = "Support",
}

Enums.SpellRarity = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
}

-- Discrete outcome buckets a spell cast resolves into. Every spell's
-- OutcomeTable assigns a weight to a subset of these.
Enums.SpellOutcome = {
	CriticalSuccess = "CriticalSuccess",
	NormalSuccess = "NormalSuccess",
	NormalFailure = "NormalFailure",
	CriticalFailure = "CriticalFailure",
}

-- Generic effect "verbs" the EffectSystem knows how to apply. New gameplay
-- behavior should be expressible as a combination of these plus data,
-- rather than as bespoke per-spell code.
Enums.EffectType = {
	Damage = "Damage",
	Heal = "Heal",
	StatModifier = "StatModifier", -- e.g. Speed +20% for 3 turns
	GaugeModifier = "GaugeModifier", -- add/remove Action Gauge progress
	ApModifier = "ApModifier", -- grant/remove Action Points
	ApCostModifier = "ApCostModifier", -- change the AP cost of future casts
	DelayAction = "DelayAction", -- push a combatant's gauge backwards
	HasteAction = "HasteAction", -- push a combatant's gauge forward
	Stun = "Stun", -- prevents gauge from filling / actions from being taken
	DamageOverTime = "DamageOverTime",
	HealOverTime = "HealOverTime",
	Shield = "Shield", -- absorbs incoming damage up to an amount
}

Enums.StatId = {
	MaxHealth = "MaxHealth",
	MaxMana = "MaxMana",
	Speed = "Speed",
	Power = "Power", -- generic offensive magic scaling stat
	Resilience = "Resilience", -- generic defensive scaling stat
	CritChanceBonus = "CritChanceBonus", -- adds to a spell's CriticalSuccess weight
	FailureResistance = "FailureResistance", -- removes from a spell's failure weights
}

Enums.GameMode = {
	PvE = "PvE",
	Dungeon = "Dungeon",
	Boss = "Boss",
	PvP = "PvP",
}

Enums.RewardCurrency = {
	Gold = "Gold",
	ArcaneDust = "ArcaneDust", -- crafting/upgrade currency
	SeasonToken = "SeasonToken", -- PvP seasonal currency
	Gems = "Gems", -- premium currency
}

return Enums
