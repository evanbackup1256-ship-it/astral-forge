--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesSky: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesSky: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["SkyKit"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.Parent.CoreKit)("theme").Palette

local function useClock()
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					setNow(workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})
	return now
end

local function corner(radius)
	return React.createElement("uicorner", { CornerRadius = radius or UDim.new(0.5, 0) })
end

local function dot(size, position, color, transparency, extra)
	local kids = { Corner = corner() }
	if extra then
		for key, value in extra do
			kids[key] = value
		end
	end
	return React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
	}, kids)
end

local GLYPH_COLORS = {
	Color3.fromRGB(255, 196, 92),
	Color3.fromRGB(214, 222, 255),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(196, 140, 255),
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(120, 240, 180),
}

-- Each glyph is drawn from primitives so it reads at any size without image assets.
local function Glyph(props)
	local index = props.glyph
	local s = props.size or 34
	local color = GLYPH_COLORS[index] or Palette.muted
	local kids = {}
	local center = UDim2.fromScale(0.5, 0.5)
	if index == 1 then
		for ray = 0, 7 do
			local angle = ray * math.pi / 4
			kids["r" .. ray] = React.createElement("frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(s * 0.18, 2),
				Position = UDim2.new(0.5, math.cos(angle) * s * 0.36, 0.5, math.sin(angle) * s * 0.36),
				Rotation = math.deg(angle),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			})
		end
		kids.Core = dot(s * 0.42, center, color)
	elseif index == 2 then
		kids.Disc = dot(s * 0.62, center, color)
		kids.Bite = dot(s * 0.54, UDim2.new(0.5, s * 0.16, 0.5, -s * 0.08), props.background or Palette.panelSoft)
	elseif index == 3 then
		kids.Tail = React.createElement("frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(s * 0.62, s * 0.16),
			Position = UDim2.new(0.5, s * 0.12, 0.5, s * 0.1),
			Rotation = -28,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, {
			Corner = corner(),
			Fade = React.createElement("uigradient", { Transparency = NumberSequence.new(1, 0) }),
		})
		kids.Head = dot(s * 0.3, UDim2.new(0.5, s * 0.16, 0.5, -s * 0.06), color)
	elseif index == 4 then
		kids.Ring = dot(s * 0.62, center, color, 1, { Stroke = React.createElement("uistroke", { Color = color, Thickness = math.max(2, s * 0.08) }) })
		kids.Pip = dot(s * 0.14, center, color)
	elseif index == 5 then
		for arm = 0, 1 do
			kids["a" .. arm] = React.createElement("frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(s * 0.7, math.max(3, s * 0.1)),
				Position = center,
				Rotation = 45 + arm * 90,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, { Corner = corner() })
		end
		kids.Glint = dot(s * 0.2, center, Color3.new(1, 1, 1))
	else
		kids.Lid = React.createElement("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(s * 0.72, s * 0.38),
			Position = center,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { Corner = corner() })
		kids.Pupil = dot(s * 0.2, center, props.background or Palette.panelSoft)
	end
	return React.createElement("frame", {
		Size = props.frameSize or UDim2.fromOffset(s, s),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, kids)
end

return {
	useClock = useClock,
	corner = corner,
	dot = dot,
	Glyph = Glyph,
	GLYPH_COLORS = GLYPH_COLORS,
}
end

__defs["StarChartsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkyCharts = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SkyCharts"))
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
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
local Text = _ui.Text
local Kit = __load("SkyKit")
local corner = Kit.corner
local SkyViewport = require(script.Parent.Parent.SkyViewport)

local PLATE = 280
local INK = Palette.ink

