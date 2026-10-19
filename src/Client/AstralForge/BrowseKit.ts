// Shared browsing UI for every list page: one hook (search + category + sort, remembered
// per page for the session) and one bar (search field, sort menu, category chips with live
// counts). The matching rules live in BrowseModel so Lune can test them.
import React from "@rbxts/react";
import ArtKit = require("./ArtKit");
import Model = require("./BrowseModel");
import * as theme from "./CoreKit/theme";

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

type BarHeight = (this: void, stack: boolean | undefined, hasChips: boolean | undefined) => number;

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

const barHeight: BarHeight = (stack, hasChips) => {
	const row = stack === true ? TapTarget : 40;
	return row + (hasChips === true ? Kit.ROW_GAP + Kit.CHIP_H : 0);
};
Kit.barHeight = barHeight;

interface ChipProps {
	id: string;
	label: string;
	icon?: string;
	count?: number;
	selected?: boolean;
	accent?: Color3;
	onSelect?: (this: void, id: string) => void;
	layoutOrder?: number;
	zIndex?: number;
}

function Chip(props: ChipProps): React.Element {
	const [hovered, setHovered] = React.useState(false);
	const selected = props.selected === true;
	const accent = props.accent;
	const count = props.count;
	const empty = count !== undefined && count === 0 && !selected;
	return h(
		"textbutton",
		{
			Size: UDim2.fromOffset(0, Kit.CHIP_H),
			AutomaticSize: Enum.AutomaticSize.X,
			BackgroundColor3: selected ? accent : hovered ? Palette.panelRaised : Palette.panelSoft,
			BackgroundTransparency: selected ? 0.05 : empty ? 0.5 : 0.15,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			LayoutOrder: props.layoutOrder,
			ZIndex: props.zIndex,
			Event: {
				Activated: () => {
					props.onSelect?.(props.id);
				},
				MouseEnter: () => {
					setHovered(true);
				},
				MouseLeave: () => {
					setHovered(false);
				},
			},
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h("uistroke", {
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			Color: selected ? theme.lighten(accent ?? Palette.cyan, 0.25) : Palette.lineSoft,
			Transparency: selected ? 0.2 : 0.55,
			Thickness: 1,
		}),
		h("uipadding", {
			PaddingLeft: new UDim(0, 12),
			PaddingRight: new UDim(0, count !== undefined ? 6 : 12),
		}),
		h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, 6),
		}),
		props.icon !== undefined &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(16, 16),
					BackgroundTransparency: 1,
					LayoutOrder: 0,
					ZIndex: (props.zIndex ?? 0) + 1,
				},
				h(Icon, {
					kind: props.icon,
					color: selected ? Palette.ink : Palette.creamSoft,
					accent: accent,
					size: 16,
					spin: false,
				}),
			),
		h("textlabel", {
			Size: UDim2.fromOffset(0, Kit.CHIP_H),
			AutomaticSize: Enum.AutomaticSize.X,
			BackgroundTransparency: 1,
			Text: props.label,
			TextSize: 13,
			FontFace: Font.fromName("BuilderSans", selected ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold),
			TextColor3: selected ? Palette.ink : empty ? Palette.muted : Palette.creamSoft,
			LayoutOrder: 1,
			ZIndex: (props.zIndex ?? 0) + 1,
		}),
		count !== undefined &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(0, 20),
					AutomaticSize: Enum.AutomaticSize.X,
					BackgroundColor3: selected ? Palette.ink : Palette.ink,
					BackgroundTransparency: selected ? 0.55 : 0.35,
					BorderSizePixel: 0,
					LayoutOrder: 2,
					ZIndex: (props.zIndex ?? 0) + 1,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uipadding", {
					PaddingLeft: new UDim(0, 7),
					PaddingRight: new UDim(0, 7),
				}),
				h("textlabel", {
					Size: UDim2.fromOffset(0, 20),
					AutomaticSize: Enum.AutomaticSize.X,
					BackgroundTransparency: 1,
					Text: tostring(count),
					TextSize: 12,
					FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
					TextColor3: selected ? Palette.cream : Palette.muted,
					ZIndex: (props.zIndex ?? 0) + 2,
				}),
			),
	);
}
Kit.Chip = Chip;

