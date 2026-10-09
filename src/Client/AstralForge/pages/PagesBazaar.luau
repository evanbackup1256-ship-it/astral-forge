--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesBazaar: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesBazaar: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["BazaarKit"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BazaarSfx = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("BazaarSfx"))
local Palette = require(script.Parent.Parent.CoreKit)("theme").Palette
local Button = require(script.Parent.Parent.UiCore)("ui").Button
local Text = require(script.Parent.Parent.UiCore)("ui").Text

local function outCubic(x)
	return 1 - (1 - math.clamp(x, 0, 1)) ^ 3
end

local frameLoop = { connection = nil :: RBXScriptConnection?, entries = {} :: { [any]: boolean }, count = 0, scratch = {} :: { any } }

local function runFrame(dt: number)
	local now = os.clock()
	local list = frameLoop.scratch
	table.clear(list)
	for entry in frameLoop.entries do
		table.insert(list, entry)
	end
	for _, entry in list do
		if frameLoop.entries[entry] and (entry.interval == 0 or now - entry.last >= entry.interval) then
			local step = if entry.last == 0 then dt else math.min(now - entry.last, 0.1)
			entry.last = now
			entry.callback.current(step, now)
		end
	end
end

local function useRender(callback, enabled, hz)
	local latest = React.useRef(callback)
	latest.current = callback
	React.useEffect(function()
		if enabled == false then
			return nil
		end
		local entry = { callback = latest, interval = if hz then 1 / hz else 0, last = 0 }
		frameLoop.entries[entry] = true
		frameLoop.count += 1
		if frameLoop.connection == nil then
			frameLoop.connection = RunService.RenderStepped:Connect(runFrame)
		end
		return function()
			frameLoop.entries[entry] = nil
			frameLoop.count -= 1
			if frameLoop.count <= 0 and frameLoop.connection ~= nil then
				frameLoop.connection:Disconnect()
				frameLoop.connection = nil
				frameLoop.count = 0
			end
		end
	end, { enabled })
end

local sfxGroup = nil
local function groupOf()
	if sfxGroup ~= nil and sfxGroup.Parent ~= nil then
		return sfxGroup
	end
	local master = SoundService:FindFirstChild("ForgeMaster")
	sfxGroup = if master then master:FindFirstChild("ForgeSfx") else nil
	return sfxGroup
end

local function makeSound(name, volume, speed, looped)
	local id = BazaarSfx[name]
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "BazaarSfx"
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = volume or 0.7
	sound.PlaybackSpeed = speed or 1
	sound.Looped = looped == true
	sound.SoundGroup = groupOf()
	local color = Instance.new("EqualizerSoundEffect")
	color.Name = "BazaarColor"
	color.HighGain = -4
	color.MidGain = -2
	color.LowGain = -3
	color.Parent = sound
	sound.Parent = SoundService
	return sound
end

-- One loaded template per cue; each play is a clone so overlapping chips/ticks all sound.
-- (This used to create a Sound and never call Play, so every Bazaar sound was silent and leaked.)
local templates = {}
local function template(name)
	local cached = templates[name]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local sound = makeSound(name, 0, 1, false)
	templates[name] = sound
	return sound
end

task.spawn(function()
	local list = {}
	for name in BazaarSfx do
		local sound = template(name)
		if sound ~= nil then
			table.insert(list, sound)
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

local function sfx(name, volume, speed)
	local base = template(name)
	if base == nil then
		return
	end
	local sound = base:Clone()
	sound.Volume = (volume or 0.7) * 0.85
	sound.PlaybackSpeed = speed or 1
	sound.SoundGroup = groupOf()
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
	sound:Play()
end

local function Stack(props)
	local kids = {
		List = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, props.gap or 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}
	for index, child in props.children do
		kids["c" .. index] = child
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, kids)
end

local function Line(props)
	return React.createElement(Text, {
		value = props.value,
		size = props.size or 13,
		color = props.color or Palette.muted,
		weight = props.weight or Enum.FontWeight.Medium,
		wrap = props.wrap ~= false,
		align = props.align,
		sizeConstraint = UDim2.new(1, 0, 0, props.height or 20),
		layoutOrder = props.order or 0,
	})
end

local function Row(props)
	local list = { Layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.gap or 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}) }
	for index, child in props.children do
		list["c" .. index] = child
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, props.height or 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order or 0,
	}, list)
end

local function Buttons(props)
	local count = #props.items
	local gap = props.gap or 6
	local children = {}
	for index, item in props.items do
		children[index] = React.createElement(Button, {
			text = item.text,
			onClick = item.onClick,
			size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
			color = item.color,
			textColor = item.textColor,
			disabled = item.disabled == true,
			highlight = item.highlight == true,
			reducedMotion = props.reducedMotion,
			layoutOrder = index,
		})
	end
	return React.createElement(Row, { height = props.height or 46, gap = gap, order = props.order, children = children })
