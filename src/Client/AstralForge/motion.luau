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
	local callbacks = {}
	local destroyed = false
	local finished = false
	local stepping = false
	local destroyQueued = false
	local suppressEmit = false
	-- One goal object for the life of the motor. Spam retargets it instead of
	-- allocating a Spring or Instant on every hover, press, or snap.
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
		stepping = true
		local pending = {}
		for entry in callbacks do
			table.insert(pending, entry)
		end
		for _, entry in pending do
			if not entry.done and not destroyed then
				entry.callback(value)
			end
		end
		stepping = false
		if destroyQueued then
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
			frequency = math.max(1.35, nextStiffness / 130)
			dampingRatio = math.clamp(nextDamping / 52, 0.48, 0.88)
			springGoal._frequency = frequency
			springGoal._dampingRatio = dampingRatio
		end,
		setGoal = function(self, goal)
			if destroyed then
				return nil
			end
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
			-- Snap without notifying listeners until the Instant has disarmed.
			-- A hover that lands inside the callback can setGoal afterwards and
			-- re-arm this same motor; disarming after that callback used to
			-- drop the new spring on the floor.
			instantGoal._targetValue = position
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
-- Realtime clocks (spinners, pulse needles, celebration timers) get a higher tick
-- budget than decorative shimmer, but touch devices hard-cap near 24 so rapid
-- hover/press storms cannot starve critical presence clocks.
local REALTIME_CLOCK_BUDGET = 48
local TOUCH_REALTIME_CLOCK_BUDGET = 24
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
local flipperToken = {}
local flipperCount = 0
-- One deadline per stagger motor. A second trigger overwrites this entry
-- instead of scheduling another task.delay.
local pendingArrivals = {}
local pendingArrivalCount = 0
local ensureDriver
local function isTouchPrimary()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end
local function realtimeClockBudget()
	if UserInputService.TouchEnabled then
		return TOUCH_REALTIME_CLOCK_BUDGET
	end
	return REALTIME_CLOCK_BUDGET
end
function armFlipper(motor)
	-- Bump even when the motor is already stepping. A setGoal inside onStep
	-- must outlive the complete=true return that would otherwise disarm it.
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
		elseif slot ~= nil then
			slot.listed = false
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
local clockTicking = 0
local function tickClocks(list, deltaTime, budget)
	local size = #list
	local live = 0
	local dead = 0
	clockTicking += 1
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
			live += 1
			-- Advance every clock so phase stays coherent, but only push the
			-- rotating budget into React. Pushing every binding every frame
			-- was the main UI cost once dozens of pulses were alive.
			if offset < math.max(1, budget) then
				slot.push(advanced)
			end
		end
	end
	if size > 0 then
		tickRotation = (tickRotation + math.max(1, budget)) % size
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
	-- Stay in the list while the driver is walking it. A hover in that same
	-- frame sets alive again on this slot instead of inserting a second copy.
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
	-- Decorative clocks stay on a full frame. Throttling this rate made sweeps
	-- and pulses look paused on constrained devices.
	continuousRate = 60
	continuousAccumulator = 0
end
local function setDecorativeMotionFrozen(frozen)
	if freezeExternal == frozen then
		return nil
	end
	freezeExternal = frozen
	applyFrozenFlag()
end
local function setHitchMotionFrozen(_frozen)
	-- A one-frame hitch must not park springs, clocks, or the driver. The flag
	-- stays available for callers; it does not freeze playback.
end
local function beginUiTransition(_seconds)
	-- Page changes keep their clocks and springs running. Freezing here left
	-- ambient motion idle until the thaw, and sometimes it never resumed.
end
local function isUiTransitioning()
	return freezeNav
end
local function setClockBudget(_budget)
	-- Tier budgets must not starve UI clocks. Every decorative spring and pulse
	-- keeps a full push window; antilag still computes its own particle numbers.
	clockBudget = 24
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
				motor:configure(920, 44)
				motor:setGoal(1)
			end
		end
	end
	if pendingArrivalCount < 0 then
		pendingArrivalCount = 0
	end
end
local function driverHasWork()
	-- Decorative/continuous work does not keep the driver alive while frozen —
	-- otherwise hitch freezes still paid for a RenderStepped no-op every frame.
	if listenerCount > 0 or flipperCount > 0 or realtimeClockCount > 0 or pendingArrivalCount > 0 then
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
				local token = flipperToken[motor]
				if motor:step(clamped) then
					disarmFlipper(motor, token)
				end
			end
		end
		if realtimeClockCount > 0 then
			ranRealtime = true
			tickClocks(realtimeClocks, clamped, realtimeClockBudget())
		end
		if listenerCount > 0 then
			ranRealtime = true
			for active in listeners do
				active(clamped)
			end
		end
		-- Decorative pulses, glows, and ambient clocks advance on the same frame
		-- as springs. Subsampling them made sweeps hitch and read as idle.
		if decorativeClockCount > 0 then
			tickClocks(decorativeClocks, clamped, clockBudget)
		end
		if continuousListenerCount > 0 then
			for active in continuousListeners do
				active(clamped)
			end
		end
		-- After springs step, so an unmount during onStep can cancel a stagger
		-- before its deadline fires setGoal on a destroyed motor.
		pumpArrivals()
	end)
