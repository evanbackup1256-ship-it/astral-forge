import type { RequestFunction } from "../ClientNetwork";
import { ClientLog } from "./log";

const HttpService = game.GetService("HttpService");
const RunService = game.GetService("RunService");

const BEAT_INTERVAL_MIN = 8;
const BEAT_INTERVAL_MAX = 12;

// prettier-ignore
export const GRANT_ACTIONS: Record<string, true> = {
	CollectVault: true, Overcharge: true, BuyMachine: true, BuyResearch: true, BuyGridUpgrade: true,
	UnlockZone: true, SelectZone: true, Rebirth: true, DomainExpansion: true, DomainLattice: true,
	EventAct: true, UpgradeContinuum: true, FoundryAct: true, Ascend: true, UpgradeSigil: true,
	EchoAct: true, RebirthAct: true, TradeChat: true, TradeRequest: true, ClaimQuest: true,
	ClaimAchievement: true, ClaimDaily: true, ClaimTimedReward: true, ClaimCommunityReward: true, SpinWheel: true, BazaarPlay: true,
	SetMarketFavorite: true, RequestProcurement: true, SelectSpecialization: true, LaunchExpedition: true,
	ClaimExpedition: true, EquipArtifact: true, UpgradeArtifact: true, BuyArtifact: true, UpgradeCrew: true,
	ClaimCommanderReward: true, ClaimWeeklyDirective: true, ClaimSeasonTier: true, ClaimForgePathStep: true,
	BuySignalOffer: true, RedeemCode: true, VerifyCreatorFollow: true, StudioGrantProduct: true,
	ActivateBoost: true, BuyItemOffer: true, OpenItemCrate: true, EquipItem: true, UnequipItem: true,
	UpgradeItem: true, SalvageItem: true, BulkSalvageItems: true, EquipBestItems: true,
	ClaimStoryChapter: true, ClaimMail: true, ClaimAllMail: true, PulseAnomaly: true, StabilizeAnomaly: true,
	BuyAnomalyProtocol: true, ActivateAnomalySurge: true, ClaimAnomalyMilestone: true,
	ClaimAnomalyDirective: true, ClaimLabOrder: true, RouteLabPower: true, CreateGuild: true, JoinGuild: true,
	LeaveGuild: true, DisbandGuild: true, KickGuildMember: true, SetGuildRole: true, RenameGuild: true,
	ContributeGuild: true, BuyGuildUpgrade: true, ClaimGuildGoal: true, SendGuildChat: true,
	SetGuildSettings: true, CreateGuildAnnouncement: true, EditGuildAnnouncement: true,
	PinGuildAnnouncement: true, ArchiveGuildAnnouncement: true, SetGuildAnnouncementExpiry: true,
	MuteGuildMember: true, UnmuteGuildMember: true, BanGuildMember: true, UnbanGuildMember: true,
	UploadGuildLogo: true, ModerateGuildLogo: true, AdminExecute: true, ClaimConvergenceReward: true,
	ConfirmTrade: true, UpdateTradeOffer: true, InviteTrade: true, RespondTrade: true, SetTradeReady: true,
	CancelTrade: true, ClaimFirstGoal: true, CompleteTutorial: true, DeleteMail: true, MarkHintSeen: true, DismissRelease: true, EquipTitle: true, SetProfileStyle: true,
	OpenRelease: true, ReadMail: true, ReadStoryChapter: true, SetAnomalyChannel: true,
	SetAnomalyLoadout: true, SetAutoForge: true, SetItemAutoSalvage: true, SetMobileLayout: true,
	SetSetting: true, SyncShop: true, ToggleItemLock: true, BuyDailyOffer: true, BuyCrateSkin: true,
	EquipCrateSkin: true, FuseRelics: true,
};

export interface GrantPayload {
	Gen?: number;
	N?: string;
	TxnId?: unknown;
	[key: string]: unknown;
}

export interface SessionResponse {
	ok?: boolean;
	error?: unknown;
	Gen?: number;
	N?: string;
	Auth?: boolean;
}

let gen = 0;
let nonce = "";
let auth = RunService.IsStudio();
let helloDone = false;
let nextBeatId = 1;
let stopped = true;
let presencePage = "Overview";
let lastPresenceAt = -1e9;
const authWaiters = new Array<() => void>();
const PRESENCE_TIMEOUT_SECONDS = 5;
const MAX_PRESENCE_IN_FLIGHT = 2;
let presenceSerial = 0;
let presenceInFlight = 0;
let sessionToken = 0;

export function setPresencePage(page: string) {
	presencePage = page;
}