end

local function Tile(props)
	return React.createElement("frame", {
		Size = props.size or UDim2.new(0.31, 0, 1, 0),
		BackgroundColor3 = props.fill or Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order or 0,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("uistroke", { Color = props.color or Palette.line, Thickness = 2, Transparency = 0.2 }),
		Label = React.createElement(Text, {
			value = props.value,
			size = props.textSize or 22,
			color = props.color or Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 11,
		}),
	})
end

local function gradient(top, bottom, rotation)
	return React.createElement("uigradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

local function Marquee(props)
	local count = props.count or 16
	local refs = React.useRef({})
	local bulbs = {}
	for index = 1, count do
		bulbs["b" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = props.color or Palette.mango,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ref = function(instance)
				refs.current[index] = instance
			end,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	bulbs.Layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	useRender(function(_, now)
		local speed = if props.mode == "win" then 14 elseif props.mode == "spin" then 9 else 3.2
		for index, bulb in refs.current do
			if bulb.Parent ~= nil then
				local wave = (math.sin(now * speed - index * 0.7) + 1) / 2
				if props.mode == "win" then
					wave = if math.floor(now * 8 + index % 2) % 2 == 0 then 1 else 0.2
				end
				bulb.BackgroundTransparency = 0.78 - 0.78 * wave
			end
		end
	end, not props.reducedMotion)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = props.position,
		LayoutOrder = props.order or 0,
	}, bulbs)
end

local function Confetti(props)
	local count = 46
	local running = React.useRef(false)
	local refs = React.useRef({})
	local sim = React.useRef({})
	local last = React.useRef(props.token)
	React.useEffect(function()
		if props.token == last.current then
			return
		end
		last.current = props.token
		local power = props.power or 1
		running.current = true
		for index = 1, count do
			local p = sim.current[index] or {}
			p.x = 0.5 + (math.random() - 0.5) * 0.3
			p.y = 1.0
			p.vx = (math.random() - 0.5) * 1.1 * power
			p.vy = -(0.9 + math.random() * 1.2) * power
			p.spin = math.random() * 6
			p.life = 1.8 + math.random() * 0.8
			p.age = if index <= count * math.min(1, 0.35 + power * 0.4) then 0 else p.life
			sim.current[index] = p
		end
	end, { props.token })
	useRender(function(dt)
		if not running.current then
			return
		end
		local alive = false
		for index = 1, count do
			local p = sim.current[index]
			local piece = refs.current[index]
			if piece ~= nil and piece.Parent ~= nil then
				if p == nil or p.age >= p.life then
					piece.Visible = false
				else
					p.age += dt
					alive = true
					p.vy += 1.9 * dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					piece.Visible = true
					piece.Position = UDim2.fromScale(p.x, p.y)
					piece.Size = UDim2.fromOffset(14, math.max(2, math.abs(math.cos(p.spin + p.age * 9)) * 14))
					piece.BackgroundTransparency = math.clamp((p.age - (p.life - 0.5)) / 0.5, 0, 1)
				end
			end
		end
		running.current = alive
	end, not props.reducedMotion)
	local pieces = {}
	local colors = { Palette.mango, Palette.brass, Palette.cream, Palette.coral, Palette.cyan }
	for index = 1, count do
		pieces["p" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colors[(index % #colors) + 1],
			BorderSizePixel = 0,
			ref = function(instance)
				refs.current[index] = instance
			end,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Active = false }, pieces)
end

local function ShineBar(props)
	local fill = React.useRef(nil)
	local shine = React.useRef(nil)
	local shown = React.useRef(0)
	useRender(function(dt, now)
		shown.current += (props.value - shown.current) * math.min(1, dt * 5)
		if fill.current ~= nil and fill.current.Parent ~= nil then
			fill.current.Size = UDim2.fromScale(shown.current, 1)
		end
		if shine.current ~= nil and shine.current.Parent ~= nil then
			shine.current.Offset = Vector2.new((now * 0.6) % 2 - 1, 0)
		end
	end, not props.reducedMotion)
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Palette.panelSoft, BorderSizePixel = 0, LayoutOrder = props.order or 0 }, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) }),
		Fill = React.createElement("frame", { Size = UDim2.fromScale(if props.reducedMotion then props.value else 0, 1), BackgroundColor3 = props.color or Palette.mango, BorderSizePixel = 0, ref = fill }, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) }),
			Shine = React.createElement("uigradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }),
				ref = shine,
			}),
		}),
	})
end

return {
	Stack = Stack, Line = Line, Row = Row, Buttons = Buttons, Tile = Tile, gradient = gradient,
	Marquee = Marquee, Confetti = Confetti, ShineBar = ShineBar,
	sfx = sfx, useRender = useRender, outCubic = outCubic,
}
end

