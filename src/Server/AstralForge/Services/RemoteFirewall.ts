import ModuleLog = require("../ModuleLog");
import BazaarMath from "../Modules/BazaarMath";
import OpsMath from "../Modules/OpsMath";
import Protocol from "../../../Shared/AstralForge/Shared/Protocol";
import { Dict, isTable, LoadService, req, SharedFolder } from "./LuaInterop";

interface RemoteFirewallMathApi {
	MAX_SAFE_USER_ID: number;
	MIN_SAFE_USER_ID: number;
	COOLDOWN_KEY_FIELDS: string[];
	TRADE_MAX_ENTRIES: number;
	Integer(this: void, value: unknown): boolean;
	SafeNumber(this: void, value: unknown): boolean;
	CoerceUserId(this: void, raw: unknown, studio?: boolean): number | undefined;
	ExtractUserId(this: void, payload: unknown): unknown;
	CooldownKey(this: void, action: string, payload: unknown, fields?: string[]): string;
	StringField(this: void, payload: Dict, key: string, minimum: number, maximum: number): boolean;
	StringArrayField(
		this: void,
		payload: Dict,
		key: string,
		maxEntries: number,
		entryMinLen: number,
		entryMaxLen: number,
	): boolean;
	NumberField(
		this: void,
		payload: Dict,
		key: string,
		minimum: number,
		maximum: number,
		mustBeInteger?: boolean,
	): boolean;
	ValidateTradeOffer(this: void, offer: unknown, maxItems: number): LuaTuple<[boolean, string | undefined]>;
	Inspect(
		this: void,
		value: unknown,
		depth?: number,
		seen?: Set<unknown>,
		budget?: { Value: number },
		maxEntries?: number,
	): LuaTuple<[boolean, string | undefined]>;
	IsSessionOnlyPayload(this: void, payload: unknown, sessionKeys?: Record<string, boolean>): boolean;
}

interface GameConfigShape {
	RemoteFirewall?: { Overrides?: unknown };
	Trading: { MaxItems: number };
	Anomalies: { LoadoutSlots: number };
}

interface ServerTelemetryApi {
	RecordRemote(this: void, accepted: boolean, reason?: string): void;
	RecordIntegrityReport(this: void): void;
}

interface Rule {
	Cost: number;
	Cooldown: number;
}

interface Bucket {
	Tokens: number;
	LastRefill: number;
	LastAction: Record<string, number>;
	LastActionCount: number;
	Strikes: number;
	LastStrike: number;
	QuarantineUntil: number;
	WindowStart: number;
	WindowCount: number;
	LastRejectedAction?: string;
}

interface ClientIntegrityState {
	Count: number;
	LastAt: number;
	Kinds: Record<string, number>;
}

interface ConfirmedProof {
	ServerConfirmed: boolean;
	CorroboratedSignals: number;
	Rule: string;
}

