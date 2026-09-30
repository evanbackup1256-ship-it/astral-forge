--!strict
-- compactNumber must never print "1000<suffix>": exact powers of 1000 used to land one tier low
-- (math.log(x) / LN10 is a hair under the true exponent), and values that round up to a full
-- thousand never rolled over to the next suffix.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local source = fs.readFile("src/Client/AstralForge/CoreKit.luau#format")
local chunk = luau.load(source, { chunkName = "format" })
local format = chunk() :: any
local compact = format.compactNumber :: (any) -> string

local function expect(value: any, expected: string)
	local actual = compact(value)
	assert(actual == expected, `compactNumber({tostring(value)}) = {actual}, expected {expected}`)
end

expect(0, "0")
expect(7, "7")
expect(36, "36")
expect(999, "999")
expect(999.4, "999")
expect(999.6, "1.00K")
expect(1000, "1.00K")
expect(1500, "1.50K")
expect(9996, "10.0K")
expect(99999, "100K")
expect(100000, "100K")
expect(999999, "1.00M")
expect(1e6, "1.00M")
expect(1.5e6, "1.50M")
expect(1e9, "1.00B")
expect(1e12, "1.00T")
expect(1e15, "1.00Qa")
expect(-1e6, "-1.00M")

-- Sweep every tier boundary: nothing may print a bare thousand before a suffix.
for exponent = 0, 90 do
	for _, mantissa in { 1, 9.99, 99.9, 999, 999.999 } do
		local text = compact(mantissa * 10 ^ exponent)
		assert(not string.find(text, "^%-?1000"), `compactNumber({mantissa}e{exponent}) = {text}`)
	end
end

print("verify_compact_number: ok")
