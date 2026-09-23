--!strict

return function()
	local AtomicState = {}
	AtomicState.__index = AtomicState

	local CONTENTION_TIMEOUT_SECONDS = 2
	local CONTENTION_POLL_SECONDS = 0.03

	local function clone(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for key, child in value do
			result[clone(key)] = clone(child)
		end
		return result
	end

	local function revisionOf(value): number
		if type(value) == "table" and type(value.Meta) == "table" and type(value.Meta.Revision) == "number" then
			return math.max(0, math.floor(value.Meta.Revision))
		end
		return 0
	end

	function AtomicState.new(initial)
		local self = setmetatable({}, AtomicState)
		self._value = initial
		self._revision = revisionOf(initial)
		self._busy = false
		return self
	end

	function AtomicState:Read()
		self._revision = math.max(self._revision, revisionOf(self._value))
		return self._value, self._revision
	end

	function AtomicState:IsBusy(): boolean
		return self._busy == true
	end

	function AtomicState:Transact(callback, incrementRevision: boolean?): (boolean, any, number)
		local deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS
		while self._busy and os.clock() < deadline do
			task.wait(CONTENTION_POLL_SECONDS)
		end
		if self._busy then
			return false, "state transaction already in progress", self._revision
		end
		self._revision = math.max(self._revision, revisionOf(self._value))
		self._busy = true
		local cloneOk, draft = pcall(clone, self._value)
		if not cloneOk then
			self._busy = false
			return false, draft, self._revision
		end
		local ok, result = pcall(callback, draft, self._revision + 1)
		local shouldCommit = ok and not (type(result) == "table" and result.ok == false)
		if shouldCommit then
			if incrementRevision ~= false then
				self._revision += 1
				if type(draft) == "table" and type(draft.Meta) == "table" then
					draft.Meta.Revision = self._revision
				end
			end
			self._value = draft
		end
		self._busy = false
		if not ok then
			return false, result, self._revision
		end
		return true, result, self._revision
	end

	function AtomicState:Replace(value, revision: number?): boolean
		if self._busy then
			return false
		end
		self._value = value
		self._revision = math.max(self._revision, revision or self._revision)
		return true
	end

	return AtomicState
end
