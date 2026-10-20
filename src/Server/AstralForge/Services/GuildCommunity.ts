import StoreAccess from "../Modules/StoreAccess";
import { Dict, isTable, num, truthy } from "./LuaInterop";
// Persistent guild community features. Chat and announcement text is filtered before storage or broadcast.

const HttpService = game.GetService("HttpService");
const MessagingService = game.GetService("MessagingService");
const RunService = game.GetService("RunService");
const Players = game.GetService("Players");

const STORE_NAME = "AstralForge_GuildCommunity_v1";
const CHAT_LIMIT = 200;
const ANNOUNCEMENT_LIMIT = 50;
const LOGO_HISTORY_LIMIT = 12;
const CACHE_SECONDS = 8;
// cross-server relay: members on other servers see chat/announcements immediately.
// One topic per guild, subscribed only by servers that currently host a member of that guild.
// A single shared topic would deliver every guild's traffic to every server, and that fan-out
// (publishes x servers) exhausts the experience-wide receive budget at high server counts.
const RELAY_PREFIX = "AF_Guild_v2_";
const RELAY_MAX_BYTES = 900; // MessagingService caps a message at 1 kB
const RELAY_RECONCILE_SECONDS = 5;

function relayTopic(guildId: string): string | undefined {
	const topic = RELAY_PREFIX + guildId;
	// MessagingService topics are at most 80 characters
	const [bad] = guildId.find("[^%w%-_]");
	return topic.size() <= 80 && bad === undefined ? topic : undefined;
}

interface GuildAnnouncement {
	Id: string;
	AuthorUserId: number;
	AuthorName: string;
	AuthorRole: string;
	PublishedAt: number;
	EditedAt?: number;
	Pinned: boolean;
	Archived: boolean;
	ExpiresAt?: number;
	Title: string;
	Body: string;
}

interface GuildChatMessage {
	Id: string;
	SpeakerUserId: number;
	SpeakerName: string;
	SpeakerRole: string;
	PublishedAt: number;
	Message: string;
}

interface GuildLogoRecord {
	Id: string;
	UploadedBy: number;
	UploadedAt: number;
	Status: "pending" | "approved" | "rejected";
	URL?: string;
	RejectReason?: string;
}

interface CommunityDocument {
	Chat: GuildChatMessage[];
	Announcements: GuildAnnouncement[];
	Logos: GuildLogoRecord[];
	Mutes: Record<string, { MutedBy: number; MutedAt: number }>;
	Bans: Record<string, { BannedBy: number; BannedAt: number }>;
	Settings: Record<string, unknown>;
}

interface DataStoreLike {
	GetAsync(key: string): unknown;
	UpdateAsync(key: string, transform: (this: void, old: unknown) => unknown): unknown;
}

interface GuildServiceLike {
	_findByTag(tag: string): Dict | undefined;
	GetPublic(guildId: string): Dict | undefined;
	_update(
		guildId: string,
		transform: (this: void, current: Dict) => Dict | undefined,
	): LuaTuple<[boolean, unknown]>;
}

interface DataServiceLike {
	Get(this: DataServiceLike, player: Player): Dict | undefined;
}

interface SecurityLike {
	Filter?: {
		Apply(
			player: Player,
			text: string,
			contextUserId?: number,
			maximumLength?: number,
		): LuaTuple<[boolean, string | undefined]>;
	};
}

type OnBanMember = (this: void, player: Player, guildId: string) => LuaTuple<[boolean, unknown]>;

const DEFAULT_SETTINGS = {
	ChatEnabled: true,
	AnnouncementsEnabled: true,
	LogoEnabled: true,
	OfficerAnnouncements: true,
	OfficerModeration: true,
	SlowMode: false,
};
const SLOW_MODE_SECONDS = 6;

function copy(value: unknown): unknown {
	if (!typeIs(value, "table")) return value;
	const result: Dict = {};
	for (const [key, child] of pairs(value)) {
		result[copy(key) as string] = copy(child);
	}
	return result;
}

function emptyDocument(): CommunityDocument {
	return {
		Chat: [],
		Announcements: [],
		Logos: [],
		Mutes: {},
		Bans: {},
		Settings: table.clone(DEFAULT_SETTINGS) as Record<string, unknown>,
	};
}

