-- Compiled with roblox-ts v3.0.0
--[[
	*
	 * Immutable scientific-notation number used for economy values beyond the
	 * native Luau double range. The mantissa is always in [1, 10) for non-zero
	 * values and the exponent is stored separately, so no intermediate 10^n is
	 * evaluated during add or multiply.
	 
]]
local finite
local AlyaNum
do
	AlyaNum = setmetatable({}, {
		__tostring = function()
			return "AlyaNum"
		end,
	})
	AlyaNum.__index = AlyaNum
	function AlyaNum.new(...)
		local self = setmetatable({}, AlyaNum)
		return self:constructor(...) or self
	end
	function AlyaNum:constructor(sign, mantissa, exponent)
		if not finite(mantissa) or mantissa == 0 or sign == 0 then
			self.sign = 0
			self.mantissa = 0
			self.exponent = 0
			return nil
		end
		local absolute = math.abs(mantissa)
		local shift = math.floor(math.log10(absolute))
		self.sign = (if sign < 0 then -1 else 1)
		self.mantissa = absolute / math.pow(10, shift)
		self.exponent = math.floor(exponent + shift)
	end
	function AlyaNum:fromNumber(value)
		if not finite(value) or value == 0 then
			return AlyaNum.ZERO
		end
		return AlyaNum.new(if value < 0 then -1 else 1, math.abs(value), 0)
	end
	function AlyaNum:fromScientific(sign, mantissa, exponent)
		return AlyaNum.new(sign, mantissa, exponent)
	end
	function AlyaNum:addValues(left, right)
		if left.sign == 0 then
			return right
		end
		if right.sign == 0 then
			return left
		end
		local dominant = if left.exponent >= right.exponent then left else right
		local other = if dominant == left then right else left
		local gap = dominant.exponent - other.exponent
		if gap > 18 then
			return dominant
		end
		local aligned = dominant.mantissa + (if dominant.sign == other.sign then 1 else -1) * other.mantissa * math.pow(10, -gap)
		if aligned == 0 then
			return AlyaNum.ZERO
		end
		return AlyaNum.new(if aligned < 0 then -dominant.sign else dominant.sign, math.abs(aligned), dominant.exponent)
	end
	function AlyaNum:multiplyValues(left, right)
		if left.sign == 0 or right.sign == 0 then
			return AlyaNum.ZERO
		end
		return AlyaNum.new(left.sign * right.sign, left.mantissa * right.mantissa, left.exponent + right.exponent)
	end
	function AlyaNum:compare(left, right)
		if left.sign ~= right.sign then
			return if left.sign > right.sign then 1 else -1
		end
		if left.sign == 0 then
			return 0
		end
		local direction = left.sign
		if left.exponent ~= right.exponent then
			return (if left.exponent > right.exponent then 1 else -1) * direction
		end
		return (if left.mantissa > right.mantissa then 1 elseif left.mantissa < right.mantissa then -1 else 0) * direction
	end
	function AlyaNum:asNumber(value)
		if value.sign == 0 then
			return 0
		end
		if value.exponent > 308 then
			return value.sign * math.huge
		end
		if value.exponent < -324 then
			return 0
		end
		return value.sign * value.mantissa * math.pow(10, value.exponent)
	end
	function AlyaNum:format(value, decimals)
		if decimals == nil then
			decimals = 2
		end
		if value.sign == 0 then
			return "0"
		end
		if value.exponent < 3 and value.exponent > -4 then
			return string.format(`%.{decimals}f`, AlyaNum:asNumber(value))
		end
		return `{string.format(`%.{decimals}f`, value.sign * value.mantissa)}e{value.exponent}`
	end
	function AlyaNum:add(other)
		return AlyaNum:addValues(self, other)
	end
	function AlyaNum:multiply(other)
		return AlyaNum:multiplyValues(self, other)
	end
	function AlyaNum:toNumber()
		return AlyaNum:asNumber(self)
	end
	function AlyaNum:toString()
		return AlyaNum:format(self)
	end
	function AlyaNum:__tostring()
		return self:toString()
	end
	AlyaNum.ZERO = AlyaNum.new(0, 0, 0)
end
function finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end
local function alya(value)
	return if TS.instanceof(value, AlyaNum) then value else AlyaNum:fromNumber(value)
end
local function addBig(left, right)
	return AlyaNum:addValues(alya(left), alya(right))
