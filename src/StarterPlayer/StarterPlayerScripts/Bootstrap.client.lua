--!strict
-- Client entrypoint: wires the network relay, combat state cache, input
-- handling, and HUD together in dependency order. Mirrors the structure
-- of ServerScriptService/Bootstrap/Init.server.lua on purpose -- one
-- place per side that owns "what starts, in what order."

local RemoteClient = require(script.Parent:WaitForChild("Network"):WaitForChild("RemoteClient"))
local CombatController = require(script.Parent:WaitForChild("Combat"):WaitForChild("CombatController"))
local InputController = require(script.Parent:WaitForChild("Combat"):WaitForChild("InputController"))
local CombatUIController = require(script.Parent:WaitForChild("UI"):WaitForChild("CombatUIController"))

RemoteClient.init()
CombatController.init()
InputController.init()
CombatUIController.init()
