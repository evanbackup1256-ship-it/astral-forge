-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local bindingController = TS.import(script, script.Parent, "binding-controller").bindingController
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
local BindingConnection
do
	BindingConnection = setmetatable({}, {
		__tostring = function()
			return "BindingConnection"
		end,
	})
	BindingConnection.__index = BindingConnection
	function BindingConnection.new(...)
		local self = setmetatable({}, BindingConnection)
		return self:constructor(...) or self
	end
	function BindingConnection:constructor(binding, callback)
		self.binding = binding
		self.callback = callback
		self.connected = false
	end
	function BindingConnection:disconnect()
		self.binding:disconnect(self)
	end
end
--* @hidden 
local InputBinding
do
	InputBinding = setmetatable({}, {
		__tostring = function()
			return "InputBinding"
		end,
	})
	InputBinding.__index = InputBinding
	function InputBinding.new(...)
		local self = setmetatable({}, InputBinding)
		return self:constructor(...) or self
	end
	function InputBinding:constructor(action, config)
		if config == nil then
			config = {}
		end
		self.action = action
		self.config = config
		self.inputBuffer = {}
		self.connections = {}
		self.receivedInput = false
		action:bind(self)
		bindingController:addBinding(self)
	end
	function InputBinding:connect(callback)
		local con = BindingConnection.new(self, callback)
		table.insert(self.connections, con)
		return con
	end
	function InputBinding:disconnect(connection)
		local _connections = self.connections
		local _connections_1 = self.connections
		local _connection = connection
		local _arg0 = (table.find(_connections_1, _connection) or 0) - 1
		-- ▼ Array.unorderedRemove ▼
		local _index = _arg0 + 1
		local _length = #_connections
		local _value = _connections[_index]
		if _value ~= nil then
			_connections[_index] = _connections[_length]
			_connections[_length] = nil
		end
		-- ▲ Array.unorderedRemove ▲
	end
	function InputBinding:fire(input)
		local _connections = self.connections
		local _arg0 = function(c)
			return c.callback(input)
		end
		for _k, _v in _connections do
			_arg0(_v, _k - 1, _connections)
		end
	end
end
local ActionBinding
do
	local super = InputBinding
	ActionBinding = setmetatable({}, {
		__tostring = function()
			return "ActionBinding"
		end,
		__index = super,
	})
	ActionBinding.__index = ActionBinding
	function ActionBinding.new(...)
		local self = setmetatable({}, ActionBinding)
		return self:constructor(...) or self
	end
	function ActionBinding:constructor(...)
		super.constructor(self, ...)
	end
end
local AxisBinding
do
	local super = InputBinding
	AxisBinding = setmetatable({}, {
		__tostring = function()
			return "AxisBinding"
		end,
		__index = super,
	})
	AxisBinding.__index = AxisBinding
	function AxisBinding.new(...)
		local self = setmetatable({}, AxisBinding)
		return self:constructor(...) or self
	end
	function AxisBinding:constructor(...)
		super.constructor(self, ...)
	end
end
return {
	BindingType = BindingType,
	InputBinding = InputBinding,
	ActionBinding = ActionBinding,
	AxisBinding = AxisBinding,
}
