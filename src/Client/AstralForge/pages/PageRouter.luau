local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)

local function lazyView(moduleName, exportName)
	return React.lazy(function()
		local thenable = {}
		function thenable:andThen(resolve, reject)
			local ok, component = pcall(function()
				return require(script.Parent[moduleName])[exportName]
			end)
			if ok and component ~= nil then
				resolve({
					default = component,
				})
			else
				reject(if ok then `Page {exportName} did not load` else component)
			end
		end
		return thenable
	end)
end

local MissionsView = lazyView("MissionsView", "MissionsView")
local MilestonesView = lazyView("MilestonesView", "MilestonesView")
local AnomalyView = lazyView("AnomalyView", "AnomalyView")
local LabView = lazyView("LabView", "LabView")
local StoryView = lazyView("StoryView", "StoryView")
local StarGridView = lazyView("StarGridView", "StarGridView")
local CommandView = lazyView("CommandView", "CommandView")
local MailboxView = lazyView("MailboxView", "MailboxView")
local ChatView = lazyView("ChatView", "ChatView")
local ShopView = lazyView("ShopView", "ShopView")
local InventoryView = lazyView("InventoryView", "InventoryView")
local GuildView = lazyView("GuildView", "GuildView")
local LeaderboardsView = lazyView("LeaderboardsView", "LeaderboardsView")
local TradeView = lazyView("TradeView", "TradeView")
local SettingsView = lazyView("SettingsView", "SettingsView")
local ContinuumView = lazyView("ContinuumView", "ContinuumView")
local ConvergenceView = lazyView("ConvergenceView", "ConvergenceView")
local AdminView = lazyView("AdminView", "AdminView")
local RebirthPanel = lazyView("RebirthPanel", "RebirthPanel")
local EchoForgeView = lazyView("EchoForgeView", "EchoForgeView")
local CinematicWheelView = lazyView("WheelView", "WheelView")
local ForgePathView = lazyView("ForgePathView", "ForgePathView")
local ResearchView = lazyView("ResearchView", "ResearchView")
local BoostsView = lazyView("BoostsView", "BoostsView")
local CrewView = lazyView("CrewView", "CrewView")
local OverviewView = lazyView("OverviewView", "OverviewView")
local WorldsView = lazyView("WorldsView", "WorldsView")
local RewardsView = lazyView("RewardsView", "RewardsView")
local WorkshopView = lazyView("WorkshopView", "WorkshopView")

local function PageContentInner(props)
	local _binding = props
	local page = _binding.page
	local state = _binding.state
	local config = _binding.config
	local dispatch = _binding.dispatch
	local reducedMotion = _binding.reducedMotion
	repeat
		if page == "Overview" then
			local _attributes = {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				effectsPaused = props.domainOverlayActive,
				openWorkshop = props.openWorkshop,
				openDomain = props.openDomain,
			}
			local _condition = config.Release.CountdownAt
			if _condition == nil then
				_condition = 1789272000
			end
			_attributes.releaseAt = _condition
			_attributes.navigate = props.navigate
			return React.createElement(OverviewView, _attributes)
		end
		if page == "Workshop" then
			return React.createElement(WorkshopView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Research" then
			return React.createElement(ResearchView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "StarGrid" then
			return React.createElement(StarGridView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Echoes" then
			return React.createElement(EchoForgeView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Continuum" then
			return React.createElement(ContinuumView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Convergence" then
			return React.createElement(ConvergenceView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Lab" then
			return React.createElement(LabView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Anomaly" then
			return React.createElement(AnomalyView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Worlds" then
			return React.createElement(WorldsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Missions" then
			return React.createElement(MissionsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Milestones" then
			return React.createElement(MilestonesView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Wheel" then
			return React.createElement(CinematicWheelView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onLand = props.onWheelLand,
			})
		end
		if page == "Rewards" then
			return React.createElement(RewardsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Boosts" then
			return React.createElement(BoostsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Command" then
			return React.createElement(CommandView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onSectionChange = props.clearConfetti,
			})
		end
		if page == "Story" then
			return React.createElement(StoryView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Mail" then
			return React.createElement(MailboxView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Chat" then
			return React.createElement(ChatView, {
				chat = props.chat,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Crew" then
			return React.createElement(CrewView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				visit = props.visit,
				setVisit = props.setVisit,
			})
		end
		if page == "Guild" then
			return React.createElement(GuildView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Leaderboards" then
			return React.createElement(LeaderboardsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Shop" then
			return React.createElement(ShopView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onPurchasePresentationChange = props.setPurchasePresentationActive,
			})
		end
		if page == "Inventory" then
			return React.createElement(InventoryView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				crateRevealActive = props.crateRevealActive,
				onCrateReveal = props.setCrateReveal,
				openShop = function()
					return props.navigate("Shop")
				end,
			})
		end
		if page == "Trade" then
			return React.createElement(TradeView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Settings" then
			return React.createElement(SettingsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Admin" then
			return React.createElement(AdminView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "ForgePath" then
			return React.createElement(ForgePathView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	until true
end
local PageContent = React.memo(PageContentInner)
return {
	PageContent = PageContent,
}
