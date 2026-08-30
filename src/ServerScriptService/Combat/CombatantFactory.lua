--!strict
-- Bridges progression data (a player's profile, or a static NPC
-- definition) into the plain Combatant.CombatantParams shape the combat
-- engine consumes. Kept separate from CombatEngine so the engine itself
-- never has to know how a stat sheet gets built -- only mode services and
-- this factory reach into Progression/catalog data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local SpellCatalog = require(Shared:WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))
local StatCalculator = require(script.Parent.Parent:WaitForChild("Progression"):WaitForChild("StatCalculator"))
local SpellbookService = require(script.Parent.Parent:WaitForChild("Progression"):WaitForChild("SpellbookService"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))

local CombatantFactory = {}

local function buildCooldownTable(spellIds: { string }): { [string]: number }
	local cooldowns = {}
	for _, spellId in spellIds do
		local def = SpellCatalog[spellId]
		if def and def.cooldownTicks then
			cooldowns[spellId] = def.cooldownTicks
		end
	end
	return cooldowns
end

function CombatantFactory.fromPlayer(player: Player, profileData: DataSchema.ProfileData, combatantId: string, teamId: string): Combatant.CombatantParams
	local derivedStats = StatCalculator.computeDerivedStats(profileData)

	local spellIds = {}
	for _, spellId in SpellbookService.getLearnedSpellIds(profileData) do
		local owns = select(1, SpellbookService.ownsSpell(profileData, spellId))
		if owns then
			table.insert(spellIds, spellId)
		end
	end

	return {
		id = combatantId,
		kind = Enums.CombatantKind.Player,
		teamId = teamId,
		displayName = player.Name,
		player = player,
		baseStats = derivedStats,
		spellIds = spellIds,
		cooldownTicksBySpell = buildCooldownTable(spellIds),
	}
end

export type NpcDef = {
	displayName: string,
	baseStats: { [string]: number },
	spellIds: { string },
}

function CombatantFactory.fromNpc(npcDef: NpcDef, combatantId: string, teamId: string): Combatant.CombatantParams
	return {
		id = combatantId,
		kind = Enums.CombatantKind.NPC,
		teamId = teamId,
		displayName = npcDef.displayName,
		player = nil,
		baseStats = npcDef.baseStats,
		spellIds = npcDef.spellIds,
		cooldownTicksBySpell = buildCooldownTable(npcDef.spellIds),
	}
end

return CombatantFactory
