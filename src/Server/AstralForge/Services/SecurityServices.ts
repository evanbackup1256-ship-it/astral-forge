import { deepCopy, Dict, isFiniteNumber, isTable, num, req, SharedFolder } from "./LuaInterop";

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`SecurityServices: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`SecurityServices: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

__defs["ProfileIntegrity"] = () => {
	return () => {
		const MOD_ADLER = 65521;
		const JOURNAL_LIMIT = 12;
		const MAX_NODES = 24000;
		const ALGORITHM = "AFX-ADLER32-V1";


		// Keys sort by type name first (boolean < number < string < anything else), then by value
		// (numbers numerically, everything else by tostring). Strings and numbers - nearly every key -
		// are sorted with the built-in comparison, which gives the same order far faster than a Lua
		// comparator on big bags like the 6,000-node star grid.
		function byText(left: unknown, right: unknown): boolean {
			return tostring(left) < tostring(right);
		}
		function orderedKeys(source: Dict): unknown[] {
			const numbers: defined[] = [];
			const strings: defined[] = [];
			let others: defined[] | undefined = undefined;
			for (const [key] of pairs(source)) {
				const kind = typeOf(key);
				if (kind === "string") {
					strings.push(key);
				} else if (kind === "number") {
					numbers.push(key);
				} else {
					others = others ?? [];
					others.push(key);
				}
			}
			numbers.sort();
			strings.sort();
			if (others === undefined) {
				for (const key of strings) numbers.push(key);
				return numbers;
			}
			const rest = others;
			rest.sort((left, right) => {
				const leftType = typeOf(left);
				const rightType = typeOf(right);
				if (leftType !== rightType) return leftType < rightType;
				return byText(left, right);
			});
			const keys: defined[] = [];
			for (const key of rest) if (typeOf(key) < "number") keys.push(key);
			for (const key of numbers) keys.push(key);
			for (const key of rest) if (typeOf(key) > "number" && typeOf(key) < "string") keys.push(key);
			for (const key of strings) keys.push(key);
			for (const key of rest) if (typeOf(key) > "string") keys.push(key);
			return keys;
		}

		// Adler-32 over the canonical text. Bytes are read eight at a time and the sums are reduced once
		// per batch: every intermediate stays an exact integer far below 2^53, so the result is the
		// same as reducing after every byte.
		function feed(state: { A: number; B: number; Nodes: number }, text: string) {
			let a = state.A;
			let b = state.B;
			const length = text.size();
			let index = 1;
			while (index + 7 <= length) {
				const [c1, c2, c3, c4, c5, c6, c7, c8] = text.byte(index, index + 7);
				a += c1;
				b += a;
				a += c2;
				b += a;
				a += c3;
				b += a;
				a += c4;
				b += a;
				a += c5;
				b += a;
				a += c6;
				b += a;
				a += c7;
				b += a;
				a += c8;
				b += a;
				a %= MOD_ADLER;
				b %= MOD_ADLER;
				index += 8;
			}
			while (index <= length) {
				a = (a + text.byte(index)[0]) % MOD_ADLER;
				b = (b + a) % MOD_ADLER;
				index += 1;
			}
			state.A = a;
			state.B = b;
		}

		// the path is only needed for an error message, so it is kept as a stack of keys and joined on failure
		function pathText(stack: string[]): string {
			return stack.size() === 0 ? "?" : stack.join("");
		}

		function digestValue(
			state: { A: number; B: number; Nodes: number },
			value: unknown,
			depth: number,
			parentKey: string | undefined,
			stack: string[],
		) {
			state.Nodes += 1;
			if (state.Nodes > MAX_NODES || depth > 18) {
				error("profile exceeds integrity traversal budget");
			}
			const kind = typeOf(value);
			if (kind === "nil") feed(state, "n;");
			else if (kind === "boolean") feed(state, value === true ? "b1;" : "b0;");
			else if (kind === "number") {
				if (!isFiniteNumber(value)) error("profile contains a non-finite number at " + pathText(stack));
				feed(state, "d" + string.format("%.17g", value as number) + ";");
			} else if (kind === "string") {
				const text = value as string;
				feed(state, "s" + tostring(text.size()) + ":" + text + ";");
			} else if (kind === "table") {
				feed(state, "{");
				const isMeta = parentKey === "Meta";
				const top = stack.size();
				const bag = value as Dict;
				for (const key of orderedKeys(bag)) {
					const excluded = isMeta && (key === "Integrity" || key === "Transactions");
					if (!excluded) {
						stack[top] = "<key>";
						digestValue(state, key, depth + 1, undefined, stack);
						stack[top] = "." + tostring(key);
						digestValue(
							state,
							bag[key as string],
							depth + 1,
							typeIs(key, "string") ? key : undefined,
							stack,
						);
					}
				}
				stack.remove(top);
				feed(state, "}");
			} else {
				error("profile contains unsupported value type " + kind);
			}
		}

		function criticalSnapshot(profile: Dict): Dict {
			const items = isTable(profile.Items) ? profile.Items : undefined;
			const anomaly = isTable(profile.Anomaly) ? profile.Anomaly : undefined;
			return {
				Cash: profile.Cash,
				Vault: profile.Vault,
				Cores: profile.Cores,
				Stardust: profile.Stardust,
				Rebirths: profile.Rebirths,
				RunCash: profile.RunCash,
				LifetimeCash: profile.LifetimeCash,
				Zone: profile.Zone,
				CurrentZone: profile.CurrentZone,
				Domain: deepCopy(profile.Domain),
				Continuum: deepCopy(profile.Continuum),
				Machines: deepCopy(profile.Machines),
				Research: deepCopy(profile.Research),
				GridUpgrades: deepCopy(profile.GridUpgrades),
				BoostInventory: deepCopy(profile.BoostInventory),
				Items: {
					NextId: items !== undefined ? (items.NextId ?? 1) : 1,
					Essence: items !== undefined ? (items.Essence ?? 0) : 0,
					Keys: deepCopy(items !== undefined ? (items.Keys ?? {}) : {}),
				},
				Anomaly: {
					Fragments: anomaly !== undefined ? (anomaly.Fragments ?? 0) : 0,
					Stabilizations: anomaly !== undefined ? (anomaly.Stabilizations ?? 0) : 0,
				},
			};
		}

		function applyCriticalSnapshot(profile: Dict, snapshot: Dict) {
			for (const key of [
				"Cash",
				"Vault",
				"Cores",
				"Stardust",
				"Rebirths",
				"RunCash",
				"LifetimeCash",
				"Zone",
				"CurrentZone",
				"Domain",
				"Continuum",
				"Machines",
				"Research",
				"GridUpgrades",
				"BoostInventory",
			]) {
				if (snapshot[key] !== undefined) profile[key] = deepCopy(snapshot[key]);
			}
			if (isTable(snapshot.Items) && isTable(profile.Items)) {
				const snapshotItems = snapshot.Items;
				const profileItems = profile.Items;
				profileItems.NextId = snapshotItems.NextId ?? profileItems.NextId;
				profileItems.Essence = snapshotItems.Essence ?? profileItems.Essence;
				profileItems.Keys = deepCopy(snapshotItems.Keys ?? profileItems.Keys);
			}
			if (isTable(snapshot.Anomaly) && isTable(profile.Anomaly)) {
				const snapshotAnomaly = snapshot.Anomaly;
				const profileAnomaly = profile.Anomaly;
				profileAnomaly.Fragments = snapshotAnomaly.Fragments ?? profileAnomaly.Fragments;
				profileAnomaly.Stabilizations = snapshotAnomaly.Stabilizations ?? profileAnomaly.Stabilizations;
			}
		}

		const ProfileIntegrity = {
			Hash(this: void, value: unknown): string {
				const state = { A: 1, B: 0, Nodes: 0 };
				digestValue(state, value, 0, undefined, []);
				return string.format("%08x", state.B * 65536 + state.A);
			},

			EnsureEnvelope(this: void, profile: Dict): Dict {
				profile.Meta = isTable(profile.Meta) ? profile.Meta : {};
				const meta = profile.Meta as Dict;
				meta.Integrity = isTable(meta.Integrity)
					? meta.Integrity
					: {
							Algorithm: ALGORITHM,
							Hash: "",
							SealedRevision: 0,
							SealedAt: 0,
						};
				meta.Transactions = isTable(meta.Transactions) ? meta.Transactions : {};
				return profile;
			},

			Seal(this: void, profile: Dict): string {
				ProfileIntegrity.EnsureEnvelope(profile);
				const meta = profile.Meta as Dict;
				const hash = ProfileIntegrity.Hash(profile);
				meta.Integrity = {
					Algorithm: ALGORITHM,
					Hash: hash,
					SealedRevision: math.max(0, math.floor(num(meta.Revision) ?? 0)),
					SealedAt: os.time(),
				};
				return hash;
			},

			Record(this: void, profile: Dict, label: string, revision?: number): Dict {
				ProfileIntegrity.EnsureEnvelope(profile);
				const meta = profile.Meta as Dict;
				const transactions = meta.Transactions as defined[];
				const snapshot = criticalSnapshot(profile);
				const entry: Dict = {
					Id: string.format("%d:%d", os.time(), math.max(0, math.floor(revision ?? 0))),
					At: os.time(),
					Revision: math.max(0, math.floor(revision ?? 0)),
					Label: (label !== "" ? label : "mutation").sub(1, 64),
					Snapshot: snapshot,
					Hash: ProfileIntegrity.Hash(snapshot),
				};
				transactions.push(entry);
				while (transactions.size() > JOURNAL_LIMIT) transactions.shift();
				return entry;
			},

			VerifyAndRecover(this: void, profile: Dict): LuaTuple<[boolean, string]> {
				ProfileIntegrity.EnsureEnvelope(profile);
				const meta = profile.Meta as Dict;
				const envelope = meta.Integrity as Dict;
				if (
					envelope.Algorithm !== ALGORITHM ||
					!typeIs(envelope.Hash, "string") ||
					envelope.Hash === ""
				) {
					const [sealed] = pcall(ProfileIntegrity.Seal, profile);
					if (!sealed) {
						return $tuple(false, "legacy profile structure is invalid; schema recovery required");
					}
					return $tuple(true, "sealed legacy profile");
				}
				const [ok, current] = pcall(ProfileIntegrity.Hash, profile);
				if (ok && current === envelope.Hash) return $tuple(true, "verified");

				const journal = meta.Transactions as unknown[];
				for (let index = journal.size(); index >= 1; index--) {
					const entry = journal[index - 1];
					if (isTable(entry) && isTable(entry.Snapshot) && typeIs(entry.Hash, "string")) {
						const [snapshotOk, snapshotHash] = pcall(ProfileIntegrity.Hash, entry.Snapshot);
						if (snapshotOk && snapshotHash === entry.Hash) {
							applyCriticalSnapshot(profile, entry.Snapshot);
							const [sealed] = pcall(ProfileIntegrity.Seal, profile);
							if (!sealed) {
								return $tuple(
									false,
									"transaction recovered critical state; schema recovery still required",
								);
							}
							return $tuple(
								false,
								"recovered critical state from transaction " + tostring(entry.Id),
							);
						}
					}
				}
				const [sealed] = pcall(ProfileIntegrity.Seal, profile);
				if (!sealed) {
					return $tuple(false, "integrity mismatch; profile structure requires schema recovery");
				}
				return $tuple(false, "integrity mismatch; no valid recovery entry");
			},

			Status(this: void, profile: Dict): Dict {
				ProfileIntegrity.EnsureEnvelope(profile);
				const meta = profile.Meta as Dict;
				const envelope = meta.Integrity as Dict;
				const transactions = meta.Transactions as unknown[];
				return {
					Algorithm: envelope.Algorithm,
					Hash: envelope.Hash,
					SealedRevision: envelope.SealedRevision,
					SealedAt: envelope.SealedAt,
					JournalDepth: transactions.size(),
				};
			},
		};

		return table.freeze(ProfileIntegrity);
	};
};

