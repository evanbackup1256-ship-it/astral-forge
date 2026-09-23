--!strict
-- Pure zone travel / unlock gate checks. No Roblox services — ServerServices
-- and Lune verify scripts share this so world-order / rebirth / core / flux
-- gates can be tested without Studio. Cash comparison is injected (Economy.Lt).

local ZoneUnlock = {}

export type ZoneLike = {
	Id: number,
	Name: string,
	RequiredRebirths: number,
	CoreCost: number,
	Cost: any,
}

export type UnlockFlags = {
	Unlocked: boolean,
	RebirthOk: boolean,
	CoresOk: boolean,
	CashOk: boolean,
	CanUnlock: boolean,
	IsNext: boolean,
}

-- Boolean flags matching Overview world-row readiness (PageRouter / WorldRow).
function ZoneUnlock.Flags(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: any,
	zone: ZoneLike,
	gteCash: (any, any) -> boolean
): UnlockFlags
	local haveZone = math.max(0, math.floor(tonumber(unlockedZone) or 0))
	local haveRebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local haveCores = math.max(0, tonumber(cores) or 0)
	local unlocked = haveZone >= zone.Id
	local rebirthOk = haveRebirths >= (zone.RequiredRebirths or 0)
	local coresOk = haveCores >= (zone.CoreCost or 0)
	local cashOk = gteCash(cash, zone.Cost)
	local isNext = zone.Id == haveZone + 1
	return {
		Unlocked = unlocked,
		RebirthOk = rebirthOk,
		CoresOk = coresOk,
		CashOk = cashOk,
		IsNext = isNext,
		CanUnlock = not unlocked and isNext and rebirthOk and coresOk and cashOk,
	}
end

-- Server unlock/travel decision. Returns kind + optional error message.
-- kind: "Travel" | "Unlock" | "Error"
function ZoneUnlock.Evaluate(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: any,
	zoneId: number,
	zone: ZoneLike,
	cashLt: (any, any) -> boolean
): (string, string?)
	local haveZone = math.max(0, math.floor(tonumber(unlockedZone) or 0))
	local target = math.floor(tonumber(zoneId) or 0)
	if target <= haveZone then
		return "Travel", nil
	end
	if target ~= haveZone + 1 then
		return "Error", "Worlds must be unlocked in order."
	end
	local haveRebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	if haveRebirths < (zone.RequiredRebirths or 0) then
		return "Error", string.format("Requires %d rebirths.", zone.RequiredRebirths or 0)
	end
	local haveCores = math.max(0, tonumber(cores) or 0)
	if haveCores < (zone.CoreCost or 0) then
		return "Error", string.format("Requires %d astral cores.", zone.CoreCost or 0)
	end
	if cashLt(cash, zone.Cost) then
		return "Error", "NEED_MORE_FLUX"
	end
	return "Unlock", nil
end

return table.freeze(ZoneUnlock)
