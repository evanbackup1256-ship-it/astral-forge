--!strict

export type Persist = number | string

local OmegaMath = {}

local MAX_DOUBLE = 1.7976931348623157e+308
local LOG10_MAX = math.log(MAX_DOUBLE) / math.log(10)
local LN10 = math.log(10)
local HUGE_EXP = 1e18

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

type Decoded = { z: boolean, s: number, e: number }

local function decode(value: any): Decoded
	if type(value) == "number" then
		if value ~= value or value == 0 then
			return { z = true, s = 1, e = 0 }
		end
		if value == math.huge then
			return { z = false, s = 1, e = HUGE_EXP }
		end
		if value == -math.huge then
			return { z = false, s = -1, e = HUGE_EXP }
		end
		return { z = false, s = value < 0 and -1 or 1, e = math.log(math.abs(value)) / LN10 }
	end
	if type(value) == "string" then
		local lowered = string.lower(value)
		if lowered == "inf" or lowered == "+inf" or lowered == "infinity" or lowered == "+infinity" then
			return { z = false, s = 1, e = HUGE_EXP }
		end
		if lowered == "-inf" or lowered == "-infinity" then
			return { z = false, s = -1, e = HUGE_EXP }
		end
		if lowered == "nan" or lowered == "" then
			return { z = true, s = 1, e = 0 }
		end
		local mantText, expText = string.match(value, "^([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)")
		if mantText and expText then
			local mant = tonumber(mantText)
			local exp = tonumber(expText)
			if mant == nil or exp == nil or mant ~= mant then
				return { z = true, s = 1, e = 0 }
			end
			if mant == 0 then
				return { z = true, s = 1, e = 0 }
			end
			return { z = false, s = mant < 0 and -1 or 1, e = math.log(math.abs(mant)) / LN10 + exp }
		end
		local parsed = tonumber(value)
		if isFinite(parsed) then
			return decode(parsed)
		end
		return { z = true, s = 1, e = 0 }
	end
	if type(value) == "table" and type(value.array) == "table" then
		local mag = value.array[1]
		local layer = value.array[2] or 0
		local sign = value.sign or 1
		if type(mag) ~= "number" or mag ~= mag then
			return { z = true, s = 1, e = 0 }
		end
		if mag == 0 and (layer == 0 or layer == nil) then
			return { z = true, s = 1, e = 0 }
		end
		if layer <= 0 then
			return decode((sign < 0 and -1 or 1) * mag)
		end
		if layer == 1 then
			return { z = false, s = sign < 0 and -1 or 1, e = mag }
		end
		return { z = false, s = sign < 0 and -1 or 1, e = HUGE_EXP }
	end
	return { z = true, s = 1, e = 0 }
end

local function encode(decoded: Decoded): Persist
	if decoded.z then
		return 0
	end
	local exponent = decoded.e
	if exponent ~= exponent then
		return 0
	end
	if exponent >= HUGE_EXP or exponent == math.huge then
		return decoded.s < 0 and "-inf" or "inf"
	end
	if exponent >= 15 then
		local exp = math.floor(exponent)
		if exp ~= exp or exp == math.huge then
			return decoded.s < 0 and "-inf" or "inf"
		end
		local frac = exponent - exp
		local mant = 10 ^ frac
		if mant ~= mant or mant == math.huge then
			mant = 1
			exp += 1
		end
		if mant >= 10 then
			mant /= 10
			exp += 1
		end
		local sign = decoded.s < 0 and "-" or ""
		return string.format("%s%.12fe%d", sign, mant, exp)
	end
	if exponent < -320 then
		return 0
	end
	local numeric = decoded.s * (10 ^ exponent)
	if isFinite(numeric) then
		return numeric
	end
	return decoded.s < 0 and "-inf" or "inf"
end

function OmegaMath.New(value: any): Persist
	return encode(decode(value))
end

function OmegaMath.Persist(value: any): Persist
	return encode(decode(value))
