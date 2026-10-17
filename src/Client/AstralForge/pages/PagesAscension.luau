--!nonstrict
-- Ascension: the final, endless reset. One hero (rank, Aether, production), the ascend panel with a
-- hold-to-confirm button, a harmony strip, and the six sigils.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Ui = require(script.Parent.Parent.UiCore)("ui")
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local chromeFor = _theme.chromeFor
local TapTarget = _theme.TapTarget
local Format = require(script.Parent.Parent.CoreKit)("format")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useViewport = _motion.useViewport
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local h = React.createElement

local ACCENT = Color3.fromRGB(255, 196, 120) -- warm aether gold
local SIGIL_COLORS = {
	Sol = Color3.fromRGB(255, 184, 52),
	Bastion = Color3.fromRGB(96, 166, 255),
	Strike = Color3.fromRGB(255, 104, 112),
	Ember = Color3.fromRGB(250, 104, 178),
	Crown = Color3.fromRGB(178, 134, 255),
	Lodestar = Color3.fromRGB(86, 236, 178),
}
local SIGIL_ICONS = { Sol = "Forge", Bastion = "Vault", Strike = "Overcharge", Ember = "Rebirth", Crown = "Domain", Lodestar = "StarGrid" }
local GAP = 14
local HOLD_SECONDS = 1.6

local function compact(value)
	return Format.compactNumber(value)
end

-- A ring of dots slowly orbiting a centre: the Ascension mark.
local function Orbit(props)
	local spin = useClock(not props.softMotion, 0.05, math.pi * 2)
	local dots = {}
	for index = 1, props.count do
		local phase = (index - 1) / props.count * math.pi * 2
		dots["d" .. index] = h("frame", {
			Size = UDim2.fromOffset(props.dot, props.dot),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = spin:map(function(angle)
				local a = angle * props.speed + phase
				return UDim2.new(0.5, math.cos(a) * props.radius, 0.5, math.sin(a) * props.radius)
			end),
			BackgroundColor3 = props.color,
			BackgroundTransparency = 0.15 + (index % 3) * 0.2,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h("frame", {
		Size = UDim2.fromOffset(props.radius * 2 + props.dot, props.radius * 2 + props.dot),
		Position = props.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, dots)
end

-- Press and hold to ascend; letting go early cancels. It resets everything below it, so a tap is
-- never enough.
local function HoldButton(props)
	local fill, setFill = React.useBinding(0)
	local holding = React.useRef(nil)
	local enabled = props.enabled
	local function stop()
		if holding.current then
			holding.current:Disconnect()
			holding.current = nil
		end
		setFill(0)
	end
	React.useEffect(function()
		return stop
	end, {})
	local function begin()
		if not enabled or holding.current then
			return
		end
		Audio:play("rebirthCharge")
		local started = os.clock()
		holding.current = RunService.Heartbeat:Connect(function()
			local amount = math.clamp((os.clock() - started) / HOLD_SECONDS, 0, 1)
			setFill(amount)
			if amount >= 1 then
				stop()
				props.onConfirm()
			end
		end)
	end
	return h("textbutton", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = if enabled then darken(ACCENT, 0.55) else Palette.panelSoft,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Active = enabled,
		Selectable = enabled,
		ClipsDescendants = true,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA then
				begin()
			end
		end,
		[React.Event.InputEnded] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA then
				if holding.current then
					Audio:play("close")
				end
				stop()
			end
		end,
		[React.Event.MouseLeave] = stop,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }),
		h("uistroke", { Color = if enabled then ACCENT else Palette.lineSoft, Transparency = 0.25, Thickness = 1.5 }),
		h("frame", {
			Name = "Fill",
			Size = fill:map(function(a) return UDim2.fromScale(a, 1) end),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		h("textlabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = fill:map(function(a)
				if not enabled then
					return props.disabledText
				end
				return if a > 0 then "KEEP HOLDING…" else props.text
			end),
			TextColor3 = fill:map(function(a) return if a > 0.5 then Palette.ink else Palette.cream end),
			TextSize = 16,
			FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
			ZIndex = 3,
		}))
end

local function SigilCard(props)
	local sigil = props.sigil
	local color = SIGIL_COLORS[sigil.Id] or ACCENT
	local pulse = useClock(not props.softMotion and sigil.Level > 0, 0.6, math.pi * 2)
	local boughtFlash = useFlipperSpring(sigil.Level, props.softMotion, 300, 22)
	local boosted = sigil.EffectiveLevel > sigil.Level
	return h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 16, accent = color, background = Palette.panelRaised, clips = false },
		h("frame", {
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = darken(color, 0.72),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h("uistroke", {
				Color = color,
				Thickness = 2,
				Transparency = pulse:map(function(a) return if sigil.Level > 0 then 0.15 + (math.sin(a) + 1) * 0.2 else 0.6 end),
			}),
			h(Ui.IconTile, { kind = SIGIL_ICONS[sigil.Id] or "StarGrid", accent = color, size = 34, position = UDim2.fromOffset(9, 9), reducedMotion = props.softMotion })),
		h(Ui.Text, { value = sigil.Name, size = 20, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(66, 2), sizeConstraint = UDim2.new(1, -150, 0, 24) }),
		h(Ui.Text, { value = sigil.Line, size = 13, color = Palette.muted, position = UDim2.fromOffset(66, 28), sizeConstraint = UDim2.new(1, -66, 0, 18) }),
		h(Ui.Text, {
			value = if sigil.Level > 0 then `Lv {compact(sigil.Level)}` else "Not started",
			size = 13, color = color, weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -84, 0, 4), sizeConstraint = UDim2.fromOffset(84, 18),
		}),
		h(Ui.Text, {
			value = if sigil.Level > 0
				then `×{compact(sigil.Multiplier)} {string.lower(sigil.Effect)}` .. (if boosted then `  ·  acts as Lv {compact(sigil.EffectiveLevel)}` else "")
				else "Buy a level to start it",
			size = 15, weight = Enum.FontWeight.Bold, color = Palette.cream,
			position = UDim2.fromOffset(0, 66), sizeConstraint = UDim2.new(1, 0, 0, 20),
		}),
		h(Ui.Button, {
			text = `Upgrade · {compact(sigil.Cost)} Aether`,
			icon = "StarGrid.2",
			color = if sigil.Affordable then color else Palette.panelSoft,
			textColor = if sigil.Affordable then Palette.ink else Palette.muted,
			disabled = not sigil.Affordable or props.busy,
			highlight = sigil.Affordable,
			size = UDim2.new(1, 0, 0, 44),
			position = UDim2.new(0, 0, 1, -44),
			reducedMotion = props.softMotion,
			onClick = function() props.onBuy(sigil.Id) end,
		}),
		h("frame", { -- a brief glow when a level lands
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = boughtFlash:map(function(value)
				return 1 - math.clamp(math.abs(value - sigil.Level), 0, 1) * 0.35
			end),
			BorderSizePixel = 0,
			ZIndex = 0,
		}, h("uicorner", { CornerRadius = UDim.new(0, 14) })))
