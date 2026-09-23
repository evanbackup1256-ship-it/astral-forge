local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.audio).Audio
local Icon = require(script.Parent.Icon).Icon
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useButtonChrome = _ui.useButtonChrome
local NODES = { {
	id = "FluxVein",
	name = "Flux Vein",
	body = "+12% production",
	lore = "A live current under the floor.",
	cost = 2,
	requires = {},
	icon = "Flux",
	accent = Palette.cyan,
	x = 0.16,
	y = 0.2,
}, {
	id = "VaultLattice",
	name = "Vault Lattice",
	body = "+18% vault size",
	lore = "More hours banked before overflow.",
	cost = 2,
	requires = {},
	icon = "Vault",
	accent = Palette.mango,
	x = 0.39,
	y = 0.12,
}, {
	id = "EmberCore",
	name = "Ember Core",
	body = "+15% overcharge",
	lore = "Heat that answers a tap.",
	cost = 2,
	requires = {},
	icon = "Overcharge",
	accent = Palette.coral,
	x = 0.61,
	y = 0.12,
}, {
	id = "NightHarvest",
	name = "Night Harvest",
	body = "+8% offline",
	lore = "The forge works the dark shift.",
	cost = 2,
	requires = {},
	icon = "Timer",
	accent = Palette.violet,
	x = 0.84,
	y = 0.2,
}, {
	id = "StarWell",
	name = "Star Well",
	body = "+10% production",
	lore = "Draws from the first bound vein.",
	cost = 3,
	requires = { "FluxVein" },
	icon = "Forge",
	accent = Palette.cyan,
	x = 0.22,
	y = 0.46,
}, {
	id = "PrismGate",
	name = "Prism Gate",
	body = "+6% crate luck",
	lore = "Splits chance into cleaner odds.",
	cost = 3,
	requires = { "VaultLattice" },
	icon = "Crate",
	accent = Palette.pink,
	x = 0.4,
	y = 0.4,
}, {
	id = "EchoChamber",
	name = "Echo Chamber",
	body = "Echoes charge faster",
	lore = "Repeats a strike until it lands.",
	cost = 3,
	requires = { "EmberCore" },
	icon = "Wave",
	accent = Palette.mint,
	x = 0.6,
	y = 0.4,
}, {
	id = "HorizonKey",
	name = "Horizon Key",
	body = "Cheaper worlds",
	lore = "Unlocks the next gate for less.",
	cost = 3,
	requires = { "NightHarvest" },
	icon = "World",
	accent = Palette.violet,
	x = 0.78,
	y = 0.46,
}, {
	id = "RealityAnchor",
	name = "Reality Anchor",
	body = "+25% rebirth cores",
	lore = "Keeps more of what a reset forges.",
	cost = 4,
	requires = { "StarWell" },
	icon = "Core",
	accent = Palette.mango,
	x = 0.28,
	y = 0.7,
}, {
	id = "DomainPulse",
	name = "Domain Pulse",
	body = "+1 essence / expand",
	lore = "Each expansion leaves more residue.",
	cost = 4,
	requires = { "PrismGate" },
	icon = "Domain",
	accent = Palette.pink,
	x = 0.46,
	y = 0.66,
}, {
	id = "ContinuumBind",
	name = "Continuum Bind",
	body = "Cheaper continuum",
	lore = "Ranks cost less to hold.",
	cost = 4,
	requires = { "EchoChamber" },
	icon = "Rebirth",
	accent = Palette.cyan,
	x = 0.64,
	y = 0.7,
}, {
	id = "OverchargeChannel",
	name = "Overcharge Channel",
	body = "+20% crit chance",
	lore = "Two anchors share one strike.",
	cost = 5,
	requires = { "RealityAnchor", "DomainPulse" },
	icon = "Jackpot",
	accent = Palette.coral,
	x = 0.5,
	y = 0.9,
}, {
	id = "TideLock",
	name = "Tide Lock",
	body = "Cheaper world hops",
	lore = "Keeps the next gate from drifting.",
	cost = 4,
	requires = { "HorizonKey" },
	icon = "World",
	accent = Palette.violet,
	x = 0.88,
	y = 0.68,
}, {
	id = "VaultHeartNode",
	name = "Vault Heart",
	body = "+14% vault size",
	lore = "A second lock on the same bank.",
	cost = 4,
	requires = { "PrismGate" },
	icon = "Vault",
	accent = Palette.mango,
	x = 0.32,
	y = 0.58,
}, {
	id = "EmberWell",
	name = "Ember Well",
	body = "+12% overcharge",
	lore = "Stores heat between taps.",
	cost = 4,
	requires = { "EchoChamber" },
	icon = "Overcharge",
	accent = Palette.coral,
	x = 0.72,
	y = 0.58,
}, {
	id = "ApexLattice",
	name = "Apex Lattice",
	body = "+8% all production",
	lore = "The last bind that holds the rest.",
	cost = 6,
	requires = { "OverchargeChannel", "ContinuumBind" },
	icon = "Domain",
	accent = Palette.pink,
	x = 0.68,
	y = 0.92,
} }
local VEINS = { {
	from = "FluxVein",
	to = "StarWell",
}, {
	from = "StarWell",
	to = "RealityAnchor",
}, {
	from = "RealityAnchor",
	to = "OverchargeChannel",
}, {
	from = "VaultLattice",
	to = "PrismGate",
}, {
	from = "PrismGate",
	to = "DomainPulse",
}, {
	from = "PrismGate",
	to = "VaultHeartNode",
}, {
	from = "DomainPulse",
	to = "OverchargeChannel",
}, {
	from = "EmberCore",
	to = "EchoChamber",
}, {
	from = "EchoChamber",
	to = "ContinuumBind",
}, {
	from = "EchoChamber",
	to = "EmberWell",
}, {
	from = "NightHarvest",
	to = "HorizonKey",
}, {
	from = "HorizonKey",
	to = "TideLock",
}, {
	from = "OverchargeChannel",
	to = "ApexLattice",
}, {
	from = "ContinuumBind",
	to = "ApexLattice",
} }
local function nodeById(id)
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(node)
		return node.id == id
	end
	local _result
	for _i, _v in NODES do
		if _callback(_v, _i - 1, NODES) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = NODES[1]
	end
	return _condition
