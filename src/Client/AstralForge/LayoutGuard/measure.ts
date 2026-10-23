// Text measurement with a bounded LRU cache.
//
// TextService:GetTextBoundsAsync is the only API that honours FontFace (custom families and
// weights); GetTextSize only takes the legacy Enum.Font. GetTextBoundsAsync yields and can fail
// for unloaded fonts, so calls are wrapped in pcall and fall back to GetTextSize (when the
// FontFace maps to an Enum.Font) and finally to the layoutSim approximation. The guard calls this
// from its scan coroutine only; render code keeps using UiCore/layoutEngine.measureText.
import { approxMeasure } from "./layoutSim";

const TextService = game.GetService("TextService");

const fonts = new Map<string, Font>();
const legacy = new Map<string, Enum.Font>();

/** Capture registers each FontFace it meets under the key it stores in TextInfo.font. */
export function fontKey(face: Font, legacyFont?: Enum.Font): string {
	const key = `${face.Family}|${face.Weight.Name}|${face.Style.Name}`;
	if (!fonts.has(key)) fonts.set(key, face);
	if (legacyFont !== undefined && legacyFont !== Enum.Font.Unknown && !legacy.has(key)) legacy.set(key, legacyFont);
	return key;
}

interface Entry {
	x: number;
	y: number;
	used: number;
}

const CAPACITY = 1024;
const cache = new Map<string, Entry>();
let cacheSize = 0;
let tick = 0;
export const measureStats = { hits: 0, misses: 0, failures: 0, evictions: 0 };

function evictOldest() {
	// O(n) scan at capacity; amortised over CAPACITY/8 inserts because we drop the oldest eighth
	const ages: [string, number][] = [];
	for (const [k, e] of cache) ages.push([k, e.used]);
	ages.sort((a, b) => a[1] < b[1]);
	const drop = math.max(1, math.floor(CAPACITY / 8));
	for (let i = 0; i < drop && i < ages.size(); i++) {
		cache.delete(ages[i][0]);
		cacheSize -= 1;
		measureStats.evictions += 1;
	}
}

function compute(text: string, size: number, font: string, maxWidth: number): { x: number; y: number } {
	const face = fonts.get(font);
	const width = maxWidth === math.huge || maxWidth <= 0 ? 100000 : maxWidth;
	if (face !== undefined) {
		const params = new Instance("GetTextBoundsParams");
		params.Text = text;
		params.Font = face;
		params.Size = size;
		params.Width = width;
		const [ok, result] = pcall(() => TextService.GetTextBoundsAsync(params));
		params.Destroy();
		if (ok) return { x: (result as Vector2).X, y: (result as Vector2).Y };
		measureStats.failures += 1;
	}
	const fallback = legacy.get(font);
	if (fallback !== undefined) {
		const [ok, result] = pcall(() => TextService.GetTextSize(text, size, fallback, new Vector2(width, 100000)));
		if (ok) return { x: result.X, y: result.Y };
	}
	return approxMeasure(text, size, font, maxWidth);
}

export function measure(text: string, size: number, font: string, maxWidth: number): { x: number; y: number } {
	const key = `${font}|${size}|${math.floor(maxWidth === math.huge ? -1 : maxWidth)}|${text}`;
	tick += 1;
	const hit = cache.get(key);
	if (hit !== undefined) {
		hit.used = tick;
		measureStats.hits += 1;
		return hit;
	}
	measureStats.misses += 1;
	const m = compute(text, size, font, maxWidth);
	if (cacheSize >= CAPACITY) evictOldest();
	cache.set(key, { x: m.x, y: m.y, used: tick });
	cacheSize += 1;
	return m;
}

export function clearMeasureCache() {
	cache.clear();
	cacheSize = 0;
}