__defs["BazaarView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local Panel = _ui.Panel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local Kit = __load("BazaarKit")
local Stack, Line, Row, Buttons, Tile = Kit.Stack, Kit.Line, Kit.Row, Kit.Buttons, Kit.Tile
local Marquee, Confetti, ShineBar = Kit.Marquee, Kit.Confetti, Kit.ShineBar
local sfx, useRender, outCubic = Kit.sfx, Kit.useRender, Kit.outCubic

local TABS = {
	{ id = "Bank", label = "Bank", accent = Palette.mint },
	{ id = "Market", label = "Black Market", accent = Palette.violet },
	{ id = "Lottery", label = "Lottery", accent = Palette.mango },
	{ id = "Contracts", label = "Contracts", accent = Palette.cyan },
}

local TERM_NAMES = { T1 = "1 hour", T6 = "6 hours", T24 = "24 hours" }
local SHARES = { "10%", "25%", "50%", "All" }
local WITHDRAW_SHARES = { "25%", "50%", "All" }

local function percent(rate)
	return string.format("%d%%", math.floor(rate * 100 + 0.5))
end

local function useClock()
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					setNow(workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})
	return now
end

local function DealCard(props)
	local offer = props.offer
	local soldOut = offer.Left <= 0
	local pips = {}
	for index = 1, offer.Stock do
		pips["p" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = if index <= offer.Left then Palette.violet else Palette.panelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	pips.Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("uistroke", { Color = if soldOut then Palette.line else Palette.violet, Thickness = 2, Transparency = 0.3 }),
		Badge = React.createElement("frame", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = if soldOut then Palette.line else Palette.coral, BorderSizePixel = 0 }, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Label = React.createElement(Text, { value = `-{percent(offer.Discount)}`, size = 14, color = Palette.ink, weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center, fit = true, minSize = 9 }),
		}),
		Name = React.createElement(Text, { value = offer.Name, size = 14, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(68, 6), sizeConstraint = UDim2.new(1, -170, 0, 18) }),
		Gives = React.createElement(Text, { value = formatReward(offer.Reward), size = 11, color = Palette.muted, position = UDim2.fromOffset(68, 24), sizeConstraint = UDim2.new(1, -170, 0, 16) }),
		Stock = React.createElement("frame", { Size = UDim2.new(1, -170, 0, 12), Position = UDim2.fromOffset(68, 46), BackgroundTransparency = 1, BorderSizePixel = 0 }, pips),
		Buy = React.createElement(Button, {
			text = if soldOut then "SOLD OUT" else compactNumber(offer.Price),
			onClick = props.onBuy,
			size = UDim2.fromOffset(94, 44),
			position = UDim2.new(1, -102, 0, 11),
			color = if soldOut then Palette.panelSoft else Palette.violet,
			textColor = if soldOut then Palette.muted else Palette.ink,
			disabled = soldOut or props.busy,
			highlight = not soldOut and not props.busy,
			reducedMotion = props.reducedMotion,
		}),
	})
end

local function ContractRow(props)
	local contract = props.contract
	local text, color, disabled = "CLAIM", Palette.cyan, not contract.Claimable or props.busy
	if contract.Claimed then
		text, color, disabled = "CLAIMED", Palette.panelSoft, true
	elseif not contract.Claimable then
		text, color = `{contract.Progress}/{contract.Target}`, Palette.panelSoft
	end
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Palette.panelSoft, BorderSizePixel = 0, LayoutOrder = props.order }, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("uistroke", { Color = if contract.Claimable then Palette.cyan else Palette.line, Thickness = 2, Transparency = 0.3 }),
		Title = React.createElement(Text, { value = `{contract.Name}: {contract.Text}`, size = 13, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(12, 6), sizeConstraint = UDim2.new(1, -130, 0, 18) }),
		Reward = React.createElement(Text, { value = formatReward(contract.Reward), size = 11, color = Palette.muted, position = UDim2.fromOffset(12, 24), sizeConstraint = UDim2.new(1, -130, 0, 16) }),
		Bar = React.createElement("frame", { Size = UDim2.new(1, -130, 0, 10), Position = UDim2.fromOffset(12, 46), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
			Fill = React.createElement(ShineBar, { value = contract.Progress / contract.Target, color = Palette.cyan, reducedMotion = props.reducedMotion }),
		}),
		Claim = React.createElement(Button, {
			text = text,
			onClick = props.onClaim,
			size = UDim2.fromOffset(100, 42),
			position = UDim2.new(1, -108, 0, 11),
			color = color,
			textColor = if contract.Claimable then Palette.ink else nil,
			disabled = disabled,
			highlight = contract.Claimable and not props.busy,
			reducedMotion = props.reducedMotion,
		}),
	})
end

