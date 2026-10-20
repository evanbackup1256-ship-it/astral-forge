import { ClientLog } from "../CoreKit/log";
import * as Voicing from "./audioVoicing";
import { DECK_NAMES as MUSIC_DECK_NAMES, MusicDirector } from "./musicDirector";
import SoundSheet = require("./soundSheet");

const ContentProvider = game.GetService("ContentProvider");
const SoundService = game.GetService("SoundService");
const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface AssetManifestApi {
	Ambience?: {
		Id: number;
		Regions: Record<string, [number, number] | undefined>;
		Loudness?: Record<string, number | undefined>;
	};
}
const AssetManifest = (
	require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
	) as (name: string) => AssetManifestApi
)("AssetManifest");

const AMBIENCE_BED = "amb_heart";
const AMBIENCE_VOLUME = 0.32;
const SHEET_CHANNELS = 14;
const UI_HOVER = "rbxassetid://10066931761";
const UI_CLICK = "rbxassetid://10066921516";
const UI_CONFIRM = "rbxassetid://10066947742";
const UI_ALERT = UI_CONFIRM;
const UI_CHIME = UI_CONFIRM;
const UI_TICK = UI_HOVER;
const UI_DOWN = UI_CLICK;
const SFX_WHOOSH = UI_CONFIRM;
const SFX_MOTOR = UI_HOVER;
const SFX_RAMP = UI_CONFIRM;
const SFX_SWEEP = UI_HOVER;
const SFX_TRAVEL = UI_CONFIRM;
const SFX_IMPACT = UI_CLICK;
const SFX_PULSE = UI_CONFIRM;
const SFX_FAIL = UI_CLICK;
const UI_SNAP = UI_CLICK;
const UI_SOFT = UI_HOVER;
const SFX_BIND = UI_CONFIRM;
const SFX_GLINT = UI_CONFIRM;
const SFX_POP2 = UI_CLICK;
const SFX_THUD = UI_CLICK;
const UI_SUCCESS = UI_CONFIRM;
const UI_SUCCESS_SOFT = UI_CHIME;
const UI_POP_IN = SFX_RAMP;
const UI_POP_OUT = UI_DOWN;
const UI_SWITCH = UI_HOVER;
const UI_SELECT = UI_HOVER;
const UI_DESELECT = UI_DOWN;
const UI_WARN = UI_ALERT;
const UI_NOTIFY = UI_CHIME;
const UI_POP = UI_CONFIRM;
const UI_SLIDE = SFX_SWEEP;
const SFX_WHOOSH_SOFT = SFX_WHOOSH;
const SFX_COIN = UI_CHIME;
const SFX_COLLECT = UI_CONFIRM;
const SFX_BLOOM = SFX_WHOOSH;
const SFX_GATE = SFX_RAMP;
const SFX_DEEP = SFX_IMPACT;
const SFX_SHIFT = SFX_MOTOR;
const SFX_LOCK = UI_DOWN;

export const AUDIO_ASSET_MANIFEST = [
	UI_HOVER, UI_CLICK, UI_CONFIRM, UI_ALERT, UI_CHIME, UI_TICK, UI_DOWN, SFX_WHOOSH, SFX_MOTOR,
	SFX_RAMP, SFX_SWEEP, SFX_TRAVEL, SFX_IMPACT, SFX_PULSE, SFX_FAIL, UI_SNAP, UI_SOFT, SFX_BIND,
	SFX_GLINT, SFX_POP2, SFX_THUD,
];

interface CueSpec {
	asset: string;
	volume: number;
	speed: number;
	variance: number;
	cooldown: number;
	stopAfter?: number;
}

