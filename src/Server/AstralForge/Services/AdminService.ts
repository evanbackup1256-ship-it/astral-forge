import { Service } from "@flamework/core";
import { Ledger } from "./Security/SecurityLedger";
import { ServerTelemetry } from "./ServerTelemetry";
import { PlayerAnalytics } from "./PlayerAnalytics";
import * as HotFlags from "./Security/HotFlags";
import ProfileIntegrity = require("./Security/ProfileIntegrity");
import * as OpsDashboard from "../Modules/OpsDashboard";
import type { DataService } from "./DataService";
import { ServerEvents } from "../Runtime/ServerNetwork";
import StoreAccess from "../Modules/StoreAccess";
import OpsMath from "../Modules/OpsMath";
import AdminPolicy from "../Modules/AdminPolicy";
import ProfileBagMath from "../Modules/ProfileBagMath";
import DataTemplate from "../DataTemplate";
import CommandMath from "../Modules/CommandMath";
import BazaarMath from "../Modules/BazaarMath";
import ServerConfig from "../ServerConfig";
import Protocol from "../../../Shared/AstralForge/Shared/Protocol";
import OmegaMath from "../../../Shared/AstralForge/Shared/OmegaMath";
import EchoMath from "../../../Shared/AstralForge/Shared/EchoMath";
import AdminCommandSchema from "../../../Shared/AstralForge/Shared/AdminCommandSchema";
import { d, Dict, economyKit, isTable, ModuleLogApi, num, req, truthy } from "./LuaInterop";

// Bag-shaped interfaces for ProfileBagMath.Ensure* returns
interface ItemsBag {
	Pity: Dict;
	Inventory: Dict;
	Equipped: unknown[];
	Essence: number;
	Keys: Dict;
	AutoSalvage?: Dict;
	[key: string]: unknown;
}
interface DomainBag { Essence: number; Rank: number; SkillPoints: number; Nodes: Dict; [key: string]: unknown; }
interface AnomalyBag { Fragments: number; Charge: number; Stabilizations: number; Combo: number; [key: string]: unknown; }
interface ContinuumBag { Rank: number; [key: string]: unknown; }
interface RelicInstance { Locked?: boolean; DefinitionId?: string; [key: string]: unknown; }

interface Omega {
	Add(this: void, left: unknown, right: unknown): unknown;
	Min(this: void, left: unknown, right: unknown): unknown;
	Div(this: void, left: unknown, right: unknown): unknown;
}

interface EconomyApi {
	Capacity(this: void, profile: unknown): unknown;
	Production(this: void, profile: unknown): unknown;
}

interface WheelBag {
	FreeSpins: number;
	LastSpinAt: number;
	[key: string]: unknown;
}
interface WheelApi {
	Ensure(this: void, source: unknown): WheelBag;
}

interface AdminGrantApi {
	DEFAULT_MAX_GRANT: number;
	CommandDanger(this: void, definition?: Record<string, unknown>): string;
	BoundedAmount(this: void, raw: unknown, fallback?: number, maxGrant?: number): number | undefined;
	CleanText(this: void, raw: unknown, maximum: number): string;
	NextRelicUid(this: void, inventory: unknown, nextId: unknown): LuaTuple<[string | undefined, number]>;
	BuildRelicInstance(this: void, definitionId: unknown, acquiredAt: unknown): Record<string, unknown> | undefined;
	AUDIT_ONLY_REASONS: Record<string, boolean>;
	PlayerFacingReason(this: void, command: unknown, reason: unknown, auditOnly?: Record<string, boolean>): string;
}

interface TelemetryApi {
	Snapshot(this: void): unknown;
}

interface DataApi {
	Get(this: DataApi, player: Player): Dict | undefined;
	GetRevision(this: DataApi, player: Player): number;
	GetIntegrityStatus(this: DataApi, player: Player): unknown;
	Save(this: DataApi, player: Player, releaseSession?: boolean): boolean;
	AtomicUpdate(
		this: DataApi,
		player: Player,
		callback: (this: void, draft: Dict, revision: number) => unknown,
		incrementRevision?: boolean,
		label?: string,
	): LuaTuple<[boolean, unknown]>;
}

interface QueuePageEntry {
	KeyName: string;
}
interface QueuePages {
	readonly IsFinished: boolean;
	GetCurrentPage(): QueuePageEntry[];
	AdvanceToNextPageAsync(): void;
}
interface AdminStore {
	ListKeysAsync(prefix?: string): unknown;
	GetAsync(key: string): unknown;
	RemoveAsync(key: string): unknown;
	UpdateAsync(key: string, transform: (previous: unknown) => unknown): unknown;
}

type CommandDef = {
	Label: string;
	Option: boolean;
	Category: string;
	Danger?: string;
	World?: boolean;
	Moderation?: boolean;
	// runs once for the whole experience instead of on a target player
	Global?: boolean;
};

type HandlerResult = Dict;
type ProfileHandler = (profile: Dict, amount: number, option: string) => HandlerResult;

interface BazaarBag {
	Counters: { Deals: number; [key: string]: unknown };
	Market: {
		Bucket: number;
		Bought: Dict;
		Procure: { Id: string; Since: number; Filled: number };
		History: Dict[];
		[key: string]: unknown;
	};
	[key: string]: unknown;
}

interface Subject {
	UserId: number;
	Name: string;
}

const Players = game.GetService("Players");
const MessagingService = game.GetService("MessagingService");
// cross-server admin topic: { Kind = "Announce" | "HotFlag", ... }; MessagingService caps a message at 1 kB
const LIVE_OPS_TOPIC = "AstralForge_AdminLiveOps_v1";
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");

const GameConfig = req<Dict>(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("GameConfig"));
const Omega: Omega = OmegaMath;
const Economy = economyKit("Economy") as EconomyApi;
const AdminGrantMath = OpsMath("AdminGrantMath") as AdminGrantApi;
const WheelMath = economyKit("WheelMath") as WheelApi;
const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));

// Queue entries are unsigned, so only explicitly configured external moderator identities are trusted.
const DiscordModeratorIds: Record<number, boolean> = {
	100000001: true,
	100000002: true,
	100000003: true,
};

const CommandSchema = AdminCommandSchema;
const MAX_AUDIT_MEMORY = 40;
const MAX_AUDIT_PERSISTED = 100;
const NONCE_TTL = 300;

