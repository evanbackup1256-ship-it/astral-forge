-- Uniqueness + kind sanity for GameConfig content tables (DataVersion stays untouched).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Minimal Color3 stub so GameConfig loads under lune.
local env = {
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
	game = {
		GetService = function()
			error("GameConfig should not GetService during content id verify")
		end,
	},
}

-- GameConfig requires LiveOpsConfig via relative require path through Rojo tree.
-- Load a trimmed extractor instead: parse Id fields from the source text.
local src = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(src, "DataVersion = 21", 1, true), "DataVersion must remain 21")
assert(string.find(src, 'Version = "5.1.0"', 1, true), "display version should stay 5.1.0")

local function collect(sectionName)
	local pattern = sectionName .. " = %{(.-)\n\t%},"
	-- Prefer first occurrence for top-level tables.
	local startPos = string.find(src, "\n\t" .. sectionName .. " = {", 1, true)
	assert(startPos, "missing section " .. sectionName)
	local bodyStart = string.find(src, "{", startPos, true)
	local depth = 0
	local i = bodyStart
	while i <= #src do
		local ch = string.sub(src, i, i)
		if ch == "{" then
			depth += 1
		elseif ch == "}" then
			depth -= 1
			if depth == 0 then
				local body = string.sub(src, bodyStart + 1, i - 1)
				local ids = {}
				for id in string.gmatch(body, 'Id = "([^"]+)"') do
					table.insert(ids, id)
				end
				return ids
			end
		end
		i += 1
	end
	error("unclosed section " .. sectionName)
end

local function assertUnique(label, ids)
	local seen = {}
	for _, id in ids do
		assert(not seen[id], label .. " duplicate id: " .. id)
		seen[id] = true
	end
	assert(#ids > 0, label .. " empty")
	print(string.format("[INFO] [TEST] %s ids=%d", label, #ids))
end

-- Lab.Orders is nested; scan from Lab = 
local labStart = string.find(src, "\n\tLab = {", 1, true)
assert(labStart)
local ordersStart = string.find(src, "Orders = {", labStart, true)
local bodyStart = string.find(src, "{", ordersStart, true)
local depth = 0
local i = bodyStart
local labIds = {}
while i <= #src do
	local ch = string.sub(src, i, i)
	if ch == "{" then
		depth += 1
	elseif ch == "}" then
		depth -= 1
		if depth == 0 then
			local body = string.sub(src, bodyStart + 1, i - 1)
			for id in string.gmatch(body, 'Id = "([^"]+)"') do
				table.insert(labIds, id)
			end
			break
		end
	end
	i += 1
end
assertUnique("Lab.Orders", labIds)
assertUnique("Achievements", collect("Achievements"))
assertUnique("Story", collect("Story"))
assertUnique("Mail", collect("Mail"))

-- PlatformBadges stay zeroed
local badges = string.match(src, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
print("[INFO] [TEST] content ids unique; DataVersion 21; PlatformBadges zeroed")
