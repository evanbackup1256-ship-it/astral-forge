--!strict
-- Wave41 offline residuals: PublicPlayerRecord + SettingsSeal peels,
-- Research/Wheel/Chat/StarGrid densify, BootScreen/AdminPrank softMotion,
-- DENSE floor raises, DV21 Story/Mail.

local fs = require("./_memberfs")(require("@lune/fs"))

local publicRec = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau#PublicPlayerRecord")
assert(string.find(publicRec, "function PublicPlayerRecord.Build", 1, true), "PublicPlayerRecord.Build missing")
local seal = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau#SettingsSeal")
assert(string.find(seal, "function SettingsSeal.Apply", 1, true), "SettingsSeal.Apply missing")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, '("PublicPlayerRecord")', 1, true), "ServerServices requires PublicPlayerRecord")
assert(string.find(server, '("SettingsSeal")', 1, true), "ServerServices requires SettingsSeal")
assert(string.find(server, "PublicPlayerRecord.Build", 1, true), "ServerServices binds PublicPlayerRecord.Build")
assert(string.find(server, "SettingsSeal.Apply", 1, true), "ServerServices binds SettingsSeal.Apply")
do
	local start = string.find(server, "local function publicPlayerRecord", 1, true)
	assert(start, "publicPlayerRecord wrapper missing")
	local slice = string.sub(server, start, start + 320)
	assert(string.find(slice, "PublicPlayerRecord.Build", 1, true), "publicPlayerRecord must delegate")
	assert(not string.find(slice, "EquippedItems = equippedItems", 1, true), "public player body must leave ServerServices")
end

local research = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ResearchView")
local wheel = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau#WheelView")
local chat = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#ChatView")
local builds = fs.readFile("src/Client/AstralForge/pages/PagesSpecializations.luau")
local boot = fs.readFile("src/Client/AstralForge/BootKit.luau#BootScreen")
local prank = fs.readFile("src/Client/AstralForge/UiCore.luau#AdminPrankOverlay")
assert(string.find(research, "local softMotion = ", 1, true), "Research softMotion")
assert(string.find(wheel, "local softMotion = ", 1, true), "Wheel softMotion")
assert(string.find(chat, "local softMotion = ", 1, true) or string.find(chat, "local softMotion = reducedMotion", 1, true), "Chat softMotion")
assert(string.find(builds, "reducedMotion = props.reducedMotion", 1, true), "Specializations reduced motion")
assert(string.find(boot, "local softMotion = ", 1, true), "BootScreen softMotion")
assert(string.find(prank, "local softMotion = ", 1, true), "AdminPrank softMotion")
do
	local soft = 0
	for _ in string.gmatch(research, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Research softMotion densify, got " .. tostring(soft))
end
assert(string.find(wheel, "if reducedMotion then", 1, true), "wheel reduced-motion landing")
assert(string.find(wheel, "reducedMotion = reducedMotion", 1, true), "active renderer receives motion preference")
do
	local soft = 0
	for _ in string.gmatch(boot, "softMotion") do
		soft += 1
	end
	assert(soft >= 7, "BootScreen softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(prank, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "AdminPrank softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesSocial.luau#ChatView"] = ', 1, true), "Chat DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/PagesProgress.luau#ResearchView"] = ', 1, true), "Research DENSE floor")
assert(string.find(playability, '"src/Client/AstralForge/pages/PagesSpecializations.luau"', 1, true), "Specializations hot-page coverage")
assert(string.find(playability, "wheel controller must provide immediate reduced-motion landing", 1, true), "Wheel motion coverage")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave41-offline-brief"', 1, true), "Story wave41")
assert(string.find(config, 'Id = "update-5-1-wave41-offline"', 1, true), "Mail wave41")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

-- Pure module smoke
local PublicPlayerRecord = require("../src/Server/AstralForge/Modules/ProfileMath")("PublicPlayerRecord")
local SettingsSeal = require("../src/Server/AstralForge/Modules/ProfileMath")("SettingsSeal")
local EconomyStub = {
	Production = function(_profile)
		return 9
	end,
}
local EnsureItems = function(profile)
	return profile.Items
end
local fakePlayer = { UserId = 3, Name = "A", DisplayName = "Alpha" }
local viewer = fakePlayer
local profile = {
	Zone = 1,
	CurrentZone = 1,
	Rebirths = 0,
	LifetimeCash = 0,
	Stardust = 0,
	Cores = 1,
	Domain = { Rank = 2 },
	Stats = { PlayTime = 10 },
	Items = {
		Inventory = {
			u1 = { DefinitionId = "RelicA" },
		},
		Equipped = { "u1" },
	},
	Settings = {
		SoundVolume = 0.5,
		EffectsIntensity = 0,
		MotionIntensity = 0.02,
	},
}
local itemById = {
	RelicA = { Name = "Relic A" },
}
local rec = PublicPlayerRecord.Build(fakePlayer, profile, viewer, nil, {
	EnsureItems = EnsureItems,
	itemById = itemById,
	Economy = EconomyStub,
})
assert(rec.UserId == 3, "public UserId")
assert(rec.Production == 9, "public Production")
for _, field in { "ItemCount", "EquippedItems", "DetailedInventory", "Boosts" } do
	assert(rec[field] == nil, "public player records keep " .. field .. " private")
end
assert(rec.IsLocal == true, "public IsLocal")
SettingsSeal.Apply(profile)
assert(profile.Settings.SoundEffects == true, "seal SoundEffects")
assert(profile.Settings.UIEffects == false, "seal UIEffects")
assert(profile.Settings.ReducedMotion == true, "seal ReducedMotion")

print("[INFO] [TEST] wave41 harden residuals passed")
