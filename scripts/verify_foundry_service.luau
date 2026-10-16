-- Star Foundry server moves: migration, every Op, junk payloads, Ignite timing and the economy view.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local F = luau.load(fs.readFile("src/Shared/AstralForge/Shared/FoundryMath.luau"))()
local folder = {}
folder.WaitForChild = function(_, name) if name == "FoundryMath" then return name end return folder end
local S = luau.load(fs.readFile("src/Server/AstralForge/Modules/FoundryService.luau"), {
	environment = setmetatable({
		game = { GetService = function() return folder end },
		require = function(name) assert(name == "FoundryMath"); return F end,
	}, { __index = _G }),
})()

local seed = 3
local random = { NextNumber = function() seed = (seed * 16807) % 2147483647; return seed / 2147483647 end }
local now = 1000

-- migration: a Continuum rank 20 player keeps at least their old production
local veteran = { Continuum = { Rank = 20 }, Anomaly = { Fragments = 30, Stabilizations = 4 } }
S.Ensure(veteran, now)
local production = S.Effects(veteran, now)
assert(production >= 1.16 ^ 20 - 1e-6, "veteran keeps Continuum production, got " .. production)
assert(veteran.Foundry.Migrated == true and veteran.Foundry.Shards > 0, "migration grants shards")
S.Ensure(veteran, now)
assert(S.Effects(veteran, now) == production, "migration runs once")

-- a fresh player gets the starter board
local p = {}
S.Ensure(p, now)
local f = p.Foundry
assert(f.Pieces["-1,0"].Kind == "Ember" and f.Pieces["1,0"].Kind == "ForgeAnvil", "starter layout")
assert(S.Effects(p, now) > 1, "starter board already helps")

-- junk is refused, never thrown
for _, junk in { nil, 5, {}, { Op = "warp" }, { Op = "place", From = "bench:99", To = "0,1" }, { Op = "place", From = "bench:1", To = "9,9" },
	{ Op = "rotate", At = "0,1" }, { Op = "move", From = "1,0", To = "1,0" }, { Op = "place", From = string.rep("x", 40), To = "0,1" } } do
	local ok = S.Act(p, junk, random, now)
	assert(ok == false, "junk payload refused")
end

-- place a bench piece, rotate it, put it back
local benchBefore = #f.Bench
local ok, _, extra = S.Act(p, { Op = "place", From = "bench:1", To = "0,1" }, random, now)
assert(ok and f.Pieces["0,1"] ~= nil and #f.Bench == benchBefore - 1 and extra.Sound == "foundryPlace", "place from bench")
ok = S.Act(p, { Op = "rotate", At = "0,1" }, random, now)
assert(ok and f.Pieces["0,1"].Facing == 1, "rotate turns one side")
ok = S.Act(p, { Op = "rotate", At = "0,1", Back = true }, random, now)
assert(ok and f.Pieces["0,1"].Facing == 0, "rotate back")
ok = S.Act(p, { Op = "store", From = "0,1" }, random, now)
assert(ok and f.Pieces["0,1"] == nil and #f.Bench == benchBefore, "store returns it to the bench")

-- fuse two identical pieces; different ones refuse
f.Bench = { { Kind = "Conduit", Tier = 1, Facing = 0 } }
ok, _, extra = S.Act(p, { Op = "place", From = "bench:1", To = "0,0" }, random, now)
assert(ok and f.Pieces["0,0"].Tier == 2 and extra.Sound == "foundryFuse", "conduit + conduit = tier 2")
f.Bench = { { Kind = "Lens", Tier = 1, Facing = 0 } }
ok = S.Act(p, { Op = "place", From = "bench:1", To = "0,0" }, random, now)
assert(ok == false and f.Pieces["0,0"].Kind == "Conduit", "different pieces do not fuse")

-- draws cost shards and fill the bench; expansion grows the board
f.Shards = 1e6
f.Bench = {}
for _ = 1, F.BENCH_CAP do
	assert(S.Act(p, { Op = "draw" }, random, now), "draw")
end
assert(#f.Bench == F.BENCH_CAP and S.Act(p, { Op = "draw" }, random, now) == false, "a full bench refuses a draw")
local radius = f.Radius
assert(S.Act(p, { Op = "expand" }, random, now) and f.Radius == radius + 1, "expand")

-- ignite: on the beat builds a combo and pays; off the beat resets
f.IgniteAt = 0
local target = F.targetPhase({ Radius = f.Radius, Pieces = f.Pieces })
local onTime = target * F.IGNITE_PERIOD + F.IGNITE_PERIOD * 100
local shards = f.Shards
ok, _, extra = S.Act(p, { Op = "ignite" }, random, onTime)
assert(ok and extra.OnBeat and f.Combo == 1 and f.Shards > shards, "on-beat ignite pays")
ok, _, extra = S.Act(p, { Op = "ignite" }, random, onTime + F.IGNITE_PERIOD * 0.5)
assert(ok and not extra.OnBeat and f.Combo == 0, "off-beat ignite resets the combo")

-- passive shards accrue, capped
local before = f.Shards
f.LastAt = 0
S.Accrue(f, 1e9)
assert(f.Shards - before <= f.ShardRate * 8 * 3600 + 1e-6, "accrual is capped at eight hours")

-- a corrupted save is repaired, not trusted
p.Foundry.Pieces = { ["99,99"] = { Kind = "Ember", Tier = 1, Facing = 0 }, ["0,0"] = { Kind = "Ember", Tier = 999, Facing = 0 }, bad = 5 }
p.Foundry.Shards = 0 / 0
S.Ensure(p, now)
assert(next(p.Foundry.Pieces) == nil and p.Foundry.Shards == 0, "invalid pieces and numbers are dropped")
assert(S.State(p, now).Shards == 0, "public state")

print("[INFO] [TEST] star foundry service passed | migration, place/rotate/store/fuse/draw/expand/ignite, junk, accrual, repair")
