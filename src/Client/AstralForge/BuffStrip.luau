--!nonstrict
-- The buff strip: every multiplier working for you right now, as a row of small icons with the value
-- underneath (boost and surge timers count down). Chips pop in when a buff starts, bob gently out of
-- step with each other, and the timed ones pulse.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local theme = require(script.Parent.CoreKit)("theme")
local format = require(script.Parent.CoreKit)("format")
local motion = require(script.Parent.MotionKit)("motion")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local P = theme.Palette
local h = React.createElement

local BuffStrip = {}

local CHIP_W = 58

local function clockText(seconds)
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh%02d", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- what is boosting the player right now, most urgent first
function BuffStrip.list(state, config, now)
	local list = {}
	if type(state) ~= "table" then
		return list
	end
	local boost = state.ActiveBoost
	if type(boost) == "table" and type(boost.Id) == "string" and boost.Id ~= "" and (tonumber(boost.EndsAt) or 0) > now then
		local def = config and config.Boosts and config.Boosts[boost.Id]
		local mult = def and (tonumber(def.Multiplier) or tonumber(def.ProductionMultiplier))
		table.insert(list, { key = "boost", icon = "Boost", value = if mult then `x{mult}` else "Boost", endsAt = boost.EndsAt, duration = def and def.Duration, color = P.pink, name = def and def.Name or "Boost" })
	end
	local surge = state.FluxSurge
	if type(surge) == "table" and surge.Active == true then
		table.insert(list, { key = "surge", icon = "Flux", value = `x{surge.Multiplier or 2}`, endsAt = surge.EndsAt, duration = surge.DurationSeconds, color = P.cyan, name = "Flux surge" })
	end
	local event = state.ServerEvent
	if type(event) == "table" and event.Phase == "Live" and type(event.Id) == "string" then
		table.insert(list, { key = "event", icon = "Calendar", value = "Live", endsAt = event.PhaseEndsAt, color = P.mango, name = (string.gsub(event.Id, "(%l)(%u)", "%1 %2")) })
	end
	local ascension = state.Ascension
	if type(ascension) == "table" and (tonumber(ascension.Rank) or 0) > 0 then
		table.insert(list, { key = "ascension", icon = "Rebirth", value = `x{format.compactNumber(ascension.Production or 1)}`, color = P.mango, name = "Ascension" })
	end
	local continuum = state.Continuum
	if type(continuum) == "table" and format.asFlux(continuum.ProductionMultiplier or 1) > 1 then
		table.insert(list, { key = "continuum", icon = "Continuum", value = `x{format.compactNumber(continuum.ProductionMultiplier)}`, color = P.cyan, name = "Continuum" })
	end
	if format.asFlux(state.PermanentMultiplier or 1) > 1 then
		table.insert(list, { key = "rebirth", icon = "Core", value = `x{format.compactNumber(state.PermanentMultiplier)}`, color = P.violet, name = "Rebirths" })
	end
	local guild = state.GuildBonuses
	if type(guild) == "table" and (tonumber(guild.Production) or 0) > 0 then
		table.insert(list, { key = "guild", icon = "Crew", value = `+{math.floor((tonumber(guild.Production) or 0) * 100 + 0.5)}%`, color = P.mint, name = "Guild" })
	end
	return list
end

