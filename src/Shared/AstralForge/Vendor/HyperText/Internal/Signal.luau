--!strict
--!optimize 2

local module = {}

local methods = {} :: classMethods<>
local connectionMethods = {} :: connectionClassMethods<>

local signalMT = {__index = methods}
local connectionMT = {__index = connectionMethods}
local threadPool : {thread} = {}

local SIGNAL_BEHAVIOUR : signalBehaviour = "defer"

local BATCH_THRESHOLD = 5

type signalBehaviour = "defer" | "sync"

type snapshot<P...> = {
	index : number,
	count : number,
	connections : {connectionClassType<P...>},
}

type classContent<P...> = {
	_last : connectionClassType<P...>?,
	_first : connectionClassType<P...>?,
	_sourceConnections : {connectionClassType<P...>}?,
	_sourceRBXConnection : RBXScriptConnection?,
	_connectionCount : number,
}
type classMethods<P...> = {
	Connect : typeof(
		function(self : classType<P...>, callback : (P...) -> ()) : connectionClassType<P...> return nil :: any end
	),
	Once : typeof(
		function(self : classType<P...>, callback : (P...) -> ()) : connectionClassType<P...> return nil :: any end
	),
	Filter : typeof(
		function(self : classType<P...>, filter : (P...) -> boolean) : classType<P...> return nil :: any end
	),
	Reject : typeof(
		function(self : classType<P...>, filter : (P...) -> boolean) : classType<P...> return nil :: any end
	),
	Transform : typeof(
		function(self : classType<P...>, transformer : (P...) -> P...) : classType<P...> return nil :: any end
	),
	Distinct : typeof(
		function(self : classType<P...>, keySelector : ((P...) -> any)?) : classType<P...> return nil :: any end
	),
	Debounce : typeof(
		function(self : classType<P...>, duration : number) : classType<P...> return nil :: any end
	),
	Throttle : typeof(
		function(self : classType<P...>, duration : number) : classType<P...> return nil :: any end
	),
	Delay : typeof(
		function(self : classType<P...>, duration : number) : classType<P...> return nil :: any end
	),
	Tap : typeof(
		function(self : classType<P...>, callback : (P...) -> ()) : classType<P...> return nil :: any end
	),
	Take : typeof(
		function(self : classType<P...>, amount : number) : classType<P...> return nil :: any end
	),
	Skip : typeof(
		function(self : classType<P...>, amount : number) : classType<P...> return nil :: any end
	),
	Merge : typeof(
		function(self : classType<P...>, ... : classType<P...>) : classType<P...> return nil :: any end
	),
	DisconnectAll : typeof(
		function(self : classType<P...>) end
	),
	Fire : typeof(
		function(self : classType<P...>, ... : P...) end
	),
	Wait : typeof(
		function(self : classType<P...>) : P... return nil :: any end
	),
	AWait : typeof(
		function(self : classType<P...>, timeoutDuration : number) : (boolean, P...) return nil :: any end
	),
	GetConnections : typeof(
		function(self : classType<P...>) : {connectionClassType<P...>} return nil :: any end
	),
	Destroy : typeof(
		function(self : classType<P...>) end
	),
	
	_FireImp : (self : classType<P...>, behaviour : signalBehaviour, P...) -> (),
}
export type classType<P...> = classContent<P...> & classMethods<P...>

type connectionClassContent<P...> = {
	_callback : (P...) -> (),
	_next : connectionClassType<P...>?,
	_previous : connectionClassType<P...>?,
	_fireOnce : boolean?,
	_isWaitConnection : boolean?,
	
	signal : classType<P...>,
	connected : boolean,
}
type connectionClassMethods<P...> = {
	Disconnect : typeof(
		function(self : connectionClassType<P...>) end
	),
}
export type connectionClassType<P...> = connectionClassContent<P...> & connectionClassMethods<P...>

local function newConnection<P...>(
	signal : classType<P...>,
	callback : (P...) -> (),
	fireOnce : boolean?,
	isWaitConnection : boolean?
) : connectionClassType<P...>
	local content : connectionClassContent<P...> = {
		_callback = callback,
		_next = nil,
		_previous = signal._last,
		_fireOnce = fireOnce,
		_isWaitConnection = isWaitConnection,

		signal = signal,
		connected = true,
	}
	
	signal._connectionCount += 1
	
	local connection = setmetatable(
		content,
		connectionMT
	) :: connectionClassType<P...>

	if signal._last then
		signal._last._next = connection
	end
	if not signal._first then
		signal._first = connection
	end

	signal._last = connection

	return connection
end

local function reuseThread<P...>(
	callback : (P...) -> (),
	thread : thread,
	... : P...
)
	callback(...)

	table.insert(threadPool, thread)
