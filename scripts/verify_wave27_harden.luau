--!strict
-- Wave27 offline residuals: InventoryMath direct calls, ContinuumDomain SnapshotDomainInts,
-- Trade/Credits softMotion density, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local inv = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
assert(not string.find(inv, "local function relicRowHeight", 1, true), "Inventory relicRowHeight wrapper must be gone")
assert(not string.find(inv, "local function rarityColor", 1, true), "Inventory rarityColor wrapper must be gone")
assert(not string.find(inv, "local function offerStock", 1, true), "Inventory offerStock wrapper must be gone")
assert(string.find(inv, "InventoryMath.RelicRowHeight", 1, true), "Inventory RelicRowHeight direct")
assert(string.find(inv, "InventoryMath.RarityColor", 1, true), "Inventory RarityColor direct")
assert(string.find(inv, "InventoryMath.OfferStock", 1, true), "Inventory OfferStock direct")
assert(string.find(inv, "InventoryMath.InspectSocketBlock", 1, true), "Inventory InspectSocketBlock direct")

local continuum = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuum, "function ContinuumDomainMath.NonNegativeInt", 1, true), "NonNegativeInt missing")
assert(string.find(continuum, "function ContinuumDomainMath.SnapshotDomainInts", 1, true), "SnapshotDomainInts missing")
assert(not string.find(continuum, "GetService", 1, true), "ContinuumDomainMath must stay pure")

local ss = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(ss, "ContinuumDomainMath.SnapshotDomainInts", 1, true), "SS SnapshotDomainInts residual")

local trade = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
local tradeSoft = 0
for _ in string.gmatch(trade, "softMotion") do
	tradeSoft += 1
end
assert(tradeSoft >= 10, "Trade softMotion density, got " .. tostring(tradeSoft))

local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
local creditsSoft = 0
for _ in string.gmatch(credits, "softMotion") do
	creditsSoft += 1
end
assert(creditsSoft >= 8, "Credits softMotion density, got " .. tostring(creditsSoft))

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave27-offline-brief"', 1, true), "Story wave27")
assert(string.find(config, 'Id = "update-5-1-wave27-offline"', 1, true), "Mail wave27")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave27 harden residuals passed")
