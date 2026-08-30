--!strict
-- Maps Roblox Developer Product / Game Pass ids to what they grant.
-- Replace the placeholder numeric ids below with real ids from the
-- Creator Dashboard before shipping -- they cannot be known ahead of time
-- since they're allocated per-experience.
--
-- Design guardrail (task requirement 16): every progression-affecting
-- product is capped at Constants.MAX_MONETIZATION_ADVANTAGE (25%) so a
-- paying player accelerates rather than statistically dominates. Purely
-- cosmetic/convenience products are uncapped since they carry no
-- competitive advantage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

export type ProductKind = "CurrencyPack" | "XpBoost"
export type GamePassKind = "Cosmetic"

export type DeveloperProduct = {
	id: number,
	kind: ProductKind,
	currency: string?,
	amount: number?,
	xpMultiplier: number?,
	durationSeconds: number?,
}

export type GamePass = {
	id: number,
	kind: GamePassKind,
	itemId: string?,
}

local ProductCatalog = {}

-- PLACEHOLDER IDS -- see module comment above.
local developerProducts: { [number]: DeveloperProduct } = {
	[1000001] = {
		id = 1000001,
		kind = "CurrencyPack",
		currency = Enums.RewardCurrency.Gems,
		amount = 100,
	},
	[1000002] = {
		id = 1000002,
		kind = "CurrencyPack",
		currency = Enums.RewardCurrency.Gems,
		amount = 550, -- bulk pack, better rate than buying 5x the small pack
	},
	[1000003] = {
		id = 1000003,
		kind = "XpBoost",
		xpMultiplier = 1.25, -- == Constants.MAX_MONETIZATION_ADVANTAGE ceiling, intentionally not higher
		durationSeconds = 60 * 60,
	},
}
ProductCatalog.DeveloperProducts = developerProducts

local gamePasses: { [number]: GamePass } = {
	[2000001] = {
		id = 2000001,
		kind = "Cosmetic",
		itemId = "season_pass_robe",
	},
}
ProductCatalog.GamePasses = gamePasses

return ProductCatalog
