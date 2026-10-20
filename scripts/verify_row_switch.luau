--!strict
-- Landscape row switches: a page that gives phones in landscape a different row layout
-- (`rowStack = stack && !chrome.landscape`) has to use that same switch for the row it draws
-- AND for the list's spacing / height. Switching only one of them makes rows overlap or leave
-- gaps. Checked for every switch:
--  * a variable switch is passed to a row (`stack={rowStack}`) or picks a row size, and
--    also feeds a height / stride (`rowStack ? A : B` in a const ending in H / Height / Stride,
--    or inside an itemHeight / cellHeight stride's definition);
--  * a helper switch (`function fooRowStack(...)`) is called at least twice (row + list).

local fs = require("@lune/fs")

local ROOT = "src/Client/AstralForge"

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.tsx?$") then
			table.insert(out, path)
		end
	end
end

local files = {}
walk(ROOT, files)
table.sort(files)

local function count(source: string, pattern: string): number
	local n = 0
	for _ in string.gmatch(source, pattern) do
		n += 1
	end
	return n
end

local switches, failures = 0, {}
for _, path in files do
	local source = fs.readFile(path)
	for name in string.gmatch(source, "const%s+([%a_][%w_]*Stack)%s*=%s*[%w_.]*[Ss]tack%s*&&%s*!%s*[%w_.]*landscape") do
		switches += 1
		local word = "%f[%w_]" .. name .. "%f[^%w_]"
		local row = string.find(source, "stack={" .. name .. "}", 1, true) ~= nil
			or string.find(source, "stack:%s*" .. name .. "[,%s}]") ~= nil
		local height = false
		for line in string.gmatch(source, "[^\n]+") do
			if string.find(line, word) and (
				string.find(line, "const%s+[%a_][%w_]*[Hh]%s*=")
				or string.find(line, "const%s+[%a_][%w_]*Height%s*=")
				or string.find(line, "const%s+[%a_][%w_]*Stride%s*=")
				or string.find(line, "const%s+[%a_][%w_]*Columns?%s*=")
				or string.find(line, "const%s+columns%s*=")
			) then
				height = true
			end
		end
		if not row and count(source, word) >= 3 then
			-- used directly in this component's own JSX (it draws the rows itself)
			row = string.find(source, name .. "%s*%?") ~= nil
		end
		if not row then
			table.insert(failures, `{path}: {name} switches the list but no row is drawn with it`)
		end
		if not height then
			table.insert(failures, `{path}: {name} switches the rows but not the list's height / stride`)
		end
	end
	for name in string.gmatch(source, "function%s+([%a_][%w_]*[Ss]tack)%s*%([^)]*%)[^{]*{%s*return[^;]*landscape") do
		switches += 1
		local calls = count(source, "%f[%w_]" .. name .. "%(") - 1
		if calls < 2 then
			table.insert(failures, `{path}: {name}() is called {calls} time(s); the row and its list both need it`)
		end
	end
end

assert(switches >= 5, `row switch check found only {switches} landscape row switches`)
if #failures > 0 then
	error("Landscape row switch used on only one side:\n  " .. table.concat(failures, "\n  "))
end
print(`[TEST] row switch: {switches} landscape row switches drive both the rows and their lists`)