local function Chip(props)
	local buff = props.buff
	local appear = motion.useFlipperSpring(1, props.reducedMotion, 300, 16)
	local timed = buff.endsAt ~= nil
	local pulse = motion.usePulse(timed, 2.2)
	return h("frame", {
		Size = UDim2.fromOffset(CHIP_W, 52),
		LayoutOrder = props.order,
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, h("uiscale", {
		Scale = appear:map(function(v) return math.max(0.01, v) end),
	}), h("frame", {
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = theme.darken(buff.color, 0.62),
		BorderSizePixel = 0,
		ZIndex = 21,
		Position = props.clock:map(function(t)
			return UDim2.new(0.5, 0, 0, 1 + math.sin(t * 2.2 + props.order * 1.3) * 2)
		end),
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
		Color = buff.color,
		Thickness = 1.5,
		Transparency = if timed then pulse:map(function(v) return 0.05 + v * 0.45 end) else 0.35,
	}), h(Icon, {
		kind = buff.icon,
		color = P.cream,
		accent = buff.color,
		size = 22,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), h("textlabel", {
		Size = UDim2.new(1, 8, 0, 14),
		Position = UDim2.new(0.5, 0, 0, 37),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = if timed then props.clock:map(function()
			return clockText((tonumber(buff.endsAt) or 0) - workspace:GetServerTimeNow())
		end) else buff.value,
		TextColor3 = P.cream,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 22,
	}, h("uistroke", { Color = P.void, Thickness = 1.5, Transparency = 0.2 }), h("uitextsizeconstraint", { MaxTextSize = 12, MinTextSize = 9 })),
		timed and h("textlabel", {
		-- the multiplier sits on the icon's corner when the label shows the timer
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(0.5, 14, 0, -4),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = buff.color,
		BorderSizePixel = 0,
		Text = buff.value,
		TextColor3 = P.ink,
		TextSize = 10,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 24,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uitextsizeconstraint", { MaxTextSize = 10, MinTextSize = 7 })))
end

-- `width` caps how many chips show; the rest are dropped from the end
function BuffStrip.Strip(props)
	local clock = motion.useClock(true, 1, 3600, true)
	local hostRef = React.useRef(nil)
	local width, setWidth = React.useState(props.width or 0)
	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local function measure()
			setWidth(host.AbsoluteSize.X)
		end
		measure()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			connection:Disconnect()
		end
	end, {})
	local now = workspace:GetServerTimeNow()
	local buffs = BuffStrip.list(props.state, props.config, now)
	local room = math.max(0, math.floor((width + 4) / (CHIP_W + 4)))
	local children = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = props.align or Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, buff in buffs do
		if index > room then
			break
		end
		children[buff.key] = h(Chip, { buff = buff, order = index, clock = clock, reducedMotion = props.reducedMotion })
	end
	return h("frame", {
		Name = "BuffStrip",
		ref = hostRef,
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, children)
end

-- The island: one black capsule that morphs. Compact, it shows each buff as an icon and its value.
-- Hover (or tap) and it grows into a list with names and live timers. When something happens
-- (a rebirth, a boost starting, an unlock, a rare drop) it widens into an announcement, then
-- settles back. Size, corners and contents all spring between shapes.
local Juice = require(script.Parent.JuiceFx)

local COMPACT_H = 44
local EVENT_H = 72
local ROW_H = 36

local function easeOutBack(x)
	local c1, c3 = 1.5, 2.5
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- contents fade and rise in each time the island changes shape
local function useArrive(key)
	local amount, setAmount = React.useBinding(0)
	React.useEffect(function()
		setAmount(0)
		local start = os.clock() + 0.06
		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / 0.32, 0, 1)
			setAmount(t)
			if t >= 1 then
				connection:Disconnect()
			end
		end)
		return function()
			if connection.Connected then
				connection:Disconnect()
			end
		end
	end, { key })
	return amount
end

local telemetryHook = require(script.Parent.MotionKit)("antilag").usePerformanceTelemetry

local PERF_W = 100
local CURRENCY_W = 104
local BUFF_W = 54
local SEP_W = 13
local VAULT_W = 92

local function fpsColor(fps)
	return if fps >= 54 then P.mint elseif fps >= 38 then P.mango else P.coral
end
local function pingColor(ping)
	return if ping == nil then P.muted elseif ping <= 85 then P.mint elseif ping <= 165 then P.mango else P.coral
end

-- frame rate and ping: a status dot and two short numbers; only this re-renders on each sample
local function PerfSegment(props)
	local telemetry = telemetryHook()
	local fps = math.max(0, math.floor(telemetry.fps + 0.5))
	local ping = if telemetry.pingMs ~= nil then math.max(0, math.floor(telemetry.pingMs + 0.5)) else nil
	local parts = {}
	if props.showFps then table.insert(parts, `{fps} fps`) end
	if props.showPing then table.insert(parts, if ping then `{ping} ms` else "-- ms") end
	local worst = if props.showFps and fps < 38 then fpsColor(fps) elseif props.showPing then pingColor(ping) else fpsColor(fps)
	return h("frame", {
		Size = UDim2.fromOffset(PERF_W, COMPACT_H),
		LayoutOrder = props.order,
		BackgroundTransparency = 1,
	}, h("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = worst,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = worst,
		Thickness = 3,
		Transparency = props.clock:map(function(t) return 0.55 + (math.sin(t * 3) + 1) * 0.2 end),
	})), h("textlabel", {
		Size = UDim2.new(1, -18, 1, 0),
		Position = UDim2.fromOffset(18, 0),
		BackgroundTransparency = 1,
		Text = table.concat(parts, " · "),
		TextColor3 = P.creamSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	}, h("uitextsizeconstraint", { MaxTextSize = 12, MinTextSize = 9 })))
end

-- one currency: flying coins land here and the value hops when they do
local function CurrencySegment(props)
	local currency = props.currency
	local ref, bump = Juice.useTarget(currency.target)
	local flash = motion.useFlash(format.asFlux(currency.value), props.reducedMotion, 0.45)
	return h("frame", {
		ref = ref,
		Size = UDim2.fromOffset(CURRENCY_W, COMPACT_H),
		LayoutOrder = props.order,
		BackgroundTransparency = 1,
	}, h("uiscale", {
		Scale = bump:map(function(b) return 1 + math.sin(b * math.pi) * 0.16 end),
	}), h("frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.darken(currency.color, 0.6),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = currency.color,
		Thickness = 1,
		Transparency = flash:map(function(v) return 0.55 - v * 0.5 end),
	}), h(Icon, {
		kind = currency.icon,
		color = P.cream,
		accent = currency.color,
		size = 16,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), h("textlabel", {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(30, 0),
		BackgroundTransparency = 1,
		Text = format.compactNumber(currency.value),
		TextColor3 = flash:map(function(v) return P.cream:Lerp(theme.lighten(currency.color, 0.4), v) end),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	}, h("uitextsizeconstraint", { MaxTextSize = 15, MinTextSize = 10 })))
end

local function Separator(order)
	return h("frame", {
		Size = UDim2.fromOffset(1, 20),
		LayoutOrder = order,
		BackgroundColor3 = P.line,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	})
end

-- what fits in the compact capsule: performance and currencies first, then as many buffs as fit
local function planCompact(props, buffs)
	local currencies = props.currencies or {}
	local perfOn = props.perf ~= nil and (props.perf.showFps or props.perf.showPing)
	local width = 28 + #currencies * (CURRENCY_W + 10)
	local showPerf = perfOn and width + PERF_W + SEP_W <= (props.maxWidth or 9999)
	if showPerf then
		width += PERF_W + SEP_W
	end
	local shownBuffs = {}
	local room = (props.maxWidth or 9999) - width - (if #buffs > 0 then SEP_W else 0) - (if props.vaultFull then SEP_W + VAULT_W + 10 else 0)
	for _, buff in buffs do
		if room >= BUFF_W + 8 then
			table.insert(shownBuffs, buff)
			room -= BUFF_W + 8
		end
	end
	if #shownBuffs > 0 then
		width += SEP_W + #shownBuffs * (BUFF_W + 8)
	end
	if props.vaultFull then
		width += SEP_W + VAULT_W + 10
	end
	if #currencies == 0 and not showPerf then
		width = 24 + #shownBuffs * (BUFF_W + 8)
	end
	return { width = width, perf = showPerf, buffs = shownBuffs }
end

local function CompactRow(props)
	local arrive = useArrive("compact")
	local plan = props.plan
	local items = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	if plan.perf then
		items.perf = h(PerfSegment, { order = nextOrder(), clock = props.clock, showFps = props.perf.showFps, showPing = props.perf.showPing })
		items.sep1 = Separator(nextOrder())
	end
	for _, currency in props.currencies or {} do
		items["c" .. currency.target] = h(CurrencySegment, { order = nextOrder(), currency = currency, reducedMotion = props.reducedMotion })
	end
	if props.vaultFull then
		items.sepVault = Separator(nextOrder())
		items.vault = h("frame", {
			Size = UDim2.fromOffset(VAULT_W, COMPACT_H),
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
		}, h("frame", {
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = theme.darken(P.mango, 0.55),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uiscale", {
			Scale = props.clock:map(function(t) return 1 + math.max(0, math.sin(t * 5)) * 0.06 end),
		}), h("textlabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "VAULT FULL",
			TextColor3 = P.mango,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		})))
	end
	if #plan.buffs > 0 then
		items.sep2 = Separator(nextOrder())
	end
	for index, buff in plan.buffs do
		items[buff.key] = h("frame", {
			Size = UDim2.fromOffset(BUFF_W, COMPACT_H),
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
		}, h(Icon, {
			kind = buff.icon,
			color = P.cream,
			accent = buff.color,
			size = 18,
			anchorPoint = Vector2.new(0, 0.5),
			position = props.clock:map(function(t)
				return UDim2.new(0, 0, 0.5, math.sin(t * 2.4 + index * 1.4) * 1.5)
			end),
			spin = false,
		}), h("textlabel", {
			Size = UDim2.new(1, -22, 1, 0),
			Position = UDim2.fromOffset(22, 0),
			BackgroundTransparency = 1,
			Text = buff.value,
			TextColor3 = theme.lighten(buff.color, 0.35),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		}, h("uitextsizeconstraint", { MaxTextSize = 12, MinTextSize = 8 })), buff.endsAt and buff.duration and h("frame", {
			-- time left on a running buff
			Size = UDim2.new(1, -4, 0, 2),
			Position = UDim2.new(0, 0, 1, -7),
			BackgroundColor3 = P.line,
			BorderSizePixel = 0,
		}, h("frame", {
			Size = props.clock:map(function()
				local left = (tonumber(buff.endsAt) or 0) - workspace:GetServerTimeNow()
				return UDim2.fromScale(math.clamp(left / math.max(1, buff.duration), 0, 1), 1)
			end),
			BackgroundColor3 = buff.color,
			BorderSizePixel = 0,
		})))
	end
	return h("frame", {
		Size = UDim2.new(1, 0, 0, COMPACT_H),
		BackgroundTransparency = 1,
		Position = arrive:map(function(t) return UDim2.fromOffset(0, (1 - t) * 6) end),
		ZIndex = 62,
	}, items)
