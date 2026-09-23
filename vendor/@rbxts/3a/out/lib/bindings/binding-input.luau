-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local InputEnums = TS.import(script, script.Parent.Parent, "enums", "enums").InputEnums
local _io_utils = TS.import(script, script.Parent.Parent, "util", "io-utils")
local keyCodeFromInputObject = _io_utils.keyCodeFromInputObject
local methodFromInputObject = _io_utils.methodFromInputObject
local typeFromInputObject = _io_utils.typeFromInputObject
local BindingInput
do
	BindingInput = setmetatable({}, {
		__tostring = function()
			return "BindingInput"
		end,
	})
	BindingInput.__index = BindingInput
	function BindingInput.new(...)
		local self = setmetatable({}, BindingInput)
		return self:constructor(...) or self
	end
	function BindingInput:constructor(io)
		local _condition = methodFromInputObject(io)
		if _condition == nil then
			_condition = InputEnums.Method.None
		end
		self.method = _condition
		local _condition_1 = typeFromInputObject(io)
		if _condition_1 == nil then
			_condition_1 = InputEnums.Type.None
		end
		self.type = _condition_1
		local _condition_2 = keyCodeFromInputObject(io)
		if _condition_2 == nil then
			_condition_2 = InputEnums.KeyCode.Unknown
		end
		self.keyCode = _condition_2
		self.state = io.UserInputState
		self.position = io.Position
		self.delta = io.Delta
	end
end
return {
	BindingInput = BindingInput,
}
