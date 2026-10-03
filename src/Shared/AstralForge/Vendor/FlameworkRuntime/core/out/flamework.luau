local TS = _G[script]
local _services = TS.import(script, TS.getModule(script, "@rbxts", "services"))
local Players = _services.Players
local RunService = _services.RunService
local Metadata = TS.import(script, script.Parent, "metadata").Metadata
local Modding = TS.import(script, script.Parent, "modding").Modding
local Reflect = TS.import(script, script.Parent, "reflect").Reflect
local isConstructor = TS.import(script, script.Parent, "utility").isConstructor
local ArtificialDependency, Flamework
local Flamework = {}
do
	local _container = Flamework
	local tsImpl = _G[script]
	local isProfiling = Metadata.isProfiling()
	local hasFlameworkIgnited = false
	local isPreloading = false
	local inactiveThread
	local function resolveDependency(id)
		if isPreloading then
			local source, line = debug.info(2, "sl")
			warn(`[Flamework] Attempting to load dependency '{id}' during preloading.`)
			warn("This is prone to race conditions and is not guaranteed to succeed.")
			warn(`Script '{source}', Line {line}`)
		elseif not hasFlameworkIgnited and Metadata.gameConfig.disableDependencyWarnings ~= true then
			local source, line = debug.info(2, "sl")
			warn(`[Flamework] Dependency '{id}' was loaded before ignition.`)
			warn("This is considered bad practice and should be avoided.")
			warn("You can disable this warning in flamework.json")
			warn(`Script '{source}', Line {line}`)
		end
		return Modding.resolveDependency(ArtificialDependency, id, 0, {})
	end
	_container.resolveDependency = resolveDependency
	local logIfVerbose
	local function _addPaths(paths)
		local preloadPaths = {}
		for _, arg in paths do
			local service = table.remove(arg, 1)
			local currentPath = game:GetService(service)
			if service == "StarterPlayer" then
				if arg[1] ~= "StarterPlayerScripts" then
					error("StarterPlayer only supports StarterPlayerScripts")
				end
				if not RunService:IsClient() then
					error("The server cannot load StarterPlayer content")
				end
				currentPath = Players.LocalPlayer:WaitForChild("PlayerScripts")
				table.remove(arg, 1)
			end
			for i = 0, #arg - 1 do
				currentPath = currentPath:WaitForChild(arg[i + 1])
			end
			local _currentPath = currentPath
			table.insert(preloadPaths, _currentPath)
		end
		local preload = function(moduleScript)
			isPreloading = true
			local start = os.clock()
			local success, value = pcall(function()
				return tsImpl.import(script, moduleScript)
			end)
			local endTime = math.floor((os.clock() - start) * 1000)
			isPreloading = false
			if not success then
				error(`{moduleScript:GetFullName()} failed to preload ({endTime}ms): {value}`)
			end
		end
		for _, path in preloadPaths do
			logIfVerbose(`Preloading directory {path:GetFullName()}`)
			if path:IsA("ModuleScript") then
				preload(path)
			end
			for _1, instance in path:GetDescendants() do
				if instance:IsA("ModuleScript") then
					preload(instance)
				end
			end
		end
	end
	_container._addPaths = _addPaths
	local function _addPathsGlob(arg)
		return _addPaths(Metadata.getGlob(arg) or {})
	end
	_container._addPathsGlob = _addPathsGlob
	local function _implements(object, id)
		local _exp = Reflect.getMetadatas(object, "flamework:implements")
		local _result = false
		local _callback = function(impl)
			local _impl = impl
			local _id = id
			return table.find(_impl, _id) ~= nil
		end
		for _k, _v in _exp do
			if _callback(_v, _k - 1, _exp) then
				_result = true
				break
			end
		end
		return _result
	end
	_container._implements = _implements
	function logIfVerbose(...)
		local args = { ... }
		if Metadata.getLogLevel() == "verbose" then
			print("[Flamework (verbose)]", unpack(args))
		end
	end
	local function getIdentifier(obj, suffix)
		if suffix == nil then
			suffix = ""
		end
		local _condition = Reflect.getMetadata(obj, "identifier")
		if _condition == nil then
			_condition = `UnidentifiedFlameworkListener{suffix}`
		end
		return _condition
	end
	local function topologicalSort(objects)
		local currentSize = 0
		local sorted = {}
		local visited = {}
		local visitor
		visitor = function(node)
			local _node = node
			if visited[_node] ~= nil then
				return nil
			end
			local _node_1 = node
			visited[_node_1] = true
			local _idToObj = Reflect.idToObj
			local _node_2 = node
			local object = _idToObj[_node_2]
			if not object then
				return nil
			end
			local dependencies = Reflect.getMetadata(object, "flamework:parameters")
			for _, dependency in dependencies or {} do
				visitor(dependency)
			end
			local _exp = node
			local _original = currentSize
			currentSize += 1
			sorted[_exp] = _original
		end
		for _, node in objects do
			visitor(node)
		end
		return sorted
	end
	local function reusableThread(func)
		local thread = coroutine.running()
		while true do
			if inactiveThread == thread then
				inactiveThread = nil
			end
			func()
			if inactiveThread ~= nil then
				break
			end
			inactiveThread = thread
			func = coroutine.yield()
		end
	end
	local function profileYielding(func, identifier)
		if isProfiling then
			return function()
				debug.profilebegin(identifier)
				debug.setmemorycategory(identifier)
				func()
				debug.resetmemorycategory()
			end
		else
			return func
		end
	end
	local function reuseThread(func)
		if inactiveThread then
			task.spawn(inactiveThread, func)
		else
			task.spawn(reusableThread, func)
		end
	end

	local function includeOptionalClass(ctor)
		Reflect.defineMetadata(ctor, "flamework:optional", false)
	end
	_container.includeOptionalClass = includeOptionalClass

	local function ignite()
		if hasFlameworkIgnited then
			error("Flamework.ignite() should only be called once")
		end
		hasFlameworkIgnited = true
		for _, ctor in Reflect.idToObj do
			if not isConstructor(ctor) then
				continue
			end
			if not Reflect.getMetadata(ctor, "flamework:singleton") then
				continue
			end
			if Reflect.getMetadata(ctor, "flamework:optional") then
				continue
			end
			Modding.resolveSingleton(ctor)
			logIfVerbose(`Resolving singleton {ctor}`)
		end
		local dependencies = {}
		for ctor, dependency in Modding.getSingletons() do
			local _condition = Reflect.getMetadata(ctor, "flamework:loadOrder")
			if _condition == nil then
				_condition = 1
			end
			local loadOrder = _condition
			local _arg0 = { dependency, loadOrder }
			table.insert(dependencies, _arg0)
		end
		local _newValue = table.create(#dependencies)
		local _callback = function(_param)
			local obj = _param[1]
			return getIdentifier(obj)
		end
		for _k, _v in dependencies do
			_newValue[_k] = _callback(_v, _k - 1, dependencies)
		end
		local sortedDependencies = topologicalSort(_newValue)
		local start = {}
		local init = {}
		local tick = {}
		local render = {}
		local physics = {}
		table.sort(dependencies, function(_param, _param_1)
			local depA = _param[1]
			local aOrder = _param[2]
			local depB = _param_1[1]
			local bOrder = _param_1[2]
			if aOrder ~= bOrder then
				return aOrder < bOrder
			end
			local _arg0 = getIdentifier(depA)
			local aIndex = sortedDependencies[_arg0]
			local _arg0_1 = getIdentifier(depB)
			local bIndex = sortedDependencies[_arg0_1]
			return aIndex < bIndex
		end)
		Modding.onListenerAdded(function(object)
			local _object = object
			local _arg1 = getIdentifier(object, "/OnTick")
			tick[_object] = _arg1
			return tick
		end, "$:flamework@OnTick")
		Modding.onListenerAdded(function(object)
			local _object = object
			local _arg1 = getIdentifier(object, "/OnPhysics")
			physics[_object] = _arg1
			return physics
		end, "$:flamework@OnPhysics")
		Modding.onListenerAdded(function(object)
			local _object = object
			local _arg1 = getIdentifier(object, "/OnRender")
			render[_object] = _arg1
			return render
		end, "$:flamework@OnRender")
		Modding.onListenerRemoved(function(object)
			local _object = object
			local _valueExisted = tick[_object] ~= nil
			tick[_object] = nil
			return _valueExisted
		end, "$:flamework@OnTick")
		Modding.onListenerRemoved(function(object)
			local _object = object
			local _valueExisted = physics[_object] ~= nil
			physics[_object] = nil
			return _valueExisted
		end, "$:flamework@OnPhysics")
		Modding.onListenerRemoved(function(object)
			local _object = object
			local _valueExisted = render[_object] ~= nil
			render[_object] = nil
			return _valueExisted
		end, "$:flamework@OnRender")
		for _, _binding in dependencies do
			local dependency = _binding[1]
			if Flamework._implements(dependency, "$:flamework@OnInit") then
				local _arg0 = { dependency, getIdentifier(dependency) }
				table.insert(init, _arg0)
			end
			if Flamework._implements(dependency, "$:flamework@OnStart") then
				local _arg0 = { dependency, getIdentifier(dependency) }
				table.insert(start, _arg0)
			end
		end
		for _, _binding in init do
			local dependency = _binding[1]
			local identifier = _binding[2]
			if isProfiling then
				debug.setmemorycategory(identifier)
			end
			logIfVerbose(`OnInit {identifier}`)
			local initResult = dependency:onInit()
			if TS.Promise.is(initResult) then
				local status, value = initResult:awaitStatus()
				if status == TS.Promise.Status.Rejected then
					error(`OnInit failed for dependency '{identifier}'. {tostring(value)}`)
				end
			end
		end
		debug.resetmemorycategory()
		RunService.Heartbeat:Connect(function(dt)
			for dependency, identifier in tick do
				reuseThread(profileYielding(function()
					return dependency:onTick(dt)
				end, identifier))
			end
		end)
		RunService.Stepped:Connect(function(time, dt)
			for dependency, identifier in physics do
				reuseThread(profileYielding(function()
					return dependency:onPhysics(dt, time)
				end, identifier))
			end
		end)
		if RunService:IsClient() then
			RunService.RenderStepped:Connect(function(dt)
				for dependency, identifier in render do
					reuseThread(profileYielding(function()
						return dependency:onRender(dt)
					end, identifier))
				end
			end)
		end
		for _, _binding in start do
			local dependency = _binding[1]
			local identifier = _binding[2]
			logIfVerbose(`OnStart {identifier}`)
			reuseThread(profileYielding(function()
				return dependency:onStart()
			end, identifier))
		end
	end
	_container.ignite = ignite

	local function createGuard(meta)
		return meta
	end
	_container.createGuard = createGuard
end

do
	ArtificialDependency = setmetatable({}, {
		__tostring = function()
			return "ArtificialDependency"
		end,
	})
	ArtificialDependency.__index = ArtificialDependency
	function ArtificialDependency.new(...)
		local self = setmetatable({}, ArtificialDependency)
		return self:constructor(...) or self
	end
	function ArtificialDependency:constructor()
	end
end
Reflect.defineMetadata(ArtificialDependency, "identifier", "$:flamework@ArtificialDependency")
Reflect.defineMetadata(ArtificialDependency, "flamework:isArtificial", true)

local Service = Modding.createDecorator("Class", function(descriptor, _param)
	local cfg = _param[1]
	if RunService:IsServer() then
		Reflect.defineMetadata(descriptor.object, "flamework:singleton", true)
		local _exp = descriptor.object
		local _result = cfg
		if _result ~= nil then
			_result = _result.loadOrder
		end
		Reflect.defineMetadata(_exp, "flamework:loadOrder", _result)
	end
end)

local Controller = Modding.createDecorator("Class", function(descriptor, _param)
	local cfg = _param[1]
	if RunService:IsClient() then
		Reflect.defineMetadata(descriptor.object, "flamework:singleton", true)
		local _exp = descriptor.object
		local _result = cfg
		if _result ~= nil then
			_result = _result.loadOrder
		end
		Reflect.defineMetadata(_exp, "flamework:loadOrder", _result)
	end
end)

local Optional = Modding.createDecorator("Class", function(descriptor)
	if not Reflect.getMetadata(descriptor.object, "flamework:singleton") then
		warn("'Optional' decorator was applied to a non-singleton.", descriptor.object)
		warn("Make sure you apply the 'Optional' decorator above other decorators.")
	end
	Reflect.defineMetadata(descriptor.object, `flamework:optional`, true)
end)

return {
	Flamework = Flamework,
	Service = Service,
	Controller = Controller,
	Optional = Optional,
}
