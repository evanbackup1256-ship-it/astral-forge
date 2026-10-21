--!nocheck
-- Plot roster, scenery marks, dressing budget and which plots a client bothers to build.
-- Run `npx rbxtsc` first. The server writes the roster; the client is the only thing that
-- should turn it into parts.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function eq(got, want, label)
	check(got == want, string.format("%s: got %s want %s", label, tostring(got), tostring(want)))
end

local P = H.load("Shared/AstralForge/Shared/PlotLayout")

eq(P.ATTR.zone, "ForgeZone", "zone attribute")
eq(P.ATTR.machines, "ForgeMachines", "roster attribute")
eq(P.ATTR.owner, "ForgeOwner", "owner attribute")
eq(P.ROSTER_CAP, 12, "roster cap")

local encoded = P.encodeRoster({
	{ id = "LunarExtractor", level = 4, r = 175, g = 119, b = 255 },
	{ id = "StellarCore", level = 12, r = 70.2, g = 225, b = 255 },
	{ id = "bad id", level = 9, r = 1, g = 1, b = 1 },
	{ id = "PrismRefinery", level = 0, r = 1, g = 2, b = 3 },
	{ id = "StellarCore", level = 3, r = 1, g = 1, b = 1 },
})
eq(encoded, "StellarCore=12=70,225,255;LunarExtractor=4=175,119,255", "sorted, capped, cleaned roster")
eq(P.encodeRoster(P.decodeRoster(encoded)), encoded, "round trip")

