--!nocheck
-- Loads compiled server/shared roblox-ts modules (out/) in Lune for tests: a fake instance tree
-- maps ServerScriptService / ReplicatedStorage onto out/ and include/, the real RuntimeLib does
-- TS.import, Flamework decorators are recorded and ignored, and Roblox services are small
-- stubs (Players, RunService, HttpService, ...) good enough for pure validation logic.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Harness = {}

-- a do-nothing value usable as any Roblox API: index, call and connect all succeed
local Stub
Stub = setmetatable({}, {
	__index = function() return Stub end,
	__call = function() return Stub end,
	__tostring = function() return "Stub" end,
})
local function signal()
	return { Connect = function() return { Disconnect = function() end, Connected = true } end, Wait = function() end, Once = function() return { Disconnect = function() end } end }
end

local node -- forward
local function newNode(name, className, parent, path, kind)
	local self = { Name = name, ClassName = className, Parent = parent, __path = path, __kind = kind, __children = {} }
	return setmetatable(self, Harness.InstanceMeta)
end

local function childPath(dir, name)
	for _, ext in { ".luau", ".lua" } do
		if fs.isFile(dir .. "/" .. name .. ext) then return dir .. "/" .. name .. ext, "file" end
	end
	if fs.isDir(dir .. "/" .. name) then return dir .. "/" .. name, "dir" end
	return nil
end

Harness.InstanceMeta = {
	__index = function(self, key)
		local method = Harness.Methods[key]
		if method then return method end
		if type(key) == "string" and key:sub(1, 2) ~= "__" then
			return Harness.Methods.FindFirstChild(self, key)
		end
		return nil
	end,
	__tostring = function(self) return self.Name end,
}
Harness.Methods = {
	FindFirstChild = function(self, name)
		local cached = self.__children[name]
		if cached then return cached end
		if self.__virtual and self.__virtual[name] then
			return self.__virtual[name]
		end
		return nil
	end,
	WaitForChild = function(self, name)
		local child = Harness.Methods.FindFirstChild(self, name)
		if not child then error("harness: " .. tostring(self.__path or self.Name) .. " has no child " .. tostring(name), 2) end
		return child
	end,
	IsA = function(self, class) return self.ClassName == class or class == "Instance" end,
	GetChildren = function() return {} end,
	GetAttribute = function() return nil end,
	SetAttribute = function() end,
	GetFullName = function(self) return self.__path or self.Name end,
	Destroy = function() end,
}

-- build the instance tree for a directory up front (fs calls cannot run inside metamethods)
local function scan(self)
	if not self.__path or not fs.isDir(self.__path) then return self end
	for _, entry in fs.readDir(self.__path) do
		local full = self.__path .. "/" .. entry
		local name, child = nil, nil
		if fs.isDir(full) then
			name = entry
			local isInit = fs.isFile(full .. "/init.luau") or fs.isFile(full .. "/init.lua")
			child = newNode(name, isInit and "ModuleScript" or "Folder", self, full, isInit and "initdir" or "dir")
			scan(child)
		else
			name = entry:match("^(.-)%.luau$") or entry:match("^(.-)%.lua$")
			if name and name ~= "init" then
				child = newNode(name, "ModuleScript", self, full, "file")
			end
		end
		if child and name then self.__children[name] = child end
	end
	return self
end

local services = {}
local ServerScriptService = scan(newNode("ServerScriptService", "ServerScriptService", nil, "out/Server", "dir"))
local ReplicatedStorage = newNode("ReplicatedStorage", "ReplicatedStorage", nil, nil, "virtual")
local include = scan(newNode("rbxts_include", "Folder", ReplicatedStorage, "include", "dir"))
local nodeModules = newNode("node_modules", "Folder", include, nil, "virtual")
local flameworkScope = newNode("@flamework", "Folder", nodeModules, nil, "virtual")
local flameworkCore = newNode("core", "Folder", flameworkScope, nil, "virtual")
local flameworkOut = newNode("out", "ModuleScript", flameworkCore, nil, "stub")
local rbxtsScope = newNode("@rbxts", "Folder", nodeModules, nil, "virtual")
flameworkCore.__virtual = { out = flameworkOut }
flameworkScope.__virtual = { core = flameworkCore }
nodeModules.__virtual = { ["@flamework"] = flameworkScope, ["@rbxts"] = rbxtsScope }
include.__virtual = { node_modules = nodeModules }
ReplicatedStorage.__virtual = {
	AstralForge = scan(newNode("AstralForge", "Folder", ReplicatedStorage, "out/Shared/AstralForge", "dir")),
	Packages = scan(newNode("Packages", "Folder", ReplicatedStorage, "out/Shared/Packages", "dir")),
	rbxts_include = include,
}
ReplicatedStorage.__kind = "virtual"

