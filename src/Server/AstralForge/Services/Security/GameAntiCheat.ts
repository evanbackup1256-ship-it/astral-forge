import { Service } from "@flamework/core";
import { Report } from "./SecurityLedger";
import ServerConfig from "../../ServerConfig";
import { d, Dict, EconomyApi, economyKit, Flux, isFiniteNumber, isTable, ModuleLogApi, req, SharedFolder, truthy } from "../LuaInterop";

interface PlayerState {
	LastCash: unknown;
	LastSeen: number;
	BaselineReady: boolean;
	LastRepairAt: number;
	LastRepairAction: string;
	LastRepairCount: number;
	LastAction: string;
	LastActionAt: number;
}

interface LevelDefinition {
	Id: string;
	MaxLevel: number;
}

interface AntiCheatConfig {
	Items: { Definitions: LevelDefinition[] };
	Machines: LevelDefinition[];
	Research: LevelDefinition[];
	GridUpgrades: LevelDefinition[];
	Boosts: Record<string, unknown>;
	Anomalies: {
		CoreTiers: Array<{ MaximumTargetBonus: number }>;
		MaximumTarget: number;
		PulseComboMax: number;
		LoadoutSlots: number;
	};
}

const RunService = game.GetService("RunService");

const Economy = economyKit("Economy") as EconomyApi;
const GameConfig = req<AntiCheatConfig>(SharedFolder().WaitForChild("GameConfig"));
const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.Parent!.WaitForChild("ModuleLog"));

const MAX_SAFE = 1e308;
const ROOT_CURRENCIES = ["Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash"];
const ITEM_DEFINITIONS: Record<string, LevelDefinition> = {};
for (const [, definition] of pairs(GameConfig.Items.Definitions)) {
	ITEM_DEFINITIONS[definition.Id] = definition;
}
const MACHINE_LEVELS: Record<string, LevelDefinition> = {};
for (const [, definition] of pairs(GameConfig.Machines)) {
	MACHINE_LEVELS[definition.Id] = definition;
}
const RESEARCH_LEVELS: Record<string, LevelDefinition> = {};
for (const [, definition] of pairs(GameConfig.Research)) {
	RESEARCH_LEVELS[definition.Id] = definition;
}
const GRID_LEVELS: Record<string, LevelDefinition> = {};
for (const [, definition] of pairs(GameConfig.GridUpgrades)) {
	GRID_LEVELS[definition.Id] = definition;
}

const clampNumber = (value: unknown, minimum: number, maximum: number): LuaTuple<[number, boolean]> => {
	const nextValue = isFiniteNumber(value) ? value : minimum;
	const clamped = math.clamp(nextValue, minimum, maximum);
	return $tuple(clamped, clamped !== value);
};

const clampSparseLevels = (map: unknown, byId: Record<string, LevelDefinition>): number => {
	if (!isTable(map)) {
		return 1;
	}
	let repairs = 0;
	for (const [key, value] of pairs(map)) {
		const definition = byId[key];
		if (definition === undefined) {
			map[key] = undefined;
			repairs += 1;
		} else {
			const [current, changed] = clampNumber(value, 0, definition.MaxLevel);
			if (current <= 0) {
				if (value !== undefined) {
					map[key] = undefined;
					repairs += 1;
				}
			} else if (changed) {
				map[key] = math.floor(current);
				repairs += 1;
			}
		}
	}
	return repairs;
};

const STAT_KEYS = [
	"PlayTime",
	"Taps",
	"MachinesBought",
	"ResearchBought",
	"CratesOpened",
	"ItemsFound",
	"ItemsSalvaged",
	"ShopPurchases",
	"AnomalyPulses",
	"AnomalyStabilizations",
	"AnomalyProtocols",
	"AnomalyDirectives",
	"OrdersCompleted",
	"PowerMoves",
	"ContinuumUpgrades",
	"Joins",
];

