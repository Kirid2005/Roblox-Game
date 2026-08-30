--!strict
-- Read-side helper over a profile's learned spells. Combat/CombatValidator
-- uses this to check spell ownership before allowing a cast; UI-facing
-- remotes use it to tell the client which spells to render.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))

local SpellbookService = {}

function SpellbookService.getLearnedSpellIds(profileData: DataSchema.ProfileData): { string }
	local ids = {}
	for spellId, learned in profileData.learnedSpells do
		if learned then
			table.insert(ids, spellId)
		end
	end
	table.sort(ids)
	return ids
end

export type OwnershipFailureReason = "UnknownSpell" | "NotLearned" | "LevelTooLow"

function SpellbookService.ownsSpell(profileData: DataSchema.ProfileData, spellId: string): (boolean, OwnershipFailureReason?)
	local spellDef = SpellCatalog[spellId]
	if not spellDef then
		return false, "UnknownSpell"
	end
	if not profileData.learnedSpells[spellId] then
		return false, "NotLearned"
	end
	if profileData.level < spellDef.requiredLevel then
		return false, "LevelTooLow"
	end
	return true
end

function SpellbookService.getUpgradeLevel(profileData: DataSchema.ProfileData, spellId: string): number
	return profileData.spellUpgrades[spellId] or 0
end

return SpellbookService
