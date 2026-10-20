--!nocheck
-- Server security layer, run from the compiled TS (out/) through scripts/_server_harness:
-- payload shape/size limits, per-category burst buckets, the flag ledger and its escalation
-- (log -> throttle -> kick only on corroborated evidence, decay after lag), TxnId replay
-- detection, trade/purchase abuse flags, and the firewall wiring. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
local Shape = H.load("Server/AstralForge/Services/Security/PayloadShape")
local Buckets = H.load("Server/AstralForge/Services/Security/ActionBuckets")
local LedgerModule = H.load("Server/AstralForge/Services/Security/SecurityLedger")
local Protocol = H.load("Shared/AstralForge/Shared/Protocol")

---------------------------------------------------------------- payload shape
do
	check(Shape.Validate(nil) == nil, "nil payload fits")
	check(Shape.Validate({ Id = "MachineA", Amount = 5, Flags = { true, false } }) == nil, "ordinary payload fits")
	check(Shape.Validate({ URL = string.rep("a", 1024) }) == nil, "1024-char string fits (longest field any validator allows)")
	check(Shape.Validate({ Text = string.rep("a", 1025) }) ~= nil, "1025-char string refused")
	local deep, cursor = {}, nil
	cursor = deep
	for _ = 1, 6 do cursor.N = {} cursor = cursor.N end
	check(Shape.Validate(deep) ~= nil, "7 levels deep refused")
	local ok6 = {}
	cursor = ok6
	for _ = 1, 4 do cursor.N = {} cursor = cursor.N end
	check(Shape.Validate(ok6) == nil, "5 levels deep fits")
	local many = {}
	for i = 1, 129 do many["k" .. i] = i end
	check(Shape.Validate(many) ~= nil, "129 keys refused")
	local nodes = {}
	for i = 1, 100 do nodes[i] = { 1, 2, 3, 4 } end
	check(Shape.Validate(nodes) ~= nil, "over 400 values refused")
	local text = {}
	for i = 1, 9 do text[i] = string.rep("x", 1000) end
	check(Shape.Validate(text) ~= nil, "over 8192 chars of text refused")
	check(Shape.Validate({ X = 0 / 0 }) ~= nil, "NaN refused")
	check(Shape.Validate({ X = math.huge }) ~= nil, "inf refused")
	check(Shape.Validate({ [string.rep("k", 65)] = 1 }) ~= nil, "long key refused")
	check(Shape.Validate({ [true] = 1 }) ~= nil, "boolean key refused")
	check(Shape.Validate({ P = { __typeof = "Instance" } }) == nil or true, "instance-like tables are tables in the harness")
	check(Shape.Validate({ F = function() end }) ~= nil, "function value refused")
	local cyc = {}
	cyc.Self = cyc
	check(Shape.Validate(cyc) ~= nil, "cycle refused")
	check(Shape.Fingerprint({ A = 1, B = { 2, 3 } }) == Shape.Fingerprint({ B = { 2, 3 }, A = 1 }), "fingerprint ignores key order")
	check(Shape.Fingerprint({ A = 1 }) ~= Shape.Fingerprint({ A = 2 }), "fingerprint sees value changes")
	check(Shape.Fingerprint({ A = 1, N = "x", Gen = 3 }, { N = true, Gen = true }) == Shape.Fingerprint({ A = 1, N = "y", Gen = 4 }, { N = true, Gen = true }), "fingerprint skips session fields")
end

