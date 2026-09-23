-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local inputMethodController = TS.import(script, script.Parent, "input-method").inputMethodController
local InputMethodMap
do
	InputMethodMap = setmetatable({}, {
		__tostring = function()
			return "InputMethodMap"
		end,
	})
	InputMethodMap.__index = InputMethodMap
	function InputMethodMap.new(...)
		local self = setmetatable({}, InputMethodMap)
		return self:constructor(...) or self
	end
	function InputMethodMap:constructor(method, map)
		self.method = method
		self.map = map
		local _map = map
		local _arg0 = function(kcList, action)
			local _kcList = kcList
			local _arg0_1 = function(kc)
				return action:addKey(kc)
			end
			for _k, _v in _kcList do
				_arg0_1(_v, _k - 1, _kcList)
			end
			return nil
		end
		for _k, _v in _map do
			_arg0(_v, _k, _map)
		end
		inputMethodController:addMethodMap(self)
	end
end
return {
	InputMethodMap = InputMethodMap,
}
