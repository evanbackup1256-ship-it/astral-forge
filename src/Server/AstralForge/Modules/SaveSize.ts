// Encoded size of a profile save. A DataStore value is capped at 4,194,304 characters; a save
// past that fails on every attempt, so the player silently stops saving. DataService measures
// each snapshot and warns well before the cap, naming the biggest fields so ops can see what grew.

export const WARN_BYTES = 1_000_000;
export const LIMIT_BYTES = 4_194_304;

export interface SaveMeasure {
	Bytes: number;
	Top: Array<{ Field: string; Bytes: number }>;
}

/** Bytes of the whole snapshot; the per-field breakdown is only built when it is over WARN_BYTES. */
export function Measure(snapshot: Record<string, unknown>, encode: (value: unknown) => string, top = 3): SaveMeasure {
	const bytes = encode(snapshot).size();
	const fields: Array<{ Field: string; Bytes: number }> = [];
	if (bytes >= WARN_BYTES) {
		for (const [field, value] of pairs(snapshot)) {
			const [ok, text] = pcall(() => encode(value));
			fields.push({ Field: tostring(field), Bytes: ok ? (text as string).size() : 0 });
		}
		fields.sort((a, b) => a.Bytes > b.Bytes);
		while (fields.size() > top) fields.pop();
	}
	return { Bytes: bytes, Top: fields };
}

export function Describe(measure: SaveMeasure): string {
	const parts = measure.Top.map((entry) => string.format("%s %d KB", entry.Field, math.floor(entry.Bytes / 1024)));
	return string.format("%d KB (largest: %s)", math.floor(measure.Bytes / 1024), parts.join(", "));
}
