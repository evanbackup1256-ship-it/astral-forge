type Dict = Record<string, unknown>;

interface ProfileItems {
	Inventory: Dict;
	Keys: Record<string, number>;
	Discovered: Record<string, boolean>;
	Equipped: Dict;
	Essence: number;
}
interface Profile {
	[key: string]: unknown;
	Cash: number;
	RunCash: number;
	Machines: Record<string, number>;
	Stats: Dict;
	Items: ProfileItems;
}
interface Config {
	Game: { Name: unknown; Version: unknown; Update: unknown };
	Machines?: { Id: string }[] | false;
	Items: { Definitions?: { Id: string }[]; Crates?: { Id: string }[]; InventoryLimit: unknown };
	Wheel: { CooldownSeconds: number; PityAfter: number };
}
interface EconomyApi {
	Production(this: void, profile: Profile, now: number): unknown;
	Capacity(this: void, profile: Profile, now: number): unknown;
	PrestigeReward(this: void, runCash: unknown): unknown;
}
interface GateApi {
	FeatureStates(this: void, profile: Profile): Record<string, Dict>;
	LevelState(this: void, profile: Profile): unknown;
}
interface WheelApi {
	Snapshot(this: void, now: number, wheel: unknown, cooldown: number, pityAfter: number): unknown;
}
interface SchemaApi {
	ENTRIES: { key: string }[];
	value(this: void, settings: Dict, key: string): number;
}
interface ShopApi {
	day(this: void, now: number): number;
}

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const ServerScriptService = game.GetService("ServerScriptService");

const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as Config;
const SharedData = require(shared.WaitForChild("SharedData") as ModuleScript) as (name: string) => unknown;

const isSet = (value: unknown) => value !== undefined && value !== false;

function server(path: string[]): Instance | undefined {
	let node: Instance | undefined = ServerScriptService.FindFirstChild("AstralForge");
	for (const name of path) {
		node = node && node.FindFirstChild(name);
	}
	return node;
}

function attempt<T>(label: string, fn: () => T, fallback: T): T {
	const [ok, value] = pcall(fn);
	if (ok && value !== undefined) {
		return value as T;
	}
	if (!ok) {
		warn(`[StoryFixture] ${label}: ${value}`);
	}
	return fallback;
}

function deepCopy<T>(value: T): T {
	if (!typeIs(value, "table")) {
		return value;
	}
	const copy: Dict = {};
	for (const [key, item] of pairs(value as unknown as Dict)) {
		copy[key] = deepCopy(item);
	}
	return copy as unknown as T;
}

interface Preset {
	cash: number;
	lifetime: number;
	stardust: number;
	cores: number;
	rebirths: number;
	levels: number;
	relics: number;
	keys: number;
}

const PRESETS: Record<string, Preset> = {
	["New player"]: { cash: 120, lifetime: 400, stardust: 0, cores: 0, rebirths: 0, levels: 1, relics: 0, keys: 1 },
	["Mid game"]: { cash: 2.4e6, lifetime: 9.6e7, stardust: 640, cores: 22, rebirths: 4, levels: 18, relics: 9, keys: 6 },
	["Late game"]: { cash: 8.1e14, lifetime: 3.3e16, stardust: 48000, cores: 940, rebirths: 37, levels: 60, relics: 40, keys: 30 },
};

function profileFor(save: string): LuaTuple<[Profile, Preset]> {
	const preset = PRESETS[save] ?? PRESETS["Mid game"];
	const template = server(["DataTemplate"]);
	const profile = attempt<Profile>("template", () => (require(template as ModuleScript) as { New(this: void): Profile }).New(), {} as Profile);
	profile.Cash = preset.cash;
	profile.RunCash = preset.cash * 0.6;
	profile.LifetimeCash = preset.lifetime;
	profile.Stardust = preset.stardust;
	profile.Cores = preset.cores;
	profile.Rebirths = preset.rebirths;
	profile.Machines = isSet(profile.Machines) ? profile.Machines : {};
	const machines = (isSet(GameConfig.Machines) ? GameConfig.Machines : {}) as Record<number, { Id: string }>;
	for (const [index, machine] of pairs(machines)) {
		if (index <= math.max(1, math.floor(preset.levels / 6))) {
			profile.Machines[machine.Id] = math.max(1, preset.levels - index * 3);
		}
	}
	profile.Stats = isSet(profile.Stats) ? profile.Stats : {};
	profile.Stats.MachinesBought = preset.levels * 4;
	profile.Items = isSet(profile.Items) ? profile.Items : ({} as ProfileItems);
	profile.Items.Inventory = {};
	profile.Items.Keys = {};
	profile.Items.Discovered = {};
	profile.Items.Equipped = {};
	const definitions = ((isSet(GameConfig.Items) && GameConfig.Items.Definitions) || []) as { Id: string }[];
	for (let index = 1; index <= math.min(preset.relics, definitions.size()); index++) {
		const definition = definitions[(index * 7) % definitions.size()];
		const uid = "story%04d".format(index);
		profile.Items.Inventory[uid] = {
			DefinitionId: definition.Id,
			Level: 1 + (index % 6),
			Stars: index % 5 === 0 ? index % 4 : undefined,
			Locked: index % 9 === 0,
		};
		profile.Items.Discovered[definition.Id] = true;
	}
	const crates = ((isSet(GameConfig.Items) && GameConfig.Items.Crates) || {}) as Record<string, { Id: string }>;
	for (const [, crate] of pairs(crates)) {
		profile.Items.Keys[crate.Id] = preset.keys;
	}
	profile.Items.Essence = preset.relics * 35;
	return $tuple(profile, preset);
}

