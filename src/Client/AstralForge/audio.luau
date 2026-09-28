local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ClientLog = require(script.Parent.log).ClientLog
local MusicDirector = require(script.Parent.musicDirector).MusicDirector
local MUSIC_DECK_NAMES = require(script.Parent.musicDirector).DECK_NAMES
local Voicing = require(script.Parent.audioVoicing)
local SoundSheet = require(script.Parent.soundSheet)
-- Voices on the sound sheet (tools/assetgen). One file, many regions, so it
-- gets a larger pool than any single legacy asset.
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
local SFX_SPARKLE = SFX_TRAVEL
local SFX_COIN = UI_CHIME
local SFX_COLLECT = UI_CONFIRM
local SFX_RISE = SFX_TRAVEL
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
		volume = 0.4,
		speed = 0.76,
		variance = 0,
		cooldown = 0.12,
		stopAfter = 1.05,
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
		volume = 0.4,
		speed = 1.06,
		variance = 0,
		cooldown = 0.14,
		stopAfter = 0.95,
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
	-- Sanctuary: ore outcrops.
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
	-- Sanctuary: the Rift Warden.
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
	-- Sanctuary: travel and regions.
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
} do
	UI_CUES[cue] = true
end
local PRELOAD_BATCH_SIZE = 11
local VOICE_CAP = 22
local UI_OVERLAP_CAP = 4
local TRIM_RELEASE_STEPS = 3
local CUE_GAIN = 1.05
-- Every cue aliases one of three real assets, so a single pool absorbs the whole
-- game's polyphony for that timbre. `IsPlaying` does not flip true on the same
-- frame as :Play(), so a channel is also reserved for this long after starting;
-- without it two cues in one frame both see the channel idle and the second
-- restarts the first, which is the doubled-attack "stacking" players hear.
local CHANNEL_CLAIM_SECONDS = 0.05
-- Same-cue coalesce window. Two systems answering one event, or several notice
-- cards mounting from one server update, fire the same cue phase-aligned; that
-- is a flam and a volume spike, not polyphony. Deliberate layering opts out via
-- bypassCooldown. Kept under a frame at 30fps so distinct taps still all sound.
local DUPLICATE_CUE_SECONDS = 0.035
local BUTTON_PITCH_CUES = {
	click = true,
	hover = true,
	confirm = true,
}
-- The three real source files, by role. Voicing layers name one of these so the
-- stacked copy is drawn from a DIFFERENT file than the cue's own -- that
-- contrast is what makes the pair read as one richer sound.
local LAYER_SOURCES = {
	hover = UI_HOVER,
	click = UI_CLICK,
	confirm = UI_CONFIRM,
}
local BOOTSTRAP_ASSETS = AUDIO_ASSET_MANIFEST
local function residentChannelCount(asset)
	return if asset == UI_CLICK or asset == UI_TICK or asset == UI_CONFIRM or asset == UI_HOVER or asset == UI_NOTIFY then 8 else 4
end
-- Every page change sounds the same. Pages used to each open with their own
-- "sting" (a reward chime for Rewards, a chat ping for Chat, a coin for Shop),
-- which mislabelled the moment -- opening Chat is not a message arriving -- and
-- stacked a second, different sound on top of the nav button's own.
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
	-- ▼ ReadonlyArray.some ▼
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
	-- ▲ ReadonlyArray.some ▲
	return _result
end
local function labelEquals(label, ...)
	local values = { ... }
	local upper = string.upper(label)
	-- ▼ ReadonlyArray.some ▼
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
	-- ▲ ReadonlyArray.some ▲
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
	return "click"
end
local function softMaster(linear)
	local t = math.clamp(linear, 0, 1)
	return t * t * (3 - 2 * t)
end
local function softSfx(linear)
	local t = math.clamp(linear, 0, 1)
	return math.clamp(t * 1.05 + t * t * 0.12, 0, 1.15)
