--!strict
-- scripts/challenger_m5_1_stress.luau
-- Milestone 5 Adversarial Stress & Empirical Verification Harness
-- Author: Challenger M5-1 (critic, specialist)
-- Workspace Root: c:\Users\evanm\OneDrive\Desktop\Astral Forge v2

local fs = require("@lune/fs")
local task = require("@lune/task")
local roblox = require("@lune/roblox")

-- Lune Environment Mocks for Roblox APIs
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }
Vector2 = roblox.Vector2 or { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
Vector3 = roblox.Vector3 or { new = function(x, y, z) return { X = x, Y = y, Z = z } end, zero = { X = 0, Y = 0, Z = 0 } }

local dummySignal = { Connect = function() return { Disconnect = function() end } end }
local mockGuiService = {
	AutoSelectGuiEnabled = false,
	GuiNavigationEnabled = false,
	SelectedObject = nil,
	safeArea = roblox.Rect.new(0, 0, 1920, 1080),
	topLeft = roblox.Vector2.new(0, 0),
	bottomRight = roblox.Vector2.new(0, 0),
	GetInsetArea = function(self, insetEnum) return self.safeArea end,
	GetGuiInset = function(self) return self.topLeft, self.bottomRight end,
	IsTenFootInterface = function(self) return false end,
}

local mockUserInputService = {
	PreferredInput = 1,
	TouchEnabled = true,
	GamepadConnected = dummySignal,
	GamepadDisconnected = dummySignal,
	InputBegan = dummySignal,
	InputChanged = dummySignal,
	InputEnded = dummySignal,
	GetPropertyChangedSignal = function(self, prop) return dummySignal end,
	GetStringForKeyCode = function(self, code) return tostring(code) end,
}

local mockWorkspace = {
	CurrentCamera = {
		ViewportSize = roblox.Vector2.new(1920, 1080),
	},
}

local mockPlayers = {
	LocalPlayer = {
		FindFirstChildOfClass = function(self, className) return nil end,
	},
}

local mockReplicatedStorage = {
	GetAttribute = function(self, attr) return false end,
	FindFirstChild = function(self, child) return nil end,
}

local globalEnv = (getfenv and getfenv()) or _G
if globalEnv.task == nil then
	globalEnv.task = task
end
if globalEnv.Color3 == nil then
	globalEnv.Color3 = Color3
end
if globalEnv.Vector2 == nil then
	globalEnv.Vector2 = Vector2
end
if globalEnv.Vector3 == nil then
	globalEnv.Vector3 = Vector3
end
if globalEnv.game == nil then
	globalEnv.game = {
		ReplicatedStorage = mockReplicatedStorage,
		GetService = function(self, name)
			if name == "GuiService" then
				return mockGuiService
			elseif name == "Workspace" then
				return mockWorkspace
			elseif name == "Players" then
				return mockPlayers
			elseif name == "ReplicatedStorage" then
				return mockReplicatedStorage
			elseif name == "UserInputService" then
				return mockUserInputService
			end
			return nil
		end,
	}
end
if globalEnv.workspace == nil then
	globalEnv.workspace = mockWorkspace
end
if globalEnv.Enum == nil then
	globalEnv.Enum = {}
end
globalEnv.Enum.ScreenInsets = globalEnv.Enum.ScreenInsets or { DeviceSafeInsets = "DeviceSafeInsets" }
globalEnv.Enum.PreferredInput = globalEnv.Enum.PreferredInput or { Touch = 1, Gamepad = 2, MicroGamepad = 3 }
globalEnv.Enum.UserInputType = globalEnv.Enum.UserInputType or { Gamepad1 = 1 }
globalEnv.Enum.KeyCode = globalEnv.Enum.KeyCode or {
	ButtonA = 1, ButtonB = 2, ButtonX = 3, ButtonY = 4,
	ButtonL1 = 5, ButtonR1 = 6, ButtonL2 = 7, ButtonR2 = 8,
	ButtonSelect = 9, ButtonStart = 10,
}

print("================================================================================")
print("  MILESTONE 5 EMPIRICAL ADVERSARIAL STRESS TEST SUITE — CHALLENGER M5-1")
print("================================================================================")

local testCount = 0
local passCount = 0
local failCount = 0

local function check(id: string, description: string, fn: () -> ())
	testCount += 1
	local ok, err = pcall(fn)
	if ok then
		passCount += 1
		print(string.format("  [PASS] [%s] %s", id, description))
	else
		failCount += 1
		print(string.format("  [FAIL] [%s] %s", id, description))
		print(string.format("         Error: %s", tostring(err)))
	end
end

--------------------------------------------------------------------------------
-- SUBSYSTEM IMPORTS
--------------------------------------------------------------------------------
local Omega = require("../src/Shared/AstralForge/Shared/OmegaMath")
local SecurityServices = require("../src/Server/AstralForge/Services/SecurityServices")
local AtomicState = SecurityServices("AtomicState")()
local ProfileVersionGuard = require("../src/Server/AstralForge/Modules/ProfileVersionGuard")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")
local MotionTokens = require("../src/Client/AstralForge/MotionKit")("motionTokens")
local CoreKit = require("../src/Client/AstralForge/CoreKit")
local mobileLayout = CoreKit("mobileLayout")
local planMobileLayout = mobileLayout.planMobileLayout
local TouchGestureService = CoreKit("TouchGestureService")
local GamepadNav = CoreKit("GamepadNavigationService")
local NoticeMath = CoreKit("noticeMath")

--------------------------------------------------------------------------------
-- SUITE 1: TIER 5 ITERATIVE STRESS & DETERMINISM (10 REPETITIONS)
--------------------------------------------------------------------------------
print("\n--- SUITE 1: Tier 5 Iterative Execution & Determinism Under Varied Conditions ---")

check("T5-STRESS-01", "Repeated execution of Tier 5 adversarial tests across 10 iterations without state drift", function()
	for i = 1, 10 do
		local prevRunner = _G.__E2E_SUITE_RUNNER__
		_G.__E2E_SUITE_RUNNER__ = true
		local t5 = require("./verify_e2e_tier5")
		_G.__E2E_SUITE_RUNNER__ = prevRunner
		assert(t5 == true, "Tier 5 suite returned true on execution")
	end
end)

check("T5-STRESS-02", "Concurrent Modal Spring Physics under high-frequency chaotic delta-time jitter (500 steps)", function()
	local feel = MotionTokens.SPRING.smooth
	local feelParams = MotionTokens.feel(feel.stiffness, feel.damping)

	local pos = 0.0
	local vel = 0.0
	local target = 1.0

	local dtSequence = { 0.0005, 0.016, 0.033, 0.002, 0.065, 0.010, 0.080, 0.001 }
	for step = 1, 500 do
		local dt = dtSequence[(step % #dtSequence) + 1]
		if step % 25 == 0 then
			target = if target == 1.0 then 0.0 else 1.0
		end
		pos, vel = MotionTokens.step(pos, vel, target, feelParams, dt)
		assert(pos == pos, `Position became NaN at step {step}`)
		assert(vel == vel, `Velocity became NaN at step {step}`)
		assert(math.abs(vel) < 5000, `Velocity unbounded ({vel}) at step {step}`)
	end

	-- Settle phase
	for _ = 1, 120 do
		pos, vel = MotionTokens.step(pos, vel, target, feelParams, 0.016)
	end
	assert(math.abs(pos - target) < 0.005, `Spring failed to settle at target: {pos} vs {target}`)
	assert(math.abs(vel) < 0.01, `Spring failed to settle velocity: {vel}`)
end)

--------------------------------------------------------------------------------
-- SUITE 2: DEEP ASTRONOMICAL MATHEMATICS WITH OMEGAMATH (UP TO 10^300)
--------------------------------------------------------------------------------
print("\n--- SUITE 2: Deep Astronomical Mathematics & Precision with OmegaMath (Up to 10^300) ---")

check("OMEGA-01", "Addition & Subtraction at astronomical scales (10^50, 10^100, 10^200, 10^300)", function()
	local powers = { 50, 100, 200, 300 }
	for _, p in powers do
		local aStr = string.format("1.000000000000e%d", p)
		local bStr = string.format("2.500000000000e%d", p)
		local sum = Omega.Add(aStr, bStr)
		local expectedSum = string.format("3.500000000000e%d", p)
		assert(Omega.Compare(sum, expectedSum) == 0, `Sum mismatch at 10^{p}: {Omega.ToString(sum)} vs {expectedSum}`)

		local diff = Omega.Sub(sum, aStr)
		assert(Omega.Compare(diff, bStr) == 0, `Diff mismatch at 10^{p}: {Omega.ToString(diff)} vs {bStr}`)

		-- Self-subtraction must return 0
		local zeroDiff = Omega.Sub(aStr, aStr)
		assert(Omega.Compare(zeroDiff, 0) == 0, `Self-subtraction at 10^{p} did not return 0`)
	end
end)

check("OMEGA-02", "Multiplication & Division at astronomical scales (products up to 10^300)", function()
	local p1 = "1.000000000000e120"
	local p2 = "3.000000000000e180"
	local product = Omega.Mul(p1, p2)
	assert(Omega.Compare(product, "3.000000000000e300") == 0, `Mul mismatch: {Omega.ToString(product)}`)

	local quotient = Omega.Div(product, p1)
	assert(Omega.Compare(quotient, p2) == 0, `Div mismatch: {Omega.ToString(quotient)} vs {p2}`)

	local quotient2 = Omega.Div(product, p2)
	assert(Omega.Compare(quotient2, p1) == 0, `Div mismatch 2: {Omega.ToString(quotient2)} vs {p1}`)
end)

check("OMEGA-03", "Precision preservation within 18 orders of magnitude at 10^300", function()
	local large = "1.000000000000e300"

	-- Case A: Close orders of magnitude (difference of 2 decades: 10^300 + 10^298)
	local closeSmall = "1.000000000000e298"
	local closeSum = Omega.Add(large, closeSmall)
	assert(Omega.Gt(closeSum, large), "Adding 10^298 to 10^300 strictly increases value")
	local closeDiff = Omega.Sub(closeSum, large)
	local closeDiffExp = Omega.Log10(closeDiff)
	local closeExpectedExp = Omega.Log10(closeSmall)
	assert(math.abs(closeDiffExp - closeExpectedExp) < 1e-6, `Close subtraction exponent restored within 1e-6 epsilon: {closeDiffExp} vs {closeExpectedExp}`)

	-- Case B: Intermediate orders of magnitude (difference of 10 decades: 10^300 + 10^290)
	local midSmall = "1.000000000000e290"
	local midSum = Omega.Add(large, midSmall)
	assert(Omega.Gt(midSum, large), "Adding 10^290 to 10^300 strictly increases value")
	local midDiff = Omega.Sub(midSum, large)
	local diffExp = Omega.Log10(midDiff)
	local expectedExp = Omega.Log10(midSmall)
	assert(math.abs(diffExp - expectedExp) < 1e-4, `Intermediate subtraction exponent matches within float cancellation tolerance: {diffExp} vs {expectedExp}`)

	-- Case C: Distant orders of magnitude (> 18 decades: 10^300 + 10^280)
	local tiny = "1.000000000000e280"
	local sumBeyond = Omega.Add(large, tiny)
	assert(Omega.Compare(sumBeyond, large) == 0, "Terms beyond 18 decades gracefully absorb into magnitude")
end)

check("OMEGA-04", "Negative numbers and sign transitions at astronomical scales", function()
	local pos = "5.000000000000e150"
	local neg = "-2.000000000000e150"
	local sum = Omega.Add(pos, neg)
	assert(Omega.Compare(sum, "3.000000000000e150") == 0, `Signed addition: {Omega.ToString(sum)}`)

	local sub = Omega.Sub(neg, pos)
	assert(Omega.Compare(sub, "-7.000000000000e150") == 0, `Negative subtraction: {Omega.ToString(sub)}`)

	local mul = Omega.Mul(pos, neg)
	assert(Omega.Compare(mul, "-1.000000000000e301") == 0, `Signed multiplication: {Omega.ToString(mul)}`)
end)

check("OMEGA-05", "Defensive handling of malformed, NaN, and infinite inputs", function()
	-- Native non-finite
	assert(Omega.ToNumber(0/0) == 0, "Native NaN converts to 0")
	assert(Omega.ToNumber(math.huge) == 1.7976931348623157e+308, "Math.huge clamps to MAX_DOUBLE in ToNumber")
	assert(Omega.ToNumber(-math.huge) == -1.7976931348623157e+308, "-Math.huge clamps to -MAX_DOUBLE in ToNumber")

	-- String forms
	assert(Omega.Compare(Omega.New("NaN"), 0) == 0, "'NaN' string sanitized to 0")
	assert(Omega.Compare(Omega.New("nan"), 0) == 0, "'nan' string sanitized to 0")
	assert(Omega.Compare(Omega.New(""), 0) == 0, "Empty string sanitized to 0")
	assert(Omega.Compare(Omega.New("malformed_text"), 0) == 0, "Malformed string sanitized to 0")

	-- Division by zero
	local divZero = Omega.Div("1.000e+50", 0)
	assert(Omega.ToString(divZero) == "inf", "Division by zero returns 'inf'")
	local zeroDivZero = Omega.Div(0, 0)
	assert(Omega.Compare(zeroDivZero, 0) == 0, "0 / 0 returns 0")

	-- Multiplication with zero
	assert(Omega.Compare(Omega.Mul(0, "1.000e+300"), 0) == 0, "0 * 10^300 is 0")
	assert(Omega.Compare(Omega.Mul("1.000e+300", 0), 0) == 0, "10^300 * 0 is 0")
end)

check("OMEGA-06", "AffordableCount and GeometricSum at 10^300 scale", function()
	local baseCost = 1000
	local scale = 1.15
	local level = 1
	local cash = "1.000000000000e300"
	local maximum = 50_000

	local count, totalCost = Omega.AffordableCount(baseCost, scale, level, cash, maximum)
	assert(count > 0, `AffordableCount returned positive buy count ({count})`)
	assert(Omega.Lte(totalCost, cash), "Total cost does not exceed cash balance")

	-- GeometricSum monotonicity: buying count + 1 costs more
	local nextCost = Omega.GeometricSum(baseCost, scale, level, count + 1)
	assert(Omega.Gt(nextCost, totalCost), "GeometricSum strictly monotonic")
end)

check("OMEGA-07", "Transition boundary across exponent 15 (native number <-> scientific string)", function()
	local crossSum = Omega.Add(5e14, 6e14)
	assert(type(crossSum) == "string", `Expected string persistence for >= 1e15, got {type(crossSum)}`)
	assert(Omega.Compare(crossSum, "1.100000000000e15") == 0, `Cross sum matches 1.1e15: {crossSum}`)

	local dropDiff = Omega.Sub(crossSum, 2e14)
	assert(type(dropDiff) == "number", `Expected number persistence for < 1e15, got {type(dropDiff)}`)
	assert(math.abs(dropDiff - 9e14) < 1, `Drop diff matches 9e14: {dropDiff}`)

	local crossMul = Omega.Mul(1e8, 1e8)
	assert(type(crossMul) == "string", `Mul expected string: {crossMul}`)
	assert(Omega.Compare(crossMul, "1.000000000000e16") == 0, "1e8 * 1e8 matches 1e16")
end)

check("OMEGA-08", "Large power evaluations (Pow up to 10^300 and beyond)", function()
	local pow10_300 = Omega.Pow(10, 300)
	assert(Omega.Compare(pow10_300, "1.000000000000e300") == 0, `10^300 matches: {Omega.ToString(pow10_300)}`)

	local powCompound = Omega.Pow("1.000000000000e100", 3)
	assert(Omega.Compare(powCompound, "1.000000000000e300") == 0, `(10^100)^3 matches: {Omega.ToString(powCompound)}`)

	local powBeyond = Omega.Pow(10, 1e19)
	assert(Omega.ToString(powBeyond) == "inf", "Powers beyond HUGE_EXP cap at 'inf'")
end)

--------------------------------------------------------------------------------
-- SUITE 3: ATOMIC ROLLBACK & CORRUPT PROFILE SANITIZATION
--------------------------------------------------------------------------------
print("\n--- SUITE 3: Atomic Rollback on Failure & Corrupt Profile Sanitization ---")

check("ROLLBACK-01", "AtomicState rollback on business logic rejection (100 rapid transactions)", function()
	local atom = AtomicState.new({
		Meta = { Revision = 1 },
		Cash = 1000,
		Items = { Essence = 5 },
	})

	for txn = 1, 100 do
		local attemptOverdraft = txn % 2 == 0
		local ok, res, rev = atom:Transact(function(draft)
			if attemptOverdraft then
				if draft.Cash < 5000 then
					return { ok = false, error = "OVERDRAFT" }
				end
				draft.Cash -= 5000
				return { ok = true }
			else
				draft.Cash += 10
				draft.Items.Essence += 1
				return { ok = true }
			end
		end)

		assert(ok, `Transact call {txn} executed cleanly`)
		if attemptOverdraft then
			assert(res.ok == false, `Transact {txn} rejected overdraft`)
		else
			assert(res.ok == true, `Transact {txn} accepted valid addition`)
		end
	end

	local finalVal, finalRev = atom:Read()
	assert(finalVal.Cash == 1000 + 50 * 10, `Cash expected 1500, got {finalVal.Cash}`)
	assert(finalVal.Items.Essence == 5 + 50 * 1, `Essence expected 55, got {finalVal.Items.Essence}`)
	assert(finalRev == 1 + 50, `Revision watermark expected 51, got {finalRev}`)
end)

check("ROLLBACK-02", "AtomicState rollback on thrown Lua exceptions mid-mutation", function()
	local atom = AtomicState.new({
		Meta = { Revision = 10 },
		Cash = 500,
		CorruptedFlag = false,
	})

	local ok, err, rev = atom:Transact(function(draft)
		draft.Cash = 999999999
		draft.CorruptedFlag = true
		error("SIMULATED_DATABASE_FAILURE")
	end)

	assert(ok == false, "Transact caught thrown error")
	assert(string.find(tostring(err), "SIMULATED_DATABASE_FAILURE") ~= nil, "Error message preserved")

	local val, readRev = atom:Read()
	assert(val.Cash == 500, `Cash was not rolled back: {val.Cash}`)
	assert(val.CorruptedFlag == false, "Corrupted flag leaked into state!")
	assert(readRev == 10, `Revision incremented despite failure: {readRev}`)
end)

check("ROLLBACK-03", "Deeply nested table isolation on transaction rollback", function()
	local atom = AtomicState.new({
		Meta = { Revision = 5 },
		Profile = {
			Inventory = {
				Slots = {
					[1] = { Id = "CoreA", Count = 10 },
					[2] = { Id = "CoreB", Count = 20 },
				},
				Stats = { TotalBought = 100 },
			},
		},
	})

	local ok, res, rev = atom:Transact(function(draft)
		draft.Profile.Inventory.Slots[1].Count = 99999
		draft.Profile.Inventory.Stats.TotalBought = 88888
		table.insert(draft.Profile.Inventory.Slots, { Id = "PoisonItem", Count = 1 })
		return { ok = false, error = "TRANSACTION_CANCELLED" }
	end)

	assert(ok == true, "Transact executed cleanly")
	assert(res.ok == false, "Transact returned failure")

	local currentVal, currentRev = atom:Read()
	assert(currentRev == 5, `Revision unchanged on rollback: {currentRev}`)
	assert(currentVal.Profile.Inventory.Slots[1].Count == 10, "Deep nested count was NOT rolled back!")
	assert(currentVal.Profile.Inventory.Stats.TotalBought == 100, "Deep nested stats were NOT rolled back!")
	assert(#currentVal.Profile.Inventory.Slots == 2, "Inserted poison item was NOT rolled back!")
end)

check("SANITIZE-01", "Defensive sanitization of corrupted, malicious, and NaN profile data", function()
	local hostileData = {
		DataVersion = 21,
		Cash = -1_000_000,
		Vault = 0/0,
		Cores = math.huge,
		Stardust = -math.huge,
		Rebirths = 3,
		PlayerName = "BadActor\x00\x01\x1F\x7F",
		Bag = {
			ItemA = -5,
			ItemB = 0/0,
			ItemC = math.huge,
			ItemD = 10,
		},
	}

	local scrubbed = DataSanitizeMath.DeepCopy(hostileData)
	DataSanitizeMath.ScrubNonFinite(scrubbed)

	assert(scrubbed.Vault == 0, `Vault NaN scrubbed to 0 (got {scrubbed.Vault})`)
	assert(scrubbed.Cores == 0, `Cores +inf scrubbed to 0 (got {scrubbed.Cores})`)
	assert(scrubbed.Stardust == 0, `Stardust -inf scrubbed to 0 (got {scrubbed.Stardust})`)
	assert(scrubbed.Bag.ItemB == 0, `ItemB NaN scrubbed to 0 (got {scrubbed.Bag.ItemB})`)
	assert(scrubbed.Bag.ItemC == 0, `ItemC +inf scrubbed to 0 (got {scrubbed.Bag.ItemC})`)

	scrubbed.Cash = DataSanitizeMath.NonNegative(scrubbed.Cash)
	assert(scrubbed.Cash == 0, `Negative cash clamped to 0 (got {scrubbed.Cash})`)

	local safeName = string.gsub(scrubbed.PlayerName, "[%c]", "")
	assert(safeName == "BadActor", `Control chars stripped: got "{safeName}"`)

	local readVer = ProfileVersionGuard.ReadCompatible(hostileData, 21)
	assert(readVer == 21, `DataVersion 21 compatible (got {readVer})`)

	local futureData = { DataVersion = 999 }
	local okFuture = pcall(function()
		ProfileVersionGuard.ReadCompatible(futureData, 21)
	end)
	assert(okFuture == false, "ProfileVersionGuard rejected future schema DataVersion 999")
end)

--------------------------------------------------------------------------------
-- SUITE 4: CONSOLE & HARDWARE INSET INTEGRITY
--------------------------------------------------------------------------------
print("\n--- SUITE 4: Console & Hardware Inset Integrity ---")

check("HW-01", "8% TV Safe Margins across multiple resolutions (1080p, 4K, 720p)", function()
	local resolutions = {
		{ name = "720p", size = roblox.Vector2.new(1280, 720), expLeft = 102, expTop = 57 },
		{ name = "1080p", size = roblox.Vector2.new(1920, 1080), expLeft = 153, expTop = 86 },
		{ name = "4K", size = roblox.Vector2.new(3840, 2160), expLeft = 307, expTop = 172 },
	}

	for _, res in resolutions do
		local insets = GamepadNav.GetTVSafeInsets(res.size)
		assert(insets.left == res.expLeft, `{res.name} left inset expected {res.expLeft}, got {insets.left}`)
		assert(insets.right == res.expLeft, `{res.name} right inset expected {res.expLeft}, got {insets.right}`)
		assert(insets.top == res.expTop, `{res.name} top inset expected {res.expTop}, got {insets.top}`)
		assert(insets.bottom == res.expTop, `{res.name} bottom inset expected {res.expTop}, got {insets.bottom}`)
	end
end)

check("HW-02", "Touch Fat-Finger resolution is strictly bounded by 14px expansion (0 to 38px pass, >= 39px fail)", function()
	local rootFrame = {
		ClassName = "ScreenGui",
		Visible = true,
		Enabled = true,
		IsA = function(self, cls) return cls == "ScreenGui" end,
	}
	local btn = {
		ClassName = "Frame",
		Visible = true,
		Enabled = true,
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(100, 100),
		AbsoluteSize = roblox.Vector2.new(48, 48),
		IsA = function(self, cls) return cls == "Frame" or cls == "GuiObject" end,
	}

	local hits = 0
	TouchGestureService.RegisterTouchTarget("StressBtn", btn, function() hits += 1 end, 1)

	assert(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(124, 124)) == true, "Center hit")
	assert(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(148, 124)) == true, "Edge hit")
	assert(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(162, 124)) == true, "14px threshold hit")
	assert(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(163, 124)) == false, "15px threshold miss")

	TouchGestureService.UnregisterTouchTarget("StressBtn")
end)

check("LAYOUT-01", "planMobileLayout under minimal boundary viewports (240x240, 320x480)", function()
	local minimal = planMobileLayout({
		width = 240,
		height = 240,
		orientationWidth = 240,
		orientationHeight = 240,
		compact = true,
		tight = true,
		short = true,
		desktop = false,
		bottomInset = 10,
		sideInset = 10,
	})
	assert(minimal.contentBudget > 0, `Minimal viewport has positive contentBudget ({minimal.contentBudget})`)
	assert(minimal.sideSafe >= 10, "Side safe honors insets")
	assert(minimal.bottomSafe >= 10, "Bottom safe honors insets")
end)

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------
print("\n================================================================================")
print(string.format("  CHALLENGER M5-1 STRESS SUITE: %d / %d TESTS PASSED", passCount, testCount))
print("================================================================================")

if failCount > 0 then
	error(string.format("[FATAL] %d test(s) failed out of %d total!", failCount, testCount))
end

return true
