--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local motion = require(script.Parent.MotionKit)("motion")
local PageScaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local Audio = require(script.Parent.AudioKit)("audio").Audio
local h, P = React.createElement, theme.Palette
local NAMES = {
	TableRoulette = "Table Roulette",
	QuantumRoulette = "Quantum Roulette",
	CardTower = "The Infinite Card Tower",
	DiceTable = "Dice Table",
}
local RULES = {
	TableRoulette = "Place several bets, then spin once. Zero belongs to neither color nor any outside bet. Returns include your stake.",
	QuantumRoulette = "The board changes every 3 rounds: split zones, merged zones, then single squares. Gravity Sink pays nothing; adjacent winning squares return double.",
	CardTower = "Build 21 in any column to clear it. Aces count as 1 or 11. A bust, or 5 cards without 21, ends the round. Bank completed hands whenever you want.",
	DiceTable = "Roll two fair dice. Low is 2–6, High is 8–12; both return 2.4x. Seven and Doubles return 6x. Returns include the stake.",
}
local function text(value, y, height, color, size)
	return h(ui.Text, {
		value = value,
		position = UDim2.fromOffset(0, y),
		sizeConstraint = UDim2.new(1, 0, 0, height),
		size = size or 14,
		color = color or P.cream,
		wrap = true,
	})
end
local function cardName(rank)
	return ({ [1] = "A", [11] = "J", [12] = "Q", [13] = "K" })[rank] or tostring(rank)
end
local CasinoViewport = require(script.Parent.CasinoViewport)
local function RouletteDraw(props)
	return h(CasinoViewport, {
		kind = "Roulette",
		token = props.token,
		number = props.number,
		position = UDim2.fromOffset(0, 54),
		size = UDim2.new(1, 0, 0, 180),
	})
end
local function IncomingCard(props)
	return h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Scene = h(
			CasinoViewport,
			{ kind = "Cards", token = props.token, rank = props.rank, size = UDim2.new(1, -80, 1, 0) }
		),
		Rank = h(ui.Text, {
			value = cardName(props.rank),
			size = 28,
			color = P.cream,
			position = UDim2.new(1, -80, 0, 12),
			sizeConstraint = UDim2.fromOffset(76, 48),
		}),
	})
