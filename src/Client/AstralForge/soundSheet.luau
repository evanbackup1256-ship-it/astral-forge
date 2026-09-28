--!strict
-- Which slice of the sound sheet each audio cue plays.
--
-- tools/assetgen renders every sound the game makes into one file (Roblox
-- caps audio uploads per month, so one file carries all of them), and the
-- mixer plays a cue as a PlaybackRegion of it. AssetManifest has the regions
-- and each voice's loudness; this module maps the game's 188 cue names onto
-- the 47 voices and levels them against each other.
--
-- Until the sheet is uploaded (Manifest.SoundSheet.Id == 0) nothing here is
-- used and the mixer keeps its original sounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manifest = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("AssetManifest"))

local SoundSheet = {}

-- Every voice is levelled to this loudness (dB RMS while sounding) before the
-- cue's own volume applies, so a soft chime and a hard hit read as intended.
local TARGET_LOUDNESS = -20

-- cue -> voice. Cues that share a moment share a voice, so the game speaks
-- one consistent language: every "opened something" is ui_open, every
-- "claimed a reward" is claim, and so on.
SoundSheet.VOICE = table.freeze({
	-- Interface
	hover = "ui_hover", click = "ui_click", tick = "ui_tick", confirm = "ui_confirm", locked = "ui_locked",
	error = "ui_error", page = "ui_page", mail = "ui_notify", story = "ui_open", open = "ui_open", close = "ui_close",
	settings = "ui_click", scroll = "ui_tick", toggleOn = "ui_toggle_on", toggleOff = "ui_toggle_off",
	sliderStep = "ui_slider", sliderCommit = "ui_pop", inputFocus = "ui_type", inputClear = "ui_pop",
	tabSwitch = "ui_page", filterOpen = "ui_open", filterPick = "ui_tick", amountChange = "ui_slider",
	modalOpen = "ui_open", modalPop = "ui_pop", modalDismiss = "ui_close", purchaseExit = "ui_close",
	playerlistOpen = "ui_open", playerlistSelect = "ui_tick", playerlistAction = "ui_click", playerlistClose = "ui_close",
	noticeInfo = "ui_notify", noticeSuccess = "ui_confirm", noticeWarning = "ui_warn", noticeError = "ui_error",
	noticeSpecial = "unlock", noticeClose = "ui_close", chatSend = "ui_pop", chatReceive = "chat_ping",
	hoverTick = "ui_tick", successChime = "ui_confirm", errorBuzz = "ui_error", velocitySlide = "whoosh",
	purchasePress = "ui_click", claimPress = "ui_click", dangerPress = "ui_warn", preview = "ui_page",
	reset = "ui_close", roleChange = "ui_confirm", memberRemove = "ui_close", mailRead = "ui_page",
	storyPage = "ui_page", leaderboardSwitch = "ui_page", requestBlocked = "ui_locked", requestTimeout = "ui_warn",
	gamePause = "ui_close", gameResume = "ui_open", gameExit = "ui_close", notification = "ui_notify",
	systemAlert = "ui_warn", crewNudge = "chat_ping", invite = "chat_ping", codeSubmit = "ui_click",
	zoneSelect = "ui_click", labRoute = "ui_click", equip = "ui_confirm", itemLink = "ui_confirm",
	itemUnlink = "ui_close", queueStart = "ui_toggle_on", queueStop = "ui_toggle_off", adminArm = "ui_warn",
	tutorialStep = "ui_confirm", boostOpen = "ui_open", boostReady = "ui_notify", offlineOpen = "ui_open",
	echoEquip = "ui_confirm", echoTune = "ui_slider", reactorReady = "ui_notify", reactorStabilize = "ui_confirm",
	storyOpen = "ui_open", storyBeat = "ui_page", crate = "ui_open", crateNear = "ui_tick",
	puzzleTap = "ui_tick", cardEndTurn = "ui_page", cardBlock = "ui_locked", travel = "whoosh",

	-- Currency and rewards
	purchase = "purchase", reward = "reward", collect = "collect", unlock = "unlock", researchUnlock = "unlock",
	codeReward = "reward", prestige = "prestige", rebirthBloom = "prestige", missionClaim = "claim",
	achievementClaim = "unlock", dailyClaim = "claim", timedClaim = "claim", seasonClaim = "unlock",
	mailClaim = "claim", tutorialFinish = "reward", comboMilestone = "unlock", discovery = "unlock",
	zoneUnlock = "unlock", boost = "collect", boostActivate = "collect", vaultDeposit = "coin", vaultBank = "coin",
	guildDeposit = "coin", guildCreate = "unlock", guildJoin = "claim", guildLeave = "ui_close",
	expeditionReturn = "claim", offlineCollect = "collect", purchaseResult = "reward", echoCapture = "unlock",
	echoClaim = "claim", storyReveal = "unlock", wheelLand = "reward", crateRare = "prestige", crateClaim = "claim",
	domainReward = "reward", puzzleClear = "collect",

	-- Forge, machines, spectacle
	salvage = "hammer", salvageCrunch = "hammer", echoDismantle = "hammer", autoForge = "hammer",
	machineInstall = "machine", wheelBrake = "machine", crateBrake = "machine", reactor = "rumble",
	reactorPulse = "spark", reactorChannel = "charge", reactorSurge = "impact", rebirthCharge = "charge",
	adminExecute = "impact", expeditionLaunch = "whoosh", wheel = "whoosh", wheelStart = "whoosh",
	wheelCharge = "charge", wheelTick = "wheel_tick", wheelSlow = "wheel_tick", crateOpen = "whoosh",
	crateCharge = "charge", crateTick = "wheel_tick", crateLand = "impact", domainCharge = "charge",
	domainCrack = "spark", domainImpact = "impact", domainBind = "rift_open", cardPlay = "card_flip",
	cardDraw = "card_flip", cardEnergy = "spark", cardPower = "charge",

	-- Boot sequence
	boot = "rift_open", bootStart = "whoosh", bootIgnite = "boot_ignite", bootTension = "charge",
	bootWhoosh = "whoosh", bootStrike = "hammer", bootClang = "hammer", bootSpark = "spark", bootFizz = "spark",
	bootRumble = "rumble", bootImpact = "impact", bootReady = "unlock", bootFinaleFlip = "whoosh",
	bootFinaleBang = "impact", bootAnvilSplit = "hammer", bootSlamCharge = "slam_charge", bootSlamAir = "whoosh",
	bootDebris = "spark", bootFractureTail = "rumble", bootGravity = "rumble", bootAftershock = "rumble",

	-- The sanctuary
	oreMine = "crystal_mine", oreCollect = "crystal_collect", wardenForming = "warden_forming",
	wardenAwake = "warden_awake", wardenStrike = "warden_strike", wardenCrit = "warden_crit",
	wardenSlamCharge = "slam_charge", wardenSlam = "slam", wardenDefeat = "warden_defeat",
	wardenEscape = "warden_escape", waystoneTravel = "waystone", regionEnter = "region_enter",
})

function SoundSheet.enabled(): boolean
	return Manifest.SoundSheet.Id > 0
end

function SoundSheet.assetId(): string
	return `rbxassetid://{Manifest.SoundSheet.Id}`
end

-- The { start, length } slice for a cue, or nil (not mapped / not uploaded).
function SoundSheet.region(cue: string): (number?, number?)
	if not SoundSheet.enabled() then
		return nil, nil
	end
	local voice = SoundSheet.VOICE[cue]
	local region = if voice ~= nil then Manifest.SoundSheet.Regions[voice] else nil
	if region == nil then
		return nil, nil
	end
	return region[1], region[2]
end

-- Level-matching gain for a cue's voice, clamped so nothing jumps wildly.
function SoundSheet.gain(cue: string): number
	local voice = SoundSheet.VOICE[cue]
	local level = if voice ~= nil then Manifest.SoundSheet.Loudness[voice] else nil
	if level == nil then
		return 1
	end
	return math.clamp(10 ^ ((TARGET_LOUDNESS - level) / 20), 0.55, 1.35)
end

return SoundSheet
