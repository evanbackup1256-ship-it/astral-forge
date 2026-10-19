interface Goal {
	Kind: string;
	Target: number;
	Text: string;
}

interface LevelDef {
	Level: number;
	Tier: string;
	Goal?: Goal;
	Unlocks: string[];
}

interface NextStep {
	Level: number;
	Tier: string;
	Text: string;
	Kind: string;
	Progress: number;
	Target: number;
	Unlocks: string[];
}

interface Snapshot {
	Level: number;
	Tier: string;
	Max: number;
	Next?: NextStep;
}

const LIFETIME_KINDS = table.freeze({
	LifetimeCash: true,
	MachinesBought: true,
	Rebirths: true,
	Domain: true,
}) as Record<string, boolean>;

const TIERS = ["Beginner", "Apprentice", "Journeyman", "Expert", "Master", "Legend"];

const TIER_BLURBS: Record<string, string> = {
	Beginner: "Learn the basics: collect flux, buy machines, research.",
	Apprentice: "Grow your forge and open new ways to earn.",
	Journeyman: "Build up to your first rebirth.",
	Expert: "Rebirth again to grow stronger every run.",
	Master: "Expand your domain and bend reality.",
	Legend: "The very top of the forge.",
};

const LADDER: LevelDef[] = [
	{ Level: 1, Tier: "Beginner", Goal: undefined, Unlocks: ["Overview", "Workshop", "Chat", "Settings", "Trade"] },
	{
		Level: 2,
		Tier: "Beginner",
		Goal: { Kind: "LifetimeCash", Target: 100, Text: "Earn 100 flux in total" },
		Unlocks: ["Research"],
	},
	{
		Level: 3,
		Tier: "Beginner",
		Goal: { Kind: "LifetimeCash", Target: 250, Text: "Earn 250 flux in total" },
		Unlocks: ["Mail", "Wheel", "Inventory"],
	},
	{
		Level: 4,
		Tier: "Beginner",
		Goal: { Kind: "LifetimeCash", Target: 500, Text: "Earn 500 flux in total" },
		Unlocks: ["Rewards", "Boosts"],
	},
	{
		Level: 5,
		Tier: "Apprentice",
		Goal: { Kind: "MachinesBought", Target: 5, Text: "Buy 5 machine levels" },
		Unlocks: ["Story", "ForgePath"],
	},
	{
		Level: 6,
		Tier: "Apprentice",
		Goal: { Kind: "LifetimeCash", Target: 1_000, Text: "Earn 1K flux in total" },
		Unlocks: ["Missions", "Leaderboards", "Guild"],
	},
	{
		Level: 7,
		Tier: "Apprentice",
		Goal: { Kind: "LifetimeCash", Target: 2_500, Text: "Earn 2.5K flux in total" },
		Unlocks: ["Worlds", "Shop"],
	},
	{
		Level: 8,
		Tier: "Apprentice",
		Goal: { Kind: "LifetimeCash", Target: 5_000, Text: "Earn 5K flux in total" },
		Unlocks: ["StarGrid", "Credits"],
	},
	{
		Level: 9,
		Tier: "Journeyman",
		Goal: { Kind: "MachinesBought", Target: 15, Text: "Buy 15 machine levels" },
		Unlocks: ["Milestones"],
	},
	{
		Level: 10,
		Tier: "Journeyman",
		Goal: { Kind: "LifetimeCash", Target: 75_000, Text: "Earn 75K flux in total" },
		Unlocks: ["Rebirth", "Bazaar"],
	},
	{
		Level: 11,
		Tier: "Journeyman",
		Goal: { Kind: "Rebirths", Target: 1, Text: "Complete your first rebirth" },
		Unlocks: ["Anomaly", "Command", "Crew"],
	},
	{
		Level: 12,
		Tier: "Expert",
		Goal: { Kind: "Rebirths", Target: 2, Text: "Complete 2 rebirths" },
		Unlocks: ["Lab"],
	},
	{
		Level: 13,
		Tier: "Expert",
		Goal: { Kind: "Rebirths", Target: 3, Text: "Complete 3 rebirths" },
		Unlocks: ["Echoes", "Convergence"],
	},
	{
		Level: 14,
		Tier: "Expert",
		Goal: { Kind: "Rebirths", Target: 5, Text: "Complete 5 rebirths" },
		Unlocks: ["Continuum"],
	},
	{
		Level: 15,
		Tier: "Master",
		Goal: { Kind: "Rebirths", Target: 10, Text: "Complete 10 rebirths" },
		Unlocks: ["Domain"],
	},
	{
		Level: 16,
		Tier: "Master",
		Goal: { Kind: "Domain", Target: 1, Text: "Expand your domain" },
		Unlocks: [],
	},
	{
		Level: 17,
		Tier: "Master",
		Goal: { Kind: "Domain", Target: 3, Text: "Reach domain rank 3" },
		Unlocks: [],
	},
	{
		Level: 18,
		Tier: "Legend",
		Goal: { Kind: "Domain", Target: 10, Text: "Reach domain rank 10" },
		Unlocks: ["Ascension"],
	},
];