const CUES: Record<string, CueSpec | undefined> = {
	hover: { asset: UI_HOVER, volume: 0.18, speed: 1.32, variance: 0.012, cooldown: 0.06, stopAfter: 0.08 },
	click: { asset: UI_CLICK, volume: 0.4, speed: 1, variance: 0.008, cooldown: 0.04, stopAfter: 0.12 },
	tick: { asset: UI_TICK, volume: 0.16, speed: 1.48, variance: 0.016, cooldown: 0.05, stopAfter: 0.07 },
	confirm: { asset: UI_CONFIRM, volume: 0.42, speed: 1.18, variance: 0.006, cooldown: 0.07, stopAfter: 0.42 },
	purchase: { asset: SFX_COIN, volume: 0.32, speed: 1.55, variance: 0.01, cooldown: 0.12, stopAfter: 0.24 },
	collect: { asset: SFX_COLLECT, volume: 0.3, speed: 1.1, variance: 0.012, cooldown: 0.09, stopAfter: 0.48 },
	reward: { asset: UI_SUCCESS, volume: 0.4, speed: 0.82, variance: 0.004, cooldown: 0.14, stopAfter: 0.82 },
	unlock: { asset: SFX_TRAVEL, volume: 0.3, speed: 1.02, variance: 0.01, cooldown: 0.22, stopAfter: 0.95 },
	locked: { asset: SFX_LOCK, volume: 0.26, speed: 0.74, variance: 0, cooldown: 0.14, stopAfter: 0.26 },
	error: { asset: SFX_FAIL, volume: 0.34, speed: 0.62, variance: 0, cooldown: 0.2, stopAfter: 0.48 },
	page: { asset: UI_SWITCH, volume: 0.2, speed: 0.86, variance: 0.008, cooldown: 0.05, stopAfter: 0.22 },
	mail: { asset: UI_SLIDE, volume: 0.24, speed: 1.12, variance: 0.01, cooldown: 0.12, stopAfter: 0.48 },
	story: { asset: SFX_MOTOR, volume: 0.22, speed: 0.84, variance: 0.008, cooldown: 0.18, stopAfter: 0.7 },
	open: { asset: UI_POP_IN, volume: 0.2, speed: 1.36, variance: 0.008, cooldown: 0.08, stopAfter: 0.2 },
	close: { asset: UI_POP_OUT, volume: 0.26, speed: 1.08, variance: 0.01, cooldown: 0.08, stopAfter: 0.38 },
	reactor: { asset: SFX_PULSE, volume: 0.28, speed: 0.94, variance: 0.012, cooldown: 0.08, stopAfter: 0.42 },
	storyOpen: { asset: SFX_MOTOR, volume: 0.26, speed: 0.9, variance: 0, cooldown: 0.42, stopAfter: 0.82 },
	storyBeat: { asset: UI_SELECT, volume: 0.18, speed: 0.92, variance: 0.012, cooldown: 0.12, stopAfter: 0.2 },
	storyReveal: { asset: UI_SUCCESS_SOFT, volume: 0.22, speed: 1.18, variance: 0.01, cooldown: 0.11, stopAfter: 0.48 },
	wheel: { asset: UI_HOVER, volume: 0.16, speed: 1.16, variance: 0.025, cooldown: 0.065, stopAfter: 0.11 },
	crate: { asset: SFX_RAMP, volume: 0.2, speed: 0.96, variance: 0.006, cooldown: 0.36, stopAfter: 0.58 },
	boost: { asset: SFX_WHOOSH, volume: 0.3, speed: 1.16, variance: 0.014, cooldown: 0.18, stopAfter: 0.8 },
	travel: { asset: SFX_SWEEP, volume: 0.22, speed: 0.72, variance: 0.006, cooldown: 0.16, stopAfter: 0.85 },
	equip: { asset: UI_SELECT, volume: 0.2, speed: 1.04, variance: 0.01, cooldown: 0.11, stopAfter: 0.22 },
	prestige: { asset: SFX_BLOOM, volume: 0.44, speed: 0.92, variance: 0, cooldown: 0.12, stopAfter: 1.05 },
	rebirthCharge: { asset: SFX_WHOOSH_SOFT, volume: 0.36, speed: 0.78, variance: 0, cooldown: 0.12, stopAfter: 0.88 },
	rebirthBloom: { asset: SFX_SHIFT, volume: 0.4, speed: 1.06, variance: 0, cooldown: 0.14, stopAfter: 0.95 },
	domainCharge: { asset: SFX_GATE, volume: 0.46, speed: 0.76, variance: 0, cooldown: 0.12, stopAfter: 0.72 },
	domainCrack: { asset: SFX_DEEP, volume: 0.38, speed: 0.94, variance: 0.012, cooldown: 0.08, stopAfter: 0.42 },
	domainImpact: { asset: SFX_IMPACT, volume: 0.44, speed: 0.88, variance: 0, cooldown: 0.12, stopAfter: 0.7 },
	domainReward: { asset: SFX_GLINT, volume: 0.46, speed: 1.06, variance: 0, cooldown: 0.14, stopAfter: 0.72 },
	hoverTick: { asset: UI_TICK, volume: 0.22, speed: 1.25, variance: 0.03, cooldown: 0.04, stopAfter: 0.15 },
	successChime: { asset: UI_SUCCESS, volume: 0.42, speed: 1.15, variance: 0.01, cooldown: 0.1, stopAfter: 0.75 },
	errorBuzz: { asset: SFX_FAIL, volume: 0.38, speed: 0.78, variance: 0, cooldown: 0.15, stopAfter: 0.45 },
	modalPop: { asset: UI_POP_IN, volume: 0.35, speed: 1.14, variance: 0.01, cooldown: 0.08, stopAfter: 0.38 },
	modalDismiss: { asset: UI_POP_OUT, volume: 0.3, speed: 0.98, variance: 0.01, cooldown: 0.08, stopAfter: 0.32 },
	salvageCrunch: { asset: SFX_MOTOR, volume: 0.36, speed: 1.24, variance: 0.02, cooldown: 0.12, stopAfter: 0.55 },
	comboMilestone: { asset: UI_SUCCESS_SOFT, volume: 0.46, speed: 1.32, variance: 0.01, cooldown: 0.2, stopAfter: 0.85 },
	vaultDeposit: { asset: SFX_COIN, volume: 0.44, speed: 1.16, variance: 0.014, cooldown: 0.08, stopAfter: 0.58 },
	domainBind: { asset: SFX_BIND, volume: 0.46, speed: 1.02, variance: 0, cooldown: 0.16, stopAfter: 0.88 },
	discovery: { asset: SFX_TRAVEL, volume: 0.25, speed: 1.08, variance: 0.006, cooldown: 0.22, stopAfter: 0.92 },
	reactorReady: { asset: SFX_PULSE, volume: 0.26, speed: 0.98, variance: 0, cooldown: 0.2, stopAfter: 0.42 },
	chatSend: { asset: UI_SELECT, volume: 0.15, speed: 1.28, variance: 0.014, cooldown: 0.09, stopAfter: 0.13 },
	chatReceive: { asset: UI_CONFIRM, volume: 0.17, speed: 1.28, variance: 0.014, cooldown: 0.1, stopAfter: 0.35 },
	boot: { asset: UI_CONFIRM, volume: 0.2, speed: 1.12, variance: 0, cooldown: 0.46, stopAfter: 0.62 },
	bootStart: { asset: SFX_RAMP, volume: 0.18, speed: 1.06, variance: 0, cooldown: 0.34, stopAfter: 0.52 },
	bootReady: { asset: UI_CONFIRM, volume: 0.18, speed: 1.18, variance: 0, cooldown: 0.38, stopAfter: 0.5 },
	bootFinaleBang: { asset: SFX_IMPACT, volume: 0.27, speed: 1.02, variance: 0, cooldown: 0.9, stopAfter: 0.5 },
	wheelStart: { asset: SFX_RAMP, volume: 0.22, speed: 0.92, variance: 0.006, cooldown: 0.28, stopAfter: 0.62 },
	wheelCharge: { asset: UI_CHIME, volume: 0.14, speed: 0.96, variance: 0.006, cooldown: 0.28, stopAfter: 0.42 },
	wheelTick: { asset: UI_HOVER, volume: 0.12, speed: 1.18, variance: 0.03, cooldown: 0.05, stopAfter: 0.09 },
	wheelSlow: { asset: UI_HOVER, volume: 0.14, speed: 1.02, variance: 0.014, cooldown: 0.11, stopAfter: 0.12 },
	wheelBrake: { asset: UI_DOWN, volume: 0.22, speed: 0.94, variance: 0, cooldown: 0.32, stopAfter: 0.48 },
	wheelLand: { asset: UI_CONFIRM, volume: 0.29, speed: 1.02, variance: 0, cooldown: 0.34, stopAfter: 0.62 },
	crateOpen: { asset: SFX_SWEEP, volume: 0.21, speed: 1.12, variance: 0.006, cooldown: 0.32, stopAfter: 0.64 },
	crateCharge: { asset: UI_CHIME, volume: 0.14, speed: 0.92, variance: 0.004, cooldown: 0.3, stopAfter: 0.4 },
	crateTick: { asset: UI_HOVER, volume: 0.11, speed: 1.18, variance: 0.025, cooldown: 0.042, stopAfter: 0.08 },
	crateNear: { asset: SFX_MOTOR, volume: 0.28, speed: 0.9, variance: 0.018, cooldown: 0.12, stopAfter: 0.55 },
	crateBrake: { asset: UI_DOWN, volume: 0.22, speed: 0.92, variance: 0.008, cooldown: 0.3, stopAfter: 0.48 },
	crateLand: { asset: UI_CONFIRM, volume: 0.27, speed: 1.02, variance: 0, cooldown: 0.36, stopAfter: 0.6 },
	crateRare: { asset: SFX_TRAVEL, volume: 0.28, speed: 1.08, variance: 0.004, cooldown: 0.36, stopAfter: 0.88 },
	crateClaim: { asset: UI_CONFIRM, volume: 0.27, speed: 1.08, variance: 0.008, cooldown: 0.2, stopAfter: 0.68 },
	settings: { asset: UI_SWITCH, volume: 0.19, speed: 1.08, variance: 0.012, cooldown: 0.1, stopAfter: 0.16 },
	scroll: { asset: UI_HOVER, volume: 0.075, speed: 1.3, variance: 0.035, cooldown: 0.09, stopAfter: 0.085 },
	tutorialStep: { asset: UI_SELECT, volume: 0.15, speed: 1.1, variance: 0.01, cooldown: 0.12, stopAfter: 0.16 },
	tutorialFinish: { asset: UI_CONFIRM, volume: 0.27, speed: 1.08, variance: 0, cooldown: 0.4, stopAfter: 0.72 },
	reactorPulse: { asset: SFX_PULSE, volume: 0.32, speed: 1.18, variance: 0.014, cooldown: 0.06, stopAfter: 0.28 },
	reactorStabilize: { asset: SFX_WHOOSH, volume: 0.34, speed: 1.04, variance: 0, cooldown: 0.22, stopAfter: 0.72 },
	toggleOn: { asset: UI_POP_IN, volume: 0.18, speed: 1.14, variance: 0.01, cooldown: 0.075, stopAfter: 0.18 },
	toggleOff: { asset: UI_DOWN, volume: 0.18, speed: 1.28, variance: 0.01, cooldown: 0.075, stopAfter: 0.24 },
	sliderStep: { asset: UI_HOVER, volume: 0.2, speed: 1.38, variance: 0.028, cooldown: 0.04, stopAfter: 0.11 },
	sliderCommit: { asset: UI_CONFIRM, volume: 0.19, speed: 1.18, variance: 0.008, cooldown: 0.08, stopAfter: 0.24 },
	inputFocus: { asset: UI_SELECT, volume: 0.16, speed: 1.18, variance: 0.012, cooldown: 0.1, stopAfter: 0.14 },
	inputClear: { asset: UI_DOWN, volume: 0.16, speed: 1.34, variance: 0.01, cooldown: 0.09, stopAfter: 0.18 },
	claimPress: { asset: UI_CONFIRM, volume: 0.16, speed: 1.28, variance: 0.012, cooldown: 0.08, stopAfter: 0.34 },
	purchasePress: { asset: SFX_COIN, volume: 0.28, speed: 1.5, variance: 0.01, cooldown: 0.08, stopAfter: 0.18 },
	dangerPress: { asset: UI_ALERT, volume: 0.17, speed: 1.02, variance: 0.012, cooldown: 0.1, stopAfter: 0.24 },
	adminArm: { asset: UI_DOWN, volume: 0.23, speed: 0.84, variance: 0, cooldown: 0.2, stopAfter: 0.42 },
	adminExecute: { asset: SFX_IMPACT, volume: 0.28, speed: 1.08, variance: 0, cooldown: 0.34, stopAfter: 0.55 },
	invite: { asset: UI_CONFIRM, volume: 0.23, speed: 1.24, variance: 0.012, cooldown: 0.2, stopAfter: 0.48 },
	queueStart: { asset: UI_CHIME, volume: 0.17, speed: 1.12, variance: 0.01, cooldown: 0.14, stopAfter: 0.28 },
	queueStop: { asset: UI_DOWN, volume: 0.19, speed: 1.2, variance: 0.01, cooldown: 0.14, stopAfter: 0.34 },
	vaultBank: { asset: UI_CHIME, volume: 0.28, speed: 0.98, variance: 0.012, cooldown: 0.12, stopAfter: 0.46 },
	machineInstall: { asset: UI_CONFIRM, volume: 0.2, speed: 1.08, variance: 0.01, cooldown: 0.12, stopAfter: 0.42 },
	researchUnlock: { asset: SFX_WHOOSH, volume: 0.24, speed: 0.88, variance: 0.006, cooldown: 0.15, stopAfter: 0.55 },
	salvage: { asset: UI_DOWN, volume: 0.15, speed: 1.2, variance: 0.012, cooldown: 0.15, stopAfter: 0.22 },
	codeSubmit: { asset: UI_CHIME, volume: 0.2, speed: 1.18, variance: 0.012, cooldown: 0.16, stopAfter: 0.3 },
	notification: { asset: UI_NOTIFY, volume: 0.22, speed: 1.04, variance: 0.008, cooldown: 0.18, stopAfter: 0.48 },
	missionClaim: { asset: UI_CHIME, volume: 0.3, speed: 1.06, variance: 0.012, cooldown: 0.16, stopAfter: 0.52 },
	achievementClaim: { asset: SFX_TRAVEL, volume: 0.27, speed: 1.08, variance: 0.004, cooldown: 0.3, stopAfter: 0.88 },
	dailyClaim: { asset: UI_CONFIRM, volume: 0.28, speed: 1.12, variance: 0.01, cooldown: 0.22, stopAfter: 0.68 },
	timedClaim: { asset: UI_CONFIRM, volume: 0.22, speed: 1.16, variance: 0.008, cooldown: 0.18, stopAfter: 0.52 },
	seasonClaim: { asset: SFX_TRAVEL, volume: 0.28, speed: 1.02, variance: 0.004, cooldown: 0.32, stopAfter: 0.92 },
	guildDeposit: { asset: SFX_COLLECT, volume: 0.28, speed: 1.02, variance: 0.01, cooldown: 0.15, stopAfter: 0.52 },
	guildCreate: { asset: SFX_COIN, volume: 0.34, speed: 0.94, variance: 0, cooldown: 0.22, stopAfter: 0.78 },
	guildJoin: { asset: UI_POP_IN, volume: 0.3, speed: 1.04, variance: 0.008, cooldown: 0.22, stopAfter: 0.55 },
	guildLeave: { asset: UI_POP_OUT, volume: 0.28, speed: 0.92, variance: 0, cooldown: 0.2, stopAfter: 0.5 },
	expeditionLaunch: { asset: SFX_SWEEP, volume: 0.28, speed: 0.98, variance: 0.008, cooldown: 0.28, stopAfter: 0.92 },
	expeditionReturn: { asset: SFX_TRAVEL, volume: 0.28, speed: 1.14, variance: 0.008, cooldown: 0.28, stopAfter: 0.92 },
	zoneUnlock: { asset: SFX_TRAVEL, volume: 0.29, speed: 1.02, variance: 0.004, cooldown: 0.34, stopAfter: 0.95 },
	zoneSelect: { asset: SFX_SWEEP, volume: 0.3, speed: 1.14, variance: 0.01, cooldown: 0.2, stopAfter: 0.92 },
	mailClaim: { asset: UI_CONFIRM, volume: 0.27, speed: 1.12, variance: 0.008, cooldown: 0.2, stopAfter: 0.66 },
	itemLink: { asset: UI_CONFIRM, volume: 0.2, speed: 1.08, variance: 0.008, cooldown: 0.15, stopAfter: 0.42 },
	itemUnlink: { asset: UI_DOWN, volume: 0.16, speed: 1.12, variance: 0.008, cooldown: 0.15, stopAfter: 0.28 },
	labRoute: { asset: SFX_PULSE, volume: 0.22, speed: 1.34, variance: 0.018, cooldown: 0.09, stopAfter: 0.25 },
	autoForge: { asset: UI_CHIME, volume: 0.19, speed: 1.08, variance: 0.008, cooldown: 0.18, stopAfter: 0.34 },
	crewNudge: { asset: UI_CONFIRM, volume: 0.25, speed: 1.3, variance: 0.012, cooldown: 0.28, stopAfter: 0.48 },
	systemAlert: { asset: UI_ALERT, volume: 0.28, speed: 0.94, variance: 0.008, cooldown: 0.3, stopAfter: 0.5 },
	boostActivate: { asset: SFX_WHOOSH, volume: 0.28, speed: 1.18, variance: 0.01, cooldown: 0.24, stopAfter: 0.72 },
	codeReward: { asset: SFX_TRAVEL, volume: 0.25, speed: 1.14, variance: 0.004, cooldown: 0.26, stopAfter: 0.82 },
	tabSwitch: { asset: UI_SWITCH, volume: 0.26, speed: 1.16, variance: 0.01, cooldown: 0.06, stopAfter: 0.18 },
	filterOpen: { asset: SFX_RAMP, volume: 0.19, speed: 1.24, variance: 0.01, cooldown: 0.08, stopAfter: 0.24 },
	filterPick: { asset: UI_HOVER, volume: 0.17, speed: 1.34, variance: 0.018, cooldown: 0.05, stopAfter: 0.1 },
	amountChange: { asset: UI_HOVER, volume: 0.24, speed: 1.24, variance: 0.022, cooldown: 0.055, stopAfter: 0.14 },
	preview: { asset: SFX_TRAVEL, volume: 0.22, speed: 0.9, variance: 0.005, cooldown: 0.18, stopAfter: 0.72 },
	reset: { asset: UI_DOWN, volume: 0.23, speed: 0.82, variance: 0.005, cooldown: 0.2, stopAfter: 0.55 },
	roleChange: { asset: UI_SWITCH, volume: 0.18, speed: 1.02, variance: 0.006, cooldown: 0.16, stopAfter: 0.2 },
	memberRemove: { asset: UI_DOWN, volume: 0.2, speed: 0.92, variance: 0.006, cooldown: 0.2, stopAfter: 0.34 },
	mailRead: { asset: UI_CONFIRM, volume: 0.19, speed: 1.34, variance: 0.01, cooldown: 0.12, stopAfter: 0.32 },
	storyPage: { asset: UI_HOVER, volume: 0.16, speed: 0.84, variance: 0.012, cooldown: 0.1, stopAfter: 0.18 },
	leaderboardSwitch: { asset: UI_CHIME, volume: 0.22, speed: 1.22, variance: 0.012, cooldown: 0.1, stopAfter: 0.3 },
	requestBlocked: { asset: UI_DOWN, volume: 0.15, speed: 1.42, variance: 0, cooldown: 0.15, stopAfter: 0.2 },
	requestTimeout: { asset: SFX_FAIL, volume: 0.3, speed: 0.9, variance: 0, cooldown: 0.45, stopAfter: 1.1 },
	modalOpen: { asset: SFX_RAMP, volume: 0.21, speed: 0.98, variance: 0.008, cooldown: 0.14, stopAfter: 0.52 },
	offlineOpen: { asset: SFX_TRAVEL, volume: 0.25, speed: 1.18, variance: 0, cooldown: 0.45, stopAfter: 0.82 },
	offlineCollect: { asset: SFX_TRAVEL, volume: 0.26, speed: 1.12, variance: 0.004, cooldown: 0.4, stopAfter: 0.88 },
	reactorSurge: { asset: SFX_WHOOSH, volume: 0.28, speed: 0.9, variance: 0.008, cooldown: 0.35, stopAfter: 0.82 },
	purchaseResult: { asset: UI_CONFIRM, volume: 0.27, speed: 1.06, variance: 0.004, cooldown: 0.3, stopAfter: 0.76 },
	purchaseExit: { asset: SFX_RAMP, volume: 0.18, speed: 1.34, variance: 0, cooldown: 0.18, stopAfter: 0.34 },
	playerlistOpen: { asset: SFX_RAMP, volume: 0.2, speed: 1.18, variance: 0.006, cooldown: 0.2, stopAfter: 0.42 },
	playerlistSelect: { asset: UI_SELECT, volume: 0.14, speed: 1.16, variance: 0.008, cooldown: 0.07, stopAfter: 0.14 },
	playerlistAction: { asset: UI_CONFIRM, volume: 0.22, speed: 1.2, variance: 0.008, cooldown: 0.14, stopAfter: 0.48 },
	playerlistClose: { asset: SFX_RAMP, volume: 0.17, speed: 0.82, variance: 0, cooldown: 0.18, stopAfter: 0.36 },
	boostOpen: { asset: SFX_MOTOR, volume: 0.2, speed: 1.12, variance: 0.008, cooldown: 0.2, stopAfter: 0.48 },
	boostReady: { asset: UI_CONFIRM, volume: 0.21, speed: 1.18, variance: 0.004, cooldown: 0.32, stopAfter: 0.56 },
	noticeInfo: { asset: UI_NOTIFY, volume: 0.34, speed: 1.04, variance: 0, cooldown: 0.14, stopAfter: 0.55 },
	noticeSuccess: { asset: UI_SUCCESS_SOFT, volume: 0.36, speed: 1.08, variance: 0, cooldown: 0.14, stopAfter: 0.6 },
	noticeWarning: { asset: UI_WARN, volume: 0.36, speed: 1.02, variance: 0, cooldown: 0.16, stopAfter: 0.58 },
	noticeError: { asset: UI_ALERT, volume: 0.38, speed: 0.96, variance: 0, cooldown: 0.16, stopAfter: 0.58 },
	noticeSpecial: { asset: UI_POP, volume: 0.38, speed: 1.06, variance: 0, cooldown: 0.14, stopAfter: 0.62 },
	echoCapture: { asset: SFX_TRAVEL, volume: 0.38, speed: 0.88, variance: 0.006, cooldown: 0.28, stopAfter: 1.1 },
	echoClaim: { asset: UI_CONFIRM, volume: 0.36, speed: 1.02, variance: 0.004, cooldown: 0.2, stopAfter: 0.78 },
	echoEquip: { asset: SFX_WHOOSH, volume: 0.3, speed: 1.12, variance: 0.008, cooldown: 0.12, stopAfter: 0.42 },
	echoTune: { asset: SFX_PULSE, volume: 0.32, speed: 1.16, variance: 0.01, cooldown: 0.12, stopAfter: 0.52 },
	echoDismantle: { asset: UI_DOWN, volume: 0.3, speed: 0.78, variance: 0.008, cooldown: 0.18, stopAfter: 0.52 },
	navHover: { asset: UI_HOVER, volume: 0.17, speed: 1.4, variance: 0.012, cooldown: 0.06, stopAfter: 0.08 },
	dropdownOpen: { asset: UI_CLICK, volume: 0.22, speed: 1.22, variance: 0.008, cooldown: 0.05, stopAfter: 0.12 },
	dropdownClose: { asset: UI_CLICK, volume: 0.2, speed: 1.0, variance: 0.008, cooldown: 0.05, stopAfter: 0.1 },
	copyDone: { asset: UI_SELECT, volume: 0.24, speed: 1.3, variance: 0.008, cooldown: 0.12, stopAfter: 0.16 },
	dragGrab: { asset: UI_CLICK, volume: 0.22, speed: 0.9, variance: 0.008, cooldown: 0.06, stopAfter: 0.1 },
	dragDrop: { asset: UI_CLICK, volume: 0.26, speed: 0.8, variance: 0.008, cooldown: 0.06, stopAfter: 0.14 },
	dragSnap: { asset: UI_HOVER, volume: 0.2, speed: 1.5, variance: 0.008, cooldown: 0.04, stopAfter: 0.06 },
	favoriteOn: { asset: UI_SELECT, volume: 0.28, speed: 1.2, variance: 0.008, cooldown: 0.12, stopAfter: 0.26 },
	favoriteOff: { asset: UI_CLICK, volume: 0.2, speed: 0.9, variance: 0.008, cooldown: 0.1, stopAfter: 0.12 },
	ratingStar: { asset: UI_SELECT, volume: 0.22, speed: 1.1, variance: 0.008, cooldown: 0.05, stopAfter: 0.12 },
	reportSubmit: { asset: UI_SELECT, volume: 0.32, speed: 0.92, variance: 0.008, cooldown: 0.4, stopAfter: 0.4 },
	feedbackSubmit: { asset: UI_SELECT, volume: 0.32, speed: 1.1, variance: 0.008, cooldown: 0.4, stopAfter: 0.4 },
	searchType: { asset: UI_HOVER, volume: 0.12, speed: 1.6, variance: 0.008, cooldown: 0.03, stopAfter: 0.04 },
	countTick: { asset: UI_HOVER, volume: 0.12, speed: 1.8, variance: 0.008, cooldown: 0.03, stopAfter: 0.03 },
	badgeEarn: { asset: SFX_BLOOM, volume: 0.34, speed: 1.2, variance: 0.008, cooldown: 0.3, stopAfter: 0.5 },
	stepNext: { asset: UI_CLICK, volume: 0.24, speed: 1.12, variance: 0.008, cooldown: 0.08, stopAfter: 0.14 },
	stepBack: { asset: UI_CLICK, volume: 0.22, speed: 0.94, variance: 0.008, cooldown: 0.08, stopAfter: 0.14 },
	guildAnnounce: { asset: SFX_BLOOM, volume: 0.34, speed: 1.0, variance: 0.008, cooldown: 0.6, stopAfter: 0.7 },
	artifactEquip: { asset: UI_SELECT, volume: 0.3, speed: 0.9, variance: 0.008, cooldown: 0.15, stopAfter: 0.3 },
	artifactUpgrade: { asset: SFX_BLOOM, volume: 0.38, speed: 1.1, variance: 0.008, cooldown: 0.25, stopAfter: 0.55 },
	crateSeal: { asset: SFX_SHIFT, volume: 0.4, speed: 0.9, variance: 0.008, cooldown: 0.2, stopAfter: 0.4 },
	crateOrbit: { asset: SFX_WHOOSH_SOFT, volume: 0.34, speed: 0.9, variance: 0.008, cooldown: 0.4, stopAfter: 0.62 },
	crateRarityStep: { asset: UI_SELECT, volume: 0.3, speed: 1.25, variance: 0.008, cooldown: 0.06, stopAfter: 0.16 },
	crateRevealEpic: { asset: SFX_BLOOM, volume: 0.44, speed: 1.0, variance: 0.008, cooldown: 0.3, stopAfter: 0.7 },
	crateRevealMythic: { asset: SFX_BLOOM, volume: 0.5, speed: 0.86, variance: 0.008, cooldown: 0.4, stopAfter: 1.0 },
	rebirthIgnite: { asset: SFX_WHOOSH_SOFT, volume: 0.42, speed: 0.7, variance: 0.008, cooldown: 0.5, stopAfter: 1.1 },
	rebirthShockwave: { asset: SFX_SHIFT, volume: 0.48, speed: 0.7, variance: 0.008, cooldown: 0.4, stopAfter: 0.8 },
	rebirthTierUp: { asset: SFX_BLOOM, volume: 0.4, speed: 1.2, variance: 0.008, cooldown: 0.12, stopAfter: 0.4 },
	rebirthAscend: { asset: SFX_BLOOM, volume: 0.5, speed: 0.8, variance: 0.008, cooldown: 0.6, stopAfter: 1.25 },
	foundryOpen: { asset: UI_CONFIRM, volume: 0.42, speed: 1, variance: 0.006, cooldown: 0.2, stopAfter: 0.9 },
	foundryPlace: { asset: UI_CONFIRM, volume: 0.42, speed: 1, variance: 0.006, cooldown: 0.05, stopAfter: 0.4 },
	foundryPickUp: { asset: UI_SELECT, volume: 0.24, speed: 1.08, variance: 0.006, cooldown: 0.05, stopAfter: 0.25 },
	foundryRotate: { asset: UI_TICK, volume: 0.18, speed: 1.3, variance: 0.006, cooldown: 0.04, stopAfter: 0.2 },
	foundryFuse: { asset: SFX_BLOOM, volume: 0.42, speed: 1.0, variance: 0.006, cooldown: 0.12, stopAfter: 1.4 },
	foundryDraw: { asset: UI_SLIDE, volume: 0.3, speed: 1.04, variance: 0.006, cooldown: 0.1, stopAfter: 0.9 },
	foundryDrawRare: { asset: SFX_GLINT, volume: 0.42, speed: 1.0, variance: 0.006, cooldown: 0.15, stopAfter: 1.6 },
	foundryExpand: { asset: SFX_GATE, volume: 0.42, speed: 0.9, variance: 0.006, cooldown: 0.3, stopAfter: 2.2 },
	foundryIgnite: { asset: SFX_PULSE, volume: 0.32, speed: 1.02, variance: 0.006, cooldown: 0.06, stopAfter: 0.6 },
	foundryIgniteMiss: { asset: SFX_FAIL, volume: 0.22, speed: 0.8, variance: 0.006, cooldown: 0.06, stopAfter: 0.4 },
	foundrySurge: { asset: SFX_WHOOSH, volume: 0.4, speed: 0.96, variance: 0.006, cooldown: 0.3, stopAfter: 2.0 },
	foundryFlow: { asset: UI_TICK, volume: 0.12, speed: 1.5, variance: 0.006, cooldown: 0.08, stopAfter: 0.2 },
};

