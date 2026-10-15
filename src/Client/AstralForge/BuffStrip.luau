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
		table.insert(list, { key = "event", icon = "Calendar", value = "Event", endsAt = event.PhaseEndsAt, color = P.mango, name = event.Id })
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

local COMPACT_H = 40
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

local function CompactRow(props)
	local arrive = useArrive("compact")
	local items = {
		layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, buff in props.buffs do
		items[buff.key] = h("frame", {
			Size = UDim2.fromOffset(52, COMPACT_H),
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, h(Icon, {
			kind = buff.icon,
			color = P.cream,
			accent = buff.color,
			size = 20,
			anchorPoint = Vector2.new(0, 0.5),
			position = props.clock:map(function(t)
				return UDim2.new(0, 0, 0.5, math.sin(t * 2.4 + index * 1.4) * 1.5)
			end),
			spin = false,
		}), h("textlabel", {
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(24, 0),
			BackgroundTransparency = 1,
			Text = buff.value,
			TextColor3 = theme.lighten(buff.color, 0.35),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		}, h("uitextsizeconstraint", { MaxTextSize = 13, MinTextSize = 9 })))
	end
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Position = arrive:map(function(t) return UDim2.fromOffset(0, (1 - t) * 6) end),
		ZIndex = 62,
	}, h("uiscale", { Scale = arrive:map(function(t) return 0.9 + t * 0.1 end) }), items)
end

local function ExpandedList(props)
	local arrive = useArrive("expanded")
	local rows = {
		layout = h("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad = h("uipadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 10) }),
		title = h("textlabel", {
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 0,
			BackgroundTransparency = 1,
			Text = "BOOSTING YOU NOW",
			TextColor3 = P.muted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		}),
	}
	for index, buff in props.buffs do
		local timed = buff.endsAt ~= nil
		rows[buff.key] = h("frame", {
			Size = UDim2.new(1, 0, 0, ROW_H),
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, h("uiscale", {
			Scale = arrive:map(function(t)
				local local_ = math.clamp(t * 1.6 - index * 0.12, 0, 1)
				return 0.85 + easeOutBack(local_) * 0.15
			end),
		}), h("frame", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = theme.darken(buff.color, 0.6),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(0, 8) }), h(Icon, {
			kind = buff.icon,
			color = P.cream,
			accent = buff.color,
			size = 18,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			spin = false,
		})), h("textlabel", {
			Size = UDim2.new(1, -150, 0, 18),
			Position = UDim2.new(0, 36, 0, if timed then 2 else 9),
			BackgroundTransparency = 1,
			Text = buff.name,
			TextColor3 = P.cream,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		}), h("textlabel", {
			Size = UDim2.fromOffset(110, 18),
			Position = UDim2.new(1, -110, 0, if timed then 2 else 9),
			BackgroundTransparency = 1,
			Text = if timed then props.clock:map(function()
				return `{buff.value}  ·  {clockText((tonumber(buff.endsAt) or 0) - workspace:GetServerTimeNow())}`
			end) else buff.value,
			TextColor3 = theme.lighten(buff.color, 0.35),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		}), timed and buff.duration and h("frame", {
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
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))))
	end
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, rows)
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
	}, h("uigradient", { Color = ColorSequence.new(theme.lighten(info.color, 0.45), info.color), Rotation = 90 }), h("uitextsizeconstraint", { MaxTextSize = 22, MinTextSize = 14 })),
		info.subtitle and h("textlabel", {
		Size = UDim2.new(1, -86, 0, 18),
		Position = arrive:map(function(t) return UDim2.new(0, 72 + (1 - t) * 26, 0, 40) end),
		BackgroundTransparency = 1,
		Text = info.subtitle,
		TextColor3 = P.creamSoft,
		TextTransparency = arrive:map(function(t) return 1 - t end),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 63,
	}))
end

function BuffStrip.Island(props)
	local clock = motion.useClock(true, 1, 3600, true)
	local now = workspace:GetServerTimeNow()
	local buffs = BuffStrip.list(props.state, props.config, now)
	local maxWidth = props.maxWidth or 520
	local fit = math.max(0, math.floor((maxWidth - 32) / 64))
	local shown = {}
	for index, buff in buffs do
		if index <= fit then
			table.insert(shown, buff)
		end
	end
	local hovered, setHovered = React.useState(false)
	local pinned, setPinned = React.useState(false)
	local event, setEvent = React.useState(nil)
	local eventToken = React.useRef(0)
	React.useEffect(function()
		return Juice.onBanner(function(info)
			eventToken.current += 1
			local token = eventToken.current
			info.token = token
			setEvent(info)
			task.delay(2.9, function()
				if eventToken.current == token then
					setEvent(nil)
				end
			end)
		end)
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

	-- phones keep the island out of the way at rest: it only drops in to announce something
	local mode = if event ~= nil then "event" elseif props.restHidden then "hidden" elseif (hovered or pinned) and #buffs > 0 then "expanded" elseif #shown > 0 then "compact" else "hidden"
	local targetW = if mode == "event" then math.min(maxWidth, 440)
		elseif mode == "expanded" then math.min(maxWidth, 340)
		elseif mode == "compact" then 24 + #shown * 64 - 12 + 16
		else 0
	local targetH = if mode == "event" then EVENT_H
		elseif mode == "expanded" then 18 + 14 + #buffs * ROW_H
		elseif mode == "compact" then COMPACT_H
		else 0
	local width = motion.useFlipperSpring(targetW, props.reducedMotion, 300, 26)
	local height = motion.useFlipperSpring(targetH, props.reducedMotion, 300, 26)
	local glow = motion.usePulse(true, 1.6)
	local accent = if event then event.color else P.lineSoft
	local content = if mode == "event" then h(Announcement, { key = "event" .. event.token, info = event, token = event.token, clock = clock })
		elseif mode == "expanded" then h(ExpandedList, { key = "expanded", buffs = buffs, clock = clock })
		elseif mode == "compact" then h(CompactRow, { key = "compact", buffs = shown, clock = clock })
		else nil
	return h("imagebutton", {
		Name = "BuffIsland",
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
			MouseEnter = function() setHovered(true) end,
			MouseLeave = function() setHovered(false) end,
			Activated = function() setPinned(not pinned) end,
		},
	}, h("uicorner", {
		CornerRadius = height:map(function(v) return UDim.new(0, math.clamp(v / 2, 10, 24)) end),
	}), h("uistroke", {
		Color = accent,
		Thickness = if event then 2 else 1,
		Transparency = glow:map(function(v) return if event then 0.05 + v * 0.3 else 0.45 + v * 0.25 end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), content)
end

return BuffStrip