for (const def of LADDER) {
	table.freeze(def.Unlocks);
	if (def.Goal !== undefined) {
		table.freeze(def.Goal);
	}
	table.freeze(def);
}
table.freeze(LADDER);
table.freeze(TIERS);
table.freeze(TIER_BLURBS);

function ladder(): LevelDef[] {
	return LADDER;
}

function count(): number {
	return LADDER.size();
}

function get(level: number): LevelDef | undefined {
	return LADDER[level - 1];
}

function tiers(): string[] {
	return TIERS;
}

function tierBlurb(tier: string): string {
	return TIER_BLURBS[tier] ?? "";
}

function tierBlurbs(): Record<string, string> {
	return TIER_BLURBS;
}

function requirementText(level: number): string {
	const def = LADDER[level - 1];
	if (def === undefined) {
		return `Reach Level ${level}`;
	}
	return `Reach Level ${level} (${def.Tier})`;
}

// The milestone that opens a feature (nil for features open from the start). Unlocks are no
// longer shown as levels: each feature names the one goal that opens it.
function goalFor(featureId: string): Goal | undefined {
	for (const def of LADDER) {
		for (const id of def.Unlocks) {
			if (id === featureId) {
				return def.Goal;
			}
		}
	}
	return undefined;
}

function unlockLevels(): Record<string, number> {
	const result: Record<string, number> = {};
	for (const def of LADDER) {
		for (const featureId of def.Unlocks) {
			result[featureId] = def.Level;
		}
	}
	return result;
}

function levelFor(progressOf: (kind: string) => unknown): number {
	const cache: Record<string, number> = {};
	let level = 1;
	for (const def of LADDER) {
		const goal = def.Goal;
		if (goal === undefined) {
			continue;
		}
		let progress = cache[goal.Kind];
		if (progress === undefined) {
			const read = progressOf(goal.Kind);
			progress = typeIs(read, "number") && read === read ? math.max(0, read) : 0;
			cache[goal.Kind] = progress;
		}
		if (progress >= goal.Target) {
			level = def.Level;
		}
	}
	return level;
}

function snapshot(progressOf: (kind: string) => unknown): Snapshot {
	const level = levelFor(progressOf);
	const current = LADDER[level - 1];
	const nextDef = LADDER[level];
	let nextStep: NextStep | undefined;
	if (nextDef !== undefined && nextDef.Goal !== undefined) {
		const goal = nextDef.Goal;
		const read = progressOf(goal.Kind);
		const progress = typeIs(read, "number") && read === read ? math.max(0, read) : 0;
		nextStep = {
			Level: nextDef.Level,
			Tier: nextDef.Tier,
			Text: goal.Text,
			Kind: goal.Kind,
			Progress: math.clamp(progress, 0, goal.Target),
			Target: goal.Target,
			Unlocks: table.clone(nextDef.Unlocks),
		};
	}
	return {
		Level: level,
		Tier: current.Tier,
		Max: LADDER.size(),
		Next: nextStep,
	};
}

export = table.freeze({
	LIFETIME_KINDS,
	ladder,
	count,
	get,
	tiers,
	tierBlurb,
	tierBlurbs,
	requirementText,
	goalFor,
	unlockLevels,
	levelFor,
	snapshot,
});
