// Decides *how* something should move from *what* it is.
// Callers describe the element (role, rarity, tone, emphasis) and the
// device budget; the resolver returns one coherent motion plan so every
// surface of the same kind feels the same without hand-tuned springs.

interface Spring {
	stiffness: number;
	damping: number;
}

interface Plan {
	role: string;
	style: string;
	enter: Spring;
	exit: Spring;
	hover: Spring;
	press: Spring;
	travel: number;
	scaleFrom: number;
	overshoot: number;
	stagger: number;
	flashSeconds: number;
	shake: number;
	particles: number;
	glow: number;
	cue?: string;
	celebrate: boolean;
	weight: number;
	reduced: boolean;
}

interface Request {
	role?: string;
	name?: string;
	rarity?: string;
	tone?: string;
	emphasis?: number;
	reduced?: boolean;
	tier?: number;
	particleBudget?: number;
	glowScale?: number;
	allowConfetti?: boolean;
}

interface RoleSpec {
	style: string;
	enter: Spring;
	exit: Spring;
	hover: Spring;
	press: Spring;
	travel: number;
	scaleFrom: number;
	overshoot: number;
	stagger: number;
	flash: number;
	shake: number;
	particles: number;
	glow: number;
	cue?: string;
}

const ROLES: Record<string, RoleSpec> = table.freeze({
	button: table.freeze({
		style: "press",
		enter: table.freeze({ stiffness: 520, damping: 34 }),
		exit: table.freeze({ stiffness: 760, damping: 44 }),
		hover: table.freeze({ stiffness: 640, damping: 38 }),
		press: table.freeze({ stiffness: 900, damping: 46 }),
		travel: 0,
		scaleFrom: 0.96,
		overshoot: 0.02,
		stagger: 0.03,
		flash: 0.18,
		shake: 0,
		particles: 0,
		glow: 0.25,
	}),
	primaryButton: table.freeze({
		style: "press",
		enter: table.freeze({ stiffness: 480, damping: 30 }),
		exit: table.freeze({ stiffness: 760, damping: 44 }),
		hover: table.freeze({ stiffness: 600, damping: 34 }),
		press: table.freeze({ stiffness: 940, damping: 44 }),
		travel: 0,
		scaleFrom: 0.94,
		overshoot: 0.04,
		stagger: 0.04,
		flash: 0.24,
		shake: 0,
		particles: 0,
		glow: 0.45,
	}),
	dangerButton: table.freeze({
		style: "press",
		enter: table.freeze({ stiffness: 560, damping: 40 }),
		exit: table.freeze({ stiffness: 820, damping: 48 }),
		hover: table.freeze({ stiffness: 700, damping: 44 }),
		press: table.freeze({ stiffness: 980, damping: 52 }),
		travel: 0,
		scaleFrom: 0.97,
		overshoot: 0,
		stagger: 0.03,
		flash: 0.14,
		shake: 0.6,
		particles: 0,
		glow: 0.2,
	}),
	toast: table.freeze({
		style: "slide",
		enter: table.freeze({ stiffness: 460, damping: 32 }),
		exit: table.freeze({ stiffness: 820, damping: 42 }),
		hover: table.freeze({ stiffness: 640, damping: 38 }),
		press: table.freeze({ stiffness: 860, damping: 44 }),
		travel: 28,
		scaleFrom: 0.98,
		overshoot: 0.02,
		stagger: 0.06,
		flash: 0.32,
		shake: 0,
		particles: 0,
		glow: 0.3,
	}),
	modal: table.freeze({
		style: "rise",
		enter: table.freeze({ stiffness: 380, damping: 30 }),
		exit: table.freeze({ stiffness: 640, damping: 40 }),
		hover: table.freeze({ stiffness: 560, damping: 36 }),
		press: table.freeze({ stiffness: 820, damping: 44 }),
		travel: 18,
		scaleFrom: 0.95,
		overshoot: 0.015,
		stagger: 0.05,
		flash: 0.3,
		shake: 0,
		particles: 0,
		glow: 0.35,
	}),
	page: table.freeze({
		style: "fade",
		enter: table.freeze({ stiffness: 420, damping: 36 }),
		exit: table.freeze({ stiffness: 700, damping: 44 }),
		hover: table.freeze({ stiffness: 560, damping: 36 }),
		press: table.freeze({ stiffness: 820, damping: 44 }),
		travel: 10,
		scaleFrom: 0.985,
		overshoot: 0,
		stagger: 0.035,
		flash: 0.2,
		shake: 0,
		particles: 0,
		glow: 0.15,
	}),
	card: table.freeze({
		style: "rise",
		enter: table.freeze({ stiffness: 440, damping: 32 }),
		exit: table.freeze({ stiffness: 700, damping: 42 }),
		hover: table.freeze({ stiffness: 600, damping: 36 }),
		press: table.freeze({ stiffness: 880, damping: 46 }),
		travel: 12,
		scaleFrom: 0.97,
		overshoot: 0.02,
		stagger: 0.045,
		flash: 0.24,
		shake: 0,
		particles: 0,
		glow: 0.3,
	}),
	listRow: table.freeze({
		style: "slide",
		enter: table.freeze({ stiffness: 520, damping: 38 }),
		exit: table.freeze({ stiffness: 760, damping: 46 }),
		hover: table.freeze({ stiffness: 640, damping: 40 }),
		press: table.freeze({ stiffness: 880, damping: 46 }),
		travel: 8,
		scaleFrom: 1,
		overshoot: 0,
		stagger: 0.025,
		flash: 0.16,
		shake: 0,
		particles: 0,
		glow: 0.12,
	}),
	tooltip: table.freeze({
		style: "fade",
		enter: table.freeze({ stiffness: 700, damping: 44 }),
		exit: table.freeze({ stiffness: 900, damping: 50 }),
		hover: table.freeze({ stiffness: 700, damping: 44 }),
		press: table.freeze({ stiffness: 900, damping: 50 }),
		travel: 4,
		scaleFrom: 0.98,
		overshoot: 0,
		stagger: 0,
		flash: 0,
		shake: 0,
		particles: 0,
		glow: 0,
	}),
	badge: table.freeze({
		style: "pop",
		enter: table.freeze({ stiffness: 520, damping: 22 }),
		exit: table.freeze({ stiffness: 760, damping: 42 }),
		hover: table.freeze({ stiffness: 600, damping: 30 }),
		press: table.freeze({ stiffness: 880, damping: 40 }),
		travel: 0,
		scaleFrom: 0.6,
		overshoot: 0.12,
		stagger: 0.06,
		flash: 0.4,
		shake: 0,
		particles: 3,
		glow: 0.55,
		cue: "badgeEarn",
	}),
	counter: table.freeze({
		style: "tick",
		enter: table.freeze({ stiffness: 600, damping: 30 }),
		exit: table.freeze({ stiffness: 760, damping: 42 }),
		hover: table.freeze({ stiffness: 600, damping: 36 }),
		press: table.freeze({ stiffness: 880, damping: 44 }),
		travel: 6,
		scaleFrom: 0.9,
		overshoot: 0.06,
		stagger: 0,
		flash: 0.22,
		shake: 0,
		particles: 0,
		glow: 0.3,
		cue: "countTick",
	}),
	reward: table.freeze({
		style: "bloom",
		enter: table.freeze({ stiffness: 360, damping: 22 }),
		exit: table.freeze({ stiffness: 640, damping: 40 }),
		hover: table.freeze({ stiffness: 560, damping: 32 }),
		press: table.freeze({ stiffness: 860, damping: 42 }),
		travel: 14,
		scaleFrom: 0.7,
		overshoot: 0.1,
		stagger: 0.08,
		flash: 0.5,
		shake: 0,
		particles: 6,
		glow: 0.7,
		cue: "reward",
	}),
	reveal: table.freeze({
		style: "bloom",
		enter: table.freeze({ stiffness: 300, damping: 20 }),
		exit: table.freeze({ stiffness: 600, damping: 38 }),
		hover: table.freeze({ stiffness: 520, damping: 30 }),
		press: table.freeze({ stiffness: 820, damping: 40 }),
		travel: 20,
		scaleFrom: 0.62,
		overshoot: 0.14,
		stagger: 0.1,
		flash: 0.62,
		shake: 1.2,
		particles: 10,
		glow: 0.85,
		cue: "crateReveal",
	}),
	ceremony: table.freeze({
		style: "ascend",
		enter: table.freeze({ stiffness: 220, damping: 18 }),
		exit: table.freeze({ stiffness: 520, damping: 34 }),
		hover: table.freeze({ stiffness: 480, damping: 30 }),
		press: table.freeze({ stiffness: 800, damping: 40 }),
		travel: 36,
		scaleFrom: 0.55,
		overshoot: 0.16,
		stagger: 0.12,
		flash: 0.9,
		shake: 2.4,
		particles: 14,
		glow: 1,
		cue: "rebirthAscend",
	}),
	drag: table.freeze({
		style: "lift",
		enter: table.freeze({ stiffness: 760, damping: 40 }),
		exit: table.freeze({ stiffness: 820, damping: 46 }),
		hover: table.freeze({ stiffness: 700, damping: 40 }),
		press: table.freeze({ stiffness: 940, damping: 48 }),
		travel: 0,
		scaleFrom: 1.04,
		overshoot: 0.03,
		stagger: 0,
		flash: 0.12,
		shake: 0,
		particles: 0,
		glow: 0.4,
	}),
});