end
local function multiplyBig(left, right)
	return AlyaNum:multiplyValues(alya(left), alya(right))
end
--[[
	*
	 * Layered base-10 magnitude for values whose exponent also exceeds f64.
	 * layer 0 = magnitude, layer 1 = 10^magnitude, layer 2 = 10^(10^magnitude).
	 
]]
local SerikaNum
do
	SerikaNum = setmetatable({}, {
		__tostring = function()
			return "SerikaNum"
		end,
	})
	SerikaNum.__index = SerikaNum
	function SerikaNum.new(...)
		local self = setmetatable({}, SerikaNum)
		return self:constructor(...) or self
	end
	function SerikaNum:constructor(sign, layer, magnitude)
		if sign == 0 or magnitude ~= magnitude or magnitude == 0 then
			self.sign = 0
			self.layer = 0
			self.magnitude = 0
			return nil
		end
		local normalizedLayer = math.max(0, math.floor(layer))
		local normalizedMagnitude = math.abs(magnitude)
		local normalizedSign = (if sign < 0 then -1 else 1)
		if normalizedLayer == 0 and normalizedMagnitude == math.huge then
			normalizedLayer = 1
			normalizedMagnitude = 309
		end
		while normalizedLayer > 0 and normalizedMagnitude < 15 do
			normalizedMagnitude = math.pow(10, normalizedMagnitude)
			normalizedLayer -= 1
			if normalizedMagnitude == math.huge then
				break
			end
		end
		if normalizedLayer == 0 and normalizedMagnitude < 0 then
			normalizedSign = (-normalizedSign)
			normalizedMagnitude = -normalizedMagnitude
		end
		self.sign = normalizedSign
		self.layer = normalizedLayer
		self.magnitude = normalizedMagnitude
	end
	function SerikaNum:fromNumber(value)
		if value ~= value or value == 0 then
			return SerikaNum.ZERO
		end
		if value == math.huge or value == -math.huge then
			return SerikaNum.new(if value < 0 then -1 else 1, 1, 309)
		end
		return SerikaNum.new(if value < 0 then -1 else 1, 0, math.abs(value))
	end
	function SerikaNum:fromAlya(value)
		if value.sign == 0 then
			return SerikaNum.ZERO
		end
		if value.exponent <= 308 then
			return SerikaNum:fromNumber(value:toNumber())
		end
		return SerikaNum.new(value.sign, 1, value.exponent + math.log10(value.mantissa))
	end
	function SerikaNum:tetrated(exponentLog10, sign)
		if sign == nil then
			sign = 1
		end
		return SerikaNum.new(sign, 2, exponentLog10)
	end
	function SerikaNum:compareAbs(left, right)
		if left.layer ~= right.layer then
			return if left.layer > right.layer then 1 else -1
		end
		return if left.magnitude > right.magnitude then 1 elseif left.magnitude < right.magnitude then -1 else 0
	end
	function SerikaNum:compare(left, right)
		if left.sign ~= right.sign then
			return if left.sign > right.sign then 1 else -1
		end
		if left.sign == 0 then
			return 0
		end
		return SerikaNum:compareAbs(left, right) * left.sign
	end
	function SerikaNum:addAbs(left, right)
		if left.layer == 0 and right.layer == 0 then
			return SerikaNum:fromNumber(left.magnitude + right.magnitude)
		end
		local dominant = if SerikaNum:compareAbs(left, right) >= 0 then left else right
		local other = if dominant == left then right else left
		if dominant.layer ~= other.layer or dominant.layer > 1 then
			return dominant
		end
		local gap = dominant.magnitude - other.magnitude
		if gap > 16 then
			return dominant
		end
		return SerikaNum.new(1, 1, dominant.magnitude + math.log10(1 + math.pow(10, -gap)))
	end
	function SerikaNum:subtractAbs(left, right)
		local comparison = SerikaNum:compareAbs(left, right)
		if comparison == 0 then
			return SerikaNum.ZERO
		end
		local dominant = if comparison > 0 then left else right
		local other = if comparison > 0 then right else left
		local sign = if comparison > 0 then 1 else -1
		if dominant.layer ~= other.layer or dominant.layer > 1 then
			return SerikaNum.new(sign, dominant.layer, dominant.magnitude)
		end
		if dominant.layer == 0 then
			return SerikaNum:fromNumber(sign * (dominant.magnitude - other.magnitude))
		end
		local gap = dominant.magnitude - other.magnitude
		if gap > 16 then
			return SerikaNum.new(sign, dominant.layer, dominant.magnitude)
		end
		return SerikaNum.new(sign, 1, dominant.magnitude + math.log10(1 - math.pow(10, -gap)))
	end
	function SerikaNum:addValues(left, right)
		if left.sign == 0 then
			return right
		end
		if right.sign == 0 then
			return left
		end
		if left.sign == right.sign then
			local sum = SerikaNum:addAbs(left, right)
			return SerikaNum.new(left.sign, sum.layer, sum.magnitude)
		end
		local difference = SerikaNum:subtractAbs(left, right)
		return SerikaNum.new(left.sign * difference.sign, difference.layer, difference.magnitude)
	end
	function SerikaNum:multiplyValues(left, right)
		if left.sign == 0 or right.sign == 0 then
			return SerikaNum.ZERO
		end
		local sign = left.sign * right.sign
		if left.layer == 0 and right.layer == 0 then
			return SerikaNum:fromNumber(sign * left.magnitude * right.magnitude)
		end
		if left.layer <= 1 and right.layer <= 1 then
			local leftLog = if left.layer == 0 then math.log10(left.magnitude) else left.magnitude
			local rightLog = if right.layer == 0 then math.log10(right.magnitude) else right.magnitude
			return SerikaNum.new(sign, 1, leftLog + rightLog)
		end
		local dominant = if SerikaNum:compareAbs(left, right) >= 0 then left else right
		return SerikaNum.new(sign, dominant.layer, dominant.magnitude)
	end
	function SerikaNum:add(other)
		return SerikaNum:addValues(self, other)
	end
	function SerikaNum:multiply(other)
		return SerikaNum:multiplyValues(self, other)
	end
	function SerikaNum:toNumber()
		if self.sign == 0 then
			return 0
		end
		if self.layer == 0 then
			return self.sign * self.magnitude
		end
		if self.layer == 1 and self.magnitude <= 308 then
			return self.sign * math.pow(10, self.magnitude)
		end
		return self.sign * math.huge
	end
	function SerikaNum:toString(decimals)
		if decimals == nil then
			decimals = 2
		end
		if self.sign == 0 then
			return "0"
		end
		if self.layer == 0 then
			return string.format(`%.{decimals}g`, self.sign * self.magnitude)
		end
		if self.layer == 1 and self.magnitude < 1_000_000 then
			local exponent = math.floor(self.magnitude)
			local mantissa = math.pow(10, self.magnitude - exponent) * self.sign
			return `{string.format(`%.{decimals}f`, mantissa)}e{exponent}`
		end
		local _exp = if self.sign < 0 then "-" else ""
		local _arg0 = math.min(self.layer, 8)
		return `{_exp}{string.rep("e", _arg0)}{string.format("%.3f", self.magnitude)}`
	end
	function SerikaNum:__tostring()
		return self:toString()
	end
	SerikaNum.ZERO = SerikaNum.new(0, 0, 0)
	SerikaNum.ONE = SerikaNum.new(1, 0, 1)
