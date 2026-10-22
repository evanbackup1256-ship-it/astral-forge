import { T } from "../../../Shared/AstralForge/Shared/Locale";
import * as OfflineProgress from "../../../Shared/AstralForge/Shared/OfflineProgress";
const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`EconomyMath: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`EconomyMath: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

type Dict = Record<string, unknown>;
type Persist = number | string;

// Luau truthiness: only nil and false are falsy (0 and "" are truthy).
function truthy<T>(value: T): value is Exclude<T, undefined | false> {
	return value !== undefined && (value as unknown) !== false;
}

interface OmegaMathApi {
	Add(this: void, a: unknown, b: unknown): Persist;
	Sub(this: void, a: unknown, b: unknown): Persist;
	Mul(this: void, a: unknown, b: unknown): Persist;
	Div(this: void, a: unknown, b: unknown): Persist;
	Pow(this: void, a: unknown, b: unknown): Persist;
	Floor(this: void, value: unknown): Persist;
	Min(this: void, a: unknown, b: unknown): Persist;
	Max(this: void, a: unknown, b: unknown): Persist;
	Lt(this: void, a: unknown, b: unknown): boolean;
	Lte(this: void, a: unknown, b: unknown): boolean;
	Gt(this: void, a: unknown, b: unknown): boolean;
	Gte(this: void, a: unknown, b: unknown): boolean;
	ToNumber(this: void, value: unknown): number;
	Persist(this: void, value: unknown): Persist;
	Log10(this: void, value: unknown): number;
	ScaledCost(this: void, baseCost: number, costScale: number, level: number): Persist;
	GeometricSum(this: void, baseCost: number, costScale: number, level: number, count: number): Persist;
	AffordableCount(
		this: void,
		baseCost: number,
		costScale: number,
		level: number,
		currency: unknown,
		maximum: number,
	): LuaTuple<[number, Persist]>;
	BoundedPower(this: void, base: unknown, exponent: number): Persist;
}

interface MachineDef {
	Id: string;
	Name?: string;
	BaseProduction: number;
	Growth: number;
	BaseCost: number;
	CostScale: number;
	MaxLevel?: number;
	RequiredZone?: number;
	RequiredRebirths?: number;
	PreviousId?: string;
	PreviousLevel?: number;
	[key: string]: unknown;
}

interface ResearchDef {
	Id: string;
	Name?: string;
	BaseCost: number;
	CostScale: number;
	RequiredZone?: number;
	RequiredRebirths?: number;
	PreviousId?: string;
	PreviousLevel?: number;
	[key: string]: unknown;
}

interface GridUpgradeDef {
	Id: string;
	Name?: string;
	EffectKind?: string;
	EffectPerLevel?: number;
	BaseCost: number;
	CostScale: number;
	RequiredZone?: number;
	RequiredRebirths?: number;
	PreviousId?: string;
	PreviousLevel?: number;
	[key: string]: unknown;
}

interface ZoneDef {
	Id?: number;
	Name?: string;
	Multiplier: number;
	[key: string]: unknown;
}

interface ArtifactDef {
	Id: string;
	Name?: string;
	Element?: string;
	Rarity?: string;
	EffectKind?: string;
	EffectPerLevel?: number;
	[key: string]: unknown;
}

interface ItemDef {
	Id: string;
	Name?: string;
	Rarity?: string;
	EffectKind?: string;
	BaseEffect?: number;
	LevelGrowth?: number;
	Slot?: string;
	Targets?: unknown;
	[key: string]: unknown;
}

interface BoostDef {
	Multiplier?: number;
	CapacityMultiplier?: number;
	[key: string]: unknown;
}

interface UnlockRule {
	Kind: string;
	Target: number;
	GoalKind?: string;
	GoalTarget?: number;
	Requirement?: unknown;
	Name?: string;
	[key: string]: unknown;
}

interface EconomyConfigBag {
	CoreMultiplier: number;
	CoreExponent: number;
	RebirthMultiplier: number;
	BaseCapacitySeconds: number;
	CapacitySecondsPerLevel: number;
	MaxCapacitySeconds: number;
	BaseCapacity: number;
	BaseOfflineHours: number;
	BaseOfflineEfficiency: number;
	PrestigeRequirement: number;
	PrestigeExponent: number;
	[key: string]: unknown;
}

interface DomainConfigBag {
	ProductionPerRank: number;
	ProductionPerEssence: number;
	CapacityPerRank: number;
	OfflineEfficiencyPerRank: number;
	BaseRequiredRebirths: number;
	RebirthsPerRank: number;
	BaseRequiredCores: number;
	CoreRequirementScale: number;
	BaseEssenceReward: number;
	EssencePerRank: number;
	BaseStardustReward: number;
	StardustPerRank: number;
	[key: string]: unknown;
}

interface ContinuumConfigBag {
	BaseFluxCost: number;
	FluxCostScale: number;
	BaseStardustCost: number;
	StardustCostScale: number;
	ProductionScale: number;
	MilestoneEvery: number;
	MilestoneScale: number;
	CapacityScale: number;
	TapScale: number;
	OfflineCap: number;
	OfflinePerRank: number;
	[key: string]: unknown;
}

interface GameConfigApi {
	Machines: MachineDef[];
	Research: ResearchDef[];
	GridUpgrades: GridUpgradeDef[];
	Zones: ZoneDef[];
	Lab: { Power: { Channels: Record<string, { EffectPerCell?: unknown } | undefined> } };
	Operations: { Artifacts: ArtifactDef[] };
	Items: { Definitions: ItemDef[]; CodexBonus: Record<string, number>; InventoryLimit: number };
	Economy: EconomyConfigBag;
	Domain: DomainConfigBag;
	Continuum: ContinuumConfigBag;
	Ore: unknown;
	Boosts: Record<string, BoostDef | undefined>;
	ForgePath: { Steps: StepLikeDef[] };
	Anomalies: { CycleSeconds: number };
	Unlocks: Record<string, UnlockRule | undefined>;
	MaxZone: number;
	ResolveZone(this: void, id: number): ZoneDef | undefined;
	ResolveExpedition(this: void, id: string): unknown;
	[key: string]: unknown;
}

interface StepLikeDef {
	XPCost: number;
	Reward?: unknown;
	EffectKind?: string;
	EffectAmount?: number;
	[key: string]: unknown;
}

interface SpecializationsApi {
	Factor(this: void, raw: unknown, kind: string): number;
}

interface AscensionMathApi {
	sanitize(this: void, raw: unknown, omega: OmegaMathApi): unknown;
	effect(this: void, state: unknown, kind: string, omega: OmegaMathApi): unknown;
}

interface DomainLatticeApi {
	bonus(this: void, links: unknown, kind: string): number;
}

interface EchoMathApi {
	total(this: void, bag: unknown, kind: string): number;
}

interface CapacityProjectionApi {
	SteadyProduction(this: void, omegaMath: OmegaMathApi, rawProduction: unknown, parts: Dict): Persist;
	Seconds(this: void, parts: Dict): number;
	Vault(
		this: void,
		omegaMath: OmegaMathApi,
		baseCapacity: number,
		steadyProduction: unknown,
		seconds: number,
		continuumCapacity: unknown,
	): Persist;
	CapacitySeconds(
		this: void,
		omegaMath: OmegaMathApi,
		capacity: unknown,
		steadyProduction: unknown,
		lte: (this: void, a: unknown, b: unknown) => boolean,
	): number;
}

interface LevelRewardsApi {
	mastery(this: void, level: number): number;
	surgeMultiplier(this: void, surge: unknown, now: number): number;
}

interface MonetizationConfigApi {
	PassBonuses(this: void, owned: Record<string, boolean>): LuaTuple<[number, number]>;
}

interface ForgeLevelsApi {
	levelFor(this: void, progressOf: (this: void, kind: string) => number): number;
	snapshot(this: void, progressOf: (this: void, kind: string) => number): unknown;
}

interface OreMathApi {
	Effect(this: void, levels: unknown, effect: string, config: unknown): number;
}

interface FoundryServiceApi {
	Effects(this: void, profile: unknown, now?: number): LuaTuple<[number, number, number, number]>;
}

interface EconomyEnvelopeMathApi {
	SumNumericLevels(this: void, bag: unknown): number;
	AutoCollectRate(
		this: void,
		automationLevel: number,
		grid: number,
		echo: number,
		artifact: number,
		item: number,
		anomaly: number,
		guild: number,
		forgePath: number,
	): number;
	OfflineHours(this: void, baseHours: number, researchOffline: number, artifactOffline: number, cap?: number): number;
	OfflineEfficiency(
		this: void,
		baseEfficiency: number,
		researchOffline: number,
		grid: number,
		echo: number,
		artifact: number,
		item: number,
		anomaly: number,
		guild: number,
		domainRank: number,
		offlinePerRank: number,
		continuumOffline: number,
		forgePath: number,
	): number;
	MasteryMultiplier(this: void, machineMastery: unknown): number;
	LabPowerEffect(this: void, routing: unknown, channelId: unknown, channel: unknown): number;
	EffectAtLevel(this: void, definition: unknown, level: unknown): number;
	ArtifactLevelEffect(this: void, artifact: unknown, owned: unknown, effectKind: unknown): number;
	GridEffect(this: void, levels: unknown, gridById: unknown, effectKind: unknown): number;
	PermanentMultiplier(
		this: void,
		cores: unknown,
		coreMultiplier: unknown,
		coreExponent: unknown,
		rank: unknown,
		essence: unknown,
		essenceCap: unknown,
		productionPerRank: unknown,
		productionPerEssence: unknown,
		domainTreeBonus: unknown,
		forgePathProduction: unknown,
		rebirths: unknown,
		rebirthMultiplier: unknown,
		forgePathRebirth: unknown,
		insightLevel: unknown,
	): number;
	ItemEffect(
		this: void,
		items: unknown,
		machines: unknown,
		research: unknown,
		effectKind: unknown,
		getDefinition?: (this: void, id: unknown) => unknown,
		slotFilter?: unknown,
		targetFilter?: unknown,
	): number;
	StarMultiplier(this: void, stars: unknown): number;
	CodexBonus(this: void, discovered: unknown, definitions: unknown, bonuses: unknown): number;
}

interface OfflineProjectionApi {
	Project(
		this: void,
		startedAt: number,
		endedAt: number,
		maxSeconds: number,
		minElapsed: number,
		cycleSeconds: number,
		boostEnd: number,
		surgeEnd: number,
		sampleAt: (this: void, sample: number) => { Production: unknown; Efficiency: number },
		add: (this: void, a: unknown, b: unknown) => unknown,
		mul: (this: void, a: unknown, b: unknown) => unknown,
		persist?: (this: void, value: unknown) => unknown,
	): LuaTuple<[unknown, number, number, boolean]>;
	PublicSnapshot(this: void, args: Dict): Dict;
}

interface TapCritProjectionApi {
	TapPower(this: void, omegaMath: OmegaMathApi, production: unknown, overchargeLevel: number, bonuses: Dict): unknown;
	CriticalChance(
		this: void,
		researchCritical: number,
		grid: number,
		echo: number,
		artifact: number,
		item: number,
		anomaly: number,
		forgePath: number,
	): number;
	CriticalMultiplier(this: void, researchCritical: number, researchImpact: number, forgePath: number): number;
}

interface UpgradeCostReasonApi {
	LevelCost(this: void, omegaMath: OmegaMathApi, def: { BaseCost: number; CostScale: number } | undefined, currentLevel: number): Persist;
	BulkCost(this: void, omegaMath: OmegaMathApi, def: { BaseCost: number; CostScale: number } | undefined, currentLevel: number, count: number): Persist;
	AffordableLevels(
		this: void,
		omegaMath: OmegaMathApi,
		def: { BaseCost: number; CostScale: number } | undefined,
		currentLevel: number,
		currency: unknown,
		maximum: number,
	): LuaTuple<[number, Persist]>;
	Evaluate(
		this: void,
		profile: unknown,
		upgrade: unknown,
		levels: unknown,
		zoneNameForIndex: (this: void, index: number) => string | undefined,
		previousNameForId: (this: void, id: string) => string | undefined,
	): string | undefined;
}

interface RebirthGateApi {
	MeetsRequired(this: void, rebirths: number, required?: number): boolean;
	RequirementMessage(this: void, required: number): string;
	PrestigeReward(
		this: void,
		omegaMath: OmegaMathApi,
		runCash: unknown,
		requirement: number,
		exponent: number,
		lt: (this: void, a: unknown, b: unknown) => boolean,
	): unknown;
	CanRebirth(this: void, prestigeReward: unknown, gte: (this: void, a: unknown, b: unknown) => boolean): boolean;
	StardustReward(this: void, coreReward: number, scale: number, minimum: number): number;
	NextPrestigeTarget(this: void, omegaMath: OmegaMathApi, currentReward: unknown, requirement: number, exponent: number): unknown;
}

interface ContinuumDomainMathApi {
	ContinuumCosts(this: void, omegaMath: OmegaMathApi, config: ContinuumConfigBag, rank: number): LuaTuple<[Persist, Persist]>;
	DomainRequirements(this: void, omegaMath: OmegaMathApi, config: DomainConfigBag, rank: number): LuaTuple<[number, number]>;
	DomainRewards(this: void, config: DomainConfigBag, rank: number): LuaTuple<[number, number]>;
	ContinuumEffects(
		this: void,
		omegaMath: OmegaMathApi,
		config: ContinuumConfigBag,
		rank: number,
	): LuaTuple<[Persist, Persist, Persist, number]>;
	DomainProductionMultiplier(
		this: void,
		rank: unknown,
		essence: unknown,
		productionPerRank: unknown,
		productionPerEssence: unknown,
		essenceCap: unknown,
		domainTreeBonus: unknown,
	): number;
	DomainRankBonus(this: void, rank: unknown, perRank: unknown, domainTreeBonus: unknown): number;
	NonNegativeInt(this: void, value: unknown): number;
	SnapshotDomainInts(this: void, domain: unknown): Dict;
	SnapshotDomainPublic(this: void, args: Dict): Dict;
	SnapshotContinuumPublic(this: void, args: Dict): Dict;
}

interface ForgePathClaimApi {
	Ensure(this: void, forgePath: unknown): Dict;
	TryClaim(this: void, forgePath: unknown, rawStep: unknown, steps: StepLikeDef[]): LuaTuple<[boolean, string | undefined, StepLikeDef | undefined]>;
	Effect(this: void, claimedSteps: unknown, steps: unknown, effectKind: string): number;
	XpFromBankedAmount(this: void, amountNumber: number, xpConfig: unknown): number;
}