local function TicketStrip(props)
	local kids = { Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index = 1, props.max do
		kids["t" .. index] = React.createElement("frame", {
			Size = UDim2.new(1 / props.max, -3, 0, 22),
			BackgroundColor3 = if index <= props.mine then Palette.mango else Palette.panelSoft,
			BackgroundTransparency = if index <= props.mine then 0 else 0.3,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }) })
	end
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = props.order }, kids)
end

local PROP_TONES = {
	steel = Color3.fromRGB(118, 126, 146),
	dark = Color3.fromRGB(30, 32, 44),
	brass = Color3.fromRGB(214, 166, 84),
	wood = Color3.fromRGB(104, 66, 42),
	paper = Color3.fromRGB(236, 222, 188),
	ink = Color3.fromRGB(70, 56, 48),
	wax = Color3.fromRGB(170, 38, 56),
	glass = Color3.fromRGB(186, 222, 255),
}

local function propPart(model, shape, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local FACE_Z = CFrame.Angles(0, math.rad(90), 0)
local FACE_Y = CFrame.Angles(0, 0, math.rad(90))

-- Each counter gets its own hand-built prop; builders return (cameraDistance, animate(t)).
local PROP_BUILDERS = {}

function PROP_BUILDERS.Bank(model)
	propPart(model, nil, Vector3.new(5.4, 5.4, 1.6), CFrame.new(0, 0, -0.9), PROP_TONES.dark, Enum.Material.Metal)
	propPart(model, Enum.PartType.Cylinder, Vector3.new(0.5, 4.7, 4.7), CFrame.new(0, 0, -0.05) * FACE_Z, PROP_TONES.brass, Enum.Material.Metal)
	local spinning = {}
	local function spin(part)
		table.insert(spinning, { part = part, base = part.CFrame })
	end
	spin(propPart(model, Enum.PartType.Cylinder, Vector3.new(0.6, 4.2, 4.2), CFrame.new(0, 0, 0.3) * FACE_Z, PROP_TONES.steel, Enum.Material.Metal))
	for bolt = 0, 11 do
		local angle = bolt * math.pi / 6
		spin(propPart(model, Enum.PartType.Ball, Vector3.new(0.32, 0.32, 0.32), CFrame.new(math.cos(angle) * 1.75, math.sin(angle) * 1.75, 0.62), PROP_TONES.brass, Enum.Material.Metal))
	end
	spin(propPart(model, Enum.PartType.Cylinder, Vector3.new(0.5, 1, 1), CFrame.new(0, 0, 0.8) * FACE_Z, PROP_TONES.brass, Enum.Material.Metal))
	for spoke = 0, 2 do
		spin(propPart(model, nil, Vector3.new(2.8, 0.18, 0.18), CFrame.new(0, 0, 1.05) * CFrame.Angles(0, 0, spoke * math.pi / 3), PROP_TONES.brass, Enum.Material.Metal))
	end
	return 13, function(t)
		local angle = t * 0.45 + 0.12 * math.sin(t * 2.4)
		local turn = CFrame.Angles(0, 0, angle)
		for _, entry in spinning do
			entry.part.CFrame = turn * entry.base
		end
	end
end

function PROP_BUILDERS.Market(model)
	propPart(model, Enum.PartType.Cylinder, Vector3.new(0.35, 2.8, 2.8), CFrame.new(0, -2.5, 0) * FACE_Y, PROP_TONES.wood, Enum.Material.Wood)
	propPart(model, nil, Vector3.new(0.3, 4.4, 0.3), CFrame.new(0, -0.2, 0), PROP_TONES.brass, Enum.Material.Metal)
	propPart(model, Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 2.15, 0), PROP_TONES.brass, Enum.Material.Metal)
	local beam = propPart(model, nil, Vector3.new(5, 0.2, 0.22), CFrame.new(0, 1.8, 0), PROP_TONES.brass, Enum.Material.Metal)
	local pans = {}
	for side = -1, 1, 2 do
		local group = {}
		local function add(part, offset)
			table.insert(group, { part = part, offset = offset })
		end
		for chain = 0, 2 do
			local angle = chain * math.pi * 2 / 3
			local foot = Vector3.new(math.cos(angle) * 0.65, -1.6, math.sin(angle) * 0.65)
			local mid = foot / 2
			add(propPart(model, nil, Vector3.new(0.05, foot.Magnitude, 0.05), CFrame.new(), PROP_TONES.brass, Enum.Material.Metal), CFrame.lookAt(mid, foot) * CFrame.Angles(math.rad(90), 0, 0))
		end
		add(propPart(model, Enum.PartType.Cylinder, Vector3.new(0.14, 1.6, 1.6), CFrame.new(), PROP_TONES.brass, Enum.Material.Metal), CFrame.new(0, -1.65, 0) * FACE_Y)
		if side < 0 then
			for coin = 0, 2 do
				add(propPart(model, Enum.PartType.Cylinder, Vector3.new(0.1, 0.62, 0.62), CFrame.new(), Color3.fromRGB(240, 196, 92), Enum.Material.Metal), CFrame.new(0.08 * coin, -1.5 + coin * 0.11, 0) * FACE_Y)
			end
		else
			add(propPart(model, Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), CFrame.new(), Color3.fromRGB(176, 120, 255), Enum.Material.Neon), CFrame.new(0, -1.3, 0))
		end
		pans[side] = group
	end
	return 12, function(t)
		local tilt = 0.16 * math.sin(t * 1.25)
		local beamCf = CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, tilt)
		beam.CFrame = beamCf
		for side, group in pans do
			local anchor = (beamCf * CFrame.new(side * 2.35, 0, 0)).Position
			for _, entry in group do
				entry.part.CFrame = CFrame.new(anchor) * entry.offset
			end
		end
	end
