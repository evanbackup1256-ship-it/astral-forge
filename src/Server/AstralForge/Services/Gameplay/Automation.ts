// Moved out of GameService (todo500). Behaviour, remote names and payloads are unchanged; GameService delegates here.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import type { StoreRow } from "../../Modules/LeaderboardService";
import type { FriendGraph } from "../../Modules/FriendGraph";
import type { PassDef as PurchasePassDef, ReceiptOutcome as PurchaseReceiptOutcome } from "../../Modules/Purchases";
import * as Deps from "../../Modules/GameServiceDeps";
import { Service } from "@flamework/core";
import { ConvergenceService } from "../ConvergenceService";
import { DataService } from "../DataService";
import { AdminService } from "../AdminService";
import { WorldService } from "../WorldService";
import { Security } from "../Security/Security";
import { SessionGate } from "../Security/SessionGate";
import { GameAntiCheat } from "../Security/GameAntiCheat";
import { PlayerAnalytics } from "../PlayerAnalytics";
import { PlayerBadges } from "../PlayerBadges";
import { SpecializationService } from "../SpecializationService";
// GameService: the gameplay hub (remotes, runtime state, every player action).
import { Dict, isTable, num, truthy } from "../LuaInterop";
import { PayloadEvent, ServerEvents, ServerFunctions } from "../../Runtime/ServerNetwork";
import { FluxSurgeService } from "../FluxSurgeService";
import { GuildService } from "./GuildService";
import { RemoteFirewall } from "../Security/RemoteFirewall";
import * as ActionBuckets from "../Security/ActionBuckets";
import * as PayloadShape from "../Security/PayloadShape";
import { Ledger, Report } from "../Security/SecurityLedger";
import * as TradeEngine from "../../Modules/TradeEngine";
import { Roll as crateRoll, RollRecord as CrateRollRecord } from "../../Modules/CrateRng";
import { Ledgers as EconomyLedgers, Snapshot as walletSnapshot } from "../../Modules/EconomyLedger";
import { ServerEventService } from "./ServerEventService";
import CompanionBonds = require("./CompanionBonds");
import ExpeditionBoardService = require("./ExpeditionBoard");
import ForgeProgramsService = require("./ForgePrograms");
import ForgePrograms = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import ExpeditionBoard = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import * as HotFlags from "../Security/HotFlags";
import * as CommunityRewards from "./CommunityRewards";
import { MatterRuntime } from "../MatterRuntime";
import * as PolicyGate from "../PolicyGate";
import * as WeeklyStores from "../WeeklyStores";
import * as LimitedEvents from "../../../../Shared/AstralForge/Shared/LimitedEvents";
import * as WeeklyBoard from "../../../../Shared/AstralForge/Shared/WeeklyBoard";
import * as PlayPolicy from "../../../../Shared/AstralForge/Shared/PlayPolicy";
import * as Constellations from "../../../../Shared/AstralForge/Shared/Constellations";
import * as RelicEngraving from "../../../../Shared/AstralForge/Shared/RelicEngraving";
import * as RelicRecipes from "../../../../Shared/AstralForge/Shared/RelicRecipes";
import * as RelicModel from "../../../../Shared/AstralForge/Shared/RelicModel";
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import * as SeenHints from "../../../../Shared/AstralForge/Shared/SeenHints";
import * as FirstGoals from "../../../../Shared/AstralForge/Shared/FirstGoals";
import * as NavRoutes from "../../../../Shared/AstralForge/Shared/NavRoutes";
import * as K from "../GameKits";
import * as ResetSpec from "../../../../Shared/AstralForge/Shared/ResetSpec";
import * as TradeDomain from "./TradeDomain";
import * as Snapshot from "./Snapshot";
import * as DomainExpansion from "./DomainExpansion";
import * as Rebirth from "./Rebirth";
import * as Leaderstats from "./Leaderstats";
import * as Moderation from "./Moderation";
import * as CrateOpening from "./CrateOpening";
import * as ShopDomain from "./ShopDomain";
import * as BoostDomain from "./BoostDomain";
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function tickForgePrograms(svc: GameService, player: Player, runtime: Runtime) {
		const live = svc._data.Get(player) as Profile | undefined;
		if (live === undefined || !ForgePrograms.unlocked(live) || ForgePrograms.rulesOf(live).size() === 0) {
			return;
		}
		const now = os.time();
		const cash = live.Cash;
		let cheapest: string | undefined;
		let cheapestCost: unknown;
		for (const machine of K.GameConfig.Machines as unknown as Dict[]) {
			const id = machine.Id as string;
			const level = (num((live.Machines as Dict)[id]) ?? 0) as number;
			if (level >= (machine.MaxLevel as number) || truthy(K.ProgressionGate.UpgradeReason(live, machine, live.Machines))) {
				continue;
			}
			const cost = K.Economy.MachineCost(id, level);
			if (truthy(K.Economy.Gt(cost, cash))) {
				continue;
			}
			if (cheapest === undefined || truthy(K.Economy.Lt(cost, cheapestCost))) {
				cheapest = id;
				cheapestCost = cost;
			}
		}
		const items = live.Items as Dict;
		const busy = new Set<unknown>();
		for (const [, uid] of pairs(items.Equipped as Dict)) busy.add(uid);
		const commons: { Uid: string; At: number }[] = [];
		for (const [uid, instance] of pairs(items.Inventory as Dict)) {
			const inst = instance as Dict;
			const definition = itemById[inst.DefinitionId as string] as Dict | undefined;
			if (definition !== undefined && definition.Rarity === "Common" && inst.Locked !== true && !busy.has(uid)) {
				commons.push({ Uid: uid as string, At: (num(inst.AcquiredAt) ?? 0) as number });
			}
		}
		const quote = svc._rebirthPublic(live, now);
		const runs = quote.Runs as Array<{ Cores?: unknown }> | undefined;
		const last = runs !== undefined && runs.size() > 0 ? runs[runs.size() - 1] : undefined;
		const steps = ForgeProgramsService.Due(live as Dict, runtime as Dict, {
			Now: now,
			Rebirths: (num(live.Rebirths) ?? 0) as number,
			RebirthReady: quote.Ready === true,
			RebirthCores: K.Economy.AsNumber(quote.Cores) as number,
			LastRunCores: last !== undefined ? (K.Economy.AsNumber(last.Cores ?? 0) as number) : 0,
			CheapestAffordable: cheapest,
			CommonCount: commons.size(),
		});
		let changed = false;
		for (const step of steps) {
			let result: Response | undefined;
			if (step.Do === "BuyCheapestMachine" && cheapest !== undefined) {
				result = svc._buyMachine(player, cheapest, 1);
			} else if (step.Do === "Rebirth") {
				result = svc._rebirth(player, {});
			} else if (step.Do === "SalvageCommons") {
				// the oldest commons go first, down to the number the rule keeps
				commons.sort((a, b) => (a.At !== b.At ? a.At < b.At : a.Uid < b.Uid));
				const uids: string[] = [];
				for (let i = 0; i < math.min(48, commons.size() - (step.Arg ?? 50)); i++) uids.push(commons[i].Uid);
				if (uids.size() > 0) result = svc._bulkSalvageItems(player, uids);
			} else if (step.Do === "EquipBest") {
				result = svc._equipBestItems(player);
			}
			changed = changed || (result !== undefined && truthy(result.ok));
		}
		if (changed) {
			svc._queueStatePush(player);
		}
}

