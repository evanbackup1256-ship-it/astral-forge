local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Icon = require(script.Parent.Icon).Icon
local _antilag = require(script.Parent.antilag)
local useAntilag = _antilag.useAntilag
local usePerformanceTelemetry = _antilag.usePerformanceTelemetry
local _motion = require(script.Parent.motion)
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local usePulse = _motion.usePulse
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local IconTile = _ui.IconTile
local LogoLockup = _ui.LogoLockup
local Text = _ui.Text
local useButtonChrome = _ui.useButtonChrome
local NumberSpinnerHost = require(script.Parent.NumberSpinnerHost).NumberSpinnerHost
local _theme = require(script.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local AppHelpers = require(script.Parent.appNav).AppHelpers
local BoostIconKind = require(script.Parent.boostIconKind)
local ReleaseClockMath = require(script.Parent.releaseClockMath)
local Audio = require(script.Parent.audio).Audio

local CHIP_TIPS = {
	FLUX = {
		title = "Flux",
		body = "Spendable cash from your vault. Bank production, then buy machines and research.",
	},
	DUST = {
		title = "Stardust",
		body = "Premium dust from rebirths and rewards. Spend it on Star Grid routes.",
	},
	CORES = {
		title = "Astral cores",
		body = "Permanent rebirth currency. Multiplies future runs and unlocks prestige tech.",
	},
}

local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}

local function StatChip(_param)
	local label = _param.label
	local value = _param.value
	local icon = _param.icon
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local velocity = _param.velocity
	if velocity == nil then
		velocity = 0
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reactiveFlash = _param.reactiveFlash
	if reactiveFlash == nil then
		reactiveFlash = true
	end
	local placeholder = _param.placeholder
	local showLabel = _param.showLabel
	if showLabel == nil then
		showLabel = true
	end
	local animateValue = _param.animateValue
	if animateValue == nil then
		animateValue = true
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — StatChip flash/springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local gains, setGains = React.useState(0)
	local previous = React.useRef(value)
	React.useEffect(function()
		if reactiveFlash and asFlux(value) > asFlux(previous.current) then
			setGains(function(current)
				return current + 1
			end)
		end
		previous.current = value
	end, { value, reactiveFlash })
	local flash = useFlash(gains, reducedMotion)
	local chipH = if tall then TapTarget else 54
	local iconSize = if tall then 32 else 28
	local valueSize = if tall then 15 else 14
	local tip = CHIP_TIPS[label]
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = flash:map(function(amount)
			return Palette.lineSoft:Lerp(accent, amount)
		end),
		Thickness = 1,
		Transparency = flash:map(function(amount)
			return 0.56 - amount * 0.5
		end),
	})
	local _exp_3 = React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, if tall then 10 else 9),
		PaddingRight = UDim.new(0, if tall then 12 else 11),
		PaddingTop = UDim.new(0, if tall then 6 else 8),
		PaddingBottom = UDim.new(0, if tall then 6 else 8),
	})
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = true,
	}, React.createElement(IconTile, {
		kind = icon,
		accent = accent,
		size = iconSize,
		radius = 99,
	}))
	local _exp_6 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 0),
	})
	local valueMaxW = if tall then 84 else 96
	local _exp_7 = showLabel and React.createElement("textlabel", {
		Size = UDim2.fromOffset(valueMaxW, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = ensureContrast(Palette.panel, accent),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
	})
	local _result
	if placeholder ~= nil or not animateValue or type(value) == "string" then
		local _attributes = {
			Size = UDim2.fromOffset(valueMaxW, 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
		local _condition = placeholder
		if _condition == nil then
			_condition = compactNumber(value)
		end
		_attributes.Text = _condition
		_attributes.TextColor3 = ensureContrast(Palette.panel, Palette.cream)
		_attributes.TextSize = valueSize
		_attributes.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
		_attributes.TextXAlignment = Enum.TextXAlignment.Left
		_attributes.TextYAlignment = Enum.TextYAlignment.Center
		_attributes.LayoutOrder = 2
		_result = React.createElement("textlabel", _attributes, React.createElement("uitextsizeconstraint", {
			MinTextSize = 10,
			MaxTextSize = valueSize,
		}))
	else
		_result = React.createElement(NumberSpinnerHost, {
			value = value,
			velocity = asFlux(velocity),
			reducedMotion = reducedMotion,
			duration = 0.55,
			size = valueSize,
			color = ensureContrast(Palette.panel, Palette.cream),
			autoWidth = false,
			sizeConstraint = UDim2.fromOffset(valueMaxW, 20),
			layoutOrder = 2,
			zIndex = 3,
		})
	end
	local chip = React.createElement("frame", {
		Size = UDim2.fromOffset(0, chipH),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, React.createElement("frame", {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, _exp_6, _exp_7, _result))
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, chipH + 2),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		ClipsDescendants = false,
	}, React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
	}), chip)
