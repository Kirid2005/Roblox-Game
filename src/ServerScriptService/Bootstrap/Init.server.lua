--!strict
-- Single entrypoint that brings the whole server-side game up in a
-- well-defined order:
--   1. Remote instances must exist before anything tries to fetch them.
--   2. Long-running loops (autosave, combat scheduler, season refresh,
--      matchmaking) start next.
--   3. Remote handlers wire themselves to the now-running services.
--   4. Player join/leave hooks tie persistence into the Players service.
--
-- Every module required below is a ModuleScript with no side effects at
-- require-time (aside from small local declarations); this script is the
-- only place `.setup()`/`.start()` calls actually happen, which makes the
-- startup sequence auditable in one file instead of scattered `if not
-- _G.initialized` guards across the codebase.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteRegistry = require(ServerScriptService:WaitForChild("Network"):WaitForChild("RemoteRegistry"))
RemoteRegistry.setup()

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local TurnScheduler = require(ServerScriptService:WaitForChild("Combat"):WaitForChild("TurnScheduler"))
local MonetizationService = require(ServerScriptService:WaitForChild("Monetization"):WaitForChild("MonetizationService"))
local SeasonService = require(ServerScriptService:WaitForChild("Modes"):WaitForChild("PvP"):WaitForChild("SeasonService"))

PlayerDataService.startAutosaveLoop()
TurnScheduler.start()
MonetizationService.start()
SeasonService.refreshCurrentSeason()
SeasonService.startPeriodicRefresh()

local CombatRemotes = require(ServerScriptService:WaitForChild("Network"):WaitForChild("CombatRemotes"))
local ProgressionRemotes = require(ServerScriptService:WaitForChild("Network"):WaitForChild("ProgressionRemotes"))
local PvPRemotes = require(ServerScriptService:WaitForChild("Network"):WaitForChild("PvPRemotes"))
local MonetizationRemotes = require(ServerScriptService:WaitForChild("Network"):WaitForChild("MonetizationRemotes"))

CombatRemotes.setup()
ProgressionRemotes.setup()
PvPRemotes.setup()
MonetizationRemotes.setup()

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local profile = PlayerDataService.loadProfile(player)
		if not profile then
			-- Could not claim the profile (locked by another server, or
			-- the player left mid-load). Kick rather than let them play
			-- with no persistence, which would silently discard progress.
			if player.Parent then
				player:Kick("Could not load your save data. Please rejoin in a moment.")
			end
			return
		end

		SeasonService.ensurePlayerOnCurrentSeason(profile.data)
		MonetizationService.applyOwnedGamePassCosmetics(player, profile.data)
		PlayerDataService.markDirty(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[Bootstrap] Roblox Magic Strategy Game server initialized.")