__defs["Security"] = () => {
	return () => {
		const Players = game.GetService("Players");
		const RunService = game.GetService("RunService");
		const TextService = game.GetService("TextService");
		const HttpService = game.GetService("HttpService");

		const Protocol = req<{ Actions: Record<string, string> }>(
			SharedFolder().WaitForChild("Protocol"),
		);

		class Authority {
			Actions: Record<string, string>;

			constructor() {
				this.Actions = Protocol.Actions;
			}

			Validate(player: Player, action: unknown, payload: unknown): LuaTuple<[boolean, string | undefined]> {
				if (RunService.IsStudio()) {
					return $tuple(true, undefined);
				}
				if (player.Parent !== Players) {
					return $tuple(false, "player is not active");
				}
				if (!typeIs(action, "string") || this.Actions[action] === undefined) {
					return $tuple(false, "unknown action");
				}
				if (payload !== undefined && !typeIs(payload, "table")) {
					return $tuple(false, "payload must be a table");
				}
				return $tuple(true, undefined);
			}
		}

		class Nonce {
			Values = new Map<Player, { Value: string; Expires: number }>();
			TTL: number;

			constructor(ttl?: number) {
				this.TTL = ttl ?? 8;
			}

			Issue(player: Player): string {
				const value = HttpService.GenerateGUID(false);
				this.Values.set(player, { Value: value, Expires: os.clock() + this.TTL });
				return value;
			}

			Consume(player: Player, value: unknown): boolean {
				const record = this.Values.get(player);
				if (
					record === undefined ||
					!typeIs(value, "string") ||
					record.Value !== value ||
					os.clock() > record.Expires
				) {
					return false;
				}
				this.Values.delete(player);
				return true;
			}

			Forget(player: Player): void {
				this.Values.delete(player);
			}
		}

		class Mask {
			Keys = new Map<Player, number>();

			Key(player: Player): number {
				let key = this.Keys.get(player);
				if (key !== undefined) {
					return key;
				}
				key = bit32.bxor(player.UserId, math.random(1, 0x7fffffff));
				this.Keys.set(player, key);
				return key;
			}

			Encode(player: Player, value: number): number {
				return bit32.bxor(math.floor(math.max(0, value)) % 0x100000000, this.Key(player));
			}

			Decode(player: Player, value: number): number {
				return bit32.bxor(value, this.Key(player));
			}

			Forget(player: Player): void {
				this.Keys.delete(player);
			}
		}

		class Rollback {
			Capacity: number;
			History = new Map<Player, Array<{ Revision: number; Snapshot: unknown }>>();

			constructor(capacity?: number) {
				this.Capacity = capacity ?? 8;
			}

			Push(player: Player, revision: number, snapshot: unknown): void {
				const history = this.History.get(player) ?? [];
				history.push({ Revision: revision, Snapshot: snapshot });
				while (history.size() > this.Capacity) {
					history.shift();
				}
				this.History.set(player, history);
			}

			Latest(player: Player): unknown {
				const history = this.History.get(player);
				return history !== undefined ? history[history.size() - 1] : undefined;
			}

			Forget(player: Player): void {
				this.History.delete(player);
			}
		}

		class Caller {
			Verify(expectedSource?: string): boolean {
				const [ok, source] = pcall(() => {
					const [s] = debug.info(3, "s");
					return s;
				});
				if (!ok || expectedSource === undefined) {
					return ok;
				}
				return source === expectedSource;
			}
		}

		class Honey {
			Tokens = new Map<string, boolean>();
			Trips = new Map<Player, number>();

			Register(token: string): void {
				this.Tokens.set(token, true);
			}

			Trip(player: Player, token: string): boolean {
				if (this.Tokens.get(token) !== true) {
					return false;
				}
				this.Trips.set(player, (this.Trips.get(player) ?? 0) + 1);
				player.SetAttribute("AF_HoneyTrips", this.Trips.get(player));
				return true;
			}

			Forget(player: Player): void {
				this.Trips.delete(player);
			}
		}

		class Lifecycle {
			Connections: RBXScriptConnection[] = [];

			Watch(instance: Instance, callback: (this: void) => void): RBXScriptConnection {
				let connection: RBXScriptConnection;
				connection = instance.AncestryChanged.Connect((_instance, parent) => {
					if (parent === undefined) {
						if (connection !== undefined) {
							connection.Disconnect();
						}
						callback();
					}
				});
				this.Connections.push(connection);
				return connection;
			}

			Destroy(): void {
				for (const connection of this.Connections) {
					connection.Disconnect();
				}
				table.clear(this.Connections);
			}
		}

		class Filter {
			Apply(
				player: Player,
				raw: unknown,
				_contextUserId?: number,
				maximumLength?: number,
			): LuaTuple<[boolean, string | undefined]> {
				if (!typeIs(raw, "string")) {
					return $tuple(false, undefined);
				}
				const text = raw.sub(1, math.clamp(math.floor(maximumLength ?? 160), 1, 800));
				const [ok, result] = pcall(() => {
					const filtered = TextService.FilterStringAsync(text, player.UserId);
					return filtered.GetNonChatStringForBroadcastAsync();
				});
				if (!ok || !typeIs(result, "string")) {
					return $tuple(false, undefined);
				}
				return $tuple(true, result);
			}
		}

		class Relations {
			Allows(flags: number, requiredBlockedMask: number): boolean {
				return bit32.band(flags, requiredBlockedMask) === 0;
			}
		}

		class Device {
			Escalate(player: Player, reason: string, severe?: boolean): void {
				player.SetAttribute("AF_SecurityReason", reason.sub(1, 96));
				if (severe === true && player.Parent === Players) {
					player.Kick("Astral Forge rejected suspicious activity.");
				}
			}
		}

		class Rate {
			Capacity: number;
			Refill: number;
			Buckets = new Map<Player, { Tokens: number; At: number }>();

			constructor(capacity?: number, refill?: number) {
				this.Capacity = capacity ?? 30;
				this.Refill = refill ?? 8;
			}

			Allow(player: Player, cost?: number): boolean {
				if (RunService.IsStudio()) {
					return true;
				}
				const now = os.clock();
				const bucket = this.Buckets.get(player) ?? { Tokens: this.Capacity, At: now };
				bucket.Tokens = math.min(this.Capacity, bucket.Tokens + (now - bucket.At) * this.Refill);
				bucket.At = now;
				const amount = cost ?? 1;
				if (bucket.Tokens < amount) {
					this.Buckets.set(player, bucket);
					return false;
				}
				bucket.Tokens -= amount;
				this.Buckets.set(player, bucket);
				return true;
			}

			Forget(player: Player): void {
				this.Buckets.delete(player);
			}
		}

		class Heuristic {
			State = new Map<
				Player,
				{ Production: number; Revision: number; At: number; Score: number }
			>();

			Observe(player: Player, production: number, revision: number): number {
				const now = os.clock();
				const previous = this.State.get(player);
				if (previous === undefined) {
					this.State.set(player, { Production: production, Revision: revision, At: now, Score: 0 });
					return 0;
				}
				const elapsed = math.max(0.05, now - previous.At);
				const acceleration = math.max(0, production - previous.Production) / elapsed;
				if (acceleration > math.max(1, production) * 1000) {
					previous.Score += 1;
				}
				if (revision < previous.Revision) {
					previous.Score += 2;
				}
				previous.Production = production;
				previous.Revision = revision;
				previous.At = now;
				return previous.Score;
			}
		}

		class Security {
			Authority = new Authority();
			Nonce = new Nonce();
			Mask = new Mask();
			Rollback = new Rollback();
			Caller = new Caller();
			Honey = new Honey();
			Lifecycle = new Lifecycle();
			Filter = new Filter();
			Relationships = new Relations();
			Device = new Device();
			Rate = new Rate();
			Heuristic = new Heuristic();
			_alive?: boolean;
			_playerRemoving?: RBXScriptConnection;

			Start(): void {
				if (this._alive === true) {
					return;
				}
				this._alive = true;
				this._playerRemoving = Players.PlayerRemoving.Connect((player) => {
					if (!this._alive) {
						return;
					}
					this.Nonce.Forget(player);
					this.Mask.Forget(player);
					this.Rollback.Forget(player);
					this.Honey.Forget(player);
					this.Rate.Forget(player);
					this.Heuristic.State.delete(player);
				});
			}

			Destroy(): void {
				this._alive = false;
				if (this._playerRemoving !== undefined) {
					this._playerRemoving.Disconnect();
					this._playerRemoving = undefined;
				}
				this.Lifecycle.Destroy();
				table.clear(this.Nonce.Values);
				table.clear(this.Mask.Keys);
				table.clear(this.Rollback.History);
				table.clear(this.Honey.Trips);
				table.clear(this.Rate.Buckets);
				table.clear(this.Heuristic.State);
			}
		}

		return Security;
	};
};

