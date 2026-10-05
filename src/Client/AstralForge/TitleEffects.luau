--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local motion = require(script.Parent.MotionKit)("motion")
local EffectMath = require(script.Parent.TitleEffectMath)
local createElement = React.createElement
local Titles = {}
local function markDecorative(instance)
	if instance then
		instance:SetAttribute("LayoutGuardIgnore", true)
	end
end
local presets = {
	wave = { Palette.cyan, "wave" },
	fire = { Palette.mango, "fire" },
	ice = { Palette.cyan, "crystal" },
	glitch = { Palette.pink, "glitch" },
	galaxy = { Palette.violet, "orbit" },
	rainbow = { Palette.mango, "spectrum" },
	glow = { Palette.cream, "pulse" },
	neon = { Palette.mint, "pulse" },
	sparkle = { Palette.mango, "stars" },
	shake = { Palette.coral, "glitch" },
	pulse = { Palette.violet, "pulse" },
	["gradient-shift"] = { Palette.blue, "spectrum" },
	holographic = { Palette.cyan, "scan" },
	void = { Palette.violet, "orbit" },
	plasma = { Palette.pink, "electric" },
	chrome = { Palette.creamSoft, "scan" },
	ember = { Palette.coral, "fire" },
	frost = { Palette.cyan, "crystal" },
	aurora = { Palette.mint, "spectrum" },
	matrix = { Palette.green, "scan" },
	static = { Palette.cream, "glitch" },
	["bounce-in"] = { Palette.mango, "wave" },
	["blur-resolve"] = { Palette.cream, "scan" },
	shimmer = { Palette.creamSoft, "scan" },
	toxic = { Palette.green, "fire" },
	solar = { Palette.mango, "orbit" },
	ocean = { Palette.blue, "wave" },
	candy = { Palette.pink, "spectrum" },
	voltage = { Palette.cyan, "electric" },
	prism = { Palette.pink, "spectrum" },
	phantom = { Palette.violet, "orbit" },
}
Titles.TITLE_FX_KINDS = {}
for kind in presets do
	table.insert(Titles.TITLE_FX_KINDS, kind)
end
table.sort(Titles.TITLE_FX_KINDS)
function Titles.parseFx(fx)
	local key = if type(fx) == "string" then string.lower(fx) else ""
	return if presets[key] then key else nil
end
function Titles.titleFxAccent(fx)
	local preset = presets[Titles.parseFx(fx)]
	return if preset then preset[1] else Palette.creamSoft
end
function Titles.darkTitlePlate(fx)
	return Titles.titleFxAccent(fx):Lerp(Palette.ink, 0.82)
end
local listeners, driver, elapsed, carry = {}, nil, 0, 0
local function visible(host)
	if not host or not host.Parent or host.AbsoluteSize.X <= 0 then
		return false
	end
	local at, size, parent = host.AbsolutePosition, host.AbsoluteSize, host.Parent
	while parent do
		if parent:IsA("GuiObject") then
			if not parent.Visible then
				return false
			end
			if parent.ClipsDescendants then
				local p, s = parent.AbsolutePosition, parent.AbsoluteSize
				if at.X + size.X <= p.X or at.X >= p.X + s.X or at.Y + size.Y <= p.Y or at.Y >= p.Y + s.Y then
					return false
				end
			end
		end
		parent = parent.Parent
	end
	return true
end
local function subscribe(host, callback)
	local entry = { host = host, callback = callback }
	listeners[entry] = true
	if not driver then
		driver = RunService.RenderStepped:Connect(function(dt)
			carry += dt
			if carry < 1 / 30 then
				return
			end
			local step = carry
			carry = 0
			if workspace:GetAttribute("AF_TitleFxHold") == true then
				return
			end
			elapsed += math.min(step, 0.1)
			for item in listeners do
				if visible(item.host.current) then
					item.callback(elapsed)
				end
			end
		end)
	end
	return function()
		listeners[entry] = nil
		if not next(listeners) and driver then
			driver:Disconnect()
			driver = nil
			carry = 0
		end
	end
