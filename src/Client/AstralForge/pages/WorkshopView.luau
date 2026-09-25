local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useClock = _motion.useClock
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local AmountToggle = _ui.AmountToggle
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local SearchField = _ui.SearchField
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local amountPayload = _format.amountPayload
local bulkCost = _format.bulkCost
local compactNumber = _format.compactNumber
local compareFlux = _format.compareFlux
local gteFlux = _format.gteFlux
local VirtualGrid = require(script.Parent.Parent.scrolling).VirtualGrid
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local PageBoardHeights = require(script.Parent.Parent.pageBoardHeights)

local function MachineRow(_param)
	local machine = _param.machine
	local level = _param.level
	local cash = _param.cash
	local buyAmount = _param.buyAmount
	local reducedMotion = _param.reducedMotion
	local onBuy = _param.onBuy
	local y = _param.y
	local x = _param.x
	local width = _param.width
	local unlocked = _param.unlocked
	local lockReason = _param.lockReason
	local lockShort = _param.lockShort
	if lockShort == nil then
		lockShort = ""
	end
	local antilag = useAntilag()
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	-- Canonical softMotion antilag gate — MachineRow buy springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local rowH = PageBoardHeights.Machine(stack)
	local price = bulkCost(machine.BaseCost, machine.CostScale, level, buyAmount, machine.MaxLevel, cash)
	local maxed = level >= machine.MaxLevel
	local ready = unlocked and gteFlux(cash, price) and not maxed
	local accent = machine.Accent or machine.Color
	local running = level > 0
	local flow = useClock(running and not softMotion and antilag.allowAmbient and antilag.tier >= 2, 0.55, 1)
	local buyLabel = if not unlocked then (if lockShort ~= "" then lockShort else "Locked") elseif maxed then "Maxed" elseif ready then (if level < 1 then "Buy this" else "Buy level") else `Need {compactNumber(price)} Flux`
	local _condition = machine.BaseProduction
	if _condition == nil then
		_condition = 0
	end
	local hasOutput = _condition > 0
	local _result
	if not unlocked then
		_result = lockReason
	else
		local _result_1
		if hasOutput then
			local _condition_1 = machine.BaseProduction
			if _condition_1 == nil then
				_condition_1 = 0
			end
			_result_1 = if level < 1 then `Earns {compactNumber(_condition_1)} Flux/sec once you buy it` else `{compactNumber(_condition_1)} Flux/sec · level {compactNumber(level)}`
		else
			_result_1 = if maxed then `Level {compactNumber(level)} · maxed` else `Level {compactNumber(level)} · next {compactNumber(price)}`
		end
		_result = _result_1
	end
	local rateLine = _result
	-- Non-stack cards used to reserve a fixed 210px for the text block and float a fixed
	-- 150px-wide button 158px from the right edge, sized for a full-width single-column row.
	-- A multi-column grid (this same component, used at 1/2 or 1/3 the row width once the
	-- viewport is wide enough) squeezes the card well under that fixed budget, so the text
	-- block and button no longer fit side by side and started overlapping. Below this width
	-- threshold, stack the button under the text instead of beside it, the same pattern the
	-- stack layout already uses correctly, rather than assuming there's always ≥360px to work
	-- with.
	local cardWidth = if width ~= nil then width.X.Offset + (width.X.Scale * viewport.width) else viewport.width
	local buttonBesideText = not stack and cardWidth >= 360
	local absolute = y ~= nil or x ~= nil
	local layoutY = if y == nil then 0 else y
	return React.createElement("frame", {
		Size = if absolute then (width or UDim2.new(1, 0, 0, rowH)) else UDim2.fromScale(1, 1),
		Position = if x ~= nil then UDim2.new(x.X.Scale, x.X.Offset, 0, layoutY) else UDim2.fromOffset(0, layoutY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding else 14,
		interactive = true,
		reducedMotion = softMotion,
	}, React.createElement(IconTile, {
		kind = if unlocked then ((machine.Icon) or "Forge") else "Lock",
		accent = if unlocked then machine.Color else Palette.muted,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 6 else 16),
		spin = false,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = if buttonBesideText then UDim2.new(1, -210, 1, -4) elseif stack then UDim2.new(1, -60, 0, 78) else UDim2.new(1, -60, 0, 78),
		Position = UDim2.fromOffset(58, if stack or not buttonBesideText then 2 else 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = machine.Name,
		size = if stack then 17 else 16,
		color = if unlocked then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.new(1, -4, 0, 22),
	}), React.createElement(Text, {
		value = if unlocked then machine.Description else lockReason,
		size = if stack then chrome.labelText else 11,
		color = if unlocked then Palette.muted else machine.Color,
		weight = if unlocked then Enum.FontWeight.Regular else Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, -4, 0, if stack then 42 else 34),
	}), unlocked and React.createElement(Text, {
		value = rateLine,
		size = if stack then chrome.labelText else 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 72 else 64),
		sizeConstraint = UDim2.new(1, -4, 0, 16),
	}), running and buttonBesideText and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, 84),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(0.28, 0, 1, 0),
		Position = flow:map(function(phase)
			return UDim2.new(phase * 1.4 - 0.32, 0, 0, 0)
		end),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})))), if not ready and unlocked and not maxed then React.createElement(Button, {
		text = buyLabel,
		icon = "Flux",
		onClick = onBuy,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if buttonBesideText then UDim2.fromOffset(150, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
		position = if buttonBesideText then UDim2.new(1, -158, 0.5, -TapTarget / 2) else UDim2.new(0, 0, 1, -(TapTarget + 4)),
		reducedMotion = softMotion,
		disabled = true,
		highlight = false,
	}) else React.createElement(Button, {
		text = buyLabel,
		icon = if unlocked then "Flux" else "Lock",
		onClick = onBuy,
		color = if ready then machine.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = if buttonBesideText then UDim2.fromOffset(150, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
		position = if buttonBesideText then UDim2.new(1, -158, 0.5, -TapTarget / 2) else UDim2.new(0, 0, 1, -(TapTarget + 4)),
		reducedMotion = softMotion,
		disabled = not ready,
		highlight = ready,
	})))