local function rgb(color)
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function Plate(props)
	local entry = props.entry
	local plotted = props.plotted
	local color = rgb(entry.Color)
	local kids = {
		Corner = corner(UDim.new(0, 18)),
		Stroke = React.createElement("uistroke", { Color = color, Thickness = 1, Transparency = 0.55 }),
		Wash = React.createElement("uigradient", {
			Color = ColorSequence.new(INK, color:Lerp(INK, 0.82)),
			Rotation = 120,
		}),
		Scene = React.createElement(SkyViewport, { entry = entry, plotted = plotted, accent = color, reducedMotion = props.reducedMotion }),
	}
	if not props.open then
		kids.Lock = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 6 }, {
			Corner = corner(UDim.new(0, 18)),
			Label = React.createElement(Text, { value = "Chart the previous constellation to reveal this one.", size = 13, color = Palette.muted, align = Enum.TextXAlignment.Center, position = UDim2.new(0, 20, 0.5, -20), sizeConstraint = UDim2.new(1, -40, 0, 40) }),
		})
	end
	return React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(PLATE, PLATE),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, kids)
end

local function StarChartsView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = props.reducedMotion == true
	local chrome = chromeFor(useViewport())
	local sky = state.Sky
	local plottedMap = if sky then sky.Plotted else {}
	local list = SkyCharts.CONSTELLATIONS

	local function plottedOf(index)
		return plottedMap[list[index].Id] or 0
	end
	local function isOpen(index)
		return index == 1 or plottedOf(index - 1) >= #list[index - 1].Stars
	end
	local firstOpen = 1
	for index = 1, #list do
		if isOpen(index) then
			firstOpen = index
		end
		if plottedOf(index) < #list[index].Stars and isOpen(index) then
			firstOpen = index
			break
		end
	end

	local selected, setSelected = React.useState(firstOpen)
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState(nil)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	local index = math.clamp(selected, 1, #list)
	local entry = list[index]
	local plotted = plottedOf(index)
	local total = #entry.Stars
	local done = plotted >= total
	local open = isOpen(index)
	local cost = if done then 0 else SkyCharts.StarCost(index, plotted)
	local stardust = tonumber(state.Stardust) or 0
	local color = rgb(entry.Color)
	local completed = if sky then sky.Completed else 0

	local function plot()
		if busy or done or not open then
			return
		end
		setBusy(true)
		dispatch("PlotStar", { Id = entry.Id }, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			if response.ok then
				setNote({ text = response.message or "", good = true })
				Audio:play(if response.Result and response.Result.Completed then "puzzleClear" else "collect")
			else
				setNote({ text = response.error or "The chart slipped.", good = false })
				Audio:play("error")
			end
		end)
	end

	local pips = { Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for pip = 1, #list do
		local full = plottedOf(pip) >= #list[pip].Stars
		pips["p" .. pip] = React.createElement("textbutton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(if pip == index then 26 else 14, 14),
			BackgroundColor3 = if full then rgb(list[pip].Color) elseif isOpen(pip) then Palette.panelSoft else INK,
			BorderSizePixel = 0,
			LayoutOrder = pip,
			[React.Event.Activated] = function()
				setSelected(pip)
				setNote(nil)
			end,
		}, {
			Corner = corner(),
			Stroke = React.createElement("uistroke", { Color = if pip == index then color else Palette.line, Thickness = 1, Transparency = if pip == index then 0 else 0.4 }),
		})
	end

	local noteText = if note then note.text elseif done then `{entry.Name} is fully charted.` elseif not open then "Locked." else `Next star costs {compactNumber(cost)} Stardust. {compactNumber(SkyCharts.RemainingCost(index, plotted))} to finish.`
	local noteColor = if note and note.good == false then Palette.coral elseif note then Palette.mint else Palette.muted

	return React.createElement(PageScaffold, {
		gap = 8,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = color,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = 84,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = color, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement(Text, { value = "STAR CHARTS", size = 10, color = color, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, 0, 0, 14) }),
					React.createElement(Text, { value = `Stardust {compactNumber(stardust)}`, size = 20, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(0, 16), sizeConstraint = UDim2.new(1, 0, 0, 28) }),
					React.createElement(Text, { value = `{completed} of {#list} constellations charted. Each one pays out when its last star is set.`, size = 11, color = Palette.muted, position = UDim2.fromOffset(0, 46), sizeConstraint = UDim2.new(1, 0, 0, 16) })
				),
			},
			{
				id = "plate",
				height = PLATE + 110,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = color, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement("frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
						Prev = React.createElement(Button, { text = "<", size = UDim2.fromOffset(48, 48), color = Palette.panelSoft, disabled = index <= 1, reducedMotion = reducedMotion, onClick = function() setSelected(index - 1); setNote(nil) end }),
						Name = React.createElement(Text, { value = `{entry.Name}  ·  {plotted}/{total}`, size = 15, color = Palette.cream, weight = Enum.FontWeight.Heavy, fit = true, minSize = 11, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(56, 12), sizeConstraint = UDim2.new(1, -112, 0, 24) }),
						Next = React.createElement(Button, { text = ">", size = UDim2.fromOffset(48, 48), position = UDim2.new(1, -48, 0, 0), color = Palette.panelSoft, disabled = index >= #list, reducedMotion = reducedMotion, onClick = function() setSelected(index + 1); setNote(nil) end }),
					}),
					React.createElement("frame", { Size = UDim2.new(1, 0, 0, PLATE), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
						Plate = React.createElement(Plate, { entry = entry, plotted = plotted, open = open, reducedMotion = reducedMotion }),
					}),
					React.createElement("frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, PLATE + 62), BackgroundTransparency = 1, BorderSizePixel = 0 }, pips)
				),
			},
			{
				id = "actions",
				height = 158,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = color, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement(Text, { value = entry.Lore, size = 12, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 32) }),
					React.createElement(Text, { value = `Reward: {formatReward(entry.Reward)}`, size = 12, color = color, weight = Enum.FontWeight.Bold, position = UDim2.fromOffset(0, 34), sizeConstraint = UDim2.new(1, 0, 0, 18) }),
					React.createElement(Text, { value = noteText, size = 12, color = noteColor, position = UDim2.fromOffset(0, 54), sizeConstraint = UDim2.new(1, 0, 0, 18) }),
					React.createElement(Button, {
						text = if done then "CHARTED" elseif not open then "LOCKED" else `PLOT STAR · {compactNumber(cost)}`,
						onClick = plot,
						size = UDim2.new(1, 0, 0, 48),
						position = UDim2.fromOffset(0, 78),
						color = if done or not open then Palette.panelSoft else color,
						textColor = if done or not open then Palette.muted else Palette.ink,
						disabled = busy or done or not open or stardust < cost,
						highlight = open and not done and stardust >= cost and not busy,
						reducedMotion = reducedMotion,
					})
				),
			},
		},
	})
