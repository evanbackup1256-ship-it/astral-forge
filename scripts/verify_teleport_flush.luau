--!nocheck
-- Teleport save flush (audit follow-up): during a soft shutdown only players whose save session
-- is released are teleported; a still-held profile gets one more release save first, and a
-- player whose release keeps failing (or throws) stays on this server. Run rbxtsc first.
local H = require("./_server_harness")
local Flush = H.load("Server/AstralForge/Runtime/TeleportFlush")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local held = { released = false, late = true, stuck = true, throws = true }
local calls = {}
local deps = {
	held = function(p) return held[p] == true end,
	release = function(p)
		calls[p] = (calls[p] or 0) + 1
		if p == "late" then held.late = false return true end
		if p == "throws" then error("store down") end
		return false
	end,
}
local result = Flush.flushBeforeTeleport({ "released", "late", "stuck", "throws" }, deps)
local function has(list, v) for _, x in list do if x == v then return true end end return false end
check(has(result.ready, "released") and calls.released == nil, "an already-released player teleports without another save")
check(has(result.ready, "late") and calls.late == 1, "a held profile gets one release save, then teleports")
check(has(result.held, "stuck") and not has(result.ready, "stuck"), "a failed release keeps the player here")
check(has(result.held, "throws") and calls.throws == 1, "a throwing release is contained and the player kept")
check(#result.ready + #result.held == 4, "every player is accounted for")
local retry = Flush.flushBeforeTeleport({ "stuck" }, deps, 3)
check(calls.stuck == 4 and #retry.held == 1, "attempts bound the extra release saves")

-- the shutdown wiring uses it with DataService's own held/release
local source = require("@lune/fs").readFile("src/Server/AstralForge/Runtime/ServerLifecycle.ts")
check(source:find("flushBeforeTeleport(Players.GetPlayers()", 1, true) ~= nil, "soft shutdown flushes before teleporting")
check(source:find("TeleportAsync(game.PlaceId, remainingPlayers", 1, true) ~= nil, "only the flushed players are teleported")

if #failures > 0 then error("teleport flush failures:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] teleport flush: %d checks (released, late release, stuck, throwing release, bounded retries, shutdown wiring) passed", checks))
