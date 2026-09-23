-- Uniqueness + kind sanity for GameConfig content tables (DataVersion stays untouched).
local fs = require("@lune/fs")

local src = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(src, "DataVersion = 21", 1, true), "DataVersion must remain 21")
assert(string.find(src, 'Version = "5.1.0"', 1, true), "display version should stay 5.1.0")

-- Match bare `Id = "..."` only — not suffixes like `CrateId` / `ItemId` / `TraitId`.
local ID_PATTERN = "([^%w_])Id = \"([^\"]+)\""

local function collectIds(body)
	local ids = {}
	for _prefix, id in string.gmatch(body, ID_PATTERN) do
		table.insert(ids, id)
	end
	return ids
end

local function extractSection(startNeedle)
	local startPos = string.find(src, startNeedle, 1, true)
	assert(startPos, "missing section " .. startNeedle)
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
				return string.sub(src, bodyStart + 1, i - 1)
			end
		end
		i += 1
	end
	error("unclosed section " .. startNeedle)
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

local labStart = string.find(src, "\n\tLab = {", 1, true)
assert(labStart)
local ordersStart = string.find(src, "Orders = {", labStart, true)
assert(ordersStart)
local ordersBodyStart = string.find(src, "{", ordersStart, true)
local depth = 0
local i = ordersBodyStart
local labBody
while i <= #src do
	local ch = string.sub(src, i, i)
	if ch == "{" then
		depth += 1
	elseif ch == "}" then
		depth -= 1
		if depth == 0 then
			labBody = string.sub(src, ordersBodyStart + 1, i - 1)
			break
		end
	end
	i += 1
end
assert(labBody, "Lab.Orders unclosed")
assertUnique("Lab.Orders", collectIds(labBody))
assertUnique("Achievements", collectIds(extractSection("\n\tAchievements = {")))
assertUnique("Story", collectIds(extractSection("\n\tStory = {")))
assertUnique("Mail", collectIds(extractSection("\n\tMail = {")))

-- Achievement Kind must be one AchievementProgress understands (Collects was a silent always-0).
do
	local VALID = {
		LifetimeCash = true,
		MachineLevels = true,
		ResearchLevels = true,
		Rebirths = true,
		Zone = true,
		PlayTime = true,
		AnomalyPulses = true,
		AnomalyStabilizations = true,
		AnomalyProtocols = true,
		ForgePathSteps = true,
		DailyStreak = true,
		WheelSpins = true,
		LabOrders = true,
		Expeditions = true,
		DomainRank = true,
		Domain = true,
		StoryClaims = true,
	}
	local achBody = extractSection("\n\tAchievements = {")
	for kind in string.gmatch(achBody, 'Kind = "([^"]+)"') do
		assert(VALID[kind], "Achievement Kind not tracked by AchievementProgress: " .. kind)
	end
end

-- PlatformBadges stay zeroed
local badges = string.match(src, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

-- Items.ShopOffers uniqueness (DV21 shop headroom). Do not match Crates[].Id via CrateId.
do
	local itemsStart = string.find(src, "\n\tItems = {", 1, true)
	assert(itemsStart, "Items section missing")
	local shopStart = string.find(src, "ShopOffers = {", itemsStart, true)
	assert(shopStart, "Items.ShopOffers missing")
	local bodyStart = string.find(src, "{", shopStart, true)
	local d = 0
	local j = bodyStart
	local shopBody
	while j <= #src do
		local ch = string.sub(src, j, j)
		if ch == "{" then
			d += 1
		elseif ch == "}" then
			d -= 1
			if d == 0 then
				shopBody = string.sub(src, bodyStart + 1, j - 1)
				break
			end
		end
		j += 1
	end
	assert(shopBody, "Items.ShopOffers unclosed")
	assertUnique("Items.ShopOffers", collectIds(shopBody))
end

-- DV21 append gates (wave9): lab / achievements / story / mail ids must stay present.
assert(string.find(src, 'Id = "Wave9DailyClaim"', 1, true), "Lab.Orders must append Wave9DailyClaim")
assert(string.find(src, 'Id = "Wave9VaultLedger"', 1, true), "Lab.Orders must append Wave9VaultLedger")
assert(string.find(src, 'Id = "Wave9DailyStreakRunner"', 1, true), "Achievements must append Wave9DailyStreakRunner")
assert(string.find(src, 'Id = "Wave9StoryCourier"', 1, true), "Achievements must append Wave9StoryCourier")
assert(string.find(src, 'Id = "bug-content-wave9-brief"', 1, true), "Story must append bug-content-wave9-brief")
assert(string.find(src, 'Id = "update-5-1-bug-content-wave9"', 1, true), "Mail must append update-5-1-bug-content-wave9")

print("[INFO] [TEST] content ids unique; DataVersion 21; PlatformBadges zeroed")
