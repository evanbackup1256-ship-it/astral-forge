--!strict
-- Pure leaderboard climb brackets for rank-ping toasts. No Roblox services —
-- ServerServices and Lune verify scripts share this so bracket crossings stay
-- testable without Studio. Bracket list / unranked sentinel are injected.

local RankBracket = {}

RankBracket.DEFAULT_BRACKETS = { 1, 3, 10, 25 }
RankBracket.UNRANKED = math.huge

function RankBracket.Of(rank: number, brackets: { number }?, unranked: number?): number
	local list = brackets or RankBracket.DEFAULT_BRACKETS
	local fallback = if unranked ~= nil then unranked else RankBracket.UNRANKED
	for _, bracket in list do
		if rank <= bracket then
			return bracket
		end
	end
	return fallback
end

-- Climb toast fires when seeded, rank improved, and bracket tightened.
function RankBracket.ShouldAnnounce(previousRank: number, nextRank: number, brackets: { number }?, unranked: number?): boolean
	local fallback = if unranked ~= nil then unranked else RankBracket.UNRANKED
	local seeded = previousRank > 0
	if not seeded or nextRank >= previousRank then
		return false
	end
	local bracket = RankBracket.Of(nextRank, brackets, fallback)
	local previousBracket = RankBracket.Of(previousRank, brackets, fallback)
	return bracket ~= fallback and bracket < previousBracket
end

return table.freeze(RankBracket)
