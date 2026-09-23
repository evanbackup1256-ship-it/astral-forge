-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local bindingController = TS.import(script, script, "lib", "bindings", "binding-controller").bindingController
local InputEnums = TS.import(script, script, "lib", "enums", "enums").InputEnums
local inputMethodController = TS.import(script, script, "lib", "input-mapping", "input-method").inputMethodController
local Input = {}
do
	local _container = Input
	--* @hidden 
	local MethodController = inputMethodController
	_container.MethodController = MethodController
	--* @hidden 
	local BindingController = bindingController
	_container.BindingController = BindingController
	local setMethodMode = function(mode)
		return inputMethodController:setInputMethodMode(mode)
	end
	_container.setMethodMode = setMethodMode
	local setMethods = function(methods)
		return inputMethodController:setInputMethods(methods)
	end
	_container.setMethods = setMethods
end
--[[
	*
	 * Input Methods are modes of operation, essentially sets of Input Types that
	 * can be used together.
	 
]]
local InputMethod = InputEnums.Method
--[[
	*
	 * @enum Type
	 * 3A's custom input types. Events associated with these input types come with additional
	 * middleware, as this enum class is meant to serve as a more friendly and standardized
	 * version of the available input schemes on Roblox.
	 
]]
local InputType = InputEnums.Type
--[[
	*
	 * A 3A contained reference to Enum.UserInputState.
	 
]]
local InputState = InputEnums.State
--[[
	*
	 * A 3A specific list of KeyCodes.
	 *
	 * This is not identical to Enum.KeyCode, it has remapped some of the
	 * UserInputType values to be keycodes, to be more consistent with
	 * what a keycode should represent.
	 *
	 * Common examples of remapped items include:
	 * ```
	 * Enum.UserInputType.MouseButton1
	 * Enum.UserInputType.Focus
	 * Enum.UserInputType.Accelerometer
	 * ```
	 * As well as a few others
	 *
	 
]]
local KeyCode = InputEnums.KeyCode
return {
	Input = Input,
	InputMethod = InputMethod,
	InputType = InputType,
	InputState = InputState,
	KeyCode = KeyCode,
}
