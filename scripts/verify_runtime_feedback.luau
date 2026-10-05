local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local function read(path)
	return fs.readFile(path):gsub("\r\n", "\n")
end
local function slice(source, first, last)
	local start = assert(source:find(first, 1, true))
	local finish = assert(source:find(last, start, true))
	return source:sub(start, finish - 1)
end
local inherited = getfenv(0)

-- Render the real atlas face with incomplete or newly introduced icon names.
local art = read("src/Client/AstralForge/ArtKit.luau")
local atlas = slice(art, "local VECTOR_ICON_ATLAS", "local ITEM_ICONS")
local function binding(value)
	return {
		map = function(_, callback)
			return callback(value)
		end,
	}
end
local icon =
	luau.load(atlas .. "return { index = vectorIconIndex, direction = vectorIconDirection, face = VectorIconFace }", {
		environment = setmetatable({
			React = {
				createElement = function(tag, props)
					return { tag = tag, props = props }
				end,
				useMemo = function(callback)
					return callback()
				end,
			},
			useExitPresence = function()
				return binding(1)
			end,
			fadeWithPresence = function(value)
				return value
			end,
			UDim2 = roblox.UDim2,
			Vector2 = roblox.Vector2,
			Enum = { ScaleType = { Stretch = "Stretch" } },
		}, { __index = inherited }),
	})()
for _, kind in { "Core", "Admin", "Gift", "Overcharge", "", "NotAnIcon", false, 12 } do
	local node = icon.face({ kind = kind, color = roblox.Color3.new(1, 1, 1) })
	assert(node.props.ImageRectOffset.X >= 0 and node.props.ImageRectOffset.Y >= 0)
	assert(math.abs(icon.direction(kind)) == 1)
end
assert(icon.index(nil) == icon.index("Guide"), "missing icon must have a valid atlas fallback")
assert(icon.index("Core") == 2 and icon.index("Admin") == 44, "existing atlas indices must remain stable")
icon.face({})

-- Execute the actual message render prelude with missing/invalid author IDs.
local social = read("src/Client/AstralForge/pages/PagesSocial.luau")
local periods = {}
local messageEnvironment = setmetatable({
	TAG_COLORS = { "cyan", "mint", "violet", "mango", "pink", "blue" },
	Palette = { mango = "mango" },
	useMessageEntrance = function()
		return binding(1)
	end,
	usePulse = function(_, period)
		table.insert(periods, period)
	end,
}, { __index = inherited })
local colorSource = slice(social, "local function userColor", "local function useMessageEntrance")
local rowSource = slice(social, "local function MessageRow", "local fade = enter:map")
local renderPrelude = luau.load(colorSource .. rowSource .. "return accent end return MessageRow", {
	environment = messageEnvironment,
})()
for _, message in
	{ { system = true }, {}, { userId = "24" }, { userId = false }, { userId = math.huge }, { userId = 0 / 0 } }
do
	assert(renderPrelude({ message = message }) ~= nil, "message must render without nil modulo")
end
for _, period in periods do
	assert(period == period and period >= 2.4 and period <= 3)
end

local audio = read("src/Client/AstralForge/AudioKit.luau")
local policy = slice(audio, "local SILENT_CUES", "local CHANNEL_CLAIM_SECONDS")
local cues = {
	"click",
	"page",
	"tabSwitch",
	"filterOpen",
	"filterPick",
	"toggleOn",
	"toggleOff",
	"sliderStep",
	"sliderCommit",
	"inputFocus",
	"inputClear",
	"playerlistSelect",
	"settings",
}
local specs = {}
for _, cue in cues do
	specs[cue] = { asset = "test", volume = 0.4, speed = 1, variance = 0, cooldown = 0.05 }
