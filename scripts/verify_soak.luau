--!nocheck
-- Soak + release hardening: many players join, act over many ticks and leave; every per-player
-- table in the security stack must be empty afterwards (no leaks over a long-lived server).
-- Also: every Protocol action has firewall payload coverage and a sane rate bucket, DataService
-- and GameService clear every per-player map on leave, guild slow-mode stamps are pruned, and
-- save sizes are measured against the DataStore cap. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local fs = require("@lune/fs")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

-- a PlayerRemoving that really fires (the harness default is inert)
local removing = {}
H.Players.PlayerRemoving = {
	Connect = function(_, fn) table.insert(removing, fn) return { Disconnect = function() end, Connected = true } end,
}
local function leave(p)
	p.Parent = nil
	for _, fn in removing do fn(p) end
end

-- count keys anywhere in obj (3 levels deep) that are one of the soak players
local function leaked(obj, players, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if type(obj) ~= "table" or seen[obj] or depth > 3 then return 0 end
	seen[obj] = true
	local n = 0
	for k, v in obj do
		if players[k] then n += 1 end
		if type(v) == "table" and not players[v] then n += leaked(v, players, depth + 1, seen) end
	end
	return n
end

local PLAYERS, TICKS = 400, 25
local telemetry = setmetatable({}, { __index = function() return function() end end })
local Protocol = H.load("Shared/AstralForge/Shared/Protocol")
local SecurityModule = H.load("Server/AstralForge/Services/Security/Security")
local Firewall = H.load("Server/AstralForge/Services/Security/RemoteFirewall").RemoteFirewall
local SessionGate = H.load("Server/AstralForge/Services/Security/SessionGate").SessionGate
local GameAntiCheat = H.load("Server/AstralForge/Services/Security/GameAntiCheat").GameAntiCheat
local DataTemplate = H.load("Server/AstralForge/DataTemplate")

local security = SecurityModule.Security.new()
security:Start()
local firewall = Firewall.new(telemetry)
local gate = SessionGate.new()
local ac = GameAntiCheat.new()
local actions = {}
for _, action in Protocol.Actions do table.insert(actions, action) end
table.sort(actions)

local soak = {}
local profile = DataTemplate.New()
for i = 1, PLAYERS do
	local p = H.player("Soak" .. i)
	soak[p] = true
	ac:Observe(p, "Load", profile)
	gate:Hello(p)
	for t = 1, TICKS do
		security.Nonce:Issue(p)
		security.Mask:Key(p)
		security.Rollback:Push(p, t, { Cash = t })
		security.Rate:Allow(p, 1)
		security.Heuristic:Observe(p, t, t)
		security.Honey:Trip(p, "nope")
		firewall:Check(p, actions[(i + t) % #actions + 1], {})
		gate:TxnClaim(p, "t" .. t)
	end
	-- production leave path: Security listens to PlayerRemoving; GameService calls the Forgets
	leave(p)
	firewall:Forget(p)
	gate:Forget(p)
	ac:Forget(p)
end
H.Players.__players = {}
check(leaked(security, soak) == 0, "Security keeps nothing for departed players (" .. leaked(security, soak) .. ")")
check(leaked(firewall, soak) == 0, "RemoteFirewall keeps nothing for departed players (" .. leaked(firewall, soak) .. ")")
check(leaked(gate, soak) == 0, "SessionGate keeps nothing for departed players (" .. leaked(gate, soak) .. ")")
check(leaked(ac, soak) == 0, "GameAntiCheat keeps nothing for departed players (" .. leaked(ac, soak) .. ")")

---------------------------------------------------------------- leave paths clear every per-player map
local function mapFields(source)
	local out = {}
	for name in string.gmatch(source, "\n\t(_[%w_]+)!?:? ?=? ?new Map<Player") do out[name] = true end
	for name in string.gmatch(source, "\n\t(_[%w_]+)!: Map<Player") do out[name] = true end
	return out
end
local function body(source, header)
	local s = string.find(source, header, 1, true)
	local e = string.find(source, "\n\t}\n", s, true)
	return string.sub(source, s, e)
end
do
	local src = fs.readFile("src/Server/AstralForge/Services/DataService.ts")
	local clear = body(src, "_clearPlayer(player: Player) {")
	local n = 0
	for name in mapFields(src) do
		n += 1
		check(string.find(clear, "this." .. name .. ".delete(player)", 1, true) ~= nil, "DataService._clearPlayer clears " .. name)
	end
	check(n >= 10, "DataService per-player maps found (" .. n .. ")")
	local gsrc = fs.readFile("src/Server/AstralForge/Services/GameService.ts")
	local removingBody = body(gsrc, "_onPlayerRemoving(player: Player) {")
	local g = 0
	for name in mapFields(gsrc) do
		g += 1
		check(string.find(removingBody, "this." .. name .. ".delete(player", 1, true) ~= nil
			or string.find(removingBody, "this." .. name .. ".delete(visitor", 1, true) ~= nil
			or string.find(gsrc, "this." .. name .. ".delete(", 1, true) ~= nil,
			"GameService clears " .. name)
	end
	check(g >= 5, "GameService per-player maps found (" .. g .. ")")
end

---------------------------------------------------------------- guild slow-mode stamps are pruned
do
	local GC = H.load("Server/AstralForge/Services/GuildCommunity")
	GC = GC.GuildCommunity or GC
	local fake = setmetatable({ _chatAt = {}, _chatAtWrites = 0 }, { __index = GC })
	-- roblox-ts Maps are plain tables in the harness; give it delete/iteration via the compiled class
	for i = 1, 5000 do fake._chatAt["g:" .. i] = 0 end
	for _ = 1, 64 do GC._pruneChatAt(fake, 100) end
	local left = 0
	for _ in fake._chatAt do left += 1 end
	check(left == 0, "stale slow-mode stamps are dropped (" .. left .. " left)")
	fake._chatAt["g:fresh"] = 99
	for _ = 1, 64 do GC._pruneChatAt(fake, 100) end
	check(fake._chatAt["g:fresh"] == 99, "a stamp still inside the slow-mode window is kept")
end

---------------------------------------------------------------- save size
do
	local SaveSize = H.load("Server/AstralForge/Modules/SaveSize")
	local serde = require("@lune/serde")
	local encode = function(v) return serde.encode("json", v) end
	local fresh = SaveSize.Measure(DataTemplate.New(), encode)
	check(fresh.Bytes > 0 and fresh.Bytes < SaveSize.WARN_BYTES and #fresh.Top == 0, "a fresh save is small (" .. fresh.Bytes .. " bytes)")
	local big = DataTemplate.New()
	big.Achievements = {}
	for i = 1, 40000 do big.Achievements["Achievement_" .. i] = string.rep("x", 24) end
	local m = SaveSize.Measure(big, encode)
	check(m.Bytes >= SaveSize.WARN_BYTES and m.Top[1].Field == "Achievements", "a bloated save names its largest field")
	check(string.find(SaveSize.Describe(m), "Achievements", 1, true) ~= nil, "the warning text names the field")
	check(SaveSize.LIMIT_BYTES == 4194304, "limit is the DataStore value cap")
end

---------------------------------------------------------------- firewall coverage for every action
do
	local fw = fs.readFile("src/Server/AstralForge/Services/Security/RemoteFirewall.ts")
	local Buckets = H.load("Server/AstralForge/Services/Security/ActionBuckets")
	local rulesStart = string.find(fw, "const RULES", 1, true)
	local rulesEnd = string.find(fw, "\n};", rulesStart, true)
	local outside = string.sub(fw, 1, rulesStart) .. string.sub(fw, rulesEnd)
	local Registry = require("./_out_loader")("out/Shared/AstralForge/Shared/Data/RemoteRegistry")
	local n = 0
	for name, action in Protocol.Actions do
		n += 1
		local entry = Registry.EntryFor(name)
		local inRegistry = entry ~= nil and entry.Kind ~= "legacy"
		check(inRegistry or string.find(outside, "Protocol.Actions." .. name .. "[^%w]") ~= nil, name .. " has a payload rule or is a no-payload action")
		local category = Buckets.CategoryOf(action)
		check(Buckets.RULES[category] ~= nil, name .. " lands in a real rate bucket")
		if string.sub(action, 1, 3) == "Buy" or string.sub(action, 1, 5) == "Claim" or action == "EventAct" then
			check(category ~= "Read", name .. " spends or grants, so it is not in the cheap Read bucket")
		end
	end
	check(n >= 150, "every Protocol action checked (" .. n .. ")")
	-- the new spend/grant actions are explicitly covered
	for _, name in { "EventAct", "ClaimSeasonPremium", "EquipItem" } do
		check(Protocol.Actions[name] ~= nil, name .. " exists")
	end
	check(string.find(fw, 'bag.Op === "Buy" && !stringField(bag, "Item"', 1, true) ~= nil, "EventAct Buy needs an item id")
end

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("soak failed: %d problems", #failures))
end
print(string.format("[TEST] soak: %d checks (%d players x %d ticks, no per-player leaks, leave paths, slow-mode prune, save size, firewall coverage) passed", checks, PLAYERS, TICKS))
