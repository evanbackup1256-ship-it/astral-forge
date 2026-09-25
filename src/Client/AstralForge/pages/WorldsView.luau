local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local PageBoardHeights = require(script.Parent.Parent.pageBoardHeights)

local function WorldRow(_param)
	local zone = _param.zone
	local current = _param.current
	local unlocked = _param.unlocked
	local canUnlock = _param.canUnlock
	local onSelect = _param.onSelect
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local cashOk = _param.cashOk
	local coresOk = _param.coresOk
	local rebirthOk = _param.rebirthOk
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — WorldRow entrance drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local skipMotion = softMotion or layoutOrder > 4 or antilag.skipEntrance
	local reveal = useStagger(math.min(layoutOrder, 4), skipMotion, 0.02, 0.14)
	local _condition = zone.Features[1]
	if _condition == nil then
		_condition = zone.Description
	end
	local feature = _condition
	local actionable = current or unlocked or canUnlock
	local costBits = {}
	if not unlocked and not current then
		if zone.RequiredRebirths > 0 then
			local _arg0 = `{zone.RequiredRebirths} rebirth{if zone.RequiredRebirths == 1 then "" else "s"}`
			table.insert(costBits, _arg0)
		end
		if zone.CoreCost > 0 then
			local _arg0 = `{compactNumber(zone.CoreCost)} cores`
			table.insert(costBits, _arg0)
		end
		if gteFlux(zone.Cost, 0.01) then
			local _arg0 = `{compactNumber(zone.Cost)} flux`
			table.insert(costBits, _arg0)
		end
	end
	local costLine = if #costBits > 0 then table.concat(costBits, " · ") else nil
	local missing = if not unlocked and not current then (if not rebirthOk then `{zone.RequiredRebirths} rebirths` elseif not coresOk then `{compactNumber(zone.CoreCost)} cores` elseif not cashOk then `{compactNumber(zone.Cost)} flux` else nil) else nil
	local cta = if current then "CURRENT" elseif unlocked then "ENTER" elseif canUnlock then "UNLOCK" elseif missing ~= nil then string.upper(missing) else "LOCKED"
	local btnColor = if current then Palette.green elseif unlocked then Palette.green elseif canUnlock then Palette.mango else Palette.panelSoft
	local btnText = if (current or unlocked or canUnlock) then Palette.ink else Palette.muted
	local rowH = PageBoardHeights.World(stack)
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = zone.Color,
		background = if current then zone.DarkColor:Lerp(Palette.panelRaised, 0.45) else Palette.panel,
		padding = if stack then 16 else 18,
		reveal = reveal,
		interactive = not current,
		highlight = current,
		reducedMotion = skipMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "World",
		accent = zone.Color,
		size = if stack then 48 else 56,
		radius = 14,
		position = UDim2.fromOffset(0, if stack then 12 else 30),
		spin = false,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, -64, 0, 126) else UDim2.new(1, -200, 1, -6),
		Position = UDim2.fromOffset(if stack then 60 else 72, if stack then 4 else 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = zone.Name,
		size = if stack then 18 else 19,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = zone.Tagline,
		size = if stack then 13 else 11,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 30),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = `{feature}  ·  {AppHelpers:formatWorldMultiplier(zone.Multiplier)}x`,
		size = if stack then 13 else 11,
		color = zone.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 56),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), costLine ~= nil and React.createElement(Text, {
		value = if canUnlock then `Cost {costLine}` else `Needs {costLine}`,
		size = 10,
		color = if canUnlock then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 78),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), current and React.createElement(Badge, {
		value = "CURRENT WORLD",
		accent = zone.Color,
		filled = true,
		position = UDim2.fromOffset(0, if costLine ~= nil then 98 else 84),
		size = UDim2.fromOffset(136, 26),
	})), React.createElement(Button, {
		text = cta,
		icon = "World",
		onClick = onSelect,
		color = btnColor,
		textColor = btnText,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, TapTarget),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -166, 0.5, -TapTarget / 2),
		reducedMotion = softMotion,
		disabled = not actionable or current,
		highlight = actionable and not current,
		zIndex = 12,
	})))