const COMMANDS: Record<string, CommandDef> = table.freeze({
	SetFlux: { Label: "Set current Flux", Option: false, Category: "Economy" },
	SetVault: { Label: "Set stored vault Flux", Option: false, Category: "Economy" },
	SetContinuumRank: { Label: "Set Continuum rank", Option: false, Category: "Progress" },
	SetFreeSpins: { Label: "Set free wheel spins", Option: false, Category: "Items" },
	ResetAnomalyCharge: { Label: "Reset current shift charge", Option: false, Category: "Resets" },
	ClearAnomalyCombo: { Label: "Clear shift combo", Option: false, Category: "Resets" },

	GrantFlux: { Label: "Grant Flux", Option: false, Category: "Economy" },
	GrantCores: { Label: "Grant astral cores", Option: false, Category: "Economy" },
	GrantStardust: { Label: "Grant Stardust", Option: false, Category: "Economy" },
	GrantRebirths: { Label: "Grant rebirths", Option: false, Category: "Progress" },
	GrantDomainEssence: { Label: "Grant domain essence", Option: false, Category: "Progress" },
	GrantAnomalyFragments: { Label: "Grant reactor fragments", Option: false, Category: "Progress" },
	GrantSignals: { Label: "Grant command signals", Option: false, Category: "Progress" },
	GrantCommandXP: { Label: "Grant command XP", Option: false, Category: "Progress" },
	GrantSeasonXP: { Label: "Grant season XP", Option: false, Category: "Progress" },
	GrantStreakShields: { Label: "Grant streak shields", Option: false, Category: "Progress" },
	GrantItemEssence: { Label: "Grant relic essence", Option: false, Category: "Items" },
	GrantContinuumRanks: { Label: "Grant Continuum ranks", Option: false, Category: "Progress" },
	GrantAnomalyCharge: { Label: "Grant reactor charge", Option: false, Category: "Progress" },
	GrantAnomalyStabilizations: { Label: "Grant reactor stabilizations", Option: false, Category: "Progress" },
	GrantShards: { Label: "Grant Star Foundry shards", Option: false, Category: "Progress" },
	SetFoundryRadius: { Label: "Set Foundry board radius", Option: false, Category: "Progress" },
	GrantFoundryPiece: { Label: "Grant Foundry piece", Option: true, Category: "Progress" },
	GrantFreeSpins: { Label: "Grant wheel spins", Option: false, Category: "Items" },
	GrantCrateKeys: { Label: "Grant crate keys", Option: true, Category: "Items" },
	GrantAllCrateKeys: { Label: "Grant every crate key", Option: false, Category: "Items" },
	GrantPity: { Label: "Grant crate pity", Option: true, Category: "Items" },
	GrantBoost: { Label: "Grant boost", Option: true, Category: "Items" },
	GrantAllBoosts: { Label: "Grant every boost", Option: false, Category: "Items" },
	GrantRelic: { Label: "Grant exact relic", Option: true, Category: "Items" },
	ClearActiveBoost: { Label: "Clear active boost", Option: false, Category: "Items" },
	ResetWheelCooldown: { Label: "Reset wheel cooldown", Option: false, Category: "Resets" },
	ResetDailyClaim: { Label: "Reset daily claim", Option: false, Category: "Resets" },
	ClearVault: { Label: "Clear vault", Option: false, Category: "Resets" },
	SetZone: { Label: "Set unlocked zone", Option: false, Category: "Progress" },
	EnableUnlimitedFlux: { Label: "Enable unlimited Flux", Option: false, Category: "Economy" },
	DisableUnlimitedFlux: { Label: "Disable unlimited Flux", Option: false, Category: "Economy" },
	UnlockProgression: { Label: "Unlock progression", Option: false, Category: "Progress" },
	ResetTutorial: { Label: "Reset tutorial", Option: false, Category: "Resets" },
	ResetSettings: { Label: "Restore settings defaults", Option: false, Category: "Resets" },
	ShowUpdates: { Label: "Show updates again", Option: false, Category: "Resets" },
	GrantEverything: { Label: "Owner grant bundle", Option: false, Category: "Economy" },
	WipeFlux: { Label: "Wipe Flux", Option: false, Category: "Resets" },
	WipeVault: { Label: "Wipe vault", Option: false, Category: "Resets" },
	WipeCores: { Label: "Wipe cores", Option: false, Category: "Resets" },
	WipeStardust: { Label: "Wipe Stardust", Option: false, Category: "Resets" },
	SetDomainEssence: { Label: "Set domain essence", Option: false, Category: "Progress" },
	SetItemEssence: { Label: "Set relic essence", Option: false, Category: "Items" },
	SetSignals: { Label: "Set command signals", Option: false, Category: "Progress" },
	SetSeasonXP: { Label: "Set season XP", Option: false, Category: "Progress" },
	SetStreakShields: { Label: "Set streak shields", Option: false, Category: "Progress" },
	SetAnomalyFragments: { Label: "Set reactor fragments", Option: false, Category: "Progress" },
	GrantVaultFlux: { Label: "Grant Flux into vault", Option: false, Category: "Economy" },
	DoubleFlux: { Label: "Double current Flux", Option: false, Category: "Economy" },
	BankVault: { Label: "Move vault into wallet", Option: false, Category: "Economy" },
	WipeItemEssence: { Label: "Wipe relic essence", Option: false, Category: "Resets" },
	ResetPityAll: { Label: "Reset pity on every crate", Option: false, Category: "Resets" },
	ResetCommandXP: { Label: "Reset command XP", Option: false, Category: "Resets" },
	PennyPinch: { Label: "Set Flux to 1", Option: false, Category: "Troll" },
	TaxHalf: { Label: "Tax half their Flux", Option: false, Category: "Troll" },
	SwapWallet: { Label: "Swap cash and vault", Option: false, Category: "Troll" },
	FillVault: { Label: "Fill vault to cap", Option: false, Category: "Economy" },
	DrainKeys: { Label: "Drain all crate keys", Option: false, Category: "Troll" },
	DrainBoosts: { Label: "Drain all boosts", Option: false, Category: "Troll" },
	LockRelics: { Label: "Protect every relic", Option: false, Category: "Items" },
	UnlockRelics: { Label: "Unprotect every relic", Option: false, Category: "Items" },
	SalvageRelics: { Label: "Salvage unlocked relics", Option: false, Category: "Troll" },
	SetRebirths: { Label: "Set rebirth count", Option: false, Category: "Progress" },
	SetCores: { Label: "Set core count", Option: false, Category: "Economy" },
	SetStardust: { Label: "Set Stardust count", Option: false, Category: "Economy" },
	SetDomainRank: { Label: "Set domain rank", Option: false, Category: "Progress" },
	GrantSkillPoints: { Label: "Grant domain skill points", Option: false, Category: "Progress" },
	ResetDomain: { Label: "Reset domain tree", Option: false, Category: "Resets" },
	MaxMachines: { Label: "Max every machine", Option: false, Category: "Progress" },
	ResetMachines: { Label: "Reset every machine", Option: false, Category: "Resets" },
	MaxResearch: { Label: "Max every research", Option: false, Category: "Progress" },
	ResetResearch: { Label: "Reset every research", Option: false, Category: "Resets" },
	MaxGrid: { Label: "Max legacy foundations", Option: false, Category: "Progress" },
	ResetGrid: { Label: "Reset legacy foundations", Option: false, Category: "Resets" },
	FillPityAll: { Label: "Max pity on every crate", Option: false, Category: "Items" },
	ResetTrades: { Label: "Reset daily trades", Option: false, Category: "Resets" },
	ResetDailies: { Label: "Reset all daily clocks", Option: false, Category: "Resets" },
	ZeroZone: { Label: "Kick back to world 1", Option: false, Category: "Troll" },
	GrantEchoCharge: { Label: "Grant echo charge", Option: false, Category: "Progress" },
	MaxCrew: { Label: "Max command crew", Option: false, Category: "Progress" },
	DiscoverArts: { Label: "Discover every artifact", Option: false, Category: "Items" },
	InspectMarket: { Label: "Inspect Black Market", Option: false, Category: "Economy", Danger: "quick" },
	ResetMarketPurchases: { Label: "Reset market shelf purchases", Option: false, Category: "Resets" },
	CancelMarketRequest: { Label: "Cancel market supply request", Option: false, Category: "Resets" },
	Blind: { Label: "Lights out overlay", Option: false, Category: "Troll", World: true },
	Jumpscare: { Label: "Jumpscare card", Option: false, Category: "Troll", World: true },
	InvertHud: { Label: "Invert their HUD", Option: false, Category: "Troll", World: true },
	SpinHud: { Label: "Spin their HUD", Option: false, Category: "Troll", World: true },
	TinyHud: { Label: "Shrink their HUD", Option: false, Category: "Troll", World: true },
	GiantHud: { Label: "Blow up their HUD", Option: false, Category: "Troll", World: true },
	JumbleHud: { Label: "Jumble the HUD", Option: false, Category: "Troll", World: true },
	ShakeHud: { Label: "Shake the shell", Option: false, Category: "Troll", World: true },
	DiscoHud: { Label: "Disco HUD", Option: false, Category: "Troll", World: true },
	RainbowHud: { Label: "Rainbow wash", Option: false, Category: "Troll", World: true },
	ConfettiStorm: { Label: "Confetti tax overlay", Option: false, Category: "Troll", World: true },
	FakeRareDrop: { Label: "Fake celestial relic drop", Option: false, Category: "Troll", World: true },
	FakeEvent: { Label: "False starfall alert", Option: false, Category: "Troll", World: true },
	FakeRebirth: { Label: "Fake rebirth prompt", Option: false, Category: "Troll", World: true },
	FakeTrade: { Label: "Fake incoming trade", Option: false, Category: "Troll", World: true },
	FakeRob: { Label: "Fake wallet hack", Option: false, Category: "Troll", World: true },
	ClownTitle: { Label: "Clown title splash", Option: true, Category: "Troll", World: true },
	Honk: { Label: "Honk toast", Option: false, Category: "Troll", World: true },
	MuteToasts: { Label: "Fake error toasts", Option: false, Category: "Troll", World: true },
	EmptyBagScare: { Label: "Fake empty bag", Option: false, Category: "Troll", World: true },
	Kick: { Label: "Kick from this server", Option: false, Category: "Moderation", Moderation: true },
	ServerBan: { Label: "Ban from this server", Option: false, Category: "Moderation", Moderation: true },
	GlobalBan: { Label: "Ban from the experience", Option: false, Category: "Moderation", Moderation: true },
	Unban: { Label: "Remove ban", Option: false, Category: "Moderation", Moderation: true },
	InspectPlayer: { Label: "Look up security flags and journal", Option: false, Category: "Moderation", Danger: "quick" },
	RollbackCritical: { Label: "Roll back to a journal entry (Option = entry id)", Option: true, Category: "Resets" },
	Announce: { Label: "Announce to every server", Option: true, Category: "LiveOps", Global: true },
	ToggleHotFlag: { Label: "Live-ops flag (Option = Name=on|off)", Option: true, Category: "LiveOps", Global: true },
});
const CATEGORY_RANK: Record<string, number> = { Economy: 1, Progress: 2, Items: 3, Resets: 4, Troll: 5, Moderation: 6, LiveOps: 7 };

function commandDanger(definition: Record<string, unknown>): string {
	if (string.sub((definition.Label as string) ?? "", 1, 4) === "Set ") return "arm";
	return AdminGrantMath.CommandDanger(definition);
}

function cleanText(raw: unknown, maximum: number): string {
	return AdminGrantMath.CleanText(raw, maximum);
}

function onlinePlayer(userId: unknown): Player | undefined {
	const id = tonumber(userId);
	if (id === undefined || id !== math.floor(id)) return undefined;
	return Players.GetPlayerByUserId(id);
}

function roleFor(player: Player): string | undefined {
	const configured = (ServerConfig.AdminUserIds as unknown as Record<number, string | undefined>)[player.UserId];
	if (typeIs(configured, "string") && configured !== "") return configured;
	if (RunService.IsStudio() && ServerConfig.AllowStudioAdmins === true) return "Studio Developer";
	return undefined;
}

