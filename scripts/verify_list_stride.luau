--!strict
-- Virtual lists place rows by a stride (itemHeight / cellHeight), separately from the size
-- each row draws itself at. When the two are written as separate literals they drift: batch 18
-- made phone mission rows 226px while the list still stepped 220px, so rows overlapped by 6px.
-- Hand-written list heights (`rows.size() * rowH + gaps`) are checked the same way, so the page
-- can't reserve a different height than its rows draw.
-- For every list here, the stride must
--  * not hard-code its own heights (no `stack ? 220 : 148` in the stride) unless the row is
--    sized by that very same name, and
--  * be built from a name the row's own size also uses (directly or through one `const`).

local fs = require("@lune/fs")

local ROOT = "src/Client/AstralForge"
local SKIP = { "MobileShell", "MobileControls", "Crate", "purchase", "CoreKit", "PagesSocial", "Guild", "Crew", "Rank", "Settings", "Playerlist", "PlayerList", "Chat" }
local IGNORE_NAMES = { stack = true, true_ = true, math = true, max = true, min = true, floor = true }

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

local function skipped(path: string): boolean
	for _, word in SKIP do
		if string.find(path, word, 1, true) then
			return true
		end
	end
	return false
end

local function definition(source: string, name: string): string?
	return string.match(source, "%f[%w_]const%s+" .. name .. "%s*[:%w%s]*=%s*([^;\n]+)")
		or string.match(source, "%f[%w_]let%s+" .. name .. "%s*[:%w%s]*=%s*([^;\n]+)")
end

local function names(expr: string): { string }
	local out = {}
	for word in string.gmatch(expr, "[%a_][%w_]*") do
		if not IGNORE_NAMES[word] and not string.match(word, "^[%l]*[Gg]ap$") and word ~= "GAP" then
			table.insert(out, word)
		end
	end
	return out
end

-- does `name` size something: used inside a UDim2(...) on a line that isn't its definition,
-- or feeds a const that does
local function sizesRows(source: string, name: string, depth: number): boolean
	for line in string.gmatch(source, "[^\n]+") do
		if string.find(line, "%f[%w_]" .. name .. "%f[^%w_]") and not string.find(line, "const%s+" .. name .. "%f[^%w_]") then
			if string.find(line, "UDim2") then
				return true
			end
			local alias = string.match(line, "const%s+([%a_][%w_]*)%s*[:%w%s]*=")
			if depth > 0 and alias and alias ~= name and sizesRows(source, alias, depth - 1) then
				return true
			end
		end
	end
	return false
end

local files = {}
walk(ROOT, files)
table.sort(files)


local checked, failures = 0, {}

-- `stride` steps rows (a list's itemHeight / cellHeight) or multiplies a row count into a
-- hand-written list height; either way it has to come from the row's own height
local function check(path: string, source: string, what: string, stride: string)
	local expr = definition(source, stride)
	if not expr then
		return
	end
	checked += 1
	if string.find(expr, "%?%s*%d+%s*:") and not sizesRows(source, stride, 0) then
		table.insert(failures, `{path}: {what} {stride} hard-codes its heights ({expr})`)
		return
	end
	-- the stride's names, and one level of what those names are defined as
	local candidates = names(expr)
	for _, word in names(expr) do
		local inner = definition(source, word)
		if inner then
			for _, deeper in names(inner) do
				table.insert(candidates, deeper)
			end
		end
	end
	for _, word in candidates do
		if sizesRows(source, word, 1) then
			return
		end
	end
	if not sizesRows(source, stride, 1) then
		table.insert(failures, `{path}: {what} {stride} isn't built from the row's own height ({expr})`)
	end
end

for _, path in files do
	if not skipped(path) and not string.find(path, "LayoutKit", 1, true) then
		local source = fs.readFile(path)
		for prop, stride in string.gmatch(source, "(%a+Height)[=:]%s*{?([%a_][%w_]*)}?") do
			if prop == "itemHeight" or prop == "cellHeight" then
				check(path, source, prop, stride)
			end
		end
		-- list heights summed by hand: `rows.size() * rowH + math.max(0, rows.size() - 1) * gap`
		for stride in string.gmatch(source, "%*%s*([%a_][%w_]*)%s*%+%s*math%.max%(%s*0%s*,[^\n]-%-%s*1%s*%)%s*%*") do
			check(path, source, "list height", stride)
		end
	end
end

assert(checked >= 8, `list stride check found only {checked} lists`)
if #failures > 0 then
	error("List stride and row height can drift apart:\n  " .. table.concat(failures, "\n  "))
end
print(`[TEST] list stride: {checked} list strides and height sums use their row's own height`)
