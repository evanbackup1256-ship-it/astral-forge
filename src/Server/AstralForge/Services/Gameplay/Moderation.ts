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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function reportPlayer(svc: GameService, player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const reason = payload ? payload.Reason : undefined;
		if (!truthy(K.ReportLedger.isReason(reason))) {
			return responseError(T("GameService.PickAReasonBeforeSending"));
		}
		const rawTarget = payload ? payload.UserId : undefined;
		const extracted = extractUserId(rawTarget);
		const targetUserId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawTarget)) as number | undefined;
		if (targetUserId === undefined) {
			return responseError(T("GameService.CouldnTFindThatPlayer"));
		}
		if (targetUserId === player.UserId) {
			return responseError(T("GameService.YouCanTReportYourself"));
		}
		const target = Players.GetPlayerByUserId(targetUserId);
		if (!target) {
			return responseError(T("TradeSuite.ThatPlayerIsNoLonger"));
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
			const [filteredOk, filtered] = (svc._security.Filter as Svc).Apply(player, rawDetails, player.UserId, 400) as LuaTuple<
				[unknown, unknown]
			>;
			details = truthy(filteredOk) && typeIs(filtered, "string") ? filtered : "";
		}
		const [reportCount, reporterCount] = reportLedger.record(player.UserId, targetUserId, reason, now) as LuaTuple<[number, number]>;
		const severity = body0.Severity === "Serious" || body0.Severity === "Urgent" ? (body0.Severity as string) : "Minor";
		const when = body0.When === "Earlier" || body0.When === "Repeated" ? (body0.When as string) : "Now";
		const where = body0.Where === "Chat" || body0.Where === "Trade" || body0.Where === "Guild" ? (body0.Where as string) : "World";
		const endpoint = ServerStorage.GetAttribute(K.ServerConfig.ReportWebhookAttribute as string);
		if (!typeIs(endpoint, "string") || endpoint.match("^https://")[0] === undefined) {
			K.ModuleLog.Every(
				"report:%d".format(targetUserId),
				5,
				"Report",
				"%s reported %s (%d) for %s; %d reports from %d players svc hour".format(
					player.Name,
					target.Name,
					targetUserId,
					reason as string,
					reportCount,
					reporterCount,
				),
			);
			return responseSuccess(T("GameService.ReportReceivedThanksForHelping"), { Reported: targetUserId });
		}
		const reporterProfile = svc._data.Get(player) as Profile | undefined;
		const targetProfile = svc._data.Get(target) as Profile | undefined;
		const progressOf = (p: Profile | undefined) =>
			"World %d · %d rebirths".format(orElse(p && p.Zone, () => 1) as number, orElse(p && p.Rebirths, () => 0) as number);
		const body = {
			username: "Astral Forge Reports",
			allowed_mentions: { parse: {} },
			embeds: [
				{
					title: "[%s] Player report: %s".format(severity, reason as string),
					description: details !== "" ? details : "(no details provided)",
					color: (K.ReportLedger.SEVERITY_COLORS as unknown as Record<string, number | undefined>)[severity] ?? 15548997,
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
					footer: { text: "Astral Forge " + tostring(K.GameConfig.Game.Version) },
					timestamp: DateTime.now().ToIsoDate(),
				},
			],
		};
		svc._spawnWorker(() => {
			const [ok, response] = pcall(() =>
				HttpService.RequestAsync({
					Url: endpoint,
					Method: "POST",
					Headers: { ["Content-Type"]: "application/json" },
					Body: HttpService.JSONEncode(body),
				}),
			);
			if (!ok || !typeIs(response, "table") || response.Success !== true) {
				K.ModuleLog.Every("report-webhook", 30, "Report", "A player report could not be delivered");
			}
		});
		return responseSuccess(T("GameService.ReportSentThanksForHelping"), { Reported: targetUserId });
}

export function submitFeedback(svc: GameService, player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const endpoint = ServerStorage.GetAttribute(K.ServerConfig.FeedbackWebhookAttribute as string);
		if (!typeIs(endpoint, "string") || endpoint.match("^https://")[0] === undefined) {
			return responseError(T("GameService.FeedbackIsnTSetUp"));
		}
		const category = payload ? payload.Category : undefined;
		const raw = payload ? payload.Message : undefined;
		if (!typeIs(category, "string") || !typeIs(raw, "string")) {
			return responseError(T("GameService.WriteAShortNoteBefore"));
		}
		const body0 = payload as Dict;
		const [filteredOk, filtered] = (svc._security.Filter as Svc).Apply(player, raw, player.UserId, 600) as LuaTuple<[unknown, unknown]>;
		if (!truthy(filteredOk) || !typeIs(filtered, "string") || filtered.size() < 1) {
			return responseError(T("GameService.ThatNoteCouldnTBe"));
		}
		const profile = svc._data.Get(player) as Profile | undefined;
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
					footer: { text: "Astral Forge " + tostring(K.GameConfig.Game.Version) },
					timestamp: DateTime.now().ToIsoDate(),
				},
			],
		};
		svc._spawnWorker(() => {
			const [ok, response] = pcall(() =>
				HttpService.RequestAsync({
					Url: endpoint,
					Method: "POST",
					Headers: { ["Content-Type"]: "application/json" },
					Body: HttpService.JSONEncode(body),
				}),
			);
			if (!ok || !typeIs(response, "table") || response.Success !== true) {
				K.ModuleLog.Every("feedback-webhook", 30, "Feedback", "A player note could not be delivered");
			}
		});
		return responseSuccess(T("GameService.ThanksYourFeedbackWasSent"));
}
