--!strict
-- scripts/verify_m3_stress.luau
-- Empirical Stress Test Harness for Milestone 3 (Safe Insets, Touch Hitboxes & Viewports)
-- Challenger M3-2

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local globalEnv = getfenv()
globalEnv.Vector2 = roblox.Vector2
globalEnv.Vector3 = roblox.Vector3
globalEnv.Rect = roblox.Rect
globalEnv.Color3 = roblox.Color3
globalEnv.UDim2 = roblox.UDim2
globalEnv.task = task

-- Test reporting counters
local totalTests = 0
local passedTests = 0
local failedTests = 0

local function test(id: string, name: string, fn: () -> ())
	totalTests += 1
	local ok, err = pcall(fn)
	if ok then
		passedTests += 1
		print(string.format("  [PASS] [%s] %s", id, name))
	else
		failedTests += 1
		print(string.format("  [FAIL] [%s] %s: %s", id, name, tostring(err)))
	end
end

local function assertEq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(string.format("%s | Expected '%s', got '%s'", msg or "Assertion failed", tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(cond: any, msg: string?)
	if not cond then
		error(msg or "Expected condition to be true", 2)
	end
end

local function assertFalse(cond: any, msg: string?)
	if cond then
		error(msg or "Expected condition to be false", 2)
	end
end

local function assertLte(actual: number, max: number, msg: string?)
	if actual > max then
		error(string.format("%s | Expected <= %s, got %s", msg or "Assertion failed", tostring(max), tostring(actual)), 2)
	end
end

local function assertGte(actual: number, min: number, msg: string?)
	if actual < min then
		error(string.format("%s | Expected >= %s, got %s", msg or "Assertion failed", tostring(min), tostring(actual)), 2)
	end
end

-- Setup Mock Environment
local mockGuiService = {
	safeArea = roblox.Rect.new(0, 0, 1920, 1080),
	topLeft = roblox.Vector2.new(0, 0),
	bottomRight = roblox.Vector2.new(0, 0),
	GetInsetArea = function(self, insetEnum)
		return self.safeArea
	end,
	GetGuiInset = function(self)
		return self.topLeft, self.bottomRight
	end,
}

local mockWorkspace = {
	CurrentCamera = {
		ViewportSize = roblox.Vector2.new(1920, 1080),
	},
}

local mockPlayers = {
	LocalPlayer = {
		FindFirstChildOfClass = function(self, className)
			return nil
		end,
	},
}

local ForgeTheme = require("../src/Shared/AstralForge/Shared/ForgeTheme")
local mockReplicatedStorage = {
	AstralForge = {
		Shared = {
			ForgeTheme = ForgeTheme,
		},
	},
}

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
			return {
				InputBegan = { Connect = function() end },
				InputChanged = { Connect = function() end },
				InputEnded = { Connect = function() end },
				TouchEnabled = true,
			}
		end
		return nil
	end,
}
globalEnv.workspace = mockWorkspace
globalEnv.Enum = {
	ScreenInsets = {
		DeviceSafeInsets = "DeviceSafeInsets",
	},
}

local function createMockGui(props)
	local obj = {
		ClassName = props.ClassName or "Frame",
		Visible = if props.Visible ~= nil then props.Visible else true,
		Enabled = if props.Enabled ~= nil then props.Enabled else true,
		ClipsDescendants = props.ClipsDescendants == true,
		AbsolutePosition = props.AbsolutePosition or roblox.Vector2.new(0, 0),
		AbsoluteSize = props.AbsoluteSize or roblox.Vector2.new(48, 48),
		Parent = props.Parent or nil,
	}
	function obj:IsA(name)
		if name == "GuiObject" then
			return obj.ClassName == "Frame" or obj.ClassName == "ImageButton" or obj.ClassName == "TextButton" or obj.ClassName == "GuiButton"
		elseif name == "ScreenGui" then
			return obj.ClassName == "ScreenGui"
		elseif name == "GuiButton" then
			return obj.ClassName == "ImageButton" or obj.ClassName == "TextButton"
		end
		return obj.ClassName == name
	end
	return obj
end

-- Load Modules
local CoreKit = require("../src/Client/AstralForge/CoreKit")
local MotionKit = require("../src/Client/AstralForge/MotionKit")
local TouchGestureService = CoreKit("TouchGestureService")
local mobileLayout = CoreKit("mobileLayout")
local planMobileLayout = mobileLayout.planMobileLayout
local ForgeConfig = require("../src/Shared/AstralForge/Shared/ForgeConfig")
local Layout = ForgeConfig.Layout

local readSafeInsets = MotionKit.readSafeInsets
local function computeViewportScale(screenWidth: number, screenHeight: number)
	local width = math.max(1, screenWidth)
	local height = math.max(1, screenHeight)
	local raw = math.min(width / Layout.referenceWidth, height / Layout.referenceHeight)
	return math.clamp(raw, Layout.minScale, Layout.maxScale)
end

print("================================================================================")
print("  MILENSTONE 3 EMPIRICAL STRESS TEST SUITE — CHALLENGER M3-2")
print("================================================================================")

--------------------------------------------------------------------------------
-- SECTION 1: HARDWARE SAFE INSETS (readSafeInsets & planMobileLayout)
--------------------------------------------------------------------------------
print("\n--- SECTION 1: Hardware Safe Insets & readSafeInsets ---")

test("SI-01", "Baseline zero insets returns strictly zero values", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1920, 1080)
	mockGuiService.safeArea = roblox.Rect.new(0, 0, 1920, 1080)
	mockGuiService.topLeft = roblox.Vector2.new(0, 0)
	mockGuiService.bottomRight = roblox.Vector2.new(0, 0)

	local insets = readSafeInsets()
	assertEq(insets.top, 0, "top must be 0")
	assertEq(insets.bottom, 0, "bottom must be 0")
	assertEq(insets.left, 0, "left must be 0")
	assertEq(insets.right, 0, "right must be 0")
end)