// Name fragments (checked in order) used when a caller only knows the instance name.
const NAME_HINTS: ReadonlyArray<[string, string]> = table.freeze([
	["rebirth", "ceremony"],
	["ascend", "ceremony"],
	["prestige", "ceremony"],
	["reveal", "reveal"],
	["crate", "reveal"],
	["unbox", "reveal"],
	["reward", "reward"],
	["claim", "primaryButton"],
	["loot", "reward"],
	["delete", "dangerButton"],
	["remove", "dangerButton"],
	["kick", "dangerButton"],
	["ban", "dangerButton"],
	["confirm", "primaryButton"],
	["buy", "primaryButton"],
	["purchase", "primaryButton"],
	["submit", "primaryButton"],
	["toast", "toast"],
	["notice", "toast"],
	["notif", "toast"],
	["modal", "modal"],
	["dialog", "modal"],
	["popup", "modal"],
	["sheet", "modal"],
	["tooltip", "tooltip"],
	["hint", "tooltip"],
	["badge", "badge"],
	["achievement", "badge"],
	["title", "badge"],
	["count", "counter"],
	["balance", "counter"],
	["currency", "counter"],
	["stat", "counter"],
	["row", "listRow"],
	["entry", "listRow"],
	["item", "listRow"],
	["card", "card"],
	["tile", "card"],
	["slot", "card"],
	["page", "page"],
	["tab", "page"],
	["drag", "drag"],
	["handle", "drag"],
	["button", "button"],
	["btn", "button"],
]);

