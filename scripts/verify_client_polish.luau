--!strict
local Core = require("../src/Client/AstralForge/CoreKit")
local Text = Core("chatText")
local Tokens = require("../src/Client/AstralForge/MotionKit")("motionTokens")
assert(Text.limit(string.rep("a", 161), 160) == string.rep("a", 160))
assert(Text.limit(string.rep("😀", 161), 160) == string.rep("😀", 160))
assert(Text.limit(string.rep("界", 161), 160) == string.rep("界", 160))
assert(Text.limit("hello", 0) == "")
assert(Text.limit(string.char(255), 160) == "")
assert(Text.limit(nil, 160) == "")
for _, duration in { 0.08, 0.14, 0.22, 0.34, 0.5 } do
	local stiffness, damping = Tokens.entranceSpring(duration)
	local feel = Tokens.feel(stiffness, damping)
	assert(Tokens.overshoot(feel) == 0, "entrances must not overshoot")
	local expected = math.clamp(duration, 4 / (2 * math.pi * Tokens.FREQUENCY_MAX), 4 / (2 * math.pi * Tokens.FREQUENCY_MIN))
	assert(math.abs(Tokens.settleSeconds(feel) - expected) < 0.001, "duration must control spring timing within the motion envelope")
	local softStiffness = Tokens.entranceSpring(duration, true)
	assert(softStiffness < stiffness, "soft motion should ease the spring")
end
local safe = Tokens.entranceSpring(0 / 0)
assert(safe == safe and safe > 0)
print("[TEST] client polish passed | Unicode chat limits + entrance timing + soft motion")

-- Execute the actual request closures with a deferred-response transport.
-- Two clicks before React's next render must issue only one request.
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
for _, gameName in { "Bazaar" } do
	local source = fs.readFile("src/Client/AstralForge/pages/Pages" .. gameName .. ".luau")
	local start = assert(string.find(source, "\tlocal function play(", 1, true))
	local stop = assert(string.find(source, "\n\tif " .. string.lower(gameName) .. " == nil", start, true))
	local body = string.sub(source, start, stop - 1)
	local callbacks = {}
	local latch = { current = false }
	local env: any = {
		busyRef = latch, mounted = { current = true }, bazaar = {},
		stopWhir = {}, stopRoll = {}, slot = {}, coin = {}, wheel = {},
		setBusy = function() end, sfx = function() end,
		Audio = { play = function() end },
		setSlot = function() end, setCoin = function() end, setWheel = function() end,
		setMode = function() end, setNote = function() end,
		fail = function() latch.current = false end,
		conclude = function() latch.current = false end,
		dispatch = function(_, _, callback) table.insert(callbacks, callback) end,
	}
	setmetatable(env, { __index = _G })
	local play = luau.load(body .. "\nreturn play", { environment = env })()
	play({})
	play({})
	assert(#callbacks == 1, gameName .. " double-dispatched before render")
	callbacks[1]({ ok = false, error = "Simulated rejection" })
	play({})
	assert(#callbacks == 2, gameName .. " did not unlock after rejection")
end
print("[TEST] bazaar same-frame double-click and retry guards passed")

-- Exercise the shell's actual visibility expression during a bazaar round.
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
local root = assert(shell:match("BackgroundTransparency = hideAmount,(.-)LevelRoadmapHost"))
local visibility = assert(root:match("Visible = ([^\n]+)")):gsub(",%s*$", "")
for _, busy in { false, true } do
	for _, reveal in { false, true } do
		local visible = luau.load("return " .. visibility, { environment = {
			arcadeBusy = busy, crateReveal = if reveal then {} else nil,
		} })()
		assert(visible == not reveal, "bazaar activity must keep the main shell visible")
	end
end
print("[TEST] bazaar idle/active shell visibility + crate overlay isolation passed")
