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
import * as Automation from "./Automation";
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function guildAction(svc: GameService, player: Player, action: string, rawPayload: unknown) {
		let payload = (typeIs(rawPayload, "table") ? rawPayload : {}) as Dict;
		if (
			action === K.Protocol.Actions.SendGuildChat ||
			action === K.Protocol.Actions.GetGuildChatHistory ||
			action === K.Protocol.Actions.GetGuildAnnouncements ||
			action === K.Protocol.Actions.GetGuildSettings ||
			action === K.Protocol.Actions.GetGuildLogoReview ||
			action === K.Protocol.Actions.SetGuildSettings ||
			action === K.Protocol.Actions.CreateGuildAnnouncement ||
			action === K.Protocol.Actions.EditGuildAnnouncement ||
			action === K.Protocol.Actions.PinGuildAnnouncement ||
			action === K.Protocol.Actions.ArchiveGuildAnnouncement ||
			action === K.Protocol.Actions.SetGuildAnnouncementExpiry ||
			action === K.Protocol.Actions.MuteGuildMember ||
			action === K.Protocol.Actions.UnmuteGuildMember ||
			action === K.Protocol.Actions.BanGuildMember ||
			action === K.Protocol.Actions.UnbanGuildMember ||
			action === K.Protocol.Actions.UploadGuildLogo ||
			action === K.Protocol.Actions.ModerateGuildLogo
		) {
			return svc._guildCommunity.Handle(player, action, payload);
		}

		if (
			action === K.Protocol.Actions.KickGuildMember ||
			action === K.Protocol.Actions.SetGuildRole ||
			action === K.Protocol.Actions.BuyGuildUpgrade
		) {
			const profile = svc._data.Get(player) as Profile | undefined;
			if (profile === undefined) {
				return responseError(T("GuildCommunity.YourProfileIsNotReady"));
			}
			let ok: unknown;
			let message: unknown;
			let guild: unknown;
			let previousActivity = 0;
			if (action === K.Protocol.Actions.BuyGuildUpgrade) {
				const before = svc._guilds.GetCachedPublic(typeIs(profile.Guild, "table") ? (profile.Guild as Dict).Id : "") as Dict | undefined;
				previousActivity = before !== undefined ? (tonumber(before.Activity) ?? 0) : 0;
			}
			if (action === K.Protocol.Actions.KickGuildMember) {
				const [kicked, kickMessage, kickGuild] = svc._guilds.Kick(player, profile, payload.UserId ?? payload.Id) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = kicked;
				message = kickMessage;
				guild = kickGuild;
				if (truthy(ok)) {
					const target = Players.GetPlayerByUserId(tonumber(payload.UserId ?? payload.Id) ?? 0);
					if (target !== undefined) {
						svc._data.AtomicUpdate(
							target,
							(victimProfile: Profile) => {
								victimProfile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
								victimProfile.GuildBonuses = emptyBonuses();
								return { ok: true };
							},
							true,
							"guild-kick",
						);
						svc._pushState(target);
					}
				}
			} else if (action === K.Protocol.Actions.SetGuildRole) {
				const [setOk, setMessage, setGuild] = svc._guilds.SetRole(player, profile, payload.UserId ?? payload.Id, payload.Role) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = setOk;
				message = setMessage;
				guild = setGuild;
			} else {
				const [buyOk, buyMessage, buyGuild] = svc._guilds.BuyUpgrade(player, profile, payload.Id) as LuaTuple<[unknown, unknown, unknown]>;
				ok = buyOk;
				message = buyMessage;
				guild = buyGuild;
			}
			if (!truthy(ok)) {
				return responseError(message);
			}
			if (action === K.Protocol.Actions.BuyGuildUpgrade) {
				const expectedGuildId = typeIs(profile.Guild, "table") ? ((profile.Guild as Dict).Id as string) : "";
				const bonuses = svc._guilds.GetCachedBonuses(expectedGuildId);
				svc._data.AtomicUpdate(
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
				const definition = (K.GameConfig.Guild as Dict).Upgrades as Dict;
				const upgradeDef = definition[payload.Id as string] as Dict | undefined;
				const upgradeName = upgradeDef !== undefined ? (upgradeDef.Name as string) : "a hall upgrade";
				const guildBag = guild as Dict | undefined;
				const level =
					guildBag !== undefined && typeIs(guildBag.Upgrades, "table")
						? tonumber((guildBag.Upgrades as Dict)[payload.Id as string])
						: undefined;
				svc._toastGuild(
					expectedGuildId,
					"Guild upgrade",
					level !== undefined
						? string.format("Your guild unlocked %s (level %d)!", upgradeName, level)
						: string.format("Guild unlocked %s.", upgradeName),
					"Special",
				);
				svc._announceGuildActivity(expectedGuildId, previousActivity, guild);
			}
			return responseSuccess(message, { Guild: guild });
		}
		if (action === K.Protocol.Actions.CreateGuild || action === K.Protocol.Actions.RenameGuild) {
			const rawName = typeIs(payload.Name, "string") ? payload.Name : "";
			const [filteredOk, filtered] = (svc._security.Filter as Svc).Apply(player, rawName, player.UserId, 28) as LuaTuple<
				[unknown, unknown]
			>;
			if (!truthy(filteredOk) || !typeIs(filtered, "string") || filtered.size() < 3) {
				return responseError(T("GameService.ThatGuildNameCouldnT"));
			}
			payload = table.clone(payload) as Dict;
			payload.Name = filtered;
		}
		let contributeActivity = 0;
		let contributeGuildId = "";
		if (action === K.Protocol.Actions.ContributeGuild) {
			const existing = svc._data.Get(player) as Profile | undefined;
			contributeGuildId = existing !== undefined && typeIs(existing.Guild, "table") ? ((existing.Guild as Dict).Id as string) : "";
			const before = svc._guilds.GetCachedPublic(contributeGuildId) as Dict | undefined;
			contributeActivity = before !== undefined ? (tonumber(before.Activity) ?? 0) : 0;
		}
		let renameGuildId = "";
		if (action === K.Protocol.Actions.RenameGuild) {
			const existing = svc._data.Get(player) as Profile | undefined;
			renameGuildId = existing !== undefined && typeIs(existing.Guild, "table") ? ((existing.Guild as Dict).Id as string) : "";
		}
		if (action === K.Protocol.Actions.JoinGuild) {
			const [canJoin, joinError] = svc._guildCommunity.CanJoinByTag(payload.Tag, player.UserId) as LuaTuple<[unknown, unknown]>;
			if (!truthy(canJoin)) {
				return responseError(truthy(joinError) ? joinError : T("GameService.YouCannotJoinThatGuild"));
			}
		}
		const result = svc._mutate(player, (profile: Profile) => {
			let ok: unknown;
			let message: unknown;
			let guild: unknown;
			if (action === K.Protocol.Actions.CreateGuild) {
				const [a, b, c] = svc._guilds.Create(player, profile, payload.Name, payload.Tag) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.JoinGuild) {
				const [a, b, c] = svc._guilds.JoinByTag(player, profile, payload.Tag) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.LeaveGuild) {
				const [a, b, c] = svc._guilds.Leave(player, profile) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.DisbandGuild) {
				const [a, b, c] = svc._guilds.Disband(player, profile) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.RenameGuild) {
				const [a, b, c] = svc._guilds.Rename(player, profile, payload.Name, payload.Tag) as LuaTuple<[unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.ContributeGuild) {
				const balanceField = payload.Currency === "Cash" ? "Cash" : "Stardust";
				let amount = payload.Amount as number;
				if (typeIs(payload.Fraction, "number")) {
					amount = math.max(1, math.floor((tonumber(profile[balanceField]) ?? 0) * payload.Fraction));
				}
				const [a, b, c] = svc._guilds.ContributeBank(player, profile, math.floor(amount), payload.Currency) as LuaTuple<
					[unknown, unknown, unknown]
				>;
				ok = a;
				message = b;
				guild = c;
			} else if (action === K.Protocol.Actions.ClaimGuildGoal) {
				const [a, b, c, reward] = svc._guilds.ClaimGoal(player, profile) as LuaTuple<[unknown, unknown, unknown, unknown]>;
				ok = a;
				message = b;
				guild = c;
				if (truthy(ok) && truthy(reward)) {
					const rewardText = K.ProgressionService.ApplyReward(profile, reward, K.Economy.Production(profile));
					if (tostring(rewardText) !== "") {
						message = T("GameService.GuildGoalDoneS", tostring(rewardText));
					}
				}
			}
			if (truthy(ok)) {
				profile.GuildBonuses = svc._guilds.GetCachedBonuses((profile.Guild as Dict).Id);
				return responseSuccess(message, { Guild: guild });
			}
			return responseError(message);
		});
		if (truthy(result.ok) && action === K.Protocol.Actions.ContributeGuild && contributeGuildId !== "") {
			svc._announceGuildActivity(contributeGuildId, contributeActivity, result.Guild);
		}
		if (truthy(result.ok) && action === K.Protocol.Actions.RenameGuild && renameGuildId !== "" && truthy(result.Guild)) {
			const guild = result.Guild as Dict;
			const auditLog = guild.AuditLog as Dict[] | undefined;
			const first = auditLog !== undefined && typeIs(auditLog[0], "table") ? auditLog[0] : undefined;
			const oldTag = first !== undefined ? first.FromTag : undefined;
			const newTag = first !== undefined ? first.ToTag : undefined;
			const tagText =
				oldTag !== undefined && newTag !== undefined && oldTag !== newTag
					? string.format(" Tag changed from %s to %s.", tostring(oldTag), tostring(newTag))
					: "";
			svc._toastGuild(
				renameGuildId,
				"Guild renamed",
				string.format("%s renamed the guild to %s.%s", player.DisplayName, (guild.Name as string | undefined) ?? "", tagText),
				"Special",
				player,
			);
			for (const online of Players.GetPlayers()) {
				if (online !== player) {
					const onlineProfile = svc._data.Get(online) as Profile | undefined;
					const onlineGuild = onlineProfile !== undefined ? (onlineProfile.Guild as Dict | undefined) : undefined;
					if (onlineProfile !== undefined && onlineGuild !== undefined && onlineGuild.Id === renameGuildId) {
						svc._pushState(online);
					}
				}
			}
		}
		return result;
}