end

local function disconnect<P...>(connection : connectionClassType<P...>)
	connection.signal._connectionCount -= 1
	connection.connected = false
	connection._next = nil
	connection._previous = nil
end

local function disconnectSource<P...>(signal : classType<P...>)
	if signal._sourceConnections then
		for _, connection in signal._sourceConnections do
			connection:Disconnect()
		end

		signal._sourceConnections = nil
	end
	if signal._sourceRBXConnection then
		signal._sourceRBXConnection:Disconnect()
	end
end

local function newDerivedSignal<P...>(
	source : classType<P...>,
	callback : (derivedSignal : classType<P...>, P...) -> ()
) : classType<P...>
	local signal = module.new() :: classType<P...>

	local connection = source:Connect(function(... : P...)
		callback(signal, ...)
	end)

	signal._sourceConnections = {connection}

	return signal
end

local function getReusableThread() : thread
	local length = #threadPool
	local thread : thread

	if length == 0 then
		thread = coroutine.create(function()
			while true do
				reuseThread(coroutine.yield())
			end
		end)

		coroutine.resume(thread)
	else
		thread = threadPool[length]

		threadPool[length] = nil
	end
	
	return thread
end

local function runSnapshot<P...>(snapshot : snapshot<P...>, ... : P...)
	local count = snapshot.count
	local connections = snapshot.connections
	
	while snapshot.index <= count do
		local connection = connections[snapshot.index]

		snapshot.index += 1

		connection._callback(...)
	end
end

local function dispatchSnapshot<P...>(snapshot : snapshot<P...>, ... : P...)
	local count = snapshot.count
	
	while snapshot.index <= count do
		local thread = getReusableThread()

		task.spawn(thread, runSnapshot, thread, snapshot, ...)
	end
end

module.new = function() : classType<>
	local content : classContent<> = {
		_connectionCount = 0,
	}
	
	return setmetatable(
		content,
		signalMT
	) :: classType<>
end

module.wrap = function(RBXSignal : RBXScriptSignal) : classType<>
	local content : classContent<> = {
		_connectionCount = 0,
	}

	local self = setmetatable(
		content,
		signalMT
	) :: classType<>
	
	local connection = RBXSignal:Connect(function()
		self:_FireImp("sync")
	end)
	
	self._sourceRBXConnection = connection
	
	return self
end

methods.Destroy = function<P...>(self : classType<P...>)
	self:DisconnectAll()

	disconnectSource(self)
end

methods.Connect = function<P...>(
	self : classType<P...>,
	callback : (P...) -> ()
) : connectionClassType<P...>	
	return newConnection(self, callback)
end

methods.Once = function<P...>(
	self : classType<P...>,
	callback : (P...) -> ()
) : connectionClassType<P...>
	return newConnection(self, callback, true)
end

methods.Filter = function<P...>(
	self : classType<P...>,
	filter : (P...) -> boolean
) : classType<P...>
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		if filter(...) then
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Reject = function<P...>(
	self : classType<P...>,
	filter : (P...) -> boolean
) : classType<P...>
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		if not filter(...) then
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Transform = function<P...>(
	self : classType<P...>,
	transformer : (P...) -> P...
) : classType<P...>
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		derivedSignal:_FireImp("sync", transformer(...))
	end)
end

methods.Distinct = function<P...>(
	self : classType<P...>,
	keySelector : ((P...) -> any)?
) : classType<P...>
	local hasLast : boolean
	local last : any
	
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		local comparand = if keySelector then keySelector(...) else select(1, ...)
		
		if not hasLast or last ~= comparand then
			hasLast = true
			last = comparand
			
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Debounce = function<P...>(
	self : classType<P...>,
	duration : number
) : classType<P...>
	local last : number
	
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		local now = os.clock()
		last = now
		
		task.wait(duration)
		
		if last == now then
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Throttle = function<P...>(
	self : classType<P...>,
	duration : number
) : classType<P...>
	local last : number?

	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		local now = os.clock()
		
		if not last or now - last >= duration then
			last = now
			
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Delay = function<P...>(
	self : classType<P...>,
	duration : number
) : classType<P...>
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		task.wait(duration)
		
		derivedSignal:_FireImp("sync", ...)
	end)
end

methods.Tap = function<P...>(
	self : classType<P...>,
	callback : (P...) -> ()
) : classType<P...>
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		callback(...)
		
		derivedSignal:_FireImp("sync", ...)
	end)
end