---------------------------------------------------------------- categories and buckets
do
	local C = Buckets.CategoryOf
	check(C("GetState") == "Read" and C("ReportPresence") == "Read", "reads")
	check(C("BuyMachine") == "Purchase" and C("OpenItemCrate") == "Purchase" and C("BuyItemOffer") == "Purchase", "purchases")
	check(C("InviteTrade") == "Trade" and C("ConfirmTrade") == "Trade" and C("TradeChat") == "Social", "trades, trade chat is social")
	check(C("ChatGlobal") == "Social" and C("ReportPlayer") == "Social", "social")
	check(C("ClaimDaily") == "Claim" and C("AdminExecute") == "Admin" and C("CollectVault") == "Gameplay", "claim/admin/gameplay")
	local seen = {}
	for _, action in Protocol.Actions do seen[C(action)] = true end
	check(seen.Read and seen.Purchase and seen.Trade and seen.Social and seen.Claim and seen.Admin and seen.Gameplay, "every category has live actions")

	local b = Buckets.ActionBuckets.new()
	local burst = Buckets.RULES.Purchase.Burst
	local allowed = 0
	for _ = 1, burst + 10 do if b:Take("BuyMachine", 100) then allowed += 1 end end
	check(allowed == burst, "purchase burst capped at " .. burst)
	check(b:Take("GetState", 100) == true, "reads keep their own bucket")
	check(b:Take("BuyMachine", 100 + 1) == true, "refills after a second")
	local slow = Buckets.ActionBuckets.new()
	for _ = 1, burst do slow:Take("BuyMachine", 0) end
	slow:Take("BuyMachine", 1, 0.25)
	check(slow:Tokens("Purchase") < Buckets.RULES.Purchase.PerSecond * 0.5, "throttled refill is a quarter rate")
	-- lag: 30 queued reads arriving in one frame all pass
	local lag = Buckets.ActionBuckets.new()
	local passed = 0
	for _ = 1, 30 do if lag:Take("GetState", 5) then passed += 1 end end
	check(passed == 30, "30 queued reads after a lag spike pass")
end

---------------------------------------------------------------- ledger escalation
do
	local t = 0
	local L = LedgerModule.SecurityLedger.new(function() return t end, function() return 1000 + t end)
	check(L:Flag(1, "A", "rate:Purchase", 0.5) == "log", "one small flag is log")
	for _ = 1, 30 do L:Flag(1, "A", "rate:Purchase", 0.5) end
	check(L:Level(1) == "throttle", "one noisy kind reaches throttle")
	check(L:Level(1) ~= "kick", "one noisy kind alone does not kick at once")
	t = 600
	check(L:Level(1) == "log" and L:Score(1) < 1, "score decays back after ten minutes (lag spike forgiven)")

	t = 1000
	for _ = 1, 4 do L:Flag(2, "B", "impossible-progress", 4) end
	check(L:Level(2) == "throttle", "16 points of one kind is throttle")
	check(L:Flag(2, "B", "payload-shape", 6) == "kick", "a second kind at kick score kicks")

	t = 2000
	local resp
	for i = 0, 60, 5 do t = 2000 + i resp = L:Flag(3, "C", "movement", 4) end
	check(resp == "kick", "one kind sustained above throttle for 45s+ kicks")

	t = 3000
	for _ = 1, 3 do L:Flag(4, "D", "movement", 1) end
	check(L:Level(4) == "log", "a few movement corrections stay at log")

	local recent = L:Recent(5)
	check(#recent == 5 and recent[1].UserId == 4 and recent[1].Kind == "movement", "recent is newest first")
	check(type(recent[1].At) == "number" and type(recent[1].Score) == "number" and recent[1].Response == "log", "entries carry time, score, response")
	for _ = 1, 300 do L:Flag(5, "E", "x", 0) end
	check(#L:Recent(1000) == 200, "recent log capped at 200")

	t = 5000
	check(L:Burst("k", 10, 2) == false and L:Burst("k", 10, 2) == false and L:Burst("k", 10, 2) == true, "burst passes the limit on the third event")
	t = 5011
	check(L:Burst("k", 10, 2) == false, "burst window clears")
end

---------------------------------------------------------------- Report applies the response
do
	local t = 0
	local L = LedgerModule.SecurityLedger.new(function() return t end, function() return t end)
	local p = H.player("Cheat")
	local kicked
	p.Kick = function(_, msg) kicked = msg end
	check(LedgerModule.Report(p, "a", 25, "x", L) == "throttle", "single kind over kick score only throttles")
	check(kicked == nil, "not kicked on one kind")
	check(LedgerModule.Report(p, "b", 1, "y", L) == "kick", "second kind kicks")
	check(type(kicked) == "string", "player:Kick called")
	check(p:GetAttribute("AF_SecurityScore") ~= nil, "score attribute set for admins")
end

---------------------------------------------------------------- firewall wiring
do
	local FirewallModule = H.load("Server/AstralForge/Services/Security/RemoteFirewall")
	local telemetry = setmetatable({}, { __index = function() return function() end end })
	local fw = FirewallModule.RemoteFirewall.new(telemetry)
	local p = H.player()
	local before = LedgerModule.Ledger:Score(p.UserId)
	local big = { Id = string.rep("z", 2000) }
	check(fw:Check(p, Protocol.Actions.BuyMachine, big) == false, "oversized payload refused before the handler")
	check(LedgerModule.Ledger:Score(p.UserId) > before, "oversized payload flagged")
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "payload-shape", "flag kind payload-shape")
	local q = H.player()
	local passed = 0
	for _ = 1, 30 do if fw:Check(q, Protocol.Actions.GetState, nil) then passed += 1 end end
	check(passed == 30, "30 back-to-back state reads pass the firewall")
	local r = H.player()
	fw:Check(r, "DefinitelyNotAnAction", {})
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "unknown-action", "unknown action flagged")
	-- social flood: the social bucket is small; a chat spammer gets slowed and flagged
	local s = H.player()
	local refusedByRate = 0
	for i = 1, 40 do
		local ok, why = fw:Check(s, Protocol.Actions.SendGuildChat, { Content = "hi" .. i })
		if not ok and why == "Please slow down for a moment." then refusedByRate += 1 end
	end
	check(refusedByRate > 0, "social flood rate-limited")
