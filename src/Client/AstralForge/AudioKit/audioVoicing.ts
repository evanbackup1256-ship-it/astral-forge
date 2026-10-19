export interface Voice {
	high: number;
	mid: number;
	low: number;
	reverbDecay: number;
	reverbWet: number;
	drive: number;
	pitch: number;
	decay: number;
	gain: number;
}

export interface Layer {
	source: string;
	pitch: number;
	volume: number;
	delay: number;
}

const FAMILIES: Record<string, Voice> = {
	chrome: {
		high: 5, mid: -12, low: -24,
		reverbDecay: 0, reverbWet: 0,
		drive: 0, pitch: 1.34, decay: 0.36, gain: 0.61,
	},
	interface: {
		high: -2, mid: 4, low: -6,
		reverbDecay: 0.25, reverbWet: 0.024,
		drive: 0, pitch: 1, decay: 0.65, gain: 0.85,
	},
	motion: {
		high: 3, mid: -10, low: -12,
		reverbDecay: 0.55, reverbWet: 0.072,
		drive: 0, pitch: 0.94, decay: 0.88, gain: 0.75,
	},
	forge: {
		high: -10, mid: 2, low: 9,
		reverbDecay: 0.45, reverbWet: 0.056,
		drive: 0.044, pitch: 0.74, decay: 0.98, gain: 0.95,
	},
	currency: {
		high: 6, mid: 0, low: -14,
		reverbDecay: 0.4, reverbWet: 0.048,
		drive: 0, pitch: 1.46, decay: 0.59, gain: 0.85,
	},
	reward: {
		high: 4, mid: 3, low: -2,
		reverbDecay: 0.9, reverbWet: 0.104,
		drive: 0, pitch: 1.08, decay: 1.11, gain: 0.99,
	},
	arcane: {
		high: 1, mid: -4, low: 2,
		reverbDecay: 1.6, reverbWet: 0.168,
		drive: 0.016, pitch: 0.66, decay: 1.43, gain: 1.02,
	},
	reactor: {
		high: -8, mid: -8, low: 7,
		reverbDecay: 1.2, reverbWet: 0.12,
		drive: 0.024, pitch: 0.82, decay: 1.17, gain: 0.7,
	},
	denial: {
		high: -30, mid: -8, low: 8,
		reverbDecay: 0.15, reverbWet: 0.016,
		drive: 0.068, pitch: 0.58, decay: 0.78, gain: 0.85,
	},
	alert: {
		high: -14, mid: 4, low: 4,
		reverbDecay: 0.3, reverbWet: 0.04,
		drive: 0.028, pitch: 0.88, decay: 0.81, gain: 0.9,
	},
	notice: {
		high: 2, mid: -2, low: -8,
		reverbDecay: 0.65, reverbWet: 0.08,
		drive: 0, pitch: 1.12, decay: 0.72, gain: 0.77,
	},
	ceremony: {
		high: 0, mid: 0, low: 10,
		reverbDecay: 1.1, reverbWet: 0.112,
		drive: 0.028, pitch: 0.62, decay: 1.56, gain: 0.97,
	},
	mechanism: {
		high: 4, mid: -6, low: -16,
		reverbDecay: 0.18, reverbWet: 0.02,
		drive: 0.012, pitch: 1.22, decay: 0.39, gain: 0.73,
	},
	social: {
		high: 1, mid: 6, low: -6,
		reverbDecay: 0.35, reverbWet: 0.044,
		drive: 0, pitch: 1.26, decay: 0.59, gain: 0.68,
	},
};

const CUE_FAMILY: Record<string, string> = {};

function assign(family: string, cues: string[]) {
	for (const cue of cues) {
		CUE_FAMILY[cue] = family;
	}
}

assign("chrome", [
	"hover", "hoverTick", "scroll", "tick", "sliderStep", "filterPick",
	"amountChange", "storyPage", "wheelTick", "crateTick",
	"navHover", 
]);

assign("interface", [
	"click", "confirm", "settings", "toggleOn", "toggleOff", "sliderCommit",
	"inputFocus", "inputClear", "claimPress", "equip", "itemLink", "itemUnlink",
	"playerlistSelect", "playerlistAction", "roleChange",
	"tutorialStep", "codeSubmit", "machineInstall", "mailRead",
	
]);

assign("motion", [
	"page", "tabSwitch", "open", "close", "modalOpen", "modalPop", "modalDismiss",
	"filterOpen", "travel", "preview", "mail", "playerlistOpen",
	"playerlistClose", "purchaseExit", "zoneSelect", "expeditionLaunch",
	"expeditionReturn", "boostOpen", 
	
]);

