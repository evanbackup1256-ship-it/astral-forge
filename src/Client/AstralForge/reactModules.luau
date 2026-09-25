local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function childOf(parent, name)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	return parent:FindFirstChild(name)
end

local include = childOf(ReplicatedStorage, "rbxts_include")
local importTsModule = nil
do
	local importScript = childOf(include, "TSImport")
	if importScript ~= nil and importScript:IsA("ModuleScript") then
		local ok, loaded = pcall(require, importScript)
		if ok and type(loaded) == "function" then
			importTsModule = loaded
		end
	end
end
local packages = childOf(childOf(include, "node_modules"), "@rbxts")
local hooksPackage = childOf(packages, "pretty-react-hooks")
local hooksRoot = childOf(hooksPackage, "out")
local loaded = {}

local function resolveHookScript(folder)
	local hookRoot = childOf(hooksRoot, folder)
	if hookRoot == nil then
		return nil
	end
	if hookRoot:IsA("ModuleScript") then
		return hookRoot
	end
	local initScript = childOf(hookRoot, "init")
	if initScript ~= nil and initScript:IsA("ModuleScript") then
		return initScript
	end
	return nil
end

local function load(folder)
	local existing = loaded[folder]
	if existing ~= nil then
		if existing == false then
			return nil
		end
		return existing
	end
	local moduleScript = resolveHookScript(folder)
	if moduleScript == nil or importTsModule == nil then
		loaded[folder] = false
		return nil
	end
	local ok, pkg = pcall(importTsModule, moduleScript)
	if not ok or type(pkg) ~= "table" then
		loaded[folder] = false
		return nil
	end
	loaded[folder] = pkg
	return pkg
end

local function hookFunction(folder, name)
	local pkg = load(folder)
	if type(pkg) ~= "table" then
		return nil
	end
	local fn = pkg[name]
	if type(fn) ~= "function" then
		return nil
	end
	return fn
end

local function callable(callback)
	local invoke = function(...)
		if type(callback) == "function" then
			return callback(...)
		end
		return nil
	end
	return setmetatable({
		flush = invoke,
		cancel = function() end,
	}, {
		__call = function(_, ...)
			return invoke(...)
		end,
	})
end

local function useLatestCallback(callback)
	local fn = hookFunction("use-latest-callback", "useLatestCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback)
end

local function useDebounceCallback(callback, options)
	local fn = hookFunction("use-debounce-callback", "useDebounceCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback, options)
end

local function useDebounceState(initialState, options)
	local fn = hookFunction("use-debounce-state", "useDebounceState")
	if fn == nil then
		return initialState, function() end
	end
	return fn(initialState, options)
end

local function usePrevious(value, predicate)
	local fn = hookFunction("use-previous", "usePrevious")
	if fn == nil then
		return nil
	end
	return fn(value, predicate)
end

local function useMountEffect(callback)
	local fn = hookFunction("use-mount-effect", "useMountEffect")
	if fn == nil then
		return nil
	end
	return fn(callback)
end

local function useUpdateEffect(effect, dependencies)
	local fn = hookFunction("use-update-effect", "useUpdateEffect")
	if fn == nil then
		return nil
	end
	return fn(effect, dependencies)
end

local function useUnmountEffect(callback)
	local fn = hookFunction("use-unmount-effect", "useUnmountEffect")
	if fn == nil then
		return nil
	end
	return fn(callback)
end

local function useDeferEffect(callback, dependencies)
	local fn = hookFunction("use-defer-effect", "useDeferEffect")
	if fn == nil then
		return nil
	end
	return fn(callback, dependencies)
end

local function useEventListener(event, listener, options)
	local fn = hookFunction("use-event-listener", "useEventListener")
	if fn == nil then
		return nil
	end
	return fn(event, listener, options)
end

local function useThrottleCallback(callback, options)
	local fn = hookFunction("use-throttle-callback", "useThrottleCallback")
	if fn == nil then
		return callable(callback)
	end
	return fn(callback, options)
end

local function useTimeout(callback, delay)
	local fn = hookFunction("use-timeout", "useTimeout")
	if fn == nil then
		return nil
	end
	return fn(callback, delay)
end

local function useInterval(callback, delay, options)
	local fn = hookFunction("use-interval", "useInterval")
	if fn == nil then
		return nil
	end
	return fn(callback, delay, options)
end

return {
	useLatestCallback = useLatestCallback,
	useDebounceCallback = useDebounceCallback,
	useDebounceState = useDebounceState,
	usePrevious = usePrevious,
	useMountEffect = useMountEffect,
	useUpdateEffect = useUpdateEffect,
	useUnmountEffect = useUnmountEffect,
	useDeferEffect = useDeferEffect,
	useEventListener = useEventListener,
	useThrottleCallback = useThrottleCallback,
	useTimeout = useTimeout,
	useInterval = useInterval,
}
