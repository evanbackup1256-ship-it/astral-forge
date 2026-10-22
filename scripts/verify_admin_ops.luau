--!nocheck
-- Live-ops admin console (roadmap 14), from the compiled TS: security flag summary and per-player
-- lookup, journal rollback through ProfileIntegrity, hot flags (parse, ordering, kill switches in
-- GameService), cross-server announce/flag messages, the economy dashboard, and role access.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

-- MessagingService fake: records publishes
local published = {}
H.services.MessagingService = {
	PublishAsync = function(_, topic, msg) table.insert(published, { topic, msg }) end,
	SubscribeAsync = function() return { Disconnect = function() end } end,
}
-- TextService fake: broadcast filter passes text through unchanged
H.services.TextService = {
	FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end,
}
local toasts = {}
H.mock("Server/AstralForge/Runtime/ServerNetwork", {
	ServerEvents = setmetatable({ toast = { fire = function(_, p, t) table.insert(toasts, { p, t }) end } }, { __index = function() return H.Stub end }),
	ServerFunctions = H.Stub,
})
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })

------------------------------------------------------------------ ledger summary and lookup
do
	local LedgerModule = H.load("Server/AstralForge/Services/Security/SecurityLedger")
	local t = 0
	local L = LedgerModule.SecurityLedger.new(function() return t end, function() return 1000 + t end)
	L:Flag(1, "A", "speed", 2, "x")
	t = 1 L:Flag(2, "B", "rate-limit", 9, "y")
	t = 2 L:Flag(1, "A", "noclip", 3, "z")
	local rows = L:Summary(10)
	check(#rows == 2 and rows[1].UserId == 2, "summary: one row per player, highest score first")
	check(rows[2].Flags == 2 and rows[2].Kinds.speed == 1 and rows[2].Kinds.noclip == 1, "summary counts flags by kind")
	check(rows[2].LastKind == "noclip" and rows[2].LastAt == 1002, "summary keeps the newest flag")
	local mine = L:ForUser(1, 10)
	check(#mine == 2 and mine[1].Kind == "noclip" and mine[2].Kind == "speed", "ForUser: this player only, newest first")
	check(#L:ForUser(1, 1) == 1, "ForUser honors the limit")
end

------------------------------------------------------------------ journal + rollback
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local PI = H.load("Server/AstralForge/Services/Security/ProfileIntegrity")
do
	local p = DataTemplate.New()
	p.Cash = 500 p.Stardust = 7
	local good = PI.Record(p, "buy", 3)
	p.Cash = 9e12 p.Stardust = 99999 -- the exploit
	PI.Record(p, "exploit", 4)
	local journal = PI.Journal(p)
	check(#journal == 2 and journal[1].Label == "exploit" and journal[2].Cash == 500, "journal lists entries newest first with balances")
	check(journal[1].Valid == true and journal[2].Valid == true, "journal marks intact entries valid")
	local ok, msg = PI.Restore(p, good.Id)
	check(ok and p.Cash == 500 and p.Stardust == 7, "restore puts critical state back: " .. tostring(msg))
	check(not PI.Restore(p, "nope"), "unknown journal id refused")
	p.Meta.Transactions[1].Snapshot.Cash = 1e300 -- tampered
	local ok2 = PI.Restore(p, good.Id)
	check(not ok2 and p.Cash == 500, "a tampered journal entry is refused and changes nothing")
end

------------------------------------------------------------------ hot flags
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
do
	HotFlags.Reset()
	local name, on = HotFlags.Parse(" TradingPaused = ON ")
	check(name == "TradingPaused" and on == true, "parse Name=on")
	check(HotFlags.Parse("Nope=on") == nil and HotFlags.Parse("TradingPaused=maybe") == nil, "bad flags refused")
	check(HotFlags.Set("TradingPaused", true, 100) == true and HotFlags.Get("TradingPaused"), "set on")
	check(HotFlags.Set("TradingPaused", false, 50) == false and HotFlags.Get("TradingPaused"), "an older message cannot undo a newer change")
	HotFlags.Reset()
	check(not HotFlags.Get("TradingPaused") and not HotFlags.Get("CratesPaused"), "every flag defaults off")
end

------------------------------------------------------------------ dashboard
do
	local Dash = H.load("Server/AstralForge/Modules/OpsDashboard")
	local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
	local actions = {} -- roblox-ts Map is a plain table
	actions.Tap = 40 actions.BuyMachine = 12 actions.Rebirth = 1
	local d = Dash.Build({
		{ Cash = 100, Production = 10, Rebirths = 1, Stardust = 5, Cores = 1 },
		{ Cash = "2.000000000000e30", Production = 30, Rebirths = 3, Stardust = 5, Cores = 0 },
		{ Cash = 50, Production = 20, Rebirths = 9, Stardust = 0, Cores = 2 },
	}, actions, Omega, 2)
	check(d.Players == 3 and d.MedianProduction == 20 and d.MedianRebirths == 3, "dashboard medians")
	check(Omega.Gt(d.TotalCash, 1e30) and d.RichestCash == "2.000000000000e30", "dashboard totals Omega-string Cash")
	check(#d.TopActions == 2 and d.TopActions[1].Action == "Tap", "dashboard top actions, bounded")
end

------------------------------------------------------------------ role access
do
	local Policy = H.load("Server/AstralForge/Modules/AdminPolicy")
	local defs = {
		Announce = { Category = "LiveOps", Global = true },
		ToggleHotFlag = { Category = "LiveOps", Global = true },
		RollbackCritical = { Category = "Resets" },
		InspectPlayer = { Category = "Moderation" },
	}
	check(Policy.Allows("Owner", "Announce", defs.Announce) == true, "owner can announce")
	check(Policy.Allows("Developer", "ToggleHotFlag", defs.ToggleHotFlag) == true and Policy.Allows("Developer", "Announce", defs.Announce) == true, "developers may announce and flip live-ops flags")
	check(Policy.Allows("Moderator", "InspectPlayer", defs.InspectPlayer) == true, "moderators can look players up")
	check(Policy.Allows("Moderator", "RollbackCritical", defs.RollbackCritical) == false, "moderators cannot roll back")
	check(Policy.Allows("Developer", "RollbackCritical", defs.RollbackCritical) == true, "developers can roll back")
end

------------------------------------------------------------------ AdminService live-ops messages
do
	local AS = H.load("Server/AstralForge/Services/AdminService").AdminService
	HotFlags.Reset()
	local a, b = H.player("P1"), H.player("P2")
	local admin = H.player("Owner")
	H.Players.__players = { a, b }
	local recorded = {}
	local stored = nil
	local store = { UpdateAsync = function(_, key, fn) stored = fn(stored) return stored end }
	local self = setmetatable({ _flagStore = store, _announcements = {}, _alive = true, _record = function(_, ...) table.insert(recorded, { ... }) end }, { __index = AS })
	local r = self:_global(admin, "Announce", { Option = true, Category = "LiveOps", Global = true }, "Servers restart in 5 minutes", "maint", false)
	check(r.ok == true and #published == 1 and published[1][2].Kind == "Announce", "announce publishes to the live-ops topic")
	check(#toasts == 2 and #self._announcements == 1, "announce toasts every player here once (" .. #toasts .. "," .. #self._announcements .. ")")
	check(self:ReceiveLiveOps(published[1][2]) == false and #toasts == 2, "this server ignores its own echo")
	check(#recorded == 1 and recorded[1][3] == "Announce", "announce is audited")
	local dry = self:_global(admin, "ToggleHotFlag", { Option = true, Category = "LiveOps", Global = true }, "CratesPaused=on", "maint", true)
	check(dry.DryRun == true and not HotFlags.Get("CratesPaused"), "dry run changes nothing")
	local f = self:_global(admin, "ToggleHotFlag", { Option = true, Category = "LiveOps", Global = true }, "CratesPaused=on", "maint", false)
	check(f.ok and HotFlags.Get("CratesPaused") and published[2][2].Flag == "CratesPaused", "flag applied here and published")
	check(stored ~= nil and stored.Flags.CratesPaused == true and stored.Flags.TradingPaused == false, "flag state is saved for servers that start later")
	-- a newer stored change is never overwritten by an older local write
	local savedAt = stored.ChangedAt
	stored = { Flags = { TradingPaused = true }, ChangedAt = savedAt + 1000 }
	check(HotFlags.Merge(stored).ChangedAt == savedAt + 1000 and HotFlags.Get("TradingPaused") and not HotFlags.Get("CratesPaused"), "merge keeps the newer stored state")
	-- a new server loads the saved state; an older stored state cannot undo a newer local one
	HotFlags.Reset()
	check(HotFlags.Decode({ Flags = { CratesPaused = true }, ChangedAt = 10 }) == true and HotFlags.Get("CratesPaused"), "a new server starts with the saved flags")
	check(HotFlags.Decode({ Flags = {}, ChangedAt = 5 }) == false and HotFlags.Get("CratesPaused"), "an older saved state cannot undo a newer change")
	check(HotFlags.Decode(nil) == false and HotFlags.Decode("junk") == false, "missing or junk saved state ignored")
	check(self:_global(admin, "ToggleHotFlag", { Option = true }, "Bogus=on", "m", false).ok == false, "bad flag refused")
	check(self:ReceiveLiveOps({ Kind = "HotFlag", Flag = "TradingPaused", On = true, At = os.time() + 5 }) == true and HotFlags.Get("TradingPaused"), "a flag from another server applies")
	check(self:ReceiveLiveOps("junk") == false and self:ReceiveLiveOps({ Kind = "Nope" }) == false, "junk messages ignored")
end

------------------------------------------------------------------ kill switches in GameService
do
	local GS = H.load("Server/AstralForge/Services/GameService").GameService
	local p = H.player()
	local fake = setmetatable({ _data = { Get = function() return DataTemplate.New() end } }, { __index = GS })
	local r = GS._openItemCrate(fake, p, "ForgeCrate", 1)
	check(r.ok == false and string.find(r.message or r.error or "", "paused"), "crates refused while CratesPaused")
	local Protocol = H.load("Shared/AstralForge/Shared/Protocol")
	local tr = GS._tradeAction(fake, p, Protocol.Actions.InviteTrade, { UserId = 5 })
	check(tr.ok == false and string.find(tr.message or tr.error or "", "paused"), "trade invites refused while TradingPaused")
	HotFlags.Reset()
end

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("admin ops failed: %d problems", #failures))
end
print(string.format("[TEST] admin ops: %d checks (flag summary/lookup, journal rollback, hot flags, announce, dashboard, roles, kill switches) passed", checks))