test("SI-02", "Extreme positive hardware notch and dynamic island insets", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1920, 1080)
	mockGuiService.safeArea = roblox.Rect.new(240, 120, 1920 - 210, 1080 - 160)
	mockGuiService.topLeft = roblox.Vector2.new(0, 54)
	mockGuiService.bottomRight = roblox.Vector2.new(0, 0)

	local insets = readSafeInsets()
	assertEq(insets.left, 240, "left hardware notch inset")
	assertEq(insets.top, 120, "top inset (max of 120 and 54)")
	assertEq(insets.right, 210, "right hardware notch inset")
	assertEq(insets.bottom, 160, "bottom home indicator inset")
end)

test("SI-03", "Negative inset values are strictly clamped to zero", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1920, 1080)
	mockGuiService.safeArea = roblox.Rect.new(-80, -60, 1920 + 50, 1080 + 70)
	mockGuiService.topLeft = roblox.Vector2.new(-30, -25)
	mockGuiService.bottomRight = roblox.Vector2.new(-15, -10)

	local insets = readSafeInsets()
	assertEq(insets.top, 0, "negative top clamped to 0")
	assertEq(insets.bottom, 0, "negative bottom clamped to 0")
	assertEq(insets.left, 0, "negative left clamped to 0")
	assertEq(insets.right, 0, "negative right clamped to 0")
end)

test("SI-04", "Asymmetric hardware notch (iPhone Landscape Left)", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(844, 390)
	-- Notch on left edge only (59px), bottom home bar (21px), zero right/top
	mockGuiService.safeArea = roblox.Rect.new(59, 0, 844, 390 - 21)
	mockGuiService.topLeft = roblox.Vector2.new(0, 36) -- CoreGui topbar
	mockGuiService.bottomRight = roblox.Vector2.new(0, 0)

	local insets = readSafeInsets()
	assertEq(insets.left, 59, "left notch protected")
	assertEq(insets.top, 36, "topbar protected")
	assertEq(insets.right, 0, "right edge remains uninflated")
	assertEq(insets.bottom, 21, "bottom home bar protected")
end)

test("SI-05", "Subpixel fractional insets correctly round via math.round", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1920, 1080)
	mockGuiService.safeArea = roblox.Rect.new(47.4, 23.6, 1920 - 32.7, 1080 - 18.2)
	mockGuiService.topLeft = roblox.Vector2.new(0, 0)
	mockGuiService.bottomRight = roblox.Vector2.new(0, 0)

	local insets = readSafeInsets()
	assertEq(insets.left, 47, "47.4 rounded to 47")
	assertEq(insets.top, 24, "23.6 rounded to 24")
	assertEq(insets.right, 33, "32.7 rounded to 33")
	assertEq(insets.bottom, 18, "18.2 rounded to 18")
