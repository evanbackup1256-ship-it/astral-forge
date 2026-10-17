--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("MotionKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("MotionKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["motionTokens"] = function()

local Tokens = {}

type Feel = { frequency: number, dampingRatio: number }

Tokens.FREQUENCY_MIN = 1.35
Tokens.FREQUENCY_MAX = 8.5
Tokens.DAMPING_MIN = 0.76
Tokens.DAMPING_MAX = 1.0

function Tokens.responseScale(intensity: number): number
	return 0.9 + math.clamp(intensity, 0, 1) * 0.2
end

function Tokens.feel(stiffness: number, damping: number): Feel
	local frequency = math.clamp(stiffness / 130, Tokens.FREQUENCY_MIN, Tokens.FREQUENCY_MAX)
	local raw = damping / 52
	local ratio = math.clamp(0.76 + (raw - 0.6) * 0.6, Tokens.DAMPING_MIN, Tokens.DAMPING_MAX)
	return { frequency = frequency, dampingRatio = ratio }
end

Tokens.SPRING = table.freeze({
	snap = table.freeze({ stiffness = 1000, damping = 44 }),
	smooth = table.freeze({ stiffness = 620, damping = 48 }),
	gentle = table.freeze({ stiffness = 420, damping = 52 }),
	settle = table.freeze({ stiffness = 360, damping = 52 }),
	bouncy = table.freeze({ stiffness = 560, damping = 22 }),
})

function Tokens.bouncyFeel(): Feel
	return { frequency = Tokens.SPRING.bouncy.stiffness / 130, dampingRatio = 0.58 }
end

function Tokens.settleSeconds(feel: Feel): number
	local omega = feel.frequency * math.pi * 2
	return 4 / (math.max(0.1, feel.dampingRatio) * omega)
end

function Tokens.overshoot(feel: Feel): number
	local z = feel.dampingRatio
	if z >= 1 then
		return 0
	end
	return math.exp(-z * math.pi / math.sqrt(1 - z * z))
end

function Tokens.step(x: number, v: number, goal: number, feel: Feel, dt: number): (number, number)
	local z = feel.dampingRatio
	local w = feel.frequency * math.pi * 2
	local offset = x - goal
	local decay = math.exp(-z * w * dt)
	if z >= 1 then
		local nx = (offset * (1 + w * dt) + v * dt) * decay + goal
		local nv = (v * (1 - w * dt) - offset * (w * w * dt)) * decay
		return nx, nv
	end
	local c = math.sqrt(1 - z * z)
	local i = math.cos(w * c * dt)
	local j = math.sin(w * c * dt)
	local nx = (offset * (i + z * j / c) + v * j / (w * c)) * decay + goal
	local nv = (v * (i - z * j / c) - offset * (j / c * w)) * decay
	return nx, nv
end

function Tokens.bezier(x1: number, y1: number, x2: number, y2: number): (number) -> number
	local function sample(a1: number, a2: number, t: number): number
		local u = 1 - t
		return 3 * u * u * t * a1 + 3 * u * t * t * a2 + t * t * t
	end
	local function slope(a1: number, a2: number, t: number): number
		local u = 1 - t
		return 3 * u * u * a1 + 6 * u * t * (a2 - a1) + 3 * t * t * (1 - a2)
	end
	return function(x: number): number
		if x <= 0 then
			return 0
		end
		if x >= 1 then
			return 1
		end
		local t = x
		for _ = 1, 8 do
			local err = sample(x1, x2, t) - x
			if math.abs(err) < 1e-5 then
				return sample(y1, y2, t)
			end
			local d = slope(x1, x2, t)
			if math.abs(d) < 1e-6 then
				break
			end
			t -= err / d
		end
		local lo, hi = 0, 1
		t = x
		for _ = 1, 24 do
			local value = sample(x1, x2, t)
			if math.abs(value - x) < 1e-5 then
				break
			end
			if value < x then
				lo = t
			else
				hi = t
			end
			t = (lo + hi) / 2
		end
		return sample(y1, y2, t)
	end
end

Tokens.EASE = table.freeze({
	standard = Tokens.bezier(0.2, 0, 0, 1),
	decelerate = Tokens.bezier(0.05, 0.7, 0.1, 1),
	accelerate = Tokens.bezier(0.3, 0, 0.8, 0.15),
	emphasized = Tokens.bezier(0.2, 0, 0, 1),
	smoothInOut = Tokens.bezier(0.45, 0, 0.55, 1),
	linear = function(x: number): number
		return math.clamp(x, 0, 1)
	end,
})

Tokens.DURATION = table.freeze({
	instant = 0.08,
	quick = 0.14,
	standard = 0.22,
	emphasized = 0.34,
	slow = 0.5,
	ceremony = 0.9,
})

function Tokens.exitSeconds(entrance: number): number
	return math.clamp(entrance * 0.65, 0.1, 0.22)
end

function Tokens.entranceSpring(duration: number, soft: boolean?): (number, number)
	local span = if type(duration) == "number" and duration == duration then math.clamp(duration, 0.08, 0.5) else 0.22
	local frequency = math.clamp(4 / (2 * math.pi * span), Tokens.FREQUENCY_MIN, Tokens.FREQUENCY_MAX)
	return frequency * 130 * (if soft then 0.82 else 1), 52
end

Tokens.STAGGER_STEP = 0.028
Tokens.STAGGER_CAP = 0.16
function Tokens.stagger(index: number, step: number?): number
	local s = step or Tokens.STAGGER_STEP
	local i = math.max(0, index)
	return math.min(Tokens.STAGGER_CAP, s * (i ^ 1.12))
end

Tokens.RISE = table.freeze({ small = 6, standard = 10, large = 16 })

local Fx = {}

function Fx.ballistic(t: number, angle: number, speed: number, g: number, k: number): (number, number)
	local vx0, vy0 = math.cos(angle) * speed, math.sin(angle) * speed
	if k < 1e-4 then
		return vx0 * t, vy0 * t + 0.5 * g * t * t
	end
	local decay = 1 - math.exp(-k * t)
	local x = vx0 / k * decay
	local terminal = g / k
	local y = terminal * t + (vy0 - terminal) / k * decay
	return x, y
end

function Fx.velocity(t: number, angle: number, speed: number, g: number, k: number): (number, number)
	local vx0, vy0 = math.cos(angle) * speed, math.sin(angle) * speed
	if k < 1e-4 then
		return vx0, vy0 + g * t
	end
	local e = math.exp(-k * t)
	local terminal = g / k
	return vx0 * e, terminal + (vy0 - terminal) * e
end

function Fx.stretch(speed: number): number
	return 1 + math.clamp(speed / 260, 0, 2.2)
end

function Fx.fade(t: number, life: number, hold: number?): number
	local start = life * (hold or 0.35)
	if t <= start then
		return 0
	end
	return Tokens.EASE.accelerate(math.clamp((t - start) / math.max(1e-3, life - start), 0, 1))
end

function Fx.heat(t: number, cool: number): number
	return 1 - Tokens.EASE.decelerate(math.clamp(t / math.max(1e-3, cool), 0, 1))
end

function Fx.ring(t: number, life: number): (number, number, number)
	local x = math.clamp(t / math.max(1e-3, life), 0, 1)
	local grow = Tokens.EASE.decelerate(x)
	local thickness = 1 - x
	local transparency = Tokens.EASE.accelerate(math.clamp((x - 0.15) / 0.85, 0, 1))
	return grow, thickness, transparency
end

function Fx.popScale(t: number, rise: number, amount: number): number
	local x = math.clamp(t / math.max(1e-3, rise), 0, 1)
	local c1 = 1.4
	local c3 = c1 + 1
	local back = 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	return 1 - amount + amount * back
end

function Fx.hash(id: number, salt: number?): number
	local v = math.sin((id + (salt or 0) * 101.37) * 12.9898) * 43758.5453
	return v - math.floor(v)
end

Tokens.fx = Fx

return Tokens
end

__defs["vfxMath"] = function()
return __load("motionTokens").fx
end

local function readSafeInsets(): { top: number, bottom: number, left: number, right: number }
	local top, bottom, left, right = 0, 0, 0, 0
	local vpX, vpY = 1920, 1080
	pcall(function()
		local ws = if typeof(workspace) ~= "nil" then workspace elseif typeof(game) ~= "nil" then game:GetService("Workspace") else nil
		local cam = if ws then ws.CurrentCamera else nil
		if cam and cam.ViewportSize then
			vpX = cam.ViewportSize.X
			vpY = cam.ViewportSize.Y
		end
	end)

	-- 1. Query DeviceSafeInsets (hardware notches, cutouts, dynamic island, home bars)
	pcall(function()
		local GuiService = if typeof(game) ~= "nil" then game:GetService("GuiService") else nil
		if GuiService then
			local safeArea = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
			if safeArea and typeof(safeArea) == "Rect" then
				left = math.max(0, safeArea.Min.X)
				top = math.max(0, safeArea.Min.Y)
				right = math.max(0, vpX - safeArea.Max.X)
				bottom = math.max(0, vpY - safeArea.Max.Y)
			end
		end
	end)

	-- 2. Query GetGuiInset (CoreGui topbar)
	pcall(function()
		local GuiService = if typeof(game) ~= "nil" then game:GetService("GuiService") else nil
		if GuiService then
			local topLeft, bottomRight = GuiService:GetGuiInset()
			if typeof(topLeft) == "Vector2" and typeof(bottomRight) == "Vector2" then
				top = math.max(top, topLeft.Y)
				left = math.max(left, topLeft.X)
				bottom = math.max(bottom, bottomRight.Y)
				right = math.max(right, bottomRight.X)
			end
		end
	end)

	return {
		top = math.round(top),
		bottom = math.round(bottom),
		left = math.round(left),
		right = math.round(right),
	}
end

__defs["autoScale"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local usesDesktopStructure = require(script.Parent.CoreKit)("interaction").usesDesktopStructure
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local _theme = require(script.Parent.CoreKit)("theme")
local Breakpoints = _theme.Breakpoints
local Layout = _theme.Layout
local ViewportScaleContext = React.createContext(nil)
local function computeViewportScale(screenWidth, screenHeight)
	local width = math.max(1, screenWidth)
	local height = math.max(1, screenHeight)
	local raw = math.min(width / Layout.referenceWidth, height / Layout.referenceHeight)
	return math.clamp(raw, Layout.minScale, Layout.maxScale)
end
local function useViewportScale()
	local _result = React.useContext(ViewportScaleContext)
	if _result ~= nil then
		_result = _result.scale
	end
	local _condition = _result
	if _condition == nil then
		_condition = 1
	end
	return _condition
end
-- readSafeInsets is defined at MotionKit module scope
local function keyboardTop(screenHeight, screenOriginY)
	if not UserInputService.TouchEnabled or not UserInputService.OnScreenKeyboardVisible then
		return screenHeight
	end
	local position = UserInputService.OnScreenKeyboardPosition
	local size = UserInputService.OnScreenKeyboardSize
	local fromPosition = if position.Y > screenOriginY then position.Y - screenOriginY else math.huge
	local fromSize = if size.Y > 0 then screenHeight - size.Y else math.huge
	local reportedTop = math.min(fromPosition, fromSize)
	if reportedTop >= screenHeight or reportedTop == math.huge then
		reportedTop = screenHeight * 0.55
	end
	return math.clamp(reportedTop, screenHeight * 0.34, screenHeight)
end
local function revealFocusedControl(keyboardTopY)
	local focused = UserInputService:GetFocusedTextBox()
	if focused == nil then
		return nil
	end
	local ancestor = focused.Parent
	while ancestor ~= nil do
		if ancestor:IsA("ScrollingFrame") then
			local scroll = ancestor
			if scroll.ScrollingEnabled and scroll.ScrollingDirection ~= Enum.ScrollingDirection.X then
				local current = scroll.CanvasPosition
				local localTop = focused.AbsolutePosition.Y - scroll.AbsolutePosition.Y + current.Y
				local localBottom = localTop + focused.AbsoluteSize.Y
				local rawWindow = math.max(1, scroll.AbsoluteWindowSize.Y)
				local occluded = if keyboardTopY ~= nil then math.max(0, scroll.AbsolutePosition.Y + rawWindow - keyboardTopY) else 0
				local windowHeight = math.max(64, rawWindow - occluded)
				local padding = 12
				local targetY = current.Y
				if localTop < current.Y + padding then
					targetY = localTop - padding
				elseif localBottom > current.Y + windowHeight - padding then
					targetY = localBottom - windowHeight + padding
				end
				local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - rawWindow)
				scroll.CanvasPosition = Vector2.new(current.X, math.clamp(targetY, 0, maxY))
			end
		end
		ancestor = ancestor.Parent
	end
end
local RESIZE_HZ = 30
local function useCoalescedScreen(initial)
	local screen, setScreenNow = React.useState(initial)
	local state = React.useRef(nil)
	if state.current == nil then
		state.current = { pending = nil, applied = screen, lastAt = 0, job = nil, alive = true }
	end
	React.useEffect(function()
		local current = state.current
		current.alive = true
		return function()
			current.alive = false
			if current.job ~= nil then
				pcall(task.cancel, current.job)
				current.job = nil
			end
		end
	end, {})
	local request = React.useCallback(function(size)
		local current = state.current
		local rounded = Vector2.new(math.round(size.X), math.round(size.Y))
		if rounded.X <= 0 or rounded.Y <= 0 then
			return
		end
		current.pending = rounded
		if current.job ~= nil then
			return
		end
		local wait = math.max(0, 1 / RESIZE_HZ - (os.clock() - current.lastAt))
		current.job = task.delay(wait, function()
			current.job = nil
			if not current.alive or current.pending == nil then
				return
			end
			local nextSize = current.pending
			current.pending = nil
			current.lastAt = os.clock()
			if nextSize ~= current.applied then
				current.applied = nextSize
				setScreenNow(nextSize)
			end
		end)
	end, {})
	return screen, request
end
local function AutoScale(_param)
	local children = _param.children
	local safeHostRef = React.useRef(nil)
	local screen, setScreen = useCoalescedScreen(function()
		local rect = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
		return rect.Max - rect.Min
	end)
	local insets, setInsets = React.useState(function()
		return readSafeInsets()
	end)
	local _, setEnvironmentRevision = React.useState(0)
	React.useEffect(function()
		local host = safeHostRef.current
		if not host then return nil end
		local function sync()
			local size = host.AbsoluteSize
			if size.X > 0 and size.Y > 0 then setScreen(size) end
		end
		sync()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function() connection:Disconnect() end
	end, {})
	React.useEffect(function()
		local sizeConnection
		local alive = true
		local pending = {}
		local resettle = function()
			for _1, item in pending do
				task.cancel(item)
			end
			table.clear(pending)
			for _1, delay in { 0, 0.12, 0.3 } do
				local _arg0 = task.delay(delay, function()
					if not alive then
						return nil
					end
					setInsets(readSafeInsets())
				end)
				table.insert(pending, _arg0)
			end
		end
		local attach = function()
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			if not camera then
				return nil
			end
			local host = safeHostRef.current
			setScreen(if host and host.AbsoluteSize.X > 0 then host.AbsoluteSize else camera.ViewportSize)
			resettle()
			sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				local currentHost = safeHostRef.current
				setScreen(if currentHost and currentHost.AbsoluteSize.X > 0 then currentHost.AbsoluteSize else camera.ViewportSize)
				resettle()
			end)
		end
		attach()
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attach)
		return function()
			alive = false
			for _1, item in pending do
				task.cancel(item)
			end
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			cameraConnection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local sync = function()
			return setInsets(readSafeInsets())
		end
		sync()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local queued = false
		local alive = true
		local sync = function()
			if queued then
				return nil
			end
			queued = true
			task.defer(function()
				if not alive then
					return nil
				end
				queued = false
				setEnvironmentRevision(function(revision)
					return revision + 1
				end)
				setInsets(readSafeInsets())
			end)
		end
		local connections = { UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(sync), UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("GamepadEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardPosition"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(sync) }
		return function()
			alive = false
			local _callback = function(connection)
				return connection:Disconnect()
			end
			for _k, _v in connections do
				_callback(_v, _k - 1, connections)
			end
		end
	end, {})
	local vrWidth = workspace:GetAttribute("AstralForgeVRCanvasWidth")
	local vrHeight = workspace:GetAttribute("AstralForgeVRCanvasHeight")
	local screenWidth = math.max(1, vrWidth or screen.X)
	local screenHeight = math.max(1, vrHeight or screen.Y)
	local safeOriginY = if safeHostRef.current then safeHostRef.current.AbsolutePosition.Y else 0
	local keyboardOpen = UserInputService.TouchEnabled and UserInputService.OnScreenKeyboardVisible
	local usableScreenHeight = keyboardTop(screenHeight, safeOriginY)
	local chromeScale = if vrWidth then 1 else Layout.chromeScale
	local tvSafe = if not vrWidth and GuiService:IsTenFootInterface()
		then GamepadNavigationService.GetTVSafeInsets(Vector2.new(screenWidth, screenHeight))
		else { top = 0, bottom = 0, left = 0, right = 0 }
	local hostWidth = math.round(math.min(Layout.maxShellWidth, math.max(1, screenWidth - tvSafe.left - tvSafe.right)))
	local hostHeight = math.round(math.max(1, usableScreenHeight - tvSafe.top - tvSafe.bottom))
	local layoutWidth = math.max(1, math.floor(hostWidth / chromeScale))
	local layoutHeight = math.max(1, math.floor(hostHeight / chromeScale))
	local desktop = usesDesktopStructure(screenWidth, screenHeight)
	local preferred = UserInputService.PreferredInput
	local preferredPad = preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
	local consoleLike = UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.TouchEnabled
	local tenFoot = desktop and screenWidth >= 1280 and screenHeight >= 720 and (preferredPad or consoleLike or (UserInputService.GamepadEnabled and GuiService.ViewportDisplaySize == Enum.DisplaySize.Large))
	local scale = computeViewportScale(layoutWidth, layoutHeight)
	local scaledInset = if vrWidth then 0 else math.max(0, math.ceil(insets.top / chromeScale))
	local bottomInset = if keyboardOpen or vrWidth then 0 else math.max(0, math.ceil(insets.bottom / chromeScale))
	local sideInset = if vrWidth then 0 else math.max(0, math.ceil(math.max(insets.left, insets.right) / chromeScale))
	local compact = layoutWidth < Breakpoints.compact
	local tight = layoutWidth < Breakpoints.tight
	local short = math.min(layoutHeight, screenHeight) < Breakpoints.short
	local info = React.useMemo(function()
		return {
			scale = scale,
			width = layoutWidth,
			height = layoutHeight,
			topInset = scaledInset,
			bottomInset = bottomInset,
			sideInset = sideInset,
			screenWidth = screenWidth,
			screenHeight = screenHeight,
			keyboardOpen = keyboardOpen,
			desktop = desktop,
			tenFoot = tenFoot,
			compact = compact,
			tight = tight,
			short = short,
		}
	end, { bottomInset, compact, desktop, keyboardOpen, layoutHeight, layoutWidth, scale, scaledInset, screenHeight, screenWidth, short, sideInset, tenFoot, tight })
	React.useEffect(function()
		if not keyboardOpen then
			return nil
		end
		local _exp = { 0.05, 0.16, 0.34 }
		local _newValue = table.create(#_exp)
		local _callback = function(delay)
			return task.delay(delay, function()
			return revealFocusedControl(safeOriginY + usableScreenHeight)
			end)
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		local attempts = _newValue
		return function()
			for _1, attempt in attempts do
				task.cancel(attempt)
			end
		end
	end, { keyboardOpen, layoutHeight, usableScreenHeight })
	return React.createElement("frame", {
		ref = safeHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(layoutWidth, layoutHeight),
		Position = UDim2.new(0.5, 0, 0, tvSafe.top),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = chromeScale,
	}), React.createElement(ViewportScaleContext.Provider, {
		value = info,
	}, children)))
