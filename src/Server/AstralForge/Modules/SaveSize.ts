// Encoded size of a profile save. A DataStore value is capped at 4,194,304 characters; a save
// past that fails on every attempt, so the player silently stops saving. DataService measures
// each snapshot and warns well before the cap, naming the biggest fields so ops can see what grew.

export const WARN_BYTES = 1_000_000;
export const LIMIT_BYTES = 4_194_304;
/** 75% of the DataStore cap: past this a save is one bad week from failing. */
export const NEAR_LIMIT_BYTES = math.floor(LIMIT_BYTES * 0.75);

export interface SaveMeasure {
	Bytes: number;
	Top: Array<{ Field: string; Bytes: number }>;
	/** Biggest Meta subkeys, filled when Meta is the largest field (Meta holds the journal). */
	MetaTop: Array<{ Field: string; Bytes: number }>;
}

function breakdown(bag: Record<string, unknown>, encode: (value: unknown) => string, top: number) {
	const fields: Array<{ Field: string; Bytes: number }> = [];
	for (const [field, value] of pairs(bag)) {
		const [ok, text] = pcall(() => encode(value));
		fields.push({ Field: tostring(field), Bytes: ok ? (text as string).size() : 0 });
	}
	fields.sort((a, b) => a.Bytes > b.Bytes);
	while (fields.size() > top) fields.pop();
	return fields;
}

/** Bytes of the whole snapshot; the per-field breakdown is only built when it is over WARN_BYTES. */
export function Measure(snapshot: Record<string, unknown>, encode: (value: unknown) => string, top = 3): SaveMeasure {
	const bytes = encode(snapshot).size();
	let fields: Array<{ Field: string; Bytes: number }> = [];
	let metaFields: Array<{ Field: string; Bytes: number }> = [];
	if (bytes >= WARN_BYTES) {
		fields = breakdown(snapshot, encode, top);
		const meta = snapshot.Meta;
		if (fields[0] !== undefined && fields[0].Field === "Meta" && typeIs(meta, "table")) {
			metaFields = breakdown(meta as Record<string, unknown>, encode, top);
		}
	}
	return { Bytes: bytes, Top: fields, MetaTop: metaFields };
}

export function Describe(measure: SaveMeasure): string {
	const parts = measure.Top.map((entry) => string.format("%s %d KB", entry.Field, math.floor(entry.Bytes / 1024)));
	let text = string.format("%d KB (largest: %s)", math.floor(measure.Bytes / 1024), parts.join(", "));
	if (measure.MetaTop.size() > 0) {
		const metaParts = measure.MetaTop.map((entry) => string.format("%s %d KB", entry.Field, math.floor(entry.Bytes / 1024)));
		text += string.format("; Meta: %s", metaParts.join(", "));
	}
	return text;
}
