--!strict
-- Offline gates for DataService busy-window production catch-up, Guild ClaimGoal,
-- and residual SessionGate txn / TradeSettle cancel markers.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local guildSrc = fs.readFile("src/Server/AstralForge/Services/GuildService.luau")
local gateSrc = fs.readFile("src/Server/AstralForge/Services/SessionGate.luau")
local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

------------------------------------------------------------------------
-- DataService busy-window (production catch-up while AtomicUpdate holds)
------------------------------------------------------------------------
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService:IsBusy must exist")
assert(string.find(dataSrc, "atom:IsBusy()", 1, true), "IsBusy must consult atom busy state")
assert(string.find(servicesSrc, "self._data:IsBusy(player)", 1, true), "production tick must consult IsBusy")
assert(
	string.find(servicesSrc, "long AtomicUpdate busy windows let ProductionAccumulator", 1, true),
	"busy-window evidence comment must stay"
)
assert(
	string.find(servicesSrc, "maxCatchUp = GameConfig.Game.ProductionTick * 4", 1, true),
	"busy window must cap ProductionAccumulator catch-up"
)
assert(string.find(configSrc, "ProductionTick", 1, true), "GameConfig.Game.ProductionTick missing")

------------------------------------------------------------------------
-- Guild ClaimGoal (double-claim + contribution gate)
------------------------------------------------------------------------
assert(string.find(guildSrc, "function GuildService:ClaimGoal", 1, true), "GuildService:ClaimGoal must exist")
assert(string.find(guildSrc, "goal.Claimed[userKey] = true", 1, true), "ClaimGoal must stamp Claimed inside UpdateAsync")
assert(string.find(guildSrc, "You already claimed this goal.", 1, true), "ClaimGoal must refuse double-claim")
assert(
	string.find(guildSrc, "MinContributionForReward", 1, true),
	"ClaimGoal must enforce MinContributionForReward"
)
assert(
	string.find(configSrc, "MinContributionForReward", 1, true),
	"GameConfig.Guild.Goal.MinContributionForReward missing"
)
assert(
	string.find(guildSrc, "Only members who helped with this goal can claim it.", 1, true),
	"ClaimGoal must refuse zero-contribution claims"
)

------------------------------------------------------------------------
-- Residual txn markers (SessionGate ring + TradeSettle cancel residual)
------------------------------------------------------------------------
assert(string.find(gateSrc, "function SessionGate:TxnClaim", 1, true), "TxnClaim must exist")
assert(string.find(gateSrc, "function SessionGate:TxnStore", 1, true), "TxnStore must exist")
assert(string.find(gateSrc, "function SessionGate:TxnRelease", 1, true), "TxnRelease must exist")
assert(string.find(gateSrc, "TXN_RING", 1, true), "txn ring must bound residual txn bags")
assert(string.find(gateSrc, "txns = {}", 1, true), "_get must allocate txns bag")
assert(string.find(gateSrc, "txnOrder = {}", 1, true), "_get must allocate txnOrder bag")

assert(string.find(settleSrc, "function TradeSettle.CancelBlocked", 1, true), "CancelBlocked must exist")
assert(
	string.find(settleSrc, 'session.Status = "RevertFailed"', 1, true)
		or string.find(settleSrc, "RevertFailed", 1, true),
	"TradeSettle must own RevertFailed residual status"
)
-- Pure residual: cancel after RevertFailed must clear; cancel while Settling must refuse.
local TradeSettle = require("../src/Server/AstralForge/Modules/TradeSettle")
do
	local settling = { Settling = true, Status = "Settling" }
	local blocked, err = TradeSettle.CancelBlocked(settling)
	assert(blocked == true and type(err) == "string", "cancel during Settling must refuse")
	local residual = { Settling = false, Status = "RevertFailed", RevertFailedReason = "guest-apply-failed" }
	blocked = TradeSettle.CancelBlocked(residual)
	assert(blocked == false, "cancel after RevertFailed must clear residual desk")
end

------------------------------------------------------------------------
-- HARD constraints
------------------------------------------------------------------------
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in { dataSrc, servicesSrc, guildSrc, gateSrc, settleSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] busy-window + Guild claim + residual txn gates passed")
