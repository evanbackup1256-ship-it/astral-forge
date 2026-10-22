--!strict
-- Title transparency reaches FancyText as a plain number. Chat rows pass a fade binding as
-- `transparency`; the title shows once that fade is past halfway and the renderer only ever
-- gets markupNumber(...) so a binding (a table) never lands in TextTransparency.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local host = fs.readFile("src/Client/AstralForge/ReactHosts/TitleLooks.tsx")
assert(host:find("transparency?: number | React.Binding<number>", 1, true), "AnimatedTitle accepts binding transparency")
assert(host:find("markupNumber(transparency, 0)", 1, true), "the renderer gets a resolved number")
assert(host:find("transparency: fixedTrans", 1, true), "FancyTitle is handed the resolved number")
assert(not host:find("HyperText", 1, true), "titles no longer load HyperText")

local compiled = fs.readFile("out/Client/AstralForge/ReactHosts/hyperTextMarkup.luau")
local mod = (luau.load(compiled, { debugName = "hyperTextMarkup" }) :: any)()
local markupNumber = mod.markupNumber
assert(markupNumber(0.42, 0) == 0.42, "number passes through")
assert(markupNumber({ getValue = function() return 0.3 end }, 0) == 0, "binding-like table falls back")
assert(markupNumber({}, 0.1) == 0.1, "table falls back")
assert(markupNumber(0 / 0, 0) == 0, "NaN falls back")
assert(markupNumber(nil, 13) == 13, "nil falls back")

print("verify_title_transparency: ok")