end
function Titles.AnimatedTitle(props)
	local text = tostring(props.text or "")
	local size = props.size or 13
	local kind = Titles.parseFx(props.fx)
	local preset = presets[kind] or { Palette.creamSoft, "none" }
	local accent, family = preset[1], preset[2]
	local motionSettings = motion.useMotionSettings()
	local soft = props.reducedMotion == true or motionSettings.soft == true
	local host = React.useRef(nil)
	local clock, setClock = React.useBinding(0)
	local metrics, setMetrics = React.useBinding(Vector2.new(1, 0))
	local chars, widths, total = {}, {}, 0
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		local width = TextService:GetTextSize(char, size, Enum.Font.BuilderSansBold, Vector2.new(1000, 1000)).X + 0.5
		table.insert(chars, char)
		table.insert(widths, width)
		total += width
	end
	React.useEffect(function()
		local frame = host.current
		if not frame then
			return
		end
		local function measure()
			local scale = math.min(1, frame.AbsoluteSize.X / math.max(1, total))
			local left = if props.align == Enum.TextXAlignment.Center
				then (frame.AbsoluteSize.X - total * scale) / 2
				elseif props.align == Enum.TextXAlignment.Right then frame.AbsoluteSize.X - total * scale
				else 0
			setMetrics(Vector2.new(scale, left))
		end
		measure()
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		local off = if kind and not soft then subscribe(host, setClock) else nil
		return function()
			resized:Disconnect()
			if off then
				off()
			end
		end
	end, { text, size, kind, soft, props.align })
	local speed = math.clamp(tonumber(props.speed) or 1, 0.25, 2)
	local power = math.clamp(tonumber(props.intensity) or 1, 0, 1.5)
	local children = {}
	if kind then
		for layer = 1, 2 do
			children["Echo" .. layer] = createElement("textlabel", {
				ref = markDecorative,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = text,
				TextScaled = true,
				TextXAlignment = props.align or Enum.TextXAlignment.Left,
				Font = Enum.Font.BuilderSansBold,
				TextColor3 = if layer == 1 then accent else Palette.cream,
				TextTransparency = math.min(1, 0.88 + (props.transparency or 0) * 0.12),
				TextStrokeColor3 = accent,
				TextStrokeTransparency = 0.82,
				ZIndex = 1,
				Position = clock:map(function(time)
					local drift = if soft then 0 else math.sin(time * speed * 2 + layer) * 1.4 * power
					return UDim2.fromOffset((layer * 2 - 3) * 1.5, drift)
				end),
			}, createElement("uitextsizeconstraint", { MinTextSize = 1, MaxTextSize = size }))
		end
	end
	local x = 0
	for i, char in chars do
		local origin, width = x, widths[i]
		x += width
		local values = React.joinBindings({ clock, metrics })
		children["Glyph" .. i] = createElement(
			"textlabel",
			{
				ref = markDecorative,
				BackgroundTransparency = 1,
				Text = char,
				RichText = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				Font = Enum.Font.BuilderSansBold,
				ZIndex = 3,
				TextTransparency = props.transparency or 0,
				TextSize = metrics:map(function(v)
					return math.max(1, size * v.X)
				end),
				Size = metrics:map(function(v)
					return UDim2.new(0, width * v.X, 1, 0)
				end),
				Position = values:map(function(v)
					local t = v[1] * speed
					local offset = 0
					local horizontalOffset = 0
					if not soft then
						if family == "wave" then
							offset = math.sin(t * 3 - i * 0.45) * size * 0.09 * power
						elseif family == "fire" then
							offset = -math.abs(math.sin(t * 4 + i)) * size * 0.06 * power
						elseif family == "glitch" then
							offset = math.sin(math.floor(t * 8) + i * 3) * size * 0.04 * power
							horizontalOffset = math.sin(math.floor(t * 11) + i * 7) * size * 0.07 * power
						elseif family == "electric" then
							offset = math.sin(t * 18 + i * 2) * size * 0.025 * power
						elseif family == "orbit" then
							offset = math.sin(t * 2 + i * 0.6) * size * 0.07 * power
						end
					end
					return UDim2.new(0, v[2].Y + origin * v[2].X + horizontalOffset, 0, offset)
				end),
				Rotation = clock:map(function(time)
					if soft or not kind then
						return 0
					end
					if family == "wave" or family == "orbit" then
						return math.sin(time * speed * 3 - i * 0.45) * 5 * power
					end
					return 0
				end),
				TextColor3 = clock:map(function(t)
					if family == "spectrum" and not soft then
						return Color3.fromHSV((t * 0.08 * speed + i / math.max(1, #chars) * 0.35) % 1, 0.55, 1)
					end
					local shine = if soft then 0.12 else (math.sin(t * speed * 2 - i * 0.35) + 1) * 0.25
					return accent:Lerp(Palette.cream, shine)
				end),
				TextStrokeColor3 = accent,
				TextStrokeTransparency = clock:map(function(time)
					if not kind then
						return 1
					end
					if soft then
						return 0.72
					end
					return 0.35 + (math.sin(time * speed * 4 - i * 0.5) + 1) * 0.2
				end),
			},
			if kind
				then {
					LetterLighting = createElement("uigradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(0, 0, 0), 0.3)),
							ColorSequenceKeypoint.new(0.38, Color3.new(1, 1, 1)),
							ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
							ColorSequenceKeypoint.new(1, accent),
						}),
						Rotation = if family == "fire" then 90 else 25,
						Offset = clock:map(function(time)
							if soft then
								return Vector2.zero
							end
							local phase = time * speed * 0.7 - i * 0.12
							return Vector2.new(math.sin(phase) * 0.65, math.cos(phase) * 0.2)
						end),
					}),
				}
				else nil
		)
	end
	if kind then
		for i = 1, 6 do
			children["Mote" .. i] = createElement("frame", {
				ref = markDecorative,
				BorderSizePixel = 0,
				ZIndex = 2,
				BackgroundColor3 = accent,
				Size = UDim2.fromOffset(if i % 2 == 0 then 2 else 3, 2),
				BackgroundTransparency = clock:map(function(t)
					return if soft then 0.85 else 0.35 + 0.5 * math.abs(math.sin(t + i))
				end),
				Position = clock:map(function(t)
					local a = if soft
						then i / 7
						else (i / 7 + t * speed * (if family == "fire" then 0.08 else 0.025)) % 1
					return UDim2.fromScale(a, 0.5 + math.sin(a * math.tau + i) * 0.38)
				end),
			}, createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
		if family == "electric" or family == "glitch" then
			for i = 1, 8 do
				local function segment(time)
					local frame = host.current
					local dimensions = if frame then frame.AbsoluteSize else Vector2.new(160, size + 6)
					return EffectMath.lightningSegment(i, time * speed, dimensions.X, dimensions.Y, soft)
				end
				children["Arc" .. i] = createElement("frame", {
					ref = markDecorative,
					ZIndex = 2,
					BorderSizePixel = 0,
					BackgroundColor3 = accent,
					AnchorPoint = Vector2.new(0, 0.5),
					Size = clock:map(function(time)
						return UDim2.fromOffset(segment(time).Length, 1)
					end),
					Position = clock:map(function(time)
						local geometry = segment(time)
						return UDim2.fromScale(geometry.X, geometry.Y)
					end),
					Rotation = clock:map(function(time)
						return segment(time).Angle
					end),
					BackgroundTransparency = clock:map(function(t)
						return if soft then 0.9 else 0.65 + 0.3 * math.abs(math.sin(t * 2))
					end),
				})
			end
		end
		children.Sweep = createElement("frame", {
			ref = markDecorative,
			ZIndex = 2,
			BorderSizePixel = 0,
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.75,
			Size = UDim2.new(0.18, 0, 0, 1),
			Position = clock:map(function(t)
				return UDim2.fromScale(if soft then 0.4 else (t * 0.12 * speed) % 1, 0.95)
			end),
		})
	end
	return createElement("frame", {
		Name = "TitleEffectsV2",
		ref = host,
		Size = props.sizeConstraint or UDim2.new(1, 0, 0, size + 6),
		Position = props.position,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = props.zIndex or 2,
	}, children)
end
function Titles.AnimatedTitlePreview(props)
	local copy = table.clone(props)
	copy.align = Enum.TextXAlignment.Center
	copy.size = props.size or 15
	return createElement(Titles.AnimatedTitle, copy)
end
return Titles
