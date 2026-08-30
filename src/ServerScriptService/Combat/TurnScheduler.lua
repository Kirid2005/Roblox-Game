--!strict
-- Drives every active CombatSession's Action Gauge/AP progression from a
-- single fixed-rate loop, rather than one coroutine per session. This
-- keeps server cost roughly O(total combatants) regardless of how many
-- concurrent dungeon/PvP sessions exist, which matters once there are
-- dozens of simultaneous encounters across a busy server.
--
-- Server-authoritative by construction: dt comes from os.clock() measured
-- on the server, never from the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local CombatRegistry = require(script.Parent:WaitForChild("CombatRegistry"))
local CombatEngine = require(script.Parent:WaitForChild("CombatEngine"))

local TurnScheduler = {}

local started = false

function TurnScheduler.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local tickInterval = 1 / Constants.COMBAT_TICK_RATE
		local lastTime = os.clock()
		while true do
			task.wait(tickInterval)
			local now = os.clock()
			local dt = now - lastTime
			lastTime = now

			for _, session in CombatRegistry.getAll() do
				local ok, err = pcall(CombatEngine.tick, session, dt)
				if not ok then
					warn(`[TurnScheduler] session {session.id} tick error: {err}`)
				end
			end
		end
	end)
end

return TurnScheduler
