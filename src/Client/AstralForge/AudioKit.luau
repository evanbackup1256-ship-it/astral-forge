--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("AudioKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("AudioKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["audio"] = function()
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local MusicDirector = __load("musicDirector").MusicDirector
local MUSIC_DECK_NAMES = __load("musicDirector").DECK_NAMES
local Voicing = __load("audioVoicing")
local SoundSheet = __load("soundSheet")
local AssetManifest = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("AssetManifest")
local AMBIENCE_BED = "amb_heart"
local AMBIENCE_VOLUME = 0.32
local SHEET_CHANNELS = 14
local UI_HOVER = "rbxassetid://10066931761"
local UI_CLICK = "rbxassetid://10066921516"
local UI_CONFIRM = "rbxassetid://10066947742"
local UI_ALERT = UI_CONFIRM
local UI_CHIME = UI_CONFIRM
local UI_TICK = UI_HOVER
local UI_DOWN = UI_CLICK
local SFX_WHOOSH = UI_CONFIRM
local SFX_MOTOR = UI_HOVER
local SFX_RAMP = UI_CONFIRM
local SFX_SWEEP = UI_HOVER
local SFX_TRAVEL = UI_CONFIRM
local SFX_IMPACT = UI_CLICK
local SFX_PULSE = UI_CONFIRM
local SFX_FAIL = UI_CLICK
local UI_SNAP = UI_CLICK
local UI_SOFT = UI_HOVER
local SFX_BIND = UI_CONFIRM
local SFX_GLINT = UI_CONFIRM
local SFX_POP2 = UI_CLICK
local SFX_THUD = UI_CLICK
local UI_SUCCESS = UI_CONFIRM
local UI_SUCCESS_SOFT = UI_CHIME
local UI_POP_IN = SFX_RAMP
local UI_POP_OUT = UI_DOWN
local UI_SWITCH = UI_HOVER
local UI_SELECT = UI_HOVER
local UI_DESELECT = UI_DOWN
local UI_WARN = UI_ALERT
local UI_NOTIFY = UI_CHIME
local UI_POP = UI_CONFIRM
local UI_SLIDE = SFX_SWEEP
local SFX_WHOOSH_SOFT = SFX_WHOOSH
local SFX_COIN = UI_CHIME
local SFX_COLLECT = UI_CONFIRM
local SFX_BLOOM = SFX_WHOOSH
local SFX_GATE = SFX_RAMP
local SFX_DEEP = SFX_IMPACT
local SFX_SHIFT = SFX_MOTOR
local SFX_LOCK = UI_DOWN
local AUDIO_ASSET_MANIFEST = { UI_HOVER, UI_CLICK, UI_CONFIRM, UI_ALERT, UI_CHIME, UI_TICK, UI_DOWN, SFX_WHOOSH, SFX_MOTOR, SFX_RAMP, SFX_SWEEP, SFX_TRAVEL, SFX_IMPACT, SFX_PULSE, SFX_FAIL, UI_SNAP, UI_SOFT, SFX_BIND, SFX_GLINT, SFX_POP2, SFX_THUD }
local CUES = {
	hover = {
		asset = UI_HOVER,
		volume = 0.18,
		speed = 1.32,
		variance = 0.012,
		cooldown = 0.06,
		stopAfter = 0.08,
	},
	click = {
		asset = UI_CLICK,
		volume = 0.4,
		speed = 1,
		variance = 0.008,
		cooldown = 0.04,
		stopAfter = 0.12,
	},
	tick = {
		asset = UI_TICK,
		volume = 0.16,
		speed = 1.48,
		variance = 0.016,
		cooldown = 0.05,
		stopAfter = 0.07,
	},
	confirm = {
		asset = UI_CONFIRM,
		volume = 0.42,
		speed = 1.18,
		variance = 0.006,
		cooldown = 0.07,
		stopAfter = 0.42,
	},
	purchase = {
		asset = SFX_COIN,
		volume = 0.32,
		speed = 1.55,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.24,
	},
	collect = {
		asset = SFX_COLLECT,
		volume = 0.3,
		speed = 1.1,
		variance = 0.012,
		cooldown = 0.09,
		stopAfter = 0.48,
	},
	reward = {
		asset = UI_SUCCESS,
		volume = 0.4,
		speed = 0.82,
		variance = 0.004,
		cooldown = 0.14,
		stopAfter = 0.82,
	},
	unlock = {
		asset = SFX_TRAVEL,
		volume = 0.3,
		speed = 1.02,
		variance = 0.01,
		cooldown = 0.22,
		stopAfter = 0.95,
	},
	locked = {
		asset = SFX_LOCK,
		volume = 0.26,
		speed = 0.74,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.26,
	},
	error = {
		asset = SFX_FAIL,
		volume = 0.34,
		speed = 0.62,
		variance = 0,
		cooldown = 0.2,
		stopAfter = 0.48,
	},
	page = {
		asset = UI_SWITCH,
		volume = 0.2,
		speed = 0.86,
		variance = 0.008,
		cooldown = 0.05,
		stopAfter = 0.22,
	},
	mail = {
		asset = UI_SLIDE,
		volume = 0.24,
		speed = 1.12,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.48,
	},
	story = {
		asset = SFX_MOTOR,
		volume = 0.22,
		speed = 0.84,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.7,
	},
	open = {
		asset = UI_POP_IN,
		volume = 0.2,
		speed = 1.36,
		variance = 0.008,
		cooldown = 0.08,
		stopAfter = 0.2,
	},
	close = {
		asset = UI_POP_OUT,
		volume = 0.26,
		speed = 1.08,
		variance = 0.01,
		cooldown = 0.08,
		stopAfter = 0.38,
	},
	reactor = {
		asset = SFX_PULSE,
		volume = 0.28,
		speed = 0.94,
		variance = 0.012,
		cooldown = 0.08,
		stopAfter = 0.42,
	},
	storyOpen = {
		asset = SFX_MOTOR,
		volume = 0.26,
		speed = 0.9,
		variance = 0,
		cooldown = 0.42,
		stopAfter = 0.82,
	},
	storyBeat = {
		asset = UI_SELECT,
		volume = 0.18,
		speed = 0.92,
		variance = 0.012,
		cooldown = 0.12,
		stopAfter = 0.2,
	},
	storyReveal = {
		asset = UI_SUCCESS_SOFT,
		volume = 0.22,
		speed = 1.18,
		variance = 0.01,
		cooldown = 0.11,
		stopAfter = 0.48,
	},
	wheel = {
		asset = UI_HOVER,
		volume = 0.16,
		speed = 1.16,
		variance = 0.025,
		cooldown = 0.065,
		stopAfter = 0.11,
	},
	crate = {
		asset = SFX_RAMP,
		volume = 0.2,
		speed = 0.96,
		variance = 0.006,
		cooldown = 0.36,
		stopAfter = 0.58,
	},
	boost = {
		asset = SFX_WHOOSH,
		volume = 0.3,
		speed = 1.16,
		variance = 0.014,
		cooldown = 0.18,
		stopAfter = 0.8,
	},
	travel = {
		asset = SFX_SWEEP,
		volume = 0.22,
		speed = 0.72,
		variance = 0.006,
		cooldown = 0.16,
		stopAfter = 0.85,
	},
	equip = {
		asset = UI_SELECT,
		volume = 0.2,
		speed = 1.04,
		variance = 0.01,
		cooldown = 0.11,
		stopAfter = 0.22,
	},
	prestige = {
		asset = SFX_BLOOM,
		volume = 0.44,
		speed = 0.92,
		variance = 0,
		cooldown = 0.12,
		stopAfter = 1.05,
	},
	rebirthCharge = {
		asset = SFX_WHOOSH_SOFT,
		volume = 0.36,
		speed = 0.78,
		variance = 0,
		cooldown = 0.12,
		stopAfter = 0.88,
	},
	rebirthBloom = {
		asset = SFX_SHIFT,
		volume = 0.4,
		speed = 1.06,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.95,
	},
	domainCharge = {
		asset = SFX_GATE,
		volume = 0.46,
		speed = 0.76,
		variance = 0,
		cooldown = 0.12,
		stopAfter = 0.72,
	},
	domainCrack = {
		asset = SFX_DEEP,
		volume = 0.38,
		speed = 0.94,
		variance = 0.012,
		cooldown = 0.08,
		stopAfter = 0.42,
	},
	domainImpact = {
		asset = SFX_IMPACT,
		volume = 0.44,
		speed = 0.88,
		variance = 0,
		cooldown = 0.12,
		stopAfter = 0.7,
	},
	domainReward = {
		asset = SFX_GLINT,
		volume = 0.46,
		speed = 1.06,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.72,
	},
	hoverTick = {
		asset = UI_TICK,
		volume = 0.22,
		speed = 1.25,
		variance = 0.03,
		cooldown = 0.04,
		stopAfter = 0.15,
	},
	successChime = {
		asset = UI_SUCCESS,
		volume = 0.42,
		speed = 1.15,
		variance = 0.01,
		cooldown = 0.1,
		stopAfter = 0.75,
	},
	errorBuzz = {
		asset = SFX_FAIL,
		volume = 0.38,
		speed = 0.78,
		variance = 0,
		cooldown = 0.15,
		stopAfter = 0.45,
	},
	velocitySlide = {
		asset = UI_SLIDE,
		volume = 0.28,
		speed = 1.05,
		variance = 0.02,
		cooldown = 0.08,
		stopAfter = 0.35,
	},
	modalPop = {
		asset = UI_POP_IN,
		volume = 0.35,
		speed = 1.14,
		variance = 0.01,
		cooldown = 0.08,
		stopAfter = 0.38,
	},
	modalDismiss = {
		asset = UI_POP_OUT,
		volume = 0.30,
		speed = 0.98,
		variance = 0.01,
		cooldown = 0.08,
		stopAfter = 0.32,
	},
	salvageCrunch = {
		asset = SFX_MOTOR,
		volume = 0.36,
		speed = 1.24,
		variance = 0.02,
		cooldown = 0.12,
		stopAfter = 0.55,
	},
	comboMilestone = {
		asset = UI_SUCCESS_SOFT,
		volume = 0.46,
		speed = 1.32,
		variance = 0.01,
		cooldown = 0.2,
		stopAfter = 0.85,
	},
	vaultDeposit = {
		asset = SFX_COIN,
		volume = 0.44,
		speed = 1.16,
		variance = 0.014,
		cooldown = 0.08,
		stopAfter = 0.58,
	},
	domainBind = {
		asset = SFX_BIND,
		volume = 0.46,
		speed = 1.02,
		variance = 0,
		cooldown = 0.16,
		stopAfter = 0.88,
	},
	puzzleClear = {
		asset = SFX_POP2,
		volume = 0.4,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.2,
		stopAfter = 0.7,
	},
	puzzleTap = {
		asset = UI_SNAP,
		volume = 0.3,
		speed = 1.22,
		variance = 0.03,
		cooldown = 0.04,
		stopAfter = 0.16,
	},
	cardPlay = {
		asset = SFX_SWEEP,
		volume = 0.26,
		speed = 1.18,
		variance = 0.02,
		cooldown = 0.08,
		stopAfter = 0.28,
	},
	cardDraw = {
		asset = UI_HOVER,
		volume = 0.18,
		speed = 1.34,
		variance = 0.03,
		cooldown = 0.05,
		stopAfter = 0.1,
	},
	cardEndTurn = {
		asset = UI_DOWN,
		volume = 0.24,
		speed = 0.92,
		variance = 0.006,
		cooldown = 0.16,
		stopAfter = 0.42,
	},
	cardEnergy = {
		asset = UI_CHIME,
		volume = 0.22,
		speed = 1.28,
		variance = 0.016,
		cooldown = 0.1,
		stopAfter = 0.28,
	},
	cardBlock = {
		asset = UI_SELECT,
		volume = 0.2,
		speed = 0.86,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.2,
	},
	cardPower = {
		asset = SFX_PULSE,
		volume = 0.28,
		speed = 1.08,
		variance = 0.012,
		cooldown = 0.14,
		stopAfter = 0.42,
	},
	discovery = {
		asset = SFX_TRAVEL,
		volume = 0.25,
		speed = 1.08,
		variance = 0.006,
		cooldown = 0.22,
		stopAfter = 0.92,
	},
	reactorReady = {
		asset = SFX_PULSE,
		volume = 0.26,
		speed = 0.98,
		variance = 0,
		cooldown = 0.2,
		stopAfter = 0.42,
	},
	chatSend = {
		asset = UI_SELECT,
		volume = 0.15,
		speed = 1.28,
		variance = 0.014,
		cooldown = 0.09,
		stopAfter = 0.13,
	},
	chatReceive = {
		asset = UI_CONFIRM,
		volume = 0.17,
		speed = 1.28,
		variance = 0.014,
		cooldown = 0.1,
		stopAfter = 0.35,
	},
	boot = {
		asset = UI_CONFIRM,
		volume = 0.2,
		speed = 1.12,
		variance = 0,
		cooldown = 0.46,
		stopAfter = 0.62,
	},
	bootStart = {
		asset = SFX_RAMP,
		volume = 0.18,
		speed = 1.06,
		variance = 0,
		cooldown = 0.34,
		stopAfter = 0.52,
	},
	bootIgnite = {
		asset = SFX_WHOOSH,
		volume = 0.2,
		speed = 1.08,
		variance = 0.006,
		cooldown = 0.28,
		stopAfter = 0.72,
	},
	bootTension = {
		asset = UI_HOVER,
		volume = 0.1,
		speed = 1.2,
		variance = 0.012,
		cooldown = 0.16,
		stopAfter = 0.12,
	},
	bootWhoosh = {
		asset = SFX_SWEEP,
		volume = 0.23,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.56,
	},
	bootStrike = {
		asset = SFX_IMPACT,
		volume = 0.19,
		speed = 1.08,
		variance = 0.018,
		cooldown = 0.12,
		stopAfter = 0.3,
	},
	bootClang = {
		asset = UI_HOVER,
		volume = 0.08,
		speed = 1.26,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.1,
	},
	bootSpark = {
		asset = SFX_PULSE,
		volume = 0.1,
		speed = 1.06,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.2,
	},
	bootFizz = {
		asset = SFX_MOTOR,
		volume = 0.14,
		speed = 1.34,
		variance = 0.02,
		cooldown = 0.1,
		stopAfter = 0.34,
	},
	bootRumble = {
		asset = UI_DOWN,
		volume = 0.16,
		speed = 0.82,
		variance = 0.004,
		cooldown = 0.38,
		stopAfter = 0.5,
	},
	bootImpact = {
		asset = SFX_IMPACT,
		volume = 0.28,
		speed = 1.02,
		variance = 0,
		cooldown = 0.26,
		stopAfter = 0.62,
	},
	bootReady = {
		asset = UI_CONFIRM,
		volume = 0.18,
		speed = 1.18,
		variance = 0,
		cooldown = 0.38,
		stopAfter = 0.5,
	},
	bootFinaleFlip = {
		asset = SFX_SWEEP,
		volume = 0.28,
		speed = 0.96,
		variance = 0,
		cooldown = 0.8,
		stopAfter = 0.78,
	},
	bootFinaleBang = {
		asset = SFX_IMPACT,
		volume = 0.27,
		speed = 1.02,
		variance = 0,
		cooldown = 0.9,
		stopAfter = 0.5,
	},
	bootAnvilSplit = {
		asset = UI_DOWN,
		volume = 0.14,
		speed = 1.12,
		variance = 0,
		cooldown = 0.9,
		stopAfter = 0.26,
	},
	bootSlamCharge = {
		asset = SFX_TRAVEL,
		volume = 0.28,
		speed = 0.72,
		variance = 0,
		cooldown = 0.9,
		stopAfter = 0.98,
	},
	bootSlamAir = {
		asset = SFX_SWEEP,
		volume = 0.3,
		speed = 0.86,
		variance = 0,
		cooldown = 0.1,
		stopAfter = 0.62,
	},
	bootDebris = {
		asset = UI_DOWN,
		volume = 0.3,
		speed = 0.72,
		variance = 0.018,
		cooldown = 0.65,
		stopAfter = 0.58,
	},
	bootFractureTail = {
		asset = SFX_TRAVEL,
		volume = 0.2,
		speed = 0.88,
		variance = 0,
		cooldown = 0.8,
		stopAfter = 0.72,
	},
	bootGravity = {
		asset = SFX_RAMP,
		volume = 0.26,
		speed = 0.68,
		variance = 0,
		cooldown = 1.4,
		stopAfter = 1.1,
	},
	bootAftershock = {
		asset = SFX_IMPACT,
		volume = 0.25,
		speed = 0.72,
		variance = 0,
		cooldown = 1,
		stopAfter = 0.78,
	},
	wheelStart = {
		asset = SFX_RAMP,
		volume = 0.22,
		speed = 0.92,
		variance = 0.006,
		cooldown = 0.28,
		stopAfter = 0.62,
	},
	wheelCharge = {
		asset = UI_CHIME,
		volume = 0.14,
		speed = 0.96,
		variance = 0.006,
		cooldown = 0.28,
		stopAfter = 0.42,
	},
	wheelTick = {
		asset = UI_HOVER,
		volume = 0.12,
		speed = 1.18,
		variance = 0.03,
		cooldown = 0.05,
		stopAfter = 0.09,
	},
	wheelSlow = {
		asset = UI_HOVER,
		volume = 0.14,
		speed = 1.02,
		variance = 0.014,
		cooldown = 0.11,
		stopAfter = 0.12,
	},
	wheelBrake = {
		asset = UI_DOWN,
		volume = 0.22,
		speed = 0.94,
		variance = 0,
		cooldown = 0.32,
		stopAfter = 0.48,
	},
	wheelLand = {
		asset = UI_CONFIRM,
		volume = 0.29,
		speed = 1.02,
		variance = 0,
		cooldown = 0.34,
		stopAfter = 0.62,
	},
	crateOpen = {
		asset = SFX_SWEEP,
		volume = 0.21,
		speed = 1.12,
		variance = 0.006,
		cooldown = 0.32,
		stopAfter = 0.64,
	},
	crateCharge = {
		asset = UI_CHIME,
		volume = 0.14,
		speed = 0.92,
		variance = 0.004,
		cooldown = 0.3,
		stopAfter = 0.4,
	},
	crateTick = {
		asset = UI_HOVER,
		volume = 0.11,
		speed = 1.18,
		variance = 0.025,
		cooldown = 0.042,
		stopAfter = 0.08,
	},
	crateNear = {
		asset = SFX_MOTOR,
		volume = 0.28,
		speed = 0.9,
		variance = 0.018,
		cooldown = 0.12,
		stopAfter = 0.55,
	},
	crateBrake = {
		asset = UI_DOWN,
		volume = 0.22,
		speed = 0.92,
		variance = 0.008,
		cooldown = 0.3,
		stopAfter = 0.48,
	},
	crateLand = {
		asset = UI_CONFIRM,
		volume = 0.27,
		speed = 1.02,
		variance = 0,
		cooldown = 0.36,
		stopAfter = 0.6,
	},
	crateRare = {
		asset = SFX_TRAVEL,
		volume = 0.28,
		speed = 1.08,
		variance = 0.004,
		cooldown = 0.36,
		stopAfter = 0.88,
	},
	crateClaim = {
		asset = UI_CONFIRM,
		volume = 0.27,
		speed = 1.08,
		variance = 0.008,
		cooldown = 0.2,
		stopAfter = 0.68,
	},
	settings = {
		asset = UI_SWITCH,
		volume = 0.19,
		speed = 1.08,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.16,
	},
	scroll = {
		asset = UI_HOVER,
		volume = 0.075,
		speed = 1.3,
		variance = 0.035,
		cooldown = 0.09,
		stopAfter = 0.085,
	},
	tutorialStep = {
		asset = UI_SELECT,
		volume = 0.15,
		speed = 1.1,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.16,
	},
	tutorialFinish = {
		asset = UI_CONFIRM,
		volume = 0.27,
		speed = 1.08,
		variance = 0,
		cooldown = 0.4,
		stopAfter = 0.72,
	},
	reactorPulse = {
		asset = SFX_PULSE,
		volume = 0.32,
		speed = 1.18,
		variance = 0.014,
		cooldown = 0.06,
		stopAfter = 0.28,
	},
	reactorStabilize = {
		asset = SFX_WHOOSH,
		volume = 0.34,
		speed = 1.04,
		variance = 0,
		cooldown = 0.22,
		stopAfter = 0.72,
	},
	toggleOn = {
		asset = UI_POP_IN,
		volume = 0.18,
		speed = 1.14,
		variance = 0.01,
		cooldown = 0.075,
		stopAfter = 0.18,
	},
	toggleOff = {
		asset = UI_DOWN,
		volume = 0.18,
		speed = 1.28,
		variance = 0.01,
		cooldown = 0.075,
		stopAfter = 0.24,
	},
	sliderStep = {
		asset = UI_HOVER,
		volume = 0.2,
		speed = 1.38,
		variance = 0.028,
		cooldown = 0.04,
		stopAfter = 0.11,
	},
	sliderCommit = {
		asset = UI_CONFIRM,
		volume = 0.19,
		speed = 1.18,
		variance = 0.008,
		cooldown = 0.08,
		stopAfter = 0.24,
	},
	inputFocus = {
		asset = UI_SELECT,
		volume = 0.16,
		speed = 1.18,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.14,
	},
	inputClear = {
		asset = UI_DOWN,
		volume = 0.16,
		speed = 1.34,
		variance = 0.01,
		cooldown = 0.09,
		stopAfter = 0.18,
	},
	claimPress = {
		asset = UI_CONFIRM,
		volume = 0.16,
		speed = 1.28,
		variance = 0.012,
		cooldown = 0.08,
		stopAfter = 0.34,
	},
	purchasePress = {
		asset = SFX_COIN,
		volume = 0.28,
		speed = 1.5,
		variance = 0.01,
		cooldown = 0.08,
		stopAfter = 0.18,
	},
	dangerPress = {
		asset = UI_ALERT,
		volume = 0.17,
		speed = 1.02,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.24,
	},
	adminArm = {
		asset = UI_DOWN,
		volume = 0.23,
		speed = 0.84,
		variance = 0,
		cooldown = 0.2,
		stopAfter = 0.42,
	},
	adminExecute = {
		asset = SFX_IMPACT,
		volume = 0.28,
		speed = 1.08,
		variance = 0,
		cooldown = 0.34,
		stopAfter = 0.55,
	},
	invite = {
		asset = UI_CONFIRM,
		volume = 0.23,
		speed = 1.24,
		variance = 0.012,
		cooldown = 0.2,
		stopAfter = 0.48,
	},
	queueStart = {
		asset = UI_CHIME,
		volume = 0.17,
		speed = 1.12,
		variance = 0.01,
		cooldown = 0.14,
		stopAfter = 0.28,
	},
	queueStop = {
		asset = UI_DOWN,
		volume = 0.19,
		speed = 1.2,
		variance = 0.01,
		cooldown = 0.14,
		stopAfter = 0.34,
	},
	vaultBank = {
		asset = UI_CHIME,
		volume = 0.28,
		speed = 0.98,
		variance = 0.012,
		cooldown = 0.12,
		stopAfter = 0.46,
	},
	machineInstall = {
		asset = UI_CONFIRM,
		volume = 0.2,
		speed = 1.08,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.42,
	},
	researchUnlock = {
		asset = SFX_WHOOSH,
		volume = 0.24,
		speed = 0.88,
		variance = 0.006,
		cooldown = 0.15,
		stopAfter = 0.55,
	},
	salvage = {
		asset = UI_DOWN,
		volume = 0.15,
		speed = 1.2,
		variance = 0.012,
		cooldown = 0.15,
		stopAfter = 0.22,
	},
	codeSubmit = {
		asset = UI_CHIME,
		volume = 0.2,
		speed = 1.18,
		variance = 0.012,
		cooldown = 0.16,
		stopAfter = 0.3,
	},
	notification = {
		asset = UI_NOTIFY,
		volume = 0.22,
		speed = 1.04,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.48,
	},
	missionClaim = {
		asset = UI_CHIME,
		volume = 0.3,
		speed = 1.06,
		variance = 0.012,
		cooldown = 0.16,
		stopAfter = 0.52,
	},
	achievementClaim = {
		asset = SFX_TRAVEL,
		volume = 0.27,
		speed = 1.08,
		variance = 0.004,
		cooldown = 0.3,
		stopAfter = 0.88,
	},
	dailyClaim = {
		asset = UI_CONFIRM,
		volume = 0.28,
		speed = 1.12,
		variance = 0.01,
		cooldown = 0.22,
		stopAfter = 0.68,
	},
	timedClaim = {
		asset = UI_CONFIRM,
		volume = 0.22,
		speed = 1.16,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.52,
	},
	seasonClaim = {
		asset = SFX_TRAVEL,
		volume = 0.28,
		speed = 1.02,
		variance = 0.004,
		cooldown = 0.32,
		stopAfter = 0.92,
	},
	guildDeposit = {
		asset = SFX_COLLECT,
		volume = 0.28,
		speed = 1.02,
		variance = 0.01,
		cooldown = 0.15,
		stopAfter = 0.52,
	},
	guildCreate = {
		asset = SFX_COIN,
		volume = 0.34,
		speed = 0.94,
		variance = 0,
		cooldown = 0.22,
		stopAfter = 0.78,
	},
	guildJoin = {
		asset = UI_POP_IN,
		volume = 0.3,
		speed = 1.04,
		variance = 0.008,
		cooldown = 0.22,
		stopAfter = 0.55,
	},
	guildLeave = {
		asset = UI_POP_OUT,
		volume = 0.28,
		speed = 0.92,
		variance = 0,
		cooldown = 0.2,
		stopAfter = 0.5,
	},
	expeditionLaunch = {
		asset = SFX_SWEEP,
		volume = 0.28,
		speed = 0.98,
		variance = 0.008,
		cooldown = 0.28,
		stopAfter = 0.92,
	},
	expeditionReturn = {
		asset = SFX_TRAVEL,
		volume = 0.28,
		speed = 1.14,
		variance = 0.008,
		cooldown = 0.28,
		stopAfter = 0.92,
	},
	zoneUnlock = {
		asset = SFX_TRAVEL,
		volume = 0.29,
		speed = 1.02,
		variance = 0.004,
		cooldown = 0.34,
		stopAfter = 0.95,
	},
	zoneSelect = {
		asset = SFX_SWEEP,
		volume = 0.3,
		speed = 1.14,
		variance = 0.01,
		cooldown = 0.2,
		stopAfter = 0.92,
	},
	mailClaim = {
		asset = UI_CONFIRM,
		volume = 0.27,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.2,
		stopAfter = 0.66,
	},
	itemLink = {
		asset = UI_CONFIRM,
		volume = 0.2,
		speed = 1.08,
		variance = 0.008,
		cooldown = 0.15,
		stopAfter = 0.42,
	},
	itemUnlink = {
		asset = UI_DOWN,
		volume = 0.16,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.15,
		stopAfter = 0.28,
	},
	labRoute = {
		asset = SFX_PULSE,
		volume = 0.22,
		speed = 1.34,
		variance = 0.018,
		cooldown = 0.09,
		stopAfter = 0.25,
	},
	autoForge = {
		asset = UI_CHIME,
		volume = 0.19,
		speed = 1.08,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.34,
	},
	crewNudge = {
		asset = UI_CONFIRM,
		volume = 0.25,
		speed = 1.3,
		variance = 0.012,
		cooldown = 0.28,
		stopAfter = 0.48,
	},
	systemAlert = {
		asset = UI_ALERT,
		volume = 0.28,
		speed = 0.94,
		variance = 0.008,
		cooldown = 0.3,
		stopAfter = 0.5,
	},
	boostActivate = {
		asset = SFX_WHOOSH,
		volume = 0.28,
		speed = 1.18,
		variance = 0.01,
		cooldown = 0.24,
		stopAfter = 0.72,
	},
	codeReward = {
		asset = SFX_TRAVEL,
		volume = 0.25,
		speed = 1.14,
		variance = 0.004,
		cooldown = 0.26,
		stopAfter = 0.82,
	},
	tabSwitch = {
		asset = UI_SWITCH,
		volume = 0.26,
		speed = 1.16,
		variance = 0.01,
		cooldown = 0.06,
		stopAfter = 0.18,
	},
	filterOpen = {
		asset = SFX_RAMP,
		volume = 0.19,
		speed = 1.24,
		variance = 0.01,
		cooldown = 0.08,
		stopAfter = 0.24,
	},
	filterPick = {
		asset = UI_HOVER,
		volume = 0.17,
		speed = 1.34,
		variance = 0.018,
		cooldown = 0.05,
		stopAfter = 0.1,
	},
	amountChange = {
		asset = UI_HOVER,
		volume = 0.24,
		speed = 1.24,
		variance = 0.022,
		cooldown = 0.055,
		stopAfter = 0.14,
	},
	preview = {
		asset = SFX_TRAVEL,
		volume = 0.22,
		speed = 0.9,
		variance = 0.005,
		cooldown = 0.18,
		stopAfter = 0.72,
	},
	reset = {
		asset = UI_DOWN,
		volume = 0.23,
		speed = 0.82,
		variance = 0.005,
		cooldown = 0.2,
		stopAfter = 0.55,
	},
	roleChange = {
		asset = UI_SWITCH,
		volume = 0.18,
		speed = 1.02,
		variance = 0.006,
		cooldown = 0.16,
		stopAfter = 0.2,
	},
	memberRemove = {
		asset = UI_DOWN,
		volume = 0.2,
		speed = 0.92,
		variance = 0.006,
		cooldown = 0.2,
		stopAfter = 0.34,
	},
	mailRead = {
		asset = UI_CONFIRM,
		volume = 0.19,
		speed = 1.34,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.32,
	},
	storyPage = {
		asset = UI_HOVER,
		volume = 0.16,
		speed = 0.84,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.18,
	},
	leaderboardSwitch = {
		asset = UI_CHIME,
		volume = 0.22,
		speed = 1.22,
		variance = 0.012,
		cooldown = 0.1,
		stopAfter = 0.3,
	},
	requestBlocked = {
		asset = UI_DOWN,
		volume = 0.15,
		speed = 1.42,
		variance = 0,
		cooldown = 0.15,
		stopAfter = 0.2,
	},
	requestTimeout = {
		asset = SFX_FAIL,
		volume = 0.3,
		speed = 0.9,
		variance = 0,
		cooldown = 0.45,
		stopAfter = 1.1,
	},
	gamePause = {
		asset = UI_DOWN,
		volume = 0.24,
		speed = 1.06,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.36,
	},
	gameResume = {
		asset = UI_CHIME,
		volume = 0.24,
		speed = 1.14,
		variance = 0.008,
		cooldown = 0.14,
		stopAfter = 0.38,
	},
	gameExit = {
		asset = UI_DOWN,
		volume = 0.18,
		speed = 1.02,
		variance = 0,
		cooldown = 0.18,
		stopAfter = 0.34,
	},
	modalOpen = {
		asset = SFX_RAMP,
		volume = 0.21,
		speed = 0.98,
		variance = 0.008,
		cooldown = 0.14,
		stopAfter = 0.52,
	},
	offlineOpen = {
		asset = SFX_TRAVEL,
		volume = 0.25,
		speed = 1.18,
		variance = 0,
		cooldown = 0.45,
		stopAfter = 0.82,
	},
	offlineCollect = {
		asset = SFX_TRAVEL,
		volume = 0.26,
		speed = 1.12,
		variance = 0.004,
		cooldown = 0.4,
		stopAfter = 0.88,
	},
	reactorChannel = {
		asset = SFX_PULSE,
		volume = 0.16,
		speed = 1.08,
		variance = 0.008,
		cooldown = 0.1,
		stopAfter = 0.25,
	},
	reactorSurge = {
		asset = SFX_WHOOSH,
		volume = 0.28,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.35,
		stopAfter = 0.82,
	},
	oreMine = {
		asset = SFX_IMPACT,
		volume = 0.34,
		speed = 1.02,
		variance = 0.04,
		cooldown = 0.1,
		stopAfter = 0.45,
	},
	oreCollect = {
		asset = SFX_GLINT,
		volume = 0.3,
		speed = 1.06,
		variance = 0.02,
		cooldown = 0.12,
		stopAfter = 0.7,
	},
	wardenForming = {
		asset = SFX_RAMP,
		volume = 0.36,
		speed = 0.62,
		variance = 0,
		cooldown = 2,
		stopAfter = 1.6,
	},
	wardenAwake = {
		asset = SFX_DEEP,
		volume = 0.44,
		speed = 0.7,
		variance = 0,
		cooldown = 1,
		stopAfter = 1.2,
	},
	wardenStrike = {
		asset = SFX_IMPACT,
		volume = 0.3,
		speed = 1.12,
		variance = 0.05,
		cooldown = 0.08,
		stopAfter = 0.32,
	},
	wardenCrit = {
		asset = SFX_IMPACT,
		volume = 0.4,
		speed = 0.94,
		variance = 0.02,
		cooldown = 0.08,
		stopAfter = 0.5,
	},
	wardenSlamCharge = {
		asset = SFX_RAMP,
		volume = 0.34,
		speed = 0.78,
		variance = 0,
		cooldown = 0.6,
		stopAfter = 1.5,
	},
	wardenSlam = {
		asset = SFX_THUD,
		volume = 0.5,
		speed = 0.72,
		variance = 0.02,
		cooldown = 0.4,
		stopAfter = 0.9,
	},
	wardenDefeat = {
		asset = SFX_BLOOM,
		volume = 0.5,
		speed = 0.8,
		variance = 0,
		cooldown = 2,
		stopAfter = 1.8,
	},
	wardenEscape = {
		asset = SFX_WHOOSH,
		volume = 0.34,
		speed = 0.66,
		variance = 0,
		cooldown = 2,
		stopAfter = 1.3,
	},
	waystoneTravel = {
		asset = SFX_TRAVEL,
		volume = 0.34,
		speed = 0.86,
		variance = 0.01,
		cooldown = 0.5,
		stopAfter = 1.1,
	},
	regionEnter = {
		asset = UI_CHIME,
		volume = 0.22,
		speed = 0.9,
		variance = 0,
		cooldown = 1,
		stopAfter = 0.9,
	},
	purchaseResult = {
		asset = UI_CONFIRM,
		volume = 0.27,
		speed = 1.06,
		variance = 0.004,
		cooldown = 0.3,
		stopAfter = 0.76,
	},
	purchaseExit = {
		asset = SFX_RAMP,
		volume = 0.18,
		speed = 1.34,
		variance = 0,
		cooldown = 0.18,
		stopAfter = 0.34,
	},
	playerlistOpen = {
		asset = SFX_RAMP,
		volume = 0.2,
		speed = 1.18,
		variance = 0.006,
		cooldown = 0.2,
		stopAfter = 0.42,
	},
	playerlistSelect = {
		asset = UI_SELECT,
		volume = 0.14,
		speed = 1.16,
		variance = 0.008,
		cooldown = 0.07,
		stopAfter = 0.14,
	},
	playerlistAction = {
		asset = UI_CONFIRM,
		volume = 0.22,
		speed = 1.2,
		variance = 0.008,
		cooldown = 0.14,
		stopAfter = 0.48,
	},
	playerlistClose = {
		asset = SFX_RAMP,
		volume = 0.17,
		speed = 0.82,
		variance = 0,
		cooldown = 0.18,
		stopAfter = 0.36,
	},
	boostOpen = {
		asset = SFX_MOTOR,
		volume = 0.2,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.2,
		stopAfter = 0.48,
	},
	boostReady = {
		asset = UI_CONFIRM,
		volume = 0.21,
		speed = 1.18,
		variance = 0.004,
		cooldown = 0.32,
		stopAfter = 0.56,
	},
	noticeInfo = {
		asset = UI_NOTIFY,
		volume = 0.34,
		speed = 1.04,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.55,
	},
	noticeSuccess = {
		asset = UI_SUCCESS_SOFT,
		volume = 0.36,
		speed = 1.08,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.6,
	},
	noticeWarning = {
		asset = UI_WARN,
		volume = 0.36,
		speed = 1.02,
		variance = 0,
		cooldown = 0.16,
		stopAfter = 0.58,
	},
	noticeError = {
		asset = UI_ALERT,
		volume = 0.38,
		speed = 0.96,
		variance = 0,
		cooldown = 0.16,
		stopAfter = 0.58,
	},
	noticeSpecial = {
		asset = UI_POP,
		volume = 0.38,
		speed = 1.06,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.62,
	},
	noticeClose = {
		asset = UI_DESELECT,
		volume = 0.22,
		speed = 1.1,
		variance = 0,
		cooldown = 0.07,
		stopAfter = 0.2,
	},
	echoCapture = {
		asset = SFX_TRAVEL,
		volume = 0.38,
		speed = 0.88,
		variance = 0.006,
		cooldown = 0.28,
		stopAfter = 1.1,
	},
	echoClaim = {
		asset = UI_CONFIRM,
		volume = 0.36,
		speed = 1.02,
		variance = 0.004,
		cooldown = 0.2,
		stopAfter = 0.78,
	},
	echoEquip = {
		asset = SFX_WHOOSH,
		volume = 0.3,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.12,
		stopAfter = 0.42,
	},
	echoTune = {
		asset = SFX_PULSE,
		volume = 0.32,
		speed = 1.16,
		variance = 0.01,
		cooldown = 0.12,
		stopAfter = 0.52,
	},
	echoDismantle = {
		asset = UI_DOWN,
		volume = 0.3,
		speed = 0.78,
		variance = 0.008,
		cooldown = 0.18,
		stopAfter = 0.52,
	},
	curtainOpen = {
		asset = SFX_RAMP,
		volume = 0.34,
		speed = 0.88,
		variance = 0.006,
		cooldown = 0.5,
		stopAfter = 0.95,
	},
	curtainClose = {
		asset = SFX_SWEEP,
		volume = 0.3,
		speed = 0.92,
		variance = 0.006,
		cooldown = 0.45,
		stopAfter = 0.8,
	},
	sanctuaryHover = {
		asset = UI_HOVER,
		volume = 0.16,
		speed = 1.18,
		variance = 0.014,
		cooldown = 0.07,
		stopAfter = 0.1,
	},
	sanctuaryClick = {
		asset = UI_CLICK,
		volume = 0.36,
		speed = 0.92,
		variance = 0.01,
		cooldown = 0.05,
		stopAfter = 0.16,
	},
	sanctuaryRecall = {
		asset = UI_CLICK,
		volume = 0.26,
		speed = 1,
		variance = 0.006,
		cooldown = 0.2,
		stopAfter = 0.7,
	},
	navHover = {
		asset = UI_HOVER,
		volume = 0.17,
		speed = 1.4,
		variance = 0.012,
		cooldown = 0.06,
		stopAfter = 0.08,
	},
	dropdownOpen = {
		asset = UI_CLICK,
		volume = 0.22,
		speed = 1.22,
		variance = 0.008,
		cooldown = 0.05,
		stopAfter = 0.12,
	},
	dropdownClose = {
		asset = UI_CLICK,
		volume = 0.2,
		speed = 1.0,
		variance = 0.008,
		cooldown = 0.05,
		stopAfter = 0.1,
	},
	copyDone = {
		asset = UI_SELECT,
		volume = 0.24,
		speed = 1.3,
		variance = 0.008,
		cooldown = 0.12,
		stopAfter = 0.16,
	},
	dragGrab = {
		asset = UI_CLICK,
		volume = 0.22,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.06,
		stopAfter = 0.1,
	},
	dragDrop = {
		asset = UI_CLICK,
		volume = 0.26,
		speed = 0.8,
		variance = 0.008,
		cooldown = 0.06,
		stopAfter = 0.14,
	},
	dragSnap = {
		asset = UI_HOVER,
		volume = 0.2,
		speed = 1.5,
		variance = 0.008,
		cooldown = 0.04,
		stopAfter = 0.06,
	},
	favoriteOn = {
		asset = UI_SELECT,
		volume = 0.28,
		speed = 1.2,
		variance = 0.008,
		cooldown = 0.12,
		stopAfter = 0.26,
	},
	favoriteOff = {
		asset = UI_CLICK,
		volume = 0.2,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.1,
		stopAfter = 0.12,
	},
	ratingStar = {
		asset = UI_SELECT,
		volume = 0.22,
		speed = 1.1,
		variance = 0.008,
		cooldown = 0.05,
		stopAfter = 0.12,
	},
	reportSubmit = {
		asset = UI_SELECT,
		volume = 0.32,
		speed = 0.92,
		variance = 0.008,
		cooldown = 0.4,
		stopAfter = 0.4,
	},
	feedbackSubmit = {
		asset = UI_SELECT,
		volume = 0.32,
		speed = 1.1,
		variance = 0.008,
		cooldown = 0.4,
		stopAfter = 0.4,
	},
	searchType = {
		asset = UI_HOVER,
		volume = 0.12,
		speed = 1.6,
		variance = 0.008,
		cooldown = 0.03,
		stopAfter = 0.04,
	},
	countTick = {
		asset = UI_HOVER,
		volume = 0.12,
		speed = 1.8,
		variance = 0.008,
		cooldown = 0.03,
		stopAfter = 0.03,
	},
	badgeEarn = {
		asset = SFX_BLOOM,
		volume = 0.34,
		speed = 1.2,
		variance = 0.008,
		cooldown = 0.3,
		stopAfter = 0.5,
	},
	stepNext = {
		asset = UI_CLICK,
		volume = 0.24,
		speed = 1.12,
		variance = 0.008,
		cooldown = 0.08,
		stopAfter = 0.14,
	},
	stepBack = {
		asset = UI_CLICK,
		volume = 0.22,
		speed = 0.94,
		variance = 0.008,
		cooldown = 0.08,
		stopAfter = 0.14,
	},
	guildAnnounce = {
		asset = SFX_BLOOM,
		volume = 0.34,
		speed = 1.0,
		variance = 0.008,
		cooldown = 0.6,
		stopAfter = 0.7,
	},
	artifactEquip = {
		asset = UI_SELECT,
		volume = 0.3,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.15,
		stopAfter = 0.3,
	},
	artifactUpgrade = {
		asset = SFX_BLOOM,
		volume = 0.38,
		speed = 1.1,
		variance = 0.008,
		cooldown = 0.25,
		stopAfter = 0.55,
	},
	crateSeal = {
		asset = SFX_SHIFT,
		volume = 0.4,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.2,
		stopAfter = 0.4,
	},
	crateOrbit = {
		asset = SFX_WHOOSH_SOFT,
		volume = 0.34,
		speed = 0.9,
		variance = 0.008,
		cooldown = 0.4,
		stopAfter = 0.62,
	},
	crateRarityStep = {
		asset = UI_SELECT,
		volume = 0.3,
		speed = 1.25,
		variance = 0.008,
		cooldown = 0.06,
		stopAfter = 0.16,
	},
	crateRevealEpic = {
		asset = SFX_BLOOM,
		volume = 0.44,
		speed = 1.0,
		variance = 0.008,
		cooldown = 0.3,
		stopAfter = 0.7,
	},
	crateRevealMythic = {
		asset = SFX_BLOOM,
		volume = 0.5,
		speed = 0.86,
		variance = 0.008,
		cooldown = 0.4,
		stopAfter = 1.0,
	},
	rebirthIgnite = {
		asset = SFX_WHOOSH_SOFT,
		volume = 0.42,
		speed = 0.7,
		variance = 0.008,
		cooldown = 0.5,
		stopAfter = 1.1,
	},
	rebirthShockwave = {
		asset = SFX_SHIFT,
		volume = 0.48,
		speed = 0.7,
		variance = 0.008,
		cooldown = 0.4,
		stopAfter = 0.8,
	},
	rebirthTierUp = {
		asset = SFX_BLOOM,
		volume = 0.4,
		speed = 1.2,
		variance = 0.008,
		cooldown = 0.12,
		stopAfter = 0.4,
	},
	rebirthAscend = {
		asset = SFX_BLOOM,
		volume = 0.5,
		speed = 0.8,
		variance = 0.008,
		cooldown = 0.6,
		stopAfter = 1.25,
	},
}
local UI_CUES = {}
for _, cue in {
	"hover", "click", "tick", "confirm", "locked", "error", "page", "mail", "story",
	"open", "close", "settings", "scroll", "toggleOn", "toggleOff", "sliderStep",
	"sliderCommit", "inputFocus", "inputClear", "tabSwitch", "filterOpen", "filterPick",
	"amountChange", "modalOpen", "modalPop", "modalDismiss", "purchaseExit",
	"playerlistOpen", "playerlistSelect", "playerlistAction", "playerlistClose",
	"noticeInfo", "noticeSuccess", "noticeWarning", "noticeError", "noticeSpecial",
	"noticeClose", "chatSend", "chatReceive", "hoverTick", "successChime",
	"errorBuzz", "velocitySlide", "purchase", "purchasePress", "reward",
	"collect", "travel", "researchUnlock", "claimPress",
	"sanctuaryHover", "sanctuaryClick", "navHover", "curtainOpen", "curtainClose",
	"dropdownOpen", "dropdownClose", "copyDone", "dragGrab", "dragDrop", "dragSnap",
	"favoriteOn", "favoriteOff", "ratingStar", "reportSubmit", "feedbackSubmit", "searchType",
	"countTick", "badgeEarn", "stepNext", "stepBack", "guildAnnounce",
} do
	UI_CUES[cue] = true
end
-- the page, hover and icon-press families (navOpenShop, claimPressHover, corePress...) are interface
-- sounds too: they share the UI group, the UI mix and the UI overlap cap
setmetatable(UI_CUES, {
	__index = function(_, cue)
		if type(cue) ~= "string" then
			return nil
		end
		return string.sub(cue, 1, 3) == "nav" or string.sub(cue, -5) == "Hover" or string.sub(cue, -5) == "Press" or nil
	end,
})
local CUE_ALIAS = {
	crateReveal = "crateRevealEpic",
}
local function isHoverCue(cue)
	return cue == "hover" or string.sub(cue, -5) == "Hover" or string.sub(cue, 1, 8) == "navHover"
end
local PRELOAD_BATCH_SIZE = 11
local VOICE_CAP = 22
local UI_OVERLAP_CAP = 2
local TRIM_RELEASE_STEPS = 3
local CUE_GAIN = 0.9
local SHEET_CUE_VOLUME = 0.3
-- relative level of a UI cue inside the UI mix (1 = as authored on the sheet); pointer chatter sits
-- a step below presses so a sweep across a menu never drowns what you click
local UI_TRIM = {
	hover = 0.75, hoverTick = 0.75, navHover = 0.75, sanctuaryHover = 0.75, tick = 0.85, scroll = 0.5,
	sliderStep = 0.8, amountChange = 0.9, inputFocus = 0.95, inputClear = 0.95, filterPick = 0.95,
	searchType = 0.7, countTick = 0.7, dragSnap = 0.85,
}
local UI_TRIM_DEFAULT = 1.15
-- Interface cues are short transients that sit under a full music bed, so the UI bus runs hot;
-- without this a hover landed near 0.04 Sound volume and read as silence.
local UI_BUS_GAIN = 1.8
local SFX_BUS_GAIN = 1.3
local function uiCurve(linear)
	return math.sqrt(math.clamp(linear, 0, 1))
end
-- only the cues that can fire many times a second (or for other players' activity) stay silent
local SILENT_CUES = {
	scroll = true,
	chatReceive = true,
	velocitySlide = true,
}
local CHANNEL_CLAIM_SECONDS = 0.05
local DUPLICATE_CUE_SECONDS = 0.035
local BUTTON_PITCH_CUES = {
	click = true,
	hover = true,
	confirm = true,
}
local LAYER_SOURCES = {
	hover = UI_HOVER,
	click = UI_CLICK,
	confirm = UI_CONFIRM,
}
local BOOTSTRAP_ASSETS = AUDIO_ASSET_MANIFEST
local function residentChannelCount(asset)
	return if asset == UI_CLICK or asset == UI_TICK or asset == UI_CONFIRM or asset == UI_HOVER or asset == UI_NOTIFY then 8 else 4
end
local NAVIGATION_CUE = "tabSwitch"
local MUSIC_DUCK_CUES = {
	reward = 0.38, unlock = 0.34, discovery = 0.36, prestige = 0.52,
	rebirthCharge = 0.45, rebirthBloom = 0.5, domainCharge = 0.48, domainImpact = 0.5, domainReward = 0.42,
	wheelLand = 0.4, crateLand = 0.36, crateRare = 0.42, crateClaim = 0.34,
	missionClaim = 0.32, achievementClaim = 0.4, dailyClaim = 0.34, seasonClaim = 0.4,
	tutorialFinish = 0.36, purchaseResult = 0.3, boostReady = 0.28, bootReady = 0.32,
	bootFinaleBang = 0.48, bootImpact = 0.4, comboMilestone = 0.34, echoCapture = 0.36, zoneUnlock = 0.38,
}
local function labelContains(label, ...)
	local needles = { ... }
	local upper = string.upper(label)
	local _result = false
	local _callback = function(needle)
		return (string.find(upper, needle, 1, true)) ~= nil
	end
	for _k, _v in needles do
		if _callback(_v, _k - 1, needles) then
			_result = true
			break
		end
	end
	return _result
end
local function labelEquals(label, ...)
	local values = { ... }
	local upper = string.upper(label)
	local _result = false
	local _callback = function(value)
		return upper == value
	end
	for _k, _v in values do
		if _callback(_v, _k - 1, values) then
			_result = true
			break
		end
	end
	return _result
end
local function buttonAudioCue(label, icon)
	if labelEquals(label, "FLUX", "REBIRTHS", "PLAYTIME", "DUST", "CORES", "DOMAIN", "WORLDS") then
		return "leaderboardSwitch"
	end
	if labelContains(label, "REVIEW CHANGE", "APPLY CHANGE") then
		return "adminArm"
	end
	if icon == "Code" or labelContains(label, "REDEEM CODE") then
		return "codeSubmit"
	end
	if labelContains(label, "KICK", "REMOVE MEMBER") then
		return "memberRemove"
	end
	if labelContains(label, "PROMOTE", "DEMOTE", "CHANGE ROLE") then
		return "roleChange"
	end
	if labelContains(label, "PREVIEW") then
		return "preview"
	end
	if labelContains(label, "REPLAY", "RESET") then
		return "reset"
	end
	if labelContains(label, "SALVAGE", "DELETE", "ARCHIVE") then
		return "dangerPress"
	end
	if labelContains(label, "CANCEL", "CLOSE", "BACK", "HIDE", "EXIT", "LEAVE", "CLEAR", "DETACH") then
		return "close"
	end
	if labelContains(label, "REFRESH", "FIND CURRENT", "QUICK LAND") then
		return "tick"
	end
	if labelContains(label, "REBIRTH", "PRESTIGE") then
		return "prestige"
	end
	if labelContains(label, "DOMAIN GATE", "DOMAIN EXPANSION", "OPEN DOMAIN") then
		return "domainCharge"
	end
	if labelContains(label, "END TURN") then
		return "cardEndTurn"
	end
	if labelEquals(label, "TEMPER") or labelContains(label, "TEMPER  ·") then
		return "cardPower"
	end
	if labelEquals(label, "SPARK") or labelContains(label, "SPARK  ·") then
		return "cardEnergy"
	end
	if labelContains(label, "CLAIM", "COLLECT", "REWARD", "GIFT") then
		return "claimPress"
	end
	if labelContains(label, "+ CASH", "+ DUST", "CONTRIBUTE", "DEPOSIT") then
		return "vaultBank"
	end
	if labelContains(label, "CHARTER") then
		return "guildCreate"
	end
	if labelContains(label, "JOIN GUILD") then
		return "guildJoin"
	end
	if labelContains(label, "BUY", "PURCHASE", "UPGRADE") then
		return "purchasePress"
	end
	if labelContains(label, "EQUIP", "WEAR", "SOCKET") then
		return "equip"
	end
	if labelContains(label, "INVITE") then
		return "invite"
	end
	if labelContains(label, "VISIT", "TRAVEL", "LAUNCH") then
		return "travel"
	end
	if labelContains(label, "RESUME") then
		return "gameResume"
	end
	if labelContains(label, "PAUSE") then
		return "gamePause"
	end
	if labelContains(label, "STOP") then
		return "queueStop"
	end
	if labelContains(label, "START", "PLAY", "SPIN") then
		return "queueStart"
	end
	if labelContains(label, "OPEN", "VIEW", "GUIDE", "UPDATES", "PATCH NOTES", "REPLAY") then
		return "open"
	end
	if icon == "Close" or icon == "Back" or icon == "Hide" then
		return "close"
	end
	if icon == "Menu" or icon == "Chevron" then
		return "open"
	end
	if icon == "Refresh" or icon == "Search" then
		return "tick"
	end
	if icon == "Collect" or icon == "Gift" or icon == "Calendar" or icon == "Rewards" then
		return "claimPress"
	end
	if icon == "Flux" or icon == "Dust" or icon == "StarGrid" or icon == "Research" or icon == "Shop" then
		return "purchasePress"
	end
	if icon == "Settings" then
		return "settings"
	end
	if icon == "Send" then
		return "chatSend"
	end
	if icon == "Mail" then
		return "mail"
	end
	if icon == "Story" or icon == "Guide" then
		return "story"
	end
	if icon == "World" or icon == "Visit" then
		return "travel"
	end
	if icon == "Loadout" or icon == "Artifact" then
		return "equip"
	end
	if icon == "Boost" then
		return "boost"
	end
	if icon == "Overcharge" or icon == "Anomaly" or icon == "Reactor" then
		return "reactorPulse"
	end
	if icon == "Lock" then
		return "locked"
	end
	if icon == "Check" then
		return "confirm"
	end
	if icon == "Play" then
		return "queueStart"
	end
	if icon == "Pause" then
		return "queueStop"
	end
	if icon == "Vault" then
		return "vaultBank"
	end
	if icon == "Timer" then
		return "boostOpen"
	end
	if icon == "Crate" then
		return "crateOpen"
	end
	if icon == "Wheel" then
		return "wheelStart"
	end
	if icon == "Jackpot" then
		return "reward"
	end
	if icon == "Rebirth" then
		return "rebirthCharge"
	end
	if icon == "Crew" or icon == "Pilot" then
		return "invite"
	end
	if icon == "Inventory" then
		return "equip"
	end
	if icon == "Milestone" or icon == "Mission" then
		return "missionClaim"
	end
	if icon == "Guild" then
		return "guildJoin"
	end
	if icon == "Leaderboard" then
		return "leaderboardSwitch"
	end
	if icon == "Forge" then
		return "forgePress"
	end
	if icon == "Core" then
		return "corePress"
	end
	if icon == "Wave" then
		return "wavePress"
	end
	if icon == "Lab" then
		return "labPress"
	end
	if icon == "Command" then
		return "commandPress"
	end
	if icon == "Admin" then
		return "adminPress"
	end
	if icon == "Credits" then
		return "creditsPress"
	end
	if icon == "Chat" then
		return "chatPress"
	end
	if icon == "Continuum" then
		return "continuumPress"
	end
	if icon == "Mission" then
		return "missionPress"
	end
	if icon == "Overview" then
		return "overviewPress"
	end
	if icon == "Domain" then
		return "domainCharge"
	end
	return "click"
end
local function hoverCueFor(pressCue)
	if type(pressCue) ~= "string" or pressCue == "" or pressCue == "hover" or pressCue == "click" then
		return "hover"
	end
	if string.sub(pressCue, 1, 8) == "navHover" or string.sub(pressCue, -5) == "Hover" then
		return pressCue
	end
	local paired = pressCue .. "Hover"
	local start = SoundSheet.region(paired)
	if start ~= nil then
		return paired
	end
	return "hover"
end
local function softMaster(linear)
	local t = math.clamp(linear, 0, 1)
	return t * t * (3 - 2 * t)
end
local function softSfx(linear)
	local t = math.clamp(linear, 0, 1)
	return math.clamp(t * 1.05 + t * t * 0.12, 0, 1.15)
end
local function paintCue(channel, cue, authored)
	local voice = Voicing.voiceFor(cue)

	local color = channel:FindFirstChild("CueColor")
	if color == nil then
		color = Instance.new("EqualizerSoundEffect")
		color.Name = "CueColor"
		color.Parent = channel
	end
	-- Authored sheet regions already have their own timbre and space.
	color.HighGain = if authored then 0 else Voicing.clampGain(voice.high)
	color.MidGain = if authored then 0 else Voicing.clampGain(voice.mid)
	color.LowGain = if authored then 0 else Voicing.clampGain(voice.low)

	local space = channel:FindFirstChild("CueSpace")
	if not authored and voice.reverbWet > 0.001 then
		if space == nil then
			space = Instance.new("ReverbSoundEffect")
			space.Name = "CueSpace"
			space.Parent = channel
		end
		space.Enabled = true
		space.DecayTime = math.clamp(voice.reverbDecay, 0.1, 20)
		space.WetLevel = math.clamp(-30 + voice.reverbWet * 36, -80, 10)
		space.DryLevel = 0
	elseif space ~= nil then
		space.Enabled = false
	end

	local grit = channel:FindFirstChild("CueDrive")
	if not authored and voice.drive > 0.001 then
		if grit == nil then
			grit = Instance.new("DistortionSoundEffect")
			grit.Name = "CueDrive"
			grit.Parent = channel
		end
		grit.Enabled = true
		grit.Level = math.clamp(voice.drive, 0, 1)
	elseif grit ~= nil then
		grit.Enabled = false
	end
end
local Mixer
do
	Mixer = setmetatable({}, {
		__tostring = function()
			return "Mixer"
		end,
	})
	Mixer.__index = Mixer
	function Mixer.new(...)
		local self = setmetatable({}, Mixer)
		return self:constructor(...) or self
	end
	function Mixer:constructor()
		self.assetPools = {}
		self.lastPlayed = {}
		self.channelGeneration = {}
		self.channelCue = {}
		self.busyUntil = {}
		self.claimedUntil = {}
		self.channelLayerGain = {}
		self.channelCursor = {}
		self.releaseWorkers = {}
		self.masterLinear = 0.75
		self.musicMix = 1
		self.musicDuck = 1
		self.duckToken = 0
		self.sfxMix = 1
		self.uiMix = 0.9
		self.gameplayMix = 1
		self.rewardMix = 1
		self.ambientMix = 0.75
		self.hoverSounds = true
		self.notificationSounds = true
		self.musicEnabled = true
		self.soundVariation = 0.7
		self.ready = false
		self.warm = false
		self.disposed = false
		self.warmWaiters = {}
		self.intentSerial = 0
		self.scene = "default"
		self.currentView = "Overview"
		self.sfxToken = 0
		self.lifecycleToken = 0
		self.releases = {}
		self.releaseByChannel = {}
		self.releasePump = nil
	end
	function Mixer:cueMix(cue)
		if isHoverCue(cue) and not self.hoverSounds then
			return 0
		end
		if (cue == "notification" or cue == "systemAlert" or cue == "chatReceive" or cue == "crewNudge" or cue == "noticeInfo" or cue == "noticeSuccess" or cue == "noticeWarning" or cue == "noticeError" or cue == "noticeSpecial" or cue == "noticeClose") and not self.notificationSounds then
			return 0
		end
		if cue == "reward" or cue == "unlock" or cue == "discovery" or cue == "prestige" or cue == "rebirthCharge" or cue == "rebirthBloom" or cue == "domainCharge" or cue == "domainCrack" or cue == "domainImpact" or cue == "domainReward" or cue == "wheelLand" or cue == "crateLand" or cue == "crateRare" or cue == "crateClaim" or cue == "missionClaim" or cue == "achievementClaim" or cue == "dailyClaim" or cue == "timedClaim" or cue == "seasonClaim" or cue == "mailClaim" or cue == "codeReward" or cue == "tutorialFinish" or cue == "purchaseResult" or cue == "boostReady" then
			return self.rewardMix
		end
		if cue == "hover" or cue == "click" or cue == "tick" or cue == "confirm" or cue == "locked" or cue == "error" or cue == "page" or cue == "open" or cue == "close" or cue == "settings" or cue == "scroll" or cue == "toggleOn" or cue == "toggleOff" or cue == "sliderStep" or cue == "sliderCommit" or cue == "inputFocus" or cue == "inputClear" or cue == "tabSwitch" or cue == "filterOpen" or cue == "filterPick" or cue == "amountChange" or cue == "modalOpen" or cue == "modalPop" or cue == "modalDismiss" or cue == "purchaseExit" or cue == "playerlistOpen" or cue == "playerlistSelect" or cue == "playerlistAction" or cue == "playerlistClose" or cue == "noticeInfo" or cue == "noticeSuccess" or cue == "noticeWarning" or cue == "noticeError" or cue == "noticeSpecial" or cue == "noticeClose" or cue == "tutorialStep" or cue == "hoverTick" or cue == "velocitySlide" or cue == "purchase" or cue == "purchasePress" or cue == "claimPress" or cue == "researchUnlock" or cue == "travel" or cue == "collect" then
			return uiCurve(self.uiMix) * (UI_TRIM[cue] or UI_TRIM_DEFAULT)
		end
		if UI_CUES[cue] then
			return uiCurve(self.uiMix) * (if isHoverCue(cue) then UI_TRIM.hover else UI_TRIM_DEFAULT)
		end
		return self.gameplayMix
	end
	function Mixer:makeChannel(asset, index, group)
		local sound = Instance.new("Sound")
		sound.Name = `Sfx_{index}`
		sound.SoundId = asset
		sound.Volume = 0
		sound.PlaybackSpeed = 1
		sound.Looped = false
		sound.SoundGroup = group
		sound.Parent = SoundService
		return sound
	end
	function Mixer:preloadChannels()
		local channels = {}
		local appended = {}
		local appendChannel = function(channel)
			local _condition = channel == nil
			if not _condition then
				local _channel = channel
				_condition = appended[_channel] ~= nil
			end
			if _condition then
				return nil
			end
			local _channel = channel
			appended[_channel] = true
			local _channel_1 = channel
			table.insert(channels, _channel_1)
		end
		for _, asset in BOOTSTRAP_ASSETS do
			local _result = self.assetPools[asset]
			if _result ~= nil then
				_result = _result[1]
			end
			appendChannel(_result)
		end
		if self.sheetPool ~= nil then
			appendChannel(self.sheetPool[1])
		end
		local priorityCount = #channels
		for _, asset in AUDIO_ASSET_MANIFEST do
			for _1, channel in self.assetPools[asset] or {} do
				appendChannel(channel)
			end
		end
		return {
			channels = channels,
			priorityCount = priorityCount,
		}
	end
	function Mixer:preloadSoundBank(channels, priorityCount, lifecycle)
		self.preloadWorker = task.spawn(function()
			if lifecycle ~= self.lifecycleToken then
				return nil
			end
			local failedBatches = 0
			local priorityPublished = priorityCount == 0
			if priorityPublished then
				self:markWarmFor(lifecycle)
			end
			do
				local offset = 0
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						offset += PRELOAD_BATCH_SIZE
					else
						_shouldIncrement = true
					end
					if not (offset < #channels) then
						break
					end
					if lifecycle ~= self.lifecycleToken then
						return nil
					end
					local batch = {}
					do
						local index = offset
						local _shouldIncrement_1 = false
						while true do
							if _shouldIncrement_1 then
								index += 1
							else
								_shouldIncrement_1 = true
							end
							if not (index < math.min(#channels, offset + PRELOAD_BATCH_SIZE)) then
								break
							end
							local channel = channels[index + 1]
							if channel ~= nil then
								table.insert(batch, channel)
							end
						end
					end
					local ok = pcall(function()
						return ContentProvider:PreloadAsync(batch)
					end)
					if lifecycle ~= self.lifecycleToken then
						return nil
					end
					if not ok then
						failedBatches += 1
					end
					if not priorityPublished and offset + PRELOAD_BATCH_SIZE >= priorityCount then
						priorityPublished = true
						self:markWarmFor(lifecycle)
					end
					task.wait()
				end
			end
			self:markWarmFor(lifecycle)
			self.preloadWorker = nil
			if self.preloadTimeout ~= nil then
				pcall(function()
					return task.cancel(self.preloadTimeout)
				end)
				self.preloadTimeout = nil
			end
			if failedBatches > 0 then
				ClientLog:warnEvery("audio-preload", 30, "Audio", `{failedBatches} sound batches will stream on first use`)
			else
				ClientLog:once("audio-bank-ready", "audio", `{#channels} sounds cached`)
			end
		end)
		self.preloadTimeout = task.delay(8, function()
			self.preloadTimeout = nil
			self:markWarmFor(lifecycle)
		end)
	end
	function Mixer:start()
		if self.ready then
			return nil
		end
		for _, child in SoundService:GetChildren() do
			if child:IsA("Sound") and (table.find(MUSIC_DECK_NAMES, child.Name) ~= nil or child.Name == "ViewMusicA" or child.Name == "ViewMusicB" or string.sub(child.Name, 1, 4) == "Sfx_") then
				child:Destroy()
			end
		end
		self.disposed = false
		self.ready = true
		self.lifecycleToken += 1
		local lifecycle = self.lifecycleToken
		local masterGroup = SoundService:FindFirstChild("ForgeMaster") :: SoundGroup
		if not masterGroup then
			masterGroup = Instance.new("SoundGroup")
			masterGroup.Name = "ForgeMaster"
			masterGroup.Volume = softMaster(self.masterLinear)
			masterGroup.Parent = SoundService
		end
		self.masterGroup = masterGroup
		masterGroup.Volume = softMaster(self.masterLinear)

		local group = masterGroup:FindFirstChild("ForgeSfx") :: SoundGroup
		if not group then
			group = Instance.new("SoundGroup")
			group.Name = "ForgeSfx"
			group.Volume = SFX_BUS_GAIN
			group.Parent = masterGroup
		end
		self.group = group
		group.Volume = SFX_BUS_GAIN

		local uiGroup = masterGroup:FindFirstChild("ForgeUI") :: SoundGroup
		if not uiGroup then
			uiGroup = Instance.new("SoundGroup")
			uiGroup.Name = "ForgeUI"
			uiGroup.Parent = masterGroup
		end
		self.uiGroup = uiGroup
		uiGroup.Volume = UI_BUS_GAIN

		local ambientGroup = masterGroup:FindFirstChild("ForgeAmbient") :: SoundGroup
		if not ambientGroup then
			ambientGroup = Instance.new("SoundGroup")
			ambientGroup.Name = "ForgeAmbient"
			ambientGroup.Volume = 0.5
			ambientGroup.Parent = masterGroup
		end
		self.ambientGroup = ambientGroup
		ambientGroup.Volume = self.ambientMix

		local equalizer = group:FindFirstChild("ForgeCurve") :: EqualizerSoundEffect
		if not equalizer then
			equalizer = Instance.new("EqualizerSoundEffect")
			equalizer.Name = "ForgeCurve"
			equalizer.LowGain = 0.3
			equalizer.MidGain = 1.05
			equalizer.HighGain = 1.35
			equalizer.Parent = group
		end

		local compressor = group:FindFirstChild("ForgeGlue") :: CompressorSoundEffect
		if not compressor then
			compressor = Instance.new("CompressorSoundEffect")
			compressor.Name = "ForgeGlue"
			compressor.Attack = 0.003
			compressor.Release = 0.05
			compressor.Ratio = 1.15
			compressor.Threshold = -28
			compressor.GainMakeup = 1.8
			compressor.Parent = group
		end

		local musicGroup = masterGroup:FindFirstChild("ForgeMusic") :: SoundGroup
		if not musicGroup then
			musicGroup = Instance.new("SoundGroup")
			musicGroup.Name = "ForgeMusic"
			musicGroup.Volume = 1
			musicGroup.Parent = masterGroup
		end
		self.musicGroup = musicGroup
		musicGroup.Volume = 1

		local musicEq = musicGroup:FindFirstChild("ForgeBed") :: EqualizerSoundEffect
		if not musicEq then
			musicEq = Instance.new("EqualizerSoundEffect")
			musicEq.Name = "ForgeBed"
			musicEq.Parent = musicGroup
		end
		musicEq.LowGain = 0.8
		musicEq.MidGain = -0.5
		musicEq.HighGain = -1.8
		for _, asset in AUDIO_ASSET_MANIFEST do
			local pool = {}
			do
				local index = 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						index += 1
					else
						_shouldIncrement = true
					end
					if not (index <= residentChannelCount(asset)) then
						break
					end
					local _arg0 = self:makeChannel(asset, index, group)
					table.insert(pool, _arg0)
				end
			end
			self.assetPools[asset] = pool
		end
		if SoundSheet.enabled() then
			local function sheetChannels(sheetAsset, base)
				local sheetPool = {}
				for index = 1, SHEET_CHANNELS do
					local channel = self:makeChannel(sheetAsset, base + index, group)
					channel.PlaybackRegionsEnabled = true
					table.insert(sheetPool, channel)
				end
				self.assetPools[sheetAsset] = sheetPool
				return sheetPool
			end
			local primaryAsset = SoundSheet.primaryAsset()
			local previousAsset = SoundSheet.previousAsset()
			self.primarySheetPool = if primaryAsset ~= nil then sheetChannels(primaryAsset, 100) else nil
			self.previousSheetPool = if previousAsset ~= nil then sheetChannels(previousAsset, 200) else nil
			self.sheetPool = self.primarySheetPool or self.previousSheetPool
		end
		local musicDirector = MusicDirector.new(musicGroup)
		self.musicDirector = musicDirector
		self:syncMusicState()
		musicDirector:start()
		self:startAmbienceBed(ambientGroup)
		local preload = self:preloadChannels()
		ClientLog:debug("audio", `{#preload.channels} sounds ready`)
		self:preloadSoundBank(preload.channels, preload.priorityCount, lifecycle)
	end
	-- The quiet forge bed under the music, driven by the Ambience slider (ForgeAmbient group). It
	-- played per sanctuary region until the sanctuary was removed; the uploaded beds were left unused.
	function Mixer:startAmbienceBed(ambientGroup)
		local ambience = AssetManifest.Ambience
		local region = if ambience ~= nil and ambience.Id > 0 then ambience.Regions[AMBIENCE_BED] else nil
		if region == nil then
			return
		end
		local bed = self.ambienceBed
		if bed == nil or bed.Parent == nil then
			bed = Instance.new("Sound")
			bed.Name = "ForgeAmbienceBed"
			bed.SoundId = `rbxassetid://{ambience.Id}`
			bed.PlaybackRegionsEnabled = true
			bed.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
			bed.LoopRegion = NumberRange.new(region[1], region[1] + region[2])
			bed.Looped = true
			local loudness = ambience.Loudness and ambience.Loudness[AMBIENCE_BED]
			bed.Volume = AMBIENCE_VOLUME * (if loudness then math.clamp(10 ^ ((-20 - loudness) / 20), 0.6, 1.4) else 1)
			bed.Parent = SoundService
			self.ambienceBed = bed
		end
		bed.SoundGroup = ambientGroup
		if not bed.IsPlaying then
			bed.TimePosition = region[1]
			pcall(function()
				bed:Play()
			end)
		end
	end
	function Mixer:ensureStarted()
		if self.ready then
			return true
		end
		if self.disposed then
			return false
		end
		self:start()
		return self.ready
	end
	function Mixer:markWarmFor(lifecycle)
		if lifecycle ~= self.lifecycleToken or not self.ready then
			return nil
		end
		self:markWarm()
	end
	function Mixer:markWarm()
		if self.warm then
			return nil
		end
		self.warm = true
		local _array = {}
		local _length = #_array
		local _array_1 = self.warmWaiters
		table.move(_array_1, 1, #_array_1, _length + 1, _array)
		local waiters = _array
		table.clear(self.warmWaiters)
		for _, waiter in waiters do
			waiter()
		end
	end
	function Mixer:whenWarm(callback)
		if self.disposed then
			return nil
		end
		if self.warm then
			callback()
			return nil
		end
		local _warmWaiters = self.warmWaiters
		local _callback = callback
		table.insert(_warmWaiters, _callback)
	end
	function Mixer:isWarm()
		return self.warm
	end
	function Mixer:setVolume(value)
		self.masterLinear = math.clamp(value, 0, 1)
		local master = softMaster(self.masterLinear)
		if self.masterGroup then
			self.masterGroup.Volume = master
		end
		self:syncMusicState()
	end
	function Mixer:setMusicVolume(value)
		self.musicMix = math.clamp(value, 0, 1)
		if not self.ready then
			return nil
		end
		self:syncMusicState()
	end
	function Mixer:syncMusicState()
		local director = self.musicDirector
		if director == nil then
			return nil
		end
		local mix = math.sqrt(math.clamp(self.musicMix, 0, 1))
		director:setMix(mix)
		director:setDuck(self.musicDuck)
		director:setAudible(self.musicEnabled and softMaster(self.masterLinear) > 0.001 and mix > 0.001)
	end
	function Mixer:duckMusic(depth, holdSeconds, releaseSeconds)
		if depth == nil then
			depth = 0.36
		end
		if holdSeconds == nil then
			holdSeconds = 0.28
		end
		if releaseSeconds == nil then
			releaseSeconds = 0.55
		end
		if not self.ready then
			return nil
		end
		local clamped = math.clamp(depth, 0, 0.4)
		if clamped <= 0.01 then
			return nil
		end
		self.duckToken += 1
		local token = self.duckToken
		self.duckTokenLive = token
		self.duckClamped = clamped
		self.musicDuck = 1 - clamped
		self:syncMusicState()
		self.duckReleasing = false
		self.duckReleaseAt = os.clock() + holdSeconds
		self.duckSteps = math.clamp(math.floor(releaseSeconds / 0.04 + 0.5), 4, 24)
		self.duckStep = 0
		self.duckNext = nil
		self:ensureReleasePump()
	end
	function Mixer:clearMusicDuck()
		self.duckToken += 1
		self.duckTokenLive = nil
		self.duckReleasing = false
		self.musicDuck = 1
		if self.ready then
			self:syncMusicState()
		end
	end
	function Mixer:setSfxVolume(value)
		self.sfxMix = math.clamp(value, 0, 1)
		if not self.ready then
			return nil
		end
		local sfx = softSfx(self.sfxMix)
		for _, pool in self.assetPools do
			for _1, sound in pool do
				local cue = self.channelCue[sound]
				if cue ~= nil then
					local spec = CUES[cue]
					local base = if spec ~= nil then spec.volume else SHEET_CUE_VOLUME
					sound.Volume = base * CUE_GAIN * Voicing.voiceFor(cue).gain * (self.channelLayerGain[sound] or 1) * sfx * self:cueMix(cue)
				end
			end
		end
	end
	function Mixer:configurePreferences(settings)
		local _condition = settings.UiVolume
		if _condition == nil then
			_condition = 0.9
		end
		self.uiMix = math.clamp(_condition, 0, 1)
		local _condition_1 = settings.GameplayVolume
		if _condition_1 == nil then
			_condition_1 = 1
		end
		self.gameplayMix = math.clamp(_condition_1, 0, 1)
		local _condition_2 = settings.RewardVolume
		if _condition_2 == nil then
			_condition_2 = 1
		end
		self.rewardMix = math.clamp(_condition_2, 0, 1)
		local _condition_3 = settings.AmbientVolume
		if _condition_3 == nil then
			_condition_3 = 0.75
		end
		self.ambientMix = math.clamp(_condition_3, 0, 1)
		if self.ambientGroup then self.ambientGroup.Volume = self.ambientMix end
		local _condition_4 = settings.HoverSounds
		if _condition_4 == nil then
			_condition_4 = 1
		end
		self.hoverSounds = _condition_4 >= 0.5
		local _condition_5 = settings.NotificationSounds
		if _condition_5 == nil then
			_condition_5 = 1
		end
		self.notificationSounds = _condition_5 >= 0.5
		local _condition_6 = settings.PageMusic
		if _condition_6 == nil then
			_condition_6 = 1
		end
		self.musicEnabled = _condition_6 >= 0.5
		local _condition_8 = settings.SoundVariation
		if _condition_8 == nil then
			_condition_8 = 0.7
		end
		self.soundVariation = math.clamp(_condition_8, 0, 1)
		if self.ready then
			self:setSfxVolume(self.sfxMix)
			self:syncMusicState()
		end
	end
	function Mixer:currentScene()
		return self.scene
	end
	function Mixer:setScene(scene)
		if self.scene == scene and self.ready then
			return nil
		end
		self.scene = scene
		if not self:ensureStarted() then
			return nil
		end
		if scene == "boot" or scene == "shutdown" then
			self:duckMusic(0.22, 0.4, 0.8)
		elseif self.musicDuck < 0.999 then
			self:clearMusicDuck()
		end
		self:syncMusicState()
	end
	function Mixer:setView(page, playCue)
		if playCue == nil then
			playCue = true
		end
		if not self:ensureStarted() then
			return nil
		end
		local changed = self.currentView ~= page
		self.currentView = page
		if self.scene ~= "boot" and self.scene ~= "shutdown" then
			self.scene = "default"
			if changed and playCue then
				self:play(NAVIGATION_CUE)
			end
		end
	end
	function Mixer:roundRobin(pool, asset)
		local cursor = self.channelCursor[asset]
		if cursor == nil then
			cursor = 0
		end
		cursor = (cursor + 1) % #pool
		self.channelCursor[asset] = cursor
		return pool[cursor + 1]
	end
	function Mixer:oldestInPool(pool)
		local oldest = nil
		local oldestProgress = -1
		for _, sound in pool do
			local claimedUntil = self.claimedUntil[sound]
			if claimedUntil ~= nil and claimedUntil > os.clock() then
				continue
			end
			local progress = sound.TimePosition
			if oldest == nil or progress > oldestProgress then
				oldest = sound
				oldestProgress = progress
			end
		end
		return oldest
	end
	function Mixer:countPlayingUi()
		local count = 0
		for _, pool in self.assetPools do
			for _, sound in pool do
				if sound.IsPlaying and UI_CUES[self.channelCue[sound]] then
					count += 1
				end
			end
		end
		return count
	end
	function Mixer:silenceOldestUi()
		local oldestSound = nil
		local oldestAge = -1
		for _, pool in self.assetPools do
			for _, sound in pool do
				if sound.IsPlaying and UI_CUES[self.channelCue[sound]] then
					local age = sound.TimePosition
					if oldestSound == nil or age >= oldestAge then
						oldestSound = sound
						oldestAge = age
					end
				end
			end
		end
		if oldestSound == nil then
			return nil
		end
		local generation = self.channelGeneration[oldestSound]
		if generation == nil then
			generation = 0
		end
		self.channelGeneration[oldestSound] = generation + 1
		self.busyUntil[oldestSound] = 0
		self.claimedUntil[oldestSound] = 0
		oldestSound:Stop()
		oldestSound.Volume = 0
		local job = self.releaseByChannel[oldestSound]
		if job ~= nil then
			job.phase = "idle"
		end
		return oldestSound
	end
	function Mixer:acquireChannel(spec, cue)
		local pool = self.assetPools[spec.asset]
		if pool == nil or #pool == 0 then
			return nil
		end
		local now = os.clock()
		local uiCue = UI_CUES[cue] == true
		if uiCue then
			local guard = 0
			while self:countPlayingUi() >= UI_OVERLAP_CAP and guard < UI_OVERLAP_CAP * 2 do
				if self:silenceOldestUi() == nil then
					break
				end
				guard += 1
			end
		end
		for _, sound in pool do
			local busyUntil = self.busyUntil[sound]
			if busyUntil == nil then
				busyUntil = 0
			end
			local claimedUntil = self.claimedUntil[sound]
			if claimedUntil == nil then
				claimedUntil = 0
			end
			if not sound.IsPlaying and busyUntil <= now and claimedUntil <= now then
				return sound
			end
		end
		local oldest = self:oldestInPool(pool)
		if oldest ~= nil then
			return oldest
		end
		return self:roundRobin(pool, spec.asset)
	end
	function Mixer:releaseIsStale(job)
		if self.disposed then
			return true
		end
		if self.channelGeneration[job.channel] ~= job.generation then
			return true
		end
		if job.token ~= self.sfxToken then
			return true
		end
		return false
	end
	function Mixer:pumpDuck()
		if self.duckTokenLive == nil or self.duckTokenLive ~= self.duckToken then
			return nil
		end
		if not self.duckReleasing then
			if self.duckReleaseAt ~= nil and os.clock() >= self.duckReleaseAt then
				self.duckReleasing = true
				self.duckStep = 0
				self.duckNext = os.clock()
			end
			return nil
		end
		if self.duckNext ~= nil and os.clock() < self.duckNext then
			return nil
		end
		self.duckStep += 1
		local steps = self.duckSteps
		if steps == nil or steps < 1 then
			steps = 1
		end
		if self.duckStep >= steps then
			self.musicDuck = 1
			self:syncMusicState()
			self.duckTokenLive = nil
			self.duckReleasing = false
			return nil
		end
		local alpha = self.duckStep / steps
		local clamped = self.duckClamped or 0
		self.musicDuck = (1 - clamped) + clamped * alpha
		self:syncMusicState()
		self.duckNext = os.clock() + 0.04
	end
	function Mixer:pumpCelebration()
		local queue = self.celebrationQueue
		if queue == nil then
			return nil
		end
		local now = os.clock()
		local index = 1
		while index <= #queue do
			local item = queue[index]
			if item.token ~= self.celebrationToken then
				table.remove(queue, index)
			elseif now >= item.at then
				table.remove(queue, index)
				self:playChannel(item.cue, true, item.pitch)
			else
				index += 1
			end
		end
	end
	function Mixer:pumpReleases()
		self:pumpDuck()
		self:pumpCelebration()
		for _, job in self.releases do
			local phase = job.phase
			if phase == nil or phase == "idle" then
				continue
			end
			if self:releaseIsStale(job) then
				job.phase = "idle"
				continue
			end
			local channel = job.channel
			local spec = job.spec
			if spec == nil then
				job.phase = "idle"
				continue
			end
			local speed = math.max(0.05, job.speed)
			if phase == "length" then
				if channel.TimeLength > 0 then
					local natural = channel.TimeLength / speed
					local familyDecay = Voicing.voiceFor(job.cue).decay
					local trimmed = if spec.stopAfter ~= nil then math.max(0.08, spec.stopAfter * familyDecay / speed) else nil
					local seconds = if trimmed ~= nil then math.min(trimmed, natural) else natural
					self.busyUntil[channel] = os.clock() + seconds
					if spec.stopAfter == nil then
						job.phase = "idle"
					else
						job.releaseAt = os.clock() + seconds
						job.phase = "hold"
					end
				elseif os.clock() - job.started >= 2 then
					job.phase = "idle"
				end
			elseif phase == "hold" then
				if os.clock() >= job.releaseAt then
					if not channel.IsPlaying then
						job.phase = "idle"
					else
						job.fullVolume = spec.volume * CUE_GAIN * Voicing.voiceFor(job.cue).gain * (self.channelLayerGain[channel] or 1) * softSfx(self.sfxMix) * self:cueMix(job.cue)
						job.fadeStep = 0
						job.phase = "fade"
					end
				end
			elseif phase == "fade" then
				if not channel.IsPlaying then
					job.phase = "idle"
				else
					job.fadeStep += 1
					local step = job.fadeStep
					channel.Volume = job.fullVolume * (1 - step / TRIM_RELEASE_STEPS)
					if step >= TRIM_RELEASE_STEPS then
						channel:Stop()
						channel.Volume = 0
						self.busyUntil[channel] = 0
						self.claimedUntil[channel] = 0
						job.phase = "idle"
					end
				end
			end
		end
	end
	function Mixer:ensureReleasePump()
		if self.releasePump ~= nil or self.disposed then
			return nil
		end
		local pump
		pump = task.spawn(function()
			while not self.disposed do
				self:pumpReleases()
				task.wait()
			end
		end)
		self.releasePump = pump
		self.releaseWorkers[pump] = true
	end
	function Mixer:scheduleRelease(channel, cue, spec, generation, token, speed)
		local job = self.releaseByChannel[channel]
		if job == nil then
			job = {
				channel = channel,
			}
			self.releaseByChannel[channel] = job
			table.insert(self.releases, job)
		end
		job.cue = cue
		job.spec = spec
		job.generation = generation
		job.token = token
		job.speed = speed
		job.started = os.clock()
		job.fadeStep = 0
		job.releaseAt = nil
		job.fullVolume = nil
		job.phase = "length"
		self:ensureReleasePump()
	end
	function Mixer:playChannel(cue, bypassCooldown, speedMult)
		if bypassCooldown == nil then
			bypassCooldown = false
		end
		if speedMult == nil then
			speedMult = 1
		end
		if SILENT_CUES[cue] then
			return false
		end
		-- names that have no voice of their own borrow the closest one instead of playing nothing
		if CUES[cue] == nil and SoundSheet.region(cue) == nil then
			if CUE_ALIAS[cue] ~= nil then
				cue = CUE_ALIAS[cue]
			elseif string.sub(cue, 1, 7) == "navOpen" then
				cue = "open"
			end
		end
		if not self:ensureStarted() then
			return false
		end
		local token = self.sfxToken
		local cueMix = self:cueMix(cue)
		if softMaster(self.masterLinear) <= 0.001 or self.sfxMix <= 0.001 or cueMix <= 0.001 then
			ClientLog:warnEvery(`audio-mix-{cue}`, 30, "Audio", `{cue} muted — master={softMaster(self.masterLinear)} sfx={self.sfxMix} cueMix={cueMix}`)
			return false
		end
		local spec = CUES[cue]
		if spec == nil then
			if string.sub(cue, 1, 8) == "navHover" then
				spec = CUES.navHover
			elseif string.sub(cue, -5) == "Hover" then
				spec = CUES.hover
			elseif cue == "button" then
				spec = CUES.click
			end
		end
		if spec == nil then
			local start = SoundSheet.region(cue)
			if start ~= nil then
				spec = {
					asset = UI_CLICK,
					volume = SHEET_CUE_VOLUME,
					speed = 1,
					variance = 0.006,
					cooldown = 0.05,
					stopAfter = 0.6,
				}
			end
		end
		if spec == nil or spec.asset == "" then
			if spec == nil then
				ClientLog:warnEvery(`audio-missing-{cue}`, 30, "Audio", `unknown cue "{cue}"`)
			end
			return false
		end
		local now = os.clock()
		local _lastPlayed = self.lastPlayed
		local _cue = cue
		local _condition = _lastPlayed[_cue]
		if _condition == nil then
			_condition = -math.huge
		end
		local previous = _condition
		if not bypassCooldown and isHoverCue(cue) and now - previous < math.max(0.12, spec.cooldown) then
			return false
		end
		local _condition_1 = cue == "hover"
		if _condition_1 then
			local _condition_2 = self.lastPlayed.click
			if _condition_2 == nil then
				_condition_2 = -math.huge
			end
			_condition_1 = now - _condition_2 < 0.04
		end
		if _condition_1 then
			return false
		end
		local liveVoices = 0
		for _, pool in self.assetPools do
			for _1, sound in pool do
				if sound.IsPlaying then
					liveVoices += 1
				end
			end
		end
		if liveVoices >= VOICE_CAP and not bypassCooldown then
			local decorative = cue == "hover" or cue == "hoverTick" or cue == "scroll" or cue == "tick" or cue == "wheelTick" or cue == "crateTick" or cue == "sliderStep" or cue == "filterPick" or cue == "amountChange" or cue == "cardDraw" or cue == "bootClang" or cue == "bootTension" or string.sub(cue, 1, 8) == "navHover" or string.sub(cue, -5) == "Hover"
			if decorative then
				return false
			end
		end
		if not bypassCooldown and now - previous < DUPLICATE_CUE_SECONDS then
			return false
		end
		if self.sheetPool ~= nil and self:sheetLoaded() then
			local start, length = SoundSheet.region(cue)
			if start ~= nil and length ~= nil then
				return self:playSheet(cue, spec, start, length, speedMult, now, token)
			end
		end
		local channel = self:acquireChannel(spec, cue)
		if channel == nil then
			return false
		end
		local _condition_2 = self.channelGeneration[channel]
		if _condition_2 == nil then
			_condition_2 = 0
		end
		local generation = _condition_2 + 1
		self.channelGeneration[channel] = generation
		local _channelCue = self.channelCue
		local _cue_1 = cue
		_channelCue[channel] = _cue_1
		self.channelLayerGain[channel] = nil
		local voice = Voicing.voiceFor(cue)
		local pitchSpread = if BUTTON_PITCH_CUES[cue] then 1 + (math.random() * 2 - 1) * 0.01 * self.soundVariation else 1
		local variance = if spec.variance > 0 then (math.random() * 2 - 1) * math.min(spec.variance, 0.015) * self.soundVariation else 0
		local speed = math.clamp(spec.speed * voice.pitch * math.clamp(speedMult, 0.82, 1.28) * pitchSpread + variance, 0.28, 2.1)
		local ambientCue = cue == "reactor" or cue == "reactorReady" or cue == "reactorPulse" or cue == "reactorChannel" or cue == "reactorStabilize" or cue == "autoForge"
		channel.SoundGroup = if UI_CUES[cue] then self.uiGroup elseif ambientCue then self.ambientGroup else self.group
		channel.Volume = spec.volume * CUE_GAIN * voice.gain * softSfx(self.sfxMix) * cueMix
		channel.PlaybackSpeed = speed
		channel.Looped = false
		paintCue(channel, cue)
		if token ~= self.sfxToken or channel.Parent == nil or self.channelGeneration[channel] ~= generation then
			return false
		end
		if channel.IsPlaying then
			channel:Stop()
		end
		channel.TimePosition = 0
		local played = pcall(function()
			return channel:Play()
		end)
		if not played then
			self.busyUntil[channel] = 0
			self.claimedUntil[channel] = 0
			ClientLog:warnEvery(`audio-play-{cue}`, 20, "Audio", `{cue} could not start`)
			return false
		end
		self.claimedUntil[channel] = now + CHANNEL_CLAIM_SECONDS
		local _lastPlayed_1 = self.lastPlayed
		local _cue_2 = cue
		_lastPlayed_1[_cue_2] = now
		self:scheduleRelease(channel, cue, spec, generation, token, speed)
		self:playLayer(cue, token)
		local duckDepth = MUSIC_DUCK_CUES[cue]
		if duckDepth ~= nil then
			self:duckMusic(duckDepth, math.max(0.18, (spec.stopAfter or 0.45) * 0.55), 0.62)
		end
		return true
	end
	function Mixer:sheetLoaded()
		if self.sheetReady then
			return true
		end
		local function loaded(pool)
			local probe = pool ~= nil and pool[1] or nil
			return probe ~= nil and probe.IsLoaded and probe.TimeLength > 1
		end
		if loaded(self.primarySheetPool) then
			self.sheetPool = self.primarySheetPool
			SoundSheet.use(false)
			self.sheetReady = true
			ClientLog:once("audio-sheet-ready", "audio", "sound sheet loaded")
			return true
		end
		if loaded(self.previousSheetPool) then
			self.sheetPool = self.previousSheetPool
			SoundSheet.use(true)
			ClientLog:once("audio-sheet-previous", "audio", "new sound sheet not available yet; playing the previous one")
			return true
		end
		return false
	end
	function Mixer:playSheet(cue, spec, start, length, speedMult, now, token)
		local pool = self.sheetPool
		local channel = nil
		local oldest = math.huge
		for _, sound in pool do
			local busy = math.max(self.busyUntil[sound] or 0, self.claimedUntil[sound] or 0)
			if busy <= now and not sound.IsPlaying then
				channel = sound
				break
			end
			if busy < oldest then
				oldest = busy
				channel = sound
			end
		end
		if channel == nil then
			return false
		end
		local generation = (self.channelGeneration[channel] or 0) + 1
		self.channelGeneration[channel] = generation
		self.channelCue[channel] = cue
		local level = SoundSheet.gain(cue)
		self.channelLayerGain[channel] = level
		local variance = if spec.variance > 0 then (math.random() * 2 - 1) * math.min(spec.variance, 0.03) * self.soundVariation else 0
		-- the sheet's interface voices are tuned to one scale, so only a hair of spread keeps them in tune
		local spread = if BUTTON_PITCH_CUES[cue] then 1 + (math.random() * 2 - 1) * 0.01 * self.soundVariation else 1
		local speed = math.clamp(math.clamp(speedMult, 0.82, 1.28) * spread + variance, 0.5, 2)
		local cueMix = self:cueMix(cue)
		local ambientCue = cue == "reactor" or cue == "reactorReady" or cue == "reactorPulse" or cue == "reactorChannel" or cue == "reactorStabilize" or cue == "autoForge"
		channel.SoundGroup = if UI_CUES[cue] then self.uiGroup elseif ambientCue then self.ambientGroup else self.group
		if channel.IsPlaying then
			channel:Stop()
		end
		channel.Looped = false
		channel.PlaybackRegion = NumberRange.new(start, start + length)
		channel.PlaybackSpeed = speed
		channel.Volume = spec.volume * CUE_GAIN * Voicing.voiceFor(cue).gain * level * softSfx(self.sfxMix) * cueMix
		paintCue(channel, cue, true)
		channel.TimePosition = start
		if token ~= self.sfxToken or channel.Parent == nil then
			return false
		end
		local played = pcall(function()
			return channel:Play()
		end)
		if not played then
			ClientLog:warnEvery(`audio-sheet-{cue}`, 20, "Audio", `{cue} could not start from the sound sheet`)
			return false
		end
		self.claimedUntil[channel] = now + CHANNEL_CLAIM_SECONDS
		self.busyUntil[channel] = now + length / speed
		self.lastPlayed[cue] = now
		ClientLog:once("audio-first-sheet-cue", "audio", `first cue {cue} volume={string.format("%.3f", channel.Volume)} bus={channel.SoundGroup and channel.SoundGroup.Name or "none"} master={string.format("%.2f", softMaster(self.masterLinear))} ui={string.format("%.2f", self.uiMix)} sfx={string.format("%.2f", self.sfxMix)}`)
		local duckDepth = MUSIC_DUCK_CUES[cue]
		if duckDepth ~= nil then
			self:duckMusic(duckDepth, math.max(0.18, length * 0.45), 0.62)
		end
		return true
	end
	function Mixer:playLayer(cue, token)
		local layer = Voicing.layerFor(cue)
		if layer == nil then
			return nil
		end
		local asset = LAYER_SOURCES[layer.source]
		if asset == nil then
			return nil
		end
		local pool = self.assetPools[asset]
		if pool == nil or #pool == 0 then
			return nil
		end
		task.delay(layer.delay, function()
			if self.disposed or token ~= self.sfxToken then
				return nil
			end
			local now = os.clock()
			local channel = nil
			for _, sound in pool do
				local claimedUntil = self.claimedUntil[sound]
				if claimedUntil == nil then
					claimedUntil = 0
				end
				if not sound.IsPlaying and claimedUntil <= now then
					channel = sound
					break
				end
			end
			if channel == nil then
				return nil
			end
			local generation = self.channelGeneration[channel]
			if generation == nil then
				generation = 0
			end
			generation += 1
			self.channelGeneration[channel] = generation
			self.channelCue[channel] = cue
			self.channelLayerGain[channel] = layer.volume
			local voice = Voicing.voiceFor(cue)
			channel.SoundGroup = if UI_CUES[cue] then self.uiGroup else self.group
			channel.Volume = (if CUES[cue] ~= nil then CUES[cue].volume else SHEET_CUE_VOLUME) * CUE_GAIN * voice.gain * layer.volume * softSfx(self.sfxMix) * self:cueMix(cue)
			channel.PlaybackSpeed = math.clamp(layer.pitch, 0.28, 2.1)
			channel.Looped = false
			paintCue(channel, cue)
			channel.TimePosition = 0
			local ok = pcall(function()
				return channel:Play()
			end)
			if not ok then
				return nil
			end
			self.claimedUntil[channel] = os.clock() + CHANNEL_CLAIM_SECONDS
			self:scheduleRelease(channel, cue, CUES[cue] or { stopAfter = 0.6 }, generation, token, channel.PlaybackSpeed)
			return nil
		end)
		return nil
	end
	function Mixer:play(cue, speedMult)
		if speedMult == nil then
			speedMult = 1
		end
		if not self:ensureStarted() then
			return false
		end
		local played = self:playChannel(cue, false, speedMult)
		if not played then
			return false
		end
		self.intentSerial += 1
		return true
	end
	function Mixer:playCelebration(cues, staggerSeconds)
		if staggerSeconds == nil then
			staggerSeconds = 0.07
		end
		if not self:ensureStarted() or #cues == 0 then
			return false
		end
		self:duckMusic(0.46, 0.2 + staggerSeconds * #cues, 0.7)
		self.celebrationToken = (self.celebrationToken or 0) + 1
		local token = self.celebrationToken
		self.celebrationQueue = {}
		local now = os.clock()
		local firedFirst = false
		for i = 0, #cues - 1 do
			local cue = cues[i + 1]
			local pitchLift = 1 + i * 0.045
			if i == 0 then
				firedFirst = self:playChannel(cue, true, pitchLift)
			else
				table.insert(self.celebrationQueue, {
					cue = cue,
					at = now + staggerSeconds * i,
					pitch = pitchLift,
					token = token,
				})
			end
		end
		self:ensureReleasePump()
		if not firedFirst then
			return false
		end
		self.intentSerial += 1
		return true
	end
	function Mixer:captureIntent()
		return self.intentSerial
	end
	function Mixer:playIfUnclaimed(marker, cue, speedMult)
		if speedMult == nil then
			speedMult = 1
		end
		if marker ~= self.intentSerial then
			return false
		end
		return self:play(cue, speedMult)
	end
	function Mixer:stopSfx()
		self.sfxToken += 1
		for _, pool in self.assetPools do
			for _1, sound in pool do
				local _channelGeneration = self.channelGeneration
				local _condition = self.channelGeneration[sound]
				if _condition == nil then
					_condition = 0
				end
				_channelGeneration[sound] = _condition + 1
				self.busyUntil[sound] = 0
				self.claimedUntil[sound] = 0
				if sound.IsPlaying then
					sound:Stop()
				end
				sound.Looped = false
				sound.TimePosition = 0
			end
		end
	end
	function Mixer:dispose()
		self.disposed = true
		if not self.ready and self.group == nil and self.musicDirector == nil then
			return nil
		end
		self.lifecycleToken += 1
		if self.preloadWorker ~= nil then
			pcall(function()
				return task.cancel(self.preloadWorker)
			end)
		end
		if self.preloadTimeout ~= nil then
			pcall(function()
				return task.cancel(self.preloadTimeout)
			end)
		end
		self.preloadWorker = nil
		self.preloadTimeout = nil
		for worker in self.releaseWorkers do
			pcall(function()
				return task.cancel(worker)
			end)
		end
		table.clear(self.releaseWorkers)
		self.releasePump = nil
		self.celebrationToken = (self.celebrationToken or 0) + 1
		self.celebrationQueue = nil
		self.duckToken += 1
		self.duckTokenLive = nil
		self.duckReleasing = false
		if self.releases ~= nil then
			table.clear(self.releases)
		end
		if self.releaseByChannel ~= nil then
			table.clear(self.releaseByChannel)
		end
		self.sfxToken += 1
		for _, pool in self.assetPools do
			for _1, sound in pool do
				pcall(function()
					return sound:Destroy()
				end)
			end
		end
		table.clear(self.assetPools)
		table.clear(self.lastPlayed)
		table.clear(self.channelGeneration)
		table.clear(self.channelCue)
		table.clear(self.busyUntil)
		table.clear(self.claimedUntil)
		table.clear(self.channelLayerGain)
		table.clear(self.channelCursor)
		local _result = self.musicDirector
		if _result ~= nil then
			_result:dispose()
		end
		self.musicDirector = nil
		local _result_1 = self.group
		if _result_1 ~= nil then
			_result_1:Destroy()
		end
		self.group = nil
		local _result_2 = self.musicGroup
		if _result_2 ~= nil then
			_result_2:Destroy()
		end
		self.musicGroup = nil
		if self.uiGroup then self.uiGroup:Destroy(); self.uiGroup = nil end
		if self.ambienceBed then self.ambienceBed:Destroy(); self.ambienceBed = nil end
		if self.ambientGroup then self.ambientGroup:Destroy(); self.ambientGroup = nil end
		if self.masterGroup then
			if #self.masterGroup:GetChildren() == 0 then self.masterGroup:Destroy() end
			self.masterGroup = nil
		end
		self.ready = false
		self.warm = false
		table.clear(self.warmWaiters)
		self.scene = "default"
		self.currentView = "Overview"
		self.musicDuck = 1
		self.duckToken += 1
	end
end
local Audio = Mixer.new()
local isActivationInput = function(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Gamepad1 or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space
end
local function hookGuiClicks(root)
	local tracked = {}
	local disposed = false
	local inputMarker = -1
	local inputStartedAt = -math.huge
	local globalInput = UserInputService.InputBegan:Connect(function(input)
		if not isActivationInput(input) then
			return nil
		end
		inputMarker = Audio:captureIntent()
		inputStartedAt = os.clock()
	end)
	local release = function(instance)
		local _instance = instance
		local connections = tracked[_instance]
		if connections == nil then
			return nil
		end
		local _instance_1 = instance
		tracked[_instance_1] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	local attachButton = function(button)
		local _button = button
		if tracked[_button] ~= nil then
			return nil
		end
		local pressMarker = -1
		local pressedAt = -math.huge
		local connections = {}
		local _arg0 = button.InputBegan:Connect(function(input)
			if not isActivationInput(input) then
				return nil
			end
			local now = os.clock()
			pressMarker = if now - inputStartedAt <= 0.15 then inputMarker else Audio:captureIntent()
			pressedAt = now
		end)
		table.insert(connections, _arg0)
		local _arg0_1 = button.Activated:Connect(function()
			if not button.Active or not button.Selectable then
				return nil
			end
			if os.clock() - pressedAt > 2 or pressMarker < 0 then
				return nil
			end
			local marker = pressMarker
			pressMarker = -1
			Audio:playIfUnclaimed(marker, "click")
		end)
		table.insert(connections, _arg0_1)
		local _arg0_2 = button.MouseEnter:Connect(function()
			if not button.Active or not button.Selectable then
				return nil
			end
			local marker = Audio:captureIntent()
			Audio:playIfUnclaimed(marker, "hover")
		end)
		table.insert(connections, _arg0_2)
		local _arg0_3 = button.SelectionGained:Connect(function()
			if not button.Active or not button.Selectable then
				return nil
			end
			local marker = Audio:captureIntent()
			Audio:playIfUnclaimed(marker, "hover")
		end)
		table.insert(connections, _arg0_3)
		local _arg0_4 = button.Destroying:Connect(function()
			return release(button)
		end)
		table.insert(connections, _arg0_4)
		local _button_1 = button
		tracked[_button_1] = connections
	end
	local attachTextBox = function(textBox)
		local _textBox = textBox
		if tracked[_textBox] ~= nil then
			return nil
		end
		local focusMarker = -1
		local pressedAt = -math.huge
		local connections = {}
		local _arg0 = textBox.InputBegan:Connect(function(input)
			if not isActivationInput(input) then
				return nil
			end
			local now = os.clock()
			focusMarker = if now - inputStartedAt <= 0.15 then inputMarker else Audio:captureIntent()
			pressedAt = now
		end)
		table.insert(connections, _arg0)
		local _arg0_1 = textBox.Focused:Connect(function()
			if os.clock() - pressedAt > 2 or focusMarker < 0 then
				return nil
			end
			local marker = focusMarker
			focusMarker = -1
			Audio:playIfUnclaimed(marker, "inputFocus")
		end)
		table.insert(connections, _arg0_1)
		local _arg0_2 = textBox.Destroying:Connect(function()
			return release(textBox)
		end)
		table.insert(connections, _arg0_2)
		local _textBox_1 = textBox
		tracked[_textBox_1] = connections
	end
	local attach = function(instance)
		if disposed then
			return nil
		end
		if root:IsA("PlayerGui") then
			local cursor = instance
			local gameLayer = false
			while cursor ~= nil and cursor ~= root do
				if cursor:IsA("ScreenGui") then
					gameLayer = string.sub(cursor.Name, 1, 11) == "AstralForge"
					break
				end
				cursor = cursor.Parent
			end
			if not gameLayer then
				return nil
			end
		end
		if instance:IsA("GuiButton") then
			attachButton(instance)
		elseif instance:IsA("TextBox") then
			attachTextBox(instance)
		end
	end
	for _, descendant in root:GetDescendants() do
		attach(descendant)
	end
	local added = root.DescendantAdded:Connect(attach)
	return function()
		if disposed then
			return nil
		end
		disposed = true
		globalInput:Disconnect()
		added:Disconnect()
		for instance in tracked do
			release(instance)
		end
	end
end
return {
	buttonAudioCue = buttonAudioCue,
	hoverCueFor = hoverCueFor,
	hookGuiClicks = hookGuiClicks,
	AUDIO_ASSET_MANIFEST = AUDIO_ASSET_MANIFEST,
	Audio = Audio,
}
end

__defs["audioVoicing"] = function()

type Voice = {
	high: number,
	mid: number,
	low: number,
	reverbDecay: number,
	reverbWet: number,
	drive: number,
	pitch: number,
	decay: number,
	gain: number,
}

type Layer = {
	source: string,
	pitch: number,
	volume: number,
	delay: number,
}

local Voicing = {} :: {
	familyOf: (string) -> string,
	voiceFor: (string) -> Voice,
	families: () -> { [string]: Voice },
	cueFamilies: () -> { [string]: string },
	clampGain: (number) -> number,
	layerFor: (string) -> Layer?,
	layers: () -> { [string]: Layer },
}

local FAMILIES: { [string]: Voice } = {
	chrome = {
		high = 5, mid = -12, low = -24,
		reverbDecay = 0, reverbWet = 0,
		drive = 0, pitch = 1.34, decay = 0.36, gain = 0.61,
	},
	interface = {
		high = -2, mid = 4, low = -6,
		reverbDecay = 0.25, reverbWet = 0.024,
		drive = 0, pitch = 1, decay = 0.65, gain = 0.85,
	},
	motion = {
		high = 3, mid = -10, low = -12,
		reverbDecay = 0.55, reverbWet = 0.072,
		drive = 0, pitch = 0.94, decay = 0.88, gain = 0.75,
	},
	forge = {
		high = -10, mid = 2, low = 9,
		reverbDecay = 0.45, reverbWet = 0.056,
		drive = 0.044, pitch = 0.74, decay = 0.98, gain = 0.95,
	},
	currency = {
		high = 6, mid = 0, low = -14,
		reverbDecay = 0.4, reverbWet = 0.048,
		drive = 0, pitch = 1.46, decay = 0.59, gain = 0.85,
	},
	reward = {
		high = 4, mid = 3, low = -2,
		reverbDecay = 0.9, reverbWet = 0.104,
		drive = 0, pitch = 1.08, decay = 1.11, gain = 0.99,
	},
	arcane = {
		high = 1, mid = -4, low = 2,
		reverbDecay = 1.6, reverbWet = 0.168,
		drive = 0.016, pitch = 0.66, decay = 1.43, gain = 1.02,
	},
	reactor = {
		high = -8, mid = -8, low = 7,
		reverbDecay = 1.2, reverbWet = 0.12,
		drive = 0.024, pitch = 0.82, decay = 1.17, gain = 0.7,
	},
	denial = {
		high = -30, mid = -8, low = 8,
		reverbDecay = 0.15, reverbWet = 0.016,
		drive = 0.068, pitch = 0.58, decay = 0.78, gain = 0.85,
	},
	alert = {
		high = -14, mid = 4, low = 4,
		reverbDecay = 0.3, reverbWet = 0.04,
		drive = 0.028, pitch = 0.88, decay = 0.81, gain = 0.9,
	},
	notice = {
		high = 2, mid = -2, low = -8,
		reverbDecay = 0.65, reverbWet = 0.08,
		drive = 0, pitch = 1.12, decay = 0.72, gain = 0.77,
	},
	ceremony = {
		high = 0, mid = 0, low = 10,
		reverbDecay = 1.1, reverbWet = 0.112,
		drive = 0.028, pitch = 0.62, decay = 1.56, gain = 0.97,
	},
	mechanism = {
		high = 4, mid = -6, low = -16,
		reverbDecay = 0.18, reverbWet = 0.02,
		drive = 0.012, pitch = 1.22, decay = 0.39, gain = 0.73,
	},
	social = {
		high = 1, mid = 6, low = -6,
		reverbDecay = 0.35, reverbWet = 0.044,
		drive = 0, pitch = 1.26, decay = 0.59, gain = 0.68,
	},
}

local CUE_FAMILY: { [string]: string } = {}

local function assign(family: string, cues: { string })
	for _, cue in cues do
		CUE_FAMILY[cue] = family
	end
end

assign("chrome", {
	"hover", "hoverTick", "scroll", "tick", "sliderStep", "filterPick",
	"amountChange", "cardDraw", "storyPage", "wheelTick", "crateTick",
	"navHover", "sanctuaryHover",
})

assign("interface", {
	"click", "confirm", "settings", "toggleOn", "toggleOff", "sliderCommit",
	"inputFocus", "inputClear", "claimPress", "equip", "itemLink", "itemUnlink",
	"cardBlock", "playerlistSelect", "playerlistAction", "roleChange",
	"tutorialStep", "codeSubmit", "machineInstall", "mailRead",
	"sanctuaryClick",
})

assign("motion", {
	"page", "tabSwitch", "open", "close", "modalOpen", "modalPop", "modalDismiss",
	"filterOpen", "travel", "preview", "velocitySlide", "mail", "playerlistOpen",
	"playerlistClose", "purchaseExit", "zoneSelect", "expeditionLaunch",
	"expeditionReturn", "boostOpen", "cardPlay", "gameExit",
	"waystoneTravel",
})

assign("forge", {
	"salvage", "salvageCrunch", "reset", "memberRemove", "adminArm",
	"adminExecute", "cardEndTurn", "echoDismantle", "labRoute", "autoForge",
	"oreMine", "wardenStrike", "wardenCrit",
})

assign("currency", {
	"purchase", "purchasePress", "purchaseResult", "vaultBank", "vaultDeposit",
	"guildDeposit", "guildCreate", "collect", "coin",
})

assign("reward", {
	"reward", "unlock", "successChime", "dailyClaim", "timedClaim",
	"seasonClaim", "missionClaim", "achievementClaim", "mailClaim", "codeReward",
	"tutorialFinish", "discovery", "researchUnlock", "zoneUnlock", "puzzleClear",
	"comboMilestone", "offlineCollect", "offlineOpen", "crateClaim", "crateRare",
	"wheelLand", "crateLand", "echoClaim", "oreCollect",
})

assign("arcane", {
	"prestige", "rebirthCharge", "rebirthBloom", "domainCharge", "domainCrack",
	"domainImpact", "domainReward", "domainBind", "echoCapture", "echoTune",
	"echoEquip", "cardPower", "storyReveal",
	"wardenForming", "wardenAwake", "wardenSlamCharge", "wardenSlam",
	"wardenDefeat", "wardenEscape",
})

assign("reactor", {
	"reactor", "reactorReady", "reactorPulse", "reactorChannel",
	"reactorStabilize", "reactorSurge", "cardEnergy",
})

assign("denial", {
	"error", "errorBuzz", "noticeError", "requestTimeout", "requestBlocked",
	"locked", "dangerPress",
})

assign("alert", {
	"noticeWarning", "systemAlert", "gamePause",
})

assign("notice", {
	"notification", "noticeInfo", "noticeSuccess", "noticeSpecial", "noticeClose",
	"gameResume", "boostReady", "boostActivate", "queueStart", "queueStop",
	"regionEnter",
})

assign("ceremony", {
	"boot", "bootStart", "bootIgnite", "bootTension", "bootWhoosh", "bootStrike",
	"bootClang", "bootSpark", "bootFizz", "bootRumble", "bootImpact", "bootReady",
	"bootFinaleFlip", "bootFinaleBang", "bootAnvilSplit", "bootSlamCharge",
	"bootSlamAir", "bootDebris", "bootFractureTail", "bootGravity",
	"bootAftershock", "storyOpen", "story", "storyBeat",
})

assign("mechanism", {
	"wheelStart", "wheelCharge", "wheelSlow", "wheelBrake", "crateOpen",
	"crateCharge", "crateNear", "crateBrake", "puzzleTap", "leaderboardSwitch",
})

assign("social", {
	"chatSend", "chatReceive", "invite", "crewNudge", "guildJoin", "guildLeave",
})

local NEUTRAL: Voice = FAMILIES.interface

function Voicing.familyOf(cue: string): string
	return CUE_FAMILY[cue] or "interface"
end

function Voicing.voiceFor(cue: string): Voice
	return FAMILIES[Voicing.familyOf(cue)] or NEUTRAL
end

function Voicing.families(): { [string]: Voice }
	return FAMILIES
end

function Voicing.cueFamilies(): { [string]: string }
	return CUE_FAMILY
end

function Voicing.clampGain(value: number): number
	return math.clamp(value, -80, 10)
end

local LAYERS: { [string]: Layer } = {
	domainImpact = { source = "click", pitch = 0.42, volume = 0.5, delay = 0.012 },
	domainCharge = { source = "confirm", pitch = 0.5, volume = 0.42, delay = 0.03 },
	domainReward = { source = "confirm", pitch = 1.5, volume = 0.34, delay = 0.05 },
	prestige = { source = "click", pitch = 0.46, volume = 0.46, delay = 0.015 },
	rebirthBloom = { source = "confirm", pitch = 1.42, volume = 0.38, delay = 0.045 },
	reward = { source = "hover", pitch = 1.62, volume = 0.3, delay = 0.04 },
	achievementClaim = { source = "hover", pitch = 1.55, volume = 0.3, delay = 0.045 },
	seasonClaim = { source = "hover", pitch = 1.48, volume = 0.32, delay = 0.05 },
	crateRare = { source = "hover", pitch = 1.7, volume = 0.34, delay = 0.035 },
	zoneUnlock = { source = "confirm", pitch = 1.34, volume = 0.3, delay = 0.05 },
	salvageCrunch = { source = "click", pitch = 0.5, volume = 0.4, delay = 0.01 },
	adminExecute = { source = "click", pitch = 0.44, volume = 0.38, delay = 0.012 },
	purchaseResult = { source = "hover", pitch = 1.66, volume = 0.26, delay = 0.03 },
	vaultDeposit = { source = "hover", pitch = 1.58, volume = 0.26, delay = 0.028 },
	error = { source = "click", pitch = 0.4, volume = 0.36, delay = 0.02 },
	requestTimeout = { source = "click", pitch = 0.38, volume = 0.34, delay = 0.025 },
	bootFinaleBang = { source = "click", pitch = 0.4, volume = 0.5, delay = 0.014 },
	bootImpact = { source = "click", pitch = 0.48, volume = 0.44, delay = 0.012 },
	wardenSlam = { source = "click", pitch = 0.4, volume = 0.5, delay = 0.012 },
	wardenDefeat = { source = "confirm", pitch = 1.46, volume = 0.36, delay = 0.05 },
	wardenCrit = { source = "hover", pitch = 1.6, volume = 0.28, delay = 0.03 },
}

function Voicing.layerFor(cue: string): Layer?
	return LAYERS[cue]
end

function Voicing.layers(): { [string]: Layer }
	return LAYERS
end

return Voicing
end

__defs["soundSheet"] = function()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manifest = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("AssetManifest")

local SoundSheet = {}

local TARGET_LOUDNESS = -20

SoundSheet.VOICE = table.freeze({
	hover = "hover",
	hoverTick = "hoverTick",
	click = "click",
	tick = "tick",
	confirm = "confirm",
	successChime = "successChime",
	locked = "locked",
	error = "error",
	errorBuzz = "errorBuzz",
	page = "page",
	mail = "mail",
	story = "story",
	open = "open",
	close = "close",
	settings = "settings",
	scroll = "scroll",
	toggleOn = "toggleOn",
	toggleOff = "toggleOff",
	sliderStep = "sliderStep",
	sliderCommit = "sliderCommit",
	inputFocus = "inputFocus",
	inputClear = "inputClear",
	tabSwitch = "tabSwitch",
	filterOpen = "filterOpen",
	filterPick = "filterPick",
	amountChange = "amountChange",
	modalOpen = "modalOpen",
	modalPop = "modalPop",
	modalDismiss = "modalDismiss",
	purchaseExit = "purchaseExit",
	playerlistOpen = "playerlistOpen",
	playerlistSelect = "playerlistSelect",
	playerlistAction = "playerlistAction",
	playerlistClose = "playerlistClose",
	noticeInfo = "noticeInfo",
	noticeSuccess = "noticeSuccess",
	noticeWarning = "noticeWarning",
	noticeError = "noticeError",
	noticeSpecial = "noticeSpecial",
	noticeClose = "noticeClose",
	chatSend = "chatSend",
	chatReceive = "chatReceive",
	velocitySlide = "velocitySlide",
	purchasePress = "purchasePress",
	claimPress = "claimPress",
	dangerPress = "dangerPress",
	preview = "preview",
	reset = "reset",
	roleChange = "roleChange",
	memberRemove = "memberRemove",
	mailRead = "mailRead",
	storyPage = "storyPage",
	leaderboardSwitch = "leaderboardSwitch",
	requestBlocked = "requestBlocked",
	requestTimeout = "requestTimeout",
	gamePause = "gamePause",
	gameResume = "gameResume",
	gameExit = "gameExit",
	notification = "notification",
	systemAlert = "systemAlert",
	crewNudge = "crewNudge",
	invite = "invite",
	codeSubmit = "codeSubmit",
	zoneSelect = "zoneSelect",
	labRoute = "labRoute",
	equip = "equip",
	itemLink = "itemLink",
	itemUnlink = "itemUnlink",
	queueStart = "queueStart",
	queueStop = "queueStop",
	adminArm = "adminArm",
	tutorialStep = "tutorialStep",
	boostOpen = "boostOpen",
	boostReady = "boostReady",
	offlineOpen = "offlineOpen",
	echoEquip = "echoEquip",
	echoTune = "echoTune",
	reactorReady = "reactorReady",
	reactorStabilize = "reactorStabilize",
	storyOpen = "storyOpen",
	storyBeat = "storyBeat",
	crate = "crate",
	crateNear = "crateNear",
	puzzleTap = "puzzleTap",
	cardEndTurn = "cardEndTurn",
	cardBlock = "cardBlock",
	travel = "travel",
	curtainOpen = "curtainOpen",
	curtainClose = "curtainClose",
	sanctuaryHover = "sanctuaryHover",
	sanctuaryClick = "sanctuaryClick",
	sanctuaryRecall = "sanctuaryRecall",
	navHover = "navHover",
	dropdownOpen = "dropdownOpen",
	dropdownClose = "dropdownClose",
	copyDone = "copyDone",
	dragGrab = "dragGrab",
	dragDrop = "dragDrop",
	dragSnap = "dragSnap",
	favoriteOn = "favoriteOn",
	favoriteOff = "favoriteOff",
	ratingStar = "ratingStar",
	searchType = "searchType",
	countTick = "countTick",
	stepNext = "stepNext",
	stepBack = "stepBack",
	reportSubmit = "reportSubmit",
	feedbackSubmit = "feedbackSubmit",
	guildAnnounce = "guildAnnounce",
	badgeEarn = "badgeEarn",
	artifactEquip = "artifactEquip",
	artifactUpgrade = "artifactUpgrade",
	crateSeal = "crateSeal",
	crateOrbit = "crateOrbit",
	crateRarityStep = "crateRarityStep",
	crateRevealEpic = "crateRevealEpic",
	crateRevealMythic = "crateRevealMythic",
	rebirthIgnite = "rebirthIgnite",
	rebirthShockwave = "rebirthShockwave",
	rebirthTierUp = "rebirthTierUp",
	rebirthAscend = "rebirthAscend",

	purchase = "purchase",
	reward = "reward",
	collect = "collect",
	unlock = "unlock",
	researchUnlock = "researchUnlock",
	codeReward = "codeReward",
	prestige = "prestige",
	rebirthBloom = "rebirthBloom",
	missionClaim = "missionClaim",
	achievementClaim = "achievementClaim",
	dailyClaim = "dailyClaim",
	timedClaim = "timedClaim",
	seasonClaim = "seasonClaim",
	mailClaim = "mailClaim",
	tutorialFinish = "tutorialFinish",
	comboMilestone = "comboMilestone",
	discovery = "discovery",
	zoneUnlock = "zoneUnlock",
	boost = "boost",
	boostActivate = "boostActivate",
	vaultDeposit = "vaultDeposit",
	vaultBank = "vaultBank",
	guildDeposit = "guildDeposit",
	guildCreate = "guildCreate",
	guildJoin = "guildJoin",
	guildLeave = "guildLeave",
	expeditionReturn = "expeditionReturn",
	offlineCollect = "offlineCollect",
	purchaseResult = "purchaseResult",
	echoCapture = "echoCapture",
	echoClaim = "echoClaim",
	storyReveal = "storyReveal",
	wheelLand = "wheelLand",
	crateRare = "crateRare",
	crateClaim = "crateClaim",
	domainReward = "domainReward",
	puzzleClear = "puzzleClear",

	salvage = "salvage",
	salvageCrunch = "salvageCrunch",
	echoDismantle = "echoDismantle",
	autoForge = "autoForge",
	machineInstall = "machineInstall",
	wheelBrake = "wheelBrake",
	crateBrake = "crateBrake",
	reactor = "reactor",
	reactorPulse = "reactorPulse",
	reactorChannel = "reactorChannel",
	reactorSurge = "reactorSurge",
	rebirthCharge = "rebirthCharge",
	adminExecute = "adminExecute",
	expeditionLaunch = "expeditionLaunch",
	wheel = "wheel",
	wheelStart = "wheelStart",
	wheelCharge = "wheelCharge",
	wheelTick = "wheelTick",
	wheelSlow = "wheelSlow",
	crateOpen = "crateOpen",
	crateCharge = "crateCharge",
	crateTick = "crateTick",
	crateLand = "crateLand",
	domainCharge = "domainCharge",
	domainCrack = "domainCrack",
	domainImpact = "domainImpact",
	domainBind = "domainBind",
	cardPlay = "cardPlay",
	cardDraw = "cardDraw",
	cardEnergy = "cardEnergy",
	cardPower = "cardPower",

	boot = "boot",
	bootStart = "bootStart",
	bootIgnite = "bootIgnite",
	bootTension = "bootTension",
	bootWhoosh = "bootWhoosh",
	bootStrike = "bootStrike",
	bootClang = "bootClang",
	bootSpark = "bootSpark",
	bootFizz = "bootFizz",
	bootRumble = "bootRumble",
	bootImpact = "bootImpact",
	bootReady = "bootReady",
	bootFinaleFlip = "bootFinaleFlip",
	bootFinaleBang = "bootFinaleBang",
	bootAnvilSplit = "bootAnvilSplit",
	bootSlamCharge = "bootSlamCharge",
	bootSlamAir = "bootSlamAir",
	bootDebris = "bootDebris",
	bootFractureTail = "bootFractureTail",
	bootGravity = "bootGravity",
	bootAftershock = "bootAftershock",

	oreMine = "oreMine",
	oreCollect = "oreCollect",
	wardenForming = "wardenForming",
	wardenAwake = "wardenAwake",
	wardenStrike = "wardenStrike",
	wardenCrit = "wardenCrit",
	wardenSlamCharge = "wardenSlamCharge",
	wardenSlam = "wardenSlam",
	wardenDefeat = "wardenDefeat",
	wardenEscape = "wardenEscape",
	waystoneTravel = "waystoneTravel",
	regionEnter = "regionEnter",
	navOpenOverview = "navOpenOverview",
	navHoverOverview = "navHoverOverview",
	navOpenWorkshop = "navOpenWorkshop",
	navHoverWorkshop = "navHoverWorkshop",
	navOpenInventory = "navOpenInventory",
	navHoverInventory = "navHoverInventory",
	navOpenResearch = "navOpenResearch",
	navHoverResearch = "navHoverResearch",
	navOpenShop = "navOpenShop",
	navHoverShop = "navHoverShop",
	navOpenSettings = "navOpenSettings",
	navHoverSettings = "navHoverSettings",
	navOpenWorlds = "navOpenWorlds",
	navHoverWorlds = "navHoverWorlds",
	navOpenMissions = "navOpenMissions",
	navHoverMissions = "navHoverMissions",
	navOpenRewards = "navOpenRewards",
	navHoverRewards = "navHoverRewards",
	navOpenBoosts = "navOpenBoosts",
	navHoverBoosts = "navHoverBoosts",
	navOpenStarGrid = "navOpenStarGrid",
	navHoverStarGrid = "navHoverStarGrid",
	navOpenEchoes = "navOpenEchoes",
	navHoverEchoes = "navHoverEchoes",
	navOpenContinuum = "navOpenContinuum",
	navHoverContinuum = "navHoverContinuum",
	navOpenLab = "navOpenLab",
	navHoverLab = "navHoverLab",
	navOpenAnomaly = "navOpenAnomaly",
	navHoverAnomaly = "navHoverAnomaly",
	navOpenWheel = "navOpenWheel",
	navHoverWheel = "navHoverWheel",
	navOpenCommand = "navOpenCommand",
	navHoverCommand = "navHoverCommand",
	navOpenStory = "navOpenStory",
	navHoverStory = "navHoverStory",
	navOpenMail = "navOpenMail",
	navHoverMail = "navHoverMail",
	navOpenChat = "navOpenChat",
	navHoverChat = "navHoverChat",
	navOpenCrew = "navOpenCrew",
	navHoverCrew = "navHoverCrew",
	navOpenMilestones = "navOpenMilestones",
	navHoverMilestones = "navHoverMilestones",
	navOpenConvergence = "navOpenConvergence",
	navHoverConvergence = "navHoverConvergence",
	navOpenGuild = "navOpenGuild",
	navHoverGuild = "navHoverGuild",
	navOpenLeaderboards = "navOpenLeaderboards",
	navHoverLeaderboards = "navHoverLeaderboards",
	navOpenTrade = "navOpenTrade",
	navHoverTrade = "navHoverTrade",
	navOpenCredits = "navOpenCredits",
	navHoverCredits = "navHoverCredits",
	navOpenAdmin = "navOpenAdmin",
	navHoverAdmin = "navHoverAdmin",
	navOpenForgePath = "navOpenForgePath",
	navHoverForgePath = "navHoverForgePath",
	navOpenFoundry = "navOpenFoundry",
	navHoverFoundry = "navHoverFoundry",
	navOpenBazaar = "navOpenWheel",
	navHoverBazaar = "navHoverWheel",
	-- Star Charts and Signal Cipher replaced Next Rank (Continuum) and Shift Plan (Anomaly) in the nav,
	-- so they inherit those pages' voices
	navOpenCharts = "navOpenContinuum",
	navHoverCharts = "navHoverContinuum",
	navOpenCipher = "navOpenAnomaly",
	navHoverCipher = "navHoverAnomaly",
	oreMineEmberite = "oreMineEmberite",
	oreCollectEmberite = "oreCollectEmberite",
	oreMineVoidglass = "oreMineVoidglass",
	oreCollectVoidglass = "oreCollectVoidglass",
	oreMineStarsteel = "oreMineStarsteel",
	oreCollectStarsteel = "oreCollectStarsteel",
	waystoneHeart = "waystoneHeart",
	waystoneEmberreach = "waystoneEmberreach",
	waystoneHollows = "waystoneHollows",
	waystoneSpire = "waystoneSpire",
	waystoneRiftmaw = "waystoneRiftmaw",
	sanctuaryMenu = "sanctuaryMenu",
	sanctuarySheetClose = "sanctuarySheetClose",
	clickHover = "clickHover",
	confirmHover = "confirmHover",
	settingsHover = "settingsHover",
	purchasePressHover = "purchasePressHover",
	claimPressHover = "claimPressHover",
	codeSubmitHover = "codeSubmitHover",
	zoneSelectHover = "zoneSelectHover",
	labRouteHover = "labRouteHover",
	playerlistActionHover = "playerlistActionHover",
	playerlistSelectHover = "playerlistSelectHover",
	puzzleTapHover = "puzzleTapHover",
	sanctuaryClickHover = "sanctuaryClickHover",
	equipHover = "equipHover",
	dangerPressHover = "dangerPressHover",
	closeHover = "closeHover",
	tickHover = "tickHover",
	openHover = "openHover",
	tabSwitchHover = "tabSwitchHover",
	mailHover = "mailHover",
	storyHover = "storyHover",
	toggleOnHover = "toggleOnHover",
	toggleOffHover = "toggleOffHover",
	lockedHover = "lockedHover",
	errorHover = "errorHover",
	prestigeHover = "prestigeHover",
	domainChargeHover = "domainChargeHover",
	cardEndTurnHover = "cardEndTurnHover",
	cardPowerHover = "cardPowerHover",
	cardEnergyHover = "cardEnergyHover",
	vaultBankHover = "vaultBankHover",
	guildCreateHover = "guildCreateHover",
	guildJoinHover = "guildJoinHover",
	inviteHover = "inviteHover",
	travelHover = "travelHover",
	gameResumeHover = "gameResumeHover",
	gamePauseHover = "gamePauseHover",
	queueStopHover = "queueStopHover",
	queueStartHover = "queueStartHover",
	boostHover = "boostHover",
	reactorPulseHover = "reactorPulseHover",
	crateOpenHover = "crateOpenHover",
	wheelStartHover = "wheelStartHover",
	rewardHover = "rewardHover",
	rebirthChargeHover = "rebirthChargeHover",
	missionClaimHover = "missionClaimHover",
	leaderboardSwitchHover = "leaderboardSwitchHover",
	adminArmHover = "adminArmHover",
	memberRemoveHover = "memberRemoveHover",
	roleChangeHover = "roleChangeHover",
	previewHover = "previewHover",
	resetHover = "resetHover",
	chatSendHover = "chatSendHover",
	boostOpenHover = "boostOpenHover",
	vaultDepositHover = "vaultDepositHover",
	forgePress = "forgePress",
	corePress = "corePress",
	wavePress = "wavePress",
	labPress = "labPress",
	commandPress = "commandPress",
	adminPress = "adminPress",
	creditsPress = "creditsPress",
	chatPress = "chatPress",
	continuumPress = "continuumPress",
	missionPress = "missionPress",
	overviewPress = "overviewPress",
})

local Primary = Manifest.SoundSheet
local Previous = Manifest.SoundSheetPrevious
local active = if Primary.Id > 0 then Primary else (Previous or Primary)

function SoundSheet.enabled(): boolean
	return Primary.Id > 0 or (Previous ~= nil and Previous.Id > 0)
end

function SoundSheet.assetId(): string
	return `rbxassetid://{active.Id}`
end

function SoundSheet.primaryAsset(): string?
	return if Primary.Id > 0 then `rbxassetid://{Primary.Id}` else nil
end

function SoundSheet.previousAsset(): string?
	return if Previous ~= nil and Previous.Id > 0 then `rbxassetid://{Previous.Id}` else nil
end

function SoundSheet.use(previous: boolean)
	active = if previous and Previous ~= nil then Previous else Primary
end

local function voiceName(cue: string): string?
	local mapped = SoundSheet.VOICE[cue]
	if mapped ~= nil then
		return mapped
	end
	if active.Regions[cue] ~= nil then
		return cue
	end
	return nil
end

function SoundSheet.region(cue: string): (number?, number?)
	if not SoundSheet.enabled() then
		return nil, nil
	end
	local voice = voiceName(cue)
	local region = if voice ~= nil then active.Regions[voice] else nil
	if region == nil then
		return nil, nil
	end
	return region[1], region[2]
end

function SoundSheet.gain(cue: string): number
	local voice = voiceName(cue)
	local level = if voice ~= nil then active.Loudness[voice] else nil
	if level == nil then
		return 1
	end
	return math.clamp(10 ^ ((TARGET_LOUDNESS - level) / 20), 0.55, 1.35)
end

return SoundSheet
end

__defs["soundtrack"] = function()

type Track = {
	name: string,
	asset: string,
	gain: number,
	low: number,
	mid: number,
	high: number,
}

local TRACKS: { Track } = {
	{ name = "Space Ambient", asset = "rbxassetid://140533822783920", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Galactic Market", asset = "rbxassetid://85922328966318", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Slow Breathing Aurora (Space Ambient)", asset = "rbxassetid://140041908508788", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Return Signal Hopeful Future Ambient Music", asset = "rbxassetid://134433077845062", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Cosmic Cafe", asset = "rbxassetid://136898642923218", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Zero Gravity", asset = "rbxassetid://102039057339088", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Twilight’s Soothing Cascade", asset = "rbxassetid://139804134367647", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Nebula Dream Theta Waves", asset = "rbxassetid://139793680497894", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Deep Space Ocean", asset = "rbxassetid://136827064604146", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Liminal Space Ambient (Lost in the Halls)", asset = "rbxassetid://133670858533628", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Space Station '98", asset = "rbxassetid://128285716110465", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Hello in There Space Ambient", asset = "rbxassetid://111560725873026", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Adrenaline Arcade Synthwave", asset = "rbxassetid://138551890276730", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Feedback", asset = "rbxassetid://122703970718439", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Desperation", asset = "rbxassetid://81466105858478", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Resistance", asset = "rbxassetid://99903926483608", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Automated", asset = "rbxassetid://93964414292507", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Aloha Sunset (Hawaiian Synth)", asset = "rbxassetid://118508726012870", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Celestial String Awakening 2", asset = "rbxassetid://101244629093073", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Calm Cinematic Space", asset = "rbxassetid://137911990035159", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Soft Intro Reflections", asset = "rbxassetid://87900257498941", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Temple of Silent Light 2", asset = "rbxassetid://86497547233756", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "River of Soft Gold 2", asset = "rbxassetid://114636840398015", gain = 0.8, low = 0, mid = 0, high = 0 },
	{ name = "Silent Cinematic Prelude", asset = "rbxassetid://85227514374326", gain = 0.8, low = 0, mid = 0, high = 0 },
}

local Soundtrack = {}

Soundtrack.CROSSFADE_SECONDS = 4
Soundtrack.BASE_VOLUME = 1
Soundtrack.RETRY_SECONDS = 600

function Soundtrack.tracks(): { Track }
	return TRACKS
end

function Soundtrack.count(): number
	return #TRACKS
end

function Soundtrack.track(index: number): Track
	return TRACKS[((index - 1) % #TRACKS) + 1]
end

function Soundtrack.nextIndex(current: number, failedAt: { [number]: number }, now: number): number?
	local count = #TRACKS
	for step = 1, count - 1 do
		local candidate = ((current - 1 + step) % count) + 1
		local failed = failedAt[candidate]
		if failed == nil or now - failed >= Soundtrack.RETRY_SECONDS then
			return candidate
		end
	end
	return nil
end

-- Fisher-Yates shuffle bags give every healthy track a turn without repeats.
function Soundtrack.newShuffle(randomInteger)
    local random = randomInteger or math.random
    local bag = {}
    local shuffle = {}
    function shuffle:next(current, failedAt, now)
		if #bag == 0 or (#bag == 1 and bag[1] == current) then
			table.clear(bag)
            for index = 1, #TRACKS do table.insert(bag, index) end
            for index = #bag, 2, -1 do
                local other = random(1, index)
                bag[index], bag[other] = bag[other], bag[index]
            end
        end
        local deferred = {}
        local chosen = nil
        while #bag > 0 do
            local candidate = table.remove(bag)
            local failed = failedAt[candidate]
            if candidate == current then
                table.insert(deferred, candidate)
            elseif failed == nil or now - failed >= Soundtrack.RETRY_SECONDS then
                chosen = candidate
                break
            end
        end
        -- A boundary repeat is deferred to a later draw, not thrown away.
        for _, candidate in deferred do table.insert(bag, 1, candidate) end
        return chosen
    end
    return shuffle
end

function Soundtrack.shouldAdvance(timeLength: number, timePosition: number, playbackSpeed: number): boolean
	if timeLength <= Soundtrack.CROSSFADE_SECONDS * 2 then
		return false
	end
	local remaining = (timeLength - timePosition) / math.max(0.05, playbackSpeed)
	return remaining <= Soundtrack.CROSSFADE_SECONDS
end

function Soundtrack.fadeGains(alpha: number): (number, number)
	local t = math.clamp(alpha, 0, 1)
	return math.cos(t * math.pi * 0.5), math.sin(t * math.pi * 0.5)
end

function Soundtrack.volume(track: Track, mix: number, duck: number): number
	return Soundtrack.BASE_VOLUME * track.gain * math.clamp(mix, 0, 1) * math.clamp(duck, 0, 1)
end

function Soundtrack.manifest(): { string }
	local assets = {}
	for _, track in TRACKS do
		table.insert(assets, track.asset)
	end
	return assets
end

return Soundtrack
end

__defs["musicDirector"] = function()
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local Soundtrack = __load("soundtrack")

local MUSIC_ASSET_MANIFEST = Soundtrack.manifest()
local DECK_NAMES = { "SoundtrackA", "SoundtrackB" }
local POLL_SECONDS = 0.25
local FADE_STEP_SECONDS = 0.05
local LOAD_DEADLINE_SECONDS = 12

local activeDirector = nil

local function makeDeck(name, group)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name = "BedGlue"
	compressor.Threshold = -18
	compressor.Ratio = 2
	compressor.Attack = 0.02
	compressor.Release = 0.2
	compressor.Parent = sound
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "TrackTone"
	equalizer.Parent = sound
	return {
		sound = sound,
		equalizer = equalizer,
		trackIndex = nil,
		loadStarted = 0,
	}
end

local MusicDirector
do
	MusicDirector = setmetatable({}, {
		__tostring = function()
			return "MusicDirector"
		end,
	})
	MusicDirector.__index = MusicDirector
	function MusicDirector.new(...)
		local self = setmetatable({}, MusicDirector)
		return self:constructor(...) or self
	end
	function MusicDirector:constructor(group)
		self.group = group
		self.decks = { makeDeck(DECK_NAMES[1], group), makeDeck(DECK_NAMES[2], group) }
		self.active = 1
		self.shuffle = Soundtrack.newShuffle()
		self.trackIndex = self.shuffle:next(nil, {}, os.clock()) or 1
		self.fading = false
		self.fadeAlpha = 0
		self.loopedOver = false
		self.failedAt = {}
		self.mix = 1
		self.duck = 1
		self.audible = true
		self.started = false
		self.disposed = false
		self.connections = {}
	end
	function MusicDirector:isLive()
		return self.started and not self.disposed and self.retryAt == nil and self.audible and self.mix * self.duck > 0.001
	end
	function MusicDirector:spare()
		return if self.active == 1 then 2 else 1
	end
	function MusicDirector:loadDeck(deckIndex, trackIndex)
		local deck = self.decks[deckIndex]
		local track = Soundtrack.track(trackIndex)
		deck.sound:Stop()
		deck.sound.Volume = 0
		deck.trackIndex = trackIndex
		deck.loadStarted = os.clock()
		deck.loadVersion = (deck.loadVersion or 0) + 1
		local version = deck.loadVersion
		deck.loadFailed = false
		if deck.sound.SoundId ~= track.asset then
			deck.sound.SoundId = track.asset
		end
		deck.sound.PlaybackSpeed = 1
		deck.sound.TimePosition = 0
		deck.equalizer.LowGain = track.low
		deck.equalizer.MidGain = track.mid
		deck.equalizer.HighGain = track.high
		-- Preloading ID strings alone does not initialize a stopped Sound decoder.
		-- Warm the actual deck instance, then Resume can start it without resetting
		-- a paused song. Old fetch callbacks must not invalidate a replacement track.
		task.spawn(function()
			local ok = pcall(function()
				ContentProvider:PreloadAsync({deck.sound}, function(_, status)
					if not self.disposed and deck.loadVersion == version then
						deck.loadFailed = status ~= Enum.AssetFetchStatus.Success
					end
				end)
			end)
			if not ok and not self.disposed and deck.loadVersion == version then deck.loadFailed = true end
		end)
	end
	function MusicDirector:applyVolumes()
		local activeDeck = self.decks[self.active]
		local spareDeck = self.decks[self:spare()]
		if not self:isLive() then
			activeDeck.sound.Volume = 0
			spareDeck.sound.Volume = 0
			return nil
		end
		local activeLevel = Soundtrack.volume(Soundtrack.track(activeDeck.trackIndex or self.trackIndex), self.mix, self.duck)
		if self.fading and spareDeck.trackIndex ~= nil then
			local outGain, inGain = Soundtrack.fadeGains(self.fadeAlpha)
			activeDeck.sound.Volume = activeLevel * outGain
			spareDeck.sound.Volume = Soundtrack.volume(Soundtrack.track(spareDeck.trackIndex), self.mix, self.duck) * inGain
		else
			activeDeck.sound.Volume = activeLevel
			spareDeck.sound.Volume = 0
		end
		return nil
	end
	function MusicDirector:refresh()
		if self.disposed or not self.started then
			return nil
		end
		self:applyVolumes()
		local activeSound = self.decks[self.active].sound
		local spareSound = self.decks[self:spare()].sound
		if self:isLive() then
			if not activeSound.IsPlaying then
				activeSound:Resume()
			end
			if self.fading and not spareSound.IsPlaying then
				spareSound:Resume()
			end
		else
			if activeSound.IsPlaying then
				activeSound:Pause()
			end
			if spareSound.IsPlaying then
				spareSound:Pause()
			end
		end
		return nil
	end
	function MusicDirector:start()
		if self.started or self.disposed then
			return nil
		end
		if activeDirector ~= nil and activeDirector ~= self and not activeDirector.disposed then
			activeDirector:dispose()
		end
		activeDirector = self
		self.started = true
		self:loadDeck(self.active, self.trackIndex)
		for index, deck in self.decks do
			table.insert(self.connections, deck.sound.DidLoop:Connect(function()
				if index == self.active and not self.fading then
					self.loopedOver = true
				end
			end))
		end
		self:refresh()
		self.worker = task.spawn(function()
			while not self.disposed do
				task.wait(POLL_SECONDS)
				if self.disposed then
					break
				end
				local ok, problem = pcall(self.step, self)
				if not ok and not self.disposed then
					self.fading = false
					self.fadeAlpha = 0
					pcall(self.refresh, self)
					ClientLog:warnEvery("music-step", 30, "Audio", `soundtrack step failed: {tostring(problem)}`)
				end
			end
		end)
		return nil
	end
	function MusicDirector:markFailed(trackIndex)
		self.failedAt[trackIndex] = os.clock()
		local name = Soundtrack.track(trackIndex).name
		ClientLog:warnEvery(`music-load-{name}`, 30, "Audio", `{name} did not load; skipping it for now`)
	end
	function MusicDirector:skipActive()
		self:markFailed(self.trackIndex)
		local nextIndex = self.shuffle:next(self.trackIndex, self.failedAt, os.clock())
		if nextIndex == nil then
			self.retryAt = os.clock() + 30
			self:refresh()
			return nil
		end
		self.trackIndex = nextIndex
		self:loadDeck(self.active, self.trackIndex)
		self:refresh()
		return nil
	end
	function MusicDirector:prepareSpare()
		local spareIndex = self:spare()
		local spare = self.decks[spareIndex]
		local nextIndex = spare.trackIndex or self.shuffle:next(self.trackIndex, self.failedAt, os.clock())
		if nextIndex == nil then return nil end
		if spare.trackIndex ~= nextIndex then
			self:loadDeck(spareIndex, nextIndex)
			return nil
		end
		if not spare.sound.IsLoaded and (spare.loadFailed or os.clock() - spare.loadStarted >= LOAD_DEADLINE_SECONDS) then
			self:markFailed(nextIndex)
			spare.trackIndex = nil
		end
		return nil
	end
	function MusicDirector:step()
		if self.retryAt ~= nil then
			if os.clock() < self.retryAt then return nil end
			self.retryAt = nil
			self:skipActive()
			return nil
		end
		if not self:isLive() or self.fading then
			return nil
		end
		local deck = self.decks[self.active]
		local sound = deck.sound
		if not sound.IsLoaded then
			if deck.loadFailed or os.clock() - deck.loadStarted >= LOAD_DEADLINE_SECONDS then
				self:skipActive()
			end
			return nil
		end
		if not sound.IsPlaying then
			sound:Resume()
		end
		self:prepareSpare()
		local due = self.loopedOver or Soundtrack.shouldAdvance(sound.TimeLength, sound.TimePosition, sound.PlaybackSpeed)
		self.loopedOver = false
		if due then
			self:handOver()
		end
		return nil
	end
	function MusicDirector:handOver()
		local spareIndex = self:spare()
		local spare = self.decks[spareIndex]
		local nextIndex = spare.trackIndex
		if nextIndex == nil or not spare.sound.IsLoaded then
			return nil
		end
		self.fading = true
		self.fadeAlpha = 0
		spare.sound.TimePosition = 0
		self:refresh()
		local elapsed = 0
		while elapsed < Soundtrack.CROSSFADE_SECONDS do
			local dt = task.wait(FADE_STEP_SECONDS)
			if self.disposed then
				return nil
			end
			if self:isLive() then
				elapsed += dt
			end
			self.fadeAlpha = math.clamp(elapsed / Soundtrack.CROSSFADE_SECONDS, 0, 1)
			self:applyVolumes()
		end
		local outgoingDeck = self.decks[self.active]
		local outgoing = outgoingDeck.sound
		outgoingDeck.trackIndex = nil
		outgoing:Stop()
		outgoing.Volume = 0
		self.active = spareIndex
		self.trackIndex = nextIndex
		self.fading = false
		self.fadeAlpha = 0
		self:refresh()
		ClientLog:debug("audio", `soundtrack: {Soundtrack.track(nextIndex).name}`)
		return nil
	end
	function MusicDirector:setMix(value)
		if self.disposed then
			return nil
		end
		local nextMix = math.clamp(value, 0, 1)
		if math.abs(nextMix - self.mix) <= 0.0005 then
			return nil
		end
		self.mix = nextMix
		self:refresh()
		return nil
	end
	function MusicDirector:setDuck(value)
		if self.disposed then
			return nil
		end
		local nextDuck = math.clamp(value, 0, 1)
		if math.abs(nextDuck - self.duck) <= 0.0005 then
			return nil
		end
		self.duck = nextDuck
		self:refresh()
		return nil
	end
	function MusicDirector:setAudible(audible)
		if self.disposed then
			return nil
		end
		self.audible = audible == true
		self:refresh()
		return nil
	end
	function MusicDirector:resume()
		self:refresh()
		return nil
	end
	function MusicDirector:currentTrack()
		return Soundtrack.track(self.trackIndex).name
	end
	function MusicDirector:dispose()
		if self.disposed then
			return nil
		end
		self.disposed = true
		self.started = false
		if activeDirector == self then
			activeDirector = nil
		end
		if self.worker ~= nil then
			pcall(task.cancel, self.worker)
			self.worker = nil
		end
		for _, connection in self.connections do
			connection:Disconnect()
		end
		table.clear(self.connections)
		for _, deck in self.decks do
			pcall(function()
				deck.sound:Destroy()
			end)
		end
		return nil
	end
end
return {
	DECK_NAMES = DECK_NAMES,
	MUSIC_ASSET_MANIFEST = MUSIC_ASSET_MANIFEST,
	MusicDirector = MusicDirector,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
