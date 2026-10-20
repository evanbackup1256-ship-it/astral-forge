--!strict
-- Loading screen copy stays short and plain, and the layout fits phones.
local fs = require("@lune/fs")
local src = fs.readFile("src/Client/AstralForge/BootKit.ts")

local tipsBlock = assert(src:match("const LOADING_TIPS = (%b[])"), "LOADING_TIPS")
local tips = 0
for tip in tipsBlock:gmatch('"([^"]+)"') do
	tips += 1
	-- two lines of 14px BuilderSans at a 286px phone column hold ~70 chars
	assert(#tip <= 70, "tip too long for two phone lines: " .. tip)
end
assert(tips >= 4, "expected a handful of tips")
for verb in src:gmatch('verb: "([^"]+)"') do
	assert(#verb <= 28, "status too long for one phone line: " .. verb)
	assert(not verb:find("%.%.%."), "no trailing ellipsis in status: " .. verb)
end
-- one progress indicator, tied to the ledger
assert(select(2, src:gsub('Name: "BootProgress"', "")) == 1, "exactly one progress bar")
assert(src:find("Ledger.read()", 1, true), "progress reads the boot ledger")
assert(src:find("math.max(shownRef.current, stepped)", 1, true), "bar never moves backwards")
-- reduced motion skips the fades
assert(src:find("reduced ? EXIT_SECONDS_REDUCED : EXIT_SECONDS", 1, true), "reduced-motion exit")
assert(src:find("setCover(reduced ? 0", 1, true), "reduced-motion skips the fade-in")
for _, gone in { "EMBER_COUNT", "SPARK_COUNT", "WHITE_HOT", "TipText", "EXIT_WIPE_SECONDS" } do
	assert(not src:find(gone, 1, true), "old boot effect still present: " .. gone)
end
-- layout: column = min(440, max(200, width - 48)) keeps a 24px margin on phones
local function column(width: number): number
	return math.min(440, math.max(200, width - 48))
end
assert(src:find("math.min(440, math.max(200, width - 48))", 1, true), "layout column rule")
assert(column(286) == 238 and column(360) == 312 and column(1920) == 440, "column widths")
print("verify_boot_screen: ok (" .. tips .. " tips)")