end
local channelPlays = 0
local channel = {
	Parent = {},
	IsPlaying = false,
	Play = function()
		channelPlays += 1
	end,
}
local Mixer = {}
local env = setmetatable({
	Mixer = Mixer,
	CUES = specs,
	UI_CUES = specs,
	SoundSheet = {
		region = function()
			return nil
		end,
	},
	softMaster = function(value)
		return value
	end,
	softSfx = function(value)
		return value
	end,
	VOICE_CAP = 22,
	DUPLICATE_CUE_SECONDS = 0.035,
	CHANNEL_CLAIM_SECONDS = 0.05,
	CUE_GAIN = 0.9,
	BUTTON_PITCH_CUES = {},
	Voicing = {
		voiceFor = function()
			return { pitch = 1, gain = 1 }
		end,
	},
	paintCue = function() end,
	MUSIC_DUCK_CUES = {},
}, { __index = inherited })
local methods = slice(audio, "function Mixer:playChannel", "function Mixer:sheetLoaded")
	.. slice(audio, "function Mixer:play(cue", "function Mixer:stopSfx")
luau.load(policy .. methods, { environment = env })()
local mixer = setmetatable({
	intentSerial = 0,
	masterLinear = 1,
	sfxMix = 1,
	sfxToken = 1,
	soundVariation = 0,
	lastPlayed = {},
	assetPools = {},
	channelGeneration = {},
	channelCue = {},
	channelLayerGain = {},
	claimedUntil = {},
	ensureStarted = function()
		return true
	end,
	cueMix = function()
		return 1
	end,
	acquireChannel = function()
		return channel
	end,
	scheduleRelease = function() end,
	playLayer = function() end,
}, { __index = Mixer })
for _, cue in cues do
	assert(mixer:play(cue), cue .. " must be audible when enabled")
end
assert(channelPlays == #cues, "UI action sounds must reach the sound channel")
local policyOnly = luau.load(policy .. "return claimsActivation", { environment = env })()
for _, cue in { "hover", "navHoverForge", "scroll", "reactorPulse", "autoForge", "noticeSuccess", "chatReceive" } do
	assert(not policyOnly(cue), cue .. " must not claim unrelated button audio")
end
assert(policyOnly("page") and policyOnly("toggleOff"), "semantic actions must claim their generic click")
local marker = mixer:captureIntent()
mixer.lastPlayed.click = nil
assert(mixer:playIfUnclaimed(marker, "click"))
assert(not mixer:playIfUnclaimed(marker, "click"), "same interaction must not sound twice")
mixer.sfxMix = 0
local mutedMarker = mixer:captureIntent()
assert(not mixer:play("page") and mixer:captureIntent() == mutedMarker, "muted settings must be respected")
-- Actual admin execute sizing must fit the 48px action and its note after panel padding.
local system = read("src/Client/AstralForge/pages/PagesSystem.luau")
local sizing = slice(system, "local FIELD_H =", "local BODY_H")
-- Only evaluate the sizing declarations, not the React render tree between them.
local declarations = {}
for line in sizing:gmatch("[^\n]+") do
	if
		line:match("local FIELD_H =")
		or line:match("local EXEC_TITLE =")
		or line:match("local EXEC_BUTTON =")
		or line:match("local EXEC_NOTE =")
		or line:match("local executeH =")
	then
		table.insert(declarations, line)
	end
end
local getSizing = luau.load(
	"return function(fieldSlots) "
		.. table.concat(declarations, "\n")
		.. " return { height = executeH, actionY = EXEC_TITLE + fieldSlots * FIELD_H, actionH = EXEC_BUTTON, noteH = EXEC_NOTE } end"
)()
for fields = 0, 3 do
	local layout = getSizing(fields)
	local innerHeight = layout.height - 24
	local noteY = innerHeight - layout.noteH + 4
	assert(layout.actionH >= 48, "admin action must meet the shared touch target")
	assert(layout.actionY + layout.actionH + 8 <= noteY, "admin note must clear the action and its shadow")
	assert(noteY + layout.noteH - 4 <= innerHeight, "admin note must fit the padded panel")
end
print("[TEST] icon fallback, invalid message IDs, 13 UI cues, activation audio and admin panel spacing passed")