export function tickAutoForge(svc: GameService, player: Player) {
		const live = svc._data.Get(player) as Profile | undefined;
		const queue = live ? live.AutoForge : undefined;
		if (!live || !isTable(queue) || queue.Enabled !== true) {
			return;
		}
		const machineFound = K.Economy.GetMachine(queue.MachineId);
		if (!truthy(machineFound)) {
			return;
		}
		const machine = machineFound as Dict;
		const machineId = machine.Id as string;
		const maxLevel = machine.MaxLevel as number;
		const level = orElse((live.Machines as Dict)[machineId], () => 0) as number;
		const reserve = math.clamp(num(queue.Reserve) ?? 0.25, 0, 0.9);
		if (level < maxLevel) {
			const lockReason = K.ProgressionGate.UpgradeReason(live, machine, live.Machines);
			const cost = K.Economy.MachineCost(machineId, level);
			if (truthy(lockReason) || truthy(K.Economy.Gt(cost, K.Economy.Mul(live.Cash, 1 - reserve)))) {
				return;
			}
		}

		const [ok, result] = svc._data.AtomicUpdate(
			player,
			(profile: Profile) => {
				const current = profile.AutoForge;
				if (!isTable(current) || current.Enabled !== true || current.MachineId !== machineId) {
					return responseError(T("GameService.AutoForgeChangedBeforePurchase"));
				}
				const machines = profile.Machines as Dict;
				const currentLevel = orElse(machines[machineId], () => 0) as number;
				if (currentLevel >= maxLevel) {
					current.Enabled = false;
					return responseSuccess(T("GameService.AutoForgePausedAtMaximum"));
				}
				if (truthy(K.ProgressionGate.UpgradeReason(profile, machine, profile.Machines))) {
					return responseError(T("GameService.AutoForgeTargetIsStill"));
				}
				const currentReserve = math.clamp(num(current.Reserve) ?? 0.25, 0, 0.9);
				const remaining = maxLevel - currentLevel;
				const spendable = K.Economy.Mul(profile.Cash, 1 - currentReserve);
				const [count, cost] = K.Economy.AffordableMachineLevels(machineId, currentLevel, spendable, remaining) as LuaTuple<[number, unknown]>;
				if (count < 1) {
					return responseError(T("GameService.AutoForgeIsPreservingIts"));
				}
				profile.Cash = K.Economy.Sub(profile.Cash, cost);
				machines[machineId] = currentLevel + count;
				bumpStat(profile, "MachinesBought", count);
				current.Bought = math.max(0, math.floor(num(current.Bought) ?? 0)) + count;
				K.LabService.Progress(profile, "BuyLevels", count);
				const mastery = ensureCommandMastery(profile);
				mastery[machineId] = (num(mastery[machineId]) ?? 0) + count;
				K.ProgressionService.Progress(profile, "BuyMachine", count);
				K.ProgressionService.AwardCommandXP(profile, count * 5);
				K.ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12));
				enforceUnlimitedMoney(profile);
				svc._antiCheat.Observe(player, "AutoForge", profile);
				return responseSuccess(count === 1 ? T("GameService.AutoForgeBoughtAMachine") : T("GameService.AutoForgeBoughtDMachine", count));
			},
			true,
			"auto-forge",
		) as LuaTuple<[unknown, unknown]>;
		if (truthy(ok) && isTable(result) && result.ok === true) {
			svc._queueStatePush(player);
		}
}