const UI_CUES: Record<string, true | undefined> = {};
for (const cue of [
	"hover", "click", "tick", "confirm", "locked", "error", "page", "mail", "story",
	"open", "close", "settings", "scroll", "toggleOn", "toggleOff", "sliderStep",
	"sliderCommit", "inputFocus", "inputClear", "tabSwitch", "filterOpen", "filterPick",
	"amountChange", "modalOpen", "modalPop", "modalDismiss", "purchaseExit",
	"playerlistOpen", "playerlistSelect", "playerlistAction", "playerlistClose",
	"noticeInfo", "noticeSuccess", "noticeWarning", "noticeError", "noticeSpecial",
	"chatSend", "chatReceive", "hoverTick", "successChime",
	"errorBuzz", "purchase", "purchasePress", "reward",
	"collect", "travel", "researchUnlock", "claimPress",
	"navHover",
	"dropdownOpen", "dropdownClose", "copyDone", "dragGrab", "dragDrop", "dragSnap",
	"favoriteOn", "favoriteOff", "ratingStar", "reportSubmit", "feedbackSubmit", "searchType",
	"countTick", "badgeEarn", "stepNext", "stepBack", "guildAnnounce",
]) {
	UI_CUES[cue] = true;
}

// the page, hover and icon-press families (navOpenShop, claimPressHover, corePress...) are interface
// sounds too: they share the UI group, the UI mix and the UI overlap cap
function isUiCue(cue: unknown): boolean {
	if (!typeIs(cue, "string")) {
		return false;
	}
	return (
		UI_CUES[cue] === true ||
		string.sub(cue, 1, 3) === "nav" ||
		string.sub(cue, -5) === "Hover" ||
		string.sub(cue, -5) === "Press"
	);
}

const CUE_ALIAS: Record<string, string | undefined> = {
	crateReveal: "crateRevealEpic",
};

function isHoverCue(cue: string): boolean {
	return cue === "hover" || string.sub(cue, -5) === "Hover" || string.sub(cue, 1, 8) === "navHover";
}

const PRELOAD_BATCH_SIZE = 11;
const VOICE_CAP = 22;
const UI_OVERLAP_CAP = 2;
const TRIM_RELEASE_STEPS = 3;
const CUE_GAIN = 0.9;
const SHEET_CUE_VOLUME = 0.3;
// relative level of a UI cue inside the UI mix (1 = as authored on the sheet); pointer chatter sits
// a step below presses so a sweep across a menu never drowns what you click
const UI_TRIM: Record<string, number | undefined> = {
	hover: 0.75, hoverTick: 0.75, navHover: 0.75, sanctuaryHover: 0.75, tick: 0.85, scroll: 0.5,
	sliderStep: 0.8, amountChange: 0.9, inputFocus: 0.95, inputClear: 0.95, filterPick: 0.95,
	searchType: 0.7, countTick: 0.7, dragSnap: 0.85,
};
const UI_TRIM_DEFAULT = 1.15;
// Interface cues are short transients that sit under a full music bed, so the UI bus runs hot;
// without this a hover landed near 0.04 Sound volume and read as silence.
const UI_BUS_GAIN = 1.8;
const SFX_BUS_GAIN = 1.3;

