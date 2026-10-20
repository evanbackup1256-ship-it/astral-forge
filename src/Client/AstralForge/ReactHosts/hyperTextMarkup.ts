// Values written into HyperText default markups must be plain numbers.
// HyperText's trans/stroke markups assign markups.trans.value straight to
// TextTransparency / UIStroke.Transparency on every printed character, so a
// React binding (a table) there spams "value of type table cannot be converted
// to a number" from ApplyTrans / stroke. Callers may hand us a binding (chat
// rows fade titles in), so resolve to a number before it reaches the library.
export function markupNumber(value: unknown, fallback: number): number {
	if (typeIs(value, "number") && value === value) {
		return value;
	}
	return fallback;
}

