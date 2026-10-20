// One-time client hints the server remembers in Flags.SeenHints. Only ids on this allow-list
// are stored; add an id here before a client hint uses it.
export const HINT_IDS: ReadonlyArray<string> = table.freeze([
	"QuickFind",
	"MobileTabPins",
	"MobileHudEditor",
	"ChatWhisper",
	"ProfileStyle",
	"TradeInvite",
]);

const HINT_SET = new Set(HINT_IDS);

export function isHintId(id: unknown): id is string {
	return typeIs(id, "string") && HINT_SET.has(id);
}

/** Known hint ids only, no repeats, in first-seen order. */
export function normalizeSeenHints(raw: unknown): string[] {
	const seen = new Array<string>();
	if (!typeIs(raw, "table")) {
		return seen;
	}
	for (const id of raw as unknown[]) {
		if (seen.size() >= HINT_IDS.size()) {
			break;
		}
		if (isHintId(id) && !seen.includes(id)) {
			seen.push(id);
		}
	}
	return seen;
}