end
function stopDriverIfIdle()
	-- Stay connected for the whole session. Disconnecting when the last spring
	-- settled left the next clock or layout change with no driver until something
	-- else re-armed it, so motion read as idle.
	if driver == nil then
		ensureDriver()
	end
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
		-- Always spring. reducedMotion used to snap the motor to its goal, so a
		-- tier flip made the pose vanish and then replay.
		ripple:setGoal(goal, {
			frequency = math.max(1.2, effectiveStiffness / 140),
			dampingRatio = math.clamp(damping / 48, 0.52, 0.92),
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
	local effectiveStiffness = stiffness * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)
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
			dampingRatio = math.clamp(dampingRatio, 0.35, 1.25),
			frequency = math.max(0.5, frequency * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)),
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
	local scaleRef = React.useRef()
	local mounted = React.useRef(false)
	React.useEffect(function()
		return function()
			local scale = scaleRef.current
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
		if not mounted.current then
			mounted.current = true
			scale.Scale = initial
		end
		if scale.Parent ~= nil and scaleRef.current == scale then
			spr.target(scale, math.clamp(dampingRatio, 0.45, 1.25), math.max(1, frequency * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)), {
				Scale = goal,
			})
		end
	end, { dampingRatio, frequency, goal, initial, motionScale })
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
		easing = easeOutCubic
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
	React.useEffect(function()
		local stop = subscribe(function(deltaTime)
			if not runningRef.current then
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
			end
		end)
		return stop
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
	React.useEffect(function()
		local stop = subscribe(function()
			if pendingAfter.current then
				pendingAfter.current = false
				local callback = afterRef.current
				afterRef.current = nil
				if callback ~= nil then
					callback()
				end
				return nil
			end
			if not running.current then
				return nil
			end
			local span = spanRef.current
			if span <= 0 then
				span = 0.01
			end
			local alpha = math.clamp((os.clock() - startedAt.current) / span, 0, 1)
			local shown = if alpha >= 1 then 0 else 1 - easeInCubic(alpha)
			setAmountRef.current(shown)
			if alpha < 1 then
				return nil
			end
			running.current = false
			if finished.current then
				return nil
			end
			finished.current = true
			pendingAfter.current = true
		end)
		return function()
			running.current = false
			pendingAfter.current = false
			stop()
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
		spanRef.current = math.clamp(duration * 0.62, 0.08, 0.18)
		running.current = true
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
	-- Page swaps always spring in. The softMotion flag must not snap this motor to rest.
	local span = math.clamp(duration, 0.1, 0.16)
	local stiffness = math.floor(168 / span)
	local damping = 46
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
	return useFlipperSpring(1, skip, 980, 46, 0)
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
	if motor.current == nil then
		motor.current = createFlipperMotor(0, 920, 44)
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
		active:configure(920, 44)
		-- Ease-out curve on the existing arrival spring. The first gap is about one
		-- step (~0.025s); later siblings open a little wider instead of a linear march.
		local capped = math.min(math.max(index, 0), 8)
		local delay = step * (capped ^ 1.15)
		scheduleArrival(active, delay)
		return function()
			cancelArrival(active)
		end
	end, { duration, index, setBinding, step })
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
	-- Scale clock advance by motion settings so reduced/low-motion players get
	-- quieter ambient loops without every caller needing a second gate.
	local scaledSpeed = speed * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL)
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
local function useWallClock(enabled)
	if enabled == nil then
		enabled = true
	end
	-- Prefer Roblox-synced server time so surge/overdrive/cycle countdowns match the
	-- deadlines the server stamps (and the anomaly pulse needle).
	local Workspace = game:GetService("Workspace")
	local function syncedNow()
		local ok, value = pcall(function()
			return Workspace:GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return value
		end
		return os.time()
	end
	local binding, setBinding = React.useBinding(syncedNow())
	local enabledRef = React.useRef(enabled)
	enabledRef.current = enabled
	local setBindingRef = React.useRef(setBinding)
	setBindingRef.current = setBinding
	React.useEffect(function()
		setBindingRef.current(syncedNow())
	end, { enabled })
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.2)
				if alive and enabledRef.current then
					setBindingRef.current(syncedNow())
				end
			end
		end)
		return function()
			alive = false
			pcall(function()
				task.cancel(worker)
			end)
		end
	end, {})
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
		-- Button-scale flashes finish fast. Ceremonial slams (duration >= 0.75) keep their span.
		local span = if duration >= 0.75 then duration else math.min(duration, 0.22)
		local stiffness = math.clamp(math.floor(180 / math.max(0.08, span)), 320, 1400)
		active:configure(stiffness, 52)
		active:setPosition(1)
		setBinding(1)
		active:setGoal(0)
	end, { duration, setBinding, trigger })
	return binding
end
local function usePulse(enabled, speed)
	if speed == nil then
		speed = 1.35
	end
	local clock = useClock(enabled, speed, TAU)
	return clock:map(function(phase)
		return (math.sin(phase) + 1) / 2
	end)
end
local function useGlowStroke(active, reducedMotion, rest, near, far, speed)
	-- Quieter defaults: slower breath, narrower transparency swing — keeps idle
	-- presence without the noisy neon strobe that stacked glows used to create.
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
ensureDriver()
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
