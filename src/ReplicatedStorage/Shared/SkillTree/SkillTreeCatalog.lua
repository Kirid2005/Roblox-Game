--!strict
-- Data-driven skill tree. Each node is pure configuration: what it costs,
-- what it requires, and what it grants. SkillTreeService (server) is the
-- only thing that mutates a player's unlocked-node set; this catalog is
-- safe to replicate so the client can render the tree and gray out
-- unmet-requirement nodes.

local Enums = require(script.Parent.Parent.Enums)

export type NodeGrant = {
	statModifiers: { [string]: number }?, -- Enums.StatId -> flat bonus applied permanently
	spellUnlocks: { string }?, -- spell ids from SpellCatalog this node unlocks
	apCostModifiers: { [string]: number }?, -- spell id -> AP cost delta (can reduce, floor is 1)
}

export type SkillNode = {
	id: string,
	displayName: string,
	description: string,
	branch: string, -- e.g. "Offense", "Defense", "Support", "RiskReward", "Tempo"
	requiredNodeIds: { string }, -- must all be unlocked first
	pointCost: number,
	requiredLevel: number,
	grants: NodeGrant,
}

local SkillTreeCatalog: { [string]: SkillNode } = {}

local function addNode(node: SkillNode)
	SkillTreeCatalog[node.id] = node
end

addNode({
	id = "offense_arcane_1",
	displayName = "Arcane Focus I",
	description = "Unlocks Arc Lance and grants +5 Power.",
	branch = "Offense",
	requiredNodeIds = {},
	pointCost = 1,
	requiredLevel = 3,
	grants = {
		statModifiers = { [Enums.StatId.Power] = 5 },
		spellUnlocks = { "arc_lance" },
	},
})

addNode({
	id = "offense_fire_2",
	displayName = "Pyromancy II",
	description = "Unlocks Inferno Wave and grants +8 Power.",
	branch = "Offense",
	requiredNodeIds = { "offense_arcane_1" },
	pointCost = 2,
	requiredLevel = 8,
	grants = {
		statModifiers = { [Enums.StatId.Power] = 8 },
		spellUnlocks = { "inferno_wave" },
	},
})

addNode({
	id = "offense_fire_3",
	displayName = "Pyromancy III",
	description = "Unlocks Meteor Call, the academy's most feared spell.",
	branch = "Offense",
	requiredNodeIds = { "offense_fire_2" },
	pointCost = 3,
	requiredLevel = 15,
	grants = {
		statModifiers = { [Enums.StatId.Power] = 12 },
		spellUnlocks = { "meteor_call" },
	},
})

addNode({
	id = "defense_arcane_1",
	displayName = "Ward Craft I",
	description = "Unlocks Arcane Shield and grants +5 Resilience.",
	branch = "Defense",
	requiredNodeIds = {},
	pointCost = 1,
	requiredLevel = 4,
	grants = {
		statModifiers = { [Enums.StatId.Resilience] = 5 },
		spellUnlocks = { "arcane_shield" },
	},
})

addNode({
	id = "support_tempo_1",
	displayName = "Tempo Manipulation I",
	description = "Unlocks Haste Chant and grants +5% Failure Resistance on support spells.",
	branch = "Support",
	requiredNodeIds = {},
	pointCost = 1,
	requiredLevel = 5,
	grants = {
		statModifiers = { [Enums.StatId.FailureResistance] = 5 },
		spellUnlocks = { "haste_chant" },
	},
})

addNode({
	id = "support_tempo_2",
	displayName = "Tempo Manipulation II",
	description = "Unlocks Temporal Delay and grants +5 Speed.",
	branch = "Support",
	requiredNodeIds = { "support_tempo_1" },
	pointCost = 2,
	requiredLevel = 6,
	grants = {
		statModifiers = { [Enums.StatId.Speed] = 5 },
		spellUnlocks = { "temporal_delay" },
	},
})

addNode({
	id = "riskreward_gambit_1",
	displayName = "Gambit I",
	description = "You live for the high roll. +5% Critical Success chance bonus applied across all spells.",
	branch = "RiskReward",
	requiredNodeIds = {},
	pointCost = 2,
	requiredLevel = 10,
	grants = {
		statModifiers = { [Enums.StatId.CritChanceBonus] = 5 },
	},
})

return SkillTreeCatalog
