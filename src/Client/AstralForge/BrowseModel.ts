// Search, category and sort logic shared by every browsable page and Quick Find.
// No Roblox APIs and no imports (so no runtime library), so the Lune suite can test it directly.

interface Category {
	id: string;
	label: string;
	icon?: string;
	test?: (this: void, item: unknown) => boolean;
}
interface Sort {
	id: string;
	label: string;
	compare?: (this: void, a: unknown, b: unknown) => boolean;
}
type TextFn = (this: void, item: unknown) => Array<string | undefined> | undefined;
interface Options {
	text?: TextFn;
	fields?: (this: void, item: unknown) => string[];
	categories?: Category[];
	sorts?: Sort[];
	aliases?: Record<string, string[]>;
}
interface Result {
	results: defined[];
	counts: Record<string, number>;
	matched: number;
	total: number;
	relevance: boolean;
}
interface Memory {
	query: string;
	category?: string;
	sort?: string;
}

// Luau `a or b`: only nil and false fall through.
function luaOr(...values: unknown[]): unknown {
	for (const value of values) {
		if (value !== undefined && value !== false) {
			return value;
		}
	}
	return values[values.size() - 1];
}

// Words players type for things the game names differently.
const ALIASES: Record<string, string[]> = {
	money: ["flux", "cash", "vault"],
	cash: ["flux", "vault"],
	gems: ["stardust", "dust"],
	pet: ["relic", "companion"],
	pets: ["relics", "companions"],
	items: ["relics", "inventory"],
	upgrade: ["research", "machine", "level"],
	upgrades: ["research", "machines"],
	friends: ["crew", "guild", "trade"],
	daily: ["rewards", "missions", "streak"],
	spin: ["wheel"],
	market: ["bazaar", "supplies", "shipments"],
	quest: ["mission", "milestone", "story"],
	quests: ["missions", "milestones"],
	options: ["settings"],
	sound: ["audio", "volume", "music"],
	inbox: ["mail"],
	rank: ["leaderboards", "ranks", "level"],
	top: ["leaderboards"],
	potion: ["boost"],
	potions: ["boosts"],
	buff: ["boost"],
	zone: ["worlds", "world"],
	map: ["worlds"],
};

function normalize(value: unknown): string {
	let source: string;
	if (!typeIs(value, "string")) {
		source = value === undefined ? "" : tostring(value);
	} else {
		source = value;
	}
	let text = source.lower();
	// strip rich text tags and punctuation so "<b>Auto-Gear</b>" matches "auto gear"
	text = text.gsub("<[^>]->", " ")[0];
	text = text.gsub("[^%w%s]", " ")[0];
	text = text.gsub("%s+", " ")[0];
	const [trimmed] = text.match("^%s*(.-)%s*$");
	return (trimmed as string | undefined) ?? "";
}

function tokens(query: string): string[] {
	const list: string[] = [];
	for (const [word] of normalize(query).gmatch("%S+")) {
		list.push(word as string);
	}
	return list;
}

// Levenshtein distance capped at `limit` (returns limit + 1 when farther).
function distance(a: string, b: string, limit: number): number {
	const la = a.size();
	const lb = b.size();
	if (math.abs(la - lb) > limit) {
		return limit + 1;
	}
	let previous = new Array<number>(lb + 1, 0);
	for (let j = 0; j <= lb; j++) {
		previous[j] = j;
	}
	for (let i = 1; i <= la; i++) {
		const current = new Array<number>(lb + 1, 0);
		current[0] = i;
		let best = i;
		const [ca] = a.byte(i);
		for (let j = 1; j <= lb; j++) {
			const cost = ca === b.byte(j)[0] ? 0 : 1;
			const value = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost);
			current[j] = value;
			if (value < best) {
				best = value;
			}
		}
		if (best > limit) {
			return limit + 1;
		}
		previous = current;
	}
	return previous[lb];
}

