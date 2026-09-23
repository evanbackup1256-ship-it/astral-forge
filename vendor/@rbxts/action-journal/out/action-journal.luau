-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local Signal = TS.import(script, TS.getModule(script, "@rbxts", "lemon-signal").src).default
local StateManager = TS.import(script, script.Parent, "state-manager").StateManager
local _binding = math
local clamp = _binding.clamp
local DEFAULT_FILTER_MODE = 0
local DEFAULT_HISTORY_SIZE = 100
local ActionJournal
do
	ActionJournal = setmetatable({}, {
		__tostring = function()
			return "ActionJournal"
		end,
	})
	ActionJournal.__index = ActionJournal
	function ActionJournal.new(...)
		local self = setmetatable({}, ActionJournal)
		return self:constructor(...) or self
	end
	function ActionJournal:constructor(state, options)
		self.state = state
		self.options = options
		self.added = Signal.new()
		self.actions = {}
		self.undoQueue = {}
		self.filters = {}
		local _exp = options.mode
		repeat
			if _exp == 0 then
				state:whenChanged(function(_param)
					local author = _param.author
					local path = _param.path
					local oldValue = _param.oldValue
					local newValue = _param.newValue
					return self:add({
						timestamp = os.clock(),
						target = path,
						author = author,
						oldValue = oldValue,
						newValue = newValue,
					})
				end)
				break
			end
			if _exp == 1 then
				self.added:Connect(function(action)
					return self:executeAction(action)
				end)
				break
			end
		until true
	end
	function ActionJournal:addFilter(filter)
		local _filters = self.filters
		local _filter = filter
		_filters[_filter] = true
		return self
	end
	function ActionJournal:removeFilter(filter)
		local _filters = self.filters
		local _filter = filter
		_filters[_filter] = nil
		return self
	end
	function ActionJournal:isFiltered(action, filterMode)
		if filterMode == nil then
			filterMode = self:getFilterMode()
		end
		local _array = {}
		local _length = #_array
		for _v in self.filters do
			_length += 1
			_array[_length] = _v
		end
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_array)
		local _callback = function(filter)
			return filter(action)
		end
		for _k, _v in _array do
			_newValue[_k] = _callback(_v, _k - 1, _array)
		end
		-- ▲ ReadonlyArray.map ▲
		local filterResults = _newValue
		repeat
			if filterMode == 0 then
				-- ▼ ReadonlyArray.some ▼
				local _result = false
				local _callback_1 = function(v)
					return v
				end
				for _k, _v in filterResults do
					if _callback_1(_v, _k - 1, filterResults) then
						_result = true
						break
					end
				end
				-- ▲ ReadonlyArray.some ▲
				return _result
			end
			if filterMode == 1 then
				local _result
				if #filterResults == 0 then
					_result = false
				else
					-- ▼ ReadonlyArray.every ▼
					local _result_1 = true
					local _callback_1 = function(v)
						return v
					end
					for _k, _v in filterResults do
						if not _callback_1(_v, _k - 1, filterResults) then
							_result_1 = false
							break
						end
					end
					-- ▲ ReadonlyArray.every ▲
					_result = _result_1
				end
				return _result
			end
		until true
	end
	function ActionJournal:add(action, filterMode)
		if filterMode == nil then
			filterMode = self:getFilterMode()
		end
		if self:isFiltered(action, filterMode) then
			return self
		end
		local _binding_1 = self.options
		local historySize = _binding_1.historySize
		if historySize == nil then
			historySize = DEFAULT_HISTORY_SIZE
		end
		local _binding_2 = self
		local actions = _binding_2.actions
		if #actions >= historySize then
			local oldest = table.remove(actions, 1)
			if oldest then
				local index = (table.find(self.undoQueue, oldest) or 0) - 1
				if index ~= -1 then
					table.remove(self.undoQueue, index + 1)
				end
			end
		end
		local _action = action
		table.insert(actions, _action)
		self.added:Fire(action)
		return self
	end
	function ActionJournal:getStateAt(timestamp, managed)
		self:validateTimestamp(timestamp)
		local state = StateManager.new(self.state.initial)
		local actions = ActionJournal.new(state, {
			mode = 1,
		})
		for _, action in self.actions do
			if action.timestamp > timestamp then
				break
			end
			actions:executeAction(action)
		end
		return if managed then state else state:getState()
	end
	function ActionJournal:timeTravel(timestamp, preserveAuthor)
		if preserveAuthor == nil then
			preserveAuthor = true
		end
		local _binding_1 = self
		local state = _binding_1.state
		local actions = _binding_1.actions
		local undoQueue = _binding_1.undoQueue
		local count = #actions
		if count == 0 then
			return nil
		end
		self:validateTimestamp(timestamp)
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(action)
			return action.timestamp <= timestamp
		end
		local _length = 0
		for _k, _v in actions do
			if _callback(_v, _k - 1, actions) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		table.sort(_newValue, function(a, b)
			return a.timestamp < b.timestamp
		end)
		local newActions = _newValue
		-- ▼ ReadonlyArray.filter ▼
		local _newValue_1 = {}
		local _callback_1 = function(action)
			return action.timestamp <= timestamp
		end
		local _length_1 = 0
		for _k, _v in undoQueue do
			if _callback_1(_v, _k - 1, undoQueue) == true then
				_length_1 += 1
				_newValue_1[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		local newUndoQueue = _newValue_1
		state:setPath("", state.initial, "time-travel")
		table.clear(actions)
		table.clear(undoQueue)
		for _, action in newActions do
			table.insert(actions, action)
			self:executeAction(action, if preserveAuthor then nil else "time-travel", false)
		end
		for _, action in newUndoQueue do
			table.insert(undoQueue, action)
		end
	end
	function ActionJournal:getFirst(offset)
		if offset == nil then
			offset = 0
		end
		return self.actions[clamp(offset, 0, #self.actions - 1) + 1]
	end
	function ActionJournal:getLast(offset)
		if offset == nil then
			offset = 0
		end
		local size = #self.actions
		return self.actions[size - 1 - clamp(offset, 0, size - 1) + 1]
	end
	function ActionJournal:getRecorded()
		return self.actions
	end
	function ActionJournal:getUndoQueue()
		return self.undoQueue
	end
	function ActionJournal:redo()
		local _exp = self.undoQueue
		-- ▼ Array.pop ▼
		local _length = #_exp
		local _result = _exp[_length]
		_exp[_length] = nil
		-- ▲ Array.pop ▲
		local action = _result
		if not action then
			return self
		end
		return self:executeAction(action)
	end
	function ActionJournal:undoNewerThan(timestamp)
		for i = #self.actions - 1, 0, -1 or 1 do
			local action = self.actions[i + 1]
			if action.timestamp < timestamp then
				continue
			end
			self:undoDirect(action)
		end
		return self
	end
	function ActionJournal:undoToAction(action)
		return self:undoNewerThan(action.timestamp)
	end
	function ActionJournal:undo()
		local _exp = self.actions
		-- ▼ Array.pop ▼
		local _length = #_exp
		local _result = _exp[_length]
		_exp[_length] = nil
		-- ▲ Array.pop ▲
		local action = _result
		if not action then
			return self
		end
		self:undoDirect(action)
		return self
	end
	function ActionJournal:executeAction(action, author, history)
		if author == nil then
			author = action.author
		end
		if history == nil then
			history = true
		end
		self.state:setPath(action.target, action.newValue, author, nil, history)
		return self
	end
	function ActionJournal:undoDirect(action)
		self.state:setPath(action.target, action.oldValue, action.author, nil, false)
		local _undoQueue = self.undoQueue
		local _action = action
		table.insert(_undoQueue, _action)
	end
	function ActionJournal:validateTimestamp(timestamp)
		local oldest = self:getFirst()
		local newest = self:getLast()
		local invalid = oldest ~= nil and newest ~= nil and (timestamp < oldest.timestamp or newest and timestamp > newest.timestamp)
		if invalid then
			error("Invalid timestamp: " .. tostring(timestamp), 2)
		end
	end
	function ActionJournal:getFilterMode()
		local _condition = self.options.filterMode
		if _condition == nil then
			_condition = DEFAULT_FILTER_MODE
		end
		return _condition
	end
end
return {
	ActionJournal = ActionJournal,
}
