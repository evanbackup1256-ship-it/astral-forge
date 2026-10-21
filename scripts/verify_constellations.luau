--!nocheck
-- Constellations: points are lifetime rebirths minus lit stars, stars light in order, the bonus
-- reaches the economy, damaged saves are repaired, and ConstellationsPaused stops new stars
-- without taking any away. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {} for k, x in v do out[k] = deepCopy(x) end return out
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local C = H.load("Shared/AstralForge/Shared/Constellations")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")

-- chart shape
check(#C.CONSTELLATIONS == 6, "six constellations")
local kinds = {}
for _, c in C.CONSTELLATIONS do
	check(#c.Stars == 5, c.Id .. " has five stars")
	check(kinds[c.Kind] == nil, c.Kind .. " has one constellation")
	kinds[c.Kind] = true
	for i = 2, #c.Stars do check(c.Stars[i].Cost > c.Stars[i - 1].Cost, c.Id .. " costs climb") end
end

-- points come from lifetime rebirths, so old saves get them back
local function profile(lifetime)
	local p = DataTemplate.New()
	p.Rebirth = { Lifetime = lifetime }
	return p
end
check(C.points(profile(0)) == 0, "no rebirths, no points")
check(C.points(profile(40)) == 40, "points equal lifetime rebirths")
check(C.lifetimeOf({ Rebirths = 3, Domain = { TotalRebirthsSpent = 5 }, Ascension = { RebirthsSpent = 2 } }) == 10,
	"saves without a ledger count rebirths still on hand plus spent")
check(C.points({ Rebirth = { Lifetime = -5 } }) == 0 and C.points({ Rebirth = { Lifetime = 0 / 0 } }) == 0, "bad lifetimes give nothing")

-- lighting
do
	local p = profile(3)
	local ok, msg = C.light(p, "Anvil2")
	check(not ok and string.find(msg, "Horn") ~= nil, "stars light in order")
	ok = C.light(p, "Anvil1")
	check(ok and p.Constellations.Lit.Anvil1 == true, "first star lights")
	check(C.points(p) == 2, "its cost is spent")
	ok = C.light(p, "Anvil1")
	check(not ok, "a lit star can't be lit again")
	ok = C.light(p, "Anvil2")
	check(ok and C.points(p) == 0, "second star spends the rest")
	ok, msg = C.light(p, "Anvil3")
	check(not ok and string.find(msg, "4 more") ~= nil, "short on points says how many")
	check(not C.light(p, "Nope1"), "unknown stars are refused")
	check(near(C.bonus(p, "Production"), 0.08), "two stars of the Anvil")
	check(C.bonus(p, "Capacity") == 0, "other kinds untouched")
end

-- completion pays extra, and the economy sees it
do
	local p = profile(31)
	for i = 1, 5 do check(C.light(p, "Cistern" .. i), "Cistern star " .. i) end
	check(C.points(p) == 0, "a full constellation costs 31")
	check(near(C.bonus(p, "Capacity"), 0.05 * 5 + 0.1), "completion bonus")
	check(near(Economy.ItemEffect(p, "Capacity", "Research"), 0.35), "research-wide lookups include it")
	check(Economy.ItemEffect(p, "Capacity", "Machine") == 0, "per-machine lookups don't")
end

-- repair: skipped stars and junk are dropped on load, in order
do
	local bag = C.ensure({ Lit = { Anvil1 = true, Anvil3 = true, Loom1 = "yes", Fake9 = true } })
	check(bag.Lit.Anvil1 == true and bag.Lit.Anvil3 == nil, "a gap ends the chain")
	check(bag.Lit.Loom1 == nil and bag.Lit.Fake9 == nil, "junk is dropped")
	check(next(C.ensure(nil).Lit) == nil and next(C.ensure("x").Lit) == nil, "missing or wrong-typed bag starts empty")
	local p = profile(5)
	p.Constellations = { Lit = { Spark1 = true, Spark2 = true, Hammer2 = true } }
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	check(clean.Constellations.Lit.Spark2 == true and clean.Constellations.Lit.Hammer2 == nil, "loading repairs the chart")
	-- a read never repairs, but it ignores what repair would drop
	check(near(C.bonus(p, "Tap"), 0), "an out-of-order star pays nothing")
end

-- through GameService, with the pause flag
local function service(p, player)
	local data = { profile = p }
	function data:AtomicUpdate(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if type(r) == "table" and r.ok == false then return false, r end
		self.profile = draft
		return true, r
	end
	function data:Get() return self.profile end
	return setmetatable({
		_data = data, _runtime = { [player] = {} }, _running = true,
		_toastPlayer = function() end, _queueStatePush = function() end,
	}, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end
do
	local player = H.player("Stargazer")
	local p = DataTemplate.New()
	p.Rebirth = nil
	p.Rebirths = 4
	local s, data = service(p, player)
	local r = s:_constellationAct(player, { Op = "Light", Star = "Lantern1" })
	check(r and r.ok, "a pre-ledger save can light a star")
	check(data.profile.Constellations.Lit.Lantern1 == true, "it's saved")
	check(type(data.profile.Rebirth) == "table" and data.profile.Rebirth.Lifetime == 4, "the ledger is seeded first")
	HotFlags.Set("ConstellationsPaused", true, os.time() + 10)
	r = s:_constellationAct(player, { Op = "Light", Star = "Lantern2" })
	check(r and not r.ok and data.profile.Constellations.Lit.Lantern2 == nil, "paused charts light nothing")
	check(near(C.bonus(data.profile, "Offline"), 0.04), "lit stars keep paying while paused")
	HotFlags.Set("ConstellationsPaused", false, os.time() + 20)
	r = s:_constellationAct(player, { Op = "Light", Star = "Lantern2" })
	check(r and r.ok, "unpaused charts work again")
	r = s:_constellationAct(player, { Op = "Burn" })
	check(r and not r.ok, "unknown ops are refused")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("constellations: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] constellations: %d checks (points, order, bonus, repair, pause flag) passed", checks))
