--!strict
-- Ordinary numbers must stay exact through OmegaMath. They used to round-trip through
-- log10, so 36 came back as 35.99999999999998 and Floor(36) as 34.999999999999986.

local O = require("../out/Shared/AstralForge/Shared/OmegaMath")

assert(O.Persist(36) == 36, "Persist keeps plain integers exact")
assert(O.Persist(78125) == 78125, "Persist keeps 78125 exact")
assert(O.Floor(36) == 36, "Floor of an integer is itself")
assert(O.Floor(36.9) == 36, "Floor rounds down")
assert(O.Floor(-0.5) == -1, "Floor rounds toward negative infinity")
assert(O.Max(36, 0) == 36, "Max returns the larger operand unchanged")
assert(O.Min(36, 50) == 36, "Min returns the smaller operand unchanged")
assert(O.Sub(100, 64) == 36, "Sub is exact for plain numbers")
assert(O.Add(0.25, 0.5) == 0.75, "Add is exact for plain numbers")
assert(O.Mul(6, 6) == 36, "Mul is exact for plain numbers")
assert(O.Div(72, 2) == 36, "Div is exact for plain numbers")
assert(O.ToNumber(36) == 36, "ToNumber passes plain numbers through")
assert(O.Gte(O.Sub(100, 64), 36), "a balance of exactly the price can afford it")
assert(O.Sub(0.3, 0.1 + 0.2) == 0, "cancellation noise collapses to zero")
assert(O.Sub(5, 5) == 0, "equal values cancel to zero")
assert(O.Sub(1e14, 1e14 - 1) == 1, "near-equal large values keep their difference")
assert(O.Compare(1, 2) == -1 and O.Compare(2, 1) == 1 and O.Compare(3, 3) == 0, "plain compare")

-- Values at or past 1e15 still use the big-number representation.
local big = O.Mul(1e10, 1e10)
assert(type(big) == "string", "1e20 is stored as a string")
assert(O.Compare(big, 1e15) == 1, "big values compare above plain ones")
assert(O.Compare(O.Add(1e14, 1e14), 1e14) == 1, "sums below the limit stay plain")
assert(type(O.Add(9e14, 9e14)) == "string", "sums past the limit switch to the big representation")

-- Deterministic sweep: integer arithmetic on plain numbers is exact and Floor is idempotent.
for a = -40, 40 do
	for b = -40, 40 do
		assert(O.Add(a, b) == a + b, "Add exact")
		assert(O.Sub(a, b) == a - b, "Sub exact")
		assert(O.Mul(a, b) == a * b, "Mul exact")
		assert(O.Floor(O.Floor(a)) == a, "Floor idempotent")
		assert(O.Max(a, b) == math.max(a, b), "Max exact")
	end
end

print("verify_omega_precision: ok")
