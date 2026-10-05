--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then
		return hit.value
	end
	local def = __defs[name]
	if def == nil then
		error("PagesCasino: unknown module " .. tostring(name), 2)
	end
	if __loading[name] then
		error("PagesCasino: cyclic require of member " .. name, 2)
	end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then
		error(value, 0)
	end
	__cache[name] = { value = value }
	return value
end

__defs["CasinoView"] = function()
	local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
	local RunService = game:GetService("RunService")
	local SoundService = game:GetService("SoundService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
	local CasinoSfx =
		require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("CasinoSfx"))
	local _format = require(script.Parent.Parent.CoreKit)("format")
	local compactNumber = _format.compactNumber
	local clockText = _format.clockText
	local formatReward = _format.formatReward
	local _motion = require(script.Parent.Parent.MotionKit)("motion")
	local useFlipperSpring = _motion.useFlipperSpring
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

	local TABS = {
		{ id = "Slots", label = "Slots", accent = Palette.mango },
		{ id = "Flip", label = "Coin Flip", accent = Palette.cyan },
		{ id = "HighLow", label = "High-Low", accent = Palette.violet },
		{ id = "Roulette", label = "Roulette", accent = Palette.coral },
		{ id = "Scratch", label = "Scratch", accent = Palette.pink },
		{ id = "Exchange", label = "Exchange", accent = Palette.mint },
		{ id = "Club", label = "Club", accent = Palette.mango },
		{ id = "TableRoulette", label = "Table Roulette", accent = Palette.cyan },
		{ id = "QuantumRoulette", label = "Quantum", accent = Palette.violet },
		{ id = "CardTower", label = "Card Tower", accent = Palette.mint },
		{ id = "DiceTable", label = "Dice Table", accent = Palette.coral },
	}

	local SYMBOL_COLORS = {
		Ember = Palette.coral,
		Dust = Palette.cyan,
		Core = Palette.mint,
		Comet = Palette.violet,
		Star = Palette.mango,
		Nova = Palette.pink,
		Spark = Palette.mango,
	}
	local SYMBOL_GLYPH = { Ember = "E", Dust = "D", Core = "C", Comet = "K", Star = "S", Nova = "N", Spark = "*" }
	local STRIPS = {
		{
			"Ember",
			"Dust",
			"Core",
			"Ember",
			"Comet",
			"Dust",
			"Ember",
			"Star",
			"Core",
			"Dust",
			"Ember",
			"Nova",
			"Core",
			"Ember",
			"Dust",
			"Comet",
			"Ember",
			"Dust",
		},
		{
			"Dust",
			"Ember",
			"Comet",
			"Dust",
			"Core",
			"Ember",
			"Dust",
			"Ember",
			"Nova",
			"Core",
			"Ember",
			"Dust",
			"Star",
			"Ember",
			"Core",
			"Dust",
			"Comet",
			"Ember",
		},
		{
			"Core",
			"Ember",
			"Dust",
			"Ember",
			"Star",
			"Dust",
			"Comet",
			"Ember",
			"Core",
			"Dust",
			"Ember",
			"Dust",
			"Nova",
			"Ember",
			"Core",
			"Comet",
			"Dust",
			"Ember",
		},
	}
	local CYCLE = 18
	local REPS = 2
	local CARD_NAMES = { [1] = "A", [11] = "J", [12] = "Q", [13] = "K" }
	local WHEEL = {
		0,
		32,
		15,
		19,
		4,
		21,
		2,
		25,
		17,
		34,
		6,
		27,
		13,
		36,
		11,
		30,
		8,
		23,
		10,
		5,
		24,
		16,
		33,
		1,
		20,
		14,
		31,
		9,
		22,
		18,
		29,
		7,
		28,
		12,
		35,
		3,
		26,
	}
	local RED = {
		[1] = true,
		[3] = true,
		[5] = true,
		[7] = true,
		[9] = true,
		[12] = true,
		[14] = true,
		[16] = true,
		[18] = true,
		[19] = true,
		[21] = true,
		[23] = true,
		[25] = true,
		[27] = true,
		[30] = true,
		[32] = true,
		[34] = true,
		[36] = true,
	}

	local function cardName(card)
		return CARD_NAMES[card] or tostring(card)
	end

	local function percent(chance)
		return string.format("%d%%", math.floor(chance * 100 + 0.5))
	end

	local function times(multiplier)
		if multiplier >= 100 then
			return string.format("x%d", math.floor(multiplier + 0.5))
		end
		return string.format("x%.2f", multiplier)
	end

	local function outCubic(x)
		return 1 - (1 - math.clamp(x, 0, 1)) ^ 3
	end

	local function outBack(x)
		x = math.clamp(x, 0, 1)
		local c1 = 1.70158
		return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end

	local function outBounce(x)
		x = math.clamp(x, 0, 1)
		if x < 1 / 2.75 then
			return 7.5625 * x * x
		elseif x < 2 / 2.75 then
			x -= 1.5 / 2.75
			return 7.5625 * x * x + 0.75
		elseif x < 2.5 / 2.75 then
			x -= 2.25 / 2.75
			return 7.5625 * x * x + 0.9375
		end
		x -= 2.625 / 2.75
		return 7.5625 * x * x + 0.984375
	end

	local frameLoop = {
		connection = nil :: RBXScriptConnection?,
		entries = {} :: { [any]: boolean },
		count = 0,
		scratch = {} :: { any },
	}

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
		local id = CasinoSfx[name]
		if type(id) ~= "number" or id <= 0 then
			return nil
		end
		local sound = Instance.new("Sound")
		sound.Name = "CasinoSfx"
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = volume or 0.7
		sound.PlaybackSpeed = speed or 1
		sound.Looped = looped == true
		sound.SoundGroup = groupOf()
		sound.Parent = SoundService
		return sound
	end

	local function sfx(name, volume, speed)
		local sound = makeSound(name, volume, speed, false)
		if sound == nil then
			return
		end
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end

	local function loopSfx(name, volume, speed)
		local sound = makeSound(name, volume, speed, true)
		if sound == nil then
			return function() end
		end
		sound:Play()
		return function()
			sound:Stop()
			sound:Destroy()
		end
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
		local list = {
			Layout = React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, props.gap or 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		}
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
		return React.createElement(
			Row,
			{ height = props.height or 46, gap = gap, order = props.order, children = children }
		)
	end

	local function Tile(props)
		return React.createElement("frame", {
			Size = props.size or UDim2.new(0.31, 0, 1, 0),
			BackgroundColor3 = props.fill or Palette.panelSoft,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement(
				"uistroke",
				{ Color = props.color or Palette.line, Thickness = 2, Transparency = 0.2 }
			),
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

	local function Gem(props)
		local color = SYMBOL_COLORS[props.id] or Palette.cream
		local jewel = props.size * 0.42
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Jewel = React.createElement("frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.44),
				Size = UDim2.fromOffset(jewel, jewel),
				Rotation = 45,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.22, 0) }),
				Fill = gradient(Color3.new(1, 1, 1), color, 135),
				Stroke = React.createElement(
					"uistroke",
					{ Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.45 }
				),
			}),
			Glyph = React.createElement(Text, {
				value = SYMBOL_GLYPH[props.id] or "?",
				size = math.floor(props.size * 0.3),
				color = Palette.ink,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.new(1, 0, 0, props.size * 0.4),
				position = UDim2.new(0, 0, 0.44, -props.size * 0.2),
				zIndex = 3,
			}),
			Name = React.createElement(Text, {
				value = string.upper(props.id),
				size = 9,
				color = color,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.new(1, 0, 0, 12),
				position = UDim2.new(0, 0, 1, -13),
			}),
		})
	end

	local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
	local NEON, METAL, PLASTIC = Enum.Material.Neon, Enum.Material.Metal, Enum.Material.SmoothPlastic

	local function solid(parent, shape, size, color, material, cframe)
		local part = Instance.new("Part")
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = material or PLASTIC
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = cframe
		part.Parent = parent
		return part
	end

	local function newModel(viewport)
		local world = viewport:FindFirstChild("CasinoScene")
		if not world then
			world = Instance.new("WorldModel")
			world.Name = "CasinoScene"
			world.Parent = viewport
		end
		local model = Instance.new("Model")
		model.WorldPivot = CFrame.new()
		model.Parent = world
		return model
	end

	local KIT_YAW = 0
	local KIT_FACE = CFrame.Angles(0, KIT_YAW, 0)
	local SYMBOL_PIECE = {
		Ember = "Ember",
		Spark = "Ember",
		Dust = "Dust",
		Core = "Core",
		Comet = "Comet",
		Star = "Star",
		Nova = "Nova",
	}
	local kitListeners = {}
	local kitWatch = nil
	local function kitFolder()
		local folder = ReplicatedStorage:FindFirstChild("CasinoKit")
		return if folder ~= nil and folder:IsA("Folder") then folder else nil
	end
	local function kitPiece(name, fit)
		local folder = kitFolder()
		local source = folder and folder:FindFirstChild("Casino_" .. name)
		if source == nil or not source:IsA("MeshPart") then
			return nil
		end
		local part = source:Clone()
		local size = part.Size
		local largest = math.max(size.X, size.Y, size.Z)
		if fit ~= nil and largest > 1e-3 then
			part.Size = size * (fit / largest)
		end
		return part, (if fit ~= nil and largest > 1e-3 then fit / largest else 1)
	end
	local function useKitReady()
		local ready, setReady = React.useState(kitFolder() ~= nil)
		React.useEffect(function()
			if ready then
				return nil
			end
			local listener = function()
				setReady(true)
			end
			kitListeners[listener] = true
			if kitWatch == nil then
				kitWatch = ReplicatedStorage.ChildAdded:Connect(function(child)
					if child.Name == "CasinoKit" then
						for each in kitListeners do
							task.defer(each)
						end
					end
				end)
			end
			return function()
				kitListeners[listener] = nil
			end
		end, { ready })
		return ready
	end

	local function addSymbol(parent, id, at, scale)
		local mesh = kitPiece(SYMBOL_PIECE[id] or "Star", 1.02 * scale)
		if mesh ~= nil then
			mesh.CFrame = at * KIT_FACE
			mesh.Parent = parent
			return
		end
		local color = SYMBOL_COLORS[id] or Palette.cream
		local function put(shape, size, paint, material, offset, rotation)
			return solid(
				parent,
				shape,
				size * scale,
				paint,
				material,
				at * CFrame.new(offset * scale) * (rotation or CFrame.identity)
			)
		end
		if id == "Ember" or id == "Spark" then
			put(BALL, Vector3.one * 0.95, color, PLASTIC, Vector3.zero)
			put(BALL, Vector3.one * 0.55, Color3.fromRGB(255, 214, 120), NEON, Vector3.new(0, 0, -0.12))
			for i = 1, 3 do
				put(
					BLOCK,
					Vector3.new(0.16, 0.42, 0.16),
					Color3.fromRGB(255, 160, 70),
					NEON,
					Vector3.new((i - 2) * 0.26, 0.5, 0),
					CFrame.Angles(0, 0, (i - 2) * -0.35)
				)
			end
		elseif id == "Dust" then
			local spots = {
				Vector3.new(0, 0, 0),
				Vector3.new(0.34, 0.2, 0.05),
				Vector3.new(-0.32, 0.24, 0),
				Vector3.new(0.2, -0.3, -0.05),
				Vector3.new(-0.22, -0.28, 0.05),
				Vector3.new(0, 0.42, -0.05),
			}
			for i, offset in spots do
				put(BALL, Vector3.one * (0.34 - 0.03 * (i % 3)), color, if i % 2 == 0 then NEON else PLASTIC, offset)
			end
		elseif id == "Core" then
			put(BLOCK, Vector3.one * 0.78, color, PLASTIC, Vector3.zero, CFrame.Angles(0.6, 0.78, 0))
			put(BLOCK, Vector3.one * 0.46, Color3.new(1, 1, 1), NEON, Vector3.zero, CFrame.Angles(0.6, 0.78, 0))
		elseif id == "Comet" then
			put(BALL, Vector3.one * 0.7, color, PLASTIC, Vector3.new(-0.2, -0.15, 0))
			put(BALL, Vector3.one * 0.5, color, NEON, Vector3.new(0.12, 0.18, 0))
			put(BALL, Vector3.one * 0.34, color, NEON, Vector3.new(0.36, 0.4, 0))
			put(BALL, Vector3.one * 0.2, color, NEON, Vector3.new(0.54, 0.58, 0))
		elseif id == "Star" then
			for i = 0, 2 do
				put(
					BLOCK,
					Vector3.new(1.3, 0.24, 0.24),
					color,
					NEON,
					Vector3.zero,
					CFrame.Angles(0, 0, i * math.pi / 3)
				)
			end
			put(BALL, Vector3.one * 0.5, Palette.cream, NEON, Vector3.zero)
		elseif id == "Nova" then
			put(BALL, Vector3.one * 0.8, color, NEON, Vector3.zero)
			for i = 0, 7 do
				local a = i / 8 * math.tau
				put(
					BALL,
					Vector3.one * 0.2,
					Palette.cream,
					NEON,
					Vector3.new(math.cos(a) * 0.62, math.sin(a) * 0.62, 0)
				)
			end
		end
	end

	local function View3D(props)
		local scene = React.useRef(nil)
		local host = React.useRef(nil)
		local builtWithKit = React.useRef(false)
		local kitReady = useKitReady()
		local function build(viewport)
			viewport:ClearAllChildren()
			local camera = Instance.new("Camera")
			camera.Name = "CasinoCamera"
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			builtWithKit.current = kitFolder() ~= nil
			scene.current = props.build(viewport, camera)
			if props.onScene then
				props.onScene(scene.current)
			end
		end
		React.useEffect(function()
			local viewport = host.current
			if kitReady and viewport ~= nil and scene.current ~= nil and not builtWithKit.current then
				build(viewport)
			end
		end, { kitReady })
		return React.createElement("viewportframe", {
			Name = "CasinoViewport",
			Active = false,
			Size = props.size or UDim2.fromScale(1, 1),
			Position = props.position,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Ambient = props.ambient or Color3.fromRGB(155, 170, 195),
			LightColor = props.lightColor or Color3.fromRGB(255, 246, 225),
			LightDirection = props.lightDirection or Vector3.new(-0.5, -0.8, 1),
			ZIndex = props.zIndex,
			LayoutOrder = props.order or 0,
			ref = function(viewport)
				host.current = viewport
				if viewport ~= nil and scene.current == nil then
					build(viewport)
				end
			end,
		})
	end

	local VISIBLE_CELLS = 3
	local function buildDrum(index)
		return function(viewport, camera)
			local model = newModel(viewport)
			local radius = 1.7
			local drum = kitPiece("Drum", (radius + 0.06) * 2)
			if drum ~= nil then
				drum.CFrame = KIT_FACE
				drum.Parent = model
			else
				solid(
					model,
					CYL,
					Vector3.new(1.3, radius * 2 - 0.12, radius * 2 - 0.12),
					Color3.fromRGB(34, 26, 40),
					PLASTIC,
					CFrame.new()
				)
				for _, x in { -0.62, 0.62 } do
					solid(
						model,
						CYL,
						Vector3.new(0.12, radius * 2 + 0.02, radius * 2 + 0.02),
						Palette.brass,
						PLASTIC,
						CFrame.new(x, 0, 0)
					)
				end
			end
			local cells = {}
			for k = 0, CYCLE - 1 do
				local cell = Instance.new("Model")
				addSymbol(
					cell,
					STRIPS[index][k + 1],
					CFrame.Angles(k / CYCLE * math.tau, 0, 0) * CFrame.new(0, 0, -(radius + 0.02)),
					0.62
				)
				cells[k] = cell
			end
			local front = nil
			local function showAround(pos)
				local nextFront = math.round(pos) % CYCLE
				if nextFront == front then
					return
				end
				front = nextFront
				for k, cell in cells do
					local gap = math.abs(k - nextFront)
					gap = math.min(gap, CYCLE - gap)
					local parent = if gap <= VISIBLE_CELLS then model else nil
					if cell.Parent ~= parent then
						cell.Parent = parent
					end
				end
			end
			local baseLight = Vector3.new(-0.5, -0.8, 1)
			local home = CFrame.lookAt(Vector3.new(0, 0, -6.4), Vector3.zero)
			local lastAngle = math.huge
			camera.FieldOfView = 24
			camera.CFrame = home
			showAround(0)
			return {
				set = function(pos)
					local angle = pos / CYCLE * math.tau
					if math.abs(angle - lastAngle) < 1e-4 then
						return
					end
					lastAngle = angle
					showAround(pos)
					local swing = CFrame.Angles(angle, 0, 0)
					camera.CFrame = swing * home
					viewport.LightDirection = swing:VectorToWorldSpace(baseLight)
				end,
			}
		end
	end

	local function GlassSheen(props)
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = props.zIndex or 6,
			Active = false,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = props.radius or UDim.new(0, 10) }),
			Fade = React.createElement("uigradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(0.22, 0.85),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	local function SlotMachine(props)
		local cellH = props.cellH or 52
		local reels = React.useRef(nil)
		local drums = React.useRef({})
		local blurs = React.useRef({})
		local band = React.useRef(nil)
		if reels.current == nil then
			reels.current = {}
			for index = 1, 3 do
				reels.current[index] =
					{ pos = (index - 1) * 5, vel = 0, mode = "idle", start = 0, goal = 0, stopAt = 0, t0 = 0, dur = 1 }
			end
		end

		local function paint()
			for index = 1, 3 do
				local drum = drums.current[index]
				if drum ~= nil then
					drum.set(reels.current[index].pos)
				end
			end
		end

		local function indexFor(strip, id, from)
			for cand = from, from + CYCLE - 1 do
				if strip[(cand % CYCLE) + 1] == id then
					return cand
				end
			end
			return from
		end

		React.useEffect(function()
			if props.phase == "idle" then
				for index = 1, 3 do
					local reel = reels.current[index]
					if reel.mode == "idle" and props.target then
						reel.pos = indexFor(STRIPS[index], props.target[index], math.floor(reel.pos))
					end
				end
				paint()
			end
		end, { props.phase, props.target })

		React.useEffect(function()
			if props.phase == "spin" then
				for index = 1, 3 do
					local reel = reels.current[index]
					reel.mode = "spin"
					reel.vel = math.max(reel.vel, 4)
				end
			elseif props.phase == "stop" and props.target then
				local now = os.clock()
				for index = 1, 3 do
					local reel = reels.current[index]
					reel.mode = "waiting"
					reel.stopAt = now + 0.2 + (index - 1) * 0.5
					reel.target = props.target[index]
				end
				if props.reducedMotion then
					for index = 1, 3 do
						local reel = reels.current[index]
						reel.pos = indexFor(STRIPS[index], reel.target, math.floor(reel.pos))
						reel.mode, reel.vel = "idle", 0
					end
					paint()
					if props.onSettled then
						props.onSettled()
					end
				end
			end
		end, { props.phase, props.token })

		useRender(function(dt, now)
			for index = 1, 3 do
				local reel = reels.current[index]
				if reel.mode == "spin" or reel.mode == "waiting" then
					reel.vel = math.min(reel.vel + 70 * dt, 26)
					reel.pos += reel.vel * dt
					if reel.mode == "waiting" and now >= reel.stopAt then
						reel.start = reel.pos
						reel.goal = indexFor(STRIPS[index], reel.target, math.ceil(reel.pos) + 14 + index * 3)
						reel.t0, reel.dur, reel.mode = now, 0.95 + 0.08 * index, "stopping"
					end
				elseif reel.mode == "stopping" then
					local k = (now - reel.t0) / reel.dur
					reel.pos = reel.start + (reel.goal - reel.start) * outBack(k)
					reel.vel = math.max(0, (reel.goal - reel.pos) * 6)
					if k >= 1 then
						reel.pos, reel.vel, reel.mode = reel.goal, 0, "idle"
						if props.onReel then
							props.onReel(index)
						end
						local all = true
						for _, other in reels.current do
							if other.mode ~= "idle" then
								all = false
							end
						end
						if all and props.onSettled then
							props.onSettled()
						end
					end
				end
				local drum = drums.current[index]
				if drum ~= nil then
					drum.set(reel.pos)
				end
				local blur = blurs.current[index]
				if blur ~= nil and blur.Parent ~= nil then
					blur.BackgroundTransparency = 1 - math.clamp(reel.vel / 26, 0, 1) * 0.28
				end
			end
			local glow = band.current
			if glow ~= nil and glow.Parent ~= nil then
				glow.Transparency = if props.flash then 0.1 + 0.35 * (math.sin(now * 14) + 1) / 2 else 0.6
			end
		end, not props.reducedMotion)

		local windows = {}
		for index = 1, 3 do
			windows["w" .. index] = React.createElement("frame", {
				Size = UDim2.new(0.31, 0, 0, cellH * 3),
				BackgroundColor3 = Palette.ink,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = index,
			}, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("uistroke", { Color = Palette.mango, Thickness = 2, Transparency = 0.35 }),
				Scene = React.createElement(View3D, {
					build = buildDrum(index),
					onScene = function(scene)
						drums.current[index] = scene
						scene.set(reels.current[index].pos)
					end,
				}),
				Shade = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BackgroundTransparency = 0.5,
					BorderSizePixel = 0,
					ZIndex = 4,
				}, {
					Fade = React.createElement("uigradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.3, 1),
							NumberSequenceKeypoint.new(0.7, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				}),
				Sheen = React.createElement(GlassSheen, { zIndex = 6 }),
				Blur = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 5,
					ref = function(instance)
						blurs.current[index] = instance
					end,
				}),
			})
		end
		windows.Layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, cellH * 3 + 32),
			BackgroundColor3 = Palette.night,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
			Trim = React.createElement("uistroke", { Color = Palette.brass, Thickness = 3, Transparency = 0.1 }),
			Body = gradient(Color3.fromRGB(46, 34, 52), Color3.fromRGB(22, 16, 26), 90),
			Top = React.createElement(Marquee, {
				position = UDim2.fromOffset(0, 4),
				mode = props.mode,
				reducedMotion = props.reducedMotion,
				color = Palette.mango,
			}),
			Bottom = React.createElement(Marquee, {
				position = UDim2.new(0, 0, 1, -14),
				mode = props.mode,
				reducedMotion = props.reducedMotion,
				color = Palette.coral,
			}),
			Reels = React.createElement("frame", {
				Size = UDim2.new(1, -20, 0, cellH * 3),
				Position = UDim2.fromOffset(10, 16),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, windows),
			Payline = React.createElement("frame", {
				Size = UDim2.new(1, -8, 0, cellH),
				Position = UDim2.new(0, 4, 0, 16 + cellH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 8,
			}, {
				Line = React.createElement("uistroke", {
					Color = Palette.mango,
					Thickness = 2,
					Transparency = 0.6,
					ref = function(instance)
						band.current = instance
					end,
				}),
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		})
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
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 20,
			Active = false,
		}, pieces)
	end

	local function PayoutBanner(props)
		local label = React.useRef(nil)
		local scale = React.useRef(nil)
		local born = React.useRef(os.clock())
		React.useEffect(function()
			born.current = os.clock()
		end, { props.token })
		useRender(function(_, now)
			local age = now - born.current
			local frame = label.current
			if frame == nil or frame.Parent == nil then
				return
			end
			if props.token == 0 or age > 3.8 then
				if frame.Visible then
					frame.Visible = false
				end
				return
			end
			local life = if props.kind == "jackpot" then 3.2 else 2.0
			frame.Visible = age < life and props.token > 0
			if props.amount ~= nil and props.kind ~= "lose" then
				frame.Text = (props.prefix or "+") .. compactNumber(props.amount * outCubic(age / 0.6))
			end
			if scale.current ~= nil then
				scale.current.Scale = if age < 0.45
					then 0.3 + 0.9 * outBack(age / 0.45)
					elseif props.kind == "jackpot" then 1.2 + 0.08 * math.sin(now * 9)
					else 1.2 - 0.2 * math.clamp((age - 0.45) / 0.8, 0, 1)
			end
			frame.TextTransparency = math.clamp((age - (life - 0.5)) / 0.5, 0, 1)
		end, not props.reducedMotion)
		local color = if props.kind == "lose"
			then Palette.coral
			elseif props.kind == "jackpot" then Palette.pink
			else Palette.mango
		return React.createElement("textlabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(300, 56),
			BackgroundTransparency = 1,
			Text = props.text or "",
			TextColor3 = color,
			Font = Enum.Font.BuilderSansExtraBold,
			TextSize = 40,
			ZIndex = 25,
			Visible = if props.reducedMotion then props.token > 0 else nil,
			ref = label,
		}, {
			Scale = React.createElement("uiscale", { ref = scale }),
			Stroke = React.createElement("uistroke", { Color = Palette.ink, Thickness = 4 }),
		})
	end

	local function buildCoin(viewport, camera)
		local model = newModel(viewport)
		local minted = kitPiece("Coin", 2.2)
		if minted ~= nil then
			minted.CFrame = KIT_FACE
			minted.Parent = model
		else
			local face = CFrame.Angles(0, math.pi / 2, 0)
			solid(model, CYL, Vector3.new(0.34, 2.2, 2.2), Palette.brassDeep, METAL, face)
			local body = solid(model, CYL, Vector3.new(0.3, 2.1, 2.1), Palette.mango, METAL, face)
			body.Reflectance = 0.25
			solid(model, CYL, Vector3.new(0.36, 1.7, 1.7), Color3.fromRGB(255, 226, 140), METAL, face)
			local ink = Palette.brassDeep
			solid(model, BLOCK, Vector3.new(0.18, 0.95, 0.07), ink, PLASTIC, CFrame.new(-0.32, 0, -0.2))
			solid(model, BLOCK, Vector3.new(0.18, 0.95, 0.07), ink, PLASTIC, CFrame.new(0.32, 0, -0.2))
			solid(model, BLOCK, Vector3.new(0.6, 0.18, 0.07), ink, PLASTIC, CFrame.new(0, 0, -0.2))
			solid(model, BLOCK, Vector3.new(0.85, 0.18, 0.07), ink, PLASTIC, CFrame.new(0, -0.38, 0.2))
			solid(model, BLOCK, Vector3.new(0.18, 0.95, 0.07), ink, PLASTIC, CFrame.new(0, 0.02, 0.2))
		end
		local shadow = solid(
			viewport,
			CYL,
			Vector3.new(0.04, 1.8, 1.8),
			Color3.new(0, 0, 0),
			PLASTIC,
			CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
		)
		shadow.Transparency = 0.55
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -6.6), Vector3.new(0, 0.1, 0))
		local lastAngle, lastLift = math.huge, math.huge
		return {
			set = function(angle, lift)
				if math.abs(angle - lastAngle) < 1e-3 and math.abs(lift - lastLift) < 1e-3 then
					return
				end
				lastAngle, lastLift = angle, lift
				model:PivotTo(CFrame.new(0, lift, 0) * CFrame.Angles(angle, 0, 0))
				local spread = 1.8 * (1 - math.clamp(lift / 3, 0, 0.5))
				shadow.Size = Vector3.new(0.04, spread, spread)
				shadow.Transparency = 0.55 + math.clamp(lift / 3, 0, 0.35)
			end,
		}
	end

	local function Coin(props)
		local scene = React.useRef(nil)
		local motion = React.useRef({ angle = 0, speed = 0, mode = "rest", t0 = 0, from = 0, to = 0 })
		local function paint(lift)
			if scene.current ~= nil then
				scene.current.set(motion.current.angle, lift or 0)
			end
		end
		React.useEffect(function()
			local m = motion.current
			if props.phase == "spin" then
				m.mode, m.speed = "spin", 18
			elseif props.phase == "land" then
				local turns = math.ceil(m.angle / math.pi) + 8
				if (turns % 2 == 0) ~= (props.heads == true) then
					turns += 1
				end
				m.from, m.to, m.t0, m.mode = m.angle, turns * math.pi, os.clock(), "land"
				if props.reducedMotion then
					m.angle, m.mode = m.to, "rest"
					paint(0)
					if props.onLanded then
						props.onLanded()
					end
				end
			end
		end, { props.phase, props.token })
		useRender(function(dt, now)
			local m = motion.current
			local lift = 0
			if m.mode == "spin" then
				m.angle += m.speed * dt
				lift = 0.5 + 0.3 * math.sin(now * 5)
			elseif m.mode == "land" then
				local k = (now - m.t0) / 1.15
				m.angle = m.from + (m.to - m.from) * outCubic(k)
				lift = 1.6 * math.sin(math.pi * math.clamp(k, 0, 1)) * (1 - 0.3 * k)
				if k >= 1 then
					m.angle, m.mode = m.to, "rest"
					if props.onLanded then
						props.onLanded()
					end
				end
			end
			paint(lift)
		end, not props.reducedMotion)
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Scene = React.createElement(View3D, {
				build = buildCoin,
				onScene = function(s)
					scene.current = s
					paint(0)
				end,
			}),
		})
	end

	local function buildCard(color)
		return function(viewport, camera)
			local model = newModel(viewport)
			local slab = kitPiece("Card", 2.8)
			if slab ~= nil then
				slab.CFrame = KIT_FACE
				slab.Parent = model
			else
				solid(model, BLOCK, Vector3.new(2, 2.8, 0.07), Palette.cream, PLASTIC, CFrame.new(0, 0, -0.04))
				solid(model, BLOCK, Vector3.new(2, 2.8, 0.07), color, PLASTIC, CFrame.new(0, 0, 0.04))
				for _, corner in { Vector3.new(-0.78, 1.15, 0), Vector3.new(0.78, -1.15, 0) } do
					solid(model, BALL, Vector3.one * 0.26, color, PLASTIC, CFrame.new(corner + Vector3.new(0, 0, -0.1)))
				end
				solid(model, BLOCK, Vector3.new(1.4, 2.2, 0.02), Palette.brass, METAL, CFrame.new(0, 0, 0.095))
				solid(model, BLOCK, Vector3.new(1.0, 1.8, 0.02), color, PLASTIC, CFrame.new(0, 0, 0.11))
			end
			camera.FieldOfView = 28
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -6.2), Vector3.zero)
			local lastRot, lastLift = math.huge, math.huge
			return {
				set = function(rotY, lift)
					if math.abs(rotY - lastRot) < 1e-3 and math.abs(lift - lastLift) < 1e-3 then
						return
					end
					lastRot, lastLift = rotY, lift
					model:PivotTo(CFrame.new(0, lift, 0) * CFrame.Angles(math.sin(rotY) * 0.08, rotY, 0))
				end,
			}
		end
	end

	local function Card(props)
		local scene = React.useRef(nil)
		local rankLabel = React.useRef(nil)
		local anim = React.useRef({ t0 = -10, shown = props.rank })
		local last = React.useRef(props.flip)
		local build = React.useMemo(function()
			return buildCard(props.color or Palette.violet)
		end, { props.color })
		React.useEffect(function()
			if props.flip ~= last.current then
				last.current = props.flip
				anim.current.t0 = os.clock()
				if props.reducedMotion then
					anim.current.shown = props.rank
					local label = rankLabel.current
					if label ~= nil and label.Parent ~= nil then
						label.Text = if props.rank then cardName(props.rank) else "?"
					end
				end
			end
		end, { props.flip })
		useRender(function(_, now)
			local k = (now - anim.current.t0) / 0.7
			local rotY, lift = 0, 0
			if k >= 0 and k < 1 then
				rotY = k * math.tau
				lift = 0.35 * math.sin(k * math.pi)
				if k > 0.5 then
					anim.current.shown = props.rank
				end
			else
				anim.current.shown = props.rank
			end
			if scene.current ~= nil then
				scene.current.set(rotY, lift)
			end
			local label = rankLabel.current
			if label ~= nil and label.Parent ~= nil then
				label.Text = if anim.current.shown then cardName(anim.current.shown) else "?"
				label.Visible = math.cos(rotY) > 0.2
				label.TextTransparency = 1 - math.clamp((math.cos(rotY) - 0.2) / 0.8, 0, 1)
			end
		end, not props.reducedMotion)
		return React.createElement("frame", {
			Size = UDim2.fromOffset(props.width, props.height),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Scene = React.createElement(View3D, {
				build = build,
				onScene = function(s)
					scene.current = s
					s.set(0, 0)
				end,
			}),
			Rank = React.createElement("textlabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if props.rank then cardName(props.rank) else "?",
				TextColor3 = props.color or Palette.violet,
				Font = Enum.Font.BuilderSansExtraBold,
				TextSize = math.floor(props.height * 0.42),
				ZIndex = 3,
				ref = rankLabel,
			}),
		})
	end

	local function buildWheel(viewport, camera)
		local scale = 4.85
		local bowl, bowlScale = kitPiece("Wheel", 5.76)
		local ball = kitPiece("Ball", 0.3)
		if bowl ~= nil and ball ~= nil then
			bowl.CFrame = CFrame.new(0, 0.25 + 0.385 * bowlScale, 0) * CFrame.Angles(0, KIT_YAW + math.pi, 0)
			bowl.Parent = viewport
			ball.CFrame = CFrame.new(0, 0.5, -2)
			ball.Parent = viewport
		else
			if bowl ~= nil then
				bowl:Destroy()
			end
			if ball ~= nil then
				ball:Destroy()
			end
			local flat = CFrame.Angles(0, 0, math.pi / 2)
			solid(
				viewport,
				CYL,
				Vector3.new(0.34, 5.7, 5.7),
				Palette.brassDeep,
				PLASTIC,
				CFrame.new(0, -0.12, 0) * flat
			)
			solid(viewport, CYL, Vector3.new(0.3, 5.3, 5.3), Palette.night, PLASTIC, CFrame.new(0, 0, 0) * flat)
			solid(
				viewport,
				CYL,
				Vector3.new(0.12, 4.5, 4.5),
				Color3.fromRGB(58, 44, 64),
				PLASTIC,
				CFrame.new(0, 0.12, 0) * flat
			)
			for index, number in WHEEL do
				local a = (index - 1) / #WHEEL * math.tau
				local color = if number == 0
					then Palette.mint
					elseif RED[number] then Palette.coral
					else Palette.graphite
				solid(
					viewport,
					BLOCK,
					Vector3.new(0.34, 0.14, 0.62),
					color,
					PLASTIC,
					CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.22, -0.34 * scale)
				)
			end
			solid(viewport, CYL, Vector3.new(0.4, 1.7, 1.7), Palette.brassDeep, PLASTIC, CFrame.new(0, 0.28, 0) * flat)
			solid(viewport, CYL, Vector3.new(0.6, 0.7, 0.7), Palette.brass, PLASTIC, CFrame.new(0, 0.4, 0) * flat)
			ball = solid(viewport, BALL, Vector3.one * 0.3, Color3.new(1, 1, 1), NEON, CFrame.new(0, 0.5, -2))
		end
		local baseLight = Vector3.new(-0.5, -0.8, 1)
		local home = CFrame.lookAt(Vector3.new(0, 6.4, -5.2), Vector3.new(0, 0, 0.2))
		local lastTurn, lastAngle, lastRadius = math.huge, math.huge, math.huge
		camera.FieldOfView = 38
		camera.CFrame = home
		return {
			set = function(turn, ballAngle, ballRadius)
				if math.abs(turn - lastTurn) > 1e-3 then
					lastTurn = turn
					local swing = CFrame.Angles(0, turn, 0)
					camera.CFrame = swing * home
					viewport.LightDirection = swing:VectorToWorldSpace(baseLight)
				end
				if math.abs(ballAngle - lastAngle) > 1e-3 or math.abs(ballRadius - lastRadius) > 1e-4 then
					lastAngle, lastRadius = ballAngle, ballRadius
					ball.Position = Vector3.new(
						math.sin(ballAngle) * ballRadius * scale,
						0.5,
						-math.cos(ballAngle) * ballRadius * scale
					)
				end
			end,
		}
	end
	local function Wheel(props)
		local diameter = props.size or 190
		local scene = React.useRef(nil)
		local motion = React.useRef({ turn = 0, mode = "rest", t0 = 0, rel = 0, pocket = 0 })
		local pocketAngle = {}
		for index, number in WHEEL do
			pocketAngle[number] = (index - 1) / #WHEEL * math.pi * 2
		end
		local function paint(angle, radius)
			if scene.current ~= nil then
				local m = motion.current
				scene.current.set(m.turn, angle - (if m.mode == "orbit" then m.turn else 0), radius)
			end
		end
		React.useEffect(function()
			local m = motion.current
			if props.phase == "spin" then
				m.mode, m.t0 = "orbit", os.clock()
			elseif props.phase == "land" and props.number ~= nil then
				m.mode, m.t0, m.pocket = "land", os.clock(), pocketAngle[props.number]
				if props.reducedMotion then
					m.mode, m.rel = "rest", m.pocket
					paint(m.rel, 0.34)
					if props.onLanded then
						props.onLanded()
					end
				end
			end
		end, { props.phase, props.token })
		useRender(function(dt, now)
			local m = motion.current
			m.turn += dt * (if m.mode == "orbit" or m.mode == "land" then 0.9 else 0.25)
			local radius, angle = 0.34, m.rel
			if m.mode == "orbit" then
				angle = -(now - m.t0) * 9
				radius = 0.43
			elseif m.mode == "land" then
				local k = (now - m.t0) / 3.0
				angle = m.pocket - (1 - outCubic(k)) * math.pi * 2 * 7
				radius = 0.43 - 0.09 * outBounce(math.clamp((k - 0.7) / 0.3, 0, 1))
				if k >= 1 then
					m.rel, m.mode = m.pocket, "rest"
					angle = m.pocket
					if props.onLanded then
						props.onLanded()
					end
				end
			end
			paint(angle, radius)
		end, not props.reducedMotion)
		return React.createElement("frame", {
			Size = UDim2.fromOffset(diameter, diameter),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Sheen = React.createElement(GlassSheen, { zIndex = 3, radius = UDim.new(0.5, 0) }),
			Scene = React.createElement(View3D, {
				build = buildWheel,
				onScene = function(s)
					scene.current = s
					paint(motion.current.rel, 0.34)
				end,
			}),
		})
	end

	local function buildGem(id)
		return function(viewport, camera)
			local model = newModel(viewport)
			addSymbol(model, id, CFrame.new(), 1.5)
			camera.FieldOfView = 34
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -4.2), Vector3.zero)
			local lastPop = 1
			return {
				set = function(rotY, pop)
					model:PivotTo(CFrame.Angles(0.25, rotY, 0))
					if math.abs(pop - lastPop) > 0.01 then
						lastPop = pop
						model:ScaleTo(pop)
					end
				end,
			}
		end
	end

	local SPARKLE_COLORS = { Palette.mango, Palette.cyan, Palette.pink, Palette.mint, Palette.cream }
	local SPARKLES = 8

	local function ScratchCell(props)
		local cover = React.useRef(nil)
		local gem = React.useRef(nil)
		local pieces = React.useRef({})
		local sparks = React.useRef({})
		local born = React.useRef(-100)
		local fired = React.useRef(true)
		local last = React.useRef(props.token)
		local id = props.symbol
		local build = React.useMemo(function()
			return if id then buildGem(id) else nil
		end, { id })
		React.useEffect(function()
			if props.token ~= last.current then
				last.current = props.token
				born.current = os.clock()
				fired.current = false
				for i = 1, SPARKLES do
					sparks.current[i] = {
						x = 0.3 + math.random() * 0.4,
						y = 0.3 + math.random() * 0.4,
						vx = (math.random() - 0.5) * 0.8,
						vy = -(0.3 + math.random() * 0.5),
						life = 0.6 + math.random() * 0.3,
						age = 0,
						wait = i * 0.03,
						size = 4 + math.random() * 4,
					}
				end
			end
		end, { props.token })
		useRender(function(dt, now)
			local c = cover.current
			if c == nil or c.Parent == nil then
				return
			end
			local k = (now - born.current - props.delay) / 0.5
			if props.symbol == nil then
				c.Visible = true
				c.Size = UDim2.fromScale(1, 1)
				c.Position = UDim2.fromScale(0, 0)
				c.Rotation = 0
				c.BackgroundTransparency = 0
			elseif k >= 0 then
				if not fired.current then
					fired.current = true
					if props.onReveal then
						props.onReveal()
					end
				end
				local peel = outCubic(k)
				c.Visible = k < 1
				c.Rotation = -15 * peel
				c.Size = UDim2.fromScale(1 - peel * 0.9, 1 - peel * 0.1)
				c.Position = UDim2.fromScale(-peel * 0.5, -peel * 0.2)
				c.BackgroundTransparency = math.clamp(k, 0, 1) * 0.7
			end
			if gem.current ~= nil then
				local pop = 0.5 + 0.6 * outBack(math.clamp((k - 0.3) / 0.4, 0, 1))
				gem.current.set(now * 1.6, math.max(0.05, pop))
			end
			for i = 1, SPARKLES do
				local p = sparks.current[i]
				local piece = pieces.current[i]
				if piece ~= nil and piece.Parent ~= nil then
					if p == nil or k < 0 then
						piece.Visible = false
					elseif p.wait > 0 then
						p.wait -= dt
						piece.Visible = false
					elseif p.age >= p.life then
						piece.Visible = false
					else
						p.age += dt
						p.vy += 1.5 * dt
						p.x += p.vx * dt
						p.y += p.vy * dt
						piece.Visible = true
						piece.Position = UDim2.fromScale(p.x, p.y)
						piece.Size = UDim2.fromOffset(p.size, p.size)
						piece.BackgroundTransparency = math.clamp((p.age - (p.life - 0.2)) / 0.2, 0, 1)
					end
				end
			end
		end, not props.reducedMotion)
		local color = if id then (SYMBOL_COLORS[id] or Palette.cream) else Palette.muted
		local sparkleEls = {}
		for i = 1, SPARKLES do
			sparkleEls["sp" .. i] = React.createElement("frame", {
				Size = UDim2.fromOffset(4, 4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = SPARKLE_COLORS[(i % #SPARKLE_COLORS) + 1],
				BorderSizePixel = 0,
				ZIndex = 7,
				ref = function(instance)
					pieces.current[i] = instance
				end,
			}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) })
		end
		return React.createElement("frame", {
			Size = props.size or UDim2.new(0.31, 0, 1, 0),
			BackgroundColor3 = Palette.panelSoft,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = props.order or 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("uistroke", {
				Color = if props.glow then Palette.mango else color,
				Thickness = if props.glow then 3 else 2,
				Transparency = 0.2,
			}),
			["Gem" .. tostring(id)] = if id
				then React.createElement(View3D, {
					build = build,
					onScene = function(s)
						gem.current = s
						s.set(0, 1)
					end,
				})
				else nil,
			Sparkles = React.createElement(
				"frame",
				{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7 },
				sparkleEls
			),
			Cover = React.createElement("frame", {
				Size = UDim2.fromScale(if props.reducedMotion and id then 0 else 1, 1),
				BackgroundColor3 = Palette.steel,
				BorderSizePixel = 0,
				ZIndex = 5,
				Visible = not (props.reducedMotion and id ~= nil),
				ref = cover,
			}, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
				Foil = gradient(Color3.fromRGB(236, 240, 252), Color3.fromRGB(150, 162, 190), 40),
				Mark = React.createElement(Text, {
					value = "?",
					size = 20,
					color = Palette.graphite,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Center,
				}),
			}),
		})
	end

	local function Ticker(props)
		local bars = React.useRef({})
		local born = React.useRef(os.clock())
		React.useEffect(function()
			born.current = os.clock()
		end, { props.tab })
		local history = props.history or {}
		local function height(mood)
			return math.clamp((mood - 0.55) / 1.0, 0.05, 1)
		end
		useRender(function(_, now)
			for index, bar in bars.current do
				if bar.Parent ~= nil then
					bar.Size = UDim2.new(
						1 / math.max(1, #history),
						-3,
						height(history[index] or 1) * outCubic((now - born.current - index * 0.02) / 0.5),
						0
					)
				end
			end
		end, not props.reducedMotion)
		local children = {
			Layout = React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
		}
		for index, mood in history do
			children["b" .. index] = React.createElement("frame", {
				Size = UDim2.new(1 / math.max(1, #history), -3, height(mood), 0),
				BackgroundColor3 = if index == #history
					then Palette.mint
					elseif mood < 1 then Palette.green
					else Palette.coral,
				BackgroundTransparency = if index == #history then 0 else 0.35,
				BorderSizePixel = 0,
				LayoutOrder = index,
				ref = function(instance)
					bars.current[index] = instance
				end,
			}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) }) })
		end
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = Palette.night,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("uistroke", { Color = Palette.line, Thickness = 1 }),
			Bars = React.createElement("frame", {
				Size = UDim2.new(1, -12, 1, -12),
				Position = UDim2.fromOffset(6, 6),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, children),
			Par = React.createElement("frame", {
				Size = UDim2.new(1, -12, 0, 1),
				Position = UDim2.new(0, 6, 1, -6 - (1 - 0.55 + 0.0) / 1.0 * (90 - 12) * 0 - height(1) * (90 - 12)),
				BackgroundColor3 = Palette.cream,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = 3,
			}),
		})
	end

	local function ClubRankRow(props)
		local rank = props.rank
		local reward = if rank.Reward then formatReward(rank.Reward) else "Welcome"
		local text, color, textColor, disabled, highlight = `{rank.XP} XP`, Palette.panelSoft, nil, true, false
		if rank.Claimed then
			text = "CLAIMED"
		elseif rank.Claimable then
			text, color, textColor, disabled, highlight = "CLAIM", Palette.mango, Palette.ink, props.busy, true
		end
		return React.createElement(Row, {
			height = 38,
			order = props.order,
			gap = 8,
			children = {
				React.createElement(Text, {
					value = `{rank.Name}: {reward}`,
					size = 12,
					color = if props.reached then Palette.cream else Palette.muted,
					sizeConstraint = UDim2.new(0.66, 0, 1, 0),
					layoutOrder = 1,
				}),
				React.createElement(Button, {
					text = text,
					onClick = function()
						if rank.Claimable and not rank.Claimed then
							props.play({ Game = "Club", Rank = rank.Rank })
						end
					end,
					size = UDim2.new(0.3, 0, 1, 0),
					color = color,
					textColor = textColor,
					disabled = disabled,
					highlight = highlight,
					reducedMotion = props.reducedMotion,
					layoutOrder = 2,
				}),
			},
		})
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
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 12),
			BackgroundColor3 = Palette.panelSoft,
			BorderSizePixel = 0,
			LayoutOrder = props.order or 0,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) }),
			Fill = React.createElement("frame", {
				Size = UDim2.fromScale(if props.reducedMotion then props.value else 0, 1),
				BackgroundColor3 = props.color or Palette.mango,
				BorderSizePixel = 0,
				ref = fill,
			}, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) }),
				Shine = React.createElement("uigradient", {
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.45, 1),
						NumberSequenceKeypoint.new(0.5, 0.35),
						NumberSequenceKeypoint.new(0.55, 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
					ref = shine,
				}),
			}),
		})
	end

	local function TabSwap(props)
		local arrive = useFlipperSpring(1, false, 620, 40, 0)
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			Position = arrive:map(function(amount)
				return UDim2.fromOffset(math.round((1 - math.clamp(amount, 0, 1)) * 18 * (props.direction or 1)), 0)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Scale = React.createElement("uiscale", {
				Scale = arrive:map(function(amount)
					return 0.97 + math.clamp(amount, 0, 1) * 0.03
				end),
			}),
			Body = props.children,
		})
	end

	local function stakeLine(state, tier)
		local stake = state.Casino.Stakes[tier]
		if stake == nil then
			return ""
		end
		return `Stake: {compactNumber(stake.Amount)} flux ({stake.Share * 100}% of yours)`
	end

	local function CasinoView(props)
		local state = props.state
		local dispatch = props.dispatch
		local reducedMotion = false
		local viewport = useViewport()
		local chrome = chromeFor(viewport)
		local tabColumns = if chrome.stack then 3 else 4
		local tabRows = math.ceil(#TABS / tabColumns)
		local tabHeight = tabRows * 48 + (tabRows - 1) * 6
		local reveal = useStagger(0, reducedMotion)
		local casino = state.Casino

		local tab, setTab = require(script.Parent.Parent.BrowseKit).useLinkedTab("Casino", "Slots", props.initialTab)
		local tabIndexRef = React.useRef({ index = 1, direction = 1 })
		for index, entry in TABS do
			if entry.id == tab and index ~= tabIndexRef.current.index then
				tabIndexRef.current = { index = index, direction = if index > tabIndexRef.current.index then 1 else -1 }
			end
		end
		local tabDirection = tabIndexRef.current.direction
		local tier, setTier = React.useState(2)
		local busy, setBusy = React.useState(false)
		local busyRef = React.useRef(false)
		React.useEffect(function()
			if props.onBusyChange then
				props.onBusyChange(busy)
			end
			return function()
				if props.onBusyChange then
					props.onBusyChange(false)
				end
			end
		end, { busy, props.onBusyChange })
		local note, setNote = React.useState({
			text = "Pick a game and a stake. The house keeps a few percent, and you can walk away any time.",
			good = nil,
		})
		local last, setLast = React.useState({})
		local pick, setPick = React.useState("Red")
		local straight, setStraight = React.useState(17)
		local slot, setSlot = React.useState({ phase = "idle", target = { "Ember", "Dust", "Core" }, token = 0 })
		local coin, setCoin = React.useState({ phase = "rest", heads = true, token = 0 })
		local card, setCard = React.useState({ rank = nil, flip = 0 })
		local wheel, setWheel = React.useState({ phase = "rest", number = nil, token = 0 })
		local scratch, setScratch = React.useState({ cells = nil, token = 0 })
		local fx, setFx = React.useState({ token = 0, power = 1 })
		local banner, setBanner = React.useState({ token = 0, text = "", kind = "win" })
		local mode, setMode = React.useState("idle")
		local mounted = React.useRef(true)
		local pending = React.useRef(nil)
		local stopWhir = React.useRef(nil)
		local stopRoll = React.useRef(nil)
		React.useEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
				if stopWhir.current then
					stopWhir.current()
				end
				if stopRoll.current then
					stopRoll.current()
				end
			end
		end, {})

		local function conclude(response)
			if not mounted.current then
				return
			end
			local result = response.Result or {}
			busyRef.current = false
			setBusy(false)
			setLast(result)
			setMode("idle")
			local multiplier = result.Multiplier or 0
			local won = result.Won == true
			local paid = result.Payout ~= nil and result.Payout ~= 0
			setNote({ text = response.message or "", good = if result.Won == nil then nil else won })
			if result.Open then
				sfx("casino_streak", 0.6)
				setFx({ token = fx.token + 1, power = 0.5 })
			elseif won and paid then
				local kind = if multiplier >= 100 then "jackpot" elseif multiplier >= 10 then "big" else "win"
				sfx(
					if kind == "jackpot"
						then "casino_jackpot"
						elseif kind == "big" then "casino_win_big"
						else "casino_win_small",
					0.8
				)
				if result.Cashed then
					sfx("casino_cash", 0.6)
				end
				setFx({
					token = fx.token + 1,
					power = if kind == "jackpot" then 2.2 elseif kind == "big" then 1.5 else 1,
				})
				setBanner({
					token = banner.token + 1,
					text = `+{compactNumber(result.Payout)}`,
					amount = result.Payout,
					kind = kind,
				})
				setMode("win")
				task.delay(if kind == "jackpot" then 3 else 1.6, function()
					if mounted.current then
						setMode("idle")
					end
				end)
			elseif result.Won == false then
				sfx("casino_lose", 0.6)
				setBanner({ token = banner.token + 1, text = `-{compactNumber(result.Stake)}`, kind = "lose" })
			else
				sfx("casino_buy", 0.6)
				setFx({ token = fx.token + 1, power = 0.6 })
			end
		end

		local function fail(response)
			if not mounted.current then
				return
			end
			busyRef.current = false
			setBusy(false)
			setMode("idle")
			setNote({ text = response.error or "That didn't go through.", good = false })
			sfx("casino_lose", 0.4, 1.3)
			Audio:play("error")
		end

		local function play(payload, onResponse)
			if busyRef.current or casino == nil then
				return
			end
			busyRef.current = true
			setBusy(true)
			dispatch("CasinoPlay", payload, function(response)
				if not mounted.current then
					return
				end
				if not response.ok then
					if stopWhir.current then
						stopWhir.current()
						stopWhir.current = nil
					end
					if stopRoll.current then
						stopRoll.current()
						stopRoll.current = nil
					end
					setSlot({ phase = "idle", target = slot.target, token = slot.token })
					setCoin({ phase = "rest", heads = coin.heads, token = coin.token })
					setWheel({ phase = "rest", number = wheel.number, token = wheel.token })
					fail(response)
					return
				end
				if onResponse then
					onResponse(response)
				else
					conclude(response)
				end
			end)
		end

		if casino == nil then
			return React.createElement(PageScaffold, {
				gap = 0,
				tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
				sections = {
					{
						id = "loading",
						height = 80,
						element = React.createElement(Text, {
							value = "The casino is warming up...",
							size = 14,
							color = Palette.muted,
							sizeConstraint = UDim2.new(1, 0, 0, 24),
						}),
					},
				},
			})
		end

		local accent = Palette.mango
		for _, entry in TABS do
			if entry.id == tab then
				accent = entry.accent
			end
		end
		local stakes = casino.Stakes
		local noteColor = if note.good == true
			then Palette.mint
			elseif note.good == false then Palette.coral
			else Palette.muted

		local function stakePicker(order, locked)
			local items = {}
			for index, stake in stakes do
				items[index] = {
					text = stake.Name,
					onClick = function()
						sfx("casino_chip", 0.5, 0.9 + index * 0.08)
						setTier(index)
					end,
					color = if tier == index then accent else Palette.panelSoft,
					textColor = if tier == index then Palette.ink else Palette.cream,
					disabled = locked == true,
				}
			end
			return React.createElement(
				Buttons,
				{ items = items, height = 40, order = order, reducedMotion = reducedMotion }
			)
		end

		local function slotsBody()
			local pays = {}
			for _, symbol in casino.Slots.Symbols do
				table.insert(pays, `{symbol.Id} {symbol.Pay3}x`)
			end
			return {
				React.createElement(Line, {
					value = "STARLIGHT SLOTS",
					size = 11,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(SlotMachine, {
					order = 2,
					phase = slot.phase,
					target = slot.target,
					token = slot.token,
					mode = if mode == "win"
						then "win"
						elseif slot.phase == "spin" or slot.phase == "stop" then "spin"
						else "idle",
					flash = mode == "win",
					reducedMotion = reducedMotion,
					onReel = function()
						sfx("casino_reel_stop", 0.7)
					end,
					onSettled = function()
						if stopWhir.current then
							stopWhir.current()
							stopWhir.current = nil
						end
						setSlot({ phase = "idle", target = slot.target, token = slot.token })
						if pending.current then
							conclude(pending.current)
							pending.current = nil
						end
					end,
				}),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 38, order = 3 }),
				stakePicker(4, busy),
				React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
				React.createElement(Buttons, {
					items = {
						{
							text = if busy then "SPINNING..." else "SPIN",
							onClick = function()
								sfx("casino_chip", 0.6)
								stopWhir.current = loopSfx("casino_spin", 0.5)
								setSlot({ phase = "spin", target = slot.target, token = slot.token + 1 })
								setMode("spin")
								play({ Game = "Slots", Tier = tier }, function(response)
									pending.current = response
									setSlot({
										phase = "stop",
										target = response.Result.Reels,
										token = slot.token + 2,
									})
								end)
							end,
							color = Palette.mango,
							textColor = Palette.ink,
							disabled = busy,
							highlight = not busy,
						},
					},
					height = 54,
					order = 6,
					reducedMotion = reducedMotion,
				}),
				React.createElement(Line, {
					value = `Three alike pays: {table.concat(pays, "  ")}. Two Embers or Dusts pay a little. Returns {percent(
						casino.Slots.Rtp
					)}.`,
					size = 11,
					height = 44,
					order = 7,
				}),
			}
		end

		local function flipBody()
			local flip = casino.Flip
			local function toss(payload)
				sfx("casino_chip", 0.6)
				sfx("casino_coin_spin", 0.6)
				setCoin({ phase = "spin", heads = coin.heads, token = coin.token + 1 })
				play(payload, function(response)
					pending.current = response
					setCoin({ phase = "land", heads = response.Result.Heads ~= false, token = coin.token + 2 })
				end)
			end
			local items = {}
			if flip.Active then
				items[1] = {
					text = if busy then "..." else `FLIP AGAIN ({times(flip.NextMultiplier)})`,
					onClick = function()
						toss({ Game = "Flip", Op = "Flip" })
					end,
					color = Palette.cyan,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy,
				}
				items[2] = {
					text = if flip.Streak > 0 then `CASH OUT {compactNumber(flip.Cashout)}` else "FLIP FIRST",
					onClick = function()
						sfx("casino_chip", 0.6)
						play({ Game = "Flip", Op = "Cashout" })
					end,
					color = Palette.mint,
					textColor = Palette.ink,
					disabled = busy or flip.Streak < 1,
				}
			else
				items[1] = {
					text = if busy then "..." else "FLIP THE COIN",
					onClick = function()
						toss({ Game = "Flip", Op = "Flip", Tier = tier })
					end,
					color = Palette.cyan,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy,
				}
			end
			return {
				React.createElement(Line, {
					value = "DOUBLE OR NOTHING",
					size = 11,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Coin, {
					order = 2,
					phase = coin.phase,
					heads = coin.heads,
					token = coin.token,
					reducedMotion = reducedMotion,
					onLanded = function()
						sfx("casino_coin_land", 0.7)
						if pending.current then
							conclude(pending.current)
							pending.current = nil
						end
					end,
				}),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
				if flip.Active
					then React.createElement(Line, {
						value = `Stake {compactNumber(flip.Stake)} flux, now worth {times(flip.Multiplier)}. {flip.Streak} in a row. One tails loses the lot.`,
						size = 12,
						order = 4,
						height = 34,
					})
					else stakePicker(4),
				if flip.Active
					then React.createElement(Line, { value = "", order = 5, height = 2 })
					else React.createElement(
						Line,
						{ value = stakeLine(state, tier), size = 12, order = 5, height = 18 }
					),
				React.createElement(Buttons, { items = items, height = 52, order = 6, reducedMotion = reducedMotion }),
				React.createElement(Line, {
					value = `Each flip is {percent(flip.Chance)} to land heads, and pays x1.92 on top of the last. The streak caps at {flip.MaxStreak}.`,
					size = 11,
					height = 30,
					order = 7,
				}),
			}
		end

		local function highLowBody()
			local round = casino.HighLow
			local items = {}
			local function turn(payload)
				sfx("casino_chip", 0.6)
				play(payload, function(response)
					pending.current = response
					sfx("casino_card_flip", 0.7)
					setCard({ rank = response.Result.Card, flip = card.flip + 1 })
					task.delay(if reducedMotion then 0 else 0.7, function()
						if mounted.current and pending.current then
							conclude(pending.current)
							pending.current = nil
						end
					end)
				end)
			end
			if round.Active then
				items[1] = {
					text = if round.High.Chance > 0
						then `HIGHER {percent(round.High.Chance)} ({times(round.High.Step)})`
						else "HIGHER (none)",
					onClick = function()
						turn({ Game = "HighLow", Op = "Guess", Pick = "High" })
					end,
					color = Palette.violet,
					textColor = Palette.ink,
					disabled = busy or round.High.Chance <= 0,
				}
				items[2] = {
					text = if round.Low.Chance > 0
						then `LOWER {percent(round.Low.Chance)} ({times(round.Low.Step)})`
						else "LOWER (none)",
					onClick = function()
						turn({ Game = "HighLow", Op = "Guess", Pick = "Low" })
					end,
					color = Palette.blue,
					textColor = Palette.ink,
					disabled = busy or round.Low.Chance <= 0,
				}
			else
				items[1] = {
					text = if busy then "..." else "DEAL A CARD",
					onClick = function()
						turn({ Game = "HighLow", Op = "Start", Tier = tier })
					end,
					color = Palette.violet,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy,
				}
			end
			local shownRank = card.rank or (if round.Active then round.Card else nil)
			return {
				React.createElement(Line, {
					value = "HIGH-LOW LADDER",
					size = 11,
					color = Palette.violet,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Row, {
					height = 110,
					order = 2,
					gap = 12,
					children = {
						React.createElement(Card, {
							rank = shownRank,
							flip = card.flip,
							width = 78,
							height = 108,
							color = Palette.violet,
							reducedMotion = reducedMotion,
							order = 1,
						}),
						React.createElement(Tile, {
							value = if round.Active then `{round.Streak} right` else "no round",
							color = Palette.cream,
							textSize = 15,
							size = UDim2.fromOffset(86, 70),
							order = 2,
						}),
						React.createElement(Tile, {
							value = if round.Active then times(round.Multiplier) else "x1.00",
							color = Palette.mango,
							textSize = 20,
							size = UDim2.fromOffset(86, 70),
							order = 3,
						}),
					},
				}),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
				if round.Active
					then React.createElement(Line, {
						value = `Stake {compactNumber(round.Stake)} flux. A tie loses. Cards run Ace (low) to King (high).`,
						size = 12,
						order = 4,
						height = 34,
					})
					else stakePicker(4),
				if round.Active
					then React.createElement(Line, { value = "", order = 5, height = 2 })
					else React.createElement(
						Line,
						{ value = stakeLine(state, tier), size = 12, order = 5, height = 18 }
					),
				React.createElement(Buttons, { items = items, height = 50, order = 6, reducedMotion = reducedMotion }),
				if round.Active
					then React.createElement(Buttons, {
						items = {
							{
								text = if round.Streak > 0
									then `CASH OUT {compactNumber(round.Cashout)}`
									else "WIN A GUESS FIRST",
								onClick = function()
									sfx("casino_chip", 0.6)
									play({ Game = "HighLow", Op = "Cashout" })
								end,
								color = Palette.mint,
								textColor = Palette.ink,
								disabled = busy or round.Streak < 1,
							},
						},
						height = 44,
						order = 7,
						reducedMotion = reducedMotion,
					})
					else React.createElement(Line, {
						value = "Every guess pays 96% of its true odds, so the safer the guess the smaller the step.",
						size = 11,
						height = 30,
						order = 7,
					}),
			}
		end

		local function rouletteBody()
			local function option(label, id)
				return {
					text = label,
					onClick = function()
						sfx("casino_chip", 0.4)
						setPick(id)
					end,
					color = if pick == id then Palette.coral else Palette.panelSoft,
					textColor = if pick == id then Palette.ink else Palette.cream,
					disabled = busy,
				}
			end
			local resultNumber = if last.Game == "Roulette" then last.Number else nil
			local resultColor = if last.Game == "Roulette" then last.Color else nil
			local numberFill = if resultColor == "Red"
				then Palette.coral
				elseif resultColor == "Green" then Palette.mint
				else Palette.panelSoft
			local picked = if string.sub(pick, 1, 1) == "N"
				then `Number {string.sub(pick, 2)} pays x36`
				else `{pick} pays x{(pick == "D1" or pick == "D2" or pick == "D3" or pick == "C1" or pick == "C2" or pick == "C3") and 3 or 2}`
			return {
				React.createElement(Line, {
					value = "ASTRAL ROULETTE",
					size = 11,
					color = Palette.coral,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Row, {
					height = 196,
					order = 2,
					gap = 12,
					children = {
						React.createElement(Wheel, {
							order = 1,
							size = 188,
							phase = wheel.phase,
							number = wheel.number,
							token = wheel.token,
							reducedMotion = reducedMotion,
							onLanded = function()
								if stopRoll.current then
									stopRoll.current()
									stopRoll.current = nil
								end
								sfx("casino_ball_drop", 0.7)
								if pending.current then
									conclude(pending.current)
									pending.current = nil
								end
							end,
						}),
						React.createElement(Tile, {
							value = if resultNumber then tostring(resultNumber) else "--",
							fill = numberFill,
							color = Palette.cream,
							size = UDim2.fromOffset(64, 64),
							order = 2,
							textSize = 28,
						}),
					},
				}),
				React.createElement(
					Line,
					{ value = `{picked}. {note.text}`, size = 13, color = noteColor, height = 34, order = 3 }
				),
				React.createElement(Buttons, {
					items = {
						option("Red", "Red"),
						option("Black", "Black"),
						option("Odd", "Odd"),
						option("Even", "Even"),
					},
					height = 34,
					order = 4,
					reducedMotion = reducedMotion,
				}),
				React.createElement(Buttons, {
					items = {
						option("1-18", "Low"),
						option("19-36", "High"),
						option("1st 12", "D1"),
						option("2nd 12", "D2"),
						option("3rd 12", "D3"),
					},
					height = 34,
					order = 5,
					reducedMotion = reducedMotion,
				}),
				React.createElement(Buttons, {
					items = {
						option("Col 1", "C1"),
						option("Col 2", "C2"),
						option("Col 3", "C3"),
						{
							text = "-",
							onClick = function()
								sfx("casino_tick", 0.5)
								setStraight((straight + 36) % 37)
							end,
							color = Palette.panelSoft,
							disabled = busy,
						},
						option(`Number {straight}`, `N{straight}`),
						{
							text = "+",
							onClick = function()
								sfx("casino_tick", 0.5)
								setStraight((straight + 1) % 37)
							end,
							color = Palette.panelSoft,
							disabled = busy,
						},
					},
					height = 34,
					order = 6,
					reducedMotion = reducedMotion,
				}),
				stakePicker(7, busy),
				React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 8, height = 18 }),
				React.createElement(Buttons, {
					items = {
						{
							text = if busy then "..." else "SPIN THE WHEEL",
							onClick = function()
								sfx("casino_chip", 0.6)
								stopRoll.current = loopSfx("casino_ball_roll", 0.5)
								setWheel({ phase = "spin", number = nil, token = wheel.token + 1 })
								play({ Game = "Roulette", Tier = tier, Pick = pick }, function(response)
									pending.current = response
									setWheel({
										phase = "land",
										number = response.Result.Number,
										token = wheel.token + 2,
									})
								end)
							end,
							color = Palette.coral,
							textColor = Palette.ink,
							disabled = busy,
							highlight = not busy,
						},
					},
					height = 50,
					order = 9,
					reducedMotion = reducedMotion,
				}),
			}
		end

		local function scratchBody()
			local free = casino.Scratch.FreeReady
			local cells = scratch.cells
			local winning = nil
			if cells and last.Game == "Scratch" and last.Symbol then
				winning = last.Symbol
			end
			local function cellRow(first)
				local row = {}
				for index = first, first + 2 do
					row[#row + 1] = React.createElement(ScratchCell, {
						symbol = if cells then cells[index] else nil,
						token = scratch.token,
						delay = (index - 1) * 0.3,
						glow = winning ~= nil and cells ~= nil and cells[index] == winning and not busy,
						order = index,
						reducedMotion = reducedMotion,
						onReveal = function()
							sfx("casino_scratch", 0.5, 0.9 + index * 0.05)
						end,
					})
				end
				return row
			end
			local function scratchCard(isFree)
				sfx("casino_chip", 0.6)
				play({ Game = "Scratch", Tier = tier, Free = isFree }, function(response)
					pending.current = response
					setScratch({ cells = response.Result.Cells, token = scratch.token + 1 })
					task.delay(if reducedMotion then 0 else 6 * 0.3 + 0.7, function()
						if mounted.current and pending.current then
							conclude(pending.current)
							pending.current = nil
						end
					end)
				end)
			end
			local items = {
				{
					text = if busy then "..." else "BUY A CARD",
					onClick = function()
						scratchCard(false)
					end,
					color = Palette.pink,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy and not free,
				},
			}
			if free then
				table.insert(items, 1, {
					text = "FREE DAILY CARD",
					onClick = function()
						scratchCard(true)
					end,
					color = Palette.mint,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy,
				})
			end
			local pays = {}
			for _, symbol in casino.Scratch.Symbols do
				table.insert(pays, `{symbol.Id} {symbol.Pay}x`)
			end
			return {
				React.createElement(Line, {
					value = "SCRATCH CARDS",
					size = 11,
					color = Palette.pink,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Row, { height = 64, order = 2, gap = 8, children = cellRow(1) }),
				React.createElement(Row, { height = 64, order = 3, gap = 8, children = cellRow(4) }),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 4 }),
				stakePicker(5, busy),
				React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 6, height = 18 }),
				React.createElement(Buttons, { items = items, height = 50, order = 7, reducedMotion = reducedMotion }),
				React.createElement(Line, {
					value = `Match three or more of one symbol: {table.concat(pays, "  ")}. Returns {percent(
						casino.Scratch.Rtp
					)}. The daily card is free, at the Pocket stake.`,
					size = 11,
					height = 44,
					order = 8,
				}),
			}
		end

		local function exchangeBody()
			local market = casino.Exchange
			local delta = math.floor((market.Mood - 1) * 100 + 0.5)
			local trend = if market.Trend > 0.02 then "rising" elseif market.Trend < -0.02 then "falling" else "steady"
			local remaining = math.max(0, market.NextAt - workspace:GetServerTimeNow())
			local function buy(count)
				return {
					text = `BUY {count}`,
					onClick = function()
						sfx("casino_chip", 0.6)
						play({ Game = "Exchange", Count = count }, function(response)
							sfx("casino_cash", 0.7)
							conclude(response)
						end)
					end,
					color = Palette.mint,
					textColor = Palette.ink,
					disabled = busy or market.Left < count,
				}
			end
			return {
				React.createElement(Line, {
					value = "STARDUST EXCHANGE",
					size = 11,
					color = Palette.mint,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Row, {
					height = 60,
					order = 2,
					gap = 8,
					children = {
						React.createElement(Tile, {
							value = `{compactNumber(market.Price)} flux`,
							color = Palette.mint,
							textSize = 18,
							size = UDim2.new(0.48, 0, 1, 0),
							order = 1,
						}),
						React.createElement(Tile, {
							value = `{if delta >= 0 then "+" else ""}{delta}% {trend}`,
							color = if delta <= 0 then Palette.mint else Palette.coral,
							textSize = 15,
							size = UDim2.new(0.48, 0, 1, 0),
							order = 2,
						}),
					},
				}),
				React.createElement(
					Ticker,
					{ history = market.History, tab = tab, reducedMotion = reducedMotion, order = 3 }
				),
				React.createElement(Line, {
					value = `One Stardust costs the price above. The market moves every ten minutes (next change in {clockText(
						remaining
					)}), the same for everyone, and is cheaper when it is below par.`,
					size = 12,
					height = 48,
					order = 4,
				}),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 24, order = 5 }),
				React.createElement(Line, {
					value = `{market.Left} of {market.Cap} Stardust left to buy today.`,
					size = 12,
					order = 6,
					height = 18,
				}),
				React.createElement(
					Buttons,
					{ items = { buy(1), buy(5), buy(20) }, height = 48, order = 7, reducedMotion = reducedMotion }
				),
			}
		end

		local function clubBody()
			local club = casino.Club
			local stats = casino.Stats
			local rows = {}
			for index, rank in club.Ranks do
				rows[index] = React.createElement(ClubRankRow, {
					rank = rank,
					reached = rank.Rank <= club.Rank,
					busy = busy,
					order = 10 + index,
					reducedMotion = reducedMotion,
					play = function(payload)
						sfx("casino_rank", 0.8)
						play(payload, function(response)
							setFx({ token = fx.token + 1, power = 1.6 })
							conclude(response)
						end)
					end,
				})
			end
			local progress = if club.NextXP then math.clamp(club.XP / club.NextXP, 0, 1) else 1
			local children = {
				React.createElement(Line, {
					value = "HIGH ROLLER CLUB",
					size = 11,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					height = 16,
					order = 1,
				}),
				React.createElement(Line, {
					value = `{club.RankName}  /  {club.XP} XP{if club.NextXP
						then " of " .. club.NextXP
						else " (top rank)"}`,
					size = 16,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					height = 24,
					order = 2,
				}),
				React.createElement(ShineBar, { value = progress, reducedMotion = reducedMotion, order = 3 }),
				React.createElement(Line, {
					value = `Every round earns Club XP (bigger stakes earn more). Played {stats.Played}, won {stats.Won}. Best streak {stats.BestStreak}, biggest win {compactNumber(
						stats.BiggestWin
					)} flux.`,
					size = 12,
					height = 48,
					order = 4,
				}),
				React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 22, order = 5 }),
			}
			for _, row in rows do
				table.insert(children, row)
			end
			return children
		end

		if table.find({ "TableRoulette", "QuantumRoulette", "CardTower", "DiceTable" }, tab) then
			return React.createElement(require(script.Parent.Parent.CasinoTables), {
				state = state,
				dispatch = dispatch,
				gameName = tab,
				tabs = TABS,
				onTab = setTab,
			})
		end
		local bodies = {
			Slots = slotsBody,
			Flip = flipBody,
			HighLow = highLowBody,
			Roulette = rouletteBody,
			Scratch = scratchBody,
			Exchange = exchangeBody,
			Club = clubBody,
		}
		local heights = {
			Slots = 486,
			Flip = 424,
			HighLow = 380,
			Roulette = 560,
			Scratch = 420,
			Exchange = 386,
			Club = 120 + #casino.Club.Ranks * 44 + 80,
		}
		local panelHeight = heights[tab] or 420
		local stats = casino.Stats

		return React.createElement(PageScaffold, {
			gap = 8,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
			scrollBarColor = accent,
			scrollBarThickness = 4,
			sections = {
				{
					id = "header",
					height = 92,
					element = React.createElement(
						Panel,
						{
							size = UDim2.fromScale(1, 1),
							accent = accent,
							background = Palette.panelRaised,
							padding = Layout.cardPadding,
							reveal = reveal,
							reducedMotion = reducedMotion,
						},
						React.createElement(Marquee, {
							position = UDim2.fromOffset(0, 0),
							mode = mode,
							reducedMotion = reducedMotion,
							color = accent,
						}),
						React.createElement(Text, {
							value = "ASTRAL CASINO",
							size = 10,
							color = accent,
							weight = Enum.FontWeight.Heavy,
							position = UDim2.fromOffset(0, 14),
							sizeConstraint = UDim2.new(1, 0, 0, 14),
						}),
						React.createElement(Text, {
							value = `Flux {compactNumber(state.Cash)}  /  {casino.Club.RankName}`,
							size = 18,
							color = Palette.cream,
							weight = Enum.FontWeight.Heavy,
							position = UDim2.fromOffset(0, 30),
							sizeConstraint = UDim2.new(1, 0, 0, 26),
						}),
						React.createElement(Text, {
							value = `Stakes are a share of your flux. A round never pays more than 4x what you had. Won {stats.Won} of {stats.Played}.`,
							size = 11,
							color = Palette.muted,
							wrap = true,
							position = UDim2.fromOffset(0, 58),
							sizeConstraint = UDim2.new(1, 0, 0, 30),
						})
					),
				},
				{
					id = "tabs",
					height = tabHeight,
					element = React.createElement(SegmentedTabs, {
						options = TABS,
						value = tab,
						onChange = function(id)
							sfx("casino_tick", 0.5)
							setTab(id)
						end,
						columns = tabColumns,
						accent = accent,
						size = UDim2.new(1, 0, 0, tabHeight),
						reducedMotion = reducedMotion,
					}),
				},
				{
					id = "game",
					height = panelHeight,
					element = React.createElement(
						"frame",
						{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 },
						{
							Panel = React.createElement(
								Panel,
								{
									size = UDim2.fromScale(1, 1),
									accent = accent,
									background = Palette.panelRaised,
									padding = Layout.cardPadding,
									reducedMotion = reducedMotion,
								},
								React.createElement(
									TabSwap,
									{ key = tab, direction = tabDirection },
									React.createElement(Stack, { gap = 8, children = bodies[tab]() })
								)
							),
							Coins = React.createElement(
								Confetti,
								{ token = fx.token, power = fx.power, reducedMotion = reducedMotion }
							),
							Banner = React.createElement(PayoutBanner, {
								token = banner.token,
								text = banner.text,
								amount = banner.amount,
								kind = banner.kind,
								reducedMotion = reducedMotion,
							}),
						}
					),
				},
			},
		})
	end

	return {
		CasinoView = CasinoView,
		SlotMachine = SlotMachine,
		Coin = Coin,
		Card = Card,
		Wheel = Wheel,
		ScratchCell = ScratchCell,
		Confetti = Confetti,
		PayoutBanner = PayoutBanner,
		Ticker = Ticker,
		Kit = {
			Stack = Stack,
			Line = Line,
			Row = Row,
			Buttons = Buttons,
			Tile = Tile,
			Marquee = Marquee,
			Confetti = Confetti,
			ShineBar = ShineBar,
			sfx = sfx,
			useRender = useRender,
			outCubic = outCubic,
			outBack = outBack,
			gradient = gradient,
		},
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
