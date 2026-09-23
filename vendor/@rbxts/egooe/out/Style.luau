local Runtime = require(script.Parent.Runtime)

local ContextKey = Runtime.createContext("Style")

-- Iris dark theme (Dear ImGui inspired)
local defaultStyle = {
	-- Text
	textColor = Color3.fromRGB(255, 255, 255),
	textDisabledColor = Color3.fromRGB(128, 128, 128),

	-- Window / Panel backgrounds
	windowBgColor = Color3.fromRGB(15, 15, 15),
	windowBgTransparency = 0.06,
	popupBgColor = Color3.fromRGB(20, 20, 20),

	-- Title bar
	titleBgColor = Color3.fromRGB(10, 10, 10),
	titleBgActiveColor = Color3.fromRGB(41, 74, 122),

	-- Frame (input, checkbox box, etc.)
	frameBgColor = Color3.fromRGB(41, 74, 122),
	frameBgTransparency = 0.46,
	frameBgHoveredColor = Color3.fromRGB(66, 150, 250),
	frameBgHoveredTransparency = 0.46,

	-- Buttons
	buttonColor = Color3.fromRGB(66, 150, 250),
	buttonTransparency = 0.6,
	buttonHoveredColor = Color3.fromRGB(66, 150, 250),
	buttonHoveredTransparency = 0,
	buttonActiveColor = Color3.fromRGB(15, 135, 250),
	buttonActiveTransparency = 0,

	-- Slider grab
	sliderGrabColor = Color3.fromRGB(66, 150, 250),

	-- Checkmark
	checkMarkColor = Color3.fromRGB(66, 150, 250),

	-- Separator
	separatorColor = Color3.fromRGB(110, 110, 128),
	separatorTransparency = 0.5,

	-- Border
	borderColor = Color3.fromRGB(110, 110, 125),
	borderTransparency = 0.5,

	-- Scrollbar
	scrollbarGrabColor = Color3.fromRGB(79, 79, 79),

	-- Header (tree/collapsible)
	headerColor = Color3.fromRGB(66, 150, 250),
	headerTransparency = 0.69,

	-- SelectableLabel highlight
	selectableColor = Color3.fromRGB(66, 150, 250),
	selectableTransparency = 0.69,

	-- Toggle switch
	toggleOnColor = Color3.fromRGB(66, 150, 250),
	toggleOffColor = Color3.fromRGB(79, 79, 79),
	toggleHandleColor = Color3.fromRGB(255, 255, 255),

	-- Modal overlay backdrop
	modalOverlayColor = Color3.fromRGB(0, 0, 0),
	modalOverlayTransparency = 0.5,

	-- Table
	tableHeaderColor = Color3.fromRGB(41, 74, 122),
	tableHeaderTransparency = 0.15,
	tableStripeRowColor = Color3.fromRGB(255, 255, 255),
	tableStripeRowTransparency = 0.94,
	tableStripeColumnColor = Color3.fromRGB(255, 255, 255),
	tableStripeColumnTransparency = 0.97,
	tableBorderColor = Color3.fromRGB(110, 110, 125),
	tableBorderTransparency = 0.5,
	tableRowHeight = 30,
	tableCellPadding = Vector2.new(6, 4),

	-- Sizing
	textSize = 13,
	framePadding = Vector2.new(4, 3),
	itemSpacing = Vector2.new(8, 4),
	windowPadding = Vector2.new(8, 8),
	itemHeight = 22,
	titleBarHeight = 24,
	scrollbarSize = 7,
}

local Style = {}

--[=[
	@within EgooE
	@function useStyle
	@tag style

	Returns the current style information. Styles cascade downwards through the tree.
]=]
function Style.get()
	return Runtime.useContext(ContextKey) or defaultStyle
end

--[=[
	@within EgooE
	@function setStyle
	@tag style
	@param styleFragment {[string]: any} -- A dictionary of style information

	Defines style for any subsequent calls in this scope. Merges with any existing styles.
]=]
function Style.set(styleFragment)
	local existing = Runtime.useContext(ContextKey) or defaultStyle
	local newStyle = table.clone(existing)

	for key, value in pairs(styleFragment) do
		newStyle[key] = value
	end

	Runtime.provideContext(ContextKey, newStyle)
end

return Style