end
local function PerformanceStats(_param)
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reducedMotion = _param.reducedMotion
	local showFps = _param.showFps
	if showFps == nil then
		showFps = true
	end
	local showPing = _param.showPing
	if showPing == nil then
		showPing = true
	end
	local telemetry = usePerformanceTelemetry()
	local fps = math.max(0, math.floor(telemetry.fps + 0.5))
	local ping = if telemetry.pingMs ~= nil then math.max(0, math.floor(telemetry.pingMs + 0.5)) else nil
	local fpsAccent = if fps >= 54 then Palette.mint elseif fps >= 38 then Palette.mango else Palette.coral
	local pingAccent = if ping == nil then Palette.muted elseif ping <= 85 then Palette.mint elseif ping <= 165 then Palette.mango else Palette.coral
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	local _exp_1 = showFps and React.createElement(StatChip, {
		label = "FPS",
		value = fps,
		icon = "Timer",
		accent = fpsAccent,
		reducedMotion = reducedMotion,
		reactiveFlash = false,
		animateValue = false,
		placeholder = `{fps}`,
		tall = tall,
		layoutOrder = 1,
	})
	local _condition = showPing
	if _condition then
		local _attributes = {
			label = "PING",
		}
		local _condition_1 = ping
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_attributes.value = _condition_1
		_attributes.icon = "Wave"
		_attributes.accent = pingAccent
		_attributes.reducedMotion = reducedMotion
		_attributes.reactiveFlash = false
		_attributes.animateValue = false
		_attributes.placeholder = if ping == nil then "—" else `{ping}`
		_attributes.tall = tall
		_attributes.layoutOrder = 2
		_condition = React.createElement(StatChip, _attributes)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, if tall then TapTarget else 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _condition)
