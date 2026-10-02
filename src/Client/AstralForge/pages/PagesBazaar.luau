--!nonstrict
--[=[
	PagesBazaar: the Astral Bazaar page suite.
	Members (1): BazaarView.

	A bank (savings with interest, term deposits), a black market with hourly stock, a server lottery and
	daily merchant contracts. Everything is decided by BazaarService on the server; this page sends one
	BazaarPlay action per tap and performs what comes back, using the casino's building blocks (PagesCasino.Kit)
	and its sounds, so the two hubs look and sound like one place.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesBazaar: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesBazaar: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: BazaarView
-- ======================================================================
__defs["BazaarView"] = function()
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
local Kit = require(script.Parent.PagesCasino)("CasinoView").Kit
local Stack, Line, Row, Buttons, Tile = Kit.Stack, Kit.Line, Kit.Row, Kit.Buttons, Kit.Tile
local Marquee, Confetti, ShineBar = Kit.Marquee, Kit.Confetti, Kit.ShineBar
local sfx, useRender, outCubic = Kit.sfx, Kit.useRender, Kit.outCubic

local TABS = {
	{ id = "Bank", label = "Bank", accent = Palette.mint },
	{ id = "Market", label = "Black Market", accent = Palette.violet },
	{ id = "Lottery", label = "Lottery", accent = Palette.mango },
	{ id = "Contracts", label = "Contracts", accent = Palette.cyan },
}

local TERM_NAMES = { T1 = "1 hour", T6 = "6 hours", T24 = "24 hours" }
local SHARES = { "10%", "25%", "50%", "All" }
local WITHDRAW_SHARES = { "25%", "50%", "All" }

local function percent(rate)
	return string.format("%d%%", math.floor(rate * 100 + 0.5))
end

-- Wall-clock seconds that tick once a second, so countdowns stay live between server pushes.
local function useClock()
	local now, setNow = React.useState(os.time())
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					setNow(os.time())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})
	return now
end

-- A deal on the black market: the discount badge, what it gives, the price and the stock left in pips.
local function DealCard(props)
	local offer = props.offer
	local soldOut = offer.Left <= 0
	local pips = {}
	for index = 1, offer.Stock do
		pips["p" .. index] = React.createElement("frame", {
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = if index <= offer.Left then Palette.violet else Palette.panelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	pips.Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("uistroke", { Color = if soldOut then Palette.line else Palette.violet, Thickness = 2, Transparency = 0.3 }),
		Badge = React.createElement("frame", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = if soldOut then Palette.line else Palette.coral, BorderSizePixel = 0 }, {
			Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			Label = React.createElement(Text, { value = `-{percent(offer.Discount)}`, size = 14, color = Palette.ink, weight = Enum.FontWeight.Heavy, align = Enum.TextXAlignment.Center, fit = true, minSize = 9 }),
		}),
		Name = React.createElement(Text, { value = offer.Name, size = 14, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(68, 6), sizeConstraint = UDim2.new(1, -170, 0, 18) }),
		Gives = React.createElement(Text, { value = formatReward(offer.Reward), size = 11, color = Palette.muted, position = UDim2.fromOffset(68, 24), sizeConstraint = UDim2.new(1, -170, 0, 16) }),
		Stock = React.createElement("frame", { Size = UDim2.new(1, -170, 0, 12), Position = UDim2.fromOffset(68, 46), BackgroundTransparency = 1, BorderSizePixel = 0 }, pips),
		Buy = React.createElement(Button, {
			text = if soldOut then "SOLD OUT" else compactNumber(offer.Price),
			onClick = props.onBuy,
			size = UDim2.fromOffset(94, 44),
			position = UDim2.new(1, -102, 0, 11),
			color = if soldOut then Palette.panelSoft else Palette.violet,
			textColor = if soldOut then Palette.muted else Palette.ink,
			disabled = soldOut or props.busy,
			highlight = not soldOut and not props.busy,
			reducedMotion = props.reducedMotion,
		}),
	})
end