function uiCurve(linear: number): number {
	return math.sqrt(math.clamp(linear, 0, 1));
}

// only the cues that can fire many times a second (or for other players' activity) stay silent
const SILENT_CUES: Record<string, true | undefined> = {
	scroll: true,
	chatReceive: true,
	velocitySlide: true,
};
const CHANNEL_CLAIM_SECONDS = 0.05;
const DUPLICATE_CUE_SECONDS = 0.035;
const BUTTON_PITCH_CUES: Record<string, true | undefined> = {
	click: true,
	hover: true,
	confirm: true,
};
const LAYER_SOURCES: Record<string, string | undefined> = {
	hover: UI_HOVER,
	click: UI_CLICK,
	confirm: UI_CONFIRM,
};
const BOOTSTRAP_ASSETS = AUDIO_ASSET_MANIFEST;

function residentChannelCount(asset: string): number {
	return asset === UI_CLICK || asset === UI_TICK || asset === UI_CONFIRM || asset === UI_HOVER || asset === UI_NOTIFY
		? 8
		: 4;
}

const NAVIGATION_CUE = "tabSwitch";
const MUSIC_DUCK_CUES: Record<string, number | undefined> = {
	reward: 0.38, unlock: 0.34, discovery: 0.36, prestige: 0.52,
	rebirthCharge: 0.45, rebirthBloom: 0.5, domainCharge: 0.48, domainImpact: 0.5, domainReward: 0.42,
	wheelLand: 0.4, crateLand: 0.36, crateRare: 0.42, crateClaim: 0.34,
	missionClaim: 0.32, achievementClaim: 0.4, dailyClaim: 0.34, seasonClaim: 0.4,
	tutorialFinish: 0.36, purchaseResult: 0.3, boostReady: 0.28, bootReady: 0.32,
	bootFinaleBang: 0.48, bootImpact: 0.4, comboMilestone: 0.34, echoCapture: 0.36, zoneUnlock: 0.38,
};

function labelContains(label: string, ...needles: string[]): boolean {
	const upper = string.upper(label);
	return needles.some((needle) => string.find(upper, needle, 1, true)[0] !== undefined);
}

function labelEquals(label: string, ...values: string[]): boolean {
	const upper = string.upper(label);
	return values.some((value) => upper === value);
}

export function buttonAudioCue(text: string, icon?: unknown): string {
	const label = text;
	// icons are unique per use (concept.use); the sound follows the concept
	let iconName: unknown = icon;
	if (typeIs(iconName, "string")) {
		const [matched] = iconName.match("^[^.]+");
		iconName = matched;
	}
	if (labelEquals(label, "FLUX", "REBIRTHS", "PLAYTIME", "DUST", "CORES", "DOMAIN", "WORLDS")) {
		return "leaderboardSwitch";
	}
	if (labelContains(label, "REVIEW CHANGE", "APPLY CHANGE")) {
		return "adminArm";
	}
	if (iconName === "Code" || labelContains(label, "REDEEM CODE")) {
		return "codeSubmit";
	}
	if (labelContains(label, "KICK", "REMOVE MEMBER")) {
		return "memberRemove";
	}
	if (labelContains(label, "PROMOTE", "DEMOTE", "CHANGE ROLE")) {
		return "roleChange";
	}
	if (labelContains(label, "PREVIEW")) {
		return "preview";
	}
	if (labelContains(label, "REPLAY", "RESET")) {
		return "reset";
	}
	if (labelContains(label, "SALVAGE", "DELETE", "ARCHIVE")) {
		return "dangerPress";
	}
	if (labelContains(label, "CANCEL", "CLOSE", "BACK", "HIDE", "EXIT", "LEAVE", "CLEAR", "DETACH")) {
		return "close";
	}
	if (labelContains(label, "REFRESH", "FIND CURRENT", "QUICK LAND")) {
		return "tick";
	}
	if (labelContains(label, "REBIRTH", "PRESTIGE")) {
		return "prestige";
	}
	if (labelContains(label, "DOMAIN GATE", "DOMAIN EXPANSION", "OPEN DOMAIN")) {
		return "domainCharge";
	}
	if (labelContains(label, "END TURN")) {
		return "cardEndTurn";
	}
	if (labelEquals(label, "TEMPER") || labelContains(label, "TEMPER  ·")) {
		return "cardPower";
	}
	if (labelEquals(label, "SPARK") || labelContains(label, "SPARK  ·")) {
		return "cardEnergy";
	}
	if (labelContains(label, "CLAIM", "COLLECT", "REWARD", "GIFT")) {
		return "claimPress";
	}
	if (labelContains(label, "+ CASH", "+ DUST", "CONTRIBUTE", "DEPOSIT")) {
		return "vaultBank";
	}
	if (labelContains(label, "CHARTER")) {
		return "guildCreate";
	}
	if (labelContains(label, "JOIN GUILD")) {
		return "guildJoin";
	}
	if (labelContains(label, "BUY", "PURCHASE", "UPGRADE")) {
		return "purchasePress";
	}
	if (labelContains(label, "EQUIP", "WEAR", "SOCKET")) {
		return "equip";
	}
	if (labelContains(label, "INVITE")) {
		return "invite";
	}
	if (labelContains(label, "VISIT", "TRAVEL", "LAUNCH")) {
		return "travel";
	}
	if (labelContains(label, "RESUME")) {
		return "gameResume";
	}
	if (labelContains(label, "PAUSE")) {
		return "gamePause";
	}
	if (labelContains(label, "STOP")) {
		return "queueStop";
	}
	if (labelContains(label, "START", "PLAY", "SPIN")) {
		return "queueStart";
	}
	if (labelContains(label, "OPEN", "VIEW", "GUIDE", "UPDATES", "PATCH NOTES", "REPLAY")) {
		return "open";
	}
	if (iconName === "Close" || iconName === "Back" || iconName === "Hide") {
		return "close";
	}
	if (iconName === "Menu" || iconName === "Chevron") {
		return "open";
	}
	if (iconName === "Refresh" || iconName === "Search") {
		return "tick";
	}
	if (iconName === "Collect" || iconName === "Gift" || iconName === "Calendar" || iconName === "Rewards") {
		return "claimPress";
	}
	if (iconName === "Flux" || iconName === "Dust" || iconName === "StarGrid" || iconName === "Research" || iconName === "Shop") {
		return "purchasePress";
	}
	if (iconName === "Settings") {
		return "settings";
	}
	if (iconName === "Send") {
		return "chatSend";
	}
	if (iconName === "Mail") {
		return "mail";
	}
	if (iconName === "Story" || iconName === "Guide") {
		return "story";
	}
	if (iconName === "World" || iconName === "Visit") {
		return "travel";
	}
	if (iconName === "Loadout" || iconName === "Artifact") {
		return "equip";
	}
	if (iconName === "Boost") {
		return "boost";
	}
	if (iconName === "Overcharge" || iconName === "Anomaly" || iconName === "Reactor") {
		return "reactorPulse";
	}
	if (iconName === "Lock") {
		return "locked";
	}
	if (iconName === "Check") {
		return "confirm";
	}
	if (iconName === "Play") {
		return "queueStart";
	}
	if (iconName === "Pause") {
		return "queueStop";
	}
	if (iconName === "Vault") {
		return "vaultBank";
	}
	if (iconName === "Timer") {
		return "boostOpen";
	}
	if (iconName === "Crate") {
		return "crateOpen";
	}
	if (iconName === "Wheel") {
		return "wheelStart";
	}
	if (iconName === "Jackpot") {
		return "reward";
	}
	if (iconName === "Rebirth") {
		return "rebirthCharge";
	}
	if (iconName === "Crew" || iconName === "Pilot") {
		return "invite";
	}
	if (iconName === "Inventory") {
		return "equip";
	}
	if (iconName === "Milestone" || iconName === "Mission") {
		return "missionClaim";
	}
	if (iconName === "Guild") {
		return "guildJoin";
	}
	if (iconName === "Leaderboard") {
		return "leaderboardSwitch";
	}
	if (iconName === "Forge") {
		return "forgePress";
	}
	if (iconName === "Core") {
		return "corePress";
	}
	if (iconName === "Wave") {
		return "wavePress";
	}
	if (iconName === "Lab") {
		return "labPress";
	}
	if (iconName === "Command") {
		return "commandPress";
	}
	if (iconName === "Admin") {
		return "adminPress";
	}
	if (iconName === "Credits") {
		return "creditsPress";
	}
	if (iconName === "Chat") {
		return "chatPress";
	}
	if (iconName === "Continuum") {
		return "continuumPress";
	}
	if (iconName === "Mission") {
		return "missionPress";
	}
	if (iconName === "Overview") {
		return "overviewPress";
	}
	if (iconName === "Domain") {
		return "domainCharge";
	}
	return "click";
}

export function hoverCueFor(pressCue: unknown): string {
	if (!typeIs(pressCue, "string") || pressCue === "" || pressCue === "hover" || pressCue === "click") {
		return "hover";
	}
	if (string.sub(pressCue, 1, 8) === "navHover" || string.sub(pressCue, -5) === "Hover") {
		return pressCue;
	}
	const paired = `${pressCue}Hover`;
	const [start] = SoundSheet.region(paired);
	if (start !== undefined) {
		return paired;
	}
	return "hover";
}

function softMaster(linear: number): number {
	const t = math.clamp(linear, 0, 1);
	return t * t * (3 - 2 * t);
}

function softSfx(linear: number): number {
	const t = math.clamp(linear, 0, 1);
	return math.clamp(t * 1.05 + t * t * 0.12, 0, 1.15);
}

function paintCue(channel: Sound, cue: string, authored?: boolean) {
	const voice = Voicing.voiceFor(cue);

	let color = channel.FindFirstChild("CueColor") as EqualizerSoundEffect | undefined;
	if (color === undefined) {
		color = new Instance("EqualizerSoundEffect");
		color.Name = "CueColor";
		color.Parent = channel;
	}
	// Authored sheet regions already have their own timbre and space.
	color.HighGain = authored === true ? 0 : Voicing.clampGain(voice.high);
	color.MidGain = authored === true ? 0 : Voicing.clampGain(voice.mid);
	color.LowGain = authored === true ? 0 : Voicing.clampGain(voice.low);

	let space = channel.FindFirstChild("CueSpace") as ReverbSoundEffect | undefined;
	if (authored !== true && voice.reverbWet > 0.001) {
		if (space === undefined) {
			space = new Instance("ReverbSoundEffect");
			space.Name = "CueSpace";
			space.Parent = channel;
		}
		space.Enabled = true;
		space.DecayTime = math.clamp(voice.reverbDecay, 0.1, 20);
		space.WetLevel = math.clamp(-30 + voice.reverbWet * 36, -80, 10);
		space.DryLevel = 0;
	} else if (space !== undefined) {
		space.Enabled = false;
	}

	let grit = channel.FindFirstChild("CueDrive") as DistortionSoundEffect | undefined;
	if (authored !== true && voice.drive > 0.001) {
		if (grit === undefined) {
			grit = new Instance("DistortionSoundEffect");
			grit.Name = "CueDrive";
			grit.Parent = channel;
		}
		grit.Enabled = true;
		grit.Level = math.clamp(voice.drive, 0, 1);
	} else if (grit !== undefined) {
		grit.Enabled = false;
	}
}
interface ReleaseJob {
	channel: Sound;
	cue?: string;
	spec?: CueSpec;
	generation?: number;
	token?: number;
	speed?: number;
	started?: number;
	fadeStep?: number;
	releaseAt?: number;
	fullVolume?: number;
	phase?: string;
}

interface CelebrationItem {
	cue: string;
	at: number;
	pitch: number;
	token: number;
}

interface AudioSettings {
	UiVolume?: number;
	GameplayVolume?: number;
	RewardVolume?: number;
	AmbientVolume?: number;
	HoverSounds?: number;
	NotificationSounds?: number;
	PageMusic?: number;
	SoundVariation?: number;
	[key: string]: unknown;
}

