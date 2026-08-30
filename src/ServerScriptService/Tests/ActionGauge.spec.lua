--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))

local Combatant = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("Combatant"))
local ActionGauge = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ActionGauge"))
local TestRunner = require(script.Parent:WaitForChild("TestRunner"))

local ActionGaugeSpec = {}

local function makeCombatant(speed: number): Combatant.CombatantObject
	return Combatant.new({
		id = "test",
		kind = Enums.CombatantKind.NPC,
		teamId = Enums.TeamId.Alpha,
		displayName = "Test Dummy",
		player = nil,
		baseStats = {
			[Enums.StatId.MaxHealth] = 100,
			[Enums.StatId.Speed] = speed,
		},
		spellIds = {},
	})
end

function ActionGaugeSpec.run(): boolean
	local results = TestRunner.run({
		["computeGaugeGain scales linearly with speed and dt"] = function()
			local gain = ActionGauge.computeGaugeGain(100, 1)
			assert(TestRunner.almostEqual(gain, 100 * Constants.ACTION_GAUGE_RATE), `unexpected gain {gain}`)
		end,

		["advance grants AP once threshold is crossed"] = function()
			local combatant = makeCombatant(Constants.ACTION_GAUGE_THRESHOLD) -- 1 second of gauge = exactly threshold
			local granted = ActionGauge.advance(combatant, 1, 1)
			assert(granted == Constants.ACTION_POINTS_PER_TICK, `expected {Constants.ACTION_POINTS_PER_TICK}, got {granted}`)
			assert(combatant.actionGauge == 0, "gauge should be fully drained")
		end,

		["advance does not grant AP below threshold"] = function()
			local combatant = makeCombatant(Constants.ACTION_GAUGE_THRESHOLD)
			local granted = ActionGauge.advance(combatant, 0.5, 1)
			assert(granted == 0, "should not grant AP yet")
			assert(combatant.actionGauge > 0, "gauge should have partially filled")
		end,

		["stunned combatants do not accrue gauge"] = function()
			local combatant = makeCombatant(1000)
			combatant:addActiveEffect({
				id = "stun1",
				type = Enums.EffectType.Stun,
				expiresAtTick = 100,
				lastTickAtTick = 0,
			})
			local granted = ActionGauge.advance(combatant, 5, 1)
			assert(granted == 0, "stunned combatant should not gain AP")
			assert(combatant.actionGauge == 0, "stunned combatant's gauge should not move")
		end,

		["applyDelta clamps negative gauge at zero"] = function()
			local combatant = makeCombatant(100)
			ActionGauge.applyDelta(combatant, -500)
			assert(combatant.actionGauge == 0, "gauge should floor at zero")
		end,

		["AP is clamped to MAX_ACTION_POINTS"] = function()
			local combatant = makeCombatant(Constants.ACTION_GAUGE_THRESHOLD * (Constants.MAX_ACTION_POINTS + 5))
			ActionGauge.advance(combatant, 1, 1)
			assert(combatant.actionPoints == Constants.MAX_ACTION_POINTS, `expected clamp at {Constants.MAX_ACTION_POINTS}, got {combatant.actionPoints}`)
		end,
	})
	return TestRunner.report("ActionGauge", results)
end

return ActionGaugeSpec
