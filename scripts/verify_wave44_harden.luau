--!strict
-- Wave44 offline residuals: UnlimitedMoneySeal + StoryMailSnapshot peels,
-- Overview/Feedback/Mailbox/Echo densify, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local money = fs.readFile("src/Server/AstralForge/Modules/UnlimitedMoneySeal.luau")
assert(string.find(money, "function UnlimitedMoneySeal.Apply", 1, true), "UnlimitedMoneySeal.Apply missing")
local storyMail = fs.readFile("src/Server/AstralForge/Modules/StoryMailSnapshot.luau")
assert(string.find(storyMail, "function StoryMailSnapshot.BuildStory", 1, true), "BuildStory missing")
assert(string.find(storyMail, "function StoryMailSnapshot.BuildMailbox", 1, true), "BuildMailbox missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, 'WaitForChild("UnlimitedMoneySeal")', 1, true), "ServerServices requires UnlimitedMoneySeal")
assert(string.find(services, 'WaitForChild("StoryMailSnapshot")', 1, true), "ServerServices requires StoryMailSnapshot")
assert(string.find(services, "UnlimitedMoneySeal.Apply", 1, true), "ServerServices uses UnlimitedMoneySeal.Apply")
assert(string.find(services, "StoryMailSnapshot.BuildStory", 1, true), "ServerServices uses BuildStory")
assert(string.find(services, "StoryMailSnapshot.BuildMailbox", 1, true), "ServerServices uses BuildMailbox")
assert(not string.find(services, "profile.Cash = MAX_SAFE_CURRENCY", 1, true), "cash seal must leave ServerServices")
assert(not string.find(services, "local storyState = {}", 1, true), "storyState builder must leave ServerServices")

local overview = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
local feedback = fs.readFile("src/Client/AstralForge/FeedbackOverlay.luau")
local mailbox = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
local echo = fs.readFile("src/Client/AstralForge/pages/EchoForgeView.luau")
assert(string.find(overview, "Canonical softMotion antilag gate — ReleaseCountdown", 1, true), "ReleaseCountdown softMotion")
assert(string.find(feedback, "Canonical softMotion antilag gate — FeedbackOverlay", 1, true), "Feedback softMotion")
assert(string.find(mailbox, "Canonical softMotion antilag gate — MailRow", 1, true), "MailRow softMotion")
assert(string.find(echo, "Canonical softMotion antilag gate — EchoCharge", 1, true), "EchoCharge softMotion")
do
	local soft = 0
	for _ in string.gmatch(overview, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Overview softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(feedback, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Feedback softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(mailbox, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Mailbox softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(echo, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Echo softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/MailboxView.luau"] = 12', 1, true), "Mailbox DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/EchoForgeView.luau"] = 12', 1, true), "Echo DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/OverviewView.luau"] = 12', 1, true), "Overview DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/FeedbackOverlay.luau"] = 12', 1, true), "Feedback DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/LeaderboardsView.luau"] = 12', 1, true), "Leaderboards DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave44-offline-brief"', 1, true), "Story wave44")
assert(string.find(config, 'Id = "update-5-1-wave44-offline"', 1, true), "Mail wave44")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local UnlimitedMoneySeal = require("../src/Server/AstralForge/Modules/UnlimitedMoneySeal")
local StoryMailSnapshot = require("../src/Server/AstralForge/Modules/StoryMailSnapshot")
do
	local profile = {
		Flags = { UnlimitedMoney = true },
		Cash = 1,
		RunCash = 2,
		LifetimeCash = 3,
	}
	local Economy = {
		Max = function(a, b)
			return math.max(a, b)
		end,
	}
	UnlimitedMoneySeal.Apply(profile, 1e308, Economy)
	assert(profile.Cash == 1e308, "cash sealed")
	assert(profile.RunCash == 1e308, "run sealed")
	assert(profile.LifetimeCash == 1e308, "lifetime sealed")
end
do
	local profile = {
		Story = { Read = { a = true }, Claimed = {} },
		Mailbox = { Deleted = {}, Read = { m1 = true }, Claimed = { m1 = true } },
	}
	local gate = {
		Progress = function(_profile, _kind)
			return 5
		end,
		Meets = function(_profile, _req)
			return true
		end,
	}
	local story = StoryMailSnapshot.BuildStory(profile, { { Id = "a", Kind = "Always", Target = 1 } }, gate)
	assert(story[1].Id == "a" and story[1].Unlocked == true and story[1].Read == true, "story row")
	local mail, unread = StoryMailSnapshot.BuildMailbox(profile, {
		{ Id = "m1", Requirement = nil },
		{ Id = "m2", Requirement = nil },
	}, gate)
	assert(#mail == 2 and unread == 1 and mail[1].Claimed == true, "mail rows")
end

print("[INFO] [TEST] wave44 harden residuals passed")
