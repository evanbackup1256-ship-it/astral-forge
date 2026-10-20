// Pure chat rules shared by the server relay and the client chat hook.
// No Roblox services here so the rules can be exercised from Lune.

interface Command {
	kind: string;
	target?: string;
	body?: string;
}

interface CommandInfo {
	name: string;
	usage: string;
	hint: string;
}

interface Candidate {
	userId: number;
	name: string;
	displayName: string;
}

interface Suggestion {
	kind: string;
	label: string;
	detail: string;
	fill: string;
	userId?: number;
}

interface SearchRecord {
	text: string;
	username: string;
	displayName: string;
	channel: string;
}

const MAX_INPUT = 160;
const GLOBAL_COOLDOWN = 6;
// Global chat crosses servers through MemoryStore sorted maps, not MessagingService: a broadcast
// topic costs (publishes x servers) against the experience-wide receive budget, while polling costs
// a fixed amount per server. Each server writes one batch per tick to its own map and reads the
// newest entries of every map.
const GLOBAL_SHARDS = 4;
const GLOBAL_TICK = 3; // seconds between a server's write and read passes
const GLOBAL_READ_COUNT = 6; // newest entries read from each map per tick
const GLOBAL_TTL = 120; // seconds an entry lives in its map
const RELAY_MAX_BYTES = 4000;
const FRIENDS_CHANNEL = "AFFriends";
const SERVER_CHANNEL = "RBXGeneral";
const WHISPER_PREFIX = "AFWhisper:";
const CREW_PREFIX = "AFCrew:";
const CHANNELS: ReadonlyArray<string> = table.freeze(["all", "global", "server", "crew", "friends", "whispers"]);

// True when `text` @mentions the player by username or display name (case-insensitive, whole word).
function mentions(text: unknown, name: unknown, displayName: unknown): boolean {
	if (!typeIs(text, "string") || text.find("@", 1, true)[0] === undefined) {
		return false;
	}
	const lowered = text.lower() + " ";
	for (const candidate of [name, displayName] as unknown[]) {
		if (typeIs(candidate, "string") && candidate !== "") {
			const needle = "@" + candidate.lower();
			let start = 1;
			while (true) {
				const [first, last] = lowered.find(needle, start, true);
				if (first === undefined) break;
				const before = first > 1 ? lowered.sub(first - 1, first - 1) : " ";
				const after = lowered.sub((last as number) + 1, (last as number) + 1);
				if (
					before.match("[%w_]")[0] === undefined &&
					after.match("[%w_]")[0] === undefined
				) {
					return true;
				}
				start = (last as number) + 1;
			}
		}
	}
	return false;
}

// Short local clock for a message time ("14:05").
function clock(at: unknown): string {
	if (!typeIs(at, "number") || at !== at) {
		return "";
	}
	return os.date("%H:%M", math.floor(at)) as string;
}

// "Who can reach you" settings (0 anyone, 0.5 friends, 1 nobody) with the default for a missing value.
function allows(policy: unknown, isFriend: boolean): boolean {
	const value = typeIs(policy, "number") && policy === policy ? policy : 0;
	if (value < 0.25) {
		return true;
	} else if (value < 0.75) {
		return isFriend;
	}
	return false;
}

function crewChannel(crewId: string): string {
	return CREW_PREFIX + crewId;
}

function isCrewChannel(name: unknown): boolean {
	return typeIs(name, "string") && name.sub(1, CREW_PREFIX.size()) === CREW_PREFIX;
}

const COMMANDS: ReadonlyArray<CommandInfo> = table.freeze([
	table.freeze({ name: "w", usage: "/w name message", hint: "Whisper a player in this server" }),
	table.freeze({ name: "r", usage: "/r message", hint: "Reply to your last whisper" }),
	table.freeze({ name: "g", usage: "/g message", hint: "Send to global chat" }),
	table.freeze({ name: "s", usage: "/s message", hint: "Send to this server" }),
	table.freeze({ name: "f", usage: "/f message", hint: "Send to friends here" }),
	table.freeze({ name: "c", usage: "/c message", hint: "Send to your crew" }),
	table.freeze({ name: "mute", usage: "/mute name", hint: "Hide a player's messages" }),
	table.freeze({ name: "unmute", usage: "/unmute name", hint: "Show a player's messages again" }),
	table.freeze({ name: "clear", usage: "/clear", hint: "Clear messages on this device" }),
	table.freeze({ name: "help", usage: "/help", hint: "List chat shortcuts" }),
]);

