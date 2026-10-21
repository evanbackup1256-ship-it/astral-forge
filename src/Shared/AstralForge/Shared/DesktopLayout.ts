// Versioned codec + limits for the desktop HUD layout editor.
// Stored on the profile as one compact string (Flags.DesktopLayout); only values that differ from
// the defaults are written, so old saves (empty string) decode to the stock layout.

type Kind = "int" | "unit" | "bool" | "order";
interface Field {
	key: string;
	element: string;
	kind: Kind;
	default: number | string;
	min?: number;
	max?: number;
	step?: number;
	// order fields: the letters that may appear (each exactly once)
	letters?: string;
}

const VERSION = "d1";
const MAX_LENGTH = 400;
const GRID = 8;
// floating elements without a saved spot keep their docked position
const DOCKED = -1;

// top bar chip letters: F flux, C cores, D dust, E event, P companion
const CHIP_LETTERS = "FCDEP";

const FIELDS: ReadonlyArray<Field> = table.freeze([
	{ key: "nav.side", element: "nav", kind: "bool", default: 0 },
	{ key: "nav.width", element: "nav", kind: "int", default: 0, min: 0, max: 100, step: 5 },
	{ key: "nav.collapsed", element: "nav", kind: "bool", default: 0 },
	{ key: "top.height", element: "top", kind: "int", default: 50, min: 0, max: 100, step: 5 },
	{ key: "top.order", element: "top", kind: "order", default: "FDCPE", letters: CHIP_LETTERS },
	{ key: "top.hideCores", element: "top", kind: "bool", default: 0 },
	{ key: "top.hideDust", element: "top", kind: "bool", default: 0 },
	{ key: "top.hideEvent", element: "top", kind: "bool", default: 0 },
	{ key: "top.hideCompanion", element: "top", kind: "bool", default: 0 },
	{ key: "island.x", element: "island", kind: "unit", default: DOCKED },
	{ key: "island.y", element: "island", kind: "unit", default: DOCKED },
	{ key: "island.scale", element: "island", kind: "int", default: 100, min: 80, max: 125, step: 5 },
	{ key: "combo.x", element: "combo", kind: "unit", default: DOCKED },
	{ key: "combo.y", element: "combo", kind: "unit", default: DOCKED },
	{ key: "combo.scale", element: "combo", kind: "int", default: 100, min: 80, max: 140, step: 5 },
	{ key: "combo.hidden", element: "combo", kind: "bool", default: 0 },
	{ key: "page.width", element: "page", kind: "int", default: 100, min: 70, max: 100, step: 5 },
]);

const ELEMENTS = table.freeze(["nav", "top", "island", "combo", "page"]);

// pixel limits the 0..100 sliders map onto
const LIMITS = table.freeze({
	navMin: 212,
	navMax: 320,
	topMin: 56,
	topMax: 88,
	pageMinWidth: 720,
});

const byKey: Record<string, Field | undefined> = {};
for (const field of FIELDS) {
	byKey[field.key] = field;
}

type Layout = Record<string, number | string>;

function validOrder(raw: unknown, letters: string): boolean {
	if (!typeIs(raw, "string") || raw.size() !== letters.size()) {
		return false;
	}
	for (let index = 1; index <= letters.size(); index++) {
		const letter = letters.sub(index, index);
		const [found] = raw.find(letter, 1, true);
		if (found === undefined) {
			return false;
		}
	}
	return true;
}

function clean(field: Field, raw: unknown): number | string | undefined {
	if (field.kind === "order") {
		return validOrder(raw, field.letters ?? "") ? (raw as string) : undefined;
	}
	const num = tonumber(raw);
	if (num === undefined || num !== num || num === math.huge || num === -math.huge) {
		return undefined;
	}
	if (field.kind === "bool") {
		return num >= 0.5 ? 1 : 0;
	}
	if (field.kind === "unit") {
		if (num < 0) {
			return DOCKED;
		}
		return math.floor(math.clamp(num, 0, 1) * 1000 + 0.5) / 1000;
	}
	const step = field.step ?? 1;
	const stepped = math.floor(num / step + 0.5) * step;
	return math.clamp(stepped, field.min ?? 0, field.max ?? 100);
}

function Defaults(): Layout {
	const layout: Layout = {};
	for (const field of FIELDS) {
		layout[field.key] = field.default;
	}
	return layout;
}