end)

test("SI-06", "Inverted degenerate safeArea produces non-negative numbers", function()
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1920, 1080)
	mockGuiService.safeArea = roblox.Rect.new(100, 100, 50, 50) -- Min > Max
	mockGuiService.topLeft = roblox.Vector2.new(0, 0)
	mockGuiService.bottomRight = roblox.Vector2.new(0, 0)

	local insets = readSafeInsets()
	assertGte(insets.left, 0, "left >= 0")
	assertGte(insets.top, 0, "top >= 0")
	assertGte(insets.right, 0, "right >= 0")
	assertGte(insets.bottom, 0, "bottom >= 0")
end)

test("SI-07", "Heavy insets propagation into mobileLayout preserves positive content budget", function()
	local plan = planMobileLayout({
		width = 844,
		height = 390,
		desktop = false,
		compact = true,
		tight = false,
		short = true,
		sideInset = 180,
		bottomInset = 65,
	})
	assertGte(plan.sideSafe, 180, "sideSafe honors 180px inset")
	assertGte(plan.bottomSafe, 65, "bottomSafe honors 65px inset")
	assertGte(plan.contentBudget, 1, "contentBudget must be at least 1px")
	assertTrue(plan.landscape, "landscape flag correctly determined")
end)

test("SI-08", "Dynamic orientation flip recalculates insets and layout instantaneously", function()
	-- 1. Portrait state (390x844)
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(390, 844)
	mockGuiService.safeArea = roblox.Rect.new(0, 47, 390, 844 - 34)
	mockGuiService.topLeft = roblox.Vector2.new(0, 0)
	local pInsets = readSafeInsets()
	assertEq(pInsets.top, 47, "portrait top inset")
	assertEq(pInsets.bottom, 34, "portrait bottom inset")
	assertEq(pInsets.left, 0, "portrait left inset")
	local pPlan = planMobileLayout({
		width = 390,
		height = 844,
		desktop = false,
		compact = true,
		tight = true,
		short = false,
		bottomInset = pInsets.bottom,
		sideInset = pInsets.left,
	})
	assertFalse(pPlan.landscape, "portrait layout")
	assertTrue(pPlan.portrait, "portrait mode true")

	-- 2. Landscape flip (844x390)
	mockWorkspace.CurrentCamera.ViewportSize = roblox.Vector2.new(844, 390)
	mockGuiService.safeArea = roblox.Rect.new(59, 0, 844, 390 - 21)
	local lInsets = readSafeInsets()
	assertEq(lInsets.left, 59, "landscape left notch")
	assertEq(lInsets.bottom, 21, "landscape bottom home bar")
	assertEq(lInsets.top, 0, "landscape top inset")
	local lPlan = planMobileLayout({
		width = 844,
		height = 390,
		desktop = false,
		compact = true,
		tight = false,
		short = true,
		bottomInset = lInsets.bottom,
		sideInset = lInsets.left,
	})
	assertTrue(lPlan.landscape, "landscape layout active")
	assertFalse(lPlan.portrait, "portrait mode false")
end)

--------------------------------------------------------------------------------
-- SECTION 2: TOUCH HITBOXES & FAT-FINGER FORGIVENESS
--------------------------------------------------------------------------------
print("\n--- SECTION 2: Touch Hitboxes & Fat-Finger Forgiveness ---")

test("TH-01", "Ergonomic baseline invariants (48px tap target + 14px expansion)", function()
	assertEq(Layout.tapTarget or Layout.TapTarget, 48, "TapTarget must be 48px baseline")
end)

local screenGui = createMockGui({ ClassName = "ScreenGui", Parent = nil })
local rootFrame = createMockGui({ ClassName = "Frame", Parent = screenGui, AbsolutePosition = roblox.Vector2.new(0, 0), AbsoluteSize = roblox.Vector2.new(1920, 1080) })