end
return {
	computeViewportScale = computeViewportScale,
	useViewportScale = useViewportScale,
	readSafeInsets = readSafeInsets,
	AutoScale = AutoScale,
	ViewportScaleContext = ViewportScaleContext,
}
end

__defs["readSafeInsets"] = function()
	return readSafeInsets
end

__defs["motion"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local BezierCurve = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].bezierts).BezierCurve
local _flipper = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].flipper)
local Instant = _flipper.Instant
local SingleMotor = _flipper.SingleMotor
local Spring = _flipper.Spring
local useRippleSpring = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-ripple"].src).useSpring
local spr = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].spr.spr)
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ViewportScaleContext = __load("autoScale").ViewportScaleContext
local MotionTokens = __load("motionTokens")
local Breakpoints = require(script.Parent.CoreKit)("theme").Breakpoints
local usesDesktopStructure = require(script.Parent.CoreKit)("interaction").usesDesktopStructure
local MotionIntent = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("MotionIntent"))
local BEZIER_CIRCLE_KAPPA = 0.5522847498
local function cubicPoint(alpha, p0, p1, p2, p3)
	local point = BezierCurve:cubicBezier(math.clamp(alpha, 0, 1), p0, p1, p2, p3)
	return Vector2.new(point.X, point.Y)
end
local easeOutCubic = function(value)
	return MotionTokens.EASE.standard(math.clamp(value, 0, 1))
end
local easeInCubic = function(value)
	return MotionTokens.EASE.accelerate(math.clamp(value, 0, 1))
end
local easeOutQuart = function(value)
	return MotionTokens.EASE.decelerate(math.clamp(value, 0, 1))
end
local easeOutBack = function(value)
	local overshoot = 1.35
	local shifted = math.clamp(value, 0, 1) - 1
	return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted
end
local easeOutExpo = function(value)
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return 1 - math.pow(2, -10 * value)
end
local function useCursorProximity(elementRef, maxRadius)
	if maxRadius == nil then
		maxRadius = 160
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local proximity, setProximity = React.useState(0)
	local lastProximity = React.useRef(0)
	React.useEffect(function()
		if touchOnly then
			if lastProximity.current ~= 0 then
				lastProximity.current = 0
				setProximity(0)
			end
			return nil
		end
		local active = true
		local frame = 0
		local stride = 6
		local conn = RunService.RenderStepped:Connect(function()
			if not active or not elementRef.current then
				return nil
			end
			frame += 1
			if frame % stride ~= 0 then
				return nil
			end
			local el = elementRef.current
			if not el.Visible or el.AbsoluteSize.Magnitude == 0 then
				if lastProximity.current ~= 0 then
					lastProximity.current = 0
					setProximity(0)
				end
				return nil
			end
			local mousePos = UserInputService:GetMouseLocation()
			local center = el.AbsolutePosition + (el.AbsoluteSize * 0.5)
			local dist = (mousePos - center).Magnitude
			local norm = math.clamp(1 - (dist / maxRadius), 0, 1)
			if math.abs(norm - lastProximity.current) > 0.03 then
				lastProximity.current = norm
				setProximity(norm)
			end
		end)
		return function()
			active = false
			conn:Disconnect()
		end
	end, { maxRadius, touchOnly })
	return if touchOnly then 0 else proximity
end
local function bezierOrbit(progress)
	local wrapped = ((progress % 1) + 1) % 1
	local segment = math.floor(wrapped * 4)
	local alpha = wrapped * 4 - segment
	if segment == 0 then
		return cubicPoint(alpha, Vector3.new(1, 0), Vector3.new(1, BEZIER_CIRCLE_KAPPA), Vector3.new(BEZIER_CIRCLE_KAPPA, 1), Vector3.new(0, 1))
	end
	if segment == 1 then
		return cubicPoint(alpha, Vector3.new(0, 1), Vector3.new(-BEZIER_CIRCLE_KAPPA, 1), Vector3.new(-1, BEZIER_CIRCLE_KAPPA), Vector3.new(-1, 0))
	end
	if segment == 2 then
		return cubicPoint(alpha, Vector3.new(-1, 0), Vector3.new(-1, -BEZIER_CIRCLE_KAPPA), Vector3.new(-BEZIER_CIRCLE_KAPPA, -1), Vector3.new(0, -1))
	end
	return cubicPoint(alpha, Vector3.new(0, -1), Vector3.new(BEZIER_CIRCLE_KAPPA, -1), Vector3.new(1, -BEZIER_CIRCLE_KAPPA), Vector3.new(1, 0))
end
local armFlipper, disarmFlipper, stopDriverIfIdle
local function createFlipperMotor(initial, stiffness, damping)
	if stiffness == nil then
		stiffness = 220
	end
	if damping == nil then
		damping = 22
	end
	local raw = SingleMotor.new(initial, false)
	local atRest = true
	raw:onComplete(function()
		atRest = true
	end)
	local feel = MotionTokens.feel(stiffness, damping)
	local frequency = feel.frequency
	local dampingRatio = feel.dampingRatio
	local callbacks = {}
	local destroyed = false
	local finished = false
	local stepping = false
	local destroyQueued = false
	local suppressEmit = false
	local scratch = {}
	local reportedError = false
	local springGoal = Spring.new(initial, {
		frequency = frequency,
		dampingRatio = dampingRatio,
	})
	local instantGoal = Instant.new(initial)
	local finishDestroy
	local function emit(value)
		if finished or suppressEmit then
			return nil
		end
		local pending = if stepping then {} else scratch
		local wasStepping = stepping
		stepping = true
		local size = 0
		for entry in callbacks do
			size += 1
			pending[size] = entry
		end
		for index = 1, size do
			local entry = pending[index]
			pending[index] = nil
			if not entry.done and not destroyed then
				local ok, problem = pcall(entry.callback, value)
				if not ok and not reportedError then
					reportedError = true
					warn(`[motion] listener error: {tostring(problem)}`)
				end
			end
		end
		stepping = wasStepping
		if destroyQueued and not stepping then
			finishDestroy()
		end
	end
	raw:onStep(function(value)
		emit(value)
	end)
	finishDestroy = function()
		if finished then
			return nil
		end
		finished = true
		destroyed = true
		destroyQueued = false
		local pending = {}
		for entry in callbacks do
			table.insert(pending, entry)
		end
		for _, entry in pending do
			entry.disconnect()
		end
		table.clear(callbacks)
		disarmFlipper(raw)
		raw:destroy()
		stopDriverIfIdle()
	end
	return {
		raw = raw,
		configure = function(self, nextStiffness, nextDamping)
			if destroyed then
				return nil
			end
			local nextFeel = MotionTokens.feel(nextStiffness, nextDamping)
			frequency = nextFeel.frequency
			dampingRatio = nextFeel.dampingRatio
			springGoal._frequency = frequency
			springGoal._dampingRatio = dampingRatio
		end,
		setGoal = function(self, goal)
			if destroyed then
				return nil
			end
			if atRest and math.abs(raw:getValue() - goal) < 1e-7 then
				return nil
			end
			atRest = false
			springGoal._targetValue = goal
			springGoal._frequency = frequency
			springGoal._dampingRatio = dampingRatio
			armFlipper(raw)
			raw:setGoal(springGoal)
		end,
		setPosition = function(self, position)
			if destroyed then
				return nil
			end
			instantGoal._targetValue = position
			atRest = true
			suppressEmit = true
			raw:setGoal(instantGoal)
			local complete = raw:step(0)
			suppressEmit = false
			if finished then
				return nil
			end
			if complete then
				disarmFlipper(raw)
			else
				armFlipper(raw)
			end
			emit(position)
		end,
		onChange = function(self, callback)
			if destroyed then
				return function()
					return nil
				end
			end
			local entry = {
				callback = callback,
				done = false,
			}
			function entry.disconnect()
				if entry.done then
					return nil
				end
				entry.done = true
				callbacks[entry] = nil
			end
			callbacks[entry] = true
			return function()
				return entry.disconnect()
			end
		end,
		halt = function(self)
			if destroyed then
				return nil
			end
			raw:stop()
			disarmFlipper(raw)
		end,
		destroy = function(self)
			if finished then
				return nil
			end
			if stepping then
				destroyed = true
				destroyQueued = true
				return nil
			end
			finishDestroy()
		end,
		alive = function(self)
			return not finished
		end,
	}
