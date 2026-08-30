--!strict
-- Development tool for balancing spell outcome distributions. Mass-rolls
-- a spell's outcome table using the exact same SpellResolver functions
-- production combat uses (so the simulation can never drift from real
-- behavior) and reports the realized distribution.
--
-- Usage from the Studio command bar (or a temporary debug script):
--   local Sim = require(game.ServerScriptService.Debug.ProbabilitySimulator)
--   Sim.printReport("firebolt", 100000)
--   Sim.printAllSpells(50000)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spells"):WaitForChild("SpellCatalog"))

local SpellResolver = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("SpellResolver"))

local ProbabilitySimulator = {}

export type SimulationReport = { [string]: { count: number, fraction: number } }

function ProbabilitySimulator.simulateSpell(spellId: string, iterations: number, modifiers: SpellResolver.OutcomeModifiers?): SimulationReport
	local spellDef = SpellCatalog[spellId]
	assert(spellDef, `ProbabilitySimulator: unknown spell "{spellId}"`)

	local adjusted = SpellResolver.buildAdjustedOutcomeTable(spellDef.outcomeTable, modifiers or { critChanceBonus = 0, failureResistance = 0 })
	local rng = Random.new()
	local counts: { [string]: number } = {}

	for _ = 1, iterations do
		local chosen = SpellResolver.rollOutcome(adjusted, rng)
		counts[chosen.outcome] = (counts[chosen.outcome] or 0) + 1
	end

	local report: SimulationReport = {}
	for outcome, count in counts do
		report[outcome] = { count = count, fraction = count / iterations }
	end
	return report
end

function ProbabilitySimulator.printReport(spellId: string, iterations: number, modifiers: SpellResolver.OutcomeModifiers?)
	local report = ProbabilitySimulator.simulateSpell(spellId, iterations, modifiers)
	print(`[ProbabilitySimulator] "{spellId}" over {iterations} casts:`)
	for outcome, data in report do
		print(("  %s: %d (%.2f%%)"):format(outcome, data.count, data.fraction * 100))
	end
end

function ProbabilitySimulator.printAllSpells(iterations: number)
	for spellId in SpellCatalog do
		ProbabilitySimulator.printReport(spellId, iterations)
	end
end

return ProbabilitySimulator
