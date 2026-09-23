local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local clockText = require(script.Parent.Parent.format).clockText
local SECTION_LABEL_H = 28
local VIRT_BOOST_MIN = 8
local SCROLL_BAR = 4
local function boostIconKind(boostId)
	if boostId == "DomainSurge" then
		return "Domain"
	end
	if boostId == "VaultSurge" then
		return "Vault"
	end
	if boostId == "Hyperdrive" then
		return "World"
	end
	return "Reactor"
end
local HERO_H_STACK = 210
local HERO_H_WIDE = 160
local IDLE_HERO_H_STACK = 110
local IDLE_HERO_H_WIDE = 96
local CARD_H_STACK = 196
local CARD_H_WIDE = 180
local CARD_GAP = Layout.panelGap
local function ActiveBoostHero(_param)
	local boost = _param.boost
	local endsAt = _param.endsAt
	local now = _param.now
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local remaining = now:map(function(timestamp)
		return math.max(0, endsAt - timestamp)
	end)
	local fraction = now:map(function(timestamp)
		return math.clamp((endsAt - timestamp) / math.max(1, boost.Duration), 0, 1)
	end)
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = boost.Color,
		background = Palette.panelRaised,
		padding = if stack then 16 else Layout.cardPadding,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = boostIconKind(boost.Id),
		accent = boost.Color,
		size = if stack then 56 else 64,
		radius = 16,
		position = UDim2.fromOffset(0, if stack then 4 else 8),
		glow = true,
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement(Badge, {
		value = "ACTIVE",
		accent = boost.Color,
		filled = true,
		position = if stack then UDim2.fromOffset(0, 76) else UDim2.new(1, -108, 0, 0),
		size = UDim2.fromOffset(108, 26),
	}), React.createElement(Text, {
		value = boost.Name,
		size = if stack then 22 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(if stack then 0 else 76, if stack then 110 else 4),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 32),
	}), React.createElement(Text, {
		value = `{AppHelpers:boostEffectText(boost)}  ·  {boost.Description}`,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(if stack then 0 else 76, if stack then 144 else 38),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, if stack then 40 else 30),
	}), React.createElement(Meter, {
		value = fraction,
		color = boost.Color,
		reducedMotion = reducedMotion,
		shimmer = true,
		position = UDim2.fromOffset(if stack then 0 else 76, if stack then HERO_H_STACK - 42 else HERO_H_WIDE - 34),
		size = UDim2.new(1, if stack then 0 else -220, 0, 8),
	}), React.createElement(Text, {
		value = remaining:map(function(seconds)
			return clockText(seconds) .. " remaining"
		end),
		size = 11,
		color = boost.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(if stack then 0 else 76, if stack then HERO_H_STACK - 26 else HERO_H_WIDE - 18),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 16),
	}))
end
local function IdleHero(_param)
	local stack = _param.stack
	local boostKinds = _param.boostKinds
	local totalBoosts = _param.totalBoosts
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.muted,
		background = Palette.panelRaised,
		padding = if stack then 16 else Layout.cardPadding,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Boost",
		accent = Palette.muted,
		size = if stack then 40 else 48,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 12),
		spin = false,
	}), React.createElement(Text, {
		value = "No boost running",
		size = if stack then 16 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(if stack then 0 else 62, if stack then 50 else 6),
		sizeConstraint = UDim2.new(1, if stack then 0 else -300, 0, 24),
	}), React.createElement(Text, {
		value = if totalBoosts > 0 then `{totalBoosts} boost{if totalBoosts == 1 then "" else "s"} stored across {boostKinds} type{if boostKinds == 1 then "" else "s"} — activate one below.` else "Win boosts from the prize draw and timed rewards.",
		size = 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(if stack then 0 else 62, if stack then 76 else 30),
		sizeConstraint = UDim2.new(1, if stack then 0 else -300, 0, 32),
	}))
end
local function StatChip(_param)
	local label = _param.label
	local value = _param.value
	local accent = _param.accent
	local position = _param.position
	local size = _param.size
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = darken(accent, 0.74),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Text, {
		value = value,
		size = 18,
		color = lighten(accent, 0.1),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -20, 0, 24),
	}), React.createElement(Text, {
		value = label,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(10, 30),
		sizeConstraint = UDim2.new(1, -20, 0, 16),
	}))
