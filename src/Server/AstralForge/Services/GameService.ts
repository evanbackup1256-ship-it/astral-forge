import { Service } from "@flamework/core";
import BazaarModule = require("./Gameplay/Bazaar");
import { ConvergenceService } from "./ConvergenceService";
import { DataService } from "./DataService";
import { AdminService } from "./AdminService";
import { WorldService } from "./WorldService";
import { Security } from "./Security/Security";
import { SessionGate } from "./Security/SessionGate";
import { GameAntiCheat } from "./Security/GameAntiCheat";
import { PlayerAnalytics } from "./PlayerAnalytics";
import { PlayerBadges } from "./PlayerBadges";
import { SpecializationService } from "./SpecializationService";
// GameService: the gameplay hub (remotes, runtime state, every player action).
import { Dict, isTable, num, truthy } from "./LuaInterop";
import { PayloadEvent, ServerEvents, ServerFunctions } from "../Runtime/ServerNetwork";
import { FluxSurgeService } from "./FluxSurgeService";
import { GuildService } from "./Gameplay/GuildService";
import { RemoteFirewall } from "./Security/RemoteFirewall";
import * as ActionBuckets from "./Security/ActionBuckets";
import * as PayloadShape from "./Security/PayloadShape";
import { Ledger, Report } from "./Security/SecurityLedger";
import { ServerEventService } from "./Gameplay/ServerEventService";
import AnomalyModule = require("./Gameplay/Anomaly");
import ForgeEchoModule = require("./Gameplay/ForgeEcho");
import LabModule = require("./Gameplay/Lab");
import RelicRigModule = require("./Gameplay/RelicRigs");
import ProgressionModule = require("./Gameplay/Progression");
import { MatterRuntime } from "./MatterRuntime";
import * as PolicyGate from "./PolicyGate";
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";
import * as ProfileStyle from "../../../Shared/AstralForge/Shared/ProfileStyle";
import * as SeenHints from "../../../Shared/AstralForge/Shared/SeenHints";
import * as NavRoutes from "../../../Shared/AstralForge/Shared/NavRoutes";

// Most of what GameService touches comes back from kits as opaque values, so module tables are typed as dot-called functions and service instances as
// colon-called methods. Values coming back are narrowed where they are used.
type Fn = (this: void, ...args: unknown[]) => unknown;
type Method = (this: object, ...args: unknown[]) => unknown;
type Kit = Record<string, Fn>;
type Svc = Record<string, Method>;
type Profile = Dict;
type Response = Dict;


interface GameConfigShape {
	Game: Dict;
	Items: Dict;
	Economy: Dict;
	Operations: Dict;
	Overcharge: Dict;
	Social: Dict;
	Continuum: Dict;
	Domain: Dict;
	Boosts: Record<string, unknown>;
	Story: Dict[];
	Mail: Dict[];
	[key: string]: unknown;
}

// per-player server-side state kept between requests
type Runtime = Dict;

// Luau `a or b()`: b only runs when a is nil or false
function orElse<T, U>(value: T, fallback: () => U): Exclude<T, undefined | false> | U {
	return truthy(value) ? (value as Exclude<T, undefined | false>) : fallback();
}

// Luau `x or {}` for a value read as a table
function orEmpty(value: unknown, fallback: () => object): Dict {
	return (truthy(value) ? value : fallback()) as Dict;
}


const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const MarketplaceService = game.GetService("MarketplaceService");
const HttpService = game.GetService("HttpService");
const ServerStorage = game.GetService("ServerStorage");
const Workspace = game.GetService("Workspace");

const root = script.Parent!.Parent!;
const modules = () => root.WaitForChild("Modules");
const shared = () => ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const mod = <T = Kit>(parent: Instance, name: string): T => require(parent.WaitForChild(name) as ModuleScript) as T;
const member = <T = Kit>(parent: Instance, name: string, memberName: string): T =>
	(require(parent.WaitForChild(name) as ModuleScript) as (this: void, m: string) => unknown)(memberName) as T;

const ModuleLog = mod<{
	Info: (this: void, scope: string, message: string, params?: Dict) => void;
	Warn: (this: void, scope: string, message: string, params?: Dict) => void;
	Error: (this: void, scope: string, message: string, params?: Dict) => void;
	Player: (this: void, player: Player, message: string, params?: Dict) => void;
	Every: (this: void, key: string, seconds: number, scope: string, message: string) => boolean;
	[name: string]: unknown;
}>(root, "ModuleLog");
const Economy = member(modules(), "EconomyMath", "Economy");
const FoundryService = mod(modules(), "FoundryService");
const Format = member(modules(), "ProfileMath", "Format");
const LeaderboardCodec = mod(modules(), "LeaderboardCodec");
const ProgressionGate = member(modules(), "EconomyMath", "ProgressionGate");
const SharedDataSuite = mod<(this: void, name: string) => unknown>(shared(), "SharedData");
const LevelRewards = SharedDataSuite("LevelRewards") as Kit;
const AscensionMath = mod(shared(), "AscensionMath");
const RebirthMath = mod(shared(), "RebirthMath");
const DomainLattice = mod(shared(), "DomainLattice");
const OmegaMath = mod(shared(), "OmegaMath");
const ForgeLevels = SharedDataSuite("ForgeLevels") as Kit;
const RebirthGate = member(modules(), "EconomyMath", "RebirthGate");
const TradeDesk = member(modules(), "TradeSuite", "TradeDesk");
const TradeSettle = member(modules(), "TradeSuite", "TradeSettle");
const TradeChatFilter = member(modules(), "TradeSuite", "TradeChatFilter");
const TradeRecovery = member(modules(), "TradeSuite", "TradeRecovery");
const TradeHistory = mod(shared(), "TradeHistory");
const ChatRules = mod(shared(), "ChatRules");
const CrateRoll = member(modules(), "EconomyMath", "CrateRoll");
const CrateRollResolver = mod(modules(), "CrateRollResolver");
const CrateConfig = mod<Dict>(shared(), "CrateConfig");
const ShopGrantEligibility = member(modules(), "ProfileMath", "ShopGrantEligibility");
const CommandActionValidators = member(modules(), "ProfileMath", "CommandActionValidators");
const SocialBoost = member(modules(), "ProfileMath", "SocialBoost");
const ItemSalvage = member(modules(), "ProfileMath", "ItemSalvage");
const VisitSnapshot = member(modules(), "ProfileMath", "VisitSnapshot");
const PublicPlayerRecord = member(modules(), "ProfileMath", "PublicPlayerRecord");
const ReportLedger = member(modules(), "ProfileMath", "ReportLedger");
const SettingsSeal = member(modules(), "ProfileMath", "SettingsSeal");
const UnlimitedMoneySeal = member(modules(), "ProfileMath", "UnlimitedMoneySeal");
const StoryMailSnapshot = member(modules(), "ProfileMath", "StoryMailSnapshot");
const VisitorList = member(modules(), "ProfileMath", "VisitorList");
const AutoSalvageSnapshot = member(modules(), "ProfileMath", "AutoSalvageSnapshot");
const OverchargeCombo = member(modules(), "EconomyMath", "OverchargeCombo");
const RankBracket = member(modules(), "ProfileMath", "RankBracket");
const ActionFeatureMaps = member<Dict>(modules(), "ProfileMath", "ActionFeatureMaps");
const ActionResponse = member(modules(), "ProfileMath", "ActionResponse");
const GeneralBoardValue = member(modules(), "ProfileMath", "GeneralBoardValue");
const TelemetryMath = member(modules(), "ProfileMath", "TelemetryMath");
const UtcClockMath = member(modules(), "ProfileMath", "UtcClockMath");
const DataSanitizeMath = mod(modules(), "DataSanitizeMath");
const ProfileBagMath = mod(modules(), "ProfileBagMath");
const ProfileClampMath = member(modules(), "ProfileMath", "ProfileClampMath");
const CommandMath = mod(modules(), "CommandMath");
const ContinuumDomainMath = member(modules(), "EconomyMath", "ContinuumDomainMath");
const ItemLoadoutMath = member(modules(), "ProfileMath", "ItemLoadoutMath");
const GuildMath = member(modules(), "OpsMath", "GuildMath");
const ForgePathClaim = member(modules(), "EconomyMath", "ForgePathClaim");
const OfflineProjection = member(modules(), "EconomyMath", "OfflineProjection");
const ReceiptLedger = mod(modules(), "ReceiptLedger");
const GameConfig = mod<GameConfigShape>(shared(), "GameConfig");
const Protocol = mod<{ Actions: Record<string, string>; [key: string]: unknown }>(shared(), "Protocol");
const MonetizationConfig = SharedDataSuite("MonetizationConfig") as Dict;
const ZoneUnlock = SharedDataSuite("ZoneUnlock") as Kit;
const MobileLayoutSlots = mod(shared(), "MobileLayoutSlots");
const CrateExpansion = mod<Kit>(shared(), "CrateExpansion");
const ProgressionService = ProgressionModule as unknown as Kit;
const AnomalyService = AnomalyModule as unknown as Kit;
const LabService = LabModule as unknown as Kit;
const RelicRigs = RelicRigModule as unknown as Kit;
const ForgeEchoService = ForgeEchoModule as unknown as Kit;
const BazaarService = BazaarModule as unknown as Kit;
const Specializations = mod<Kit>(shared(), "Specializations");
const GuildCommunity = mod(script.Parent!, "GuildCommunity");
const ChatService = mod(script.Parent!, "ChatService");
const CrewService = mod(script.Parent!, "CrewService");
const ServerConfig = mod<Dict>(root, "ServerConfig");

// read-only stand-in for an empty anomaly action queue (the 5 Hz tick reads it every pass)
const NO_PENDING_ACTIONS: ReadonlyArray<string> = table.freeze([]);

// guild kick/ban/reconcile paths reset bonuses
const emptyBonuses = () => GuildMath.EmptyBonuses();

const MAX_SAFE_CURRENCY = 1e308;
const AUTO_FORGE_INTERVAL = 2;
const PROFILE_MAINTENANCE_INTERVAL = 10;
const GUILD_REFRESH_INTERVAL = 30;
const GLOBAL_LB_PAGE = 25;
const RANK_PING_INTERVAL = 20;
const RANK_PING_BOARD = "Flux";
const RANK_PING_BOARD_LABEL = "Lifetime Flux";
const RANK_PING_BRACKETS = RankBracket.DEFAULT_BRACKETS;
const RANK_PING_UNRANKED = RankBracket.UNRANKED;
const GUILD_ACTIVITY_MILESTONE_STEP = 250_000;

const applySocialBoost = (profile: Profile, friendCount: number, premium: boolean): boolean =>
	SocialBoost.Apply(profile, friendCount, premium, GameConfig.Social) as boolean;

const GENERAL_BOARD_STORE_NAMES: Record<string, string> = {
	Flux: ServerConfig.LeaderboardStoreName as string,
	Rebirths: ServerConfig.RebirthLeaderboardStoreName as string,
	PlayTime: ServerConfig.PlayTimeLeaderboardStoreName as string,
	Dust: ServerConfig.DustLeaderboardStoreName as string,
	Cores: ServerConfig.CoresLeaderboardStoreName as string,
	Domain: ServerConfig.DomainLeaderboardStoreName as string,
	Worlds: ServerConfig.WorldLeaderboardStoreName as string,
	Crates: ServerConfig.CratesLeaderboardStoreName as string,
	Finds: ServerConfig.FindsLeaderboardStoreName as string,
	Ore: ServerConfig.OreLeaderboardStoreName as string,
	Wardens: ServerConfig.WardensLeaderboardStoreName as string,
	Orders: ServerConfig.OrdersLeaderboardStoreName as string,
	Stars: ServerConfig.StarsLeaderboardStoreName as string,
	Cipher: ServerConfig.CipherLeaderboardStoreName as string,
};

const generalBoardValue = (profile: Profile, id: string) => GeneralBoardValue.Of(profile, id, Economy.Persist);

const anomalyChargeByAction = ActionFeatureMaps.ANOMALY_CHARGE as Record<string, unknown>;


const encodeTelemetry = (
	revision: unknown,
	settings: unknown,
	cash: unknown,
	vault: unknown,
	production: unknown,
	capacity: unknown,
	cores: unknown,
	stardust: unknown,
) => TelemetryMath.Encode(revision, settings, cash, vault, production, capacity, cores, stardust, Economy.AsNumber);

const anomalySignalByAction = ActionFeatureMaps.ANOMALY_SIGNAL as Record<string, unknown>;
const featureByAction = ActionFeatureMaps.FEATURE as Record<string, unknown>;

const enforceUnlimitedMoney = (profile: Profile) => {
	UnlimitedMoneySeal.Apply(profile, MAX_SAFE_CURRENCY, Economy);
};

const itemById: Record<string, Dict> = {};
const crateById: Record<string, Dict> = {};
const itemOfferById: Record<string, Dict> = {};
const storyById: Record<string, Dict> = {};
const mailById: Record<string, Dict> = {};
for (const [, definition] of pairs(GameConfig.Items.Definitions as Dict[])) {
	itemById[definition.Id as string] = definition;
}
for (const [, crate] of pairs(GameConfig.Items.Crates as Dict[])) {
	crateById[crate.Id as string] = crate;
}
for (const [, offer] of pairs(GameConfig.Items.ShopOffers as Dict[])) {
	itemOfferById[offer.Id as string] = offer;
}
for (const [, chapter] of pairs(GameConfig.Story)) {
	storyById[chapter.Id as string] = chapter;
}
for (const [, message] of pairs(GameConfig.Mail)) {
	mailById[message.Id as string] = message;
}

const utcDay = (): number => UtcClockMath.Day(os.time()) as number;

const nextUtcMidnight = (): number => UtcClockMath.NextMidnight(os.time()) as number;

const offerStockMax = (offer: unknown): number => ShopGrantEligibility.StockMax(offer) as number;

const inventoryCount = (profile: Profile): number => {
	const items = ProfileBagMath.EnsureItems(profile) as Dict;
	return ShopGrantEligibility.InventoryCount(items.Inventory) as number;
};

const ensureItemShop = (profile: Profile): boolean => {
	const items = ProfileBagMath.EnsureItems(profile) as Dict;
	return ShopGrantEligibility.EnsureShop(items.Shop, GameConfig.Items.ShopOffers, utcDay()) as boolean;
};

const ensureStats = (profile: Profile) => ProfileBagMath.EnsureStats(profile) as Dict;

const bumpStat = (profile: Profile, key: string, amount?: number) => ProfileBagMath.BumpStat(profile, key, amount);

// first time a relic rig is fully socketed: mark it, pay it, and describe it
const grantLitRigs = (profile: Profile): LuaTuple<[number, string]> => {
	const fresh = RelicRigs.Settle(profile) as Array<{ Name: string; Reward: Dict; Percent: number; Kind: string }>;
	if (fresh.size() === 0) {
		return $tuple(0, "");
	}
	const parts: string[] = [];
	for (const entry of fresh) {
		const paid = ProgressionService.ApplyReward(profile, entry.Reward, Economy.Production(profile)) as string;
		const effect = RelicRigs.effectText(entry) as string;
		if (typeIs(paid, "string") && paid !== "") {
			parts.push(`${entry.Name}: ${effect} (${paid})`);
		} else {
			parts.push(`${entry.Name}: ${effect}`);
		}
	}
	return $tuple(fresh.size(), parts.join(", "));
};

const ensureActiveBoost = (profile: Profile) => ProfileBagMath.EnsureActiveBoost(profile) as Dict;

const ensureBoostInventory = (profile: Profile) => ProfileBagMath.EnsureBoostInventory(profile) as Dict;

const ensureCommandMastery = (profile: Profile) => {
	const command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId) as Dict;
	profile.Command = command;
	return command.MachineMastery as Dict;
};

const copyDictionary = (source: unknown) => DataSanitizeMath.DeepCopy(source);

const responseError = (message: unknown): Response => ActionResponse.Error(message) as Response;

// session fields that legitimately change when the client retries a TxnId
const TXN_PRINT_IGNORE: Record<string, boolean> = { Gen: true, N: true, TxnId: true };

const responseSuccess = (message?: unknown, extra?: unknown): Response =>
	ActionResponse.Success(message, extra) as Response;

const publicPlayerRecord = (player: Player, profile: Profile, viewer: Player, presence: unknown) =>
	PublicPlayerRecord.Build(player, profile, viewer, presence, {
		Economy: Economy,
	}) as Dict;

const buildVisitSnapshot = (player: Player, profile: Profile) => VisitSnapshot.Build(player, profile, Economy);

// extracts a user id the way every social action does: ExtractUserId when present, then coerce
const extractUserId = (raw: unknown): unknown =>
	RemoteFirewall.ExtractUserId !== undefined ? RemoteFirewall.ExtractUserId(raw) : raw;

const PRESENCE_PAGES: Record<string, boolean> = {
	Overview: true,
	Workshop: true,
	Inventory: true,
	Research: true,
	StarGrid: true,
	Echoes: true,
	Continuum: true,
	Lab: true,
	Anomaly: true,
	Worlds: true,
	Missions: true,
	Wheel: true,
	Bazaar: true,
	Rewards: true,
	Command: true,
	Story: true,
	Mail: true,
	Chat: true,
	Crew: true,
	Milestones: true,
	Convergence: true,
	Leaderboards: true,
	Trade: true,
	Credits: true,
	Admin: true,
	Settings: true,
	Shop: true,
};

// the Studio check every social action uses; never throws
const studioCheck = (): boolean => {
	let isStudio = false;
	pcall(() => {
		const rs = game.GetService("RunService");
		if (rs && typeIs((rs as unknown as Dict).IsStudio, "function")) {
			isStudio = rs.IsStudio();
		}
	});
	return isStudio;
};

const StoreAccess = require(root.WaitForChild("Modules").WaitForChild("StoreAccess") as ModuleScript) as Kit;
const getOrderedStore = StoreAccess.ordered;

const reportLedger = ReportLedger.new() as Svc;
Players.PlayerRemoving.Connect((leaving) => {
	reportLedger.forgetReporter(leaving.UserId);
});

const itemSalvageValue = (instance: Dict, definition: Dict): number => {
	const rarity = (GameConfig.Items.Rarities as Record<string, Dict | undefined>)[definition.Rarity as string];
	const rank = rarity && truthy(rarity.Rank) ? rarity.Rank : 1;
	return ItemSalvage.Value(instance.Level, rank) as number;
};

const shopShared = (): LuaTuple<[Kit, Kit]> => {
	return $tuple(SharedDataSuite("ShopCatalog") as Kit, SharedDataSuite("RelicSystem") as Kit);
};

const spendShopCurrency = (profile: Profile, currency: string, price: number): string | undefined => {
	if (currency !== "Stardust" && currency !== "Cores") {
		return "That offer can't be bought with " + tostring(currency) + ".";
	}
	const have = tonumber(profile[currency]) ?? 0;
	if (have < price) {
		return string.format(
			"You need %s more %s.",
			(Format.Number as Fn)(price - have) as string,
			string.lower(currency),
		);
	}
	profile[currency] = have - price;
	return undefined;
};

const ensureAutoSalvage = (profile: Profile) => ProfileBagMath.EnsureAutoSalvage(profile) as Dict;

const progressionNumber = (value: unknown): number => Economy.AsNumber(value) as number;

const clampProgressionNumbers = (profile: Profile) => {
	ProfileClampMath.ClampProgressionNumbers(profile, Economy.Persist, MAX_SAFE_CURRENCY);
};

const OVERCHARGE_COMBO_WINDOW = GameConfig.Overcharge.ComboWindow as number;
const OVERCHARGE_COMBO_MAX = GameConfig.Overcharge.ComboMax as number;
const OVERCHARGE_COMBO_BONUS = GameConfig.Overcharge.ComboBonusPerStack as number;

const overchargeComboWindow = (_profile: unknown): number => OverchargeCombo.Window(OVERCHARGE_COMBO_WINDOW) as number;

const overchargeComboMultiplier = (_profile: unknown, combo: number): number =>
	OverchargeCombo.Multiplier(combo, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS) as number;

// The full snapshot is ~350 KB (the star grid alone is ~200 KB) and goes out every few seconds.
// Sections that are identical to the ones this player was last sent are left out and listed in
// `Reused`; the client fills them back in from its previous copy. Every so often a full snapshot
// goes out anyway so the two sides can never drift.
const FULL_SNAPSHOT_EVERY = 60;
// true = same, false = different, nil = no differences found but a shared table was met: the
// very same table may have been edited in place since it was sent, so it can't vouch for itself
const sameValue = (left: unknown, right: unknown, depth: number): boolean | undefined => {
	if (!typeIs(left, "table") || !typeIs(right, "table")) {
		return left === right;
	}
	if (rawequal(left, right) || depth > 24) {
		return undefined;
	}
	let unsure = false;
	for (const [key, value] of pairs(left as Dict)) {
		const verdict = sameValue(value, rawget(right, key), depth + 1);
		if (verdict === false) {
			return false;
		} else if (verdict === undefined) {
			unsure = true;
		}
	}
	for (const [key] of pairs(right as Dict)) {
		if (rawget(left, key) === undefined) {
			return false;
		}
	}
	return unsure ? undefined : true;
};
const fingerprint = (value: unknown): string | undefined => {
	const [ok, encoded] = pcall(() => HttpService.JSONEncode(value));
	return ok ? encoded : undefined;
};

// runs one AnomalyService call inside a mutation and hands back what it reported
const anomalyCall = (
	owner: { _mutate(player: Player, callback: (profile: Profile) => unknown, incrementRevision?: boolean): Response },
	player: Player,
	run: (profile: Profile) => LuaTuple<[unknown, unknown, unknown]>,
): LuaTuple<[Response, Dict | undefined]> => {
	let details: Dict | undefined = undefined;
	const result = owner._mutate(player, (profile: Profile) => {
		const [success, message, payload] = run(profile);
		details = payload as Dict | undefined;
		return truthy(success) ? responseSuccess(message, payload) : responseError(message);
	});
	return $tuple(result, details as Dict | undefined);
};

// the rebirth ledger, normalized; saves from before it start counting from the rebirths already spent
const rebirthLedger = (profile: Profile, now: number): Dict => {
	let seed: number | undefined = undefined;
	if (profile.Rebirth === undefined) {
		seed =
			(num(profile.Rebirths) ?? 0) +
			(isTable(profile.Domain) ? (num(profile.Domain.TotalRebirthsSpent) ?? 0) : 0) +
			(isTable(profile.Ascension) ? (num(profile.Ascension.RebirthsSpent) ?? 0) : 0);
	}
	profile.Rebirth = RebirthMath.ensure(profile.Rebirth, now, seed);
	return profile.Rebirth as Dict;
};

// the facts a vow is judged on, and the flux this run would convert
const rebirthRun = (profile: Profile, now: number, ledger: Dict): LuaTuple<[Dict, unknown]> => {
	let kinds = 0;
	for (const [, level] of pairs(orEmpty(profile.Machines, () => ({})))) {
		if (typeIs(level, "number") && level >= 1) {
			kinds += 1;
		}
	}
	const rebirthConfig = orEmpty(GameConfig.Economy.Rebirth, () => ({}));
	const bank =
		rebirthConfig.BankVaultIntoRun !== false ? Economy.Add(profile.RunCash, profile.Vault) : profile.RunCash;
	const ratio = (Economy.AsNumber(bank) as number) / math.max(1, GameConfig.Economy.PrestigeRequirement as number);
	return $tuple(
		{ Seconds: now - (ledger.RunStartedAt as number), Zone: profile.Zone, MachineKinds: kinds, Ratio: ratio },
		bank,
	);
};

// cores and stardust before the ledger's own multipliers, or nil when the run can't convert yet
const rebirthBase = (profile: Profile, bank: unknown): LuaTuple<[unknown, number]> => {
	let reward = Economy.PrestigeReward(bank);
	if (!truthy(RebirthGate.CanRebirth(reward, Economy.Gte))) {
		return $tuple(undefined, 0);
	}
	reward = Economy.Max(
		1,
		Economy.Floor(Economy.Mul(reward, 1 + (Economy.DomainTreeBonus(profile, "RebirthYield") as number))),
	);
	reward = Economy.Floor(Economy.Mul(reward, Economy.AscensionEffect(profile, "Cores")));
	const rebirthConfig = orEmpty(GameConfig.Economy.Rebirth, () => ({}));
	const dust = RebirthGate.StardustReward(
		Economy.AsNumber(reward),
		num(rebirthConfig.StardustSqrtScale) ?? 5,
		num(rebirthConfig.StardustMinimum) ?? 4,
	) as number;
	return $tuple(reward, dust);
};

// machines a keepsake may carry: ones that live in the first world and are open after this rebirth
const keepsakeAllowed = (profile: Profile) => {
	return (id: string): boolean => {
		const machine = Economy.GetMachine(id) as Dict | undefined;
		return (
			machine !== undefined &&
			(num(machine.RequiredZone) ?? 1) <= 1 &&
			truthy(RebirthGate.MeetsRequired((num(profile.Rebirths) ?? 0) + 1, machine.RequiredRebirths))
		);
	};
};

@Service({ loadOrder: 4 })
export class GameService {
	_data!: Svc;
	_world!: Svc;
	_fluxSurge: Svc | undefined;
	_state!: PayloadEvent;
	_toast!: PayloadEvent;
	_effect!: PayloadEvent;
	_security!: Dict;
	_admin: Svc | undefined;
	_runtime!: Map<Player, Runtime>;
	_visiting!: Map<Player, number>;
	_visitors!: Map<number, Map<Player, boolean>>;
	_presence!: Map<number, Dict>;
	_matter!: MatterRuntime;
	_matterAccumulator!: number;
	_rankPingAccumulator!: number;
	_rankPingBusy!: boolean;
	_firewall!: Svc;
	_session!: Svc;
	_antiCheat!: Svc;
	_analytics!: Svc;
	_badges!: Svc;
	_convergence!: Svc;
	_events!: Svc;
	_guilds!: Svc;
	_guildCommunity!: Svc;
	_chat!: Svc;
	_crews!: Svc;
	_trades!: Svc;
	_random!: Random;
	_heartbeat: RBXScriptConnection | undefined;
	_playerAddedConnection: RBXScriptConnection | undefined;
	_playerRemovingConnection: RBXScriptConnection | undefined;
	_characterConnections!: Map<Player, RBXScriptConnection>;
	_joining!: Map<Player, unknown>;
	_running!: boolean;
	_leaderboardStores!: Record<string, unknown>;
	_playerNameCache!: Map<number, Dict>;
	_nameLookupPending!: Map<number, boolean>;
	_nameCachePruneAt!: number;
	_globalBoardCache!: Record<string, Dict | undefined>;
	_friendshipCache!: Record<string, Dict | undefined>;
	_queuedStatePushes!: Map<Player, thread>;
	_socialBoostScheduled!: boolean;
	_socialBoostDirty!: boolean;
	_socialBoostWorker: thread | undefined;
	_backgroundWorkers!: Map<object, thread>;
	_saveFailedToastAt!: Map<Player, number>;
	[key: string]: unknown;

	_visitorList(host: Player) {
		return VisitorList.Build(this._visitors.get(host.UserId), (visitor: Player) => visitor.Parent === Players);
	}

	_clearVisit(visitor: Player, notifyHost: boolean) {
		const hostUserId = this._visiting.get(visitor);
		if (hostUserId === undefined) {
			return;
		}
		this._visiting.delete(visitor);
		const bucket = this._visitors.get(hostUserId);
		if (bucket) {
			bucket.delete(visitor);
			if (bucket.size() === 0) {
				this._visitors.delete(hostUserId);
			}
		}
		if (!notifyHost) {
			return;
		}
		for (const host of Players.GetPlayers()) {
			if (host.UserId === hostUserId) {
				this._toastPlayer(host, "Visitor left", visitor.DisplayName + " headed home.", "Info");
				this._pushState(host);
				break;
			}
		}
	}

	_broadcastVisit(host: Player) {
		const bucket = this._visitors.get(host.UserId);
		if (!bucket) {
			return;
		}
		const profile = this._data.Get(host) as Profile | undefined;
		if (!profile) {
			return;
		}
		const visit = buildVisitSnapshot(host, profile);
		for (const [visitor] of bucket) {
			if (visitor.Parent === Players) {
				this._effect.fire(visitor, {
					Type: "VisitUpdate",
					Visit: visit,
				});
			}
		}
	}

	_visitPlot(visitor: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);

		let userId = RemoteFirewall.CoerceUserId(extracted) as number | undefined;
		if (userId === undefined) {
			userId = RemoteFirewall.CoerceUserId(rawUserId) as number | undefined;
		}
		if (userId === undefined) {
			return responseError("That workshop could not be found.");
		}
		if (userId === visitor.UserId) {
			return responseError("You're already at your own workshop.");
		}
		const host = Players.GetPlayerByUserId(userId);
		if (!host) {
			return responseError("That player is no longer in this server.");
		}
		const profile = this._data.Get(host) as Profile | undefined;
		if (!profile) {
			return responseError("Their workshop is still loading.");
		}

		this._clearVisit(visitor, true);
		this._visiting.set(visitor, host.UserId);
		let bucket = this._visitors.get(host.UserId);
		if (!bucket) {
			bucket = new Map();
			this._visitors.set(host.UserId, bucket);
		}
		bucket.set(visitor, true);

		const visit = buildVisitSnapshot(host, profile);
		this._toastPlayer(host, "Someone stopped by", visitor.DisplayName + " is checking out your shop.", "Special");
		this._pushState(host);

