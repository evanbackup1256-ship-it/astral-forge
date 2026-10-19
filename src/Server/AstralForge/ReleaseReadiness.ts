const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");

const DataTemplate = require(script.Parent!.FindFirstChild("DataTemplate")! as ModuleScript) as {
	New(): Record<string, unknown>;
};
const Economy = require(
	script.Parent!.WaitForChild("Modules").WaitForChild("EconomyMath") as ModuleScript,
) as unknown as {
	Production(this: void, profile: Record<string, unknown>): number | string;
	Capacity(this: void, profile: Record<string, unknown>): number | string;
	TapPower(this: void, profile: Record<string, unknown>): number | string;
	MachineCost(this: void, id: string, level: number): number | string;
	ResearchCost(this: void, id: string, level: number): number | string;
	ContinuumCosts(this: void, rank: number): LuaTuple<[number | string, number | string]>;
	DomainRequirements(this: void, rank: number): LuaTuple<[number | string, number | string]>;
	DomainRewards(this: void, rank: number): LuaTuple<[number | string, number | string]>;
	PrestigeReward(this: void, runCash: number | string): number | string;
	Max(this: void, a: number | string, b: number | string): number | string;
};
const ProfileIntegrity = (
	require(script.Parent!.WaitForChild("Services").WaitForChild("ServerServices") as ModuleScript) as {
		ProfileIntegrity: unknown;
	}
).ProfileIntegrity as {
	Record(this: void, profile: Record<string, unknown>, label: string, revision: number): void;
	Seal(this: void, profile: Record<string, unknown>): void;
	VerifyAndRecover(this: void, profile: Record<string, unknown>): boolean;
};
const GameConfig = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("GameConfig") as ModuleScript,
) as unknown as Record<string, unknown>;
const OmegaMath = require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript) as {
	Gte(this: void, a: unknown, b: unknown): boolean;
	Max(this: void, a: unknown, b: unknown): unknown;
	Min(this: void, a: unknown, b: unknown): unknown;
	Add(this: void, a: unknown, b: unknown): unknown;
	Sub(this: void, a: unknown, b: unknown): unknown;
	Mul(this: void, a: unknown, b: unknown): unknown;
};

const ReleaseReadiness = {
	RunQuick(this: void): Record<string, unknown> {
		const startedAt = os.clock();
		const checks = quickChecks();
		const profile = DataTemplate.New();
		const random = new Random(0xa57a1);
		for (const iteration of $range(1, 50_000)) {
			simulationStep(profile, random);
			if (iteration % 1_000 === 0) {
				validateProfile(profile);
				task.wait();
			}
		}
		ProfileIntegrity.Record(profile, "quick-soak", (profile.Meta as Record<string, unknown>).Revision as number);
		ProfileIntegrity.Seal(profile);
		validateProfile(profile);
		checks.push("50,000-action deterministic economy soak");
		return {
			Ok: true,
			Checks: checks,
			Iterations: 50_000,
			ElapsedSeconds: os.clock() - startedAt,
		};
	},

	RunSoak(this: void, minutes?: number): Record<string, unknown> {
		expect(RunService.IsStudio(), "long release soaks are Studio-only");
		const duration = math.clamp(minutes ?? 30, 1, 60) * 60;
		const startedAt = os.clock();
		const deadline = startedAt + duration;
		const checks = quickChecks();
		const profile = DataTemplate.New();
		const random = new Random(0xf047e);
		let iterations = 0;
		while (os.clock() < deadline) {
			for (const _ of $range(1, 500)) {
				simulationStep(profile, random);
				iterations += 1;
			}
			validateProfile(profile);
			ProfileIntegrity.Record(profile, "soak-checkpoint", iterations);
			ProfileIntegrity.Seal(profile);
			task.wait();
		}
		checks.push(string.format("%.0f-minute economy and integrity soak", duration / 60));
		return {
			Ok: true,
			Checks: checks,
			Iterations: iterations,
			ElapsedSeconds: os.clock() - startedAt,
		};
	},
};

const MAX_VALUE = 1e308;

function expect(condition: boolean, message: string): void {
	if (!condition) {
		error(message, 2);
	}
}

function finite(value: unknown): boolean {
	if (typeIs(value, "string")) {
		const [mantissa, exponent] = string.match(value, "^([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)$");
		const m = tonumber(mantissa);
		const e = tonumber(exponent);
		return (
			m !== undefined &&
			e !== undefined &&
			m === m &&
			e === e &&
			math.abs(m) < math.huge &&
			math.abs(e) < 1e18
		);
	}
	return (
		typeIs(value, "number") &&
		value === value &&
		value !== math.huge &&
		value !== -math.huge &&
		math.abs(value) <= 1.7976931348623157e308
	);
}

