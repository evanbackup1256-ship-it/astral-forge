--!strict
-- Wave40 offline residuals: VisitSnapshot peel, DomainExpansion/Purchase overlay
-- softMotion gates, Boosts/Credits/Rebirth densify + DENSE floors, DV21 Story/Mail.

local fs = require("@lune/fs")

local visit = fs.readFile("src/Server/AstralForge/Modules/VisitSnapshot.luau")
assert(string.find(visit, "function VisitSnapshot.Build", 1, true), "VisitSnapshot.Build missing")
assert(string.find(visit, "MachineKinds", 1, true), "VisitSnapshot MachineKinds")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, 'WaitForChild("VisitSnapshot")', 1, true), "ServerServices requires VisitSnapshot")
assert(string.find(server, "VisitSnapshot.Build", 1, true), "ServerServices binds VisitSnapshot.Build")
-- Inline visit machine loop must leave the monolith builder body.
do
	local start = string.find(server, "local function buildVisitSnapshot", 1, true)
	assert(start, "buildVisitSnapshot wrapper missing")
	local slice = string.sub(server, start, start + 220)
	assert(string.find(slice, "VisitSnapshot.Build", 1, true), "buildVisitSnapshot must delegate")
	assert(not string.find(slice, "MachineKinds = machineCount", 1, true), "visit machine loop must leave ServerServices")
end

local domain = fs.readFile("src/Client/AstralForge/DomainExpansionOverlay.luau")
local purchase = fs.readFile("src/Client/AstralForge/purchaseOverlay.luau")
local boosts = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
local rebirth = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
assert(string.find(domain, "Canonical softMotion antilag gate — DomainExpansionOverlay", 1, true), "DomainExpansion softMotion")
assert(string.find(purchase, "Canonical softMotion antilag gate — PurchaseOverlay", 1, true), "Purchase softMotion")
assert(string.find(boosts, "Canonical softMotion antilag gate — BoostsView", 1, true), "Boosts softMotion")
assert(string.find(credits, "Canonical softMotion antilag gate — CreditsView", 1, true), "Credits softMotion")
assert(string.find(rebirth, "Canonical softMotion antilag gate — RebirthPanel", 1, true), "Rebirth softMotion")
assert(
	not string.find(rebirth, "local softMotion = reducedMotion or effectsPaused", 1, true),
	"Rebirth must keep effectsPaused off softMotion assignment"
)
do
	local soft = 0
	for _ in string.gmatch(domain, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "DomainExpansion softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(purchase, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Purchase softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(boosts, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Boosts softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(credits, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "Credits softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(rebirth, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "Rebirth softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/BoostsView.luau"] = 12', 1, true), "Boosts DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/CreditsView.luau"] = 10', 1, true), "Credits DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/RebirthPanel.luau"] = 12', 1, true), "Rebirth DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave40-offline-brief"', 1, true), "Story wave40")
assert(string.find(config, 'Id = "update-5-1-wave40-offline"', 1, true), "Mail wave40")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

-- Pure VisitSnapshot smoke (Economy stub).
local VisitSnapshot = require("../src/Server/AstralForge/Modules/VisitSnapshot")
local EconomyStub = {
	Production = function(_profile)
		return 12
	end,
	Capacity = function(_profile, _now)
		return 100
	end,
}
local fakePlayer = { UserId = 7, Name = "Tester", DisplayName = "Tester" }
local fakeProfile = {
	Zone = 1,
	CurrentZone = 1,
	Rebirths = 0,
	Cash = 0,
	Vault = 0,
	Cores = 0,
	Stardust = 0,
	LifetimeCash = 0,
	Machines = { Core = 2, Pump = 0 },
}
local snap = VisitSnapshot.Build(fakePlayer, fakeProfile, EconomyStub)
assert(snap.UserId == 7, "visit UserId")
assert(snap.Production == 12, "visit Production")
assert(snap.Capacity == 100, "visit Capacity")
assert(snap.Machines.Core == 2, "visit Machines")
assert(snap.MachineKinds == 1, "visit MachineKinds skips zero")

print("[INFO] [TEST] wave40 harden residuals passed")
