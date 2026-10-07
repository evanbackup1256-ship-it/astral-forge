--!strict
-- Purpose: Shared deck, blackjack and draw-poker scoring rules for server play and independent replay.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes, ArcadeConfig. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
export type Hand = { Total: number, Soft: boolean, Natural: boolean }
export type PokerHand = { Category: string, Score: number }
export type API = {
	deck: (stream: Types.Stream) -> Types.Numbers,
	rank: (card: number) -> number,
	suit: (card: number) -> number,
	total: (cards: Types.Numbers) -> Hand,
	poker: (cards: Types.Numbers) -> PokerHand,
}

local function rank(card: number): number
	assert(card >= 1 and card <= 52 and card % 1 == 0, "invalid card")
	return (card - 1) % 13 + 1
end

local function suit(card: number): number
	assert(card >= 1 and card <= 52 and card % 1 == 0, "invalid card")
	return math.floor((card - 1) / 13) + 1
end

local function deck(stream: Types.Stream): Types.Numbers
	local cards: Types.Numbers = {}
	for card = 1, 52 do
		cards[card] = card
	end
	for index = #cards, 2, -1 do
		local target = stream.integer(1, index)
		cards[index], cards[target] = cards[target], cards[index]
	end
	return cards
end

local function total(cards: Types.Numbers): Hand
	local sum, aces = 0, 0
	for _, card in cards do
		local value = rank(card)
		sum += math.min(value, 10)
		if value == 1 then
			aces += 1
		end
	end
	local soft = aces > 0 and sum + 10 <= 21
	if soft then
		sum += 10
	end
	return { Total = sum, Soft = soft, Natural = #cards == 2 and sum == 21 }
end

local function poker(cards: Types.Numbers): PokerHand
	assert(#cards == 5, "five cards required")
	local ranks: Types.Numbers = {}
	local counts: { [number]: number } = {}
	local seen: { [number]: boolean } = {}
	local flush = true
	for index, card in cards do
		assert(not seen[card], "duplicate card")
		seen[card] = true
		local value = rank(card)
		value = if value == 1 then 14 else value
		ranks[index] = value
		counts[value] = (counts[value] or 0) + 1
		if suit(card) ~= suit(cards[1]) then
			flush = false
		end
	end
	table.sort(ranks)
	local straight = true
	for index = 2, #ranks do
		if ranks[index] ~= ranks[1] + index - 1 then
			straight = false
		end
	end
	if ranks[1] == 2 and ranks[2] == 3 and ranks[3] == 4 and ranks[4] == 5 and ranks[5] == 14 then
		straight = true
	end
	local pairs, triple, four, highPair = 0, false, false, false
	for value, count in counts do
		if count == 2 then
			pairs += 1
			if value >= 11 then
				highPair = true
			end
		elseif count == 3 then
			triple = true
		elseif count == 4 then
			four = true
		end
	end
	local category = if flush
			and straight
			and ranks[1] == 10
		then "RoyalFlush"
		elseif flush and straight then "StraightFlush"
		elseif four then "FourKind"
		elseif triple and pairs == 1 then "FullHouse"
		elseif flush then "Flush"
		elseif straight then "Straight"
		elseif triple then "ThreeKind"
		elseif pairs == 2 then "TwoPair"
		elseif highPair then "HighPair"
		else "None"
	return { Category = category, Score = Config.PokerScores[category] }
end

local api: API = { deck = deck, rank = rank, suit = suit, total = total, poker = poker }
return table.freeze(api)