__defs["Economy"] = () => {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
	const GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as GameConfigApi;
	const OmegaMath = require(shared.WaitForChild("OmegaMath") as ModuleScript) as OmegaMathApi;
	const Specializations = require(shared.WaitForChild("Specializations") as ModuleScript) as SpecializationsApi;
	const AscensionMath = require(shared.WaitForChild("AscensionMath") as ModuleScript) as AscensionMathApi;
	const SharedData = require(shared.WaitForChild("SharedData") as ModuleScript) as (this: void, name: string) => unknown;
	const CapacityProjection = SharedData("CapacityProjection") as CapacityProjectionApi;
	const LevelRewards = SharedData("LevelRewards") as LevelRewardsApi;
	const DomainLattice = require(shared.WaitForChild("DomainLattice") as ModuleScript) as DomainLatticeApi;
	const RelicRigs = require(shared.WaitForChild("RelicRigs") as ModuleScript) as {
		bonus(this: void, profile: unknown, kind: string): number;
	};
	const RelicEngraving = require(shared.WaitForChild("RelicEngraving") as ModuleScript) as {
		bonus(this: void, items: unknown, kind: string): number;
	};
	const Constellations = require(shared.WaitForChild("Constellations") as ModuleScript) as {
		bonus(this: void, profile: unknown, kind: string): number;
	};
	const CompanionRelic = require(shared.WaitForChild("CompanionRelic") as ModuleScript) as {
		bonus(this: void, items: unknown, kind: string): number;
	};
	const OfflineProjection = __load("OfflineProjection") as OfflineProjectionApi;
	const TapCritProjection = __load("TapCritProjection") as TapCritProjectionApi;
	const UpgradeCostReason = __load("UpgradeCostReason") as UpgradeCostReasonApi;
	const RebirthGate = __load("RebirthGate") as RebirthGateApi;
	const ContinuumDomainMath = __load("ContinuumDomainMath") as ContinuumDomainMathApi;
	const ForgePathClaim = __load("ForgePathClaim") as ForgePathClaimApi;
	const EconomyEnvelopeMath = __load("EconomyEnvelopeMath") as EconomyEnvelopeMathApi;
	const EchoMath = require(shared.WaitForChild("EchoMath") as ModuleScript) as EchoMathApi;
	__load("AnomalyOpsMath");
	const OreMath = require(script.Parent!.WaitForChild("OreMath") as ModuleScript) as OreMathApi;

	function bounded(value: unknown): Persist {
		return OmegaMath.Persist(value);
	}

	interface ProfileLike {
		Cash: Persist;
		Vault: Persist;
		Cores: number;
		Stardust: number;
		Rebirths: number;
		Domain?: {
			Rank: number;
			Essence: number;
			Links?: unknown;
			[key: string]: unknown;
		};
		Continuum?: {
			Rank: number;
			TotalFluxSpent: number;
			TotalStardustSpent: number;
		};
		RunCash: Persist;
		Zone: number;
		CurrentZone: number;
		Machines: Record<string, number>;
		Research: Record<string, number>;
		GridUpgrades: Record<string, number>;
		Specialization?: unknown;
		ActiveBoost: { Id: string; EndsAt: number };
		Items?: {
			Inventory: Record<string, { DefinitionId: string; Level: number; AcquiredAt: number }>;
			Equipped: Record<string, string>;
			[key: string]: unknown;
		};
		Command?: {
			EquippedArtifact: string;
			Artifacts: Record<string, { Level: number; Fragments: number }>;
			MachineMastery: Record<string, number>;
			[key: string]: unknown;
		};
		Anomaly?: {
			SurgeEndsAt: number;
			Channel: string;
			Protocols: Record<string, number>;
			Loadout?: string[];
			CoreTier?: number;
			[key: string]: unknown;
		};
		Lab?: {
			Routing: Record<string, number>;
		};
		OwnedPasses?: Record<string, boolean>;
		GuildBonuses?: { Production: number; Capacity: number; Offline: number; Automation: number; Tap: number };
		SocialBoost?: {
			FriendCount: number;
			FriendBonus: number;
			Premium: boolean;
			PremiumBonus: number;
			Multiplier: number;
		};
		ForgeEchoes?: unknown;
		ForgePath?: {
			ClaimedSteps: Record<string, boolean>;
			XP: number;
		};
		[key: string]: unknown;
	}

	const Economy = {
		Add(this: void, left: unknown, right: unknown): Persist {
			return OmegaMath.Add(left, right);
		},

		Sub(this: void, left: unknown, right: unknown): Persist {
			return OmegaMath.Sub(left, right);
		},

		Mul(this: void, left: unknown, right: unknown): Persist {
			return OmegaMath.Mul(left, right);
		},

		Lt(this: void, left: unknown, right: unknown): boolean {
			return OmegaMath.Lt(left, right);
		},

		Lte(this: void, left: unknown, right: unknown): boolean {
			return OmegaMath.Lte(left, right);
		},

		Gt(this: void, left: unknown, right: unknown): boolean {
			return OmegaMath.Gt(left, right);
		},

		Gte(this: void, left: unknown, right: unknown): boolean {
			return OmegaMath.Gte(left, right);
		},

		AsNumber(this: void, value: unknown): number {
			return OmegaMath.ToNumber(value);
		},

		Persist(this: void, value: unknown): Persist {
			return OmegaMath.Persist(value);
		},

		Floor(this: void, value: unknown): Persist {
			return OmegaMath.Floor(value);
		},

		Min(this: void, left: unknown, right: unknown): Persist {
			return OmegaMath.Min(left, right);
		},

		Max(this: void, left: unknown, right: unknown): Persist {
			return OmegaMath.Max(left, right);
		},

		LabPowerEffect(this: void, profile: ProfileLike, channelId: string): number {
			const lab = profile.Lab;
			const channel = GameConfig.Lab.Power.Channels[channelId];
			if (!truthy(lab) || !truthy(lab.Routing) || !truthy(channel)) {
				return 0;
			}
			// only cells the player still owns count, filled in channel order like the Lab state
			const LabOrderMath = require(script.Parent!.WaitForChild("LabOrderMath") as ModuleScript) as {
				CHANNEL_ORDER: string[];
				TotalCells(this: void, rebirths: number, baseCells: number, rebirthsPerCell: number, maxCells: number): number;
			};
			const power = GameConfig.Lab.Power as unknown as Dict;
			let left = LabOrderMath.TotalCells(
				tonumber(profile.Rebirths) ?? 0,
				tonumber(power.BaseCells) ?? 0,
				tonumber(power.RebirthsPerCell) ?? 0,
				tonumber(power.MaxCells) ?? 0,
			);
			const routing = lab.Routing as unknown as Dict;
			for (const id of LabOrderMath.CHANNEL_ORDER) {
				const raw = routing[id];
				const cells =
					typeIs(raw, "number") && raw === raw && raw < math.huge
						? math.clamp(math.floor(raw), 0, math.max(0, left))
						: 0;
				if (id === channelId) {
					return EconomyEnvelopeMath.LabPowerEffect({ [id]: cells }, channelId, channel);
				}
				left -= cells;
			}
			return 0;
		},

		GetMachine(this: void, id: string): MachineDef | undefined {
			return machineById[id];
		},

		GetResearch(this: void, id: string): ResearchDef | undefined {
			return researchById[id];
		},

		GetGridUpgrade(this: void, id: string): GridUpgradeDef | undefined {
			return gridById[id];
		},

		GetArtifact(this: void, id: string): ArtifactDef | undefined {
			for (const artifact of GameConfig.Operations.Artifacts) {
				if (artifact.Id === id) {
					return artifact;
				}
			}
			return undefined;
		},

		GetItemDefinition(this: void, id: string): ItemDef | undefined {
			for (const definition of GameConfig.Items.Definitions) {
				if (definition.Id === id) {
					return definition;
				}
			}
			return undefined;
		},

		ItemEffect(this: void, profile: ProfileLike, effectKind: string, slotFilter?: string, targetFilter?: string): number {
			// the companion, lit constellations and engraved lines are global bonuses, so they ride along with the
			// research-wide lookups only
			const companion =
				targetFilter === undefined && (slotFilter === undefined || slotFilter === "Research")
					? CompanionRelic.bonus(profile.Items, effectKind) +
						Constellations.bonus(profile, effectKind) +
						RelicEngraving.bonus(profile.Items, effectKind)
					: 0;
			return companion + EconomyEnvelopeMath.ItemEffect(
				profile.Items,
				profile.Machines,
				profile.Research,
				effectKind,
				(id: unknown) => Economy.GetItemDefinition(id as string),
				slotFilter,
				targetFilter,
			);
		},

		CodexBonus(this: void, profile: ProfileLike): number {
			const items = profile.Items as Dict | undefined;
			return EconomyEnvelopeMath.CodexBonus(
				typeIs(items, "table") && truthy(items.Discovered) ? items.Discovered : undefined,
				GameConfig.Items.Definitions,
				GameConfig.Items.CodexBonus,
			);
		},

		ArtifactEffect(this: void, profile: ProfileLike, effectKind: string): number {
			const command = profile.Command;
			if (!truthy(command) || command.EquippedArtifact === "") {
				return 0;
			}
			if (!typeIs(command.Artifacts, "table")) {
				return 0;
			}
			const artifact = Economy.GetArtifact(command.EquippedArtifact);
			const owned = command.Artifacts[command.EquippedArtifact];
			if (!truthy(artifact) || !truthy(owned)) {
				return 0;
			}
			return EconomyEnvelopeMath.ArtifactLevelEffect(artifact, owned, effectKind);
		},

		MasteryMultiplier(this: void, profile: ProfileLike): number {
			const command = profile.Command;
			if (!truthy(command)) {
				return 1;
			}
			return EconomyEnvelopeMath.MasteryMultiplier(command.MachineMastery);
		},

		GridEffect(this: void, profile: ProfileLike, effectKind: string): number {
			return EconomyEnvelopeMath.GridEffect(profile.GridUpgrades, gridById, effectKind);
		},

		// The Reactor retired into the Star Foundry (its progress converted on load), so it adds nothing now.
		AnomalyEffect(this: void, _profile: ProfileLike, _effectKind: string, _now?: number): number {
			return 0;
		},

		AnomalySurgeMultiplier(this: void, _profile: ProfileLike, _now?: number): number {
			return 1;
		},

		GetZone(this: void, id: number): ZoneDef | undefined {
			return GameConfig.ResolveZone(id);
		},

		MaxZone(this: void): number {
			return GameConfig.MaxZone;
		},

		GetExpedition(this: void, id: string): unknown {
			return GameConfig.ResolveExpedition(id);
		},

		// what the Domain Lattice adds to one kind of bonus ("Production", "Capacity", ...)
		DomainTreeBonus(this: void, profile: ProfileLike, field: string): number {
			const domain = profile.Domain;
			return DomainLattice.bonus(truthy(domain) ? domain.Links : undefined, field);
		},

		MachineCost(this: void, id: string, currentLevel: number): Persist {
			return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetMachine(id), currentLevel);
		},

		ResearchCost(this: void, id: string, currentLevel: number): Persist {
			return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetResearch(id), currentLevel);
		},

		GridUpgradeCost(this: void, id: string, currentLevel: number): Persist {
			return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetGridUpgrade(id), currentLevel);
		},

		GridBulkCost(this: void, id: string, currentLevel: number, count: number): Persist {
			return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetGridUpgrade(id), currentLevel, count);
		},

		AffordableGridLevels(this: void, id: string, currentLevel: number, stardust: unknown, maximum: number): LuaTuple<[number, Persist]> {
			return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetGridUpgrade(id), currentLevel, stardust, maximum);
		},

		MachineBulkCost(this: void, id: string, currentLevel: number, count: number): Persist {
			return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetMachine(id), currentLevel, count);
		},

		ResearchBulkCost(this: void, id: string, currentLevel: number, count: number): Persist {
			return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetResearch(id), currentLevel, count);
		},

		AffordableMachineLevels(this: void, id: string, currentLevel: number, cash: unknown, maximum: number): LuaTuple<[number, Persist]> {
			return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetMachine(id), currentLevel, cash, maximum);
		},

		AffordableResearchLevels(this: void, id: string, currentLevel: number, cash: unknown, maximum: number): LuaTuple<[number, Persist]> {
			return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetResearch(id), currentLevel, cash, maximum);
		},

		RawProduction(this: void, profile: ProfileLike): Persist {
			let total: Persist = 0;
			const owned = profile.Machines;
			if (!typeIs(owned, "table")) {
				return 0;
			}
			for (const [id, level] of pairs(owned)) {
				if (typeIs(level, "number") && level > 0) {
					const machine = machineById[id];
					if (machine !== undefined) {
						const itemMultiplier =
							1 + Economy.ItemEffect(profile, "Production", "Machine", `Machine:${machine.Id}`);
						const piece = OmegaMath.Mul(
							OmegaMath.Mul(machine.BaseProduction, level),
							(1 + machine.Growth * math.max(0, level - 1)) * itemMultiplier,
						);
						total = OmegaMath.Add(total, piece);
					}
				}
			}
			return total;
		},

		PassBonuses(this: void, profile: ProfileLike): LuaTuple<[number, number]> {
			const owned = profile.OwnedPasses;
			if (!typeIs(owned, "table")) {
				return $tuple(0, 0);
			}
			const MonetizationConfig = SharedData("MonetizationConfig") as MonetizationConfigApi;
			return MonetizationConfig.PassBonuses(owned);
		},

		ForgePathEffect(this: void, profile: ProfileLike | undefined, effectKind: string): number {
			const forgePath = truthy(profile) ? profile.ForgePath : undefined;
			if (forgePath === undefined) {
				return 0;
			}
			return ForgePathClaim.Effect(forgePath.ClaimedSteps, GameConfig.ForgePath.Steps, effectKind);
		},

		PermanentMultiplier(this: void, profile: ProfileLike): Persist {
			const domain = profile.Domain;
			const insightResearch = profile.Research;
			const insightLevel =
				typeIs(insightResearch, "table") && truthy(insightResearch.Insight) ? insightResearch.Insight : 0;
			return bounded(
				EconomyEnvelopeMath.PermanentMultiplier(
					profile.Cores,
					GameConfig.Economy.CoreMultiplier,
					GameConfig.Economy.CoreExponent,
					truthy(domain) ? domain.Rank : 0,
					truthy(domain) ? domain.Essence : 0,
					1_000_000,
					GameConfig.Domain.ProductionPerRank,
					GameConfig.Domain.ProductionPerEssence,
					Economy.DomainTreeBonus(profile, "Production"),
					Economy.ForgePathEffect(profile, "Production"),
					profile.Rebirths,
					GameConfig.Economy.RebirthMultiplier,
					Economy.ForgePathEffect(profile, "RebirthMultiplier"),
					insightLevel,
				),
			);
		},

		OreEffect(this: void, profile: ProfileLike, effectKind: string): number {
			return OreMath.Effect((profile as Dict).OreUpgrades, effectKind, GameConfig.Ore);
		},

		// what the echo chord (and the journal) adds to one kind of bonus
		EchoEffect(this: void, profile: ProfileLike, effectKind: string): number {
			return EchoMath.total(profile.ForgeEchoes, effectKind);
		},

		ContinuumCosts(this: void, rank: number): LuaTuple<[Persist, Persist]> {
			return ContinuumDomainMath.ContinuumCosts(OmegaMath, GameConfig.Continuum, rank);
		},

		// Star Foundry replaced Continuum: production, capacity, tap and offline come from the board
		FoundryEffects(this: void, profile: ProfileLike): LuaTuple<[number, number, number, number]> {
			return (
				require(script.Parent!.WaitForChild("FoundryService") as ModuleScript) as FoundryServiceApi
			).Effects(profile);
		},

		ContinuumEffects(this: void, profile: ProfileLike): LuaTuple<[number, number, number, number]> {
			return Economy.FoundryEffects(profile);
		},

		DomainRequirements(this: void, rank: number): LuaTuple<[number, number]> {
			return ContinuumDomainMath.DomainRequirements(OmegaMath, GameConfig.Domain, rank);
		},

		DomainRewards(this: void, rank: number): LuaTuple<[number, number]> {
			return ContinuumDomainMath.DomainRewards(GameConfig.Domain, rank);
		},

		// Ascension multiplier for one effect (Production, Capacity, Tap, Cores, Essence, Aether).
		AscensionEffect(this: void, profile: ProfileLike, kind: string): Persist {
			const state = (profile as Dict).Ascension;
			if (!typeIs(state, "table")) {
				return 1;
			}
			return AscensionMath.effect(AscensionMath.sanitize(state, OmegaMath), kind, OmegaMath) as Persist;
		},

		Production(this: void, profile: ProfileLike, now?: number): Persist {
			const research = profile.Research;
			const efficiencyLevel = typeIs(research, "table") && truthy(research.Efficiency) ? research.Efficiency : 0;
			const zone = Economy.GetZone(profile.CurrentZone) ?? GameConfig.Zones[0];
			const passProduction = Economy.PassBonuses(profile)[0];
			let multiplier = OmegaMath.Mul(1 + (efficiencyLevel as number) * 0.15, zone.Multiplier);
			multiplier = OmegaMath.Mul(multiplier, Economy.PermanentMultiplier(profile));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.GridEffect(profile, "GridProduction"));
			multiplier = OmegaMath.Mul(multiplier, Specializations.Factor(profile.Specialization, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.EchoEffect(profile, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.ArtifactEffect(profile, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.ItemEffect(profile, "Production", "Research"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.CodexBonus(profile));
			// BALANCE: relic-rig production. Live rate only; steady production below matches it.
			multiplier = OmegaMath.Mul(multiplier, 1 + RelicRigs.bonus(profile, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.AnomalyEffect(profile, "Production", now));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.LabPowerEffect(profile, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + Economy.OreEffect(profile, "Production"));
			multiplier = OmegaMath.Mul(multiplier, 1 + passProduction);
			multiplier = OmegaMath.Mul(multiplier, 1 + (truthy(profile.GuildBonuses) ? profile.GuildBonuses.Production : 0));
			multiplier = OmegaMath.Mul(
				multiplier,
				math.max(1, truthy(profile.SocialBoost) ? profile.SocialBoost.Multiplier : 1),
			);
			multiplier = OmegaMath.Mul(multiplier, Economy.MasteryMultiplier(profile));
			multiplier = OmegaMath.Mul(multiplier, Economy.AnomalySurgeMultiplier(profile, now));
			multiplier = OmegaMath.Mul(multiplier, Economy.ContinuumEffects(profile)[0]);
			multiplier = OmegaMath.Mul(multiplier, Economy.AscensionEffect(profile, "Production"));
			const progression = profile.Progression;
			if (typeIs(progression, "table")) {
				const bag = progression as Dict;
				multiplier = OmegaMath.Mul(multiplier, 1 + LevelRewards.mastery(tonumber(bag.RewardedLevel) ?? 0));
				multiplier = OmegaMath.Mul(multiplier, LevelRewards.surgeMultiplier(bag.Surge, now ?? os.time()));
			}
			const activeBoost = profile.ActiveBoost;
			if (truthy(activeBoost) && activeBoost.EndsAt > (now ?? os.time())) {
				const boost = GameConfig.Boosts[activeBoost.Id];
				if (truthy(boost) && truthy(boost.Multiplier)) {
					multiplier = OmegaMath.Mul(multiplier, boost.Multiplier);
				}
			}
			return OmegaMath.Mul(Economy.RawProduction(profile), multiplier);
		},

		SteadyProduction(this: void, profile: ProfileLike, now?: number): Persist {
			const research = profile.Research;
			const efficiencyLevel = typeIs(research, "table") && truthy(research.Efficiency) ? research.Efficiency : 0;
			const zone = Economy.GetZone(profile.CurrentZone) ?? GameConfig.Zones[0];
			const passProduction = Economy.PassBonuses(profile)[0];
			return CapacityProjection.SteadyProduction(OmegaMath, Economy.RawProduction(profile), {
				EfficiencyLevel: efficiencyLevel,
				ZoneMultiplier: zone.Multiplier,
				PermanentMultiplier: Economy.PermanentMultiplier(profile),
				Additives: [
					Specializations.Factor(profile.Specialization, "Production") - 1,
					Economy.GridEffect(profile, "GridProduction"),
					Economy.EchoEffect(profile, "Production"),
					Economy.ArtifactEffect(profile, "Production"),
					Economy.ItemEffect(profile, "Production", "Research"),
					Economy.AnomalyEffect(profile, "Production", now),
					Economy.LabPowerEffect(profile, "Production"),
					passProduction,
					truthy(profile.GuildBonuses) ? profile.GuildBonuses.Production : 0,
					Economy.OreEffect(profile, "Production"),
					RelicRigs.bonus(profile, "Production"),
				],
				SocialMultiplier: truthy(profile.SocialBoost) ? profile.SocialBoost.Multiplier : 1,
				MasteryMultiplier: Economy.MasteryMultiplier(profile),
				ContinuumProduction: OmegaMath.Mul(
					Economy.ContinuumEffects(profile)[0],
					Economy.AscensionEffect(profile, "Production"),
				),
			});
		},

		Capacity(this: void, profile: ProfileLike, now?: number, _production?: unknown): Persist {
			const research = profile.Research;
			const storageLevel = typeIs(research, "table") && truthy(research.Storage) ? research.Storage : 0;
			const passCapacity = Economy.PassBonuses(profile)[1];
			const continuumCapacity = Economy.ContinuumEffects(profile)[1];
			const domainRank = truthy(profile.Domain) ? math.max(0, profile.Domain.Rank ?? 0) : 0;
			let boostCapacityMultiplier = 1;
			const activeBoost = profile.ActiveBoost;
			if (truthy(activeBoost) && activeBoost.EndsAt > (now ?? os.time())) {
				const boost = GameConfig.Boosts[activeBoost.Id];
				if (truthy(boost) && truthy(boost.CapacityMultiplier)) {
					boostCapacityMultiplier = boost.CapacityMultiplier;
				}
			}
			const seconds = CapacityProjection.Seconds({
				BaseSeconds: GameConfig.Economy.BaseCapacitySeconds,
				SecondsPerLevel: GameConfig.Economy.CapacitySecondsPerLevel,
				StorageLevel: storageLevel,
				Additives: [
					Economy.GridEffect(profile, "GridCapacity"),
					Economy.EchoEffect(profile, "Capacity"),
					Economy.ArtifactEffect(profile, "Capacity"),
					Economy.ItemEffect(profile, "Capacity", "Research"),
					Economy.AnomalyEffect(profile, "Capacity", now),
					Economy.LabPowerEffect(profile, "Storage"),
					passCapacity,
					truthy(profile.GuildBonuses) ? profile.GuildBonuses.Capacity : 0,
					Economy.ForgePathEffect(profile, "Capacity"),
					Economy.OreEffect(profile, "Capacity"),
					RelicRigs.bonus(profile, "Capacity"),
				],
				DomainRank: domainRank,
				CapacityPerRank: GameConfig.Domain.CapacityPerRank,
				BoostCapacityMultiplier: boostCapacityMultiplier,
				MaxSeconds: GameConfig.Economy.MaxCapacitySeconds,
				DomainTreeCapacity: Economy.DomainTreeBonus(profile, "Capacity"),
			});
			const output = Economy.SteadyProduction(profile, now);
			return OmegaMath.Mul(
				CapacityProjection.Vault(
					OmegaMath,
					GameConfig.Economy.BaseCapacity,
					output,
					seconds,
					continuumCapacity,
				),
				OmegaMath.Mul(
					Specializations.Factor(profile.Specialization, "Capacity"),
					Economy.AscensionEffect(profile, "Capacity"),
				),
			);
		},

		CapacitySeconds(this: void, profile: ProfileLike, now?: number, _production?: unknown): number {
			const output = Economy.SteadyProduction(profile, now);
			return CapacityProjection.CapacitySeconds(OmegaMath, Economy.Capacity(profile, now), output, Economy.Lte);
		},

		TapPower(this: void, profile: ProfileLike, now?: number): Persist {
			return OmegaMath.Mul(
				TapCritProjection.TapPower(OmegaMath, Economy.Production(profile, now), researchLevel(profile, "Overcharge"), {
					Grid: Economy.GridEffect(profile, "GridTap"),
					Echo: Economy.EchoEffect(profile, "Tap"),
					Artifact: Economy.ArtifactEffect(profile, "Tap"),
					Item: Economy.ItemEffect(profile, "Tap", "Research") + RelicRigs.bonus(profile, "Tap"),
					Anomaly: Economy.AnomalyEffect(profile, "Tap", now),
					Lab: Economy.LabPowerEffect(profile, "Tap"),
					Guild: truthy(profile.GuildBonuses) ? profile.GuildBonuses.Tap : 0,
					Continuum: Economy.ContinuumEffects(profile)[2],
					ForgePath: Economy.ForgePathEffect(profile, "TapPower"),
					Ore: Economy.OreEffect(profile, "Tap"),
				}),
				OmegaMath.Mul(
					Specializations.Factor(profile.Specialization, "Tap"),
					Economy.AscensionEffect(profile, "Tap"),
				),
			);
		},

		CriticalChance(this: void, profile: ProfileLike): number {
			return TapCritProjection.CriticalChance(
				researchLevel(profile, "Critical"),
				Economy.GridEffect(profile, "GridCritical"),
				Economy.EchoEffect(profile, "Critical"),
				Economy.ArtifactEffect(profile, "Critical"),
				Economy.ItemEffect(profile, "Critical", "Research"),
				Economy.AnomalyEffect(profile, "Critical"),
				Economy.ForgePathEffect(profile, "CriticalChance"),
			);
		},

		CriticalMultiplier(this: void, profile: ProfileLike): number {
			return TapCritProjection.CriticalMultiplier(
				researchLevel(profile, "Critical"),
				researchLevel(profile, "Impact"),
				Economy.ForgePathEffect(profile, "CriticalMultiplier"),
			);
		},

		AutoCollectRate(this: void, profile: ProfileLike): number {
			return EconomyEnvelopeMath.AutoCollectRate(
				researchLevel(profile, "Automation"),
				Economy.GridEffect(profile, "GridAutomation"),
				Economy.EchoEffect(profile, "Automation"),
				Economy.ArtifactEffect(profile, "Automation"),
				Economy.ItemEffect(profile, "Automation", "Research"),
				Economy.AnomalyEffect(profile, "Automation"),
				truthy(profile.GuildBonuses) ? profile.GuildBonuses.Automation : 0,
				Economy.ForgePathEffect(profile, "AutoCollect"),
			);
		},

		OfflineHours(this: void, profile: ProfileLike): number {
			return EconomyEnvelopeMath.OfflineHours(
				GameConfig.Economy.BaseOfflineHours,
				researchLevel(profile, "Offline"),
				Economy.ArtifactEffect(profile, "OfflineHours"),
				24,
			);
		},

		OfflineEfficiency(this: void, profile: ProfileLike, now?: number): number {
			const continuumOffline = Economy.ContinuumEffects(profile)[3];
			return math.min(
				1,
				EconomyEnvelopeMath.OfflineEfficiency(
					GameConfig.Economy.BaseOfflineEfficiency,
					researchLevel(profile, "Offline"),
					Economy.GridEffect(profile, "GridOffline"),
					Economy.EchoEffect(profile, "Offline"),
					Economy.ArtifactEffect(profile, "Offline"),
					Economy.ItemEffect(profile, "Offline", "Research") + RelicRigs.bonus(profile, "Offline"),
					Economy.AnomalyEffect(profile, "Offline", now),
					truthy(profile.GuildBonuses) ? profile.GuildBonuses.Offline : 0,
					truthy(profile.Domain) ? math.max(0, profile.Domain.Rank ?? 0) : 0,
					GameConfig.Domain.OfflineEfficiencyPerRank,
					continuumOffline,
					Economy.ForgePathEffect(profile, "Offline"),
				) * Specializations.Factor(profile.Specialization, "Offline"),
			);
		},

		OfflineEarnings(this: void, profile: ProfileLike, startedAt: number, endedAt: number): LuaTuple<[unknown, number, number, boolean]> {
			return OfflineProjection.Project(
				startedAt,
				endedAt,
				Economy.OfflineHours(profile) * 3600,
				30,
				GameConfig.Anomalies.CycleSeconds,
				truthy(profile.ActiveBoost) ? profile.ActiveBoost.EndsAt : 0,
				truthy(profile.Anomaly) ? profile.Anomaly.SurgeEndsAt : 0,
				(sample: number) => ({
					Production: Economy.Production(profile, sample),
					Efficiency: Economy.OfflineEfficiency(profile, sample),
				}),
				Economy.Add,
				Economy.Mul,
				bounded,
			);
		},

		// the Flux a rebirth needs after this many rebirths (base x growth^rebirths, capped)
		PrestigeRequirementFor(this: void, rebirths?: number): number {
			const economy = GameConfig.Economy as unknown as Dict;
			const base = GameConfig.Economy.PrestigeRequirement;
			const growth = math.max(1, tonumber(economy.PrestigeRequirementGrowth) ?? 1);
			const maxScale = math.max(1, tonumber(economy.PrestigeRequirementMaxScale) ?? 1);
			const count = math.max(0, math.floor(tonumber(rebirths) ?? 0));
			const discountFloor = math.clamp(tonumber(economy.PrestigeEarlyDiscount) ?? 1, 0.05, 1);
			const discountSpan = math.max(0, tonumber(economy.PrestigeEarlyDiscountRebirths) ?? 0);
			const discount =
				discountSpan > 0 && count < discountSpan ? discountFloor + (1 - discountFloor) * (count / discountSpan) : 1;
			return base * discount * math.min(maxScale, growth ** math.min(count, 10000));
		},

		PrestigeReward(this: void, runCash: unknown, rebirths?: number): unknown {
			return RebirthGate.PrestigeReward(
				OmegaMath,
				runCash,
				Economy.PrestigeRequirementFor(rebirths),
				GameConfig.Economy.PrestigeExponent,
				Economy.Lt,
			);
		},

		NextPrestigeTarget(this: void, currentReward: unknown, rebirths?: number): unknown {
			return RebirthGate.NextPrestigeTarget(
				OmegaMath,
				currentReward,
				Economy.PrestigeRequirementFor(rebirths),
				GameConfig.Economy.PrestigeExponent,
			);
		},

		TotalMachineLevels(this: void, profile: ProfileLike): number {
			return EconomyEnvelopeMath.SumNumericLevels(profile.Machines);
		},

		TotalResearchLevels(this: void, profile: ProfileLike): number {
			return EconomyEnvelopeMath.SumNumericLevels(profile.Research);
		},
	};

	function researchLevel(profile: ProfileLike, key: string): number {
		const research = profile.Research;
		if (!typeIs(research, "table")) {
			return 0;
		}
		return research[key] ?? 0;
	}

	const machineById: Record<string, MachineDef> = {};
	for (const machine of GameConfig.Machines) {
		machineById[machine.Id] = machine;
	}

	const researchById: Record<string, ResearchDef> = {};
	for (const research of GameConfig.Research) {
		researchById[research.Id] = research;
	}

	const gridById: Record<string, GridUpgradeDef> = {};
	for (const upgrade of GameConfig.GridUpgrades) {
		gridById[upgrade.Id] = upgrade;
	}

	return table.freeze(Economy);
};

__defs["EconomyEnvelopeMath"] = () => {
	const EconomyEnvelopeMath = {
		SumNumericLevels(this: void, bag: unknown): number {
			if (!typeIs(bag, "table")) {
				return 0;
			}
			let total = 0;
			for (const [, value] of pairs(bag)) {
				if (typeIs(value, "number")) {
					total += value;
				}
			}
			return total;
		},

		AutoCollectRate(
			this: void,
			automationLevel: number,
			grid: number,
			echo: number,
			artifact: number,
			item: number,
			anomaly: number,
			guild: number,
			forgePath: number,
		): number {
			return math.min(
				0.8,
				math.max(0, tonumber(automationLevel) ?? 0) * 0.02 +
					(tonumber(grid) ?? 0) +
					(tonumber(echo) ?? 0) +
					(tonumber(artifact) ?? 0) +
					(tonumber(item) ?? 0) +
					(tonumber(anomaly) ?? 0) +
					(tonumber(guild) ?? 0) +
					(tonumber(forgePath) ?? 0),
			);
		},

		OfflineHours(this: void, baseHours: number, researchOffline: number, artifactOffline: number, cap?: number): number {
			const softCap = typeIs(cap, "number") ? cap : 24;
			return math.min(
				softCap,
				(tonumber(baseHours) ?? 0) +
					math.max(0, tonumber(researchOffline) ?? 0) * 1.25 +
					(tonumber(artifactOffline) ?? 0),
			);
		},

		OfflineEfficiency(
			this: void,
			baseEfficiency: number,
			researchOffline: number,
			grid: number,
			echo: number,
			artifact: number,
			item: number,
			anomaly: number,
			guild: number,
			domainRank: number,
			offlinePerRank: number,
			continuumOffline: number,
			forgePath: number,
		): number {
			return math.min(
				1,
				(tonumber(baseEfficiency) ?? 0) +
					math.max(0, tonumber(researchOffline) ?? 0) * 0.06 +
					(tonumber(grid) ?? 0) +
					(tonumber(echo) ?? 0) +
					(tonumber(artifact) ?? 0) +
					(tonumber(item) ?? 0) +
					(tonumber(anomaly) ?? 0) +
					(tonumber(guild) ?? 0) +
					math.max(0, tonumber(domainRank) ?? 0) * (tonumber(offlinePerRank) ?? 0) +
					(tonumber(continuumOffline) ?? 0) +
					(tonumber(forgePath) ?? 0),
			);
		},

		MasteryMultiplier(this: void, machineMastery: unknown): number {
			if (!typeIs(machineMastery, "table")) {
				return 1;
			}
			let points = 0;
			for (const [, value] of pairs(machineMastery)) {
				if (typeIs(value, "number")) {
					points += value;
				}
			}
			return 1 + math.min(0.5, points * 0.002);
		},

		LabPowerEffect(this: void, routing: unknown, channelId: unknown, channel: unknown): number {
			if (!typeIs(routing, "table") || !typeIs(channel, "table") || !typeIs(channelId, "string")) {
				return 0;
			}
			const perCell = tonumber((channel as Dict).EffectPerCell) ?? 0;
			const cells = tonumber((routing as Dict)[channelId]) ?? 0;
			return math.max(0, cells) * perCell;
		},

		EffectAtLevel(this: void, definition: unknown, level: unknown): number {
			if (!typeIs(definition, "table")) {
				return 0;
			}
			const bag = definition as Dict;
			const base = tonumber(bag.BaseEffect) ?? 0;
			const growth = tonumber(bag.LevelGrowth) ?? 0;
			const safeLevel = typeIs(level, "number") ? level : 1;
			return base * (1 + growth * math.max(0, safeLevel - 1));
		},

		ArtifactLevelEffect(this: void, artifact: unknown, owned: unknown, effectKind: unknown): number {
			if (!typeIs(artifact, "table") || !typeIs(owned, "table")) {
				return 0;
			}
			const artifactBag = artifact as Dict;
			const ownedBag = owned as Dict;
			if (artifactBag.EffectKind !== effectKind) {
				return 0;
			}
			const perLevel = tonumber(artifactBag.EffectPerLevel) ?? 0;
			const level = tonumber(ownedBag.Level) ?? 0;
			return perLevel * math.max(0, level);
		},

		GridEffect(this: void, levels: unknown, gridById: unknown, effectKind: unknown): number {
			if (!typeIs(levels, "table") || !typeIs(gridById, "table")) {
				return 0;
			}
			const list = gridKindList(gridById, effectKind);
			if (list === undefined) {
				return 0;
			}
			let total = 0;
			for (const entry of list) {
				const level = (levels as Dict)[entry[0] as string];
				if (typeIs(level, "number") && level > 0) {
					total += level * entry[1];
				}
			}
			return total;
		},

		PermanentMultiplier(
			this: void,
			cores: unknown,
			coreMultiplier: unknown,
			coreExponent: unknown,
			rank: unknown,
			essence: unknown,
			essenceCap: unknown,
			productionPerRank: unknown,
			productionPerEssence: unknown,
			domainTreeBonus: unknown,
			forgePathProduction: unknown,
			rebirths: unknown,
			rebirthMultiplier: unknown,
			forgePathRebirth: unknown,
			insightLevel: unknown,
		): number {
			const safeCores = math.max(0, tonumber(cores) ?? 0);
			const coreBonus = (tonumber(coreMultiplier) ?? 0) * safeCores ** (tonumber(coreExponent) ?? 0);
			const safeRank = math.max(0, tonumber(rank) ?? 0);
			let safeEssence = math.max(0, tonumber(essence) ?? 0);
			const cap = tonumber(essenceCap) ?? 1_000_000;
			if (safeEssence > cap) {
				safeEssence = cap;
			}
			const safeRebirths = math.max(0, tonumber(rebirths) ?? 0);
			const domainMultiplier =
				1 +
				safeRank * (tonumber(productionPerRank) ?? 0) +
				safeEssence * (tonumber(productionPerEssence) ?? 0) +
				(tonumber(domainTreeBonus) ?? 0) +
				(tonumber(forgePathProduction) ?? 0);
			const rebirthScale =
				(tonumber(rebirthMultiplier) ?? 0) *
				(1 + (tonumber(forgePathRebirth) ?? 0)) *
				(1 + math.max(0, tonumber(insightLevel) ?? 0) * 0.02);
			return (1 + coreBonus + safeRebirths * rebirthScale) * domainMultiplier;
		},

		ItemEffect(
			this: void,
			items: unknown,
			machines: unknown,
			research: unknown,
			effectKind: unknown,
			getDefinition?: (this: void, id: unknown) => unknown,
			slotFilter?: unknown,
			targetFilter?: unknown,
		): number {
			if (!typeIs(items, "table") || !typeIs(effectKind, "string")) {
				return 0;
			}
			const itemsBag = items as Dict;
			const equipped = itemsBag.Equipped;
			const inventory = itemsBag.Inventory;
			if (!typeIs(equipped, "table") || !typeIs(inventory, "table")) {
				return 0;
			}
			const resolve = getDefinition;
			if (!typeIs(resolve, "function")) {
				return 0;
			}
			let total = 0;
			for (const [target, uid] of pairs(equipped)) {
				const instance = (inventory as Dict)[uid as string];
				const definition =
					instance !== undefined && instance !== false
						? resolve((instance as Dict).DefinitionId)
						: undefined;
				const [slot, targetId] = tostring(target).match("^(%a+):([%w_]+)$");
				const ownedLevel =
					slot === "Machine" && typeIs(machines, "table")
						? (machines as Dict)[targetId as string]
						: slot === "Research" && typeIs(research, "table")
							? (research as Dict)[targetId as string]
							: undefined;
				if (
					typeIs(definition, "table") &&
					typeIs(ownedLevel, "number") &&
					ownedLevel > 0 &&
					(definition as Dict).EffectKind === effectKind &&
					(!truthy(slotFilter) || slot === slotFilter) &&
					(!truthy(targetFilter) || target === targetFilter)
				) {
					total +=
						EconomyEnvelopeMath.EffectAtLevel(definition, (instance as Dict).Level) *
						EconomyEnvelopeMath.StarMultiplier((instance as Dict).Stars);
				}
			}
			return total;
		},

		STAR_BONUS: 0.25,
		MAX_STARS: 5,

		StarMultiplier(this: void, stars: unknown): number {
			const count = tonumber(stars);
			if (!typeIs(count, "number") || count !== count) {
				return 1;
			}
			return 1 + EconomyEnvelopeMath.STAR_BONUS * math.clamp(math.floor(count), 0, EconomyEnvelopeMath.MAX_STARS);
		},

		CodexBonus(this: void, discovered: unknown, definitions: unknown, bonuses: unknown): number {
			if (!typeIs(discovered, "table") || !typeIs(definitions, "table") || !typeIs(bonuses, "table")) {
				return 0;
			}
			const total: Record<string, number> = {};
			const found: Record<string, number> = {};
			for (const [, definition] of pairs(definitions)) {
				const rarity = (definition as Dict).Rarity as string;
				total[rarity] = (total[rarity] ?? 0) + 1;
				if ((discovered as Dict)[(definition as Dict).Id as string] === true) {
					found[rarity] = (found[rarity] ?? 0) + 1;
				}
			}
			let bonus = 0;
			for (const [rarity, count] of pairs(total)) {
				if (count > 0 && found[rarity] === count) {
					bonus += tonumber((bonuses as Dict)[rarity]) ?? 0;
				}
			}
			return bonus;
		},
	};

	// the star grid has thousands of nodes and this runs many times per player tick, so each effect
	// kind keeps its own list of { id, per-level } and only that list is walked
	const gridKindIndex = setmetatable(new Map<unknown, Record<string, [unknown, number][]>>(), {
		__mode: "k",
	} as LuaMetatable<Map<unknown, Record<string, [unknown, number][]>>>);

	function gridKindList(gridById: unknown, effectKind: unknown): [unknown, number][] | undefined {
		let byKind = gridKindIndex.get(gridById);
		if (byKind === undefined) {
			byKind = {};
			for (const [id, upgrade] of pairs(gridById as object)) {
				const bag = upgrade as Dict;
				if (typeIs(upgrade, "table") && bag.EffectKind !== undefined) {
					let list = byKind[bag.EffectKind as string];
					if (list === undefined) {
						list = [];
						byKind[bag.EffectKind as string] = list;
					}
					list.push([id, tonumber(bag.EffectPerLevel) ?? 0]);
				}
			}
			gridKindIndex.set(gridById, byKind);
		}
		return byKind[effectKind as string];
	}

	return table.freeze(EconomyEnvelopeMath);
};

__defs["ForgePathClaim"] = () => {
	interface ForgePathBag {
		ClaimedSteps: Record<string, boolean>;
		XP: number;
		XPDay: number;
		XPEarnedToday: number;
	}

	const ForgePathClaim = {
		Ensure(this: void, forgePath: unknown): ForgePathBag {
			if (!typeIs(forgePath, "table")) {
				return { ClaimedSteps: {}, XP: 0, XPDay: -1, XPEarnedToday: 0 };
			}
			const bag = forgePath as ForgePathBag;
			if (!typeIs(bag.ClaimedSteps, "table")) {
				bag.ClaimedSteps = {};
			}
			bag.XP = math.max(0, math.floor(tonumber(bag.XP) ?? 0));
			bag.XPDay = math.floor(tonumber(bag.XPDay) ?? -1);
			bag.XPEarnedToday = math.max(0, math.floor(tonumber(bag.XPEarnedToday) ?? 0));
			return bag;
		},

		TryClaim(this: void, forgePath: unknown, rawStep: unknown, steps: StepLikeDef[]): LuaTuple<[boolean, string | undefined, StepLikeDef | undefined]> {
			ForgePathClaim.Ensure(forgePath);
			if (!typeIs(rawStep, "number")) {
				return $tuple(false, T("EconomyMath.InvalidForgePathStep"), undefined);
			}
			const stepIndex = math.floor(rawStep);
			const step = steps[stepIndex - 1];
			if (!truthy(step)) {
				return $tuple(false, T("EconomyMath.ThatForgePathStepDoesn"), undefined);
			}
			const key = tostring(stepIndex);
			const bag = forgePath as ForgePathBag;
			if (bag.ClaimedSteps[key]) {
				return $tuple(false, T("EconomyMath.ThatStepWasAlreadyClaimed"), undefined);
			}
			if (stepIndex > 1 && !bag.ClaimedSteps[tostring(stepIndex - 1)]) {
				return $tuple(false, T("EconomyMath.ClaimThePreviousStepFirst"), undefined);
			}
			if (bag.XP < step.XPCost) {
				return $tuple(false, T("EconomyMath.NotEnoughForgeXPFor"), undefined);
			}
			bag.XP -= step.XPCost;
			bag.ClaimedSteps[key] = true;
			return $tuple(true, undefined, step);
		},

		Effect(this: void, claimedSteps: unknown, steps: unknown, effectKind: string): number {
			if (!typeIs(claimedSteps, "table") || !typeIs(steps, "table")) {
				return 0;
			}
			const stepList = steps as StepLikeDef[];
			let total = 0;
			for (const [stepKey] of pairs(claimedSteps)) {
				const stepIndex = tonumber(stepKey);
				const step = stepIndex !== undefined ? stepList[stepIndex - 1] : undefined;
				if (typeIs(step, "table") && step.EffectKind === effectKind) {
					total += tonumber(step.EffectAmount) ?? 0;
				}
			}
			return total / 100;
		},

		XpFromBankedAmount(this: void, amountNumber: number, xpConfig: unknown): number {
			const bag = xpConfig as Dict | undefined;
			const scale = tonumber(truthy(bag) ? bag.LogScale : undefined) ?? 4;
			const minimum = tonumber(truthy(bag) ? bag.Minimum : undefined) ?? 1;
			const safeAmount = math.max(0, tonumber(amountNumber) ?? 0);
			return math.max(minimum, math.floor((math.log(safeAmount + 1) / math.log(10)) * scale));
		},
	};

	return table.freeze(ForgePathClaim);
};

__defs["OfflineProjection"] = () => {
	interface SampleResult {
		Production: unknown;
		Efficiency: number;
	}

	const OfflineProjection = {
		Project(
			this: void,
			startedAt: number,
			endedAt: number,
			maxSeconds: number,
			minElapsed: number,
			cycleSeconds: number,
			boostEnd: number,
			surgeEnd: number,
			sampleAt: (this: void, sample: number) => SampleResult,
			add: (this: void, a: unknown, b: unknown) => unknown,
			mul: (this: void, a: unknown, b: unknown) => unknown,
			persist?: (this: void, value: unknown) => unknown,
		): LuaTuple<[unknown, number, number, boolean]> {
			// the math lives in Shared/OfflineProgress (pure, tested); this keeps the old tuple shape
			const result = OfflineProgress.project<unknown>(
				startedAt,
				endedAt,
				{ maxSeconds, minSeconds: minElapsed, cycleSeconds, boostEndsAt: boostEnd, surgeEndsAt: surgeEnd },
				(at) => {
					const sample = sampleAt(at);
					return { production: sample.Production, efficiency: sample.Efficiency };
				},
				{ zero: 0, add, scale: (value, factor) => mul(value, factor) },
			);
			const reward = persist !== undefined && result.elapsed >= minElapsed ? persist(result.reward) : result.reward;
			return $tuple(reward, result.elapsed, result.efficiency, result.capped);
		},

		PublicSnapshot(this: void, args: {
			runtime?: Dict;
			production: unknown;
			vault: unknown;
			offlineHours: number;
		}): Dict {
			const runtime = args.runtime;
			if (truthy(runtime)) {
				return {
					Reward: runtime.OfflineReward,
					Seconds: runtime.OfflineSeconds,
					Efficiency: runtime.OfflineEfficiency,
					Capped: runtime.OfflineCapped,
					Production: args.production,
					AwaySeconds: runtime.OfflineAwaySeconds ?? runtime.OfflineSeconds,
					CapHours: runtime.OfflineCapHours ?? args.offlineHours,
					Vault: args.vault,
				};
			}
			return {
				Reward: 0,
				Seconds: 0,
				Efficiency: 0,
				Capped: false,
				Production: args.production,
				AwaySeconds: 0,
				CapHours: args.offlineHours,
				Vault: args.vault,
			};
		},
	};

	return table.freeze(OfflineProjection);
};

__defs["RebirthGate"] = () => {
	const RebirthGate = {
		MeetsRequired(this: void, rebirths: number, required?: number): boolean {
			const have = math.max(0, math.floor(tonumber(rebirths) ?? 0));
			const need = math.max(0, math.floor(tonumber(required) ?? 0));
			return have >= need;
		},

		RequirementMessage(this: void, required: number): string {
			const need = math.max(0, math.floor(tonumber(required) ?? 0));
			return string.format("Requires %d rebirths.", need);
		},

		PrestigeReward(
			this: void,
			omegaMath: OmegaMathApi,
			runCash: unknown,
			requirement: number,
			exponent: number,
			lt: (this: void, a: unknown, b: unknown) => boolean,
		): unknown {
			if (lt(runCash, requirement)) {
				return 0;
			}
			const ratio = omegaMath.Div(runCash, requirement);
			return omegaMath.Max(1, omegaMath.Floor(omegaMath.Pow(ratio, exponent)));
		},

		CanRebirth(this: void, prestigeReward: unknown, gte: (this: void, a: unknown, b: unknown) => boolean): boolean {
			return gte(prestigeReward, 1);
		},

		StardustReward(this: void, coreReward: number, scale: number, minimum: number): number {
			const reward = math.max(0, tonumber(coreReward) ?? 0);
			const stardustScale = tonumber(scale) ?? 5;
			const stardustMinimum = tonumber(minimum) ?? 4;
			return math.clamp(math.max(stardustMinimum, math.floor(math.sqrt(reward) * stardustScale)), 0, 1e14);
		},

		NextPrestigeTarget(this: void, omegaMath: OmegaMathApi, currentReward: unknown, requirement: number, exponent: number): unknown {
			const desired = omegaMath.Max(1, omegaMath.Add(currentReward, 1));
			return omegaMath.Floor(omegaMath.Mul(requirement, omegaMath.Pow(desired, 1 / exponent)));
		},
	};

	return table.freeze(RebirthGate);
};

__defs["TapCritProjection"] = () => {
	interface TapBonuses {
		Grid: number;
		Echo: number;
		Artifact: number;
		Item: number;
		Anomaly: number;
		Lab: number;
		Guild: number;
		Continuum: unknown;
		ForgePath: number;
		Ore?: number;
	}

	const TapCritProjection = {
		TapPower(this: void, omegaMath: OmegaMathApi, production: unknown, overchargeLevel: number, bonuses: TapBonuses): unknown {
			let tap = omegaMath.Max(1, omegaMath.Mul(production, 0.15));
			tap = omegaMath.Mul(tap, 1 + overchargeLevel * 0.2);
			tap = omegaMath.Mul(tap, 1 + bonuses.Grid);
			tap = omegaMath.Mul(tap, 1 + bonuses.Echo);
			tap = omegaMath.Mul(tap, 1 + bonuses.Artifact);
			tap = omegaMath.Mul(tap, 1 + bonuses.Item);
			tap = omegaMath.Mul(tap, 1 + bonuses.Anomaly);
			tap = omegaMath.Mul(tap, 1 + bonuses.Lab);
			tap = omegaMath.Mul(tap, 1 + bonuses.Guild);
			tap = omegaMath.Mul(tap, bonuses.Continuum);
			tap = omegaMath.Mul(tap, 1 + bonuses.ForgePath);
			tap = omegaMath.Mul(tap, 1 + (bonuses.Ore ?? 0));
			return tap;
		},

		CriticalChance(
			this: void,
			researchCritical: number,
			grid: number,
			echo: number,
			artifact: number,
			item: number,
			anomaly: number,
			forgePath: number,
		): number {
			return math.min(0.75, 0.05 + researchCritical * 0.012 + grid + echo + artifact + item + anomaly + forgePath);
		},

		CriticalMultiplier(this: void, researchCritical: number, researchImpact: number, forgePath: number): number {
			return 2 + math.floor(researchCritical / 5) * 0.5 + researchImpact * 0.1 + forgePath;
		},
	};

	return table.freeze(TapCritProjection);
};

__defs["UpgradeCostReason"] = () => {
	interface UpgradeLike {
		RequiredZone?: number;
		RequiredRebirths?: number;
		PreviousId?: string;
		PreviousLevel?: number;
		BaseCost?: number;
		CostScale?: number;
	}

	interface CostDef {
		BaseCost: number;
		CostScale: number;
	}

	const UpgradeCostReason = {
		LevelCost(this: void, omegaMath: OmegaMathApi, def: CostDef | undefined, currentLevel: number): Persist {
			if (!truthy(def)) {
				return math.huge;
			}
			return omegaMath.ScaledCost(def.BaseCost, def.CostScale, currentLevel);
		},

		BulkCost(this: void, omegaMath: OmegaMathApi, def: CostDef | undefined, currentLevel: number, count: number): Persist {
			if (!truthy(def)) {
				return math.huge;
			}
			return omegaMath.GeometricSum(def.BaseCost, def.CostScale, currentLevel, count);
		},

		AffordableLevels(
			this: void,
			omegaMath: OmegaMathApi,
			def: CostDef | undefined,
			currentLevel: number,
			currency: unknown,
			maximum: number,
		): LuaTuple<[number, Persist]> {
			if (!truthy(def)) {
				return $tuple(0, 0);
			}
			return omegaMath.AffordableCount(def.BaseCost, def.CostScale, currentLevel, currency, maximum);
		},

		Evaluate(
			this: void,
			profile: unknown,
			upgrade: UpgradeLike,
			levels: unknown,
			zoneNameForIndex: (this: void, index: number) => string | undefined,
			previousNameForId: (this: void, id: string) => string | undefined,
		): string | undefined {
			const bag = profile as Dict;
			const requiredZone = upgrade.RequiredZone ?? 1;
			const zoneOwned = math.max(0, math.floor(tonumber(bag.Zone) ?? 0));
			if (zoneOwned < requiredZone) {
				const zoneName = zoneNameForIndex(requiredZone);
				return `Reach ${zoneName ?? `World ${tostring(requiredZone)}`}`;
			}
			const requiredRebirths = upgrade.RequiredRebirths ?? 0;
			const rebirths = math.max(0, math.floor(tonumber(bag.Rebirths) ?? 0));
			if (rebirths < requiredRebirths) {
				return string.format("Complete %d rebirth%s", requiredRebirths, requiredRebirths === 1 ? "" : "s");
			}
			const levelsBag = levels as Dict;
			if (truthy(upgrade.PreviousId) && ((levelsBag[upgrade.PreviousId] as number | undefined) ?? 0) < (upgrade.PreviousLevel ?? 1)) {
				const previousName = previousNameForId(upgrade.PreviousId);
				return string.format("Raise %s to level %d", previousName ?? upgrade.PreviousId, upgrade.PreviousLevel ?? 1);
			}
			return undefined;
		},
	};

	return table.freeze(UpgradeCostReason);
};

__defs["ContinuumDomainMath"] = () => {
	const MAX_VALUE = 1e308;

	const ContinuumDomainMath = {
		ContinuumCosts(this: void, omegaMath: OmegaMathApi, config: ContinuumConfigBag, rank: number): LuaTuple<[Persist, Persist]> {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			const flux = omegaMath.Floor(omegaMath.Mul(config.BaseFluxCost, omegaMath.BoundedPower(config.FluxCostScale, safeRank)));
			const stardust = omegaMath.Floor(
				omegaMath.Mul(config.BaseStardustCost, omegaMath.BoundedPower(config.StardustCostScale, safeRank)),
			);
			return $tuple(flux, stardust);
		},

		DomainRequirements(this: void, omegaMath: OmegaMathApi, config: DomainConfigBag, rank: number): LuaTuple<[number, number]> {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			const rebirths = math.floor(math.min(MAX_VALUE, config.BaseRequiredRebirths + safeRank * config.RebirthsPerRank));
			const cores = omegaMath.ScaledCost(config.BaseRequiredCores, config.CoreRequirementScale, safeRank);
			return $tuple(rebirths, omegaMath.ToNumber(cores));
		},

		DomainRewards(this: void, config: DomainConfigBag, rank: number): LuaTuple<[number, number]> {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			const essence = math.floor(math.min(MAX_VALUE, config.BaseEssenceReward + safeRank * config.EssencePerRank));
			const stardust = math.floor(math.min(MAX_VALUE, config.BaseStardustReward + safeRank * config.StardustPerRank));
			return $tuple(essence, stardust);
		},

		ContinuumEffects(this: void, omegaMath: OmegaMathApi, config: ContinuumConfigBag, rank: number): LuaTuple<[Persist, Persist, Persist, number]> {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			const every = math.max(1, math.floor(tonumber(config.MilestoneEvery) ?? 1));
			const milestones = math.floor(safeRank / every);
			const milestoneMultiplier = omegaMath.BoundedPower(config.MilestoneScale, milestones);
			const production = omegaMath.Mul(omegaMath.BoundedPower(config.ProductionScale, safeRank), milestoneMultiplier);
			const capacity = omegaMath.BoundedPower(config.CapacityScale, safeRank);
			const tap = omegaMath.BoundedPower(config.TapScale, safeRank);
			const offline = math.min(config.OfflineCap, safeRank * config.OfflinePerRank);
			return $tuple(production, capacity, tap, offline);
		},

		DomainProductionMultiplier(
			this: void,
			rank: unknown,
			essence: unknown,
			productionPerRank: unknown,
			productionPerEssence: unknown,
			essenceCap: unknown,
			domainTreeBonus: unknown,
		): number {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			let safeEssence = math.max(0, tonumber(essence) ?? 0);
			const cap = tonumber(essenceCap) ?? 1_000_000;
			if (safeEssence > cap) {
				safeEssence = cap;
			}
			return (
				1 +
				safeRank * (tonumber(productionPerRank) ?? 0) +
				safeEssence * (tonumber(productionPerEssence) ?? 0) +
				(tonumber(domainTreeBonus) ?? 0)
			);
		},

		DomainRankBonus(this: void, rank: unknown, perRank: unknown, domainTreeBonus: unknown): number {
			const safeRank = math.max(0, math.floor(tonumber(rank) ?? 0));
			return safeRank * (tonumber(perRank) ?? 0) + (tonumber(domainTreeBonus) ?? 0);
		},

		NonNegativeInt(this: void, value: unknown): number {
			return math.max(0, math.floor(tonumber(value) ?? 0));
		},

		SnapshotDomainInts(this: void, domain: unknown): Dict {
			const bag = (typeIs(domain, "table") ? domain : {}) as Dict;
			return {
				Essence: ContinuumDomainMath.NonNegativeInt(bag.Essence),
				LastExpandedAt: ContinuumDomainMath.NonNegativeInt(bag.LastExpandedAt),
				TotalRebirthsSpent: ContinuumDomainMath.NonNegativeInt(bag.TotalRebirthsSpent),
				TotalCoresSpent: ContinuumDomainMath.NonNegativeInt(bag.TotalCoresSpent),
				SkillPoints: ContinuumDomainMath.NonNegativeInt(bag.SkillPoints),
			};
		},

		SnapshotDomainPublic(this: void, args: Dict): Dict {
			const ints = ContinuumDomainMath.SnapshotDomainInts(args.domain);
			const bag = (typeIs(args.domain, "table") ? args.domain : {}) as Dict;
			const config = (truthy(args.domainConfig) ? args.domainConfig : {}) as Dict;
			const MeetsRequired = args.MeetsRequired as (this: void, a: number, b: number) => boolean;
			const Gte = args.Gte as (this: void, a: unknown, b: unknown) => boolean;
			const DomainTreeBonus = args.DomainTreeBonus as (this: void, kind: string) => number;
			return {
				Rank: args.rank,
				Essence: ints.Essence,
				LastExpandedAt: ints.LastExpandedAt,
				TotalRebirthsSpent: ints.TotalRebirthsSpent,
				TotalCoresSpent: ints.TotalCoresSpent,
				RequiredRebirths: args.requiredRebirths,
				RequiredCores: args.requiredCores,
				CanExpand: MeetsRequired(args.rebirths as number, args.requiredRebirths as number) && Gte(args.cores, args.requiredCores),
				EssenceReward: args.essenceReward,
				StardustReward: args.stardustReward,
				ProductionMultiplier: ContinuumDomainMath.DomainProductionMultiplier(
					args.rank,
					bag.Essence,
					config.ProductionPerRank,
					config.ProductionPerEssence,
					1_000_000,
					DomainTreeBonus("Production"),
				),
				CapacityMultiplier:
					1 + ContinuumDomainMath.DomainRankBonus(args.rank, config.CapacityPerRank, DomainTreeBonus("Capacity")),
				OfflineBonus: ContinuumDomainMath.DomainRankBonus(args.rank, config.OfflineEfficiencyPerRank, DomainTreeBonus("Offline")),
				SkillPoints: ints.SkillPoints,
				Links: typeIs(bag.Links, "table") ? bag.Links : {},
				LatticeClearedAtRank: ContinuumDomainMath.NonNegativeInt(bag.LatticeClearedAtRank),
			};
		},

		SnapshotContinuumPublic(this: void, args: Dict): Dict {
			const every = math.max(1, math.floor(tonumber(args.milestoneEvery) ?? 1));
			const safeRank = math.max(0, math.floor(tonumber(args.rank) ?? 0));
			const Gte = args.Gte as (this: void, a: unknown, b: unknown) => boolean;
			return {
				Rank: args.rank,
				TotalFluxSpent: args.totalFluxSpent,
				TotalStardustSpent: math.max(0, tonumber(args.totalStardustSpent) ?? 0),
				FluxCost: args.fluxCost,
				StardustCost: args.stardustCost,
				CanUpgrade: Gte(args.cash, args.fluxCost) && Gte(args.stardust, args.stardustCost),
				ProductionMultiplier: args.production,
				CapacityMultiplier: args.capacity,
				TapMultiplier: args.tap,
				OfflineBonus: args.offline,
				NextMilestone: (math.floor(safeRank / every) + 1) * every,
			};
		},
	};

	return table.freeze(ContinuumDomainMath);
};

__defs["AnomalyOpsMath"] = () => {
	interface ProtocolLike {
		Id: string;
		EffectKind?: string;
		EffectPerLevel?: number;
		BaseCost?: number;
		CostScale?: number;
		[key: string]: unknown;
	}

	const AnomalyOpsMath = {
		FindProtocol(this: void, list: unknown, protocolId: unknown): unknown {
			if (!typeIs(list, "table") || !typeIs(protocolId, "string")) {
				return undefined;
			}
			for (const [, protocol] of pairs(list)) {
				if (typeIs(protocol, "table") && (protocol as Dict).Id === protocolId) {
					return protocol;
				}
			}
			return undefined;
		},

		ProtocolEffect(this: void, protocolsBag: unknown, protocolDefs: unknown, effectKind: string): number {
			if (!typeIs(protocolDefs, "table") || !typeIs(effectKind, "string")) {
				return 0;
			}
			const levels = typeIs(protocolsBag, "table") ? (protocolsBag as Dict) : undefined;
			let total = 0;
			for (const [, protocol] of pairs(protocolDefs)) {
				const bag = protocol as Dict;
				if (typeIs(protocol, "table") && bag.EffectKind === effectKind) {
					let level = 0;
					if (levels !== undefined) {
						level = math.max(0, math.floor(tonumber(levels[bag.Id as string]) ?? 0));
					}
					total += level * (tonumber(bag.EffectPerLevel) ?? 0);
				}
			}
			return total;
		},

		CoreTierMaximumBonus(this: void, coreTier: unknown, tierConfigs: unknown): number {
			const tier = math.max(0, math.floor(tonumber(coreTier) ?? 0));
			if (!typeIs(tierConfigs, "table")) {
				return 0;
			}
			let bonus = 0;
			for (const [, tierConfig] of pairs(tierConfigs)) {
				if (typeIs(tierConfig, "table")) {
					const bag = tierConfig as Dict;
					const configTier = math.max(0, math.floor(tonumber(bag.Tier) ?? 0));
					if (configTier <= tier) {
						bonus = tonumber(bag.MaximumTargetBonus) ?? 0;
					}
				}
			}
			return bonus;
		},

		ChargeTarget(
			this: void,
			baseTarget: number,
			targetPerStabilization: number,
			maximumTarget: number,
			stabilizations: unknown,
			tierBonus: number,
		): number {
			const stabs = math.max(0, math.floor(tonumber(stabilizations) ?? 0));
			const base = math.max(0, tonumber(baseTarget) ?? 0);
			const per = math.max(0, tonumber(targetPerStabilization) ?? 0);
			const maxCap = math.max(0, tonumber(maximumTarget) ?? 0) + math.max(0, tonumber(tierBonus) ?? 0);
			return math.min(maxCap, base + stabs * per);
		},

		ProtocolCost(this: void, protocol: ProtocolLike, level: unknown): number {
			const safeLevel = math.max(0, math.floor(tonumber(level) ?? 0));
			const base = math.max(0, tonumber(truthy(protocol) ? protocol.BaseCost : undefined) ?? 0);
			const scale = math.max(1, tonumber(truthy(protocol) ? protocol.CostScale : undefined) ?? 1);
			return math.max(1, math.floor(base * scale ** safeLevel + 0.5));
		},

		SelectDirectives(this: void, cycle: unknown, definitions: unknown, slots: unknown): unknown[] {
			const selected: unknown[] = [];
			if (!typeIs(definitions, "table")) {
				return selected;
			}
			const list = definitions as unknown[];
			const count = list.size();
			if (count <= 0) {
				return selected;
			}
			const safeCycle = math.max(0, math.floor(tonumber(cycle) ?? 0));
			const slotCount = math.max(0, math.floor(tonumber(slots) ?? 0));
			const start = safeCycle % count;
			for (const slot of $range(1, slotCount)) {
				const index = ((start + (slot - 1) * 3) % count) + 1;
				const definition = list[index - 1] as Dict | undefined;
				if (typeIs(definition, "table")) {
					const difficulty = ((safeCycle * 7 + slot * 13) % 5) / 4;
					const targetMin = tonumber(definition.TargetMin) ?? 1;
					const targetMax = tonumber(definition.TargetMax) ?? targetMin;
					const target = math.floor(targetMin + (targetMax - targetMin) * difficulty + 0.5);
					selected[slot - 1] = {
						Definition: definition,
						Target: math.max(1, target),
					};
				}
			}
			return selected;
		},

		RewardMultiplier(this: void, anomalyRewardMultiplier: unknown, protocolRewardEffect: number, channelRewardAmount?: number): number {
			const base = math.max(0, tonumber(anomalyRewardMultiplier) ?? 1);
			const protocol = 1 + math.max(0, tonumber(protocolRewardEffect) ?? 0);
			const channel = 1 + math.max(0, tonumber(channelRewardAmount) ?? 0);
			return base * protocol * channel;
		},

		ApplyCoreXP(this: void, anomaly: unknown, xp: unknown, tierConfigs: unknown): number {
			if (!typeIs(anomaly, "table")) {
				return 0;
			}
			const bag = anomaly as Dict;
			const add = math.max(0, tonumber(xp) ?? 0);
			const coreXP = math.max(0, tonumber(bag.CoreXP) ?? 0) + add;
			bag.CoreXP = coreXP;
			let currentTier = math.max(0, math.floor(tonumber(bag.CoreTier) ?? 0));
			let gained = 0;
			if (typeIs(tierConfigs, "table")) {
				for (const [, tierConfig] of pairs(tierConfigs)) {
					if (typeIs(tierConfig, "table")) {
						const tierBag = tierConfig as Dict;
						const configTier = math.max(0, math.floor(tonumber(tierBag.Tier) ?? 0));
						const required = math.max(0, tonumber(tierBag.RequiredXP) ?? 0);
						if (configTier > currentTier && coreXP >= required) {
							currentTier = configTier;
							gained += 1;
						}
					}
				}
			}
			if (gained > 0) {
				bag.CoreTier = currentTier;
			}
			return gained;
		},

		NextCoreTier(this: void, coreTier: unknown, tierConfigs: unknown): unknown {
			const tier = math.max(0, math.floor(tonumber(coreTier) ?? 0));
			if (!typeIs(tierConfigs, "table")) {
				return undefined;
			}
			for (const [, tierConfig] of pairs(tierConfigs)) {
				if (typeIs(tierConfig, "table")) {
					const bag = tierConfig as Dict;
					const configTier = math.max(0, math.floor(tonumber(bag.Tier) ?? 0));
					if (configTier > tier) {
						return tierConfig;
					}
				}
			}
			return undefined;
		},

		LoadoutEffect(this: void, loadout: unknown, channels: unknown, effectKind: string): number {
			if (!typeIs(loadout, "table") || !typeIs(channels, "table") || !typeIs(effectKind, "string")) {
				return 0;
			}
			let total = 0;
			for (const [, channelId] of pairs(loadout)) {
				const channel = (channels as Dict)[channelId as string];
				if (typeIs(channel, "table") && (channel as Dict).EffectKind === effectKind) {
					total += tonumber((channel as Dict).EffectAmount) ?? 0;
				}
			}
			return total;
		},

		CycleTypeEffect(this: void, types: unknown, cycleSeconds: unknown, now: unknown, effectKind: string): number {
			if (!typeIs(types, "table") || !typeIs(effectKind, "string")) {
				return 0;
			}
			const list = types as unknown[];
			const count = list.size();
			if (count <= 0) {
				return 0;
			}
			const seconds = math.max(1, math.floor(tonumber(cycleSeconds) ?? 1));
			const timestamp = math.max(0, math.floor(tonumber(now) ?? 0));
			const cycle = math.floor(timestamp / seconds);
			const anomaly = list[cycle % count] as Dict | undefined;
			if (typeIs(anomaly, "table") && anomaly.EffectKind === effectKind) {
				return tonumber(anomaly.EffectAmount) ?? 0;
			}
			return 0;
		},

		CorePassiveProduction(this: void, coreTier: unknown, tierConfigs: unknown): number {
			const tier = math.max(0, math.floor(tonumber(coreTier) ?? 0));
			if (tier <= 0 || !typeIs(tierConfigs, "table")) {
				return 0;
			}
			let total = 0;
			for (const [, tierConfig] of pairs(tierConfigs)) {
				if (typeIs(tierConfig, "table")) {
					const bag = tierConfig as Dict;
					const configTier = math.max(0, math.floor(tonumber(bag.Tier) ?? 0));
					if (configTier <= tier) {
						total += tonumber(bag.PassiveProduction) ?? 0;
					}
				}
			}
			return total;
		},

		Effect(
			this: void,
			state: unknown,
			effectKind: string,
			protocolDefs: unknown,
			channels: unknown,
			types: unknown,
			cycleSeconds: unknown,
			now: unknown,
			coreTiers: unknown,
		): number {
			if (!typeIs(state, "table") || !typeIs(effectKind, "string")) {
				return 0;
			}
			const bag = state as Dict;
			let total = AnomalyOpsMath.ProtocolEffect(bag.Protocols, protocolDefs, effectKind);
			total += AnomalyOpsMath.LoadoutEffect(bag.Loadout, channels, effectKind);
			total += AnomalyOpsMath.CycleTypeEffect(types, cycleSeconds, now, effectKind);
			if (effectKind === "Production") {
				total += AnomalyOpsMath.CorePassiveProduction(bag.CoreTier, coreTiers);
			}
			return total;
		},

		SurgeMultiplier(this: void, state: unknown, now: unknown, surgeMultiplier: unknown): number {
			if (!typeIs(state, "table")) {
				return 1;
			}
			const endsAt = tonumber((state as Dict).SurgeEndsAt);
			const timestamp = tonumber(now) ?? 0;
			if (endsAt !== undefined && endsAt > timestamp) {
				return math.max(1, tonumber(surgeMultiplier) ?? 1);
			}
			return 1;
		},
	};

	return table.freeze(AnomalyOpsMath);
};

__defs["ProgressionGate"] = () => {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");

	interface EconomyLite {
		AsNumber(this: void, value: unknown): number;
		TotalMachineLevels(this: void, profile: unknown): number;
		TotalResearchLevels(this: void, profile: unknown): number;
		GetMachine(this: void, id: string): { Name?: string } | undefined;
		GetResearch(this: void, id: string): { Name?: string } | undefined;
	}

	const Economy = __load("Economy") as EconomyLite;
	const UpgradeCostReason = __load("UpgradeCostReason") as UpgradeCostReasonApi;
	const GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as GameConfigApi;
	const ForgeLevels = (require(shared.WaitForChild("SharedData") as ModuleScript) as (this: void, name: string) => unknown)(
		"ForgeLevels",
	) as ForgeLevelsApi;

	const ProgressionGate = {
		Progress(this: void, profile: unknown, kind: string): number {
			const bag = profile as Dict;
			if (kind === "Always") {
				return math.huge;
			} else if (kind === "Level") {
				return ProgressionGate.Level(profile);
			} else if (kind === "LifetimeCash") {
				return Economy.AsNumber(bag.LifetimeCash);
			} else if (kind === "MachinesBought") {
				const stats = bag.Stats as Dict | undefined;
				const bought = math.max(0, math.floor(tonumber(truthy(stats) ? stats.MachinesBought : undefined) ?? 0));
				return math.max(bought, Economy.TotalMachineLevels(profile));
			} else if (kind === "MachineLevels") {
				return Economy.TotalMachineLevels(profile);
			} else if (kind === "ResearchLevels") {
				return Economy.TotalResearchLevels(profile);
			} else if (kind === "Rebirths") {
				const current = math.max(0, math.floor(tonumber(bag.Rebirths) ?? 0));
				let spent = 0;
				if (typeIs(bag.Domain, "table")) {
					spent = math.max(0, math.floor(tonumber((bag.Domain as Dict).TotalRebirthsSpent) ?? 0));
				}
				// rebirths reset by an ascension still count toward milestones
				const ascension = bag.Ascension;
				const ascended = typeIs(ascension, "table")
					? math.max(0, math.floor(tonumber((ascension as Dict).RebirthsSpent) ?? 0))
					: 0;
				return current + spent + ascended;
			} else if (kind === "Domain" || kind === "DomainRank") {
				const domain = bag.Domain as Dict | undefined;
				const rank = math.max(0, tonumber(truthy(domain) ? domain.Rank : undefined) ?? 0);
				const ascension = bag.Ascension;
				const best = typeIs(ascension, "table") ? math.max(0, tonumber((ascension as Dict).BestDomainRank) ?? 0) : 0;
				return math.max(rank, best);
			} else if (kind === "Zone") {
				return math.max(0, math.floor(tonumber(bag.Zone) ?? 0));
			} else if (kind === "PlayTime") {
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.PlayTime : undefined) ?? 0));
			} else if (kind === "AnomalyStabilizations") {
				const anomaly = bag.Anomaly as Dict | undefined;
				const fromAnomaly = tonumber(truthy(anomaly) ? anomaly.Stabilizations : undefined);
				if (fromAnomaly !== undefined) {
					return math.max(0, math.floor(fromAnomaly));
				}
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.AnomalyStabilizations : undefined) ?? 0));
			} else if (kind === "ForgePathSteps") {
				let claimed = 0;
				const forgePath = bag.ForgePath as Dict | undefined;
				if (typeIs(forgePath, "table") && typeIs(forgePath.ClaimedSteps, "table")) {
					for (const _ of pairs(forgePath.ClaimedSteps as object)) {
						claimed += 1;
					}
				}
				return claimed;
			}
			return 0;
		},

		Meets(this: void, profile: unknown, requirement: unknown): boolean {
			if (!truthy(requirement)) {
				return true;
			}
			const bag = requirement as Dict;
			return ProgressionGate.Progress(profile, bag.Kind as string) >= (bag.Target as number);
		},

		Level(this: void, profile: unknown): number {
			return ForgeLevels.levelFor((kind: string): number => ProgressionGate.Progress(profile, kind));
		},

		LevelState(this: void, profile: unknown): unknown {
			return ForgeLevels.snapshot((kind: string): number => ProgressionGate.Progress(profile, kind));
		},

		IsFeatureUnlocked(this: void, profile: unknown, featureId: string): boolean {
			const rule = GameConfig.Unlocks[featureId];
			return rule === undefined || ProgressionGate.Progress(profile, rule.Kind) >= rule.Target;
		},

		FeatureStates(this: void, profile: unknown): Record<string, unknown> {
			const result: Record<string, unknown> = {};
			const level = ProgressionGate.Level(profile);
			for (const [id, rule] of pairs(GameConfig.Unlocks)) {
				if (rule === undefined) {
					continue;
				}
				const progress = rule.Kind === "Level" ? level : ProgressionGate.Progress(profile, rule.Kind);
				const unlocked = progress >= rule.Target;
				// what the player sees is the milestone itself: its goal and how far along it they are
				let shownProgress = progress;
				let shownTarget = rule.Target;
				if (rule.GoalKind !== undefined && rule.GoalTarget !== undefined) {
					shownTarget = rule.GoalTarget;
					shownProgress = unlocked
						? rule.GoalTarget
						: math.min(ProgressionGate.Progress(profile, rule.GoalKind), rule.GoalTarget);
				}
				result[id as string] = {
					Unlocked: unlocked,
					Progress: shownProgress === math.huge ? shownTarget : shownProgress,
					Target: shownTarget,
					Requirement: rule.Requirement,
					Name: rule.Name,
				};
			}
			return result;
		},

		UpgradeReason(this: void, profile: unknown, upgrade: unknown, levels: unknown): string | undefined {
			return UpgradeCostReason.Evaluate(
				profile,
				upgrade,
				levels,
				(requiredZone: number): string | undefined => {
					const zone = GameConfig.Zones[requiredZone - 1];
					return zone !== undefined ? zone.Name : undefined;
				},
				(previousId: string): string | undefined => {
					const previous = Economy.GetMachine(previousId) ?? Economy.GetResearch(previousId);
					return previous !== undefined ? previous.Name : undefined;
				},
			);
		},
	};

	return table.freeze(ProgressionGate);
};