end
local function BoostCard(_param)
	local boost = _param.boost
	local owned = _param.owned
	local canActivate = _param.canActivate
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local index = _param.index
	local stack = _param.stack
	local columns = _param.columns
	local activateHostRef = _param.activateHostRef
	local reveal = useStagger(index, reducedMotion)
	local ready = owned > 0 and canActivate
	local cardH = if stack then CARD_H_STACK else CARD_H_WIDE
	local column = index % columns
	local row = math.floor(index / columns)
	local cellW = 1 / columns
	-- Each card is (1/columns) of the row width minus its share of the total
	-- gap, and its left edge sits at (column/columns) plus the gap already
	-- "used up" by columns before it — column * CARD_GAP * (columns-1)/columns
	-- would double-count the per-card gap reservation, so it's just column *
	-- CARD_GAP / columns here, matching the width formula's own gap split.
	local position = UDim2.new(cellW * column, CARD_GAP * column / columns, 0, row * (cardH + CARD_GAP))
	local size = UDim2.new(cellW, -(CARD_GAP * (columns - 1) / columns), 0, cardH)
	-- Name/description/effect/owned used to sit at hand-placed fixed y-offsets sized for a
	-- single-line description — a real description that wraps to two lines (most of them do,
	-- e.g. "4x production for 5 minutes. All heat, no patience.") pushed past its allotted box
	-- and visually collided with the fixed-offset lines below it and the bottom-pinned Activate
	-- button. A uilistlayout lets each line's actual rendered height push the next one down
	-- instead of assuming a height that doesn't match the real text.
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = if owned > 0 then boost.Color else Palette.muted,
		background = Palette.panelRaised,
		padding = if stack then 14 else Layout.cardPadding,
		reveal = reveal,
		interactive = true,
		highlight = ready,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = boostIconKind(boost.Id),
		accent = if owned > 0 then boost.Color else Palette.panelSoft,
		size = 42,
		radius = 12,
		position = UDim2.fromOffset(0, 2),
		glow = ready,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -104, 1, -(TapTarget + 8)),
		Position = UDim2.fromOffset(52, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}), React.createElement(Text, {
		value = boost.Name,
		size = 15,
		color = if owned > 0 then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = boost.Description,
		size = 10,
		color = Palette.muted,
		wrap = true,
		fit = false,
		layoutOrder = 1,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = `{AppHelpers:boostEffectText(boost)}  ·  {clockText(boost.Duration)}`,
		size = 10,
		color = boost.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if owned > 0 then `{owned} stored` else "Not owned yet",
		size = 10,
		color = if owned > 0 then Palette.creamSoft else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		layoutOrder = 3,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})), React.createElement("frame", {
		-- FocusClaim prefers Claim-named hosts; Activate is the claim CTA on boost cards.
		Name = "BoostClaimActions",
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ref = if ready then activateHostRef else nil,
	}, React.createElement(Button, {
		text = if owned <= 0 then "None owned" elseif canActivate then "Activate" else "One at a time",
		icon = "Boost",
		onClick = function()
			return dispatch("ActivateBoost", {
				Id = boost.Id,
			})
		end,
		color = if ready then boost.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	}))))
