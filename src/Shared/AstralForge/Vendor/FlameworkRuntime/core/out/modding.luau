local TS = _G[script]
local Signal = TS.import(script, TS.getModule(script, "@rbxts", "signal"))
local Reflect = TS.import(script, script.Parent, "reflect").Reflect
local isConstructor = TS.import(script, script.Parent, "utility").isConstructor
local getDeferredConstructor
local Modding = {}
do
	local _container = Modding
	local listeners = {}
	local lifecycleListeners = {}
	local decoratorListeners = {}
	local listenerAdded = Signal.new()
	local listenerRemoved = Signal.new()
	local listenerAddedEvents = {}
	local listenerRemovedEvents = {}
	local dependencyResolution = {}
	local resolvedSingletons = {}
	local loadingList = {}

	local function getObjectFromId(id)
		local _idToObj = Reflect.idToObj
		local _id = id
		return _idToObj[_id]
	end
	_container.getObjectFromId = getObjectFromId

	local function addListener(object)
		local listener = {
			eventIds = {},
			involvement = {},
		}
		for _, lifecycleEvents in Reflect.getMetadatas(object, `flamework:implements`) do
			for _1, lifecycleEvent in lifecycleEvents do
				if listener.eventIds[lifecycleEvent] ~= nil then
					continue
				end
				local lifecycleListener = lifecycleListeners[lifecycleEvent]
				if not lifecycleListener then
					lifecycleListener = {}
					local _lifecycleListener = lifecycleListener
					lifecycleListeners[lifecycleEvent] = _lifecycleListener
				end
				local _lifecycleListener = lifecycleListener
				local _object = object
				_lifecycleListener[_object] = true
				listener.eventIds[lifecycleEvent] = true
				local _involvement = listener.involvement
				local _lifecycleListener_1 = lifecycleListener
				table.insert(_involvement, _lifecycleListener_1)
				local _result = listenerAddedEvents[lifecycleEvent]
				if _result ~= nil then
					_result:Fire(object)
				end
			end
		end
		local decorators = Reflect.getMetadata(object, `flamework:decorators`)
		if decorators then
			for _, decorator in decorators do
				if listener.eventIds[decorator] ~= nil then
					continue
				end
				local decoratorListener = decoratorListeners[decorator]
				if not decoratorListener then
					decoratorListener = {}
					local _decoratorListener = decoratorListener
					decoratorListeners[decorator] = _decoratorListener
				end
				local _decoratorListener = decoratorListener
				local _object = object
				_decoratorListener[_object] = true
				listener.eventIds[decorator] = true
				local _involvement = listener.involvement
				local _decoratorListener_1 = decoratorListener
				table.insert(_involvement, _decoratorListener_1)
				local _result = listenerAddedEvents[decorator]
				if _result ~= nil then
					_result:Fire(object)
				end
			end
		end
		local _object = object
		listeners[_object] = listener
		listenerAdded:Fire(object)
	end
	_container.addListener = addListener

	local function removeListener(object)
		local _object = object
		local listener = listeners[_object]
		if not listener then
			return nil
		end
		for _, set in listener.involvement do
			local _object_1 = object
			set[_object_1] = nil
		end
		for id in listener.eventIds do
			local _result = listenerRemovedEvents[id]
			if _result ~= nil then
				_result:Fire(object)
			end
		end
		local _object_1 = object
		listeners[_object_1] = nil
		listenerRemoved:Fire(object)
	end
	_container.removeListener = removeListener

	local function onListenerAdded(func, id)
		if id ~= nil then
			local _id = id
			local listenerAddedEvent = listenerAddedEvents[_id]
			if not listenerAddedEvent then
				local _exp = id
				listenerAddedEvent = Signal.new()
				local _listenerAddedEvent = listenerAddedEvent
				listenerAddedEvents[_exp] = _listenerAddedEvent
			end
			local _id_1 = id
			local _condition = lifecycleListeners[_id_1]
			if not _condition then
				local _id_2 = id
				_condition = decoratorListeners[_id_2]
			end
			local existingListeners = _condition
			if existingListeners then
				for listener in existingListeners do
					task.spawn(func, listener)
				end
			end
			return listenerAddedEvent:Connect(func)
		else
			for listener in listeners do
				task.spawn(func, listener)
			end
			return listenerAdded:Connect(func)
		end
	end
	_container.onListenerAdded = onListenerAdded

	local function onListenerRemoved(func, id)
		if id ~= nil then
			local _id = id
			local listenerRemovedEvent = listenerRemovedEvents[_id]
			if not listenerRemovedEvent then
				local _exp = id
				listenerRemovedEvent = Signal.new()
				local _listenerRemovedEvent = listenerRemovedEvent
				listenerRemovedEvents[_exp] = _listenerRemovedEvent
			end
			return listenerRemovedEvent:Connect(func)
		else
			return listenerRemoved:Connect(func)
		end
	end
	_container.onListenerRemoved = onListenerRemoved

	local defineDecoratorMetadata
	local function createDecorator(_kind, func)
		return {
			func = function(descriptor, config)
				defineDecoratorMetadata(descriptor, config)
				func(descriptor, config)
			end,
		}
	end
	_container.createDecorator = createDecorator

	local function createMetaDecorator(_kind)
		return {
			func = function(descriptor, config)
				defineDecoratorMetadata(descriptor, config)
			end,
		}
	end
	_container.createMetaDecorator = createMetaDecorator

	local function getDecorators(id)
		local _arg0 = id ~= nil
		assert(_arg0)
		local _decorators = Reflect.decorators
		local _id = id
		local decorators = _decorators[_id]
		if not decorators then
			return {}
		end
		local _newValue = table.create(#decorators)
		local _callback = function(object)
			local decoratorConfig = Reflect.getOwnMetadata(object, `flamework:decorators.{id}`)
			assert(decoratorConfig)
			return {
				object = object,
				constructor = if isConstructor(object) then object else nil,
				arguments = decoratorConfig.arguments,
			}
		end
		for _k, _v in decorators do
			_newValue[_k] = _callback(_v, _k - 1, decorators)
		end
		return _newValue
	end
	_container.getDecorators = getDecorators

	local getDecorator
	local function getPropertyDecorators(obj, id)
		local decorators = {}
		local _arg0 = id ~= nil
		assert(_arg0)
		for _, prop in Reflect.getProperties(obj) do
			local decorator = getDecorator(obj, prop, id)
			if decorator then
				decorators[prop] = decorator
			end
		end
		return decorators
	end
	_container.getPropertyDecorators = getPropertyDecorators

	function getDecorator(object, property, id)
		local decorator = Reflect.getMetadata(object, `flamework:decorators.{id}`, property)
		if not decorator then
			return nil
		end
		return decorator
	end
	_container.getDecorator = getDecorator

	local createDependency
	local function resolveSingleton(ctor)
		local _ctor = ctor
		local resolvedDependency = resolvedSingletons[_ctor]
		if resolvedDependency ~= nil then
			return resolvedDependency
		end
		local _ctor_1 = ctor
		if table.find(loadingList, _ctor_1) ~= nil then
			local _result = table.create(#loadingList)
			for _k, _v in loadingList do
				_result[_k] = tostring(_v)
			end
			error(`Circular dependency detected {table.concat(_result, " <=> ")} <=> {ctor}`)
		end
		local _ctor_2 = ctor
		table.insert(loadingList, _ctor_2)
		local opts = Reflect.getOwnMetadata(ctor, "flamework:dependency_resolution")
		local dependency = createDependency(ctor, opts)
		local _ctor_3 = ctor
		resolvedSingletons[_ctor_3] = dependency
		loadingList[#loadingList] = nil
		addListener(dependency)
		return dependency
	end
	_container.resolveSingleton = resolveSingleton
	local function getSingletons()
		return resolvedSingletons
	end
	_container.getSingletons = getSingletons

	local function registerDependency(dependency, id)
		local _arg0 = id ~= nil
		assert(_arg0)
		local _dependency = dependency
		if type(_dependency) == "function" then
			local _id = id
			local _dependency_1 = dependency
			dependencyResolution[_id] = _dependency_1
		else
			local _id = id
			dependencyResolution[_id] = function()
				return dependency
			end
		end
	end
	_container.registerDependency = registerDependency

	local createDeferredDependency
	function createDependency(ctor, options)
		if options == nil then
			options = {}
		end
		local _binding = createDeferredDependency(ctor, options)
		local obj = _binding[1]
		local construct = _binding[2]
		construct()
		return obj
	end
	_container.createDependency = createDependency

	local resolveDependency
	function createDeferredDependency(ctor, options)
		if options == nil then
			options = {}
		end
		local _binding = getDeferredConstructor(ctor)
		local obj = _binding[1]
		local construct = _binding[2]
		return { obj, function()
			local dependencies = Reflect.getMetadata(ctor, "flamework:parameters")
			local constructorDependencies = {}
			if dependencies then
				for index, dependencyId in pairs(dependencies) do
					constructorDependencies[index] = resolveDependency(ctor, dependencyId, index - 1, options)
				end
			end
			construct(unpack(constructorDependencies))
		end }
	end
	_container.createDeferredDependency = createDeferredDependency

	function resolveDependency(ctor, dependencyId, index, options)
		if options.handle ~= nil then
			local dependency = options.handle(dependencyId, index)
			if dependency ~= nil then
				return dependency
			end
		end
		local _dependencyId = dependencyId
		local resolution = dependencyResolution[_dependencyId]
		if resolution ~= nil then
			return resolution(ctor)
		end
		local _idToObj = Reflect.idToObj
		local _dependencyId_1 = dependencyId
		local dependencyCtor = _idToObj[_dependencyId_1]
		if dependencyCtor and isConstructor(dependencyCtor) then
			return resolveSingleton(dependencyCtor)
		end
		if string.sub(dependencyId, 1, 2) == "$p" then
			if string.sub(dependencyId, 1, 3) == "$ps" then
				return string.sub(dependencyId, 5)
			end
			if string.sub(dependencyId, 1, 3) == "$pn" then
				local _condition = tonumber(string.sub(dependencyId, 5))
				if _condition == nil then
					_condition = 0
				end
				return _condition
			end
			if options.handlePrimitive ~= nil then
				return options.handlePrimitive(dependencyId, index)
			end
			error(`Unexpected primitive dependency '{dependencyId}' while constructing {ctor}`)
		end
		error(`Could not find constructor for {dependencyId} while constructing {ctor}`)
	end
	_container.resolveDependency = resolveDependency

	local function inspect(value)
		local _value = value
		assert(_value)
		return value
	end
	_container.inspect = inspect

	function defineDecoratorMetadata(descriptor, config)
		local propertyKey = if descriptor.isStatic then `static:{descriptor.property}` else descriptor.property
		Reflect.defineMetadata(descriptor.object, `flamework:decorators.{descriptor.id}`, {
			arguments = config,
		}, propertyKey)
		local decoratorList = Reflect.getMetadata(descriptor.object, `flamework:decorators`, propertyKey)
		if not decoratorList then
			local _exp = descriptor.object
			decoratorList = {}
			Reflect.defineMetadata(_exp, "flamework:decorators", decoratorList, propertyKey)
		end
		local _decoratorList = decoratorList
		local _id = descriptor.id
		table.insert(_decoratorList, _id)
	end
end
function getDeferredConstructor(ctor)
	local obj = setmetatable({}, ctor)
	return { obj, function(...)
		local args = { ... }
		local result = obj:constructor(unpack(args))
		local _arg0 = result == nil or result == obj
		local _arg1 = `Deferred constructors are not allowed to return values.`
		assert(_arg0, _arg1)
	end }
end
return {
	Modding = Modding,
}