end
local function CasinoTables(props)
	local viewport = motion.useViewport()
	local chrome = theme.chromeFor(viewport)
	local tabColumns = if chrome.stack then 3 else 4
	local tabRows = math.max(1, math.ceil(#props.tabs / tabColumns))
	local tabHeight = tabRows * 48 + (tabRows - 1) * 6
	local arcade = props.state.Casino.Arcade
	local gameName = props.gameName
	local busy, setBusy = React.useState(false)
	local busyRef = React.useRef(false)
	local mounted = React.useRef(true)
	local bets, setBets = React.useState({})
	local tier, setTier = React.useState(1)
	local slots, setSlots = React.useState(3)
	local pick, setPick = React.useState("Low")
	local category, setCategory = React.useState("Straight")
	local note, setNote =
		React.useState("Practice chips stay at these tables. They cannot be bought, traded, or exchanged for rewards.")
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local board = if arcade and gameName == "QuantumRoulette" then arcade.Quantum else arcade and arcade.Table
	React.useEffect(function()
		setBets({})
	end, { gameName, board and board.Version })
	local function play(payload)
		if busyRef.current then
			return
		end
		busyRef.current = true
		setBusy(true)
		payload.Game = gameName
		props.dispatch("CasinoPlay", payload, function(response)
			if not mounted.current then
				return
			end
			busyRef.current = false
			setBusy(false)
			setNote(response.message or response.error or "Table updated.")
			if response.ok then
				local result = response.Result or {}
				Audio:play(if result.Won or result.Cleared then "reward" else "click")
				if payload.Bets then
					setBets({})
				end
			else
				Audio:play("error")
			end
		end)
	end
	local function button(label, x, y, w, onClick, color, disabled)
		return h(ui.Button, {
			text = label,
			position = UDim2.new(x, 0, 0, y),
			size = UDim2.new(w, -6, 0, 48),
			color = color or P.cyan,
			textColor = P.ink,
			onClick = onClick,
			disabled = busy or disabled,
			reducedMotion = false,
		})
	end
	local function panel(children, height)
		return {
			id = "table",
			height = height,
			element = h(
				ui.Panel,
				{ size = UDim2.fromScale(1, 1), accent = P.cyan, padding = 12, background = P.panelRaised },
				children
			),
		}
	end
	local sections = {
		{
			id = "header",
			height = 176,
			element = h(ui.Panel, { size = UDim2.fromScale(1, 1), accent = P.cyan, padding = 12 }, {
				Title = text(NAMES[gameName], 0, 30, P.cyan, 22),
				Balance = text(`{arcade and arcade.Chips or 0} practice chips`, 34, 22, P.mango, 16),
				Rules = text(RULES[gameName], 62, 78, P.muted, 13),
			}),
		},
		{
			id = "tabs",
			height = tabHeight,
			element = h(ui.SegmentedTabs, {
				options = props.tabs,
				value = gameName,
				onChange = props.onTab,
				columns = tabColumns,
				size = UDim2.new(1, 0, 0, tabHeight),
				accent = P.cyan,
			}),
		},
	}
	if not arcade then
		table.insert(sections, panel({ text("Tables are loading…", 0, 48) }, 80))
		return h(PageScaffold, { sections = sections, gap = 12 })
	end
	local children = {}
	local height = 0
	if gameName == "TableRoulette" or gameName == "QuantumRoulette" then
		local quantum = gameName == "QuantumRoulette"
		children.Info = text(
			if quantum
				then `{board.Phase} • shift in {board.UntilShift} rounds • Gravity Sink: {board.Sink}`
				else "Tap a zone to add 10 chips. Up to 12 zones per spin.",
			0,
			48,
			P.cyan,
			14
		)
		children.Draw = h(RouletteDraw, { token = arcade.Played, number = arcade.Last.Number })
		local top = 246
		if not quantum then
			for i, name in { "Straight", "Outside", "Split" } do
				children["Category" .. i] = button(name, (i - 1) / 3, top, 1 / 3, function()
					setCategory(name)
				end, if category == name then P.cyan else P.steel)
			end
			top += 58
		end
		local zones = {}
		for _, zone in board.Zones do
			if
				quantum
				or category == "Straight" and zone.Id:sub(1, 1) == "N"
				or category == "Split" and zone.Id:sub(1, 1) == "S"
				or category == "Outside" and not zone.Id:match("^[NS]%d")
			then
				table.insert(zones, zone)
			end
		end
		local columns = if quantum and board.Phase == "Merged zones"
			then (if chrome.stack then 1 else 3)
			elseif chrome.stack then 3
			else 6
		for i, zone in zones do
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			local amount = bets[zone.Id] or 0
			local name = if zone.Id:sub(1, 1) == "N"
				then tostring(zone.Numbers[1])
				elseif quantum or zone.Id:sub(1, 1) == "S" then table.concat(zone.Numbers, "/")
				else zone.Id
			children[zone.Id] = h("frame", {
				Size = UDim2.new(1 / columns, -6, 0, 78),
				Position = UDim2.new(col / columns, 0, 0, top + row * 84),
				BackgroundTransparency = 1,
			}, {
				Bet = h(ui.Button, {
					text = name,
					size = UDim2.new(1, 0, 0, 48),
					color = if amount > 0
						then P.mango
						elseif quantum and table.find(zone.Numbers, board.Sink) then P.violet
						else P.panelSoft,
					textColor = P.cream,
					disabled = busy,
					onClick = function()
						setBets(function(old)
							local copy = table.clone(old)
							local count, total = 0, 0
							for _, v in old do
								count += 1
								total += v
							end
							if
								(old[zone.Id] or count < 12)
								and total + 10 <= arcade.Chips
								and (old[zone.Id] or 0) < 1000
							then
								copy[zone.Id] = (old[zone.Id] or 0) + 10
							end
							return copy
						end)
					end,
				}),
				Odds = h(ui.Text, {
					value = `{zone.Return}x • {amount} chips`,
					position = UDim2.fromOffset(0, 52),
					sizeConstraint = UDim2.new(1, 0, 0, 22),
					size = 11,
					color = P.muted,
					wrap = true,
				}),
			})
		end
		local bottom = top + math.ceil(#zones / columns) * 84
		local total = 0
		for _, amount in bets do
			total += amount
		end
		children.Spin = button(`Spin • {total}`, 0, bottom, 0.65, function()
			play({ Bets = bets, Version = board.Version })
		end, P.cyan, total == 0)
		children.Clear = button("Clear", 0.65, bottom, 0.35, function()
			setBets({})
		end, P.steel)
		children.Result = text(
			if arcade.Last.Number ~= nil
				then `Last ball: {arcade.Last.Number} • returned {arcade.Last.Payout} chips`
				else "All 37 numbers have a 1/37 chance.",
			bottom + 54,
			40,
			P.mango
		)
		height = bottom + 120
	elseif gameName == "CardTower" then
		local tower = arcade.Tower
		if not tower.Active then
			children.Explain = text(
				"Choose your tower width. More columns give you more places to send a difficult card.",
				0,
				60,
				P.muted
			)
			children.Three = button("3 columns", 0, 70, 0.5, function()
				setSlots(3)
			end, if slots == 3 then P.cyan else P.steel)
			children.Four = button("4 columns", 0.5, 70, 0.5, function()
				setSlots(4)
			end, if slots == 4 then P.cyan else P.steel)
			for i, stake in { 10, 25, 100 } do
				children["Stake" .. i] = button(tostring(stake) .. " chips", (i - 1) / 3, 128, 1 / 3, function()
					setTier(i)
				end, if tier == i then P.mango else P.steel)
			end
			children.Start = button("Deal cards", 0, 190, 1, function()
				play({ Action = "Start", Tier = tier, Slots = slots })
			end)
			children.Preview = h(
				CasinoViewport,
				{
					kind = "Cards",
					cards = { 1, 10, 13 },
					position = UDim2.fromOffset(0, 246),
					size = UDim2.new(1, 0, 0, 140),
				}
			)
			height = 414
		else
			children.Hands = text(`{tower.Hands} completed hands • {tower.Placed} cards placed`, 0, 36, P.mango)
			children.Conveyor = h("frame", {
				Size = UDim2.new(1, 0, 0, 84),
				Position = UDim2.fromOffset(0, 42),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, h(IncomingCard, { key = tower.Id, token = tower.Id, rank = tower.Card }))
			for i = 1, tower.Slots do
				local content = {
					Title = h(ui.Text, {
						value = `{tower.Totals[i]} / 21`,
						size = 17,
						color = P.cyan,
						sizeConstraint = UDim2.new(1, 0, 0, 28),
						wrap = true,
					}),
				}
				content.Cards = h(CasinoViewport, {
					kind = "Cards",
					cards = tower.Columns[i],
					position = UDim2.fromOffset(0, 30),
					size = UDim2.new(1, 0, 0, 104),
				})
				local ranks = {}
				for _, rank in tower.Columns[i] do
					table.insert(ranks, cardName(rank))
				end
				content.Ranks = h(ui.Text, {
					value = table.concat(ranks, " · "),
					size = 14,
					color = P.cream,
					wrap = true,
					position = UDim2.fromOffset(4, 136),
					sizeConstraint = UDim2.new(1, -8, 0, 38),
				})
				content.Place = h(ui.Button, {
					text = "Place",
					size = UDim2.new(1, 0, 0, 48),
					position = UDim2.fromOffset(0, 176),
					color = P.cyan,
					textColor = P.ink,
					disabled = busy,
					onClick = function()
						play({ Action = "Place", Column = i, RoundId = tower.Id })
					end,
				})
				children["Column" .. i] = h("frame", {
					Size = UDim2.new(1 / tower.Slots, -6, 0, 226),
					Position = UDim2.new((i - 1) / tower.Slots, 0, 0, 138),
					BackgroundColor3 = P.panelSoft,
					BorderSizePixel = 0,
				}, content)
			end
			children.Bank = button(`Bank {tower.Cashout} chips`, 0, 378, 1, function()
				play({ Action = "Cashout", RoundId = tower.Id })
			end, P.mango, tower.Hands < 1)
			height = 454
		end
	else
		children.Odds = text("Low / High: 15 of 36 outcomes. Seven / Doubles: 6 of 36 outcomes.", 0, 56, P.muted)
		for i, name in { "Low", "High", "Seven", "Doubles" } do
			children[name] = button(name, ((i - 1) % 2) / 2, 64 + math.floor((i - 1) / 2) * 58, 0.5, function()
				setPick(name)
			end, if pick == name then P.cyan else P.steel)
		end
		for i, stake in { 10, 25, 100 } do
			children["Stake" .. i] = button(tostring(stake) .. " chips", (i - 1) / 3, 188, 1 / 3, function()
				setTier(i)
			end, if tier == i then P.mango else P.steel)
		end
		children.Roll = button("Roll dice", 0, 246, 1, function()
			play({ Tier = tier, Pick = pick })
		end)
		local dice = arcade.Last.Dice
		children.Dice = h(
			CasinoViewport,
			{
				kind = "Dice",
				token = arcade.Played,
				dice = dice,
				position = UDim2.fromOffset(0, 310),
				size = UDim2.new(1, 0, 0, 150),
			}
		)
		children.Result = text(if dice then `{dice[1]} + {dice[2]}` else "Ready to roll", 464, 30, P.mango, 20)
		height = 522
	end
	table.insert(sections, panel(children, height))
	table.insert(sections, {
		id = "feedback",
		height = if arcade.Chips < 10 and not arcade.Tower.Active then 150 else 92,
		element = h(ui.Panel, { size = UDim2.fromScale(1, 1), accent = P.cyan, padding = 12 }, {
			Message = text(note, 0, 68, P.muted),
			Refill = arcade.Chips < 10
					and not arcade.Tower.Active
					and button("Refill practice chips", 0, 76, 1, function()
						play({ Action = "Refill" })
					end)
				or nil,
		}),
	})
	return h(PageScaffold, {
		sections = sections,
		gap = 12,
		tailPad = theme.scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = P.cyan,
		scrollBarThickness = 4,
	})
end
return CasinoTables
