-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local UserInputService = TS.import(script, TS.getModule(script, "@rbxts", "services")).UserInputService
local InputEnums = TS.import(script, script.Parent, "enums", "enums").InputEnums
local getMouseDelta = TS.import(script, script.Parent, "util", "mouse-utils").getMouseDelta
local toVec3 = TS.import(script, script.Parent, "util", "vector-utils").toVec3
local function mouseButton(input)
	input.delta = Vector3.zero
	input.position = Vector3.zero
	return input
end
local function mouseWheel(input)
	input.delta = Vector3.new(0, 0, input.position.Z)
	input.position = Vector3.zero
	return input
end
local function mouseMovement(input)
	input.position = toVec3(UserInputService:GetMouseLocation())
	input.delta = toVec3(getMouseDelta())
	return input
end
local function keyboardKey(input)
	input.position = Vector3.zero
	input.delta = Vector3.zero
	return input
end
local function gamepadButton(input)
	input.position = Vector3.zero
	input.delta = Vector3.zero
	return input
end
local function gamepadTrigger(input)
	if input.state == InputEnums.State.Change then
		input.position = Vector3.new(0, 0, input.position.Z)
		input.delta = Vector3.new(0, 0, input.delta.Z)
	else
		input.position = Vector3.zero
		input.delta = Vector3.zero
	end
	return input
end
local function gamepadThumbstick(input)
	if input.state == InputEnums.State.Change then
		input.position = toVec3(input.position)
		input.delta = toVec3(input.delta)
	else
		input.position = Vector3.zero
		input.delta = Vector3.zero
	end
	return input
