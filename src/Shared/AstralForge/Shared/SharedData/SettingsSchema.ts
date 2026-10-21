interface Choice {
	label: string;
	value: number;
}
interface Entry {
	key: string;
	section: string;
	label: string;
	help: string;
	kind: "toggle" | "slider" | "choice";
	default: number;
	choices?: Choice[];
	advanced?: boolean;
	touchOnly?: boolean;
}
interface Section {
	id: string;
	label: string;
	icon: string;
	accent: string;
	blurb: string;
	touchOnly?: boolean;
}
interface Preset {
	id: string;
	label: string;
	notice: string;
	values: Record<string, number>;
}
const SECTIONS: ReadonlyArray<Section> = table.freeze([
	{ id: "sound", label: "Sound", icon: "Wave.20", accent: "mint", blurb: "Volume for music, effects and alerts." },
	{ id: "display", label: "Graphics", icon: "Boost.22", accent: "pink", blurb: "Effects, glow and how lively the menus move." },
	{ id: "interface", label: "Interface", icon: "Settings.4", accent: "cyan", blurb: "What the screen shows and how it is laid out." },
	{ id: "accessibility", label: "Accessibility", icon: "Guide.3", accent: "mango", blurb: "Text size, contrast and color-safe signals." },
	{ id: "social", label: "Social", icon: "Chat.8", accent: "violet", blurb: "Who can reach you, and how chat looks." },
	{ id: "mobile", label: "Phone", icon: "Menu.5", accent: "blue", blurb: "Sizes and layout for touch screens.", touchOnly: true },
]);

const SIZE4: Choice[] = [
	{ label: "S", value: 0.25 },
	{ label: "M", value: 0.5 },
	{ label: "L", value: 0.75 },
	{ label: "XL", value: 1 },
];