-- One merchant contract: what to do, how far along, and a claim button once done.
local function ContractRow(props)
	local contract = props.contract
	local text, color, disabled = "CLAIM", Palette.cyan, not contract.Claimable or props.busy
	if contract.Claimed then
		text, color, disabled = "CLAIMED", Palette.panelSoft, true
	elseif not contract.Claimable then
		text, color = `{contract.Progress}/{contract.Target}`, Palette.panelSoft
	end
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Palette.panelSoft, BorderSizePixel = 0, LayoutOrder = props.order }, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("uistroke", { Color = if contract.Claimable then Palette.cyan else Palette.line, Thickness = 2, Transparency = 0.3 }),
		Title = React.createElement(Text, { value = `{contract.Name}: {contract.Text}`, size = 13, color = Palette.cream, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(12, 6), sizeConstraint = UDim2.new(1, -130, 0, 18) }),
		Reward = React.createElement(Text, { value = formatReward(contract.Reward), size = 11, color = Palette.muted, position = UDim2.fromOffset(12, 24), sizeConstraint = UDim2.new(1, -130, 0, 16) }),
		Bar = React.createElement("frame", { Size = UDim2.new(1, -130, 0, 10), Position = UDim2.fromOffset(12, 46), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
			Fill = React.createElement(ShineBar, { value = contract.Progress / contract.Target, color = Palette.cyan, reducedMotion = props.reducedMotion }),
		}),
		Claim = React.createElement(Button, {
			text = text,
			onClick = props.onClaim,
			size = UDim2.fromOffset(100, 42),
			position = UDim2.new(1, -108, 0, 11),
			color = color,
			textColor = if contract.Claimable then Palette.ink else nil,
			disabled = disabled,
			highlight = contract.Claimable and not props.busy,
			reducedMotion = props.reducedMotion,
		}),
	})
end