local junk = P.decodeRoster("nope;StellarCore=3=1,2,3;x=;=1=1,2,3;Ok=2=9,9,9;StellarCore=9=4,4,4;Wide=2=1,2;Hue=2=1,2,300")
eq(#junk, 3, "junk tokens dropped")
eq(junk[1].id, "StellarCore", "first valid id kept")
eq(junk[1].level, 3, "first copy of an id kept")
eq(junk[2].id, "Ok", "plain id")
eq(junk[3].b, 255, "color channel clamped")
eq(#P.decodeRoster(""), 0, "empty roster")
eq(#P.decodeRoster(nil), 0, "missing roster")
local huge = P.decodeRoster("Core=1e+15=1,2,3")
eq(huge[1] and huge[1].level or 0, 1e15, "big level survives")
eq(#P.decodeRoster("Core=12e=1,2,3"), 0, "broken exponent dropped")

local many = {}
for i = 1, 20 do
	many[i] = { id = string.format("M_%02d", i), level = i, r = 1, g = 2, b = 3 }
end
local capped = P.decodeRoster(P.encodeRoster(many))
eq(#capped, 12, "twelve machines")
eq(capped[1].id, "M_20", "highest level leads")
eq(capped[12].id, "M_09", "twelfth is the cutoff")

local raised = P.raisedLevels({
	{ id = "StellarCore", level = 12, r = 0, g = 0, b = 0 },
	{ id = "LunarExtractor", level = 4, r = 0, g = 0, b = 0 },
}, {
	{ id = "StellarCore", level = 13, r = 0, g = 0, b = 0 },
	{ id = "LunarExtractor", level = 4, r = 0, g = 0, b = 0 },
	{ id = "PrismRefinery", level = 1, r = 0, g = 0, b = 0 },
})
eq(table.concat(raised, ","), "StellarCore,PrismRefinery", "level-ups and new machines")

eq(P.sceneryKind(1), "dock", "dock")
eq(P.sceneryKind(2), "crystal", "crystal")
eq(P.sceneryKind(3), "foundry", "foundry")
eq(P.sceneryKind(4), "rift", "rift")
eq(P.sceneryKind(5), "well", "later zones")
eq(P.sceneryKind(0), "dock", "unset zone")
local posts = P.sceneryMarks(1, 4)
eq(#posts, 4, "four bollards")
eq(posts[1].x, -30, "bollard x")
eq(posts[1].shape, "block", "bollard shape")
eq(#P.sceneryMarks(1, 2), 2, "scenery respects the count")
eq(#P.sceneryMarks(1, 0), 0, "no scenery")
eq(#P.sceneryMarks(3, 9), 3, "foundry has three marks")
eq(P.sceneryMarks(3, 1)[1].shape, "ring", "foundry leads with the heat ring")
check(P.sceneryMarks(3, 1)[1].z >= 20, "heat ring sits behind the machine rows")

local first = P.machineOffset(0)
eq(first.x, -18, "first machine x")
eq(first.y, 2, "machines sit on the pad")
eq(first.z, -8, "first machine z")
eq(P.machineOffset(3).x, 18, "fourth column")
eq(P.machineOffset(4).z, 4, "second row")
eq(P.machineScale(0), 2.4, "smallest machine")
check(P.machineScale(1e15) == 5.2, "machine scale caps")
eq(P.pillarHeight(0), 0, "no pillar")
eq(P.pillarHeight(1), 7.25, "first rank")
eq(P.pillarHeight(100), 28, "pillar caps")
eq(P.pillarHeight(0 / 0), 0, "nan rank")

local rich = P.stageBudget({
	fx = 0.49, density = 0.75, glow = 0.5, effects = 1,
	reducedMotion = false, hideOtherPlots = false, constrained = false,
})
eq(rich.plots, 3, "rich plots")
eq(rich.machines, 12, "rich machines")
eq(rich.detail, 3, "rich detail")
eq(rich.scenery, 4, "rich scenery")
eq(rich.trim, true, "rich trim")
eq(rich.lights, 4, "rich lights")
eq(rich.particles, 2, "rich particles")
eq(rich.tweens, 6, "rich tweens")
eq(rich.spins, 8, "rich spins")
eq(rich.particleRate, 8, "rich spark rate")
eq(rich.radius, 170, "rich radius")
eq(rich.motionHz, 20, "rich motion")

local phone = P.stageBudget({
	fx = 0.2, density = 0.75, glow = 0.4, effects = 1,
	reducedMotion = false, hideOtherPlots = false, constrained = true,
})
eq(phone.plots, 2, "phone plots")
eq(phone.machines, 6, "phone machines")
eq(phone.detail, 2, "phone detail")
eq(phone.scenery, 2, "phone scenery")
eq(phone.trim, false, "phone skips trim")
eq(phone.lights, 1, "phone lights")
eq(phone.particles, 1, "phone particles")
eq(phone.tweens, 2, "phone tweens")
eq(phone.spins, 3, "phone spins")
eq(phone.particleRate, 5, "phone spark rate")
eq(phone.radius, 110, "phone radius")

local quiet = P.stageBudget({
	fx = 0.49, density = 1, glow = 1, effects = 1,
	reducedMotion = true, hideOtherPlots = false, constrained = false,
})
eq(quiet.machines, 6, "quiet machines")
eq(quiet.scenery, 0, "quiet scenery")
eq(quiet.trim, false, "quiet trim")
eq(quiet.particles, 0, "quiet particles")
eq(quiet.tweens, 0, "quiet tweens")
eq(quiet.spins, 0, "quiet motion")
eq(quiet.lights, 6, "quiet still allows a few lights")

local solo = P.stageBudget({
	fx = 0.49, density = 0, glow = 0, effects = 1,
	reducedMotion = false, hideOtherPlots = true, constrained = false,
})
eq(solo.plots, 1, "hide other plots")
eq(solo.particles, 0, "density zero")
eq(solo.lights, 0, "glow zero")

local spots = {
	{ key = "far", x = 1000, y = 0, z = 0, localPlot = false },
	{ key = "near", x = 40, y = 0, z = 0, localPlot = false },
	{ key = "mine", x = 900, y = 0, z = 0, localPlot = true },
	{ key = "tiedB", x = 10, y = 0, z = 0, localPlot = false },
	{ key = "tiedA", x = 0, y = 10, z = 0, localPlot = false },
}
eq(table.concat(P.streamPlots(spots, 0, 0, 0, 170, 3, false), ","), "mine,tiedA,tiedB", "local first, then nearest, ties by name")
eq(table.concat(P.streamPlots(spots, 0, 0, 0, 170, 3, true), ","), "mine", "local only")
eq(table.concat(P.streamPlots(spots, 0, 0, 0, 170, 1, false), ","), "mine", "cap includes the local plot")
eq(#P.streamPlots(spots, 0, 0, 0, 170, 0, false), 0, "zero budget draws nothing")
eq(table.concat(P.streamPlots({ spots[1], spots[2] }, 0, 0, 0, 50, 2, false), ","), "near", "no local plot, nearest in range")

local richKey = P.budgetKey(rich)
local movedRate = table.clone(rich)
movedRate.particleRate = 1
eq(P.budgetKey(movedRate), richKey, "spark rate is not a rebuild")
movedRate.machines = rich.machines - 1
check(P.budgetKey(movedRate) ~= richKey, "machine count is a rebuild")

if #failures > 0 then
	for _, f in failures do print("  " .. f) end
	error(string.format("plot layout failed: %d problems", #failures))
end
print(string.format("[TEST] plot layout: %d checks (roster, scenery, budget, streaming) passed", checks))
