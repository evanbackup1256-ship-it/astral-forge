--!strict
-- Evidence: selectable server-priced route choices are committed and snapshotted on launch.
local fs = require("./_memberfs")(require("@lune/fs"))
local ExpeditionPlanMath = require("../src/Server/AstralForge/Modules/ExpeditionPlanMath")
local CommandMath = require("../src/Server/AstralForge/Modules/CommandMath")

local plans = {
	Standard = {
		Name = "Direct route",
		Description = "Balanced.",
		SignalCost = 0,
		DurationScale = 1,
		RewardScale = 1,
		ArtifactChanceBonus = 0,
	},
	Charted = {
		Name = "Charted route",
		Description = "Safer.",
		SignalCost = 10,
		DurationScale = 1.1,
		RewardScale = 1.05,
		ArtifactChanceBonus = 0.12,
	},
	Salvage = {
		Name = "Salvage route",
		Description = "More resources.",
		SignalCost = 18,
		DurationScale = 1.25,
		RewardScale = 1.35,
		ArtifactChanceBonus = -0.08,
	},
}

assert(ExpeditionPlanMath.Resolve(plans, "Standard") == plans.Standard, "resolve free route")
assert(ExpeditionPlanMath.Resolve(plans, "Missing") == nil, "reject unknown route")
assert(ExpeditionPlanMath.Resolve({ Broken = { SignalCost = -1 } }, "Broken") == nil, "reject invalid config")

local canCommit, cost, remaining = ExpeditionPlanMath.Quote(20, plans.Salvage)
assert(canCommit and cost == 18 and remaining == 2, "quote affordable route")
local cannotCommit, shortCost, noNegativeBalance = ExpeditionPlanMath.Quote(17, plans.Salvage)
assert(not cannotCommit and shortCost == 18 and noNegativeBalance == 0, "reject underfunded route")
assert(not ExpeditionPlanMath.Quote(0 / 0, plans.Charted), "reject corrupt wallet")

assert(ExpeditionPlanMath.Duration(100, 1, plans.Standard) == 100, "baseline duration")
assert(ExpeditionPlanMath.Duration(100, 2, plans.Charted) == 104, "pilot and plan duration compose")
assert(ExpeditionPlanMath.Duration(100, 1, plans.Salvage) == 125, "salvage route takes longer")

local snapshot = ExpeditionPlanMath.Snapshot("Salvage", plans.Salvage)
local migrated = ExpeditionPlanMath.MigrateSnapshot(snapshot)
assert(migrated.Id == "Salvage" and migrated.SignalCost == 18, "persist route identity and commitment")
assert(migrated.RewardScale == 1.35 and migrated.ArtifactChanceBonus == -0.08, "persist route consequences")
local legacy = ExpeditionPlanMath.MigrateSnapshot(nil)
assert(legacy.Id == "Standard" and legacy.RewardScale == 1 and legacy.SignalCost == 0, "legacy active trips keep standard terms")
local corrupt = ExpeditionPlanMath.MigrateSnapshot({ Id = string.rep("x", 100), RewardScale = 1e100, ArtifactChanceBonus = 1e100 })
assert(corrupt.Id == "Standard" and corrupt.RewardScale == 2 and corrupt.ArtifactChanceBonus == 0.5, "bound corrupted snapshots")

local reward = ExpeditionPlanMath.ScaleReward({
	CashMinutes = 100,
	Stardust = 10,
	Signals = 20,
	CommandXP = 30,
	Cores = 2,
}, 2, plans.Salvage)
assert(reward.CashMinutes == 145 and reward.Stardust == 14 and reward.Signals == 29, "engineer and route resource bonuses")
assert(reward.CommandXP == 40 and reward.Cores == 2, "route scales XP and leaves fixed core rewards intact")
assert(math.abs(ExpeditionPlanMath.ArtifactChance(0.2, 2, plans.Charted) - 0.35) < 1e-9, "charted route improves artifact odds")
assert(math.abs(ExpeditionPlanMath.ArtifactChance(0.2, 1, plans.Salvage) - 0.12) < 1e-9, "salvage carries a clear relic tradeoff")
assert(ExpeditionPlanMath.ArtifactChance(1, 100, plans.Charted) == 0.95, "artifact chance cap")
assert(ExpeditionPlanMath.ArtifactChance(-2, 1, plans.Salvage) == 0, "artifact chance floor")

local normalized = CommandMath.Ensure({
	ActiveExpedition = { Id = "LunarSurvey", StartedAt = 1, EndsAt = 30 },
	ExpeditionPlanVersion = 0 / 0,
}, "DEEP_SPACE_01", 3)
assert(normalized.ActiveExpedition.Plan.Id == "Standard", "old save snapshot migration")
assert(normalized.ExpeditionPlanVersion == 3, "plan schema version migration")
assert(CommandMath.Ensure({ ExpeditionPlanVersion = 7 }, "DEEP_SPACE_01", 3).ExpeditionPlanVersion == 7, "never downgrade a newer save schema")
local bounded = CommandMath.Ensure({ ActiveExpedition = { Plan = { SignalCost = 0 / 0, RewardScale = 0 / 0 } } })
assert(bounded.ActiveExpedition.Plan.SignalCost == 0 and bounded.ActiveExpedition.Plan.RewardScale == 1, "sanitize corrupt stored values")

local progression = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau#ProgressionService")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local page = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau")
local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(progression, "ExpeditionPlanMath.Quote(profile.Command.Signals, routePlan)", 1, true), "server prices selected route")
assert(string.find(progression, "profile.Command.Signals -= signalCost", 1, true), "commit Signals in launch mutation")
assert(string.find(progression, "Plan = ExpeditionPlanMath.Snapshot(selectedPlanId, routePlan)", 1, true), "persist launch terms")
assert(string.find(progression, "ExpeditionPlanMath.MigrateSnapshot(active.Plan)", 1, true), "claim uses saved route terms")
assert(string.find(server, "payload and payload.PlanId", 1, true), "server forwards route choice")
assert(string.find(firewall, 'stringField(payload, "PlanId", 1, 40)', 1, true), "validate route choice payload")
assert(string.find(page, 'value = "EXPEDITION ROUTE PLAN · SIGNALS COMMIT ON LAUNCH"', 1, true), "planner appears before launch")
assert(string.find(page, "PlanId = selectedPlanId", 1, true), "client sends chosen plan")
for _, id in { "Standard", "Charted", "Salvage" } do
	assert(string.find(config, id .. " = {", 1, true), "configured route " .. id)
end

print("[TEST] expedition route planning, costs, saved terms, risk/reward tradeoffs, legacy snapshots and server/client wiring passed")
