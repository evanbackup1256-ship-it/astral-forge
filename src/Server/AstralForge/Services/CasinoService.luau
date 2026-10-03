--!strict

return function(loadService: (string) -> any)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local CasinoMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CasinoMath"))
	local ProgressionService = loadService("ProgressionService")

	local CasinoService = {}

	local DAY = 86400
	local SLOTS_RTP = CasinoMath.SlotsRtp()
	local SCRATCH_RTP = CasinoMath.ScratchRtp()

	local function day(now: number): number
		return math.floor(now / DAY)
	end

	local function ensure(profile): any
		profile.Casino = CasinoMath.Ensure(profile.Casino)
		return profile.Casino
	end

	local function stakeAmount(profile, tier: number): any
		local share = Economy.Floor(Economy.Mul(profile.Cash, CasinoMath.STAKES[tier]))
		return Economy.Max(1, share)
	end

	local function tierOf(payload: any): number?
		local tier = tonumber(payload and payload.Tier)
		if tier == nil or tier ~= math.floor(tier) or tier < 1 or tier > #CasinoMath.STAKES then
			return nil
		end
		return tier
	end

	local function capped(base: any, stake: any, payout: any): any
		local ceiling = Economy.Add(Economy.Mul(base, CasinoMath.PROFIT_CAP), stake)
		if Economy.Gt(payout, ceiling) then
			return ceiling
		end
		return payout
	end

	local function recordRound(casino, tier: number, won: boolean, payout: any)
		casino.Played += 1
		casino.Club.XP = math.min(1e9, casino.Club.XP + CasinoMath.ClubXp(tier))
		if won then
			casino.Won += 1
			casino.Streak = math.min(1000, casino.Streak + 1)
			casino.BestStreak = math.max(casino.BestStreak, casino.Streak)
			if Economy.Gt(payout, casino.BiggestWin) then
				casino.BiggestWin = Economy.Persist(payout)
			end
		else
			casino.Streak = 0
		end
	end

	local function pay(profile, amount: any)
		profile.Cash = Economy.Add(profile.Cash, amount)
	end

	local function take(profile, amount: any): boolean
		if not Economy.Gte(profile.Cash, amount) then
			return false
		end
		profile.Cash = Economy.Sub(profile.Cash, amount)
		return true
	end

	local function result(game: string, won: boolean, stake: any, payout: any, extra: any): any
		extra.Game = game
		extra.Won = won
		extra.Stake = Economy.Persist(stake)
		extra.Payout = Economy.Persist(payout)
		return extra
	end

	local function playSlots(profile, random: Random, payload): (boolean, string, any?)
		local tier = tierOf(payload)
		if tier == nil then
			return false, "Pick a stake."
		end
		local casino = ensure(profile)
		local stake = stakeAmount(profile, tier)
		local base = profile.Cash
		if not take(profile, stake) then
			return false, "Not enough flux for that stake."
		end
		local reels, multiplier, kind = CasinoMath.SlotsSpin(function()
			return random:NextNumber()
		end)
		local payout = if multiplier > 0 then capped(base, stake, Economy.Mul(stake, multiplier)) else 0
		if multiplier > 0 then
			pay(profile, payout)
		end
		local won = multiplier >= 1
		recordRound(casino, tier, won, payout)
		local message = if kind == "Triple" then `Three {reels[1]}! x{multiplier}` elseif kind == "Pair" and multiplier > 0 then `A pair of {reels[1] == reels[2] and reels[1] or reels[3]}.` else "No match."
		return true, message, result("Slots", won, stake, payout, { Reels = reels, Multiplier = multiplier, Kind = kind })
	end

	local function playRoulette(profile, random: Random, payload): (boolean, string, any?)
		local tier = tierOf(payload)
		if tier == nil then
			return false, "Pick a stake."
		end
		local pick = payload and payload.Pick
		if not CasinoMath.RoulettePickValid(pick) then
			return false, "Pick something to bet on."
		end
		local casino = ensure(profile)
		local stake = stakeAmount(profile, tier)
		local base = profile.Cash
		if not take(profile, stake) then
			return false, "Not enough flux for that stake."
		end
		local number = CasinoMath.RouletteSpin(function()
			return random:NextNumber()
		end)
		local multiplier = CasinoMath.RoulettePay(pick :: string, number)
		local payout = if multiplier > 0 then capped(base, stake, Economy.Mul(stake, multiplier)) else 0
		if multiplier > 0 then
			pay(profile, payout)
		end
		recordRound(casino, tier, multiplier > 0, payout)
		local color = CasinoMath.RouletteColor(number)
		local message = if multiplier > 0 then `{number} {color}: your {pick} wins x{multiplier}.` else `{number} {color}. Your {pick} loses.`
		return true, message, result("Roulette", multiplier > 0, stake, payout, { Number = number, Color = color, Pick = pick, Multiplier = multiplier })
	end

	local function playScratch(profile, random: Random, payload, now: number): (boolean, string, any?)
		local casino = ensure(profile)
		local free = payload and payload.Free == true
		local tier = if free then 1 else tierOf(payload)
		if tier == nil then
			return false, "Pick a stake."
		end
		local stake = stakeAmount(profile, tier)
		local base = profile.Cash
		if free then
			if casino.Scratch.FreeDay == day(now) then
				return false, "Today's free card is already scratched."
			end
			casino.Scratch.FreeDay = day(now)
		elseif not take(profile, stake) then
			return false, "Not enough flux for that stake."
		end
		local cells, multiplier, symbol = CasinoMath.ScratchCard(function()
			return random:NextNumber()
		end)
		local payout = if multiplier > 0 then capped(base, if free then 0 else stake, Economy.Mul(stake, multiplier)) else 0
		if multiplier > 0 then
			pay(profile, payout)
		end
		recordRound(casino, tier, multiplier >= 1 or (free and multiplier > 0), payout)
		local message = if symbol ~= nil then `Three {symbol}! x{multiplier}` else "Nothing matched."
		return true, message, result("Scratch", multiplier > 0, if free then 0 else stake, payout, { Cells = cells, Multiplier = multiplier, Symbol = symbol, Free = free })
	end

	local function settleLadder(profile, casino, round, multiplier: number, tier: number, game: string, extra: any): (boolean, string, any?)
		local payout = capped(round.Base, round.Stake, Economy.Mul(round.Stake, multiplier))
		pay(profile, payout)
		local stake = round.Stake
		round.Active, round.Streak, round.Stake, round.Base = false, 0, 0, 0
		if game == "HighLow" then
			round.Multiplier = 1
		end
		recordRound(casino, tier, true, payout)
		extra.Cashed = true
		extra.Multiplier = multiplier
		return true, `Cashed out x{string.format("%.2f", multiplier)}.`, result(game, true, stake, payout, extra)
	end

	local function playFlip(profile, random: Random, payload): (boolean, string, any?)
		local casino = ensure(profile)
		local flip = casino.Flip
		local op = payload and payload.Op
		if op == "Cashout" then
			if not flip.Active or flip.Streak < 1 then
				return false, "Flip at least once before cashing out."
			end
			return settleLadder(profile, casino, flip, CasinoMath.FlipMultiplier(flip.Streak), flip.Tier, "Flip", { Streak = flip.Streak })
		end
		if not flip.Active then
			local tier = tierOf(payload)
			if tier == nil then
				return false, "Pick a stake."
			end
			local stake = stakeAmount(profile, tier)
			local base = profile.Cash
			if not take(profile, stake) then
				return false, "Not enough flux for that stake."
			end
			flip.Active, flip.Streak, flip.Stake, flip.Tier, flip.Base = true, 0, Economy.Persist(stake), tier, Economy.Persist(base)
		end
		local heads = CasinoMath.FlipRoll(function()
			return random:NextNumber()
		end)
		if not heads then
			local stake, tier = flip.Stake, flip.Tier
			local streak = flip.Streak
			flip.Active, flip.Streak, flip.Stake, flip.Base = false, 0, 0, 0
			recordRound(casino, tier, false, 0)
			return true, "Tails. The stake is gone.", result("Flip", false, stake, 0, { Heads = false, Streak = streak, Lost = true })
		end
		flip.Streak += 1
		local multiplier = CasinoMath.FlipMultiplier(flip.Streak)
		if flip.Streak >= CasinoMath.FLIP_MAX_STREAK then
			return settleLadder(profile, casino, flip, multiplier, flip.Tier, "Flip", { Heads = true, Streak = flip.Streak, Maxed = true })
		end
		return true, `Heads! x{string.format("%.2f", multiplier)} and counting.`, result("Flip", true, flip.Stake, 0, { Heads = true, Streak = flip.Streak, Multiplier = multiplier, Open = true })
	end

	local function playHighLow(profile, random: Random, payload): (boolean, string, any?)
		local casino = ensure(profile)
		local round = casino.HighLow
		local op = payload and payload.Op
		local function rand(): number
			return random:NextNumber()
		end
		if op == "Start" then
			if round.Active then
				return false, "A round is already open."
			end
			local tier = tierOf(payload)
			if tier == nil then
				return false, "Pick a stake."
			end
			local stake = stakeAmount(profile, tier)
			local base = profile.Cash
			if not take(profile, stake) then
				return false, "Not enough flux for that stake."
			end
			round.Active, round.Streak, round.Multiplier, round.Stake, round.Tier, round.Base = true, 0, 1, Economy.Persist(stake), tier, Economy.Persist(base)
			round.Card = CasinoMath.HighLowDraw(rand)
			return true, "The first card is down.", result("HighLow", true, stake, 0, { Card = round.Card, Open = true, Started = true })
		end
		if not round.Active then
			return false, "Start a round first."
		end
		if op == "Cashout" then
			if round.Streak < 1 then
				return false, "Win a guess before cashing out."
			end
			return settleLadder(profile, casino, round, round.Multiplier, round.Tier, "HighLow", { Card = round.Card, Streak = round.Streak })
		end
		if op ~= "Guess" then
			return false, "Unknown move."
		end
		local guess = payload and payload.Pick
		if guess ~= "High" and guess ~= "Low" then
			return false, "Guess High or Low."
		end
		local chance, step = CasinoMath.HighLowOdds(round.Card, guess)
		if chance <= 0 then
			return false, `You cannot guess {guess} on that card.`
		end
		local previous = round.Card
		local nextCard = CasinoMath.HighLowDraw(rand)
		if CasinoMath.HighLowWins(previous, nextCard, guess) then
			round.Card = nextCard
			round.Streak += 1
			round.Multiplier = math.min(CasinoMath.HL_MAX_MULT, round.Multiplier * step)
			if round.Streak >= CasinoMath.HL_MAX_STREAK or round.Multiplier >= CasinoMath.HL_MAX_MULT then
				return settleLadder(profile, casino, round, round.Multiplier, round.Tier, "HighLow", { Card = nextCard, Previous = previous, Streak = round.Streak, Maxed = true })
			end
			return true, `{nextCard}: right! x{string.format("%.2f", round.Multiplier)}.`, result("HighLow", true, round.Stake, 0, { Card = nextCard, Previous = previous, Streak = round.Streak, Multiplier = round.Multiplier, Open = true })
		end
		local stake, tier = round.Stake, round.Tier
		round.Active, round.Streak, round.Stake, round.Base, round.Multiplier = false, 0, 0, 0, 1
		recordRound(casino, tier, false, 0)
		return true, `{nextCard}: wrong. The stake is gone.`, result("HighLow", false, stake, 0, { Card = nextCard, Previous = previous, Lost = true })
	end

	local function exchangePrice(profile, mood: number): any
		local seconds = CasinoMath.EXCHANGE_BASE_SECONDS * mood
		local price = Economy.Floor(Economy.Mul(Economy.SteadyProduction(profile), seconds))
		return Economy.Max(25000, price)
	end

	local function playExchange(profile, payload, now: number): (boolean, string, any?)
		local casino = ensure(profile)
		local exchange = casino.Exchange
		local today = day(now)
		if exchange.Day ~= today then
			exchange.Day, exchange.Bought = today, 0
		end
		local amount = tonumber(payload and payload.Count)
		if amount == nil or amount ~= math.floor(amount) or amount < 1 or amount > CasinoMath.EXCHANGE_DAILY_CAP then
			return false, "Pick how much Stardust to buy."
		end
		local left = CasinoMath.EXCHANGE_DAILY_CAP - exchange.Bought
		if amount > left then
			return false, if left <= 0 then "You have bought today's whole allowance." else `Only {left} Stardust left today.`
		end
		local mood = CasinoMath.ExchangeMood(CasinoMath.ExchangeBucket(now))
		local unit = exchangePrice(profile, mood)
		local cost = Economy.Mul(unit, amount)
		if not take(profile, cost) then
			return false, "Not enough flux."
		end
		profile.Stardust = (tonumber(profile.Stardust) or 0) + amount
		exchange.Bought += amount
		return true, `Bought {amount} Stardust.`, { Game = "Exchange", Bought = amount, Cost = Economy.Persist(cost) }
	end

	local function claimRank(profile, payload): (boolean, string, any?)
		local casino = ensure(profile)
		local rank = tonumber(payload and payload.Rank)
		if rank == nil or rank ~= math.floor(rank) or rank < 2 or rank > #CasinoMath.CLUB_RANKS then
			return false, "Pick a rank."
		end
		if CasinoMath.ClubRank(casino.Club.XP) < rank then
			return false, "You have not reached that rank."
		end
		if casino.Club.Claims[tostring(rank)] then
			return false, "That rank's reward is already claimed."
		end
		local entry = CasinoMath.CLUB_RANKS[rank]
		casino.Club.Claims[tostring(rank)] = true
		local message = ProgressionService.ApplyReward(profile, entry.Reward, Economy.Production(profile))
		return true, `{entry.Name}: {message}`, { Game = "Club", Rank = rank }
	end

	function CasinoService.Play(profile, random: Random, payload: any, now: number): (boolean, string, any?)
		if type(payload) ~= "table" or type(payload.Game) ~= "string" then
			return false, "Pick a game.", nil
		end
		local game = payload.Game
		if game == "Slots" then
			return playSlots(profile, random, payload)
		elseif game == "Roulette" then
			return playRoulette(profile, random, payload)
		elseif game == "Scratch" then
			return playScratch(profile, random, payload, now)
		elseif game == "Flip" then
			return playFlip(profile, random, payload)
		elseif game == "HighLow" then
			return playHighLow(profile, random, payload)
		elseif game == "Exchange" then
			return playExchange(profile, payload, now)
		elseif game == "Club" then
			return claimRank(profile, payload)
		end
		return false, "Unknown game.", nil
	end

	function CasinoService.State(profile, now: number): any
		local casino = ensure(profile)
		local stakes = {}
		for tier, share in CasinoMath.STAKES do
			table.insert(stakes, { Tier = tier, Name = CasinoMath.STAKE_NAMES[tier], Share = share, Amount = Economy.Persist(stakeAmount(profile, tier)) })
		end
		local flip, round = casino.Flip, casino.HighLow
		local bucket = CasinoMath.ExchangeBucket(now)
		local mood = CasinoMath.ExchangeMood(bucket)
		local today = day(now)
		local history = {}
		for back = 23, 0, -1 do
			table.insert(history, CasinoMath.ExchangeMood(bucket - back))
		end
		local bought = if casino.Exchange.Day == today then casino.Exchange.Bought else 0
		local highChance, highStep = CasinoMath.HighLowOdds(round.Card, "High")
		local lowChance, lowStep = CasinoMath.HighLowOdds(round.Card, "Low")
		local rank = CasinoMath.ClubRank(casino.Club.XP)
		local ranks = {}
		for index, entry in CasinoMath.CLUB_RANKS do
			table.insert(ranks, {
				Rank = index,
				Name = entry.Name,
				XP = entry.XP,
				Reward = entry.Reward,
				Claimed = casino.Club.Claims[tostring(index)] == true,
				Claimable = entry.Reward ~= nil and index <= rank and casino.Club.Claims[tostring(index)] ~= true,
			})
		end
		local nextRank = CasinoMath.CLUB_RANKS[rank + 1]
		return {
			Stakes = stakes,
			Stats = { Played = casino.Played, Won = casino.Won, Streak = casino.Streak, BestStreak = casino.BestStreak, BiggestWin = casino.BiggestWin },
			Slots = { Symbols = CasinoMath.SLOT_SYMBOLS, Rtp = SLOTS_RTP },
			Roulette = { Zero = "Green" },
			Flip = {
				Active = flip.Active,
				Streak = flip.Streak,
				Stake = flip.Stake,
				Multiplier = CasinoMath.FlipMultiplier(flip.Streak),
				NextMultiplier = CasinoMath.FlipMultiplier(flip.Streak + 1),
				Cashout = if flip.Active and flip.Streak > 0 then Economy.Persist(capped(flip.Base, flip.Stake, Economy.Mul(flip.Stake, CasinoMath.FlipMultiplier(flip.Streak)))) else 0,
				MaxStreak = CasinoMath.FLIP_MAX_STREAK,
				Chance = CasinoMath.FLIP_WIN_CHANCE,
			},
			HighLow = {
				Active = round.Active,
				Card = round.Card,
				Streak = round.Streak,
				Multiplier = round.Multiplier,
				Stake = round.Stake,
				Cashout = if round.Active and round.Streak > 0 then Economy.Persist(capped(round.Base, round.Stake, Economy.Mul(round.Stake, round.Multiplier))) else 0,
				High = { Chance = highChance, Step = highStep },
				Low = { Chance = lowChance, Step = lowStep },
			},
			Scratch = { FreeReady = casino.Scratch.FreeDay ~= today, Symbols = CasinoMath.SCRATCH_SYMBOLS, Rtp = SCRATCH_RTP },
			Exchange = {
				Mood = mood,
				History = history,
				Price = Economy.Persist(exchangePrice(profile, mood)),
				Cap = CasinoMath.EXCHANGE_DAILY_CAP,
				Bought = bought,
				Left = CasinoMath.EXCHANGE_DAILY_CAP - bought,
				NextAt = (bucket + 1) * CasinoMath.EXCHANGE_BUCKET_SECONDS,
				Trend = CasinoMath.ExchangeMood(bucket + 1) - mood,
			},
			Club = { XP = casino.Club.XP, Rank = rank, RankName = CasinoMath.CLUB_RANKS[rank].Name, NextXP = if nextRank ~= nil then nextRank.XP else nil, Ranks = ranks },
		}
	end

	return CasinoService
end
