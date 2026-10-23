// Module-level helpers shared by GameService and its Gameplay domain modules (todo500 #3).
import { T } from "../../../Shared/AstralForge/Shared/Locale";
import type { StoreRow } from "../Modules/LeaderboardService";
import type { FriendGraph } from "../Modules/FriendGraph";
import type { PassDef as PurchasePassDef, ReceiptOutcome as PurchaseReceiptOutcome } from "../Modules/Purchases";
import * as Deps from "../Modules/GameServiceDeps";
import { Service } from "@flamework/core";
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
import * as TradeEngine from "../Modules/TradeEngine";
import { Roll as crateRoll, RollRecord as CrateRollRecord } from "../Modules/CrateRng";
import { Ledgers as EconomyLedgers, Snapshot as walletSnapshot } from "../Modules/EconomyLedger";
import { ServerEventService } from "./Gameplay/ServerEventService";
import CompanionBonds = require("./Gameplay/CompanionBonds");
import ExpeditionBoardService = require("./Gameplay/ExpeditionBoard");
import ForgeProgramsService = require("./Gameplay/ForgePrograms");
import ForgePrograms = require("../../../Shared/AstralForge/Shared/ForgePrograms");
import ExpeditionBoard = require("../../../Shared/AstralForge/Shared/ExpeditionBoard");
import * as HotFlags from "./Security/HotFlags";
import * as CommunityRewards from "./Gameplay/CommunityRewards";
import { MatterRuntime } from "./MatterRuntime";
import * as PolicyGate from "./PolicyGate";
import * as WeeklyStores from "./WeeklyStores";
import * as LimitedEvents from "../../../Shared/AstralForge/Shared/LimitedEvents";
import * as WeeklyBoard from "../../../Shared/AstralForge/Shared/WeeklyBoard";
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";
import * as Constellations from "../../../Shared/AstralForge/Shared/Constellations";
import * as RelicEngraving from "../../../Shared/AstralForge/Shared/RelicEngraving";
import * as RelicRecipes from "../../../Shared/AstralForge/Shared/RelicRecipes";
import * as RelicModel from "../../../Shared/AstralForge/Shared/RelicModel";
import CompanionRelic = require("../../../Shared/AstralForge/Shared/CompanionRelic");
import * as ProfileStyle from "../../../Shared/AstralForge/Shared/ProfileStyle";
import * as SeenHints from "../../../Shared/AstralForge/Shared/SeenHints";
import * as FirstGoals from "../../../Shared/AstralForge/Shared/FirstGoals";
import * as NavRoutes from "../../../Shared/AstralForge/Shared/NavRoutes";
import * as K from "./GameKits";
import * as ResetSpec from "../../../Shared/AstralForge/Shared/ResetSpec";
import * as TradeDomain from "./Gameplay/TradeDomain";

// Most of what GameService touches comes back from kits as opaque values, so module tables are typed as dot-called functions and service instances as
// colon-called methods. Values coming back are narrowed where they are used.
export type Fn = (this: void, ...args: unknown[]) => unknown;
export type Method = (this: object, ...args: unknown[]) => unknown;
export type Kit = Record<string, Fn>;
export type Svc = Record<string, Method>;
export type Profile = Dict;
export type Response = Dict;


// per-player server-side state kept between requests
export type Runtime = Dict;

// Luau `a or b()`: b only runs when a is nil or false
export function orElse<T, U>(value: T, fallback: () => U): Exclude<T, undefined | false> | U {
	return truthy(value) ? (value as Exclude<T, undefined | false>) : fallback();
}

// Luau `x or {}` for a value read as a table
export function orEmpty(value: unknown, fallback: () => object): Dict {
	return (truthy(value) ? value : fallback()) as Dict;
}