end
local boostIconKind = BoostIconKind.of
local function ActiveBoostIcon(_param)
	local boost = _param.boost
	local endsAt = _param.endsAt
	local now = _param.now
	local open = _param.open
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ActiveBoostIcon springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local remaining = now:map(function(timestamp)
		return clockText(math.max(0, endsAt - timestamp))
	end)
	local fraction = now:map(function(timestamp)
		return math.clamp((endsAt - timestamp) / math.max(1, boost.Duration), 0, 1)
	end)
	local chrome = useButtonChrome(open, reducedMotion, false, "boostOpen", true)
	local reveal = useEntrance(reducedMotion)
	local radius = if compact then 11 else 12
	local visualScale = React.joinBindings({
		press = chrome.touchScale,
		reveal = reveal,
	}):map(function(_param_1)
		local press = _param_1.press
		local amount = _param_1.reveal
		return press * (0.94 + math.clamp(amount, 0, 1) * 0.06)
	end)
	local visualPosition = React.joinBindings({
		offset = chrome.offsetY,
		reveal = reveal,
	}):map(function(_param_1)
		local offset = _param_1.offset
		local amount = _param_1.reveal
		return UDim2.new(0.5, 0, 0.5, math.round(offset + (1 - math.clamp(amount, 0, 1)) * 6))
	end)
	local hoverFill = chrome.hoverAmount:map(function(amount)
		return Palette.panelRaised:Lerp(darken(boost.Color, 0.72), math.clamp(amount, 0, 1) * 0.24)
	end)
	local runningLow, setRunningLow = React.useState(function()
		return endsAt - os.time() <= boost.Duration * 0.15
	end)
	React.useEffect(function()
		local threshold = boost.Duration * 0.15
		local remainingSeconds = endsAt - os.time()
		local shouldRunLow = remainingSeconds <= threshold
		setRunningLow(shouldRunLow)
		if shouldRunLow then
			return nil
		end
		local timer = task.delay(math.max(0, remainingSeconds - threshold), function()
			return setRunningLow(true)
		end)
		return function()
			return task.cancel(timer)
		end
	end, { boost.Duration, endsAt })
	local urgentStroke = useGlowStroke(runningLow, reducedMotion, 0.5, 0.15, 0.65, 2.4)
	local strokeTransparency = React.joinBindings({
		hover = chrome.hoverAmount,
		glow = urgentStroke,
	}):map(function(_param_1)
		local hover = _param_1.hover
		local glow = _param_1.glow
		return math.min(0.5 - hover * 0.22, glow)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = visualPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = visualScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundColor3 = hoverFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.5),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 3 else 4, if compact then 34 else 38),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = chrome.hoverAmount:map(function(amount)
			return 1 - amount * 0.1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		idle = true,
		zIndex = 2,
		radius = radius,
	}), React.createElement(IconTile, {
		kind = boostIconKind(boost.Id),
		accent = boost.Color,
		size = if compact then 34 else 40,
		radius = if compact then 9 else 10,
		position = if compact then UDim2.new(0.5, -17, 0, 4) else UDim2.fromOffset(9, 8),
		spin = chrome.hovered and not reducedMotion,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
		zIndex = 3,
	}), if compact then React.createElement(Text, {
		value = remaining,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 5, 1, -19),
		sizeConstraint = UDim2.new(1, -10, 0, 13),
		zIndex = 4,
	}) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "ACTIVE BOOST",
		size = 9,
		color = boost.Color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, -128, 0, 13),
		zIndex = 4,
	}), React.createElement(Text, {
		value = boost.Name,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(60, 20),
		sizeConstraint = UDim2.new(1, -128, 0, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = remaining,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 10,
		position = UDim2.new(1, -64, 0, 18),
		sizeConstraint = UDim2.fromOffset(54, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = AppHelpers:boostEffectText(boost),
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 38),
		sizeConstraint = UDim2.new(1, -72, 0, 13),
		zIndex = 4,
	})), React.createElement("frame", {
		Size = if compact then UDim2.new(1, -12, 0, 3) else UDim2.new(1, -69, 0, 3),
		Position = if compact then UDim2.new(0, 6, 1, -6) else UDim2.new(0, 60, 1, -7),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fraction:map(function(amount)
			return UDim2.new(amount, 0, 1, 0)
		end),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = boost.Color,
		Thickness = 1,
		Transparency = strokeTransparency,
	})))))
