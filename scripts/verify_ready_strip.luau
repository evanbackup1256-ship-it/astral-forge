--!strict
-- The Overview "Ready" strip never slices a pill at its edge: full pills when they fit, label-only
-- pills next, then as many label-only pills as fit beside a "+N" pill.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("src/Client/AstralForge/ReadyBoard.luau")
local start = assert(source:find("function Board.plan(", 1, true))
local finish = assert(source:find("\n-- One row of jump buttons", start, true))
local Board = {}
luau.load("local Board = ...\n" .. source:sub(start, finish), { chunkName = "ReadyPlan" })(Board)

local function entry(name) return { label = name, detail = "detail", count = 1, route = name } end
local list = { entry("A"), entry("B"), entry("C"), entry("D") }
local function widthOf(_, brief) return if brief then 100 else 200 end

local shown, brief, hidden = Board.plan(list, 4 * 200 + 3 * 8, widthOf)
assert(#shown == 4 and not brief and hidden == 0, "everything fits in full")
shown, brief, hidden = Board.plan(list, 4 * 100 + 3 * 8, widthOf)
assert(#shown == 4 and brief and hidden == 0, "label-only when full pills don't fit")
shown, brief, hidden = Board.plan(list, 64 + 2 * (100 + 8), widthOf)
assert(#shown == 2 and brief and hidden == 2, "two fit beside the +N pill, got " .. #shown)
shown, brief, hidden = Board.plan(list, 30, widthOf)
assert(#shown == 0 and hidden == 4, "nothing fits: only +N")
shown, brief, hidden = Board.plan(list, 0, widthOf)
assert(#shown == 4 and hidden == 0, "unmeasured strip shows everything until it has a width")

local strip = source:sub(source:find("function Board.Strip(", 1, true) or 1)
assert(strip:find("ref = stripRef", 1, true), "the strip measures its own width")
assert(strip:find("children.more", 1, true) and strip:find("props.onFind()", 1, true), "+N opens Find, which lists everything ready")
print("[TEST] ready strip: no pill is cut by the edge passed")