__defs["ProgressionOpsMath"] = () => {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const RelicRigs = require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("RelicRigs") as ModuleScript,
	) as { litCount(this: void, raw: unknown): number };

	function sumNumericLevels(bag: unknown): number {
		if (!typeIs(bag, "table")) {
			return 0;
		}
		let total = 0;
		for (const [, value] of pairs(bag)) {
			if (typeIs(value, "number")) {
				total += value;
			}
		}
		return total;
	}

	interface TitleLike {
		Kind?: string;
		Target?: number;
	}

	const ProgressionOpsMath = {
		WeeklyValue(this: void, profile: unknown, kind: string): number {
			const bag = profile as Dict;
			const stats = (typeIs(profile, "table") ? bag.Stats : undefined) as Dict | undefined;
			if (kind === "Upgrades") {
				return (
					math.max(0, math.floor(tonumber(truthy(stats) ? stats.MachinesBought : undefined) ?? 0)) +
					math.max(0, math.floor(tonumber(truthy(stats) ? stats.ResearchBought : undefined) ?? 0))
				);
			} else if (kind === "Expeditions") {
				const command = (typeIs(profile, "table") ? bag.Command : undefined) as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(command) ? command.ExpeditionsCompleted : undefined) ?? 0));
			}
			if (!typeIs(stats, "table")) {
				return 0;
			}
			return math.max(0, math.floor(tonumber(stats[kind]) ?? 0));
		},

		CommanderReward(this: void, level: unknown): Record<string, number> {
			const safe = math.max(1, math.floor(tonumber(level) ?? 1));
			if (safe % 10 === 0) {
				return { Cores: math.max(1, safe / 10), Stardust: 10 + safe, Signals: 10 + safe };
			} else if (safe % 5 === 0) {
				return { Stardust: 8 + safe, Signals: 8 + math.floor(safe / 2), StreakShield: 1 };
			}
			return { CashMinutes: 5 + safe, Signals: 3 + math.floor(safe / 3) };
		},

		FindById(this: void, list: unknown, id: string): unknown {
			if (!typeIs(list, "table") || !typeIs(id, "string")) {
				return undefined;
			}
			for (const [, item] of pairs(list)) {
				if (typeIs(item, "table") && (item as Dict).Id === id) {
					return item;
				}
			}
			return undefined;
		},

		TitleUnlocked(
			this: void,
			profile: unknown,
			title: TitleLike,
			command: unknown,
			commanderLevel: number,
			lifetimeGte?: (this: void, a: unknown, b: unknown) => boolean,
		): boolean {
			if (!typeIs(title, "table") || !typeIs(command, "table")) {
				return false;
			}
			const commandBag = command as Dict;
			const profileBag = profile as Dict;
			const kind = title.Kind;
			const target = tonumber(title.Target) ?? 0;
			if (kind === "Level") {
				return commanderLevel >= target;
			} else if (kind === "Expeditions") {
				return math.max(0, math.floor(tonumber(commandBag.ExpeditionsCompleted) ?? 0)) >= target;
			} else if (kind === "Artifacts") {
				let count = 0;
				if (typeIs(commandBag.Artifacts, "table")) {
					for (const _ of pairs(commandBag.Artifacts as object)) {
						count += 1;
					}
				}
				return count >= target;
			} else if (kind === "LifetimeCash") {
				const gte = lifetimeGte;
				if (!typeIs(gte, "function")) {
					return false;
				}
				const cash = typeIs(profile, "table") ? profileBag.LifetimeCash : undefined;
				return gte(cash, target) === true;
			} else if (kind === "Rebirths") {
				const rebirths = typeIs(profile, "table") ? tonumber(profileBag.Rebirths) ?? 0 : 0;
				return rebirths >= target;
			}
			return false;
		},

		AchievementProgress(this: void, profile: unknown, kind: string, lifetimeAsNumber?: (this: void, value: unknown) => number): number {
			if (!typeIs(profile, "table") || !typeIs(kind, "string")) {
				return 0;
			}
			const bag = profile as Dict;
			if (kind === "LifetimeCash") {
				const asNumber = lifetimeAsNumber;
				if (!typeIs(asNumber, "function")) {
					return 0;
				}
				return math.max(0, asNumber(bag.LifetimeCash) ?? 0);
			} else if (kind === "MachineLevels") {
				return sumNumericLevels(bag.Machines);
			} else if (kind === "ResearchLevels") {
				return sumNumericLevels(bag.Research);
			} else if (kind === "Rebirths") {
				const current = math.max(0, math.floor(tonumber(bag.Rebirths) ?? 0));
				let spent = 0;
				if (typeIs(bag.Domain, "table")) {
					spent = math.max(0, math.floor(tonumber((bag.Domain as Dict).TotalRebirthsSpent) ?? 0));
				}
				return current + spent;
			} else if (kind === "Zone") {
				return math.max(0, math.floor(tonumber(bag.Zone) ?? 0));
			} else if (kind === "PlayTime") {
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.PlayTime : undefined) ?? 0));
			} else if (kind === "AnomalyPulses") {
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.AnomalyPulses : undefined) ?? 0));
			} else if (kind === "AnomalyStabilizations") {
				const anomaly = bag.Anomaly as Dict | undefined;
				const fromAnomaly = tonumber(truthy(anomaly) ? anomaly.Stabilizations : undefined);
				if (fromAnomaly !== undefined) {
					return math.max(0, math.floor(fromAnomaly));
				}
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.AnomalyStabilizations : undefined) ?? 0));
			} else if (kind === "AnomalyProtocols") {
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.AnomalyProtocols : undefined) ?? 0));
			} else if (kind === "ForgePathSteps") {
				let claimed = 0;
				const forgePath = bag.ForgePath as Dict | undefined;
				if (typeIs(forgePath, "table") && typeIs(forgePath.ClaimedSteps, "table")) {
					for (const _ of pairs(forgePath.ClaimedSteps as object)) {
						claimed += 1;
					}
				}
				return claimed;
			} else if (kind === "DailyStreak") {
				const daily = bag.Daily as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(daily) ? daily.Streak : undefined) ?? 0));
			} else if (kind === "WheelSpins") {
				const wheel = bag.Wheel as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(wheel) ? wheel.Spins : undefined) ?? 0));
			} else if (kind === "LabOrders") {
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.OrdersCompleted : undefined) ?? 0));
			} else if (kind === "Expeditions") {
				const command = bag.Command as Dict | undefined;
				const fromCommand = tonumber(truthy(command) ? command.ExpeditionsCompleted : undefined);
				if (fromCommand !== undefined) {
					return math.max(0, math.floor(fromCommand));
				}
				const stats = bag.Stats as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(stats) ? stats.Expeditions : undefined) ?? 0));
			} else if (kind === "DomainRank" || kind === "Domain") {
				const domain = bag.Domain as Dict | undefined;
				return math.max(0, math.floor(tonumber(truthy(domain) ? domain.Rank : undefined) ?? 0));
			} else if (kind === "StoryClaims") {
				let count = 0;
				const story = bag.Story as Dict | undefined;
				const claimed = truthy(story) ? story.Claimed : undefined;
				if (typeIs(claimed, "table")) {
					for (const [, value] of pairs(claimed)) {
						if (value === true) {
							count += 1;
						}
					}
				}
				return count;
			} else if (kind === "RigsLit") {
				const items = bag.Items as Dict | undefined;
				return RelicRigs.litCount(typeIs(items, "table") ? items.Rigs : undefined);
			}
			return 0;
		},

		AdvanceQuestProgress(this: void, items: unknown, kind: unknown, amount: unknown): number {
			if (!typeIs(items, "table") || !typeIs(kind, "string")) {
				return 0;
			}
			const delta = math.max(0, math.floor(tonumber(amount) ?? 0));
			if (delta !== delta || delta === math.huge || delta === -math.huge || delta <= 0) {
				return 0;
			}
			let updated = 0;
			for (const [, quest] of pairs(items)) {
				if (typeIs(quest, "table")) {
					const bag = quest as Dict;
					const questKind = bag.Kind;
					if (questKind === kind || (questKind === "BuyAny" && (kind === "BuyMachine" || kind === "BuyResearch"))) {
						const progress = math.max(0, math.floor(tonumber(bag.Progress) ?? 0));
						const target = math.max(0, math.floor(tonumber(bag.Target) ?? 0));
						bag.Progress = math.min(target, progress + delta);
						updated += 1;
					}
				}
			}
			return updated;
		},

		CanClaimQuest(this: void, quest: unknown): LuaTuple<[boolean, string]> {
			if (!typeIs(quest, "table")) {
				return $tuple(false, T("EconomyMath.MissionNotFound"));
			}
			const bag = quest as Dict;
			if (bag.Claimed === true) {
				return $tuple(false, T("EconomyMath.ThatMissionRewardWasAlready"));
			}
			const progress = math.max(0, math.floor(tonumber(bag.Progress) ?? 0));
			const target = math.max(0, math.floor(tonumber(bag.Target) ?? 0));
			if (progress < target) {
				return $tuple(false, T("EconomyMath.ThatMissionIsNotComplete"));
			}
			return $tuple(true, "");
		},

		ScaledCommandXP(this: void, amount: unknown, domainBonus: unknown): number {
			const value = math.max(0, math.floor(tonumber(amount) ?? 0));
			const bonus = tonumber(domainBonus) ?? 0;
			return math.floor(value * (1 + bonus));
		},

		ApplyCommandXP(this: void, command: unknown, amount: unknown, domainBonus: unknown): number {
			if (!typeIs(command, "table")) {
				return 0;
			}
			const bag = command as Dict;
			const granted = ProgressionOpsMath.ScaledCommandXP(amount, domainBonus);
			bag.XP = (tonumber(bag.XP) ?? 0) + granted;
			bag.SeasonXP = (tonumber(bag.SeasonXP) ?? 0) + granted;
			return granted;
		},
	};

	return table.freeze(ProgressionOpsMath);
};

