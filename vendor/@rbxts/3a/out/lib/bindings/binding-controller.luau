-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local RenderFirst = TS.import(script, script.Parent.Parent, "util", "render-first").RenderFirst
local BindingController
do
	BindingController = setmetatable({}, {
		__tostring = function()
			return "BindingController"
		end,
	})
	BindingController.__index = BindingController
	function BindingController.new(...)
		local self = setmetatable({}, BindingController)
		return self:constructor(...) or self
	end
	function BindingController:constructor()
		self.bindings = {}
		RenderFirst.bindAt(0, function()
			local _bindings = self.bindings
			local _arg0 = function(b)
				b.receivedInput = false
				return b.receivedInput
			end
			for _k, _v in _bindings do
				_arg0(_v, _k - 1, _bindings)
			end
		end)
	end
	function BindingController:addBinding(binding)
		local _bindings = self.bindings
		local _binding = binding
		table.insert(_bindings, _binding)
	end
end
local bindingController = BindingController.new()
return {
	BindingController = BindingController,
	bindingController = bindingController,
}