const THREE = (a: string, b: string, c: string, va: number, vb: number, vc: number): Choice[] => [
	{ label: a, value: va },
	{ label: b, value: vb },
	{ label: c, value: vc },
];
function toggle(key: string, section: string, label: string, help: string, def: number, advanced?: boolean): Entry {
	return { key, section, label, help, kind: "toggle", default: def, advanced };
}
function slider(key: string, section: string, label: string, help: string, def: number, advanced?: boolean): Entry {
	return { key, section, label, help, kind: "slider", default: def, advanced };
}
function choice(key: string, section: string, label: string, help: string, def: number, choices: Choice[], advanced?: boolean): Entry {
	return { key, section, label, help, kind: "choice", default: def, choices, advanced };
}
const ENTRIES: ReadonlyArray<Entry> = table.freeze([
	slider("SoundVolume", "sound", "Master volume", "Everything at once.", 0.75),
	slider("MusicVolume", "sound", "Music", "The soundtrack.", 1),
	slider("SfxVolume", "sound", "Sound effects", "Buttons, rewards, machines.", 1),
	toggle("PageMusic", "sound", "Background music", "Play the soundtrack at all.", 1),
	toggle("NotificationSounds", "sound", "Alert sounds", "Mail, unlocks and other pings.", 1),
	toggle("HoverSounds", "sound", "Hover sounds", "A soft tick when you point at a button.", 1),
	slider("UiVolume", "sound", "Menu clicks", "Taps and page turns.", 0.6, true),
	slider("GameplayVolume", "sound", "Gameplay sounds", "Machines, Star Foundry, arcade.", 1, true),
	slider("RewardVolume", "sound", "Reward sounds", "Claims, crates, the wheel.", 1, true),
	slider("AmbientVolume", "sound", "Ambience", "The quiet forge noise under the music.", 0.75, true),
	slider("SoundVariation", "sound", "Pitch variation", "Small changes so repeated clicks don't sound identical.", 0.7, true),
	slider("EffectsIntensity", "display", "Effects", "Sparks, pops and flashes.", 1),
	slider("MotionIntensity", "display", "Animation", "How lively menus feel. Lower is calmer, never choppy.", 1),
	toggle("ConfettiEnabled", "display", "Celebrations", "Confetti and bursts on big wins.", 1),
	toggle("ScreenFlashes", "display", "Screen flashes", "A brief flash on big moments.", 0.8),
	toggle("BackgroundStars", "display", "Background stars", "The starfield behind the pages.", 1),
	toggle("ButtonShimmers", "display", "Button shine", "A light sweep across hovered buttons.", 1),
	slider("RainbowIntensity", "display", "Rainbow colour", "Colour sweeps on rare items, selections and full bars.", 0.7),
	toggle("ScreenEffects", "display", "Screen effects", "Edge light, tints and blur on confirms and big moments.", 1),
	slider("GlowIntensity", "display", "Glow", "Light around rewards and live things.", 0.75, true),
	slider("ParticleDensity", "display", "Particles", "How many sparks and bits fly.", 0.75, true),
	slider("ShimmerIntensity", "display", "Shine strength", "How bright the button sweep is.", 0.8, true),
	slider("BackgroundDetail", "display", "Background detail", "Depth and glow behind the menus.", 0.8, true),
	toggle("AmbientGlow", "display", "Ambient light", "Soft colored light behind the interface.", 1, true),
	toggle("PanelHover", "display", "Card lift", "Cards rise a little when you point at them.", 1, true),
	toggle("PanelEntrances", "display", "Card entrances", "New cards ease in instead of appearing.", 1, true),
	toggle("AnimatedTitles", "display", "Moving titles", "Titles keep a slow drift.", 1, true),
	toggle("IconAnimations", "display", "Moving icons", "Large icons turn and orbit.", 1, true),
	toggle("NumberAnimations", "display", "Rolling numbers", "Counters roll when they change.", 1, true),
	toggle("OfflineRewardEffects", "display", "Welcome-back glow", "Effects when you return to offline earnings.", 1, true),
	slider("ViewportSpeed", "display", "3D spin speed", "How fast 3D icons turn.", 0.65, true),
	slider("ReactorMotion", "display", "Star Foundry motion", "Beams, pulses, and star drift.", 0.8, true),
	toggle("ShowFps", "interface", "FPS", "Frame rate in the top bar.", 1),
	toggle("ShowPing", "interface", "Ping", "Connection delay in the top bar.", 1),
	toggle("ShowResourceLabels", "interface", "Currency labels", "FLUX, CORES and DUST above the numbers.", 1),
	toggle("ShowNextGoal", "interface", "Level bar", "Your Forge Level and next goal under page titles.", 1),
	toggle(
		"FirstGoals",
		"interface",
		"First goals",
		"Short starter goals with small rewards on Overview. Turn back on to pick up where you left off.",
		1,
	),
	toggle("Tooltips", "interface", "Tooltips", "Notes when you hover, or press and hold on a phone.", 1),
	toggle("CompactTopBar", "interface", "Compact top bar", "A shorter header with more room below.", 0),
	choice("UiDensity", "interface", "Spacing", "Room between things on the page.", 0.55, THREE("Tight", "Normal", "Roomy", 0.2, 0.55, 0.9)),
	choice(
		"ToastDensity",
		"interface",
		"Alerts on screen",
		"How many notifications stack up.",
		0.55,
		THREE("Few", "Some", "Many", 0.2, 0.55, 0.9),
	),
	choice(
		"NotificationDuration",
		"interface",
		"Alert time",
		"How long notifications stay.",
		0.55,
		THREE("Short", "Normal", "Long", 0.25, 0.55, 0.9),
	),
	choice(
		"PerformanceBias",
		"interface",
		"Priority",
		"Favor looks or frame rate when the game is busy.",
		0.5,
		THREE("Looks", "Balanced", "Speed", 0, 0.5, 1),
	),
	choice(
		"ScrollSpeed",
		"interface",
		"Scroll speed",
		"How far one wheel notch moves a list.",
		0.65,
		THREE("Slow", "Normal", "Fast", 0.35, 0.65, 0.95),
		true,
	),
	slider("ScrollMomentum", "interface", "Scroll glide", "How long a list keeps moving after you let go.", 0.75, true),
	choice("DesktopTextScale", "accessibility", "Text size", "Bigger or smaller text. Buttons stay where they are.", 0.5, SIZE4),
	toggle("HighContrast", "accessibility", "High contrast", "Stronger text and edges.", 0),
	toggle("ColorblindMode", "accessibility", "Color-safe signals", "Blue and gold instead of green and red.", 0),
	toggle("BoldText", "accessibility", "Bolder text", "Heavier descriptions.", 0),
	toggle("ReducedTransparency", "accessibility", "Solid panels", "Less see-through backgrounds.", 0),
	toggle("LargeTouchTargets", "accessibility", "Large buttons", "Bigger tap targets on touch screens.", 1),
	slider("HapticIntensity", "accessibility", "Vibration", "How hard the phone buzzes on taps.", 0.65),
	// Social: the "who can reach you" choices are enforced by the server, not just hidden in the UI
	toggle("ChatShowGlobal", "social", "Global chat", "Show messages from every server in the All tab.", 1),
	toggle("ChatSounds", "social", "Chat sounds", "A soft sound when a message arrives.", 1),
	toggle("ChatUseProfileAccent", "social", "Profile colours in chat", "Names use each player's chosen profile accent.", 1),
	choice(
		"ChatTextSize",
		"social",
		"Chat text size",
		"Message text in the chat page.",
		0.5,
		THREE("Small", "Normal", "Large", 0.2, 0.5, 0.85),
	),
	toggle("WhispersFriendsOnly", "social", "Whispers from friends only", "Only Roblox friends can start a private chat with you.", 0),
	choice("CrewInvitePolicy", "social", "Crew invites", "Who can invite you to a crew.", 0, THREE("Anyone", "Friends", "Nobody", 0, 0.5, 1)),
	choice(
		"TradeInvitePolicy",
		"social",
		"Trade invites",
		"Who can invite you to trade.",
		0,
		THREE("Anyone", "Friends", "Nobody", 0, 0.5, 1),
	),
	choice("MobileTextScale", "mobile", "Text size", "Text size on phones.", 0.5, SIZE4),
	choice("MobileQuickReverse", "mobile", "Main thumb", "Which side the overcharge button sits on.", 0, [
		{ label: "Right", value: 0 },
		{ label: "Left", value: 1 },
	]),
	toggle("MobileQuickVisible", "mobile", "Quick buttons", "Vault and overcharge above the menu.", 1),
	toggle("MobileDockVisible", "mobile", "Bottom menu", "Show the menu bar. The drawer still works.", 1),
	toggle("MobileToastVisible", "mobile", "Alerts", "Floating notifications.", 1),
	toggle("MobileCompactHeaders", "mobile", "Short headers", "Smaller page titles for more room.", 1),
	toggle("MobileAutoHideDock", "mobile", "Hide menu while typing", "Also hides it in the arcade.", 1),
	toggle("MobileLandscapeCompact", "mobile", "Compact sideways", "Fewer headers when the phone is turned.", 1),
	toggle("MobileKeyboardCompact", "mobile", "Compact with keyboard", "Shrink the chrome while typing.", 1),
	slider("MobileQuickScale", "mobile", "Quick button size", "Vault and overcharge buttons.", 0.5, true),
	slider("MobileDockScale", "mobile", "Menu size", "The bottom menu.", 0.5, true),
	slider("MobileToastScale", "mobile", "Alert size", "Notification cards.", 0.5, true),
	slider("MobileQuickOpacity", "mobile", "Quick button opacity", "How solid the floating buttons are.", 0.9, true),
	slider("MobileDockOpacity", "mobile", "Menu opacity", "How solid the bottom menu is.", 0.88, true),
	slider("MobileToastOpacity", "mobile", "Alert opacity", "How solid notifications are.", 0.9, true),
	slider("MobileButtonSpacing", "mobile", "Button spacing", "Room between thumb buttons.", 0.5, true),
]);