		const visitorSnap = this._snapshot(visitor);
		this._forgetSentSections(visitor);
		this._pushState(visitor);
		return responseSuccess("Visiting " + host.DisplayName + ".", { Visit: visit, State: visitorSnap });
	}

	_leavePlot(visitor: Player) {
		if (this._visiting.get(visitor) === undefined) {
			return responseSuccess("Already back at your workshop.");
		}
		this._clearVisit(visitor, true);
		this._effect.fire(visitor, { Type: "VisitEnded" });
		return responseSuccess("Back at your workshop.");
	}

	_nudgeCrew(sender: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);
		const userId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawUserId)) as
			| number
			| undefined;
		if (userId === undefined) {
			return responseError("Couldn't find that crew member.");
		}
		if (userId === sender.UserId) {
			return responseError("Wave at someone else.");
		}
		const target = Players.GetPlayerByUserId(userId);
		if (!target) {
			return responseError("They're not in this server anymore.");
		}

		this._effect.fire(target, {
			Type: "CrewNudge",
			FromUserId: sender.UserId,
			FromName: sender.DisplayName,
		});
		return responseSuccess("Waved at " + target.DisplayName + ".");
	}

	_reportPresence(player: Player, payload: unknown) {
		const body = payload as Dict | undefined;
		const page = body !== undefined ? body.Page : undefined;
		if (typeIs(page, "string") && PRESENCE_PAGES[page]) {
			this._presence.set(player.UserId, { Page: page, UpdatedAt: os.time() });
		}
		if (body === undefined || body.Gen === undefined) {
			const [gen, nonce] = this._session.Hello(player) as LuaTuple<[unknown, unknown]>;
			return responseSuccess(undefined, { Gen: gen, N: nonce });
		}
		const [ok, reason, gen, nonce] = this._session.Beat(player, body.Gen, body.Id, body.N) as LuaTuple<
			[boolean, unknown, unknown, unknown]
		>;
		if (!ok && reason !== "late") {
			ModuleLog.Every(
				"beat:%d".format(player.UserId),
				15,
				"auth",
				"u=%d beat rejected %s".format(player.UserId, tostring(reason)),
			);
		}
		return responseSuccess(undefined, { Gen: gen, N: nonce, Auth: ok });
	}

	_getPlayers(viewer: Player) {
		const records: Dict[] = [];
		for (const target of Players.GetPlayers()) {
			const profile = this._data.Get(target) as Profile | undefined;
			if (profile) {
				records.push(publicPlayerRecord(target, profile, viewer, this._presence));
			}
		}
		const isStudio = studioCheck();
		let hasOther = false;
		for (const r of records) {
			if (!truthy(r.IsLocal)) {
				hasOther = true;
				break;
			}
		}
		if (isStudio || !hasOther) {
			records.push({
				UserId: -999,
				Name: "ForgeAutomaton",
				DisplayName: "Forge Automaton [Practice]",
				Zone: 1,
				CurrentZone: 1,
				Rebirths: 3,
				Production: 1000,
				LifetimeCash: 10000,
				Stardust: 1000,
				Cores: 10,
				DomainRank: 0,
				PlayTime: 1000,
				Boards: {
					Crates: "10",
					Finds: "5",
					Ore: "100",
					Wardens: "1",
					Orders: "2",
					Stars: "3",
					Cipher: "0",
				},
				ItemCount: 0,
				EquippedItems: {},
				Artifact: undefined,
				IsLocal: false,
				SocialFlags: 0,
				CurrentPage: "Overview",
				PresenceAge: 0,
				AccountAge: 100,
				Premium: false,
			});
		}
		table.sort(records as defined[], (leftValue, rightValue) => {
			const left = leftValue as Dict;
			const right = rightValue as Dict;
			if (left.IsLocal !== right.IsLocal) {
				return left.IsLocal as boolean;
			}
			// Production above 1e15 is an Omega string; a plain > would throw comparing it to a number
			return Economy.Gt(left.Production, right.Production) as boolean;
		});
		return responseSuccess(undefined, { Players: records });
	}

	_pushTradePartners(hostId: unknown, guestId: unknown) {
		for (const userId of [hostId, guestId]) {
			const other = Players.GetPlayerByUserId(userId as number);
			if (other) {
				this._pushState(other, true);
			}
		}
	}

	_tradeAction(player: Player, action: string, rawPayload: unknown) {
		const payload = rawPayload as Dict;
		const profile = this._data.Get(player) as Profile | undefined;
		if (!profile) {
			return responseError("Profile is still loading.");
		}
		const now = os.time();
		if (action === Protocol.Actions.GetTrade) {
			return responseSuccess(undefined);
		}
		if (!truthy(this._trades.Unlocked(profile))) {
			return responseError("Trade Floor unlocks after your first rebirth.");
		}
		if (action === Protocol.Actions.InviteTrade) {
			const userId = RemoteFirewall.CoerceUserId(payload.UserId) as number | undefined;
			if (userId === undefined) {
				return responseError("Choose a player to invite.");
			}
			this._flagTradeInvite(player, userId);
			if (!truthy(this._trades.Unlocked(profile))) {
				return responseError("Trade Floor unlocks after your first rebirth.");
			}
			const target = userId === -999 ? undefined : Players.GetPlayerByUserId(userId);
			const targetProfile = target ? (this._data.Get(target) as Profile | undefined) : undefined;
			if (userId !== -999 && targetProfile && !truthy(this._trades.Unlocked(targetProfile))) {
				return responseError("They have not unlocked Trade Floor yet.");
			}
			// the target's Social setting decides who may invite them
			const targetSettings = targetProfile ? (targetProfile.Settings as Dict | undefined) : undefined;
			const tradePolicy = targetSettings ? targetSettings.TradeInvitePolicy : undefined;
			if (target && typeIs(tradePolicy, "number") && tradePolicy >= 0.25) {
				const [okFriend, isFriend] = pcall(() => (target as unknown as Svc).IsFriendsWith(player.UserId));
				if (!truthy(ChatRules.allows(tradePolicy, okFriend && isFriend === true))) {
					return responseError(
						tradePolicy >= 0.75
							? `${target.DisplayName} isn't taking trade invites.`
							: `${target.DisplayName} only takes trade invites from friends.`,
					);
				}
			}
			const [ok, err] = this._trades.Invite(player, profile, userId, now) as LuaTuple<[unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (target) {
				this._toastPlayer(target, "Trade invite", player.DisplayName + " wants to trade. Open Trade to accept.", "Info");
				this._pushState(target, true);
			}
			this._pushState(player, true);
			return responseSuccess(userId === -999 ? "Practice trade opened." : "Invite sent.");
		} else if (action === Protocol.Actions.RespondTrade) {
			const accept = payload.Accept === true;
			const [ok, err, session, fromId] = this._trades.Respond(player, profile, accept, now) as LuaTuple<
				[unknown, unknown, Dict | undefined, number | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (fromId !== undefined) {
				const host = Players.GetPlayerByUserId(fromId);
				if (host) {
					this._toastPlayer(
						host,
						accept ? "Trade opened" : "Invite declined",
						accept ? player.DisplayName + " accepted." : player.DisplayName + " declined.",
						accept ? "Success" : "Info",
					);
					this._pushState(host, true);
				}
			}
			if (session) {
				this._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess(accept ? "Trade opened." : "Invite declined.");
		} else if (action === Protocol.Actions.UpdateTradeOffer) {
			const [ok, err, session] = this._trades.UpdateOffer(player, profile, payload.Offer, now) as LuaTuple<
				[unknown, unknown, Dict | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (session) {
				this._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess("Offer updated.");
		} else if (action === Protocol.Actions.SetTradeReady) {
			const [ok, err, session] = this._trades.SetReady(player, profile, payload.Ready === true, now) as LuaTuple<
				[unknown, unknown, Dict | undefined]
			>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			if (session) {
				this._pushTradePartners(session.Host, session.Guest);
			}
			return responseSuccess(payload.Ready === true ? "You are ready." : "Ready cleared.");
		} else if (action === Protocol.Actions.ConfirmTrade) {
			const [ok, err, maybeSession] = this._trades.Confirm(player, now) as LuaTuple<[unknown, unknown, Dict | undefined]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			const confirmed = maybeSession ? (maybeSession.Confirmed as Record<number, unknown>) : undefined;
			if (
				maybeSession &&
				confirmed &&
				truthy(confirmed[maybeSession.Host as number]) &&
				truthy(confirmed[maybeSession.Guest as number])
			) {
				const session = maybeSession;
				if (!truthy(this._trades.TryBeginSettle(session))) {
					this._pushTradePartners(session.Host, session.Guest);
					return responseSuccess("Trade is settling.");
				}
				const isPractice = session.Guest === -999 || session.Host === -999;
				const host = Players.GetPlayerByUserId(session.Host as number);
				const guest = (
					session.Guest === -999
						? {
								UserId: -999,
								Name: "ForgeAutomaton",
								DisplayName: "Forge Automaton [Practice]",
							}
						: Players.GetPlayerByUserId(session.Guest as number)
				) as Player | undefined;
				const hostProfile = host ? (this._data.Get(host) as Profile | undefined) : undefined;
				let mockBotProfile: Profile | undefined = undefined;
				if (isPractice) {
					mockBotProfile = {
						Cash: 1e6,
						Stardust: 1e5,
						Cores: 100,
						Command: { Signals: 100 },
						Items: {
							Essence: 100,
							Inventory: {},
							Equipped: {},
							Keys: { Bronze: 10, Silver: 10, Gold: 10, Astral: 10, ForgeCrate: 10 },
						},
						BoostInventory: { Surge: 10, Overdrive: 10, Hyperdrive: 10, VaultSurge: 10 },
						Trade: {
							Day: -1,
							Completed: 0,
							Sent: { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 },
							History: {},
						},
					};
				}
				const guestProfile =
					session.Guest === -999 ? mockBotProfile : guest ? (this._data.Get(guest) as Profile | undefined) : undefined;
				if (!host || !guest || !hostProfile || !guestProfile) {
					this._trades.FailSettle(session, false);
					this._trades.Cancel(player);
					return responseError("A trader left before the swap finished.");
				}
				const [plannedValue, planErr] = this._trades.Plan(session, hostProfile, guestProfile, now) as LuaTuple<
					[Dict | undefined, unknown]
				>;
				if (!plannedValue) {
					this._trades.FailSettle(session, false);
					this._pushTradePartners(session.Host, session.Guest);
					return responseError(orElse(planErr, () => "That trade could not be settled."));
				}
				const plan = plannedValue;

				// One side's record of this trade: what it gave and what it got, with item names.
				const tradeHistoryEntry = (
					tradeSession: Dict,
					partner: Player,
					gave: unknown,
					gaveItems: unknown,
					got: unknown,
					gotItems: unknown,
					at: unknown,
				) => {
					const names = (snapshot: unknown) => {
						const list: string[] = [];
						for (const [, instance] of pairs((truthy(snapshot) ? snapshot : {}) as Dict)) {
							const definition = isTable(instance) ? itemById[instance.DefinitionId as string] : undefined;
							list.push(definition ? (definition.Name as string) : "an item");
						}
						return list;
					};
					const amount = (value: unknown) => {
						const number = num(value);
						if (number === undefined) {
							return (
								require(
									ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
								) as Kit
							).ToString(value);
						}
						for (const step of [
							[1e12, "T"],
							[1e9, "B"],
							[1e6, "M"],
							[1e3, "K"],
						] as Array<[number, string]>) {
							if (math.abs(number) >= step[0]) {
								return "%.1f%s".format(number / step[0], step[1]).gsub("%.0(%a)", "%1")[0];
							}
						}
						return tostring(math.floor(number));
					};
					return {
						Id: tostring(tradeSession.Id),
						At: at,
						PartnerId: partner.UserId,
						Partner: partner.DisplayName,
						Gave: TradeHistory.summarize(gave, names(gaveItems), amount),
						Got: TradeHistory.summarize(got, names(gotItems), amount),
					};
				};

				// Durability hook: stamp a per-profile fault journal so a faulted trade
				// can be reconciled the next time the affected profile loads.
				const writeTradeJournal = (targetPlayer: Player, side: string, status: string, reason?: unknown) => {
					if (status !== "faulted") {
						return;
					}
					const [journalOk, journalErr] = pcall(() =>
						this._data.AtomicUpdate(
							targetPlayer,
							(journalProfile: Profile) => {
								const entry = TradeRecovery.MakeFaultedEntry(session, side, plan, orElse(reason, () => "unknown"), now);
								(journalProfile.Trade as Dict).FaultedJournal = entry;
								return { ok: true };
							},
							true,
							"trade-journal-" + side,
						),
					);
					if (!journalOk) {
						ModuleLog.Warn("Trade", "Could not write %s fault journal: %s".format(side, tostring(journalErr)));
					}
				};

				const outcome = TradeSettle.RunHostGuest(session, {
					plan: plan,
					applyHost: () =>
						this._data.AtomicUpdate(
							host,
							(hostDraft: Profile) => {
								const applyErr = this._trades.ApplyExchange(
									hostDraft,
									plan.HostOffer,
									plan.GuestOffer,
									plan.HostItems,
									plan.GuestItems,
									plan.Now,
								);
								if (truthy(applyErr)) {
									return { ok: false, error: applyErr };
								}
								// history commits in the same save as the exchange
								TradeHistory.record(
									hostDraft.Trade,
									tradeHistoryEntry(session, guest, plan.HostOffer, plan.HostItems, plan.GuestOffer, plan.GuestItems, plan.Now),
								);
								return { ok: true };
							},
							true,
							"trade-host",
						),
					guestPresent: () => {
						if (isPractice) {
							return true;
						}
						return this._data.Get(guest) !== undefined;
					},
					applyGuest: () => {
						if (isPractice) {
							// RunHostGuest reads (committed, result); a bare table left committed as the table and failed the guest side.
							return $tuple(true, { ok: true });
						}
						return this._data.AtomicUpdate(
							guest,
							(guestDraft: Profile) => {
								const applyErr = this._trades.ApplyExchange(
									guestDraft,
									plan.GuestOffer,
									plan.HostOffer,
									plan.GuestItems,
									plan.HostItems,
									plan.Now,
								);
								if (truthy(applyErr)) {
									return { ok: false, error: applyErr };
								}
								TradeHistory.record(
									guestDraft.Trade,
									tradeHistoryEntry(session, host, plan.GuestOffer, plan.GuestItems, plan.HostOffer, plan.HostItems, plan.Now),
								);
								return { ok: true };
							},
							true,
							"trade-guest",
						);
					},
					revertHostOnce: () => {
						const [revertOk, revertResult] = this._data.AtomicUpdate(
							host,
							(hostDraft: Profile) => {
								const shortfall = this._trades.RevertExchange(
									hostDraft,
									plan.HostOffer,
									plan.GuestOffer,
									plan.HostItems,
									plan.GuestItems,
									plan.Now,
								);
								if (truthy(shortfall)) {
									// what the host received was already spent; the settle faults and is journaled
									return { ok: false, error: "revert shortfall: " + tostring(shortfall) };
								}
								// a reverted side never happened, so its history entry goes too
								TradeHistory.remove(hostDraft.Trade, tostring(session.Id));
								return { ok: true };
							},
							true,
							"trade-revert",
						) as LuaTuple<[unknown, unknown]>;
						return TradeSettle.IsCommitOk(revertOk, revertResult);
					},
					writeHostJournal: (status: string, reason?: unknown) => {
						writeTradeJournal(host, "host", status, reason);
					},
					writeGuestJournal: (status: string, reason?: unknown) => {
						writeTradeJournal(guest, "guest", status, reason);
					},
				}) as Dict;
				this._pushTradePartners(session.Host, session.Guest);
				if (!truthy(outcome.ok)) {
					if (typeIs(outcome.log, "string")) {
						ModuleLog.Warn("Trade", outcome.log, { SessionId: session.Id, Host: session.Host, Guest: session.Guest });
					}
					return responseError(orElse(outcome.message, () => "That trade could not be settled."));
				}
				this._trades.Close(session);
				this._toastPlayer(host, "Trade complete", "The exchange is locked in.", "Success");
				this._toastPlayer(guest, "Trade complete", "The exchange is locked in.", "Success");
				return responseSuccess("Trade complete.");
			}
			if (maybeSession) {
				this._pushTradePartners(maybeSession.Host, maybeSession.Guest);
			}
			return responseSuccess("Confirmation noted.");
		} else if (action === Protocol.Actions.TradeChat) {
			let text: unknown = undefined;
			if (typeIs(payload.Text, "string") && payload.Text.size() > 0) {
				// free text goes through Roblox's filter for the partner before anyone sees it
				const raw = payload.Text.sub(1, 140);
				const [okFilter, filtered] = TradeChatFilter.Apply(
					game.GetService("TextService"),
					raw,
					player.UserId,
					Enum.TextFilterContext.PrivateChat,
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(okFilter)) {
					return responseError("That message couldn't be sent.");
				}
				text = filtered;
			}
			const [ok, err, session] = this._trades.Say(player, text, num(payload.Phrase), now) as LuaTuple<[unknown, unknown, Dict]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			this._pushTradePartners(session.Host, session.Guest);
			return responseSuccess();
		} else if (action === Protocol.Actions.TradeRequest) {
			const [ok, err, session] = this._trades.Request(player, payload.Request, now) as LuaTuple<[unknown, unknown, Dict]>;
			if (!truthy(ok)) {
				return responseError(err);
			}
			this._pushTradePartners(session.Host, session.Guest);
			return responseSuccess("Request sent.");
		} else if (action === Protocol.Actions.TradeViewAway) {
			const away = truthy(payload) ? payload.Away === true : payload;
			const session = this._trades.SetAway(player, away) as Dict | undefined;
			if (!session) {
				return responseSuccess();
			}
			const otherId = session.Host === player.UserId && truthy(session.Guest) ? session.Guest : session.Host;
			const other = Players.GetPlayerByUserId(otherId as number);
			if (other) {
				if (truthy(payload) && payload.Away === true) {
					this._toastPlayer(other, "Trade", player.DisplayName + " stepped away from the table.", "Info");
				} else {
					this._toastPlayer(other, "Trade", player.DisplayName + " is back at the table.", "Info");
				}
			}
			return responseSuccess();
		} else if (action === Protocol.Actions.CancelTrade) {
			const [session, otherId, cancelErr] = this._trades.Cancel(player) as LuaTuple<[unknown, number | undefined, unknown]>;
			if (truthy(cancelErr)) {
				return responseError(cancelErr);
			}
			if (otherId !== undefined) {
				const other = Players.GetPlayerByUserId(otherId);
				if (other) {
					this._toastPlayer(other, "Trade cancelled", player.DisplayName + " closed the table.", "Info");
					this._pushState(other, true);
				}
			}
			if (truthy(session)) {
				return responseSuccess("Trade cancelled.");
			}
			return responseSuccess("Invite cleared.");
		}
		return responseError("Unknown trade action.");
	}

	_getPlayerMirror(viewer: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);
		const userId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawUserId)) as
			| number
			| undefined;
		if (userId === undefined) {
			return responseError("That player could not be found.");
		}
		const target = Players.GetPlayerByUserId(userId);
		if (target) {
			const profile = this._data.Get(target) as Profile | undefined;
			if (profile) {
				return responseSuccess(undefined, { Mirror: publicPlayerRecord(target, profile, viewer, this._presence) });
			}
		}
		return responseError("That player is no longer in this server.");
	}

	constructor(
		private readonly dataService: DataService,
		private readonly worldService: WorldService,
		private readonly fluxSurgeService: FluxSurgeService,
		private readonly convergenceService: ConvergenceService,
		private readonly securityPipeline: Security,
		private readonly adminService: AdminService,
		private readonly sessionGate: SessionGate,
		private readonly remoteFirewall: RemoteFirewall,
		private readonly gameAntiCheat: GameAntiCheat,
		private readonly playerAnalytics: PlayerAnalytics,
		private readonly playerBadges: PlayerBadges,
		private readonly matterRuntime: MatterRuntime,
		private readonly serverEvents: ServerEventService,
		private readonly guildService: GuildService,
		// GameService reads the shared Specializations rules; this service keeps them live-tuned.
		private readonly _specializations: SpecializationService,
	) {}

	// Runs from the server runtime's "gameplay construction" boot step.
	build() {
		const dataService = this.dataService as unknown as Svc;
		this._data = dataService;
		this._world = this.worldService as unknown as Svc;
		this._fluxSurge = this.fluxSurgeService as unknown as Svc;
		this._state = ServerEvents.state;
		this._toast = ServerEvents.toast;
		this._effect = ServerEvents.effect;
		this._security = this.securityPipeline as unknown as Dict;
		this._admin = this.adminService as unknown as Svc;
		this._runtime = new Map();
		this._visiting = new Map();
		this._visitors = new Map();
		this._presence = new Map();
		this._matter = this.matterRuntime;
		this._matterAccumulator = 0;
		this._rankPingAccumulator = 0;
		this._rankPingBusy = false;
		this._firewall = this.remoteFirewall as unknown as Svc;
		this._session = this.sessionGate as unknown as Svc;
		this._antiCheat = this.gameAntiCheat as unknown as Svc;
		this._analytics = this.playerAnalytics as unknown as Svc;
		this._badges = this.playerBadges as unknown as Svc;
		this._convergence = this.convergenceService as unknown as Svc;
		this._events = this.serverEvents as unknown as Svc;
		this.serverEvents.Attach({
			random: () => this._random.NextNumber(),
			announce: (phase: string, def: Dict) => {
				this._announceServerEvent(phase, def);
			},
			broadcast: () => {
				for (const online of Players.GetPlayers()) {
					this._effect.fire(online, { Type: "ServerEvent", Event: this._events.State(online) });
				}
			},
			pay: (entries: Dict[], def: Dict, why: string) => {
				this._payEvent(entries, def, why);
			},
		} as unknown as Parameters<ServerEventService["Attach"]>[0]);
		// Studio only: start any event by id to try it (ServerScriptService.EventDebug:Invoke("IronTitan"))
		if (game.GetService("RunService").IsStudio()) {
			const debugHook = new Instance("BindableFunction");
			debugHook.Name = "EventDebug";
			debugHook.OnInvoke = (id: unknown) => this._events.Start(id);
			debugHook.Parent = game.GetService("ServerScriptService");
		}
		this._guilds = this.guildService as unknown as Svc;
		this._guildCommunity = GuildCommunity.new(
			this._guilds,
			dataService,
			this._security,
			this._effect,
			(target: Player, guildId: string): LuaTuple<[boolean, unknown]> => {
				const [updated, result] = this._data.AtomicUpdate(
					target,
					(targetProfile: Profile) => {
						const guild = targetProfile.Guild as Dict | undefined;
						if (truthy(guild) && guild.Id === guildId) {
							targetProfile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
							targetProfile.GuildBonuses = emptyBonuses();
						}
						return { ok: true };
					},
					true,
					"guild-ban",
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(updated)) {
					return $tuple(false, result);
				}
				this._pushState(target);
				// a guild ban removes guild access only (the client shows the notice); never disconnect the player
				this._effect.fire(target, { Type: "GuildBanned", GuildId: guildId });
				return $tuple(true, undefined);
			},
		) as Svc;
		this._chat = ChatService.new(this._effect, this._data) as Svc;
		this._crews = CrewService.new(this._effect, this._data) as Svc;
		this._trades = TradeDesk.new() as Svc;
		// the trade table shows each side the other's tradeable relics
		(this._trades as Dict).ProfileOf = (userId: number) => {
			const other = Players.GetPlayerByUserId(userId);
			const found = other ? this._data.Get(other) : undefined;
			return truthy(found) ? found : undefined;
		};
		this._random = new Random();
		this._heartbeat = undefined;
		this._playerAddedConnection = undefined;
		this._playerRemovingConnection = undefined;
		this._characterConnections = new Map();
		this._joining = new Map();
		this._running = false;
		this._leaderboardStores = {};
		for (const [id, storeName] of pairs(GENERAL_BOARD_STORE_NAMES)) {
			this._leaderboardStores[id] = getOrderedStore(storeName);
		}

		this._playerNameCache = new Map();
		this._nameLookupPending = new Map();
		this._nameCachePruneAt = 0;
		this._globalBoardCache = {};
		this._friendshipCache = {};
		this._queuedStatePushes = new Map();
		this._socialBoostScheduled = false;
		this._socialBoostDirty = false;
		this._socialBoostWorker = undefined;
		this._backgroundWorkers = new Map();
		this._saveFailedToastAt = new Map();
		(dataService as Dict).OnSaveFailed = (player: Player, reason: string) => {
			const lastToastAt = this._saveFailedToastAt.get(player) ?? 0;
			if (os.clock() - lastToastAt < 120) {
				return;
			}
			this._saveFailedToastAt.set(player, os.clock());
			this._toastPlayer(player, "Save trouble", "Your progress couldn't save just now. Stay online while we retry.", "Warning");
		};
	}

	_submitFeedback(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const endpoint = ServerStorage.GetAttribute(ServerConfig.FeedbackWebhookAttribute as string);
		if (!typeIs(endpoint, "string") || endpoint.match("^https://")[0] === undefined) {
			return responseError("Feedback isn't set up yet. Please try again later.");
		}
		const category = payload ? payload.Category : undefined;
		const raw = payload ? payload.Message : undefined;
		if (!typeIs(category, "string") || !typeIs(raw, "string")) {
			return responseError("Write a short note before sending it.");
		}
		const body0 = payload as Dict;
		const [filteredOk, filtered] = (this._security.Filter as Svc).Apply(player, raw, player.UserId, 600) as LuaTuple<
			[unknown, unknown]
		>;
		if (!truthy(filteredOk) || !typeIs(filtered, "string") || filtered.size() < 1) {
			return responseError("That note couldn't be checked. Please try different wording.");
		}
		const profile = this._data.Get(player) as Profile | undefined;
		const categoryColors: Record<string, number | undefined> = {
			Bug: 15548997,
			Suggestion: 5959144,
			Balance: 16762880,
			Performance: 10181046,
			Interface: 3447003,
			Other: 9807270,
		};
		const impactLabels: Record<number, string | undefined> = {
			1: "Minor",
			2: "Noticeable",
			3: "Annoying",
			4: "Major",
			5: "Blocking",
		};
		const impact = payload ? payload.Impact : undefined;
		const fields: Dict[] = [
			{
				name: "Player",
				value: "%s (@%s) · %d".format(player.DisplayName, player.Name, player.UserId),
				inline: false,
			},
			{
				name: "Progress",
				value: "World %d · %d rebirths".format(
					orElse(profile && profile.Zone, () => 1) as number,
					orElse(profile && profile.Rebirths, () => 0) as number,
				),
				inline: true,
			},
			{ name: "Server", value: game.JobId !== "" ? game.JobId : "Studio", inline: true },
		];
		if (typeIs(impact, "number") && impactLabels[impact] !== undefined) {
			fields.push({ name: "Impact", value: "%s (%d/5)".format(impactLabels[impact]!, impact), inline: true });
		}
		if (typeIs(body0.Device, "string")) {
			const screen = typeIs(body0.Screen, "string") ? " · " + body0.Screen : "";
			fields.push({ name: "Device", value: body0.Device + screen, inline: true });
		}
		if (typeIs(body0.Page, "string")) {
			fields.push({ name: "Page", value: body0.Page, inline: true });
		}
		const body = {
			username: "Astral Forge Feedback",
			allowed_mentions: { parse: {} },
			embeds: [
				{
					title: category + " feedback",
					description: filtered,
					color: categoryColors[category] ?? 5959144,
					fields: fields,
					footer: { text: "Astral Forge " + tostring(GameConfig.Game.Version) },
					timestamp: DateTime.now().ToIsoDate(),
				},
			],
		};
		this._spawnWorker(() => {
			const [ok, response] = pcall(() =>
				HttpService.RequestAsync({
					Url: endpoint,
					Method: "POST",
					Headers: { ["Content-Type"]: "application/json" },
					Body: HttpService.JSONEncode(body),
				}),
			);
			if (!ok || !typeIs(response, "table") || response.Success !== true) {
				ModuleLog.Every("feedback-webhook", 30, "Feedback", "A player note could not be delivered");
			}
		});
		return responseSuccess("Thanks. Your feedback was sent.");
	}

	_reportPlayer(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const reason = payload ? payload.Reason : undefined;
		if (!truthy(ReportLedger.isReason(reason))) {
			return responseError("Pick a reason before sending the report.");
		}
		const rawTarget = payload ? payload.UserId : undefined;
		const extracted = extractUserId(rawTarget);
		const targetUserId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawTarget)) as
			| number
			| undefined;
		if (targetUserId === undefined) {
			return responseError("Couldn't find that player.");
		}
		if (targetUserId === player.UserId) {
			return responseError("You can't report yourself.");
		}
		const target = Players.GetPlayerByUserId(targetUserId);
		if (!target) {
			return responseError("That player is no longer in this server.");
		}
		const body0 = payload as Dict;
		const now = os.time();
		const [allowed, refusal] = reportLedger.canReport(player.UserId, targetUserId, now) as LuaTuple<[unknown, unknown]>;
		if (!truthy(allowed)) {
			return responseError(refusal);
		}
		const rawDetails = body0.Details;
		let details = "";
		if (typeIs(rawDetails, "string") && rawDetails.size() > 0) {
			const [filteredOk, filtered] = (this._security.Filter as Svc).Apply(player, rawDetails, player.UserId, 400) as LuaTuple<
				[unknown, unknown]
			>;
			details = truthy(filteredOk) && typeIs(filtered, "string") ? filtered : "";
		}
		const [reportCount, reporterCount] = reportLedger.record(player.UserId, targetUserId, reason, now) as LuaTuple<
			[number, number]
		>;
		const severity = body0.Severity === "Serious" || body0.Severity === "Urgent" ? (body0.Severity as string) : "Minor";
		const when = body0.When === "Earlier" || body0.When === "Repeated" ? (body0.When as string) : "Now";
		const where =
			body0.Where === "Chat" || body0.Where === "Trade" || body0.Where === "Guild" ? (body0.Where as string) : "World";
		const endpoint = ServerStorage.GetAttribute(ServerConfig.ReportWebhookAttribute as string);
		if (!typeIs(endpoint, "string") || endpoint.match("^https://")[0] === undefined) {
			ModuleLog.Every(
				"report:%d".format(targetUserId),
				5,
				"Report",
				"%s reported %s (%d) for %s; %d reports from %d players this hour".format(
					player.Name,
					target.Name,
					targetUserId,
					reason as string,
					reportCount,
					reporterCount,
				),
			);
			return responseSuccess("Report received. Thanks for helping keep the server clean.", { Reported: targetUserId });
		}
		const reporterProfile = this._data.Get(player) as Profile | undefined;
		const targetProfile = this._data.Get(target) as Profile | undefined;
		const progressOf = (p: Profile | undefined) =>
			"World %d · %d rebirths".format(
				orElse(p && p.Zone, () => 1) as number,
				orElse(p && p.Rebirths, () => 0) as number,
			);
		const body = {
			username: "Astral Forge Reports",
			allowed_mentions: { parse: {} },
			embeds: [
				{
					title: "[%s] Player report: %s".format(severity, reason as string),
					description: details !== "" ? details : "(no details provided)",
					color: (ReportLedger.SEVERITY_COLORS as unknown as Record<string, number | undefined>)[severity] ?? 15548997,
					fields: [
						{
							name: "Reported",
							value: "%s (@%s) · %d".format(target.DisplayName, target.Name, target.UserId),
							inline: true,
						},
						{
							name: "Reported by",
							value: "%s (@%s) · %d".format(player.DisplayName, player.Name, player.UserId),
							inline: true,
						},
						{ name: "Target progress", value: progressOf(targetProfile), inline: true },
						{ name: "Reporter progress", value: progressOf(reporterProfile), inline: true },
						{ name: "This hour", value: "%d reports from %d players".format(reportCount, reporterCount), inline: true },
						{ name: "Target account", value: "%d days old".format(target.AccountAge), inline: true },
						{ name: "Context", value: "%s · %s".format(where, when), inline: true },
						{ name: "Server", value: game.JobId !== "" ? game.JobId : "Studio", inline: true },
					],
					footer: { text: "Astral Forge " + tostring(GameConfig.Game.Version) },
					timestamp: DateTime.now().ToIsoDate(),
				},
			],
		};
		this._spawnWorker(() => {
			const [ok, response] = pcall(() =>
				HttpService.RequestAsync({
					Url: endpoint,
					Method: "POST",
					Headers: { ["Content-Type"]: "application/json" },
					Body: HttpService.JSONEncode(body),
				}),
			);
			if (!ok || !typeIs(response, "table") || response.Success !== true) {
				ModuleLog.Every("report-webhook", 30, "Report", "A player report could not be delivered");
			}
		});
		return responseSuccess("Report sent. Thanks for helping keep the server clean.", { Reported: targetUserId });
	}

	_spawnWorker(callback: () => void) {
		if (!this._running) {
			return undefined;
		}
		const token = {};
		const worker = task.defer(() => {
			if (this._running) {
				const [ok, problem] = pcall(callback);
				if (!ok) {
					ModuleLog.Every("background-worker", 5, "Game", "background task failed: " + tostring(problem));
				}
			}
			this._backgroundWorkers.delete(token);
		});
		this._backgroundWorkers.set(token, worker);
		return worker;
	}

	_queueSocialBoostRefresh() {
		this._socialBoostDirty = true;
		if (this._socialBoostScheduled) {
			return;
		}
		this._socialBoostScheduled = true;
		this._socialBoostWorker = task.spawn(() => {
			do {
				this._socialBoostDirty = false;
				task.wait(0.15);
				if (!this._running) {
					break;
				}
				const cacheNow = os.clock();
				for (const [key, entry] of pairs(this._friendshipCache)) {
					if (!isTable(entry) || num(entry.ExpiresAt) === undefined || (entry.ExpiresAt as number) <= cacheNow) {
						this._friendshipCache[key] = undefined;
					}
				}
				const online = Players.GetPlayers();
				const counts = new Map<Player, number>();
				for (const player of online) {
					counts.set(player, 0);
				}
				for (let leftIndex = 0; leftIndex < online.size(); leftIndex++) {
					const left = online[leftIndex];
					for (let rightIndex = leftIndex + 1; rightIndex < online.size(); rightIndex++) {
						const right = online[rightIndex];
						const low = math.min(left.UserId, right.UserId);
						const high = math.max(left.UserId, right.UserId);
						const key = tostring(low) + ":" + tostring(high);
						const cached = this._friendshipCache[key];
						let friends: unknown = false;
						if (cached && (cached.ExpiresAt as number) > os.clock()) {
							friends = cached.Value;
						} else {
							const [ok, result] = pcall(() => (left as unknown as Svc).IsFriendsWith(right.UserId));
							friends = ok && result === true;
							this._friendshipCache[key] = {
								Value: friends,
								ExpiresAt: os.clock() + (ok ? (GameConfig.Social.FriendshipCacheSeconds as number) : 20),
							};
						}
						if (truthy(friends)) {
							counts.set(left, (counts.get(left) ?? 0) + 1);
							counts.set(right, (counts.get(right) ?? 0) + 1);
						}
					}
				}
				for (const player of online) {
					const [updated, updateError] = pcall(() => {
						let changed = false;
						const [committed] = this._data.AtomicUpdate(
							player,
							(profile: Profile) => {
								changed = applySocialBoost(
									profile,
									counts.get(player) ?? 0,
									player.MembershipType === Enum.MembershipType.Premium,
								);

								if (!changed) {
									return { ok: false, noop: true };
								}
								return { ok: true };
							},
							true,
							"social-boost",
						) as LuaTuple<[unknown]>;
						if (truthy(committed) && changed) {
							this._pushState(player);
						}
					});
					if (!updated) {
						ModuleLog.Every("social-boost:" + tostring(player.UserId), 30, "Social", "friend boost update failed: " + tostring(updateError));
					}
				}
			} while (this._socialBoostDirty);
			this._socialBoostScheduled = false;
			this._socialBoostWorker = undefined;

			if (this._socialBoostDirty && this._running) {
				this._queueSocialBoostRefresh();
			}
		});
	}

	_toastPlayer(player: Player, title: unknown, body: unknown, tone?: unknown) {
		if (player.Parent !== Players) {
			return;
		}
		this._toast.fire(player, {
			Title: title,
			Body: body,
			Tone: orElse(tone, () => "Info"),
		});
	}

	_createLeaderstats(player: Player) {
		const old = player.FindFirstChild("leaderstats");
		if (old) {
			old.Destroy();
		}
		const folder = new Instance("Folder");
		folder.Name = "leaderstats";
		folder.Parent = player;

		const flux = new Instance("NumberValue");
		flux.Name = "Flux";
		flux.Parent = folder;

		const cores = new Instance("NumberValue");
		cores.Name = "Cores";
		cores.Parent = folder;
		const rebirths = new Instance("NumberValue");
		rebirths.Name = "Rebirths";
		rebirths.Parent = folder;
	}

	_syncLeaderstats(player: Player, profile: unknown) {
		if (player.Parent !== Players || !isTable(profile)) {
			return;
		}
		const leaderstats = player.FindFirstChild("leaderstats");
		if (leaderstats) {
			const flux = leaderstats.FindFirstChild("Flux");
			const cores = leaderstats.FindFirstChild("Cores");
			const rebirths = leaderstats.FindFirstChild("Rebirths");
			if (flux && flux.IsA("NumberValue")) {
				flux.Value = math.floor(progressionNumber(profile.Cash));
			}
			if (cores && cores.IsA("NumberValue")) {
				cores.Value = math.floor(progressionNumber(profile.Cores));
			}
			if (rebirths && rebirths.IsA("NumberValue")) {
				rebirths.Value = math.floor(progressionNumber(profile.Rebirths));
			}
		}
		player.SetAttribute(
			"ProductionPerSecond",
			progressionNumber(
				Economy.Mul(
					Economy.Production(profile),
					(this._convergence.Multiplier() as number) *
						(this._events.ProductionMultiplier() as number) *
						(this._crews.Multiplier(player) as number),
				),
			),
		);
		player.SetAttribute("CurrentZone", profile.CurrentZone as AttributeValue);
		if (GameConfig.Operations.TitlesEnabled === false) {
			player.SetAttribute("EquippedTitle", undefined);
			player.SetAttribute("EquippedTitleName", undefined);
			player.SetAttribute("EquippedTitleFx", undefined);
		} else {
			let titleId = "Cadet";
			const commandState = profile.Command as Dict | undefined;
			if (truthy(commandState) && typeIs(commandState.EquippedTitle, "string") && commandState.EquippedTitle !== "") {
				titleId = commandState.EquippedTitle;
			}
			let titleName: unknown = "Forge Cadet";
			let titleFx = "";
			for (const [, title] of pairs(GameConfig.Operations.Titles as Dict[])) {
				if (title.Id === titleId) {
					titleName = title.Name;
					titleFx = typeIs(title.Fx, "string") ? title.Fx : "";
					break;
				}
			}
			player.SetAttribute("EquippedTitle", titleId);
			player.SetAttribute("EquippedTitleName", titleName as AttributeValue);
			player.SetAttribute("EquippedTitleFx", titleFx);
		}
		// profile style is public too: nameplates, the player list and chat tint by it
		const profileStyle = ProfileStyle.read(profile.Cosmetics);
		player.SetAttribute("ProfileAccent", profileStyle.Accent);
		player.SetAttribute("ProfileFrame", profileStyle.Frame);
		// the equipped artifact is public: every client reads these for the overhead aura, the
		// player list and chat, so it has to be visible to the whole server, not just its owner
		const command = profile.Command as Dict | undefined;
		const artifactId =
			truthy(command) && typeIs(command.EquippedArtifact, "string") && truthy(command.EquippedArtifact)
				? command.EquippedArtifact
				: "";
		const artifactFound = artifactId !== "" ? Economy.GetArtifact(artifactId) : undefined;
		const artifact = truthy(artifactFound) ? (artifactFound as Dict) : undefined;
		const artifacts = command ? command.Artifacts : undefined;
		const ownedFound = artifact && isTable(artifacts) ? artifacts[artifactId] : undefined;
		const owned = truthy(ownedFound) ? ownedFound : undefined;
		if (artifact && isTable(owned)) {
			const level = math.max(1, math.floor(num(owned.Level) ?? 1));
			const power = (num(artifact.EffectPerLevel) ?? 0) * level;
			const effectText =
				artifact.EffectKind === "OfflineHours"
					? "+%.1fh offline".format(power)
					: "+%.0f%% %s".format(power * 100, tostring(artifact.EffectKind).lower());
			player.SetAttribute("EquippedArtifactName", tostring(artifact.Name));
			player.SetAttribute("EquippedArtifactElement", tostring(orElse(artifact.Element, () => "")));
			player.SetAttribute("EquippedArtifactRarity", tostring(orElse(artifact.Rarity, () => "COMMON")));
			player.SetAttribute("EquippedArtifactLevel", level);
			player.SetAttribute(
				"EquippedArtifactColor",
				typeIs(artifact.Color, "Color3") ? artifact.Color : Color3.fromRGB(170, 139, 255),
			);
			player.SetAttribute("EquippedArtifactEffect", effectText);
			player.SetAttribute("EquippedArtifact", artifactId);
		} else if (player.GetAttribute("EquippedArtifact") !== undefined) {
			for (const key of [
				"EquippedArtifact",
				"EquippedArtifactName",
				"EquippedArtifactElement",
				"EquippedArtifactRarity",
				"EquippedArtifactLevel",
				"EquippedArtifactColor",
				"EquippedArtifactEffect",
			]) {
				player.SetAttribute(key, undefined);
			}
		}
	}

	_announceServerEvent(phase: string, def: Dict) {
		let title: unknown;
		let body: unknown;
		let tone: string;
		if (phase === "Warning") {
			title = (def.Name as string) + " in a minute";
			body = def.Blurb;
			tone = "Info";
		} else if (phase === "Live") {
			// the client lands a live event as a moment out of the island; a toast would repeat it
			return;
		} else if (phase === "Completed") {
			title = "Order filled";
			body = "Everyone who helped has been paid.";
			tone = "Success";
		} else if (phase === "Defeated") {
			title = "The Titan is down";
			body = "Everyone who hit it has been paid.";
			tone = "Success";
		} else {
			title = (def.Name as string) + " is over";
			body = "The next event is a few minutes away.";
			tone = "Info";
		}
		for (const online of Players.GetPlayers()) {
			this._toastPlayer(online, title, body, tone);
		}
	}

	// pays whoever an event says earned something; one toast each, saying exactly what came in
	_payEvent(entries: Dict[], _def: Dict, why: string) {
		for (const [, entry] of pairs(entries)) {
			const player = Players.GetPlayerByUserId(entry.UserId as number);
			if (player === undefined) {
				continue;
			}
			let fluxPaid = 0;
			const fluxSeconds = (entry.FluxSeconds as number | undefined) ?? 0;
			const entryStardust = (entry.Stardust as number | undefined) ?? 0;
			const entryCores = (entry.Cores as number | undefined) ?? 0;
			const entryKeys = (entry.Keys as number | undefined) ?? 0;
			this._mutate(player, (profile: Profile) => {
				if (fluxSeconds > 0) {
					let amount = Economy.Mul(Economy.Production(profile), entry.FluxSeconds);
					if ((Economy.AsNumber(amount) as number) < 500) {
						amount = 500;
					}
					profile.Cash = Economy.Add(profile.Cash, amount);
					profile.RunCash = Economy.Add(profile.RunCash, amount);
					profile.LifetimeCash = Economy.Add(profile.LifetimeCash, amount);
					fluxPaid = Economy.AsNumber(amount) as number;
				}
				if (entryStardust > 0) {
					profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (entry.Stardust as number), 0, 1e14);
				}
				if (entryCores > 0) {
					profile.Cores = Economy.Add(profile.Cores, entry.Cores);
				}
				const items = profile.Items as Dict | undefined;
				if (entryKeys > 0 && truthy(entry.KeyCrate) && truthy(items) && truthy(items.Keys)) {
					const keys = items.Keys as Dict;
					const crate = entry.KeyCrate as string;
					keys[crate] = (num(keys[crate]) ?? 0) + (entry.Keys as number);
				}
				return responseSuccess(undefined);
			});
			const parts: string[] = [];
			if (fluxPaid > 0) {
				parts.push("+" + (Format.Number(fluxPaid) as string) + " Flux");
			}
			if (entryStardust > 0) {
				parts.push("+" + tostring(entry.Stardust) + " Stardust");
			}
			if (entryCores > 0) {
				parts.push("+" + tostring(entry.Cores) + " cores");
			}
			const rank = entry.Rank as number | undefined;
			let title: string;
			if (why === "race") {
				title = rank !== undefined && rank <= 3 ? "Forge Race: #%d".format(rank) : "Forge Race: you scored";
			} else if (why === "draw") {
				title = truthy(entry.Rank) ? "Your ticket was drawn" : "Lucky Draw: thanks for playing";
			} else if (why === "titan") {
				title = rank !== undefined && rank <= 3 ? "Titan down: #%d hitter".format(rank) : "Titan down";
			} else {
				title = rank !== undefined && rank <= 3 ? "Order filled: #%d".format(rank) : "Order filled";
			}
			this._toastPlayer(player, title, parts.join(", "), "Success");
		}
	}

	_settleProgression(player: Player, profile: Profile, levelState: Dict, production: unknown) {
		let progression = profile.Progression as Dict;
		if (!isTable(progression)) {
			progression = { RewardedLevel: -1, HalfwayPaidFor: -1, Surge: { Multiplier: 1, EndsAt: 0 } };
			profile.Progression = progression;
		}
		const now = os.time();
		const firstLook = (num(progression.RewardedLevel) ?? -1) < 0;
		const [owed, settled] = LevelRewards.owed(num(progression.RewardedLevel) ?? -1, levelState.Level) as LuaTuple<
			[unknown[], unknown]
		>;
		progression.RewardedLevel = settled;
		if (firstLook) {
			progression.HalfwayPaidFor = levelState.Level;
		}
		const fluxFor = (seconds: unknown, floor: number) => {
			let amount = Economy.Mul(production, seconds);
			if ((Economy.AsNumber(amount) as number) < floor) {
				amount = floor;
			}
			return amount;
		};
		if (owed.size() > 0) {
			let fluxTotal: unknown = 0;
			let stardustTotal = 0;
			let surge = progression.Surge;
			for (const reached of owed) {
				const def = ForgeLevels.get(reached) as Dict | undefined;
				const reward = LevelRewards.forLevel(reached, truthy(def) ? def.Tier : def) as Dict;
				const flux = fluxFor(reward.FluxSeconds, reward.MinFlux as number);
				profile.Cash = Economy.Add(profile.Cash, flux);
				fluxTotal = Economy.Add(fluxTotal, flux);
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (reward.Stardust as number), 0, 1e14);
				stardustTotal += reward.Stardust as number;
				surge = LevelRewards.mergeSurge(surge, now, reward.SurgeMultiplier, reward.SurgeSeconds);
			}
			progression.Surge = surge;
			progression.HalfwayPaidFor = math.max(num(progression.HalfwayPaidFor) ?? -1, levelState.Level as number);
			this._effect.fire(player, {
				Type: "LevelReward",
				Level: levelState.Level,
				Tier: levelState.Tier,
				Levels: owed,
				Flux: Economy.AsNumber(fluxTotal),
				Stardust: stardustTotal,
				SurgeMultiplier: (surge as Dict).Multiplier,
				SurgeEndsAt: (surge as Dict).EndsAt,
			});
		}
		const nextStep = levelState.Next as Dict | undefined;
		let nextReward: unknown = undefined;
		if (nextStep !== undefined) {
			nextReward = LevelRewards.forLevel(nextStep.Level, nextStep.Tier);
		}
		return {
			Mastery: LevelRewards.mastery(settled),
			Surge: {
				Multiplier: LevelRewards.surgeMultiplier(progression.Surge, now),
				EndsAt:
					(LevelRewards.surgeMultiplier(progression.Surge, now) as number) > 1
						? (progression.Surge as Dict).EndsAt
						: 0,
			},
			HalfwayPaidFor: progression.HalfwayPaidFor,
			NextReward: nextReward,
		};
	}

	_snapshot(player: Player): Dict | undefined {
		let profile = this._data.Get(player) as Profile | undefined;
		const runtime = this._runtime.get(player);
		if (!profile) {
			return undefined;
		}
		if (
			(!runtime || os.clock() >= ((runtime.BazaarRecoveryRetryAt as number | undefined) ?? 0)) &&
			truthy(BazaarService.NeedsRecovery(profile, player.UserId))
		) {
			const recovered = this._mutate(player, (draft: Profile) => {
				const [ok, message] = BazaarService.Roll(draft, os.time(), player.UserId) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
			if (!truthy(recovered.ok)) {
				if (runtime) {
					runtime.BazaarRecoveryRetryAt = os.clock() + 30;
				}
				ModuleLog.Every(
					"legacy-refund:" + player.UserId,
					30,
					"BlackMarket",
					"Legacy refund could not be committed for " + player.UserId + ": " + tostring(recovered.error),
				);
			}
			profile = this._data.Get(player) as Profile | undefined;
			if (!profile) {
				return undefined;
			}
		}
		const now = os.time();
		const baseProduction = Economy.Production(profile, now);
		const production = Economy.Mul(
			baseProduction,
			(this._convergence.Multiplier() as number) *
				(this._events.ProductionMultiplier() as number) *
				(this._crews.Multiplier(player) as number),
		);
		const capacity = Economy.Capacity(profile, now);
		const prestigeReward = Economy.PrestigeReward(Economy.Add(profile.RunCash, profile.Vault));
		const domain = orEmpty(profile.Domain, () => ({
			Rank: 0,
			Essence: 0,
			LastExpandedAt: 0,
			TotalRebirthsSpent: 0,
			TotalCoresSpent: 0,
		}));
		const domainRank = math.max(0, math.floor(num(domain.Rank) ?? 0));
		const [domainRequiredRebirths, domainRequiredCores] = Economy.DomainRequirements(domainRank) as LuaTuple<
			[unknown, unknown]
		>;
		const [domainEssenceReward, domainStardustReward] = Economy.DomainRewards(domainRank) as LuaTuple<[unknown, unknown]>;
		const continuum = orEmpty(profile.Continuum, () => ({ Rank: 0, TotalFluxSpent: 0, TotalStardustSpent: 0 }));
		const continuumRank = math.max(0, math.floor(num(continuum.Rank) ?? 0));
		const [continuumFluxCost, continuumStardustCost] = Economy.ContinuumCosts(continuumRank) as LuaTuple<
			[unknown, unknown]
		>;
		const [continuumProduction, continuumCapacity, continuumTap, continuumOffline] = Economy.ContinuumEffects(
			profile,
		) as LuaTuple<[unknown, unknown, unknown, unknown]>;
		if (runtime) {
			runtime.SnapshotId = ((runtime.SnapshotId as number | undefined) ?? 0) + 1;
		}
		const itemShop: Record<number, unknown> = {};
		ensureItemShop(profile);
		const items = profile.Items as Dict;
		(GameConfig.Items.ShopOffers as Dict[]).forEach((offer, i) => {
			const state = copyDictionary(offer) as Dict;
			const stockMax = offerStockMax(offer);
			const stock = ShopGrantEligibility.RemainingStock(
				((items.Shop as Dict).Stock as Dict)[offer.Id as string],
				stockMax,
			) as number;
			state.Stock = stock;
			state.StockMax = stockMax;
			state.DailyRefresh = offer.DailyRefresh === true;
			state.Purchased = stock <= 0;
			itemShop[i + 1] = state;
		});
		const featureUnlocks = ProgressionGate.FeatureStates(profile) as Record<string, Dict>;
		const levelState = ProgressionGate.LevelState(profile) as Dict;
		if (runtime) {
			const newlyUnlocked: Array<{ Id: string; State: Dict }> = [];
			const previousUnlocks = runtime.FeatureUnlocks as Record<string, unknown> | undefined;
			if (truthy(previousUnlocks)) {
				for (const [id, state] of pairs(featureUnlocks)) {
					if (truthy(state.Unlocked) && previousUnlocks[id] !== true) {
						newlyUnlocked.push({ Id: id, State: state });
					}
				}
			}
			const leveledUp =
				runtime.ForgeLevel !== undefined && (levelState.Level as number) > (runtime.ForgeLevel as number);
			runtime.ForgeLevel = levelState.Level;
			if (leveledUp) {
				const names: string[] = [];
				for (const entry of newlyUnlocked) {
					names.push(entry.State.Name as string);
				}
				table.sort(names);
				// the milestone card on the client names what opened and what it paid; no toast on top
				this._effect.fire(player, {
					Type: "LevelUp",
					Level: levelState.Level,
					Tier: levelState.Tier,
					Names: names,
				});
			} else if (newlyUnlocked.size() > 0) {
				const names: string[] = [];
				for (const entry of newlyUnlocked) {
					names.push(entry.State.Name as string);
				}
				const single = newlyUnlocked.size() === 1 ? newlyUnlocked[0] : undefined;
				this._toastPlayer(
					player,
					single ? (single.State.Name as string) + " unlocked" : "New systems unlocked",
					single ? "You can open it from the Forge menu." : names.join(", ") + " are ready in the Forge menu.",
					"Special",
				);
				this._effect.fire(player, {
					Type: "FeatureUnlocked",
					Id: single ? single.Id : undefined,
					Name: single ? single.State.Name : names.join(", "),
					Count: newlyUnlocked.size(),
				});
			}
			const current: Record<string, unknown> = {};
			for (const [id, state] of pairs(featureUnlocks)) {
				current[id] = state.Unlocked;
			}
			runtime.FeatureUnlocks = current;
		}
		levelState.Progression = this._settleProgression(player, profile, levelState, production);
		const storyState = StoryMailSnapshot.BuildStory(profile, GameConfig.Story, ProgressionGate);
		const [mailState, unreadMail] = StoryMailSnapshot.BuildMailbox(profile, GameConfig.Mail, ProgressionGate) as LuaTuple<
			[unknown, unknown]
		>;
		const guildMembership = profile.Guild as Dict | undefined;
		const guildId = (truthy(guildMembership) && truthy(guildMembership.Id) ? guildMembership.Id : "") as string;
		const guildCachedPublic = guildId !== "" ? this._guilds.GetCachedPublic(guildId) : undefined;
		const guildSnapshot = GuildMath.SnapshotPublic(guildMembership, guildCachedPublic) as Dict | undefined;
		if (truthy(guildSnapshot) && guildId !== "") {
			guildSnapshot.Community = this._guildCommunity.Snapshot(guildId);
		}
		const [overchargeCombo, overchargeMultiplier] = this._overchargeCombo(runtime, profile);
		const sky = orEmpty(profile.Sky, () => ({}));
		const charts = orEmpty(sky.Charts, () => ({}));
		const cipher = orEmpty(sky.Cipher, () => ({}));
		const dailyShop = profile.DailyShop;
		const cosmetics = profile.Cosmetics;
		const meta = profile.Meta as Dict;
		const finalProfile = profile;

		return {
			Game: {
				Name: GameConfig.Game.Name,
				Version: GameConfig.Game.Version,
				Update: GameConfig.Game.Update,
			},
			Cash: profile.Cash,
			Vault: profile.Vault,
			Cores: profile.Cores,
			Stardust: profile.Stardust,
			Rebirths: profile.Rebirths,
			Domain: ContinuumDomainMath.SnapshotDomainPublic({
				domain: domain,
				rank: domainRank,
				requiredRebirths: domainRequiredRebirths,
				requiredCores: domainRequiredCores,
				essenceReward: domainEssenceReward,
				stardustReward: domainStardustReward,
				rebirths: profile.Rebirths,
				cores: profile.Cores,
				domainConfig: GameConfig.Domain,
				MeetsRequired: RebirthGate.MeetsRequired,
				Gte: Economy.Gte,
				DomainTreeBonus: (kind: unknown) => Economy.DomainTreeBonus(finalProfile, kind),
			}),
			Foundry: FoundryService.State(profile, Workspace.GetServerTimeNow()),
			Continuum: ContinuumDomainMath.SnapshotContinuumPublic({
				rank: continuumRank,
				totalFluxSpent: continuum.TotalFluxSpent,
				totalStardustSpent: continuum.TotalStardustSpent,
				fluxCost: continuumFluxCost,
				stardustCost: continuumStardustCost,
				cash: profile.Cash,
				stardust: profile.Stardust,
				production: continuumProduction,
				capacity: continuumCapacity,
				tap: continuumTap,
				offline: continuumOffline,
				milestoneEvery: GameConfig.Continuum.MilestoneEvery,
				Gte: Economy.Gte,
			}),
			ForgeEchoes: ForgeEchoService.State(profile),
			Ascension: this._ascensionPublic(profile),
			RunCash: profile.RunCash,
			LifetimeCash: profile.LifetimeCash,
			Zone: profile.Zone,
			CurrentZone: profile.CurrentZone,
			Machines: copyDictionary(profile.Machines),
			Research: copyDictionary(profile.Research),
			GridUpgrades: copyDictionary(profile.GridUpgrades),
			Specialization: Specializations.Snapshot(profile, Economy, os.time(), runtime, {
				Production: baseProduction,
				Capacity: capacity,
			}),
			BoostInventory: copyDictionary(profile.BoostInventory),
			ActiveBoost: copyDictionary(profile.ActiveBoost),
			Quests: copyDictionary((profile.Quests as Dict).Items),
			Achievements: ProgressionService.AchievementStates(profile),
			Daily: ProgressionService.DailyState(profile),
			Wheel: ProgressionService.WheelState(profile),
			Bazaar: BazaarService.State(profile, os.time(), player.UserId),
			Sky: {
				Retired: true,
				Plotted: table.clone(orEmpty(charts.Plotted, () => ({}))),
				Cipher: {
					Solves: orElse(cipher.Solves, () => 0),
					Best: orElse(cipher.Best, () => 0),
				},
			},
			Command: ProgressionService.CommandState(profile),
			ForgePath: ProgressionService.ForgePathState(profile),
			TimedRewards: ProgressionService.TimedRewardState(profile),
			Items: {
				Inventory: copyDictionary(items.Inventory),
				Equipped: copyDictionary(items.Equipped),
				Essence: items.Essence,
				Keys: copyDictionary(items.Keys),
				Pity: copyDictionary(items.Pity),
				InventoryLimit: GameConfig.Items.InventoryLimit,
				Shop: itemShop,
				ShopRefreshAt: nextUtcMidnight(),
				AutoSalvage: AutoSalvageSnapshot.Public(items.AutoSalvage, copyDictionary),
				Effects: ItemLoadoutMath.EffectsPublic(profile, Economy),
				Discovered: copyDictionary(orElse(items.Discovered, () => ({}))),
				CodexBonus: Economy.CodexBonus(profile),
				Rigs: RelicRigs.Public(profile),
			},
			DailyShop: {
				Day: isTable(dailyShop) && truthy(dailyShop.Day) ? dailyShop.Day : -1,
				Bought: copyDictionary(isTable(dailyShop) && truthy(dailyShop.Bought) ? dailyShop.Bought : {}),
				Owned: isTable(dailyShop) && isTable(dailyShop.Owned) ? copyDictionary(dailyShop.Owned) : undefined,
			},
			Cosmetics: {
				CrateSkins: copyDictionary(
					isTable(cosmetics) && truthy(cosmetics.CrateSkins) ? cosmetics.CrateSkins : { Classic: true },
				),
				CrateSkin: isTable(cosmetics) && truthy(cosmetics.CrateSkin) ? cosmetics.CrateSkin : "Classic",
				ProfileAccent: ProfileStyle.read(cosmetics).Accent,
				ProfileFrame: ProfileStyle.read(cosmetics).Frame,
			},
			Anomaly: AnomalyService.State(profile),
			Lab: LabService.State(profile),
			Guild: guildSnapshot,
			GuildBonuses: copyDictionary(profile.GuildBonuses),
			SocialBoost: SocialBoost.PublicSnapshot(profile.SocialBoost, GameConfig.Social.MaxBoostedFriends, copyDictionary),
			SocialRewards: SocialBoost.CreatorRewardsPublic(profile.SocialRewards, ServerConfig.CreatorUsername),
			AutoForge: AutoSalvageSnapshot.PublicAutoForge(profile.AutoForge, copyDictionary),
			Trade: truthy(this._trades) ? this._trades.StatePublic(profile, player, now) : TradeDesk.LockedPublic(),
			Convergence: this._convergence.State(player, profile),
			FeatureUnlocks: featureUnlocks,
			Level: levelState,
			Story: storyState,
			Mailbox: StoryMailSnapshot.MailboxPublic(mailState, unreadMail),
			Admin: orElse(this._admin ? this._admin.State(player) : undefined, () => ({ Access: false })),
			Settings: copyDictionary(profile.Settings),
			Flags: copyDictionary(profile.Flags),
			Stats: copyDictionary(profile.Stats),
			Shop: ShopGrantEligibility.CatalogPublic(profile.OwnedPasses, copyDictionary),
			Production: production,
			RawProduction: Economy.RawProduction(profile),
			Capacity: capacity,
			CapacitySeconds: Economy.CapacitySeconds(profile, now),
			SteadyProduction: Economy.SteadyProduction(profile, now),
			FluxSurge: orElse(this._fluxSurge ? this._fluxSurge.State(now) : undefined, () => FluxSurgeService.IdleState()),
			ServerEvent: this._events.State(player),
			PermanentMultiplier: Economy.PermanentMultiplier(profile),
			AutoCollectRate: Economy.AutoCollectRate(profile),
			OfflineHours: Economy.OfflineHours(profile),
			OfflineEfficiency: Economy.OfflineEfficiency(profile),
			TapPower: Economy.TapPower(profile, now),
			CriticalChance: Economy.CriticalChance(profile),
			CriticalMultiplier: Economy.CriticalMultiplier(profile),
			Overcharge: OverchargeCombo.PublicSnapshot({
				combo: overchargeCombo,
				comboMultiplier: overchargeMultiplier,
				comboMax: GameConfig.Overcharge.ComboMax,
				comboWindow: overchargeComboWindow(profile),
				comboBonusPerStack: GameConfig.Overcharge.ComboBonusPerStack,
			}),
			PrestigeReward: prestigeReward,
			NextPrestigeTarget: Economy.NextPrestigeTarget(prestigeReward),
			Rebirth: this._rebirthPublic(profile, now),
			Revision: meta.Revision,
			SnapshotId: runtime && truthy(runtime.SnapshotId) ? runtime.SnapshotId : 0,
			ServerTime: now,
			Telemetry: encodeTelemetry(
				meta.Revision,
				profile.Settings,
				profile.Cash,
				profile.Vault,
				production,
				capacity,
				profile.Cores,
				profile.Stardust,
			),
			Offline: OfflineProjection.PublicSnapshot({
				runtime: runtime,
				production: production,
				vault: profile.Vault,
				offlineHours: Economy.OfflineHours(profile),
			}),
			Visitors: this._visitorList(player),
			Visit: VisitSnapshot.Resolve(
				this._visiting.get(player),
				Players.GetPlayers(),
				(host: Player) => this._data.Get(host),
				Economy,
			),
		};
	}

	_trimUnchangedSections(runtime: Runtime | undefined, snapshot: Dict, force?: boolean) {
		if (runtime === undefined) {
			return snapshot;
		}
		const now = os.clock();
		const previous = runtime.LastSentSections as Dict | undefined;
		const previousPrints = orEmpty(runtime.LastSentPrints, () => ({}));
		const sections: Dict = {};
		for (const [key, value] of pairs(snapshot)) {
			if (typeIs(value, "table")) {
				sections[key] = value;
			}
		}
		runtime.LastSentSections = sections;
		const full =
			truthy(force) ||
			previous === undefined ||
			now - ((runtime.LastFullSnapshotAt as number | undefined) ?? 0) >= FULL_SNAPSHOT_EVERY;
		const prints: Dict = {};
		if (full) {
			// Everything goes out anyway, so skip the deep compare. Only sections that needed a
			// fingerprint last time (they share tables) get one now, so the next push can still
			// reuse them; a section that newly starts sharing just gets resent once.
			for (const [key, value] of pairs(sections)) {
				if (previousPrints[key] !== undefined) {
					prints[key] = fingerprint(value);
				}
			}
			runtime.LastSentPrints = prints;
			runtime.LastFullSnapshotAt = now;
			return snapshot;
		}
		const trimmed = table.clone(snapshot);
		const reused: string[] = [];
		for (const [key, value] of pairs(sections)) {
			let verdict: boolean | undefined =
				previous !== undefined && previous[key] !== undefined ? sameValue(previous[key], value, 0) : false;
			if (verdict === undefined) {
				// shares tables with something else: compare what was actually sent instead
				const sent = fingerprint(value);
				prints[key] = sent;
				verdict = sent !== undefined && previousPrints[key] === sent;
			}
			if (verdict && !full) {
				trimmed[key] = undefined;
				reused.push(key);
			}
		}
		runtime.LastSentPrints = prints;
		if (full) {
			runtime.LastFullSnapshotAt = now;
			return snapshot;
		}
		if (reused.size() === 0) {
			return snapshot;
		}
		trimmed.Reused = reused;
		return trimmed;
	}

	// a snapshot that leaves this server by another path (a GetState reply) makes the next push a full one
	_forgetSentSections(player: Player) {
		const runtime = this._runtime.get(player);
		if (runtime) {
			runtime.LastSentSections = undefined;
		}
	}

	_pushState(player: Player, force?: boolean) {
		if (player.Parent !== Players) {
			return;
		}
		// the same revision pushed moments ago would be dropped below anyway; skip building the
		// whole snapshot for it (unless a Bazaar recovery is due, which the snapshot performs)
		if (!truthy(force)) {
			const early = this._runtime.get(player);
			const current = this._data.Get(player) as Profile | undefined;
			const currentMeta = current !== undefined ? (current.Meta as Dict | undefined) : undefined;
			if (
				early &&
				current !== undefined &&
				currentMeta !== undefined &&
				early.LastPushRevision === (num(currentMeta.Revision) ?? 0) &&
				os.clock() - ((early.LastPushAt as number | undefined) ?? 0) < 0.55 &&
				!truthy(BazaarService.NeedsRecovery(current, player.UserId))
			) {
				this._broadcastVisit(player);
				return;
			}
		}
		const snapshot = this._snapshot(player);
		if (snapshot) {
			const runtime = this._runtime.get(player);
			const now = os.clock();
			const revision = num(snapshot.Revision) ?? 0;
			if (
				!truthy(force) &&
				runtime &&
				runtime.LastPushRevision === revision &&
				now - ((runtime.LastPushAt as number | undefined) ?? 0) < 0.55
			) {
				return;
			}
			if (runtime) {
				runtime.LastPushRevision = revision;
				runtime.LastPushAt = now;
			}
			this._state.fire(player, this._trimUnchangedSections(runtime, snapshot, force));
		}
		this._broadcastVisit(player);
	}

	_mutate(player: Player, callback: (profile: Profile) => unknown, incrementRevision?: boolean): Response {
		const [success, result] = this._data.Update(
			player,
			(profile: Profile) => {
				const callbackResult = callback(profile);
				if (isTable(callbackResult) && callbackResult.ok === false) {
					return callbackResult;
				}
				clampProgressionNumbers(profile);
				enforceUnlimitedMoney(profile);

				const [, wouldReject] = this._antiCheat.Observe(player, "Mutation", profile) as LuaTuple<[unknown, unknown]>;
				if (truthy(wouldReject)) {
					// Returning a failed transaction quarantines the whole mutation, including the illegal credit.
					return responseError("That economy change was rejected.");
				}
				return callbackResult;
			},
			incrementRevision,
		) as LuaTuple<[unknown, unknown]>;
		if (!truthy(success)) {
			return responseError("Your profile is not ready. Please try again.");
		}
		if (!isTable(result) || !typeIs(result.ok, "boolean")) {
			return responseError("Couldn't finish that.");
		}
		const runtime = this._runtime.get(player);
		if (result.ok && runtime) {
			runtime.SpecializationPreviewKey = undefined;
		}
		return result;
	}

	_progressAnomalyFromAction(player: Player, action: string) {
		if (!truthy(anomalyChargeByAction[action])) {
			return;
		}
		const runtime = this._runtime.get(player);
		if (!runtime) {
			return;
		}
		runtime.PendingAnomalyActions = orElse(runtime.PendingAnomalyActions, () => []);
		const pending = runtime.PendingAnomalyActions as string[];
		if (pending.size() < 64) {
			pending.push(action);
		}
	}

	_pulseAnomaly(player: Player) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.Pulse(profile, this._random) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: truthy(details.BecameReady) ? "AnomalyReady" : "AnomalyPulse",
				Amount: details.Amount,
				Charge: details.Charge,
				Accurate: details.Accurate,
				Combo: details.Combo,
				PulseWindowStartedAt: details.PulseWindowStartedAt,
			});
			if (truthy(details.OverdriveTriggered)) {
				this._effect.broadcast({ Type: "OverdriveTriggered", Overdrive: AnomalyService.OverdriveState() });
			}
		}
		return result;
	}

	_stabilizeAnomaly(player: Player) {
		const [result, details] = anomalyCall(this, player, (profile) => {
			const outcome = AnomalyService.Stabilize(profile) as LuaTuple<[unknown, unknown, unknown]>;
			if (truthy(outcome[0])) {
				LabService.Progress(profile, "Stabilize", 1);
			}
			return outcome;
		});
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyStabilized",
				AnomalyId: details.AnomalyId,
				AnomalyName: details.AnomalyName,
				Fragments: details.Fragments,
				Stabilizations: details.Stabilizations,
				CoreTier: details.CoreTier,
				CoreXP: details.CoreXP,
				TiersGained: details.TiersGained,
			});
			if (truthy(details.OverdriveTriggered)) {
				this._effect.broadcast({ Type: "OverdriveTriggered", Overdrive: AnomalyService.OverdriveState() });
			}
		}
		return result;
	}

	_buyAnomalyProtocol(player: Player, protocolId: unknown) {
		if (!typeIs(protocolId, "string")) {
			return responseError("Choose a reactor upgrade and try again.");
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.BuyProtocol(profile, protocolId) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyProtocol",
				ProtocolId: details.ProtocolId,
				ProtocolName: details.ProtocolName,
				Level: details.Level,
			});
		}
		return result;
	}

	_activateAnomalySurge(player: Player) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.ActivateSurge(profile) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalySurge",
				EndsAt: details.EndsAt,
				Duration: details.Duration,
			});
		}
		return result;
	}

	_setAnomalyChannel(player: Player, channelId: unknown) {
		if (!typeIs(channelId, "string")) {
			return responseError("Pick a valid reactor channel.");
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.SetLoadout(profile, [channelId]) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			const loadout = details.Loadout as Record<number, unknown> | undefined;
			const first = truthy(loadout) ? loadout[1] : undefined;
			this._effect.fire(player, {
				Type: "AnomalyLoadout",
				Loadout: details.Loadout,
				Channel: truthy(first) ? first : channelId,
			});
		}
		return result;
	}

	_setAnomalyLoadout(player: Player, rawLoadout: unknown) {
		if (!typeIs(rawLoadout, "table")) {
			return responseError("Invalid reactor loadout.");
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.SetLoadout(profile, rawLoadout) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, { Type: "AnomalyLoadout", Loadout: details.Loadout });
		}
		return result;
	}

	_claimAnomalyMilestone(player: Player, tier: unknown) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.ClaimMilestone(profile, tier) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, { Type: "AnomalyMilestone", Tier: details.Tier });
		}
		return result;
	}

	_claimAnomalyDirective(player: Player, directiveId: unknown) {
		if (!typeIs(directiveId, "string")) {
			return responseError("That reactor job isn't valid.");
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => AnomalyService.ClaimDirective(profile, directiveId) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyDirective",
				DirectiveId: details.DirectiveId,
				DirectiveName: details.DirectiveName,
				Fragments: details.Fragments,
			});
		}
		return result;
	}

	// Forge Echoes: every echo action goes through EchoMath's rules in ForgeEchoService.Act
	_echoAct(player: Player, payload: unknown) {
		const op = isTable(payload) && truthy(payload.Op) ? payload.Op : "";
		const result = this._mutate(player, (profile: Profile) => {
			const [ok, message, extra] = ForgeEchoService.Act(profile, payload, this._random) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, extra);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "EchoAct", Op: op });
		}
		return result;
	}

	_collect(player: Player) {
		const result = this._mutate(player, (profile: Profile) => {
			const amount = profile.Vault;
			if (truthy(Economy.Lt(amount, 0.01))) {
				return responseError("Your vault is still charging.");
			}
			profile.Vault = 0;
			profile.Cash = Economy.Add(profile.Cash, amount);
			profile.RunCash = Economy.Add(profile.RunCash, amount);
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, amount);
			const stats = ensureStats(profile);
			stats.Collected = Economy.Add(stats.Collected, amount);
			const amountNumber = Economy.AsNumber(amount) as number;
			ProgressionService.Progress(profile, "EarnCash", amountNumber);
			LabService.Progress(profile, "BankFlux", amountNumber);
			ProgressionService.AwardCommandXP(profile, math.max(1, math.floor((math.log(amountNumber + 1) / math.log(10)) * 3)));
			ProgressionService.AwardForgePathXP(
				profile,
				ForgePathClaim.XpFromBankedAmount(amountNumber, GameConfig.Economy.ForgePathXP),
			);
			ForgeEchoService.Record(profile, "Collect", math.clamp(2 + math.log(amountNumber + 1) / math.log(10), 2, 12));
			const extra = this._events.OnCollect(player, amountNumber, Economy.AsNumber(Economy.Production(profile))) as Dict;
			const notes: string[] = [];
			if ((extra.FluxBonus as number) > 0) {
				const bonus = Economy.Mul(amount, extra.FluxBonus);
				profile.Cash = Economy.Add(profile.Cash, bonus);
				profile.RunCash = Economy.Add(profile.RunCash, bonus);
				profile.LifetimeCash = Economy.Add(profile.LifetimeCash, bonus);
				notes.push("+" + (Format.Number(bonus) as string) + " golden Flux");
			}
			if ((extra.Dust as number) > 0) {
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (extra.Dust as number), 0, 1e14);
				notes.push(tostring(extra.Dust) + " Stardust");
			}
			if ((extra.Cores as number) > 0) {
				profile.Cores = Economy.Add(profile.Cores, extra.Cores);
				notes.push(tostring(extra.Cores) + (extra.Cores === 1 ? " core" : " cores"));
			}
			const items = profile.Items as Dict | undefined;
			if ((extra.Keys as number) > 0 && truthy(extra.KeyCrate) && truthy(items) && truthy(items.Keys)) {
				const keys = items.Keys as Dict;
				const crate = extra.KeyCrate as string;
				keys[crate] = (num(keys[crate]) ?? 0) + (extra.Keys as number);
				notes.push("a crate key");
			}
			if (notes.size() > 0) {
				return responseSuccess(
					"Banked " + (Format.Number(amount) as string) + " Flux and found " + notes.join(", ") + ".",
					{ Amount: amount, Dust: extra.Dust, Cores: extra.Cores, Keys: extra.Keys },
				);
			}
			return responseSuccess("Banked " + (Format.Number(amount) as string) + " Flux.", { Amount: amount });
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "Collect", Amount: result.Amount });
		}
		return result;
	}

	// Op "Catch" (Falling Stars) or "Claim" with Drop (Supply Drop)
	_eventAct(player: Player, payload: unknown) {
		const op = isTable(payload) ? payload.Op : undefined;
		if (op === "Catch") {
			const [dust, reason] = this._events.CatchStar(player) as LuaTuple<[number | undefined, unknown]>;
			if (dust === undefined) {
				return responseError(orElse(reason, () => "Missed."));
			}
			return this._mutate(player, (profile: Profile) => {
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + dust, 0, 1e14);
				return responseSuccess(undefined, { Dust: dust });
			});
		} else if (op === "Claim") {
			const [reward, reason] = this._events.ClaimSupply(player, (payload as Dict).Drop) as LuaTuple<
				[Dict | undefined, unknown]
			>;
			if (reward === undefined) {
				return responseError(orElse(reason, () => "Missed it."));
			}
			return this._mutate(player, (profile: Profile) => {
				const rewardDust = orElse(reward.Stardust, () => 0) as number;
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + rewardDust, 0, 1e14);
				const items = profile.Items as Dict | undefined;
				if ((orElse(reward.Keys, () => 0) as number) > 0 && truthy(items) && truthy(items.Keys)) {
					const keys = items.Keys as Dict;
					const crate = reward.KeyCrate as string;
					keys[crate] = (num(keys[crate]) ?? 0) + (reward.Keys as number);
				}
				return responseSuccess("Got it: a crate key and " + tostring(rewardDust) + " Stardust.", {
					Dust: reward.Stardust,
					Keys: reward.Keys,
				});
			});
		}
		return responseError("Unknown event action.");
	}

	_overchargeCombo(runtime: Runtime | undefined, profile: unknown): LuaTuple<[number, number]> {
		if (!runtime) {
			return $tuple(0, 1);
		}
		const combo = math.max(0, math.floor(num(runtime.TapCombo) ?? 0));
		if (
			combo > 0 &&
			os.clock() - (num(runtime.LastTap) ?? 0) >
				overchargeComboWindow(profile) * (this._events.ComboWindowMultiplier() as number)
		) {
			return $tuple(0, 1);
		}
		return $tuple(combo, overchargeComboMultiplier(profile, combo));
	}

	_overcharge(player: Player) {
		const runtime = this._runtime.get(player);
		if (!runtime) {
			return responseError("Shop's still loading.");
		}
		const profileForCombo = this._data.Get(player);
		const nowClock = os.clock();
		if (nowClock - (runtime.LastTap as number) < 0.06) {
			return responseError("Overcharge is cooling down.");
		}
		let previousCombo = math.max(0, math.floor(num(runtime.TapCombo) ?? 0));
		if (
			nowClock - (runtime.LastTap as number) >
			overchargeComboWindow(profileForCombo) * (this._events.ComboWindowMultiplier() as number)
		) {
			previousCombo = 0;
		}
		const combo = math.min(OVERCHARGE_COMBO_MAX, previousCombo + 1);
		const comboMultiplier = overchargeComboMultiplier(profileForCombo, combo);
		runtime.LastTap = nowClock;
		runtime.TapCombo = combo;

		const result = this._mutate(
			player,
			(profile: Profile) => {
				const capacity = Economy.Capacity(profile);
				const room = Economy.Sub(capacity, profile.Vault);
				if (truthy(Economy.Lte(room, 0.01))) {
					return responseError("Your vault is full. Bank it first.");
				}
				const critical =
					this._random.NextNumber() <=
					(Economy.CriticalChance(profile) as number) + (this._events.CritBonus() as number);
				let amount = Economy.TapPower(profile);
				const eventTap = this._events.TapMultiplier();
				if (eventTap !== 1) {
					amount = Economy.Mul(amount, eventTap);
				}
				if (critical) {
					amount = Economy.Mul(amount, Economy.CriticalMultiplier(profile));
				}
				if (comboMultiplier > 1) {
					amount = Economy.Mul(amount, comboMultiplier);
				}
				amount = Economy.Min(room, amount);
				profile.Vault = Economy.Add(profile.Vault, amount);
				bumpStat(profile, "Taps", 1);
				LabService.Progress(profile, "Tap", 1);
				ProgressionService.Progress(profile, "Tap", 1);
				ProgressionService.AwardCommandXP(profile, 1);
				ForgeEchoService.Record(profile, "Surge", 1);
				return responseSuccess(undefined, {
					Amount: amount,
					Critical: critical,
					Combo: combo,
					ComboMultiplier: comboMultiplier,
					ComboMax: OVERCHARGE_COMBO_MAX,
					ComboWindow: overchargeComboWindow(profile) * (this._events.ComboWindowMultiplier() as number),
				});
			},
			false,
		);
		if (truthy(result.ok)) {
			this._events.OnTap(player);
			this._effect.fire(player, {
				Type: "Overcharge",
				Amount: result.Amount,
				Critical: result.Critical,
				Combo: result.Combo,
				ComboMultiplier: result.ComboMultiplier,
				ComboMax: result.ComboMax,
				ComboWindow: result.ComboWindow,
			});
		} else {
			runtime.TapCombo = previousCombo;
		}
		return result;
	}

	_buyMachine(player: Player, machineId: unknown, requestedAmount?: unknown) {
		if (!typeIs(machineId, "string")) {
			return responseError("Invalid machine request.");
		}
		const machineFound = Economy.GetMachine(machineId);
		if (!truthy(machineFound)) {
			return responseError("That machine does not exist.");
		}
		const machine = machineFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const machines = profile.Machines as Dict;
			const level = orElse(machines[machineId], () => 0) as number;
			if (level >= (machine.MaxLevel as number)) {
				return responseError("That machine is already at maximum level.");
			}
			const lockReason = ProgressionGate.UpgradeReason(profile, machine, profile.Machines);
			if (truthy(lockReason)) {
				return responseError((lockReason as string) + " first.");
			}
			const remainingLevels = (machine.MaxLevel as number) - level;
			let count: number;
			let cost: unknown;
			if (requestedAmount === "Max") {
				[count, cost] = Economy.AffordableMachineLevels(machineId, level, profile.Cash, remainingLevels) as LuaTuple<
					[number, unknown]
				>;
			} else {
				count = typeIs(requestedAmount, "number") ? math.clamp(math.floor(requestedAmount), 1, 50) : 1;
				count = math.min(count, remainingLevels);
				cost = Economy.MachineBulkCost(machineId, level, count);
			}
			if (count < 1) {
				return responseError("You cannot afford another level yet.");
			}
			if (truthy(Economy.Lt(profile.Cash, cost))) {
				return responseError("You need " + (Format.Number(Economy.Sub(cost, profile.Cash)) as string) + " more Flux.");
			}
			profile.Cash = Economy.Sub(profile.Cash, cost);
			machines[machineId] = level + count;
			bumpStat(profile, "MachinesBought", count);
			LabService.Progress(profile, "BuyLevels", count);
			const mastery = ensureCommandMastery(profile);
			mastery[machineId] = (num(mastery[machineId]) ?? 0) + count;
			ProgressionService.Progress(profile, "BuyMachine", count);
			ProgressionService.AwardCommandXP(profile, count * 5);
			ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12));
			return responseSuccess("%s gained %d levels and reached level %d.".format(machine.Name as string, count, level + count));
		});
		if (truthy(result.ok)) {
			const profile = this._data.Get(player);
			this._world.RefreshPlot(player, profile);
		}
		return result;
	}

	_queueStatePush(player: Player) {
		if (this._queuedStatePushes.get(player)) {
			return;
		}
		this._queuedStatePushes.set(
			player,
			task.defer(() => {
				this._queuedStatePushes.delete(player);
				if (this._running && player.Parent === Players) {
					this._pushState(player);
				}
			}),
		);
	}

	_setAutoForge(player: Player, payload: unknown) {
		if (!isTable(payload) || !typeIs(payload.Enabled, "boolean")) {
			return responseError("Choose a valid Auto-Forge setup.");
		}
		const machineFound = Economy.GetMachine(payload.MachineId);
		if (!truthy(machineFound)) {
			return responseError("That machine cannot be queued.");
		}
		const machine = machineFound as Dict;
		const reserve = math.clamp(num(payload.Reserve) ?? 0.25, 0, 0.9);
		const enabled = payload.Enabled;
		return this._mutate(player, (profile: Profile) => {
			profile.AutoForge = orElse(profile.AutoForge, () => ({}));
			const autoForge = profile.AutoForge as Dict;
			autoForge.Enabled = enabled;
			autoForge.MachineId = machine.Id;
			autoForge.Reserve = reserve;
			autoForge.Bought = math.max(0, math.floor(num(autoForge.Bought) ?? 0));
			const state = enabled ? "online" : "paused";
			return responseSuccess(
				"Auto-Forge %s: buying %s and keeping %d%% in reserve.".format(
					state,
					machine.Name as string,
					math.floor(reserve * 100 + 0.5),
				),
			);
		});
	}

	_tickAutoForge(player: Player) {
		const live = this._data.Get(player) as Profile | undefined;
		const queue = live ? live.AutoForge : undefined;
		if (!live || !isTable(queue) || queue.Enabled !== true) {
			return;
		}
		const machineFound = Economy.GetMachine(queue.MachineId);
		if (!truthy(machineFound)) {
			return;
		}
		const machine = machineFound as Dict;
		const machineId = machine.Id as string;
		const maxLevel = machine.MaxLevel as number;
		const level = orElse((live.Machines as Dict)[machineId], () => 0) as number;
		const reserve = math.clamp(num(queue.Reserve) ?? 0.25, 0, 0.9);
		if (level < maxLevel) {
			const lockReason = ProgressionGate.UpgradeReason(live, machine, live.Machines);
			const cost = Economy.MachineCost(machineId, level);
			if (truthy(lockReason) || truthy(Economy.Gt(cost, Economy.Mul(live.Cash, 1 - reserve)))) {
				return;
			}
		}

		const [ok, result] = this._data.AtomicUpdate(
			player,
			(profile: Profile) => {
				const current = profile.AutoForge;
				if (!isTable(current) || current.Enabled !== true || current.MachineId !== machineId) {
					return responseError("Auto-Forge changed before purchase.");
				}
				const machines = profile.Machines as Dict;
				const currentLevel = orElse(machines[machineId], () => 0) as number;
				if (currentLevel >= maxLevel) {
					current.Enabled = false;
					return responseSuccess("Auto-Forge paused at maximum level.");
				}
				if (truthy(ProgressionGate.UpgradeReason(profile, machine, profile.Machines))) {
					return responseError("Auto-Forge target is still locked.");
				}
				const currentReserve = math.clamp(num(current.Reserve) ?? 0.25, 0, 0.9);
				const remaining = maxLevel - currentLevel;
				const spendable = Economy.Mul(profile.Cash, 1 - currentReserve);
				const [count, cost] = Economy.AffordableMachineLevels(machineId, currentLevel, spendable, remaining) as LuaTuple<
					[number, unknown]
				>;
				if (count < 1) {
					return responseError("Auto-Forge is preserving its reserve.");
				}
				profile.Cash = Economy.Sub(profile.Cash, cost);
				machines[machineId] = currentLevel + count;
				bumpStat(profile, "MachinesBought", count);
				current.Bought = math.max(0, math.floor(num(current.Bought) ?? 0)) + count;
				LabService.Progress(profile, "BuyLevels", count);
				const mastery = ensureCommandMastery(profile);
				mastery[machineId] = (num(mastery[machineId]) ?? 0) + count;
				ProgressionService.Progress(profile, "BuyMachine", count);
				ProgressionService.AwardCommandXP(profile, count * 5);
				ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12));
				enforceUnlimitedMoney(profile);
				this._antiCheat.Observe(player, "AutoForge", profile);
				return responseSuccess("Auto-Forge bought one machine level.");
			},
			true,
			"auto-forge",
		) as LuaTuple<[unknown, unknown]>;
		if (truthy(ok) && isTable(result) && result.ok === true) {
			const profile = this._data.Get(player);
			if (truthy(profile)) {
				this._world.RefreshPlot(player, profile);
			}
			this._queueStatePush(player);
		}
	}

	_buyResearch(player: Player, researchId: unknown, requestedAmount?: unknown) {
		if (!typeIs(researchId, "string")) {
			return responseError("Invalid research request.");
		}
		const researchFound = Economy.GetResearch(researchId);
		if (!truthy(researchFound)) {
			return responseError("That research project does not exist.");
		}
		const research = researchFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const researchLevels = profile.Research as Dict;
			const level = orElse(researchLevels[researchId], () => 0) as number;
			if (level >= (research.MaxLevel as number)) {
				return responseError("That research is already complete.");
			}
			const lockReason = ProgressionGate.UpgradeReason(profile, research, profile.Research);
			if (truthy(lockReason)) {
				return responseError((lockReason as string) + " first.");
			}
			const remainingLevels = (research.MaxLevel as number) - level;
			let count: number;
			let cost: unknown;
			if (requestedAmount === "Max") {
				[count, cost] = Economy.AffordableResearchLevels(researchId, level, profile.Cash, remainingLevels) as LuaTuple<
					[number, unknown]
				>;
			} else {
				count = typeIs(requestedAmount, "number") ? math.clamp(math.floor(requestedAmount), 1, 50) : 1;
				count = math.min(count, remainingLevels);
				cost = Economy.ResearchBulkCost(researchId, level, count);
			}
			if (count < 1) {
				return responseError("You cannot afford another research level yet.");
			}
			if (truthy(Economy.Lt(profile.Cash, cost))) {
				return responseError("You need " + (Format.Number(Economy.Sub(cost, profile.Cash)) as string) + " more Flux.");
			}
			profile.Cash = Economy.Sub(profile.Cash, cost);
			researchLevels[researchId] = level + count;
			bumpStat(profile, "ResearchBought", count);
			LabService.Progress(profile, "BuyLevels", count);
			ProgressionService.Progress(profile, "BuyResearch", count);
			ProgressionService.AwardCommandXP(profile, count * 4);
			ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.7, 2, 12));
			return responseSuccess("%s gained %d levels and reached level %d.".format(research.Name as string, count, level + count));
		});
		return result;
	}

	_unlockZone(player: Player, rawZoneId: unknown) {
		let zoneId = rawZoneId;
		if (typeIs(zoneId, "string")) {
			zoneId = num(zoneId);
		}
		if (!typeIs(zoneId, "number")) {
			return responseError("Invalid world request.");
		}
		const zoneNumber = math.floor(zoneId + 0.5);
		const zoneFound = Economy.GetZone(zoneNumber);
		if (!truthy(zoneFound)) {
			return responseError("That world does not exist.");
		}
		const zone = zoneFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const [kind, err] = ZoneUnlock.Evaluate(
				profile.Zone,
				profile.Rebirths,
				profile.Cores,
				profile.Cash,
				zoneNumber,
				zone,
				Economy.Lt,
			) as LuaTuple<[unknown, unknown]>;
			if (kind === "Travel") {
				profile.CurrentZone = zoneNumber;
				return responseSuccess("Traveled to " + (zone.Name as string) + ".");
			}
			if (kind === "Error") {
				if (err === "NEED_MORE_FLUX") {
					return responseError("You need " + (Format.Number(Economy.Sub(zone.Cost, profile.Cash)) as string) + " more Flux.");
				}
				return responseError(err as string);
			}
			profile.Cash = Economy.Sub(profile.Cash, zone.Cost);
			profile.Zone = zoneNumber;
			profile.CurrentZone = zoneNumber;
			LabService.Progress(profile, "UnlockWorld", 1);
			ForgeEchoService.Record(profile, "Explore", 12);
			return responseSuccess("Unlocked " + (zone.Name as string) + " and its production bonus.");
		});
		if (truthy(result.ok)) {
			this._world.RefreshPlot(player, this._data.Get(player));
		}
		return result;
	}

	_selectZone(player: Player, rawZoneId: unknown) {
		let zoneId = rawZoneId;
		if (typeIs(zoneId, "string")) {
			zoneId = num(zoneId);
		}
		if (!typeIs(zoneId, "number")) {
			return responseError("Invalid world request.");
		}
		const zoneNumber = math.floor(zoneId + 0.5);
		const zoneFound = Economy.GetZone(zoneNumber);
		if (!truthy(zoneFound)) {
			return responseError("That world does not exist.");
		}
		const zone = zoneFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			if (zoneNumber > (profile.Zone as number)) {
				return responseError("Unlock that world first.");
			}
			profile.CurrentZone = zoneNumber;
			return responseSuccess("Traveled to " + (zone.Name as string) + ".");
		});
		if (truthy(result.ok)) {
			this._world.RefreshPlot(player, this._data.Get(player));
		}
		return result;
	}

	_rebirthPublic(profile: Profile, now: number): Dict {
		const ledger = rebirthLedger(profile, now);
		const [run, bank] = rebirthRun(profile, now, ledger) as LuaTuple<[Dict, unknown]>;
		const [reward, dust] = rebirthBase(profile, bank) as LuaTuple<[unknown, number]>;
		const quote = RebirthMath.quote(ledger, {
			Cores: truthy(reward) ? Economy.AsNumber(reward) : 0,
			Stardust: dust,
		}, run) as Dict;
		const [holds, status] = RebirthMath.vowHolds(ledger, run) as LuaTuple<[unknown, unknown]>;
		const [, nextStar] = RebirthMath.nextStar(ledger) as LuaTuple<[unknown, unknown]>;
		return {
			Ready: reward !== undefined,
			Cores: truthy(reward) ? Economy.Max(1, Economy.Floor(Economy.Mul(reward, quote.CoreMultiplier))) : 0,
			Stardust: truthy(reward) ? quote.Stardust : 0,
			Grade: quote.Grade,
			Vow: ledger.Vow,
			VowHolds: holds,
			VowStatus: status,
			VowOpen: now <= (ledger.RunStartedAt as number) + (RebirthMath.VOW_GRACE as unknown as number),
			KeptVows: table.clone(ledger.Kept as object),
			RunStartedAt: ledger.RunStartedAt,
			Lifetime: ledger.Lifetime,
			Stars: table.clone(ledger.Stars as object),
			Pending: RebirthMath.pendingStars(ledger),
			NextStar: nextStar,
			Keep: table.clone(ledger.Keep as object),
			KeepSlots: RebirthMath.keepSlots(ledger.Lifetime),
			Runs: table.clone(ledger.Runs as object),
			BestCores: ledger.BestCores,
			FastestSeconds: ledger.FastestSeconds,
		};
	}

	_rebirth(player: Player, rawPayload: unknown) {
		const payload = (typeIs(rawPayload, "table") ? rawPayload : {}) as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const rebirthConfig = (GameConfig.Economy.Rebirth as Dict | undefined) ?? ({} as Dict);
			const ledger = rebirthLedger(profile, now);
			const [run, bank] = rebirthRun(profile, now, ledger) as LuaTuple<[Dict, unknown]>;
			const [baseReward, stardustBase] = rebirthBase(profile, bank) as LuaTuple<[unknown, number]>;
			if (baseReward === undefined) {
				return responseError(
					"Bank at least " +
						(Format.Number as Fn)(GameConfig.Economy.PrestigeRequirement) +
						" run Flux first.",
				);
			}
			if (payload.Keep !== undefined) {
				RebirthMath.setKeep(ledger, payload.Keep);
			}
			const quote = RebirthMath.quote(ledger, {
				Cores: Economy.AsNumber(baseReward),
				Stardust: stardustBase,
			}, run) as Dict;
			const reward = Economy.Max(1, Economy.Floor(Economy.Mul(baseReward, quote.CoreMultiplier)));
			const stardustReward = quote.Stardust as number;
			const bankedVault = profile.Vault;
			const multiplierBefore = Economy.PermanentMultiplier(profile);
			profile.Cores = Economy.AsNumber(Economy.Add(profile.Cores, reward));
			profile.Stardust = math.clamp((tonumber(profile.Stardust) ?? 0) + stardustReward, 0, 1e14);
			if (!typeIs(profile.BoostInventory, "table")) {
				profile.BoostInventory = {};
			}
			const boostInventory = profile.BoostInventory as Dict;
			const celebrationBoost = (rebirthConfig.CelebrationBoostId as string | undefined) ?? "Overdrive";
			const bonusCount = math.max(1, math.floor(tonumber(rebirthConfig.BonusOverdrive) ?? 1));
			if (truthy(GameConfig.Boosts[celebrationBoost])) {
				boostInventory[celebrationBoost] = ((boostInventory[celebrationBoost] as number | undefined) ?? 0) + bonusCount;
			}
			const carry = RebirthMath.carry(
				ledger,
				profile.Machines,
				Economy.AsNumber(profile.Vault),
				GameConfig.Economy.StartingCash,
				keepsakeAllowed(profile),
			) as Dict;
			const entry = RebirthMath.close(
				ledger,
				quote,
				now,
				typeIs(payload.Vow, "string") ? payload.Vow : undefined,
				undefined,
			) as Dict;
			profile.Rebirths = (profile.Rebirths as number) + 1;
			profile.Cash = carry.Cash;
			profile.Vault = 0;
			profile.RunCash = 0;
			profile.Zone = 1;
			profile.CurrentZone = 1;
			profile.Machines = carry.Machines;

			const items = profile.Items as Dict | undefined;
			if (items !== undefined && typeIs(items.Equipped, "table")) {
				const equipped = items.Equipped as Dict;
				for (const [target] of pairs(equipped)) {
					const [slot, targetId] = tostring(target).match("^(%a+):([%w_]+)$");
					if (slot === "Machine") {
						const level = (profile.Machines as Dict)[targetId as string] as unknown;
						if (!typeIs(level, "number") || level < 1) {
							equipped[target as string] = undefined;
						}
					}
				}
			}
			const vow = RebirthMath.vow(quote.Vow) as Dict | undefined;
			const vowLine =
				vow !== undefined && truthy(quote.Kept)
					? " " + (vow.Name as string) + " kept."
					: vow !== undefined
						? " " + (vow.Name as string) + " broken."
						: "";
			// reward can be a persisted big-number string, so %d would throw on late-game rebirths
			return responseSuccess(
				"Rebirth " +
					tostring(entry.N) +
					", grade " +
					tostring(quote.Grade) +
					". +" +
					(Format.Number as Fn)(reward) +
					" cores, +" +
					(Format.Number as Fn)(stardustReward) +
					" Stardust." +
					vowLine,
				{
					Rebirths: profile.Rebirths,
					MultiplierBefore: multiplierBefore,
					MultiplierAfter: Economy.PermanentMultiplier(profile),
					Reward: reward,
					StardustReward: stardustReward,
					BankedVault: bankedVault,
					CelebrationBoost: celebrationBoost,
					NextTarget: GameConfig.Economy.PrestigeRequirement,
					Grade: quote.Grade,
					Vow: quote.Vow,
					VowKept: quote.Kept,
					Seconds: entry.Seconds,
					Carried: carry.Machines,
					NextVow: ledger.Vow,
					StarLit: (RebirthMath.pendingStars(ledger) as unknown[]).size() > 0,
				},
			);
		});
		if (truthy(result.ok)) {
			this._world.RefreshPlot(player, this._data.Get(player));
			this._effect.broadcast({
				Type: "Rebirth",
				UserId: player.UserId,
				Position: this._world.GetPlotPosition(player),
				Reward: result.Reward,
				StardustReward: result.StardustReward,
				BankedVault: result.BankedVault,
				CelebrationBoost: result.CelebrationBoost,
				Grade: result.Grade,
				VowKept: result.VowKept,
			});
		}
		return result;
	}

	// between rebirths: light a star, swear or drop a vow, choose keepsakes
	_rebirthAct(player: Player, rawPayload: unknown) {
		if (!typeIs(rawPayload, "table")) {
			return responseError("Invalid rebirth request.");
		}
		const payload = rawPayload as Dict;
		return this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const ledger = rebirthLedger(profile, now);
			if (payload.Op === "Star") {
				const index = math.floor(tonumber(payload.Index) ?? 0);
				const [ok, message] = RebirthMath.pickStar(
					ledger,
					index,
					math.floor(tonumber(payload.Pick) ?? 0),
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(ok)) {
					return responseError(message);
				}
				return responseSuccess("Star lit: " + tostring(message) + ".", { Star: index });
			} else if (payload.Op === "Vow") {
				const [ok, message] = RebirthMath.swear(
					ledger,
					typeIs(payload.Vow, "string") ? payload.Vow : "",
					now,
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(ok)) {
					return responseError(message);
				}
				return responseSuccess(message, { Vow: ledger.Vow });
			} else if (payload.Op === "Keep") {
				if (!truthy(RebirthMath.setKeep(ledger, payload.Keep))) {
					return responseError("Pick machines to keep.");
				}
				return responseSuccess("Keepsakes set.", { Keep: table.clone(ledger.Keep as object) });
			}
			return responseError("Unknown rebirth action.");
		});
	}

	_claimQuest(player: Player, questId: unknown) {
		if (!typeIs(questId, "string")) {
			return responseError("Invalid mission request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimQuest(profile, questId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimAchievement(player: Player, achievementId: unknown) {
		if (!typeIs(achievementId, "string")) {
			return responseError("Invalid milestone request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimAchievement(profile, achievementId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimDaily(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimDaily(profile) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimTimedReward(player: Player, rewardIndex: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimTimedReward(profile, rewardIndex) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_bazaarPlay(player: Player, payload: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const [recovered, recoveryMessage] = BazaarService.Roll(profile, now, player.UserId) as LuaTuple<
				[unknown, unknown]
			>;
			if (!truthy(recovered)) {
				return responseError(recoveryMessage);
			}
			const [ok, message, extra] = BazaarService.Play(
				profile,
				this._random,
				payload,
				now,
				player.UserId,
			) as LuaTuple<[unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, { Result: extra });
		});
	}

	_spinWheel(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (!typeIs(rawPayload, "table") || !typeIs(payload!.ExpectedSpin, "number")) {
			return responseError("Refresh the wheel before spinning.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, prizeIndex, prizeId, pityHit] = ProgressionService.SpinWheel(
				profile,
				this._random,
				payload!.ExpectedSpin,
			) as LuaTuple<[unknown, unknown, unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, {
				PrizeIndex: prizeIndex,
				PrizeId: prizeId,
				Pity: pityHit === true,
			});
		});
	}

	_launchExpedition(player: Player, expeditionId: unknown) {
		if (!typeIs(expeditionId, "string")) {
			return responseError("Invalid expedition request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.LaunchExpedition(profile, expeditionId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimExpedition(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, artifactId, artifactNew] = ProgressionService.ClaimExpedition(
				profile,
				this._random,
			) as LuaTuple<[unknown, unknown, unknown, unknown]>;
			return truthy(ok)
				? responseSuccess(message, { ArtifactId: artifactId, ArtifactNew: artifactNew })
				: responseError(message);
		});
	}

	_equipArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError("Invalid artifact request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.EquipArtifact(profile, artifactId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_buyArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError("Invalid artifact request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, fresh] = ProgressionService.BuyArtifact(profile, artifactId) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			return truthy(ok)
				? responseSuccess(message, { ArtifactId: artifactId, ArtifactNew: fresh })
				: responseError(message);
		});
	}

	_upgradeArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError("Invalid artifact request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.UpgradeArtifact(profile, artifactId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_upgradeCrew(player: Player, roleId: unknown) {
		if (!typeIs(roleId, "string")) {
			return responseError("Invalid crew request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.UpgradeCrew(profile, roleId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimCommanderReward(player: Player, level: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimCommanderReward(profile, level) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimWeeklyDirective(player: Player, directiveId: unknown) {
		if (!typeIs(directiveId, "string")) {
			return responseError("Invalid weekly directive.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimWeeklyDirective(profile, directiveId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimSeasonTier(player: Player, tier: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimSeasonTier(profile, tier) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimForgePathStep(player: Player, step: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.ClaimForgePathStep(profile, step) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_buySignalOffer(player: Player, offerId: unknown) {
		if (!typeIs(offerId, "string")) {
			return responseError("Invalid signal shop offer.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.BuySignalOffer(profile, offerId) as LuaTuple<
				[unknown, unknown]
			>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_equipTitle(player: Player, titleId: unknown) {
		const operations = GameConfig.Operations as Dict;
		if (operations.TitlesEnabled === false) {
			return responseError((operations.TitleStatus as string | undefined) ?? "Titles are temporarily unavailable.");
		}
		if (!typeIs(titleId, "string")) {
			return responseError("Invalid title request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ProgressionService.EquipTitle(profile, titleId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_setProfileStyle(player: Player, accent: unknown, frame: unknown) {
		if ((accent !== undefined && !typeIs(accent, "string")) || (frame !== undefined && !typeIs(frame, "string"))) {
			return responseError("Invalid profile style.");
		}
		let saved: ProfileStyle.ProfileStyleState | undefined;
		const result = this._mutate(player, (profile: Profile) => {
			saved = undefined;
			const current = ProfileStyle.read(profile.Cosmetics);
			const [chosen, problem] = ProfileStyle.validate(current, accent, frame, num(profile.Rebirths) ?? 0);
			if (chosen === undefined) {
				return responseError(problem ?? "That style is not available.");
			}
			if (!isTable(profile.Cosmetics)) {
				profile.Cosmetics = { CrateSkins: { Classic: true }, CrateSkin: "Classic" };
			}
			const cosmetics = profile.Cosmetics as Dict;
			cosmetics.ProfileAccent = chosen.Accent;
			cosmetics.ProfileFrame = chosen.Frame;
			saved = chosen;
			return responseSuccess("Profile style saved.");
		});
		// publish only once the transaction committed, so other players never see an unsaved style
		if (result.ok === true && saved !== undefined) {
			player.SetAttribute("ProfileAccent", saved.Accent);
			player.SetAttribute("ProfileFrame", saved.Frame);
		}
		return result;
	}

	_redeemCode(player: Player, rawCode: unknown) {
		if (!typeIs(rawCode, "string")) {
			return responseError("Enter a valid code.");
		}
		const code = string.upper(string.gsub(rawCode, "%s+", "")[0]);
		if (code.size() < 1 || code.size() > 24) {
			return responseError("Enter a valid code.");
		}
		const codeData = (ServerConfig.Codes as Dict)[code] as Dict | undefined;
		if (codeData === undefined) {
			return responseError("That code is invalid or already used.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.Codes, "table")) {
				profile.Codes = {};
			}
			const codes = profile.Codes as Dict;
			if (truthy(codes[code])) {
				return responseError("You already redeemed that code.");
			}
			codes[code] = true;
			const rewardText = ProgressionService.ApplyReward(profile, codeData.Reward, Economy.Production(profile));
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_grantDevProduct(profile: Profile, productDef: Dict): string {
		return ProgressionService.ApplyReward(
			profile,
			productDef.Reward,
			Economy.Production(profile),
		) as string;
	}

	_processReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision {
		const player = Players.GetPlayerByUserId(receiptInfo.PlayerId as number);
		if (player === undefined) {
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		const productDef = (MonetizationConfig.FindDevProductByProductId as Fn)(receiptInfo.ProductId) as
			| Dict
			| undefined;
		if (productDef === undefined) {
			ModuleLog.Warn("Shop", string.format("unknown ProductId %s", tostring(receiptInfo.ProductId)));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		const purchaseKey = tostring(receiptInfo.PurchaseId);
		let rewardText = "";
		let already = false;
		const [updated] = this._data.Update(player, (profile: Profile) => {
			const [recorded, alreadyProcessed] = ReceiptLedger.Record(
				profile.Receipts,
				purchaseKey,
				os.time(),
			) as LuaTuple<[unknown, unknown]>;
			profile.Receipts = recorded;
			if (truthy(alreadyProcessed)) {
				already = true;
				return;
			}
			rewardText = this._grantDevProduct(profile, productDef);
		}) as LuaTuple<[unknown]>;
		if (!truthy(updated)) {
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}

		if (!truthy(this._data.Save(player, false))) {
			ModuleLog.Warn("Shop", string.format("receipt %s is waiting on a save", purchaseKey));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		if (!already) {
			this._syncLeaderstats(player, this._data.Get(player) as Profile | undefined);
			this._pushState(player);
			this._toastPlayer(
				player,
				"Purchase complete",
				rewardText !== "" ? rewardText : (productDef.Name as string),
				"Special",
			);
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return Enum.ProductPurchaseDecision.PurchaseGranted;
	}

	_syncShop(player: Player) {
		const ownedPasses = new Set<string>();
		for (const passDef of MonetizationConfig.GamePasses as Dict[]) {
			if ((passDef.PassId as number) > 0) {
				const [ok, owns] = pcall(() =>
					MarketplaceService.UserOwnsGamePassAsync(User.fromId(player.UserId), passDef.PassId as number),
				);
				if (ok && truthy(owns)) {
					ownedPasses.add(passDef.Key as string);
				}
			}
		}

		if (!this._running || player.Parent !== Players || this._runtime.get(player) === undefined) {
			return responseError("That forge session is no longer active.");
		}
		return this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.OwnedPasses, "table")) {
				profile.OwnedPasses = {};
			}
			if (!typeIs(profile.Receipts, "table")) {
				profile.Receipts = {};
			}
			const owned = profile.OwnedPasses as Dict;
			for (const passKey of ownedPasses) {
				owned[passKey] = true;
			}
			return responseSuccess("Dock inventory synced.");
		});
	}

	_studioGrantProduct(player: Player, rawKey: unknown) {
		if (!truthy(ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return responseError("Studio grants are disabled in live servers.");
		}
		if (!typeIs(rawKey, "string")) {
			return responseError("Invalid product key.");
		}
		const productDef = (MonetizationConfig.FindDevProductByKey as Fn)(rawKey) as Dict | undefined;
		const passDef = (MonetizationConfig.FindPassByKey as Fn)(rawKey) as Dict | undefined;
		if (productDef === undefined && passDef === undefined) {
			return responseError("Unknown studio product or pass.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			if (passDef !== undefined) {
				if (!typeIs(profile.OwnedPasses, "table")) {
					profile.OwnedPasses = {};
				}
				const owned = profile.OwnedPasses as Dict;
				if (truthy(owned[passDef.Key as string])) {
					return responseSuccess((passDef.Name as string) + " already owned.");
				}
				owned[passDef.Key as string] = true;
				const parts: string[] = [];
				if ((num(passDef.ProductionBonus) ?? 0) > 0) {
					parts.push(string.format("+%d%% production", math.floor((num(passDef.ProductionBonus) ?? 0) * 100 + 0.5)));
				}
				if ((num(passDef.CapacityBonus) ?? 0) > 0) {
					parts.push(string.format("+%d%% vault", math.floor((num(passDef.CapacityBonus) ?? 0) * 100 + 0.5)));
				}
				const detail = parts.size() > 0 ? parts.join(" · ") : "Pass linked";
				return responseSuccess((passDef.Name as string) + ": " + detail);
			}
			assert(productDef !== undefined, "studio grant missing product");
			const rewardText = this._grantDevProduct(profile, productDef);
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, "Purchase test", truthy(result.message) ? result.message : rawKey, "Success");
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_activateBoost(player: Player, boostId: unknown) {
		if (!typeIs(boostId, "string") || !truthy(GameConfig.Boosts[boostId])) {
			return responseError("Invalid boost request.");
		}
		const boost = GameConfig.Boosts[boostId] as Dict;
		return this._mutate(player, (profile: Profile) => {
			const active = ensureActiveBoost(profile) as Dict;
			if ((active.EndsAt as number) > os.time()) {
				return responseError("Another boost is already active.");
			}
			const inventory = ensureBoostInventory(profile) as Dict;
			if ((tonumber(inventory[boostId]) ?? 0) < 1) {
				return responseError("You do not own that boost.");
			}
			inventory[boostId] = math.max(0, math.floor(tonumber(inventory[boostId]) ?? 0) - 1);
			profile.ActiveBoost = { Id: boostId, EndsAt: os.time() + (boost.Duration as number) };
			return responseSuccess((boost.Name as string) + " is running.");
		});
	}

	_createItem(profile: Profile, definitionId: string): string | undefined {
		const items = ProfileBagMath.EnsureItems(profile) as Dict;
		if (itemById[definitionId] === undefined || (inventoryCount(profile) as number) >= (GameConfig.Items.InventoryLimit as number)) {
			return undefined;
		}
		const inventory = items.Inventory as Dict;
		let uid = "";
		do {
			uid = string.format("IT%07d", items.NextId as number);
			items.NextId = (items.NextId as number) + 1;
		} while (inventory[uid] !== undefined);
		inventory[uid] = {
			DefinitionId: definitionId,
			Level: 1,
			AcquiredAt: os.time(),
		};
		if (!typeIs(items.Discovered, "table")) {
			items.Discovered = {};
		}
		(items.Discovered as Dict)[definitionId] = true;
		bumpStat(profile, "ItemsFound", 1);
		return uid;
	}

	_rollItemDefinition(crate: Dict, pity: number) {
		return CrateRollResolver.roll(
			crate,
			pity,
			GameConfig.Items.Rarities,
			GameConfig.Items.Definitions,
			(definition: Dict) => definition.Rarity,
			(lo: number, hi: number) => this._random.NextNumber(lo, hi),
			(lo: number, hi: number) => this._random.NextInteger(lo, hi),
			CrateConfig.RarityOrder,
			CrateConfig.MinimumRollInterval,
		);
	}

	// Abuse patterns that are only visible across requests. Each one is a flag, never a rejection
	// on its own: the request's own validation already decided whether it goes through.
	_flagFailedRequest(player: Player, action: string) {
		const category = ActionBuckets.CategoryOf(action);
		if (category === "Purchase" && Ledger.Burst("buy-fail:" + player.UserId, 20, 15)) {
			Report(player, "purchase-probing", 1.5, "more than 15 refused purchases in 20s, last " + action);
		} else if (category === "Trade" && Ledger.Burst("trade-fail:" + player.UserId, 30, 15)) {
			Report(player, "trade-probing", 1.5, "more than 15 refused trade requests in 30s, last " + action);
		}
	}

	_flagTradeInvite(player: Player, targetUserId: unknown) {
		const key = "trade-invite:" + player.UserId + ":" + tostring(targetUserId);
		// a repeat invite to the same player is one entry; fan-out to many different players is the signal
		if (!Ledger.Burst(key, 60, 1)) {
			if (Ledger.Burst("trade-invite-fanout:" + player.UserId, 60, 8)) {
				Report(player, "trade-invite-spam", 2, "trade invites to more than 8 players in 60s");
			}
		}
	}

	_buyItemOffer(player: Player, offerId: unknown) {
		if (!typeIs(offerId, "string") || itemOfferById[offerId] === undefined) {
			return responseError("That market offer does not exist.");
		}
		const offer = itemOfferById[offerId] as Dict;
		const policyNote = PolicyGate.OfferBlocked(player, offer);
		if (policyNote !== undefined) {
			return responseError(policyNote);
		}
		return this._mutate(player, (profile: Profile) => {
			const items = ProfileBagMath.EnsureItems(profile) as Dict;
			ensureItemShop(profile);
			const stockMax = offerStockMax(offer);
			const shop = items.Shop as Dict;
			const stock = shop.Stock as Dict;
			const purchased = shop.Purchased as Dict;
			const remaining = ShopGrantEligibility.RemainingStock(stock[offerId], stockMax);
			const [eligible, denyReason] = ShopGrantEligibility.EvaluateBuy(
				offer,
				remaining,
				inventoryCount(profile),
				GameConfig.Items.InventoryLimit,
				// Cash above 1e15 persists as an Omega string; compare it as a number
				offer.Currency === "Cash" ? progressionNumber(profile.Cash) : profile[offer.Currency as string],
				(need: unknown, currency: unknown) =>
					string.format("You need %s more %s.", (Format.Number as Fn)(need) as string, tostring(currency)),
			) as LuaTuple<[unknown, unknown]>;
			if (!truthy(eligible)) {
				return responseError(truthy(denyReason) ? denyReason : "That market offer is unavailable.");
			}
			const currency = offer.Currency as string;
			if (currency === "Cash") {
				profile.Cash = Economy.Sub(profile.Cash, offer.Price as number);
			} else {
				profile[currency] = (profile[currency] as number) - (offer.Price as number);
			}
			const keys = items.Keys as Dict;
			let itemUid: string | undefined;
			if (offer.Kind === "Key") {
				keys[offer.CrateId as string] = ((keys[offer.CrateId as string] as number | undefined) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Essence") {
				items.Essence = (items.Essence as number) + (offer.Amount as number);
			} else if (offer.Kind === "Item") {
				itemUid = this._createItem(profile, offer.ItemId as string);
				if (itemUid === undefined) {
					return responseError("The market could not deliver that item.");
				}
			} else {
				return responseError("That market offer is misconfigured.");
			}
			const nextStock = (remaining as number) - 1;
			stock[offerId] = nextStock;
			purchased[offerId] = nextStock <= 0;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((offer.Name as string) + " bought.", { ItemUid: itemUid, Stock: nextStock });
		});
	}

	_buyDailyOffer(player: Player, slot: unknown) {
		if (!typeIs(slot, "number") || slot !== slot) {
			return responseError("That daily offer does not exist.");
		}
		const [ShopCatalog] = shopShared();
		const now = os.time();
		const day = ShopCatalog.day(now);
		const policy = PolicyGate.Get(player);
		return this._mutate(player, (profile: Profile) => {
			const cosmetics = ProfileBagMath.EnsureCosmetics(profile, (id: unknown) => ShopCatalog.skin(id) !== undefined) as Dict;
			const shop = ProfileBagMath.EnsureDailyShop(profile, day, cosmetics.CrateSkins) as Dict;
			const offers = ShopCatalog.roll(player.UserId, day, shop.Owned) as Dict[];
			const offer = offers[math.floor(slot) - 1];
			if (offer === undefined) {
				return responseError("That daily offer does not exist.");
			}
			const policyNote = PlayPolicy.offerBlocked(policy, offer);
			if (policyNote !== undefined) {
				return responseError(policyNote);
			}
			const bought = shop.Bought as Dict;
			if ((ShopCatalog.remaining(offer, bought) as number) <= 0) {
				return responseError("You've bought all of that one today.");
			}
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (offer.Kind === "Skin" && crateSkins[offer.SkinId as string] === true) {
				return responseError("You already own that skin.");
			}
			if (offer.Kind === "Cache" && (inventoryCount(profile) as number) >= (GameConfig.Items.InventoryLimit as number)) {
				return responseError("Your relic inventory is full.");
			}
			const denied = spendShopCurrency(profile, offer.Currency as string, offer.Price as number);
			if (denied !== undefined) {
				return responseError(denied);
			}
			const items = ProfileBagMath.EnsureItems(profile) as Dict;
			const keys = items.Keys as Dict;
			const detail: Dict = { Slot: offer.Slot, Kind: offer.Kind };
			if (offer.Kind === "Key") {
				keys[offer.CrateId as string] = ((keys[offer.CrateId as string] as number | undefined) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Essence") {
				items.Essence = (items.Essence as number) + (offer.Amount as number);
			} else if (offer.Kind === "Boost") {
				const inventory = ensureBoostInventory(profile) as Dict;
				inventory[offer.BoostId as string] =
					math.floor(tonumber(inventory[offer.BoostId as string]) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Flux") {
				const generated = Economy.Max(
					500,
					Economy.Mul(Economy.SteadyProduction(profile), 60 * (offer.Minutes as number)),
				);
				profile.Cash = Economy.Add(profile.Cash, generated);
				profile.RunCash = Economy.Add(profile.RunCash, generated);
				profile.LifetimeCash = Economy.Add(profile.LifetimeCash, generated);
			} else if (offer.Kind === "Skin") {
				crateSkins[offer.SkinId as string] = true;
			} else if (offer.Kind === "Cache") {
				const candidates: Dict[] = [];
				for (const definition of GameConfig.Items.Definitions as Dict[]) {
					if (definition.Rarity === offer.Rarity) {
						candidates.push(definition);
					}
				}
				if (candidates.size() === 0) {
					return responseError("That cache is empty.");
				}
				const definition = candidates[this._random.NextInteger(0, candidates.size() - 1)];
				const discovered = typeIs(items.Discovered, "table") ? (items.Discovered as Dict) : ({} as Dict);
				const wasOwned = discovered[definition.Id as string] === true;
				const uid = this._createItem(profile, definition.Id as string);
				if (uid === undefined) {
					return responseError("Your relic inventory is full.");
				}
				detail.Rolls = [
					{
						Uid: uid,
						DefinitionId: definition.Id,
						Rarity: definition.Rarity,
						New: !wasOwned,
						Pity: false,
						AutoSalvaged: false,
						Essence: 0,
					},
				];
			} else {
				return responseError("That offer is misconfigured.");
			}
			const key = tostring(offer.Slot);
			bought[key] = ((bought[key] as number | undefined) ?? 0) + 1;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((offer.Name as string) + " bought.", detail);
		});
	}

	_buyCrateSkin(player: Player, id: unknown) {
		const [ShopCatalog] = shopShared();
		const skin = ShopCatalog.skin(id) as Dict | undefined;
		if (skin === undefined || skin.Price === undefined) {
			return responseError("That skin isn't for sale.");
		}
		if (truthy(skin.DailyOnly)) {
			return responseError("That skin only appears in the Daily Shop.");
		}
		return this._mutate(player, (profile: Profile) => {
			const cosmetics = ProfileBagMath.EnsureCosmetics(profile, (skinId: unknown) => ShopCatalog.skin(skinId) !== undefined) as Dict;
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (crateSkins[skin.Id as string] === true) {
				return responseError("You already own that skin.");
			}
			ProfileBagMath.EnsureDailyShop(profile, ShopCatalog.day(os.time()), crateSkins);
			const price = skin.Price as Dict;
			const denied = spendShopCurrency(profile, price.Currency as string, price.Amount as number);
			if (denied !== undefined) {
				return responseError(denied);
			}
			crateSkins[skin.Id as string] = true;
			cosmetics.CrateSkin = skin.Id;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((skin.Name as string) + " unlocked and equipped.", { Skin: skin.Id });
		});
	}

	_equipCrateSkin(player: Player, id: unknown) {
		const [ShopCatalog] = shopShared();
		const skin = ShopCatalog.skin(id) as Dict | undefined;
		if (skin === undefined) {
			return responseError("That skin doesn't exist.");
		}
		return this._mutate(player, (profile: Profile) => {
			const cosmetics = ProfileBagMath.EnsureCosmetics(profile, (skinId: unknown) => ShopCatalog.skin(skinId) !== undefined) as Dict;
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (crateSkins[skin.Id as string] !== true) {
				return responseError("You don't own that skin yet.");
			}
			cosmetics.CrateSkin = skin.Id;
			return responseSuccess((skin.Name as string) + " equipped.", { Skin: skin.Id });
		});
	}

	_fuseRelics(player: Player, definitionId: unknown) {
		if (!typeIs(definitionId, "string") || itemById[definitionId] === undefined) {
			return responseError("That relic doesn't exist.");
		}
		const [, RelicSystem] = shopShared();
		const definition = itemById[definitionId] as Dict;
		return this._mutate(player, (profile: Profile) => {
			const items = ProfileBagMath.EnsureItems(profile) as Dict;
			const inventory = items.Inventory as Dict;
			const maxStars = (GameConfig.Items.MaxStars as number | undefined) ?? 5;
			const [targetUid, fodderUid, reason] = RelicSystem.fusionPair(
				inventory,
				items.Equipped,
				definitionId,
				maxStars,
			) as LuaTuple<[unknown, unknown, unknown]>;
			if (targetUid === undefined || fodderUid === undefined) {
				return responseError(truthy(reason) ? reason : "Those relics can't be fused.");
			}
			const target = inventory[targetUid as string] as Dict;
			const fodder = inventory[fodderUid as string] as Dict;
			const [stars, level] = RelicSystem.fuse(target, fodder, maxStars) as LuaTuple<[number, number]>;
			target.Stars = stars;
			target.Level = math.min(level, definition.MaxLevel as number);
			inventory[fodderUid as string] = undefined;
			bumpStat(profile, "RelicsFused", 1);
			return responseSuccess(
				string.format("%s fused to %d star%s.", definition.Name as string, stars, stars === 1 ? "" : "s"),
				{
					Uid: targetUid,
					Stars: stars,
					DefinitionId: definitionId,
					Rarity: definition.Rarity,
				},
			);
		});
	}

	_openItemCrate(player: Player, crateId: unknown, rawCount: unknown) {
		if (!typeIs(crateId, "string") || crateById[crateId] === undefined) {
			return responseError("That crate channel does not exist.");
		}
		const [count, countError] = CrateRoll.NormalizeOpenCount(rawCount) as LuaTuple<[number | undefined, unknown]>;
		if (count === undefined) {
			return responseError(truthy(countError) ? countError : "Crates can be opened one or five at a time.");
		}
		const crate = crateById[crateId] as Dict;
		return this._mutate(player, (profile: Profile) => {
			const items = ProfileBagMath.EnsureItems(profile) as Dict;
			const keys = items.Keys as Dict;
			if (((keys[crateId] as number | undefined) ?? 0) < count) {
				return responseError(
					string.format(
						"You need %d more %s keys.",
						count - ((keys[crateId] as number | undefined) ?? 0),
						crate.Name as string,
					),
				);
			}
			const autoRules = ensureAutoSalvage(profile) as Dict;
			const ownedPasses = profile.OwnedPasses as Dict | undefined;
			const autoEnabled =
				autoRules.Enabled === true && ownedPasses !== undefined && ownedPasses.AutoSalvage === true;

			const guaranteedRecycle = CrateRoll.GuaranteedRecycle(
				crate.Weights,
				autoEnabled,
				autoRules.KeepNew,
				autoRules.Rarities,
			);
			const requiredSlots = CrateRoll.RequiredSlots(count, guaranteedRecycle) as number;
			if ((inventoryCount(profile) as number) + requiredSlots > (GameConfig.Items.InventoryLimit as number)) {
				return responseError("Your item inventory does not have enough open slots.");
			}
			keys[crateId] = (keys[crateId] as number) - count;
			const rolls: Dict[] = [];
			const cosmetics = ProfileBagMath.EnsureCosmetics(profile) as Dict;
			const shopCatalog = SharedDataSuite("ShopCatalog") as Kit;
			const equippedSkin = shopCatalog.skin(cosmetics.CrateSkin) as Dict | undefined;
			const pityStep = CrateExpansion.pityStep(cosmetics, equippedSkin) as number;
			const rarities = autoRules.Rarities as Dict;
			const pityBag = items.Pity as Dict;
			for (let index = 0; index < count; index++) {
				const pity = (pityBag[crateId] as number | undefined) ?? 0;
				const [definition, rarity, pityHit] = this._rollItemDefinition(crate, pity) as LuaTuple<
					[Dict | undefined, string, unknown]
				>;
				if (definition === undefined) {
					return responseError("That crate has no valid drops configured.");
				}
				if (!typeIs(items.Discovered, "table")) {
					items.Discovered = {};
				}
				const discovered = items.Discovered as Dict;
				const wasOwned = discovered[definition.Id as string] === true;
				const shouldAutoSalvage =
					autoEnabled && rarities[rarity] === true && !(autoRules.KeepNew !== false && !wasOwned);
				let uid: string | undefined;
				let autoEssence = 0;
				if (shouldAutoSalvage) {
					autoEssence = CrateExpansion.salvageEssence(
						cosmetics,
						equippedSkin,
						itemSalvageValue({ Level: 1 } as Dict, definition),
					) as number;
					items.Essence = (items.Essence as number) + autoEssence;
					bumpStat(profile, "ItemsFound", 1);
					bumpStat(profile, "ItemsSalvaged", 1);
					discovered[definition.Id as string] = true;
					uid = string.format("AUTO%07d", items.NextId as number);
					items.NextId = (items.NextId as number) + 1;
				} else {
					uid = this._createItem(profile, definition.Id as string);
					if (uid === undefined) {
						return responseError(
							"The crate decoder ran out of inventory space. Adjust auto-salvage or clear a slot.",
						);
					}
				}
				pityBag[crateId] = truthy(pityHit) ? 0 : pity + pityStep;
				rolls[index] = {
					Uid: uid,
					DefinitionId: definition.Id,
					Rarity: rarity,
					New: !wasOwned,
					Pity: pityHit,
					AutoSalvaged: shouldAutoSalvage,
					Essence: autoEssence,
				};
			}
			const skinBonus = CrateExpansion.openBonus(cosmetics, equippedSkin, count) as number;
			items.Essence = (items.Essence as number) + skinBonus;
			bumpStat(profile, "CratesOpened", count);
			LabService.Progress(profile, "OpenCrate", count);
			return responseSuccess(
				string.format("Decoded %d %s%s.", count, crate.Name as string, count === 1 ? "" : "s"),
				{ Rolls: rolls, CrateId: crateId, Pity: pityBag[crateId], SkinEssence: skinBonus },
			);
		});
	}

	_equipItem(player: Player, uid: unknown, target: unknown) {
		if (!typeIs(uid, "string") || !typeIs(target, "string")) {
			return responseError("Invalid socket request.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			const definition = instance !== undefined ? (itemById[instance.DefinitionId as string] as Dict | undefined) : undefined;
			if (definition === undefined) {
				return responseError("That item is not in your inventory.");
			}
			const [slot, targetId] = target.match("^(%a+):([%w_]+)$");
			if (definition.Slot !== slot) {
				return responseError(
					string.format("%s items only fit %s sockets.", definition.Name as string, definition.Slot as string),
				);
			}
			if (
				typeIs(definition.Targets, "table") &&
				!(definition.Targets as string[]).includes(targetId as string)
			) {
				return responseError((definition.Name as string) + " is not compatible with that upgrade.");
			}
			const ownedLevel =
				slot === "Machine"
					? (profile.Machines as Dict)[targetId as string]
					: slot === "Research"
						? (profile.Research as Dict)[targetId as string]
						: undefined;
			if (!typeIs(ownedLevel, "number") || ownedLevel < 1) {
				return responseError("Unlock at least one level of that upgrade before socketing an item.");
			}
			const equipped = items.Equipped as Dict;
			for (const [equippedTarget, equippedUid] of pairs(equipped)) {
				if (equippedUid === uid) {
					equipped[equippedTarget as string] = undefined;
				}
			}
			equipped[target] = uid;
			const [rigCount, rigNote] = grantLitRigs(profile);
			const attached = (definition.Name as string) + " attached to " + tostring(targetId) + ".";
			return responseSuccess(rigCount > 0 ? attached + " " + rigNote + "." : attached, {
				ItemName: definition.Name,
				Rarity: definition.Rarity,
				Target: target,
			});
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, "Relic linked", result.message, "Success");
			this._effect.fire(player, {
				Type: "ItemLinked",
				ItemName: result.ItemName,
				Rarity: result.Rarity,
				Target: result.Target,
			});
		}
		return result;
	}

	_unequipItem(player: Player, target: unknown) {
		if (!typeIs(target, "string")) {
			return responseError("Invalid socket request.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			const equipped = (profile.Items as Dict).Equipped as Dict;
			if (equipped[target] === undefined) {
				return responseError("That socket is already empty.");
			}
			equipped[target] = undefined;
			return responseSuccess("Item returned to inventory.");
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, "Relic detached", result.message, "Info");
		}
		return result;
	}

	_upgradeItem(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError("Invalid item request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError("That item is not in your inventory.");
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError("That item is not in your inventory.");
			}
			if ((instance.Level as number) >= (definition.MaxLevel as number)) {
				return responseError("That item is already max level.");
			}
			const cost = math.floor(
				(definition.EssenceBase as number) * math.pow(1.55, math.max(0, (instance.Level as number) - 1)),
			);
			if ((items.Essence as number) < cost) {
				return responseError(
					string.format("You need %d more item essence.", cost - (items.Essence as number)),
				);
			}
			items.Essence = (items.Essence as number) - cost;
			instance.Level = (instance.Level as number) + 1;
			return responseSuccess(
				string.format("%s upgraded to level %d.", definition.Name as string, instance.Level as number),
			);
		});
	}

	_salvageItem(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError("Invalid item request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError("That item is not in your inventory.");
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError("That item is not in your inventory.");
			}
			if (instance.Locked === true) {
				return responseError("Unlock that relic before salvaging it.");
			}
			for (const [, equippedUid] of pairs(items.Equipped as object)) {
				if (equippedUid === uid) {
					return responseError("Detach that item before salvaging it.");
				}
			}
			const essence = itemSalvageValue(instance, definition);
			inventory[uid] = undefined;
			items.Essence = (items.Essence as number) + essence;
			bumpStat(profile, "ItemsSalvaged", 1);
			return responseSuccess(
				string.format("Salvaged %s for %d essence.", definition.Name as string, essence),
				{ Amount: essence },
			);
		});
	}

	_setSetting(player: Player, rawPayload: unknown) {
		if (!typeIs(rawPayload, "table")) {
			return responseError("Invalid setting request.");
		}
		const payload = rawPayload as Dict;
		const Schema = SharedDataSuite("SettingsSchema") as Kit;
		const accepts = (key: unknown): boolean => typeIs(key, "string") && truthy(Schema.accepts(key));
		const notifyKeys: Record<string, boolean> = {
			NotifyGuild: true,
		};
		if (typeIs(payload.Values, "table")) {
			return this._mutate(player, (profile: Profile) => {
				let applied = 0;
				for (const [key, value] of pairs(payload.Values as object)) {
					if (applied >= 24) {
						break;
					}
					if (typeIs(key, "string") && typeIs(value, "number") && accepts(key)) {
						(profile.Settings as Dict)[key] = Schema.normalize(key, value);
						applied += 1;
					}
				}
				if (applied === 0) {
					return responseError("Unknown setting.");
				}
				SettingsSeal.Apply(profile);
				const label = payload.Label;
				if (typeIs(label, "string") && label !== "") {
					const clipped = string.sub(label, 1, 80);
					const [, brokenAt] = utf8.len(clipped);
					return responseSuccess(brokenAt !== undefined ? string.sub(clipped, 1, brokenAt - 1) : clipped);
				}
				return responseSuccess("Settings updated.");
			});
		}
		if (!typeIs(payload.Key, "string") || !typeIs(payload.Value, "number")) {
			return responseError("Unknown setting.");
		}
		const key = payload.Key;
		const value = payload.Value;
		if (accepts(key)) {
			return this._mutate(player, (profile: Profile) => {
				(profile.Settings as Dict)[key] = Schema.normalize(key, value);
				SettingsSeal.Apply(profile);
				return responseSuccess("Setting updated.");
			});
		}
		if (truthy(notifyKeys[key])) {
			return this._mutate(player, (profile: Profile) => {
				(profile.Settings as Dict)[key] = value >= 0.5 ? 1 : 0;
				return responseSuccess(value >= 0.5 ? "You'll be notified." : "Notification cleared.");
			});
		}
		return responseError("Unknown setting.");
	}

	// Star Foundry: every move is one FoundryAct with an Op (rules in FoundryMath, moves in FoundryService)
	_foundryAct(player: Player, payload: unknown) {
		const now = Workspace.GetServerTimeNow();
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, extra] = FoundryService.Act(profile, payload, this._random, now) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			if (!truthy(ok)) {
				return responseError(truthy(message) ? message : "That foundry move is not valid.");
			}
			return responseSuccess(message, truthy(extra) ? extra : {});
		});
	}

	_upgradeContinuum(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.Continuum, "table")) {
				profile.Continuum = {
					Rank: 0,
					TotalFluxSpent: 0,
					TotalStardustSpent: 0,
				};
			}
			const continuum = profile.Continuum as Dict;
			const rank = math.max(0, math.floor(tonumber(continuum.Rank) ?? 0));
			if (rank >= ((GameConfig.Continuum as Dict).MaxRank as number)) {
				return responseError("The Continuum has reached the exact-integer engine limit.");
			}
			const [fluxCost, stardustCost] = Economy.ContinuumCosts(rank) as LuaTuple<[unknown, number]>;
			if (Economy.Lt(profile.Cash, fluxCost)) {
				return responseError(
					"You need " + (Format.Number as Fn)(Economy.Sub(fluxCost, profile.Cash)) + " more Flux.",
				);
			}
			if (Economy.Lt(profile.Stardust, stardustCost)) {
				return responseError(
					"You need " + (Format.Number as Fn)(Economy.Sub(stardustCost, profile.Stardust)) + " more Stardust.",
				);
			}

			profile.Cash = Economy.Sub(profile.Cash, fluxCost);
			profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, stardustCost));
			continuum.Rank = rank + 1;
			continuum.TotalFluxSpent = Economy.Persist(Economy.Add(continuum.TotalFluxSpent, fluxCost));
			continuum.TotalStardustSpent = math.min(
				1e308,
				math.max(0, tonumber(continuum.TotalStardustSpent) ?? 0) + stardustCost,
			);
			const stats = ensureStats(profile) as Dict;
			stats.ContinuumUpgrades = math.min(1e308, math.max(0, tonumber(stats.ContinuumUpgrades) ?? 0) + 1);
			ProgressionService.AwardCommandXP(profile, 20 + math.min(480, rank * 2));

			const [nextProduction] = Economy.ContinuumEffects(profile) as LuaTuple<[unknown]>;
			const milestone = (rank + 1) % ((GameConfig.Continuum as Dict).MilestoneEvery as number) === 0;
			return responseSuccess(
				string.format(
					"Continuum rank %d reached. Production is now %s.",
					rank + 1,
					(Format.Number as Fn)(nextProduction) + "x",
				),
				{ Level: rank + 1, Milestone: milestone },
			);
		});
	}

	_toggleItemLock(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError("Invalid relic request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const inventory = (profile.Items as Dict).Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError("That relic is not in your inventory.");
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError("That relic is not in your inventory.");
			}
			instance.Locked = instance.Locked !== true;
			return responseSuccess(
				instance.Locked === true
					? (definition.Name as string) + " protected."
					: (definition.Name as string) + " unlocked.",
				{ Uid: uid, Locked: instance.Locked },
			);
		});
	}

	_bulkSalvageItems(player: Player, rawUids: unknown) {
		if (!typeIs(rawUids, "table")) {
			return responseError("Select at least one relic.");
		}
		return this._mutate(player, (profile: Profile) => {
			const requested = new Set<string>();
			let requestCount = 0;
			for (const [, uid] of pairs(rawUids)) {
				if (!typeIs(uid, "string") || uid.size() < 1 || uid.size() > 48) {
					return responseError("The relic selection is invalid.");
				}
				if (!requested.has(uid)) {
					requestCount += 1;
					if (requestCount > 25) {
						return responseError("Salvage up to 25 relics at once.");
					}
					requested.add(uid);
				}
			}
			if (requestCount === 0) {
				return responseError("Select at least one relic.");
			}
			const items = profile.Items as Dict;
			const equipped = new Set<string>();
			for (const [, equippedUid] of pairs(items.Equipped as object)) {
				if (typeIs(equippedUid, "string")) {
					equipped.add(equippedUid);
				}
			}
			const inventory = items.Inventory as Dict;
			let removed = 0;
			let essence = 0;
			let protectedCount = 0;
			for (const uid of requested) {
				const instance = inventory[uid] as Dict | undefined;
				const definition =
					instance !== undefined ? (itemById[instance.DefinitionId as string] as Dict | undefined) : undefined;
				if (definition !== undefined && !equipped.has(uid) && instance!.Locked !== true) {
					inventory[uid] = undefined;
					removed += 1;
					essence += itemSalvageValue(instance!, definition);
				} else if (instance !== undefined) {
					protectedCount += 1;
				}
			}
			if (removed === 0) {
				return responseError(
					protectedCount > 0
						? "Every selected relic is equipped or protected."
						: "Those relics are no longer available.",
				);
			}
			items.Essence = (items.Essence as number) + essence;
			bumpStat(profile, "ItemsSalvaged", removed);
			return responseSuccess(
				string.format(
					"Salvaged %d relic%s for %d essence%s.",
					removed,
					removed === 1 ? "" : "s",
					essence,
					protectedCount > 0 ? string.format("; %d protected", protectedCount) : "",
				),
				{ Count: removed, Amount: essence, Protected: protectedCount },
			);
		});
	}

	_equipBestItems(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const targets = ItemLoadoutMath.BuildTargets(
				GameConfig.Machines,
				GameConfig.Research,
				profile.Machines,
				profile.Research,
			) as unknown[];
			const candidates: Dict[] = [];
			for (const [uid, instance] of pairs(items.Inventory as object)) {
				const inst = instance as Dict;
				const definition = itemById[inst.DefinitionId as string] as Dict | undefined;
				if (definition !== undefined) {
					candidates.push({
						Uid: uid,
						Instance: inst,
						Definition: definition,
						Power: ItemLoadoutMath.CandidatePower(definition, inst.Level),
					});
				}
			}
			const [nextEquipped, equippedCount, changed] = ItemLoadoutMath.PlanEquipBest(
				targets,
				candidates,
				GameConfig.Items.Rarities,
				items.Equipped,
			) as LuaTuple<[unknown, number, unknown]>;
			items.Equipped = nextEquipped;
			const [rigCount, rigNote] = grantLitRigs(profile);
			const equippedLine =
				targets.size() === 0
					? "Unlock a machine or research socket first."
					: equippedCount === 0
						? "No compatible relics are available yet."
						: string.format("Best loadout equipped across %d socket%s.", equippedCount, equippedCount === 1 ? "" : "s");
			return responseSuccess(rigCount > 0 ? equippedLine + " " + rigNote + "." : equippedLine, {
				Equipped: equippedCount,
				Changed: changed,
			});
		});
	}

	_setItemAutoSalvage(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (
			!typeIs(rawPayload, "table") ||
			!typeIs(payload!.Enabled, "boolean") ||
			!typeIs(payload!.KeepNew, "boolean") ||
			!typeIs(payload!.Rarities, "table")
		) {
			return responseError("Invalid auto-salvage request.");
		}
		return this._mutate(player, (profile: Profile) => {
			const ownedPasses = profile.OwnedPasses as Dict | undefined;
			if (ownedPasses === undefined || ownedPasses.AutoSalvage !== true) {
				return { ok: false, error: "Relic Recycler is required for auto-salvage.", RequiresPass: "AutoSalvage" };
			}
			const rarities: Dict = {};
			for (const [rarity] of pairs(GameConfig.Items.Rarities as Dict)) {
				rarities[rarity] = false;
			}
			let count = 0;
			for (const [, rarity] of pairs(payload!.Rarities as object)) {
				if (!typeIs(rarity, "string") || (GameConfig.Items.Rarities as Dict)[rarity] === undefined) {
					return responseError("An auto-salvage rarity is invalid.");
				}
				if (rarities[rarity] !== true) {
					count += 1;
					if (count > 6) {
						return responseError("Too many auto-salvage rarities.");
					}
					rarities[rarity] = true;
				}
			}
			const rules = ensureAutoSalvage(profile) as Dict;
			rules.Enabled = payload!.Enabled;
			rules.KeepNew = payload!.KeepNew;
			rules.Rarities = rarities;
			return responseSuccess(payload!.Enabled === true ? "Relic Recycler armed." : "Relic Recycler paused.");
		});
	}

	// the Domain Lattice: Op "Etch" spends points on the link between anchors A and B,
	// Op "Clear" refunds every link (once per domain rank)
	_domainLattice(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const op = typeIs(rawPayload, "table") ? payload!.Op : undefined;
		if (op !== "Etch" && op !== "Clear") {
			return responseError("Unknown lattice action.");
		}
		return this._mutate(player, (profile: Profile) => {
			const domain = ProfileBagMath.EnsureDomain(profile) as Dict;
			if ((domain.Rank as number) < 1) {
				return responseError("Expand your domain first.");
			}
			domain.Links = DomainLattice.sanitize(domain.Links);
			const links = domain.Links as Dict;
			const etched = DomainLattice.count(links) as number;
			if (op === "Clear") {
				if (etched === 0) {
					return responseError("Nothing is etched yet.");
				}
				if ((tonumber(domain.LatticeClearedAtRank) ?? 0) >= (domain.Rank as number)) {
					return responseError("You can clear the lattice again after your next expansion.");
				}
				domain.SkillPoints = (domain.SkillPoints as number) + (DomainLattice.spent(etched) as number);
				domain.Links = {};
				domain.LatticeClearedAtRank = domain.Rank;
				return responseSuccess("Lattice cleared. Every point is back.", {
					Links: domain.Links,
					SkillPoints: domain.SkillPoints,
				});
			}
			const a = tonumber(payload!.A);
			const b = tonumber(payload!.B);
			const [ok, reason] = DomainLattice.canEtch(links, a, b, domain.SkillPoints) as LuaTuple<
				[unknown, unknown]
			>;
			if (!truthy(ok)) {
				return responseError(truthy(reason) ? reason : "That link can't be etched.");
			}
			const cost = DomainLattice.linkCost(etched) as number;
			const key = DomainLattice.key(math.floor(a as number), math.floor(b as number)) as string;
			const facetsBefore = (DomainLattice.facets(links) as unknown[]).size();
			domain.SkillPoints = (domain.SkillPoints as number) - cost;
			links[key] = true;
			const facetsAfter = (DomainLattice.facets(links) as unknown[]).size();
			return responseSuccess(facetsAfter > facetsBefore ? "Facet closed." : "Link etched.", {
				Link: key,
				Links: links,
				SkillPoints: domain.SkillPoints,
				Facets: facetsAfter,
				ClosedFacet: facetsAfter > facetsBefore,
			});
		});
	}

	_domainExpansion(player: Player) {
		let details: Dict | undefined;
		const result = this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.Domain, "table")) {
				profile.Domain = {
					Rank: 0,
					Essence: 0,
					LastExpandedAt: 0,
					TotalRebirthsSpent: 0,
					TotalCoresSpent: 0,
				};
			}
			const domain = profile.Domain as Dict;
			const expansion = ((GameConfig.Domain as Dict).Expansion as Dict | undefined) ?? ({} as Dict);
			const cooldown = math.max(1, math.floor(tonumber(expansion.CooldownSeconds) ?? 6));
			const rank = math.max(0, math.floor(tonumber(domain.Rank) ?? 0));
			if (os.time() - math.max(0, math.floor(tonumber(domain.LastExpandedAt) ?? 0)) < cooldown) {
				return responseError("Reality is still settling.");
			}
			const [requiredRebirths, requiredCores] = Economy.DomainRequirements(rank) as LuaTuple<[number, number]>;
			if (!truthy(RebirthGate.MeetsRequired(profile.Rebirths, requiredRebirths))) {
				return responseError(string.format("Domain rank %d requires %d rebirths.", rank + 1, requiredRebirths));
			}
			if ((profile.Cores as number) < requiredCores) {
				return responseError(
					string.format("Domain rank %d requires %d astral cores.", rank + 1, requiredCores),
				);
			}

			const [baseEssence, baseStardust] = Economy.DomainRewards(rank) as LuaTuple<[number, number]>;
			let essenceReward = baseEssence;
			const spentRebirths = profile.Rebirths as number;
			const spentCores = profile.Cores as number;
			const overflowRebirths = math.max(0, spentRebirths - requiredRebirths);
			const overflowCores = math.max(0, spentCores - requiredCores);
			const overflowRebirthScale = tonumber(expansion.OverflowRebirthScale) ?? 18;
			const overflowCoreScale = tonumber(expansion.OverflowCoreSqrtScale) ?? 6;
			const overflowReward = math.floor(
				overflowRebirths * overflowRebirthScale + math.sqrt(overflowCores) * overflowCoreScale,
			);
			const nextRank = rank + 1;
			domain.Rank = nextRank;
			if (!typeIs(domain.Links, "table")) {
				domain.Links = {};
			}
			domain.SkillPoints =
				math.max(0, math.floor(tonumber(domain.SkillPoints) ?? 0)) +
				(((GameConfig.Domain as Dict).SkillPointPerRank as number | undefined) ?? 2);
			essenceReward += Economy.DomainTreeBonus(profile, "EssenceGain") as number;
			essenceReward = math.floor(
				math.min(1e300, essenceReward * math.max(1, Economy.AsNumber(Economy.AscensionEffect(profile, "Essence") as number) as number)),
			);
			domain.Essence = math.max(0, math.floor(tonumber(domain.Essence) ?? 0)) + essenceReward;
			domain.LastExpandedAt = os.time();
			domain.TotalRebirthsSpent = math.max(0, math.floor(tonumber(domain.TotalRebirthsSpent) ?? 0)) + spentRebirths;
			domain.TotalCoresSpent = math.max(0, math.floor(tonumber(domain.TotalCoresSpent) ?? 0)) + spentCores;

			ForgeEchoService.Record(profile, "Explore", 14);

			profile.Cash = GameConfig.Economy.StartingCash;
			profile.Vault = 0;
			profile.Cores = 0;
			profile.Rebirths = 0;
			profile.RunCash = 0;
			profile.Zone = 1;
			profile.CurrentZone = 1;
			profile.Machines = { StellarCore: 1 };
			const autoForge = profile.AutoForge as Dict | undefined;
			if (autoForge !== undefined) {
				autoForge.Enabled = false;
				autoForge.MachineId = "StellarCore";
			}
			const items = profile.Items as Dict | undefined;
			if (items !== undefined && typeIs(items.Equipped, "table")) {
				const equipped = items.Equipped as Dict;
				for (const [target] of pairs(equipped)) {
					const [slot] = tostring(target).match("^(%a+):");
					if (slot === "Machine") {
						equipped[target as string] = undefined;
					}
				}
			}
			const lab = profile.Lab as Dict | undefined;
			if (lab !== undefined) {
				lab.Routing = {
					Production: ((GameConfig.Lab as unknown as Dict).Power as Dict).BaseCells,
					Storage: 0,
					Tap: 0,
				};
			}

			const stardustReward = baseStardust + overflowReward;
			profile.Stardust = math.clamp((tonumber(profile.Stardust) ?? 0) + stardustReward, 0, 1e14);
			const freeSpins = math.max(0, math.floor(tonumber(expansion.FreeSpins) ?? 3));
			const wheel = profile.Wheel as Dict;
			wheel.FreeSpins = ((wheel.FreeSpins as number | undefined) ?? 0) + freeSpins;
			const bonusBoostId = (expansion.BonusBoostId as string | undefined) ?? (GameConfig.Domain as Dict).SurgeBoostId;
			const bonusBoostCount = math.max(1, math.floor(tonumber(expansion.BonusBoostCount) ?? 1));
			const boostInventory = profile.BoostInventory as Dict;
			if (truthy(GameConfig.Boosts[bonusBoostId as string])) {
				boostInventory[bonusBoostId as string] =
					((boostInventory[bonusBoostId as string] as number | undefined) ?? 0) + bonusBoostCount;
			}
			boostInventory.Hyperdrive = ((boostInventory.Hyperdrive as number | undefined) ?? 0) + 2;
			boostInventory.Overdrive = ((boostInventory.Overdrive as number | undefined) ?? 0) + 3;
			boostInventory.VaultSurge = ((boostInventory.VaultSurge as number | undefined) ?? 0) + 2;
			const surge = GameConfig.Boosts[(GameConfig.Domain as Dict).SurgeBoostId as string] as Dict;
			profile.ActiveBoost = { Id: surge.Id, EndsAt: os.time() + (surge.Duration as number) };

			details = {
				DomainRank: nextRank,
				DomainEssence: essenceReward,
				StardustReward: stardustReward,
				OverflowReward: overflowReward,
				ConsumedRebirths: spentRebirths,
				ConsumedCores: spentCores,
				BoostEndsAt: (profile.ActiveBoost as Dict).EndsAt,
				FreeSpins: freeSpins,
				BonusBoost: bonusBoostId,
			};
			const [nextRequiredRebirths, nextRequiredCores] = Economy.DomainRequirements(nextRank) as LuaTuple<
				[number, number]
			>;
			details.NextRequiredRebirths = nextRequiredRebirths;
			details.NextRequiredCores = nextRequiredCores;
			return responseSuccess(
				string.format("Domain %d established. Reality now yields more power.", nextRank),
				details,
			);
		});
		if (truthy(result.ok)) {
			const profile = this._data.Get(player) as Profile | undefined;
			this._world.RefreshPlot(player, profile);
			this._effect.broadcast({
				Type: "DomainExpansion",
				UserId: player.UserId,
				Rank: details !== undefined ? details.DomainRank : 0,
				Position: this._world.GetPlotPosition(player),
			});
		}
		return result;
	}

	// Ascension: the infinite final reset. Resets the Domain, rebirths, cores and the run; pays Aether.
	_ascend(player: Player) {
		let details: Dict | undefined;
		const result = this._mutate(player, (profile: Profile) => {
			const state = AscensionMath.sanitize(profile.Ascension, OmegaMath) as Dict;
			const domain = profile.Domain as Dict | undefined;
			const domainRank = math.max(
				0,
				math.floor(tonumber(domain !== undefined ? domain.Rank : undefined) ?? 0),
			);
			const now = os.time();
			if (now - (state.LastAscendedAt as number) < 10) {
				return responseError("The forge is still settling from your last ascension.");
			}
			const [nextState, gainOrReason] = AscensionMath.ascend(
				state,
				domainRank,
				now,
				OmegaMath,
				tonumber(profile.Rebirths) ?? 0,
			) as LuaTuple<[Dict | undefined, unknown]>;
			if (nextState === undefined) {
				return responseError(gainOrReason);
			}
			profile.Ascension = nextState;
			profile.Domain = {
				Rank: 0,
				Essence: 0,
				LastExpandedAt: 0,
				TotalRebirthsSpent: math.max(0, math.floor(tonumber(domain?.TotalRebirthsSpent) ?? 0)),
				TotalCoresSpent: math.max(0, math.floor(tonumber(domain?.TotalCoresSpent) ?? 0)),
				SkillPoints: 0,
				Links: {},
				LatticeClearedAtRank: 0,
			};
			profile.Cash = GameConfig.Economy.StartingCash;
			profile.Vault = 0;
			profile.Cores = 0;
			profile.Rebirths = 0;
			profile.RunCash = 0;
			profile.Zone = 1;
			profile.CurrentZone = 1;
			profile.Machines = { StellarCore: 1 };
			const autoForge = profile.AutoForge as Dict | undefined;
			if (autoForge !== undefined) {
				autoForge.Enabled = false;
				autoForge.MachineId = "StellarCore";
			}
			const items = profile.Items as Dict | undefined;
			if (items !== undefined && typeIs(items.Equipped, "table")) {
				const equipped = items.Equipped as Dict;
				for (const [target] of pairs(equipped)) {
					const [slot] = tostring(target).match("^(%a+):");
					if (slot === "Machine") {
						equipped[target as string] = undefined;
					}
				}
			}
			const lab = profile.Lab as Dict | undefined;
			if (lab !== undefined) {
				lab.Routing = {
					Production: ((GameConfig.Lab as unknown as Dict).Power as Dict).BaseCells,
					Storage: 0,
					Tap: 0,
				};
			}
			details = { Rank: nextState.Rank, Aether: gainOrReason, DomainRank: domainRank };
			return responseSuccess(
				string.format("Ascension %d. +%s Aether.", nextState.Rank as number, (Format.Number as Fn)(gainOrReason) as string),
				details,
			);
		});
		if (truthy(result.ok)) {
			this._world.RefreshPlot(player, this._data.Get(player));
			this._effect.broadcast({
				Type: "Ascension",
				UserId: player.UserId,
				Rank: details !== undefined ? details.Rank : 0,
				Position: this._world.GetPlotPosition(player),
			});
		}
		return result;
	}

	_upgradeSigil(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const id = typeIs(rawPayload, "table") ? payload!.Id : undefined;
		return this._mutate(player, (profile: Profile) => {
			const state = AscensionMath.sanitize(profile.Ascension, OmegaMath) as Dict;
			const [nextState, costOrReason] = AscensionMath.buy(state, id, OmegaMath) as LuaTuple<
				[Dict | undefined, unknown]
			>;
			if (nextState === undefined) {
				return responseError(costOrReason);
			}
			profile.Ascension = nextState;
			const sigil = AscensionMath.sigil(id) as Dict | undefined;
			return responseSuccess(
				string.format(
					"%s is now level %d.",
					sigil !== undefined ? (sigil.Name as string) : tostring(id),
					(nextState.Sigils as Dict)[id as string] as number,
				),
				{ Id: id, Level: (nextState.Sigils as Dict)[id as string] },
			);
		});
	}

	// What the Ascension page shows.
	_ascensionPublic(profile: Profile): Dict {
		const state = AscensionMath.sanitize(profile.Ascension, OmegaMath) as Dict;
		const domain = profile.Domain as Dict | undefined;
		const domainRank = math.max(0, math.floor(tonumber(domain !== undefined ? domain.Rank : undefined) ?? 0));
		const gain = AscensionMath.aetherGain(state, domainRank, OmegaMath);
		const sigils: Dict[] = [];
		for (const [order, sigil] of pairs(AscensionMath.SIGILS as unknown as Dict[])) {
			const sigilDef = sigil as Dict;
			const level = ((state.Sigils as Dict)[sigilDef.Id as string] as number | undefined) ?? 0;
			const cost = AscensionMath.sigilCost(sigilDef.Id, level, OmegaMath);
			sigils.push({
				Id: sigilDef.Id,
				Name: sigilDef.Name,
				Line: sigilDef.Line,
				Effect: sigilDef.Effect,
				Order: order,
				Level: level,
				EffectiveLevel: AscensionMath.effectiveLevel(state, sigilDef.Id),
				Multiplier: OmegaMath.Persist(AscensionMath.sigilMultiplier(state, sigilDef.Id, OmegaMath)),
				Cost: OmegaMath.Persist(cost),
				Affordable: OmegaMath.Gte(state.Aether, cost),
			});
		}
		return {
			Rank: state.Rank,
			Aether: OmegaMath.Persist(state.Aether),
			TotalAether: OmegaMath.Persist(state.TotalAether),
			DomainRank: domainRank,
			RequiredDomainRank: AscensionMath.requiredDomainRank(state.Rank),
			CanAscend: gain !== undefined,
			Gain: gain !== undefined ? OmegaMath.Persist(gain) : 0,
			Harmony: AscensionMath.harmony(state),
			Production: OmegaMath.Persist(AscensionMath.effect(state, "Production", OmegaMath)),
			NextRankProduction: OmegaMath.Persist(
				OmegaMath.Pow((state.Rank as number) + 2, AscensionMath.RANK_EXPONENT),
			),
			Sigils: sigils,
		};
	}

	_verifyCreatorFollow(player: Player) {
		// Roblox exposes no trusted follow check here; only the explicit Studio QA bypass may award it.
		if (!RunService.IsStudio() || ServerConfig.AllowStudioFollowVerification !== true) {
			ModuleLog.Every(
				string.format("creator-follow-unverified:%d", player.UserId),
				30,
				"Security",
				string.format("u=%d Creator follow claim denied because verification is unavailable", player.UserId),
			);
			return responseError("Creator follow verification is unavailable.");
		}
		const profile = this._data.Get(player) as Profile | undefined;
		if (profile === undefined) {
			return responseError("Your save is still loading. Try again in a moment.");
		}
		const socialRewards = typeIs(profile.SocialRewards, "table") ? (profile.SocialRewards as Dict) : undefined;
		if (socialRewards !== undefined && socialRewards.CreatorFollowClaimed === true) {
			return responseSuccess("You already claimed this reward.");
		}
		const result = this._mutate(player, (current: Profile) => {
			if (!typeIs(current.SocialRewards, "table")) {
				current.SocialRewards = { CreatorFollowClaimed: false };
			}
			const rewards = current.SocialRewards as Dict;
			if (rewards.CreatorFollowClaimed === true) {
				return responseSuccess("You already claimed this reward.");
			}
			rewards.CreatorFollowClaimed = true;
			const rewardText = ProgressionService.ApplyReward(
				current,
				ServerConfig.FollowReward,
				Economy.Production(current),
			);
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_setMobileLayout(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (!typeIs(rawPayload, "table")) {
			return responseError("Invalid mobile layout.");
		}
		if (payload!.Values !== undefined && !typeIs(payload!.Values, "table")) {
			return responseError("Invalid mobile layout.");
		}
		if (payload!.Pins !== undefined && !NavRoutes.validMobileTabPins(payload!.Pins)) {
			return responseError("Invalid tab pins.");
		}
		const allowed: Record<string, boolean> = {
			MobileQuickX: true,
			MobileQuickY: true,
			MobileDockX: true,
			MobileDockY: true,
			MobileToastX: true,
			MobileToastY: true,
		};
		return this._mutate(player, (profile: Profile) => {
			if (payload!.Pins !== undefined) {
				(profile.Flags as Dict).MobileTabPins = NavRoutes.normalizeMobileTabPins(payload!.Pins);
			}
			for (const [key, value] of pairs((payload!.Values ?? {}) as object)) {
				if (truthy(allowed[key as string]) && typeIs(value, "number")) {
					(profile.Settings as Dict)[key as string] = math.clamp(value, 0, 1);
				}
			}
			if (payload!.Slots !== undefined) {
				const normalized = MobileLayoutSlots.Normalize(payload!.Slots);
				if (normalized === undefined) {
					return responseError("Invalid layout memory.");
				}
				(profile.Flags as Dict).MobileLayoutSlots = normalized;
				return responseSuccess("Layout memory saved.");
			}
			if (payload!.Pins !== undefined && payload!.Values === undefined) {
				return responseSuccess("Tab bar saved.");
			}
			return responseSuccess("Mobile HUD layout saved.");
		});
	}

	_completeTutorial(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			if (truthy(flags.TutorialDone)) {
				return responseSuccess("Tutorial already complete.");
			}
			flags.TutorialDone = true;
			flags.TutorialStep = 15;
			if (truthy(flags.TutorialRewardClaimed)) {
				return responseSuccess("Guide finished.");
			}
			flags.TutorialRewardClaimed = true;
			const reward = GameConfig.Economy.TutorialReward;
			profile.Cash = Economy.Add(profile.Cash, reward);
			profile.RunCash = Economy.Add(profile.RunCash, reward);
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward);
			return responseSuccess("Guide finished. +" + (Format.Number as Fn)(reward) + " Flux");
		});
	}

	_setTutorialStep(player: Player, rawStep: unknown) {
		if (!typeIs(rawStep, "number")) {
			return responseError("Invalid tutorial step.");
		}
		const step = math.clamp(math.floor(rawStep), 1, 15);
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			if (truthy(flags.TutorialDone)) {
				return responseSuccess("Guide progress already complete.");
			}
			flags.TutorialStep = step;
			return responseSuccess("Guide progress saved.");
		});
	}

	_markHintSeen(player: Player, rawId: unknown) {
		if (!SeenHints.isHintId(rawId)) {
			return responseError("Unknown hint.");
		}
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			const seen = SeenHints.normalizeSeenHints(flags.SeenHints);
			if (!seen.includes(rawId)) {
				seen.push(rawId);
			}
			flags.SeenHints = seen;
			return responseSuccess("Hint saved.");
		});
	}

	_replayTutorial(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			flags.TutorialDone = false;
			flags.TutorialStep = 1;
			return responseSuccess("Guide reopened.");
		});
	}

	_dismissRelease(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = (GameConfig.Game as Dict).Version;
			return responseSuccess();
		});
	}

	_openRelease(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = "";
			return responseSuccess();
		});
	}

	_claimLabOrder(player: Player, orderId: unknown) {
		if (!typeIs(orderId, "string")) {
			return responseError("Invalid order request.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			LabService.Ensure(profile, player.UserId);
			const [ok, message, reward] = LabService.ClaimOrder(profile, orderId) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			const rewardText = ProgressionService.ApplyReward(profile, reward, Economy.Production(profile));
			return responseSuccess(tostring(message) + " " + tostring(rewardText));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "LabOrder", OrderId: orderId });
		}
		return result;
	}

	_routeLabPower(player: Player, channelId: unknown, rawDelta: unknown) {
		if (!typeIs(channelId, "string") || !typeIs(rawDelta, "number")) {
			return responseError("Invalid power routing request.");
		}
		const delta = math.floor(rawDelta);
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = LabService.RoutePower(profile, channelId, delta) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_readStoryChapter(player: Player, chapterId: unknown) {
		if (!typeIs(chapterId, "string") || storyById[chapterId] === undefined) {
			return responseError("That story chapter could not be found.");
		}
		return this._mutate(player, (profile: Profile) => {
			const chapter = storyById[chapterId] as Dict;
			if ((ProgressionGate.Progress(profile, chapter.Kind) as number) < (chapter.Target as number)) {
				return responseError("Keep progressing to uncover this chapter.");
			}
			((profile.Story as Dict).Read as Dict)[chapterId] = true;
			return responseSuccess("Chapter added to your archive.");
		});
	}

	_claimStoryChapter(player: Player, chapterId: unknown) {
		if (!typeIs(chapterId, "string") || storyById[chapterId] === undefined) {
			return responseError("That story chapter could not be found.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			const chapter = storyById[chapterId] as Dict;
			if ((ProgressionGate.Progress(profile, chapter.Kind) as number) < (chapter.Target as number)) {
				return responseError("Keep progressing to uncover this chapter.");
			}
			const story = profile.Story as Dict;
			if (!truthy((story.Read as Dict)[chapterId])) {
				return responseError("Read the chapter before collecting its keepsake.");
			}
			if (truthy((story.Claimed as Dict)[chapterId])) {
				return responseError("That keepsake is already in your collection.");
			}
			(story.Claimed as Dict)[chapterId] = true;
			const reward = ProgressionService.ApplyReward(profile, chapter.Reward, Economy.Production(profile));
			return responseSuccess("Story keepsake: " + tostring(reward));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "StoryClaimed", Id: chapterId });
		}
		return result;
	}

	_readMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError("That letter could not be found.");
		}
		return this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy((mailbox.Deleted as Dict)[messageId]) || !truthy(ProgressionGate.Meets(profile, message.Requirement))) {
				return responseError("That letter is not available yet.");
			}
			(mailbox.Read as Dict)[messageId] = true;
			return responseSuccess();
		});
	}

	_claimMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError("That letter could not be found.");
		}
		const result = this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy((mailbox.Deleted as Dict)[messageId]) || !truthy(ProgressionGate.Meets(profile, message.Requirement))) {
				return responseError("That letter is not available yet.");
			}
			if (truthy((mailbox.Claimed as Dict)[messageId])) {
				return responseError("You already collected this attachment.");
			}
			(mailbox.Read as Dict)[messageId] = true;
			(mailbox.Claimed as Dict)[messageId] = true;
			const reward = ProgressionService.ApplyReward(profile, message.Attachment, Economy.Production(profile));
			return responseSuccess("Mail attachment: " + tostring(reward));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "MailClaimed", Id: messageId });
		}
		return result;
	}

	_claimAllMail(player: Player) {
		let claimedCount = 0;
		const result = this._mutate(player, (profile: Profile) => {
			const mailbox = profile.Mailbox as Dict;
			for (const message of GameConfig.Mail) {
				const messageId = message.Id as string;
				if (
					truthy(message.Attachment) &&
					!truthy((mailbox.Deleted as Dict)[messageId]) &&
					!truthy((mailbox.Claimed as Dict)[messageId]) &&
					truthy(ProgressionGate.Meets(profile, message.Requirement))
				) {
					(mailbox.Read as Dict)[messageId] = true;
					(mailbox.Claimed as Dict)[messageId] = true;
					ProgressionService.ApplyReward(profile, message.Attachment, Economy.Production(profile));
					claimedCount += 1;
				}
			}
			if (claimedCount === 0) {
				return responseError("There are no attachments ready to collect.");
			}
			return responseSuccess(
				string.format("Collected %d mail attachment%s.", claimedCount, claimedCount === 1 ? "" : "s"),
			);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "MailClaimed", Id: "*", Count: claimedCount });
		}
		return result;
	}

	_deleteMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError("That letter could not be found.");
		}
		return this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy(message.Attachment) && !truthy((mailbox.Claimed as Dict)[messageId])) {
				return responseError("Collect the attachment before archiving this letter.");
			}
			(mailbox.Read as Dict)[messageId] = true;
			(mailbox.Deleted as Dict)[messageId] = true;
			return responseSuccess("Letter archived.");
		});
	}

	_toastGuild(guildId: unknown, title: unknown, body: unknown, tone?: unknown, skip?: Player) {
		if (!typeIs(guildId, "string") || guildId === "") {
			return;
		}
		for (const online of Players.GetPlayers()) {
			if (online !== skip) {
				const profile = this._data.Get(online) as Profile | undefined;
				const guild = profile !== undefined ? (profile.Guild as Dict | undefined) : undefined;
				if (profile !== undefined && guild !== undefined && guild.Id === guildId) {
					this._toastPlayer(online, title, body, tone);
				}
			}
		}
	}

	_announceGuildActivity(guildId: string, previousActivity: unknown, guild: unknown) {
		if (!typeIs(guild, "table")) {
			return;
		}
		const guildBag = guild as Dict;
		const current = math.max(0, math.floor(tonumber(guildBag.Activity) ?? 0));
		const previous = math.max(0, math.floor(tonumber(previousActivity) ?? 0));
		if (current <= previous) {
			return;
		}
		const reached = math.floor(current / GUILD_ACTIVITY_MILESTONE_STEP);
		const before = math.floor(previous / GUILD_ACTIVITY_MILESTONE_STEP);
		if (reached <= before) {
			return;
		}
		const milestone = reached * GUILD_ACTIVITY_MILESTONE_STEP;
		this._toastGuild(
			guildId,
			"Guild milestone",
			string.format("%s passed %s activity.", (guildBag.Name as string | undefined) ?? "Your guild", (Format.Number as Fn)(milestone) as string),
			"Special",
		);
	}

	_guildAction(player: Player, action: string, rawPayload: unknown) {
		let payload = (typeIs(rawPayload, "table") ? rawPayload : {}) as Dict;
		if (
			action === Protocol.Actions.SendGuildChat ||
			action === Protocol.Actions.GetGuildChatHistory ||
			action === Protocol.Actions.GetGuildAnnouncements ||
			action === Protocol.Actions.GetGuildSettings ||
			action === Protocol.Actions.GetGuildLogoReview ||
			action === Protocol.Actions.SetGuildSettings ||
			action === Protocol.Actions.CreateGuildAnnouncement ||
			action === Protocol.Actions.EditGuildAnnouncement ||
			action === Protocol.Actions.PinGuildAnnouncement ||
			action === Protocol.Actions.ArchiveGuildAnnouncement ||
			action === Protocol.Actions.SetGuildAnnouncementExpiry ||
			action === Protocol.Actions.MuteGuildMember ||
			action === Protocol.Actions.UnmuteGuildMember ||
			action === Protocol.Actions.BanGuildMember ||
			action === Protocol.Actions.UnbanGuildMember ||
			action === Protocol.Actions.UploadGuildLogo ||
			action === Protocol.Actions.ModerateGuildLogo
		) {
			return this._guildCommunity.Handle(player, action, payload);
		}

		if (
			action === Protocol.Actions.KickGuildMember ||
			action === Protocol.Actions.SetGuildRole ||
			action === Protocol.Actions.BuyGuildUpgrade
		) {
			const profile = this._data.Get(player) as Profile | undefined;
			if (profile === undefined) {
				return responseError("Your profile is not ready. Please try again.");
			}
			let ok: unknown;
			let message: unknown;
			let guild: unknown;
			let previousActivity = 0;
			if (action === Protocol.Actions.BuyGuildUpgrade) {
				const before = this._guilds.GetCachedPublic(
					typeIs(profile.Guild, "table") ? (profile.Guild as Dict).Id : "",
				) as Dict | undefined;
				previousActivity = before !== undefined ? (tonumber(before.Activity) ?? 0) : 0;
			}
			if (action === Protocol.Actions.KickGuildMember) {
				const [kicked, kickMessage, kickGuild] = this._guilds.Kick(
					player,
					profile,
					payload.UserId ?? payload.Id,
				) as LuaTuple<[unknown, unknown, unknown]>;
				ok = kicked;
				message = kickMessage;
				guild = kickGuild;
				if (truthy(ok)) {
					const target = Players.GetPlayerByUserId(tonumber(payload.UserId ?? payload.Id) ?? 0);
					if (target !== undefined) {
						this._data.AtomicUpdate(
							target,
							(victimProfile: Profile) => {
								victimProfile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
								victimProfile.GuildBonuses = emptyBonuses();
								return { ok: true };
							},
							true,
							"guild-kick",
						);
						this._pushState(target);
					}
				}
			} else if (action === Protocol.Actions.SetGuildRole) {
				const [setOk, setMessage, setGuild] = this._guilds.SetRole(
					player,
					profile,
					payload.UserId ?? payload.Id,
					payload.Role,
				) as LuaTuple<[unknown, unknown, unknown]>;
				ok = setOk;
				message = setMessage;
				guild = setGuild;
			} else {
				const [buyOk, buyMessage, buyGuild] = this._guilds.BuyUpgrade(player, profile, payload.Id) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = buyOk;
				message = buyMessage;
				guild = buyGuild;
			}
			if (!truthy(ok)) {
				return responseError(message);
			}
			if (action === Protocol.Actions.BuyGuildUpgrade) {
				const expectedGuildId = typeIs(profile.Guild, "table") ? ((profile.Guild as Dict).Id as string) : "";
				const bonuses = this._guilds.GetCachedBonuses(expectedGuildId);
				this._data.AtomicUpdate(
					player,
					(current: Profile) => {
						const currentGuild = current.Guild as Dict | undefined;
						if (currentGuild === undefined || currentGuild.Id !== expectedGuildId) {
							return { ok: false, noop: true };
						}
						current.GuildBonuses = copyDictionary(bonuses);
						return { ok: true };
					},
					true,
					"guild-bonus",
				);
				const definition = (GameConfig.Guild as Dict).Upgrades as Dict;
				const upgradeDef = definition[payload.Id as string] as Dict | undefined;
				const upgradeName = upgradeDef !== undefined ? (upgradeDef.Name as string) : "a hall upgrade";
				const guildBag = guild as Dict | undefined;
				const level =
					guildBag !== undefined && typeIs(guildBag.Upgrades, "table")
						? tonumber((guildBag.Upgrades as Dict)[payload.Id as string])
						: undefined;
				this._toastGuild(
					expectedGuildId,
					"Guild upgrade",
					level !== undefined
						? string.format("Your guild unlocked %s (level %d)!", upgradeName, level)
						: string.format("Guild unlocked %s.", upgradeName),
					"Special",
				);
				this._announceGuildActivity(expectedGuildId, previousActivity, guild);
			}
			return responseSuccess(message, { Guild: guild });
		}
		if (action === Protocol.Actions.CreateGuild || action === Protocol.Actions.RenameGuild) {
			const rawName = typeIs(payload.Name, "string") ? payload.Name : "";
			const [filteredOk, filtered] = (this._security.Filter as Svc).Apply(
				player,
				rawName,
				player.UserId,
				28,
			) as LuaTuple<[unknown, unknown]>;
			if (!truthy(filteredOk) || !typeIs(filtered, "string") || filtered.size() < 3) {
				return responseError("That guild name couldn't be checked. Please try different wording.");
			}
			payload = table.clone(payload) as Dict;
			payload.Name = filtered;
		}
		let contributeActivity = 0;
		let contributeGuildId = "";
		if (action === Protocol.Actions.ContributeGuild) {
			const existing = this._data.Get(player) as Profile | undefined;
			contributeGuildId =
				existing !== undefined && typeIs(existing.Guild, "table") ? ((existing.Guild as Dict).Id as string) : "";
			const before = this._guilds.GetCachedPublic(contributeGuildId) as Dict | undefined;
			contributeActivity = before !== undefined ? (tonumber(before.Activity) ?? 0) : 0;
		}
		let renameGuildId = "";
		if (action === Protocol.Actions.RenameGuild) {
			const existing = this._data.Get(player) as Profile | undefined;
			renameGuildId =
				existing !== undefined && typeIs(existing.Guild, "table") ? ((existing.Guild as Dict).Id as string) : "";
		}
		if (action === Protocol.Actions.JoinGuild) {
			const [canJoin, joinError] = this._guildCommunity.CanJoinByTag(payload.Tag, player.UserId) as LuaTuple<
				[unknown, unknown]
			>;
			if (!truthy(canJoin)) {
				return responseError(truthy(joinError) ? joinError : "You cannot join that guild.");
			}
		}
		const result = this._mutate(player, (profile: Profile) => {
			let ok: unknown;
			let message: unknown;
			let guild: unknown;
			if (action === Protocol.Actions.CreateGuild) {
				const [a, b, c] = this._guilds.Create(player, profile, payload.Name, payload.Tag) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.JoinGuild) {
				const [a, b, c] = this._guilds.JoinByTag(player, profile, payload.Tag) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.LeaveGuild) {
				const [a, b, c] = this._guilds.Leave(player, profile) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.DisbandGuild) {
				const [a, b, c] = this._guilds.Disband(player, profile) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.RenameGuild) {
				const [a, b, c] = this._guilds.Rename(player, profile, payload.Name, payload.Tag) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.ContributeGuild) {
				const balanceField = payload.Currency === "Cash" ? "Cash" : "Stardust";
				let amount = payload.Amount as number;
				if (typeIs(payload.Fraction, "number")) {
					amount = math.max(1, math.floor((tonumber(profile[balanceField]) ?? 0) * payload.Fraction));
				}
				const [a, b, c] = this._guilds.ContributeBank(
					player,
					profile,
					math.floor(amount),
					payload.Currency,
				) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === Protocol.Actions.ClaimGuildGoal) {
				const [a, b, c, reward] = this._guilds.ClaimGoal(player, profile) as LuaTuple<
					[unknown, unknown, unknown, unknown]
				>;
				ok = a;
				message = b;
				guild = c;
				if (truthy(ok) && truthy(reward)) {
					const rewardText = ProgressionService.ApplyReward(profile, reward, Economy.Production(profile));
					if (tostring(rewardText) !== "") {
						message = "Guild goal done. " + tostring(rewardText);
					}
				}
			}
			if (truthy(ok)) {
				profile.GuildBonuses = this._guilds.GetCachedBonuses((profile.Guild as Dict).Id);
				return responseSuccess(message, { Guild: guild });
			}
			return responseError(message);
		});
		if (truthy(result.ok) && action === Protocol.Actions.ContributeGuild && contributeGuildId !== "") {
			this._announceGuildActivity(contributeGuildId, contributeActivity, result.Guild);
		}
		if (truthy(result.ok) && action === Protocol.Actions.RenameGuild && renameGuildId !== "" && truthy(result.Guild)) {
			const guild = result.Guild as Dict;
			const auditLog = guild.AuditLog as Dict[] | undefined;
			const first = auditLog !== undefined && typeIs(auditLog[0], "table") ? auditLog[0] : undefined;
			const oldTag = first !== undefined ? first.FromTag : undefined;
			const newTag = first !== undefined ? first.ToTag : undefined;
			const tagText =
				oldTag !== undefined && newTag !== undefined && oldTag !== newTag
					? string.format(" Tag changed from %s to %s.", tostring(oldTag), tostring(newTag))
					: "";
			this._toastGuild(
				renameGuildId,
				"Guild renamed",
				string.format("%s renamed the guild to %s.%s", player.DisplayName, (guild.Name as string | undefined) ?? "", tagText),
				"Special",
				player,
			);
			for (const online of Players.GetPlayers()) {
				if (online !== player) {
					const onlineProfile = this._data.Get(online) as Profile | undefined;
					const onlineGuild =
						onlineProfile !== undefined ? (onlineProfile.Guild as Dict | undefined) : undefined;
					if (onlineProfile !== undefined && onlineGuild !== undefined && onlineGuild.Id === renameGuildId) {
						this._pushState(online);
					}
				}
			}
		}
		return result;
	}

	_resolvePlayerName(userId: number): string {
		const now = os.clock();
		if (now >= this._nameCachePruneAt) {
			this._nameCachePruneAt = now + 300;
			for (const [cachedUserId, entry] of this._playerNameCache) {
				if (!typeIs(entry, "table") || tonumber(entry.ExpiresAt) === undefined || (entry.ExpiresAt as number) <= now) {
					this._playerNameCache.delete(cachedUserId);
				}
			}
		}
		const online = Players.GetPlayerByUserId(userId);
		if (online !== undefined) {
			const label = online.DisplayName !== "" ? online.DisplayName : online.Name;
			this._playerNameCache.set(userId, { Name: label, ExpiresAt: os.clock() + 300 });
			return label;
		}
		const cached = this._playerNameCache.get(userId);
		if (cached !== undefined && (cached.ExpiresAt as number) > now) {
			return cached.Name as string;
		}

		if (!this._nameLookupPending.get(userId)) {
			this._nameLookupPending.set(userId, true);
			this._spawnWorker(() => {
				const [ok, name] = pcall(() => Players.GetNameFromUserIdAsync(User.fromId(userId)));
				if (ok && typeIs(name, "string") && name !== "") {
					this._playerNameCache.set(userId, { Name: name, ExpiresAt: os.clock() + 900 });
					table.clear(this._globalBoardCache);
				}
				this._nameLookupPending.delete(userId);
			});
		}
		return "Pilot " + tostring(userId);
	}

	_primePlayerNames(rows: unknown) {
		const now = os.clock();
		const missing: number[] = [];
		for (const [, row] of pairs(rows as object)) {
			const userId = tonumber((row as Dict).UserId);
			if (userId !== undefined) {
				const online = Players.GetPlayerByUserId(userId);
				if (online !== undefined) {
					this._playerNameCache.set(userId, { Name: online.Name, ExpiresAt: now + 300 });
				} else {
					const cached = this._playerNameCache.get(userId);
					if (cached === undefined || (cached.ExpiresAt as number) <= now) {
						missing.push(userId);
					}
				}
			}
		}
		if (missing.size() === 0) {
			return;
		}
		const [ok, infos] = pcall(() => game.GetService("UserService").GetUserInfosByUserIdsAsync(missing) as unknown);
		if (!ok || !typeIs(infos, "table")) {
			return;
		}
		for (const [, info] of pairs(infos)) {
			const userId = tonumber((info as Dict).Id);
			const username = (info as Dict).Username;
			if (userId !== undefined && typeIs(username, "string") && username !== "") {
				this._playerNameCache.set(userId, { Name: username, ExpiresAt: os.clock() + 900 });
			}
		}
	}

	_announceRankClimbs(id: string, rows: Dict[]) {
		if (id !== RANK_PING_BOARD) {
			return;
		}
		const rankByUser = new Map<number, number>();
		for (const [index, row] of pairs(rows)) {
			rankByUser.set(row.UserId as number, index as number);
		}
		for (const online of Players.GetPlayers()) {
			const runtime = this._runtime.get(online);
			const rank = rankByUser.get(online.UserId);
			if (runtime !== undefined && rank !== undefined) {
				const previous = math.max(0, math.floor(tonumber(runtime.LeaderboardRank) ?? 0));
				runtime.LeaderboardRank = rank;
				if (truthy(RankBracket.ShouldAnnounce(previous, rank, RANK_PING_BRACKETS, RANK_PING_UNRANKED))) {
					this._toastPlayer(
						online,
						"Leaderboard climb",
						string.format("You're #%d in %s now.", rank, RANK_PING_BOARD_LABEL),
						"Special",
					);
				}
			} else if (runtime !== undefined) {
				runtime.LeaderboardRank = 0;
			}
		}
	}

	_getLeaderboard(id: unknown) {
		if (!typeIs(id, "string")) {
			return responseError("That leaderboard is unavailable.");
		}
		const store = this._leaderboardStores[id] as Dict | undefined;
		if (store === undefined) {
			return responseError("That leaderboard is unavailable.");
		}
		const cached = this._globalBoardCache[id];
		if (cached !== undefined && (cached.ExpiresAt as number) > os.clock()) {
			return responseSuccess(undefined, { Leaderboard: cached.Entries, LeaderboardId: id });
		}

		const byUser = new Map<number, unknown>();
		const [ok, pages] = pcall(() =>
			(store as { GetSortedAsync(asc: boolean, size: number): { GetCurrentPage(): Dict[] } }).GetSortedAsync(
				false,
				GLOBAL_LB_PAGE,
			),
		);
		if (ok && truthy(pages)) {
			for (const row of pages.GetCurrentPage()) {
				const userId = tonumber(row.key);
				const value = LeaderboardCodec.Decode(row.value);
				if (userId !== undefined) {
					byUser.set(userId, value);
				}
			}
		}

		for (const online of Players.GetPlayers()) {
			const profile = this._data.Get(online) as Profile | undefined;
			if (profile !== undefined) {
				byUser.set(online.UserId, generalBoardValue(profile, id));
			}
		}
		const rows: Dict[] = [];
		for (const [userId, value] of byUser) {
			const counts = id === "Worlds" ? Economy.Gt(value, 1) : Economy.Gt(value, 0);
			if (truthy(counts)) {
				rows.push({ UserId: userId, Value: value });
			}
		}
		table.sort(rows, (a, b) => {
			if (truthy(Economy.Gt(a.Value, b.Value))) {
				return true;
			}
			if (truthy(Economy.Lt(a.Value, b.Value))) {
				return false;
			}
			return (a.UserId as number) < (b.UserId as number);
		});
		this._primePlayerNames(rows);
		const entries: Dict[] = [];
		for (let index = 0; index < math.min(rows.size(), GLOBAL_LB_PAGE); index++) {
			const row = rows[index];
			entries.push({
				UserId: row.UserId,
				Name: this._resolvePlayerName(row.UserId as number),
				Value: row.Value,
				Category: id,
			});
		}
		this._globalBoardCache[id] = { Entries: entries, ExpiresAt: os.clock() + 15 };
		this._announceRankClimbs(id, rows);
		return responseSuccess(undefined, { Leaderboard: entries, LeaderboardId: id });
	}

	_handleAction(player: Player, action: unknown, rawPayload: unknown): Response {
		if (!truthy(CommandActionValidators.IsValidAction(action))) {
			return responseError("Invalid request.");
		}
		const payload = typeIs(rawPayload, "table") ? (rawPayload as Dict) : undefined;
		if (action === Protocol.Actions.ReportClientIntegrity) {
			const accepted = RemoteFirewall.processFirewallViolation(
				player,
				payload !== undefined ? payload.ActionType : undefined,
				payload !== undefined ? payload.PenaltyCode : undefined,
			);
			return truthy(accepted) ? responseSuccess(undefined) : responseError("Integrity report rejected.");
		}
		if (action === Protocol.Actions.ReportPerformance) {
			return truthy(this._analytics.RecordPerformance(player, payload))
				? responseSuccess(undefined)
				: responseError("Performance sample was already received.");
		}
		const featureId = featureByAction[action as string];
		if (truthy(featureId)) {
			const profile = this._data.Get(player) as Profile | undefined;
			const domainOpen =
				featureId === "Domain" &&
				profile !== undefined &&
				typeIs(profile.Domain, "table") &&
				(tonumber((profile.Domain as Dict).Rank) ?? 0) >= 1;
			if (profile !== undefined && !domainOpen && !truthy(ProgressionGate.IsFeatureUnlocked(profile, featureId))) {
				const rule = (GameConfig.Unlocks as Dict)[featureId as string] as Dict | undefined;
				const name = rule !== undefined && truthy(rule.Name) ? rule.Name : featureId;
				if (rule !== undefined && typeIs(rule.Requirement, "string") && rule.Requirement !== "") {
					return responseError(string.format("%s is locked. %s to open it.", tostring(name), rule.Requirement));
				}
				return responseError(
					tostring(name) +
						" unlocks when you " +
						string.lower(rule !== undefined && truthy(rule.Requirement) ? tostring(rule.Requirement) : "progress further") +
						".",
				);
			}
		}
		if (action === Protocol.Actions.GetState) {
			const runtime = this._runtime.get(player);
			if (runtime !== undefined) {
				runtime.BazaarRecoveryRetryAt = undefined;
			}
			const snapshot = this._snapshot(player);
			this._forgetSentSections(player);
			return snapshot !== undefined
				? responseSuccess(undefined, { State: snapshot })
				: responseError("Profile is still loading.");
		} else if (action === Protocol.Actions.MeasureLatency) {
			return responseSuccess(undefined);
		} else if (action === Protocol.Actions.SubmitFeedback) {
			return this._submitFeedback(player, payload);
		} else if (action === Protocol.Actions.ReportPlayer) {
			return this._reportPlayer(player, payload);
		} else if (action === Protocol.Actions.GetPlayers) {
			return this._getPlayers(player);
		} else if (action === Protocol.Actions.GetPlayerMirror) {
			return this._getPlayerMirror(player, payload);
		} else if (action === Protocol.Actions.VisitPlot) {
			return this._visitPlot(player, payload);
		} else if (action === Protocol.Actions.LeavePlot) {
			return this._leavePlot(player);
		} else if (action === Protocol.Actions.NudgeCrew) {
			return this._nudgeCrew(player, payload);
		} else if (action === Protocol.Actions.ReportPresence) {
			return this._reportPresence(player, payload);
		} else if (action === Protocol.Actions.GetGuild) {
			const profile = this._data.Get(player) as Profile | undefined;
			return responseSuccess(undefined, {
				Guild:
					profile !== undefined
						? this._guilds.GetPublic(typeIs(profile.Guild, "table") ? (profile.Guild as Dict).Id : "")
						: undefined,
			});
		} else if (action === Protocol.Actions.GetGuildLeaderboard) {
			return responseSuccess(undefined, {
				GuildLeaderboard: this._guilds.GetLeaderboard(payload !== undefined ? (payload.Page ?? 1) : 1),
			});
		} else if (action === Protocol.Actions.GetLeaderboard) {
			return this._getLeaderboard(payload !== undefined ? payload.Id : undefined);
		} else if (action === Protocol.Actions.GetAdminState) {
			return this._admin !== undefined
				? responseSuccess(undefined, { Admin: this._admin.State(player) })
				: responseError("Administration is unavailable.");
		} else if (action === Protocol.Actions.AdminExecute) {
			if (this._admin === undefined) {
				return responseError("Administration is unavailable.");
			}
			const result = this._admin.Execute(player, payload) as Dict;
			if (truthy(result.ok) && typeIs(result.TargetUserId, "number")) {
				const target = Players.GetPlayerByUserId(result.TargetUserId);
				const targetProfile = target !== undefined ? (this._data.Get(target) as Profile | undefined) : undefined;
				if (target !== undefined && targetProfile !== undefined && result.World !== true) {
					this._syncLeaderstats(target, targetProfile);
					if (target !== player) {
						this._pushState(target);
						this._toastPlayer(
							target,
							"Forgemaster grant",
							truthy(result.message) ? result.message : "Your profile was updated.",
							"Special",
						);
					}
				}
			}
			return result;
		} else if (
			action === Protocol.Actions.CreateGuild ||
			action === Protocol.Actions.JoinGuild ||
			action === Protocol.Actions.LeaveGuild ||
			action === Protocol.Actions.DisbandGuild ||
			action === Protocol.Actions.KickGuildMember ||
			action === Protocol.Actions.SetGuildRole ||
			action === Protocol.Actions.RenameGuild ||
			action === Protocol.Actions.ContributeGuild ||
			action === Protocol.Actions.BuyGuildUpgrade ||
			action === Protocol.Actions.ClaimGuildGoal ||
			action === Protocol.Actions.SendGuildChat ||
			action === Protocol.Actions.GetGuildChatHistory ||
			action === Protocol.Actions.GetGuildAnnouncements ||
			action === Protocol.Actions.GetGuildSettings ||
			action === Protocol.Actions.SetGuildSettings ||
			action === Protocol.Actions.GetGuildLogoReview ||
			action === Protocol.Actions.CreateGuildAnnouncement ||
			action === Protocol.Actions.EditGuildAnnouncement ||
			action === Protocol.Actions.PinGuildAnnouncement ||
			action === Protocol.Actions.ArchiveGuildAnnouncement ||
			action === Protocol.Actions.SetGuildAnnouncementExpiry ||
			action === Protocol.Actions.MuteGuildMember ||
			action === Protocol.Actions.UnmuteGuildMember ||
			action === Protocol.Actions.BanGuildMember ||
			action === Protocol.Actions.UnbanGuildMember ||
			action === Protocol.Actions.UploadGuildLogo ||
			action === Protocol.Actions.ModerateGuildLogo
		) {
			return this._guildAction(player, action as string, payload ?? {}) as Response;
		} else if (
			action === Protocol.Actions.GetTrade ||
			action === Protocol.Actions.InviteTrade ||
			action === Protocol.Actions.RespondTrade ||
			action === Protocol.Actions.UpdateTradeOffer ||
			action === Protocol.Actions.SetTradeReady ||
			action === Protocol.Actions.ConfirmTrade ||
			action === Protocol.Actions.CancelTrade ||
			action === Protocol.Actions.TradeViewAway ||
			action === Protocol.Actions.TradeChat ||
			action === Protocol.Actions.TradeRequest
		) {
			const policyNote = PolicyGate.TradeBlocked(player, action as string, payload);
			if (policyNote !== undefined) {
				return responseError(policyNote);
			}
			return this._tradeAction(player, action as string, payload ?? {});
		} else if (action === Protocol.Actions.CollectVault) {
			return this._collect(player);
		} else if (action === Protocol.Actions.Overcharge) {
			return this._overcharge(player);
		} else if (action === Protocol.Actions.BuyMachine) {
			return this._buyMachine(player, payload?.Id, payload?.Amount);
		} else if (action === Protocol.Actions.SetAutoForge) {
			return this._setAutoForge(player, payload);
		} else if (action === Protocol.Actions.BuyResearch) {
			return this._buyResearch(player, payload?.Id, payload?.Amount);
		} else if (action === Protocol.Actions.BuyGridUpgrade) {
			return responseError(
				"Star Grid purchases have retired. Your purchased bonuses remain active; choose a build in Forge Specializations.",
			);
		} else if (action === Protocol.Actions.UpgradeContinuum) {
			return this._upgradeContinuum(player);
		} else if (action === Protocol.Actions.FoundryAct) {
			return this._foundryAct(player, payload);
		} else if (action === Protocol.Actions.EchoAct) {
			return this._echoAct(player, payload);
		} else if (action === Protocol.Actions.UnlockZone) {
			return this._unlockZone(player, payload?.Id);
		} else if (action === Protocol.Actions.SelectZone) {
			return this._selectZone(player, payload?.Id);
		} else if (action === Protocol.Actions.Rebirth) {
			return this._rebirth(player, payload);
		} else if (action === Protocol.Actions.RebirthAct) {
			return this._rebirthAct(player, payload);
		} else if (action === Protocol.Actions.Ascend) {
			return this._ascend(player);
		} else if (action === Protocol.Actions.UpgradeSigil) {
			return this._upgradeSigil(player, payload);
		} else if (action === Protocol.Actions.DomainExpansion) {
			return this._domainExpansion(player);
		} else if (action === Protocol.Actions.DomainLattice) {
			return this._domainLattice(player, payload);
		} else if (action === Protocol.Actions.EventAct) {
			return this._eventAct(player, payload);
		} else if (action === Protocol.Actions.ClaimConvergenceReward) {
			return this._convergence.Claim(player, payload?.Tier) as Response;
		} else if (action === Protocol.Actions.ClaimQuest) {
			return this._claimQuest(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimAchievement) {
			return this._claimAchievement(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimDaily) {
			return this._claimDaily(player);
		} else if (action === Protocol.Actions.ClaimTimedReward) {
			return this._claimTimedReward(player, payload?.Index);
		} else if (action === Protocol.Actions.SpinWheel) {
			return this._spinWheel(player, payload);
		} else if (action === Protocol.Actions.BazaarPlay) {
			return this._bazaarPlay(player, payload);
		} else if (action === Protocol.Actions.SelectSpecialization) {
			return this._mutate(player, (profile: Profile) => {
				const [selected, message] = Specializations.Select(
					profile.Specialization,
					payload?.Id,
					os.time(),
				) as LuaTuple<[Dict | undefined, unknown]>;
				if (selected === undefined) {
					return responseError(message);
				}
				const previous = profile.Specialization;
				if (selected.Focus === (Specializations.Sanitize(previous) as Dict).Focus) {
					return responseSuccess(message);
				}
				profile.Specialization = selected;
				if (truthy(Economy.Gt(profile.Vault, Economy.Capacity(profile)))) {
					profile.Specialization = previous;
					return responseError("Collect your vault before equipping a build with a smaller capacity.");
				}
				return responseSuccess(message);
			});
		} else if (action === Protocol.Actions.SetMarketFavorite) {
			return this._mutate(player, (profile: Profile) => {
				const [ok, message] = BazaarService.SetFavorite(profile, payload) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
		} else if (action === Protocol.Actions.RequestProcurement) {
			return this._mutate(player, (profile: Profile) => {
				const [ok, message] = BazaarService.Procure(profile, payload, os.time()) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
		} else if (action === Protocol.Actions.LaunchExpedition) {
			return this._launchExpedition(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimExpedition) {
			return this._claimExpedition(player);
		} else if (action === Protocol.Actions.EquipArtifact) {
			return this._equipArtifact(player, payload?.Id);
		} else if (action === Protocol.Actions.UpgradeArtifact) {
			return this._upgradeArtifact(player, payload?.Id);
		} else if (action === Protocol.Actions.BuyArtifact) {
			return this._buyArtifact(player, payload?.Id);
		} else if (action === Protocol.Actions.UpgradeCrew) {
			return this._upgradeCrew(player, payload?.Role);
		} else if (action === Protocol.Actions.ClaimCommanderReward) {
			return this._claimCommanderReward(player, payload?.Level);
		} else if (action === Protocol.Actions.ClaimWeeklyDirective) {
			return this._claimWeeklyDirective(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimSeasonTier) {
			return this._claimSeasonTier(player, payload?.Tier);
		} else if (action === Protocol.Actions.ClaimForgePathStep) {
			return this._claimForgePathStep(player, payload?.Step);
		} else if (action === Protocol.Actions.BuySignalOffer) {
			return this._buySignalOffer(player, payload?.Id);
		} else if (action === Protocol.Actions.EquipTitle) {
			return this._equipTitle(player, payload?.Id);
		} else if (action === Protocol.Actions.SetProfileStyle) {
			return this._setProfileStyle(player, payload?.Accent, payload?.Frame);
		} else if (action === Protocol.Actions.RedeemCode) {
			return this._redeemCode(player, payload?.Code);
		} else if (action === Protocol.Actions.VerifyCreatorFollow) {
			return this._verifyCreatorFollow(player);
		} else if (action === Protocol.Actions.SyncShop) {
			return this._syncShop(player);
		} else if (action === Protocol.Actions.StudioGrantProduct) {
			return this._studioGrantProduct(player, payload?.Id);
		} else if (action === Protocol.Actions.ActivateBoost) {
			return this._activateBoost(player, payload?.Id);
		} else if (action === Protocol.Actions.BuyDailyOffer) {
			return this._buyDailyOffer(player, payload?.Slot);
		} else if (action === Protocol.Actions.BuyCrateSkin) {
			return this._buyCrateSkin(player, payload?.Id);
		} else if (action === Protocol.Actions.EquipCrateSkin) {
			return this._equipCrateSkin(player, payload?.Id);
		} else if (action === Protocol.Actions.FuseRelics) {
			return this._fuseRelics(player, payload?.Id);
		} else if (action === Protocol.Actions.BuyItemOffer) {
			return this._buyItemOffer(player, payload?.Id);
		} else if (action === Protocol.Actions.OpenItemCrate) {
			return this._openItemCrate(player, payload?.Id, payload?.Count);
		} else if (action === Protocol.Actions.EquipItem) {
			return this._equipItem(player, payload?.Uid, payload?.Target);
		} else if (action === Protocol.Actions.UnequipItem) {
			return this._unequipItem(player, payload?.Target);
		} else if (action === Protocol.Actions.UpgradeItem) {
			return this._upgradeItem(player, payload?.Uid);
		} else if (action === Protocol.Actions.SalvageItem) {
			return this._salvageItem(player, payload?.Uid);
		} else if (action === Protocol.Actions.BulkSalvageItems) {
			return this._bulkSalvageItems(player, payload?.Uids);
		} else if (action === Protocol.Actions.EquipBestItems) {
			return this._equipBestItems(player);
		} else if (action === Protocol.Actions.ToggleItemLock) {
			return this._toggleItemLock(player, payload?.Uid);
		} else if (action === Protocol.Actions.SetItemAutoSalvage) {
			return this._setItemAutoSalvage(player, payload);
		} else if (action === Protocol.Actions.SetSetting) {
			return this._setSetting(player, payload);
		} else if (action === Protocol.Actions.SetMobileLayout) {
			return this._setMobileLayout(player, payload);
		} else if (action === Protocol.Actions.ChatOpenWhisper) {
			return this._chat.OpenWhisper(player, payload) as Response;
		} else if (action === Protocol.Actions.ChatGlobal) {
			return this._chat.SendGlobal(player, payload) as Response;
		} else if (action === Protocol.Actions.GetCrew) {
			return this._crews.Get(player) as Response;
		} else if (action === Protocol.Actions.CrewInvite) {
			return this._crews.Invite(player, payload) as Response;
		} else if (action === Protocol.Actions.CrewRespond) {
			return this._crews.Respond(player, payload) as Response;
		} else if (action === Protocol.Actions.CrewLeave) {
			return this._crews.Leave(player) as Response;
		} else if (action === Protocol.Actions.CrewKick) {
			return this._crews.Kick(player, payload) as Response;
		} else if (action === Protocol.Actions.CrewRename) {
			return this._crews.Rename(player, payload) as Response;
		} else if (action === Protocol.Actions.CrewClaim) {
			return this._crews.Claim(player, payload) as Response;
		} else if (action === Protocol.Actions.SetTutorialStep) {
			return this._setTutorialStep(player, payload?.Step);
		} else if (action === Protocol.Actions.MarkHintSeen) {
			return this._markHintSeen(player, payload?.Id);
		} else if (action === Protocol.Actions.CompleteTutorial) {
			return this._completeTutorial(player);
		} else if (action === Protocol.Actions.ReplayTutorial) {
			return this._replayTutorial(player);
		} else if (action === Protocol.Actions.DismissRelease) {
			return this._dismissRelease(player);
		} else if (action === Protocol.Actions.OpenRelease) {
			return this._openRelease(player);
		} else if (action === Protocol.Actions.ReadStoryChapter) {
			return this._readStoryChapter(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimStoryChapter) {
			return this._claimStoryChapter(player, payload?.Id);
		} else if (action === Protocol.Actions.ReadMail) {
			return this._readMail(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimMail) {
			return this._claimMail(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimAllMail) {
			return this._claimAllMail(player);
		} else if (action === Protocol.Actions.DeleteMail) {
			return this._deleteMail(player, payload?.Id);
		} else if (action === Protocol.Actions.PulseAnomaly) {
			return this._pulseAnomaly(player);
		} else if (action === Protocol.Actions.StabilizeAnomaly) {
			return this._stabilizeAnomaly(player);
		} else if (action === Protocol.Actions.BuyAnomalyProtocol) {
			return this._buyAnomalyProtocol(player, payload?.Id);
		} else if (action === Protocol.Actions.ActivateAnomalySurge) {
			return this._activateAnomalySurge(player);
		} else if (action === Protocol.Actions.SetAnomalyChannel) {
			return this._setAnomalyChannel(player, payload?.Id);
		} else if (action === Protocol.Actions.SetAnomalyLoadout) {
			return this._setAnomalyLoadout(player, payload?.Loadout);
		} else if (action === Protocol.Actions.ClaimAnomalyMilestone) {
			return this._claimAnomalyMilestone(player, payload?.Tier);
		} else if (action === Protocol.Actions.ClaimAnomalyDirective) {
			return this._claimAnomalyDirective(player, payload?.Id);
		} else if (action === Protocol.Actions.ClaimLabOrder) {
			return this._claimLabOrder(player, payload?.Id);
		} else if (action === Protocol.Actions.RouteLabPower) {
			return this._routeLabPower(player, payload?.Channel, payload?.Delta);
		}
		return responseError("Unknown forge command.");
	}

	_processOffline(player: Player, profile: Profile) {
		const previousLastSeen = this._data.GetPreviousLastSeen(player);
		const now = os.time();
		const [reward, elapsed, averageEfficiency, capped] = Economy.OfflineEarnings(
			profile,
			previousLastSeen,
			now,
		) as LuaTuple<[unknown, number, number, unknown]>;
		const awaySeconds = math.max(elapsed, math.max(0, now - (tonumber(previousLastSeen) ?? now)));
		const capHours = Economy.OfflineHours(profile);
		if (truthy(Economy.Gt(reward, 0))) {
			profile.Cash = Economy.Add(profile.Cash, reward);
			profile.RunCash = Economy.Add(profile.RunCash, reward);
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward);
			const stats = ensureStats(profile) as Dict;
			stats.Collected = Economy.Add(stats.Collected, reward);
			const rewardNumber = Economy.AsNumber(reward);
			ProgressionService.Progress(profile, "EarnCash", rewardNumber);
			LabService.Progress(profile, "BankFlux", rewardNumber);
		}
		return $tuple(reward, elapsed, averageEfficiency, capped, awaySeconds, capHours);
	}

	_onPlayerAdded(player: Player, stealLock?: boolean) {
		if (this._admin !== undefined && truthy(this._admin.EnforceServerBan(player))) {
			return;
		}
		const [loaded, errorMessage] = this._data.Load(player, stealLock) as LuaTuple<[unknown, unknown]>;
		if (!truthy(loaded)) {
			if (errorMessage === "refreshing" || this._refreshing() || player.Parent !== Players) {
				return;
			}
			error(truthy(errorMessage) ? errorMessage : "profile load failed", 0);
		}
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			return;
		}

		const profile = this._data.Get(player) as Profile | undefined;
		if (profile === undefined) {
			this._data.Save(player, true);
			return;
		}
		this._antiCheat.Observe(player, "Load", profile);
		const membershipBeforeReconcile = profile.Guild as Dict | undefined;
		const membershipGuildId = membershipBeforeReconcile !== undefined ? (membershipBeforeReconcile.Id as string) : "";
		this._guilds.ReconcileMembership(profile, player.UserId);
		if (membershipGuildId !== "" && truthy(this._guildCommunity.IsBanned(membershipGuildId, player.UserId))) {
			this._guilds._update(membershipGuildId, (current: Dict) => {
				(current.Members as Dict)[tostring(player.UserId)] = undefined;
				return current;
			});
			profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
			profile.GuildBonuses = emptyBonuses();
		}
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			return;
		}

		applySocialBoost(profile, 0, player.MembershipType === Enum.MembershipType.Premium);
		const [offlineReward, offlineSeconds, offlineEfficiency, offlineCapped, offlineAwaySeconds, offlineCapHours] =
			this._processOffline(player, profile) as LuaTuple<[unknown, number, number, unknown, number, unknown]>;
		this._antiCheat.SyncBaseline(player, profile);
		ProgressionService.EnsureQuests(profile, player.UserId);
		ProgressionService.EnsureTimedRewards(profile);
		ProgressionService.EnsureCommandRotations(profile);
		ensureItemShop(profile);
		AnomalyService.Ensure(profile);
		LabService.Ensure(profile, player.UserId);
		const [rigCount, rigNote] = grantLitRigs(profile);
		bumpStat(profile, "Joins", 1);
		(profile.Meta as Dict).Revision = ((profile.Meta as Dict).Revision as number) + 1;
		this._data.MarkDirty(player);
		const runtime: Runtime = {
			LastTap: 0,
			TapCombo: 0,
			LeaderboardRank: 0,
			ProductionAccumulator: 0,
			AutoForgeAccumulator: 0,
			PushAccumulator: 0,
			DirtyAccumulator: 0,
			MaintenanceAccumulator: 0,
			GuildRefreshAccumulator: 0,
			GuildRefreshBusy: false,
			PendingAnomalyActions: [],
			SnapshotId: 0,
			OfflineReward: offlineReward,
			OfflineSeconds: offlineSeconds,
			OfflineEfficiency: offlineEfficiency,
			OfflineCapped: offlineCapped,
			OfflineAwaySeconds: offlineAwaySeconds,
			OfflineCapHours: offlineCapHours,
		};
		this._runtime.set(player, runtime);
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			this._runtime.delete(player);
			return;
		}
		const [spawned, spawnProblem] = pcall(() => {
			runtime.MatterEntity = this._matter.SpawnPlayer(player, runtime, profile);
		});
		if (!spawned) {
			if (!this._running) {
				this._data.Save(player, true);
				this._runtime.delete(player);
				return;
			}
			error(spawnProblem, 0);
		}
		pcall(() => {
			this._analytics.PlayerJoined(player, profile);
		});
		pcall(() => {
			this._badges.Evaluate(player, profile);
		});

		this._createLeaderstats(player);
		this._syncLeaderstats(player, profile);
		const [plotted, plotProblem] = pcall(() => {
			this._world.CreatePlot(player, profile);
		});
		if (!plotted) {
			if (!this._running) {
				return;
			}
			ModuleLog.Warn(
				"Player",
				string.format("plot setup failed for %s - %s", player.Name, tostring(plotProblem)),
			);
		}

		table.clear(this._globalBoardCache);
		player.SetAttribute("AstralForgeLoaded", true);

		const joinedRuntime = runtime;
		this._spawnWorker(() => {
			this._syncShop(player);
			if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
				this._pushState(player);
			}
		});

		const previousCharacterConnection = this._characterConnections.get(player);
		if (previousCharacterConnection !== undefined) {
			previousCharacterConnection.Disconnect();
		}
		this._characterConnections.set(
			player,
			player.CharacterAdded.Connect((character) => {
				task.defer(() => {
					const animate = character.WaitForChild("Animate", 3);
					const mood = animate !== undefined ? animate.FindFirstChild("mood") : undefined;
					if (mood !== undefined) {
						mood.Destroy();
					}
				});
				this._spawnWorker(() => {
					task.wait(0.15);
					if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
						this._world.TeleportToPlot(player);
					}
				});
			}),
		);
		if (player.Character !== undefined) {
			this._spawnWorker(() => {
				if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
					this._world.TeleportToPlot(player);
				}
			});
		}

		this._pushState(player);
		if (rigCount > 0) {
			this._toastPlayer(player, rigCount === 1 ? "Rig lit" : "Rigs lit", rigNote, "Success");
		}
		const away =
			offlineSeconds >= 3600
				? string.format("%.0fh", offlineSeconds / 3600)
				: offlineSeconds >= 60
					? string.format("%.0fm", offlineSeconds / 60)
					: string.format("%.0fs", offlineSeconds);
		ModuleLog.Player(player, string.format("joined world %d after %s away", profile.CurrentZone as number, away));
	}

	_refreshing(): boolean {
		if (this._running !== true) {
			return true;
		}
		const data = this._data;
		if (data === undefined) {
			return true;
		}
		const [ok, closing] = pcall(() => data.IsClosing());
		return ok && closing === true;
	}

	_safePlayerAdded(player: Player) {
		if (this._refreshing() || this._joining.get(player) !== undefined || this._runtime.get(player) !== undefined) {
			return;
		}
		this._joining.set(player, true);
		let attempts = 0;
		let lockNoticeAt = 0;
		let lockSince: number | undefined;
		let stealNoticeAt = 0;
		while (player.Parent === Players && !this._refreshing()) {
			attempts += 1;
			if (this._runtime.get(player) !== undefined) {
				break;
			}
			const stealLock = lockSince !== undefined && os.clock() - lockSince > 90;
			const [ok, problem] = pcall(() => this._onPlayerAdded(player, stealLock));
			if (this._runtime.get(player) !== undefined) {
				break;
			}
			if (this._refreshing() || player.Parent !== Players) {
				break;
			}
			if (!ok) {
				ModuleLog.Every(
					"join-retry:" + tostring(player.UserId),
					8,
					"Player",
					string.format("%s join retry %d: %s", player.Name, attempts, tostring(problem)),
				);
			}
			const locked =
				typeIs(problem, "string") && string.lower(tostring(problem)).find("another server", 1, true)[0] !== undefined;
			if (locked) {
				if (lockSince === undefined) {
					lockSince = os.clock();
				}
				if (os.clock() - lockNoticeAt > 25) {
					lockNoticeAt = os.clock();
					this._toastPlayer(
						player,
						"Save is still syncing",
						"Your data is still active on another server. Close any other open session, or wait and it clears on its own.",
						"Info",
					);
				}
				if (stealLock && os.clock() - stealNoticeAt > 60) {
					stealNoticeAt = os.clock();
					ModuleLog.Warn(
						"Player",
						string.format("%s save lock held for %.0fs, taking it over", player.Name, os.clock() - lockSince),
						{ UserId: player.UserId },
					);
					this._toastPlayer(
						player,
						"Taking over your session",
						"Your other session is being closed so this one can load your save.",
						"Info",
					);
				}
				task.wait(2.5);
				continue;
			}
			lockSince = undefined;
			if (attempts >= 10) {
				if (attempts === 10) {
					ModuleLog.Error(
						"Player",
						string.format(
							"%s join retries degraded to slow retry after %d attempts — %s",
							player.Name,
							attempts,
							tostring(problem),
						),
						{ UserId: player.UserId },
					);
					this._toastPlayer(
						player,
						"Still connecting",
						"Your save is taking longer than usual to load. We'll keep retrying, so you don't need to rejoin.",
						"Warning",
					);
				}
				task.wait(25);
				continue;
			}
			task.wait(math.min(0.8 + attempts * 0.25, 5));
		}
		this._joining.delete(player);
		if (this._runtime.get(player) !== undefined || player.Parent !== Players) {
			return;
		}
		if (this._data.Get(player) !== undefined) {
			pcall(() => {
				this._data.Save(player, true);
			});
		}
	}

	_onPlayerRemoving(player: Player) {
		ModuleLog.Player(player, "left, saving");
		this._joining.delete(player);
		this._saveFailedToastAt.delete(player);
		const characterConnection = this._characterConnections.get(player);
		if (characterConnection !== undefined) {
			characterConnection.Disconnect();
		}
		this._characterConnections.delete(player);
		const pendingPush = this._queuedStatePushes.get(player);
		if (pendingPush !== undefined) {
			task.cancel(pendingPush);
		}
		this._queuedStatePushes.delete(player);
		this._presence.delete(player.UserId);
		this._clearVisit(player, true);
		const hosted = this._visitors.get(player.UserId);
		if (hosted !== undefined) {
			for (const [visitor] of hosted) {
				this._visiting.delete(visitor);
				if (visitor.Parent === Players) {
					this._toastPlayer(visitor, "Visit ended", "The host left the server.", "Info");
					this._effect.fire(visitor, { Type: "VisitEnded" });
				}
			}
			this._visitors.delete(player.UserId);
		}
		const profile = this._data.Get(player) as Profile | undefined;
		this._convergence.PlayerRemoving(player);
		if (this._trades !== undefined) {
			const notify = this._trades.Drop(player.UserId) as number[];
			for (const userId of notify) {
				const other = Players.GetPlayerByUserId(userId);
				if (other !== undefined) {
					this._toastPlayer(other, "Trade closed", "Your partner left the server.", "Info");
					this._pushState(other, true);
				}
			}
		}
		if (profile !== undefined) {
			this._analytics.PlayerLeft(player, profile);
			this._data.MarkDirty(player);
		}
		this._world.RemovePlot(player);
		const runtime = this._runtime.get(player);
		if (runtime !== undefined && runtime.MatterEntity !== undefined) {
			this._matter.Despawn(runtime.MatterEntity as number);
		}
		this._runtime.delete(player);
		this._firewall.Forget(player);
		this._session.Forget(player);
		this._antiCheat.Forget(player);
		if (this._admin !== undefined) {
			this._admin.Forget(player);
		}
		this._analytics.Forget(player);
		this._badges.Forget(player);
		if (!truthy(this._data.Save(player, true))) {
			this._spawnWorker(() => {
				for (let attempt = 1; attempt <= 3; attempt++) {
					task.wait(attempt * 2);
					if (!this._running || this._data.Get(player) === undefined) {
						return;
					}
					if (truthy(this._data.Save(player, true))) {
						return;
					}
				}
				ModuleLog.Warn("Data", string.format("release retries exhausted for %s", player.Name));
			});
		}
		this._queueSocialBoostRefresh();
	}

	_queueGuildMembershipRefresh(player: Player, runtime: Runtime) {
		if (truthy(runtime.GuildRefreshBusy)) {
			return;
		}
		const profile = this._data.Get(player) as Profile | undefined;
		const guildId =
			profile !== undefined && typeIs(profile.Guild, "table") ? (((profile.Guild as Dict).Id as string) ?? "") : "";
		if (guildId === "") {
			return;
		}
		runtime.GuildRefreshBusy = true;
		const shadow = {
			Guild: copyDictionary(profile!.Guild) as Dict,
			GuildBonuses:
				(copyDictionary(
					profile!.GuildBonuses ?? { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 },
				) as Dict),
		};
		this._spawnWorker(() => {
			const [resolved, problem] = pcall(() => {
				this._guilds.ReconcileMembership(shadow, player.UserId);
			});
			if (resolved && this._running && player.Parent === Players && this._runtime.get(player) === runtime) {
				let changed = false;
				const committed = this._data.AtomicUpdate(
					player,
					(current: Profile) => {
						const currentGuild = current.Guild as Dict | undefined;
						if (currentGuild === undefined || currentGuild.Id !== guildId) {
							return { ok: false, noop: true };
						}
						const desiredGuild = (shadow.Guild ?? { Id: "", Role: "", JoinedAt: 0, Tag: "" }) as Dict;
						const desiredBonuses =
							(shadow.GuildBonuses ?? { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 }) as Dict;
						const currentBonuses = (current.GuildBonuses ?? {}) as Dict;
						changed =
							currentGuild.Id !== desiredGuild.Id ||
							currentGuild.Role !== desiredGuild.Role ||
							currentGuild.Tag !== desiredGuild.Tag ||
							currentGuild.JoinedAt !== desiredGuild.JoinedAt ||
							currentBonuses.Production !== desiredBonuses.Production ||
							currentBonuses.Capacity !== desiredBonuses.Capacity ||
							currentBonuses.Offline !== desiredBonuses.Offline;
						if (!changed) {
							return { ok: false, noop: true };
						}
						current.Guild = copyDictionary(desiredGuild);
						current.GuildBonuses = copyDictionary(desiredBonuses);
						return { ok: true };
					},
					true,
					"guild-refresh",
				);
				if (truthy(committed) && changed) {
					this._queueStatePush(player);
				}
			} else if (!resolved) {
				ModuleLog.Every("guild-refresh:" + tostring(player.UserId), 30, "Guild", string.format("guild refresh failed for %s: %s", player.Name, tostring(problem)));
			}
			runtime.GuildRefreshBusy = false;
		});
	}

	_processPlayerTick(player: Player, runtime: Runtime) {
		if (
			(runtime.MaintenanceAccumulator as number) >= PROFILE_MAINTENANCE_INTERVAL &&
			!truthy(this._data.IsBusy(player))
		) {
			runtime.MaintenanceAccumulator = (runtime.MaintenanceAccumulator as number) % PROFILE_MAINTENANCE_INTERVAL;
			let changed = false;
			const committed = this._data.AtomicUpdate(
				player,
				(profile: Profile) => {
					changed = truthy(ProgressionService.EnsureQuests(profile, player.UserId)) || changed;
					changed = truthy(ProgressionService.EnsureTimedRewards(profile)) || changed;
					changed = truthy(ProgressionService.EnsureCommandRotations(profile)) || changed;
					changed = truthy(ensureItemShop(profile)) || changed;
					changed = truthy(AnomalyService.Ensure(profile)) || changed;
					changed = truthy(LabService.Ensure(profile, player.UserId)) || changed;
					if (!truthy(this._antiCheat.Observe(player, "Maintenance", profile))) {
						changed = true;
					}
					if (!changed) {
						return { ok: false, noop: true };
					}
					return { ok: true };
				},
				true,
				"maintenance",
			);
			if (truthy(committed) && changed) {
				this._queueStatePush(player);
			}
		}
		if ((runtime.GuildRefreshAccumulator as number) >= GUILD_REFRESH_INTERVAL) {
			runtime.GuildRefreshAccumulator = (runtime.GuildRefreshAccumulator as number) % GUILD_REFRESH_INTERVAL;
			this._queueGuildMembershipRefresh(player, runtime);
		}
		if ((runtime.ProductionAccumulator as number) >= (GameConfig.Game.ProductionTick as number)) {
			const step = runtime.ProductionAccumulator as number;
			const pendingAnomalyActions = (runtime.PendingAnomalyActions as ReadonlyArray<string> | undefined) ?? NO_PENDING_ACTIONS;
			const pendingAnomalyCount = pendingAnomalyActions.size();
			let anomalyDetails: Dict | undefined;

			if (truthy(this._data.IsBusy(player))) {
				const maxCatchUp = (GameConfig.Game.ProductionTick as number) * 4;
				if ((runtime.ProductionAccumulator as number) > maxCatchUp) {
					runtime.ProductionAccumulator = maxCatchUp;
				}
			} else {
				runtime.ProductionAccumulator = 0;
				const ok = this._data.AtomicUpdate(
					player,
					(profile: Profile) => {
						const now = os.time();
						const active = ensureActiveBoost(profile) as Dict;
						if ((active.EndsAt as number) > 0 && (active.EndsAt as number) <= now) {
							profile.ActiveBoost = { Id: "", EndsAt: 0 };
						}
						const production = Economy.Mul(
							Economy.Production(profile, now),
							(this._convergence.Multiplier() as number) *
								(this._fluxSurge!.Multiplier(now) as number) *
								(this._events.ProductionMultiplier() as number) *
								(this._crews.Multiplier(player) as number),
						);
						const capacity = Economy.Capacity(profile, now);
						const produced = Economy.Mul(production, step);
						profile.Vault = Economy.Min(capacity, Economy.Add(profile.Vault, produced));

						const autoRate = Economy.AutoCollectRate(profile) as number;
						if (autoRate > 0 && truthy(Economy.Gt(profile.Vault, 0))) {
							const fromVault = Economy.Mul(profile.Vault, autoRate * step);
							const fromProd = Economy.Mul(produced, autoRate);
							const collected = Economy.Min(profile.Vault, Economy.Max(fromVault, fromProd));
							if (truthy(Economy.Gt(collected, 0))) {
								profile.Vault = Economy.Sub(profile.Vault, collected);
								profile.Cash = Economy.Add(profile.Cash, collected);
								profile.RunCash = Economy.Add(profile.RunCash, collected);
								profile.LifetimeCash = Economy.Add(profile.LifetimeCash, collected);
								const stats = ensureStats(profile) as Dict;
								stats.Collected = Economy.Add(stats.Collected, collected);
								ProgressionService.Progress(profile, "EarnCash", Economy.AsNumber(collected));
								LabService.Progress(profile, "BankFlux", Economy.AsNumber(collected));
							}
						}
						bumpStat(profile, "PlayTime", step);
						ProgressionService.EnsureTimedRewards(profile);
						const timedRewards = profile.TimedRewards as Dict;
						timedRewards.PlaySeconds = (timedRewards.PlaySeconds as number) + step;
						if (pendingAnomalyCount > 0) {
							let totalAmount = 0;
							let becameReady = false;
							for (let index = 0; index < pendingAnomalyCount; index++) {
								const pendingAction = pendingAnomalyActions[index];
								const [amount, ready] = AnomalyService.Progress(
									profile,
									(anomalyChargeByAction[pendingAction] as number | undefined) ?? 0,
								) as LuaTuple<[number, unknown]>;
								totalAmount += amount;
								becameReady = becameReady || truthy(ready);
								const signal = anomalySignalByAction[pendingAction];
								if (truthy(signal)) {
									AnomalyService.Signal(profile, signal, 1);
								}
							}
							anomalyDetails = {
								Amount: totalAmount,
								BecameReady: becameReady,
								Charge: (profile.Anomaly as Dict).Charge,
							};
						}
						enforceUnlimitedMoney(profile);
						// the tick just capped Vault at this capacity; pass it so the check skips a second Capacity pass
						this._antiCheat.Observe(player, "Production", profile, capacity);
					},
					false,
					"production",
				);
				if (!truthy(ok)) {
					runtime.ProductionAccumulator = (runtime.ProductionAccumulator as number) + step;
				} else if (pendingAnomalyCount > 0) {
					// Drain only the actions we processed; any appended during the tick
					// remain queued for the next production tick.
					const currentPending = (runtime.PendingAnomalyActions as string[] | undefined) ?? [];
					const remaining: string[] = [];
					for (let i = pendingAnomalyCount; i < currentPending.size(); i++) {
						remaining.push(currentPending[i]);
					}
					runtime.PendingAnomalyActions = remaining;
					this._queueStatePush(player);
					if (anomalyDetails !== undefined && truthy(anomalyDetails.BecameReady)) {
						this._effect.fire(player, {
							Type: "AnomalyReady",
							Amount: anomalyDetails.Amount,
							Charge: anomalyDetails.Charge,
						});
						this._toastPlayer(player, "Reactor ready", "Stabilize it for the payout.", "Special");
					}
				}
			}
		}

		if ((runtime.AutoForgeAccumulator as number) >= AUTO_FORGE_INTERVAL) {
			runtime.AutoForgeAccumulator = (runtime.AutoForgeAccumulator as number) % AUTO_FORGE_INTERVAL;
			this._tickAutoForge(player);
		}

		if ((runtime.DirtyAccumulator as number) >= 5) {
			runtime.DirtyAccumulator = 0;
			this._data.MarkDirty(player);
		}
		if ((runtime.PushAccumulator as number) >= (GameConfig.Game.StatePushSeconds as number)) {
			runtime.PushAccumulator = 0;
			const profile = this._data.Get(player) as Profile | undefined;
			if (profile !== undefined) {
				this._syncLeaderstats(player, profile);
				this._pushState(player);
			}
		}
	}

	_tickPlayer(player: Player, runtime: Runtime, deltaTime: number) {
		if (player.Parent !== Players) {
			return;
		}
		runtime.ProductionAccumulator = (runtime.ProductionAccumulator as number) + deltaTime;
		runtime.AutoForgeAccumulator = ((runtime.AutoForgeAccumulator as number | undefined) ?? 0) + deltaTime;
		runtime.PushAccumulator = (runtime.PushAccumulator as number) + deltaTime;
		runtime.DirtyAccumulator = (runtime.DirtyAccumulator as number) + deltaTime;
		runtime.MaintenanceAccumulator = ((runtime.MaintenanceAccumulator as number | undefined) ?? 0) + deltaTime;
		runtime.GuildRefreshAccumulator = ((runtime.GuildRefreshAccumulator as number | undefined) ?? 0) + deltaTime;

		const hasWork =
			(runtime.ProductionAccumulator as number) >= (GameConfig.Game.ProductionTick as number) ||
			(runtime.AutoForgeAccumulator as number) >= AUTO_FORGE_INTERVAL ||
			(runtime.DirtyAccumulator as number) >= 5 ||
			(runtime.PushAccumulator as number) >= (GameConfig.Game.StatePushSeconds as number) ||
			(runtime.MaintenanceAccumulator as number) >= PROFILE_MAINTENANCE_INTERVAL ||
			(runtime.GuildRefreshAccumulator as number) >= GUILD_REFRESH_INTERVAL;
		if (!hasWork) {
			return;
		}
		if (truthy(runtime.MatterWorkQueued)) {
			// watchdog: a tick worker that has not finished after 15s is released so production
			// resumes (checked here on the 5 Hz tick instead of a timer thread per work item)
			if (os.clock() - ((runtime.MatterWorkStartedAt as number | undefined) ?? math.huge) < 15) {
				return;
			}
			runtime.MatterWorkQueued = false;
			ModuleLog.Warn("game loop", string.format("player tick watchdog released %s after 15s", player.Name), {
				UserId: player.UserId,
			});
			return;
		}

		runtime.MatterWorkQueued = true;
		runtime.MatterWorkStartedAt = os.clock();
		const workToken = ((runtime.MatterWorkToken as number | undefined) ?? 0) + 1;
		runtime.MatterWorkToken = workToken;
		this._spawnWorker(() => {
			if (!this._running || player.Parent !== Players || this._runtime.get(player) !== runtime) {
				runtime.MatterWorkQueued = false;
				return;
			}
			const [ok, problem] = pcall(() => this._processPlayerTick(player, runtime));
			if (runtime.MatterWorkToken === workToken) {
				runtime.MatterWorkQueued = false;
			}
			if (!ok) {
				ModuleLog.Every(
					"matter-player-work:" + tostring(player.UserId),
					5,
					"game loop",
					string.format("deferred production failed for %s: %s", player.Name, tostring(problem)),
				);
			}
		});
	}

	_tick(deltaTime: number) {
		this._fluxSurge!.Tick(deltaTime);
		this._events.Step(deltaTime);

		this._rankPingAccumulator += deltaTime;
		if (this._rankPingAccumulator >= RANK_PING_INTERVAL) {
			this._rankPingAccumulator = 0;
			if (!this._rankPingBusy && Players.GetPlayers().size() > 0) {
				this._rankPingBusy = true;
				const worker = this._spawnWorker(() => {
					pcall(() => {
						this._getLeaderboard(RANK_PING_BOARD);
					});
					this._rankPingBusy = false;
				});
				if (!truthy(worker)) {
					this._rankPingBusy = false;
				}
			}
		}

		this._matterAccumulator += deltaTime;
		if (this._matterAccumulator < 0.2) {
			return;
		}
		this._matterAccumulator = 0;
		this._matter.Step();
	}

	Start() {
		if (this._running) {
			return;
		}
		this._running = true;
		this._convergence.Start();
		PolicyGate.Start();
		MarketplaceService.ProcessReceipt = (receiptInfo) => {
			const [ok, decision] = pcall(() => this._processReceipt(receiptInfo));
			if (ok) {
				return decision;
			}
			ModuleLog.Warn("Shop", "ProcessReceipt errored: " + tostring(decision));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		};
		this._matter.Start(this);
		this._world.SetInteractionHandler((player: Player, action: string, payload: unknown) => {
			if (action === "Collect") {
				this._collect(player);
			} else if (action === "BuyMachine") {
				this._buyMachine(player, payload);
			} else if (action === "Zone") {
				const profile = this._data.Get(player) as Profile | undefined;
				if (profile !== undefined && (payload as number) <= (profile.Zone as number)) {
					this._selectZone(player, payload);
				} else {
					this._unlockZone(player, payload);
				}
			}
			this._pushState(player);
		});

		ServerFunctions.request.setCallback((player: Player, action: string, payload?: unknown) => {
			const requestStartedAt = os.clock();

			if (
				player.GetAttribute("AstralForgeLoaded") !== true &&
				action !== Protocol.Actions.MeasureLatency &&
				action !== Protocol.Actions.ReportClientIntegrity &&
				action !== Protocol.Actions.ReportPerformance &&
				action !== Protocol.Actions.ReportPresence
			) {
				return responseError("Profile is still loading.");
			}
			if (truthy(this._security)) {
				const [authorityOk, authorityMessage] = (this._security.Authority as Svc).Validate(
					player,
					action,
					payload,
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(authorityOk)) {
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d authority %s %s", player.UserId, tostring(action), tostring(authorityMessage)),
					);
					return responseError(truthy(authorityMessage) ? authorityMessage : "Request rejected.");
				}

				if (
					!truthy(
						(this._security.Rate as Svc).Allow(
							player,
							action === Protocol.Actions.AdminExecute ? 1 : 0.1,
						),
					)
				) {
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d rate %s", player.UserId, tostring(action)),
					);
					return responseError("Please slow down for a moment.");
				}
			}
			const [allowed, firewallMessage] = this._firewall.Check(player, action, payload) as LuaTuple<
				[unknown, unknown]
			>;
			if (!truthy(allowed)) {
				if (action !== Protocol.Actions.ReportPresence && action !== Protocol.Actions.ReportPerformance) {
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d firewall %s %s", player.UserId, tostring(action), tostring(firewallMessage)),
					);
				}
				return responseError(truthy(firewallMessage) ? firewallMessage : "Please slow down for a moment.");
			}
			const readOnly = truthy(CommandActionValidators.IsReadOnly(action));
			const payloadTable = typeIs(payload, "table") ? (payload as Dict) : undefined;
			if (!readOnly) {
				const [grantOk, grantReason] = this._session.CheckGrant(
					player,
					payloadTable !== undefined ? payloadTable.Gen : undefined,
					payloadTable !== undefined ? payloadTable.N : undefined,
					CommandActionValidators.RequiresHighValueNonce(action),
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(grantOk)) {
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d drop %s %s", player.UserId, tostring(action), tostring(grantReason)),
					);
					const [liveGen, liveNonce] = this._session.Peek(player) as LuaTuple<[unknown, unknown]>;
					return {
						ok: false,
						error: "Your session needs to refresh. One moment.",
						Gen: liveGen,
						N: liveNonce,
						Auth: grantReason === "unauth" ? false : undefined,
					} as Response;
				}
			}
			const txnId =
				payloadTable !== undefined && typeIs(payloadTable.TxnId, "string") ? payloadTable.TxnId : undefined;
			let txnClaimed = false;
			if (txnId !== undefined) {
				if (txnId.size() > 64) {
					Report(player, "txn-id", 2, "TxnId of " + txnId.size() + " chars");
					return responseError("That request could not be validated.");
				}
				const [status, storedResult] = this._session.TxnClaim(
					player,
					txnId,
					tostring(action) + "|" + PayloadShape.Fingerprint(payload, TXN_PRINT_IGNORE),
				) as LuaTuple<[unknown, unknown]>;
				if (status === "mismatch") {
					Report(player, "txn-replay", 3, string.format("%s reused a TxnId from a different request", tostring(action)));
					return responseError("That request could not be validated.");
				}
				if (status === "done") {
					return storedResult as Response;
				}
				if (status === "busy") {
					return responseError("Still working on that.");
				}
				txnClaimed = true;
			}
			const [success, result] = pcall(() => this._handleAction(player, action, payload));
			if (!success) {
				if (txnClaimed && txnId !== undefined) {
					this._session.TxnRelease(player, txnId);
				}
				ModuleLog.Every(
					string.format("action:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d could not run %s: %s", player.UserId, tostring(action), tostring(result)),
				);
				return responseError("The forge encountered an error. Please try again.");
			}
			const resultBag = result as Dict;
			if (!typeIs(resultBag, "table") || !typeIs(resultBag.ok, "boolean")) {
				if (txnClaimed && txnId !== undefined) {
					this._session.TxnRelease(player, txnId);
				}
				ModuleLog.Every(
					string.format("action-contract:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d got an invalid response for %s", player.UserId, tostring(action)),
				);
				return responseError("The forge returned an invalid response. Please try again.");
			}
			if (txnClaimed && txnId !== undefined) {
				if (resultBag.ok === true) {
					this._session.TxnStore(player, txnId, resultBag);
				} else {
					this._session.TxnRelease(player, txnId);
				}
			}
			if (resultBag.ok === false) {
				this._flagFailedRequest(player, action as string);
			}
			if (
				resultBag.ok === false &&
				action !== Protocol.Actions.ReportPresence &&
				action !== Protocol.Actions.ReportPerformance
			) {
				ModuleLog.Every(
					string.format("result:%d:%s", player.UserId, tostring(action)),
					10,
					"Action",
					string.format("u=%d %s failed: %s", player.UserId, tostring(action), tostring(resultBag.error)),
				);
			}
			if (resultBag.ok === true && !readOnly) {
				this._spawnWorker(() => {
					if (player.Parent !== Players) {
						return;
					}
					this._progressAnomalyFromAction(player, action as string);
					const profile = this._data.Get(player) as Profile | undefined;
					if (profile !== undefined) {
						this._convergence.RecordAction(player, tostring(action));
						if (action === Protocol.Actions.CollectVault) {
							this._crews.RecordCollect(player);
						}
						this._analytics.RecordAction(player, tostring(action), profile, (os.clock() - requestStartedAt) * 1000);
						this._badges.Evaluate(player, profile, tostring(action));
					}
					this._syncLeaderstats(player, profile);
					if (!truthy(CommandActionValidators.IsDeferredSnapshot(action))) {
						this._queueStatePush(player);
					}
				});
			}
			if (!readOnly && resultBag.Gen === undefined) {
				const [gen, nonce] = this._session.Peek(player) as LuaTuple<[unknown, unknown]>;
				resultBag.Gen = gen;
				resultBag.N = nonce;
			}
			return resultBag;
		});

		this._playerAddedConnection = Players.PlayerAdded.Connect((player) => {
			this._spawnWorker(() => {
				this._safePlayerAdded(player);
			});
		});
		this._playerRemovingConnection = Players.PlayerRemoving.Connect((player) => {
			this._onPlayerRemoving(player);
			this._queueSocialBoostRefresh();
		});
		for (const player of Players.GetPlayers()) {
			this._spawnWorker(() => {
				this._safePlayerAdded(player);
			});
		}
		this._heartbeat = RunService.Heartbeat.Connect((deltaTime) => {
			if (!this._running) {
				return;
			}
			this._tick(deltaTime);
		});
	}

	GrantStudioMoney(player: Player): LuaTuple<[boolean, string, unknown]> {
		if (!truthy(ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return $tuple(false, "Studio grants are disabled in published servers.", undefined);
		}
		if (player.Parent !== Players) {
			return $tuple(false, "That player is not in this server.", undefined);
		}
		if (this._data.Get(player) === undefined) {
			return $tuple(false, "The player's profile is still loading. Wait for the game UI, then retry.", undefined);
		}

		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			(profile.Flags as Dict).UnlimitedMoney = true;
			enforceUnlimitedMoney(profile);
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, "Profile update failed: " + tostring(updateError), undefined);
		}

		this._syncLeaderstats(player, this._data.Get(player) as Profile | undefined);
		this._pushState(player);
		this._toastPlayer(player, "Unlimited Flux enabled", "Your test balance will not decrease.", "Success");
		if (!truthy(this._data.Save(player, false))) {
			return $tuple(false, "The balance changed in-session, but the forced DataStore save failed.", undefined);
		}
		return $tuple(true, "Unlimited Flux lock enabled and saved. Purchases cannot lower it.", MAX_SAFE_CURRENCY);
	}

	GrantStudioWheelSpins(player: Player, amount: unknown): LuaTuple<[boolean, string, unknown]> {
		if (!truthy(ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return $tuple(false, "Studio grants are disabled in published servers.", undefined);
		}
		if (player.Parent !== Players) {
			return $tuple(false, "That player is not in this server.", undefined);
		}
		if (this._data.Get(player) === undefined) {
			return $tuple(false, "The player's profile is still loading. Wait for the game UI, then retry.", undefined);
		}

		const grant = ShopGrantEligibility.ClampWheelGrant(amount) as number;
		let total = 0;
		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			const wheel = profile.Wheel as Dict;
			const current = math.max(0, math.floor(tonumber(wheel.FreeSpins) ?? 0));
			total = current + grant;
			wheel.FreeSpins = total;
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, "Profile update failed: " + tostring(updateError), undefined);
		}

		this._pushState(player);
		this._toastPlayer(
			player,
			"Free wheel spins",
			tostring(grant) + " spins added (" + tostring(total) + " ready).",
			"Success",
		);
		return $tuple(true, "Granted " + tostring(grant) + " free wheel spins (" + tostring(total) + " total).", total);
	}

	ShowRelease(player: Player): LuaTuple<[boolean, string]> {
		if (player.Parent !== Players) {
			return $tuple(false, "That player is not in this server.");
		}
		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = "";
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, "Profile update failed: " + tostring(updateError));
		}
		this._pushState(player);
		return $tuple(true, "Release notes reopened for " + player.Name + ".");
	}

	Shutdown() {
		this._running = false;
		this._joining = new Map();
		this._socialBoostDirty = false;
		this._socialBoostScheduled = false;
		if (this._socialBoostWorker !== undefined) {
			task.cancel(this._socialBoostWorker);
			this._socialBoostWorker = undefined;
		}
		if (this._playerAddedConnection !== undefined) {
			this._playerAddedConnection.Disconnect();
			this._playerAddedConnection = undefined;
		}
		if (this._playerRemovingConnection !== undefined) {
			this._playerRemovingConnection.Disconnect();
			this._playerRemovingConnection = undefined;
		}
		for (const [player, connection] of this._characterConnections) {
			connection.Disconnect();
			this._characterConnections.delete(player);
		}
		this._joining.clear();
		if (this._admin !== undefined) {
			this._admin.Destroy();
		}

		ServerFunctions.request.setCallback(() => responseError("The server is shutting down."));
		for (const [player, pending] of this._queuedStatePushes) {
			task.cancel(pending);
			this._queuedStatePushes.delete(player);
		}
		for (const [token, worker] of this._backgroundWorkers) {
			pcall(() => task.cancel(worker));
			this._backgroundWorkers.delete(token);
		}
		if (this._heartbeat !== undefined) {
			this._heartbeat.Disconnect();
			this._heartbeat = undefined;
		}
		this._matter.Stop();
		this._convergence.Stop();
		this._guilds.Destroy();
		this._guildCommunity.Shutdown();
		this._chat.Shutdown();
		this._crews.Shutdown();
		this._badges.Destroy();
	}
}