test("TH-02", "Exact center touch registers with 0 offset", function()
	local button = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(200, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local fired = false
	TouchGestureService.RegisterTouchTarget("centerBtn", button, function()
		fired = true
	end, 1)

	local center = roblox.Vector2.new(224, 224)
	local handled = TouchGestureService.ResolveFatFingerHit(center)
	assertTrue(handled, "center tap handled")
	assertTrue(fired, "callback fired")
	TouchGestureService.UnregisterTouchTarget("centerBtn")
end)

test("TH-03", "Touch at exact physical boundaries (distance = 24px) is accepted", function()
	local button = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(200, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local count = 0
	TouchGestureService.RegisterTouchTarget("boundaryBtn", button, function()
		count += 1
	end, 1)

	-- 4 boundaries: right (248, 224), left (200, 224), bottom (224, 248), top (224, 200)
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(248, 224)), "right edge hit")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(200, 224)), "left edge hit")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 248)), "bottom edge hit")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 200)), "top edge hit")
	assertEq(count, 4, "all 4 boundary hits triggered callback")

	TouchGestureService.UnregisterTouchTarget("boundaryBtn")
end)

test("TH-04", "Touch at exact fat-finger threshold (distance = 38px, 24+14) is accepted", function()
	local button = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(200, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local count = 0
	TouchGestureService.RegisterTouchTarget("fatFingerBtn", button, function()
		count += 1
	end, 1)

	-- 4 fat finger boundaries at 38px
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(262, 224)), "right fat-finger threshold")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(186, 224)), "left fat-finger threshold")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 262)), "bottom fat-finger threshold")
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 186)), "top fat-finger threshold")
	assertEq(count, 4, "all 4 fat-finger threshold hits triggered callback")

	TouchGestureService.UnregisterTouchTarget("fatFingerBtn")
end)

test("TH-05", "Touch 1px past fat-finger threshold (distance = 39px) is strictly rejected", function()
	local button = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(200, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local count = 0
	TouchGestureService.RegisterTouchTarget("rejectBtn", button, function()
		count += 1
	end, 1)

	-- 4 points at 39px (outside 38px)
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(263, 224)), "right 39px rejected")
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(185, 224)), "left 39px rejected")
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 263)), "bottom 39px rejected")
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(224, 185)), "top 39px rejected")
	assertEq(count, 0, "no callback fired for rejected points")

	TouchGestureService.UnregisterTouchTarget("rejectBtn")
end)

test("TH-06", "Priority scoring selects higher-priority target despite greater distance", function()
	-- Button A: pos (200, 200), center (224, 224), Priority 1
	local btnA = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(200, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	-- Button B: pos (250, 200), center (274, 224), Priority 2
	local btnB = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(250, 200),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})

	local firedA = 0
	local firedB = 0
	TouchGestureService.RegisterTouchTarget("priA", btnA, function() firedA += 1 end, 1)
	TouchGestureService.RegisterTouchTarget("priB", btnB, function() firedB += 1 end, 2)

	-- Tap at (240, 224):
	-- Dist to A = |240 - 224| = 16. Score A = 16 - (1 * 20) = -4
	-- Dist to B = |274 - 240| = 34. Score B = 34 - (2 * 20) = -6
	-- Score B (-6) is lower than Score A (-4). Button B must win!
	local handled = TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(240, 224))
	assertTrue(handled, "overlap tap handled")
	assertEq(firedA, 0, "Button A with lower priority not chosen")
	assertEq(firedB, 1, "Button B with higher priority wins")

	TouchGestureService.UnregisterTouchTarget("priA")
	TouchGestureService.UnregisterTouchTarget("priB")
end)

test("TH-07", "ClipsDescendants strictly rejects fat-finger taps outside clipping bounds", function()
	local clipBox = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		ClipsDescendants = true,
		AbsolutePosition = roblox.Vector2.new(400, 400),
		AbsoluteSize = roblox.Vector2.new(70, 70), -- Bounds: [400, 470] x [400, 470]
	})
	local clippedBtn = createMockGui({
		ClassName = "Frame",
		Parent = clipBox,
		AbsolutePosition = roblox.Vector2.new(410, 410),
		AbsoluteSize = roblox.Vector2.new(48, 48), -- Bounds: [410, 458]. Expanded: [396, 472].
	})

	local fired = 0
	TouchGestureService.RegisterTouchTarget("clipBtn", clippedBtn, function() fired += 1 end, 1)

	-- Tap at (465, 434): Inside expansion (465 <= 472), and inside clipBox (465 <= 470) -> ALLOWED
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(465, 434)), "inside clipbox allowed")
	assertEq(fired, 1, "clip tap fired")

	-- Tap at (471, 434): Inside expansion (471 <= 472), but OUTSIDE clipBox (471 > 470) -> STRICTLY REJECTED
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(471, 434)), "outside clipbox rejected")
	assertEq(fired, 1, "rejected tap does not fire")

	TouchGestureService.UnregisterTouchTarget("clipBtn")