// Sub-headings inside each section. Rows render grouped in this order; keys not listed fall into the last group.
const GROUPS: Readonly<Record<string, ReadonlyArray<{ label: string; keys: ReadonlyArray<string> }>>> = table.freeze({
	sound: [
		{ label: "Volume", keys: ["SoundVolume", "MusicVolume", "SfxVolume", "UiVolume", "GameplayVolume", "RewardVolume", "AmbientVolume"] },
		{ label: "Switches", keys: ["PageMusic", "NotificationSounds", "HoverSounds"] },
		{ label: "Fine tuning", keys: ["SoundVariation"] },
	],
	display: [
		{
			label: "Motion",
			keys: [
				"MotionIntensity",
				"AnimatedTitles",
				"IconAnimations",
				"NumberAnimations",
				"PanelHover",
				"PanelEntrances",
				"ViewportSpeed",
				"ReactorMotion",
			],
		},
		{ label: "Effects", keys: ["EffectsIntensity", "ConfettiEnabled", "ScreenFlashes", "ScreenEffects", "RainbowIntensity", "ParticleDensity", "OfflineRewardEffects"] },
		{
			label: "Light and background",
			keys: ["GlowIntensity", "ButtonShimmers", "ShimmerIntensity", "BackgroundStars", "BackgroundDetail", "AmbientGlow"],
		},
	],
	interface: [
		{ label: "Top bar", keys: ["ShowFps", "ShowPing", "ShowResourceLabels", "CompactTopBar"] },
		{ label: "Pages", keys: ["ShowNextGoal", "FirstGoals", "Tooltips", "UiDensity", "ScrollSpeed", "ScrollMomentum"] },
		{ label: "Alerts", keys: ["ToastDensity", "NotificationDuration"] },
		{ label: "Performance", keys: ["PerformanceBias"] },
	],
	accessibility: [
		{ label: "Reading", keys: ["DesktopTextScale", "BoldText", "HighContrast", "ReducedTransparency", "ColorblindMode"] },
		{ label: "Touch", keys: ["LargeTouchTargets", "HapticIntensity"] },
	],
	social: [
		{ label: "Chat", keys: ["ChatShowGlobal", "ChatSounds", "ChatUseProfileAccent", "ChatTextSize"] },
		{ label: "Privacy", keys: ["WhispersFriendsOnly", "CrewInvitePolicy", "TradeInvitePolicy"] },
	],
	mobile: [
		{
			label: "Layout",
			keys: [
				"MobileTextScale",
				"MobileQuickReverse",
				"MobileQuickVisible",
				"MobileDockVisible",
				"MobileToastVisible",
				"MobileCompactHeaders",
				"MobileAutoHideDock",
				"MobileLandscapeCompact",
				"MobileKeyboardCompact",
			],
		},
		{
			label: "Sizes and opacity",
			keys: [
				"MobileQuickScale",
				"MobileDockScale",
				"MobileToastScale",
				"MobileQuickOpacity",
				"MobileDockOpacity",
				"MobileToastOpacity",
				"MobileButtonSpacing",
			],
		},
	],
});
const groupOf: Record<string, { label: string; order: number } | undefined> = {};
for (const [, groups] of pairs(GROUPS)) {
	groups.forEach((group, order) => {
		for (const key of group.keys) {
			groupOf[key] = { label: group.label, order };
		}
	});
}