end
local function TopbarReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local width = _param.width
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TopbarReleaseCountdown pulses drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local Workspace = game:GetService("Workspace")
	local function syncedNow()
		local ok, value = pcall(function()
			return Workspace:GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return math.floor(value)
		end
		return os.time()
	end
	local now, setNow = React.useState(syncedNow())
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if alive then
					setNow(syncedNow())
				end
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	local remaining = ReleaseClockMath.Remaining(releaseAt, now)
	local live = ReleaseClockMath.IsLive(releaseAt, now)
	local slam, setSlam = React.useState(0)
	local wasLive = React.useRef(live)
	React.useEffect(function()
		if live and not wasLive.current then
			wasLive.current = true
			setSlam(function(n)
				return n + 1
			end)
			if not reducedMotion then
				Audio:play("prestige")
				Audio:play("bootFinaleBang")
			end
		end
		if not live then
			wasLive.current = false
		end
	end, { live, reducedMotion })
	local pulse = usePulse(live and not reducedMotion, 2.4)
	local flash = useFlash(slam, reducedMotion, 1.05)
	local days = math.floor(remaining / 86400)
	local hours = math.floor(remaining / 3600) % 24
	local minutes = math.floor(remaining / 60) % 60
	local seconds = remaining % 60
	local pair = function(value)
		return if value < 10 then `0{value}` else tostring(value)
	end
	local values = if live then { {
		value = "LIVE",
		unit = "NOW",
		color = Palette.mint,
	} } else { {
		value = tostring(days),
		unit = "DAYS",
		color = Palette.cyan,
	}, {
		value = pair(hours),
		unit = "HRS",
		color = Palette.violet,
	}, {
		value = pair(minutes),
		unit = "MIN",
		color = Palette.pink,
	}, {
		value = pair(seconds),
		unit = "SEC",
		color = Palette.mango,
	} }
	local labelW = if live then (if width >= 360 then 96 else 82) elseif width >= 360 then 104 else 88
	local strokeColor = if live then Palette.mint else Palette.cyan
	local strokeTransparency = if live then pulse:map(function(amount)
		return 0.08 + (1 - amount) * 0.38
	end) else 0.5
	local fillWash = if live then pulse:map(function(amount)
		return 0.82 - amount * 0.28
	end) else 1
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = strokeColor,
		Thickness = if live then 1.6 else 1,
		Transparency = strokeTransparency,
	})
	local _exp_2 = live and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mint,
		BackgroundTransparency = fillWash,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}))
	local _condition = nil
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(9, 11),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Icon, {
		kind = "Calendar",
		color = Palette.cream,
		accent = if live then Palette.mint else Palette.cyan,
		size = 26,
		spin = live and not reducedMotion,
	}))
	local _exp_4 = React.createElement(Text, {
		value = if live then "LAUNCH" else "NEXT",
		size = 10,
		color = if live then Palette.mint else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(40, 7),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 14),
		zIndex = 3,
	})
	local _exp_5 = React.createElement(Text, {
		value = if live then "LIVE" else "UPDATE",
		size = 10,
		minSize = 8,
		color = if live then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(40, 23),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 15),
		zIndex = 3,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -16),
		Position = UDim2.fromOffset(labelW, 8),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.36,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	local _exp_7 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#values)
	local _callback = function(entry, index)
		return React.createElement("frame", {
			key = entry.unit,
			Size = UDim2.new(1 / #values, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, index > 0 and React.createElement("frame", {
			Size = UDim2.fromOffset(1, 22),
			Position = UDim2.new(0, 0, 0.5, -11),
			BackgroundColor3 = Palette.lineSoft,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -4, 0, 21),
			Position = UDim2.fromOffset(2, 3),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.value,
			TextColor3 = entry.color,
			TextSize = if live then 15 else 14,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 4,
		}), React.createElement(Text, {
			value = entry.unit,
			size = 10,
			minSize = 9,
			color = if live then Palette.mint else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(2, 25),
			sizeConstraint = UDim2.new(1, -4, 0, 11),
			zIndex = 3,
		}))
	end
	for _k, _v in values do
		_newValue[_k] = _callback(_v, _k - 1, values)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _condition, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.new(1, -(labelW + 7), 1, -6),
		Position = UDim2.fromOffset(labelW + 5, 3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _exp_7, _newValue))