assign("forge", [
	"salvage", "salvageCrunch", "reset", "memberRemove", "adminArm",
	"adminExecute", "echoDismantle", "labRoute", "autoForge",
	
]);

assign("currency", [
	"purchase", "purchasePress", "purchaseResult", "vaultBank", "vaultDeposit",
	"guildDeposit", "guildCreate", "collect", "coin",
]);

assign("reward", [
	"reward", "unlock", "successChime", "dailyClaim", "timedClaim",
	"seasonClaim", "missionClaim", "achievementClaim", "mailClaim", "codeReward",
	"tutorialFinish", "discovery", "researchUnlock", "zoneUnlock", 
	"comboMilestone", "offlineCollect", "offlineOpen", "crateClaim", "crateRare",
	"wheelLand", "crateLand", "echoClaim", 
]);

assign("arcane", [
	"prestige", "rebirthCharge", "rebirthBloom", "domainCharge", "domainCrack",
	"domainImpact", "domainReward", "domainBind", "echoCapture", "echoTune",
	"echoEquip", "storyReveal",
	
	
]);

assign("reactor", [
	"reactor", "reactorReady", "reactorPulse", 
	"reactorStabilize", "reactorSurge", 
]);

assign("denial", [
	"error", "errorBuzz", "noticeError", "requestTimeout", "requestBlocked",
	"locked", "dangerPress",
]);

assign("alert", [
	"noticeWarning", "systemAlert", 
]);

assign("notice", [
	"notification", "noticeInfo", "noticeSuccess", "noticeSpecial", 
	"boostReady", "boostActivate", "queueStart", "queueStop",
	
]);

assign("ceremony", [
	"boot", "bootStart", 
	"bootReady",
	"bootFinaleBang", 
	
	"storyOpen", "story", "storyBeat",
]);

assign("mechanism", [
	"wheelStart", "wheelCharge", "wheelSlow", "wheelBrake", "crateOpen",
	"crateCharge", "crateNear", "crateBrake", "leaderboardSwitch",
]);

assign("social", [
	"chatSend", "chatReceive", "invite", "crewNudge", "guildJoin", "guildLeave",
]);

const NEUTRAL: Voice = FAMILIES.interface;

export function familyOf(cue: string): string {
	return CUE_FAMILY[cue] ?? "interface";
}

export function voiceFor(cue: string): Voice {
	return FAMILIES[familyOf(cue)] ?? NEUTRAL;
}

export function families(): Record<string, Voice> {
	return FAMILIES;
}

export function cueFamilies(): Record<string, string> {
	return CUE_FAMILY;
}

export function clampGain(value: number): number {
	return math.clamp(value, -80, 10);
}

const LAYERS: Record<string, Layer> = {
	domainImpact: { source: "click", pitch: 0.42, volume: 0.5, delay: 0.012 },
	domainCharge: { source: "confirm", pitch: 0.5, volume: 0.42, delay: 0.03 },
	domainReward: { source: "confirm", pitch: 1.5, volume: 0.34, delay: 0.05 },
	prestige: { source: "click", pitch: 0.46, volume: 0.46, delay: 0.015 },
	rebirthBloom: { source: "confirm", pitch: 1.42, volume: 0.38, delay: 0.045 },
	reward: { source: "hover", pitch: 1.62, volume: 0.3, delay: 0.04 },
	achievementClaim: { source: "hover", pitch: 1.55, volume: 0.3, delay: 0.045 },
	seasonClaim: { source: "hover", pitch: 1.48, volume: 0.32, delay: 0.05 },
	crateRare: { source: "hover", pitch: 1.7, volume: 0.34, delay: 0.035 },
	zoneUnlock: { source: "confirm", pitch: 1.34, volume: 0.3, delay: 0.05 },
	salvageCrunch: { source: "click", pitch: 0.5, volume: 0.4, delay: 0.01 },
	adminExecute: { source: "click", pitch: 0.44, volume: 0.38, delay: 0.012 },
	purchaseResult: { source: "hover", pitch: 1.66, volume: 0.26, delay: 0.03 },
	vaultDeposit: { source: "hover", pitch: 1.58, volume: 0.26, delay: 0.028 },
	error: { source: "click", pitch: 0.4, volume: 0.36, delay: 0.02 },
	requestTimeout: { source: "click", pitch: 0.38, volume: 0.34, delay: 0.025 },
	bootFinaleBang: { source: "click", pitch: 0.4, volume: 0.5, delay: 0.014 },
};

export function layerFor(cue: string): Layer | undefined {
	return LAYERS[cue];
}

export function layers(): Record<string, Layer> {
	return LAYERS;
}
