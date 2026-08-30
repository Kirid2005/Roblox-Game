--!strict
-- MarketplaceService receipt processing for developer products, plus
-- game pass ownership checks. This is the only module allowed to grant
-- currency/boosts/cosmetics from a real-money purchase, and it is
-- deliberately kept separate from RewardService/ExperienceService's core
-- logic -- monetization decides *that* a grant should happen and how big
-- it is allowed to be, but reuses the same server-authoritative grant
-- machinery every other reward source uses.
--
-- Idempotency: Roblox can call ProcessReceipt more than once for the same
-- purchase (retries, server crashes mid-grant). We record
-- receipt.PurchaseId in the player's own profile before returning
-- PurchaseGranted; if we ever see that PurchaseId again we grant nothing
-- and just confirm the receipt, so a purchase can never be paid out twice
-- even across a save/reload race.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local DataSchema = require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataSchema"))
local InventoryService = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("InventoryService"))

local ProductCatalog = require(script.Parent:WaitForChild("ProductCatalog"))

local MonetizationService = {}

local function grantDeveloperProduct(profileData: DataSchema.ProfileData, product: ProductCatalog.DeveloperProduct)
	if product.kind == "CurrencyPack" and product.currency and product.amount then
		profileData.currencies[product.currency] = (profileData.currencies[product.currency] or 0) + product.amount
	elseif product.kind == "XpBoost" and product.xpMultiplier and product.durationSeconds then
		profileData.monetization.activeBoosts["xp_boost"] = os.time() + product.durationSeconds
	end

	profileData.monetization.purchasedProductIds[tostring(product.id)] = (profileData.monetization.purchasedProductIds[tostring(product.id)] or 0) + 1
end

-- Reads any currently-active XP boost and returns the multiplier to pass
-- into RewardService/ExperienceService, already clamped by
-- ExperienceService itself as a second line of defense. Pure function of
-- profile data + current time, so it's testable without MarketplaceService.
function MonetizationService.getActiveXpMultiplier(profileData: DataSchema.ProfileData): number
	local expiresAt = profileData.monetization.activeBoosts["xp_boost"]
	if expiresAt and expiresAt > os.time() then
		local product = ProductCatalog.DeveloperProducts[1000003]
		return product and product.xpMultiplier or 1
	end
	return 1
end

function MonetizationService.processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = receiptInfo.PurchaseId :: string
	if profile.data.monetization.processedPurchaseIds[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = ProductCatalog.DeveloperProducts[receiptInfo.ProductId]
	if not product then
		warn(`[MonetizationService] Unknown ProductId {receiptInfo.ProductId} in receipt {purchaseId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantDeveloperProduct(profile.data, product)
	profile.data.monetization.processedPurchaseIds[purchaseId] = true
	PlayerDataService.markDirty(player)

	local saved = PlayerDataService.saveProfile(player)
	if not saved then
		-- Don't confirm the receipt if we couldn't persist the grant --
		-- Roblox will retry ProcessReceipt later, and processedPurchaseIds
		-- not yet being set means the retry will actually grant it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Game passes are entitlement checks (does the player own it), not
-- one-time grants, so they don't go through the receipt/ledger flow.
-- Cosmetic-only in this catalog, so no monetization advantage cap needed.
function MonetizationService.playerOwnsGamePass(player: Player, gamePassId: number): boolean
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	return ok and owns == true
end

function MonetizationService.applyOwnedGamePassCosmetics(player: Player, profileData: DataSchema.ProfileData)
	for gamePassId, gamePass in ProductCatalog.GamePasses do
		if gamePass.kind == "Cosmetic" and gamePass.itemId then
			if MonetizationService.playerOwnsGamePass(player, gamePassId) then
				if (profileData.inventory.items[gamePass.itemId] or 0) == 0 and profileData.equipment.Trinket ~= gamePass.itemId then
					InventoryService.addItem(profileData, gamePass.itemId, 1)
				end
			end
		end
	end
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt
end

return MonetizationService
