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
local ViewportScaleContext = require(script.Parent.autoScale).ViewportScaleContext
local Breakpoints = require(script.Parent.theme).Breakpoints
local usesDesktopStructure = require(script.Parent.interaction).usesDesktopStructure
local BEZIER_CIRCLE_KAPPA = 0.5522847498
local function cubicPoint(alpha, p0, p1, p2, p3)
	local point = BezierCurve:cubicBezier(math.clamp(alpha, 0, 1), p0, p1, p2, p3)
	return Vector2.new(point.X, point.Y)
end
local easeOutCubic = function(value)
	return 1 - math.pow(1 - value, 3)
end
local easeInCubic = function(value)
	return value * value * value
end
local easeOutQuart = function(value)
	return 1 - math.pow(1 - value, 4)
end
local easeOutBack = function(value)
	local overshoot = 1.70158
	local shifted = value - 1
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
	-- Always call hooks (Rules of Hooks). Touch-primary devices short-circuit the
	-- effect body so we never attach a RenderStepped listener for a cursor that
	-- does not exist, but the hook order stays identical across platforms.
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
		-- Sample every 3rd frame — proximity drives soft glow, not gameplay.
		local stride = 3
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
	local frequency = math.max(1.35, stiffness / 130)
	local dampingRatio = math.clamp(damping / 52, 0.48, 0.88)
	return {
		raw = raw,
		configure = function(self, nextStiffness, nextDamping)
			frequency = math.max(1.35, nextStiffness / 130)
			dampingRatio = math.clamp(nextDamping / 52, 0.48, 0.88)
		end,
		setGoal = function(self, goal)
			armFlipper(raw)
			raw:setGoal(Spring.new(goal, {
				frequency = frequency,
				dampingRatio = dampingRatio,
			}))
		end,
		setPosition = function(self, position)
			armFlipper(raw)
			raw:setGoal(Instant.new(position))
		end,
		onChange = function(self, callback)
			local connection = raw:onStep(callback)
			return function()
				return connection:disconnect()
			end
		end,
		halt = function(self)
			raw:stop()
			disarmFlipper(raw)
		end,
		destroy = function(self)
			disarmFlipper(raw)
			raw:destroy()
			stopDriverIfIdle()
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
local MOTION_OFF_THRESHOLD = 0.08
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
local continuousRate = 48
local continuousAccumulator = 0
local LISTENER_SOFT_CAP = 32
local warnedOverCap = false
local freezeExternal = false
local freezeHitch = false
local freezeNav = false
local decorativeFrozen = false
local clockBudget = 14
local navFreezeGeneration = 0
local flipperMotors = {}
local flipperCount = 0
local ensureDriver
function armFlipper(motor)
	local _motor = motor
	if flipperMotors[_motor] ~= nil then
		return nil
	end
	local _motor_1 = motor
	flipperMotors[_motor_1] = true
	flipperCount += 1
	ensureDriver()
end
function disarmFlipper(motor)
	local _motor = motor
	-- ▼ Set.delete ▼
	local _valueExisted = flipperMotors[_motor] ~= nil
	flipperMotors[_motor] = nil
	-- ▲ Set.delete ▲
	if not _valueExisted then
		return nil
	end
	flipperCount -= 1
	if flipperCount < 0 then
		flipperCount = 0
	end
end
local function applyFrozenFlag()
	local frozen = freezeExternal or freezeHitch or freezeNav
	if decorativeFrozen == frozen then
		return nil
	end
	decorativeFrozen = frozen
	if frozen then
		continuousAccumulator = 0
		-- When hitch/nav freeze parks decorative work and nothing realtime is
		-- left, drop the RenderStepped driver entirely instead of spinning a
		-- no-op callback every frame until thaw.
		stopDriverIfIdle()
	elseif listenerCount > 0 or continuousListenerCount > 0 or flipperCount > 0 or realtimeClockCount > 0 or decorativeClockCount > 0 then
		ensureDriver()
	end
end
local function compactClocks(list)
	local write = 0
	for index = 0, #list - 1 do
		local slot = list[index + 1]
		if slot ~= nil and slot.alive then
			list[write + 1] = slot
			write += 1
		end
	end
	while #list > write do
		list[#list] = nil
	end
end
-- Rotating start offset so the budget cap doesn't always favor the same
-- earliest-registered slots — without this, once more than `budget` clocks
-- are alive at once (e.g. many buttons shimmering from rapid hover/click),
-- every slot past the first `budget` in array order never ticks again until
-- enough earlier slots die off, which reads as a permanently frozen shimmer.
--
-- Phase still advances for every live slot even past the budget: only the
-- React binding push is rate-limited. That keeps shimmer phase coherent when
-- a slot rotates into the push window without scheduling N updates/frame.
local tickRotation = 0
local function tickClocks(list, deltaTime, budget)
	local size = #list
	local live = 0
	local dead = 0
	if size > 0 then
		tickRotation = tickRotation % size
	end
	do
		local offset = 0
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				offset += 1
			else
				_shouldIncrement = true
			end
			if not (offset < size) then
				break
			end
			local index = (tickRotation + offset) % size
			local slot = list[index + 1]
			if slot == nil or not slot.alive then
				dead += 1
				continue
			end
			local advanced = (slot.phase + deltaTime * slot.speed) % slot.period
			slot.phase = advanced
			if live < budget then
				live += 1
				slot.push(advanced)
			end
		end
	end
	if size > 0 then
		tickRotation = (tickRotation + math.max(1, budget)) % size
	end
	if dead >= 6 then
		compactClocks(list)
	end
	return live
end
local function addClock(slot, realtime)
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
	slot.alive = false
	if realtime then
		realtimeClockCount = math.max(0, realtimeClockCount - 1)
		if realtimeClockCount == 0 then
			compactClocks(realtimeClocks)
		end
	else
		decorativeClockCount = math.max(0, decorativeClockCount - 1)
		if decorativeClockCount == 0 then
			compactClocks(decorativeClocks)
		end
	end
	stopDriverIfIdle()
end
local function setContinuousMotionRate(rate)
	-- Floor at 12 so constrained antilag can target ~18Hz decorative clocks
	-- without being clamped back up to a desktop-ish 20.
	continuousRate = math.clamp(math.floor(rate + 0.5), 12, 60)
	continuousAccumulator = math.min(continuousAccumulator, 1 / continuousRate)
end
local function setDecorativeMotionFrozen(frozen)
	if freezeExternal == frozen then
		return nil
	end
	freezeExternal = frozen
	applyFrozenFlag()
end
local function setHitchMotionFrozen(frozen)
	if freezeHitch == frozen then
		return nil
	end
	freezeHitch = frozen
	applyFrozenFlag()
end
local function beginUiTransition(seconds)
	if seconds == nil then
		seconds = 0.1
	end
	navFreezeGeneration += 1
	local generation = navFreezeGeneration
	freezeNav = true
	applyFrozenFlag()
	task.delay(math.max(0.06, seconds), function()
		if generation ~= navFreezeGeneration then
			return nil
		end
		freezeNav = false
		applyFrozenFlag()
	end)
end
local function isUiTransitioning()
	return freezeNav
end
local function setClockBudget(budget)
	clockBudget = math.clamp(math.floor(budget), 2, 24)
end
local function getClockBudget()
	return clockBudget
end
local function decorativeClockSlotsUsed()
	return decorativeClockCount
end
local function driverHasWork()
	-- Decorative/continuous work does not keep the driver alive while frozen —
	-- otherwise hitch freezes still paid for a RenderStepped no-op every frame.
	if listenerCount > 0 or flipperCount > 0 or realtimeClockCount > 0 then
		return true
	end
	if decorativeFrozen then
		return false
	end
	return continuousListenerCount > 0 or decorativeClockCount > 0
end
function ensureDriver()
	if driver ~= nil then
		return nil
	end
	driver = RunService.RenderStepped:Connect(function(deltaTime)
		local clamped = math.min(deltaTime, 0.05)
		local ranRealtime = false
		if flipperCount > 0 then
			ranRealtime = true
			for motor in flipperMotors do
				if motor:step(clamped) then
					disarmFlipper(motor)
				end
			end
		end
		if realtimeClockCount > 0 then
			ranRealtime = true
			tickClocks(realtimeClocks, clamped, 48)
		end
		if listenerCount > 0 then
			ranRealtime = true
			for active in listeners do
				active(clamped)
			end
		end
		if decorativeFrozen then
			if not ranRealtime then
				stopDriverIfIdle()
			end
			return nil
		end
		continuousAccumulator += clamped
		local step = 1 / continuousRate
		if continuousAccumulator + 1e-5 < step then
			return nil
		end
		local sampledDelta = continuousAccumulator
		continuousAccumulator = 0
		if decorativeClockCount > 0 then
			tickClocks(decorativeClocks, sampledDelta, clockBudget)
		end
		if continuousListenerCount > 0 then
			for active in continuousListeners do
				active(sampledDelta)
			end
		end
	end)
end
function stopDriverIfIdle()
	if driverHasWork() or driver == nil then
		return nil
	end
	driver:Disconnect()
	driver = nil
	continuousAccumulator = 0
end
local function subscribe(listener)
	local _listener = listener
	if not (listeners[_listener] ~= nil) then
		local _listener_1 = listener
		listeners[_listener_1] = true
		listenerCount += 1
		if listenerCount > LISTENER_SOFT_CAP and not warnedOverCap then
			warnedOverCap = true
			print(`[forge] {listenerCount} frame listeners (cap {LISTENER_SOFT_CAP})`)
		end
	end
	ensureDriver()
	local released = false
	return function()
		if released then
			return nil
		end
		released = true
		local _listener_1 = listener
		listeners[_listener_1] = nil
		listenerCount -= 1
		if listenerCount <= LISTENER_SOFT_CAP then
			warnedOverCap = false
		end
		if listenerCount < 0 then
			listenerCount = 0
		end
		stopDriverIfIdle()
	end
end
local function subscribeContinuous(listener)
	local _listener = listener
	if not (continuousListeners[_listener] ~= nil) then
		local _listener_1 = listener
		continuousListeners[_listener_1] = true
		continuousListenerCount += 1
	end
	ensureDriver()
	local released = false
	return function()
		if released then
			return nil
		end
		released = true
		local _listener_1 = listener
		continuousListeners[_listener_1] = nil
		continuousListenerCount -= 1
		if continuousListenerCount < 0 then
			continuousListenerCount = 0
		end
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
	local effectiveStiffness = stiffness * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)
	local binding, ripple = useRippleSpring(initial, {
		start = true,
		frequency = math.max(1.2, effectiveStiffness / 140),
		dampingRatio = math.clamp(damping / 48, 0.52, 0.92),
	})
	React.useEffect(function()
		if reducedMotion or motionScale <= MOTION_OFF_THRESHOLD then
			ripple:halt()
			ripple:setGoal(goal)
			ripple:setPosition(goal)
		else
			ripple:setGoal(goal, {
				frequency = math.max(1.2, effectiveStiffness / 140),
				dampingRatio = math.clamp(damping / 48, 0.52, 0.92),
			})
		end
	end, { damping, effectiveStiffness, goal, motionScale, reducedMotion, ripple })
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
	local effectiveStiffness = stiffness * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)
	local binding, setBinding = React.useBinding(initial)
	local motor = React.useRef()
	if not motor.current then
		motor.current = createFlipperMotor(initial, effectiveStiffness, damping)
	end
	React.useEffect(function()
		local active = motor.current
		return active:onChange(function(value)
			return setBinding(value)
		end)
	end, { setBinding })
	React.useEffect(function()
		local active = motor.current
		active:configure(effectiveStiffness, damping)
		if reducedMotion or motionScale <= MOTION_OFF_THRESHOLD then
			active:halt()
			active:setPosition(goal)
			setBinding(goal)
		else
			active:setGoal(goal)
		end
	end, { damping, effectiveStiffness, goal, motionScale, reducedMotion, setBinding })
	React.useEffect(function()
		return function()
			local _result = motor.current
			if _result ~= nil then
				_result = _result:destroy()
			end
			return _result
		end
	end, {})
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
	local binding, setBinding = React.useBinding(initial)
	local current = React.useRef(initial)
	React.useEffect(function()
		local otter = loadOtter()
		if reducedMotion or motionScale <= MOTION_OFF_THRESHOLD or otter == nil then
			current.current = goal
			setBinding(goal)
			return nil
		end
		local motor = otter.createSingleMotor(current.current)
		local disconnect = motor:onStep(function(value)
			current.current = value
			setBinding(value)
		end)
		motor:setGoal(otter.spring(goal, {
			dampingRatio = math.clamp(dampingRatio, 0.35, 1.25),
			frequency = math.max(0.5, frequency * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)),
			restingVelocityLimit = 0.001,
			restingPositionLimit = 0.001,
		}))
		return function()
			disconnect()
			motor:destroy()
		end
	end, { dampingRatio, frequency, goal, motionScale, reducedMotion, setBinding })
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
	local suppressOnMount = React.useRef(React.useContext(EntranceMotionSuppressedContext)).current
	local scaleRef = React.useRef()
	local mounted = React.useRef(false)
	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return nil
		end
		local still = reducedMotion or suppressOnMount or motionScale <= MOTION_OFF_THRESHOLD
		spr.stop(scale)
		if not mounted.current then
			mounted.current = true
			scale.Scale = if still then goal else initial
		end
		if still then
			scale.Scale = goal
			return nil
		end
		if scale.Parent ~= nil and scaleRef.current == scale then
			spr.target(scale, math.clamp(dampingRatio, 0.45, 1.25), math.max(1, frequency * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)), {
				Scale = goal,
			})
		end
		return function()
			spr.stop(scale)
		end
	end, { dampingRatio, frequency, goal, initial, motionScale, reducedMotion })
	return scaleRef
