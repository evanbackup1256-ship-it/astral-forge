local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local AutoGrid = require(script.Parent.Parent.scrolling).AutoGrid
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local levelCapLabel = _format.levelCapLabel
local Icon = require(script.Parent.Parent.Icon).Icon
local _motion = require(script.Parent.Parent.motion)
local usePulse = _motion.usePulse
local useRotation = _motion.useRotation
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local OrbitDot = _ui.OrbitDot
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SweptRing = _ui.SweptRing
local Text = _ui.Text
local SECTION_LABEL_H = 30
local EMPTY_ECHOES = {
	Charge = 0,
	ChargeTarget = 100,
	Ready = false,
	Resonance = 0,
	Captures = 0,
	InventoryLimit = 18,
	MaxLevel = 20,
	SlotsUnlocked = 1,
	Harmony = false,
	HarmonyBonus = 0,
	DominantPattern = "Collect",
	Pattern = {
		Collect = 0,
		Surge = 0,
		Build = 0,
		Explore = 0,
	},
	DraftId = "",
	Choices = {},
	Inventory = {},
	Equipped = { {
		Slot = 1,
		Unlocked = true,
	}, {
		Slot = 2,
		Unlocked = false,
	}, {
		Slot = 3,
		Unlocked = false,
	} },
}
local PATTERN_COPY = {
	Collect = {
		label = "BANKING",
		body = "vault collections",
		color = Palette.cyan,
		icon = "Vault",
	},
	Surge = {
		label = "SURGE",
		body = "overcharge strikes",
		color = Palette.mango,
		icon = "Overcharge",
	},
	Build = {
		label = "CRAFT",
		body = "machines and research",
		color = Palette.mint,
		icon = "Forge",
	},
	Explore = {
		label = "EXPLORE",
		body = "worlds and rebirths",
		color = Palette.violet,
		icon = "World",
	},
}
local function effectIcon(kind)
	repeat
		if kind == "Production" then
			return "Flux"
		end
		if kind == "Capacity" then
			return "Vault"
		end
		if kind == "Tap" then
			return "Overcharge"
		end
		if kind == "Critical" then
			return "Artifact"
		end
		if kind == "Automation" then
			return "Grid"
		end
		if kind == "Offline" then
			return "Timer"
		end
	until true
end
local function effectText(item)
	local label = if item.EffectKind == "Tap" then "OVERCHARGE" else string.upper(item.EffectKind)
	return `+{string.format(if item.EffectValue < 0.02 then "%.2f" else "%.1f", item.EffectValue * 100)}% {label}`
end
local function quality(item)
	if item.Strength >= 1.2 then
		return {
			label = "RESONANT",
			color = Palette.pink,
		}
	end
	if item.Strength >= 1.06 then
		return {
			label = "CLEAR",
			color = Palette.cyan,
		}
	end
	return {
		label = "FAINT",
		color = Palette.muted,
	}
