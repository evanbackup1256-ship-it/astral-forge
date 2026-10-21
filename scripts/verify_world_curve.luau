--!nocheck
-- Worlds after the last hand-tuned one (12): every world costs more, gates harder and pays more
-- than the one before, from world 13 through the generated rows and on into ResolveZone's endless
-- tail; the first six past the anchor carry hand-written names. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local WorldCurve = H.load("Shared/AstralForge/Shared/WorldCurve")
local OmegaMath = H.load("Shared/AstralForge/Shared/OmegaMath")

local function zone(id)
	return GameConfig.ResolveZone(id)
end

local anchor = zone(WorldCurve.ANCHOR_ID)
check(anchor ~= nil and anchor.Name == "Crown Rift", "the anchor is the last hand-tuned world")
local thirteen = zone(13)
check(thirteen.Multiplier > anchor.Multiplier, "world 13 pays more than world 12 (was x15 against x370)")
check(OmegaMath.Gt(thirteen.Cost, anchor.Cost), "world 13 costs more than world 12")
check(thirteen.RequiredRebirths > anchor.RequiredRebirths and thirteen.CoreCost > anchor.CoreCost, "world 13 gates harder")
local step = thirteen.Multiplier / anchor.Multiplier
check(step > 1.4 and step < 1.7, string.format("the first step keeps the hand-tuned pace (x%.2f)", step))

local function walk(from, to, stride)
	local previous = zone(from)
	for id = from + stride, to, stride do
		local current = zone(id)
		if current == nil then
			check(false, "world " .. id .. " resolves")
			return
		end
		if not (current.Multiplier >= previous.Multiplier and OmegaMath.Gt(current.Cost, previous.Cost)
			and current.RequiredRebirths >= previous.RequiredRebirths and current.CoreCost >= previous.CoreCost) then
			check(false, string.format("world %d is a step up from world %d", id, id - stride))
			return
		end
		previous = current
	end
	check(true, "walk " .. from .. " to " .. to)
end
walk(1, 400, 1) -- hand-tuned, generated rows (13..125) and the ResolveZone tail, one by one
walk(400, 500000, 997)

-- generated rows and the ResolveZone tail agree at the seam
local lastRow = 0
for index, row in GameConfig.Zones do lastRow = math.max(lastRow, row.Id) end
check(lastRow > 12, "generated rows exist")
local seam, after = zone(lastRow), zone(lastRow + 1)
local seamStats = WorldCurve.statsFor(anchor, lastRow)
check(math.abs(seam.Multiplier - seamStats.Multiplier) < 1e-6 * seamStats.Multiplier, "rows use the same curve as the tail")
check(after.Multiplier / seam.Multiplier < 1.3, "no jump across the seam")

local far = zone(500000)
check(far.Multiplier <= 1e300 and far.Multiplier == far.Multiplier, "the far end stays finite")
check(type(far.Cost) == "string" and string.match(far.Cost, "^%d%.%d+e%d+$") ~= nil, "huge costs use the config's string form")

local names = {}
for id = 13, 18 do
	local z = zone(id)
	check(WorldCurve.FLAVOR[id] ~= nil and z.Name == WorldCurve.FLAVOR[id].Name, "world " .. id .. " has its written name")
	check(not names[z.Name], "written names are unique")
	names[z.Name] = true
end
for id = 1, 12 do
	check(not names[zone(id).Name], "written names don't repeat a tuned world")
end

if #failures > 0 then
	error("world curve failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] world curve: %d checks (step-up from world 12, rows and tail agree, written worlds 13-18) passed", checks))
