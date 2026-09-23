local LN10 = math.log(10)
local compactNumber
local function formatReward(reward)
	if not reward then
		return ""
	end
	local parts = {}
	if reward.Cash ~= nil and reward.Cash > 0 then
		local _arg0 = `{compactNumber(reward.Cash)} flux`
		table.insert(parts, _arg0)
	end
	if reward.CashMinutes ~= nil and reward.CashMinutes > 0 then
		local _arg0 = `{compactNumber(reward.CashMinutes)} min of flux`
		table.insert(parts, _arg0)
	end
	if reward.Stardust ~= nil and reward.Stardust > 0 then
		local _arg0 = `{compactNumber(reward.Stardust)} stardust`
		table.insert(parts, _arg0)
	end
	if reward.Cores ~= nil and reward.Cores > 0 then
		local _arg0 = `{compactNumber(reward.Cores)} cores`
		table.insert(parts, _arg0)
	end
	if reward.Signals ~= nil and reward.Signals > 0 then
		local _arg0 = `{compactNumber(reward.Signals)} signals`
		table.insert(parts, _arg0)
	end
	if reward.CommandXP ~= nil and reward.CommandXP > 0 then
		local _arg0 = `{compactNumber(reward.CommandXP)} command XP`
		table.insert(parts, _arg0)
	end
	if reward.StreakShield ~= nil and reward.StreakShield > 0 then
		local _arg0 = `{reward.StreakShield} streak shield`
		table.insert(parts, _arg0)
	end
	local essenceAmount = 0
	if reward.Essence ~= nil and reward.Essence > 0 then
		essenceAmount += reward.Essence
	end
	if reward.DomainEssence ~= nil and reward.DomainEssence > 0 then
		essenceAmount += reward.DomainEssence
	end
	if essenceAmount > 0 then
		table.insert(parts, `{compactNumber(essenceAmount)} domain essence`)
	end
	if reward.Fragments ~= nil and reward.Fragments > 0 then
		table.insert(parts, `{compactNumber(reward.Fragments)} fragments`)
	end
	if reward.FreeSpins ~= nil and reward.FreeSpins > 0 then
		local spinLabel = if reward.FreeSpins == 1 then "free spin" else "free spins"
		table.insert(parts, `{compactNumber(reward.FreeSpins)} {spinLabel}`)
	end
	if type(reward.Keys) == "table" then
		for crateId, amount in reward.Keys do
			if type(crateId) == "string" and type(amount) == "number" and amount > 0 then
				table.insert(parts, `{compactNumber(amount)} {crateId}`)
			end
		end
	end
	if reward.Boost ~= nil then
		local _boost = reward.Boost
		table.insert(parts, _boost)
	end
	if #parts == 0 then
		return ""
	end
	local text = "+" .. parts[1]
	for index = 1, #parts - 1 do
		text ..= `, +{parts[index + 1]}`
	end
	return text