end
local function WorldsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Worlds travel/unlock CTAs drop springs on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local quietMotion = reducedMotion or antilag.skipEntrance
	-- Canonical softMotion antilag gate — WorldsBoard.
	local boardReveal = useStagger(0, softMotion)
	local travelReveal = useStagger(1, softMotion)
	local headerReveal = boardReveal
	local worldsHostRef = React.useRef(nil)
	-- Gamepad: park Selection on FIND CURRENT / travel strip (FocusClaim prefers Confirm-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = worldsHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { state.CurrentZone, state.Zone })
	local headerHeight = if stack then 168 else 112
	local rowHeight = PageBoardHeights.World(stack)
	local rowGap = if stack then chrome.panelGap else Layout.panelGap
	local worldColumns = if stack then 1 elseif viewport.width >= 1700 then 3 elseif viewport.width >= 1100 then 2 else 1
	local listPad = Layout.stackGap * 2
	local _condition = config.MaxZone
	if _condition == nil then
		_condition = #config.Zones
	end
	local catalogTotal = _condition
	local total = if catalogTotal > 0 then math.clamp(state.Zone + 2, 1, catalogTotal) else 0
	local currentIdx = math.clamp(state.CurrentZone - 1, 0, math.max(0, total - 1))
	local range, setRange = React.useState(function()
		return AppHelpers:worldWindowAround(currentIdx, total)
	end)
	local scrollRef = React.useRef()
	React.useEffect(function()
		setRange(function(prev)
			local stop = prev.start + prev.count
			if currentIdx >= prev.start and currentIdx < stop then
				return prev
			end
			return AppHelpers:worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk)
		end)
	end, { currentIdx, total })
	local rangeEnd = math.min(total, range.start + range.count)
	local shownCount = math.max(0, rangeEnd - range.start)
	local remainingBelow = math.max(0, total - rangeEnd)
	local remainingAbove = range.start
	local canShowMore = remainingBelow > 0 or remainingAbove > 0
	local showMore = function()
		setRange(function(prev)
			local stop = math.min(total, prev.start + prev.count)
			if stop < total then
				if prev.count >= AppHelpers.worldWindow.maxMounted then
					local nextStart = math.min(math.max(0, total - AppHelpers.worldWindow.maxMounted), prev.start + AppHelpers.worldWindow.chunk)
					return {
						start = nextStart,
						count = math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					}
				end
				return {
					start = prev.start,
					count = math.min(AppHelpers.worldWindow.maxMounted, total - prev.start, prev.count + AppHelpers.worldWindow.chunk),
				}
			end
			if prev.start > 0 then
				if prev.count >= AppHelpers.worldWindow.maxMounted then
					local nextStart = math.max(0, prev.start - AppHelpers.worldWindow.chunk)
					return {
						start = nextStart,
						count = math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					}
				end
				local grow = math.min(AppHelpers.worldWindow.chunk, prev.start, AppHelpers.worldWindow.maxMounted - prev.count)
				return {
					start = prev.start - grow,
					count = prev.count + grow,
				}
			end
			return prev
		end)
	end
	local jumpToCurrent = function()
		local focused = AppHelpers:worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk)
		setRange(focused)
		task.defer(function()
			local scrolling = scrollRef.current
			if not scrolling then
				return nil
			end
			local localIndex = math.clamp(currentIdx - focused.start, 0, math.max(0, focused.count - 1))
			scrolling.CanvasPosition = Vector2.new(0, math.max(0, headerHeight + rowGap + localIndex * (rowHeight + rowGap) - 40))
		end)
	end
	local moreLabel = if remainingBelow > 0 then `SHOW MORE  ({remainingBelow} left)` elseif remainingAbove > 0 then `SHOW EARLIER  ({remainingAbove})` else "SHOW MORE"
	local gridRows = math.ceil(math.max(1, shownCount) / worldColumns)
	local rowsHeight = math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)
	local worldTail = scrollTail(stack, chrome.bottomSafe, 40)
	local rows = {}
	do
		local index = range.start
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < rangeEnd) then
				break
			end
			local zone = if config.ResolveZone ~= nil then config.ResolveZone(index + 1) else config.Zones[index + 1]
			if zone == nil then
				continue
			end
			local unlocked = state.Zone >= zone.Id
			local rebirthOk = state.Rebirths >= zone.RequiredRebirths
			local coresOk = state.Cores >= zone.CoreCost
			local cashOk = gteFlux(state.Cash, zone.Cost)
			local canUnlock = not unlocked and zone.Id == state.Zone + 1 and rebirthOk and coresOk and cashOk
			local localOrder = index - range.start + 1
			local _arg0 = React.createElement(WorldRow, {
				key = zone.Id,
				zone = zone,
				current = state.CurrentZone == zone.Id,
				unlocked = unlocked,
				canUnlock = canUnlock,
				cashOk = cashOk,
				coresOk = coresOk,
				rebirthOk = rebirthOk,
				reducedMotion = reducedMotion,
				onSelect = function()
					return dispatch(if unlocked then "SelectZone" else "UnlockZone", {
						Id = zone.Id,
					})
				end,
				layoutOrder = localOrder,
				stack = stack,
			})
			table.insert(rows, _arg0)
		end
	end
	local rowsBlock = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, (if worldColumns > 1 then React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / worldColumns, -math.floor(rowGap * (worldColumns - 1) / worldColumns), 0, rowHeight),
		CellPadding = UDim2.fromOffset(rowGap, rowGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = worldColumns,
	}) else React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, rowGap),
	})), rows)
	local sections = {
		{
			id = "header",
			height = headerHeight,
			element = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = if stack then 16 else 14,
		reveal = headerReveal,
		reducedMotion = softMotion,
		highlight = not softMotion and travelReveal ~= nil,
		layoutOrder = 0,
		clips = false,
	}, React.createElement(Text, {
		value = "SCENE SELECT",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 18),
	}), React.createElement(Text, {
		value = "Pick a world.",
		size = if stack then chrome.titleText else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 30),
	}), React.createElement(Text, {
		value = "Travel to ones you own, or unlock the next stop.",
		size = if stack then chrome.labelText else 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 56),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 36),
	}), not stack and React.createElement("frame", {
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = `{state.Zone} / {catalogTotal}`,
		accent = Palette.mint,
		size = UDim2.fromOffset(118, 28),
	}), React.createElement(Button, {
		text = "FIND CURRENT",
		icon = "Search",
		onClick = jumpToCurrent,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 42),
		hug = true,
		reducedMotion = softMotion,
	})), stack and React.createElement(Button, {
		text = "FIND CURRENT",
		icon = "Search",
		onClick = jumpToCurrent,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = softMotion,
	})),
		},
		{
			id = "rows",
			height = rowsHeight,
			element = rowsBlock,
		},
	}
	if canShowMore then
		table.insert(sections, {
			id = "more",
			height = TapTarget + 8,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = moreLabel,
				icon = "Chevron",
				onClick = showMore,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.new(1, 0, 0, TapTarget),
				reducedMotion = softMotion,
				outline = true,
			})),
		})
	end
	return React.createElement("frame", {
		ref = worldsHostRef,
		Name = "WorldsTravelClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- FocusClaim FIND CURRENT / travel must not clip CTA overshoot.
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = rowGap,
		tailPad = worldTail + listPad,
		scrollBarColor = Palette.mint,
		scrollBarThickness = 4,
		sections = sections,
	}))
end
return {
	WorldsView = WorldsView,
}