end
local function EchoLoom(_param)
	local size = _param.size
	local active = _param.active
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local animate = not reducedMotion and antilag.allowAmbient and antilag.tier >= 2
	local outer = useRotation(animate, 26)
	local inner = useRotation(animate, -38)
	local drift = useRotation(animate, 9)
	local pulse = usePulse(active and animate, 1.05)
	local breathe = usePulse(animate, 0.32)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = breathe:map(function(amount)
			return UDim2.fromScale(0.92 + amount * 0.03, 0.92 + amount * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if active then Palette.mango else Palette.cyan,
		BackgroundTransparency = breathe:map(function(amount)
			return if active then 0.88 - amount * 0.06 else 0.94 - amount * 0.03
		end),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = drift,
		ZIndex = 1,
	}, React.createElement(SweptRing, {
		scale = 0.86,
		color = Palette.cyan,
		thickness = 1.5,
		spin = outer,
		sweepWidth = 0.3,
	})), React.createElement(SweptRing, {
		scale = 0.62,
		color = Palette.violet,
		thickness = 1.5,
		spin = inner,
		sweepWidth = 0.34,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(0.86, 0.86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = outer,
		ZIndex = 3,
	}, React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 0,
		size = 7,
		color = Palette.mango,
		glow = active,
	}), React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 120,
		size = 5,
		color = Palette.pink,
		glow = false,
	}), React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 240,
		size = 5,
		color = Palette.mango,
		glow = false,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = inner,
		ZIndex = 3,
	}, React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 0,
		size = 6,
		color = Palette.violet,
		glow = false,
	}), React.createElement(OrbitDot, {
		radiusScale = 0.5,
		angleDeg = 180,
		size = 6,
		color = Palette.cyan,
		glow = false,
	})), React.createElement("frame", {
		Size = pulse:map(function(value)
			return UDim2.fromOffset(math.floor(size * (0.42 + value * 0.035)), math.floor(size * (0.42 + value * 0.035)))
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(Palette.cyan, 0.62),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.violet, 0.05), darken(Palette.cyan, 0.35)),
		Rotation = 45,
	}), React.createElement("uistroke", {
		Color = if active then Palette.mango else Palette.cyan,
		Thickness = 2,
		Transparency = pulse:map(function(value)
			return 0.22 + (1 - value) * 0.34
		end),
	}), React.createElement(Icon, {
		kind = "Wave",
		color = Palette.cream,
		accent = if active then Palette.mango else Palette.cyan,
		size = math.floor(size * 0.31),
		spin = false,
		reducedMotion = reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})))
end
local function PatternCell(_param)
	local id = _param.id
	local value = _param.value
	local total = _param.total
	local dominant = _param.dominant
	local index = _param.index
	local reducedMotion = _param.reducedMotion
	local copy = PATTERN_COPY[id]
	local fill = if total > 0 then value / total else 0
	local surface = darken(copy.color, 0.93)
	local reveal = useStagger(index, reducedMotion, 0.05, 0.24)
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = copy.color,
		background = surface,
		padding = 11,
		highlight = dominant,
		reveal = reveal,
		reducedMotion = reducedMotion,
	}, React.createElement(Icon, {
		kind = copy.icon,
		color = ensureContrast(surface, Palette.creamSoft),
		accent = copy.color,
		size = 25,
		spin = false,
		position = UDim2.fromOffset(0, 1),
	}), React.createElement(Text, {
		value = copy.label,
		size = 10,
		color = ensureContrast(surface, copy.color),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(34, 0),
		sizeConstraint = UDim2.new(1, -42, 0, 16),
	}), React.createElement(Text, {
		value = copy.body,
		size = 9,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		position = UDim2.fromOffset(34, 17),
		sizeConstraint = UDim2.new(1, -42, 0, 14),
	}), React.createElement(Meter, {
		value = fill,
		color = copy.color,
		position = UDim2.new(0, 0, 1, -9),
		size = UDim2.new(1, 0, 0, 6),
		reducedMotion = reducedMotion,
		shimmer = dominant,
	}))
end
local function ChoiceCard(_param)
	local item = _param.item
	local index = _param.index
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local tier = quality(item)
	local reveal = useStagger(index, reducedMotion, 0.06, 0.3)
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = item.Color,
		background = darken(item.Color, 0.91),
		padding = 14,
		highlight = true,
		interactive = true,
		reveal = reveal,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(Icon, {
		kind = effectIcon(item.EffectKind),
		color = Palette.cream,
		accent = item.Color,
		size = 38,
		spin = false,
		position = UDim2.fromOffset(0, 0),
	}), React.createElement(Badge, {
		value = tier.label,
		accent = tier.color,
		filled = true,
		position = UDim2.new(1, -92, 0, 0),
		size = UDim2.fromOffset(92, 25),
	}), React.createElement(Text, {
		value = item.Name,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(0, 49),
		sizeConstraint = UDim2.new(1, 0, 0, 27),
	}), React.createElement(Text, {
		value = item.Description,
		size = 10,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 78),
		sizeConstraint = UDim2.new(1, 0, 0, 38),
	}), React.createElement(Text, {
		value = effectText(item),
		size = 11,
		color = item.Color,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.new(0, 0, 1, -76),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Button, {
		text = "KEEP THIS ECHO",
		icon = "Check",
		onClick = function()
			return dispatch("ClaimEcho", {
				ChoiceId = item.Uid,
			})
		end,
		color = item.Color,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		highlight = true,
	}))
