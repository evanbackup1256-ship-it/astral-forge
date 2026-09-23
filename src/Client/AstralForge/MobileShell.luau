-- Mobile shell (v2) — a ground-up rewrite of the touch/narrow-viewport navigation chrome.
--
-- The previous mobile pattern reused the desktop rail as a slide-out drawer, sharing one
-- animated spring (`railWidth`) between "desktop sidebar collapse" (a real width change) and
-- "mobile drawer open/close" (should have been a slide). Any interruption mid-animation left
-- the drawer visibly stuck at a partial size — a bug that survived three separate fix attempts
-- aimed at the symptom instead of the shape of the problem.
--
-- This shell removes the shared-animation hazard entirely by using a different navigation
-- pattern for touch/narrow viewports: a fixed-height bottom tab bar. Nothing about a tab bar's
-- container ever needs to resize or reposition — it is exactly Layout.tabBarH tall, anchored to
-- the bottom safe area, for the lifetime of the mobile session. Only icon/label emphasis
-- animates (a purely decorative tween on already-mounted, already-correctly-sized elements),
-- so there is no failure mode where the bar itself can render at a wrong size.
--
-- Overflow destinations (anything past the tab bar's `tabBarSlots`) live in a "More" sheet: a
-- bottom sheet that slides up from off-screen and is fully hidden (Visible=false) when closed,
-- so it never occupies layout space it could get stuck holding onto.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _motion = require(script.Parent.motion)
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _appNav = require(script.Parent.appNav)
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local CountBadge = _ui.CountBadge
local IconTile = _ui.IconTile
local Text = _ui.Text
local useButtonChrome = _ui.useButtonChrome
local Icon = require(script.Parent.Icon).Icon
local Audio = require(script.Parent.audio).Audio
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local function TabButton(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local disabled = entry.disabled == true
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	local selection = useFlipperSpring(if active and not disabled then 1 else 0, reducedMotion, 520, 34)
	local iconSize = 22
	local iconColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(entry.accent, math.clamp(raw, 0, 1))
	end)
	local labelColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.muted:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local liftY = selection:map(function(raw)
		return -math.round(math.clamp(raw, 0, 1) * 2)
	end)
	local indicatorSize = selection:map(function(raw)
		return UDim2.fromOffset(22 * math.clamp(raw, 0, 1), 3)
	end)
	local indicatorTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1)
	end)
	-- Packed to fit a TAP_TARGET (48px) tab core: icon + label must clear inside the bar
	-- before bottomSafe, especially on landscape phones.
	local iconTop = 3
	local labelTop = 26
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		ZIndex = 40,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 41,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = liftY:map(function(lift)
			return UDim2.new(0.5, 0, 0, iconTop + lift)
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = iconColor,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = iconSize,
		spin = false,
		reducedMotion = reducedMotion,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 44,
		compact = true,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 0, 0, labelTop),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 42,
	}), React.createElement("frame", {
		Size = indicatorSize,
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = entry.accent,
		BackgroundTransparency = indicatorTransparency,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local MoreCell
local function MoreSheet(_param)
	local open = _param.open
	local entries = _param.entries
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local bottomSafe = _param.bottomSafe
	local onClose = _param.onClose
	local viewportHeight = _param.viewportHeight
	local visible = AppHelpers:filterNav(entries, state, tutorialPage)
	local cols = math.max(1, math.min(_param.moreCols or 4, #visible))
	local cellH = _param.moreCellH or 72
	local rows = math.max(1, math.ceil(#visible / cols))
	local rawSheetH = rows * (cellH + 8) + bottomSafe + 64
	local maxSheetH = if viewportHeight and viewportHeight > 0 then math.floor(viewportHeight * 0.8) else rawSheetH
	local sheetH = math.min(rawSheetH, maxSheetH)
	local gridH = math.min(rows * (cellH + 8), maxSheetH - bottomSafe - 64)
	local needsScroll = rawSheetH > maxSheetH
	local reveal = useFlipperSpring(if open then 1 else 0, reducedMotion, 780, 44)
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.6
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		ZIndex = 200,
		Event = {
			Activated = function()
				Audio:play("close")
				onClose()
			end,
		},
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 20),
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.62,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(40, 4),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 202,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_4 = React.createElement(Text, {
		value = "MORE",
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 202,
	})
	local _exp_5 = React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / cols, -8, 0, cellH),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#visible)
	local _callback = function(entry, index)
		return React.createElement(MoreCell, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				setPage(entry.id)
				onClose()
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in visible do
		_newValue[_k] = _callback(_v, _k - 1, visible)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
		Visible = open,
	}, _exp, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, sheetH),
		AnchorPoint = Vector2.new(0, 1),
		Position = reveal:map(function(amount)
			return UDim2.new(0, 0, 1, math.round((1 - math.clamp(amount, 0, 1)) * sheetH))
		end),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 201,
		ClipsDescendants = true,
	}, _exp_1, _exp_2, _exp_3, _exp_4, React.createElement(if needsScroll then "scrollingframe" else "frame", (function()
		local props = {
			Size = UDim2.new(1, -16, 0, math.max(1, gridH)),
			Position = UDim2.fromOffset(8, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 202,
		}
		if needsScroll then
			props.ScrollBarThickness = 6
			props.ScrollingEnabled = true
			props.CanvasSize = UDim2.new(0, 0, 0, rows * (cellH + 8))
			props.AutomaticCanvasSize = Enum.AutomaticSize.Y
		end
		return props
	end)(), _exp_5, _newValue)))
end
function MoreCell(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local disabled = entry.disabled == true
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 203,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 204,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if active then darken(entry.accent, 0.7) else Palette.panelRaised,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ZIndex = 205,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if active then entry.accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.35 else 0.7,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 205,
		radius = 14,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 206,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = 24,
		spin = false,
		reducedMotion = reducedMotion,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 207,
		compact = true,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(2, 40),
		sizeConstraint = UDim2.new(1, -4, 0, 26),
		zIndex = 206,
	}))))
