--!nocheck
-- Weekly Flux board: week boundaries, the saved bag (new, damaged, rolled over, Omega-sized Flux),
-- and the end-of-week payout through GameService (paid once, only the top 100, refused retries).
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local WeeklyBoard = H.load("Shared/AstralForge/Shared/WeeklyBoard")
local WeeklyStores = H.load("Server/AstralForge/Services/WeeklyStores")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local OmegaMath = H.load("Shared/AstralForge/Shared/OmegaMath")

-- Monday 2026-10-19 00:00 UTC
local MONDAY = 1792368000
check(os.date("!%A %H:%M", MONDAY) == "Monday 00:00", "fixture is a Monday")
local week = WeeklyBoard.weekOf(MONDAY)
check(WeeklyBoard.weekOf(MONDAY - 1) == week - 1, "Sunday 23:59:59 is last week")
check(WeeklyBoard.weekOf(MONDAY + 7 * 86400 - 1) == week, "the week runs to the next Monday")
check(WeeklyBoard.weekEndsAt(week) == MONDAY + 7 * 86400, "the week ends on the next Monday")
check(WeeklyBoard.storeName("Base", week) == "Base_W" .. week, "one store per week")

check(WeeklyBoard.tierFor(1).reward.Cores == 25, "#1 tier")
check(WeeklyBoard.tierFor(3).upTo == 3 and WeeklyBoard.tierFor(4).upTo == 10, "tier edges")
check(WeeklyBoard.tierFor(100) ~= nil and WeeklyBoard.tierFor(101) == nil, "only the top 100 are paid")
check(WeeklyBoard.tierFor(0) == nil and WeeklyBoard.tierFor(0 / 0) == nil, "bad ranks aren't paid")
local lastCores = math.huge
for _, tier in WeeklyBoard.TIERS do
	check(tier.reward.Cores < lastCores, "rewards shrink down the board")
	lastCores = tier.reward.Cores
end

-- the saved bag
local profile = DataTemplate.New()
check(type(profile.WeeklyBoard) == "table", "the template carries the bag")
profile.LifetimeCash = 5000
check(WeeklyBoard.ensure(profile, MONDAY + 60) == true, "the first tick starts the week")
check(WeeklyBoard.scoreOf(profile, MONDAY + 60) == 0, "nothing earned yet")
check(WeeklyBoard.ensure(profile, MONDAY + 120) == false, "a second tick changes nothing")
profile.LifetimeCash = 8000
check(WeeklyBoard.scoreOf(profile, MONDAY + 3600) == 3000, "score is Flux since the week started")
check(WeeklyBoard.unpaidWeek(profile, MONDAY + 3600) == nil, "a fresh bag has nothing from before it existed")
check(WeeklyBoard.ensure(profile, MONDAY + 7 * 86400 + 5) == true, "the next week rolls the bag")
check(WeeklyBoard.scoreOf(profile, MONDAY + 7 * 86400 + 5) == 0, "a new week starts at zero")
check(WeeklyBoard.unpaidWeek(profile, MONDAY + 7 * 86400 + 5) == week, "last week is now payable")
check(WeeklyBoard.scoreOf(profile, MONDAY + 14 * 86400) == 0, "a stale bag scores zero until it rolls")

local damaged = { LifetimeCash = 900, WeeklyBoard = { Week = "x", Base = {}, ClaimedWeek = -3 } }
check(WeeklyBoard.ensure(damaged, MONDAY) == true and damaged.WeeklyBoard.Base == 900 and damaged.WeeklyBoard.Week == week, "a damaged bag is rebuilt")
check(WeeklyBoard.scoreOf({ LifetimeCash = 10, WeeklyBoard = { Week = week, Base = 50, ClaimedWeek = 0 } }, MONDAY) == 0, "score never goes negative")

local big = { LifetimeCash = OmegaMath.Mul(1e20, 1e20), WeeklyBoard = { Week = week, Base = 0, ClaimedWeek = week - 1 } }
check(OmegaMath.Gt(WeeklyBoard.scoreOf(big, MONDAY), 1e30), "Omega-sized Flux scores")