end

function OmegaMath.IsOmega(_value: any): boolean
	return false
end

function OmegaMath.Add(left: any, right: any): Persist
	local a = decode(left)
	local b = decode(right)
	if a.z then
		return encode(b)
	end
	if b.z then
		return encode(a)
	end
	if a.s == b.s then
		local hi = math.max(a.e, b.e)
		local lo = math.min(a.e, b.e)
		local e = hi
		if hi - lo <= 18 then
			e = hi + math.log(1 + 10 ^ (lo - hi)) / LN10
		end
		return encode({ z = false, s = a.s, e = e })
	end
	local pos = a.s > 0 and a or b
	local neg = a.s > 0 and b or a
	if math.abs(pos.e - neg.e) < 1e-12 then
		return 0
	end
	if pos.e > neg.e then
		local e = pos.e
		if pos.e - neg.e <= 18 then
			e = pos.e + math.log(1 - 10 ^ (neg.e - pos.e)) / LN10
		end
		return encode({ z = false, s = 1, e = e })
	end
	local e = neg.e
	if neg.e - pos.e <= 18 then
		e = neg.e + math.log(1 - 10 ^ (pos.e - neg.e)) / LN10
	end
	return encode({ z = false, s = -1, e = e })
end

function OmegaMath.Sub(left: any, right: any): Persist
	local b = decode(right)
	if b.z then
		return encode(decode(left))
	end
	return OmegaMath.Add(left, encode({ z = false, s = -b.s, e = b.e }))
end

function OmegaMath.Mul(left: any, right: any): Persist
	local a = decode(left)
	local b = decode(right)
	if a.z or b.z then
		return 0
	end
	return encode({ z = false, s = a.s * b.s, e = a.e + b.e })
end

function OmegaMath.Div(left: any, right: any): Persist
	local a = decode(left)
	local b = decode(right)
	if b.z then
		if a.z then
			return 0
		end
		return encode({ z = false, s = a.s, e = HUGE_EXP })
	end
	if a.z then
		return 0
	end
	return encode({ z = false, s = a.s * b.s, e = a.e - b.e })
end

function OmegaMath.Pow(left: any, right: any): Persist
	local a = decode(left)
	local b = decode(right)
	if b.z then
		return 1
	end
	if a.z then
		return 0
	end
	if a.s < 0 then
		a = { z = false, s = 1, e = a.e }
	end
	if b.e >= LOG10_MAX then
		return encode({ z = false, s = 1, e = HUGE_EXP })
	end
	local exponent = b.s < 0 and -(10 ^ b.e) or (10 ^ b.e)
	if exponent ~= exponent or exponent == math.huge or exponent == -math.huge then
		return encode({ z = false, s = 1, e = HUGE_EXP })
	end
	return encode({ z = false, s = 1, e = a.e * exponent })
end

function OmegaMath.Max(left: any, right: any): Persist
	if OmegaMath.Compare(left, right) >= 0 then
		return OmegaMath.Persist(left)
	end
	return OmegaMath.Persist(right)
end

function OmegaMath.Min(left: any, right: any): Persist
	if OmegaMath.Compare(left, right) <= 0 then
		return OmegaMath.Persist(left)
	end
	return OmegaMath.Persist(right)
end

function OmegaMath.Compare(left: any, right: any): number
	local a = decode(left)
	local b = decode(right)
	if a.z and b.z then
		return 0
	end
	if a.z then
		return b.s > 0 and -1 or 1
	end
	if b.z then
		return a.s > 0 and 1 or -1
	end
	if a.s ~= b.s then
		return a.s > 0 and 1 or -1
	end
	if a.e == b.e then
		return 0
	end
	if a.s > 0 then
		return a.e > b.e and 1 or -1
	end
	return a.e > b.e and -1 or 1
end

function OmegaMath.Lt(left: any, right: any): boolean
	return OmegaMath.Compare(left, right) < 0
