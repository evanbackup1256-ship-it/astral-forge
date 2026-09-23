-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local InputAction
do
	InputAction = setmetatable({}, {
		__tostring = function()
			return "InputAction"
		end,
	})
	InputAction.__index = InputAction
	function InputAction.new(...)
		local self = setmetatable({}, InputAction)
		return self:constructor(...) or self
	end
	function InputAction:constructor(name, keys)
		if keys == nil then
			keys = {}
		end
		self.name = name
		self.keys = keys
		self.active = false
		self.bindings = {}
	end
	function InputAction:addKey(key)
		local _keys = self.keys
		local _key = key
		table.insert(_keys, _key)
	end
	function InputAction:setActive(active)
		self.active = active
	end
	function InputAction:isActive()
		return self.active
	end
	function InputAction:bind(binding)
		local _bindings = self.bindings
		local _binding = binding
		table.insert(_bindings, _binding)
	end
	function InputAction:fireBindings(input)
		local _bindings = self.bindings
		local _arg0 = function(b)
			local _binding = b.config
			local receiveStates = _binding.receiveStates
			local dropDuplicates = _binding.dropDuplicates
			local transformers = _binding.transformers
			local _condition = receiveStates ~= nil
			if _condition then
				local _state = input.state
				_condition = not (table.find(receiveStates, _state) ~= nil)
			end
			if _condition then
				return nil
			end
			if dropDuplicates and b.receivedInput then
				return nil
			end
			if transformers ~= nil and transformers[input.keyCode] ~= nil then
				b:fire(transformers[input.keyCode](input))
			else
				b:fire(input)
			end
		end
		for _k, _v in _bindings do
			_arg0(_v, _k - 1, _bindings)
		end
	end
end
local function makeInputActionSet(enums)
	local out = {}
	for k, v in pairs(enums) do
		if not (type(k) == "string") then
			continue
		end
		out[k] = InputAction.new(k, {})
	end
	out.setActive = function(self, active)
		for k, v in pairs(out) do
			if TS.instanceof(v, InputAction) then
				v:setActive(active)
			end
		end
	end
	return out
end
return {
	makeInputActionSet = makeInputActionSet,
	InputAction = InputAction,
}
