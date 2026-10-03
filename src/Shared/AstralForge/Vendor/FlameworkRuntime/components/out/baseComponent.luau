local TS = _G[script]
local Signal = TS.import(script, TS.getModule(script, "@rbxts", "signal"))

local SYMBOL_ATTRIBUTE_HANDLERS = {}

local SYMBOL_ATTRIBUTE_SETTER = {}

local BaseComponent
do
	BaseComponent = setmetatable({}, {
		__tostring = function()
			return "BaseComponent"
		end,
	})
	BaseComponent.__index = BaseComponent
	function BaseComponent.new(...)
		local self = setmetatable({}, BaseComponent)
		return self:constructor(...) or self
	end
	function BaseComponent:constructor()
		self[SYMBOL_ATTRIBUTE_HANDLERS] = {}
	end
	function BaseComponent:setInstance(component, instance, attributes)
		component.instance = instance
		component.attributes = attributes
	end
	BaseComponent[SYMBOL_ATTRIBUTE_SETTER] = function(self, key, value, postfix)
		local previousValue = (self.attributes)[key];
		(self.attributes)[key] = value
		self.instance:SetAttribute(key, value)
		return if postfix then previousValue else value
	end
	function BaseComponent:onAttributeChanged(name, cb)
		local _exp = self[SYMBOL_ATTRIBUTE_HANDLERS]
		local _name = name
		local list = _exp[_name]
		if not list then
			local _exp_1 = self[SYMBOL_ATTRIBUTE_HANDLERS]
			local _exp_2 = name
			list = Signal.new()
			local _list = list
			_exp_1[_exp_2] = _list
		end
		return list:Connect(cb)
	end
	function BaseComponent:destroy()
		for _, changeHandler in self[SYMBOL_ATTRIBUTE_HANDLERS] do
			changeHandler:Destroy()
		end
	end
end
return {
	SYMBOL_ATTRIBUTE_HANDLERS = SYMBOL_ATTRIBUTE_HANDLERS,
	SYMBOL_ATTRIBUTE_SETTER = SYMBOL_ATTRIBUTE_SETTER,
	BaseComponent = BaseComponent,
}