-- payout through GameService
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local toasts = {}
local function service(p, player)
	local data = { profile = p, updates = 0 }
	function data:AtomicUpdate(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if type(r) == "table" and r.ok == false then return false, r end
		self.profile = draft
		self.updates += 1
		return true, r
	end
	function data:Get() return self.profile end
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true,
		_toastPlayer = function(_, _, title, body) table.insert(toasts, body) end,
		_queueStatePush = function() end,
	}
	return setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end

local realTime = os.time
local now = MONDAY + 7 * 86400 + 30
local winner, other = H.player("Weekly winner"), H.player("Weekly other")
local function lastWeekProfile()
	local p = DataTemplate.New()
	p.WeeklyBoard = { Week = week + 1, Base = 0, ClaimedWeek = week - 1 }
	return p
end

-- ranks not loaded yet: nothing happens
WeeklyStores.ResetForTests()
local s, data = service(lastWeekProfile(), winner)
local ok = pcall(function() s:_payWeeklyBoard(winner) end)
check(ok, "a payout before ranks load doesn't error")

WeeklyStores.SetRanksForTests(week, { [winner.UserId] = 1 })
local thisWeek = WeeklyBoard.weekOf(os.time())
if thisWeek == week + 1 then
	local cores = data.profile.Cores
	s:_payWeeklyBoard(winner)
	check(data.profile.WeeklyBoard.ClaimedWeek == week, "the winner's week is marked paid")
	check(data.profile.Cores == cores + 25, "#1 gets 25 Cores")
	check(#toasts == 1, "the winner hears about it")
	s:_payWeeklyBoard(winner)
	check(data.profile.Cores == cores + 25 and data.updates == 1, "a week is only paid once")
	local s2, data2 = service(lastWeekProfile(), other)
	local before = data2.profile.Cores
	s2:_payWeeklyBoard(other)
	check(data2.profile.WeeklyBoard.ClaimedWeek == week and data2.profile.Cores == before, "outside the top 100: marked, not paid")
	check(#toasts == 1, "no toast without a reward")
else
	-- the payout reads the real clock; build the fixture around whatever week it is now
	local live = thisWeek - 1
	WeeklyStores.SetRanksForTests(live, { [winner.UserId] = 7 })
	local p = DataTemplate.New()
	p.WeeklyBoard = { Week = thisWeek, Base = 0, ClaimedWeek = live - 1 }
	local s3, data3 = service(p, winner)
	local cores = data3.profile.Cores
	s3:_payWeeklyBoard(winner)
	check(data3.profile.WeeklyBoard.ClaimedWeek == live, "the winner's week is marked paid")
	check(data3.profile.Cores == cores + 12, "#7 gets 12 Cores")
	s3:_payWeeklyBoard(winner)
	check(data3.profile.Cores == cores + 12 and data3.updates == 1, "a week is only paid once")
	local p2 = DataTemplate.New()
	p2.WeeklyBoard = { Week = thisWeek, Base = 0, ClaimedWeek = live - 1 }
	local s4, data4 = service(p2, other)
	local before = data4.profile.Cores
	s4:_payWeeklyBoard(other)
	check(data4.profile.WeeklyBoard.ClaimedWeek == live and data4.profile.Cores == before, "outside the top 100: marked, not paid")
end
WeeklyStores.ResetForTests()

-- the server player list carries the weekly score, so the board's "this server" tab can rank it
do
	local PublicPlayerRecord = H.load("Server/AstralForge/Modules/ProfileMath")("PublicPlayerRecord")
	local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
	local p = DataTemplate.New()
	p.LifetimeCash = 7500
	p.WeeklyBoard = { Week = WeeklyBoard.weekOf(os.time()), Base = 2500, ClaimedWeek = 0 }
	local listed = H.player("Listed")
	local record = PublicPlayerRecord.Build(listed, p, listed, {}, { Economy = Economy })
	check(type(record.Boards) == "table" and record.Boards.Weekly == 5000, "the player list carries this week's Flux")
end

if #failures > 0 then
	error("weekly board failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] weekly board: %d checks (week edges, bag rollover, Omega scores, one payout per week) passed", checks))
