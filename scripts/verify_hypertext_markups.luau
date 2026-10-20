--!strict
-- HyperText default markups must only ever receive plain numbers for numeric
-- markups. trans.value flows straight into TextTransparency (Helpers/ApplyTrans)
-- and UIStroke.Transparency (Markups/Paired/stroke), so a React binding there
-- spams "value of type table cannot be converted to a number" on every glyph.
-- Chat rows pass a fade binding as `transparency`; this guards that path.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local NUMERIC = { trans = true, size = true, interval = true, ZIndex = true }

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= "Vendor" then
				walk(path, out)
			end
		elseif name:match("%.tsx?$") then
			table.insert(out, path)
		end
	end
end

local files = {}
walk("src", files)
local checked = 0
for _, path in files do
	local src = fs.readFile(path)
	for name, rhs in src:gmatch("markups%.([%w_]+)%.value%s*=%s*([^;\n]+);") do
		if NUMERIC[name] then
			checked += 1
			local literal = rhs:match("^[%d%.]+$") ~= nil
			local ternaryLiterals = rhs:match("^[%w_%.!]+%s*%?%s*[%w_]+%s*:%s*[%d%.]+$") ~= nil
			assert(
				literal or ternaryLiterals or rhs:match("^markupNumber%(") ~= nil,
				`{path}: markups.{name}.value must be a number literal or markupNumber(...), got {rhs}`
			)
		end
	end
end
assert(checked >= 4, "expected HyperTextHost to set numeric default markups")

-- The host must not key its render effect on the raw transparency prop: a
-- binding is a fresh table each parent render, which re-rendered the title.
local host = fs.readFile("src/Client/AstralForge/ReactHosts/HyperTextHost.tsx")
local deps = assert(host:match("%}, %[live, kind, text, size, ([%w_]+), horizAlign, preview%]%);"), "render effect deps")
assert(deps ~= "transparency", "render effect must key on the resolved number, not the transparency prop")
assert(host:find("transparency?: number | React.Binding<number>", 1, true), "AnimatedTitle accepts binding transparency")

-- markupNumber: plain numbers pass, tables/bindings/NaN fall back.
local compiled = fs.readFile("out/Client/AstralForge/ReactHosts/hyperTextMarkup.luau")
local mod = (luau.load(compiled, { debugName = "hyperTextMarkup" }) :: any)()
local markupNumber = mod.markupNumber
assert(markupNumber(0.42, 0) == 0.42, "number passes through")
assert(markupNumber({ getValue = function() return 0.3 end }, 0) == 0, "binding-like table falls back")
assert(markupNumber({}, 0.1) == 0.1, "table falls back")
assert(markupNumber(0 / 0, 0) == 0, "NaN falls back")
assert(markupNumber(nil, 13) == 13, "nil falls back")

-- Reproduce the library's merge rule (Internal/Util mergeMarkups): a table with
-- no value/attributes key is stored raw as .value. Prove the guard keeps it numeric.
local function merge(target: any, data: any)
	if type(data) ~= "table" or (data.value == nil and data.attributes == nil and data.valueAttributes == nil) then
		target.value = data
	end
end
local trans = { value = 0 }
merge(trans, markupNumber({ getValue = function() return 1 end }, 0))
assert(type(trans.value) == "number", "trans.value stays numeric after merge")

print("verify_hypertext_markups: ok (" .. checked .. " numeric markup writes)")
