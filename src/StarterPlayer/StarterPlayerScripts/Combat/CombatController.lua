--!strict
-- Client-side view of the current combat session. Holds only what the
-- server has told us (via RemoteClient) -- this module never simulates
-- combat locally; it's a cache plus a couple of convenience lookups for
-- the UI layer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local RemoteClient = require(script.Parent.Parent:WaitForChild("Network"):WaitForChild("RemoteClient"))

local CombatController = {}

local LocalPlayer = Players.LocalPlayer
-- Matches the id scheme CombatantFactory.fromPlayer uses server-side
-- (`player_<UserId>`), so the client never needs a round trip just to
-- learn its own combatant id.
CombatController.myCombatantId = `player_{LocalPlayer.UserId}`

CombatController.currentSessionId = nil :: string?
CombatController.latestSnapshot = nil :: { [string]: any }?

CombatController.Updated = Signal.new()
CombatController.LogAppended = Signal.new()
CombatController.Ended = Signal.new()

local initialized = false

function CombatController.init()
	if initialized then
		return
	end
	initialized = true

	RemoteClient.CombatStateUpdated:Connect(function(snapshot)
		CombatController.currentSessionId = snapshot.id
		CombatController.latestSnapshot = snapshot
		CombatController.Updated:Fire(snapshot)
	end)

	RemoteClient.CombatLogEvent:Connect(function(entry)
		CombatController.LogAppended:Fire(entry)
	end)

	RemoteClient.CombatEnded:Connect(function(info)
		CombatController.Ended:Fire(info)
		CombatController.currentSessionId = nil
		CombatController.latestSnapshot = nil
	end)

	RemoteClient.PvpMatchFound:Connect(function(info)
		CombatController.currentSessionId = info.sessionId
	end)
end

function CombatController.getCombatant(combatantId: string): { [string]: any }?
	if not CombatController.latestSnapshot then
		return nil
	end
	for _, combatant in CombatController.latestSnapshot.combatants do
		if combatant.id == combatantId then
			return combatant
		end
	end
	return nil
end

function CombatController.getMyCombatant(): { [string]: any }?
	return CombatController.getCombatant(CombatController.myCombatantId)
end

function CombatController.castSpell(spellId: string, primaryTargetId: string?)
	if not CombatController.currentSessionId then
		warn("[CombatController] Cannot cast: not in a combat session")
		return
	end
	RemoteClient.requestCastSpell(CombatController.currentSessionId, CombatController.myCombatantId, spellId, primaryTargetId)
end

return CombatController
