// Shared browsing UI for every list page: one hook (search + category + sort, remembered
// per page for the session) and one bar (search field, sort menu, category chips with live
// counts). The matching rules live in BrowseModel so Lune can test them.
import React from "@rbxts/react";
import ArtKit = require("./ArtKit");
import Model = require("./BrowseModel");
import * as theme from "./CoreKit/theme";
import { FilterChipRow } from "./UiCore/FilterChips";

const Workspace = game.GetService("Workspace");

type LuaKit = (name: string) => unknown;
type LooseComponent = React.FunctionComponent<Record<string, unknown>>;
interface AudioApi {
	play(cue: string, energy?: number): void;
	[key: string]: unknown;
}

// UiCore is still Luau; require it at the same point the bundled module did.
const ui = (require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as LuaKit)("ui") as Record<
	string,
	LooseComponent
>;
const Audio = (
	(require(script.Parent!.FindFirstChild("AudioKit")! as ModuleScript) as LuaKit)("audio") as {
		Audio: AudioApi;
	}
).Audio;
const Icon = (ArtKit("Icon") as { Icon: LooseComponent }).Icon;

const Palette = theme.Palette;
const TapTarget = theme.TapTarget;
const h = React.createElement as unknown as (
	type: unknown,
	props?: object,
	...children: unknown[]
) => React.Element;

interface BrowseOption {
	id: string;
	label: string;
	icon?: string;
	accent?: Color3;
	test?: (this: void, item: unknown) => boolean;
	compare?: (this: void, a: unknown, b: unknown) => boolean;
	[key: string]: unknown;
}

interface BrowseConfig {
	id?: string;
	items?: ReadonlyArray<unknown>;
	text?: (this: void, item: unknown) => Array<string | undefined> | undefined;
	textKey?: unknown;
	categories?: ReadonlyArray<BrowseOption>;
	sorts?: ReadonlyArray<BrowseOption>;
	aliases?: Record<string, string[]>;
	initialQuery?: string;
	initialCategory?: string;
	initialSort?: string;
}

interface BrowseState {
	query: string;
	setQuery: (this: void, query: string) => void;
	category: string;
	setCategory: (this: void, id: string) => void;
	sort?: string;
	setSort: (this: void, id: string) => void;
	categories?: ReadonlyArray<BrowseOption>;
	sorts?: ReadonlyArray<BrowseOption>;
	results: defined[];
	counts: Record<string, number>;
	matched: number;
	total: number;
	relevance: boolean;
	searching: boolean;
	filtered: boolean;
	firstCategory: string;
	reset: (this: void) => void;
	label: (this: void, id?: string) => string;
	[key: string]: unknown;
}

const Kit: Record<string, unknown> & { Model: typeof Model; CHIP_H: number; ROW_GAP: number } = {
	Model: Model,
	CHIP_H: 32,
	ROW_GAP: 8,
};

type BarHeight = (this: void, stack: boolean | undefined, hasChips: boolean | undefined, chipLines?: number) => number;

// Normalized fields are cached per item table, so typing stays cheap on long lists.
// Snapshots replace item tables when data changes, which naturally invalidates the cache.
const fieldCache = setmetatable(new Map<object, { key: string; fields: string[] }>(), {
	__mode: "k",
} as LuaMetatable<Map<object, { key: string; fields: string[] }>>);
function cachedFields(
	text: ((this: void, item: unknown) => Array<string | undefined> | undefined) | undefined,
	key: string,
) {
	return (item: unknown): string[] => {
		if (!typeIs(item, "table")) {
			return Model.fieldsOf(item, text);
		}
		const cached = fieldCache.get(item);
		if (cached !== undefined && cached.key === key) {
			return cached.fields;
		}
		const fields = Model.fieldsOf(item, text);
		fieldCache.set(item, { key: key, fields: fields });
		return fields;
	};
}

