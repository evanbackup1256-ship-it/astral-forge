local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.Icon).Icon
local useAntilag = require(script.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.motion)
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local CountBadge = _ui.CountBadge
local Text = _ui.Text
local acquireDropdownPortal = _ui.acquireDropdownPortal
local releaseDropdownPortal = _ui.releaseDropdownPortal
local useButtonChrome = _ui.useButtonChrome
local _theme = require(script.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _appNav = require(script.Parent.appNav)
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
local Audio = require(script.Parent.audio).Audio
local InteractionFeedback = require(script.Parent.interaction).InteractionFeedback
local ActiveBoostIcon = require(script.Parent.TopBarChrome).ActiveBoostIcon

local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}

local MORE_BTN_W = 172

local function RailButton(_param)
	local entry = _param.entry
	local active = _param.active
	local collapsed = _param.collapsed
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local rowHeight = _param.rowHeight
	local bodySize = _param.bodySize
	local viewport = useViewport()
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — RailButton springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local touchChrome = viewport.compact or viewport.tight
	local disabled = entry.disabled == true
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local hoveredRef = React.useRef(false)
	local emphasis = useFlipperSpring(if not disabled and active then 1 elseif not disabled and hovered then 0.4 else 0, reducedMotion, 360, 28)
	local iconHover = useFlipperSpring(if not disabled and hovered then 1 else 0, reducedMotion, 520, 34)
	local press = useFlipperSpring(if pressed and not reducedMotion then 1 else 0, reducedMotion, 620, 36)
	local fill = emphasis:map(function(raw)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(raw, 0, 1))
	end)
	local fillTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return 0.34 - amount * 0.34
	end)
	local strokeTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return math.clamp(0.82 - amount * 0.62, 0.18, 0.85)
	end)
	local markerSize = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0, 3, 1, -18 - math.round((1 - amount) * 16))
	end)
	local tileFill = emphasis:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.52), math.clamp(raw, 0, 1))
	end)
	local ringTransparency = emphasis:map(function(raw)
		return math.clamp(0.78 - math.clamp(raw, 0, 1) * 0.7, 0.05, 0.82)
	end)
	local labelColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local eyebrowColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.muted:Lerp(entry.accent, math.clamp(raw, 0, 1))
	end)
	local pressWash = press:map(function(amount)
		return if touchChrome then math.clamp(1 - amount * 0.22, 0.78, 1) else 1
	end)
	local pressScale = press:map(function(amount)
		return if touchChrome then 1 - amount * 0.055 else 1
	end)
	local iconSize = if collapsed then 34 else 30
	local iconX = if collapsed then math.floor((Layout.sidebarCollapsedWidth - SHELL_CHROME.railGutter * 2 - iconSize) / 2) else 12
	local markHover = function()
		if disabled then
			return nil
		end
		if hoveredRef.current then
			return nil
		end
		hoveredRef.current = true
		setHovered(true)
		Audio:play("hover")
	end
	local clearHover = function()
		hoveredRef.current = false
		setHovered(false)
		setPressed(false)
	end
	React.useEffect(function()
		return subscribeInputCancellation(function()
			hoveredRef.current = false
			setHovered(false)
			setPressed(false)
		end)
	end, {})
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		Event = {
			Activated = function()
				local audioMarker = Audio:captureIntent()
				onClick()
				if not disabled then
					Audio:playIfUnclaimed(audioMarker, "tabSwitch")
				end
				InteractionFeedback.tap()
			end,
			MouseEnter = function()
				return markHover()
			end,
			MouseLeave = function()
				return clearHover()
			end,
			SelectionGained = function()
				return markHover()
			end,
			SelectionLost = function()
				return clearHover()
			end,
			InputBegan = function(_b, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(true)
				end
			end,
			InputEnded = function()
				return setPressed(false)
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pressScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -4, 1, -2),
		Position = press:map(function(amount)
			return UDim2.new(0, 2, 0, 1 + math.round(amount * (if touchChrome then 2 else 1)))
		end),
		BackgroundColor3 = fill,
		BackgroundTransparency = fillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.7),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), touchChrome and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = lighten(entry.accent, 0.35),
		BackgroundTransparency = pressWash,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})), React.createElement("frame", {
		Size = markerSize,
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = entry.accent,
		BackgroundTransparency = emphasis:map(function(amount)
			return if amount < 0.08 then 1 else 0.75 - amount * 0.75
		end),
		BorderSizePixel = 0,
		Visible = emphasis:map(function(amount)
			return amount >= 0.08
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = UDim2.new(0, iconX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = tileFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = entry.accent,
		Thickness = 1,
		Transparency = ringTransparency,
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft elseif active then lighten(entry.accent, 0.42) else Palette.muted,
		size = iconSize,
		spin = not disabled and hovered,
		hoverAmount = iconHover,
		reducedMotion = reducedMotion,
	})), not collapsed and React.createElement(Text, {
		value = entry.label,
		size = bodySize,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(56, 10),
		sizeConstraint = UDim2.new(1, -66, 0, 22),
	}), not collapsed and React.createElement(Text, {
		value = entry.eyebrow,
		size = 10,
		color = eyebrowColor,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(56, 34),
		sizeConstraint = UDim2.new(1, -66, 0, 18),
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 12,
	})))))
