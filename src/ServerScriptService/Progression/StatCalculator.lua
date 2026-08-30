--!strict
-- Pure functions that turn a player's persistent profile data into the
-- derived numbers combat actually uses (final stats, AP costs). Kept free
-- of DataStore/Player/Instance references so it can be unit tested with
-- plain tables (see ServerScriptService/Tests/StatCalculator.spec.lua).
--
-- Order of composition: base stats -> + equipment -> + skill tree grants.
-- Temporary combat buffs/debuffs are NOT applied here; those live on the
-- runtime Combatant (see Combat/Combatant.lua) and are layered on top of
-- whatever this module returns when a combat session starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemCatalog = require(Shared:WaitForChild("Items"):WaitForChild("ItemCatalog"))
local SkillTreeCatalog = require(Shared:WaitForChild("SkillTree"):WaitForChild("SkillTreeCatalog"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))

local StatCalculator = {}

export type DerivedStats = { [string]: number }

function StatCalculator.computeDerivedStats(profileData: DataSchema.ProfileData): DerivedStats
	local derived: DerivedStats = {}
	for stat, value in profileData.baseStats do
		derived[stat] = value
	end

	for _, itemId in profileData.equipment do
		if itemId then
			local item = ItemCatalog[itemId]
			if item then
				for stat, bonus in item.statModifiers do
					derived[stat] = (derived[stat] or 0) + bonus
				end
			end
		end
	end

	for nodeId in profileData.skillTree.unlockedNodeIds do
		local node = SkillTreeCatalog[nodeId]
		if node and node.grants.statModifiers then
			for stat, bonus in node.grants.statModifiers do
				derived[stat] = (derived[stat] or 0) + bonus
			end
		end
	end

	return derived
end

-- Resolves the effective AP cost of a spell for this profile, applying any
-- skill-tree AP cost modifiers. Cost can never go below 1 -- a spell that
-- costs 0 AP would break the gauge/AP gate entirely.
function StatCalculator.computeSpellApCost(profileData: DataSchema.ProfileData, spellId: string, baseApCost: number): number
	local cost = baseApCost
	for nodeId in profileData.skillTree.unlockedNodeIds do
		local node = SkillTreeCatalog[nodeId]
		local modifiers = node and node.grants.apCostModifiers
		if modifiers and modifiers[spellId] then
			cost += modifiers[spellId]
		end
	end
	return math.max(1, cost)
end

function StatCalculator.hasLearnedSpell(profileData: DataSchema.ProfileData, spellId: string): boolean
	return profileData.learnedSpells[spellId] == true
end

return StatCalculator
