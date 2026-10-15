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
local runtimeSource = fs.readFile("src/Client/AstralForge/ClientRuntime.luau")
assert(string.find(runtimeSource, "local PRELOAD_FAIL_OPEN_SECONDS = if UserInputService.TouchEnabled then 8 else 120", 1, true), "touch startup must fail open before optional assets stall the player")
assert(string.find(runtimeSource, "if not UserInputService.TouchEnabled then\n\t\t\tcollectConfigContent", 1, true), "touch startup must defer non-mounted config assets")
assert(string.find(runtimeSource, "local function isUiElement(instance)\n\treturn carriesContent(instance)\nend", 1, true), "preload discovery must ignore layout-only UI instances")
assert(not string.find(runtimeSource, "table.insert(target, root)", 1, true), "preloading a service root recursively fetches unrelated descendants")
assert(string.find(runtimeSource, "not UserInputService.TouchEnabled or isVisibleUiContent(instance)", 1, true), "touch startup must defer hidden page assets")
assert(string.find(runtimeSource, "addContentId(instance.Image, seen, target)", 1, true), "image preloading must deduplicate content IDs instead of recursively loading UI trees")
assert(not string.find(runtimeSource, "AUDIO_ASSET_MANIFEST", 1, true) and not string.find(runtimeSource, "MUSIC_ASSET_MANIFEST", 1, true), "the shell preloader must not duplicate audio preloading")
assert(string.find(runtimeSource, "if not UserInputService.TouchEnabled then\n\t\tfor _, contentId in FORGE_ASSET_MANIFEST", 1, true), "touch startup must stream non-visible forge art on demand")
local uiSource = fs.readFile("src/Client/AstralForge/UiCore.luau#ui")
assert(string.find(uiSource, "useFlash(popTrigger, softMotion, if touchChrome then 0.24 else 0.32)", 1, true), "button impacts remain visible through the release")
assert(string.find(uiSource, "local hoverGain = 0", 1, true), "button feedback must not grow into adjacent controls")
assert(not string.find(uiSource, "local kick = math.clamp(values[2]", 1, true), "button impact feedback must stay inside its layout slot")
assert(string.find(uiSource, "Thickness = impact:map(function(amount)", 1, true), "buttons must show a restrained impact ring")
assert(string.find(uiSource, "return math.clamp(1 - amount * 0.78, 0.18, 1)", 1, true), "button impact feedback must fade cleanly")
assert(string.find(uiSource, "useFlipperSpring(activeColumn, reducedMotion, 860, 42)", 1, true), "tab selection glides instead of snapping")
assert(string.find(uiSource, "useFlash(activeIndex + 1, reducedMotion, 0.3)", 1, true), "tab selection feedback remains readable")
local eventFxSource = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
assert(string.find(eventFxSource, "if style == nil then\n\t\t\treturn nil\n\t\tend\n\t\tlocal conn = RunService.Heartbeat:Connect", 1, true), "idle event effects must not retain a frame heartbeat")
do
	local source = fs.readFile("src/Client/AstralForge/pages/PagesBazaar.luau")
	local start = assert(string.find(source, "\tlocal function request(", 1, true))
	local stop = assert(string.find(source, "\n\tlocal sections = {}", start, true))
	local body = string.sub(source, start, stop - 1)
	local calls, scheduled = {}, {}
	local latch = { current = false }
	local unresolved = { current = nil }
	local env: any = {
		pending = latch, live = { current = true }, unresolved = unresolved,
		nonce = { current = 0 }, timeout = { current = nil },
		setBusy = function() end, setNote = function() end,
		Audio = { play = function() end },
		task = {
			delay = function(_, callback)
				local token = { callback = callback }
				table.insert(scheduled, token)
				return token
			end,
			cancel = function(token) token.cancelled = true end,
		},
		props = { dispatch = function(action, payload, callback)
			table.insert(calls, { action = action, payload = payload, callback = callback })
		end },
	}
	setmetatable(env, { __index = _G })
	local request, sessionOrder = luau.load(body .. "\nreturn request, function() return sessionOrder end", { environment = env })()
	local original = { Pick = "core", Quantity = 1, RequestId = "original-order" }
	request("BazaarPlay", original)
	request("BazaarPlay", original)
	assert(#calls == 1, "market double-dispatched before render")
	calls[1].callback({ ok = false, error = "Simulated rejection" })
	assert(not unresolved.current and not sessionOrder() and scheduled[1].cancelled, "conclusive rejection clears order and timeout")
	request("BazaarPlay", original)
	assert(#calls == 2, "market did not unlock after rejection")
	calls[2].callback({ ok = false, Uncertain = true, error = "Simulated transport timeout" })
	assert(unresolved.current == original and sessionOrder() == original, "transport failures retain the order ID")
	request("BazaarPlay", { Pick = "keys", Quantity = 1, RequestId = "different-order" })
	assert(#calls == 2, "an unresolved order cannot be replaced with another purchase")
	request("BazaarPlay", { Pick = "core", Quantity = 1, RequestId = "new-id" })
	assert(#calls == 3 and calls[3].payload.RequestId == "original-order", "retry reuses the original payload")
	scheduled[#scheduled].callback()
	assert(not latch.current and unresolved.current == original, "local timeout releases input but preserves the order")
	request("BazaarPlay", original)
	assert(#calls == 4)
	env.live.current = false
	calls[4].callback({ ok = true, message = "Completed" })
	assert(not unresolved.current and not sessionOrder(), "confirmed orders clear even after the page closes")
end
print("[TEST] market actual request closure: same-frame latch, uncertain response, stable retry ID and close-time completion passed")

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
