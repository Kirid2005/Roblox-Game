--!strict
-- Turns player input into a (spell, target) selection and, once both are
-- chosen, a cast request. Deliberately minimal: number keys 1-9 pick a
-- spell from the local combatant's known spell list (server-provided, via
-- CombatController), and `selectTarget` is called by whatever UI element
-- represents a target (see UI/CombatUIController.lua). This module holds
-- selection state only -- it never resolves anything locally.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local CombatController = require(script.Parent:WaitForChild("CombatController"))

local InputController = {}

InputController.selectedSpellId = nil :: string?
InputController.SelectionChanged = Signal.new()

local NUMBER_KEYCODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

function InputController.selectSpell(spellId: string?)
	InputController.selectedSpellId = spellId
	InputController.SelectionChanged:Fire(spellId)
end

-- Called by UI when a target is clicked. Self-targeting/no-target spells
-- pass nil; CombatValidator on the server resolves those cases itself.
function InputController.selectTarget(targetId: string?)
	if not InputController.selectedSpellId then
		return
	end
	CombatController.castSpell(InputController.selectedSpellId, targetId)
	InputController.selectSpell(nil)
end

local initialized = false

function InputController.init()
	if initialized then
		return
	end
	initialized = true

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		local index = table.find(NUMBER_KEYCODES, input.KeyCode)
		if not index then
			return
		end

		local myCombatant = CombatController.getMyCombatant()
		if not myCombatant then
			return
		end

		local spellId = myCombatant.spellIds[index]
		if spellId then
			InputController.selectSpell(spellId)
		end
	end)
end

return InputController
