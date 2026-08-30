--!strict
-- Single source of truth for every RemoteEvent/RemoteFunction the game
-- uses, plus thin helpers for firing/invoking them. Keeping the remote
-- *names* here (instead of magic strings scattered through the codebase)
-- means the client and server can never drift out of sync on what a
-- remote is called, and adding a new remote is a one-line change.
--
-- IMPORTANT: this module never decides *whether* a request is allowed --
-- that authority lives entirely in the server-side handlers under
-- ServerScriptService/Network. This module only describes the wire
-- format and provides plumbing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

export type RemoteKind = "Event" | "Function"

export type RemoteDef = {
	name: string,
	kind: RemoteKind,
}

-- Every remote used by the game. Grouped by subsystem. `kind = "Event"`
-- means fire-and-forget (client requests an action, server later pushes a
-- state update); `kind = "Function"` is used sparingly, only where the
-- client genuinely needs a synchronous reply (see task requirement 11).
local Remotes: { [string]: RemoteDef } = {
	-- Combat: client -> server requests.
	RequestCastSpell = { name = "RequestCastSpell", kind = "Event" },
	RequestJoinQueue = { name = "RequestJoinQueue", kind = "Event" },
	RequestLeaveQueue = { name = "RequestLeaveQueue", kind = "Event" },

	-- Combat: server -> client pushes. One coarse "state changed" event
	-- rather than dozens of tiny per-field remotes (see performance
	-- requirement: avoid high-frequency remotes for every small update).
	CombatStateUpdated = { name = "CombatStateUpdated", kind = "Event" },
	CombatLogEvent = { name = "CombatLogEvent", kind = "Event" },
	CombatEnded = { name = "CombatEnded", kind = "Event" },

	-- Progression: client -> server requests that need a reply.
	RequestUnlockSkillNode = { name = "RequestUnlockSkillNode", kind = "Event" },
	GetPlayerProfileSnapshot = { name = "GetPlayerProfileSnapshot", kind = "Function" },

	-- Progression: server -> client pushes.
	ProfileUpdated = { name = "ProfileUpdated", kind = "Event" },

	-- PvP.
	RequestJoinPvpQueue = { name = "RequestJoinPvpQueue", kind = "Event" },
	RequestLeavePvpQueue = { name = "RequestLeavePvpQueue", kind = "Event" },
	PvpMatchFound = { name = "PvpMatchFound", kind = "Event" },
	LeaderboardSnapshotRequest = { name = "LeaderboardSnapshotRequest", kind = "Function" },

	-- Monetization: purchases are handled by MarketplaceService receipts,
	-- not remotes, but the client still needs to *request* a purchase
	-- prompt be shown for a given product id.
	RequestPurchasePrompt = { name = "RequestPurchasePrompt", kind = "Event" },
}
Net.Remotes = Remotes

local FOLDER_NAME = "Remotes"

function Net.getRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		-- On the client this simply waits for the server-created folder to
		-- replicate in; on the server RemoteRegistry creates it eagerly
		-- during bootstrap before any other module runs.
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	end
	assert(folder, "[Net] Remotes folder never appeared under ReplicatedStorage")
	return folder :: Folder
end

function Net.getRemote(name: string): RemoteEvent | RemoteFunction
	local def = Net.Remotes[name]
	assert(def, `[Net] Unknown remote "{name}"`)
	local folder = Net.getRemotesFolder()
	local instance = folder:WaitForChild(def.name, 30)
	assert(instance, `[Net] Remote instance "{name}" never appeared`)
	return instance :: any
end

-- Client-side convenience wrappers. Safe to call from server too, but
-- server code should generally prefer FireClient/FireAllClients directly
-- for clarity about direction.
function Net.fireServer(name: string, ...: any)
	local remote = Net.getRemote(name) :: RemoteEvent
	remote:FireServer(...)
end

function Net.invokeServer(name: string, ...: any): ...any
	local remote = Net.getRemote(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

return Net