end
local nativePackageCache = {}
local missingNativePackages = {}
local function loadNativePackage(name)
	local _name = name
	local cached = nativePackageCache[_name]
	if cached ~= nil then
		return cached
	end
	local _name_1 = name
	if missingNativePackages[_name_1] ~= nil then
		return nil
	end
	local _candidate = ReplicatedStorage:FindFirstChild("Packages")
	if _candidate ~= nil then
		_candidate = _candidate:FindFirstChild(name)
	end
	local candidate = _candidate
	if candidate == nil or not candidate:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(function()
		return require(candidate)
	end)
	if not ok then
		local _name_2 = name
		missingNativePackages[_name_2] = true
		warn(`[forge] {name} failed: {tostring(result)}`)
		return nil
	end
	local _name_2 = name
	nativePackageCache[_name_2] = result
	return result
end
local function loadOtter()
	return loadNativePackage("Otter")
end
local function loadCanvasDraw()
	return loadNativePackage("CanvasDraw")
end
local function preloadUiLibs()
	task.defer(function()
		loadOtter()
		loadCanvasDraw()
	end)
end
local DefaultMotionSettings = {
	motionScale = 1,
	soft = false,
	viewportScale = 1,
	textScale = 1,
}
local MotionSettingsContext = React.createContext(DefaultMotionSettings)
local EntranceMotionSuppressedContext = React.createContext(false)
local function useMotionSettings()
	return React.useContext(MotionSettingsContext)
end
local MOTION_SCALE_FLOOR = 0.32
local MOTION_SCALE_CEIL = 1.6
local SOFT_STIFFNESS = 0.82
local SOFT_DAMPING = 56
local SOFT_CLOCK_SPEED = 0.6
local SOFT_PULSE_DEPTH = 0.45
local SOFT_FLASH_PEAK = 0.55
local function softSpring(stiffness, damping, soft)
	if not soft then
		return stiffness, damping
	end
	return stiffness * SOFT_STIFFNESS, math.max(damping, SOFT_DAMPING)
end
local function softRatio(dampingRatio, frequency, soft)
	if not soft then
		return dampingRatio, frequency
	end
	return math.max(dampingRatio, 1), frequency * SOFT_STIFFNESS
end
local TAU = math.pi * 2
local listeners = {}
local continuousListeners = {}
local realtimeClocks = {}
local decorativeClocks = {}
local listenerCount = 0
local continuousListenerCount = 0
local realtimeClockCount = 0
local decorativeClockCount = 0
local driver
local LISTENER_SOFT_CAP = 32
local warnedOverCap = false
local freezeNav = false
local clockBudget = 24
local flipperMotors = {}
local flipperToken = {}
local flipperCount = 0
local pendingArrivals = {}
local pendingArrivalCount = 0
local ensureDriver
local LAG_START_SECONDS = 1 / 48
local LAG_FULL_SECONDS = 1 / 28
local frameEma = 1 / 60
local lagPressure = 0
local flipperScratch = {}
local listenerScratch = {}
local continuousScratch = {}
local function snapshotKeys(set, scratch)
	local size = 0
	for key in set do
		size += 1
		scratch[size] = key
	end
	return size
end
function armFlipper(motor)
	flipperToken[motor] = (flipperToken[motor] or 0) + 1
	if flipperMotors[motor] ~= nil then
		return nil
	end
	flipperMotors[motor] = true
	flipperCount += 1
	ensureDriver()
end
function disarmFlipper(motor, expectedToken)
	if expectedToken ~= nil and flipperToken[motor] ~= expectedToken then
		return nil
	end
	flipperToken[motor] = nil
	if flipperMotors[motor] == nil then
		return nil
	end
	flipperMotors[motor] = nil
	flipperCount -= 1
	if flipperCount < 0 then
		flipperCount = 0
	end
end
local function compactClocks(list)
	local write = 0
	for index = 0, #list - 1 do
		local slot = list[index + 1]
		if slot ~= nil and slot.alive then
			list[write + 1] = slot
			write += 1
		elseif slot ~= nil then
			slot.listed = false
		end
	end
	while #list > write do
		list[#list] = nil
	end
end
local clockTicking = 0
local function tickClocks(list, deltaTime)
	local live = 0
	local dead = 0
	clockTicking += 1
	for index = 1, #list do
		local slot = list[index]
		if slot == nil or not slot.alive then
			dead += 1
			continue
		end
		local advanced = (slot.phase + deltaTime * slot.speed) % slot.period
		slot.phase = advanced
		live += 1
		slot.push(advanced)
	end
	clockTicking -= 1
	if dead >= 6 and clockTicking == 0 then
		compactClocks(list)
	end
	return live
end
local function removeClockSlot(list, slot)
	for index = #list, 1, -1 do
		if list[index] == slot then
			table.remove(list, index)
			return nil
		end
	end
end
local function addClock(slot, realtime)
	if slot.listed and slot.realtime ~= realtime then
		removeClockSlot(if slot.realtime then realtimeClocks else decorativeClocks, slot)
		slot.listed = false
		slot.alive = false
	end
	slot.realtime = realtime
	if slot.listed then
		if not slot.alive then
			slot.alive = true
			if realtime then
				realtimeClockCount += 1
			else
				decorativeClockCount += 1
			end
			ensureDriver()
		end
		return nil
	end
	slot.listed = true
	slot.alive = true
	if realtime then
		local _slot = slot
		table.insert(realtimeClocks, _slot)
		realtimeClockCount += 1
	else
		local _slot = slot
		table.insert(decorativeClocks, _slot)
		decorativeClockCount += 1
	end
	ensureDriver()
end
local function dropClock(slot, realtime)
	if slot == nil or not slot.alive then
		return nil
	end
	slot.alive = false
	if realtime then
		realtimeClockCount = math.max(0, realtimeClockCount - 1)
	else
		decorativeClockCount = math.max(0, decorativeClockCount - 1)
	end
	if clockTicking == 0 then
		removeClockSlot(if realtime then realtimeClocks else decorativeClocks, slot)
		slot.listed = false
		local remaining = if realtime then realtimeClockCount else decorativeClockCount
		if remaining == 0 then
			compactClocks(if realtime then realtimeClocks else decorativeClocks)
		end
	end
	stopDriverIfIdle()
end
local function setContinuousMotionRate(_rate)
end
local function setDecorativeMotionFrozen(_frozen)
end
local function setHitchMotionFrozen(_frozen)
end
local function beginUiTransition(_seconds)
end
local function isUiTransitioning()
	return freezeNav
end
local function setClockBudget(budget)
	local requested = if type(budget) == "number" and budget == budget then budget else 24
	clockBudget = math.clamp(math.floor(requested + 0.5), 20, 48)
end
local function getClockBudget()
	return clockBudget
end
local function decorativeClockSlotsUsed()
	return decorativeClockCount
end
local function scheduleArrival(motor, delaySeconds)
	if motor == nil then
		return nil
	end
	if motor.alive ~= nil and not motor:alive() then
		return nil
	end
	if pendingArrivals[motor] == nil then
		pendingArrivalCount += 1
	end
	pendingArrivals[motor] = os.clock() + math.max(0, delaySeconds)
	ensureDriver()
end
local function cancelArrival(motor)
	if motor == nil or pendingArrivals[motor] == nil then
		return nil
	end
	pendingArrivals[motor] = nil
	pendingArrivalCount -= 1
	if pendingArrivalCount < 0 then
		pendingArrivalCount = 0
	end
end
local function pumpArrivals()
	if pendingArrivalCount <= 0 then
		return nil
	end
	local now = os.clock()
	local due = nil
	for motor, deadline in pendingArrivals do
		if now >= deadline then
			if due == nil then
				due = {}
			end
			table.insert(due, motor)
		end
	end
	if due == nil then
		return nil
	end
	for _, motor in due do
		if pendingArrivals[motor] ~= nil then
			pendingArrivals[motor] = nil
			pendingArrivalCount -= 1
			if motor.alive == nil or motor:alive() then
				motor:setGoal(1)
			end
		end
	end
	if pendingArrivalCount < 0 then
		pendingArrivalCount = 0
	end
end
function ensureDriver()
	if driver ~= nil then
		return nil
	end
	driver = RunService.RenderStepped:Connect(function(deltaTime)
		local clamped = math.clamp(deltaTime, 0, 0.25)
		local sample = math.min(deltaTime, 0.1)
		frameEma += (sample - frameEma) * math.min(1, sample * 2.5)
		local pressureTarget = math.clamp((frameEma - LAG_START_SECONDS) / (LAG_FULL_SECONDS - LAG_START_SECONDS), 0, 1)
		lagPressure += (pressureTarget - lagPressure) * math.min(1, sample * 1.5)
		local ranRealtime = false
		if flipperCount > 0 then
			ranRealtime = true
			local size = snapshotKeys(flipperMotors, flipperScratch)
			for index = 1, size do
				local motor = flipperScratch[index]
				flipperScratch[index] = nil
				if flipperMotors[motor] ~= nil then
					local token = flipperToken[motor]
					local SUBSTEP_MAX_DT = 1 / 60
					local steps = math.clamp(math.ceil(clamped / SUBSTEP_MAX_DT), 1, 3)
					local subDt = clamped / steps
					local completed = false
					for _ = 1, steps do
						if motor:step(subDt) then
							completed = true
							break
						end
					end
					if completed then
						disarmFlipper(motor, token)
					end
				end
			end
		end
		if realtimeClockCount > 0 then
			tickClocks(realtimeClocks, clamped)
		end
		if listenerCount > 0 then
			ranRealtime = true
			local size = snapshotKeys(listeners, listenerScratch)
			for index = 1, size do
				local active = listenerScratch[index]
				listenerScratch[index] = nil
				if listeners[active] ~= nil then
					active(clamped)
				end
			end
		end
		if decorativeClockCount > 0 then
			tickClocks(decorativeClocks, clamped)
		end
		if continuousListenerCount > 0 then
			local size = snapshotKeys(continuousListeners, continuousScratch)
			for index = 1, size do
				local active = continuousScratch[index]
				continuousScratch[index] = nil
				if continuousListeners[active] ~= nil then
					active(clamped)
				end
			end
		end
		pumpArrivals()
		stopDriverIfIdle()
	end)
end
function stopDriverIfIdle()
	if driver ~= nil and flipperCount == 0 and listenerCount == 0 and continuousListenerCount == 0
		and realtimeClockCount == 0 and decorativeClockCount == 0 and pendingArrivalCount == 0 then
		driver:Disconnect()
		driver = nil
	end
end
local function subscribe(listener)
	local held = listeners[listener]
	if held == nil then
		listeners[listener] = 1
		listenerCount += 1
		if listenerCount > LISTENER_SOFT_CAP and not warnedOverCap then
			warnedOverCap = true
			print(`[forge] {listenerCount} frame listeners (cap {LISTENER_SOFT_CAP})`)
		end
	else
		listeners[listener] = held + 1
	end
	ensureDriver()
	local released = false
	return function()
		if released then
			return nil
		end
		released = true
		local remaining = listeners[listener]
		if remaining == nil then
			return nil
		end
		if remaining > 1 then
			listeners[listener] = remaining - 1
			return nil
		end
		listeners[listener] = nil
		listenerCount = math.max(0, listenerCount - 1)
		if listenerCount <= LISTENER_SOFT_CAP then
			warnedOverCap = false
		end
		stopDriverIfIdle()
	end
end
local function subscribeContinuous(listener)
	local held = continuousListeners[listener]
	if held == nil then
		continuousListeners[listener] = 1
		continuousListenerCount += 1
	else
		continuousListeners[listener] = held + 1
	end
	ensureDriver()
	local released = false
	return function()
		if released then
			return nil
		end
		released = true
		local remaining = continuousListeners[listener]
		if remaining == nil then
			return nil
		end
		if remaining > 1 then
			continuousListeners[listener] = remaining - 1
			return nil
		end
		continuousListeners[listener] = nil
		continuousListenerCount = math.max(0, continuousListenerCount - 1)
		stopDriverIfIdle()
	end
end
local function useSpring(goal, reducedMotion, stiffness, damping, initial)
	if stiffness == nil then
		stiffness = 230
	end
	if damping == nil then
		damping = 22
	end
	if initial == nil then
		initial = goal
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	stiffness, damping = softSpring(stiffness, damping, _binding.soft == true)
	local effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale)
	local feel = MotionTokens.feel(effectiveStiffness, damping)
	local binding, ripple = useRippleSpring(initial, {
		start = true,
		frequency = feel.frequency,
		dampingRatio = feel.dampingRatio,
	})
	React.useEffect(function()
		ripple:setGoal(goal, {
			frequency = feel.frequency,
			dampingRatio = feel.dampingRatio,
		})
	end, { damping, effectiveStiffness, goal, motionScale, ripple })
	return binding
