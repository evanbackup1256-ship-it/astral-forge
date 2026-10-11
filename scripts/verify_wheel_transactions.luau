local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Omega = require("../src/Shared/AstralForge/Shared/OmegaMath")
local WheelMath = require("../src/Server/AstralForge/Modules/EconomyMath")("WheelMath")
local Atomic = require("../src/Server/AstralForge/Services/SecurityServices")("AtomicState")()
local rewards = {}
for index = 1, 20 do
	rewards[index] = { Id = "prize" .. index, Name = "Prize " .. index, Rarity = if index == 20 then "RARE" else "COMMON",
		Weight = 1, Reward = { Stardust = index } }
end
local Economy = table.clone(Omega)
Economy.Production = function() return 100 end
local progression = {}
local config = { Wheel = { Rewards = rewards, CooldownSeconds = 21600, PityAfter = 8, PityRarity = "RARE" } }
local env = setmetatable({
	ProgressionService = progression, Economy = Economy, GameConfig = config, WheelMath = WheelMath,
	Format = { Number = tostring },
	ensureWheel = function(profile) profile.Wheel = WheelMath.Ensure(profile.Wheel); return profile.Wheel end,
}, { __index = _G })
local source = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau")
local start = assert(source:find("function ProgressionService.ApplyReward", 1, true))
local finish = assert(source:find("function ProgressionService.EnsureQuests", start, true))
luau.load(source:sub(start, finish - 1), { environment = env })()
start = assert(source:find("function ProgressionService.SpinWheel", 1, true))
finish = assert(source:find("function ProgressionService.EnsureTimedRewards", start, true))
luau.load(source:sub(start, finish - 1), { environment = env })()
local rolls = 0
local rng = { NextNumber = function(_, _, maximum) rolls += 1; return maximum * .01 end }
local atom = Atomic.new({ Stardust = 0, Wheel = { FreeSpins = 3 } })
local function spin(expected)
	local committed, result = atom:Transact(function(profile)
		local ok, message, index, id, pity = progression.SpinWheel(profile, rng, expected)
		return { ok = ok, message = message, PrizeIndex = index, PrizeId = id, Pity = pity }
	end)
	assert(committed, tostring(result))
	return result
end
assert(not spin(-1).ok and not spin(0.5).ok and not spin(math.huge).ok)
local first = spin(0)
assert(first.ok and first.PrizeId == "prize1")
local saved = atom:Read()
assert(saved.Wheel.FreeSpins == 2 and saved.Wheel.Spins == 1 and saved.Stardust == 1)
local rollsAfterFirst = rolls
assert(spin(0).ok, "same request replays receipt")
assert(rolls == rollsAfterFirst, "receipt replay cannot redraw a prize")
saved = atom:Read()
assert(saved.Wheel.FreeSpins == 2 and saved.Stardust == 1, "repeated/simultaneous request cannot spend another token or grant twice")
saved = serde.decode("json", serde.encode("json", saved))
saved.Wheel = WheelMath.Ensure(saved.Wheel)
local ok, message, index = progression.SpinWheel(saved, rng, 0)
assert(ok and index == first.PrizeIndex and saved.Stardust == 1 and saved.Wheel.FreeSpins == 2, "copied/sanitized rejoin receipt replays")
assert(rolls == rollsAfterFirst, "rejoin receipt cannot redraw a prize")
assert(WheelMath.Snapshot(os.time(), saved.Wheel, 21600, 8).LastReceipt.PrizeId == first.PrizeId)
assert(spin(1).ok)
assert(not spin(0).ok, "old receipt outside latest spin cannot become a new purchase")
assert(not spin(99).ok)
local broken = { Stardust = 1e50, Wheel = { FreeSpins = 2 } }
local failed = Atomic.new(broken)
local committed = failed:Transact(function(profile)
	local granted, detail = progression.SpinWheel(profile, rng, 0)
	return { ok = granted, message = detail }
end)
local retained, revision = failed:Read()
assert(not committed and retained == broken and revision == 0 and retained.Wheel.FreeSpins == 2,
	"failed actual reward must roll back token, counter, pity and receipt")
local pityProfile = { Stardust = 0, Wheel = { FreeSpins = 1, PityMisses = 7 } }
local granted, _, pityIndex, _, pity = progression.SpinWheel(pityProfile, rng, 0)
assert(granted and pity and pityIndex == 20 and pityProfile.Wheel.PityMisses == 0)
local malformed = WheelMath.Ensure({ Spins = 1, LastReceipt = { ExpectedSpin = 0, PrizeIndex = 1, PrizeId = "prize1", Message = "saved", Pity = false } })
assert(malformed.LastReceipt)
malformed.LastReceipt.ExpectedSpin = 2
assert(WheelMath.Ensure(malformed).LastReceipt == nil)
local freeReward = rewards[1].Reward
rewards[1].Reward = { FreeSpins = 2 }
local freeProfile = { Wheel = { FreeSpins = 1 } }
assert(progression.SpinWheel(freeProfile, rng, 0))
assert(freeProfile.Wheel.FreeSpins == 2 and freeProfile.Wheel.LastReceipt.ExpectedSpin == 0,
	"free-spin reward bag reconstruction preserves receipt")
