--!nocheck
-- Desktop HUD layout codec: defaults for old saves, clamping, canonical round-trips, bad input.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local L = H.load("Shared/AstralForge/Shared/DesktopLayout")

local d = L.Decode("")
check(d["nav.side"] == 0 and d["top.order"] == "FDCPE" and d["island.x"] == L.DOCKED, "empty save decodes to defaults")
check(L.Encode(L.Defaults()) == "", "defaults encode to empty")
check(L.Normalize("") == "", "empty normalizes to empty")
check(L.Normalize("v1|x") == nil, "wrong version rejected")
check(L.Normalize(string.rep("a", 500)) == nil, "oversize rejected")

local custom = L.SetValue(L.Defaults(), "nav.side", 1)
custom = L.SetValue(custom, "nav.width", 73)
custom = L.SetValue(custom, "island.scale", 999)
custom = L.SetValue(custom, "combo.x", 0.25)
custom = L.SetValue(custom, "combo.y", 1.7)
custom = L.SetValue(custom, "top.order", "PEDCF")
custom = L.SetValue(custom, "top.order", "FFFFF")
custom = L.SetValue(custom, "bogus", 1)
check(custom["nav.width"] == 75, "width snaps to step")
check(custom["island.scale"] == 125, "scale clamps to max")
check(custom["combo.y"] == 1, "unit clamps to 1")
check(custom["top.order"] == "PEDCF", "bad order ignored, good kept")
check(custom.bogus == nil, "unknown key ignored")

local encoded = L.Encode(custom)
check(#encoded <= L.MAX_LENGTH, "encoded fits")
local back = L.Decode(encoded)
for _, field in L.FIELDS do
	check(back[field.key] == custom[field.key], "round trip " .. field.key)
end
check(L.Normalize(encoded) == encoded, "canonical string is stable")

-- half a position falls back to docked
local half = L.Decode("d1|island.x=0.400")
check(half["island.x"] == L.DOCKED and half["island.y"] == L.DOCKED, "half spot docks")
-- junk entries are dropped, good ones kept
local junk = L.Decode("d1|nav.side=1|nav.width=abc|zzz=1|page.width=10")
check(junk["nav.side"] == 1 and junk["nav.width"] == 0 and junk["page.width"] == 70, "junk dropped, page width clamped")

local reset = L.ResetElement(custom, "nav")
check(reset["nav.side"] == 0 and reset["nav.width"] == 0 and reset["island.scale"] == 125, "element reset only touches its fields")
check(L.IsCustom(custom, "nav") and not L.IsCustom(reset, "nav") and L.IsCustom(reset), "IsCustom")

local plan = L.Resolve(custom, 1920, 264, 74)
check(plan.navRight and plan.navWidth >= L.LIMITS.navMin and plan.navWidth <= L.LIMITS.navMax, "nav width in limits")
check(plan.topHeight == 74, "stock top height kept")
local narrow = L.Resolve(L.SetValue(L.Defaults(), "nav.width", 100), 800, 264, 74)
check(narrow.navWidth <= math.max(L.LIMITS.navMin, 240), "nav capped on narrow screens")
local tall = L.Resolve(L.SetValue(L.Defaults(), "top.height", 100), 1920, 264, 74)
check(tall.topHeight == L.LIMITS.topMax, "top height max")
check(L.Resolve(L.SetValue(L.Defaults(), "page.width", 70), 900, 264, 74).pageMax == L.LIMITS.pageMinWidth, "page width floor")

if #failures > 0 then
	error(("desktop layout: %d/%d failed\n  %s"):format(#failures, checks, table.concat(failures, "\n  ")))
end
print(("desktop layout: %d checks passed"):format(checks))
