--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("BootKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("BootKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["BootScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local BrandArt = require(script.Parent.ArtKit)("Icon")
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local STAR_COUNT = 30
local TICK_COUNT = 36
local BootStageText = __load("BootStageText").BootStageText
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local MotionTokens = require(script.Parent.MotionKit)("motionTokens")
local BOOT_MODULE_TIMEOUT = 9
local MIN_BOOT_SECONDS = 3.2
local BOOT_MOTION = {
	motionScale = 1,
	viewportScale = 1,
	textScale = 1,
}
local EXIT_SPIN_SECONDS = 0.22
local EXIT_VEIL_SECONDS = 0.32
local STALL_SECONDS = 45
local SYSTEMS = { "bridge", "remotes", "state", "assets", "modules", "fonts", "audio", "shell", "mail", "research", "forge", "trade", "boosts", "settings", "mobile" }
local STAGE_LABELS = { "Connecting", "Connecting", "Connecting", "Loading art", "Loading art", "Loading art", "Loading sounds", "Building the menus", "Opening your save", "Opening your save", "Opening your save", "Opening your save", "Opening your save", "Opening your save", "Almost there", "Ready" }
local LOADING_TIPS = {
	"Research stays with you when you rebirth.",
	"A full vault stops filling. Collect it often.",
	"Overcharge a machine by tapping it fast.",
	"Your Forge build keeps every bonus you've earned.",
	"Boosts stack with research, so start one before a long session.",
	"Rebirth when the Cores on offer would beat what you have now.",
	"The wheel's pity counter guarantees a rare sooner or later.",
	"Auto-Forge keeps buying your best machine while you're away.",
	"Daily shop stock changes at midnight UTC.",
	"Relics can be salvaged for essence if you pull a duplicate.",
	"You can replay the tour from Settings.",
}
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function statusFor(marks, ready, stalled, loaded, total)
	if ready then
		return "Ready"
	end
	local stage = 0
	for _, key in SYSTEMS do
		if marks[key] then
			stage += 1
		else
			break
		end
	end
	if stalled then
		return "Almost there"
	end
	if stage >= #SYSTEMS then
		return "Ready"
	end
	local _condition = STAGE_LABELS[math.min(stage, #STAGE_LABELS - 1) + 1]
	if _condition == nil then
		_condition = "Loading"
	end
	return _condition
end
local function progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	local complete = 0
	for _, key in SYSTEMS do
		if marks[key] then
			complete += 1
		end
	end
	local partial = 0
	if not marks.assets and assetsTotal ~= nil and assetsTotal > 0 and assetsLoaded ~= nil then
		partial += math.clamp(assetsLoaded / assetsTotal, 0, 1) * 0.85
	end
	if not marks.modules and modulesTotal ~= nil and modulesTotal > 0 and modulesLoaded ~= nil then
		partial += math.clamp(modulesLoaded / modulesTotal, 0, 1) * 0.85
	end
	return math.clamp((complete + partial) / #SYSTEMS, 0, 1)
end
local function bootChecklistReady(marks)
	for _, key in SYSTEMS do
		if not marks[key] then
			return false
		end
	end
	return true
end
local function bootProgress(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	return progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
end
local function BootScreen(_param)
	local short = useViewport().height < 420
	local centerY = if short then 0.36 else 0.42
	-- core, wordmark and status offsets from centerY; short landscape keeps all of it above the tip
	local coreSize = if short then 108 else 212
	local coreY = if short then -36 else -54
	local wordY = if short then 24 else 70
	local statusY = if short then 64 else 142
	local marks = _param.marks
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local startedAt = _param.startedAt
	local assetsLoaded = _param.assetsLoaded
	local assetsTotal = _param.assetsTotal
	local modulesLoaded = _param.modulesLoaded
	local modulesTotal = _param.modulesTotal
	local _version = _param.version
	local onExitDone = _param.onExitDone
	local _condition = startedAt
	if _condition == nil then
		_condition = os.clock()
	end
	local mountedAt = React.useRef(_condition)
	local finished = React.useRef(false)
	local exitClock = React.useRef(0)
	local spinClock = React.useRef(0)
	local exiting, setExiting = React.useState(false)
	local gone, setGone = React.useState(false)
	local stalled, setStalled = React.useState(false)
	local tipIndex, setTipIndex = React.useState(0)
	local clock, setClock = React.useBinding(0)
	local spinFade, setSpinFade = React.useBinding(0)
	local veilFade, setVeilFade = React.useBinding(0)
	local veilHide = veilFade
	local progressPulse, setProgressPulse = React.useBinding(0)
	local shownProgress, setShownProgress = React.useBinding(0)
	local shownRef = React.useRef(0)
	local targetProgress = React.useRef(0)
	React.useEffect(function()
		local alive = true
		Audio:setScene("boot")
		local start = function()
			if alive and os.clock() - mountedAt.current <= 0.55 then
				Audio:play("bootStart")
			end
		end
		if Audio:isWarm() then
			start()
		else
			Audio:whenWarm(start)
		end
		return function()
			alive = false
			Audio:setScene("default")
		end
	end, {})
	React.useEffect(function()
		local assetList = { BrandArt.GAME_ICON_ASSET, BrandArt.WORDMARK_ASSET, BrandArt.COMPACT_MARK_ASSET }
		local isStudio = false
		pcall(function()
			local rs = game:GetService("RunService")
			if rs and type(rs.IsStudio) == "function" then
				isStudio = rs:IsStudio()
			end
		end)
		local preload = task.spawn(function()
			local ok, reason = pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(assetList, function(asset, status)
					if status ~= Enum.AssetFetchStatus.Success and not isStudio then
						warn(`[Branding] {asset} failed to load: {status.Name}`)
					end
				end)
			end)
			if not ok and not isStudio then
				warn(`[Branding] Preload failed: {tostring(reason)}`)
			end
		end)
		return function()
			if coroutine.status(preload) == "suspended" then
				task.cancel(preload)
			end
		end
	end, {})
	React.useEffect(function()
		local current = tipIndex
		local token = task.delay(3.2, function()
			return setTipIndex((current + 1) % #LOADING_TIPS)
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { tipIndex })
	React.useEffect(function()
		if ready then
			return nil
		end
		local elapsed = os.clock() - mountedAt.current
		local remaining = math.max(0, STALL_SECONDS - elapsed)
		local token = task.delay(remaining, function()
			return setStalled(true)
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { ready })
	React.useEffect(function()
		if ready and not exiting and not finished.current then
			local elapsed = os.clock() - mountedAt.current
			local hold = math.max(0, MIN_BOOT_SECONDS - elapsed)
			local token = task.delay(hold, function()
				if finished.current then
					return nil
				end
				finished.current = true
				exitClock.current = 0
				setExiting(true)
				Audio:play("bootReady")
			end)
			return function()
				pcall(task.cancel, token)
			end
		elseif not exiting and not finished.current then
			local timeout = if RunService:IsStudio() then 22 else 36
			local token = task.delay(timeout, function()
				if not finished.current then
					finished.current = true
					exitClock.current = 0
					setExiting(true)
				end
			end)
			return function()
				pcall(task.cancel, token)
			end
		end
	end, { exiting, ready })
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			shownRef.current += (targetProgress.current - shownRef.current) * (1 - math.exp(-dt * 7))
			setShownProgress(shownRef.current)
			local rate = if softMotion then 0.55 else 1
			spinClock.current += dt * rate
			setClock(spinClock.current)
			setProgressPulse((math.sin(spinClock.current * 2.4) + 1) * 0.5)
			if not exiting then
				return nil
			end
			exitClock.current += dt
			local elapsed = exitClock.current
			local spinSeconds = if softMotion then EXIT_SPIN_SECONDS * 0.55 else EXIT_SPIN_SECONDS
			local veilSeconds = if softMotion then EXIT_VEIL_SECONDS * 0.55 else EXIT_VEIL_SECONDS
			setSpinFade(MotionTokens.EASE.accelerate(clamp01(elapsed / spinSeconds)))
			setVeilFade(MotionTokens.EASE.smoothInOut(clamp01((elapsed - spinSeconds) / veilSeconds)))
		end)
		return function()
			return connection:Disconnect()
		end
	end, { exiting, softMotion, setClock, setSpinFade, setVeilFade })
	React.useEffect(function()
		if not exiting then
			return nil
		end
		local span = (EXIT_SPIN_SECONDS + EXIT_VEIL_SECONDS) * (if softMotion then 0.55 else 1) + 0.05
		local token = task.delay(span, function()
			setGone(true)
			onExitDone()
		end)
		return function()
			pcall(task.cancel, token)
		end
	end, { exiting, onExitDone })
	if gone then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local status = statusFor(marks, ready, stalled, assetsLoaded, assetsTotal)
	local progress = if ready then 1 else progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal)
	targetProgress.current = progress
	local tipText = LOADING_TIPS[tipIndex + 1] or ""
	local hidden = spinFade:map(function(amount)
		return amount
	end)
	local showing = spinFade:map(function(amount)
		return amount < 0.98
	end)
	local function fadeFrom(base)
		return hidden:map(function(amount)
			return math.clamp(base + amount, 0, 1)
		end)
	end

	-- the forge core: a ring of ticks that light up as loading goes, two counter-rotating orbits,
	-- a breathing glow and stars streaming out of the middle
	local driftRate = if softMotion then 0.5 else 1
	local orbitRate = if softMotion then 0.45 else 1

	local stars = {}
	for index = 1, STAR_COUNT do
		local seed = math.abs(math.sin(index * 12.9898) * 43758.5453) % 1
		local seedB = math.abs(math.sin(index * 78.233) * 12345.678) % 1
		local angle = seed * math.pi * 2
		local speed = (0.05 + seedB * 0.07) * driftRate
		local warm = index % 3 == 0
		stars["star" .. index] = React.createElement("frame", {
			Size = clock:map(function(t)
				local r = (t * speed + seedB) % 1
				local px = 1 + math.floor(r * 3)
				return UDim2.fromOffset(px, px)
			end),
			Position = clock:map(function(t)
				local r = (t * speed + seedB) % 1
				local reach = 0.08 + r * r * 0.62
				return UDim2.fromScale(0.5 + math.cos(angle) * reach, centerY + math.sin(angle) * reach * 1.3)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if warm then Palette.mango else Palette.cream,
			BackgroundTransparency = React.joinBindings({ clock, veilHide }):map(function(values)
				local r = (values[1] * speed + seedB) % 1
				local fade = if r < 0.15 then 1 - r / 0.15 else (if r > 0.85 then (r - 0.85) / 0.15 else 0)
				return math.clamp(0.25 + fade * 0.75 + values[2], 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end

	local ticks = {}
	for index = 0, TICK_COUNT - 1 do
		local share = index / TICK_COUNT
		local radians = math.rad(-90 + share * 360)
		ticks["tick" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(if short then 3 else 4, if short then 9 else 13),
			Position = UDim2.fromScale(0.5 + math.cos(radians) * 0.47, 0.5 + math.sin(radians) * 0.47),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(radians) + 90,
			BackgroundColor3 = shownProgress:map(function(shown)
				if share < shown then
					return if shown - share < 1 / TICK_COUNT * 2 then Palette.cream else Palette.mango
				end
				return Palette.graphite
			end),
			BackgroundTransparency = React.joinBindings({ shownProgress, progressPulse, hidden }):map(function(values)
				local lit = share < values[1]
				local base = if lit then 0.05 + values[2] * 0.15 else 0.35
				return math.clamp(base + values[3], 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end

	local function orbit(name, scale, rate, sparks, color)
		local children = {
			ring = React.createElement("uistroke", {
				Color = color,
				Thickness = 1,
				Transparency = fadeFrom(0.62),
			}),
			corner = React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}
		for spark = 1, sparks do
			local radians = (spark - 1) / sparks * math.pi * 2
			children["spark" .. spark] = React.createElement("frame", {
				Size = UDim2.fromOffset(if short then 5 else 7, if short then 5 else 7),
				Position = UDim2.fromScale(0.5 + math.cos(radians) * 0.5, 0.5 + math.sin(radians) * 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = color,
				BackgroundTransparency = fadeFrom(0),
				BorderSizePixel = 0,
				ZIndex = 8,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}))
		end
		return React.createElement("frame", {
			Name = name,
			Size = UDim2.fromScale(scale, scale),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Rotation = clock:map(function(t)
				return (t * rate * orbitRate) % 360
			end),
			ZIndex = 6,
		}, children)
	end

	local core = React.createElement("frame", {
		Name = "BootCore",
		Size = UDim2.fromOffset(coreSize, coreSize),
		Position = UDim2.new(0.5, 0, centerY, coreY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = showing,
	}, React.createElement("uiscale", {
		Scale = React.joinBindings({ progressPulse, spinFade }):map(function(values)
			return 1 + values[1] * 0.012 + values[2] * 0.22
		end),
	}), React.createElement("frame", {
		Name = "Glow",
		Size = progressPulse:map(function(pulse)
			local s = 0.78 + pulse * 0.06
			return UDim2.fromScale(s, s)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = React.joinBindings({ progressPulse, hidden }):map(function(values)
			return math.clamp(0.8 - values[1] * 0.06 + values[2], 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.mango, Palette.ember),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
		Rotation = clock:map(function(t)
			return (t * 40 * orbitRate) % 360
		end),
	})), React.createElement("frame", {
		Name = "Ticks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 7,
	}, ticks), orbit("OuterOrbit", 0.8, 34, 3, Palette.mango), orbit("InnerOrbit", 0.62, -52, 2, Palette.cream), React.createElement("imagelabel", {
		Size = UDim2.fromScale(0.42, 0.42),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = BrandArt.COMPACT_MARK_ASSET,
		ImageTransparency = fadeFrom(0),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 9,
	}))

	-- on ready a shockwave leaves the core before the veil lifts
	local shockwave = React.createElement("frame", {
		Size = spinFade:map(function(amount)
			local s = coreSize * (1 + amount * 2.4)
			return UDim2.fromOffset(s, s)
		end),
		Position = UDim2.new(0.5, 0, centerY, coreY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Visible = spinFade:map(function(amount)
			return amount > 0.01 and amount < 0.99
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 3,
		Transparency = spinFade:map(function(amount)
			return math.clamp(0.1 + amount * 0.9, 0, 1)
		end),
	}))

	local percent = shownProgress:map(function(shown)
		return `{math.floor(math.clamp(shown, 0, 1) * 100 + 0.5)}%`
	end)

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = veilHide,
		BorderSizePixel = 0,
		Active = not exiting and not gone,
		ClipsDescendants = true,
		ZIndex = 420,
		Visible = veilFade:map(function(amount)
			return amount < 0.995
		end),
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.void),
			ColorSequenceKeypoint.new(0.5, Palette.night),
			ColorSequenceKeypoint.new(1, Palette.void),
		}),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, stars), core, shockwave, React.createElement("imagelabel", {
		Name = "BootWordmark",
		Size = UDim2.new(0.8, 0, 0, if short then 36 else 60),
		Position = UDim2.new(0.5, 0, centerY, wordY),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Image = BrandArt.WORDMARK_ASSET,
		ImageTransparency = fadeFrom(0),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
		Visible = showing,
	}), React.createElement("frame", {
		Size = UDim2.new(0.9, 0, 0, 20),
		Position = UDim2.new(0.5, 0, centerY, statusY),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Visible = showing,
	}, React.createElement(BootStageText, {
		text = status,
		clock = clock,
		leaving = hidden,
		reducedMotion = softMotion,
		textSize = 13,
		color = Palette.creamSoft,
		height = 20,
	})), React.createElement("textlabel", {
		Size = UDim2.new(0.9, 0, 0, 14),
		Position = UDim2.new(0.5, 0, centerY, statusY + 22),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = percent,
		TextColor3 = Palette.mango,
		TextTransparency = fadeFrom(0.2),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 6,
		Visible = showing,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0.86, 0, 0, 14),
		Position = UDim2.new(0.5, 0, 1, if short then -46 else -62),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Text = if stalled then "TAKING A WHILE" else "TIP",
		TextColor3 = Palette.mango,
		TextTransparency = fadeFrom(0.1),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 6,
		Visible = showing,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0.86, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, if short then -10 else -22),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Text = if stalled then "Still loading. Your save is safe." else tipText,
		TextColor3 = Palette.creamSoft,
		TextTransparency = fadeFrom(0.05),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		ZIndex = 6,
		Visible = showing,
	}), _version ~= nil and React.createElement("textlabel", {
		Size = UDim2.fromOffset(160, 14),
		Position = UDim2.new(1, -16, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = `v{_version}`,
		TextColor3 = Palette.line,
		TextTransparency = fadeFrom(0),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
	}))
end
return {
	bootChecklistReady = bootChecklistReady,
	bootProgress = bootProgress,
	BootScreen = BootScreen,
	BOOT_MODULE_TIMEOUT = BOOT_MODULE_TIMEOUT,
	BOOT_MOTION = BOOT_MOTION,
}
end

__defs["BootStageText"] = function()

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette

local ROLL = 0.42
local CHAR_W = 8.2
local MAX_CHARS = 42

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function easeOutCubic(t: number): number
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end

-- whole UTF-8 characters; byte slots split "…" and "·" into garbage glyphs
local function characters(text: string): { string }
	local list = {}
	for character in string.gmatch(text, utf8.charpattern) do
		table.insert(list, character)
	end
	return list
end

type Props = {
	text: string,
	clock: React.Binding<number>,
	leaving: React.Binding<number>?,
	reducedMotion: boolean?,
	textSize: number?,
	color: Color3?,
	height: number?,
}

local function BootStageText(props: Props)
	local text = props.text or ""
	local clock = props.clock
	local leaving = props.leaving
	local reducedMotion = props.reducedMotion == true
	local textSize = props.textSize or 12
	local color = props.color or Palette.muted
	local height = props.height or 20
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave

	local prevRef = React.useRef(text)
	local fromRef = React.useRef(text)
	local rollStartRef = React.useRef(0)
	local rollingRef = React.useRef(false)

	React.useEffect(function()
		if text == prevRef.current then
			return
		end
		fromRef.current = prevRef.current
		prevRef.current = text
		if reducedMotion then
			rollingRef.current = false
			return
		end
		rollingRef.current = true
		rollStartRef.current = os.clock()
	end, { text, reducedMotion } :: { any })

	local targetChars = characters(text)
	local fromChars = characters(fromRef.current)
	local glyphCount = math.min(MAX_CHARS, math.max(#targetChars, #fromChars, 8))
	local children = table.create(glyphCount)

	for i = 1, glyphCount do
		local targetChar = targetChars[i] or " "
		local fromChar = fromChars[i] or " "
		local x = (i - 0.5 - glyphCount * 0.5) * CHAR_W

		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(values)
			local fade = clamp01(values.leaving)
			local elapsed = os.clock() - rollStartRef.current
			local rolling = rollingRef.current and not reducedMotion
			local amount = if rolling then easeOutCubic(elapsed / ROLL) else 1
			if rolling and amount >= 1 then
				rollingRef.current = false
			end
			local y = if rolling and fromChar ~= targetChar then (1 - amount) * height else 0
			local ghostAlpha = if rolling and fromChar ~= targetChar then (1 - amount) else 0
			return {
				y = y,
				ghost = ghostAlpha,
				fade = fade,
			}
		end)

		children[i] = React.createElement("frame", {
			key = `boot-ch-{i}`,
			Size = UDim2.fromOffset(math.ceil(CHAR_W), height),
			Position = UDim2.new(0.5, x, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 4,
		}, React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = targetChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.08 + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 5,
		}), React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y - height)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = fromChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.15 + (1 - v.ghost) + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 4,
			Visible = motion:map(function(v)
				return v.ghost > 0.02 and v.fade < 0.96
			end),
		}))
	end

	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, children)
end

return {
	BootStageText = BootStageText,
}
end

__defs["LoadingDots"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.CoreKit)("theme").Palette
local DOTS = { 0, 1, 2, 3 }
local CYCLE = 0.86
local COUNT = 4
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function pulse(elapsed, index)
	local travel = ((elapsed / CYCLE) % 1) * COUNT
	local delta = math.abs(travel - index)
	local wrap = math.min(delta, COUNT - delta)
	local falloff = clamp01(1 - wrap)
	return falloff * falloff * (3 - 2 * falloff)
end
local function LoadingDots(_param)
	local clock = _param.clock
	local leaving = _param.leaving
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local width = if compact then 92 else 112
	local height = if compact then 22 else 26
	local gap = if compact then 18 else 22
	local size = if compact then 7 else 8
	local lift = if compact then 5 else 6
	local center = width / 2
	local restY = height * 0.55
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave
	local _newValue = table.create(#DOTS)
	local _callback = function(index)
		local x = center + (index - 1.5) * gap
		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(_param_1)
			local elapsed = _param_1.clock
			local exit = _param_1.leaving
			local fade = clamp01(exit)
			if reducedMotion or ready then
				return {
					y = restY,
					scale = 0.72,
					alpha = 0.45,
					mix = 0,
					fade = fade,
				}
			end
			local amount = pulse(elapsed, index)
			return {
				y = restY - amount * lift,
				scale = 0.62 + amount * 0.38,
				alpha = 0.28 + amount * 0.72,
				mix = amount,
				fade = fade,
			}
		end)
		return React.createElement("frame", {
			key = `load-dot-{index}`,
			Size = motion:map(function(value)
				return UDim2.fromOffset(size * value.scale, size * value.scale)
			end),
			Position = motion:map(function(value)
				return UDim2.fromOffset(x, value.y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = motion:map(function(value)
				return Palette.cream:Lerp(Palette.cyan, value.mix)
			end),
			BackgroundTransparency = motion:map(function(value)
				return clamp01(1 - value.alpha + value.fade)
			end),
			BorderSizePixel = 0,
			ZIndex = 527,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	for _k, _v in DOTS do
		_newValue[_k] = _callback(_v, _k - 1, DOTS)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 525,
	}, _newValue)
end
return {
	LoadingDots = LoadingDots,
}
end

__defs["SoftShutdownScreen"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local WORDMARK_ASSET = require(script.Parent.ArtKit)("Icon").WORDMARK_ASSET
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local LoadingDots = __load("LoadingDots").LoadingDots
local Palette = require(script.Parent.CoreKit)("theme").Palette
local function phaseName(phase)
	if phase == "Teleporting" then
		return "Teleporting"
	end
	if phase == "Waiting" then
		return "Waiting"
	end
	return "Saving"
end
local function titleFor(phase)
	if phase == "Teleporting" then
		return "JOINING NEW SERVER"
	end
	if phase == "Waiting" then
		return "RECONNECTING"
	end
	return "SAVING YOUR PROGRESS"
end
local function statusFor(phase)
	if phase == "Teleporting" then
		return "Save locked in. Moving you to the fresh server."
	end
	if phase == "Waiting" then
		return "Stay here. We'll move you when the new server is ready."
	end
	return "Don't leave yet. Saving your progress."
end
local function cueFor(phase)
	if phase == "Teleporting" then
		return "travel"
	end
	if phase == "Waiting" then
		return "systemAlert"
	end
	return "bootStart"
end
local function SoftShutdownScreen(_param)
	local centerY = if useViewport().height < 420 then 0.32 else 0.44
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local phase = phaseName(state.phase)
	local teleporting = phase == "Teleporting"
	local waiting = phase == "Waiting"
	local clock, setClock = React.useBinding(0)
	local spinClock = React.useRef(0)
	local barPulse, setBarPulse = React.useBinding(0.35)
	React.useEffect(function()
		spinClock.current = 0
		setClock(0)
		if reducedMotion then
			setBarPulse(if teleporting then 1 elseif waiting then 0.55 else 0.4)
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(dt)
			spinClock.current += dt
			setClock(spinClock.current)
			local wave = (math.sin(spinClock.current * 2.1) + 1) * 0.5
			if teleporting then
				setBarPulse(0.72 + wave * 0.28)
			elseif waiting then
				setBarPulse(0.4 + wave * 0.35)
			else
				setBarPulse(0.28 + wave * 0.32)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { phase, reducedMotion, setClock, teleporting, waiting })
	React.useEffect(function()
		Audio:setScene("shutdown")
		Audio:play(cueFor(phase))
		return function()
			return Audio:setScene("default")
		end
	end, { phase })
	local phaseAccent = if teleporting then Palette.mint elseif waiting then Palette.mango else Palette.cyan
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = true,
		Selectable = false,
		ZIndex = 900,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(112, 26),
		Position = UDim2.new(0.5, 0, centerY, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 903,
	}, React.createElement(LoadingDots, {
		clock = clock,
		ready = teleporting,
		reducedMotion = reducedMotion,
		compact = false,
	})), React.createElement("imagelabel", {
		Name = "ShutdownWordmark",
		Size = UDim2.new(0.8, 0, 0, 32),
		Position = UDim2.new(0.5, 0, centerY, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = WORDMARK_ASSET,
		ImageTransparency = 0.08,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Size = UDim2.new(0.9, 0, 0, 18),
		Position = UDim2.new(0.5, 0, centerY, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = titleFor(phase),
		TextColor3 = Color3.fromRGB(190, 174, 178),
		TextTransparency = 0.18,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(220, 4),
		Position = UDim2.new(0.5, 0, centerY, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(46, 36, 50),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 904,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = barPulse:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.08, 1), 0, 1, 0)
		end),
		BackgroundColor3 = phaseAccent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("textlabel", {
		Name = "ShutdownStatus",
		Size = UDim2.new(0.9, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = statusFor(phase),
		TextWrapped = true,
		TextColor3 = Palette.creamSoft,
		TextTransparency = 0.08,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 904,
	}), React.createElement("textlabel", {
		Name = "ShutdownMessage",
		Size = UDim2.new(0.9, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = state.message or "",
		Visible = state.message ~= nil and state.message ~= "",
		TextColor3 = Palette.muted,
		TextTransparency = 0.08,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		ZIndex = 904,
	}))
end
return {
	SoftShutdownScreen = SoftShutdownScreen,
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
