--!nonstrict
--[=[
	PagesCasino: the Astral Casino page suite.
	Members (1): CasinoView.

	Same shape as the other page suites: `require(<this module>)("CasinoView")` (or index it) returns that
	member's exports, evaluated lazily once. Every roll, stake and payout happens on the server
	(CasinoService); this page picks a stake, sends one CasinoPlay action and performs what comes back:
	spinning reels that decelerate onto the answer, a coin that tumbles, cards that turn over, a roulette
	ball that rattles into its pocket, scratch cells that wipe clear, coin showers and payout banners, and
	custom sound effects (Shared/CasinoSfx) on every beat.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesCasino: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesCasino: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: CasinoView
-- ======================================================================
__defs["CasinoView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local CasinoSfx = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("CasinoSfx"))
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

local TABS = {
	{ id = "Slots", label = "Slots", accent = Palette.mango },
	{ id = "Flip", label = "Coin Flip", accent = Palette.cyan },
	{ id = "HighLow", label = "High-Low", accent = Palette.violet },
	{ id = "Roulette", label = "Roulette", accent = Palette.coral },
	{ id = "Scratch", label = "Scratch", accent = Palette.pink },
	{ id = "Exchange", label = "Exchange", accent = Palette.mint },
	{ id = "Club", label = "Club", accent = Palette.mango },
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
-- Each reel's strip: 18 cells, the rarer symbols appearing less often, shuffled differently per reel.
local STRIPS = {
	{ "Ember", "Dust", "Core", "Ember", "Comet", "Dust", "Ember", "Star", "Core", "Dust", "Ember", "Nova", "Core", "Ember", "Dust", "Comet", "Ember", "Dust" },
	{ "Dust", "Ember", "Comet", "Dust", "Core", "Ember", "Dust", "Ember", "Nova", "Core", "Ember", "Dust", "Star", "Ember", "Core", "Dust", "Comet", "Ember" },
	{ "Core", "Ember", "Dust", "Ember", "Star", "Dust", "Comet", "Ember", "Core", "Dust", "Ember", "Dust", "Nova", "Ember", "Core", "Comet", "Dust", "Ember" },
}
local CYCLE = 18
local REPS = 2
local CARD_NAMES = { [1] = "A", [11] = "J", [12] = "Q", [13] = "K" }
-- A European roulette wheel, clockwise from the zero.
local WHEEL = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
local RED = { [1] = true, [3] = true, [5] = true, [7] = true, [9] = true, [12] = true, [14] = true, [16] = true, [18] = true, [19] = true, [21] = true, [23] = true, [25] = true, [27] = true, [30] = true, [32] = true, [34] = true, [36] = true }

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

-- ----- easing and a frame loop -------------------------------------------------------------------

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

-- Runs `callback(dt, now)` every rendered frame while `enabled`; always calls the latest closure.
local function useRender(callback, enabled)
	local latest = React.useRef(callback)
	latest.current = callback
	React.useEffect(function()
		if enabled == false then
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(dt)
			latest.current(dt, os.clock())
		end)
		return function()
			connection:Disconnect()
		end
	end, { enabled })
end

-- ----- sound ---------------------------------------------------------------------------------------------

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

-- A looping sound; returns the function that stops it.
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

-- ----- small building blocks ---------------------------------------------------------------------------

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

-- n equal buttons across a row.
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

-- A rounded tile with one big word.
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

-- ----- marquee lights ----------------------------------------------------------------------------------

-- A string of bulbs that chase; `mode` "win" flashes them fast and gold.
local function Marquee(props)
	local count = props.count or 22
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

-- ----- a symbol gem -------------------------------------------------------------------------------------

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
			Stroke = React.createElement("uistroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.45 }),
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

-- ----- the slot machine ---------------------------------------------------------------------------------

-- Three reels. phase "spin": whirr until told to stop. phase "stop": each reel decelerates, one after the
-- other, onto `target[i]` with a little overshoot, calling onReel(i) as it lands and onSettled() when all have.
local function SlotMachine(props)
	local cellH = props.cellH or 52
	local reels = React.useRef(nil)
	local strips = React.useRef({})
	local blurs = React.useRef({})
	local band = React.useRef(nil)
	if reels.current == nil then
		reels.current = {}
		for index = 1, 3 do
			reels.current[index] = { pos = (index - 1) * 5, vel = 0, mode = "idle", start = 0, goal = 0, stopAt = 0, t0 = 0, dur = 1 }
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

	-- Idle reels show the last answer (or the opening line-up).
	React.useEffect(function()
		if props.phase == "idle" then
			for index = 1, 3 do
				local reel = reels.current[index]
				if reel.mode == "idle" and props.target then
					reel.pos = indexFor(STRIPS[index], props.target[index], math.floor(reel.pos))
				end
			end
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
			local strip = strips.current[index]
			if strip ~= nil and strip.Parent ~= nil then
				strip.Position = UDim2.fromOffset(0, -(((reel.pos - 1) % CYCLE) * cellH))
			end
			local blur = blurs.current[index]
			if blur ~= nil and blur.Parent ~= nil then
				blur.BackgroundTransparency = 1 - math.clamp(reel.vel / 26, 0, 1) * 0.5
			end
		end
		local glow = band.current
		if glow ~= nil and glow.Parent ~= nil then
			glow.Transparency = if props.flash then 0.1 + 0.35 * (math.sin(now * 14) + 1) / 2 else 0.6
		end
	end, not props.reducedMotion)

	local windows = {}
	for index = 1, 3 do
		local cells = {}
		for k = 0, CYCLE * REPS - 1 do
			cells["c" .. k] = React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, cellH),
				Position = UDim2.fromOffset(0, k * cellH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Gem, { id = STRIPS[index][(k % CYCLE) + 1], size = cellH }))
		end
		windows["w" .. index] = React.createElement("frame", {
			Size = UDim2.new(0.31, 0, 0, cellH * 3),
			BackgroundColor3 = Palette.ink,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = index,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("uistroke", { Color = Palette.mango, Thickness = 2, Transparency = 0.35 }),
			Strip = React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, cellH * CYCLE * REPS),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ref = function(instance)
					strips.current[index] = instance
				end,
			}, cells),
			Shade = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.ink, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 4 }, {
				Fade = React.createElement("uigradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0) }),
				}),
			}),
			Blur = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
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
		Top = React.createElement(Marquee, { position = UDim2.fromOffset(0, 4), mode = props.mode, reducedMotion = props.reducedMotion, color = Palette.mango }),
		Bottom = React.createElement(Marquee, { position = UDim2.new(0, 0, 1, -14), mode = props.mode, reducedMotion = props.reducedMotion, color = Palette.coral }),
		Reels = React.createElement("frame", { Size = UDim2.new(1, -20, 0, cellH * 3), Position = UDim2.fromOffset(10, 16), BackgroundTransparency = 1, BorderSizePixel = 0 }, windows),
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