function build(save?: string): Dict {
	const [profile, preset] = profileFor(save ?? "Mid game");
	const now = os.time();
	const EconomyMath = server(["Modules", "EconomyMath"]);
	const economy = EconomyMath && attempt<((name: string) => unknown) | undefined>("economy", () => require(EconomyMath as ModuleScript) as (name: string) => unknown, undefined);
	const member = <T>(name: string) => (economy && attempt<unknown>(name, () => economy(name), undefined)) as T | undefined;
	const Economy = member<EconomyApi>("Economy");
	const Gate = member<GateApi>("ProgressionGate");
	const WheelMath = member<WheelApi>("WheelMath");
	const Schema = SharedData("SettingsSchema") as SchemaApi;
	const ShopCatalog = SharedData("ShopCatalog") as ShopApi;

	const settings: Dict = {};
	for (const [, entry] of pairs(Schema.ENTRIES as unknown as Record<number, { key: string }>)) {
		settings[entry.key] = Schema.value({}, entry.key);
	}
	for (const [key, value] of pairs((isSet(profile.Settings) ? profile.Settings : {}) as Dict)) {
		settings[key] = value;
	}

	const gated = Gate && attempt<Record<string, Dict>>("features", () => Gate.FeatureStates(profile), {});
	const features = (isSet(gated) ? gated : {}) as Record<string, Dict>;
	if (save === "Late game") {
		for (const [, entry] of pairs(features)) {
			entry.Unlocked = true;
		}
	}

	const orNumber = (value: unknown, fallback: unknown) => (isSet(value) ? value : fallback);

	const state: Dict = {
		Game: { Name: GameConfig.Game.Name, Version: GameConfig.Game.Version, Update: GameConfig.Game.Update },
		Cash: profile.Cash,
		Vault: preset.cash * 0.25,
		Cores: profile.Cores,
		Stardust: profile.Stardust,
		Rebirths: profile.Rebirths,
		RunCash: profile.RunCash,
		LifetimeCash: profile.LifetimeCash,
		Zone: math.max(1, math.floor(preset.levels / 12)),
		CurrentZone: math.max(1, math.floor(preset.levels / 12)),
		Machines: deepCopy(profile.Machines),
		Research: deepCopy(isSet(profile.Research) ? profile.Research : {}),
		GridUpgrades: deepCopy(isSet(profile.GridUpgrades) ? profile.GridUpgrades : {}),
		BoostInventory: { Overdrive: 2, Hyperdrive: 1, DomainSurge: 1, VaultSurge: 0 },
		ActiveBoost: { Id: "", EndsAt: 0 },
		Settings: settings,
		Flags: deepCopy(isSet(profile.Flags) ? profile.Flags : {}),
		FeatureUnlocks: features,
		Level: Gate && attempt<unknown>("level", () => Gate.LevelState(profile), undefined),
		Production: orNumber(Economy && attempt<unknown>("production", () => Economy.Production(profile, now), 120), 120),
		RawProduction: 120,
		Capacity: orNumber(Economy && attempt<unknown>("capacity", () => Economy.Capacity(profile, now), 1e6), 1e6),
		PrestigeReward: orNumber(
			Economy && attempt<unknown>("prestige", () => Economy.PrestigeReward(profile.RunCash), 0),
			0,
		),
		PermanentMultiplier: 1 + preset.rebirths * 0.25,
		NextPrestigeTarget: preset.cash * 4,
		Offline: { Pending: 0, Hours: 0 },
		OfflineHours: 8,
		OfflineEfficiency: 0.5,
		Wheel: orNumber(
			WheelMath &&
				attempt<unknown>(
					"wheel",
					() =>
						WheelMath.Snapshot(
							now,
							isSet(profile.Wheel) ? profile.Wheel : { LastSpinAt: 0, Spins: 0, PityMisses: 0, FreeSpins: 1 },
							GameConfig.Wheel.CooldownSeconds,
							GameConfig.Wheel.PityAfter,
						),
					undefined,
				),
			{ CanSpin: true, ReadyAt: now, Spins: 3, FreeSpins: 1, PityMisses: 2, PityAfter: 8, PityArmed: false },
		),
		Items: {
			Inventory: profile.Items.Inventory,
			Equipped: profile.Items.Equipped,
			Essence: profile.Items.Essence,
			Keys: profile.Items.Keys,
			Pity: {},
			InventoryLimit: GameConfig.Items.InventoryLimit,
			Shop: {},
			ShopRefreshAt: now + 3600,
			AutoSalvage: { Enabled: false, KeepNew: true, Rarities: {} },
			Effects: {},
			Discovered: profile.Items.Discovered,
			CodexBonus: 0.01,
		},
		DailyShop: { Day: ShopCatalog.day(now), Bought: { ["2"]: 1 } },
		Cosmetics: { CrateSkins: { Classic: true, Crystal: true, Molten: save === "Late game" }, CrateSkin: "Crystal" },
		Shop: { OwnedPasses: {} },
		SocialRewards: { CreatorFollowClaimed: false, CreatorName: "usingINales" },
		Quests: {},
		Achievements: {},
		Stats: deepCopy(profile.Stats),
		Domain: { Rank: 0, Essence: 0 },
		Continuum: { Rank: 0 },
		GuildBonuses: {},
		Guild: { Id: "" },
		Trade: { Locked: true },
		Mailbox: { Items: {}, Unread: 0 },
		Story: { Chapters: {} },
		Visitors: {},
	};
	if (isSet(Economy)) {
		const Specializations = require(shared.WaitForChild("Specializations") as ModuleScript) as { Snapshot(this: void, profile: Profile, economy: EconomyApi, now: number): unknown };
		state.Specialization = Specializations.Snapshot(profile, Economy!, now);
	}
	return state;
}

export = { build };
