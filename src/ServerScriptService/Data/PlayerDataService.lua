--!strict
-- Server-authoritative persistence for player profiles.
--
-- Responsibilities:
--   * Load a player's profile from DataStoreService on join, migrating it
--     to the current schema (see DataSchema.lua).
--   * Guard against two servers editing the same profile at once (session
--     locking) so a player who rejoins on another server during a
--     save/shutdown race can't corrupt or dupe their data.
--   * Retry transient DataStore failures with backoff instead of silently
--     losing writes.
--   * Autosave periodically and on BindToClose so process death doesn't
--     lose recent progress.
--
-- Public API:
--   PlayerDataService.loadProfile(player: Player): Profile?  -- yields
--   PlayerDataService.getProfile(player: Player): Profile?   -- non-yielding, nil until loaded
--   PlayerDataService.saveProfile(player: Player): boolean   -- yields
--   PlayerDataService.releaseProfile(player: Player)          -- yields
--   PlayerDataService.ProfileLoaded: Signal<Player, Profile>
--   PlayerDataService.ProfileReleased: Signal<Player>
--
-- Dependencies: DataSchema (shape/migrations), Constants (retry tuning),
-- Signal (event plumbing). No other gameplay module should touch
-- DataStoreService directly -- everything goes through this service so
-- there is exactly one place that can corrupt a save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local DataSchema = require(script.Parent:WaitForChild("DataSchema"))

local PlayerDataService = {}

export type Profile = {
	player: Player,
	userId: number,
	data: DataSchema.ProfileData,
	sessionId: string,
	loaded: boolean,
	active: boolean, -- false once released; gameplay code must stop touching `data`
	dirty: boolean, -- true when in-memory data has changed since the last successful save
}

local profileStore = DataStoreService:GetDataStore(Constants.DATASTORE_NAME)

-- Unique per-server identifier used for session locking.
local SESSION_ID = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1e9)))
local LOCK_STALE_SECONDS = 30

local activeProfiles: { [Player]: Profile } = {}

PlayerDataService.ProfileLoaded = Signal.new()
PlayerDataService.ProfileReleased = Signal.new()

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local function withRetry<T>(fn: () -> T, description: string): (boolean, T?)
	local attempt = 0
	while attempt < Constants.DATASTORE_SAVE_RETRIES do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[PlayerDataService] %s failed (attempt %d/%d): %s"):format(
			description,
			attempt,
			Constants.DATASTORE_SAVE_RETRIES,
			tostring(result)
		))
		if attempt < Constants.DATASTORE_SAVE_RETRIES then
			task.wait(Constants.DATASTORE_RETRY_BACKOFF_SECONDS * attempt)
		end
	end
	return false, nil
end

-- Attempts to claim (or refresh) the session lock for this profile via
-- UpdateAsync, migrating the stored data forward in the same transaction.
-- Returns the migrated ProfileData on success, or nil if another live
-- server holds the lock.
local function claimAndLoad(userId: number): DataSchema.ProfileData?
	local claimed: DataSchema.ProfileData? = nil
	local key = keyFor(userId)

	local ok = select(1, withRetry(function()
		profileStore:UpdateAsync(key, function(rawEntry)
			local entry = rawEntry :: { [string]: any }?
			local now = os.time()

			if entry ~= nil then
				local lock = entry.ActiveSession :: { sessionId: string, lockedAt: number }?
				if lock ~= nil and lock.sessionId ~= SESSION_ID and (now - lock.lockedAt) < LOCK_STALE_SECONDS then
					-- Another live server owns this profile right now.
					return nil
				end
			end

			local migrated = DataSchema.migrate(entry and entry.Data or nil)

			local nextEntry = {
				Data = migrated,
				ActiveSession = { sessionId = SESSION_ID, lockedAt = now },
			}
			claimed = migrated
			return nextEntry
		end)
	end, `claimAndLoad({userId})`))

	if not ok then
		return nil
	end
	return claimed
end

function PlayerDataService.loadProfile(player: Player): Profile?
	if activeProfiles[player] then
		return activeProfiles[player]
	end

	local data = claimAndLoad(player.UserId)
	if data == nil then
		warn(`[PlayerDataService] Could not claim profile for {player.Name} ({player.UserId}); likely locked by another server.`)
		return nil
	end

	if not player.Parent then
		-- Player left while we were loading; release the lock immediately.
		task.spawn(function()
			withRetry(function()
				profileStore:UpdateAsync(keyFor(player.UserId), function(rawEntry)
					local entry = rawEntry :: { [string]: any }?
					if entry then
						entry.ActiveSession = nil
					end
					return entry
				end)
			end, `release-after-leave({player.UserId})`)
		end)
		return nil
	end

	local profile: Profile = {
		player = player,
		userId = player.UserId,
		data = data,
		sessionId = SESSION_ID,
		loaded = true,
		active = true,
		dirty = false,
	}

	data.meta.lastLoginAt = os.time()
	profile.dirty = true

	activeProfiles[player] = profile
	PlayerDataService.ProfileLoaded:Fire(player, profile)
	return profile
end

function PlayerDataService.getProfile(player: Player): Profile?
	return activeProfiles[player]
end

-- Marks a profile dirty so the next autosave/final save actually writes it.
-- Gameplay services should call this after mutating `profile.data`.
function PlayerDataService.markDirty(player: Player)
	local profile = activeProfiles[player]
	if profile then
		profile.dirty = true
	end
end

function PlayerDataService.saveProfile(player: Player): boolean
	local profile = activeProfiles[player]
	if not profile or not profile.active then
		return false
	end
	if not profile.dirty then
		return true
	end

	local key = keyFor(profile.userId)
	local ok = select(1, withRetry(function()
		profileStore:UpdateAsync(key, function(rawEntry)
			local entry = (rawEntry :: { [string]: any }?) or {}
			entry.Data = profile.data
			entry.ActiveSession = { sessionId = profile.sessionId, lockedAt = os.time() }
			return entry
		end)
	end, `saveProfile({profile.userId})`))

	if ok then
		profile.dirty = false
	end
	return ok
end

function PlayerDataService.releaseProfile(player: Player)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	PlayerDataService.saveProfile(player)

	profile.active = false
	activeProfiles[player] = nil

	withRetry(function()
		profileStore:UpdateAsync(keyFor(profile.userId), function(rawEntry)
			local entry = rawEntry :: { [string]: any }?
			if entry and entry.ActiveSession and entry.ActiveSession.sessionId == profile.sessionId then
				entry.ActiveSession = nil
			end
			return entry
		end)
	end, `releaseLock({profile.userId})`)

	PlayerDataService.ProfileReleased:Fire(player)
end

-- Periodic autosave for every currently-active profile. Started once from
-- Bootstrap; not re-entrant-safe to call twice.
function PlayerDataService.startAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(Constants.AUTO_SAVE_INTERVAL_SECONDS)
			for player in activeProfiles do
				task.spawn(PlayerDataService.saveProfile, player)
			end
		end
	end)
end

game:BindToClose(function()
	local threads = {}
	for player in activeProfiles do
		table.insert(
			threads,
			task.spawn(function()
				PlayerDataService.releaseProfile(player)
			end)
		)
	end
	-- Give in-flight saves a chance to finish before the process is killed.
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local anyRunning = false
		for _, thread in threads do
			if coroutine.status(thread) ~= "dead" then
				anyRunning = true
				break
			end
		end
		if not anyRunning then
			break
		end
		task.wait(0.5)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.releaseProfile(player)
end)

return PlayerDataService
