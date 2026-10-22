--!strict
-- Story fixture: every achievement in StorySnapshot.ts carries the same Name and
-- Description as GameConfig, so the preview never shows a stale label.

local fs = require("@lune/fs")

-- the text of `Achievements: {`/`[` up to its matching close, so ids shared with
-- shop items or machines elsewhere in the file can't be mixed in
local function findBlock(source: string, key: string?, opener: string?): string
	local name = key or "Achievements"
	local start = string.find(source, "\n%s*" .. name .. ": " .. (opener or "[%[{]"))
	assert(start, `no {name} block found`)
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
	error("block never closes")
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

local config = rows(findBlock(fs.readFile("src/Shared/AstralForge/Shared/GameConfig.ts")))
local fixture = rows(findBlock(fs.readFile("src/Stories/StorySnapshot.ts")))

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

-- Quests: the server builds daily quests from a fixed set of templates, so every
-- quest in the fixture must use a Name (and Description) that the server can send.
-- templates live in QuestEngine since rewrite 13; Progression still sends a few of its own
local progression = fs.readFile("src/Server/AstralForge/Services/Gameplay/Progression.ts")
	.. "\n" .. fs.readFile("src/Server/AstralForge/Modules/QuestEngine.ts")
local fixtureSource = fs.readFile("src/Stories/StorySnapshot.ts")
local questBlock = findBlock(fixtureSource, "Quests")
local questCount, questFailures = 0, {}
for _, line in string.split(questBlock, "\n") do
	local name = string.match(line, '^%s*Name: "(.-)",?$')
	if name then
		questCount += 1
		if not string.find(progression, `"{name}"`, 1, true) then
			table.insert(questFailures, `quest "{name}" isn't a name the server sends`)
		end
	end
	local desc = string.match(line, '^%s*Description: "(.-)",?$')
	if desc and not string.find(progression, `"{desc}"`, 1, true) then
		table.insert(questFailures, `quest description "{desc}" isn't one the server sends`)
	end
end
assert(questCount >= 1, "story fixture has no quests to check")

-- Chapters: every chapter id in the fixture is a real chapter in GameConfig.Story.
local storyIds = {}
for id in string.gmatch(findBlock(fs.readFile("src/Shared/AstralForge/Shared/GameConfig.ts"), "Story", "%["), '\n%s*Id: "([%w%-_]+)"') do
	storyIds[id] = true
end
local chapterBlock = string.match(fixtureSource, "\n\tStory: (%b{})")
assert(chapterBlock, "no top-level Story block in the fixture")
local chapterCount = 0
for id in string.gmatch(chapterBlock, '\n%s*Id: "([%w%-_]+)"') do
	chapterCount += 1
	if not storyIds[id] then
		table.insert(questFailures, `chapter "{id}" isn't in GameConfig.Story`)
	end
end
assert(chapterCount >= 5, `story fixture matched only {chapterCount} chapters`)
if #questFailures > 0 then
	error("Story fixture drifted:\n  " .. table.concat(questFailures, "\n  "))
end
print(`story fixture: {questCount} quests and {chapterCount} chapters match the game`)
