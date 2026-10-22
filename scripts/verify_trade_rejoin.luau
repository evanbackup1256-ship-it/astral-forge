--!nocheck
-- Trade rejoin mid-settle (audit follow-up): a settle that faulted leaves a journal on each side;
-- when that player rejoins, TradeRecovery reverts exactly this side's applied exchange, once.
-- Pins: a side that never committed is left alone even when the partner committed (the old
-- flag fallthrough), a revert that can't be covered (proceeds already spent) keeps the journal
-- instead of half-reverting, and a second rejoin is a no-op. Run rbxtsc first.
local H = require("./_server_harness")
H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
local Suite = H.load("Server/AstralForge/Modules/TradeSuite")
local Recovery = Suite.TradeRecovery or Suite("TradeRecovery")
local Exchange = Suite.TradeExchange or Suite("TradeExchange")
local OfferMath = Suite.TradeOfferMath or Suite("TradeOfferMath")
local Template = H.load("Server/AstralForge/DataTemplate")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local function offer(fields)
	local o = OfferMath.EmptyOffer(Exchange.BOOST_IDS, Exchange.KEY_IDS)
	for k, v in fields do o[k] = v end
	return o
end
-- host gave 5 Stardust for 3 Cores; the host side was applied (Stardust 45, Cores 10)
local function applied()
	local p = Template.New()
	p.Cash, p.Stardust, p.Cores = 100, 45, 10
	return p
end
local function journal(side, hostCommitted, guestCommitted)
	local session = { Id = "S1", Host = 1, Guest = 2, HostCommitted = hostCommitted, GuestCommitted = guestCommitted }
	local plan = { HostOffer = offer({ Stardust = 5 }), GuestOffer = offer({ Cores = 3 }), HostItems = {}, GuestItems = {} }
	return Recovery.MakeFaultedEntry(session, side, plan, "player left mid-settle", 1000)
end
local logs = {}
local function log(m) table.insert(logs, m) end

do -- host committed, guest left before its side applied: host rejoins and is made whole
	local p = applied()
	p.Trade.FaultedJournal = journal("host", true, false)
	Recovery.RecoverFaulted(p, 2000, log)
	check(p.Stardust == 50 and p.Cores == 7, "committed host side is reverted on rejoin")
	check(p.Trade.FaultedJournal == nil, "journal cleared after a clean recovery")
	Recovery.RecoverFaulted(p, 3000, log)
	check(p.Stardust == 50 and p.Cores == 7, "a second rejoin does not revert again")
end
do -- host never committed but the guest did: the host must not be touched
	local p = Template.New()
	p.Cash, p.Stardust, p.Cores = 100, 50, 7
	p.Trade.FaultedJournal = journal("host", false, true)
	Recovery.RecoverFaulted(p, 2000, log)
	check(p.Stardust == 50 and p.Cores == 7, "an uncommitted side is never reverted because the partner committed")
	check(p.Trade.FaultedJournal == nil, "nothing-to-do journal is cleared")
end
do -- guest side applied (got 5 Stardust, gave 3 Cores) and guest rejoins
	local p = Template.New()
	p.Cash, p.Stardust, p.Cores = 100, 15, 4
	p.Trade.FaultedJournal = journal("guest", false, true)
	Recovery.RecoverFaulted(p, 2000, log)
	check(p.Stardust == 10 and p.Cores == 7, "committed guest side is reverted from the guest's own flags")
end
do -- the host already spent the 3 Cores it received: keep the journal, change nothing
	local p = applied()
	p.Cores = 1
	p.Trade.FaultedJournal = journal("host", true, false)
	local before = #logs
	Recovery.RecoverFaulted(p, 2000, log)
	local j = p.Trade.FaultedJournal
	check(p.Stardust == 45 and p.Cores == 1, "an uncoverable revert changes nothing")
	check(type(j) == "table" and j.Status == "faulted" and j.Problem ~= nil and j.LastAttemptAt == 2000, "journal kept with the problem for the next load")
	check(#logs > before, "the deferred recovery is logged")
	p.Cores = 5 -- earned back; the next rejoin settles it
	Recovery.RecoverFaulted(p, 4000, log)
	check(p.Stardust == 50 and p.Cores == 2 and p.Trade.FaultedJournal == nil, "a later rejoin completes the recovery")
end
do -- a journal that is not a fault is dropped
	local p = applied()
	p.Trade.FaultedJournal = { Status = "recovered" }
	Recovery.RecoverFaulted(p, 2000, log)
	check(p.Trade.FaultedJournal == nil and p.Stardust == 45, "non-faulted journals are dropped untouched")
end

if #failures > 0 then error("trade rejoin failures:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] trade rejoin: %d checks (revert once on rejoin, own-side flags, guest side, uncoverable revert kept, idempotent) passed", checks))