end
local function MoreDockButton(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local fill = _param.fill
	local disabled = entry.disabled == true
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDockButton springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	local selection = useFlipperSpring(if active and not disabled then 1 else 0, reducedMotion, 420, 32)
	local radius = 9
	local iconSize = if fill then 22 else 28
	local iconX = if fill then 7 else 9
	local textX = if fill then 38 else 49
	local fillColor = chrome.hoverAmount:map(function(amount)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(amount, 0, 1) * 0.6)
	end)
	-- On the desktop row, idle buttons carry no card surface at all -- with 20+ of these in one
	-- strip, giving every one its own border/fill turned the dock into a wall of identical boxes.
	-- Only the active page or whatever the pointer is currently over gets a card; everything else
	-- sits flat on the dock's own background, so the row reads as one toolbar with a highlight
	-- instead of a row of tiles. The mobile "More" sheet (fill=true) is a small deliberate grid,
	-- not a crowded strip, so it keeps a visible card on every cell -- that's what makes each
	-- touch target legible there.
	local cardTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(1 - selected * 0.94 - hoverAmount * 0.55, 0.06, 1)
	end)
	local activeFillTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1) * 0.78
	end)
	local strokeTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		local selected = math.clamp(raw, 0, 1)
		if fill then
			return math.clamp(0.72 - math.clamp(hovered, 0, 1) * 0.32 - selected * 0.48, 0.18, 0.76)
		end
		return math.clamp(1 - math.clamp(hovered, 0, 1) * 0.55 - selected * 0.82, 0.18, 1)
	end)
	local iconPosition = selection:map(function(raw)
		local selected = math.clamp(raw, 0, 1)
		return if fill then UDim2.new(0.5, 0, 0, 3 - math.round(selected * 2)) else UDim2.new(0, iconX, 0.5, -math.round(selected))
	end)
	local iconFill = selection:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.64), math.clamp(raw, 0, 1))
	end)
	-- Idle rows on the desktop strip keep a mostly-transparent icon tile so 20+ buttons in one row
	-- don't read as a wall of solid squares; hovering or being the active page fills the tile back
	-- in, which is what actually needs to draw the eye. The mobile grid keeps its icon tile solid.
	local iconFillTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if disabled then
			return 0.35
		end
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(0.62 - hoverAmount * 0.5 - selected * 0.62, 0, 0.62)
	end)
	local labelColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local underlineSize = selection:map(function(raw)
		return UDim2.new(0.46 * math.clamp(raw, 0, 1), 0, 0, 2)
	end)
	local underlineTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1)
	end)
	return React.createElement("frame", {
		Size = if fill then UDim2.fromScale(1, 1) else UDim2.fromOffset(MORE_BTN_W, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		ZIndex = 56,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 57,
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
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = fillColor,
		BackgroundTransparency = cardTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.55),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(entry.accent, 0.68),
		BackgroundTransparency = activeFillTransparency,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 58,
	}, React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 58,
		radius = radius,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = iconPosition,
		AnchorPoint = if fill then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		BackgroundColor3 = iconFill,
		BackgroundTransparency = iconFillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 59,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = iconSize,
		spin = not disabled and chrome.hovered,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = if fill then 11 else 12,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		align = if fill then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		fit = true,
		minSize = if fill then 9 else 10,
		position = if fill then UDim2.fromOffset(2, if fill then 26 else 4) else UDim2.fromOffset(textX, 12),
		sizeConstraint = if fill then UDim2.new(1, -4, 0, 16) else UDim2.new(1, -(textX + 6), 0, 22),
		zIndex = 59,
	}), React.createElement("frame", {
		Size = underlineSize,
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = lighten(entry.accent, 0.48),
		BackgroundTransparency = underlineTransparency,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 58,
		compact = true,
	}), not fill and React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 56,
	}))
