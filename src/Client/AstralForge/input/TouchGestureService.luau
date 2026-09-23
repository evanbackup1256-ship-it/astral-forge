--!strict
--[=[
	[INPUT] Astral Forge Engine v5.0+ Touch & Gesture Engine
	Omni-platform touch architecture featuring:
	- Multi-touch pointer lifecycle management
	- Pinch-to-zoom & two-finger twist detection
	- Velocity-based directional swipe & flick analysis
	- Dynamic Virtual Thumbstick (anchors dynamically under thumb)
	- "Fat-Finger" forgiveness with distance-to-center hit resolution
]=]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

export type TouchPointer = {
	id: number,
	startPos: Vector2,
	currentPos: Vector2,
	previousPos: Vector2,
	velocity: Vector2,
	startTime: number,
	lastUpdateTime: number,
	isConsumed: boolean,
}

export type GestureEvent = "Tap" | "DoubleTap" | "LongPress" | "Swipe" | "Pinch" | "ThumbstickMove"

export type SwipeData = {
	direction: Vector2,
	distance: number,
	velocity: Vector2,
	isFlick: boolean,
}

export type PinchData = {
	center: Vector2,
	scaleDelta: number,
	rotationDelta: number,
	distance: number,
}

export type ThumbstickData = {
	origin: Vector2,
	current: Vector2,
	direction: Vector2,
	magnitude: number, -- 0 to 1
	active: boolean,
}

local TouchGestureService = {}
TouchGestureService.__index = TouchGestureService

-- Configuration constants
local MIN_SWIPE_DISTANCE = 40 -- Minimum pixels for swipe
local FLICK_VELOCITY_THRESHOLD = 800 -- Pixels/sec
local PINCH_MIN_TOUCH_DIST = 16
local THUMBSTICK_RADIUS = 64
local THUMBSTICK_DEADZONE = 0.12
local FAT_FINGER_EXPANSION_PX = 14 -- Hitbox padding beyond visual border
local TAP_MAX_DURATION = 0.35
local TAP_MAX_TRAVEL = 12

local activeTouches: { [InputObject]: TouchPointer } = {}
local pointerIdCounter = 0
local listeners: { [GestureEvent]: { (any) -> () } } = {
	Tap = {},
	DoubleTap = {},
	LongPress = {},
	Swipe = {},
	Pinch = {},
	ThumbstickMove = {},
}

-- Dynamic Virtual Thumbstick state
local thumbstickState: ThumbstickData = {
	origin = Vector2.zero,
	current = Vector2.zero,
	direction = Vector2.zero,
	magnitude = 0,
	active = false,
}
local thumbstickTouch: InputObject? = nil

-- Registered Fat-Finger Hitbox Targets
type HitTarget = {
	id: string,
	gui: GuiObject,
	priority: number,
	callback: () -> (),
	customExpansion: number?,
}
local registeredTargets: { HitTarget } = {}
local inputConnections: { RBXScriptConnection } = {}
local initialized = false

local function isVisible(gui: GuiObject): boolean
	local ancestor: Instance? = gui
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function toGuiPosition(rawPosition: Vector2): Vector2
	-- InputObject.Position includes the GUI inset; PlayerGui hit tests and
	-- GuiObject.AbsolutePosition use the inset-adjusted coordinate space.
	local ok, topLeft = pcall(function() return GuiService:GetGuiInset() end)
	return if ok and typeof(topLeft) == "Vector2" then rawPosition - topLeft else rawPosition
end

local function isPointUnclipped(gui: GuiObject, position: Vector2): boolean
	local ancestor: Instance? = gui.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
			local origin = ancestor.AbsolutePosition
			local size = ancestor.AbsoluteSize
			if position.X < origin.X or position.X > origin.X + size.X
				or position.Y < origin.Y or position.Y > origin.Y + size.Y then
				return false
			end
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function isOnInteractiveGui(position: Vector2): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, gui in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if gui:IsA("GuiButton") and isVisible(gui) then
			return true
		end
	end
	return false
end

--[=[
	Helper: Emit gesture events to registered listeners
]=]
local function emit(event: GestureEvent, payload: any)
	local list = listeners[event]
	if list then
		for _, handler in list do
			task.spawn(handler, payload)
		end
	end
end

