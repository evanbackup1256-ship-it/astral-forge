--!strict
-- Pure general leaderboard board-value projection. No Roblox services —
-- ServerServices and Lune verify scripts share this so Flux/Rebirths/PlayTime/
-- Dust/Cores/Domain/Worlds scoring stays testable without Studio. Persist for
-- LifetimeCash is injected (Economy.Persist under Studio).

local GeneralBoardValue = {}

function GeneralBoardValue.Of(profile: any, id: string, persist: (any) -> any): number
	if id == "Flux" then
		return persist(profile.LifetimeCash)
	end
	if id == "Rebirths" then
		return math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
	end
	if id == "PlayTime" then
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.PlayTime) or 0))
	end
	if id == "Dust" then
		return math.max(0, math.floor(tonumber(profile.Stardust) or 0))
	end
	if id == "Cores" then
		return math.max(0, math.floor(tonumber(profile.Cores) or 0))
	end
	if id == "Domain" then
		return math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0))
	end
	if id == "Worlds" then
		return math.max(1, math.floor(tonumber(profile.Zone) or 1))
	end
	return 0
end

return table.freeze(GeneralBoardValue)
