-- Star Foundry rules: flow, fusion, costs, ignite timing and the migration from Continuum/Reactor.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local F = luau.load(fs.readFile("src/Shared/AstralForge/Shared/FoundryMath.luau"))()

local function board(radius, list)
	local pieces = {}
	for _, entry in list do
		pieces[F.key(entry[1], entry[2])] = { Kind = entry[3], Tier = entry[4] or 1, Facing = entry[5] or 0 }
	end
	return { Radius = radius, Pieces = pieces }
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6) * math.max(1, math.abs(b))
end

-- geometry
assert(F.cellCount(2) == 19 and F.cellCount(5) == 91, "hex cell counts")
assert(#F.cells(3) == F.cellCount(3), "cells() lists every cell")
assert(F.onBoard(2, 2, -2) and not F.onBoard(2, 2, 1), "board bounds")

-- an ember straight into a forge anvil delivers its whole output
local direct = F.flow(board(2, { { 0, 0, "Ember", 1, 0 }, { 1, 0, "ForgeAnvil", 1, 0 } }))
assert(near(direct.Production, 10), "ember -> anvil = 10, got " .. direct.Production)
assert(direct.Wasted == 0, "nothing wasted on a direct line")

-- a conduit loses a little, a lens focuses, a prism splits three ways
local relay = F.flow(board(2, { { -1, 0, "Ember", 1, 0 }, { 0, 0, "Conduit", 1, 0 }, { 1, 0, "ForgeAnvil", 1, 0 } }))
assert(near(relay.Production, 9.2), "conduit keeps 92%")
local lens = F.flow(board(2, { { -1, 0, "Ember", 1, 0 }, { 0, 0, "Lens", 1, 0 }, { 1, 0, "StrikeAnvil", 1, 0 } }))
assert(near(lens.Tap, 18), "lens focuses x1.8 into tap")
local prism = F.flow(board(2, { { -1, 0, "Ember", 1, 0 }, { 0, 0, "Prism", 1, 0 }, { 1, 0, "ForgeAnvil" }, { -1, 1, "VaultAnvil" }, { 0, -1, "EchoAnvil" } }))
assert(near(prism.Production, 6) and near(prism.Capacity, 6) and near(prism.Offline, 6), "prism sends 0.6 down each of three faces")

-- energy aimed off the board or at an empty cell is wasted; embers do not relay
local lost = F.flow(board(2, { { 2, 0, "Ember", 1, 0 } }))
assert(lost.Delivered == 0 and near(lost.Wasted, 10), "off the board is wasted")
local blocked = F.flow(board(2, { { -1, 0, "Ember", 1, 0 }, { 0, 0, "Ember", 1, 3 }, { 1, 0, "ForgeAnvil" } }))
assert(blocked.Production == 0, "an ember does not pass energy on")

-- loops cannot amplify forever: a ring of lenses terminates and stays bounded
local ring = {}
for i = 0, 5 do
	local d = F.DIRECTIONS[i + 1]
	table.insert(ring, { d[1], d[2], "Lens", 3, (i + 2) % 6 })
end
table.insert(ring, { 0, 0, "Ember", 5, 0 })
local looped = F.flow(board(2, ring))
assert(looped.Delivered == 0 and looped.Wasted < math.huge, "a closed loop terminates")

-- a board packed with prisms stays inside the step budget and is deterministic
local packed = {}
for _, key in F.cells(5) do
	local q, r = F.parse(key)
	table.insert(packed, { q, r, if (q + r) % 4 == 0 then "Ember" else "Prism", 2, (q * 7 + r * 3) % 6 })
end
local a, b = F.flow(board(5, packed)), F.flow(board(5, packed))
assert(a.Delivered == b.Delivered and a.Wasted == b.Wasted, "flow is deterministic")

-- tiers: each tier is TIER_GROWTH stronger; fusion needs an exact match
assert(near(F.emberOutput(3), 10 * 2.2 * 2.2), "tier growth")
assert(F.canFuse({ Kind = "Lens", Tier = 2, Facing = 0 }, { Kind = "Lens", Tier = 2, Facing = 3 }), "same kind and tier fuse")
assert(not F.canFuse({ Kind = "Lens", Tier = 2, Facing = 0 }, { Kind = "Lens", Tier = 3, Facing = 0 }), "different tiers do not")
assert(not F.canFuse({ Kind = "Lens", Tier = 2, Facing = 0 }, { Kind = "Prism", Tier = 2, Facing = 0 }), "different kinds do not")

-- validation rejects junk
assert(not F.validPiece({ Kind = "Nope", Tier = 1, Facing = 0 }) and not F.validPiece({ Kind = "Ember", Tier = 0, Facing = 0 })
	and not F.validPiece({ Kind = "Ember", Tier = 1, Facing = 6 }) and not F.validPiece({ Kind = "Ember", Tier = 1.5, Facing = 0 }), "invalid pieces")

-- effects, costs
local fx = F.effects(direct)
assert(near(fx.Production, 2) and fx.Tap == 1, "10 energy = x2 production")
assert(F.effects({ Production = 0, Tap = 0, Capacity = 0, Offline = 1e9, Delivered = 0, Wasted = 0, Links = {}, Lit = {} }).Offline == 0.45, "offline capped")
for draws = 0, 60 do
	assert(F.drawCost(draws + 1) >= F.drawCost(draws), "draw cost never falls")
end
assert(F.expandCost(F.MAX_RADIUS) == nil and F.expandCost(2) > 0, "expansion stops at the max radius")

-- draws are always valid pieces
for i = 0, 200 do
	local piece = F.draw((i * 0.6180339) % 1, (i * 0.3819660) % 1, 9)
	assert(F.validPiece(piece), "draw makes a valid piece")
end

-- ignite timing
assert(F.onBeat(0.02, 0.98) and not F.onBeat(0.3, 0.6), "beat window wraps round the turn")
assert(near(F.wavePhase(0, F.IGNITE_PERIOD * 2.25), 0.25), "wave phase")

-- migration keeps old Continuum power: the starter board delivers at least the old production
for _, rank in { 0, 1, 10, 25, 60 } do
	local migrated, bench, shards = F.migrate(rank, 50, 3)
	local flow = F.flow(migrated)
	local old = 1.16 ^ rank * 1.5 ^ math.floor(rank / 25)
	assert(F.effects(flow).Production >= old - 1e-6, string.format("rank %d keeps its production (%.2f < %.2f)", rank, F.effects(flow).Production, old))
	assert(#bench > 0 and shards >= 50 * 4, "migration also grants bench pieces and shards")
end

print("[INFO] [TEST] star foundry math passed | flow, loops, budget, fusion, costs, ignite, migration")
