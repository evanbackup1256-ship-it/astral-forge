// Maps a cue to its region on the authored sound sheet, plus the sheet's loudness trim.

interface SheetData {
	Id: number;
	Regions: Record<string, [number, number] | undefined>;
	Loudness: Record<string, number | undefined>;
}

const ReplicatedStorage = game.GetService("ReplicatedStorage");

const Manifest = (
	require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
	) as (name: string) => { SoundSheet: SheetData; SoundSheetPrevious?: SheetData }
)("AssetManifest");

const TARGET_LOUDNESS = -20;

const VOICE: Readonly<Record<string, string>> = table.freeze({
	hover: "hover",
	hoverTick: "hoverTick",
	click: "click",
	tick: "tick",
	confirm: "confirm",
	successChime: "successChime",
	locked: "locked",
	error: "error",
	errorBuzz: "errorBuzz",
	page: "page",
	mail: "mail",
	story: "story",
	open: "open",
	close: "close",
	settings: "settings",
	scroll: "scroll",
	toggleOn: "toggleOn",
	toggleOff: "toggleOff",
	sliderStep: "sliderStep",
	sliderCommit: "sliderCommit",
	inputFocus: "inputFocus",
	inputClear: "inputClear",
	tabSwitch: "tabSwitch",
	filterOpen: "filterOpen",
	filterPick: "filterPick",
	amountChange: "amountChange",
	modalOpen: "modalOpen",
	modalPop: "modalPop",
	modalDismiss: "modalDismiss",
	purchaseExit: "purchaseExit",
	playerlistOpen: "playerlistOpen",
	playerlistSelect: "playerlistSelect",
	playerlistAction: "playerlistAction",
	playerlistClose: "playerlistClose",
	noticeInfo: "noticeInfo",
	noticeSuccess: "noticeSuccess",
	noticeWarning: "noticeWarning",
	noticeError: "noticeError",
	noticeSpecial: "noticeSpecial",
	chatSend: "chatSend",
	chatReceive: "chatReceive",
	purchasePress: "purchasePress",
	claimPress: "claimPress",
	dangerPress: "dangerPress",
	preview: "preview",
	reset: "reset",
	roleChange: "roleChange",
	memberRemove: "memberRemove",
	mailRead: "mailRead",
	storyPage: "storyPage",
	leaderboardSwitch: "leaderboardSwitch",
	requestBlocked: "requestBlocked",
	requestTimeout: "requestTimeout",
	notification: "notification",
	systemAlert: "systemAlert",
	crewNudge: "crewNudge",
	invite: "invite",
	codeSubmit: "codeSubmit",
	zoneSelect: "zoneSelect",
	labRoute: "labRoute",
	equip: "equip",
	itemLink: "itemLink",
	itemUnlink: "itemUnlink",
	queueStart: "queueStart",
	queueStop: "queueStop",
	adminArm: "adminArm",
	tutorialStep: "tutorialStep",
	boostOpen: "boostOpen",
	boostReady: "boostReady",
	offlineOpen: "offlineOpen",
	echoEquip: "echoEquip",
	echoTune: "echoTune",
	reactorReady: "reactorReady",
	reactorStabilize: "reactorStabilize",
	storyOpen: "storyOpen",
	storyBeat: "storyBeat",
	crate: "crate",
	crateNear: "crateNear",
	travel: "travel",
	navHover: "navHover",
	dropdownOpen: "dropdownOpen",
	dropdownClose: "dropdownClose",
	copyDone: "copyDone",
	dragGrab: "dragGrab",
	dragDrop: "dragDrop",
	dragSnap: "dragSnap",
	favoriteOn: "favoriteOn",
	favoriteOff: "favoriteOff",
	ratingStar: "ratingStar",
	searchType: "searchType",
	countTick: "countTick",
	stepNext: "stepNext",
	stepBack: "stepBack",
	reportSubmit: "reportSubmit",
	feedbackSubmit: "feedbackSubmit",
	guildAnnounce: "guildAnnounce",
	badgeEarn: "badgeEarn",
	artifactEquip: "artifactEquip",
	artifactUpgrade: "artifactUpgrade",
	crateSeal: "crateSeal",
	crateOrbit: "crateOrbit",
	crateRarityStep: "crateRarityStep",
	crateRevealEpic: "crateRevealEpic",
	crateRevealMythic: "crateRevealMythic",
	rebirthIgnite: "rebirthIgnite",
	rebirthShockwave: "rebirthShockwave",
	rebirthTierUp: "rebirthTierUp",
	rebirthAscend: "rebirthAscend",

	purchase: "purchase",
	reward: "reward",
	collect: "collect",
	unlock: "unlock",
	researchUnlock: "researchUnlock",
	codeReward: "codeReward",
	prestige: "prestige",
	rebirthBloom: "rebirthBloom",
	missionClaim: "missionClaim",
	achievementClaim: "achievementClaim",
	dailyClaim: "dailyClaim",
	timedClaim: "timedClaim",
	seasonClaim: "seasonClaim",
	mailClaim: "mailClaim",
	tutorialFinish: "tutorialFinish",
	comboMilestone: "comboMilestone",
	discovery: "discovery",
	zoneUnlock: "zoneUnlock",
	boost: "boost",
	boostActivate: "boostActivate",
	vaultDeposit: "vaultDeposit",
	vaultBank: "vaultBank",
	guildDeposit: "guildDeposit",
	guildCreate: "guildCreate",
	guildJoin: "guildJoin",
	guildLeave: "guildLeave",
	expeditionReturn: "expeditionReturn",
	offlineCollect: "offlineCollect",
	purchaseResult: "purchaseResult",
	echoCapture: "echoCapture",
	echoClaim: "echoClaim",
	storyReveal: "storyReveal",
	wheelLand: "wheelLand",
	crateRare: "crateRare",
	crateClaim: "crateClaim",
	domainReward: "domainReward",

	salvage: "salvage",
	salvageCrunch: "salvageCrunch",
	echoDismantle: "echoDismantle",
	autoForge: "autoForge",
	machineInstall: "machineInstall",
	wheelBrake: "wheelBrake",
	crateBrake: "crateBrake",
	reactor: "reactor",
	reactorPulse: "reactorPulse",
	reactorSurge: "reactorSurge",
	rebirthCharge: "rebirthCharge",
	adminExecute: "adminExecute",
	expeditionLaunch: "expeditionLaunch",
	wheel: "wheel",
	wheelStart: "wheelStart",
	wheelCharge: "wheelCharge",
	wheelTick: "wheelTick",
	wheelSlow: "wheelSlow",
	crateOpen: "crateOpen",
	crateCharge: "crateCharge",
	crateTick: "crateTick",
	crateLand: "crateLand",
	domainCharge: "domainCharge",
	domainCrack: "domainCrack",
	domainImpact: "domainImpact",
	domainBind: "domainBind",

	boot: "boot",
	bootStart: "bootStart",
	bootReady: "bootReady",
	bootFinaleBang: "bootFinaleBang",

	navOpenOverview: "navOpenOverview",
	navHoverOverview: "navHoverOverview",
	navOpenWorkshop: "navOpenWorkshop",
	navHoverWorkshop: "navHoverWorkshop",
	navOpenInventory: "navOpenInventory",
	navHoverInventory: "navHoverInventory",
	navOpenResearch: "navOpenResearch",
	navHoverResearch: "navHoverResearch",
	navOpenShop: "navOpenShop",
	navHoverShop: "navHoverShop",
	navOpenSettings: "navOpenSettings",
	navHoverSettings: "navHoverSettings",
	navOpenWorlds: "navOpenWorlds",
	navHoverWorlds: "navHoverWorlds",
	navOpenMissions: "navOpenMissions",
	navHoverMissions: "navHoverMissions",
	navOpenRewards: "navOpenRewards",
	navHoverRewards: "navHoverRewards",
	navOpenBoosts: "navOpenBoosts",
	navHoverBoosts: "navHoverBoosts",
	navOpenStarGrid: "navOpenStarGrid",
	navHoverStarGrid: "navHoverStarGrid",
	navOpenEchoes: "navOpenEchoes",
	navHoverEchoes: "navHoverEchoes",
	navOpenContinuum: "navOpenContinuum",
	navHoverContinuum: "navHoverContinuum",
	navOpenLab: "navOpenLab",
	navHoverLab: "navHoverLab",
	navOpenAnomaly: "navOpenAnomaly",
	navHoverAnomaly: "navHoverAnomaly",
	navOpenWheel: "navOpenWheel",
	navHoverWheel: "navHoverWheel",
	navOpenCommand: "navOpenCommand",
	navHoverCommand: "navHoverCommand",
	navOpenStory: "navOpenStory",
	navHoverStory: "navHoverStory",
	navOpenMail: "navOpenMail",
	navHoverMail: "navHoverMail",
	navOpenChat: "navOpenChat",
	navHoverChat: "navHoverChat",
	navOpenCrew: "navOpenCrew",
	navHoverCrew: "navHoverCrew",
	navOpenMilestones: "navOpenMilestones",
	navHoverMilestones: "navHoverMilestones",
	navOpenConvergence: "navOpenConvergence",
	navHoverConvergence: "navHoverConvergence",
	navOpenGuild: "navOpenGuild",
	navHoverGuild: "navHoverGuild",
	navOpenLeaderboards: "navOpenLeaderboards",
	navHoverLeaderboards: "navHoverLeaderboards",
	navOpenTrade: "navOpenTrade",
	navHoverTrade: "navHoverTrade",
	navOpenCredits: "navOpenCredits",
	navHoverCredits: "navHoverCredits",
	navOpenAdmin: "navOpenAdmin",
	navHoverAdmin: "navHoverAdmin",
	navOpenForgePath: "navOpenForgePath",
	navHoverForgePath: "navHoverForgePath",
	navOpenFoundry: "navOpenFoundry",
	navHoverFoundry: "navHoverFoundry",
	navOpenBazaar: "navOpenWheel",
	navHoverBazaar: "navHoverWheel",
	// Star Charts and Signal Cipher replaced Next Rank (Continuum) and Shift Plan (Anomaly) in the nav,
	// so they inherit those pages' voices
	navOpenCharts: "navOpenContinuum",
	navHoverCharts: "navHoverContinuum",
	navOpenCipher: "navOpenAnomaly",
	navHoverCipher: "navHoverAnomaly",
	clickHover: "clickHover",
	confirmHover: "confirmHover",
	settingsHover: "settingsHover",
	purchasePressHover: "purchasePressHover",
	claimPressHover: "claimPressHover",
	codeSubmitHover: "codeSubmitHover",
	zoneSelectHover: "zoneSelectHover",
	labRouteHover: "labRouteHover",
	playerlistActionHover: "playerlistActionHover",
	playerlistSelectHover: "playerlistSelectHover",
	equipHover: "equipHover",
	dangerPressHover: "dangerPressHover",
	closeHover: "closeHover",
	tickHover: "tickHover",
	openHover: "openHover",
	tabSwitchHover: "tabSwitchHover",
	mailHover: "mailHover",
	storyHover: "storyHover",
	toggleOnHover: "toggleOnHover",
	toggleOffHover: "toggleOffHover",
	lockedHover: "lockedHover",
	errorHover: "errorHover",
	prestigeHover: "prestigeHover",
	domainChargeHover: "domainChargeHover",
	vaultBankHover: "vaultBankHover",
	guildCreateHover: "guildCreateHover",
	guildJoinHover: "guildJoinHover",
	inviteHover: "inviteHover",
	travelHover: "travelHover",
	queueStopHover: "queueStopHover",
	queueStartHover: "queueStartHover",
	boostHover: "boostHover",
	reactorPulseHover: "reactorPulseHover",
	crateOpenHover: "crateOpenHover",
	wheelStartHover: "wheelStartHover",
	rewardHover: "rewardHover",
	rebirthChargeHover: "rebirthChargeHover",
	missionClaimHover: "missionClaimHover",
	leaderboardSwitchHover: "leaderboardSwitchHover",
	adminArmHover: "adminArmHover",
	memberRemoveHover: "memberRemoveHover",
	roleChangeHover: "roleChangeHover",
	previewHover: "previewHover",
	resetHover: "resetHover",
	chatSendHover: "chatSendHover",
	boostOpenHover: "boostOpenHover",
	vaultDepositHover: "vaultDepositHover",
	forgePress: "forgePress",
	corePress: "corePress",
	wavePress: "wavePress",
	labPress: "labPress",
	commandPress: "commandPress",
	adminPress: "adminPress",
	creditsPress: "creditsPress",
	chatPress: "chatPress",
	continuumPress: "continuumPress",
	missionPress: "missionPress",
	overviewPress: "overviewPress",
	foundryOpen: "foundryOpen",
	foundryPlace: "foundryPlace",
	foundryPickUp: "foundryPickUp",
	foundryRotate: "foundryRotate",
	foundryFuse: "foundryFuse",
	foundryDraw: "foundryDraw",
	foundryDrawRare: "foundryDrawRare",
	foundryExpand: "foundryExpand",
	foundryIgnite: "foundryIgnite",
	foundryIgniteMiss: "foundryIgniteMiss",
	foundrySurge: "foundrySurge",
	foundryFlow: "foundryFlow",
});

