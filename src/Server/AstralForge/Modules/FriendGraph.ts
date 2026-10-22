// Who is friends with whom in this server, for the friends bonus.
//
// Friendship is symmetric, so each pair is asked once (lower UserId first) and the answer is
// cached: for `ttl` seconds when the call worked, for `failTtl` when it failed (a failure counts
// as "not friends" so an outage never grants a bonus, and is retried sooner). count() returns how
// many friends each player has among the players passed in. Expired entries are swept on each
// count so the cache never outgrows the server.
//
// The friend check and the clock are injected; nothing here touches Roblox services.

export interface FriendGraphOptions {
	ttl: number;
	failTtl: number;
	isFriends: (this: void, a: number, b: number) => boolean;
	clock?: (this: void) => number;
}

interface CacheEntry {
	friends: boolean;
	expiresAt: number;
}

export class FriendGraph {
	private readonly cache = new Map<string, CacheEntry>();
	private readonly clock: () => number;

	constructor(private readonly options: FriendGraphOptions) {
		this.clock = options.clock ?? os.clock;
	}

	static pairKey(a: number, b: number): string {
		return `${math.min(a, b)}:${math.max(a, b)}`;
	}

	/** Cached, symmetric friend check. */
	friends(a: number, b: number): boolean {
		if (a === b) {
			return false;
		}
		const key = FriendGraph.pairKey(a, b);
		const now = this.clock();
		const cached = this.cache.get(key);
		if (cached !== undefined && cached.expiresAt > now) {
			return cached.friends;
		}
		const [ok, result] = pcall(() => this.options.isFriends(math.min(a, b), math.max(a, b)));
		const friends = ok && result === true;
		this.cache.set(key, { friends, expiresAt: now + (ok ? this.options.ttl : this.options.failTtl) });
		return friends;
	}

	/** Friends-in-server count for every user id given. */
	count(userIds: number[]): Map<number, number> {
		this.sweep();
		const counts = new Map<number, number>();
		for (const id of userIds) counts.set(id, 0);
		for (let i = 0; i < userIds.size(); i++) {
			for (let j = i + 1; j < userIds.size(); j++) {
				if (this.friends(userIds[i], userIds[j])) {
					counts.set(userIds[i], counts.get(userIds[i])! + 1);
					counts.set(userIds[j], counts.get(userIds[j])! + 1);
				}
			}
		}
		return counts;
	}

	/** Drop expired answers. */
	sweep(): void {
		const now = this.clock();
		for (const [key, entry] of this.cache) {
			if (entry.expiresAt <= now) {
				this.cache.delete(key);
			}
		}
	}

	/** Forget one player's pairs (they left), or everything. */
	forget(userId?: number): void {
		if (userId === undefined) {
			this.cache.clear();
			return;
		}
		const prefix = `${userId}:`;
		const suffix = `:${userId}`;
		for (const [key] of this.cache) {
			if (key.sub(1, prefix.size()) === prefix || key.sub(-suffix.size()) === suffix) {
				this.cache.delete(key);
			}
		}
	}

	size(): number {
		return this.cache.size();
	}
}
