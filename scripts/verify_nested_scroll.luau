--!strict
-- Nested scrolling: a page's own scroll and a list's scroll must never fight.
--  * PageScaffold.planOverflow says when the sections can't fit, so the page has to scroll.
--  * A list in the fill section then joins the page scroll (embedded, still windowed).
--  * The wheel goes to the innermost frame that can still move, handing off at the ends.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local planSource = fs.readFile("src/Client/AstralForge/LayoutKit.luau#pageScaffoldPlan")
local Plan = luau.load(planSource, { chunkName = "pageScaffoldPlan" })() :: any

local sections = {
	{ id = "header", height = 120 },
	{ id = "list", fill = true, minHeight = 200 },
	{ id = "actions", height = 60 },
}
-- 120 + 200 + 60 + 2 gaps of 10 + tail 8 = 408
assert(Plan.planOverflow(sections, 900, 10, 8) == false, "tall viewport: the list scrolls itself")
assert(Plan.planOverflow(sections, 408, 10, 8) == false, "exact fit is not overflow")
assert(Plan.planOverflow(sections, 360, 10, 8) == true, "short viewport: the page has to scroll")
assert(Plan.planOverflow(sections, 0, 10, 8) == false, "unmeasured scaffold never claims overflow")
assert(Plan.planOverflow({ { id = "a", height = 900 } }, 300, 10, 8) == false, "no fill section, nothing to embed")
assert(Plan.planOverflow({ { id = "l", fill = true } }, 100, 10, 8) == true, "default fill minHeight is 120")

-- A grown fill section (the embedded list's reported height) is honoured as a content floor.
local grown = {
	{ id = "header", height = 120 },
	{ id = "list", fill = true, minHeight = 200, height = 1500 },
	{ id = "actions", height = 60 },
}
local heights = Plan.planFittedHeights(grown, 360, 10, 8)
assert(heights[2] == 1500, "the fill section grows to hold every embedded row, got " .. tostring(heights[2]))

local scaffold = fs.readFile("src/Client/AstralForge/LayoutKit.luau#pageScaffold")
assert(string.find(scaffold, "PageScrollContext.Provider", 1, true), "the fill section receives the page scroll context")
assert(string.find(scaffold, "planOverflow(sections, usable, gap, tailPad)", 1, true), "overflow comes from the plan")

local list = fs.readFile("src/Client/AstralForge/LayoutKit.luau#virtualizedList")
assert(string.find(list, "React.useContext(PageScrollContext)", 1, true), "lists read the page scroll context")
assert(string.find(list, "useVirtualWindow(count, itemHeight, headerHeight, overscan, hostRef)", 1, true), "embedded lists stay windowed against the page")
assert(string.find(list, 'frame:SetAttribute("LayoutGuardAllowDisabledScroll", embedded)', 1, true), "the layout guard is told the disabled scroll is deliberate")

local scrolling = fs.readFile("src/Client/AstralForge/LayoutKit.luau#scrolling")
assert(string.find(scrolling, "if canScrollToward(frame, delta) then", 1, true), "the wheel hands off to the outer scroller at the ends")
assert(string.find(scrolling, "frame = scrollingAncestor(frame.Parent)", 1, true), "hand-off walks up to the next scroller")

print("verify_nested_scroll: ok")
