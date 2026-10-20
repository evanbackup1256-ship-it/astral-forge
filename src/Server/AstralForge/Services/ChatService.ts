import { PayloadEvent } from "../Runtime/ServerNetwork";
// Server chat channels beyond RBXGeneral:
//   friends  : one TextChannel that only delivers between Roblox friends in this server
//   whispers : per-pair TextChannels created on request (Roblox filters and respects privacy)
//   global   : filtered text relayed across servers through sharded MemoryStore sorted maps
//              (see ChatRules: polling costs a fixed amount per server; broadcasting does not scale)
import ChatRules from "../../../Shared/AstralForge/Shared/ChatRules";
import StoreAccess from "../Modules/StoreAccess";

const Players = game.GetService("Players");
const HttpService = game.GetService("HttpService");
const MemoryStoreService = game.GetService("MemoryStoreService");
const TextChatService = game.GetService("TextChatService");
const TextService = game.GetService("TextService");

const DELIVER_PER_FLUSH = 8; // busy periods sample global chat instead of flooding every client
const WHISPER_LIMIT = 24; // open whisper channels per player
const HISTORY = 30;
type Dict = Record<string, unknown>;
interface Entry { Id: string; UserId: number; Name: string; Display: string; Text: string; At: number }
interface DataApi { Get(player: Player): Dict | undefined }
const isDict = (value: unknown): value is Dict => typeIs(value, "table");
const pairKey = (a: number, b: number) => a < b ? `${a}:${b}` : `${b}:${a}`;

class ChatService {
	private _alive = true;
	private _friends = new Map<string, boolean>();
	private _canChat = new Map<number, boolean>();
	private _lastGlobal = new Map<number, number>();
	private _whispers = new Map<number, Map<string, boolean>>();
	private _outbox = new Array<Entry>();
	private _inbox = new Array<Entry>();
	private _history = new Array<Entry>();
	private _maps = new Map<number, MemoryStoreSortedMap>();
	private _seen = new Map<number, string>(); // newest key already read from each map
	private _sequence = 0;
	private _shard = ChatRules.shardFor(game.JobId !== "" ? game.JobId : "studio");
	private _connections = new Array<RBXScriptConnection>();
	private _channels?: Instance;
	private _friendsChannel?: TextChannel;

