--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("UiOverlays: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("UiOverlays: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["DomainExpansionOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local Audio = require(script.Parent.AudioKit)("audio").Audio
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local easeOutQuart = _motion.easeOutQuart
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local CanvasEnergyField = require(script.Parent.UiCore)("effects").CanvasEnergyField
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local h = React.createElement
local TAU = math.pi * 2
local HOLD_SECONDS = 1.1
local KEEPS = { "Research", "Star Grid", "Relics", "Crew", "Milestones", "Guild", "Stardust" }
local RESETS = { "Machines", "Flux", "Vault", "Worlds", "Rebirths spent", "Cores spent" }

local function phase(value, from, to)
	return math.clamp((value - from) / math.max(0.001, to - from), 0, 1)
end

local function pulse(value, start, peak, finish)
	if value <= peak then
		return phase(value, start, peak)
	end
	return 1 - phase(value, peak, finish)
end

local function asNumber(value)
	local n = tonumber(value)
	return if n ~= nil and n == n then n else 0
end

local function surgeText()
	local boost = GameConfig.Boosts and GameConfig.Boosts[GameConfig.Domain.SurgeBoostId or "DomainSurge"]
	if boost == nil then
		return "6x surge"
	end
	local minutes = math.floor((tonumber(boost.Duration) or 1800) / 60 + 0.5)
	local mult = tonumber(boost.Multiplier) or tonumber(boost.ProductionMultiplier)
	return if mult ~= nil then `{mult}x · {minutes}m` else `{minutes}m surge`
end

-- The portal: a halo, three counter-rotating rings, a swirling accretion disk, an event horizon and
-- orbiting motes. `collapse` (0..1) pulls everything into the core; `children` sit in the middle.
local function Portal(props)
	local time = props.time
	local size = props.size
	local softMotion = props.softMotion
	local budget = props.budget or 1
	local collapse = props.collapse
	local function shrink(map)
		if collapse == nil then
			return time:map(function(t)
				return map(t, 0)
			end)
		end
		return React.joinBindings({ time, collapse }):map(function(values)
			return map(values[1], math.clamp(values[2], 0, 1))
		end)
	end
	local rings = {}
	local ringColors = { Palette.violet, Palette.pink, Palette.cyan }
	for index = 1, 3 do
		local scale = 1 - (index - 1) * 0.13
		rings[`ring{index}`] = h("frame", {
			Size = shrink(function(_t, c)
				local s = scale * (1 - c * 0.88)
				return UDim2.fromScale(s, s)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = time:map(function(t)
				local speed = if softMotion then 6 else (14 + index * 9)
				return t * speed * (if index % 2 == 0 then -1 else 1) + index * 40
			end),
			BackgroundTransparency = 1,
			ZIndex = 4 + index,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = if index == 1 then 3 else 2,
			Transparency = time:map(function(t)
				return math.clamp(0.18 + (index - 1) * 0.14 + math.sin(t * 2.4 + index) * 0.08, 0.05, 0.7)
			end),
		}, h("uigradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, ringColors[index]),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, ringColors[index]),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.85),
				NumberSequenceKeypoint.new(0.55, 0.85),
				NumberSequenceKeypoint.new(1, 0),
			}),
		})))
	end
	local motes = {}
	local moteCount = if softMotion then 5 elseif budget < 0.4 then 7 else 12
	for index = 1, moteCount do
		local radius = 0.34 + (index % 4) * 0.05
		local speed = 0.35 + (index % 3) * 0.12
		motes[`mote{index}`] = h("frame", {
			Size = UDim2.fromOffset(if index % 3 == 0 then 6 else 4, if index % 3 == 0 then 6 else 4),
			Position = shrink(function(t, c)
				local a = t * speed * (if index % 2 == 0 then 1 else -1) + index * (TAU / moteCount)
				local r = radius * (1 - c * 0.9)
				return UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r * 0.42)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 3 == 0 then Color3.new(1, 1, 1) elseif index % 2 == 0 then Palette.cyan else Palette.pink,
			BackgroundTransparency = time:map(function(t)
				return 0.15 + (math.sin(t * 3 + index) * 0.5 + 0.5) * 0.5
			end),
			BorderSizePixel = 0,
			ZIndex = 12,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, h("frame", {
		Name = "Halo",
		Size = UDim2.fromScale(1.5, 1.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.violet,
		BackgroundTransparency = shrink(function(t, c)
			return math.clamp(0.82 + math.sin(t * 1.3) * 0.04 + c * 0.15, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = time:map(function(t)
			return (t * 8) % 360
		end),
	})), h("frame", {
		Name = "Disk",
		Size = shrink(function(_t, c)
			return UDim2.fromScale(1.25 * (1 - c * 0.9), 0.34 * (1 - c * 0.9))
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -14,
		BackgroundColor3 = Palette.pink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.violet),
			ColorSequenceKeypoint.new(0.3, Palette.pink),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 236, 220)),
			ColorSequenceKeypoint.new(0.7, Palette.cyan),
			ColorSequenceKeypoint.new(1, Palette.violet),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = time:map(function(t)
			return Vector2.new(math.sin(t * (if softMotion then 0.4 else 1.1)) * 0.18, 0)
		end),
	})), rings, motes, h("frame", {
		Name = "Horizon",
		Size = shrink(function(_t, c)
			local s = 0.42 * (1 - c * 0.7)
			return UDim2.fromScale(s, s)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = Color3.fromRGB(255, 230, 245),
		Thickness = 2,
		Transparency = time:map(function(t)
			return 0.15 + math.sin(t * 4) * 0.1
		end),
	}), h("uigradient", {
		Color = ColorSequence.new(darken(Palette.violet, 0.7), Palette.void),
		Rotation = 90,
	})), h("frame", {
		Name = "Center",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, props.children))
end

local function Meter(props)
	local have, need = asNumber(props.have), asNumber(props.need)
	local fraction = if need <= 0 then 1 else math.clamp(have / need, 0, 1)
	local ready = have >= need
	local accent = if ready then Palette.mint else props.accent
	return h("frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = darken(accent, 0.86),
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = accent,
		Transparency = 0.55,
	}), h(Icon, {
		kind = if ready then "Check" else props.icon,
		color = Palette.cream,
		accent = accent,
		size = 22,
		position = UDim2.fromOffset(12, 9),
		spin = false,
	}), h(Text, {
		value = props.label,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(42, 8),
		sizeConstraint = UDim2.new(0.5, -42, 0, 14),
	}), h(Text, {
		value = if ready then "Ready" else `{compactNumber(need - have)} more`,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.5, 0, 0, 8),
		sizeConstraint = UDim2.new(0.5, -12, 0, 14),
	}), h(Text, {
		value = `{compactNumber(have)} / {compactNumber(need)}`,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(42, 22),
		sizeConstraint = UDim2.new(1, -54, 0, 18),
	}), h("frame", {
		Size = UDim2.new(1, -24, 0, 5),
		Position = UDim2.new(0, 12, 1, -10),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("frame", {
		Size = UDim2.fromScale(fraction, 1),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.25), accent),
	}))))
end

local function RewardTile(props)
	local reveal = props.reveal
	return h("frame", {
		BackgroundColor3 = darken(props.accent, 0.8),
		BackgroundTransparency = if reveal ~= nil then reveal:map(function(a)
			return 1 - a * 0.96
		end) else 0.04,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = props.accent,
		Thickness = 1.5,
		Transparency = if reveal ~= nil then reveal:map(function(a)
			return 1 - a * 0.6
		end) else 0.4,
	}), h("uiscale", {
		Scale = if reveal ~= nil then reveal:map(function(a)
			return 0.7 + easeOutBack(a) * 0.3
		end) else 1,
	}), h(Icon, {
		kind = props.icon,
		color = Palette.cream,
		accent = props.accent,
		size = 24,
		position = UDim2.new(0, 10, 0.5, -12),
		spin = false,
	}), h(Text, {
		value = props.value,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(42, 6),
		sizeConstraint = UDim2.new(1, -48, 0, 20),
		transparency = if reveal ~= nil then reveal:map(function(a)
			return 1 - a
		end) else nil,
	}), h(Text, {
		value = props.label,
		size = 10,
		color = props.accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(42, 26),
		sizeConstraint = UDim2.new(1, -48, 0, 14),
		transparency = if reveal ~= nil then reveal:map(function(a)
			return 1 - a
		end) else nil,
	}))
end

local function rewardsFor(domain, result)
	local essence = if result ~= nil then result.essence else domain.EssenceReward
	local stardust = if result ~= nil then result.stardust else domain.StardustReward
	local spins = if result ~= nil then result.freeSpins else (GameConfig.Domain.Expansion and GameConfig.Domain.Expansion.FreeSpins or 3)
	return {
		{ icon = "Domain", label = "DOMAIN ESSENCE", value = `+{compactNumber(asNumber(essence))}`, accent = Palette.pink },
		{ icon = "Dust", label = if result ~= nil and asNumber(result.overflow) > 0 then `STARDUST · +{compactNumber(result.overflow)} EXCESS` else "STARDUST", value = `+{compactNumber(asNumber(stardust))}`, accent = Palette.violet },
		{ icon = "StarGrid", label = "LATTICE POINTS", value = `+{GameConfig.Domain.SkillPointPerRank or 2}`, accent = Palette.mango },
		{ icon = "Boost", label = "DOMAIN SURGE", value = surgeText(), accent = Palette.cyan },
		{ icon = "Wheel", label = "FREE SPINS", value = `+{asNumber(spins)}`, accent = Palette.mint },
	}
end

