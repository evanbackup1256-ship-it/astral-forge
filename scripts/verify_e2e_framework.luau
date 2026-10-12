--!strict
-- scripts/verify_e2e_framework.luau
-- Core Test Harness & Assertion Engine for Astral Forge v2 E2E Suites

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

-- Initialize environment mocks if missing in standalone Lune
if (rawget(_G, "Color3") == nil) then
	_G.Color3 = roblox.Color3 or {
		fromRGB = function(r: number, g: number, b: number)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
		new = function(r: number, g: number, b: number)
			return { R = r, G = g, B = b }
		end,
	}
end

if (rawget(_G, "Vector2") == nil) then
	_G.Vector2 = roblox.Vector2 or {
		new = function(x: number, y: number)
			return { X = x, Y = y, Magnitude = math.sqrt(x * x + y * y) }
		end,
		zero = { X = 0, Y = 0, Magnitude = 0 },
	}
end

if (rawget(_G, "Vector3") == nil) then
	_G.Vector3 = roblox.Vector3 or {
		new = function(x: number, y: number, z: number)
			return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }
		end,
		zero = { X = 0, Y = 0, Z = 0, Magnitude = 0 },
	}
end

if (rawget(_G, "CFrame") == nil) then
	_G.CFrame = roblox.CFrame or {
		new = function(...)
			return { Position = _G.Vector3.zero }
		end,
		Angles = function(rx, ry, rz)
			return { Position = _G.Vector3.zero }
		end,
		identity = { Position = _G.Vector3.zero },
	}
end

if (rawget(_G, "UDim2") == nil) then
	_G.UDim2 = roblox.UDim2 or {
		new = function(sx: number, ox: number, sy: number, oy: number)
			return {
				X = { Scale = sx, Offset = ox },
				Y = { Scale = sy, Offset = oy },
			}
		end,
	}
end

if (rawget(_G, "NumberRange") == nil) then
	_G.NumberRange = roblox.NumberRange or {
		new = function(min: number, max: number?)
			return { Min = min, Max = max or min }
		end,
	}
end

if (rawget(_G, "NumberSequenceKeypoint") == nil) then
	_G.NumberSequenceKeypoint = {
		new = function(time: number, value: number, envelope: number?)
			return { Time = time, Value = value, Envelope = envelope or 0 }
		end,
	}
end

if (rawget(_G, "NumberSequence") == nil) then
	_G.NumberSequence = {
		new = function(points)
			return { Keypoints = points }
		end,
	}
end

export type TestCase = {
	id: string,
	tier: string,
	feature: string,
	name: string,
	fn: () -> (),
}

export type TestResult = {
	id: string,
	tier: string,
	feature: string,
	name: string,
	passed: boolean,
	error: string?,
	durationMs: number,
}

local Framework = {}
local registeredTests: { TestCase } = {}
local currentTier = "Tier 1"
local currentFeature = "Feature 1"

function Framework.setContext(tier: string, feature: string)
	currentTier = tier
	currentFeature = feature
end

function Framework.register(id: string, name: string, fn: () -> ())
	table.insert(registeredTests, {
		id = id,
		tier = currentTier,
		feature = currentFeature,
		name = name,
		fn = fn,
	})
end

-- Assertion library
function Framework.assertTrue(condition: any, message: string?)
	if not condition then
		error(message or "Expected condition to be truthy, got falsy", 2)
	end
end

function Framework.assertFalse(condition: any, message: string?)
	if condition then
		error(message or "Expected condition to be falsy, got truthy", 2)
	end
end

function Framework.assertEq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		local detail = `Expected '{tostring(expected)}' but got '{tostring(actual)}'`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertNotEq(actual: any, expected: any, message: string?)
	if actual == expected then
		local detail = `Expected actual not to equal '{tostring(expected)}'`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertNil(val: any, message: string?)
	if val ~= nil then
		local detail = `Expected nil, got '{tostring(val)}'`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertNotNil(val: any, message: string?)
	if val == nil then
		error(message or "Expected non-nil value, got nil", 2)
	end
end

function Framework.assertGte(actual: number, expected: number, message: string?)
	if actual < expected then
		local detail = `Expected {actual} >= {expected}`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertLte(actual: number, expected: number, message: string?)
	if actual > expected then
		local detail = `Expected {actual} <= {expected}`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertInRange(val: number, min: number, max: number, message: string?)
	if val < min or val > max then
		local detail = `Expected {val} to be within [{min}, {max}]`
		error(if message then `{message} | {detail}` else detail, 2)
	end
end

function Framework.assertThrows(fn: () -> (), pattern: string?, message: string?)
	local ok, err = pcall(fn)
	if ok then
		error(message or "Expected function to throw error, but it succeeded", 2)
	end
	if pattern and type(err) == "string" and not string.find(err, pattern, 1, true) then
		error(`Expected error matching pattern '{pattern}', got: {err}`, 2)
	end
end

-- Execution and Runner
function Framework.runAll(): { results: { TestResult }, passed: number, failed: number, total: number }
	local results: { TestResult } = {}
	local passed = 0
	local failed = 0
	local startTime = os.clock()

	for _, testCase in registeredTests do
		local t0 = os.clock()
		local ok, err = pcall(testCase.fn)
		local durationMs = math.floor((os.clock() - t0) * 1000 * 100) / 100

		if ok then
			passed += 1
			table.insert(results, {
				id = testCase.id,
				tier = testCase.tier,
				feature = testCase.feature,
				name = testCase.name,
				passed = true,
				durationMs = durationMs,
			})
		else
			failed += 1
			table.insert(results, {
				id = testCase.id,
				tier = testCase.tier,
				feature = testCase.feature,
				name = testCase.name,
				passed = false,
				error = tostring(err),
				durationMs = durationMs,
			})
			print(`[ERROR] [TEST_FAIL] {testCase.id} ({testCase.tier} - {testCase.feature}): {testCase.name}`)
			print(`        Details: {tostring(err)}`)
		end
	end

	local totalTimeMs = math.floor((os.clock() - startTime) * 1000)
	print(`[INFO] [SUITE_SUMMARY] Executed {passed + failed} tests in {totalTimeMs}ms | Passed: {passed} | Failed: {failed}`)

	return {
		results = results,
		passed = passed,
		failed = failed,
		total = passed + failed,
	}
end

function Framework.clear()
	table.clear(registeredTests)
end

return Framework
