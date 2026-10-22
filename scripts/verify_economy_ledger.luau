--!nocheck
-- Economy ledger: committed wallet changes become hash-chained entries, untracked changes are
-- written as their own entries, trimming keeps the chain auditable, and any edit, reorder or
-- dropped entry fails Audit. Also checks GameService._mutate records a successful mutation and
-- skips a refused one. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local L = H.load("Server/AstralForge/Modules/EconomyLedger")
local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")

local function wallet(cash, cores) return { Cash = cash, Vault = 0, Cores = cores, Stardust = 0, Ore = { Emberite = 0, Voidglass = 0, Starsteel = 0 } } end

-- snapshot reads nested ore and ignores junk
local snap = L.Snapshot({ Cash = 5, Ore = { Emberite = 2 }, Cores = "bad?" }, Omega)
assert(snap.Cash == 5 and snap["Ore.Emberite"] == 2, "snapshot reads flat and nested currencies")
assert(next(L.Snapshot(nil, Omega)) == nil, "no profile, empty snapshot")

local book = L.Book.new(16)
local p = wallet(100, 0)
local before = L.Snapshot(p, Omega)
p.Cash = 40; p.Cores = 3
local written = book:Record("BuyMachine", before, L.Snapshot(p, Omega), 1000, Omega)
assert(#written == 2, "one entry per moved currency")
assert(written[1].Currency == "Cash" and Omega.ToNumber(written[1].Delta) == -60, "cash delta")
assert(written[2].Currency == "Cores" and Omega.ToNumber(written[2].Delta) == 3, "cores delta")
assert(#book:Record("Noop", L.Snapshot(p, Omega), L.Snapshot(p, Omega), 1001, Omega) == 0, "no movement, no entry")

-- tick income outside a transaction shows up as an untracked entry before the next one
p.Cash = 90
before = L.Snapshot(p, Omega)
p.Cash = 10
written = book:Record("Upgrade", before, L.Snapshot(p, Omega), 1002, Omega)
assert(#written == 2 and written[1].Reason == L.UNTRACKED and Omega.ToNumber(written[1].Delta) == 50, "untracked gap recorded")
assert(written[2].Reason == "Upgrade", "then the transaction")
assert(book:Audit(), "clean book audits")
assert(Omega.ToNumber(book:Totals(Omega, "Upgrade").Cash) == -80, "totals by reason")

-- big numbers stored as strings
local big = book:Record("Rebirth", { Cash = "1e400" }, { Cash = "2e400" }, 1003, Omega)
assert(#big == 1 or #big == 2, "string balances are recorded")
assert(book:Audit(), "audit with big numbers")

-- trimming keeps audit working
for i = 1, 40 do
	local b = L.Snapshot(p, Omega); p.Cash += i
	book:Record("Tick" .. i, b, L.Snapshot(p, Omega), 2000 + i, Omega)
end
assert(#book:Entries() == 16, "capacity holds")
local ok, why = book:Audit()
assert(ok, "trimmed book still audits: " .. tostring(why))

-- tampering
local entries = book:Entries()
local saved = entries[5].Delta
entries[5].Delta = 999999
assert(not book:Audit(), "an edited delta fails audit")
entries[5].Delta = saved
assert(book:Audit(), "restored")
entries[3], entries[4] = entries[4], entries[3]
assert(not book:Audit(), "reordered entries fail audit")
entries[3], entries[4] = entries[4], entries[3]
local removed = table.remove(entries, 8)
assert(not book:Audit(), "a dropped entry fails audit")
table.insert(entries, 8, removed)
assert(book:Audit(), "restored again")

-- per-player books
local all = L.Ledgers.new()
assert(all:For(1) == all:For(1) and all:For(1) ~= all:For(2), "one book per player")
all:Drop(1)
assert(not all:Has(1) and all:Has(2), "drop on leave")

-- GameService._mutate wiring
H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local player = H.player()
local profile = DataTemplate.New()
profile.Cash = 500
local svc = setmetatable({
	_runtime = { [player] = {} },
	_antiCheat = { Observe = function() return nil, false end },
	_data = { AtomicUpdate = function(_, _, cb) local r = cb(profile) return true, r end },
}, { __index = GS })

local r = svc:_mutate(player, function(pr) pr.Cash = 200 return { ok = true } end, false, "BuyThing")
assert(r.ok, "mutation went through")
local mine = svc:_ledgers():For(player.UserId):Entries()
assert(#mine == 1 and mine[1].Reason == "BuyThing" and Omega.ToNumber(mine[1].Delta) == -300, "mutate records the change")
r = svc:_mutate(player, function(pr) return { ok = false, message = "no" } end, false, "Refused")
assert(#svc:_ledgers():For(player.UserId):Entries() == 1, "refused mutation writes nothing")

print("verify_economy_ledger: ok")
