--!strict
-- Story fixture: every achievement in StorySnapshot.ts carries the same Name and
-- Description as GameConfig, so the preview never shows a stale label.

local fs = require("@lune/fs")

-- the text of `Achievements: {`/`[` up to its matching close, so ids shared with
-- shop items or machines elsewhere in the file can't be mixed in
local function achievementBlock(source: string): string
	local start = string.find(source, "\n%s*Achievements: [%[{]")
	assert(start, "no Achievements block found")
	local open = string.find(source, "[%[{]", start) :: number
	local depth = 0
	for i = open, #source do
		local c = string.sub(source, i, i)
		if c == "{" or c == "[" then
			depth += 1
		elseif c == "}" or c == "]" then
			depth -= 1
			if depth == 0 then
				return string.sub(source, open, i)
			end
		end
	end
	error("Achievements block never closes")
end

local function rows(source: string): { [string]: { name: string?, desc: string? } }
	local out = {}
	local lines = string.split(source, "\n")
	for i, line in lines do
		local id = string.match(line, '^%s*Id: "(%w+)",')
		if id then
			local entry: { name: string?, desc: string? } = {}
			for k = math.max(1, i - 4), math.min(#lines, i + 4) do
				local indent = string.match(lines[k], "^(%s*)") :: string
				if indent == string.match(line, "^(%s*)") then
					entry.name = entry.name or string.match(lines[k], '^%s*Name: "(.-)",?$')
					entry.desc = entry.desc or string.match(lines[k], '^%s*Description: "(.-)",?$')
				end
			end
			out[id] = entry
		end
	end
	return out
end

local config = rows(achievementBlock(fs.readFile("src/Shared/AstralForge/Shared/GameConfig.ts")))
local fixture = rows(achievementBlock(fs.readFile("src/Stories/StorySnapshot.ts")))

local checked, failures = 0, {}
for id, shown in fixture do
	local real = config[id]
	if real and real.name and shown.name then
		checked += 1
		if shown.name ~= real.name then
			table.insert(failures, `{id}: fixture name "{shown.name}" vs config "{real.name}"`)
		end
		if shown.desc and real.desc and shown.desc ~= real.desc then
			table.insert(failures, `{id}: fixture description is out of date`)
		end
	end
end

assert(checked >= 20, `story fixture check matched only {checked} entries`)
if #failures > 0 then
	error("Story fixture drifted from GameConfig:\n  " .. table.concat(failures, "\n  "))
end
print(`story fixture: {checked} entries match GameConfig`)
