--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("UiOverlays: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("UiOverlays: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["DomainChamber"] = function()
-- The Domain, one screen: the lattice on the left, and on the right whatever you're doing with it.
--   mode "lattice": etch links between anchors, read what the lattice gives, clear it once per rank
--   mode "confirm": the expansion rite; hold to expand, with what it costs, keeps and pays
--   mode "result":  a ring of heat leaves the Hearth, the new rank lands and the rewards count in
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.CoreKit)("format").compactNumber
local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local GameConfig = require(shared:WaitForChild("GameConfig"))
local DomainLattice = require(shared:WaitForChild("DomainLattice"))

local h = React.createElement
local WHITE_HOT = Color3.fromRGB(255, 244, 222)
local HOLD_SECONDS = 1.1
local SCALE = 0.5 / 2.2
local KIND_COLOR = {
	Production = Palette.mango, Capacity = Palette.cyan, Tap = Palette.coral, RebirthYield = Palette.violet,
	Critical = Palette.pink, EchoCharge = Palette.mint, ContinuumDiscount = Palette.mango, Offline = Palette.cyan,
	Luck = Palette.mint, WorldDiscount = Palette.violet, EssenceGain = Palette.pink, ForgePathXP = Palette.mango,
	CommandXP = Palette.coral,
}
local KEEPS = "Research, relics, Stardust, milestones, your crew and guild"
local RESETS = "Machines, Flux, the vault, worlds, and the rebirths and Cores you spend"

local function easeOut(t)
	local u = 1 - math.clamp(t, 0, 1)
	return 1 - u * u * u
end
local function asNumber(value)
	local n = tonumber(value)
	return if n ~= nil and n == n then n else 0
end
local function spot(index)
	local x, y = DomainLattice.position(index)
	return 0.5 + x * SCALE, 0.5 + y * SCALE
end
local function colorOf(index)
	local anchor = DomainLattice.ANCHORS[index]
	return (anchor and KIND_COLOR[anchor.kind]) or Palette.mango
end
local function splitKey(key)
	local a, b = string.match(key, "^(%d+)%-(%d+)$")
	return tonumber(a), tonumber(b)
end
-- a line between two points of the square canvas, drawn `p` of the way from the first
local function line(x1, y1, x2, y2, thickness, p)
	local dx, dy = (x2 - x1) * p, (y2 - y1) * p
	local length = math.sqrt(dx * dx + dy * dy)
	return UDim2.new(length, 0, 0, thickness), UDim2.fromScale(x1 + dx / 2, y1 + dy / 2), math.deg(math.atan2(y2 - y1, x2 - x1))
end
local function surgeLabel()
	local boost = GameConfig.Boosts and GameConfig.Boosts[GameConfig.Domain.SurgeBoostId or "DomainSurge"]
	if boost == nil then
		return "Domain Surge"
	end
	local minutes = math.floor((tonumber(boost.Duration) or 1800) / 60 + 0.5)
	return `Domain Surge for {minutes} min`
end

-- what etching a link would change, for the preview
local function etchPreview(links, key)
	local a, b = splitKey(key)
	local degree = DomainLattice.degrees(links)
	local lines = {}
	for _, index in { a, b } do
		local anchor = DomainLattice.ANCHORS[index]
		local d = degree[index] or 0
		local gain = DomainLattice.anchorBonus(index, d + 1) - DomainLattice.anchorBonus(index, d)
		table.insert(lines, { color = colorOf(index), text = `{anchor.name}: {DomainLattice.describe(anchor.kind, gain)}` })
	end
	local after = table.clone(links)
	after[key] = true
	local closes = #DomainLattice.facets(after) - #DomainLattice.facets(links)
	if closes > 0 then
		table.insert(lines, { color = Palette.mango, text = `Closes {if closes == 1 then "a facet" else closes .. " facets"}: {DomainLattice.describe("Production", closes * DomainLattice.FACET_PRODUCTION)}` })
	end
	return lines
end

