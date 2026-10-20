export const DEFAULT_COOLDOWN = 0.1;
export const DEFAULT_TIMEOUT = 15;
export const MAX_PHYSICAL_REQUESTS = 12;
export const PIPELINE_REQUEST_LIMIT = 4;
export const SERIAL_REQUEST_LIMIT = 2;

// prettier-ignore
export const ACTION_COOLDOWNS: Record<string, number> = {
	GetState: 0.24, GetPlayers: 0.28, GetPlayerMirror: 0.28, VisitPlot: 0.52, LeavePlot: 0.35,
	NudgeCrew: 2.7, ReportPresence: 1.6, CollectVault: 0.04, Overcharge: 0.05, PulseAnomaly: 0.05,
	SpinWheel: 1.4, BazaarPlay: 0.35, OpenItemCrate: 0.24, BuyDailyOffer: 0.4, BuyCrateSkin: 0.55,
	EquipCrateSkin: 0.3, FuseRelics: 0.4, UpgradeContinuum: 0.4, FoundryAct: 0.06, EchoAct: 0.15,
	RebirthAct: 0.2, SetAutoForge: 0.28, SetItemAutoSalvage: 0.2, BulkSalvageItems: 0.35, SetSetting: 0.18,
	SetMobileLayout: 0.35, SetTutorialStep: 0.18, MarkHintSeen: 0.2, ClaimLabOrder: 0.18, RouteLabPower: 0.12,
	ReadStoryChapter: 0.18, ClaimStoryChapter: 0.18, ReadMail: 0.18, ClaimMail: 0.18, ClaimAllMail: 0.75,
	DeleteMail: 0.18, RedeemCode: 1.5, SyncShop: 1.3, StudioGrantProduct: 0.45, GetTrade: 0.2,
	InviteTrade: 0.7, RespondTrade: 0.28, UpdateTradeOffer: 0.08, SetTradeReady: 0.12, ConfirmTrade: 0.28,
	CancelTrade: 0.2, TradeViewAway: 0.2, DomainExpansion: 5.2, ClaimConvergenceReward: 0.45,
	GetLeaderboard: 1.1, GetGuildLeaderboard: 1.1, GetAdminState: 0.9, ReportClientIntegrity: 30.5,
	AdminExecute: 0.9, CreateGuild: 2.1, JoinGuild: 1.1, GetGuild: 0.32, SendGuildChat: 0.45,
	ChatOpenWhisper: 0.4, ChatGlobal: 0.8, GetGuildChatHistory: 0.25, GetGuildAnnouncements: 0.3,
	GetGuildSettings: 0.6, GetGuildLogoReview: 1.1, SetGuildSettings: 1.1, CreateGuildAnnouncement: 2.1,
	EditGuildAnnouncement: 0.6, PinGuildAnnouncement: 0.6, ArchiveGuildAnnouncement: 0.6,
	SetGuildAnnouncementExpiry: 0.6, MuteGuildMember: 0.7, UnmuteGuildMember: 0.7, BanGuildMember: 1.1,
	UnbanGuildMember: 0.7, UploadGuildLogo: 0.6, ModerateGuildLogo: 1.1, KickGuildMember: 0.6,
	SetGuildRole: 0.6, RenameGuild: 2.1, ContributeGuild: 0.45, BuyGuildUpgrade: 0.8, LeaveGuild: 1.1,
};

// prettier-ignore
export const REQUEST_TIMEOUTS: Record<string, number> = {
	GetState: 8, GetPlayers: 8, GetPlayerMirror: 8, GetGuild: 8, GetGuildChatHistory: 8,
	GetGuildAnnouncements: 8, GetGuildSettings: 8, GetGuildLogoReview: 8, GetGuildLeaderboard: 8,
	GetLeaderboard: 8, GetAdminState: 8,
};

// prettier-ignore
export const PIPELINED_ACTIONS: Record<string, true> = {
	Overcharge: true, PulseAnomaly: true, CollectVault: true, RouteLabPower: true, SetAutoForge: true,
	SetAnomalyChannel: true, SetSetting: true, SetMobileLayout: true, SetTutorialStep: true, MarkHintSeen: true,
	ReplayTutorial: true, DismissRelease: true, OpenRelease: true, ReadStoryChapter: true, ReadMail: true,
	SelectZone: true, UpdateTradeOffer: true, SetTradeReady: true, ConfirmTrade: true, CancelTrade: true,
	RespondTrade: true, TradeViewAway: true, SetItemAutoSalvage: true, ReportPresence: true,
};

// prettier-ignore
export const OPTIMISTIC_ACTIONS: Record<string, true> = {
	CollectVault: true, Overcharge: true, RouteLabPower: true, SetAutoForge: true, SetAnomalyChannel: true,
	SetSetting: true, SetMobileLayout: true, SetTutorialStep: true, MarkHintSeen: true, CompleteTutorial: true,
	ReplayTutorial: true, DismissRelease: true, OpenRelease: true, ReadStoryChapter: true, ReadMail: true,
	SelectZone: true, EquipTitle: true, ReportPresence: true,
};

export function Cooldown(action: unknown): number {
	if (!typeIs(action, "string")) {
		return DEFAULT_COOLDOWN;
	}
	const value = ACTION_COOLDOWNS[action];
	return typeIs(value, "number") ? value : DEFAULT_COOLDOWN;
}

export function Timeout(action: unknown): number {
	if (!typeIs(action, "string")) {
		return DEFAULT_TIMEOUT;
	}
	const value = REQUEST_TIMEOUTS[action];
	return typeIs(value, "number") ? value : DEFAULT_TIMEOUT;
}

export function IsPipelined(action: unknown): boolean {
	return typeIs(action, "string") && PIPELINED_ACTIONS[action] === true;
}

export function IsOptimistic(action: unknown): boolean {
	return typeIs(action, "string") && OPTIMISTIC_ACTIONS[action] === true;
}

export function RequestLimit(pipelined?: boolean): number {
	return pipelined ? PIPELINE_REQUEST_LIMIT : SERIAL_REQUEST_LIMIT;
}

export function IsCoolingDown(now: unknown, previous: unknown, cooldown: unknown): boolean {
	const clock = tonumber(now);
	const last = tonumber(previous);
	const window = tonumber(cooldown);
	if (clock === undefined || last === undefined || window === undefined) {
		return false;
	}
	return clock - last < window;
}
