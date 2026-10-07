local Session = require("../src/Client/AstralForge/PurchaseSession")

local function fixture()
	local scheduled = {}
	local prompts = {}
	local checks = {}
	local session = Session.new({
		schedule = function(seconds, callback)
			assert(seconds == 45)
			local job = { callback = callback, cancelled = false }
			table.insert(scheduled, job)
			return function()
				job.cancelled = true
			end
		end,
		prompt = function(kind, id)
			table.insert(prompts, { kind = kind, id = id })
		end,
		verifyPass = function(key, done)
			table.insert(checks, { key = key, done = done })
		end,
	})
	local function timeout()
		local job = scheduled[#scheduled]
		assert(not job.cancelled)
		job.callback()
	end
	return session, prompts, checks, timeout, scheduled
end

local product = { ProductId = 42, Name = "Dust Pouch", Key = "DustPouch" }
local pass = { PassId = 52, Name = "Furnace Tuning", Key = "FurnaceTuning" }
local session, prompts, _, timeout, timers = fixture()
local events = 0
local unsubscribe = session.subscribe(function()
	events += 1
end)
local original = session.snapshot()
assert(session.begin(product, "product"))
assert(original.phase == "hidden" and original.token == 0, "published state must remain immutable")
assert(not session.begin(product, "product") and #prompts == 1, "double click must open only one native prompt")
assert(not session.dismiss(), "a live purchase cannot be dismissed")
session.promptFinished("product", 99, false)
assert(session.snapshot().phase == "pending", "unrelated prompt callbacks must be ignored")
session.promptFinished("product", 42, true)
assert(session.snapshot().phase == "verifying", "native prompt completion is not a saved reward")
assert(timers[1].cancelled, "verifying replaces the pending deadline")
session.receipt({ ProductId = 42 })
session.receipt({ ProductId = 99, Key = "wrong" })
session.receipt({ ProductId = 42, Key = "" })
assert(session.snapshot().phase == "verifying")
timeout()
assert(session.snapshot().phase == "delayed" and session.snapshot().awaiting)
assert(session.dismiss() and session.snapshot().phase == "hidden")
assert(not session.begin(product, "product"), "a timeout must not enable a repeat charge")
unsubscribe()
local count = events
session.resume()
assert(session.snapshot().phase == "delayed" and events == count)
local remounted = 0
session.subscribe(function()
	remounted += 1
end)
session.receipt({ ProductId = 42, Key = "receipt-one" })
assert(session.snapshot().phase == "success" and not session.snapshot().awaiting and remounted == 2)
assert(session.begin(product, "product"))
session.receipt({ ProductId = 42, Key = "receipt-one" })
assert(session.snapshot().phase == "pending", "duplicate delivery cannot finish the next purchase")
session.receipt({ ProductId = 42, Key = "receipt-two" })
assert(session.snapshot().phase == "success")

local passSession, _, checks = fixture()
assert(passSession.begin(pass, "pass"))
passSession.promptFinished("pass", 52, true)
checks[1].done(false)
assert(passSession.snapshot().phase == "verifying", "unverified ownership must not report success")
passSession.promptFinished("pass", 52, false)
assert(passSession.snapshot().phase == "cancelled" and not passSession.snapshot().awaiting)
assert(passSession.begin(pass, "pass"))
checks[1].done(true)
assert(passSession.snapshot().phase == "pending", "stale verification cannot finish a newer purchase")
passSession.reconcile({ FurnaceTuning = true })
assert(passSession.snapshot().phase == "success")

local failures = Session.new({
	schedule = function()
		return function() end
	end,
	prompt = function()
		error("unavailable")
	end,
})
assert(not failures.begin(product, "product") and failures.snapshot().phase == "fail")
assert(not failures.begin({ ProductId = 42, Donation = true }, "product"))
for _, id in { 0, -1, math.huge, 0 / 0, 1.5, "42" } do
	assert(not failures.begin({ ProductId = id }, "product"))
end
local disposed, _, _, _, jobs = fixture()
assert(disposed.begin(pass, "pass"))
disposed.dispose()
assert(jobs[1].cancelled)
disposed.promptFinished("pass", 52, true)
disposed.reconcile({ FurnaceTuning = true })
assert(disposed.snapshot().phase == "pending" and not disposed.dismiss())
assert(not disposed.begin(product, "product"))
print(
	"[TEST] native purchase latch, saved delivery, timeout/remount, duplicate receipts and stale pass callbacks passed"
)
