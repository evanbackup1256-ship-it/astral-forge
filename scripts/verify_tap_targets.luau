--!strict
-- Raw tap targets shorter than TapTarget (44px) fail the build unless listed in ALLOWED.
-- The kit's <Button> already pads its hit area up to TapTarget on phones and touch
-- devices (useTouchHitShell), so it's not checked. What this looks for is hand-rolled
-- <textbutton>/<imagebutton> (or h("TextButton"/"ImageButton")) with a literal Size under
-- 44px: those get no padding and are the real misses on a phone. When a size is
-- `stack ? phone : desktop`, only the phone branch counts; sizes from variables are skipped.

local fs = require("@lune/fs")

local TAP = 44
local ROOT = "src/Client/AstralForge"
local SKIP = { "Settings", "PlayerList", "Playerlist", "Chat", "NameTag", "Rank", "Guild", "CrewMember", "PagesSocial", "Crate", "purchase", "MobileControls", "ProfileStyle" }

-- known short raw buttons, per file, each with the reason it's fine
local ALLOWED: { [string]: number } = {
	-- next-unlock and mission strips draw 32px; StripTapArea under them catches taps at 44px
	["src/Client/AstralForge/UiCore/WorkspaceChrome.tsx"] = 2,
	-- Skip guide (phones): 40px invisible catch area under the 28px button (day-a batch 6, their file)
	["src/Client/AstralForge/UiCore/onboarding.ts"] = 1,
}

local function skipped(path: string): boolean
	for _, word in SKIP do
		if string.find(path, word, 1, true) then
			return true
		end
	end
	return false
end

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.tsx?$") then
			table.insert(out, path)
		end
	end
end

-- height in px from a size expression, or nil when it isn't a literal
local function heightOf(expr: string): number?
	local phone = string.match(expr, "stack%s*%?%s*(.-)%s*:%s*[%w_]") or expr
	local h = string.match(phone, "fromOffset%(%s*[^,]+,%s*(%d+)%s*%)")
	if not h then
		local scale, offset = string.match(phone, "UDim2%([^,]+,[^,]+,%s*([%d%.]+),%s*(%d+)%s*%)")
		-- a box that fills its parent (Y scale > 0) is as tall as the row it sits in
		if scale and tonumber(scale) == 0 then
			h = offset
		end
	end
	return if h then tonumber(h) else nil
end

local files = {}
walk(ROOT, files)
table.sort(files)

local found = {}
for _, path in files do
	if not skipped(path) then
		local source = fs.readFile(path)
		local lines = string.split(source, "\n")
		for i, line in lines do
			local lower = string.lower(line)
			local at = string.find(lower, '"textbutton"', 1, true)
				or string.find(lower, '"imagebutton"', 1, true)
				or string.find(lower, "<textbutton", 1, true)
				or string.find(lower, "<imagebutton", 1, true)
			if at then
				for k = i, math.min(#lines, i + 14) do
					local text = if k == i then string.sub(lines[k], at) else lines[k]
					local expr = string.match(text, "%f[%w]Size={(.-)}%s")
						or string.match(text, "%f[%w]Size={(.*)}")
						or string.match(text, "%f[%w]Size:%s*(.-%b()),")
						or string.match(text, "%f[%w]Size:%s*(.-),?%s*$")
					if expr and string.find(text .. (lines[k + 1] or "") .. (lines[k + 2] or ""), "AutomaticSize", 1, true) then
						break -- grows with its content; the literal Size is just a floor
					end
					if expr then
						local h = heightOf(expr)
						if h and h < TAP then
							table.insert(found, { path = path, line = k, h = h })
						end
						break
					end
					if k > i and (string.find(text, "/>") or string.find(text, "^%s*}%)")) then
						break
					end
				end
			end
		end
	end
end

local perFile: { [string]: number } = {}
for _, f in found do
	perFile[f.path] = (perFile[f.path] or 0) + 1
end
local over = {}
for path, count in perFile do
	if count > (ALLOWED[path] or 0) then
		for _, f in found do
			if f.path == path then
				table.insert(over, `{f.h}px  {f.path}:{f.line}`)
			end
		end
	end
end
if #over > 0 then
	table.sort(over)
	error(`Raw buttons under {TAP}px on phones (use the kit Button, or give it a {TAP}px catch area):\n  ` .. table.concat(over, "\n  "))
end
print(`[TEST] tap targets: {#found} short raw buttons, all listed exceptions`)
