--!strict
-- Every key in a Roblox host element's props table (React.createElement("frame",
-- {...})) is assigned straight onto the Instance, and React-Roblox raises a
-- hard error ("Error applying initial props to Roblox Instance") on any key
-- that is not a real property -- the element, and whatever mounted it, fails.
--
-- Roblox properties are PascalCase, and React's only reserved keys are the
-- lowercase ref / key / children. So a lowercase key (layoutOrder) or a
-- capitalised reserved key (Key, Ref, Children) is always a bug. Both shipped:
-- SettingsView set `layoutOrder`, and every button notice pill set `Key`.
--
-- HARD: pure source scan -- no Roblox instances, no API dump needed.

local fs = require("@lune/fs")

local RESERVED = { ref = true, key = true, children = true }
local CAPITALISED_RESERVED = { Key = true, Ref = true, Children = true }

-- Top-level keys of the table literal whose "{" is at `open`.
local function tableKeys(src: string, open: number): { { key: string, at: number } }
	local keys = {}
	local depth = 0
	local i = open
	local n = #src
	local expectKey = false
	while i <= n do
		local c = string.sub(src, i, i)
		if c == "-" and string.sub(src, i, i + 1) == "--" then
			local nl = string.find(src, "\n", i, true)
			i = (nl or n) + 1
		elseif c == '"' or c == "'" or c == "`" then
			local j = i + 1
			while j <= n do
				local d = string.sub(src, j, j)
				if d == "\\" then
					j += 2
				elseif d == c then
					break
				else
					j += 1
				end
			end
			i = j + 1
			expectKey = false
		elseif c == "{" or c == "(" or c == "[" then
			depth += 1
			if depth == 1 then
				expectKey = true
			end
			i += 1
		elseif c == "}" or c == ")" or c == "]" then
			depth -= 1
			i += 1
			if depth == 0 then
				return keys
			end
		elseif depth == 1 and (c == "," or c == ";") then
			expectKey = true
			i += 1
		elseif depth == 1 and expectKey and string.match(c, "[%a_]") then
			local key, rest = string.match(src, "^([%a_][%w_]*)%s*()", i)
			if string.sub(src, rest :: number, rest :: number) == "=" and string.sub(src, (rest :: number) + 1, (rest :: number) + 1) ~= "=" then
				table.insert(keys, { key = key :: string, at = i })
			end
			expectKey = false
			i = rest :: number
		elseif string.match(c, "%s") then
			i += 1
		else
			expectKey = false
			i += 1
		end
	end
	return keys
end

local problems: { string } = {}
local elements = 0

local function scan(path: string)
	local src = string.gsub(fs.readFile(path), "\r\n", "\n")
	local pos = 1
	while true do
		local s, e, host = string.find(src, 'React%.createElement%(%s*"([%w_]+)"%s*,%s*{', pos)
		if not s then
			break
		end
		pos = (e :: number) + 1
		elements += 1
		for _, entry in tableKeys(src, e :: number) do
			local first = string.sub(entry.key, 1, 1)
			local bad = CAPITALISED_RESERVED[entry.key] or (first == string.lower(first) and not RESERVED[entry.key])
			if bad then
				local _, lines = string.gsub(string.sub(src, 1, entry.at), "\n", "")
				table.insert(problems, `{path}:{lines + 1} {host}.{entry.key}`)
			end
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= "Vendor" and name ~= "Packages" then
				walk(path)
			end
		elseif string.match(path, "%.luau$") then
			scan(path)
		end
	end
end

walk("src/Client")
walk("src/Shared")

assert(elements > 1000, "expected to scan the client's host elements, found " .. tostring(elements))
if #problems > 0 then
	error(`{#problems} host prop(s) are not Roblox properties and will throw on mount:\n  ` .. table.concat(problems, "\n  "))
end

print(`[INFO] [TEST] host props passed | {elements} host elements, every key PascalCase or reserved`)
