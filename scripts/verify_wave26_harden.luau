--!strict
-- Wave26 offline residuals: Mailbox body FlatList, Items EnsureShop snapshot,
-- Boosts softMotion density, DV21 Story/Mail briefs.

local fs = require("@lune/fs")

local mailbox = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
assert(string.find(mailbox, "createElement(FlatList", 1, true), "Mailbox FlatList")
assert(not string.find(mailbox, 'createElement("scrollingframe"', 1, true), "Mailbox no raw scrollingframe")
assert(string.find(mailbox, 'Name = "MailClaimActions"', 1, true), "MailClaimActions")
do
	local hostStart = string.find(mailbox, 'Name = "MailClaimActions"', 1, true)
	assert(hostStart, "MailClaimActions missing")
	local hostSlice = string.sub(mailbox, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "MailClaimActions clips")
end
assert(string.find(mailbox, "overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2", 1, true), "Mailbox body overscan")

local ss = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(ss, "ProfileBagMath.EnsureItems(profile)", 1, true), "EnsureItems residual")
assert(string.find(ss, "ensureItemShop(profile)", 1, true), "ensureItemShop residual")
-- Snapshot must EnsureShop before RemainingStock on Keys-only Items.
do
	local snap = string.find(ss, "function GameService:_snapshot", 1, true)
	assert(snap, "snapshot missing")
	local stock = string.find(ss, "ShopGrantEligibility.RemainingStock", snap, true)
	assert(stock, "RemainingStock missing")
	local ensure = string.find(ss, "ensureItemShop(profile)", snap, true)
	assert(ensure ~= nil and ensure < stock, "ensureItemShop must precede RemainingStock in snapshot")
end
-- publicPlayerRecord must EnsureItems before Inventory iteration.
do
	local pub = string.find(ss, "local function publicPlayerRecord", 1, true)
	assert(pub, "publicPlayerRecord missing")
	local inv = string.find(ss, "items.Inventory", pub, true)
	assert(inv, "items.Inventory missing")
	local ensure = string.find(ss, "ProfileBagMath.EnsureItems(profile)", pub, true)
	assert(ensure ~= nil and ensure < inv, "EnsureItems must precede Inventory in publicPlayerRecord")
end

local boosts = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
local soft = 0
for _ in string.gmatch(boosts, "softMotion") do
	soft += 1
end
assert(soft >= 8, "Boosts softMotion density, got " .. tostring(soft))

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave26-offline-brief"', 1, true), "Story wave26")
assert(string.find(config, 'Id = "update-5-1-wave26-offline"', 1, true), "Mail wave26")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave26 harden residuals passed")
