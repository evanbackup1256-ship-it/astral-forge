--!nocheck
-- LeaderboardService: one store read per board per TTL, a new cache key (next week) reads again,
-- failed reads keep the last page and back off, live players override stored rows, ranking is
-- high-to-low with UserId ties. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local M = H.load("Server/AstralForge/Modules/LeaderboardService")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local now = 0
local board = M.LeaderboardService.new({
	pageSize = 25, pageTtl = 60, retryAfter = 30,
	decode = function(raw) return raw / 10 end,
	greater = function(a, b) return a > b end,
	clock = function() return now end,
})

local reads, failing = 0, false
local function reader(size)
	reads += 1
	if failing then error("store down") end
	return { { key = "1", value = 100 }, { key = "2", value = 50 }, { key = "bad", value = 1 } }
end

local rows = board:stored("Flux", "Flux", reader)
check(reads == 1 and rows[1] == 10 and rows[2] == 5, "first request reads and decodes the page")
local size = 0 for _ in rows do size += 1 end
check(size == 2, "non-numeric keys are skipped")
now = 30
board:stored("Flux", "Flux", reader)
check(reads == 1, "a second request inside the TTL is served from cache")
board:stored("Flux", "Flux2", reader)
check(reads == 2, "a new cache key (next week's store) reads again")

now = 100
failing = true
local stale = board:stored("Flux", "Flux2", reader)
check(reads == 3 and stale[1] == 10, "a failed read keeps the last good page")
now = 110
board:stored("Flux", "Flux2", reader)
check(reads == 3, "after a failure the board backs off")
now = 131
board:stored("Flux", "Flux2", reader)
check(reads == 4, "it retries once the backoff passes")

local fresh = M.LeaderboardService.new({ pageSize = 5, pageTtl = 60, retryAfter = 30, decode = function(v) return v end, greater = function(a, b) return a > b end, clock = function() return now end })
fresh:stored("X", "X", function() error("down") end)
check(fresh:unavailable("X"), "a board that never read is unavailable")

local storedRows = { [1] = 10, [2] = 5, [3] = 0 }
local live = { [2] = 40, [4] = 10 }
local function toMap(t) local m = {} for k, v in t do m[k] = v end return m end
local ranked = board:rank(toMap(storedRows), toMap(live), function(v) return v > 0 end)
check(#ranked == 3, "zero values are dropped (" .. #ranked .. ")")
check(ranked[1].UserId == 2 and ranked[1].Value == 40, "live values override the store")
check(ranked[2].UserId == 1 and ranked[3].UserId == 4, "ties rank by UserId")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("leaderboard service failed: %d problems", #failures))
end
print(string.format("[TEST] leaderboard service: %d checks passed", checks))