end

return {
	StarChartsView = StarChartsView,
}
end

__defs["CipherView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkyCharts = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SkyCharts"))
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
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
local Text = _ui.Text
local Kit = __load("SkyKit")
local useClock, corner, dot, Glyph = Kit.useClock, Kit.corner, Kit.dot, Kit.Glyph
local SkyViewport = require(script.Parent.Parent.SkyViewport)

local CELL = 38
local ROW_H = 46
local GLYPHS = SkyCharts.CIPHER.Glyphs
local LENGTH = SkyCharts.CIPHER.Length
local MAX = SkyCharts.CIPHER.MaxGuesses

local function digits(code: string): { number }
	local out = {}
	for slot = 1, #code do
		out[slot] = tonumber(string.sub(code, slot, slot)) or 0
	end
	return out
end

local function Pegs(props)
	local kids = { Grid = React.createElement("uigridlayout", { CellSize = UDim2.fromOffset(10, 10), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for slot = 1, LENGTH do
		local exact = slot <= props.exact
		local near = not exact and slot <= props.exact + props.near
		kids["p" .. slot] = React.createElement("frame", {
			BackgroundColor3 = if exact then Palette.mint else Palette.panelSoft,
			BackgroundTransparency = if exact or near then 0 else 0.4,
			BorderSizePixel = 0,
			LayoutOrder = slot,
		}, {
			Corner = corner(),
			Stroke = if near then React.createElement("uistroke", { Color = Palette.mango, Thickness = 2 }) else nil,
		})
	end
	return React.createElement("frame", { Size = UDim2.fromOffset(28, 28), Position = props.position, AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, kids)
end

local function Row(props)
	local kids = {}
	for slot = 1, LENGTH do
		local glyph = props.code[slot]
		kids["c" .. slot] = React.createElement("frame", {
			Size = UDim2.fromOffset(CELL, CELL),
			Position = UDim2.new(0, 34 + (slot - 1) * (CELL + 8), 0.5, -CELL / 2),
			BackgroundColor3 = Palette.panelSoft,
			BackgroundTransparency = if glyph then 0 else 0.5,
			BorderSizePixel = 0,
		}, {
			Corner = corner(UDim.new(0, 10)),
			Stroke = React.createElement("uistroke", { Color = if props.active then Palette.cyan else Palette.line, Thickness = 1, Transparency = if props.active then 0.1 else 0.5 }),
			Glyph = if glyph and glyph > 0 then React.createElement(Glyph, { glyph = glyph, size = CELL - 6, position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) }) else nil,
		})
	end
	kids.Index = React.createElement(Text, { value = tostring(props.index), size = 11, color = if props.active then Palette.cyan else Palette.muted, weight = Enum.FontWeight.Bold, position = UDim2.new(0, 6, 0.5, -8), sizeConstraint = UDim2.fromOffset(20, 16) })
	if props.exact then
		kids.Pegs = React.createElement(Pegs, { exact = props.exact, near = props.near, position = UDim2.new(1, -8, 0.5, 0) })
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = if props.active then Palette.panelSoft else Palette.panelRaised,
		BackgroundTransparency = if props.active then 0.4 else 1,
		BorderSizePixel = 0,
		LayoutOrder = props.index,
	}, { Corner = corner(UDim.new(0, 12)), Cells = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, kids) })