// How well one query token matches one normalized field. 0 means no match.
function tokenScore(token: string, field: string): number {
	if (token === "" || field === "") {
		return 0;
	}
	if (field === token) {
		return 10;
	}
	const [at] = field.find(token, 1, true);
	if (at !== undefined) {
		const wordStart = at === 1 || field.sub(at - 1, at - 1) === " ";
		if (at === 1) {
			return 8;
		} else if (wordStart) {
			return 6;
		}
		return 3;
	}
	// initials: "ag" finds "auto gear", "sg" finds "star grid"
	if (token.size() >= 2) {
		const [initials] = (" " + field).gsub(" (%w)%w*", "%1");
		if (initials.find(token, 1, true)[0] === 1) {
			return 4;
		}
	}
	// one typo per four letters, compared against each word's leading slice
	if (token.size() >= 4) {
		const limit = token.size() >= 8 ? 2 : 1;
		for (const [w] of field.gmatch("%S+")) {
			const word = w as string;
			if (word.size() >= token.size() - limit) {
				const slice = word.sub(1, math.max(token.size(), math.min(word.size(), token.size() + limit)));
				if (distance(token, slice, limit) <= limit || distance(token, word, limit) <= limit) {
					return 2;
				}
			}
		}
	}
	return 0;
}

// Normalizes every searchable field once; the result is cached per item by `index`.
function fieldsOf(item: unknown, text?: TextFn): string[] {
	let raw: Array<string | undefined>;
	if (text !== undefined) {
		raw = text(item) ?? [];
	} else if (typeIs(item, "table")) {
		const t = item as Record<string, unknown>;
		raw = [
			luaOr(t.Name, t.name, t.label, t.Label) as string | undefined,
			luaOr(t.Description, t.description, t.Desc) as string | undefined,
		];
	} else {
		raw = [tostring(item)];
	}
	const fields: string[] = [];
	// `[a, undefined, c]` leaves holes, so walk the declared length rather than ipairs
	let count = 0;
	for (const [key] of pairs(raw as unknown as Record<string | number, unknown>)) {
		if (typeIs(key, "number") && key > count) {
			count = key;
		}
	}
	for (let i = 0; i < count; i++) {
		const value = raw[i];
		if (value !== undefined) {
			fields.push(normalize(value));
		}
	}
	return fields;
}

// Total relevance of `query` against an item's fields; 0 when any token misses.
// Earlier fields weigh more (the name beats the description).
function score(query: string | string[], fields: string[], aliases?: Record<string, string[]>): number {
	const list = typeIs(query, "table") ? (query as string[]) : tokens(query as string);
	if (list.size() === 0) {
		return 1;
	}
	const aliasMap = aliases ?? ALIASES;
	let total = 0;
	for (const token of list) {
		let best = 0;
		fields.forEach((field, index) => {
			const weight = index === 0 ? 2 : index === 1 ? 1.25 : 1;
			const value = tokenScore(token, field) * weight;
			if (value > best) {
				best = value;
			}
		});
		if (best === 0) {
			const synonyms = aliasMap[token];
			if (synonyms !== undefined) {
				for (const synonym of synonyms) {
					fields.forEach((field, index) => {
						const weight = index === 0 ? 2 : index === 1 ? 1.25 : 1;
						const value = tokenScore(synonym, field) * weight * 0.8;
						if (value > best) {
							best = value;
						}
					});
				}
			}
		}
		if (best === 0) {
			return 0;
		}
		total += best;
	}
	return total;
}

function matches(query: string, item: unknown, text?: TextFn): boolean {
	return score(query, fieldsOf(item, text)) > 0;
}

function findById<T extends { id: string }>(list: T[] | undefined, id: string | undefined): T | undefined {
	if (list === undefined || id === undefined) {
		return undefined;
	}
	for (const entry of list) {
		if (entry.id === id) {
			return entry;
		}
	}
	return undefined;
}