export const Players = game.GetService("Players");
export const ReplicatedStorage = game.GetService("ReplicatedStorage");
export const RunService = game.GetService("RunService");
export const MarketplaceService = game.GetService("MarketplaceService");
export const HttpService = game.GetService("HttpService");
export const ServerStorage = game.GetService("ServerStorage");
export const Workspace = game.GetService("Workspace");

// The limited event this server is running, or undefined. In Studio, setting the Workspace attribute
// AstralForgeEventPreview to an event id runs that event now so its stall can be checked early.
export function liveEvent(now: number): LimitedEvents.LimitedEvent | undefined {
	if (RunService.IsStudio()) {
		const preview = LimitedEvents.byId(Workspace.GetAttribute("AstralForgeEventPreview"));
		if (preview !== undefined) {
			return preview;
		}
	}
	return LimitedEvents.activeAt(now);
}

export function limitedEventPublic(profile: Profile, now: number) {
	const event = HotFlags.Get("LimitedEventsPaused") ? undefined : liveEvent(now);
	const upcoming = LimitedEvents.nextAfter(now);
	const bag = profile.LimitedEvent as Dict | undefined;
	const mine = event !== undefined && typeIs(bag, "table") && bag.Id === event.Id;
	return {
		Id: event?.Id,
		Paused: HotFlags.Get("LimitedEventsPaused"),
		Tokens: mine ? bag!.Tokens : 0,
		DayEarned: mine && bag!.Day === math.floor(now / 86400) ? bag!.DayEarned : 0,
		Bought: mine ? bag!.Bought : {},
		NextId: upcoming?.Id,
	};
}

export function communityConfig(): CommunityRewards.CommunityConfig {
	return {
		GroupId: typeIs(K.ServerConfig.CommunityGroupId, "number") ? K.ServerConfig.CommunityGroupId : 0,
		GroupName: tostring(K.ServerConfig.CommunityGroupName),
		GroupReward: K.ServerConfig.GroupReward as unknown as Dict,
		Likes: typeIs(K.ServerConfig.CommunityLikes, "number") ? K.ServerConfig.CommunityLikes : 0,
		LikeGoals: K.ServerConfig.LikeGoals as unknown as ReadonlyArray<CommunityRewards.LikeGoal>,
		NotifyEnabled: K.ServerConfig.NotifyOptInRewardEnabled === true,
		NotifyReward: K.ServerConfig.NotifyReward as unknown as Dict,
	};
}
// read-only stand-in for an empty anomaly action queue (the 5 Hz tick reads it every pass)
export const NO_PENDING_ACTIONS: ReadonlyArray<string> = table.freeze([]);

// guild kick/ban/reconcile paths reset bonuses
export const emptyBonuses = () => K.GuildMath.EmptyBonuses();

export const MAX_SAFE_CURRENCY = 1e308;
export const AUTO_FORGE_INTERVAL = 2;
export const PROFILE_MAINTENANCE_INTERVAL = 10;
export const GUILD_REFRESH_INTERVAL = 30;
export const GLOBAL_LB_PAGE = 25;
// store pages are re-read at most once a minute per board; failed reads back off from 30s
export const boardReader = new Deps.LeaderboardService({
	pageSize: GLOBAL_LB_PAGE,
	pageTtl: 60,
	retryAfter: 30,
	decode: (raw) => K.LeaderboardCodec.Decode(raw),
	greater: (a, b) => truthy(K.Economy.Gt(a, b)),
});
export const RANK_PING = {
	INTERVAL: 20,
	BOARD: "Flux",
	BOARD_LABEL: "Lifetime Flux",
	BRACKETS: K.RankBracket.DEFAULT_BRACKETS,
	UNRANKED: K.RankBracket.UNRANKED,
};
export const GUILD_ACTIVITY_MILESTONE_STEP = 250_000;

export const applySocialBoost = (profile: Profile, friendCount: number, premium: boolean): boolean =>
	K.SocialBoost.Apply(profile, friendCount, premium, K.GameConfig.Social) as boolean;

