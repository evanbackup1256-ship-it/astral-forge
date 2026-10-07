--!strict
-- Purpose: Human-readable card faces for the arcade controls.
-- Owner: Astral Forge presentation. Dependencies: ArcadeCards. Last-reviewed: 2026-10-05.
local Cards = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeCards")
local function cardName(card: number): string
	local rank = Cards.rank(card)
	local name = ({ "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" })[rank]
	return name .. ({ "♠", "♥", "♣", "♦" })[Cards.suit(card)]
end

return table.freeze({ cardName = cardName })