function createRelic(profile: Dict, definitionId: string): boolean {
	let definition: Dict | undefined;
	for (const candidate of d(GameConfig.Items).Definitions as unknown[]) {
		const candidateDef = candidate as Dict;
		if (candidateDef.Id === definitionId) {
			definition = candidateDef;
			break;
		}
	}
	if (definition === undefined) return false;
	const items = ProfileBagMath.EnsureItems(profile);
	let count = 0;
	for (const _ of pairs(d(items.Inventory))) count += 1;
	if (count >= (d(GameConfig.Items).InventoryLimit as number)) return false;
	const [uid, nextId] = AdminGrantMath.NextRelicUid(items.Inventory, items.NextId);
	if (uid === undefined) return false;
	const instance = AdminGrantMath.BuildRelicInstance(definition.Id, os.time());
	if (instance === undefined) return false;
	items.NextId = nextId;
	d(items.Inventory)[uid] = instance;
	ProfileBagMath.BumpStat(profile, "ItemsFound", 1);
	return true;
}

function firePrank(player: Player, kind: string, duration: number, caption: string) {
	ServerEvents.effect.fire(player, { Type: "AdminPrank", Kind: kind, Duration: duration, Caption: caption });
}

function applyWorld(_actor: Player, target: Player, command: string, amount: number, option: string): LuaTuple<[boolean, string]> {
	const duration = math.clamp(math.floor(amount), 3, 20);
	if (command === "Honk") {
		ServerEvents.toast.fire(target, { Title: "HONK", Body: "An admin honked at you.", Tone: "Special" });
		return $tuple(true, "Honked at " + target.Name);
	}
	let caption = option;
	if (command === "FakeRareDrop") {
		caption = "Astra Prism";
	} else if (command === "FakeEvent") {
		caption = "Starfall signatures are converging above the forge.";
	} else if (command === "JumbleHud") {
		caption = "The forge instruments slipped out of alignment.";
	}
	firePrank(target, command, duration, caption);
	return $tuple(true, string.format("%s in-game prank on %s for %ds.", command, target.Name, duration));
}

@Service({ loadOrder: 3 })
export class AdminService {
	static DiscordModeratorIds = DiscordModeratorIds;

	private _data: DataApi;
	private _audit: Dict[] = [];
	private _nonces: Map<number, Record<string, number>> = new Map();
	private _lastByActor: Map<number, Dict> | undefined = new Map();
	private _alive = true;
	private _workers: Map<object, thread> = new Map();
	private _serverBans: Map<number, Dict> = new Map();
	private _banLog: Map<number, Dict> = new Map();
	private _auditStore!: AdminStore;
	private _discordQueueStore!: AdminStore;
	private _discordSeenIds: Map<string, boolean> = new Map();
	private _playerAdded: RBXScriptConnection | undefined;
	private _discordQueueWorker: thread | undefined;

	private _liveOpsConnection: RBXScriptConnection | undefined;
	private _announcements: Dict[] = [];

	constructor(
		private readonly telemetry: ServerTelemetry,
		dataService: DataService,
		private readonly analytics: PlayerAnalytics,
	) {
		this._data = dataService as unknown as DataApi;
	}

	// Runs from the server runtime's "administration construction" boot step.
	build() {
		this._auditStore = StoreAccess.data(ServerConfig.AdminAuditStoreName) as AdminStore;
		this._discordQueueStore = StoreAccess.data(ServerConfig.DiscordModQueueStoreName) as AdminStore;
		this._playerAdded = Players.PlayerAdded.Connect((player) => {
			this.EnforceServerBan(player);
		});
		for (const player of Players.GetPlayers()) {
			this.EnforceServerBan(player);
		}
		task.spawn(() => {
			const [ok, connection] = pcall(() =>
				MessagingService.SubscribeAsync(LIVE_OPS_TOPIC, (envelope) => {
					this.ReceiveLiveOps(typeIs(envelope, "table") ? (envelope as Dict).Data : undefined);
				}),
			);
			if (ok && this._alive) {
				this._liveOpsConnection = connection as RBXScriptConnection;
			} else if (ok) {
				(connection as RBXScriptConnection).Disconnect();
			} else {
				ModuleLog.Warn("Admin", "live-ops topic subscribe failed: " + tostring(connection));
			}
		});
		this._discordQueueWorker = task.spawn(() => {
			while (this._alive) {
				task.wait(ServerConfig.DiscordModQueuePollSeconds);
				if (!this._alive) break;
				const [ok, err] = pcall(() => {
					this._pollDiscordQueue();
				});
				if (!ok) {
					ModuleLog.Every("discord-queue-poll", 60, "Admin", "Discord mod queue poll crashed: " + tostring(err));
				}
			}
		});
	}

	private _pollDiscordQueue() {
		let pages: QueuePages | undefined;
		const [listOk, listErr] = pcall(() => {
			pages = this._discordQueueStore.ListKeysAsync(ServerConfig.DiscordModQueuePrefix) as QueuePages;
		});
		if (!listOk) {
			ModuleLog.Every("discord-queue-list", 60, "Admin", "Discord mod queue list failed: " + tostring(listErr));
			return;
		}
		while (true) {
			const [itemsOk, items] = pcall(() => pages!.GetCurrentPage());
			if (!itemsOk || !typeIs(items, "table")) {
				break;
			}
			for (const item of items) {
				const key = item.KeyName;
				if (this._discordSeenIds.get(key) !== true) {
					this._discordSeenIds.set(key, true);
					this._claimDiscordEntry(key);
				}
			}
			if (pages!.IsFinished) break;
			const [advanceOk, advanceErr] = pcall(() => pages!.AdvanceToNextPageAsync());
			if (!advanceOk) {
				ModuleLog.Every("discord-queue-page", 60, "Admin", "Discord mod queue page advance failed: " + tostring(advanceErr));
				break;
			}
		}
	}

	private _claimDiscordEntry(key: string) {
		let entry: unknown;
		const [getOk, getErr] = pcall(() => {
			entry = this._discordQueueStore.GetAsync(key);
		});
		if (!getOk) {
			this._discordSeenIds.delete(key);
			ModuleLog.Every("discord-queue-get:" + key, 60, "Admin", "Discord mod queue read failed: " + tostring(getErr));
			return;
		}
		if (!isTable(entry)) return;
		const [removed, removeErr] = pcall(() => {
			this._discordQueueStore.RemoveAsync(key);
		});
		if (!removed) {
			this._discordSeenIds.delete(key);
			ModuleLog.Every("discord-queue-remove:" + key, 60, "Admin", "Discord mod queue remove failed: " + tostring(removeErr));
			return;
		}
		this._executeDiscordAction(entry);
	}

	private _executeDiscordAction(entry: Dict) {
		const moderatorId = tonumber(entry.ModeratorId);
		if (
			!typeIs(moderatorId, "number") ||
			moderatorId !== moderatorId ||
			moderatorId <= 0 ||
			moderatorId !== math.floor(moderatorId) ||
			DiscordModeratorIds[moderatorId] !== true
		) {
			// Drop unsigned/untrusted queue entries before any moderation side effect can occur.
			ModuleLog.Warn("Admin", "Dropped Discord moderation entry with an unauthorized ModeratorId");
			return;
		}
		const action = entry.Action;
		let userId = tonumber(entry.UserId);
		if (!typeIs(action, "string") || !typeIs(userId, "number")) return;
		userId = math.floor(userId);
		const reason = typeIs(entry.Reason, "string") && entry.Reason !== "" ? entry.Reason : "Moderated via Discord.";
		const moderator = typeIs(entry.Moderator, "string") ? entry.Moderator : "Discord staff";
		const subject: Subject = { UserId: userId, Name: tostring(userId) };
		const target = Players.GetPlayerByUserId(userId);
		if (target !== undefined) subject.Name = target.Name;

		if (action === "Kick") {
			if (target !== undefined && target.Parent === Players) {
				target.Kick(string.format("Kicked by %s: %s", moderator, reason));
				this._record({ Name: "Discord:" + moderator, UserId: 0 } as unknown as Player, subject, "DiscordKick", 0, "", reason, 0);
			}
			return;
		}

		if (action === "Ban") {
			const durationSeconds = tonumber(entry.DurationSeconds);
			const permanent = entry.DurationSeconds === undefined || durationSeconds === undefined || durationSeconds <= 0;
			const duration = permanent ? -1 : math.max(60, math.floor(durationSeconds!));
			const displayReason = string.sub(string.format("Banned by %s: %s", moderator, reason), 1, 400);
			const [banOk, banError] = pcall(() => {
				Players.BanAsync({
					UserIds: [userId],
					Duration: duration,
					DisplayReason: displayReason,
					PrivateReason: string.sub(string.format("Discord ban by %s: %s", moderator, reason), 1, 1000),
					ExcludeAltAccounts: false,
					ApplyToUniverse: true,
				});
			});
			const untilTime = permanent ? -1 : os.time() + duration;
			this._banLog.set(userId, { Name: subject.Name, Scope: "Global", Until: untilTime, Reason: displayReason });
			if (!banOk) {
				ModuleLog.Warn("Admin", "Discord BanAsync failed: " + tostring(banError));
				this._serverBans.set(userId, {
					Name: subject.Name,
					Scope: "Server",
					Until: untilTime === -1 ? 0 : untilTime,
					Reason: displayReason,
				});
			}
			if (target !== undefined && target.Parent === Players) {
				target.Kick(displayReason);
			}
			this._record(
				{ Name: "Discord:" + moderator, UserId: 0 } as unknown as Player,
				subject,
				"DiscordBan",
				permanent ? 0 : duration,
				"",
				reason,
				0,
			);
			return;
		}

		if (action === "Unban") {
			this._serverBans.delete(userId);
			this._banLog.delete(userId);
			const [unbanOk, unbanError] = pcall(() => {
				Players.UnbanAsync({ UserIds: [userId], ApplyToUniverse: true });
			});
			if (!unbanOk) {
				ModuleLog.Warn("Admin", "Discord UnbanAsync failed: " + tostring(unbanError));
			}
			this._record({ Name: "Discord:" + moderator, UserId: 0 } as unknown as Player, subject, "DiscordUnban", 0, "", reason, 0);
		}
	}

