interface CommandBag {
	XP: number;
	Signals: number;
	StreakShields: number;
	ExpeditionsCompleted: number;
	ActiveExpedition: { Id: string; StartedAt: number; EndsAt: number };
	Artifacts: Record<string, unknown>;
	EquippedArtifact: string;
	Crew: Record<string, number>;
	CommanderClaims: Record<string, boolean>;
	SeasonId: string;
	SeasonXP: number;
	SeasonClaims: Record<string, boolean>;
	Weekly: { Week: number; Baseline: Record<string, number>; Claimed: Record<string, boolean> };
	Shop: { Day: number; Purchased: Record<string, boolean> };
	EquippedTitle: string;
	MachineMastery: Record<string, number>;
}

const DEFAULT_CREW = { Pilot: 1, Engineer: 1, Navigator: 1 };
const DEFAULT_SEASON = "DEEP_SPACE_01";

const CommandMath = {
	Ensure(this: void, command: unknown, seasonId?: string): CommandBag {
		const season = typeIs(seasonId, "string") && seasonId !== "" ? seasonId : DEFAULT_SEASON;
		if (!typeIs(command, "table")) {
			return {
				XP: 0,
				Signals: 0,
				StreakShields: 0,
				ExpeditionsCompleted: 0,
				ActiveExpedition: { Id: "", StartedAt: 0, EndsAt: 0 },
				Artifacts: {},
				EquippedArtifact: "",
				Crew: table.clone(DEFAULT_CREW) as Record<string, number>,
				CommanderClaims: {},
				SeasonId: season,
				SeasonXP: 0,
				SeasonClaims: {},
				Weekly: { Week: -1, Baseline: {}, Claimed: {} },
				Shop: { Day: -1, Purchased: {} },
				EquippedTitle: "Cadet",
				MachineMastery: {},
			};
		}
		const bag = command as CommandBag;
		bag.XP = math.max(0, math.floor(tonumber(bag.XP) ?? 0));
		bag.Signals = math.max(0, math.floor(tonumber(bag.Signals) ?? 0));
		bag.StreakShields = math.max(0, math.floor(tonumber(bag.StreakShields) ?? 0));
		bag.ExpeditionsCompleted = math.max(0, math.floor(tonumber(bag.ExpeditionsCompleted) ?? 0));
		bag.SeasonXP = math.max(0, math.floor(tonumber(bag.SeasonXP) ?? 0));
		if (!typeIs(bag.SeasonId, "string") || bag.SeasonId === "") {
			bag.SeasonId = season;
		}
		if (!typeIs(bag.EquippedArtifact, "string")) {
			bag.EquippedArtifact = "";
		}
		if (!typeIs(bag.EquippedTitle, "string") || bag.EquippedTitle === "") {
			bag.EquippedTitle = "Cadet";
		}
		if (!typeIs(bag.ActiveExpedition, "table")) {
			bag.ActiveExpedition = { Id: "", StartedAt: 0, EndsAt: 0 };
		} else {
			bag.ActiveExpedition.Id = typeIs(bag.ActiveExpedition.Id, "string")
				? bag.ActiveExpedition.Id
				: "";
			bag.ActiveExpedition.StartedAt = math.max(
				0,
				math.floor(tonumber(bag.ActiveExpedition.StartedAt) ?? 0),
			);
			bag.ActiveExpedition.EndsAt = math.max(
				0,
				math.floor(tonumber(bag.ActiveExpedition.EndsAt) ?? 0),
			);
		}
		if (!typeIs(bag.Artifacts, "table")) {
			bag.Artifacts = {};
		}
		if (!typeIs(bag.Crew, "table")) {
			bag.Crew = table.clone(DEFAULT_CREW) as Record<string, number>;
		} else {
			for (const [role, floor] of pairs(DEFAULT_CREW)) {
				bag.Crew[role] = math.max(floor, math.floor(tonumber(bag.Crew[role]) ?? floor));
			}
		}
		if (!typeIs(bag.CommanderClaims, "table")) {
			bag.CommanderClaims = {};
		}
		if (!typeIs(bag.SeasonClaims, "table")) {
			bag.SeasonClaims = {};
		}
		if (!typeIs(bag.Weekly, "table")) {
			bag.Weekly = { Week: -1, Baseline: {}, Claimed: {} };
		} else {
			bag.Weekly.Week = math.floor(tonumber(bag.Weekly.Week) ?? -1);
			if (!typeIs(bag.Weekly.Baseline, "table")) {
				bag.Weekly.Baseline = {};
			}
			if (!typeIs(bag.Weekly.Claimed, "table")) {
				bag.Weekly.Claimed = {};
			}
		}
		if (!typeIs(bag.Shop, "table")) {
			bag.Shop = { Day: -1, Purchased: {} };
		} else {
			bag.Shop.Day = math.floor(tonumber(bag.Shop.Day) ?? -1);
			if (!typeIs(bag.Shop.Purchased, "table")) {
				bag.Shop.Purchased = {};
			}
		}
		if (!typeIs(bag.MachineMastery, "table")) {
			bag.MachineMastery = {};
		}
		return bag;
	},

	Level(this: void, xp: unknown, maxLevel: number): number {
		const safeMax = math.max(1, math.floor(tonumber(maxLevel) ?? 1));
		return math.clamp(math.floor(math.sqrt(math.max(0, tonumber(xp) ?? 0) / 100)) + 1, 1, safeMax);
	},

	FloorXP(this: void, level: unknown): number {
		const safeLevel = math.max(1, math.floor(tonumber(level) ?? 1));
		return 100 * math.max(0, safeLevel - 1) ** 2;
	},

	NextXP(this: void, level: unknown, maxLevel: number): number {
		const safeLevel = math.max(1, math.floor(tonumber(level) ?? 1));
		const safeMax = math.max(1, math.floor(tonumber(maxLevel) ?? 1));
		if (safeLevel >= safeMax) {
			return CommandMath.FloorXP(safeLevel);
		}
		return 100 * safeLevel ** 2;
	},

	Rank(this: void, level: unknown): string {
		const safeLevel = math.max(1, math.floor(tonumber(level) ?? 1));
		if (safeLevel >= 60) {
			return "TIMELESS COMMANDER";
		} else if (safeLevel >= 50) {
			return "VOID MARSHAL";
		} else if (safeLevel >= 40) {
			return "FLEET DIRECTOR";
		} else if (safeLevel >= 30) {
			return "SECTOR ADMIRAL";
		} else if (safeLevel >= 20) {
			return "EXPEDITION CAPTAIN";
		} else if (safeLevel >= 10) {
			return "STAR OFFICER";
		} else if (safeLevel >= 5) {
			return "FLIGHT SPECIALIST";
		}
		return "FORGE CADET";
	},
};

export = table.freeze(CommandMath);