end
-- Desktop equivalent of the mobile MoreSheet: a small grid popover anchored below the dock,
-- opened from a "MORE" trigger instead of always occupying screen width. Rendered through the
-- shared dropdown portal (a top-level ScreenGui) rather than nested under the dock's own frame,
-- since the dock's ancestor shell clips descendants to its own small strip -- anything drawn
-- inside that tree past the dock's bounds would be invisible. Closes on picking a page, Escape,
-- or clicking anywhere outside the panel.
local MoreCell
local function MoreDockPopover(_param)
	local entries = _param.entries
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local anchor = _param.anchor
	local onClose = _param.onClose
	local viewport = useViewport()
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDockPopover motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local portalLayer = React.useState(acquireDropdownPortal)
	React.useEffect(function()
		return function()
			return releaseDropdownPortal()
		end
	end, {})
	local panelRef = React.useRef()
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				onClose()
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			local panel = panelRef.current
			if panel == nil then
				return nil
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local origin = panel.AbsolutePosition
			local extent = panel.AbsoluteSize
			local inside = point.X >= origin.X and point.X <= origin.X + extent.X and point.Y >= origin.Y and point.Y <= origin.Y + extent.Y
			if not inside then
				onClose()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { onClose })
	local visible = AppHelpers:filterNav(entries, state, tutorialPage)
	local cols = math.min(5, math.max(3, math.ceil(math.sqrt(#visible))))
	local cellW = 132
	local cellH = 68
	local gap = 8
	local rows = math.max(1, math.ceil(#visible / cols))
	local panelW = cols * cellW + (cols - 1) * gap + 20
	local panelH = rows * cellH + (rows - 1) * gap + 56
	local clampedX = math.clamp(anchor.right - panelW, 10, math.max(10, viewport.width - panelW - 10))
	local clampedY = math.min(anchor.top, math.max(10, viewport.height - panelH - 10))
	local reveal = useFlipperSpring(1, reducedMotion, 780, 44)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = reveal:map(function(amount)
			return math.clamp(1 - amount * 0.38, 0.4, 1)
		end),
	})
	local _exp_2 = React.createElement(Text, {
		value = "MORE",
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 8),
		sizeConstraint = UDim2.new(1, -20, 0, 14),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
	})
	local _exp_3 = React.createElement("uigridlayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.new(0, gap, 0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
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
	return React.createElement(React.Fragment, nil, ReactRoblox.createPortal(React.createElement("frame", {
		ref = panelRef,
		Size = UDim2.fromOffset(panelW, panelH),
		Position = reveal:map(function(amount)
			return UDim2.fromOffset(clampedX, clampedY + math.round((1 - math.clamp(amount, 0, 1)) * 10))
		end),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 220,
		ClipsDescendants = true,
		Visible = reveal:map(function(amount)
			return amount > 0.01
		end),
	}, _exp, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -20, 1, -34),
		Position = UDim2.fromOffset(10, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 221,
	}, _exp_3, _newValue)), portalLayer))
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreCell springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 93,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 94,
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
		ZIndex = 95,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if active then entry.accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.35 else 0.7,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 95,
		radius = 12,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = 22,
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(2, 36),
		sizeConstraint = UDim2.new(1, -4, 0, 26),
		zIndex = 96,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 97,
		compact = true,
	}))))
