-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local _services = TS.import(script, TS.getModule(script, "@rbxts", "services"))
local RunService = _services.RunService
local UserInputService = _services.UserInputService
local Signal = TS.import(script, TS.getModule(script, "@rbxts", "signal"))
local BindingInput = TS.import(script, script.Parent.Parent, "bindings", "binding-input").BindingInput
local InputEnums = TS.import(script, script.Parent.Parent, "enums", "enums").InputEnums
local RobloxInputMethod3AReverseMap = TS.import(script, script.Parent.Parent, "enums", "methods").RobloxInputMethod3AReverseMap
local RobloxInputType3AReverseMap = TS.import(script, script.Parent.Parent, "enums", "types").RobloxInputType3AReverseMap
local _io_utils = TS.import(script, script.Parent.Parent, "util", "io-utils")
local keyCodeFromInputObject = _io_utils.keyCodeFromInputObject
local methodFromInputObject = _io_utils.methodFromInputObject
local RenderFirst = TS.import(script, script.Parent.Parent, "util", "render-first").RenderFirst
local transformerMap = TS.import(script, script.Parent.Parent, "transformers").transformerMap
local InputMethodController
do
	InputMethodController = setmetatable({}, {
		__tostring = function()
			return "InputMethodController"
		end,
	})
	InputMethodController.__index = InputMethodController
	function InputMethodController.new(...)
		local self = setmetatable({}, InputMethodController)
		return self:constructor(...) or self
	end
	function InputMethodController:constructor()
		self.currentMethods = {}
		self.currentMode = 0
		self.queuedMethods = {}
		self.methodSelection = {}
		self.currentMethodLocked = false
		self.preferredList = {}
		self.preferredRegistered = false
		self.selectiveList = {}
		self.inputBuffer = {}
		self.methodMaps = {}
		self.inputMethodsChanged = Signal.new()
		UserInputService.InputBegan:Connect(function(i)
			return self:onInput(i)
		end)
		UserInputService.InputEnded:Connect(function(i)
			return self:onInput(i)
		end)
		UserInputService.InputChanged:Connect(function(i)
			return self:onInput(i)
		end)
		RunService.Heartbeat:Connect(function()
			self.currentMethodLocked = false
			self.preferredRegistered = false
		end)
		RenderFirst.bindAt(10, function()
			if not (#self.queuedMethods == 0) then
				table.clear(self.currentMethods)
				local temp = self.currentMethods
				self.currentMethods = self.queuedMethods
				self.queuedMethods = temp
			end
			self:broadcastInputs()
		end)
	end
	function InputMethodController:onInput(input)
		local _userInputType = input.UserInputType
		local inputType = RobloxInputType3AReverseMap[_userInputType]
		if inputType == nil then
			return nil
		end
		local inputMethod = RobloxInputMethod3AReverseMap[inputType]
		if inputMethod == nil then
			return nil
		end
		if self:updateInputMethod(inputMethod) then
			local _inputBuffer = self.inputBuffer
			local _input = input
			table.insert(_inputBuffer, _input)
		end
	end
	function InputMethodController:updateInputMethod(method)
		if self.currentMode == 0 then
			self:queueInputMethod(method)
		elseif self.currentMode == 1 then
			local _selectiveList = self.selectiveList
			local _method = method
			if not (table.find(_selectiveList, _method) ~= nil) then
				return false
			end
			self:queueInputMethod(method)
		elseif self.currentMode == 2 then
			local _currentMethods = self.currentMethods
			local _method = method
			if not (table.find(_currentMethods, _method) ~= nil) then
				return false
			end
		end
		return true
	end
	function InputMethodController:queueInputMethod(method)
		local _queuedMethods = self.queuedMethods
		local _method = method
		table.insert(_queuedMethods, _method)
	end
	function InputMethodController:setInputMethods(methods)
		self.currentMethods = methods
	end
	function InputMethodController:broadcastInputs()
		local _inputBuffer = self.inputBuffer
		local _arg0 = function(io)
			local method = methodFromInputObject(io)
			if method == nil then
				return nil
			end
			local input = BindingInput.new(io)
			local _keyCode = input.keyCode
			local transformer = transformerMap[_keyCode]
			if transformer ~= nil then
				input = transformer(input)
			end
			--[[
				*
							 * None method is a special case, it should be
							 * received in all circumstances, regardless of active method.
							 * This makes it more akin to an `any` method
							 
			]]
			if method == InputEnums.Method.None then
				local keyCode = keyCodeFromInputObject(io)
				if keyCode == nil then
					return nil
				end
				local _methodMaps = self.methodMaps
				local _arg0_1 = function(maps)
					local _maps = maps
					local _arg0_2 = function(_param)
						local map = _param.map
						local _arg0_3 = function(kcList, action)
							if not action:isActive() then
								return nil
							end
							if not (table.find(kcList, keyCode) ~= nil) then
								return nil
							end
							action:fireBindings(input)
						end
						for _k, _v in map do
							_arg0_3(_v, _k, map)
						end
					end
					for _k, _v in _maps do
						_arg0_2(_v, _k - 1, _maps)
					end
					return nil
				end
				for _k, _v in _methodMaps do
					_arg0_1(_v, _k, _methodMaps)
				end
				return nil
			end
			if not (table.find(self.currentMethods, method) ~= nil) then
				return nil
			end
			local maps = self.methodMaps[method]
			if maps == nil then
				return nil
			end
			local keyCode = keyCodeFromInputObject(io)
			if keyCode == nil then
				return nil
			end
			local _arg0_1 = function(_param)
				local map = _param.map
				local _arg0_2 = function(kcList, action)
					if not action:isActive() then
						return nil
					end
					if not (table.find(kcList, keyCode) ~= nil) then
						return nil
					end
					action:fireBindings(input)
				end
				for _k, _v in map do
					_arg0_2(_v, _k, map)
				end
			end
			for _k, _v in maps do
				_arg0_1(_v, _k - 1, maps)
			end
		end
		for _k, _v in _inputBuffer do
			_arg0(_v, _k - 1, _inputBuffer)
		end
		table.clear(self.inputBuffer)
	end
	function InputMethodController:addMethodMap(map)
		local _methodMaps = self.methodMaps
		local _method = map.method
		local maps = _methodMaps[_method]
		if maps == nil then
			maps = {}
			local _methodMaps_1 = self.methodMaps
			local _method_1 = map.method
			local _maps = maps
			_methodMaps_1[_method_1] = _maps
		end
		local _maps = maps
		local _map = map
		table.insert(_maps, _map)
	end
	function InputMethodController:setInputMethodMode(mode)
		self.currentMode = mode
	end
end
local inputMethodController = InputMethodController.new()
return {
	InputMethodController = InputMethodController,
	inputMethodController = inputMethodController,
}