end
local SORT_OPTIONS = { {
	id = "Default",
	label = "Tier order",
}, {
	id = "Cheapest",
	label = "Cheapest first",
}, {
	id = "Output",
	label = "Highest output",
}, {
	id = "Level",
	label = "Highest level",
} }
local function UpgradeBoard(_param)
	local title = _param.title
	local eyebrow = _param.eyebrow
	local blurb = _param.blurb
	local accent = _param.accent
	local entries = _param.entries
	local state = _param.state
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local onBuy = _param.onBuy
	local onBuyAll = _param.onBuyAll
	local featurePanel = _param.featurePanel
	local featurePanelHeight = _param.featurePanelHeight
	if featurePanelHeight == nil then
		featurePanelHeight = 0
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — VirtualGrid overscan / Buy CTAs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	-- Canonical softMotion antilag gate — WorkshopBoard.
	local workshopHostReveal = useStagger(4, softMotion)
	local workshopBuyHostRef = React.useRef(nil)
	-- Gamepad: park Selection on BUY ALL (FocusClaim prefers Claim/Buy-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = workshopBuyHostRef.current
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
	end, { buyAmount, #entries })
	local query, setQuery = React.useState("")
	local sort, setSort = React.useState("Default")
	local filter, setFilter = React.useState("All")
	local headerReveal = useStagger(0, softMotion)
	local controlsReveal = useStagger(1, softMotion)
	local featureReveal = useStagger(2, softMotion)
	local gridReveal = useStagger(3, softMotion)
	local cash = state.Cash
	local canBuy = function(entry)
		return entry.unlocked and not entry.maxed and gteFlux(cash, entry.price)
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = function(total, entry)
		return total + (if canBuy(entry) then 1 else 0)
	end
	for _i = 1, #entries do
		_result = _callback(_result, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local affordableCount = _result
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_1 = function(total, entry)
		return total + (if entry.level > 0 then 1 else 0)
	end
	for _i = 1, #entries do
		_result_1 = _callback_1(_result_1, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local ownedCount = _result_1
	local near = AppHelpers:trimFarLockedUpgrades(entries)
	-- ▼ ReadonlyArray.reduce ▼
	local _result_2 = 0
	local _callback_2 = function(total, entry)
		return total + (if not entry.unlocked then 1 else 0)
	end
	for _i = 1, #near do
		_result_2 = _callback_2(_result_2, near[_i], _i - 1, near)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local nextCount = _result_2
	local filterOptions = { {
		id = "All",
		label = "Near unlocks",
		count = #near,
	}, {
		id = "Affordable",
		label = "Can afford",
		count = affordableCount,
	}, {
		id = "Owned",
		label = "Owned",
		count = ownedCount,
	}, {
		id = "Next",
		label = "Coming up",
		count = nextCount,
	} }
	local needle = string.lower(query)
	local pool = if needle ~= "" then entries else near
	local visible = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback_3 = function(entry)
		if filter == "Affordable" and not canBuy(entry) then
			return nil
		end
		if filter == "Owned" and entry.level <= 0 then
			return nil
		end
		if filter == "Next" and entry.unlocked then
			return nil
		end
		if needle ~= "" then
			local haystack = string.lower((entry.config.Name .. " " .. entry.config.Description))
			local found = string.find(haystack, needle, 1, true)
			if found == nil then
				return nil
			end
		end
		local _entry = entry
		table.insert(visible, _entry)
	end
	for _k, _v in pool do
		_callback_3(_v, _k - 1, pool)
	end
	-- ▲ ReadonlyArray.forEach ▲
	table.sort(visible, function(left, right)
		if sort == "Cheapest" then
			return compareFlux(left.price, right.price) < 0
		end
		if sort == "Output" then
			local _condition = right.config.BaseProduction
			if _condition == nil then
				_condition = 0
			end
			local _condition_1 = left.config.BaseProduction
			if _condition_1 == nil then
				_condition_1 = 0
			end
			return _condition < _condition_1
		end
		if sort == "Level" then
			return right.level < left.level
		end
		return left.order < right.order
	end)
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local searchW = 252
	local sortW = 176
	local filterW = 176
	local controlGap = 12
	local controlsWrap = not stack and viewport.width < 900
	-- Portrait: title + Buy All + search/filters. Landscape: Buy All only.
	-- Keep machines above the fold — every 20px of header is a lost buy CTA.
	local stackControlsY = if chrome.landscape then 40 else 56
	-- Header must clear the search row. A short section lets those controls
	-- paint on top of the first machine cards.
	local headerHeight = if chrome.landscape and stack then 136 elseif stack then 268 else (if controlsWrap then 232 else 188)
	local rowH = PageBoardHeights.Machine(stack)
	local gap = if stack then chrome.panelGap else Layout.panelGap
	local columns = if stack then 1 elseif viewport.width >= 2200 then 4 elseif viewport.width >= 1400 then 3 elseif viewport.width >= 900 then 2 else 1
	local rowStride = rowH + gap
	local columnWidth = UDim2.new(1 / columns, -(gap * (columns - 1)) / columns, 0, rowH)
	local gridRows = math.ceil(math.max(1, #visible) / columns)
	-- Machines come first so buy CTAs stay above the fold; AutoForge sits below the grid.
	local machinesBlock = if #visible == 0 then 150 else (gridRows * rowH + math.max(0, gridRows - 1) * gap)
	-- Extra mobile scroll tail so the floating vault/tap cluster never covers the last Buy button.
	local machineScrollTail = if stack then scrollTail(stack, chrome.bottomSafe, if chrome.landscape then 52 else 80) else scrollTail(stack, chrome.bottomSafe, 28)
	local scrollRef = React.useRef()
	local controlH = TapTarget
	local desktopControlH = if touchLayout then TapTarget else 40
	local controlsY = if controlsWrap then 98 else 100
	local sortX = searchW + controlGap
	local filterX = sortX + sortW + controlGap
	local wrapRowY = controlsY + desktopControlH + 6
	local stackCompact = stack and chrome.landscape
	local stackSearchY = stackControlsY + controlH + 6
	local stackFilterY = stackControlsY + (controlH + 6) * 2
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = if stack then chrome.cardPadding else 14,
		reveal = headerReveal,
		zIndex = 30,
		clips = false,
	}, React.createElement(Text, {
		value = eyebrow,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 14 else 18),
	}), React.createElement(Text, {
		value = title,
		size = if stack then (if stackCompact then 18 else 20) else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 14 else 16),
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 26 else 30),
	}), not stackCompact and React.createElement(Text, {
		value = blurb,
		size = if stack then chrome.labelText else 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, if stack then 42 else 46),
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 20 else 34),
	}), not stack and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = compactNumber(state.Production) .. " / sec",
		size = 14,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.new(1, -236, 0, 2),
		sizeConstraint = UDim2.new(0, 228, 0, 18),
		align = Enum.TextXAlignment.Right,
	}), React.createElement(AmountToggle, {
		value = buyAmount,
		onChange = setBuyAmount,
		accent = accent,
		position = UDim2.new(1, -236, 0, 22),
		size = UDim2.fromOffset(228, desktopControlH),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if affordableCount > 0 then `Buy all you can · {affordableCount}` else "Nothing to buy yet",
		icon = "Flux",
		onClick = function()
			local _result_3 = onBuyAll
			if _result_3 ~= nil then
				_result_3 = _result_3()
			end
			return _result_3
		end,
		color = if affordableCount > 0 then accent else Palette.panelSoft,
		textColor = if affordableCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(228, 30),
		position = UDim2.new(1, -236, 0, 66),
		disabled = affordableCount <= 0 or onBuyAll == nil,
		reducedMotion = reducedMotion,
		highlight = affordableCount > 0,
	}), React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = accent,
		placeholder = "Search upgrades",
		position = UDim2.fromOffset(0, controlsY),
		size = UDim2.fromOffset(searchW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 31,
	}), if controlsWrap then React.createElement(React.Fragment, nil, React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.fromOffset(0, wrapRowY),
		size = UDim2.fromOffset(sortW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.fromOffset(sortW + controlGap, wrapRowY),
		size = UDim2.fromOffset(filterW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	})) else React.createElement(React.Fragment, nil, React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.fromOffset(sortX, controlsY),
		size = UDim2.fromOffset(sortW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.fromOffset(filterX, controlsY),
		size = UDim2.fromOffset(filterW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	}))), stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
		value = buyAmount,
		onChange = setBuyAmount,
		accent = accent,
		position = UDim2.new(0, 0, 0, stackControlsY),
		size = UDim2.new(0.62, -6, 0, controlH),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if affordableCount > 0 then "Buy all you can" else "Nothing to buy",
		icon = "Flux",
		onClick = function()
			local _result_3 = onBuyAll
			if _result_3 ~= nil then
				_result_3 = _result_3()
			end
			return _result_3
		end,
		color = if affordableCount > 0 then accent else Palette.panelSoft,
		textColor = if affordableCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.new(0.38, -6, 0, controlH),
		position = UDim2.new(0.62, 6, 0, stackControlsY),
		disabled = affordableCount <= 0 or onBuyAll == nil,
		reducedMotion = reducedMotion,
		highlight = affordableCount > 0,
	}), not stackCompact and React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = accent,
		placeholder = "Search upgrades",
		position = UDim2.new(0, 0, 0, stackSearchY),
		size = UDim2.new(1, 0, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 31,
	}), not stackCompact and React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.new(0, 0, 0, stackFilterY),
		size = UDim2.new(0.5, -4, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), not stackCompact and React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.new(0.5, 4, 0, stackFilterY),
		size = UDim2.new(0.5, -4, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	})))
	local machinesElement
	if #visible == 0 then
		machinesElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(EmptyState, {
		icon = "Forge",
		title = if needle ~= "" or filter ~= "All" then "Nothing matches" elseif filter == "Affordable" then "Can't afford a machine yet" else "No machines to show",
		body = if needle ~= "" then "Clear the search to see the machines again." elseif filter == "Affordable" then "Collect Flux on Overview, then come back to buy the next machine." elseif filter ~= "All" then "Switch the filter back to Near unlocks." else "Buy a machine to start earning Flux into your vault.",
		accent = accent,
		size = UDim2.fromScale(1, 1),
	}), filter == "Affordable" and affordableCount == 0 and React.createElement(Button, {
		text = "Show next machines",
		icon = "Forge",
		onClick = function()
			setFilter("All")
		end,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = reducedMotion,
		highlight = true,
	}))
	else
		machinesElement = React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #visible,
			columns = columns,
			cellHeight = rowH,
			gap = gap,
			overscanRows = if softMotion then 0 else (if stack then 2 else 3),
			itemKey = function(index)
				return visible[index + 1].config.Id
			end,
			renderItem = function(index)
				local entry = visible[index + 1]
				return React.createElement(MachineRow, {
					machine = entry.config,
					level = entry.level,
					cash = state.Cash,
					buyAmount = buyAmount,
					reducedMotion = reducedMotion,
					onBuy = function()
						return onBuy(entry.config.Id)
					end,
					width = columnWidth,
					unlocked = entry.unlocked,
					lockReason = entry.lockReason,
					lockShort = entry.lockShort,
				})
			end,
		})
	end
	local sections = {
		{
			id = "header",
			height = headerHeight,
			element = headerPanel,
		},
		{
			id = "machines",
			height = machinesBlock,
			element = machinesElement,
		},
	}
	if featurePanel ~= nil then
		table.insert(sections, {
			id = "autoforge",
			height = featurePanelHeight,
			element = featurePanel,
		})
	end
	return React.createElement("frame", {
		Name = "WorkshopBuyClaim",
		ref = workshopBuyHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- FocusClaim BUY ALL / machine Buy must not clip CTA overshoot.
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 0,
		reveal = workshopHostReveal,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = gap,
		tailPad = machineScrollTail,
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = sections,
	})))