function normalizeDocument(raw: unknown): CommunityDocument {
	const doc = (typeIs(raw, "table") ? raw : emptyDocument()) as CommunityDocument;
	for (const [key, value] of pairs(emptyDocument())) {
		if (!typeIs(doc[key as keyof CommunityDocument], "table")) (doc as unknown as Dict)[key] = value;
	}
	for (const [key, value] of pairs(DEFAULT_SETTINGS)) {
		if (!typeIs(doc.Settings[key], "boolean")) doc.Settings[key] = value;
	}
	return doc;
}

function isMember(guild: unknown, userId: number): LuaTuple<[boolean, string]> {
	const member =
		isTable(guild) && isTable(guild.Members)
			? guild.Members[tostring(userId)]
			: undefined;
	if (!isTable(member)) return $tuple(false, "You are not a member of this guild.");
	const role = typeIs(member.Role, "string") ? member.Role : "Member";
	return $tuple(true, role);
}

function canManage(role: string): boolean {
	return role === "Leader" || role === "Officer";
}

function safeGuildAsset(raw: unknown): string | undefined {
	if (!typeIs(raw, "string")) return undefined;
	const [assetId] = raw.match("^rbxassetid://(%d+)$");
	const [plainId] = raw.match("^(%d+)$");
	const id = assetId ?? plainId;
	if (id === undefined || tostring(id).size() > 20 || tonumber(id) === undefined || (tonumber(id) ?? 0) <= 0)
		return undefined;
	return "rbxassetid://" + tostring(id);
}

class GuildCommunity {
	private _guilds: GuildServiceLike;
	private _data: DataServiceLike;
	private _security: SecurityLike | undefined;
	private _effect: RemoteEvent;
	private _onBanMember: OnBanMember | undefined;
	private _cache = new Map<string, CommunityDocument>();
	private _cacheAt = new Map<string, number>();
	private _studio = new Map<string, CommunityDocument>();
	private _store: DataStoreLike;
	private _alive = true;
	// guildId -> live subscription, or true while SubscribeAsync is still in flight
	private _relays = new Map<string, RBXScriptConnection | boolean>();
	private _chatAt = new Map<string, number>();

	constructor(
		guildService: GuildServiceLike,
		dataService: DataServiceLike,
		security: SecurityLike | undefined,
		effect: RemoteEvent,
		onBanMember?: OnBanMember,
	) {
		this._guilds = guildService;
		this._data = dataService;
		this._security = security;
		this._effect = effect;
		this._onBanMember = onBanMember;
		this._store = StoreAccess.data(STORE_NAME) as DataStoreLike;
		if (!StoreAccess.isPreview()) {
			task.spawn(() => {
				while (this._alive) {
					this._reconcileRelays();
					task.wait(RELAY_RECONCILE_SECONDS);
				}
			});
		}
	}

	// Guilds with at least one member on this server.
	private _hostedGuilds(): Set<string> {
		const hosted = new Set<string>();
		for (const player of Players.GetPlayers()) {
			const profile = this._data.Get(player);
			const guildId = profile !== undefined && isTable(profile.Guild) ? profile.Guild.Id : undefined;
			if (typeIs(guildId, "string") && guildId !== "") hosted.add(guildId);
		}
		return hosted;
	}

	private _reconcileRelays() {
		const hosted = this._hostedGuilds();
		for (const [guildId, subscription] of this._relays) {
			if (!hosted.has(guildId) && typeIs(subscription, "RBXScriptConnection")) {
				subscription.Disconnect();
				this._relays.delete(guildId);
			}
		}
		for (const guildId of hosted) {
			const topic = relayTopic(guildId);
			if (topic !== undefined && this._relays.get(guildId) === undefined) {
				this._relays.set(guildId, true);
				task.spawn(() => {
					const [ok, connection] = pcall(() =>
						MessagingService.SubscribeAsync(topic, (envelope) => {
							this._onRelay(typeIs(envelope, "table") ? (envelope as Dict).Data : undefined);
						}),
					);
					if (!ok) {
						this._relays.delete(guildId); // retried on the next reconcile
					} else if (this._alive && this._relays.get(guildId) === true) {
						this._relays.set(guildId, connection as RBXScriptConnection);
					} else {
						(connection as RBXScriptConnection).Disconnect();
					}
				});
			}
		}
	}

