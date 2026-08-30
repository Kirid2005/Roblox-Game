--!strict
-- Runs every *.spec module in this folder and prints a summary. Only runs
-- in Studio (never in a live game server) -- delete this guard if you
-- wire the project into an external CI runner that boots a real server
-- instead of Studio.

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local specs = {
	require(script.Parent:WaitForChild("StatCalculator.spec")),
	require(script.Parent:WaitForChild("DamageCalculator.spec")),
	require(script.Parent:WaitForChild("ActionGauge.spec")),
	require(script.Parent:WaitForChild("RatingService.spec")),
	require(script.Parent:WaitForChild("SpellResolver.spec")),
}

task.spawn(function()
	local allPassed = true
	for _, spec in specs do
		local passed = spec.run()
		allPassed = allPassed and passed
	end
	print(allPassed and "[Tests] ALL SUITES PASSED" or "[Tests] SOME SUITES FAILED -- see warnings above")
end)