end

function PROP_BUILDERS.Lottery(model)
	propPart(model, nil, Vector3.new(3.4, 0.4, 1.8), CFrame.new(0, -2.55, 0), PROP_TONES.wood, Enum.Material.Wood)
	for side = -1, 1, 2 do
		propPart(model, nil, Vector3.new(0.22, 3.2, 0.22), CFrame.new(side * 1.25, -1.1, 0) * CFrame.Angles(0, 0, side * -0.32), PROP_TONES.brass, Enum.Material.Metal)
	end
	propPart(model, nil, Vector3.new(4.9, 0.16, 0.16), CFrame.new(0, 0.4, 0), PROP_TONES.brass, Enum.Material.Metal)
	propPart(model, Enum.PartType.Ball, Vector3.new(4, 4, 4), CFrame.new(0, 0.4, 0), PROP_TONES.glass, Enum.Material.Glass, 0.62)
	local tones = { Color3.fromRGB(255, 196, 92), Color3.fromRGB(120, 240, 180), Color3.fromRGB(255, 120, 150), Color3.fromRGB(176, 120, 255), Color3.fromRGB(120, 220, 255) }
	local balls = {}
	for index = 1, 11 do
		balls[index] = propPart(model, Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.4, 0), tones[(index - 1) % #tones + 1])
	end
	return 12, function(t)
		for index, ball in balls do
			local theta = t * (1.1 + index * 0.07) + index * 2.1
			local radius = 1.05 + 0.22 * math.sin(index)
			ball.CFrame = CFrame.new(math.cos(theta) * radius, 0.4 + math.sin(theta * 1.3 + index) * radius * 0.7, math.sin(theta) * radius * 0.6)
		end
	end
end

function PROP_BUILDERS.Contracts(model)
	local parts = {}
	local function add(part)
		table.insert(parts, { part = part, base = part.CFrame })
		return part
	end
	add(propPart(model, nil, Vector3.new(3.2, 3.6, 0.05), CFrame.new(0, 0, 0), PROP_TONES.paper))
	for roll = -1, 1, 2 do
		add(propPart(model, Enum.PartType.Cylinder, Vector3.new(3.7, 0.46, 0.46), CFrame.new(0, roll * 1.85, 0), PROP_TONES.paper:Lerp(PROP_TONES.wood, 0.25)))
		for knob = -1, 1, 2 do
			add(propPart(model, Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.34), CFrame.new(knob * 1.95, roll * 1.85, 0), PROP_TONES.wood, Enum.Material.Wood))
		end
	end
	local widths = { 2.3, 2.5, 1.9, 2.4, 1.6, 2.2 }
	for line, width in widths do
		add(propPart(model, nil, Vector3.new(width, 0.09, 0.02), CFrame.new(-1.25 + width / 2, 1.2 - line * 0.36, 0.04), PROP_TONES.ink))
	end
	add(propPart(model, Enum.PartType.Cylinder, Vector3.new(0.12, 0.8, 0.8), CFrame.new(0.85, -1.15, 0.08) * FACE_Z, PROP_TONES.wax))
	add(propPart(model, nil, Vector3.new(0.18, 0.7, 0.02), CFrame.new(0.7, -1.6, 0.06) * CFrame.Angles(0, 0, 0.3), PROP_TONES.wax))
	add(propPart(model, nil, Vector3.new(0.18, 0.7, 0.02), CFrame.new(1.0, -1.6, 0.06) * CFrame.Angles(0, 0, -0.3), PROP_TONES.wax))
	add(propPart(model, nil, Vector3.new(0.1, 2.8, 0.05), CFrame.new(1.6, 0.4, 0.35) * CFrame.Angles(0, 0, -0.45), Color3.fromRGB(246, 244, 236)))
	add(propPart(model, nil, Vector3.new(0.34, 1.6, 0.03), CFrame.new(1.85, 0.95, 0.36) * CFrame.Angles(0, 0, -0.45), Color3.fromRGB(230, 232, 240)))
	return 11.5, function(t)
		local sway = CFrame.new(0, 0.08 * math.sin(t * 1.6), 0) * CFrame.Angles(0.05 * math.sin(t * 0.9), 0.32 * math.sin(t * 0.7), 0)
		for _, entry in parts do
			entry.part.CFrame = sway * entry.base
		end
	end