-- ----- coin shower ---------------------------------------------------------------------------------------

-- Gold coins thrown up from the bottom and falling back; trigger it by bumping `token`.
local function Confetti(props)
	local count = 46
	local refs = React.useRef({})
	local sim = React.useRef({})
	local last = React.useRef(props.token)
	React.useEffect(function()
		if props.token == last.current then
			return
		end
		last.current = props.token
		local power = props.power or 1
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
		for index = 1, count do
			local p = sim.current[index]
			local piece = refs.current[index]
			if piece ~= nil and piece.Parent ~= nil then
				if p == nil or p.age >= p.life then
					piece.Visible = false
				else
					p.age += dt
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

-- ----- payout banner ------------------------------------------------------------------------------------

-- "+12.3K" that pops in, hangs and fades. kind: "win" | "big" | "jackpot" | "lose".
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
		local life = if props.kind == "jackpot" then 3.2 else 2.0
		frame.Visible = age < life and props.token > 0
		if scale.current ~= nil then
			scale.current.Scale = if age < 0.45 then 0.3 + 0.9 * outBack(age / 0.45) elseif props.kind == "jackpot" then 1.2 + 0.08 * math.sin(now * 9) else 1.2 - 0.2 * math.clamp((age - 0.45) / 0.8, 0, 1)
		end
		frame.TextTransparency = math.clamp((age - (life - 0.5)) / 0.5, 0, 1)
	end, not props.reducedMotion)
	local color = if props.kind == "lose" then Palette.coral elseif props.kind == "jackpot" then Palette.pink else Palette.mango
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

-- ----- the coin --------------------------------------------------------------------------------------------

