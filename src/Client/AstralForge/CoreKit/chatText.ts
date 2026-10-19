export function limit(text: unknown, maxCharacters?: number): string {
	if (!typeIs(text, "string")) {
		return "";
	}
	const length = utf8.len(text)[0];
	if (length === undefined || length === false) {
		return "";
	}
	const cap = math.max(0, math.floor(maxCharacters ?? 160));
	if (length <= cap) {
		return text;
	}
	return text.sub(1, (utf8.offset(text, cap + 1) ?? text.size() + 1) - 1);
}

// byte cap (servers measure #text) that never leaves half a UTF-8 character behind
export function cutBytes(text: unknown, maxBytes?: number): string {
	if (!typeIs(text, "string")) {
		return "";
	}
	const stop = math.max(0, math.floor(maxBytes ?? 0));
	if (text.size() <= stop) {
		return text;
	}
	let index = stop + 1;
	while (index > 1 && index > stop - 3) {
		const [byte] = text.byte(index);
		if (byte < 0x80 || byte >= 0xc0) {
			break;
		}
		index -= 1;
	}
	return text.sub(1, index - 1);
}

// first visible character for monogram badges
export function initial(text: unknown, fallback?: string): string {
	const first = typeIs(text, "string") ? text.match(utf8.charpattern)[0] : undefined;
	return tostring(first ?? fallback ?? "?").upper();
}
