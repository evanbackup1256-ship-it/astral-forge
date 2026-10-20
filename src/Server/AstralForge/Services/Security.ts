// Request security pipeline: authority, nonce, rate, filter and friends. Started and destroyed by SecurityRuntime.
import { Service } from "@flamework/core";
import { req, SharedFolder } from "./LuaInterop";

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

@Service({ loadOrder: 1 })
export class Security {
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

