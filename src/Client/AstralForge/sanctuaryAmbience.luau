--!strict
-- Region ambience in the sanctuary: a warm hum at the Forge Heart, lava and
-- crackle in Emberreach, glassy wind and chimes in the Hollows, high wind at
-- the Spire and a slow drone in the Riftmaw.
--
-- All five loops live in one uploaded file (tools/assetgen/ambience.py) and
-- each plays as a looping region of it. Two voices crossfade when the player
-- crosses into a new region; on a bridge the last region's bed carries on,
-- quieter. Played through the mixer's ambient group, so the ambient volume
-- setting applies. Silent until the ambience file is uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Signals = require(script.Parent.sanctuarySignals)
local Manifest = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("AssetManifest"))

local Ambience = {}

local BED = {
	Heart = "amb_heart",
	Emberreach = "amb_ember",
	Hollows = "amb_hollows",
	Spire = "amb_spire",
	Riftmaw = "amb_riftmaw",
}
local LEVEL = 0.55
local BRIDGE_LEVEL = 0.3
local FADE_SECONDS = 2.5

type Voice = { sound: Sound, bed: string?, level: number, target: number }

local voices: { Voice } = {}
local current: Voice? = nil
local stepper: RBXScriptConnection? = nil
local unsubscribe: (() -> ())? = nil
local active = false

local function ambientGroup(): SoundGroup?
	local master = SoundService:FindFirstChild("ForgeMaster")
	local group = master and master:FindFirstChild("ForgeAmbient")
	return if group ~= nil and group:IsA("SoundGroup") then group else nil
end

local function makeVoice(): Voice
	local sound = Instance.new("Sound")
	sound.Name = "SanctuaryAmbience"
	sound.SoundId = `rbxassetid://{Manifest.Ambience.Id}`
	sound.Looped = true
	sound.PlaybackRegionsEnabled = true
	sound.Volume = 0
	sound.SoundGroup = ambientGroup()
	sound.Parent = SoundService
	return { sound = sound, bed = nil, level = 0, target = 0 }
end

local function play(voice: Voice, bed: string)
	local region = Manifest.Ambience.Regions[bed]
	if region == nil then
		return
	end
	local range = NumberRange.new(region[1], region[1] + region[2])
	voice.bed = bed
	voice.sound.PlaybackRegion = range
	voice.sound.LoopRegion = range
	voice.sound.TimePosition = region[1]
	if not voice.sound.IsPlaying then
		voice.sound:Play()
	end
end

local function onRegion(payload)
	if type(payload) ~= "table" or type(payload.Id) ~= "string" then
		return
	end
	local bed = BED[payload.Id]
	if bed == nil then
		-- On a bridge: keep what's playing, a little quieter.
		if current ~= nil then
			current.target = BRIDGE_LEVEL
		end
		return
	end
	if current ~= nil and current.bed == bed then
		current.target = LEVEL
		return
	end
	-- Fade the old bed out and bring the new one in on the other voice.
	local nextVoice = if voices[1] == current then voices[2] else voices[1]
	if current ~= nil then
		current.target = 0
	end
	play(nextVoice, bed)
	nextVoice.target = LEVEL
	current = nextVoice
end

function Ambience.start()
	if active or Manifest.Ambience.Id <= 0 then
		return
	end
	active = true
	voices = { makeVoice(), makeVoice() }
	current = nil
	unsubscribe = Signals.on("RegionChanged", onRegion)
	stepper = RunService.Heartbeat:Connect(function(dt: number)
		local step = dt / FADE_SECONDS
		for _, voice in voices do
			if voice.level < voice.target then
				voice.level = math.min(voice.target, voice.level + step)
			elseif voice.level > voice.target then
				voice.level = math.max(voice.target, voice.level - step)
			end
			voice.sound.Volume = voice.level * voice.level
			if voice.level <= 0 and voice.target <= 0 and voice.sound.IsPlaying then
				voice.sound:Stop()
			end
		end
	end)
end

function Ambience.stop()
	if not active then
		return
	end
	active = false
	if unsubscribe ~= nil then
		unsubscribe()
		unsubscribe = nil
	end
	if stepper ~= nil then
		stepper:Disconnect()
		stepper = nil
	end
	-- A short fade so leaving the rift never cuts the bed off mid-breath.
	local leaving = voices
	voices = {}
	current = nil
	task.spawn(function()
		local started = os.clock()
		local from = {}
		for index, voice in leaving do
			from[index] = voice.sound.Volume
		end
		while os.clock() - started < 0.8 do
			local k = 1 - (os.clock() - started) / 0.8
			for index, voice in leaving do
				voice.sound.Volume = from[index] * k
			end
			task.wait()
		end
		for _, voice in leaving do
			voice.sound:Destroy()
		end
	end)
end

return Ambience
