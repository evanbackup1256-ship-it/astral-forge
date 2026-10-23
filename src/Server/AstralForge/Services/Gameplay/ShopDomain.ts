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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function buyDailyOffer(svc: GameService, player: Player, slot: unknown) {
		if (!typeIs(slot, "number") || slot !== slot) {
			return responseError(T("GameService.ThatDailyOfferDoesNot"));
		}
		const [ShopCatalog] = shopShared();
		const now = os.time();
		const day = ShopCatalog.day(now);
		const policy = PolicyGate.Get(player);
		return svc._mutate(player, (profile: Profile) => {
			const cosmetics = K.ProfileBagMath.EnsureCosmetics(profile, (id: unknown) => ShopCatalog.skin(id) !== undefined) as Dict;
			const shop = K.ProfileBagMath.EnsureDailyShop(profile, day, cosmetics.CrateSkins) as Dict;
			const offers = ShopCatalog.roll(player.UserId, day, shop.Owned) as Dict[];
			const offer = offers[math.floor(slot) - 1];
			if (offer === undefined) {
				return responseError(T("GameService.ThatDailyOfferDoesNot"));
			}
			const policyNote = PlayPolicy.offerBlocked(policy, offer);
			if (policyNote !== undefined) {
				return responseError(policyNote);
			}
			const bought = shop.Bought as Dict;
			if ((ShopCatalog.remaining(offer, bought) as number) <= 0) {
				return responseError(T("GameService.YouVeBoughtAllOf"));
			}
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (offer.Kind === "Skin" && crateSkins[offer.SkinId as string] === true) {
				return responseError(T("GameService.YouAlreadyOwnThatSkin"));
			}
			if (offer.Kind === "Cache" && (inventoryCount(profile) as number) >= (K.GameConfig.Items.InventoryLimit as number)) {
				return responseError(T("GameService.YourRelicInventoryIsFull"));
			}
			const denied = spendShopCurrency(profile, offer.Currency as string, offer.Price as number);
			if (denied !== undefined) {
				return responseError(denied);
			}
			const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
			const keys = items.Keys as Dict;
			const detail: Dict = { Slot: offer.Slot, Kind: offer.Kind };
			if (offer.Kind === "Key") {
				keys[offer.CrateId as string] = ((keys[offer.CrateId as string] as number | undefined) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Essence") {
				items.Essence = (items.Essence as number) + (offer.Amount as number);
			} else if (offer.Kind === "Boost") {
				const inventory = ensureBoostInventory(profile) as Dict;
				inventory[offer.BoostId as string] = math.floor(tonumber(inventory[offer.BoostId as string]) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Flux") {
				const generated = K.Economy.Max(500, K.Economy.Mul(K.Economy.SteadyProduction(profile), 60 * (offer.Minutes as number)));
				profile.Cash = K.Economy.Add(profile.Cash, generated);
				profile.RunCash = K.Economy.Add(profile.RunCash, generated);
				profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, generated);
			} else if (offer.Kind === "Skin") {
				crateSkins[offer.SkinId as string] = true;
			} else if (offer.Kind === "Cache") {
				const candidates = RelicModel.definitionsOfRarity(offer.Rarity) as unknown as Dict[];
				if (candidates.size() === 0) {
					return responseError(T("GameService.ThatCacheIsEmpty"));
				}
				const definition = candidates[svc._random.NextInteger(0, candidates.size() - 1)];
				const discovered = typeIs(items.Discovered, "table") ? (items.Discovered as Dict) : ({} as Dict);
				const wasOwned = discovered[definition.Id as string] === true;
				const uid = svc._createItem(profile, definition.Id as string);
				if (uid === undefined) {
					return responseError(T("GameService.YourRelicInventoryIsFull"));
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
				return responseError(T("GameService.ThatOfferIsMisconfigured"));
			}
			const key = tostring(offer.Slot);
			bought[key] = ((bought[key] as number | undefined) ?? 0) + 1;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((offer.Name as string) + " bought.", detail);
		});
}
