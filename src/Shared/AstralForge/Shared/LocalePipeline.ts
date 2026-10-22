// The localization pipeline behind T().
//
//   source table (Locale.EN)  ->  active overlay (one registered locale, may be partial)
//                             ->  format with string.format, guarded
//
// A translation is used only when it carries the same placeholders, in the same order, as the
// English copy; otherwise English is used so a bad translation can never crash a call site or
// print a raw "%s". Formatting is guarded too: a value that string.format rejects falls back to
// tostring. lintTable reports every problem in an overlay so it can be fixed before shipping.

export type CopyTable = { readonly [key: string]: string };

export interface LintProblem {
	key: string;
	kind: "UnknownKey" | "Empty" | "Placeholders" | "BadKeyName" | "Whitespace";
	detail: string;
}

const KEY_PATTERN = "^%u[%w]*%.[%w%.]+$";

const overlays = new Map<string, CopyTable>();
let activeCode = "en";
let active: CopyTable | undefined;

/** The ordered %-specs in a copy string ("%s", "%d", "%.1f" ...), ignoring escaped "%%". */
export function placeholders(copy: string): string[] {
	const [stripped] = string.gsub(copy, "%%%%", "");
	const found: string[] = [];
	for (const [spec] of string.gmatch(stripped, "%%[%-%d%.]*[sdifx]")) {
		found.push(spec as string);
	}
	return found;
}

function sameShape(source: string, translated: string): boolean {
	const a = placeholders(source);
	const b = placeholders(translated);
	if (a.size() !== b.size()) {
		return false;
	}
	for (let i = 0; i < a.size(); i++) {
		// the conversion letter must match; width/precision may differ between languages
		if (string.sub(a[i], -1) !== string.sub(b[i], -1)) {
			return false;
		}
	}
	return true;
}

/** Register a locale overlay (missing keys fall back to English). */
export function registerLocale(code: string, copy: CopyTable): void {
	overlays.set(string.lower(code), copy);
	if (string.lower(code) === activeCode) {
		active = copy;
	}
}

/** Switch the active locale; unknown codes fall back to English. Returns the code in use. */
export function setLocale(code: string): string {
	const lowered = string.lower(code);
	const overlay = overlays.get(lowered);
	activeCode = overlay !== undefined ? lowered : "en";
	active = overlay;
	return activeCode;
}

export function activeLocale(): string {
	return activeCode;
}

function format(copy: string, args: unknown[]): string {
	if (args.size() === 0) {
		return copy;
	}
	const [ok, text] = pcall(() => string.format(copy, ...(args as Array<string | number>)));
	if (ok) {
		return text as string;
	}
	const safe: string[] = [];
	for (let i = 0; i < args.size(); i++) {
		safe.push(tostring(args[i]));
	}
	const [ok2, text2] = pcall(() => string.format(string.gsub(copy, "%%[%-%d%.]*[difx]", "%%s")[0], ...safe));
	return ok2 ? (text2 as string) : copy;
}

/** Resolve a key against the active overlay, then the source table, and format it. */
export function translate(source: CopyTable, key: string, args: unknown[]): string {
	const english = source[key];
	if (english === undefined) {
		return key;
	}
	const translated = active?.[key];
	const copy = translated !== undefined && sameShape(english, translated) ? translated : english;
	return format(copy, args);
}

/** Lint a table against the source: key names, empties, whitespace and placeholder shape. */
export function lintTable(source: CopyTable, candidate: CopyTable, isSource = false): LintProblem[] {
	const problems: LintProblem[] = [];
	for (const [key, copy] of pairs(candidate)) {
		const name = key as string;
		const text = copy as string;
		if (string.match(name, KEY_PATTERN)[0] === undefined) {
			problems.push({ key: name, kind: "BadKeyName", detail: "keys look like Scope.Name" });
		}
		if (!isSource && source[name] === undefined) {
			problems.push({ key: name, kind: "UnknownKey", detail: "not in the English table" });
			continue;
		}
		if (text.size() === 0) {
			problems.push({ key: name, kind: "Empty", detail: "copy is empty" });
			continue;
		}
		if (string.match(text, "^%s")[0] !== undefined || string.match(text, "%s$")[0] !== undefined) {
			problems.push({ key: name, kind: "Whitespace", detail: "leading or trailing whitespace" });
		}
		if (!isSource && !sameShape(source[name], text)) {
			problems.push({
				key: name,
				kind: "Placeholders",
				detail: `expects ${placeholders(source[name]).join(" ")} got ${placeholders(text).join(" ")}`,
			});
		}
	}
	table.sort(problems, (a, b) => (a.key === b.key ? a.kind < b.kind : a.key < b.key));
	return problems;
}