	private _read(guildId: string): CommunityDocument | undefined {
		const now = os.clock();
		const cached = this._cache.get(guildId);
		if (cached !== undefined && (this._cacheAt.get(guildId) ?? 0) + CACHE_SECONDS > now)
			return copy(cached) as CommunityDocument;
		if (RunService.IsStudio() && this._studio.get(guildId) !== undefined) {
			const doc = normalizeDocument(copy(this._studio.get(guildId)));
			this._cache.set(guildId, doc);
			this._cacheAt.set(guildId, now);
			return copy(doc) as CommunityDocument;
		}
		const [ok, raw] = pcall(() => this._store.GetAsync(guildId));
		if (ok) {
			const doc = normalizeDocument(raw);
			this._cache.set(guildId, doc);
			this._cacheAt.set(guildId, now);
			if (RunService.IsStudio()) this._studio.set(guildId, copy(doc) as CommunityDocument);
			return copy(doc) as CommunityDocument;
		}
		if (cached !== undefined) return copy(cached) as CommunityDocument;
		if (RunService.IsStudio()) {
			const doc = emptyDocument();
			this._studio.set(guildId, copy(doc) as CommunityDocument);
			this._cache.set(guildId, copy(doc) as CommunityDocument);
			this._cacheAt.set(guildId, now);
			return copy(doc) as CommunityDocument;
		}
		return undefined;
	}

	private _update(
		guildId: string,
		transform: (this: void, doc: CommunityDocument) => LuaTuple<[CommunityDocument | undefined, unknown]>,
	): LuaTuple<[boolean, unknown, CommunityDocument | undefined]> {
		if (!this._alive || guildId === "") return $tuple(false, "Guild community is unavailable.", undefined);
		let updated: CommunityDocument | undefined = undefined;
		let resultValue: unknown = undefined;
		let callbackError: string | undefined = undefined;
		let [ok, storeError] = pcall(() => {
			this._store.UpdateAsync(guildId, (raw: unknown) => {
				updated = undefined;
				resultValue = undefined;
				callbackError = undefined;
				const [nextDoc, value] = transform(normalizeDocument(copy(raw)));
				if (nextDoc === undefined) {
					callbackError = typeIs(value, "string") ? value : "Guild request was denied.";
					return undefined;
				}
				updated = normalizeDocument(nextDoc);
				resultValue = value;
				return updated;
			});
		});
		if (!ok && RunService.IsStudio()) {
			const fallback = normalizeDocument(
				copy(this._studio.get(guildId) ?? this._cache.get(guildId) ?? emptyDocument()),
			);
			const [transformed, value] = transform(fallback);
			if (transformed !== undefined) {
				updated = normalizeDocument(transformed);
				resultValue = value;
				ok = true;
				this._studio.set(guildId, copy(updated) as CommunityDocument);
			}
		}
		if (!ok)
			return $tuple(
				false,
				"Guild records are unavailable. Try again shortly. " + tostring(storeError),
				undefined,
			);
		if (updated === undefined) return $tuple(false, callbackError ?? "Guild request was denied.", undefined);
		this._cache.set(guildId, copy(updated) as CommunityDocument);
		this._cacheAt.set(guildId, os.clock());
		if (RunService.IsStudio()) this._studio.set(guildId, copy(updated) as CommunityDocument);
		return $tuple(true, resultValue, copy(updated) as CommunityDocument);
	}

	IsBanned(guildId: string, userId: number): boolean {
		const doc = this._read(guildId);
		return doc !== undefined && doc.Bans[tostring(userId)] !== undefined;
	}

	CanJoinByTag(tag: string, userId: number): LuaTuple<[boolean, string | undefined]> {
		const guild = this._guilds._findByTag(tag);
		if (guild === undefined) return $tuple(true, undefined);
		const document = this._read(guild.Id as string);
		if (document === undefined)
			return $tuple(false, "Guild records are unavailable. Try again shortly.");
		if (document.Bans[tostring(userId)] !== undefined) return $tuple(false, "You are banned from this guild.");
		return $tuple(true, undefined);
	}