end

local SECTION_HEAD = 24

local function sectionHeight(rows)
	return SECTION_HEAD + rows * ROW_H + 6
end

local function expandedHeight(props, buffs)
	local h_ = 10 + COMPACT_H
	if props.currencies and #props.currencies > 0 then h_ += sectionHeight(#props.currencies) end
	if props.perf and (props.perf.showFps or props.perf.showPing) then h_ += sectionHeight(1) end
	if #buffs > 0 then h_ += sectionHeight(#buffs) end
	return h_ + 8
end

local function Row(order, color, icon, name, value, valueColor, extra, onClick)
	return h(if onClick then "textbutton" else "frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Text = if onClick then "" else nil,
		AutoButtonColor = if onClick then false else nil,
		Event = if onClick then { Activated = onClick } else nil,
	}, h("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.darken(color, 0.6),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 8) }), h(Icon, {
		kind = icon,
		color = P.cream,
		accent = color,
		size = 18,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), h("textlabel", {
		Size = UDim2.new(1, -170, 0, 18),
		Position = UDim2.new(0, 36, 0, if extra then 2 else 9),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = P.cream,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	}), h("textlabel", {
		Size = UDim2.fromOffset(130, 18),
		Position = UDim2.new(1, -130, 0, if extra then 2 else 9),
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = valueColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	}, h("uitextsizeconstraint", { MaxTextSize = 13, MinTextSize = 9 })), extra)
end