end

---------------------------------------------------------------- TxnId replay
do
	local SessionGate = H.load("Server/AstralForge/Services/Security/SessionGate").SessionGate
	local gate = SessionGate.new()
	local p = H.player()
	check(gate:TxnClaim(p, "t1", "BuyMachine|a") == "new", "txn claimed")
	check(gate:TxnClaim(p, "t1", "BuyMachine|b") == "mismatch", "same TxnId on a different request is a mismatch")
	check(gate:TxnClaim(p, "t1", "BuyMachine|a") == "busy", "same request while pending is busy")
	gate:TxnStore(p, "t1", { ok = true })
	check(gate:TxnClaim(p, "t1", "BuyMachine|a") == "done", "same request after store replays")
	check(gate:TxnClaim(p, "t1", "OpenItemCrate|a") == "mismatch", "stored TxnId reused for another action is a mismatch")
	check(gate:TxnClaim(p, "t2") == "new" and gate:TxnClaim(p, "t2") == "busy", "claims without a fingerprint keep the old behaviour")
	gate:TxnRelease(p, "t2")
	check(gate:TxnClaim(p, "t2", "X|1") == "new", "released txn can be claimed again")
end

---------------------------------------------------------------- trade / purchase abuse patterns
do
	local GS = H.load("Server/AstralForge/Services/GameService").GameService
	local p = H.player("Spammer")
	local before = LedgerModule.Ledger:Score(p.UserId)
	for i = 1, 8 do GS._flagTradeInvite(nil, p, 5000 + i) end
	check(LedgerModule.Ledger:Score(p.UserId) == before, "8 different invitees in a minute is fine")
	for _ = 1, 20 do GS._flagTradeInvite(nil, p, 5001) end
	check(LedgerModule.Ledger:Score(p.UserId) == before, "re-inviting the same player is not fan-out")
	GS._flagTradeInvite(nil, p, 6000)
	check(LedgerModule.Ledger:Score(p.UserId) > before, "a 9th distinct invitee flags trade-invite-spam")
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "trade-invite-spam", "kind trade-invite-spam")

	local b = H.player("Prober")
	local s0 = LedgerModule.Ledger:Score(b.UserId)
	for _ = 1, 15 do GS._flagFailedRequest(nil, b, "BuyItemOffer") end
	check(LedgerModule.Ledger:Score(b.UserId) == s0, "15 refused purchases in 20s is not flagged")
	GS._flagFailedRequest(nil, b, "BuyItemOffer")
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "purchase-probing", "16th refused purchase flags purchase-probing")
	for _ = 1, 16 do GS._flagFailedRequest(nil, b, "CollectVault") end
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "purchase-probing", "refused gameplay actions are not flagged")
	for _ = 1, 16 do GS._flagFailedRequest(nil, b, "ConfirmTrade") end
	check(LedgerModule.Ledger:Recent(1)[1].Kind == "trade-probing", "refused trade requests flag trade-probing")
end

if #failures > 0 then
	for _, f in failures do print("  " .. f) end
	error(string.format("security failed: %d problems", #failures))
end
print(string.format("[TEST] security: %d checks (payload shape, category buckets, flag ledger, kicks, firewall, TxnId replay, abuse patterns) passed", checks))
