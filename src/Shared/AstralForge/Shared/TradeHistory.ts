// Completed-trade history and pre-confirm warnings. Pure: the server records entries inside the
// same atomic save that applies each side of a trade; the client shows them on the Trade page.

type Dict = Record<string, unknown>;

interface Entry {
	Id: string;
	At: number;
	PartnerId: number;
	Partner: string;
	Gave: string;
	Got: string;
}

const LIMIT = 15;

const CURRENCIES = [
	{ key: "Cash", label: "flux" },
	{ key: "Stardust", label: "dust" },
	{ key: "Cores", label: "cores" },
	{ key: "Signals", label: "signals" },
	{ key: "Essence", label: "essence" },
];

function hasAny(value: object): boolean {
	for (const _ of pairs(value)) {
		return true;
	}
	return false;
}

function positive(value: unknown): boolean {
	if (typeIs(value, "number")) {
		return value === value && value > 0;
	}
	// big-number flux values arrive as tables; anything non-zero counts
	return typeIs(value, "table") && hasAny(value) && tostring(value) !== "0";
}

function countMap(map: unknown): number {
	let total = 0;
	if (typeIs(map, "table")) {
		for (const [, count] of pairs(map as Dict)) {
			if (typeIs(count, "number") && count > 0) {
				total += count;
			}
		}
	}
	return total;
}

// True when an offer carries nothing at all.
function isEmpty(offer: unknown): boolean {
	if (!typeIs(offer, "table")) {
		return true;
	}
	const o = offer as Dict;
	for (const currency of CURRENCIES) {
		if (positive(o[currency.key])) {
			return false;
		}
	}
	return (
		countMap(o.Boosts) === 0 &&
		countMap(o.Keys) === 0 &&
		(!typeIs(o.ItemIds, "table") || (o.ItemIds as defined[]).size() === 0)
	);
}

// "1.2K flux, 30 dust, 2 boosts, Ember Crown". `format` renders a currency amount.
function summarize(offer: unknown, itemNames?: string[], format?: (value: unknown) => string): string {
	if (!typeIs(offer, "table")) {
		return "nothing";
	}
	const o = offer as Dict;
	const render = format ?? ((value: unknown) => tostring(value));
	const parts: string[] = [];
	for (const currency of CURRENCIES) {
		if (positive(o[currency.key])) {
			parts.push(`${render(o[currency.key])} ${currency.label}`);
		}
	}
	const boosts = countMap(o.Boosts);
	const keys = countMap(o.Keys);
	if (boosts > 0) {
		parts.push(`${boosts} boost${boosts === 1 ? "" : "s"}`);
	}
	if (keys > 0) {
		parts.push(`${keys} key${keys === 1 ? "" : "s"}`);
	}
	const names = itemNames ?? [];
	for (let index = 0; index < math.min(names.size(), 3); index++) {
		parts.push(names[index]);
	}
	if (names.size() > 3) {
		parts.push(`${names.size() - 3} more item${names.size() - 3 === 1 ? "" : "s"}`);
	}
	return parts.size() === 0 ? "nothing" : parts.join(", ");
}

// Adds an entry newest-first, once per trade id, keeping at most LIMIT.
function record(trade: unknown, entry: Entry): void {
	if (!typeIs(trade, "table")) {
		return;
	}
	const t = trade as Dict;
	const list = (typeIs(t.History, "table") ? t.History : []) as defined[];
	for (let index = list.size() - 1; index >= 0; index--) {
		const item = list[index];
		if (!typeIs(item, "table") || (item as Dict).Id === entry.Id) {
			list.remove(index);
		}
	}
	list.unshift(entry);
	while (list.size() > LIMIT) {
		list.pop();
	}
	t.History = list;
}

// Drops an entry again when its side of the trade is reverted.
function remove(trade: unknown, id: string): void {
	if (!typeIs(trade, "table") || !typeIs((trade as Dict).History, "table")) {
		return;
	}
	const history = (trade as Dict).History as defined[];
	for (let index = history.size() - 1; index >= 0; index--) {
		const entry = history[index];
		if (typeIs(entry, "table") && (entry as Dict).Id === id) {
			history.remove(index);
		}
	}
}

// A clean copy for the client: only well-formed entries, bounded strings.
function publicEntries(trade: unknown): Entry[] {
	const out: Entry[] = [];
	if (!typeIs(trade, "table") || !typeIs((trade as Dict).History, "table")) {
		return out;
	}
	for (const raw of (trade as Dict).History as defined[]) {
		const entry = raw as Dict;
		if (
			typeIs(raw, "table") &&
			typeIs(entry.Id, "string") &&
			typeIs(entry.At, "number") &&
			typeIs(entry.Partner, "string") &&
			typeIs(entry.Gave, "string") &&
			typeIs(entry.Got, "string")
		) {
			out.push({
				Id: entry.Id,
				At: entry.At,
				PartnerId: tonumber(entry.PartnerId) ?? 0,
				Partner: entry.Partner.sub(1, 40),
				Gave: entry.Gave.sub(1, 160),
				Got: entry.Got.sub(1, 160),
			});
			if (out.size() >= LIMIT) {
				break;
			}
		}
	}
	return out;
}

const RARITY_RANK: Record<string, number> = { COMMON: 1, UNCOMMON: 2, RARE: 3, EPIC: 4, LEGENDARY: 5, MYTHIC: 6 };

function topRarity(list?: string[]): LuaTuple<[number, string | undefined]> {
	let best = 0;
	let name: string | undefined = undefined;
	for (const rarity of list ?? []) {
		const rank = RARITY_RANK[tostring(rarity).upper()] ?? 0;
		if (rank > best) {
			best = rank;
			name = rarity;
		}
	}
	return $tuple(best, name);
}

// Warnings shown above Confirm. They never block a trade; they make one-sided offers obvious.
// `myRarities` / `theirRarities` list the rarity of each relic on either side, when known.
function warnings(mine: unknown, theirs: unknown, myRarities?: string[], theirRarities?: string[]): string[] {
	const out: string[] = [];
	const giving = !isEmpty(mine);
	const getting = !isEmpty(theirs);
	if (giving && !getting) {
		out.push("You get nothing back in this trade. Only confirm if it's a gift.");
	} else if (getting && !giving) {
		out.push("You're not giving anything. Your partner is offering a gift.");
	}
	const myItems =
		typeIs(mine, "table") && typeIs((mine as Dict).ItemIds, "table") ? ((mine as Dict).ItemIds as defined[]).size() : 0;
	const theirItems =
		typeIs(theirs, "table") && typeIs((theirs as Dict).ItemIds, "table")
			? ((theirs as Dict).ItemIds as defined[]).size()
			: 0;
	if (myItems >= 3 && theirItems === 0) {
		out.push(`You're giving ${myItems} items and getting none. Check the other side before you confirm.`);
	}
	// a top-tier relic going out with nothing close to it coming back
	const [myTop, myName] = topRarity(myRarities);
	const [theirTop] = topRarity(theirRarities);
	if (myTop >= RARITY_RANK.LEGENDARY && theirTop < myTop - 1) {
		const label = (myName ?? "").sub(1, 1).upper() + (myName ?? "").sub(2).lower();
		out.push(`You're giving a ${label} relic and getting nothing close to it back.`);
	}
	return out;
}

export = table.freeze({ LIMIT, isEmpty, summarize, record, remove, public: publicEntries, warnings });
