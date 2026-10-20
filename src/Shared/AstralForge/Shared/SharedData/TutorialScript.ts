type Dict = Record<string, unknown>;

interface Step {
	id: string;
	title: string;
	line: string;
	task?: string;
	target: string | string[];
	startPage?: string;
	page: string;
	watch: string;
	auto?: boolean;
	cta?: string;
	ctaLabel?: string;
	controls?: string;
}

interface Rect {
	x: number;
	y: number;
	w: number;
	h: number;
}

const EXPERIENCE_NAME = "GETTING STARTED";

// Each step points at one real control. `watch` says what finishes it:
//   continue / finish  read it and press Next
//   collect / buy / amount / page:<id>  the player does it and the step ticks itself off
const STEPS: ReadonlyArray<Step> = table.freeze([
	{
		id: "vault",
		title: "This is your vault",
		line: "Your machines pour Flux in here, even while you're offline.",
		target: "OverviewVaultClaimActions",
		startPage: "Overview",
		page: "Overview",
		watch: "continue",
	},
	{
		id: "collect",
		title: "Collect it",
		line: "Stored Flux becomes cash you can spend. A full vault stops filling.",
		task: "Collect the vault",
		target: "OverviewVaultClaimActions",
		page: "Overview",
		watch: "collect",
		auto: true,
		cta: "collect",
		ctaLabel: "Collect",
		controls: "Keyboard E  ·  Controller Y",
	},
	{
		id: "toWorkshop",
		title: "Open the Workshop",
		line: "Machines are bought here. It's the page you'll use most.",
		task: "Open the Workshop",
		target: "Nav_Workshop",
		page: "Workshop",
		watch: "page:Workshop",
		auto: true,
		cta: "workshop",
		ctaLabel: "Open Workshop",
	},
	{
		id: "buy",
		title: "Buy a machine",
		line: "Every level adds Flux per second. Greyed out means collect first.",
		task: "Buy any machine",
		target: "WorkshopBuyClaim",
		startPage: "Workshop",
		page: "Workshop",
		watch: "buy",
		auto: true,
	},
	{
		id: "amount",
		title: "Buy in bulk",
		line: "x5 buys five levels at once. Max buys everything you can afford.",
		task: "Switch to x5 or Max",
		target: "AmountToggleTarget",
		page: "Workshop",
		watch: "amount",
		auto: true,
		controls: "Controller LT / RT",
	},
	{
		id: "level",
		title: "Your level",
		line: "Levels open new parts of the forge. Tap the bar to see what each one unlocks.",
		target: [ "LevelBarTarget", "MobileHeader" ],
		page: "Workshop",
		watch: "continue",
	},
	{
		id: "toResearch",
		title: "Open Research",
		line: "Research bonuses are permanent. They stay when you rebirth.",
		task: "Open Research",
		target: "Nav_Research",
		page: "Research",
		watch: "page:Research",
		auto: true,
		cta: "research",
		ctaLabel: "Open Research",
	},
	{
		id: "menu",
		title: "Every page is here",
		line: "New pages join the menu as you level up. On a phone it's the Menu tab.",
		target: [ "RailNavClaim", "Nav_Menu" ],
		page: "Research",
		watch: "continue",
	},
	{
		id: "finish",
		title: "That's the loop",
		line: "Collect, buy, research, and rebirth for Cores when the run slows down. Replay this from Settings.",
		target: [ "Nav_Overview", "Nav_Menu" ],
		startPage: "Overview",
		page: "Overview",
		watch: "finish",
	},
]);

function num(value: unknown, fallback: number): number {
	if (typeIs(value, "number") && value === value) {
		return value;
	}
	return fallback;
}

function goalMet(step: Step | undefined, live: unknown, collected?: boolean): boolean {
	if (step === undefined) {
		return false;
	}
	const watch = step.watch;
	const l = (typeIs(live, "table") ? live : {}) as Dict;
	if (watch === "continue" || watch === "finish") {
		return true;
	} else if (watch === "collect") {
		return collected === true || (typeIs(l.vaultFlux, "number") && l.vaultFlux <= 0.01);
	} else if (watch === "buy") {
		return num(l.ownedMachines, 0) > 0;
	} else if (watch === "amount") {
		return num(l.buyAmount, 1) !== 1;
	} else if (typeIs(watch, "string") && watch.sub(1, 5) === "page:") {
		return l.page === watch.sub(6);
	}
	return false;
}

