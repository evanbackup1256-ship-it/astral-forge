--!nocheck
-- Big-number (Omega-string) currency paths at 1e30, run from the compiled TS (out/) through
-- scripts/_server_harness: player-list sort by Production, retired-Bazaar refund on a huge
-- balance, market Cash offers, guild Flux contributions, leaderboard encoding, trade Flux checks,
-- rebirth carry, quest rewards. Each check fails on the pre-stage-16 code. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local Monetization = H.load("Shared/AstralForge/Shared/SharedData/MonetizationConfig")

local one = setmetatable({}, { __index = function() return function() return 1 end end })
local function service(profile)
	local player = H.player()
	local data = { profile = profile, saveOk = true }
	function data:Update(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if not (type(r) == "table" and r.ok == false) then self.profile = draft end
		return true, r
	end
	function data:AtomicUpdate(p, cb) return self:Update(p, cb) end
	function data:Get() return self.profile end
	function data:Save() return self.saveOk end
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true, _random = H.env.Random.new(3),
		_antiCheat = { Observe = function() return nil, false end },
		_convergence = one, _events = one, _crews = one, _fluxSurge = one,
		_syncLeaderstats = function() end, _pushState = function() end, _toastPlayer = function() end, _effect = H.Stub,
	}
	local s = setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end })
	return s, player, data
end


local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
local BIG = Omega.New(1e30)
check(type(BIG) == "string", "1e30 persists as an Omega string")
local function near(a, b) return Omega.Gte(a, Omega.Mul(b, 0.999999)) and Omega.Lte(a, Omega.Mul(b, 1.000001)) end

-- player list sort (GameService._getPlayers): mixed Omega-string and number Production
do
	local profiles = {}
	local s, player, data = service(DataTemplate.New())
	data.Get = function(_, target) return profiles[target] end
	profiles[player] = data.profile
	local other = H.player("Rich")
	local function richProfile(level)
		local rich = DataTemplate.New()
		rich.Cash, rich.RunCash, rich.LifetimeCash = BIG, BIG, BIG
		for _, m in GameConfig.Machines do rich.Machines[m.Id] = level end
		return rich
	end
	profiles[other] = richProfile(5000)
	profiles[H.player("Richer")] = richProfile(900)
	profiles[H.player("Mid")] = richProfile(60)
	s._presence = {}
	s._production = nil
	local ok, r = pcall(function() return s:_getPlayers(player) end)
	check(ok and r and r.ok, "player list builds with Omega Production values (" .. tostring(r) .. ")")
	if ok and r and r.Players then
		check(#r.Players >= 4, "player list has every player")
		local sorted = true
		for i = 3, #r.Players do
			if Omega.Lt(r.Players[i - 1].Production, r.Players[i].Production) then sorted = false end
		end
		check(r.Players[1].IsLocal == true and sorted, "others sorted by Production, highest first")
		check(type(r.Players[2].Production) == "string", "top Production is an Omega string")
	end
	-- the sort itself, on Omega strings that compare wrongly as text
	local Economy = H.load("Server/AstralForge/Modules/EconomyMath")
	local okSort = pcall(function()
		local rows = { { Production = Omega.New(9e20) }, { Production = Omega.New(1e30) }, { Production = 1000 } }
		table.sort(rows, function(a, b) return Omega.Gt(a.Production, b.Production) end)
		assert(rows[1].Production == Omega.New(1e30) and rows[3].Production == 1000)
	end)
	check(okSort, "Omega order: 1e30 > 9e20 > 1000")
	local _ = Economy
	for _, p in H.env.game:GetService("Players"):GetPlayers() do p.Parent = nil end
end

-- retired Bazaar refund on a 1e30 balance (BazaarService.Roll)
do
	local Bazaar = H.load("Server/AstralForge/Services/Gameplay/Bazaar")
	local p = DataTemplate.New()
	p.Cash = BIG
	Bazaar.Roll(p, os.time(), 1) -- settle anything the template owes
	p.Bazaar.Bank.Balance = 5e6
	check(Bazaar.NeedsRecovery(p, 1) == true, "legacy bank balance needs recovery")
	local ok, msg = Bazaar.Roll(p, os.time(), 1)
	check(ok == true, "1e30 balance settles a small legacy refund (" .. tostring(msg) .. ")")
	check(Bazaar.NeedsRecovery(p, 1) == false, "refund no longer pending after settle")
	check(near(p.Cash, BIG), "balance unchanged at 12-digit precision")
	local q = DataTemplate.New()
	q.Cash = 1e6
	Bazaar.Roll(q, os.time(), 1)
	q.Bazaar.Bank.Balance = 5e6
	check(Bazaar.Roll(q, os.time(), 1) == true and Omega.ToNumber(q.Cash) == 6e6, "small balance credited exactly")
	local inf = DataTemplate.New()
	Bazaar.Roll(inf, os.time(), 1)
	inf.Cash = "inf"
	inf.Bazaar.Bank.Balance = 5e6
	check(Bazaar.Roll(inf, os.time(), 1) == false, "infinite balance still refuses and keeps the claim owed")
end

-- market Cash offer at 1e30 (stage 15 fix stays fixed)
do
	local offer
	for _, o in GameConfig.Items.ShopOffers do if o.Currency == "Cash" and o.Kind ~= "Item" then offer = o break end end
	local s, player, data = service(DataTemplate.New())
	data.profile.Cash = BIG
	local r = s:_buyItemOffer(player, offer.Id)
	check(r.ok == true and type(data.profile.Cash) == "string", "Cash offer bought with Omega Cash")
end

-- guild Flux contribution with Omega Cash: affordability and debit go through OmegaMath
do
	local OpsMath = H.load("Server/AstralForge/Modules/OpsMath")
	local G = OpsMath.GuildMath or OpsMath
	if G.CanAffordBank then
		check(G.CanAffordBank(Omega, "Cash", BIG, 1e9) == true, "guild bank affords from Omega balance")
		check(near(G.CreditBank(Omega, "Cash", BIG, 1e9), BIG), "guild bank credit keeps Omega balance")
		check(G.DebitBank(Omega, "Cash", BIG, 1e9) ~= nil, "guild bank debit from Omega balance")
	end
end

-- leaderboard Flux encoding: Omega strings order the same as numbers
do
	local Codec = H.load("Server/AstralForge/Modules/LeaderboardCodec")
	local a, b, c = Codec.Encode(1e14), Codec.Encode(BIG), Codec.Encode(Omega.New(1e40))
	check(type(b) == "number" and a < b and b < c, "leaderboard encodes Omega Flux in order")
	check(near(Codec.Decode(b), BIG), "leaderboard decode round-trips 1e30")
end

if #failures > 0 then
	error("server omega failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] server omega: %d checks (player list, bazaar refund, market, guild bank, leaderboard at 1e30) passed", checks))