end
-- The fixed-height bottom tab bar. Size is a pure function of the viewport (via
-- chrome.tabBarH / chrome.tabBarSlots computed in mobileLayout.ts) — it is set once per
-- viewport change and never animates, so there is no "stuck mid-resize" failure mode.
local function MobileTabBar(_param)
	local page = _param.page
	local setPage = _param.setPage
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomSafe = _param.bottomSafe
	local visible = _param.visible
	if visible == nil then
		visible = true
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local enter = useEntrance(reducedMotion)
	local moreOpen, setMoreOpen = React.useState(false)
	local _array = {}
	local _length = #_array
	local _pRIMARY_NAVLength = #PRIMARY_NAV
	table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength, _length + 1, _array)
	_length += _pRIMARY_NAVLength
	table.move(MORE_NAV, 1, #MORE_NAV, _length + 1, _array)
	local allVisible = AppHelpers:filterNav(_array, state, tutorialPage)
	local slots = math.max(3, chrome.tabBarSlots)
	-- Reserve one slot for "More" whenever there's overflow; otherwise every visible entry
	-- fits directly on the bar.
	local needsMore = #allVisible > slots
	local primaryCount = if needsMore then slots - 1 else slots
	local primary = {}
	local overflow = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(entry, index)
		if index < primaryCount then
			local _entry = entry
			table.insert(primary, _entry)
		else
			local _overflow = overflow
			local _entry = entry
			table.insert(_overflow, _entry)
		end
	end
	for _k, _v in allVisible do
		_callback(_v, _k - 1, allVisible)
	end
	-- ▲ ReadonlyArray.forEach ▲
	-- If the current page is buried in overflow, still show it in the bar in place of the
	-- last primary slot so the active tab is never invisible to the player. The swap has to
	-- move the displaced primary entry into the More sheet AND take the active entry out of
	-- it — leaving the active entry in `overflow` rendered it twice (tab bar + More sheet,
	-- duplicate React keys) while the displaced entry vanished from the sheet entirely.
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(entry)
		return entry.id == page
	end
	local _result
	for _i, _v in overflow do
		if _callback_1(_v, _i - 1, overflow) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local activeInOverflow = _result
	if activeInOverflow ~= nil and #primary > 0 then
		local displaced = primary[#primary]
		primary[#primary] = activeInOverflow
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback_2 = function(entry)
			return entry.id ~= activeInOverflow.id
		end
		local _length_1 = 0
		for _k, _v in overflow do
			if _callback_2(_v, _k - 1, overflow) == true then
				_length_1 += 1
				_newValue[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		overflow = _newValue
		if displaced ~= nil then
			table.insert(overflow, 1, displaced)
		end
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_2 = function(sum, entry)
		return sum + AppHelpers:navBadge(entry, state, chatUnread)
	end
	for _i = 1, #overflow do
		_result_1 = _callback_2(_result_1, overflow[_i], _i - 1, overflow)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local overflowBadgeTotal = _result_1
	local moreActive = activeInOverflow ~= nil or moreOpen
	local _exp = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.5),
		Rotation = 90,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 41,
	})
	local _exp_2 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#primary)
	local _callback_3 = function(entry, index)
		return React.createElement("frame", {
			key = entry.id,
			Size = UDim2.new(1 / slots, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, React.createElement(TabButton, {
			entry = entry,
			active = page == entry.id,
			onClick = function()
				return setPage(entry.id)
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		}))
	end
	for _k, _v in primary do
		_newValue[_k] = _callback_3(_v, _k - 1, primary)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = enter:map(function(amount)
			return UDim2.new(0, 0, 1, math.round((1 - math.clamp(amount, 0, 1)) * (height * 0.6)))
		end),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 40,
		ClipsDescendants = false,
		Visible = visible,
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.new(1, -8, 0, height - bottomSafe),
		Position = UDim2.fromOffset(4, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 41,
	}, _exp_2, _newValue, needsMore and React.createElement("frame", {
		key = "more",
		Size = UDim2.new(1 / slots, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = primaryCount,
	}, React.createElement(TabButton, {
		entry = {
			id = "Overview",
			label = "More",
			eyebrow = "",
			icon = "Menu",
			accent = Palette.muted,
		},
		active = moreActive,
		onClick = function()
			return setMoreOpen(true)
		end,
		reducedMotion = reducedMotion,
		badge = overflowBadgeTotal,
		layoutOrder = primaryCount,
	})))), React.createElement(MoreSheet, {
		open = moreOpen,
		entries = overflow,
		page = page,
		setPage = setPage,
		reducedMotion = reducedMotion,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		bottomSafe = bottomSafe,
		onClose = function()
			return setMoreOpen(false)
		end,
		viewportHeight = _param.viewportHeight,
		moreCols = _param.moreCols,
		moreCellH = _param.moreCellH,
	}))
end
-- Compact mobile header: logo mark, resource chips, and a vault-collect button. Replaces the
-- old TopBar's mobile branch — same information, laid out for a fixed-height single row
-- instead of the old desktop bar's row-stacking logic.
local MiniChip
local function MobileHeader(_param)
	local state = _param.state
	local page = _param.page
	local accent = _param.accent
	local width = _param.width
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local openPlayerlist = _param.openPlayerlist
	local entry = AppHelpers:pageEntry(page)
	local vaultReady = asFlux(state.Vault) >= 0.01
	local showDust = AppHelpers:featureUnlocked(state, "StarGrid")
	local showCores = AppHelpers:featureUnlocked(state, "Rebirth")
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	-- Reserve the right side purely for however wide the chip cluster actually needs (not a
	-- guessed percentage), and let the player-list button fill whatever's left. Guessed
	-- percentages on both sides is exactly what let them overlap in the middle on narrow
	-- phones once real (long) numbers pushed the chip row wider than assumed.
	local chipCount = (if showCores then 1 else 0) + (if showDust then 1 else 0) + 1
	local chipReserve = chipCount * 64 + (chipCount - 1) * 6 + 12
	return React.createElement("frame", {
		Size = UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(52, 2),
		Position = UDim2.fromOffset(14, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("imagebutton", {
		Size = UDim2.new(1, -chipReserve, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 4,
		Event = {
			Activated = function()
				Audio:play("playerlistOpen")
				openPlayerlist()
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = 30,
		radius = 10,
		position = UDim2.fromOffset(10, math.floor((barHeight - 30) / 2)),
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 4,
	}), React.createElement(Text, {
		value = entry.label,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(48, math.floor(barHeight / 2) - 10),
		sizeConstraint = UDim2.new(1, -56, 0, 20),
		zIndex = 4,
	}), visitorsHere > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(38, math.floor((barHeight - 30) / 2) - 2),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget - 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}), showCores and React.createElement(MiniChip, {
		label = "CORES",
		value = state.Cores,
		accent = Palette.violet,
		layoutOrder = 1,
	}), showDust and React.createElement(MiniChip, {
		label = "DUST",
		value = state.Stardust,
		accent = Palette.mango,
		layoutOrder = 2,
	}), React.createElement(MiniChip, {
		label = "FLUX",
		value = state.Cash,
		accent = if vaultReady then Palette.cyan else Palette.muted,
		layoutOrder = 3,
	})))
end
function MiniChip(_param)
	local value = _param.value
	local accent = _param.accent
	local layoutOrder = _param.layoutOrder
	return React.createElement("frame", {
		Size = UDim2.fromOffset(64, 30),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}), React.createElement(Text, {
		value = `{compactNumber(value)}`,
		size = 12,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(0, 0, 1, 0),
		zIndex = 2,
	}))
end
-- Floating vault/overcharge quick-action cluster anchored above the tab bar. Fixed position
-- (bottom-right, above the bar) — no drag/reposition in v2, since the tab bar already claims
-- the thumb-reachable bottom strip and a second freely-floating control invites exactly the
-- kind of overlap bugs the old floating quick bar produced.
local function MobileQuickActions(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local enter = useEntrance(reducedMotion)
	local tapReadyAt, setTapReadyAt = React.useState(0)
	local tapLeft, setTapLeft = React.useState(0)
	React.useEffect(function()
		if tapReadyAt <= 0 then
			setTapLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, tapReadyAt - os.clock())
				setTapLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.06)
		setTapLeft(0.06)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	local width = 190
	local height = 56
	-- AnchorPoint (1, 1): Position's Y is measured to this frame's OWN bottom edge, so
	-- `bottomOffset` (the tab bar's total height + a gap) places the cluster's bottom edge
	-- exactly that far above the screen bottom — i.e. directly above the tab bar, never
	-- overlapping it. Without an explicit anchor this defaults to the top-left corner, which
	-- silently made the same offset math place the cluster's TOP that far up and let its
	-- bottom (anchor + height) sink down past the tab bar's own top edge.
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(1, 1),
		Position = enter:map(function(amount)
			return UDim2.new(1, -edgePad, 1, -bottomOffset + math.round((1 - amount) * 14))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 38,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 39,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = 0.45,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -14, 0, 3),
		Position = UDim2.fromOffset(7, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 40,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFill > 0.92 then Palette.mango else Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -14, 0, TapTarget),
		Position = UDim2.fromOffset(7, height - TapTarget - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 41,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -3, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK {compactNumber(state.Vault)}` else "EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -3, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if tapLeft > 0.02 then string.format("%.1fs", tapLeft) else "TAP",
		icon = "Forge",
		onClick = tap,
		color = if tapLeft > 0.02 then Palette.panelSoft else Palette.cyan,
		textColor = if tapLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = tapLeft > 0.02,
		highlight = tapLeft <= 0.02,
	})))))
end
return {
	MobileTabBar = MobileTabBar,
	MobileHeader = MobileHeader,
	MobileQuickActions = MobileQuickActions,
}