const Primary = Manifest.SoundSheet;
const Previous = Manifest.SoundSheetPrevious;
let active: SheetData = Primary.Id > 0 ? Primary : Previous ?? Primary;

function enabled(): boolean {
	return Primary.Id > 0 || (Previous !== undefined && Previous.Id > 0);
}

function assetId(): string {
	return `rbxassetid://${active.Id}`;
}

function primaryAsset(): string | undefined {
	return Primary.Id > 0 ? `rbxassetid://${Primary.Id}` : undefined;
}

function previousAsset(): string | undefined {
	return Previous !== undefined && Previous.Id > 0 ? `rbxassetid://${Previous.Id}` : undefined;
}

function use(previous: boolean) {
	active = previous && Previous !== undefined ? Previous : Primary;
}

function voiceName(cue: string): string | undefined {
	const mapped = VOICE[cue] as string | undefined;
	if (mapped !== undefined) {
		return mapped;
	}
	if (active.Regions[cue] !== undefined) {
		return cue;
	}
	return undefined;
}

function region(cue: string): LuaTuple<[number?, number?]> {
	if (!enabled()) {
		return $tuple(undefined, undefined);
	}
	const voice = voiceName(cue);
	const entry = voice !== undefined ? active.Regions[voice] : undefined;
	if (entry === undefined) {
		return $tuple(undefined, undefined);
	}
	return $tuple(entry[0], entry[1]);
}

function gain(cue: string): number {
	const voice = voiceName(cue);
	const level = voice !== undefined ? active.Loudness[voice] : undefined;
	if (level === undefined) {
		return 1;
	}
	return math.clamp(10 ** ((TARGET_LOUDNESS - level) / 20), 0.55, 1.35);
}

const SoundSheet = { VOICE, enabled, assetId, primaryAsset, previousAsset, use, region, gain };

export = SoundSheet;