export const GENERAL_BOARD_STORE_NAMES: Record<string, string> = {
	Flux: K.ServerConfig.LeaderboardStoreName as string,
	Rebirths: K.ServerConfig.RebirthLeaderboardStoreName as string,
	PlayTime: K.ServerConfig.PlayTimeLeaderboardStoreName as string,
	Dust: K.ServerConfig.DustLeaderboardStoreName as string,
	Cores: K.ServerConfig.CoresLeaderboardStoreName as string,
	Domain: K.ServerConfig.DomainLeaderboardStoreName as string,
	Worlds: K.ServerConfig.WorldLeaderboardStoreName as string,
	Crates: K.ServerConfig.CratesLeaderboardStoreName as string,
	Finds: K.ServerConfig.FindsLeaderboardStoreName as string,
	Ore: K.ServerConfig.OreLeaderboardStoreName as string,
	Wardens: K.ServerConfig.WardensLeaderboardStoreName as string,
	Orders: K.ServerConfig.OrdersLeaderboardStoreName as string,
	Stars: K.ServerConfig.StarsLeaderboardStoreName as string,
	Cipher: K.ServerConfig.CipherLeaderboardStoreName as string,
};

export const generalBoardValue = (profile: Profile, id: string) => K.GeneralBoardValue.Of(profile, id, K.Economy.Persist);

export const anomalyChargeByAction = K.ActionFeatureMaps.ANOMALY_CHARGE as Record<string, unknown>;

export const encodeTelemetry = (
	revision: unknown,
	settings: unknown,
	cash: unknown,
	vault: unknown,
	production: unknown,
	capacity: unknown,
	cores: unknown,
	stardust: unknown,
) => K.TelemetryMath.Encode(revision, settings, cash, vault, production, capacity, cores, stardust, K.Economy.AsNumber);

export const anomalySignalByAction = K.ActionFeatureMaps.ANOMALY_SIGNAL as Record<string, unknown>;
export const featureByAction = K.ActionFeatureMaps.FEATURE as Record<string, unknown>;

export const enforceUnlimitedMoney = (profile: Profile) => {
	K.UnlimitedMoneySeal.Apply(profile, MAX_SAFE_CURRENCY, K.Economy);
};

export const itemById: Record<string, Dict> = {};
export const crateById: Record<string, Dict> = {};
export const itemOfferById: Record<string, Dict> = {};
export const storyById: Record<string, Dict> = {};
export const mailById: Record<string, Dict> = {};
for (const [, definition] of pairs(K.GameConfig.Items.Definitions as Dict[])) {
	itemById[definition.Id as string] = definition;
}
for (const [, crate] of pairs(K.GameConfig.Items.Crates as Dict[])) {
	crateById[crate.Id as string] = crate;
}
for (const [, offer] of pairs(K.GameConfig.Items.ShopOffers as Dict[])) {
	itemOfferById[offer.Id as string] = offer;
}
for (const [, chapter] of pairs(K.GameConfig.Story)) {
	storyById[chapter.Id as string] = chapter;
}
for (const [, message] of pairs(K.GameConfig.Mail)) {
	mailById[message.Id as string] = message;
}

export const utcDay = (): number => K.UtcClockMath.Day(os.time()) as number;

export const nextUtcMidnight = (): number => K.UtcClockMath.NextMidnight(os.time()) as number;

export const offerStockMax = (offer: unknown): number => K.ShopGrantEligibility.StockMax(offer) as number;

export const inventoryCount = (profile: Profile): number => {
	const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
	return K.ShopGrantEligibility.InventoryCount(items.Inventory) as number;
};

export const ensureItemShop = (profile: Profile): boolean => {
	const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
	return K.ShopGrantEligibility.EnsureShop(items.Shop, K.GameConfig.Items.ShopOffers, utcDay()) as boolean;
};

