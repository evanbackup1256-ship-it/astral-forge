interface BigMath {
	Gte(this: void, a: unknown, b: unknown): boolean;
	Gt(this: void, a: unknown, b: unknown): boolean;
	ToNumber(this: void, value: unknown): number;
	Div(this: void, a: unknown, b: unknown): unknown;
}

interface FeatureLock {
	Unlocked?: unknown;
	Name?: unknown;
}

interface GoalState {
	Rebirths?: number;
	Level?: {
		Level?: number;
		Next?: unknown;
	};
	FeatureUnlocks?: Record<string, FeatureLock | undefined>;
	Domain?: { CanExpand?: unknown };
	PrestigeReward?: unknown;
	[key: string]: unknown;
}

interface NextLevel {
	Text: string;
	Target?: unknown;
	Progress?: unknown;
	Kind?: unknown;
	Unlocks?: unknown;
}

interface Ready {
	missions: number;
	lab: number;
	path?: unknown;
}

interface Goal {
	title: string;
	body: string;
	page?: string;
	cta?: string;
	value: string;
	label: string;
	progress: number;
}

export = (Math: BigMath, compact: (value: unknown) => string) => {
	return (state: GoalState, ready: Ready): Goal | undefined => {
		// Keep the guided first run, then prioritize actionable progression.
		if ((state.Rebirths ?? 0) < 1 && (!state.Level || (state.Level.Level ?? 1) < 5)) {
			return undefined;
		}
		const unlocked = (page: string) => {
			const gate = state.FeatureUnlocks && state.FeatureUnlocks[page];
			return gate === undefined || gate.Unlocked !== false;
		};
		const rewards: Array<[string, number, string]> = [
			["Missions", ready.missions, "mission rewards"],
			["Lab", ready.lab, "Lab rewards"],
			["ForgePath", ready.path !== undefined && ready.path !== false ? 1 : 0, "Forge Path reward"],
		];
		for (const reward of rewards) {
			if (reward[1] > 0 && unlocked(reward[0])) {
				return {
					title: `Claim your ${reward[2]}`,
					body: `${reward[1]} ready to collect.`,
					page: reward[0],
					cta: "Open " + (reward[0] === "ForgePath" ? "Forge Path" : reward[0]),
					value: tostring(reward[1]),
					label: "Rewards ready",
					progress: 1,
				};
			}
		}
		if (state.Domain && state.Domain.CanExpand !== undefined && state.Domain.CanExpand !== false) {
			return {
				title: "Your next Domain is ready",
				body: "Review the reset and permanent bonuses before expanding your Domain.",
				page: "Domain",
				cta: "Review Domain",
				value: "Ready",
				label: "Domain expansion",
				progress: 1,
			};
		}
		if (Math.Gte(state.PrestigeReward ?? 0, 1) && unlocked("Rebirth")) {
			return {
				title: "Rebirth rewards are ready",
				body: `Review the panel below to reset machines and collect ${compact(state.PrestigeReward)} Cores. Research stays permanent.`,
				value: "+" + compact(state.PrestigeReward),
				label: "Cores ready",
				progress: 1,
			};
		}
		const rawNext = state.Level && state.Level.Next;
		if (typeIs(rawNext, "table") && typeIs((rawNext as NextLevel).Text, "string")) {
			const nextLevel = rawNext as NextLevel;
			const progress = Math.Gt(nextLevel.Target ?? 0, 0)
				? math.clamp(Math.ToNumber(Math.Div(nextLevel.Progress ?? 0, nextLevel.Target)), 0, 1)
				: 0;
			const page =
				nextLevel.Kind === "Domain" ? "Domain" : nextLevel.Kind === "Rebirths" ? undefined : "Workshop";
			const names: string[] = [];
			const unlocks = typeIs(nextLevel.Unlocks, "table") ? (nextLevel.Unlocks as string[]) : [];
			for (const id of unlocks) {
				const lock = state.FeatureUnlocks && state.FeatureUnlocks[id];
				names.push(lock && typeIs(lock.Name, "string") ? lock.Name : id);
			}
			const opens = names.size() > 0 ? names.join(" and ") : undefined;
			return {
				title: opens !== undefined ? `Unlock ${opens}` : nextLevel.Text,
				body: `${nextLevel.Text} · ${compact(nextLevel.Progress ?? 0)} / ${compact(nextLevel.Target ?? 0)}`,
				page,
				cta: page === "Domain" ? "Review Domain" : page !== undefined ? "Build production" : undefined,
				value: `${math.floor(progress * 100)}%`,
				label: "Next unlock",
				progress,
			};
		}
		return {
			title: "Buy more machines",
			body: "Upgrade your best machine to raise production. Research stays through rebirths.",
			page: "Workshop",
			cta: "Compare machines",
			value: "Next",
			label: "Production",
			progress: 0,
		};
	};
};
