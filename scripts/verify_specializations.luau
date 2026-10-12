local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Specializations = require("../src/Shared/AstralForge/Shared/Specializations")
local Omega = require("../src/Shared/AstralForge/Shared/OmegaMath")
local members = require("./_memberfs")(fs)
local Envelope = luau.load(members.readFile("src/Server/AstralForge/Modules/EconomyMath.luau#EconomyEnvelopeMath"))()
local function near(actual, expected) assert(math.abs(actual - expected) < 1e-8, tostring(actual) .. " ~= " .. tostring(expected)) end
local original = { GridUpgrades = { Furnace_01 = 5 }, Cash = "1e405" }
local default = Specializations.Sanitize(nil)
assert(default.Focus == "Balanced" and default.ChangedAt == 0)
for _, kind in { "Production", "Capacity", "Tap", "Offline" } do assert(Specializations.Factor(nil, kind) == 1) end
local state = assert(Specializations.Select(nil, "Handcraft", 1000))
near(Specializations.Factor(state, "Production"), .85)
near(Specializations.Factor(state, "Tap"), 1.3)
assert(not Specializations.Select(state, "Reserve", 1599))
assert(Specializations.Select(state, "Handcraft", 1001), "same build does not restart the cooldown")
local respec = assert(Specializations.Select(state, "Reserve", 1600))
assert(respec.ChangedAt == 1600 and respec.Focus == "Reserve")
assert(not Specializations.Select(nil, {}, 1000))
assert(not Specializations.Select(nil, "unknown", 1000))
assert(original.GridUpgrades.Furnace_01 == 5 and original.Cash == "1e405", "selection cannot mutate legacy purchases or economy")
Specializations.Configure(2, .1, 0)
near(Specializations.Policy().Gain, 1.5); near(Specializations.Policy().Cost, .5)
assert(Specializations.Policy().Cooldown == 60)
near(Specializations.Factor(state, "Tap"), 1.3)
near(Specializations.Factor(state, "Production"), .85)
assert(Specializations.Sanitize(state).Gain == 1.3, "live updates must not reprice an equipped build or shrink its vault")
Specializations.Configure(nil, nil, nil)
local source = members.readFile("src/Server/AstralForge/Modules/EconomyMath.luau#Economy")
local env = setmetatable({
	Specializations = Specializations, OmegaMath = Omega, EconomyEnvelopeMath = Envelope,
	Economy = { Production = function(p) return Omega.Mul(100, Specializations.Factor(p.Specialization, "Production")) end },
	GameConfig = { Economy = { BaseOfflineEfficiency = .5 }, Domain = { OfflineEfficiencyPerRank = 0 } },
	researchLevel = function() return 0 end,
}, { __index = _G })
for _, name in { "GridEffect", "EchoEffect", "ArtifactEffect", "ItemEffect", "AnomalyEffect", "ForgePathEffect" } do env.Economy[name] = function() return 0 end end
env.Economy.ContinuumEffects = function() return 1, 1, 1, 0 end
local start = assert(source:find("function Economy.OfflineEfficiency", 1, true))
local finish = assert(source:find("function Economy.OfflineEarnings", start, true))
luau.load(source:sub(start, finish-1), { environment = env })()
near(env.Economy.OfflineEfficiency({}), .5)
near(env.Economy.OfflineEfficiency({ Specialization = { Focus = "NightShift" } }), .65)
env.GameConfig.Economy.BaseOfflineEfficiency = 1
near(env.Economy.OfflineEfficiency({}), 1)
near(env.Economy.OfflineEfficiency({ Specialization = { Focus = "NightShift" } }), 1)
local tap = require("../src/Server/AstralForge/Modules/EconomyMath")("TapCritProjection")
env.TapCritProjection = tap
env.Economy.LabPowerEffect = function() return 0 end
env.Economy.OreEffect = function() return 0 end
start = assert(source:find("function Economy.TapPower", 1, true))
finish = assert(source:find("function Economy.CriticalChance", start, true))
luau.load(source:sub(start, finish-1), { environment = env })()
near(Omega.ToNumber(env.Economy.TapPower({})), 15)
near(Omega.ToNumber(env.Economy.TapPower({ Specialization = state })), 15 * .85 * 1.3)
near(Omega.ToNumber(env.Economy.TapPower({ Specialization = respec })), 15 * .85)
assert(Envelope.GridEffect(original.GridUpgrades, { Furnace_01 = { EffectKind = "GridProduction", EffectPerLevel = .02 } }, "GridProduction") == .1)
env.CapacityProjection = require("../src/Shared/AstralForge/Shared/SharedData")("CapacityProjection")
env.GameConfig.Zones = { { Multiplier = 1 } }
env.GameConfig.Economy.BaseCapacity = 1000
env.GameConfig.Economy.BaseCapacitySeconds = 60
env.GameConfig.Economy.CapacitySecondsPerLevel = 10
env.GameConfig.Economy.MaxCapacitySeconds = 12000
env.GameConfig.Boosts = {}
env.Economy.RawProduction = function(p) return p.RawOutput or 100 end
env.Economy.GetZone = function() return { Multiplier = 1 } end
env.Economy.PassBonuses = function() return 0, 0 end
env.Economy.PermanentMultiplier = function() return 1 end
env.Economy.MasteryMultiplier = function() return 1 end
env.Economy.AnomalySurgeMultiplier = function() return 1 end
env.Economy.CodexBonus = function() return 0 end
env.Economy.DomainTreeBonus = function() return 0 end
env.GameConfig.Domain.CapacityPerRank = 0
start = assert(source:find("function Economy.Production", 1, true))
finish = assert(source:find("local function researchLevel", start, true))
luau.load(source:sub(start, finish-1), { environment = env })()
local function sample(specialization, output)
	return { Research = {}, GridUpgrades = {}, CurrentZone = 1, Specialization = specialization, RawOutput = output }