	constructor(private _effect: PayloadEvent, private _data?: DataApi) { task.spawn(() => this._boot()); }
	private _boot() {
		const channels = TextChatService.WaitForChild("TextChannels", 30);
		if (!this._alive || !channels) return;
		this._channels = channels;
		let friends = channels.FindFirstChild(ChatRules.FRIENDS_CHANNEL);
		if (!friends) { const created = new Instance("TextChannel"); created.Name = ChatRules.FRIENDS_CHANNEL; created.Parent = channels; friends = created; }
		const friendsChannel = friends as TextChannel;
		this._friendsChannel = friendsChannel;
		friendsChannel.ShouldDeliverCallback = (message, target) => {
			const source = message.TextSource;
			return source !== undefined && (source.UserId === target.UserId || this._areFriends(source.UserId, target.UserId));
		};
		this._connections.push(Players.PlayerAdded.Connect((player) => this._join(player)));
		this._connections.push(Players.PlayerRemoving.Connect((player) => this._leave(player)));
		for (const player of Players.GetPlayers()) task.spawn(() => this._join(player));
		if (!StoreAccess.isPreview()) for (let shard = 1; shard <= ChatRules.GLOBAL_SHARDS; shard++) {
			const [ok, map] = pcall(() => MemoryStoreService.GetSortedMap(ChatRules.mapName(shard)));
			if (ok) this._maps.set(shard, map);
		}
		task.spawn(() => { while (this._alive) { task.wait(ChatRules.GLOBAL_TICK); this._flush(); } });
	}
	private _areFriends(a: number, b: number) { return this._friends.get(pairKey(a, b)) === true; }
	private _join(player: Player) {
		if (!this._alive) return;
		if (this._friendsChannel) pcall(() => this._friendsChannel!.AddUserAsync(player.UserId));
		const [okChat, canChat] = pcall(() => (TextChatService as unknown as { CanUserChatAsync(userId: number): boolean }).CanUserChatAsync(player.UserId));
		this._canChat.set(player.UserId, okChat && canChat === true);
		for (const other of Players.GetPlayers()) if (other !== player) {
			const [ok, friends] = pcall(() => (player as unknown as { IsFriendsWith(userId: number): boolean }).IsFriendsWith(other.UserId));
			if (ok && friends) this._friends.set(pairKey(player.UserId, other.UserId), true);
		}
		if (this._history.size() > 0 && player.Parent === Players) this._effect.fire(player, { Type: "ChatGlobal", Messages: this._history, Backlog: true });
	}
	private _leave(player: Player) {
		const userId = player.UserId;
		this._canChat.delete(userId); this._lastGlobal.delete(userId);
		for (const [key] of this._friends) { const [a, b] = key.match("^(%d+):(%d+)$"); if (tonumber(a) === userId || tonumber(b) === userId) this._friends.delete(key); }
		const open = this._whispers.get(userId); this._whispers.delete(userId);
		if (this._channels && open) for (const [name] of open) {
			this._channels.FindFirstChild(name)?.Destroy();
			const peer = ChatRules.whisperPeer(name, userId); if (peer !== undefined) this._whispers.get(peer)?.delete(name);
		}
	}
	OpenWhisper(player: Player, payload: unknown) {
		const targetId = isDict(payload) ? tonumber(payload.UserId as string) : undefined;
		if (targetId === undefined || targetId === player.UserId) return { ok: false, error: "Pick another player to whisper." };
		const target = Players.GetPlayerByUserId(targetId); if (!target) return { ok: false, error: "That player is no longer in this server." };
		if (!this._channels) return { ok: false, error: "Chat is still starting. Try again in a moment." };
		if (this._canChat.get(player.UserId) === false) return { ok: false, error: "Chat is turned off for your account." };
		const name = ChatRules.whisperChannel(player.UserId, targetId);
		// the target's "whispers from friends only" setting; an existing conversation stays open
		const profile = this._data?.Get(target); const settings = profile && isDict(profile.Settings) ? profile.Settings : undefined;
		const friendsOnly = settings?.WhispersFriendsOnly;
		let existing = this._channels.FindFirstChild(name);
		if (!existing && typeIs(friendsOnly, "number") && friendsOnly >= 0.5 && !this._areFriends(player.UserId, targetId)) return { ok: false, error: `${target.DisplayName} only takes whispers from friends.` };
		if (!existing) {
			const mine = this._whispers.get(player.UserId) ?? new Map<string, boolean>();
			if (mine.size() >= WHISPER_LIMIT) return { ok: false, error: "Too many whispers open. Close one first." };
			const channel = new Instance("TextChannel"); channel.Name = name; channel.Parent = this._channels;
			const [okA] = pcall(() => channel.AddUserAsync(player.UserId)); const [okB, sourceB] = pcall(() => channel.AddUserAsync(targetId));
			if (!okA || !okB || !sourceB) { channel.Destroy(); return { ok: false, error: "That player can't receive whispers right now." }; }
			existing = channel; this._whispers.set(player.UserId, mine); mine.set(name, true);
			const theirs = this._whispers.get(targetId) ?? new Map<string, boolean>(); theirs.set(name, true); this._whispers.set(targetId, theirs);
		}
		return { ok: true, Channel: name, UserId: targetId };
	}
	SendGlobal(player: Player, payload: unknown) {
		const raw = isDict(payload) ? payload.Text : undefined;
		if (!typeIs(raw, "string")) return { ok: false, error: "Type a message first." };
		const text = ChatRules.trim(raw); const [length] = utf8.len(text);
		if (text === "" || length === false || length > ChatRules.MAX_INPUT) return { ok: false, error: "Message is empty or too long." };
		const now = os.clock(); const last = this._lastGlobal.get(player.UserId);
		if (last !== undefined && now - last < ChatRules.GLOBAL_COOLDOWN) return { ok: false, error: `Global chat cools down for ${math.ceil(ChatRules.GLOBAL_COOLDOWN - (now - last))}s.` };
		if (this._canChat.get(player.UserId) !== true) { const [ok, can] = pcall(() => (TextChatService as unknown as { CanUserChatAsync(userId: number): boolean }).CanUserChatAsync(player.UserId)); this._canChat.set(player.UserId, ok && can === true); if (!this._canChat.get(player.UserId)) return { ok: false, error: "Chat is turned off for your account." }; }
		this._lastGlobal.set(player.UserId, now);
		const [ok, filtered] = pcall(() => TextService.FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat).GetNonChatStringForBroadcastAsync());
		if (!ok || !typeIs(filtered, "string") || filtered === "") return { ok: false, error: "Roblox could not filter that message. Try again." };
		const entry: Entry = { Id: HttpService.GenerateGUID(false), UserId: player.UserId, Name: player.Name, Display: player.DisplayName, Text: filtered, At: os.time() };
		this._deliver([entry]); if (!StoreAccess.isPreview()) this._outbox.push(entry); return { ok: true };
	}
	private _remember(entries: Entry[]) { for (const entry of entries) { this._history.push(entry); while (this._history.size() > HISTORY) this._history.shift(); } }
	private _deliver(entries: Entry[]) { if (entries.size() === 0) return; this._remember(entries); for (const player of Players.GetPlayers()) if (this._canChat.get(player.UserId) === true) this._effect.fire(player, { Type: "ChatGlobal", Messages: entries }); }
	// One tick: write at most one batch to this server's map, then read the newest entries of every map.
	private _flush() {
		const own = this._maps.get(this._shard);
		if (own && this._outbox.size() > 0) { const [batch, encoded] = ChatRules.takeBatch(this._outbox, (list: unknown) => HttpService.JSONEncode({ S: game.JobId, M: list })); if (batch.size() > 0 && encoded) { this._sequence++; const key = ChatRules.entryKey(DateTime.now().UnixTimestampMillis, game.JobId.sub(1, 12) + this._sequence); pcall(() => own.SetAsync(key, encoded, ChatRules.GLOBAL_TTL)); } }
		for (const [shard, map] of this._maps) { const [ok, items] = pcall(() => map.GetRangeAsync(Enum.SortDirection.Descending, ChatRules.GLOBAL_READ_COUNT)); if (ok && typeIs(items, "table")) { const seen = this._seen.get(shard); let newest = seen; for (let i = items.size() - 1; i >= 0; i--) { const item = items[i]; const key = typeIs(item, "table") ? item.key : undefined; if (typeIs(key, "string") && (seen === undefined || key > seen)) { if (seen !== undefined) this._onRelay(item.value); if (newest === undefined || key > newest) newest = key; } } this._seen.set(shard, newest ?? ""); } }
		if (this._inbox.size() > 0) { const take = new Array<Entry>(); for (let i = math.max(0, this._inbox.size() - DELIVER_PER_FLUSH); i < this._inbox.size(); i++) take.push(this._inbox[i]); this._inbox.clear(); this._deliver(take); }
	}
	private _onRelay(raw: unknown) {
		if (!this._alive || !typeIs(raw, "string")) return;
		const [ok, decoded] = pcall(() => HttpService.JSONDecode(raw)); if (!ok || !isDict(decoded) || decoded.S === game.JobId || !typeIs(decoded.M, "table")) return;
		for (const value of decoded.M as unknown[]) if (isDict(value) && typeIs(value.Id, "string") && value.Id.size() <= 64 && typeIs(value.UserId, "number") && typeIs(value.Name, "string") && value.Name.size() <= 32 && typeIs(value.Display, "string") && value.Display.size() <= 64 && typeIs(value.Text, "string") && value.Text.size() <= 640 && typeIs(value.At, "number")) { this._inbox.push(value as unknown as Entry); if (this._inbox.size() > DELIVER_PER_FLUSH * 4) this._inbox.shift(); }
	}
	Shutdown() { this._alive = false; for (const connection of this._connections) connection.Disconnect(); this._connections.clear(); this._maps.clear(); }
}

export = ChatService;