--[=[
	Evaluates registered UI elements using distance-weighted "Fat-Finger" expansion.
	Returns true if a target was successfully engaged.
]=]
function TouchGestureService.ResolveFatFingerHit(screenPosition: Vector2): boolean
	-- Native GuiButton.Activated owns touches within a visible button. Assistance only
	-- handles the extra margin; otherwise a tap can purchase or claim twice.
	if isOnInteractiveGui(screenPosition) then
		return false
	end
	local bestTarget: HitTarget? = nil
	local bestScore = math.huge

	for _, target in registeredTargets do
		if not target.gui.Parent or not isVisible(target.gui) or not isPointUnclipped(target.gui, screenPosition) then
			continue
		end

		local absPos = target.gui.AbsolutePosition
		local absSize = target.gui.AbsoluteSize
		local expansion = target.customExpansion or FAT_FINGER_EXPANSION_PX

		-- Calculate expanded AABB
		local minX = absPos.X - expansion
		local maxX = absPos.X + absSize.X + expansion
		local minY = absPos.Y - expansion
		local maxY = absPos.Y + absSize.Y + expansion

		if screenPosition.X >= minX and screenPosition.X <= maxX and screenPosition.Y >= minY and screenPosition.Y <= maxY then
			-- Calculate Euclidean distance to element center
			local center = absPos + (absSize * 0.5)
			local dist = (screenPosition - center).Magnitude
			local score = dist - (target.priority * 20) -- Higher priority shifts score favorable

			if score < bestScore then
				bestScore = score
				bestTarget = target
			end
		end
	end

	if bestTarget then
		task.spawn(bestTarget.callback)
		return true
	end
	return false
end

--[=[
	Register a UI element for fat-finger touch assist.
]=]
function TouchGestureService.RegisterTouchTarget(id: string, gui: GuiObject, callback: () -> (), priority: number?, customExpansion: number?)
	for idx, t in registeredTargets do
		if t.id == id then
			registeredTargets[idx] = {
				id = id,
				gui = gui,
				priority = priority or 1,
				callback = callback,
				customExpansion = customExpansion,
			}
			return
		end
	end

	table.insert(registeredTargets, {
		id = id,
		gui = gui,
		priority = priority or 1,
		callback = callback,
		customExpansion = customExpansion,
	})
end

function TouchGestureService.UnregisterTouchTarget(id: string)
	for idx, t in registeredTargets do
		if t.id == id then
			table.remove(registeredTargets, idx)
			break
		end
	end
end

function TouchGestureService.IsNearRegisteredTarget(position: Vector2): boolean
	for _, target in registeredTargets do
		if target.gui.Parent and isVisible(target.gui) and isPointUnclipped(target.gui, position) then
			local origin = target.gui.AbsolutePosition
			local size = target.gui.AbsoluteSize
			local margin = target.customExpansion or FAT_FINGER_EXPANSION_PX
			if position.X >= origin.X - margin and position.X <= origin.X + size.X + margin
				and position.Y >= origin.Y - margin and position.Y <= origin.Y + size.Y + margin then
				return true
			end
		end
	end
	return false
end

--[=[
	Calculates pinch metrics across two active touch points.
]=]
local function evaluatePinch(p1: TouchPointer, p2: TouchPointer)
	local curDist = (p1.currentPos - p2.currentPos).Magnitude
	local prevDist = (p1.previousPos - p2.previousPos).Magnitude
	if prevDist < PINCH_MIN_TOUCH_DIST then
		return
	end

	local scaleDelta = curDist / prevDist
	local center = (p1.currentPos + p2.currentPos) * 0.5

	local curVec = p1.currentPos - p2.currentPos
	local prevVec = p1.previousPos - p2.previousPos
	local curAngle = math.atan2(curVec.Y, curVec.X)
	local prevAngle = math.atan2(prevVec.Y, prevVec.X)
	local rotDelta = curAngle - prevAngle

	local pinchPayload: PinchData = {
		center = center,
		scaleDelta = scaleDelta,
		rotationDelta = rotDelta,
		distance = curDist,
	}
	emit("Pinch", pinchPayload)
end