	HasAccess(player: Player): boolean {
		return roleFor(player) !== undefined;
	}

	Forget(player: Player) {
		this._nonces.delete(player.UserId);
		if (this._lastByActor !== undefined) {
			this._lastByActor.delete(player.UserId);
		}
	}

	private _consumeNonce(actor: Player, nonce: string): boolean {
		const now = os.time();
		const bucket = this._nonces.get(actor.UserId) ?? {};
		this._nonces.set(actor.UserId, bucket);
		for (const [id, expiresAt] of pairs(bucket)) if (expiresAt <= now) bucket[id] = undefined!;
		if (bucket[nonce] !== undefined) return false;
		bucket[nonce] = now + NONCE_TTL;
		return true;
	}

	EnforceServerBan(player: Player): boolean {
		const record = this._serverBans.get(player.UserId);
		if (record === undefined) {
			return false;
		}
		const banUntil = num(record.Until);
		if (banUntil !== undefined && banUntil > 0 && banUntil <= os.time()) {
			this._serverBans.delete(player.UserId);
			return false;
		}
		player.Kick(record.Reason !== "" ? (record.Reason as string) : "You are banned from this server.");
		return true;
	}

	private _record(
		actor: Player,
		target: Subject,
		command: string,
		amount: number | undefined,
		option: string,
		reason: string,
		revision: number,
	) {
		const entry = {
			Id: string.format("%s:%d:%d:%d:%d", game.JobId, actor.UserId, target.UserId, revision, os.time()),
			At: os.time(),
			ActorUserId: actor.UserId,
			ActorName: actor.Name,
			TargetUserId: target.UserId,
			TargetName: target.Name,
			Command: command,
			Amount: amount ?? 0,
			Option: option,
			Reason: reason,
			Revision: revision,
			JobId: game.JobId,
		};
		this._audit.unshift(entry);
		while (this._audit.size() > MAX_AUDIT_MEMORY) this._audit.pop();
		ModuleLog.Info("Admin", string.format("%s -> %s: %s (%s)", actor.Name, target.Name, command, reason));
		if (!this._alive) return;
		const token = {};
		const worker = task.defer(() => {
			if (!this._alive) {
				this._workers.delete(token);
				return;
			}
			const [ok, err] = pcall(() => {
				this._auditStore.UpdateAsync("Recent", (previous) => {
					const records = typeIs(previous, "table") ? (previous as Dict[]) : [];
					records.unshift(entry);
					while (records.size() > MAX_AUDIT_PERSISTED) records.pop();
					return records;
				});
			});
			if (!ok) ModuleLog.Warn("Admin", "couldn't write the audit log: " + tostring(err));
			this._workers.delete(token);
		});
		this._workers.set(token, worker);
	}

	Destroy() {
		this._alive = false;
		if (this._liveOpsConnection !== undefined) {
			this._liveOpsConnection.Disconnect();
			this._liveOpsConnection = undefined;
		}
		if (this._playerAdded !== undefined) {
			this._playerAdded.Disconnect();
			this._playerAdded = undefined;
		}
		if (this._discordQueueWorker !== undefined) {
			task.cancel(this._discordQueueWorker);
			this._discordQueueWorker = undefined;
		}
		for (const [token, worker] of this._workers) {
			task.cancel(worker);
			this._workers.delete(token);
		}
		this._nonces.clear();
		if (this._lastByActor !== undefined) {
			this._lastByActor.clear();
		}
		this._serverBans.clear();
		this._banLog.clear();
		this._discordSeenIds.clear();
	}

	State(viewer: Player): Dict {
		const role = roleFor(viewer);
		if (role === undefined) return { Access: false };
		const online: Dict[] = [];
		for (const player of Players.GetPlayers()) {
			const profile = this._data.Get(player);
			if (profile !== undefined) {
				let keys = 0;
				let relics = 0;
				let boosts = 0;
				let essence = 0;
				if (typeIs(profile.Items, "table")) {
					const items = profile.Items as Dict;
					essence = num(items.Essence) ?? 0;
					if (typeIs(items.Keys, "table")) {
						for (const [, count] of pairs(items.Keys as Record<string, number>)) {
							if (typeIs(count, "number")) {
								keys += count;
							}
						}
					}
					if (typeIs(items.Inventory, "table")) {
						for (const _ of pairs(items.Inventory as object)) {
							relics += 1;
						}
					}
				}
				if (typeIs(profile.BoostInventory, "table")) {
					for (const [, count] of pairs(profile.BoostInventory as Record<string, number>)) {
						if (typeIs(count, "number")) {
							boosts += count;
						}
					}
				}
				online.push({
					UserId: player.UserId,
					Name: player.Name,
					DisplayName: player.DisplayName,
					Cash: profile.Cash,
					Vault: profile.Vault,
					Capacity: Economy.Capacity(profile),
					Cores: profile.Cores,
					Rebirths: profile.Rebirths,
					Zone: profile.Zone,
					CurrentZone: profile.CurrentZone,
					Production: Economy.Production(profile),
					Stardust: profile.Stardust,
					Essence: essence,
					Keys: keys,
					Relics: relics,
					Boosts: boosts,
					Unlimited: typeIs(profile.Flags, "table") && (profile.Flags as Dict).UnlimitedMoney === true,
				});
			}
		}
		online.sort((left, right) => (left.Name as string) < (right.Name as string));
		const commands: Dict[] = [];
		for (const [id, definition] of pairs(COMMANDS)) {
			const [allowed] = AdminPolicy.Allows(role, id, definition);
			if (!allowed) {
				continue;
			}
			commands.push({
				Id: id,
				Label: definition.Label,
				Input: CommandSchema.describe(id, definition),
				NeedsOption: definition.Option === true,
				Category: definition.Category ?? "Economy",
				Danger: commandDanger(definition),
				World: definition.World === true,
			});
		}
		commands.sort((left, right) => {
			const leftRank = CATEGORY_RANK[left.Category as string] ?? 9;
			const rightRank = CATEGORY_RANK[right.Category as string] ?? 9;
			if (leftRank !== rightRank) return leftRank < rightRank;
			return (left.Label as string) < (right.Label as string);
		});
		const audit: Dict[] = [];
		for (const index of $range(1, math.min(12, this._audit.size()))) audit[index - 1] = this._audit[index - 1];
		const banned: Dict[] = [];
		const seenBan: Record<number, boolean> = {};
		const pushBan = (userId: number, record: Dict | undefined) => {
			if (seenBan[userId] === true || !typeIs(record, "table")) return;
			const banUntil = num(record.Until);
			if (banUntil !== undefined && banUntil > 0 && banUntil <= os.time()) return;
			seenBan[userId] = true;
			banned.push({
				UserId: userId,
				Name: record.Name ?? tostring(userId),
				Scope: record.Scope ?? "Server",
				Until: record.Until ?? 0,
				Reason: record.Reason ?? "",
			});
		};
		for (const [userId, record] of this._serverBans) pushBan(userId, record);
		for (const [userId, record] of this._banLog) pushBan(userId, record);
		banned.sort((left, right) => (left.Name as string) < (right.Name as string));
		return {
			Access: true,
			Role: role,
			SelfUserId: viewer.UserId,
			Online: online,
			Commands: commands,
			Recent: audit,
			Banned: banned,
			LastAction: this._lastByActor !== undefined ? this._lastByActor.get(viewer.UserId) : undefined,
			Integrity: this._data.GetIntegrityStatus(viewer),
			Telemetry: this.telemetry.Snapshot(),
			// newest first: { At, UserId, Name, Kind, Weight, Score, Response, Detail }
			SecurityFlags: Ledger.Recent(25),
			// one row per flagged player, highest live score first (drill in with InspectPlayer)
			SecurityPlayers: Ledger.Summary(25),
			HotFlags: HotFlags.Snapshot(),
			Announcements: this._announcements,
			Economy: this._dashboard(),
		};
	}