__defs["WheelMath"] = () => {
	interface WheelBag {
		LastSpinAt: number;
		Spins: number;
		PityMisses: number;
		FreeSpins: number;
		LastReceipt?: { ExpectedSpin: number; PrizeIndex: number; PrizeId: string; Message: string; Pity: boolean };
		History?: { PrizeId: string; At: number; Pity: boolean }[];
	}

	interface PoolEntry {
		Index: number;
		Prize: unknown;
		Weight: number;
	}

	const WheelMath = {
		RARITY_RANK: {
			COMMON: 1,
			UNCOMMON: 2,
			RARE: 3,
			EPIC: 4,
			LEGENDARY: 5,
			MYTHIC: 6,
		} as Record<string, number>,

		HISTORY_LIMIT: 10,

		// Recent spins, newest first, bounded. Written in the same save as the spin itself.
		RecordHistory(this: void, wheel: unknown, prizeId: string, at: number, pity: boolean): void {
			if (!typeIs(wheel, "table")) {
				return;
			}
			const bag = wheel as WheelBag;
			const list = (typeIs(bag.History, "table") ? bag.History : []) as { PrizeId: string; At: number; Pity: boolean }[];
			list.unshift({ PrizeId: prizeId, At: math.floor(at), Pity: pity === true });
			while (list.size() > WheelMath.HISTORY_LIMIT) {
				list.pop();
			}
			bag.History = list;
		},

		Ensure(this: void, wheel: unknown): WheelBag {
			if (!typeIs(wheel, "table")) {
				return {
					LastSpinAt: 0,
					Spins: 0,
					PityMisses: 0,
					FreeSpins: 0,
				};
			}
			const bag = wheel as WheelBag;
			bag.LastSpinAt = math.max(0, math.floor(tonumber(bag.LastSpinAt) ?? 0));
			bag.Spins = math.max(0, math.floor(tonumber(bag.Spins) ?? 0));
			bag.PityMisses = math.max(0, math.floor(tonumber(bag.PityMisses) ?? 0));
			bag.FreeSpins = math.max(0, math.floor(tonumber(bag.FreeSpins) ?? 0));
			const receipt = bag.LastReceipt;
			if (
				!typeIs(receipt, "table") ||
				!WheelMath.ValidExpectedSpin(receipt.ExpectedSpin) ||
				receipt.ExpectedSpin + 1 !== bag.Spins ||
				!typeIs(receipt.PrizeIndex, "number") ||
				receipt.PrizeIndex < 1 ||
				receipt.PrizeIndex > 1000 ||
				receipt.PrizeIndex % 1 !== 0 ||
				!typeIs(receipt.PrizeId, "string") ||
				receipt.PrizeId.size() < 1 ||
				receipt.PrizeId.size() > 64 ||
				!typeIs(receipt.Message, "string") ||
				receipt.Message.size() > 1024 ||
				!typeIs(receipt.Pity, "boolean")
			) {
				bag.LastReceipt = undefined;
			} else {
				bag.LastReceipt = {
					ExpectedSpin: receipt.ExpectedSpin,
					PrizeIndex: receipt.PrizeIndex,
					PrizeId: receipt.PrizeId,
					Message: receipt.Message,
					Pity: receipt.Pity,
				};
			}
			if (bag.History !== undefined) {
				const clean: { PrizeId: string; At: number; Pity: boolean }[] = [];
				if (typeIs(bag.History, "table")) {
					for (const entry of bag.History) {
						if (
							typeIs(entry, "table") &&
							typeIs(entry.PrizeId, "string") &&
							entry.PrizeId.size() >= 1 &&
							entry.PrizeId.size() <= 64 &&
							typeIs(entry.At, "number") &&
							entry.At === entry.At &&
							clean.size() < WheelMath.HISTORY_LIMIT
						) {
							clean.push({ PrizeId: entry.PrizeId, At: math.floor(entry.At), Pity: entry.Pity === true });
						}
					}
				}
				bag.History = clean;
			}
			return bag;
		},

		ValidExpectedSpin(this: void, value: unknown): boolean {
			return typeIs(value, "number") && value === value && value >= 0 && value < 1e12 && value % 1 === 0;
		},

		RarityRank(this: void, rarity: unknown): number {
			return WheelMath.RARITY_RANK[tostring(truthy(rarity) ? rarity : "").upper()] ?? 1;
		},

		Snapshot(
			this: void,
			now: number,
			wheel: WheelBag,
			cooldownSeconds: number,
			pityAfter: number,
		): {
			CanSpin: boolean;
			ReadyAt: number;
			Spins: number;
			FreeSpins: number;
			PityMisses: number;
			PityAfter: number;
			PityArmed: boolean;
			LastReceipt?: unknown;
			History: unknown[];
		} {
			const safeCooldown = math.max(0, math.floor(tonumber(cooldownSeconds) ?? 0));
			const safePityAfter = math.max(1, math.floor(tonumber(pityAfter) ?? 8));
			const readyAt = wheel.LastSpinAt + safeCooldown;
			const freeSpins = wheel.FreeSpins;
			const pityMisses = wheel.PityMisses;
			const cooldownReady = now >= readyAt;
			return {
				CanSpin: freeSpins > 0 || cooldownReady,
				ReadyAt: freeSpins > 0 ? now : math.max(now, readyAt),
				Spins: wheel.Spins,
				FreeSpins: freeSpins,
				PityMisses: pityMisses,
				PityAfter: safePityAfter,
				PityArmed: pityMisses + 1 >= safePityAfter,
				LastReceipt: wheel.LastReceipt,
				History: wheel.History ?? [],
			};
		},

		BuildPool(this: void, rewards: unknown[], forcePity: boolean, floorRank: number): LuaTuple<[PoolEntry[], number]> {
			const pool: PoolEntry[] = [];
			let totalWeight = 0;
			for (const [index, prize] of ipairs(rewards)) {
				const rank = WheelMath.RarityRank((prize as Dict).Rarity);
				if (!forcePity || rank >= floorRank) {
					const weight = math.max(0, tonumber((prize as Dict).Weight) ?? 0);
					pool.push({ Index: index, Prize: prize, Weight: weight });
					totalWeight += weight;
				}
			}
			return $tuple(pool, totalWeight);
		},

		FullPool(this: void, rewards: unknown[]): LuaTuple<[PoolEntry[], number]> {
			return WheelMath.BuildPool(rewards, false, 1);
		},

		PickEntry(this: void, pool: PoolEntry[], totalWeight: number, roll: number): PoolEntry | undefined {
			if (pool.size() === 0 || totalWeight <= 0) {
				return undefined;
			}
			// zero-weight prizes can never be drawn (a roll of exactly 0 used to land on one
			// when it was first in the pool)
			let selected: PoolEntry | undefined;
			let cursor = 0;
			for (const entry of pool) {
				if (entry.Weight > 0) {
					selected = entry;
					cursor += entry.Weight;
					if (roll <= cursor) {
						break;
					}
				}
			}
			return selected;
		},

		NextPityMisses(this: void, pityMisses: unknown, selectedRank: number, floorRank: number): number {
			if (selectedRank >= floorRank) {
				return 0;
			}
			return math.max(0, math.floor(tonumber(pityMisses) ?? 0)) + 1;
		},
	};

	return table.freeze(WheelMath);
};