-- A coin that tumbles. `phase` "spin" tumbles until told to land; "land" settles on `heads` with a bounce.
local function Coin(props)
	local coin = React.useRef(nil)
	local face = React.useRef(nil)
	local motion = React.useRef({ angle = 0, speed = 0, mode = "rest", t0 = 0, from = 0, to = 0 })
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
			lift = 18 + 14 * math.sin(now * 5)
		elseif m.mode == "land" then
			local k = (now - m.t0) / 1.15
			m.angle = m.from + (m.to - m.from) * outCubic(k)
			lift = 70 * math.sin(math.pi * math.clamp(k, 0, 1)) * (1 - 0.3 * k)
			if k >= 1 then
				m.angle, m.mode = m.to, "rest"
				if props.onLanded then
					props.onLanded()
				end
			end
		end
		local c = coin.current
		if c ~= nil and c.Parent ~= nil then
			local s = math.abs(math.cos(m.angle))
			c.Size = UDim2.fromOffset(math.max(6, 96 * s), 96)
			c.Position = UDim2.new(0.5, 0, 1, -56 - lift)
		end
		local f = face.current
		if f ~= nil and f.Parent ~= nil then
			f.Text = if math.cos(m.angle) >= 0 then "H" else "T"
		end
	end, not props.reducedMotion)
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = props.order or 0 }, {
		Shadow = React.createElement("frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(80, 10), BackgroundColor3 = Palette.shadow, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		Coin = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -56),
			Size = UDim2.fromOffset(96, 96),
			BackgroundColor3 = Palette.mango,
			BorderSizePixel = 0,
			ref = coin,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fill = gradient(Color3.fromRGB(255, 232, 150), Color3.fromRGB(214, 140, 30), 120),
			Rim = React.createElement("uistroke", { Color = Palette.brassDeep, Thickness = 5 }),
			Face = React.createElement("textlabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "H",
				TextColor3 = Palette.brassDeep,
				Font = Enum.Font.BuilderSansExtraBold,
				TextSize = 46,
				ref = face,
			}),
		}),
	})
end

-- ----- playing cards ---------------------------------------------------------------------------------------

-- A card that turns over when `flip` changes (back, then face with the new rank).
local function Card(props)
	local card = React.useRef(nil)
	local rankLabel = React.useRef(nil)
	local anim = React.useRef({ t0 = -10, shown = props.rank })
	local last = React.useRef(props.flip)
	React.useEffect(function()
		if props.flip ~= last.current then
			last.current = props.flip
			anim.current.t0 = os.clock()
			if props.reducedMotion then
				anim.current.shown = props.rank
			end
		end
	end, { props.flip })
	useRender(function(_, now)
		local k = (now - anim.current.t0) / 0.55
		local c = card.current
		if c == nil or c.Parent == nil then
			return
		end
		local scale = 1
		if k >= 0 and k < 1 then
			scale = math.abs(math.cos(k * math.pi))
			if k > 0.5 then
				anim.current.shown = props.rank
			end
			c.Rotation = math.sin(k * math.pi) * -5
		else
			anim.current.shown = props.rank
			c.Rotation = 0
		end
		c.Size = UDim2.fromOffset(math.max(4, props.width * scale), props.height)
		local label = rankLabel.current
		if label ~= nil and label.Parent ~= nil then
			label.Text = if anim.current.shown then cardName(anim.current.shown) else "?"
			label.Visible = not (k >= 0 and k < 0.5)
		end
	end, not props.reducedMotion)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(props.width, props.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order or 0,
	}, {
		Card = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(props.width, props.height),
			BackgroundColor3 = Palette.cream,
			BorderSizePixel = 0,
			ref = card,
		}, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Edge = React.createElement("uistroke", { Color = props.color or Palette.violet, Thickness = 3 }),
			Fill = gradient(Color3.new(1, 1, 1), Color3.fromRGB(226, 216, 236), 90),
			Rank = React.createElement("textlabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if props.rank then cardName(props.rank) else "?",
				TextColor3 = props.color or Palette.violet,
				Font = Enum.Font.BuilderSansExtraBold,
				TextSize = math.floor(props.height * 0.5),
				ref = rankLabel,
			}),
		}),
	})
end

-- ----- the roulette wheel -------------------------------------------------------------------------------------