end
local function LatticeField(_param)
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local drift = useClock(not reducedMotion, 0.18, 1)
	local motes = { 0, 1, 2, 3, 4, 5 }
	local _exp = { 0, 1, 2, 3, 4 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp)
	local _callback = function(index)
		return React.createElement("frame", {
			key = `grid-{index}`,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, (index + 1) / 6, 0),
			BackgroundColor3 = Palette.lineSoft,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		})
	end
	for _k, _v in _exp do
		_newValue[_k] = _callback(_v, _k - 1, _exp)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_1 = { 0, 1, 2, 3, 4, 5 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#_exp_1)
	local _callback_1 = function(index)
		return React.createElement("frame", {
			key = `col-{index}`,
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new((index + 1) / 7, 0, 0, 0),
			BackgroundColor3 = Palette.lineSoft,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
		})
	end
	for _k, _v in _exp_1 do
		_newValue_1[_k] = _callback_1(_v, _k - 1, _exp_1)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#motes)
	local _callback_2 = function(index)
		local seed = 0.07 + index * 0.083
		return React.createElement("frame", {
			key = `mote-{index}`,
			Size = UDim2.fromOffset(if index % 3 == 0 then 4 else 2, if index % 3 == 0 then 4 else 2),
			Position = drift:map(function(phase)
				local t = (phase + seed) % 1
				return UDim2.fromScale((seed * 9) % 1, (t * 0.9 + ((index * 17) % 10) / 40) % 1)
			end),
			BackgroundColor3 = if index % 2 == 0 then accent else Palette.cream,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in motes do
		_newValue_2[_k] = _callback_2(_v, _k - 1, motes)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _newValue, _newValue_1, _newValue_2)
end
local function BranchVein(_param)
	local from = _param.from
	local to = _param.to
	local live = _param.live
	local selected = _param.selected
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(live and selected and not reducedMotion, 0.9, 1)
	local accent = if live then from.accent else Palette.lineSoft
	local marks = if selected then { 0.28, 0.5, 0.72 } else { 0.5 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#marks)
	local _callback = function(alpha)
		return React.createElement("frame", {
			key = `seg-{alpha}`,
			Size = UDim2.fromOffset(if selected then 7 else 5, if selected then 7 else 5),
			Position = UDim2.fromScale(from.x + (to.x - from.x) * alpha, from.y + (to.y - from.y) * alpha),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = if live then 0.18 else 0.68,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in marks do
		_newValue[_k] = _callback(_v, _k - 1, marks)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, _newValue, live and selected and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = pulse:map(function(phase)
			return UDim2.fromScale(from.x + (to.x - from.x) * phase, from.y + (to.y - from.y) * phase)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function NodeOrnament(_param)
	local node = _param.node
	local owned = _param.owned
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local beat = usePulse((owned or ready) and not reducedMotion, if owned then 1.4 else 2.1)
	if not owned and not ready then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if owned then 9 else 7, if owned then 9 else 7),
		Position = UDim2.new(1, -4, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = beat:map(function(amount)
			return 0.08 + (1 - amount) * 0.35
		end),
		BorderSizePixel = 0,
		ZIndex = 44,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
end
local function HexNode(_param)
	local node = _param.node
	local owned = _param.owned
	local ready = _param.ready
	local selected = _param.selected
	local bound = _param.bound
	local reducedMotion = _param.reducedMotion
	local onSelect = _param.onSelect
	local index = _param.index
	local nodeSize = _param.nodeSize
	local padX = _param.padX
	local padY = _param.padY
	local chrome = useButtonChrome(function()
		Audio:play(if owned then "tick" elseif ready then "domainCharge" else "locked")
		onSelect()
	end, reducedMotion, false, false, true)
	local reveal = useStagger(index, reducedMotion, 0.02, 0.2)
	local pulse = usePulse(ready and not owned and not reducedMotion, 1.7)
	local ownedGlow = usePulse(owned and not reducedMotion, 1.15)
	local lift = useFlipperSpring(if selected then 1 elseif ready then 0.55 elseif owned then 0.25 else 0, reducedMotion, 620, 34)
	local bindPop = useFlash(if bound then 1 else 0, reducedMotion, 0.55)
	local size = if selected then nodeSize + 8 else nodeSize
	local hitSize = math.max(size, TapTarget)
	local fill = if owned then darken(node.accent, 0.28) elseif ready then darken(node.accent, 0.62) else Palette.panel
	local x = padX + node.x * (1 - padX * 2)
	local y = padY + node.y * (1 - padY * 2)
	return React.createElement("imagebutton", {
		Size = UDim2.fromOffset(hitSize, hitSize),
		Position = React.joinBindings({ lift, bindPop }):map(function(values)
			local _exp = UDim2.fromScale(x, y)
			local _arg0 = UDim2.fromOffset(0, math.round(-values[1] * 10 - values[2] * 6))
			return _exp + _arg0
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = 40,
		Event = chrome.events,
	}, React.createElement(ScaleFromCenter, {
		scale = React.joinBindings({ reveal, bindPop, chrome.touchScale }):map(function(values)
			return (0.62 + values[1] * 0.38) * (1 + values[2] * 0.28) * values[3]
		end),
		zIndex = 40,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 40,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(fill, 0.22), darken(fill, 0.12)),
		Rotation = 90,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 41,
		radius = 12,
	}), ready and not owned and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = pulse:map(function(amount)
			return 0.78 + (1 - amount) * 0.14
		end),
		BorderSizePixel = 0,
		ZIndex = 41,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})), owned and React.createElement("frame", {
		Size = UDim2.new(0.48, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, -5),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = node.accent,
		BackgroundTransparency = ownedGlow:map(function(amount)
			return 0.08 + (1 - amount) * 0.4
		end),
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), selected and React.createElement("frame", {
		Size = UDim2.new(0.58, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), bound and React.createElement("frame", {
		Size = bindPop:map(function(amount)
			return UDim2.fromScale(1 + amount * 1.4, 1 + amount * 1.4)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 45,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = node.accent,
		Thickness = bindPop:map(function(amount)
			return 3 - amount * 2
		end),
		Transparency = bindPop:map(function(amount)
			return 0.08 + amount * 0.9
		end),
	}))), React.createElement(NodeOrnament, {
		node = node,
		owned = owned,
		ready = ready,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(math.floor(size * 0.58), math.floor(size * 0.58)),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 43,
	}, React.createElement(Icon, {
		kind = node.icon,
		color = if owned or ready or selected then Palette.cream else Palette.muted,
		accent = node.accent,
		size = math.floor(size * 0.42),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = (selected or bound) and not reducedMotion,
		reducedMotion = reducedMotion,
	}))))
end
local function DomainSkillTree(_param)
	local domain = _param.domain
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local selectedId, setSelectedId = React.useState()
	local busy, setBusy = React.useState(false)
	local binds, setBinds = React.useState(0)
	local burstId, setBurstId = React.useState()
	local pan, setPan = React.useState({
		x = 0,
		y = 0,
	})
	local drag = React.useRef()
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion, 0.28)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local flash = useFlash(binds, reducedMotion, 0.7)
	local headerIn = useStagger(1, reducedMotion, 0.04, 0.28)
	local footerIn = useStagger(2, reducedMotion, 0.05, 0.3)
	local nodeSize = if stack then (if viewport.height < 640 then 40 else 48) elseif viewport.width < 1280 then 54 else 60
	local padX = if stack then 0.08 else 0.04
	local padY = if stack then 0.08 else 0.05
	local side = chrome.sideSafe + (if stack then 10 else 0)
	local panelW = if stack then math.max(300, math.min(viewport.width - math.max(20, side * 2), math.floor(viewport.width * 0.96))) else math.min(math.max(760, math.floor(viewport.width * 0.78)), viewport.width - 48)
	local headerH = if stack then 62 else 58
	local footerH = if stack then 126 else 64
	local treeGap = 8
	local panelH = if stack then math.min(viewport.height - math.max(28, chrome.bottomSafe + viewport.topInset + 20), math.max(420, math.floor(viewport.height * 0.86))) else math.min(viewport.height - 56, math.max(560, math.floor(viewport.height * 0.8)))
	local liveFx = not reducedMotion and not leaving
	local close = function()
		if leaving then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end
	local cardTravel = if stack then 22 else 18
	local cardPosition = motion:map(function(amount)
		local _exp = UDim2.fromScale(0.5, 0.5)
		local _arg0 = UDim2.fromOffset(0, math.round((1 - amount) * cardTravel))
		return _exp + _arg0
	end)
	local scrimTransparency = motion:map(function(amount)
		return 1 - amount * 0.52
	end)
	local cardScale = motion:map(function(amount)
		return 0.9 + amount * 0.1
	end)
	local nodes = domain.Nodes or {}
	local nodeOwned = function(id)
		return nodes[id] == true
	end
	local _condition = domain.SkillPoints
	if _condition == nil then
		_condition = 0
	end
	local points = _condition
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(node)
		return node.id == selectedId
	end
	local _result
	for _i, _v in NODES do
		if _callback(_v, _i - 1, NODES) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = NODES[1]
	end
	local selected = _condition_1
	local owned = selected ~= nil and nodeOwned(selected.id)
	local _condition_2 = selected ~= nil
	if _condition_2 then
		local _exp = selected.requires
		-- ▼ ReadonlyArray.every ▼
		local _result_1 = true
		local _callback_1 = function(id)
			return nodeOwned(id)
		end
		for _k, _v in _exp do
			if not _callback_1(_v, _k - 1, _exp) then
				_result_1 = false
				break
			end
		end
		-- ▲ ReadonlyArray.every ▲
		_condition_2 = _result_1
	end
	local prereqs = _condition_2
	local canBuy = selected ~= nil and not owned and prereqs and points >= selected.cost and not busy
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_1 = function(total, node)
		return total + (if nodeOwned(node.id) then 1 else 0)
	end
	for _i = 1, #NODES do
		_result_1 = _callback_1(_result_1, NODES[_i], _i - 1, NODES)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local boundCount = _result_1
	React.useEffect(function()
		Audio:play("domainCrack")
	end, {})
	React.useEffect(function()
		local moved = UserInputService.InputChanged:Connect(function(input)
			local hold = drag.current
			if hold == nil then
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			setPan({
				x = math.clamp(hold.ox + input.Position.X - hold.x, -90, 90),
				y = math.clamp(hold.oy + input.Position.Y - hold.y, -70, 70),
			})
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag.current = nil
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, {})
	local unlock = function()
		if selected == nil or not canBuy then
			return nil
		end
		setBusy(true)
		Audio:play("domainImpact")
		dispatch("UnlockDomainNode", {
			Id = selected.id,
		}, function(response)
			setBusy(false)
			if response.ok then
				Audio:play("domainBind")
				Audio:play("domainReward")
				setBurstId(selected.id)
				setBinds(function(current)
					return current + 1
				end)
			else
				Audio:play("locked")
			end
		end)
	end
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 700,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 701,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, if stack then 16 else 18),
	}))
	local _exp_2 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, if stack then 16 else 18),
	})
	local _exp_3 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.pink,
		Thickness = 2,
		Transparency = flash:map(function(amount)
			return 0.22 - amount * 0.12
		end),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, headerH),
		Position = headerIn:map(function(amount)
			return UDim2.fromOffset(10, 8 + math.round((1 - amount) * 10))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 720,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = darken(Palette.pink, 0.55),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.pink,
		Thickness = 1,
		Transparency = 0.2,
	}), React.createElement(Text, {
		value = `{domain.Rank}`,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})), React.createElement(Text, {
		value = "DOMAIN LATTICE",
		size = 9,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 7,
		position = UDim2.fromOffset(50, 4),
		sizeConstraint = UDim2.new(1, if stack then -166 else -210, 0, 12),
	}), React.createElement(Text, {
		value = "Bind a branch.",
		size = if stack then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(50, 18),
		sizeConstraint = UDim2.new(1, if stack then -166 else -210, 0, 22),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 40),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement(Text, {
		value = `{points}`,
		size = 16,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 1),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = "POINTS",
		size = 8,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 12),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 40),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement(Text, {
		value = `{boundCount}/{#NODES}`,
		size = 16,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 1),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = "BOUND",
		size = 8,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 12),
	}))))
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _attributes = {
		reducedMotion = not liveFx,
	}
	local _result_2 = selected
	if _result_2 ~= nil then
		_result_2 = _result_2.accent
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = Palette.pink
	end
	_attributes.accent = _condition_3
	local _exp_6 = React.createElement(LatticeField, _attributes)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#VEINS)
	local _callback_2 = function(vein)
		local from = nodeById(vein.from)
		local to = nodeById(vein.to)
		local live = nodeOwned(vein.from)
		local selectedVein = selectedId == vein.from or selectedId == vein.to
		local _object = table.clone(from)
		setmetatable(_object, nil)
		_object.x = padX + from.x * (1 - padX * 2)
		_object.y = padY + from.y * (1 - padY * 2)
		local fromPad = _object
		local _object_1 = table.clone(to)
		setmetatable(_object_1, nil)
		_object_1.x = padX + to.x * (1 - padX * 2)
		_object_1.y = padY + to.y * (1 - padY * 2)
		local toPad = _object_1
		return React.createElement(BranchVein, {
			key = `{vein.from}-{vein.to}`,
			from = fromPad,
			to = toPad,
			live = live and liveFx,
			selected = selectedVein,
			reducedMotion = not liveFx,
		})
	end
	for _k, _v in VEINS do
		_newValue[_k] = _callback_2(_v, _k - 1, VEINS)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#NODES)
	local _callback_3 = function(node, index)
		local isOwned = nodeOwned(node.id)
		local _condition_4 = not isOwned
		if _condition_4 then
			local _exp_7 = node.requires
			-- ▼ ReadonlyArray.every ▼
			local _result_3 = true
			local _callback_4 = function(id)
				return nodeOwned(id)
			end
			for _k, _v in _exp_7 do
				if not _callback_4(_v, _k - 1, _exp_7) then
					_result_3 = false
					break
				end
			end
			-- ▲ ReadonlyArray.every ▲
			_condition_4 = _result_3
			if _condition_4 then
				_condition_4 = points >= node.cost
			end
		end
		local ready = _condition_4
		return React.createElement(HexNode, {
			key = node.id,
			node = node,
			owned = isOwned,
			ready = ready,
			selected = selectedId == node.id,
			bound = burstId == node.id,
			reducedMotion = not liveFx,
			onSelect = function()
				return setSelectedId(node.id)
			end,
			index = index,
			nodeSize = nodeSize,
			padX = padX,
			padY = padY,
		})
	end
	for _k, _v in NODES do
		_newValue_1[_k] = _callback_3(_v, _k - 1, NODES)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -16, 1, -(headerH + footerH + treeGap * 2 + 10)),
		Position = UDim2.fromOffset(8, headerH + treeGap + 6),
		BackgroundColor3 = darken(Palette.void, 0.04),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 710,
		Active = true,
		Event = {
			InputBegan = function(_frame, input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return nil
				end
				drag.current = {
					x = input.Position.X,
					y = input.Position.Y,
					ox = pan.x,
					oy = pan.y,
				}
			end,
		},
	}, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(pan.x, pan.y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _newValue, _newValue_1))
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _attributes_1 = {}
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.accent
	end
	local _condition_4 = _result_3
	if _condition_4 == nil then
		_condition_4 = Palette.pink
	end
	_attributes_1.Color = _condition_4
	_attributes_1.Thickness = 1
	_attributes_1.Transparency = 0.4
	local _exp_9 = React.createElement("uistroke", _attributes_1)
	local _attributes_2 = {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(12, 10),
	}
	local _result_4 = selected
	if _result_4 ~= nil then
		_result_4 = _result_4.accent
	end
	local _condition_5 = _result_4
	if _condition_5 == nil then
		_condition_5 = Palette.pink
	end
	_attributes_2.BackgroundColor3 = _condition_5
	_attributes_2.BorderSizePixel = 0
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 700,
		ClipsDescendants = true,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, _exp, React.createElement("frame", {
		Size = UDim2.fromOffset(panelW, panelH),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 701,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 701,
	}, _exp_1, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 702,
		ClipsDescendants = true,
		Active = true,
	}, _exp_2, _exp_3, _exp_4, _exp_7, React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, footerH),
		Position = footerIn:map(function(amount)
			return UDim2.new(0, 8, 1, -(footerH + 6) + math.round((1 - amount) * 14))
		end),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 720,
	}, _exp_8, _exp_9, React.createElement("frame", _attributes_2, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = if selected ~= nil then selected.name else "Choose a branch",
		size = if stack then 14 else 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(24, 4),
		sizeConstraint = UDim2.new(1, if stack then -24 else -220, 0, 18),
	}), React.createElement(Text, {
		value = if selected ~= nil then `{selected.body}  ·  {selected.lore}` else "",
		size = if stack then 11 else 10,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(12, 24),
		sizeConstraint = UDim2.new(1, if stack then -24 else -220, 0, if stack then 32 else 14),
	}), not stack and React.createElement(Text, {
		value = if selected ~= nil then (if owned then "Already bound to this domain." elseif prereqs then `{selected.cost} points to bind` else "Open the earlier branch first.") else "",
		size = 10,
		color = if owned then Palette.mint elseif canBuy then Palette.mango else Palette.muted,
		position = UDim2.fromOffset(12, 40),
		sizeConstraint = UDim2.new(1, -220, 0, 12),
	}), React.createElement(Button, {
		text = if owned then "BOUND" elseif busy then "BINDING" else `BIND  {selected.cost}`,
		icon = "Domain",
		onClick = unlock,
		color = if canBuy then Palette.pink else Palette.panelSoft,
		textColor = if canBuy then Palette.cream else Palette.muted,
		size = if stack then UDim2.new(0.58, -8, 0, TapTarget) else UDim2.fromOffset(118, 40),
		position = if stack then UDim2.new(0, 8, 1, -(TapTarget + 8)) else UDim2.new(1, -216, 0.5, -20),
		disabled = not canBuy,
		reducedMotion = reducedMotion,
		highlight = canBuy,
	}), React.createElement(Button, {
		text = "DONE",
		icon = "Close",
		onClick = close,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = if stack then UDim2.new(0.38, -8, 0, TapTarget) else UDim2.fromOffset(86, 40),
		position = if stack then UDim2.new(0.60, 4, 1, -(TapTarget + 8)) else UDim2.new(1, -90, 0.5, -20),
		reducedMotion = reducedMotion,
	})))))))
end
return {
	DomainSkillTree = DomainSkillTree,
}
