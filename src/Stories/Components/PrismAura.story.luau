local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs
local h = React.createElement

local prism = require(StoryKit.client:WaitForChild("UiCore"))("prismFx")
local Palette = require(StoryKit.client:WaitForChild("CoreKit"))("theme").Palette

return StoryKit.story({
	name = "Prismatic aura",
	summary = "The Celestial and Astral look: turning rim, light rays and sparks (UiCore#prismFx).",
	controls = {
		Rarity = UILabs.Choose({ "Celestial", "Astral" }, 1),
		Intensity = UILabs.Slider(1, 0, 1, 0.05),
		Rays = true,
		Sparks = true,
	},
}, function(controls)
	return h("frame", {
		Size = UDim2.fromOffset(260, 180),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h(prism.PrismAura, {
		rarity = controls.Rarity,
		intensity = controls.Intensity,
		rays = controls.Rays,
		sparks = controls.Sparks,
		corner = 14,
		clipRays = false,
	}), h("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.upper(controls.Rarity) .. " RELIC",
		TextColor3 = Palette.cream,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 22,
		ZIndex = 10,
	}))
end)
