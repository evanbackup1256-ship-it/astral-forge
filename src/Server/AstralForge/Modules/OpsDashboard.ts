// Pure economy dashboard for the admin panel: aggregates of the online profiles plus this
// server's action counters. No Roblox services, so it runs under Lune.

interface OmegaLike {
	Add(this: void, a: unknown, b: unknown): unknown;
	Gt(this: void, a: unknown, b: unknown): boolean;
	ToNumber(this: void, a: unknown): number;
}

export interface DashboardRow {
	Cash: unknown;
	Production: unknown;
	Rebirths: unknown;
	Stardust: unknown;
	Cores: unknown;
}

function median(values: number[]): number {
	if (values.size() === 0) return 0;
	const sorted = [...values];
	sorted.sort((a, b) => a < b);
	const mid = math.floor(sorted.size() / 2);
	return sorted.size() % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function finite(value: unknown): number {
	const n = tonumber(value);
	return n !== undefined && n === n && n !== math.huge && n !== -math.huge ? n : 0;
}

export function Build(rows: DashboardRow[], actions: Map<string, number>, omega: OmegaLike, topActions = 8) {
	let totalCash: unknown = 0;
	let richest: unknown = 0;
	const production: number[] = [];
	const rebirths: number[] = [];
	let stardust = 0;
	let cores = 0;
	for (const row of rows) {
		totalCash = omega.Add(totalCash, row.Cash ?? 0);
		if (omega.Gt(row.Cash ?? 0, richest)) richest = row.Cash;
		production.push(omega.ToNumber(row.Production ?? 0));
		rebirths.push(finite(row.Rebirths));
		stardust += finite(row.Stardust);
		cores += finite(row.Cores);
	}
	const actionRows: Array<{ Action: string; Count: number }> = [];
	for (const [action, count] of actions) actionRows.push({ Action: action, Count: count });
	actionRows.sort((a, b) => (a.Count !== b.Count ? a.Count > b.Count : a.Action < b.Action));
	while (actionRows.size() > topActions) actionRows.pop();
	return {
		Players: rows.size(),
		TotalCash: totalCash,
		RichestCash: richest,
		MedianProduction: median(production),
		MedianRebirths: median(rebirths),
		TotalStardust: stardust,
		TotalCores: cores,
		TopActions: actionRows,
	};
}
