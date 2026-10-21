// Server-side record of security flags with escalating responses.
//
// Every flag adds weight to a per-player score that halves every HALF_LIFE seconds, so one bad
// moment (a lag spike that bursts queued requests, a rubber-band teleport) fades on its own.
// The response comes from the decayed score:
//   below THROTTLE  -> "log"      the flag is recorded and shown to admins
//   THROTTLE+       -> "throttle" the firewall refills that player's buckets at a quarter rate
//   KICK+           -> "kick"     only when the evidence is corroborated: at least two different
//                                 flag kinds, or the score has stayed above THROTTLE for
//                                 SUSTAIN seconds. A single noisy signal can't kick anyone.
// Admins read Recent() through the admin panel state.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";

export type Response = "log" | "throttle" | "kick";

export interface FlagEntry {
	At: number;
	UserId: number;
	Name: string;
	Kind: string;
	Weight: number;
	Score: number;
	Response: Response;
	Detail: string;
}

interface PlayerRecord {
	score: number;
	at: number;
	kinds: Record<string, number>;
	throttledSince?: number;
	response: Response;
}

export const HALF_LIFE = 90;
export const THROTTLE = 8;
export const KICK = 20;
export const SUSTAIN = 45;
const KIND_MEMORY = 300;
const RECENT_LIMIT = 200;

export class SecurityLedger {
	private records = new Map<number, PlayerRecord>();
	private recent: FlagEntry[] = [];
	private counters = new Map<string, number[]>();

	constructor(private readonly clock: () => number = os.clock, private readonly wall: () => number = os.time) {}

	private record(userId: number, now: number): PlayerRecord {
		let rec = this.records.get(userId);
		if (rec === undefined) {
			rec = { score: 0, at: now, kinds: {}, response: "log" };
			this.records.set(userId, rec);
		}
		const elapsed = math.max(0, now - rec.at);
		rec.score *= 0.5 ** (elapsed / HALF_LIFE);
		rec.at = now;
		for (const [kind, at] of pairs(rec.kinds)) {
			if (now - at > KIND_MEMORY) {
				delete rec.kinds[kind];
			}
		}
		if (rec.score < THROTTLE) {
			rec.throttledSince = undefined;
		}
		return rec;
	}

	private respond(rec: PlayerRecord, now: number): Response {
		if (rec.score >= THROTTLE && rec.throttledSince === undefined) {
			rec.throttledSince = now;
		}
		let kinds = 0;
		for (const _ of pairs(rec.kinds)) {
			kinds += 1;
		}
		const sustained = rec.throttledSince !== undefined && now - rec.throttledSince >= SUSTAIN;
		if (rec.score >= KICK && (kinds >= 2 || sustained)) {
			return "kick";
		}
		return rec.score >= THROTTLE ? "throttle" : "log";
	}

	/** Records a flag and returns the response the caller should apply. */
	Flag(userId: number, name: string, kind: string, weight: number, detail?: string): Response {
		const now = this.clock();
		const rec = this.record(userId, now);
		rec.score += math.max(0, weight);
		rec.kinds[kind] = now;
		const response = this.respond(rec, now);
		rec.response = response;
		this.recent.unshift({
			At: this.wall(),
			UserId: userId,
			Name: name,
			Kind: kind,
			Weight: weight,
			Score: math.floor(rec.score * 10 + 0.5) / 10,
			Response: response,
			Detail: string.sub(detail ?? "", 1, 120),
		});
		while (this.recent.size() > RECENT_LIMIT) {
			this.recent.pop();
		}
		return response;
	}

	/** Current response level without adding a flag (the score decays as time passes). */
	Level(userId: number): Response {
		if (!this.records.has(userId)) {
			return "log";
		}
		const now = this.clock();
		const rec = this.record(userId, now);
		rec.response = this.respond(rec, now);
		return rec.response;
	}

	Score(userId: number): number {
		if (!this.records.has(userId)) {
			return 0;
		}
		return this.record(userId, this.clock()).score;
	}

