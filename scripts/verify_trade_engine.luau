--!nocheck
-- Trade engine: only listed state moves are allowed, final states are final, history is kept and
-- capped, escrow copies the offers at lock time, catches any later change to the live offers or
-- the escrow itself, and the real TradeSettle/TradeDesk paths go through the engine. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local E = H.load("Server/AstralForge/Modules/TradeEngine")

local function session()
	return { Host = 1, Guest = 2, Status = "Open", Offers = { [1] = { Items = { "IT1" }, Cash = 5 }, [2] = { Items = {}, Cash = 0 } } }
end

-- transitions
assert(E.Can("Open", "Confirming") and E.Can("Confirming", "Settling") and E.Can("Settling", "Settled"), "happy path")
assert(E.Can("Settling", "Open") and E.Can("Settling", "RevertFailed"), "revert paths")
assert(not E.Can("Open", "Settled"), "can't skip settling")
assert(not E.Can("Settling", "Cancelled"), "can't cancel mid-settle")
assert(not E.Can("Settled", "Open") and E.IsFinal("Settled") and E.IsFinal("Cancelled"), "final states")
assert(not E.Can("Bogus", "Open") and not E.IsState("Bogus"), "unknown state")

local t = session()
assert(E.Move(t, "Confirming", 10), "open to confirming")
local ok, why = E.Move(t, "Settled", 11)
assert(not ok and why and t.Status == "Confirming", "illegal move refused and nothing changed")
assert(E.Move(t, "Confirming", 12) and #t.History == 1, "self move is fine and not logged")
for i = 1, 40 do E.Move(t, i % 2 == 0 and "Open" or "Confirming", 100 + i) end
assert(#t.History == 32, "history capped")

-- escrow
t = session()
E.Move(t, "Settling")
local escrow = E.Lock(t, 50)
assert(escrow.LockedAt == 50 and t.Escrow == escrow, "locked")
assert(E.Verify(t), "fresh escrow verifies")
assert(E.Given(t, 1).Cash == 5 and E.Given(t, 1) ~= t.Offers[1], "escrow holds a copy")
t.Offers[1].Cash = 6
assert(not E.Verify(t), "a live offer change after lock is caught")
t.Offers[1].Cash = 5
assert(E.Verify(t), "back to agreed")
escrow.Offers[2].Cash = 1000
assert(not E.Verify(t), "an edited escrow is caught")
escrow.Offers[2].Cash = 0
E.Release(t)
assert(t.Escrow == nil and not E.Verify(t), "released")
assert(E.Fingerprint({ b = 1, a = { 2, 3 } }) == E.Fingerprint({ a = { 2, 3 }, b = 1 }), "fingerprint ignores key order")

-- the real settle code
H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
local Suite = H.load("Server/AstralForge/Modules/TradeSuite")
local Settle = Suite.TradeSettle or Suite("TradeSettle")
local live = session()
live.Ready = { [1] = true, [2] = true }
live.Confirmed = { [1] = true, [2] = true }
live.ConfirmEndsAt = 1
live.Settling = false
live.Status = "Confirming"
assert(Settle.TryBegin(live) and live.Status == "Settling" and live.Escrow ~= nil, "settling locks the escrow")
assert(not Settle.TryBegin(live), "no double settle")
Settle.Fail(live, false)
assert(live.Status == "Open" and live.Escrow == nil, "a clean revert reopens and releases")
live.Confirmed = { [1] = true, [2] = true }
assert(Settle.TryBegin(live))
Settle.Fail(live, true, "x")
assert(live.Status == "RevertFailed" and live.Escrow ~= nil, "a failed revert keeps the escrow for support")

print("verify_trade_engine: ok")
