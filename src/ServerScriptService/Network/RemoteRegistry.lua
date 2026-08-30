--!strict
-- Creates the actual RemoteEvent/RemoteFunction instances described by
-- ReplicatedStorage/Shared/Net.lua. Must run before any other server or
-- client code tries to fetch a remote (Net.getRemote uses WaitForChild,
-- so ordering only matters for latency, not correctness -- but Bootstrap
-- still calls this first for clarity).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local RemoteRegistry = {}

function RemoteRegistry.setup()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	for _, def in Net.Remotes do
		if not folder:FindFirstChild(def.name) then
			local instance = if def.kind == "Function" then Instance.new("RemoteFunction") else Instance.new("RemoteEvent")
			instance.Name = def.name
			instance.Parent = folder
		end
	end

	return folder
end

return RemoteRegistry
