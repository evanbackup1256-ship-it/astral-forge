--!strict
-- Offline gates for RemoteFirewall coerce/extract + DataService sanitize residuals.
-- Mirrors verify_settle_sanitize style: string markers + lightweight pure logic. No Studio.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local firewallSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

------------------------------------------------------------------------
-- RemoteFirewall: user-id coerce/extract + quarantine + action allowlist
------------------------------------------------------------------------
assert(string.find(firewallSrc, "local function coerceUserId", 1, true), "RemoteFirewall must define coerceUserId")
assert(string.find(firewallSrc, "local function extractUserId", 1, true), "RemoteFirewall must define extractUserId")
assert(string.find(firewallSrc, "Firewall.CoerceUserId = coerceUserId", 1, true), "CoerceUserId must be exported")
assert(string.find(firewallSrc, "Firewall.ExtractUserId = extractUserId", 1, true), "ExtractUserId must be exported")
assert(string.find(firewallSrc, "TargetUserId", 1, true), "extractUserId must read TargetUserId")
assert(string.find(firewallSrc, "MAX_SAFE_USER_ID", 1, true), "coerce must bound safe integer ids")
assert(string.find(firewallSrc, "QuarantineUntil", 1, true), "firewall must track quarantine")
assert(string.find(firewallSrc, "function Firewall:Check", 1, true), "Firewall:Check must remain entry")
assert(string.find(firewallSrc, "function Firewall:Forget", 1, true), "Firewall:Forget must clear player state")
assert(string.find(firewallSrc, "CLIENT_SIGNAL_RULES", 1, true), "client integrity signal allowlist must stay")

-- Pure coerce replica (mirrors RemoteFirewall.coerceUserId numeric path; no Instance).
local MAX_SAFE_USER_ID = 9007199254740991
local MIN_SAFE_USER_ID = -9007199254740991
local function coerceUserId(raw: any, studio: boolean?): number?
	local value = raw
	if type(value) == "string" then
		local trimmed = string.match(value, "^%s*(%-?%d+)%s*$")
		if not trimmed then
			return nil
		end
		value = tonumber(trimmed)
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local rounded = if value >= 0 then math.floor(value + 0.5) else math.ceil(value - 0.5)
	if math.abs(value - rounded) > 1e-6 then
		return nil
	end
	if rounded == 0 then
		return nil
	end
	if rounded < MIN_SAFE_USER_ID or rounded > MAX_SAFE_USER_ID then
		return nil
	end
	if studio ~= true and rounded < 1 then
		return nil
	end
	return rounded
end
assert(coerceUserId(42) == 42, "positive id ok")
assert(coerceUserId(" 99 ") == 99, "trimmed string id ok")
assert(coerceUserId(0) == nil, "zero rejected")
assert(coerceUserId(1.5) == nil, "non-integer rejected")
assert(coerceUserId(-3) == nil, "live negative rejected")
assert(coerceUserId(-3, true) == -3, "Studio negative allowed")
assert(coerceUserId("nope") == nil, "garbage string rejected")

local function extractUserId(payload: any): any
	if payload == nil then
		return nil
	end
	if type(payload) == "number" or type(payload) == "string" then
		return payload
	end
	if type(payload) ~= "table" then
		return nil
	end
	local raw = payload.UserId
	if raw == nil then
		raw = payload.userId
	end
	if raw == nil then
		raw = payload.Id
	end
	if raw == nil then
		raw = payload.TargetUserId
	end
	return raw
end
assert(extractUserId({ TargetUserId = 7 }) == 7, "TargetUserId extracted")
assert(extractUserId({ userId = "8" }) == "8", "userId extracted")
assert(coerceUserId(extractUserId({ UserId = "12" })) == 12, "coerce∘extract roundtrip")

------------------------------------------------------------------------
-- DataService sanitize residuals (boost bag + guild/anomaly/mailbox)
------------------------------------------------------------------------
assert(string.find(dataSrc, "local function sanitize(profile)", 1, true), "DataService sanitize must exist")
assert(string.find(dataSrc, "profile.BoostInventory", 1, true), "sanitize must harden BoostInventory")
assert(string.find(dataSrc, "profile.ActiveBoost", 1, true), "sanitize must harden ActiveBoost")
assert(string.find(dataSrc, "GameConfig.Boosts[boostId]", 1, true), "BoostInventory must drop unknown boost ids")
assert(string.find(dataSrc, "profile.Guild", 1, true), "sanitize must harden Guild bag")
assert(string.find(dataSrc, "profile.GuildBonuses", 1, true), "sanitize must harden GuildBonuses")
assert(string.find(dataSrc, "profile.Anomaly", 1, true), "sanitize must harden Anomaly bag")
assert(string.find(dataSrc, "profile.Anomaly.Loadout", 1, true), "sanitize must harden Anomaly.Loadout")
assert(string.find(dataSrc, "profile.Mailbox", 1, true) or string.find(dataSrc, "Mailbox.Read", 1, true), "sanitize must touch Mailbox collections")
assert(string.find(dataSrc, "profile.Trade.Sent", 1, true), "sanitize must harden Trade.Sent")
assert(string.find(dataSrc, "ClaimedSteps", 1, true), "sanitize must harden ForgePath.ClaimedSteps")
-- wave11: ApplyReward Keys/Fragments/FreeSpins partial bags must not crash sanitize.
assert(string.find(dataSrc, 'type(profile.Items) ~= "table"', 1, true), "sanitize must rebuild Keys-only Items")
assert(string.find(dataSrc, 'type(profile.Anomaly.Protocols) ~= "table"', 1, true), "sanitize must rebuild Fragments-only Anomaly.Protocols")
assert(string.find(dataSrc, 'type(profile.Wheel) ~= "table"', 1, true), "sanitize must rebuild FreeSpins-only Wheel")
assert(string.find(dataSrc, 'type(profile.Quests) ~= "table"', 1, true), "sanitize must harden Quests")
assert(string.find(dataSrc, 'type(profile.TimedRewards) ~= "table"', 1, true), "sanitize must harden TimedRewards")
-- wave13: ApplyReward Signals seeds Command={Signals=N}; Studio fixtures may omit Lab.
assert(string.find(dataSrc, "CommandMath.Ensure", 1, true), "sanitize must rebuild Signals-only Command")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "sanitize must rebuild missing Lab")

------------------------------------------------------------------------
-- Config RemoteFirewall overrides stay present
------------------------------------------------------------------------
assert(string.find(configSrc, "RemoteFirewall = {", 1, true), "GameConfig.RemoteFirewall missing")
assert(string.find(configSrc, '["ActivateBoost"]', 1, true) or string.find(configSrc, 'ActivateBoost', 1, true), "ActivateBoost override missing")

------------------------------------------------------------------------
-- HARD constraints
------------------------------------------------------------------------
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in { firewallSrc, dataSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] RemoteFirewall + DataService residual gates passed")