--[=[
	Initializes input listeners for the multi-touch lifecycle.
]=]
function TouchGestureService.Init()
	if initialized or not UserInputService.TouchEnabled then
		return
	end
	initialized = true

	-- InputBegan
	local beganConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		pointerIdCounter += 1
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local now = os.clock()

		local pointer: TouchPointer = {
			id = pointerIdCounter,
			startPos = pos,
			currentPos = pos,
			previousPos = pos,
			velocity = Vector2.zero,
			startTime = now,
			lastUpdateTime = now,
			isConsumed = gameProcessed or isOnInteractiveGui(toGuiPosition(pos)),
		}
		activeTouches[input] = pointer

		-- Dynamic Virtual Thumbstick initialization:
		-- If touch originates in bottom-left quadrant (X < 45% screen width, Y > 50% screen height)
		-- and thumbstick is currently idle, anchor the joystick center dynamically right here!
		local cam = workspace.CurrentCamera
		local vSize = if cam then cam.ViewportSize else Vector2.new(1000, 800)
		if not pointer.isConsumed and not TouchGestureService.IsNearRegisteredTarget(toGuiPosition(pos)) and not thumbstickState.active and pos.X < (vSize.X * 0.45) and pos.Y > (vSize.Y * 0.50) then
			thumbstickTouch = input
			thumbstickState.active = true
			thumbstickState.origin = pos
			thumbstickState.current = pos
			thumbstickState.direction = Vector2.zero
			thumbstickState.magnitude = 0
			emit("ThumbstickMove", thumbstickState)
		end
	end)
	table.insert(inputConnections, beganConnection)

	-- InputChanged
	local changedConnection = UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pointer = activeTouches[input]
		if not pointer then
			return
		end

		local newPos = Vector2.new(input.Position.X, input.Position.Y)
		local now = os.clock()
		local dt = math.max(0.001, now - pointer.lastUpdateTime)

		pointer.velocity = (newPos - pointer.currentPos) / dt
		pointer.previousPos = pointer.currentPos
		pointer.currentPos = newPos
		pointer.lastUpdateTime = now

		-- Dynamic Virtual Thumbstick tracking
		if input == thumbstickTouch and thumbstickState.active then
			local delta = newPos - thumbstickState.origin
			local rawMag = delta.Magnitude
			local clampedDist = math.min(rawMag, THUMBSTICK_RADIUS)
			local unitDir = if rawMag > 0.001 then (delta / rawMag) else Vector2.zero

			-- Apply deadzone filter
			local normalized = clampedDist / THUMBSTICK_RADIUS
			local filteredMag = 0
			if normalized > THUMBSTICK_DEADZONE then
				filteredMag = (normalized - THUMBSTICK_DEADZONE) / (1 - THUMBSTICK_DEADZONE)
			end

			thumbstickState.current = thumbstickState.origin + (unitDir * clampedDist)
			thumbstickState.direction = unitDir
			thumbstickState.magnitude = filteredMag
			emit("ThumbstickMove", thumbstickState)
		end

		-- Multi-touch gesture processing: Two-finger pinch
		local touches = {}
		for touchInput, ptr in activeTouches do
			if not ptr.isConsumed and touchInput ~= thumbstickTouch then
				table.insert(touches, ptr)
			end
		end
		if #touches == 2 then
			evaluatePinch(touches[1], touches[2])
		end
	end)
	table.insert(inputConnections, changedConnection)

	-- InputEnded
	local endedConnection = UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pointer = activeTouches[input]
		if not pointer then
			return
		end

		local now = os.clock()
		local duration = now - pointer.startTime
		local travel = (pointer.currentPos - pointer.startPos).Magnitude

		-- Thumbstick release
		local wasThumbstick = input == thumbstickTouch
		if wasThumbstick then
			thumbstickTouch = nil
			thumbstickState.active = false
			thumbstickState.direction = Vector2.zero
			thumbstickState.magnitude = 0
			emit("ThumbstickMove", thumbstickState)
		end

		-- Tap / Fat-finger assistance
		if not pointer.isConsumed and not wasThumbstick and duration <= TAP_MAX_DURATION and travel <= TAP_MAX_TRAVEL then
			local handled = TouchGestureService.ResolveFatFingerHit(toGuiPosition(pointer.currentPos))
			if not handled then
				emit("Tap", pointer.currentPos)
			end
		-- Swipe analysis
		elseif not pointer.isConsumed and not wasThumbstick and travel >= MIN_SWIPE_DISTANCE then
			local dir = (pointer.currentPos - pointer.startPos).Unit
			local speed = pointer.velocity.Magnitude
			local isFlick = speed >= FLICK_VELOCITY_THRESHOLD

			local swipe: SwipeData = {
				direction = dir,
				distance = travel,
				velocity = pointer.velocity,
				isFlick = isFlick,
			}
			emit("Swipe", swipe)
		end

		activeTouches[input] = nil
	end)
	table.insert(inputConnections, endedConnection)
end

function TouchGestureService.Stop()
	for _, connection in inputConnections do
		connection:Disconnect()
	end
	table.clear(inputConnections)
	table.clear(activeTouches)
	table.clear(registeredTargets)
	thumbstickTouch = nil
	thumbstickState.active = false
	thumbstickState.direction = Vector2.zero
	thumbstickState.magnitude = 0
	initialized = false
end

--[=[
	Subscribes to gesture events.
]=]
function TouchGestureService.On(event: GestureEvent, callback: (any) -> ()): () -> ()
	local list = listeners[event]
	if list then
		table.insert(list, callback)
		return function()
			local idx = table.find(list, callback)
			if idx then
				table.remove(list, idx)
			end
		end
	end
	return function() end
end

function TouchGestureService.GetThumbstickState(): ThumbstickData
	return thumbstickState
end

return TouchGestureService
