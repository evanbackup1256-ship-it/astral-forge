local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
local OmegaMath = require("../out/Shared/AstralForge/Shared/OmegaMath")
local source = fs.readFile("src/Server/AstralForge/ReleaseReadiness.luau")
local start = assert(string.find(source, "local function finite", 1, true))
local stop = assert(string.find(source, "local function expect", start, true))
local env = setmetatable({ MAX_VALUE = 1e308, OmegaMath = OmegaMath }, { __index = getfenv(0) })
local finite = luau.load(string.sub(source, start, stop - 1) .. "\nreturn finite", { environment = env })()
for _, value in { 0, 1e308, 1.7976931348623157e308, "1.25e2096", "1.778279410039e1885635130883680" } do
	assert(finite(value), "valid persisted currency rejected")
end
for _, value in { math.huge, -math.huge, 0 / 0, "inf", "nan", "", "1e999999999999999999999", "1e4garbage" } do
	assert(not finite(value), "invalid currency accepted")
end
start = assert(string.find(source, "local function simulationStep", 1, true))
stop = assert(string.find(source, "function ReleaseReadiness.RunQuick", start, true))
env.GameConfig = { Machines = { { Id = "QA", MaxLevel = 100 } } }
env.Economy = {
	MachineCost = function() return "1e20" end,
	Production = function() return "1e25" end,
	PrestigeReward = function() return "1e30" end,
}
local step = luau.load(string.sub(source, start, stop - 1) .. "\nreturn simulationStep", { environment = env })()
local profile = { Cash = "1e25", RunCash = "1e25", LifetimeCash = "1e25", Cores = "1e20", Rebirths = 0, Machines = {} }
local random = { NextInteger = function() return 1 end, NextNumber = function(_, low) return if low then 1 else 0 end }
step(profile, random)
assert(profile.Machines.QA == 1 and profile.Rebirths == 1)
assert(profile.Cash == 0 and profile.RunCash == 0)
assert(finite(profile.Cores) and OmegaMath.Gt(profile.Cores, "1e29"))
assert(finite(profile.LifetimeCash) and OmegaMath.Gt(profile.LifetimeCash, "1e25"))
print("[TEST] readiness large-number validation and simulation passed")

-- The real 50k loop must yield between batches so Studio can process input.
start = assert(string.find(source, "function ReleaseReadiness.RunQuick", 1, true))
stop = assert(string.find(source, "function ReleaseReadiness.RunSoak", start, true))
local waits, iterations = 0, 0
env.ReleaseReadiness = {}
env.quickChecks = function() return {} end
env.DataTemplate = { New = function() return { Meta = { Revision = 0 } } end }
env.Random = { new = function() return {} end }
env.simulationStep = function() iterations += 1 end
env.validateProfile = function() end
env.ProfileIntegrity = { Record = function() end, Seal = function() end }
env.task = { wait = function() waits += 1 end }
local quick = luau.load(string.sub(source, start, stop - 1) .. "\nreturn ReleaseReadiness.RunQuick", { environment = env })()
local result = quick()
assert(result.Ok and result.Iterations == 50000 and iterations == 50000)
assert(waits == 50, "quick soak must yield once per thousand actions")
print("[TEST] readiness 50k loop yields between all 50 batches")
