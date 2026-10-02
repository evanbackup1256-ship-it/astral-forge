--!nonstrict
--[=[
	PagesCasino: the Astral Casino page suite.
	Members (1): CasinoView.

	Same shape as the other page suites: `require(<this module>)("CasinoView")` (or index it) returns that
	member's exports, evaluated lazily once. Every roll, stake and payout happens on the server
	(CasinoService); this page only picks a stake, sends one CasinoPlay action and draws what comes back.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesCasino: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesCasino: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: CasinoView
-- ======================================================================
__defs["CasinoView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
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
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text

local TABS = {
	{ id = "Slots", label = "Slots", accent = Palette.mango },
	{ id = "Flip", label = "Coin Flip", accent = Palette.cyan },
	{ id = "HighLow", label = "High-Low", accent = Palette.violet },
	{ id = "Roulette", label = "Roulette", accent = Palette.coral },
	{ id = "Scratch", label = "Scratch", accent = Palette.pink },
	{ id = "Exchange", label = "Exchange", accent = Palette.mint },
	{ id = "Club", label = "Club", accent = Palette.mango },
}

local SYMBOL_COLORS = {
	Ember = Palette.coral,
	Dust = Palette.cyan,
	Core = Palette.mint,
	Comet = Palette.violet,
	Star = Palette.mango,
	Nova = Palette.pink,
	Spark = Palette.mango,
}
local SLOT_IDS = { "Ember", "Dust", "Core", "Comet", "Star", "Nova" }
local SCRATCH_IDS = { "Spark", "Dust", "Core", "Comet", "Star", "Nova" }
local CARD_NAMES = { [1] = "A", [11] = "J", [12] = "Q", [13] = "K" }

local function cardName(card)
	return CARD_NAMES[card] or tostring(card)
end

local function percent(chance)
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

local function times(multiplier)
	if multiplier >= 100 then
		return string.format("x%d", math.floor(multiplier + 0.5))
	end
	return string.format("x%.2f", multiplier)
end

-- ----- small building blocks --------------------------------------------------------------------

local function Stack(props)
	local kids = {
		List = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, props.gap or 8),
		}),
	}
	for index, child in props.children do
		kids["c" .. index] = child
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, kids)
end

local function Line(props)
	return React.createElement(Text, {
		value = props.value,
		size = props.size or 13,
		color = props.color or Palette.muted,
		weight = props.weight or Enum.FontWeight.Medium,
		wrap = props.wrap ~= false,
		align = props.align,
		sizeConstraint = UDim2.new(1, 0, 0, props.height or 20),
		layoutOrder = props.order or 0,
	})
end

local function Row(props)
	local list = { Layout = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.gap or 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}) }
	for index, child in props.children do
		list["c" .. index] = child
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, props.height or 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order or 0,
	}, list)
end

-- n equal buttons across a row.
local function Buttons(props)
	local count = #props.items
	local gap = props.gap or 6
	local children = {}
	for index, item in props.items do
		children[index] = React.createElement(Button, {
			text = item.text,
			onClick = item.onClick,
			size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
			color = item.color,
			textColor = item.textColor,
			disabled = item.disabled == true,
			highlight = item.highlight == true,
			reducedMotion = props.reducedMotion,
			layoutOrder = index,
		})
	end
	return React.createElement(Row, { height = props.height or 46, gap = gap, order = props.order, children = children })
end

-- A rounded tile with one big word (a reel, a card, a scratch cell, a roulette number).
local function Tile(props)
	return React.createElement("frame", {
		Size = props.size or UDim2.new(0.31, 0, 1, 0),
		BackgroundColor3 = props.fill or Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order or 0,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("uistroke", { Color = props.color or Palette.line, Thickness = 2, Transparency = 0.2 }),
		Label = React.createElement(Text, {
			value = props.value,
			size = props.textSize or 22,
			color = props.color or Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 11,
		}),
	})
end

local function stakeLine(state, tier)
	local stake = state.Casino.Stakes[tier]
	if stake == nil then
		return ""
	end
	return `Stake: {compactNumber(stake.Amount)} flux ({stake.Share * 100}% of yours)`
end