end
local balanced = sample(nil)
near(Omega.ToNumber(env.Economy.Production(balanced)), 100)
near(Omega.ToNumber(env.Economy.SteadyProduction(balanced)), 100)
near(Omega.ToNumber(env.Economy.Capacity(balanced)), 6000)
local handcrafted = sample(state)
near(Omega.ToNumber(env.Economy.Production(handcrafted)), 85)
near(Omega.ToNumber(env.Economy.SteadyProduction(handcrafted)), 85)
near(Omega.ToNumber(env.Economy.Capacity(handcrafted)), 5100)
near(Omega.ToNumber(env.Economy.Capacity(sample(respec))), 7800)
env.Economy.GridEffect = function(p, kind)
	return Envelope.GridEffect(p.GridUpgrades, { Furnace_01 = { EffectKind = "GridProduction", EffectPerLevel = .02 } }, kind)
end
local legacy = sample(nil); legacy.GridUpgrades.Furnace_01 = 5
near(Omega.ToNumber(env.Economy.Production(legacy)), 110)
legacy.Specialization = state
near(Omega.ToNumber(env.Economy.Production(legacy)), 93.5)
assert(legacy.GridUpgrades.Furnace_01 == 5, "build changes retain exact legacy levels")
local high = env.Economy.Production(sample(state, "1e405"))
assert(Omega.Gte(high, "8.5e404") and Omega.Gte("8.5e404", high), "build modifiers preserve high-value Omega output")
local cache = {}
local snapshotProfile = sample(respec)
snapshotProfile.GridUpgrades.Furnace_01 = 5
local firstSnapshot = Specializations.Snapshot(snapshotProfile, env.Economy, 1700, cache)
assert(firstSnapshot.Focus == "Reserve" and #firstSnapshot.Builds == 4 and #firstSnapshot.Foundation == 1)
for _, build in firstSnapshot.Builds do
	local preview = table.clone(snapshotProfile)
	preview.Specialization = { Focus = build.Id, Gain = 1.3, Cost = .85 }
	assert(Omega.Gte(build.Capacity, env.Economy.Capacity(preview)) and Omega.Gte(env.Economy.Capacity(preview), build.Capacity))
	assert(Omega.Gte(build.Tap, env.Economy.TapPower(preview)) and Omega.Gte(env.Economy.TapPower(preview), build.Tap))
	near(build.Offline, env.Economy.OfflineEfficiency(preview))
end
assert(Specializations.Snapshot(snapshotProfile, env.Economy, 1700, cache) == firstSnapshot, "unchanged same-second snapshots reuse previews")
assert(Specializations.Snapshot(snapshotProfile, env.Economy, 1701, cache) ~= firstSnapshot, "time-dependent hidden effects cannot leave cached previews stale")
snapshotProfile.Specialization = assert(Specializations.Select(nil, "NightShift", 1700))
env.GameConfig.Economy.BaseOfflineEfficiency = .8
local capped = Specializations.Snapshot(snapshotProfile, env.Economy, 1800, cache)
near(capped.Offline, 1); near(capped.Builds[1].Offline, .8)
env.GameConfig.Economy.BaseOfflineEfficiency = .9
local recapped = Specializations.Snapshot(snapshotProfile, env.Economy, 1801, cache)
near(recapped.Offline, 1); near(recapped.Builds[1].Offline, .9)
cache.SpecializationPreviewKey = nil
assert(Specializations.Snapshot(snapshotProfile, env.Economy, 1801, cache) ~= recapped, "successful mutations explicitly invalidate same-second previews")
Specializations.Configure(1.5, .5, 600)
local tuned = Specializations.Snapshot(snapshotProfile, env.Economy, 1801, cache)
near(tuned.Builds[2].GainMultiplier, 1.5)
near(tuned.Builds[4].GainMultiplier, 1.3)
Specializations.Configure(nil, nil, nil)
env.GameConfig.Economy.BaseOfflineEfficiency = 1
local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(router:find('SpecializationsView = "PagesSpecializations"',1,true) and not router:find('lazyView("StarGridView"',1,true))
assert(fs.readFile("src/Server/AstralForge/Services/ServerServices.luau"):find('serviceFactories["SpecializationService"]',1,true))
local Atomic = require("../src/Server/AstralForge/Services/SecurityServices")("AtomicState")()
local serde = require("@lune/serde")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local branch = assert(server:find("elseif action == Protocol.Actions.SelectSpecialization then", 1, true))
local branchEnd = assert(server:find("\n\t\telseif action == Protocol.Actions.SetMarketFavorite", branch, true))
local body = server:sub(assert(server:find("\n\t\t\treturn", branch, true)), branchEnd - 1)
local clock = 2000
local atom = Atomic.new({ Vault = 6000, RawOutput = 100, Research = {}, GridUpgrades = { Furnace_01 = 5 }, Cash = "1e405" })
local owner = {
	_mutate = function(_, _, callback)
		local ok, result = atom:Transact(callback)
		return if ok then result else { ok = false, error = tostring(result) }
	end,
}
env.Economy.Gt = function(a, b) return Omega.Gt(a, b) end
local selectEnvironment = setmetatable({
	Specializations = Specializations, Economy = env.Economy, os = { time = function() return clock end },
	responseError = function(message) return { ok = false, error = message } end,
	responseSuccess = function(message) return { ok = true, message = message } end,
}, { __index = _G })
local dispatch = luau.load("return function(self, player, payload)" .. body .. "\nend", { environment = selectEnvironment })()
local before = atom:Read()
local encoded = serde.encode("json", before)
assert(not dispatch(owner, {}, { Id = "Handcraft" }).ok, "smaller vault must reject rather than delete stored flux")
local after, revision = atom:Read()
assert(after == before and revision == 0 and serde.encode("json", after) == encoded, "rejected build rolls back exact profile")
assert(dispatch(owner, {}, { Id = "Reserve" }).ok)
after = atom:Read()
assert(after.Specialization.Focus == "Reserve" and after.Vault == 6000 and after.Cash == "1e405" and after.GridUpgrades.Furnace_01 == 5)
assert(dispatch(owner, {}, { Id = "Reserve" }).ok, "same-build retry is conclusive")
assert(not dispatch(owner, {}, { Id = "Balanced" }).ok, "cooldown is authoritative")
Specializations.Configure(1.5, .5, 600)
after = atom:Read()
near(Specializations.Factor(Specializations.Sanitize(after.Specialization), "Capacity"), 1.3)
clock += 600
assert(dispatch(owner, {}, { Id = "Balanced" }).ok)
assert(dispatch(owner, {}, { Id = "Balanced" }).ok)
Specializations.Configure(nil, nil, nil)
local overfull = Atomic.new({ Vault = "1e405", Research = {}, Specialization = state })
local overfullOwner = { _mutate = function(_, _, callback) local _, result = overfull:Transact(callback); return result end }
assert(dispatch(overfullOwner, {}, { Id = "Handcraft" }).ok, "retry of an equipped build cannot be trapped by a pre-existing overfull vault")
local failedOwner = { _mutate = function()
	return { ok = false, error = "Profile unavailable" }
end }
assert(not dispatch(failedOwner, {}, { Id = "Reserve" }).ok)

local client = fs.readFile("src/Client/AstralForge/pages/PagesSpecializations.luau")
local requestStart = assert(client:find("local function selectBuild(id: string)", 1, true))
local requestEnd = assert(client:find('\n\tif not state then', requestStart, true))
local function mount(order)
	local calls, timers, notes = {}, {}, {}
	local context = setmetatable({
		unresolved = order, pending = { current = false }, live = { current = true },
		serial = { current = 0 }, timeout = { current = nil }, setBusy = function() end,
		setNote = function(note) table.insert(notes, note) end,
		props = { dispatch = function(action, payload, callback) table.insert(calls, { action = action, payload = payload, callback = callback }) end },
		task = {
			delay = function(_, callback) local timer = { callback = callback }; table.insert(timers, timer); return timer end,
			cancel = function(timer) timer.cancelled = true end,
		},
	}, { __index = _G })
	local send, current = luau.load(client:sub(requestStart, requestEnd - 1) .. "\nreturn selectBuild, function() return unresolved end", { environment = context })()
	return send, current, calls, timers, context
end
local send, current, calls, timers, context = mount(nil)
send("Reserve"); send("Handcraft")
assert(#calls == 1 and calls[1].payload.Id == "Reserve", "double input sends one build")
calls[1].callback({ ok = false, Uncertain = true })
assert(current().Id == "Reserve")
send("Handcraft")
assert(calls[2].payload == calls[1].payload, "uncertainty retries exactly the previous build")
timers[2].callback()
send("Balanced")
assert(calls[3].payload == calls[1].payload)
calls[2].callback({ ok = true })
assert(context.pending.current, "late reply cannot clear a newer request latch")
calls[3].callback({ ok = true })
assert(current() == nil and not context.pending.current)
send, current, calls, timers, context = mount({ Id = "Reserve" })
send("Balanced")
assert(calls[1].payload.Id == "Reserve", "reopening resolves previous build before another selection")
context.live.current = false
calls[1].callback({ ok = false, error = "Cooldown" })
assert(current() == nil, "conclusive response clears retry after unmount")
print("Specializations verification passed: neutral legacy behavior, distinct build trade-offs, respec bounds, frozen live rates, exact production/steady/vault/tap/offline formulas and Omega values.")
print("Specialization transaction/client verification passed: actual atomic dispatch, full-vault rollback, same-build retry, cooldown, frozen rejoin rates, transport uncertainty, remount and late response isolation.")
