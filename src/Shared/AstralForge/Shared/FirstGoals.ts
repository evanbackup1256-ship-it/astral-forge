// First goals: the short guided path that picks up where the tour ends. One goal shows at a
// time on the Overview "next goal" card; when it's done the card turns into a claim for a small
// reward. The server checks the same facts before it pays, and remembers claimed ids in
// Flags.FirstGoals. Settings.FirstGoals = 0 hides the path (skip); turning it back on resumes it
// at the first unclaimed goal. Add new goals at the end so saved progress keeps its meaning.

export interface GoalFacts {
	machinesBought: number;
	researchBought: number;
	cratesOpened: number;
	level: number;
	rebirths: number;
	rebirthReady: boolean;
	/** added after launch; older callers may leave it out */
	itemsSalvaged?: number;
}

export interface FirstGoal {
	id: string;
	title: string;
	line: string;
	/** Overview card button while the goal is open */
	cta: string;
	/** page the button opens */
	page: string;
	/** level that opens `page`, so a locked goal can say when it opens */
	pageLevel: number;
	need: number;
	have: (facts: GoalFacts) => number;
	rewardFlux: number;
	rewardKeys?: { crate: string; count: number };
}

export const GOALS: ReadonlyArray<FirstGoal> = table.freeze([
	{
		id: "machines",
		title: "Buy 5 machine levels",
		line: "More levels, more Flux every second. Collect first if you're short.",
		cta: "Open Workshop",
		page: "Workshop",
		pageLevel: 1,
		need: 5,
		have: (facts: GoalFacts) => facts.machinesBought,
		rewardFlux: 150,
	},
	{
		id: "research",
		title: "Buy your first research",
		line: "Research bonuses stay with you forever, even after a rebirth.",
		cta: "Open Research",
		page: "Research",
		pageLevel: 2,
		need: 1,
		have: (facts: GoalFacts) => facts.researchBought,
		rewardFlux: 250,
	},
	{
		id: "crate",
		title: "Open your free crate",
		line: "You start with two Forge Crate keys. Crates drop relics that boost your forge.",
		cta: "Open Inventory",
		page: "Inventory",
		pageLevel: 3,
		need: 1,
		have: (facts: GoalFacts) => facts.cratesOpened,
		rewardFlux: 300,
		rewardKeys: { crate: "ForgeCrate", count: 1 },
	},
	{
		id: "level",
		title: "Reach level 5",
		line: "Each level opens more of the forge. Keep buying and collecting.",
		cta: "Build production",
		page: "Workshop",
		pageLevel: 1,
		need: 5,
		have: (facts: GoalFacts) => facts.level,
		rewardFlux: 500,
	},
	{
		id: "rebirth",
		title: "Get a rebirth ready",
		line: "Earn enough this run to be worth a Core. Rebirth trades machines for a permanent boost.",
		cta: "Build production",
		page: "Workshop",
		pageLevel: 1,
		need: 1,
		have: (facts: GoalFacts) => (facts.rebirthReady || facts.rebirths > 0 ? 1 : 0),
		rewardFlux: 1000,
	},
	{
		id: "salvage",
		title: "Salvage a spare relic",
		line: "Duplicates melt into Flux. Keep the best, salvage the rest.",
		cta: "Open Inventory",
		page: "Inventory",
		pageLevel: 3,
		need: 1,
		have: (facts: GoalFacts) => facts.itemsSalvaged ?? 0,
		rewardFlux: 1500,
	},
	{
		id: "firstRebirth",
		title: "Rebirth once",
		line: "Your machines reset, your Cores stay. The next run is faster.",
		cta: "Open Rebirth",
		page: "Rebirth",
		pageLevel: 10,
		need: 1,
		have: (facts: GoalFacts) => facts.rebirths,
		rewardFlux: 5000,
		rewardKeys: { crate: "ForgeCrate", count: 2 },
	},
]);

const BY_ID = new Map<string, FirstGoal>();
for (const goal of GOALS) {
	BY_ID.set(goal.id, goal);
}

export function isGoalId(id: unknown): id is string {
	return typeIs(id, "string") && BY_ID.has(id);
}

export function goalById(id: string): FirstGoal | undefined {
	return BY_ID.get(id);
}

/** Known goal ids only, no repeats. */
export function normalizeClaimed(raw: unknown): string[] {
	const claimed = new Array<string>();
	if (!typeIs(raw, "table")) {
		return claimed;
	}
	for (const id of raw as unknown[]) {
		if (claimed.size() >= GOALS.size()) {
			break;
		}
		if (isGoalId(id) && !claimed.includes(id)) {
			claimed.push(id);
		}
	}
	return claimed;
}

/** The first goal not yet claimed, and its 1-based position; undefined once the path is done. */
export function currentGoal(claimed: ReadonlyArray<string>): LuaTuple<[FirstGoal | undefined, number]> {
	for (const [index, goal] of ipairs(GOALS)) {
		if (!claimed.includes(goal.id)) {
			return $tuple(goal, index);
		}
	}
	return $tuple(undefined, GOALS.size() + 1);
}

export function progressOf(goal: FirstGoal, facts: GoalFacts): LuaTuple<[number, boolean]> {
	const have = math.max(0, math.floor(goal.have(facts)));
	return $tuple(math.min(have, goal.need), have >= goal.need);
}

/** Onboarding funnel step for analytics: the tour logs 1-16, first goals continue from 17. */
export const FUNNEL_FIRST_STEP = 17;
