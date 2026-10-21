--!nocheck
-- Recipe forging: recipes open from the codex, costs scale with rarity, Uncommon and up take a
-- spare relic one rarity lower (never a protected or equipped one), weekly caps per relic and
-- overall reset on Monday, failures spend nothing, and RecipesPaused closes the bench.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {} for k, x in v do out[k] = deepCopy(x) end return out
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local R = H.load("Shared/AstralForge/Shared/RelicRecipes")
local WeeklyBoard = H.load("Shared/AstralForge/Shared/WeeklyBoard")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")

local defs = {}
for _, d in GameConfig.Items.Definitions do defs[d.Id] = d end
local function rarityOf(id) return defs[id] and defs[id].Rarity end
local function firstOf(rarity)
	for _, d in GameConfig.Items.Definitions do if d.Rarity == rarity then return d end end
end
local COMMON, UNCOMMON, LEGENDARY = firstOf("Common"), firstOf("Uncommon"), firstOf("Legendary")
check(COMMON and UNCOMMON and LEGENDARY, "fixture relics exist")

-- recipe shape
do
	local c, u, l = R.recipeFor(COMMON), R.recipeFor(UNCOMMON), R.recipeFor(LEGENDARY)
	check(c.SacrificeRarity == nil and c.Voidglass == 0 and c.Starsteel == 0 and c.WeeklyCap == 3, "commons need only Essence and Emberite")
	check(u.SacrificeRarity == "Common", "uncommons take a common")
	check(l.SacrificeRarity == "Epic" and l.Starsteel > 0 and l.Voidglass > 0 and l.WeeklyCap == 1, "legendaries cost every ore, once a week")
	check(l.Emberite > u.Emberite and u.Emberite > c.Emberite, "ore climbs with rarity")
end

local NOW = 1792368000 + 3600 -- Monday 01:00 UTC
local function rich()
	local p = DataTemplate.New()
	p.Items.Essence = 1e6
	p.Ore.Emberite, p.Ore.Voidglass, p.Ore.Starsteel = 1e4, 1e4, 1e4
	p.Items.Discovered = { [COMMON.Id] = true, [UNCOMMON.Id] = true, [LEGENDARY.Id] = true }
	p.Items.Inventory = {}
	p.Items.Equipped = {}
	return p
end

-- planning
do
	local p = rich()
	p.Items.Discovered[COMMON.Id] = nil
	local plan, why = R.plan(p, COMMON, nil, NOW, rarityOf, 100)
	check(plan == nil and string.find(why, "codex") ~= nil, "undiscovered relics have no recipe")
	check(R.plan(rich(), nil, nil, NOW, rarityOf, 100) == nil, "unknown relics are refused")
	p = rich()
	check(R.plan(p, COMMON, nil, NOW, rarityOf, 100) ~= nil, "a common needs no sacrifice")
	check(R.plan(p, UNCOMMON, nil, NOW, rarityOf, 100) == nil, "an uncommon needs one")
	p.Items.Inventory.x = { DefinitionId = UNCOMMON.Id, Level = 1 }
	plan, why = R.plan(p, UNCOMMON, "x", NOW, rarityOf, 100)
	check(plan == nil and string.find(why, "common") ~= nil, "the sacrifice must be the rarity below")
	p.Items.Inventory.y = { DefinitionId = COMMON.Id, Level = 1, Locked = true }
	check(R.plan(p, UNCOMMON, "y", NOW, rarityOf, 100) == nil, "protected relics can't be given")
	p.Items.Inventory.y.Locked = nil
	p.Items.Equipped["Companion:1"] = "y"
	check(R.plan(p, UNCOMMON, "y", NOW, rarityOf, 100) == nil, "equipped relics can't be given")
	p.Items.Equipped = {}
	check(R.plan(p, UNCOMMON, "y", NOW, rarityOf, 100) ~= nil, "a spare common works")
	p = rich()
	p.Items.Essence = 0
	p.Ore.Emberite = 3
	plan, why = R.plan(p, COMMON, nil, NOW, rarityOf, 100)
	check(plan == nil and string.find(why, "Essence") ~= nil and string.find(why, "Emberite") ~= nil, "shortfalls are listed together")
	p = rich()
	for i = 1, 5 do p.Items.Inventory["f" .. i] = { DefinitionId = COMMON.Id, Level = 1 } end
	check(R.plan(p, COMMON, nil, NOW, rarityOf, 5) == nil, "a full bag can't take a craft")
end

-- weekly caps and reset
do
	local bag = R.ensure({ Week = WeeklyBoard.weekOf(NOW), Crafted = { [COMMON.Id] = 3, Bad = "x" } }, NOW)
	check(bag.Crafted[COMMON.Id] == 3 and bag.Crafted.Bad == nil, "this week's counts are kept, junk dropped")
	check(next(R.ensure(bag, NOW + 7 * 86400).Crafted) == nil, "Monday clears the counts")
	local p = rich()
	p.Items.Recipes = bag
	check(R.plan(p, COMMON, nil, NOW, rarityOf, 100) == nil, "per-relic cap")
	local many = {}
	for i = 1, R.WEEKLY_TOTAL do many["R" .. i] = 1 end
	p.Items.Recipes = { Week = WeeklyBoard.weekOf(NOW), Crafted = many }
	local plan, why = R.plan(p, LEGENDARY, nil, NOW, rarityOf, 100)
	check(plan == nil and string.find(why, "week") ~= nil, "overall weekly cap")
end

-- through GameService
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
	local player = H.player("Smith")
	local p = rich()
	p.Items.Inventory.spare = { DefinitionId = COMMON.Id, Level = 1, AcquiredAt = 1 }
	local s, data = service(p, player)
	local r = s:_craftRelic(player, UNCOMMON.Id, "spare")
	check(r and r.ok and r.Uid ~= nil, "craft an uncommon")
	local inv = data.profile.Items.Inventory
	check(inv.spare == nil, "the spare is gone")
	check(inv[r.Uid] and inv[r.Uid].DefinitionId == UNCOMMON.Id and inv[r.Uid].Level == 1, "the new relic is there")
	local recipe = R.recipeFor(UNCOMMON)
	check(data.profile.Items.Essence == 1e6 - recipe.Essence and data.profile.Ore.Emberite == 1e4 - recipe.Emberite, "costs are paid")
	check(data.profile.Items.Recipes.Crafted[UNCOMMON.Id] == 1, "the craft is counted")
	local before = deepCopy(data.profile)
	r = s:_craftRelic(player, UNCOMMON.Id, nil)
	check(r and not r.ok, "no sacrifice, no craft")
	check(data.profile.Items.Essence == before.Items.Essence, "a refused craft spends nothing")
	HotFlags.Set("RecipesPaused", true, os.time() + 50)
	r = s:_craftRelic(player, COMMON.Id, nil)
	check(r and not r.ok, "paused bench refuses")
	HotFlags.Set("RecipesPaused", false, os.time() + 60)
	r = s:_craftRelic(player, COMMON.Id, nil)
	check(r and r.ok, "the bench reopens")
end

-- saves
do
	local p = rich()
	p.Items.Recipes = "junk"
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	check(type(clean.Items.Recipes) == "table" and type(clean.Items.Recipes.Crafted) == "table", "a damaged recipe ledger is rebuilt")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("relic recipes: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] relic recipes: %d checks (codex gate, sacrifices, caps, weekly reset, costs, pause flag) passed", checks))