-- A row of mini tickets that light up for each one you hold.
local function TicketStrip(props)
	local kids = { Layout = React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index = 1, props.max do
		kids["t" .. index] = React.createElement("frame", {
			Size = UDim2.new(1 / props.max, -3, 0, 22),
			BackgroundColor3 = if index <= props.mine then Palette.mango else Palette.panelSoft,
			BackgroundTransparency = if index <= props.mine then 0 else 0.3,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, { Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }) })
	end
	return React.createElement("frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = props.order }, kids)
end

local function BazaarView(props)
	local state = props.state
	local dispatch = props.dispatch
	local reducedMotion = props.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local reveal = useStagger(0, reducedMotion)
	local bazaar = state.Bazaar
	local now = useClock()

	local tab, setTab = React.useState(props.initialTab or "Bank")
	local tier, setTier = React.useState(2)
	local term, setTerm = React.useState("T6")
	local busy, setBusy = React.useState(false)
	local note, setNote = React.useState({ text = "Welcome to the Bazaar. Bank some flux, snap up a deal, or try your luck on a ticket.", good = nil })
	local fx, setFx = React.useState({ token = 0, power = 1 })
	local mode, setMode = React.useState("idle")
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	local function play(payload, cue, power)
		if busy or bazaar == nil then
			return
		end
		setBusy(true)
		sfx("casino_chip", 0.5)
		dispatch("BazaarPlay", payload, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			if response.ok then
				setNote({ text = response.message or "", good = true })
				sfx(cue or "casino_buy", 0.7)
				if power then
					setFx({ token = fx.token + 1, power = power })
					setMode("win")
					task.delay(1.4, function()
						if mounted.current then
							setMode("idle")
						end
					end)
				end
			else
				setNote({ text = response.error or "That didn't go through.", good = false })
				sfx("casino_lose", 0.4, 1.3)
				Audio:play("error")
			end
		end)
	end

	if bazaar == nil then
		return React.createElement(PageScaffold, {
			gap = 0,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
			sections = { { id = "loading", height = 80, element = React.createElement(Text, { value = "The Bazaar is opening its shutters...", size = 14, color = Palette.muted, sizeConstraint = UDim2.new(1, 0, 0, 24) }) } },
		})
	end

	local accent = Palette.mint
	for _, entry in TABS do
		if entry.id == tab then
			accent = entry.accent
		end
	end
	local noteColor = if note.good == true then Palette.mint elseif note.good == false then Palette.coral else Palette.muted

	local function picker(order, labels, selected, onPick)
		local items = {}
		for index, label in labels do
			items[index] = {
				text = label,
				onClick = function()
					sfx("casino_chip", 0.4, 0.9 + index * 0.08)
					onPick(index)
				end,
				color = if selected == index then accent else Palette.panelSoft,
				textColor = if selected == index then Palette.ink else Palette.cream,
				disabled = busy,
			}
		end
		return React.createElement(Buttons, { items = items, height = 38, order = order, reducedMotion = reducedMotion })
	end

	-- ------------------------------------------------------------------ bank
	local function bankBody()
		local bank = bazaar.Bank
		local open = bank.Term.Id ~= ""
		local left = math.max(0, bank.Term.EndsAt - now)
		local total = (bank.Term.Hours or 0) * 3600
		local termProgress = if open and total > 0 then math.clamp(1 - left / total, 0, 1) else 0
		local children = {
			React.createElement(Line, { value = "ASTRAL BANK", size = 11, color = Palette.mint, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 64, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `Savings {compactNumber(bank.Balance)}`, color = Palette.mint, textSize = 16, size = UDim2.new(0.48, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = `Interest {compactNumber(bank.Accrued)}`, color = Palette.mango, textSize = 16, size = UDim2.new(0.48, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(Line, { value = note.text, size = 13, color = noteColor, height = 34, order = 3 }),
			picker(4, SHARES, tier, setTier),
			React.createElement(Buttons, { items = {
				{ text = "DEPOSIT", onClick = function() play({ Game = "Bank", Op = "Deposit", Tier = tier }, "casino_buy") end, color = Palette.mint, textColor = Palette.ink, disabled = busy, highlight = not busy },
				{ text = "WITHDRAW", onClick = function() play({ Game = "Bank", Op = "Withdraw", Tier = math.min(tier, 3) }, "casino_cash") end, color = Palette.panelSoft, disabled = busy },
				{ text = "COLLECT", onClick = function() play({ Game = "Bank", Op = "Collect" }, "casino_win_small", 1) end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
			}, height = 46, order = 5, reducedMotion = reducedMotion }),
			React.createElement(Line, { value = `Savings earn {percent(bank.Rate)} an hour on up to {compactNumber(bank.Cap)} flux (two hours of your income). Interest builds for up to a day; collect it any time.`, size = 11, height = 44, order = 6 }),
			React.createElement(Line, { value = "TERM DEPOSIT", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 7 }),
		}
		if open then
			table.insert(children, React.createElement(Line, { value = `{compactNumber(bank.Term.Principal)} flux locked at {percent(bank.Term.Rate)} an hour. {if bank.Term.Matured then "Matured: ready to redeem." else clockText(left) .. " to go."}`, size = 12, color = Palette.cream, height = 34, order = 8 }))
			table.insert(children, React.createElement(ShineBar, { value = termProgress, color = Palette.violet, reducedMotion = reducedMotion, order = 9 }))
			table.insert(children, React.createElement(Buttons, { items = {
				{ text = "REDEEM", onClick = function() play({ Game = "Bank", Op = "Redeem" }, "casino_win_big", 1.5) end, color = Palette.mint, textColor = Palette.ink, disabled = busy or not bank.Term.Matured, highlight = bank.Term.Matured },
				{ text = "BREAK (NO INTEREST)", onClick = function() play({ Game = "Bank", Op = "Break" }, "casino_cash") end, color = Palette.panelSoft, disabled = busy },
			}, height = 44, order = 10, reducedMotion = reducedMotion }))
		else
			local labels = {}
			for index, entry in bank.Terms do
				labels[index] = `{TERM_NAMES[entry.Id] or entry.Id} {percent(entry.Rate)}/h`
			end
			local selected = 1
			for index, entry in bank.Terms do
				if entry.Id == term then
					selected = index
				end
			end
			table.insert(children, picker(8, labels, selected, function(index)
				setTerm(bank.Terms[index].Id)
			end))
			table.insert(children, React.createElement(Buttons, { items = {
				{ text = `LOCK {SHARES[tier]} FOR {TERM_NAMES[term] or term}`, onClick = function() play({ Game = "Bank", Op = "Term", Term = term, Tier = tier }, "casino_buy") end, color = Palette.violet, textColor = Palette.ink, disabled = busy, highlight = not busy },
			}, height = 46, order = 9, reducedMotion = reducedMotion }))
			table.insert(children, React.createElement(Line, { value = "Lock flux for a set time for a higher rate. Breaking it early returns the principal with no interest.", size = 11, height = 30, order = 10 }))
		end
		return children
	end

	-- ------------------------------------------------------------------ black market
	local function marketBody()
		local market = bazaar.Market
		local children = {
			React.createElement(Line, { value = "BLACK MARKET", size = 11, color = Palette.violet, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{note.text}  New stock in {clockText(math.max(0, market.EndsAt - now))}.`, size = 12, color = noteColor, height = 34, order = 2 }),
		}
		for index, offer in market.Offers do
			children[#children + 1] = React.createElement(DealCard, {
				offer = offer,
				order = 2 + index,
				busy = busy,
				reducedMotion = reducedMotion,
				onBuy = function()
					play({ Game = "Market", Pick = offer.Id }, "casino_cash", 0.8)
				end,
			})
		end
		children[#children + 1] = React.createElement(Line, { value = "Four deals each hour, the same for everyone, 20% to 45% off, and only a few of each per player.", size = 11, height = 30, order = 20 })
		return children
	end

	-- ------------------------------------------------------------------ lottery
	local function lotteryBody()
		local lottery = bazaar.Lottery
		local last = lottery.Last
		local lastLine = "No draw yet."
		if last then
			lastLine = `Last draw: {last.Winner} won {compactNumber(last.Prize)} flux.`
		end
		local children = {
			React.createElement(Line, { value = "SERVER LOTTERY", size = 11, color = Palette.mango, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Row, { height = 78, order = 2, gap = 8, children = {
				React.createElement(Tile, { value = `Pot {compactNumber(lottery.Pot)}`, color = Palette.mango, textSize = 22, size = UDim2.new(0.6, 0, 1, 0), order = 1 }),
				React.createElement(Tile, { value = clockText(math.max(0, lottery.NextAt - now)), color = Palette.cream, textSize = 20, size = UDim2.new(0.36, 0, 1, 0), order = 2 }),
			} }),
			React.createElement(TicketStrip, { max = lottery.Max, mine = lottery.Mine, order = 3 }),
			React.createElement(Line, { value = `{note.text}  You hold {lottery.Mine} of {lottery.Max} tickets. {lastLine}`, size = 12, color = noteColor, height = 48, order = 4 }),
			React.createElement(Buttons, { items = {
				{ text = `1 TICKET ({compactNumber(lottery.Price)})`, onClick = function() play({ Game = "Lottery", Tier = 1 }, "casino_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
				{ text = "5 TICKETS", onClick = function() play({ Game = "Lottery", Tier = 2 }, "casino_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
				{ text = "20 TICKETS", onClick = function() play({ Game = "Lottery", Tier = 3 }, "casino_chip") end, color = Palette.mango, textColor = Palette.ink, disabled = busy },
			}, height = 50, order = 5, reducedMotion = reducedMotion }),
		}
		if lottery.Prize ~= 0 then
			table.insert(children, React.createElement(Buttons, { items = { {
				text = `COLLECT PRIZE {compactNumber(lottery.Prize)}`,
				onClick = function()
					sfx("casino_jackpot", 0.8)
					play({ Game = "Lottery", Op = "Prize" }, "casino_win_big", 2)
				end,
				color = Palette.mint,
				textColor = Palette.ink,
				disabled = busy,
				highlight = true,
			} }, height = 54, order = 6, reducedMotion = reducedMotion }))
		end
		table.insert(children, React.createElement(Line, { value = "A draw every five minutes: one winner takes the pot, less the house's tenth. A ticket costs 1% of your flux. Only players still in the server can win; with nobody to win, the pot rolls over.", size = 11, height = 58, order = 7 }))
		return children
	end

	-- ------------------------------------------------------------------ contracts
	local function contractsBody()
		local children = {
			React.createElement(Line, { value = "MERCHANT CONTRACTS", size = 11, color = Palette.cyan, weight = Enum.FontWeight.Heavy, height = 16, order = 1 }),
			React.createElement(Line, { value = `{note.text}  A fresh board every day.`, size = 12, color = noteColor, height = 34, order = 2 }),
		}
		for index, contract in bazaar.Contracts do
			children[#children + 1] = React.createElement(ContractRow, {
				contract = contract,
				order = 2 + index,
				busy = busy,
				reducedMotion = reducedMotion,
				onClaim = function()
					play({ Game = "Contracts", Pick = contract.Id }, "casino_rank", 1.4)
				end,
			})
		end
		children[#children + 1] = React.createElement(Line, { value = "Contracts count what you do from the moment today's board is drawn: casino rounds and wins, deals, deposits, tickets and interest.", size = 11, height = 44, order = 20 })
		return children
	end

	local bodies = { Bank = bankBody, Market = marketBody, Lottery = lotteryBody, Contracts = contractsBody }
	local heights = { Bank = 548, Market = 458, Lottery = 440, Contracts = 366 }

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
				}, React.createElement(Marquee, { position = UDim2.fromOffset(0, 0), mode = mode, reducedMotion = reducedMotion, color = accent }), React.createElement(Text, {
					value = "ASTRAL BAZAAR",
					size = 10,
					color = accent,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 14),
					sizeConstraint = UDim2.new(1, 0, 0, 14),
				}), React.createElement(Text, {
					value = `Flux {compactNumber(state.Cash)}`,
					size = 20,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(0, 30),
					sizeConstraint = UDim2.new(1, 0, 0, 28),
				}), React.createElement(Text, {
					value = "Bank it, bargain for it, bet on it, or work for it.",
					size = 11,
					color = Palette.muted,
					position = UDim2.fromOffset(0, 58),
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				})),
			},
			{
				id = "tabs",
				height = 48,
				element = React.createElement(SegmentedTabs, {
					options = TABS,
					value = tab,
					onChange = function(id)
						sfx("casino_tick", 0.5)
						setTab(id)
					end,
					columns = 4,
					accent = accent,
					size = UDim2.new(1, 0, 0, 48),
					reducedMotion = reducedMotion,
				}),
			},
			{
				id = "body",
				height = heights[tab] or 420,
				element = React.createElement("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
					Panel = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = accent,
						background = Palette.panelRaised,
						padding = Layout.cardPadding,
						reducedMotion = reducedMotion,
					}, React.createElement(Stack, { gap = 8, children = bodies[tab]() })),
					Coins = React.createElement(Confetti, { token = fx.token, power = fx.power, reducedMotion = reducedMotion }),
				}),
			},
		},
	})
end

return {
	BazaarView = BazaarView,
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
