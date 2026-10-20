--!strict
-- roblox-ts compiled packages start with `local TS = _G[script]`, which only exists when the
-- module is loaded through include/TSImport. A plain require() of one fails at load time
-- ("attempt to index nil with 'import'") and takes the whole client UI down with it.

local fs = require("@lune/fs")

local PACKAGES = {
	{ needle = '["@rbxts"].bezierts', file = "vendor/@rbxts/bezierts/out.luau" },
	{ needle = '["@rbxts"]["3a"]', file = nil },
	{ needle = '["@rbxts"]["react-lifetime-component"].out', file = nil },
}

local bezier = fs.readFile("vendor/@rbxts/bezierts/out.luau")
assert(bezier:find("local TS = _G[script]", 1, true), "bezierts is a roblox-ts module (needs TSImport)")
assert(fs.isFile("include/TSImport.luau"), "the TSImport loader ships in rbxts_include")

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end
local files = {}
walk("src/Client", files)
walk("src/Shared", files)

local offenders = {}
for _, path in files do
	local source = fs.readFile(path)
	for _, package in PACKAGES do
		local start = 1
		while true do
			local at = string.find(source, package.needle, start, true)
			if at == nil then break end
			local lineStart = at
			while lineStart > 1 and string.sub(source, lineStart - 1, lineStart - 1) ~= "\n" do
				lineStart -= 1
			end
			local lineEnd = string.find(source, "\n", at, true) or #source
			local line = string.sub(source, lineStart, lineEnd)
			if string.find(line, "require(", 1, true) and not string.find(line, "importTsModule(", 1, true) then
				table.insert(offenders, path .. ": " .. line)
			end
			start = lineEnd + 1
		end
	end
end
assert(#offenders == 0, "roblox-ts packages must load through importTsModule:\n" .. table.concat(offenders, "\n"))
print("[TEST] ts imports: every roblox-ts package loads through TSImport passed")
