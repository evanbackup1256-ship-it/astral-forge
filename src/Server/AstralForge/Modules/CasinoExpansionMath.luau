--!strict
-- Practice tables never read or grant the game's economy or Club rewards.
local Tables = {}
local RED = {
	[1] = true,
	[3] = true,
	[5] = true,
	[7] = true,
	[9] = true,
	[12] = true,
	[14] = true,
	[16] = true,
	[18] = true,
	[19] = true,
	[21] = true,
	[23] = true,
	[25] = true,
	[27] = true,
	[30] = true,
	[32] = true,
	[34] = true,
	[36] = true,
}
local STAKES = { 10, 25, 100 }
local function integer(value: any, low: number, high: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < low or value > high then
		return nil
	end
	return value
end
local function count(value: any, fallback: number): number
	return integer(value, 0, 1e9) or fallback
end
local function total(cards: { number }): number
	local sum, aces = 0, 0
	for _, card in cards do
		sum += math.min(card, 10)
		if card == 1 then
			aces += 1
		end
	end
	if aces > 0 and sum + 10 <= 21 then
		sum += 10
	end
	return sum
end
Tables.CardTotal = total
function Tables.Ensure(source: any): any
	source = if type(source) == "table" then source else {}
	local tower = if type(source.Tower) == "table" then source.Tower else {}
	local columns = {}
	local slots = integer(tower.Slots, 3, 4) or 3
	for i = 1, slots do
		local cards = {}
		if type(tower.Columns) == "table" and type(tower.Columns[i]) == "table" then
			for j, card in tower.Columns[i] do
				if type(j) == "number" and j <= 5 and integer(card, 1, 13) then
					cards[j] = card
				end
			end
		end
		columns[i] = cards
	end
	return {
		Chips = count(source.Chips, 1000),
		Played = count(source.Played, 0),
		Won = count(source.Won, 0),
		QuantumRound = count(source.QuantumRound, 0),
		Seed = integer(source.Seed, 1, 999999) or 1,
		Tower = {
			Active = tower.Active == true,
			Slots = slots,
			Columns = columns,
			Card = integer(tower.Card, 1, 13) or 1,
			Hands = count(tower.Hands, 0),
			Placed = count(tower.Placed, 0),
			Stake = integer(tower.Stake, 10, 100) or 10,
			Id = count(tower.Id, 0),
		},
		Last = if type(source.Last) == "table" then source.Last else {},
	}
end
function Tables.QuantumBoard(seed: number, round: number): any
	local phase = math.floor(round / 3) % 3
	local span = ({ 2, 6, 1 })[phase + 1]
	local sink = (seed + math.floor(round / 3) * 17) % 37
	local zones = {}
	local first = 1
	while first <= 36 do
		local variation = (seed + math.floor(round / 3) * 47 + first * 13) % 7
		local width = if phase == 0 and variation == 0
			then 1
			elseif phase == 0 and variation == 1 then 3
			elseif phase == 1 and variation < 2 then 2
			elseif phase == 2 and variation == 0 then 2
			else span
		local numbers = {}
		for n = first, math.min(first + width - 1, 36) do
			table.insert(numbers, n)
		end
		table.insert(zones, { Id = "Q" .. first, Numbers = numbers, Return = 36 / #numbers })
		first += width
	end
	table.insert(zones, { Id = "Q0", Numbers = { 0 }, Return = 36 })
	return {
		Zones = zones,
		Sink = sink,
		Version = math.floor(round / 3),
		UntilShift = 3 - round % 3,
		Phase = ({ "Split zones", "Merged zones", "Single squares" })[phase + 1],
	}
end
function Tables.TableBoard(): any
	local zones = {}
	for n = 0, 36 do
		table.insert(zones, { Id = "N" .. n, Numbers = { n }, Return = 36 })
	end
	for _, kind in { "Red", "Black", "Odd", "Even", "Low", "High", "Dozen1", "Dozen2", "Dozen3" } do
		local numbers = {}
		for n = 1, 36 do
			local match = kind == "Red" and RED[n]
				or kind == "Black" and not RED[n]
				or kind == "Odd" and n % 2 == 1
				or kind == "Even" and n % 2 == 0
				or kind == "Low" and n <= 18
				or kind == "High" and n >= 19
				or kind == "Dozen1" and n <= 12
				or kind == "Dozen2" and n >= 13 and n <= 24
				or kind == "Dozen3" and n >= 25
			if match then
				table.insert(numbers, n)
			end
		end
		table.insert(zones, { Id = kind, Numbers = numbers, Return = 36 / #numbers })
	end
	for n = 1, 35 do
		if n % 3 ~= 0 then
			table.insert(zones, { Id = "S" .. n, Numbers = { n, n + 1 }, Return = 18 })
		end
	end
	return { Zones = zones, Version = 0 }
end
local function adjacent(a: number, b: number): boolean
	if a == 0 then
		return b >= 1 and b <= 3
	end
	if b == 0 then
		return a >= 1 and a <= 3
	end
	return math.abs(a - b) == 3 or (math.floor((a - 1) / 3) == math.floor((b - 1) / 3) and math.abs(a - b) == 1)
end
function Tables.SettleRoulette(board: any, bets: any, number: number): number
	local payout = 0
	for _, zone in board.Zones do
		local bet = bets[zone.Id]
		if bet and table.find(zone.Numbers, number) and number ~= board.Sink then
			payout += math.floor(
				bet * zone.Return * (if board.Sink ~= nil and adjacent(number, board.Sink) then 2 else 1)
			)
		end
	end
	return payout
end
local function finish(state: any, gameName: string, stake: number, payout: number, extra: any): any
	state.Chips = math.min(1e9, state.Chips + payout)
	state.Played += 1
	if payout > stake then
		state.Won += 1
	end
	extra.Game = gameName
	extra.Stake = stake
	extra.Payout = payout
	extra.Won = payout > stake
	extra.Practice = true
	state.Last = extra
	return extra
end
function Tables.Play(state: any, payload: any, rand: () -> number): (boolean, string, any?)
	local gameName = payload.Game
	if payload.Action == "Refill" then
		if state.Chips >= 10 or state.Tower.Active then
			return false, "Refills are for an empty practice balance.", nil
		end
		state.Chips = 1000
		return true, "Practice chips refilled.", { Game = gameName, Practice = true }
	end
	if gameName == "TableRoulette" or gameName == "QuantumRoulette" then
		local board = if gameName == "QuantumRoulette"
			then Tables.QuantumBoard(state.Seed, state.QuantumRound)
			else Tables.TableBoard()
		if payload.Version ~= board.Version then
			return false, "The board shifted. Choose your bets again.", nil
		end
		if type(payload.Bets) ~= "table" then
			return false, "Place a chip on the board.", nil
		end
		local available = {}
		for _, zone in board.Zones do
			available[zone.Id] = true
		end
		local stake, entries = 0, 0
		for key, amount in payload.Bets do
			if not available[key] or not integer(amount, 10, 1000) or amount % 10 ~= 0 then
				return false, "Invalid table bet.", nil
			end
			stake += amount
			entries += 1
		end
		if entries < 1 or entries > 12 or stake > state.Chips then
			return false, "Choose up to 12 zones within your chip balance.", nil
		end
		state.Chips -= stake
		local number = math.min(36, math.floor(rand() * 37))
		local payout = Tables.SettleRoulette(board, payload.Bets, number)
		if gameName == "QuantumRoulette" then
			state.QuantumRound += 1
			if state.QuantumRound % 3 == 0 then
				state.Seed = math.floor(rand() * 999998) + 1
			end
		end
		return true,
			`Ball landed on {number}. {payout} practice chips returned.`,
			finish(state, gameName, stake, payout, { Number = number, Sink = board.Sink, Version = board.Version })
	elseif gameName == "DiceTable" then
		local tier = integer(payload.Tier, 1, 3)
		local pick = payload.Pick
		if not tier or not table.find({ "Low", "High", "Seven", "Doubles" }, pick) then
			return false, "Choose a dice bet and chip size.", nil
		end
		local stake = STAKES[tier]
		if state.Chips < stake then
			return false, "Not enough practice chips.", nil
		end
		state.Chips -= stake
		local a, b = math.min(6, math.floor(rand() * 6) + 1), math.min(6, math.floor(rand() * 6) + 1)
		local sum = a + b
		local win = pick == "Low" and sum < 7
			or pick == "High" and sum > 7
			or pick == "Seven" and sum == 7
			or pick == "Doubles" and a == b
		local payout = if win then math.floor(stake * (if pick == "High" or pick == "Low" then 2.4 else 6)) else 0
		return true,
			`Rolled {a} + {b}. {payout} chips returned.`,
			finish(state, gameName, stake, payout, { Dice = { a, b } })
	elseif gameName == "CardTower" then
		local t = state.Tower
		if payload.Action == "Start" then
			local tier, slots = integer(payload.Tier, 1, 3), integer(payload.Slots, 3, 4)
			if t.Active or not tier or not slots then
				return false, "Choose 3 or 4 columns to start a new tower.", nil
			end
			local stake = STAKES[tier]
			if state.Chips < stake then
				return false, "Not enough practice chips.", nil
			end
			state.Chips -= stake
			t.Active = true
			t.Stake = stake
			t.Slots = slots
			t.Hands = 0
			t.Placed = 0
			t.Id += 1
			t.Columns = {}
			for i = 1, slots do
				t.Columns[i] = {}
			end
			t.Card = math.min(13, math.floor(rand() * 13) + 1)
			return true, "Send the incoming card to a column.", { Game = gameName, Practice = true, Open = true }
		end
		if not t.Active or payload.RoundId ~= t.Id then
			return false, "That tower round is no longer active.", nil
		end
		if payload.Action == "Cashout" then
			if t.Hands < 1 then
				return false, "Complete a 21 before banking the tower.", nil
			end
			t.Active = false
			local payout = math.floor(t.Stake * (1 + math.min(t.Hands, 20) * 0.3))
			return true,
				`Banked {t.Hands} hands for {payout} chips.`,
				finish(state, gameName, t.Stake, payout, { Hands = t.Hands })
		elseif payload.Action == "Place" then
			local column = integer(payload.Column, 1, t.Slots)
			if not column then
				return false, "Choose a column.", nil
			end
			table.insert(t.Columns[column], t.Card)
			t.Placed += 1
			local value = total(t.Columns[column])
			if value > 21 or (#t.Columns[column] >= 5 and value ~= 21) then
				t.Active = false
				return true,
					"Tower fell. A column went bust or filled before reaching 21.",
					finish(state, gameName, t.Stake, 0, { Bust = column })
			end
			local cleared = value == 21
			if cleared then
				t.Hands += 1
				t.Columns[column] = {}
			end
			t.Id += 1
			t.Card = math.min(13, math.floor(rand() * 13) + 1)
			return true,
				if cleared
					then "21! Column cleared. Keep building or bank it."
					else "Card placed. Choose where the next one goes.",
				{ Game = gameName, Practice = true, Cleared = cleared }
		end
	end
	return false, "Unknown practice-table action.", nil
end
function Tables.State(state: any): any
	local t = state.Tower
	local totals = {}
	for i, cards in t.Columns do
		totals[i] = total(cards)
	end
	return {
		Chips = state.Chips,
		Played = state.Played,
		Won = state.Won,
		Last = state.Last,
		Quantum = Tables.QuantumBoard(state.Seed, state.QuantumRound),
		Table = Tables.TableBoard(),
		Tower = {
			Active = t.Active,
			Slots = t.Slots,
			Columns = t.Columns,
			Card = t.Card,
			Hands = t.Hands,
			Placed = t.Placed,
			Stake = t.Stake,
			Id = t.Id,
			Totals = totals,
			Cashout = if t.Hands > 0 then math.floor(t.Stake * (1 + math.min(t.Hands, 20) * 0.3)) else 0,
		},
	}
end
return table.freeze(Tables)
