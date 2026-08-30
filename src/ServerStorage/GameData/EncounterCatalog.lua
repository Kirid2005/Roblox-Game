--!strict
-- Data-driven dungeon rooms/encounters. DungeonService and
-- BossEncounterService both read this rather than hard-coding which NPCs
-- spawn where -- adding new content is adding an entry here (plus NPC
-- entries in NPCCatalog if needed), not writing a new script.

export type EncounterDef = {
	id: string,
	displayName: string,
	npcIds: { string }, -- NPCCatalog ids spawned as team Beta
	minPlayers: number,
	maxPlayers: number,
	isBossEncounter: boolean,
	rewardTableId: string, -- Rewards/RewardTables.lua key
}

local EncounterCatalog: { [string]: EncounterDef } = {}

EncounterCatalog.academy_corridor_1 = {
	id = "academy_corridor_1",
	displayName = "Lower Corridor Ambush",
	npcIds = { "novice_hexer", "novice_hexer" },
	minPlayers = 1,
	maxPlayers = 4,
	isBossEncounter = false,
	rewardTableId = "dungeon_trash",
}

EncounterCatalog.academy_corridor_2 = {
	id = "academy_corridor_2",
	displayName = "Golem Guard Post",
	npcIds = { "academy_golem", "novice_hexer" },
	minPlayers = 1,
	maxPlayers = 4,
	isBossEncounter = false,
	rewardTableId = "dungeon_elite",
}

EncounterCatalog.headmaster_boss_room = {
	id = "headmaster_boss_room",
	displayName = "The Headmaster's Study",
	npcIds = { "headmaster_revenant" },
	minPlayers = 1,
	maxPlayers = 8,
	isBossEncounter = true,
	rewardTableId = "academy_boss",
}

return EncounterCatalog