	Snapshot(guildId: string): unknown {
		const doc = this._read(guildId);
		if (doc === undefined) return undefined;
		let logo: unknown = undefined;
		for (let index = doc.Logos.size(); index >= 1; index--) {
			const candidate = doc.Logos[index - 1];
			if (candidate.Status === "approved") {
				logo = copy(candidate);
				break;
			}
		}
		return { Settings: copy(doc.Settings), Logo: logo };
	}

	private _filter(player: Player, text: string, maxLength: number): LuaTuple<[boolean, string | undefined]> {
		if (
			this._security === undefined ||
			this._security.Filter === undefined ||
			!typeIs(text, "string") ||
			text.size() > maxLength ||
			maxLength > 800
		)
			return $tuple(false, undefined);
		text = text.gsub("^%s+", "")[0];
		text = text.gsub("%s+$", "")[0];
		if (text === "") return $tuple(false, undefined);
		const [callOk, filteredOk, result] = pcall(() =>
			this._security!.Filter!.Apply(player, text, player.UserId, maxLength),
		);
		if (!callOk || filteredOk !== true || !typeIs(result, "string") || result === "")
			return $tuple(false, undefined);
		return $tuple(true, result);
	}

	private _localMembers(guildId: string): Player[] {
		const members: Player[] = [];
		for (const recipient of Players.GetPlayers()) {
			const profile = this._data.Get(recipient);
			if (profile !== undefined && isTable(profile.Guild) && profile.Guild.Id === guildId)
				members.push(recipient);
		}
		return members;
	}

	private _deliver(guildId: string, payload: unknown, document: CommunityDocument) {
		for (const recipient of this._localMembers(guildId)) {
			if (document.Bans[tostring(recipient.UserId)] === undefined)
				this._effect.FireClient(recipient, payload);
		}
	}

	private _publish(guildId: string, payload: unknown) {
		const topic = relayTopic(guildId);
		if (topic === undefined || StoreAccess.isPreview()) return;
		const [okEncode, encoded] = pcall(() =>
			HttpService.JSONEncode({ Server: game.JobId, GuildId: guildId, Payload: payload }),
		);
		let message = encoded as string;
		if (!okEncode || message.size() > RELAY_MAX_BYTES) {
			// too large to carry (long announcements): other servers re-read the document instead
			message = HttpService.JSONEncode({
				Server: game.JobId,
				GuildId: guildId,
				Refresh: (payload as Dict).Type,
			});
		}
		task.spawn(() => {
			pcall(() => MessagingService.PublishAsync(topic, message));
		});
	}

	private _onRelay(raw: unknown) {
		if (!this._alive || !typeIs(raw, "string")) return;
		const [ok, data] = pcall(() => HttpService.JSONDecode(raw));
		if (
			!ok ||
			!isTable(data) ||
			data.Server === game.JobId ||
			!typeIs(data.GuildId, "string") ||
			data.GuildId === ""
		)
			return;
		const guildId = data.GuildId;
		// another server changed this guild: the next read must hit the store
		this._cacheAt.set(guildId, 0);
		if (this._localMembers(guildId).size() === 0) return;
		const payload: Dict = isTable(data.Payload) ? data.Payload : { Type: data.Refresh, Refresh: true };
		if (!typeIs(payload.Type, "string")) return;
		payload.GuildId = guildId;
		const document = this._cache.get(guildId) ?? this._read(guildId);
		if (document !== undefined) this._deliver(guildId, payload, document);
	}

	private _broadcast(guildId: string, payload: unknown) {
		const document = this._read(guildId);
		if (document === undefined) return;
		this._deliver(guildId, payload, document);
		this._publish(guildId, payload);
	}

