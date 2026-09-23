-- Compiled with roblox-ts v3.0.0
local BASE = 10_000_000
local BASE_DIGITS = 7
local function trim(limbs)
	while #limbs > 0 and limbs[#limbs] == 0 do
		limbs[#limbs] = nil
	end
	return limbs
end
local function compareAbs(left, right)
	if #left ~= #right then
		return if #left > #right then 1 else -1
	end
	for index = #left - 1, 0, -1 do
		if left[index + 1] ~= right[index + 1] then
			return if left[index + 1] > right[index + 1] then 1 else -1
		end
	end
	return 0
end
local function addAbs(left, right)
	local length = math.max(#left, #right)
	local output = table.create(length + 1)
	local carry = 0
	do
		local index = 0
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < length) then
				break
			end
			local _condition = left[index + 1]
			if _condition == nil then
				_condition = 0
			end
			local _condition_1 = right[index + 1]
			if _condition_1 == nil then
				_condition_1 = 0
			end
			local value = _condition + _condition_1 + carry
			output[index + 1] = value % BASE
			carry = math.floor(value / BASE)
		end
	end
	if carry > 0 then
		output[length + 1] = carry
	end
	return trim(output)
end
local function subtractAbs(left, right)
	local output = table.create(#left)
	local borrow = 0
	for index = 0, #left - 1 do
		local _exp = left[index + 1]
		local _condition = right[index + 1]
		if _condition == nil then
			_condition = 0
		end
		local value = _exp - _condition - borrow
		if value < 0 then
			value += BASE
			borrow = 1
		else
			borrow = 0
		end
		output[index + 1] = value
	end
	return trim(output)
end
local function multiplyAbs(left, right)
	if #left == 0 or #right == 0 then
		return {}
	end
	local output = table.create(#left + #right)
	for index = 0, #output - 1 do
		output[index + 1] = 0
	end
	for leftIndex = 0, #left - 1 do
		local carry = 0
		for rightIndex = 0, #right - 1 do
			local outputIndex = leftIndex + rightIndex
			local value = output[outputIndex + 1] + left[leftIndex + 1] * right[rightIndex + 1] + carry
			output[outputIndex + 1] = value % BASE
			carry = math.floor(value / BASE)
		end
		local cursor = leftIndex + #right
		while carry > 0 do
			local _condition = output[cursor + 1]
			if _condition == nil then
				_condition = 0
			end
			local value = _condition + carry
			output[cursor + 1] = value % BASE
			carry = math.floor(value / BASE)
			cursor += 1
		end
	end
	return trim(output)
end
--* Immutable arbitrary-precision integer backed by base-1e7 limbs. 
local HelloMpz
do
	HelloMpz = setmetatable({}, {
		__tostring = function()
			return "HelloMpz"
		end,
	})
	HelloMpz.__index = HelloMpz
	function HelloMpz.new(...)
		local self = setmetatable({}, HelloMpz)
		return self:constructor(...) or self
	end
	function HelloMpz:constructor(sign, limbs)
		self.sign = sign
		self.limbs = limbs
	end
	function HelloMpz:create(sign, raw)
		local limbs = trim(raw)
		if #limbs == 0 then
			return HelloMpz.ZERO
		end
		return HelloMpz.new((if sign < 0 then -1 else 1), table.freeze(limbs))
	end
	function HelloMpz:parse(raw)
		local text = (string.gsub(raw, "%s+", ""))
		local sign = 1
		if string.sub(text, 1, 1) == "-" then
			sign = -1
			text = string.sub(text, 2)
		elseif string.sub(text, 1, 1) == "+" then
			text = string.sub(text, 2)
		end
		if #text == 0 or (string.find(text, "^%d+$")) == nil then
			return HelloMpz.ZERO
		end
		local limbs = {}
		do
			local finish = #text
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					finish -= BASE_DIGITS
				else
					_shouldIncrement = true
				end
				if not (finish > 0) then
					break
				end
				local start = math.max(1, finish - BASE_DIGITS + 1)
				local _text = text
				local _finish = finish
				local _condition = tonumber(string.sub(_text, start, _finish))
				if _condition == nil then
					_condition = 0
				end
				table.insert(limbs, _condition)
			end
		end
		return HelloMpz:create(sign, limbs)
	end
	function HelloMpz:fromSafeInteger(value)
		if value ~= value or value == 0 then
			return HelloMpz.ZERO
		end
		return HelloMpz:parse(string.format("%.0f", math.floor(math.abs(value)))):withSign(if value < 0 then -1 else 1)
	end
	function HelloMpz:withSign(sign)
		return if self.sign == 0 then self else HelloMpz.new((if sign < 0 then -1 else 1), self.limbs)
	end
	function HelloMpz:compare(other)
		if self.sign ~= other.sign then
			return if self.sign > other.sign then 1 else -1
		end
		return if self.sign == 0 then 0 else compareAbs(self.limbs, other.limbs) * self.sign
	end
	function HelloMpz:add(other)
		if self.sign == 0 then
			return other
		end
		if other.sign == 0 then
			return self
		end
		if self.sign == other.sign then
			return HelloMpz:create(self.sign, addAbs(self.limbs, other.limbs))
		end
		local comparison = compareAbs(self.limbs, other.limbs)
		if comparison == 0 then
			return HelloMpz.ZERO
		end
		return if comparison > 0 then HelloMpz:create(self.sign, subtractAbs(self.limbs, other.limbs)) else HelloMpz:create(other.sign, subtractAbs(other.limbs, self.limbs))
	end
	function HelloMpz:subtract(other)
		return self:add(other:withSign(-other.sign))
	end
	function HelloMpz:multiply(other)
		if self.sign == 0 or other.sign == 0 then
			return HelloMpz.ZERO
		end
		return HelloMpz:create(self.sign * other.sign, multiplyAbs(self.limbs, other.limbs))
	end
	function HelloMpz:multiplyPowerOfTen(power)
		local amount = math.max(0, math.floor(power))
		if amount == 0 or self.sign == 0 then
			return self
		end
		return self:multiply(HelloMpz:parse(`1{string.rep("0", amount)}`))
	end
	function HelloMpz:toString()
		if self.sign == 0 then
			return "0"
		end
		local output = tostring(self.limbs[#self.limbs])
		for index = #self.limbs - 2, 0, -1 do
			output ..= string.format(`%0{BASE_DIGITS}d`, self.limbs[index + 1])
		end
		return if self.sign < 0 then `-{output}` else output
	end
	function HelloMpz:__tostring()
		return self:toString()
	end
	HelloMpz.ZERO = HelloMpz.new(0, {})
	HelloMpz.ONE = HelloMpz.new(1, { 1 })
end
--* Exact rational container that never converts either operand through f64. 
local HelloMpq
do
	HelloMpq = setmetatable({}, {
		__tostring = function()
			return "HelloMpq"
		end,
	})
	HelloMpq.__index = HelloMpq
	function HelloMpq.new(...)
		local self = setmetatable({}, HelloMpq)
		return self:constructor(...) or self
	end
	function HelloMpq:constructor(numerator, denominator)
		if denominator == nil then
			denominator = HelloMpz.ONE
		end
		local _arg0 = denominator.sign ~= 0
		assert(_arg0, "HelloMpq denominator cannot be zero")
		self.numerator = if denominator.sign < 0 then numerator:withSign(-numerator.sign) else numerator
		self.denominator = denominator:withSign(1)
	end
	function HelloMpq:add(other)
		return HelloMpq.new(self.numerator:multiply(other.denominator):add(other.numerator:multiply(self.denominator)), self.denominator:multiply(other.denominator))
	end
	function HelloMpq:multiply(other)
		return HelloMpq.new(self.numerator:multiply(other.numerator), self.denominator:multiply(other.denominator))
	end
	function HelloMpq:toString()
		return if self.denominator:compare(HelloMpz.ONE) == 0 then self.numerator:toString() else `{self.numerator:toString()}/{self.denominator:toString()}`
	end
	function HelloMpq:__tostring()
		return self:toString()
	end
end
--* Exact fixed-point decimal represented as an integer coefficient and scale. 
local HelloMpf
do
	HelloMpf = setmetatable({}, {
		__tostring = function()
			return "HelloMpf"
		end,
	})
	HelloMpf.__index = HelloMpf
	function HelloMpf.new(...)
		local self = setmetatable({}, HelloMpf)
		return self:constructor(...) or self
	end
	function HelloMpf:constructor(coefficient, scale)
		self.coefficient = coefficient
		self.scale = scale
	end
	function HelloMpf:parse(raw)
		local _binding = string.split(raw, ".")
		local whole = _binding[1]
		if whole == nil then
			whole = "0"
		end
		local fraction = _binding[2]
		if fraction == nil then
			fraction = ""
		end
		return HelloMpf.new(HelloMpz:parse(`{whole}{fraction}`), #fraction)
	end
	function HelloMpf:add(other)
		local scale = math.max(self.scale, other.scale)
		return HelloMpf.new(self.coefficient:multiplyPowerOfTen(scale - self.scale):add(other.coefficient:multiplyPowerOfTen(scale - other.scale)), scale)
	end
	function HelloMpf:multiply(other)
		return HelloMpf.new(self.coefficient:multiply(other.coefficient), self.scale + other.scale)
	end
	function HelloMpf:toString()
		if self.scale <= 0 then
			return self.coefficient:toString()
		end
		local negative = self.coefficient.sign < 0
		local digits = self.coefficient:toString()
		if negative then
			digits = string.sub(digits, 2)
		end
		if #digits <= self.scale then
			local _arg0 = self.scale - #digits + 1
			digits = `{string.rep("0", _arg0)}{digits}`
		end
		local split = #digits - self.scale
		local _exp = string.sub(digits, 1, split)
		local _digits = digits
		local _arg0 = split + 1
		local output = `{_exp}.{string.sub(_digits, _arg0)}`
		return if negative then `-{output}` else output
	end
	function HelloMpf:__tostring()
		return self:toString()
	end
end
local HelloGMPPrecisionCore = table.freeze({
	mpz = HelloMpz,
	mpq = HelloMpq,
	mpf = HelloMpf,
})
return {
	HelloMpz = HelloMpz,
	HelloMpq = HelloMpq,
	HelloMpf = HelloMpf,
	HelloGMPPrecisionCore = HelloGMPPrecisionCore,
}
