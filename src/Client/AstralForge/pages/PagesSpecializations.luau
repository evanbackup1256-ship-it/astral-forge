--!strict
-- Forge Specializations: pick one of four builds that trade one forge stat for another.
--
-- Layout is a fixed stack of measured sections (no text is left to grow into its neighbour):
--   hero      the equipped build and its four live stats
--   status    when you can switch next, as a meter that empties while the forge reconfigures
--   builds    one card per build: what it trades, how its stats compare with yours, equip
--   foundation bonuses kept from the retired Star Grid
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.Parent.UiCore)("ui")
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local TapTarget = _theme.TapTarget
local useViewport = require(script.Parent.Parent.MotionKit)("motion").useViewport
local Format = require(script.Parent.Parent.CoreKit)("format")
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Specializations = require(game.ReplicatedStorage.AstralForge.Shared.Specializations)
local OmegaMath = require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath)
type Response = { ok: boolean, Uncertain: boolean?, message: string?, error: string? }
type Props = {
	state: { Specialization: Specializations.Snapshot? },
	reducedMotion: boolean?,
	dispatch: (string, { Id: string }, (Response) -> ()) -> (),
}
local h = React.createElement
local unresolved: { Id: string }? = nil

-- how each build looks, and what its trade-off stats are called on screen
local LOOK: { [string]: { icon: string, accent: Color3, tagline: string } } = {
	Balanced = { icon = "Forge", accent = Palette.cyan, tagline = "Even rates, no trade-offs" },
	Handcraft = { icon = "Overcharge", accent = Palette.mango, tagline = "For players who tap" },
	Reserve = { icon = "Vault", accent = Palette.violet, tagline = "For longer gaps between collects" },
	NightShift = { icon = "Timer", accent = Palette.blue, tagline = "For time away from the game" },
}
local STAT_NAME = { Tap = "overcharge", Production = "production", Capacity = "vault size", Offline = "offline earnings" }
local STATS = {
	{ key = "Production", label = "Production", format = function(v) return Format.compactNumber(v) .. "/s" end },
	{ key = "Capacity", label = "Vault", format = function(v) return Format.compactNumber(v) end },
	{ key = "Tap", label = "Overcharge", format = function(v) return Format.compactNumber(v) end },
	{ key = "Offline", label = "Offline", format = function(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) .. "%" end },
}
local GAP = 14
local CARD_H = 268
local CHIP_H = 28

local function lookFor(id: string)
	return LOOK[id] or LOOK.Balanced
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function chip(text: string, accent: Color3, order: number, fill: boolean?)
	return h("frame", {
		Size = UDim2.fromOffset(0, CHIP_H), AutomaticSize = if fill then Enum.AutomaticSize.None else Enum.AutomaticSize.X, LayoutOrder = order,
		BackgroundColor3 = accent, BackgroundTransparency = 0.8, BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }),
		h("uistroke", { Color = accent, Transparency = 0.45, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		h("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		h("textlabel", {
			Size = UDim2.fromScale(if fill then 1 else 0, 1), AutomaticSize = if fill then Enum.AutomaticSize.None else Enum.AutomaticSize.X, BackgroundTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = text, TextSize = 13, TextColor3 = Palette.cream, FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
		}))
end

