--!strict
-- Rebirth: vows, keepsakes, stars, the run log and grades (Shared/RebirthMath), and their wiring.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local RebirthMath = luau.load(fs.readFile("src/Shared/AstralForge/Shared/RebirthMath.luau"), { chunkName = "RebirthMath" })() :: any

-- an old save: no ledger yet, the star count starts from the rebirths already spent
local bag = RebirthMath.ensure(nil, 1000, 7)
assert(bag.Lifetime == 7 and bag.RunStartedAt == 1000 and bag.Vow == "", "fresh ledger")
assert(#RebirthMath.pendingStars(bag) == 3, "rebirths 1, 3 and 5 have lit stars")
assert(RebirthMath.keepSlots(bag.Lifetime) == 1, "one keepsake slot from rebirth 3")
local again = RebirthMath.ensure(bag, 5000, 2)
assert(again.Lifetime == 7 and again.RunStartedAt == 1000, "ensure never loses progress or restarts the clock")
bag.Stars["99"] = "HeadStart"
bag.Stars["1"] = "CoreYield"
bag.Vow = "Nonsense"
RebirthMath.ensure(bag, 1000)
assert(bag.Stars["99"] == nil and bag.Stars["1"] == nil and bag.Vow == "", "ensure drops stars and vows that can't exist")

-- stars: one of the pair, once, only when lit
local ok, err = RebirthMath.pickStar(bag, 4, 1)
assert(not ok and string.find(err, "rebirth 8", 1, true), "star 4 lights at rebirth 8")
ok = RebirthMath.pickStar(bag, 1, 3)
assert(not ok, "only one of two")
ok = RebirthMath.pickStar(bag, 1, 1)
assert(ok and bag.Stars["1"] == "HeadStart", "star 1 picks Head Start")
assert(not RebirthMath.pickStar(bag, 1, 2), "a star is chosen once")
RebirthMath.pickStar(bag, 2, 1)
assert(RebirthMath.effects(bag).CoreYield == 0.06 and RebirthMath.effects(bag).HeadStart == 5, "perks sum")

-- vows: sworn only early in a run; each is judged on the run's facts
assert(not RebirthMath.swear(bag, "Swift", 1000 + RebirthMath.VOW_GRACE + 1), "too late to swear")
assert(RebirthMath.swear(bag, "Swift", 1010), "swear early")
assert((RebirthMath.vowHolds(bag, { Seconds = 600 })), "Swift holds at 10 minutes")
assert(not (RebirthMath.vowHolds(bag, { Seconds = 800 })), "Swift breaks after 12 minutes")
bag.Vow = "Lean"
assert((RebirthMath.vowHolds(bag, { MachineKinds = 3 })) and not (RebirthMath.vowHolds(bag, { MachineKinds = 4 })), "Lean counts machine kinds")
bag.Vow = "Homebound"
assert((RebirthMath.vowHolds(bag, { Zone = 1 })) and not (RebirthMath.vowHolds(bag, { Zone = 2 })), "Homebound stays in world 1")
bag.Vow = "Overflow"
assert((RebirthMath.vowHolds(bag, { Ratio = 8 })) and not (RebirthMath.vowHolds(bag, { Ratio = 7.9 })), "Overflow needs 8x")
bag.VowSince = bag.RunStartedAt + RebirthMath.VOW_GRACE + 5
assert(not (RebirthMath.vowHolds(bag, { Ratio = 50 })), "a vow sworn late never pays")
bag.VowSince = bag.RunStartedAt

-- quotes: a kept vow multiplies what it pays; grade compares with your best
bag.Vow = "Homebound"
local quote = RebirthMath.quote(bag, { Cores = 100, Stardust = 50 }, { Zone = 1, Seconds = 60 })
assert(quote.Kept and quote.Grade == "S", "first run, vow kept: S")
assert(quote.Cores == math.floor(100 * 1.06 * 1.6), "cores: stars then vow, got " .. quote.Cores)
assert(quote.Stardust == math.floor(50 * 1.25), "stardust gets the S bonus")
local broken = RebirthMath.quote(bag, { Cores = 100, Stardust = 50 }, { Zone = 3, Seconds = 60 })
assert(not broken.Kept and broken.Grade == "A" and broken.Cores == 106, "a broken vow pays no bonus, never a penalty")

-- closing a run logs it, counts the vow, starts the next clock with the next vow
local entry = RebirthMath.close(bag, quote, 1400, "Lean", nil)
assert(entry.N == 8 and entry.Seconds == 400 and entry.Grade == "S", "run logged")
assert(bag.Lifetime == 8 and bag.RunStartedAt == 1400 and bag.Vow == "Lean" and bag.Kept.Homebound == 1, "next run set up")
assert(bag.BestCores == quote.Cores and bag.FastestSeconds == 400, "bests kept")
assert(RebirthMath.grade(bag, quote.Cores, false) == "B" and RebirthMath.grade(bag, 1, false) == "C", "grades against the best")
for i = 1, 14 do
	RebirthMath.close(bag, quote, 1400 + i, "", nil)
end
assert(#bag.Runs == RebirthMath.LOG_LIMIT, "the log keeps the last ten")

-- mastery: every five kept makes the vow stronger
bag.Kept.Lean = 10
assert(RebirthMath.mastery(bag, "Lean") == 2, "two mastery steps")
assert(math.abs(RebirthMath.vowMultiplier(bag, "Lean") - (1 + 0.45 + 0.1)) < 1e-9, "mastery adds to the vow")

-- keepsakes and the start of the next run
bag.Keep = {}
assert(RebirthMath.setKeep(bag, { "LunarExtractor", "LunarExtractor", "PrismRefinery", "StellarCore", "X" }), "keep set")
assert(#bag.Keep == RebirthMath.keepSlots(bag.Lifetime), "keepsakes capped by slots")
local carry = RebirthMath.carry(bag, { StellarCore = 300, LunarExtractor = 40, PrismRefinery = 2 }, 1000, 250, function(id)
	return id ~= "VoidSingularity"
end)
assert(carry.Machines.LunarExtractor == 8, "a keepsake keeps 20%")
assert(carry.Machines.StellarCore == 6, "Head Start puts the core at Lv 6")
assert(carry.Cash == 250, "no seed flux without the perk")

-- wiring: the server uses the ledger; the action is guarded; the card opens the chamber
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(server:find("RebirthMath.quote(ledger", 1, true) and server:find("RebirthMath.close(ledger, quote, now", 1, true), "rebirth closes the run through the ledger")
assert(server:find("Rebirth = self:_rebirthPublic(profile, now)", 1, true), "state carries the quote")
assert(server:find("return self:_rebirthAct(player, payload)", 1, true), "RebirthAct routed")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(firewall:find("[Protocol.Actions.RebirthAct] =", 1, true) and firewall:find('"invalid keepsakes"', 1, true), "firewall rule and validation")
local protocol = fs.readFile("src/Shared/AstralForge/Shared/Protocol.luau")
assert(protocol:find('RebirthAct = "RebirthAct"', 1, true), "protocol action")
local panel = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau")
assert(panel:find('dispatch("Rebirth", { Vow = nextVow, Keep = keep }', 1, true), "the chamber sends the next vow and keepsakes")
assert(panel:find('dispatch("RebirthAct", { Op = "Star"', 1, true), "stars are lit from the chamber")
assert(panel:find("ReactRoblox.createPortal", 1, true), "the chamber sits above the page")

print("[TEST] rebirth: vows, keepsakes, stars, grades and the run log")
