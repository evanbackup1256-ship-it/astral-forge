--!strict
-- Wave25 offline residuals: Leaderboards FocusClaim, CrateRevealStage softMotion,
-- DV21 Story/Mail briefs, release-readiness past checks=30.

local fs = require("@lune/fs")

local CANON = "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"
-- CrateRevealStage uses props.reducedMotion as the left-hand of the canon gate.
local STAGE_CANON = "local softMotion = props.reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"

local boards = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
assert(string.find(boards, CANON, 1, true), "Leaderboards softMotion canon")
assert(string.find(boards, 'Name = "LeaderboardConfirm"', 1, true), "LeaderboardConfirm host")
assert(string.find(boards, 'Name = "LeaderboardConfirmFilters"', 1, true), "LeaderboardConfirmFilters")
do
	local hostStart = string.find(boards, 'Name = "LeaderboardConfirm"', 1, true)
	assert(hostStart, "LeaderboardConfirm missing")
	local hostSlice = string.sub(boards, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "LeaderboardConfirm clips")
end
assert(string.find(boards, "GamepadNavigationService.FocusClaim", 1, true), "Leaderboards FocusClaim")

local stage = fs.readFile("src/Client/AstralForge/pages/CrateRevealStage.luau")
assert(string.find(stage, STAGE_CANON, 1, true), "CrateRevealStage softMotion canon")
assert(string.find(stage, "reducedMotion = softMotion", 1, true) or string.find(stage, "local reducedMotion = softMotion", 1, true), "Stage folds softMotion")
assert(string.find(stage, 'Name = "CrateClaim"', 1, true), "Stage CrateClaim host")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave24-offline-brief"', 1, true), "Story wave24")
assert(string.find(config, 'Id = "wave25-offline-brief"', 1, true), "Story wave25")
assert(string.find(config, 'Id = "update-5-1-wave24-offline"', 1, true), "Mail wave24")
assert(string.find(config, 'Id = "update-5-1-wave25-offline"', 1, true), "Mail wave25")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")
assert(not string.find(config, "DataVersion = 22", 1, true), "must not bump DV")

print("[INFO] [TEST] wave25 harden residuals passed")