end

function OmegaMath.Lte(left: any, right: any): boolean
	return OmegaMath.Compare(left, right) <= 0
end

function OmegaMath.Gt(left: any, right: any): boolean
	return OmegaMath.Compare(left, right) > 0
end

function OmegaMath.Gte(left: any, right: any): boolean
	return OmegaMath.Compare(left, right) >= 0
end

function OmegaMath.ToNumber(value: any): number
	local decoded = decode(value)
	if decoded.z then
		return 0
	end
	if decoded.e >= LOG10_MAX then
		return decoded.s < 0 and -MAX_DOUBLE or MAX_DOUBLE
	end
	local numeric = decoded.s * (10 ^ decoded.e)
	if isFinite(numeric) then
		return numeric
	end
	return decoded.s < 0 and -MAX_DOUBLE or MAX_DOUBLE
end

function OmegaMath.Log10(value: any): number
	local decoded = decode(value)
	if decoded.z or decoded.s <= 0 then
		return 0
	end
	return decoded.e
end

function OmegaMath.Floor(value: any): Persist
	local decoded = decode(value)
	if decoded.z then
		return 0
	end
	if decoded.e >= 15 then
		return encode(decoded)
	end
	local numeric = OmegaMath.ToNumber(value)
	return encode(decode(math.floor(numeric)))
end

function OmegaMath.ScaledCost(baseCost: number, scale: number, level: number): Persist
	local safeBase = math.max(1e-12, baseCost)
	local safeScale = math.max(1e-12, scale)
	local safeLevel = math.max(0, level)
	return OmegaMath.Floor(OmegaMath.Mul(safeBase, OmegaMath.Pow(safeScale, safeLevel)))
end

function OmegaMath.GeometricSum(baseCost: number, scale: number, level: number, count: number): Persist
	local n = math.max(0, math.floor(count))
	if n <= 0 then
		return 0
	end
	if n == 1 then
		return OmegaMath.ScaledCost(baseCost, scale, level)
	end
	local safeBase = math.max(1e-12, baseCost)
	local safeScale = math.max(1e-12, scale)
	local safeLevel = math.max(0, level)
	if math.abs(safeScale - 1) < 1e-12 then
		return OmegaMath.Floor(OmegaMath.Mul(OmegaMath.ScaledCost(safeBase, safeScale, safeLevel), n))
	end

	local first = OmegaMath.ScaledCost(safeBase, safeScale, safeLevel)
	local ratioPow = OmegaMath.Pow(safeScale, n)
	local numerator = OmegaMath.Sub(ratioPow, 1)
	if OmegaMath.Lte(numerator, 0) then
		return first
	end
	return OmegaMath.Floor(OmegaMath.Div(OmegaMath.Mul(first, numerator), safeScale - 1))
end

function OmegaMath.AffordableCount(baseCost: number, scale: number, level: number, cash: any, maximum: number): (number, Persist)
	local remaining = math.max(0, math.floor(maximum))
	if remaining <= 0 then
		return 0, 0
	end
	local first = OmegaMath.ScaledCost(baseCost, scale, level)
	if OmegaMath.Gt(first, cash) then
		return 0, 0
	end
	local low = 1
	local high = remaining
	while low < high do
		local mid = low + math.floor((high - low + 1) / 2)
		if OmegaMath.Lte(OmegaMath.GeometricSum(baseCost, scale, level, mid), cash) then
			low = mid
		else
			high = mid - 1
		end
	end
	return low, OmegaMath.GeometricSum(baseCost, scale, level, low)
end

function OmegaMath.BoundedPower(base: number, exponent: number): Persist
	return OmegaMath.Pow(math.max(1, base), math.max(0, exponent))
end

function OmegaMath.ToString(value: any): string
	local persist = encode(decode(value))
	if type(persist) == "number" then
		return tostring(persist)
	end
	return persist
end

return OmegaMath