export class Mixer {
	assetPools = new Map<string, Sound[]>();
	lastPlayed = new Map<string, number>();
	channelGeneration = new Map<Sound, number>();
	channelCue = new Map<Sound, string>();
	busyUntil = new Map<Sound, number>();
	claimedUntil = new Map<Sound, number>();
	channelLayerGain = new Map<Sound, number>();
	channelCursor = new Map<string, number>();
	releaseWorkers = new Set<thread>();
	masterLinear = 0.75;
	musicMix = 1;
	musicDuck = 1;
	duckToken = 0;
	sfxMix = 1;
	uiMix = 0.9;
	gameplayMix = 1;
	rewardMix = 1;
	ambientMix = 0.75;
	hoverSounds = true;
	notificationSounds = true;
	musicEnabled = true;
	soundVariation = 0.7;
	ready = false;
	warm = false;
	disposed = false;
	warmWaiters: (() => void)[] = [];
	intentSerial = 0;
	scene = "default";
	currentView = "Overview";
	sfxToken = 0;
	lifecycleToken = 0;
	releases: ReleaseJob[] = [];
	releaseByChannel = new Map<Sound, ReleaseJob>();
	releasePump?: thread;
	sheetPool?: Sound[];
	primarySheetPool?: Sound[];
	previousSheetPool?: Sound[];
	sheetReady = false;
	preloadWorker?: thread;
	preloadTimeout?: thread;
	masterGroup?: SoundGroup;
	group?: SoundGroup;
	uiGroup?: SoundGroup;
	ambientGroup?: SoundGroup;
	musicGroup?: SoundGroup;
	musicDirector?: MusicDirector;
	ambienceBed?: Sound;
	duckTokenLive?: number;
	duckClamped?: number;
	duckReleasing = false;
	duckReleaseAt?: number;
	duckSteps?: number;
	duckStep = 0;
	duckNext?: number;
	celebrationQueue?: CelebrationItem[];
	celebrationToken?: number;

	cueMix(cue: string): number {
		if (isHoverCue(cue) && !this.hoverSounds) {
			return 0;
		}
		if (
			(cue === "notification" ||
				cue === "systemAlert" ||
				cue === "chatReceive" ||
				cue === "crewNudge" ||
				cue === "noticeInfo" ||
				cue === "noticeSuccess" ||
				cue === "noticeWarning" ||
				cue === "noticeError" ||
				cue === "noticeSpecial" ||
				cue === "noticeClose") &&
			!this.notificationSounds
		) {
			return 0;
		}
		if (
			cue === "reward" ||
			cue === "unlock" ||
			cue === "discovery" ||
			cue === "prestige" ||
			cue === "rebirthCharge" ||
			cue === "rebirthBloom" ||
			cue === "domainCharge" ||
			cue === "domainCrack" ||
			cue === "domainImpact" ||
			cue === "domainReward" ||
			cue === "wheelLand" ||
			cue === "crateLand" ||
			cue === "crateRare" ||
			cue === "crateClaim" ||
			cue === "missionClaim" ||
			cue === "achievementClaim" ||
			cue === "dailyClaim" ||
			cue === "timedClaim" ||
			cue === "seasonClaim" ||
			cue === "mailClaim" ||
			cue === "codeReward" ||
			cue === "tutorialFinish" ||
			cue === "purchaseResult" ||
			cue === "boostReady"
		) {
			return this.rewardMix;
		}
		if (
			cue === "hover" ||
			cue === "click" ||
			cue === "tick" ||
			cue === "confirm" ||
			cue === "locked" ||
			cue === "error" ||
			cue === "page" ||
			cue === "open" ||
			cue === "close" ||
			cue === "settings" ||
			cue === "scroll" ||
			cue === "toggleOn" ||
			cue === "toggleOff" ||
			cue === "sliderStep" ||
			cue === "sliderCommit" ||
			cue === "inputFocus" ||
			cue === "inputClear" ||
			cue === "tabSwitch" ||
			cue === "filterOpen" ||
			cue === "filterPick" ||
			cue === "amountChange" ||
			cue === "modalOpen" ||
			cue === "modalPop" ||
			cue === "modalDismiss" ||
			cue === "purchaseExit" ||
			cue === "playerlistOpen" ||
			cue === "playerlistSelect" ||
			cue === "playerlistAction" ||
			cue === "playerlistClose" ||
			cue === "noticeInfo" ||
			cue === "noticeSuccess" ||
			cue === "noticeWarning" ||
			cue === "noticeError" ||
			cue === "noticeSpecial" ||
			cue === "noticeClose" ||
			cue === "tutorialStep" ||
			cue === "hoverTick" ||
			cue === "velocitySlide" ||
			cue === "purchase" ||
			cue === "purchasePress" ||
			cue === "claimPress" ||
			cue === "researchUnlock" ||
			cue === "travel" ||
			cue === "collect"
		) {
			return uiCurve(this.uiMix) * (UI_TRIM[cue] ?? UI_TRIM_DEFAULT);
		}
		if (isUiCue(cue)) {
			return uiCurve(this.uiMix) * (isHoverCue(cue) ? UI_TRIM.hover ?? UI_TRIM_DEFAULT : UI_TRIM_DEFAULT);
		}
		return this.gameplayMix;
	}

	makeChannel(asset: string, index: number, group: SoundGroup): Sound {
		const sound = new Instance("Sound");
		sound.Name = `Sfx_${index}`;
		sound.SoundId = asset;
		sound.Volume = 0;
		sound.PlaybackSpeed = 1;
		sound.Looped = false;
		sound.SoundGroup = group;
		sound.Parent = SoundService;
		return sound;
	}

	preloadChannels(): { channels: Sound[]; priorityCount: number } {
		const channels: Sound[] = [];
		const appended = new Set<Sound>();
		const appendChannel = (channel: Sound | undefined) => {
			if (channel === undefined || appended.has(channel)) {
				return;
			}
			appended.add(channel);
			channels.push(channel);
		};
		for (const asset of BOOTSTRAP_ASSETS) {
			appendChannel(this.assetPools.get(asset)?.[0]);
		}
		if (this.sheetPool !== undefined) {
			appendChannel(this.sheetPool[0]);
		}
		const priorityCount = channels.size();
		for (const asset of AUDIO_ASSET_MANIFEST) {
			for (const channel of this.assetPools.get(asset) ?? []) {
				appendChannel(channel);
			}
		}
		return { channels, priorityCount };
	}

	preloadSoundBank(channels: Sound[], priorityCount: number, lifecycle: number) {
		this.preloadWorker = task.spawn(() => {
			if (lifecycle !== this.lifecycleToken) {
				return;
			}
			let failedBatches = 0;
			let priorityPublished = priorityCount === 0;
			if (priorityPublished) {
				this.markWarmFor(lifecycle);
			}
			for (let offset = 0; offset < channels.size(); offset += PRELOAD_BATCH_SIZE) {
				if (lifecycle !== this.lifecycleToken) {
					return;
				}
				const batch: Sound[] = [];
				for (let index = offset; index < math.min(channels.size(), offset + PRELOAD_BATCH_SIZE); index++) {
					const channel = channels[index];
					if (channel !== undefined) {
						batch.push(channel);
					}
				}
				const [ok] = pcall(() => ContentProvider.PreloadAsync(batch));
				if (lifecycle !== this.lifecycleToken) {
					return;
				}
				if (!ok) {
					failedBatches += 1;
				}
				// the loading screen counts the bank in
				pcall(() => {
					const done = math.min(channels.size(), offset + batch.size());
					const AstralForge = script.Parent!.Parent!;
					(require(AstralForge.WaitForChild("BootKit") as ModuleScript) as (member: string) => {
						part(label: string, scope: string, done: number, total: number, message: string): void;
					})("BootLedger").part(
						"sound",
						"bank",
						done,
						channels.size(),
						`Sound effects ${done} of ${channels.size()}`,
					);
				});
				if (!priorityPublished && offset + PRELOAD_BATCH_SIZE >= priorityCount) {
					priorityPublished = true;
					this.markWarmFor(lifecycle);
				}
				task.wait();
			}
			this.markWarmFor(lifecycle);
			this.preloadWorker = undefined;
			if (this.preloadTimeout !== undefined) {
				pcall(() => task.cancel(this.preloadTimeout!));
				this.preloadTimeout = undefined;
			}
			if (failedBatches > 0) {
				ClientLog.warnEvery("audio-preload", 30, "Audio", `${failedBatches} sound batches will stream on first use`);
			} else {
				ClientLog.once("audio-bank-ready", "audio", `${channels.size()} sounds cached`);
			}
		});
		this.preloadTimeout = task.delay(8, () => {
			this.preloadTimeout = undefined;
			this.markWarmFor(lifecycle);
		});
	}

	start() {
		if (this.ready) {
			return;
		}
		for (const child of SoundService.GetChildren()) {
			if (
				child.IsA("Sound") &&
				(MUSIC_DECK_NAMES.includes(child.Name) ||
					child.Name === "ViewMusicA" ||
					child.Name === "ViewMusicB" ||
					string.sub(child.Name, 1, 4) === "Sfx_")
			) {
				child.Destroy();
			}
		}
		this.disposed = false;
		this.ready = true;
		this.lifecycleToken += 1;
		const lifecycle = this.lifecycleToken;
		let masterGroup = SoundService.FindFirstChild("ForgeMaster") as SoundGroup | undefined;
		if (masterGroup === undefined) {
			masterGroup = new Instance("SoundGroup");
			masterGroup.Name = "ForgeMaster";
			masterGroup.Volume = softMaster(this.masterLinear);
			masterGroup.Parent = SoundService;
		}
		this.masterGroup = masterGroup;
		masterGroup.Volume = softMaster(this.masterLinear);

		let group = masterGroup.FindFirstChild("ForgeSfx") as SoundGroup | undefined;
		if (group === undefined) {
			group = new Instance("SoundGroup");
			group.Name = "ForgeSfx";
			group.Volume = SFX_BUS_GAIN;
			group.Parent = masterGroup;
		}
		this.group = group;
		group.Volume = SFX_BUS_GAIN;

		let uiGroup = masterGroup.FindFirstChild("ForgeUI") as SoundGroup | undefined;
		if (uiGroup === undefined) {
			uiGroup = new Instance("SoundGroup");
			uiGroup.Name = "ForgeUI";
			uiGroup.Parent = masterGroup;
		}
		this.uiGroup = uiGroup;
		uiGroup.Volume = UI_BUS_GAIN;

		let ambientGroup = masterGroup.FindFirstChild("ForgeAmbient") as SoundGroup | undefined;
		if (ambientGroup === undefined) {
			ambientGroup = new Instance("SoundGroup");
			ambientGroup.Name = "ForgeAmbient";
			ambientGroup.Volume = 0.5;
			ambientGroup.Parent = masterGroup;
		}
		this.ambientGroup = ambientGroup;
		ambientGroup.Volume = this.ambientMix;

		let equalizer = group.FindFirstChild("ForgeCurve") as EqualizerSoundEffect | undefined;
		if (equalizer === undefined) {
			equalizer = new Instance("EqualizerSoundEffect");
			equalizer.Name = "ForgeCurve";
			equalizer.LowGain = 0.3;
			equalizer.MidGain = 1.05;
			equalizer.HighGain = 1.35;
			equalizer.Parent = group;
		}

		let compressor = group.FindFirstChild("ForgeGlue") as CompressorSoundEffect | undefined;
		if (compressor === undefined) {
			compressor = new Instance("CompressorSoundEffect");
			compressor.Name = "ForgeGlue";
			compressor.Attack = 0.003;
			compressor.Release = 0.05;
			compressor.Ratio = 1.15;
			compressor.Threshold = -28;
			compressor.GainMakeup = 1.8;
			compressor.Parent = group;
		}

		let musicGroup = masterGroup.FindFirstChild("ForgeMusic") as SoundGroup | undefined;
		if (musicGroup === undefined) {
			musicGroup = new Instance("SoundGroup");
			musicGroup.Name = "ForgeMusic";
			musicGroup.Volume = 1;
			musicGroup.Parent = masterGroup;
		}
		this.musicGroup = musicGroup;
		musicGroup.Volume = 1;

		let musicEq = musicGroup.FindFirstChild("ForgeBed") as EqualizerSoundEffect | undefined;
		if (musicEq === undefined) {
			musicEq = new Instance("EqualizerSoundEffect");
			musicEq.Name = "ForgeBed";
			musicEq.Parent = musicGroup;
		}
		musicEq.LowGain = 0.8;
		musicEq.MidGain = -0.5;
		musicEq.HighGain = -1.8;
		for (const asset of AUDIO_ASSET_MANIFEST) {
			const pool: Sound[] = [];
			for (let index = 1; index <= residentChannelCount(asset); index++) {
				pool.push(this.makeChannel(asset, index, group));
			}
			this.assetPools.set(asset, pool);
		}
		if (SoundSheet.enabled()) {
			const sheetChannels = (sheetAsset: string, base: number): Sound[] => {
				const sheetPool: Sound[] = [];
				for (let index = 1; index <= SHEET_CHANNELS; index++) {
					const channel = this.makeChannel(sheetAsset, base + index, group);
					channel.PlaybackRegionsEnabled = true;
					sheetPool.push(channel);
				}
				this.assetPools.set(sheetAsset, sheetPool);
				return sheetPool;
			};
			const primaryAsset = SoundSheet.primaryAsset();
			const previousAsset = SoundSheet.previousAsset();
			this.primarySheetPool = primaryAsset !== undefined ? sheetChannels(primaryAsset, 100) : undefined;
			this.previousSheetPool = previousAsset !== undefined ? sheetChannels(previousAsset, 200) : undefined;
			this.sheetPool = this.primarySheetPool ?? this.previousSheetPool;
		}
		const musicDirector = new MusicDirector(musicGroup);
		this.musicDirector = musicDirector;
		this.syncMusicState();
		musicDirector.start();
		this.startAmbienceBed(ambientGroup);
		const preload = this.preloadChannels();
		ClientLog.debug("audio", `${preload.channels.size()} sounds ready`);
		this.preloadSoundBank(preload.channels, preload.priorityCount, lifecycle);
	}

