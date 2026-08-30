--!strict
-- Character leveling. The XP curve lives in one place (Constants) and this
-- module is the only thing allowed to mutate profile.level/experience, so
-- every XP source (PvE rewards, PvP rewards, quests, monetization boosts)
-- goes through the same, server-authoritative path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))

local ExperienceService = {}

function ExperienceService.xpRequiredForLevel(level: number): number
	return math.floor(Constants.XP_BASE * (Constants.XP_GROWTH ^ (level - 1)))
end

export type GrantResult = {
	levelsGained: number,
	newLevel: number,
	skillPointsGranted: number,
}

-- `bonusMultiplier` lets monetization (e.g. an XP boost gamepass) scale
-- gains, but is clamped here too -- defense in depth alongside whatever
-- cap MonetizationService applies -- so a bug or bad config elsewhere can
-- never grant more than the documented pay-to-progress ceiling.
function ExperienceService.grantExperience(profileData: DataSchema.ProfileData, amount: number, bonusMultiplier: number?): GrantResult
	assert(amount >= 0, "ExperienceService.grantExperience: amount must be non-negative")

	local clampedMultiplier = math.clamp(bonusMultiplier or 1, 1, 1 + Constants.MAX_MONETIZATION_ADVANTAGE)
	local grantedAmount = math.floor(amount * clampedMultiplier)

	local levelsGained = 0
	local skillPointsGranted = 0

	if profileData.level >= Constants.MAX_CHARACTER_LEVEL then
		return { levelsGained = 0, newLevel = profileData.level, skillPointsGranted = 0 }
	end

	profileData.experience += grantedAmount

	while profileData.level < Constants.MAX_CHARACTER_LEVEL do
		local required = ExperienceService.xpRequiredForLevel(profileData.level)
		if profileData.experience < required then
			break
		end
		profileData.experience -= required
		profileData.level += 1
		levelsGained += 1
		skillPointsGranted += 1
		profileData.skillTree.availablePoints += 1
	end

	if profileData.level >= Constants.MAX_CHARACTER_LEVEL then
		profileData.experience = 0
	end

	return {
		levelsGained = levelsGained,
		newLevel = profileData.level,
		skillPointsGranted = skillPointsGranted,
	}
end

return ExperienceService
