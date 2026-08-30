--!strict
-- The client can only ask the server to *show* a purchase prompt; the
-- actual grant only ever happens through MonetizationService.processReceipt
-- reacting to a real MarketplaceService receipt, never from this remote
-- directly. This keeps "prompt a purchase" and "grant a purchase"
-- completely separate so a forged RequestPurchasePrompt call can't grant
-- anything by itself.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local ProductCatalog = require(ServerScriptService:WaitForChild("Monetization"):WaitForChild("ProductCatalog"))
local RateLimiter = require(ServerScriptService:WaitForChild("Security"):WaitForChild("RateLimiter"))

local MonetizationRemotes = {}

function MonetizationRemotes.setup()
	local requestPrompt = Net.getRemote("RequestPurchasePrompt") :: RemoteEvent
	requestPrompt.OnServerEvent:Connect(function(player: Player, productId: unknown)
		if typeof(productId) ~= "number" then
			return
		end
		if not RateLimiter.checkAndConsume(player, "RequestPurchasePrompt", 2) then
			return
		end
		if not ProductCatalog.DeveloperProducts[productId] then
			return
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

return MonetizationRemotes
