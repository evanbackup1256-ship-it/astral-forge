--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

local Format = {}

local SUFFIXES = {
	"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
	"Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg",
	"Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion",
	"Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign",
	"Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex",
	"Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx",
	"Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx",
	"Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega",
	"Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless",
	"Apex", "Horizon",
}

local LAST_NAMED_LOG10 = #SUFFIXES * 3

local function formatFromLog10(log10: number): string
	if log10 ~= log10 or log10 <= 0 then
		return "0"
	end
	if log10 < 3 then
		return string.format("%.0f", 10 ^ log10)
	end
	if log10 >= LAST_NAMED_LOG10 then
		local exponent = math.floor(log10)
		local mantissa = 10 ^ (log10 - exponent)
		return string.format("%.2fe%d", mantissa, exponent)
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #SUFFIXES)
	local scaled = 10 ^ (log10 - group * 3)
	if scaled >= 1000 and group < #SUFFIXES then
		group += 1
		scaled /= 1000
	end
	local suffix = SUFFIXES[group]
	local precision = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
	local formatted = string.format("%." .. tostring(precision) .. "f", scaled)
	formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return formatted .. suffix
end

local function scaleForDisplay(value: number): (number, string)
	local absolute = math.abs(value)
	if absolute ~= absolute or absolute == 0 then
		return 0, ""
	end
	if absolute == math.huge or math.log(absolute) / math.log(10) >= LAST_NAMED_LOG10 then
		return 1, "e308+"
	end
	if absolute < 1000 then
		return value, ""
	end
	local group = math.clamp(math.floor(math.log(absolute) / math.log(1000)), 1, #SUFFIXES)
	local scaled = value / (1000 ^ group)
	if math.abs(scaled) >= 1000 and group < #SUFFIXES then
		group += 1
		scaled /= 1000
	end
	return scaled, SUFFIXES[group]
end

function Format.Number(value: any, decimals: number?): string
	if type(value) == "string" or type(value) == "table" then
		return formatFromLog10(OmegaMath.Log10(value))
	end
	if type(value) ~= "number" or value ~= value then
		return "0"
	end
	if value == math.huge or value == -math.huge then
		return formatFromLog10(OmegaMath.Log10(value))
	end
	if math.abs(value) >= 1000 then
		return formatFromLog10(math.log(math.abs(value)) / math.log(10))
	end
	local scaled, suffix = scaleForDisplay(value)
	if suffix == "" then
		local absolute = math.abs(value)
		local precision = decimals
		if precision == nil then
			precision = absolute < 10 and absolute % 1 ~= 0 and 1 or 0
		end
		local formatted = string.format("%." .. tostring(precision) .. "f", value)
		formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
		return formatted
	end
	local absolute = math.abs(scaled)
	local precision = decimals
	if precision == nil then
		if absolute < 10 then
			precision = 2
		elseif absolute < 100 then
			precision = 1
		else
			precision = 0
		end
	end
	local formatted = string.format("%." .. tostring(precision) .. "f", scaled)
	formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return formatted .. suffix
end

function Format.Integer(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	local sign, digits = text:match("^([%-]?)(%d+)$")
	if not digits then
		return text
	end
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
	local result = reversed:reverse():gsub("^,", "")
	return (sign or "") .. result
end

function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remaining = seconds % 60
	if days > 0 then
		return string.format("%dd %02dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, remaining)
	end
	return string.format("%ds", remaining)
end

function Format.Percent(value: number, decimals: number?): string
	return string.format("%." .. tostring(decimals or 0) .. "f%%", value * 100)
end

return table.freeze(Format)
