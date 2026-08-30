--!strict
-- Versioned shape of a player's persistent profile, plus the migration
-- chain that upgrades old saves forward. This is the ONLY place the save
-- shape is defined -- PlayerDataService never hard-codes field names, and
-- gameplay services should treat `profile.data` as this shape rather than
-- inventing their own ad-hoc fields on it.
--
-- How to change the schema safely:
--   1. Add/rename/restructure fields in `DataSchema.Defaults`.
--   2. Bump ReplicatedStorage/Shared/SchemaVersion.lua by 1.
--   3. Append a function to `DataSchema.Migrations` keyed by the NEW
--      version number that transforms a profile at (new-1) into (new).
--   4. Never delete an old migration step as long as any live save could
--      still be sitting at that version.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local TableUtil = require(Shared:WaitForChild("Util"):WaitForChild("Table"))
local Enums = require(Shared:WaitForChild("Enums"))
local CurrentSchemaVersion = require(Shared:WaitForChild("SchemaVersion"))

local DataSchema = {}

DataSchema.CurrentVersion = CurrentSchemaVersion :: number

export type Currencies = { [string]: number }
export type BaseStats = { [string]: number }

export type ProfileData = {
	schemaVersion: number,
	level: number,
	experience: number,
	currencies: Currencies,
	baseStats: BaseStats,
	learnedSpells: { [string]: boolean },
	spellUpgrades: { [string]: number },
	skillTree: {
		unlockedNodeIds: { [string]: boolean },
		availablePoints: number,
		spentPoints: number,
	},
	inventory: {
		items: { [string]: number }, -- itemId -> quantity (non-equipped stock)
	},
	equipment: { [string]: string? }, -- slot -> itemId
	pve: {
		highestDungeonCleared: number,
		storyChapter: number,
		completedEncounters: { [string]: boolean },
	},
	pvp: {
		rating: number,
		wins: number,
		losses: number,
		currentSeasonId: string?,
		seasonStats: { [string]: { wins: number, losses: number, rating: number } }, -- seasonId -> stats snapshot
	},
	achievements: {
		unlocked: { [string]: boolean },
	},
	rewardLedger: { [string]: boolean }, -- idempotency keys of already-granted rewards
	monetization: {
		purchasedProductIds: { [string]: number }, -- productId -> purchase count, informational only
		processedPurchaseIds: { [string]: boolean }, -- MarketplaceService receipt.PurchaseId -> granted; the actual idempotency guard
		activeBoosts: { [string]: number }, -- boostId -> expiresAtUnix
	},
	meta: {
		createdAt: number,
		lastLoginAt: number,
		totalPlaytimeSeconds: number,
	},
}

function DataSchema.newDefaults(): ProfileData
	local now = os.time()
	return {
		schemaVersion = DataSchema.CurrentVersion,
		level = 1,
		experience = 0,
		currencies = {
			[Enums.RewardCurrency.Gold] = 100,
			[Enums.RewardCurrency.ArcaneDust] = 0,
			[Enums.RewardCurrency.SeasonToken] = 0,
			[Enums.RewardCurrency.Gems] = 0,
		},
		baseStats = {
			[Enums.StatId.MaxHealth] = 100,
			[Enums.StatId.MaxMana] = 50,
			[Enums.StatId.Speed] = Constants.BASE_SPEED,
			[Enums.StatId.Power] = 10,
			[Enums.StatId.Resilience] = 10,
			[Enums.StatId.CritChanceBonus] = 0,
			[Enums.StatId.FailureResistance] = 0,
		},
		learnedSpells = {
			firebolt = true,
			minor_heal = true,
		},
		spellUpgrades = {},
		skillTree = {
			unlockedNodeIds = {},
			availablePoints = 0,
			spentPoints = 0,
		},
		inventory = {
			items = {},
		},
		equipment = {
			Wand = "apprentice_wand",
			Robe = "scholars_robe",
			Trinket = nil,
		},
		pve = {
			highestDungeonCleared = 0,
			storyChapter = 1,
			completedEncounters = {},
		},
		pvp = {
			rating = Constants.PVP_STARTING_RATING,
			wins = 0,
			losses = 0,
			currentSeasonId = nil,
			seasonStats = {},
		},
		achievements = {
			unlocked = {},
		},
		rewardLedger = {},
		monetization = {
			purchasedProductIds = {},
			processedPurchaseIds = {},
			activeBoosts = {},
		},
		meta = {
			createdAt = now,
			lastLoginAt = now,
			totalPlaytimeSeconds = 0,
		},
	}
end

-- Migrations[targetVersion](data) mutates `data` in place from
-- (targetVersion - 1) to targetVersion and returns it. Version 1 has no
-- predecessor, so there is no Migrations[1] entry.
local migrations: { [number]: (data: { [string]: any }) -> { [string]: any } } = {
	-- Example for the future:
	-- [2] = function(data)
	-- 	data.pvp.seasonStats = data.pvp.seasonStats or {}
	-- 	return data
	-- end,
}
DataSchema.Migrations = migrations

-- Brings a raw decoded save (of unknown/older shape) up to CurrentVersion,
-- filling in any newly-added fields with defaults along the way. Safe to
-- call on a freshly created default profile too (no-op).
function DataSchema.migrate(rawData: { [string]: any }?): ProfileData
	local data = rawData
	if data == nil then
		return DataSchema.newDefaults()
	end

	data.schemaVersion = data.schemaVersion or 0

	while data.schemaVersion < DataSchema.CurrentVersion do
		local nextVersion = data.schemaVersion + 1
		local migrationFn = DataSchema.Migrations[nextVersion]
		if migrationFn then
			data = migrationFn(data)
		end
		data.schemaVersion = nextVersion
	end

	-- Reconcile against defaults last so migrations only need to handle
	-- structural changes, not every newly-added leaf field.
	TableUtil.reconcile(data, DataSchema.newDefaults())
	data.schemaVersion = DataSchema.CurrentVersion

	return data :: ProfileData
end

return DataSchema