__defs["CrateRoll"] = () => {
	interface CrateLike {
		PityRarity: string;
		PityAfter: number;
		Weights: Record<string, number>;
	}

	interface RarityData {
		Rank: number;
	}

	const CrateRoll = {
		RARITY_ORDER: ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"],

		MinimumRank(this: void, pity: number, pityAfter: number, pityRank: number): number {
			const safePity = math.max(0, math.floor(tonumber(pity) ?? 0));
			const after = math.max(0, math.floor(tonumber(pityAfter) ?? 0));
			const rank = math.max(0, math.floor(tonumber(pityRank) ?? 0));
			return safePity + 1 >= after ? rank : 0;
		},

		TotalWeight(this: void, weights: Record<string, number>, rarities: Record<string, RarityData>, minimumRank: number): number {
			let total = 0;
			for (const [rarity, weight] of pairs(weights)) {
				const data = rarities[rarity];
				if (data !== undefined && data.Rank >= minimumRank) {
					total += weight;
				}
			}
			return total;
		},

		SelectRarity(
			this: void,
			roll: number,
			weights: Record<string, number>,
			rarities: Record<string, RarityData>,
			minimumRank: number,
			pityRarityFallback: string,
			order?: string[],
		): string {
			let remaining = roll;
			let selected = pityRarityFallback;
			const walk = order ?? CrateRoll.RARITY_ORDER;
			for (const rarity of walk) {
				const data = rarities[rarity];
				const weight = weights[rarity] ?? 0;
				if (data !== undefined && data.Rank >= minimumRank && weight > 0) {
					remaining -= weight;
					if (remaining <= 0) {
						selected = rarity;
						break;
					}
				}
			}
			return selected;
		},

		Candidates(this: void, definitions: unknown[], selectedRarity: string): unknown[] {
			const candidates: defined[] = [];
			for (const definition of definitions) {
				if ((definition as Dict).Rarity === selectedRarity) {
					candidates.push(definition as defined);
				}
			}
			return candidates;
		},

		PickCandidate(this: void, candidates: unknown[], index: number): unknown {
			if (candidates.size() < 1) {
				return undefined;
			}
			const safeIndex = math.clamp(math.floor(index), 1, candidates.size());
			return candidates[safeIndex - 1];
		},

		Roll(
			this: void,
			crate: CrateLike,
			pity: number,
			rarities: Record<string, RarityData>,
			definitions: unknown[],
			nextNumber: (this: void, min: number, max: number) => number,
			nextInteger: (this: void, min: number, max: number) => number,
		): LuaTuple<[unknown, string, boolean]> {
			const pityData = rarities[crate.PityRarity];
			const pityRank = pityData !== undefined ? pityData.Rank : 0;
			const minimumRank = CrateRoll.MinimumRank(pity, crate.PityAfter, pityRank);
			const totalWeight = CrateRoll.TotalWeight(crate.Weights, rarities, minimumRank);
			const roll = nextNumber(0, math.max(totalWeight, 0.001));
			const selectedRarity = CrateRoll.SelectRarity(roll, crate.Weights, rarities, minimumRank, crate.PityRarity);
			const candidates = CrateRoll.Candidates(definitions, selectedRarity);
			const selected = CrateRoll.PickCandidate(candidates, nextInteger(1, math.max(1, candidates.size())));
			const selectedData = rarities[selectedRarity];
			const selectedRank = selectedData !== undefined ? selectedData.Rank : 0;
			const pityHit = selectedRank >= pityRank;
			if (selected === undefined) {
				return $tuple(undefined, selectedRarity, false);
			}
			return $tuple(selected, selectedRarity, pityHit);
		},

		NormalizeOpenCount(this: void, rawCount: unknown): LuaTuple<[number | undefined, string | undefined]> {
			const count = typeIs(rawCount, "number") ? math.clamp(math.floor(rawCount), 1, 5) : 1;
			if (count !== 1 && count !== 5) {
				return $tuple(undefined, T("GameService.CratesCanBeOpenedOne"));
			}
			return $tuple(count, undefined);
		},

		GuaranteedRecycle(
			this: void,
			weights: Record<string, number>,
			autoEnabled: boolean,
			keepNew: unknown,
			rarityRules: Record<string, boolean>,
		): boolean {
			if (!autoEnabled || keepNew !== false) {
				return false;
			}
			for (const [rarity, weight] of pairs(weights)) {
				if (weight > 0 && rarityRules[rarity] !== true) {
					return false;
				}
			}
			return true;
		},

		RequiredSlots(this: void, count: number, guaranteedRecycle: boolean): number {
			return guaranteedRecycle ? 0 : math.max(0, math.floor(count));
		},
	};

	return table.freeze(CrateRoll);
};

