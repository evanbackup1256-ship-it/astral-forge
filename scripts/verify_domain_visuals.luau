local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/Client/AstralForge/UiOverlays.luau")
local layout = string.match(source, "(local function buildSpace%(%).-)\nlocal SPACE = buildSpace%(%)")
assert(layout, "domain spatial layout missing")
local makeSpace = luau.load([[
local Vector3 = require("@lune/roblox").Vector3
local STEP_Y = ]] .. tostring(assert(tonumber(string.match(source, "local STEP_Y = ([%d%.]+)")))) .. "\n" .. [[
return function(LAYOUT)
]] .. layout .. "\nreturn buildSpace()\nend")()
for count = 1, 16 do
	local slots = {}
	for tier = 0, 4 do
		for index = 1, count do
			slots[tostring(tier) .. ":" .. tostring(index)] = { tier = tier, index = index, count = count }
		end
	end
	local space = makeSpace({ slot = slots, widest = count, tierCount = 5 })
	for tier = 0, 4 do
		for index = 1, count do
			local point = space.points[tostring(tier) .. ":" .. tostring(index)]
			assert(point.pos.Magnitude < math.huge, "domain position must be finite")
			assert(point.pos.Y >= space.bottom and point.pos.Y <= space.top, "node outside vertical fit")
			assert(math.sqrt(point.pos.X ^ 2 + point.pos.Z ^ 2) < space.radius, "node outside horizontal fit")
			if index > 1 then
				local previous = space.points[tostring(tier) .. ":" .. tostring(index - 1)]
				assert((point.pos - previous.pos).Magnitude >= 3.4 - 1e-5, "domain nodes need wider spacing")
			end
			local smoothing = string.match(source, "(local function smoothDomainValue.-)\nend")
			assert(smoothing, "domain interpolation missing")
			local smooth = luau.load(smoothing .. "\nend\nreturn smoothDomainValue")()
			local function advance(fps)
				local value = 1
				for _ = 1, fps do value = smooth(value, 0.62, 1 / fps, false) end
				return value
			end
			assert(math.abs(advance(30) - advance(120)) < 1e-6, "camera easing must be frame-rate independent")
			assert(smooth(1, 0.62, 1 / 60, false) > 0.62, "zoom must not snap")
			assert(smooth(1, 0.62, 1 / 60, true) == 0.62, "reduced motion must settle immediately")
			for _, size in { { 600, 500 }, { 360, 260 } } do
				local tangent = math.tan(math.rad(19))
				local aspect = size[1] / size[2]
				local focal = size[2] / 2 / tangent
				for count = 2, 8 do
					local slots = {}
					for tier = 0, 4 do
						for index = 1, count do
							slots[tier .. ":" .. index] = { tier = tier, index = index, count = count }
						end
					end
					local space = makeSpace({ slot = slots, widest = count, tierCount = 5 })
					local distance = math.max((space.height / 2 + 0.9) / tangent, (space.radius + 0.4) / (tangent * aspect)) + space.depth
					local oldRadius = math.sqrt(((count - 1) / 2 * 2.4) ^ 2 + 1.2 ^ 2) + 0.6
					local oldDistance = math.max(((4 * 2.3 + 3) / 2 + 0.9) / tangent, (oldRadius + 0.4) / (tangent * aspect)) + oldRadius * 0.55
					assert(3.4 * focal / distance > 2.4 * focal / oldDistance, "default horizontal screen spacing must increase")
					assert(3.2 * focal / distance > 2.3 * focal / oldDistance, "default vertical screen spacing must increase")
				end
			end
		end
	end
end
local node = string.match(source, "(local function NodeButton.-)\nlocal function TotalsStrip")
assert(node and string.find(node, 'Name = "NodeName"', 1, true), "selected nodes need readable labels")
assert(string.find(node, 'Audio:play("navHover")', 1, true), "domain hover feedback missing")
local stage = string.match(source, "(local function LatticeStage.-)\nlocal function DomainSkillTree")
assert(stage, "domain stage missing")
assert(not string.find(stage, "state.targetYaw += dt", 1, true), "tree must not auto-orbit away from the user")
assert(string.find(stage, "view.current.selectedPath = selectedPath", 1, true), "prerequisite path highlighting missing")
assert(string.find(stage, "if id == state.focusId then 3 + BANDS * 10 + 20", 1, true), "selected node labels stay above overlapping depth bands")
assert(string.find(stage, 'container:SetAttribute("LayoutGuardIgnore", true)', 1, true), "the projected lattice owns its geometry")
assert(string.find(stage, 'container:SetAttribute("NoMotion", true)', 1, true), "generic button motion must not fight the lattice")
assert(string.find(stage, 'text = "FIT"', 1, true), "touch view reset missing")
assert(string.find(stage, 'text = "+"', 1, true) and string.find(stage, 'text = "-"', 1, true), "touch zoom missing")
assert(string.find(stage, "if softMotion then 1 else", 1, true), "reduced-motion presentation missing")
local audio = fs.readFile("src/Client/AstralForge/AudioKit.luau")
local trim = string.match(audio, "local UI_TRIM = {(.-)\n}")
assert(trim, "UI sound trims missing")
local hover = tonumber(string.match(trim, "hover = ([%d%.]+)"))
local press = tonumber(string.match(audio, "local UI_TRIM_DEFAULT = ([%d%.]+)"))
assert(hover and press and hover >= 0.5 and press >= 1 and hover < press, "UI sounds must stay audible with quieter hover feedback")
local bazaar = fs.readFile("src/Client/AstralForge/pages/PagesBazaar.luau")
assert(string.find(bazaar, "sound.Volume = (volume or 0.7) * 0.85", 1, true), "Bazaar feedback level regression")
print("[INFO] [TEST] domain visuals passed | 1-16 nodes per tier, path highlighting, labels, touch controls")
