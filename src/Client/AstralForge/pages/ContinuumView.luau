-- Next Rank
-- One permanent purchase. Spend flux and stardust to raise a rank that
-- survives rebirth. The page says whether you can afford it, which resource
-- is missing, and what the rank already gives you.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local asFlux = _format.asFlux
local _motion = require(script.Parent.Parent.motion)
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local Text = _ui.Text

local EMPTY_CONTINUUM = {
	Rank = 0,
	FluxCost = 2500000,
	StardustCost = 12,
	CanUpgrade = false,
	ProductionMultiplier = 1,
	CapacityMultiplier = 1,
	TapMultiplier = 1,
	OfflineBonus = 0,
}

local function showMult(value)
	if type(value) ~= "number" then
		return compactNumber(value)
	end
	return string.format("%.2f", value)
end

local function advice(canUpgrade, canFlux, canDust, rank)
	if canUpgrade then
		return "You can raise the rank now. It is permanent, so it is worth more than spending the same flux on a machine you will rebirth away."
	end
	local nextRank = rank + 1
	local milestone = nextRank % 25 == 0
	if not canFlux and not canDust then
		return if milestone
			then "Rank " .. tostring(nextRank) .. " is a milestone (an extra 1.5x). You still need both flux and stardust."
			else "You need more flux and more stardust. Bank the vault, then claim a reward or finish a shift."
	end
	if not canFlux then
		return "Flux is the only thing missing. Bank the vault, then press Raise Rank."
	end
	return "Stardust is the only thing missing. Claim rewards, finish a lab order, or bank a full shift, then come back."
end

local function BonusLine(props)
	return React.createElement(Text, {
		value = `{props.label}   {props.value}`,
		size = 14,
		color = props.color,
		weight = Enum.FontWeight.Heavy,
		layoutOrder = props.order,
		sizeConstraint = UDim2.new(1, 0, 0, 22),
		reducedMotion = props.reducedMotion,
	})
end