end

local function CounterProp(props)
	local viewport = React.useRef(nil)
	local animate = React.useRef(nil)
	React.useEffect(function()
		local frame = viewport.current
		if frame == nil then
			return nil
		end
		local model = Instance.new("Model")
		local builder = PROP_BUILDERS[props.kind] or PROP_BUILDERS.Bank
		local distance, step = builder(model)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.28, distance * 0.16, distance), Vector3.new(0, 0, 0))
		camera.Parent = frame
		frame.CurrentCamera = camera
		model.Parent = frame
		step(0.6)
		animate.current = step
		return function()
			animate.current = nil
			model:Destroy()
			camera:Destroy()
		end
	end, { props.kind })
	useRender(function(_, now)
		if animate.current then
			animate.current(now)
		end
	end, not props.reducedMotion, 30)
	return React.createElement("frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Halo = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = props.accent,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fade = React.createElement("uigradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }),
		}),
		View = React.createElement("viewportframe", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(128, 126, 150),
			LightColor = Color3.fromRGB(255, 240, 220),
			LightDirection = Vector3.new(-0.6, -1, -0.8),
			ref = viewport,
		}),
	})
end

local COUNTER_LINES = {
	Bank = "Savings earn by the hour. Lock a term for a better rate.",
	Market = "Hourly stock, the same for everyone. Few of each per player.",
	Lottery = "One winner every five minutes takes the pot.",
	Contracts = "A fresh board of merchant work every day.",
}