end
local function useFlipperSpring(goal, reducedMotion, stiffness, damping, initial)
	if stiffness == nil then
		stiffness = 900
	end
	if damping == nil then
		damping = 36
	end
	if initial == nil then
		initial = goal
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	stiffness, damping = softSpring(stiffness, damping, _binding.soft == true)
	local effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale)
	local binding, setBinding = React.useBinding(initial)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local reducedRef = React.useRef(reducedMotion)
	local goalRef = React.useRef(goal)
	reducedRef.current = reducedMotion
	goalRef.current = goal
	local motor = React.useRef()
	if not motor.current then
		motor.current = createFlipperMotor(initial, effectiveStiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		local disconnect = active:onChange(function(value)
			return setBindingRef.current(value)
		end)
		return function()
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		active:configure(effectiveStiffness, damping)
		active:setGoal(goalRef.current)
	end, { damping, effectiveStiffness, goal, motionScale, setBinding })
	return binding
end
local function useOtterSpring(goal, reducedMotion, initial, dampingRatio, frequency)
	if initial == nil then
		initial = goal
	end
	if dampingRatio == nil then
		dampingRatio = 0.82
	end
	if frequency == nil then
		frequency = 3.8
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	dampingRatio, frequency = softRatio(dampingRatio, frequency, _binding.soft == true)
	local binding, setBinding = React.useBinding(initial)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local current = React.useRef(initial)
	local motorRef = React.useRef()
	local disconnectRef = React.useRef()
	React.useEffect(function()
		return function()
			local disconnect = disconnectRef.current
			if disconnect ~= nil then
				disconnect()
				disconnectRef.current = nil
			end
			local motor = motorRef.current
			if motor ~= nil then
				motor:destroy()
				motorRef.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local otter = loadOtter()
		if otter == nil then
			current.current = goal
			setBinding(goal)
			return nil
		end
		local motor = motorRef.current
		if motor == nil then
			motor = otter.createSingleMotor(current.current)
			motorRef.current = motor
			disconnectRef.current = motor:onStep(function(value)
				current.current = value
				setBindingRef.current(value)
			end)
		end
		motor:setGoal(otter.spring(goal, {
			dampingRatio = math.clamp(dampingRatio, 0.6, 1.25),
			frequency = math.max(0.5, frequency * MotionTokens.responseScale(motionScale)),
			restingVelocityLimit = 0.001,
			restingPositionLimit = 0.001,
		}))
	end, { dampingRatio, frequency, goal, motionScale, setBinding })
	return binding
end
local function useSprScale(goal, reducedMotion, initial, dampingRatio, frequency)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if initial == nil then
		initial = goal
	end
	if dampingRatio == nil then
		dampingRatio = 0.82
	end
	if frequency == nil then
		frequency = 9
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	dampingRatio, frequency = softRatio(dampingRatio, frequency, _binding.soft == true)
	local scaleRef = React.useRef()
	local mounted = React.useRef(false)
	local drivenScale = React.useRef()
	React.useEffect(function()
		return function()
			local scale = drivenScale.current
			drivenScale.current = nil
			if scale ~= nil then
				spr.stop(scale)
			end
		end
	end, {})
	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return nil
		end
		drivenScale.current = scale
		if not mounted.current then
			mounted.current = true
			scale.Scale = initial
		end
		if scale.Parent ~= nil and scaleRef.current == scale then
			spr.target(scale, math.clamp(dampingRatio, 0.6, 1.25), math.max(1, frequency * MotionTokens.responseScale(motionScale)), {
				Scale = goal,
			})
		end
	end, { dampingRatio, frequency, goal, initial, motionScale })
	return scaleRef
end

local function ScaleFromCenter(_param)
	local scale = _param.scale
	local scaleRef = _param.scaleRef
	local zIndex = _param.zIndex
	local children = _param.children
	local _exp = {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}
	local _result
	if scaleRef ~= nil then
		_result = React.createElement("uiscale", {
			ref = scaleRef,
		})
	else
		local _object = {}
		local _left = "Scale"
		local _condition = scale
		if _condition == nil then
			_condition = 1
		end
		_object[_left] = _condition
		_result = React.createElement("uiscale", _object)
	end
	return React.createElement("frame", _exp, _result, children)
end
local function useOptionalFlipperSpring(goal, enabled, reducedMotion, stiffness, damping)
	if stiffness == nil then
		stiffness = 900
	end
	if damping == nil then
		damping = 36
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	stiffness, damping = softSpring(stiffness, damping, _binding.soft == true)
	local effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale)
	local binding, setBinding = React.useBinding(if enabled then goal else 0)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local reducedRef = React.useRef(reducedMotion == true)
	local goalRef = React.useRef(goal)
	local enabledRef = React.useRef(enabled == true)
	reducedRef.current = reducedMotion == true
	goalRef.current = goal
	enabledRef.current = enabled == true
	local motor = React.useRef()
	if motor.current == nil then
		motor.current = createFlipperMotor(if enabled then goal else 0, effectiveStiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		local disconnect = active:onChange(function(value)
			return setBindingRef.current(value)
		end)
		return function()
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		if not enabledRef.current then
			active:halt()
			active:setPosition(0)
			if not enabledRef.current then
				setBinding(0)
				return nil
			end
		end
		active:configure(effectiveStiffness, damping)
		active:setGoal(goalRef.current)
	end, { damping, effectiveStiffness, enabled, goal, motionScale, setBinding })
	return binding
end
local function useBoatTween(goal, duration, reducedMotion, easing, initial)
	if duration == nil then
		duration = 0.22
	end
	if reducedMotion == nil then
		reducedMotion = false
	end
	if easing == nil then
		easing = MotionTokens.EASE.standard
	end
	local start = if initial == nil then goal else initial
	local binding, setBinding = React.useBinding(start)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local current = React.useRef(start)
	local fromRef = React.useRef(start)
	local goalRef = React.useRef(goal)
	local elapsedRef = React.useRef(0)
	local runningRef = React.useRef(false)
	local easingRef = React.useRef(easing)
	local durationRef = React.useRef(duration)
	local reducedRef = React.useRef(reducedMotion)
	local stopRef = React.useRef(nil)
	local tickRef = React.useRef(nil)
	if tickRef.current == nil then
		tickRef.current = function(deltaTime)
			if not runningRef.current then
				local release = stopRef.current
				stopRef.current = nil
				if release ~= nil then
					release()
				end
				return nil
			end
			elapsedRef.current += deltaTime
			local alpha = math.clamp(elapsedRef.current / math.max(0.01, durationRef.current), 0, 1)
			local from = fromRef.current
			local target = goalRef.current
			local value = from + (target - from) * easingRef.current(alpha)
			current.current = value
			setBindingRef.current(value)
			if alpha >= 1 then
				runningRef.current = false
				local release = stopRef.current
				stopRef.current = nil
				if release ~= nil then
					release()
				end
			end
		end
	end
	React.useEffect(function()
		return function()
			runningRef.current = false
			local release = stopRef.current
			stopRef.current = nil
			if release ~= nil then
				release()
			end
		end
	end, {})
	React.useEffect(function()
		easingRef.current = easing
		durationRef.current = duration
		reducedRef.current = reducedMotion
		goalRef.current = goal
		local from = current.current
		if math.abs(from - goal) < 0.001 then
			current.current = goal
			setBinding(goal)
			runningRef.current = false
			return nil
		end
		fromRef.current = from
		elapsedRef.current = 0
		runningRef.current = true
		if stopRef.current == nil then
			stopRef.current = subscribe(tickRef.current)
		end
	end, { duration, easing, goal, reducedMotion, setBinding })
	return binding
end
local ALWAYS_VISIBLE = React.createBinding(1)
local ExitPresenceContext = React.createContext(nil)
local function useExitPresence()
	return React.useContext(ExitPresenceContext) or ALWAYS_VISIBLE
end
local function composePresence(enter, leave)
	return React.joinBindings({ enter, leave }):map(function(values)
		return math.clamp(math.min(values[1], values[2]), 0, 1)
	end)
end
local function useExitTransition(reducedMotion, duration, resetWhenActive)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if duration == nil then
		duration = 0.18
	end
	local exiting, setExiting = React.useState(false)
	local closing = React.useRef(false)
	local finished = React.useRef(false)
	local afterRef = React.useRef()
	local startedAt = React.useRef(0)
	local spanRef = React.useRef(0.18)
	local running = React.useRef(false)
	local pendingAfter = React.useRef(false)
	local amount, setAmount = React.useBinding(1)
	local setAmountRef = React.useRef(setAmount)
	setAmountRef.current = setAmount
	local stopRef = React.useRef(nil)
	local tickRef = React.useRef(nil)
	if tickRef.current == nil then
		local function release()
			local stop = stopRef.current
			stopRef.current = nil
			if stop ~= nil then
				stop()
			end
		end
		tickRef.current = function()
			if pendingAfter.current then
				pendingAfter.current = false
				local callback = afterRef.current
				afterRef.current = nil
				if not running.current then
					release()
				end
				if callback ~= nil then
					callback()
				end
				return nil
			end
			if not running.current then
				release()
				return nil
			end
			local span = spanRef.current
			if span <= 0 then
				span = 0.01
			end
			local alpha = math.clamp((os.clock() - startedAt.current) / span, 0, 1)
			local shown = if alpha >= 1 then 0 else 1 - MotionTokens.EASE.accelerate(alpha)
			setAmountRef.current(shown)
			if alpha < 1 then
				return nil
			end
			running.current = false
			if finished.current then
				release()
				return nil
			end
			finished.current = true
			pendingAfter.current = true
		end
	end
	React.useEffect(function()
		return function()
			running.current = false
			pendingAfter.current = false
			local stop = stopRef.current
			stopRef.current = nil
			if stop ~= nil then
				stop()
			end
		end
	end, {})
	local begin = React.useCallback(function(after)
		closing.current = true
		finished.current = false
		pendingAfter.current = false
		afterRef.current = after
		setExiting(true)
		setAmount(1)
		startedAt.current = os.clock()
		spanRef.current = MotionTokens.exitSeconds(duration)
		running.current = true
		if stopRef.current == nil then
			stopRef.current = subscribe(tickRef.current)
		end
	end, { duration, reducedMotion, setAmount })
	React.useEffect(function()
		if resetWhenActive ~= true then
			return nil
		end
		running.current = false
		pendingAfter.current = false
		closing.current = false
		finished.current = false
		afterRef.current = nil
		setExiting(false)
		setAmount(1)
	end, { resetWhenActive, setAmount })
	return { amount, exiting, begin }