end

local function CipherView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = props.reducedMotion == true
	local chrome = chromeFor(useViewport())
	local now = useClock()
	local cipher = if state.Sky then state.Sky.Cipher else nil
	local draft, setDraft = React.useState({})
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState(nil)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	local guesses = if cipher then cipher.Guesses else {}
	local finished = cipher ~= nil and (cipher.Solved or cipher.Failed)
	local accent = if cipher and cipher.Solved then Palette.mint elseif cipher and cipher.Failed then Palette.coral else Palette.cyan

	local function push(glyph)
		if finished or busy or #draft >= LENGTH then
			return
		end
		local nextDraft = table.clone(draft)
		table.insert(nextDraft, glyph)
		setDraft(nextDraft)
		Audio:play("puzzleTap")
	end
	local function pop()
		if #draft == 0 then
			return
		end
		local nextDraft = table.clone(draft)
		table.remove(nextDraft)
		setDraft(nextDraft)
		Audio:play("tick")
	end
	local function submit()
		if busy or finished or #draft < LENGTH then
			return
		end
		setBusy(true)
		dispatch("SubmitCipher", { Code = SkyCharts.Encode(draft) }, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			if response.ok then
				setDraft({})
				setNote({ text = response.message or "", good = true })
				Audio:play(if response.Result and response.Result.Solved then "codeReward" else "codeSubmit")
			else
				setNote({ text = response.error or "The signal scrambled.", good = false })
				Audio:play("error")
			end
		end)
	end

	local rows = { Layout = React.createElement("uilistlayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index = 1, MAX do
		local guess = guesses[index]
		if guess then
			rows["r" .. index] = React.createElement(Row, { index = index, code = digits(guess.Code), exact = guess.Exact, near = guess.Near })
		elseif index == #guesses + 1 and not finished then
			rows["r" .. index] = React.createElement(Row, { index = index, code = draft, active = true })
		else
			rows["r" .. index] = React.createElement(Row, { index = index, code = {} })
		end
	end

	local keys = { Grid = React.createElement("uigridlayout", { CellSize = UDim2.new(1 / 3, -6, 0, 52), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for glyph, name in GLYPHS do
		keys["k" .. glyph] = React.createElement("frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = glyph,
		}, {
			Button = React.createElement(Button, {
				text = "", size = UDim2.fromScale(1, 1), color = Palette.panelSoft,
				reducedMotion = reducedMotion, sound = false,
				disabled = busy or finished or #draft >= LENGTH, onClick = function() push(glyph) end,
				children = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11 },
					React.createElement(Glyph, { glyph = glyph, size = 24, position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5) }),
					React.createElement(Text, { value = name, size = 12, color = Palette.cream, fit = true, minSize = 9, position = UDim2.new(0, 42, 0.5, -9), sizeConstraint = UDim2.new(1, -48, 0, 18), zIndex = 11 })
				),
			}),
		})
	end

	local streak = if cipher then cipher.Streak else 0
	local best = if cipher then cipher.Best else 0
	local nextAt = if cipher then cipher.NextAt else 0
	local status
	if cipher == nil then
		status = "Tuning the receiver..."
	elseif cipher.Solved then
		status = `Decoded in {#guesses}. Next signal in {clockText(math.max(0, nextAt - now))}.`
	elseif cipher.Failed then
		status = `Lost the signal. Next one in {clockText(math.max(0, nextAt - now))}.`
	else
		status = `{MAX - #guesses} attempts left. Green = right glyph, right slot. Ring = right glyph, wrong slot.`
	end
	if note and not finished then
		status = note.text
	end
	local reward = SkyCharts.CipherReward(math.max(1, #guesses + 1), streak + 1)

	local answer = nil
	if cipher and cipher.Answer then
		local kids = { Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) }
		kids.Label = React.createElement(Text, { value = "ANSWER", size = 10, color = accent, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.fromOffset(56, 14) })
		for slot, glyph in digits(cipher.Answer) do
			kids["a" .. slot] = React.createElement(Glyph, { glyph = glyph, size = 26, order = slot })
		end
		answer = React.createElement("frame", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 60), BackgroundTransparency = 1, BorderSizePixel = 0 }, kids)
	end

	return React.createElement(PageScaffold, {
		gap = 8,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = if answer then 102 else 84,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement(Text, { value = "SIGNAL CIPHER", size = 10, color = accent, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, 0, 0, 14) }),
					React.createElement(Text, { value = `Streak {streak}  ·  Best {best}`, size = 20, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(0, 16), sizeConstraint = UDim2.new(1, 0, 0, 28) }),
					React.createElement(Text, { value = status, size = 11, color = if note and note.good == false then Palette.coral else Palette.muted, position = UDim2.fromOffset(0, 44), sizeConstraint = UDim2.new(1, 0, 0, 16) }),
					answer
				),
			},
			{
				id = "receiver",
				height = 128,
				element = React.createElement(SkyViewport, {
					glyphs = draft, colors = Kit.GLYPH_COLORS, accent = accent, reducedMotion = reducedMotion,
				}),
			},
			{
				id = "board",
				height = MAX * (ROW_H + 4) + 28,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, rows)
				),
			},
			{
				id = "keys",
				height = 214,
				element = React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panelRaised, padding = Layout.cardPadding, reducedMotion = reducedMotion },
					React.createElement("frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, BorderSizePixel = 0 }, keys),
					React.createElement(Button, { text = "BACK", onClick = pop, size = UDim2.new(0.3, -4, 0, 44), position = UDim2.fromOffset(0, 120), color = Palette.panelSoft, disabled = busy or finished or #draft == 0, reducedMotion = reducedMotion }),
					React.createElement(Button, {
						text = if finished then "DONE FOR TODAY" else "TRANSMIT",
						onClick = submit,
						size = UDim2.new(0.7, -4, 0, 44),
						position = UDim2.new(0.3, 4, 0, 120),
						color = if finished then Palette.panelSoft else accent,
						textColor = if finished then Palette.muted else Palette.ink,
						disabled = busy or finished or #draft < LENGTH,
						highlight = not finished and #draft == LENGTH and not busy,
						reducedMotion = reducedMotion,
					}),
					React.createElement(Text, { value = if finished then "Solve tomorrow's signal to keep the streak alive." else `Solve now for {formatReward(reward)}`, size = 11, color = Palette.muted, position = UDim2.fromOffset(0, 170), sizeConstraint = UDim2.new(1, 0, 0, 16) })
				),
			},
		},
	})
end

return {
	CipherView = CipherView,
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