/*
	config = {
		id = "Boosts",                       -- remembers the choices for this page
		items = { ... },
		text = function(item) return { item.Name, item.Desc } end,
		categories = { { id = "All", label = "All" }, { id = "Ready", label = "Ready", test = fn } },
		sorts = { { id = "Default", label = "Recommended" }, { id = "Name", label = "A to Z", compare = fn } },
	}
*/
Kit.useBrowse = function (config: BrowseConfig): BrowseState {
	const saved = config.id !== undefined ? Model.recall(config.id) : undefined;
	const categories = config.categories;
	const sorts = config.sorts;
	const firstCategory = categories !== undefined && categories[0] !== undefined ? categories[0].id : "All";
	const firstSort = sorts !== undefined && sorts[0] !== undefined ? sorts[0].id : undefined;
	const [query, setQuery] = React.useState(saved !== undefined ? saved.query : (config.initialQuery ?? ""));
	let [category, setCategory] = React.useState(
		saved !== undefined && saved.category !== undefined ? saved.category : (config.initialCategory ?? firstCategory),
	);
	let [sort, setSort] = React.useState<string | undefined>(
		saved !== undefined && saved.sort !== undefined ? saved.sort : (config.initialSort ?? firstSort),
	);
	// a category that disappeared (data changed) falls back to the first one
	if (categories !== undefined && Model.findById(categories as BrowseOption[], category) === undefined) {
		category = firstCategory;
	}
	if (sorts !== undefined && Model.findById(sorts as BrowseOption[], sort) === undefined) {
		sort = firstSort;
	}
	React.useEffect(() => {
		if (config.id !== undefined) {
			Model.remember(config.id, { query: query, category: category, sort: sort });
		}
	}, [query, category, sort]);
	React.useEffect(() => {
		if (config.id === undefined) {
			return undefined;
		}
		return Model.listen(config.id, (entry) => {
			setQuery(entry.query ?? "");
			setCategory(entry.category ?? firstCategory);
			if (entry.sort !== undefined) {
				setSort(entry.sort);
			}
		});
	}, [config.id, firstCategory]);
	// `id` keys the cache; pages whose searchable text depends on more than the item pass `textKey`
	const fieldsFn = React.useMemo(() => {
		return cachedFields(config.text, `${config.id ?? ""}|${tostring(config.textKey ?? "")}`);
	}, [config.text, config.textKey]);
	const result = Model.run(
		(config.items ?? []) as defined[],
		{
			fields: fieldsFn,
			categories: categories as BrowseOption[] | undefined,
			sorts: sorts as BrowseOption[] | undefined,
			aliases: config.aliases,
		},
		query,
		category,
		sort,
	);
	const browse: BrowseState = {
		query: query,
		setQuery: setQuery,
		category: category,
		setCategory: (id: string) => {
			if (id !== category) {
				Audio.play("tabSwitch");
			}
			setCategory(id);
		},
		sort: sort,
		setSort: setSort,
		categories: categories,
		sorts: sorts,
		results: result.results,
		counts: result.counts,
		matched: result.matched,
		total: result.total,
		relevance: result.relevance,
		searching: query !== "",
		filtered: query !== "" || category !== firstCategory,
		firstCategory: firstCategory,
		reset: () => {
			setQuery("");
			setCategory(firstCategory);
		},
		label: (id?: string) => {
			const entry = Model.findById(categories as BrowseOption[] | undefined, id ?? category);
			return entry !== undefined ? entry.label : "";
		},
	};
	return browse;
};

// For pages with their own filter logic: a search string that is remembered per page and
// that Quick Find deep links fill in. Returns query, setQuery like useState.
Kit.useLinkedQuery = function (
	id: string,
	initial?: string,
): LuaTuple<[string, (query: string) => void]> {
	const saved = Model.recall(id);
	const [query, setQuery] = React.useState(saved !== undefined ? saved.query : (initial ?? ""));
	React.useEffect(() => {
		const previous = Model.recall(id);
		Model.remember(id, {
			query: query,
			category: previous !== undefined ? previous.category : undefined,
			sort: previous !== undefined ? previous.sort : undefined,
		});
	}, [query]);
	React.useEffect(() => {
		return Model.listen(id, (entry) => {
			setQuery(entry.query ?? "");
		});
	}, [id]);
	return $tuple(query, setQuery);
};

// A tab that Quick Find can open directly (links carry the tab id as `category`).
// An explicit `preferred` tab (a prop from the caller) wins over the last linked one.
Kit.useLinkedTab = function (
	id: string,
	fallback: string,
	preferred?: string,
): LuaTuple<[string, (tab: string) => void]> {
	const linked = Model.recall(id);
	const [tab, setTab] = React.useState(preferred ?? (linked !== undefined ? linked.category : undefined) ?? fallback);
	React.useEffect(() => {
		return Model.listen(id, (entry) => {
			if (entry.category !== undefined) {
				setTab(entry.category);
			}
		});
	}, [id]);
	return $tuple(tab, setTab);
};

