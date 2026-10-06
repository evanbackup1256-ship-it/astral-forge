local StoryKit = require(script.Parent.Parent.StoryKit)
local React = StoryKit.React
local UILabs = StoryKit.UILabs
local h = React.createElement

local ui = require(StoryKit.client:WaitForChild("UiCore"))("ui")
local Palette = require(StoryKit.client:WaitForChild("CoreKit"))("theme").Palette

local ACCENTS = { "mango", "cyan", "mint", "coral", "violet", "pink" }

local function Gallery(props)
	local controls = props.controls
	local tab, setTab = React.useState("one")
	local query, setQuery = React.useState("")
	local accent = Palette[controls.Accent] or Palette.mango
	local function row(order, height, ...)
		return h("frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}), ...)
	end
	return h("frame", {
		Size = UDim2.new(1, -32, 1, -32),
		Position = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
	}, h("uilistlayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), row(1, 48, h(ui.Button, {
		text = controls.Label,
		icon = "Shop",
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromOffset(200, 44),
		disabled = controls.Disabled,
		highlight = not controls.Disabled,
		reducedMotion = props.reducedMotion,
		onClick = function()
			print("[story] pressed")
		end,
	}), h(ui.Button, {
		text = "OUTLINE",
		icon = "Guide",
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(160, 44),
		reducedMotion = props.reducedMotion,
	}), h(ui.Button, {
		text = "LOCKED",
		icon = "Lock",
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		disabled = true,
		size = UDim2.fromOffset(140, 44),
		reducedMotion = props.reducedMotion,
	})), row(2, 24, h(ui.Badge, {
		value = "NEW",
		accent = accent,
		filled = true,
		size = UDim2.fromOffset(60, 20),
	}), h(ui.Badge, {
		value = "LV 12 ★★",
		accent = Palette.mango,
		size = UDim2.fromOffset(92, 20),
	}), h(ui.Badge, {
		value = "SOLD OUT",
		accent = Palette.lineSoft,
		size = UDim2.fromOffset(90, 20),
	})), row(3, 14, h(ui.Meter, {
		value = controls.Progress,
		color = accent,
		size = UDim2.fromOffset(360, 10),
		reducedMotion = props.reducedMotion,
	})), row(4, 44, h(ui.SegmentedTabs, {
		options = { { id = "one", label = "Daily" }, { id = "two", label = "Crates" }, { id = "three", label = "Skins" } },
		value = tab,
		onChange = setTab,
		accent = accent,
		columns = 3,
		size = UDim2.fromOffset(420, 44),
		reducedMotion = props.reducedMotion,
	})), row(5, 44, h(ui.SearchField, {
		value = query,
		onChange = setQuery,
		placeholder = "Search settings",
		accent = accent,
		size = UDim2.fromOffset(340, 38),
		reducedMotion = props.reducedMotion,
	})), row(6, 140, h(ui.Panel, {
		size = UDim2.fromOffset(420, 130),
		accent = accent,
		background = Palette.panelRaised,
		highlight = true,
		reducedMotion = props.reducedMotion,
	}, h(ui.Text, {
		value = "A panel",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), h(ui.Text, {
		value = controls.Body,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 30),
		sizeConstraint = UDim2.new(1, 0, 0, 60),
	}))))
end

return StoryKit.story({
	name = "Controls",
	summary = "Buttons, badges, meters, tabs, search and panels from UiCore#ui.",
	controls = {
		Label = "BUY · 400",
		Disabled = false,
		Accent = UILabs.Choose(ACCENTS, 1),
		Progress = UILabs.Slider(0.62, 0, 1, 0.01),
		Body = "Text inside a panel wraps to its width. Long strings should never run under the button beside them.",
	},
}, function(controls, kit)
	return h(Gallery, { controls = controls, reducedMotion = kit.reducedMotion })
end)
