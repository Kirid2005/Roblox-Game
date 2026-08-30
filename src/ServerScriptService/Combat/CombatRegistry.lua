--!strict
-- Process-wide registry of active CombatSessions. TurnScheduler iterates
-- this list once per tick instead of every session running its own
-- coroutine, which keeps per-tick overhead flat regardless of how many
-- dungeon/PvP sessions happen to be live on this server at once.
--
-- Also the hook point Network/CombatRemotes.lua uses to find out about
-- new sessions (via SessionRegistered) without mode services needing any
-- awareness of networking -- they just create sessions through
-- CombatEngine, and the registry announces them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local CombatRegistry = {}

local sessions: { [string]: any } = {}
local nextSessionNumber = 0

CombatRegistry.SessionRegistered = Signal.new()
CombatRegistry.SessionUnregistered = Signal.new()

function CombatRegistry.generateSessionId(prefix: string): string
	nextSessionNumber += 1
	return `{prefix}_{nextSessionNumber}_{os.time()}`
end

function CombatRegistry.register(session: any)
	sessions[session.id] = session
	CombatRegistry.SessionRegistered:Fire(session)
end

function CombatRegistry.unregister(sessionId: string)
	sessions[sessionId] = nil
	CombatRegistry.SessionUnregistered:Fire(sessionId)
end

function CombatRegistry.get(sessionId: string): any?
	return sessions[sessionId]
end

function CombatRegistry.getAll(): { [string]: any }
	return sessions
end

function CombatRegistry.count(): number
	local n = 0
	for _ in sessions do
		n += 1
	end
	return n
end

return CombatRegistry