// True when `query` fuzzily matches any of the given strings (for pages with custom filters).
Kit.matches = function (query: string | undefined, ...rest: unknown[]): boolean {
	if (query === undefined || query.match("^%s*$")[0] !== undefined) {
		return true;
	}
	const fields: string[] = [];
	for (let i = 0; i < rest.size(); i++) {
		const value = rest[i];
		if (value !== undefined) {
			fields.push(Model.normalize(value));
		}
	}
	return Model.score(query, fields) > 0;
};

// Server time that re-renders every `period` seconds (countdowns to UTC resets and deadlines).
Kit.useServerNow = function (period?: number): number {
	const [now, setNow] = React.useState(() => {
		return Workspace.GetServerTimeNow();
	});
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				task.wait(math.max(0.1, period ?? 1));
				if (alive) {
					setNow(Workspace.GetServerTimeNow());
				}
			}
		});
		return () => {
			alive = false;
		};
	}, [period]);
	return now;
};

// Seconds until the next UTC midnight, when dailies, missions and playtime drops reset.
Kit.untilUtcReset = function (now: number): number {
	return 86400 - (math.floor(now) % 86400);
};

Kit.shortDuration = function (seconds: number): string {
	seconds = math.max(0, math.floor(seconds));
	const hours = math.floor(seconds / 3600);
	const minutes = math.floor((seconds % 3600) / 60);
	if (hours > 0) {
		return `${hours}h ${minutes}m`;
	} else if (minutes > 0) {
		return `${minutes}m ${seconds % 60}s`;
	}
	return `${seconds}s`;
};

const barHeight: BarHeight = (stack, hasChips, chipLines) => {
	const row = stack === true ? TapTarget : 40;
	const lines = math.max(1, chipLines ?? 1);
	return row + (hasChips === true ? Kit.ROW_GAP + Kit.CHIP_H * lines + 4 * (lines - 1) : 0);
};
Kit.barHeight = barHeight;

// Every filter chip in the game goes through UiCore/FilterChips (one component, one
// animated selection plate). Kit.ChipRow stays as the entry point older views call.
Kit.ChipRow = FilterChipRow;

/*
	The browse bar: search + sort on the first row, category chips on the second.
	props: browse (from useBrowse), placeholder, accent, stack, reducedMotion, position, zIndex,
	       extra (an element placed right of the search on wide screens, e.g. a toggle)
*/
interface BrowseBarProps {
	browse: BrowseState;
	placeholder?: string;
	accent?: Color3;
	stack?: boolean;
	reducedMotion?: boolean;
	position?: UDim2;
	size?: UDim2;
	layoutOrder?: number;
	zIndex?: number;
	extra?: unknown;
	/** >1: chips get their own full-width block and wrap instead of scrolling under a fade */
	chipLines?: number;
}