function uniqueIds(list: unknown[], label: string): void {
	const seen: Record<string, number> = {};
	for (const [index, item] of ipairs(list)) {
		const id = typeIs(item, "table") ? (item as Record<string, unknown>).Id : undefined;
		expect(
			(typeIs(id, "string") && id !== "") || (typeIs(id, "number") && id === math.floor(id)),
			label + " has an invalid Id",
		);
		const key = tostring(id as string | number);
		expect(!seen[key], string.format("%s contains duplicate Id %s", label, key));
		seen[key] = index;
	}
}

function idSet(list: unknown[]): Record<string, boolean> {
	const result: Record<string, boolean> = {};
	for (const item of list) {
		if (typeIs(item, "table")) {
			const id = (item as Record<string, unknown>).Id;
			if (typeIs(id, "string")) {
				result[id] = true;
			}
		}
	}
	return result;
}

function validateProfile(profile: Record<string, unknown>): void {
	for (const key of ["Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash"]) {
		expect(finite(profile[key]) && OmegaMath.Gte(profile[key], 0), key + " left its finite persistence envelope");
	}
	expect(finite(Economy.Production(profile)), "production is not finite");
	expect(finite(Economy.Capacity(profile)), "capacity is not finite");
	expect(finite(Economy.TapPower(profile)), "tap power is not finite");
}

function quickChecks(): string[] {
	const checks: string[] = [];
	function passed(name: string): void {
		checks.push(name);
	}

	const gameConfigGame = GameConfig.Game as Record<string, unknown>;
	expect(typeIs(gameConfigGame.Version, "string") && gameConfigGame.Version !== "", "game version is missing");
	expect(typeIs(gameConfigGame.DataVersion, "number") && gameConfigGame.DataVersion >= 1, "data version is invalid");
	passed("version and data schema");

	uniqueIds(GameConfig.Machines as unknown[], "machines");
	uniqueIds(GameConfig.Research as unknown[], "research");
	uniqueIds(GameConfig.GridUpgrades as unknown[], "star grid");
	uniqueIds(GameConfig.Zones as unknown[], "worlds");
	uniqueIds((GameConfig.Items as Record<string, unknown>).Definitions as unknown[], "relic definitions");
	uniqueIds((GameConfig.Items as Record<string, unknown>).Crates as unknown[], "crates");
	uniqueIds((GameConfig.Operations as Record<string, unknown>).Artifacts as unknown[], "artifacts");
	uniqueIds((GameConfig.Operations as Record<string, unknown>).Expeditions as unknown[], "expeditions");
	uniqueIds((GameConfig.Operations as Record<string, unknown>).WeeklyDirectives as unknown[], "weekly directives");
	passed("configuration identity");

	const machineIds = idSet(GameConfig.Machines as unknown[]);
	const researchIds = idSet(GameConfig.Research as unknown[]);
	const gridIds = idSet(GameConfig.GridUpgrades as unknown[]);
	const artifactIds = idSet((GameConfig.Operations as Record<string, unknown>).Artifacts as unknown[]);
	const crateIds = idSet((GameConfig.Items as Record<string, unknown>).Crates as unknown[]);
	for (const machine of GameConfig.Machines as Array<Record<string, unknown>>) {
		if (machine.PreviousId) {
			expect(machineIds[tostring(machine.PreviousId)] === true, machine.Id + " references a missing machine prerequisite");
		}
	}
	for (const research of GameConfig.Research as Array<Record<string, unknown>>) {
		if (research.PreviousId) {
			expect(researchIds[tostring(research.PreviousId)] === true, research.Id + " references a missing research prerequisite");
		}
	}
	for (const node of GameConfig.GridUpgrades as Array<Record<string, unknown>>) {
		if (node.PreviousId) {
			expect(gridIds[tostring(node.PreviousId)] === true, node.Id + " references a missing Star Grid prerequisite");
		}
	}
	for (const expedition of (GameConfig.Operations as Record<string, unknown>).Expeditions as Array<Record<string, unknown>>) {
		expect(artifactIds[tostring(expedition.ArtifactId)] === true, expedition.Id + " references a missing artifact");
	}
	for (const offer of (GameConfig.Items as Record<string, unknown>).ShopOffers as Array<Record<string, unknown>>) {
		if (offer.CrateId) {
			expect(crateIds[tostring(offer.CrateId)] === true, offer.Id + " references a missing crate");
		}
	}
	const seen: Map<object, boolean> = new Map();
	function validateRewards(value: unknown, path: string): void {
		if (!typeIs(value, "table") || seen.get(value as object)) {
			return;
		}
		seen.set(value as object, true);
		const valueTable = value as Record<string, unknown>;
		if (typeIs(valueTable.Boost, "string")) {
			expect((GameConfig.Boosts as Record<string, unknown>)[valueTable.Boost as string] !== undefined, path + " references a missing boost " + valueTable.Boost);
		}
		if (typeIs(valueTable.Keys, "table")) {
			for (const crateId of pairs(valueTable.Keys as object)) {
				expect(crateIds[tostring(crateId)] === true, path + " references a missing crate key " + tostring(crateId));
			}
		}
		for (const [childKey, child] of pairs(value as object)) {
			if (typeIs(child, "table")) {
				validateRewards(child, path + "." + tostring(childKey));
			}
		}
	}
	validateRewards(GameConfig, "GameConfig");
	passed("configuration references");

	const profile = DataTemplate.New();
	validateProfile(profile);
	for (const machine of GameConfig.Machines as Array<Record<string, unknown>>) {
		let previous: number | string = 0;
		for (const level of [0, 1, 10, 100, 10_000, machine.MaxLevel as number]) {
			const cost = Economy.MachineCost(machine.Id as string, level);
			expect(finite(cost) && OmegaMath.Gte(cost, previous), machine.Id + " machine cost is invalid or regressed");
			previous = cost;
		}
	}
	for (const research of GameConfig.Research as Array<Record<string, unknown>>) {
		let previous: number | string = 0;
		for (const level of [0, 1, 10, 100, 10_000, research.MaxLevel as number]) {
			const cost = Economy.ResearchCost(research.Id as string, level);
			expect(finite(cost) && OmegaMath.Gte(cost, previous), research.Id + " research cost is invalid or regressed");
			previous = cost;
		}
	}
	for (const rank of [0, 1, 10, 100, 10_000, 9_000_000_000_000_000]) {
		const [flux, stardust] = Economy.ContinuumCosts(rank);
		const [rebirths, cores] = Economy.DomainRequirements(rank);
		const [essence, domainDust] = Economy.DomainRewards(rank);
		expect(finite(flux) && finite(stardust), "Continuum cost overflow");
		expect(finite(rebirths) && finite(cores), "Domain requirement overflow");
		expect(finite(essence) && finite(domainDust), "Domain reward overflow");
	}
	passed("endless economy envelope");

	ProfileIntegrity.Record(profile, "release-test", 0);
	ProfileIntegrity.Seal(profile);
	const expectedCash = profile.Cash;
	profile.Cash = math.huge;
	const healthy = ProfileIntegrity.VerifyAndRecover(profile);
	expect(!healthy && profile.Cash === expectedCash, "integrity journal did not recover the last known-good state");
	const malformed = DataTemplate.New();
	let branch: Record<string, unknown> = {};
	malformed.UnknownMigrationBranch = branch;
	for (const _ of $range(1, 24)) {
		const child: Record<string, unknown> = {};
		branch.Next = child;
		branch = child;
	}
	const [verifyOk, malformedHealthy] = pcall(() => ProfileIntegrity.VerifyAndRecover(malformed));
	expect(verifyOk && !malformedHealthy, "malformed profile verification escaped its recovery boundary");
	passed("profile corruption recovery");

	return checks;
}