Harness.flamework = {
	Reflect = { defineMetadata = function() end, decorate = function() end, getMetadata = function() end },
	Flamework = { addPaths = function() end, ignite = function() end },
	Service = function() end,
	Controller = function() end,
	Dependency = function() return Harness.dependencies end,
	Modding = Stub,
}
Harness.dependencies = setmetatable({}, { __index = function() return Stub end })

local Players = { Name = "Players", ClassName = "Players", __players = {} }
Players.PlayerAdded = signal()
Players.PlayerRemoving = signal()
function Players:GetPlayers() return table.clone(self.__players) end
function Players:GetPlayerByUserId(id)
	for _, p in self.__players do if p.UserId == id then return p end end
	return nil
end
services.Players = Players

local RunService = { Heartbeat = signal(), Stepped = signal(), RenderStepped = signal() }
function RunService:IsStudio() return false end
function RunService:IsServer() return true end
function RunService:IsClient() return false end
function RunService:IsRunning() return false end
services.RunService = RunService

local HttpService = {}
function HttpService:JSONEncode(v) return serde.encode("json", v) end
function HttpService:JSONDecode(s) return serde.decode("json", s) end
local guid = 0
function HttpService:GenerateGUID() guid += 1 return string.format("GUID-%08d", guid) end
services.HttpService = HttpService

-- client modules (StarterPlayerScripts.AstralForge) for controller tests
local StarterPlayerScripts = newNode("StarterPlayerScripts", "StarterPlayerScripts", nil, nil, "virtual")
StarterPlayerScripts.__virtual = { AstralForge = scan(newNode("AstralForge", "Folder", StarterPlayerScripts, "out/Client/AstralForge", "dir")) }
services.StarterPlayer = { Name = "StarterPlayer", StarterPlayerScripts = StarterPlayerScripts }

services.ServerScriptService = ServerScriptService
services.ReplicatedStorage = ReplicatedStorage

local game = { Name = "game", JobId = "harness-job", PlaceId = 0, GameId = 0, PlaceVersion = 1 }
function game:GetService(name)
	return services[name] or Stub
end
game.Loaded = signal()
function game:IsLoaded() return true end
function game:BindToClose() end
Harness.game = game
Harness.Players = Players

local cache = {}
local env
local function requireNode(module)
	if type(module) ~= "table" then error("harness: require of non-instance", 2) end
	if module == flameworkOut then return Harness.flamework end
	if cache[module] ~= nil then return cache[module] end
	local path = module.__path
	if module.__kind == "initdir" then
		path = fs.isFile(path .. "/init.luau") and path .. "/init.luau" or path .. "/init.lua"
	end
	if not path or not fs.isFile(path) then error("harness: cannot require " .. tostring(module.__path or module.Name), 2) end
	-- the 5 MB generated config is too large for Lune's compiler; GameConfig falls back to its
	-- lazy generators (the same rows) when this require fails
	if path:find("GameConfigGenerated", 1, true) then
		error("harness: GameConfigGenerated skipped", 2)
	end
	local moduleEnv = table.clone(env)
	moduleEnv.script = module
	local chunk = luau.load(fs.readFile(path), { chunkName = path, environment = moduleEnv })
	local result = chunk()
	cache[module] = result
	return result
end

