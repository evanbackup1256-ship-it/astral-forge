// Purpose: isolated ordered leaderboards for explicitly allowed unpublished Studio previews.
// Owner: persistence. Dependencies: a caller-provided native store accessor.
// Last-reviewed: 2026-10-06.

type Row = { key: string; value: number };
type Pages = {
	IsFinished: boolean;
	GetCurrentPage(this: Pages): Row[];
	AdvanceToNextPageAsync(this: Pages): void;
};
type Ordered = {
	SetAsync(this: Ordered, key: string, value: number): void;
	GetAsync(this: Ordered, key: string): number | undefined;
	GetSortedAsync(
		this: Ordered,
		ascending: boolean,
		pageSize: number,
		minimum?: number,
		maximum?: number,
	): Pages;
};
type Store = OrderedDataStore | Ordered;

const stores: Record<string, Ordered> = {};

function copyRows(rows: Row[], start: number, pageSize: number): Row[] {
	const output: Row[] = [];
	for (let index = start; index <= math.min(rows.size(), start + pageSize - 1); index++) {
		const row = rows[index - 1];
		output.push({ key: row.key, value: row.value });
	}
	return output;
}

function newStore(): Ordered {
	const values: Record<string, number> = {};
	const store: Ordered = {
		SetAsync(this: Ordered, key: string, value: number): void {
			assert(value === value && math.abs(value) !== math.huge, "Preview leaderboard value must be finite");
			values[key] = value;
		},

		GetAsync(this: Ordered, key: string): number | undefined {
			return values[key];
		},

		GetSortedAsync(
			this: Ordered,
			ascending: boolean,
			pageSize: number,
			minimum?: number,
			maximum?: number,
		): Pages {
			assert(pageSize >= 1 && pageSize <= 100 && pageSize % 1 === 0, "Invalid leaderboard page size");
			const rows: Row[] = [];
			for (const [key, value] of pairs(values)) {
				if ((minimum === undefined || value >= minimum) && (maximum === undefined || value <= maximum)) {
					rows.push({ key: key, value: value });
				}
			}
			table.sort(rows, (left: Row, right: Row): boolean => {
				if (left.value === right.value) {
					return left.key < right.key;
				}
				return ascending ? left.value < right.value : left.value > right.value;
			});
			let offset = 1;
			const pages: Pages = {
				IsFinished: rows.size() <= pageSize,
				GetCurrentPage(this: Pages): Row[] {
					return copyRows(rows, offset, pageSize);
				},
				AdvanceToNextPageAsync(this: Pages): void {
					if (this.IsFinished) {
						return;
					}
					offset += pageSize;
					this.IsFinished = offset + pageSize - 1 >= rows.size();
				},
			};
			return pages;
		},
	};
	return store;
}

const PreviewStores = {
	enabled(this: void, isStudio: boolean, universeId: number, allowMemory: boolean): boolean {
		return isStudio && universeId === 0 && allowMemory;
	},

	ordered(this: void, name: string, preview: boolean, native: (name: string) => Store): Store {
		if (!preview) {
			return native(name);
		}
		const existing = stores[name];
		if (existing) {
			return existing;
		}
		const created = newStore();
		stores[name] = created;
		return created;
	},
};

export = table.freeze(PreviewStores);
