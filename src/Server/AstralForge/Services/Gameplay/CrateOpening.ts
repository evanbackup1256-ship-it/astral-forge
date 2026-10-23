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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function openItemCrate(svc: GameService, player: Player, crateId: unknown, rawCount: unknown) {
		if (HotFlags.Get("CratesPaused")) {
			return responseError(T("GameService.CrateDecodingIsPausedFor"));
		}
		if (!typeIs(crateId, "string") || crateById[crateId] === undefined) {
			return responseError(T("GameService.ThatCrateChannelDoesNot"));
		}
		const [count, countError] = K.CrateRoll.NormalizeOpenCount(rawCount) as LuaTuple<[number | undefined, unknown]>;
		if (count === undefined) {
			return responseError(truthy(countError) ? countError : T("GameService.CratesCanBeOpenedOne"));
		}
		const crate = crateById[crateId] as Dict;
		return svc._mutate(player, (profile: Profile) => {
			const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
			const keys = items.Keys as Dict;
			if (((keys[crateId] as number | undefined) ?? 0) < count) {
				return responseError(
					T("GameService.YouNeedDMoreS", count - ((keys[crateId] as number | undefined) ?? 0), crate.Name as string),
				);
			}
			const autoRules = ensureAutoSalvage(profile) as Dict;
			const ownedPasses = profile.OwnedPasses as Dict | undefined;
			const autoEnabled = autoRules.Enabled === true && ownedPasses !== undefined && ownedPasses.AutoSalvage === true;

			const guaranteedRecycle = K.CrateRoll.GuaranteedRecycle(crate.Weights, autoEnabled, autoRules.KeepNew, autoRules.Rarities);
			const requiredSlots = K.CrateRoll.RequiredSlots(count, guaranteedRecycle) as number;
			if ((inventoryCount(profile) as number) + requiredSlots > (K.GameConfig.Items.InventoryLimit as number)) {
				return responseError(T("GameService.YourItemInventoryDoesNot"));
			}
			keys[crateId] = (keys[crateId] as number) - count;
			const rolls: Dict[] = [];
			const cosmetics = K.ProfileBagMath.EnsureCosmetics(profile) as Dict;
			const shopCatalog = K.SharedDataSuite("ShopCatalog") as Kit;
			const equippedSkin = shopCatalog.skin(cosmetics.CrateSkin) as Dict | undefined;
			const pityStep = K.CrateExpansion.pityStep(cosmetics, equippedSkin) as number;
			const rarities = autoRules.Rarities as Dict;
			const pityBag = items.Pity as Dict;
			for (let index = 0; index < count; index++) {
				const pity = (pityBag[crateId] as number | undefined) ?? 0;
				const [definition, rarity, pityHit] = svc._rollItemDefinition(crate, pity) as LuaTuple<[Dict | undefined, string, unknown]>;
				if (definition === undefined) {
					return responseError(T("GameService.ThatCrateHasNoValid"));
				}
				if (!typeIs(items.Discovered, "table")) {
					items.Discovered = {};
				}
				const discovered = items.Discovered as Dict;
				const wasOwned = discovered[definition.Id as string] === true;
				const shouldAutoSalvage = autoEnabled && rarities[rarity] === true && !(autoRules.KeepNew !== false && !wasOwned);
				let uid: string | undefined;
				let autoEssence = 0;
				if (shouldAutoSalvage) {
					autoEssence = K.CrateExpansion.salvageEssence(
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
					uid = svc._createItem(profile, definition.Id as string);
					if (uid === undefined) {
						return responseError(T("GameService.TheCrateDecoderRanOut"));
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
			const skinBonus = K.CrateExpansion.openBonus(cosmetics, equippedSkin, count) as number;
			items.Essence = (items.Essence as number) + skinBonus;
			bumpStat(profile, "CratesOpened", count);
			K.LabService.Progress(profile, "OpenCrate", count);
			return responseSuccess(T("GameService.DecodedDSS", count, crate.Name as string, count === 1 ? "" : "s"), {
				Rolls: rolls,
				CrateId: crateId,
				Pity: pityBag[crateId],
				SkinEssence: skinBonus,
			});
		});
}
