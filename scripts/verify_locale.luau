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
check(count >= 600, "table holds the routed strings (" .. count .. ")")

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

-- every call site passes exactly as many arguments as its copy has placeholders, every key is
-- used, and routed copy is not still hard-coded anywhere in the server/shared sources
local function listTs(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			listTs(path, out)
		elseif string.sub(name, -3) == ".ts" and not string.find(path, "Locale.ts", 1, true) then
			table.insert(out, path)
		end
	end
	return out
end
local sources = listTs("src/Shared", listTs("src/Server", {}))

-- count top-level arguments after the key in T("key", ...) starting at the opening paren
local function argCount(text, open)
	local depth, count, i, quote = 0, 0, open, nil
	while i <= #text do
		local c = string.sub(text, i, i)
		if quote then
			if c == "\\" then i += 1 elseif c == quote then quote = nil end
		elseif c == '"' or c == "'" or c == "`" then
			quote = c
		elseif c == "(" or c == "{" or c == "[" then
			depth += 1
		elseif c == ")" or c == "}" or c == "]" then
			depth -= 1
			if depth == 0 then return count end
		elseif c == "," and depth == 1 and not string.match(text, "^,%s*%)", i) then
			count += 1
		end
		i += 1
	end
	return -1
end
local function placeholders(copy)
	local n = 0
	for spec in string.gmatch(string.gsub(copy, "%%%%", ""), "%%[%-%d%.]*[sdif]") do n += 1 end
	return n
end

local used, sites = {}, 0
for _, path in sources do
	local text = fs.readFile(path)
	local from = 1
	while true do
		local s, e, key = string.find(text, '[^%w_]T%("([%w%.]+)"', from)
		if not s then break end
		sites += 1
		used[key] = true
		local copy = Locale.EN[key]
		if copy == nil then
			check(false, path .. " uses missing key " .. key)
		else
			local args = argCount(text, s + 2)
			check(args == placeholders(copy), string.format("%s: %s passes %d args for %d placeholders", path, key, args, placeholders(copy)))
		end
		from = e + 1
	end
	for key, copy in Locale.EN do
		if not string.find(copy, "%", 1, true) and #copy > 16 then
			check(not string.find(text, '"' .. copy .. '"', 1, true), path .. " still hard-codes " .. key)
		end
	end
end
for key in Locale.EN do
	check(used[key] == true, key .. " is used somewhere")
end
check(sites >= 600, "call sites routed (" .. sites .. ")")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("locale failed: %d problems", #failures))
end
print(string.format("[TEST] locale: %d checks (%d keyed strings, %d call sites, args match placeholders, no unused keys, no leftover literals) passed", checks, count, sites))