	// The quiet forge bed under the music, driven by the Ambience slider (ForgeAmbient group). It
	// played per sanctuary region until the sanctuary was removed; the uploaded beds were left unused.
	startAmbienceBed(ambientGroup: SoundGroup) {
		const ambience = AssetManifest.Ambience;
		const region = ambience !== undefined && ambience.Id > 0 ? ambience.Regions[AMBIENCE_BED] : undefined;
		if (region === undefined) {
			return;
		}
		let bed = this.ambienceBed;
		if (bed === undefined || bed.Parent === undefined) {
			bed = new Instance("Sound");
			bed.Name = "ForgeAmbienceBed";
			bed.SoundId = `rbxassetid://${ambience!.Id}`;
			bed.PlaybackRegionsEnabled = true;
			bed.PlaybackRegion = new NumberRange(region[0], region[0] + region[1]);
			bed.LoopRegion = new NumberRange(region[0], region[0] + region[1]);
			bed.Looped = true;
			const loudness = ambience!.Loudness?.[AMBIENCE_BED];
			bed.Volume =
				AMBIENCE_VOLUME *
				(loudness !== undefined ? math.clamp(10 ** ((-20 - loudness) / 20), 0.6, 1.4) : 1);
			bed.Parent = SoundService;
			this.ambienceBed = bed;
		}
		bed.SoundGroup = ambientGroup;
		if (!bed.IsPlaying) {
			bed.TimePosition = region[0];
			pcall(() => bed.Play());
		}
	}

	ensureStarted(): boolean {
		if (this.ready) {
			return true;
		}
		if (this.disposed) {
			return false;
		}
		this.start();
		return this.ready;
	}

	markWarmFor(lifecycle: number) {
		if (lifecycle !== this.lifecycleToken || !this.ready) {
			return;
		}
		this.markWarm();
	}

	markWarm() {
		if (this.warm) {
			return;
		}
		this.warm = true;
		const waiters = [...this.warmWaiters];
		this.warmWaiters.clear();
		for (const waiter of waiters) {
			waiter();
		}
	}

	whenWarm(callback: () => void) {
		if (this.disposed) {
			return;
		}
		if (this.warm) {
			callback();
			return;
		}
		this.warmWaiters.push(callback);
	}

	isWarm(): boolean {
		return this.warm;
	}

	setVolume(value: number) {
		this.masterLinear = math.clamp(value, 0, 1);
		const master = softMaster(this.masterLinear);
		if (this.masterGroup !== undefined) {
			this.masterGroup.Volume = master;
		}
		this.syncMusicState();
	}

	setMusicVolume(value: number) {
		this.musicMix = math.clamp(value, 0, 1);
		if (!this.ready) {
			return;
		}
		this.syncMusicState();
	}

	syncMusicState() {
		const director = this.musicDirector;
		if (director === undefined) {
			return;
		}
		const mix = math.sqrt(math.clamp(this.musicMix, 0, 1));
		director.setMix(mix);
		director.setDuck(this.musicDuck);
		director.setAudible(this.musicEnabled && softMaster(this.masterLinear) > 0.001 && mix > 0.001);
	}

	duckMusic(depth?: number, holdSeconds?: number, releaseSeconds?: number) {
		const depthValue = depth ?? 0.36;
		const hold = holdSeconds ?? 0.28;
		const release = releaseSeconds ?? 0.55;
		if (!this.ready) {
			return;
		}
		const clamped = math.clamp(depthValue, 0, 0.4);
		if (clamped <= 0.01) {
			return;
		}
		this.duckToken += 1;
		const token = this.duckToken;
		this.duckTokenLive = token;
		this.duckClamped = clamped;
		this.musicDuck = 1 - clamped;
		this.syncMusicState();
		this.duckReleasing = false;
		this.duckReleaseAt = os.clock() + hold;
		this.duckSteps = math.clamp(math.floor(release / 0.04 + 0.5), 4, 24);
		this.duckStep = 0;
		this.duckNext = undefined;
		this.ensureReleasePump();
	}

	clearMusicDuck() {
		this.duckToken += 1;
		this.duckTokenLive = undefined;
		this.duckReleasing = false;
		this.musicDuck = 1;
		if (this.ready) {
			this.syncMusicState();
		}
	}

