local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Roblox = require("@lune/roblox")
local Session = require("../src/Client/AstralForge/PurchaseSession")
local Catalog = { GamePasses = {}, DevProducts = {} }
require("../src/Shared/AstralForge/Shared/CommerceCatalog").Extend(Catalog, { Products = {}, Passes = {} })
local viewport = { width = 1920, height = 1080, topInset = 36, bottomInset = 0, sideInset = 0 }
local soft = false
local time = 0
local clockEnabled = false
local tab = "Featured"
local effects = {}
local bindings = 0
local vr = false
local vrOverlay = {}
local playerGui = {
	FindFirstChild = function()
		return {
			FindFirstChild = function()
				return vrOverlay
			end,
		}
	end,
}
local function binding(read)
	local value = { getValue = read }
	function value:map(mapper)
		return binding(function()
			return mapper(read())
		end)
	end
	return value
end
local React = {
	createElement = function(kind, props, children)
		assert(kind ~= nil, "renderer cannot create a missing component")
		return { kind = kind, props = props or {}, children = children }
	end,
	useRef = function(value)
		return { current = value }
	end,
	useState = function(value)
		return if value == "Featured" then tab else value, function() end
	end,
	useReducer = function(_, value)
		return value, function() end
	end,
	useEffect = function(callback)
		table.insert(effects, callback)
	end,
	joinBindings = function(values)
		return binding(function()
			local result = {}
			for key, value in values do
				result[key] = value.getValue()
			end
			return result
		end)
	end,
}
local motion = {
	useViewport = function()
		return viewport
	end,
	useMotionSettings = function()
		return { soft = soft }
	end,
	useBoatTween = function(target)
		return binding(function()
			return target
		end)
	end,
	useExitTransition = function(_, _, reset)
		assert(type(reset) == "boolean", "shared exit transitions require a boolean reset")
		return {
			binding(function()
				return 1
			end),
			false,
			function(callback)
				callback()
			end,
		}
	end,
	useClock = function(enabled)
		clockEnabled = enabled
		return binding(function()
			return time
		end)
	end,
}
local ui = {
	Panel = "Panel",
	Text = "Text",
	Button = "Button",
	SearchField = "SearchField",
	SegmentedTabs = "SegmentedTabs",
	OverlayPresence = "Presence",
}
local palette = setmetatable({}, {
	__index = function()
		return Roblox.Color3.fromRGB(60, 160, 180)
	end,
})
local navigation = { BeginOverlayFocus = function() end, EndOverlayFocus = function() end, FocusClaim = function() end }
local marketplace = {
	PromptProductPurchaseFinished = { Connect = function() end },
	PromptGamePassPurchaseFinished = { Connect = function() end },
}
local modules = {
	React = React,
	ReactRoblox = {
		createPortal = function(children, target)
			return { kind = "Portal", children = children, target = target }
		end,
	},
	UiCore = function()
		return ui
	end,
	MotionKit = function()
		return motion
	end,
	CoreKit = function(name)
		return if name == "theme" then { Palette = palette } else navigation
	end,
	AudioKit = function()
		return { Audio = { play = function() end } }
	end,
	ArtKit = function()
		return { Icon = "Icon" }
	end,
	LayoutKit = function()
		return { PageScaffold = "PageScaffold" }
	end,
	PurchaseSignals = { subscribe = function() end },
	PurchaseSession = Session,
	SharedData = function()
		return Catalog
	end,
}
local parent = {}
for name in modules do
	parent[name] = name
end
parent.PurchasePresentation = "PurchasePresentation"
local environment = setmetatable({
	game = {
		ReplicatedStorage = {
			rbxts_include = { node_modules = { ["@rbxts"] = { react = "React", ["react-roblox"] = "ReactRoblox" } } },
			AstralForge = { Shared = { SharedData = "SharedData" } },
		},
		GetService = function(_, name)
			if name == "MarketplaceService" then
				return marketplace
			elseif name == "ContextActionService" then
				return {
					BindActionAtPriority = function()
						bindings += 1
					end,
					UnbindAction = function() end,
				}
			end
			return { LocalPlayer = {
				FindFirstChildOfClass = function()
					return playerGui
				end,
			} }
		end,
	},
	workspace = {
		GetAttribute = function()
			return if vr then 1440 else nil
		end,
	},
	script = { Parent = parent },
	require = function(name)
		assert(modules[name], name)
		return modules[name]
	end,
	Color3 = Roblox.Color3,
	Vector2 = Roblox.Vector2,
	UDim2 = Roblox.UDim2,
	UDim = Roblox.UDim,
	Enum = setmetatable({}, {
		__index = function(_, category)
			return setmetatable({}, {
				__index = function(_, name)
					return category .. "." .. name
				end,
			})
		end,
	}),
}, { __index = getfenv(0) })
local presentation =
	luau.load(fs.readFile("src/Client/AstralForge/PurchasePresentation.luau"), { environment = environment })()
