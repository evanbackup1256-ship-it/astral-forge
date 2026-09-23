--!strict
-- Pure toast/notice helpers peeled from MainGame (wave42). No Roblox services.

local NoticeMath = {}

function NoticeMath.NormalizeTitle(title: any): string
	local text = if type(title) == "string" then title else tostring(title)
	if text == "Boost online" then
		return "Boost on"
	elseif text == "Rebirth" then
		return "Rebirth done"
	elseif text == "Order paid" then
		return "Claimed"
	elseif text == "Studio grant" then
		return "Purchase test"
	end
	return text
end

function NoticeMath.Signature(title: string, body: any, tone: any): string
	return `{title}|{body}|{tone}`
end

function NoticeMath.ShouldDedupe(lastSignature: string, lastAt: number, signature: string, now: number, window: number?): boolean
	local gap = if type(window) == "number" then window else 0.55
	return lastSignature == signature and (now - lastAt) < gap
end

function NoticeMath.Lifetime(notificationDuration: number): number
	local duration = tonumber(notificationDuration) or 0
	return 2.8 + duration * 4.4
end

function NoticeMath.MaxNotices(toastDensity: number): number
	local density = tonumber(toastDensity) or 0
	return math.clamp(math.floor(2 + density * 3 + 0.5), 2, 5)
end

return table.freeze(NoticeMath)
