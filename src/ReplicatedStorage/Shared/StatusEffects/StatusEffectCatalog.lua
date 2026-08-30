--!strict
-- Metadata for *named* status effects: display info and stacking rules.
-- Individual spell effects (see SpellCatalog EffectSpec) can either be
-- anonymous (a one-off StatModifier/DamageOverTime with no catalog entry,
-- stacking freely) or reference one of these ids via `statusEffectId` to
-- get a shared icon/name and an explicit stacking policy -- e.g. so five
-- different "Burning" sources don't each apply an independent DoT stack
-- when the design calls for a single refreshing burn.

export type StackingRule = "Refresh" | "Stack" | "Ignore"

export type StatusEffectDef = {
	id: string,
	displayName: string,
	description: string,
	category: "Buff" | "Debuff" | "Neutral",
	stackingRule: StackingRule,
	maxStacks: number,
	tickIntervalTicks: number?, -- for DoT/HoT: how often (in combat ticks) it pulses
}

local StatusEffectCatalog: { [string]: StatusEffectDef } = {}

StatusEffectCatalog.burning = {
	id = "burning",
	displayName = "Burning",
	description = "Taking fire damage over time.",
	category = "Debuff",
	stackingRule = "Refresh",
	maxStacks = 1,
	tickIntervalTicks = 10,
}

StatusEffectCatalog.hastened = {
	id = "hastened",
	displayName = "Hastened",
	description = "Speed increased.",
	category = "Buff",
	stackingRule = "Refresh",
	maxStacks = 1,
}

StatusEffectCatalog.delayed = {
	id = "delayed",
	displayName = "Delayed",
	description = "Action Gauge progress has been set back.",
	category = "Debuff",
	stackingRule = "Ignore",
	maxStacks = 1,
}

StatusEffectCatalog.stunned = {
	id = "stunned",
	displayName = "Stunned",
	description = "Action Gauge cannot fill.",
	category = "Debuff",
	stackingRule = "Refresh",
	maxStacks = 1,
}

StatusEffectCatalog.shielded = {
	id = "shielded",
	displayName = "Shielded",
	description = "Absorbing incoming damage.",
	category = "Buff",
	stackingRule = "Stack",
	maxStacks = 3,
}

StatusEffectCatalog.boss_enrage = {
	id = "boss_enrage",
	displayName = "Enraged",
	description = "This boss has entered an enraged phase.",
	category = "Debuff",
	stackingRule = "Ignore",
	maxStacks = 1,
}

return StatusEffectCatalog