-- Pockets round a rim that turns slowly; the ball rattles round the other way and settles into the winning
-- pocket. phase "spin": the ball circles; "land": it decelerates into pocket `number` and calls onLanded.
local function Wheel(props)
	local diameter = props.size or 190
	local rim = React.useRef(nil)
	local ball = React.useRef(nil)
	local motion = React.useRef({ turn = 0, mode = "rest", t0 = 0, rel = 0, pocket = 0 })
	local pocketAngle = {}
	for index, number in WHEEL do
		pocketAngle[number] = (index - 1) / #WHEEL * math.pi * 2
	end
	React.useEffect(function()
		local m = motion.current
		if props.phase == "spin" then
			m.mode, m.t0 = "orbit", os.clock()
		elseif props.phase == "land" and props.number ~= nil then
			m.mode, m.t0, m.pocket = "land", os.clock(), pocketAngle[props.number]
			if props.reducedMotion then
				m.mode, m.rel = "rest", m.pocket
				if props.onLanded then
					props.onLanded()
				end
			end
		end
	end, { props.phase, props.token })
	useRender(function(dt, now)
		local m = motion.current
		m.turn += dt * (if m.mode == "orbit" or m.mode == "land" then 0.9 else 0.25)
		local r = rim.current
		if r ~= nil and r.Parent ~= nil then
			r.Rotation = math.deg(m.turn)
		end
		local radius, angle = 0.34, m.rel
		if m.mode == "orbit" then
			angle = -(now - m.t0) * 9
			radius = 0.43
		elseif m.mode == "land" then
			local k = (now - m.t0) / 3.0
			local eased = outCubic(k)
			angle = m.pocket - (1 - eased) * math.pi * 2 * 7
			radius = 0.43 - 0.09 * outBounce(math.clamp((k - 0.7) / 0.3, 0, 1))
			if k >= 1 then
				m.rel, m.mode = m.pocket, "rest"
				angle = m.pocket
				if props.onLanded then
					props.onLanded()
				end
			end
		end
		local b = ball.current
		if b ~= nil and b.Parent ~= nil then
			-- the ball rides in the wheel's own frame, so it turns with the rim once it has dropped
			local world = angle + (if m.mode == "rest" or m.mode == "land" then m.turn else 0)
			b.Position = UDim2.fromScale(0.5 + math.sin(world) * radius, 0.5 - math.cos(world) * radius)
		end
	end, not props.reducedMotion)
	local pockets = {}
	for index, number in WHEEL do
		local angle = (index - 1) / #WHEEL * 360
		local color = if number == 0 then Palette.mint elseif RED[number] then Palette.coral else Palette.graphite
		pockets["p" .. index] = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(math.rad(angle)) * 0.34, 0.5 - math.cos(math.rad(angle)) * 0.34),
			Size = UDim2.fromOffset(diameter * 0.075, diameter * 0.14),
			Rotation = angle,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { Stroke = React.createElement("uistroke", { Color = Palette.brass, Thickness = 1, Transparency = 0.2 }) })
	end
	return React.createElement("frame", { Size = UDim2.fromOffset(diameter, diameter), BackgroundColor3 = Palette.night, BorderSizePixel = 0, LayoutOrder = props.order or 0 }, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }),
		Trim = React.createElement("uistroke", { Color = Palette.brass, Thickness = 5 }),
		Rim = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ref = rim }, pockets),
		Hub = React.createElement("frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = Palette.brassDeep, BorderSizePixel = 0 }, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }),
			Ring = React.createElement("uistroke", { Color = Palette.brass, Thickness = 3 }),
			Fill = gradient(Palette.brass, Palette.brassDeep, 90),
		}),
		Ball = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.07),
			Size = UDim2.fromOffset(diameter * 0.06, diameter * 0.06),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 6,
			ref = ball,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) }),
	})
end

-- ----- one scratch cell ----------------------------------------------------------------------------------------

-- A cell under a silver cover that wipes away `delay` seconds after `token` changes.
local function ScratchCell(props)
	local cover = React.useRef(nil)
	local born = React.useRef(-100)
	local fired = React.useRef(true)
	local last = React.useRef(props.token)
	React.useEffect(function()
		if props.token ~= last.current then
			last.current = props.token
			born.current = os.clock()
			fired.current = false
		end
	end, { props.token })
	useRender(function(_, now)
		local c = cover.current
		if c == nil or c.Parent == nil then
			return
		end
		local k = (now - born.current - props.delay) / 0.4
		if props.symbol == nil then
			c.Visible = true
			c.Size = UDim2.fromScale(1, 1)
			c.BackgroundTransparency = 0
		elseif k >= 0 then
			if not fired.current then
				fired.current = true
				if props.onReveal then
					props.onReveal()
				end
			end
			c.Visible = k < 1
			c.Size = UDim2.fromScale(1 - outCubic(k), 1)
			c.BackgroundTransparency = math.clamp(k, 0, 1) * 0.6
		end
	end, not props.reducedMotion)
	local id = props.symbol
	local color = if id then (SYMBOL_COLORS[id] or Palette.cream) else Palette.muted
	return React.createElement("frame", {
		Size = props.size or UDim2.new(0.31, 0, 1, 0),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.order or 0,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("uistroke", { Color = if props.glow then Palette.mango else color, Thickness = if props.glow then 3 else 2, Transparency = 0.2 }),
		Gem = if id then React.createElement(Gem, { id = id, size = 50 }) else nil,
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
			Mark = React.createElement(Text, { value = "?", size = 20, color = Palette.graphite, weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center }),
		}),
	})
