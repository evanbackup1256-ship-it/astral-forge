-- Lune-compatible kit loader for verify scripts.
-- Replaces the old merged-suite require("../src/Client/AstralForge/CoreKit")("member")
-- pattern with a callable table that reads the compiled roblox-ts output from out/.
-- Supports both directory kits (out/<Kit>/<member>.luau) and single-file kits
-- (out/<Kit>.luau with __defs["member"] closures).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

return function(kitName: string)
	local base = "out/Client/AstralForge/" .. kitName
	local isDir = fs.isDir(base)
	local isSingleFile = not isDir and fs.isFile(base .. ".luau")
	local cache = {}

	-- For single-file kits: load the whole kit once by requiring it.
	-- The compiled file uses __defs/makeKit pattern identical to the original Luau.
	-- If it has game:GetService, we need a sandbox approach.
	local singleFileKit = nil
	if isSingleFile then
		-- Try requiring the single file directly; if it crashes on game:GetService,
		-- fall back to text extraction of __defs members.
		local ok, result = pcall(function()
			return require("../" .. base)
		end)
		if ok and (type(result) == "table" or type(result) == "function") then
			singleFileKit = result
		else
			-- The kit uses game:GetService. Extract pure member closures from source text.
			-- Each member is wrapped as __defs["name"] = function() ... end and returns a
			-- module table. We load them individually by finding their __defs block.
			local source = fs.readFile(base .. ".luau")
			source = string.gsub(source, "\r\n", "\n")
			singleFileKit = setmetatable({}, {
				__call = function(_, memberName: string)
					if cache[memberName] ~= nil then
						return cache[memberName]
					end
					-- Find the member's __defs closure in the source
					-- Compiled TS uses __defs.name = function() while old Luau uses __defs["name"] = function()
					local header = `__defs.{memberName} = function()\n`
					local headerStart = string.find(source, header, 1, true)
					if not headerStart then
						header = `__defs["{memberName}"] = function()\n`
						headerStart = string.find(source, header, 1, true)
					end
					if not headerStart then
						error(kitName .. ": unknown member " .. memberName, 2)
					end
					local bodyStart = headerStart + #header
					-- Find the end: next __defs entry, or __members, or __load
					local nextDef = string.find(source, "\n__defs.", bodyStart, true)
					if not nextDef then
						nextDef = string.find(source, '\n__defs["', bodyStart, true)
					end
					local membersBlock = string.find(source, "\nlocal __members = {}", bodyStart, true)
					local loadBlock = string.find(source, "\nlocal function __load(", bodyStart, true)
					local endPos = math.min(
						nextDef or math.huge,
						membersBlock or math.huge,
						loadBlock or math.huge
					)
					local bodyEnd = if endPos == math.huge then #source else endPos - 1
					local body = string.sub(source, bodyStart, bodyEnd)
					-- Strip trailing `end` and any lines after it (comments, return nil, etc.)
					body = string.gsub(body, "\nend%s*\n.*$", "\n")
					body = string.gsub(body, "\nend%s*$", "\n")
					-- The member body is a self-contained function that returns a module.
					-- Wrap it in a function and execute it.
					local chunk = "return (function()\n" .. body .. "\nend)()"
					local fn, err = pcall(luau.load, chunk, { debugName = kitName .. "/" .. memberName })
					if fn then fn = err; err = nil else fn = nil end
					if not fn then
						error(kitName .. "/" .. memberName .. ": loadstring failed: " .. tostring(err), 2)
					end
					local mod = fn()
					cache[memberName] = mod
					return mod
				end,
				__index = function(_, key: string)
					if key == "__members" then
						local m = {}
						for name in string.gmatch(source, '__defs%.([%w_]+)%s*=') do
							table.insert(m, name)
						end
						if #m == 0 then
							for name in string.gmatch(source, '__defs%["([%w_]+)"%]') do
								table.insert(m, name)
							end
						end
						table.sort(m)
						return m
					end
					return nil
				end,
			})
		end
	end

	if singleFileKit then
		return singleFileKit
	end

	-- Directory kit: load individual member modules from out/<Kit>/<member>.luau
	local function load(memberName: string)
		if cache[memberName] ~= nil then
			return cache[memberName]
		end
		local path = base .. "/" .. memberName .. ".luau"
		local initPath = base .. "/" .. memberName .. "/init.luau"
		if not fs.isFile(path) and not fs.isFile(initPath) then
			error(kitName .. ": unknown module " .. tostring(memberName), 2)
		end
		local mod = require("../" .. base .. "/" .. memberName)
		cache[memberName] = mod
		return mod
	end
	-- __members: list compiled member names
	local members = {}
	if isDir then
		for _, name in fs.readDir(base) do
			local m = string.match(name, "^(.+)%.luau$")
			if m and m ~= "init" then
				table.insert(members, m)
			end
		end
	end
	table.sort(members)
	table.freeze(members)

	return setmetatable({}, {
		__call = function(_, name: string)
			return load(name)
		end,
		__index = function(_, name: string)
			if name == "__members" then
				return members
			end
			return load(name)
		end,
	})
end
