--!nonstrict
-- The Domain tree as a constellation: the Domain core in the middle, prerequisite depth as rings,
-- each root branch in its own sector. Bound nodes show their element's companion and send energy
-- along bound links; available nodes breathe; binding plays a burst and the companion's reveal.
-- Drag to pan, wheel or pinch to zoom, tap a node to inspect it. Same props as DomainHexStage.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local ui = require(script.Parent.UiCore)("ui")
local motion = require(script.Parent.MotionKit)("motion")
local theme = require(script.Parent.CoreKit)("theme")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local ElementFx = require(script.Parent.ElementFx).ElementFx
local Math = require(script.Parent.DomainConstellationMath)
local P = theme.Palette
local h = React.createElement

local ORB = 64
local MAX_PULSES = 18 -- energy dots on bound links, bounded for busy trees
local DRAG_SLOP = 6

local function Orb(props)
	local hovered, setHovered = React.useState(false)
	local style = props.style
	local accent = if props.owned then style.accent elseif props.available then style.accent else P.lineSoft
	local lift = motion.useFlipperSpring(if hovered or props.selected then 1 else 0, props.softMotion, 520, 40)
	local breathe = motion.usePulse(props.available and not props.owned and not props.softMotion, 1.1)
	local burst = motion.useFlash(if props.bound then props.boundToken else 0, props.softMotion, 0.9)
	return h("frame", {
		Name = props.node.Id, Size = UDim2.fromOffset(ORB + 40, ORB + 40),
		Position = UDim2.fromOffset(props.x, props.y), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, ZIndex = if props.selected then 30 else 20,
	}, {
		-- bind burst: a ring that races outward once
		Burst = h("frame", {
			Size = burst:map(function(v) return UDim2.fromOffset(ORB + (1 - v) * 90, ORB + (1 - v) * 90) end),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, ZIndex = 19,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = style.accent, Thickness = 3,
			Transparency = burst:map(function(v) return if v <= 0.001 then 1 else 1 - v end),
		})),
		-- availability ring: breathes until bound
		Ring = h("frame", {
			Size = UDim2.fromOffset(ORB + 14, ORB + 14), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, ZIndex = 20,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = accent, Thickness = if props.selected then 3 else 2,
			Transparency = if props.owned then 0.1 elseif props.available then breathe:map(function(v) return 0.15 + v * 0.55 end) else 0.7,
		})),
		Face = h("frame", {
			Size = UDim2.fromOffset(ORB, ORB), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if props.owned then theme.darken(style.accent, 0.72) else P.ink, BorderSizePixel = 0,
			ClipsDescendants = true, ZIndex = 21,
		}, {
			Corner = h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			Scale = h("uiscale", { Scale = lift:map(function(v) return 1 + v * 0.08 end) }),
			Glow = h("uigradient", {
				Color = ColorSequence.new(theme.lighten(accent, 0.1), P.ink),
				Transparency = NumberSequence.new(if props.owned then 0.35 else 0.85, 0.95),
				Rotation = 90,
			}),
			Companion = h(ElementFx, {
				element = style.element, size = UDim2.fromScale(0.92, 0.92), position = UDim2.fromScale(0.5, 0.52),
				still = not props.owned, transparency = if props.owned then 0 elseif props.available then 0.45 else 0.8,
				reducedMotion = props.softMotion, zIndex = 22,
				reaction = "reveal", reactionKey = props.owned,
			}),
		}),
		Hit = h("textbutton", {
			Name = "SelectNode", Size = UDim2.fromOffset(ORB + 12, ORB + 12), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
			Selectable = true, SelectionOrder = props.order, ZIndex = 32,
			Event = {
				Activated = function()
					if props.dragged() then return end
					Audio:play("tabSwitch")
					props.onSelect(props.node.Id)
				end,
				MouseEnter = function() setHovered(true) end,
				MouseLeave = function() setHovered(false) end,
				SelectionGained = function() setHovered(true); props.onSelect(props.node.Id) end,
				SelectionLost = function() setHovered(false) end,
			},
		}),
		Label = h(ui.Text, {
			value = props.node.Name, size = 12, color = if props.selected then P.cream else (if props.owned then P.creamSoft else P.muted),
			weight = Enum.FontWeight.Bold, align = Enum.TextXAlignment.Center, wrap = true,
			position = UDim2.new(0, -20, 1, -16), sizeConstraint = UDim2.new(1, 40, 0, 30), zIndex = 31,
		}),
	})
end

