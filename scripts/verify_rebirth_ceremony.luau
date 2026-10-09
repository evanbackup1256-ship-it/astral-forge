local fs = require("@lune/fs")

local uiCore = fs.readFile("src/Client/AstralForge/UiCore.luau")
local panel = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")

local function slice(src, startMarker, endMarker)
	local a = string.find(src, startMarker, 1, true)
	assert(a, "missing " .. startMarker)
	local b = string.find(src, endMarker, a, true)
	assert(b, "missing end " .. endMarker)
	return string.sub(src, a, b)
end

local ceremony = slice(uiCore, '__defs["RebirthCeremony"]', '__defs["CrateRevealOverlay"]')
for _, cue in { "rebirthIgnite", "rebirthShockwave", "rebirthTierUp", "rebirthAscend", "countTick" } do
	assert(string.find(ceremony, '"' .. cue .. '"', 1, true), "ceremony cue " .. cue)
end
assert(string.find(ceremony, 'role = "ceremony"', 1, true), "ceremony resolves a MotionIntent plan")
assert(string.find(ceremony, "plan.reduced", 1, true), "ceremony honours reduced motion")
assert(string.find(ceremony, "cancelJobs()", 1, true), "ceremony cancels pending cues on skip/unmount")
assert(string.find(ceremony, "connection:Disconnect()", 1, true), "ceremony disconnects its clock")
assert(string.find(ceremony, "math.log", 1, true), "multiplier blends in log space")
assert(string.find(uiCore, "React.createElement(RebirthCeremonyHost", 1, true), "ceremony host mounted in shell")
assert(string.find(uiCore, '__load("RebirthCeremony").play(', 1, true), "rebirth action triggers ceremony")
assert(string.find(uiCore, 'addNotice("Rebirth done"', 1, true), "rebirth notice kept")

local rebirthPanel = slice(panel, '__defs["RebirthPanel"]', "RebirthPanel = RebirthPanel,")
assert(string.find(rebirthPanel, "local function beginIgnition", 1, true) or string.find(rebirthPanel, "local beginIgnition", 1, true), "ignition step")
assert(string.find(rebirthPanel, "cancelIgnition", 1, true), "ignition cancellable")
assert(string.find(rebirthPanel, "stopIgnition()", 1, true), "ignition stops on unmount")
assert(string.find(rebirthPanel, "RebirthLedger", 1, true), "keep/reset ledger")
assert(string.find(rebirthPanel, "RebirthGateTrack", 1, true), "gate track")
assert(string.find(rebirthPanel, "ChargeDial", 1, true), "charge dial")

local rebirthServer = slice(server, "function GameService:_rebirth", "function GameService:_claimQuest")
assert(not string.find(rebirthServer, "%d cores", 1, true), "rebirth message must not %d-format big-number rewards")
assert(string.find(rebirthServer, "MultiplierAfter = Economy.PermanentMultiplier(profile)", 1, true), "rebirth returns new multiplier")
assert(string.find(rebirthServer, "Rebirths = profile.Rebirths", 1, true), "rebirth returns new count")

print("[INFO] [TEST] rebirth ceremony guards passed")