/** Sub-heading and sort order for a setting inside its section. */
function group(key: string): { label: string; order: number } {
	return groupOf[key] ?? { label: "Other", order: 99 };
}

const HIDDEN_KEYS = table.freeze({
	RippleIntensity: 0.5,
	ButtonRipples: 1,
	MobileHudScale: 0.5,
	MobileHudOpacity: 0.85,
	MobilePreviewAck: 0,
	MobileQuickX: 0.5,
	MobileQuickY: 0.7,
	MobileDockX: 0.5,
	MobileDockY: 0.92,
	MobileToastX: 0.84,
	MobileToastY: 0.27,
}) as Readonly<Record<string, number>>;

const byKey: Record<string, Entry | undefined> = {};
for (const entry of ENTRIES) {
	assert(byKey[entry.key] === undefined, "duplicate setting " + entry.key);
	byKey[entry.key] = entry;
}

function entry(key: string): Entry | undefined {
	return byKey[key];
}

function accepts(key: unknown): boolean {
	return typeIs(key, "string") && (byKey[key] !== undefined || HIDDEN_KEYS[key] !== undefined);
}

function normalize(key: string, value: number): number {
	const v = value === value ? math.clamp(value, 0, 1) : 0;
	const e = byKey[key];
	if (e === undefined) {
		return v;
	}
	if (e.kind === "toggle") {
		return v >= 0.5 ? 1 : 0;
	} else if (e.kind === "choice" && e.choices !== undefined) {
		let best = e.choices[0].value;
		let gap = math.huge;
		for (const option of e.choices) {
			const d = math.abs(option.value - v);
			if (d < gap) {
				best = option.value;
				gap = d;
			}
		}
		return best;
	}
	return v;
}

