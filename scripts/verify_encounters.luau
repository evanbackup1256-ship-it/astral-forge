local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Encounters = require("../src/Shared/AstralForge/Shared/Encounters")
assert(fs.readFile("src/Server/AstralForge/Services/ServerServices.luau"):find('serviceFactories["EncounterService"]', 1, true), "encounters must be registered in the real service loader")
local SharedData = require("../src/Shared/AstralForge/Shared/SharedData")
local Omega = require("../src/Shared/AstralForge/Shared/OmegaMath")
local Atomic = require("../src/Server/AstralForge/Services/SecurityServices")("AtomicState")()
local env = setmetatable({ Color3 = roblox.Color3, require = function(module) return module end }, { __index = _G })
local shared = { SharedData = SharedData, Encounters = Encounters }
local function wait(parent, name) return assert(parent[name], name) end
shared.WaitForChild = wait
env.script = { Parent = shared }
for _, name in { "CrateExpansion", "GameConfigGenerated", "GameConfig" } do
	shared[name] = luau.load(fs.readFile("src/Shared/AstralForge/Shared/" .. name .. ".luau"), { environment = env })()
end
for id, rule in shared.GameConfig.Unlocks do
	assert(type(rule.Target) == "number" and type(rule.Kind) == "string", "all unlocks must have an initialized gate: " .. id)
end
local progression = {}
env.GameConfig, env.ProgressionService, env.Economy, env.Format = shared.GameConfig, progression, Omega, { Number = tostring }
local source = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau")
local first = assert(source:find("function ProgressionService.ApplyReward", 1, true))
local last = assert(source:find("function ProgressionService.EnsureQuests", first, true))
luau.load(source:sub(first, last - 1), { environment = env })()
local settings = { SalvageDailyLimit = 3, EncounterStardustUnit = 4 }
local refresh
local snapshot = {
	GetValue = function(_, key) return settings[key] end, Refresh = function() end,
	UpdateAvailable = { Connect = function(_, callback) refresh = callback end },
}
local sequence = 0
env.script = { Parent = { Parent = { WaitForChild = wait, ModuleLog = { Warn = function(_, message) error(message) end } } } }
env.game = { GetService = function(_, name)
	if name == "ReplicatedStorage" then return { WaitForChild = wait, AstralForge = { WaitForChild = wait, Shared = shared } } end
	if name == "HttpService" then return { GenerateGUID = function() sequence += 1; return string.format("encounter-%08d", sequence) end } end
	if name == "ConfigService" then return { GetConfigAsync = function() return snapshot end } end
	error(name)
end }
env.task = { defer = function(callback) callback() end }
local service = luau.load(fs.readFile("src/Server/AstralForge/Services/EncounterService.luau"), { environment = env })()(function(name)
	assert(name == "ProgressionService"); return progression
end)
local function profile()
	return { Zone = 6, Stardust = 0, Cash = "1e405", Command = { Artifacts = {
		SolarLens = { Level = 1, Fragments = 0 }, PulsarCoil = { Level = 1, Fragments = 0 },
	} } }
end
local requests = 0
local function begin(p, mode, site, artifact, now)
	requests += 1
	local payload = { Mode = mode, Site = site, Artifact = artifact, RequestId = string.format("request-%08d", requests) }
	local ok, message = service.Begin(p, payload, now or 86400)
	assert(ok, message)
	return payload
end
local function choose(p, id)
	local run = assert(p.Encounters.Active)
	local payload = { RunId = run.Id, Step = run.Step, Choice = id }
	local ok, message = service.Choose(p, payload)
	assert(ok, message)
	return payload
