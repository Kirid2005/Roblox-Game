--!strict
-- Wires the combat-related RemoteEvents to the (mode-agnostic)
-- CombatEngine, and pushes state back out to clients. This is the ONLY
-- place a client's cast request touches the combat engine -- everything
-- here is a request, never a claim; CombatEngine.requestCastSpell (via
-- CombatValidator) is what actually decides whether it happens.
--
-- Replication strategy: rather than firing a remote for every tiny state
-- change (an AP tick, a gauge increment), we push one coarse
-- CombatStateUpdated snapshot on meaningful state transitions and throttle
-- it to a max rate per session, plus a CombatLogEvent per resolved cast
-- for the combat log UI. This keeps remote traffic bounded even for an
-- 8-player boss fight with enemies constantly ticking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Enums = require(Shared:WaitForChild("Enums"))

local ServerScriptService = game:GetService("ServerScriptService")
local CombatRegistry = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatRegistry"))
local CombatEngine = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatEngine"))
local CombatSession = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("CombatSession"))
local RateLimiter = require(ServerScriptService:WaitForChild("Security"):WaitForChild("RateLimiter"))

local CombatRemotes = {}

local MIN_SNAPSHOT_INTERVAL_SECONDS = 0.2 -- 5Hz ceiling per session
local lastBroadcastAt: { [string]: number } = {}

local function getSessionPlayers(session: CombatSession.CombatSessionObject): { Player }
	local players = {}
	for _, combatant in session:getRoster() do
		if combatant.player then
			table.insert(players, combatant.player)
		end
	end
	return players
end

local function broadcastSnapshot(session: CombatSession.CombatSessionObject, force: boolean?)
	local now = os.clock()
	if not force and (lastBroadcastAt[session.id] or 0) + MIN_SNAPSHOT_INTERVAL_SECONDS > now then
		return
	end
	lastBroadcastAt[session.id] = now

	local snapshot = session:toSnapshot()
	local remote = Net.getRemote("CombatStateUpdated") :: RemoteEvent
	for _, player in getSessionPlayers(session) do
		remote:FireClient(player, snapshot)
	end
end

local function broadcastLog(session: CombatSession.CombatSessionObject, entry: CombatSession.LogEntry)
	if entry.kind ~= "Cast" and entry.kind ~= "Info" then
		return
	end
	local remote = Net.getRemote("CombatLogEvent") :: RemoteEvent
	for _, player in getSessionPlayers(session) do
		remote:FireClient(player, entry)
	end
end

local function attachSessionListeners(session: CombatSession.CombatSessionObject)
	session.StateChanged:Connect(function(_old, newState)
		broadcastSnapshot(session, true)
		if newState == Enums.CombatState.Victory or newState == Enums.CombatState.Defeat or newState == Enums.CombatState.Ended then
			local remote = Net.getRemote("CombatEnded") :: RemoteEvent
			for _, player in getSessionPlayers(session) do
				remote:FireClient(player, { sessionId = session.id, finalState = newState })
			end
			lastBroadcastAt[session.id] = nil
		end
	end)

	session.LogAppended:Connect(function(entry)
		broadcastLog(session, entry)
		broadcastSnapshot(session)
	end)
end

function CombatRemotes.setup()
	CombatRegistry.SessionRegistered:Connect(attachSessionListeners)

	local requestCastSpell = Net.getRemote("RequestCastSpell") :: RemoteEvent
	requestCastSpell.OnServerEvent:Connect(function(player: Player, sessionId: unknown, casterId: unknown, spellId: unknown, primaryTargetId: unknown)
		if typeof(sessionId) ~= "string" or typeof(casterId) ~= "string" or typeof(spellId) ~= "string" then
			return
		end
		if primaryTargetId ~= nil and typeof(primaryTargetId) ~= "string" then
			return
		end

		if not RateLimiter.checkAndConsume(player, "RequestCastSpell", 5) then
			return
		end

		local session = CombatRegistry.get(sessionId)
		if not session then
			return
		end

		local result = CombatEngine.requestCastSpell(session, player, casterId, spellId, primaryTargetId :: string?)
		if not result.ok then
			-- Failed requests are cheap and expected (e.g. a stale button
			-- press after AP was just spent elsewhere); only log during
			-- development rather than spamming a client-facing remote.
			return
		end
	end)
end

return CombatRemotes
