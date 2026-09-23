--!strict
-- Wave45 offline residuals: VisitorList + AutoSalvageSnapshot peels,
-- Shop/Admin/Story/Rebirth densify, DENSE floor raises, DV21 Story/Mail.

local fs = require("@lune/fs")

local visitors = fs.readFile("src/Server/AstralForge/Modules/VisitorList.luau")
assert(string.find(visitors, "function VisitorList.Build", 1, true), "VisitorList.Build missing")
local salvage = fs.readFile("src/Server/AstralForge/Modules/AutoSalvageSnapshot.luau")
assert(string.find(salvage, "function AutoSalvageSnapshot.Public", 1, true), "AutoSalvageSnapshot.Public missing")
assert(string.find(salvage, "function AutoSalvageSnapshot.PublicAutoForge", 1, true), "PublicAutoForge missing")
local social = fs.readFile("src/Server/AstralForge/Modules/SocialBoost.luau")
assert(string.find(social, "function SocialBoost.PublicSnapshot", 1, true), "SocialBoost.PublicSnapshot missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, 'WaitForChild("VisitorList")', 1, true), "ServerServices requires VisitorList")
assert(string.find(services, 'WaitForChild("AutoSalvageSnapshot")', 1, true), "ServerServices requires AutoSalvageSnapshot")
assert(string.find(services, "VisitorList.Build", 1, true), "ServerServices uses VisitorList.Build")
assert(string.find(services, "AutoSalvageSnapshot.Public", 1, true), "ServerServices uses AutoSalvageSnapshot.Public")
assert(string.find(services, "SocialBoost.PublicSnapshot", 1, true), "ServerServices uses SocialBoost.PublicSnapshot")
assert(not string.find(services, "left.DisplayName < right.DisplayName", 1, true), "visitor sort must leave ServerServices")
assert(not string.find(services, 'Enabled = false, MachineId = "StellarCore", Reserve = 0.25', 1, true), "AutoForge default must leave ServerServices")

local shop = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
local admin = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
local story = fs.readFile("src/Client/AstralForge/pages/StoryView.luau")
local rebirth = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
assert(string.find(shop, "Canonical softMotion antilag gate — ShopCatalog", 1, true), "ShopCatalog softMotion")
assert(string.find(admin, "Canonical softMotion antilag gate — AdminTools", 1, true), "AdminTools softMotion")
assert(string.find(story, "Canonical softMotion antilag gate — StoryArchive", 1, true), "StoryArchive softMotion")
assert(string.find(rebirth, "Canonical softMotion antilag gate — RebirthConfirm", 1, true), "RebirthConfirm softMotion")
do
	local soft = 0
	for _ in string.gmatch(shop, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Shop softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(admin, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Admin softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(story, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Story softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(rebirth, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Rebirth softMotion densify, got " .. tostring(soft))
end

local playability = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playability, '["src/Client/AstralForge/pages/ShopView.luau"] = 12', 1, true), "Shop DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/AdminView.luau"] = 12', 1, true), "Admin DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/StoryView.luau"] = 12', 1, true), "Story DENSE floor")
assert(string.find(playability, '["src/Client/AstralForge/pages/RebirthPanel.luau"] = 12', 1, true), "Rebirth DENSE floor")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave45-offline-brief"', 1, true), "Story wave45")
assert(string.find(config, 'Id = "update-5-1-wave45-offline"', 1, true), "Mail wave45")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local VisitorList = require("../src/Server/AstralForge/Modules/VisitorList")
local AutoSalvageSnapshot = require("../src/Server/AstralForge/Modules/AutoSalvageSnapshot")
local SocialBoost = require("../src/Server/AstralForge/Modules/SocialBoost")
do
	local present = { UserId = 1, Name = "a", DisplayName = "Zed", Parent = true }
	local absent = { UserId = 2, Name = "b", DisplayName = "Amy", Parent = false }
	local bucket = { [present] = true, [absent] = true }
	local list = VisitorList.Build(bucket, function(visitor)
		return visitor.Parent == true
	end)
	assert(#list == 1 and list[1].DisplayName == "Zed", "visitor filter+sort")
end
do
	local copy = function(t)
		local out = {}
		for k, v in t do
			out[k] = v
		end
		return out
	end
	local public = AutoSalvageSnapshot.Public(nil, copy)
	assert(public.Enabled == false and public.KeepNew == true, "autosalvage default")
	local forge = AutoSalvageSnapshot.PublicAutoForge(nil, copy)
	assert(forge.MachineId == "StellarCore", "autoforge default")
	local socialBag = SocialBoost.PublicSnapshot(nil, 5, copy)
	assert(socialBag.FriendLimit == 5 and socialBag.Multiplier == 1, "social default")
end

print("[INFO] [TEST] wave45 harden residuals passed")
