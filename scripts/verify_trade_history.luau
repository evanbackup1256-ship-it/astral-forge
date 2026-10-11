-- Completed-trade history and one-sided offer warnings.
local fs = require("@lune/fs")
local TradeHistory = require("../src/Shared/AstralForge/Shared/TradeHistory")

local empty = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boosts = { Surge = 0 }, Keys = { Bronze = 0 }, ItemIds = {} }
local function offer(fields)
	local copy = table.clone(empty)
	for key, value in fields do copy[key] = value end
	return copy
end

assert(TradeHistory.isEmpty(empty) and TradeHistory.isEmpty(nil), "empty offers")
assert(not TradeHistory.isEmpty(offer({ Stardust = 5 })) and not TradeHistory.isEmpty(offer({ ItemIds = { "IT1" } })), "non-empty offers")
assert(not TradeHistory.isEmpty(offer({ Boosts = { Surge = 2 } })), "boosts count")

local text = TradeHistory.summarize(offer({ Cash = 1200, Stardust = 30, Boosts = { Surge = 2 }, Keys = { Bronze = 1 } }), { "Ember Crown" }, function(v) return tostring(v) end)
assert(text == "1200 flux, 30 dust, 2 boosts, 1 key, Ember Crown", text)
assert(TradeHistory.summarize(empty, {}) == "nothing", "empty summary")
assert(string.find(TradeHistory.summarize(empty, { "a", "b", "c", "d", "e" }), "2 more items", 1, true), "long item lists are shortened")

-- record: newest first, one entry per trade, bounded
local trade = {}
for index = 1, 20 do
	TradeHistory.record(trade, { Id = "T" .. index, At = index, PartnerId = 1, Partner = "P", Gave = "a", Got = "b" })
end
assert(#trade.History == TradeHistory.LIMIT and trade.History[1].Id == "T20", "bounded, newest first")
TradeHistory.record(trade, { Id = "T20", At = 99, PartnerId = 1, Partner = "P", Gave = "x", Got = "y" })
assert(#trade.History == TradeHistory.LIMIT and trade.History[1].At == 99 and trade.History[2].Id == "T19", "a trade id is recorded once")
TradeHistory.remove(trade, "T20")
assert(trade.History[1].Id == "T19", "a reverted trade leaves the history")

-- public copy drops malformed entries and caps strings
trade.History[2] = { Id = 5 }
trade.History[3].Gave = string.rep("z", 400)
local public = TradeHistory.public(trade)
for _, entry in public do assert(type(entry.Id) == "string", "only well-formed entries reach the client") end
assert(#public[2].Gave <= 160, "long summaries are capped")

-- warnings
assert(#TradeHistory.warnings(offer({ Stardust = 9 }), empty) == 1, "giving for nothing warns")
assert(string.find(TradeHistory.warnings(empty, offer({ Stardust = 9 }))[1], "gift", 1, true), "receiving a gift is noted")
assert(#TradeHistory.warnings(offer({ Stardust = 9 }), offer({ Cores = 1 })) == 0, "a two-sided trade has no warning")
local items = TradeHistory.warnings(offer({ ItemIds = { "1", "2", "3" } }), offer({ Stardust = 100 }))
assert(#items == 1 and string.find(items[1], "3 items", 1, true), "giving many items for none is flagged")

-- wiring: history is written in the same atomic saves that apply each side, and removed on revert
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local _, recorded = string.gsub(server, "TradeHistory%.record%(profile%.Trade, tradeHistoryEntry%(", "")
assert(recorded == 2, "both sides record their own history")
assert(server:find("TradeHistory.remove(profile.Trade, tostring(session.Id))", 1, true), "reverting removes the entry")
assert(fs.readFile("src/Server/AstralForge/Modules/TradeSuite.luau"):find(".public(profile.Trade)", 1, true), "history reaches the client state")
print("[TEST] trade history: summaries, bounded single entries, revert removal, public copy and warnings passed")
