--!strict
-- Purpose: Persistent interactive Card 21 and five-card draw rounds with exact deck order and no stakes.
-- Owner: Astral Forge arcade. Dependencies: ArcadeTypes/ArcadeCards. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Cards = require("./ArcadeCards")
export type API = {
	begin: (round: Types.Round, stream: Types.Stream) -> (),
	act: (round: Types.Round, request: Types.Request) -> (boolean, string?),
}

local function finishBlackjack(round: Types.Round): ()
	local player, dealer = Cards.total(round.PlayerCards), Cards.total(round.DealerCards)
	round.Finished = true
	if player.Total > 21 then
		round.Score, round.Label = 0, "Over 21"
	elseif dealer.Total > 21 then
		round.Score, round.Label = 100, "Dealer went over 21"
	elseif player.Natural and not dealer.Natural then
		round.Score, round.Label = 150, "Natural 21"
	elseif dealer.Natural and not player.Natural then
		round.Score, round.Label = 0, "Dealer has natural 21"
	elseif player.Total == dealer.Total then
		round.Score, round.Label = 50, "Matching totals"
	elseif player.Total > dealer.Total then
		round.Score, round.Label = 100, "Higher total"
	else
		round.Score, round.Label = 0, "Dealer has the higher total"
	end
end

local function begin(round: Types.Round, stream: Types.Stream): ()
	round.Numbers = Cards.deck(stream)
	round.Draws = stream.drawCount()
	if round.Game == "Blackjack" then
		round.PlayerCards = { round.Numbers[1], round.Numbers[3] }
		round.DealerCards = { round.Numbers[2], round.Numbers[4] }
		round.Cursor = 5
		round.Label = "Hit or stand"
		if Cards.total(round.PlayerCards).Natural or Cards.total(round.DealerCards).Natural then
			finishBlackjack(round)
		end
	else
		for index = 1, 5 do
			round.PlayerCards[index] = round.Numbers[index]
		end
		round.Cursor = 6
		round.Label = "Choose which cards to keep"
	end
end

local function act(round: Types.Round, request: Types.Request): (boolean, string?)
	if round.Game == "Blackjack" then
		if request.Action == "Hit" then
			if round.Cursor > #round.Numbers then
				return false, "The deck is exhausted."
			end
			table.insert(round.PlayerCards, round.Numbers[round.Cursor])
			round.Cursor += 1
			if Cards.total(round.PlayerCards).Total >= 21 then
				if Cards.total(round.PlayerCards).Total == 21 then
					while Cards.total(round.DealerCards).Total < 17 and round.Cursor <= #round.Numbers do
						table.insert(round.DealerCards, round.Numbers[round.Cursor])
						round.Cursor += 1
					end
				end
				finishBlackjack(round)
			end
		elseif request.Action == "Stand" then
			-- Dealer stands on soft 17. This rule is fixed and included in replay documentation.
			while Cards.total(round.DealerCards).Total < 17 and round.Cursor <= #round.Numbers do
				table.insert(round.DealerCards, round.Numbers[round.Cursor])
				round.Cursor += 1
			end
			finishBlackjack(round)
		else
			return false, "Choose hit or stand."
		end
	elseif round.Game == "Poker" then
		if request.Action ~= "Draw" then
			return false, "Choose the cards to keep, then draw."
		end
		local held: { [number]: boolean } = {}
		for _, index in request.Picks or {} do
			if index < 1 or index > 5 or index % 1 ~= 0 or held[index] then
				return false, "Held card positions must be distinct."
			end
			held[index] = true
		end
		for index = 1, 5 do
			if not held[index] then
				round.PlayerCards[index] = round.Numbers[round.Cursor]
				round.Cursor += 1
			end
		end
		local result = Cards.poker(round.PlayerCards)
		round.Score, round.Label = result.Score, result.Category
		round.Finished = true
	else
		return false, "This is not a card round."
	end
	return true, nil
end

local api: API = { begin = begin, act = act }
return table.freeze(api)
