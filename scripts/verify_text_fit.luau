--!strict
-- Report only: wrapped Text in view files that sits in a fixed-height box without
-- shrink-to-fit. On a 360px phone those are the lines that spill or clip. This never
-- fails the build; it prints a count and the worst files so the next sweep knows where to look.

local fs = require("@lune/fs")

local ROOT = "src/Client/AstralForge"
-- other workstreams own these; they're listed but not counted
local SKIP = { "Settings", "PlayerList", "Playerlist", "Chat", "NameTag", "Rank", "Guild", "CrewMember" }

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
		local source = fs.readFile(path)
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
print(`[REPORT] text fit: {total} wrapped lines in fixed boxes without shrink-to-fit`)
for i = 1, math.min(12, #perFile) do
	print(`  {perFile[i].count}  {perFile[i].path}`)
end
