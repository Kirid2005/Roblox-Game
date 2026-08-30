--!strict
-- The Speed-driven Action Gauge. This is the only place gauge-fill math
-- happens, so the "how fast do you get AP" balance question always has a
-- single answer regardless of which mode/UI triggered the tick.
--
-- Server-authoritative by construction: the scheduler that calls
-- ActionGauge.advance runs entirely server-side (see TurnScheduler.lua)
-- and uses server-measured dt, never anything reported by a client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local Combatant = require(script.Parent:WaitForChild("Combatant"))

local ActionGauge = {}

-- Pure helper: how much gauge a given Speed accrues over dtSeconds. Split
-- out from `advance` so balance/design tools and tests can probe the curve
-- without needing a full Combatant.
function ActionGauge.computeGaugeGain(speed: number, dtSeconds: number): number
	return speed * Constants.ACTION_GAUGE_RATE * dtSeconds
end

-- Drains any gauge overflow past the threshold into banked Action Points,
-- looping in case a single large gain (e.g. a Haste burst) crosses the
-- threshold multiple times at once. Returns how many AP were granted.
local function drainOverflowToAp(combatant: Combatant.CombatantObject): number
	local granted = 0
	while combatant.actionGauge >= Constants.ACTION_GAUGE_THRESHOLD do
		combatant.actionGauge -= Constants.ACTION_GAUGE_THRESHOLD
		local before = combatant.actionPoints
		combatant.actionPoints = math.clamp(combatant.actionPoints + Constants.ACTION_POINTS_PER_TICK, 0, Constants.MAX_ACTION_POINTS)
		granted += (combatant.actionPoints - before)
	end
	return granted
end

-- Advances a combatant's gauge by dtSeconds of real combat time. Stunned
-- combatants do not accrue gauge at all. Returns AP granted this call (0
-- most of the time).
function ActionGauge.advance(combatant: Combatant.CombatantObject, dtSeconds: number, currentTick: number): number
	if not combatant:isAlive() then
		return 0
	end
	if combatant:isStunned(currentTick) then
		return 0
	end

	local speed = combatant:getEffectiveStat(Enums.StatId.Speed, currentTick)
	combatant.actionGauge += ActionGauge.computeGaugeGain(speed, dtSeconds)
	return drainOverflowToAp(combatant)
end

-- Applies an instantaneous gauge delta from an ability effect (haste,
-- delay, etc.) rather than from time passing. Positive deltas can overflow
-- straight into AP just like natural fill; negative deltas are floored at
-- zero (a combatant's gauge cannot go negative).
function ActionGauge.applyDelta(combatant: Combatant.CombatantObject, amount: number): number
	combatant.actionGauge = math.max(0, combatant.actionGauge + amount)
	if amount > 0 then
		return drainOverflowToAp(combatant)
	end
	return 0
end

return ActionGauge