export = (loadService: LoadService) => {
	const Players = game.GetService("Players");
	const RunService = game.GetService("RunService");
	const ReplicatedStorage = game.GetService("ReplicatedStorage");

	const GameConfig = req<GameConfigShape>(SharedFolder().WaitForChild("GameConfig"));
	const RemoteFirewallMath = OpsMath("RemoteFirewallMath") as RemoteFirewallMathApi;
	const ServerTelemetry = loadService("ServerTelemetry") as ServerTelemetryApi;

	const ACTIONS: Record<string, boolean> = {};
	for (const [, action] of pairs(Protocol.Actions)) {
		ACTIONS[action] = true;
	}

	const CLIENT_SIGNAL_RULES: Record<string, Record<string, boolean>> = {
		MEMORY_INTEGRITY_VIOLATION: {
			GC_WEAK_VALUE_RETAINED_V1: true,
		},
		ENVIRONMENT_HOOK_VIOLATION: {
			GETFENV_TIMING_PROXY_V1: true,
		},
		PHYSICS_INTEGRITY_VIOLATION: {
			CLIENT_MOTION_ENVELOPE_V1: true,
		},
	};
	const CLIENT_INTEGRITY_REPORTS = new Map<Player, ClientIntegrityState>();

	const DEFAULT_RULE: Rule = { Cost: 1, Cooldown: 0.06 };

	const COOLDOWN_KEY_FIELDS = RemoteFirewallMath.COOLDOWN_KEY_FIELDS;

	function cooldownKey(action: string, payload: unknown): string {
		return RemoteFirewallMath.CooldownKey(action, payload, COOLDOWN_KEY_FIELDS);
	}

	const RULES: Record<string, Rule> = {
		[Protocol.Actions.GetState]: { Cost: 0.35, Cooldown: 0.18 },
		[Protocol.Actions.MeasureLatency]: { Cost: 0.05, Cooldown: 1.5 },
		[Protocol.Actions.GetPlayers]: { Cost: 0.35, Cooldown: 0.2 },
		[Protocol.Actions.SubmitFeedback]: { Cost: 4, Cooldown: 45 },
		[Protocol.Actions.ReportPlayer]: { Cost: 4, Cooldown: 60 },
		[Protocol.Actions.GetPlayerMirror]: { Cost: 0.6, Cooldown: 0.2 },
		[Protocol.Actions.VisitPlot]: { Cost: 0.7, Cooldown: 0.45 },
		[Protocol.Actions.LeavePlot]: { Cost: 0.35, Cooldown: 0.2 },
		[Protocol.Actions.NudgeCrew]: { Cost: 0.5, Cooldown: 2.5 },
		[Protocol.Actions.ReportPresence]: { Cost: 0.05, Cooldown: 1.5 },
		[Protocol.Actions.CollectVault]: { Cost: 1, Cooldown: 0.08 },
		[Protocol.Actions.Overcharge]: { Cost: 0.5, Cooldown: 0.06 },
		[Protocol.Actions.PulseAnomaly]: { Cost: 1, Cooldown: 0.08 },
		[Protocol.Actions.SpinWheel]: { Cost: 2, Cooldown: 1.2 },
		[Protocol.Actions.OpenItemCrate]: { Cost: 2, Cooldown: 0.18 },
		[Protocol.Actions.BulkSalvageItems]: { Cost: 2, Cooldown: 0.8 },
		[Protocol.Actions.EquipBestItems]: { Cost: 1.5, Cooldown: 0.7 },
		[Protocol.Actions.ToggleItemLock]: { Cost: 0.5, Cooldown: 0.12 },
		[Protocol.Actions.SetItemAutoSalvage]: { Cost: 0.75, Cooldown: 0.3 },
		[Protocol.Actions.SetAnomalyLoadout]: { Cost: 0.75, Cooldown: 0.3 },
		[Protocol.Actions.SetAutoForge]: { Cost: 0.75, Cooldown: 0.22 },
		[Protocol.Actions.SetSetting]: { Cost: 0.5, Cooldown: 0.12 },
		[Protocol.Actions.SetProfileStyle]: { Cost: 0.75, Cooldown: 0.3 },
		[Protocol.Actions.SetMobileLayout]: { Cost: 0.75, Cooldown: 0.3 },
		[Protocol.Actions.ChatOpenWhisper]: { Cost: 0.5, Cooldown: 0.5 },
		[Protocol.Actions.ChatGlobal]: { Cost: 0.5, Cooldown: 1 },
		[Protocol.Actions.GetCrew]: { Cost: 0.25, Cooldown: 0.3 },
		[Protocol.Actions.CrewInvite]: { Cost: 1, Cooldown: 1.5 },
		[Protocol.Actions.CrewRespond]: { Cost: 0.5, Cooldown: 0.5 },
		[Protocol.Actions.CrewLeave]: { Cost: 0.5, Cooldown: 1 },
		[Protocol.Actions.CrewKick]: { Cost: 1, Cooldown: 1 },
		[Protocol.Actions.CrewRename]: { Cost: 1.5, Cooldown: 5 },
		[Protocol.Actions.CrewClaim]: { Cost: 0.75, Cooldown: 0.75 },
		[Protocol.Actions.SetTutorialStep]: { Cost: 0.5, Cooldown: 0.12 },
		[Protocol.Actions.RedeemCode]: { Cost: 2, Cooldown: 1.4 },
		[Protocol.Actions.VerifyCreatorFollow]: { Cost: 1, Cooldown: 0.8 },
		[Protocol.Actions.SyncShop]: { Cost: 1, Cooldown: 1.2 },
		[Protocol.Actions.StudioGrantProduct]: { Cost: 1, Cooldown: 0.4 },
		[Protocol.Actions.GetGuild]: { Cost: 0.4, Cooldown: 0.25 },
		[Protocol.Actions.GetGuildLeaderboard]: { Cost: 0.7, Cooldown: 1 },
		[Protocol.Actions.GetLeaderboard]: { Cost: 0.8, Cooldown: 1 },
		[Protocol.Actions.GetAdminState]: { Cost: 0.5, Cooldown: 0.8 },
		[Protocol.Actions.AdminExecute]: { Cost: 4, Cooldown: 0.8 },
		[Protocol.Actions.CreateGuild]: { Cost: 2, Cooldown: 2 },
		[Protocol.Actions.JoinGuild]: { Cost: 1.5, Cooldown: 1 },
		[Protocol.Actions.LeaveGuild]: { Cost: 1, Cooldown: 1 },
		[Protocol.Actions.DisbandGuild]: { Cost: 2, Cooldown: 2 },
		[Protocol.Actions.KickGuildMember]: { Cost: 1.5, Cooldown: 0.5 },
		[Protocol.Actions.SetGuildRole]: { Cost: 1.5, Cooldown: 0.5 },
		[Protocol.Actions.RenameGuild]: { Cost: 2, Cooldown: 2 },
		[Protocol.Actions.ContributeGuild]: { Cost: 1, Cooldown: 0.25 },
		[Protocol.Actions.BuyGuildUpgrade]: { Cost: 1.5, Cooldown: 0.7 },
		[Protocol.Actions.ClaimGuildGoal]: { Cost: 1.5, Cooldown: 0.4 },
		[Protocol.Actions.SendGuildChat]: { Cost: 0.25, Cooldown: 0.4 },
		[Protocol.Actions.GetGuildChatHistory]: { Cost: 0.25, Cooldown: 0.2 },
		[Protocol.Actions.GetGuildAnnouncements]: { Cost: 0.25, Cooldown: 0.25 },
		[Protocol.Actions.GetGuildSettings]: { Cost: 0.2, Cooldown: 0.5 },
		[Protocol.Actions.SetGuildSettings]: { Cost: 0.75, Cooldown: 1 },
		[Protocol.Actions.GetGuildLogoReview]: { Cost: 0.3, Cooldown: 1 },
		[Protocol.Actions.CreateGuildAnnouncement]: { Cost: 1, Cooldown: 2 },
		[Protocol.Actions.EditGuildAnnouncement]: { Cost: 0.25, Cooldown: 0.5 },
		[Protocol.Actions.PinGuildAnnouncement]: { Cost: 0.25, Cooldown: 0.5 },
		[Protocol.Actions.ArchiveGuildAnnouncement]: { Cost: 0.25, Cooldown: 0.5 },
		[Protocol.Actions.SetGuildAnnouncementExpiry]: { Cost: 0.25, Cooldown: 0.5 },
		[Protocol.Actions.MuteGuildMember]: { Cost: 0.5, Cooldown: 0.6 },
		[Protocol.Actions.UnmuteGuildMember]: { Cost: 0.5, Cooldown: 0.6 },
		[Protocol.Actions.BanGuildMember]: { Cost: 1, Cooldown: 1 },
		[Protocol.Actions.UnbanGuildMember]: { Cost: 0.5, Cooldown: 0.6 },
		[Protocol.Actions.UploadGuildLogo]: { Cost: 0.25, Cooldown: 0.5 },
		[Protocol.Actions.ModerateGuildLogo]: { Cost: 0.5, Cooldown: 1 },
		[Protocol.Actions.DomainExpansion]: { Cost: 5, Cooldown: 5 },
		[Protocol.Actions.DomainLattice]: { Cost: 1, Cooldown: 0.15 },
		[Protocol.Actions.EventAct]: { Cost: 0.4, Cooldown: 0.2 },
		[Protocol.Actions.UpgradeContinuum]: { Cost: 1.5, Cooldown: 0.35 },
		// Star Foundry moves; Ignite is a timing tap, so the cooldown is short
		[Protocol.Actions.FoundryAct]: { Cost: 0.45, Cooldown: 0.06 },
		[Protocol.Actions.Ascend]: { Cost: 5, Cooldown: 5 },
		[Protocol.Actions.UpgradeSigil]: { Cost: 1.5, Cooldown: 0.3 },
		[Protocol.Actions.EchoAct]: { Cost: 0.8, Cooldown: 0.15 },
		[Protocol.Actions.RebirthAct]: { Cost: 0.6, Cooldown: 0.2 },
		[Protocol.Actions.TradeChat]: { Cost: 0.8, Cooldown: 0.5 },
		[Protocol.Actions.TradeRequest]: { Cost: 0.6, Cooldown: 0.3 },
		[Protocol.Actions.ReportClientIntegrity]: { Cost: 0.25, Cooldown: 30 },
		[Protocol.Actions.ReportPerformance]: { Cost: 0.1, Cooldown: 45 },
		[Protocol.Actions.ClaimConvergenceReward]: { Cost: 1, Cooldown: 0.35 },
		[Protocol.Actions.GetTrade]: { Cost: 0.25, Cooldown: 0.15 },
		[Protocol.Actions.InviteTrade]: { Cost: 0.8, Cooldown: 0.55 },
		[Protocol.Actions.RespondTrade]: { Cost: 0.7, Cooldown: 0.22 },
		[Protocol.Actions.UpdateTradeOffer]: { Cost: 0.35, Cooldown: 0.07 },
		[Protocol.Actions.SetTradeReady]: { Cost: 0.45, Cooldown: 0.12 },
		[Protocol.Actions.ConfirmTrade]: { Cost: 1.1, Cooldown: 0.22 },
		[Protocol.Actions.CancelTrade]: { Cost: 0.45, Cooldown: 0.18 },
		[Protocol.Actions.TradeViewAway]: { Cost: 0.2, Cooldown: 0.35 },
		[Protocol.Actions.BazaarPlay]: { Cost: 1, Cooldown: 0.3 },
		[Protocol.Actions.SetMarketFavorite]: { Cost: 0.5, Cooldown: 0.3 },
		[Protocol.Actions.RequestProcurement]: { Cost: 1, Cooldown: 1 },
		[Protocol.Actions.SelectSpecialization]: { Cost: 1, Cooldown: 0.5 },
		[Protocol.Actions.BuyDailyOffer]: { Cost: 1, Cooldown: 0.35 },
		[Protocol.Actions.BuyCrateSkin]: { Cost: 1, Cooldown: 0.5 },
		[Protocol.Actions.EquipCrateSkin]: { Cost: 0.5, Cooldown: 0.25 },
		[Protocol.Actions.FuseRelics]: { Cost: 1, Cooldown: 0.35 },
	};

	const EXEMPT_ACTIONS: Record<string, boolean> = {
		[Protocol.Actions.GetState]: true,
		[Protocol.Actions.GetTrade]: true,
		[Protocol.Actions.ConfirmTrade]: true,
		[Protocol.Actions.CancelTrade]: true,
		[Protocol.Actions.TradeViewAway]: true,
		[Protocol.Actions.CollectVault]: true,
		[Protocol.Actions.Overcharge]: true,
		[Protocol.Actions.Rebirth]: true,
		[Protocol.Actions.ClaimDaily]: true,
		[Protocol.Actions.ClaimAllMail]: true,
		[Protocol.Actions.VerifyCreatorFollow]: true,
	};

	// Exempt actions skip the token/window/strike enforcement, but some still
	// need a per-action cooldown to prevent spam (e.g. Rebirth, daily claims).
	// Core click actions (CollectVault, Overcharge) remain fully uncapped.
	const EXEMPT_COOLDOWNS: Record<string, number> = {
		[Protocol.Actions.ConfirmTrade]: 0.22,
		[Protocol.Actions.CancelTrade]: 0.18,
		[Protocol.Actions.TradeViewAway]: 0.35,
		[Protocol.Actions.Rebirth]: 1,
		[Protocol.Actions.ClaimDaily]: 1,
		[Protocol.Actions.ClaimAllMail]: 1,
		[Protocol.Actions.VerifyCreatorFollow]: 5,
	};

	function applyFirewallOverrides() {
		const overrides =
			GameConfig.RemoteFirewall !== undefined ? GameConfig.RemoteFirewall.Overrides : undefined;
		if (!isTable(overrides)) return;
		for (const [action, rule] of pairs(overrides)) {
			if (
				typeIs(action, "string") &&
				isTable(rule) &&
				typeIs(rule.Cost, "number") &&
				typeIs(rule.Cooldown, "number")
			) {
				RULES[action] = { Cost: rule.Cost, Cooldown: rule.Cooldown };
			}
		}
	}

	applyFirewallOverrides();

	const NO_PAYLOAD_ACTIONS: Record<string, boolean> = {
		[Protocol.Actions.GetState]: true,
		[Protocol.Actions.MeasureLatency]: true,
		[Protocol.Actions.GetPlayers]: true,
		[Protocol.Actions.GetTrade]: true,
		[Protocol.Actions.ConfirmTrade]: true,
		[Protocol.Actions.CancelTrade]: true,
		[Protocol.Actions.GetAdminState]: true,
		[Protocol.Actions.CollectVault]: true,
		[Protocol.Actions.Overcharge]: true,
		[Protocol.Actions.DomainExpansion]: true,
		[Protocol.Actions.UpgradeContinuum]: true,
		[Protocol.Actions.Ascend]: true,
		[Protocol.Actions.ClaimDaily]: true,
		[Protocol.Actions.ClaimExpedition]: true,
		[Protocol.Actions.CompleteTutorial]: true,
		[Protocol.Actions.ReplayTutorial]: true,
		[Protocol.Actions.DismissRelease]: true,
		[Protocol.Actions.OpenRelease]: true,
		[Protocol.Actions.PulseAnomaly]: true,
		[Protocol.Actions.StabilizeAnomaly]: true,
		[Protocol.Actions.ActivateAnomalySurge]: true,
		[Protocol.Actions.SyncShop]: true,
		[Protocol.Actions.LeavePlot]: true,
		[Protocol.Actions.GetGuild]: true,
		[Protocol.Actions.LeaveGuild]: true,
		[Protocol.Actions.DisbandGuild]: true,
		[Protocol.Actions.ClaimGuildGoal]: true,
		[Protocol.Actions.EquipBestItems]: true,
		[Protocol.Actions.ClaimAllMail]: true,
		[Protocol.Actions.VerifyCreatorFollow]: true,
	};

	function integer(value: unknown): boolean {
		return RemoteFirewallMath.Integer(value);
	}

	function safeNumber(value: unknown): boolean {
		return RemoteFirewallMath.SafeNumber(value);
	}

	function inspect(
		value: unknown,
		depth: number,
		seen: Set<unknown>,
		budget: { Value: number },
		maxEntries?: number,
	): LuaTuple<[boolean, string | undefined]> {
		return RemoteFirewallMath.Inspect(value, depth, seen, budget, maxEntries);
	}

	function stringField(payload: Dict, key: string, minimum: number, maximum: number): boolean {
		return RemoteFirewallMath.StringField(payload, key, minimum, maximum);
	}

	function stringArrayField(
		payload: Dict,
		key: string,
		maxEntries: number,
		entryMinLen: number,
		entryMaxLen: number,
	): boolean {
		return RemoteFirewallMath.StringArrayField(payload, key, maxEntries, entryMinLen, entryMaxLen);
	}

	function numberField(
		payload: Dict,
		key: string,
		minimum: number,
		maximum: number,
		mustBeInteger?: boolean,
	): boolean {
		return RemoteFirewallMath.NumberField(payload, key, minimum, maximum, mustBeInteger);
	}

	function coerceUserId(raw: unknown): number | undefined {
		let value = raw;
		if (typeIs(value, "Instance") && value.IsA("Player")) {
			value = value.UserId;
		}
		return RemoteFirewallMath.CoerceUserId(value, RunService.IsStudio());
	}

	function extractUserId(payload: unknown): unknown {
		if (typeIs(payload, "Instance") && payload.IsA("Player")) {
			return payload.UserId;
		}
		return RemoteFirewallMath.ExtractUserId(payload);
	}

	function userIdField(payload: unknown): boolean {
		return coerceUserId(extractUserId(payload)) !== undefined;
	}

	function validateActionPayload(action: string, payload: unknown): LuaTuple<[boolean, string | undefined]> {
		if (payload === undefined) {
			if (NO_PAYLOAD_ACTIONS[action] === true) {
				return $tuple(true, undefined);
			}
			return $tuple(false, "payload is required");
		}
		if (!typeIs(payload, "table")) {
			return $tuple(false, "payload must be a table");
		}
		const bag = payload as Dict;
		const maxEntries =
			action === Protocol.Actions.UpdateTradeOffer ? RemoteFirewallMath.TRADE_MAX_ENTRIES : undefined;
		const [ok, reason] = inspect(payload, 0, new Set<unknown>(), { Value: 0 }, maxEntries);
		if (!ok) {
			return $tuple(false, reason);
		}
		if (NO_PAYLOAD_ACTIONS[action] === true) {
			if (!RemoteFirewallMath.IsSessionOnlyPayload(payload)) {
				return $tuple(false, "this action does not accept a payload");
			}
		}
		if (
			action === Protocol.Actions.GetGuildChatHistory ||
			action === Protocol.Actions.GetGuildAnnouncements ||
			action === Protocol.Actions.GetGuildSettings ||
			action === Protocol.Actions.GetGuildLogoReview
		) {
			for (const [key] of pairs(bag)) {
				if (
					key !== "BeforeId" &&
					key !== "Limit" &&
					key !== "Gen" &&
					key !== "N" &&
					key !== "TxnId"
				) {
					return $tuple(false, "unexpected read-only guild field");
				}
			}
		}

		if (action === Protocol.Actions.UpdateTradeOffer) {
			const [validOffer, offerReason] = RemoteFirewallMath.ValidateTradeOffer(
				bag.Offer,
				GameConfig.Trading.MaxItems,
			);
			if (!validOffer) {
				return $tuple(false, offerReason);
			}
		} else if (action === Protocol.Actions.SubmitFeedback) {
			if (!stringField(bag, "Category", 3, 16) || !stringField(bag, "Message", 8, 600)) {
				return $tuple(false, "invalid feedback");
			}
			const category = bag.Category;
			if (
				category !== "Bug" &&
				category !== "Suggestion" &&
				category !== "Balance" &&
				category !== "Performance" &&
				category !== "Interface" &&
				category !== "Other"
			) {
				return $tuple(false, "invalid feedback category");
			}
			if (bag.Impact !== undefined && !numberField(bag, "Impact", 1, 5, true)) {
				return $tuple(false, "invalid feedback impact");
			}
			if (bag.Device !== undefined && !stringField(bag, "Device", 1, 16)) {
				return $tuple(false, "invalid feedback device");
			}
			if (bag.Screen !== undefined && !stringField(bag, "Screen", 3, 16)) {
				return $tuple(false, "invalid feedback screen");
			}
			if (bag.Page !== undefined && !stringField(bag, "Page", 1, 32)) {
				return $tuple(false, "invalid feedback page");
			}
		} else if (action === Protocol.Actions.ReportPlayer) {
			if (!stringField(bag, "Reason", 3, 16) || !userIdField(bag)) {
				return $tuple(false, "invalid report payload");
			}
			if (bag.Details !== undefined && !stringField(bag, "Details", 0, 400)) {
				return $tuple(false, "invalid report details");
			}
			if (
				bag.Severity !== undefined &&
				bag.Severity !== "Minor" &&
				bag.Severity !== "Serious" &&
				bag.Severity !== "Urgent"
			) {
				return $tuple(false, "invalid report severity");
			}
			if (bag.When !== undefined && bag.When !== "Now" && bag.When !== "Earlier" && bag.When !== "Repeated") {
				return $tuple(false, "invalid report timing");
			}
			if (
				bag.Where !== undefined &&
				bag.Where !== "Chat" &&
				bag.Where !== "Trade" &&
				bag.Where !== "Guild" &&
				bag.Where !== "World"
			) {
				return $tuple(false, "invalid report location");
			}
		} else if (action === Protocol.Actions.SetProfileStyle) {
			const accent = bag.Accent;
			const frame = bag.Frame;
			if (accent === undefined && frame === undefined) {
				return $tuple(false, "invalid profile style");
			}
			if (accent !== undefined && !stringField(bag, "Accent", 1, 32)) {
				return $tuple(false, "invalid profile accent");
			}
			if (frame !== undefined && !stringField(bag, "Frame", 1, 32)) {
				return $tuple(false, "invalid profile frame");
			}
		} else if (action === Protocol.Actions.SetSetting) {
			if (isTable(bag.Values)) {
				const values = bag.Values;
				let count = 0;
				for (const [key] of pairs(values)) {
					count += 1;
					if (count > 24 || !typeIs(key, "string") || !numberField(values, key as string, 0, 1)) {
						return $tuple(false, "invalid setting payload");
					}
				}
				if (count === 0) {
					return $tuple(false, "invalid setting payload");
				}
				if (bag.Label !== undefined && !stringField(bag, "Label", 1, 80)) {
					return $tuple(false, "invalid setting payload");
				}
			} else if (!stringField(bag, "Key", 1, 40) || !numberField(bag, "Value", 0, 1)) {
				return $tuple(false, "invalid setting payload");
			}
		} else if (action === Protocol.Actions.SetMobileLayout) {
			if (!isTable(bag.Values)) {
				return $tuple(false, "mobile layout values are missing");
			}
			const values = bag.Values;
			const allowedLayout: Record<string, boolean> = {
				MobileQuickX: true,
				MobileQuickY: true,
				MobileDockX: true,
				MobileDockY: true,
				MobileToastX: true,
				MobileToastY: true,
			};
			let count = 0;
			for (const [key] of pairs(values)) {
				count += 1;
				if (allowedLayout[key as string] !== true || !numberField(values, key as string, 0, 1)) {
					return $tuple(false, "invalid mobile layout value");
				}
			}
			if (bag.Slots !== undefined && !stringField(bag, "Slots", 0, 512)) {
				return $tuple(false, "invalid mobile layout slots");
			}
			if (count > 6 || (count < 1 && bag.Slots === undefined)) {
				return $tuple(false, "invalid mobile layout size");
			}
		} else if (action === Protocol.Actions.RedeemCode) {
			if (!stringField(bag, "Code", 1, 32)) {
				return $tuple(false, "invalid code payload");
			}
		} else if (action === Protocol.Actions.VerifyCreatorFollow) {
			if (payload !== undefined && !typeIs(payload, "table")) {
				return $tuple(false, "invalid follow verification payload");
			}
		} else if (action === Protocol.Actions.StudioGrantProduct) {
			if (!stringField(bag, "Id", 1, 64)) {
				return $tuple(false, "invalid studio product payload");
			}
		} else if (action === Protocol.Actions.OpenItemCrate) {
			if (!stringField(bag, "Id", 1, 48) || !numberField(bag, "Count", 1, 5, true)) {
				return $tuple(false, "invalid crate payload");
			}
		} else if (action === Protocol.Actions.EquipItem) {
			if (!stringField(bag, "Uid", 1, 48) || !stringField(bag, "Target", 1, 96)) {
				return $tuple(false, "invalid socket payload");
			}
		} else if (action === Protocol.Actions.UnequipItem) {
			if (!stringField(bag, "Target", 1, 96)) {
				return $tuple(false, "invalid socket payload");
			}
		} else if (action === Protocol.Actions.UpgradeItem || action === Protocol.Actions.SalvageItem) {
			if (!stringField(bag, "Uid", 1, 48)) {
				return $tuple(false, "invalid item payload");
			}
		} else if (action === Protocol.Actions.ToggleItemLock) {
			if (!stringField(bag, "Uid", 1, 48)) {
				return $tuple(false, "invalid relic lock payload");
			}
		} else if (action === Protocol.Actions.BulkSalvageItems) {
			const uids = bag.Uids;
			if (!isTable(uids)) {
				return $tuple(false, "bulk salvage selection is missing");
			}
			let count = 0;
			for (const [, uid] of pairs(uids)) {
				count += 1;
				if (count > 25 || !typeIs(uid, "string") || uid.size() < 1 || uid.size() > 48) {
					return $tuple(false, "invalid bulk salvage selection");
				}
			}
			if (count < 1) return $tuple(false, "bulk salvage selection is empty");
		} else if (action === Protocol.Actions.SetItemAutoSalvage) {
			if (!typeIs(bag.Enabled, "boolean") || !typeIs(bag.KeepNew, "boolean") || !isTable(bag.Rarities)) {
				return $tuple(false, "invalid auto-salvage payload");
			}
			const rarities = bag.Rarities;
			let count = 0;
			for (const [, rarity] of pairs(rarities)) {
				count += 1;
				if (count > 6 || !typeIs(rarity, "string") || rarity.size() < 3 || rarity.size() > 16) {
					return $tuple(false, "invalid auto-salvage rarity");
				}
			}
		} else if (
			action === Protocol.Actions.LaunchExpedition ||
			action === Protocol.Actions.EquipArtifact ||
			action === Protocol.Actions.UpgradeArtifact ||
			action === Protocol.Actions.BuyArtifact ||
			action === Protocol.Actions.BuySignalOffer ||
			action === Protocol.Actions.EquipTitle ||
			action === Protocol.Actions.ActivateBoost ||
			action === Protocol.Actions.BuyItemOffer ||
			action === Protocol.Actions.BuyAnomalyProtocol ||
			action === Protocol.Actions.SetAnomalyChannel ||
			action === Protocol.Actions.ReadStoryChapter ||
			action === Protocol.Actions.ClaimStoryChapter ||
			action === Protocol.Actions.ReadMail ||
			action === Protocol.Actions.ClaimMail ||
			action === Protocol.Actions.DeleteMail
		) {
			if (!stringField(bag, "Id", 1, 96)) {
				if (action === Protocol.Actions.LaunchExpedition) {
					return $tuple(false, "invalid expedition");
				} else if (
					action === Protocol.Actions.EquipArtifact ||
					action === Protocol.Actions.UpgradeArtifact ||
					action === Protocol.Actions.BuyArtifact
				) {
					return $tuple(false, "invalid artifact");
				} else if (action === Protocol.Actions.BuySignalOffer) {
					return $tuple(false, "invalid signal offer");
				} else if (action === Protocol.Actions.EquipTitle) {
					return $tuple(false, "invalid title selection");
				} else if (action === Protocol.Actions.ActivateBoost) {
					return $tuple(false, "invalid boost selection");
				} else if (action === Protocol.Actions.BuyItemOffer) {
					return $tuple(false, "invalid shop offer");
				} else if (action === Protocol.Actions.BuyAnomalyProtocol) {
					return $tuple(false, "invalid protocol");
				} else if (action === Protocol.Actions.SetAnomalyChannel) {
					return $tuple(false, "invalid reactor channel");
				} else if (
					action === Protocol.Actions.ReadStoryChapter ||
					action === Protocol.Actions.ClaimStoryChapter
				) {
					return $tuple(false, "invalid story chapter");
				} else if (
					action === Protocol.Actions.ReadMail ||
					action === Protocol.Actions.ClaimMail ||
					action === Protocol.Actions.DeleteMail
				) {
					return $tuple(false, "invalid mail");
				}
				return $tuple(false, "invalid action payload");
			}
		} else if (action === Protocol.Actions.FoundryAct) {
			if (!typeIs(payload, "table") || !stringField(bag, "Op", 1, 12)) {
				return $tuple(false, "invalid foundry move");
			}
			for (const field of ["From", "To", "At"]) {
				const value = bag[field];
				if (value !== undefined && (!typeIs(value, "string") || value.size() < 1 || value.size() > 16)) {
					return $tuple(false, "invalid foundry cell");
				}
			}
			if (bag.Back !== undefined && !typeIs(bag.Back, "boolean")) {
				return $tuple(false, "invalid foundry rotation");
			}
		} else if (action === Protocol.Actions.EventAct) {
			if (!typeIs(payload, "table") || (bag.Op !== "Catch" && bag.Op !== "Claim")) {
				return $tuple(false, "invalid event action");
			}
			if (bag.Op === "Claim" && !numberField(bag, "Drop", 1, 8, true)) {
				return $tuple(false, "invalid supply drop");
			}
		} else if (action === Protocol.Actions.DomainLattice) {
			if (!typeIs(payload, "table") || (bag.Op !== "Etch" && bag.Op !== "Clear")) {
				return $tuple(false, "invalid lattice action");
			}
			if (
				bag.Op === "Etch" &&
				!(numberField(bag, "A", 1, 13, true) && numberField(bag, "B", 1, 13, true))
			) {
				return $tuple(false, "invalid lattice anchors");
			}
		} else if (action === Protocol.Actions.SetAnomalyLoadout) {
			if (!stringArrayField(bag, "Loadout", GameConfig.Anomalies.LoadoutSlots, 1, 32)) {
				return $tuple(false, "invalid reactor loadout payload");
			}
		} else if (action === Protocol.Actions.ClaimForgePathStep) {
			if (!numberField(bag, "Step", 1, 10000, true)) {
				return $tuple(false, "invalid forge path payload");
			}
		} else if (action === Protocol.Actions.BuyDailyOffer) {
			if (!numberField(bag, "Slot", 1, 12, true)) {
				return $tuple(false, "invalid daily offer");
			}
		} else if (action === Protocol.Actions.BuyCrateSkin || action === Protocol.Actions.EquipCrateSkin) {
			if (!stringField(bag, "Id", 2, 32)) {
				return $tuple(false, "invalid crate skin");
			}
		} else if (action === Protocol.Actions.FuseRelics) {
			if (!stringField(bag, "Id", 2, 64)) {
				return $tuple(false, "invalid relic");
			}
		} else if (action === Protocol.Actions.BazaarPlay) {
			const [order] = BazaarMath.ReadOrder(bag);
			if (order === undefined) {
				return $tuple(false, "invalid Black Market order");
			}
		} else if (action === Protocol.Actions.SetMarketFavorite) {
			if (!stringField(bag, "Id", 2, 24) || !typeIs(bag.Saved, "boolean")) {
				return $tuple(false, "invalid saved supply");
			}
		} else if (action === Protocol.Actions.RequestProcurement) {
			if (!stringField(bag, "Id", 0, 24)) {
				return $tuple(false, "invalid supply request");
			}
		} else if (action === Protocol.Actions.UpgradeSigil) {
			if (!stringField(bag, "Id", 1, 24)) return $tuple(false, "invalid sigil");
		} else if (action === Protocol.Actions.SelectSpecialization) {
			if (!stringField(bag, "Id", 1, 24)) return $tuple(false, "invalid forge specialization");
		} else if (action === Protocol.Actions.SpinWheel) {
			if (!numberField(bag, "ExpectedSpin", 0, 1e12 - 1, true))
				return $tuple(false, "invalid wheel sequence");
		} else if (action === Protocol.Actions.UpgradeCrew) {
			if (!stringField(bag, "Role", 1, 64)) {
				return $tuple(false, "invalid crew payload");
			}
		} else if (action === Protocol.Actions.SetAutoForge) {
			if (
				!typeIs(bag.Enabled, "boolean") ||
				!stringField(bag, "MachineId", 1, 64) ||
				!numberField(bag, "Reserve", 0, 0.9)
			) {
				return $tuple(false, "invalid auto-forge payload");
			}
		} else if (action === Protocol.Actions.TradeChat) {
			if (!typeIs(payload, "table")) {
				return $tuple(false, "invalid trade chat");
			}
			if (bag.Text !== undefined && (!typeIs(bag.Text, "string") || bag.Text.size() > 200)) {
				return $tuple(false, "invalid trade message");
			}
			if (bag.Phrase !== undefined && !numberField(bag, "Phrase", 1, 16, true)) {
				return $tuple(false, "invalid trade phrase");
			}
		} else if (action === Protocol.Actions.TradeRequest) {
			if (!typeIs(payload, "table") || !isTable(bag.Request)) {
				return $tuple(false, "invalid trade request");
			}
			const request = bag.Request;
			const ids = request.ItemIds;
			if (ids !== undefined && (!isTable(ids) || (ids as unknown as Array<unknown>).size() > 16)) {
				return $tuple(false, "invalid requested relics");
			}
		} else if (action === Protocol.Actions.Rebirth || action === Protocol.Actions.RebirthAct) {
			if (action === Protocol.Actions.RebirthAct) {
				const ops: Record<string, boolean> = { Star: true, Vow: true, Keep: true };
				if (!typeIs(bag.Op, "string") || ops[bag.Op] !== true) {
					return $tuple(false, "invalid rebirth action");
				}
				for (const field of ["Index", "Pick"]) {
					if (bag[field] !== undefined && !numberField(bag, field, 0, 64, true)) {
						return $tuple(false, "invalid rebirth number");
					}
				}
			}
			if (bag.Vow !== undefined && (!typeIs(bag.Vow, "string") || bag.Vow.size() > 16)) {
				return $tuple(false, "invalid vow");
			}
			const keep = bag.Keep;
			if (keep !== undefined) {
				if (!isTable(keep) || (keep as unknown as Array<unknown>).size() > 3) {
					return $tuple(false, "invalid keepsakes");
				}
				for (const [, id] of pairs(keep)) {
					if (!typeIs(id, "string") || id.size() > 48) {
						return $tuple(false, "invalid keepsake");
					}
				}
			}
		} else if (action === Protocol.Actions.EchoAct) {
			const op = isTable(bag) ? bag.Op : undefined;
			const ops: Record<string, boolean> = {
				Strike: true,
				Reroll: true,
				Keep: true,
				Slot: true,
				Tune: true,
				Fuse: true,
				Lock: true,
				Dismantle: true,
			};
			if (!typeIs(op, "string") || ops[op] !== true) {
				return $tuple(false, "invalid echo action");
			}
			for (const field of ["Uid", "A", "B"]) {
				const value = bag[field];
				if (value !== undefined && (!typeIs(value, "string") || value.size() > 16)) {
					return $tuple(false, "invalid echo");
				}
			}
			for (const field of ["Choice", "Slot", "Times"]) {
				if (bag[field] !== undefined && !numberField(bag, field, 0, 10, true)) {
					return $tuple(false, "invalid echo number");
				}
			}
		} else if (
			action === Protocol.Actions.BuyMachine ||
			action === Protocol.Actions.BuyResearch ||
			action === Protocol.Actions.BuyGridUpgrade
		) {
			const requestedAmount = bag.Amount;
			const validAmount = requestedAmount === "Max" || numberField(bag, "Amount", 1, 1e4, true);
			if (!stringField(bag, "Id", 1, 64) || !validAmount) {
				return $tuple(false, "invalid upgrade payload");
			}
		} else if (action === Protocol.Actions.SetTutorialStep) {
			if (!numberField(bag, "Step", 1, 15, true)) {
				return $tuple(false, "invalid guide payload");
			}
		} else if (action === Protocol.Actions.ClaimConvergenceReward) {
			if (!numberField(bag, "Tier", 1, 10, true)) return $tuple(false, "invalid convergence payload");
		} else if (action === Protocol.Actions.ReportPerformance) {
			if (
				!numberField(bag, "FPS", 0, 360) ||
				!numberField(bag, "P95Ms", 0, 1000) ||
				!numberField(bag, "JankPct", 0, 1) ||
				!numberField(bag, "PingMs", 0, 10000) ||
				!numberField(bag, "Width", 1, 16384) ||
				!numberField(bag, "Height", 1, 16384) ||
				!numberField(bag, "BootMs", 0, 120000) ||
				!stringField(bag, "Input", 1, 16)
			)
				return $tuple(false, "invalid performance payload");
		} else if (action === Protocol.Actions.ClaimTimedReward) {
			if (!numberField(bag, "Index", 1, 100, true)) {
				return $tuple(false, "invalid reward payload");
			}
		} else if (action === Protocol.Actions.ReportPresence) {
			if (bag.Page !== undefined && !stringField(bag, "Page", 1, 32)) {
				return $tuple(false, "invalid presence payload");
			}
			if (bag.Gen !== undefined) {
				if (
					!numberField(bag, "Gen", 1, 1e12, true) ||
					!numberField(bag, "Id", 1, 1e15, true) ||
					!stringField(bag, "N", 8, 80)
				) {
					return $tuple(false, "invalid beat payload");
				}
			}
		} else if (
			action === Protocol.Actions.GetPlayerMirror ||
			action === Protocol.Actions.VisitPlot ||
			action === Protocol.Actions.NudgeCrew
		) {
			if (!userIdField(bag)) {
				const raw = extractUserId(bag);

				ModuleLog.Every(
					string.format("bad-userid:%s", action),
					12,
					"Requests",
					string.format("%s payload UserId type=%s value=%s", action, typeOf(raw), tostring(raw)),
				);
				return $tuple(false, "invalid player id");
			}
		} else if (action === Protocol.Actions.LeavePlot) {
			// read-only guild-scoped requests accept no caller-controlled fields.
		} else if (
			action === Protocol.Actions.ClaimCommanderReward ||
			action === Protocol.Actions.ClaimSeasonTier
		) {
			const key = action === Protocol.Actions.ClaimCommanderReward ? "Level" : "Tier";
			if (!numberField(bag, key, 1, 10000, true)) {
				return $tuple(false, "invalid progression payload");
			}
		} else if (action === Protocol.Actions.UnlockZone || action === Protocol.Actions.SelectZone) {
			let rawId = bag.Id;
			if (typeIs(rawId, "string")) {
				rawId = tonumber(rawId);
				bag.Id = rawId;
			}
			if (typeIs(rawId, "number") && math.abs(rawId - math.floor(rawId)) < 1e-6) {
				bag.Id = math.floor(rawId);
			}
			if (!numberField(bag, "Id", 1, 10000, true)) {
				return $tuple(false, "invalid world payload");
			}
		} else if (
			action === Protocol.Actions.ClaimQuest ||
			action === Protocol.Actions.ClaimAchievement ||
			action === Protocol.Actions.ClaimWeeklyDirective ||
			action === Protocol.Actions.ClaimAnomalyDirective ||
			action === Protocol.Actions.ClaimLabOrder
		) {
			if (!stringField(bag, "Id", 1, 96) && !numberField(bag, "Id", 1, 10000, true)) {
				return $tuple(false, "invalid claim payload");
			}
		} else if (action === Protocol.Actions.ClaimAnomalyMilestone) {
			if (!numberField(bag, "Tier", 1, 10000, true)) {
				return $tuple(false, "invalid anomaly payload");
			}
		} else if (action === Protocol.Actions.RouteLabPower) {
			if (
				!stringField(bag, "Channel", 1, 24) ||
				!numberField(bag, "Delta", -1, 1, true) ||
				bag.Delta === 0
			) {
				return $tuple(false, "invalid power route payload");
			}
		} else if (action === Protocol.Actions.SendGuildChat) {
			if (!stringField(bag, "Content", 1, 800)) return $tuple(false, "invalid guild message");
		} else if (action === Protocol.Actions.ChatOpenWhisper) {
			if (!numberField(bag, "UserId", 1, 1e15, true)) return $tuple(false, "invalid whisper target");
		} else if (action === Protocol.Actions.CrewInvite || action === Protocol.Actions.CrewKick) {
			if (!numberField(bag, "UserId", 1, 1e15, true)) return $tuple(false, "invalid crew member");
		} else if (action === Protocol.Actions.CrewRespond) {
			if (!typeIs(payload, "table") || !typeIs(bag.Accept, "boolean"))
				return $tuple(false, "invalid crew reply");
		} else if (action === Protocol.Actions.CrewRename) {
			if (!stringField(bag, "Name", 2, 80)) return $tuple(false, "invalid crew name");
		} else if (action === Protocol.Actions.CrewClaim) {
			if (!numberField(bag, "Tier", 1, 3, true)) return $tuple(false, "invalid crew goal");
		} else if (action === Protocol.Actions.ChatGlobal) {
			if (!stringField(bag, "Text", 1, 640)) return $tuple(false, "invalid global message");
		} else if (action === Protocol.Actions.GetGuildChatHistory) {
			if (bag.BeforeId !== undefined && !stringField(bag, "BeforeId", 1, 64))
				return $tuple(false, "invalid guild history cursor");
			if (bag.Limit !== undefined && !numberField(bag, "Limit", 1, 50, true))
				return $tuple(false, "invalid guild history limit");
		} else if (action === Protocol.Actions.GetGuildAnnouncements) {
			if (bag.BeforeId !== undefined && !stringField(bag, "BeforeId", 1, 64))
				return $tuple(false, "invalid announcement cursor");
			if (bag.Limit !== undefined && !numberField(bag, "Limit", 1, 50, true))
				return $tuple(false, "invalid announcement limit");
		} else if (action === Protocol.Actions.GetGuildSettings || action === Protocol.Actions.GetGuildLogoReview) {
			// Read-only guild-scoped requests accept no caller-controlled fields.
		} else if (action === Protocol.Actions.SetGuildSettings) {
			if (!isTable(bag.Settings)) {
				return $tuple(false, "invalid guild settings");
			}
			const allowed: Record<string, boolean> = {
				ChatEnabled: true,
				AnnouncementsEnabled: true,
				LogoEnabled: true,
				OfficerAnnouncements: true,
				OfficerModeration: true,
				SlowMode: true,
			};
			let count = 0;
			for (const [key, value] of pairs(bag.Settings)) {
				count += 1;
				if (count > 6 || allowed[key as string] !== true || !typeIs(value, "boolean"))
					return $tuple(false, "invalid guild settings");
			}
			if (count === 0) return $tuple(false, "empty guild settings");
		} else if (action === Protocol.Actions.CreateGuild) {
			if (typeIs(payload, "table")) {
				if (typeIs(bag.Name, "string")) {
					bag.Name = bag.Name.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
				}
				if (typeIs(bag.Tag, "string")) {
					bag.Tag = bag.Tag.gsub("%s+", "")[0].upper();
				}
			}
			if (!stringField(bag, "Name", 3, 28) || !stringField(bag, "Tag", 3, 4))
				return $tuple(false, "invalid guild charter payload");
		} else if (action === Protocol.Actions.JoinGuild) {
			if (typeIs(payload, "table") && typeIs(bag.Tag, "string")) {
				bag.Tag = bag.Tag.gsub("%s+", "")[0].upper();
			}
			if (!stringField(bag, "Tag", 3, 4)) return $tuple(false, "invalid guild tag");
		} else if (action === Protocol.Actions.KickGuildMember) {
			if (!userIdField(bag)) return $tuple(false, "invalid guild member");
		} else if (action === Protocol.Actions.SetGuildRole) {
			if (!userIdField(bag) || (bag.Role !== "Officer" && bag.Role !== "Member"))
				return $tuple(false, "invalid guild role");
		} else if (action === Protocol.Actions.RenameGuild) {
			if (typeIs(payload, "table") && typeIs(bag.Name, "string")) {
				bag.Name = bag.Name.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
			}
			if (typeIs(payload, "table") && typeIs(bag.Tag, "string")) {
				bag.Tag = bag.Tag.gsub("%s+", "")[0].upper();
			}
			if (!stringField(bag, "Name", 3, 28)) return $tuple(false, "invalid guild rename name");
			if (bag.Tag !== undefined && !stringField(bag, "Tag", 3, 4))
				return $tuple(false, "invalid guild rename tag");
		} else if (action === Protocol.Actions.ContributeGuild) {
			const hasAmount = bag.Amount !== undefined;
			const hasFraction = bag.Fraction !== undefined;
			if (
				hasAmount === hasFraction ||
				(hasAmount && !numberField(bag, "Amount", 1, 1e15)) ||
				(hasFraction && !numberField(bag, "Fraction", 0.0001, 0.25)) ||
				(bag.Currency !== "Cash" && bag.Currency !== "Dust")
			) {
				return $tuple(false, "invalid guild contribution");
			}
		} else if (action === Protocol.Actions.BuyGuildUpgrade) {
			if (!stringField(bag, "Id", 1, 48)) return $tuple(false, "invalid guild upgrade");
		} else if (
			action === Protocol.Actions.CreateGuildAnnouncement ||
			action === Protocol.Actions.EditGuildAnnouncement
		) {
			if (!stringField(bag, "Title", 1, 120) || !stringField(bag, "Body", 1, 800))
				return $tuple(false, "invalid guild announcement");
			if (action === Protocol.Actions.EditGuildAnnouncement && !stringField(bag, "AnnouncementId", 1, 64))
				return $tuple(false, "invalid announcement id");
		} else if (
			action === Protocol.Actions.PinGuildAnnouncement ||
			action === Protocol.Actions.ArchiveGuildAnnouncement ||
			action === Protocol.Actions.SetGuildAnnouncementExpiry
		) {
			if (!stringField(bag, "AnnouncementId", 1, 64)) return $tuple(false, "invalid announcement id");
			if (
				action === Protocol.Actions.PinGuildAnnouncement &&
				bag.Pinned !== undefined &&
				!typeIs(bag.Pinned, "boolean")
			)
				return $tuple(false, "invalid announcement pin state");
			if (
				action === Protocol.Actions.SetGuildAnnouncementExpiry &&
				bag.ExpiresAt !== undefined &&
				!numberField(bag, "ExpiresAt", 0, 4102444800, true)
			)
				return $tuple(false, "invalid announcement expiry");
		} else if (
			action === Protocol.Actions.MuteGuildMember ||
			action === Protocol.Actions.UnmuteGuildMember ||
			action === Protocol.Actions.BanGuildMember ||
			action === Protocol.Actions.UnbanGuildMember
		) {
			if (!userIdField(bag)) return $tuple(false, "invalid guild moderation target");
		} else if (action === Protocol.Actions.UploadGuildLogo) {
			if (!stringField(bag, "URL", 1, 1024)) return $tuple(false, "invalid guild logo URL");
		} else if (action === Protocol.Actions.ModerateGuildLogo) {
			if (
				!stringField(bag, "LogoId", 1, 64) ||
				(bag.Decision !== "approved" && bag.Decision !== "rejected")
			)
				return $tuple(false, "invalid guild logo decision");
			if (bag.Reason !== undefined && !stringField(bag, "Reason", 1, 500))
				return $tuple(false, "invalid guild logo decision reason");
		} else if (action === Protocol.Actions.GetGuildLeaderboard) {
			if (bag.Page !== undefined && !numberField(bag, "Page", 1, 100, true)) {
				return $tuple(false, "invalid guild leaderboard page");
			}
		} else if (action === Protocol.Actions.GetLeaderboard) {
			const id = typeIs(payload, "table") ? bag.Id : undefined;
			if (
				id !== "Flux" &&
				id !== "Rebirths" &&
				id !== "PlayTime" &&
				id !== "Dust" &&
				id !== "Cores" &&
				id !== "Domain" &&
				id !== "Worlds" &&
				id !== "Crates" &&
				id !== "Finds" &&
				id !== "Ore" &&
				id !== "Wardens" &&
				id !== "Orders" &&
				id !== "Stars" &&
				id !== "Cipher"
			) {
				return $tuple(false, "invalid leaderboard");
			}
		} else if (action === Protocol.Actions.AdminExecute) {
			if (
				!numberField(bag, "TargetUserId", -9007199254740991, 9007199254740991, true) ||
				!stringField(bag, "Command", 1, 48) ||
				!stringField(bag, "Amount", 1, 32) ||
				!stringField(bag, "Nonce", 8, 80) ||
				!stringField(bag, "Reason", 3, 96)
			) {
				return $tuple(false, "invalid admin command envelope");
			}
			if (bag.Option !== undefined && !stringField(bag, "Option", 0, 64)) {
				return $tuple(false, "invalid admin command option");
			}
			if (bag.DryRun !== undefined && !typeIs(bag.DryRun, "boolean")) {
				return $tuple(false, "invalid admin preview flag");
			}
		} else if (action === Protocol.Actions.ReportClientIntegrity) {
			if (!stringField(bag, "ActionType", 1, 48) || !stringField(bag, "PenaltyCode", 1, 48)) {
				return $tuple(false, "invalid integrity envelope");
			}
		}
		return $tuple(true, undefined);
	}

	function processFirewallViolation(
		player: Player,
		actionType: unknown,
		penaltyCode: unknown,
	): LuaTuple<[boolean, string | undefined]> {
		if (player.Parent !== Players) {
			return $tuple(false, "player is not active");
		}
		if (!typeIs(actionType, "string") || !typeIs(penaltyCode, "string")) {
			return $tuple(false, "malformed integrity report");
		}
		const allowedPenalties = CLIENT_SIGNAL_RULES[actionType];
		if (allowedPenalties === undefined || allowedPenalties[penaltyCode] !== true) {
			return $tuple(false, "unknown integrity signature");
		}

		const now = os.clock();
		let record = CLIENT_INTEGRITY_REPORTS.get(player);
		if (record === undefined) {
			record = { Count: 0, LastAt: 0, Kinds: {} };
			CLIENT_INTEGRITY_REPORTS.set(player, record);
		}
		if (now - record.LastAt < 25) {
			return $tuple(false, "integrity report rate exceeded");
		}

		record.LastAt = now;
		record.Count += 1;
		record.Kinds[penaltyCode] = (record.Kinds[penaltyCode] ?? 0) + 1;
		ServerTelemetry.RecordIntegrityReport();
		player.SetAttribute("AF_ClientIntegritySignals", record.Count);
		player.SetAttribute("AF_LastIntegritySignal", penaltyCode);
		ModuleLog.Every(
			string.format("integrity:%d", player.UserId),
			30,
			"Security",
			string.format(
				"%s reported client integrity telemetry %s/%s (%d)",
				player.Name,
				actionType,
				penaltyCode,
				record.Count,
			),
		);
		return $tuple(true, undefined);
	}

	function enforceConfirmedBan(player: Player, proof: unknown): LuaTuple<[boolean, string | undefined]> {
		if (
			!isTable(proof) ||
			proof.ServerConfirmed !== true ||
			!typeIs(proof.CorroboratedSignals, "number") ||
			proof.CorroboratedSignals < 2
		) {
			return $tuple(false, "insufficient server evidence");
		}
		if (!typeIs(proof.Rule, "string") || proof.Rule === "") {
			return $tuple(false, "missing enforcement rule");
		}

		const privateReason = string
			.format(
				"AF security rule %s; signals=%d; user=%d",
				proof.Rule,
				proof.CorroboratedSignals,
				player.UserId,
			)
			.sub(1, 1000);
		const banConfig = {
			UserIds: [player.UserId],
			Duration: -1,
			DisplayReason: "Your account was removed for confirmed exploitation.",
			PrivateReason: privateReason,
			ExcludeAltAccounts: false,
			ApplyToUniverse: true,
			ApplyDeviceBlock: true,
		} as BanAsyncConfig & { ApplyDeviceBlock?: boolean };
		let [success, banError] = pcall(() => {
			Players.BanAsync(banConfig);
		});
		if (!success) {
			delete banConfig.ApplyDeviceBlock;
			[success, banError] = pcall(() => {
				Players.BanAsync(banConfig);
			});
		}
		if (success) {
			return $tuple(true, undefined);
		}

		ModuleLog.Every(
			string.format("ban-failure:%d", player.UserId),
			30,
			"Security",
			string.format("Ban service failed for %s: %s", player.Name, tostring(banError)),
		);
		if (player.Parent === Players) {
			player.Kick("Astral Forge rejected confirmed exploit activity.");
		}
		return $tuple(false, tostring(banError));
	}

	function newBucket(now: number): Bucket {
		return {
			Tokens: 30,
			LastRefill: now,
			LastAction: {},
			LastActionCount: 0,
			Strikes: 0,
			LastStrike: now,
			QuarantineUntil: 0,
			WindowStart: now,
			WindowCount: 0,
			LastRejectedAction: undefined,
		};
	}

	class Firewall {
		private _states = new Map<Player, Bucket>();

		private _strike(player: Player, state: Bucket, reason: string, severity: number): void {
			ServerTelemetry.RecordRemote(false, reason);
			const now = os.clock();
			if (now - state.LastStrike > 18) {
				state.Strikes = math.max(0, state.Strikes - math.floor((now - state.LastStrike) / 18));
			}
			state.LastStrike = now;
			state.Strikes += severity;
			if (state.Strikes >= 4) {
				state.QuarantineUntil = math.max(
					state.QuarantineUntil,
					now + math.min(60, 2 ** math.floor(state.Strikes - 4)),
				);
			}
			player.SetAttribute("AF_RemoteScore", math.floor(state.Strikes));
			if (severity >= 1 || math.floor(state.Strikes) % 3 === 0) {
				const actionLabel = state.LastRejectedAction ?? "?";
				ModuleLog.Every(
					string.format("request:%d:%s", player.UserId, reason),
					8,
					"Requests",
					string.format(
						"%s · %s rejected — %s (score %.1f)",
						player.Name,
						tostring(actionLabel),
						reason,
						state.Strikes,
					),
				);
			}
			if (state.Strikes >= 24 && player.Parent === Players) {
				player.Kick("Astral Forge rejected suspicious remote traffic.");
			}
		}

		Check(player: Player, action: unknown, payload: unknown): LuaTuple<[boolean, string | undefined]> {
			if (RunService.IsStudio()) {
				return $tuple(true, undefined);
			}
			if (player.Parent !== Players) {
				return $tuple(false, "Player is not active.");
			}
			const now = os.clock();
			let state = this._states.get(player);
			if (state === undefined) {
				state = newBucket(now);
				this._states.set(player, state);
			}
			if (!typeIs(action, "string") || ACTIONS[action] !== true) {
				state.LastRejectedAction = tostring(action);
				this._strike(player, state, "unknown action", 2);
				return $tuple(false, "Unknown forge command.");
			}
			if (state.QuarantineUntil > now && action !== Protocol.Actions.GetState) {
				ServerTelemetry.RecordRemote(false, "quarantine");
				return $tuple(false, "Remote traffic paused briefly. Please try again.");
			}
			const [payloadOk, payloadReason] = validateActionPayload(action, payload);
			if (!payloadOk) {
				state.LastRejectedAction = action;
				this._strike(player, state, payloadReason ?? "invalid payload", 1);
				return $tuple(false, payloadReason ?? "That request could not be validated.");
			}
			if (EXEMPT_ACTIONS[action] === true) {
				// Even exempt actions can carry a per-action cooldown to prevent abuse
				// of high-impact actions like Rebirth or daily claims.
				const exemptCooldown = EXEMPT_COOLDOWNS[action];
				if (exemptCooldown !== undefined && exemptCooldown > 0) {
					const actionKey = cooldownKey(action, payload);
					const previous = state.LastAction[actionKey] ?? -math.huge;
					if (now - previous < exemptCooldown) {
						ServerTelemetry.RecordRemote(false, "exempt action cooldown");
						return $tuple(false, "That action is still cooling down.");
					}
					state.LastAction[actionKey] = now;
				}
				ServerTelemetry.RecordRemote(true);
				return $tuple(true, undefined);
			}
			if (now - state.WindowStart >= 2) {
				state.WindowStart = now;
				state.WindowCount = 0;
			}
			state.WindowCount += 1;
			if (state.WindowCount > 48) {
				this._strike(player, state, "request burst", 1);
				return $tuple(false, "Please slow down for a moment.");
			}
			const rule = RULES[action] ?? DEFAULT_RULE;
			const elapsed = math.max(0, now - state.LastRefill);
			state.LastRefill = now;
			state.Tokens = math.min(30, state.Tokens + elapsed * 14);
			const actionKey = cooldownKey(action, payload);
			const previous = state.LastAction[actionKey] ?? -math.huge;
			if (now - previous < rule.Cooldown) {
				ServerTelemetry.RecordRemote(false, "action cooldown");
				return $tuple(false, "That action is still cooling down.");
			}
			if (state.Tokens < rule.Cost) {
				this._strike(player, state, "token budget", 0.5);
				return $tuple(false, "Please slow down for a moment.");
			}
			state.Tokens -= rule.Cost;
			if (state.LastAction[actionKey] === undefined) {
				state.LastActionCount += 1;
			}
			state.LastAction[actionKey] = now;

			if (state.LastActionCount > 256) {
				const retained: { Key: string; At: number }[] = [];
				for (const [key, timestamp] of pairs(state.LastAction)) {
					if (now - timestamp <= 120) {
						retained.push({ Key: key, At: timestamp });
					} else {
						delete state.LastAction[key];
					}
				}
				if (retained.size() > 256) {
					retained.sort((left, right) => left.At > right.At);
					for (let index = 257; index <= retained.size(); index++)
						delete state.LastAction[retained[index - 1].Key];
				}
				state.LastActionCount = math.min(retained.size(), 256);
			}
			ServerTelemetry.RecordRemote(true);
			return $tuple(true, undefined);
		}

		Forget(player: Player): void {
			this._states.delete(player);
			CLIENT_INTEGRITY_REPORTS.delete(player);
		}

		static CoerceUserId = coerceUserId;
		static ExtractUserId = extractUserId;
		static processFirewallViolation = processFirewallViolation;
		static EnforceConfirmedBan = enforceConfirmedBan;
	}

	return Firewall;
};
