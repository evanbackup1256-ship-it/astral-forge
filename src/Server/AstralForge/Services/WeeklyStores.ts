// Ordered stores for the weekly Flux board, one per week, and a per-server read of a finished
// week's top 100 so rewards can be paid without every server hammering the store.
import StoreAccess from "../Modules/StoreAccess";
import ServerConfig from "../ServerConfig";
import * as WeeklyBoard from "../../../Shared/AstralForge/Shared/WeeklyBoard";

interface Sorted {
	GetSortedAsync(this: Sorted, ascending: boolean, size: number): { GetCurrentPage(): { key: string; value: unknown }[] };
	SetAsync(this: Sorted, key: string, value: unknown): unknown;
}

const RETRY_AFTER = 60;
const stores = new Map<number, Sorted>();
const finished = new Map<number, { ranks?: Map<number, number>; busy: boolean; retryAt: number }>();

export function forWeek(week: number): Sorted {
	let store = stores.get(week);
	if (store === undefined) {
		store = StoreAccess.ordered(WeeklyBoard.storeName(ServerConfig.WeeklyLeaderboardStoreName, week)) as Sorted;
		stores.set(week, store);
		// only this week and last week are ever read
		for (const [old] of stores) {
			if (old < week - 1) {
				stores.delete(old);
			}
		}
	}
	return store;
}

export function current(now: number): Sorted {
	return forWeek(WeeklyBoard.weekOf(now));
}

// Final ranks for a finished week, or undefined while the read is still out (it starts one).
export function finalRanks(week: number): Map<number, number> | undefined {
	let entry = finished.get(week);
	if (entry === undefined) {
		entry = { busy: false, retryAt: 0 };
		finished.set(week, entry);
	}
	if (entry.ranks !== undefined) {
		return entry.ranks;
	}
	if (!entry.busy && os.clock() >= entry.retryAt) {
		entry.busy = true;
		const pending = entry;
		task.spawn(() => {
			const [ok, page] = pcall(() => forWeek(week).GetSortedAsync(false, WeeklyBoard.PAID_RANKS).GetCurrentPage());
			pending.busy = false;
			if (!ok) {
				pending.retryAt = os.clock() + RETRY_AFTER;
				return;
			}
			const ranks = new Map<number, number>();
			let rank = 0;
			for (const row of page) {
				const userId = tonumber(row.key);
				if (userId !== undefined && (tonumber(row.value) ?? 0) > 0) {
					rank += 1;
					ranks.set(userId, rank);
				}
			}
			pending.ranks = ranks;
		});
	}
	return undefined;
}

export function ResetForTests() {
	stores.clear();
	finished.clear();
}

export function SetRanksForTests(week: number, ranks: Map<number, number>) {
	finished.set(week, { ranks, busy: false, retryAt: 0 });
}
