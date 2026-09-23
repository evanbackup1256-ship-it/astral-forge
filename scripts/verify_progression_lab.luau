--!strict
-- Pure-module extract guards: LabOrderMath / RebirthGate / ZoneUnlock.
-- Mirrors verify_extract_modules style — require under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local ZoneUnlock = require("../src/Shared/AstralForge/Shared/ZoneUnlock")
local LabOrderMath = require("../src/Server/AstralForge/Modules/LabOrderMath")
local RebirthGate = require("../src/Server/AstralForge/Modules/RebirthGate")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

-- --- LabOrderMath ------------------------------------------------------------
assert(LabOrderMath.TotalCells(0, 3, 5, 12) == 3, "base cells at 0 rebirths")
assert(LabOrderMath.TotalCells(9, 3, 5, 12) == 4, "one cell per 5 rebirths")
assert(LabOrderMath.TotalCells(1000, 3, 5, 12) == 12, "cells clamp to max")
assert(LabOrderMath.TotalCells(-4, 3, 5, 12) == 3, "negative rebirths → base")

local tapOrder = { Id = "TapShift", Kind = "Tap", BaseTarget = 10, PerRebirth = 2, Reward = { Kind = "Cash", Amount = 1 } }
assert(LabOrderMath.OrderTarget(tapOrder, 0) == 10, "tap target base")
assert(LabOrderMath.OrderTarget(tapOrder, 3) == 16, "tap target + rebirths")

local bankOrder = { Id = "Bank", Kind = "BankFlux", BaseTarget = 100, PerRebirth = 0, ProductionSeconds = 30, Reward = nil }
assert(LabOrderMath.OrderTarget(bankOrder, 5, 250) == 250, "bank uses injected steady target")
assert(LabOrderMath.OrderTarget(bankOrder, 5, 40) == 100, "bank floors at BaseTarget")

local orders = {
	{ Id = "A", Progress = 5, Target = 10, Claimed = false },
	{ Id = "B", Progress = 10, Target = 10, Claimed = false },
	{ Id = "C", Progress = 10, Target = 10, Claimed = true },
}
assert(LabOrderMath.CountReady(orders) == 1, "one ready order")
assert(LabOrderMath.IsReady(orders[2]) == true, "B ready")
assert(LabOrderMath.IsReady(orders[3]) == false, "C claimed not ready")

local byId = {
	A = { Id = "A", Kind = "Tap", BaseTarget = 10, PerRebirth = 0, Reward = "ra" },
	B = { Id = "B", Kind = "Tap", BaseTarget = 10, PerRebirth = 0, Reward = "rb" },
	C = { Id = "C", Kind = "BankFlux", BaseTarget = 10, PerRebirth = 0, Reward = "rc" },
}
assert(LabOrderMath.ApplyProgress(orders, byId, "Tap", 3) == true, "tap progress applied")
assert(orders[1].Progress == 8, "A progressed by 3")
assert(orders[2].Progress == 10, "B already at target stays")
assert(LabOrderMath.ApplyProgress(orders, byId, "Tap", 0) == false, "zero gain no-op")
assert(LabOrderMath.ApplyProgress(orders, byId, "BankFlux", 5) == false, "claimed C ignores progress")

local stringOrders = { { Id = "S", Progress = "9", Target = "10", Claimed = false } }
local stringById = { S = { Id = "S", Kind = "Tap", BaseTarget = 10 } }
assert(LabOrderMath.IsReady(stringOrders[1]) == false, "string 9/10 not ready")
assert(LabOrderMath.ApplyProgress(stringOrders, stringById, "Tap", 1) == true, "string progress applies")
assert(stringOrders[1].Progress == 10, "string progress coerced")

local ok, msg, reward = LabOrderMath.TryClaim(orders, byId, "missing")
assert(ok == false and msg == "That order is no longer on the board.", "missing order")

ok, msg, reward = LabOrderMath.TryClaim(orders, byId, "A")
assert(ok == false and msg == "That order is not finished yet.", "unfinished claim")