local function BazaarView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = false
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local reveal = useStagger(0, reducedMotion)
	local bazaar = state.Bazaar
	local now = useClock()

	local tab, setTab = require(script.Parent.Parent.BrowseKit).useLinkedTab("Bazaar", "Bank", props.initialTab)
	local tier, setTier = React.useState(2)
	local term, setTerm = React.useState("T6")
	local busy, setBusy = React.useState(false)
	local busyRef = React.useRef(false)
	local note, setNote = React.useState({ text = "Welcome to the Bazaar. Bank some flux, snap up a deal, or try your luck on a ticket.", good = nil })
	local fx, setFx = React.useState({ token = 0, power = 1 })
	local mode, setMode = React.useState("idle")
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	local function play(payload, cue, power)
		if busyRef.current or bazaar == nil then
			return
		end
		busyRef.current = true
		setBusy(true)
		sfx("bazaar_chip", 0.5)
		dispatch("BazaarPlay", payload, function(response)
			if not mounted.current then
				return
			end
			busyRef.current = false
			setBusy(false)
			if response.ok then
				setNote({ text = response.message or "", good = true })
				sfx(cue or "bazaar_buy", 0.7)
				if power then
					setFx({ token = fx.token + 1, power = power })
					setMode("win")
					task.delay(1.4, function()
						if mounted.current then
							setMode("idle")
						end
					end)
				end
			else
				setNote({ text = response.error or "That didn't go through.", good = false })
				sfx("bazaar_lose", 0.4, 1.3)
				Audio:play("error")
			end
		end)
	end

	if bazaar == nil then
		return React.createElement(PageScaffold, {
			gap = 0,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
			sections = { { id = "loading", height = 80, element = React.createElement(Text, { value = "The Bazaar is opening its shutters...", size = 14, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }) } },
		})
	end

	local accent = Palette.mint
	for _, entry in TABS do
		if entry.id == tab then
			accent = entry.accent
		end
	end
	local noteColor = if note.good == true then Palette.mint elseif note.good == false then Palette.coral else Palette.muted

	local function picker(order, labels, selected, onPick)
		local items = {}
		for index, label in labels do
			items[index] = {
				text = label,
				onClick = function()
					sfx("bazaar_chip", 0.4, 0.9 + index * 0.08)
					onPick(index)
				end,
				color = if selected == index then accent else Palette.panelSoft,
				textColor = if selected == index then Palette.ink else Palette.cream,
				disabled = busy,
			}
		end
		return React.createElement(Buttons, { items = items, height = 38, order = order, reducedMotion = reducedMotion })
	end

	local function bankBody()
		local bank = bazaar.Bank
		local open = bank.Term.Id ~= ""
		local left = math.max(0, bank.Term.EndsAt - now)
		local total = (bank.Term.Hours or 0) * 3600
		local termProgress = if open and total > 0 then math.clamp(1 - left / total, 0, 1) else 0
		local children = {
			React.createElement(Line, { value = "ASTRAL BANK", size = 11, color = Palette.mint, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 64, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `Savings {compactNumber(bank.Balance)}`, color = Palette.mint, textSize = 16, size = UDim2.new(0.48, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = `Interest {compactNumber(bank.Accrued)}`, color = Palette.mango, textSize = 16, size = UDim2.new(0.48, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
			picker(4, SHARES, tier, setTier),
			React.createElement(Buttons, { items = {
				{ text = "DEPOSIT", onClick = function() play({ Game = "Bank", Op = "Deposit", Tier = tier }, "bazaar_buy") end, color = Palette.mint, textColor = Palette.ink, disabled = busy, highlight = not busy },
				{ text = "WITHDRAW", onClick = function() play({ Game = "Bank", Op = "Withdraw", Tier = math.min(tier, 3) }, "bazaar_cash") end, color = Palette.panelSoft, disabled = busy },
				{ text = "COLLECT", onClick = function() play({ Game = "Bank", Op = "Collect" }, "bazaar_win_small", 1) end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
			}, height = 46, order = 5, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Savings earn {percent(bank.Rate)} an hour on up to {compactNumber(bank.Cap)} flux (two hours of your income). Interest builds for up to a day; collect it any time.`, size = 11, height = 44, order = 6 }),
			React.createElement(Line, { value = "TERM DEPOSIT", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 7 }),
		}
		if open then
			table.insert(children, React.createElement(Line, { value = `{compactNumber(bank.Term.Principal)} flux locked at {percent(bank.Term.Rate)} an hour. {if bank.Term.Matured then "Matured: ready to redeem." else clockText(left) .. " to go."}`, size = 12, color = Palette.cream, height = 34, order = 8 }))
			table.insert(children, React.createElement(ShineBar, { value = termProgress, color = Palette.violet, reducedMotion = reducedMotion, order = 9 }))
			table.insert(children, React.createElement(Buttons, { items = {
				{ text = "REDEEM", onClick = function() play({ Game = "Bank", Op = "Redeem" }, "bazaar_win_big", 1.5) end, color = Palette.mint, textColor = Palette.ink, disabled = busy or not bank.Term.Matured, highlight = bank.Term.Matured },
				{ text = "BREAK (NO INTEREST)", onClick = function() play({ Game = "Bank", Op = "Break" }, "bazaar_cash") end, color = Palette.panelSoft, disabled = busy },
			}, height = 44, order = 10, reducedMotion = reducedMotion }))
		else
			local labels = {}
			for index, entry in bank.Terms do
				labels[index] = `{TERM_NAMES[entry.Id] or entry.Id} {percent(entry.Rate)}/h`
			end
			local selected = 1
			for index, entry in bank.Terms do
				if entry.Id == term then
					selected = index
				end
			end
			table.insert(children, picker(8, labels, selected, function(index)
				setTerm(bank.Terms[index].Id)
			end))
			table.insert(children, React.createElement(Buttons, { items = {
				{ text = `LOCK {SHARES[tier]} FOR {TERM_NAMES[term] or term}`, onClick = function() play({ Game = "Bank", Op = "Term", Term = term, Tier = tier }, "bazaar_buy") end, color = Palette.violet, textColor = Palette.ink, disabled = busy, highlight = not busy },
			}, height = 46, order = 9, reducedMotion = reducedMotion }))
			table.insert(children, React.createElement(Line, { value = "Lock flux for a set time for a higher rate. Breaking it early returns the principal with no interest.", size = 11, height = 30, order = 10 }))
		end
		return children
	end

	local function marketBody()
		local market = bazaar.Market
		local children = {
			React.createElement(Line, { value = "BLACK MARKET", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{note.text}  New stock in {clockText(math.max(0, market.EndsAt - now))}.`, size = 12, color = noteColor, height = 34, order = 2 }),
		}
		for index, offer in market.Offers do
			children[#children + 1] = React.createElement(DealCard, {
				offer = offer,
				order = 2 + index,
				busy = busy,
				reducedMotion = reducedMotion,
				onBuy = function()
					play({ Game = "Market", Pick = offer.Id }, "bazaar_cash", 0.8)
				end,
			})
		end
		children[#children + 1] = React.createElement(Line, { value = "Four deals each hour, the same for everyone, 20% to 45% off, and only a few of each per player.", size = 11, height = 30, order = 20 })
		return children
	end

	local function lotteryBody()
		local lottery = bazaar.Lottery
		local last = lottery.Last
		local lastLine = "No draw yet."
		if last then
			lastLine = `Last draw: {last.Winner} won {compactNumber(last.Prize)} flux.`
		end
		local children = {
			React.createElement(Line, { value = "SERVER LOTTERY", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 78, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `Pot {compactNumber(lottery.Pot)}`, color = Palette.mango, textSize = 22, size = UDim2.new(0.6, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = clockText(math.max(0, lottery.NextAt - now)), color = Palette.cream, textSize = 20, size = UDim2.new(0.36, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(TicketStrip, { max = lottery.Max, mine = lottery.Mine, order = 3 }),
			React.createElement(Line, { value = `{note.text}  You hold {lottery.Mine} of {lottery.Max} tickets. {lastLine}`, size = 12, color = noteColor, height = 48, order = 4 }),
			React.createElement(Buttons, { items = {
				{ text = `1 TICKET ({compactNumber(lottery.Price)})`, onClick = function() play({ Game = "Lottery", Tier = 1 }, "bazaar_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
				{ text = "5 TICKETS", onClick = function() play({ Game = "Lottery", Tier = 2 }, "bazaar_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
				{ text = "20 TICKETS", onClick = function() play({ Game = "Lottery", Tier = 3 }, "bazaar_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
			}, height = 50, order = 5, reducedMotion = reducedMotion }),
		}
		if lottery.Prize ~= 0 then
			table.insert(children, React.createElement(Buttons, { items = { {
				text = `COLLECT PRIZE {compactNumber(lottery.Prize)}`,
				onClick = function()
					sfx("bazaar_jackpot", 0.8)
					play({ Game = "Lottery", Op = "Prize" }, "bazaar_win_big", 2)
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy,
				highlight = true,
			} }, height = 54, order = 6, reducedMotion = reducedMotion }))
		end
		table.insert(children, React.createElement(Line, { value = "A draw every five minutes: one winner takes the pot, less the house's tenth. A ticket costs 1% of your flux. Only players still in the server can win; with nobody to win, the pot rolls over.", size = 11, height = 58, order = 7 }))
		return children
	end

	local function contractsBody()
		local children = {
			React.createElement(Line, { value = "MERCHANT CONTRACTS", size = 11, color = Palette.cyan, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{note.text}  A fresh board every day.`, size = 12, color = noteColor, height = 34, order = 2 }),
		}
		for index, contract in bazaar.Contracts do
			children[#children + 1] = React.createElement(ContractRow, {
				contract = contract,
				order = 2 + index,
				busy = busy,
				reducedMotion = reducedMotion,
				onClaim = function()
					play({ Game = "Contracts", Pick = contract.Id }, "bazaar_rank", 1.4)
				end,
			})
		end
		children[#children + 1] = React.createElement(Line, { value = "Contracts count what you do from the moment today's board is drawn: deals, deposits, tickets and interest.", size = 11, height = 44, order = 20 })
		return children
	end

	local bodies = { Bank = bankBody, Market = marketBody, Lottery = lotteryBody, Contracts = contractsBody }
	local heights = { Bank = 548, Market = 458, Lottery = 440, Contracts = 366 }

	return React.createElement(PageScaffold, {
		gap = 8,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = 112,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reveal = reveal,
					reducedMotion = reducedMotion,
				}, React.createElement(Marquee, { position = UDim2.fromOffset(0, 0), mode = mode, reducedMotion = reducedMotion, color = accent }), React.createElement(Text, {
					value = "ASTRAL BAZAAR",
					size = 10,
					color = accent,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 14),
					sizeConstraint = UDim2.new(1, -112, 0, 14),
				}), React.createElement(Text, {
					value = `Flux {compactNumber(state.Cash)}`,
					size = 22,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 30),
					sizeConstraint = UDim2.new(1, -112, 0, 30),
				}), React.createElement(Text, {
					value = COUNTER_LINES[tab] or "",
					size = 11,
					color = Palette.muted,
					position = UDim2.fromOffset(0, 62),
					sizeConstraint = UDim2.new(1, -112, 0, 30),
				}), React.createElement(CounterProp, {
					kind = tab,
					accent = accent,
					reducedMotion = reducedMotion,
					size = UDim2.fromOffset(104, 104),
					position = UDim2.new(1, 4, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
				})),
			},
			{
				id = "tabs",
				height = 48,
				element = React.createElement(SegmentedTabs, {
					options = TABS,
					value = tab,
					onChange = function(id)
						sfx("bazaar_tick", 0.5)
						setTab(id)
					end,
					columns = 4,
					accent = accent,
					size = UDim2.new(1, 0, 0, 48),
					reducedMotion = reducedMotion,
				}),
			},
			{
				id = "body",
				height = heights[tab] or 420,
				element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
					Panel = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = accent,
						background = Palette.panelRaised,
						padding = Layout.cardPadding,
						reducedMotion = reducedMotion,
					}, React.createElement(Stack, { gap = 8, children = bodies[tab]() })),
					Coins = React.createElement(Confetti, { token = fx.token, power = fx.power, reducedMotion = reducedMotion }),
				}),
			},
		},
	})
end

return {
	BazaarView = BazaarView,
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
