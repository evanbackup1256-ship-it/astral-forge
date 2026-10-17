--!nonstrict
-- Star Foundry: a hex board of star pieces. Embers send energy along the way they face, Conduits and
-- Lenses carry it, Prisms split it, Anvils turn it into production, tap, capacity and offline bonuses.
-- Tap a piece (board or bench), then a cell, to place, move or fuse it. Ignite when the sweeping wave
-- crosses your brightest Anvil for Shards; ten on the beat in a row light a surge.
-- The board you see runs the same FoundryMath the server does, so the flow drawn is the flow you get.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
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
local useFlash = _motion.useFlash
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local FoundryMath = require(game.ReplicatedStorage.AstralForge.Shared.FoundryMath)
local h = React.createElement

local ACCENT = Color3.fromRGB(255, 176, 92)
local GAP = 14
local KIND_LOOK = {
	Ember = { name = "Ember", color = Color3.fromRGB(255, 132, 64), icon = "Flux", line = "Sends energy the way it faces" },
	Conduit = { name = "Conduit", color = Color3.fromRGB(120, 196, 255), icon = "Travel", line = "Carries energy onward" },
	Lens = { name = "Lens", color = Color3.fromRGB(150, 236, 255), icon = "Boost", line = "Focuses energy, stronger" },
	Prism = { name = "Prism", color = Color3.fromRGB(200, 150, 255), icon = "StarGrid", line = "Splits energy three ways" },
	ForgeAnvil = { name = "Forge Anvil", color = Color3.fromRGB(255, 196, 84), icon = "Forge", line = "Energy becomes production" },
	StrikeAnvil = { name = "Strike Anvil", color = Color3.fromRGB(255, 104, 112), icon = "Overcharge", line = "Energy becomes tap power" },
	VaultAnvil = { name = "Vault Anvil", color = Color3.fromRGB(96, 220, 168), icon = "Vault", line = "Energy becomes vault capacity" },
	EchoAnvil = { name = "Echo Anvil", color = Color3.fromRGB(176, 140, 255), icon = "Continuum", line = "Energy becomes offline income" },
}

local function compact(value)
	return Format.compactNumber(value)
end

-- flat-top hex layout: axial (q, r) -> pixel centre
local function hexPixel(q, r, size)
	return Vector2.new(size * 1.5 * q, size * math.sqrt(3) * (r + q / 2))
end

local function directionAngle(direction)
	local d = FoundryMath.DIRECTIONS[direction + 1]
	local p = hexPixel(d[1], d[2], 1)
	return math.deg(math.atan2(p.Y, p.X))
end

-- A flat-top hexagon from plain frames: three rectangles (R wide, sqrt(3)R tall) at 0, 60 and 120
-- degrees overlap into exactly the hexagon with circumradius R.
local function Hexagon(props)
	local r = props.radius
	local bars = {}
	for index, angle in { 0, 60, 120 } do
		bars["bar" .. index] = h("frame", {
			Size = UDim2.fromOffset(r, r * math.sqrt(3)),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = angle,
			BackgroundColor3 = props.color,
			BackgroundTransparency = props.transparency or 0,
			BorderSizePixel = 0,
			ZIndex = props.zIndex or 1,
		}, props.gradient and h("uigradient", props.gradient))
	end
	return h("frame", {
		Size = UDim2.fromOffset(r * 2, r * 2),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex or 1,
	}, bars)
end