function Decode(raw: unknown): Layout {
	const layout = Defaults();
	if (!typeIs(raw, "string") || raw.size() > MAX_LENGTH) {
		return layout;
	}
	const parts = raw.split("|");
	if (parts[0] !== VERSION) {
		return layout;
	}
	for (let index = 1; index < parts.size(); index++) {
		const [key, value] = parts[index].match("^([%a%.]+)=([%w%.%-]+)$");
		const field = key !== undefined ? byKey[key as string] : undefined;
		if (field !== undefined) {
			const cleaned = clean(field, value);
			if (cleaned !== undefined) {
				layout[field.key] = cleaned;
			}
		}
	}
	// a spot is all-or-nothing: half a position falls back to docked
	for (const id of ["island", "combo"]) {
		if (layout[id + ".x"] === DOCKED || layout[id + ".y"] === DOCKED) {
			layout[id + ".x"] = DOCKED;
			layout[id + ".y"] = DOCKED;
		}
	}
	return layout;
}

function Encode(layout: unknown): string {
	const parts: string[] = [VERSION];
	const source = typeIs(layout, "table") ? (layout as Record<string, unknown>) : {};
	for (const field of FIELDS) {
		const cleaned = source[field.key] !== undefined ? clean(field, source[field.key]) : undefined;
		if (cleaned !== undefined && cleaned !== field.default) {
			parts.push(field.kind === "unit" && cleaned !== DOCKED ? "%s=%.3f".format(field.key, cleaned as number) : `${field.key}=${cleaned}`);
		}
	}
	return parts.size() === 1 ? "" : parts.join("|");
}

// Round-trips untrusted input so only canonical, bounded strings reach the save.
function Normalize(raw: unknown): string | undefined {
	if (raw === "") {
		return "";
	}
	if (!typeIs(raw, "string") || raw.size() > MAX_LENGTH || raw.split("|")[0] !== VERSION) {
		return undefined;
	}
	return Encode(Decode(raw));
}

function ResetElement(layout: Layout, element: string): Layout {
	const updated = table.clone(layout);
	for (const field of FIELDS) {
		if (field.element === element) {
			updated[field.key] = field.default;
		}
	}
	return updated;
}

function SetValue(layout: Layout, key: string, value: unknown): Layout {
	const field = byKey[key];
	if (field === undefined) {
		return layout;
	}
	const cleaned = clean(field, value);
	if (cleaned === undefined || layout[key] === cleaned) {
		return layout;
	}
	const updated = table.clone(layout);
	updated[key] = cleaned;
	return updated;
}

function IsCustom(layout: Layout, element?: string): boolean {
	for (const field of FIELDS) {
		if ((element === undefined || field.element === element) && layout[field.key] !== field.default) {
			return true;
		}
	}
	return false;
}

function lerp(a: number, b: number, t: number): number {
	return math.floor(a + (b - a) * math.clamp(t, 0, 1) + 0.5);
}

// Resolved pixel plan for the shell; viewportWidth keeps the content area usable.
function Resolve(layout: Layout, viewportWidth: number, baseNav: number, baseTop: number) {
	const navWidth = (layout["nav.width"] as number) === 0 ? baseNav : lerp(LIMITS.navMin, LIMITS.navMax, (layout["nav.width"] as number) / 100);
	const topRaw = layout["top.height"] as number;
	const topHeight = topRaw === 50 ? baseTop : lerp(LIMITS.topMin, LIMITS.topMax, topRaw / 100);
	const pageShare = (layout["page.width"] as number) / 100;
	const pageMax = pageShare >= 1 ? math.huge : math.max(LIMITS.pageMinWidth, math.floor(viewportWidth * pageShare));
	return {
		navRight: layout["nav.side"] === 1,
		navWidth: math.clamp(navWidth, LIMITS.navMin, math.min(LIMITS.navMax, math.max(LIMITS.navMin, math.floor(viewportWidth * 0.3)))),
		navCollapsed: layout["nav.collapsed"] === 1,
		topHeight,
		chipOrder: layout["top.order"] as string,
		hideCores: layout["top.hideCores"] === 1,
		hideDust: layout["top.hideDust"] === 1,
		hideEvent: layout["top.hideEvent"] === 1,
		hideCompanion: layout["top.hideCompanion"] === 1,
		islandAt: layout["island.x"] === DOCKED ? undefined : new Vector2(layout["island.x"] as number, layout["island.y"] as number),
		islandScale: (layout["island.scale"] as number) / 100,
		comboAt: layout["combo.x"] === DOCKED ? undefined : new Vector2(layout["combo.x"] as number, layout["combo.y"] as number),
		comboScale: (layout["combo.scale"] as number) / 100,
		comboHidden: layout["combo.hidden"] === 1,
		pageMax,
	};
}

export = table.freeze({
	VERSION,
	MAX_LENGTH,
	GRID,
	DOCKED,
	CHIP_LETTERS,
	FIELDS,
	ELEMENTS,
	LIMITS,
	Defaults,
	Decode,
	Encode,
	Normalize,
	ResetElement,
	SetValue,
	IsCustom,
	Resolve,
});
