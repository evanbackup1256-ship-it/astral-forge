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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function overcharge(svc: GameService, player: Player) {
		const runtime = svc._runtime.get(player);
		if (!runtime) {
			return responseError(T("GameService.ShopSStillLoading"));
		}
		const profileForCombo = svc._data.Get(player);
		const nowClock = os.clock();
		if (nowClock - (runtime.LastTap as number) < 0.06) {
			return responseError(T("GameService.OverchargeIsCoolingDown"));
		}
		let previousCombo = math.max(0, math.floor(num(runtime.TapCombo) ?? 0));
		if (
			nowClock - (runtime.LastTap as number) >
			overchargeComboWindow(profileForCombo) * (svc._events.ComboWindowMultiplier() as number)
		) {
			previousCombo = 0;
		}
		const combo = math.min(OVERCHARGE_COMBO_MAX, previousCombo + 1);
		const comboMultiplier = overchargeComboMultiplier(profileForCombo, combo);
		runtime.LastTap = nowClock;
		runtime.TapCombo = combo;

		const result = svc._mutate(
			player,
			(profile: Profile) => {
				const capacity = K.Economy.Capacity(profile);
				const room = K.Economy.Sub(capacity, profile.Vault);
				if (truthy(K.Economy.Lte(room, 0.01))) {
					return responseError(T("GameService.YourVaultIsFullBank"));
				}
				const critical = svc._random.NextNumber() <= (K.Economy.CriticalChance(profile) as number) + (svc._events.CritBonus() as number);
				let amount = K.Economy.TapPower(profile);
				const eventTap = svc._events.TapMultiplier();
				if (eventTap !== 1) {
					amount = K.Economy.Mul(amount, eventTap);
				}
				if (critical) {
					amount = K.Economy.Mul(amount, K.Economy.CriticalMultiplier(profile));
				}
				if (comboMultiplier > 1) {
					amount = K.Economy.Mul(amount, comboMultiplier);
				}
				amount = K.Economy.Min(room, amount);
				profile.Vault = K.Economy.Add(profile.Vault, amount);
				bumpStat(profile, "Taps", 1);
				K.LabService.Progress(profile, "Tap", 1);
				K.ProgressionService.Progress(profile, "Tap", 1);
				K.ProgressionService.AwardCommandXP(profile, 1);
				K.ForgeEchoService.Record(profile, "Surge", 1);
				return responseSuccess(undefined, {
					Amount: amount,
					Critical: critical,
					Combo: combo,
					ComboMultiplier: comboMultiplier,
					ComboMax: OVERCHARGE_COMBO_MAX,
					ComboWindow: overchargeComboWindow(profile) * (svc._events.ComboWindowMultiplier() as number),
				});
			},
			false,
			"overcharge",
		);
		if (truthy(result.ok)) {
			svc._events.OnTap(player);
			svc._effect.fire(player, {
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
