local fs = require("@lune/fs")
local luau = require("@lune/luau")

local signals = luau.load(fs.readFile("src/Client/AstralForge/PurchaseSignals.luau"))()
local confirmations = 0
local dispose = signals.subscribe(function(payload)
	assert(payload.ProductId == 42)
	confirmations += 1
end)
signals.confirm({ ProductId = 42 })
assert(confirmations == 0, "incomplete confirmation must not complete checkout")
signals.confirm({ ProductId = 42, Key = "receipt-a" })
signals.confirm({ ProductId = 42, Key = "receipt-a" })
assert(confirmations == 1, "a repeated receipt must not play success twice")
dispose()
signals.confirm({ ProductId = 42, Key = "receipt-b" })
assert(confirmations == 1, "unmounted shop must not receive confirmations")

local effects = luau.load(fs.readFile("src/Client/AstralForge/TitleEffectMath.luau"))()
for time = 0, 10, 0.125 do
	for index = 1, 8 do
		local segment = effects.lightningSegment(index, time, 160, 24, false)
		assert(segment.Length > 0 and segment.Length < 40)
		assert(segment.Y > 0 and segment.Y < 1)
		local nextY = effects.lightningPoint(index, time, false)
		local reconstructedY = segment.Y + math.sin(math.rad(segment.Angle)) * segment.Length / 24
		assert(math.abs(nextY - reconstructedY) < 0.00001, "lightning segments must connect")
		local static = effects.lightningSegment(index, time, 160, 24, true)
		assert(static.Angle == 0 and static.Y == 0.77, "reduced motion must remain stationary")
	end
end
print("[TEST] purchase confirmation dedup/cleanup and connected, bounded, reduced-motion lightning passed")
