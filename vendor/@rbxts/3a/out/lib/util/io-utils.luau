-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local RobloxKeyCode3AReverseMap = TS.import(script, script.Parent.Parent, "enums", "keycodes").RobloxKeyCode3AReverseMap
local RobloxInputMethod3AReverseMap = TS.import(script, script.Parent.Parent, "enums", "methods").RobloxInputMethod3AReverseMap
local RobloxInputType3AReverseMap = TS.import(script, script.Parent.Parent, "enums", "types").RobloxInputType3AReverseMap
local function methodFromInputObject(io)
	local _userInputType = io.UserInputType
	local inputType = RobloxInputType3AReverseMap[_userInputType]
	if inputType == nil then
		return nil
	end
	return RobloxInputMethod3AReverseMap[inputType]
end
local function typeFromInputObject(io)
	local _userInputType = io.UserInputType
	return RobloxInputType3AReverseMap[_userInputType]
end
local function keyCodeFromInputObject(io)
	local _keyCode = io.KeyCode
	local _condition = RobloxKeyCode3AReverseMap[_keyCode]
	if _condition == nil then
		local _userInputType = io.UserInputType
		_condition = RobloxKeyCode3AReverseMap[_userInputType]
	end
	return _condition
end
return {
	methodFromInputObject = methodFromInputObject,
	typeFromInputObject = typeFromInputObject,
	keyCodeFromInputObject = keyCodeFromInputObject,
}