	private _moderate(
		actor: Player,
		command: string,
		targetUserId: number,
		amountRaw: unknown,
		option: string,
		reason: string,
	): Dict {
		const target = Players.GetPlayerByUserId(targetUserId);
		const listed = this._serverBans.get(targetUserId) ?? this._banLog.get(targetUserId);
		const targetName = (target !== undefined ? target.Name : undefined) ?? (listed?.Name as string | undefined) ?? tostring(targetUserId);
		const subject: Subject = { UserId: targetUserId, Name: targetName };
		if (target !== undefined && roleFor(target) !== undefined && target !== actor) {
			return { ok: false, error: "Cannot moderate another administrator." };
		}

		if (command === "Unban") {
			this._serverBans.delete(targetUserId);
			this._banLog.delete(targetUserId);
			const [unbanOk, unbanError] = pcall(() => {
				Players.UnbanAsync({
					UserIds: [targetUserId],
					ApplyToUniverse: true,
				});
			});
			if (!unbanOk) {
				ModuleLog.Warn("Admin", "UnbanAsync failed: " + tostring(unbanError));
			}
			this._record(actor, subject, command, 0, option, reason, 0);
			return {
				ok: true,
				message: string.format("Cleared bans for %s%s.", targetName, unbanOk ? "" : " (experience ban service unavailable)"),
				Admin: this.State(actor),
				TargetUserId: targetUserId,
				Persisted: true,
			};
		}

		if (target === undefined || target.Parent !== Players) {
			return { ok: false, error: "Target must be online in this server." };
		}

		if (command === "Kick") {
			const kickMessage = playerFacingReason(command, reason);
			this._record(actor, subject, command, 0, option, reason, this._data.GetRevision(target) ?? 0);
			target.Kick(kickMessage);
			return {
				ok: true,
				message: string.format("Kicked %s.", targetName),
				Admin: this.State(actor),
				TargetUserId: targetUserId,
				Persisted: true,
			};
		}

		let seconds = tonumber(amountRaw);
		if (seconds === undefined) seconds = 0;
		if (command === "ServerBan") {
			const untilTime = seconds <= 0 ? 0 : os.time() + math.max(60, math.floor(seconds));
			const kickMessage = playerFacingReason(command, reason);
			const record = { Name: targetName, Scope: "Server", Until: untilTime, Reason: kickMessage };
			this._serverBans.set(targetUserId, record);
			this._banLog.set(targetUserId, record);
			this._record(actor, subject, command, math.max(0, math.floor(seconds)), option, reason, this._data.GetRevision(target) ?? 0);
			target.Kick(kickMessage);
			return {
				ok: true,
				message: string.format("Server-banned %s%s.", targetName, untilTime === 0 ? " for this session" : ""),
				Admin: this.State(actor),
				TargetUserId: targetUserId,
				Persisted: true,
			};
		}

		if (command === "GlobalBan") {
			if (target === actor) {
				return { ok: false, error: "Do not globally ban yourself." };
			}
			const permanent = option === "Permanent" || seconds < 0;
			const duration = permanent ? -1 : math.max(60, math.floor(seconds));
			const displayReason = string.sub(playerFacingReason(command, reason), 1, 400);
			const banConfig: BanAsyncConfig = {
				UserIds: [targetUserId],
				Duration: duration,
				DisplayReason: displayReason,
				PrivateReason: string.sub(string.format("%s banned %s: %s", actor.Name, targetName, reason), 1, 1000),
				ExcludeAltAccounts: false,
				ApplyToUniverse: true,
			};
			const [banOk, banError] = pcall(() => {
				Players.BanAsync(banConfig);
			});
			const untilTime = permanent ? -1 : os.time() + duration;
			this._banLog.set(targetUserId, { Name: targetName, Scope: "Global", Until: untilTime, Reason: displayReason });
			if (!banOk) {
				this._serverBans.set(targetUserId, {
					Name: targetName,
					Scope: "Server",
					Until: untilTime === -1 ? 0 : untilTime,
					Reason: displayReason,
				});
				ModuleLog.Warn("Admin", "BanAsync failed: " + tostring(banError));
				if (target.Parent === Players) {
					target.Kick(displayReason);
				}
			}
			this._record(actor, subject, command, permanent ? 0 : duration, option, reason, this._data.GetRevision(target) ?? 0);
			return {
				ok: true,
				message: string.format(
					"%s globally banned %s%s.",
					banOk ? "Issued" : "Queued (service failed; kicked this server)",
					targetName,
					permanent ? " permanently" : "",
				),
				Admin: this.State(actor),
				TargetUserId: targetUserId,
				Persisted: true,
			};
		}

		return { ok: false, error: "Unknown moderation command." };
	}

	private _execute(actor: Player, payload: Dict): Dict {
		const role = roleFor(actor);
		if (role === undefined) return { ok: false, error: "Administrative access denied." };
		if (!typeIs(payload, "table")) return { ok: false, error: "Malformed admin request." };
		// Server-side authorization: canonicalization only accepts names in the COMMANDS allowlist.
		const command = CommandSchema.canonical(cleanText(payload.Command, 48), COMMANDS);
		const definition = command !== undefined ? COMMANDS[command] : undefined;
		if (definition === undefined) return { ok: false, error: "Unknown admin command." };
		const [permitted, permissionError] = AdminPolicy.Allows(role, command!, definition);
		if (!permitted) return { ok: false, error: permissionError };
		const dryRun = payload.DryRun === true;
		const nonce = cleanText(payload.Nonce, 80);
		if (nonce.size() < 8 || !this._consumeNonce(actor, nonce)) {
			return { ok: false, error: "This admin request was already processed." };
		}
		const reason = cleanText(payload.Reason, 96);
		if (reason.size() < 3 && !dryRun) return { ok: false, error: "Add a short audit reason." };
		const option = cleanText(payload.Option, command === "Announce" ? 140 : 64);
		if (definition.Global === true) {
			return this._global(actor, command!, definition, option, reason, dryRun);
		}
		if (definition.Moderation === true) {
			const [duration, problem] = CommandSchema.validate(command!, definition, payload.Amount, option);
			if (duration === undefined) return { ok: false, error: problem };
			const targetUserId = tonumber(payload.TargetUserId);
			if (targetUserId === undefined || targetUserId !== math.floor(targetUserId)) {
				return { ok: false, error: "Pick a player to moderate." };
			}
			if (dryRun) {
				const subject = Players.GetPlayerByUserId(targetUserId);
				return {
					ok: true,
					DryRun: true,
					message: `Preview: ${definition.Label} → ${subject !== undefined ? subject.Name : tostring(targetUserId)}.`,
					Preview: [`${definition.Label}: ${option !== "" ? option : tostring(duration)}`],
					PreviewTotal: 1,
				};
			}
			return this._moderate(actor, command!, targetUserId, duration, option, reason);
		}
		const target = onlinePlayer(payload.TargetUserId);
		if (target === undefined || target.Parent !== Players) return { ok: false, error: "Target must be online in this server." };
		if (this._data.Get(target) === undefined) return { ok: false, error: "Target profile is still loading." };
		if (command === "InspectPlayer") {
			// read-only: no transaction, no revision bump
			return { ok: true, message: "Lookup for " + target.Name + ".", Lookup: this.Lookup(target) };
		}
		const [amount, inputError] = CommandSchema.validate(command!, definition, payload.Amount, option);
		if (amount === undefined) return { ok: false, error: inputError };

		if (dryRun) {
			if (definition.World === true) {
				return {
					ok: true,
					DryRun: true,
					message: `Preview: ${definition.Label} plays on ${target.Name}'s screen only. No saved data changes.`,
					Preview: [],
					PreviewTotal: 0,
				};
			}
			const handler = profileHandlers[command!];
			if (handler === undefined) return { ok: false, error: "Admin command has no executor." };
			const before = AdminPolicy.DeepCopy(this._data.Get(target)!);
			const scratch = AdminPolicy.DeepCopy(before);
			const [okRun, applied] = pcall(handler, scratch, amount, option);
			if (!okRun) return { ok: false, error: "Preview failed: " + tostring(applied) };
			if (typeIs(applied, "table") && (applied as Dict).ok === false) return applied as Dict;
			const [lines, total] = AdminPolicy.Diff(before, scratch, 10);
			const previewNote = typeIs(applied, "table") && typeIs((applied as Dict).note, "string") ? " " + ((applied as Dict).note as string) : "";
			return {
				ok: true,
				DryRun: true,
				message:
					(total === 0
						? `Preview: ${definition.Label} would change nothing for ${target.Name}.`
						: `Preview: ${total} saved value${total === 1 ? "" : "s"} change for ${target.Name}.`) + previewNote,
				Preview: lines,
				PreviewTotal: total,
			};
		}

		if (definition.World === true) {
			const [ok, worldMessage] = applyWorld(actor, target, command!, amount, option);
			if (!ok) return { ok: false, error: worldMessage };
			const revision = this._data.GetRevision(target);
			this._record(actor, target, command!, amount, option, reason, revision);
			return {
				ok: true,
				message: worldMessage,
				Admin: this.State(actor),
				TargetUserId: target.UserId,
				World: true,
				Persisted: false,
			};
		}

		let changedAmount = amount;
		let note = "";
		const [success, result] = this._data.AtomicUpdate(
			target,
			(profile) => {
				const handler = profileHandlers[command!];
				if (handler === undefined) return { ok: false, error: "Admin command has no executor." };
				const applied = handler(profile, amount, option);
				if (applied.ok === true) {
					changedAmount = applied.amount as number;
					note = typeIs(applied.note, "string") ? " " + applied.note : "";
				}
				return applied;
			},
			true,
			"admin:" + command,
		);
		if (!success) return { ok: false, error: "Profile transaction failed: " + tostring(result) };
		if (typeIs(result, "table") && (result as Dict).ok === false) return result as Dict;
		const revision = this._data.GetRevision(target);
		this._record(actor, target, command!, changedAmount, option, reason, revision);

		const persisted = this._data.Save(target, false);
		return {
			ok: true,
			message: string.format(
				"%s applied to %s (revision %d%s).%s",
				definition.Label,
				target.Name,
				revision,
				persisted ? ", saved" : ", autosave retry queued",
				note,
			),
			Admin: this.State(actor),
			TargetUserId: target.UserId,
			Persisted: persisted,
		};
	}