local function ChipRow(props)
	local chips = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, label in props.items do
		chips[`c{index}`] = h("frame", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = darken(props.accent, 0.82),
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}), h("textlabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = lighten(props.accent, 0.2),
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		}))
	end
	return h("frame", {
		Size = UDim2.new(1, 0, 0, props.height),
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, h(Text, {
		value = props.title,
		size = 11,
		color = props.accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), h("frame", {
		Size = UDim2.new(1, 0, 1, -18),
		Position = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
	}, chips))
end

-- Expansion can't be undone, so it asks for a held press: the bar fills over HOLD_SECONDS and drains
-- if you let go.
local function HoldButton(props)
	local progress, setProgress = React.useBinding(0)
	local holding, setHolding = React.useState(false)
	local holdingRef = React.useRef(false)
	local valueRef = React.useRef(0)
	local firedRef = React.useRef(false)
	local propsRef = React.useRef(props)
	propsRef.current = props
	local function setHold(on)
		if on and not propsRef.current.enabled then
			Audio:play("locked")
			return
		end
		if holdingRef.current == on then
			return
		end
		holdingRef.current = on
		setHolding(on)
		if on then
			Audio:play("domainCharge")
			InteractionFeedback.tap()
		end
	end
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			local now = propsRef.current
			local target = if holdingRef.current and now.enabled then 1 else 0
			local current = valueRef.current
			if target == current then
				return
			end
			local rate = if target > current then 1 / HOLD_SECONDS else 2.6
			local step = math.min(math.abs(target - current), dt * rate)
			local nextValue = current + (if target > current then step else -step)
			if math.floor(nextValue * 4) > math.floor(current * 4) and target > current then
				Audio:play("tick", 0.9 + nextValue * 0.4)
			end
			valueRef.current = nextValue
			setProgress(nextValue)
			if nextValue >= 1 and not firedRef.current then
				firedRef.current = true
				holdingRef.current = false
				setHolding(false)
				valueRef.current = 0
				setProgress(0)
				now.onComplete()
			elseif nextValue < 1 then
				firedRef.current = false
			end
		end)
		local released = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
				setHold(false)
			end
		end)
		return function()
			connection:Disconnect()
			released:Disconnect()
		end
	end, {})
	local enabled = props.enabled
	local accent = if enabled then Palette.pink else Palette.panelSoft
	return h("imagebutton", {
		Name = "DomainClaim",
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = if enabled then darken(Palette.pink, 0.55) else Palette.panelSoft,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Selectable = true,
		LayoutOrder = props.order,
		ClipsDescendants = true,
		Event = {
			InputBegan = function(_gui, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
					setHold(true)
				end
			end,
			InputEnded = function(_gui, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
					setHold(false)
				end
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = if enabled then 0.1 else 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size = progress:map(function(p)
			return UDim2.fromScale(p, 1)
		end),
		BackgroundColor3 = Palette.pink,
		BorderSizePixel = 0,
	}, h("uigradient", {
		Color = ColorSequence.new(Palette.violet, Palette.pink),
	})), h(Icon, {
		kind = if enabled then "Domain" else "Lock",
		color = Palette.cream,
		accent = accent,
		size = 22,
		position = UDim2.new(0, 14, 0.5, -11),
		spin = holding and not props.softMotion,
	}), h(Text, {
		value = if not enabled then props.lockedText elseif props.busy then "OPENING THE DOMAIN…" elseif holding then "KEEP HOLDING…" else props.text,
		size = 15,
		color = if enabled then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(44, 0),
		sizeConstraint = UDim2.new(1, -88, 1, 0),
	}))
end

local function ConfirmView(props)
	local cardRef = React.useRef(nil)
	local parentSize = useGuiSize(cardRef, true)
	local domain = props.domain
	local viewport = props.viewport
	local softMotion = props.softMotion
	local time = props.time
	local wide = viewport.width >= 760 and viewport.height >= 470
	local side = math.max(12, viewport.sideInset + 12)
	local cardW = math.min(viewport.width - side * 2, 920)
	local availH = viewport.height - math.max(12, viewport.topInset + 12) - math.max(12, viewport.bottomInset + 12)
	local cardH = if wide then math.min(availH, 500) else availH
	local portalSize = if wide then math.min(300, cardH - 80) else math.min(170, viewport.width * 0.42)
	local ready = domain.CanExpand == true
	local rebirths, cores = asNumber(props.currentRebirths), asNumber(props.currentCores)
	local needRebirths, needCores = asNumber(domain.RequiredRebirths), asNumber(domain.RequiredCores)
	local lockedText = if rebirths < needRebirths then `NEED {compactNumber(needRebirths - rebirths)} MORE REBIRTHS` elseif cores < needCores then `NEED {compactNumber(needCores - cores)} MORE CORES` else "NOT READY YET"
	local rewards = rewardsFor(domain, nil)
	local tiles = {
		Layout = h("uigridlayout", {
			CellSize = UDim2.new(if wide then 1 / 3 else 0.5, -6, 0, 52),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, reward in rewards do
		tiles[`r{index}`] = h(RewardTile, {
			icon = reward.icon,
			label = reward.label,
			value = reward.value,
			accent = reward.accent,
			order = index,
		})
	end
	local tileRows = math.ceil(#rewards / (if wide then 3 else 2))
	local details = {
		Layout = h("uilistlayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Eyebrow = h(Text, {
			value = `DOMAIN {domain.Rank}  →  {domain.Rank + 1}`,
			size = 12,
			color = Palette.pink,
			weight = Enum.FontWeight.Heavy,
			layoutOrder = 1,
			sizeConstraint = UDim2.new(1, -50, 0, 16),
		}),
		Title = h(Text, {
			value = "Collapse this run into a new Domain",
			size = if wide then 24 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 14,
			layoutOrder = 2,
			sizeConstraint = UDim2.new(1, -50, 0, if wide then 30 else 26),
		}),
		Meters = h("frame", {
			Size = UDim2.new(1, 0, 0, if wide then 54 else 116),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, h("uigridlayout", {
			CellSize = if wide then UDim2.new(0.5, -5, 0, 54) else UDim2.new(1, 0, 0, 54),
			CellPadding = UDim2.fromOffset(10, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), h(Meter, { label = "REBIRTHS", icon = "Rebirth", have = rebirths, need = needRebirths, accent = Palette.coral, order = 1 }),
			h(Meter, { label = "ASTRAL CORES", icon = "Core", have = cores, need = needCores, accent = Palette.coral, order = 2 })),
		RewardLabel = h(Text, {
			value = "YOU GAIN",
			size = 11,
			color = Palette.mango,
			weight = Enum.FontWeight.Heavy,
			layoutOrder = 4,
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}),
		Rewards = h("frame", {
			Size = UDim2.new(1, 0, 0, tileRows * 52 + (tileRows - 1) * 8),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
		}, tiles),
		Keeps = h(ChipRow, { title = "STAYS WITH YOU", items = KEEPS, accent = Palette.mint, height = if wide then 46 else 76, order = 6 }),
		Resets = h(ChipRow, { title = "RESETS", items = RESETS, accent = Palette.coral, height = if wide then 46 else 76, order = 7 }),
		Hold = h(HoldButton, {
			size = UDim2.new(1, 0, 0, TapTarget + 8),
			order = 8,
			enabled = ready and not props.busy,
			busy = props.busy,
			text = "HOLD TO EXPAND",
			lockedText = lockedText,
			softMotion = softMotion,
			onComplete = function()
				Audio:play("domainImpact")
				InteractionFeedback.reward()
				props.onConfirm()
			end,
		}),
	}
	local detailsW = if wide then cardW - portalSize - 72 else cardW - 32
	local detailFrame
	if wide then
		detailFrame = h("frame", {
			Size = UDim2.new(0, detailsW, 1, -40),
			Position = UDim2.fromOffset(portalSize + 52, 20),
			BackgroundTransparency = 1,
			ZIndex = 30,
		}, details)
	else
		detailFrame = h("scrollingframe", {
			Size = UDim2.new(1, -32, 1, -(portalSize + 34)),
			Position = UDim2.fromOffset(16, portalSize + 24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Palette.pink,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 30,
		}, h("uipadding", { PaddingBottom = UDim.new(0, 12) }), details)
	end
	local cardIn = React.joinBindings({ props.enter, parentSize }):map(function(values)
		return pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 30)
	end)
	return h("frame", {
		ref = cardRef,
		Size = UDim2.fromOffset(cardW, cardH),
		Position = cardIn,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = props.enter:map(function(a)
			return 1 - a * 0.94
		end),
		BorderSizePixel = 0,
		ZIndex = 20,
	}, h("uicorner", { CornerRadius = UDim.new(0, 22) }), h("uistroke", {
		Color = if ready then Palette.pink else Palette.violet,
		Thickness = 2,
		Transparency = time:map(function(t)
			return if ready then 0.1 + math.sin(t * 2.6) * 0.1 else 0.4
		end),
	}), h("uigradient", {
		Color = ColorSequence.new(darken(Palette.violet, 0.78), Palette.void),
		Rotation = 25,
	}), h(Portal, {
		time = time,
		size = portalSize,
		softMotion = softMotion,
		budget = props.budget,
		position = if wide then UDim2.new(0, 24 + portalSize / 2, 0.5, 0) else UDim2.new(0.5, 0, 0, 14 + portalSize / 2),
	}, h(Text, {
		value = `{domain.Rank + 1}`,
		size = math.floor(portalSize * 0.17),
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 0.5, -math.floor(portalSize * 0.1)),
		sizeConstraint = UDim2.new(1, 0, 0, math.floor(portalSize * 0.2)),
		zIndex = 22,
	})), detailFrame, h("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -(TapTarget + 10), 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 40,
	}, h(Button, {
		text = "",
		icon = "Close",
		onClick = props.onClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		zIndex = 41,
	})))
end

local function ResultView(props)
	local domain = props.domain
	local result = props.result or {}
	local viewport = props.viewport
	local softMotion = props.softMotion
	local time = props.time
	local compact = viewport.width < 640 or viewport.height < 500
	local portalSize = if compact then math.min(220, viewport.width * 0.55) else 300
	local rank = result.rank or domain.Rank
	local collapse = time:map(function(t)
		local inward = easeOutQuart(phase(t, 0, 0.8))
		local outward = easeOutBack(phase(t, 0.95, 1.6))
		return math.clamp(inward - outward, 0, 1)
	end)
	local impact = time:map(function(t)
		return pulse(t, 0.82, 0.92, 1.5)
	end)
	local titleIn = time:map(function(t)
		return easeOutBack(phase(t, 1.05, 1.6))
	end)
	local shards = {}
	local shardCount = if softMotion then 6 elseif (props.budget or 1) < 0.4 then 10 else 18
	for index = 1, shardCount do
		local angle = index / shardCount * TAU + (index % 3) * 0.2
		local distance = (if compact then 140 else 220) + (index % 4) * 40
		shards[`s{index}`] = h("frame", {
			Size = UDim2.fromOffset(4 + index % 3, 16 + (index % 4) * 8),
			Position = time:map(function(t)
				local fly = easeOutQuart(phase(t, 0.88, 2.4))
				return UDim2.new(0.5, math.cos(angle) * distance * fly, 0.5, math.sin(angle) * distance * fly)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(angle) + 90,
			BackgroundColor3 = if index % 3 == 0 then Palette.cyan elseif index % 2 == 0 then Palette.pink else Color3.new(1, 1, 1),
			BackgroundTransparency = time:map(function(t)
				return 1 - pulse(t, 0.86, 1.0, 2.6) * 0.9
			end),
			BorderSizePixel = 0,
			ZIndex = 8,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	local waves = {}
	for index = 1, 3 do
		waves[`w{index}`] = h("frame", {
			Size = time:map(function(t)
				local grow = easeOutQuart(phase(t, 0.86 + index * 0.08, 1.9 + index * 0.1))
				local px = grow * math.max(viewport.width, viewport.height) * 1.2
				return UDim2.fromOffset(px, px)
			end),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 7,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = if index == 2 then Palette.cyan else Palette.pink,
			Thickness = 3,
			Transparency = time:map(function(t)
				return 0.1 + phase(t, 0.9 + index * 0.08, 2.0 + index * 0.1) * 0.9
			end),
		}))
	end
	local rewards = rewardsFor(domain, result)
	local tiles = {
		Layout = h("uigridlayout", {
			CellSize = UDim2.new(if compact then 0.5 else 0.2, -8, 0, 54),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}
	for index, reward in rewards do
		tiles[`r{index}`] = h(RewardTile, {
			icon = reward.icon,
			label = reward.label,
			value = reward.value,
			accent = reward.accent,
			order = index,
			reveal = time:map(function(t)
				return if softMotion then phase(t, 1.5, 1.7) else phase(t, 1.6 + index * 0.1, 1.95 + index * 0.1)
			end),
		})
	end
	local rows = math.ceil(#rewards / (if compact then 2 else 5))
	local tilesW = math.min(viewport.width - 32, if compact then 400 else 860)
	local nextLine = if asNumber(result.nextRebirths) > 0 then `Next Domain: {compactNumber(result.nextRebirths)} rebirths + {compactNumber(result.nextCores)} cores` else ""
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, waves, shards, h(Portal, {
		time = time,
		size = portalSize,
		softMotion = softMotion,
		budget = props.budget,
		collapse = collapse,
		position = UDim2.fromScale(0.5, if compact then 0.3 else 0.32),
	}), h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = impact:map(function(a)
			return 1 - a * 0.85
		end),
		BorderSizePixel = 0,
		ZIndex = 60,
	}), h("frame", {
		Size = UDim2.new(1, -32, 0, 100),
		Position = titleIn:map(function(a)
			return UDim2.new(0.5, 0, if compact then 0.3 else 0.32, math.round((1 - a) * 40))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, h(Text, {
		value = `DOMAIN {rank}`,
		size = if compact then 40 else 58,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 24,
		sizeConstraint = UDim2.new(1, 0, 0, if compact then 46 else 64),
		transparency = titleIn:map(function(a)
			return 1 - math.clamp(a, 0, 1)
		end),
		zIndex = 51,
	}), h(Text, {
		value = "EXPANSION COMPLETE",
		size = if compact then 14 else 18,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, if compact then 48 else 66),
		sizeConstraint = UDim2.new(1, 0, 0, 22),
		transparency = titleIn:map(function(a)
			return 1 - math.clamp(a, 0, 1)
		end),
		zIndex = 51,
	})), h("frame", {
		Size = UDim2.fromOffset(tilesW, rows * 54 + (rows - 1) * 8),
		Position = UDim2.new(0.5, 0, if compact then 0.56 else 0.62, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 52,
	}, tiles), nextLine ~= "" and h(Text, {
		value = nextLine,
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 16, 1, -(math.max(viewport.bottomInset, 12) + TapTarget + 40)),
		sizeConstraint = UDim2.new(1, -32, 0, 16),
		zIndex = 52,
	}), h("frame", {
		Size = UDim2.fromOffset(math.min(300, viewport.width - 32), TapTarget),
		Position = UDim2.new(0.5, 0, 1, -(math.max(viewport.bottomInset, 12) + TapTarget + 12)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 70,
	}, h(Button, {
		text = if props.canClose then "OPEN THE LATTICE" else "…",
		icon = "Domain",
		onClick = props.onClose,
		color = if props.canClose then Palette.pink else Palette.panelSoft,
		textColor = if props.canClose then Palette.cream else Palette.muted,
		size = UDim2.fromScale(1, 1),
		disabled = not props.canClose,
		highlight = props.canClose,
		reducedMotion = softMotion,
		zIndex = 71,
	})))
end

local function DomainExpansionOverlay(_param)
	local mode = _param.mode
	local domain = _param.domain
	local busy = _param.busy == true
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local antilag = useAntilag()
	local resultMode = mode == "result"
	local time, setTime = React.useBinding(0)
	local _binding = useExitTransition(softMotion, 0.32)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local canClose, setCanClose = React.useState(not resultMode)
	local hostRef = React.useRef(nil)
	local leavingRef = React.useRef(leaving)
	leavingRef.current = leaving
	React.useEffect(function()
		local started = os.clock()
		local speed = if softMotion then 1.6 else 1
		local connection = RunService.RenderStepped:Connect(function()
			if not leavingRef.current then
				setTime((os.clock() - started) * speed)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { softMotion })
	React.useEffect(function()
		Audio:play("domainCharge")
		if not resultMode then
			return nil
		end
		local alive = true
		local scale = if softMotion then 1 / 1.6 else 1
		local jobs = {
			task.delay(0.6 * scale, function()
				if alive then
					Audio:play("domainCrack")
				end
			end),
			task.delay(0.86 * scale, function()
				if alive then
					Audio:play("domainImpact")
					InteractionFeedback.reward()
				end
			end),
			task.delay(1.6 * scale, function()
				if alive then
					Audio:play("domainReward")
				end
			end),
			task.delay(2.5 * scale, function()
				if alive then
					setCanClose(true)
				end
			end),
		}
		return function()
			alive = false
			for _, job in jobs do
				pcall(task.cancel, job)
			end
		end
	end, { resultMode, softMotion })
	local close = React.useCallback(function()
		if busy or leaving or (resultMode and not canClose) then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, busy, canClose, leaving, onClose, resultMode })
	React.useEffect(function()
		local actionName = "AstralForgeDomainClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { resultMode, canClose, domain.CanExpand })
	local enter = React.joinBindings({ time, leave }):map(function(values)
		return math.clamp(math.min(easeOutCubic(phase(values[1], 0, 0.35)), values[2]), 0, 1)
	end)
	local body
	if resultMode then
		body = h(ResultView, {
			domain = domain,
			result = _param.result,
			viewport = viewport,
			softMotion = softMotion,
			time = time,
			budget = antilag.fxBudget,
			canClose = canClose,
			onClose = close,
		})
	else
		body = h(ConfirmView, {
			domain = domain,
			viewport = viewport,
			softMotion = softMotion,
			time = time,
			enter = enter,
			budget = antilag.fxBudget,
			busy = busy,
			currentRebirths = _param.currentRebirths,
			currentCores = _param.currentCores,
			onConfirm = function()
				if _param.onConfirm ~= nil then
					_param.onConfirm()
				end
			end,
			onClose = close,
		})
	end
	return h(OverlayPresence, {
		amount = enter,
	}, h("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = enter:map(function(a)
			return 1 - a * 0.86
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 700,
		ClipsDescendants = true,
		Visible = enter:map(function(a)
			return a > 0.02
		end),
	}, h("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		ZIndex = 700,
	}), h("frame", {
		Size = UDim2.fromScale(1.6, 1.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(Palette.violet, 0.7),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 701,
	}, h("uigradient", {
		Color = ColorSequence.new(darken(Palette.pink, 0.6), Palette.void),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.6, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = time:map(function(t)
			return 30 + math.sin(t * 0.3) * 20
		end),
	})), h(CanvasEnergyField, {
		time = time,
		enabled = not softMotion and antilag.fxBudget >= 0.5,
		reducedMotion = softMotion,
		zIndex = 702,
	}), h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 710,
	}, body)))
end

return {
	DomainExpansionOverlay = DomainExpansionOverlay,
}
end

__defs["DomainSkillTree"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local InteractionFeedback = require(script.Parent.CoreKit)("interaction").InteractionFeedback
local _motion = require(script.Parent.MotionKit)("motion")
local composePresence = _motion.composePresence
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local DomainKit = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("DomainKit"))
local useGuiSize = _ui.useGuiSize
local pixelPosition = _ui.pixelPosition
local _elementFx = require(script.Parent.ElementFx)
local ElementFx = _elementFx.ElementFx
local elementSheet = _elementFx.sheet
local easeOutBack = _motion.easeOutBack
local useMotionSettings = _motion.useMotionSettings
local RunService = game:GetService("RunService")

local h = React.createElement
local TREE = (GameConfig.Domain and GameConfig.Domain.Tree) or {}
local FIELD_ORDER = { "Production", "Capacity", "Tap", "Offline", "Luck", "EchoCharge", "WorldDiscount", "RebirthYield", "EssenceGain", "ContinuumDiscount", "Critical", "ForgePathXP", "CommandXP" }
-- element: the animated aura a bound node of that field burns with (Shared/ElementSprites)
local FIELD_STYLE = {
	Production = { icon = "Flux", accent = Palette.cyan, label = "production", element = "Lightning" },
	Capacity = { icon = "Vault", accent = Palette.mango, label = "vault capacity", element = "Earth" },
	Tap = { icon = "Overcharge", accent = Palette.coral, label = "overcharge power", element = "Fire" },
	Offline = { icon = "Timer", accent = Palette.violet, label = "offline yield", element = "Cosmic" },
	Luck = { icon = "Crate", accent = Palette.pink, label = "crate & market luck", element = "Prism" },
	EchoCharge = { icon = "Wave", accent = Palette.mint, label = "echo charge speed", element = "Sonic" },
	WorldDiscount = { icon = "World", accent = Palette.violet, label = "off world unlocks", element = "Void" },
	RebirthYield = { icon = "Core", accent = Palette.mango, label = "rebirth cores", element = "Magma" },
	EssenceGain = { icon = "Domain", accent = Palette.pink, label = "essence per expansion", flat = true, element = "Spirit" },
	ContinuumDiscount = { icon = "Rebirth", accent = Palette.cyan, label = "off continuum ranks", element = "Chrono" },
	Critical = { icon = "Jackpot", accent = Palette.coral, label = "critical chance", element = "Blood" },
	ForgePathXP = { icon = "Forge", accent = Palette.mango, label = "forge path XP", element = "Solar" },
	CommandXP = { icon = "Mission", accent = Palette.mint, label = "command XP", element = "Arcane" },
}

local function fieldOf(node)
	for _, field in FIELD_ORDER do
		if node[field] ~= nil then
			return field
		end
	end
	return "Production"
end

local function effectText(field, value)
	local style = FIELD_STYLE[field] or FIELD_STYLE.Production
	if style.flat then
		return `+{value} {style.label}`
	end
	return `+{math.floor(value * 100 + 0.5)}% {style.label}`
end

-- Tiers by longest prerequisite chain; within a tier, nodes sit near the average of their parents so the
-- links cross as little as possible.
local function buildLayout()
	local byId = {}
	for _, node in TREE do
		byId[node.Id] = node
	end
	local depth = {}
	local function depthOf(id, guard)
		if depth[id] ~= nil then
			return depth[id]
		end
		if guard[id] then
			return 0
		end
		guard[id] = true
		local node = byId[id]
		local d = 0
		for _, parent in (node and node.Requires) or {} do
			if byId[parent] ~= nil then
				d = math.max(d, depthOf(parent, guard) + 1)
			end
		end
		depth[id] = d
		return d
	end
	local tiers = {}
	local maxDepth = 0
	for _, node in TREE do
		local d = depthOf(node.Id, {})
		maxDepth = math.max(maxDepth, d)
		tiers[d + 1] = tiers[d + 1] or {}
		table.insert(tiers[d + 1], node.Id)
	end
	local position = {}
	for tierIndex = 1, maxDepth + 1 do
		local tier = tiers[tierIndex] or {}
		if tierIndex > 1 then
			local order = {}
			for i, id in tier do
				local sum, count = 0, 0
				for _, parent in byId[id].Requires or {} do
					if position[parent] ~= nil then
						sum += position[parent]
						count += 1
					end
				end
				order[id] = if count > 0 then sum / count else i / #tier
			end
			table.sort(tier, function(a, b)
				return order[a] < order[b]
			end)
		end
		for i, id in tier do
			position[id] = (i - 0.5) / #tier
		end
		tiers[tierIndex] = tier
	end
	local slot = {}
	local widest = 1
	for tierIndex, tier in tiers do
		widest = math.max(widest, #tier)
		for i, id in tier do
			slot[id] = { tier = tierIndex - 1, index = i, count = #tier }
		end
	end
	return { byId = byId, tiers = tiers, slot = slot, tierCount = #tiers, widest = widest }
end
local LAYOUT = buildLayout()

-- Front-facing terraces keep prerequisites legible while retaining depth when orbiting.
local STEP_Y = 3.2
local BANDS = 5
local FOV = 38
local function buildSpace()
	local tiers = math.max(1, LAYOUT.tierCount)
	local points = {}
	local radiusMax = 0
	local depthMax = 0
	local baseY = -(tiers - 1) * STEP_Y / 2
	for id, slotInfo in LAYOUT.slot do
		local t = slotInfo.tier
		local x = (slotInfo.index - (slotInfo.count + 1) / 2) * 3.4
		local z = 0.8 - (x / math.max(1, LAYOUT.widest)) ^ 2 * 0.25
		radiusMax = math.max(radiusMax, Vector3.new(x, 0, z).Magnitude)
		depthMax = math.max(depthMax, math.abs(z))
		points[id] = { pos = Vector3.new(x, baseY + t * STEP_Y, z), angle = math.atan2(x, z), tier = t }
	end
	return {
		points = points,
		radius = radiusMax + 0.6,
		depth = depthMax + 0.6,
		bottom = baseY - 1.6,
		top = baseY + (tiers - 1) * STEP_Y + 0.6,
		height = (tiers - 1) * STEP_Y + 3,
	}
end
local SPACE = buildSpace()

local function smoothDomainValue(current, target, dt, reducedMotion)
	if reducedMotion then return target end
	return current + (target - current) * (1 - math.exp(-math.max(0, dt) * 8))
end

local function bezier(a, c, b, t)
	local u = 1 - t
	return a * (u * u) + c * (2 * u * t) + b * (t * t)
end

local function rod(a, b, thickness, color, material, transparency)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(math.max(0.01, (b - a).Magnitude), thickness, thickness)
	part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local function orb(position, size, color, material, transparency)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local function wrapAngle(target, current)
	local tau = math.pi * 2
	return current + ((target - current + math.pi) % tau - math.pi)
end

local GEM_SIZE = 2.2
local GEM_CAMERA = CFrame.lookAt(Vector3.new(0, 0.9, 4.4), Vector3.zero)

local function fitted(piece, target)
	local size = piece.Size
	piece.Size = size * (target / math.max(size.X, size.Y, size.Z, 0.01))
	return piece
end

-- One field's gem for a viewport: the kit mesh as a tinted shell around a neon heart, or the original
-- glass orb while the kit has not arrived. `spin` lists the parts the caller turns each frame.
local function buildGem(kit, field, accent, owned, available)
	local shape = DomainKit.Fields[field] or "Brilliant"
	local piece = if kit ~= nil then kit:FindFirstChild("Domain_" .. shape) else nil
	local tone = if owned then accent elseif available then darken(accent, 0.2) else Color3.fromRGB(96, 92, 112)
	if piece == nil or not piece:IsA("BasePart") then
		local shell = orb(Vector3.zero, 2, tone, Enum.Material.Glass, if owned then 0.35 else 0.55)
		local core = orb(Vector3.zero, if owned then 1.15 else 0.8, if owned then lighten(accent, 0.2) else tone, if owned or available then Enum.Material.Neon else Enum.Material.SmoothPlastic, if owned then 0 elseif available then 0.25 else 0.4)
		return { parts = { shell, core }, spin = {}, base = CFrame.identity, sway = false, spinLocal = false }
	end
	local tableUp = DomainKit.TableUp[shape] == true
	-- table cuts tip their table toward the camera; the cube stands on a corner
	local base = if tableUp then CFrame.Angles(math.rad(58), 0, 0) elseif shape == "Cube" then CFrame.Angles(math.rad(35.26), 0, math.rad(45)) else CFrame.Angles(math.rad(8), 0, 0)
	local shell = fitted(piece:Clone(), GEM_SIZE)
	shell.Color = if owned then lighten(accent, 0.12) else tone
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = if owned then 0.2 else 0
	shell.Transparency = if owned then 0.32 elseif available then 0.22 else 0.1
	shell.CFrame = base
	local parts = { shell }
	if owned or available then
		local heart = fitted(piece:Clone(), GEM_SIZE * (if owned then 0.6 else 0.48))
		heart.Color = if owned then lighten(accent, 0.4) else accent
		heart.Material = Enum.Material.Neon
		heart.Transparency = if owned then 0 else 0.5
		heart.CFrame = base
		table.insert(parts, heart)
	end
	return { parts = parts, spin = parts, base = base, sway = DomainKit.Sway[shape] == true, spinLocal = tableUp }
end

local function gemFrame(gem, seconds, speed, phase)
	local turn = CFrame.Angles(0, if gem.sway then math.sin(seconds * 0.9 + phase) * 0.55 else seconds * speed + phase, 0)
	return if gem.spinLocal then gem.base * turn else turn * gem.base
end

-- The server publishes the gem kit a moment after start; anything opened before then upgrades in place.
local function useDomainKit()
	local kit, setKit = React.useState(function()
		return ReplicatedStorage:FindFirstChild("DomainKit")
	end)
	React.useEffect(function()
		if kit ~= nil then
			return nil
		end
		local connection = ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "DomainKit" then
				setKit(child)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { kit })
	return kit
end

-- A self-contained turning gem, for places outside the lattice (the detail panel).
local function GemView(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local viewport = ref.current
		if viewport == nil then
			return nil
		end
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = GEM_CAMERA
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local gem = buildGem(props.kit, props.field, props.accent, props.owned, props.available)
		for _, part in gem.parts do
			part.Parent = viewport
		end
		local connection = nil
		if not props.softMotion and #gem.spin > 0 then
			local started = os.clock()
			connection = RunService.RenderStepped:Connect(function()
				local frame = gemFrame(gem, os.clock() - started, 0.8, 0)
				for _, part in gem.spin do
					part.CFrame = frame
				end
			end)
		end
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
			camera:Destroy()
			for _, part in gem.parts do
				part:Destroy()
			end
		end
	end, { props.kit, props.field, props.accent, props.owned, props.available, props.softMotion })
	return h("viewportframe", {
		ref = ref,
		Size = props.size,
		Position = props.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(120, 110, 160),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = props.zIndex,
	})
end

local function NodeButton(props)
	local node = props.node
	local field = fieldOf(node)
	local style = FIELD_STYLE[field]
	local accent = style.accent
	local owned, available, affordable, selected = props.owned, props.available, props.affordable, props.selected
	local softMotion = props.softMotion
	local hovered, setHovered = React.useState(false)
	local lift = useFlipperSpring(if selected then 1 elseif hovered then 0.5 else 0, softMotion, 620, 32)
	local beat = usePulse((selected or (available and affordable)) and not softMotion, 0.65)
	local burst = useFlash(if props.bound then props.boundToken else 0, softMotion, 0.8)
	local size = props.size
	local fill = if owned then darken(accent, 0.55) elseif available then darken(accent, 0.75) else Palette.panel
	local buttonRef = React.useRef(nil)
	local gemRef = React.useRef(nil)
	local fogRef = React.useRef(nil)
	React.useEffect(function()
		local viewport = gemRef.current
		if viewport == nil then
			return nil
		end
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = GEM_CAMERA
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local gem = buildGem(props.kit, field, accent, owned, available)
		for _, part in gem.parts do
			part.Parent = viewport
		end
		local phase = 0
		for index = 1, #node.Id do
			phase += string.byte(node.Id, index)
		end
		local registry = props.registry
		if registry ~= nil then
			-- the lattice's render loop places the button and turns the gem
			registry[node.Id] = {
				button = buttonRef.current,
				camera = camera,
				fog = fogRef.current,
				gem = gem,
				speed = if owned then 0.3 elseif available then 0.18 else 0,
				phase = (phase * 0.37) % (math.pi * 2),
			}
		end
		return function()
			if registry ~= nil and registry[node.Id] ~= nil and registry[node.Id].camera == camera then
				registry[node.Id] = nil
			end
			camera:Destroy()
			for _, part in gem.parts do
				part:Destroy()
			end
		end
	end, { owned, available, props.registry, props.kit })
	local centre = UDim2.new(0.5, 0, 0, size / 2)
	return h("imagebutton", {
		ref = buttonRef,
		Name = "Node" .. node.Id,
		Size = UDim2.fromOffset(math.max(size, TapTarget), math.max(size, TapTarget) + 16),
		Position = UDim2.fromOffset(props.center.X, props.center.Y + 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
		ZIndex = 10,
		Event = {
			Activated = function()
				Audio:play(if owned or available then "filterPick" else "locked")
				props.onSelect()
			end,
			SelectionGained = function()
				setHovered(true)
				props.onFocus()
			end,
			MouseEnter = function()
				setHovered(true)
				Audio:play("navHover")
			end,
			MouseLeave = function()
				setHovered(false)
			end,
			SelectionLost = function()
				setHovered(false)
			end,
		},
	}, h("uiscale", { Name = "Depth", Scale = 1 }), selected and h(ElementFx, {
		-- the picked node stands on a turning rune circle
		element = "Arcane",
		size = UDim2.fromOffset(math.floor(size * 1.65), math.floor(size * 1.65)),
		position = centre,
		transparency = 0.55,
		framerate = 12,
		reducedMotion = softMotion,
		zIndex = 10,
	}), selected and h(ElementFx, {
		-- the node's own element breathes through the selected crown
		element = style.element,
		size = UDim2.fromOffset(math.floor(size * 1.92), math.floor(size * 1.92)),
		position = centre,
		transparency = 0.72,
		framerate = 16,
		reducedMotion = softMotion,
		zIndex = 10,
	}), owned and hovered and not selected and h(ElementFx, {
		-- bound nodes burn with their field's element
		element = style.element,
		size = UDim2.fromOffset(math.floor(size * 1.6), math.floor(size * 1.6)),
		position = centre,
		transparency = 0.6,
		framerate = 16,
		reducedMotion = softMotion,
		zIndex = 10,
	}), h("frame", {
		Name = "Gem",
		Size = UDim2.fromOffset(size, size),
		Position = lift:map(function(a)
			return UDim2.new(0.5, 0, 0, size / 2 - a * 3)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = fill,
		BackgroundTransparency = if owned then 0.3 else 0.08,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uiscale", {
		Scale = React.joinBindings({ lift, burst }):map(function(v)
			return 1 + v[1] * 0.06 + v[2] * 0.12
		end),
	}), h("uigradient", {
		Color = ColorSequence.new(lighten(fill, 0.25), darken(fill, 0.15)),
		Rotation = 90,
	}), h("uistroke", {
		Color = if selected then Palette.cream elseif owned or available then accent else Palette.lineSoft,
		Thickness = if selected then 2 else 1,
		Transparency = if owned then beat:map(function(a)
			return 0.05 + (1 - a) * 0.3
		end) elseif available and affordable then beat:map(function(a)
			return 0.1 + (1 - a) * 0.55
		end) elseif available then 0.35 else 0.65,
	}), h("viewportframe", {
		Name = "Orb",
		ref = gemRef,
		Size = UDim2.fromScale(1.3, 1.3),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(120, 110, 160),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = 11,
	}), h("frame", {
		Name = "Fog",
		ref = fogRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 16,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) })), h("frame", {
		-- the gem's cut already says which field it is; the badge confirms it (or shows the lock)
		Name = "Field",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(-2, -2),
		BackgroundColor3 = if owned or available then darken(accent, 0.45) else Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = if owned or available then accent else Palette.lineSoft,
		Transparency = 0.25,
	}), h(Icon, {
		kind = if available or owned then style.icon else "Lock",
		color = if owned or available then Palette.cream else Palette.muted,
		accent = accent,
		size = 12,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), owned and h("frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -2, 0, 2),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.mint,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h(Icon, {
		kind = "Check",
		color = Palette.ink,
		accent = Palette.mint,
		size = 12,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), props.bound and h("frame", {
		Size = burst:map(function(a)
			return UDim2.fromScale(1 + a * 1.6, 1 + a * 1.6)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 14,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = accent,
		Thickness = 3,
		Transparency = burst:map(function(a)
			return 1 - a
		end),
	}))), props.bound and h(ElementFx, {
		-- binding flashes holy light through the node
		element = "Radiance",
		size = UDim2.fromOffset(math.floor(size * 2.8), math.floor(size * 2.8)),
		position = centre,
		transparency = burst:map(function(a)
			return 1 - a
		end),
		framerate = 30,
		reducedMotion = softMotion,
		zIndex = 15,
	}), not owned and h("frame", {
		Name = "Cost",
		Size = UDim2.fromOffset(34, 16),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = if available and affordable then Palette.mango else Palette.panelSoft,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h(Text, {
		value = `{node.Cost}`,
		size = 11,
		color = if available and affordable then Palette.ink else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 13,
	})), (selected or hovered) and h("textlabel", {
		Name = "NodeName",
		Size = UDim2.fromOffset(144, 26),
		Position = UDim2.new(0.5, 0, 0, -30),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Text = node.Name,
		TextColor3 = Palette.cream,
		TextSize = 12,
		TextWrapped = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 20,
	}, h("uicorner", { CornerRadius = UDim.new(0, 6) })))
end

local function TotalsStrip(props)
	local totals = {}
	for _, node in TREE do
		if props.owned[node.Id] then
			local field = fieldOf(node)
			totals[field] = (totals[field] or 0) + (tonumber(node[field]) or 0)
		end
	end
	local chips = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local count = 0
	for order, field in FIELD_ORDER do
		local value = totals[field]
		if value ~= nil and value > 0 then
			count += 1
			local style = FIELD_STYLE[field]
			chips[field] = h("frame", {
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = darken(style.accent, 0.8),
				BorderSizePixel = 0,
				LayoutOrder = order,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}), h("textlabel", {
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = effectText(field, value),
				TextColor3 = lighten(style.accent, 0.2),
				TextSize = 12,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			}))
		end
	end
	if count == 0 then
		chips.Empty = h("textlabel", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = "Nothing bound yet. Pick a glowing node to start.",
			TextColor3 = Palette.muted,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		})
	end
	return h("frame", {
		Size = props.size,
		Position = props.position,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 30,
	}, chips)
end

local function DetailPanel(props)
	local node = props.node
	local softMotion = props.softMotion
	if node == nil then
		return h("frame", { Size = props.size, Position = props.position, BackgroundTransparency = 1 })
	end
	local field = fieldOf(node)
	local style = FIELD_STYLE[field]
	local owned = props.owned[node.Id] == true
	local prereqs = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local missing = 0
	for index, id in node.Requires or {} do
		local parent = LAYOUT.byId[id]
		local done = props.owned[id] == true
		if not done then
			missing += 1
		end
		prereqs[id] = h("frame", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if done then darken(Palette.mint, 0.78) else darken(Palette.coral, 0.8),
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}), h("textlabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = (if done then "✓ " else "✕ ") .. (if parent then parent.Name else id),
			TextColor3 = if done then Palette.mint else Palette.coral,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		}))
	end
	local points = props.points
	local available = missing == 0
	local canBind = not owned and available and points >= node.Cost and not props.busy
	local status = if owned then "Bound to your Domain." elseif missing > 0 then "Bind the linked branches first." elseif points < node.Cost then `Needs {node.Cost - points} more point{if node.Cost - points == 1 then "" else "s"}.` else `Costs {node.Cost} point{if node.Cost == 1 then "" else "s"}.`
	-- the tall side panel has room between the text and the button for the gem itself
	local width, height = props.size.X.Offset, props.size.Y.Offset
	local showTop = if #(node.Requires or {}) > 0 then 156 else 104
	local showH = height - (TapTarget + 44) - showTop
	local stage = math.min(showH, width - 24)
	local sheet = elementSheet(style.element)
	return h("frame", {
		Name = "DomainClaimActions",
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 30,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = style.accent,
		Transparency = 0.45,
	}), h("frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = darken(style.accent, 0.6),
		BorderSizePixel = 0,
		ZIndex = 31,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = style.accent,
		Transparency = 0.4,
	}), h(GemView, {
		kit = props.kit,
		field = field,
		accent = style.accent,
		owned = owned,
		available = available,
		softMotion = softMotion,
		size = UDim2.fromOffset(58, 58),
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 32,
	})), h(Text, {
		value = node.Name,
		size = 17,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(66, 12),
		sizeConstraint = UDim2.new(1, -78, 0, 22),
		zIndex = 31,
	}), h(Text, {
		value = effectText(field, tonumber(node[field]) or 0),
		size = 13,
		color = style.accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(66, 36),
		sizeConstraint = UDim2.new(1, -78, 0, 18),
		zIndex = 31,
	}), h(Text, {
		value = node.Description or "",
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(12, 64),
		sizeConstraint = UDim2.new(1, -24, 0, 32),
		zIndex = 31,
	}), #(node.Requires or {}) > 0 and h("frame", {
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.fromOffset(12, 98),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, prereqs), showH >= 150 and h("frame", {
		Name = "Showcase",
		Size = UDim2.fromOffset(width - 24, showH),
		Position = UDim2.fromOffset(12, showTop),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, h(ElementFx, {
		element = style.element,
		size = UDim2.fromOffset(stage, stage),
		position = UDim2.fromScale(0.5, 0.46),
		transparency = if owned then 0.08 elseif available then 0.45 else 0.75,
		still = not owned and not available,
		reducedMotion = softMotion,
		zIndex = 31,
	}), h(GemView, {
		kit = props.kit,
		field = field,
		accent = style.accent,
		owned = owned,
		available = available,
		softMotion = softMotion,
		size = UDim2.fromOffset(math.floor(stage * 0.78), math.floor(stage * 0.78)),
		position = UDim2.fromScale(0.5, 0.46),
		zIndex = 32,
	}), sheet ~= nil and h(Text, {
		value = `{sheet.Label} AFFINITY`,
		size = 11,
		color = if owned then sheet.Glow else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -16),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 33,
	})), h(Text, {
		value = status,
		size = 12,
		color = if owned then Palette.mint elseif canBind then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		position = UDim2.new(0, 12, 1, -(TapTarget + 34)),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
		zIndex = 31,
	}), h("frame", {
		Name = "DomainClaim",
		Size = UDim2.new(1, -24, 0, TapTarget),
		Position = UDim2.new(0, 12, 1, -(TapTarget + 12)),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 32,
	}, h(Button, {
		text = if owned then "BOUND" elseif props.busy then "BINDING…" else `BIND · {node.Cost}`,
		icon = if owned then "Check" else "Domain",
		onClick = props.onBind,
		color = if canBind then style.accent else Palette.panelSoft,
		textColor = if canBind then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		disabled = not canBind,
		highlight = canBind,
		reducedMotion = softMotion,
		zIndex = 33,
	})))
end

local function LatticeStage(props)
	local containerRef = React.useRef(nil)
	local bandRefHolder = React.useRef(nil)
	if bandRefHolder.current == nil then
		local refs = {}
		for band = 1, BANDS do
			refs[band] = React.createRef()
		end
		bandRefHolder.current = refs
	end
	local bandRefs = bandRefHolder.current
	local starsRef = React.useRef(nil)
	local sigilRef = React.useRef(nil)
	local focusHaloRef = React.useRef(nil)
	local view = React.useRef({
		yaw = 0,
		pitch = 0.12,
		targetYaw = 0,
		targetPitch = 0.12,
		zoom = 1,
		targetZoom = 1,
		idle = 0,
		drag = nil,
		segments = {},
		flows = {},
		cameras = {},
		stars = {},
		born = os.clock(),
		settled = false,
	})
	local softMotion = props.softMotion
	local registry = props.registry
	local kit = props.kit
	-- cameras + starfield, once
	React.useEffect(function()
		local state = view.current
		state.born = os.clock()
		for band = 1, BANDS do
			local viewport = bandRefs[band].current
			if viewport ~= nil then
				local camera = Instance.new("Camera")
				camera.FieldOfView = FOV
				camera.Parent = viewport
				viewport.CurrentCamera = camera
				state.cameras[band] = camera
			end
		end
		local random = Random.new(41)
		local field = starsRef.current
		if field ~= nil then
			for index = 1, if props.compact then 18 else 42 do
				local theta = random:NextNumber(0, math.pi * 2)
				local phi = math.acos(random:NextNumber(-0.7, 0.9))
				local dot = Instance.new("Frame")
				dot.Name = "Star" .. index
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				local px = random:NextInteger(1, 3)
				dot.Size = UDim2.fromOffset(px, px)
				dot.BackgroundColor3 = Color3.fromRGB(255, 240 - px * 10, 255)
				dot.BackgroundTransparency = 0.2 + random:NextNumber() * 0.5
				dot.BorderSizePixel = 0
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = dot
				dot.Parent = field
				table.insert(state.stars, {
					frame = dot,
					pos = Vector3.new(math.sin(phi) * math.sin(theta), math.cos(phi), math.sin(phi) * math.cos(theta)) * 34,
					base = dot.BackgroundTransparency,
					twinkle = random:NextNumber(0, math.pi * 2),
				})
			end
		end
		return function()
			for _, camera in state.cameras do
				camera:Destroy()
			end
			for _, star in state.stars do
				star.frame:Destroy()
			end
			table.clear(state.cameras)
			table.clear(state.stars)
		end
	end, {})
	-- branch geometry, rebuilt when ownership changes (or the gem kit arrives)
	React.useEffect(function()
		local state = view.current
		local holder = bandRefs[1].current
		if holder == nil then
			return nil
		end
		local segments, flows = {}, {}
		local function add(part)
			part.Parent = holder
			table.insert(segments, { part = part, mid = part.Position, band = 1 })
		end
		local owned = props.owned
		local spire = if kit ~= nil then kit:FindFirstChild("Domain_Spire") else nil
		local seed = if kit ~= nil then kit:FindFirstChild("Domain_Seed") else nil
		local height = SPACE.top - SPACE.bottom
		if spire ~= nil and spire:IsA("BasePart") then
			-- the trunk: one twisting crystal column with a neon vein running up its heart
			local trunk = spire:Clone()
			trunk.Size = Vector3.new(1.25, height + 0.8, 1.25)
			trunk.CFrame = CFrame.new(0, SPACE.bottom + (height + 0.8) / 2 - 0.2, 0)
			trunk.Color = Color3.fromRGB(104, 84, 160)
			trunk.Material = Enum.Material.SmoothPlastic
			trunk.Reflectance = 0.15
			trunk.Transparency = 0.2
			add(trunk)
			add(rod(Vector3.new(0, SPACE.bottom, 0), Vector3.new(0, SPACE.top + 0.1, 0), 0.16, Palette.pink, Enum.Material.Neon, 0.35))
		else
			local trunkColor = Color3.fromRGB(70, 58, 104)
			local trunkSteps = 6
			for step = 1, trunkSteps do
				local a = Vector3.new(0, SPACE.bottom + (step - 1) / trunkSteps * height, 0)
				local b = Vector3.new(0, SPACE.bottom + step / trunkSteps * height, 0)
				add(rod(a, b, 0.55 - step * 0.06, trunkColor:Lerp(Color3.fromRGB(140, 110, 200), step / trunkSteps), Enum.Material.Glass, 0.25))
			end
		end
		if seed ~= nil and seed:IsA("BasePart") then
			local root = seed:Clone()
			root.Size = Vector3.new(1.3, 1.3, 1.3)
			root.CFrame = CFrame.new(0, SPACE.bottom, 0)
			root.Color = Palette.pink
			root.Material = Enum.Material.Neon
			root.Transparency = 0.1
			add(root)
		else
			add(orb(Vector3.new(0, SPACE.bottom, 0), 1.1, Palette.pink, Enum.Material.Neon, 0.2))
		end
		if not props.compact then
			for tier = 0, 1 do
				local radius = 1.6 + tier * 0.6
				local y = SPACE.bottom + tier * 0.12
				local pieces = 18
				for piece = 1, pieces do
					local t0 = (piece - 1) / pieces * math.pi * 2
					local t1 = piece / pieces * math.pi * 2
					add(rod(Vector3.new(math.sin(t0) * radius, y, math.cos(t0) * radius), Vector3.new(math.sin(t1) * radius, y, math.cos(t1) * radius), 0.03, Palette.violet, Enum.Material.Neon, 0.82))
				end
			end
		end
		local function branch(a, b, accent, live, reachable, nodeId)
			local mid = (a + b) / 2
			local outward = Vector3.new(mid.X, 0, mid.Z)
			outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.new(0, 0, 1)
			local control = mid + outward * 0.7 + Vector3.new(0, 0.35, 0)
			local color = if live then accent elseif reachable then darken(accent, 0.35) else Color3.fromRGB(84, 80, 104)
			local material = if live then Enum.Material.Neon else Enum.Material.Glass
			local alpha = if live then 0.22 elseif reachable then 0.42 else 0.8
			local thickness = if live then 0.085 elseif reachable then 0.065 else 0.045
			local pieces = if props.compact then 5 else 8
			local previous = a
			for piece = 1, pieces do
				local point = bezier(a, control, b, piece / pieces)
				local segment = rod(previous, point, thickness, color, material, alpha)
				add(segment)
				segments[#segments].baseAlpha = alpha
				segments[#segments].nodeId = nodeId
				if piece < pieces then
					-- a bead on every joint hides the seam between the straight pieces
					add(orb(point, thickness * 1.05, color, material, alpha))
				end
				previous = point
			end
			if live and not softMotion then
				-- One restrained pulse per owned path avoids a trail over every node.
				local phase = (#flows * 0.37) % 1
				for k, spec in { { 0.16, 0.2 } } do
					local pulse = orb(a, spec[1], if k == 1 then Color3.new(1, 1, 1) else lighten(accent, 0.3), Enum.Material.Neon, spec[2])
					pulse.Parent = holder
					local entry = { part = pulse, mid = mid, band = 1 }
					table.insert(segments, entry)
					table.insert(flows, { entry = entry, a = a, c = control, b = b, phase = phase - (k - 1) * 0.035 })
				end
			end
		end
		for _, node in TREE do
			local point = SPACE.points[node.Id]
			if point == nil then
				continue
			end
			local accent = FIELD_STYLE[fieldOf(node)].accent
			local requires = node.Requires or {}
			if #requires == 0 then
				branch(Vector3.new(0, point.pos.Y - STEP_Y * 0.6, 0), point.pos, accent, owned[node.Id] == true, true, node.Id)
			end
			for _, parentId in requires do
				local parent = SPACE.points[parentId]
				if parent ~= nil then
					branch(parent.pos, point.pos, accent, owned[parentId] == true and owned[node.Id] == true, owned[parentId] == true, node.Id)
				end
			end
		end
		state.segments = segments
		state.flows = flows
		state.forceBands = true
		return function()
			for _, entry in segments do
				entry.part:Destroy()
			end
			if state.segments == segments then
				state.segments = {}
				state.flows = {}
			end
		end
	end, { props.ownedKey, props.compact, softMotion, kit })
	-- swing the selected node to face the camera
	React.useEffect(function()
		local selectedPath = {}
		local function visit(id)
			if selectedPath[id] then return end
			selectedPath[id] = true
			local node = LAYOUT.byId[id]
			for _, parentId in (node and node.Requires) or {} do visit(parentId) end
		end
		if props.focusId ~= nil then visit(props.focusId) end
		view.current.selectedPath = selectedPath
		view.current.focusId = props.focusId
		local point = SPACE.points[props.focusId]
		if point ~= nil then
			local state = view.current
			state.targetYaw = wrapAngle(math.clamp(point.angle * 0.12, -0.18, 0.18), state.yaw)
			state.idle = 0
		end
	end, { props.focusId })
	-- the render loop: orbit, band sorting, projection of DOM nodes onto the 3D positions
	React.useEffect(function()
		local state = view.current
		local inputChanged = UserInputService.InputChanged:Connect(function(input)
			local drag = state.drag
			if drag == nil then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - drag
				state.drag = input.Position
				state.targetYaw -= delta.X * 0.005
				state.targetPitch = math.clamp(state.targetPitch + delta.Y * 0.003, 0.02, 0.6)
				state.idle = 0
			end
		end)
		local inputEnded = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				state.drag = nil
			end
		end)
		-- Depth scalers are looked up once per anchor, not every frame
		local function depthScaleOf(anchor, button)
			local depthScale = anchor.depthScale
			if depthScale == nil or depthScale.Parent ~= button then
				depthScale = button:FindFirstChild("Depth")
				anchor.depthScale = depthScale
			end
			return depthScale
		end
		local loop = RunService.RenderStepped:Connect(function(dt)
			dt = math.min(dt, 0.1)
			local container = containerRef.current
			if container == nil then
				return
			end
			local size = container.AbsoluteSize
			local w, hgt = size.X, size.Y
			if w < 4 or hgt < 4 then
				return
			end
			local now = os.clock()
			local age = now - state.born
			state.idle += dt
			state.yaw = smoothDomainValue(state.yaw, state.targetYaw, dt, softMotion)
			state.pitch = smoothDomainValue(state.pitch, state.targetPitch, dt, softMotion)
			state.zoom = smoothDomainValue(state.zoom, state.targetZoom, dt, softMotion)
			local tanHalf = math.tan(math.rad(FOV / 2))
			local aspect = w / hgt
			local fitV = (SPACE.height / 2 + 0.9) / tanHalf
			local fitH = (SPACE.radius + 0.4) / (tanHalf * aspect)
			local distance = (math.max(fitV, fitH) + SPACE.depth + math.abs(math.sin(state.yaw)) * SPACE.radius) * state.zoom
			local focus = Vector3.new(0, (SPACE.top + SPACE.bottom) / 2, 0)
			local camCF = CFrame.new(focus) * CFrame.Angles(0, state.yaw, 0) * CFrame.Angles(-state.pitch, 0, 0) * CFrame.new(0, 0, distance)
			for _, camera in state.cameras do
				camera.CFrame = camCF
			end
			-- the 3D lattice fades up as the panel opens
			if not state.settled then
				local progress = math.clamp(age / 0.75, 0, 1)
				local fade = if softMotion then 0 else 1 - progress * progress * (3 - 2 * progress)
				for band = 1, BANDS do
					local viewport = bandRefs[band].current
					if viewport ~= nil then
						viewport.ImageTransparency = fade
					end
				end
				state.settled = fade <= 0
			end
			local focal = (hgt / 2) / tanHalf
			local zNear = distance - SPACE.radius - 1
			local zFar = distance + SPACE.radius + 1
			local span = math.max(0.01, zFar - zNear)
			local function bandOf(z)
				return math.clamp(BANDS - math.floor((z - zNear) / span * BANDS), 1, BANDS)
			end
			for _, flow in state.flows do
				local t = (now * 0.26 + flow.phase) % 1
				local position = bezier(flow.a, flow.c, flow.b, t)
				flow.entry.part.CFrame = CFrame.new(position)
				flow.entry.mid = position
			end
			for _, entry in state.segments do
				if entry.baseAlpha ~= nil then
					local focused = state.selectedPath and state.selectedPath[entry.nodeId]
					local target = if focused then entry.baseAlpha * 0.65 else math.min(0.9, entry.baseAlpha + 0.12)
					entry.part.Transparency = smoothDomainValue(entry.part.Transparency, target, dt, softMotion)
				end
				local z = -camCF:PointToObjectSpace(entry.mid).Z
				local band = bandOf(z)
				if band ~= entry.band or state.forceBands then
					entry.band = band
					local viewport = bandRefs[band].current
					if viewport ~= nil and entry.part.Parent ~= viewport then
						entry.part.Parent = viewport
					end
				end
			end
			state.forceBands = false
			for id, anchor in registry do
				local point = SPACE.points[id]
				local button = anchor.button
				if point == nil or button == nil then
					continue
				end
				local q = camCF:PointToObjectSpace(point.pos)
				local z = -q.Z
				if z < 0.1 then
					button.Visible = false
					continue
				end
				button.Visible = true
				button.Position = UDim2.fromOffset(w / 2 + q.X / z * focal, hgt / 2 - q.Y / z * focal + 8)
				local band = bandOf(z)
				button.ZIndex = if id == state.focusId then 3 + BANDS * 10 + 20 else 3 + (band - 1) * 10 + 6
				local depthScale = depthScaleOf(anchor, button)
				if depthScale then
					-- nodes pop in tier by tier, root first
					local progress = math.clamp((age - 0.08 - point.tier * 0.05) / 0.65, 0, 1)
					local grow = if softMotion then 1 else 0.85 + 0.15 * progress * progress * (3 - 2 * progress)
					depthScale.Scale = math.clamp(distance / z, 0.85, 1.12) * grow
				end
				if anchor.fog then
					anchor.fog.BackgroundTransparency = math.clamp(0.4 + (1 - (z - zNear) / span) * 0.9, 0.4, 1)
				end
				local gem = anchor.gem
				if gem ~= nil and not softMotion and #gem.spin > 0 then
					local frame = gemFrame(gem, now, anchor.speed, anchor.phase)
					for _, part in gem.spin do
						part.CFrame = frame
					end
				end
			end
			-- the root sigil lies flat under the seed, so it squashes as the camera levels out
			local sigil = sigilRef.current
			if sigil ~= nil then
				local q = camCF:PointToObjectSpace(Vector3.new(0, SPACE.bottom, 0))
				local z = -q.Z
				sigil.Visible = z > 0.1
				if z > 0.1 then
					local across = 5.4 / z * focal
					sigil.Position = UDim2.fromOffset(w / 2 + q.X / z * focal, hgt / 2 - q.Y / z * focal)
					sigil.Size = UDim2.fromOffset(across, across * math.clamp(math.sin(state.pitch + 0.14), 0.16, 0.9))
				end
			end
			local focusHalo = focusHaloRef.current
			local focusPoint = if state.focusId ~= nil then SPACE.points[state.focusId] else nil
			if focusHalo ~= nil then
				if focusPoint == nil then
					focusHalo.Visible = false
				else
					local q = camCF:PointToObjectSpace(focusPoint.pos)
					local z = -q.Z
					focusHalo.Visible = z > 0.1
					if z > 0.1 then
						local across = math.clamp(2.7 / z * focal, 54, 140)
						focusHalo.Position = UDim2.fromOffset(w / 2 + q.X / z * focal, hgt / 2 - q.Y / z * focal + 8)
						focusHalo.Size = UDim2.fromOffset(across, across)
						focusHalo.Rotation = if softMotion then 0 else now * 18
						focusHalo.BackgroundTransparency = math.clamp(0.9 + math.sin(now * 1.6) * 0.03, 0.84, 0.96)
					end
				end
			end
			for _, star in state.stars do
				local q = camCF.Rotation:PointToObjectSpace(star.pos)
				local z = -q.Z
				if z <= 0.5 then
					star.frame.Visible = false
				else
					star.frame.Visible = true
					star.frame.Position = UDim2.fromOffset(w / 2 + q.X / z * focal, hgt / 2 - q.Y / z * focal)
					if not softMotion then
						star.frame.BackgroundTransparency = math.clamp(star.base + math.sin(now * 0.7 + star.twinkle) * 0.1, 0, 0.95)
					end
				end
			end
		end)
		return function()
			inputChanged:Disconnect()
			inputEnded:Disconnect()
			loop:Disconnect()
		end
	end, { softMotion })
	local bands = {}
	for band = 1, BANDS do
		bands[`Band{band}`] = h("viewportframe", {
			ref = bandRefs[band],
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageTransparency = if softMotion then 0 else 1,
			Ambient = Color3.fromRGB(110, 96, 150),
			LightColor = Color3.fromRGB(255, 236, 250),
			LightDirection = Vector3.new(-0.5, -1, -0.35),
			ZIndex = 3 + (band - 1) * 10,
		})
	end
	return h("frame", {
		ref = function(container)
			containerRef.current = container
			if container ~= nil then
				container:SetAttribute("LayoutGuardIgnore", true)
				container:SetAttribute("NoMotion", true)
			end
		end,
		Name = "LatticeStage",
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = darken(Palette.void, 0.02),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uigradient", {
		Color = ColorSequence.new(darken(Palette.violet, 0.92), Palette.void),
		Rotation = 90,
	}), h("frame", {
		Name = "NebulaA",
		Size = UDim2.fromScale(1.2, 0.7),
		Position = UDim2.fromScale(-0.08, -0.04),
		BackgroundColor3 = Palette.violet,
		BackgroundTransparency = if softMotion then 0.93 else 0.88,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, h("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), h("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, darken(Palette.violet, 0.3)),
			ColorSequenceKeypoint.new(0.52, lighten(Palette.pink, 0.08)),
			ColorSequenceKeypoint.new(1, darken(Palette.cyan, 0.28)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.28, 0.55),
			NumberSequenceKeypoint.new(0.52, 0.14),
			NumberSequenceKeypoint.new(0.78, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 18,
	})), h("frame", {
		Name = "NebulaB",
		Size = UDim2.fromScale(1.0, 0.58),
		Position = UDim2.fromScale(0.18, 0.72),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = if softMotion then 0.95 else 0.9,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, h("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), h("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, darken(Palette.cyan, 0.26)),
			ColorSequenceKeypoint.new(0.48, lighten(Palette.cyan, 0.18)),
			ColorSequenceKeypoint.new(1, darken(Palette.violet, 0.28)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.62),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(0.78, 0.68),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = -12,
	})), h(ElementFx, {
		element = "Cosmic",
		size = UDim2.fromScale(0.92, 0.92),
		position = UDim2.fromScale(0.2, 0.26),
		anchorPoint = Vector2.new(0.5, 0.5),
		transparency = if softMotion then 0.92 else 0.86,
		scaleType = Enum.ScaleType.Stretch,
		framerate = 10,
		reducedMotion = softMotion,
		zIndex = 1,
	}), h(ElementFx, {
		element = "Prism",
		size = UDim2.fromScale(0.72, 0.72),
		position = UDim2.fromScale(0.82, 0.72),
		anchorPoint = Vector2.new(0.5, 0.5),
		transparency = if softMotion then 0.95 else 0.9,
		scaleType = Enum.ScaleType.Stretch,
		framerate = 8,
		reducedMotion = softMotion,
		zIndex = 1,
	}), h("frame", {
		Name = "Stars",
		ref = starsRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}), h("frame", {
		-- a rune circle turning under the seed of the lattice
		Name = "RootSigil",
		ref = sigilRef,
		Size = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, h(ElementFx, {
		element = "Arcane",
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		transparency = 0.7,
		framerate = 10,
		scaleType = Enum.ScaleType.Stretch,
		reducedMotion = softMotion,
		zIndex = 2,
	})), h("frame", {
		Name = "FocusHalo",
		ref = focusHaloRef,
		Visible = false,
		Size = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 25,
	}, h("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), h("uistroke", {
		Color = lighten(Palette.cyan, 0.2),
		Thickness = 2,
		Transparency = 0.18,
	}), h(ElementFx, {
		element = "Arcane",
		size = UDim2.fromScale(1.08, 1.08),
		position = UDim2.fromScale(0.5, 0.5),
		transparency = 0.38,
		framerate = 18,
		reducedMotion = softMotion,
		zIndex = 26,
	}), h(ElementFx, {
		element = "Radiance",
		size = UDim2.fromScale(1.34, 1.34),
		position = UDim2.fromScale(0.5, 0.5),
		transparency = 0.66,
		framerate = 12,
		reducedMotion = softMotion,
		zIndex = 25,
	})), h("textbutton", {
		Name = "Orbit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 2,
		Event = {
			InputBegan = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					view.current.drag = input.Position
					view.current.idle = 0
				end
			end,
			InputChanged = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseWheel then
					local state = view.current
					state.targetZoom = math.clamp(state.targetZoom - input.Position.Z * 0.08, 0.62, 1.5)
					state.idle = 0
				end
			end,
		},
	}), bands, props.children, h("frame", {
		Name = "ViewControls",
		Size = UDim2.fromOffset(TapTarget * 3 + 12, TapTarget),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 80,
	}, h("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}), h(Button, {
		text = "-", layoutOrder = 1,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		color = Palette.panelSoft, reducedMotion = softMotion,
		onClick = function() view.current.targetZoom = math.min(1.5, view.current.targetZoom + 0.12) end,
	}), h(Button, {
		text = "+", layoutOrder = 2,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		color = Palette.panelSoft, reducedMotion = softMotion,
		onClick = function() view.current.targetZoom = math.max(0.62, view.current.targetZoom - 0.12) end,
	}), h(Button, {
		text = "FIT", layoutOrder = 3,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		color = Palette.panelSoft, reducedMotion = softMotion,
		onClick = function()
			local state = view.current
			state.targetYaw = wrapAngle(0, state.yaw)
			state.targetPitch = 0.12
			state.targetZoom = 1
			state.drag = nil
		end,
	})), h(Text, {
		value = if props.compact then "Drag to orbit / + - zoom / FIT reset" else "Drag to orbit / scroll to zoom / select a node to inspect",
		size = 11,
		color = Palette.muted,
		position = UDim2.new(0, 12, 1, -22),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
		zIndex = 80,
	}))
end

local function DomainSkillTree(_param)
	local domain = _param.domain
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	-- the host passes no preference, so honour the player's motion setting from context
	local softMotion = reducedMotion or useMotionSettings().soft == true
	local onClose = _param.onClose
	local kit = useDomainKit()
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack or viewport.width < 760
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion, 0.28)
	local leave = _binding[1]
	local leaving = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local hostRef = React.useRef(nil)
	local hostSize = useGuiSize(hostRef)
	local alive = React.useRef(true)
	local nodes = domain.Nodes or {}
	local owned = {}
	for id, value in nodes do
		if value == true then
			owned[id] = true
		end
	end
	local points = math.max(0, math.floor(tonumber(domain.SkillPoints) or 0))
	local function availableFor(node)
		for _, id in node.Requires or {} do
			if not owned[id] then
				return false
			end
		end
		return true
	end
	local firstReady = nil
	for _, node in TREE do
		if firstReady == nil and not owned[node.Id] and availableFor(node) then
			firstReady = node.Id
		end
	end
	local selectedId, setSelectedId = React.useState(firstReady or (TREE[1] and TREE[1].Id))
	local busy, setBusy = React.useState(false)
	local boundId, setBoundId = React.useState(nil)
	local boundToken, setBoundToken = React.useState(0)
	local boundCount = 0
	for _, node in TREE do
		if owned[node.Id] then
			boundCount += 1
		end
	end
	React.useEffect(function()
		alive.current = true
		Audio:play("domainCrack")
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			alive.current = false
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, {})
	local close = function()
		if leaving then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end
	React.useEffect(function()
		local actionName = "AstralForgeLatticeClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			ContextActionService:UnbindAction(actionName)
		end
	end, { leaving })
	local selected = LAYOUT.byId[selectedId]
	local bind = function()
		if selected == nil or busy or owned[selected.Id] or not availableFor(selected) or points < selected.Cost then
			return
		end
		setBusy(true)
		Audio:play("domainImpact")
		local id = selected.Id
		dispatch("UnlockDomainNode", { Id = id }, function(response)
			if not alive.current then
				return
			end
			setBusy(false)
			if type(response) == "table" and response.ok then
				Audio:play("domainBind")
				Audio:play("domainReward")
				InteractionFeedback.reward()
				setBoundId(id)
				setBoundToken(function(n)
					return n + 1
				end)
			else
				Audio:play("locked")
			end
		end)
	end

	local side = math.max(10, chrome.sideSafe + 8)
	local panelW = math.min(viewport.width - side * 2, 1180)
	local panelH = math.min(viewport.height - math.max(16, viewport.topInset + 10) - math.max(16, viewport.bottomInset + 10), 760)
	local headerH = 64
	local totalsH = if stack then 56 else 34
	local detailW = if stack then panelW - 24 else 300
	local detailH = if stack then 210 else panelH - headerH - totalsH - 40
	local canvasW = if stack then panelW - 24 else panelW - detailW - 36
	local canvasViewH = if stack then panelH - headerH - totalsH - detailH - 40 else panelH - headerH - totalsH - 40
	local nodeSize = math.clamp(math.floor(math.min(canvasW, canvasViewH) / 9), 40, 56)
	local registry = React.useRef({}).current
	local ownedKeyParts = {}
	for _, node in TREE do
		if owned[node.Id] then
			table.insert(ownedKeyParts, node.Id)
		end
	end
	local gems = {}
	for _, node in TREE do
		gems[node.Id] = h(NodeButton, {
			node = node,
			center = Vector2.new(canvasW / 2, canvasViewH / 2),
			size = nodeSize,
			owned = owned[node.Id] == true,
			available = availableFor(node),
			affordable = points >= node.Cost,
			selected = selectedId == node.Id,
			bound = boundId == node.Id,
			boundToken = boundToken,
			softMotion = softMotion,
			registry = registry,
			kit = kit,
			onSelect = function()
				setSelectedId(node.Id)
			end,
			onFocus = function()
				setSelectedId(node.Id)
			end,
		})
	end
	local canvasHost = h(LatticeStage, {
		size = UDim2.fromOffset(canvasW, canvasViewH),
		position = UDim2.fromOffset(12, headerH + 8),
		owned = owned,
		ownedKey = table.concat(ownedKeyParts, ","),
		focusId = selectedId,
		registry = registry,
		compact = stack,
		softMotion = softMotion,
		kit = kit,
	}, gems)
	local nextPoints = GameConfig.Domain.SkillPointPerRank or 2
	return h(OverlayPresence, {
		amount = motion,
	}, h("frame", {
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 700,
		ClipsDescendants = true,
		Visible = motion:map(function(a)
			return a > 0.003
		end),
	}, h("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = motion:map(function(a)
			return 1 - a * 0.6
		end),
		AutoButtonColor = false,
		Selectable = false,
		Active = true,
		ZIndex = 700,
	}), h("frame", {
		Size = UDim2.fromOffset(panelW, panelH),
		Position = React.joinBindings({ motion, hostSize }):map(function(values)
			return pixelPosition(values[2], 0.5, 0, 0.5, (1 - values[1]) * 22)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 701,
	}, h("uicorner", { CornerRadius = UDim.new(0, 18) }), h("uistroke", {
		Color = Palette.pink,
		Thickness = 2,
		Transparency = 0.3,
	}), h("uigradient", {
		Color = ColorSequence.new(darken(Palette.violet, 0.8), Palette.night),
		Rotation = 90,
	}), h("frame", {
		Name = "Header",
		Size = UDim2.new(1, -24, 0, headerH - 8),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		ZIndex = 710,
	}, h("frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = darken(Palette.pink, 0.55),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = Palette.pink,
	}), h(Text, {
		value = `{domain.Rank or 0}`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})), h(Text, {
		value = "DOMAIN TREE",
		size = 11,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(56, 6),
		sizeConstraint = UDim2.new(1, -(56 + 96 + TapTarget + 22), 0, 14),
	}), h(Text, {
		value = if stack then `{boundCount}/{#TREE} bound` else `{boundCount} of {#TREE} bound  ·  +{nextPoints} points every expansion`,
		size = if stack then 13 else 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(56, 22),
		sizeConstraint = UDim2.new(1, -(56 + 96 + TapTarget + 22), 0, 22),
	}), h("frame", {
		Size = UDim2.fromOffset(96, 46),
		Position = UDim2.new(1, -(96 + TapTarget + 10), 0, 4),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
		Color = Palette.mango,
		Transparency = 0.35,
	}), h(Text, {
		value = `{points}`,
		size = 20,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 2),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
	}), h(Text, {
		value = "POINTS",
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 27),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})), h(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -TapTarget, 0, 5),
		reducedMotion = softMotion,
	})), canvasHost, h(TotalsStrip, {
		owned = owned,
		size = UDim2.new(0, canvasW, 0, totalsH),
		position = UDim2.fromOffset(12, headerH + 14 + canvasViewH),
	}), h(DetailPanel, {
		node = selected,
		owned = owned,
		points = points,
		busy = busy,
		softMotion = softMotion,
		kit = kit,
		onBind = bind,
		size = UDim2.fromOffset(detailW, detailH),
		position = if stack then UDim2.new(0, 12, 1, -(detailH + 12)) else UDim2.fromOffset(panelW - detailW - 12, headerH + 8),
	}))))
