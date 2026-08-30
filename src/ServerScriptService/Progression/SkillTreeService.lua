--!strict
-- Validates and applies skill tree node unlocks. This is the only module
-- allowed to mutate profile.skillTree / profile.learnedSpells for a node
-- unlock -- the RemoteEvent handler in Network/ProgressionRemotes.lua just
-- calls into here and trusts nothing else from the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillTreeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillTree"):WaitForChild("SkillTreeCatalog"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))

local SkillTreeService = {}

export type UnlockFailureReason = "UnknownNode" | "AlreadyUnlocked" | "LevelTooLow" | "MissingPrerequisite" | "NotEnoughPoints"

function SkillTreeService.canUnlock(profileData: DataSchema.ProfileData, nodeId: string): (boolean, UnlockFailureReason?)
	local node = SkillTreeCatalog[nodeId]
	if not node then
		return false, "UnknownNode"
	end
	if profileData.skillTree.unlockedNodeIds[nodeId] then
		return false, "AlreadyUnlocked"
	end
	if profileData.level < node.requiredLevel then
		return false, "LevelTooLow"
	end
	for _, prereqId in node.requiredNodeIds do
		if not profileData.skillTree.unlockedNodeIds[prereqId] then
			return false, "MissingPrerequisite"
		end
	end
	if profileData.skillTree.availablePoints < node.pointCost then
		return false, "NotEnoughPoints"
	end
	return true
end

function SkillTreeService.unlockNode(profileData: DataSchema.ProfileData, nodeId: string): (boolean, UnlockFailureReason?)
	local ok, reason = SkillTreeService.canUnlock(profileData, nodeId)
	if not ok then
		return false, reason
	end

	local node = SkillTreeCatalog[nodeId]
	profileData.skillTree.unlockedNodeIds[nodeId] = true
	profileData.skillTree.availablePoints -= node.pointCost
	profileData.skillTree.spentPoints += node.pointCost

	if node.grants.spellUnlocks then
		for _, spellId in node.grants.spellUnlocks do
			profileData.learnedSpells[spellId] = true
		end
	end

	return true
end

return SkillTreeService
