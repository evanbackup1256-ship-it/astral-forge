--!strict

local CasinoMath = {}

CasinoMath.STAKES = table.freeze({ 0.005, 0.02, 0.05, 0.15, 0.40 })
CasinoMath.STAKE_NAMES = table.freeze({ "Pocket", "Low", "Mid", "High", "All-in" })
CasinoMath.PROFIT_CAP = 4

type Rand = () -> number

local function pickWeighted(items: { any }, rand: Rand): any
	local total = 0
	for _, item in items do
		total += item.Weight
	end
	local roll = rand() * total
	for _, item in items do
		roll -= item.Weight
		if roll < 0 then
			return item
		end
	end
	return items[#items]
end

CasinoMath.SLOT_SYMBOLS = table.freeze({
	table.freeze({ Id = "Ember", Weight = 30, Pay3 = 8, Pair = 0.6 }),
	table.freeze({ Id = "Dust", Weight = 25, Pay3 = 12, Pair = 0.3 }),
	table.freeze({ Id = "Core", Weight = 20, Pay3 = 20, Pair = 0 }),
	table.freeze({ Id = "Comet", Weight = 14, Pay3 = 50, Pair = 0 }),
	table.freeze({ Id = "Star", Weight = 8, Pay3 = 150, Pair = 0 }),
	table.freeze({ Id = "Nova", Weight = 3, Pay3 = 700, Pair = 0 }),
})

local slotById: { [string]: any } = {}
for _, symbol in CasinoMath.SLOT_SYMBOLS do
	slotById[symbol.Id] = symbol
end

function CasinoMath.SlotsPay(a: string, b: string, c: string): (number, string)
	if a == b and b == c then
		return slotById[a].Pay3, "Triple"
	end
	local pair: string? = nil
	if a == b or a == c then
		pair = a
	elseif b == c then
		pair = b
	end
	if pair ~= nil and slotById[pair].Pair > 0 then
		return slotById[pair].Pair, "Pair"
	end
	return 0, "None"
end

function CasinoMath.SlotsSpin(rand: Rand): ({ string }, number, string)
	local reels = {
		pickWeighted(CasinoMath.SLOT_SYMBOLS, rand).Id,
		pickWeighted(CasinoMath.SLOT_SYMBOLS, rand).Id,
		pickWeighted(CasinoMath.SLOT_SYMBOLS, rand).Id,
	}
	local multiplier, kind = CasinoMath.SlotsPay(reels[1], reels[2], reels[3])
	return reels, multiplier, kind
end

function CasinoMath.SlotsRtp(): number
	local total = 0
	for _, s in CasinoMath.SLOT_SYMBOLS do
		total += s.Weight
	end
	local rtp = 0
	for _, a in CasinoMath.SLOT_SYMBOLS do
		for _, b in CasinoMath.SLOT_SYMBOLS do
			for _, c in CasinoMath.SLOT_SYMBOLS do
				local p = (a.Weight / total) * (b.Weight / total) * (c.Weight / total)
				rtp += p * (CasinoMath.SlotsPay(a.Id, b.Id, c.Id))
			end
		end
	end
	return rtp
end

CasinoMath.FLIP_WIN_CHANCE = 0.495
CasinoMath.FLIP_STEP = 1.92
CasinoMath.FLIP_MAX_STREAK = 12
CasinoMath.FLIP_MAX_MULT = 500

function CasinoMath.FlipMultiplier(streak: number): number
	if streak <= 0 then
		return 1
	end
	return math.min(CasinoMath.FLIP_MAX_MULT, CasinoMath.FLIP_STEP ^ math.min(streak, CasinoMath.FLIP_MAX_STREAK))
end

function CasinoMath.FlipRoll(rand: Rand): boolean
	return rand() < CasinoMath.FLIP_WIN_CHANCE
end

CasinoMath.HL_RANKS = 13
CasinoMath.HL_RETURN = 0.96
CasinoMath.HL_MAX_STREAK = 12
CasinoMath.HL_MAX_MULT = 150

function CasinoMath.HighLowDraw(rand: Rand): number
	return math.min(CasinoMath.HL_RANKS, math.floor(rand() * CasinoMath.HL_RANKS) + 1)
end

function CasinoMath.HighLowOdds(card: number, guess: string): (number, number)
	local n = CasinoMath.HL_RANKS
	local chance = if guess == "High" then (n - card) / n elseif guess == "Low" then (card - 1) / n else 0
	if chance <= 0 then
		return 0, 0
	end
	return chance, CasinoMath.HL_RETURN / chance
end

function CasinoMath.HighLowWins(card: number, nextCard: number, guess: string): boolean
	if guess == "High" then
		return nextCard > card
	end
	return nextCard < card
end

CasinoMath.RED = table.freeze({
	[1] = true, [3] = true, [5] = true, [7] = true, [9] = true, [12] = true, [14] = true, [16] = true, [18] = true,
	[19] = true, [21] = true, [23] = true, [25] = true, [27] = true, [30] = true, [32] = true, [34] = true, [36] = true,
})

function CasinoMath.RouletteSpin(rand: Rand): number
	return math.min(36, math.floor(rand() * 37))
end

function CasinoMath.RouletteColor(number: number): string
	if number == 0 then
		return "Green"
	end
	return if CasinoMath.RED[number] then "Red" else "Black"
end

function CasinoMath.RoulettePay(pick: string, number: number): number
	if pick == "Red" or pick == "Black" then
		return if number ~= 0 and CasinoMath.RouletteColor(number) == pick then 2 else 0
	elseif pick == "Odd" then
		return if number ~= 0 and number % 2 == 1 then 2 else 0
	elseif pick == "Even" then
		return if number ~= 0 and number % 2 == 0 then 2 else 0
	elseif pick == "Low" then
		return if number >= 1 and number <= 18 then 2 else 0
	elseif pick == "High" then
		return if number >= 19 then 2 else 0
	elseif pick == "D1" then
		return if number >= 1 and number <= 12 then 3 else 0
	elseif pick == "D2" then
		return if number >= 13 and number <= 24 then 3 else 0
	elseif pick == "D3" then
		return if number >= 25 then 3 else 0
	elseif pick == "C1" then
		return if number ~= 0 and number % 3 == 1 then 3 else 0
	elseif pick == "C2" then
		return if number ~= 0 and number % 3 == 2 then 3 else 0
	elseif pick == "C3" then
		return if number ~= 0 and number % 3 == 0 then 3 else 0
	end
	local straight = string.match(pick, "^N(%d+)$")
	if straight ~= nil then
		return if tonumber(straight) == number then 36 else 0
	end
	return 0
end

function CasinoMath.RoulettePickValid(pick: any): boolean
	if type(pick) ~= "string" then
		return false
	end
	local fixed = { Red = true, Black = true, Odd = true, Even = true, Low = true, High = true, D1 = true, D2 = true, D3 = true, C1 = true, C2 = true, C3 = true }
	if fixed[pick] then
		return true
	end
	local straight = string.match(pick, "^N(%d+)$")
	return straight ~= nil and tonumber(straight) ~= nil and (tonumber(straight) :: number) <= 36
end

CasinoMath.SCRATCH_CELLS = 6
CasinoMath.SCRATCH_SYMBOLS = table.freeze({
	table.freeze({ Id = "Spark", Weight = 40, Pay = 0.5 }),
	table.freeze({ Id = "Dust", Weight = 28, Pay = 1.5 }),
	table.freeze({ Id = "Core", Weight = 18, Pay = 3 }),
	table.freeze({ Id = "Comet", Weight = 9, Pay = 10 }),
	table.freeze({ Id = "Star", Weight = 4, Pay = 35 }),
	table.freeze({ Id = "Nova", Weight = 1, Pay = 250 }),
})

function CasinoMath.ScratchPay(cells: { string }): (number, string?)
	local counts: { [string]: number } = {}
	for _, id in cells do
		counts[id] = (counts[id] or 0) + 1
	end
	local best, bestId = 0, nil
	for _, symbol in CasinoMath.SCRATCH_SYMBOLS do
		if (counts[symbol.Id] or 0) >= 3 and symbol.Pay > best then
			best, bestId = symbol.Pay, symbol.Id
		end
	end
	return best, bestId
end

function CasinoMath.ScratchCard(rand: Rand): ({ string }, number, string?)
	local cells = {}
	for i = 1, CasinoMath.SCRATCH_CELLS do
		cells[i] = pickWeighted(CasinoMath.SCRATCH_SYMBOLS, rand).Id
	end
	local multiplier, symbol = CasinoMath.ScratchPay(cells)
	return cells, multiplier, symbol
end

function CasinoMath.ScratchRtp(): number
	local total = 0
	for _, s in CasinoMath.SCRATCH_SYMBOLS do
		total += s.Weight
	end
	local count = #CasinoMath.SCRATCH_SYMBOLS
	local rtp = 0
	local cells = table.create(CasinoMath.SCRATCH_CELLS, "")
	local function walk(index: number, probability: number)
		if index > CasinoMath.SCRATCH_CELLS then
			rtp += probability * (CasinoMath.ScratchPay(cells))
			return
		end
		for i = 1, count do
			local symbol = CasinoMath.SCRATCH_SYMBOLS[i]
			cells[index] = symbol.Id
			walk(index + 1, probability * symbol.Weight / total)
		end
	end
	walk(1, 1)
	return rtp
end

CasinoMath.EXCHANGE_BUCKET_SECONDS = 600
CasinoMath.EXCHANGE_DAILY_CAP = 20
CasinoMath.EXCHANGE_BASE_SECONDS = 1800

local function hash01(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

function CasinoMath.ExchangeMood(bucket: number): number
	local blend = hash01(bucket) * 0.6 + hash01(bucket - 1) * 0.4
	return 0.65 + 0.8 * blend
end

function CasinoMath.ExchangeBucket(now: number): number
	return math.floor(now / CasinoMath.EXCHANGE_BUCKET_SECONDS)
end

CasinoMath.CLUB_RANKS = table.freeze({
	table.freeze({ Name = "Newcomer", XP = 0, Reward = nil }),
	table.freeze({ Name = "Regular", XP = 40, Reward = table.freeze({ FreeSpins = 1 }) }),
	table.freeze({ Name = "Gambler", XP = 150, Reward = table.freeze({ Stardust = 12, FreeSpins = 1 }) }),
	table.freeze({ Name = "High Roller", XP = 400, Reward = table.freeze({ Cores = 1, FreeSpins = 2 }) }),
	table.freeze({ Name = "Whale", XP = 1000, Reward = table.freeze({ Stardust = 40, Cores = 2, FreeSpins = 2 }) }),
	table.freeze({ Name = "Starlit Legend", XP = 2500, Reward = table.freeze({ Stardust = 100, Cores = 5, FreeSpins = 3 }) }),
	table.freeze({ Name = "Casino Royale", XP = 6000, Reward = table.freeze({ Stardust = 250, Cores = 10, FreeSpins = 5 }) }),
})

function CasinoMath.ClubXp(stakeTier: number): number
	return 1 + math.clamp(math.floor(stakeTier), 1, 5)
end

function CasinoMath.ClubRank(xp: number): number
	local rank = 1
	for index, entry in CasinoMath.CLUB_RANKS do
		if xp >= entry.XP then
			rank = index
		end
	end
	return rank
end

local function count(value: any, ceiling: number?): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.clamp(math.floor(n), 0, ceiling or 1e9)
end

function CasinoMath.Ensure(bag: any): any
	local source = if type(bag) == "table" then bag else {}
	local function persist(value: any): number | string
		if type(value) == "string" and #value <= 40 and (value == "inf" or (string.match(value, "^[%d%.eE%+]+$") ~= nil and tonumber(value) ~= nil)) then
			return value
		end
		local n = tonumber(value)
		if n == nil or n ~= n or n == math.huge or n == -math.huge or n < 0 then
			return 0
		end
		return n
	end
	local flip = if type(source.Flip) == "table" then source.Flip else {}
	local highLow = if type(source.HighLow) == "table" then source.HighLow else {}
	local scratch = if type(source.Scratch) == "table" then source.Scratch else {}
	local exchange = if type(source.Exchange) == "table" then source.Exchange else {}
	local club = if type(source.Club) == "table" then source.Club else {}
	local claims = {}
	if type(club.Claims) == "table" then
		for rank in club.Claims do
			local index = tonumber(rank)
			if index ~= nil and index >= 1 and index <= #CasinoMath.CLUB_RANKS then
				claims[tostring(math.floor(index))] = true
			end
		end
	end
	return {
		Played = count(source.Played),
		Won = count(source.Won),
		Streak = count(source.Streak, 1000),
		BestStreak = count(source.BestStreak, 1000),
		BiggestWin = persist(source.BiggestWin),
		Flip = {
			Active = flip.Active == true,
			Streak = count(flip.Streak, CasinoMath.FLIP_MAX_STREAK),
			Stake = persist(flip.Stake),
			Tier = math.clamp(count(flip.Tier), 1, 5),
			Base = persist(flip.Base),
		},
		HighLow = {
			Active = highLow.Active == true,
			Card = math.clamp(count(highLow.Card), 1, CasinoMath.HL_RANKS),
			Streak = count(highLow.Streak, CasinoMath.HL_MAX_STREAK),
			Multiplier = math.clamp(tonumber(highLow.Multiplier) or 1, 1, CasinoMath.HL_MAX_MULT),
			Stake = persist(highLow.Stake),
			Tier = math.clamp(count(highLow.Tier), 1, 5),
			Base = persist(highLow.Base),
		},
		Scratch = { FreeDay = math.floor(tonumber(scratch.FreeDay) or -1) },
		Exchange = { Day = math.floor(tonumber(exchange.Day) or -1), Bought = count(exchange.Bought, 1e6) },
		Club = { XP = count(club.XP, 1e9), Claims = claims },
	}
end

return table.freeze(CasinoMath)