-- One rank in the club ladder: its name, what it pays, and a claim button when it is earned.
local function ClubRankRow(props)
	local rank = props.rank
	local reward = if rank.Reward then formatReward(rank.Reward) else "Welcome"
	local text, color, textColor, disabled, highlight = `{rank.XP} XP`, Palette.panelSoft, nil, true, false
	if rank.Claimed then
		text = "CLAIMED"
	elseif rank.Claimable then
		text, color, textColor, disabled, highlight = "CLAIM", Palette.mango, Palette.ink, props.busy, true
	end
	return React.createElement(Row, { height = 38, order = props.order, gap = 8, children = {
		React.createElement(Text, { value = `{rank.Name}: {reward}`, size = 12, color = if props.reached then Palette.cream else Palette.muted, sizeConstraint = UDim2.new(0.66, 0, 1, 0), layoutOrder = 1 }),
		React.createElement(Button, {
			text = text,
			onClick = function()
				if rank.Claimable and not rank.Claimed then
					props.play({ Game = "Club", Rank = rank.Rank })
				end
			end,
			size = UDim2.new(0.3, 0, 1, 0),
			color = color,
			textColor = textColor,
			disabled = disabled,
			highlight = highlight,
			reducedMotion = props.reducedMotion,
			layoutOrder = 2,
		}),
	} })
end

-- ----- the page --------------------------------------------------------------------------------------