	Handle(player: Player, action: string, payload: unknown): unknown {
		const bag = payload as Dict;
		const profile = this._data.Get(player);
		if (profile === undefined) return { ok: false, error: "Your profile is not ready. Please try again." };
		const guildId = (isTable(profile.Guild) && truthy(profile.Guild.Id) ? profile.Guild.Id : "") as string;
		if (guildId === "") return { ok: false, error: "You are not in a guild." };
		const guild = this._guilds.GetPublic(guildId);
		if (guild === undefined) return { ok: false, error: "Guild records are unavailable. Try again shortly." };
		const [member, role] = isMember(guild, player.UserId);
		if (!member || this.IsBanned(guildId, player.UserId))
			return { ok: false, error: "You are not an active member of this guild." };
		const document = this._read(guildId);
		if (document === undefined) return { ok: false, error: "Guild records are unavailable. Try again shortly." };

		if (action === "GetGuildSettings") return { ok: true, Settings: copy(document.Settings) };
		if (action === "GetGuildLogoReview") {
			if (role !== "Leader") return { ok: false, error: "Only the guild leader can review logos." };
			const pending: GuildLogoRecord[] = [];
			for (const logo of document.Logos)
				if (logo.Status === "pending") pending.push(copy(logo) as GuildLogoRecord);
			return { ok: true, Logos: pending };
		}
		if (action === "GetGuildAnnouncements") {
			const announcements: GuildAnnouncement[] = [];
			let endIndex = document.Announcements.size();
			if (typeIs(bag.BeforeId, "string")) {
				for (const [index, entry] of pairs(document.Announcements)) {
					if (entry.Id === bag.BeforeId) {
						endIndex = index - 1;
						break;
					}
				}
			}
			const limit = math.clamp(math.floor(num(bag.Limit) ?? 50), 1, 50);
			for (let index = endIndex; index >= math.max(1, endIndex - limit + 1); index--) {
				const entry = document.Announcements[index - 1] as GuildAnnouncement | undefined;
				if (
					entry !== undefined &&
					!entry.Archived &&
					(entry.ExpiresAt === undefined || entry.ExpiresAt > os.time())
				)
					announcements.push(copy(entry) as GuildAnnouncement);
			}
			announcements.sort((left, right) => {
				if (left.Pinned !== right.Pinned) return left.Pinned;
				return left.PublishedAt > right.PublishedAt;
			});
			return { ok: true, Announcements: announcements };
		}
		if (action === "GetGuildChatHistory") {
			const messages: defined[] = [];
			const limit = math.clamp(math.floor(num(bag.Limit) ?? 50), 1, 50);
			let endIndex = document.Chat.size();
			if (typeIs(bag.BeforeId, "string")) {
				for (const [index, entry] of pairs(document.Chat))
					if (entry.Id === bag.BeforeId) {
						endIndex = index - 1;
						break;
					}
			}
			for (let index = math.max(1, endIndex - limit + 1); index <= endIndex; index++)
				messages.push(copy(document.Chat[index - 1]) as defined);
			return { ok: true, Messages: messages };
		}
		if (action === "SendGuildChat") {
			if (document.Settings.ChatEnabled !== true) return { ok: false, error: "Guild chat is disabled." };
			if (document.Mutes[tostring(player.UserId)] !== undefined)
				return { ok: false, error: "You are muted in this guild." };
			if (document.Settings.SlowMode === true && role !== "Leader") {
				const key = guildId + ":" + tostring(player.UserId);
				const last = this._chatAt.get(key) ?? 0;
				if (os.clock() - last < SLOW_MODE_SECONDS) {
					return {
						ok: false,
						error: `Slow mode is on. Wait ${math.ceil(SLOW_MODE_SECONDS - (os.clock() - last))}s.`,
					};
				}
				this._chatAt.set(key, os.clock());
			}
			const [filteredOk, filtered] = this._filter(
				player,
				(typeIs(bag.Content, "string") ? bag.Content : "") as string,
				800,
			);
			if (!filteredOk || filtered === undefined)
				return { ok: false, error: "That message could not be checked. Please try different wording." };
			const message: GuildChatMessage = {
				Id: HttpService.GenerateGUID(false),
				SpeakerUserId: player.UserId,
				SpeakerName: player.DisplayName !== "" ? player.DisplayName : player.Name,
				SpeakerRole: role,
				PublishedAt: os.time(),
				Message: filtered,
			};
			const [saved, result] = this._update(guildId, (doc) => {
				if (
					doc.Settings.ChatEnabled !== true ||
					doc.Mutes[tostring(player.UserId)] !== undefined ||
					doc.Bans[tostring(player.UserId)] !== undefined
				)
					return $tuple(undefined, "Chat is unavailable for your account.");
				doc.Chat.push(message);
				while (doc.Chat.size() > CHAT_LIMIT) doc.Chat.shift();
				return $tuple(doc, message);
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, { Type: "GuildChat", GuildId: guildId, Message: message });
			return { ok: true, message: "Guild message sent.", Message: message };
		}

		if (action === "SetGuildSettings") {
			if (role !== "Leader")
				return { ok: false, error: "Only the guild leader can change guild settings." };
			const requested = isTable(bag.Settings) ? bag.Settings : {};
			const [saved, result] = this._update(guildId, (doc) => {
				for (const [key, value] of pairs(requested)) {
					if ((DEFAULT_SETTINGS as Dict)[key as string] !== undefined && typeIs(value, "boolean"))
						doc.Settings[key as string] = value;
				}
				return $tuple(doc, copy(doc.Settings));
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, { Type: "GuildSettings", GuildId: guildId, Settings: result });
			return { ok: true, message: "Guild settings saved.", Settings: result };
		}

		if (action === "CreateGuildAnnouncement" || action === "EditGuildAnnouncement") {
			if (!canManage(role))
				return { ok: false, error: "Only leaders and officers can manage announcements." };
			if (role === "Officer" && document.Settings.OfficerAnnouncements === false)
				return { ok: false, error: "The leader has reserved announcements for themselves." };
			if (document.Settings.AnnouncementsEnabled !== true)
				return { ok: false, error: "Guild announcements are disabled." };
			const [titleOk, title] = this._filter(
				player,
				(typeIs(bag.Title, "string") ? bag.Title : "") as string,
				120,
			);
			const [bodyOk, body] = this._filter(
				player,
				(typeIs(bag.Body, "string") ? bag.Body : "") as string,
				800,
			);
			if (!titleOk || !bodyOk || title === undefined || body === undefined)
				return { ok: false, error: "That announcement could not be checked. Please try different wording." };
			const announcementId =
				action === "CreateGuildAnnouncement" ? HttpService.GenerateGUID(false) : bag.AnnouncementId;
			const [saved, result] = this._update(guildId, (doc) => {
				if (doc.Settings.AnnouncementsEnabled !== true)
					return $tuple(undefined, "Guild announcements are disabled.");
				let announcement: GuildAnnouncement | undefined = undefined;
				for (const existing of doc.Announcements)
					if (existing.Id === announcementId) {
						announcement = existing;
						break;
					}
				if (action === "CreateGuildAnnouncement") {
					announcement = {
						Id: announcementId as string,
						AuthorUserId: player.UserId,
						AuthorName: player.DisplayName !== "" ? player.DisplayName : player.Name,
						AuthorRole: role,
						PublishedAt: os.time(),
						Pinned: false,
						Archived: false,
						Title: title,
						Body: body,
					};
					doc.Announcements.push(announcement);
					while (doc.Announcements.size() > ANNOUNCEMENT_LIMIT) doc.Announcements.shift();
				} else {
					if (announcement === undefined) return $tuple(undefined, "Announcement not found.");
					announcement.Title = title;
					announcement.Body = body;
					announcement.EditedAt = os.time();
				}
				return $tuple(doc, copy(announcement));
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, {
				Type: "GuildAnnouncement",
				GuildId: guildId,
				Action: action === "CreateGuildAnnouncement" ? "Created" : "Edited",
				Announcement: result,
			});
			return {
				ok: true,
				message:
					action === "CreateGuildAnnouncement"
						? "Guild announcement published."
						: "Guild announcement updated.",
				Announcement: result,
			};
		}

		if (
			action === "PinGuildAnnouncement" ||
			action === "ArchiveGuildAnnouncement" ||
			action === "SetGuildAnnouncementExpiry"
		) {
			if (!canManage(role))
				return { ok: false, error: "Only leaders and officers can manage announcements." };
			if (role === "Officer" && document.Settings.OfficerAnnouncements === false)
				return { ok: false, error: "The leader has reserved announcements for themselves." };
			if (
				action === "SetGuildAnnouncementExpiry" &&
				bag.ExpiresAt !== undefined &&
				(bag.ExpiresAt as number) <= os.time()
			)
				return { ok: false, error: "Expiry must be a future timestamp or omitted." };
			const [saved, result] = this._update(guildId, (doc) => {
				for (const announcement of doc.Announcements) {
					if (announcement.Id === bag.AnnouncementId) {
						if (action === "PinGuildAnnouncement") announcement.Pinned = bag.Pinned !== false;
						else if (action === "ArchiveGuildAnnouncement") announcement.Archived = true;
						else announcement.ExpiresAt = bag.ExpiresAt as number | undefined;
						return $tuple(doc, copy(announcement));
					}
				}
				return $tuple(undefined, "Announcement not found.");
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, {
				Type: "GuildAnnouncement",
				GuildId: guildId,
				Action: action,
				Announcement: result,
			});
			return { ok: true, Announcement: result };
		}

		if (
			action === "MuteGuildMember" ||
			action === "UnmuteGuildMember" ||
			action === "BanGuildMember" ||
			action === "UnbanGuildMember"
		) {
			if (!canManage(role))
				return { ok: false, error: "Only leaders and officers can moderate members." };
			if (role === "Officer" && document.Settings.OfficerModeration === false)
				return { ok: false, error: "The leader has reserved moderation for themselves." };
			const targetId = tonumber(bag.UserId as string);
			if (targetId === undefined || targetId <= 0 || targetId === player.UserId)
				return { ok: false, error: "That member cannot be moderated." };
			const members = guild.Members as Dict;
			const target = members[tostring(targetId)];
			const isBan = action === "BanGuildMember" || action === "UnbanGuildMember";
			const remove = action === "UnmuteGuildMember" || action === "UnbanGuildMember";
			const targetHasBan = document.Bans[tostring(targetId)] !== undefined;
			if (
				(target === undefined && !(action === "UnbanGuildMember" && targetHasBan)) ||
				(isTable(target) && target.Role === "Leader") ||
				(role === "Officer" && isTable(target) && target.Role !== "Member")
			)
				return { ok: false, error: "That member cannot be moderated." };
			if (action === "UnbanGuildMember" && !targetHasBan)
				return { ok: false, error: "That member is not guild-banned." };
			const [saved, result] = this._update(guildId, (doc) => {
				if (isBan && action === "BanGuildMember" && doc.Bans[tostring(targetId)] !== undefined)
					return $tuple(undefined, "That member is already guild-banned.");
				const key = tostring(targetId);
				const tableToUpdate = (isBan ? doc.Bans : doc.Mutes) as Record<string, unknown>;
				if (remove) delete tableToUpdate[key];
				else if (isBan) tableToUpdate[key] = { BannedBy: player.UserId, BannedAt: os.time() };
				else tableToUpdate[key] = { MutedBy: player.UserId, MutedAt: os.time() };
				return $tuple(doc, true);
			});
			if (!saved) return { ok: false, error: result };
			if (action === "BanGuildMember") {
				const [removed, removeError] = this._guilds._update(guildId, (current) => {
					if (!isTable(current.Members) || current.Members[tostring(targetId)] === undefined)
						return current;
					delete (current.Members as Dict)[tostring(targetId)];
					return current;
				});
				if (!removed)
					return {
						ok: false,
						error: removeError ?? "Guild ban saved, but membership could not be removed.",
					};
				const targetPlayer = Players.GetPlayerByUserId(targetId);
				if (targetPlayer !== undefined && this._onBanMember !== undefined) {
					const [cleared, clearResult] = this._onBanMember(targetPlayer, guildId);
					if (!cleared)
						return {
							ok: false,
							error: "Ban was saved, but the member profile could not be refreshed: " + tostring(clearResult),
						};
				}
			}
			this._broadcast(guildId, {
				Type: "GuildModeration",
				GuildId: guildId,
				Action: action,
				TargetUserId: targetId,
			});
			return { ok: true, message: "Guild moderation updated." };
		}

		if (action === "UploadGuildLogo") {
			if (!canManage(role))
				return { ok: false, error: "Only leaders and officers can submit guild logos." };
			if (document.Settings.LogoEnabled !== true) return { ok: false, error: "Guild logos are disabled." };
			const asset = safeGuildAsset(bag.URL);
			if (asset === undefined)
				return { ok: false, error: "Use a Roblox image asset ID. Roblox platform moderation still applies." };
			const logo: GuildLogoRecord = {
				Id: HttpService.GenerateGUID(false),
				UploadedBy: player.UserId,
				UploadedAt: os.time(),
				Status: "pending",
				URL: asset,
			};
			const [saved, result] = this._update(guildId, (doc) => {
				doc.Logos.push(logo);
				while (doc.Logos.size() > LOGO_HISTORY_LIMIT) doc.Logos.shift();
				return $tuple(doc, copy(logo));
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, { Type: "GuildLogo", GuildId: guildId, Action: "Uploaded", Logo: result });
			return { ok: true, message: "Guild logo submitted for leader review.", Logo: result };
		}

		if (action === "ModerateGuildLogo") {
			if (role !== "Leader") return { ok: false, error: "Only the guild leader can review logos." };
			if (bag.Decision !== "approved" && bag.Decision !== "rejected")
				return { ok: false, error: "Choose approve or reject." };
			let reason: string | undefined = undefined;
			if (bag.Decision === "rejected") {
				// the reason is broadcast to every member, so it goes through the text filter
				const [reasonOk, filteredReason] = this._filter(
					player,
					(typeIs(bag.Reason, "string") ? bag.Reason : "") as string,
					500,
				);
				if (!reasonOk || filteredReason === undefined)
					return { ok: false, error: "A rejection reason is required (and must pass the chat filter)." };
				reason = filteredReason;
			}
			let pendingLogo: GuildLogoRecord | undefined = undefined;
			for (const logo of document.Logos) {
				if (logo.Id === bag.LogoId && logo.Status === "pending") {
					pendingLogo = copy(logo) as GuildLogoRecord;
					break;
				}
			}
			if (pendingLogo === undefined) return { ok: false, error: "Pending logo not found." };
			const [saved, result] = this._update(guildId, (doc) => {
				for (const logo of doc.Logos) {
					if (logo.Id === bag.LogoId && logo.Status === "pending") {
						logo.Status = bag.Decision as "approved" | "rejected";
						logo.RejectReason = reason;
						return $tuple(doc, copy(logo));
					}
				}
				return $tuple(undefined, "Pending logo not found.");
			});
			if (!saved) return { ok: false, error: result };
			this._broadcast(guildId, { Type: "GuildLogo", GuildId: guildId, Action: "Moderated", Logo: result });
			return {
				ok: true,
				message: bag.Decision === "approved" ? "Guild logo approved." : "Guild logo rejected.",
				Logo: result,
			};
		}

		if (action === "RenameGuild") {
			if (role !== "Leader")
				return { ok: false, error: "Only the guild leader can change the guild name." };
			const newName = typeIs(bag.NewName, "string") ? bag.NewName.gsub("^%s*(.-)%s*$", "%1")[0] : "";
			if (newName.size() < 3 || newName.size() > 24) {
				return { ok: false, error: "Guild name must be between 3 and 24 characters." };
			}
			const [updated, updateError] = this._guilds._update(guildId, (current) => {
				current.Name = newName;
				return current;
			});
			if (!updated) return { ok: false, error: updateError ?? "Could not update guild name." };
			this._broadcast(guildId, { Type: "GuildRenamed", GuildId: guildId, NewName: newName });
			return { ok: true, message: "Guild name updated successfully.", NewName: newName };
		}

		return { ok: false, error: "Unknown guild community action." };
	}

	Shutdown() {
		this._alive = false;
		for (const [, subscription] of this._relays) {
			if (typeIs(subscription, "RBXScriptConnection")) subscription.Disconnect();
		}
		this._relays.clear();
		this._cache.clear();
		this._cacheAt.clear();
		this._studio.clear();
	}
}

export = table.freeze(GuildCommunity);
