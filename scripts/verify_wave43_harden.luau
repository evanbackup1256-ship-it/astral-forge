--!strict
-- Wave43 offline residuals: SnapshotEnvelopeMath peel from MainGame,
-- Chat/Convergence/StarGrid densify, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local envelope = fs.readFile("src/Client/AstralForge/snapshotEnvelopeMath.luau")
assert(string.find(envelope, "function SnapshotEnvelopeMath.IsFiniteNumber", 1, true), "IsFiniteNumber missing")
assert(string.find(envelope, "function SnapshotEnvelopeMath.IsPersist", 1, true), "IsPersist missing")
assert(string.find(envelope, "function SnapshotEnvelopeMath.IsValidEnvelope", 1, true), "IsValidEnvelope missing")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, 'require(script.Parent.snapshotEnvelopeMath)', 1, true), "MainGame requires snapshotEnvelopeMath")
assert(string.find(main, "SnapshotEnvelopeMath.IsValidEnvelope", 1, true), "MainGame uses IsValidEnvelope")
assert(not string.find(main, 'local numericKeys = { "Revision", "SnapshotId"', 1, true), "numericKeys must leave MainGame")
assert(not string.find(main, "local isFiniteNumber = function", 1, true), "isFiniteNumber must leave MainGame")

local chat = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
local convergence = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
local star = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
assert(string.find(chat, "Canonical softMotion antilag gate — MessageRow", 1, true), "MessageRow softMotion")
assert(string.find(chat, "Canonical softMotion antilag gate — ChatView", 1, true), "ChatView softMotion")
assert(string.find(convergence, "Canonical softMotion antilag gate — ConvergenceView", 1, true), "Convergence softMotion")
assert(string.find(convergence, "Canonical softMotion antilag gate — ConvergenceTier", 1, true), "ConvergenceTier softMotion")
assert(string.find(star, "Canonical softMotion antilag gate — BranchHeader", 1, true), "BranchHeader softMotion")
assert(string.find(star, "Canonical softMotion antilag gate — StarGridNode", 1, true), "StarGridNode softMotion")
do
	local soft = 0
	for _ in string.gmatch(chat, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Chat softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(convergence, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Convergence softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(star, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "StarGrid softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/ChatView.luau"] = 12', 1, true), "Chat DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ConvergenceView.luau"] = 12', 1, true), "Convergence DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/StarGridView.luau"] = 12', 1, true), "StarGrid DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave43-offline-brief"', 1, true), "Story wave43")
assert(string.find(config, 'Id = "update-5-1-wave43-offline"', 1, true), "Mail wave43")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local SnapshotEnvelopeMath = require("../src/Client/AstralForge/snapshotEnvelopeMath")
assert(SnapshotEnvelopeMath.IsFiniteNumber(1) == true, "finite ok")
assert(SnapshotEnvelopeMath.IsFiniteNumber(0 / 0) == false, "nan rejected")
assert(SnapshotEnvelopeMath.IsFiniteNumber(math.huge) == false, "inf rejected")
assert(SnapshotEnvelopeMath.IsPersist(0) == true, "persist zero")
assert(SnapshotEnvelopeMath.IsPersist(-1) == false, "persist negative")
assert(SnapshotEnvelopeMath.IsPersist("1e10") == true, "persist sci")
assert(SnapshotEnvelopeMath.IsPersist("inf") == true, "persist inf string")
assert(SnapshotEnvelopeMath.IsPersist("") == false, "persist empty")
assert(SnapshotEnvelopeMath.IsValidEnvelope(nil) == false, "nil envelope")
do
	local good = {
		Revision = 1,
		SnapshotId = 2,
		ServerTime = 3,
		Cores = 0,
		Stardust = 0,
		Rebirths = 0,
		Zone = 1,
		CurrentZone = 1,
		Cash = 0,
		Vault = 0,
		RunCash = 0,
		LifetimeCash = 0,
		Production = 0,
		Capacity = 0,
		Game = {},
		Machines = {},
		Research = {},
		Wheel = {},
		Daily = {},
		TimedRewards = {},
		Quests = {},
		Settings = {},
		Flags = {},
	}
	assert(SnapshotEnvelopeMath.IsValidEnvelope(good) == true, "good envelope")
	good.Revision = -1
	assert(SnapshotEnvelopeMath.IsValidEnvelope(good) == false, "negative revision")
end

print("[INFO] [TEST] wave43 harden residuals passed")
