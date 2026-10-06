--!strict
-- Astral Casino rules: every game's return-to-player sits where the house wants it, the payout tables only
-- pay what they say, ladders cap, and the saved bag rebuilds from garbage. Pure CasinoMath; no Studio.

local CasinoMath = require("../src/Server/AstralForge/Modules/CasinoMath")

local function between(value: number, low: number, high: number, label: string)
	assert(value >= low and value <= high, `{label}: {value} not in [{low}, {high}]`)
end

-- --- house edge: exact where it can be enumerated -----------------------------
between(CasinoMath.SlotsRtp(), 0.92, 0.97, "slots RTP")
between(CasinoMath.ScratchRtp(), 0.90, 0.97, "scratch RTP")
for _, pick in { "Red", "Black", "Odd", "Even", "Low", "High", "D1", "D2", "D3", "C1", "C2", "C3", "N0", "N17", "N36" } do
	local total = 0
	for number = 0, 36 do
		total += CasinoMath.RoulettePay(pick, number)
	end
	between(total / 37, 0.97, 0.9731, "roulette RTP " .. pick)
end
between(CasinoMath.FLIP_WIN_CHANCE * CasinoMath.FLIP_STEP, 0.94, 0.96, "flip RTP per flip")
for card = 1, CasinoMath.HL_RANKS do
	for _, guess in { "High", "Low" } do
		local chance, step = CasinoMath.HighLowOdds(card, guess)
		if chance > 0 then
			assert(math.abs(chance * step - CasinoMath.HL_RETURN) < 1e-9, "high-low pays 0.96 per guess")
		end
	end
end
-- a tie loses, so the ends of the ladder offer one side
assert(CasinoMath.HighLowOdds(1, "Low") == 0 and CasinoMath.HighLowOdds(13, "High") == 0, "no impossible guesses")
assert(CasinoMath.HighLowWins(5, 5, "High") == false and CasinoMath.HighLowWins(5, 5, "Low") == false, "a tie loses")

-- --- the rolls themselves, driven by a scripted random ---------------------------
local function scripted(values: { number }): () -> number
	local index = 0
	return function()
		index += 1
		return values[((index - 1) % #values) + 1]
	end
end
local reels, multiplier, kind = CasinoMath.SlotsSpin(scripted({ 0.999 })) -- the last symbol, three times
assert(reels[1] == "Nova" and reels[3] == "Nova" and multiplier == 700 and kind == "Triple", "three Novas pay the jackpot")
local _, miss = CasinoMath.SlotsSpin(scripted({ 0.0, 0.5, 0.97 }))
assert(miss == 0, "three different symbols pay nothing")
assert(CasinoMath.SlotsPay("Core", "Core", "Ember") == 0, "a pair of Cores pays nothing")
assert(CasinoMath.SlotsPay("Ember", "Core", "Ember") == 0.6, "a pair of Embers pays a little")

assert(CasinoMath.RouletteSpin(scripted({ 0 })) == 0 and CasinoMath.RouletteSpin(scripted({ 0.999999 })) == 36, "roulette covers 0..36")
assert(CasinoMath.RouletteColor(0) == "Green" and CasinoMath.RouletteColor(1) == "Red" and CasinoMath.RouletteColor(2) == "Black", "colours")
assert(CasinoMath.RoulettePay("Red", 0) == 0, "zero loses every outside bet")
assert(CasinoMath.RoulettePay("N17", 17) == 36 and CasinoMath.RoulettePay("N17", 18) == 0, "straight up")
assert(CasinoMath.RoulettePickValid("N36") and not CasinoMath.RoulettePickValid("N37") and not CasinoMath.RoulettePickValid("Bogus") and not CasinoMath.RoulettePickValid(5), "pick validation")

assert(CasinoMath.ScratchPay({ "Spark", "Spark", "Spark", "Core", "Dust", "Comet" }) == 0.5, "three alike pays")
assert(CasinoMath.ScratchPay({ "Spark", "Spark", "Core", "Core", "Dust", "Comet" }) == 0, "two alike pays nothing")
assert(CasinoMath.ScratchPay({ "Spark", "Spark", "Spark", "Star", "Star", "Star" }) == 35, "the best symbol pays")

-- --- ladders cap ---------------------------------------------------------------
assert(CasinoMath.FlipMultiplier(0) == 1 and CasinoMath.FlipMultiplier(1) == CasinoMath.FLIP_STEP, "flip ladder starts at the stake")
assert(CasinoMath.FlipMultiplier(500) <= CasinoMath.FLIP_MAX_MULT, "flip ladder is capped")

-- --- the exchange ticker is deterministic and bounded --------------------------------
for bucket = 0, 2000 do
	between(CasinoMath.ExchangeMood(bucket), 0.65, 1.45, "exchange mood")
end
assert(CasinoMath.ExchangeMood(123) == CasinoMath.ExchangeMood(123), "the market is the same for everyone in a window")

-- --- the club ---------------------------------------------------------------------
assert(CasinoMath.ClubRank(0) == 1 and CasinoMath.ClubRank(40) == 2 and CasinoMath.ClubRank(10_000_000) == #CasinoMath.CLUB_RANKS, "club ranks")
assert(CasinoMath.ClubXp(1) == 2 and CasinoMath.ClubXp(5) == 6 and CasinoMath.ClubXp(99) == 6, "club XP by stake")

-- --- the saved bag rebuilds from garbage ---------------------------------------------
local clean = CasinoMath.Ensure(nil)
assert(clean.Played == 0 and clean.Flip.Active == false and clean.HighLow.Multiplier == 1 and clean.Club.XP == 0, "nil becomes a fresh bag")
local dirty = CasinoMath.Ensure({
	Played = math.huge,
	Won = "x",
	Streak = -5,
	BiggestWin = 0 / 0,
	Flip = { Active = true, Streak = 99, Stake = -1, Tier = 99 },
	HighLow = { Card = 99, Multiplier = 1e9 },
	Exchange = { Day = "x", Bought = 1e12 },
	Club = { XP = -5, Claims = { ["2"] = true, ["99"] = true, bogus = true } },
})
assert(dirty.Played == 0 and dirty.Won == 0 and dirty.Streak == 0 and dirty.BiggestWin == 0, "non-finite and mistyped numbers become 0")
assert(dirty.Flip.Streak == CasinoMath.FLIP_MAX_STREAK and dirty.Flip.Tier == 5 and dirty.Flip.Stake == 0, "flip fields clamp")
assert(dirty.HighLow.Card == CasinoMath.HL_RANKS and dirty.HighLow.Multiplier == CasinoMath.HL_MAX_MULT, "high-low fields clamp")
assert(dirty.Exchange.Bought <= 1e6 and dirty.Club.XP == 0, "exchange and club clamp")
assert(dirty.Club.Claims["2"] == true and dirty.Club.Claims["99"] == nil and dirty.Club.Claims.bogus == nil, "club claims keep only real ranks")

print("[TEST] casino math guards passed | slots+scratch+roulette+flip+high-low RTP, caps, exchange, club, bag rebuild")