modules.PurchasePresentation = presentation
local shop = luau.load(fs.readFile("src/Client/AstralForge/PremiumShop.luau"), { environment = environment })()

local function collect(node, result)
	if type(node) ~= "table" then
		return result
	end
	if node.kind then
		if type(node.kind) == "function" then
			return collect(node.kind(node.props), result)
		end
		table.insert(result, node)
		collect(node.children, result)
	elseif not node.getValue then
		for _, child in node do
			collect(child, result)
		end
	end
	return result
end
local function find(nodes, name)
	for _, node in nodes do
		if node.props and node.props.Name == name then
			return node
		end
	end
	error("missing " .. name)
end
for _, dimensions in { { 320, 568 }, { 568, 240 }, { 1366, 768 }, { 1920, 1080 }, { 3840, 2160 } } do
	viewport.width, viewport.height = table.unpack(dimensions)
	local card = presentation.cardLayout(viewport.width, viewport.height, 36, 20, 12)
	assert(card.width + 48 <= viewport.width and card.height + 80 <= viewport.height)
	local nodes = collect(presentation.PurchaseOverlay({ phase = "pending", token = 1 }), {})
	local renderedCard = find(nodes, "PurchaseCard")
	assert(renderedCard.props.AnchorPoint == Roblox.Vector2.new(0.5, 0.5))
	assert(renderedCard.props.Position.X.Scale == 0.5 and renderedCard.props.Position.Y.Scale == 0.5)
	assert(find(nodes, "AstralForgePurchase").props.DisplayOrder == 100)
	local scrollBody = find(nodes, "PurchaseStatusBody")
	assert(scrollBody.props.ClipsDescendants and scrollBody.props.Size.Y.Offset == -64)
	assert(clockEnabled)
	local dot = find(nodes, "PurchaseDot1")
	time = 0
	local start = dot.props.Position.getValue()
	time = 0.3
	assert(dot.props.Position.getValue().Y.Offset < start.Y.Offset, "loading dots must bounce")
	for _, node in nodes do
		assert(node.kind ~= "Button", "waiting feedback cannot contain custom checkout controls")
	end
end
soft = true
local nodes = collect(presentation.PurchaseOverlay({ phase = "pending", token = 2 }), {})
local dot = find(nodes, "PurchaseDot1")
local static = dot.props.Position.getValue()
time += 1
assert(not clockEnabled and dot.props.Position.getValue() == static)
nodes = collect(presentation.PurchaseOverlay({ phase = "success", token = 2 }), {})
assert(find(nodes, "PurchaseStatusBody").props.Size.Y.Offset == -84)
local continueButtons = 0
for _, node in nodes do
	if node.kind == "Button" then
		continueButtons += 1
		assert(node.props.text == "Continue")
	end
end
assert(continueButtons == 1 and not clockEnabled)
vr = true
nodes = collect(presentation.PurchaseOverlay({ phase = "pending", token = 3 }), {})
assert(nodes[1].target == vrOverlay and find(nodes, "PurchaseOverlayHost").props.Size.Y.Offset == -64)
vr = false
for _, phase in { "pending", "verifying", "success", "cancelled" } do
	effects = {}
	bindings = 0
	collect(presentation.PurchaseOverlay({ phase = phase, token = 4 }), {})
	for _, effect in effects do
		local cleanup = effect()
		if cleanup then
			cleanup()
		end
	end
	assert(
		bindings == (if phase == "pending" or phase == "verifying" then 0 else 1),
		"native prompt must retain its cancel/back controls"
	)
end
for _, width in { 240, 320, 570, 900, 1920 } do
	viewport.width = width
	local layout = shop.shopLayout(width)
	assert(layout.width <= width and layout.columns >= 1 and layout.columns <= 3)
	local cellWidth = (layout.width - (layout.columns - 1) * layout.gap) / layout.columns
	assert(cellWidth > 0)
	for count = 1, layout.columns do
		local rowWidth = count * cellWidth + (count - 1) * layout.gap
		assert(rowWidth <= layout.width + 0.001 and (layout.width - rowWidth) / 2 >= -0.001)
	end
end
for _, selected in { "Featured", "Passes", "Packs", "Codes" } do
	tab = selected
	local offers = shop.catalogOffers(tab)
	for _, entry in offers do
		assert(not entry.offer.Donation)
	end
	nodes = collect(shop.ShopView({ state = {}, dispatch = function() end }), {})
	for _, node in nodes do
		assert(node.kind ~= "ViewportFrame", "removed tip jar must not render")
		if node.kind == "PageScaffold" then
			for _, section in node.props.sections do
				collect(section.element, nodes)
			end
		elseif node.kind == "Panel" or node.kind == "Button" then
			assert(node.props.reducedMotion == true, "every shop card/control must respect global reduced motion")
		end
	end
end
assert(#shop.catalogOffers("Passes") == 10 and #shop.catalogOffers("Packs") == 16)
print(
	"[TEST] centered status portal, short-screen scrolling, bouncing/reduced-motion dots, VR target and centered shop rows passed"
)
