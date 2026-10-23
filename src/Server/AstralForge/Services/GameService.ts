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
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "./GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "./GameServiceCore";
import * as Snapshot from "./Gameplay/Snapshot";
import * as DomainExpansion from "./Gameplay/DomainExpansion";
import * as Rebirth from "./Gameplay/Rebirth";
import * as Leaderstats from "./Gameplay/Leaderstats";
import * as Moderation from "./Gameplay/Moderation";
import * as CrateOpening from "./Gameplay/CrateOpening";
import * as ShopDomain from "./Gameplay/ShopDomain";
import * as BoostDomain from "./Gameplay/BoostDomain";
import * as Automation from "./Gameplay/Automation";
import * as GuildActions from "./Gameplay/GuildActions";

@Service({ loadOrder: 4 })
export class GameService {
	_data!: Svc;
	_world!: Svc;
	_fluxSurge: Svc | undefined;
	_state!: PayloadEvent;
	_toast!: PayloadEvent;
	_effect!: PayloadEvent;
	_security!: Dict;
	_admin: Svc | undefined;
	_runtime!: Map<Player, Runtime>;
	_visiting!: Map<Player, number>;
	_visitors!: Map<number, Map<Player, boolean>>;
	_presence!: Map<number, Dict>;
	_matter!: MatterRuntime;
	_matterAccumulator!: number;
	_rankPingAccumulator!: number;
	_rankPingBusy!: boolean;
	_firewall!: Svc;
	_session!: Svc;
	_antiCheat!: Svc;
	_analytics!: Svc;
	_badges!: Svc;
	_convergence!: Svc;
	_events!: Svc;
	_guilds!: Svc;
	_guildCommunity!: Svc;
	_chat!: Svc;
	_crews!: Svc;
	_trades!: Svc;
	_random!: Random;
	_economyLedgers: EconomyLedgers | undefined;
	_heartbeat: RBXScriptConnection | undefined;
	_playerAddedConnection: RBXScriptConnection | undefined;
	_playerRemovingConnection: RBXScriptConnection | undefined;
	_characterConnections!: Map<Player, RBXScriptConnection>;
	_joining!: Map<Player, unknown>;
	_running!: boolean;
	_leaderboardStores!: Record<string, unknown>;
	_playerNameCache!: Map<number, Dict>;
	_nameLookupPending!: Map<number, boolean>;
	_nameCachePruneAt!: number;
	_globalBoardCache!: Record<string, Dict | undefined>;
	_friendGraph!: FriendGraph;
	_queuedStatePushes!: Map<Player, thread>;
	_socialBoostScheduled!: boolean;
	_socialBoostDirty!: boolean;
	_socialBoostWorker: thread | undefined;
	_backgroundWorkers!: Map<object, thread>;
	_saveFailedToastAt!: Map<Player, number>;
	[key: string]: unknown;

	_visitorList(host: Player) {
		return K.VisitorList.Build(this._visitors.get(host.UserId), (visitor: Player) => visitor.Parent === Players);
	}

	_clearVisit(visitor: Player, notifyHost: boolean) {
		const hostUserId = this._visiting.get(visitor);
		if (hostUserId === undefined) {
			return;
		}
		this._visiting.delete(visitor);
		const bucket = this._visitors.get(hostUserId);
		if (bucket) {
			bucket.delete(visitor);
			if (bucket.size() === 0) {
				this._visitors.delete(hostUserId);
			}
		}
		if (!notifyHost) {
			return;
		}
		for (const host of Players.GetPlayers()) {
			if (host.UserId === hostUserId) {
				this._toastPlayer(host, T("Toast.VisitorLeftTitle"), T("Toast.VisitorLeftBody", visitor.DisplayName), "Info");
				this._pushState(host);
				break;
			}
		}
	}

	_broadcastVisit(host: Player) {
		const bucket = this._visitors.get(host.UserId);
		if (!bucket) {
			return;
		}
		const profile = this._data.Get(host) as Profile | undefined;
		if (!profile) {
			return;
		}
		const visit = buildVisitSnapshot(host, profile);
		for (const [visitor] of bucket) {
			if (visitor.Parent === Players) {
				this._effect.fire(visitor, {
					Type: "VisitUpdate",
					Visit: visit,
				});
			}
		}
	}

	_visitPlot(visitor: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);

		let userId = RemoteFirewall.CoerceUserId(extracted) as number | undefined;
		if (userId === undefined) {
			userId = RemoteFirewall.CoerceUserId(rawUserId) as number | undefined;
		}
		if (userId === undefined) {
			return responseError(T("GameService.ThatWorkshopCouldNotBe"));
		}
		if (userId === visitor.UserId) {
			return responseError(T("GameService.YouReAlreadyAtYour"));
		}
		const host = Players.GetPlayerByUserId(userId);
		if (!host) {
			return responseError(T("TradeSuite.ThatPlayerIsNoLonger"));
		}
		const profile = this._data.Get(host) as Profile | undefined;
		if (!profile) {
			return responseError(T("GameService.TheirWorkshopIsStillLoading"));
		}

		this._clearVisit(visitor, true);
		this._visiting.set(visitor, host.UserId);
		let bucket = this._visitors.get(host.UserId);
		if (!bucket) {
			bucket = new Map();
			this._visitors.set(host.UserId, bucket);
		}
		bucket.set(visitor, true);

		const visit = buildVisitSnapshot(host, profile);
		this._toastPlayer(host, T("Toast.VisitorArrivedTitle"), T("Toast.VisitorArrivedBody", visitor.DisplayName), "Special");
		this._pushState(host);