Kit.BrowseBar = function (props: BrowseBarProps): React.Element {
	const browse = props.browse;
	const stack = props.stack === true;
	const accent = props.accent ?? Palette.cyan;
	const zIndex = props.zIndex ?? 30;
	const rowH = stack ? TapTarget : 40;
	const hasSorts = browse.sorts !== undefined && browse.sorts.size() > 1;
	const hasChips = browse.categories !== undefined && browse.categories.size() > 1;
	const sortW = !hasSorts ? 0 : stack ? 128 : 184;
	// "N total" repeated the All chip's count, so the tally only appears once a filter is on
	const countW = stack || !hasChips || !browse.filtered ? 0 : 124;
	const summary = `${browse.results.size()} of ${browse.total}`;
	const chipLines = math.max(1, props.chipLines ?? 1);
	return h(
		"frame",
		{
			Size: props.size ?? new UDim2(1, 0, 0, barHeight(stack, hasChips, chipLines)),
			Position: props.position,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: props.layoutOrder,
			ZIndex: zIndex,
		},
		h(ui.SearchField, {
			value: browse.query,
			onChange: browse.setQuery,
			placeholder: props.placeholder ?? "Search",
			accent: accent,
			reducedMotion: props.reducedMotion,
			position: UDim2.fromOffset(0, 0),
			size: new UDim2(1, -(sortW + (sortW > 0 ? 8 : 0)), 0, rowH),
			zIndex: zIndex + 2,
		}),
		hasSorts &&
			h(ui.Dropdown, {
				options: browse.sorts,
				value: browse.sort,
				onChange: browse.setSort,
				accent: accent,
				label: stack ? undefined : "Sort",
				reducedMotion: props.reducedMotion,
				position: new UDim2(1, -sortW, 0, 0),
				size: UDim2.fromOffset(sortW, rowH),
				zIndex: zIndex + 14,
			}),
		hasChips &&
			h(Kit.ChipRow as LooseComponent, {
				options: browse.categories,
				value: browse.category,
				onChange: browse.setCategory,
				counts: browse.counts,
				accent: accent,
				position: UDim2.fromOffset(0, rowH + Kit.ROW_GAP),
				size: new UDim2(1, chipLines > 1 ? 0 : -countW, 0, Kit.CHIP_H * chipLines + 4 * (chipLines - 1)),
				wrap: chipLines > 1,
				zIndex: zIndex + 1,
			}),
		countW > 0 &&
			chipLines === 1 &&
			h("textbutton", {
				Size: UDim2.fromOffset(countW - 8, Kit.CHIP_H),
				Position: new UDim2(1, 0, 0, rowH + Kit.ROW_GAP),
				AnchorPoint: new Vector2(1, 0),
				BackgroundTransparency: 1,
				AutoButtonColor: false,
				Text: `${summary} · <u>Clear</u>`,
				RichText: true,
				TextSize: 13,
				FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
				TextColor3: browse.filtered ? accent : Palette.muted,
				TextXAlignment: Enum.TextXAlignment.Right,
				Selectable: browse.filtered,
				Active: browse.filtered,
				ZIndex: zIndex + 1,
				Event: {
					Activated: () => {
						if (browse.filtered) {
							Audio.play("close");
							browse.reset();
						}
					},
				},
			}),
	);
};

interface NoResultsProps {
	browse: BrowseState;
	noun?: string;
	emptyTitle?: string;
	emptyBody?: string;
	filteredTitle?: string;
	filteredBody?: string;
	icon?: string;
	accent?: Color3;
	reducedMotion?: boolean;
	compact?: boolean;
	position?: UDim2;
	size?: UDim2;
	layoutOrder?: number;
}

// Shown when a filter leaves nothing; offers the fix instead of a dead end.
Kit.NoResults = function (props: NoResultsProps): React.Element {
	const browse = props.browse;
	const noun = props.noun ?? "items";
	let title: string;
	let body: string;
	if (browse.total === 0) {
		title = props.emptyTitle ?? `No ${noun} yet`;
		body = props.emptyBody ?? "They will show up here.";
	} else if (browse.searching && browse.matched === 0) {
		title = `Nothing matches "${browse.query}"`;
		body = "Try a shorter word.";
	} else if (browse.searching) {
		title = `No ${browse.label().lower()} ${noun} match "${browse.query}"`;
		body = `${browse.matched} found in other categories.`;
	} else {
		title = props.filteredTitle ?? `No ${browse.label().lower()} ${noun}`;
		body = props.filteredBody ?? "Try another category.";
	}
	const canClear = browse.total > 0 && browse.filtered;
	return h(
		"frame",
		{
			Size: props.size ?? new UDim2(1, 0, 0, 200),
			Position: props.position,
			BackgroundTransparency: 1,
			LayoutOrder: props.layoutOrder,
		},
		h(ui.EmptyState, {
			icon: props.icon ?? "Search.1",
			title: title,
			body: body,
			accent: props.accent,
			reducedMotion: props.reducedMotion,
			compact: props.compact,
			size: new UDim2(1, 0, 1, canClear ? -52 : 0),
		}),
		canClear &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(200, 44),
					Position: new UDim2(0.5, 0, 1, -48),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundTransparency: 1,
				},
				h(ui.Button, {
					text: browse.searching && browse.matched > 0 ? "Show all matches" : "Clear filters",
					icon: "Search.2",
					color: Palette.panelRaised,
					textColor: Palette.cream,
					size: UDim2.fromScale(1, 1),
					reducedMotion: props.reducedMotion,
					onClick: () => {
						if (browse.searching && browse.matched > 0) {
							browse.setCategory(browse.firstCategory);
						} else {
							browse.reset();
						}
					},
				}),
			),
	);
};

export = Kit;
