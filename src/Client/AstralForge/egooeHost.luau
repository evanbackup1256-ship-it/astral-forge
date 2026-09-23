local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local HOST_NAME = "AstralForgeEgooE"
local function loadEgooe()
	local include = ReplicatedStorage:FindFirstChild("rbxts_include")
	local _modules = include
	if _modules ~= nil then
		_modules = _modules:FindFirstChild("node_modules")
	end
	local modules = _modules
	local _scope = modules
	if _scope ~= nil then
		_scope = _scope:FindFirstChild("@rbxts")
	end
	local scope = _scope
	local _pack = scope
	if _pack ~= nil then
		_pack = _pack:FindFirstChild("egooe")
	end
	local pack = _pack
	local _out = pack
	if _out ~= nil then
		_out = _out:FindFirstChild("out")
	end
	local out = _out
	if out == nil or not out:IsA("ModuleScript") then
		return nil
	end
	local ok, loaded = pcall(function()
		return require(out)
	end)
	return if ok then loaded else nil
end
local function startEgooeHost(playerGui)
	if not RunService:IsStudio() then
		return function()
			return nil
		end
	end
	local hostGui = playerGui or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if hostGui == nil then
		return function()
			return nil
		end
	end
	local stale = hostGui:FindFirstChild(HOST_NAME)
	if stale ~= nil then
		stale:Destroy()
	end
	local layer = Instance.new("ScreenGui")
	layer.Name = HOST_NAME
	layer.ResetOnSpawn = false
	layer.IgnoreGuiInset = true
	layer.DisplayOrder = 240
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	layer.Parent = hostGui
	local api
	local node
	local open = false
	local showDemo = false
	local frames = 0
	local fps = 60
	local sampleAt = os.clock()
	local heartbeat
	local paint = function(dt)
		if api == nil then
			return nil
		end
		frames += 1
		local now = os.clock()
		if now - sampleAt >= 0.4 then
			fps = frames / math.max(0.001, now - sampleAt)
			frames = 0
			sampleAt = now
		end
		local player = Players.LocalPlayer
		api.start(node, function()
			if not open then
				return nil
			end
			local handle = api.window({
				title = "Astral Forge",
				closable = true,
				minimizable = true,
				movable = true,
				resizable = true,
				size = Vector2.new(340, 300),
				position = Vector2.new(18, 86),
			}, function()
				api.heading("Studio debug")
				api.separator()
				api.label(`FPS     {string.format("%.0f", fps)}  ({string.format("%.1f", dt * 1000)} ms)`)
				api.label(`Player  {player.Name}  ({player.UserId})`)
				api.label(`Mem     {string.format("%.1f", Stats:GetTotalMemoryUsageMb())} MB`)
				api.label(`Inst    {Stats.InstanceCount}`)
				api.space()
				api.label("F8 toggles this overlay. It is not the game UI.")
				api.separator()
				local gallery = api.checkbox("Widget gallery", {
					checked = showDemo,
				})
				if gallery:clicked() then
					showDemo = not showDemo
				end
				if api.button("Close overlay"):clicked() then
					open = false
				end
			end)
			if handle:closed() then
				open = false
			end
			if showDemo then
				api.demoWindow()
			end
		end)
	end
	local ensureHeartbeat = function()
		if heartbeat ~= nil then
			return nil
		end
		heartbeat = RunService.Heartbeat:Connect(paint)
	end
	local stopHeartbeat = function()
		local _result = heartbeat
		if _result ~= nil then
			_result:Disconnect()
		end
		heartbeat = nil
	end
	local setOpen = function(shouldOpen)
		if shouldOpen and api == nil then
			api = loadEgooe()
			if api == nil then
				return nil
			end
			node = api.new(layer)
		end
		open = shouldOpen and api ~= nil
		if open then
			ensureHeartbeat()
		else
			stopHeartbeat()
			for _, child in layer:GetChildren() do
				child:Destroy()
			end
		end
	end
	local input = UserInputService.InputBegan:Connect(function(inputObject, processed)
		if processed then
			return nil
		end
		if inputObject.KeyCode ~= Enum.KeyCode.F8 then
			return nil
		end
		setOpen(not open)
	end)
	return function()
		input:Disconnect()
		stopHeartbeat()
		layer:Destroy()
	end
end
return {
	startEgooeHost = startEgooeHost,
}