		const visitorSnap = this._snapshot(visitor);
		this._forgetSentSections(visitor);
		this._pushState(visitor);
		return responseSuccess(T("GameService.VisitingS", host.DisplayName), { Visit: visit, State: visitorSnap });
	}

	_leavePlot(visitor: Player) {
		if (this._visiting.get(visitor) === undefined) {
			return responseSuccess(T("GameService.AlreadyBackAtYourWorkshop"));
		}
		this._clearVisit(visitor, true);
		this._effect.fire(visitor, { Type: "VisitEnded" });
		return responseSuccess(T("GameService.BackAtYourWorkshop"));
	}

	_nudgeCrew(sender: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);
		const userId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawUserId)) as number | undefined;
		if (userId === undefined) {
			return responseError(T("GameService.CouldnTFindThatCrew"));
		}
		if (userId === sender.UserId) {
			return responseError(T("GameService.WaveAtSomeoneElse"));
		}
		const target = Players.GetPlayerByUserId(userId);
		if (!target) {
			return responseError(T("GameService.TheyReNotInThis"));
		}

		this._effect.fire(target, {
			Type: "CrewNudge",
			FromUserId: sender.UserId,
			FromName: sender.DisplayName,
		});
		return responseSuccess(T("GameService.WavedAtS", target.DisplayName));
	}

	_reportPresence(player: Player, payload: unknown) {
		const body = payload as Dict | undefined;
		const page = body !== undefined ? body.Page : undefined;
		if (typeIs(page, "string") && PRESENCE_PAGES[page]) {
			this._presence.set(player.UserId, { Page: page, UpdatedAt: os.time() });
		}
		if (body === undefined || body.Gen === undefined) {
			const [gen, nonce] = this._session.Hello(player) as LuaTuple<[unknown, unknown]>;
			return responseSuccess(undefined, { Gen: gen, N: nonce });
		}
		const [ok, reason, gen, nonce] = this._session.Beat(player, body.Gen, body.Id, body.N) as LuaTuple<
			[boolean, unknown, unknown, unknown]
		>;
		if (!ok && reason !== "late") {
			K.ModuleLog.Every("beat:%d".format(player.UserId), 15, "auth", "u=%d beat rejected %s".format(player.UserId, tostring(reason)));
		}
		return responseSuccess(undefined, { Gen: gen, N: nonce, Auth: ok });
	}

	_getPlayers(viewer: Player) {
		const records: Dict[] = [];
		for (const target of Players.GetPlayers()) {
			const profile = this._data.Get(target) as Profile | undefined;
			if (profile) {
				records.push(publicPlayerRecord(target, profile, viewer, this._presence));
			}
		}
		const isStudio = studioCheck();
		let hasOther = false;
		for (const r of records) {
			if (!truthy(r.IsLocal)) {
				hasOther = true;
				break;
			}
		}
		if (isStudio || !hasOther) {
			records.push({
				UserId: -999,
				Name: "ForgeAutomaton",
				DisplayName: "Forge Automaton [Practice]",
				Zone: 1,
				CurrentZone: 1,
				Rebirths: 3,
				Production: 1000,
				LifetimeCash: 10000,
				Stardust: 1000,
				Cores: 10,
				DomainRank: 0,
				PlayTime: 1000,
				Boards: {
					Crates: "10",
					Finds: "5",
					Ore: "100",
					Wardens: "1",
					Orders: "2",
					Stars: "3",
					Cipher: "0",
				},
				ItemCount: 0,
				EquippedItems: {},
				Artifact: undefined,
				IsLocal: false,
				SocialFlags: 0,
				CurrentPage: "Overview",
				PresenceAge: 0,
				AccountAge: 100,
				Premium: false,
			});
		}
		table.sort(records as defined[], (leftValue, rightValue) => {
			const left = leftValue as Dict;
			const right = rightValue as Dict;
			if (left.IsLocal !== right.IsLocal) {
				return left.IsLocal as boolean;
			}
			// Production above 1e15 is an Omega string; a plain > would throw comparing it to a number
			return K.Economy.Gt(left.Production, right.Production) as boolean;
		});
		return responseSuccess(undefined, { Players: records });
	}

	_pushTradePartners(hostId: unknown, guestId: unknown) {
		for (const userId of [hostId, guestId]) {
			const other = Players.GetPlayerByUserId(userId as number);
			if (other) {
				this._pushState(other, true);
			}
		}
	}

	_tradeAction(player: Player, action: string, rawPayload: unknown) {
		return TradeDomain.tradeAction(this as unknown as TradeDomain.TradeHost, itemById, player, action, rawPayload);
	}

	_getPlayerMirror(viewer: Player, rawUserId: unknown) {
		const extracted = extractUserId(rawUserId);
		const userId = orElse(RemoteFirewall.CoerceUserId(extracted), () => RemoteFirewall.CoerceUserId(rawUserId)) as number | undefined;
		if (userId === undefined) {
			return responseError(T("GameService.ThatPlayerCouldNotBe"));
		}
		const target = Players.GetPlayerByUserId(userId);
		if (target) {
			const profile = this._data.Get(target) as Profile | undefined;
			if (profile) {
				return responseSuccess(undefined, { Mirror: publicPlayerRecord(target, profile, viewer, this._presence) });
			}
		}
		return responseError(T("TradeSuite.ThatPlayerIsNoLonger"));
	}

	constructor(
		private readonly dataService: DataService,
		private readonly worldService: WorldService,
		private readonly fluxSurgeService: FluxSurgeService,
		private readonly convergenceService: ConvergenceService,
		private readonly securityPipeline: Security,
		private readonly adminService: AdminService,
		private readonly sessionGate: SessionGate,
		private readonly remoteFirewall: RemoteFirewall,
		private readonly gameAntiCheat: GameAntiCheat,
		private readonly playerAnalytics: PlayerAnalytics,
		private readonly playerBadges: PlayerBadges,
		private readonly matterRuntime: MatterRuntime,
		private readonly serverEvents: ServerEventService,
		private readonly guildService: GuildService,
		// GameService reads the shared Specializations rules; this service keeps them live-tuned.
		private readonly _specializations: SpecializationService,
	) {}

	// Runs from the server runtime's "gameplay construction" boot step.
	build() {
		const dataService = this.dataService as unknown as Svc;
		this._data = dataService;
		this._world = this.worldService as unknown as Svc;
		this._fluxSurge = this.fluxSurgeService as unknown as Svc;
		this._state = ServerEvents.state;
		this._toast = ServerEvents.toast;
		this._effect = ServerEvents.effect;
		this._security = this.securityPipeline as unknown as Dict;
		this._admin = this.adminService as unknown as Svc;
		this._runtime = new Map();
		this._visiting = new Map();
		this._visitors = new Map();
		this._presence = new Map();
		this._matter = this.matterRuntime;
		this._matterAccumulator = 0;
		this._rankPingAccumulator = 0;
		this._rankPingBusy = false;
		this._firewall = this.remoteFirewall as unknown as Svc;
		this._session = this.sessionGate as unknown as Svc;
		this._antiCheat = this.gameAntiCheat as unknown as Svc;
		this._analytics = this.playerAnalytics as unknown as Svc;
		this._badges = this.playerBadges as unknown as Svc;
		this._convergence = this.convergenceService as unknown as Svc;
		this._events = this.serverEvents as unknown as Svc;
		this.serverEvents.Attach({
			random: () => this._random.NextNumber(),
			announce: (phase: string, def: Dict) => {
				this._announceServerEvent(phase, def);
			},
			broadcast: () => {
				for (const online of Players.GetPlayers()) {
					this._effect.fire(online, { Type: "ServerEvent", Event: this._events.State(online) });
				}
			},
			pay: (entries: Dict[], def: Dict, why: string) => {
				this._payEvent(entries, def, why);
			},
		} as unknown as Parameters<ServerEventService["Attach"]>[0]);
		// Studio only: start any event by id to try it (ServerScriptService.EventDebug:Invoke("IronTitan"))
		if (game.GetService("RunService").IsStudio()) {
			const debugHook = new Instance("BindableFunction");
			debugHook.Name = "EventDebug";
			debugHook.OnInvoke = (id: unknown) => this._events.Start(id);
			debugHook.Parent = game.GetService("ServerScriptService");
		}
		this._guilds = this.guildService as unknown as Svc;
		this._guildCommunity = K.GuildCommunity.new(
			this._guilds,
			dataService,
			this._security,
			this._effect,
			(target: Player, guildId: string): LuaTuple<[boolean, unknown]> => {
				const [updated, result] = this._data.AtomicUpdate(
					target,
					(targetProfile: Profile) => {
						const guild = targetProfile.Guild as Dict | undefined;
						if (truthy(guild) && guild.Id === guildId) {
							targetProfile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
							targetProfile.GuildBonuses = emptyBonuses();
						}
						return { ok: true };
					},
					true,
					"guild-ban",
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(updated)) {
					return $tuple(false, result);
				}
				this._pushState(target);
				// a guild ban removes guild access only (the client shows the notice); never disconnect the player
				this._effect.fire(target, { Type: "GuildBanned", GuildId: guildId });
				return $tuple(true, undefined);
			},
		) as Svc;
		this._chat = K.ChatService.new(this._effect, this._data) as Svc;
		this._crews = K.CrewService.new(this._effect, this._data) as Svc;
		this._trades = K.TradeDesk.new() as Svc;
		// the trade table shows each side the other's tradeable relics
		(this._trades as Dict).ProfileOf = (userId: number) => {
			const other = Players.GetPlayerByUserId(userId);
			const found = other ? this._data.Get(other) : undefined;
			return truthy(found) ? found : undefined;
		};
		this._random = new Random();
		this._heartbeat = undefined;
		this._playerAddedConnection = undefined;
		this._playerRemovingConnection = undefined;
		this._characterConnections = new Map();
		this._joining = new Map();
		this._running = false;
		this._leaderboardStores = {};
		for (const [id, storeName] of pairs(GENERAL_BOARD_STORE_NAMES)) {
			this._leaderboardStores[id] = getOrderedStore(storeName);
		}

		this._playerNameCache = new Map();
		this._nameLookupPending = new Map();
		this._nameCachePruneAt = 0;
		this._globalBoardCache = {};
		// friends bonus: pairwise IsFriendsWith answers cached per pair (failures count as no)
		this._friendGraph = new Deps.FriendGraph({
			ttl: K.GameConfig.Social.FriendshipCacheSeconds as number,
			failTtl: 20,
			isFriends: (low, high) => {
				const player = Players.GetPlayerByUserId(low);
				return player !== undefined && (player as unknown as Svc).IsFriendsWith(high) === true;
			},
		});
		this._queuedStatePushes = new Map();
		this._socialBoostScheduled = false;
		this._socialBoostDirty = false;
		this._socialBoostWorker = undefined;
		this._backgroundWorkers = new Map();
		this._saveFailedToastAt = new Map();
		(dataService as Dict).OnSaveFailed = (player: Player, reason: string) => {
			const lastToastAt = this._saveFailedToastAt.get(player) ?? 0;
			if (os.clock() - lastToastAt < 120) {
				return;
			}
			this._saveFailedToastAt.set(player, os.clock());
			this._toastPlayer(player, T("Toast.SaveTroubleTitle"), T("Toast.SaveTroubleBody"), "Warning");
		};
	}

	_submitFeedback(player: Player, rawPayload: unknown) {
		return Moderation.submitFeedback(this, player, rawPayload);
	}

	_reportPlayer(player: Player, rawPayload: unknown) {
		return Moderation.reportPlayer(this, player, rawPayload);
	}

	_spawnWorker(callback: () => void) {
		if (!this._running) {
			return undefined;
		}
		const token = {};
		const worker = task.defer(() => {
			if (this._running) {
				const [ok, problem] = pcall(callback);
				if (!ok) {
					K.ModuleLog.Every("background-worker", 5, "Game", "background task failed: " + tostring(problem));
				}
			}
			this._backgroundWorkers.delete(token);
		});
		this._backgroundWorkers.set(token, worker);
		return worker;
	}

	_queueSocialBoostRefresh() {
		this._socialBoostDirty = true;
		if (this._socialBoostScheduled) {
			return;
		}
		this._socialBoostScheduled = true;
		this._socialBoostWorker = task.spawn(() => {
			do {
				this._socialBoostDirty = false;
				task.wait(0.15);
				if (!this._running) {
					break;
				}
				const online = Players.GetPlayers();
				const friendCounts = this._friendGraph.count(online.map((player) => player.UserId));
				const counts = new Map<Player, number>();
				for (const player of online) {
					counts.set(player, friendCounts.get(player.UserId) ?? 0);
				}
				for (const player of online) {
					const [updated, updateError] = pcall(() => {
						let changed = false;
						const committed = this._data.AtomicUpdate(
							player,
							(profile: Profile) => {
								changed = applySocialBoost(profile, counts.get(player) ?? 0, player.MembershipType === Enum.MembershipType.Premium);

								if (!changed) {
									return { ok: false, noop: true };
								}
								return { ok: true };
							},
							true,
							"social-boost",
						) as LuaTuple<[unknown]>;
						if (truthy(committed) && changed) {
							this._pushState(player);
						}
					});
					if (!updated) {
						K.ModuleLog.Every(
							"social-boost:" + tostring(player.UserId),
							30,
							"Social",
							"friend boost update failed: " + tostring(updateError),
						);
					}
				}
			} while (this._socialBoostDirty);
			this._socialBoostScheduled = false;
			this._socialBoostWorker = undefined;

			if (this._socialBoostDirty && this._running) {
				this._queueSocialBoostRefresh();
			}
		});
	}

	_toastPlayer(player: Player, title: unknown, body: unknown, tone?: unknown) {
		if (player.Parent !== Players) {
			return;
		}
		this._toast.fire(player, {
			Title: title,
			Body: body,
			Tone: orElse(tone, () => "Info"),
		});
	}

	_createLeaderstats(player: Player) {
		const old = player.FindFirstChild("leaderstats");
		if (old) {
			old.Destroy();
		}
		const folder = new Instance("Folder");
		folder.Name = "leaderstats";
		folder.Parent = player;

		const flux = new Instance("NumberValue");
		flux.Name = "Flux";
		flux.Parent = folder;

		const cores = new Instance("NumberValue");
		cores.Name = "Cores";
		cores.Parent = folder;
		const rebirths = new Instance("NumberValue");
		rebirths.Name = "Rebirths";
		rebirths.Parent = folder;
	}

	_syncLeaderstats(player: Player, profile: unknown) {
		return Leaderstats.syncLeaderstats(this, player, profile);
	}

	_announceServerEvent(phase: string, def: Dict) {
		let title: unknown;
		let body: unknown;
		let tone: string;
		if (phase === "Warning") {
			title = (def.Name as string) + " in a minute";
			body = def.Blurb;
			tone = "Info";
		} else if (phase === "Live") {
			// the client lands a live event as a moment out of the island; a toast would repeat it
			return;
		} else if (phase === "Completed") {
			title = "Order filled";
			body = "Everyone who helped has been paid.";
			tone = "Success";
		} else if (phase === "Defeated") {
			title = "The Titan is down";
			body = "Everyone who hit it has been paid.";
			tone = "Success";
		} else {
			title = (def.Name as string) + " is over";
			body = "The next event is a few minutes away.";
			tone = "Info";
		}
		for (const online of Players.GetPlayers()) {
			this._toastPlayer(online, title, body, tone);
		}
	}

	// pays whoever an event says earned something; one toast each, saying exactly what came in
	_payEvent(entries: Dict[], _def: Dict, why: string) {
		for (const [, entry] of pairs(entries)) {
			const player = Players.GetPlayerByUserId(entry.UserId as number);
			if (player === undefined) {
				continue;
			}
			let fluxPaid = 0;
			const fluxSeconds = (entry.FluxSeconds as number | undefined) ?? 0;
			const entryStardust = (entry.Stardust as number | undefined) ?? 0;
			const entryCores = (entry.Cores as number | undefined) ?? 0;
			const entryKeys = (entry.Keys as number | undefined) ?? 0;
			this._mutate(player, (profile: Profile) => {
				if (fluxSeconds > 0) {
					let amount = K.Economy.Mul(K.Economy.Production(profile), entry.FluxSeconds);
					if ((K.Economy.AsNumber(amount) as number) < 500) {
						amount = 500;
					}
					profile.Cash = K.Economy.Add(profile.Cash, amount);
					profile.RunCash = K.Economy.Add(profile.RunCash, amount);
					profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, amount);
					fluxPaid = K.Economy.AsNumber(amount) as number;
				}
				if (entryStardust > 0) {
					profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (entry.Stardust as number), 0, 1e14);
				}
				if (entryCores > 0) {
					profile.Cores = math.clamp((num(profile.Cores) ?? 0) + (entry.Cores as number), 0, 1e14);
				}
				const items = profile.Items as Dict | undefined;
				if (entryKeys > 0 && truthy(entry.KeyCrate) && truthy(items) && truthy(items.Keys)) {
					const keys = items.Keys as Dict;
					const crate = entry.KeyCrate as string;
					keys[crate] = (num(keys[crate]) ?? 0) + (entry.Keys as number);
				}
				return responseSuccess(undefined);
			});
			const parts: string[] = [];
			if (fluxPaid > 0) {
				parts.push("+" + (K.Format.Number(fluxPaid) as string) + " Flux");
			}
			if (entryStardust > 0) {
				parts.push("+" + tostring(entry.Stardust) + " Stardust");
			}
			if (entryCores > 0) {
				parts.push("+" + tostring(entry.Cores) + " cores");
			}
			const rank = entry.Rank as number | undefined;
			let title: string;
			if (why === "race") {
				title = rank !== undefined && rank <= 3 ? "Forge Race: #%d".format(rank) : "Forge Race: you scored";
			} else if (why === "draw") {
				title = truthy(entry.Rank) ? "Your ticket was drawn" : "Lucky Draw: thanks for playing";
			} else if (why === "titan") {
				title = rank !== undefined && rank <= 3 ? "Titan down: #%d hitter".format(rank) : "Titan down";
			} else {
				title = rank !== undefined && rank <= 3 ? "Order filled: #%d".format(rank) : "Order filled";
			}
			this._toastPlayer(player, title, parts.join(", "), "Success");
		}
	}

	_settleProgression(player: Player, profile: Profile, levelState: Dict, production: unknown) {
		let progression = profile.Progression as Dict;
		if (!isTable(progression)) {
			progression = { RewardedLevel: -1, HalfwayPaidFor: -1, Surge: { Multiplier: 1, EndsAt: 0 } };
			profile.Progression = progression;
		}
		const now = os.time();
		const firstLook = (num(progression.RewardedLevel) ?? -1) < 0;
		const [owed, settled] = K.LevelRewards.owed(num(progression.RewardedLevel) ?? -1, levelState.Level) as LuaTuple<[unknown[], unknown]>;
		progression.RewardedLevel = settled;
		if (firstLook) {
			progression.HalfwayPaidFor = levelState.Level;
		}
		const fluxFor = (seconds: unknown, floor: number) => {
			let amount = K.Economy.Mul(production, seconds);
			if ((K.Economy.AsNumber(amount) as number) < floor) {
				amount = floor;
			}
			return amount;
		};
		if (owed.size() > 0) {
			let fluxTotal: unknown = 0;
			let stardustTotal = 0;
			let surge = progression.Surge;
			for (const reached of owed) {
				const def = K.ForgeLevels.get(reached) as Dict | undefined;
				const reward = K.LevelRewards.forLevel(reached, truthy(def) ? def.Tier : def) as Dict;
				const flux = fluxFor(reward.FluxSeconds, reward.MinFlux as number);
				profile.Cash = K.Economy.Add(profile.Cash, flux);
				fluxTotal = K.Economy.Add(fluxTotal, flux);
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (reward.Stardust as number), 0, 1e14);
				stardustTotal += reward.Stardust as number;
				surge = K.LevelRewards.mergeSurge(surge, now, reward.SurgeMultiplier, reward.SurgeSeconds);
			}
			progression.Surge = surge;
			progression.HalfwayPaidFor = math.max(num(progression.HalfwayPaidFor) ?? -1, levelState.Level as number);
			this._effect.fire(player, {
				Type: "LevelReward",
				Level: levelState.Level,
				Tier: levelState.Tier,
				Levels: owed,
				Flux: K.Economy.AsNumber(fluxTotal),
				Stardust: stardustTotal,
				SurgeMultiplier: (surge as Dict).Multiplier,
				SurgeEndsAt: (surge as Dict).EndsAt,
			});
		}
		const nextStep = levelState.Next as Dict | undefined;
		let nextReward: unknown = undefined;
		if (nextStep !== undefined) {
			nextReward = K.LevelRewards.forLevel(nextStep.Level, nextStep.Tier);
		}
		return {
			Mastery: K.LevelRewards.mastery(settled),
			Surge: {
				Multiplier: K.LevelRewards.surgeMultiplier(progression.Surge, now),
				EndsAt: (K.LevelRewards.surgeMultiplier(progression.Surge, now) as number) > 1 ? (progression.Surge as Dict).EndsAt : 0,
			},
			HalfwayPaidFor: progression.HalfwayPaidFor,
			NextReward: nextReward,
		};
	}

	_snapshot(player: Player): Dict | undefined {
		return Snapshot.snapshot(this, player);
	}

	_trimUnchangedSections(runtime: Runtime | undefined, snapshot: Dict, force?: boolean) {
		if (runtime === undefined) {
			return snapshot;
		}
		const now = os.clock();
		const previous = runtime.LastSentSections as Dict | undefined;
		const previousPrints = orEmpty(runtime.LastSentPrints, () => ({}));
		const sections: Dict = {};
		for (const [key, value] of pairs(snapshot)) {
			if (typeIs(value, "table")) {
				sections[key] = value;
			}
		}
		runtime.LastSentSections = sections;
		const full =
			truthy(force) || previous === undefined || now - ((runtime.LastFullSnapshotAt as number | undefined) ?? 0) >= FULL_SNAPSHOT_EVERY;
		const prints: Dict = {};
		if (full) {
			// Everything goes out anyway, so skip the deep compare. Only sections that needed a
			// fingerprint last time (they share tables) get one now, so the next push can still
			// reuse them; a section that newly starts sharing just gets resent once.
			for (const [key, value] of pairs(sections)) {
				if (previousPrints[key] !== undefined) {
					prints[key] = fingerprint(value);
				}
			}
			runtime.LastSentPrints = prints;
			runtime.LastFullSnapshotAt = now;
			return snapshot;
		}
		const trimmed = table.clone(snapshot);
		const reused: string[] = [];
		for (const [key, value] of pairs(sections)) {
			let verdict: boolean | undefined = previous !== undefined && previous[key] !== undefined ? sameValue(previous[key], value, 0) : false;
			if (verdict === undefined) {
				// shares tables with something else: compare what was actually sent instead
				const sent = fingerprint(value);
				prints[key] = sent;
				verdict = sent !== undefined && previousPrints[key] === sent;
			}
			if (verdict && !full) {
				trimmed[key] = undefined;
				reused.push(key);
			}
		}
		runtime.LastSentPrints = prints;
		if (full) {
			runtime.LastFullSnapshotAt = now;
			return snapshot;
		}
		if (reused.size() === 0) {
			return snapshot;
		}
		trimmed.Reused = reused;
		return trimmed;
	}

	// a snapshot that leaves this server by another path (a GetState reply) makes the next push a full one
	_forgetSentSections(player: Player) {
		const runtime = this._runtime.get(player);
		if (runtime) {
			runtime.LastSentSections = undefined;
		}
	}

	_pushState(player: Player, force?: boolean) {
		if (player.Parent !== Players) {
			return;
		}
		// the same revision pushed moments ago would be dropped below anyway; skip building the
		// whole snapshot for it (unless a Bazaar recovery is due, which the snapshot performs)
		if (!truthy(force)) {
			const early = this._runtime.get(player);
			const current = this._data.Get(player) as Profile | undefined;
			const currentMeta = current !== undefined ? (current.Meta as Dict | undefined) : undefined;
			if (
				early &&
				current !== undefined &&
				currentMeta !== undefined &&
				early.LastPushRevision === (num(currentMeta.Revision) ?? 0) &&
				os.clock() - ((early.LastPushAt as number | undefined) ?? 0) < 0.55 &&
				!truthy(K.BazaarService.NeedsRecovery(current, player.UserId))
			) {
				this._broadcastVisit(player);
				return;
			}
		}
		const snapshot = this._snapshot(player);
		if (snapshot) {
			const runtime = this._runtime.get(player);
			const now = os.clock();
			const revision = num(snapshot.Revision) ?? 0;
			if (
				!truthy(force) &&
				runtime &&
				runtime.LastPushRevision === revision &&
				now - ((runtime.LastPushAt as number | undefined) ?? 0) < 0.55
			) {
				return;
			}
			if (runtime) {
				runtime.LastPushRevision = revision;
				runtime.LastPushAt = now;
			}
			this._state.fire(player, this._trimUnchangedSections(runtime, snapshot, force));
		}
		this._broadcastVisit(player);
	}

	_mutate(player: Player, callback: (profile: Profile) => unknown, incrementRevision?: boolean, label = "legacy"): Response {
		let walletBefore: Record<string, number | string> | undefined;
		let walletAfter: Record<string, number | string> | undefined;
		const [success, result] = this._data.AtomicUpdate(
			player,
			(profile: Profile) => {
				walletBefore = walletSnapshot(profile, K.OmegaMath as never);
				walletAfter = undefined;
				const callbackResult = callback(profile);
				if (isTable(callbackResult) && callbackResult.ok === false) {
					return callbackResult;
				}
				clampProgressionNumbers(profile);
				enforceUnlimitedMoney(profile);

				const [, wouldReject] = this._antiCheat.Observe(player, "Mutation", profile) as LuaTuple<[unknown, unknown]>;
				if (truthy(wouldReject)) {
					// Returning a failed transaction quarantines the whole mutation, including the illegal credit.
					return responseError(T("GameService.ThatEconomyChangeWasRejected"));
				}
				walletAfter = walletSnapshot(profile, K.OmegaMath as never);
				return callbackResult;
			},
			incrementRevision,
			label,
		) as LuaTuple<[unknown, unknown]>;
		if (!truthy(success)) {
			return responseError(T("GuildCommunity.YourProfileIsNotReady"));
		}
		if (!isTable(result) || !typeIs(result.ok, "boolean")) {
			return responseError(T("GameService.CouldnTFinishThat"));
		}
		const runtime = this._runtime.get(player);
		if (result.ok && runtime) {
			runtime.SpecializationPreviewKey = undefined;
		}
		if (result.ok && walletBefore !== undefined && walletAfter !== undefined) {
			this._ledgers().For(player.UserId).Record(label, walletBefore, walletAfter, os.time(), K.OmegaMath as never);
		}
		return result;
	}

	// The economy ledger for every player in the server (see Modules/EconomyLedger).
	_ledgers(): EconomyLedgers {
		if (this._economyLedgers === undefined) {
			this._economyLedgers = new EconomyLedgers();
		}
		return this._economyLedgers;
	}

	_progressAnomalyFromAction(player: Player, action: string) {
		if (!truthy(anomalyChargeByAction[action])) {
			return;
		}
		const runtime = this._runtime.get(player);
		if (!runtime) {
			return;
		}
		runtime.PendingAnomalyActions = orElse(runtime.PendingAnomalyActions, () => []);
		const pending = runtime.PendingAnomalyActions as string[];
		if (pending.size() < 64) {
			pending.push(action);
		}
	}

	_pulseAnomaly(player: Player) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.Pulse(profile, this._random) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: truthy(details.BecameReady) ? "AnomalyReady" : "AnomalyPulse",
				Amount: details.Amount,
				Charge: details.Charge,
				Accurate: details.Accurate,
				Combo: details.Combo,
				PulseWindowStartedAt: details.PulseWindowStartedAt,
			});
			if (truthy(details.OverdriveTriggered)) {
				this._effect.broadcast({ Type: "OverdriveTriggered", Overdrive: K.AnomalyService.OverdriveState() });
			}
		}
		return result;
	}

	_stabilizeAnomaly(player: Player) {
		const [result, details] = anomalyCall(this, player, (profile) => {
			const outcome = K.AnomalyService.Stabilize(profile) as LuaTuple<[unknown, unknown, unknown]>;
			if (truthy(outcome[0])) {
				K.LabService.Progress(profile, "Stabilize", 1);
			}
			return outcome;
		});
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyStabilized",
				AnomalyId: details.AnomalyId,
				AnomalyName: details.AnomalyName,
				Fragments: details.Fragments,
				Stabilizations: details.Stabilizations,
				CoreTier: details.CoreTier,
				CoreXP: details.CoreXP,
				TiersGained: details.TiersGained,
			});
			if (truthy(details.OverdriveTriggered)) {
				this._effect.broadcast({ Type: "OverdriveTriggered", Overdrive: K.AnomalyService.OverdriveState() });
			}
		}
		return result;
	}

	_buyAnomalyProtocol(player: Player, protocolId: unknown) {
		if (!typeIs(protocolId, "string")) {
			return responseError(T("GameService.ChooseAReactorUpgradeAnd"));
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.BuyProtocol(profile, protocolId) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyProtocol",
				ProtocolId: details.ProtocolId,
				ProtocolName: details.ProtocolName,
				Level: details.Level,
			});
		}
		return result;
	}

	_activateAnomalySurge(player: Player) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.ActivateSurge(profile) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalySurge",
				EndsAt: details.EndsAt,
				Duration: details.Duration,
			});
		}
		return result;
	}

	_setAnomalyChannel(player: Player, channelId: unknown) {
		if (!typeIs(channelId, "string")) {
			return responseError(T("GameService.PickAValidReactorChannel"));
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.SetLoadout(profile, [channelId]) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			const loadout = details.Loadout as Record<number, unknown> | undefined;
			const first = truthy(loadout) ? loadout[1] : undefined;
			this._effect.fire(player, {
				Type: "AnomalyLoadout",
				Loadout: details.Loadout,
				Channel: truthy(first) ? first : channelId,
			});
		}
		return result;
	}

	_setAnomalyLoadout(player: Player, rawLoadout: unknown) {
		if (!typeIs(rawLoadout, "table")) {
			return responseError(T("Anomaly.InvalidReactorLoadout"));
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.SetLoadout(profile, rawLoadout) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, { Type: "AnomalyLoadout", Loadout: details.Loadout });
		}
		return result;
	}

	_claimAnomalyMilestone(player: Player, tier: unknown) {
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.ClaimMilestone(profile, tier) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, { Type: "AnomalyMilestone", Tier: details.Tier });
		}
		return result;
	}

	_claimAnomalyDirective(player: Player, directiveId: unknown) {
		if (!typeIs(directiveId, "string")) {
			return responseError(T("GameService.ThatReactorJobIsnT"));
		}
		const [result, details] = anomalyCall(
			this,
			player,
			(profile) => K.AnomalyService.ClaimDirective(profile, directiveId) as LuaTuple<[unknown, unknown, unknown]>,
		);
		if (truthy(result.ok) && truthy(details)) {
			this._effect.fire(player, {
				Type: "AnomalyDirective",
				DirectiveId: details.DirectiveId,
				DirectiveName: details.DirectiveName,
				Fragments: details.Fragments,
			});
		}
		return result;
	}

	// Forge Echoes: every echo action goes through EchoMath's rules in ForgeEchoService.Act
	_echoAct(player: Player, payload: unknown) {
		const op = isTable(payload) && truthy(payload.Op) ? payload.Op : "";
		const result = this._mutate(player, (profile: Profile) => {
			const [ok, message, extra] = K.ForgeEchoService.Act(profile, payload, this._random) as LuaTuple<[unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, extra);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "EchoAct", Op: op });
		}
		return result;
	}

	_collect(player: Player) {
		const result = this._mutate(player, (profile: Profile) => {
			const amount = profile.Vault;
			if (truthy(K.Economy.Lt(amount, 0.01))) {
				return responseError(T("GameService.YourVaultIsStillCharging"));
			}
			profile.Vault = 0;
			profile.Cash = K.Economy.Add(profile.Cash, amount);
			profile.RunCash = K.Economy.Add(profile.RunCash, amount);
			profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, amount);
			const stats = ensureStats(profile);
			stats.Collected = K.Economy.Add(stats.Collected, amount);
			const amountNumber = K.Economy.AsNumber(amount) as number;
			K.ProgressionService.Progress(profile, "EarnCash", amountNumber);
			K.LabService.Progress(profile, "BankFlux", amountNumber);
			K.ProgressionService.AwardCommandXP(profile, math.max(1, math.floor((math.log(amountNumber + 1) / math.log(10)) * 3)));
			K.ProgressionService.AwardForgePathXP(profile, K.ForgePathClaim.XpFromBankedAmount(amountNumber, K.GameConfig.Economy.ForgePathXP));
			K.ForgeEchoService.Record(profile, "Collect", math.clamp(2 + math.log(amountNumber + 1) / math.log(10), 2, 12));
			const extra = this._events.OnCollect(player, amountNumber, K.Economy.AsNumber(K.Economy.Production(profile))) as Dict;
			const notes: string[] = [];
			if ((extra.FluxBonus as number) > 0) {
				const bonus = K.Economy.Mul(amount, extra.FluxBonus);
				profile.Cash = K.Economy.Add(profile.Cash, bonus);
				profile.RunCash = K.Economy.Add(profile.RunCash, bonus);
				profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, bonus);
				notes.push("+" + (K.Format.Number(bonus) as string) + " golden Flux");
			}
			if ((extra.Dust as number) > 0) {
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + (extra.Dust as number), 0, 1e14);
				notes.push(tostring(extra.Dust) + " Stardust");
			}
			if ((extra.Cores as number) > 0) {
				profile.Cores = math.clamp((num(profile.Cores) ?? 0) + (extra.Cores as number), 0, 1e14);
				notes.push(tostring(extra.Cores) + (extra.Cores === 1 ? " core" : " cores"));
			}
			const items = profile.Items as Dict | undefined;
			if ((extra.Keys as number) > 0 && truthy(extra.KeyCrate) && truthy(items) && truthy(items.Keys)) {
				const keys = items.Keys as Dict;
				const crate = extra.KeyCrate as string;
				keys[crate] = (num(keys[crate]) ?? 0) + (extra.Keys as number);
				notes.push("a crate key");
			}
			if (notes.size() > 0) {
				return responseSuccess(T("GameService.BankedSFluxAndFound", (K.Format.Number(amount) as string), notes.join(", ")), {
					Amount: amount,
					Dust: extra.Dust,
					Cores: extra.Cores,
					Keys: extra.Keys,
				});
			}
			return responseSuccess(T("GameService.BankedSFlux", (K.Format.Number(amount) as string)), { Amount: amount });
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "Collect", Amount: result.Amount });
		}
		return result;
	}

	// Op "Catch" (Falling Stars) or "Claim" with Drop (Supply Drop)
	// Event tokens are counted per action in the runtime and written on the 10s maintenance pass.
	_queueEventPoints(player: Player, action: string) {
		if (HotFlags.Get("LimitedEventsPaused")) {
			return;
		}
		const event = liveEvent(os.time());
		const runtime = this._runtime.get(player);
		const points = event !== undefined ? LimitedEvents.pointsFor(event, action) : 0;
		if (runtime !== undefined && points > 0) {
			runtime.EventPoints = ((runtime.EventPoints as number | undefined) ?? 0) + points;
		}
	}

	// Runs inside the maintenance update. Moves the bag onto the current event, pays Stardust for an
	// ended event's leftover tokens, and banks the queued points.
	_settleEventTokens(player: Player, runtime: Runtime, profile: Profile): boolean {
		if (HotFlags.Get("LimitedEventsPaused")) {
			// actions taken while paused don't bank up to pay out when the flag is lifted
			runtime.EventPoints = 0;
			return false;
		}
		const now = os.time();
		const event = liveEvent(now);
		const [moved, refund] = LimitedEvents.ensure(profile, event);
		if (refund > 0) {
			K.ProgressionService.ApplyReward(profile, { Stardust: refund }, undefined);
			task.defer(() =>
				this._toastPlayer(player, T("GameService.EventOver"), T("GameService.YourLeftoverTokensBecameD", refund), "Special"),
			);
		}
		const points = (runtime.EventPoints as number | undefined) ?? 0;
		runtime.EventPoints = 0;
		const added = event !== undefined && points > 0 ? LimitedEvents.earn(profile, event, points, now) : 0;
		return moved || added > 0;
	}

	// Companion Bonds: bank counted taps, crates and play time onto the companion's bond
	_settleCompanionBond(player: Player, runtime: Runtime, profile: Profile): boolean {
		const [changed, evolved] = CompanionBonds.Settle(runtime as Dict, profile as Dict, os.time());
		if (evolved > 0) {
			const name = CompanionRelic.describe(profile.Items)?.Name ?? "";
			task.defer(() =>
				this._toastPlayer(player, T("CompanionBonds.Evolved", name), T("CompanionBonds.EvolvedBody", evolved), "Special"),
			);
		}
		return changed;
	}

	_companionAct(player: Player, payload: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = CompanionBonds.Act(profile as Dict, payload);
			if (!ok) {
				return responseError(message);
			}
			const name = CompanionRelic.describe(profile.Items)?.Name ?? "";
			return responseSuccess(T("CompanionBonds.PickedTrait", name, message), { Trait: message });
		});
	}

	_buyEventItem(player: Player, itemId: unknown) {
		const now = os.time();
		const event = liveEvent(now);
		if (event === undefined || HotFlags.Get("LimitedEventsPaused")) {
			return responseError(T("GameService.TheEventStallIsClosed"));
		}
		let refunded = 0;
		const result = this._mutate(player, (profile: Profile) => {
			// a bag still on the previous event is moved here too, so its leftover tokens are paid out
			// rather than dropped when the stall is used before the next maintenance pass
			const [, refund] = LimitedEvents.ensure(profile, event);
			if (refund > 0) {
				K.ProgressionService.ApplyReward(profile, { Stardust: refund }, undefined);
				refunded = refund;
			}
			const [item, reason] = LimitedEvents.buy(profile, event, itemId);
			if (item === undefined) {
				if (refunded > 0) {
					// keep the move and the refund even though the purchase itself was refused
					return responseSuccess(T("GameService.YourLeftoverTokensBecameD2", refunded, reason ?? ""), {
						Refund: refunded,
					});
				}
				return responseError(reason ?? T("GameService.ThatIsnTSoldAt"));
			}
			const text = K.ProgressionService.ApplyReward(profile, item.Reward, K.Economy.Production(profile));
			return responseSuccess(T("GameService.BoughtSS", item.Name, tostring(text)), { Item: item.Id });
		});
		return result;
	}

	_eventAct(player: Player, payload: unknown) {
		const op = isTable(payload) ? payload.Op : undefined;
		if (op === "Catch") {
			const [dust, reason] = this._events.CatchStar(player) as LuaTuple<[number | undefined, unknown]>;
			if (dust === undefined) {
				return responseError(orElse(reason, () => "Missed."));
			}
			return this._mutate(player, (profile: Profile) => {
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + dust, 0, 1e14);
				return responseSuccess(undefined, { Dust: dust });
			});
		} else if (op === "Buy") {
			return this._buyEventItem(player, (payload as Dict).Item);
		} else if (op === "Claim") {
			const [reward, reason] = this._events.ClaimSupply(player, (payload as Dict).Drop) as LuaTuple<[Dict | undefined, unknown]>;
			if (reward === undefined) {
				return responseError(orElse(reason, () => T("GameService.MissedIt")));
			}
			return this._mutate(player, (profile: Profile) => {
				const rewardDust = orElse(reward.Stardust, () => 0) as number;
				profile.Stardust = math.clamp((num(profile.Stardust) ?? 0) + rewardDust, 0, 1e14);
				const items = profile.Items as Dict | undefined;
				if ((orElse(reward.Keys, () => 0) as number) > 0 && truthy(items) && truthy(items.Keys)) {
					const keys = items.Keys as Dict;
					const crate = reward.KeyCrate as string;
					keys[crate] = (num(keys[crate]) ?? 0) + (reward.Keys as number);
				}
				return responseSuccess(T("GameService.GotItACrateKey2", tostring(rewardDust)), {
					Dust: reward.Stardust,
					Keys: reward.Keys,
				});
			});
		}
		return responseError(T("GameService.UnknownEventAction"));
	}

	_craftRelic(player: Player, definitionId: unknown, sacrificeUid: unknown) {
		if (HotFlags.Get("RecipesPaused")) {
			return responseError(T("RelicRecipes.TheBenchIsClosed"));
		}
		return this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const definition = typeIs(definitionId, "string") ? (itemById[definitionId] as Dict | undefined) : undefined;
			const [chosen, reason] = RelicRecipes.plan(
				profile as Dict,
				definition as unknown as RelicRecipes.RecipeDefinition | undefined,
				sacrificeUid,
				now,
				(id) => (typeIs(id, "string") && itemById[id] !== undefined ? ((itemById[id] as Dict).Rarity as string) : undefined),
				K.GameConfig.Items.InventoryLimit as number,
			);
			if (chosen === undefined) {
				return responseError(reason);
			}
			RelicRecipes.pay(profile as Dict, definitionId as string, chosen, now);
			const uid = this._createItem(profile, definitionId as string);
			if (uid === undefined) {
				// can't happen after plan() (the sacrifice or the bag check left room), but never pay for nothing
				return responseError(T("RelicRecipes.YourRelicBagIsFull"));
			}
			bumpStat(profile, "RelicsCrafted", 1);
			return responseSuccess(T("RelicRecipes.SForged", definition!.Name as string), {
				Uid: uid,
				DefinitionId: definitionId,
				Rarity: definition!.Rarity,
			});
		});
	}

	_engraveRelic(player: Player, payload: Dict | undefined) {
		if (HotFlags.Get("EngravingPaused")) {
			return responseError(T("RelicEngraving.TheEngraverIsAway"));
		}
		const uid = payload?.Uid;
		const line = payload?.Line;
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const instance = typeIs(uid, "string") ? ((items.Inventory as Dict)[uid] as Dict | undefined) : undefined;
			const definition = instance !== undefined ? (itemById[instance.DefinitionId as string] as Dict | undefined) : undefined;
			if (instance === undefined || definition === undefined) {
				return responseError(T("RelicEngraving.ThatRelicIsnTYours"));
			}
			if (payload?.Op === "Lock") {
				const [ok, message] = RelicEngraving.toggleLock(instance, definition.Rarity, line);
				return ok ? responseSuccess(message, { Uid: uid, Engraving: instance.Engraving }) : responseError(message);
			}
			const ore = profile.Ore as Dict;
			const wallet = { Essence: num(items.Essence) ?? 0, Starsteel: num(ore.Starsteel) ?? 0 };
			const [ok, message] = RelicEngraving.roll(instance, definition, line, wallet, () => this._random.NextNumber());
			if (!ok) {
				return responseError(message);
			}
			items.Essence = wallet.Essence;
			ore.Starsteel = wallet.Starsteel;
			bumpStat(profile, "RelicsEngraved", 1);
			return responseSuccess(message, { Uid: uid, Engraving: instance.Engraving });
		});
	}

	_constellationAct(player: Player, payload: Dict | undefined) {
		if (payload?.Op !== "Light") {
			return responseError(T("Constellations.UnknownAction"));
		}
		if (HotFlags.Get("ConstellationsPaused")) {
			return responseError(T("Constellations.ChartsArePaused"));
		}
		return this._mutate(player, (profile: Profile) => {
			rebirthLedger(profile, os.time());
			const [ok, message] = Constellations.light(profile as Dict, payload.Star);
			return ok ? responseSuccess(message, { Star: payload.Star }) : responseError(message);
		});
	}

	_overchargeCombo(runtime: Runtime | undefined, profile: unknown): LuaTuple<[number, number]> {
		if (!runtime) {
			return $tuple(0, 1);
		}
		const combo = math.max(0, math.floor(num(runtime.TapCombo) ?? 0));
		if (
			combo > 0 &&
			os.clock() - (num(runtime.LastTap) ?? 0) > overchargeComboWindow(profile) * (this._events.ComboWindowMultiplier() as number)
		) {
			return $tuple(0, 1);
		}
		return $tuple(combo, overchargeComboMultiplier(profile, combo));
	}

	_overcharge(player: Player) {
		return BoostDomain.overcharge(this, player);
	}

	_buyMachine(player: Player, machineId: unknown, requestedAmount?: unknown) {
		if (!typeIs(machineId, "string")) {
			return responseError(T("GameService.InvalidMachineRequest"));
		}
		const machineFound = K.Economy.GetMachine(machineId);
		if (!truthy(machineFound)) {
			return responseError(T("GameService.ThatMachineDoesNotExist"));
		}
		const machine = machineFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const machines = profile.Machines as Dict;
			const level = orElse(machines[machineId], () => 0) as number;
			if (level >= (machine.MaxLevel as number)) {
				return responseError(T("GameService.ThatMachineIsAlreadyAt"));
			}
			const lockReason = K.ProgressionGate.UpgradeReason(profile, machine, profile.Machines);
			if (truthy(lockReason)) {
				return responseError((lockReason as string) + " first.");
			}
			const remainingLevels = (machine.MaxLevel as number) - level;
			let count: number;
			let cost: unknown;
			if (requestedAmount === "Max") {
				[count, cost] = K.Economy.AffordableMachineLevels(machineId, level, profile.Cash, remainingLevels) as LuaTuple<[number, unknown]>;
			} else {
				count = typeIs(requestedAmount, "number") ? math.clamp(math.floor(requestedAmount), 1, 50) : 1;
				count = math.min(count, remainingLevels);
				cost = K.Economy.MachineBulkCost(machineId, level, count);
			}
			if (count < 1) {
				return responseError(T("GameService.YouCannotAffordAnotherLevel"));
			}
			if (truthy(K.Economy.Lt(profile.Cash, cost))) {
				return responseError(T("GameService.YouNeedSMoreFlux", (K.Format.Number(K.Economy.Sub(cost, profile.Cash)) as string)));
			}
			profile.Cash = K.Economy.Sub(profile.Cash, cost);
			machines[machineId] = level + count;
			bumpStat(profile, "MachinesBought", count);
			K.LabService.Progress(profile, "BuyLevels", count);
			const mastery = ensureCommandMastery(profile);
			mastery[machineId] = (num(mastery[machineId]) ?? 0) + count;
			K.ProgressionService.Progress(profile, "BuyMachine", count);
			K.ProgressionService.AwardCommandXP(profile, count * 5);
			K.ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12));
			return responseSuccess("%s gained %d levels and reached level %d.".format(machine.Name as string, count, level + count));
		});
		return result;
	}

	_queueStatePush(player: Player) {
		if (this._queuedStatePushes.get(player)) {
			return;
		}
		this._queuedStatePushes.set(
			player,
			task.defer(() => {
				this._queuedStatePushes.delete(player);
				if (this._running && player.Parent === Players) {
					this._pushState(player);
				}
			}),
		);
	}

	_setAutoForge(player: Player, payload: unknown) {
		if (!isTable(payload) || !typeIs(payload.Enabled, "boolean")) {
			return responseError(T("GameService.ChooseAValidAutoForge"));
		}
		const machineFound = K.Economy.GetMachine(payload.MachineId);
		if (!truthy(machineFound)) {
			return responseError(T("GameService.ThatMachineCannotBeQueued"));
		}
		const machine = machineFound as Dict;
		const reserve = math.clamp(num(payload.Reserve) ?? 0.25, 0, 0.9);
		const enabled = payload.Enabled;
		return this._mutate(player, (profile: Profile) => {
			profile.AutoForge = orElse(profile.AutoForge, () => ({}));
			const autoForge = profile.AutoForge as Dict;
			autoForge.Enabled = enabled;
			autoForge.MachineId = machine.Id;
			autoForge.Reserve = reserve;
			autoForge.Bought = math.max(0, math.floor(num(autoForge.Bought) ?? 0));
			const state = enabled ? "online" : "paused";
			return responseSuccess(
				T("GameService.AutoForgeSBuyingS", state, machine.Name as string, math.floor(reserve * 100 + 0.5)),
			);
		});
	}

	// Forge Programs: carry out the rules that are due, each through the same action a button uses
	_tickForgePrograms(player: Player, runtime: Runtime) {
		return Automation.tickForgePrograms(this, player, runtime);
	}

	_programAct(player: Player, payload: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = ForgeProgramsService.Act(profile as Dict, payload);
			return ok ? responseSuccess(message) : responseError(message);
		});
	}

	_tickAutoForge(player: Player) {
		return Automation.tickAutoForge(this, player);
	}

	_buyResearch(player: Player, researchId: unknown, requestedAmount?: unknown) {
		if (!typeIs(researchId, "string")) {
			return responseError(T("GameService.InvalidResearchRequest"));
		}
		const researchFound = K.Economy.GetResearch(researchId);
		if (!truthy(researchFound)) {
			return responseError(T("GameService.ThatResearchProjectDoesNot"));
		}
		const research = researchFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const researchLevels = profile.Research as Dict;
			const level = orElse(researchLevels[researchId], () => 0) as number;
			if (level >= (research.MaxLevel as number)) {
				return responseError(T("GameService.ThatResearchIsAlreadyComplete"));
			}
			const lockReason = K.ProgressionGate.UpgradeReason(profile, research, profile.Research);
			if (truthy(lockReason)) {
				return responseError((lockReason as string) + " first.");
			}
			const remainingLevels = (research.MaxLevel as number) - level;
			let count: number;
			let cost: unknown;
			if (requestedAmount === "Max") {
				[count, cost] = K.Economy.AffordableResearchLevels(researchId, level, profile.Cash, remainingLevels) as LuaTuple<[number, unknown]>;
			} else {
				count = typeIs(requestedAmount, "number") ? math.clamp(math.floor(requestedAmount), 1, 50) : 1;
				count = math.min(count, remainingLevels);
				cost = K.Economy.ResearchBulkCost(researchId, level, count);
			}
			if (count < 1) {
				return responseError(T("GameService.YouCannotAffordAnotherResearch"));
			}
			if (truthy(K.Economy.Lt(profile.Cash, cost))) {
				return responseError(T("GameService.YouNeedSMoreFlux", (K.Format.Number(K.Economy.Sub(cost, profile.Cash)) as string)));
			}
			profile.Cash = K.Economy.Sub(profile.Cash, cost);
			researchLevels[researchId] = level + count;
			bumpStat(profile, "ResearchBought", count);
			K.LabService.Progress(profile, "BuyLevels", count);
			K.ProgressionService.Progress(profile, "BuyResearch", count);
			K.ProgressionService.AwardCommandXP(profile, count * 4);
			K.ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.7, 2, 12));
			return responseSuccess("%s gained %d levels and reached level %d.".format(research.Name as string, count, level + count));
		});
		return result;
	}

	_unlockZone(player: Player, rawZoneId: unknown) {
		let zoneId = rawZoneId;
		if (typeIs(zoneId, "string")) {
			zoneId = num(zoneId);
		}
		if (!typeIs(zoneId, "number")) {
			return responseError(T("GameService.InvalidWorldRequest"));
		}
		const zoneNumber = math.floor(zoneId + 0.5);
		const zoneFound = K.Economy.GetZone(zoneNumber);
		if (!truthy(zoneFound)) {
			return responseError(T("GameService.ThatWorldDoesNotExist"));
		}
		const zone = zoneFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			const [kind, err] = K.ZoneUnlock.Evaluate(
				profile.Zone,
				profile.Rebirths,
				profile.Cores,
				profile.Cash,
				zoneNumber,
				zone,
				K.Economy.Lt,
			) as LuaTuple<[unknown, unknown]>;
			if (kind === "Travel") {
				profile.CurrentZone = zoneNumber;
				return responseSuccess(T("GameService.TraveledToS", (zone.Name as string)));
			}
			if (kind === "Error") {
				if (err === "NEED_MORE_FLUX") {
					return responseError(T("GameService.YouNeedSMoreFlux", (K.Format.Number(K.Economy.Sub(zone.Cost, profile.Cash)) as string)));
				}
				return responseError(err as string);
			}
			profile.Cash = K.Economy.Sub(profile.Cash, zone.Cost);
			profile.Zone = zoneNumber;
			profile.CurrentZone = zoneNumber;
			K.LabService.Progress(profile, "UnlockWorld", 1);
			K.ForgeEchoService.Record(profile, "Explore", 12);
			return responseSuccess(T("GameService.UnlockedSAndItsProduction", (zone.Name as string)));
		});
		return result;
	}

	_selectZone(player: Player, rawZoneId: unknown) {
		let zoneId = rawZoneId;
		if (typeIs(zoneId, "string")) {
			zoneId = num(zoneId);
		}
		if (!typeIs(zoneId, "number")) {
			return responseError(T("GameService.InvalidWorldRequest"));
		}
		const zoneNumber = math.floor(zoneId + 0.5);
		const zoneFound = K.Economy.GetZone(zoneNumber);
		if (!truthy(zoneFound)) {
			return responseError(T("GameService.ThatWorldDoesNotExist"));
		}
		const zone = zoneFound as Dict;
		const result = this._mutate(player, (profile: Profile) => {
			if (zoneNumber > (profile.Zone as number)) {
				return responseError(T("GameService.UnlockThatWorldFirst"));
			}
			profile.CurrentZone = zoneNumber;
			return responseSuccess(T("GameService.TraveledToS", (zone.Name as string)));
		});
		return result;
	}

	_rebirthPublic(profile: Profile, now: number): Dict {
		const ledger = rebirthLedger(profile, now);
		const [run, bank] = rebirthRun(profile, now, ledger) as LuaTuple<[Dict, unknown]>;
		const [reward, dust] = rebirthBase(profile, bank) as LuaTuple<[unknown, number]>;
		const quote = K.RebirthMath.quote(
			ledger,
			{
				Cores: truthy(reward) ? K.Economy.AsNumber(reward) : 0,
				Stardust: dust,
			},
			run,
		) as Dict;
		const [holds, status] = K.RebirthMath.vowHolds(ledger, run) as LuaTuple<[unknown, unknown]>;
		const [, nextStar] = K.RebirthMath.nextStar(ledger) as LuaTuple<[unknown, unknown]>;
		return {
			Ready: reward !== undefined,
			Cores: truthy(reward) ? K.Economy.Max(1, K.Economy.Floor(K.Economy.Mul(reward, quote.CoreMultiplier))) : 0,
			Stardust: truthy(reward) ? quote.Stardust : 0,
			Grade: quote.Grade,
			Vow: ledger.Vow,
			VowHolds: holds,
			VowStatus: status,
			VowOpen: now <= (ledger.RunStartedAt as number) + (K.RebirthMath.VOW_GRACE as unknown as number),
			KeptVows: table.clone(ledger.Kept as object),
			RunStartedAt: ledger.RunStartedAt,
			Lifetime: ledger.Lifetime,
			Stars: table.clone(ledger.Stars as object),
			Pending: K.RebirthMath.pendingStars(ledger),
			NextStar: nextStar,
			Keep: table.clone(ledger.Keep as object),
			KeepSlots: K.RebirthMath.keepSlots(ledger.Lifetime),
			Runs: table.clone(ledger.Runs as object),
			BestCores: ledger.BestCores,
			FastestSeconds: ledger.FastestSeconds,
		};
	}

	_rebirth(player: Player, rawPayload: unknown) {
		return Rebirth.rebirth(this, player, rawPayload);
	}

	// between rebirths: light a star, swear or drop a vow, choose keepsakes
	_rebirthAct(player: Player, rawPayload: unknown) {
		if (!typeIs(rawPayload, "table")) {
			return responseError(T("GameService.InvalidRebirthRequest"));
		}
		const payload = rawPayload as Dict;
		return this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const ledger = rebirthLedger(profile, now);
			if (payload.Op === "Star") {
				const rawIndex = tonumber(payload.Index) ?? 0;
				const rawPick = tonumber(payload.Pick) ?? 0;
				const index = rawIndex === rawIndex && math.abs(rawIndex) !== math.huge ? math.floor(rawIndex) : 0;
				const pick = rawPick === rawPick && math.abs(rawPick) !== math.huge ? math.floor(rawPick) : 0;
				const [ok, message] = K.RebirthMath.pickStar(ledger, index, pick) as LuaTuple<[unknown, unknown]>;
				if (!truthy(ok)) {
					return responseError(message);
				}
				return responseSuccess(T("GameService.StarLitS", tostring(message)), { Star: index });
			} else if (payload.Op === "Vow") {
				const [ok, message] = K.RebirthMath.swear(ledger, typeIs(payload.Vow, "string") ? payload.Vow : "", now) as LuaTuple<
					[unknown, unknown]
				>;
				if (!truthy(ok)) {
					return responseError(message);
				}
				return responseSuccess(message, { Vow: ledger.Vow });
			} else if (payload.Op === "Keep") {
				if (!truthy(K.RebirthMath.setKeep(ledger, payload.Keep))) {
					return responseError(T("GameService.PickMachinesToKeep"));
				}
				return responseSuccess(T("GameService.KeepsakesSet"), { Keep: table.clone(ledger.Keep as object) });
			}
			return responseError(T("GameService.UnknownRebirthAction"));
		});
	}

	_claimQuest(player: Player, questId: unknown) {
		if (!typeIs(questId, "string")) {
			return responseError(T("GameService.InvalidMissionRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimQuest(profile, questId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimAchievement(player: Player, achievementId: unknown) {
		if (!typeIs(achievementId, "string")) {
			return responseError(T("GameService.InvalidMilestoneRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimAchievement(profile, achievementId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimDaily(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimDaily(profile) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimTimedReward(player: Player, rewardIndex: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimTimedReward(profile, rewardIndex) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_bazaarPlay(player: Player, payload: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const now = os.time();
			const [recovered, recoveryMessage] = K.BazaarService.Roll(profile, now, player.UserId) as LuaTuple<[unknown, unknown]>;
			if (!truthy(recovered)) {
				return responseError(recoveryMessage);
			}
			const [ok, message, extra] = K.BazaarService.Play(profile, this._random, payload, now, player.UserId) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, { Result: extra });
		});
	}

	_spinWheel(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (!typeIs(rawPayload, "table") || !typeIs(payload!.ExpectedSpin, "number")) {
			return responseError(T("Progression.RefreshTheWheelBeforeSpinning"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, prizeIndex, prizeId, pityHit] = K.ProgressionService.SpinWheel(
				profile,
				this._random,
				payload!.ExpectedSpin,
			) as LuaTuple<[unknown, unknown, unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			return responseSuccess(message, {
				PrizeIndex: prizeIndex,
				PrizeId: prizeId,
				Pity: pityHit === true,
			});
		});
	}

	_launchExpedition(player: Player, expeditionId: unknown) {
		if (!typeIs(expeditionId, "string")) {
			return responseError(T("GameService.InvalidExpeditionRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			// v7 single-slot remote: an alias for board slot 1
			const [ok, message] = ExpeditionBoardService.Launch(profile as Dict, { Slot: 1, Id: expeditionId });
			return ok ? responseSuccess(message) : responseError(message);
		});
	}

	_claimExpedition(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			// v7 single-slot remote: an alias for board slot 1
			const [ok, message, extra] = ExpeditionBoardService.Claim(profile as Dict, { Slot: 1 }, this._random);
			return ok ? responseSuccess(message, { ArtifactId: extra?.ArtifactId, ArtifactNew: extra?.ArtifactNew }) : responseError(message);
		});
	}

	// Expedition Board: Launch / Claim / Recall on any slot
	_expeditionAct(player: Player, payload: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, extra] = ExpeditionBoardService.Act(profile as Dict, payload, this._random);
			return ok ? responseSuccess(message, extra) : responseError(message);
		});
	}

	_equipArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError(T("GameService.InvalidArtifactRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.EquipArtifact(profile, artifactId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_buyArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError(T("GameService.InvalidArtifactRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, fresh] = K.ProgressionService.BuyArtifact(profile, artifactId) as LuaTuple<[unknown, unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message, { ArtifactId: artifactId, ArtifactNew: fresh }) : responseError(message);
		});
	}

	_upgradeArtifact(player: Player, artifactId: unknown) {
		if (!typeIs(artifactId, "string")) {
			return responseError(T("GameService.InvalidArtifactRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.UpgradeArtifact(profile, artifactId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_upgradeCrew(player: Player, roleId: unknown) {
		if (!typeIs(roleId, "string")) {
			return responseError(T("GameService.InvalidCrewRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.UpgradeCrew(profile, roleId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimCommanderReward(player: Player, level: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimCommanderReward(profile, level) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimWeeklyDirective(player: Player, directiveId: unknown) {
		if (!typeIs(directiveId, "string")) {
			return responseError(T("GameService.InvalidWeeklyDirective"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimWeeklyDirective(profile, directiveId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimSeasonTier(player: Player, tier: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimSeasonTier(profile, tier) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimSeasonPremium(player: Player, tier: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimSeasonPremium(profile, tier) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_claimForgePathStep(player: Player, step: unknown) {
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.ClaimForgePathStep(profile, step) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_buySignalOffer(player: Player, offerId: unknown) {
		if (!typeIs(offerId, "string")) {
			return responseError(T("GameService.InvalidSignalShopOffer"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.BuySignalOffer(profile, offerId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_equipTitle(player: Player, titleId: unknown) {
		const operations = K.GameConfig.Operations as Dict;
		if (operations.TitlesEnabled === false) {
			return responseError((operations.TitleStatus as string | undefined) ?? T("GameService.TitlesAreTemporarilyUnavailable"));
		}
		if (!typeIs(titleId, "string")) {
			return responseError(T("GameService.InvalidTitleRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.ProgressionService.EquipTitle(profile, titleId) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_setProfileStyle(player: Player, accent: unknown, frame: unknown) {
		if ((accent !== undefined && !typeIs(accent, "string")) || (frame !== undefined && !typeIs(frame, "string"))) {
			return responseError(T("GameService.InvalidProfileStyle"));
		}
		let saved: ProfileStyle.ProfileStyleState | undefined;
		const result = this._mutate(player, (profile: Profile) => {
			saved = undefined;
			const current = ProfileStyle.read(profile.Cosmetics);
			const [chosen, problem] = ProfileStyle.validate(current, accent, frame, ProfileStyle.factsOf(profile));
			if (chosen === undefined) {
				return responseError(problem ?? T("GameService.ThatStyleIsNotAvailable"));
			}
			if (!isTable(profile.Cosmetics)) {
				profile.Cosmetics = { CrateSkins: { Classic: true }, CrateSkin: "Classic" };
			}
			const cosmetics = profile.Cosmetics as Dict;
			cosmetics.ProfileAccent = chosen.Accent;
			cosmetics.ProfileFrame = chosen.Frame;
			saved = chosen;
			return responseSuccess(T("GameService.ProfileStyleSaved"));
		});
		// publish only once the transaction committed, so other players never see an unsaved style
		if (result.ok === true && saved !== undefined) {
			player.SetAttribute("ProfileAccent", saved.Accent);
			player.SetAttribute("ProfileFrame", saved.Frame);
		}
		return result;
	}

	_redeemCode(player: Player, rawCode: unknown) {
		if (!typeIs(rawCode, "string")) {
			return responseError(T("GameService.EnterAValidCode"));
		}
		const code = string.upper(string.gsub(rawCode, "%s+", "")[0]);
		if (code.size() < 1 || code.size() > 24) {
			return responseError(T("GameService.EnterAValidCode"));
		}
		const codeData = (K.ServerConfig.Codes as Dict)[code] as Dict | undefined;
		if (codeData === undefined) {
			return responseError(T("GameService.ThatCodeIsInvalidOr"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.Codes, "table")) {
				profile.Codes = {};
			}
			const codes = profile.Codes as Dict;
			if (truthy(codes[code])) {
				return responseError(T("GameService.YouAlreadyRedeemedThatCode"));
			}
			codes[code] = true;
			const rewardText = K.ProgressionService.ApplyReward(profile, codeData.Reward, K.Economy.Production(profile));
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_grantDevProduct(profile: Profile, productDef: Dict): string {
		return K.ProgressionService.ApplyReward(profile, productDef.Reward, K.Economy.Production(profile)) as string;
	}

	_processReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision {
		const player = Players.GetPlayerByUserId(receiptInfo.PlayerId as number);
		if (player === undefined) {
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		const productDef = (K.MonetizationConfig.FindDevProductByProductId as Fn)(receiptInfo.ProductId) as Dict | undefined;
		if (productDef === undefined) {
			K.ModuleLog.Warn("Shop", string.format("unknown ProductId %s", tostring(receiptInfo.ProductId)));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		const purchaseKey = tostring(receiptInfo.PurchaseId);
		let outcome = { kind: "duplicate" } as PurchaseReceiptOutcome;
		const [updated] = this._data.Update(player, (profile: Profile) => {
			outcome = Deps.Purchases.applyReceipt(profile, purchaseKey, os.time(), () => this._grantDevProduct(profile, productDef));
		}) as LuaTuple<[unknown]>;
		if (!truthy(updated)) {
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}

		if (!truthy(this._data.Save(player, false))) {
			K.ModuleLog.Warn("Shop", string.format("receipt %s is waiting on a save", purchaseKey));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		}
		// A duplicate means Roblox retried a receipt we already paid out (usually after a slow save).
		if (outcome.kind === "granted") {
			const rewardText = outcome.rewardText;
			this._syncLeaderstats(player, this._data.Get(player) as Profile | undefined);
			this._pushState(player);
			this._toastPlayer(player, T("Toast.PurchaseCompleteTitle"), rewardText !== "" ? rewardText : (productDef.Name as string), "Special");
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return Enum.ProductPurchaseDecision.PurchaseGranted;
	}

	_syncShop(player: Player) {
		const ownedPasses = new Set<string>();
		for (const passDef of K.MonetizationConfig.GamePasses as Dict[]) {
			if ((passDef.PassId as number) > 0) {
				const [ok, owns] = pcall(() => MarketplaceService.UserOwnsGamePassAsync(User.fromId(player.UserId), passDef.PassId as number));
				if (ok && truthy(owns)) {
					ownedPasses.add(passDef.Key as string);
				}
			}
		}

		if (!this._running || player.Parent !== Players || this._runtime.get(player) === undefined) {
			return responseError(T("GameService.ThatForgeSessionIsNo"));
		}
		return this._mutate(player, (profile: Profile) => {
			Deps.Purchases.ensureTables(profile);
			for (const passKey of ownedPasses) {
				(profile.OwnedPasses as Dict)[passKey] = true;
			}
			return responseSuccess(T("GameService.DockInventorySynced"));
		});
	}

	// MarketplaceService.PromptGamePassPurchaseFinished fires on the server with the real result, so
	// a pass bought mid-session is granted right away instead of waiting on UserOwnsGamePassAsync,
	// which caches ownership and can still say "no" for a while after the purchase.
	_grantPurchasedPass(player: Player, rawPassId: unknown, purchased: unknown) {
		if (purchased !== true || !typeIs(rawPassId, "number")) {
			return responseError(T("GameService.NoPassPurchaseToGrant"));
		}
		const passDef = (K.MonetizationConfig.FindPassByPassId as Fn)(rawPassId) as Dict | undefined;
		if (passDef === undefined) {
			return responseError(T("GameService.UnknownPass"));
		}
		if (!this._running || player.Parent !== Players || this._runtime.get(player) === undefined) {
			return responseError(T("GameService.ThatForgeSessionIsNo"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			const grant = Deps.Purchases.grantPass(profile, passDef as unknown as PurchasePassDef);
			return responseSuccess(grant.name + (grant.granted ? " unlocked." : " already owned."));
		});
		if (truthy((result as Dict | undefined)?.ok)) {
			this._pushState(player);
		}
		return result;
	}

	_studioGrantProduct(player: Player, rawKey: unknown) {
		if (!truthy(K.ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return responseError(T("GameService.StudioGrantsAreDisabledIn2"));
		}
		if (!typeIs(rawKey, "string")) {
			return responseError(T("GameService.InvalidProductKey"));
		}
		const productDef = (K.MonetizationConfig.FindDevProductByKey as Fn)(rawKey) as Dict | undefined;
		const passDef = (K.MonetizationConfig.FindPassByKey as Fn)(rawKey) as Dict | undefined;
		if (productDef === undefined && passDef === undefined) {
			return responseError(T("GameService.UnknownStudioProductOrPass"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			if (passDef !== undefined) {
				const pass = passDef as unknown as PurchasePassDef;
				const grant = Deps.Purchases.grantPass(profile, pass);
				return responseSuccess(grant.granted ? pass.Name + ": " + Deps.Purchases.passPerks(pass) : pass.Name + " already owned.");
			}
			assert(productDef !== undefined, "studio grant missing product");
			const rewardText = this._grantDevProduct(profile, productDef);
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, T("GameService.PurchaseTest"), truthy(result.message) ? result.message : rawKey, "Success");
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_activateBoost(player: Player, boostId: unknown, buy?: unknown) {
		if (!typeIs(boostId, "string") || !truthy(K.GameConfig.Boosts[boostId])) {
			return responseError(T("GameService.InvalidBoostRequest"));
		}
		const boost = K.GameConfig.Boosts[boostId] as Dict;
		return this._mutate(player, (profile: Profile) => {
			const active = ensureActiveBoost(profile) as Dict;
			if ((active.EndsAt as number) > os.time()) {
				return responseError(T("GameService.AnotherBoostIsAlreadyActive"));
			}
			const inventory = ensureBoostInventory(profile) as Dict;
			if ((tonumber(inventory[boostId]) ?? 0) < 1) {
				// BALANCE v8 Stardust sink: run it now for Stardust instead of an owned charge
				const price = buy === true ? stardustBoostPrice(profile, boostId) : undefined;
				if (price === undefined) {
					return responseError(T("GameService.YouDoNotOwnThat"));
				}
				const stardust = num(profile.Stardust) ?? 0;
				if (stardust < price) {
					return responseError(T("GameService.YouNeedSMoreStardust", (K.Format.Number as Fn)(price - stardust)));
				}
				profile.Stardust = stardust - price;
				profile.ActiveBoost = { Id: boostId, EndsAt: os.time() + (boost.Duration as number) };
				return responseSuccess((boost.Name as string) + " is running.");
			}
			inventory[boostId] = math.max(0, math.floor(tonumber(inventory[boostId]) ?? 0) - 1);
			profile.ActiveBoost = { Id: boostId, EndsAt: os.time() + (boost.Duration as number) };
			return responseSuccess((boost.Name as string) + " is running.");
		});
	}

	_createItem(profile: Profile, definitionId: string): string | undefined {
		const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
		if (itemById[definitionId] === undefined || (inventoryCount(profile) as number) >= (K.GameConfig.Items.InventoryLimit as number)) {
			return undefined;
		}
		const uid = RelicModel.add(items, definitionId, os.time());
		bumpStat(profile, "ItemsFound", 1);
		return uid;
	}

	// Each roll draws from its own seeded stream (Modules/CrateRng); the seed is kept on
	// _lastCrateRoll so a disputed or odd roll can be replayed exactly.
	_lastCrateRoll: CrateRollRecord<Dict> | undefined;

	_rollItemDefinition(crate: Dict, pity: number) {
		const record = crateRoll<Dict>(
			this._random.NextInteger(0, 0x7fffffff),
			crate as never,
			pity,
			K.GameConfig.Items.Rarities as never,
			K.GameConfig.Items.Definitions as never,
			(definition: Dict) => definition.Rarity as string,
			K.CrateConfig.RarityOrder as never,
			K.CrateConfig.MinimumRollInterval as never,
		);
		this._lastCrateRoll = record;
		return $tuple(record.Definition, record.Rarity, record.PityHit);
	}

	// Abuse patterns that are only visible across requests. Each one is a flag, never a rejection
	// on its own: the request's own validation already decided whether it goes through.
	_flagFailedRequest(player: Player, action: string) {
		const category = ActionBuckets.CategoryOf(action);
		if (category === "Purchase" && Ledger.Burst("buy-fail:" + player.UserId, 20, 15)) {
			Report(player, "purchase-probing", 1.5, "more than 15 refused purchases in 20s, last " + action);
		} else if (category === "Trade" && Ledger.Burst("trade-fail:" + player.UserId, 30, 15)) {
			Report(player, "trade-probing", 1.5, "more than 15 refused trade requests in 30s, last " + action);
		}
	}

	_flagTradeInvite(player: Player, targetUserId: unknown) {
		const key = "trade-invite:" + player.UserId + ":" + tostring(targetUserId);
		// a repeat invite to the same player is one entry; fan-out to many different players is the signal
		if (!Ledger.Burst(key, 60, 1)) {
			if (Ledger.Burst("trade-invite-fanout:" + player.UserId, 60, 8)) {
				Report(player, "trade-invite-spam", 2, "trade invites to more than 8 players in 60s");
			}
		}
	}

	_buyItemOffer(player: Player, offerId: unknown) {
		if (!typeIs(offerId, "string") || itemOfferById[offerId] === undefined) {
			return responseError(T("GameService.ThatMarketOfferDoesNot"));
		}
		const offer = itemOfferById[offerId] as Dict;
		const policyNote = PolicyGate.OfferBlocked(player, offer);
		if (policyNote !== undefined) {
			return responseError(policyNote);
		}
		return this._mutate(player, (profile: Profile) => {
			const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
			ensureItemShop(profile);
			const stockMax = offerStockMax(offer);
			const shop = items.Shop as Dict;
			const stock = shop.Stock as Dict;
			const purchased = shop.Purchased as Dict;
			const remaining = K.ShopGrantEligibility.RemainingStock(stock[offerId], stockMax);
			const [eligible, denyReason] = K.ShopGrantEligibility.EvaluateBuy(
				offer,
				remaining,
				inventoryCount(profile),
				K.GameConfig.Items.InventoryLimit,
				// Cash above 1e15 persists as an Omega string; compare it as a number
				offer.Currency === "Cash" ? progressionNumber(profile.Cash) : profile[offer.Currency as string],
				(need: unknown, currency: unknown) =>
					string.format("You need %s more %s.", (K.Format.Number as Fn)(need) as string, tostring(currency)),
			) as LuaTuple<[unknown, unknown]>;
			if (!truthy(eligible)) {
				return responseError(truthy(denyReason) ? denyReason : T("GameService.ThatMarketOfferIsUnavailable"));
			}
			const currency = offer.Currency as string;
			if (currency === "Cash") {
				profile.Cash = K.Economy.Sub(profile.Cash, offer.Price as number);
			} else {
				profile[currency] = (profile[currency] as number) - (offer.Price as number);
			}
			const keys = items.Keys as Dict;
			let itemUid: string | undefined;
			if (offer.Kind === "Key") {
				keys[offer.CrateId as string] = ((keys[offer.CrateId as string] as number | undefined) ?? 0) + (offer.Amount as number);
			} else if (offer.Kind === "Essence") {
				items.Essence = (items.Essence as number) + (offer.Amount as number);
			} else if (offer.Kind === "Item") {
				itemUid = this._createItem(profile, offer.ItemId as string);
				if (itemUid === undefined) {
					return responseError(T("GameService.TheMarketCouldNotDeliver"));
				}
			} else {
				return responseError(T("ProfileMath.ThatMarketOfferIsMisconfigured"));
			}
			const nextStock = (remaining as number) - 1;
			stock[offerId] = nextStock;
			purchased[offerId] = nextStock <= 0;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((offer.Name as string) + " bought.", { ItemUid: itemUid, Stock: nextStock });
		});
	}

	_buyDailyOffer(player: Player, slot: unknown) {
		return ShopDomain.buyDailyOffer(this, player, slot);
	}

	_buyCrateSkin(player: Player, id: unknown) {
		const [ShopCatalog] = shopShared();
		const skin = ShopCatalog.skin(id) as Dict | undefined;
		if (skin === undefined || skin.Price === undefined) {
			return responseError(T("GameService.ThatSkinIsnTFor"));
		}
		if (truthy(skin.DailyOnly)) {
			return responseError(T("GameService.ThatSkinOnlyAppearsIn"));
		}
		return this._mutate(player, (profile: Profile) => {
			const cosmetics = K.ProfileBagMath.EnsureCosmetics(profile, (skinId: unknown) => ShopCatalog.skin(skinId) !== undefined) as Dict;
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (crateSkins[skin.Id as string] === true) {
				return responseError(T("GameService.YouAlreadyOwnThatSkin"));
			}
			K.ProfileBagMath.EnsureDailyShop(profile, ShopCatalog.day(os.time()), crateSkins);
			const price = skin.Price as Dict;
			const denied = spendShopCurrency(profile, price.Currency as string, price.Amount as number);
			if (denied !== undefined) {
				return responseError(denied);
			}
			crateSkins[skin.Id as string] = true;
			cosmetics.CrateSkin = skin.Id;
			bumpStat(profile, "ShopPurchases", 1);
			return responseSuccess((skin.Name as string) + " unlocked and equipped.", { Skin: skin.Id });
		});
	}

	_equipCrateSkin(player: Player, id: unknown) {
		const [ShopCatalog] = shopShared();
		const skin = ShopCatalog.skin(id) as Dict | undefined;
		if (skin === undefined) {
			return responseError(T("GameService.ThatSkinDoesnTExist"));
		}
		return this._mutate(player, (profile: Profile) => {
			const cosmetics = K.ProfileBagMath.EnsureCosmetics(profile, (skinId: unknown) => ShopCatalog.skin(skinId) !== undefined) as Dict;
			const crateSkins = cosmetics.CrateSkins as Dict;
			if (crateSkins[skin.Id as string] !== true) {
				// earned skins are owned the first time you equip them after meeting the milestone
				const earn = skin.Earn as ProfileStyle.StyleUnlock | undefined;
				if (earn === undefined) {
					return responseError(T("GameService.YouDonTOwnThat"));
				}
				if (!ProfileStyle.isUnlocked(earn, ProfileStyle.factsOf(profile))) {
					return responseError(`${skin.Name as string} is still locked: ${ProfileStyle.unlockText(earn)}.`);
				}
				crateSkins[skin.Id as string] = true;
			}
			cosmetics.CrateSkin = skin.Id;
			return responseSuccess((skin.Name as string) + " equipped.", { Skin: skin.Id });
		});
	}

	_fuseRelics(player: Player, definitionId: unknown) {
		if (!typeIs(definitionId, "string") || itemById[definitionId] === undefined) {
			return responseError(T("GameService.ThatRelicDoesnTExist"));
		}
		const [, RelicSystem] = shopShared();
		const definition = itemById[definitionId] as Dict;
		return this._mutate(player, (profile: Profile) => {
			const items = K.ProfileBagMath.EnsureItems(profile) as Dict;
			const inventory = items.Inventory as Dict;
			const maxStars = (K.GameConfig.Items.MaxStars as number | undefined) ?? 5;
			const [targetUid, fodderUid, reason] = RelicSystem.fusionPair(inventory, items.Equipped, definitionId, maxStars) as LuaTuple<
				[unknown, unknown, unknown]
			>;
			if (targetUid === undefined || fodderUid === undefined) {
				return responseError(truthy(reason) ? reason : T("GameService.ThoseRelicsCanTBe"));
			}
			const target = inventory[targetUid as string] as Dict;
			const fodder = inventory[fodderUid as string] as Dict;
			const [stars, level] = RelicSystem.fuse(target, fodder, maxStars) as LuaTuple<[number, number]>;
			target.Stars = stars;
			target.Level = math.min(level, definition.MaxLevel as number);
			inventory[fodderUid as string] = undefined;
			bumpStat(profile, "RelicsFused", 1);
			return responseSuccess(string.format("%s fused to %d star%s.", definition.Name as string, stars, stars === 1 ? "" : "s"), {
				Uid: targetUid,
				Stars: stars,
				DefinitionId: definitionId,
				Rarity: definition.Rarity,
			});
		});
	}

	_openItemCrate(player: Player, crateId: unknown, rawCount: unknown) {
		return CrateOpening.openItemCrate(this, player, crateId, rawCount);
	}

	_equipItem(player: Player, uid: unknown, target: unknown) {
		if (!typeIs(uid, "string") || !typeIs(target, "string")) {
			return responseError(T("GameService.InvalidSocketRequest"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			const definition = instance !== undefined ? (itemById[instance.DefinitionId as string] as Dict | undefined) : undefined;
			if (definition === undefined) {
				return responseError(T("GameService.ThatItemIsNotIn"));
			}
			for (const [equippedTarget, equippedUid] of pairs(items.Equipped as Dict)) {
				if (equippedUid === uid && ExpeditionBoard.isLockKey(equippedTarget)) {
					return responseError(T("ExpeditionBoard.CrewAway"));
				}
			}
			if (target === CompanionRelic.TARGET) {
				const equipped = items.Equipped as Dict;
				for (const [equippedTarget, equippedUid] of pairs(equipped)) {
					if (equippedUid === uid) {
						equipped[equippedTarget as string] = undefined;
					}
				}
				equipped[target] = uid;
				return responseSuccess((definition.Name as string) + " is your companion now.", {
					ItemName: definition.Name,
					Rarity: definition.Rarity,
					Target: target,
				});
			}
			const [slot, targetId] = target.match("^(%a+):([%w_]+)$");
			if (definition.Slot !== slot) {
				return responseError(string.format("%s items only fit %s sockets.", definition.Name as string, definition.Slot as string));
			}
			if (typeIs(definition.Targets, "table") && !(definition.Targets as string[]).includes(targetId as string)) {
				return responseError((definition.Name as string) + " is not compatible with that upgrade.");
			}
			const ownedLevel =
				slot === "Machine"
					? (profile.Machines as Dict)[targetId as string]
					: slot === "Research"
						? (profile.Research as Dict)[targetId as string]
						: undefined;
			if (!typeIs(ownedLevel, "number") || ownedLevel < 1) {
				return responseError(T("GameService.UnlockAtLeastOneLevel"));
			}
			const equipped = items.Equipped as Dict;
			for (const [equippedTarget, equippedUid] of pairs(equipped)) {
				if (equippedUid === uid) {
					equipped[equippedTarget as string] = undefined;
				}
			}
			equipped[target] = uid;
			const [rigCount, rigNote] = grantLitRigs(profile);
			const attached = (definition.Name as string) + " attached to " + tostring(targetId) + ".";
			return responseSuccess(rigCount > 0 ? attached + " " + rigNote + "." : attached, {
				ItemName: definition.Name,
				Rarity: definition.Rarity,
				Target: target,
			});
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, T("Toast.RelicLinkedTitle"), result.message, "Success");
			this._effect.fire(player, {
				Type: "ItemLinked",
				ItemName: result.ItemName,
				Rarity: result.Rarity,
				Target: result.Target,
			});
		}
		return result;
	}

	_unequipItem(player: Player, target: unknown) {
		if (!typeIs(target, "string")) {
			return responseError(T("GameService.InvalidSocketRequest"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			const equipped = (profile.Items as Dict).Equipped as Dict;
			if (ExpeditionBoard.isLockKey(target)) {
				return responseError(T("ExpeditionBoard.CrewAway"));
			}
			if (equipped[target] === undefined) {
				return responseError(T("GameService.ThatSocketIsAlreadyEmpty"));
			}
			equipped[target] = undefined;
			return responseSuccess(T("GameService.ItemReturnedToInventory"));
		});
		if (truthy(result.ok)) {
			this._toastPlayer(player, T("Toast.RelicDetachedTitle"), result.message, "Info");
		}
		return result;
	}

	_upgradeItem(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError(T("GameService.InvalidItemRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError(T("GameService.ThatItemIsNotIn"));
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError(T("GameService.ThatItemIsNotIn"));
			}
			if ((instance.Level as number) >= (definition.MaxLevel as number)) {
				return responseError(T("GameService.ThatItemIsAlreadyMax"));
			}
			const cost = math.floor((definition.EssenceBase as number) * math.pow(1.55, math.max(0, (instance.Level as number) - 1)));
			if ((items.Essence as number) < cost) {
				return responseError(T("GameService.YouNeedDMoreItem", cost - (items.Essence as number)));
			}
			items.Essence = (items.Essence as number) - cost;
			instance.Level = (instance.Level as number) + 1;
			return responseSuccess(string.format("%s upgraded to level %d.", definition.Name as string, instance.Level as number));
		});
	}

	_salvageItem(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError(T("GameService.InvalidItemRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const inventory = items.Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError(T("GameService.ThatItemIsNotIn"));
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError(T("GameService.ThatItemIsNotIn"));
			}
			if (instance.Locked === true) {
				return responseError(T("GameService.UnlockThatRelicBeforeSalvaging"));
			}
			for (const [, equippedUid] of pairs(items.Equipped as object)) {
				if (equippedUid === uid) {
					return responseError(T("GameService.DetachThatItemBeforeSalvaging"));
				}
			}
			const essence = itemSalvageValue(instance, definition);
			inventory[uid] = undefined;
			items.Essence = (items.Essence as number) + essence;
			bumpStat(profile, "ItemsSalvaged", 1);
			return responseSuccess(T("GameService.SalvagedSForDEssence", definition.Name as string, essence), { Amount: essence });
		});
	}

	_setSetting(player: Player, rawPayload: unknown) {
		if (!typeIs(rawPayload, "table")) {
			return responseError(T("GameService.InvalidSettingRequest"));
		}
		const payload = rawPayload as Dict;
		const Schema = K.SharedDataSuite("SettingsSchema") as Kit;
		const accepts = (key: unknown): boolean => typeIs(key, "string") && truthy(Schema.accepts(key));
		const notifyKeys: Record<string, boolean> = {
			NotifyGuild: true,
		};
		if (typeIs(payload.Values, "table")) {
			return this._mutate(player, (profile: Profile) => {
				let applied = 0;
				for (const [key, value] of pairs(payload.Values as object)) {
					if (applied >= 24) {
						break;
					}
					if (typeIs(key, "string") && typeIs(value, "number") && accepts(key)) {
						(profile.Settings as Dict)[key] = Schema.normalize(key, value);
						applied += 1;
					}
				}
				if (applied === 0) {
					return responseError(T("GameService.UnknownSetting"));
				}
				K.SettingsSeal.Apply(profile);
				const label = payload.Label;
				if (typeIs(label, "string") && label !== "") {
					const clipped = string.sub(label, 1, 80);
					const [, brokenAt] = utf8.len(clipped);
					return responseSuccess(brokenAt !== undefined ? string.sub(clipped, 1, brokenAt - 1) : clipped);
				}
				return responseSuccess(T("GameService.SettingsUpdated"));
			});
		}
		if (!typeIs(payload.Key, "string") || !typeIs(payload.Value, "number")) {
			return responseError(T("GameService.UnknownSetting"));
		}
		const key = payload.Key;
		const value = payload.Value;
		if (accepts(key)) {
			return this._mutate(player, (profile: Profile) => {
				(profile.Settings as Dict)[key] = Schema.normalize(key, value);
				K.SettingsSeal.Apply(profile);
				return responseSuccess(T("GameService.SettingUpdated"));
			});
		}
		if (truthy(notifyKeys[key])) {
			return this._mutate(player, (profile: Profile) => {
				(profile.Settings as Dict)[key] = value >= 0.5 ? 1 : 0;
				return responseSuccess(value >= 0.5 ? T("GameService.YouLlBeNotified") : T("GameService.NotificationCleared"));
			});
		}
		return responseError(T("GameService.UnknownSetting"));
	}

	// Star Foundry: every move is one FoundryAct with an Op (rules in FoundryMath, moves in FoundryService)
	_foundryAct(player: Player, payload: unknown) {
		const now = Workspace.GetServerTimeNow();
		return this._mutate(player, (profile: Profile) => {
			const [ok, message, extra] = K.FoundryService.Act(profile, payload, this._random, now) as LuaTuple<[unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(truthy(message) ? message : T("FoundryService.ThatFoundryMoveIsNot"));
			}
			return responseSuccess(message, truthy(extra) ? extra : {});
		});
	}

	_upgradeContinuum(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.Continuum, "table")) {
				profile.Continuum = {
					Rank: 0,
					TotalFluxSpent: 0,
					TotalStardustSpent: 0,
				};
			}
			const continuum = profile.Continuum as Dict;
			const rank = math.max(0, math.floor(tonumber(continuum.Rank) ?? 0));
			if (rank >= ((K.GameConfig.Continuum as Dict).MaxRank as number)) {
				return responseError(T("GameService.TheContinuumHasReachedThe"));
			}
			const [fluxCost, stardustCost] = K.Economy.ContinuumCosts(rank) as LuaTuple<[unknown, number]>;
			if (K.Economy.Lt(profile.Cash, fluxCost)) {
				return responseError(T("GameService.YouNeedSMoreFlux", (K.Format.Number as Fn)(K.Economy.Sub(fluxCost, profile.Cash))));
			}
			if (K.Economy.Lt(profile.Stardust, stardustCost)) {
				return responseError(T("GameService.YouNeedSMoreStardust", (K.Format.Number as Fn)(K.Economy.Sub(stardustCost, profile.Stardust))));
			}

			profile.Cash = K.Economy.Sub(profile.Cash, fluxCost);
			profile.Stardust = K.Economy.AsNumber(K.Economy.Sub(profile.Stardust, stardustCost));
			continuum.Rank = rank + 1;
			continuum.TotalFluxSpent = K.Economy.Persist(K.Economy.Add(continuum.TotalFluxSpent, fluxCost));
			continuum.TotalStardustSpent = math.min(1e308, math.max(0, tonumber(continuum.TotalStardustSpent) ?? 0) + stardustCost);
			const stats = ensureStats(profile) as Dict;
			stats.ContinuumUpgrades = math.min(1e308, math.max(0, tonumber(stats.ContinuumUpgrades) ?? 0) + 1);
			K.ProgressionService.AwardCommandXP(profile, 20 + math.min(480, rank * 2));

			const [nextProduction] = K.Economy.ContinuumEffects(profile) as LuaTuple<[unknown]>;
			const milestone = (rank + 1) % ((K.GameConfig.Continuum as Dict).MilestoneEvery as number) === 0;
			return responseSuccess(
				T("GameService.ContinuumRankDReachedProduction", rank + 1, (K.Format.Number as Fn)(nextProduction) + "x"),
				{ Level: rank + 1, Milestone: milestone },
			);
		});
	}

	_toggleItemLock(player: Player, uid: unknown) {
		if (!typeIs(uid, "string")) {
			return responseError(T("GameService.InvalidRelicRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const inventory = (profile.Items as Dict).Inventory as Dict;
			const instance = inventory[uid] as Dict | undefined;
			if (instance === undefined) {
				return responseError(T("GameService.ThatRelicIsNotIn"));
			}
			const definition = itemById[instance.DefinitionId as string] as Dict | undefined;
			if (definition === undefined) {
				return responseError(T("GameService.ThatRelicIsNotIn"));
			}
			instance.Locked = instance.Locked !== true;
			return responseSuccess(
				instance.Locked === true ? (definition.Name as string) + " protected." : (definition.Name as string) + " unlocked.",
				{ Uid: uid, Locked: instance.Locked },
			);
		});
	}

	_bulkSalvageItems(player: Player, rawUids: unknown) {
		if (!typeIs(rawUids, "table")) {
			return responseError(T("GameService.SelectAtLeastOneRelic"));
		}
		return this._mutate(player, (profile: Profile) => {
			const requested = new Set<string>();
			let requestCount = 0;
			for (const [, uid] of pairs(rawUids)) {
				if (!typeIs(uid, "string") || uid.size() < 1 || uid.size() > 48) {
					return responseError(T("GameService.TheRelicSelectionIsInvalid"));
				}
				if (!requested.has(uid)) {
					requestCount += 1;
					if (requestCount > 25) {
						return responseError(T("GameService.SalvageUpTo25Relics"));
					}
					requested.add(uid);
				}
			}
			if (requestCount === 0) {
				return responseError(T("GameService.SelectAtLeastOneRelic"));
			}
			const items = profile.Items as Dict;
			const equipped = new Set<string>();
			for (const [, equippedUid] of pairs(items.Equipped as object)) {
				if (typeIs(equippedUid, "string")) {
					equipped.add(equippedUid);
				}
			}
			const inventory = items.Inventory as Dict;
			let removed = 0;
			let essence = 0;
			let protectedCount = 0;
			for (const uid of requested) {
				const instance = inventory[uid] as Dict | undefined;
				const definition = instance !== undefined ? (itemById[instance.DefinitionId as string] as Dict | undefined) : undefined;
				if (definition !== undefined && !equipped.has(uid) && instance!.Locked !== true) {
					inventory[uid] = undefined;
					removed += 1;
					essence += itemSalvageValue(instance!, definition);
				} else if (instance !== undefined) {
					protectedCount += 1;
				}
			}
			if (removed === 0) {
				return responseError(
					protectedCount > 0 ? T("GameService.EverySelectedRelicIsEquipped") : T("GameService.ThoseRelicsAreNoLonger"),
				);
			}
			items.Essence = (items.Essence as number) + essence;
			bumpStat(profile, "ItemsSalvaged", removed);
			return responseSuccess(
				T("GameService.SalvagedDRelicSFor",
					removed,
					removed === 1 ? "" : "s",
					essence,
					protectedCount > 0 ? string.format("; %d protected", protectedCount) : "",
				),
				{ Count: removed, Amount: essence, Protected: protectedCount },
			);
		});
	}

	_equipBestItems(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const items = profile.Items as Dict;
			const targets = K.ItemLoadoutMath.BuildTargets(
				K.GameConfig.Machines,
				K.GameConfig.Research,
				profile.Machines,
				profile.Research,
			) as unknown[];
			const candidates: Dict[] = [];
			const companion = CompanionRelic.uidOf(items);
			// crew out on an expedition stay with it
			const crewLocks: Dict = {};
			for (const [target, uid] of pairs(items.Equipped as Dict)) {
				if (ExpeditionBoard.isLockKey(target)) crewLocks[target as string] = uid;
			}
			const away = new Set<unknown>();
			for (const [, uid] of pairs(crewLocks)) away.add(uid);
			for (const [uid, instance] of pairs(items.Inventory as object)) {
				const inst = instance as Dict;
				const definition = itemById[inst.DefinitionId as string] as Dict | undefined;
				if (definition !== undefined && uid !== companion && !away.has(uid)) {
					candidates.push({
						Uid: uid,
						Instance: inst,
						Definition: definition,
						Power: K.ItemLoadoutMath.CandidatePower(definition, inst.Level),
					});
				}
			}
			const [nextEquipped, equippedCount, changed] = K.ItemLoadoutMath.PlanEquipBest(
				targets,
				candidates,
				K.GameConfig.Items.Rarities,
				items.Equipped,
			) as LuaTuple<[unknown, number, unknown]>;
			if (companion !== undefined) {
				(nextEquipped as Dict)[CompanionRelic.TARGET] = companion;
			}
			for (const [target, uid] of pairs(crewLocks)) {
				(nextEquipped as Dict)[target as string] = uid;
			}
			items.Equipped = nextEquipped;
			const [rigCount, rigNote] = grantLitRigs(profile);
			const equippedLine =
				targets.size() === 0
					? "Unlock a machine or research socket first."
					: equippedCount === 0
						? "No compatible relics are available yet."
						: string.format("Best loadout equipped across %d socket%s.", equippedCount, equippedCount === 1 ? "" : "s");
			return responseSuccess(rigCount > 0 ? equippedLine + " " + rigNote + "." : equippedLine, {
				Equipped: equippedCount,
				Changed: changed,
			});
		});
	}

	_setItemAutoSalvage(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (
			!typeIs(rawPayload, "table") ||
			!typeIs(payload!.Enabled, "boolean") ||
			!typeIs(payload!.KeepNew, "boolean") ||
			!typeIs(payload!.Rarities, "table")
		) {
			return responseError(T("GameService.InvalidAutoSalvageRequest"));
		}
		return this._mutate(player, (profile: Profile) => {
			const ownedPasses = profile.OwnedPasses as Dict | undefined;
			if (ownedPasses === undefined || ownedPasses.AutoSalvage !== true) {
				return { ok: false, error: T("GameService.RelicRecyclerIsRequiredFor"), RequiresPass: "AutoSalvage" };
			}
			const rarities: Dict = {};
			for (const [rarity] of pairs(K.GameConfig.Items.Rarities as Dict)) {
				rarities[rarity] = false;
			}
			let count = 0;
			for (const [, rarity] of pairs(payload!.Rarities as object)) {
				if (!typeIs(rarity, "string") || (K.GameConfig.Items.Rarities as Dict)[rarity] === undefined) {
					return responseError(T("GameService.AnAutoSalvageRarityIs"));
				}
				if (rarities[rarity] !== true) {
					count += 1;
					if (count > 6) {
						return responseError(T("GameService.TooManyAutoSalvageRarities"));
					}
					rarities[rarity] = true;
				}
			}
			const rules = ensureAutoSalvage(profile) as Dict;
			rules.Enabled = payload!.Enabled;
			rules.KeepNew = payload!.KeepNew;
			rules.Rarities = rarities;
			return responseSuccess(payload!.Enabled === true ? T("GameService.RelicRecyclerArmed") : T("GameService.RelicRecyclerPaused"));
		});
	}

	// the Domain Lattice: Op "Etch" spends points on the link between anchors A and B,
	// Op "Clear" refunds every link (once per domain rank)
	_domainLattice(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const op = typeIs(rawPayload, "table") ? payload!.Op : undefined;
		if (op !== "Etch" && op !== "Clear") {
			return responseError(T("GameService.UnknownLatticeAction"));
		}
		return this._mutate(player, (profile: Profile) => {
			const domain = K.ProfileBagMath.EnsureDomain(profile) as Dict;
			if ((domain.Rank as number) < 1) {
				return responseError(T("GameService.ExpandYourDomainFirst"));
			}
			domain.Links = K.DomainLattice.sanitize(domain.Links);
			const links = domain.Links as Dict;
			const etched = K.DomainLattice.count(links) as number;
			if (op === "Clear") {
				if (etched === 0) {
					return responseError(T("GameService.NothingIsEtchedYet"));
				}
				if ((tonumber(domain.LatticeClearedAtRank) ?? 0) >= (domain.Rank as number)) {
					return responseError(T("GameService.YouCanClearTheLattice"));
				}
				domain.SkillPoints = (domain.SkillPoints as number) + (K.DomainLattice.spent(etched) as number);
				domain.Links = {};
				domain.LatticeClearedAtRank = domain.Rank;
				return responseSuccess(T("GameService.LatticeClearedEveryPointIs"), {
					Links: domain.Links,
					SkillPoints: domain.SkillPoints,
				});
			}
			const a = tonumber(payload!.A);
			const b = tonumber(payload!.B);
			// NaN, infinities and fractions would key the ledger with junk ("nan:1") and still charge points
			if (a === undefined || b === undefined || a !== a || b !== b || math.abs(a) === math.huge || math.abs(b) === math.huge || a % 1 !== 0 || b % 1 !== 0) {
				return responseError(T("GameService.ThatLinkCanTBe"));
			}
			const [ok, reason] = K.DomainLattice.canEtch(links, a, b, domain.SkillPoints) as LuaTuple<[unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(truthy(reason) ? reason : T("GameService.ThatLinkCanTBe"));
			}
			const cost = K.DomainLattice.linkCost(etched) as number;
			const key = K.DomainLattice.key(math.floor(a as number), math.floor(b as number)) as string;
			const facetsBefore = (K.DomainLattice.facets(links) as unknown[]).size();
			domain.SkillPoints = (domain.SkillPoints as number) - cost;
			links[key] = true;
			const facetsAfter = (K.DomainLattice.facets(links) as unknown[]).size();
			return responseSuccess(facetsAfter > facetsBefore ? T("GameService.FacetClosed") : T("GameService.LinkEtched"), {
				Link: key,
				Links: links,
				SkillPoints: domain.SkillPoints,
				Facets: facetsAfter,
				ClosedFacet: facetsAfter > facetsBefore,
			});
		});
	}

	_domainExpansion(player: Player) {
		return DomainExpansion.domainExpansion(this, player);
	}

	// Ascension: the infinite final reset. Resets the Domain, rebirths, cores and the run; pays Aether.
	_ascend(player: Player) {
		let details: Dict | undefined;
		const result = this._mutate(player, (profile: Profile) => {
			const state = K.AscensionMath.sanitize(profile.Ascension, K.OmegaMath) as Dict;
			const domain = profile.Domain as Dict | undefined;
			const domainRank = math.max(0, math.floor(tonumber(domain !== undefined ? domain.Rank : undefined) ?? 0));
			const now = os.time();
			if (now - (state.LastAscendedAt as number) < 10) {
				return responseError(T("GameService.TheForgeIsStillSettling"));
			}
			const [nextState, gainOrReason] = K.AscensionMath.ascend(
				state,
				domainRank,
				now,
				K.OmegaMath,
				tonumber(profile.Rebirths) ?? 0,
			) as LuaTuple<[Dict | undefined, unknown]>;
			if (nextState === undefined) {
				return responseError(gainOrReason);
			}
			profile.Ascension = nextState;
			ResetSpec.applyReset(ResetSpec.Ascension, profile as Dict, resetContext());
			details = { Rank: nextState.Rank, Aether: gainOrReason, DomainRank: domainRank };
			return responseSuccess(
				T("GameService.AscensionDSAether", nextState.Rank as number, (K.Format.Number as Fn)(gainOrReason) as string),
				details,
			);
		});
		if (truthy(result.ok)) {
			this._effect.broadcast({
				Type: "Ascension",
				UserId: player.UserId,
				Rank: details !== undefined ? details.Rank : 0,
				Position: this._world.GetPlotPosition(player),
			});
		}
		return result;
	}

	_upgradeSigil(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		const id = typeIs(rawPayload, "table") ? payload!.Id : undefined;
		return this._mutate(player, (profile: Profile) => {
			const state = K.AscensionMath.sanitize(profile.Ascension, K.OmegaMath) as Dict;
			const [nextState, costOrReason] = K.AscensionMath.buy(state, id, K.OmegaMath) as LuaTuple<[Dict | undefined, unknown]>;
			if (nextState === undefined) {
				return responseError(costOrReason);
			}
			profile.Ascension = nextState;
			const sigil = K.AscensionMath.sigil(id) as Dict | undefined;
			return responseSuccess(
				string.format(
					"%s is now level %d.",
					sigil !== undefined ? (sigil.Name as string) : tostring(id),
					(nextState.Sigils as Dict)[id as string] as number,
				),
				{ Id: id, Level: (nextState.Sigils as Dict)[id as string] },
			);
		});
	}

	// What the Ascension page shows.
	_ascensionPublic(profile: Profile): Dict {
		const state = K.AscensionMath.sanitize(profile.Ascension, K.OmegaMath) as Dict;
		const domain = profile.Domain as Dict | undefined;
		const domainRank = math.max(0, math.floor(tonumber(domain !== undefined ? domain.Rank : undefined) ?? 0));
		const gain = K.AscensionMath.aetherGain(state, domainRank, K.OmegaMath);
		const sigils: Dict[] = [];
		for (const [order, sigil] of pairs(K.AscensionMath.SIGILS as unknown as Dict[])) {
			const sigilDef = sigil as Dict;
			const level = ((state.Sigils as Dict)[sigilDef.Id as string] as number | undefined) ?? 0;
			const cost = K.AscensionMath.sigilCost(sigilDef.Id, level, K.OmegaMath);
			sigils.push({
				Id: sigilDef.Id,
				Name: sigilDef.Name,
				Line: sigilDef.Line,
				Effect: sigilDef.Effect,
				Order: order,
				Level: level,
				EffectiveLevel: K.AscensionMath.effectiveLevel(state, sigilDef.Id),
				Multiplier: K.OmegaMath.Persist(K.AscensionMath.sigilMultiplier(state, sigilDef.Id, K.OmegaMath)),
				Cost: K.OmegaMath.Persist(cost),
				Affordable: K.OmegaMath.Gte(state.Aether, cost),
			});
		}
		return {
			Rank: state.Rank,
			Aether: K.OmegaMath.Persist(state.Aether),
			TotalAether: K.OmegaMath.Persist(state.TotalAether),
			DomainRank: domainRank,
			RequiredDomainRank: K.AscensionMath.requiredDomainRank(state.Rank),
			CanAscend: gain !== undefined,
			Gain: gain !== undefined ? K.OmegaMath.Persist(gain) : 0,
			Harmony: K.AscensionMath.harmony(state),
			Production: K.OmegaMath.Persist(K.AscensionMath.effect(state, "Production", K.OmegaMath)),
			NextRankProduction: K.OmegaMath.Persist(K.OmegaMath.Pow((state.Rank as number) + 2, K.AscensionMath.RANK_EXPONENT)),
			Sigils: sigils,
		};
	}

	_verifyCreatorFollow(player: Player) {
		// Roblox exposes no trusted follow check here; only the explicit Studio QA bypass may award it.
		if (!RunService.IsStudio() || K.ServerConfig.AllowStudioFollowVerification !== true) {
			K.ModuleLog.Every(
				string.format("creator-follow-unverified:%d", player.UserId),
				30,
				"Security",
				string.format("u=%d Creator follow claim denied because verification is unavailable", player.UserId),
			);
			return responseError(T("GameService.CreatorFollowVerificationIsUnavailable"));
		}
		const profile = this._data.Get(player) as Profile | undefined;
		if (profile === undefined) {
			return responseError(T("GameService.YourSaveIsStillLoading"));
		}
		const socialRewards = typeIs(profile.SocialRewards, "table") ? (profile.SocialRewards as Dict) : undefined;
		if (socialRewards !== undefined && socialRewards.CreatorFollowClaimed === true) {
			return responseSuccess(T("CommunityRewards.YouAlreadyClaimedThisReward"));
		}
		const result = this._mutate(player, (current: Profile) => {
			if (!typeIs(current.SocialRewards, "table")) {
				current.SocialRewards = { CreatorFollowClaimed: false };
			}
			const rewards = current.SocialRewards as Dict;
			if (rewards.CreatorFollowClaimed === true) {
				return responseSuccess(T("CommunityRewards.YouAlreadyClaimedThisReward"));
			}
			rewards.CreatorFollowClaimed = true;
			const rewardText = K.ProgressionService.ApplyReward(current, K.ServerConfig.FollowReward, K.Economy.Production(current));
			return responseSuccess(rewardText);
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "FeatureUnlocked" });
		}
		return result;
	}

	_claimCommunityReward(player: Player, kind: unknown, index: unknown) {
		const config = communityConfig();
		// membership is checked here, before the mutate, because IsInGroup can yield
		let inGroup: boolean | undefined;
		if (kind === "Group" && config.GroupId > 0) {
			const [ok, member] = pcall(() => player.IsInGroup(config.GroupId));
			inGroup = ok ? member === true : undefined;
		}
		return this._mutate(player, (profile: Profile) => {
			if (!typeIs(profile.SocialRewards, "table")) {
				profile.SocialRewards = { CreatorFollowClaimed: false };
			}
			const result = CommunityRewards.claim(profile.SocialRewards as Dict, kind, index, inGroup, config);
			if (!result.ok) {
				return responseError(result.message);
			}
			return responseSuccess(K.ProgressionService.ApplyReward(profile, result.reward, K.Economy.Production(profile)));
		});
	}

	_setMobileLayout(player: Player, rawPayload: unknown) {
		const payload = rawPayload as Dict | undefined;
		if (!typeIs(rawPayload, "table")) {
			return responseError(T("GameService.InvalidMobileLayout"));
		}
		if (payload!.Values !== undefined && !typeIs(payload!.Values, "table")) {
			return responseError(T("GameService.InvalidMobileLayout"));
		}
		if (payload!.Pins !== undefined && !NavRoutes.validMobileTabPins(payload!.Pins)) {
			return responseError(T("GameService.InvalidTabPins"));
		}
		const allowed: Record<string, boolean> = {
			MobileQuickX: true,
			MobileQuickY: true,
			MobileDockX: true,
			MobileDockY: true,
			MobileToastX: true,
			MobileToastY: true,
		};
		return this._mutate(player, (profile: Profile) => {
			if (payload!.Pins !== undefined) {
				(profile.Flags as Dict).MobileTabPins = NavRoutes.normalizeMobileTabPins(payload!.Pins);
			}
			for (const [key, value] of pairs((payload!.Values ?? {}) as object)) {
				if (truthy(allowed[key as string]) && typeIs(value, "number")) {
					(profile.Settings as Dict)[key as string] = math.clamp(value, 0, 1);
				}
			}
			if (payload!.Desktop !== undefined) {
				const desktop = K.DesktopLayout.Normalize(payload!.Desktop);
				if (desktop === undefined) {
					return responseError(T("GameService.InvalidLayoutMemory"));
				}
				(profile.Flags as Dict).DesktopLayout = desktop;
				return responseSuccess(T("GameService.MobileHUDLayoutSaved"));
			}
			if (payload!.Slots !== undefined) {
				const normalized = K.MobileLayoutSlots.Normalize(payload!.Slots);
				if (normalized === undefined) {
					return responseError(T("GameService.InvalidLayoutMemory"));
				}
				(profile.Flags as Dict).MobileLayoutSlots = normalized;
				return responseSuccess(T("GameService.LayoutMemorySaved"));
			}
			if (payload!.Pins !== undefined && payload!.Values === undefined) {
				return responseSuccess(T("GameService.TabBarSaved"));
			}
			return responseSuccess(T("GameService.MobileHUDLayoutSaved"));
		});
	}

	_completeTutorial(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			if (truthy(flags.TutorialDone)) {
				return responseSuccess(T("GameService.TutorialAlreadyComplete"));
			}
			flags.TutorialDone = true;
			flags.TutorialStep = 15;
			if (truthy(flags.TutorialRewardClaimed)) {
				return responseSuccess(T("GameService.GuideFinished"));
			}
			flags.TutorialRewardClaimed = true;
			const reward = K.GameConfig.Economy.TutorialReward;
			profile.Cash = K.Economy.Add(profile.Cash, reward);
			profile.RunCash = K.Economy.Add(profile.RunCash, reward);
			profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, reward);
			return responseSuccess(T("GameService.GuideFinishedSFlux", (K.Format.Number as Fn)(reward)));
		});
	}

	_setTutorialStep(player: Player, rawStep: unknown) {
		if (!typeIs(rawStep, "number")) {
			return responseError(T("GameService.InvalidTutorialStep"));
		}
		const step = math.clamp(math.floor(rawStep), 1, 15);
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			if (truthy(flags.TutorialDone)) {
				return responseSuccess(T("GameService.GuideProgressAlreadyComplete"));
			}
			flags.TutorialStep = step;
			return responseSuccess(T("GameService.GuideProgressSaved"));
		});
	}

	_markHintSeen(player: Player, rawId: unknown) {
		if (!SeenHints.isHintId(rawId)) {
			return responseError(T("GameService.UnknownHint"));
		}
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			const seen = SeenHints.normalizeSeenHints(flags.SeenHints);
			if (!seen.includes(rawId)) {
				seen.push(rawId);
			}
			flags.SeenHints = seen;
			return responseSuccess(T("GameService.HintSaved"));
		});
	}

	// First goals pay once, in order, and only when the profile shows the goal is done.
	_claimFirstGoal(player: Player, rawId: unknown) {
		if (!FirstGoals.isGoalId(rawId)) {
			return responseError(T("GameService.UnknownGoal"));
		}
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			const claimed = FirstGoals.normalizeClaimed(flags.FirstGoals);
			if (claimed.includes(rawId)) {
				return responseSuccess(T("GameService.AlreadyClaimed"));
			}
			const [goal] = FirstGoals.currentGoal(claimed);
			if (goal === undefined || goal.id !== rawId) {
				return responseError(T("GameService.FinishTheEarlierGoalFirst"));
			}
			const stats = (profile.Stats ?? {}) as Dict;
			const levelState = K.ProgressionGate.LevelState(profile) as Dict;
			const prestige = K.Economy.PrestigeReward(K.Economy.Add(profile.RunCash, profile.Vault), num(profile.Rebirths) ?? 0);
			const [, done] = FirstGoals.progressOf(goal, {
				machinesBought: num(stats.MachinesBought) ?? 0,
				researchBought: num(stats.ResearchBought) ?? 0,
				cratesOpened: num(stats.CratesOpened) ?? 0,
				itemsSalvaged: num(stats.ItemsSalvaged) ?? 0,
				level: num(levelState.Level) ?? 1,
				rebirths: num(profile.Rebirths) ?? 0,
				rebirthReady: (K.Economy.AsNumber(prestige) as number) >= 1,
			});
			if (!done) {
				return responseError(T("GameService.NotDoneYet"));
			}
			claimed.push(goal.id);
			flags.FirstGoals = claimed;
			const reward = goal.rewardFlux;
			profile.Cash = K.Economy.Add(profile.Cash, reward);
			profile.RunCash = K.Economy.Add(profile.RunCash, reward);
			profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, reward);
			let note = "+" + (K.Format.Number as Fn)(reward) + " Flux";
			const keys = goal.rewardKeys;
			const bag = isTable(profile.Items) && isTable((profile.Items as Dict).Keys) ? ((profile.Items as Dict).Keys as Dict) : undefined;
			if (keys !== undefined && bag !== undefined) {
				bag[keys.crate] = (num(bag[keys.crate]) ?? 0) + keys.count;
				note += keys.count === 1 ? " and a crate key" : ` and ${keys.count} crate keys`;
			}
			return responseSuccess(T("GameService.GoalDoneS", note));
		});
	}

	_replayTutorial(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			const flags = profile.Flags as Dict;
			flags.TutorialDone = false;
			flags.TutorialStep = 1;
			return responseSuccess(T("GameService.GuideReopened"));
		});
	}

	_dismissRelease(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = (K.GameConfig.Game as Dict).Version;
			return responseSuccess();
		});
	}

	_openRelease(player: Player) {
		return this._mutate(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = "";
			return responseSuccess();
		});
	}

	_claimLabOrder(player: Player, orderId: unknown) {
		if (!typeIs(orderId, "string")) {
			return responseError(T("GameService.InvalidOrderRequest"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			K.LabService.Ensure(profile, player.UserId);
			const [ok, message, reward] = K.LabService.ClaimOrder(profile, orderId) as LuaTuple<[unknown, unknown, unknown]>;
			if (!truthy(ok)) {
				return responseError(message);
			}
			const rewardText = K.ProgressionService.ApplyReward(profile, reward, K.Economy.Production(profile));
			return responseSuccess(tostring(message) + " " + tostring(rewardText));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "LabOrder", OrderId: orderId });
		}
		return result;
	}

	_routeLabPower(player: Player, channelId: unknown, rawDelta: unknown) {
		if (!typeIs(channelId, "string") || !typeIs(rawDelta, "number")) {
			return responseError(T("GameService.InvalidPowerRoutingRequest"));
		}
		const delta = math.floor(rawDelta);
		return this._mutate(player, (profile: Profile) => {
			const [ok, message] = K.LabService.RoutePower(profile, channelId, delta) as LuaTuple<[unknown, unknown]>;
			return truthy(ok) ? responseSuccess(message) : responseError(message);
		});
	}

	_readStoryChapter(player: Player, chapterId: unknown) {
		if (!typeIs(chapterId, "string") || storyById[chapterId] === undefined) {
			return responseError(T("GameService.ThatStoryChapterCouldNot"));
		}
		return this._mutate(player, (profile: Profile) => {
			const chapter = storyById[chapterId] as Dict;
			if ((K.ProgressionGate.Progress(profile, chapter.Kind) as number) < (chapter.Target as number)) {
				return responseError(T("GameService.KeepProgressingToUncoverThis"));
			}
			((profile.Story as Dict).Read as Dict)[chapterId] = true;
			return responseSuccess(T("GameService.ChapterAddedToYourArchive"));
		});
	}

	_claimStoryChapter(player: Player, chapterId: unknown) {
		if (!typeIs(chapterId, "string") || storyById[chapterId] === undefined) {
			return responseError(T("GameService.ThatStoryChapterCouldNot"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			const chapter = storyById[chapterId] as Dict;
			if ((K.ProgressionGate.Progress(profile, chapter.Kind) as number) < (chapter.Target as number)) {
				return responseError(T("GameService.KeepProgressingToUncoverThis"));
			}
			const story = profile.Story as Dict;
			if (!truthy((story.Read as Dict)[chapterId])) {
				return responseError(T("GameService.ReadTheChapterBeforeCollecting"));
			}
			if (truthy((story.Claimed as Dict)[chapterId])) {
				return responseError(T("GameService.ThatKeepsakeIsAlreadyIn"));
			}
			(story.Claimed as Dict)[chapterId] = true;
			const reward = K.ProgressionService.ApplyReward(profile, chapter.Reward, K.Economy.Production(profile));
			return responseSuccess(T("GameService.StoryKeepsakeS", tostring(reward)));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "StoryClaimed", Id: chapterId });
		}
		return result;
	}

	_readMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError(T("GameService.ThatLetterCouldNotBe"));
		}
		return this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy((mailbox.Deleted as Dict)[messageId]) || !truthy(K.ProgressionGate.Meets(profile, message.Requirement))) {
				return responseError(T("GameService.ThatLetterIsNotAvailable"));
			}
			(mailbox.Read as Dict)[messageId] = true;
			return responseSuccess();
		});
	}

	_claimMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError(T("GameService.ThatLetterCouldNotBe"));
		}
		const result = this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy((mailbox.Deleted as Dict)[messageId]) || !truthy(K.ProgressionGate.Meets(profile, message.Requirement))) {
				return responseError(T("GameService.ThatLetterIsNotAvailable"));
			}
			if (truthy((mailbox.Claimed as Dict)[messageId])) {
				return responseError(T("GameService.YouAlreadyCollectedThisAttachment"));
			}
			(mailbox.Read as Dict)[messageId] = true;
			(mailbox.Claimed as Dict)[messageId] = true;
			const reward = K.ProgressionService.ApplyReward(profile, message.Attachment, K.Economy.Production(profile));
			return responseSuccess(T("GameService.MailAttachmentS", tostring(reward)));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "MailClaimed", Id: messageId });
		}
		return result;
	}

	_claimAllMail(player: Player) {
		let claimedCount = 0;
		const result = this._mutate(player, (profile: Profile) => {
			const mailbox = profile.Mailbox as Dict;
			for (const message of K.GameConfig.Mail) {
				const messageId = message.Id as string;
				if (
					truthy(message.Attachment) &&
					!truthy((mailbox.Deleted as Dict)[messageId]) &&
					!truthy((mailbox.Claimed as Dict)[messageId]) &&
					truthy(K.ProgressionGate.Meets(profile, message.Requirement))
				) {
					(mailbox.Read as Dict)[messageId] = true;
					(mailbox.Claimed as Dict)[messageId] = true;
					K.ProgressionService.ApplyReward(profile, message.Attachment, K.Economy.Production(profile));
					claimedCount += 1;
				}
			}
			if (claimedCount === 0) {
				return responseError(T("GameService.ThereAreNoAttachmentsReady"));
			}
			return responseSuccess(T("GameService.CollectedDMailAttachmentS", claimedCount, claimedCount === 1 ? "" : "s"));
		});
		if (truthy(result.ok)) {
			this._effect.fire(player, { Type: "MailClaimed", Id: "*", Count: claimedCount });
		}
		return result;
	}

	_deleteMail(player: Player, messageId: unknown) {
		if (!typeIs(messageId, "string") || mailById[messageId] === undefined) {
			return responseError(T("GameService.ThatLetterCouldNotBe"));
		}
		return this._mutate(player, (profile: Profile) => {
			const message = mailById[messageId] as Dict;
			const mailbox = profile.Mailbox as Dict;
			if (truthy(message.Attachment) && !truthy((mailbox.Claimed as Dict)[messageId])) {
				return responseError(T("GameService.CollectTheAttachmentBeforeArchiving"));
			}
			(mailbox.Read as Dict)[messageId] = true;
			(mailbox.Deleted as Dict)[messageId] = true;
			return responseSuccess(T("GameService.LetterArchived"));
		});
	}

	_toastGuild(guildId: unknown, title: unknown, body: unknown, tone?: unknown, skip?: Player) {
		if (!typeIs(guildId, "string") || guildId === "") {
			return;
		}
		for (const online of Players.GetPlayers()) {
			if (online !== skip) {
				const profile = this._data.Get(online) as Profile | undefined;
				const guild = profile !== undefined ? (profile.Guild as Dict | undefined) : undefined;
				if (profile !== undefined && guild !== undefined && guild.Id === guildId) {
					this._toastPlayer(online, title, body, tone);
				}
			}
		}
	}

	_announceGuildActivity(guildId: string, previousActivity: unknown, guild: unknown) {
		if (!typeIs(guild, "table")) {
			return;
		}
		const guildBag = guild as Dict;
		const current = math.max(0, math.floor(tonumber(guildBag.Activity) ?? 0));
		const previous = math.max(0, math.floor(tonumber(previousActivity) ?? 0));
		if (current <= previous) {
			return;
		}
		const reached = math.floor(current / GUILD_ACTIVITY_MILESTONE_STEP);
		const before = math.floor(previous / GUILD_ACTIVITY_MILESTONE_STEP);
		if (reached <= before) {
			return;
		}
		const milestone = reached * GUILD_ACTIVITY_MILESTONE_STEP;
		this._toastGuild(
			guildId,
			"Guild milestone",
			string.format(
				"%s passed %s activity.",
				(guildBag.Name as string | undefined) ?? "Your guild",
				(K.Format.Number as Fn)(milestone) as string,
			),
			"Special",
		);
	}

	_guildAction(player: Player, action: string, rawPayload: unknown) {
		return GuildActions.guildAction(this, player, action, rawPayload);
	}

	_resolvePlayerName(userId: number): string {
		const now = os.clock();
		if (now >= this._nameCachePruneAt) {
			this._nameCachePruneAt = now + 300;
			for (const [cachedUserId, entry] of this._playerNameCache) {
				if (!typeIs(entry, "table") || tonumber(entry.ExpiresAt) === undefined || (entry.ExpiresAt as number) <= now) {
					this._playerNameCache.delete(cachedUserId);
				}
			}
		}
		const online = Players.GetPlayerByUserId(userId);
		if (online !== undefined) {
			const label = online.DisplayName !== "" ? online.DisplayName : online.Name;
			this._playerNameCache.set(userId, { Name: label, ExpiresAt: os.clock() + 300 });
			return label;
		}
		const cached = this._playerNameCache.get(userId);
		if (cached !== undefined && (cached.ExpiresAt as number) > now) {
			return cached.Name as string;
		}

		if (!this._nameLookupPending.get(userId)) {
			this._nameLookupPending.set(userId, true);
			this._spawnWorker(() => {
				const [ok, name] = pcall(() => Players.GetNameFromUserIdAsync(User.fromId(userId)));
				if (ok && typeIs(name, "string") && name !== "") {
					this._playerNameCache.set(userId, { Name: name, ExpiresAt: os.clock() + 900 });
					table.clear(this._globalBoardCache);
				}
				this._nameLookupPending.delete(userId);
			});
		}
		return T("GameService.PilotS", tostring(userId));
	}

	_primePlayerNames(rows: unknown) {
		const now = os.clock();
		const missing: number[] = [];
		for (const [, row] of pairs(rows as object)) {
			const userId = tonumber((row as Dict).UserId);
			if (userId !== undefined) {
				const online = Players.GetPlayerByUserId(userId);
				if (online !== undefined) {
					this._playerNameCache.set(userId, { Name: online.Name, ExpiresAt: now + 300 });
				} else {
					const cached = this._playerNameCache.get(userId);
					if (cached === undefined || (cached.ExpiresAt as number) <= now) {
						missing.push(userId);
					}
				}
			}
		}
		if (missing.size() === 0) {
			return;
		}
		const [ok, infos] = pcall(() => game.GetService("UserService").GetUserInfosByUserIdsAsync(missing) as unknown);
		if (!ok || !typeIs(infos, "table")) {
			return;
		}
		for (const [, info] of pairs(infos)) {
			const userId = tonumber((info as Dict).Id);
			const username = (info as Dict).Username;
			if (userId !== undefined && typeIs(username, "string") && username !== "") {
				this._playerNameCache.set(userId, { Name: username, ExpiresAt: os.clock() + 900 });
			}
		}
	}

	_announceRankClimbs(id: string, rows: Dict[]) {
		if (id !== RANK_PING.BOARD) {
			return;
		}
		const rankByUser = new Map<number, number>();
		for (const [index, row] of pairs(rows)) {
			rankByUser.set(row.UserId as number, index as number);
		}
		for (const online of Players.GetPlayers()) {
			const runtime = this._runtime.get(online);
			const rank = rankByUser.get(online.UserId);
			if (runtime !== undefined && rank !== undefined) {
				const previous = math.max(0, math.floor(tonumber(runtime.LeaderboardRank) ?? 0));
				runtime.LeaderboardRank = rank;
				if (truthy(K.RankBracket.ShouldAnnounce(previous, rank, RANK_PING.BRACKETS, RANK_PING.UNRANKED))) {
					this._toastPlayer(online, T("Toast.LeaderboardClimbTitle"), T("Toast.LeaderboardClimbBody", rank, RANK_PING.BOARD_LABEL), "Special");
				}
			} else if (runtime !== undefined) {
				runtime.LeaderboardRank = 0;
			}
		}
	}

	// Pays a finished week's top 100 once, the first maintenance tick after that week's ranks load.
	_payWeeklyBoard(player: Player) {
		const profile = this._data.Get(player) as Profile | undefined;
		const week = profile !== undefined ? WeeklyBoard.unpaidWeek(profile, os.time()) : undefined;
		if (week === undefined) {
			return;
		}
		const ranks = WeeklyStores.finalRanks(week);
		if (ranks === undefined) {
			return;
		}
		const rank = ranks.get(player.UserId);
		const tier = rank !== undefined ? WeeklyBoard.tierFor(rank) : undefined;
		let paid = "";
		const committed = this._data.AtomicUpdate(
			player,
			(draft: Profile) => {
				if (WeeklyBoard.unpaidWeek(draft, os.time()) !== week) {
					return { ok: false, noop: true };
				}
				(draft.WeeklyBoard as Dict).ClaimedWeek = week;
				if (tier !== undefined) {
					paid = tostring(K.ProgressionService.ApplyReward(draft, tier.reward, K.Economy.Production(draft)));
				}
				return { ok: true };
			},
			true,
			"weekly board",
		);
		if (truthy(committed) && tier !== undefined && paid !== "") {
			this._toastPlayer(player, T("GameService.WeeklyBoard"), T("GameService.YouFinishedDLastWeek", rank!, paid), "Special");
			this._queueStatePush(player);
		}
	}

	_getLeaderboard(id: unknown) {
		if (!typeIs(id, "string")) {
			return responseError(T("GameService.ThatLeaderboardIsUnavailable"));
		}
		const weekly = id === WeeklyBoard.BOARD_ID;
		const store = (weekly ? WeeklyStores.current(os.time()) : this._leaderboardStores[id]) as Dict | undefined;
		if (store === undefined) {
			return responseError(T("GameService.ThatLeaderboardIsUnavailable"));
		}
		const cached = this._globalBoardCache[id];
		if (cached !== undefined && (cached.ExpiresAt as number) > os.clock()) {
			return responseSuccess(undefined, { Leaderboard: cached.Entries, LeaderboardId: id });
		}

		// store page: cached per board, shared in-flight read, stale page kept when a read fails
		const sorted = store as { GetSortedAsync(asc: boolean, size: number): { GetCurrentPage(): Dict[] } };
		const stored = boardReader.stored(id, weekly ? `week${WeeklyBoard.weekOf(os.time())}` : id, (size) =>
			sorted.GetSortedAsync(false, size).GetCurrentPage() as unknown as StoreRow[],
		);
		const live = new Map<number, unknown>();
		for (const online of Players.GetPlayers()) {
			const profile = this._data.Get(online) as Profile | undefined;
			if (profile !== undefined) {
				live.set(online.UserId, weekly ? WeeklyBoard.scoreOf(profile, os.time()) : generalBoardValue(profile, id));
			}
		}
		const rows = boardReader.rank(stored, live, (value) =>
			truthy(id === "Worlds" ? K.Economy.Gt(value, 1) : K.Economy.Gt(value, 0)),
		) as unknown as Dict[];
		this._primePlayerNames(rows);
		const entries: Dict[] = [];
		for (let index = 0; index < math.min(rows.size(), GLOBAL_LB_PAGE); index++) {
			const row = rows[index];
			entries.push({
				UserId: row.UserId,
				Name: this._resolvePlayerName(row.UserId as number),
				Value: row.Value,
				Category: id,
			});
		}
		this._globalBoardCache[id] = { Entries: entries, ExpiresAt: os.clock() + 15 };
		this._announceRankClimbs(id, rows);
		return responseSuccess(undefined, { Leaderboard: entries, LeaderboardId: id });
	}

	// action name -> handler (todo500 #2); action strings are unchanged, the first branch for a name wins
	_actionHandlers?: Map<string, (player: Player, action: string, payload: Dict | undefined) => Response>;
	_actionTable(): Map<string, (player: Player, action: string, payload: Dict | undefined) => Response> {
		if (this._actionHandlers !== undefined) {
			return this._actionHandlers;
		}
		const handlers = new Map<string, (player: Player, action: string, payload: Dict | undefined) => Response>();
		const on = (names: unknown[], handler: (player: Player, action: string, payload: Dict | undefined) => Response) => {
			for (const name of names) {
				if (typeIs(name, "string") && !handlers.has(name)) {
					handlers.set(name, handler);
				}
			}
		};
		on([K.Protocol.Actions.GetState], (player, action, payload) => {
			const runtime = this._runtime.get(player);
			if (runtime !== undefined) {
				runtime.BazaarRecoveryRetryAt = undefined;
			}
			const snapshot = this._snapshot(player);
			this._forgetSentSections(player);
			return snapshot !== undefined ? responseSuccess(undefined, { State: snapshot }) : responseError(T("GameService.ProfileIsStillLoading"));
		});
		on([K.Protocol.Actions.MeasureLatency], (player, action, payload) => {
			return responseSuccess(undefined);
		});
		on([K.Protocol.Actions.SubmitFeedback], (player, action, payload) => {
			return this._submitFeedback(player, payload);
		});
		on([K.Protocol.Actions.ReportPlayer], (player, action, payload) => {
			return this._reportPlayer(player, payload);
		});
		on([K.Protocol.Actions.GetPlayers], (player, action, payload) => {
			return this._getPlayers(player);
		});
		on([K.Protocol.Actions.GetPlayerMirror], (player, action, payload) => {
			return this._getPlayerMirror(player, payload);
		});
		on([K.Protocol.Actions.VisitPlot], (player, action, payload) => {
			return this._visitPlot(player, payload);
		});
		on([K.Protocol.Actions.LeavePlot], (player, action, payload) => {
			return this._leavePlot(player);
		});
		on([K.Protocol.Actions.NudgeCrew], (player, action, payload) => {
			return this._nudgeCrew(player, payload);
		});
		on([K.Protocol.Actions.ReportPresence], (player, action, payload) => {
			return this._reportPresence(player, payload);
		});
		on([K.Protocol.Actions.GetGuild], (player, action, payload) => {
			const profile = this._data.Get(player) as Profile | undefined;
			return responseSuccess(undefined, {
				Guild: profile !== undefined ? this._guilds.GetPublic(typeIs(profile.Guild, "table") ? (profile.Guild as Dict).Id : "") : undefined,
			});
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.GetGuildLeaderboard], (player, action, payload) => {
			return responseSuccess(undefined, {
				GuildLeaderboard: this._guilds.GetLeaderboard(payload !== undefined ? (payload.Page ?? 1) : 1),
			});
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.GetLeaderboard], (player, action, payload) => {
			return this._getLeaderboard(payload !== undefined ? payload.Id : undefined);
		});
		on([K.Protocol.Actions.GetAdminState], (player, action, payload) => {
			return this._admin !== undefined
				? responseSuccess(undefined, { Admin: this._admin.State(player) })
				: responseError(T("GameService.AdministrationIsUnavailable"));
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.AdminExecute], (player, action, payload) => {
			if (this._admin === undefined) {
				return responseError(T("GameService.AdministrationIsUnavailable"));
			}
			const result = this._admin.Execute(player, payload) as Dict;
			if (truthy(result.ok) && typeIs(result.TargetUserId, "number")) {
				const target = Players.GetPlayerByUserId(result.TargetUserId);
				const targetProfile = target !== undefined ? (this._data.Get(target) as Profile | undefined) : undefined;
				if (target !== undefined && targetProfile !== undefined && result.World !== true) {
					this._syncLeaderstats(target, targetProfile);
					if (target !== player) {
						this._pushState(target);
						this._toastPlayer(
							target,
							T("GameService.ForgemasterGrant"),
							truthy(result.message) ? result.message : T("GameService.YourProfileWasUpdated"),
							"Special",
						);
					}
				}
			}
			return result;
		});
		on([K.Protocol.Actions.CreateGuild, K.Protocol.Actions.JoinGuild, K.Protocol.Actions.LeaveGuild, K.Protocol.Actions.DisbandGuild, K.Protocol.Actions.KickGuildMember, K.Protocol.Actions.SetGuildRole, K.Protocol.Actions.RenameGuild, K.Protocol.Actions.ContributeGuild, K.Protocol.Actions.BuyGuildUpgrade, K.Protocol.Actions.ClaimGuildGoal, K.Protocol.Actions.SendGuildChat, K.Protocol.Actions.GetGuildChatHistory, K.Protocol.Actions.GetGuildAnnouncements, K.Protocol.Actions.GetGuildSettings, K.Protocol.Actions.SetGuildSettings, K.Protocol.Actions.GetGuildLogoReview, K.Protocol.Actions.CreateGuildAnnouncement, K.Protocol.Actions.EditGuildAnnouncement, K.Protocol.Actions.PinGuildAnnouncement, K.Protocol.Actions.ArchiveGuildAnnouncement, K.Protocol.Actions.SetGuildAnnouncementExpiry, K.Protocol.Actions.MuteGuildMember, K.Protocol.Actions.UnmuteGuildMember, K.Protocol.Actions.BanGuildMember, K.Protocol.Actions.UnbanGuildMember, K.Protocol.Actions.UploadGuildLogo, K.Protocol.Actions.ModerateGuildLogo], (player, action, payload) => {
			return this._guildAction(player, action as string, payload ?? {}) as Response;
		});
		on([K.Protocol.Actions.GetTrade, K.Protocol.Actions.InviteTrade, K.Protocol.Actions.RespondTrade, K.Protocol.Actions.UpdateTradeOffer, K.Protocol.Actions.SetTradeReady, K.Protocol.Actions.ConfirmTrade, K.Protocol.Actions.CancelTrade, K.Protocol.Actions.TradeViewAway, K.Protocol.Actions.TradeChat, K.Protocol.Actions.TradeRequest], (player, action, payload) => {
			const policyNote = PolicyGate.TradeBlocked(player, action as string, payload);
			if (policyNote !== undefined) {
				return responseError(policyNote);
			}
			return this._tradeAction(player, action as string, payload ?? {});
		});
		on([K.Protocol.Actions.CollectVault], (player, action, payload) => {
			return this._collect(player);
		});
		on([K.Protocol.Actions.Overcharge], (player, action, payload) => {
			return this._overcharge(player);
		});
		on([K.Protocol.Actions.BuyMachine], (player, action, payload) => {
			return this._buyMachine(player, payload?.Id, payload?.Amount);
		});
		on([K.Protocol.Actions.SetAutoForge], (player, action, payload) => {
			return this._setAutoForge(player, payload);
		});
		on([K.Protocol.Actions.BuyResearch], (player, action, payload) => {
			return this._buyResearch(player, payload?.Id, payload?.Amount);
		});
		on([K.Protocol.Actions.BuyGridUpgrade], (player, action, payload) => {
			return responseError(
				T("GameService.StarGridPurchasesHaveRetired"),
			);
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.UpgradeContinuum], (player, action, payload) => {
			return this._upgradeContinuum(player);
		});
		on([K.Protocol.Actions.FoundryAct], (player, action, payload) => {
			return this._foundryAct(player, payload);
		});
		on([K.Protocol.Actions.EchoAct], (player, action, payload) => {
			return this._echoAct(player, payload);
		});
		on([K.Protocol.Actions.UnlockZone], (player, action, payload) => {
			return this._unlockZone(player, payload?.Id);
		});
		on([K.Protocol.Actions.SelectZone], (player, action, payload) => {
			return this._selectZone(player, payload?.Id);
		});
		on([K.Protocol.Actions.Rebirth], (player, action, payload) => {
			return this._rebirth(player, payload);
		});
		on([K.Protocol.Actions.RebirthAct], (player, action, payload) => {
			return this._rebirthAct(player, payload);
		});
		on([K.Protocol.Actions.Ascend], (player, action, payload) => {
			return this._ascend(player);
		});
		on([K.Protocol.Actions.UpgradeSigil], (player, action, payload) => {
			return this._upgradeSigil(player, payload);
		});
		on([K.Protocol.Actions.DomainExpansion], (player, action, payload) => {
			return this._domainExpansion(player);
		});
		on([K.Protocol.Actions.DomainLattice], (player, action, payload) => {
			return this._domainLattice(player, payload);
		});
		on([K.Protocol.Actions.EventAct], (player, action, payload) => {
			return this._eventAct(player, payload);
		});
		on([K.Protocol.Actions.CompanionAct], (player, action, payload) => {
			return this._companionAct(player, payload);
		});
		on([K.Protocol.Actions.ExpeditionAct], (player, action, payload) => {
			return this._expeditionAct(player, payload);
		});
		on([K.Protocol.Actions.ProgramAct], (player, action, payload) => {
			return this._programAct(player, payload);
		});
		on([K.Protocol.Actions.ConstellationAct], (player, action, payload) => {
			return this._constellationAct(player, payload);
		});
		on([K.Protocol.Actions.ClaimConvergenceReward], (player, action, payload) => {
			return this._convergence.Claim(player, payload?.Tier) as Response;
		});
		on([K.Protocol.Actions.ClaimQuest], (player, action, payload) => {
			return this._claimQuest(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimAchievement], (player, action, payload) => {
			return this._claimAchievement(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimDaily], (player, action, payload) => {
			return this._claimDaily(player);
		});
		on([K.Protocol.Actions.ClaimTimedReward], (player, action, payload) => {
			return this._claimTimedReward(player, payload?.Index);
		});
		on([K.Protocol.Actions.SpinWheel], (player, action, payload) => {
			return this._spinWheel(player, payload);
		});
		on([K.Protocol.Actions.BazaarPlay], (player, action, payload) => {
			return this._bazaarPlay(player, payload);
		});
		on([K.Protocol.Actions.SelectSpecialization], (player, action, payload) => {
			return this._mutate(player, (profile: Profile) => {
				const [selected, message] = K.Specializations.Select(profile.Specialization, payload?.Id, os.time()) as LuaTuple<
					[Dict | undefined, unknown]
				>;
				if (selected === undefined) {
					return responseError(message);
				}
				const previous = profile.Specialization;
				if (selected.Focus === (K.Specializations.Sanitize(previous) as Dict).Focus) {
					return responseSuccess(message);
				}
				profile.Specialization = selected;
				if (truthy(K.Economy.Gt(profile.Vault, K.Economy.Capacity(profile)))) {
					profile.Specialization = previous;
					return responseError(T("GameService.CollectYourVaultBeforeEquipping"));
				}
				return responseSuccess(message);
			});
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.SetMarketFavorite], (player, action, payload) => {
			return this._mutate(player, (profile: Profile) => {
				const [ok, message] = K.BazaarService.SetFavorite(profile, payload) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.RequestProcurement], (player, action, payload) => {
			return this._mutate(player, (profile: Profile) => {
				const [ok, message] = K.BazaarService.Procure(profile, payload, os.time()) as LuaTuple<[unknown, unknown]>;
				return truthy(ok) ? responseSuccess(message) : responseError(message);
			});
			return responseError(T("RemoteFirewall.UnknownForgeCommand"));
		});
		on([K.Protocol.Actions.LaunchExpedition], (player, action, payload) => {
			return this._launchExpedition(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimExpedition], (player, action, payload) => {
			return this._claimExpedition(player);
		});
		on([K.Protocol.Actions.EquipArtifact], (player, action, payload) => {
			return this._equipArtifact(player, payload?.Id);
		});
		on([K.Protocol.Actions.UpgradeArtifact], (player, action, payload) => {
			return this._upgradeArtifact(player, payload?.Id);
		});
		on([K.Protocol.Actions.BuyArtifact], (player, action, payload) => {
			return this._buyArtifact(player, payload?.Id);
		});
		on([K.Protocol.Actions.UpgradeCrew], (player, action, payload) => {
			return this._upgradeCrew(player, payload?.Role);
		});
		on([K.Protocol.Actions.ClaimCommanderReward], (player, action, payload) => {
			return this._claimCommanderReward(player, payload?.Level);
		});
		on([K.Protocol.Actions.ClaimWeeklyDirective], (player, action, payload) => {
			return this._claimWeeklyDirective(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimSeasonTier], (player, action, payload) => {
			return this._claimSeasonTier(player, payload?.Tier);
		});
		on([K.Protocol.Actions.ClaimSeasonPremium], (player, action, payload) => {
			return this._claimSeasonPremium(player, payload?.Tier);
		});
		on([K.Protocol.Actions.ClaimForgePathStep], (player, action, payload) => {
			return this._claimForgePathStep(player, payload?.Step);
		});
		on([K.Protocol.Actions.BuySignalOffer], (player, action, payload) => {
			return this._buySignalOffer(player, payload?.Id);
		});
		on([K.Protocol.Actions.EquipTitle], (player, action, payload) => {
			return this._equipTitle(player, payload?.Id);
		});
		on([K.Protocol.Actions.SetProfileStyle], (player, action, payload) => {
			return this._setProfileStyle(player, payload?.Accent, payload?.Frame);
		});
		on([K.Protocol.Actions.RedeemCode], (player, action, payload) => {
			return this._redeemCode(player, payload?.Code);
		});
		on([K.Protocol.Actions.VerifyCreatorFollow], (player, action, payload) => {
			return this._verifyCreatorFollow(player);
		});
		on([K.Protocol.Actions.ClaimCommunityReward], (player, action, payload) => {
			return this._claimCommunityReward(player, payload?.Kind, payload?.Index);
		});
		on([K.Protocol.Actions.SyncShop], (player, action, payload) => {
			return this._syncShop(player);
		});
		on([K.Protocol.Actions.StudioGrantProduct], (player, action, payload) => {
			return this._studioGrantProduct(player, payload?.Id);
		});
		on([K.Protocol.Actions.ActivateBoost], (player, action, payload) => {
			return this._activateBoost(player, payload?.Id, payload?.Buy);
		});
		on([K.Protocol.Actions.BuyDailyOffer], (player, action, payload) => {
			return this._buyDailyOffer(player, payload?.Slot);
		});
		on([K.Protocol.Actions.BuyCrateSkin], (player, action, payload) => {
			return this._buyCrateSkin(player, payload?.Id);
		});
		on([K.Protocol.Actions.EquipCrateSkin], (player, action, payload) => {
			return this._equipCrateSkin(player, payload?.Id);
		});
		on([K.Protocol.Actions.FuseRelics], (player, action, payload) => {
			return this._fuseRelics(player, payload?.Id);
		});
		on([K.Protocol.Actions.EngraveRelic], (player, action, payload) => {
			return this._engraveRelic(player, payload);
		});
		on([K.Protocol.Actions.CraftRelic], (player, action, payload) => {
			return this._craftRelic(player, payload?.Id, payload?.Sacrifice);
		});
		on([K.Protocol.Actions.BuyItemOffer], (player, action, payload) => {
			return this._buyItemOffer(player, payload?.Id);
		});
		on([K.Protocol.Actions.OpenItemCrate], (player, action, payload) => {
			return this._openItemCrate(player, payload?.Id, payload?.Count);
		});
		on([K.Protocol.Actions.EquipItem], (player, action, payload) => {
			return this._equipItem(player, payload?.Uid, payload?.Target);
		});
		on([K.Protocol.Actions.UnequipItem], (player, action, payload) => {
			return this._unequipItem(player, payload?.Target);
		});
		on([K.Protocol.Actions.UpgradeItem], (player, action, payload) => {
			return this._upgradeItem(player, payload?.Uid);
		});
		on([K.Protocol.Actions.SalvageItem], (player, action, payload) => {
			return this._salvageItem(player, payload?.Uid);
		});
		on([K.Protocol.Actions.BulkSalvageItems], (player, action, payload) => {
			return this._bulkSalvageItems(player, payload?.Uids);
		});
		on([K.Protocol.Actions.EquipBestItems], (player, action, payload) => {
			return this._equipBestItems(player);
		});
		on([K.Protocol.Actions.ToggleItemLock], (player, action, payload) => {
			return this._toggleItemLock(player, payload?.Uid);
		});
		on([K.Protocol.Actions.SetItemAutoSalvage], (player, action, payload) => {
			return this._setItemAutoSalvage(player, payload);
		});
		on([K.Protocol.Actions.SetSetting], (player, action, payload) => {
			return this._setSetting(player, payload);
		});
		on([K.Protocol.Actions.SetMobileLayout], (player, action, payload) => {
			return this._setMobileLayout(player, payload);
		});
		on([K.Protocol.Actions.ChatOpenWhisper], (player, action, payload) => {
			return this._chat.OpenWhisper(player, payload) as Response;
		});
		on([K.Protocol.Actions.ChatGlobal], (player, action, payload) => {
			return this._chat.SendGlobal(player, payload) as Response;
		});
		on([K.Protocol.Actions.GetCrew], (player, action, payload) => {
			return this._crews.Get(player) as Response;
		});
		on([K.Protocol.Actions.CrewInvite], (player, action, payload) => {
			return this._crews.Invite(player, payload) as Response;
		});
		on([K.Protocol.Actions.CrewRespond], (player, action, payload) => {
			return this._crews.Respond(player, payload) as Response;
		});
		on([K.Protocol.Actions.CrewLeave], (player, action, payload) => {
			return this._crews.Leave(player) as Response;
		});
		on([K.Protocol.Actions.CrewKick], (player, action, payload) => {
			return this._crews.Kick(player, payload) as Response;
		});
		on([K.Protocol.Actions.CrewRename], (player, action, payload) => {
			return this._crews.Rename(player, payload) as Response;
		});
		on([K.Protocol.Actions.CrewClaim], (player, action, payload) => {
			return this._crews.Claim(player, payload) as Response;
		});
		on([K.Protocol.Actions.SetTutorialStep], (player, action, payload) => {
			return this._setTutorialStep(player, payload?.Step);
		});
		on([K.Protocol.Actions.MarkHintSeen], (player, action, payload) => {
			return this._markHintSeen(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimFirstGoal], (player, action, payload) => {
			return this._claimFirstGoal(player, payload?.Id);
		});
		on([K.Protocol.Actions.CompleteTutorial], (player, action, payload) => {
			return this._completeTutorial(player);
		});
		on([K.Protocol.Actions.ReplayTutorial], (player, action, payload) => {
			return this._replayTutorial(player);
		});
		on([K.Protocol.Actions.DismissRelease], (player, action, payload) => {
			return this._dismissRelease(player);
		});
		on([K.Protocol.Actions.OpenRelease], (player, action, payload) => {
			return this._openRelease(player);
		});
		on([K.Protocol.Actions.ReadStoryChapter], (player, action, payload) => {
			return this._readStoryChapter(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimStoryChapter], (player, action, payload) => {
			return this._claimStoryChapter(player, payload?.Id);
		});
		on([K.Protocol.Actions.ReadMail], (player, action, payload) => {
			return this._readMail(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimMail], (player, action, payload) => {
			return this._claimMail(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimAllMail], (player, action, payload) => {
			return this._claimAllMail(player);
		});
		on([K.Protocol.Actions.DeleteMail], (player, action, payload) => {
			return this._deleteMail(player, payload?.Id);
		});
		on([K.Protocol.Actions.PulseAnomaly], (player, action, payload) => {
			return this._pulseAnomaly(player);
		});
		on([K.Protocol.Actions.StabilizeAnomaly], (player, action, payload) => {
			return this._stabilizeAnomaly(player);
		});
		on([K.Protocol.Actions.BuyAnomalyProtocol], (player, action, payload) => {
			return this._buyAnomalyProtocol(player, payload?.Id);
		});
		on([K.Protocol.Actions.ActivateAnomalySurge], (player, action, payload) => {
			return this._activateAnomalySurge(player);
		});
		on([K.Protocol.Actions.SetAnomalyChannel], (player, action, payload) => {
			return this._setAnomalyChannel(player, payload?.Id);
		});
		on([K.Protocol.Actions.SetAnomalyLoadout], (player, action, payload) => {
			return this._setAnomalyLoadout(player, payload?.Loadout);
		});
		on([K.Protocol.Actions.ClaimAnomalyMilestone], (player, action, payload) => {
			return this._claimAnomalyMilestone(player, payload?.Tier);
		});
		on([K.Protocol.Actions.ClaimAnomalyDirective], (player, action, payload) => {
			return this._claimAnomalyDirective(player, payload?.Id);
		});
		on([K.Protocol.Actions.ClaimLabOrder], (player, action, payload) => {
			return this._claimLabOrder(player, payload?.Id);
		});
		on([K.Protocol.Actions.RouteLabPower], (player, action, payload) => {
			return this._routeLabPower(player, payload?.Channel, payload?.Delta);
		});
		this._actionHandlers = handlers;
		return handlers;
	}

	_handleAction(player: Player, action: unknown, rawPayload: unknown): Response {
		if (!truthy(K.CommandActionValidators.IsValidAction(action))) {
			return responseError(T("GameService.InvalidRequest"));
		}
		const payload = typeIs(rawPayload, "table") ? (rawPayload as Dict) : undefined;
		if (action === K.Protocol.Actions.ReportClientIntegrity) {
			const accepted = RemoteFirewall.processFirewallViolation(
				player,
				payload !== undefined ? payload.ActionType : undefined,
				payload !== undefined ? payload.PenaltyCode : undefined,
			);
			return truthy(accepted) ? responseSuccess(undefined) : responseError(T("GameService.IntegrityReportRejected"));
		}
		if (action === K.Protocol.Actions.ReportPerformance) {
			return truthy(this._analytics.RecordPerformance(player, payload))
				? responseSuccess(undefined)
				: responseError(T("GameService.PerformanceSampleWasAlreadyReceived"));
		}
		const featureId = featureByAction[action as string];
		if (truthy(featureId)) {
			const profile = this._data.Get(player) as Profile | undefined;
			const domainOpen =
				featureId === "Domain" &&
				profile !== undefined &&
				typeIs(profile.Domain, "table") &&
				(tonumber((profile.Domain as Dict).Rank) ?? 0) >= 1;
			if (profile !== undefined && !domainOpen && !truthy(K.ProgressionGate.IsFeatureUnlocked(profile, featureId))) {
				const rule = (K.GameConfig.Unlocks as Dict)[featureId as string] as Dict | undefined;
				const name = rule !== undefined && truthy(rule.Name) ? rule.Name : featureId;
				if (rule !== undefined && typeIs(rule.Requirement, "string") && rule.Requirement !== "") {
					return responseError(string.format("%s is locked. %s to open it.", tostring(name), rule.Requirement));
				}
				return responseError(
					tostring(name) +
						" unlocks when you " +
						string.lower(rule !== undefined && truthy(rule.Requirement) ? tostring(rule.Requirement) : "progress further") +
						".",
				);
			}
		}
		const handler = this._actionTable().get(action as string);
		if (handler !== undefined) {
			// Flag remote handlers that yield for over a second (todo500 #34); the response is unchanged.
			const started = os.clock();
			const response = handler(player, action as string, payload);
			const took = os.clock() - started;
			if (took > 1) {
				K.ModuleLog.Every("slow-action:" + (action as string), 60, "Perf", string.format("%s took %.2fs", action as string, took));
			}
			return response;
		}
		return responseError(T("RemoteFirewall.UnknownForgeCommand"));
	}

	_processOffline(player: Player, profile: Profile) {
		const previousLastSeen = this._data.GetPreviousLastSeen(player);
		const now = os.time();
		const [reward, elapsed, averageEfficiency, capped] = K.Economy.OfflineEarnings(profile, previousLastSeen, now) as LuaTuple<
			[unknown, number, number, unknown]
		>;
		const awaySeconds = math.max(elapsed, math.max(0, now - (tonumber(previousLastSeen) ?? now)));
		const capHours = K.Economy.OfflineHours(profile);
		if (truthy(K.Economy.Gt(reward, 0))) {
			profile.Cash = K.Economy.Add(profile.Cash, reward);
			profile.RunCash = K.Economy.Add(profile.RunCash, reward);
			profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, reward);
			const stats = ensureStats(profile) as Dict;
			stats.Collected = K.Economy.Add(stats.Collected, reward);
			const rewardNumber = K.Economy.AsNumber(reward);
			K.ProgressionService.Progress(profile, "EarnCash", rewardNumber);
			K.LabService.Progress(profile, "BankFlux", rewardNumber);
		}
		return $tuple(reward, elapsed, averageEfficiency, capped, awaySeconds, capHours);
	}

	_onPlayerAdded(player: Player, stealLock?: boolean) {
		if (this._admin !== undefined && truthy(this._admin.EnforceServerBan(player))) {
			return;
		}
		const [loaded, errorMessage] = this._data.Load(player, stealLock) as LuaTuple<[unknown, unknown]>;
		if (!truthy(loaded)) {
			if (errorMessage === "refreshing" || this._refreshing() || player.Parent !== Players) {
				return;
			}
			error(truthy(errorMessage) ? errorMessage : "profile load failed", 0);
		}
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			return;
		}

		const profile = this._data.Get(player) as Profile | undefined;
		if (profile === undefined) {
			this._data.Save(player, true);
			return;
		}
		this._antiCheat.Observe(player, "Load", profile);
		const membershipBeforeReconcile = profile.Guild as Dict | undefined;
		const membershipGuildId = membershipBeforeReconcile !== undefined ? (membershipBeforeReconcile.Id as string) : "";
		this._guilds.ReconcileMembership(profile, player.UserId);
		if (membershipGuildId !== "" && truthy(this._guildCommunity.IsBanned(membershipGuildId, player.UserId))) {
			this._guilds._update(membershipGuildId, (current: Dict) => {
				(current.Members as Dict)[tostring(player.UserId)] = undefined;
				return current;
			});
			profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
			profile.GuildBonuses = emptyBonuses();
		}
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			return;
		}

		applySocialBoost(profile, 0, player.MembershipType === Enum.MembershipType.Premium);
		const [offlineReward, offlineSeconds, offlineEfficiency, offlineCapped, offlineAwaySeconds, offlineCapHours] = this._processOffline(
			player,
			profile,
		) as LuaTuple<[unknown, number, number, unknown, number, unknown]>;
		this._antiCheat.SyncBaseline(player, profile);
		K.ProgressionService.EnsureQuests(profile, player.UserId);
		K.ProgressionService.EnsureTimedRewards(profile);
		K.ProgressionService.EnsureCommandRotations(profile);
		ensureItemShop(profile);
		K.AnomalyService.Ensure(profile);
		K.LabService.Ensure(profile, player.UserId);
		const [rigCount, rigNote] = grantLitRigs(profile);
		bumpStat(profile, "Joins", 1);
		(profile.Meta as Dict).Revision = ((profile.Meta as Dict).Revision as number) + 1;
		this._data.MarkDirty(player);
		const runtime: Runtime = {
			LastTap: 0,
			TapCombo: 0,
			LeaderboardRank: 0,
			ProductionAccumulator: 0,
			AutoForgeAccumulator: 0,
			PushAccumulator: 0,
			DirtyAccumulator: 0,
			MaintenanceAccumulator: 0,
			GuildRefreshAccumulator: 0,
			GuildRefreshBusy: false,
			PendingAnomalyActions: [],
			SnapshotId: 0,
			OfflineReward: offlineReward,
			OfflineSeconds: offlineSeconds,
			OfflineEfficiency: offlineEfficiency,
			OfflineCapped: offlineCapped,
			OfflineAwaySeconds: offlineAwaySeconds,
			OfflineCapHours: offlineCapHours,
		};
		this._runtime.set(player, runtime);
		if (!this._running || player.Parent !== Players) {
			this._data.Save(player, true);
			this._runtime.delete(player);
			return;
		}
		const [spawned, spawnProblem] = pcall(() => {
			runtime.MatterEntity = this._matter.SpawnPlayer(player, runtime, profile);
		});
		if (!spawned) {
			if (!this._running) {
				this._data.Save(player, true);
				this._runtime.delete(player);
				return;
			}
			error(spawnProblem, 0);
		}
		pcall(() => {
			this._analytics.PlayerJoined(player, profile);
		});
		pcall(() => {
			this._badges.Evaluate(player, profile);
		});

		this._createLeaderstats(player);
		this._syncLeaderstats(player, profile);
		const [plotted, plotProblem] = pcall(() => {
			this._world.CreatePlot(player);
		});
		if (!plotted) {
			if (!this._running) {
				return;
			}
			K.ModuleLog.Warn("Player", string.format("plot setup failed for %s - %s", player.Name, tostring(plotProblem)));
		}

		table.clear(this._globalBoardCache);
		player.SetAttribute("AstralForgeLoaded", true);

		const joinedRuntime = runtime;
		this._spawnWorker(() => {
			this._syncShop(player);
			if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
				this._pushState(player);
			}
		});

		const previousCharacterConnection = this._characterConnections.get(player);
		if (previousCharacterConnection !== undefined) {
			previousCharacterConnection.Disconnect();
		}
		this._characterConnections.set(
			player,
			player.CharacterAdded.Connect((character) => {
				task.defer(() => {
					const animate = character.WaitForChild("Animate", 3);
					const mood = animate !== undefined ? animate.FindFirstChild("mood") : undefined;
					if (mood !== undefined) {
						mood.Destroy();
					}
				});
				this._spawnWorker(() => {
					task.wait(0.15);
					if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
						this._world.TeleportToPlot(player);
					}
				});
			}),
		);
		if (player.Character !== undefined) {
			this._spawnWorker(() => {
				if (this._running && player.Parent === Players && this._runtime.get(player) === joinedRuntime) {
					this._world.TeleportToPlot(player);
				}
			});
		}

		this._pushState(player);
		if (rigCount > 0) {
			this._toastPlayer(player, rigCount === 1 ? T("GameService.RigLit") : T("GameService.RigsLit"), rigNote, "Success");
		}
		const away = Deps.formatAway(offlineSeconds);
		K.ModuleLog.Player(player, string.format("joined world %d after %s away", profile.CurrentZone as number, away));
	}

	_refreshing(): boolean {
		if (this._running !== true) {
			return true;
		}
		const data = this._data;
		if (data === undefined) {
			return true;
		}
		const [ok, closing] = pcall(() => data.IsClosing());
		return ok && closing === true;
	}

	_safePlayerAdded(player: Player) {
		if (this._refreshing() || this._joining.get(player) !== undefined || this._runtime.get(player) !== undefined) {
			return;
		}
		this._joining.set(player, true);
		let attempts = 0;
		let lockNoticeAt = 0;
		let lockSince: number | undefined;
		let stealNoticeAt = 0;
		while (player.Parent === Players && !this._refreshing()) {
			attempts += 1;
			if (this._runtime.get(player) !== undefined) {
				break;
			}
			const stealLock = lockSince !== undefined && os.clock() - lockSince > 90;
			const [ok, problem] = pcall(() => this._onPlayerAdded(player, stealLock));
			if (this._runtime.get(player) !== undefined) {
				break;
			}
			if (this._refreshing() || player.Parent !== Players) {
				break;
			}
			if (!ok) {
				K.ModuleLog.Every(
					"join-retry:" + tostring(player.UserId),
					8,
					"Player",
					string.format("%s join retry %d: %s", player.Name, attempts, tostring(problem)),
				);
			}
			const locked = typeIs(problem, "string") && string.lower(tostring(problem)).find("another server", 1, true)[0] !== undefined;
			if (locked) {
				if (lockSince === undefined) {
					lockSince = os.clock();
				}
				if (os.clock() - lockNoticeAt > 25) {
					lockNoticeAt = os.clock();
					this._toastPlayer(
						player,
						T("GameService.SaveIsStillSyncing"),
						T("GameService.YourDataIsStillActive"),
						"Info",
					);
				}
				if (stealLock && os.clock() - stealNoticeAt > 60) {
					stealNoticeAt = os.clock();
					K.ModuleLog.Warn("Player", string.format("%s save lock held for %.0fs, taking it over", player.Name, os.clock() - lockSince), {
						UserId: player.UserId,
					});
					this._toastPlayer(
						player,
						T("GameService.TakingOverYourSession"),
						T("GameService.YourOtherSessionIsBeing"),
						"Info",
					);
				}
				task.wait(2.5);
				continue;
			}
			lockSince = undefined;
			if (attempts >= 10) {
				if (attempts === 10) {
					K.ModuleLog.Error(
						"Player",
						string.format("%s join retries degraded to slow retry after %d attempts — %s", player.Name, attempts, tostring(problem)),
						{ UserId: player.UserId },
					);
					this._toastPlayer(
						player,
						T("GameService.StillConnecting"),
						T("GameService.YourSaveIsTakingLonger"),
						"Warning",
					);
				}
				task.wait(25);
				continue;
			}
			task.wait(math.min(0.8 + attempts * 0.25, 5));
		}
		this._joining.delete(player);
		if (this._runtime.get(player) !== undefined || player.Parent !== Players) {
			return;
		}
		if (this._data.Get(player) !== undefined) {
			pcall(() => {
				this._data.Save(player, true);
			});
		}
	}

	_onPlayerRemoving(player: Player) {
		K.ModuleLog.Player(player, "left, saving");
		this._joining.delete(player);
		this._saveFailedToastAt.delete(player);
		const characterConnection = this._characterConnections.get(player);
		if (characterConnection !== undefined) {
			characterConnection.Disconnect();
		}
		this._characterConnections.delete(player);
		const pendingPush = this._queuedStatePushes.get(player);
		if (pendingPush !== undefined) {
			task.cancel(pendingPush);
		}
		this._queuedStatePushes.delete(player);
		this._presence.delete(player.UserId);
		this._clearVisit(player, true);
		const hosted = this._visitors.get(player.UserId);
		if (hosted !== undefined) {
			for (const [visitor] of hosted) {
				this._visiting.delete(visitor);
				if (visitor.Parent === Players) {
					this._toastPlayer(visitor, T("Toast.VisitEndedTitle"), T("Toast.VisitEndedBody"), "Info");
					this._effect.fire(visitor, { Type: "VisitEnded" });
				}
			}
			this._visitors.delete(player.UserId);
		}
		// Leave flush order (todo500 #14): 1) cancel open trades, 2) guild state (nothing to flush: GuildService writes guild docs on each change),
		// 3) analytics and per-player caches, 4) release the profile with a final save.
		const profile = this._data.Get(player) as Profile | undefined;
		this._convergence.PlayerRemoving(player);
		// 1) trade cancel
		if (this._trades !== undefined) {
			const notify = this._trades.Drop(player.UserId) as number[];
			for (const userId of notify) {
				const other = Players.GetPlayerByUserId(userId);
				if (other !== undefined) {
					this._toastPlayer(other, T("Toast.TradeClosedTitle"), T("Toast.TradeClosedBody"), "Info");
					this._pushState(other, true);
				}
			}
		}
		if (profile !== undefined) {
			this._analytics.PlayerLeft(player, profile);
			this._data.MarkDirty(player);
		}
		this._world.RemovePlot(player);
		const runtime = this._runtime.get(player);
		if (runtime !== undefined && runtime.MatterEntity !== undefined) {
			this._matter.Despawn(runtime.MatterEntity as number);
		}
		this._runtime.delete(player);
		this._economyLedgers?.Drop(player.UserId);
		this._firewall.Forget(player);
		Ledger.ForgetIfQuiet(player.UserId);
		this._session.Forget(player);
		this._antiCheat.Forget(player);
		if (this._admin !== undefined) {
			this._admin.Forget(player);
		}
		this._analytics.Forget(player);
		this._badges.Forget(player);
		// 4) profile release
		if (!truthy(this._data.Save(player, true))) {
			this._spawnWorker(() => {
				for (let attempt = 1; attempt <= 3; attempt++) {
					task.wait(attempt * 2);
					if (!this._running || this._data.Get(player) === undefined) {
						return;
					}
					if (truthy(this._data.Save(player, true))) {
						return;
					}
				}
				K.ModuleLog.Warn("Data", string.format("release retries exhausted for %s", player.Name));
			});
		}
		this._queueSocialBoostRefresh();
	}

	_queueGuildMembershipRefresh(player: Player, runtime: Runtime) {
		if (truthy(runtime.GuildRefreshBusy)) {
			return;
		}
		const profile = this._data.Get(player) as Profile | undefined;
		const guildId = profile !== undefined && typeIs(profile.Guild, "table") ? (((profile.Guild as Dict).Id as string) ?? "") : "";
		if (guildId === "") {
			return;
		}
		runtime.GuildRefreshBusy = true;
		const shadow = {
			Guild: copyDictionary(profile!.Guild) as Dict,
			GuildBonuses: copyDictionary(profile!.GuildBonuses ?? { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 }) as Dict,
		};
		this._spawnWorker(() => {
			const [resolved, problem] = pcall(() => {
				this._guilds.ReconcileMembership(shadow, player.UserId);
			});
			if (resolved && this._running && player.Parent === Players && this._runtime.get(player) === runtime) {
				let changed = false;
				const committed = this._data.AtomicUpdate(
					player,
					(current: Profile) => {
						const currentGuild = current.Guild as Dict | undefined;
						if (currentGuild === undefined || currentGuild.Id !== guildId) {
							return { ok: false, noop: true };
						}
						const desiredGuild = (shadow.Guild ?? { Id: "", Role: "", JoinedAt: 0, Tag: "" }) as Dict;
						const desiredBonuses = (shadow.GuildBonuses ?? { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 }) as Dict;
						const currentBonuses = (current.GuildBonuses ?? {}) as Dict;
						changed =
							currentGuild.Id !== desiredGuild.Id ||
							currentGuild.Role !== desiredGuild.Role ||
							currentGuild.Tag !== desiredGuild.Tag ||
							currentGuild.JoinedAt !== desiredGuild.JoinedAt ||
							currentBonuses.Production !== desiredBonuses.Production ||
							currentBonuses.Capacity !== desiredBonuses.Capacity ||
							currentBonuses.Offline !== desiredBonuses.Offline;
						if (!changed) {
							return { ok: false, noop: true };
						}
						current.Guild = copyDictionary(desiredGuild);
						current.GuildBonuses = copyDictionary(desiredBonuses);
						return { ok: true };
					},
					true,
					"guild-refresh",
				);
				if (truthy(committed) && changed) {
					this._queueStatePush(player);
				}
			} else if (!resolved) {
				K.ModuleLog.Every(
					"guild-refresh:" + tostring(player.UserId),
					30,
					"Guild",
					string.format("guild refresh failed for %s: %s", player.Name, tostring(problem)),
				);
			}
			runtime.GuildRefreshBusy = false;
		});
	}

	// Per-system player tick steps, run in this order every heartbeat (todo500 #6). Each step owns its accumulator.
	_playerTickStepCache?: ReadonlyArray<[string, (player: Player, runtime: Runtime) => void]>;
	_playerTickSteps(): ReadonlyArray<[string, (player: Player, runtime: Runtime) => void]> {
		if (this._playerTickStepCache !== undefined) {
			return this._playerTickStepCache;
		}
		this._playerTickStepCache = [
			["Maintenance", (player, runtime) => this._playerTickMaintenance(player, runtime)],
			["GuildRefresh", (player, runtime) => this._playerTickGuildRefresh(player, runtime)],
			["Production", (player, runtime) => this._playerTickProduction(player, runtime)],
			["Automation", (player, runtime) => this._playerTickAutomation(player, runtime)],
			["Dirty", (player, runtime) => this._playerTickDirty(player, runtime)],
			["StatePush", (player, runtime) => this._playerTickStatePush(player, runtime)],
		];
		return this._playerTickStepCache;
	}

	_processPlayerTick(player: Player, runtime: Runtime) {
		for (const [name, step] of this._playerTickSteps()) {
			debug.profilebegin("PlayerTick." + name);
			step(player, runtime);
			debug.profileend();
		}
	}

	_playerTickMaintenance(player: Player, runtime: Runtime) {
		if ((runtime.MaintenanceAccumulator as number) >= PROFILE_MAINTENANCE_INTERVAL && !truthy(this._data.IsBusy(player))) {
			runtime.MaintenanceAccumulator = (runtime.MaintenanceAccumulator as number) % PROFILE_MAINTENANCE_INTERVAL;
			let changed = false;
			const committed = this._data.AtomicUpdate(
				player,
				(profile: Profile) => {
					changed = truthy(K.ProgressionService.EnsureQuests(profile, player.UserId)) || changed;
					changed = truthy(K.ProgressionService.EnsureTimedRewards(profile)) || changed;
					changed = truthy(K.ProgressionService.EnsureCommandRotations(profile)) || changed;
					changed = truthy(ensureItemShop(profile)) || changed;
					changed = truthy(K.AnomalyService.Ensure(profile)) || changed;
					changed = truthy(K.LabService.Ensure(profile, player.UserId)) || changed;
					changed = WeeklyBoard.ensure(profile, os.time()) || changed;
					changed = this._settleEventTokens(player, runtime, profile) || changed;
					changed = this._settleCompanionBond(player, runtime, profile) || changed;
					if (!truthy(this._antiCheat.Observe(player, "Maintenance", profile))) {
						changed = true;
					}
					if (!changed) {
						return { ok: false, noop: true };
					}
					return { ok: true };
				},
				true,
				"maintenance",
			);
			if (truthy(committed) && changed) {
				this._queueStatePush(player);
			}
			this._payWeeklyBoard(player);
		}
	}

	_playerTickGuildRefresh(player: Player, runtime: Runtime) {
		if ((runtime.GuildRefreshAccumulator as number) >= GUILD_REFRESH_INTERVAL) {
			runtime.GuildRefreshAccumulator = (runtime.GuildRefreshAccumulator as number) % GUILD_REFRESH_INTERVAL;
			this._queueGuildMembershipRefresh(player, runtime);
		}
	}

	_playerTickProduction(player: Player, runtime: Runtime) {
		if ((runtime.ProductionAccumulator as number) >= (K.GameConfig.Game.ProductionTick as number)) {
			const step = runtime.ProductionAccumulator as number;
			const pendingAnomalyActions = (runtime.PendingAnomalyActions as ReadonlyArray<string> | undefined) ?? NO_PENDING_ACTIONS;
			const pendingAnomalyCount = pendingAnomalyActions.size();
			let anomalyDetails: Dict | undefined;

			if (truthy(this._data.IsBusy(player))) {
				const maxCatchUp = (K.GameConfig.Game.ProductionTick as number) * 4;
				if ((runtime.ProductionAccumulator as number) > maxCatchUp) {
					runtime.ProductionAccumulator = maxCatchUp;
				}
			} else {
				runtime.ProductionAccumulator = 0;
				const ok = this._data.AtomicUpdate(
					player,
					(profile: Profile) => {
						const now = os.time();
						const active = ensureActiveBoost(profile) as Dict;
						if ((active.EndsAt as number) > 0 && (active.EndsAt as number) <= now) {
							profile.ActiveBoost = { Id: "", EndsAt: 0 };
						}
						const production = K.Economy.Mul(
							K.Economy.Production(profile, now),
							(this._convergence.Multiplier() as number) *
								(this._fluxSurge!.Multiplier(now) as number) *
								(this._events.ProductionMultiplier() as number) *
								(this._crews.Multiplier(player) as number),
						);
						const capacity = K.Economy.Capacity(profile, now);
						const produced = K.Economy.Mul(production, step);
						profile.Vault = K.Economy.Min(capacity, K.Economy.Add(profile.Vault, produced));

						const autoRate = K.Economy.AutoCollectRate(profile) as number;
						if (autoRate > 0 && truthy(K.Economy.Gt(profile.Vault, 0))) {
							const fromVault = K.Economy.Mul(profile.Vault, autoRate * step);
							const fromProd = K.Economy.Mul(produced, autoRate);
							const collected = K.Economy.Min(profile.Vault, K.Economy.Max(fromVault, fromProd));
							if (truthy(K.Economy.Gt(collected, 0))) {
								profile.Vault = K.Economy.Sub(profile.Vault, collected);
								profile.Cash = K.Economy.Add(profile.Cash, collected);
								profile.RunCash = K.Economy.Add(profile.RunCash, collected);
								profile.LifetimeCash = K.Economy.Add(profile.LifetimeCash, collected);
								const stats = ensureStats(profile) as Dict;
								stats.Collected = K.Economy.Add(stats.Collected, collected);
								K.ProgressionService.Progress(profile, "EarnCash", K.Economy.AsNumber(collected));
								K.LabService.Progress(profile, "BankFlux", K.Economy.AsNumber(collected));
							}
						}
						bumpStat(profile, "PlayTime", step);
						K.ProgressionService.EnsureTimedRewards(profile);
						const timedRewards = profile.TimedRewards as Dict;
						timedRewards.PlaySeconds = (timedRewards.PlaySeconds as number) + step;
						if (pendingAnomalyCount > 0) {
							let totalAmount = 0;
							let becameReady = false;
							for (let index = 0; index < pendingAnomalyCount; index++) {
								const pendingAction = pendingAnomalyActions[index];
								const [amount, ready] = K.AnomalyService.Progress(
									profile,
									(anomalyChargeByAction[pendingAction] as number | undefined) ?? 0,
								) as LuaTuple<[number, unknown]>;
								totalAmount += amount;
								becameReady = becameReady || truthy(ready);
								const signal = anomalySignalByAction[pendingAction];
								if (truthy(signal)) {
									K.AnomalyService.Signal(profile, signal, 1);
								}
							}
							anomalyDetails = {
								Amount: totalAmount,
								BecameReady: becameReady,
								Charge: (profile.Anomaly as Dict).Charge,
							};
						}
						enforceUnlimitedMoney(profile);
						// the tick just capped Vault at this capacity; pass it so the check skips a second Capacity pass
						this._antiCheat.Observe(player, "Production", profile, capacity);
					},
					false,
					"production",
				);
				if (!truthy(ok)) {
					runtime.ProductionAccumulator = (runtime.ProductionAccumulator as number) + step;
				} else if (pendingAnomalyCount > 0) {
					// Drain only the actions we processed; any appended during the tick
					// remain queued for the next production tick.
					const currentPending = (runtime.PendingAnomalyActions as string[] | undefined) ?? [];
					const remaining: string[] = [];
					for (let i = pendingAnomalyCount; i < currentPending.size(); i++) {
						remaining.push(currentPending[i]);
					}
					runtime.PendingAnomalyActions = remaining;
					this._queueStatePush(player);
					if (anomalyDetails !== undefined && truthy(anomalyDetails.BecameReady)) {
						this._effect.fire(player, {
							Type: "AnomalyReady",
							Amount: anomalyDetails.Amount,
							Charge: anomalyDetails.Charge,
						});
						this._toastPlayer(player, T("Toast.ReactorReadyTitle"), T("Toast.ReactorReadyBody"), "Special");
					}
				}
			}
		}
	}

	_playerTickAutomation(player: Player, runtime: Runtime) {
		if ((runtime.AutoForgeAccumulator as number) >= AUTO_FORGE_INTERVAL) {
			runtime.AutoForgeAccumulator = (runtime.AutoForgeAccumulator as number) % AUTO_FORGE_INTERVAL;
			this._tickAutoForge(player);
			this._tickForgePrograms(player, runtime);
		}
	}

	_playerTickDirty(player: Player, runtime: Runtime) {
		if ((runtime.DirtyAccumulator as number) >= 5) {
			runtime.DirtyAccumulator = 0;
			this._data.MarkDirty(player);
		}
	}

	_playerTickStatePush(player: Player, runtime: Runtime) {
		if ((runtime.PushAccumulator as number) >= (K.GameConfig.Game.StatePushSeconds as number)) {
			runtime.PushAccumulator = 0;
			const profile = this._data.Get(player) as Profile | undefined;
			if (profile !== undefined) {
				this._syncLeaderstats(player, profile);
				this._pushState(player);
			}
		}
	}

	_tickPlayer(player: Player, runtime: Runtime, deltaTime: number) {
		if (player.Parent !== Players) {
			return;
		}
		runtime.ProductionAccumulator = (runtime.ProductionAccumulator as number) + deltaTime;
		runtime.AutoForgeAccumulator = ((runtime.AutoForgeAccumulator as number | undefined) ?? 0) + deltaTime;
		runtime.PushAccumulator = (runtime.PushAccumulator as number) + deltaTime;
		runtime.DirtyAccumulator = (runtime.DirtyAccumulator as number) + deltaTime;
		runtime.MaintenanceAccumulator = ((runtime.MaintenanceAccumulator as number | undefined) ?? 0) + deltaTime;
		runtime.GuildRefreshAccumulator = ((runtime.GuildRefreshAccumulator as number | undefined) ?? 0) + deltaTime;

		const hasWork =
			(runtime.ProductionAccumulator as number) >= (K.GameConfig.Game.ProductionTick as number) ||
			(runtime.AutoForgeAccumulator as number) >= AUTO_FORGE_INTERVAL ||
			(runtime.DirtyAccumulator as number) >= 5 ||
			(runtime.PushAccumulator as number) >= (K.GameConfig.Game.StatePushSeconds as number) ||
			(runtime.MaintenanceAccumulator as number) >= PROFILE_MAINTENANCE_INTERVAL ||
			(runtime.GuildRefreshAccumulator as number) >= GUILD_REFRESH_INTERVAL;
		if (!hasWork) {
			return;
		}
		if (truthy(runtime.MatterWorkQueued)) {
			// watchdog: a tick worker that has not finished after 15s is released so production
			// resumes (checked here on the 5 Hz tick instead of a timer thread per work item)
			if (os.clock() - ((runtime.MatterWorkStartedAt as number | undefined) ?? math.huge) < 15) {
				return;
			}
			runtime.MatterWorkQueued = false;
			K.ModuleLog.Warn("game loop", string.format("player tick watchdog released %s after 15s", player.Name), {
				UserId: player.UserId,
			});
			return;
		}

		runtime.MatterWorkQueued = true;
		runtime.MatterWorkStartedAt = os.clock();
		const workToken = ((runtime.MatterWorkToken as number | undefined) ?? 0) + 1;
		runtime.MatterWorkToken = workToken;
		this._spawnWorker(() => {
			if (!this._running || player.Parent !== Players || this._runtime.get(player) !== runtime) {
				runtime.MatterWorkQueued = false;
				return;
			}
			const [ok, problem] = pcall(() => this._processPlayerTick(player, runtime));
			if (runtime.MatterWorkToken === workToken) {
				runtime.MatterWorkQueued = false;
			}
			if (!ok) {
				K.ModuleLog.Every(
					"matter-player-work:" + tostring(player.UserId),
					5,
					"game loop",
					string.format("deferred production failed for %s: %s", player.Name, tostring(problem)),
				);
			}
		});
	}

	_tick(deltaTime: number) {
		this._fluxSurge!.Tick(deltaTime);
		this._events.Step(deltaTime);

		this._rankPingAccumulator += deltaTime;
		if (this._rankPingAccumulator >= RANK_PING.INTERVAL) {
			this._rankPingAccumulator = 0;
			if (!this._rankPingBusy && Players.GetPlayers().size() > 0) {
				this._rankPingBusy = true;
				const worker = this._spawnWorker(() => {
					pcall(() => {
						this._getLeaderboard(RANK_PING.BOARD);
					});
					this._rankPingBusy = false;
				});
				if (!truthy(worker)) {
					this._rankPingBusy = false;
				}
			}
		}

		this._matterAccumulator += deltaTime;
		if (this._matterAccumulator < 0.2) {
			return;
		}
		this._matterAccumulator = 0;
		this._matter.Step();
	}

	Start() {
		if (this._running) {
			return;
		}
		this._running = true;
		// Boot steps (todo500 #5), in the original order.
		this._bootLiveOps();
		this._bootPurchases();
		this._bootRemotes();
		this._bootPlayers();
		this._bootTicks();
	}

	_bootLiveOps() {
		this._convergence.Start();
		PolicyGate.Start();
	}

	_bootPurchases() {
		MarketplaceService.PromptGamePassPurchaseFinished.Connect((player, passId, purchased) => {
			const [ok, err] = pcall(() => this._grantPurchasedPass(player, passId, purchased));
			if (!ok) {
				K.ModuleLog.Warn("Shop", "pass grant errored: " + tostring(err));
			}
		});
		MarketplaceService.ProcessReceipt = (receiptInfo) => {
			const [ok, decision] = pcall(() => this._processReceipt(receiptInfo));
			if (ok) {
				return decision;
			}
			K.ModuleLog.Warn("Shop", "ProcessReceipt errored: " + tostring(decision));
			return Enum.ProductPurchaseDecision.NotProcessedYet;
		};
	}

	_bootRemotes() {
		this._matter.Start(this);
		this._world.SetInteractionHandler((player: Player, action: string, payload: unknown) => {
			if (action === "Collect") {
				this._collect(player);
			} else if (action === "BuyMachine") {
				this._buyMachine(player, payload);
			} else if (action === "Zone") {
				const profile = this._data.Get(player) as Profile | undefined;
				if (profile !== undefined && (payload as number) <= (profile.Zone as number)) {
					this._selectZone(player, payload);
				} else {
					this._unlockZone(player, payload);
				}
			}
			this._pushState(player);
		});

		ServerFunctions.request.setCallback((player: Player, action: string, payload?: unknown) => {
			const requestStartedAt = os.clock();

			if (
				player.GetAttribute("AstralForgeLoaded") !== true &&
				action !== K.Protocol.Actions.MeasureLatency &&
				action !== K.Protocol.Actions.ReportClientIntegrity &&
				action !== K.Protocol.Actions.ReportPerformance &&
				action !== K.Protocol.Actions.ReportPresence
			) {
				return responseError(T("GameService.ProfileIsStillLoading"));
			}
			if (truthy(this._security)) {
				const [authorityOk, authorityMessage] = (this._security.Authority as Svc).Validate(player, action, payload) as LuaTuple<
					[unknown, unknown]
				>;
				if (!truthy(authorityOk)) {
					K.ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d authority %s %s", player.UserId, tostring(action), tostring(authorityMessage)),
					);
					return responseError(truthy(authorityMessage) ? authorityMessage : T("GameService.RequestRejected"));
				}

				if (!truthy((this._security.Rate as Svc).Allow(player, action === K.Protocol.Actions.AdminExecute ? 1 : 0.1))) {
					K.ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d rate %s", player.UserId, tostring(action)),
					);
					return responseError(T("RemoteFirewall.PleaseSlowDownForA"));
				}
			}
			const [allowed, firewallMessage] = this._firewall.Check(player, action, payload) as LuaTuple<[unknown, unknown]>;
			if (!truthy(allowed)) {
				if (action !== K.Protocol.Actions.ReportPresence && action !== K.Protocol.Actions.ReportPerformance) {
					K.ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d firewall %s %s", player.UserId, tostring(action), tostring(firewallMessage)),
					);
				}
				return responseError(truthy(firewallMessage) ? firewallMessage : T("RemoteFirewall.PleaseSlowDownForA"));
			}
			const readOnly = truthy(K.CommandActionValidators.IsReadOnly(action));
			const payloadTable = typeIs(payload, "table") ? (payload as Dict) : undefined;
			if (!readOnly) {
				const [grantOk, grantReason] = this._session.CheckGrant(
					player,
					payloadTable !== undefined ? payloadTable.Gen : undefined,
					payloadTable !== undefined ? payloadTable.N : undefined,
					K.CommandActionValidators.RequiresHighValueNonce(action),
				) as LuaTuple<[unknown, unknown]>;
				if (!truthy(grantOk)) {
					K.ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d drop %s %s", player.UserId, tostring(action), tostring(grantReason)),
					);
					const [liveGen, liveNonce] = this._session.Peek(player) as LuaTuple<[unknown, unknown]>;
					return {
						ok: false,
						error: T("GameService.YourSessionNeedsToRefresh"),
						Gen: liveGen,
						N: liveNonce,
						Auth: grantReason === "unauth" ? false : undefined,
					} as Response;
				}
			}
			const txnId = payloadTable !== undefined && typeIs(payloadTable.TxnId, "string") ? payloadTable.TxnId : undefined;
			let txnClaimed = false;
			if (txnId !== undefined) {
				if (txnId.size() > 64) {
					Report(player, "txn-id", 2, "TxnId of " + txnId.size() + " chars");
					return responseError(T("RemoteFirewall.ThatRequestCouldNotBe"));
				}
				const [status, storedResult] = this._session.TxnClaim(
					player,
					txnId,
					tostring(action) + "|" + PayloadShape.Fingerprint(payload, TXN_PRINT_IGNORE),
				) as LuaTuple<[unknown, unknown]>;
				if (status === "mismatch") {
					Report(player, "txn-replay", 3, string.format("%s reused a TxnId from a different request", tostring(action)));
					return responseError(T("RemoteFirewall.ThatRequestCouldNotBe"));
				}
				if (status === "done") {
					return storedResult as Response;
				}
				if (status === "busy") {
					return responseError(T("GameService.StillWorkingOnThat"));
				}
				txnClaimed = true;
			}
			const [success, result] = pcall(() => this._handleAction(player, action, payload));
			if (!success) {
				if (txnClaimed && txnId !== undefined) {
					this._session.TxnRelease(player, txnId);
				}
				K.ModuleLog.Every(
					string.format("action:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d could not run %s: %s", player.UserId, tostring(action), tostring(result)),
				);
				return responseError(T("GameService.TheForgeEncounteredAnError"));
			}
			const resultBag = result as Dict;
			if (!typeIs(resultBag, "table") || !typeIs(resultBag.ok, "boolean")) {
				if (txnClaimed && txnId !== undefined) {
					this._session.TxnRelease(player, txnId);
				}
				K.ModuleLog.Every(
					string.format("action-contract:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d got an invalid response for %s", player.UserId, tostring(action)),
				);
				return responseError(T("GameService.TheForgeReturnedAnInvalid"));
			}
			if (txnClaimed && txnId !== undefined) {
				if (resultBag.ok === true) {
					this._session.TxnStore(player, txnId, resultBag);
				} else {
					this._session.TxnRelease(player, txnId);
				}
			}
			if (resultBag.ok === false) {
				this._flagFailedRequest(player, action as string);
			}
			if (resultBag.ok === false && action !== K.Protocol.Actions.ReportPresence && action !== K.Protocol.Actions.ReportPerformance) {
				K.ModuleLog.Every(
					string.format("result:%d:%s", player.UserId, tostring(action)),
					10,
					"Action",
					string.format("u=%d %s failed: %s", player.UserId, tostring(action), tostring(resultBag.error)),
				);
			}
			if (resultBag.ok === true && !readOnly) {
				this._spawnWorker(() => {
					if (player.Parent !== Players) {
						return;
					}
					this._progressAnomalyFromAction(player, action as string);
					const profile = this._data.Get(player) as Profile | undefined;
					if (profile !== undefined) {
						this._convergence.RecordAction(player, tostring(action));
						this._queueEventPoints(player, tostring(action));
						CompanionBonds.Record(this._runtime.get(player), tostring(action));
						if (action === K.Protocol.Actions.CollectVault) {
							this._crews.RecordCollect(player);
						}
						this._analytics.RecordAction(player, tostring(action), profile, (os.clock() - requestStartedAt) * 1000);
						this._badges.Evaluate(player, profile, tostring(action));
					}
					this._syncLeaderstats(player, profile);
					if (!truthy(K.CommandActionValidators.IsDeferredSnapshot(action))) {
						this._queueStatePush(player);
					}
				});
			}
			if (!readOnly && resultBag.Gen === undefined) {
				const [gen, nonce] = this._session.Peek(player) as LuaTuple<[unknown, unknown]>;
				resultBag.Gen = gen;
				resultBag.N = nonce;
			}
			return resultBag;
		});
	}

	_bootPlayers() {
		this._playerAddedConnection = Players.PlayerAdded.Connect((player) => {
			this._spawnWorker(() => {
				this._safePlayerAdded(player);
			});
		});
		this._playerRemovingConnection = Players.PlayerRemoving.Connect((player) => {
			this._onPlayerRemoving(player);
			this._queueSocialBoostRefresh();
		});
		for (const player of Players.GetPlayers()) {
			this._spawnWorker(() => {
				this._safePlayerAdded(player);
			});
		}
	}

	_bootTicks() {
		this._heartbeat = RunService.Heartbeat.Connect((deltaTime) => {
			if (!this._running) {
				return;
			}
			this._tick(deltaTime);
		});
	}

	GrantStudioMoney(player: Player): LuaTuple<[boolean, string, unknown]> {
		if (!truthy(K.ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return $tuple(false, T("GameService.StudioGrantsAreDisabledIn"), undefined);
		}
		if (player.Parent !== Players) {
			return $tuple(false, T("GameService.ThatPlayerIsNotIn"), undefined);
		}
		if (this._data.Get(player) === undefined) {
			return $tuple(false, T("GameService.ThePlayerSProfileIs"), undefined);
		}

		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			(profile.Flags as Dict).UnlimitedMoney = true;
			enforceUnlimitedMoney(profile);
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, T("GameService.ProfileUpdateFailedS", tostring(updateError)), undefined);
		}

		this._syncLeaderstats(player, this._data.Get(player) as Profile | undefined);
		this._pushState(player);
		this._toastPlayer(player, T("Toast.UnlimitedFluxTitle"), T("Toast.UnlimitedFluxBody"), "Success");
		if (!truthy(this._data.Save(player, false))) {
			return $tuple(false, T("GameService.TheBalanceChangedInSession"), undefined);
		}
		return $tuple(true, T("GameService.UnlimitedFluxLockEnabledAnd"), MAX_SAFE_CURRENCY);
	}

	GrantStudioWheelSpins(player: Player, amount: unknown): LuaTuple<[boolean, string, unknown]> {
		if (!truthy(K.ShopGrantEligibility.StudioGrantAllowed(RunService.IsStudio()))) {
			return $tuple(false, T("GameService.StudioGrantsAreDisabledIn"), undefined);
		}
		if (player.Parent !== Players) {
			return $tuple(false, T("GameService.ThatPlayerIsNotIn"), undefined);
		}
		if (this._data.Get(player) === undefined) {
			return $tuple(false, T("GameService.ThePlayerSProfileIs"), undefined);
		}

		const grant = K.ShopGrantEligibility.ClampWheelGrant(amount) as number;
		let total = 0;
		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			const wheel = profile.Wheel as Dict;
			const current = math.max(0, math.floor(tonumber(wheel.FreeSpins) ?? 0));
			total = current + grant;
			wheel.FreeSpins = total;
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, T("GameService.ProfileUpdateFailedS", tostring(updateError)), undefined);
		}

		this._pushState(player);
		this._toastPlayer(player, T("Toast.FreeSpinsTitle"), T("Toast.FreeSpinsBody", tostring(grant), tostring(total)), "Success");
		return $tuple(true, T("GameService.GrantedSFreeWheelSpins", tostring(grant), tostring(total)), total);
	}

	ShowRelease(player: Player): LuaTuple<[boolean, string]> {
		if (player.Parent !== Players) {
			return $tuple(false, T("GameService.ThatPlayerIsNotIn"));
		}
		const [updated, updateError] = this._data.Update(player, (profile: Profile) => {
			(profile.Flags as Dict).LastSeenVersion = "";
		}) as LuaTuple<[unknown, unknown]>;
		if (!truthy(updated)) {
			return $tuple(false, T("GameService.ProfileUpdateFailedS", tostring(updateError)));
		}
		this._pushState(player);
		return $tuple(true, T("GameService.ReleaseNotesReopenedForS", player.Name));
	}

	Shutdown() {
		this._running = false;
		this._joining = new Map();
		this._socialBoostDirty = false;
		this._socialBoostScheduled = false;
		if (this._socialBoostWorker !== undefined) {
			task.cancel(this._socialBoostWorker);
			this._socialBoostWorker = undefined;
		}
		if (this._playerAddedConnection !== undefined) {
			this._playerAddedConnection.Disconnect();
			this._playerAddedConnection = undefined;
		}
		if (this._playerRemovingConnection !== undefined) {
			this._playerRemovingConnection.Disconnect();
			this._playerRemovingConnection = undefined;
		}
		for (const [player, connection] of this._characterConnections) {
			connection.Disconnect();
			this._characterConnections.delete(player);
		}
		this._joining.clear();
		if (this._admin !== undefined) {
			this._admin.Destroy();
		}

		ServerFunctions.request.setCallback(() => responseError(T("GameService.TheServerIsShuttingDown")));
		for (const [player, pending] of this._queuedStatePushes) {
			task.cancel(pending);
			this._queuedStatePushes.delete(player);
		}
		for (const [token, worker] of this._backgroundWorkers) {
			pcall(() => task.cancel(worker));
			this._backgroundWorkers.delete(token);
		}
		if (this._heartbeat !== undefined) {
			this._heartbeat.Disconnect();
			this._heartbeat = undefined;
		}
		this._matter.Stop();
		this._convergence.Stop();
		this._guilds.Destroy();
		this._guildCommunity.Shutdown();
		this._chat.Shutdown();
		this._crews.Shutdown();
		this._badges.Destroy();
	}
}