local function Lattice(props)
	local links, tick, selected = props.links, props.tick, props.selected
	local degree = DomainLattice.degrees(links)
	local facetSet = {}
	for _, index in DomainLattice.facets(links) do
		facetSet[index] = true
	end
	local reached = { [DomainLattice.HEARTH] = true }
	for index, d in degree do
		if d > 0 then
			reached[index] = true
		end
	end
	local children = {}
	-- the figure's guide rings, faint like a drafting sheet
	for ring, radius in { 1, 1.92 } do
		local s = radius * SCALE * 2
		children["guide" .. ring] = h("frame", {
			Size = UDim2.fromScale(s, s),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = Palette.line,
			Thickness = 1,
			Transparency = 0.55,
		}))
	end
	-- the heat ring that leaves the Hearth when a rank lands
	children.flare = h("frame", {
		Size = props.flare:map(function(f)
			local s = easeOut(f) * 1.3
			return UDim2.fromScale(s, s)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = props.flare:map(function(f)
			return f > 0.001 and f < 1
		end),
		ZIndex = 9,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = WHITE_HOT,
		Thickness = props.flare:map(function(f)
			return 2 + (1 - f) * 10
		end),
		Transparency = props.flare:map(function(f)
			return f
		end),
	}))
	for _, e in DomainLattice.EDGES do
		local x1, y1 = spot(e.a)
		local x2, y2 = spot(e.b)
		local etched = links[e.key] == true
		local open = not etched and (reached[e.a] or reached[e.b])
		local picked = selected ~= nil and selected.kind == "link" and selected.id == e.key
		if etched then
			-- molten: a glow, a hot core drawing itself in from the Hearth's side, and a beat running outward
			local key = e.key
			local function drawn(now)
				local at = props.etchedAt[key]
				return if at == nil then 1 else easeOut((now - at) / 0.42)
			end
			local _, _, rot = line(x1, y1, x2, y2, 10, 1)
			children["glow" .. key] = h("frame", {
				Size = tick:map(function(now)
					return (line(x1, y1, x2, y2, 10, drawn(now)))
				end),
				Position = tick:map(function(now)
					local _, pos = line(x1, y1, x2, y2, 10, drawn(now))
					return pos
				end),
				Rotation = rot,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.ember,
				BackgroundTransparency = 0.78,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
			children["core" .. key] = h("frame", {
				Size = tick:map(function(now)
					return (line(x1, y1, x2, y2, 3, drawn(now)))
				end),
				Position = tick:map(function(now)
					local _, pos = line(x1, y1, x2, y2, 3, drawn(now))
					return pos
				end),
				Rotation = rot,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.white,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, h("uigradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Palette.mango),
					ColorSequenceKeypoint.new(0.5, WHITE_HOT),
					ColorSequenceKeypoint.new(1, Palette.mango),
				}),
				Offset = tick:map(function(now)
					return Vector2.new(math.sin(now * 1.3 + e.a) * 0.4, 0)
				end),
			}))
			if not props.reduced then
				local phase = (e.a * 0.37 + e.b * 0.21) % 1
				children["beat" .. key] = h("frame", {
					Size = UDim2.fromOffset(5, 5),
					Position = tick:map(function(now)
						local p = (now * 0.55 + phase) % 1
						return UDim2.fromScale(x1 + (x2 - x1) * p, y1 + (y2 - y1) * p)
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = WHITE_HOT,
					BackgroundTransparency = tick:map(function(now)
						return if drawn(now) < 1 then 1 else 0.1
					end),
					BorderSizePixel = 0,
					ZIndex = 5,
				}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
			end
		else
			local size, pos, rot = line(x1, y1, x2, y2, if open then (if picked then 3 else 2) else 1, 1)
			children["line" .. e.key] = h("frame", {
				Size = size,
				Position = pos,
				Rotation = rot,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if picked then WHITE_HOT elseif open then Palette.mango else Palette.lineSoft,
				BackgroundTransparency = if picked then 0 elseif open then tick:map(function(now)
					return 0.35 + (math.sin(now * 3 + e.a + e.b) + 1) * 0.2
				end) else 0.55,
				BorderSizePixel = 0,
				ZIndex = 3,
			})
			if open then
				local hitSize, hitPos = line(x1, y1, x2, y2, 22, 0.7)
				children["hit" .. e.key] = h("textbutton", {
					Size = hitSize,
					Position = hitPos,
					Rotation = rot,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 6,
					Event = {
						Activated = function()
							props.onLink(e.key)
						end,
					},
				})
			end
		end
	end
	-- facets: a lit mark in the middle of every closed triangle
	for index, t in DomainLattice.TRIANGLES do
		if facetSet[index] then
			local cx, cy = 0, 0
			for _, corner in t do
				local x, y = spot(corner)
				cx += x / 3
				cy += y / 3
			end
			children["facet" .. index] = h("frame", {
				Size = UDim2.fromOffset(9, 9),
				Position = UDim2.fromScale(cx, cy),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = Palette.mango,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, h("uiscale", {
				Scale = tick:map(function(now)
					local at = props.facetAt[index]
					local pop = if at == nil then 0 else 1 - easeOut((now - at) / 0.4)
					return 1 + pop * 1.6 + math.sin(now * 2 + index) * 0.08
				end),
			}), h("uistroke", { Color = WHITE_HOT, Thickness = 1, Transparency = 0.3 }))
		end
	end
	-- the anchors: a cut stone, filled as its links are etched, with a pip for every link it can take
	for _, anchor in DomainLattice.ANCHORS do
		local index = anchor.index
		local x, y = spot(index)
		local color = KIND_COLOR[anchor.kind] or Palette.mango
		local d = degree[index] or 0
		local maxD = DomainLattice.maxDegree(index)
		local fill = d / math.max(1, maxD)
		local isHearth = index == DomainLattice.HEARTH
		local stone = if isHearth then 34 else 24
		local picked = selected ~= nil and selected.kind == "anchor" and selected.id == index
		local pips = {}
		for pip = 1, maxD do
			local a = math.rad(-90 + (pip - 1) * 360 / maxD)
			local r = if isHearth then 0.5 else 0.42
			pips["p" .. pip] = h("frame", {
				Size = UDim2.fromOffset(4, 4),
				Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if pip <= d then color else Palette.lineSoft,
				BackgroundTransparency = if pip <= d then 0 else 0.4,
				BorderSizePixel = 0,
				ZIndex = 8,
			}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
		children["anchor" .. index] = h("textbutton", {
			ref = function(instance)
				props.anchorRefs[index] = instance
			end,
			Size = UDim2.fromOffset(if isHearth then 64 else 50, if isHearth then 64 else 50),
			Position = UDim2.fromScale(x, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 7,
			Event = {
				Activated = function()
					props.onAnchor(index)
				end,
			},
		}, h("frame", {
			Size = UDim2.fromOffset(stone, stone),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = darken(color, 0.62),
			BorderSizePixel = 0,
			ZIndex = 8,
		}, h("uicorner", { CornerRadius = UDim.new(0, 4) }), h("uistroke", {
			Color = if picked then WHITE_HOT else color,
			Thickness = if picked then 2.5 else 1.5,
			Transparency = if d > 0 or isHearth then 0 else 0.45,
		}), h("frame", {
			Size = UDim2.fromScale(0.22 + fill * 0.62, 0.22 + fill * 0.62),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if fill >= 1 then WHITE_HOT else color,
			BackgroundTransparency = if d > 0 or isHearth then 0 else 0.7,
			BorderSizePixel = 0,
			ZIndex = 9,
		}, h("uicorner", { CornerRadius = UDim.new(0, 2) }))), h("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, pips), picked and h("frame", {
			-- a bracket that turns slowly around the picked anchor
			Size = UDim2.fromScale(1.05, 1.05),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = tick:map(function(now)
				return (now * 40) % 360
			end),
			BackgroundTransparency = 1,
			ZIndex = 7,
		}, h("uistroke", { Color = WHITE_HOT, Thickness = 1, Transparency = 0.35 })), h("textlabel", {
			Size = UDim2.fromOffset(110, 14),
			Position = UDim2.new(0.5, 0, 1, if isHearth then 0 else -2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Text = anchor.name,
			TextSize = if isHearth then 13 else 11,
			FontFace = Font.fromEnum(if isHearth then Enum.Font.BuilderSansExtraBold else Enum.Font.BuilderSansBold),
			TextColor3 = if d > 0 or isHearth then Palette.cream else Palette.muted,
			ZIndex = 9,
		}))
	end
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, h("uiaspectratioconstraint", { AspectRatio = 1 }), children)
end

local function Row(props)
	return h("frame", {
		Size = UDim2.new(1, 0, 0, props.height or 22),
		LayoutOrder = props.order,
		BackgroundTransparency = 1,
		ZIndex = 32,
	}, h("textlabel", {
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Text = props.label,
		TextSize = props.size or 13,
		TextWrapped = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextColor3 = props.labelColor or Palette.creamSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = props.fade or 0,
		ZIndex = 33,
	}), props.value ~= nil and h("textlabel", {
		Size = UDim2.new(0, 110, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = props.value,
		TextSize = props.size or 13,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextColor3 = props.valueColor or Palette.cream,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = props.fade or 0,
		ZIndex = 33,
	}))
end

local function Heading(props)
	return h("textlabel", {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = props.order,
		BackgroundTransparency = 1,
		Text = props.text,
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextColor3 = props.color or Palette.mango,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	})
end

local function DomainChamber(props)
	local domain = props.domain or {}
	local mode = props.mode
	local rank = math.max(0, math.floor(asNumber(domain.Rank)))
	if rank < 1 and mode == "lattice" then
		mode = "confirm"
	end
	local viewport = useViewport()
	local stacked = viewport.width < 760 or viewport.width < viewport.height
	local reduced = props.reducedMotion == true
	local tick, setTick = React.useBinding(os.clock())
	local flare, setFlare = React.useBinding(0)
	local hold, setHold = React.useBinding(0)
	local selected, setSelected = React.useState(nil)
	local override, setOverride = React.useState(nil)
	local note, setNote = React.useState(nil)
	local etchedAt = React.useRef({})
	local facetAt = React.useRef({})
	local anchorRefs = React.useRef({})
	local resultAt = React.useRef(0)
	local holding = React.useRef(nil)
	local fired = React.useRef(false)
	local requesting = React.useRef(false)

	React.useEffect(function()
		setOverride(nil)
	end, { domain.Links, domain.SkillPoints })
	local links = if override then override.links else (if type(domain.Links) == "table" then domain.Links else {})
	local points = if override then override.points else math.floor(asNumber(domain.SkillPoints))
	local etched = DomainLattice.count(links)
	local nextCost = DomainLattice.linkCost(etched)
	local canClear = rank >= 1 and etched > 0 and asNumber(domain.LatticeClearedAtRank) < rank

	React.useEffect(function()
		if mode == "result" then
			resultAt.current = os.clock()
			Audio:play("domainImpact")
		elseif mode == "confirm" then
			Audio:play("open")
		end
		fired.current = false
		holding.current = nil
		setHold(0)
	end, { mode })

	-- one clock drives everything on screen, plus the hold and the result's flare
	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			setTick(now)
			if mode == "result" then
				setFlare(math.clamp((now - resultAt.current) / 1.1, 0, 1))
			else
				setFlare(0)
			end
			local startedAt = holding.current
			if startedAt ~= nil and not fired.current then
				local p = math.clamp((now - startedAt) / HOLD_SECONDS, 0, 1)
				setHold(p)
				if p >= 1 then
					fired.current = true
					holding.current = nil
					Audio:play("domainCrack")
					props.onConfirm()
				end
			elseif startedAt == nil and not fired.current then
				setHold(0)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { mode, props.onConfirm })

	-- a controller lands on the chamber's own buttons whenever the mode changes
	local actionsRef = React.useRef(nil)
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local job = task.defer(function()
			local host = actionsRef.current
			if host ~= nil and host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { mode })

	-- Escape backs out: the rite returns to the lattice, the lattice closes
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.ButtonB then
				return
			end
			if mode == "confirm" and rank >= 1 then
				props.onMode("lattice")
			elseif mode ~= "result" then
				props.onClose()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { mode, rank })

	local function burstAt(index, color, scale)
		if reduced then
			return
		end
		local instance = anchorRefs.current[index]
		if instance ~= nil and instance.Parent ~= nil then
			pcall(function()
				require(script.Parent.JuiceFx).burst(instance.AbsolutePosition + instance.AbsoluteSize / 2, color, scale)
			end)
		end
	end

	local function etch(key)
		if requesting.current then
			return
		end
		local a, b = splitKey(key)
		local ok, reason = DomainLattice.canEtch(links, a, b, points)
		if not ok then
			setNote(reason)
			Audio:play("locked")
			return
		end
		requesting.current = true
		local before = DomainLattice.facets(links)
		props.dispatch("DomainLattice", { Op = "Etch", A = a, B = b }, function(response)
			requesting.current = false
			if not response.ok or type(response.Links) ~= "table" then
				setNote(response.message or "That link didn't take.")
				Audio:play("locked")
				return
			end
			local now = os.clock()
			etchedAt.current[key] = now
			local was = {}
			for _, index in before do
				was[index] = true
			end
			for _, index in DomainLattice.facets(response.Links) do
				if not was[index] then
					facetAt.current[index] = now + 0.3
				end
			end
			setOverride({ links = response.Links, points = math.floor(asNumber(response.SkillPoints)) })
			setNote(nil)
			setSelected({ kind = "anchor", id = b })
			Audio:play(if response.ClosedFacet then "domainImpact" else "domainBind")
			task.delay(0.36, function()
				burstAt(b, colorOf(b), if response.ClosedFacet then 1.2 else 0.8)
			end)
		end)
	end
	local function clear()
		if requesting.current or not canClear then
			return
		end
		requesting.current = true
		props.dispatch("DomainLattice", { Op = "Clear" }, function(response)
			requesting.current = false
			if response.ok and type(response.Links) == "table" then
				etchedAt.current = {}
				facetAt.current = {}
				setOverride({ links = response.Links, points = math.floor(asNumber(response.SkillPoints)) })
				setSelected(nil)
				Audio:play("domainReward")
			else
				setNote(response.message or "Couldn't clear the lattice.")
			end
		end)
	end
	local onLink = function(key)
		if selected ~= nil and selected.kind == "link" and selected.id == key then
			etch(key)
		else
			Audio:play("tick")
			setNote(nil)
			setSelected({ kind = "link", id = key })
		end
	end
	local onAnchor = function(index)
		Audio:play("tick")
		setNote(nil)
		setSelected({ kind = "anchor", id = index })
	end

	-- the side panel
	local rows = {}
	local order = 0
	local function add(element)
		order += 1
		rows["r" .. order] = element
		return order
	end
	local function heading(text, color)
		add(h(Heading, { text = text, color = color, order = order + 1 }))
	end
	local function row(label, value, extra)
		local r = extra or {}
		r.label, r.value, r.order = label, value, order + 1
		add(h(Row, r))
	end
	local function gap(px)
		add(h("frame", { Size = UDim2.new(1, 0, 0, px), BackgroundTransparency = 1, LayoutOrder = order + 1 }))
	end

	local panelTitle, panelNumber
	local actions = {}
	if mode == "lattice" then
		panelTitle, panelNumber = "DOMAIN", tostring(rank)
		row("Production from your domain", `x{string.format("%.2f", asNumber(domain.ProductionMultiplier))}`, { valueColor = Palette.mango })
		row("Domain points", tostring(points), { valueColor = if points > 0 then Palette.mango else Palette.cream })
		row("Next link costs", if nextCost == 1 then "1 point" else `{nextCost} points`)
		gap(6)
		if selected ~= nil and selected.kind == "link" and links[selected.id] ~= true then
			local a, b = splitKey(selected.id)
			heading(`ETCH {string.upper(DomainLattice.ANCHORS[a].name)} TO {string.upper(DomainLattice.ANCHORS[b].name)}`)
			for _, preview in etchPreview(links, selected.id) do
				row(preview.text, nil, { labelColor = preview.color })
			end
			local ok, reason = DomainLattice.canEtch(links, a, b, points)
			table.insert(actions, {
				text = if ok then (if nextCost == 1 then "Etch for 1 point" else `Etch for {nextCost} points`) else (reason or "Can't etch"),
				primary = true,
				disabled = not ok,
				onClick = function()
					etch(selected.id)
				end,
			})
		elseif selected ~= nil and selected.kind == "anchor" then
			local anchor = DomainLattice.ANCHORS[selected.id]
			local d = DomainLattice.degrees(links)[anchor.index] or 0
			local maxD = DomainLattice.maxDegree(anchor.index)
			heading(string.upper(anchor.name), KIND_COLOR[anchor.kind])
			row("Gives now", DomainLattice.describe(anchor.kind, DomainLattice.anchorBonus(anchor.index, d)), { valueColor = KIND_COLOR[anchor.kind] })
			row("Links", `{d} of {maxD}`)
			row("With every link etched", DomainLattice.describe(anchor.kind, anchor.full))
			if anchor.index == DomainLattice.HEARTH then
				gap(4)
				row("Every closed triangle in the lattice adds " .. DomainLattice.describe("Production", DomainLattice.FACET_PRODUCTION) .. ".", nil, { height = 36, size = 12, labelColor = Palette.muted })
			end
		else
			heading("WHAT YOUR LATTICE GIVES")
			local any = false
			for _, anchor in DomainLattice.ANCHORS do
				local total = DomainLattice.bonus(links, anchor.kind)
				if total > 0 and (anchor.kind ~= "Production" or anchor.index == DomainLattice.HEARTH) then
					any = true
					row(DomainLattice.describe(anchor.kind, total), nil, { labelColor = KIND_COLOR[anchor.kind] })
				end
			end
			local facets = #DomainLattice.facets(links)
			if facets > 0 then
				row(`{facets} closed {if facets == 1 then "facet" else "facets"}`, nil, { labelColor = Palette.muted, size = 12 })
			end
			if not any then
				row("Tap a glowing line next to the Hearth to start. Links grow outward from it.", nil, { height = 40, labelColor = Palette.muted })
			end
		end
		if note ~= nil then
			gap(4)
			row(note, nil, { labelColor = Palette.coral, height = 30, size = 12 })
		end
		if domain.CanExpand == true then
			table.insert(actions, {
				text = `Expand to Domain {rank + 1}`,
				primary = #actions == 0,
				onClick = function()
					props.onMode("confirm")
				end,
			})
		end
		table.insert(actions, {
			text = if canClear then `Clear lattice (refunds {DomainLattice.spent(etched)})` elseif etched > 0 then "Cleared this rank" else "Clear lattice",
			quiet = true,
			disabled = not canClear,
			onClick = clear,
		})
	elseif mode == "confirm" then
		panelTitle, panelNumber = "EXPAND TO DOMAIN", tostring(rank + 1)
		local needR, needC = asNumber(domain.RequiredRebirths), asNumber(domain.RequiredCores)
		local haveR, haveC = asNumber(props.rebirths), asNumber(props.cores)
		heading("IT TAKES")
		row("Rebirths", `{compactNumber(haveR)} / {compactNumber(needR)}`, { valueColor = if haveR >= needR then Palette.mint else Palette.coral })
		row("Cores", `{compactNumber(haveC)} / {compactNumber(needC)}`, { valueColor = if haveC >= needC then Palette.mint else Palette.coral })
		gap(6)
		heading("YOU GET")
		row("Domain essence", `+{compactNumber(asNumber(domain.EssenceReward))}`, { valueColor = Palette.pink })
		row("Stardust (more for every extra rebirth)", `+{compactNumber(asNumber(domain.StardustReward))}`, { valueColor = Palette.cyan, size = 12 })
		row("Domain points", `+{GameConfig.Domain.SkillPointPerRank or 2}`, { valueColor = Palette.mango })
		row("Wheel spins", `+{(GameConfig.Domain.Expansion and GameConfig.Domain.Expansion.FreeSpins) or 3}`)
		row(surgeLabel(), nil, { labelColor = Palette.mango })
		gap(6)
		row("Keeps: " .. KEEPS .. ".", nil, { height = 34, size = 12, labelColor = Palette.mint })
		row("Resets: " .. RESETS .. ".", nil, { height = 34, size = 12, labelColor = Palette.coral })
		table.insert(actions, {
			text = if domain.CanExpand == true then (if props.busy then "Expanding…" else "Hold to expand") else "Not ready yet",
			primary = true,
			hold = domain.CanExpand == true and not props.busy,
			disabled = domain.CanExpand ~= true or props.busy,
		})
		if rank >= 1 then
			table.insert(actions, { text = "Back to the lattice", quiet = true, onClick = function()
				props.onMode("lattice")
			end })
		end
	else
		local result = props.result or {}
		panelTitle, panelNumber = "DOMAIN", tostring(result.rank or rank)
		heading("THE EXPANSION PAID")
		local lines = {
			{ "Domain essence", `+{compactNumber(asNumber(result.essence))}`, Palette.pink },
			{ "Stardust", `+{compactNumber(asNumber(result.stardust))}`, Palette.cyan },
			{ "Domain points", `+{GameConfig.Domain.SkillPointPerRank or 2}`, Palette.mango },
			{ "Wheel spins", `+{compactNumber(asNumber(result.freeSpins))}`, Palette.cream },
		}
		for index, item in lines do
			local delay = 0.7 + index * 0.18
			row(item[1], item[2], {
				valueColor = item[3],
				fade = tick:map(function(now)
					return 1 - easeOut((now - resultAt.current - delay) / 0.3)
				end),
			})
		end
		if asNumber(result.overflow) > 0 then
			row(`{compactNumber(asNumber(result.overflow))} of that Stardust came from rebirths past the requirement.`, nil, { height = 34, size = 12, labelColor = Palette.muted })
		end
		gap(6)
		row(`Next expansion: {compactNumber(asNumber(result.nextRebirths))} rebirths and {compactNumber(asNumber(result.nextCores))} Cores.`, nil, { height = 34, size = 12, labelColor = Palette.muted })
		table.insert(actions, { text = "Etch your new points", primary = true, onClick = function()
			props.onMode("lattice")
		end })
	end

	local buttons = {}
	for index, action in actions do
		local height = if action.quiet then 30 else TapTarget
		if action.hold then
			buttons["a" .. index] = h("textbutton", {
				Size = UDim2.new(1, 0, 0, TapTarget),
				LayoutOrder = index,
				BackgroundColor3 = darken(Palette.mango, 0.55),
				AutoButtonColor = false,
				Text = "",
				ZIndex = 34,
				Event = {
					InputBegan = function(_, input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							holding.current = os.clock()
							Audio:play("domainCharge")
						end
					end,
					InputEnded = function(_, input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							holding.current = nil
						end
					end,
					Activated = function(_, input)
						-- a controller press can't be held, so it confirms straight away
						if input ~= nil and input.UserInputType ~= nil and string.find(input.UserInputType.Name, "Gamepad", 1, true) and not fired.current then
							fired.current = true
							props.onConfirm()
						end
					end,
				},
			}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("frame", {
				Size = hold:map(function(p)
					return UDim2.fromScale(p, 1)
				end),
				BackgroundColor3 = Palette.white,
				BorderSizePixel = 0,
				ZIndex = 35,
			}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uigradient", {
				Color = ColorSequence.new(Palette.mango, WHITE_HOT),
			})), h("textlabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = action.text,
				TextSize = 15,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextColor3 = Palette.cream,
				ZIndex = 36,
			}))
		elseif action.quiet then
			buttons["a" .. index] = h("textbutton", {
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Text = action.text,
				TextSize = 12,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextColor3 = if action.disabled then Palette.lineSoft else Palette.muted,
				AutoButtonColor = false,
				ZIndex = 34,
				Event = {
					Activated = function()
						if not action.disabled and action.onClick then
							action.onClick()
						end
					end,
				},
			})
		else
			buttons["a" .. index] = h("frame", {
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				ZIndex = 34,
			}, h(Button, {
				text = action.text,
				onClick = action.onClick,
				color = if action.primary then Palette.mango else Palette.panelSoft,
				textColor = if action.primary then Palette.ink else Palette.cream,
				size = UDim2.fromScale(1, 1),
				disabled = action.disabled,
				reducedMotion = reduced,
				highlight = action.primary,
				zIndex = 35,
			}))
		end
	end

	local panelW = if stacked then viewport.width - 24 else 360
	local numberSlam = if mode == "result" then tick:map(function(now)
		local t = (now - resultAt.current - 0.35) / 0.32
		return if t < 0 then 0 else 1 + (1 - easeOut(t)) * 1.4
	end) else nil
	local panel = h("frame", {
		Size = if stacked then UDim2.new(1, -24, 0.48, -12) else UDim2.new(0, panelW, 1, -48),
		Position = if stacked then UDim2.new(0, 12, 0.52, 0) else UDim2.new(1, -24, 0, 24),
		AnchorPoint = if stacked then Vector2.zero else Vector2.new(1, 0),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = Palette.lineSoft,
		Transparency = 0.25,
	}), h("uipadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}), h("textbutton", {
		Size = UDim2.fromOffset(60, 24),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Text = "Close",
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextColor3 = Palette.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = mode ~= "result",
		ZIndex = 34,
		Event = {
			Activated = function()
				if not props.busy then
					props.onClose()
				end
			end,
		},
	}), h("textlabel", {
		Size = UDim2.new(1, -60, 0, 14),
		BackgroundTransparency = 1,
		Text = panelTitle,
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextColor3 = Palette.mango,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	}), h("textlabel", {
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Text = panelNumber,
		TextSize = 50,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextColor3 = if mode == "result" then WHITE_HOT else Palette.cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = if numberSlam then numberSlam:map(function(s)
			return if s <= 0 then 1 else 0
		end) else 0,
		ZIndex = 33,
	}, numberSlam and h("uiscale", { Scale = numberSlam:map(function(s)
		return math.max(0.01, s)
	end) })), h("scrollingframe", {
		Size = UDim2.new(1, 0, 1, -(78 + #actions * (TapTarget + 8))),
		Position = UDim2.fromOffset(0, 74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.muted,
		ZIndex = 32,
	}, h("uipadding", { PaddingRight = UDim.new(0, 12) }), h("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}), rows), h("frame", {
		ref = actionsRef,
		Size = UDim2.new(1, 0, 0, #actions * (TapTarget + 8)),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		ZIndex = 33,
	}, h("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}), buttons))

	local heat = React.joinBindings({ hold, flare })
	return h("frame", {
		Name = "DomainChamber",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 20,
	}, h("frame", {
		-- the forge floor glows with the hold and the landing
		Size = UDim2.fromScale(1, 0.7),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = heat:map(function(v)
			local landing = if v[2] > 0 then 1 - v[2] else 0
			return math.clamp(0.86 - v[1] * 0.4 - landing * 0.5, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 21,
	}, h("uigradient", {
		Rotation = -90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})), h("frame", {
		Size = if stacked then UDim2.new(1, -24, 0.5, -12) else UDim2.new(1, -(panelW + 72), 1, -48),
		Position = UDim2.fromOffset(if stacked then 12 else 24, if stacked then 12 else 24),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, h("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, h(Lattice, {
		links = links,
		tick = tick,
		flare = flare,
		selected = if mode == "lattice" then selected else nil,
		etchedAt = etchedAt.current,
		facetAt = facetAt.current,
		anchorRefs = anchorRefs.current,
		reduced = reduced,
		onLink = if mode == "lattice" then onLink else function() end,
		onAnchor = if mode == "lattice" then onAnchor else function() end,
	}))), panel)
end

return {
	DomainChamber = DomainChamber,
}
end

__defs["purchaseOverlay"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.MotionKit)("motion")
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useBoatTween = _motion.useBoatTween
local useClock = _motion.useClock
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.CoreKit)("theme")
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local PURCHASE_RESULT_HOLD = 2.2
local PURCHASE_RESULT_HOLD_REDUCED = 1.65
local PURCHASE_PENDING_FAILSAFE = 45
local DOT_COLORS = { Palette.mango, Palette.cyan, Palette.mint }
local function ForgeDot(_param)
	local index = _param.index
	local clock = _param.clock
	local morph = _param.morph
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local color = DOT_COLORS[index + 1]
	local x = (index - 1) * 26
	local position = React.joinBindings({ clock, morph }):map(function(values)
		local wave = if reducedMotion then 0 else math.pow((math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.5, 1.6)
		return UDim2.new(0.5, math.round(x * (1 - values[2])), 0.5, math.round(9 - wave * 18))
	end)
	local scale = React.joinBindings({ clock, morph }):map(function(values)
		local pulse = if reducedMotion then 1 else 0.82 + (math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.13
		return math.max(0.05, pulse * (1 - values[2]))
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 414,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = morph:map(function(amount)
			return math.clamp(amount * 1.2, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement("frame", {
		Size = UDim2.new(1.35, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(color, 0.28),
		BackgroundTransparency = 0.54,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function ResultGlyph(_param)
	local phase = _param.phase
	local amount = _param.amount
	local accent = _param.accent
	local kind = if phase == "success" then "Check" else "Close"
	return React.createElement("frame", {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement(ScaleFromCenter, {
		scale = amount:map(function(value)
			return 0.24 + value * 0.76
		end),
		zIndex = 415,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(accent, 0.78),
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.22
		end),
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = amount:map(function(value)
			return 1 - value * 0.92
		end),
	}), React.createElement(Icon, {
		kind = kind,
		color = Palette.cream,
		accent = accent,
		size = 54,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))))
end
local function PurchaseOverlay(_param)
	local phase = _param.phase
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local detail = _param.detail
	local onDismiss = _param.onDismiss
	local visible = phase ~= "hidden"
	local result = phase == "success" or phase == "fail"
	local show = useBoatTween(if visible then 1 else 0, if visible then 0.25 else 0.18, softMotion, easeOutCubic, 0)
	local card = useBoatTween(if visible then 1 else 0, if visible then 0.34 else 0.15, softMotion, easeOutBack, 0)
	local _binding = useExitTransition(softMotion, 0.32, phase == "hidden")
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local morph = useFlipperSpring(if result then 1 else 0, softMotion, 500, 30)
	local clock = useClock(phase == "pending" and not reducedMotion, 1.4, 1)
	local viewport = useViewport()
	local nonce, setNonce = React.useState(0)
	local dismissRef = React.useRef(onDismiss)
	local dismissStarted = React.useRef(false)
	local overlayHostRef = React.useRef(nil)
	dismissRef.current = onDismiss
	local previousPhase = React.useRef("hidden")
	React.useEffect(function()
		if phase == previousPhase.current then
			return nil
		end
		previousPhase.current = phase
		if phase == "success" then
			Audio:play("purchaseResult")
		elseif phase == "fail" then
			Audio:play("error")
		end
	end, { phase })
	React.useEffect(function()
		if result then
			setNonce(function(value)
				return value + 1
			end)
		end
	end, { phase, result })
	local flash = useFlash(nonce, reducedMotion, if phase == "fail" then 0.62 else 0.48)
	local dismiss = React.useCallback(function()
		if not result or exiting or dismissStarted.current then
			return nil
		end
		dismissStarted.current = true
		Audio:play("purchaseExit")
		beginExit(function()
			local _result = dismissRef.current
			if _result ~= nil then
				_result = _result()
			end
			return _result
		end)
	end, { beginExit, exiting, result })
	React.useEffect(function()
		if phase == "pending" or phase == "hidden" then
			dismissStarted.current = false
		end
	end, { phase })
	React.useEffect(function()
		if not result then
			return nil
		end
		local alive = true
		local worker = task.delay(if reducedMotion then PURCHASE_RESULT_HOLD_REDUCED else PURCHASE_RESULT_HOLD, function()
			if alive then
				dismiss()
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { dismiss, phase, reducedMotion, result })
	React.useEffect(function()
		if phase == "hidden" then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase })
	React.useEffect(function()
		if not result or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current
		if host == nil then
			return nil
		end
		local alive = true
		local selectJob = task.defer(function()
			if not alive or host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			alive = false
			pcall(task.cancel, selectJob)
		end
	end, { phase, result })
	local accent = if phase == "fail" then Palette.coral elseif phase == "success" then Palette.mint else Palette.mango
	local title = if phase == "pending" then "BUYING..." elseif phase == "success" then "BOUGHT" else "COULDN'T BUY"
	local _result
	if phase == "pending" then
		_result = "Waiting on Roblox checkout"
	else
		local _result_1
		if phase == "success" then
			_result_1 = "It's in your account now"
		else
			local _condition = detail
			if _condition == nil then
				_condition = "You weren't charged"
			end
			_result_1 = _condition
		end
		_result = _result_1
	end
	local detailText = _result
	local shortLandscape = viewport.height < 430 and viewport.width > viewport.height * 1.14
	local sideSafe = math.max(viewport.sideInset, 8)
	local topSafe = math.max(viewport.topInset, 8)
	local bottomSafe = math.max(viewport.bottomInset, 8)
	local safeHeight = math.max(184, viewport.height - topSafe - bottomSafe)
	local availableWidth = math.max(280, viewport.width - (sideSafe + 12) * 2)
	local cardWidth = math.min(if shortLandscape then 540 else 430, availableWidth)
	local cardHeight = if shortLandscape then math.clamp(safeHeight - 16, 184, 218) else math.clamp(safeHeight - 20, 232, 272)
	local compactVertical = not shortLandscape and cardHeight < 260
	local presence = React.joinBindings({ show, card, exitAmount }):map(function(values)
		return math.min(values[1], values[2], values[3])
	end)
	local cardTravel = 22
	local cardPosition = presence:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.floor((1 - amount) * cardTravel))
	end)
	local cardScale = React.joinBindings({ presence, flash }):map(function(values)
		return 0.94 + math.clamp(values[1], 0, 1) * 0.06 + values[2] * 0.025
	end)
	local orbSize = if shortLandscape then math.min(106, cardHeight - 32) elseif compactVertical then 104 else 118
	local orbPosition = if shortLandscape then UDim2.fromOffset(20, math.floor(cardHeight * 0.5)) else UDim2.new(0.5, 0, 0, 24)
	local orbAnchor = if shortLandscape then Vector2.new(0, 0.5) else Vector2.new(0.5, 0)
	local copyLeft = if shortLandscape then orbSize + 42 else 18
	local copyWidth = if shortLandscape then -(copyLeft + 20) else -36
	local titleY = if shortLandscape then math.max(28, math.floor(cardHeight * 0.5) - 44) else orbSize + (if compactVertical then 32 else 40)
	local detailY = titleY + (if shortLandscape then 28 else 24)
	local railLeft = if shortLandscape then copyLeft else 26
	local railBottom = if shortLandscape then 28 elseif compactVertical then 29 else 38
	local _exp = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = presence:map(function(amount)
			return 1 - amount * 0.68
		end),
		BorderSizePixel = 0,
		ZIndex = 400,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Name = "PurchaseDismissBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Active = visible and not exiting,
		Selectable = false,
		Modal = visible,
		ZIndex = 401,
		Event = {
			Activated = function()
				if result and not exiting then
					dismiss()
				end
			end,
		},
	})
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 4),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		ZIndex = 405,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}))
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	})
	local _exp_4 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.62),
		Rotation = 90,
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = presence:map(function(amount)
			return 1 - amount * 0.8
		end),
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0.56, 0, 0, 3),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 407,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_7 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_8 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.5,
	})
	local _exp_9 = { 0, 1, 2 }
	local _newValue = table.create(#_exp_9)
	local _callback = function(index)
		return React.createElement(ForgeDot, {
			key = index,
			index = index,
			clock = clock,
			morph = morph,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_9 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_9)
	end
	local content = React.createElement(OverlayPresence, {
		amount = presence,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
		Active = presence:map(function(amount)
			return amount > 0.02 and not exiting
		end),
		Visible = presence:map(function(amount)
			return amount > 0.005
		end),
		ClipsDescendants = false,
		Event = {
			InputBegan = function(_frame, input)
				if result and not exiting and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dismiss()
				end
			end,
		},
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		ClipsDescendants = false,
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 405,
	}, _exp_2, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 406,
	}, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromOffset(orbSize, orbSize),
		Position = orbPosition,
		AnchorPoint = orbAnchor,
		BackgroundColor3 = darken(accent, 0.86),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, _exp_7, _exp_8, _newValue, phase == "success" and React.createElement(ResultGlyph, {
		phase = "success",
		amount = morph,
		accent = accent,
	}), phase == "fail" and React.createElement(ResultGlyph, {
		phase = "fail",
		amount = morph,
		accent = accent,
	})), React.createElement(Text, {
		value = title,
		size = if shortLandscape then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(copyLeft, titleY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 26),
		zIndex = 410,
	}), React.createElement(Text, {
		value = detailText,
		size = 11,
		color = Palette.creamSoft,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(copyLeft, detailY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 28),
		zIndex = 410,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(railLeft + (if shortLandscape then 20 else 26)), 0, 3),
		Position = UDim2.new(0, railLeft, 1, -railBottom),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 409,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = if phase == "pending" then clock:map(function(time)
			return UDim2.new(0.22, 0, 1, 0)
		end) else UDim2.fromScale(1, 1),
		Position = if phase == "pending" then clock:map(function(time)
			return UDim2.new((time * 1.25) % 1, 0, 0, 0)
		end) else UDim2.fromScale(0, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, accent),
	}))), result and React.createElement("frame", {
		Name = "PurchaseContinue",
		Size = UDim2.new(1, -(copyLeft + (if shortLandscape then 20 else 26)), 0, 36),
		Position = UDim2.new(0, copyLeft, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 412,
	}, React.createElement(Button, {
		text = "CONTINUE",
		onClick = dismiss,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
		selectable = true,
		zIndex = 412,
	})))))))
	return React.createElement("frame", {
		ref = overlayHostRef,
		Name = "PurchaseOverlayHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
	}, content)
