--!strict
-- Thin client-side wrapper over Net.lua: turns server push events into
-- local Signals other client controllers subscribe to, and exposes small
-- request functions for the things the client is allowed to ask for.
--
-- No combat/economy logic lives here -- this module never decides
-- anything, it only relays. CombatController is what interprets a
-- CombatStateUpdated payload into UI-friendly state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local RemoteClient = {}

RemoteClient.CombatStateUpdated = Signal.new()
RemoteClient.CombatLogEvent = Signal.new()
RemoteClient.CombatEnded = Signal.new()
RemoteClient.PvpMatchFound = Signal.new()
RemoteClient.ProfileUpdated = Signal.new()

local initialized = false

function RemoteClient.init()
	if initialized then
		return
	end
	initialized = true

	local combatStateUpdated = Net.getRemote("CombatStateUpdated") :: RemoteEvent
	combatStateUpdated.OnClientEvent:Connect(function(snapshot)
		RemoteClient.CombatStateUpdated:Fire(snapshot)
	end)

	local combatLogEvent = Net.getRemote("CombatLogEvent") :: RemoteEvent
	combatLogEvent.OnClientEvent:Connect(function(entry)
		RemoteClient.CombatLogEvent:Fire(entry)
	end)

	local combatEnded = Net.getRemote("CombatEnded") :: RemoteEvent
	combatEnded.OnClientEvent:Connect(function(info)
		RemoteClient.CombatEnded:Fire(info)
	end)

	local pvpMatchFound = Net.getRemote("PvpMatchFound") :: RemoteEvent
	pvpMatchFound.OnClientEvent:Connect(function(info)
		RemoteClient.PvpMatchFound:Fire(info)
	end)

	local profileUpdated = Net.getRemote("ProfileUpdated") :: RemoteEvent
	profileUpdated.OnClientEvent:Connect(function(snapshot)
		RemoteClient.ProfileUpdated:Fire(snapshot)
	end)
end

function RemoteClient.requestCastSpell(sessionId: string, casterId: string, spellId: string, primaryTargetId: string?)
	Net.fireServer("RequestCastSpell", sessionId, casterId, spellId, primaryTargetId)
end

function RemoteClient.requestUnlockSkillNode(nodeId: string)
	Net.fireServer("RequestUnlockSkillNode", nodeId)
end

function RemoteClient.getProfileSnapshot(): any
	return Net.invokeServer("GetPlayerProfileSnapshot")
end

function RemoteClient.joinPvpQueue()
	Net.fireServer("RequestJoinPvpQueue")
end

function RemoteClient.leavePvpQueue()
	Net.fireServer("RequestLeavePvpQueue")
end

function RemoteClient.getLeaderboardSnapshot(topN: number?): any
	return Net.invokeServer("LeaderboardSnapshotRequest", topN)
end

function RemoteClient.requestPurchasePrompt(productId: number)
	Net.fireServer("RequestPurchasePrompt", productId)
end

return RemoteClient