	setSfxVolume(value: number) {
		this.sfxMix = math.clamp(value, 0, 1);
		if (!this.ready) {
			return;
		}
		const sfx = softSfx(this.sfxMix);
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				const cue = this.channelCue.get(sound);
				if (cue !== undefined) {
					const spec = CUES[cue];
					const base = spec !== undefined ? spec.volume : SHEET_CUE_VOLUME;
					sound.Volume =
						base *
						CUE_GAIN *
						Voicing.voiceFor(cue).gain *
						(this.channelLayerGain.get(sound) ?? 1) *
						sfx *
						this.cueMix(cue);
				}
			}
		}
	}

	configurePreferences(settings: AudioSettings) {
		this.uiMix = math.clamp(settings.UiVolume ?? 0.9, 0, 1);
		this.gameplayMix = math.clamp(settings.GameplayVolume ?? 1, 0, 1);
		this.rewardMix = math.clamp(settings.RewardVolume ?? 1, 0, 1);
		this.ambientMix = math.clamp(settings.AmbientVolume ?? 0.75, 0, 1);
		if (this.ambientGroup !== undefined) {
			this.ambientGroup.Volume = this.ambientMix;
		}
		this.hoverSounds = (settings.HoverSounds ?? 1) >= 0.5;
		this.notificationSounds = (settings.NotificationSounds ?? 1) >= 0.5;
		this.musicEnabled = (settings.PageMusic ?? 1) >= 0.5;
		this.soundVariation = math.clamp(settings.SoundVariation ?? 0.7, 0, 1);
		if (this.ready) {
			this.setSfxVolume(this.sfxMix);
			this.syncMusicState();
		}
	}

	currentScene(): string {
		return this.scene;
	}

	setScene(scene: string) {
		if (this.scene === scene && this.ready) {
			return;
		}
		this.scene = scene;
		if (!this.ensureStarted()) {
			return;
		}
		if (scene === "boot" || scene === "shutdown") {
			this.duckMusic(0.22, 0.4, 0.8);
		} else if (this.musicDuck < 0.999) {
			this.clearMusicDuck();
		}
		this.syncMusicState();
	}

	setView(page: string, playCue?: boolean) {
		const shouldPlay = playCue ?? true;
		if (!this.ensureStarted()) {
			return;
		}
		const changed = this.currentView !== page;
		this.currentView = page;
		if (this.scene !== "boot" && this.scene !== "shutdown") {
			this.scene = "default";
			if (changed && shouldPlay) {
				this.play(NAVIGATION_CUE);
			}
		}
	}

	roundRobin(pool: Sound[], asset: string): Sound {
		let cursor = this.channelCursor.get(asset);
		if (cursor === undefined) {
			cursor = 0;
		}
		cursor = (cursor + 1) % pool.size();
		this.channelCursor.set(asset, cursor);
		return pool[cursor];
	}

	oldestInPool(pool: Sound[]): Sound | undefined {
		let oldest: Sound | undefined;
		let oldestProgress = -1;
		for (const sound of pool) {
			const claimedUntil = this.claimedUntil.get(sound);
			if (claimedUntil !== undefined && claimedUntil > os.clock()) {
				continue;
			}
			const progress = sound.TimePosition;
			if (oldest === undefined || progress > oldestProgress) {
				oldest = sound;
				oldestProgress = progress;
			}
		}
		return oldest;
	}

	countPlayingUi(): number {
		let count = 0;
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				if (sound.IsPlaying && isUiCue(this.channelCue.get(sound))) {
					count += 1;
				}
			}
		}
		return count;
	}

	silenceOldestUi(): Sound | undefined {
		let oldestSound: Sound | undefined;
		let oldestAge = -1;
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				if (sound.IsPlaying && isUiCue(this.channelCue.get(sound))) {
					const age = sound.TimePosition;
					if (oldestSound === undefined || age >= oldestAge) {
						oldestSound = sound;
						oldestAge = age;
					}
				}
			}
		}
		if (oldestSound === undefined) {
			return undefined;
		}
		const generation = this.channelGeneration.get(oldestSound) ?? 0;
		this.channelGeneration.set(oldestSound, generation + 1);
		this.busyUntil.set(oldestSound, 0);
		this.claimedUntil.set(oldestSound, 0);
		oldestSound.Stop();
		oldestSound.Volume = 0;
		const job = this.releaseByChannel.get(oldestSound);
		if (job !== undefined) {
			job.phase = "idle";
		}
		return oldestSound;
	}

	acquireChannel(spec: CueSpec, cue: string): Sound | undefined {
		const pool = this.assetPools.get(spec.asset);
		if (pool === undefined || pool.size() === 0) {
			return undefined;
		}
		const now = os.clock();
		const uiCue = isUiCue(cue);
		if (uiCue) {
			let guard = 0;
			while (this.countPlayingUi() >= UI_OVERLAP_CAP && guard < UI_OVERLAP_CAP * 2) {
				if (this.silenceOldestUi() === undefined) {
					break;
				}
				guard += 1;
			}
		}
		for (const sound of pool) {
			const busyUntil = this.busyUntil.get(sound) ?? 0;
			const claimedUntil = this.claimedUntil.get(sound) ?? 0;
			if (!sound.IsPlaying && busyUntil <= now && claimedUntil <= now) {
				return sound;
			}
		}
		const oldest = this.oldestInPool(pool);
		if (oldest !== undefined) {
			return oldest;
		}
		return this.roundRobin(pool, spec.asset);
	}

	releaseIsStale(job: ReleaseJob): boolean {
		if (this.disposed) {
			return true;
		}
		if (this.channelGeneration.get(job.channel) !== job.generation) {
			return true;
		}
		if (job.token !== this.sfxToken) {
			return true;
		}
		return false;
	}

	pumpDuck() {
		if (this.duckTokenLive === undefined || this.duckTokenLive !== this.duckToken) {
			return;
		}
		if (!this.duckReleasing) {
			if (this.duckReleaseAt !== undefined && os.clock() >= this.duckReleaseAt) {
				this.duckReleasing = true;
				this.duckStep = 0;
				this.duckNext = os.clock();
			}
			return;
		}
		if (this.duckNext !== undefined && os.clock() < this.duckNext) {
			return;
		}
		this.duckStep += 1;
		let steps = this.duckSteps;
		if (steps === undefined || steps < 1) {
			steps = 1;
		}
		if (this.duckStep >= steps) {
			this.musicDuck = 1;
			this.syncMusicState();
			this.duckTokenLive = undefined;
			this.duckReleasing = false;
			return;
		}
		const alpha = this.duckStep / steps;
		const clamped = this.duckClamped ?? 0;
		this.musicDuck = 1 - clamped + clamped * alpha;
		this.syncMusicState();
		this.duckNext = os.clock() + 0.04;
	}

	pumpCelebration() {
		const queue = this.celebrationQueue;
		if (queue === undefined) {
			return;
		}
		const now = os.clock();
		let index = 0;
		while (index < queue.size()) {
			const item = queue[index];
			if (item.token !== this.celebrationToken) {
				queue.remove(index);
			} else if (now >= item.at) {
				queue.remove(index);
				this.playChannel(item.cue, true, item.pitch);
			} else {
				index += 1;
			}
		}
	}

	pumpReleases() {
		this.pumpDuck();
		this.pumpCelebration();
		for (const job of this.releases) {
			const phase = job.phase;
			if (phase === undefined || phase === "idle") {
				continue;
			}
			if (this.releaseIsStale(job)) {
				job.phase = "idle";
				continue;
			}
			const channel = job.channel;
			const spec = job.spec;
			if (spec === undefined) {
				job.phase = "idle";
				continue;
			}
			const speed = math.max(0.05, job.speed ?? 1);
			if (phase === "length") {
				if (channel.TimeLength > 0) {
					const natural = channel.TimeLength / speed;
					const familyDecay = Voicing.voiceFor(job.cue ?? "").decay;
					const trimmed =
						spec.stopAfter !== undefined ? math.max(0.08, (spec.stopAfter * familyDecay) / speed) : undefined;
					const seconds = trimmed !== undefined ? math.min(trimmed, natural) : natural;
					this.busyUntil.set(channel, os.clock() + seconds);
					if (spec.stopAfter === undefined) {
						job.phase = "idle";
					} else {
						job.releaseAt = os.clock() + seconds;
						job.phase = "hold";
					}
				} else if (os.clock() - (job.started ?? 0) >= 2) {
					job.phase = "idle";
				}
			} else if (phase === "hold") {
				if (os.clock() >= (job.releaseAt ?? 0)) {
					if (!channel.IsPlaying) {
						job.phase = "idle";
					} else {
						job.fullVolume =
							spec.volume *
							CUE_GAIN *
							Voicing.voiceFor(job.cue ?? "").gain *
							(this.channelLayerGain.get(channel) ?? 1) *
							softSfx(this.sfxMix) *
							this.cueMix(job.cue ?? "");
						job.fadeStep = 0;
						job.phase = "fade";
					}
				}
			} else if (phase === "fade") {
				if (!channel.IsPlaying) {
					job.phase = "idle";
				} else {
					job.fadeStep = (job.fadeStep ?? 0) + 1;
					const step = job.fadeStep;
					channel.Volume = (job.fullVolume ?? 0) * (1 - step / TRIM_RELEASE_STEPS);
					if (step >= TRIM_RELEASE_STEPS) {
						channel.Stop();
						channel.Volume = 0;
						this.busyUntil.set(channel, 0);
						this.claimedUntil.set(channel, 0);
						job.phase = "idle";
					}
				}
			}
		}
	}

	ensureReleasePump() {
		if (this.releasePump !== undefined || this.disposed) {
			return;
		}
		const pump = task.spawn(() => {
			while (!this.disposed) {
				this.pumpReleases();
				task.wait();
			}
		});
		this.releasePump = pump;
		this.releaseWorkers.add(pump);
	}

	scheduleRelease(channel: Sound, cue: string, spec: CueSpec, generation: number, token: number, speed: number) {
		let job = this.releaseByChannel.get(channel);
		if (job === undefined) {
			job = { channel };
			this.releaseByChannel.set(channel, job);
			this.releases.push(job);
		}
		job.cue = cue;
		job.spec = spec;
		job.generation = generation;
		job.token = token;
		job.speed = speed;
		job.started = os.clock();
		job.fadeStep = 0;
		job.releaseAt = undefined;
		job.fullVolume = undefined;
		job.phase = "length";
		this.ensureReleasePump();
	}

	playChannel(cue: string, bypassCooldown?: boolean, speedMult?: number): boolean {
		const bypass = bypassCooldown ?? false;
		const mult = speedMult ?? 1;
		let cueName = cue;
		if (SILENT_CUES[cueName] === true) {
			return false;
		}
		// names that have no voice of their own borrow the closest one instead of playing nothing
		if (CUES[cueName] === undefined) {
			const [sheetStart] = SoundSheet.region(cueName);
			if (sheetStart === undefined) {
				const alias = CUE_ALIAS[cueName];
				if (alias !== undefined) {
					cueName = alias;
				} else if (string.sub(cueName, 1, 7) === "navOpen") {
					cueName = "open";
				}
			}
		}
		if (!this.ensureStarted()) {
			return false;
		}
		const token = this.sfxToken;
		const mix = this.cueMix(cueName);
		if (softMaster(this.masterLinear) <= 0.001 || this.sfxMix <= 0.001 || mix <= 0.001) {
			ClientLog.warnEvery(
				`audio-mix-${cueName}`,
				30,
				"Audio",
				`${cueName} muted — master=${softMaster(this.masterLinear)} sfx=${this.sfxMix} cueMix=${mix}`,
			);
			return false;
		}
		let spec = CUES[cueName];
		if (spec === undefined) {
			if (string.sub(cueName, 1, 8) === "navHover") {
				spec = CUES.navHover;
			} else if (string.sub(cueName, -5) === "Hover") {
				spec = CUES.hover;
			} else if (cueName === "button") {
				spec = CUES.click;
			}
		}
		if (spec === undefined) {
			const [start] = SoundSheet.region(cueName);
			if (start !== undefined) {
				spec = {
					asset: UI_CLICK,
					volume: SHEET_CUE_VOLUME,
					speed: 1,
					variance: 0.006,
					cooldown: 0.05,
					stopAfter: 0.6,
				};
			}
		}
		if (spec === undefined || spec.asset === "") {
			if (spec === undefined) {
				ClientLog.warnEvery(`audio-missing-${cueName}`, 30, "Audio", `unknown cue "${cueName}"`);
			}
			return false;
		}
		const now = os.clock();
		const previous = this.lastPlayed.get(cueName) ?? -math.huge;
		if (!bypass && isHoverCue(cueName) && now - previous < math.max(0.12, spec.cooldown)) {
			return false;
		}
		const recentClick = cueName === "hover" && now - (this.lastPlayed.get("click") ?? -math.huge) < 0.04;
		if (recentClick) {
			return false;
		}
		let liveVoices = 0;
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				if (sound.IsPlaying) {
					liveVoices += 1;
				}
			}
		}
		if (liveVoices >= VOICE_CAP && !bypass) {
			const decorative =
				cueName === "hover" ||
				cueName === "hoverTick" ||
				cueName === "scroll" ||
				cueName === "tick" ||
				cueName === "wheelTick" ||
				cueName === "crateTick" ||
				cueName === "sliderStep" ||
				cueName === "filterPick" ||
				cueName === "amountChange" ||
				cueName === "cardDraw" ||
				cueName === "bootClang" ||
				cueName === "bootTension" ||
				string.sub(cueName, 1, 8) === "navHover" ||
				string.sub(cueName, -5) === "Hover";
			if (decorative) {
				return false;
			}
		}
		if (!bypass && now - previous < DUPLICATE_CUE_SECONDS) {
			return false;
		}
		if (this.sheetPool !== undefined && this.sheetLoaded()) {
			const [start, length] = SoundSheet.region(cueName);
			if (start !== undefined && length !== undefined) {
				return this.playSheet(cueName, spec, start, length, mult, now, token);
			}
		}
		const channel = this.acquireChannel(spec, cueName);
		if (channel === undefined) {
			return false;
		}
		const generation = (this.channelGeneration.get(channel) ?? 0) + 1;
		this.channelGeneration.set(channel, generation);
		this.channelCue.set(channel, cueName);
		this.channelLayerGain.delete(channel);
		const voice = Voicing.voiceFor(cueName);
		const pitchSpread =
			BUTTON_PITCH_CUES[cueName] === true ? 1 + (math.random() * 2 - 1) * 0.01 * this.soundVariation : 1;
		const variance =
			spec.variance > 0 ? (math.random() * 2 - 1) * math.min(spec.variance, 0.015) * this.soundVariation : 0;
		const speed = math.clamp(
			spec.speed * voice.pitch * math.clamp(mult, 0.82, 1.28) * pitchSpread + variance,
			0.28,
			2.1,
		);
		const ambientCue =
			cueName === "reactor" ||
			cueName === "reactorReady" ||
			cueName === "reactorPulse" ||
			cueName === "reactorChannel" ||
			cueName === "reactorStabilize" ||
			cueName === "autoForge";
		channel.SoundGroup = isUiCue(cueName) ? this.uiGroup : ambientCue ? this.ambientGroup : this.group;
		channel.Volume = spec.volume * CUE_GAIN * voice.gain * softSfx(this.sfxMix) * mix;
		channel.PlaybackSpeed = speed;
		channel.Looped = false;
		paintCue(channel, cueName);
		if (token !== this.sfxToken || channel.Parent === undefined || this.channelGeneration.get(channel) !== generation) {
			return false;
		}
		if (channel.IsPlaying) {
			channel.Stop();
		}
		channel.TimePosition = 0;
		const [played] = pcall(() => channel.Play());
		if (!played) {
			this.busyUntil.set(channel, 0);
			this.claimedUntil.set(channel, 0);
			ClientLog.warnEvery(`audio-play-${cueName}`, 20, "Audio", `${cueName} could not start`);
			return false;
		}
		this.claimedUntil.set(channel, now + CHANNEL_CLAIM_SECONDS);
		this.lastPlayed.set(cueName, now);
		this.scheduleRelease(channel, cueName, spec, generation, token, speed);
		this.playLayer(cueName, token);
		const duckDepth = MUSIC_DUCK_CUES[cueName];
		if (duckDepth !== undefined) {
			this.duckMusic(duckDepth, math.max(0.18, (spec.stopAfter ?? 0.45) * 0.55), 0.62);
		}
		return true;
	}

	sheetLoaded(): boolean {
		if (this.sheetReady) {
			return true;
		}
		const loaded = (pool: Sound[] | undefined): boolean => {
			const probe = pool !== undefined ? pool[0] : undefined;
			return probe !== undefined && probe.IsLoaded && probe.TimeLength > 1;
		};
		if (loaded(this.primarySheetPool)) {
			this.sheetPool = this.primarySheetPool;
			SoundSheet.use(false);
			this.sheetReady = true;
			ClientLog.once("audio-sheet-ready", "audio", "sound sheet loaded");
			return true;
		}
		if (loaded(this.previousSheetPool)) {
			this.sheetPool = this.previousSheetPool;
			SoundSheet.use(true);
			ClientLog.once("audio-sheet-previous", "audio", "new sound sheet not available yet; playing the previous one");
			return true;
		}
		return false;
	}

	playSheet(
		cue: string,
		spec: CueSpec,
		start: number,
		length: number,
		speedMult: number,
		now: number,
		token: number,
	): boolean {
		const pool = this.sheetPool;
		if (pool === undefined) {
			return false;
		}
		let channel: Sound | undefined;
		let oldest = math.huge;
		for (const sound of pool) {
			const busy = math.max(this.busyUntil.get(sound) ?? 0, this.claimedUntil.get(sound) ?? 0);
			if (busy <= now && !sound.IsPlaying) {
				channel = sound;
				break;
			}
			if (busy < oldest) {
				oldest = busy;
				channel = sound;
			}
		}
		if (channel === undefined) {
			return false;
		}
		const generation = (this.channelGeneration.get(channel) ?? 0) + 1;
		this.channelGeneration.set(channel, generation);
		this.channelCue.set(channel, cue);
		const level = SoundSheet.gain(cue);
		this.channelLayerGain.set(channel, level);
		const variance =
			spec.variance > 0 ? (math.random() * 2 - 1) * math.min(spec.variance, 0.03) * this.soundVariation : 0;
		// the sheet's interface voices are tuned to one scale, so only a hair of spread keeps them in tune
		const spread = BUTTON_PITCH_CUES[cue] === true ? 1 + (math.random() * 2 - 1) * 0.01 * this.soundVariation : 1;
		const speed = math.clamp(math.clamp(speedMult, 0.82, 1.28) * spread + variance, 0.5, 2);
		const mix = this.cueMix(cue);
		const ambientCue =
			cue === "reactor" ||
			cue === "reactorReady" ||
			cue === "reactorPulse" ||
			cue === "reactorChannel" ||
			cue === "reactorStabilize" ||
			cue === "autoForge";
		channel.SoundGroup = isUiCue(cue) ? this.uiGroup : ambientCue ? this.ambientGroup : this.group;
		if (channel.IsPlaying) {
			channel.Stop();
		}
		channel.Looped = false;
		channel.PlaybackRegion = new NumberRange(start, start + length);
		channel.PlaybackSpeed = speed;
		channel.Volume = spec.volume * CUE_GAIN * Voicing.voiceFor(cue).gain * level * softSfx(this.sfxMix) * mix;
		paintCue(channel, cue, true);
		channel.TimePosition = start;
		if (token !== this.sfxToken || channel.Parent === undefined) {
			return false;
		}
		const [played] = pcall(() => channel.Play());
		if (!played) {
			ClientLog.warnEvery(`audio-sheet-${cue}`, 20, "Audio", `${cue} could not start from the sound sheet`);
			return false;
		}
		this.claimedUntil.set(channel, now + CHANNEL_CLAIM_SECONDS);
		this.busyUntil.set(channel, now + length / speed);
		this.lastPlayed.set(cue, now);
		ClientLog.once(
			"audio-first-sheet-cue",
			"audio",
			`first cue ${cue} volume=${string.format("%.3f", channel.Volume)} bus=${channel.SoundGroup?.Name ?? "none"} master=${string.format("%.2f", softMaster(this.masterLinear))} ui=${string.format("%.2f", this.uiMix)} sfx=${string.format("%.2f", this.sfxMix)}`,
		);
		const duckDepth = MUSIC_DUCK_CUES[cue];
		if (duckDepth !== undefined) {
			this.duckMusic(duckDepth, math.max(0.18, length * 0.45), 0.62);
		}
		return true;
	}

	playLayer(cue: string, token: number) {
		const layer = Voicing.layerFor(cue);
		if (layer === undefined) {
			return;
		}
		const asset = LAYER_SOURCES[layer.source];
		if (asset === undefined) {
			return;
		}
		const pool = this.assetPools.get(asset);
		if (pool === undefined || pool.size() === 0) {
			return;
		}
		task.delay(layer.delay, () => {
			if (this.disposed || token !== this.sfxToken) {
				return;
			}
			const now = os.clock();
			let channel: Sound | undefined;
			for (const sound of pool) {
				const claimedUntil = this.claimedUntil.get(sound) ?? 0;
				if (!sound.IsPlaying && claimedUntil <= now) {
					channel = sound;
					break;
				}
			}
			if (channel === undefined) {
				return;
			}
			const generation = (this.channelGeneration.get(channel) ?? 0) + 1;
			this.channelGeneration.set(channel, generation);
			this.channelCue.set(channel, cue);
			this.channelLayerGain.set(channel, layer.volume);
			const voice = Voicing.voiceFor(cue);
			channel.SoundGroup = isUiCue(cue) ? this.uiGroup : this.group;
			channel.Volume =
				(CUES[cue] !== undefined ? CUES[cue]!.volume : SHEET_CUE_VOLUME) *
				CUE_GAIN *
				voice.gain *
				layer.volume *
				softSfx(this.sfxMix) *
				this.cueMix(cue);
			channel.PlaybackSpeed = math.clamp(layer.pitch, 0.28, 2.1);
			channel.Looped = false;
			paintCue(channel, cue);
			channel.TimePosition = 0;
			const [ok] = pcall(() => channel!.Play());
			if (!ok) {
				return;
			}
			this.claimedUntil.set(channel, os.clock() + CHANNEL_CLAIM_SECONDS);
			this.scheduleRelease(
				channel,
				cue,
				(CUES[cue] ?? { stopAfter: 0.6 }) as CueSpec,
				generation,
				token,
				channel.PlaybackSpeed,
			);
		});
	}

	play(cue: string, speedMult?: number): boolean {
		const mult = speedMult ?? 1;
		if (!this.ensureStarted()) {
			return false;
		}
		const played = this.playChannel(cue, false, mult);
		if (!played) {
			return false;
		}
		this.intentSerial += 1;
		return true;
	}

	playCelebration(cues: string[], staggerSeconds?: number): boolean {
		const stagger = staggerSeconds ?? 0.07;
		if (!this.ensureStarted() || cues.size() === 0) {
			return false;
		}
		this.duckMusic(0.46, 0.2 + stagger * cues.size(), 0.7);
		this.celebrationToken = (this.celebrationToken ?? 0) + 1;
		const token = this.celebrationToken;
		this.celebrationQueue = [];
		const now = os.clock();
		let firedFirst = false;
		for (let i = 0; i < cues.size(); i++) {
			const cue = cues[i];
			const pitchLift = 1 + i * 0.045;
			if (i === 0) {
				firedFirst = this.playChannel(cue, true, pitchLift);
			} else {
				this.celebrationQueue.push({
					cue,
					at: now + stagger * i,
					pitch: pitchLift,
					token,
				});
			}
		}
		this.ensureReleasePump();
		if (!firedFirst) {
			return false;
		}
		this.intentSerial += 1;
		return true;
	}

	captureIntent(): number {
		return this.intentSerial;
	}

	playIfUnclaimed(marker: number, cue: string, speedMult?: number): boolean {
		const mult = speedMult ?? 1;
		if (marker !== this.intentSerial) {
			return false;
		}
		return this.play(cue, mult);
	}

	stopSfx() {
		this.sfxToken += 1;
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				this.channelGeneration.set(sound, (this.channelGeneration.get(sound) ?? 0) + 1);
				this.busyUntil.set(sound, 0);
				this.claimedUntil.set(sound, 0);
				if (sound.IsPlaying) {
					sound.Stop();
				}
				sound.Looped = false;
				sound.TimePosition = 0;
			}
		}
	}

	dispose() {
		this.disposed = true;
		if (!this.ready && this.group === undefined && this.musicDirector === undefined) {
			return;
		}
		this.lifecycleToken += 1;
		if (this.preloadWorker !== undefined) {
			pcall(() => task.cancel(this.preloadWorker!));
		}
		if (this.preloadTimeout !== undefined) {
			pcall(() => task.cancel(this.preloadTimeout!));
		}
		this.preloadWorker = undefined;
		this.preloadTimeout = undefined;
		for (const worker of this.releaseWorkers) {
			pcall(() => task.cancel(worker));
		}
		this.releaseWorkers.clear();
		this.releasePump = undefined;
		this.celebrationToken = (this.celebrationToken ?? 0) + 1;
		this.celebrationQueue = undefined;
		this.duckToken += 1;
		this.duckTokenLive = undefined;
		this.duckReleasing = false;
		this.releases.clear();
		this.releaseByChannel.clear();
		this.sfxToken += 1;
		for (const [, pool] of this.assetPools) {
			for (const sound of pool) {
				pcall(() => sound.Destroy());
			}
		}
		this.assetPools.clear();
		this.lastPlayed.clear();
		this.channelGeneration.clear();
		this.channelCue.clear();
		this.busyUntil.clear();
		this.claimedUntil.clear();
		this.channelLayerGain.clear();
		this.channelCursor.clear();
		this.musicDirector?.dispose();
		this.musicDirector = undefined;
		this.group?.Destroy();
		this.group = undefined;
		this.musicGroup?.Destroy();
		this.musicGroup = undefined;
		if (this.uiGroup !== undefined) {
			this.uiGroup.Destroy();
			this.uiGroup = undefined;
		}
		if (this.ambienceBed !== undefined) {
			this.ambienceBed.Destroy();
			this.ambienceBed = undefined;
		}
		if (this.ambientGroup !== undefined) {
			this.ambientGroup.Destroy();
			this.ambientGroup = undefined;
		}
		if (this.masterGroup !== undefined) {
			if (this.masterGroup.GetChildren().size() === 0) {
				this.masterGroup.Destroy();
			}
			this.masterGroup = undefined;
		}
		this.ready = false;
		this.warm = false;
		this.warmWaiters.clear();
		this.scene = "default";
		this.currentView = "Overview";
		this.musicDuck = 1;
		this.duckToken += 1;
	}
}