end

local AUTO_FORGE_RESERVES = { {
	id = "NONE",
	label = "No reserve",
}, {
	id = "SAFE",
	label = "Keep 25%",
}, {
	id = "HALF",
	label = "Keep 50%",
}, {
	id = "HIGH",
	label = "Keep 75%",
} }
local function AutoForgePanel(_param)
	local state = _param.state
	local machines = _param.machines
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local viewport = useViewport()
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AutoForge controls drop springs on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chromeFor(viewport).stack
	local _condition = state.AutoForge
	if _condition == nil then
		local _object = {
			Enabled = false,
		}
		local _left = "MachineId"
		local _result = machines[1]
		if _result ~= nil then
			_result = _result.Id
		end
		local _condition_1 = _result
		if _condition_1 == nil then
			_condition_1 = "StellarCore"
		end
		_object[_left] = _condition_1
		_object.Reserve = 0.25
		_object.Bought = 0
		_condition = _object
	end
	local queue = _condition
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(machine)
		return machine.Id == queue.MachineId
	end
	local _result
	for _i, _v in machines do
		if _callback(_v, _i - 1, machines) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = machines[1]
	end
	local target = _condition_1
	local machineOptions = (function()
		local options = {}
		local seen = {}
		local push = function(machine)
			local _id = machine.Id
			if seen[_id] ~= nil then
				return nil
			end
			local _id_1 = machine.Id
			seen[_id_1] = true
			local _arg0 = {
				id = machine.Id,
				label = machine.Name,
			}
			table.insert(options, _arg0)
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback_1 = function(machine)
			return machine.Id == queue.MachineId
		end
		local _result_1
		for _i, _v in machines do
			if _callback_1(_v, _i - 1, machines) == true then
				_result_1 = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local current = _result_1
		if current ~= nil then
			push(current)
		end
		do
			local index = #machines - 1
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index -= 1
				else
					_shouldIncrement = true
				end
				if not (index >= 0 and #options < 24) then
					break
				end
				local machine = machines[index + 1]
				local _condition_2 = state.Machines[machine.Id]
				if _condition_2 == nil then
					_condition_2 = 0
				end
				if _condition_2 > 0 then
					push(machine)
				end
			end
		end
		for _, machine in machines do
			if #options >= 40 then
				break
			end
			local _exp = state.Zone
			local _condition_2 = machine.RequiredZone
			if _condition_2 == nil then
				_condition_2 = 1
			end
			if _exp < _condition_2 then
				continue
			end
			local _exp_1 = state.Rebirths
			local _condition_3 = machine.RequiredRebirths
			if _condition_3 == nil then
				_condition_3 = 0
			end
			if _exp_1 < _condition_3 then
				continue
			end
			local _condition_4 = machine.PreviousId ~= nil
			if _condition_4 then
				local _condition_5 = state.Machines[machine.PreviousId]
				if _condition_5 == nil then
					_condition_5 = 0
				end
				local _condition_6 = machine.PreviousLevel
				if _condition_6 == nil then
					_condition_6 = 1
				end
				_condition_4 = _condition_5 < _condition_6
			end
			if _condition_4 then
				continue
			end
			push(machine)
		end
		return options
	end)()
	local _result_1
	if target ~= nil then
		local _condition_2 = state.Machines[target.Id]
		if _condition_2 == nil then
			_condition_2 = 0
		end
		_result_1 = _condition_2
	else
		_result_1 = 0
	end
	local level = _result_1
	local nextCost = if target ~= nil and level < target.MaxLevel then bulkCost(target.BaseCost, target.CostScale, level, 1, target.MaxLevel) else 0
	local _condition_2 = target ~= nil
	if _condition_2 then
		local _exp = state.Zone
		local _condition_3 = target.RequiredZone
		if _condition_3 == nil then
			_condition_3 = 1
		end
		local _condition_4 = _exp < _condition_3
		if not _condition_4 then
			local _exp_1 = state.Rebirths
			local _condition_5 = target.RequiredRebirths
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_condition_4 = _exp_1 < _condition_5
			if not _condition_4 then
				local _condition_6 = target.PreviousId ~= nil
				if _condition_6 then
					local _condition_7 = state.Machines[target.PreviousId]
					if _condition_7 == nil then
						_condition_7 = 0
					end
					local _condition_8 = target.PreviousLevel
					if _condition_8 == nil then
						_condition_8 = 1
					end
					_condition_6 = _condition_7 < _condition_8
				end
				_condition_4 = _condition_6
			end
		end
		_condition_2 = _condition_4
	end
	local targetLocked = _condition_2
	local waiting = not targetLocked and target ~= nil and level < target.MaxLevel and not gteFlux(state.Cash, nextCost)
	local status = if not queue.Enabled then "PAUSED" elseif target == nil or level >= target.MaxLevel then "TARGET COMPLETE" elseif targetLocked then "WAITING FOR UNLOCK" elseif waiting then `WAITING FOR {compactNumber(nextCost)} FLUX` else "NEXT LEVEL QUEUED"
	local _result_2
	if not queue.Enabled then
		_result_2 = "PAUSED"
	else
		local _result_3
		if targetLocked then
			_result_3 = "LOCKED"
		else
			local _result_4
			if waiting then
				_result_4 = "WAITING"
			else
				local _condition_3 = target == nil
				if not _condition_3 then
					local _condition_4 = target.MaxLevel
					if _condition_4 == nil then
						_condition_4 = 0
					end
					_condition_3 = level >= _condition_4
				end
				_result_4 = if _condition_3 then "DONE" else "LIVE"
			end
			_result_3 = _result_4
		end
		_result_2 = _result_3
	end
	local badgeStatus = _result_2
	local apply = function(enabled, machineId, reserve)
		if machineId == nil then
			machineId = queue.MachineId
		end
		if reserve == nil then
			reserve = queue.Reserve
		end
		return dispatch("SetAutoForge", {
			Enabled = enabled,
			MachineId = machineId,
			Reserve = reserve,
		})
	end
	local controlY = if stack then 124 else 102
	local machineW = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(270, 42)
	local reserveW = if stack then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.fromOffset(174, 42)
	local buttonW = if stack then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.fromOffset(158, 42)
	local _exp = React.createElement(IconTile, {
		kind = "Forge",
		accent = if queue.Enabled then Palette.mango else Palette.muted,
		size = 48,
		radius = 12,
		position = UDim2.fromOffset(0, 0),
		spin = queue.Enabled,
		reducedMotion = softMotion,
	})
	local _exp_1 = React.createElement(Text, {
		value = "AUTO-FORGE",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(62, 0),
		sizeConstraint = UDim2.new(1, if stack then -168 else -220, 0, 16),
	})
	local _exp_2 = React.createElement(Text, {
		value = "Your production queue",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(62, 16),
		sizeConstraint = UDim2.new(1, if stack then -168 else -220, 0, 24),
	})
	local _exp_3 = React.createElement(Text, {
		value = if stack then "Buys one level at a time and never spends your reserve." else "Pick a machine. Auto-Forge buys one affordable level at a time and leaves your saved flux alone.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(62, 42),
		sizeConstraint = UDim2.new(1, if stack then -168 else -70, 0, if stack then 36 else 28),
	})
	local _exp_4 = React.createElement(Badge, {
		value = if stack then badgeStatus else status,
		accent = if queue.Enabled then Palette.mint else Palette.muted,
		position = if stack then UDim2.new(1, -92, 0, 0) else UDim2.new(1, -210, 0, 4),
		size = if stack then UDim2.fromOffset(88, 24) else UDim2.fromOffset(200, 22),
	})
	local _exp_5 = not stack and React.createElement(Text, {
		value = `{compactNumber(queue.Bought)} AUTO LEVELS`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -210, 0, 30),
		sizeConstraint = UDim2.new(0, 210, 0, 16),
	})
	local _attributes = {
		options = machineOptions,
	}
	local _result_3 = target
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	local _condition_3 = _result_3
	if _condition_3 == nil then
		local _result_4 = machineOptions[1]
		if _result_4 ~= nil then
			_result_4 = _result_4.id
		end
		_condition_3 = _result_4
		if _condition_3 == nil then
			_condition_3 = "StellarCore"
		end
	end
	_attributes.value = _condition_3
	_attributes.onChange = function(id)
		return apply(queue.Enabled, id, queue.Reserve)
	end
	_attributes.accent = Palette.mango
	_attributes.label = "TARGET MACHINE"
	_attributes.position = UDim2.fromOffset(0, controlY)
	_attributes.size = machineW
		_attributes.reducedMotion = softMotion
	_attributes.zIndex = 54
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, height),
		accent = Palette.mango,
		background = darken(Palette.mango, 0.9),
		padding = 14,
		layoutOrder = 1,
		reducedMotion = softMotion,
		zIndex = 24,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, React.createElement(Dropdown, _attributes), React.createElement(Dropdown, {
		options = AUTO_FORGE_RESERVES,
		value = AppHelpers:reserveId(queue.Reserve),
		onChange = function(id)
			return apply(queue.Enabled, queue.MachineId, AppHelpers:reserveValue(id))
		end,
		accent = Palette.cyan,
		label = "FLUX RESERVE",
		position = if stack then UDim2.fromOffset(0, controlY + TapTarget + 26) else UDim2.fromOffset(282, controlY),
		size = reserveW,
		reducedMotion = softMotion,
		zIndex = 52,
	}), React.createElement("frame", {
		Size = buttonW,
		Position = if stack then UDim2.new(0.5, 5, 0, controlY + TapTarget + 26) else UDim2.fromOffset(468, controlY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 26,
	}, React.createElement(Button, {
		text = if queue.Enabled then "PAUSE QUEUE" else "START QUEUE",
		icon = if queue.Enabled then "Pause" else "Play",
		onClick = function()
			return apply(not queue.Enabled)
		end,
		color = if queue.Enabled then Palette.panelSoft else Palette.mango,
		textColor = if queue.Enabled then Palette.cream else Palette.ink,
		outline = queue.Enabled,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = not queue.Enabled,
		zIndex = 27,
	})))
