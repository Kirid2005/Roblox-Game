--!strict
-- Action Point bookkeeping: effective cost computation (base cost plus any
-- temporary ApCostModifier effects), affordability checks, and the actual
-- spend/grant mutations. Centralizing this means a combatant can never be
-- allowed to execute an ability it cannot afford -- every spend goes
-- through `ApManager.spend`, which re-checks affordability itself rather
-- than trusting a caller that already checked once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))

local ApManager = {}

-- ApCostModifier active effects may target a specific spell (effect.spellId
-- set) or apply globally to all of this combatant's casts (spellId nil).
function ApManager.getEffectiveApCost(combatant: Combatant.CombatantObject, spellId: string, baseApCost: number, currentTick: number): number
	local cost = baseApCost
	for _, effect in combatant.activeEffects do
		if effect.type == Enums.EffectType.ApCostModifier and effect.expiresAtTick > currentTick then
			local appliesToThisSpell = effect.targetSpellId == nil or effect.targetSpellId == spellId
			if appliesToThisSpell then
				cost += (effect.amount or 0)
			end
		end
	end
	return math.max(1, cost)
end

function ApManager.canAfford(combatant: Combatant.CombatantObject, apCost: number): boolean
	return combatant.actionPoints >= apCost
end

function ApManager.spend(combatant: Combatant.CombatantObject, apCost: number): boolean
	if not ApManager.canAfford(combatant, apCost) then
		return false
	end
	combatant.actionPoints -= apCost
	return true
end

-- `amount` may be negative (an enemy removing AP). Always clamped into
-- [0, MAX_ACTION_POINTS].
function ApManager.grant(combatant: Combatant.CombatantObject, amount: number)
	combatant.actionPoints = math.clamp(combatant.actionPoints + amount, 0, Constants.MAX_ACTION_POINTS)
end

return ApManager