end
local function SlotCard(_param)
	local slot = _param.slot
	local reducedMotion = _param.reducedMotion
	local item = slot.Echo
	local _result
	if not slot.Unlocked then
		_result = Palette.lineSoft
	else
		local _result_1 = item
		if _result_1 ~= nil then
			_result_1 = _result_1.Color
		end
		local _condition = _result_1
		if _condition == nil then
			_condition = Palette.violet
		end
		_result = _condition
	end
	local accent = _result
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = if item then darken(accent, 0.93) else Palette.panel,
		padding = 12,
		reducedMotion = reducedMotion,
	}, React.createElement(Badge, {
		value = `SLOT {slot.Slot}`,
		accent = accent,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.fromOffset(70, 23),
	}), if not slot.Unlocked then React.createElement(React.Fragment, nil, React.createElement(Icon, {
		kind = "Lock",
		color = Palette.muted,
		accent = Palette.lineSoft,
		size = 30,
		spin = false,
		position = UDim2.new(1, -34, 0, 0),
	}), React.createElement(Text, {
		value = "LOCKED SLOT",
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 38),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	})) elseif item then React.createElement(React.Fragment, nil, React.createElement(Icon, {
		kind = effectIcon(item.EffectKind),
		color = Palette.cream,
		accent = item.Color,
		size = 30,
		spin = false,
		position = UDim2.new(1, -34, 0, 0),
	}), React.createElement(Text, {
		value = item.Name,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 23),
	}), React.createElement(Text, {
		value = `LV {item.Level}  ·  {effectText(item)}`,
		size = 10,
		color = item.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, 17),
	})) else React.createElement(React.Fragment, nil, React.createElement(Icon, {
		kind = "Wave",
		color = Palette.muted,
		accent = Palette.violet,
		size = 30,
		spin = false,
		position = UDim2.new(1, -34, 0, 0),
	}), React.createElement(Text, {
		value = "EMPTY SLOT",
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 38),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	})))
end
local function InventoryCard(_param)
	local item = _param.item
	local echoes = _param.echoes
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local armed = _param.armed
	local arm = _param.arm
	local index = _param.index
	local _exp = echoes.Equipped
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(slot)
		local _result = slot.Echo
		if _result ~= nil then
			_result = _result.Uid
		end
		return _result == item.Uid
	end
	local _result
	for _i, _v in _exp do
		if _callback(_v, _i - 1, _exp) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _current = _result
	if _current ~= nil then
		_current = _current.Slot
	end
	local current = _current
	local _exp_1 = echoes.Equipped
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(slot)
		return slot.Unlocked and slot.Echo == nil
	end
	local _result_1
	for _i, _v in _exp_1 do
		if _callback_1(_v, _i - 1, _exp_1) == true then
			_result_1 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _open = _result_1
	if _open ~= nil then
		_open = _open.Slot
	end
	local open = _open
	local _result_2
	if current ~= nil then
		_result_2 = current % math.max(1, echoes.SlotsUnlocked) + 1
	else
		local _condition = open
		if _condition == nil then
			_condition = 1
		end
		_result_2 = _condition
	end
	local nextSlot = _result_2
	local maxed = item.Level >= echoes.MaxLevel
	local canUpgrade = not maxed and state.Stardust >= item.UpgradeCost
	local reveal = useStagger(index, reducedMotion, 0.04, 0.22)
	local surface = Palette.panel
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = item.Color,
		background = surface,
		padding = 13,
		interactive = true,
		reducedMotion = reducedMotion,
		reveal = reveal,
		clips = true,
	}, React.createElement(Icon, {
		kind = effectIcon(item.EffectKind),
		color = ensureContrast(surface, Palette.cream),
		accent = item.Color,
		size = 38,
		spin = false,
		position = UDim2.fromOffset(0, 0),
	}), React.createElement(Text, {
		value = item.Name,
		size = 16,
		color = ensureContrast(surface, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(48, 0),
		sizeConstraint = UDim2.new(1, -56, 0, 24),
	}), React.createElement(Text, {
		value = `{item.Affinity} · {quality(item).label} · LV {item.Level}/{levelCapLabel(echoes.MaxLevel)}`,
		size = 9,
		color = ensureContrast(surface, item.Color),
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(48, 25),
		sizeConstraint = UDim2.new(1, -56, 0, 15),
	}), React.createElement(Text, {
		value = item.Description,
		size = 10,
		color = ensureContrast(surface, Palette.creamSoft),
		wrap = true,
		position = UDim2.fromOffset(0, 51),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = effectText(item),
		size = 11,
		color = ensureContrast(surface, item.Color),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 82),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Button, {
		text = if current ~= nil and echoes.SlotsUnlocked == 1 then "LINKED" else `LINK SLOT {nextSlot}`,
		icon = "Wave",
		onClick = function()
			return dispatch("EquipEcho", {
				Uid = item.Uid,
				Slot = nextSlot,
			})
		end,
		color = if current ~= nil and echoes.SlotsUnlocked == 1 then Palette.panelSoft else item.Color,
		textColor = Palette.cream,
		disabled = current ~= nil and echoes.SlotsUnlocked == 1,
		size = UDim2.new(0.48, -4, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if maxed then "MAX" else `{compactNumber(item.UpgradeCost)} DUST`,
		icon = "Research",
		onClick = function()
			return dispatch("UpgradeEcho", {
				Uid = item.Uid,
			})
		end,
		color = if canUpgrade then Palette.violet else Palette.panelSoft,
		textColor = Palette.cream,
		disabled = not canUpgrade,
		size = UDim2.new(0.32, -4, 0, TapTarget),
		position = UDim2.new(0.48, 4, 1, -TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if armed then "SURE?" else "BREAK",
		icon = "Close",
		onClick = function()
			return if armed then dispatch("DismantleEcho", {
				Uid = item.Uid,
			}) else arm()
		end,
		color = if armed then Palette.coral else Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(0.2, -4, 0, TapTarget),
		position = UDim2.new(0.8, 4, 1, -TapTarget),
		reducedMotion = reducedMotion,
	}))
end
local function EchoForgeView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local echoes = state.ForgeEchoes or EMPTY_ECHOES
	local armedUid, setArmedUid = React.useState()
	React.useEffect(function()
		return setArmedUid(nil)
	end, { #echoes.Inventory })
	local patternTotal = echoes.Pattern.Collect + echoes.Pattern.Surge + echoes.Pattern.Build + echoes.Pattern.Explore
	local sectionGap = if stack then chrome.panelGap else Layout.panelGap
	local heroH = if stack then 264 else 278
	local choiceRows = if #echoes.Choices > 0 then (if stack then #echoes.Choices else 1) else 0
	local choiceGridH = choiceRows * 214 + math.max(0, choiceRows - 1) * sectionGap
	local choiceSectionH = if choiceRows > 0 then 30 + choiceGridH else 0
	local slotRows = if stack then #echoes.Equipped else 1
	local slotGridH = slotRows * 116 + math.max(0, slotRows - 1) * sectionGap
	local slotSectionH = 30 + slotGridH
	local patternRows = if stack then 2 else 1
	local patternSectionH = 30 + patternRows * 88 + math.max(0, patternRows - 1) * sectionGap
	local inventoryRows = math.max(1, if stack then #echoes.Inventory else math.ceil(#echoes.Inventory / 2))
	local inventoryGridH = inventoryRows * 196 + math.max(0, inventoryRows - 1) * sectionGap
	local inventorySectionH = 30 + inventoryGridH
	local dominant = PATTERN_COPY[echoes.DominantPattern]
	local chargeFill = echoes.Charge / math.max(1, echoes.ChargeTarget)
	local chargeAccent = if echoes.Ready or #echoes.Choices > 0 then Palette.mango else dominant.color
	local heroSurface = darken(Palette.cyan, 0.95)
	local chargeLabel = ensureContrast(heroSurface, chargeAccent)
	local chargeCopy = if #echoes.Choices > 0 then "CHOOSE ONE ECHO BELOW" elseif echoes.Ready then `READY  ·  {dominant.label} STYLE  ·  {compactNumber(echoes.Charge)} / {compactNumber(echoes.ChargeTarget)}` else `{dominant.label} STYLE  ·  {compactNumber(echoes.Charge)} / {compactNumber(echoes.ChargeTarget)}`
	local chargePulse = usePulse((echoes.Ready or #echoes.Choices > 0) and not reducedMotion, 1.7)
	local loomSize = if stack then 72 else 128
	local heroPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = chargeAccent,
		background = heroSurface,
		padding = if stack then 15 else Layout.cardPadding,
		highlight = echoes.Ready,
		reducedMotion = reducedMotion,
		clips = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(loomSize, loomSize),
		Position = if stack then UDim2.new(0.5, -loomSize / 2, 0, 4) else UDim2.fromOffset(4, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(EchoLoom, {
		size = loomSize,
		active = echoes.Ready or #echoes.Choices > 0,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 154) else UDim2.new(1, -(loomSize + 34), 0, 202),
		Position = if stack then UDim2.fromOffset(0, loomSize + 8) else UDim2.fromOffset(loomSize + 24, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = "HOW YOU PLAY",
		size = 10,
		color = ensureContrast(heroSurface, Palette.cyan),
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -110, 0, 16),
	}), React.createElement(Badge, {
		value = `{compactNumber(echoes.Resonance)} RESONANCE`,
		accent = Palette.violet,
		position = UDim2.new(1, -116, 0, 0),
		size = UDim2.fromOffset(116, 22),
	}), React.createElement(Text, {
		value = "Forge Echoes",
		size = if stack then 20 else 30,
		color = ensureContrast(heroSurface, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = "Play normally. The forge records what you do, then shapes three permanent echoes around your habits.",
		size = 11,
		color = ensureContrast(heroSurface, Palette.creamSoft),
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 28 else 38),
	}), React.createElement(Text, {
		value = chargeCopy,
		size = 10,
		color = chargeLabel,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, if stack then 80 else 102),
		sizeConstraint = UDim2.new(1, 0, 0, 15),
		transparency = if echoes.Ready then chargePulse:map(function(amount)
			return 0.04 + (1 - amount) * 0.16
		end) else 0,
	}), React.createElement(Meter, {
		value = chargeFill,
		color = chargeAccent,
		position = UDim2.fromOffset(0, if stack then 98 else 120),
		size = UDim2.new(1, 0, 0, 7),
		reducedMotion = reducedMotion,
		shimmer = echoes.Ready,
	}), React.createElement(Button, {
		text = if #echoes.Choices > 0 then "CHOOSE AN ECHO BELOW" elseif echoes.Ready then "CAPTURE THIS PATTERN" else "KEEP FORGING",
		icon = "Wave",
		onClick = function()
			return dispatch("CaptureEcho")
		end,
		color = if echoes.Ready and #echoes.Choices == 0 then Palette.mango else Palette.panelSoft,
		textColor = if echoes.Ready and #echoes.Choices == 0 then Palette.ink else ensureContrast(Palette.panelSoft, Palette.muted),
		disabled = not echoes.Ready or #echoes.Choices > 0,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		highlight = echoes.Ready,
	})))
	local sections = {
		{
			id = "hero",
			height = heroH,
			element = heroPanel,
		},
	}
	if choiceRows > 0 then
		local _exp_5 = echoes.Choices
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_5)
		local _callback = function(item, index)
			return React.createElement(ChoiceCard, {
				key = item.Uid,
				item = item,
				index = index,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		for _k, _v in _exp_5 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_5)
		end
		-- ▲ ReadonlyArray.map ▲
		table.insert(sections, {
			id = "choices",
			height = choiceSectionH,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(SectionLabel, {
				value = "PICK ONE ECHO",
				color = Palette.mango,
			}), React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, choiceGridH),
				Position = UDim2.fromOffset(0, SECTION_LABEL_H),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(AutoGrid, {
				columns = if stack then 1 else 3,
				cellHeight = 214,
				gap = sectionGap,
			}), _newValue)),
		})
	end
	local _exp_5 = echoes.Equipped
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_5)
	local _callback = function(slot)
		return React.createElement(SlotCard, {
			key = `slot-{slot.Slot}`,
			slot = slot,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_5 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_5)
	end
	-- ▲ ReadonlyArray.map ▲
	table.insert(sections, {
		id = "slots",
		height = slotSectionH,
		element = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(SectionLabel, {
			value = if echoes.Harmony then `LINKED ECHOES · HARMONY +{math.floor(echoes.HarmonyBonus * 100 + 0.5)}%` else `LINKED ECHOES · {echoes.SlotsUnlocked}/3 OPEN`,
			color = if echoes.Harmony then Palette.mint else Palette.violet,
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, slotGridH),
			Position = UDim2.fromOffset(0, SECTION_LABEL_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(AutoGrid, {
			columns = if stack then 1 else 3,
			cellHeight = 116,
			gap = sectionGap,
		}), _newValue)),
	})
	local _exp_9 = ({ "Collect", "Surge", "Build", "Explore" })
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#_exp_9)
	local _callback_1 = function(id, index)
		return React.createElement(PatternCell, {
			key = id,
			id = id,
			value = echoes.Pattern[id],
			total = patternTotal,
			dominant = id == echoes.DominantPattern,
			index = index,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_9 do
		_newValue_1[_k] = _callback_1(_v, _k - 1, _exp_9)
	end
	-- ▲ ReadonlyArray.map ▲
	table.insert(sections, {
		id = "pattern",
		height = patternSectionH,
		element = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(SectionLabel, {
			value = "CURRENT PROGRESS",
			color = dominant.color,
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, patternSectionH - SECTION_LABEL_H),
			Position = UDim2.fromOffset(0, SECTION_LABEL_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(AutoGrid, {
			columns = if stack then 2 else 4,
			cellHeight = 88,
			gap = sectionGap,
		}), _newValue_1)),
	})
	local inventoryBody
	if #echoes.Inventory > 0 then
		local _exp_13 = echoes.Inventory
		-- ▼ ReadonlyArray.map ▼
		local _newValue_2 = table.create(#_exp_13)
		local _callback_2 = function(item, index)
			return React.createElement(InventoryCard, {
				key = item.Uid,
				item = item,
				echoes = echoes,
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				armed = armedUid == item.Uid,
				arm = function()
					return setArmedUid(item.Uid)
				end,
				index = index,
			})
		end
		for _k, _v in _exp_13 do
			_newValue_2[_k] = _callback_2(_v, _k - 1, _exp_13)
		end
		-- ▲ ReadonlyArray.map ▲
		inventoryBody = _newValue_2
	else
		inventoryBody = React.createElement(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.lineSoft,
			padding = 16,
		}, React.createElement(Icon, {
			kind = "Wave",
			color = Palette.muted,
			accent = Palette.cyan,
			size = 34,
			spin = false,
			position = UDim2.fromOffset(0, 0),
		}), React.createElement(Text, {
			value = "NO ECHOES YET",
			size = 14,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(46, 0),
			sizeConstraint = UDim2.new(1, -54, 0, 22),
		}), React.createElement(Text, {
			value = "Keep playing to shape your first echo.",
			size = 11,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(46, 26),
			sizeConstraint = UDim2.new(1, -54, 0, 38),
		}))
	end
	table.insert(sections, {
		id = "inventory",
		height = inventorySectionH,
		element = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(SectionLabel, {
			value = `ECHO VAULT · {#echoes.Inventory}/{echoes.InventoryLimit}`,
			color = Palette.cyan,
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, inventoryGridH),
			Position = UDim2.fromOffset(0, SECTION_LABEL_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(AutoGrid, {
			columns = if stack then 1 else 2,
			cellHeight = 196,
			gap = sectionGap,
		}), inventoryBody)),
	})
	return React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, if stack then 72 else 56),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = sections,
	})
end
return {
	EchoForgeView = EchoForgeView,
}