ok, msg, reward = LabOrderMath.TryClaim(orders, byId, "B")
assert(ok == true and msg == "Order paid." and reward == "rb", "claim ready B")
assert(orders[2].Claimed == true, "B marked claimed")

ok, msg, reward = LabOrderMath.TryClaim(orders, byId, "B")
assert(ok == false and msg == "That order has already been paid.", "double claim")

ok, msg, reward = LabOrderMath.TryClaim(orders, byId, "C")
assert(ok == false and msg == "That order has already been paid.", "pre-claimed C")

-- --- Lab Ensure / NormalizeRouting -------------------------------------------
local emptyLab = LabOrderMath.Ensure(nil, 12)
assert(emptyLab.Day == -1 and #emptyLab.Orders == 0, "nil Lab → empty bag")
assert(emptyLab.Routing.Production == 4 and emptyLab.Routing.Storage == 4 and emptyLab.Routing.Tap == 4, "default routing thirds")
local partialLab = LabOrderMath.Ensure({ Day = 3 }, 12)
assert(partialLab.Day == 3 and type(partialLab.Orders) == "table" and type(partialLab.Routing) == "table", "Day-only fills Orders/Routing")
local sameLab = LabOrderMath.Ensure(partialLab, 12)
assert(sameLab == partialLab, "Ensure mutates Lab in place")
local overflow = { Production = 10, Storage = 10, Tap = 10 }
assert(LabOrderMath.NormalizeRouting(overflow, LabOrderMath.CHANNEL_ORDER, 12) == true, "overflow changes routing")
assert(overflow.Production + overflow.Storage + overflow.Tap == 12, "overflow clamped to budget")
local clean = { Production = 2, Storage = 2, Tap = 2 }
assert(LabOrderMath.NormalizeRouting(clean, LabOrderMath.CHANNEL_ORDER, 12) == false, "in-budget no-op")

-- --- RebirthGate -------------------------------------------------------------
assert(RebirthGate.MeetsRequired(2, 2) == true, "exact rebirths meet")
assert(RebirthGate.MeetsRequired(1, 2) == false, "short rebirths fail")
assert(RebirthGate.MeetsRequired(5, nil) == true, "nil required → 0")
assert(RebirthGate.RequirementMessage(1) == "Requires 1 rebirths.", "requirement message")

local function lt(a, b)
	return OmegaMath.Lt(a, b)
end
local function gte(a, b)
	return OmegaMath.Gte(a, b)
end

local prestige = RebirthGate.PrestigeReward(OmegaMath, 50, 100, 0.55, lt)
assert(prestige == 0, "under requirement → 0")

prestige = RebirthGate.PrestigeReward(OmegaMath, 100, 100, 0.55, lt)
near(OmegaMath.ToNumber(prestige), 1, "exact requirement → 1 core")

prestige = RebirthGate.PrestigeReward(OmegaMath, 10_000, 100, 0.5, lt)
-- (10000/100)^0.5 = 10
near(OmegaMath.ToNumber(prestige), 10, "prestige pow reward")

assert(RebirthGate.CanRebirth(prestige, gte) == true, "can rebirth when reward >= 1")
assert(RebirthGate.CanRebirth(0, gte) == false, "cannot rebirth on 0")

assert(RebirthGate.StardustReward(100, 5, 4) == 50, "stardust sqrt*scale")
assert(RebirthGate.StardustReward(0, 5, 4) == 4, "stardust floors at minimum")
assert(RebirthGate.StardustReward(1, 5, 4) == 5, "stardust sqrt(1)*5")

-- --- ZoneUnlock --------------------------------------------------------------
local zone2 = { Id = 2, Name = "Nebula", RequiredRebirths = 2, CoreCost = 5, Cost = 1000 }
local flags = ZoneUnlock.Flags(1, 2, 5, 1000, zone2, gte)
assert(flags.Unlocked == false and flags.IsNext == true and flags.CanUnlock == true, "next zone unlockable")
assert(flags.RebirthOk and flags.CoresOk and flags.CashOk, "all resource checks pass")

flags = ZoneUnlock.Flags(1, 1, 5, 1000, zone2, gte)
assert(flags.CanUnlock == false and flags.RebirthOk == false, "rebirth gate blocks")

flags = ZoneUnlock.Flags(2, 9, 9, 9, zone2, gte)
assert(flags.Unlocked == true and flags.CanUnlock == false, "already unlocked")

local kind, err = ZoneUnlock.Evaluate(1, 2, 5, 1000, 2, zone2, lt)
assert(kind == "Unlock" and err == nil, "evaluate unlock")

kind, err = ZoneUnlock.Evaluate(2, 2, 5, 1000, 2, zone2, lt)
assert(kind == "Travel" and err == nil, "evaluate travel")

kind, err = ZoneUnlock.Evaluate(1, 2, 5, 1000, 4, zone2, lt)
assert(kind == "Error" and err == "Worlds must be unlocked in order.", "order gate")

kind, err = ZoneUnlock.Evaluate(1, 0, 5, 1000, 2, zone2, lt)
assert(kind == "Error" and err == "Requires 2 rebirths.", "rebirth error")

kind, err = ZoneUnlock.Evaluate(1, 2, 1, 1000, 2, zone2, lt)
assert(kind == "Error" and err == "Requires 5 astral cores.", "cores error")

kind, err = ZoneUnlock.Evaluate(1, 2, 5, 100, 2, zone2, lt)
assert(kind == "Error" and err == "NEED_MORE_FLUX", "flux sentinel")

-- --- Source wiring + HARD constraints ----------------------------------------
local labServiceSrc = fs.readFile("src/Server/AstralForge/Services/LabService.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local gameSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local labMathSrc = fs.readFile("src/Server/AstralForge/Modules/LabOrderMath.luau")
local rebirthSrc = fs.readFile("src/Server/AstralForge/Modules/RebirthGate.luau")
local zoneSrc = fs.readFile("src/Shared/AstralForge/Shared/ZoneUnlock.luau")

assert(string.find(labServiceSrc, "LabOrderMath.OrderTarget", 1, true), "LabService must delegate OrderTarget")
assert(string.find(labServiceSrc, "LabOrderMath.ApplyProgress", 1, true), "LabService must delegate ApplyProgress")
assert(string.find(labServiceSrc, "LabOrderMath.TryClaim", 1, true), "LabService must delegate TryClaim")
assert(string.find(labServiceSrc, "LabOrderMath.TotalCells", 1, true), "LabService must delegate TotalCells")
assert(string.find(labServiceSrc, "LabOrderMath.Ensure", 1, true), "LabService must nil-safe Lab via Ensure")
assert(string.find(labServiceSrc, "LabOrderMath.NormalizeRouting", 1, true), "LabService must delegate NormalizeRouting")
assert(string.find(dataSrc, "LabOrderMath.TotalCells", 1, true), "DataService must delegate TotalCells")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "DataService sanitize must rebuild Lab via Ensure")
assert(string.find(dataSrc, "LabOrderMath.NormalizeRouting", 1, true), "DataService sanitize must NormalizeRouting")
assert(string.find(economySrc, "RebirthGate.PrestigeReward", 1, true), "Economy must delegate PrestigeReward")
assert(string.find(gameSrc, "ZoneUnlock.Evaluate", 1, true), "GameService must delegate ZoneUnlock.Evaluate")
assert(string.find(gameSrc, "RebirthGate.CanRebirth", 1, true), "GameService must use CanRebirth")
assert(string.find(gameSrc, "RebirthGate.StardustReward", 1, true), "GameService must use StardustReward")
assert(string.find(gameSrc, "RebirthGate.MeetsRequired", 1, true), "GameService must use MeetsRequired")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { labServiceSrc, dataSrc, economySrc, gameSrc, labMathSrc, rebirthSrc, zoneSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(labMathSrc, "GetService", 1, true), "LabOrderMath must stay pure")
assert(not string.find(rebirthSrc, "GetService", 1, true), "RebirthGate must stay pure")
assert(not string.find(zoneSrc, "GetService", 1, true), "ZoneUnlock must stay pure")

print("[INFO] [TEST] progression/lab extract passed | LabOrderMath+RebirthGate+ZoneUnlock")
