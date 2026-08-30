--!strict
-- Inventory (unequipped stock) and equipment slot management. Kept
-- separate from StatCalculator (which only *reads* equipment to derive
-- stats) so item-granting code (rewards, monetization, crafting later)
-- has one place to go through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"):WaitForChild("ItemCatalog"))

local DataSchema = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataSchema"))

local InventoryService = {}

function InventoryService.addItem(profileData: DataSchema.ProfileData, itemId: string, quantity: number?)
	local qty = quantity or 1
	assert(ItemCatalog[itemId] ~= nil, `InventoryService.addItem: unknown item "{itemId}"`)
	assert(qty > 0, "InventoryService.addItem: quantity must be positive")
	profileData.inventory.items[itemId] = (profileData.inventory.items[itemId] or 0) + qty
end

function InventoryService.removeItem(profileData: DataSchema.ProfileData, itemId: string, quantity: number?): boolean
	local qty = quantity or 1
	local current = profileData.inventory.items[itemId] or 0
	if current < qty then
		return false
	end
	local remaining = current - qty
	if remaining <= 0 then
		profileData.inventory.items[itemId] = nil
	else
		profileData.inventory.items[itemId] = remaining
	end
	return true
end

export type EquipFailureReason = "UnknownItem" | "NotOwned"

function InventoryService.equipItem(profileData: DataSchema.ProfileData, itemId: string): (boolean, EquipFailureReason?)
	local item = ItemCatalog[itemId]
	if not item then
		return false, "UnknownItem"
	end
	if not InventoryService.removeItem(profileData, itemId, 1) then
		return false, "NotOwned"
	end

	local previous = profileData.equipment[item.slot]
	if previous then
		InventoryService.addItem(profileData, previous, 1)
	end
	profileData.equipment[item.slot] = itemId
	return true
end

function InventoryService.unequipSlot(profileData: DataSchema.ProfileData, slot: string)
	local current = profileData.equipment[slot]
	if current then
		InventoryService.addItem(profileData, current, 1)
		profileData.equipment[slot] = nil
	end
end

return InventoryService
