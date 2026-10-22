// Title transparency must reach the renderer as a plain number. Callers may hand
// us a React binding (chat rows fade titles in), so resolve it here first.
export function markupNumber(value: unknown, fallback: number): number {
	if (typeIs(value, "number") && value === value) {
		return value;
	}
	return fallback;
}