__defs["SessionGate"] = () => {
	return () => {
		const HttpService = game.GetService("HttpService");
		const RunService = game.GetService("RunService");

		const ROTATE_EVERY_BEATS = 8;
		const ROTATE_EVERY_SEC = 24;
		const GRACE_SEC = 2.5;
		const UNAUTH_AFTER = 45;
		const LATE_BEAT_STRIKE_SEC = 8;
		const TXN_RING = 64;

		interface Session {
			gen: number;
			nonce: string;
			prevNonce?: string;
			issued: number;
			lastRotate: number;
			lastBeat: number;
			lastBeatId: number;
			beatsSinceRotate: number;
			auth: boolean;
			txns: Record<string, unknown>;
			txnOrder: string[];
		}

		function newNonce(): string {
			return HttpService.GenerateGUID(false);
		}

		function rotate(session: Session) {
			session.prevNonce = session.nonce;
			session.nonce = newNonce();
			session.gen += 1;
			session.lastRotate = os.clock();
			session.beatsSinceRotate = 0;
		}

		const TXN_PENDING = { __txn: "pending" };

		class SessionGate {
			private _sessions = new Map<Player, Session>();

			private _get(player: Player): Session {
				const existing = this._sessions.get(player);
				if (existing !== undefined) {
					return existing;
				}
				const now = os.clock();
				const created: Session = {
					gen: 1,
					nonce: newNonce(),
					prevNonce: undefined,
					issued: now,
					lastRotate: now,
					lastBeat: now,
					lastBeatId: 0,
					beatsSinceRotate: 0,
					auth: false,
					txns: {},
					txnOrder: [],
				};
				this._sessions.set(player, created);
				return created;
			}

			Hello(player: Player): LuaTuple<[number, string]> {
				const session = this._get(player);
				return $tuple(session.gen, session.nonce);
			}

			Beat(
				player: Player,
				gen: unknown,
				id: unknown,
				n: unknown,
			): LuaTuple<[boolean, string | undefined, number | undefined, string | undefined]> {
				if (RunService.IsStudio()) {
					const session = this._get(player);
					session.auth = true;
					return $tuple(true, undefined, session.gen, session.nonce);
				}
				const session = this._get(player);
				const now = os.clock();
				if (!typeIs(gen, "number") || !typeIs(id, "number") || !typeIs(n, "string")) {
					return $tuple(false, "malformed beat", session.gen, session.nonce);
				}

				const inGrace = session.prevNonce !== undefined && now - session.lastRotate < GRACE_SEC;
				const genOk = gen === session.gen || (inGrace && gen === session.gen - 1);
				if (!genOk) {
					return $tuple(false, "gen mismatch", session.gen, session.nonce);
				}
				const nonceOk =
					n === session.nonce || (inGrace && gen === session.gen - 1 && n === session.prevNonce);
				if (!nonceOk) {
					return $tuple(false, "nonce mismatch", session.gen, session.nonce);
				}
				if (id <= session.lastBeatId) {
					return $tuple(false, "replay", session.gen, session.nonce);
				}

				const late = now - session.lastBeat;
				session.lastBeat = now;
				session.lastBeatId = id;
				session.beatsSinceRotate += 1;
				session.auth = true;

				if (late > UNAUTH_AFTER) {
					session.auth = false;
				}

				if (
					session.prevNonce === undefined ||
					session.beatsSinceRotate >= ROTATE_EVERY_BEATS ||
					now - session.lastRotate >= ROTATE_EVERY_SEC
				) {
					rotate(session);
				}

				if (late > LATE_BEAT_STRIKE_SEC) {
					return $tuple(session.auth, "late", session.gen, session.nonce);
				}
				return $tuple(session.auth, undefined, session.gen, session.nonce);
			}

			CheckGrant(
				player: Player,
				gen: unknown,
				n: unknown,
				requireNonce: boolean,
			): LuaTuple<[boolean, string | undefined]> {
				if (RunService.IsStudio()) {
					const session = this._get(player);
					session.auth = true;
					session.lastBeat = os.clock();
					return $tuple(true, undefined);
				}
				const session = this._sessions.get(player);
				if (session === undefined) {
					return $tuple(false, "no session");
				}
				const now = os.clock();
				if (!session.auth || now - session.lastBeat > UNAUTH_AFTER) {
					return $tuple(false, "unauth");
				}
				const inGrace = session.prevNonce !== undefined && now - session.lastRotate < GRACE_SEC;
				const genOk =
					typeIs(gen, "number") && (gen === session.gen || (inGrace && gen === session.gen - 1));
				if (!genOk) {
					return $tuple(false, "gen mismatch");
				}
				if (requireNonce) {
					const nonceOk =
						typeIs(n, "string") &&
						(n === session.nonce ||
							(inGrace && gen === session.gen - 1 && n === session.prevNonce));
					if (!nonceOk) {
						return $tuple(false, "nonce mismatch");
					}
				}
				return $tuple(true, undefined);
			}

			TxnLookup(player: Player, txnId: string): LuaTuple<[boolean, unknown]> {
				const session = this._get(player);
				const stored = session.txns[txnId];
				if (stored === undefined || stored === TXN_PENDING) {
					return $tuple(false, undefined);
				}
				return $tuple(true, stored);
			}

			TxnClaim(player: Player, txnId: string): LuaTuple<[string, unknown]> {
				const session = this._get(player);
				const stored = session.txns[txnId];
				if (stored === TXN_PENDING) {
					return $tuple("busy", undefined);
				}
				if (stored !== undefined) {
					return $tuple("done", stored);
				}
				session.txnOrder.push(txnId);
				if (session.txnOrder.size() > TXN_RING) {
					const oldest = session.txnOrder.shift();
					if (oldest !== undefined) {
						delete session.txns[oldest];
					}
				}
				session.txns[txnId] = TXN_PENDING;
				return $tuple("new", undefined);
			}

			TxnStore(player: Player, txnId: string, result: unknown) {
				const session = this._get(player);
				if (session.txns[txnId] === undefined) {
					session.txnOrder.push(txnId);
					if (session.txnOrder.size() > TXN_RING) {
						const oldest = session.txnOrder.shift();
						if (oldest !== undefined) {
							delete session.txns[oldest];
						}
					}
				}
				session.txns[txnId] = result;
			}

			TxnRelease(player: Player, txnId: string) {
				const session = this._get(player);
				if (session.txns[txnId] === TXN_PENDING) {
					delete session.txns[txnId];
					for (const [index, id] of pairs(session.txnOrder)) {
						if (id === txnId) {
							session.txnOrder.remove(index - 1);
							break;
						}
					}
				}
			}

			Peek(player: Player): LuaTuple<[number | undefined, string | undefined]> {
				const session = this._sessions.get(player);
				if (session === undefined) {
					return $tuple(undefined, undefined);
				}
				return $tuple(session.gen, session.nonce);
			}

			Forget(player: Player) {
				this._sessions.delete(player);
			}
		}

		return SessionGate;
	};
};