end
--[[
	* UIScale ignores AnchorPoint and grows from the parent's top-left. Put the
	 *  scaled visuals inside a Size(1,1) Position(0.5,0.5) AnchorPoint(0.5,0.5)
	 *  host so entrance/exit zooms from the middle instead of a corner. 
]]
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
	local effectiveStiffness = stiffness * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)
	local binding, setBinding = React.useBinding(if enabled then goal else 0)
	local motor = React.useRef()
	React.useEffect(function()
		if not enabled then
			local _result = motor.current
			if _result ~= nil then
				_result:halt()
			end
			setBinding(0)
			return nil
		end
		if motor.current == nil then
			motor.current = createFlipperMotor(goal, effectiveStiffness, damping)
		end
		local active = motor.current
		active:configure(effectiveStiffness, damping)
		local disconnect = active:onChange(function(value)
			return setBinding(value)
		end)
		if reducedMotion or motionScale <= MOTION_OFF_THRESHOLD then
			active:halt()
			active:setPosition(goal)
			setBinding(goal)
		else
			active:setGoal(goal)
		end
		return disconnect
	end, { damping, effectiveStiffness, enabled, goal, motionScale, reducedMotion, setBinding })
	React.useEffect(function()
		return function()
			local _result = motor.current
			if _result ~= nil then
				_result = _result:destroy()
			end
			return _result
		end
	end, {})
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
		easing = easeOutCubic
	end
	local _result
	if reducedMotion then
		_result = goal
	else
		local _condition = initial
		if _condition == nil then
			_condition = goal
		end
		_result = _condition
	end
	local start = _result
	local binding, setBinding = React.useBinding(start)
	local current = React.useRef(start)
	React.useEffect(function()
		if reducedMotion then
			current.current = goal
			setBinding(goal)
			return nil
		end
		local from = current.current
		if math.abs(from - goal) < 0.001 then
			current.current = goal
			setBinding(goal)
			return nil
		end
		local elapsed = 0
		local stop
		stop = subscribe(function(deltaTime)
			elapsed += deltaTime
			local alpha = math.clamp(elapsed / math.max(0.01, duration), 0, 1)
			local value = from + (goal - from) * easing(alpha)
			current.current = value
			setBinding(value)
			if alpha >= 1 then
				local _result_1 = stop
				if _result_1 ~= nil then
					_result_1()
				end
			end
		end)
		return function()
			local _result_1 = stop
			if _result_1 ~= nil then
				_result_1 = _result_1()
			end
			return _result_1
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
		duration = 0.34
	end
	local exiting, setExiting = React.useState(false)
	local closing = React.useRef(false)
	local finished = React.useRef(false)
	local driver = React.useRef()
	local afterRef = React.useRef()
	local amount, setAmount = React.useBinding(1)
	local begin = React.useCallback(function(after)
		if closing.current then
			return nil
		end
		closing.current = true
		finished.current = false
		afterRef.current = after
		setExiting(true)
		if reducedMotion then
			setAmount(0)
			finished.current = true
			after()
			return nil
		end
		local startedAt = os.clock()
		local span = math.max(0.12, duration)
		local _result = driver.current
		if _result ~= nil then
			_result()
		end
		driver.current = subscribe(function()
			local alpha = math.clamp((os.clock() - startedAt) / span, 0, 1)
			local shown = if alpha >= 1 then 0 else 1 - easeInCubic(alpha)
			setAmount(shown)
			if alpha < 1 then
				return nil
			end
			local _result_1 = driver.current
			if _result_1 ~= nil then
				_result_1()
			end
			driver.current = nil
			if finished.current then
				return nil
			end
			finished.current = true
			task.defer(function()
				local _result_2 = afterRef.current
				if _result_2 ~= nil then
					_result_2 = _result_2()
				end
				return _result_2
			end)
		end)
	end, { duration, reducedMotion, setAmount })
	React.useEffect(function()
		if resetWhenActive ~= true then
			return nil
		end
		local _result = driver.current
		if _result ~= nil then
			_result()
		end
		driver.current = nil
		closing.current = false
		finished.current = false
		afterRef.current = nil
		setExiting(false)
		setAmount(1)
	end, { resetWhenActive, setAmount })
	React.useEffect(function()
		return function()
			local _result = driver.current
			if _result ~= nil then
				_result()
			end
			driver.current = nil
		end
	end, {})
	return { amount, exiting, begin }
end
local function useTokenEntrance(token, reducedMotion, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if duration == nil then
		duration = 0.12
	end
	local skip = reducedMotion
	local binding, setBinding = React.useBinding(if skip then 1 else 0)
	local motor = React.useRef()
	if motor.current == nil then
		motor.current = createFlipperMotor(if skip then 1 else 0, 720, 38)
	end
	React.useEffect(function()
		local active = motor.current
		return active:onChange(function(value)
			return setBinding(value)
		end)
	end, { setBinding })
	React.useEffect(function()
		local active = motor.current
		if skip then
			active:halt()
			active:setPosition(1)
			setBinding(1)
			return nil
		end
		active:setPosition(0)
		setBinding(0)
		active:configure(720, 38)
		active:setGoal(1)
	end, { duration, reducedMotion, setBinding, skip, token })
	React.useEffect(function()
		return function()
			local _result = motor.current
			if _result ~= nil then
				_result = _result:destroy()
			end
			return _result
		end
	end, {})
	return binding
end
local function useEntrance(reducedMotion)
	if reducedMotion == nil then
		reducedMotion = false
	end
	local suppressOnMount = React.useRef(React.useContext(EntranceMotionSuppressedContext)).current
	local skip = reducedMotion or suppressOnMount
	return useFlipperSpring(1, skip, 720, 38, if skip then 1 else 0)
end
local function useStagger(index, reducedMotion, step, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if step == nil then
		step = 0.01
	end
	if duration == nil then
		duration = 0.14
	end
	local suppressOnMount = React.useRef(React.useContext(EntranceMotionSuppressedContext)).current
	local skip = reducedMotion or suppressOnMount or index > 8
	local binding, setBinding = React.useBinding(if skip then 1 else 0)
	local motor = React.useRef()
	if motor.current == nil then
		motor.current = createFlipperMotor(if skip then 1 else 0, 680, 36)
	end
	React.useEffect(function()
		local active = motor.current
		return active:onChange(function(value)
			return setBinding(value)
		end)
	end, { setBinding })
	React.useEffect(function()
		local active = motor.current
		if skip then
			active:halt()
			active:setPosition(1)
			setBinding(1)
			return nil
		end
		active:setPosition(0)
		setBinding(0)
		local delay = math.min(index, 8) * math.max(0.016, step)
		local job = task.delay(delay, function()
			active:configure(680, 36)
			active:setGoal(1)
		end)
		return function()
			return task.cancel(job)
		end
	end, { duration, index, setBinding, skip, step })
	React.useEffect(function()
		return function()
			local _result = motor.current
			if _result ~= nil then
				_result = _result:destroy()
			end
			return _result
		end
	end, {})
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
	local binding, setBinding = React.useBinding(0)
	local phase = React.useRef(0)
	React.useEffect(function()
		if not enabled or speed <= 0 then
			return nil
		end
		local slot = {
			speed = speed,
			period = period,
			phase = phase.current,
			push = function(value)
				phase.current = value
				setBinding(value)
			end,
			alive = true,
		}
		addClock(slot, realtime)
		return function()
			phase.current = slot.phase
			dropClock(slot, realtime)
		end
	end, { enabled, period, realtime, setBinding, speed })
	return binding
end
local function useWallClock(enabled)
	if enabled == nil then
		enabled = true
	end
	local binding, setBinding = React.useBinding(os.time())
	React.useEffect(function()
		setBinding(os.time())
		if not enabled then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			local previous = os.time()
			while alive do
				task.wait(0.2)
				local current = os.time()
				if current ~= previous then
					previous = current
					setBinding(current)
				end
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { enabled, setBinding })
	return binding
end
local function useRotation(enabled, degreesPerSecond)
	return useClock(enabled, degreesPerSecond, 360, true)
end
local function useFlash(trigger, reducedMotion, duration)
	if reducedMotion == nil then
		reducedMotion = false
	end
	if duration == nil then
		duration = 0.42
	end
	local binding, setBinding = React.useBinding(0)
	React.useEffect(function()
		if trigger == 0 or reducedMotion or isUiTransitioning() then
			setBinding(0)
			return nil
		end
		local elapsed = 0
		local stop
		setBinding(1)
		stop = subscribe(function(deltaTime)
			elapsed += deltaTime
			local alpha = math.clamp(elapsed / math.max(0.01, duration), 0, 1)
			setBinding(1 - easeOutCubic(alpha))
			if alpha >= 1 then
				local _result = stop
				if _result ~= nil then
					_result()
				end
			end
		end)
		return function()
			local _result = stop
			if _result ~= nil then
				_result = _result()
			end
			return _result
		end
	end, { duration, reducedMotion, setBinding, trigger })
	return binding
end
local function usePulse(enabled, speed)
	if speed == nil then
		speed = 1.6
	end
	local clock = useClock(enabled, speed, TAU)
	return clock:map(function(phase)
		return (math.sin(phase) + 1) / 2
	end)
end
local function useGlowStroke(active, reducedMotion, rest, near, far, speed)
	if near == nil then
		near = 0.12
	end
	if far == nil then
		far = 0.6
	end
	if speed == nil then
		speed = 2.2
	end
	local everActive, setEverActive = React.useState(active)
	React.useEffect(function()
		if active then
			setEverActive(true)
		end
	end, { active })
	local pulse = usePulse(active and not reducedMotion, speed)
	local blend = useOptionalFlipperSpring(if active then 1 else 0, everActive, reducedMotion, 520, 40)
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
			keyboardOpen = UserInputService.OnScreenKeyboardVisible,
			desktop = usesDesktopStructure(size.X, size.Y),
			compact = size.X < Breakpoints.compact,
			tight = size.X < Breakpoints.tight,
			short = size.Y < Breakpoints.short,
		}
	end, { host, size })
end
return {
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
