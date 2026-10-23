--!nocheck
-- Shared Lune loader for the compiled LayoutGuard modules (out/Client/AstralForge/LayoutGuard).
-- The stock _out_loader only maps out/Shared and out/Server; `script` here is a path proxy.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local BASE = "out/Client/AstralForge/LayoutGuard"
local cache = {}
local load

local function proxy(path)
	local p = { __path = path }
	return setmetatable(p, {
		__index = function(self, key)
			if key == "Parent" then
				local parent = path:match("^(.*)/[^/]+$")
				return parent and proxy(parent) or nil
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name) return proxy(path .. "/" .. name) end
			end
			return proxy(path .. "/" .. key)
		end,
	})
end

local TS = {}
function TS.import(_script, parent, ...)
	local path = parent.__path
	for _, part in { ... } do path ..= "/" .. part end
	return load(path)
end

local stub = setmetatable({}, { __index = function(t) return function() return t end end })
local game = { GetService = function() return stub end }

load = function(path)
	if cache[path] ~= nil then return cache[path] end
	local file = fs.isFile(path .. ".luau") and path .. ".luau" or path .. "/init.luau"
	local selfScript = fs.isFile(path .. ".luau") and proxy(path) or proxy(path .. "/init")
	if not fs.isFile(path .. ".luau") then
		-- init.luau: script is the folder itself, script.Parent its parent
		selfScript = proxy(path)
	end
	local env = setmetatable({
		game = game,
		script = selfScript,
		task = task,
		require = function() return TS end,
	}, { __index = getfenv() })
	local result = luau.load(fs.readFile(file), { chunkName = file, environment = env })()
	cache[path] = result
	return result
end

return { load = load, BASE = BASE }