end
local function MoreDock(_param)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MoreDock motion drops on soft tiers.
	local softMotion = (_param.reducedMotion or false) or antilag.tier <= 1 or not antilag.allowAmbient
	if softMotion then
		_param = table.clone(_param)
		_param.reducedMotion = true
	end
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local stack = _param.stack
	local cols = _param.cols
	local cellH = _param.cellH
	local opacity = _param.opacity
	if opacity == nil then
		opacity = 1
	end
	local spacing = _param.spacing
	if spacing == nil then
		spacing = 0.5
	end
	local entries = _param.entries
	local viewport = useViewport()
	local more = AppHelpers:filterNav(entries, state, tutorialPage)
	local gridGap = 3 + math.floor(math.clamp(spacing, 0, 1) * 5)
	local height = moreDockHeight(stack, #more, cols, cellH, gridGap)
	-- These hooks back the desktop-only MORE popover, but must still run unconditionally on
	-- every render (including the mobile `stack` branch below) -- React requires the same
	-- hooks in the same order on every call, regardless of which branch's JSX gets returned.
	local moreMenuOpen, setMoreMenuOpen = React.useState(false)
	local moreTriggerRef = React.useRef()
	local popoverAnchor, setPopoverAnchor = React.useState()
	if stack then
		local _exp = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		})
		local _exp_1 = React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.65,
		})
		local _exp_2 = React.createElement("uigridlayout", {
			CellSize = UDim2.new(1 / cols, -gridGap, 0, cellH),
			CellPadding = UDim2.new(0, gridGap, 0, gridGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = cols,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#more)
		local _callback = function(entry, index)
			return React.createElement(MoreDockButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				onClick = function()
					return setPage(entry.id)
				end,
				reducedMotion = reducedMotion,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
				layoutOrder = index,
				fill = true,
			})
		end
		for _k, _v in more do
			_newValue[_k] = _callback(_v, _k - 1, more)
		end
		-- ▲ ReadonlyArray.map ▲
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = Palette.night,
			BackgroundTransparency = math.clamp(1 - opacity, 0, 0.48),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Active = false,
			ZIndex = 55,
		}, _exp, _exp_1, React.createElement("frame", {
			Size = UDim2.new(1, -10, 1, -12),
			Position = UDim2.fromOffset(5, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 56,
		}, _exp_2, _newValue))
	end
	-- Only as many entries as comfortably fit get a permanent slot on the bar; the rest live
	-- behind a "MORE" trigger opened on demand (MoreDockPopover), same idea as the mobile tab
	-- bar's overflow sheet. One slot is reserved for the trigger whenever there's overflow.
	local visibleCount = math.clamp(math.floor((viewport.width - 32) / (MORE_BTN_W + 4)), 1, 7)
	local needsMore = #more > visibleCount
	local primaryCount = if needsMore then math.max(1, visibleCount - 1) else visibleCount
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
	for _k, _v in more do
		_callback(_v, _k - 1, more)
	end
	-- ▲ ReadonlyArray.forEach ▲
	-- Keep the active page visible on the bar even if it would otherwise land in overflow --
	-- swap it in for the last primary slot (and move the displaced entry into overflow) so the
	-- current page is never hidden behind the MORE trigger.
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
		local _length = 0
		for _k, _v in overflow do
			if _callback_2(_v, _k - 1, overflow) == true then
				_length += 1
				_newValue[_length] = _v
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
	local moreTriggerActive = moreMenuOpen or activeInOverflow ~= nil
	local toggleMoreMenu = function()
		if not moreMenuOpen then
			local trigger = moreTriggerRef.current
			if trigger ~= nil then
				local origin = trigger.AbsolutePosition
				local extent = trigger.AbsoluteSize
				setPopoverAnchor({
					right = origin.X + extent.X,
					top = origin.Y + extent.Y + 6,
				})
			end
		end
		setMoreMenuOpen(function(current)
			return not current
		end)
	end
	local canvasW = math.max(#primary * (MORE_BTN_W + 4) - 4, 1)
	local dockW = math.min(viewport.width - 16, #primary * (MORE_BTN_W + 4) - 4)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	local _exp_2 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#primary)
	local _callback_3 = function(entry, index)
		return React.createElement(MoreDockButton, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				return setPage(entry.id)
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in primary do
		_newValue[_k] = _callback_3(_v, _k - 1, primary)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
		ZIndex = 55,
	}, _exp, _exp_1, React.createElement("scrollingframe", {
		Size = UDim2.new(0, dockW, 1, -8),
		Position = UDim2.new(0.5, -math.floor(dockW / 2) - (if needsMore then (MORE_BTN_W + 4) / 2 else 0), 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, canvasW, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		ScrollingEnabled = true,
		Active = true,
		Selectable = false,
		ClipsDescendants = true,
		ZIndex = 56,
	}, _exp_2, _newValue), needsMore and React.createElement("frame", {
		ref = moreTriggerRef,
		Size = UDim2.fromOffset(MORE_BTN_W, TapTarget),
		Position = UDim2.new(1, -(MORE_BTN_W + 6), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement(MoreDockButton, {
		entry = {
			id = "Overview",
			label = "MORE",
			eyebrow = "",
			icon = "Menu",
			accent = Palette.muted,
		},
		active = moreTriggerActive,
		onClick = toggleMoreMenu,
		reducedMotion = reducedMotion,
		badge = overflowBadgeTotal,
		layoutOrder = #primary,
	})), moreMenuOpen and popoverAnchor ~= nil and React.createElement(MoreDockPopover, {
		entries = overflow,
		page = page,
		setPage = function(chosen)
			setPage(chosen)
			setMoreMenuOpen(false)
		end,
		reducedMotion = reducedMotion,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		anchor = popoverAnchor,
		onClose = function()
			return setMoreMenuOpen(false)
		end,
	}))
end
local function Navigation(_param)
	local page = _param.page
	local setPage = _param.setPage
	local collapsed = _param.collapsed
	local width = _param.width
	local fixedWidth = _param.fixedWidth
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local includeSecondary = _param.includeSecondary
	if includeSecondary == nil then
		includeSecondary = false
	end
	local fromMore = _param.fromMore
	if fromMore == nil then
		fromMore = false
	end
	local activeBoost = _param.activeBoost
	local activeBoostEndsAt = _param.activeBoostEndsAt
	if activeBoostEndsAt == nil then
		activeBoostEndsAt = 0
	end
	local wallClock = _param.wallClock
	local openBoosts = _param.openBoosts
	local viewport = useViewport()
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Navigation rail motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local railNavHostRef = React.useRef(nil)
	-- Gamepad: park Selection on sidebar rail (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = railNavHostRef.current
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
			task.cancel(selectJob)
		end
	end, { page, collapsed })
	local chrome = chromeFor(viewport)
	local rowHeight = if collapsed then chrome.railCollapsedRow else chrome.railRow
	local primaryEntries = if fromMore then {} else AppHelpers:filterNav(PRIMARY_NAV, state, tutorialPage)
	local secondaryEntries = if fromMore then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) elseif includeSecondary then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) else {}
	local showSecondarySection = includeSecondary and not fromMore and #secondaryEntries > 0 and not collapsed
	local sectionH = if showSecondarySection then 22 else 0
	local railCount = if fromMore then #secondaryEntries else (#primaryEntries + #secondaryEntries)
	local canvasHeight = math.max(1, railCount) * (rowHeight + chrome.railGap) - chrome.railGap + Layout.stackGap * 2 + sectionH
	local headerHeight = if collapsed then 12 else 48
	local showBoost = activeBoost ~= nil and not chrome.mobile and page ~= "Rewards" and wallClock ~= nil and openBoosts ~= nil
	local boostHeight = if showBoost then (if collapsed then 62 else 64) else 0
	local boostReserve = if showBoost then boostHeight + SHELL_CHROME.railGutter * 2 else 0
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.5),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.68,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	local _exp_3 = not collapsed and React.createElement("frame", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2), 0, 28),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = AppHelpers:pageAccent(page),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = "Forge",
		size = 10,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(18, 0),
		sizeConstraint = UDim2.new(0.58, -18, 1, 0),
	}))
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, chrome.railGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local railChildren = {}
	local appendRail = function(entries, orderBase)
		local _callback = function(entry, index)
			table.insert(railChildren, React.createElement(RailButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				collapsed = collapsed,
				onClick = function()
					return setPage(entry.id)
				end,
				layoutOrder = orderBase + index,
				reducedMotion = reducedMotion,
				rowHeight = rowHeight,
				bodySize = chrome.bodyText,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
			}))
		end
		for _k, _v in entries do
			_callback(_v, _k - 1, entries)
		end
		return orderBase + #entries
	end
	local layoutCursor = 0
	if fromMore then
		appendRail(secondaryEntries, 0)
	else
		layoutCursor = appendRail(primaryEntries, 0)
		if showSecondarySection then
			table.insert(railChildren, React.createElement("frame", {
				key = "nav-more-section",
				Size = UDim2.new(1, 0, 0, sectionH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = layoutCursor,
			}, React.createElement(Text, {
				value = "MORE",
				size = 9,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(8, 4),
				sizeConstraint = UDim2.new(1, -12, 1, -4),
			})))
			layoutCursor += 1
		end
		if includeSecondary then
			appendRail(secondaryEntries, layoutCursor)
		end
	end
	return React.createElement("frame", {
		Name = "RailNavClaim",
		ref = railNavHostRef,
		Size = if fixedWidth ~= nil then UDim2.fromScale(1, 1) else width:map(function(value)
			return UDim2.new(0, math.max(0, value), 1, 0)
		end),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 10,
		-- FocusClaim rail nav must not clip CTA overshoot.
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("scrollingframe", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2 + 4), 1, -(headerHeight + SHELL_CHROME.railGutter + boostReserve)),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, headerHeight),
		CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
	}, _exp_4, railChildren), showBoost and React.createElement("frame", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2), 0, boostHeight),
		Position = UDim2.new(0, SHELL_CHROME.railGutter, 1, -(boostHeight + SHELL_CHROME.railGutter)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, React.createElement(ActiveBoostIcon, {
		boost = activeBoost,
		endsAt = activeBoostEndsAt,
		now = wallClock,
		open = openBoosts,
		reducedMotion = reducedMotion,
		compact = collapsed,
	})))
end

return {
	Navigation = Navigation,
	MoreDock = MoreDock,
	RailButton = RailButton,
	MoreDockButton = MoreDockButton,
	MoreDockPopover = MoreDockPopover,
}
