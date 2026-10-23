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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function snapshot(svc: GameService, player: Player): Dict | undefined {
		let profile = svc._data.Get(player) as Profile | undefined;
		const runtime = svc._runtime.get(player);
		if (!profile) {
			return undefined;
		}
		if (
			(!runtime || os.clock() >= ((runtime.BazaarRecoveryRetryAt as number | undefined) ?? 0)) &&
			truthy(K.BazaarService.NeedsRecovery(profile, player.UserId))
		) {
			const recovered = svc._mutate(player, (draft: Profile) => {
				const [ok, message] = K.BazaarService.Roll(draft, os.time(), player.UserId) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
			if (!truthy(recovered.ok)) {
				if (runtime) {
					runtime.BazaarRecoveryRetryAt = os.clock() + 30;
				}
				K.ModuleLog.Every(
					"legacy-refund:" + player.UserId,
					30,
					"BlackMarket",
					"Legacy refund could not be committed for " + player.UserId + ": " + tostring(recovered.error),
				);
			}
			profile = svc._data.Get(player) as Profile | undefined;
			if (!profile) {
				return undefined;
			}
		}
		const now = os.time();
		const baseProduction = K.Economy.Production(profile, now);
		const production = K.Economy.Mul(
			baseProduction,
			(svc._convergence.Multiplier() as number) *
				(svc._events.ProductionMultiplier() as number) *
				(svc._crews.Multiplier(player) as number),
		);
		const capacity = K.Economy.Capacity(profile, now);
		const prestigeReward = softCapCores(K.Economy.PrestigeReward(K.Economy.Add(profile.RunCash, profile.Vault), num(profile.Rebirths) ?? 0));
		const domain = orEmpty(profile.Domain, () => ({
			Rank: 0,
			Essence: 0,
			LastExpandedAt: 0,
			TotalRebirthsSpent: 0,
			TotalCoresSpent: 0,
		}));
		const domainRank = math.max(0, math.floor(num(domain.Rank) ?? 0));
		const [domainRequiredRebirths, domainRequiredCores] = K.Economy.DomainRequirements(domainRank) as LuaTuple<[unknown, unknown]>;
		const [domainEssenceReward, domainStardustReward] = K.Economy.DomainRewards(domainRank) as LuaTuple<[unknown, unknown]>;
		const continuum = orEmpty(profile.Continuum, () => ({ Rank: 0, TotalFluxSpent: 0, TotalStardustSpent: 0 }));
		const continuumRank = math.max(0, math.floor(num(continuum.Rank) ?? 0));
		const [continuumFluxCost, continuumStardustCost] = K.Economy.ContinuumCosts(continuumRank) as LuaTuple<[unknown, unknown]>;
		const [continuumProduction, continuumCapacity, continuumTap, continuumOffline] = K.Economy.ContinuumEffects(profile) as LuaTuple<
			[unknown, unknown, unknown, unknown]
		>;
		if (runtime) {
			runtime.SnapshotId = ((runtime.SnapshotId as number | undefined) ?? 0) + 1;
		}
		const itemShop: Record<number, unknown> = {};
		ensureItemShop(profile);
		const items = profile.Items as Dict;
		(K.GameConfig.Items.ShopOffers as Dict[]).forEach((offer, i) => {
			const state = copyDictionary(offer) as Dict;
			const stockMax = offerStockMax(offer);
			const stock = K.ShopGrantEligibility.RemainingStock(((items.Shop as Dict).Stock as Dict)[offer.Id as string], stockMax) as number;
			state.Stock = stock;
			state.StockMax = stockMax;
			state.DailyRefresh = offer.DailyRefresh === true;
			state.Purchased = stock <= 0;
			itemShop[i + 1] = state;
		});
		const featureUnlocks = K.ProgressionGate.FeatureStates(profile) as Record<string, Dict>;
		const levelState = K.ProgressionGate.LevelState(profile) as Dict;
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
			const leveledUp = runtime.ForgeLevel !== undefined && (levelState.Level as number) > (runtime.ForgeLevel as number);
			runtime.ForgeLevel = levelState.Level;
			if (leveledUp) {
				const names: string[] = [];
				for (const entry of newlyUnlocked) {
					names.push(entry.State.Name as string);
				}
				table.sort(names);
				// the milestone card on the client names what opened and what it paid; no toast on top
				svc._effect.fire(player, {
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
				svc._toastPlayer(
					player,
					single ? (single.State.Name as string) + " unlocked" : T("GameService.NewSystemsUnlocked"),
					single ? T("GameService.YouCanOpenItFrom") : names.join(", ") + " are ready in the Forge menu.",
					"Special",
				);
				svc._effect.fire(player, {
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
		levelState.Progression = svc._settleProgression(player, profile, levelState, production);
		const storyState = K.StoryMailSnapshot.BuildStory(profile, K.GameConfig.Story, K.ProgressionGate);
		const [mailState, unreadMail] = K.StoryMailSnapshot.BuildMailbox(profile, K.GameConfig.Mail, K.ProgressionGate) as LuaTuple<
			[unknown, unknown]
		>;
		const guildMembership = profile.Guild as Dict | undefined;
		const guildId = (truthy(guildMembership) && truthy(guildMembership.Id) ? guildMembership.Id : "") as string;
		const guildCachedPublic = guildId !== "" ? svc._guilds.GetCachedPublic(guildId) : undefined;
		const guildSnapshot = K.GuildMath.SnapshotPublic(guildMembership, guildCachedPublic) as Dict | undefined;
		if (truthy(guildSnapshot) && guildId !== "") {
			guildSnapshot.Community = svc._guildCommunity.Snapshot(guildId);
		}
		const [overchargeCombo, overchargeMultiplier] = svc._overchargeCombo(runtime, profile);
		const sky = orEmpty(profile.Sky, () => ({}));
		const charts = orEmpty(sky.Charts, () => ({}));
		const cipher = orEmpty(sky.Cipher, () => ({}));
		const dailyShop = profile.DailyShop;
		const cosmetics = profile.Cosmetics;
		const meta = profile.Meta as Dict;
		const finalProfile = profile;

		return {
			Game: {
				Name: K.GameConfig.Game.Name,
				Version: K.GameConfig.Game.Version,
				Update: K.GameConfig.Game.Update,
			},
			Cash: profile.Cash,
			Vault: profile.Vault,
			Cores: profile.Cores,
			Stardust: profile.Stardust,
			Rebirths: profile.Rebirths,
			Domain: K.ContinuumDomainMath.SnapshotDomainPublic({
				domain: domain,
				rank: domainRank,
				requiredRebirths: domainRequiredRebirths,
				requiredCores: domainRequiredCores,
				essenceReward: domainEssenceReward,
				stardustReward: domainStardustReward,
				rebirths: profile.Rebirths,
				cores: profile.Cores,
				domainConfig: K.GameConfig.Domain,
				MeetsRequired: K.RebirthGate.MeetsRequired,
				Gte: K.Economy.Gte,
				DomainTreeBonus: (kind: unknown) => K.Economy.DomainTreeBonus(finalProfile, kind),
			}),
			Foundry: K.FoundryService.State(profile, Workspace.GetServerTimeNow()),
			Continuum: K.ContinuumDomainMath.SnapshotContinuumPublic({
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
				milestoneEvery: K.GameConfig.Continuum.MilestoneEvery,
				Gte: K.Economy.Gte,
			}),
			ForgeEchoes: K.ForgeEchoService.State(profile),
			ExpeditionBoard: ExpeditionBoardService.State(profile as Dict),
			ForgePrograms: ForgeProgramsService.State(profile as Dict),
			Ascension: svc._ascensionPublic(profile),
			RunCash: profile.RunCash,
			LifetimeCash: profile.LifetimeCash,
			Zone: profile.Zone,
			CurrentZone: profile.CurrentZone,
			Machines: copyDictionary(profile.Machines),
			Research: copyDictionary(profile.Research),
			GridUpgrades: copyDictionary(profile.GridUpgrades),
			Specialization: K.Specializations.Snapshot(profile, K.Economy, os.time(), runtime, {
				Production: baseProduction,
				Capacity: capacity,
			}),
			BoostInventory: copyDictionary(profile.BoostInventory),
			ActiveBoost: copyDictionary(profile.ActiveBoost),
			Quests: copyDictionary((profile.Quests as Dict).Items),
			Achievements: K.ProgressionService.AchievementStates(profile),
			Daily: K.ProgressionService.DailyState(profile),
			Wheel: K.ProgressionService.WheelState(profile),
			Bazaar: K.BazaarService.State(profile, os.time(), player.UserId),
			Sky: {
				Retired: true,
				Plotted: table.clone(orEmpty(charts.Plotted, () => ({}))),
				Cipher: {
					Solves: orElse(cipher.Solves, () => 0),
					Best: orElse(cipher.Best, () => 0),
				},
			},
			Command: K.ProgressionService.CommandState(profile),
			ForgePath: K.ProgressionService.ForgePathState(profile),
			TimedRewards: K.ProgressionService.TimedRewardState(profile),
			Items: {
				Inventory: copyDictionary(items.Inventory),
				Equipped: copyDictionary(items.Equipped),
				Essence: items.Essence,
				Keys: copyDictionary(items.Keys),
				Pity: copyDictionary(items.Pity),
				InventoryLimit: K.GameConfig.Items.InventoryLimit,
				Shop: itemShop,
				ShopRefreshAt: nextUtcMidnight(),
				AutoSalvage: K.AutoSalvageSnapshot.Public(items.AutoSalvage, copyDictionary),
				Effects: K.ItemLoadoutMath.EffectsPublic(profile, K.Economy),
				Discovered: copyDictionary(orElse(items.Discovered, () => ({}))),
				CodexBonus: K.Economy.CodexBonus(profile),
				Rigs: K.RelicRigs.Public(profile),
				Recipes: { ...RelicRecipes.ensure(items.Recipes, os.time()), Paused: HotFlags.Get("RecipesPaused") },
				EngravingPaused: HotFlags.Get("EngravingPaused"),
			},
			DailyShop: {
				Day: isTable(dailyShop) && truthy(dailyShop.Day) ? dailyShop.Day : -1,
				Bought: copyDictionary(isTable(dailyShop) && truthy(dailyShop.Bought) ? dailyShop.Bought : {}),
				Owned: isTable(dailyShop) && isTable(dailyShop.Owned) ? copyDictionary(dailyShop.Owned) : undefined,
			},
			Cosmetics: {
				CrateSkins: copyDictionary(isTable(cosmetics) && truthy(cosmetics.CrateSkins) ? cosmetics.CrateSkins : { Classic: true }),
				CrateSkin: isTable(cosmetics) && truthy(cosmetics.CrateSkin) ? cosmetics.CrateSkin : "Classic",
				ProfileAccent: ProfileStyle.read(cosmetics).Accent,
				ProfileFrame: ProfileStyle.read(cosmetics).Frame,
				// milestone counts the style picker shows unlocks against; the server re-checks on every pick
				Facts: ProfileStyle.factsOf(profile),
			},
			Anomaly: K.AnomalyService.State(profile),
			Lab: K.LabService.State(profile),
			Guild: guildSnapshot,
			GuildBonuses: copyDictionary(profile.GuildBonuses),
			SocialBoost: K.SocialBoost.PublicSnapshot(profile.SocialBoost, K.GameConfig.Social.MaxBoostedFriends, copyDictionary),
			SocialRewards: K.SocialBoost.CreatorRewardsPublic(profile.SocialRewards, K.ServerConfig.CreatorUsername),
			Community: CommunityRewards.publicState(profile.SocialRewards, communityConfig()),
			AutoForge: K.AutoSalvageSnapshot.PublicAutoForge(profile.AutoForge, copyDictionary),
			Trade: truthy(svc._trades) ? svc._trades.StatePublic(profile, player, now) : K.TradeDesk.LockedPublic(),
			Convergence: svc._convergence.State(player, profile),
			FeatureUnlocks: featureUnlocks,
			Level: levelState,
			Story: storyState,
			Mailbox: K.StoryMailSnapshot.MailboxPublic(mailState, unreadMail),
			LimitedEvent: limitedEventPublic(profile, now),
			Constellations: { ...Constellations.publicView(profile), Paused: HotFlags.Get("ConstellationsPaused") },
			WeeklyBoard: {
				Score: WeeklyBoard.scoreOf(profile, now),
				EndsAt: WeeklyBoard.weekEndsAt(WeeklyBoard.weekOf(now)),
			},
			Admin: orElse(svc._admin ? svc._admin.State(player) : undefined, () => ({ Access: false })),
			Settings: copyDictionary(profile.Settings),
			Flags: copyDictionary(profile.Flags),
			Stats: copyDictionary(profile.Stats),
			Shop: K.ShopGrantEligibility.CatalogPublic(profile.OwnedPasses, copyDictionary),
			Production: production,
			RawProduction: K.Economy.RawProduction(profile),
			Capacity: capacity,
			CapacitySeconds: K.Economy.CapacitySeconds(profile, now),
			SteadyProduction: K.Economy.SteadyProduction(profile, now),
			FluxSurge: orElse(svc._fluxSurge ? svc._fluxSurge.State(now) : undefined, () => FluxSurgeService.IdleState()),
			ServerEvent: svc._events.State(player),
			PermanentMultiplier: K.Economy.PermanentMultiplier(profile),
			AutoCollectRate: K.Economy.AutoCollectRate(profile),
			OfflineHours: K.Economy.OfflineHours(profile),
			OfflineEfficiency: K.Economy.OfflineEfficiency(profile),
			TapPower: K.Economy.TapPower(profile, now),
			CriticalChance: K.Economy.CriticalChance(profile),
			CriticalMultiplier: K.Economy.CriticalMultiplier(profile),
			Overcharge: K.OverchargeCombo.PublicSnapshot({
				combo: overchargeCombo,
				comboMultiplier: overchargeMultiplier,
				comboMax: K.GameConfig.Overcharge.ComboMax,
				comboWindow: overchargeComboWindow(profile),
				comboBonusPerStack: K.GameConfig.Overcharge.ComboBonusPerStack,
			}),
			PrestigeReward: prestigeReward,
			NextPrestigeTarget: K.Economy.NextPrestigeTarget(K.Economy.PrestigeReward(K.Economy.Add(profile.RunCash, profile.Vault), num(profile.Rebirths) ?? 0), num(profile.Rebirths) ?? 0),
			Rebirth: svc._rebirthPublic(profile, now),
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
			Offline: K.OfflineProjection.PublicSnapshot({
				runtime: runtime,
				production: production,
				vault: profile.Vault,
				offlineHours: K.Economy.OfflineHours(profile),
			}),
			Visitors: svc._visitorList(player),
			Visit: K.VisitSnapshot.Resolve(svc._visiting.get(player), Players.GetPlayers(), (host: Player) => svc._data.Get(host), K.Economy),
		};
}
