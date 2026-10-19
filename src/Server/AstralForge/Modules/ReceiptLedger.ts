// Receipt ledger: prune old purchase receipts and record new ones.

const DEFAULT_MAX = 256;

function stampOf(value: unknown): number {
	return typeIs(value, "number") ? value : 0;
}

function Prune(receipts: unknown, cap?: number): number {
	if (!typeIs(receipts, "table")) {
		return 0;
	}
	const bag = receipts as Record<string, unknown>;
	const limit = math.max(0, math.floor(tonumber(cap) ?? DEFAULT_MAX));
	let count = 0;
	for (const _ of pairs(bag)) {
		count++;
	}
	if (count <= limit) {
		return 0;
	}
	const ordered: { key: string; stamp: number }[] = [];
	for (const [key, value] of pairs(bag)) {
		ordered.push({ key: key as string, stamp: stampOf(value) });
	}
	ordered.sort((a, b) => {
		if (a.stamp === b.stamp) {
			return tostring(a.key) < tostring(b.key);
		}
		return a.stamp < b.stamp;
	});
	const removeCount = count - limit;
	for (let i = 0; i < removeCount; i++) {
		bag[ordered[i].key] = undefined!;
	}
	return removeCount;
}

function Record(
	receipts: unknown,
	purchaseKey: string,
	now: number,
	cap?: number,
): LuaTuple<[Record<string, unknown>, boolean]> {
	let bag: Record<string, unknown>;
	if (!typeIs(receipts, "table")) {
		bag = {};
	} else {
		bag = receipts as Record<string, unknown>;
	}
	if (bag[purchaseKey] !== undefined) {
		return $tuple(bag, true);
	}
	bag[purchaseKey] = typeIs(now, "number") && now === now ? now : 0;
	Prune(bag, cap);
	return $tuple(bag, false);
}

export = table.freeze({ Prune, Record });