end
local function useTokenEntrance(token, reducedMotion, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if duration == nil then
		duration = 0.16
	end
	local skip = reducedMotion == true
	local binding, setBinding = React.useBinding(0)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local skipRef = React.useRef(skip)
	skipRef.current = skip
	local motor = React.useRef()
	local stiffness, damping = MotionTokens.entranceSpring(duration, useMotionSettings().soft == true or reducedMotion == true)
	if motor.current == nil then
		motor.current = createFlipperMotor(0, stiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		local disconnect = active:onChange(function(value)
			return setBindingRef.current(value)
		end)
		return function()
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		active:halt()
		active:setPosition(0)
		setBinding(0)
		active:configure(stiffness, damping)
		active:setGoal(1)
	end, { damping, duration, setBinding, stiffness, token })
	return binding
end
local function useEntrance(reducedMotion)
	if reducedMotion == nil then
		reducedMotion = false
	end
	local skip = reducedMotion == true
	return useFlipperSpring(1, skip, MotionTokens.SPRING.smooth.stiffness, MotionTokens.SPRING.smooth.damping, 0)
end
local function useStagger(index, reducedMotion, step, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if step == nil then
		step = 0.025
	end
	if duration == nil then
		duration = 0.14
	end
	local skip = reducedMotion == true
	local binding, setBinding = React.useBinding(0)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local skipRef = React.useRef(skip)
	skipRef.current = skip
	local motor = React.useRef()
	local stiffness, damping = MotionTokens.entranceSpring(duration, useMotionSettings().soft == true or reducedMotion == true)
	if motor.current == nil then
		motor.current = createFlipperMotor(0, stiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		local disconnect = active:onChange(function(value)
			return setBindingRef.current(value)
		end)
		return function()
			cancelArrival(active)
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		active:halt()
		active:setPosition(0)
		setBinding(0)
		active:configure(stiffness, damping)
		scheduleArrival(active, MotionTokens.stagger(index, step))
		return function()
			cancelArrival(active)
		end
	end, { damping, duration, index, setBinding, step, stiffness })
	return binding
end
local function useClock(enabled, speed, period, realtime)
	if speed == nil then
		speed = 1
	end
	if period == nil then
		period = TAU
	end
	if realtime == nil then
		realtime = false
	end
	local _binding = useMotionSettings()
	local motionScale = _binding.motionScale
	local scaledSpeed = speed * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL) * (if _binding.soft == true and not realtime then SOFT_CLOCK_SPEED else 1)
	local live = enabled and speed > 0
	local binding, setBinding = React.useBinding(0)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local phase = React.useRef(0)
	local slotRef = React.useRef()
	React.useEffect(function()
		if not live then
			return nil
		end
		local slot = slotRef.current
		if slot == nil then
			slot = {
				speed = scaledSpeed,
				period = period,
				phase = phase.current,
				alive = false,
				listed = false,
				realtime = realtime,
			}
			slotRef.current = slot
		end
		slot.speed = scaledSpeed
		slot.period = period
		slot.phase = phase.current
		slot.push = function(value)
			phase.current = value
			setBindingRef.current(value)
		end
		addClock(slot, realtime)
		return function()
			phase.current = slot.phase
			dropClock(slot, slot.realtime)
		end
	end, { live, period, realtime, setBinding, scaledSpeed })
	return binding
end
local function syncedNow()
	local value = workspace:GetServerTimeNow()
	return if type(value) == "number" and value == value then value else os.time()
end
local sharedWall, setSharedWall = React.createBinding(syncedNow())
local wallUsers = 0
local wallRelease = nil
local function useWallClock(_enabled)
	React.useEffect(function()
		wallUsers += 1
		if wallRelease == nil then
			setSharedWall(syncedNow())
			wallRelease = subscribeContinuous(function()
				setSharedWall(syncedNow())
			end)
		end
		return function()
			wallUsers = math.max(0, wallUsers - 1)
			if wallUsers == 0 and wallRelease ~= nil then
				wallRelease()
				wallRelease = nil
			end
		end
	end, {})
	return sharedWall
end
local function useRotation(enabled, degreesPerSecond)
	return useClock(enabled, degreesPerSecond, 360, true)
end
local function useFlash(trigger, reducedMotion, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if duration == nil then
		duration = 0.22
	end
	local binding, setBinding = React.useBinding(0)
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	local reducedRef = React.useRef(reducedMotion == true)
	reducedRef.current = reducedMotion == true
	local motor = React.useRef()
	local seenTrigger = React.useRef(nil)
	if motor.current == nil then
		motor.current = createFlipperMotor(0, 900, 52)
	end
	React.useEffect(function()
		local active = motor.current
		local disconnect = active:onChange(function(value)
			return setBindingRef.current(value)
		end)
		return function()
			disconnect()
			active:destroy()
			if motor.current == active then
				motor.current = nil
			end
		end
	end, {})
	React.useEffect(function()
		local active = motor.current
		if active == nil then
			return nil
		end
		local triggerChanged = seenTrigger.current ~= trigger
		seenTrigger.current = trigger
		if trigger == 0 then
			active:halt()
			active:setPosition(0)
			setBinding(0)
			return nil
		end
		if not triggerChanged then
			return nil
		end
		local span = if duration >= 0.75 then duration else math.min(duration, 0.22)
		local stiffness = math.clamp(math.floor(180 / math.max(0.08, span)), 320, 1400)
		active:configure(stiffness, 52)
		active:setPosition(1)
		setBinding(1)
		active:setGoal(0)
	end, { duration, setBinding, trigger })
	local peak = if useMotionSettings().soft == true then SOFT_FLASH_PEAK else 1
	return React.useMemo(function()
		if peak >= 1 then
			return binding
		end
		return binding:map(function(value)
			return value * peak
		end)
	end, { binding, peak })
end
local function usePulse(enabled, speed)
	if speed == nil then
		speed = 1.35
	end
	local clock = useClock(enabled, speed, TAU)
	local depth = if useMotionSettings().soft == true then SOFT_PULSE_DEPTH else 1
	return React.useMemo(function()
		return clock:map(function(phase)
			return 0.5 + math.sin(phase) * 0.5 * depth
		end)
	end, { clock, depth })
end
local function useGlowStroke(active, reducedMotion, rest, near, far, speed)
	if near == nil then
		near = 0.2
	end
	if far == nil then
		far = 0.48
	end
	if speed == nil then
		speed = 1.55
	end
	local everActive, setEverActive = React.useState(active)
	React.useEffect(function()
		if active then
			setEverActive(true)
		end
	end, { active })
	local pulse = usePulse(active, speed)
	local blend = useOptionalFlipperSpring(if active then 1 else 0, everActive, reducedMotion, 420, 36)
	return React.useMemo(function()
		return React.joinBindings({ pulse, blend }):map(function(values)
			local swept = near + (1 - values[1]) * (far - near)
			return rest + (swept - rest) * values[2]
		end)
	end, { blend, far, near, pulse, rest })
end
local function useViewport()
	local host = React.useContext(ViewportScaleContext)
	local function safeSize()
		local rect = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
		return rect.Max - rect.Min
	end
	local size, setSize = React.useState(function()
		return safeSize()
	end)
	React.useEffect(function()
		if host ~= nil then
			return nil
		end
		local sizeConnection
		local attach = function()
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			if not camera then
				return nil
			end
			setSize(safeSize())
			sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				return setSize(safeSize())
			end)
		end
		attach()
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attach)
		return function()
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			cameraConnection:Disconnect()
		end
	end, { host })
	React.useEffect(function()
		if host ~= nil then
			return nil
		end
		local sync = function() return setSize(safeSize()) end
		sync()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, { host })
	local keyboardOpen, setKeyboardOpen = React.useState(UserInputService.OnScreenKeyboardVisible)
	React.useEffect(function()
		if host ~= nil then
			return nil
		end
		local connection = UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(function()
			setKeyboardOpen(UserInputService.OnScreenKeyboardVisible)
		end)
		return function()
			connection:Disconnect()
		end
	end, { host })
	return React.useMemo(function()
		if host ~= nil then
			local _object = {
				width = host.width,
				height = host.height,
				screenWidth = host.screenWidth,
				screenHeight = host.screenHeight,
				topInset = host.topInset,
			}
			local _left = "bottomInset"
			local _condition = host.bottomInset
			if _condition == nil then
				_condition = 0
			end
			_object[_left] = _condition
			local _left_1 = "sideInset"
			local _condition_1 = host.sideInset
			if _condition_1 == nil then
				_condition_1 = 0
			end
			_object[_left_1] = _condition_1
			_object.keyboardOpen = host.keyboardOpen
			_object.desktop = host.desktop
			_object.compact = host.compact
			_object.tight = host.tight
			_object.short = host.short
			return _object
		end
		return {
			width = size.X,
			height = size.Y,
			screenWidth = size.X,
			screenHeight = size.Y,
			topInset = 0,
			bottomInset = 0,
			sideInset = 0,
			keyboardOpen = keyboardOpen,
			desktop = usesDesktopStructure(size.X, size.Y),
			compact = size.X < Breakpoints.compact,
			tight = size.X < Breakpoints.tight,
			short = size.Y < Breakpoints.short,
		}
	end, { host, size, keyboardOpen })
end
local function resolveIntent(request)
	return MotionIntent.resolve(request)
end
-- Picks springs/travel/flash/cues from what the element is; callers pass role or name.
local function useIntent(request, antilagInfo)
	local settings = useMotionSettings()
	local reduced = request.reduced
	if reduced == nil then
		reduced = settings ~= nil and (settings.soft == true or (settings.motionScale or 1) <= MOTION_SCALE_FLOOR)
	end
	local info = antilagInfo or {}
	return React.useMemo(function()
		return MotionIntent.resolve({
			role = request.role,
			name = request.name,
			rarity = request.rarity,
			tone = request.tone,
			emphasis = request.emphasis,
			reduced = reduced,
			tier = info.tier,
			particleBudget = info.particleBudget,
			glowScale = info.glowScale,
			allowConfetti = info.allowConfetti,
		})
	end, { request.role, request.name, request.rarity, request.tone, request.emphasis, reduced, info.tier, info.particleBudget, info.glowScale, info.allowConfetti } :: { any })
end
local function useIntentSpring(goal, plan)
	local spring = if goal > 0.5 then plan.enter else plan.exit
	return useFlipperSpring(goal, plan.reduced, spring.stiffness, spring.damping)
end
ensureDriver()
return {
	MotionIntent = MotionIntent,
	resolveIntent = resolveIntent,
	useIntent = useIntent,
	useIntentSpring = useIntentSpring,
	bezierOrbit = bezierOrbit,
	createFlipperMotor = createFlipperMotor,
	loadOtter = loadOtter,
	loadCanvasDraw = loadCanvasDraw,
	preloadUiLibs = preloadUiLibs,
	useMotionSettings = useMotionSettings,
	setContinuousMotionRate = setContinuousMotionRate,
	setDecorativeMotionFrozen = setDecorativeMotionFrozen,
	setHitchMotionFrozen = setHitchMotionFrozen,
	beginUiTransition = beginUiTransition,
	isUiTransitioning = isUiTransitioning,
	setClockBudget = setClockBudget,
	getClockBudget = getClockBudget,
	getLagPressure = function()
		return lagPressure
	end,
	decorativeClockSlotsUsed = decorativeClockSlotsUsed,
	useSpring = useSpring,
	useFlipperSpring = useFlipperSpring,
	useOtterSpring = useOtterSpring,
	useSprScale = useSprScale,
	ScaleFromCenter = ScaleFromCenter,
	useOptionalFlipperSpring = useOptionalFlipperSpring,
	useBoatTween = useBoatTween,
	useExitPresence = useExitPresence,
	composePresence = composePresence,
	useExitTransition = useExitTransition,
	useTokenEntrance = useTokenEntrance,
	useEntrance = useEntrance,
	useStagger = useStagger,
	useClock = useClock,
	useWallClock = useWallClock,
	subscribeContinuous = subscribeContinuous,
	useRotation = useRotation,
	useFlash = useFlash,
	usePulse = usePulse,
	useGlowStroke = useGlowStroke,
	useViewport = useViewport,
	easeOutCubic = easeOutCubic,
	easeInCubic = easeInCubic,
	easeOutQuart = easeOutQuart,
	easeOutBack = easeOutBack,
	easeOutExpo = easeOutExpo,
	useCursorProximity = useCursorProximity,
	DefaultMotionSettings = DefaultMotionSettings,
	MotionSettingsContext = MotionSettingsContext,
	EntranceMotionSuppressedContext = EntranceMotionSuppressedContext,
	ExitPresenceContext = ExitPresenceContext,
}
end