function stateOf(owner: { _players: Map<Player, PlayerState> }, player: Player): PlayerState {
	let state = owner._players.get(player);
	if (state) {
		return state;
	}
	state = {
		LastCash: 0,
		LastSeen: os.clock(),
		BaselineReady: false,
		LastRepairAt: -math.huge,
		LastRepairAction: "",
		LastRepairCount: 0,
		LastAction: "",
		LastActionAt: 0,
	};
	owner._players.set(player, state);
	return state;
}

/**
 * Anti-cheat as a list of repair rules. Each rule owns one part of the profile, fixes anything
 * out of range in place and returns how many fields it touched. Rules run in order, so a later
 * rule may read what an earlier one recorded on the shared context (vault reads `levelRepairs`).
 * Add a rule by appending to REPAIR_RULES; nothing else needs to change. The production-ceiling
 * velocity check runs after every rule and is the only one that can reject a transaction.
 */
interface RuleContext {
	/** Vault capacity the caller already computed this transaction, if any. */
	capacityHint?: Flux;
	/** Levels repaired by the "levels" rule; a non-zero value forces a fresh capacity read. */
	levelRepairs: number;
}

export interface RepairRule {
	id: string;
	describe: string;
	repair(profile: Dict, ctx: RuleContext): number;
}

const REPAIR_RULES: RepairRule[] = [
	{
		id: "currencies",
		describe: "Root currencies are non-negative and finite",
		repair(profile, ctx) {
			let repairs = 0;
			const persistKeys: Record<string, boolean | undefined> = { Cash: true, Vault: true, RunCash: true, LifetimeCash: true };
			for (const key of ROOT_CURRENCIES) {
				if (persistKeys[key]) {
					const persisted = Economy.Max(profile[key], 0);
					if (persisted !== profile[key]) {
						profile[key] = persisted;
						repairs += 1;
					}
				} else {
					const [value, changed] = clampNumber(profile[key], 0, MAX_SAFE);
					if (changed) {
						profile[key] = value;
						repairs += 1;
					}
				}
			}
			return repairs;
		},
	},
	{
		id: "levels",
		describe: "Machine, research and grid levels exist and stay within their max",
		repair(profile, ctx) {
			let repairs = 0;
			if (!isTable(profile.Machines)) {
				profile.Machines = {};
				repairs += 1;
			}
			if (!isTable(profile.Research)) {
				profile.Research = {};
				repairs += 1;
			}
			if (!isTable(profile.GridUpgrades)) {
				profile.GridUpgrades = {};
				repairs += 1;
			}
			const levelRepairs =
				clampSparseLevels(profile.Machines, MACHINE_LEVELS) +
				clampSparseLevels(profile.Research, RESEARCH_LEVELS) +
				clampSparseLevels(profile.GridUpgrades, GRID_LEVELS);
			ctx.levelRepairs = levelRepairs;
			repairs += levelRepairs;
			return repairs;
		},
	},
	{
		id: "vault",
		describe: "Vault never holds more than its capacity",
		repair(profile, ctx) {
			let repairs = 0;
			let capacityOk = true;
			let capacityResult: unknown = ctx.capacityHint;
			if (ctx.capacityHint === undefined || ctx.levelRepairs !== 0) {
				[capacityOk, capacityResult] = pcall(Economy.Capacity, profile, os.time());
			}
			if (capacityOk) {
				const nextVault = Economy.Min(profile.Vault, capacityResult);
				if (nextVault !== profile.Vault) {
					profile.Vault = nextVault;
					repairs += 1;
				}
			}
			return repairs;
		},
	},
	{
		id: "boost",
		describe: "The active boost is a real boost with a sane end time",
		repair(profile, ctx) {
			let repairs = 0;
			const activeBoost = profile.ActiveBoost;
			const boostValid =
				isTable(activeBoost) &&
				(activeBoost.Id === "" || GameConfig.Boosts[activeBoost.Id as string] !== undefined);
			if (!boostValid) {
				profile.ActiveBoost = { Id: "", EndsAt: 0 };
				repairs += 1;
			} else {
				const boost = d(activeBoost);
				const [endsAt, endsChanged] = clampNumber(boost.EndsAt, 0, 4_000_000_000);
				if (endsChanged) {
					boost.EndsAt = math.floor(endsAt);
					repairs += 1;
				}
			}
			return repairs;
		},
	},
	{
		id: "items",
		describe: "Inventory entries are real items, levels in range, equips point at owned items",
		repair(profile, ctx) {
			let repairs = 0;
			if (!isTable(profile.Items)) {
				profile.Items = {
					Inventory: {},
					Discovered: {},
					Equipped: {},
					Essence: 0,
					Keys: {},
					Pity: {},
					Shop: {},
					AutoSalvage: { Enabled: false, KeepNew: true, Rarities: {} },
				};
				repairs += 1;
			} else {
				const items = profile.Items;
				const [essence, essenceChanged] = clampNumber(items.Essence, 0, MAX_SAFE);
				if (essenceChanged) {
					items.Essence = essence;
					repairs += 1;
				}
				if (!isTable(items.Inventory)) {
					items.Inventory = {};
					repairs += 1;
				}
				if (!isTable(items.Equipped)) {
					items.Equipped = {};
					repairs += 1;
				}
				const inventory = d(items.Inventory);
				for (const [uid, item] of pairs(inventory)) {
					const definition = isTable(item) ? ITEM_DEFINITIONS[item.DefinitionId as string] : undefined;
					if (!typeIs(uid, "string") || !definition) {
						inventory[uid] = undefined;
						repairs += 1;
					} else {
						const entry = d(item);
						const [level, levelChanged] = clampNumber(entry.Level, 1, definition.MaxLevel);
						if (levelChanged) {
							entry.Level = math.floor(level);
							repairs += 1;
						}
					}
				}
				const equipped = d(items.Equipped);
				for (const [target, uid] of pairs(equipped)) {
					if (!typeIs(target, "string") || !typeIs(uid, "string") || !truthy(inventory[uid])) {
						equipped[target] = undefined;
						repairs += 1;
					}
				}
			}
			return repairs;
		},
	},
	{
		id: "anomaly",
		describe: "Anomaly charge, core tier and loadout stay within config",
		repair(profile, ctx) {
			let repairs = 0;
			if (!isTable(profile.Anomaly)) {
				profile.Anomaly = { Charge: 0, Fragments: 0, Stabilizations: 0, Chain: 0, BestChain: 0 };
				repairs += 1;
			} else {
				const anomaly = profile.Anomaly;
				let maxTargetBonus = 0;
				for (const [, tierConfig] of pairs(GameConfig.Anomalies.CoreTiers)) {
					maxTargetBonus = math.max(maxTargetBonus, tierConfig.MaximumTargetBonus);
				}
				const [charge, chargeChanged] = clampNumber(
					anomaly.Charge,
					0,
					(GameConfig.Anomalies.MaximumTarget + maxTargetBonus) * 1.5,
				);
				const [fragments, fragmentsChanged] = clampNumber(anomaly.Fragments, 0, MAX_SAFE);
				if (chargeChanged) {
					anomaly.Charge = charge;
					repairs += 1;
				}
				if (fragmentsChanged) {
					anomaly.Fragments = math.floor(fragments);
					repairs += 1;
				}

				const maxCoreTier = GameConfig.Anomalies.CoreTiers.size();
				const orZero = (value: unknown) => (truthy(value) ? value : 0);
				const [coreTier, coreTierChanged] = clampNumber(orZero(anomaly.CoreTier), 0, maxCoreTier);
				const [coreXP, coreXPChanged] = clampNumber(orZero(anomaly.CoreXP), 0, MAX_SAFE);
				const [combo, comboChanged] = clampNumber(orZero(anomaly.Combo), 0, GameConfig.Anomalies.PulseComboMax);
				const [bestCombo, bestComboChanged] = clampNumber(
					orZero(anomaly.BestCombo),
					0,
					GameConfig.Anomalies.PulseComboMax,
				);
				if (coreTierChanged) {
					anomaly.CoreTier = math.floor(coreTier);
					repairs += 1;
				}
				if (coreXPChanged) {
					anomaly.CoreXP = coreXP;
					repairs += 1;
				}
				if (comboChanged) {
					anomaly.Combo = math.floor(combo);
					repairs += 1;
				}
				if (bestComboChanged) {
					anomaly.BestCombo = math.floor(bestCombo);
					repairs += 1;
				}
				if (!isTable(anomaly.Loadout)) {
					anomaly.Loadout = {};
					repairs += 1;
				} else if ((anomaly.Loadout as unknown as defined[]).size() > GameConfig.Anomalies.LoadoutSlots) {
					const loadout = anomaly.Loadout as unknown as defined[];
					const trimmed: defined[] = [];
					for (let index = 0; index < GameConfig.Anomalies.LoadoutSlots; index++) {
						trimmed[index] = loadout[index];
					}
					anomaly.Loadout = trimmed;
					repairs += 1;
				}
			}
			return repairs;
		},
	},
	{
		id: "flags",
		describe: "Unlimited money only exists in Studio",
		repair(profile, ctx) {
			let repairs = 0;
			if (!isTable(profile.Flags)) {
				profile.Flags = {
					TutorialDone: false,
					TutorialStep: 1,
					TutorialRewardClaimed: false,
					LastSeenVersion: "",
					UnlimitedMoney: false,
				};
				repairs += 1;
			} else if (!RunService.IsStudio() && truthy(profile.Flags.UnlimitedMoney)) {
				profile.Flags.UnlimitedMoney = false;
				repairs += 1;
			}
			return repairs;
		},
	},
	{
		id: "stats",
		describe: "Lifetime stats are non-negative",
		repair(profile, ctx) {
			let repairs = 0;
			if (isTable(profile.Stats)) {
				const stats = profile.Stats;
				if (stats.Collected !== undefined) {
					const persisted = Economy.Max(stats.Collected, 0);
					if (persisted !== stats.Collected) {
						stats.Collected = persisted;
						repairs += 1;
					}
				}
				for (const key of STAT_KEYS) {
					const [value, changed] = clampNumber(stats[key], 0, MAX_SAFE);
					if (changed) {
						stats[key] = value;
						repairs += 1;
					}
				}
			}
			return repairs;
		},
	},
	{
		id: "meta",
		describe: "Save revision is a non-negative integer",
		repair(profile, ctx) {
			let repairs = 0;
			if (isTable(profile.Meta)) {
				const [revision, revisionChanged] = clampNumber(profile.Meta.Revision, 0, MAX_SAFE);
				if (revisionChanged) {
					profile.Meta.Revision = math.floor(revision);
					repairs += 1;
				}
			}
			return repairs;
		},
	},
];

