local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local overlay = require(StoryKit.client:WaitForChild("UiCore"))("CrateRevealOverlay")
local ShopCatalog = require(StoryKit.shared:WaitForChild("SharedData"))("ShopCatalog")
local RelicSystem = require(StoryKit.shared:WaitForChild("SharedData"))("RelicSystem")

local skins = {}
for _, skin in ShopCatalog.SKINS do
	table.insert(skins, skin.Id)
end

local function rollsFor(config, rarity, count)
	local pick = nil
	for _, definition in config.Items.Definitions do
		if definition.Rarity == rarity then
			pick = definition
			break
		end
	end
	pick = pick or config.Items.Definitions[1]
	local rolls = {}
	for index = 1, count do
		table.insert(rolls, { Uid = `story{index}`, DefinitionId = pick.Id, Rarity = pick.Rarity, New = index == 1, Pity = false, AutoSalvaged = false, Essence = 0 })
	end
	return rolls
end

return StoryKit.story({
	name = "Crate reveal",
	summary = "The reel, the equipped crate popping open, and the Celestial/Astral aura on a win.",
	controls = {
		Rarity = UILabs.Choose(RelicSystem.ORDER, 7),
		Count = UILabs.Choose({ 1, 5 }, 1),
		Skin = UILabs.Choose(skins, 1),
		Replay = 0,
	},
}, function(controls, kit)
	local crate = kit.config.Items.Crates[1]
	return React.createElement(overlay.CrateRevealOverlay, {
		key = `{controls.Rarity}-{controls.Count}-{controls.Skin}-{controls.Replay}`,
		session = {
			crateId = crate.Id,
			crateName = crate.Name,
			accent = crate.Color,
			rolls = rollsFor(kit.config, controls.Rarity, controls.Count),
		},
		config = kit.config,
		skin = controls.Skin,
		reducedMotion = kit.reducedMotion,
		onClose = function()
			print("[story] reveal closed")
		end,
	})
end)