local function ContinuumView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ContinuumView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local continuum = state.Continuum or EMPTY_CONTINUUM
	local canFlux = gteFlux(state.Cash, continuum.FluxCost)
	local canDust = gteFlux(state.Stardust, continuum.StardustCost)
	local fluxFill = meterFill(asFlux(state.Cash), math.max(1, asFlux(continuum.FluxCost)))
	local dustFill = meterFill(asFlux(state.Stardust), math.max(1, asFlux(continuum.StardustCost)))
	local claimRef = React.useRef(nil)
	React.useEffect(function()
		if not continuum.CanUpgrade or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { continuum.CanUpgrade, continuum.Rank })
	local ranksIntoSet = continuum.Rank % 25
	local ranksLeft = if ranksIntoSet == 0 and continuum.Rank > 0 then 25 else 25 - ranksIntoSet
	local sectionGap = if stack then chrome.panelGap else Layout.panelGap
	return React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, if stack then 56 else 48),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		sections = {
			{
				id = "plan",
				height = if stack then 210 else 188,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = Palette.violet,
					background = Palette.panelRaised,
					padding = if stack then 14 else 18,
					reducedMotion = softMotion,
					clips = true,
				}, React.createElement(Text, {
					value = "NEXT RANK",
					size = 11,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
					reducedMotion = softMotion,
				}), React.createElement(Text, {
					value = `Raise rank {compactNumber(continuum.Rank)} to {compactNumber(continuum.Rank + 1)}`,
					size = if stack then 22 else 28,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 16,
					position = UDim2.fromOffset(0, 20),
					sizeConstraint = UDim2.new(1, 0, 0, 36),
					reducedMotion = softMotion,
				}), React.createElement(Text, {
					value = advice(continuum.CanUpgrade, canFlux, canDust, continuum.Rank),
					size = 15,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(0, 62),
					sizeConstraint = UDim2.new(1, 0, 0, 72),
					reducedMotion = softMotion,
				}), React.createElement(Text, {
					value = `{ranksLeft} ranks until the next 1.5x milestone`,
					size = 12,
					color = Palette.pink,
					weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(0, 140),
					sizeConstraint = UDim2.new(1, 0, 0, 18),
					reducedMotion = softMotion,
				})),
			},
			{
				id = "cost",
				height = if stack then 250 else 168,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = if continuum.CanUpgrade then Palette.mint else Palette.violet,
					background = Palette.panel,
					padding = 14,
					highlight = continuum.CanUpgrade,
					reducedMotion = softMotion,
					clips = false,
				}, React.createElement(Text, {
					value = if canFlux then "Flux ready" else `Flux  {compactNumber(state.Cash)} / {compactNumber(continuum.FluxCost)}`,
					size = 13,
					color = if canFlux then Palette.mint else Palette.cream,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 18),
					reducedMotion = softMotion,
				}), React.createElement(Meter, {
					value = math.min(1, fluxFill),
					color = Palette.cyan,
					reducedMotion = softMotion,
					position = UDim2.fromOffset(0, 24),
					size = UDim2.new(1, 0, 0, 8),
				}), React.createElement(Text, {
					value = if canDust then "Stardust ready" else `Stardust  {compactNumber(state.Stardust)} / {compactNumber(continuum.StardustCost)}`,
					size = 13,
					color = if canDust then Palette.mango else Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 42),
					sizeConstraint = UDim2.new(1, 0, 0, 18),
					reducedMotion = softMotion,
				}), React.createElement(Meter, {
					value = math.min(1, dustFill),
					color = Palette.mango,
					reducedMotion = softMotion,
					position = UDim2.fromOffset(0, 66),
					size = UDim2.new(1, 0, 0, 8),
				}), React.createElement("frame", {
					Name = "ContinuumClaimActions",
					Size = UDim2.new(1, 0, 0, TapTarget),
					Position = UDim2.new(0, 0, 1, -(TapTarget + 4)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = claimRef,
				}, React.createElement(Button, {
					text = if continuum.CanUpgrade then "RAISE RANK" else "NEED BOTH RESOURCES",
					icon = "Rebirth",
					color = if continuum.CanUpgrade then Palette.mint else Palette.panelSoft,
					textColor = if continuum.CanUpgrade then Palette.ink else Palette.cream,
					size = UDim2.fromOffset(220, 40),
					disabled = not continuum.CanUpgrade,
					highlight = false,
					reducedMotion = softMotion,
					onClick = function()
						return dispatch("UpgradeContinuum")
					end,
				}))),
			},
			{
				id = "have",
				height = if stack then 168 else 132,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = Palette.cyan,
					background = Palette.panelRaised,
					padding = 14,
					reducedMotion = softMotion,
				}, React.createElement("uilistlayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}), React.createElement(Text, {
					value = "ALREADY YOURS  ·  kept after rebirth",
					size = 11,
					color = Palette.muted,
					weight = Enum.FontWeight.Heavy,
					layoutOrder = 0,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
					reducedMotion = softMotion,
				}), React.createElement(BonusLine, {
					label = "Production",
					value = `{showMult(continuum.ProductionMultiplier)}x`,
					color = Palette.cyan,
					order = 1,
					reducedMotion = softMotion,
				}), React.createElement(BonusLine, {
					label = "Vault",
					value = `{showMult(continuum.CapacityMultiplier)}x`,
					color = Palette.violet,
					order = 2,
					reducedMotion = softMotion,
				}), React.createElement(BonusLine, {
					label = "Clicks",
					value = `{showMult(continuum.TapMultiplier)}x`,
					color = Palette.mango,
					order = 3,
					reducedMotion = softMotion,
				}), React.createElement(BonusLine, {
					label = "Offline",
					value = `+{string.format("%.1f", (tonumber(continuum.OfflineBonus) or 0) * 100)}%`,
					color = Palette.mint,
					order = 4,
					reducedMotion = softMotion,
				})),
			},
		},
	})
end

return {
	ContinuumView = ContinuumView,
}