end
return {
	PurchaseOverlay = PurchaseOverlay,
	PURCHASE_RESULT_HOLD = PURCHASE_RESULT_HOLD,
	PURCHASE_RESULT_HOLD_REDUCED = PURCHASE_RESULT_HOLD_REDUCED,
	PURCHASE_PENDING_FAILSAFE = PURCHASE_PENDING_FAILSAFE,
}
end

__defs["MobileControls"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _motion = require(script.Parent.MotionKit)("motion")
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local EDIT_BOUNDS = require(script.Parent.CoreKit)("mobileLayout").EDIT_BOUNDS
local _theme = require(script.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.UiCore)("ui")
local Button = _ui.Button
local Text = _ui.Text
local _format = require(script.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Audio = require(script.Parent.AudioKit)("audio").Audio
local dragHandles = {}
local editMode = false
local dragId
local dragInput
local dragOffset = Vector2.zero
local dragLastCell = Vector2.zero
local dragChanged
local dragEnded
local dragFocusReleased
local dragMenuOpened
local function cancelDrag()
	dragId = nil
	dragInput = nil
end
local function clampDrag(pos, bounds)
	return Vector2.new(math.clamp(pos.X, bounds.minX, bounds.maxX), math.clamp(pos.Y, bounds.minY, bounds.maxY))
end
local function ensureDragging()
	if dragChanged ~= nil then
		return nil
	end
	dragChanged = UserInputService.InputChanged:Connect(function(input)
		if not editMode or dragId == nil or dragInput == nil then
			return nil
		end
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= dragInput then
				return nil
			end
		elseif dragInput.UserInputType == Enum.UserInputType.MouseButton1 then
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return nil
			end
		else
			return nil
		end
		local _dragId = dragId
		local handle = dragHandles[_dragId]
		if handle == nil then
			return nil
		end
		local raw = Vector2.new(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		local cellX = math.round(raw.X / grid)
		local cellY = math.round(raw.Y / grid)
		local resolvedPosition = clampDrag(Vector2.new(cellX * grid, cellY * grid), handle.bounds)
		handle.position = resolvedPosition
		local _result = handle.onMove
		if _result ~= nil then
			_result(resolvedPosition)
		end
		if cellX ~= dragLastCell.X or cellY ~= dragLastCell.Y then
			dragLastCell = Vector2.new(cellX, cellY)
			Audio:play("dragSnap")
		end
	end)
	dragEnded = UserInputService.InputEnded:Connect(function(input)
		if dragInput == nil then
			return nil
		end
		local exactTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
		local mouseRelease = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
		if exactTouch or mouseRelease then
			if dragId ~= nil then
				Audio:play("dragDrop")
			end
			cancelDrag()
		end
	end)
	dragFocusReleased = UserInputService.WindowFocusReleased:Connect(cancelDrag)
	dragMenuOpened = GuiService.MenuOpened:Connect(cancelDrag)
end
local MobileDragging = {
	setEditMode = function(self, on)
		editMode = on
		if not on then
			cancelDrag()
		end
		ensureDragging()
	end,
	register = function(self, handle)
		ensureDragging()
		local _id = handle.id
		local _handle = handle
		dragHandles[_id] = _handle
		return function()
			local _id_1 = handle.id
			dragHandles[_id_1] = nil
			if dragId == handle.id then
				cancelDrag()
			end
		end
	end,
	beginDrag = function(self, id, input)
		if not editMode then
			return nil
		end
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		Audio:play("dragGrab")
		dragId = id
		dragInput = input
		dragOffset = Vector2.new(input.Position.X - handle.position.X, input.Position.Y - handle.position.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		dragLastCell = Vector2.new(math.round(handle.position.X / grid), math.round(handle.position.Y / grid))
	end,
	setPosition = function(self, id, pos)
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		handle.position = clampDrag(pos, handle.bounds)
		local _result = handle.onMove
		if _result ~= nil then
			_result(handle.position)
		end
	end,
	dispose = function(self)
		local _result = dragChanged
		if _result ~= nil then
			_result:Disconnect()
		end
		local _result_1 = dragEnded
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		local _result_2 = dragFocusReleased
		if _result_2 ~= nil then
			_result_2:Disconnect()
		end
		local _result_3 = dragMenuOpened
		if _result_3 ~= nil then
			_result_3:Disconnect()
		end
		dragChanged = nil
		dragEnded = nil
		dragFocusReleased = nil
		dragMenuOpened = nil
		table.clear(dragHandles)
		cancelDrag()
		editMode = false
	end,
}
local function slotPixels(slot, width, height)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local _exp = slot.x * width
	local _condition_2 = slot.anchorX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local _exp_1 = _exp - slotW * _condition_2
	local _exp_2 = slot.y * height
	local _condition_3 = slot.anchorY
	if _condition_3 == nil then
		_condition_3 = 0.5
	end
	return Vector2.new(_exp_1, _exp_2 - slotH * _condition_3)
end
local function slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local minX = math.max(8, sideInset + 8)
	local _exp = topInset + 8
	local _condition_2 = slot.safeTop
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local minY = math.max(48, _exp, _condition_2)
	return {
		minX = minX,
		maxX = math.max(minX, width - sideInset - slotW - 8),
		minY = minY,
		maxY = math.max(minY, height - bottomInset - slotH - 8),
	}
end
local function safeSlotPosition(slot, position, width, height, sideInset, topInset, bottomInset)
	local bounds = slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	return Vector2.new(math.clamp(position.X, bounds.minX, bounds.maxX), math.clamp(position.Y, bounds.minY, bounds.maxY))
end
-- Layout memory; fractions so a stored layout survives rotation. Seeded from the saved profile string.
local MobileLayoutSlots = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("MobileLayoutSlots"))
local MOBILE_LAYOUT_MEMORY = {}
local MOBILE_LAYOUT_SEEDED = false
local function MobileControls(_param)
	local slots = _param.slots
	local dispatch = _param.dispatch
	if not MOBILE_LAYOUT_SEEDED and type(_param.savedSlots) == "string" then
		MOBILE_LAYOUT_SEEDED = true
		for index, memory in MobileLayoutSlots.Decode(_param.savedSlots) do
			MOBILE_LAYOUT_MEMORY[index] = memory
		end
	end
	local reducedMotion = _param.reducedMotion
	local visible = _param.visible
	local onClose = _param.onClose
	local scales = _param.scales
	local opacities = _param.opacities
	local viewport = useViewport()
	local editing, setEditing = React.useState(false)
	local snap, setSnap = React.useState(true)
	local snapStep, setSnapStep = React.useState(16)
	local fine, setFine = React.useState(false)
	local showThirds, setShowThirds = React.useState(false)
	local selectedId, setSelectedId = React.useState()
	local locked, setLocked = React.useState({})
	local history, setHistory = React.useState({})
	local redo, setRedo = React.useState({})
	local positions, setPositions = React.useState({})
	local memoryIndex, setMemoryIndex = React.useState(1)
	local memoryRevision, setMemoryRevision = React.useState(0)
	local _binding = useExitTransition(reducedMotion, 0.38, visible)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local requestClose = React.useCallback(function()
		if not exiting then
			beginExit(onClose)
		end
	end, { beginExit, exiting, onClose })
	local screen = React.useState(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local vrScreen = playerGui:FindFirstChild("AstralForgeVR")
		if vrScreen and vrScreen.Enabled then return vrScreen:FindFirstChild("Overlay") end
		local rootScreen = playerGui:FindFirstChild("AstralForgeStudioUI")
		return if rootScreen ~= nil and rootScreen:IsA("ScreenGui") then rootScreen else playerGui
	end)
	local positionsRef = React.useRef(positions)
	positionsRef.current = positions
	React.useEffect(function()
		return function()
			MobileDragging:dispose()
		end
	end, {})
	React.useEffect(function()
		if not visible then
			return nil
		end
		local initialPositions = {}
		for _, slot in slots do
			initialPositions[slot.id] = safeSlotPosition(slot, slotPixels(slot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		positionsRef.current = initialPositions
		setPositions(initialPositions)
	end, { slots, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		if not visible then
			MobileDragging:setEditMode(false)
			setEditing(false)
			return nil
		end
		local cleanups = {}
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local corrected = _object
		local correctedAny = false
		for _, slot in slots do
			local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local raw = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local position = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			if position.X ~= raw.X or position.Y ~= raw.Y then
				corrected[slot.id] = position
				correctedAny = true
			end
			local _arg0 = MobileDragging:register({
				id = slot.id,
				position = position,
				bounds = bounds,
				snap = if snap then snapStep else 1,
				onMove = function(nextPosition)
					return setPositions(function(current)
						local _object_1 = table.clone(current)
						setmetatable(_object_1, nil)
						_object_1[slot.id] = nextPosition
						return _object_1
					end)
				end,
			})
			table.insert(cleanups, _arg0)
		end
		if correctedAny then
			positionsRef.current = corrected
			setPositions(corrected)
		end
		return function()
			for _, dispose in cleanups do
				dispose()
			end
		end
	end, { slots, snap, snapStep, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		MobileDragging:setEditMode(editing and visible)
		return function()
			return MobileDragging:setEditMode(false)
		end
	end, { editing, visible })
	local layoutOverlaps = function(source)
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			local pos = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			do
				local otherIndex = index + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						otherIndex += 1
					else
						_shouldIncrement = true
					end
					if not (otherIndex < #slots) then
						break
					end
					local other = slots[otherIndex + 1]
					local otherPos = source[other.id] or slotPixels(other, viewport.width, viewport.height)
					local _condition_2 = other.width
					if _condition_2 == nil then
						_condition_2 = 112
					end
					local otherWidth = _condition_2
					local _condition_3 = other.height
					if _condition_3 == nil then
						_condition_3 = 62
					end
					local otherHeight = _condition_3
					local separated = pos.X + width + 6 <= otherPos.X or otherPos.X + otherWidth + 6 <= pos.X or pos.Y + height + 6 <= otherPos.Y or otherPos.Y + otherHeight + 6 <= pos.Y
					if not separated then
						return true
					end
				end
			end
		end
		return false
	end
	local save = function(source)
		if source == nil then
			source = positionsRef.current
		end
		if layoutOverlaps(source) then
			return false
		end
		local values = {}
		for _, slot in slots do
			local raw = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local pos = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local slotW = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local slotH = _condition_1
			local _exp = pos.X
			local _condition_2 = slot.anchorX
			if _condition_2 == nil then
				_condition_2 = 0.5
			end
			values[slot.xKey] = math.clamp((_exp + slotW * _condition_2) / viewport.width, 0, 1)
			local _exp_1 = pos.Y
			local _condition_3 = slot.anchorY
			if _condition_3 == nil then
				_condition_3 = 0.5
			end
			values[slot.yKey] = math.clamp((_exp_1 + slotH * _condition_3) / viewport.height, 0, 1)
		end
		dispatch("SetMobileLayout", {
			Values = values,
		})
		return true
	end
	local finishEditing = function()
		if not save() then
			return false
		end
		setEditing(false)
		return true
	end
	local capStack = function(source, extra)
		local _array = {}
		local _length = #_array
		table.move(source, 1, #source, _length + 1, _array)
		local nextHist = _array
		local _object = table.clone(extra)
		setmetatable(_object, nil)
		table.insert(nextHist, _object)
		if #nextHist <= 12 then
			return nextHist
		end
		local trimmed = {}
		for index = #nextHist - 12, #nextHist - 1 do
			local _arg0 = nextHist[index + 1]
			table.insert(trimmed, _arg0)
		end
		return trimmed
	end
	local applyPositions = function(nextPos)
		positionsRef.current = nextPos
		setPositions(nextPos)
		for _, slot in slots do
			local pos = nextPos[slot.id]
			if pos ~= nil then
				MobileDragging:setPosition(slot.id, pos)
			end
		end
	end
	local pushHistory = function(source)
		setHistory(function(current)
			return capStack(current, source)
		end)
		setRedo({})
	end
	local undoLayout = function()
		if #history == 0 then
			return nil
		end
		local prior = history[#history]
		if prior == nil then
			return nil
		end
		setRedo(function(current)
			return capStack(current, positionsRef.current)
		end)
		setHistory(function(current)
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			return _newValue
		end)
		applyPositions(prior)
		Audio:play("close", 0.94)
	end
	local redoLayout = function()
		if #redo == 0 then
			return nil
		end
		local upcoming = redo[#redo]
		if upcoming == nil then
			return nil
		end
		setHistory(function(current)
			return capStack(current, positionsRef.current)
		end)
		setRedo(function(current)
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			return _newValue
		end)
		applyPositions(upcoming)
		Audio:play("open", 1.04)
	end
	local nudgeSelected = function(dx, dy)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local step = if fine then 1 else (if snap then snapStep else 4)
		local moved = safeSlotPosition(slot, Vector2.new(current.X + dx * step, current.Y + dy * step), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = moved
		applyPositions(_object)
	end
	local alignSelected = function(mode)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local _condition_1 = slot.width
		if _condition_1 == nil then
			_condition_1 = 112
		end
		local slotW = _condition_1
		local _condition_2 = slot.height
		if _condition_2 == nil then
			_condition_2 = 62
		end
		local slotH = _condition_2
		local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local x = current.X
		local y = current.Y
		if mode == "left" then
			x = bounds.minX
		end
		if mode == "right" then
			x = bounds.maxX
		end
		if mode == "top" then
			y = bounds.minY
		end
		if mode == "bottom" then
			y = bounds.maxY
		end
		if mode == "cx" then
			x = math.floor((viewport.width - slotW) / 2)
		end
		if mode == "cy" then
			y = math.floor((viewport.height - slotH) / 2)
		end
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = safeSlotPosition(slot, Vector2.new(x, y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		applyPositions(_object)
	end
	local unstackOverlaps = function()
		pushHistory(positionsRef.current)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local nextPos = _object
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			for otherIndex = 0, #slots - 1 do
				if otherIndex == index then
					continue
				end
				local other = slots[otherIndex + 1]
				local otherPos = nextPos[other.id] or slotPixels(other, viewport.width, viewport.height)
				local _condition_2 = other.width
				if _condition_2 == nil then
					_condition_2 = 112
				end
				local otherW = _condition_2
				local _condition_3 = other.height
				if _condition_3 == nil then
					_condition_3 = 62
				end
				local otherH = _condition_3
				local separated = pos.X + width + 8 <= otherPos.X or otherPos.X + otherW + 8 <= pos.X or pos.Y + height + 8 <= otherPos.Y or otherPos.Y + otherH + 8 <= pos.Y
				if separated then
					continue
				end
				pos = safeSlotPosition(slot, Vector2.new(pos.X, otherPos.Y + otherH + 12), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
			nextPos[slot.id] = pos
		end
		applyPositions(nextPos)
		save(nextPos)
	end
	local bumpSelectedSetting = function(kind, delta)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil then
			return nil
		end
		local key = if id == "quick" then (if kind == "scale" then "MobileQuickScale" else "MobileQuickOpacity") elseif id == "dock" then (if kind == "scale" then "MobileDockScale" else "MobileDockOpacity") else (if kind == "scale" then "MobileToastScale" else "MobileToastOpacity")
		local _result
		if kind == "scale" then
			local _result_1 = scales
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_result = _condition_1
		else
			local _result_1 = opacities
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.85
			end
			_result = _condition_1
		end
		local current = _result
		dispatch("SetSetting", {
			Key = key,
			Value = math.clamp(current + delta, 0, 1),
		})
	end
	local resetLayout = function()
		local fresh = {}
		for _, slot in slots do
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = slot.defaultX
			_object.y = slot.defaultY
			local resetSlot = _object
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(resetSlot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		for _, slot in slots do
			MobileDragging:setPosition(slot.id, fresh[slot.id])
		end
		positionsRef.current = fresh
		setPositions(fresh)
		save(fresh)
	end
	local applyPreset = function(side)
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 1.02)
		local fresh = {}
		for _, slot in slots do
			local x = slot.defaultX
			local y = slot.defaultY
			if side == "left" then
				if slot.id == "quick" then
					x = 0.28
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "right" then
				if slot.id == "quick" then
					x = 0.72
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "top" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.82
					y = 0.38
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "thumbs" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.5
					y = 0.18
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.93
				end
			elseif side == "tl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "tr" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "bl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "br" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			end
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = x
			_object.y = y
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(_object, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		applyPositions(fresh)
		save(fresh)
		if side == "left" or side == "bl" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 1,
			})
		end
		if side == "right" or side == "br" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 0,
			})
		end
	end
	local slotSize = function(slot)
		return slot.width or 112, slot.height or 62
	end
	local commitLayout = function(nextPos)
		applyPositions(nextPos)
		if not layoutOverlaps(nextPos) then
			save(nextPos)
		end
	end
	local mirrorLayout = function()
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 0.94)
		local nextPos = table.clone(positionsRef.current)
		for _, slot in slots do
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local width = slotSize(slot)
			nextPos[slot.id] = safeSlotPosition(slot, Vector2.new(viewport.width - pos.X - width, pos.Y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		commitLayout(nextPos)
	end
	local cycleSelection = function()
		if #slots == 0 then
			return nil
		end
		local nextIndex = 1
		for index, slot in slots do
			if slot.id == selectedId then
				nextIndex = index % #slots + 1
				break
			end
		end
		setSelectedId(slots[nextIndex].id)
		Audio:play("filterPick", 1.08)
	end
	local swapSelected = function()
		if #slots < 2 then
			return nil
		end
		local fromIndex = 1
		for index, slot in slots do
			if slot.id == selectedId then
				fromIndex = index
				break
			end
		end
		local fromSlot = slots[fromIndex]
		local toSlot = nil
		for step = 1, #slots - 1 do
			local candidate = slots[(fromIndex - 1 + step) % #slots + 1]
			if locked[candidate.id] ~= true then
				toSlot = candidate
				break
			end
		end
		if toSlot == nil or locked[fromSlot.id] == true then
			return nil
		end
		pushHistory(positionsRef.current)
		local nextPos = table.clone(positionsRef.current)
		local fromPos = nextPos[fromSlot.id] or slotPixels(fromSlot, viewport.width, viewport.height)
		local toPos = nextPos[toSlot.id] or slotPixels(toSlot, viewport.width, viewport.height)
		local fromW, fromH = slotSize(fromSlot)
		local toW, toH = slotSize(toSlot)
		-- Swap centres, not corners, so blocks of different sizes trade places cleanly.
		local fromCentre = fromPos + Vector2.new(fromW, fromH) / 2
		local toCentre = toPos + Vector2.new(toW, toH) / 2
		nextPos[fromSlot.id] = safeSlotPosition(fromSlot, toCentre - Vector2.new(fromW, fromH) / 2, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		nextPos[toSlot.id] = safeSlotPosition(toSlot, fromCentre - Vector2.new(toW, toH) / 2, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		Audio:play("filterPick", 1.0)
		commitLayout(nextPos)
	end
	local storeMemory = function()
		local stored = {}
		for _, slot in slots do
			local pos = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			stored[slot.id] = { x = pos.X / math.max(1, viewport.width), y = pos.Y / math.max(1, viewport.height) }
		end
		MOBILE_LAYOUT_MEMORY[memoryIndex] = stored
		setMemoryRevision(memoryRevision + 1)
		dispatch("SetMobileLayout", {
			Values = {},
			Slots = MobileLayoutSlots.Encode(MOBILE_LAYOUT_MEMORY),
		})
		Audio:play("copyDone")
	end
	local recallMemory = function()
		local stored = MOBILE_LAYOUT_MEMORY[memoryIndex]
		if stored == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local nextPos = table.clone(positionsRef.current)
		for _, slot in slots do
			local entry = stored[slot.id]
			if entry ~= nil and locked[slot.id] ~= true then
				nextPos[slot.id] = safeSlotPosition(slot, Vector2.new(entry.x * viewport.width, entry.y * viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
		end
		Audio:play("filterPick", 0.9)
		commitLayout(nextPos)
	end
	local overlaps = function(slot, pos)
		local _condition = slot.width
		if _condition == nil then
			_condition = 112
		end
		local w = _condition
		local _condition_1 = slot.height
		if _condition_1 == nil then
			_condition_1 = 62
		end
		local h = _condition_1
		for _, other in slots do
			if other.id == slot.id then
				continue
			end
			local otherPos = positions[other.id] or slotPixels(other, viewport.width, viewport.height)
			local _condition_2 = other.width
			if _condition_2 == nil then
				_condition_2 = 112
			end
			local otherW = _condition_2
			local _condition_3 = other.height
			if _condition_3 == nil then
				_condition_3 = 62
			end
			local otherH = _condition_3
			local separated = pos.X + w + 6 <= otherPos.X or otherPos.X + otherW + 6 <= pos.X or pos.Y + h + 6 <= otherPos.Y or otherPos.Y + otherH + 6 <= pos.Y
			if not separated then
				return true
			end
		end
		return false
	end
	local collisionPresent = layoutOverlaps(positions)
	if not visible then
		return ReactRoblox.createPortal(React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}), screen)
	end
	local editorToolbarY = math.max(if viewport.width > viewport.height and viewport.height < 500 then 56 else 8, viewport.topInset + 8)
	local topToolbarBottom = editorToolbarY + TapTarget * 2 + 16 + 8
	local bottomBarY = math.max(topToolbarBottom, viewport.height - viewport.bottomInset - (TapTarget * 2 + 16))
	local gridMarks = if showThirds then { 1 / 3, 0.5, 2 / 3 } else { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
	local _callback = function(entry)
		local _exp = entry.id
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		return _exp == _condition
	end
	local _result
	for _i, _v in slots do
		if _callback(_v, _i - 1, slots) == true then
			_result = _v
			break
		end
	end
	local selectedSlot = _result
	local selectedPos = if selectedSlot ~= nil then (positions[selectedSlot.id] or slotPixels(selectedSlot, viewport.width, viewport.height)) else nil
	local selectedLocked = selectedSlot ~= nil and locked[selectedSlot.id] == true
	local _condition = editing
	if _condition then
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(x)
			return React.createElement("frame", {
				key = `grid-x-{x}`,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.new(x, 0, 0, 0),
				BackgroundColor3 = if x == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if x == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		_condition = _newValue
	end
	local _condition_1 = editing
	if _condition_1 then
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(y)
			return React.createElement("frame", {
				key = `grid-y-{y}`,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, y, 0),
				BackgroundColor3 = if y == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if y == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		_condition_1 = _newValue
	end
	local _condition_2 = editing
	if _condition_2 then
		local _newValue = table.create(#slots)
		local _callback_1 = function(slot)
			local _condition_3 = slot.width
			if _condition_3 == nil then
				_condition_3 = 112
			end
			local slotW = _condition_3
			local _condition_4 = slot.height
			if _condition_4 == nil then
				_condition_4 = 62
			end
			local slotH = _condition_4
			local pos = positions[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local collision = overlaps(slot, pos)
			local isLocked = locked[slot.id] == true
			local accent = if collision then Palette.coral elseif selectedId == slot.id then Palette.mint elseif isLocked then Palette.mango else EDIT_BOUNDS
			local pctX = math.floor(((pos.X + slotW * 0.5) / viewport.width) * 100)
			local pctY = math.floor(((pos.Y + slotH * 0.5) / viewport.height) * 100)
			return React.createElement("frame", {
				key = slot.id,
				Size = UDim2.fromOffset(slotW, slotH),
				Position = UDim2.fromOffset(pos.X, pos.Y),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ZIndex = 502,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 14),
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = if collision then 3 else 2,
				Transparency = 0.08,
			}), React.createElement("frame", {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(-7, -7),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 505,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement(Text, {
				value = if isLocked then "L" else "+",
				size = 14,
				color = Palette.ink,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 506,
			})), React.createElement(Text, {
				value = slot.label,
				size = 11,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(4, 8),
				sizeConstraint = UDim2.new(1, -8, 0, 18),
				zIndex = 503,
			}), React.createElement(Text, {
				value = `{pctX}%  {pctY}%`,
				size = 9,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 4, 1, -22),
				sizeConstraint = UDim2.new(1, -8, 0, 14),
				zIndex = 503,
			}), collision and React.createElement(Text, {
				value = "OVERLAP",
				size = 8,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -36),
				sizeConstraint = UDim2.new(1, 0, 0, 14),
				zIndex = 506,
			}), React.createElement("imagebutton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Active = true,
				ZIndex = 504,
				Event = {
					InputBegan = function(_button, input)
						if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
							setSelectedId(slot.id)
							if not isLocked then
								MobileDragging:beginDrag(slot.id, input)
							end
						end
					end,
				},
			}))
		end
		for _k, _v in slots do
			_newValue[_k] = _callback_1(_v, _k - 1, slots)
		end
		_condition_2 = _newValue
	end
	local _condition_3 = editing
	if _condition_3 then
		local _exp = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 13),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.42,
		}), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if collisionPresent then "OVERLAP" else "SAVE",
			onClick = if collisionPresent then unstackOverlaps else finishEditing,
			color = if collisionPresent then Palette.coral else EDIT_BOUNDS,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.2, 1, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if snap then `SNAP {snapStep}` else "FREE",
			onClick = function()
				if not snap then
					setSnap(true)
					setSnapStep(4)
				elseif snapStep == 4 then
					setSnapStep(8)
				elseif snapStep == 8 then
					setSnapStep(16)
				elseif snapStep == 16 then
					setSnapStep(32)
				else
					setSnap(false)
					setSnapStep(8)
				end
			end,
			color = if snap then Palette.cyan else Palette.panelSoft,
			textColor = if snap then Palette.ink else Palette.creamSoft,
			outline = not snap,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.4, 2, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "UNDO",
			onClick = undoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.6, 3, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "REDO",
			onClick = redoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.8, 4, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "DONE",
			onClick = function()
				if finishEditing() then
					requestClose()
				end
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = exiting,
		})))
		local _exp_1 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY + TapTarget + 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "←",
			onClick = function()
				return nudgeSelected(-1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↑",
			onClick = function()
				return nudgeSelected(0, -1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.16, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↓",
			onClick = function()
				return nudgeSelected(0, 1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "→",
			onClick = function()
				return nudgeSelected(1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if fine then "1px" else "STEP",
			onClick = function()
				return setFine(not fine)
			end,
			color = if fine then Palette.mint else Palette.panelSoft,
			textColor = if fine then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.64, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if showThirds then "1/3" else "10%",
			onClick = function()
				return setShowThirds(not showThirds)
			end,
			color = if showThirds then Palette.cyan else Palette.panelSoft,
			textColor = if showThirds then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.82, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_2 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "L",
			onClick = function()
				return alignSelected("left")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "R",
			onClick = function()
				return alignSelected("right")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(1 / 6, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "T",
			onClick = function()
				return alignSelected("top")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(2 / 6, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "B",
			onClick = function()
				return alignSelected("bottom")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(3 / 6, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CX",
			onClick = function()
				return alignSelected("cx")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(4 / 6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CY",
			onClick = function()
				return alignSelected("cy")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(5 / 6, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_3 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY + TapTarget + 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = if selectedLocked then "UNLOCK" else "LOCK",
			onClick = function()
				if selectedSlot == nil then
					return nil
				end
				setLocked(function(current)
					local _object = table.clone(current)
					setmetatable(_object, nil)
					_object[selectedSlot.id] = not selectedLocked
					return _object
				end)
			end,
			color = if selectedLocked then Palette.mango else Palette.panelSoft,
			textColor = if selectedLocked then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ-",
			onClick = function()
				return bumpSelectedSetting("scale", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.18, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ+",
			onClick = function()
				return bumpSelectedSetting("scale", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE-",
			onClick = function()
				return bumpSelectedSetting("opacity", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.46, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE+",
			onClick = function()
				return bumpSelectedSetting("opacity", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.62, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CLEAR",
			onClick = unstackOverlaps,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.new(0.22, -3, 1, 0),
			position = UDim2.new(0.78, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _attributes = {}
		local _result_1
		if selectedPos ~= nil then
			local _result_2 = selectedSlot
			if _result_2 ~= nil then
				_result_2 = _result_2.label
			end
			local _condition_4 = _result_2
			if _condition_4 == nil then
				_condition_4 = "HUD"
			end
			local selectedScale = if scales ~= nil and selectedSlot ~= nil then scales[selectedSlot.id] else nil
			local selectedFade = if opacities ~= nil and selectedSlot ~= nil then opacities[selectedSlot.id] else nil
			local xPct = math.floor(selectedPos.X / math.max(1, viewport.width) * 100 + 0.5)
			local yPct = math.floor(selectedPos.Y / math.max(1, viewport.height) * 100 + 0.5)
			_result_1 = `{_condition_4}  ·  X {xPct}%  Y {yPct}%  ·  SIZE {math.floor((selectedScale or 0.5) * 100 + 0.5)}  FADE {math.floor((selectedFade or 0.85) * 100 + 0.5)}{if selectedLocked then "  ·  LOCKED" else ""}{if collisionPresent then "  ·  OVERLAP" else ""}`
		else
			_result_1 = "DRAG A BLOCK"
		end
		_attributes.value = _result_1
		_attributes.size = 10
		_attributes.color = Palette.cyan
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.align = Enum.TextXAlignment.Center
		_attributes.position = UDim2.new(0, viewport.sideInset + 12, 0, editorToolbarY + TapTarget * 2 + 16)
		_attributes.sizeConstraint = UDim2.new(1, -(viewport.sideInset * 2 + 24), 0, 18)
		_attributes.zIndex = 506
		local toolRowY = bottomBarY - TapTarget - 6
		local memoryFilled = MOBILE_LAYOUT_MEMORY[memoryIndex] ~= nil
		local _exp_4 = toolRowY >= topToolbarBottom + 18 and React.createElement("frame", {
			key = `tools-{memoryRevision}`,
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, toolRowY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "NEXT",
			onClick = cycleSelection,
			color = Palette.panelSoft,
			textColor = Palette.cyan,
			outline = true,
			size = UDim2.new(0.15, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SWAP",
			onClick = swapSelected,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.15, -3, 1, 0),
			position = UDim2.new(0.15, 1, 0, 0),
			disabled = selectedLocked,
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "MIRROR",
			onClick = mirrorLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.3, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = `M{memoryIndex}`,
			onClick = function()
				setMemoryIndex(memoryIndex % 3 + 1)
			end,
			color = if memoryFilled then Palette.violet else Palette.panelSoft,
			textColor = if memoryFilled then Palette.ink else Palette.creamSoft,
			outline = not memoryFilled,
			size = UDim2.new(0.12, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "STORE",
			onClick = storeMemory,
			color = Palette.panelSoft,
			textColor = Palette.violet,
			outline = true,
			size = UDim2.new(0.2, -3, 1, 0),
			position = UDim2.new(0.6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "RECALL",
			onClick = recallMemory,
			color = if memoryFilled then Palette.violet else Palette.panelSoft,
			textColor = if memoryFilled then Palette.ink else Palette.muted,
			size = UDim2.new(0.2, -3, 1, 0),
			position = UDim2.new(0.8, 5, 0, 0),
			disabled = not memoryFilled,
			reducedMotion = reducedMotion,
		}))
		_condition_3 = React.createElement(React.Fragment, nil, _exp, _exp_1, _exp_2, _exp_3, _exp_4 or nil, React.createElement(Text, _attributes))
	end
	return ReactRoblox.createPortal(React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = exit:map(function(amount)
			return 1 - amount * (if editing then 0.62 else 0.88)
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 500,
		ClipsDescendants = true,
		Visible = exit:map(function(amount)
			return amount > 0.01
		end),
	}, _condition, _condition_1, _condition_2, _condition_3, not editing and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(440, viewport.width - viewport.sideInset * 2 - 24), 292),
		Position = UDim2.new(0.5, 0, 1, -(304 + viewport.bottomInset)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 510,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(Button, {
		text = "EDIT HUD LAYOUT",
		onClick = function()
			return setEditing(true)
		end,
		color = EDIT_BOUNDS,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "LEFT",
		onClick = function()
			return applyPreset("left")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.2, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "HOME",
		onClick = function()
			return applyPreset("default")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.4, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RIGHT",
		onClick = function()
			return applyPreset("right")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.6, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TOP",
		onClick = function()
			return applyPreset("top")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.8, 4, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "THUMB",
		onClick = function()
			return applyPreset("thumbs")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TL",
		onClick = function()
			return applyPreset("tl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.25, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TR",
		onClick = function()
			return applyPreset("tr")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.5, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BL",
		onClick = function()
			return applyPreset("bl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.75, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BR",
		onClick = function()
			return applyPreset("br")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.fromOffset(0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RESET",
		onClick = resetLayout,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.new(0.5, 4, 0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "CLOSE",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
	})), React.createElement(Text, {
		value = "Drag the vault, dock and alerts where you want them.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(8, 212),
		sizeConstraint = UDim2.new(1, -16, 0, 56),
	})), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	}), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	})), screen)
end
local function MobileQuickBar(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local hudX = _param.hudX
	local hudY = _param.hudY
	local hudScale = _param.hudScale
	local hudOpacity = _param.hudOpacity
	local buttonSpacing = _param.buttonSpacing
	local minTop = _param.minTop
	local reversed = _param.reversed
	if reversed == nil then
		reversed = false
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local side = math.max(edgePad, chrome.sideSafe)
	local _condition = buttonSpacing
	if _condition == nil then
		_condition = 0.5
	end
	local gap = 4 + math.floor(math.clamp(_condition, 0, 1) * 10)
	local btnH = TapTarget
	local _condition_1 = hudScale
	if _condition_1 == nil then
		_condition_1 = 0.5
	end
	local scale = 0.72 + math.clamp(_condition_1, 0, 1) * 0.28
	local width = math.max(200, (viewport.width - side * 2) * scale)
	local _condition_2 = hudX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local x = math.clamp(_condition_2, (side + width / 2) / viewport.width, 1 - (side + width / 2) / viewport.width)
	local yFallback = 1 - (bottomOffset - height / 2) / viewport.height
	local _condition_3 = hudY
	if _condition_3 == nil then
		_condition_3 = yFallback
	end
	local y = math.clamp(_condition_3, (math.max(viewport.topInset, minTop) + height / 2 + 8) / viewport.height, 1 - (viewport.bottomInset + height / 2 + 8) / viewport.height)
	local _condition_4 = hudOpacity
	if _condition_4 == nil then
		_condition_4 = 0.85
	end
	local surfaceTransparency = math.clamp(0.48 - math.clamp(_condition_4, 0, 1) * 0.48, 0, 0.48)
	local readyPulse = usePulse(vaultReady and vaultFill > 0.8, 2.4)
	local tapReadyAt, setTapReadyAt = React.useState(0)
	local tapLeft, setTapLeft = React.useState(0)
	React.useEffect(function()
		if tapReadyAt <= 0 then
			setTapLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, tapReadyAt - os.clock())
				if not alive then
					break
				end
				setTapLeft(math.ceil(left * 10) / 10)
				if not alive or left <= 0 then
					break
				end
				task.wait(math.max(0.016, left - (math.ceil(left * 10) - 1) / 10))
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.45)
		setTapLeft(0.45)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = 61,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = readyPulse:map(function(amount)
			return if vaultFill > 0.8 then 0.42 - amount * 0.22 else 0.45
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 3),
		Position = UDim2.fromOffset(8, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 62,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFill > 0.92 then Palette.mango else Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, btnH),
		Position = UDim2.fromOffset(8, height - btnH - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 63,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 2 else 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK  {compactNumber(state.Vault)}` else "VAULT EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 1 else 2,
	}, React.createElement(Button, {
		text = if tapLeft > 0.02 then string.format("%.1fs", tapLeft) else "TAP",
		icon = "Forge",
		onClick = tap,
		color = if tapLeft > 0.02 then Palette.panelSoft else Palette.cyan,
		textColor = if tapLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = tapLeft > 0.02,
		highlight = tapLeft <= 0.02,
	}))), chrome.landscape and React.createElement(Text, {
		value = `{compactNumber(state.Production)}/s`,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -12, 0, 6),
		sizeConstraint = UDim2.fromOffset(80, 12),
		zIndex = 64,
	})))
end
return {
	MobileControls = MobileControls,
	MobileQuickBar = MobileQuickBar,
}
end

__defs["floorFx"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local Motion = require(script.Parent.MotionKit)("motionTokens")
local Fx = require(script.Parent.MotionKit)("vfxMath")
local _theme = require(script.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local Text = require(script.Parent.UiCore)("ui").Text
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local SHOCK_LIFE = 0.55
local function ShockRing(_param)
	local trigger = _param.trigger
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local size = _param.size
	if size == nil then
		size = 280
	end
	local clock = useClock(trigger > 0 and not reducedMotion, 1, 1000, true)
	local rings = {}
	for ring = 0, 2 do
		local delay = ring * 0.05
		rings[ring + 1] = React.createElement("frame", {
			key = ring,
			Size = clock:map(function(seconds)
				local grow = Fx.ring(seconds - delay, SHOCK_LIFE)
				local d = 24 + grow * (size * 0.95 + ring * 26)
				return UDim2.fromOffset(d, d)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 81,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then Palette.cream else lighten(color, if ring == 0 then 0.25 else 0),
			Thickness = if ring == 0 then 3 else 2,
			Transparency = clock:map(function(seconds)
				local _, _, fade = Fx.ring(seconds - delay, SHOCK_LIFE)
				return 0.05 + fade * 0.95
			end),
		}))
	end
	return React.createElement("frame", {
		key = `shock-{trigger}`,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(seconds)
			local d = size * (0.16 + 0.42 * Motion.EASE.decelerate(clamp01(seconds / 0.2)))
			return UDim2.fromOffset(d, d)
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = lighten(color, 0.55),
		BackgroundTransparency = clock:map(function(seconds)
			return 0.3 + 0.7 * Motion.EASE.accelerate(clamp01(seconds / 0.24))
		end),
		BorderSizePixel = 0,
		ZIndex = 82,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	})), rings)
end
local Spark
local function SparkBurst(_param)
	local sparks = _param.sparks
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(4, math.min(antilag.maxPops * 2, 28))
	local visible = sparks
	if #sparks > max then
		visible = {}
		for index = #sparks - max + 1, #sparks do
			table.insert(visible, sparks[index])
		end
	end
	local children = table.create(#visible)
	for index, spark in visible do
		children[index] = React.createElement(Spark, {
			key = spark.id,
			spark = spark,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
local SPARK_LIFE = 0.72
local SPARK_GRAVITY = 980
local SPARK_DRAG = 2.6
function Spark(_param)
	local spark = _param.spark
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local crumb = spark.kind == "strike" or spark.kind == "perfect" or spark.kind == "bank"
	local power = if spark.kind == "perfect" then 1.35 elseif spark.kind == "bank" then 1.1 else 0.85
	local thickness = if spark.kind == "perfect" then 5 elseif crumb then 4 else 3.2
	local angle = -math.pi / 2 + (Fx.hash(spark.id, 1) - 0.5) * math.rad(150)
	local speed = (260 + Fx.hash(spark.id, 2) * 260) * power * (if reducedMotion then 0.6 else 1)
	local function velocity(seconds: number): (number, number)
		return Fx.velocity(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
	end
	return React.createElement("frame", {
		Size = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			local length = thickness * 1.4 * Fx.stretch(math.sqrt(vx * vx + vy * vy))
			return UDim2.fromOffset(length, thickness)
		end),
		Position = clock:map(function(seconds)
			local dx, dy = Fx.ballistic(seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG)
			return UDim2.fromScale(spark.x, spark.y) + UDim2.fromOffset(dx, dy)
		end),
		Rotation = clock:map(function(seconds)
			local vx, vy = velocity(seconds)
			return math.deg(math.atan2(vy, vx))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = clock:map(function(seconds)
			return spark.color:Lerp(Palette.white, Fx.heat(seconds, 0.16))
		end),
		BackgroundTransparency = clock:map(function(seconds)
			return Fx.fade(seconds, SPARK_LIFE, 0.3)
		end),
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }),
	}))
end
local ClickPop
local function ClickPops(_param)
	local pops = _param.pops
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(3, math.min(antilag.maxPops, 10))
	local visible = pops
	if #pops > max then
		visible = {}
		for index = #pops - max + 1, #pops do
			table.insert(visible, pops[index])
		end
	end
	local children = table.create(#visible)
	for index, pop in visible do
		children[index] = React.createElement(ClickPop, {
			key = pop.id,
			pop = pop,
			reducedMotion = reducedMotion,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
		Active = false,
		ClipsDescendants = false,
	}, children)
end
local POP_LIFE = 0.8
function ClickPop(_param)
	local pop = _param.pop
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 34 else 24
	local rise = if pop.critical then 118 else 86
	local drift = (Fx.hash(pop.id, 3) - 0.5) * 36
	local tilt = if pop.critical then (Fx.hash(pop.id, 4) - 0.5) * 12 else 0
	local position = clock:map(function(seconds)
		local t = Motion.EASE.decelerate(clamp01(seconds / POP_LIFE))
		return UDim2.fromScale(pop.x, pop.y) + UDim2.fromOffset(drift * t, -t * rise)
	end)
	local scale = clock:map(function(seconds)
		if reducedMotion then
			return 1
		end
		return Fx.popScale(seconds, if pop.critical then 0.24 else 0.18, if pop.critical then 0.55 else 0.4)
	end)
	local color = if pop.critical
		then clock:map(function(seconds)
			return pop.color:Lerp(Palette.white, Fx.heat(seconds, 0.14))
		end)
		else pop.color
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if pop.critical then 168 else 128, 40),
		Position = position,
		Rotation = clock:map(function(seconds)
			return tilt * (1 - Motion.EASE.decelerate(clamp01(seconds / 0.35)))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 97,
	}, React.createElement("uiscale", {
		Scale = scale,
	}), React.createElement(Text, {
		value = pop.text,
		size = size,
		color = color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		transparency = clock:map(function(seconds)
			return Fx.fade(seconds, POP_LIFE, 0.5)
		end),
	}))
end
local function ComboBanner(_param)
	local combo = _param.combo
	local heat = _param.heat
	local perfect = _param.perfect
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(not reducedMotion and combo > 1, 1.05)
	local bump = useFlash(combo, reducedMotion, 0.3)
	local accent = if perfect then Palette.mango elseif heat > 0.82 then Palette.coral else Palette.brass
	if combo <= 1 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 52),
		Position = UDim2.fromScale(0.5, 0.145),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 70,
	}, React.createElement("uiscale", {
		Scale = React.joinBindings({ pulse, bump }):map(function(values)
			return 1 + math.sin(values[1]) * (if perfect then 0.045 else 0.022) + values[2] * 0.16
		end),
	}), React.createElement(Text, {
		value = if perfect then "CRIT" else "STREAK",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = `x{combo}`,
		size = if combo >= 10 then 30 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 14),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
end
local function HeatHaze(_param)
	local heat = _param.heat
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion and heat > 0.12, 0.22)
	local strength = math.clamp(heat, 0, 1)
	if strength <= 0.02 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1.08, 0, 0.42, 0),
		Position = clock:map(function(phase)
			return UDim2.new(-0.04 + math.sin(phase) * 0.02, 0, 0.48 + math.cos(phase * 0.7) * 0.012, 0)
		end),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = 1 - 0.07 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(420, 420),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 1 - 0.05 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function FluxRiver(_param)
	local stations = _param.stations
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local clock = useClock(not reducedMotion, 0.55)
	local _newValue = table.create(#stations)
	local _callback = function(station, index)
		return if station.live then React.createElement("frame", {
			key = `river-{index}`,
			Size = UDim2.fromOffset(3, 3),
			Position = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				local x = station.x + (0.5 - station.x) * t
				local y = station.y + (0.58 - station.y) * t - math.sin(t * math.pi) * 0.04
				return UDim2.fromScale(x, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = station.color,
			BackgroundTransparency = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				return 0.15 + (1 - math.sin(t * math.pi)) * 0.7
			end),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})) else nil
	end
	for _k, _v in stations do
		_newValue[_k] = _callback(_v, _k - 1, stations)
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Active = false,
	}, _newValue, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromOffset(8 + math.sin(phase) * 3, 8 + math.sin(phase) * 3)
		end),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function WorldHaze(_param)
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.07)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.42, darken(color, 0.82)), ColorSequenceKeypoint.new(1, Palette.ink) }),
		Rotation = 118,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(720, 720),
		Position = clock:map(function(phase)
			return UDim2.new(1, 90 + math.sin(phase) * 28, 1, 50 + math.cos(phase * 0.7) * 20)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(460, 460),
		Position = UDim2.new(0, -90, 0, -70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.12) }),
		Rotation = 90,
	})))
end
local function CoreAura(_param)
	local color = _param.color
	local heat = _param.heat
	local squash = _param.squash
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.16)
	local glow = math.clamp(0.16 + heat * 0.22, 0.16, 0.4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 18,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromScale(0.72 + math.sin(phase) * 0.03, 0.72 + math.sin(phase) * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - glow,
		BorderSizePixel = 0,
		ZIndex = 18,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(lighten(color, 0.2), 0.8),
		Rotation = 90,
	})))
end
return {
	ShockRing = ShockRing,
	SparkBurst = SparkBurst,
	ClickPops = ClickPops,
	ComboBanner = ComboBanner,
	HeatHaze = HeatHaze,
	FluxRiver = FluxRiver,
	WorldHaze = WorldHaze,
	CoreAura = CoreAura,
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
