local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/Client/AstralForge/UiOverlays.luau")
local hexSource = fs.readFile("src/Client/AstralForge/DomainHexStage.luau")
local hexStart = assert(hexSource:find("local function hexLayout(", 1, true))
local hexEnd = assert(hexSource:find("local function Hex(", hexStart, true))
local hexLayout = luau.load("local Vector2=require('@lune/roblox').Vector2\n" .. hexSource:sub(hexStart, hexEnd - 1) .. "\nreturn hexLayout")()
for count = 1, 16 do
	for _, zoom in { 0.85, 1, 1.6 } do
		local slots = {}
		for tier = 0, 7 do
			for index = 1, count do
				slots[`{tier}:{index}`] = { tier = tier, index = index, count = count }
			end
		end
		local points, extent = hexLayout({ slot = slots, widest = count, tierCount = 8 }, zoom)
		assert(72 * zoom >= 48, "hex node hit areas retain touch-target size")
		for id, point in points do
			assert(point.X >= 36 * zoom and point.X + 46 * zoom <= extent.X, "hex nodes stay inside horizontal canvas bounds")
			assert(point.Y >= 36 * zoom and point.Y + 72 * zoom <= extent.Y, "hex labels stay inside vertical canvas bounds")
			for other, otherPoint in points do
				if id ~= other then
					assert(math.abs(point.X - otherPoint.X) >= 92 * zoom or math.abs(point.Y - otherPoint.Y) >= 108 * zoom, "hex cards must not overlap")
				end
			end
		end
	end
end
local domainStart = assert(source:find("local function DomainSkillTree(", 1, true))
local domainEnd = assert(source:find('__defs["purchaseOverlay"]', domainStart, true))
local body = source:sub(domainStart, domainEnd - 1)
assert(body:find("h(DomainHexStage", 1, true), "domain presentation must use the hex stage")
assert(not source:find("local function LatticeStage", 1, true), "retired 3D stage must be removed")
assert(body:find('dispatch("UnlockDomainNode"', 1, true), "hex rewrite preserves server-authoritative unlock action")
assert(body:find("points < selected.Cost", 1, true), "hex rewrite preserves point gating")
assert(hexSource:find("selectedPath[parent]and selectedPath[node.Id]", 1, true), "selected prerequisite links remain highlighted")
assert(hexSource:find('Audio:play("navHover")', 1, true), "node hover feedback remains available")
assert(hexSource:find('Name="SelectNode"', 1, true), "node selection retains a distinct hit area")
assert(hexSource:find('children.Content=h("frame"', 1, true), "node icons are layered above the hex fill")
assert(not hexSource:find('"viewportframe"', 1, true), "hex grid must not create 3D viewports")
assert(hexSource:find('"LayoutGuardIgnore",true', 1, true) and hexSource:find('"NoMotion",true', 1, true), "the grid must own its geometry")
for _, text in { "-", "FIT", "+" } do
	assert(hexSource:find(`text="{text}"`, 1, true), "touch view controls remain available")
end
assert(body:find('Name = "DomainMobileBody"', 1, true), "mobile details remain scrollable")
local audio = fs.readFile("src/Client/AstralForge/AudioKit.luau")
local trim = assert(audio:match("local UI_TRIM = {(.-)\n}"))
local hover = tonumber(trim:match("hover = ([%d%.]+)"))
local press = tonumber(audio:match("local UI_TRIM_DEFAULT = ([%d%.]+)"))
assert(hover and press and hover >= 0.5 and press >= 1 and hover < press, "UI sounds stay audible with quieter hover feedback")
print("[INFO] [TEST] hex domain visuals passed | 1-16 nodes, 8 tiers, path highlighting, touch controls")
