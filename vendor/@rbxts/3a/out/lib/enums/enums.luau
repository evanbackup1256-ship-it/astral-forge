-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local KeyCodes = TS.import(script, script.Parent, "keycodes").KeyCodes
local Methods = TS.import(script, script.Parent, "methods").Methods
local Types = TS.import(script, script.Parent, "types").Types
local InputEnums = {}
do
	local _container = InputEnums
	local BindingType
	do
		local _inverse = {}
		BindingType = setmetatable({}, {
			__index = _inverse,
		})
		BindingType.Action = 0
		_inverse[0] = "Action"
		BindingType.Axis = 1
		_inverse[1] = "Axis"
	end
	_container.BindingType = BindingType
	local Method = Methods
	_container.Method = Method
	local Type = Types
	_container.Type = Type
	local State = Enum.UserInputState
	_container.State = State
	local KeyCode = KeyCodes
	_container.KeyCode = KeyCode
end
return {
	InputEnums = InputEnums,
}
