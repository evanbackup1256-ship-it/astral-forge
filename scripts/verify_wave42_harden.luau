--!strict
-- Wave42 offline residuals: NoticeMath peel from MainGame, Missions/Worlds densify,
-- DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local notice = fs.readFile("src/Client/AstralForge/noticeMath.luau")
assert(string.find(notice, "function NoticeMath.NormalizeTitle", 1, true), "NormalizeTitle missing")
assert(string.find(notice, "function NoticeMath.Signature", 1, true), "Signature missing")
assert(string.find(notice, "function NoticeMath.ShouldDedupe", 1, true), "ShouldDedupe missing")
assert(string.find(notice, "function NoticeMath.Lifetime", 1, true), "Lifetime missing")
assert(string.find(notice, "function NoticeMath.MaxNotices", 1, true), "MaxNotices missing")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, 'require(script.Parent.noticeMath)', 1, true), "MainGame requires noticeMath")
assert(string.find(main, "NoticeMath.NormalizeTitle", 1, true), "MainGame uses NormalizeTitle")
assert(string.find(main, "NoticeMath.ShouldDedupe", 1, true), "MainGame uses ShouldDedupe")
assert(not string.find(main, 'if title == "Boost online" then "Boost on"', 1, true), "title normalize must leave MainGame")

local missions = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
local worlds = fs.readFile("src/Client/AstralForge/pages/WorldsView.luau")
assert(string.find(missions, "Canonical softMotion antilag gate — MissionsView", 1, true), "Missions softMotion")
assert(string.find(missions, "Canonical softMotion antilag gate — MissionRow", 1, true), "MissionRow softMotion")
assert(string.find(worlds, "Canonical softMotion antilag gate — Worlds", 1, true), "Worlds softMotion")
do
	local soft = 0
	for _ in string.gmatch(missions, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Missions softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(worlds, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Worlds softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/MissionsView.luau"] = 12', 1, true), "Missions DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/WorldsView.luau"] = 12', 1, true), "Worlds DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/RebirthPanel.luau"] = 12', 1, true), "Rebirth DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ChatView.luau"] = 12', 1, true), "Chat DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/StarGridView.luau"] = 12', 1, true), "StarGrid DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ConvergenceView.luau"] = 12', 1, true), "Convergence DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave42-offline-brief"', 1, true), "Story wave42")
assert(string.find(config, 'Id = "update-5-1-wave42-offline"', 1, true), "Mail wave42")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local NoticeMath = require("../src/Client/AstralForge/noticeMath")
assert(NoticeMath.NormalizeTitle("Boost online") == "Boost on", "normalize boost")
assert(NoticeMath.NormalizeTitle("Rebirth") == "Rebirth done", "normalize rebirth")
assert(NoticeMath.NormalizeTitle("Order paid") == "Claimed", "normalize order")
assert(NoticeMath.NormalizeTitle("Studio grant") == "Purchase test", "normalize grant")
assert(NoticeMath.NormalizeTitle("Hello") == "Hello", "normalize passthrough")
assert(NoticeMath.Signature("A", "B", "Info") == "A|B|Info", "signature")
assert(NoticeMath.ShouldDedupe("x", 1.0, "x", 1.2, 0.55) == true, "dedupe hit")
assert(NoticeMath.ShouldDedupe("x", 1.0, "x", 2.0, 0.55) == false, "dedupe miss")
assert(NoticeMath.ShouldDedupe("x", 1.0, "y", 1.1, 0.55) == false, "dedupe different")
assert(math.abs(NoticeMath.Lifetime(0.5) - (2.8 + 0.5 * 4.4)) < 1e-9, "lifetime")
assert(NoticeMath.MaxNotices(0) == 2, "max notices low")
assert(NoticeMath.MaxNotices(1) == 5, "max notices high")

print("[INFO] [TEST] wave42 harden residuals passed")
