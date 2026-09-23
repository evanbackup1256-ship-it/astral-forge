local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local hapticIntensity = 1
local motorGenerations = {}
-- HapticService only ever addresses gamepads. GetLastInputType returns Touch on a phone and
-- Keyboard/MouseButton1 on a desktop, and none of those are vibration targets — so routing
-- feedback through "whatever was last pressed" meant every haptic call died in a pcall, including
-- for players holding a controller on mobile. Resolve an actually-connected gamepad instead.
local GAMEPAD_INPUTS = { Enum.UserInputType.Gamepad1, Enum.UserInputType.Gamepad2, Enum.UserInputType.Gamepad3, Enum.UserInputType.Gamepad4 }
-- IsVibrationSupported is a round trip per call and the answer only changes when a controller is
-- plugged in or out, so cache it and drop the cache on those events.
-- Cache the actual usable motor set, not a single boolean. A controller's dual-motor rumble
-- (the classic Xbox-style Small/Large pair) doesn't guarantee both motors report supported on
-- every platform — hard-requiring one specific motor risks silently disabling haptics on
-- hardware that can vibrate through the other one. Drive whichever motors are actually there.
local RUMBLE_MOTORS = { Enum.VibrationMotor.Small, Enum.VibrationMotor.Large }
local vibrationSupport = {}
local function isGamepadInput(input)
	for _, candidate in GAMEPAD_INPUTS do
		if candidate == input then
			return true
		end
	end
	return false
end
local gamepadWatchInstalled = false
local function watchGamepads()
	if gamepadWatchInstalled then
		return nil
	end
	gamepadWatchInstalled = true
	UserInputService.GamepadConnected:Connect(function(pad)
		local _pad = pad
		-- ▼ Map.delete ▼
		local _valueExisted = vibrationSupport[_pad] ~= nil
		vibrationSupport[_pad] = nil
		-- ▲ Map.delete ▲
		return _valueExisted
	end)
	UserInputService.GamepadDisconnected:Connect(function(pad)
		local _pad = pad
		vibrationSupport[_pad] = nil
		local _pad_1 = pad
		motorGenerations[_pad_1] = nil
	end)
end
local function motorsFor(input)
	local _input = input
	local cached = vibrationSupport[_input]
	if cached ~= nil then
		return cached
	end
	watchGamepads()
	local vibrationOk, vibrationSupported = pcall(function()
		return HapticService:IsVibrationSupported(input)
	end)
	local resolved = {}
	if vibrationOk and vibrationSupported == true then
		local usable = {}
		for _, motor in RUMBLE_MOTORS do
			local motorOk, motorSupported = pcall(function()
				return HapticService:IsMotorSupported(input, motor)
			end)
			if motorOk and motorSupported == true then
				table.insert(usable, motor)
			end
		end
		resolved = usable
	end
	local _input_1 = input
	local _resolved = resolved
	vibrationSupport[_input_1] = _resolved
	return resolved
end
local function supportsVibration(input)
	return #motorsFor(input) > 0
end
-- The gamepad that should receive feedback: the one the player last actually used when that is a
-- gamepad, otherwise the first connected pad that can vibrate. Undefined means "no haptics here",
-- which is the normal answer on a bare touchscreen.
local function hapticTarget()
	local last = UserInputService:GetLastInputType()
	if isGamepadInput(last) then
		return if supportsVibration(last) then last else nil
	end
	-- Only pay for the connected-gamepad scan when a pad is actually attached — on a plain phone
	-- or a mouse-and-keyboard desktop this short-circuits before any service round trip.
	if not UserInputService.GamepadEnabled then
		return nil
	end
	local ok, connected = pcall(function()
		return UserInputService:GetConnectedGamepads()
	end)
	if not ok or connected == nil then
		return nil
	end
	for _, pad in connected do
		if supportsVibration(pad) then
			return pad
		end
	end
	return nil