local InstanceLib = {
	new = function(className)
		local inst = { ClassName = className, Name = className, Event = signal(), Changed = signal() }
		function inst:Fire() end
		function inst:Invoke() end
		function inst:Destroy() end
		function inst:IsA(c) return c == className end
		function inst:GetAttribute() end
		function inst:SetAttribute() end
		return inst
	end,
}

-- Lune 0.8.9 can hang on exit after many task.cancel calls on pending task.delay threads, so
-- delays scheduled by game code are cancelled by flag: the thread still wakes, then does nothing.
local cancelledDelays = setmetatable({}, { __mode = "k" })
local harnessTask = table.clone(task)
function harnessTask.delay(seconds, fn, ...)
	local args = table.pack(...)
	local thread
	thread = task.delay(seconds, function()
		local cancelled = cancelledDelays[thread]
		cancelledDelays[thread] = nil
		if cancelled then
			return
		end
		fn(table.unpack(args, 1, args.n))
	end)
	cancelledDelays[thread] = false
	return thread
end
function harnessTask.cancel(thread)
	if cancelledDelays[thread] == false then
		cancelledDelays[thread] = true
		return
	end
	return task.cancel(thread)
end
Harness.task = harnessTask

env = {
	game = game,
	workspace = Stub,
	task = harnessTask,
	require = requireNode,
	Instance = InstanceLib,
	Enum = Stub,
	typeof = function(v) return type(v) == "table" and v.__typeof or typeof(v) end,
	warn = function() end,
	print = function() end,
	tick = os.clock,
	elapsedTime = os.clock,
	DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end },
	Random = { new = function(seed)
		local s = seed or 1
		return {
			NextNumber = function(_, a, b) s = (s * 1103515245 + 12345) % 2147483648; local r = s / 2147483648; return a and a + (b - a) * r or r end,
			NextInteger = function(_, a, b) s = (s * 1103515245 + 12345) % 2147483648; return a + s % (b - a + 1) end,
		}
	end },
	Vector3 = Stub, Vector2 = Stub, CFrame = Stub, Color3 = Stub, UDim2 = Stub, UDim = Stub,
	ColorSequence = Stub, NumberSequence = Stub, NumberRange = Stub, TweenInfo = Stub,
}
Harness.env = env

--- require a compiled module by its out/ path below Server or Shared, e.g. "Server/AstralForge/Modules/BazaarMath"
function Harness.load(relative)
	local parts = string.split(relative, "/")
	local current
	if parts[1] == "Server" then
		current = ServerScriptService
	elseif parts[1] == "Client" then
		current = StarterPlayerScripts
	elseif parts[1] == "Shared" then
		current = ReplicatedStorage.__virtual.AstralForge
		table.remove(parts, 1) -- "Shared"
		table.remove(parts, 1) -- "AstralForge"
		local rest = {}
		for i = 1, #parts do rest[i] = parts[i] end
		for _, name in rest do current = current:WaitForChild(name) end
		return requireNode(current)
	else
		error("harness: unknown root " .. relative)
	end
	for i = 2, #parts do current = current:WaitForChild(parts[i]) end
	return requireNode(current)
end

--- replace a compiled module with a test double before anything requires it
function Harness.mock(relative, value)
	local parts = string.split(relative, "/")
	local current = parts[1] == "Client" and StarterPlayerScripts or ServerScriptService
	for i = 2, #parts do current = current:WaitForChild(parts[i]) end
	cache[current] = value
end

--- a fake in-game player (Parent = Players)
local nextUserId = 1000
function Harness.player(name)
	nextUserId += 1
	local p = { Name = name or ("Player" .. nextUserId), DisplayName = name or "P", UserId = nextUserId, Parent = Players, ClassName = "Player", __typeof = "Instance" }
	local attrs = {}
	function p:GetAttribute(k) return attrs[k] end
	function p:SetAttribute(k, v) attrs[k] = v end
	function p:IsA(c) return c == "Player" or c == "Instance" end
	function p:Kick() end
	function p:IsInGroup() return false end
	function p:GetRankInGroup() return 0 end
	table.insert(Players.__players, p)
	return p
end

return Harness