const ALIASES: Record<string, string> = table.freeze({
	w: "w",
	whisper: "w",
	msg: "w",
	pm: "w",
	dm: "w",
	r: "r",
	reply: "r",
	g: "g",
	global: "g",
	s: "s",
	server: "s",
	f: "f",
	friends: "f",
	c: "c",
	crew: "c",
	party: "c",
	mute: "mute",
	unmute: "unmute",
	clear: "clear",
	help: "help",
});

function trim(text: string): string {
	return text.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
}

// roblox-ts string.match returns string|number|undefined for each capture.
function cap1(text: string, pattern: string): string | undefined {
	// Keep the LuaTuple type: casting it to an array makes roblox-ts index the first capture as a table.
	const [v] = text.match(pattern);
	return typeIs(v, "string") ? v : undefined;
}

function cap2(text: string, pattern: string): LuaTuple<[string | undefined, string | undefined]> {
	const [a, b] = text.match(pattern);
	return $tuple(typeIs(a, "string") ? a : undefined, typeIs(b, "string") ? b : undefined);
}

// Splits "/w name hello" into { kind = "w", target = "name", body = "hello" }.
// Plain text returns kind = "say". Unknown slash words return kind = "unknown".
function parse(raw: unknown): Command {
	if (!typeIs(raw, "string")) return { kind: "empty" };
	const text = trim(raw);
	if (text === "") return { kind: "empty" };
	if (text.sub(1, 1) !== "/") return { kind: "say", body: text };
	const [word, rest] = cap2(text, "^/(%S+)%s*(.*)$");
	if (word === undefined) return { kind: "unknown", body: text };
	const kind = ALIASES[word.lower()];
	if (kind === undefined) return { kind: "unknown", target: word, body: rest };
	if (kind === "w") {
		const [target, body] = cap2(rest ?? "", "^@?(%S+)%s*(.*)$");
		return { kind: "w", target, body: body && body !== "" ? body : undefined };
	} else if (kind === "mute" || kind === "unmute") {
		const [target] = cap2(rest ?? "", "^@?(%S+)");
		return { kind: kind, target };
	}
	return { kind, body: rest && rest !== "" ? rest : undefined };
}

function startsWith(text: string, prefix: string): boolean {
	return text.lower().sub(1, prefix.size()) === prefix.lower();
}

function rankPlayers(partial: string, players: Candidate[], limit: number): Candidate[] {
	const hits: { score: number; candidate: Candidate }[] = [];
	for (const candidate of players) {
		let score = 0;
		if (partial === "") {
			score = 1;
		} else if (startsWith(candidate.name, partial)) {
			score = 4;
		} else if (startsWith(candidate.displayName, partial)) {
			score = 3;
		} else if (candidate.name.lower().find(partial.lower(), 1, true)[0] !== undefined) {
			score = 2;
		} else if (candidate.displayName.lower().find(partial.lower(), 1, true)[0] !== undefined) {
			score = 1;
		}
		if (score > 0) hits.push({ score, candidate });
	}
	hits.sort((a, b) => {
		if (a.score !== b.score) return a.score > b.score;
		return a.candidate.name.lower() < b.candidate.name.lower();
	});
	const out: Candidate[] = [];
	for (let index = 0; index < math.min(limit, hits.size()); index++) {
		out[index] = hits[index].candidate;
	}
	return out;
}