end
--[[
	*
	 * Rules for input transformers:
	 *
	 * 1. Do not include input data not immediately relevant to the input.
	 * (example: mouse position included on all keyboard presses and mouse inputs)
	 * 2. Do not include duplicate data in the input
	 * (example: key press delta being 1 or -1 when the userInputState is already sufficient)
	 * 3. single number position/delta values should always go in the Z component
	 
]]
local transformers = {
	[InputEnums.KeyCode.MouseButton1] = mouseButton,
	[InputEnums.KeyCode.MouseButton2] = mouseButton,
	[InputEnums.KeyCode.MouseButton3] = mouseButton,
	[InputEnums.KeyCode.MouseWheel] = mouseWheel,
	[InputEnums.KeyCode.MouseMovement] = mouseMovement,
	[InputEnums.KeyCode.Backspace] = keyboardKey,
	[InputEnums.KeyCode.Tab] = keyboardKey,
	[InputEnums.KeyCode.Clear] = keyboardKey,
	[InputEnums.KeyCode.Return] = keyboardKey,
	[InputEnums.KeyCode.Pause] = keyboardKey,
	[InputEnums.KeyCode.Escape] = keyboardKey,
	[InputEnums.KeyCode.Space] = keyboardKey,
	[InputEnums.KeyCode.QuotedDouble] = keyboardKey,
	[InputEnums.KeyCode.Hash] = keyboardKey,
	[InputEnums.KeyCode.Dollar] = keyboardKey,
	[InputEnums.KeyCode.Percent] = keyboardKey,
	[InputEnums.KeyCode.Ampersand] = keyboardKey,
	[InputEnums.KeyCode.Quote] = keyboardKey,
	[InputEnums.KeyCode.LeftParenthesis] = keyboardKey,
	[InputEnums.KeyCode.RightParenthesis] = keyboardKey,
	[InputEnums.KeyCode.Asterisk] = keyboardKey,
	[InputEnums.KeyCode.Plus] = keyboardKey,
	[InputEnums.KeyCode.Comma] = keyboardKey,
	[InputEnums.KeyCode.Minus] = keyboardKey,
	[InputEnums.KeyCode.Period] = keyboardKey,
	[InputEnums.KeyCode.Slash] = keyboardKey,
	[InputEnums.KeyCode.Zero] = keyboardKey,
	[InputEnums.KeyCode.One] = keyboardKey,
	[InputEnums.KeyCode.Two] = keyboardKey,
	[InputEnums.KeyCode.Three] = keyboardKey,
	[InputEnums.KeyCode.Four] = keyboardKey,
	[InputEnums.KeyCode.Five] = keyboardKey,
	[InputEnums.KeyCode.Six] = keyboardKey,
	[InputEnums.KeyCode.Seven] = keyboardKey,
	[InputEnums.KeyCode.Eight] = keyboardKey,
	[InputEnums.KeyCode.Nine] = keyboardKey,
	[InputEnums.KeyCode.Colon] = keyboardKey,
	[InputEnums.KeyCode.Semicolon] = keyboardKey,
	[InputEnums.KeyCode.LessThan] = keyboardKey,
	[InputEnums.KeyCode.Equals] = keyboardKey,
	[InputEnums.KeyCode.GreaterThan] = keyboardKey,
	[InputEnums.KeyCode.Question] = keyboardKey,
	[InputEnums.KeyCode.At] = keyboardKey,
	[InputEnums.KeyCode.LeftBracket] = keyboardKey,
	[InputEnums.KeyCode.BackSlash] = keyboardKey,
	[InputEnums.KeyCode.RightBracket] = keyboardKey,
	[InputEnums.KeyCode.Caret] = keyboardKey,
	[InputEnums.KeyCode.Underscore] = keyboardKey,
	[InputEnums.KeyCode.Backquote] = keyboardKey,
	[InputEnums.KeyCode.A] = keyboardKey,
	[InputEnums.KeyCode.B] = keyboardKey,
	[InputEnums.KeyCode.C] = keyboardKey,
	[InputEnums.KeyCode.D] = keyboardKey,
	[InputEnums.KeyCode.E] = keyboardKey,
	[InputEnums.KeyCode.F] = keyboardKey,
	[InputEnums.KeyCode.G] = keyboardKey,
	[InputEnums.KeyCode.H] = keyboardKey,
	[InputEnums.KeyCode.I] = keyboardKey,
	[InputEnums.KeyCode.J] = keyboardKey,
	[InputEnums.KeyCode.K] = keyboardKey,
	[InputEnums.KeyCode.L] = keyboardKey,
	[InputEnums.KeyCode.M] = keyboardKey,
	[InputEnums.KeyCode.N] = keyboardKey,
	[InputEnums.KeyCode.O] = keyboardKey,
	[InputEnums.KeyCode.P] = keyboardKey,
	[InputEnums.KeyCode.Q] = keyboardKey,
	[InputEnums.KeyCode.R] = keyboardKey,
	[InputEnums.KeyCode.S] = keyboardKey,
	[InputEnums.KeyCode.T] = keyboardKey,
	[InputEnums.KeyCode.U] = keyboardKey,
	[InputEnums.KeyCode.V] = keyboardKey,
	[InputEnums.KeyCode.W] = keyboardKey,
	[InputEnums.KeyCode.X] = keyboardKey,
	[InputEnums.KeyCode.Y] = keyboardKey,
	[InputEnums.KeyCode.Z] = keyboardKey,
	[InputEnums.KeyCode.LeftCurly] = keyboardKey,
	[InputEnums.KeyCode.Pipe] = keyboardKey,
	[InputEnums.KeyCode.RightCurly] = keyboardKey,
	[InputEnums.KeyCode.Tilde] = keyboardKey,
	[InputEnums.KeyCode.Delete] = keyboardKey,
	[InputEnums.KeyCode.World0] = keyboardKey,
	[InputEnums.KeyCode.World1] = keyboardKey,
	[InputEnums.KeyCode.World2] = keyboardKey,
	[InputEnums.KeyCode.World3] = keyboardKey,
	[InputEnums.KeyCode.World4] = keyboardKey,
	[InputEnums.KeyCode.World5] = keyboardKey,
	[InputEnums.KeyCode.World6] = keyboardKey,
	[InputEnums.KeyCode.World7] = keyboardKey,
	[InputEnums.KeyCode.World8] = keyboardKey,
	[InputEnums.KeyCode.World9] = keyboardKey,
	[InputEnums.KeyCode.World10] = keyboardKey,
	[InputEnums.KeyCode.World11] = keyboardKey,
	[InputEnums.KeyCode.World12] = keyboardKey,
	[InputEnums.KeyCode.World13] = keyboardKey,
	[InputEnums.KeyCode.World14] = keyboardKey,
	[InputEnums.KeyCode.World15] = keyboardKey,
	[InputEnums.KeyCode.World16] = keyboardKey,
	[InputEnums.KeyCode.World17] = keyboardKey,
	[InputEnums.KeyCode.World18] = keyboardKey,
	[InputEnums.KeyCode.World19] = keyboardKey,
	[InputEnums.KeyCode.World20] = keyboardKey,
	[InputEnums.KeyCode.World21] = keyboardKey,
	[InputEnums.KeyCode.World22] = keyboardKey,
	[InputEnums.KeyCode.World23] = keyboardKey,
	[InputEnums.KeyCode.World24] = keyboardKey,
	[InputEnums.KeyCode.World25] = keyboardKey,
	[InputEnums.KeyCode.World26] = keyboardKey,
	[InputEnums.KeyCode.World27] = keyboardKey,
	[InputEnums.KeyCode.World28] = keyboardKey,
	[InputEnums.KeyCode.World29] = keyboardKey,
	[InputEnums.KeyCode.World30] = keyboardKey,
	[InputEnums.KeyCode.World31] = keyboardKey,
	[InputEnums.KeyCode.World32] = keyboardKey,
	[InputEnums.KeyCode.World33] = keyboardKey,
	[InputEnums.KeyCode.World34] = keyboardKey,
	[InputEnums.KeyCode.World35] = keyboardKey,
	[InputEnums.KeyCode.World36] = keyboardKey,
	[InputEnums.KeyCode.World37] = keyboardKey,
	[InputEnums.KeyCode.World38] = keyboardKey,
	[InputEnums.KeyCode.World39] = keyboardKey,
	[InputEnums.KeyCode.World40] = keyboardKey,
	[InputEnums.KeyCode.World41] = keyboardKey,
	[InputEnums.KeyCode.World42] = keyboardKey,
	[InputEnums.KeyCode.World43] = keyboardKey,
	[InputEnums.KeyCode.World44] = keyboardKey,
	[InputEnums.KeyCode.World45] = keyboardKey,
	[InputEnums.KeyCode.World46] = keyboardKey,
	[InputEnums.KeyCode.World47] = keyboardKey,
	[InputEnums.KeyCode.World48] = keyboardKey,
	[InputEnums.KeyCode.World49] = keyboardKey,
	[InputEnums.KeyCode.World50] = keyboardKey,
	[InputEnums.KeyCode.World51] = keyboardKey,
	[InputEnums.KeyCode.World52] = keyboardKey,
	[InputEnums.KeyCode.World53] = keyboardKey,
	[InputEnums.KeyCode.World54] = keyboardKey,
	[InputEnums.KeyCode.World55] = keyboardKey,
	[InputEnums.KeyCode.World56] = keyboardKey,
	[InputEnums.KeyCode.World57] = keyboardKey,
	[InputEnums.KeyCode.World58] = keyboardKey,
	[InputEnums.KeyCode.World59] = keyboardKey,
	[InputEnums.KeyCode.World60] = keyboardKey,
	[InputEnums.KeyCode.World61] = keyboardKey,
	[InputEnums.KeyCode.World62] = keyboardKey,
	[InputEnums.KeyCode.World63] = keyboardKey,
	[InputEnums.KeyCode.World64] = keyboardKey,
	[InputEnums.KeyCode.World65] = keyboardKey,
	[InputEnums.KeyCode.World66] = keyboardKey,
	[InputEnums.KeyCode.World67] = keyboardKey,
	[InputEnums.KeyCode.World68] = keyboardKey,
	[InputEnums.KeyCode.World69] = keyboardKey,
	[InputEnums.KeyCode.World70] = keyboardKey,
	[InputEnums.KeyCode.World71] = keyboardKey,
	[InputEnums.KeyCode.World72] = keyboardKey,
	[InputEnums.KeyCode.World73] = keyboardKey,
	[InputEnums.KeyCode.World74] = keyboardKey,
	[InputEnums.KeyCode.World75] = keyboardKey,
	[InputEnums.KeyCode.World76] = keyboardKey,
	[InputEnums.KeyCode.World77] = keyboardKey,
	[InputEnums.KeyCode.World78] = keyboardKey,
	[InputEnums.KeyCode.World79] = keyboardKey,
	[InputEnums.KeyCode.World80] = keyboardKey,
	[InputEnums.KeyCode.World81] = keyboardKey,
	[InputEnums.KeyCode.World82] = keyboardKey,
	[InputEnums.KeyCode.World83] = keyboardKey,
	[InputEnums.KeyCode.World84] = keyboardKey,
	[InputEnums.KeyCode.World85] = keyboardKey,
	[InputEnums.KeyCode.World86] = keyboardKey,
	[InputEnums.KeyCode.World87] = keyboardKey,
	[InputEnums.KeyCode.World88] = keyboardKey,
	[InputEnums.KeyCode.World89] = keyboardKey,
	[InputEnums.KeyCode.World90] = keyboardKey,
	[InputEnums.KeyCode.World91] = keyboardKey,
	[InputEnums.KeyCode.World92] = keyboardKey,
	[InputEnums.KeyCode.World93] = keyboardKey,
	[InputEnums.KeyCode.World94] = keyboardKey,
	[InputEnums.KeyCode.World95] = keyboardKey,
	[InputEnums.KeyCode.KeypadZero] = keyboardKey,
	[InputEnums.KeyCode.KeypadOne] = keyboardKey,
	[InputEnums.KeyCode.KeypadTwo] = keyboardKey,
	[InputEnums.KeyCode.KeypadThree] = keyboardKey,
	[InputEnums.KeyCode.KeypadFour] = keyboardKey,
	[InputEnums.KeyCode.KeypadFive] = keyboardKey,
	[InputEnums.KeyCode.KeypadSix] = keyboardKey,
	[InputEnums.KeyCode.KeypadSeven] = keyboardKey,
	[InputEnums.KeyCode.KeypadEight] = keyboardKey,
	[InputEnums.KeyCode.KeypadNine] = keyboardKey,
	[InputEnums.KeyCode.KeypadPeriod] = keyboardKey,
	[InputEnums.KeyCode.KeypadDivide] = keyboardKey,
	[InputEnums.KeyCode.KeypadMultiply] = keyboardKey,
	[InputEnums.KeyCode.KeypadMinus] = keyboardKey,
	[InputEnums.KeyCode.KeypadPlus] = keyboardKey,
	[InputEnums.KeyCode.KeypadEnter] = keyboardKey,
	[InputEnums.KeyCode.KeypadEquals] = keyboardKey,
	[InputEnums.KeyCode.Up] = keyboardKey,
	[InputEnums.KeyCode.Down] = keyboardKey,
	[InputEnums.KeyCode.Right] = keyboardKey,
	[InputEnums.KeyCode.Left] = keyboardKey,
	[InputEnums.KeyCode.Insert] = keyboardKey,
	[InputEnums.KeyCode.Home] = keyboardKey,
	[InputEnums.KeyCode.End] = keyboardKey,
	[InputEnums.KeyCode.PageUp] = keyboardKey,
	[InputEnums.KeyCode.PageDown] = keyboardKey,
	[InputEnums.KeyCode.F1] = keyboardKey,
	[InputEnums.KeyCode.F2] = keyboardKey,
	[InputEnums.KeyCode.F3] = keyboardKey,
	[InputEnums.KeyCode.F4] = keyboardKey,
	[InputEnums.KeyCode.F5] = keyboardKey,
	[InputEnums.KeyCode.F6] = keyboardKey,
	[InputEnums.KeyCode.F7] = keyboardKey,
	[InputEnums.KeyCode.F8] = keyboardKey,
	[InputEnums.KeyCode.F9] = keyboardKey,
	[InputEnums.KeyCode.F10] = keyboardKey,
	[InputEnums.KeyCode.F11] = keyboardKey,
	[InputEnums.KeyCode.F12] = keyboardKey,
	[InputEnums.KeyCode.F13] = keyboardKey,
	[InputEnums.KeyCode.F14] = keyboardKey,
	[InputEnums.KeyCode.F15] = keyboardKey,
	[InputEnums.KeyCode.NumLock] = keyboardKey,
	[InputEnums.KeyCode.CapsLock] = keyboardKey,
	[InputEnums.KeyCode.ScrollLock] = keyboardKey,
	[InputEnums.KeyCode.RightShift] = keyboardKey,
	[InputEnums.KeyCode.LeftShift] = keyboardKey,
	[InputEnums.KeyCode.RightControl] = keyboardKey,
	[InputEnums.KeyCode.LeftControl] = keyboardKey,
	[InputEnums.KeyCode.RightAlt] = keyboardKey,
	[InputEnums.KeyCode.LeftAlt] = keyboardKey,
	[InputEnums.KeyCode.RightMeta] = keyboardKey,
	[InputEnums.KeyCode.LeftMeta] = keyboardKey,
	[InputEnums.KeyCode.LeftSuper] = keyboardKey,
	[InputEnums.KeyCode.RightSuper] = keyboardKey,
	[InputEnums.KeyCode.Mode] = keyboardKey,
	[InputEnums.KeyCode.Compose] = keyboardKey,
	[InputEnums.KeyCode.Help] = keyboardKey,
	[InputEnums.KeyCode.Print] = keyboardKey,
	[InputEnums.KeyCode.SysReq] = keyboardKey,
	[InputEnums.KeyCode.Break] = keyboardKey,
	[InputEnums.KeyCode.Menu] = keyboardKey,
	[InputEnums.KeyCode.Power] = keyboardKey,
	[InputEnums.KeyCode.Euro] = keyboardKey,
	[InputEnums.KeyCode.Undo] = keyboardKey,
	[InputEnums.KeyCode.ButtonX] = gamepadButton,
	[InputEnums.KeyCode.ButtonY] = gamepadButton,
	[InputEnums.KeyCode.ButtonA] = gamepadButton,
	[InputEnums.KeyCode.ButtonB] = gamepadButton,
	[InputEnums.KeyCode.ButtonR1] = gamepadButton,
	[InputEnums.KeyCode.ButtonL1] = gamepadButton,
	[InputEnums.KeyCode.ButtonR2] = gamepadTrigger,
	[InputEnums.KeyCode.ButtonL2] = gamepadTrigger,
	[InputEnums.KeyCode.ButtonR3] = gamepadButton,
	[InputEnums.KeyCode.ButtonL3] = gamepadButton,
	[InputEnums.KeyCode.ButtonStart] = gamepadButton,
	[InputEnums.KeyCode.ButtonSelect] = gamepadButton,
	[InputEnums.KeyCode.DPadLeft] = gamepadButton,
	[InputEnums.KeyCode.DPadRight] = gamepadButton,
	[InputEnums.KeyCode.DPadUp] = gamepadButton,
	[InputEnums.KeyCode.DPadDown] = gamepadButton,
	[InputEnums.KeyCode.Thumbstick1] = gamepadThumbstick,
	[InputEnums.KeyCode.Thumbstick2] = gamepadThumbstick,
}
local transformerMap = {}
for k, v in pairs(transformers) do
	transformerMap[k] = v
end
return {
	transformers = transformers,
	transformerMap = transformerMap,
}
