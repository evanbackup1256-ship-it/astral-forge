--!strict
-- Wrapped Text in view files that sits in a fixed-height box without shrink-to-fit.
-- On a 360px phone those are the lines that spill or clip. The files below are owned by
-- other workstreams and keep their current count as an allowance; any file going over
-- its allowance (every other file has 0) fails the build.

local fs = require("@lune/fs")
-- Windows checkouts (core.autocrlf) carry CRLF; patterns here anchor on \n and $
local function readFile(path: string): string return (string.gsub(fs.readFile(path), "\r", "")) end

local ROOT = "src/Client/AstralForge"
-- other workstreams own these; they're listed but not counted (day-a areas are counted since batch 30)
local SKIP = { "Settings", "Chat", "NameTag" }

local ALLOWED: { [string]: number } = {
	["src/Client/AstralForge/UiCore/CrateRevealOverlay.tsx"] = 1, -- crate workstream
	["src/Client/AstralForge/UiOverlays/MobileControls.ts"] = 1, -- mobile-shell workstream
}

local function skipped(path: string): boolean
	for _, word in SKIP do
		if string.find(path, word, 1, true) then
			return true
		end
	end
	return false
end

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

-- the Text props around a wrap flag: back to the opening `<Text` / `Text, {`, forward to `/>` or `})`
local function propsAround(source: string, at: number): string
	local from = at
	for i = at, math.max(1, at - 900), -1 do
		local s = string.sub(source, i, i + 5)
		if s == "<Text " or s == "<Text\n" or string.sub(source, i, i + 6) == "Text, {" then
			from = i
			break
		end
	end
	local close = string.find(source, "/>", at, true) or #source
	local brace = string.find(source, "}%)", at) or #source
	return string.sub(source, from, math.min(close, brace, at + 900))
end

local files = {}
walk(ROOT, files)
table.sort(files)

local total, perFile = 0, {}
for _, path in files do
	if not skipped(path) then
		local source = readFile(path)
		local count = 0
		local pos = 1
		while true do
			local s, e = string.find(source, "wrap[=:]%s*{?true", pos)
			if not s then
				break
			end
			local props = propsAround(source, s)
			local fits = string.find(props, "fit[=:]%s*{?true") ~= nil or string.find(props, "fit[=:]%s*{?stack") ~= nil
			local fixed = string.find(props, "UDim2%([^,]+,[^,]+,%s*0,%s*[%w_]") ~= nil
				or string.find(props, "fromOffset%(") ~= nil
			if fixed and not fits then
				count += 1
			end
			pos = (e :: number) + 1
		end
		if count > 0 then
			total += count
			table.insert(perFile, { path = path, count = count })
		end
	end
end

table.sort(perFile, function(a, b)
	return a.count > b.count
end)
local over, stale = {}, {}
local counted: { [string]: number } = {}
for _, entry in perFile do
	counted[entry.path] = entry.count
end
for path, allowed in ALLOWED do
	local count = counted[path] or 0
	if count < allowed then
		table.insert(stale, `{path}: {count} now (allowance {allowed})`)
	end
end
for _, entry in perFile do
	local allowed = ALLOWED[entry.path] or 0
	if entry.count > allowed then
		table.insert(over, `{entry.path}: {entry.count} (allowed {allowed})`)
	end
end
if #stale > 0 then
	table.sort(stale)
	-- someone fixed lines in an allowed file: lower its allowance so it can't creep back up
	error("Allowance is higher than needed; lower it in ALLOWED:\n  " .. table.concat(stale, "\n  "))
end
if #over > 0 then
	error(
		"Wrapped Text in a fixed-height box needs fit + minSize so it shrinks on phones:\n  "
			.. table.concat(over, "\n  ")
	)
end
print(`[TEST] text fit: {total} known wrapped lines without shrink-to-fit, all in allowed files`)