methods.Take = function<P...>(
	self : classType<P...>,
	amount : number
) : classType<P...>
	amount = math.max(amount, 0)

	local count = 0
	
	local signal = newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		count += 1

		if count >= amount then
			disconnectSource(derivedSignal)
			
			if count == amount then
				derivedSignal:_FireImp("sync", ...)
			end
		else
			derivedSignal:_FireImp("sync", ...)
		end
	end)
	
	if amount == 0 then
		disconnectSource(signal)
	end
	
	return signal
end

methods.Skip = function<P...>(
	self : classType<P...>,
	amount : number
) : classType<P...>	
	amount = math.max(amount, 0)
	
	local count = 0
	
	return newDerivedSignal(self, function(derivedSignal : classType<P...>, ... : P...)
		count += 1

		if count > amount then
			derivedSignal:_FireImp("sync", ...)
		end
	end)
end

methods.Merge = function<P...>(self : classType<P...>, ... : classType<P...>) : classType<P...>
	local signal = module.new() :: classType<P...>
	local connections : {connectionClassType<P...>} = {
		self:Connect(function(... : P...)
			signal:_FireImp("sync", ...)
		end)
	}
	
	for _, givenSignal in {...} do
		table.insert(connections, givenSignal:Connect(function(... : P...)
			signal:_FireImp("sync", ...)
		end))
	end

	signal._sourceConnections = connections

	return signal
end

methods._FireImp = function<P...>(
	self : classType<P...>,
	behaviour : signalBehaviour,
	... : P...
)
	if behaviour == "sync" or self._connectionCount >= BATCH_THRESHOLD then
		local connections : {connectionClassType<P...>} = {}
		local connection = self._first
		local count = self._connectionCount

		while connection do
			local current = connection
			
			connection = connection._next

			table.insert(connections, current)
			
			if current._fireOnce then
				current:Disconnect()
			end
		end
		
		local snapshot : snapshot<P...> = {
			connections = connections,
			index = 1,
			count = count,
		}
		
		if behaviour == "sync" then
			dispatchSnapshot(snapshot, ...)
		else
			task.defer(dispatchSnapshot, snapshot, ...)
		end
	else
		local connection = self._first
		
		while connection do
			local current = connection
			local thread = getReusableThread()

			connection = connection._next

			if current._fireOnce then
				current:Disconnect()
			end

			task.defer(thread, current._callback, thread, ...)
		end
	end
end

methods.Fire = function<P...>(self : classType<P...>, ... : P...)
	self:_FireImp(SIGNAL_BEHAVIOUR, ...)
end

methods.Wait = function<P...>(self : classType<P...>) : P...
	local thread = coroutine.running()

	local connection = newConnection(self, function(... : P...)
		if coroutine.status(thread) == "suspended" then
			local success, message = coroutine.resume(thread, ...)

			if not success then
				error(message)
			end
		end
	end, true, true)

	return coroutine.yield()
end

methods.AWait = function<P...>(
	self : classType<P...>,
	timeoutDuration : number
) : (boolean, P...)
	local thread = coroutine.running()
	local timeoutThread : thread?

	local connection = newConnection(self, function(... : P...)
		if timeoutThread then
			task.cancel(timeoutThread)
		end

		if coroutine.status(thread) == "suspended" then
			local success, message = coroutine.resume(thread, false, ...)

			if not success then
				error(message)
			end
		end
	end, true, true)

	timeoutThread = task.delay(timeoutDuration, function()
		connection:Disconnect()
		
		if coroutine.status(thread) == "suspended" then
			warn("signal wait exceeded timeout duration and will return no values")
			
			local success, message = coroutine.resume(thread, true)

			if not success then
				error(message)
			end
		end
	end)
	
	return coroutine.yield()
end

methods.GetConnections = function<P...>(self : classType<P...>) : {connectionClassType<P...>}
	local connection = self._first
	local connections = {}
	
	while connection do
		local isWaitConnection = connection._isWaitConnection
		
		if not isWaitConnection then
			table.insert(connections, connection)
		end
		
		connection = connection._next
	end
	
	return connections
end

methods.DisconnectAll = function<P...>(self : classType<P...>)
	local connection = self._first
	
	while connection do
		local next_ = connection._next
		
		disconnect(connection)
		
		connection = next_
	end
	
	self._last = nil
	self._first = nil
end

connectionMethods.Disconnect = function<P...>(self : connectionClassType<P...>)
	local connected = self.connected
	
	if connected then
		local previous = self._previous
		local next_ = self._next
		local signal = self.signal
		
		if previous then
			previous._next = next_
		end
		if next_ then
			next_._previous = previous
		end

		if signal._last == self then
			signal._last = previous
		end
		if signal._first == self then
			signal._first = next_
		end
		
		disconnect(self)
	end
end

return module
