--!strict
-- Which slice of the sound sheet each audio cue plays.
--
-- tools/assetgen renders every sound the game makes into one file (Roblox
-- caps audio uploads per month, so one file carries all of them), and the
-- mixer plays a cue as a PlaybackRegion of it. AssetManifest has the regions
-- and each voice's loudness; this module maps each cue onto its own designed
-- voice (near 1:1 — share only when intentional).
--
-- Until the sheet is uploaded (Manifest.SoundSheet.Id == 0) nothing here is
-- used and the mixer keeps its original sounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Manifest = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("AssetManifest"))

local SoundSheet = {}

-- Every voice is levelled to this loudness (dB RMS while sounding) before the
-- cue's own volume applies, so a soft chime and a hard hit read as intended.
local TARGET_LOUDNESS = -20

-- cue -> voice. Voice keys match cue names and sheet regions from sfx.py.
SoundSheet.VOICE = table.freeze({
	-- Interface chrome
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

	-- Currency and rewards
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

	-- Forge, machines, spectacle
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

	-- Boot sequence
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

	-- Sanctuary
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
})

function SoundSheet.enabled(): boolean
	return Manifest.SoundSheet.Id > 0
end

function SoundSheet.assetId(): string
	return `rbxassetid://{Manifest.SoundSheet.Id}`
end

-- The { start, length } slice for a cue, or nil (not mapped / not uploaded).
local function voiceName(cue: string): string?
	local mapped = SoundSheet.VOICE[cue]
	if mapped ~= nil then
		return mapped
	end
	-- Newer cues are packed under their own name and are not all listed above.
	if Manifest.SoundSheet.Regions[cue] ~= nil then
		return cue
	end
	return nil
end

function SoundSheet.region(cue: string): (number?, number?)
	if not SoundSheet.enabled() then
		return nil, nil
	end
	local voice = voiceName(cue)
	local region = if voice ~= nil then Manifest.SoundSheet.Regions[voice] else nil
	if region == nil then
		return nil, nil
	end
	return region[1], region[2]
end

-- Level-matching gain for a cue's voice, clamped so nothing jumps wildly.
function SoundSheet.gain(cue: string): number
	local voice = voiceName(cue)
	local level = if voice ~= nil then Manifest.SoundSheet.Loudness[voice] else nil
	if level == nil then
		return 1
	end
	return math.clamp(10 ^ ((TARGET_LOUDNESS - level) / 20), 0.55, 1.35)
end

return SoundSheet