function value(settings: unknown, key: string): number {
	const raw = typeIs(settings, "table") ? (settings as Record<string, unknown>)[key] : undefined;
	if (typeIs(raw, "number") && raw === raw) {
		return math.clamp(raw, 0, 1);
	}
	const e = byKey[key];
	if (e !== undefined) {
		return e.default;
	}
	return HIDDEN_KEYS[key] ?? 1;
}

function inSection(section: string): Entry[] {
	const list: Entry[] = [];
	for (const e of ENTRIES) {
		if (e.section === section) {
			list.push(e);
		}
	}
	return list;
}

function sectionDefaults(section: string): Record<string, number> {
	const values: Record<string, number> = {};
	for (const e of ENTRIES) {
		if (e.section === section) {
			values[e.key] = e.default;
		}
	}
	return values;
}
const PRESETS: ReadonlyArray<Preset> = table.freeze([
	{
		id: "low",
		label: "Low",
		notice: "Low graphics: fewer effects, calmer motion.",
		values: {
			EffectsIntensity: 0.25,
			MotionIntensity: 0.3,
			ParticleDensity: 0.15,
			GlowIntensity: 0.25,
			ShimmerIntensity: 0.2,
			ButtonShimmers: 0,
			ConfettiEnabled: 0,
			ScreenFlashes: 0,
			ScreenEffects: 0,
			RainbowIntensity: 0,
			BackgroundDetail: 0.3,
			AnimatedTitles: 0,
			IconAnimations: 0,
			PerformanceBias: 1,
		},
	},
	{
		id: "balanced",
		label: "Balanced",
		notice: "Balanced graphics.",
		values: {
			EffectsIntensity: 0.7,
			MotionIntensity: 0.7,
			ParticleDensity: 0.6,
			GlowIntensity: 0.6,
			ShimmerIntensity: 0.7,
			ButtonShimmers: 1,
			ConfettiEnabled: 1,
			ScreenFlashes: 1,
			ScreenEffects: 1,
			RainbowIntensity: 0.5,
			BackgroundDetail: 0.7,
			AnimatedTitles: 1,
			IconAnimations: 1,
			PerformanceBias: 0.5,
		},
	},
	{
		id: "high",
		label: "High",
		notice: "High graphics: every effect at full.",
		values: {
			EffectsIntensity: 1,
			MotionIntensity: 1,
			ParticleDensity: 1,
			GlowIntensity: 1,
			ShimmerIntensity: 1,
			ButtonShimmers: 1,
			ConfettiEnabled: 1,
			ScreenFlashes: 1,
			ScreenEffects: 1,
			RainbowIntensity: 1,
			BackgroundDetail: 1,
			AnimatedTitles: 1,
			IconAnimations: 1,
			PerformanceBias: 0,
		},
	},
]);

function matchingPreset(settings: unknown): string | undefined {
	for (const preset of PRESETS) {
		let same = true;
		for (const [key, v] of pairs(preset.values)) {
			if (math.abs(value(settings, key) - v) > 0.03) {
				same = false;
				break;
			}
		}
		if (same) {
			return preset.id;
		}
	}
	return undefined;
}

export = table.freeze({
	SECTIONS,
	ENTRIES,
	HIDDEN_KEYS,
	PRESETS,
	entry,
	group,
	accepts,
	normalize,
	value,
	inSection,
	sectionDefaults,
	matchingPreset,
});
