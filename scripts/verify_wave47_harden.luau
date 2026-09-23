--!strict
-- Wave47 offline residuals: Guild/Trade/Overcharge/Visit snapshot peels,
-- Leaderboards/Guild/Chat/Mailbox densify, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local guildMath = fs.readFile("src/Server/AstralForge/Modules/GuildMath.luau")
assert(string.find(guildMath, "function GuildMath.SnapshotPublic", 1, true), "GuildMath SnapshotPublic missing")
assert(string.find(guildMath, "function GuildMath.EmptyHall", 1, true), "GuildMath EmptyHall missing")

local tradeDesk = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
assert(string.find(tradeDesk, "function TradeDesk:StatePublic", 1, true), "TradeDesk StatePublic missing")
assert(string.find(tradeDesk, "function TradeDesk.LockedPublic", 1, true), "TradeDesk LockedPublic missing")

local overcharge = fs.readFile("src/Server/AstralForge/Modules/OverchargeCombo.luau")
assert(string.find(overcharge, "function OverchargeCombo.PublicSnapshot", 1, true), "OverchargeCombo PublicSnapshot missing")

local visit = fs.readFile("src/Server/AstralForge/Modules/VisitSnapshot.luau")
assert(string.find(visit, "function VisitSnapshot.Resolve", 1, true), "VisitSnapshot Resolve missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, "GuildMath.SnapshotPublic", 1, true), "ServerServices uses GuildMath.SnapshotPublic")
assert(string.find(services, "TradeDesk.LockedPublic", 1, true) or string.find(services, ":StatePublic(", 1, true), "ServerServices uses TradeDesk StatePublic")
assert(string.find(services, "OverchargeCombo.PublicSnapshot", 1, true), "ServerServices uses OverchargeCombo.PublicSnapshot")
assert(string.find(services, "VisitSnapshot.Resolve", 1, true), "ServerServices uses VisitSnapshot.Resolve")
assert(not string.find(services, "Guild = (function()", 1, true), "Guild IIFE must leave ServerServices")
assert(not string.find(services, "Trade = (function()", 1, true), "Trade IIFE must leave ServerServices")
assert(not string.find(services, "Visit = (function()", 1, true), "Visit IIFE must leave ServerServices")
assert(not string.find(services, 'Name = "Guild Hall"', 1, true), "Guild Hall fallback must leave ServerServices")

local leaderboards = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
local guild = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local chat = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
local mailbox = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
assert(string.find(leaderboards, "Canonical softMotion antilag gate — LeaderboardsBoard", 1, true), "LeaderboardsBoard softMotion")
assert(string.find(guild, "Canonical softMotion antilag gate — GuildBank", 1, true), "GuildBank softMotion")
assert(string.find(chat, "Canonical softMotion antilag gate — ChatComposer", 1, true), "ChatComposer softMotion")
assert(string.find(mailbox, "Canonical softMotion antilag gate — MailboxList", 1, true), "MailboxList softMotion")
do
	local soft = 0
	for _ in string.gmatch(leaderboards, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Leaderboards softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(guild, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Guild softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(chat, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Chat softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(mailbox, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Mailbox softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/ResearchView.luau"] = 12', 1, true), "Research DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/WheelView.luau"] = 12', 1, true), "Wheel DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/ForgePathView.luau"] = 12', 1, true), "ForgePath DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave47-offline-brief"', 1, true), "Story wave47")
assert(string.find(config, 'Id = "update-5-1-wave47-offline"', 1, true), "Mail wave47")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local GuildMath = require("../src/Server/AstralForge/Modules/GuildMath")
do
	assert(GuildMath.SnapshotPublic(nil, nil) == nil, "guild nil membership")
	assert(GuildMath.SnapshotPublic({ Id = "" }, nil) == nil, "guild empty id")
	local cached = { Id = "g1", Name = "Cached" }
	assert(GuildMath.SnapshotPublic({ Id = "g1" }, cached) == cached, "guild cached")
	local empty = GuildMath.SnapshotPublic({ Id = "g2", Tag = "AB" }, nil)
	assert(empty.Name == "Guild Hall" and empty.Tag == "AB", "guild empty hall")
end

local OverchargeCombo = require("../src/Server/AstralForge/Modules/OverchargeCombo")
do
	local bag = OverchargeCombo.PublicSnapshot({
		combo = 3,
		comboMultiplier = 1.3,
		comboMax = 10,
		comboWindow = 1.5,
		comboBonusPerStack = 0.1,
	})
	assert(bag.Combo == 3 and bag.ComboMax == 10 and bag.ComboWindow == 1.5, "overcharge public")
end

local VisitSnapshot = require("../src/Server/AstralForge/Modules/VisitSnapshot")
do
	assert(VisitSnapshot.Resolve(nil, {}, function()
		return nil
	end, {
		Production = function()
			return 0
		end,
		Capacity = function()
			return 0
		end,
	}) == nil, "visit nil host")
end

print("[INFO] [TEST] wave47 harden residuals passed")
