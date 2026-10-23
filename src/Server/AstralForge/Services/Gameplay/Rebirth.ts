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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function rebirth(svc: GameService, player: Player, rawPayload: unknown) {
		const payload = (typeIs(rawPayload, "table") ? rawPayload : {}) as Dict;
		const result = svc._mutate(player, (profile: Profile) => {
			const now = os.time();
			const rebirthConfig = (K.GameConfig.Economy.Rebirth as Dict | undefined) ?? ({} as Dict);
			const ledger = rebirthLedger(profile, now);
			const [run, bank] = rebirthRun(profile, now, ledger) as LuaTuple<[Dict, unknown]>;
			const [baseReward, stardustBase] = rebirthBase(profile, bank) as LuaTuple<[unknown, number]>;
			if (baseReward === undefined) {
				return responseError(T("GameService.BankAtLeastSRun", (K.Format.Number as Fn)(K.Economy.PrestigeRequirementFor(num(profile.Rebirths) ?? 0))));
			}
			if (payload.Keep !== undefined) {
				K.RebirthMath.setKeep(ledger, payload.Keep);
			}
			const quote = K.RebirthMath.quote(
				ledger,
				{
					Cores: K.Economy.AsNumber(baseReward),
					Stardust: stardustBase,
				},
				run,
			) as Dict;
			const reward = K.Economy.Max(1, K.Economy.Floor(K.Economy.Mul(baseReward, quote.CoreMultiplier)));
			const stardustReward = quote.Stardust as number;
			const bankedVault = profile.Vault;
			const multiplierBefore = K.Economy.PermanentMultiplier(profile);
			// cores are capped at 1e14 like Stardust (DataService clamps on load and save)
			profile.Cores = math.clamp((num(profile.Cores) ?? 0) + math.max(0, (K.Economy.AsNumber(reward) as number)), 0, 1e14);
			profile.Stardust = math.clamp((tonumber(profile.Stardust) ?? 0) + stardustReward, 0, 1e14);
			if (!typeIs(profile.BoostInventory, "table")) {
				profile.BoostInventory = {};
			}
			const boostInventory = profile.BoostInventory as Dict;
			const celebrationBoost = (rebirthConfig.CelebrationBoostId as string | undefined) ?? "Overdrive";
			const bonusCount = math.max(0, math.floor(tonumber(rebirthConfig.BonusOverdrive) ?? 1));
			if (bonusCount > 0 && truthy(K.GameConfig.Boosts[celebrationBoost])) {
				boostInventory[celebrationBoost] = ((boostInventory[celebrationBoost] as number | undefined) ?? 0) + bonusCount;
			}
			const carry = K.RebirthMath.carry(
				ledger,
				profile.Machines,
				K.Economy.AsNumber(profile.Vault),
				K.GameConfig.Economy.StartingCash,
				keepsakeAllowed(profile),
			) as Dict;
			const entry = K.RebirthMath.close(ledger, quote, now, typeIs(payload.Vow, "string") ? payload.Vow : undefined, undefined) as Dict;
			// BALANCE v8: a run shorter than MinCountedRunSeconds pays out but doesn't move the rebirth count
			const minCounted = num(rebirthConfig.MinCountedRunSeconds) ?? 0;
			const counted = (num(run.Seconds) ?? 0) >= minCounted;
			if (counted) {
				profile.Rebirths = (profile.Rebirths as number) + 1;
			}
			ResetSpec.applyReset(ResetSpec.Rebirth, profile as Dict, resetContext(carry));
			const vow = K.RebirthMath.vow(quote.Vow) as Dict | undefined;
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
					(K.Format.Number as Fn)(reward) +
					" cores, +" +
					(K.Format.Number as Fn)(stardustReward) +
					" Stardust." +
					vowLine,
				{
					Rebirths: profile.Rebirths,
					MultiplierBefore: multiplierBefore,
					MultiplierAfter: K.Economy.PermanentMultiplier(profile),
					Reward: reward,
					StardustReward: stardustReward,
					BankedVault: bankedVault,
					CelebrationBoost: bonusCount > 0 ? celebrationBoost : undefined,
					NextTarget: K.Economy.PrestigeRequirementFor(num(profile.Rebirths) ?? 0),
					Counted: counted,
					Grade: quote.Grade,
					Vow: quote.Vow,
					VowKept: quote.Kept,
					Seconds: entry.Seconds,
					Carried: carry.Machines,
					NextVow: ledger.Vow,
					StarLit: (K.RebirthMath.pendingStars(ledger) as unknown[]).size() > 0,
				},
			);
		});
		if (truthy(result.ok)) {
			svc._effect.broadcast({
				Type: "Rebirth",
				UserId: player.UserId,
				Position: svc._world.GetPlotPosition(player),
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
