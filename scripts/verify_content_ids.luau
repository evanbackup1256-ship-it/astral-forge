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

-- DV21 append gates (wave11): lab / achievements / story / mail ids must stay present.
assert(string.find(src, 'Id = "Wave9DailyClaim"', 1, true), "Lab.Orders must append Wave9DailyClaim")
assert(string.find(src, 'Id = "Wave9VaultLedger"', 1, true), "Lab.Orders must append Wave9VaultLedger")
assert(string.find(src, 'Id = "Wave10EchoVault"', 1, true), "Lab.Orders must append Wave10EchoVault")
assert(string.find(src, 'Id = "Wave10EconomyBags"', 1, true), "Lab.Orders must append Wave10EconomyBags")
assert(string.find(src, 'Id = "Wave11QuestSanitize"', 1, true), "Lab.Orders must append Wave11QuestSanitize")
assert(string.find(src, 'Id = "Wave11SanitizeBags"', 1, true), "Lab.Orders must append Wave11SanitizeBags")
assert(string.find(src, 'Id = "Wave12WheelMath"', 1, true), "Lab.Orders must append Wave12WheelMath")
assert(string.find(src, 'Id = "Wave12StorySoftMotion"', 1, true), "Lab.Orders must append Wave12StorySoftMotion")
assert(string.find(src, 'Id = "Wave13CommandMath"', 1, true), "Lab.Orders must append Wave13CommandMath")
assert(string.find(src, 'Id = "Wave13MailLabClips"', 1, true), "Lab.Orders must append Wave13MailLabClips")
assert(string.find(src, 'Id = "Wave14ProfileBags"', 1, true), "Lab.Orders must append Wave14ProfileBags")
assert(string.find(src, 'Id = "Wave14PageReadySoftMotion"', 1, true), "Lab.Orders must append Wave14PageReadySoftMotion")
assert(string.find(src, 'Id = "Wave15OpsMath"', 1, true), "Lab.Orders must append Wave15OpsMath")
assert(string.find(src, 'Id = "Wave15ItemsShopSoftMotion"', 1, true), "Lab.Orders must append Wave15ItemsShopSoftMotion")
assert(string.find(src, 'Id = "Wave16AnomalyOps"', 1, true), "Lab.Orders must append Wave16AnomalyOps")
assert(string.find(src, 'Id = "Wave16ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave16ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave17EchoEnsure"', 1, true), "Lab.Orders must append Wave17EchoEnsure")
assert(string.find(src, 'Id = "Wave17ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave17ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave18ConvergenceOps"', 1, true), "Lab.Orders must append Wave18ConvergenceOps")
assert(string.find(src, 'Id = "Wave18ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave18ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave19GuildGoal"', 1, true), "Lab.Orders must append Wave19GuildGoal")
assert(string.find(src, 'Id = "Wave19ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave19ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave20TradeOfferCoreXP"', 1, true), "Lab.Orders must append Wave20TradeOfferCoreXP")
assert(string.find(src, 'Id = "Wave20ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave20ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave21QuestClampProgress"', 1, true), "Lab.Orders must append Wave21QuestClampProgress")
assert(string.find(src, 'Id = "Wave21ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave21ClaimClipsSoftMotion")
assert(string.find(src, 'Id = "Wave21FirewallEchoExtract"', 1, true), "Lab.Orders must append Wave21FirewallEchoExtract")
assert(string.find(src, 'Id = "Wave21EnvelopeUtcExtract"', 1, true), "Lab.Orders must append Wave21EnvelopeUtcExtract")
assert(string.find(src, 'Id = "Wave22LabOrderProgress"', 1, true), "Lab.Orders must append Wave22LabOrderProgress")
assert(string.find(src, 'Id = "Wave22ClaimClipsSoftMotion"', 1, true), "Lab.Orders must append Wave22ClaimClipsSoftMotion")
-- Footgun: Wave16 briefly nested AnomalyOps inside Wave15ItemsShopSoftMotion — keep top-level.
do
	local wave15 = string.find(src, 'Id = "Wave15ItemsShopSoftMotion"', 1, true)
	local wave16 = string.find(src, 'Id = "Wave16AnomalyOps"', 1, true)
	assert(wave15 and wave16 and wave16 > wave15, "Wave16AnomalyOps must follow Wave15ItemsShopSoftMotion")
	local between = string.sub(src, wave15, wave16)
	assert(
		string.find(between, "Color = Color3.fromRGB(255, 190, 210),\n\t\t\t},", 1, true),
		"Wave15ItemsShopSoftMotion must close before Wave16AnomalyOps (no nested Lab.Orders)"
	)
end
assert(string.find(src, 'Id = "Wave9DailyStreakRunner"', 1, true), "Achievements must append Wave9DailyStreakRunner")
assert(string.find(src, 'Id = "Wave9StoryCourier"', 1, true), "Achievements must append Wave9StoryCourier")
assert(string.find(src, 'Id = "Wave10EchoArchivist"', 1, true), "Achievements must append Wave10EchoArchivist")
assert(string.find(src, 'Id = "Wave10SettingsCourier"', 1, true), "Achievements must append Wave10SettingsCourier")
assert(string.find(src, 'Id = "Wave11MissionCourier"', 1, true), "Achievements must append Wave11MissionCourier")
assert(string.find(src, 'Id = "Wave11SanitizeRunner"', 1, true), "Achievements must append Wave11SanitizeRunner")
assert(string.find(src, 'Id = "Wave12WheelCourier"', 1, true), "Achievements must append Wave12WheelCourier")
assert(string.find(src, 'Id = "Wave12SoftMotionRunner"', 1, true), "Achievements must append Wave12SoftMotionRunner")
assert(string.find(src, 'Id = "Wave13CommandCourier"', 1, true), "Achievements must append Wave13CommandCourier")
assert(string.find(src, 'Id = "Wave13MailClipRunner"', 1, true), "Achievements must append Wave13MailClipRunner")
assert(string.find(src, 'Id = "Wave14ProfileCourier"', 1, true), "Achievements must append Wave14ProfileCourier")
assert(string.find(src, 'Id = "Wave14SoftMotionRunner"', 1, true), "Achievements must append Wave14SoftMotionRunner")
assert(string.find(src, 'Id = "Wave15OpsCourier"', 1, true), "Achievements must append Wave15OpsCourier")
assert(string.find(src, 'Id = "Wave15SoftMotionRunner"', 1, true), "Achievements must append Wave15SoftMotionRunner")
assert(string.find(src, 'Id = "Wave16AnomalyCourier"', 1, true), "Achievements must append Wave16AnomalyCourier")
assert(string.find(src, 'Id = "Wave16ClaimClipRunner"', 1, true), "Achievements must append Wave16ClaimClipRunner")
assert(string.find(src, 'Id = "Wave17EchoCourier"', 1, true), "Achievements must append Wave17EchoCourier")
assert(string.find(src, 'Id = "Wave17ClaimClipRunner"', 1, true), "Achievements must append Wave17ClaimClipRunner")
assert(string.find(src, 'Id = "Wave18ConvergenceCourier"', 1, true), "Achievements must append Wave18ConvergenceCourier")
assert(string.find(src, 'Id = "Wave18ClaimClipRunner"', 1, true), "Achievements must append Wave18ClaimClipRunner")
assert(string.find(src, 'Id = "Wave19GuildCourier"', 1, true), "Achievements must append Wave19GuildCourier")
assert(string.find(src, 'Id = "Wave19ClaimClipRunner"', 1, true), "Achievements must append Wave19ClaimClipRunner")
assert(string.find(src, 'Id = "Wave20TradeCourier"', 1, true), "Achievements must append Wave20TradeCourier")
assert(string.find(src, 'Id = "Wave20ClaimClipRunner"', 1, true), "Achievements must append Wave20ClaimClipRunner")
assert(string.find(src, 'Id = "Wave21QuestCourier"', 1, true), "Achievements must append Wave21QuestCourier")
assert(string.find(src, 'Id = "Wave21ClaimClipRunner"', 1, true), "Achievements must append Wave21ClaimClipRunner")
assert(string.find(src, 'Id = "Wave21ExtractCourier"', 1, true), "Achievements must append Wave21ExtractCourier")
assert(string.find(src, 'Id = "Wave21ReadinessRunner"', 1, true), "Achievements must append Wave21ReadinessRunner")
assert(string.find(src, 'Id = "Wave22LabCourier"', 1, true), "Achievements must append Wave22LabCourier")
assert(string.find(src, 'Id = "Wave22ClaimClipRunner"', 1, true), "Achievements must append Wave22ClaimClipRunner")
assert(string.find(src, 'Id = "bug-content-wave9-brief"', 1, true), "Story must append bug-content-wave9-brief")
assert(string.find(src, 'Id = "wave10-harden-brief"', 1, true), "Story must append wave10-harden-brief")
assert(string.find(src, 'Id = "bug-content-wave11-brief"', 1, true), "Story must append bug-content-wave11-brief")
assert(string.find(src, 'Id = "wave12-harden-brief"', 1, true), "Story must append wave12-harden-brief")
assert(string.find(src, 'Id = "wave13-harden-brief"', 1, true), "Story must append wave13-harden-brief")
assert(string.find(src, 'Id = "wave14-harden-brief"', 1, true), "Story must append wave14-harden-brief")
assert(string.find(src, 'Id = "wave15-harden-brief"', 1, true), "Story must append wave15-harden-brief")
assert(string.find(src, 'Id = "wave16-harden-brief"', 1, true), "Story must append wave16-harden-brief")
assert(string.find(src, 'Id = "wave17-harden-brief"', 1, true), "Story must append wave17-harden-brief")
assert(string.find(src, 'Id = "wave18-harden-brief"', 1, true), "Story must append wave18-harden-brief")
assert(string.find(src, 'Id = "wave19-harden-brief"', 1, true), "Story must append wave19-harden-brief")
assert(string.find(src, 'Id = "wave20-harden-brief"', 1, true), "Story must append wave20-harden-brief")
assert(string.find(src, 'Id = "wave21-harden-brief"', 1, true), "Story must append wave21-harden-brief")
assert(string.find(src, 'Id = "wave21-extract-brief"', 1, true), "Story must append wave21-extract-brief")
assert(string.find(src, 'Id = "wave22-harden-brief"', 1, true), "Story must append wave22-harden-brief")
assert(string.find(src, 'Id = "wave22-extract-brief"', 1, true), "Story must append wave22-extract-brief")
assert(string.find(src, 'Id = "wave24-offline-brief"', 1, true), "Story must append wave24-offline-brief")
assert(string.find(src, 'Id = "wave25-offline-brief"', 1, true), "Story must append wave25-offline-brief")
assert(string.find(src, 'Id = "wave26-offline-brief"', 1, true), "Story must append wave26-offline-brief")
assert(string.find(src, 'Id = "wave27-offline-brief"', 1, true), "Story must append wave27-offline-brief")
assert(string.find(src, 'Id = "wave28-offline-brief"', 1, true), "Story must append wave28-offline-brief")
assert(string.find(src, 'Id = "wave29-offline-brief"', 1, true), "Story must append wave29-offline-brief")
assert(string.find(src, 'Id = "wave30-offline-brief"', 1, true), "Story must append wave30-offline-brief")
assert(string.find(src, 'Id = "wave31-offline-brief"', 1, true), "Story must append wave31-offline-brief")
assert(string.find(src, 'Id = "wave32-offline-brief"', 1, true), "Story must append wave32-offline-brief")
assert(string.find(src, 'Id = "wave33-offline-brief"', 1, true), "Story must append wave33-offline-brief")
assert(string.find(src, 'Id = "wave34-offline-brief"', 1, true), "Story must append wave34-offline-brief")
assert(string.find(src, 'Id = "wave35-offline-brief"', 1, true), "Story must append wave35-offline-brief")
assert(string.find(src, 'Id = "wave36-offline-brief"', 1, true), "Story must append wave36-offline-brief")
assert(string.find(src, 'Id = "wave37-offline-brief"', 1, true), "Story must append wave37-offline-brief")
assert(string.find(src, 'Id = "wave38-offline-brief"', 1, true), "Story must append wave38-offline-brief")
assert(string.find(src, 'Id = "wave39-offline-brief"', 1, true), "Story must append wave39-offline-brief")
assert(string.find(src, 'Id = "wave40-offline-brief"', 1, true), "Story must append wave40-offline-brief")
assert(string.find(src, 'Id = "wave41-offline-brief"', 1, true), "Story must append wave41-offline-brief")
assert(string.find(src, 'Id = "wave42-offline-brief"', 1, true), "Story must append wave42-offline-brief")
assert(string.find(src, 'Id = "wave43-offline-brief"', 1, true), "Story must append wave43-offline-brief")
assert(string.find(src, 'Id = "wave44-offline-brief"', 1, true), "Story must append wave44-offline-brief")
assert(string.find(src, 'Id = "update-5-1-bug-content-wave9"', 1, true), "Mail must append update-5-1-bug-content-wave9")
assert(string.find(src, 'Id = "update-5-1-wave10-harden"', 1, true), "Mail must append update-5-1-wave10-harden")
assert(string.find(src, 'Id = "update-5-1-bug-content-wave11"', 1, true), "Mail must append update-5-1-bug-content-wave11")
assert(string.find(src, 'Id = "update-5-1-wave12-harden"', 1, true), "Mail must append update-5-1-wave12-harden")
assert(string.find(src, 'Id = "update-5-1-wave13-harden"', 1, true), "Mail must append update-5-1-wave13-harden")
assert(string.find(src, 'Id = "update-5-1-wave14-harden"', 1, true), "Mail must append update-5-1-wave14-harden")
assert(string.find(src, 'Id = "update-5-1-wave15-harden"', 1, true), "Mail must append update-5-1-wave15-harden")
assert(string.find(src, 'Id = "update-5-1-wave16-harden"', 1, true), "Mail must append update-5-1-wave16-harden")
assert(string.find(src, 'Id = "update-5-1-wave17-harden"', 1, true), "Mail must append update-5-1-wave17-harden")
assert(string.find(src, 'Id = "update-5-1-wave18-harden"', 1, true), "Mail must append update-5-1-wave18-harden")
assert(string.find(src, 'Id = "update-5-1-wave19-harden"', 1, true), "Mail must append update-5-1-wave19-harden")
assert(string.find(src, 'Id = "update-5-1-wave20-harden"', 1, true), "Mail must append update-5-1-wave20-harden")
assert(string.find(src, 'Id = "update-5-1-wave21-harden"', 1, true), "Mail must append update-5-1-wave21-harden")
assert(string.find(src, 'Id = "update-5-1-wave21-extract"', 1, true), "Mail must append update-5-1-wave21-extract")
assert(string.find(src, 'Id = "update-5-1-wave22-harden"', 1, true), "Mail must append update-5-1-wave22-harden")
assert(string.find(src, 'Id = "update-5-1-wave22-extract"', 1, true), "Mail must append update-5-1-wave22-extract")
assert(string.find(src, 'Id = "update-5-1-wave24-offline"', 1, true), "Mail must append update-5-1-wave24-offline")
assert(string.find(src, 'Id = "update-5-1-wave25-offline"', 1, true), "Mail must append update-5-1-wave25-offline")
assert(string.find(src, 'Id = "update-5-1-wave26-offline"', 1, true), "Mail must append update-5-1-wave26-offline")
assert(string.find(src, 'Id = "update-5-1-wave27-offline"', 1, true), "Mail must append update-5-1-wave27-offline")
assert(string.find(src, 'Id = "update-5-1-wave28-offline"', 1, true), "Mail must append update-5-1-wave28-offline")
assert(string.find(src, 'Id = "update-5-1-wave29-offline"', 1, true), "Mail must append update-5-1-wave29-offline")
assert(string.find(src, 'Id = "update-5-1-wave30-offline"', 1, true), "Mail must append update-5-1-wave30-offline")
assert(string.find(src, 'Id = "update-5-1-wave31-offline"', 1, true), "Mail must append update-5-1-wave31-offline")
assert(string.find(src, 'Id = "update-5-1-wave32-offline"', 1, true), "Mail must append update-5-1-wave32-offline")
assert(string.find(src, 'Id = "update-5-1-wave33-offline"', 1, true), "Mail must append update-5-1-wave33-offline")
assert(string.find(src, 'Id = "update-5-1-wave34-offline"', 1, true), "Mail must append update-5-1-wave34-offline")
assert(string.find(src, 'Id = "update-5-1-wave35-offline"', 1, true), "Mail must append update-5-1-wave35-offline")
assert(string.find(src, 'Id = "update-5-1-wave36-offline"', 1, true), "Mail must append update-5-1-wave36-offline")
assert(string.find(src, 'Id = "update-5-1-wave37-offline"', 1, true), "Mail must append update-5-1-wave37-offline")
assert(string.find(src, 'Id = "update-5-1-wave38-offline"', 1, true), "Mail must append update-5-1-wave38-offline")
assert(string.find(src, 'Id = "update-5-1-wave39-offline"', 1, true), "Mail must append update-5-1-wave39-offline")
assert(string.find(src, 'Id = "update-5-1-wave40-offline"', 1, true), "Mail must append update-5-1-wave40-offline")
assert(string.find(src, 'Id = "update-5-1-wave41-offline"', 1, true), "Mail must append update-5-1-wave41-offline")
assert(string.find(src, 'Id = "update-5-1-wave42-offline"', 1, true), "Mail must append update-5-1-wave42-offline")
assert(string.find(src, 'Id = "update-5-1-wave43-offline"', 1, true), "Mail must append update-5-1-wave43-offline")
assert(string.find(src, 'Id = "update-5-1-wave44-offline"', 1, true), "Mail must append update-5-1-wave44-offline")

print("[INFO] [TEST] content ids unique; DataVersion 21; PlatformBadges zeroed")