export const ensureStats = (profile: Profile) => K.ProfileBagMath.EnsureStats(profile) as Dict;

export const bumpStat = (profile: Profile, key: string, amount?: number) => K.ProfileBagMath.BumpStat(profile, key, amount);

// first time a relic rig is fully socketed: mark it, pay it, and describe it
export const grantLitRigs = (profile: Profile): LuaTuple<[number, string]> => {
	const fresh = K.RelicRigs.Settle(profile) as Array<{ Name: string; Reward: Dict; Percent: number; Kind: string }>;
	if (fresh.size() === 0) {
		return $tuple(0, "");
	}
	const parts: string[] = [];
	for (const entry of fresh) {
		const paid = K.ProgressionService.ApplyReward(profile, entry.Reward, K.Economy.Production(profile)) as string;
		const effect = K.RelicRigs.effectText(entry) as string;
		if (typeIs(paid, "string") && paid !== "") {
			parts.push(`${entry.Name}: ${effect} (${paid})`);
		} else {
			parts.push(`${entry.Name}: ${effect}`);
		}
	}
	return $tuple(fresh.size(), parts.join(", "));
};

export const ensureActiveBoost = (profile: Profile) => K.ProfileBagMath.EnsureActiveBoost(profile) as Dict;

export const ensureBoostInventory = (profile: Profile) => K.ProfileBagMath.EnsureBoostInventory(profile) as Dict;

export const ensureCommandMastery = (profile: Profile) => {
	const command = K.CommandMath.Ensure(profile.Command, K.GameConfig.Operations.SeasonId) as Dict;
	profile.Command = command;
	return command.MachineMastery as Dict;
};

export const copyDictionary = (source: unknown) => K.DataSanitizeMath.DeepCopy(source);

export const responseError = (message: unknown): Response => K.ActionResponse.Error(message) as Response;

// session fields that legitimately change when the client retries a TxnId
export const TXN_PRINT_IGNORE: Record<string, boolean> = { Gen: true, N: true, TxnId: true };

export const responseSuccess = (message?: unknown, extra?: unknown): Response => K.ActionResponse.Success(message, extra) as Response;

export const publicPlayerRecord = (player: Player, profile: Profile, viewer: Player, presence: unknown) =>
	K.PublicPlayerRecord.Build(player, profile, viewer, presence, {
		Economy: K.Economy,
	}) as Dict;

export const buildVisitSnapshot = (player: Player, profile: Profile) => K.VisitSnapshot.Build(player, profile, K.Economy);

// extracts a user id the way every social action does: ExtractUserId when present, then coerce
export const extractUserId = (raw: unknown): unknown => (RemoteFirewall.ExtractUserId !== undefined ? RemoteFirewall.ExtractUserId(raw) : raw);