end
local function setHapticIntensity(value)
	hapticIntensity = math.clamp(value, 0, 1)
	if hapticIntensity <= 0.02 then
		for input in motorGenerations do
			for _, motor in motorsFor(input) do
				pcall(function()
					return HapticService:SetMotor(input, motor, 0)
				end)
			end
		end
		table.clear(motorGenerations)
	end
end
local function safePulse(input, strength, seconds)
	if hapticIntensity <= 0.02 then
		return nil
	end
	local motors = motorsFor(input)
	if #motors == 0 then
		return nil
	end
	local level = math.clamp(strength * hapticIntensity, 0, 1)
	local startedAny = false
	for _, motor in motors do
		local startOk = pcall(function()
			return HapticService:SetMotor(input, motor, level)
		end)
		if startOk then
			startedAny = true
		end
	end
	if not startedAny then
		return nil
	end
	local _input = input
	local _condition = motorGenerations[_input]
	if _condition == nil then
		_condition = 0
	end
	local generation = _condition + 1
	local _input_1 = input
	motorGenerations[_input_1] = generation
	task.delay(math.max(0.01, seconds), function()
		local _input_2 = input
		if motorGenerations[_input_2] ~= generation then
			return nil
		end
		local _input_3 = input
		motorGenerations[_input_3] = nil
		for _, motor in motors do
			pcall(function()
				return HapticService:SetMotor(input, motor, 0)
			end)
		end
	end)
end
local function pulse(strength, seconds)
	if hapticIntensity <= 0.02 then
		return nil
	end
	local input = hapticTarget()
	if input == nil then
		return nil
	end
	task.defer(function()
		return safePulse(input, strength, seconds)
	end)
end
local lastDesktopResult = nil
local function usesDesktopStructure(width, height)
	local hasPointerHardware = UserInputService.KeyboardEnabled or UserInputService.MouseEnabled
	local preferred = UserInputService.PreferredInput
	local touch = UserInputService.TouchEnabled

	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local screenWidth = if width ~= nil then width else viewport.X
	local screenHeight = if height ~= nil then height else viewport.Y

	-- Strict physical screen boundary: anything under 840px wide or 500px tall cannot fit a desktop sidebar
	local result = false
	if screenWidth >= 840 and screenHeight >= 500 then
		if not touch then
			if preferred == Enum.PreferredInput.KeyboardAndMouse then
				result = true
			elseif preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
				result = true
			else
				result = hasPointerHardware
			end
		else
			if preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
				result = true
			else
				result = screenWidth >= 1100 and screenHeight >= 650
			end
		end
	end

	-- Hysteresis: avoid flipping the entire UI when the window hovers near the boundary.
	if lastDesktopResult ~= nil and result ~= lastDesktopResult then
		if lastDesktopResult then
			-- currently desktop -> mobile; require a bigger drop to switch
			if screenWidth < 780 or screenHeight < 470 then
				lastDesktopResult = false
			else
				return lastDesktopResult
			end
		else
			-- currently mobile -> desktop; require a clear jump to switch
			if screenWidth >= 840 and screenHeight >= 500 then
				lastDesktopResult = true
			else
				return lastDesktopResult
			end
		end
	end
	lastDesktopResult = result
	return result
end
local function isTouchDevice()
	return UserInputService.TouchEnabled and not usesDesktopStructure()
end
local function isGamepadDevice()
	local preferred = UserInputService.PreferredInput
	return preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
end
local InteractionFeedback = {
	tap = function()
		return pulse(0.22, 0.045)
	end,
	tick = function()
		return pulse(0.1, 0.025)
	end,
	reward = function()
		return pulse(0.5, 0.11)
	end,
	confirm = function()
		return pulse(0.32, 0.06)
	end,
}
return {
	setHapticIntensity = setHapticIntensity,
	usesDesktopStructure = usesDesktopStructure,
	isTouchDevice = isTouchDevice,
	isGamepadDevice = isGamepadDevice,
	InteractionFeedback = InteractionFeedback,
}