end
local p = profile()
local start = begin(p, "Salvage", "Freighter", "")
local activeId = p.Encounters.Active.Id
assert(service.Begin(p, start, 86400) and p.Encounters.Used == 1 and p.Encounters.Active.Id == activeId)
local invalid = table.clone(start); invalid.Artifact = "NotOwned"
assert(not service.Begin(p, invalid, 86400))
assert(not service.Choose(p, { RunId = activeId, Step = 3, Choice = "Rescue" }))
assert(not service.Choose(p, { RunId = activeId, Step = 1, Choice = "Rack" }))
local one = choose(p, "Beacon")
local after = serde.encode("json", p)
assert(service.Choose(p, one) and serde.encode("json", p) == after, "saved turn replay changes nothing")
one.Choice = "Power"; assert(not service.Choose(p, one))
p.Encounters = Encounters.Sanitize(p.Encounters)
choose(p, "Case")
local final = choose(p, "Rescue")
assert(p.Stardust == 16 and p.Encounters.Active == nil and #p.Encounters.History == 1)
after = serde.encode("json", p)
for _ = 1, 10 do assert(service.Choose(p, final)); assert(serde.encode("json", p) == after) end
assert(service.Begin(p, start, 86400) and serde.encode("json", p) == after, "completed begin replay cannot start a second run")
for _ = 1, 2 do
	begin(p, "Salvage", "Freighter", "")
	choose(p, "Power"); choose(p, "Hold"); choose(p, "Rack")
	assert(p.Encounters.History[1].Passed == false, "excess strain forces extraction")
end
assert(p.Stardust == 24 and p.Cash == "1e405", "bounded dust rewards never coerce flux")
assert(not service.Begin(p, { Mode = "Salvage", Site = "Freighter", Artifact = "", RequestId = "fourth-order" }, 86400))
assert(service.State(p, 86400).Remaining == 0 and service.State(p, 172800).Remaining == 3)
begin(p, "Salvage", "Foundry", "SolarLens", 172800)
choose(p, "Hoist"); choose(p, "Brace"); choose(p, "Tools")
assert(p.Encounters.History[1].Passed and p.Encounters.History[1].Stardust == 24)
local low = profile(); low.Zone = 1
assert(not service.Begin(low, { Mode = "Salvage", Site = "Foundry", Artifact = "", RequestId = "locked-site" }, 86400))
assert(not service.Begin(low, { Mode = "Trial", Site = "", Artifact = "", RequestId = "missing-companion" }, 86400))
assert(not service.Begin(low, { Mode = "Trial", Site = "", Artifact = "CosmicCore", RequestId = "unowned-companion" }, 86400))

local trial = profile()
for success = 1, 12 do
	begin(trial, "Trial", "", "SolarLens")
	choose(trial, "Release"); choose(trial, "Steady"); choose(trial, "Release")
	assert(trial.Encounters.History[1].Passed)
	trial.Encounters = Encounters.Sanitize(trial.Encounters)
	assert(trial.Encounters.Mastery.SolarLens == math.min(success, 7))
end
assert(trial.Stardust == 44 and #trial.Encounters.History == 10, "only 1,3,7 milestones pay, history stays bounded")
begin(trial, "Trial", "", "PulsarCoil")
choose(trial, "Observe"); choose(trial, "Observe"); choose(trial, "Observe")
assert(not trial.Encounters.History[1].Passed and trial.Stardust == 44)
local solutions = {
	Ember = { "Release", "Steady", "Release" }, Current = { "Observe", "Release", "Steady" },
	Growth = { "Observe", "Observe", "Steady" }, Shelter = { "Release", "Steady", "Steady" },
	Shadow = { "Observe", "Release", "Observe" }, Focus = { "Observe", "Steady", "Release" },
}
for family, choices in solutions do
	local run = { Mode = "Trial", Site = "", Step = 4, Family = family, Choices = choices }
	assert(Encounters.Passed(run), "each family rule is achievable: " .. family)
	run.Choices = { "Release", "Release", "Release" }
	assert(not Encounters.Passed(run), "uncontrolled output must fail: " .. family)
end
for _, payload in {
	{ Mode = "Lottery", Site = "", Artifact = "", RequestId = "invalid-mode" },
	{ Mode = "Trial", Site = "", Artifact = {}, RequestId = "invalid-artifact" },
	{ Mode = "Trial", Site = "", Artifact = "", RequestId = string.rep("x", 65) },
} do assert(not Encounters.ValidBegin(payload)) end
for _, step in { 0, 4, 1.5, 0/0, math.huge } do assert(not Encounters.ValidChoice({ RunId = "run-valid-id", Step = step, Choice = "Observe" })) end
assert(Encounters.Sanitize({ Active = { Id = "broken" }, History = { {} }, Mastery = { SolarLens = math.huge } }).Active == nil)

local transaction = profile()
begin(transaction, "Salvage", "Freighter", "")
choose(transaction, "Beacon"); choose(transaction, "Case")
local original = serde.encode("json", transaction)
local atomic = Atomic.new(transaction)
local command = { RunId = transaction.Encounters.Active.Id, Step = 3, Choice = "Rescue" }
local apply = progression.ApplyReward
progression.ApplyReward = function(candidate, reward) apply(candidate, reward); error("injected grant failure") end
local ok = atomic:Transact(function(candidate)
	local granted, message = service.Choose(candidate, command)
	return { ok = granted, error = message }
end)
assert(not ok and serde.encode("json", transaction) == original, "failed grant rolls back choice, mastery, balance and receipt")
progression.ApplyReward = apply
assert(atomic:Transact(function(candidate)
	local granted, message = service.Choose(candidate, command)
	return { ok = granted, error = message }
end))
transaction = atomic:Read()
assert(transaction.Stardust == 16 and #transaction.Encounters.History == 1)
local full = profile()
full.Stardust = 1e50
begin(full, "Trial", "", "SolarLens")
choose(full, "Release"); choose(full, "Steady")
local fullAtomic = Atomic.new(full)
local lastChoice = { RunId = full.Encounters.Active.Id, Step = 3, Choice = "Release" }
local beforeFull = serde.encode("json", full)
local _, rejected = fullAtomic:Transact(function(candidate)
	local granted, message = service.Choose(candidate, lastChoice)
	return { ok = granted, error = message }
end)
assert(not rejected.ok, "capacity must reject: " .. tostring(rejected.error))
local retained, revision = fullAtomic:Read()
assert(retained == full and revision == 0 and serde.encode("json", retained) == beforeFull, "capacity rejection preserves a replayable final choice")
lastChoice.ForfeitReward = true
assert(fullAtomic:Transact(function(candidate)
	local granted, message = service.Choose(candidate, lastChoice)
	return { ok = granted, error = message }
end))
full = fullAtomic:Read()
assert(full.Stardust == 1e50 and full.Encounters.Active == nil and full.Encounters.Mastery.SolarLens == 1)
assert(full.Encounters.History[1].Stardust == 0 and full.Encounters.History[1].Message:find("without stardust", 1, true))
settings.EncounterStardustUnit = 100; settings.SalvageDailyLimit = 12; refresh()
assert(service.State(transaction, 86400).DailyLimit == 12)
assert(transaction.Encounters.History[1].Run.UnitReward == 4, "live balance changes do not reprice an existing run")
print("Encounter verification passed: authored scenes, six trial rules, limits, save/replay, live config and atomic grant rollback.")

local clientSource = fs.readFile("src/Client/AstralForge/pages/PagesEncounters.luau")
local requestStart = assert(clientSource:find("local function request(action, payload)", 1, true))
local requestEnd = assert(clientSource:find("\n\tlocal sections", requestStart, true))
local function mounted(sharedOrder)
	local calls, timers = {}, {}
	local input = { current = false }
	local context = setmetatable({
		unresolved = sharedOrder, pending = input, live = { current = true },
		serial = { current = 0 }, timeout = { current = nil },
		setBusy = function() end, setNote = function() end, setForfeit = function() end,
		props = { dispatch = function(action, payload, callback) table.insert(calls, { action = action, payload = payload, callback = callback }) end },
		task = {
			delay = function(_, callback) local timer = { callback = callback }; table.insert(timers, timer); return timer end,
			cancel = function(timer) timer.cancelled = true end,
		},
	}, { __index = _G })
	local request, order = luau.load(clientSource:sub(requestStart, requestEnd - 1) .. "\nreturn request, function() return unresolved end",
		{ environment = context })()
	return request, order, calls, timers, context
end
local request, order, calls, timers, context = mounted(nil)
local payload = { RunId = "original-run", Step = 1, Choice = "Beacon" }
request("ChooseEncounter", payload); request("ChooseEncounter", payload)
assert(#calls == 1, "double input must not dispatch two choices")
calls[1].callback({ ok = false, Uncertain = true })
request("ChooseEncounter", { RunId = "other-run", Step = 2, Choice = "Case" })
assert(#calls == 2 and calls[2].payload == payload, "uncertain choice retries the identical run, turn and approach")
timers[#timers].callback()
assert(not context.pending.current and order().Payload == payload, "timeout releases input but retains request")
local remount, current, reopened = mounted(order())
remount("BeginEncounter", { RequestId = "different-start" })
assert(#reopened == 1 and reopened[1].payload == payload, "page remount resolves the earlier choice before a new run")
reopened[1].callback({ ok = true, message = "Saved" })
assert(current() == nil, "confirmed remount clears retry")
context.live.current = false
calls[2].callback({ ok = true, message = "Saved" })
assert(order() == nil, "late confirmed reply clears unresolved request even after unmount")
request, order, calls, timers = mounted(nil)
request("ChooseEncounter", payload)
calls[1].callback({ ok = false, error = "Confirmed rejection" })
assert(order() == nil and timers[1].cancelled, "conclusive rejection releases request and timeout")
print("Encounter client verification passed: double input, transport uncertainty, stable retry, page reopen and late completion.")