	/**
	 * Counts an event in a sliding window and returns true once the count passes `limit`
	 * (and on each event after that, until the window clears).
	 */
	Burst(key: string, windowSeconds: number, limit: number): boolean {
		const now = this.clock();
		const list = this.counters.get(key) ?? [];
		const kept = list.filter((at) => now - at < windowSeconds);
		kept.push(now);
		this.counters.set(key, kept);
		if (this.counters.size() > 4096) {
			this.counters.clear();
		}
		return kept.size() > limit;
	}

	Recent(limit = 20): FlagEntry[] {
		const out: FlagEntry[] = [];
		for (let i = 0; i < math.min(limit, this.recent.size()); i++) {
			out.push(this.recent[i]);
		}
		return out;
	}

	/** This player's flags from the recent log, newest first. */
	ForUser(userId: number, limit = 25): FlagEntry[] {
		const out: FlagEntry[] = [];
		for (const entry of this.recent) {
			if (entry.UserId === userId) {
				out.push(entry);
				if (out.size() >= limit) break;
			}
		}
		return out;
	}

	/**
	 * One row per player seen in the recent log, highest live score first: the flag-log view
	 * the admin panel lists before drilling into a player with ForUser.
	 */
	Summary(limit = 25): PlayerSummary[] {
		const rows = new Map<number, PlayerSummary>();
		for (const entry of this.recent) {
			let row = rows.get(entry.UserId);
			if (row === undefined) {
				row = {
					UserId: entry.UserId,
					Name: entry.Name,
					Flags: 0,
					Kinds: {},
					LastAt: entry.At,
					LastKind: entry.Kind,
					Score: math.floor(this.Score(entry.UserId) * 10 + 0.5) / 10,
					Level: this.Level(entry.UserId),
				};
				rows.set(entry.UserId, row);
			}
			row.Flags += 1;
			row.Kinds[entry.Kind] = (row.Kinds[entry.Kind] ?? 0) + 1;
		}
		const out: PlayerSummary[] = [];
		for (const [, row] of rows) out.push(row);
		out.sort((a, b) => (a.Score !== b.Score ? a.Score > b.Score : a.LastAt > b.LastAt));
		while (out.size() > limit) out.pop();
		return out;
	}

	Forget(userId: number): void {
		this.records.delete(userId);
	}
}

export interface PlayerSummary {
	UserId: number;
	Name: string;
	Flags: number;
	Kinds: Record<string, number>;
	LastAt: number;
	LastKind: string;
	Score: number;
	Level: Response;
}

interface LogApi {
	Every(this: void, key: string, seconds: number, scope: string, message: string): boolean;
	Warn(this: void, scope: string, message: string, params?: Record<string, unknown>): void;
}

/** The server's ledger, shared by the firewall, anti-cheat, character checks and the admin panel. */
export const Ledger = new SecurityLedger();

const Players = game.GetService("Players");
const ModuleLog = require(script.Parent!.Parent!.Parent!.WaitForChild("ModuleLog") as ModuleScript) as LogApi;

/**
 * Flags a player on the shared ledger, logs it, and applies the response: "kick" disconnects
 * them. Returns the response so callers can also throttle or reject the current request.
 */
export function Report(player: Player, kind: string, weight: number, detail?: string, ledger: SecurityLedger = Ledger): Response {
	const response = ledger.Flag(player.UserId, player.Name, kind, weight, detail);
	const score = ledger.Score(player.UserId);
	pcall(() => player.SetAttribute("AF_SecurityScore", math.floor(score)));
	ModuleLog.Every(
		string.format("flag:%d:%s", player.UserId, kind),
		10,
		"Security",
		string.format(
			"%s flagged %s (+%s, score %.1f, %s)%s",
			player.Name,
			kind,
			tostring(weight),
			score,
			response,
			detail !== undefined && detail !== "" ? ": " + detail : "",
		),
	);
	if (response === "kick" && player.Parent === Players) {
		ModuleLog.Warn("Security", "kicking player after corroborated flags", { Player: player, Score: score, Kind: kind });
		player.Kick(T("SecurityLedger.AstralForgeDisconnectedYouAfter"));
	}
	return response;
}