end
local AlyaNumEngine = table.freeze({
	zero = AlyaNum.ZERO,
	from = alya,
	add = addBig,
	multiply = multiplyBig,
	compare = function(left, right)
		return AlyaNum:compare(left, right)
	end,
	format = function(value, decimals)
		return AlyaNum:format(value, decimals)
	end,
})
local SerikaNumEngine = table.freeze({
	zero = SerikaNum.ZERO,
	one = SerikaNum.ONE,
	from = function(value)
		return SerikaNum:fromNumber(value)
	end,
	fromAlya = function(value)
		return SerikaNum:fromAlya(value)
	end,
	tetrated = function(exponentLog10, sign)
		return SerikaNum:tetrated(exponentLog10, sign)
	end,
	add = function(left, right)
		return SerikaNum:addValues(left, right)
	end,
	multiply = function(left, right)
		return SerikaNum:multiplyValues(left, right)
	end,
	compare = function(left, right)
		return SerikaNum:compare(left, right)
	end,
})
return {
	alya = alya,
	addBig = addBig,
	multiplyBig = multiplyBig,
	AlyaNum = AlyaNum,
	SerikaNum = SerikaNum,
	AlyaNumEngine = AlyaNumEngine,
	SerikaNumEngine = SerikaNumEngine,
}