local function SectionTitle(order, text)
	return h("textlabel", {
		Size = UDim2.new(1, 0, 0, SECTION_HEAD),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = P.muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	})
end

local function PerfRows(props)
	local telemetry = telemetryHook()
	local fps = math.max(0, math.floor(telemetry.fps + 0.5))
	local ping = if telemetry.pingMs ~= nil then math.max(0, math.floor(telemetry.pingMs + 0.5)) else nil
	local label = {}
	if props.showFps then table.insert(label, `{fps} fps`) end
	if props.showPing then table.insert(label, if ping then `{ping} ms ping` else "measuring ping") end
	local smooth = fps >= 54 and (ping == nil or ping <= 85)
	return Row(props.order, fpsColor(fps), "Timer", if smooth then "Running smoothly" else "Running a little slow", table.concat(label, "  ·  "), if smooth then P.mint else P.mango)
end

local function ExpandedList(props)
	local arrive = useArrive("expanded")
	local rows = {
		layout = h("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad = h("uipadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 2) }),
	}
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	if props.currencies and #props.currencies > 0 then
		rows.balanceTitle = SectionTitle(nextOrder(), "YOUR BALANCE")
		for _, currency in props.currencies do
			local rate = if currency.target == "FLUX" and props.rate ~= nil then `  +{format.compactNumber(props.rate)}/s` else ""
			local destination = if currency.target == "FLUX" then "Workshop" elseif currency.target == "DUST" then "StarGrid" else "Overview"
			rows["c" .. currency.target] = Row(nextOrder(), currency.color, currency.icon, currency.name or currency.target, format.compactNumber(currency.value) .. rate, theme.lighten(currency.color, 0.3), nil,
				if props.navigate then function() props.navigate(destination) end else nil)
		end
	end
	if props.perf and (props.perf.showFps or props.perf.showPing) then
		rows.perfTitle = SectionTitle(nextOrder(), "CONNECTION")
		rows.perf = h(PerfRows, { order = nextOrder(), showFps = props.perf.showFps, showPing = props.perf.showPing })
	end
	if #props.buffs > 0 then
		rows.buffTitle = SectionTitle(nextOrder(), "BOOSTING YOU NOW")
		for _, buff in props.buffs do
			local timed = buff.endsAt ~= nil
			rows[buff.key] = Row(nextOrder(), buff.color, buff.icon, buff.name,
				if timed then props.clock:map(function()
					return `{buff.value}  ·  {clockText((tonumber(buff.endsAt) or 0) - workspace:GetServerTimeNow())}`
				end) else buff.value,
				theme.lighten(buff.color, 0.35),
				timed and buff.duration and h("frame", {
					Size = UDim2.new(1, -36, 0, 3),
					Position = UDim2.new(0, 36, 0, 25),
					BackgroundColor3 = P.line,
					BorderSizePixel = 0,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("frame", {
					Size = props.clock:map(function()
						local left = (tonumber(buff.endsAt) or 0) - workspace:GetServerTimeNow()
						return UDim2.fromScale(math.clamp(left / math.max(1, buff.duration), 0, 1), 1)
					end),
					BackgroundColor3 = buff.color,
					BorderSizePixel = 0,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))) or nil,
				if props.navigate then function() props.navigate("Boosts") end else nil)
		end
	end
	return h("frame", {
		Size = UDim2.new(1, 0, 1, -(COMPACT_H + 6)),
		Position = arrive:map(function(t) return UDim2.fromOffset(0, COMPACT_H + 6 + (1 - t) * 8) end),
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, h("frame", {
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.fromOffset(16, 0),
		BackgroundColor3 = P.line,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}), h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows))
end

local function Announcement(props)
	local info = props.info
	local arrive = useArrive(props.token)
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, h("frame", {
		-- a band of light sweeps across once
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundColor3 = info.color,
		BorderSizePixel = 0,
		Position = arrive:map(function(t) return UDim2.fromScale(-0.6 + t * 1.8, 0) end),
		BackgroundTransparency = 0.72,
		ZIndex = 61,
	}, h("uigradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})), h("frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.darken(info.color, 0.55),
		BorderSizePixel = 0,
		ZIndex = 63,
		Rotation = props.clock:map(function(t) return math.sin(t * 5) * 6 end),
	}, h("uiscale", { Scale = arrive:map(function(t) return 0.3 + easeOutBack(t) * 0.7 end) }), h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = theme.lighten(info.color, 0.3),
		Thickness = 2,
	}), h(Icon, {
		kind = info.icon or "Boost",
		color = P.white,
		accent = info.color,
		size = 28,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), h("textlabel", {
		Size = UDim2.new(1, -86, 0, 28),
		Position = arrive:map(function(t) return UDim2.new(0, 72 + (1 - t) * 16, 0, if info.subtitle then 10 else 22) end),
		BackgroundTransparency = 1,
		Text = info.title,
		TextColor3 = P.white,
		TextTransparency = arrive:map(function(t) return 1 - t end),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 63,
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, h("uigradient", { Color = ColorSequence.new(theme.lighten(info.color, 0.45), info.color), Rotation = 90 }), h("uitextsizeconstraint", { MaxTextSize = 22, MinTextSize = 14 })),
		info.subtitle and h("textlabel", {
		Size = UDim2.new(1, -86, 0, 17 * (info.lines or 1)),
		Position = arrive:map(function(t) return UDim2.new(0, 72 + (1 - t) * 26, 0, 40) end),
		BackgroundTransparency = 1,
		Text = info.subtitle,
		TextColor3 = P.creamSoft,
		TextTransparency = arrive:map(function(t) return 1 - t end),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = (info.lines or 1) > 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 63,
	}))
end

-- a live combo: the island widens into a meter that drains until the combo window runs out
local function ComboActivity(props)
	local combo = props.combo
	local arrive = useArrive("combo" .. tostring(combo.count))
	local hot = combo.count >= (combo.max or 12)
	local color = if hot then P.coral else P.mango
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, h("frame", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.darken(color, 0.55),
		BorderSizePixel = 0,
		ZIndex = 63,
		Rotation = props.clock:map(function(t) return math.sin(t * 9) * (if hot then 10 else 4) end),
	}, h("uiscale", { Scale = arrive:map(function(t) return 0.6 + easeOutBack(t) * 0.4 end) }), h("uicorner", { CornerRadius = UDim.new(1, 0) }), h(Icon, {
		kind = "Overcharge",
		color = P.white,
		accent = color,
		size = 20,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})), h("textlabel", {
		Size = UDim2.fromOffset(150, 20),
		Position = UDim2.fromOffset(48, 4),
		BackgroundTransparency = 1,
		Text = if hot then `MAX COMBO x{combo.count}` else `COMBO x{combo.count}`,
		TextColor3 = theme.lighten(color, 0.35),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		ZIndex = 63,
	}, h("uiscale", { Scale = arrive:map(function(t) return 0.8 + easeOutBack(t) * 0.2 end) })), h("textlabel", {
		Size = UDim2.fromOffset(120, 18),
		Position = UDim2.new(1, -132, 0, 5),
		BackgroundTransparency = 1,
		Text = `{string.format("%.2f", combo.multiplier or 1)}x taps`,
		TextColor3 = P.creamSoft,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 63,
	}), h("frame", {
		Size = UDim2.new(1, -60, 0, 5),
		Position = UDim2.new(0, 48, 1, -12),
		BackgroundColor3 = P.line,
		BorderSizePixel = 0,
		ZIndex = 63,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("frame", {
		Size = props.clock:map(function()
			local left = combo.at + (combo.window or 1.8) - os.clock()
			return UDim2.fromScale(math.clamp(left / (combo.window or 1.8), 0, 1), 1)
		end),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", { Color = ColorSequence.new(theme.lighten(color, 0.4), color) }))))
end

-- an announcement is only as wide as its words; a long line wraps onto a second row
local TextService = game:GetService("TextService")
local function textWidth(text, size, font)
	local ok, bounds = pcall(TextService.GetTextSize, TextService, text, size, font, Vector2.new(4000, 100))
	return if ok then bounds.X else #text * size * 0.55
end
local function measureEvent(info, maxWidth)
	local cap = math.min(maxWidth or 560, 560)
	local titleW = textWidth(info.title or "", 22, Enum.Font.BuilderSansExtraBold)
	local subtitleW = if info.subtitle then textWidth(info.subtitle, 13, Enum.Font.BuilderSansBold) else 0
	local width = math.clamp(math.ceil(92 + math.max(titleW, math.min(subtitleW, 380))), 240, cap)
	local room = math.max(80, width - 92)
	info.width = width
	info.lines = if subtitleW > room then 2 else 1
end

-- props: state, config, currencies { {target, name, value, icon, color} }, perf { showFps, showPing },
-- rate (flux per second), vaultFull, navigate, maxWidth, position, anchorPoint, restHidden, reducedMotion
function BuffStrip.Island(props)
	local clock = motion.useClock(true, 1, 3600, true)
	local now = workspace:GetServerTimeNow()
	local buffs = BuffStrip.list(props.state, props.config, now)
	local maxWidth = props.maxWidth or 640
	local plan = planCompact(props, buffs)
	local hovered, setHovered = React.useState(false)
	local pinned, setPinned = React.useState(false)
	-- announcements queue up and play one after another
	local event, setEvent = React.useState(nil)
	local queue = React.useRef({})
	local playing = React.useRef(false)
	local token = React.useRef(0)
	local holdTimer = React.useRef(nil)
	local alive = React.useRef(true)
	local maxWidthRef = React.useRef(maxWidth)
	maxWidthRef.current = maxWidth
	local playNextRef = React.useRef(nil)
	playNextRef.current = function()
		if holdTimer.current then
			pcall(task.cancel, holdTimer.current)
			holdTimer.current = nil
		end
		if not alive.current then
			return
		end
		local nextInfo = table.remove(queue.current, 1)
		if nextInfo == nil then
			playing.current = false
			setEvent(nil)
			return
		end
		playing.current = true
		token.current += 1
		nextInfo.token = token.current
		measureEvent(nextInfo, maxWidthRef.current)
		setEvent(nextInfo)
		-- a backlog plays through faster
		local hold = (nextInfo.duration or 2.6) * (if #queue.current >= 3 then 0.55 elseif #queue.current >= 1 then 0.75 else 1)
		holdTimer.current = task.delay(hold, function()
			holdTimer.current = nil
			playNextRef.current()
		end)
	end
	React.useEffect(function()
		alive.current = true
		local stopBanner = Juice.onBanner(function(info)
			-- the same line twice in a row only plays once
			local last = queue.current[#queue.current]
			if last and last.title == info.title and last.subtitle == info.subtitle then
				return
			end
			if #queue.current >= 6 then
				table.remove(queue.current, 1)
			end
			table.insert(queue.current, info)
			if not playing.current then
				playNextRef.current()
			end
		end)
		return function()
			alive.current = false
			stopBanner()
			queue.current = {}
			if holdTimer.current then
				pcall(task.cancel, holdTimer.current)
			end
		end
	end, {})
	-- hover is read from the pointer itself: enter/leave events go stale when the capsule
	-- changes size under the cursor, and touch never sends a leave
	local islandRef = React.useRef(nil)
	React.useEffect(function()
		local UserInputService = game:GetService("UserInputService")
		local GuiService = game:GetService("GuiService")
		local wait = 0
		local last = false
		local connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
			wait += dt
			if wait < 0.1 then
				return
			end
			wait = 0
			local island = islandRef.current
			local over = false
			local inputType = UserInputService:GetLastInputType()
			local mouseInput = inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.MouseWheel
			if island ~= nil and island.Parent ~= nil and mouseInput then
				local screenGui = island:FindFirstAncestorOfClass("ScreenGui")
				local inset = if screenGui ~= nil and screenGui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
				local mouse = UserInputService:GetMouseLocation() - inset
				local topLeft, size = island.AbsolutePosition, island.AbsoluteSize
				-- a little slack once inside so the edge doesn't flicker
				local slack = if last then 10 else 0
				over = size.X > 4 and mouse.X >= topLeft.X - slack and mouse.X <= topLeft.X + size.X + slack and mouse.Y >= topLeft.Y - slack and mouse.Y <= topLeft.Y + size.Y + slack
			end
			if over ~= last then
				last = over
				setHovered(over)
			end
		end)
		-- a tap anywhere else lets go of a pinned island
		local began = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local island = islandRef.current
			if island == nil then
				return
			end
			local p, topLeft, size = input.Position, island.AbsolutePosition, island.AbsoluteSize
			local inside = p.X >= topLeft.X and p.X <= topLeft.X + size.X and p.Y >= topLeft.Y and p.Y <= topLeft.Y + size.Y
			if not inside then
				setPinned(false)
			end
		end)
		return function()
			connection:Disconnect()
			began:Disconnect()
		end
	end, {})
	-- live activity: the overcharge combo
	local combo, setCombo = React.useState(nil)
	React.useEffect(function()
		local stop = Juice.onActivity(function(kind, data)
			if kind == "combo" and type(data) == "table" then
				local entry = { count = data.combo or 0, multiplier = data.multiplier, max = data.max, window = data.window or 1.8, at = os.clock() }
				setCombo(entry)
				task.delay(entry.window + 0.15, function()
					setCombo(function(current)
						return if current == entry then nil else current
					end)
				end)
			end
		end)
		return stop
	end, {})
	-- a buff that just started announces itself
	local signature = {}
	for _, buff in buffs do
		table.insert(signature, buff.key)
	end
	local signatureText = table.concat(signature, ",")
	local seen = React.useRef(nil)
	React.useEffect(function()
		local current = {}
		for _, buff in buffs do
			current[buff.key] = buff
		end
		if seen.current ~= nil then
			for key, buff in current do
				if seen.current[key] == nil and (key == "boost" or key == "surge" or key == "event") then
					Juice.banner(`{string.upper(buff.name)} ON`, `{buff.value} production while it lasts`, buff.color, buff.icon)
				end
			end
		end
		seen.current = current
	end, { signatureText })

	local hasContent = plan.width > 30 and ((props.currencies and #props.currencies > 0) or #plan.buffs > 0 or plan.perf)
	local comboLive = combo ~= nil and combo.count >= 2
	local mode = if event ~= nil then "event"
		elseif comboLive and not (hovered or pinned) then "combo"
		elseif props.restHidden then "hidden"
		elseif hovered or pinned then "expanded"
		elseif hasContent then "compact"
		else "hidden"
	local compactW = math.min(maxWidth, plan.width)
	local targetW = if mode == "event" then math.min(maxWidth, event.width or 520)
		elseif mode == "combo" then math.min(maxWidth, 360)
		elseif mode == "expanded" then math.min(maxWidth, math.max(420, compactW))
		elseif mode == "compact" then compactW
		else 0
	local targetH = if mode == "event" then EVENT_H + 17 * ((event.lines or 1) - 1)
		elseif mode == "combo" then COMPACT_H + 4
		elseif mode == "expanded" then expandedHeight(props, buffs)
		elseif mode == "compact" then COMPACT_H
		else 0
	local width = motion.useFlipperSpring(targetW, props.reducedMotion, 300, 24)
	local height = motion.useFlipperSpring(targetH, props.reducedMotion, 300, 24)
	-- jelly: each change of shape lands with a small squash and settles
	local modeKey = mode .. (if event then tostring(event.token) else "") .. (if combo then tostring(combo.count) else "")
	local jelly = motion.useFlash(modeKey, props.reducedMotion, 0.5)
	local glow = motion.usePulse(true, if props.vaultFull then 3.2 else 1.6)
	local accent = if event then event.color elseif mode == "combo" then P.mango elseif props.vaultFull then P.mango else P.lineSoft
	local content = if mode == "event" then h(Announcement, { key = "event" .. event.token, info = event, token = event.token, clock = clock })
		elseif mode == "combo" then h(ComboActivity, { key = "combo", combo = combo, clock = clock })
		elseif mode == "expanded" then h(React.Fragment, nil,
			h(CompactRow, { key = "top", plan = plan, currencies = props.currencies, perf = props.perf, vaultFull = props.vaultFull, clock = clock, reducedMotion = props.reducedMotion }),
			h(ExpandedList, { key = "list", buffs = buffs, currencies = props.currencies, perf = props.perf, rate = props.rate, navigate = props.navigate, clock = clock }))
		elseif mode == "compact" then h(CompactRow, { key = "top", plan = plan, currencies = props.currencies, perf = props.perf, vaultFull = props.vaultFull, clock = clock, reducedMotion = props.reducedMotion })
		else nil
	return h("imagebutton", {
		Name = "BuffIsland",
		ref = islandRef,
		Size = React.joinBindings({ width, height }):map(function(values)
			return UDim2.fromOffset(math.max(0, values[1]), math.max(0, values[2]))
		end),
		Position = props.position,
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(6, 6, 10),
		BackgroundTransparency = 0.02,
		AutoButtonColor = false,
		Image = "",
		ClipsDescendants = true,
		Visible = width:map(function(v) return v > 4 end),
		ZIndex = 60,
		Event = {
			Activated = function()
				-- tapping an announcement moves on to the next one
				if event ~= nil then
					playNextRef.current()
					return
				end
				setPinned(not pinned)
			end,
		},
	}, h("uiscale", {
		Scale = jelly:map(function(v) return 1 + math.sin(v * math.pi) * 0.045 end),
	}), h("uicorner", {
		CornerRadius = height:map(function(v) return UDim.new(0, math.clamp(v / 2, 10, 22)) end),
	}), h("uistroke", {
		Color = accent,
		Thickness = if event or props.vaultFull or mode == "combo" then 2 else 1,
		Transparency = glow:map(function(v) return if event or props.vaultFull or mode == "combo" then 0.05 + v * 0.35 else 0.45 + v * 0.25 end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		-- a slow sheen crosses the capsule every few seconds
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundColor3 = P.white,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		ZIndex = 61,
		Position = clock:map(function(t)
			local phase = (t % 7) / 1.1
			return UDim2.fromScale(-0.4 + math.clamp(phase, 0, 1) * 1.8, 0)
		end),
	}, h("uigradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})), content)
end

return BuffStrip
