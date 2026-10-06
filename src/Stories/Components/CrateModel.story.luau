local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs

local crate = require(StoryKit.client:WaitForChild("UiCore"))("crateModel")
local ShopCatalog = require(StoryKit.shared:WaitForChild("SharedData"))("ShopCatalog")

local skins = {}
for _, skin in ShopCatalog.SKINS do
	table.insert(skins, skin.Id)
end

return StoryKit.story({
	name = "Crate skin",
	summary = "A crate skin from the casino kit (Crate_<Skin>_Body/_Lid), as the Shop and the crate reveal show it.",
	controls = {
		Skin = UILabs.Choose(skins, 1),
		Open = UILabs.Slider(0, 0, 1, 0.05),
		Shake = UILabs.Slider(0, 0, 1, 0.05),
		Spin = true,
		Zoom = UILabs.Slider(0.9, 0.5, 1.5, 0.05),
	},
}, function(controls)
	return React.createElement(crate.CrateModel, {
		skin = controls.Skin,
		open = controls.Open,
		shake = controls.Shake,
		spin = controls.Spin,
		zoom = controls.Zoom,
		size = UDim2.fromScale(0.8, 0.8),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})
end)
