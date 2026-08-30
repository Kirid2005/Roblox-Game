--!strict
-- Turns an EncounterDef (data) into the NPC-side Combatant params list the
-- combat engine needs. The only module that reads NPCCatalog directly for
-- the purpose of spawning a fight.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local NPCCatalog = require(ServerStorage:WaitForChild("GameData"):WaitForChild("NPCCatalog"))
local EncounterCatalog = require(ServerStorage:WaitForChild("GameData"):WaitForChild("EncounterCatalog"))

local CombatantFactory = require(script.Parent.Parent.Parent:WaitForChild("Combat"):WaitForChild("CombatantFactory"))
local Combatant = require(script.Parent.Parent.Parent:WaitForChild("Combat"):WaitForChild("Combatant"))

local EncounterFactory = {}

function EncounterFactory.buildNpcCombatants(encounterDef: EncounterCatalog.EncounterDef): { Combatant.CombatantParams }
	local params = {}
	for index, npcId in encounterDef.npcIds do
		local npcDef = NPCCatalog[npcId]
		assert(npcDef, `EncounterFactory: unknown NPC id "{npcId}" in encounter "{encounterDef.id}"`)
		local combatantId = `npc_{index}_{npcId}`
		table.insert(params, CombatantFactory.fromNpc(npcDef, combatantId, Enums.TeamId.Beta))
	end
	return params
end

return EncounterFactory
