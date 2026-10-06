-- Run in a Studio Client through MCP with a copied server snapshot.
-- Never sends gameplay requests or writes a player's profile.
return function(client, snapshot, pages, viewport, soft)
	local function unpackSnapshot(value)
		if type(value) ~= "table" then return value end
		if value.__qaType == "Color3" then return Color3.new(value.r, value.g, value.b) end
		local copy = {}
		for key, item in value do copy[key] = unpackSnapshot(item) end
		return copy
	end
	snapshot = unpackSnapshot(snapshot)
	local packages = game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]
	local React = require(packages.react)
	local ReactRoblox = require(packages["react-roblox"])
	local Motion = require(client.MotionKit)("motion")
	local AutoScale = require(client.MotionKit)("autoScale")
	local Router = require(client.pages.PageRouter)
	local Config = require(game.ReplicatedStorage.AstralForge.Shared.GameConfig)
	viewport = table.clone(viewport)
	viewport.screenWidth = viewport.screenWidth or viewport.width
	viewport.screenHeight = viewport.screenHeight or viewport.height
	viewport.topInset = viewport.topInset or 0
	viewport.bottomInset = viewport.bottomInset or 0
	viewport.sideInset = viewport.sideInset or 0
	viewport.desktop = viewport.width >= 1100
	viewport.scale = viewport.scale or 1
	local results = {}
	local current
	local Boundary = React.Component:extend("SmokeBoundary")
	function Boundary:init() self.state = { failed = false } end
	function Boundary.getDerivedStateFromError() return { failed = true } end
	function Boundary:componentDidCatch(problem)
		current.error = tostring(problem)
	end
	function Boundary:render()
		return if self.state.failed then nil else self.props.children
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AstralForgeSmokeTest"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2000
	gui.Parent = game.Players.LocalPlayer.PlayerGui
	local root = ReactRoblox.createRoot(gui)
	local function noop() end
	local function dispatch(_, _, callback)
		if callback then callback({ ok = false, error = "Read-only smoke test" }) end
	end
	local ok, problem = xpcall(function()
		for _, page in pages do
			current = { page = page, soft = soft == true }
			table.insert(results, current)
			local element = React.createElement(Router.PageContent, {
				page = page, state = snapshot, config = Config, dispatch = dispatch,
				reducedMotion = false, navigate = noop, buyAmount = 1,
				setBuyAmount = noop, openWorkshop = noop, openDomain = noop,
				onWheelLand = noop, clearConfetti = noop, setVisit = noop,
				addNotice = noop, setCrateReveal = noop, setArcadeBusy = noop,
				setPurchasePresentationActive = noop,
				chat = { messages = {}, connected = false, unread = 0, send = noop, clear = noop },
			})
			if page == "PurchasePending" or page == "PurchaseSuccess" then
				element = React.createElement(require(client.UiOverlays)("purchaseOverlay").PurchaseOverlay, {
					phase = if page == "PurchasePending" then "pending" else "success",
					onDismiss = noop, reducedMotion = false,
				})
			end
			root:render(React.createElement(Motion.MotionSettingsContext.Provider, {
				value = { motionScale = 1, soft = soft == true, viewportScale = 1, textScale = 1 },
			}, React.createElement(AutoScale.ViewportScaleContext.Provider, { value = viewport },
				React.createElement("frame", {
					Size = UDim2.fromOffset(viewport.width, viewport.height),
					BackgroundTransparency = 1, ClipsDescendants = true,
				}, React.createElement(Boundary, { key = page },
					React.createElement(React.Suspense, { fallback = React.createElement("frame") }, element))))))
			task.wait(0.65)
			current.descendants = #gui:GetDescendants()
		end
	end, debug.traceback)
	root:unmount()
	gui:Destroy()
	if not ok then error(problem, 0) end
	return results
end
