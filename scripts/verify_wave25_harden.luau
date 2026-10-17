--!strict
-- Wave25 offline residuals: Leaderboards FocusClaim, CrateRevealStage softMotion,
-- DV21 Story/Mail briefs, release-readiness past checks=30.

local fs = require("./_memberfs")(require("@lune/fs"))

-- CrateRevealStage uses props.reducedMotion as the left-hand of the canon gate.
local STAGE_CANON = "local softMotion = props.reducedMotion == true"

local boards = fs.readFile("src/Client/AstralForge/RankDashboard.luau")
assert(string.find(boards, 'Name="RankDashboard"', 1, true), "Ranks host")
assert(string.find(boards, "ClipsDescendants=false", 1, true), "Ranks host must not clip")
assert(string.find(boards, "if animate and not props.reducedMotion then", 1, true), "Ranks reduced-motion gate")
assert(string.find(boards, "GamepadNavigationService.FocusClaim", 1, true), "Leaderboards FocusClaim")

local stage = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau#CrateRevealStage")
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
