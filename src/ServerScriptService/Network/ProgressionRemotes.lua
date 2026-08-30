--!strict
-- Progression-facing remotes: reading a client-safe profile snapshot and
-- requesting skill tree unlocks. As with combat, the client only ever
-- asks ("unlock node X"); SkillTreeService decides whether that's legal
-- against the player's actual server-held profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local DataSchema = require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataSchema"))
local StatCalculator = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("StatCalculator"))
local SpellbookService = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("SpellbookService"))
local SkillTreeService = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("SkillTreeService"))
local RateLimiter = require(ServerScriptService:WaitForChild("Security"):WaitForChild("RateLimiter"))

local ProgressionRemotes = {}

-- Everything a client legitimately needs to render its own HUD/menus.
-- Deliberately omits server-only bookkeeping (reward ledger keys,
-- processed purchase ids, session locks) even though it all lives on the
-- same `profile.data` table.
local function buildProfileSnapshot(profileData: DataSchema.ProfileData): { [string]: any }
	return {
		level = profileData.level,
		experience = profileData.experience,
		currencies = profileData.currencies,
		derivedStats = StatCalculator.computeDerivedStats(profileData),
		learnedSpellIds = SpellbookService.getLearnedSpellIds(profileData),
		skillTree = {
			unlockedNodeIds = profileData.skillTree.unlockedNodeIds,
			availablePoints = profileData.skillTree.availablePoints,
			spentPoints = profileData.skillTree.spentPoints,
		},
		inventory = profileData.inventory,
		equipment = profileData.equipment,
		pve = profileData.pve,
		pvp = {
			rating = profileData.pvp.rating,
			wins = profileData.pvp.wins,
			losses = profileData.pvp.losses,
			currentSeasonId = profileData.pvp.currentSeasonId,
		},
	}
end

function ProgressionRemotes.setup()
	local getSnapshot = Net.getRemote("GetPlayerProfileSnapshot") :: RemoteFunction
	getSnapshot.OnServerInvoke = function(player: Player)
		local profile = PlayerDataService.getProfile(player)
		if not profile then
			return nil
		end
		return buildProfileSnapshot(profile.data)
	end

	local requestUnlock = Net.getRemote("RequestUnlockSkillNode") :: RemoteEvent
	requestUnlock.OnServerEvent:Connect(function(player: Player, nodeId: unknown)
		if typeof(nodeId) ~= "string" then
			return
		end
		if not RateLimiter.checkAndConsume(player, "RequestUnlockSkillNode", 3) then
			return
		end

		local profile = PlayerDataService.getProfile(player)
		if not profile then
			return
		end

		local ok = SkillTreeService.unlockNode(profile.data, nodeId)
		if ok then
			PlayerDataService.markDirty(player)
			local updated = Net.getRemote("ProfileUpdated") :: RemoteEvent
			updated:FireClient(player, buildProfileSnapshot(profile.data))
		end
	end)
end

ProgressionRemotes.buildProfileSnapshot = buildProfileSnapshot

return ProgressionRemotes