__defs["OverchargeCombo"] = () => {
	const OverchargeCombo = {
		Window(this: void, comboWindow: number): number {
			return comboWindow;
		},

		Multiplier(this: void, combo: number, comboMax: number, bonusPerStack: number): number {
			return 1 + math.min(comboMax, math.max(0, combo)) * bonusPerStack;
		},

		NextCombo(this: void, previousCombo: number, comboMax: number): number {
			return math.min(comboMax, math.max(0, math.floor(previousCombo)) + 1);
		},

		Expired(this: void, elapsed: number, comboWindow: number): boolean {
			return elapsed > comboWindow;
		},

		PublicSnapshot(this: void, args: {
			combo: number;
			comboMultiplier: number;
			comboMax: number;
			comboWindow: number;
			comboBonusPerStack: number;
		}): Dict {
			return {
				Combo: args.combo,
				ComboMultiplier: args.comboMultiplier,
				ComboMax: args.comboMax,
				ComboWindow: args.comboWindow,
				ComboBonusPerStack: args.comboBonusPerStack,
			};
		},
	};

	return table.freeze(OverchargeCombo);
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type EconomyMathCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const EconomyMath = setmetatable({}, {
	__call: (_self: unknown, name: string): unknown => __load(name),
	__index: (_self: unknown, name: string): unknown => name === "__members" ? __members : __load(name),
} as LuaMetatable<object>) as unknown as EconomyMathCallable;

export = EconomyMath;