interface ChipRowProps {
	options?: ReadonlyArray<BrowseOption>;
	value?: string;
	onChange?: (this: void, id: string) => void;
	counts?: Record<string, number>;
	accent?: Color3;
	fadeColor?: Color3;
	position?: UDim2;
	size?: UDim2;
	layoutOrder?: number;
	zIndex?: number;
}

// Horizontally scrolling category chips; `counts` adds a live tally to each chip.
Kit.ChipRow = function (props: ChipRowProps): React.Element {
	const children: Record<string, React.Element> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, 6),
		}),
	};
	const zIndex = props.zIndex ?? 6;
	for (const [index, entry] of ipairs(props.options ?? [])) {
		children[entry.id] = h(Chip, {
			id: entry.id,
			label: entry.label,
			icon: entry.icon,
			count: props.counts !== undefined ? props.counts[entry.id] : undefined,
			selected: entry.id === props.value,
			accent: entry.accent ?? props.accent ?? Palette.cyan,
			onSelect: props.onChange,
			layoutOrder: index,
			zIndex: zIndex,
		});
	}
	// when the chips don't all fit, the far edge fades out (and fades back at the start once
	// scrolled), so a chip cut by the edge reads as "more this way" rather than as broken
	const rowRef = React.useRef<ScrollingFrame>();
	const [fades, setFades] = React.useState({ left: false, right: false });
	React.useEffect(() => {
		const row = rowRef.current;
		if (row === undefined) {
			return undefined;
		}
		const measure = () => {
			const spare = row.AbsoluteCanvasSize.X - row.AbsoluteSize.X;
			const left = spare > 2 && row.CanvasPosition.X > 2;
			const right = spare > 2 && row.CanvasPosition.X < spare - 2;
			setFades((current) => {
				if (current.left === left && current.right === right) {
					return current;
				}
				return { left: left, right: right };
			});
		};
		measure();
		const a = row.GetPropertyChangedSignal("AbsoluteCanvasSize").Connect(measure);
		const b = row.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		const c = row.GetPropertyChangedSignal("CanvasPosition").Connect(measure);
		return () => {
			a.Disconnect();
			b.Disconnect();
			c.Disconnect();
		};
	}, []);
	const edgeFade = (side: string) => {
		return h(
			"frame",
			{
				Size: new UDim2(0, 34, 1, 0),
				Position: side === "right" ? UDim2.fromScale(1, 0) : UDim2.fromScale(0, 0),
				AnchorPoint: side === "right" ? new Vector2(1, 0) : Vector2.zero,
				BackgroundColor3: props.fadeColor ?? Palette.panel,
				BorderSizePixel: 0,
				Active: false,
				ZIndex: zIndex + 4,
			},
			h("uigradient", {
				Transparency: new NumberSequence(1, 0),
				Rotation: side === "right" ? 0 : 180,
			}),
		);
	};
	return h(
		"frame",
		{
			Size: props.size ?? new UDim2(1, 0, 0, Kit.CHIP_H),
			Position: props.position,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: props.layoutOrder,
			ZIndex: zIndex,
		},
		h(
			"scrollingframe",
			{
				ref: rowRef,
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				CanvasSize: new UDim2(),
				AutomaticCanvasSize: Enum.AutomaticSize.X,
				ScrollingDirection: Enum.ScrollingDirection.X,
				ScrollBarThickness: 0,
				ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
				ClipsDescendants: true,
				ZIndex: zIndex,
			},
			children,
		),
		fades.right && edgeFade("right"),
		fades.left && edgeFade("left"),
	);
};

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
	const countW = stack || !hasChips ? 0 : 124;
	const summary = browse.filtered ? `${browse.results.size()} of ${browse.total}` : `${browse.total} total`;
	return h(
		"frame",
		{
			Size: props.size ?? new UDim2(1, 0, 0, barHeight(stack, hasChips)),
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
				size: new UDim2(1, -countW, 0, Kit.CHIP_H),
				zIndex: zIndex + 1,
			}),
		countW > 0 &&
			h("textbutton", {
				Size: UDim2.fromOffset(countW - 8, Kit.CHIP_H),
				Position: new UDim2(1, 0, 0, rowH + Kit.ROW_GAP),
				AnchorPoint: new Vector2(1, 0),
				BackgroundTransparency: 1,
				AutoButtonColor: false,
				Text: browse.filtered ? `${summary} · <u>Clear</u>` : summary,
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
		body = "Check the spelling or try a shorter word.";
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