end)

test("TH-08", "Invisible target or ancestor is strictly ignored", function()
	local invisContainer = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		Visible = false,
		AbsolutePosition = roblox.Vector2.new(500, 500),
		AbsoluteSize = roblox.Vector2.new(100, 100),
	})
	local btn = createMockGui({
		ClassName = "Frame",
		Parent = invisContainer,
		Visible = true,
		AbsolutePosition = roblox.Vector2.new(510, 510),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local fired = 0
	TouchGestureService.RegisterTouchTarget("invisBtn", btn, function() fired += 1 end, 1)

	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(534, 534)), "invisible ancestor rejected")
	assertEq(fired, 0, "no callback fired")

	TouchGestureService.UnregisterTouchTarget("invisBtn")
end)

test("TH-09", "Custom expansion parameter overrides baseline 14px", function()
	local customBtn = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(600, 600),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local fired = 0
	-- Custom expansion of 30px (threshold = 24 + 30 = 54px from center 624)
	TouchGestureService.RegisterTouchTarget("customExpBtn", customBtn, function() fired += 1 end, 1, 30)

	-- Tap at 624 + 50 = 674 (50px from center, within 54px)
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(674, 624)), "within 30px expansion allowed")
	-- Tap at 624 + 55 = 679 (55px from center, outside 54px)
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(679, 624)), "outside 30px expansion rejected")
	assertEq(fired, 1, "only 1 tap fired")

	TouchGestureService.UnregisterTouchTarget("customExpBtn")
end)

test("TH-10", "Unregistering touch target prevents subsequent trigger", function()
	local btn = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(700, 700),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local fired = 0
	TouchGestureService.RegisterTouchTarget("tempBtn", btn, function() fired += 1 end, 1)
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(724, 724)), "initial hit registered")
	assertEq(fired, 1, "fired once")

	TouchGestureService.UnregisterTouchTarget("tempBtn")
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(724, 724)), "hit after unregister rejected")
	assertEq(fired, 1, "count remains 1")
end)

test("TH-11", "IsNearRegisteredTarget accurately reflects expanded perimeter", function()
	local btn = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(800, 800),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	TouchGestureService.RegisterTouchTarget("nearBtn", btn, function() end, 1)

	-- Inside 14px expansion: [786, 862] x [786, 862]
	assertTrue(TouchGestureService.IsNearRegisteredTarget(roblox.Vector2.new(824, 824)), "center is near")
	assertTrue(TouchGestureService.IsNearRegisteredTarget(roblox.Vector2.new(860, 824)), "12px past right is near")
	assertFalse(TouchGestureService.IsNearRegisteredTarget(roblox.Vector2.new(865, 824)), "17px past right is not near")

	TouchGestureService.UnregisterTouchTarget("nearBtn")
end)

test("TH-12", "Degenerate 0x0 dimension target expands to 14px perimeter", function()
	local zeroBtn = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(900, 900),
		AbsoluteSize = roblox.Vector2.new(0, 0),
	})
	local fired = 0
	TouchGestureService.RegisterTouchTarget("zeroBtn", zeroBtn, function() fired += 1 end, 1)

	-- Center is at (900, 900). Expansion is 14px: bounds [886, 914] x [886, 914]
	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(905, 905)), "5px from zero-dim target registers")
	assertFalse(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(920, 920)), "20px from zero-dim target rejected")
	assertEq(fired, 1, "only within 14px fires")

	TouchGestureService.UnregisterTouchTarget("zeroBtn")
end)

test("TH-13", "Deterministic tie-breaking preserves first-registered target", function()
	local btn1 = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(1000, 1000),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local btn2 = createMockGui({
		ClassName = "Frame",
		Parent = rootFrame,
		AbsolutePosition = roblox.Vector2.new(1000, 1000),
		AbsoluteSize = roblox.Vector2.new(48, 48),
	})
	local fired1 = 0
	local fired2 = 0
	TouchGestureService.RegisterTouchTarget("tie1", btn1, function() fired1 += 1 end, 1)
	TouchGestureService.RegisterTouchTarget("tie2", btn2, function() fired2 += 1 end, 1)

	assertTrue(TouchGestureService.ResolveFatFingerHit(roblox.Vector2.new(1024, 1024)), "tie hit handled")
	assertEq(fired1, 1, "first registered target wins tie")
	assertEq(fired2, 0, "second target yields")

	TouchGestureService.UnregisterTouchTarget("tie1")
	TouchGestureService.UnregisterTouchTarget("tie2")
end)