export const PRESENCE_PAGES: Record<string, boolean> = {
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
export const studioCheck = (): boolean => {
	let isStudio = false;
	pcall(() => {
		const rs = game.GetService("RunService");
		if (rs && typeIs((rs as unknown as Dict).IsStudio, "function")) {
			isStudio = rs.IsStudio();
		}
	});
	return isStudio;
};

export const StoreAccess = require(K.root.WaitForChild("Modules").WaitForChild("StoreAccess") as ModuleScript) as Kit;

export function resetContext(carry?: Dict): ResetSpec.ResetContext {
	return {
		StartingCash: K.GameConfig.Economy.StartingCash as number,
		LabBaseCells: ((K.GameConfig.Lab as unknown as Dict).Power as Dict).BaseCells as number,
		Carry: carry !== undefined ? { Cash: carry.Cash, Machines: carry.Machines } : undefined,
	};
}
export const getOrderedStore = StoreAccess.ordered;

export const reportLedger = K.ReportLedger.new() as Svc;
Players.PlayerRemoving.Connect((leaving) => {
	reportLedger.forgetReporter(leaving.UserId);
});

export const itemSalvageValue = (instance: Dict, definition: Dict): number => {
	const rarity = (K.GameConfig.Items.Rarities as Record<string, Dict | undefined>)[definition.Rarity as string];
	const rank = rarity && truthy(rarity.Rank) ? rarity.Rank : 1;
	return K.ItemSalvage.Value(instance.Level, rank) as number;
};

export const shopShared = (): LuaTuple<[Kit, Kit]> => {
	return $tuple(K.SharedDataSuite("ShopCatalog") as Kit, K.SharedDataSuite("RelicSystem") as Kit);
};

export const spendShopCurrency = (profile: Profile, currency: string, price: number): string | undefined => {
	if (currency !== "Stardust" && currency !== "Cores") {
		return T("GameService.ThatOfferCanTBe", tostring(currency));
	}
	const have = tonumber(profile[currency]) ?? 0;
	if (have < price) {
		return string.format("You need %s more %s.", (K.Format.Number as Fn)(price - have) as string, string.lower(currency));
	}
	profile[currency] = have - price;
	return undefined;
};

export const ensureAutoSalvage = (profile: Profile) => K.ProfileBagMath.EnsureAutoSalvage(profile) as Dict;

export const progressionNumber = (value: unknown): number => K.Economy.AsNumber(value) as number;

export const clampProgressionNumbers = (profile: Profile) => {
	K.ProfileClampMath.ClampProgressionNumbers(profile, K.Economy.Persist, MAX_SAFE_CURRENCY);
};

export const OVERCHARGE_COMBO_WINDOW = K.GameConfig.Overcharge.ComboWindow as number;
export const OVERCHARGE_COMBO_MAX = K.GameConfig.Overcharge.ComboMax as number;
export const OVERCHARGE_COMBO_BONUS = K.GameConfig.Overcharge.ComboBonusPerStack as number;

export const overchargeComboWindow = (_profile: unknown): number => K.OverchargeCombo.Window(OVERCHARGE_COMBO_WINDOW) as number;

export const overchargeComboMultiplier = (_profile: unknown, combo: number): number =>
	K.OverchargeCombo.Multiplier(combo, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS) as number;

// The full snapshot is ~350 KB (the star grid alone is ~200 KB) and goes out every few seconds.
// Sections that are identical to the ones this player was last sent are left out and listed in
// `Reused`; the client fills them back in from its previous copy. Every so often a full snapshot
// goes out anyway so the two sides can never drift.
export const FULL_SNAPSHOT_EVERY = 60;
// true = same, false = different, nil = no differences found but a shared table was met: the
// very same table may have been edited in place since it was sent, so it can't vouch for itself
export const sameValue = (left: unknown, right: unknown, depth: number): boolean | undefined => {
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
export const fingerprint = (value: unknown): string | undefined => {
	const [ok, encoded] = pcall(() => HttpService.JSONEncode(value));
	return ok ? encoded : undefined;
};

// runs one AnomalyService call inside a mutation and hands back what it reported
export const anomalyCall = (
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
export const rebirthLedger = (profile: Profile, now: number): Dict => {
	let seed: number | undefined = undefined;
	if (profile.Rebirth === undefined) {
		seed =
			(num(profile.Rebirths) ?? 0) +
			(isTable(profile.Domain) ? (num(profile.Domain.TotalRebirthsSpent) ?? 0) : 0) +
			(isTable(profile.Ascension) ? (num(profile.Ascension.RebirthsSpent) ?? 0) : 0);
	}
	profile.Rebirth = K.RebirthMath.ensure(profile.Rebirth, now, seed);
	return profile.Rebirth as Dict;
};

// the facts a vow is judged on, and the flux this run would convert
export const rebirthRun = (profile: Profile, now: number, ledger: Dict): LuaTuple<[Dict, unknown]> => {
	let kinds = 0;
	for (const [, level] of pairs(orEmpty(profile.Machines, () => ({})))) {
		if (typeIs(level, "number") && level >= 1) {
			kinds += 1;
		}
	}
	const rebirthConfig = orEmpty(K.GameConfig.Economy.Rebirth, () => ({}));
	const bank = rebirthConfig.BankVaultIntoRun !== false ? K.Economy.Add(profile.RunCash, profile.Vault) : profile.RunCash;
	const ratio = (K.Economy.AsNumber(bank) as number) / math.max(1, K.Economy.PrestigeRequirementFor(num(profile.Rebirths) ?? 0) as number);
	return $tuple({ Seconds: now - (ledger.RunStartedAt as number), Zone: profile.Zone, MachineKinds: kinds, Ratio: ratio }, bank);
};

// BALANCE v8: one rebirth's cores past Rebirth.CoreSoftCap grow with a square root
export const softCapCores = (reward: unknown): unknown => {
	const rebirthConfig = orEmpty(K.GameConfig.Economy.Rebirth, () => ({})) as Dict;
	const cap = num(rebirthConfig.CoreSoftCap);
	const exponent = num(rebirthConfig.CoreSoftExponent) ?? 0.5;
	if (cap === undefined || cap <= 0 || !truthy(K.Economy.Gt(reward, cap))) {
		return reward;
	}
	return K.OmegaMath.Floor(K.OmegaMath.Mul(cap, K.OmegaMath.Pow(K.OmegaMath.Div(reward, cap), exponent)));
};

// BALANCE v8: Stardust price to run a boost without an owned charge, or undefined when it isn't sold
export const stardustBoostPrice = (profile: Profile, boostId: string): number | undefined => {
	const rebirthConfig = orEmpty(K.GameConfig.Economy.Rebirth, () => ({})) as Dict;
	const prices = rebirthConfig.StardustBoostPrices as Record<string, number> | undefined;
	const base = prices !== undefined ? prices[boostId] : undefined;
	if (!typeIs(base, "number") || base <= 0) {
		return undefined;
	}
	const perRebirth = num(rebirthConfig.StardustBoostPerRebirth) ?? 0;
	return math.floor(base * (1 + math.max(0, num(profile.Rebirths) ?? 0) * perRebirth));
};

// cores and stardust before the ledger's own multipliers, or nil when the run can't convert yet
export const rebirthBase = (profile: Profile, bank: unknown): LuaTuple<[unknown, number]> => {
	let reward = K.Economy.PrestigeReward(bank, num(profile.Rebirths) ?? 0);
	if (!truthy(K.RebirthGate.CanRebirth(reward, K.Economy.Gte))) {
		return $tuple(undefined, 0);
	}
	reward = softCapCores(reward);
	reward = K.Economy.Max(1, K.Economy.Floor(K.Economy.Mul(reward, 1 + (K.Economy.DomainTreeBonus(profile, "RebirthYield") as number))));
	reward = K.Economy.Floor(K.Economy.Mul(reward, K.Economy.AscensionEffect(profile, "Cores")));
	const rebirthConfig = orEmpty(K.GameConfig.Economy.Rebirth, () => ({}));
	const dust = K.RebirthGate.StardustReward(
		K.Economy.AsNumber(reward),
		num(rebirthConfig.StardustSqrtScale) ?? 5,
		num(rebirthConfig.StardustMinimum) ?? 4,
	) as number;
	return $tuple(reward, dust);
};

// machines a keepsake may carry: ones that live in the first world and are open after this rebirth
export const keepsakeAllowed = (profile: Profile) => {
	return (id: string): boolean => {
		const machine = K.Economy.GetMachine(id) as Dict | undefined;
		return (
			machine !== undefined &&
			(num(machine.RequiredZone) ?? 1) <= 1 &&
			truthy(K.RebirthGate.MeetsRequired((num(profile.Rebirths) ?? 0) + 1, machine.RequiredRebirths))
		);
	};
};