end

return {
	DomainSkillTree = DomainSkillTree,
}
end

__defs["purchaseOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useBoatTween = _motion.useBoatTween
local useClock = _motion.useClock
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local PURCHASE_RESULT_HOLD = 2.2
local PURCHASE_RESULT_HOLD_REDUCED = 1.65
local PURCHASE_PENDING_FAILSAFE = 45
local DOT_COLORS = { Palette.mango, Palette.cyan, Palette.mint }
local function ForgeDot(_param)
	local index = _param.index
	local clock = _param.clock
	local morph = _param.morph
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local color = DOT_COLORS[index + 1]
	local x = (index - 1) * 26
	local position = React.joinBindings({ clock, morph }):map(function(values)
		local wave = if reducedMotion then 0 else math.pow((math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.5, 1.6)
		return UDim2.new(0.5, math.round(x * (1 - values[2])), 0.5, math.round(9 - wave * 18))
	end)
	local scale = React.joinBindings({ clock, morph }):map(function(values)
		local pulse = if reducedMotion then 1 else 0.82 + (math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.13
		return math.max(0.05, pulse * (1 - values[2]))
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 414,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = morph:map(function(amount)
			return math.clamp(amount * 1.2, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement("frame", {
		Size = UDim2.new(1.35, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(color, 0.28),
		BackgroundTransparency = 0.54,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function ResultGlyph(_param)
	local phase = _param.phase
	local amount = _param.amount
	local accent = _param.accent
	local kind = if phase == "success" then "Check" else "Close"
	return React.createElement("frame", {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement(ScaleFromCenter, {
		scale = amount:map(function(value)
			return 0.24 + value * 0.76
		end),
		zIndex = 415,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(accent, 0.78),
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.22
		end),
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = amount:map(function(value)
			return 1 - value * 0.92
		end),
	}), React.createElement(Icon, {
		kind = kind,
		color = Palette.cream,
		accent = accent,
		size = 54,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))))
end
local function PurchaseOverlay(_param)
	local phase = _param.phase
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local detail = _param.detail
	local onDismiss = _param.onDismiss
	local visible = phase ~= "hidden"
	local result = phase == "success" or phase == "fail"
	local show = useBoatTween(if visible then 1 else 0, if visible then 0.25 else 0.18, softMotion, easeOutCubic, 0)
	local card = useBoatTween(if visible then 1 else 0, if visible then 0.34 else 0.15, softMotion, easeOutBack, 0)
	local _binding = useExitTransition(softMotion, 0.32, phase == "hidden")
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local morph = useFlipperSpring(if result then 1 else 0, softMotion, 500, 30)
	local clock = useClock(phase == "pending" and not reducedMotion, 1.4, 1)
	local viewport = useViewport()
	local nonce, setNonce = React.useState(0)
	local dismissRef = React.useRef(onDismiss)
	local dismissStarted = React.useRef(false)
	local overlayHostRef = React.useRef(nil)
	dismissRef.current = onDismiss
	local previousPhase = React.useRef("hidden")
	React.useEffect(function()
		if phase == previousPhase.current then
			return nil
		end
		previousPhase.current = phase
		if phase == "success" then
			Audio:play("purchaseResult")
		elseif phase == "fail" then
			Audio:play("error")
		end
	end, { phase })
	React.useEffect(function()
		if result then
			setNonce(function(value)
				return value + 1
			end)
		end
	end, { phase, result })
	local flash = useFlash(nonce, reducedMotion, if phase == "fail" then 0.62 else 0.48)
	local dismiss = React.useCallback(function()
		if not result or exiting or dismissStarted.current then
			return nil
		end
		dismissStarted.current = true
		Audio:play("purchaseExit")
		beginExit(function()
			local _result = dismissRef.current
			if _result ~= nil then
				_result = _result()
			end
			return _result
		end)
	end, { beginExit, exiting, result })
	React.useEffect(function()
		if phase == "pending" or phase == "hidden" then
			dismissStarted.current = false
		end
	end, { phase })
	React.useEffect(function()
		if not result then
			return nil
		end
		local alive = true
		local worker = task.delay(if reducedMotion then PURCHASE_RESULT_HOLD_REDUCED else PURCHASE_RESULT_HOLD, function()
			if alive then
				dismiss()
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { dismiss, phase, reducedMotion, result })
	React.useEffect(function()
		if phase == "hidden" then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase })
	React.useEffect(function()
		if not result or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current
		if host == nil then
			return nil
		end
		local alive = true
		local selectJob = task.defer(function()
			if not alive or host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			alive = false
			pcall(task.cancel, selectJob)
		end
	end, { phase, result })
	local accent = if phase == "fail" then Palette.coral elseif phase == "success" then Palette.mint else Palette.mango
	local title = if phase == "pending" then "BUYING..." elseif phase == "success" then "BOUGHT" else "COULDN'T BUY"
	local _result
	if phase == "pending" then
		_result = "Waiting on Roblox checkout"
	else
		local _result_1
		if phase == "success" then
			_result_1 = "It's in your account now"
		else
			local _condition = detail
			if _condition == nil then
				_condition = "You weren't charged"
			end
			_result_1 = _condition
		end
		_result = _result_1
	end
	local detailText = _result
	local shortLandscape = viewport.height < 430 and viewport.width > viewport.height * 1.14
	local sideSafe = math.max(viewport.sideInset, 8)
	local topSafe = math.max(viewport.topInset, 8)
	local bottomSafe = math.max(viewport.bottomInset, 8)
	local safeHeight = math.max(184, viewport.height - topSafe - bottomSafe)
	local availableWidth = math.max(280, viewport.width - (sideSafe + 12) * 2)
	local cardWidth = math.min(if shortLandscape then 540 else 430, availableWidth)
	local cardHeight = if shortLandscape then math.clamp(safeHeight - 16, 184, 218) else math.clamp(safeHeight - 20, 232, 272)
	local compactVertical = not shortLandscape and cardHeight < 260
	local presence = React.joinBindings({ show, card, exitAmount }):map(function(values)
		return math.min(values[1], values[2], values[3])
	end)
	local cardTravel = 22
	local cardPosition = presence:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.floor((1 - amount) * cardTravel))
	end)
	local cardScale = React.joinBindings({ presence, flash }):map(function(values)
		return 0.94 + math.clamp(values[1], 0, 1) * 0.06 + values[2] * 0.025
	end)
	local orbSize = if shortLandscape then math.min(106, cardHeight - 32) elseif compactVertical then 104 else 118
	local orbPosition = if shortLandscape then UDim2.fromOffset(20, math.floor(cardHeight * 0.5)) else UDim2.new(0.5, 0, 0, 24)
	local orbAnchor = if shortLandscape then Vector2.new(0, 0.5) else Vector2.new(0.5, 0)
	local copyLeft = if shortLandscape then orbSize + 42 else 18
	local copyWidth = if shortLandscape then -(copyLeft + 20) else -36
	local titleY = if shortLandscape then math.max(28, math.floor(cardHeight * 0.5) - 44) else orbSize + (if compactVertical then 32 else 40)
	local detailY = titleY + (if shortLandscape then 28 else 24)
	local railLeft = if shortLandscape then copyLeft else 26
	local railBottom = if shortLandscape then 28 elseif compactVertical then 29 else 38
	local _exp = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = presence:map(function(amount)
			return 1 - amount * 0.68
		end),
		BorderSizePixel = 0,
		ZIndex = 400,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Name = "PurchaseDismissBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Active = visible and not exiting,
		Selectable = false,
		Modal = visible,
		ZIndex = 401,
		Event = {
			Activated = function()
				if result and not exiting then
					dismiss()
				end
			end,
		},
	})
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 4),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		ZIndex = 405,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}))
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	})
	local _exp_4 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.62),
		Rotation = 90,
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = presence:map(function(amount)
			return 1 - amount * 0.8
		end),
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0.56, 0, 0, 3),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 407,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_7 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_8 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.5,
	})
	local _exp_9 = { 0, 1, 2 }
	local _newValue = table.create(#_exp_9)
	local _callback = function(index)
		return React.createElement(ForgeDot, {
			key = index,
			index = index,
			clock = clock,
			morph = morph,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_9 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_9)
	end
	local content = React.createElement(OverlayPresence, {
		amount = presence,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
		Active = presence:map(function(amount)
			return amount > 0.02 and not exiting
		end),
		Visible = presence:map(function(amount)
			return amount > 0.005
		end),
		ClipsDescendants = false,
		Event = {
			InputBegan = function(_frame, input)
				if result and not exiting and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dismiss()
				end
			end,
		},
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		ClipsDescendants = false,
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 405,
	}, _exp_2, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 406,
	}, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromOffset(orbSize, orbSize),
		Position = orbPosition,
		AnchorPoint = orbAnchor,
		BackgroundColor3 = darken(accent, 0.86),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, _exp_7, _exp_8, _newValue, phase == "success" and React.createElement(ResultGlyph, {
		phase = "success",
		amount = morph,
		accent = accent,
	}), phase == "fail" and React.createElement(ResultGlyph, {
		phase = "fail",
		amount = morph,
		accent = accent,
	})), React.createElement(Text, {
		value = title,
		size = if shortLandscape then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(copyLeft, titleY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 26),
		zIndex = 410,
	}), React.createElement(Text, {
		value = detailText,
		size = 11,
		color = Palette.creamSoft,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(copyLeft, detailY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 28),
		zIndex = 410,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(railLeft + (if shortLandscape then 20 else 26)), 0, 3),
		Position = UDim2.new(0, railLeft, 1, -railBottom),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 409,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = if phase == "pending" then clock:map(function(time)
			return UDim2.new(0.22, 0, 1, 0)
		end) else UDim2.fromScale(1, 1),
		Position = if phase == "pending" then clock:map(function(time)
			return UDim2.new((time * 1.25) % 1, 0, 0, 0)
		end) else UDim2.fromScale(0, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, accent),
	}))), result and React.createElement("frame", {
		Name = "PurchaseContinue",
		Size = UDim2.new(1, -(copyLeft + (if shortLandscape then 20 else 26)), 0, 36),
		Position = UDim2.new(0, copyLeft, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 412,
	}, React.createElement(Button, {
		text = "CONTINUE",
		onClick = dismiss,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
		selectable = true,
		zIndex = 412,
	})))))))
	return React.createElement("frame", {
		ref = overlayHostRef,
		Name = "PurchaseOverlayHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
	}, content)
