--!strict
-- Luau allows at most 200 locals live in one function. Studio compiles at O0
-- when the debugger is attached, where every local counts; O1+ folds some
-- away, so a function can compile under Lune's default and still fail in
-- Studio with "Out of local registers ... exceeded limit 200" -- which blanks
-- the whole client, because the failing module never loads.
--
-- That happened to AppShell (the app's root component): it sat 2 locals from
-- the limit and a 3-local edit took the client down. This keeps real headroom
-- in every long function of ours: it re-compiles each one at O0 with SPARE
-- extra locals and fails if any no longer fits.
--
-- Vendored libraries are skipped -- they compile, and they are not ours to edit.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SPARE = 8
-- Only long functions can approach 200 locals; short ones are not worth a compile.
local MIN_LINES = 120

local probed = 0
local tight: { string } = {}

local function scan(path: string)
	local lines = string.split((string.gsub(fs.readFile(path), "\r\n", "\n")), "\n")
	local headers: { number } = {}
	for i, line in lines do
		if string.match(line, "^%s*local function [%w_]+%(") or string.match(line, "^%s*function [%w_.:]+%(") then
			table.insert(headers, i)
		end
	end
	for index, at in headers do
		local nextAt = headers[index + 1] or #lines
		if nextAt - at < MIN_LINES then
			continue
		end
		probed += 1
		-- Extra locals right after the header stay live through the whole body,
		-- so this fits only if the function's worst point has SPARE to spare.
		local indent = (string.match(lines[at], "^(%s*)") or "") .. "\t"
		local copy = table.clone(lines)
		local headerEnd = at
		local depth = 0
		for i = at, #lines do
			for character in string.gmatch(lines[i], ".") do
				if character == "(" then depth += 1 end
				if character == ")" then depth -= 1 end
			end
			headerEnd = i
			if depth == 0 then break end
		end
		for k = SPARE, 1, -1 do
			table.insert(copy, headerEnd + 1, indent .. "local __headroom" .. k .. " = " .. k)
		end
		local ok = pcall(luau.compile, table.concat(copy, "\n"), { optimizationLevel = 0, debugLevel = 1 })
		if not ok then
			table.insert(tight, `{path}:{at} {(string.gsub(lines[at], "^%s+", ""))}`)
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
walk("src/Server")
walk("src/Shared")

assert(probed > 50, "expected to probe the project's long functions, found " .. tostring(probed))
if #tight > 0 then
	error(
		`{#tight} function(s) have fewer than {SPARE} spare locals at O0 -- one more edit could crash Studio:\n  `
			.. table.concat(tight, "\n  ")
	)
end

print(`[INFO] [TEST] register headroom passed | {probed} long functions keep {SPARE}+ spare locals at O0`)
