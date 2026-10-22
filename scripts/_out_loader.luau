--!nocheck
-- Loads compiled roblox-ts modules from out/ under Lune: TS.import resolves ReplicatedStorage /
-- ServerScriptService style paths onto out/Shared and out/Server. Only for pure modules (no
-- services beyond the stubs below). Run `npx rbxtsc` first.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local cache = {}
local load

local function resolve(parts)
	-- parts after the service: e.g. { "AstralForge", "Shared", "Protocol" }
	return parts
end

local stub = setmetatable({}, { __index = function(t) return function() return t end end })
local TS = {}
function TS.import(_script, service, ...)
	local parts = { ... }
	local root = service and service.__root or "out/Shared"
	return load(root .. "/" .. table.concat(parts, "/"))
end
function TS.async(fn) return fn end
function TS.await(v) return v end

local function service(root)
	return { __root = root, WaitForChild = function(self, name) if name == "rbxts_include" then return { WaitForChild = function() return "RuntimeLib" end } end return self end, FindFirstChild = function(self) return self end }
end
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then return service("out/Shared") end
		if name == "ServerScriptService" or name == "ServerStorage" then return service("out/Server") end
		return stub
	end,
}

load = function(path)
	if cache[path] ~= nil then return cache[path] end
	local file = fs.isFile(path .. ".luau") and path .. ".luau" or path .. "/init.luau"
	local env = setmetatable({
		game = game,
		script = stub,
		task = task,
		require = function(x) if x == "RuntimeLib" then return TS end return TS end,
	}, { __index = getfenv() })
	local result = luau.load(fs.readFile(file), { chunkName = file, environment = env })()
	cache[path] = result
	return result
end

return load