// Applies the query, then counts every category against the query matches,
// then keeps the chosen category and sorts. With a query and the default sort,
// results come back best match first.
function run(items: defined[], options: Options, query: string, categoryId?: string, sortId?: string): Result {
	const list = tokens(query);
	const matched: defined[] = [];
	const scores = new Map<defined, number>();
	items.forEach((item, index) => {
		const value =
			list.size() === 0
				? 1
				: score(list, options.fields ? options.fields(item) : fieldsOf(item, options.text), options.aliases);
		if (value > 0) {
			matched.push(item);
			scores.set(item, value - (index + 1) * 1e-6);
		}
	});
	const counts: Record<string, number> = {};
	const category = findById(options.categories, categoryId);
	const results: defined[] = [];
	for (const entry of options.categories ?? []) {
		let n = 0;
		for (const item of matched) {
			if (entry.test === undefined || entry.test(item)) {
				n += 1;
			}
		}
		counts[entry.id] = n;
	}
	for (const item of matched) {
		if (category === undefined || category.test === undefined || category.test(item)) {
			results.push(item);
		}
	}
	const sorts = options.sorts;
	const sort = findById(sorts, sortId) ?? (sorts ? sorts[0] : undefined);
	let relevance = false;
	if (sort !== undefined && sort.compare !== undefined) {
		const compare = sort.compare;
		const order = new Map<defined, number>();
		results.forEach((item, index) => order.set(item, index + 1));
		results.sort((a, b) => {
			if (compare(a, b)) {
				return true;
			} else if (compare(b, a)) {
				return false;
			}
			return order.get(a)! < order.get(b)!;
		});
	} else if (list.size() > 0) {
		relevance = true;
		results.sort((a, b) => scores.get(a)! > scores.get(b)!);
	}
	return {
		results,
		counts,
		matched: matched.size(),
		total: items.size(),
		relevance,
	};
}

// Escapes rich text and bolds the first hit of each query token, for result rows.
function highlight(text: string, query: string, color?: string): string {
	const escape = (value: string): string => value.gsub("&", "&amp;")[0].gsub("<", "&lt;")[0].gsub(">", "&gt;")[0];
	const list = tokens(query);
	if (list.size() === 0) {
		return escape(text);
	}
	const lower = text.lower();
	const marks: Array<[number, number]> = [];
	for (const token of list) {
		const [at] = lower.find(token, 1, true);
		if (at !== undefined) {
			marks.push([at, at + token.size() - 1]);
		}
	}
	if (marks.size() === 0) {
		return escape(text);
	}
	marks.sort((a, b) => a[0] < b[0]);
	const out: string[] = [];
	let cursor = 1;
	const open = color !== undefined ? `<b><font color="${color}">` : "<b>";
	const close = color !== undefined ? "</font></b>" : "</b>";
	for (const mark of marks) {
		if (mark[0] >= cursor) {
			out.push(escape(text.sub(cursor, mark[0] - 1)));
			out.push(open + escape(text.sub(mark[0], mark[1])) + close);
			cursor = mark[1] + 1;
		}
	}
	out.push(escape(text.sub(cursor)));
	return out.join("");
}

// Session memory so a page keeps its search, category and sort when you come back.
const memory: Record<string, Memory> = {};
function remember(id: string, entry: Memory): void {
	memory[id] = entry;
}
function recall(id: string): Memory | undefined {
	return memory[id];
}

// Deep links (Quick Find -> a page): remembered for a page that mounts later, and pushed
// live to a page that is already open.
type Listener = (this: void, entry: Memory) => void;
const listeners: Record<string, Listener[]> = {};
function link(id: string, entry: Memory): void {
	const previous = memory[id] as Memory | undefined;
	memory[id] = {
		query: entry.query,
		category: entry.category,
		sort: entry.sort ?? (previous ? previous.sort : undefined),
	};
	for (const listener of [...(listeners[id] ?? [])]) {
		listener(memory[id]);
	}
}
function listen(id: string, listener: Listener): () => void {
	const list = listeners[id] ?? [];
	listeners[id] = list;
	list.push(listener);
	return () => {
		const at = list.indexOf(listener);
		if (at !== -1) {
			list.remove(at);
		}
	};
}

// Recent Quick Find picks, newest first.
const recents: string[] = [];
function pushRecent(key: string, limit?: number): void {
	const at = recents.indexOf(key);
	if (at !== -1) {
		recents.remove(at);
	}
	recents.unshift(key);
	while (recents.size() > (limit ?? 6)) {
		recents.pop();
	}
}
function recent(): string[] {
	return [...recents];
}

const Model = {
	ALIASES,
	normalize,
	tokens,
	distance,
	tokenScore,
	fieldsOf,
	score,
	matches,
	findById,
	run,
	highlight,
	remember,
	recall,
	link,
	listen,
	pushRecent,
	recent,
};

export = Model;
