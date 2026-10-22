--!nocheck
-- Memory on player leave (audit follow-up): DataService._clearPlayer drops every per-player map
-- including the per-user leaderboard mirror (kept only while a push is still in flight), the
-- security ledger forgets a departed player's decayed record but keeps a real one, and a scan of
-- GameService/DataService per-player maps finds each one cleared on leave. Run rbxtsc first.
local H = require("./_server_harness")
local fs = require("@lune/fs")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local DataService = H.load("Server/AstralForge/Services/DataService").DataService
local function size(t) local n = 0 for _ in t do n += 1 end return n end
local PLAYER_MAPS = { "_profiles", "_documents", "_dirty", "_memoryMode", "_previousLastSeen", "_atoms", "_writeGen",
	"_integrityStatus", "_cacheSyncThreads", "_lastCacheSyncAt", "_saveBusy", "_releasing", "_broken" }
local function service()
	local svc = setmetatable({ telemetry = { RecordPlayerLeft = function() end } }, { __index = DataService })
	for _, k in PLAYER_MAPS do svc[k] = {} end
	svc._leaderboardMirrors, svc._leaderboardPending, svc._leaderboardPushBusy, svc._leaderboardWorkers = {}, {}, {}, {}
	return svc
end
do
	local svc = service()
	for i = 1, 200 do
		local p = H.player("P" .. i)
		p.UserId = 9000 + i
		for _, k in PLAYER_MAPS do if k ~= "_cacheSyncThreads" then svc[k][p] = true end end
		svc._leaderboardMirrors[p.UserId] = { Cash = i }
		if i % 10 == 0 then svc._leaderboardWorkers[p.UserId] = true end
		svc:_clearPlayer(p)
	end
	for _, k in PLAYER_MAPS do check(size(svc[k]) == 0, "DataService." .. k .. " is empty after 200 leaves") end
	check(size(svc._leaderboardMirrors) == 20, "leaderboard mirrors kept only for the 20 pushes still in flight")
end

do
	local LedgerModule = H.load("Server/AstralForge/Services/Security/SecurityLedger")
	local now = 0
	local ledger = LedgerModule.SecurityLedger.new(function() return now end, function() return 0 end)
	for i = 1, 300 do ledger:Flag(i, "P" .. i, "probe", 0.5) end
	ledger:Flag(7, "P7", "speed", 40)
	check(ledger:Size() == 300, "300 flagged players recorded")
	now = 3600
	for i = 1, 300 do ledger:ForgetIfQuiet(i) end
	check(ledger:Size() <= 1, "decayed records are dropped when players leave")
	now = 3600
	local fresh = LedgerModule.SecurityLedger.new(function() return now end, function() return 0 end)
	fresh:Flag(1, "A", "speed", 40)
	check(fresh:ForgetIfQuiet(1) == false and fresh:Score(1) > 1, "a real score survives leaving (no wipe by rejoining)")
	check(fresh:ForgetIfQuiet(42) == false, "unknown players are a no-op")
end

-- every Map<Player, ...> field on GameService and DataService is deleted somewhere
for _, path in { "src/Server/AstralForge/Services/GameService.ts", "src/Server/AstralForge/Services/DataService.ts" } do
	local source = fs.readFile(path)
	for name in source:gmatch("\n\t(_[%w_]+)%s*=%s*new Map<Player") do
		check(source:find("this." .. name .. ".delete(", 1, true) ~= nil or source:find("this." .. name .. ".clear(", 1, true) ~= nil,
			path .. ": " .. name .. " is never cleared on leave")
	end
	for name in source:gmatch("\n\t(_[%w_]+)%s*=%s*new Set<Player") do
		check(source:find("this." .. name .. ".delete(", 1, true) ~= nil, path .. ": " .. name .. " is never cleared on leave")
	end
end
local gs = fs.readFile("src/Server/AstralForge/Services/GameService.ts")
check(gs:find("Ledger.ForgetIfQuiet(player.UserId)", 1, true) ~= nil, "GameService forgets quiet ledger records on leave")

if #failures > 0 then error("leave leak failures:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] leave leaks: %d checks (DataService maps, leaderboard mirrors, security ledger records, per-player map scan) passed", checks))