end
return {
	PurchaseOverlay = PurchaseOverlay,
	PURCHASE_RESULT_HOLD = PURCHASE_RESULT_HOLD,
	PURCHASE_RESULT_HOLD_REDUCED = PURCHASE_RESULT_HOLD_REDUCED,
	PURCHASE_PENDING_FAILSAFE = PURCHASE_PENDING_FAILSAFE,
}
end

__defs["MobileControls"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _motion = require(script.Parent.MotionKit)("motion")
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local EDIT_BOUNDS = require(script.Parent.CoreKit)("mobileLayout").EDIT_BOUNDS
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local Text = _ui.Text
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Audio = require(script.Parent.AudioKit)("audio").Audio
local dragHandles = {}
local editMode = false
local dragId
local dragInput
local dragOffset = Vector2.zero
local dragLastCell = Vector2.zero
local dragChanged
local dragEnded
local dragFocusReleased
local dragMenuOpened
local function cancelDrag()
	dragId = nil
	dragInput = nil
end
local function clampDrag(pos, bounds)
	return Vector2.new(math.clamp(pos.X, bounds.minX, bounds.maxX), math.clamp(pos.Y, bounds.minY, bounds.maxY))
end
local function ensureDragging()
	if dragChanged ~= nil then
		return nil
	end
	dragChanged = UserInputService.InputChanged:Connect(function(input)
		if not editMode or dragId == nil or dragInput == nil then
			return nil
		end
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= dragInput then
				return nil
			end
		elseif dragInput.UserInputType == Enum.UserInputType.MouseButton1 then
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return nil
			end
		else
			return nil
		end
		local _dragId = dragId
		local handle = dragHandles[_dragId]
		if handle == nil then
			return nil
		end
		local raw = Vector2.new(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		local cellX = math.round(raw.X / grid)
		local cellY = math.round(raw.Y / grid)
		local resolvedPosition = clampDrag(Vector2.new(cellX * grid, cellY * grid), handle.bounds)
		handle.position = resolvedPosition
		local _result = handle.onMove
		if _result ~= nil then
			_result(resolvedPosition)
		end
		if cellX ~= dragLastCell.X or cellY ~= dragLastCell.Y then
			dragLastCell = Vector2.new(cellX, cellY)
			Audio:play("dragSnap")
		end
	end)
	dragEnded = UserInputService.InputEnded:Connect(function(input)
		if dragInput == nil then
			return nil
		end
		local exactTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
		local mouseRelease = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
		if exactTouch or mouseRelease then
			if dragId ~= nil then
				Audio:play("dragDrop")
			end
			cancelDrag()
		end
	end)
	dragFocusReleased = UserInputService.WindowFocusReleased:Connect(cancelDrag)
	dragMenuOpened = GuiService.MenuOpened:Connect(cancelDrag)
end
local MobileDragging = {
	setEditMode = function(self, on)
		editMode = on
		if not on then
			cancelDrag()
		end
		ensureDragging()
	end,
	register = function(self, handle)
		ensureDragging()
		local _id = handle.id
		local _handle = handle
		dragHandles[_id] = _handle
		return function()
			local _id_1 = handle.id
			dragHandles[_id_1] = nil
			if dragId == handle.id then
				cancelDrag()
			end
		end
	end,
	beginDrag = function(self, id, input)
		if not editMode then
			return nil
		end
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		Audio:play("dragGrab")
		dragId = id
		dragInput = input
		dragOffset = Vector2.new(input.Position.X - handle.position.X, input.Position.Y - handle.position.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		dragLastCell = Vector2.new(math.round(handle.position.X / grid), math.round(handle.position.Y / grid))
	end,
	setPosition = function(self, id, pos)
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		handle.position = clampDrag(pos, handle.bounds)
		local _result = handle.onMove
		if _result ~= nil then
			_result(handle.position)
		end
	end,
	dispose = function(self)
		local _result = dragChanged
		if _result ~= nil then
			_result:Disconnect()
		end
		local _result_1 = dragEnded
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		local _result_2 = dragFocusReleased
		if _result_2 ~= nil then
			_result_2:Disconnect()
		end
		local _result_3 = dragMenuOpened
		if _result_3 ~= nil then
			_result_3:Disconnect()
		end
		dragChanged = nil
		dragEnded = nil
		dragFocusReleased = nil
		dragMenuOpened = nil
		table.clear(dragHandles)
		cancelDrag()
		editMode = false
	end,
}
local function slotPixels(slot, width, height)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local _exp = slot.x * width
	local _condition_2 = slot.anchorX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local _exp_1 = _exp - slotW * _condition_2
	local _exp_2 = slot.y * height
	local _condition_3 = slot.anchorY
	if _condition_3 == nil then
		_condition_3 = 0.5
	end
	return Vector2.new(_exp_1, _exp_2 - slotH * _condition_3)
end
local function slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local minX = math.max(8, sideInset + 8)
	local _exp = topInset + 8
	local _condition_2 = slot.safeTop
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local minY = math.max(48, _exp, _condition_2)
	return {
		minX = minX,
		maxX = math.max(minX, width - sideInset - slotW - 8),
		minY = minY,
		maxY = math.max(minY, height - bottomInset - slotH - 8),
	}
end
local function safeSlotPosition(slot, position, width, height, sideInset, topInset, bottomInset)
	local bounds = slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	return Vector2.new(math.clamp(position.X, bounds.minX, bounds.maxX), math.clamp(position.Y, bounds.minY, bounds.maxY))
end
-- Session-scoped layout memory; fractions so a stored layout survives rotation.
local MOBILE_LAYOUT_MEMORY = {}
local function MobileControls(_param)
	local slots = _param.slots
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visible = _param.visible
	local onClose = _param.onClose
	local scales = _param.scales
	local opacities = _param.opacities
	local viewport = useViewport()
	local editing, setEditing = React.useState(false)
	local snap, setSnap = React.useState(true)
	local snapStep, setSnapStep = React.useState(16)
	local fine, setFine = React.useState(false)
	local showThirds, setShowThirds = React.useState(false)
	local selectedId, setSelectedId = React.useState()
	local locked, setLocked = React.useState({})
	local history, setHistory = React.useState({})
	local redo, setRedo = React.useState({})
	local positions, setPositions = React.useState({})
	local memoryIndex, setMemoryIndex = React.useState(1)
	local memoryRevision, setMemoryRevision = React.useState(0)
	local _binding = useExitTransition(reducedMotion, 0.38, visible)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local requestClose = React.useCallback(function()
		if not exiting then
			beginExit(onClose)
		end
	end, { beginExit, exiting, onClose })
	local screen = React.useState(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local vrScreen = playerGui:FindFirstChild("AstralForgeVR")
		if vrScreen and vrScreen.Enabled then return vrScreen:FindFirstChild("Overlay") end
		local rootScreen = playerGui:FindFirstChild("AstralForgeStudioUI")
		return if rootScreen ~= nil and rootScreen:IsA("ScreenGui") then rootScreen else playerGui
	end)
	local positionsRef = React.useRef(positions)
	positionsRef.current = positions
	React.useEffect(function()
		return function()
			MobileDragging:dispose()
		end
	end, {})
	React.useEffect(function()
		if not visible then
			return nil
		end
		local initialPositions = {}
		for _, slot in slots do
			initialPositions[slot.id] = safeSlotPosition(slot, slotPixels(slot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		positionsRef.current = initialPositions
		setPositions(initialPositions)
	end, { slots, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		if not visible then
			MobileDragging:setEditMode(false)
			setEditing(false)
			return nil
		end
		local cleanups = {}
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local corrected = _object
		local correctedAny = false
		for _, slot in slots do
			local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local raw = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local position = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			if position.X ~= raw.X or position.Y ~= raw.Y then
				corrected[slot.id] = position
				correctedAny = true
			end
			local _arg0 = MobileDragging:register({
				id = slot.id,
				position = position,
				bounds = bounds,
				snap = if snap then snapStep else 1,
				onMove = function(nextPosition)
					return setPositions(function(current)
						local _object_1 = table.clone(current)
						setmetatable(_object_1, nil)
						_object_1[slot.id] = nextPosition
						return _object_1
					end)
				end,
			})
			table.insert(cleanups, _arg0)
		end
		if correctedAny then
			positionsRef.current = corrected
			setPositions(corrected)
		end
		return function()
			for _, dispose in cleanups do
				dispose()
			end
		end
	end, { slots, snap, snapStep, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		MobileDragging:setEditMode(editing and visible)
		return function()
			return MobileDragging:setEditMode(false)
		end
	end, { editing, visible })
	local layoutOverlaps = function(source)
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			local pos = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			do
				local otherIndex = index + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						otherIndex += 1
					else
						_shouldIncrement = true
					end
					if not (otherIndex < #slots) then
						break
					end
					local other = slots[otherIndex + 1]
					local otherPos = source[other.id] or slotPixels(other, viewport.width, viewport.height)
					local _condition_2 = other.width
					if _condition_2 == nil then
						_condition_2 = 112
					end
					local otherWidth = _condition_2
					local _condition_3 = other.height
					if _condition_3 == nil then
						_condition_3 = 62
					end
					local otherHeight = _condition_3
					local separated = pos.X + width + 6 <= otherPos.X or otherPos.X + otherWidth + 6 <= pos.X or pos.Y + height + 6 <= otherPos.Y or otherPos.Y + otherHeight + 6 <= pos.Y
					if not separated then
						return true
					end
				end
			end
		end
		return false
	end
	local save = function(source)
		if source == nil then
			source = positionsRef.current
		end
		if layoutOverlaps(source) then
			return false
		end
		local values = {}
		for _, slot in slots do
			local raw = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local pos = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local slotW = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local slotH = _condition_1
			local _exp = pos.X
			local _condition_2 = slot.anchorX
			if _condition_2 == nil then
				_condition_2 = 0.5
			end
			values[slot.xKey] = math.clamp((_exp + slotW * _condition_2) / viewport.width, 0, 1)
			local _exp_1 = pos.Y
			local _condition_3 = slot.anchorY
			if _condition_3 == nil then
				_condition_3 = 0.5
			end
			values[slot.yKey] = math.clamp((_exp_1 + slotH * _condition_3) / viewport.height, 0, 1)
		end
		dispatch("SetMobileLayout", {
			Values = values,
		})
		return true
	end
	local finishEditing = function()
		if not save() then
			return false
		end
		setEditing(false)
		return true
	end
	local capStack = function(source, extra)
		local _array = {}
		local _length = #_array
		table.move(source, 1, #source, _length + 1, _array)
		local nextHist = _array
		local _object = table.clone(extra)
		setmetatable(_object, nil)
		table.insert(nextHist, _object)
		if #nextHist <= 12 then
			return nextHist
		end
		local trimmed = {}
		for index = #nextHist - 12, #nextHist - 1 do
			local _arg0 = nextHist[index + 1]
			table.insert(trimmed, _arg0)
		end
		return trimmed
	end
	local applyPositions = function(nextPos)
		positionsRef.current = nextPos
		setPositions(nextPos)
		for _, slot in slots do
			local pos = nextPos[slot.id]
			if pos ~= nil then
				MobileDragging:setPosition(slot.id, pos)
			end
		end
	end
	local pushHistory = function(source)
		setHistory(function(current)
			return capStack(current, source)
		end)
		setRedo({})
	end
	local undoLayout = function()
		if #history == 0 then
			return nil
		end
		local prior = history[#history]
		if prior == nil then
			return nil
		end
		setRedo(function(current)
			return capStack(current, positionsRef.current)
		end)
		setHistory(function(current)
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			return _newValue
		end)
		applyPositions(prior)
		Audio:play("close", 0.94)
	end
	local redoLayout = function()
		if #redo == 0 then
			return nil
		end
		local upcoming = redo[#redo]
		if upcoming == nil then
			return nil
		end
		setHistory(function(current)
			return capStack(current, positionsRef.current)
		end)
		setRedo(function(current)
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			return _newValue
		end)
		applyPositions(upcoming)
		Audio:play("open", 1.04)
	end
	local nudgeSelected = function(dx, dy)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local step = if fine then 1 else (if snap then snapStep else 4)
		local moved = safeSlotPosition(slot, Vector2.new(current.X + dx * step, current.Y + dy * step), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = moved
		applyPositions(_object)
	end
	local alignSelected = function(mode)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local _condition_1 = slot.width
		if _condition_1 == nil then
			_condition_1 = 112
		end
		local slotW = _condition_1
		local _condition_2 = slot.height
		if _condition_2 == nil then
			_condition_2 = 62
		end
		local slotH = _condition_2
		local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local x = current.X
		local y = current.Y
		if mode == "left" then
			x = bounds.minX
		end
		if mode == "right" then
			x = bounds.maxX
		end
		if mode == "top" then
			y = bounds.minY
		end
		if mode == "bottom" then
			y = bounds.maxY
		end
		if mode == "cx" then
			x = math.floor((viewport.width - slotW) / 2)
		end
		if mode == "cy" then
			y = math.floor((viewport.height - slotH) / 2)
		end
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = safeSlotPosition(slot, Vector2.new(x, y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		applyPositions(_object)
	end
	local unstackOverlaps = function()
		pushHistory(positionsRef.current)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local nextPos = _object
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			for otherIndex = 0, #slots - 1 do
				if otherIndex == index then
					continue
				end
				local other = slots[otherIndex + 1]
				local otherPos = nextPos[other.id] or slotPixels(other, viewport.width, viewport.height)
				local _condition_2 = other.width
				if _condition_2 == nil then
					_condition_2 = 112
				end
				local otherW = _condition_2
				local _condition_3 = other.height
				if _condition_3 == nil then
					_condition_3 = 62
				end
				local otherH = _condition_3
				local separated = pos.X + width + 8 <= otherPos.X or otherPos.X + otherW + 8 <= pos.X or pos.Y + height + 8 <= otherPos.Y or otherPos.Y + otherH + 8 <= pos.Y
				if separated then
					continue
				end
				pos = safeSlotPosition(slot, Vector2.new(pos.X, otherPos.Y + otherH + 12), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
			nextPos[slot.id] = pos
		end
		applyPositions(nextPos)
		save(nextPos)
	end
	local bumpSelectedSetting = function(kind, delta)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil then
			return nil
		end
		local key = if id == "quick" then (if kind == "scale" then "MobileQuickScale" else "MobileQuickOpacity") elseif id == "dock" then (if kind == "scale" then "MobileDockScale" else "MobileDockOpacity") else (if kind == "scale" then "MobileToastScale" else "MobileToastOpacity")
		local _result
		if kind == "scale" then
			local _result_1 = scales
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_result = _condition_1
		else
			local _result_1 = opacities
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.85
			end
			_result = _condition_1
		end
		local current = _result
		dispatch("SetSetting", {
			Key = key,
			Value = math.clamp(current + delta, 0, 1),
		})
	end
	local resetLayout = function()
		local fresh = {}
		for _, slot in slots do
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = slot.defaultX
			_object.y = slot.defaultY
			local resetSlot = _object
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(resetSlot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		for _, slot in slots do
			MobileDragging:setPosition(slot.id, fresh[slot.id])
		end
		positionsRef.current = fresh
		setPositions(fresh)
		save(fresh)
	end
	local applyPreset = function(side)
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 1.02)
		local fresh = {}
		for _, slot in slots do
			local x = slot.defaultX
			local y = slot.defaultY
			if side == "left" then
				if slot.id == "quick" then
					x = 0.28
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "right" then
				if slot.id == "quick" then
					x = 0.72
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "top" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.82
					y = 0.38
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "thumbs" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.5
					y = 0.18
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.93
				end
			elseif side == "tl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "tr" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "bl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "br" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			end
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = x
			_object.y = y
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(_object, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		applyPositions(fresh)
		save(fresh)
		if side == "left" or side == "bl" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 1,
			})
		end
		if side == "right" or side == "br" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 0,
			})
		end
	end
	local slotSize = function(slot)
		return slot.width or 112, slot.height or 62
	end
	local commitLayout = function(nextPos)
		applyPositions(nextPos)
		if not layoutOverlaps(nextPos) then
			save(nextPos)
		end
	end
	local mirrorLayout = function()
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 0.94)
		local nextPos = table.clone(positionsRef.current)
		for _, slot in slots do
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local width = slotSize(slot)
			nextPos[slot.id] = safeSlotPosition(slot, Vector2.new(viewport.width - pos.X - width, pos.Y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		commitLayout(nextPos)
	end
	local cycleSelection = function()
		if #slots == 0 then
			return nil
		end
		local nextIndex = 1
		for index, slot in slots do
			if slot.id == selectedId then
				nextIndex = index % #slots + 1
				break
			end
		end
		setSelectedId(slots[nextIndex].id)
		Audio:play("filterPick", 1.08)
	end
	local swapSelected = function()
		if #slots < 2 then
			return nil
		end
		local fromIndex = 1
		for index, slot in slots do
			if slot.id == selectedId then
				fromIndex = index
				break
			end
		end
		local fromSlot = slots[fromIndex]
		local toSlot = nil
		for step = 1, #slots - 1 do
			local candidate = slots[(fromIndex - 1 + step) % #slots + 1]
			if locked[candidate.id] ~= true then
				toSlot = candidate
				break
			end
		end
		if toSlot == nil or locked[fromSlot.id] == true then
			return nil
		end
		pushHistory(positionsRef.current)
		local nextPos = table.clone(positionsRef.current)
		local fromPos = nextPos[fromSlot.id] or slotPixels(fromSlot, viewport.width, viewport.height)
		local toPos = nextPos[toSlot.id] or slotPixels(toSlot, viewport.width, viewport.height)
		local fromW, fromH = slotSize(fromSlot)
		local toW, toH = slotSize(toSlot)
		-- Swap centres, not corners, so blocks of different sizes trade places cleanly.
		local fromCentre = fromPos + Vector2.new(fromW, fromH) / 2
		local toCentre = toPos + Vector2.new(toW, toH) / 2
		nextPos[fromSlot.id] = safeSlotPosition(fromSlot, toCentre - Vector2.new(fromW, fromH) / 2, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		nextPos[toSlot.id] = safeSlotPosition(toSlot, fromCentre - Vector2.new(toW, toH) / 2, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		Audio:play("filterPick", 1.0)
		commitLayout(nextPos)
	end
	local storeMemory = function()
		local stored = {}
		for _, slot in slots do
			local pos = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			stored[slot.id] = { x = pos.X / math.max(1, viewport.width), y = pos.Y / math.max(1, viewport.height) }
		end
		MOBILE_LAYOUT_MEMORY[memoryIndex] = stored
		setMemoryRevision(memoryRevision + 1)
		Audio:play("copyDone")
	end
	local recallMemory = function()
		local stored = MOBILE_LAYOUT_MEMORY[memoryIndex]
		if stored == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local nextPos = table.clone(positionsRef.current)
		for _, slot in slots do
			local entry = stored[slot.id]
			if entry ~= nil and locked[slot.id] ~= true then
				nextPos[slot.id] = safeSlotPosition(slot, Vector2.new(entry.x * viewport.width, entry.y * viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
		end
		Audio:play("filterPick", 0.9)
		commitLayout(nextPos)
	end
	local overlaps = function(slot, pos)
		local _condition = slot.width
		if _condition == nil then
			_condition = 112
		end
		local w = _condition
		local _condition_1 = slot.height
		if _condition_1 == nil then
			_condition_1 = 62
		end
		local h = _condition_1
		for _, other in slots do
			if other.id == slot.id then
				continue
			end
			local otherPos = positions[other.id] or slotPixels(other, viewport.width, viewport.height)
			local _condition_2 = other.width
			if _condition_2 == nil then
				_condition_2 = 112
			end
			local otherW = _condition_2
			local _condition_3 = other.height
			if _condition_3 == nil then
				_condition_3 = 62
			end
			local otherH = _condition_3
			local separated = pos.X + w + 6 <= otherPos.X or otherPos.X + otherW + 6 <= pos.X or pos.Y + h + 6 <= otherPos.Y or otherPos.Y + otherH + 6 <= pos.Y
			if not separated then
				return true
			end
		end
		return false
	end
	local collisionPresent = layoutOverlaps(positions)
	if not visible then
		return ReactRoblox.createPortal(React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}), screen)
	end
	local editorToolbarY = math.max(if viewport.width > viewport.height and viewport.height < 500 then 56 else 8, viewport.topInset + 8)
	local topToolbarBottom = editorToolbarY + TapTarget * 2 + 16 + 8
	local bottomBarY = math.max(topToolbarBottom, viewport.height - viewport.bottomInset - (TapTarget * 2 + 16))
	local gridMarks = if showThirds then { 1 / 3, 0.5, 2 / 3 } else { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
	local _callback = function(entry)
		local _exp = entry.id
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		return _exp == _condition
	end
	local _result
	for _i, _v in slots do
		if _callback(_v, _i - 1, slots) == true then
			_result = _v
			break
		end
	end
	local selectedSlot = _result
	local selectedPos = if selectedSlot ~= nil then (positions[selectedSlot.id] or slotPixels(selectedSlot, viewport.width, viewport.height)) else nil
	local selectedLocked = selectedSlot ~= nil and locked[selectedSlot.id] == true
	local _condition = editing
	if _condition then
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(x)
			return React.createElement("frame", {
				key = `grid-x-{x}`,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.new(x, 0, 0, 0),
				BackgroundColor3 = if x == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if x == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		_condition = _newValue
	end
	local _condition_1 = editing
	if _condition_1 then
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(y)
			return React.createElement("frame", {
				key = `grid-y-{y}`,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, y, 0),
				BackgroundColor3 = if y == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if y == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		_condition_1 = _newValue
	end
	local _condition_2 = editing
	if _condition_2 then
		local _newValue = table.create(#slots)
		local _callback_1 = function(slot)
			local _condition_3 = slot.width
			if _condition_3 == nil then
				_condition_3 = 112
			end
			local slotW = _condition_3
			local _condition_4 = slot.height
			if _condition_4 == nil then
				_condition_4 = 62
			end
			local slotH = _condition_4
			local pos = positions[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local collision = overlaps(slot, pos)
			local isLocked = locked[slot.id] == true
			local accent = if collision then Palette.coral elseif selectedId == slot.id then Palette.mint elseif isLocked then Palette.mango else EDIT_BOUNDS
			local pctX = math.floor(((pos.X + slotW * 0.5) / viewport.width) * 100)
			local pctY = math.floor(((pos.Y + slotH * 0.5) / viewport.height) * 100)
			return React.createElement("frame", {
				key = slot.id,
				Size = UDim2.fromOffset(slotW, slotH),
				Position = UDim2.fromOffset(pos.X, pos.Y),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ZIndex = 502,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 14),
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = if collision then 3 else 2,
				Transparency = 0.08,
			}), React.createElement("frame", {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(-7, -7),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 505,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement(Text, {
				value = if isLocked then "L" else "+",
				size = 14,
				color = Palette.ink,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 506,
			})), React.createElement(Text, {
				value = slot.label,
				size = 11,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(4, 8),
				sizeConstraint = UDim2.new(1, -8, 0, 18),
				zIndex = 503,
			}), React.createElement(Text, {
				value = `{pctX}%  {pctY}%`,
				size = 9,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 4, 1, -22),
				sizeConstraint = UDim2.new(1, -8, 0, 14),
				zIndex = 503,
			}), collision and React.createElement(Text, {
				value = "OVERLAP",
				size = 8,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -36),
				sizeConstraint = UDim2.new(1, 0, 0, 14),
				zIndex = 506,
			}), React.createElement("imagebutton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Active = true,
				ZIndex = 504,
				Event = {
					InputBegan = function(_button, input)
						if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
							setSelectedId(slot.id)
							if not isLocked then
								MobileDragging:beginDrag(slot.id, input)
							end
						end
					end,
				},
			}))
		end
		for _k, _v in slots do
			_newValue[_k] = _callback_1(_v, _k - 1, slots)
		end
		_condition_2 = _newValue
	end
	local _condition_3 = editing
	if _condition_3 then
		local _exp = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 13),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.42,
		}), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if collisionPresent then "OVERLAP" else "SAVE",
			onClick = if collisionPresent then unstackOverlaps else finishEditing,
			color = if collisionPresent then Palette.coral else EDIT_BOUNDS,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.2, 1, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if snap then `SNAP {snapStep}` else "FREE",
			onClick = function()
				if not snap then
					setSnap(true)
					setSnapStep(4)
				elseif snapStep == 4 then
					setSnapStep(8)
				elseif snapStep == 8 then
					setSnapStep(16)
				elseif snapStep == 16 then
					setSnapStep(32)
				else
					setSnap(false)
					setSnapStep(8)
				end
			end,
			color = if snap then Palette.cyan else Palette.panelSoft,
			textColor = if snap then Palette.ink else Palette.creamSoft,
			outline = not snap,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.4, 2, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "UNDO",
			onClick = undoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.6, 3, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "REDO",
			onClick = redoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.8, 4, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "DONE",
			onClick = function()
				if finishEditing() then
					requestClose()
				end
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = exiting,
		})))
		local _exp_1 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY + TapTarget + 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "←",
			onClick = function()
				return nudgeSelected(-1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↑",
			onClick = function()
				return nudgeSelected(0, -1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.16, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↓",
			onClick = function()
				return nudgeSelected(0, 1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "→",
			onClick = function()
				return nudgeSelected(1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if fine then "1px" else "STEP",
			onClick = function()
				return setFine(not fine)
			end,
			color = if fine then Palette.mint else Palette.panelSoft,
			textColor = if fine then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.64, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if showThirds then "1/3" else "10%",
			onClick = function()
				return setShowThirds(not showThirds)
			end,
			color = if showThirds then Palette.cyan else Palette.panelSoft,
			textColor = if showThirds then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.82, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_2 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "L",
			onClick = function()
				return alignSelected("left")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "R",
			onClick = function()
				return alignSelected("right")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(1 / 6, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "T",
			onClick = function()
				return alignSelected("top")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(2 / 6, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "B",
			onClick = function()
				return alignSelected("bottom")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(3 / 6, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CX",
			onClick = function()
				return alignSelected("cx")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(4 / 6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CY",
			onClick = function()
				return alignSelected("cy")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(5 / 6, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_3 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY + TapTarget + 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = if selectedLocked then "UNLOCK" else "LOCK",
			onClick = function()
				if selectedSlot == nil then
					return nil
				end
				setLocked(function(current)
					local _object = table.clone(current)
					setmetatable(_object, nil)
					_object[selectedSlot.id] = not selectedLocked
					return _object
				end)
			end,
			color = if selectedLocked then Palette.mango else Palette.panelSoft,
			textColor = if selectedLocked then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ-",
			onClick = function()
				return bumpSelectedSetting("scale", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.18, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ+",
			onClick = function()
				return bumpSelectedSetting("scale", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE-",
			onClick = function()
				return bumpSelectedSetting("opacity", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.46, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE+",
			onClick = function()
				return bumpSelectedSetting("opacity", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.62, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CLEAR",
			onClick = unstackOverlaps,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.new(0.22, -3, 1, 0),
			position = UDim2.new(0.78, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _attributes = {}
		local _result_1
		if selectedPos ~= nil then
			local _result_2 = selectedSlot
			if _result_2 ~= nil then
				_result_2 = _result_2.label
			end
			local _condition_4 = _result_2
			if _condition_4 == nil then
				_condition_4 = "HUD"
			end
			local selectedScale = if scales ~= nil and selectedSlot ~= nil then scales[selectedSlot.id] else nil
			local selectedFade = if opacities ~= nil and selectedSlot ~= nil then opacities[selectedSlot.id] else nil
			local xPct = math.floor(selectedPos.X / math.max(1, viewport.width) * 100 + 0.5)
			local yPct = math.floor(selectedPos.Y / math.max(1, viewport.height) * 100 + 0.5)
			_result_1 = `{_condition_4}  ·  X {xPct}%  Y {yPct}%  ·  SIZE {math.floor((selectedScale or 0.5) * 100 + 0.5)}  FADE {math.floor((selectedFade or 0.85) * 100 + 0.5)}{if selectedLocked then "  ·  LOCKED" else ""}{if collisionPresent then "  ·  OVERLAP" else ""}`
		else
			_result_1 = "DRAG A BLOCK"
		end
		_attributes.value = _result_1
		_attributes.size = 10
		_attributes.color = Palette.cyan
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.align = Enum.TextXAlignment.Center
		_attributes.position = UDim2.new(0, viewport.sideInset + 12, 0, editorToolbarY + TapTarget * 2 + 16)
		_attributes.sizeConstraint = UDim2.new(1, -(viewport.sideInset * 2 + 24), 0, 18)
		_attributes.zIndex = 506
		local toolRowY = bottomBarY - TapTarget - 6
		local memoryFilled = MOBILE_LAYOUT_MEMORY[memoryIndex] ~= nil
		local _exp_4 = toolRowY >= topToolbarBottom + 18 and React.createElement("frame", {
			key = `tools-{memoryRevision}`,
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, toolRowY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "NEXT",
			onClick = cycleSelection,
			color = Palette.panelSoft,
			textColor = Palette.cyan,
			outline = true,
			size = UDim2.new(0.15, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SWAP",
			onClick = swapSelected,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.15, -3, 1, 0),
			position = UDim2.new(0.15, 1, 0, 0),
			disabled = selectedLocked,
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "MIRROR",
			onClick = mirrorLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.3, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = `M{memoryIndex}`,
			onClick = function()
				setMemoryIndex(memoryIndex % 3 + 1)
			end,
			color = if memoryFilled then Palette.violet else Palette.panelSoft,
			textColor = if memoryFilled then Palette.ink else Palette.creamSoft,
			outline = not memoryFilled,
			size = UDim2.new(0.12, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "STORE",
			onClick = storeMemory,
			color = Palette.panelSoft,
			textColor = Palette.violet,
			outline = true,
			size = UDim2.new(0.2, -3, 1, 0),
			position = UDim2.new(0.6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "RECALL",
			onClick = recallMemory,
			color = if memoryFilled then Palette.violet else Palette.panelSoft,
			textColor = if memoryFilled then Palette.ink else Palette.muted,
			size = UDim2.new(0.2, -3, 1, 0),
			position = UDim2.new(0.8, 5, 0, 0),
			disabled = not memoryFilled,
			reducedMotion = reducedMotion,
		}))
		_condition_3 = React.createElement(React.Fragment, nil, _exp, _exp_1, _exp_2, _exp_3, _exp_4 or nil, React.createElement(Text, _attributes))
	end
	return ReactRoblox.createPortal(React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = exit:map(function(amount)
			return 1 - amount * (if editing then 0.62 else 0.88)
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 500,
		ClipsDescendants = true,
		Visible = exit:map(function(amount)
			return amount > 0.01
		end),
	}, _condition, _condition_1, _condition_2, _condition_3, not editing and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(440, viewport.width - viewport.sideInset * 2 - 24), 292),
		Position = UDim2.new(0.5, 0, 1, -(304 + viewport.bottomInset)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 510,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(Button, {
		text = "EDIT HUD LAYOUT",
		onClick = function()
			return setEditing(true)
		end,
		color = EDIT_BOUNDS,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "LEFT",
		onClick = function()
			return applyPreset("left")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.2, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "HOME",
		onClick = function()
			return applyPreset("default")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.4, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RIGHT",
		onClick = function()
			return applyPreset("right")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.6, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TOP",
		onClick = function()
			return applyPreset("top")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.8, 4, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "THUMB",
		onClick = function()
			return applyPreset("thumbs")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TL",
		onClick = function()
			return applyPreset("tl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.25, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TR",
		onClick = function()
			return applyPreset("tr")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.5, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BL",
		onClick = function()
			return applyPreset("bl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.75, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BR",
		onClick = function()
			return applyPreset("br")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.fromOffset(0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RESET",
		onClick = resetLayout,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.new(0.5, 4, 0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "CLOSE",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
	})), React.createElement(Text, {
		value = "Move vault, dock, and alerts. Size, fade, lock, and snap stay. Nothing is removed.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(8, 212),
		sizeConstraint = UDim2.new(1, -16, 0, 56),
	})), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	}), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	})), screen)
end
local function MobileQuickBar(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local hudX = _param.hudX
	local hudY = _param.hudY
	local hudScale = _param.hudScale
	local hudOpacity = _param.hudOpacity
	local buttonSpacing = _param.buttonSpacing
	local minTop = _param.minTop
	local reversed = _param.reversed
	if reversed == nil then
		reversed = false
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local side = math.max(edgePad, chrome.sideSafe)
	local _condition = buttonSpacing
	if _condition == nil then
		_condition = 0.5
	end
	local gap = 4 + math.floor(math.clamp(_condition, 0, 1) * 10)
	local btnH = TapTarget
	local _condition_1 = hudScale
	if _condition_1 == nil then
		_condition_1 = 0.5
	end
	local scale = 0.72 + math.clamp(_condition_1, 0, 1) * 0.28
	local width = math.max(200, (viewport.width - side * 2) * scale)
	local _condition_2 = hudX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local x = math.clamp(_condition_2, (side + width / 2) / viewport.width, 1 - (side + width / 2) / viewport.width)
	local yFallback = 1 - (bottomOffset - height / 2) / viewport.height
	local _condition_3 = hudY
	if _condition_3 == nil then
		_condition_3 = yFallback
	end
	local y = math.clamp(_condition_3, (math.max(viewport.topInset, minTop) + height / 2 + 8) / viewport.height, 1 - (viewport.bottomInset + height / 2 + 8) / viewport.height)
	local _condition_4 = hudOpacity
	if _condition_4 == nil then
		_condition_4 = 0.85
	end
	local surfaceTransparency = math.clamp(0.48 - math.clamp(_condition_4, 0, 1) * 0.48, 0, 0.48)
	local readyPulse = usePulse(vaultReady and vaultFill > 0.8, 2.4)
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
				if not alive then
					break
				end
				setTapLeft(math.ceil(left * 10) / 10)
				if not alive or left <= 0 then
					break
				end
				task.wait(math.max(0.016, left - (math.ceil(left * 10) - 1) / 10))
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.45)
		setTapLeft(0.45)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = 61,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = readyPulse:map(function(amount)
			return if vaultFill > 0.8 then 0.42 - amount * 0.22 else 0.45
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 3),
		Position = UDim2.fromOffset(8, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 62,
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
		Size = UDim2.new(1, -16, 0, btnH),
		Position = UDim2.fromOffset(8, height - btnH - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 63,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 2 else 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK  {compactNumber(state.Vault)}` else "VAULT EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 1 else 2,
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
	}))), chrome.landscape and React.createElement(Text, {
		value = `{compactNumber(state.Production)}/s`,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -12, 0, 6),
		sizeConstraint = UDim2.fromOffset(80, 12),
		zIndex = 64,
	})))
end
return {
	MobileControls = MobileControls,
	MobileQuickBar = MobileQuickBar,
}
end

__defs["floorFx"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local Motion = require(script.Parent.MotionKit)("motionTokens")
local Fx = require(script.Parent.MotionKit)("vfxMath")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local Text = require(script.Parent.UiCore)("ui").Text
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local SHOCK_LIFE = 0.55
local function ShockRing(_param)
	local trigger = _param.trigger
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local size = _param.size
	if size == nil then
		size = 280
	end
	local clock = useClock(trigger > 0 and not reducedMotion, 1, 1000, true)
	local rings = {}
	for ring = 0, 2 do
		local delay = ring * 0.05
		rings[ring + 1] = React.createElement("frame", {
			key = ring,
			Size = clock:map(function(seconds)
				local grow = Fx.ring(seconds - delay, SHOCK_LIFE)
				local d = 24 + grow * (size * 0.95 + ring * 26)
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 81,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then Palette.cream else lighten(color, if ring == 0 then 0.25 else 0),
			Thickness = clock:map(function(seconds)
				local _, thin = Fx.ring(seconds - delay, SHOCK_LIFE)
				return 1 + thin * (if ring == 0 then 5 else 3)
			end),
			Transparency = clock:map(function(seconds)
				local _, _, fade = Fx.ring(seconds - delay, SHOCK_LIFE)
				return 0.05 + fade * 0.95
			end),
		}))
	end
	return React.createElement("frame", {
		key = `shock-{trigger}`,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(seconds)
			local d = size * (0.16 + 0.42 * Motion.EASE.decelerate(clamp01(seconds / 0.2)))
			return UDim2.fromOffset(d, d)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = lighten(color, 0.55),
		BackgroundTransparency = clock:map(function(seconds)
			return 0.3 + 0.7 * Motion.EASE.accelerate(clamp01(seconds / 0.24))
		end),
		BorderSizePixel = 0,
		ZIndex = 82,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	})), rings)
end
local Spark
local function SparkBurst(_param)
	local sparks = _param.sparks
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(4, math.min(antilag.maxPops * 2, 28))
	local visible = sparks
	if #sparks > max then
		visible = {}
		for index = #sparks - max + 1, #sparks do
			table.insert(visible, sparks[index])
		end
	end
	local children = table.create(#visible)
	for index, spark in visible do
		children[index] = React.createElement(Spark, {
			key = spark.id,
			spark = spark,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
local SPARK_LIFE = 0.72
local SPARK_GRAVITY = 980
local SPARK_DRAG = 2.6
function Spark(_param)
	local spark = _param.spark
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local crumb = spark.kind == "strike" or spark.kind == "perfect" or spark.kind == "bank"
	local power = if spark.kind == "perfect" then 1.35 elseif spark.kind == "bank" then 1.1 else 0.85
	local thickness = if spark.kind == "perfect" then 5 elseif crumb then 4 else 3.2
	local angle = -math.pi / 2 + (Fx.hash(spark.id, 1) - 0.5) * math.rad(150)
	local speed = (260 + Fx.hash(spark.id, 2) * 260) * power * (if reducedMotion then 0.6 else 1)
	local function velocity(seconds: number): (number, number)
		return Fx.velocity(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
	end
	return React.createElement("frame", {
		Size = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			local length = thickness * 1.4 * Fx.stretch(math.sqrt(vx * vx + vy * vy))
			return UDim2.fromOffset(length, thickness)
		end),
		Position = clock:map(function(seconds)
			local dx, dy = Fx.ballistic(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
			return UDim2.fromScale(spark.x, spark.y) + UDim2.fromOffset(dx, dy)
		end),
		Rotation = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			return math.deg(math.atan2(vy, vx))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = clock:map(function(seconds)
			return spark.color:Lerp(Palette.white, Fx.heat(seconds, 0.16))
		end),
		BackgroundTransparency = clock:map(function(seconds)
			return Fx.fade(seconds, SPARK_LIFE, 0.3)
		end),
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }),
	}))
end
local ClickPop
local function ClickPops(_param)
	local pops = _param.pops
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(3, math.min(antilag.maxPops, 10))
	local visible = pops
	if #pops > max then
		visible = {}
		for index = #pops - max + 1, #pops do
			table.insert(visible, pops[index])
		end
	end
	local children = table.create(#visible)
	for index, pop in visible do
		children[index] = React.createElement(ClickPop, {
			key = pop.id,
			pop = pop,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
local POP_LIFE = 0.8
function ClickPop(_param)
	local pop = _param.pop
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 34 else 24
	local rise = if pop.critical then 118 else 86
	local drift = (Fx.hash(pop.id, 3) - 0.5) * 36
	local tilt = if pop.critical then (Fx.hash(pop.id, 4) - 0.5) * 12 else 0
	local position = clock:map(function(seconds)
		local t = Motion.EASE.decelerate(clamp01(seconds / POP_LIFE))
		return UDim2.fromScale(pop.x, pop.y) + UDim2.fromOffset(drift * t, -t * rise)
	end)
	local scale = clock:map(function(seconds)
		if reducedMotion then
			return 1
		end
		return Fx.popScale(seconds, if pop.critical then 0.24 else 0.18, if pop.critical then 0.55 else 0.4)
	end)
	local color = if pop.critical
		then clock:map(function(seconds)
			return pop.color:Lerp(Palette.white, Fx.heat(seconds, 0.14))
		end)
		else pop.color
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if pop.critical then 168 else 128, 40),
		Position = position,
		Rotation = clock:map(function(seconds)
			return tilt * (1 - Motion.EASE.decelerate(clamp01(seconds / 0.35)))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 97,
	}, React.createElement("uiscale", {
		Scale = scale,
	}), React.createElement(Text, {
		value = pop.text,
		size = size,
		color = color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		transparency = clock:map(function(seconds)
			return Fx.fade(seconds, POP_LIFE, 0.5)
		end),
	}))
end
local function ComboBanner(_param)
	local combo = _param.combo
	local heat = _param.heat
	local perfect = _param.perfect
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(not reducedMotion and combo > 1, 1.05)
	local bump = useFlash(combo, reducedMotion, 0.3)
	local accent = if perfect then Palette.mango elseif heat > 0.82 then Palette.coral else Palette.brass
	if combo <= 1 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 52),
		Position = UDim2.fromScale(0.5, 0.145),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 70,
	}, React.createElement("uiscale", {
		Scale = React.joinBindings({ pulse, bump }):map(function(values)
			return 1 + math.sin(values[1]) * (if perfect then 0.045 else 0.022) + values[2] * 0.16
		end),
	}), React.createElement(Text, {
		value = if perfect then "CRIT" else "STREAK",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = `x{combo}`,
		size = if combo >= 10 then 30 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 14),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
end
local function HeatHaze(_param)
	local heat = _param.heat
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion and heat > 0.12, 0.22)
	local strength = math.clamp(heat, 0, 1)
	if strength <= 0.02 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1.08, 0, 0.42, 0),
		Position = clock:map(function(phase)
			return UDim2.new(-0.04 + math.sin(phase) * 0.02, 0, 0.48 + math.cos(phase * 0.7) * 0.012, 0)
		end),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = 1 - 0.07 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(420, 420),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 1 - 0.05 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function FluxRiver(_param)
	local stations = _param.stations
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local clock = useClock(not reducedMotion, 0.55)
	local _newValue = table.create(#stations)
	local _callback = function(station, index)
		return if station.live then React.createElement("frame", {
			key = `river-{index}`,
			Size = UDim2.fromOffset(3, 3),
			Position = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				local x = station.x + (0.5 - station.x) * t
				local y = station.y + (0.58 - station.y) * t - math.sin(t * math.pi) * 0.04
				return UDim2.fromScale(x, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = station.color,
			BackgroundTransparency = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				return 0.15 + (1 - math.sin(t * math.pi)) * 0.7
			end),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})) else nil
	end
	for _k, _v in stations do
		_newValue[_k] = _callback(_v, _k - 1, stations)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Active = false,
	}, _newValue, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromOffset(8 + math.sin(phase) * 3, 8 + math.sin(phase) * 3)
		end),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function WorldHaze(_param)
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.07)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.42, darken(color, 0.82)), ColorSequenceKeypoint.new(1, Palette.ink) }),
		Rotation = 118,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(720, 720),
		Position = clock:map(function(phase)
			return UDim2.new(1, 90 + math.sin(phase) * 28, 1, 50 + math.cos(phase * 0.7) * 20)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(460, 460),
		Position = UDim2.new(0, -90, 0, -70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.12) }),
		Rotation = 90,
	})))
end
local function CoreAura(_param)
	local color = _param.color
	local heat = _param.heat
	local squash = _param.squash
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.16)
	local glow = math.clamp(0.16 + heat * 0.22, 0.16, 0.4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 18,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromScale(0.72 + math.sin(phase) * 0.03, 0.72 + math.sin(phase) * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - glow,
		BorderSizePixel = 0,
		ZIndex = 18,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(lighten(color, 0.2), 0.8),
		Rotation = 90,
	})))
end
return {
	ShockRing = ShockRing,
	SparkBurst = SparkBurst,
	ClickPops = ClickPops,
	ComboBanner = ComboBanner,
	HeatHaze = HeatHaze,
	FluxRiver = FluxRiver,
	WorldHaze = WorldHaze,
	CoreAura = CoreAura,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