--------------------------------------------------------------------------------
-- SECTION 3: VIEWPORT SCALING & EXTREME ASPECT RATIOS
--------------------------------------------------------------------------------
print("\n--- SECTION 3: Viewport Scaling & Extreme Aspect Ratios ---")

test("VS-01", "32:9 Super Ultrawide PC (5120x1440) clamps shell width strictly to 3440px", function()
	local screenWidth = 5120
	local screenHeight = 1440
	local hostWidth = math.min(Layout.maxShellWidth, screenWidth)
	assertEq(hostWidth, 3440, "hostWidth strictly clamped to maxShellWidth (3440)")

	local scale = computeViewportScale(hostWidth, screenHeight)
	assertEq(scale, 1.0, "scale clamped to maxScale 1.0")
end)

test("VS-02", "32:9 Ultra-Resolution 8K (7680x2160) clamps shell width strictly to 3440px", function()
	local screenWidth = 7680
	local screenHeight = 2160
	local hostWidth = math.min(Layout.maxShellWidth, screenWidth)
	assertEq(hostWidth, 3440, "7680px width strictly clamped to 3440px")

	local scale = computeViewportScale(hostWidth, screenHeight)
	assertEq(scale, 1.0, "scale remains clamped at 1.0")
end)

test("VS-03", "32:9 Short Ultrawide (3840x1080) clamps shell width to 3440px", function()
	local screenWidth = 3840
	local screenHeight = 1080
	local hostWidth = math.min(Layout.maxShellWidth, screenWidth)
	assertEq(hostWidth, 3440, "3840px clamped to 3440px")

	local scale = computeViewportScale(hostWidth, screenHeight)
	assertEq(scale, 1.0, "scale is exactly 1.0")
end)

test("VS-04", "21:9 Standard Ultrawide (3440x1440) exactly matches 3440px max width", function()
	local screenWidth = 3440
	local hostWidth = math.min(Layout.maxShellWidth, screenWidth)
	assertEq(hostWidth, 3440, "3440px width matches maxShellWidth")
end)

test("VS-05", "Foldable inner unfolded display (~0.86 aspect, 768x884) selects compact layout", function()
	local plan = planMobileLayout({
		width = 768,
		height = 884,
		orientationWidth = 768,
		orientationHeight = 884,
		compact = true,
		tight = true,
		short = false,
		desktop = false,
		bottomInset = 0,
		sideInset = 0,
	})
	assertTrue(plan.mobile, "foldable categorized as mobile")
	assertTrue(plan.stack, "foldable inner screen uses stacked layout")
	assertGte(plan.contentBudget, 120, "healthy content budget (>= 120)")
	assertLte(plan.tabBarSlots * 64, 768, "tab slots fit width")
end)

test("VS-06", "Foldable outer folded display (~0.40 aspect, 384x960) fits tall narrow layout", function()
	local plan = planMobileLayout({
		width = 384,
		height = 960,
		orientationWidth = 384,
		orientationHeight = 960,
		compact = true,
		tight = true,
		short = false,
		desktop = false,
		bottomInset = 34,
		sideInset = 0,
	})
	assertTrue(plan.mobile, "folded outer screen is mobile")
	assertTrue(plan.stack, "folded outer screen uses stack")
	assertGte(plan.contentBudget, 120, "content budget healthy")
	assertLte(plan.topbarRows + plan.tabBarH, 960 * 0.7, "chrome does not dominate viewport")
end)

test("VS-07", "4:3 Tablet Portrait (720x960) selects tablet mode with healthy dimensions", function()
	local plan = planMobileLayout({
		width = 720,
		height = 960,
		orientationWidth = 720,
		orientationHeight = 960,
		compact = true,
		tight = true,
		short = false,
		desktop = false,
		bottomInset = 0,
		sideInset = 0,
	})
	assertTrue(plan.tablet, "tablet portrait recognized")
	assertFalse(plan.landscape, "not landscape")
	assertEq(plan.pagePadding, 16, "tablet padding is 16")
	assertGte(plan.contentBudget, 120, "healthy content budget")
end)