function flushAuthWaiters() {
	if (!auth) {
		return;
	}
	const queued = [...authWaiters];
	authWaiters.clear();
	for (const waiter of queued) {
		waiter();
	}
}

export function whenAuthed(run: () => void) {
	if (auth) {
		run();
		return;
	}
	authWaiters.push(run);
}

export function isAuthed(): boolean {
	return auth;
}

export function makeTxnId(): string {
	return HttpService.GenerateGUID(false).sub(1, 40);
}

export function attachGrantFields<T extends GrantPayload>(payload: T): T {
	payload.Gen = gen;
	payload.N = nonce;
	if (!typeIs(payload.TxnId, "string") || payload.TxnId === "") {
		payload.TxnId = makeTxnId();
	}
	return payload;
}

export function adopt(response: SessionResponse) {
	if (response.Gen === undefined || response.Gen < gen) {
		return;
	}
	if (response.N === undefined) {
		return;
	}
	gen = response.Gen;
	nonce = response.N;
	if (response.Auth !== undefined) {
		auth = response.Auth;
	}
}

export function startSession(remotes: { Request: RequestFunction }) {
	stopped = false;
	helloDone = false;
	lastPresenceAt = -1e9;
	sessionToken += 1;
	const token = sessionToken;
	let worker: thread | undefined;
	const beatOnce = (force: boolean): "ok" | "retry" | undefined => {
		const now = os.clock();
		if (!force && now - lastPresenceAt < 1.7) {
			return undefined;
		}
		if (presenceInFlight >= MAX_PRESENCE_IN_FLIGHT) {
			return "retry";
		}
		lastPresenceAt = now;
		const payload: { Page: string; Gen?: number; Id?: number; N?: string } = { Page: presencePage };
		if (helloDone) {
			payload.Gen = gen;
			payload.Id = nextBeatId;
			payload.N = nonce;
			nextBeatId += 1;
		}
		presenceSerial += 1;
		const serial = presenceSerial;
		presenceInFlight += 1;
		let finished = false;
		let ok = false;
		let raw: unknown = undefined;
		task.spawn(() => {
			const [callOk, callRaw] = pcall(() => remotes.Request.invoke("ReportPresence", payload).expect());
			presenceInFlight = math.max(0, presenceInFlight - 1);
			if (serial !== presenceSerial || token !== sessionToken || stopped) {
				return;
			}
			ok = callOk;
			raw = callRaw;
			finished = true;
		});
		const started = os.clock();
		while (!finished && !stopped && token === sessionToken && os.clock() - started < PRESENCE_TIMEOUT_SECONDS) {
			task.wait(0.05);
		}
		if (stopped || token !== sessionToken) {
			return undefined;
		}
		if (!finished) {
			presenceSerial += 1;
			lastPresenceAt = -1e9;
			ClientLog.warnEvery("presence-beat", 15, "auth", "presence beat timed out");
			return "retry";
		}
		if (!ok || !typeIs(raw, "table")) {
			lastPresenceAt = -1e9;
			ClientLog.warnEvery("presence-beat", 15, "auth", ok ? "presence beat returned no session" : tostring(raw));
			return "retry";
		}
		const response = raw as SessionResponse;
		if (response.ok !== true) {
			lastPresenceAt = -1e9;
			ClientLog.warnEvery("presence-reject", 15, "auth", tostring(response.error ?? "presence rejected"));
			return "retry";
		}
		const wasAuthed = auth;
		adopt(response);
		if (!helloDone) {
			helloDone = true;
			ClientLog.debug("auth", `hello ok gen=${gen}`);
		} else if (!wasAuthed && auth) {
			ClientLog.debug("auth", `beat ok gen=${gen}`);
		}
		if (auth) {
			flushAuthWaiters();
		}
		return "ok";
	};
	worker = task.spawn(() => {
		let outcome = beatOnce(true);
		if (!stopped) {
			outcome = beatOnce(true);
		}
		while (!stopped && token === sessionToken) {
			const retrySoon = outcome === "retry" || !auth;
			const interval = retrySoon ? 2 : BEAT_INTERVAL_MIN + math.random() * (BEAT_INTERVAL_MAX - BEAT_INTERVAL_MIN);
			task.wait(interval);
			if (stopped || token !== sessionToken) {
				break;
			}
			outcome = beatOnce(false);
		}
	});
	return () => {
		// a cleanup from an earlier session must not stop the one that replaced it
		if (token === sessionToken) {
			stopped = true;
		}
		if (worker !== undefined) {
			const running = worker;
			pcall(() => task.cancel(running));
			worker = undefined;
		}
	};
}
