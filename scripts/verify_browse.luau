--!nocheck
-- Lune tests for the shared search/category/sort model (src/Client/AstralForge/BrowseModel.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("src/Client/AstralForge/BrowseModel.luau")
local Model = luau.load(source, { debugName = "BrowseModel" })()

local failures = 0
local function check(label, ok)
	if not ok then
		failures += 1
		print("FAIL " .. label)
	end
end

-- normalize / tokens
check("normalize strips tags and punctuation", Model.normalize("<b>Auto-Gear</b>!") == "auto gear")
check("tokens split on spaces", #Model.tokens("  star   grid ") == 2)

-- token scoring tiers
check("exact beats prefix", Model.tokenScore("lab", "lab") > Model.tokenScore("lab", "laboratory"))
check("prefix beats word start", Model.tokenScore("gr", "grid star") > Model.tokenScore("gr", "star grid"))
check("word start beats inside", Model.tokenScore("grid", "star grid") > Model.tokenScore("rid", "star grid"))
check("initials", Model.tokenScore("sg", "star grid") > 0)
check("one typo", Model.tokenScore("reserch", "research bonuses") > 0)
check("two typos on long word", Model.tokenScore("leaderbords", "leaderboards") > 0)
check("short tokens are strict", Model.tokenScore("xq", "star grid") == 0)
check("no match", Model.tokenScore("dragon", "star grid") == 0)

-- multi token: every token must hit something
local fields = Model.fieldsOf({ Name = "Quantum Forge", Description = "Makes flux fast" })
check("all tokens across fields", Model.score("forge flux", fields) > 0)
check("missing token fails", Model.score("forge dragon", fields) == 0)
check("alias reaches flux", Model.score("money", fields) > 0)
check("name outweighs description", Model.score("forge", fields) > Model.score("fast", fields))
check("holes in field list", #Model.fieldsOf({}, function() return { "a", nil, "c" } end) == 2)

-- run: counts, category, sort, relevance
local items = {
	{ Name = "Ember Drill", Rarity = "Common", Price = 30 },
	{ Name = "Star Drill", Rarity = "Rare", Price = 10 },
	{ Name = "Void Lens", Rarity = "Rare", Price = 20 },
	{ Name = "Drill Core", Rarity = "Epic", Price = 5 },
}
local options = {
	categories = {
		{ id = "All", label = "All" },
		{ id = "Rare", label = "Rare", test = function(item) return item.Rarity == "Rare" end },
	},
	sorts = {
		{ id = "Default", label = "Default" },
		{ id = "Price", label = "Cheapest", compare = function(a, b) return a.Price < b.Price end },
	},
}
local r = Model.run(items, options, "drill", "All", "Default")
check("query matches 3", #r.results == 3 and r.matched == 3 and r.total == 4)
check("counts follow the query", r.counts.All == 3 and r.counts.Rare == 1)
check("relevance puts prefix first", r.results[1].Name == "Drill Core" and r.relevance)
local r2 = Model.run(items, options, "", "Rare", "Price")
check("category filter", #r2.results == 2)
check("sort compare", r2.results[1].Name == "Star Drill")
local r3 = Model.run(items, options, "", "Missing", "Missing")
check("unknown ids fall back", #r3.results == 4 and r3.results[1].Name == "Ember Drill")

-- highlight escapes and bolds
check("highlight", Model.highlight("Star <Grid>", "grid") == "Star &lt;<b>Grid</b>&gt;")
check("highlight colour", string.find(Model.highlight("Star Grid", "star", "#fff"), 'font color="#fff"', 1, true) ~= nil)

-- memory and recents
Model.remember("Boosts", { query = "x", category = "Active" })
check("recall", Model.recall("Boosts").category == "Active")
for i = 1, 8 do
	Model.pushRecent("k" .. i)
end
Model.pushRecent("k3")
local recent = Model.recent()
check("recents capped and refreshed", #recent == 6 and recent[1] == "k3")

if failures > 0 then
	error(`{failures} browse checks failed`)
end
print("[INFO] [TEST] browse model passed")