-- a soft round glow: concentric discs, each faint, so the middle builds up and the edge fades out
local function Halo(props)
	local d = props.size
	local strength = 1 - (props.transparency or 0.2)
	local discs = {}
	local steps = 6
	for index = 1, steps do
		local share = index / steps
		discs["disc" .. index] = h("frame", {
			Size = UDim2.fromScale(share, share),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.color,
			BackgroundTransparency = 1 - strength / steps * 1.6,
			BorderSizePixel = 0,
			ZIndex = props.zIndex or 1,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h("frame", {
		Size = UDim2.fromOffset(d, d),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex or 1,
	}, discs)
end

-- tier shown as pips under the piece (a compact corner badge when cells are small or tier > 5)
local function TierMark(props)
	local tier = props.tier
	local color = props.color
	local d = props.cellSize or 40
	if d < 32 or tier > 5 then
		return h("textlabel", {
			Size = UDim2.fromOffset(if d < 32 then 18 else 22, if d < 32 then 10 else 12),
			Position = if d < 32 then UDim2.new(1, -1, 0, 1) else UDim2.new(0.5, 0, 1, 2),
			AnchorPoint = if d < 32 then Vector2.new(1, 0) else Vector2.new(0.5, 0),
			BackgroundColor3 = darken(color, 0.7),
			Text = tostring(tier),
			TextColor3 = lighten(color, 0.5),
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			ZIndex = props.zIndex,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	local pips = {}
	for index = 1, tier do
		pips["p" .. index] = h("frame", {
			Size = UDim2.fromOffset(4, 4),
			Position = UDim2.new(0.5, (index - (tier + 1) / 2) * 7, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = lighten(color, 0.4),
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h(React.Fragment, nil, pips)
end

-- Each kind has its own silhouette: an Ember is a burning four-point star, a Conduit a diamond,
-- a Lens a ring with a bright core, a Prism a triangle, an Anvil a solid hexagon plate.
local function PieceFace(props)
	local piece = props.piece
	local look = KIND_LOOK[piece.Kind] or KIND_LOOK.Conduit
	local d = props.size
	local z = props.zIndex or 4
	local color = look.color
	local lit = props.lit or 0
	local clock = props.clock
	local body
	if piece.Kind == "Ember" then
		local rays = {}
		for index, angle in { 0, 90 } do
			rays["ray" .. index] = h("frame", {
				Size = UDim2.new(1.15, 0, 0, math.max(2, math.floor(d * 0.1))),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = if clock then clock:map(function(t) return angle + t * 18 end) else angle,
				BackgroundColor3 = lighten(color, 0.45),
				BorderSizePixel = 0,
				ZIndex = z + 1,
			}, h("uigradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }))
		end
		body = h(React.Fragment, nil,
			h(Halo, { size = d * 1.5, color = color, transparency = 0.1, zIndex = z }),
			h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z + 1 }, rays),
			h("frame", {
				Size = UDim2.fromScale(0.42, 0.42), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.white, BorderSizePixel = 0, ZIndex = z + 2,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = color, Thickness = 3 })))
	elseif piece.Kind == "Conduit" then
		body = h("frame", {
			Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45, BackgroundColor3 = darken(color, 0.35), BorderSizePixel = 0, ZIndex = z + 1,
		}, h("uicorner", { CornerRadius = UDim.new(0, 3) }), h("uistroke", { Color = lighten(color, 0.3), Thickness = 2 }))
	elseif piece.Kind == "Lens" then
		body = h(React.Fragment, nil,
			h("frame", {
				Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1, ZIndex = z + 1,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = color, Thickness = math.max(2, d * 0.07) })),
			h("frame", {
				Size = UDim2.fromScale(0.22, 0.22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = lighten(color, 0.6), BorderSizePixel = 0, ZIndex = z + 2,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))
	elseif piece.Kind == "Prism" then
		body = h("frame", {
			-- a square with a hard diagonal mask, turned: an upward triangle
			Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.6), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z + 1,
		}, h("uigradient", {
			Rotation = -135,
			Color = ColorSequence.new(lighten(color, 0.4), darken(color, 0.2)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.495, 1), NumberSequenceKeypoint.new(0.505, 0), NumberSequenceKeypoint.new(1, 0) }),
		}))
	else
		-- anvils: a solid hexagon plate in the colour of what they make, the stat icon inset
		body = h(React.Fragment, nil,
			h(Hexagon, { radius = d * 0.42, color = darken(color, 0.45), zIndex = z + 1 }),
			h(Hexagon, { radius = d * 0.34, color = color, transparency = 0.15, zIndex = z + 1,
				gradient = { Rotation = 90, Color = ColorSequence.new(lighten(color, 0.35), darken(color, 0.25)) } }),
			h(Icon, { kind = look.icon, color = Palette.ink, accent = Palette.ink, size = math.floor(d * 0.36), position = UDim2.fromScale(0.5, 0.5), anchorPoint = Vector2.new(0.5, 0.5), spin = false }))
	end
	return h("frame", {
		Size = UDim2.fromOffset(d, d),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = z,
	},
		-- energy passing through makes a piece glow
		lit > 0.05 and FoundryMath.KINDS[piece.Kind].role ~= "source" and h(Halo, { size = d * (1 + lit * 0.5), color = color, transparency = 0.55 - lit * 0.35, zIndex = z }),
		props.selected and h("frame", {
			Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, ZIndex = z + 3,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = Palette.white, Thickness = 2, Transparency = 0.1 })),
		body,
		props.showFacing and FoundryMath.KINDS[piece.Kind].role ~= "sink" and h("frame", {
			-- a stub of beam out of the side it faces
			Size = UDim2.fromOffset(math.floor(d * 0.62), 3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = directionAngle(piece.Facing),
			BackgroundColor3 = lighten(color, 0.4),
			BorderSizePixel = 0,
			ZIndex = z,
		}, h("uigradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }) })),
		h(TierMark, { tier = piece.Tier, color = color, cellSize = d, zIndex = z + 3 }))
end

local function Board(props)
	local foundry = props.foundry
	local flow = props.flow
	local size = props.cellSize
	local clock = useClock(not props.softMotion, 1, 3600, true)
	local centre = Vector2.new(props.width / 2, props.height / 2)
	local children = {}
	-- deep space: a warm nebula behind the board and a slow, faint drift of stars
	children.nebula = h(Halo, { size = math.min(props.width, props.height) * 1.25, color = Color3.fromRGB(120, 60, 30), transparency = 0.55, position = UDim2.fromOffset(centre.X, centre.Y), zIndex = 0 })
	for index = 1, 28 do
		local x = ((index * 0.6180339) % 1) * props.width
		local y = ((index * 0.7548776) % 1) * props.height
		children["star" .. index] = h("frame", {
			Size = UDim2.fromOffset(if index % 5 == 0 then 3 else 2, if index % 5 == 0 then 3 else 2),
			Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = if props.softMotion then 0.6 else clock:map(function(t) return 0.45 + 0.4 * math.sin(t * 0.8 + index) end),
			BorderSizePixel = 0,
			ZIndex = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	-- the orbit ring the ignite comet runs on, with a notch at the target
	local orbit = math.min(props.width, props.height) * 0.47
	local target = FoundryMath.targetPhase({ Radius = foundry.Radius, Pieces = foundry.Pieces })
	children.orbit = h("frame", {
		Size = UDim2.fromOffset(orbit * 2, orbit * 2),
		Position = UDim2.fromOffset(centre.X, centre.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = ACCENT, Thickness = 1, Transparency = 0.75 }))
	local tx, ty = math.cos(target * 2 * math.pi), math.sin(target * 2 * math.pi)
	children.notch = h("frame", {
		Size = UDim2.fromOffset(18, 4),
		Position = UDim2.fromOffset(centre.X + tx * orbit, centre.Y + ty * orbit),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = math.deg(target * 2 * math.pi),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	local function cometPoint(lag)
		return function()
			local phase = FoundryMath.wavePhase(foundry.IgniteAt or 0, workspace:GetServerTimeNow()) - lag
			local angle = phase * 2 * math.pi
			return UDim2.fromOffset(centre.X + math.cos(angle) * orbit, centre.Y + math.sin(angle) * orbit)
		end
	end
	for index = 0, 5 do
		local lag = index * 0.012
		children["comet" .. index] = h("frame", {
			Size = UDim2.fromOffset(10 - index * 1.4, 10 - index * 1.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = clock:map(cometPoint(lag)),
			BackgroundColor3 = if index == 0 then Palette.white else ACCENT,
			BackgroundTransparency = clock:map(function()
				local phase = FoundryMath.wavePhase(foundry.IgniteAt or 0, workspace:GetServerTimeNow())
				local hot = FoundryMath.onBeat(phase, target)
				return math.clamp((if hot then 0 else 0.15) + index * 0.15, 0, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 8,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	-- energy beams: a wide soft glow under a thin bright core, shading from source to target colour
	local drawn = 0
	for index, link in flow.Links do
		if drawn >= 80 then
			break
		end
		local q1, r1 = FoundryMath.parse(link.from)
		local q2, r2 = FoundryMath.parse(link.to)
		if q1 and q2 then
			drawn += 1
			local a = centre + hexPixel(q1, r1, size)
			local b = centre + hexPixel(q2, r2, size)
			local delta = b - a
			local strength = math.clamp(math.log10(1 + link.amount) / 4, 0.15, 1)
			local fromPiece, toPiece = foundry.Pieces[link.from], foundry.Pieces[link.to]
			local c1 = (fromPiece and KIND_LOOK[fromPiece.Kind] or KIND_LOOK.Ember).color
			local c2 = (toPiece and KIND_LOOK[toPiece.Kind] or KIND_LOOK.Ember).color
			local function beam(name, thickness, transparency, z)
				children[name .. index] = h("frame", {
					Size = UDim2.fromOffset(delta.Magnitude, thickness),
					Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = math.deg(math.atan2(delta.Y, delta.X)),
					BackgroundColor3 = Palette.white,
					BackgroundTransparency = transparency,
					BorderSizePixel = 0,
					ZIndex = z,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uigradient", { Color = ColorSequence.new(c1, c2) }))
			end
			beam("glow", 6 + strength * 10, 0.82 - strength * 0.12, 2)
			beam("core", 1.5 + strength * 2, 0.15, 3)
			if not props.softMotion then
				local speed = 0.7 + strength * 1.4
				local offset = (index * 0.37) % 1
				for tail = 0, 2 do
					children["pulse" .. index .. "_" .. tail] = h("frame", {
						Size = UDim2.fromOffset(7 - tail * 2, 7 - tail * 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = clock:map(function(t)
							local u = (t * speed + offset - tail * 0.04) % 1
							local p = a + delta * u
							return UDim2.fromOffset(p.X, p.Y)
						end),
						BackgroundColor3 = if tail == 0 then Palette.white else c2,
						BackgroundTransparency = tail * 0.3,
						BorderSizePixel = 0,
						ZIndex = 4,
					}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
				end
			end
		end
	end
	-- the lattice: a faint hexagon socket for every cell, pieces sitting in them
	for _, key in FoundryMath.cells(foundry.Radius) do
		local q, r = FoundryMath.parse(key)
		local p = centre + hexPixel(q, r, size)
		local piece = foundry.Pieces[key]
		local target = props.selected ~= nil and props.selected ~= key
		children["socket" .. key] = h(Hexagon, {
			radius = size * 0.94,
			color = if target and piece == nil then darken(ACCENT, 0.55) else Color3.fromRGB(28, 26, 38),
			transparency = if piece then 0.6 else 0.2,
			position = UDim2.fromOffset(p.X, p.Y),
			zIndex = 1,
		})
		children["cell" .. key] = h("textbutton", {
			Size = UDim2.fromOffset(size * 1.6, size * 1.6),
			Position = UDim2.fromOffset(p.X, p.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
			[React.Event.Activated] = function()
				props.onCell(key)
			end,
		}, piece and h(PieceFace, {
			piece = piece,
			size = math.floor(size * 1.25),
			selected = props.selected == key,
			lit = math.clamp(math.log10(1 + (flow.Lit[key] or 0)) / 3, 0, 1),
			showFacing = true,
			clock = if props.softMotion then nil else clock,
			zIndex = 5,
		}))
	end
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 7, 14),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), children)
end

local function Chip(props)
	return h("frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = darken(props.color, 0.78),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", { Color = props.color, Thickness = 1, Transparency = 0.55 }),
		h(Ui.Text, { value = props.label, size = 11, weight = Enum.FontWeight.Bold, color = props.color, position = UDim2.fromOffset(10, 6), sizeConstraint = UDim2.new(1, -20, 0, 14) }),
		h(Ui.Text, { value = props.value, size = 17, weight = Enum.FontWeight.Heavy, fit = true, minSize = 11, position = UDim2.fromOffset(10, 22), sizeConstraint = UDim2.new(1, -20, 0, 22) }))
end

local function FoundryView(props)
	local foundry = props.state.Foundry
	local softMotion = props.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local selected, setSelected = React.useState(nil)
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState("")
	local combo, setCombo = React.useState(0)
	local boardWidth, setBoardWidth = React.useState(if stack then viewport.width - 24 else math.max(320, viewport.width - 440))
	local sections = {}
	local function add(id, height, element)
		table.insert(sections, { id = id, height = height, element = element })
	end
	if type(foundry) ~= "table" then
		add("loading", 80, h(Ui.Text, { value = "Loading the Star Foundry…", size = 16, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }))
		return React.createElement(PageScaffold, { sections = sections, gap = GAP, tailPad = 72 })
	end
	local function act(payload, quiet)
		if busy and payload.Op ~= "ignite" then
			return
		end
		if payload.Op ~= "ignite" then
			setBusy(true)
		end
		props.dispatch("FoundryAct", payload, function(response)
			setBusy(false)
			if type(response) ~= "table" then
				return
			end
			if response.ok then
				Audio:play(response.Sound or "foundryPlace")
				if response.Combo ~= nil or payload.Op == "ignite" then
					setCombo(response.Combo or 0)
					-- a running Ignite combo is pinned to the island; a miss clears it
					local Juice = require(script.Parent.Parent.JuiceFx)
					if (response.Combo or 0) > 0 then
						Juice.live("foundryIgnite", { title = `IGNITE ×{response.Combo}`, icon = "Boost", color = ACCENT, endsAt = os.clock() + FoundryMath.IGNITE_PERIOD + 0.4, span = FoundryMath.IGNITE_PERIOD + 0.4, priority = 2 })
					else
						Juice.live("foundryIgnite", nil)
					end
				end
				if response.message and not quiet then
					setNote(response.message)
				end
			else
				Audio:play("error")
				setNote(response.error or "That move didn't work.")
			end
		end)
	end
	local function onCell(key)
		if selected == nil then
			if foundry.Pieces[key] ~= nil then
				Audio:play("foundryPickUp")
				setSelected(key)
			end
			return
		end
		if selected == key then
			-- double-tap a selected board piece to rotate it directly
			if string.sub(key, 1, 6) ~= "bench:" then
				act({ Op = "rotate", At = key }, true)
			else
				setSelected(nil)
			end
			return
		end
		local fromBench = string.sub(selected, 1, 6) == "bench:"
		act({ Op = if fromBench then "place" else "move", From = selected, To = key })
		setSelected(nil)
	end

	local flow = FoundryMath.flow({ Radius = foundry.Radius, Pieces = foundry.Pieces })
	local effects = foundry.Effects or {}
	local surgeLeft = math.max(0, (foundry.SurgeEndsAt or 0) - workspace:GetServerTimeNow())
	local dormant = (flow.Delivered or 0) <= 0

	-- hero: what the board is worth right now
	local chipW = if stack then UDim2.new(0.5, -6, 0, 50) else UDim2.new(0.25, -9, 0, 50)
	local chips = {
		{ "PRODUCTION", `×{compact(effects.Production or 1)}`, Color3.fromRGB(255, 196, 84) },
		{ "TAP", `×{compact(effects.Tap or 1)}`, Color3.fromRGB(255, 104, 112) },
		{ "CAPACITY", `×{compact(effects.Capacity or 1)}`, Color3.fromRGB(96, 220, 168) },
		{ "OFFLINE", `+{math.floor((effects.Offline or 0) * 100 + 0.5)}%`, Color3.fromRGB(176, 140, 255) },
	}
	local chipEls = {}
	for index, chip in chips do
		local col = if stack then (index - 1) % 2 else index - 1
		local row = if stack then (index - 1) // 2 else 0
		chipEls["chip" .. index] = h(Chip, {
			label = chip[1], value = chip[2], color = chip[3], size = chipW,
			position = if stack then UDim2.new(col * 0.5, col * 6, 0, 64 + row * 58) else UDim2.new((index - 1) * 0.25, (index - 1) * 3, 0, 64),
		})
	end
	add("hero", if stack then 186 else 128, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 16, accent = ACCENT, background = darken(ACCENT, 0.9) },
		h(Ui.Text, { value = "STAR FOUNDRY", size = 12, weight = Enum.FontWeight.Heavy, color = ACCENT, sizeConstraint = UDim2.new(1, 0, 0, 16) }),
		h(Ui.Text, {
			value = `{compact(foundry.Shards)} Shards  ·  ` .. (if dormant then "Dormant (rotate Ember to an Anvil)" else `+{string.format("%.1f", (foundry.ShardRate or 0) * 60)}/min`),
			size = if stack then 17 else 22, weight = Enum.FontWeight.Heavy, fit = true, minSize = 13,
			position = UDim2.fromOffset(0, 20), sizeConstraint = UDim2.new(1, 0, 0, 30),
		}),
		h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, chipEls)))

	-- the board
	local boardH = if stack then math.min(viewport.width - 24, 420) else 480
	local boardW = math.max(200, boardWidth)
	local cells = foundry.Radius * 2 + 1
	-- the lattice (and the orbit ring round it) fits the shorter side with a margin
	local cellSize = math.floor(math.min(boardW / (1.5 * cells + 0.6), boardH * 0.86 / (math.sqrt(3) * cells + 0.2)))
	add("board", boardH, h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[React.Change.AbsoluteSize] = function(frame)
			local measured = math.floor(frame.AbsoluteSize.X)
			if measured > 0 and math.abs(measured - boardWidth) > 2 then
				setBoardWidth(measured)
			end
		end,
	}, h(Board, {
		foundry = foundry, flow = flow, cellSize = cellSize, width = boardW, height = boardH,
		selected = selected, onCell = onCell, softMotion = softMotion,
	})))

	-- controls for a selected board piece
	if selected ~= nil and string.sub(selected, 1, 6) ~= "bench:" and foundry.Pieces[selected] then
		local piece = foundry.Pieces[selected]
		local look = KIND_LOOK[piece.Kind] or KIND_LOOK.Conduit
		local panelH = if stack then 96 else 64
		add("selected", panelH, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 12, accent = look.color, background = Palette.panel },
			if stack then
				h(React.Fragment, nil,
					h(Ui.Text, { value = `{look.name} · Tier {piece.Tier}`, size = 15, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, -44, 0, 18) }),
					h(Ui.Button, { text = "×", onClick = function() setSelected(nil) end, size = UDim2.fromOffset(36, 26), position = UDim2.new(1, -36, 0, -2), color = Palette.panelSoft, reducedMotion = softMotion }),
					h(Ui.Text, { value = look.line, size = 11, color = Palette.muted, position = UDim2.fromOffset(0, 18), sizeConstraint = UDim2.new(1, -44, 0, 14) }),
					h("frame", {
						Size = UDim2.new(1, 0, 0, 36),
						Position = UDim2.fromOffset(0, 38),
						BackgroundTransparency = 1,
					},
						h(Ui.Button, { text = "⟲ LEFT", onClick = function() act({ Op = "rotate", At = selected, Back = true }, true) end, size = UDim2.new(0.28, -4, 1, 0), position = UDim2.new(0, 0, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion }),
						h(Ui.Button, { text = "⟳ RIGHT", onClick = function() act({ Op = "rotate", At = selected }, true) end, size = UDim2.new(0.28, -4, 1, 0), position = UDim2.new(0.28, 0, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion }),
						h(Ui.Button, { text = "TO BENCH", onClick = function() act({ Op = "store", From = selected }, true); setSelected(nil) end, size = UDim2.new(0.44, 0, 1, 0), position = UDim2.new(0.56, 4, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion, disabled = #foundry.Bench >= FoundryMath.BENCH_CAP })
					))
			else
				h(React.Fragment, nil,
					h(Ui.Text, { value = `{look.name} · Tier {piece.Tier}`, size = 15, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, -330, 0, 20) }),
					h(Ui.Text, { value = look.line, size = 12, color = Palette.muted, position = UDim2.fromOffset(0, 22), sizeConstraint = UDim2.new(1, -330, 0, 16) }),
					h(Ui.Button, { text = "⟲", onClick = function() act({ Op = "rotate", At = selected, Back = true }, true) end, size = UDim2.fromOffset(56, 40), position = UDim2.new(1, -320, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion }),
					h(Ui.Button, { text = "⟳", onClick = function() act({ Op = "rotate", At = selected }, true) end, size = UDim2.fromOffset(56, 40), position = UDim2.new(1, -258, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion }),
					h(Ui.Button, { text = "TO BENCH", onClick = function() act({ Op = "store", From = selected }, true); setSelected(nil) end, size = UDim2.fromOffset(120, 40), position = UDim2.new(1, -196, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion, disabled = #foundry.Bench >= FoundryMath.BENCH_CAP }),
					h(Ui.Button, { text = "×", onClick = function() setSelected(nil) end, size = UDim2.fromOffset(64, 40), position = UDim2.new(1, -68, 0, 0), color = Palette.panelSoft, reducedMotion = softMotion })
				)
		))
	end

	-- actions: ignite, draw, expand (placed directly below board on mobile for instant visibility)
	local canDraw = foundry.Shards >= (foundry.DrawCost or math.huge) and #foundry.Bench < FoundryMath.BENCH_CAP
	local canExpand = foundry.ExpandCost ~= nil and foundry.Shards >= foundry.ExpandCost
	local buttonH = TapTarget
	local function renderActions()
		return h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
			h(Ui.Button, {
				text = if surgeLeft > 0 then `SURGE {math.ceil(surgeLeft)}s · IGNITE` else (if combo > 0 then `IGNITE · ×{combo}` else "IGNITE"),
				icon = "Boost", onClick = function() act({ Op = "ignite" }, true) end, color = ACCENT, textColor = Palette.ink, highlight = true,
				size = if stack then UDim2.new(1, 0, 0, buttonH) else UDim2.new(0.4, -8, 0, buttonH), position = UDim2.fromOffset(0, 0), reducedMotion = softMotion,
			}),
			h(Ui.Button, {
				text = if #foundry.Bench >= FoundryMath.BENCH_CAP then "BENCH FULL" else `DRAW · {compact(foundry.DrawCost or 0)}`,
				icon = "Crate", onClick = function() act({ Op = "draw" }) end, color = Palette.panelSoft, disabled = not canDraw or busy,
				size = if stack then UDim2.new(1, 0, 0, buttonH) else UDim2.new(0.3, -8, 0, buttonH),
				position = if stack then UDim2.fromOffset(0, buttonH + 10) else UDim2.new(0.4, 0, 0, 0), reducedMotion = softMotion,
			}),
			h(Ui.Button, {
				text = if foundry.ExpandCost == nil then "FULL SIZE" else `EXPAND · {compact(foundry.ExpandCost)}`,
				icon = "World", onClick = function() act({ Op = "expand" }) end, color = Palette.panelSoft, disabled = not canExpand or busy,
				size = if stack then UDim2.new(1, 0, 0, buttonH) else UDim2.new(0.3, -8, 0, buttonH),
				position = if stack then UDim2.fromOffset(0, (buttonH + 10) * 2) else UDim2.new(0.7, 0, 0, 0), reducedMotion = softMotion,
			}),
			not stack and h(Ui.Text, {
				value = "Ignite when the white hand crosses the gold marker. Ten on the beat in a row: a surge.",
				size = 12, color = Palette.muted, position = UDim2.fromOffset(0, buttonH + 8), sizeConstraint = UDim2.new(1, 0, 0, 16),
			}))
	end

	if stack then
		add("actions", buttonH * 3 + 20, renderActions())
	end

	-- the bench (centered with exact 5-gap math so slots hit 48-52px touch targets)
	local benchCols = 6
	local slotGap = 6
	local innerW = if stack then viewport.width - 24 else 380
	local slotSize = if stack then math.clamp(math.floor((innerW - (benchCols - 1) * slotGap) / benchCols), 44, 58) else 58
	local totalRowW = if stack then benchCols * slotSize + (benchCols - 1) * slotGap else benchCols * (58 + 6)
	local rowOffset = if stack then math.max(0, math.floor((innerW - totalRowW) / 2)) else 0
	local benchRows = if stack then 2 else 1
	local benchEls = {}
	for index = 1, FoundryMath.BENCH_CAP do
		local piece = foundry.Bench[index]
		local col = if stack then (index - 1) % benchCols else index - 1
		local row = if stack then (index - 1) // benchCols else 0
		local key = `bench:{index}`
		benchEls["slot" .. index] = h("textbutton", {
			Size = UDim2.fromOffset(slotSize, slotSize),
			Position = UDim2.fromOffset(rowOffset + col * (slotSize + slotGap), 24 + row * (slotSize + slotGap)),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = if piece then 0.6 else 0.3,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			[React.Event.Activated] = function()
				if piece == nil then
					if selected ~= nil and string.sub(selected, 1, 6) ~= "bench:" then
						act({ Op = "store", From = selected }, true)
						setSelected(nil)
					end
					return
				end
				Audio:play("foundryPickUp")
				setSelected(if selected == key then nil else key)
			end,
		}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", { Color = if selected == key then Palette.white else Palette.lineSoft, Thickness = if selected == key then 2 else 1, Transparency = 0.4 }),
			piece and h(PieceFace, { piece = piece, size = math.floor(slotSize * 0.82), selected = selected == key, zIndex = 2 }))
	end
	local benchH = 24 + benchRows * (slotSize + slotGap)
	add("bench", benchH, h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		h(Ui.Text, { value = `BENCH  ·  {#foundry.Bench}/{FoundryMath.BENCH_CAP}  ·  tap a piece, then a cell`, size = 12, weight = Enum.FontWeight.Bold, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 18) }),
		h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, benchEls)))

	if not stack then
		add("actions", buttonH + 30, renderActions())
	end
	if note ~= "" then
		add("note", 26, h(Ui.Text, { value = note, size = 14, color = Palette.creamSoft, sizeConstraint = UDim2.new(1, 0, 0, 22) }))
	end
	return React.createElement(PageScaffold, { sections = sections, gap = GAP, tailPad = 72, scrollBarColor = ACCENT })
end

return function()
	return { FoundryView = FoundryView }
end