const RARITY_WEIGHT: Record<string, number> = table.freeze({
	Common: 0,
	Uncommon: 0.12,
	Rare: 0.26,
	Epic: 0.42,
	Legendary: 0.6,
	Mythic: 0.78,
	Celestial: 0.9,
	Astral: 1,
});

const TONE_CUE: Record<string, string> = table.freeze({
	Success: "noticeSuccess",
	Warning: "noticeWarning",
	Error: "noticeError",
	Special: "noticeSpecial",
	Info: "noticeInfo",
});

const RARITY_CUE: Record<string, string> = table.freeze({
	Epic: "crateRevealEpic",
	Legendary: "crateRevealEpic",
	Mythic: "crateRevealMythic",
	Celestial: "crateRevealMythic",
	Astral: "crateRevealMythic",
});

function roles(): string[] {
	const list: string[] = [];
	for (const [name] of pairs(ROLES)) {
		list.push(name);
	}
	list.sort();
	return list;
}

function classify(name: string | undefined): string {
	if (!typeIs(name, "string") || name === "") {
		return "card";
	}
	const lower = name.lower();
	for (const hint of NAME_HINTS) {
		if (lower.find(hint[0], 1, true)[0] !== undefined) {
			return hint[1];
		}
	}
	return "card";
}

function rarityWeight(rarity: string | undefined): number {
	return rarity ? RARITY_WEIGHT[rarity] ?? 0 : 0;
}