__defs["ServerTelemetry"] = () => {
	return () => {
		interface Timing {
			Count: number;
			Failures: number;
			TotalMs: number;
			MaximumMs: number;
			LastMs: number;
		}

		let startedAt = os.clock();
		let remoteAccepted = 0;
		let remoteRejected = 0;
		let integrityReports = 0;
		let logs = { Info: 0, Warning: 0, Debug: 0 };
		const rejectionReasons: Record<string, number> = {};
		const timings: Record<string, Timing> = {};
		const activeSessions: Record<number, number> = {};
		let sessionsStarted = 0;
		let sessionsEnded = 0;
		let totalSessionSeconds = 0;
		let clientQuality = {
			Samples: 0,
			TotalFPS: 0,
			TotalP95Ms: 0,
			TotalPingMs: 0,
			TotalBootMs: 0,
			TotalJank: 0,
			WorstP95Ms: 0,
		};

		function timingFor(name: string): Timing {
			let timing = timings[name];
			if (timing === undefined) {
				timing = { Count: 0, Failures: 0, TotalMs: 0, MaximumMs: 0, LastMs: 0 };
				timings[name] = timing;
			}
			return timing;
		}

		const Telemetry = {
			RecordLog(this: void, level: string): void {
				if (level === "Info") logs.Info += 1;
				else if (level === "Warning") logs.Warning += 1;
				else if (level === "Debug") logs.Debug += 1;
			},

			RecordRemote(this: void, accepted: boolean, reason?: string): void {
				if (accepted) {
					remoteAccepted += 1;
					return;
				}
				remoteRejected += 1;
				const key = (reason ?? "unspecified").sub(1, 64);
				rejectionReasons[key] = (rejectionReasons[key] ?? 0) + 1;
			},

			RecordIntegrityReport(this: void): void {
				integrityReports += 1;
			},

			RecordPlayerJoined(this: void, userId: number): void {
				if (activeSessions[userId] !== undefined) return;
				activeSessions[userId] = os.clock();
				sessionsStarted += 1;
			},

			RecordPlayerLeft(this: void, userId: number): void {
				const joinedAt = activeSessions[userId];
				if (joinedAt === undefined) return;
				delete activeSessions[userId];
				sessionsEnded += 1;
				totalSessionSeconds += math.max(0, os.clock() - joinedAt);
			},

			Observe(this: void, name: string, seconds: number, succeeded: boolean): void {
				const milliseconds = math.max(0, seconds) * 1000;
				const timing = timingFor(name);
				timing.Count += 1;
				if (!succeeded) timing.Failures += 1;
				timing.TotalMs += milliseconds;
				timing.MaximumMs = math.max(timing.MaximumMs, milliseconds);
				timing.LastMs = milliseconds;
			},

			RecordClientPerformance(this: void, sample: unknown): void {
				const bag = sample as Dict;
				clientQuality.Samples += 1;
				clientQuality.TotalFPS += math.clamp(num(bag.FPS) ?? 0, 0, 360);
				clientQuality.TotalP95Ms += math.clamp(num(bag.P95Ms) ?? 0, 0, 1000);
				clientQuality.TotalPingMs += math.clamp(num(bag.PingMs) ?? 0, 0, 10000);
				clientQuality.TotalBootMs += math.clamp(num(bag.BootMs) ?? 0, 0, 120000);
				clientQuality.TotalJank += math.clamp(num(bag.JankPct) ?? 0, 0, 1);
				clientQuality.WorstP95Ms = math.max(clientQuality.WorstP95Ms, num(bag.P95Ms) ?? 0);
			},

			Snapshot(this: void): Dict {
				const reasonList: { Reason: string; Count: number }[] = [];
				for (const [reason, count] of pairs(rejectionReasons)) {
					reasonList.push({ Reason: reason, Count: count });
				}
				reasonList.sort((left, right) =>
					left.Count === right.Count ? left.Reason < right.Reason : left.Count > right.Count,
				);
				while (reasonList.size() > 6) reasonList.pop();

				const timingList: Dict[] = [];
				for (const [name, timing] of pairs(timings)) {
					timingList.push({
						Name: name,
						Count: timing.Count,
						Failures: timing.Failures,
						AverageMs: timing.Count > 0 ? timing.TotalMs / timing.Count : 0,
						MaximumMs: timing.MaximumMs,
						LastMs: timing.LastMs,
					});
				}
				timingList.sort((left, right) => (left.Name as string) < (right.Name as string));

				const total = remoteAccepted + remoteRejected;
				const samples = clientQuality.Samples;
				return {
					UptimeSeconds: math.max(0, os.clock() - startedAt),
					RemoteAccepted: remoteAccepted,
					RemoteRejected: remoteRejected,
					RemoteRejectRate: total > 0 ? remoteRejected / total : 0,
					IntegrityReports: integrityReports,
					SessionsStarted: sessionsStarted,
					SessionsEnded: sessionsEnded,
					ActiveSessions: sessionsStarted - sessionsEnded,
					AverageSessionSeconds: sessionsEnded > 0 ? totalSessionSeconds / sessionsEnded : 0,
					Logs: table.clone(logs),
					TopRejections: reasonList,
					Timings: timingList,
					ClientPerformance: {
						Samples: samples,
						AverageFPS: samples > 0 ? clientQuality.TotalFPS / samples : 0,
						AverageP95Ms: samples > 0 ? clientQuality.TotalP95Ms / samples : 0,
						AveragePingMs: samples > 0 ? clientQuality.TotalPingMs / samples : 0,
						AverageBootMs: samples > 0 ? clientQuality.TotalBootMs / samples : 0,
						AverageJankPct: samples > 0 ? clientQuality.TotalJank / samples : 0,
						WorstP95Ms: clientQuality.WorstP95Ms,
					},
				};
			},

			ResetForTests(this: void): void {
				startedAt = os.clock();
				remoteAccepted = 0;
				remoteRejected = 0;
				integrityReports = 0;
				sessionsStarted = 0;
				sessionsEnded = 0;
				totalSessionSeconds = 0;
				logs = { Info: 0, Warning: 0, Debug: 0 };
				table.clear(rejectionReasons);
				table.clear(timings);
				table.clear(activeSessions);
				clientQuality = {
					Samples: 0,
					TotalFPS: 0,
					TotalP95Ms: 0,
					TotalPingMs: 0,
					TotalBootMs: 0,
					TotalJank: 0,
					WorstP95Ms: 0,
				};
			},
		};

		return table.freeze(Telemetry);
	};
};