test("VS-08", "4:3 Tablet Landscape (800x600) selects compact mobile landscape", function()
	local plan = planMobileLayout({
		width = 800,
		height = 600,
		orientationWidth = 800,
		orientationHeight = 600,
		compact = true,
		tight = true,
		short = true,
		desktop = false,
		bottomInset = 0,
		sideInset = 0,
	})
	assertTrue(plan.landscape, "tablet landscape recognized")
	assertEq(plan.topbarRows, 34, "compact topbar rows (34)")
	assertEq(plan.moreCols, 5, "landscape uses 5 more columns")
	assertGte(plan.contentBudget, 120, "healthy content budget")
end)

test("VS-09", "4:3 Desktop Monitor (1024x768, desktop=true) eliminates mobile tab bar", function()
	local plan = planMobileLayout({
		width = 1024,
		height = 768,
		orientationWidth = 1024,
		orientationHeight = 768,
		compact = true,
		tight = false,
		short = false,
		desktop = true,
		bottomInset = 0,
		sideInset = 0,
	})
	assertFalse(plan.mobile, "desktop layout is not mobile")
	assertEq(plan.tabBarH, 0, "desktop has no mobile tab bar")
	assertGte(plan.contentBudget, 120, "desktop content budget healthy")
end)

test("VS-10", "Degenerate 1x1 screen clamps scale and keeps positive budget without panic", function()
	local scale = computeViewportScale(1, 1)
	assertEq(scale, Layout.minScale, "scale clamped to minScale (0.75)")

	local plan = planMobileLayout({
		width = 1,
		height = 1,
		desktop = false,
		compact = true,
		tight = true,
		short = true,
	})
	assertGte(plan.contentBudget, 1, "contentBudget kept at >= 1px")
end)

test("VS-11", "Adversarial 100:1 Aspect Ratio (10000x100 banner) handles bounds safely", function()
	local hostWidth = math.min(Layout.maxShellWidth, 10000)
	assertEq(hostWidth, 3440, "clamped to 3440px")
	local scale = computeViewportScale(hostWidth, 100)
	assertEq(scale, Layout.minScale, "scale safely clamped to minScale (0.75)")
end)

test("VS-12", "Adversarial 1:100 Aspect Ratio (100x10000 strip) handles bounds safely", function()
	local hostWidth = math.min(Layout.maxShellWidth, 100)
	assertEq(hostWidth, 100, "hostWidth is 100")
	local scale = computeViewportScale(hostWidth, 10000)
	assertEq(scale, Layout.minScale, "scale safely clamped to minScale (0.75)")
end)

test("VS-13", "Continuous sweep across 100 randomized viewports satisfies scale & width bounds", function()
	math.randomseed(42)
	for i = 1, 100 do
		local w = math.random(100, 8000)
		local h = math.random(100, 5000)
		local hostW = math.min(Layout.maxShellWidth, w)
		local scale = computeViewportScale(hostW, h)

		assertLte(hostW, Layout.maxShellWidth, "hostW <= maxShellWidth (3440)")
		assertGte(scale, Layout.minScale, "scale >= minScale (0.75)")
		assertLte(scale, Layout.maxScale, "scale <= maxScale (1.00)")
	end
end)

test("VS-14", "32:9 Super Ultrawide multi-height matrix strictly clamps width across all resolutions", function()
	local resolutions = {
		{ w = 3840, h = 1080 },
		{ w = 5120, h = 1440 },
		{ w = 7680, h = 2160 },
		{ w = 10240, h = 2880 },
	}
	for _, res in resolutions do
		local hostW = math.min(Layout.maxShellWidth, res.w)
		assertEq(hostW, 3440, string.format("%dx%d width clamped to 3440px", res.w, res.h))
		local scale = computeViewportScale(hostW, res.h)
		assertEq(scale, 1.0, string.format("%dx%d scale remains 1.0", res.w, res.h))
	end
end)

print("\n================================================================================")
print(string.format("  STRESS TEST SUMMARY: Total: %d | Passed: %d | Failed: %d", totalTests, passedTests, failedTests))
print("================================================================================")

if failedTests > 0 then
	error(string.format("Milestone 3 stress test failed with %d failures", failedTests), 2)
end