	/** Security flags, live score and recovery journal for one online player. */
	Lookup(target: Player): Dict {
		const profile = this._data.Get(target);
		return {
			UserId: target.UserId,
			Name: target.Name,
			Score: math.floor(Ledger.Score(target.UserId) * 10 + 0.5) / 10,
			Level: Ledger.Level(target.UserId),
			Flags: Ledger.ForUser(target.UserId, 25),
			Revision: this._data.GetRevision(target),
			Journal: profile !== undefined ? ProfileIntegrity.Journal(profile) : [],
		};
	}

	private _dashboard(): Dict {
		const rows: OpsDashboard.DashboardRow[] = [];
		for (const player of Players.GetPlayers()) {
			const profile = this._data.Get(player);
			if (profile !== undefined) {
				const [ok, production] = pcall(Economy.Production, profile);
				rows.push({
					Cash: profile.Cash,
					Production: ok ? production : 0,
					Rebirths: profile.Rebirths,
					Stardust: profile.Stardust,
					Cores: profile.Cores,
				});
			}
		}
		return OpsDashboard.Build(rows, this.analytics.ActionCounts(), OmegaMath) as unknown as Dict;
	}

	private _global(actor: Player, command: string, definition: CommandDef, option: string, reason: string, dryRun: boolean): Dict {
		const [, problem] = CommandSchema.validate(command, definition, undefined, option);
		if (problem !== undefined) return { ok: false, error: problem };
		let message: Dict;
		if (command === "Announce") {
			const text = option.gsub("^%s*(.-)%s*$", "%1")[0];
			if (text.size() < 3) return { ok: false, error: "Write a short announcement." };
			message = { Kind: "Announce", Text: text, From: actor.Name, At: os.time() };
		} else if (command === "ToggleHotFlag") {
			const [flag, on, parseError] = HotFlags.Parse(option);
			if (flag === undefined) return { ok: false, error: parseError };
			message = { Kind: "HotFlag", Flag: flag, On: on, From: actor.Name, At: os.time() };
		} else {
			return { ok: false, error: "Admin command has no executor." };
		}
		if (dryRun) {
			return {
				ok: true,
				DryRun: true,
				message: `Preview: ${definition.Label}.`,
				Preview: [`${definition.Label}: ${option}`],
				PreviewTotal: 1,
			};
		}
		// apply here first, then tell the other servers (this server ignores its own echo by At)
		this.ReceiveLiveOps(message);
		const [published, publishError] = pcall(() => MessagingService.PublishAsync(LIVE_OPS_TOPIC, message));
		const subject = { Name: "all servers", UserId: 0 } as unknown as Player;
		this._record(actor, subject as never, command, 0, option, reason, 0);
		return {
			ok: true,
			message: published
				? `${definition.Label}: sent to every server.`
				: `${definition.Label}: applied here only (cross-server send failed: ${tostring(publishError)}).`,
			Admin: true,
		};
	}

	/** Applies a live-ops message from this or another server. Unknown or malformed ones are ignored. */
	ReceiveLiveOps(raw: unknown): boolean {
		if (!typeIs(raw, "table")) return false;
		const message = raw as Dict;
		const at = num(message.At) ?? 0;
		if (message.Kind === "HotFlag" && HotFlags.IsFlag(message.Flag)) {
			const changed = HotFlags.Set(message.Flag, message.On === true, at);
			if (changed) {
				ModuleLog.Warn("Admin", string.format("live-ops flag %s %s by %s", message.Flag, message.On === true ? "on" : "off", tostring(message.From)));
			}
			return changed;
		}
		if (message.Kind === "Announce" && typeIs(message.Text, "string")) {
			const text = cleanText(message.Text, 140);
			if (text.size() < 1) return false;
			for (const seen of this._announcements) {
				if (seen.Text === text && seen.At === at) return false; // our own echo
			}
			this._announcements.unshift({ Text: text, From: cleanText(message.From, 40), At: at });
			while (this._announcements.size() > 10) this._announcements.pop();
			if (!HotFlags.Get("AnnouncementsMuted")) {
				for (const player of Players.GetPlayers()) {
					ServerEvents.toast.fire(player, { Title: "Announcement", Body: text, Tone: "Info" });
				}
			}
			return true;
		}
		return false;
	}

	Execute(actor: Player, payload: Dict): Dict {
		const result = this._execute(actor, payload);
		if (typeIs(result, "table")) {
			if (this._lastByActor === undefined) {
				this._lastByActor = new Map();
			}
			this._lastByActor.set(actor.UserId, {
				Ok: result.ok === true,
				Command: typeIs(payload, "table") ? cleanText(payload.Command, 48) : "",
				Message: (result.ok === true ? result.message : result.error) ?? "",
				At: os.time(),
			});
			if (result.Admin !== undefined) {
				result.Admin = this.State(actor);
			}
		}
		return result;
	}
}

const AUDIT_ONLY_REASONS = AdminGrantMath.AUDIT_ONLY_REASONS;

function playerFacingReason(command: string, reason: string): string {
	return AdminGrantMath.PlayerFacingReason(command, reason, AUDIT_ONLY_REASONS);
}