local function DomainConstellation(props)
	local layout = React.useMemo(function() return Math.build(props.tree) end, { props.tree })
	local viewW, viewH = props.size.X.Offset, props.size.Y.Offset
	local zoom, setZoom = React.useBinding(math.max(Math.READABLE_ZOOM, Math.fitZoom(layout, viewW, viewH - 56)))
	local pan, setPan = React.useBinding(Vector2.zero)
	local hostRef = React.useRef(nil)
	local drag = React.useRef({ active = false, origin = Vector2.zero, start = Vector2.zero, moved = false })
	local live = not props.softMotion
	local clock = motion.useClock(live, 0.35, 1)
	-- the how-to hint is for first look only: it fades once you've panned or zoomed
	local learned, setLearned = React.useState(false)
	local hintFade = motion.useFlipperSpring(if learned then 1 else 0, props.softMotion, 260, 30)
	local function zoomBy(factor)
		setLearned(true)
		setZoom(math.clamp(zoom:getValue() * factor, 0.35, 1.8))
	end
	local function fit()
		setZoom(Math.fitZoom(layout, viewW, viewH - 56))
		setPan(Vector2.zero)
	end
	-- pan with a drag, zoom with the wheel or a pinch; taps that moved past the slop don't select
	React.useEffect(function()
		local connections = {}
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			local state = drag.current
			if state.active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - state.start
				if delta.Magnitude > DRAG_SLOP then state.moved = true end
				local limit = layout.radius * zoom:getValue()
				setPan(Vector2.new(math.clamp(state.origin.X + delta.X, -limit, limit), math.clamp(state.origin.Y + delta.Y, -limit, limit)))
			end
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag.current.active = false
				task.defer(function() drag.current.moved = false end)
			end
		end))
		table.insert(connections, UserInputService.TouchPinch:Connect(function(_, scale, _, state)
			local host = hostRef.current
			if host == nil or host.Parent == nil or state ~= Enum.UserInputState.Change then return end
			setZoom(math.clamp(zoom:getValue() * (1 + (scale - 1) * 0.08), 0.35, 1.8))
		end))
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { layout })
	-- the stage owns its geometry: the layout guard and global motion leave it alone
	React.useEffect(function()
		local host = hostRef.current
		if host then
			host:SetAttribute("LayoutGuardIgnore", true)
			host:SetAttribute("NoMotion", true)
		end
	end, {})
	-- keep the selected node in view
	React.useEffect(function()
		local placed = layout.positions[props.focusId]
		if placed then
			local z = zoom:getValue()
			setPan(Vector2.new(-placed.x * z, -placed.y * z))
		end
	end, { props.focusId })

	local path = {}
	local function visit(id)
		if path[id] then return end
		path[id] = true
		local node = nil
		for _, candidate in props.tree do if candidate.Id == id then node = candidate end end
		for _, parent in (node and node.Requires) or {} do visit(parent) end
	end
	if props.focusId then visit(props.focusId) end

	local content = {}
	-- depth rings
	for ring = 1, layout.rings do
		local radius = Math.CORE_RADIUS + ring * Math.RING_GAP
		content["ring" .. ring] = h("frame", {
			Size = UDim2.fromOffset(radius * 2, radius * 2), Position = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, ZIndex = 2,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = P.lineSoft, Thickness = 1, Transparency = 0.82 }))
	end
	-- the Domain core
	content.Core = h("frame", {
		Size = UDim2.fromOffset(96, 96), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = P.panelRaised, BorderSizePixel = 0, ZIndex = 25,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", { Color = P.violet, Thickness = 2 }),
		h("uigradient", { Color = ColorSequence.new(theme.lighten(P.violet, 0.2), P.ink), Rotation = 90 }),
		h(ui.Text, { value = props.coreLabel or "DOMAIN", size = 13, color = P.cream, weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center, sizeConstraint = UDim2.fromScale(1, 1), zIndex = 26 }))
	-- links: a soft glow under a crisp core; bound links carry travelling energy
	local pulses = 0
	for _, node in props.tree do
		local placed = layout.positions[node.Id]
		local parents = node.Requires or {}
		local origins = {}
		if #parents == 0 then
			table.insert(origins, { id = "core", x = 0, y = 0, owned = true })
		else
			for _, parent in parents do
				local from = layout.positions[parent]
				if from then table.insert(origins, { id = parent, x = from.x, y = from.y, owned = props.owned[parent] == true }) end
			end
		end
		local style = props.styleFor(node)
		for _, origin in origins do
			local dx, dy = placed.x - origin.x, placed.y - origin.y
			local length = math.sqrt(dx * dx + dy * dy)
			local bound = origin.owned and props.owned[node.Id] == true
			local onPath = path[node.Id] and (origin.id == "core" or path[origin.id])
			local color = if onPath then P.cyan elseif bound then style.accent elseif origin.owned then theme.darken(style.accent, 0.35) else P.lineSoft
			local key = origin.id .. ">" .. node.Id
			local mid = UDim2.fromOffset((origin.x + placed.x) / 2, (origin.y + placed.y) / 2)
			local rotation = math.deg(math.atan2(dy, dx))
			content["glow" .. key] = h("frame", {
				Size = UDim2.fromOffset(length, if bound or onPath then 8 else 4), Position = mid, AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = rotation, BackgroundColor3 = color, BackgroundTransparency = if bound or onPath then 0.8 else 0.92,
				BorderSizePixel = 0, ZIndex = 5,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
			content["link" .. key] = h("frame", {
				Size = UDim2.fromOffset(length, if bound or onPath then 2 else 1), Position = mid, AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = rotation, BackgroundColor3 = color, BackgroundTransparency = if bound or onPath then 0.05 else 0.55,
				BorderSizePixel = 0, ZIndex = 6,
			})
			if bound and live and pulses < MAX_PULSES then
				pulses += 1
				local offset = (pulses * 0.37) % 1
				content["pulse" .. key] = h("frame", {
					Size = UDim2.fromOffset(7, 7), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = theme.lighten(style.accent, 0.5),
					BorderSizePixel = 0, ZIndex = 7,
					Position = clock:map(function(t)
						local u = (t + offset) % 1
						return UDim2.fromOffset(origin.x + dx * u, origin.y + dy * u)
					end),
					BackgroundTransparency = clock:map(function(t)
						local u = (t + offset) % 1
						return 0.1 + math.abs(u - 0.5) * 1.2
					end),
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
			end
		end
	end
	for order, node in props.tree do
		local placed = layout.positions[node.Id]
		local available = true
		for _, parent in node.Requires or {} do
			if not props.owned[parent] then available = false end
		end
		content[node.Id] = h(Orb, {
			node = node, x = placed.x, y = placed.y, order = order, style = props.styleFor(node),
			owned = props.owned[node.Id] == true, available = available, selected = props.focusId == node.Id,
			softMotion = props.softMotion, onSelect = props.onSelect, bound = props.boundId == node.Id, boundToken = props.boundToken,
			dragged = function() return drag.current.moved end,
		})
	end

	return h("frame", {
		Name = "DomainConstellation", ref = hostRef, Size = props.size, Position = props.position,
		BackgroundColor3 = P.ink, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 705, Active = true,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag.current = { active = true, origin = pan:getValue(), start = Vector2.new(input.Position.X, input.Position.Y), moved = false }
				setLearned(true)
			end
		end,
		[React.Event.InputChanged] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				zoomBy(if input.Position.Z > 0 then 1.12 else 1 / 1.12)
			end
		end,
	}, {
		Corner = h("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Backdrop = h("uigradient", { Color = ColorSequence.new(theme.darken(P.violet, 0.82), P.ink), Rotation = 90 }),
		Stage = h("frame", {
			Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 706,
			Position = pan:map(function(offset) return UDim2.new(0.5, offset.X, 0.5, offset.Y - 24) end),
		}, {
			Scale = h("uiscale", { Scale = zoom }),
			Content = h("frame", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, content),
		}),
		ZoomOut = h(ui.Button, { text = "−", onClick = function() zoomBy(1 / 1.2) end, size = UDim2.fromOffset(48, 48),
			position = UDim2.new(0, 8, 1, -54), outline = true, color = P.cyan, reducedMotion = props.softMotion, zIndex = 720 }),
		Fit = h(ui.Button, { text = "FIT", onClick = fit, size = UDim2.fromOffset(76, 48), position = UDim2.new(0, 64, 1, -54),
			outline = true, color = P.cyan, reducedMotion = props.softMotion, zIndex = 720 }),
		ZoomIn = h(ui.Button, { text = "+", onClick = function() zoomBy(1.2) end, size = UDim2.fromOffset(48, 48),
			position = UDim2.new(0, 148, 1, -54), outline = true, color = P.cyan, reducedMotion = props.softMotion, zIndex = 720 }),
		-- on a dark pill so it stays readable over nodes and links
		Hint = h("frame", {
			Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14),
			BackgroundColor3 = P.ink, BackgroundTransparency = hintFade:map(function(a) return 0.15 + 0.85 * math.clamp(a, 0, 1) end),
			BorderSizePixel = 0, ZIndex = 719, Visible = hintFade:map(function(a) return a < 0.99 end),
		}, {
			Corner = h("uicorner", { CornerRadius = UDim.new(1, 0) }),
			Pad = h("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
			Label = h("textlabel", {
				Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 720,
				Text = "Drag to look around · scroll or pinch to zoom", TextSize = 12, TextColor3 = P.creamSoft,
				TextTransparency = hintFade:map(function(a) return math.clamp(a, 0, 1) end),
				FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
			}),
		}),
	})
end

return { DomainConstellation = DomainConstellation }
