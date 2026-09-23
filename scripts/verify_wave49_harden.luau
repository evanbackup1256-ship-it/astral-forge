--!strict
-- Wave49 offline residuals: Mailbox/Shop/ItemEffects/FluxSurge peels,
-- Credits/Inventory/Rebirth/Settings/Trade densify, DV21 Story/Mail.

local fs = require("@lune/fs")

local storyMail = fs.readFile("src/Server/AstralForge/Modules/StoryMailSnapshot.luau")
assert(string.find(storyMail, "function StoryMailSnapshot.MailboxPublic", 1, true), "MailboxPublic missing")

local shop = fs.readFile("src/Server/AstralForge/Modules/ShopGrantEligibility.luau")
assert(string.find(shop, "function ShopGrantEligibility.CatalogPublic", 1, true), "CatalogPublic missing")

local loadout = fs.readFile("src/Server/AstralForge/Modules/ItemLoadoutMath.luau")
assert(string.find(loadout, "function ItemLoadoutMath.EffectsPublic", 1, true), "EffectsPublic missing")

local flux = fs.readFile("src/Server/AstralForge/Services/FluxSurgeService.luau")
assert(string.find(flux, "function FluxSurgeService.IdleState", 1, true), "FluxSurge IdleState missing")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(services, "StoryMailSnapshot.MailboxPublic", 1, true), "ServerServices MailboxPublic")
assert(string.find(services, "ShopGrantEligibility.CatalogPublic", 1, true), "ServerServices CatalogPublic")
assert(string.find(services, "ItemLoadoutMath.EffectsPublic", 1, true), "ServerServices EffectsPublic")
assert(string.find(services, "FluxSurgeService.IdleState", 1, true), "ServerServices IdleState")
assert(not string.find(services, "Mailbox = { Messages = mailState", 1, true), "Mailbox inline must leave")
assert(not string.find(services, "OwnedPasses = copyDictionary(profile.OwnedPasses", 1, true), "Shop OwnedPasses inline must leave")
assert(not string.find(services, 'Automation = Economy.ItemEffect(profile, "Automation")', 1, true), "Item Effects inline must leave")
assert(not string.find(services, "{ Active = false, Multiplier = 1, AffectsCapacity = false }", 1, true), "FluxSurge idle inline must leave")

local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
local inventory = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local rebirth = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
local settings = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
local trade = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
assert(string.find(credits, "Canonical softMotion antilag gate — CreditsThanks", 1, true), "CreditsThanks softMotion")
assert(string.find(inventory, "Canonical softMotion antilag gate — InventoryTabs", 1, true), "InventoryTabs softMotion")
assert(string.find(rebirth, "Canonical softMotion antilag gate — RebirthHero", 1, true), "RebirthHero softMotion")
assert(string.find(settings, "Canonical softMotion antilag gate — SettingsAudio", 1, true), "SettingsAudio softMotion")
assert(string.find(trade, "Canonical softMotion antilag gate — TradeBoard", 1, true), "TradeBoard softMotion")
do
	local soft = 0
	for _ in string.gmatch(credits, "softMotion") do
		soft += 1
	end
	assert(soft >= 18, "Credits softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(inventory, "softMotion") do
		soft += 1
	end
	assert(soft >= 20, "Inventory softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(rebirth, "softMotion") do
		soft += 1
	end
	assert(soft >= 20, "Rebirth softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(settings, "softMotion") do
		soft += 1
	end
	assert(soft >= 20, "Settings softMotion densify, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(trade, "softMotion") do
		soft += 1
	end
	assert(soft >= 20, "Trade softMotion densify, got " .. tostring(soft))
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave49-offline-brief"', 1, true), "Story wave49")
assert(string.find(config, 'Id = "update-5-1-wave49-offline"', 1, true), "Mail wave49")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

local StoryMailSnapshot = require("../src/Server/AstralForge/Modules/StoryMailSnapshot")
do
	local bag = StoryMailSnapshot.MailboxPublic({ { Id = "a" } }, 2)
	assert(bag.Unread == 2 and bag.Messages[1].Id == "a", "mailbox public")
end

local ShopGrantEligibility = require("../src/Server/AstralForge/Modules/ShopGrantEligibility")
do
	local bag = ShopGrantEligibility.CatalogPublic({ VIP = true }, function(t)
		return t
	end)
	assert(bag.CatalogVersion == 1 and bag.OwnedPasses.VIP == true, "catalog public")
end

local ItemLoadoutMath = require("../src/Server/AstralForge/Modules/ItemLoadoutMath")
do
	local effects = ItemLoadoutMath.EffectsPublic({}, {
		ItemEffect = function(_profile, kind)
			return kind
		end,
	})
	assert(effects.Production == "Production" and effects.Offline == "Offline", "effects public")
end

print("[INFO] [TEST] wave49 harden residuals passed")