end
local function BoostsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local columns = if stack then 1 elseif viewport.width >= 1280 then 3 else 2
	local activateHostRef = React.useRef(nil)
	local now = useWallClock(true):map(function(seconds)
		return seconds
	end)
	local boostDefinitions = config.Boosts
	local boosts = {}
	if boostDefinitions ~= nil then
		for _, definition in pairs(boostDefinitions) do
			table.insert(boosts, definition)
		end
	end
	table.sort(boosts, function(left, right)
		return left.Id < right.Id
	end)
	local _result = state.ActiveBoost
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local activeId = _condition
	local _result_1 = state.ActiveBoost
	if _result_1 ~= nil then
		_result_1 = _result_1.EndsAt
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local activeEndsAt = _condition_1
	local boostRunning = activeId ~= "" and activeEndsAt > os.time()
	local activeBoost = if boostRunning and boostDefinitions ~= nil then boostDefinitions[activeId] else nil
	local totalBoosts = 0
	local boostKinds = 0
	local firstReadyId = nil
	for _, boost in boosts do
		local _result_2 = state.BoostInventory
		if _result_2 ~= nil then
			_result_2 = _result_2[boost.Id]
		end
		local _condition_2 = _result_2
		if _condition_2 == nil then
			_condition_2 = 0
		end
		local owned = _condition_2
		totalBoosts += owned
		if owned > 0 then
			boostKinds += 1
		end
		if firstReadyId == nil and owned > 0 and not boostRunning then
			firstReadyId = boost.Id
		end
	end
	-- Gamepad: park Selection on the first Activate CTA that can fire.
	React.useEffect(function()
		if firstReadyId == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = activateHostRef.current
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
	end, { firstReadyId, boostRunning })
	local headerReveal = useStagger(0, softMotion)
	local heroH = if activeBoost ~= nil then (if stack then HERO_H_STACK else HERO_H_WIDE) else (if stack then IDLE_HERO_H_STACK else IDLE_HERO_H_WIDE)
	local statsH = if stack then 88 else 72
	local cardH = if stack then CARD_H_STACK else CARD_H_WIDE
	local rows = math.ceil(math.max(1, #boosts) / columns)
	local gridH = if #boosts > 0 then rows * cardH + (rows - 1) * CARD_GAP else 150
	local headerH = if stack then 72 else 80
	local pageGap = if stack then 12 else Layout.panelGap
	local _exp_2 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = Palette.panelRaised,
		padding = if stack then 14 else Layout.cardPadding,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "BOOSTS",
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	}), React.createElement(Text, {
		value = "Short bursts of extra power, activated one at a time.",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, -16, 0, 28),
	}))
	local _exp_3 = if activeBoost ~= nil then React.createElement(ActiveBoostHero, {
		boost = activeBoost,
		endsAt = activeEndsAt,
		now = now,
		reducedMotion = softMotion,
		stack = stack,
	}) else React.createElement(IdleHero, {
		stack = stack,
		boostKinds = boostKinds,
		totalBoosts = totalBoosts,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(StatChip, {
		label = "STORED",
		value = `{totalBoosts}`,
		accent = Palette.pink,
		position = UDim2.fromOffset(0, 0),
		size = if stack then UDim2.new(0.5, -4, 1, 0) else UDim2.fromOffset(160, statsH),
	}), React.createElement(StatChip, {
		label = "TYPES OWNED",
		value = `{boostKinds} / {#boosts}`,
		accent = Palette.cyan,
		position = if stack then UDim2.new(0.5, 4, 0, 0) else UDim2.fromOffset(168, 0),
		size = if stack then UDim2.new(0.5, -4, 1, 0) else UDim2.fromOffset(160, statsH),
	}))
	local _exp_5 = React.createElement(SectionLabel, {
		value = "ALL BOOSTS",
		color = Palette.pink,
	})
	local gridElement
	if #boosts == 0 then
		gridElement = React.createElement(EmptyState, {
			icon = "Forge",
			title = "No boosts yet",
			body = "Win them from the prize draw, then turn them on here.",
			accent = Palette.cyan,
		})
	else
		local function boostCardFor(boost, index)
			local _attributes = {
				key = boost.Id,
				boost = boost,
			}
			local _result_2 = state.BoostInventory
			if _result_2 ~= nil then
				_result_2 = _result_2[boost.Id]
			end
			local _condition_3 = _result_2
			if _condition_3 == nil then
				_condition_3 = 0
			end
			_attributes.owned = _condition_3
			_attributes.canActivate = not boostRunning
			_attributes.dispatch = dispatch
			_attributes.reducedMotion = softMotion
			_attributes.index = index
			_attributes.stack = stack
			_attributes.columns = columns
			if boost.Id == firstReadyId then
				_attributes.activateHostRef = activateHostRef
			end
			return React.createElement(BoostCard, _attributes)
		end
		-- Flatten inventory into row chunks so FlatList virtualizes long boost catalogs.
		if #boosts >= VIRT_BOOST_MIN then
			local offerRows = {}
			local index = 1
			while index <= #boosts do
				local row = {
					Id = `boost-row-{index}`,
					cells = {},
				}
				for col = 0, columns - 1 do
					local boost = boosts[index]
					if boost == nil then
						break
					end
					-- Column-local index so BoostCard parks at y=0 within the row.
					table.insert(row.cells, { boost = boost, index = col, globalIndex = index - 1 })
					index += 1
				end
				table.insert(offerRows, row)
			end
			local rowH = cardH + CARD_GAP
			gridElement = React.createElement(FlatList, {
				data = offerRows,
				itemHeight = rowH,
				overscan = 2,
				canvasTail = 8,
				Size = UDim2.fromScale(1, 1),
				scrollBarColor = Palette.pink,
				scrollBarThickness = SCROLL_BAR,
				keyExtractor = function(row)
					return row.Id
				end,
				renderItem = function(_param_1)
					local row = _param_1.item
					local cells = {}
					for cellIndex, cell in row.cells do
						-- Reveal stagger still follows global catalog order.
						cells[cellIndex] = boostCardFor(cell.boost, cell.index)
					end
					return React.createElement("frame", {
						Size = UDim2.new(1, 0, 0, cardH),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					}, cells)
				end,
			})
		else
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#boosts)
			for _k, _v in boosts do
				_newValue[_k] = boostCardFor(_v, _k - 1)
			end
			-- ▲ ReadonlyArray.map ▲
			gridElement = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, _newValue)
		end
	end
	local gridSectionH = if #boosts >= VIRT_BOOST_MIN then math.min(rows, 4) * (cardH + CARD_GAP) else gridH
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, if stack then 56 else 48),
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero-title",
				height = headerH,
				element = _exp_2,
			},
			{
				id = "active",
				height = heroH,
				element = _exp_3,
			},
			{
				id = "stats",
				height = statsH,
				element = _exp_4,
			},
			{
				id = "grid-label",
				height = SECTION_LABEL_H,
				element = _exp_5,
			},
			{
				id = "grid",
				height = gridSectionH,
				element = gridElement,
			},
		},
	})
end
return {
	BoostsView = BoostsView,
}