function scaleSpring(spring: Spring, energy: number): Spring {
	// More energy = looser, bouncier spring; damping ratio drops gently.
	const k = spring.stiffness * (1 - 0.18 * energy);
	const c = spring.damping * (1 - 0.32 * energy);
	return { stiffness: math.max(120, k), damping: math.max(12, c) };
}

function critical(spring: Spring): Spring {
	// Reduced motion: critically damped and quick so nothing bounces.
	const k = math.max(spring.stiffness, 600);
	return { stiffness: k, damping: 2 * math.sqrt(k) };
}

function resolve(request: Request): Plan {
	let role = request.role;
	if (role === undefined || ROLES[role] === undefined) {
		role = classify(request.name);
	}
	const spec = ROLES[role as string];
	const rarity = rarityWeight(request.rarity);
	const emphasis = math.clamp(request.emphasis ?? 0, 0, 1);
	const energy = math.clamp(math.max(rarity, emphasis), 0, 1);
	const tier = math.clamp(request.tier ?? 3, 0, 3);
	const tierScale = [0.15, 0.45, 0.75, 1][tier];
	const reduced = request.reduced === true;
	const budget = request.particleBudget ?? 14;
	const glowScale = request.glowScale ?? 1;

	let style = spec.style;
	if (role === "reward" && energy >= 0.6) {
		style = "burst";
	}

	let cue = spec.cue;
	if ((role === "reveal" || role === "reward") && request.rarity && RARITY_CUE[request.rarity]) {
		cue = RARITY_CUE[request.rarity];
	} else if (role === "toast" && request.tone) {
		cue = TONE_CUE[request.tone] ?? "noticeInfo";
	}

	const plan: Plan = {
		role: role as string,
		style: reduced ? "fade" : style,
		enter: scaleSpring(spec.enter, energy),
		exit: spec.exit,
		hover: spec.hover,
		press: spec.press,
		travel: spec.travel * (1 + 0.5 * energy),
		scaleFrom: spec.scaleFrom - (1 - spec.scaleFrom) * 0.35 * energy,
		overshoot: spec.overshoot * (1 + energy),
		stagger: spec.stagger,
		flashSeconds: spec.flash * (1 + 0.6 * energy),
		shake: spec.shake * energy * tierScale,
		particles: math.min(budget, math.floor(spec.particles * (1 + 1.4 * energy) * tierScale + 0.5)),
		glow: math.clamp(spec.glow * (0.7 + 0.6 * energy) * glowScale, 0, 1),
		cue,
		celebrate:
			energy >= 0.9 &&
			(role === "reveal" || role === "reward" || role === "ceremony") &&
			request.allowConfetti !== false,
		weight: energy,
		reduced,
	};

	if (reduced) {
		plan.enter = critical(plan.enter);
		plan.exit = critical(plan.exit);
		plan.hover = critical(plan.hover);
		plan.press = critical(plan.press);
		plan.travel = 0;
		plan.scaleFrom = 1;
		plan.overshoot = 0;
		plan.stagger = 0;
		plan.shake = 0;
		plan.particles = 0;
		plan.flashSeconds = math.min(plan.flashSeconds, 0.12);
	} else if (tier <= 1) {
		plan.stagger *= 0.5;
		plan.overshoot *= 0.5;
	}
	return plan;
}

// Stagger delay that compresses for long lists so the last item never waits forever.
function delay(plan: Plan, index: number): number {
	if (plan.stagger <= 0 || index <= 0) {
		return 0;
	}
	const cap = 0.42;
	return math.min(cap, (plan.stagger * index) / (1 + (index * plan.stagger) / cap));
}

const MotionIntent = {
	roles,
	classify,
	rarityWeight,
	resolve,
	delay,
};

export = table.freeze(MotionIntent);