end
local function TopBar(_param)
	local state = _param.state
	local page = _param.page
	local railOpen = _param.railOpen
	local toggleRail = _param.toggleRail
	local hideUI = _param.hideUI
	local tight = _param.tight
	local width = _param.width
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local barHeightMotion = _param.barHeightMotion
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local releaseAt = _param.releaseAt
	local visit = _param.visit
	local openPlayerlist = _param.openPlayerlist
	local openFeedback = _param.openFeedback
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TopBar chips/pills drop springs on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local accent = AppHelpers:pageAccent(page)
	local shortRow = barHeight <= 54 and width < 980
	local micro = barHeight <= 54 and width < 620
	local stacked = barHeight > Layout.topbarHeight
	local chipWidthEstimate = if stacked then 148 elseif micro then 150 else 164
	local logoCompact = tight or stacked or barHeight <= Layout.topbarHeight
	local logoWidth = if micro then 40 elseif stacked then 148 elseif shortRow then 146 elseif logoCompact then 172 else 228
	local pageTitleW = 0
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local visitPill = if not stacked and visit ~= nil then {
		label = `AT {string.upper(visit.DisplayName)}`,
		accent = Palette.blue,
	} elseif not stacked and visitorsHere > 0 then {
		label = if visitorsHere == 1 then "1 VISITOR" else `{visitorsHere} VISITORS`,
		accent = Palette.mango,
	} else nil
	local allChips = {}
	if AppHelpers:featureUnlocked(state, "Rebirth") then
		local _arg0 = {
			label = "CORES",
			value = state.Cores,
			icon = "Core",
			accent = Palette.violet,
		}
		table.insert(allChips, _arg0)
	end
	if AppHelpers:featureUnlocked(state, "StarGrid") then
		local _arg0 = {
			label = "DUST",
			value = state.Stardust,
			icon = "Dust",
			accent = Palette.mango,
		}
		table.insert(allChips, _arg0)
	end
	local _arg0 = {
		label = "FLUX",
		value = state.Cash,
		icon = "Flux",
		accent = Palette.cyan,
	}
	table.insert(allChips, _arg0)
	local visitPillWidth = if visitPill ~= nil then (if tight then 124 else 156) else 0
	-- Was hardcoded to 0 (dead space between the logo and the resource chips, with the
	-- countdown component fully built but never shown). Room only exists for it on a real
	-- single-row desktop bar -- stacked/short/micro layouts already spend every pixel on the
	-- logo, chips, and controls.
	local countdownW = if not stacked and not shortRow and not micro and width >= 900 then 200 else 0
	local _condition_1 = state.Settings.ShowFps
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local _exp = (if _condition_1 >= 0.5 then 1 else 0)
	local _condition_2 = state.Settings.ShowPing
	if _condition_2 == nil then
		_condition_2 = 1
	end
	local performanceCount = _exp + (if _condition_2 >= 0.5 then 1 else 0)
	local fullPerformanceW = if micro or performanceCount == 0 then 0 elseif performanceCount == 1 then (if stacked then 100 else 90) elseif stacked then 192 else 172
	local performanceGap = 10
	local playerControlGap = if shortRow then 6 else 8
	local playerControlW = if micro or stacked or width < 980 then SHELL_CHROME.topbarControl else 110
	local feedbackControlGap = if shortRow then 6 else 8
	local showFeedbackControl = not (stacked and width < 360)
	local feedbackControlW = if not showFeedbackControl then 0 elseif micro or stacked or width < 1480 then SHELL_CHROME.topbarControl else 116
	local controlsW = SHELL_CHROME.topbarControl + playerControlGap + playerControlW + (if showFeedbackControl then feedbackControlGap + feedbackControlW else 0)
	local fixedSingleRow = edgePad * 2 + (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) + controlsW + 12 + (if visitPillWidth > 0 then visitPillWidth + 6 else 0) + (if countdownW > 0 then countdownW + 10 else 0)
	local minimumResourceRoom = if #allChips > 0 then chipWidthEstimate + 6 else 0
	local performanceW = if not stacked and fullPerformanceW > 0 and width - fixedSingleRow - fullPerformanceW - performanceGap < minimumResourceRoom then 0 else fullPerformanceW
	local spare = if stacked then width - edgePad * 2 - 24 - performanceW - performanceGap else width - edgePad * 2 - (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) - (if pageTitleW > 0 then pageTitleW + 10 else 0) - controlsW - 12 - (if visitPillWidth > 0 then visitPillWidth + 6 else 0) - performanceW - performanceGap - (if countdownW > 0 then countdownW + 10 else 0)
	local fitCount = if stacked then math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 1, math.min(2, #allChips)) else math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 0, #allChips)
	local chips = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(chip, index)
		if index >= #allChips - fitCount then
			local _chip = chip
			table.insert(chips, _chip)
		end
	end
	for _k, _v in allChips do
		_callback(_v, _k - 1, allChips)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local controlsRight = edgePad + 4
	local hasRightCluster = not stacked and (#chips > 0 or visitPill ~= nil or performanceW > 0)
	local row1H = if stacked then 62 else barHeight
	local logoH = if stacked then 52 else math.min(56, math.max(40, barHeight - 16))
	local logoY = if stacked then 6 else math.max(4, math.floor((row1H - logoH) / 2))
	local chipRowH = if stacked then TapTarget else 50
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_2 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	})
	local _exp_3 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.52,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromOffset(72, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.new(1, -36, 0, 1),
		Position = UDim2.fromOffset(18, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.fromOffset(12, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = if railOpen then "Close" else "Menu",
		onClick = toggleRail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.fromOffset(logoWidth, logoH),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap, logoY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(LogoLockup, {
		compact = logoCompact,
		micro = micro,
		accent = accent,
		reducedMotion = reducedMotion,
	}))
	local _exp_8 = countdownW > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(countdownW, 48),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14, math.floor((row1H - 48) / 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 22,
	}, React.createElement(TopbarReleaseCountdown, {
		releaseAt = releaseAt,
		width = countdownW,
		reducedMotion = reducedMotion,
	}))
	local _condition_3 = hasRightCluster
	if _condition_3 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		})
		local _condition_4 = performanceW > 0
		if _condition_4 then
			local _attributes = {
				tall = false,
				reducedMotion = reducedMotion,
			}
			local _condition_5 = state.Settings.ShowFps
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showFps = _condition_5 >= 0.5
			local _condition_6 = state.Settings.ShowPing
			if _condition_6 == nil then
				_condition_6 = 1
			end
			_attributes.showPing = _condition_6 >= 0.5
			_condition_4 = React.createElement(PerformanceStats, _attributes)
		end
		local _exp_10 = visitPill ~= nil and React.createElement("frame", {
			Size = UDim2.fromOffset(visitPillWidth, TapTarget),
			LayoutOrder = 10,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = visitPill.label,
			icon = "Crew",
			onClick = openPlayerlist,
			color = Palette.panelSoft,
			textColor = visitPill.accent,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		}))
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			local _attributes = {
				key = chip.label,
				layoutOrder = 20 + index,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_3 = React.createElement("frame", {
			Size = UDim2.fromOffset(0, chipRowH + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(controlsW + controlsRight + 12), 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
		}, _exp_9, _condition_4, _exp_10, _newValue)
	end
	local _condition_4 = stacked
	if _condition_4 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			local _attributes = {
				key = chip.label,
				layoutOrder = index + 1,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
				tall = true,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_4 = React.createElement("frame", {
			Size = UDim2.new(1, -(24 + (if performanceW > 0 then performanceW + performanceGap else 0)), 0, TapTarget + 6),
			Position = UDim2.fromOffset(12, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
		}, _exp_9, _newValue)
	end
	local _condition_5 = stacked and performanceW > 0
	if _condition_5 then
		local _attributes = {
			tall = true,
			reducedMotion = reducedMotion,
		}
		local _condition_6 = state.Settings.ShowFps
		if _condition_6 == nil then
			_condition_6 = 1
		end
		_attributes.showFps = _condition_6 >= 0.5
		local _condition_7 = state.Settings.ShowPing
		if _condition_7 == nil then
			_condition_7 = 1
		end
		_attributes.showPing = _condition_7 >= 0.5
		_condition_5 = React.createElement("frame", {
			Size = UDim2.fromOffset(performanceW, TapTarget),
			Position = UDim2.new(1, -(performanceW + 12), 0, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 23,
			ClipsDescendants = true,
		}, React.createElement(PerformanceStats, _attributes))
	end
	return React.createElement("frame", {
		Size = if barHeightMotion ~= nil then barHeightMotion:map(function(height)
			return UDim2.new(1, -edgePad * 2, 0, height)
		end) else UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _exp_8, _condition_3, _condition_4, _condition_5, React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = "Hide",
		onClick = hideUI,
		color = Palette.panelSoft,
		textColor = accent,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if playerControlW > SHELL_CHROME.topbarControl then "PLAYERS" else "",
		icon = "Pilot",
		onClick = openPlayerlist,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), showFeedbackControl and React.createElement("frame", {
		Size = UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW + feedbackControlGap + feedbackControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if feedbackControlW > SHELL_CHROME.topbarControl then "FEEDBACK" else "",
		icon = "Chat",
		onClick = openFeedback,
		color = Palette.panelSoft,
		textColor = Palette.mint,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
end

return {
	TopBar = TopBar,
	ActiveBoostIcon = ActiveBoostIcon,
	StatChip = StatChip,
	PerformanceStats = PerformanceStats,
	TopbarReleaseCountdown = TopbarReleaseCountdown,
}
