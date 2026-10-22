// Global leaderboards: one cached read of each OrderedDataStore, merged with live players.
//
//   read     GetSortedAsync(false, size) through a caller-supplied reader, once per board per
//            pageTtl seconds. Concurrent requests for the same board share one in-flight read.
//   stale    when a read fails the last good page is kept and served, and the board backs off
//            for retryAfter seconds before trying again, so an outage costs one call, not one
//            per request.
//   merge    rows from the store, then live values for players in this server (fresher), then
//            filtered, ranked (higher first, ties by UserId) and cut to the page size.
//
// No Roblox services are touched here; the reader, the clock and value comparison are injected,
// which keeps it testable and lets the weekly board pass a different store every week.

export interface StoreRow {
	key: string;
	value: unknown;
}

export type StoreReader = (this: void, size: number) => StoreRow[];

export interface RankedRow {
	UserId: number;
	Value: unknown;
}

export interface LeaderboardOptions {
	pageSize: number;
	/** how long a store page is reused, in seconds */
	pageTtl: number;
	/** after a failed read, wait this long before reading again */
	retryAfter: number;
	decode: (this: void, raw: unknown) => unknown;
	greater: (this: void, a: unknown, b: unknown) => boolean;
	clock?: (this: void) => number;
}

interface PageEntry {
	key: string;
	rows: Map<number, unknown>;
	readAt: number;
	nextReadAt: number;
	reading: boolean;
	failures: number;
}

export class LeaderboardService {
	private readonly pages = new Map<string, PageEntry>();
	private readonly clock: () => number;

	constructor(private readonly options: LeaderboardOptions) {
		this.clock = options.clock ?? os.clock;
	}

	/** Stored rows for a board (cached; stale on failure). `cacheKey` changes when the store does. */
	stored(board: string, cacheKey: string, reader: StoreReader): Map<number, unknown> {
		const now = this.clock();
		let entry = this.pages.get(board);
		if (entry === undefined || entry.key !== cacheKey) {
			entry = { key: cacheKey, rows: new Map(), readAt: -math.huge, nextReadAt: -math.huge, reading: false, failures: 0 };
			this.pages.set(board, entry);
		}
		if (now < entry.nextReadAt) {
			return entry.rows;
		}
		if (entry.reading) {
			// another request is already reading this board; wait for it briefly, then use what is there
			const deadline = now + 5;
			while (entry.reading && this.clock() < deadline) {
				task.wait();
			}
			return entry.rows;
		}
		entry.reading = true;
		const [ok, page] = pcall(() => reader(this.options.pageSize));
		entry.reading = false;
		if (ok && typeIs(page, "table")) {
			const rows = new Map<number, unknown>();
			for (const row of page as StoreRow[]) {
				const userId = tonumber(row.key);
				if (userId !== undefined) {
					rows.set(userId, this.options.decode(row.value));
				}
			}
			entry.rows = rows;
			entry.readAt = now;
			entry.failures = 0;
			entry.nextReadAt = now + this.options.pageTtl;
		} else {
			entry.failures += 1;
			entry.nextReadAt = now + this.options.retryAfter * math.min(entry.failures, 4);
		}
		return entry.rows;
	}

	/** Merge stored rows with live values, keep the rows that count, rank and cut to a page. */
	rank(stored: Map<number, unknown>, live: Map<number, unknown>, counts: (this: void, value: unknown) => boolean): RankedRow[] {
		const merged = new Map<number, unknown>();
		for (const [userId, value] of stored) merged.set(userId, value);
		for (const [userId, value] of live) merged.set(userId, value);
		const rows: RankedRow[] = [];
		for (const [userId, value] of merged) {
			if (counts(value)) {
				rows.push({ UserId: userId, Value: value });
			}
		}
		const greater = this.options.greater;
		table.sort(rows, (a, b) => {
			if (greater(a.Value, b.Value)) return true;
			if (greater(b.Value, a.Value)) return false;
			return a.UserId < b.UserId;
		});
		return rows;
	}

	/** True when this board has no readable page and has failed at least once. */
	unavailable(board: string): boolean {
		const entry = this.pages.get(board);
		return entry !== undefined && entry.failures > 0 && entry.rows.size() === 0;
	}

	clear(): void {
		this.pages.clear();
	}
}
