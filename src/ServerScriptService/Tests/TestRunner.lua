--!strict
-- Tiny assert-based test runner, dependency-free on purpose so the test
-- suite doesn't require pulling in a third-party framework. Each spec
-- module exports a `run(): boolean` that calls TestRunner.run with a
-- table of named test functions and returns whether the whole suite
-- passed; RunAll.server.lua aggregates every spec's result.

local TestRunner = {}

export type TestResult = { name: string, ok: boolean, err: string? }

function TestRunner.run(tests: { [string]: () -> () }): { TestResult }
	local results: { TestResult } = {}
	for name, fn in tests do
		local ok, err = pcall(fn)
		table.insert(results, { name = name, ok = ok, err = if ok then nil else tostring(err) })
	end
	table.sort(results, function(a, b)
		return a.name < b.name
	end)
	return results
end

function TestRunner.report(suiteName: string, results: { TestResult }): boolean
	local passed = 0
	for _, result in results do
		if result.ok then
			passed += 1
		else
			warn(`[{suiteName}] FAIL: {result.name} -- {result.err}`)
		end
	end
	print(`[{suiteName}] {passed}/{#results} passed`)
	return passed == #results
end

function TestRunner.almostEqual(a: number, b: number, epsilon: number?): boolean
	return math.abs(a - b) <= (epsilon or 1e-6)
end

return TestRunner
