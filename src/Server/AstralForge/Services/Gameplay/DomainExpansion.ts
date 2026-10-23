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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function domainExpansion(svc: GameService, player: Player) {
		let details: Dict | undefined;
		const result = svc._mutate(player, (profile: Profile) => {
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
			const expansion = ((K.GameConfig.Domain as Dict).Expansion as Dict | undefined) ?? ({} as Dict);
			const cooldown = math.max(1, math.floor(tonumber(expansion.CooldownSeconds) ?? 6));
			const rank = math.max(0, math.floor(tonumber(domain.Rank) ?? 0));
			if (os.time() - math.max(0, math.floor(tonumber(domain.LastExpandedAt) ?? 0)) < cooldown) {
				return responseError(T("GameService.RealityIsStillSettling"));
			}
			const [requiredRebirths, requiredCores] = K.Economy.DomainRequirements(rank) as LuaTuple<[number, number]>;
			if (!truthy(K.RebirthGate.MeetsRequired(profile.Rebirths, requiredRebirths))) {
				return responseError(T("GameService.DomainRankDRequiresD", rank + 1, requiredRebirths));
			}
			if ((profile.Cores as number) < requiredCores) {
				return responseError(T("GameService.DomainRankDRequiresD2", rank + 1, requiredCores));
			}

			const [baseEssence, baseStardust] = K.Economy.DomainRewards(rank) as LuaTuple<[number, number]>;
			let essenceReward = baseEssence;
			const spentRebirths = profile.Rebirths as number;
			const spentCores = profile.Cores as number;
			const overflowRebirths = math.max(0, spentRebirths - requiredRebirths);
			const overflowCores = math.max(0, spentCores - requiredCores);
			const overflowRebirthScale = tonumber(expansion.OverflowRebirthScale) ?? 18;
			const overflowCoreScale = tonumber(expansion.OverflowCoreSqrtScale) ?? 6;
			const overflowReward = math.floor(overflowRebirths * overflowRebirthScale + math.sqrt(overflowCores) * overflowCoreScale);
			const nextRank = rank + 1;
			domain.Rank = nextRank;
			if (!typeIs(domain.Links, "table")) {
				domain.Links = {};
			}
			domain.SkillPoints =
				math.max(0, math.floor(tonumber(domain.SkillPoints) ?? 0)) +
				(((K.GameConfig.Domain as Dict).SkillPointPerRank as number | undefined) ?? 2);
			essenceReward += K.Economy.DomainTreeBonus(profile, "EssenceGain") as number;
			essenceReward = math.floor(
				math.min(1e300, essenceReward * math.max(1, K.Economy.AsNumber(K.Economy.AscensionEffect(profile, "Essence") as number) as number)),
			);
			domain.Essence = math.max(0, math.floor(tonumber(domain.Essence) ?? 0)) + essenceReward;
			domain.LastExpandedAt = os.time();
			domain.TotalRebirthsSpent = math.max(0, math.floor(tonumber(domain.TotalRebirthsSpent) ?? 0)) + spentRebirths;
			domain.TotalCoresSpent = math.max(0, math.floor(tonumber(domain.TotalCoresSpent) ?? 0)) + spentCores;

			K.ForgeEchoService.Record(profile, "Explore", 14);

			profile.Cash = K.GameConfig.Economy.StartingCash;
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
					Production: ((K.GameConfig.Lab as unknown as Dict).Power as Dict).BaseCells,
					Storage: 0,
					Tap: 0,
				};
			}

			const stardustReward = baseStardust + overflowReward;
			profile.Stardust = math.clamp((tonumber(profile.Stardust) ?? 0) + stardustReward, 0, 1e14);
			const freeSpins = math.max(0, math.floor(tonumber(expansion.FreeSpins) ?? 3));
			const wheel = profile.Wheel as Dict;
			wheel.FreeSpins = ((wheel.FreeSpins as number | undefined) ?? 0) + freeSpins;
			const bonusBoostId = (expansion.BonusBoostId as string | undefined) ?? (K.GameConfig.Domain as Dict).SurgeBoostId;
			const bonusBoostCount = math.max(1, math.floor(tonumber(expansion.BonusBoostCount) ?? 1));
			const boostInventory = profile.BoostInventory as Dict;
			if (truthy(K.GameConfig.Boosts[bonusBoostId as string])) {
				boostInventory[bonusBoostId as string] = ((boostInventory[bonusBoostId as string] as number | undefined) ?? 0) + bonusBoostCount;
			}
			boostInventory.Hyperdrive = ((boostInventory.Hyperdrive as number | undefined) ?? 0) + 2;
			boostInventory.Overdrive = ((boostInventory.Overdrive as number | undefined) ?? 0) + 3;
			boostInventory.VaultSurge = ((boostInventory.VaultSurge as number | undefined) ?? 0) + 2;
			const surge = K.GameConfig.Boosts[(K.GameConfig.Domain as Dict).SurgeBoostId as string] as Dict;
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
			const [nextRequiredRebirths, nextRequiredCores] = K.Economy.DomainRequirements(nextRank) as LuaTuple<[number, number]>;
			details.NextRequiredRebirths = nextRequiredRebirths;
			details.NextRequiredCores = nextRequiredCores;
			return responseSuccess(T("GameService.DomainDEstablishedRealityNow", nextRank), details);
		});
		if (truthy(result.ok)) {
			svc._effect.broadcast({
				Type: "DomainExpansion",
				UserId: player.UserId,
				Rank: details !== undefined ? details.DomainRank : 0,
				Position: svc._world.GetPlotPosition(player),
			});
		}
		return result;
}