local function CasinoView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = props.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local reveal = useStagger(0, reducedMotion)
	local casino = state.Casino

	local tab, setTab = React.useState("Slots")
	local tier, setTier = React.useState(2)
	local busy, setBusy = React.useState(false)
	local shake, setShake = React.useState(0)
	local note, setNote = React.useState({ text = "Pick a game and a stake. The house keeps a few percent, and you can walk away any time.", good = nil })
	local last, setLast = React.useState({})
	local spinning, setSpinning = React.useState(false)
	local shown, setShown = React.useState({ "Ember", "Dust", "Core" })
	local pick, setPick = React.useState("Red")
	local straight, setStraight = React.useState(17)
	local revealed, setRevealed = React.useState(6)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	-- One tap, one server round. `visual` runs when the answer is in (after any reel animation).
	local function play(payload, visual, minimum)
		if busy or casino == nil then
			return
		end
		setBusy(true)
		local started = os.clock()
		dispatch("CasinoPlay", payload, function(response)
			local function settle()
				if not mounted.current then
					return
				end
				setBusy(false)
				setSpinning(false)
				if response.ok then
					local result = response.Result or {}
					setLast(result)
					if visual then
						visual(result)
					end
					local good = if result.Won == nil then nil else result.Won
					setNote({ text = response.message or "", good = good })
					Audio:play(if good == true and result.Payout ~= nil and result.Payout ~= 0 then "purchase" else "confirm")
				else
					setNote({ text = response.error or "That didn't go through.", good = false })
					setShake(shake + 1)
					Audio:play("error")
				end
			end
			local wait = (minimum or 0) - (os.clock() - started)
			if wait > 0 and response.ok then
				task.delay(wait, settle)
			else
				settle()
			end
		end)
	end

	-- Reel flicker while a spin is in flight.
	React.useEffect(function()
		if not spinning or reducedMotion then
			return nil
		end
		local alive = true
		task.spawn(function()
			while alive and mounted.current do
				setShown({ SLOT_IDS[math.random(#SLOT_IDS)], SLOT_IDS[math.random(#SLOT_IDS)], SLOT_IDS[math.random(#SLOT_IDS)] })
				task.wait(0.07)
			end
		end)
		return function()
			alive = false
		end
	end, { spinning, reducedMotion })

	if casino == nil then
		return React.createElement(PageScaffold, {
			gap = 0,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
			sections = { {
				id = "loading",
				height = 80,
				element = React.createElement(Text, { value = "The casino is warming up...", size = 14, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }),
			} },
		})
	end

	local accent = Palette.mango
	for _, entry in TABS do
		if entry.id == tab then
			accent = entry.accent
		end
	end
	local stakes = casino.Stakes
	local noteColor = if note.good == true then Palette.mint elseif note.good == false then Palette.coral else Palette.muted

	local function stakePicker(order, locked)
		local items = {}
		for index, stake in stakes do
			items[index] = {
				text = stake.Name,
				onClick = function()
					setTier(index)
				end,
				color = if tier == index then accent else Palette.panelSoft,
				textColor = if tier == index then Palette.ink else Palette.cream,
				disabled = locked == true,
			}
		end
		return React.createElement(Buttons, { items = items, height = 40, order = order, reducedMotion = reducedMotion })
	end

	-- ------------------------------------------------------------------ slots
	local function slotsBody()
		local reelTiles = {}
		local reels = if spinning then shown elseif last.Game == "Slots" and last.Reels then last.Reels else shown
		for index = 1, 3 do
			reelTiles[index] = React.createElement(Tile, { value = string.upper(reels[index]), color = SYMBOL_COLORS[reels[index]] or Palette.cream, order = index, size = UDim2.new(0.32, 0, 1, 0) })
		end
		local pays = {}
		for _, symbol in casino.Slots.Symbols do
			table.insert(pays, `{symbol.Id} {symbol.Pay3}x`)
		end
		return {
			React.createElement(Line, { value = "STARLIGHT SLOTS", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 78, order = 2, gap = 8, children = reelTiles }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 38, order = 3 }),
			stakePicker(4, busy),
			React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = { {
				text = if busy then "SPINNING..." else "SPIN",
				onClick = function()
					setSpinning(true)
					play({ Game = "Slots", Tier = tier }, function(result)
						if result.Reels then
							setShown(result.Reels)
						end
					end, 0.9)
				end,
				color = Palette.mango,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			} }, height = 50, order = 6, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Three alike pays: {table.concat(pays, "  ")}. Two Embers or Dusts pay a little. Returns {percent(casino.Slots.Rtp)}.`, size = 11, height = 44, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ coin flip
	local function flipBody()
		local flip = casino.Flip
		local face = if last.Game == "Flip" then (if last.Heads == false then "TAILS" elseif last.Heads then "HEADS" else "?") else "?"
		local items = {}
		if flip.Active then
			items[1] = {
				text = if busy then "..." else `FLIP AGAIN ({times(flip.NextMultiplier)})`,
				onClick = function()
					play({ Game = "Flip", Op = "Flip" })
				end,
				color = Palette.cyan,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			}
			items[2] = {
				text = if flip.Streak > 0 then `CASH OUT {compactNumber(flip.Cashout)}` else "FLIP FIRST",
				onClick = function()
					play({ Game = "Flip", Op = "Cashout" })
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy or flip.Streak < 1,
			}
		else
			items[1] = {
				text = if busy then "..." else "FLIP THE COIN",
				onClick = function()
					play({ Game = "Flip", Op = "Flip", Tier = tier })
				end,
				color = Palette.cyan,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			}
		end
		return {
			React.createElement(Line, { value = "DOUBLE OR NOTHING", size = 11, color = Palette.cyan, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 78, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = face, color = if face == "TAILS" then Palette.coral elseif face == "HEADS" then Palette.mint else Palette.cream, size = UDim2.new(0.4, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = if flip.Active then `{flip.Streak} in a row` else "no round", color = Palette.cyan, textSize = 15, size = UDim2.new(0.4, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 38, order = 3 }),
			if flip.Active then React.createElement(Line, { value = `Stake {compactNumber(flip.Stake)} flux, now worth {times(flip.Multiplier)}. Heads doubles it (x1.92 each); one tails loses the lot.`, size = 12, order = 4, height = 34 }) else stakePicker(4),
			if flip.Active then React.createElement(Line, { value = "", order = 5, height = 2 }) else React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = items, height = 50, order = 6, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Each flip is {percent(flip.Chance)} to land heads. The streak caps at {flip.MaxStreak}.`, size = 11, height = 30, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ high-low
	local function highLowBody()
		local round = casino.HighLow
		local showCard = if round.Active then round.Card elseif last.Game == "HighLow" and last.Card then last.Card else nil
		local items = {}
		if round.Active then
			items[1] = {
				text = if round.High.Chance > 0 then `HIGHER {percent(round.High.Chance)} ({times(round.High.Step)})` else "HIGHER (none)",
				onClick = function()
					play({ Game = "HighLow", Op = "Guess", Pick = "High" })
				end,
				color = Palette.violet,
				textColor = Palette.ink,
				disabled = busy or round.High.Chance <= 0,
			}
			items[2] = {
				text = if round.Low.Chance > 0 then `LOWER {percent(round.Low.Chance)} ({times(round.Low.Step)})` else "LOWER (none)",
				onClick = function()
					play({ Game = "HighLow", Op = "Guess", Pick = "Low" })
				end,
				color = Palette.blue,
				textColor = Palette.ink,
				disabled = busy or round.Low.Chance <= 0,
			}
		else
			items[1] = {
				text = if busy then "..." else "DEAL A CARD",
				onClick = function()
					play({ Game = "HighLow", Op = "Start", Tier = tier })
				end,
				color = Palette.violet,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			}
		end
		return {
			React.createElement(Line, { value = "HIGH-LOW LADDER", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 78, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = if showCard then cardName(showCard) else "?", color = Palette.violet, size = UDim2.new(0.3, 0, 1, 0), order = 1, textSize = 34 }),
				React.createElement(Tile, { value = if round.Active then `{round.Streak} right` else "no round", color = Palette.cream, textSize = 15, size = UDim2.new(0.3, 0, 1, 0), order = 2 }),
				React.createElement(Tile, { value = if round.Active then times(round.Multiplier) else "x1.00", color = Palette.mango, textSize = 20, size = UDim2.new(0.3, 0, 1, 0), order = 3 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 38, order = 3 }),
			if round.Active then React.createElement(Line, { value = `Stake {compactNumber(round.Stake)} flux. A tie loses. Cards run Ace (low) to King (high).`, size = 12, order = 4, height = 34 }) else stakePicker(4),
			if round.Active then React.createElement(Line, { value = "", order = 5, height = 2 }) else React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = items, height = 50, order = 6, reducedMotion = reducedMotion }),
			if round.Active then React.createElement(Buttons, { items = { {
				text = if round.Streak > 0 then `CASH OUT {compactNumber(round.Cashout)}` else "WIN A GUESS FIRST",
				onClick = function()
					play({ Game = "HighLow", Op = "Cashout" })
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy or round.Streak < 1,
			} }, height = 44, order = 7, reducedMotion = reducedMotion }) else React.createElement(Line, { value = "Every guess pays 96% of its true odds, so the safer the guess the smaller the step.", size = 11, height = 30, order = 7 }),
		}
	end

	-- ------------------------------------------------------------------ roulette
	local function rouletteBody()
		local function option(label, id)
			return {
				text = label,
				onClick = function()
					setPick(id)
				end,
				color = if pick == id then Palette.coral else Palette.panelSoft,
				textColor = if pick == id then Palette.ink else Palette.cream,
				disabled = busy,
			}
		end
		local resultNumber = if last.Game == "Roulette" then last.Number else nil
		local resultColor = if last.Game == "Roulette" then last.Color else nil
		local numberFill = if resultColor == "Red" then Palette.coral elseif resultColor == "Green" then Palette.mint else Palette.panelSoft
		local picked = if string.sub(pick, 1, 1) == "N" then `Number {string.sub(pick, 2)} pays x36` else `{pick} pays x{(pick == "D1" or pick == "D2" or pick == "D3" or pick == "C1" or pick == "C2" or pick == "C3") and 3 or 2}`
		return {
			React.createElement(Line, { value = "ASTRAL ROULETTE", size = 11, color = Palette.coral, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 64, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = if resultNumber then tostring(resultNumber) else "--", fill = numberFill, color = Palette.cream, size = UDim2.new(0.25, 0, 1, 0), order = 1, textSize = 30 }),
				React.createElement(Tile, { value = picked, color = Palette.coral, textSize = 14, size = UDim2.new(0.6, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
			React.createElement(Buttons, { items = { option("Red", "Red"), option("Black", "Black"), option("Odd", "Odd"), option("Even", "Even") }, height = 36, order = 4, reducedMotion = reducedMotion }),
			React.createElement(Buttons, { items = { option("1-18", "Low"), option("19-36", "High"), option("1st 12", "D1"), option("2nd 12", "D2"), option("3rd 12", "D3") }, height = 36, order = 5, reducedMotion = reducedMotion }),
			React.createElement(Buttons, { items = {
				option("Col 1", "C1"), option("Col 2", "C2"), option("Col 3", "C3"),
				{ text = "-", onClick = function() setStraight((straight + 36) % 37) end, color = Palette.panelSoft, disabled = busy },
				option(`Number {straight}`, `N{straight}`),
				{ text = "+", onClick = function() setStraight((straight + 1) % 37) end, color = Palette.panelSoft, disabled = busy },
			}, height = 36, order = 6, reducedMotion = reducedMotion }),
			stakePicker(7, busy),
			React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 8, height = 18 }),
			React.createElement(Buttons, { items = { {
				text = if busy then "..." else "SPIN THE WHEEL",
				onClick = function()
					play({ Game = "Roulette", Tier = tier, Pick = pick })
				end,
				color = Palette.coral,
				textColor = Palette.ink,
				disabled = busy,
				highlight = not busy,
			} }, height = 48, order = 9, reducedMotion = reducedMotion }),
		}
	end

	-- ------------------------------------------------------------------ scratch cards
	local function scratchBody()
		local scratch = casino.Scratch
		local cells = if last.Game == "Scratch" and last.Cells then last.Cells else nil
		local function cellRow(first)
			local row = {}
			for index = first, first + 2 do
				local id = cells and cells[index]
				local hidden = cells == nil or index > revealed
				row[#row + 1] = React.createElement(Tile, { value = if hidden then "?" else string.upper(id), color = if hidden then Palette.muted else (SYMBOL_COLORS[id] or Palette.cream), textSize = 17, order = index, size = UDim2.new(0.31, 0, 1, 0) })
			end
			return row
		end
		local function scratch_(free)
			setRevealed(0)
			play({ Game = "Scratch", Tier = tier, Free = free }, function(result)
				if reducedMotion then
					setRevealed(6)
					return
				end
				for index = 1, 6 do
					task.delay(index * 0.18, function()
						if mounted.current then
							setRevealed(index)
						end
					end)
				end
			end)
		end
		local items = {
			{ text = if busy then "..." else "BUY A CARD", onClick = function() scratch_(false) end, color = Palette.pink, textColor = Palette.ink, disabled = busy, highlight = not busy },
		}
		if scratch.FreeReady then
			table.insert(items, 1, { text = "FREE DAILY CARD", onClick = function() scratch_(true) end, color = Palette.mint, textColor = Palette.ink, disabled = busy, highlight = not busy })
		end
		local pays = {}
		for _, symbol in casino.Scratch.Symbols do
			table.insert(pays, `{symbol.Id} {symbol.Pay}x`)
		end
		return {
			React.createElement(Line, { value = "SCRATCH CARDS", size = 11, color = Palette.pink, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 56, order = 2, gap = 8, children = cellRow(1) }),
			React.createElement(Row, { height = 56, order = 3, gap = 8, children = cellRow(4) }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 4 }),
			stakePicker(5, busy),
			React.createElement(Line, { value = stakeLine(state, tier), size = 12, order = 6, height = 18 }),
			React.createElement(Buttons, { items = items, height = 48, order = 7, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Match three or more of one symbol: {table.concat(pays, "  ")}. Returns {percent(casino.Scratch.Rtp)}. The daily card is free, at the Pocket stake.`, size = 11, height = 44, order = 8 }),
		}
	end

	-- ------------------------------------------------------------------ exchange
	local function exchangeBody()
		local market = casino.Exchange
		local delta = math.floor((market.Mood - 1) * 100 + 0.5)
		local trend = if market.Trend > 0.02 then "rising" elseif market.Trend < -0.02 then "falling" else "steady"
		local remaining = math.max(0, market.NextAt - os.time())
		local function buy(count)
			return {
				text = `BUY {count}`,
				onClick = function()
					play({ Game = "Exchange", Count = count })
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy or market.Left < count,
			}
		end
		return {
			React.createElement(Line, { value = "STARDUST EXCHANGE", size = 11, color = Palette.mint, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 64, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `{compactNumber(market.Price)} flux`, color = Palette.mint, textSize = 18, size = UDim2.new(0.48, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = `{if delta >= 0 then "+" else ""}{delta}% {trend}`, color = if delta <= 0 then Palette.mint else Palette.coral, textSize = 15, size = UDim2.new(0.48, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Line, { value = `One Stardust costs the price above. The market moves every ten minutes (next change in {clockText(remaining)}), the same for everyone, and is cheaper when it is below par.`, size = 12, height = 48, order = 3 }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 24, order = 4 }),
			React.createElement(Line, { value = `{market.Left} of {market.Cap} Stardust left to buy today.`, size = 12, order = 5, height = 18 }),
			React.createElement(Buttons, { items = { buy(1), buy(5), buy(20) }, height = 48, order = 6, reducedMotion = reducedMotion }),
		}
	end

	-- ------------------------------------------------------------------ club
	local function clubBody()
		local club = casino.Club
		local stats = casino.Stats
		local rows = {}
		for index, rank in club.Ranks do
			rows[index] = React.createElement(ClubRankRow, { rank = rank, reached = rank.Rank <= club.Rank, busy = busy, order = 10 + index, play = play, reducedMotion = reducedMotion })
		end
		local progress = if club.NextXP then math.clamp(club.XP / club.NextXP, 0, 1) else 1
		local children = {
			React.createElement(Line, { value = "HIGH ROLLER CLUB", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{club.RankName}  /  {club.XP} XP{if club.NextXP then " of " .. club.NextXP else " (top rank)"}`, size = 16, color = Palette.cream, weight = Enum.FontWeight.Heavy, height = 24, order = 2 }),
			React.createElement("frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Palette.panelSoft, BorderSizePixel = 0, LayoutOrder = 3 }, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }),
				Fill = React.createElement("frame", { Size = UDim2.fromScale(progress, 1), BackgroundColor3 = Palette.mango, BorderSizePixel = 0 }, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }) }),
			}),
			React.createElement(Line, { value = `Every round earns Club XP (bigger stakes earn more). Played {stats.Played}, won {stats.Won}. Best streak {stats.BestStreak}, biggest win {compactNumber(stats.BiggestWin)} flux.`, size = 12, height = 48, order = 4 }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 22, order = 5 }),
		}
		for _, row in rows do
			table.insert(children, row)
		end
		return children
	end

	local bodies = { Slots = slotsBody, Flip = flipBody, HighLow = highLowBody, Roulette = rouletteBody, Scratch = scratchBody, Exchange = exchangeBody, Club = clubBody }
	local heights = { Slots = 372, Flip = 372, HighLow = 396, Roulette = 462, Scratch = 428, Exchange = 322, Club = 120 + #casino.Club.Ranks * 44 + 80 }
	local panelHeight = heights[tab] or 400

	local stats = casino.Stats
	return React.createElement(PageScaffold, {
		gap = 8,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = 84,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reveal = reveal,
					reducedMotion = reducedMotion,
				}, React.createElement(Text, {
					value = "ASTRAL CASINO",
					size = 10,
					color = accent,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 14),
				}), React.createElement(Text, {
					value = `Flux {compactNumber(state.Cash)}  /  {casino.Club.RankName}`,
					size = 18,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 16),
					sizeConstraint = UDim2.new(1, 0, 0, 26),
				}), React.createElement(Text, {
					value = `Stakes are a share of your flux. A round never pays more than 4x what you had. Won {stats.Won} of {stats.Played}.`,
					size = 11,
					color = Palette.muted,
					wrap = true,
					position = UDim2.fromOffset(0, 44),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				})),
			},
			{
				id = "tabs",
				height = 96,
				element = React.createElement(SegmentedTabs, {
					options = TABS,
					value = tab,
					onChange = setTab,
					columns = 4,
					accent = accent,
					size = UDim2.new(1, 0, 0, 96),
					reducedMotion = reducedMotion,
				}),
			},
			{
				id = "game",
				height = panelHeight,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reducedMotion = reducedMotion,
				}, React.createElement(Stack, { gap = 8, children = bodies[tab]() })),
			},
		},
	})
end

return {
	CasinoView = CasinoView,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