__defs["AtomicState"] = () => {
	return () => {
		const CONTENTION_TIMEOUT_SECONDS = 2;
		const CONTENTION_POLL_SECONDS = 0.03;

		// deep copy for rollback; the native shallow copy does the bulk of the work at each level, so
		// only nested tables cost a Lua call (profiles hold thousands of plain number entries)
		function clone(value: unknown): unknown {
			if (!typeIs(value, "table")) {
				return value;
			}
			const result = table.clone(value as Dict);
			if (getmetatable(result) !== undefined) {
				setmetatable(result, undefined);
			}
			for (const [key, child] of pairs(value)) {
				if (typeIs(child, "table")) {
					result[key as string] = clone(child);
				}
			}
			return result;
		}

		function revisionOf(value: unknown): number {
			if (isTable(value) && isTable(value.Meta) && typeIs(value.Meta.Revision, "number")) {
				return math.max(0, math.floor(value.Meta.Revision));
			}
			return 0;
		}

		class AtomicState {
			private _value: unknown;
			private _revision: number;
			private _busy = false;

			constructor(initial: unknown) {
				this._value = initial;
				this._revision = revisionOf(initial);
			}

			Read(): LuaTuple<[unknown, number]> {
				this._revision = math.max(this._revision, revisionOf(this._value));
				return $tuple(this._value, this._revision);
			}

			IsBusy(): boolean {
				return this._busy === true;
			}

			Transact(
				callback: (this: void, draft: unknown, revision: number) => unknown,
				incrementRevision?: boolean,
			): LuaTuple<[boolean, unknown, number]> {
				const deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS;
				while (this._busy && os.clock() < deadline) {
					task.wait(CONTENTION_POLL_SECONDS);
				}
				if (this._busy) {
					return $tuple(false, "state transaction already in progress", this._revision);
				}
				this._revision = math.max(this._revision, revisionOf(this._value));
				this._busy = true;
				const [cloneOk, draft] = pcall(clone, this._value);
				if (!cloneOk) {
					this._busy = false;
					return $tuple(false, draft, this._revision);
				}
				const [ok, result] = pcall(callback, draft, this._revision + 1);
				const shouldCommit = ok && !(isTable(result) && result.ok === false);
				if (shouldCommit) {
					if (incrementRevision !== false) {
						this._revision += 1;
						if (isTable(draft) && isTable(draft.Meta)) {
							draft.Meta.Revision = this._revision;
						}
					}
					this._value = draft;
				}
				this._busy = false;
				if (!ok) {
					return $tuple(false, result, this._revision);
				}
				return $tuple(true, result, this._revision);
			}

			// Fast path for hot, small updates (the 0.5s production tick): the callback edits the live
			// value in place instead of a deep copy of the whole profile, under the same busy lock.
			// Rollback state is kept only for what such a callback can touch: the root's own fields
			// (scalars and which table each key points at), a shallow copy of each `shallowKeys`
			// section, and a deep copy of each `deepKeys` section. On a throw or an { ok = false }
			// result all of those are put back; tables keep their identity when nothing failed.
			TransactInPlace(
				callback: (this: void, draft: unknown, revision: number) => unknown,
				deepKeys: ReadonlyArray<string>,
				shallowKeys: ReadonlyArray<string>,
				incrementRevision?: boolean,
			): LuaTuple<[boolean, unknown, number]> {
				const deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS;
				while (this._busy && os.clock() < deadline) {
					task.wait(CONTENTION_POLL_SECONDS);
				}
				if (this._busy) {
					return $tuple(false, "state transaction already in progress", this._revision);
				}
				const live = this._value;
				if (!isTable(live)) {
					return this.Transact(callback, incrementRevision);
				}
				this._revision = math.max(this._revision, revisionOf(live));
				this._busy = true;
				const root = live as Record<string, unknown>;
				const [backupOk, backup] = pcall(() => {
					const rootCopy = table.clone(root);
					const deep: Record<string, unknown> = {};
					for (const key of deepKeys) {
						deep[key] = clone(root[key]);
					}
					const shallow: Record<string, Record<string, unknown> | undefined> = {};
					for (const key of shallowKeys) {
						const section = root[key];
						shallow[key] = isTable(section) ? table.clone(section as Record<string, unknown>) : undefined;
					}
					return { rootCopy, deep, shallow };
				});
				if (!backupOk) {
					this._busy = false;
					return $tuple(false, backup, this._revision);
				}
				const [ok, result] = pcall(callback, live, this._revision + 1);
				const shouldCommit = ok && !(isTable(result) && result.ok === false);
				if (shouldCommit) {
					if (incrementRevision !== false) {
						this._revision += 1;
						if (isTable(root.Meta)) {
							(root.Meta as Record<string, unknown>).Revision = this._revision;
						}
					}
				} else {
					const saved = backup as {
						rootCopy: Record<string, unknown>;
						deep: Record<string, unknown>;
						shallow: Record<string, Record<string, unknown> | undefined>;
					};
					for (const [key] of pairs(root)) {
						if (rawget(saved.rootCopy, key) === undefined) {
							root[key as string] = undefined;
						}
					}
					for (const [key, value] of pairs(saved.rootCopy)) {
						root[key as string] = value;
					}
					for (const key of shallowKeys) {
						const before = saved.shallow[key];
						const section = root[key];
						if (before !== undefined && isTable(section)) {
							const target = section as Record<string, unknown>;
							for (const [field] of pairs(target)) {
								if (rawget(before, field) === undefined) {
									target[field as string] = undefined;
								}
							}
							for (const [field, value] of pairs(before)) {
								target[field as string] = value;
							}
						}
					}
					for (const key of deepKeys) {
						root[key] = saved.deep[key];
					}
				}
				this._busy = false;
				if (!ok) {
					return $tuple(false, result, this._revision);
				}
				return $tuple(true, result, this._revision);
			}

			Replace(value: unknown, revision?: number): boolean {
				if (this._busy) {
					return false;
				}
				this._value = value;
				this._revision = math.max(this._revision, revision ?? this._revision);
				return true;
			}
		}

		return AtomicState;
	};
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type SecurityServicesCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const SecurityServices = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => __load(name),
		__index: (_self: unknown, name: string): unknown => name === "__members" ? __members : __load(name),
	} as LuaMetatable<object>,
) as unknown as SecurityServicesCallable;

export = SecurityServices;
