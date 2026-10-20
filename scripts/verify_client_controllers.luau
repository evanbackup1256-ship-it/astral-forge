--!nocheck
-- Client controller checks, read from the compiled TS (out/) through scripts/_server_harness:
-- NetworkController connect/disconnect/reconnect, the presence session (hello, beats, auth
-- waiters, grant fields, restart), the request policy, the ActionRequest latch and the
-- PurchaseQueue. Grant fields are cross-checked against the server's read-only list. Run
-- `npx rbxtsc` first.
local H = require("./_server_harness")
local task = require("@lune/task")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function waitUntil(cond, seconds)
	local deadline = os.clock() + seconds
	while not cond() and os.clock() < deadline do task.wait(0.02) end
	return cond()
end

---------------------------------------------------------------- NetworkController
local created = 0
H.mock("Client/AstralForge/ClientNetwork", {
	createClientNetwork = function()
		created += 1
		return { id = created, functions = {}, events = {} }
	end,
})
local NC = H.load("Client/AstralForge/Controllers/NetworkController").NetworkController
do
	local nc = NC.new()
	check(nc:get() == nil, "no network before connect")
	local early, late, cleaned, broken = {}, {}, 0, 0
	nc:onConnected(function(net) table.insert(early, net.id) return function() cleaned += 1 end end)
	nc:onConnected(function() broken += 1 error("listener boom") end)
	local first = nc:connect()
	check(first.id == 1 and early[1] == 1, "connect runs listeners registered before it")
	check(broken == 1, "a failing listener is contained")
	check(nc:connect() == first and created == 1, "connect is idempotent while connected")
	nc:onConnected(function(net) table.insert(late, net.id) return function() cleaned += 1 error("cleanup boom") end end)
	check(late[1] == 1, "listener registered after connect runs at once")
	nc:disconnect()
	check(cleaned == 2, "disconnect runs every cleanup, even past a failing one")
	check(nc:get() == nil, "disconnect drops the handlers")
	nc:disconnect()
	check(cleaned == 2, "second disconnect runs nothing twice")
	local second = nc:connect()
	check(second.id == 2 and created == 2, "reconnect creates fresh handlers")
	check(early[2] == 2 and late[2] == 2 and broken == 2, "reconnect restarts every listener")
	nc:disconnect()
	check(cleaned == 4, "cleanups from the reconnect run on the next disconnect")
end

---------------------------------------------------------------- policy + grant cross-check
local Protocol = H.load("Shared/AstralForge/Shared/Protocol")
local Validators = H.load("Server/AstralForge/Modules/ProfileMath").CommandActionValidators
local Policy = H.load("Client/AstralForge/CoreKit/networkPolicy")
local Session = H.load("Client/AstralForge/CoreKit/session")
local actions = {}
for _, a in Protocol.Actions do actions[a] = true end
for a in actions do
	-- the server drops any non-read-only action without Gen/N (GameService -> SessionGate.CheckGrant)
	if not Validators.IsReadOnly(a) then
		check(Session.GRANT_ACTIONS[a] == true, "client attaches grant fields to mutating action " .. a)
	end
end
for name, list in { grant = Session.GRANT_ACTIONS, cooldown = Policy.ACTION_COOLDOWNS, pipelined = Policy.PIPELINED_ACTIONS, optimistic = Policy.OPTIMISTIC_ACTIONS, timeout = Policy.REQUEST_TIMEOUTS } do
	for a in list do check(actions[a] == true, name .. " entry is a real action: " .. tostring(a)) end
end
check(Policy.Cooldown("NoSuchAction") == Policy.DEFAULT_COOLDOWN and Policy.Cooldown(5) == Policy.DEFAULT_COOLDOWN, "unknown cooldown defaults")
check(Policy.Cooldown("SpinWheel") == 1.4, "listed cooldown used")
check(Policy.Timeout("GetState") == 8 and Policy.Timeout(nil) == Policy.DEFAULT_TIMEOUT, "timeouts")
check(Policy.IsPipelined("MarkHintSeen") and not Policy.IsPipelined("SpinWheel") and not Policy.IsPipelined({}), "pipelined lookup")
check(Policy.IsOptimistic("SetMobileLayout") and not Policy.IsOptimistic(1), "optimistic lookup")
check(Policy.RequestLimit(true) == Policy.PIPELINE_REQUEST_LIMIT and Policy.RequestLimit(false) == Policy.SERIAL_REQUEST_LIMIT, "request limits")
check(Policy.IsCoolingDown(10, 9.95, 0.1) and not Policy.IsCoolingDown(10, 9.8, 0.1), "cooldown window")
check(not Policy.IsCoolingDown("x", 1, 1) and not Policy.IsCoolingDown(1, nil, 1) and not Policy.IsCoolingDown(1, 1, {}), "junk clock never blocks")