function simulationStep(profile: Record<string, unknown>, random: Random): void {
	const machines = GameConfig.Machines as Array<Record<string, unknown>>;
	const machine = machines[random.NextInteger(1, machines.size()) - 1];
	const machineId = machine.Id as string;
	const machineMachines = profile.Machines as Record<string, unknown>;
	const current = (machineMachines[machineId] as number) ?? 0;
	const cost = Economy.MachineCost(machineId, current);
	const production = OmegaMath.Max(1, Economy.Production(profile));
	profile.Cash = OmegaMath.Min(MAX_VALUE, OmegaMath.Add(profile.Cash, OmegaMath.Mul(production, random.NextNumber(0.25, 4))));
	profile.RunCash = OmegaMath.Min(MAX_VALUE, OmegaMath.Add(profile.RunCash, production));
	profile.LifetimeCash = OmegaMath.Min(MAX_VALUE, OmegaMath.Add(profile.LifetimeCash, production));
	if (OmegaMath.Gte(profile.Cash, cost) && current < (machine.MaxLevel as number)) {
		profile.Cash = OmegaMath.Sub(profile.Cash, cost);
		machineMachines[machineId] = current + 1;
	}
	if (random.NextNumber() < 0.002) {
		profile.Cores = OmegaMath.Min(MAX_VALUE, OmegaMath.Add(profile.Cores, Economy.PrestigeReward(profile.RunCash as number | string)));
		profile.Rebirths = math.min(MAX_VALUE, (profile.Rebirths as number) + 1);
		profile.Cash = 0;
		profile.RunCash = 0;
	}
}

export = table.freeze(ReleaseReadiness);
