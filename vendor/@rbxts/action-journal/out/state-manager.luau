-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local Signal = TS.import(script, TS.getModule(script, "@rbxts", "lemon-signal").src).default
local PATH_SEPARATOR = "/"
local function invalidPath(path)
	return error(`Invalid path: {path}`, 2)
end
local StateManager
do
	StateManager = setmetatable({}, {
		__tostring = function()
			return "StateManager"
		end,
	})
	StateManager.__index = StateManager
	function StateManager.new(...)
		local self = setmetatable({}, StateManager)
		return self:constructor(...) or self
	end
	function StateManager:constructor(state)
		self.state = state
		self.changed = Signal.new()
		self.initial = state
	end
	function StateManager:whenChanged(callback)
		local conn = self.changed:Connect(callback)
		return function()
			return conn:Disconnect()
		end
	end
	function StateManager:whenPathChanged(atPath, callback)
		local conn = self.changed:Connect(function(info)
			if info.path ~= atPath then
				return nil
			end
			callback(info)
		end)
		return function()
			return conn:Disconnect()
		end
	end
	function StateManager:setPath(path, value, author, initialPath, history)
		if initialPath == nil then
			initialPath = path
		end
		if history == nil then
			history = true
		end
		if path == "" then
			self.state = value
			return nil
		end
		local parts = string.split(path, PATH_SEPARATOR)
		-- ▼ Array.pop ▼
		local _length = #parts
		local _result = parts[_length]
		parts[_length] = nil
		-- ▲ Array.pop ▲
		local field = _result
		-- ▼ ReadonlyArray.join ▼
		local _pATH_SEPARATOR = PATH_SEPARATOR
		if _pATH_SEPARATOR == nil then
			_pATH_SEPARATOR = ", "
		end
		-- ▲ ReadonlyArray.join ▲
		local objectPath = table.concat(parts, _pATH_SEPARATOR)
		local object = self:getPath(objectPath)
		if field == nil or object == nil then
			return invalidPath(path)
		end
		local oldValue = object[field]
		local _object = {}
		if object ~= 0 and object == object and object ~= "" and object then
			for _k, _v in object do
				_object[_k] = _v
			end
		end
		_object[field] = value
		local newObject = _object
		self:setPath(objectPath, newObject, author, initialPath)
		if path == initialPath and history then
			self.changed:Fire({
				author = author,
				path = path,
				oldValue = oldValue,
				newValue = value,
			})
		end
	end
	function StateManager:getPath(path)
		if path == "" then
			return self.state
		end
		local parts = string.split(path, PATH_SEPARATOR)
		local current = self.state
		for _, part in parts do
			if current == nil then
				return invalidPath(path)
			end
			current = current[part]
		end
		return current
	end
	function StateManager:getState()
		return self.state
	end
end
return {
	StateManager = StateManager,
}
