--!strict
-- Enemy/boss stat blocks. Lives in ServerStorage (not ReplicatedStorage)
-- because there is no reason for a client to ever see an enemy's exact
-- stat sheet ahead of time -- only the combat snapshot fields
-- CombatSession.toSnapshot exposes during an actual fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

-- Shape intentionally mirrors Combat/CombatantFactory.NpcDef (displayName,
-- baseStats, spellIds) plus catalog-only metadata; not importing that type
-- directly keeps this pure-data module decoupled from combat code.
export type NpcDef = {
	id: string,
	displayName: string,
	baseStats: { [string]: number },
	spellIds: { string },
	rewardTags: { string },
}

local NPCCatalog: { [string]: NpcDef } = {}

NPCCatalog.novice_hexer = {
	id = "novice_hexer",
	displayName = "Novice Hexer",
	baseStats = {
		[Enums.StatId.MaxHealth] = 60,
		[Enums.StatId.MaxMana] = 30,
		[Enums.StatId.Speed] = 90,
		[Enums.StatId.Power] = 6,
		[Enums.StatId.Resilience] = 4,
		[Enums.StatId.CritChanceBonus] = 0,
		[Enums.StatId.FailureResistance] = 0,
	},
	spellIds = { "firebolt" },
	rewardTags = { "dungeon_trash" },
}

NPCCatalog.academy_golem = {
	id = "academy_golem",
	displayName = "Academy Golem",
	baseStats = {
		[Enums.StatId.MaxHealth] = 160,
		[Enums.StatId.MaxMana] = 10,
		[Enums.StatId.Speed] = 60,
		[Enums.StatId.Power] = 10,
		[Enums.StatId.Resilience] = 14,
		[Enums.StatId.CritChanceBonus] = 0,
		[Enums.StatId.FailureResistance] = 5,
	},
	spellIds = { "firebolt", "arc_lance" },
	rewardTags = { "dungeon_elite" },
}

NPCCatalog.headmaster_revenant = {
	id = "headmaster_revenant",
	displayName = "Headmaster's Revenant",
	baseStats = {
		[Enums.StatId.MaxHealth] = 1400,
		[Enums.StatId.MaxMana] = 200,
		[Enums.StatId.Speed] = 110,
		[Enums.StatId.Power] = 22,
		[Enums.StatId.Resilience] = 18,
		[Enums.StatId.CritChanceBonus] = 5,
		[Enums.StatId.FailureResistance] = 10,
	},
	spellIds = { "arc_lance", "inferno_wave", "meteor_call" },
	rewardTags = { "boss", "academy_boss" },
}

return NPCCatalog
