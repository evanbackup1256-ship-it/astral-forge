--!nocheck
-- Localization groundwork: every routed string comes back exactly as the shipped copy, the
-- formatted keys produce the same text as the concatenations they replaced, and the routed copy
-- no longer appears as a literal in the server files. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local fs = require("@lune/fs")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local Locale = H.load("Shared/AstralForge/Shared/Locale")
local count = 0
for key, copy in Locale.EN do
	count += 1
	check(type(copy) == "string" and #copy > 0, key .. " has copy")
	if not string.find(copy, "%", 1, true) then
		check(Locale.T(key) == copy, key .. " returns its copy unchanged")
	end
end
check(count >= 40, "table holds the routed strings (" .. count .. ")")

-- formatted keys match the old concatenations byte for byte
local name, odd = "Nova", "100%Fun"
check(Locale.T("Toast.VisitorLeftBody", name) == name .. " headed home.", "visitor left")
check(Locale.T("Toast.VisitorArrivedBody", odd) == odd .. " is checking out your shop.", "a % in a name is passed through")
check(Locale.T("Toast.TradeInviteBody", name) == name .. " wants to trade. Open Trade to accept.", "trade invite")
check(Locale.T("Toast.TradeAwayBody", name) == name .. " stepped away from the table.", "trade away")
check(Locale.T("Toast.TradeBackBody", name) == name .. " is back at the table.", "trade back")
check(Locale.T("Toast.TradeCancelledBody", name) == name .. " closed the table.", "trade cancelled")
check(Locale.T("Toast.LeaderboardClimbBody", 3, "Flux") == "You're #3 in Flux now.", "leaderboard climb")
check(Locale.T("Toast.FreeSpinsBody", tostring(2), tostring(5)) == "2 spins added (5 ready).", "free spins")

-- routed copy is no longer hard-coded at the use sites
local files = {
	"src/Server/AstralForge/Services/DataService.ts",
	"src/Server/AstralForge/Services/GameService.ts",
	"src/Server/AstralForge/Runtime/ServerLifecycle.ts",
	"src/Server/AstralForge/Services/Security/Security.ts",
	"src/Server/AstralForge/Services/Security/RemoteFirewall.ts",
}
for _, path in files do
	local text = fs.readFile(path)
	for key, copy in Locale.EN do
		if not string.find(copy, "%", 1, true) and #copy > 16 then
			check(not string.find(text, '"' .. copy .. '"', 1, true), path .. " still hard-codes " .. key)
		end
	end
end

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("locale failed: %d problems", #failures))
end
print(string.format("[TEST] locale: %d checks (%d keyed strings, unchanged copy, formatted keys, no leftover literals) passed", checks, count))