__defs["antilag"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local _log = require(script.Parent.CoreKit)("log")
local ClientLog = _log.ClientLog
local recordPerformanceTelemetry = _log.recordPerformanceTelemetry
local _motion = __load("motion")
local setClockBudget = _motion.setClockBudget
local setContinuousMotionRate = _motion.setContinuousMotionRate
local function constrainedDevice()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return true
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return true
	end
	local preferredOk, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if preferredOk and preferred ~= nil then
		if preferred == Enum.PreferredInput.Touch then
			return true
		end
		if preferred == Enum.PreferredInput.Gamepad then
			return true
		end
	end
	return false
end
local IS_CONSTRAINED = constrainedDevice()
local DEFAULT_TELEMETRY = {
	fps = if IS_CONSTRAINED then 48 else 60,
	lowFps = if IS_CONSTRAINED then 42 else 55,
	frameTimeMs = if IS_CONSTRAINED then 1000 / 48 else 1000 / 60,
	p50FrameTimeMs = if IS_CONSTRAINED then 1000 / 48 else 1000 / 60,
	p95FrameTimeMs = if IS_CONSTRAINED then 1000 / 48 else 1000 / 60,
	p99FrameTimeMs = if IS_CONSTRAINED then 1000 / 48 else 1000 / 60,
	jankRatio = 0,
	hitchScore = 0,
	sampledAt = 0,
}
local telemetryListeners = {}
local pingHistory = {}
local telemetryConnection
local latestTelemetry = DEFAULT_TELEMETRY
local cachedPingItem
local latencyRemote
local latencyAction = "MeasureLatency"
local latencyWorker
local latencyProbeWorkers = {}
local latencyTimeoutWorkers = {}
local latencyGeneration = 0
local lastRoundTripProbeAt = -math.huge
local FRAME_RING = if IS_CONSTRAINED then 48 else 72
local SAMPLE_SECONDS = if IS_CONSTRAINED then 0.48 else 0.32
local frames = table.create(FRAME_RING)
local scratch = table.create(FRAME_RING)
for index = 0, FRAME_RING - 1 do
	frames[index + 1] = 1 / 60
	scratch[index + 1] = 1 / 60
end
local frameWrite = 0
local frameFilled = 0
local liveScene = "normal"
local livePreference = if IS_CONSTRAINED then 0.62 else 0.42
local sceneListeners = {}
local function validPing(value)
	local _value = value
	local _condition = type(_value) == "number"
	if _condition then
		_condition = value == value and value >= 0 and value <= 10000
	end
	return _condition
end
local function parsePingText(value)
	local match = string.match(value, "([%d%.]+)")
	if match == nil then
		return nil
	end
	local parsed = tonumber(match)
	return if validPing(parsed) then parsed else nil
end
local function readStatsPing(item)
	local valueOk, value = pcall(function()
		return item.GetValue()
	end)
	if valueOk and validPing(value) then
		return value
	end
	if item.GetValueString ~= nil then
		local textOk, text = pcall(function()
			return item.GetValueString()
		end)
		if textOk and type(text) == "string" then
			return parsePingText(text)
		end
	end
	return nil
end
local function enginePingMs()
	local _result = cachedPingItem
	if _result ~= nil then
		_result = _result.Parent
	end
	if _result ~= nil then
		local value = readStatsPing(cachedPingItem)
		if value ~= nil then
			return value
		end
		cachedPingItem = nil
	end
	local network = Stats:FindFirstChild("Network")
	local _server = network
	if _server ~= nil then
		_server = _server:FindFirstChild("ServerStatsItem")
	end
	local server = _server
	local _result_1 = server
	if _result_1 ~= nil then
		_result_1 = _result_1:FindFirstChild("Data Ping")
	end
	local _condition = _result_1
	if _condition == nil then
		_condition = Stats:FindFirstChild("Data Ping", true)
	end
	local item = _condition
	if item == nil then
		return nil
	end
	local statsItem = item
	local value = readStatsPing(statsItem)
	if value == nil then
		return nil
	end
	cachedPingItem = statsItem
	return value
end
local function publishPingSample(value, roundTrip)
	if roundTrip == nil then
		roundTrip = false
	end
	if not validPing(value) then
		return nil
	end
	if roundTrip then
		if os.clock() - lastRoundTripProbeAt > 6 then
			table.clear(pingHistory)
		end
		lastRoundTripProbeAt = os.clock()
	elseif os.clock() - lastRoundTripProbeAt <= 6 then
		return nil
	end
	local _value = value
	table.insert(pingHistory, _value)
	while #pingHistory > 7 do
		table.remove(pingHistory, 1)
	end
end
local function stopLatencyWorker()
	latencyGeneration += 1
	if latencyWorker ~= nil then
		task.cancel(latencyWorker)
		latencyWorker = nil
	end
	for worker in latencyProbeWorkers do
		task.cancel(worker)
	end
	for worker in latencyTimeoutWorkers do
		task.cancel(worker)
	end
	table.clear(latencyProbeWorkers)
	table.clear(latencyTimeoutWorkers)
end
local function startLatencyWorker()
	local _condition = latencyWorker ~= nil or latencyRemote == nil
	if not _condition then
		local _size = 0
		for _ in telemetryListeners do
			_size += 1
		end
		_condition = _size == 0
	end
	if _condition then
		return nil
	end
	local generation = latencyGeneration + 1
	latencyGeneration = generation
	latencyWorker = task.spawn(function()
		task.wait(1.25)
		local probeSerial = 0
		local probeInFlight = false
		local outstandingProbes = 0
		while true do
			local _condition_1 = generation == latencyGeneration
			if _condition_1 then
				local _size = 0
				for _ in telemetryListeners do
					_size += 1
				end
				_condition_1 = _size > 0
				if _condition_1 then
					_condition_1 = latencyRemote ~= nil
				end
			end
			if not _condition_1 then
				break
			end
			local statsPing = enginePingMs()
			local needsFallback = statsPing == nil or statsPing <= 0.5
			if not probeInFlight and needsFallback and outstandingProbes < 2 then
				local remote = latencyRemote
				local serial = probeSerial + 1
				probeSerial = serial
				probeInFlight = true
				outstandingProbes += 1
				local startedAt = os.clock()
				local probeWorker
				local timeoutWorker
				probeWorker = task.defer(function()
					local ok, response = pcall(function()
						return remote:InvokeServer(latencyAction)
					end)
					local _probeWorker = probeWorker
					latencyProbeWorkers[_probeWorker] = nil
					local _timeoutWorker = timeoutWorker
					if latencyTimeoutWorkers[_timeoutWorker] ~= nil then
						local _timeoutWorker_1 = timeoutWorker
						latencyTimeoutWorkers[_timeoutWorker_1] = nil
						task.cancel(timeoutWorker)
					end
					if generation ~= latencyGeneration then
						return nil
					end
					outstandingProbes = math.max(0, outstandingProbes - 1)
					if serial ~= probeSerial then
						return nil
					end
					probeInFlight = false
					local elapsedMs = (os.clock() - startedAt) * 1000
					if ok and type(response) == "table" and response.ok == true then
						publishPingSample(elapsedMs, true)
					end
				end)
				local _probeWorker = probeWorker
				latencyProbeWorkers[_probeWorker] = true
				timeoutWorker = task.delay(4, function()
					local _timeoutWorker = timeoutWorker
					latencyTimeoutWorkers[_timeoutWorker] = nil
					if generation ~= latencyGeneration or serial ~= probeSerial or not probeInFlight then
						return nil
					end
					probeSerial += 1
					probeInFlight = false
				end)
				local _timeoutWorker = timeoutWorker
				latencyTimeoutWorkers[_timeoutWorker] = true
			end
			task.wait(if needsFallback then 2.5 else 5)
		end
		if generation == latencyGeneration then
			latencyWorker = nil
		end
	end)
end
local function watchPing(remote, action)
	if action == nil then
		action = "MeasureLatency"
	end
	local stopped = false
	local function disconnect()
		if stopped then
			return nil
		end
		stopped = true
		if latencyRemote ~= remote or latencyAction ~= action then
			return nil
		end
		stopLatencyWorker()
		latencyRemote = nil
		latencyAction = nil
	end
	if latencyRemote ~= remote or latencyAction ~= action then
		stopLatencyWorker()
		latencyRemote = remote
		latencyAction = action
		startLatencyWorker()
	end
	return disconnect
end
local function median(values)
	if #values == 0 then
		return nil
	end
	local _array = {}
	local _length = #_array
	table.move(values, 1, #values, _length + 1, _array)
	table.sort(_array, function(a, b)
		return a < b
	end)
	local sorted = _array
	return sorted[math.floor((#sorted - 1) / 2) + 1]
end
local function medianAbsoluteDeviation(values, center)
	if #values == 0 or center == nil then
		return nil
	end
	local _newValue = table.create(#values)
	local _callback = function(value)
		return math.abs(value - center)
	end
	for _k, _v in values do
		_newValue[_k] = _callback(_v, _k - 1, values)
	end
	local deviations = _newValue
	return median(deviations)
end
local function sortScratch(count)
	do
		local index = 1
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < count) then
				break
			end
			local value = scratch[index + 1]
			local slot = index
			while slot > 0 and scratch[slot] > value do
				scratch[slot + 1] = scratch[slot]
				slot -= 1
			end
			scratch[slot + 1] = value
		end
	end
end
local function percentile(count, p)
	if count <= 0 then
		return 1 / 60
	end
	local index = math.clamp(math.floor((count - 1) * p + 0.5), 0, count - 1)
	return scratch[index + 1]
end
local lastGuardSweepAt = 0
local bootSeedListeners
local function sweepRuntimeGuards()
	local now = os.clock()
	if now - lastGuardSweepAt < 4 then
		return nil
	end
	lastGuardSweepAt = now
	while #pingHistory > 7 do
		table.remove(pingHistory, 1)
	end
	local trimWorkers = function(workers)
		local _size = 0
		for _ in workers do
			_size += 1
		end
		if _size <= 6 then
			return nil
		end
		local index = 0
		for worker in workers do
			if index >= 6 then
				workers[worker] = nil
				pcall(function()
					return task.cancel(worker)
				end)
			end
			index += 1
		end
	end
	trimWorkers(latencyProbeWorkers)
	trimWorkers(latencyTimeoutWorkers)
	if cachedPingItem ~= nil and cachedPingItem.Parent == nil then
		cachedPingItem = nil
	end
	if #bootSeedListeners > 8 then
		while #bootSeedListeners > 4 do
			table.remove(bootSeedListeners, 1)
		end
	end
	if #sceneListeners > 8 then
		while #sceneListeners > 4 do
			table.remove(sceneListeners, 1)
		end
	end
end
local function startTelemetry()
	if telemetryConnection ~= nil then
		return nil
	end
	local elapsed = 0
	local tight = constrainedDevice()
	local sampleSeconds = if tight then 0.48 else SAMPLE_SECONDS
	local jankThreshold = if tight then 1 / 30 else 1 / 36
	local hitchThreshold = if tight then 0.04 else 0.032
	local signal = if tight then RunService.Heartbeat else RunService.RenderStepped
	telemetryConnection = signal:Connect(function(deltaTime)
		local clamped = math.clamp(deltaTime, 0.001, 0.12)
		frames[frameWrite + 1] = clamped
		frameWrite = (frameWrite + 1) % FRAME_RING
		if frameFilled < FRAME_RING then
			frameFilled += 1
		end
		elapsed += clamped
		if elapsed < sampleSeconds then
			return nil
		end
		elapsed = 0
		local count = frameFilled
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < count) then
					break
				end
				local ring = (frameWrite - count + index + FRAME_RING) % FRAME_RING
				scratch[index + 1] = frames[ring + 1]
			end
		end
		sortScratch(count)
		local total = 0
		local jankFrames = 0
		local hitchFrames = 0
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < count) then
					break
				end
				local time = scratch[index + 1]
				total += time
				if time > jankThreshold then
					jankFrames += 1
				end
				if time > hitchThreshold then
					hitchFrames += 1
				end
			end
		end
		local mean = total / math.max(count, 1)
		local rawFps = 1 / math.max(mean, 0.001)
		local p50 = percentile(count, 0.5)
		local p95 = percentile(count, 0.95)
		local p99 = percentile(count, 0.99)
		local livePing = enginePingMs()
		if livePing ~= nil then
			publishPingSample(livePing)
		end
		local stablePing = median(pingHistory)
		latestTelemetry = {
			fps = rawFps,
			lowFps = math.min(rawFps, 1 / math.max(p95, 1 / 240)),
			frameTimeMs = mean * 1000,
			p50FrameTimeMs = p50 * 1000,
			p95FrameTimeMs = p95 * 1000,
			p99FrameTimeMs = p99 * 1000,
			jankRatio = jankFrames / math.max(count, 1),
			hitchScore = hitchFrames / math.max(count, 1),
			pingMs = stablePing,
			pingJitterMs = medianAbsoluteDeviation(pingHistory, stablePing),
			sampledAt = os.clock(),
		}
		recordPerformanceTelemetry(latestTelemetry)
		sweepRuntimeGuards()
		for listener in telemetryListeners do
			listener(latestTelemetry)
		end
	end)
end
local function stopTelemetryIfIdle()
	local _size = 0
	for _ in telemetryListeners do
		_size += 1
	end
	local _condition = _size > 0
	if not _condition then
		_condition = telemetryConnection == nil
	end
	if _condition then
		return nil
	end
	telemetryConnection:Disconnect()
	telemetryConnection = nil
end
local function subscribeTelemetry(listener)
	local _listener = listener
	telemetryListeners[_listener] = true
	listener(latestTelemetry)
	startTelemetry()
	startLatencyWorker()
	return function()
		local _listener_1 = listener
		telemetryListeners[_listener_1] = nil
		stopTelemetryIfIdle()
		local _size = 0
		for _ in telemetryListeners do
			_size += 1
		end
		if _size == 0 then
			stopLatencyWorker()
		end
	end
end
local function usePerformanceTelemetry()
	local sample, setSample = React.useState(latestTelemetry)
	React.useEffect(function()
		return subscribeTelemetry(setSample)
	end, {})
	return sample
end
local function infoFromQuality(quality, fps, pressure, hitchScore)
	local q = math.clamp(quality, 0, 1)
	local tight = IS_CONSTRAINED
	local qEff = if tight then math.min(q, 0.78) else q
	local tier = if qEff < 0.2 then 0 elseif qEff < 0.44 then 1 elseif qEff < 0.7 then 2 else 3
	local fxBudget = math.clamp(0.05 + qEff * (if tight then 0.28 else 0.34) + qEff * qEff * (if tight then 0.12 else 0.18), 0.05, if tight then 0.52 else 0.7)
	local renderRate = math.clamp(math.floor((if tight then 12 else 16) + qEff * (if tight then 28 else 34) + 0.5), if tight then 12 else 16, if tight then 42 else 56)
	return {
		fps = fps,
		tier = tier,
		quality = q,
		pressure = math.clamp(pressure, 0, 1),
		hitchScore = math.clamp(hitchScore, 0, 1),
		frameBudgetMs = 1000 / renderRate,
		fxBudget = fxBudget,
		particleBudget = math.clamp(math.floor(1 + (if tight then 8 else 12) * qEff + 0.5), 1, if tight then 9 else 14),
		titleGlyphLimit = if tight then 12 else 18,
		renderRate = renderRate,
		glowScale = math.clamp(0.08 + qEff * (if tight then 0.52 else 0.72), 0.08, if tight then 0.62 else 0.86),
		allowAmbient = true,
		allowConfetti = qEff >= (if tight then 0.42 else 0.34),
		skipEntrance = false,
		freezeIcons = false,
		maxClocks = math.clamp(math.floor((if tight then 2 else 3) + (if tight then 6 else 8) * qEff + 0.5), if tight then 2 else 3, if tight then 8 else 12),
		maxPops = math.clamp(math.floor(1 + (if tight then 2 else 3) * qEff + 0.5), 1, if tight then 3 else 4),
		maxStars = if qEff < (if tight then 0.5 else 0.42) then 0 else math.clamp(math.floor(qEff * (if tight then 3.5 else 5) + 0.5), 1, if tight then 3 else 5),
		constrained = tight,
	}
end
local function tierCeiling(tier)
	if tier == 0 then
		return 0.18
	end
	if tier == 1 then
		return 0.4
	end
	if tier == 2 then
		return 0.66
	end
	return 1
end
local DEFAULT_INFO = infoFromQuality(if IS_CONSTRAINED then 0.55 else 0.88, if IS_CONSTRAINED then 48 else 60, 0.2, 0)
local AntilagContext = React.createContext(DEFAULT_INFO)
local bootSeededQuality
local bootSeededFps
bootSeedListeners = {}
local function sceneLoad(scene)
	if scene == "cinematic" then
		return 0.38
	end
	if scene == "arcade" then
		return 0.28
	end
	if scene == "heavy" then
		return 0.16
	end
	return 0
end
local function applyMotionRate(info)
	local floor = if IS_CONSTRAINED then 18 else 24
	local boost = if IS_CONSTRAINED then 32 else 40
	local rate = if info.tier >= 2 then math.max(info.renderRate, boost) else math.max(floor, info.renderRate)
	setContinuousMotionRate(rate)
	setClockBudget(info.maxClocks)
end
local function setAntilagScene(scene)
	if liveScene == scene then
		return nil
	end
	liveScene = scene
	for _, listener in sceneListeners do
		listener()
	end
end
local function setAntilagPreference(bias)
	local preferred = math.clamp(bias, 0, 1)
	if math.abs(preferred - livePreference) < 0.01 then
		return nil
	end
	livePreference = preferred
	for _, listener in sceneListeners do
		listener()
	end
end
local function seedAntilagFromBoot(fps)
	local measured = math.clamp(fps, 8, 120)
	bootSeededFps = measured
	local raw = math.clamp((measured - 16) / 44, 0.12, 1)
	local motionFloor = if IS_CONSTRAINED then 0.4 else 0.48
	local seeded = math.max(raw, motionFloor)
	bootSeededQuality = if IS_CONSTRAINED then math.min(seeded, 0.74) else seeded
	for _, listener in bootSeedListeners do
		listener(bootSeededQuality, measured)
	end
	return if bootSeededQuality < 0.2 then 0 elseif bootSeededQuality < 0.44 then 1 elseif bootSeededQuality < 0.7 then 2 else 3
end
local function clampAntilagTier(info, maxTier)
	if info.tier <= maxTier then
		return info
	end
	return infoFromQuality(math.min(info.quality, tierCeiling(maxTier)), info.fps, info.pressure, info.hitchScore)
end
local function scoreWindow(sample)
	local targetFps = if IS_CONSTRAINED then 45 else 58
	local fpsScore = math.clamp(sample.fps / targetFps, 0, 1.15)
	local p95Score = math.clamp(1 - (sample.p95FrameTimeMs - (if IS_CONSTRAINED then 20 else 16)) / 48, 0, 1)
	local p99Score = math.clamp(1 - (sample.p99FrameTimeMs - (if IS_CONSTRAINED then 28 else 20)) / 70, 0, 1)
	local jankScore = 1 - math.clamp(sample.jankRatio * (if IS_CONSTRAINED then 1.4 else 1.7), 0, 1)
	local hitchPenalty = math.clamp(sample.hitchScore * (if IS_CONSTRAINED then 2.4 else 2.1), 0, 1)
	local pingPenalty = if sample.pingMs ~= nil and sample.pingMs > 180 then math.clamp((sample.pingMs - 180) / 500, 0, 0.16) else 0
	local blended = fpsScore * 0.3 + p95Score * 0.28 + p99Score * 0.18 + jankScore * 0.24
	return math.clamp(blended - hitchPenalty * 0.62 - pingPenalty, 0, 1)
end
local latestAntilagInfo
local function AntilagProvider(_param)
	local children = _param.children
	local _condition = bootSeededQuality
	if _condition == nil then
		_condition = (if IS_CONSTRAINED then 0.55 else 0.88)
	end
	local startingQuality = _condition
	local _condition_1 = bootSeededFps
	if _condition_1 == nil then
		_condition_1 = (if IS_CONSTRAINED then 48 else 60)
	end
	local startingFps = _condition_1
	local info, setInfo = React.useState(function()
		return infoFromQuality(startingQuality, startingFps, 0.2, 0)
	end)
	local infoRef = React.useRef(info)
	infoRef.current = info
	latestAntilagInfo = info
	React.useEffect(function()
		local apply = function(quality, fps)
			local seeded = infoFromQuality(quality, fps, 1 - quality, 0)
			infoRef.current = seeded
			setInfo(seeded)
			applyMotionRate(seeded)
		end
		if bootSeededQuality ~= nil then
			local _exp = bootSeededQuality
			local _condition_2 = bootSeededFps
			if _condition_2 == nil then
				_condition_2 = 60
			end
			apply(_exp, _condition_2)
		end
		table.insert(bootSeedListeners, apply)
		return function()
			local index = (table.find(bootSeedListeners, apply) or 0) - 1
			if index >= 0 then
				table.remove(bootSeedListeners, index + 1)
			end
		end
	end, {})
	React.useEffect(function()
		applyMotionRate(info)
		return function()
			return setContinuousMotionRate(60)
		end
	end, { info.renderRate, info.tier })
	React.useEffect(function()
		local quality = startingQuality
		local lastLoggedTier = infoRef.current.tier
		local TIER_DEBOUNCE_SECONDS = 1.5
		local QUALITY_FLOOR = if IS_CONSTRAINED then 0.22 else 0.46
		local SUSTAINED_BAD_SAMPLES = 3
		local MAX_DROP = 0.24
		local badSamples = 0
		local pendingTier = lastLoggedTier
		local pendingTierSince = os.clock()
		local lastRiseAt = 0
		local lastDropAt = 0
		local slope = 0
		local previousScore = quality
		local holdUntil = 0
		local hitchStrikes = 0
		local hitchHoldUntil = 0
		local evaluateStartedAt = os.clock()
		local evaluate = function(sample)
			local raw = scoreWindow(sample)
			slope = slope * 0.55 + (raw - previousScore) * 0.45
			previousScore = raw
			local scene = sceneLoad(liveScene)
			local prefer = livePreference * 0.48
			local touchCeil = if IS_CONSTRAINED then 0.82 else 1
			local target = math.clamp(raw - scene - prefer, 0.08, touchCeil)
			local now = os.clock()
			local warming = now - evaluateStartedAt < 1
			if warming then
				target = math.max(target, quality)
			end
			local collapsed = not warming and (sample.fps < 40 or sample.p95FrameTimeMs >= 32)
			if collapsed then
				badSamples += 1
				hitchStrikes += 1
				hitchHoldUntil = now + 1.8
			else
				badSamples = 0
				hitchStrikes = math.max(0, hitchStrikes - 1)
				if now >= hitchHoldUntil and sample.hitchScore < 0.05 and sample.fps >= 50 then
					hitchHoldUntil = now
				end
			end
			if sample.fps < 50 and not warming then
				target = math.min(target, 0.22 + (sample.fps / 50) * 0.4)
			end
			if warming then
				target = math.max(target, quality)
			end
			local falling = target < quality - 0.02
			local rising = target > quality + 0.05
			if falling and badSamples >= SUSTAINED_BAD_SAMPLES and now - lastDropAt >= 2 then
				quality = math.max(target, quality - MAX_DROP)
				lastDropAt = now
				holdUntil = now + 3
				badSamples = 0
			elseif rising and now >= holdUntil and now - lastDropAt >= 2.2 and now - lastRiseAt >= 1.1 then
				quality += (target - quality) * 0.08
				lastRiseAt = now
			elseif not falling then
				quality += (target - quality) * 0.02
			end
			quality = math.clamp(quality, QUALITY_FLOOR, touchCeil)
			local pressure = math.clamp(1 - raw + scene + prefer, 0, 1)
			local scored = infoFromQuality(quality, sample.fps, pressure, sample.hitchScore)
			local published = infoRef.current
			if scored.tier == published.tier then
				pendingTier = published.tier
				pendingTierSince = now
				applyMotionRate(scored)
				return nil
			end
			if pendingTier ~= scored.tier then
				pendingTier = scored.tier
				pendingTierSince = now
			end
			if now - pendingTierSince < TIER_DEBOUNCE_SECONDS then
				return nil
			end
			applyMotionRate(scored)
			latestAntilagInfo = scored
			infoRef.current = scored
			setInfo(scored)
			if scored.tier ~= lastLoggedTier then
				lastLoggedTier = scored.tier
				ClientLog:debug("perf", `{math.floor(sample.fps)} fps, quality {string.format("%.2f", quality)}`)
			end
		end
		local onScene = function()
			return evaluate(latestTelemetry)
		end
		table.insert(sceneListeners, onScene)
		local stop = subscribeTelemetry(evaluate)
		return function()
			stop()
			local index = (table.find(sceneListeners, onScene) or 0) - 1
			if index >= 0 then
				table.remove(sceneListeners, index + 1)
			end
		end
	end, {})
	return React.createElement(AntilagContext.Provider, {
		value = info,
	}, children)
end
latestAntilagInfo = DEFAULT_INFO
local function currentAntilagInfo()
	return latestAntilagInfo
end
local function useAntilag()
	return React.useContext(AntilagContext)
end
return {
	watchPing = watchPing,
	constrainedDevice = constrainedDevice,
	usePerformanceTelemetry = usePerformanceTelemetry,
	setAntilagScene = setAntilagScene,
	setAntilagPreference = setAntilagPreference,
	seedAntilagFromBoot = seedAntilagFromBoot,
	clampAntilagTier = clampAntilagTier,
	AntilagProvider = AntilagProvider,
	currentAntilagInfo = currentAntilagInfo,
	useAntilag = useAntilag,
	AntilagContext = AntilagContext,
}
end

__defs["dynamicLayout"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useFlipperSpring = __load("motion").useFlipperSpring

local LAYOUT_STIFFNESS = 520
local LAYOUT_DAMPING = 46

local function useDynamicLayoutNumber(goal: number, _reducedMotion: boolean?): React.Binding<number>
	return useFlipperSpring(goal, false, LAYOUT_STIFFNESS, LAYOUT_DAMPING)
end

return {
	LAYOUT_STIFFNESS = LAYOUT_STIFFNESS,
	LAYOUT_DAMPING = LAYOUT_DAMPING,
	useDynamicLayoutNumber = useDynamicLayoutNumber,
}
end

__defs["flexbox"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _interaction = require(script.Parent.CoreKit)("interaction")
local isGamepadDevice = _interaction.isGamepadDevice
local isTouchDevice = _interaction.isTouchDevice
local useViewport = __load("motion").useViewport
local TapTarget = require(script.Parent.CoreKit)("theme").TapTarget
local function flexSurface()
	if isGamepadDevice() then
		return "gamepad"
	end
	if isTouchDevice() then
		return "touch"
	end
	return "desktop"
end
local function useFlexPlatform()
	local surface = flexSurface()
	if surface == "touch" then
		return {
			surface = surface,
			wrap = true,
			gap = 8,
			minWidth = TapTarget,
			minHeight = TapTarget,
			justify = "fill",
		}
	end
	if surface == "gamepad" then
		return {
			surface = surface,
			wrap = false,
			gap = 14,
			minWidth = TapTarget + 16,
			minHeight = TapTarget + 8,
			justify = "space-between",
		}
	end
	return {
		surface = surface,
		wrap = true,
		gap = 12,
		minWidth = 120,
		minHeight = 48,
		justify = "fill",
	}
end
local function justifyEnum(value)
	if value == "fill" then
		return Enum.UIFlexAlignment.Fill
	end
	if value == "space-between" then
		return Enum.UIFlexAlignment.SpaceBetween
	end
	if value == "space-around" then
		return Enum.UIFlexAlignment.SpaceAround
	end
	if value == "space-evenly" then
		return Enum.UIFlexAlignment.SpaceEvenly
	end
	return Enum.UIFlexAlignment.None
end
local function alignEnum(value)
	if value == "start" then
		return Enum.ItemLineAlignment.Start
	end
	if value == "center" then
		return Enum.ItemLineAlignment.Center
	end
	if value == "end" then
		return Enum.ItemLineAlignment.End
	end
	if value == "stretch" then
		return Enum.ItemLineAlignment.Stretch
	end
	return Enum.ItemLineAlignment.Automatic
end
local function modeEnum(value)
	if value == "grow" then
		return Enum.UIFlexMode.Grow
	end
	if value == "shrink" then
		return Enum.UIFlexMode.Shrink
	end
	if value == "fill" then
		return Enum.UIFlexMode.Fill
	end
	if value == "custom" then
		return Enum.UIFlexMode.Custom
	end
	return Enum.UIFlexMode.None
end
local function mainAlign(direction, align)
	if direction == "row" then
		return {
			horizontal = Enum.HorizontalAlignment.Left,
			vertical = if align == "end" then Enum.VerticalAlignment.Bottom elseif align == "start" then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center,
		}
	end
	return {
		horizontal = if align == "end" then Enum.HorizontalAlignment.Right elseif align == "start" then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,
		vertical = Enum.VerticalAlignment.Top,
	}
end
local function Flex(_param)
	local children = _param.children
	local direction = _param.direction
	if direction == nil then
		direction = "row"
	end
	local wrap = _param.wrap
	local justify = _param.justify
	local align = _param.align
	if align == nil then
		align = "center"
	end
	local gap = _param.gap
	local size = _param.size
	if size == nil then
		size = UDim2.fromScale(1, 1)
	end
	local position = _param.position
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local clips = _param.clips
	if clips == nil then
		clips = false
	end
	local exact = _param.exact
	if exact == nil then
		exact = false
	end
	local platform = useFlexPlatform()
	local _condition = wrap
	if _condition == nil then
		_condition = (if exact then false else platform.wrap)
	end
	local wraps = _condition
	local _condition_1 = gap
	if _condition_1 == nil then
		_condition_1 = (if exact then 8 else platform.gap)
	end
	local padding = _condition_1
	local distribution = justify or (if exact then "none" else platform.justify)
	local main = mainAlign(direction, align)
	local axis = if direction == "column" then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	local horizontalFlex = if direction == "row" then justifyEnum(distribution) else Enum.UIFlexAlignment.None
	local verticalFlex = if direction == "column" then justifyEnum(distribution) else Enum.UIFlexAlignment.None
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = clips,
	}, React.createElement("uilistlayout", {
		FillDirection = axis,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
		Wraps = wraps,
		HorizontalFlex = horizontalFlex,
		VerticalFlex = verticalFlex,
		ItemLineAlignment = alignEnum(align),
		HorizontalAlignment = main.horizontal,
		VerticalAlignment = main.vertical,
	}), children)
end
local function FlexItem(_param)
	local children = _param.children
	local mode = _param.mode
	if mode == nil then
		mode = "grow"
	end
	local grow = _param.grow
	local shrink = _param.shrink
	local minWidth = _param.minWidth
	local minHeight = _param.minHeight
	local maxWidth = _param.maxWidth
	local maxHeight = _param.maxHeight
	local size = _param.size
	local automaticSize = _param.automaticSize
	if automaticSize == nil then
		automaticSize = Enum.AutomaticSize.None
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local platform = useFlexPlatform()
	local _condition = minWidth
	if _condition == nil then
		_condition = platform.minWidth
	end
	local floorX = _condition
	local _condition_1 = minHeight
	if _condition_1 == nil then
		_condition_1 = platform.minHeight
	end
	local floorY = _condition_1
	local itemSize = size or (if mode == "fill" or mode == "grow" then UDim2.new(0, floorX, 0, floorY) else UDim2.fromOffset(floorX, floorY))
	local _attributes = {
		FlexMode = modeEnum(mode),
	}
	local _condition_2 = grow
	if _condition_2 == nil then
		_condition_2 = 1
	end
	_attributes.GrowRatio = _condition_2
	local _condition_3 = shrink
	if _condition_3 == nil then
		_condition_3 = 1
	end
	_attributes.ShrinkRatio = _condition_3
	local _exp = React.createElement("uiflexitem", _attributes)
	local _attributes_1 = {
		MinSize = Vector2.new(floorX, floorY),
	}
	local _condition_4 = maxWidth
	if _condition_4 == nil then
		_condition_4 = math.huge
	end
	local _condition_5 = maxHeight
	if _condition_5 == nil then
		_condition_5 = math.huge
	end
	_attributes_1.MaxSize = Vector2.new(_condition_4, _condition_5)
	return React.createElement("frame", {
		Size = itemSize,
		AutomaticSize = automaticSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, _exp, React.createElement("uisizeconstraint", _attributes_1), children)
end
local function packColumns(width, surface)
	if surface == nil then
		surface = flexSurface()
	end
	if surface == "touch" or width < 640 then
		return 2
	end
	if surface == "gamepad" or width < 1100 then
		return 3
	end
	return 4
end
local function isFlexChildList(value)
	local _value = value
	if not (type(_value) == "table") then
		return false
	end
	local record = value
	if record.component ~= nil or record.type ~= nil or record.props ~= nil then
		return false
	end
	local numeric = 0
	local named = 0
	for key in pairs(record) do
		if type(key) == "number" then
			numeric += 1
		else
			named += 1
		end
	end
	return numeric > 0 and named == 0
end
local function flattenFlexChildren(value, into)
	if into == nil then
		into = {}
	end
	if value == nil or value == false or value == true then
		return into
	end
	if isFlexChildList(value) then
		for _, child in value do
			flattenFlexChildren(child, into)
		end
		return into
	end
	local _into = into
	local _value = value
	table.insert(_into, _value)
	return into
end
local function useShopColumns()
	local viewport = useViewport()
	local contentW = math.max(280, viewport.width - (if viewport.width >= 1100 then 320 elseif viewport.width >= 760 then 96 else 36))
	if contentW < 540 then
		return 1
	end
	if contentW < 900 then
		return 2
	end
	return 3
end
local function usePackColumns()
	local viewport = useViewport()
	return packColumns(viewport.width, flexSurface())
end
local PACK_BREAKPOINTS = { {
	minWidth = 0,
	columns = 2,
}, {
	minWidth = 640,
	columns = 3,
}, {
	minWidth = 1100,
	columns = 4,
} }
local function FlexGrid(_param)
	local children = _param.children
	local columns = _param.columns
	local gap = _param.gap
	local _cellMinWidth = _param.cellMinWidth
	local cellMinHeight = _param.cellMinHeight
	if cellMinHeight == nil then
		cellMinHeight = 160
	end
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, 0)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local packed = usePackColumns()
	local _condition = columns
	if _condition == nil then
		_condition = packed
	end
	local cols = math.max(1, _condition)
	local platform = useFlexPlatform()
	local _condition_1 = gap
	if _condition_1 == nil then
		_condition_1 = platform.gap
	end
	local gapPx = _condition_1
	local nodes = flattenFlexChildren(children)
	local _exp = React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / cols, -math.ceil((gapPx * (cols - 1)) / cols), 0, cellMinHeight),
		CellPadding = UDim2.new(0, gapPx, 0, gapPx),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	local _newValue = table.create(#nodes)
	local _callback = function(child, index)
		return React.createElement("frame", {
			key = `pack-{index}`,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ClipsDescendants = false,
		}, child)
	end
	for _k, _v in nodes do
		_newValue[_k] = _callback(_v, _k - 1, nodes)
	end
	return React.createElement("frame", {
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, _exp, _newValue)
end
return {
	flexSurface = flexSurface,
	useFlexPlatform = useFlexPlatform,
	Flex = Flex,
	FlexItem = FlexItem,
	packColumns = packColumns,
	useShopColumns = useShopColumns,
	usePackColumns = usePackColumns,
	FlexGrid = FlexGrid,
	PACK_BREAKPOINTS = PACK_BREAKPOINTS,
}
end

__defs["shimmer"] = function()

local DEFAULT_TRAVEL = 2.4
local TRAIL_LAG = 0.035
local TRAIL_MIN_SCALE = 0.85
local SWEEP_SHARE = 0.6
local SWEEP_EASE = 0.55

local function bell(halfWidth, peak, samples)
	local points = { NumberSequenceKeypoint.new(0, 1) }
	local low = 0.5 - halfWidth
	table.insert(points, NumberSequenceKeypoint.new(low, 1))
	for i = 1, samples - 1 do
		local u = i / samples
		local x = low + u * halfWidth * 2
		local lit = (1 - math.cos(u * math.pi * 2)) * 0.5
		table.insert(points, NumberSequenceKeypoint.new(x, 1 - (1 - peak) * lit))
	end
	table.insert(points, NumberSequenceKeypoint.new(0.5 + halfWidth, 1))
	table.insert(points, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(points)
end

local GLINT = bell(0.17, 0.08, 12)

local TRAIL = bell(0.3, 0.7, 12)

local SWEEP_SPEED = 0.42
local ROTATION = 20

local function clamp01(value)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

local function sweepProgress(phase)
	local t = phase
	if type(t) ~= "number" or t ~= t then
		t = 0
	end
	t = t % 1
	if t < 0 then
		t += 1
	end
	local u = math.min(t / SWEEP_SHARE, 1)
	local smooth = u * u * (3 - 2 * u)
	return u + (smooth - u) * SWEEP_EASE
end

local function offset(phase, travel, lag)
	if travel == nil then
		travel = DEFAULT_TRAVEL
	end
	if type(travel) ~= "number" or travel ~= travel or travel <= 0 then
		travel = DEFAULT_TRAVEL
	end
	local t = phase
	if type(t) ~= "number" or t ~= t then
		t = 0
	end
	if type(lag) == "number" and lag == lag then
		t -= lag
	end
	return Vector2.new(sweepProgress(t) * travel - travel * 0.5, 0)
end

local function sweepSpeed(shimmerScale)
	local scale = clamp01(if type(shimmerScale) == "number" then shimmerScale else 1)
	return SWEEP_SPEED * math.clamp(0.55 + scale * 0.45, 0.55, 1)
end

local function surfaceStrength(hoverAmount, idle, shimmerScale)
	local scale = clamp01(if type(shimmerScale) == "number" then shimmerScale else 1)
	local hoverStrength = clamp01(hoverAmount) * 0.4
	local idleStrength = if idle then 0.12 else 0
	return math.clamp(math.max(hoverStrength, idleStrength) * scale, 0, 0.5)
end

local function surfaceTransparency(hoverAmount, idle, shimmerScale)
	return 1 - surfaceStrength(hoverAmount, idle, shimmerScale)
end

local function shouldShow(hoverAmount, idle, shimmerScale)
	if clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) <= 0.02 then
		return false
	end
	if idle then
		return true
	end
	return clamp01(hoverAmount) > 0.02
end

local function wantTrail(shimmerScale, trailOpt)
	if trailOpt == false then
		return false
	end
	if trailOpt == true then
		return clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) > 0.02
	end
	return clamp01(if type(shimmerScale) == "number" then shimmerScale else 1) >= TRAIL_MIN_SCALE
end

return {
	GLINT = GLINT,
	TRAIL = TRAIL,
	SWEEP_SPEED = SWEEP_SPEED,
	ROTATION = ROTATION,
	DEFAULT_TRAVEL = DEFAULT_TRAVEL,
	TRAIL_LAG = TRAIL_LAG,
	TRAIL_MIN_SCALE = TRAIL_MIN_SCALE,
	SWEEP_SHARE = SWEEP_SHARE,
	SWEEP_EASE = SWEEP_EASE,
	bell = bell,
	sweepProgress = sweepProgress,
	offset = offset,
	sweepSpeed = sweepSpeed,
	surfaceStrength = surfaceStrength,
	surfaceTransparency = surfaceTransparency,
	shouldShow = shouldShow,
	wantTrail = wantTrail,
	clamp01 = clamp01,
}
end

__defs["pageTransition"] = function()

local SLIDE_DESKTOP = 24
local SLIDE_PHONE = 36
local SOFT_SCALE = 0.45
local VEIL_PEAK = 0.68
local VEIL_POWER = 2.4

local function clamp01(value)
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(value, 0, 1)
end

local function indexOf(order, id)
	if order == nil or id == nil then
		return nil
	end
	for index, entry in order do
		if entry == id then
			return index
		end
	end
	return nil
end

local function direction(fromPage, toPage, order)
	local from = indexOf(order, fromPage)
	local to = indexOf(order, toPage)
	if from == nil or to == nil or from == to then
		return 1
	end
	return if to > from then 1 else -1
end

local function distance(phone, soft)
	local base = if phone then SLIDE_PHONE else SLIDE_DESKTOP
	return if soft then math.floor(base * SOFT_SCALE + 0.5) else base
end

local function offset(amount, dir, axis, travel)
	local t = clamp01(amount)
	local remaining = (1 - t) * (if dir == -1 then -1 else 1) * (travel or SLIDE_DESKTOP)
	local px = math.round(remaining)
	if axis == "x" then
		return px, 0
	end
	return 0, px
end

local function veilTransparency(amount)
	local t = clamp01(amount)
	return 1 - VEIL_PEAK * (1 - t) ^ VEIL_POWER
end

return {
	SLIDE_DESKTOP = SLIDE_DESKTOP,
	SLIDE_PHONE = SLIDE_PHONE,
	SOFT_SCALE = SOFT_SCALE,
	VEIL_PEAK = VEIL_PEAK,
	direction = direction,
	distance = distance,
	offset = offset,
	veilTransparency = veilTransparency,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