/** Repairs made per rule since the server started, for the admin panel. */
const RULE_HITS: Record<string, number> = {};

/** One row per rule with how often it has repaired a profile on this server. */
export function RuleStats(): Array<{ Id: string; Describe: string; Repairs: number }> {
	return REPAIR_RULES.map((rule) => ({ Id: rule.id, Describe: rule.describe, Repairs: RULE_HITS[rule.id] ?? 0 }));
}

@Service({ loadOrder: 2 })
export class GameAntiCheat {
	_players = new Map<Player, PlayerState>();

	/**
	 * `capacityHint` is the Vault capacity the caller computed for this profile in the same
	 * transaction (the production tick). It is used only when this pass repaired no machine,
	 * research or grid levels, since those are the inputs that could change it.
	 */
	Observe(player: Player, action: string, profile: unknown, capacityHint?: Flux): LuaTuple<[boolean, boolean]> {
		if (!isTable(profile)) {
			return $tuple(false, false);
		}
		const state = stateOf(this, player);
		const now = os.clock();
		if (state.LastAction === action && now - state.LastActionAt < 0.2) {
			// Coalesced repeat: the full repair pass ran under 0.2s ago, so skip it, but still
			// check this credit against the production ceiling. The window is not extended, so
			// a steady stream of repeats still gets a full pass at least every 0.2s.
			const wouldReject = this._checkVelocity(player, action, profile, state, true);
			if (!wouldReject) {
				state.LastCash = profile.Cash;
				state.LastSeen = os.clock();
			}
			return $tuple(true, wouldReject);
		}
		state.LastAction = action;
		state.LastActionAt = now;
		const ctx: RuleContext = { capacityHint, levelRepairs: 0 };
		let repairs = 0;
		for (const rule of REPAIR_RULES) {
			const fixed = rule.repair(profile, ctx);
			if (fixed > 0) {
				repairs += fixed;
				RULE_HITS[rule.id] = (RULE_HITS[rule.id] ?? 0) + fixed;
			}
		}

		if (repairs > 0) {
			const now2 = os.clock();
			if (state.LastRepairAction !== action || state.LastRepairCount !== repairs || now2 - state.LastRepairAt >= 30) {
				state.LastRepairAction = action;
				state.LastRepairCount = repairs;
				state.LastRepairAt = now2;
				player.SetAttribute("AF_LastRepair", action);
			}
		}

		const wouldReject = this._checkVelocity(player, action, profile, state, false);

		if (!wouldReject) {
			state.LastCash = profile.Cash;
			state.LastSeen = os.clock();
			state.BaselineReady = true;
		}
		return $tuple(repairs === 0, wouldReject);
	}

