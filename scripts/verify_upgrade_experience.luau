--!nocheck
local Math = require("../out/Shared/AstralForge/Shared/OmegaMath")
local Model = require("../out/Client/AstralForge/UpgradeModel")(Math)
local Queue = require("../out/Client/AstralForge/PurchaseQueue")
local Goals = require("../out/Client/AstralForge/OverviewGoals")(Math, tostring)
local function entry(id, cost, level, max, growth)
	return { config = { Id = id, Name = id, Description = "production bonus", BaseCost = cost, CostScale = 1.15, MaxLevel = max or 100, BaseProduction = 10, Growth = growth or 0.1 }, level = level or 0, unlocked = true, maxed = false, price = Math.ScaledCost(cost, 1.15, level or 0), order = 1 }
end
local entries = {entry("A", 100), entry("B", 100), entry("C", 100)}
assert(Model.quote(entries[1], 10, 100).ready == false)
assert(#Model.filter(entries, "  BONUS  ", "All", 1, 500) == 3)
assert(#Model.filter(entries, "nothing", "All", 1, 500) == 0)
assert(#Model.filter(entries, "", "Affordable", 10, 100) == 0)
assert(Model.gainScore(entry("grown", 100, 10)) > Model.gainScore(entries[1]))
local orders, remaining = Model.plan(entries, 0, 900)
assert(#orders == 3 and Math.Gte(remaining, 0), "Max must distribute the budget")
for _, order in orders do assert(order.Amount > 0 and order.Amount < 100) end
local many = {}
for i = 1, 100 do table.insert(many, entry(tostring(i), 1)) end
assert(#Model.plan(many, 1, 1000) == 24, "request cap")
for _, cash in {0, 1, 100, 900, 1e15, "1e309", "1e2096"} do
	for _, amount in {0, 1, 10, 100} do
		local pool = {entry("high", "1e300", 5, 1000), entry("low", 1), entry("middle", 300)}
		local budget = cash
		local plan, left = Model.plan(pool, amount, cash)
		for _, order in plan do
			assert(order.Amount <= 50, "match the server numeric amount ceiling")
			assert(Math.Gte(budget, order.Cost), "plan cannot overspend")
			budget = Math.Max(0, Math.Sub(budget, order.Cost))
		end
		assert(Math.Compare(budget, left) == 0 and Math.Gte(left, 0))
	end
end
local jobs, calls, callbacks = {}, {}, {}
local queue = Queue(function(action, payload, reply)
	table.insert(calls, payload); table.insert(callbacks, reply)
end, function(seconds, fn) table.insert(jobs, {seconds, fn}) end, function() end)
assert(queue.start("BuyMachine", orders))
assert(not queue.start("BuyMachine", orders) and #calls == 1, "same-frame latch")
callbacks[1]({ok = true})
callbacks[1]({ok = true})
assert(queue.completed == 1, "duplicate reply")
for _, job in table.clone(jobs) do if job[1] < 1 then job[2]() end end
assert(#calls == 2, "sequential dispatch")
callbacks[2]({ok = false})
assert(not queue.busy and queue.completed == 1)
local before = #calls
for _, job in table.clone(jobs) do job[2]() end
assert(#calls == before, "failure cancels remaining orders")
assert(queue.start("BuyMachine", orders))
queue.cancel()
callbacks[#callbacks]({ok = true})
for _, job in table.clone(jobs) do job[2]() end
assert(#calls == before + 1, "unmount cancels stale continuation")
queue.start("BuyMachine", orders)
jobs[#jobs][2]()
assert(not queue.busy, "timeout releases latch")
local zero = {missions = 0, lab = 0, path = false, anomaly = false}
assert(Goals({Rebirths = 0}, zero) == nil, "preserve first-run guide")
assert(Goals({Rebirths = 0, Level = {Level = 18}}, zero).page == "Workshop", "advanced players need goals even before their first rebirth")
assert(Goals({Rebirths = 10, Domain = {CanExpand = true}}, zero).page == "Domain")
assert(Goals({Rebirths = 3}, {missions = 2, lab = 0, path = false, anomaly = false}).page == "Missions")
assert(Goals({Rebirths = 3, FeatureUnlocks = {Missions = {Unlocked = false}}}, {missions = 2, lab = 0, path = false, anomaly = false}).page == "Workshop")
assert(Goals({Rebirths = 3, PrestigeReward = "1e309"}, zero).label == "CORES READY")
assert(Goals({Rebirths = 3, Level = {Next = {Level = 15, Text = "Earn Flux", Progress = "1e309", Target = "1e310"}}}, zero).progress < 1)
local fs = require("./_memberfs")(require("@lune/fs"))
local research = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#ResearchView")
local textColumns = 0
for _ in research:gmatch("sizeConstraint = UDim2%.new%(1, if stack then %-8 else %-332, 0,") do
	textColumns += 1
end
assert(textColumns == 3, "all research hero labels reserve their 72px inset and the batch controls")
for _, width in { 640, 835, 1100 } do
	local labelRight = 72 + width - 332
	local actionsLeft = width - 240
	assert(labelRight <= actionsLeft - 20, "research heading and actions need a clear gutter")
end
local storefront = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau#StoreFront")
local wallet = assert(storefront:match("(local function Wallet.-)\nlocal function Hero"))
assert(wallet:find("value = compactNumber(state[currency])", 1, true), "wallet balances use the shared large-number formatter")
print("[TEST] upgrade experience passed | budget distribution, Omega currency, amount filters, request sequencing/cancel/timeout, adaptive goals")
