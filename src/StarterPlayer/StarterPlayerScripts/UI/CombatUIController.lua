--!strict
-- Minimal, functional combat HUD built at runtime rather than hand-authored
-- GUI instances -- see StarterGui/UINotes.lua for why. This is intentionally
-- barebones per the task's UI guidance: it exists to prove the client can
-- present authoritative server state (health, AP, gauge, spells, targets,
-- combat log) cleanly, not to be a finished interface. Every value shown
-- comes from CombatController's cached snapshot; nothing is computed here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local CombatController = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("CombatController"))
local InputController = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("InputController"))

local CombatUIController = {}

local function makeLabel(parent: Instance, layoutOrder: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = layoutOrder
	label.Parent = parent
	return label
end

function CombatUIController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "Status"
	statusFrame.Size = UDim2.new(0, 260, 0, 90)
	statusFrame.Position = UDim2.new(0, 20, 1, -110)
	statusFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	statusFrame.BackgroundTransparency = 0.4
	statusFrame.Parent = screenGui
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.Parent = statusFrame

	local healthLabel = makeLabel(statusFrame, 1)
	local apLabel = makeLabel(statusFrame, 2)
	local gaugeLabel = makeLabel(statusFrame, 3)

	local spellFrame = Instance.new("Frame")
	spellFrame.Name = "Spells"
	spellFrame.Size = UDim2.new(0, 220, 0, 200)
	spellFrame.Position = UDim2.new(0, 300, 1, -220)
	spellFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	spellFrame.BackgroundTransparency = 0.4
	spellFrame.Parent = screenGui
	local spellLayout = Instance.new("UIListLayout")
	spellLayout.Parent = spellFrame

	local targetFrame = Instance.new("Frame")
	targetFrame.Name = "Targets"
	targetFrame.Size = UDim2.new(0, 220, 0, 200)
	targetFrame.Position = UDim2.new(0, 540, 1, -220)
	targetFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	targetFrame.BackgroundTransparency = 0.4
	targetFrame.Parent = screenGui
	local targetLayout = Instance.new("UIListLayout")
	targetLayout.Parent = targetFrame

	local logFrame = Instance.new("ScrollingFrame")
	logFrame.Name = "CombatLog"
	logFrame.Size = UDim2.new(0, 400, 0, 150)
	logFrame.Position = UDim2.new(1, -420, 1, -170)
	logFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	logFrame.BackgroundTransparency = 0.4
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logFrame.Parent = screenGui
	local logLayout = Instance.new("UIListLayout")
	logLayout.Parent = logFrame

	local function clearChildren(parent: Instance)
		for _, child in parent:GetChildren() do
			if not child:IsA("UILayout") then
				child:Destroy()
			end
		end
	end

	local function refresh()
		local myCombatant = CombatController.getMyCombatant()
		screenGui.Enabled = CombatController.currentSessionId ~= nil
		if not myCombatant then
			return
		end

		healthLabel.Text = `HP: {math.floor(myCombatant.currentHealth)} / {math.floor(myCombatant.maxHealth)}`
		apLabel.Text = `AP: {myCombatant.actionPoints}`
		gaugeLabel.Text = `Gauge: {math.floor(myCombatant.actionGauge)} (Speed {math.floor(myCombatant.speed)})`

		clearChildren(spellFrame)
		for index, spellId in myCombatant.spellIds do
			local spellDef = SpellCatalog[spellId]
			if spellDef then
				local button = Instance.new("TextButton")
				button.Size = UDim2.new(1, 0, 0, 28)
				button.LayoutOrder = index
				button.Text = `[{index}] {spellDef.displayName} ({spellDef.apCost} AP)`
				button.Parent = spellFrame
				button.MouseButton1Click:Connect(function()
					InputController.selectSpell(spellId)
				end)
			end
		end

		clearChildren(targetFrame)
		local snapshot = CombatController.latestSnapshot
		if snapshot then
			local order = 0
			for _, combatant in snapshot.combatants do
				if combatant.id ~= CombatController.myCombatantId and combatant.isAlive then
					order += 1
					local button = Instance.new("TextButton")
					button.Size = UDim2.new(1, 0, 0, 28)
					button.LayoutOrder = order
					button.Text = `{combatant.displayName} ({math.floor(combatant.currentHealth)}/{math.floor(combatant.maxHealth)})`
					button.Parent = targetFrame
					button.MouseButton1Click:Connect(function()
						InputController.selectTarget(combatant.id)
					end)
				end
			end
		end
	end

	CombatController.Updated:Connect(refresh)
	CombatController.Ended:Connect(function()
		screenGui.Enabled = false
	end)

	CombatController.LogAppended:Connect(function(entry)
		local label = makeLabel(logFrame, #logFrame:GetChildren())
		if entry.kind == "Cast" then
			local data = entry.data
			label.Text = `[t{entry.tick}] {data.casterId} cast {data.spellId}: {data.outcome}`
		else
			label.Text = `[t{entry.tick}] {entry.data.message or entry.kind}`
		end
	end)

	refresh()
end

return CombatUIController