export const Audio = new Mixer();

const isActivationInput = (input: InputObject): boolean =>
	input.UserInputType === Enum.UserInputType.MouseButton1 ||
	input.UserInputType === Enum.UserInputType.Touch ||
	input.UserInputType === Enum.UserInputType.Gamepad1 ||
	input.KeyCode === Enum.KeyCode.Return ||
	input.KeyCode === Enum.KeyCode.Space;

export function hookGuiClicks(root: Instance): () => void {
	const tracked = new Map<Instance, RBXScriptConnection[]>();
	let disposed = false;
	let inputMarker = -1;
	let inputStartedAt = -math.huge;
	const globalInput = UserInputService.InputBegan.Connect((input) => {
		if (!isActivationInput(input)) {
			return;
		}
		inputMarker = Audio.captureIntent();
		inputStartedAt = os.clock();
	});
	const release = (instance: Instance) => {
		const connections = tracked.get(instance);
		if (connections === undefined) {
			return;
		}
		tracked.delete(instance);
		for (const connection of connections) {
			connection.Disconnect();
		}
	};
	const attachButton = (button: GuiButton) => {
		if (tracked.has(button)) {
			return;
		}
		let pressMarker = -1;
		let pressedAt = -math.huge;
		const connections: RBXScriptConnection[] = [];
		connections.push(
			button.InputBegan.Connect((input) => {
				if (!isActivationInput(input)) {
					return;
				}
				const now = os.clock();
				pressMarker = now - inputStartedAt <= 0.15 ? inputMarker : Audio.captureIntent();
				pressedAt = now;
			}),
		);
		connections.push(
			button.Activated.Connect(() => {
				if (!button.Active || !button.Selectable) {
					return;
				}
				if (os.clock() - pressedAt > 2 || pressMarker < 0) {
					return;
				}
				const marker = pressMarker;
				pressMarker = -1;
				Audio.playIfUnclaimed(marker, "click");
			}),
		);
		connections.push(
			button.MouseEnter.Connect(() => {
				if (!button.Active || !button.Selectable) {
					return;
				}
				const marker = Audio.captureIntent();
				Audio.playIfUnclaimed(marker, "hover");
			}),
		);
		connections.push(
			button.SelectionGained.Connect(() => {
				if (!button.Active || !button.Selectable) {
					return;
				}
				const marker = Audio.captureIntent();
				Audio.playIfUnclaimed(marker, "hover");
			}),
		);
		connections.push(button.Destroying.Connect(() => release(button)));
		tracked.set(button, connections);
	};
	const attachTextBox = (textBox: TextBox) => {
		if (tracked.has(textBox)) {
			return;
		}
		let focusMarker = -1;
		let pressedAt = -math.huge;
		const connections: RBXScriptConnection[] = [];
		connections.push(
			textBox.InputBegan.Connect((input) => {
				if (!isActivationInput(input)) {
					return;
				}
				const now = os.clock();
				focusMarker = now - inputStartedAt <= 0.15 ? inputMarker : Audio.captureIntent();
				pressedAt = now;
			}),
		);
		connections.push(
			textBox.Focused.Connect(() => {
				if (os.clock() - pressedAt > 2 || focusMarker < 0) {
					return;
				}
				const marker = focusMarker;
				focusMarker = -1;
				Audio.playIfUnclaimed(marker, "inputFocus");
			}),
		);
		connections.push(textBox.Destroying.Connect(() => release(textBox)));
		tracked.set(textBox, connections);
	};
	const attach = (instance: Instance) => {
		if (disposed) {
			return;
		}
		if (root.IsA("PlayerGui")) {
			let cursor: Instance | undefined = instance;
			let gameLayer = false;
			while (cursor !== undefined && cursor !== root) {
				if (cursor.IsA("ScreenGui")) {
					gameLayer = string.sub(cursor.Name, 1, 11) === "AstralForge";
					break;
				}
				cursor = cursor.Parent;
			}
			if (!gameLayer) {
				return;
			}
		}
		if (instance.IsA("GuiButton")) {
			attachButton(instance);
		} else if (instance.IsA("TextBox")) {
			attachTextBox(instance);
		}
	};
	for (const descendant of root.GetDescendants()) {
		attach(descendant);
	}
	const added = root.DescendantAdded.Connect(attach);
	// a control pulled out without being destroyed keeps its connections alive otherwise; it
	// re-attaches through DescendantAdded if it comes back
	const removed = root.DescendantRemoving.Connect(release);
	return () => {
		if (disposed) {
			return;
		}
		disposed = true;
		globalInput.Disconnect();
		added.Disconnect();
		removed.Disconnect();
		tracked.forEach((_, instance) => release(instance));
	};
}
