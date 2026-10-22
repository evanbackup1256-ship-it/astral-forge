--!nocheck
-- LocalePipeline: overlays fall back to English per key, translations with the wrong
-- placeholders are ignored, bad format values never throw, and lintTable names each problem.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")
local P = H.load("Shared/AstralForge/Shared/LocalePipeline")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local EN = { ["Toast.Hello"] = "Hello %s", ["Toast.Count"] = "You have %d left.", ["Toast.Plain"] = "Saved." }
check(P.translate(EN, "Toast.Hello", { "Nova" }) == "Hello Nova", "English formats")
check(P.translate(EN, "Toast.Missing", {}) == "Toast.Missing", "a missing key prints itself")
check(P.translate(EN, "Toast.Count", { "many" }) == "You have many left.", "a bad %d value falls back to text")
check(P.placeholders("50%% off, %s and %.1f")[1] == "%s" and #P.placeholders("50%% off, %s and %.1f") == 2, "placeholders skip %%")

P.registerLocale("fr", { ["Toast.Hello"] = "Bonjour %s", ["Toast.Count"] = "Il reste %s." })
check(P.setLocale("FR") == "fr" and P.activeLocale() == "fr", "locale codes are case-insensitive")
check(P.translate(EN, "Toast.Hello", { "Nova" }) == "Bonjour Nova", "the overlay is used")
check(P.translate(EN, "Toast.Plain", {}) == "Saved.", "untranslated keys fall back to English")
check(P.translate(EN, "Toast.Count", { 3 }) == "You have 3 left.", "a translation with other placeholders is ignored")
check(P.setLocale("xx") == "en" and P.translate(EN, "Toast.Hello", { "A" }) == "Hello A", "unknown locales fall back to English")

local problems = P.lintTable(EN, {
	["Toast.Hello"] = "Salut",
	["Toast.Nope"] = "x",
	["Toast.Plain"] = " Ok",
	["bad"] = "y",
	["Toast.Count"] = "",
})
local kinds = {}
for _, p in problems do kinds[p.key .. ":" .. p.kind] = true end
check(kinds["Toast.Hello:Placeholders"], "lint finds a dropped placeholder")
check(kinds["Toast.Nope:UnknownKey"], "lint finds an unknown key")
check(kinds["Toast.Plain:Whitespace"], "lint finds edge whitespace")
check(kinds["bad:BadKeyName"], "lint finds a badly named key")
check(kinds["Toast.Count:Empty"], "lint finds empty copy")
check(#P.lintTable(EN, EN, true) == 0, "a clean table lints clean")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("locale pipeline failed: %d problems", #failures))
end
print(string.format("[TEST] locale pipeline: %d checks passed", checks))
