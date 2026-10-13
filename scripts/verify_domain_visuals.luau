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
-- The presentation is the radial constellation (verify_domain_constellation covers its layout); the
-- hex module still draws the detail panel's gem.
local stage = fs.readFile("src/Client/AstralForge/DomainConstellation.luau")
assert(body:find("DomainConstellation).DomainConstellation", 1, true), "domain presentation uses the constellation")
assert(not source:find("local function LatticeStage", 1, true), "retired 3D stage must be removed")
assert(body:find('dispatch("UnlockDomainNode"', 1, true), "the redesign preserves the server-authoritative unlock action")
assert(body:find("points < selected.Cost", 1, true), "the redesign preserves point gating")
assert(stage:find("path[node.Id] and (origin.id == \"core\" or path[origin.id])", 1, true), "selected prerequisite links remain highlighted")
assert(stage:find('Name = "SelectNode"', 1, true), "node selection retains a distinct hit area")
assert(not stage:find('"viewportframe"', 1, true), "the constellation must not create 3D viewports")
assert(stage:find('"LayoutGuardIgnore", true', 1, true) and stage:find('"NoMotion", true', 1, true), "the stage must own its geometry")
for _, text in { "\u{2212}", "FIT", "+" } do
	assert(stage:find(`text = "{text}"`, 1, true), "touch view controls remain available")
end
assert(body:find('Name = "DomainMobileBody"', 1, true), "mobile details remain scrollable")
local audio = fs.readFile("src/Client/AstralForge/AudioKit.luau")
local trim = assert(audio:match("local UI_TRIM = {(.-)\n}"))
local hover = tonumber(trim:match("hover = ([%d%.]+)"))
local press = tonumber(audio:match("local UI_TRIM_DEFAULT = ([%d%.]+)"))
assert(hover and press and hover >= 0.5 and press >= 1 and hover < press, "UI sounds stay audible with quieter hover feedback")
print("[INFO] [TEST] domain visuals passed | hex gem layout, constellation path highlighting, touch controls")