// Autocomplete for the draft. Covers command names, "/w partial" and "@partial" at the end of the draft.
function suggest(draft: unknown, players: Candidate[], limit?: number): Suggestion[] {
	const cap = limit ?? 5;
	if (!typeIs(draft, "string") || draft === "") return [];
	const out: Suggestion[] = [];
	const commandWord = cap1(draft, "^/(%S*)$");
	if (commandWord !== undefined) {
		for (const info of COMMANDS) {
			if (startsWith(info.name, commandWord) && out.size() < cap) {
				out.push({
					kind: "command",
					label: info.usage,
					detail: info.hint,
					fill: "/" + info.name + " ",
				});
			}
		}
		return out;
	}
	const [verb, partial] = cap2(draft, "^/(%a+)%s+@?(%S*)$");
	if (verb !== undefined) {
		const kind = ALIASES[verb.lower()];
		if (kind === "w" || kind === "mute" || kind === "unmute") {
			for (const candidate of rankPlayers(partial ?? "", players, cap)) {
				out.push({
					kind: "player",
					label: candidate.displayName,
					detail: "@" + candidate.name,
					fill: "/" + verb.lower() + " " + candidate.name + " ",
					userId: candidate.userId,
				});
			}
		}
		return out;
	}
	const [head, mention] = cap2(draft, "^(.-)@(%w*)$");
	if (
		mention !== undefined &&
		head !== undefined &&
		(head === "" || cap1(head, "%s$") !== undefined)
	) {
		for (const candidate of rankPlayers(mention, players, cap)) {
			out.push({
				kind: "mention",
				label: candidate.displayName,
				detail: "@" + candidate.name,
				fill: head + "@" + candidate.name + " ",
				userId: candidate.userId,
			});
		}
	}
	return out;
}

function findPlayer(name: unknown, players: Candidate[]): Candidate | undefined {
	if (!typeIs(name, "string") || name === "") return undefined;
	const lowered = name.lower();
	for (const candidate of players) {
		if (candidate.name.lower() === lowered) return candidate;
	}
	for (const candidate of players) {
		if (candidate.displayName.lower() === lowered) return candidate;
	}
	const ranked = rankPlayers(name, players, 2);
	// a partial only resolves when it is unambiguous
	if (ranked.size() === 1) return ranked[0];
	if (
		ranked.size() > 1 &&
		startsWith(ranked[0].name, name) &&
		!startsWith(ranked[1].name, name)
	) {
		return ranked[0];
	}
	return undefined;
}

function whisperChannel(a: number, b: number): string {
	const low = math.min(a, b);
	const high = math.max(a, b);
	return "%s%d_%d".format(WHISPER_PREFIX, low, high);
}

function whisperPeer(channelName: unknown, selfId: number): number | undefined {
	if (!typeIs(channelName, "string")) return undefined;
	const [lowStr, highStr] = cap2(channelName, "^" + WHISPER_PREFIX + "(%d+)_(%d+)$");
	if (lowStr === undefined || highStr === undefined) return undefined;
	const a = tonumber(lowStr) as number;
	const b = tonumber(highStr) as number;
	if (a === selfId) return b;
	if (b === selfId) return a;
	return undefined;
}

// Stable shard for a server id: a server always writes the same map, so writes spread evenly.
function shardFor(jobId: string, shards?: number): number {
	const count = math.max(1, math.floor(shards ?? GLOBAL_SHARDS));
	let hash = 5381;
	// string.byte is 1-based; starting at 0 skipped the last byte and changed every shard.
	for (let index = 1; index <= jobId.size(); index++) {
		hash = (hash * 33 + (jobId.byte(index)[0] ?? 0)) % 2147483647;
	}
	return hash % count + 1;
}

function mapName(shard: number): string {
	return "AF_GlobalChat_v2_" + tostring(shard);
}

// Sorted-map keys order by time: zero-padded milliseconds, then a per-server suffix for uniqueness.
function entryKey(millis: number, suffix: string): string {
	return "%015d_%s".format(math.max(0, math.floor(millis)), suffix.sub(1, 24));
}

// MemoryStore requests one server spends per minute, at most (one write and every map read per tick).
function requestsPerServerMinute(): number {
	return (60 / GLOBAL_TICK) * (1 + GLOBAL_SHARDS);
}