local function chipRow(children, position: UDim2)
	return h("frame", { Size = UDim2.new(1, 0, 0, CHIP_H), Position = position, BackgroundTransparency = 1 },
		h("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		table.unpack(children))
end

-- one stat: small label over a value, tinted when this build raises or lowers it
local function statTile(label: string, value: string, tint: Color3?, size: UDim2, position: UDim2)
	return h("frame", {
		Size = size, Position = position, BackgroundColor3 = Palette.panelSoft, BackgroundTransparency = 0.25, BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }),
		h("uistroke", {
			Color = tint or Palette.line,
			Thickness = 1,
			Transparency = if tint ~= nil then 0.5 else 0.8,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		h(Ui.Text, { value = string.upper(label), size = 11, color = Palette.muted, weight = Enum.FontWeight.Bold,
			position = UDim2.fromOffset(12, 7), sizeConstraint = UDim2.new(1, -24, 0, 14) }),
		h(Ui.Text, { value = value, size = 16, color = tint or Palette.cream, weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(12, 23), sizeConstraint = UDim2.new(1, -24, 0, 20) }))
end

local function SpecializationsView(props: Props)
	local state = props.state.Specialization
	local note, setNote = React.useState("")
	local busy, setBusy = React.useState(false)
	local pending = React.useRef(false)
	local live = React.useRef(true)
	local timeout = React.useRef(nil)
	local serial = React.useRef(0)
	local viewport = useViewport()
	local stack = chromeFor(viewport).contentStack
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	React.useEffect(function()
		live.current = true
		return function() live.current = false; if timeout.current then task.cancel(timeout.current) end end
	end, {})
	-- tick once a second only while the forge is reconfiguring
	local readyAt = if state then state.ReadyAt else 0
	React.useEffect(function()
		if readyAt <= workspace:GetServerTimeNow() then
			return nil
		end
		local alive = true
		local ticker = task.spawn(function()
			while alive do
				setNow(workspace:GetServerTimeNow())
				if workspace:GetServerTimeNow() >= readyAt then break end
				task.wait(1)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, ticker)
		end
	end, { readyAt })
	local sections = {}
	local function add(key, height, element) table.insert(sections, { id = key, key = key, height = height, element = element, stretch = false }) end
	local function selectBuild(id: string)
		if pending.current then return end
		local order = unresolved or { Id = id }
		unresolved = order
		pending.current = true
		serial.current += 1
		local token = serial.current
		setBusy(true)
		timeout.current = task.delay(20, function()
			if serial.current ~= token then return end
			serial.current += 1
			timeout.current = nil
			pending.current = false
			if live.current then setBusy(false); setNote("No response yet. Retry to confirm the previous build change.") end
		end)
		props.dispatch("SelectSpecialization", order, function(response)
			if not response.Uncertain and unresolved == order then unresolved = nil end
			if serial.current ~= token then return end
			if timeout.current then task.cancel(timeout.current); timeout.current = nil end
			pending.current = false
			if not live.current then return end
			setBusy(false)
			setNote(if response.Uncertain then "The change has not been confirmed. Retry before choosing another build."
				elseif response.ok then response.message or "Build equipped." else response.error or "The build could not be changed.")
		end)
	end

	if not state then
		add("loading", 96, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 18, accent = Palette.mango },
			h(Ui.Text, { value = "Loading your forge build...", size = 16, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) })))
		return h(PageScaffold, { sections = sections, gap = GAP, tailPad = 72, scrollBarColor = Palette.mango })
	end

	local current = lookFor(state.Focus)
	local cooling = state.ReadyAt > now
	local locked = busy or unresolved ~= nil or cooling

	-- hero: the equipped build and its live numbers
	local tileCols = if stack then 2 else 4
	local tileRows = math.ceil(#STATS / tileCols)
	local tileH = 50
	local heroTop = 78
	local heroH = 18 + heroTop + tileRows * tileH + (tileRows - 1) * 10 + 18
	local tiles = {}
	for index, stat in STATS do
		local col, row = (index - 1) % tileCols, (index - 1) // tileCols
		table.insert(tiles, statTile(stat.label, stat.format((state :: any)[stat.key]), nil,
			UDim2.new(1 / tileCols, -10 + 10 / tileCols, 0, tileH),
			UDim2.new(col / tileCols, col * 10 / tileCols, 0, heroTop + row * (tileH + 10))))
	end
	add("hero", heroH, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 18, accent = current.accent, clips = false },
		h(Ui.IconTile, { kind = current.icon, accent = current.accent, size = 56, filled = true, reducedMotion = props.reducedMotion }),
		h(Ui.Text, { value = "EQUIPPED BUILD", size = 12, color = current.accent, weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(72, 2), sizeConstraint = UDim2.new(1, -72, 0, 16) }),
		h(Ui.Text, { value = state.Name, size = 24, weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(72, 18), sizeConstraint = UDim2.new(1, -72, 0, 30) }),
		h(Ui.Text, { value = current.tagline, size = 14, color = Palette.muted,
			position = UDim2.fromOffset(72, 48), sizeConstraint = UDim2.new(1, -72, 0, 18) }),
		table.unpack(tiles)))

	-- status: switching is free, but the forge needs time to reconfigure between switches
	local remaining = math.max(0, state.ReadyAt - now)
	add("status", 92, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 16, accent = if cooling then Palette.mango else Palette.green },
		h(Ui.IconTile, { kind = if cooling then "Timer" else "Check", accent = if cooling then Palette.mango else Palette.green,
			size = 40, reducedMotion = props.reducedMotion }),
		h(Ui.Text, { value = if cooling then `Reconfiguring · next switch in {clock(remaining)}` else "Ready to switch. Changing builds is free.",
			size = 16, weight = Enum.FontWeight.Bold, fit = true, minSize = 12, position = UDim2.fromOffset(54, 0), sizeConstraint = UDim2.new(1, -54, 0, 20) }),
		if cooling
			then h(Ui.Meter, { value = 1 - remaining / math.max(1, state.Cooldown), color = Palette.mango, reducedMotion = props.reducedMotion,
				position = UDim2.fromOffset(54, 30), size = UDim2.new(1, -54, 0, 8) })
			else h(Ui.Text, { value = `After a switch the forge needs {math.ceil(state.Cooldown / 60)} minutes before the next one.`,
				size = 13, color = Palette.muted, wrap = true, position = UDim2.fromOffset(54, 24), sizeConstraint = UDim2.new(1, -54, 0, 36) })))

	if unresolved then
		add("retry", TapTarget, h(Ui.Button, { text = "Confirm your last build change", size = UDim2.fromScale(1, 1),
			color = Palette.mango, disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function() selectBuild((unresolved :: { Id: string }).Id) end }))
	end
	if note ~= "" then
		add("response", 28, h(Ui.Text, { value = note, size = 14, color = Palette.creamSoft, sizeConstraint = UDim2.new(1, 0, 0, 24) }))
	end

	-- the four builds, two to a row on wide screens
	local columns = if stack then 1 else 2
	local rows = math.ceil(#state.Builds / columns)
	local cards = {}
	for index, build in state.Builds do
		local look = lookFor(build.Id)
		local equipped = state.Focus == build.Id
		local positive = math.floor((build.GainMultiplier - 1) * 100 + 0.5)
		local negative = math.floor((1 - build.CostMultiplier) * 100 + 0.5)
		local chips = if build.Gain ~= ""
			then { chip(`+{positive}% {STAT_NAME[build.Gain] or build.Gain}`, Palette.green, 1), chip(`-{negative}% {STAT_NAME[build.Cost] or build.Cost}`, Palette.coral, 2) }
			else { chip("No trade-offs", Palette.cyan, 1) }
		local compare = {}
		for statIndex, stat in STATS do
			local col, row = (statIndex - 1) % 2, (statIndex - 1) // 2
			-- compare with what you have now: higher reads green, lower reads red
			local ok, order = pcall(OmegaMath.Compare, (build :: any)[stat.key], (state :: any)[stat.key])
			local tint = if equipped or not ok then nil elseif order > 0 then Palette.green elseif order < 0 then Palette.coral else nil
			table.insert(compare, statTile(stat.label, stat.format((build :: any)[stat.key]), tint,
				UDim2.new(0.5, -5, 0, 44), UDim2.new(col * 0.5, col * 5, 0, 88 + row * 50)))
		end
		local col, row = (index - 1) % columns, (index - 1) // columns
		cards[build.Id] = h("frame", {
			Size = UDim2.new(1 / columns, -GAP + GAP / columns, 0, CARD_H),
			Position = UDim2.new(col / columns, col * GAP / columns, 0, row * (CARD_H + GAP)),
			BackgroundTransparency = 1,
		}, h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 16, accent = look.accent, clips = false,
			highlight = equipped, reducedMotion = props.reducedMotion },
			h(Ui.IconTile, { kind = look.icon, accent = look.accent, size = 44, filled = equipped, glow = equipped and not props.reducedMotion, reducedMotion = props.reducedMotion }),
			h(Ui.Text, { value = build.Name, size = 19, weight = Enum.FontWeight.Heavy,
				position = UDim2.fromOffset(58, 0), sizeConstraint = UDim2.new(1, -150, 0, 24) }),
			h(Ui.Text, { value = look.tagline, size = 13, color = Palette.muted,
				position = UDim2.fromOffset(58, 25), sizeConstraint = UDim2.new(1, -58, 0, 18) }),
			equipped and h(Ui.Badge, { value = "EQUIPPED", accent = look.accent, filled = true,
				position = UDim2.new(1, -88, 0, 4), size = UDim2.fromOffset(88, 24) }) or nil,
			chipRow(chips, UDim2.fromOffset(0, 54)),
			h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, table.unpack(compare)),
			h(Ui.Button, { text = if equipped then "Equipped" elseif cooling then `Ready in {clock(remaining)}` else "Equip " .. build.Name,
				size = UDim2.new(1, 0, 0, 44), position = UDim2.new(0, 0, 1, -44),
				color = look.accent, textColor = Palette.ink,
				disabled = locked or equipped, reducedMotion = props.reducedMotion,
				onClick = function() selectBuild(build.Id) end })))
	end
	add("builds", rows * CARD_H + (rows - 1) * GAP, h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cards))

	-- the old Star Grid's purchased bonuses still apply to every build
	if #state.Foundation > 0 then
		local chips = {}
		for index, bonus in state.Foundation do
			local percent = bonus.Value * 100
			local shown = if percent < 1000 then string.format("%.1f", percent) else Format.compactNumber(percent)
			table.insert(chips, chip(`{bonus.Name} +{shown}%`, Palette.creamSoft, index, true))
		end
		local perRow = if stack then 2 else 4
		local chipRows = math.ceil(#chips / perRow)
		add("foundation", 52 + chipRows * (CHIP_H + 8), h(Ui.Panel, { size = UDim2.fromScale(1, 1), padding = 16, accent = Palette.creamSoft },
			h(Ui.Text, { value = "Kept from the Star Grid · applies to every build", size = 14, color = Palette.muted, weight = Enum.FontWeight.Bold,
				sizeConstraint = UDim2.new(1, 0, 0, 18) }),
			h("frame", { Size = UDim2.new(1, 0, 0, chipRows * (CHIP_H + 8)), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1 },
				h("uigridlayout", { CellSize = UDim2.new(1 / perRow, -8, 0, CHIP_H), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				table.unpack(chips))))
	end
	add("rules", 40, h(Ui.Text, { value = "Builds change rates going forward only. Collect your vault before moving to a build with a smaller vault.",
		size = 13, color = Palette.muted, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 36) }))
	return React.createElement(PageScaffold, { sections = sections, gap = GAP, tailPad = 72, scrollBarColor = current.accent })
end
return function() return { SpecializationsView = SpecializationsView } end
