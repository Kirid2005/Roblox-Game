--!strict
-- Data-driven equipment/inventory items. Kept intentionally small for the
-- initial foundation -- enough shape to prove the progression pipeline
-- (inventory -> equip -> stat modifiers feed into StatCalculator) without
-- committing to a full itemization pass yet.

local Enums = require(script.Parent.Parent.Enums)

export type EquipSlot = "Wand" | "Robe" | "Trinket"

export type ItemDef = {
	id: string,
	displayName: string,
	description: string,
	slot: EquipSlot,
	rarity: string, -- Enums.SpellRarity reused as a general rarity scale
	statModifiers: { [string]: number }, -- Enums.StatId -> flat bonus while equipped
	tradeable: boolean,
}

local ItemCatalog: { [string]: ItemDef } = {}

ItemCatalog.apprentice_wand = {
	id = "apprentice_wand",
	displayName = "Apprentice Wand",
	description = "A simple training wand. Everyone starts with one.",
	slot = "Wand",
	rarity = Enums.SpellRarity.Common,
	statModifiers = { [Enums.StatId.Power] = 2 },
	tradeable = false,
}

ItemCatalog.scholars_robe = {
	id = "scholars_robe",
	displayName = "Scholar's Robe",
	description = "Lightweight robes favored by the academy's students.",
	slot = "Robe",
	rarity = Enums.SpellRarity.Common,
	statModifiers = { [Enums.StatId.MaxMana] = 10, [Enums.StatId.Resilience] = 2 },
	tradeable = false,
}

-- Purely cosmetic reward granted by the "season_pass_robe" game pass (see
-- Monetization/ProductCatalog.lua) -- no stat modifiers, so owning it
-- carries zero competitive advantage.
ItemCatalog.season_pass_robe = {
	id = "season_pass_robe",
	displayName = "Season Pass Robe",
	description = "An ornate robe available only through the seasonal pass. Purely cosmetic.",
	slot = "Robe",
	rarity = Enums.SpellRarity.Legendary,
	statModifiers = {},
	tradeable = false,
}

ItemCatalog.gamblers_charm = {
	id = "gamblers_charm",
	displayName = "Gambler's Charm",
	description = "A lucky charm that steadies your nerve against critical failure.",
	slot = "Trinket",
	rarity = Enums.SpellRarity.Rare,
	statModifiers = { [Enums.StatId.FailureResistance] = 8 },
	tradeable = true,
}

return ItemCatalog