end
local NUMBER_SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion", "Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign", "Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex", "Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx", "Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx", "Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega", "Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless", "Apex", "Horizon", "Zenith", "Nadir", "Helix", "Quasar", "Pulsar", "Nebula", "Singularity", "Eventide", "Eon", "Aeon", "Continuum", "Lattice", "Axiom", "Paragon", "Astral", "Forgepeak" }
local function suffixForGroup(group)
	if group <= 0 then
		return ""
	end
	local index = math.min(group, #NUMBER_SUFFIXES) - 1
	return NUMBER_SUFFIXES[index + 1]
end
local LAST_NAMED_LOG10 = #NUMBER_SUFFIXES * 3
local function formatFromLog10(log10, sign)
	if sign == nil then
		sign = 1
	end
	if log10 ~= log10 or log10 == -math.huge then
		return "0"
	end
	if log10 < 3 then
		local numeric = sign * 10 ^ math.max(0, log10)
		return string.format("%.0f", numeric)
	end
	if log10 >= LAST_NAMED_LOG10 then
		local exponent = math.floor(log10)
		local mantissa = 10 ^ (log10 - exponent)
		return string.format("%s%.2fe%d", if sign < 0 then "-" else "", mantissa, exponent)
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #NUMBER_SUFFIXES)
	local scaled = sign * 10 ^ (log10 - group * 3)
	if math.abs(scaled) >= 1000 and group < #NUMBER_SUFFIXES then
		group += 1
		scaled /= 1000
	end
	local suffix = suffixForGroup(group)
	local absolute = math.abs(scaled)
	if absolute >= 100 then
		return string.format("%.0f%s", scaled, suffix)
	end
	if absolute >= 10 then
		return string.format("%.1f%s", scaled, suffix)
	end
	return string.format("%.2f%s", scaled, suffix)
end
local function scaleForDisplay(value)
	local absolute = math.abs(value)
	if absolute ~= absolute or absolute == 0 then
		return {
			scaled = 0,
			suffix = "",
		}
	end
	if absolute == math.huge then
		return {
			scaled = 1,
			suffix = "e308+",
		}
	end
	if absolute < 1000 then
		return {
			scaled = value,
			suffix = "",
		}
	end
	local log10 = math.log(absolute) / LN10
	if log10 >= LAST_NAMED_LOG10 then
		return {
			scaled = 10 ^ (log10 - math.floor(log10)),
			suffix = `e{math.floor(log10)}`,
		}
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #NUMBER_SUFFIXES)
	local scaled = value / 1000 ^ group
	if math.abs(scaled) >= 1000 and group < #NUMBER_SUFFIXES then
		group += 1
		scaled /= 1000
	end
	return {
		scaled = scaled,
		suffix = suffixForGroup(group),
	}
end
local log10Flux
local function asFlux(value)
	local _value = value
	if type(_value) == "number" then
		return if value == value then value else 0
	end
	local parsed = tonumber(value)
	if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
		return parsed
	end
	local log = log10Flux(value)
	if log == -math.huge then
		return 0
	end
	if log >= 308 then
		return 1e308
	end
	if log <= -308 then
		return 0
	end
	return 10 ^ log
end
function log10Flux(value)
	local _value = value
	if type(_value) == "number" then
		if value ~= value or value == 0 then
			return -math.huge
		end
		if value < 0 then
			return -math.huge
		end
		if value == math.huge then
			return 1e6
		end
		return math.log(value) / LN10
	end
	local parsed = tonumber(value)
	if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
		return log10Flux(parsed)
	end
	local mantissaText, exponentText = string.match(value, "([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)")
	if mantissaText ~= nil and exponentText ~= nil then
		local _condition = tonumber(mantissaText)
		if _condition == nil then
			_condition = 1
		end
		local mantissa = _condition
		local _condition_1 = tonumber(exponentText)
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local exponent = _condition_1
		if mantissa <= 0 then
			return -math.huge
		end
		return math.log(mantissa) / LN10 + exponent
	end
	if string.lower(value) == "inf" or string.lower(value) == "infinity" then
		return 1e6
	end
	return -math.huge
end
local function fromLog10(log10)
	if log10 ~= log10 or log10 == -math.huge then
		return 0
	end
	if log10 < 308 then
		local numeric = 10 ^ log10
		if numeric == numeric and numeric ~= math.huge then
			return numeric
		end
	end
	local exponent = math.floor(log10)
	local mantissa = 10 ^ (log10 - exponent)
	return string.format("%.12fe%d", mantissa, exponent)
end
local function compareFlux(left, right)
	local a = log10Flux(left)
	local b = log10Flux(right)
	if a < b then
		return -1
	end
	if a > b then
		return 1
	end
	return 0
end
local function gteFlux(left, right)
	return compareFlux(left, right) >= 0
end
local function levelCapLabel(maxLevel)
	if maxLevel >= 1000000000 then
		return "∞"
	end
	return compactNumber(maxLevel)
end
function compactNumber(value)
	local _value = value
	if type(_value) == "string" then
		local parsed = tonumber(value)
		if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
			return compactNumber(parsed)
		end
		return formatFromLog10(log10Flux(value))
	end
	local _value_1 = value
	local _condition = not (type(_value_1) == "number")
	if not _condition then
		_condition = value ~= value
	end
	if _condition then
		return "0"
	end
	if value == 0 then
		return "0"
	end
	if math.abs(value) < 1000 and value ~= math.huge and value ~= -math.huge then
		return string.format("%.0f", value)
	end
	return formatFromLog10(log10Flux(value), if value < 0 then -1 else 1)
end
local function compactSpinParts(value)
	local _value = value
	if type(_value) == "string" then
		local parsed = tonumber(value)
		if parsed ~= nil and parsed == parsed and parsed ~= math.huge then
			return compactSpinParts(parsed)
		end
		return {
			value = 1,
			suffix = compactNumber(value),
			decimals = 0,
		}
	end
	local _value_1 = value
	local _condition = not (type(_value_1) == "number")
	if not _condition then
		_condition = value ~= value
	end
	if _condition then
		return {
			value = 0,
			suffix = "",
			decimals = 0,
		}
	end
	local parts = scaleForDisplay(value)
	if parts.suffix == "" then
		return {
			value = math.floor(value + (if value >= 0 then 0.5 else -0.5)),
			suffix = "",
			decimals = 0,
		}
	end
	local decimals = if math.abs(parts.scaled) >= 100 then 0 elseif math.abs(parts.scaled) >= 10 then 1 else 2
	local factor = 10 ^ decimals
	local rounded = math.floor(parts.scaled * factor + (if parts.scaled >= 0 then 0.5 else -0.5)) / factor
	return {
		value = rounded,
		suffix = parts.suffix,
		decimals = decimals,
	}
end
local function clockText(seconds)
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor(total % 3600 / 60)
	local remaining = total % 60
	return if hours > 0 then string.format("%02d:%02d:%02d", hours, minutes, remaining) else string.format("%02d:%02d", minutes, remaining)
end
local function scaledCost(base, scale, level)
	local safeBase = math.max(1e-12, base)
	local safeScale = math.max(1e-12, scale)
	local exponent = math.log(safeBase) + math.max(0, level) * math.log(safeScale)
	if exponent < math.log(1e308) then
		return math.floor(math.exp(exponent) + 0.5)
	end
	return fromLog10(exponent / LN10)
end
local function addFlux(left, right)
	local a = log10Flux(left)
	local b = log10Flux(right)
	if a == -math.huge then
		return right
	end
	if b == -math.huge then
		return left
	end
	local high = math.max(a, b)
	local low = math.min(a, b)
	if high - low > 15 then
		return fromLog10(high)
	end
	return fromLog10(high + math.log(1 + 10 ^ (low - high)) / LN10)
end
local function geometricSum(base, scale, level, count)
	if count <= 0 then
		return 0
	end
	if count == 1 then
		return scaledCost(base, scale, level)
	end
	local safeBase = math.max(1e-12, base)
	local safeScale = math.max(1e-12, scale)
	if math.abs(safeScale - 1) < 1e-12 then
		local one = scaledCost(safeBase, safeScale, level)
		local logTotal = log10Flux(one) + math.log(count) / LN10
		return fromLog10(logTotal)
	end
	local lnScale = math.log(safeScale)
	local nLnScale = count * lnScale
	local logDiff = if nLnScale < math.log(1e300) then math.log(math.max(1e-12, safeScale ^ count - 1)) else nLnScale
	local logTotal = math.log(safeBase) + math.max(0, level) * lnScale + logDiff - math.log(math.max(1e-12, safeScale - 1))
	if logTotal < math.log(1e308) then
		return math.floor(math.exp(logTotal) + 0.5)
	end
	return fromLog10(logTotal / LN10)
end
local function maxAffordableLevels(base, scale, level, remaining, cash)
	if remaining <= 0 then
		return 0
	end
	if compareFlux(scaledCost(base, scale, level), cash) > 0 then
		return 0
	end
	local low = 1
	local high = remaining
	while low < high do
		local mid = low + math.floor((high - low + 1) / 2)
		if compareFlux(geometricSum(base, scale, level, mid), cash) <= 0 then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end
local function bulkCost(base, scale, level, amount, maxLevel, cash)
	local remaining = math.max(0, maxLevel - level)
	if amount == 0 then
		if cash == nil then
			return scaledCost(base, scale, level)
		end
		local count = maxAffordableLevels(base, scale, level, remaining, cash)
		return if count <= 0 then scaledCost(base, scale, level) else geometricSum(base, scale, level, count)
	end
	return geometricSum(base, scale, level, math.min(amount, remaining))
end
local function amountPayload(amount)
	return if amount == 0 then "Max" else amount
end
return {
	formatReward = formatReward,
	asFlux = asFlux,
	log10Flux = log10Flux,
	compareFlux = compareFlux,
	gteFlux = gteFlux,
	levelCapLabel = levelCapLabel,
	compactNumber = compactNumber,
	compactSpinParts = compactSpinParts,
	clockText = clockText,
	scaledCost = scaledCost,
	bulkCost = bulkCost,
	amountPayload = amountPayload,
}