assert(progression.SpinWheel(freeProfile, rng, 0) and freeProfile.Wheel.FreeSpins == 2)
rewards[1].Reward = freeReward
local cooldown = { Stardust = 0, Wheel = { LastSpinAt = os.time(), FreeSpins = 0 } }
assert(not progression.SpinWheel(cooldown, rng, 0), "cooldown still blocks a fresh spin")
local daily = { Stardust = 0, Wheel = { LastSpinAt = 0, FreeSpins = 0 } }
assert(progression.SpinWheel(daily, rng, 0))
assert(progression.SpinWheel(daily, rng, 0) and not progression.SpinWheel(daily, rng, 1),
	"saved cooldown spin replays but fresh cooldown spin rejects")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(server:find("self._random, payload.ExpectedSpin", 1, true))
assert(fs.readFile("src/Server/AstralForge/Services/DataService.luau"):find("profile.Wheel = WheelMath.Ensure(profile.Wheel)", 1, true))
assert(fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau"):find('"ExpectedSpin", 0, 1e12 - 1, true', 1, true))

local client = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau")
assert(not client:find("local function FlatPrizeWheel", 1, true) and not client:find("buildSpinningWheel", 1, true)
	and not client:find("WheelPrizeViewport", 1, true), "all alternate wheel renderers and viewport dependencies retire")
start = assert(client:find("local WHEEL_OMEGA =", 1, true))
finish = assert(client:find("local function PrizeWheelMachine", start, true))
local callbacks, timers, effects, setterValues = {}, {}, {}, {}
local React = {
	useState = function(value)
		return value, function(nextValue) table.insert(setterValues, nextValue) end
	end,
	useBinding = function(value) return { value = value }, function() end end,
	useRef = function(value) return { current = value } end,
	useCallback = function(callback) return callback end,
	useEffect = function(callback) table.insert(effects, callback) end,
}
local clientEnv = setmetatable({
	React = React, useAntilag = function() return { tier = 3, fxBudget = 1 } end,
	Audio = { play = function() end }, InteractionFeedback = { tap = function() end, reward = function() end },
	task = {
		delay = function(_, callback) local timer = { callback = callback }; table.insert(timers, timer); return timer end,
		cancel = function(timer) timer.cancelled = true end,
	},
}, { __index = _G })
local mount, pending = luau.load(client:sub(start, finish - 1) .. "\nreturn useWheelController, function() return unresolvedSpin end",
	{ environment = clientEnv })()
local props = {
	state = { Wheel = { CanSpin = true, Spins = 0 } }, config = config, reducedMotion = true,
	dispatch = function(action, payload, callback)
		table.insert(callbacks, { action = action, payload = payload, callback = callback })
	end,
}
local controller = mount(props)
controller.spin(); controller.spin()
assert(#callbacks == 1 and callbacks[1].payload.ExpectedSpin == 0)
callbacks[1].callback({ ok = false, Uncertain = true })
props.state.Wheel = { CanSpin = false, Spins = 1 }
effects = {}
local reopened = mount(props)
assert(reopened.retry, "interrupted order survives page reopen")
reopened.spin()
assert(callbacks[2].payload == callbacks[1].payload and callbacks[2].payload.ExpectedSpin == 0,
	"reopen retry ignores newer counters and cannot start a second spin")
timers[2].callback()
reopened.spin()
assert(callbacks[3].payload == callbacks[2].payload, "timeout retry retains original sequence")
callbacks[2].callback({ ok = true, PrizeIndex = 1, PrizeId = "prize1", message = "saved" })
assert(pending() == nil, "late authoritative response resolves the old order")
local beforeCalls = #callbacks
reopened.spin()
assert(#callbacks == beforeCalls, "late response cannot release newer input latch")
callbacks[3].callback({ ok = true, PrizeIndex = 1, PrizeId = "prize1", message = "saved" })
assert(pending() == nil)
props.state.Wheel.LastReceipt = { PrizeId = "prize20", PrizeIndex = 20 }
local restored = mount(props)
assert(restored.winner == 19 and restored.phase == "landed", "rejoin restores original result by prize identity")
props.state.Wheel.CanSpin = true
controller = mount(props)
controller.spin()
for _, effect in effects do
	local cleanup = effect()
	if cleanup then cleanup() end
end
callbacks[#callbacks].callback({ ok = true, PrizeId = "prize1", PrizeIndex = 1 })
assert(pending() == nil, "conclusive reply clears retained order after unmount")
effects = {}
props.state.Wheel = { CanSpin = true, Spins = 2 }
controller = mount(props)
controller.spin()
callbacks[#callbacks].callback({ ok = true, PrizeId = "prize20", PrizeIndex = 1 })
assert(setterValues[#setterValues] == "Your reward was saved, but its artwork is unavailable. Reopen the wheel to refresh.",
	"mismatched index/id cannot fabricate a winner")
effects = {}
props.state.Wheel = { CanSpin = false, Spins = 3, LastReceipt = { ExpectedSpin = 2, PrizeId = "prize1", PrizeIndex = 1 } }
mount(props)
for _, effect in effects do effect() end
assert(setterValues[#setterValues] == "landed", "arriving saved receipt silently restores a reopened wheel")
print("[TEST] wheel transactions: actual reward/token/pity rollback, sequence replay/rejoin, stale request rejection, saved result, double input, uncertain transport, remount and late response isolation passed")