end
-- Voicing: every cue belongs to a family (forge, arcane, currency, denial...)
-- and each family carries a full voice -- EQ curve, reverb space, drive, pitch
-- and decay. Three source files can only sound like three things without this;
-- with it, the same click reads as a hammer, a coin or a rift depending on the
-- family it is voiced through. See audioVoicing.luau for the design rationale.
local function paintCue(channel, cue)
	local voice = Voicing.voiceFor(cue)

	local color = channel:FindFirstChild("CueColor")
	if color == nil then
		color = Instance.new("EqualizerSoundEffect")
		color.Name = "CueColor"
		color.Parent = channel
	end
	color.HighGain = Voicing.clampGain(voice.high)
	color.MidGain = Voicing.clampGain(voice.mid)
	color.LowGain = Voicing.clampGain(voice.low)

	-- Reverb is what places a cue in a space. Close UI stays dry; rift and
	-- ceremony sit in a big room. Reused per channel rather than recreated, and
	-- fully disabled when dry so a tight click keeps no tail from a previous cue.
	local space = channel:FindFirstChild("CueSpace")
	if voice.reverbWet > 0.001 then
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

	-- A little drive gives metal its grain and makes a refusal feel blocked.
	local grit = channel:FindFirstChild("CueDrive")
	if voice.drive > 0.001 then
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
		-- Same-frame reservation; see CHANNEL_CLAIM_SECONDS.
		self.claimedUntil = {}
		-- Layer trim (Voicing layer.volume) for channels currently voicing a
		-- layer; nil for a cue's own hit. Every volume recompute multiplies it in,
		-- or a quiet layer jumps to full cue volume on a slider move or release.
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
		-- The "Background music" setting (persisted under its old key, PageMusic).
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
		if cue == "hover" and not self.hoverSounds then
			return 0
		end
		if (cue == "notification" or cue == "systemAlert" or cue == "chatReceive" or cue == "crewNudge" or cue == "noticeInfo" or cue == "noticeSuccess" or cue == "noticeWarning" or cue == "noticeError" or cue == "noticeSpecial" or cue == "noticeClose") and not self.notificationSounds then
			return 0
		end
		if cue == "reward" or cue == "unlock" or cue == "discovery" or cue == "prestige" or cue == "rebirthCharge" or cue == "rebirthBloom" or cue == "domainCharge" or cue == "domainCrack" or cue == "domainImpact" or cue == "domainReward" or cue == "wheelLand" or cue == "crateLand" or cue == "crateRare" or cue == "crateClaim" or cue == "missionClaim" or cue == "achievementClaim" or cue == "dailyClaim" or cue == "timedClaim" or cue == "seasonClaim" or cue == "mailClaim" or cue == "codeReward" or cue == "tutorialFinish" or cue == "purchaseResult" or cue == "boostReady" then
			return self.rewardMix
		end
		if cue == "hover" or cue == "click" or cue == "tick" or cue == "confirm" or cue == "locked" or cue == "error" or cue == "page" or cue == "open" or cue == "close" or cue == "settings" or cue == "scroll" or cue == "toggleOn" or cue == "toggleOff" or cue == "sliderStep" or cue == "sliderCommit" or cue == "inputFocus" or cue == "inputClear" or cue == "tabSwitch" or cue == "filterOpen" or cue == "filterPick" or cue == "amountChange" or cue == "modalOpen" or cue == "modalPop" or cue == "modalDismiss" or cue == "purchaseExit" or cue == "playerlistOpen" or cue == "playerlistSelect" or cue == "playerlistAction" or cue == "playerlistClose" or cue == "noticeInfo" or cue == "noticeSuccess" or cue == "noticeWarning" or cue == "noticeError" or cue == "noticeSpecial" or cue == "noticeClose" or cue == "tutorialStep" or cue == "hoverTick" or cue == "velocitySlide" or cue == "purchase" or cue == "purchasePress" or cue == "claimPress" or cue == "researchUnlock" or cue == "travel" or cue == "collect" then
			return self.uiMix
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
		-- The sound sheet is one file behind most cues, so it loads first.
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
		-- Sounds live on SoundService, so a second mixer (script reload, or a
		-- start that replaced musicDirector without disposing it) keeps the
		-- previous soundtrack audible. Drop those leftovers before building a new
		-- set (ViewMusicA/B are the per-view decks from before the soundtrack).
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
			group.Volume = 1
			group.Parent = masterGroup
		end
		self.group = group
		group.Volume = 1

		local uiGroup = masterGroup:FindFirstChild("ForgeUI") :: SoundGroup
		if not uiGroup then
			uiGroup = Instance.new("SoundGroup")
			uiGroup.Name = "ForgeUI"
			uiGroup.Volume = 0.95
			uiGroup.Parent = masterGroup
		end
		self.uiGroup = uiGroup

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
			musicGroup.Volume = 0.38
			musicGroup.Parent = masterGroup
		end
		self.musicGroup = musicGroup
		musicGroup.Volume = 0.38

		local musicEq = musicGroup:FindFirstChild("ForgeBed") :: EqualizerSoundEffect
		if not musicEq then
			musicEq = Instance.new("EqualizerSoundEffect")
			musicEq.Name = "ForgeBed"
			musicEq.Parent = musicGroup
		end
		-- Light global shelf over the whole soundtrack; each track's own TrackTone
		-- EQ only evens it out against the others.
		musicEq.LowGain = 0
		musicEq.MidGain = -0.3
		musicEq.HighGain = -1.2
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
		-- The designed sound sheet, once uploaded: every mapped cue plays its own
		-- slice of it (see soundSheet.luau) instead of a re-voiced legacy click.
		if SoundSheet.enabled() then
			local sheetAsset = SoundSheet.assetId()
			local sheetPool = {}
			for index = 1, SHEET_CHANNELS do
				local channel = self:makeChannel(sheetAsset, 100 + index, group)
				channel.PlaybackRegionsEnabled = true
				table.insert(sheetPool, channel)
			end
			self.assetPools[sheetAsset] = sheetPool
			self.sheetPool = sheetPool
		end
		-- One soundtrack for the whole game; page changes never touch it.
		local musicDirector = MusicDirector.new(musicGroup)
		self.musicDirector = musicDirector
		-- Settings load before the mixer starts, so masterLinear / musicEnabled /
		-- musicDuck can already differ from the director's constructor defaults.
		-- Push the whole live state through once the director exists, and before
		-- it starts, so a muted or music-off player never hears a blip.
		self:syncMusicState()
		musicDirector:start()
		local preload = self:preloadChannels()
		ClientLog:debug("audio", `{#preload.channels} sounds ready`)
		self:preloadSoundBank(preload.channels, preload.priorityCount, lifecycle)
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
		local mix = self.musicMix
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
		local clamped = math.clamp(depth, 0, 0.72)
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
					-- Family gain and layer trim included, to match what playChannel /
					-- playLayer set.
					sound.Volume = CUES[cue].volume * CUE_GAIN * Voicing.voiceFor(cue).gain * (self.channelLayerGain[sound] or 1) * sfx * self:cueMix(cue)
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
		-- "Background music" on/off. Saved under PageMusic, its name from when
		-- each page had its own music, so existing players keep their choice.
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
	-- Record the open page. The music ignores it; navigation just gets its one
	-- consistent cue. Nav controls capture an audio intent before navigating,
	-- so this cue claims it and the control's own fallback does not double up.
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
		-- Advance first, then read the advanced cursor: same full rotation as
		-- before, written so the stored cursor and the returned index agree.
		local cursor = self.channelCursor[asset]
		if cursor == nil then
			cursor = 0
		end
		cursor = (cursor + 1) % #pool
		self.channelCursor[asset] = cursor
		return pool[cursor + 1]
	end
	-- Steal the channel whose sound is furthest through its own playback, so the
	-- voice closest to finishing is the one cut rather than a fresh transient.
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
			-- Drain down to the cap rather than silencing a single voice, so a
			-- burst that lands several cues in one frame cannot leave the UI
			-- layer permanently above UI_OVERLAP_CAP.
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
		-- Resident channels are created once at start. Spam steals one of those
		-- instead of Instance.new, including when every voice is busy. Prefer the
		-- voice furthest through playback; fall back to round-robin only when every
		-- channel is still inside its same-frame claim.
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
			local speed = math.max(0.05, job.speed)
			if phase == "length" then
				if channel.TimeLength > 0 then
					local natural = channel.TimeLength / speed
					-- The family's decay stretches or shortens the cue's own
					-- stopAfter, so arcane cues ring out and chrome stays clipped
					-- without retuning every entry in the cue table.
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
						-- Must match the volume playChannel / playLayer set, family
						-- gain and layer trim included, or the release fade starts
						-- with a jump.
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
		if spec.asset == "" then
			return false
		end
		local now = os.clock()
		-- The per-cue cooldown only throttles high-frequency, purely-decorative cues (hover
		-- scrubbing across a list) where back-to-back retriggers would sound like a buzz rather
		-- than distinct feedback. Every other cue is a direct response to a discrete player
		-- action (a click, a claim, a purchase) -- dropping it silently on a fast player or a
		-- burst of distinct buttons is a missing tap, not noise control, so those always play and
		-- lean on the channel pool below for polyphony instead of a time gate.
		local _lastPlayed = self.lastPlayed
		local _cue = cue
		local _condition = _lastPlayed[_cue]
		if _condition == nil then
			_condition = -math.huge
		end
		local previous = _condition
		if not bypassCooldown and cue == "hover" and now - previous < spec.cooldown then
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
		-- The cap used to apply to "hover" alone, which let every other cue stack
		-- without limit -- the loudest form of the pile-up. Decorative cues are
		-- dropped at the cap; a cue that answers a discrete player action still
		-- plays (it steals a voice below) so a tap is never silently swallowed.
		if liveVoices >= VOICE_CAP and not bypassCooldown then
			local decorative = cue == "hover" or cue == "hoverTick" or cue == "scroll" or cue == "tick" or cue == "wheelTick" or cue == "crateTick" or cue == "sliderStep" or cue == "filterPick" or cue == "amountChange" or cue == "cardDraw" or cue == "bootClang" or cue == "bootTension"
			if decorative then
				return false
			end
		end
		-- Coalesce identical cues fired in the same instant. Several notice cards
		-- mounting from one server update each play their tone cue, and a claim
		-- handler plus the notice it raises answer the same event -- one asset,
		-- several voices, phase-aligned. That reads as a flam and a volume spike,
		-- not as polyphony. Deliberate layering (playCelebration) passes
		-- bypassCooldown and is exempt, as are distinct cues.
		if not bypassCooldown and now - previous < DUPLICATE_CUE_SECONDS then
			return false
		end
		if self.sheetPool ~= nil then
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
		-- This channel may last have voiced a layer; the cue's own hit is untrimmed.
		self.channelLayerGain[channel] = nil
		local voice = Voicing.voiceFor(cue)
		local pitchSpread = if BUTTON_PITCH_CUES[cue] then math.random(95, 105) / 100 else 1
		local variance = if spec.variance > 0 then (math.random() * 2 - 1) * spec.variance * self.soundVariation else 0
		-- The family's pitch is the main reason one source file can read as a
		-- hammer, a coin or a rift. The floor drops to 0.28 so the arcane and
		-- ceremony families can actually sit an octave down; the old 0.5 clamp
		-- quietly flattened every deep cue back toward the click it came from.
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
		-- Reserve the channel immediately. busyUntil is only filled in later by the
		-- release pump (it needs TimeLength, which is 0 until the asset loads), so
		-- without this a cue fired in the same frame sees IsPlaying still false and
		-- restarts this very sound on top of itself.
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
	-- A designed voice from the sound sheet: play just its region. The sound
	-- already carries its own space and character, so the family voicing
	-- (pitch shifts, drive, rooms) that made three clicks sound like forty
	-- things is skipped; only a touch of pitch variety stays.
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
		-- Stored as the layer trim so a slider move recomputes the same volume.
		self.channelLayerGain[channel] = level
		local variance = if spec.variance > 0 then (math.random() * 2 - 1) * math.min(spec.variance, 0.03) * self.soundVariation else 0
		local spread = if BUTTON_PITCH_CUES[cue] then math.random(97, 103) / 100 else 1
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
		local duckDepth = MUSIC_DUCK_CUES[cue]
		if duckDepth ~= nil then
			self:duckMusic(duckDepth, math.max(0.18, length * 0.45), 0.62)
		end
		return true
	end
	-- A handful of cues stack a second, quieter copy of a DIFFERENT source file
	-- a few milliseconds late: a deep body under a rift impact, a bright shimmer
	-- over a reward. Close enough together it reads as one richer sound rather
	-- than two, which is how three files cover a game this size. Deliberately
	-- rare -- layering everything would just double the voice count.
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
			-- A stopSfx or dispose between the hit and the layer must silence it.
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
			-- No free voice: the layer is a garnish, so drop it rather than
			-- stealing a channel from a cue the player actually triggered.
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
			channel.Volume = CUES[cue].volume * CUE_GAIN * voice.gain * layer.volume * softSfx(self.sfxMix) * self:cueMix(cue)
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
			self:scheduleRelease(channel, cue, CUES[cue], generation, token, channel.PlaybackSpeed)
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
				-- Deliberate layering: exempt from the same-cue coalesce window.
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
			-- No hasRecentIntent pre-check here -- it used to void this button's own marker
			-- whenever ANY sound had played anywhere in the last 25ms, which during fast/rapid
			-- clicking across different buttons voided the fallback for a button that never
			-- actually got its own sound. playIfUnclaimed below already does the correct,
			-- precise check (does the marker captured for THIS press still match the live
			-- intentSerial) at commit time, so pre-guessing here was redundant and wrong.
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
	hookGuiClicks = hookGuiClicks,
	AUDIO_ASSET_MANIFEST = AUDIO_ASSET_MANIFEST,
	Audio = Audio,
}