// Roblox's documented experience-wide MemoryStore quota.
function memoryStoreQuota(players: number): number {
	return 1000 + 100 * math.max(0, players);
}

// Takes as many queued entries as fit under maxBytes once encoded; the rest wait for the next flush.
function takeBatch(
	queue: unknown[],
	encode: (batch: unknown[]) => string,
	maxBytes?: number,
): LuaTuple<[unknown[], string | undefined]> {
	const budget = maxBytes ?? RELAY_MAX_BYTES;
	const safeQueue = queue as defined[];
	const batch: defined[] = [];
	let encoded: string | undefined = undefined;
	while (safeQueue.size() > 0) {
		batch.push(safeQueue[0]);
		const attempt = encode(batch as unknown[]);
		if (attempt.size() > budget) {
			batch.remove(batch.size() - 1);
			break;
		}
		encoded = attempt;
		safeQueue.remove(0);
	}
	if (batch.size() === 0 && safeQueue.size() > 0) {
		// a single entry that can never fit is dropped so it cannot block the queue
		safeQueue.remove(0);
	}
	return $tuple(batch as unknown[], encoded);
}

function matches(record: SearchRecord, query: unknown): boolean {
	if (!typeIs(query, "string")) return true;
	let needle = trim(query).lower();
	if (needle === "") return true;
	const from = cap1(needle, "^from:(%S+)");
	if (from !== undefined) {
		const rest = trim(needle.sub(from.size() + 6));
		if (!startsWith(record.username, from) && !startsWith(record.displayName, from)) return false;
		if (rest === "") return true;
		needle = rest;
	}
	const channel = cap1(needle, "^in:(%S+)");
	if (channel !== undefined) {
		const rest = trim(needle.sub(channel.size() + 4));
		if (!startsWith(record.channel, channel)) return false;
		if (rest === "") return true;
		needle = rest;
	}
	return (
		record.text.lower().find(needle, 1, true)[0] !== undefined ||
		record.username.lower().find(needle, 1, true)[0] !== undefined ||
		record.displayName.lower().find(needle, 1, true)[0] !== undefined
	);
}

// Which category tab a record belongs to.
function inTab(channel: string, tab: string): boolean {
	if (tab === "all") return true;
	if (tab === "whispers") return channel === "whisper";
	if (channel === "system") return true;
	return channel === tab;
}

// Sent-message recall (Up / Down in the chat box). History is newest first; index 0 is the
// fresh draft, 1 the last message sent, and so on.
const RECALL_LIMIT = 20;

function remember(history: string[], text: unknown): void {
	if (!typeIs(text, "string")) return;
	const clean = trim(text);
	if (clean === "" || history[0] === clean) return;
	history.unshift(clean);
	while (history.size() > RECALL_LIMIT) {
		history.pop();
	}
}

function recall(history: string[], index: number, direction: number): LuaTuple<[number, string]> {
	const delta = direction > 0 ? 1 : direction < 0 ? -1 : 0;
	const nextIndex = math.clamp(index + delta, 0, history.size());
	return $tuple(nextIndex, nextIndex === 0 ? "" : history[nextIndex - 1]);
}

const ChatRules = {
	MAX_INPUT,
	GLOBAL_COOLDOWN,
	GLOBAL_SHARDS,
	GLOBAL_TICK,
	GLOBAL_READ_COUNT,
	GLOBAL_TTL,
	RELAY_MAX_BYTES,
	FRIENDS_CHANNEL,
	SERVER_CHANNEL,
	WHISPER_PREFIX,
	CREW_PREFIX,
	CHANNELS,
	mentions,
	clock,
	allows,
	crewChannel,
	isCrewChannel,
	COMMANDS,
	trim,
	parse,
	suggest,
	findPlayer,
	whisperChannel,
	whisperPeer,
	shardFor,
	mapName,
	entryKey,
	requestsPerServerMinute,
	memoryStoreQuota,
	takeBatch,
	matches,
	inTab,
	RECALL_LIMIT,
	remember,
	recall,
};

export = table.freeze(ChatRules);