// Each profile command has one executor; the transaction wrapper owns audits and saving.
const profileHandlers: Record<string, ProfileHandler> = {};
profileHandlers.RollbackCritical = (profile, _amount, option) => {
	const [ok, message] = ProfileIntegrity.Restore(profile, option);
	if (!ok) return { ok: false, error: message };
	return { ok: true, amount: 0, message };
};
profileHandlers.GrantFlux = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cash = Omega.Add(profile.Cash, amount);
	profile.RunCash = Omega.Add(profile.RunCash, amount);
	profile.LifetimeCash = Omega.Add(profile.LifetimeCash, amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantCores = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cores = (num(profile.Cores) ?? 0) + amount;
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantStardust = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Stardust = (num(profile.Stardust) ?? 0) + amount;
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantRebirths = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Rebirths = (num(profile.Rebirths) ?? 0) + math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantDomainEssence = (profile, amount, option) => {
	const changedAmount = amount;
	(ProfileBagMath.EnsureDomain(profile) as DomainBag).Essence += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantAnomalyFragments = (profile, amount, option) => {
	const changedAmount = amount;
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Fragments += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantSignals = (profile, amount, option) => {
	const changedAmount = amount;
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.Signals += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantCommandXP = (profile, amount, option) => {
	const changedAmount = amount;
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.XP += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantSeasonXP = (profile, amount, option) => {
	const changedAmount = amount;
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.SeasonXP += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantStreakShields = (profile, amount, option) => {
	const changedAmount = amount;
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.StreakShields += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantItemEssence = (profile, amount, option) => {
	const changedAmount = amount;
	(ProfileBagMath.EnsureItems(profile) as ItemsBag).Essence += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantContinuumRanks = (profile, amount, option) => {
	const changedAmount = amount;
	const continuum = ProfileBagMath.EnsureContinuum(profile) as ContinuumBag;
	continuum.Rank = math.min(d(GameConfig.Continuum).MaxRank as number, (continuum.Rank as number) + math.floor(amount));
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantAnomalyCharge = (profile, amount, option) => {
	const changedAmount = amount;
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Charge += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantAnomalyStabilizations = (profile, amount, option) => {
	const changedAmount = amount;
	const n = math.floor(amount);
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Stabilizations += n;
	ProfileBagMath.BumpStat(profile, "AnomalyStabilizations", n);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantShards = (profile, amount, option) => {
	const changedAmount = amount;
	const foundry = ProfileBagMath.EnsureFoundry(profile);
	foundry.Shards = (num(foundry.Shards) ?? 0) + math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetFoundryRadius = (profile, amount, option) => {
	const changedAmount = amount;
	const foundry = ProfileBagMath.EnsureFoundry(profile);
	foundry.Radius = math.clamp(math.floor(amount), 2, 4);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantFoundryPiece = (profile, amount, option) => {
	const changedAmount = amount;
	const foundry = ProfileBagMath.EnsureFoundry(profile);
	if (!typeIs(foundry.Bench, "table")) {
		foundry.Bench = [];
	}
	let kind = "Ember";
	let tier = 1;
	if (typeIs(option, "string") && option !== "") {
		const [k, t] = string.match(option, "([^:]+):?(%d*)");
		if (k !== undefined && k !== "") {
			kind = k as string;
		}
		if (t !== undefined && num(t) !== undefined) {
			tier = math.clamp(num(t)!, 1, 9);
		}
	}
	for (const _ of $range(1, math.clamp(math.floor(amount), 1, 10))) {
		if ((foundry.Bench as defined[]).size() < 12) {
			(foundry.Bench as defined[]).push({ Kind: kind, Tier: tier, Rotation: 0 });
		}
	}
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantFreeSpins = (profile, amount, option) => {
	const changedAmount = amount;
	const wheel = WheelMath.Ensure(profile.Wheel);
	profile.Wheel = wheel;
	wheel.FreeSpins += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantCrateKeys = (profile, amount, option) => {
	const changedAmount = amount;
	const keys = ProfileBagMath.EnsureItemKeys(profile);
	if (keys[option] === undefined) return { ok: false, error: "Unknown crate id." };
	keys[option] += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantAllCrateKeys = (profile, amount, option) => {
	const changedAmount = amount;
	const keys = ProfileBagMath.EnsureItemKeys(profile);
	for (const [crateId] of pairs(keys)) keys[crateId] += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantPity = (profile, amount, option) => {
	const changedAmount = amount;
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	const pity = items.Pity as Dict;
	if (pity[option] === undefined) return { ok: false, error: "Unknown crate id." };
	pity[option] = (num(pity[option]) ?? 0) + math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantBoost = (profile, amount, option) => {
	const changedAmount = amount;
	if (!truthy((GameConfig.Boosts as Dict)[option])) return { ok: false, error: "Unknown boost id." };
	const inventory = ProfileBagMath.EnsureBoostInventory(profile);
	inventory[option] = (inventory[option] ?? 0) + math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantAllBoosts = (profile, amount, option) => {
	const changedAmount = amount;
	const inventory = ProfileBagMath.EnsureBoostInventory(profile);
	for (const [boostId] of pairs(GameConfig.Boosts as Dict)) {
		inventory[boostId as string] = (inventory[boostId as string] ?? 0) + math.floor(amount);
	}
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantRelic = (profile, amount, option) => {
	let changedAmount = amount;
	changedAmount = 0;
	for (const _ of $range(1, math.min(10, math.floor(amount)))) {
		if (!createRelic(profile, option)) break;
		changedAmount += 1;
	}
	if (changedAmount <= 0) return { ok: false, error: "Relic id is invalid or inventory is full." };
	return { ok: true, amount: changedAmount };
};
profileHandlers.ClearActiveBoost = (profile, amount, option) => {
	const changedAmount = amount;
	const active = ProfileBagMath.EnsureActiveBoost(profile);
	active.Id = "";
	active.EndsAt = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetWheelCooldown = (profile, amount, option) => {
	const changedAmount = amount;
	const wheel = WheelMath.Ensure(profile.Wheel);
	profile.Wheel = wheel;
	wheel.LastSpinAt = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetDailyClaim = (profile, amount, option) => {
	const changedAmount = amount;
	ProfileBagMath.EnsureDaily(profile).LastClaimDay = -1;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ClearVault = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Vault = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetZone = (profile, amount, option) => {
	const changedAmount = amount;
	const zone = math.clamp(math.floor(amount), 1, GameConfig.MaxZone as number);
	profile.Zone = math.max(num(profile.Zone) ?? 0, zone);
	profile.CurrentZone = zone;
	return { ok: true, amount: changedAmount };
};
profileHandlers.EnableUnlimitedFlux = (profile, amount, option) => {
	const changedAmount = amount;
	ProfileBagMath.EnsureFlags(profile).UnlimitedMoney = true;
	return { ok: true, amount: changedAmount };
};
profileHandlers.DisableUnlimitedFlux = (profile, amount, option) => {
	const changedAmount = amount;
	ProfileBagMath.EnsureFlags(profile).UnlimitedMoney = false;
	return { ok: true, amount: changedAmount };
};
profileHandlers.UnlockProgression = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Zone = GameConfig.MaxZone;
	profile.CurrentZone = profile.Zone;
	const machines = d(profile.Machines);
	for (const machine of GameConfig.Machines as Dict[]) machines[machine.Id as string] = machine.MaxLevel;
	const research = d(profile.Research);
	for (const entry of GameConfig.Research as Dict[]) research[entry.Id as string] = entry.MaxLevel;
	const gridUpgrades = d(profile.GridUpgrades);
	for (const upgrade of GameConfig.GridUpgrades as Dict[]) gridUpgrades[upgrade.Id as string] = upgrade.MaxLevel;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetTutorial = (profile, amount, option) => {
	const changedAmount = amount;
	const flags = ProfileBagMath.EnsureFlags(profile);
	flags.TutorialDone = false;
	flags.TutorialStep = 1;
	flags.TutorialRewardClaimed = false;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetSettings = (profile, amount, option) => {
	profile.Settings = table.clone(d(DataTemplate.New().Settings));
	return { ok: true, amount: amount, note: "saved preferences restored to defaults" };
};
profileHandlers.ShowUpdates = (profile, amount, option) => {
	const changedAmount = amount;
	ProfileBagMath.EnsureFlags(profile).LastSeenVersion = "";
	return { ok: true, amount: changedAmount };
};
profileHandlers.WipeFlux = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cash = 0;
	profile.RunCash = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.WipeVault = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Vault = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.WipeCores = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cores = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.WipeStardust = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Stardust = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetDomainEssence = (profile, amount, option) => {
	(ProfileBagMath.EnsureDomain(profile) as DomainBag).Essence = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.SetItemEssence = (profile, amount, option) => {
	(ProfileBagMath.EnsureItems(profile) as ItemsBag).Essence = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.SetSignals = (profile, amount, option) => {
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.Signals = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.SetSeasonXP = (profile, amount, option) => {
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.SeasonXP = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.SetStreakShields = (profile, amount, option) => {
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.StreakShields = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.SetAnomalyFragments = (profile, amount, option) => {
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Fragments = math.max(0, math.floor(amount));
	return { ok: true, amount: amount };
};
profileHandlers.GrantVaultFlux = (profile, amount, option) => {
	profile.Vault = Omega.Min(Omega.Add(profile.Vault, amount), Economy.Capacity(profile));
	return { ok: true, amount: amount };
};
profileHandlers.DoubleFlux = (profile, amount, option) => {
	profile.Cash = Omega.Add(profile.Cash, profile.Cash);
	profile.RunCash = Omega.Add(profile.RunCash, profile.RunCash);
	return { ok: true, amount: amount };
};
profileHandlers.BankVault = (profile, amount, option) => {
	profile.Cash = Omega.Add(profile.Cash, profile.Vault);
	profile.RunCash = Omega.Add(profile.RunCash, profile.Vault);
	profile.Vault = 0;
	return { ok: true, amount: amount };
};
profileHandlers.WipeItemEssence = (profile, amount, option) => {
	(ProfileBagMath.EnsureItems(profile) as ItemsBag).Essence = 0;
	return { ok: true, amount: amount };
};
profileHandlers.ResetPityAll = (profile, amount, option) => {
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	const pity = items.Pity as Dict;
	for (const [crateId] of pairs(pity)) pity[crateId as string] = 0;
	return { ok: true, amount: amount };
};
profileHandlers.ResetCommandXP = (profile, amount, option) => {
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.XP = 0;
	return { ok: true, amount: amount };
};
profileHandlers.PennyPinch = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cash = 1;
	profile.RunCash = 1;
	return { ok: true, amount: changedAmount };
};
profileHandlers.TaxHalf = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cash = Omega.Div(profile.Cash, 2);
	profile.RunCash = Omega.Div(profile.RunCash, 2);
	return { ok: true, amount: changedAmount };
};
profileHandlers.SwapWallet = (profile, amount, option) => {
	const changedAmount = amount;
	const parked = profile.Cash;
	profile.Cash = profile.Vault;
	profile.Vault = parked;
	return { ok: true, amount: changedAmount };
};
profileHandlers.FillVault = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Vault = Economy.Capacity(profile);
	return { ok: true, amount: changedAmount };
};
profileHandlers.DrainKeys = (profile, amount, option) => {
	const changedAmount = amount;
	const keys = ProfileBagMath.EnsureItemKeys(profile);
	for (const [crateId] of pairs(keys)) keys[crateId] = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.DrainBoosts = (profile, amount, option) => {
	const changedAmount = amount;
	const inventory = ProfileBagMath.EnsureBoostInventory(profile);
	for (const [boostId] of pairs(inventory)) inventory[boostId] = 0;
	return { ok: true, amount: changedAmount };
};
profileHandlers.LockRelics = (profile, amount, option) => {
	const changedAmount = amount;
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	for (const [, instance] of pairs(items.Inventory as object)) (instance as RelicInstance).Locked = true;
	return { ok: true, amount: changedAmount };
};
profileHandlers.UnlockRelics = (profile, amount, option) => {
	const changedAmount = amount;
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	for (const [, instance] of pairs(items.Inventory as object)) (instance as RelicInstance).Locked = false;
	return { ok: true, amount: changedAmount };
};
profileHandlers.SalvageRelics = (profile, amount, option) => {
	const changedAmount = { value: amount };
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	const kept: Record<string, unknown> = {};
	let salvaged = 0;
	for (const [uid, instance] of pairs(items.Inventory as object)) {
		let equipped = false;
		for (const equippedUid of items.Equipped as defined[]) {
			if (equippedUid === uid) {
				equipped = true;
				break;
			}
		}
		if (equipped || (instance as RelicInstance).Locked === true) {
			kept[uid as string] = instance;
		} else {
			salvaged += 1;
			items.Essence += 8;
		}
	}
	items.Inventory = kept as Dict;
	changedAmount.value = salvaged;
	return { ok: true, amount: changedAmount.value };
};
profileHandlers.SetRebirths = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Rebirths = math.max(0, math.floor(amount));
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetCores = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Cores = math.max(0, math.floor(amount));
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetStardust = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Stardust = math.max(0, math.floor(amount));
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetDomainRank = (profile, amount, option) => {
	const changedAmount = amount;
	(ProfileBagMath.EnsureDomain(profile) as DomainBag).Rank = math.max(0, math.floor(amount));
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantSkillPoints = (profile, amount, option) => {
	const changedAmount = amount;
	const domain = ProfileBagMath.EnsureDomain(profile) as DomainBag;
	domain.SkillPoints = (domain.SkillPoints ?? 0) + math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetDomain = (profile, amount, option) => {
	const changedAmount = amount;
	const domain = ProfileBagMath.EnsureDomain(profile) as DomainBag;
	domain.Rank = 0;
	domain.SkillPoints = 0;
	domain.Nodes = {};
	return { ok: true, amount: changedAmount };
};
profileHandlers.MaxMachines = (profile, amount, option) => {
	const changedAmount = amount;
	const machines = d(profile.Machines);
	for (const machine of GameConfig.Machines as Dict[]) machines[machine.Id as string] = machine.MaxLevel;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetMachines = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Machines = { StellarCore: 1 };
	return { ok: true, amount: changedAmount };
};
profileHandlers.MaxResearch = (profile, amount, option) => {
	const changedAmount = amount;
	const research = d(profile.Research);
	for (const entry of GameConfig.Research as Dict[]) research[entry.Id as string] = entry.MaxLevel;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetResearch = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Research = {};
	return { ok: true, amount: changedAmount };
};
profileHandlers.MaxGrid = (profile, amount, option) => {
	const changedAmount = amount;
	const gridUpgrades = d(profile.GridUpgrades);
	for (const upgrade of GameConfig.GridUpgrades as Dict[]) gridUpgrades[upgrade.Id as string] = upgrade.MaxLevel;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetGrid = (profile, amount, option) => {
	const changedAmount = amount;
	profile.GridUpgrades = {};
	return { ok: true, amount: changedAmount };
};
profileHandlers.FillPityAll = (profile, amount, option) => {
	const changedAmount = amount;
	const items = ProfileBagMath.EnsureItems(profile) as ItemsBag;
	const pity = items.Pity as Dict;
	for (const [crateId] of pairs(pity)) pity[crateId as string] = 99;
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetTrades = (profile, amount, option) => {
	const changedAmount = amount;
	if (truthy(profile.Trade)) {
		const trade = d(profile.Trade);
		trade.Completed = 0;
		trade.Day = -1;
	}
	return { ok: true, amount: changedAmount };
};
profileHandlers.ResetDailies = (profile, amount, option) => {
	const changedAmount = amount;
	ProfileBagMath.EnsureDaily(profile).LastClaimDay = -1;
	const wheel = WheelMath.Ensure(profile.Wheel);
	profile.Wheel = wheel;
	wheel.LastSpinAt = 0;
	if (truthy(profile.Trade)) d(profile.Trade).Day = -1;
	return { ok: true, amount: changedAmount };
};
profileHandlers.InspectMarket = (profile, amount, option) => {
	const bag = BazaarMath.Ensure(profile.Bazaar) as BazaarBag;
	profile.Bazaar = bag;
	const bucket = BazaarMath.MarketBucket(os.time());
	const merchant = BazaarMath.Merchant(bucket) as Dict;
	const rare = BazaarMath.RareOffer(bucket) as Dict | undefined;
	const [tier] = BazaarMath.Reputation(bag.Counters.Deals);
	const tierName = d(tier).Name;
	let spent = 0;
	if (bag.Market.Bucket === bucket) for (const [, count] of pairs(bag.Market.Bought as object)) spent += count as number;
	const request = BazaarMath.RegularById(bag.Market.Procure.Id) as Dict | undefined;
	const last = bag.Market.History[0] as Dict | undefined;
	const lastName =
		last !== undefined ? ((BazaarMath.CatalogById(last.Pick) as Dict | undefined) ?? { Name: last.Pick }).Name : "none";
	return {
		ok: true,
		amount: amount,
		note: string.format(
			"Shipment %d by %s; rare: %s. %s standing (%d units), %d bought this shipment, %d receipts, last: %s. Request: %s.",
			bucket,
			merchant.Name as string,
			rare !== undefined ? (rare.Name as string) : "none",
			tierName as string,
			bag.Counters.Deals,
			spent,
			bag.Market.History.size(),
			lastName as string,
			request !== undefined ? (request.Name as string) : "none",
		),
	};
};
profileHandlers.ResetMarketPurchases = (profile, amount, option) => {
	const bag = BazaarMath.Ensure(profile.Bazaar) as BazaarBag;
	profile.Bazaar = bag;
	bag.Market.Bought = {};
	return { ok: true, amount: amount };
};
profileHandlers.CancelMarketRequest = (profile, amount, option) => {
	const bag = BazaarMath.Ensure(profile.Bazaar) as BazaarBag;
	profile.Bazaar = bag;
	if (bag.Market.Procure.Id === "") return { ok: false, error: "That player has no open supply request." };
	bag.Market.Procure = { Id: "", Since: 0, Filled: 0 };
	return { ok: true, amount: amount };
};
profileHandlers.ZeroZone = (profile, amount, option) => {
	const changedAmount = amount;
	profile.Zone = 1;
	profile.CurrentZone = 1;
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantEchoCharge = (profile, amount, option) => {
	const changedAmount = amount;
	const echoes = EchoMath.ensure(profile.ForgeEchoes);
	profile.ForgeEchoes = echoes;
	echoes.Charge += math.floor(amount);
	return { ok: true, amount: changedAmount };
};
profileHandlers.MaxCrew = (profile, amount, option) => {
	const changedAmount = amount;
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	for (const [roleId] of pairs(commandState.Crew)) {
		commandState.Crew[roleId] = 10;
	}
	return { ok: true, amount: changedAmount };
};
profileHandlers.DiscoverArts = (profile, amount, option) => {
	const changedAmount = amount;
	if (truthy(GameConfig.Operations) && truthy(d(GameConfig.Operations).Artifacts)) {
		const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
		profile.Command = commandState;
		if (!typeIs(commandState.Artifacts, "table")) {
			commandState.Artifacts = {};
		}
		for (const artifact of d(GameConfig.Operations).Artifacts as Dict[]) {
			commandState.Artifacts[artifact.Id as string] =
				(commandState.Artifacts as Record<string, unknown>)[artifact.Id as string] ?? { Level: 1, Fragments: 0 };
		}
	}
	return { ok: true, amount: changedAmount };
};
profileHandlers.GrantEverything = (profile, amount, option) => {
	const changedAmount = amount;
	const bundle = math.max(amount, 1e12);
	profile.Cash = Omega.Add(profile.Cash, bundle);
	profile.RunCash = Omega.Add(profile.RunCash, bundle);
	profile.LifetimeCash = Omega.Add(profile.LifetimeCash, bundle);
	profile.Cores = (num(profile.Cores) ?? 0) + math.max(1000, math.floor(amount));
	profile.Stardust = (num(profile.Stardust) ?? 0) + math.max(100000, math.floor(amount));
	profile.Rebirths = (num(profile.Rebirths) ?? 0) + math.max(100, math.floor(amount));
	(ProfileBagMath.EnsureDomain(profile) as DomainBag).Essence += math.max(100, math.floor(amount));
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Fragments += math.max(10000, math.floor(amount));
	const commandState = CommandMath.Ensure(profile.Command, d(GameConfig.Operations).SeasonId as string);
	profile.Command = commandState;
	commandState.Signals += math.max(10000, math.floor(amount));
	const wheel = WheelMath.Ensure(profile.Wheel);
	profile.Wheel = wheel;
	wheel.FreeSpins += math.max(100, math.floor(amount));
	const keys = ProfileBagMath.EnsureItemKeys(profile);
	for (const [crateId] of pairs(keys)) keys[crateId] += 100;
	const boosts = ProfileBagMath.EnsureBoostInventory(profile);
	for (const [boostId] of pairs(GameConfig.Boosts as Dict)) boosts[boostId as string] = (boosts[boostId as string] ?? 0) + 25;
	return { ok: true, amount: changedAmount };
};
profileHandlers.SetFlux = (profile, amount, option) => {
	profile.Cash = amount;
	return { ok: true, amount: amount };
};
profileHandlers.SetVault = (profile, amount, option) => {
	profile.Vault = Omega.Min(amount, Economy.Capacity(profile));
	return { ok: true, amount: amount };
};
profileHandlers.SetContinuumRank = (profile, amount, option) => {
	ProfileBagMath.EnsureContinuum(profile).Rank = math.min(d(GameConfig.Continuum).MaxRank as number, amount);
	return { ok: true, amount: amount };
};
profileHandlers.SetFreeSpins = (profile, amount, option) => {
	const wheel = WheelMath.Ensure(profile.Wheel);
	profile.Wheel = wheel;
	wheel.FreeSpins = amount;
	return { ok: true, amount: amount };
};
profileHandlers.ResetAnomalyCharge = (profile, amount, option) => {
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Charge = 0;
	return { ok: true, amount: amount };
};
profileHandlers.ClearAnomalyCombo = (profile, amount, option) => {
	(ProfileBagMath.EnsureAnomaly(profile) as AnomalyBag).Combo = 0;
	return { ok: true, amount: amount };
};