end

-- ----- the exchange ticker -----------------------------------------------------------------------------------

-- The last four hours of the market as bars that grow in, with a line at par.
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
				bar.Size = UDim2.new(1 / math.max(1, #history), -3, height(history[index] or 1) * outCubic((now - born.current - index * 0.02) / 0.5), 0)
			end
		end
	end, not props.reducedMotion)
	local children = {
		Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
	}
	for index, mood in history do
		children["b" .. index] = React.createElement("frame", {
			Size = UDim2.new(1 / math.max(1, #history), -3, height(mood), 0),
			BackgroundColor3 = if index == #history then Palette.mint elseif mood < 1 then Palette.green else Palette.coral,
			BackgroundTransparency = if index == #history then 0 else 0.35,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ref = function(instance)
				bars.current[index] = instance
			end,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) }) })
	end
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = Palette.night, BorderSizePixel = 0, LayoutOrder = props.order or 0 }, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("uistroke", { Color = Palette.line, Thickness = 1 }),
		Bars = React.createElement("frame", { Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0 }, children),
		Par = React.createElement("frame", { Size = UDim2.new(1, -12, 0, 1), Position = UDim2.new(0, 6, 1, -6 - (1 - 0.55 + 0.0) / 1.0 * (90 - 12) * 0 - height(1) * (90 - 12)), BackgroundColor3 = Palette.cream, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 3 }),
	})
end

-- ----- one rank in the club ladder -----------------------------------------------------------------------------

local function ClubRankRow(props)
	local rank = props.rank
	local reward = if rank.Reward then formatReward(rank.Reward) else "Welcome"
	local text, color, textColor, disabled, highlight = `{rank.XP} XP`, Palette.panelSoft, nil, true, false
	if rank.Claimed then
		text = "CLAIMED"
	elseif rank.Claimable then
		text, color, textColor, disabled, highlight = "CLAIM", Palette.mango, Palette.ink, props.busy, true
	end
	return React.createElement(Row, { height = 38, order = props.order, gap = 8, children = {
		React.createElement(Text, { value = `{rank.Name}: {reward}`, size = 12, color = if props.reached then Palette.cream else Palette.muted, sizeConstraint = UDim2.new(0.66, 0, 1, 0), layoutOrder = 1 }),
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
	} })
end

-- A progress bar whose fill eases to its value and carries a moving shine.
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

local function stakeLine(state, tier)
	local stake = state.Casino.Stakes[tier]
	if stake == nil then
		return ""
	end
	return `Stake: {compactNumber(stake.Amount)} flux ({stake.Share * 100}% of yours)`
end

-- ----- the page ------------------------------------------------------------------------------------------------------