end
local function listedFluxPerSec(machine): number
	local base = if type(machine) == "table" then machine.BaseProduction else nil
	if type(base) ~= "number" or base <= 0 then
		return 0
	end
	return base
end
local function WorkshopView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chainStack = chromeFor(viewport).contentStack
	local stellarLevel = state.Machines.StellarCore
	if stellarLevel == nil then
		stellarLevel = 0
	end
	local firstMachine = stellarLevel < 1
	local chainLine = nil
	if not firstMachine and config ~= nil and type(config.Machines) == "table" then
		local names = {}
		for _, machine in config.Machines do
			if type(machine) == "table" and type(machine.Id) == "string" then
				names[machine.Id] = if type(machine.Name) == "string" then machine.Name else machine.Id
			end
		end
		for _, machine in config.Machines do
			if type(machine) ~= "table" or type(machine.PreviousId) ~= "string" then
				continue
			end
			local needLevel = machine.PreviousLevel
			if type(needLevel) ~= "number" then
				needLevel = 1
			end
			local haveLevel = state.Machines[machine.PreviousId]
			if type(haveLevel) ~= "number" then
				haveLevel = 0
			end
			local rebirthsNeed = machine.RequiredRebirths
			if type(rebirthsNeed) ~= "number" then
				rebirthsNeed = 0
			end
			local zoneNeed = machine.RequiredZone
			if type(zoneNeed) ~= "number" then
				zoneNeed = 1
			end
			local rebirthsHave = state.Rebirths
			if type(rebirthsHave) ~= "number" then
				rebirthsHave = 0
			end
			local zoneHave = state.Zone
			if type(zoneHave) ~= "number" then
				zoneHave = 1
			end
			local machineName = if type(machine.Name) == "string" then machine.Name else machine.Id
			local rate = listedFluxPerSec(machine)
			local earns = if rate > 0 then ` earns {compactNumber(rate)} Flux/sec` else ""
			local rateBit = if rate > 0 then ` +{compactNumber(rate)}/sec` else ""
			if rebirthsHave < rebirthsNeed then
				chainLine = if chainStack
					then `{machineName}{rateBit}. {rebirthsHave}/{rebirthsNeed} rebirths.`
					else `{machineName}{earns}. Needs {rebirthsNeed} rebirth{if rebirthsNeed == 1 then "" else "s"}. You have {rebirthsHave}.`
				break
			elseif zoneHave < zoneNeed then
				chainLine = if chainStack
					then `{machineName}{rateBit}. World {zoneHave}/{zoneNeed}.`
					else `{machineName}{earns}. Needs world {zoneNeed}. You are on world {zoneHave}.`
				break
			elseif haveLevel < needLevel then
				local prevName = names[machine.PreviousId]
				if prevName == nil then
					prevName = machine.PreviousId
				end
				chainLine = if chainStack
					then `Next: {machineName}{rateBit}. {prevName} {haveLevel}/{needLevel}.`
					elseif rate > 0
					then `Next: {machineName} earns {compactNumber(rate)} Flux/sec. Get {prevName} to level {needLevel}. You have {haveLevel}.`
					else `Next: {machineName}. Get {prevName} to level {needLevel}. You have {haveLevel}.`
				break
			end
		end
	end
	local entries = React.useMemo(function()
		return AppHelpers:buildUpgradeEntries(config.Machines, state.Machines, state)
	end, { config.Machines, state.Machines, state.Zone, state.Rebirths })
	local featureHeight = if chromeFor(viewport).landscape then 128 elseif chromeFor(viewport).stack then 188 else 168
	return React.createElement(UpgradeBoard, {
		title = if firstMachine then "Buy a machine" else "More hands. Less waiting.",
		eyebrow = if firstMachine then "EARNS FLUX" else "BUILD QUEUE",
		blurb = if firstMachine then "A machine earns Flux into your vault every second." elseif chainLine ~= nil then chainLine else "More machines = more flux, even while you're AFK.",
		accent = Palette.coral,
		entries = entries,
		state = state,
		buyAmount = buyAmount,
		setBuyAmount = setBuyAmount,
		reducedMotion = reducedMotion,
		onBuy = function(id)
			return dispatch("BuyMachine", {
				Id = id,
				Amount = amountPayload(buyAmount),
			})
		end,
		onBuyAll = function()
			-- ▼ ReadonlyArray.forEach ▼
			local _callback = function(entry)
				if entry.unlocked and not entry.maxed and gteFlux(state.Cash, entry.price) then
					dispatch("BuyMachine", {
						Id = entry.config.Id,
						Amount = "Max",
					})
				end
			end
			for _k, _v in entries do
				_callback(_v, _k - 1, entries)
			end
			-- ▲ ReadonlyArray.forEach ▲
		end,
		featurePanelHeight = featureHeight,
		featurePanel = React.createElement(AutoForgePanel, {
			state = state,
			machines = config.Machines,
			dispatch = dispatch,
			reducedMotion = reducedMotion,
			height = featureHeight,
		}),
	})
end
return {
	WorkshopView = WorkshopView,
}