function needsAction(step: Step | undefined): boolean {
	return step !== undefined && step.watch !== "continue" && step.watch !== "finish";
}

function progress(index: number, count: number, met: boolean): number {
	const total = math.max(1, count);
	return math.clamp((index - (met ? 0 : 0.5)) / total, 0, 1);
}

// Where the callout card goes: beside the target with room for the leader line (right, left,
// below, above), else docked at the bottom or top, whichever covers less of the target.
// Returns x, y and the side ("right" | "left" | "below" | "above" | "dock").
const LEADER_GAP = 34;
function calloutPlacement(
	rect: Rect | undefined,
	screenW: number,
	screenH: number,
	cardW: number,
	cardH: number,
	topInset?: number,
	bottomInset?: number,
): LuaTuple<[number, number, string]> {
	const edge = 12;
	const gap = TutorialScript.LEADER_GAP;
	const minY = math.max(edge, num(topInset, 0) + 8);
	const maxY = math.max(minY, screenH - math.max(edge, num(bottomInset, 0)) - cardH);
	const minX = edge;
	const maxX = math.max(minX, screenW - edge - cardW);
	const centreX = (screenW - cardW) / 2;
	if (rect === undefined) {
		return $tuple(centreX, maxY, "dock");
	}
	const cx = rect.x + rect.w / 2;
	const cy = rect.y + rect.h / 2;
	const fitsY = cardH <= screenH - minY - math.max(edge, num(bottomInset, 0));
	if (fitsY && rect.x + rect.w + gap + cardW <= screenW - edge) {
		return $tuple(rect.x + rect.w + gap, math.clamp(cy - cardH / 2, minY, maxY), "right");
	}
	if (fitsY && rect.x - gap - cardW >= edge) {
		return $tuple(rect.x - gap - cardW, math.clamp(cy - cardH / 2, minY, maxY), "left");
	}
	if (rect.y + rect.h + gap + cardH <= screenH - math.max(edge, num(bottomInset, 0))) {
		return $tuple(math.clamp(cx - cardW / 2, minX, maxX), rect.y + rect.h + gap, "below");
	}
	if (rect.y - gap - cardH >= minY) {
		return $tuple(math.clamp(cx - cardW / 2, minX, maxX), rect.y - gap - cardH, "above");
	}
	const overlap = (y: number) => math.max(0, math.min(y + cardH, rect.y + rect.h) - math.max(y, rect.y));
	if (overlap(maxY) > overlap(minY)) {
		return $tuple(centreX, minY, "dock");
	}
	return $tuple(centreX, maxY, "dock");
}

// The leader line for a placed card: from the card's edge facing the target to the target's edge.
function leader(
	rect: Rect | undefined,
	side: string,
	cardX: number,
	cardY: number,
	cardW: number,
	cardH: number,
): LuaTuple<[number | undefined, number | undefined, number | undefined, number | undefined]> {
	if (rect === undefined || side === "dock") {
		return $tuple(undefined, undefined, undefined, undefined);
	}
	const inset = 18;
	if (side === "right" || side === "left") {
		const y = math.clamp(rect.y + rect.h / 2, cardY + inset, cardY + cardH - inset);
		const ty = math.clamp(y, rect.y + 4, rect.y + rect.h - 4);
		if (side === "right") {
			return $tuple(cardX, y, rect.x + rect.w, ty);
		}
		return $tuple(cardX + cardW, y, rect.x, ty);
	}
	const x = math.clamp(rect.x + rect.w / 2, cardX + inset, cardX + cardW - inset);
	const tx = math.clamp(x, rect.x + 4, rect.x + rect.w - 4);
	if (side === "below") {
		return $tuple(x, cardY, tx, rect.y + rect.h);
	}
	return $tuple(x, cardY + cardH, tx, rect.y);
}

const TutorialScript = {
	EXPERIENCE_NAME,
	STEPS,
	LEADER_GAP,
	goalMet,
	needsAction,
	progress,
	calloutPlacement,
	leader,
};

export = TutorialScript;