local function CasinoView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = props.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local reveal = useStagger(0, reducedMotion)
	local casino = state.Casino

	local tab, setTab = React.useState(props.initialTab or "Slots")
	local tier, setTier = React.useState(2)
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState({ text = "Pick a game and a stake. The house keeps a few percent, and you can walk away any time.", good = nil })
	local last, setLast = React.useState({})
	local pick, setPick = React.useState("Red")
	local straight, setStraight = React.useState(17)
	-- one animation state per game
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

	-- The animation is finished: show the outcome, throw coins, play the right fanfare.
	local function conclude(response)
		if not mounted.current then
			return
		end
		local result = response.Result or {}
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
			sfx(if kind == "jackpot" then "casino_jackpot" elseif kind == "big" then "casino_win_big" else "casino_win_small", 0.8)
			if result.Cashed then
				sfx("casino_cash", 0.6)
			end
			setFx({ token = fx.token + 1, power = if kind == "jackpot" then 2.2 elseif kind == "big" then 1.5 else 1 })
			setBanner({ token = banner.token + 1, text = `+{compactNumber(result.Payout)}`, kind = kind })
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
		setBusy(false)
		setMode("idle")
		setNote({ text = response.error or "That didn't go through.", good = false })
		sfx("casino_lose", 0.4, 1.3)
		Audio:play("error")
	end

	-- One tap, one server round; `onResponse(response)` runs the game's own animation, which ends in conclude().
	local function play(payload, onResponse)
		if busy or casino == nil then
			return
		end
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
			sections = { {
				id = "loading",
				height = 80,
				element = React.createElement(Text, { value = "The casino is warming up...", size = 14, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }),
			} },
		})
	end

	local accent = Palette.mango
	for _, entry in TABS do
		if entry.id == tab then
			accent = entry.accent
		end
	end
	local stakes = casino.Stakes
	local noteColor = if note.good == true then Palette.mint elseif note.good == false then Palette.coral else Palette.muted

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
		return React.createElement(Buttons, { items = items, height = 40, order = order, reducedMotion = reducedMotion })
	end

	-- ------------------------------------------------------------------ slots
	local function slotsBody()
		local pays = {}
		for _, symbol in casino.Slots.Symbols do
			table.insert(pays, `{symbol.Id} {symbol.Pay3}x`)
		end
		return {
			React.createElement(Line, { value = "STARLIGHT SLOTS", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(SlotMachine, {
				order = 2,
				phase = slot.phase,
				target = slot.target,
				token = slot.token,
				mode = if mode == "win" then "win" elseif slot.phase == "spin" or slot.phase == "stop" then "spin" else "idle",
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
			React.createElement(Buttons, { items = { {
				text = if busy then "SPINNING..." else "SPIN",
				onClick = function()
					sfx("casino_chip", 0.6)
					stopWhir.current = loopSfx("casino_spin", 0.5)
					setSlot({ phase = "spin", target = slot.target, token = slot.token + 1 })
					setMode("spin")
					play({ Game = "Slots", Tier = tier }, function(response)
						pending.current = response
						setSlot({ phase = "stop", target = response.Result.Reels, token = slot.token + 2 })
					end)
				end,
				color = Palette.mango,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			} }, height = 54, order = 6, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Three alike pays: {table.concat(pays, "  ")}. Two Embers or Dusts pay a little. Returns {percent(casino.Slots.Rtp)}.`, size = 11, height = 44, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ coin flip
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
			React.createElement(Line, { value = "DOUBLE OR NOTHING", size = 11, color = Palette.cyan, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
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
			if flip.Active then React.createElement(Line, { value = `Stake {compactNumber(flip.Stake)} flux, now worth {times(flip.Multiplier)}. {flip.Streak} in a row. One tails loses the lot.`, size = 12, order = 4, height = 34 }) else stakePicker(4),
			if flip.Active then React.createElement(Line, { value = "", order = 5, height = 2 }) else React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = items, height = 52, order = 6, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Each flip is {percent(flip.Chance)} to land heads, and pays x1.92 on top of the last. The streak caps at {flip.MaxStreak}.`, size = 11, height = 30, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ high-low
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
				text = if round.High.Chance > 0 then `HIGHER {percent(round.High.Chance)} ({times(round.High.Step)})` else "HIGHER (none)",
				onClick = function()
					turn({ Game = "HighLow", Op = "Guess", Pick = "High" })
				end,
				color = Palette.violet,
				textColor = Palette.ink,
				disabled = busy or round.High.Chance <= 0,
			}
			items[2] = {
				text = if round.Low.Chance > 0 then `LOWER {percent(round.Low.Chance)} ({times(round.Low.Step)})` else "LOWER (none)",
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
			React.createElement(Line, { value = "HIGH-LOW LADDER", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 110, order = 2, gap = 12, children = {
				React.createElement(Card, { rank = shownRank, flip = card.flip, width = 78, height = 108, color = Palette.violet, reducedMotion = reducedMotion, order = 1 }),
				React.createElement(Tile, { value = if round.Active then `{round.Streak} right` else "no round", color = Palette.cream, textSize = 15, size = UDim2.fromOffset(86, 70), order = 2 }),
				React.createElement(Tile, { value = if round.Active then times(round.Multiplier) else "x1.00", color = Palette.mango, textSize = 20, size = UDim2.fromOffset(86, 70), order = 3 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
			if round.Active then React.createElement(Line, { value = `Stake {compactNumber(round.Stake)} flux. A tie loses. Cards run Ace (low) to King (high).`, size = 12, order = 4, height = 34 }) else stakePicker(4),
			if round.Active then React.createElement(Line, { value = "", order = 5, height = 2 }) else React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = items, height = 50, order = 6, reducedMotion = reducedMotion }),
			if round.Active then React.createElement(Buttons, { items = { {
				text = if round.Streak > 0 then `CASH OUT {compactNumber(round.Cashout)}` else "WIN A GUESS FIRST",
				onClick = function()
					sfx("casino_chip", 0.6)
					play({ Game = "HighLow", Op = "Cashout" })
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy or round.Streak < 1,
			} }, height = 44, order = 7, reducedMotion = reducedMotion }) else React.createElement(Line, { value = "Every guess pays 96% of its true odds, so the safer the guess the smaller the step.", size = 11, height = 30, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ roulette
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
		local numberFill = if resultColor == "Red" then Palette.coral elseif resultColor == "Green" then Palette.mint else Palette.panelSoft
		local picked = if string.sub(pick, 1, 1) == "N" then `Number {string.sub(pick, 2)} pays x36` else `{pick} pays x{(pick == "D1" or pick == "D2" or pick == "D3" or pick == "C1" or pick == "C2" or pick == "C3") and 3 or 2}`
		return {
			React.createElement(Line, { value = "ASTRAL ROULETTE", size = 11, color = Palette.coral, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 196, order = 2, gap = 12, children = {
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
				React.createElement(Tile, { value = if resultNumber then tostring(resultNumber) else "--", fill = numberFill, color = Palette.cream, size = UDim2.fromOffset(64, 64), order = 2, textSize = 28 }),
			} }),
			React.createElement(Line, { value = `{picked}. {note.text}`, size = 13, color = noteColor, height = 34, order = 3 }),
			React.createElement(Buttons, { items = { option("Red", "Red"), option("Black", "Black"), option("Odd", "Odd"), option("Even", "Even") }, height = 34, order = 4, reducedMotion = reducedMotion }),
			React.createElement(Buttons, { items = { option("1-18", "Low"), option("19-36", "High"), option("1st 12", "D1"), option("2nd 12", "D2"), option("3rd 12", "D3") }, height = 34, order = 5, reducedMotion = reducedMotion }),
			React.createElement(Buttons, { items = {
				option("Col 1", "C1"), option("Col 2", "C2"), option("Col 3", "C3"),
				{ text = "-", onClick = function() sfx("casino_tick", 0.5) setStraight((straight + 36) % 37) end, color = Palette.panelSoft, disabled = busy },
				option(`Number {straight}`, `N{straight}`),
				{ text = "+", onClick = function() sfx("casino_tick", 0.5) setStraight((straight + 1) % 37) end, color = Palette.panelSoft, disabled = busy },
			}, height = 34, order = 6, reducedMotion = reducedMotion }),
			stakePicker(7, busy),
			React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 8, height = 18 }),
			React.createElement(Buttons, { items = { {
				text = if busy then "..." else "SPIN THE WHEEL",
				onClick = function()
					sfx("casino_chip", 0.6)
					stopRoll.current = loopSfx("casino_ball_roll", 0.5)
					setWheel({ phase = "spin", number = nil, token = wheel.token + 1 })
					play({ Game = "Roulette", Tier = tier, Pick = pick }, function(response)
						pending.current = response
						setWheel({ phase = "land", number = response.Result.Number, token = wheel.token + 2 })
					end)
				end,
				color = Palette.coral,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			} }, height = 50, order = 9, reducedMotion = reducedMotion }),
		}
	end

	-- ------------------------------------------------------------------ scratch cards
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
			{ text = if busy then "..." else "BUY A CARD", onClick = function() scratchCard(false) end, color = Palette.pink, textColor = Palette.ink, disabled = busy, highlight = not busy and not free },
		}
		if free then
			table.insert(items, 1, { text = "FREE DAILY CARD", onClick = function() scratchCard(true) end, color = Palette.mint, textColor = Palette.ink, disabled = busy, highlight = not busy })
		end
		local pays = {}
		for _, symbol in casino.Scratch.Symbols do
			table.insert(pays, `{symbol.Id} {symbol.Pay}x`)
		end
		return {
			React.createElement(Line, { value = "SCRATCH CARDS", size = 11, color = Palette.pink, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 64, order = 2, gap = 8, children = cellRow(1) }),
			React.createElement(Row, { height = 64, order = 3, gap = 8, children = cellRow(4) }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 4 }),
			stakePicker(5, busy),
			React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 6, height = 18 }),
			React.createElement(Buttons, { items = items, height = 50, order = 7, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Match three or more of one symbol: {table.concat(pays, "  ")}. Returns {percent(casino.Scratch.Rtp)}. The daily card is free, at the Pocket stake.`, size = 11, height = 44, order = 8 }),
		}
	end

	-- ------------------------------------------------------------------ exchange
	local function exchangeBody()
		local market = casino.Exchange
		local delta = math.floor((market.Mood - 1) * 100 + 0.5)
		local trend = if market.Trend > 0.02 then "rising" elseif market.Trend < -0.02 then "falling" else "steady"
		local remaining = math.max(0, market.NextAt - os.time())
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
			React.createElement(Line, { value = "STARDUST EXCHANGE", size = 11, color = Palette.mint, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 60, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `{compactNumber(market.Price)} flux`, color = Palette.mint, textSize = 18, size = UDim2.new(0.48, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = `{if delta >= 0 then "+" else ""}{delta}% {trend}`, color = if delta <= 0 then Palette.mint else Palette.coral, textSize = 15, size = UDim2.new(0.48, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Ticker, { history = market.History, tab = tab, reducedMotion = reducedMotion, order = 3 }),
			React.createElement(Line, { value = `One Stardust costs the price above. The market moves every ten minutes (next change in {clockText(remaining)}), the same for everyone, and is cheaper when it is below par.`, size = 12, height = 48, order = 4 }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 24, order = 5 }),
			React.createElement(Line, { value = `{market.Left} of {market.Cap} Stardust left to buy today.`, size = 12, order = 6, height = 18 }),
			React.createElement(Buttons, { items = { buy(1), buy(5), buy(20) }, height = 48, order = 7, reducedMotion = reducedMotion }),
		}
	end

	-- ------------------------------------------------------------------ club
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
			React.createElement(Line, { value = "HIGH ROLLER CLUB", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{club.RankName}  /  {club.XP} XP{if club.NextXP then " of " .. club.NextXP else " (top rank)"}`, size = 16, color = Palette.cream, weight = Enum.FontWeight.Heavy, height = 24, order = 2 }),
			React.createElement(ShineBar, { value = progress, reducedMotion = reducedMotion, order = 3 }),
			React.createElement(Line, { value = `Every round earns Club XP (bigger stakes earn more). Played {stats.Played}, won {stats.Won}. Best streak {stats.BestStreak}, biggest win {compactNumber(stats.BiggestWin)} flux.`, size = 12, height = 48, order = 4 }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 22, order = 5 }),
		}
		for _, row in rows do
			table.insert(children, row)
		end
		return children
	end

	local bodies = { Slots = slotsBody, Flip = flipBody, HighLow = highLowBody, Roulette = rouletteBody, Scratch = scratchBody, Exchange = exchangeBody, Club = clubBody }
	local heights = { Slots = 428, Flip = 396, HighLow = 424, Roulette = 556, Scratch = 450, Exchange = 408, Club = 120 + #casino.Club.Ranks * 44 + 80 }
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
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reveal = reveal,
					reducedMotion = reducedMotion,
				}, React.createElement(Marquee, { position = UDim2.fromOffset(0, 0), mode = mode, reducedMotion = reducedMotion, color = accent }), React.createElement(Text, {
					value = "ASTRAL CASINO",
					size = 10,
					color = accent,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 14),
					sizeConstraint = UDim2.new(1, 0, 0, 14),
				}), React.createElement(Text, {
					value = `Flux {compactNumber(state.Cash)}  /  {casino.Club.RankName}`,
					size = 18,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 30),
					sizeConstraint = UDim2.new(1, 0, 0, 26),
				}), React.createElement(Text, {
					value = `Stakes are a share of your flux. A round never pays more than 4x what you had. Won {stats.Won} of {stats.Played}.`,
					size = 11,
					color = Palette.muted,
					wrap = true,
					position = UDim2.fromOffset(0, 58),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				})),
			},
			{
				id = "tabs",
				height = 96,
				element = React.createElement(SegmentedTabs, {
					options = TABS,
					value = tab,
					onChange = function(id)
						sfx("casino_tick", 0.5)
						setTab(id)
					end,
					columns = 4,
					accent = accent,
					size = UDim2.new(1, 0, 0, 96),
					reducedMotion = reducedMotion,
				}),
			},
			{
				id = "game",
				height = panelHeight,
				element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
					Panel = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = accent,
						background = Palette.panelRaised,
						padding = Layout.cardPadding,
						reducedMotion = reducedMotion,
					}, React.createElement(Stack, { gap = 8, children = bodies[tab]() })),
					Coins = React.createElement(Confetti, { token = fx.token, power = fx.power, reducedMotion = reducedMotion }),
					Banner = React.createElement(PayoutBanner, { token = banner.token, text = banner.text, kind = banner.kind, reducedMotion = reducedMotion }),
				}),
			},
		},
	})
end

-- The animated parts are exported too, so each can be driven on its own (tests, and a future minigame hub).
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
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