---------------------------------------------------------------- session (against the real SessionGate)
local Gate = H.load("Server/AstralForge/Services/Security/SessionGate").SessionGate.new()
local player = H.player("Client")
local calls, hellos, beats, failNext = 0, 0, 0, 0
local fakeRequest = {
	invoke = function(_, action, payload)
		calls += 1
		local reply
		if failNext > 0 then
			failNext -= 1
			reply = { ok = false, error = "busy" }
		elseif payload.Gen == nil then
			hellos += 1
			local gen, nonce = Gate:Hello(player)
			reply = { ok = true, Gen = gen, N = nonce }
		else
			beats += 1
			local ok, err, gen, nonce = Gate:Beat(player, payload.Gen, payload.Id, payload.N)
			reply = { ok = ok, error = err, Gen = gen, N = nonce, Auth = ok }
		end
		check(action == "ReportPresence" and type(payload.Page) == "string", "beat sends ReportPresence with a page")
		return { expect = function() return reply end }
	end,
}
local stops = {}
local okSession, sessionError = pcall(function()
	check(not Session.isAuthed(), "not authed before hello")
	local waited = 0
	Session.whenAuthed(function() waited += 1 end)
	local stop = Session.startSession({ Request = fakeRequest })
	table.insert(stops, stop)
	check(waitUntil(function() return Session.isAuthed() end, 2), "hello then beat authenticates")
	check(hellos == 1 and beats >= 1, "one hello, then numbered beats")
	check(waited == 1, "auth waiters run once authed")
	Session.whenAuthed(function() waited += 1 end)
	check(waited == 2, "whenAuthed runs at once when already authed")
	local payload = Session.attachGrantFields({})
	local grantOk = Gate:CheckGrant(player, payload.Gen, payload.N, false)
	check(grantOk == true, "attached grant fields pass SessionGate.CheckGrant")
	check(type(payload.TxnId) == "string" and #payload.TxnId > 0 and #payload.TxnId <= 40, "txn id attached")
	check(Session.attachGrantFields({ TxnId = "keep" }).TxnId == "keep", "caller txn id kept")
	check(Session.attachGrantFields({ TxnId = "" }).TxnId ~= "", "empty txn id replaced")
	local before = Session.attachGrantFields({})
	Session.adopt({ Gen = before.Gen - 1, N = "older" })
	Session.adopt({ Gen = before.Gen + 5 })
	local after = Session.attachGrantFields({})
	check(after.Gen == before.Gen and after.N == before.N, "adopt ignores older generations and missing nonces")
	stop()

	-- a restarted session must survive the previous session's late cleanup
	failNext = 1000
	local stopA = Session.startSession({ Request = fakeRequest })
	local stopB = Session.startSession({ Request = fakeRequest })
	table.insert(stops, stopA)
	table.insert(stops, stopB)
	stopA()
	local mark = calls
	task.wait(2.4)
	check(calls > mark, "old session cleanup does not stop its replacement")
	stopB()
	task.wait(0.1)
	mark = calls
	task.wait(2.4)
	check(calls == mark, "stopping the live session stops beats")
	failNext = 0
end)
-- a live beat worker would keep Lune running forever, so always stop every session
for i = #stops, 1, -1 do stops[i]() end
check(okSession, "session checks ran: " .. tostring(sessionError))

---------------------------------------------------------------- ActionRequest latch
-- lua.ts pulls in @rbxts/react, which the harness does not load; truthy is all ActionRequest uses
H.mock("Client/AstralForge/lua", { truthy = function(v) return v ~= nil and v ~= false end })
local ActionRequest = H.load("Client/AstralForge/ActionRequest")
local function scheduler()
	local jobs = {}
	return jobs, function(seconds, fn) table.insert(jobs, { seconds = seconds, fn = fn }) end
end
do
	local jobs, schedule = scheduler()
	local pending, changes = {}, 0
	local req = ActionRequest(function(action, payload, finish) table.insert(pending, { action = action, payload = payload, finish = finish }) end, schedule, function() changes += 1 end)
	local replies = {}
	check(req.run("A", nil, function(r) table.insert(replies, r) end), "first run starts")
	check(type(pending[1].payload) == "table", "nil payload becomes a table")
	check(req.busy and not req.run("B", {}), "busy latch refuses a second run")
	pending[1].finish({ ok = true, message = "Yay" })
	check(not req.busy and req.status == "Yay" and replies[1].ok == true, "reply clears the latch")
	jobs[1].fn()
	check(#replies == 1, "a timeout after the reply is ignored")
	check(req.run("C", {}, function(r) table.insert(replies, r) end), "runs again after reply")
	jobs[2].fn()
	check(not req.busy and replies[2].ok == false, "timeout releases the latch with a failure")
	pending[2].finish({ ok = true })
	check(#replies == 2, "a late reply after the timeout is ignored")
	req.run("D", {}, function(r) table.insert(replies, r) end)
	pending[3].finish("junk")
	check(replies[3].ok == false and req.status ~= "", "non-table reply is a failure")
	req.dispose()
	check(not req.run("E", {}), "disposed request refuses")
	local thrower = ActionRequest(function() error("net down") end, schedule, function() end)
	local got
	thrower.run("F", {}, function(r) got = r end)
	check(got and got.ok == false and not thrower.busy, "dispatch error fails cleanly")
	check(changes >= 4, "changed fires on start and finish")
end

---------------------------------------------------------------- PurchaseQueue
local PurchaseQueue = H.load("Client/AstralForge/PurchaseQueue")
do
	local jobs, schedule = scheduler()
	local sent = {}
	local q = PurchaseQueue(function(action, payload, reply) table.insert(sent, { payload = payload, reply = reply }) end, schedule, function() end)
	check(not q.start("Buy", {}), "empty order list refused")
	local orders = { { Id = "a", Amount = 1 }, { Id = "b", Amount = 2 }, { Id = "c", Amount = 3 } }
	check(q.start("Buy", orders) and q.busy and q.total == 3, "queue starts")
	check(not q.start("Buy", orders), "busy queue refuses a second start")
	check(#sent == 1 and sent[1].payload.Id == "a", "one order in flight at a time")
	sent[1].reply({ ok = true })
	check(q.completed == 1 and #sent == 1, "next order waits for the spacing delay")
	jobs[#jobs].fn()
	check(#sent == 2 and sent[2].payload.Id == "b" and sent[2].payload.Amount == 2, "second order sent")
	sent[2].reply({ ok = true })
	jobs[#jobs].fn()
	sent[3].reply({ ok = true })
	jobs[#jobs].fn()
	check(not q.busy and q.completed == 3 and q.status:find("3"), "all orders bought")
	-- failure stops, timeout pauses, cancel drops late replies
	q.start("Buy", orders)
	sent[4].reply({ ok = false })
	check(not q.busy and q.completed == 0, "a refused order stops the queue")
	q.start("Buy", orders)
	local timeout = jobs[#jobs]
	timeout.fn()
	check(not q.busy and q.status:find("Paused"), "timeout pauses the queue")
	sent[5].reply({ ok = true })
	check(q.completed == 0, "late reply after timeout ignored")
	q.start("Buy", orders)
	q.cancel()
	sent[6].reply({ ok = true })
	check(not q.busy and q.completed == 0, "cancel drops the in-flight reply")
	local thrower = PurchaseQueue(function() error("net down") end, schedule, function() end)
	thrower.start("Buy", orders)
	check(not thrower.busy and thrower.status:find("interrupted"), "dispatch error stops the queue")
end

if #failures > 0 then
	error("client controllers failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] client controllers: %d checks (network reconnect, session, request policy, action latch, purchase queue) passed", checks))
