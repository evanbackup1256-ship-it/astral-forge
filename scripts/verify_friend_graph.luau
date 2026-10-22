--!nocheck
-- FriendGraph (friends bonus): each pair asked once and cached, failures count as not friends
-- and retry sooner, counts are per player, sweep and forget trim the cache. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local M = H.load("Server/AstralForge/Modules/FriendGraph")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local now, calls, down = 0, 0, false
local pairsSet = { ["1:2"] = true, ["2:3"] = true }
local graph = M.FriendGraph.new({
	ttl = 300, failTtl = 20,
	clock = function() return now end,
	isFriends = function(a, b)
		calls += 1
		if down then error("web down") end
		check(a < b, "asked lower id first")
		return pairsSet[a .. ":" .. b] == true
	end,
})

local counts = graph:count({ 3, 1, 2, 4 })
check(counts[1] == 1 and counts[2] == 2 and counts[3] == 1 and counts[4] == 0, "friend counts per player")
check(calls == 6, "4 players ask 6 pairs (" .. calls .. ")")
graph:count({ 1, 2, 3, 4 })
check(calls == 6, "cached answers are reused")
check(graph:friends(2, 1) and not graph:friends(1, 1), "symmetric, and nobody is their own friend")

now = 301
down = true
check(not graph:friends(1, 2), "a failed check counts as not friends")
local before = calls
now = 310
graph:friends(1, 2)
check(calls == before, "a failure is cached briefly")
now = 322
down = false
check(graph:friends(1, 2), "and retried after failTtl")

graph:forget(2)
check(graph:size() == 3, "forget drops a player's pairs (" .. graph:size() .. " left)")
now = 10000
graph:sweep()
check(graph:size() == 0, "sweep drops expired answers")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("friend graph failed: %d problems", #failures))
end
print(string.format("[TEST] friend graph: %d checks passed", checks))
