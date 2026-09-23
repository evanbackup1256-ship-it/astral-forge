local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLog = require(script.Parent.log).ClientLog
local bootstrapRoot
local function installBundledRuntime()
	local include = ReplicatedStorage:FindFirstChild("rbxts_include")
	local _nodeModules = include
	if _nodeModules ~= nil then
		_nodeModules = _nodeModules:FindFirstChild("node_modules")
	end
	local nodeModules = _nodeModules
	if nodeModules == nil then
		return false
	end
	local _localFallback = script.Parent
	if _localFallback ~= nil then
		_localFallback = _localFallback:FindFirstChild("FrameworkRuntime")
	end
	local localFallback = _localFallback
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	local _replicatedFallback = astral
	if _replicatedFallback ~= nil then
		_replicatedFallback = _replicatedFallback:FindFirstChild("Vendor")
		if _replicatedFallback ~= nil then
			_replicatedFallback = _replicatedFallback:FindFirstChild("FlameworkRuntime")
		end
	end
	local replicatedFallback = _replicatedFallback
	local fallback = localFallback or replicatedFallback
	if fallback == nil then
		return false
	end
	local runtime = nodeModules:FindFirstChild("@flamework")
	local installed = false
	if runtime == nil then
		runtime = fallback:Clone()
		runtime.Name = "@flamework"
		runtime.Parent = nodeModules
		installed = true
	else
		local fillMissing
		fillMissing = function(target, source)
			for _, child in source:GetChildren() do
				local current = target:FindFirstChild(child.Name)
				if current == nil then
					child:Clone().Parent = target
					installed = true
				else
					fillMissing(current, child)
				end
			end
		end
		fillMissing(runtime, fallback)
	end
	if installed then
		ClientLog:debug("framework", "bundled runtime installed")
	end
	return true
end
local function hasFlameworkRuntime()
	local include = ReplicatedStorage:FindFirstChild("rbxts_include")
	local _nodeModules = include
	if _nodeModules ~= nil then
		_nodeModules = _nodeModules:FindFirstChild("node_modules")
	end
	local nodeModules = _nodeModules
	local _scope = nodeModules
	if _scope ~= nil then
		_scope = _scope:FindFirstChild("@flamework")
	end
	local scope = _scope
	local _coreOut = scope
	if _coreOut ~= nil then
		_coreOut = _coreOut:FindFirstChild("core")
		if _coreOut ~= nil then
			_coreOut = _coreOut:FindFirstChild("out")
		end
	end
	local coreOut = _coreOut
	local _componentsOut = scope
	if _componentsOut ~= nil then
		_componentsOut = _componentsOut:FindFirstChild("components")
		if _componentsOut ~= nil then
			_componentsOut = _componentsOut:FindFirstChild("out")
		end
	end
	local componentsOut = _componentsOut
	if coreOut == nil or componentsOut == nil then
		return false
	end
	for _, child in { "flamework", "metadata", "modding", "prelude", "reflect" } do
		if coreOut:FindFirstChild(child) == nil then
			return false
		end
	end
	for _, child in { "baseComponent", "componentTracker", "components", "utility" } do
		if componentsOut:FindFirstChild(child) == nil then
			return false
		end
	end
	return true
end
local function startFramework(root)
	if not hasFlameworkRuntime() then
		return false
	end
	ClientLog:once("framework-runtime", "framework", "flamework present")
	local _frameworkModule = script.Parent
	if _frameworkModule ~= nil then
		_frameworkModule = _frameworkModule:FindFirstChild("framework")
	end
	local frameworkModule = _frameworkModule
	if frameworkModule == nil or not frameworkModule:IsA("ModuleScript") then
		ClientLog:warn("framework", "framework module missing")
		return true
	end
	local loaded, runtime = pcall(function()
		return require(frameworkModule)
	end)
	if not loaded then
		ClientLog:warn("framework", `couldn't load framework: {tostring(runtime)}`)
		return true
	end
	local started, reason = pcall(function()
		return runtime.initializeClientFramework(root)
	end)
	if not started then
		ClientLog:warn("framework", `framework didn't start: {tostring(reason)}`)
	else
		ClientLog:once("framework-started", "framework", "framework started")
		task.spawn(function()
			local deadline = os.clock() + 5
			while root.Parent ~= nil and os.clock() < deadline do
				if root:GetAttribute("AstralFrameworkReady") == true then
					ClientLog:once("framework-ready", "framework", "ui root ready")
					return nil
				end
				task.wait(0.1)
			end
			if root.Parent ~= nil then
				ClientLog:warn("framework", "ui root did not attach")
			end
		end)
	end
	return true
end
local function initializeClientFramework(root)
	if bootstrapRoot == root and root.Parent ~= nil then
		return nil
	end
	bootstrapRoot = root
	installBundledRuntime()
	if startFramework(root) then
		return nil
	end
	ClientLog:debug("framework", "waiting for runtime")
	task.spawn(function()
		local deadline = os.clock() + 8
		while root.Parent ~= nil and os.clock() < deadline do
			installBundledRuntime()
			if startFramework(root) then
				return nil
			end
			task.wait(0.2)
		end
		ClientLog:warn("framework", "framework still missing after 8s — restart Rojo")
	end)
end
return {
	initializeClientFramework = initializeClientFramework,
}