end

local function AscensionView(props)
	local state = props.state.Ascension
	local softMotion = props.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState("")
	local function request(action, payload)
		if busy then return end
		setBusy(true)
		props.dispatch(action, payload or {}, function(response)
			setBusy(false)
			if type(response) == "table" then
				setNote(if response.ok then (response.message or "") else (response.error or "That didn't work."))
				Audio:play(if response.ok then "successChime" else "error")
			end
		end)
	end
	local sections = {}
	local function add(id, height, element) table.insert(sections, { id = id, height = height, element = element }) end
	if type(state) ~= "table" then
		add("loading", 80, h(Ui.Text, { value = "Loading Ascension…", size = 16, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }))
		return React.createElement(PageScaffold, { sections = sections, gap = GAP, tailPad = 72 })
	end

	-- hero (phones: a smaller orbit and a narrower left column so the copy keeps its width)
	local heroH = if stack then 216 else 168
	local col = if stack then 104 else 140
	local orbitX = if stack then 44 else 60
	local outer = if stack then 38 else 52
	local inner = if stack then 22 else 30
	add("hero", heroH, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = if stack then 16 else 20, accent = ACCENT, background = darken(ACCENT, 0.9), clips = true },
		h(Orbit, { count = 12, radius = outer, dot = 6, speed = 1, color = ACCENT, position = UDim2.new(0, orbitX, 0, outer + 12), softMotion = softMotion, zIndex = 2 }),
		h(Orbit, { count = 7, radius = inner, dot = 5, speed = -1.6, color = lighten(ACCENT, 0.25), position = UDim2.new(0, orbitX, 0, outer + 12), softMotion = softMotion, zIndex = 2 }),
		h(Ui.Text, { value = tostring(state.Rank), size = if stack then 24 else 30, weight = Enum.FontWeight.Heavy, color = Palette.cream, align = Enum.TextXAlignment.Center,
			position = UDim2.new(0, orbitX - 30, 0, outer + 12 - 18), sizeConstraint = UDim2.fromOffset(60, 36), zIndex = 3 }),
		h(Ui.Text, { value = "ASCENSION", size = 12, weight = Enum.FontWeight.Heavy, color = ACCENT, position = UDim2.fromOffset(col, 0), sizeConstraint = UDim2.new(1, -col, 0, 16) }),
		h(Ui.Text, {
			value = if state.Rank > 0 then `Ascended {state.Rank} time{if state.Rank == 1 then "" else "s"}` else "The final reset",
			size = if stack then 22 else 26, weight = Enum.FontWeight.Heavy, fit = true, minSize = 16,
			position = UDim2.fromOffset(col, 18), sizeConstraint = UDim2.new(1, -col, 0, 32),
		}),
		h(Ui.Text, {
			value = `{compact(state.Aether)} Aether to spend  ·  ×{compact(state.Production)} production from Ascension`,
			size = 14, color = Palette.creamSoft, wrap = true, position = UDim2.fromOffset(col, 56), sizeConstraint = UDim2.new(1, -col, 0, if stack then 58 else 40),
		}),
		h(Ui.Text, {
			value = "Ascension resets your Domain, rebirths, cores and current run. Research, relics, artifacts, Continuum and sigils stay. You can ascend again.",
			size = 12, color = Palette.muted, wrap = true,
			position = if stack then UDim2.fromOffset(0, 124) else UDim2.fromOffset(col, 96),
			sizeConstraint = if stack then UDim2.new(1, 0, 0, 56) else UDim2.new(1, -col, 0, 36),
		})))

	-- ascend
	local progress = math.clamp(state.DomainRank / math.max(1, state.RequiredDomainRank), 0, 1)
	add("ascend", if stack then 196 else 132, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 18, accent = if state.CanAscend then ACCENT else Palette.lineSoft, background = Palette.panel },
		h(Ui.Text, {
			value = if state.CanAscend then `Ascension {state.Rank + 1} is ready: +{compact(state.Gain)} Aether` else `Reach Domain rank {state.RequiredDomainRank} to ascend`,
			size = 19, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, if stack then 0 else -300, 0, 26),
		}),
		h(Ui.Text, {
			value = `Domain rank {state.DomainRank} of {state.RequiredDomainRank}` .. (if state.CanAscend then "  ·  going further past it pays more Aether" else ""),
			size = 13, color = Palette.muted, position = UDim2.fromOffset(0, 30), sizeConstraint = UDim2.new(1, if stack then 0 else -300, 0, 18),
		}),
		h(Ui.Meter, { value = progress, color = ACCENT, reducedMotion = softMotion, position = UDim2.fromOffset(0, 58), size = UDim2.new(1, if stack then 0 else -300, 0, 8) }),
		h(Ui.Text, {
			value = `Next rank: ×{compact(state.NextRankProduction)} production`,
			size = 12, color = Palette.creamSoft, position = UDim2.fromOffset(0, 76), sizeConstraint = UDim2.new(1, if stack then 0 else -300, 0, 16),
		}),
		h(HoldButton, {
			enabled = state.CanAscend and not busy,
			text = "HOLD TO ASCEND",
			disabledText = "NOT READY",
			size = if stack then UDim2.new(1, 0, 0, TapTarget + 8) else UDim2.fromOffset(280, 64),
			position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -280, 0.5, -32),
			onConfirm = function() request("Ascend") end,
		})))
	if note ~= "" then
		add("note", 28, h(Ui.Text, { value = note, size = 14, color = Palette.creamSoft, sizeConstraint = UDim2.new(1, 0, 0, 24) }))
	end

	-- harmony
	local pips = {}
	for index, sigil in state.Sigils do
		local color = SIGIL_COLORS[sigil.Id] or ACCENT
		pips[sigil.Id] = h("frame", {
			Size = UDim2.new(1 / 6, -8, 0, 26),
			Position = UDim2.new((index - 1) / 6, 4, 0, 40),
			BackgroundColor3 = darken(color, if sigil.Level > state.Harmony then 0.4 else 0.75),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			h(Ui.Text, { value = `{sigil.Name} {compact(sigil.Level)}`, size = 11, weight = Enum.FontWeight.Bold, align = Enum.TextXAlignment.Center,
				fit = true, minSize = 8, sizeConstraint = UDim2.fromScale(1, 1) }))
	end
	add("harmony", 82, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.mint, background = Palette.panel },
		h(Ui.Text, {
			value = if state.Harmony > 0 then `Harmony {state.Harmony}: every started sigil acts {state.Harmony} level{if state.Harmony == 1 then "" else "s"} higher`
				else "Harmony 0: raise all six sigils together and each one acts higher",
			size = 15, weight = Enum.FontWeight.Bold, sizeConstraint = UDim2.new(1, 0, 0, 22),
		}),
		h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pips)))

	-- sigils
	local columns = if stack then 1 else (if viewport.width >= 1300 then 3 else 2)
	local cardH = 168
	local rows = math.ceil(#state.Sigils / columns)
	local cards = {}
	for index, sigil in state.Sigils do
		local col, row = (index - 1) % columns, (index - 1) // columns
		cards[sigil.Id] = h("frame", {
			Size = UDim2.new(1 / columns, -GAP + GAP / columns, 0, cardH),
			Position = UDim2.new(col / columns, col * GAP / columns, 0, row * (cardH + GAP)),
			BackgroundTransparency = 1,
		}, h(SigilCard, { sigil = sigil, softMotion = softMotion, busy = busy, onBuy = function(id) request("UpgradeSigil", { Id = id }) end }))
	end
	add("sigils", rows * cardH + (rows - 1) * GAP, h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cards))
	return React.createElement(PageScaffold, { sections = sections, gap = GAP, tailPad = 72, scrollBarColor = ACCENT })
end

return function()
	return { AscensionView = AscensionView }
end