	/** Production-ceiling check on the Cash credited since the last accepted baseline. */
	_checkVelocity(player: Player, action: string, profile: Dict, state: PlayerState, coalesced: boolean): boolean {
		let wouldReject = false;
		const skipVelocity =
			!state.BaselineReady ||
			action === "Load" ||
			action === "Production" ||
			action === "AutoForge" ||
			action === "Maintenance";
		if (!skipVelocity) {
			const elapsed = math.max(0, os.clock() - state.LastSeen);
			if ((coalesced || elapsed > 0.05) && elapsed < 3600) {
				const delta = Economy.Sub(profile.Cash, state.LastCash);
				if (Economy.Gt(delta, 0)) {
					const [productionOk, productionRate] = pcall(Economy.Production, profile, os.time());
					if (productionOk) {
						const [offlineOk, offlineHours] = pcall(Economy.OfflineHours, profile);
						let offlineSeconds = 86400;
						if (offlineOk && typeIs(offlineHours, "number")) {
							offlineSeconds = offlineHours * 3600;
						}
						const burstSeconds = elapsed + offlineSeconds;
						const CEILING_MULTIPLIER = 12;
						const ceiling: Flux = Economy.Mul(Economy.Mul(productionRate, burstSeconds), CEILING_MULTIPLIER);
						const ceilingFloor = Economy.Max(ceiling, 10_000);
						if (Economy.Gt(delta, ceilingFloor)) {
							// Flag the containing transaction so callers can discard an illegal credit when enforcement is enabled.
							wouldReject = (ServerConfig.GameAntiCheat as Dict).EnforcementEnabled === true;
							Report(
								player,
								"impossible-progress",
								4,
								"%s Cash rose %s in %.1fs, ceiling %s".format(
									action,
									tostring(delta),
									elapsed,
									tostring(ceilingFloor),
								),
							);
							ModuleLog.Every(
								"velocity:%d".format(player.UserId),
								30,
								"Security",
								"u=%d Cash jump exceeded production ceiling (%s)".format(
									player.UserId,
									wouldReject ? "rejected" : "observed only, not corrected",
								),
							);
						}
					}
				}
			}
		}
		return wouldReject;
	}

	SyncBaseline(player: Player, profile: unknown): void {
		if (!isTable(profile)) {
			return;
		}
		const state = stateOf(this, player);
		state.LastCash = profile.Cash;
		state.LastSeen = os.clock();
		state.BaselineReady = true;
	}

	Forget(player: Player): void {
		this._players.delete(player);
	}
}

