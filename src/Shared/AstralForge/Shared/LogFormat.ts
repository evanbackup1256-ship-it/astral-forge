// Log line formatting shared by the server ModuleLog and the client ClientLog.
//
//   12.345  warn   security      Studio bypass audit                 allowStudioAdmins=true isStudio=true
//   ^clock  ^level ^scope (12)   ^message (padded to 34 when fields follow)  ^fields, sorted by key
//
// Field values: integers as-is, other numbers to 4 significant digits, strings quoted only when
// they contain spaces or quotes, Instances by name (players as Name#UserId), arrays as [a, b, c],
// dictionaries as {k=v} one level deep. Long values are cut so one bad field can't flood the line.

export type LogParams = Record<string, unknown> | undefined;

const LEVEL_COLUMN: Record<string, string> = {
	INFO: "info ",
	WARN: "warn ",
	ERROR: "error",
	FATAL: "fatal",
	NETWORK: "net  ",
	DEBUG: "debug",
};
const SCOPE_WIDTH = 12;
const MESSAGE_WIDTH = 34;
const MAX_VALUE = 80;
const MAX_ITEMS = 6;

function oneLine(text: string): string {
	const [flat] = string.gsub(text, "[\r\n\t]+", " ");
	return flat;
}

function cut(text: string, limit: number): string {
	if (text.size() <= limit) {
		return text;
	}
	return string.sub(text, 1, limit - 3) + "...";
}

export function formatNumber(value: number): string {
	if (value !== value) {
		return "nan";
	}
	if (value === math.huge || value === -math.huge) {
		return value > 0 ? "inf" : "-inf";
	}
	if (value === math.floor(value) && math.abs(value) < 1e15) {
		return string.format("%d", value);
	}
	if (math.abs(value) >= 1e15 || math.abs(value) < 1e-3) {
		return string.format("%.3e", value);
	}
	// 4 significant digits, trailing zeros dropped: 0.1235, 12.35, 1235
	let text = string.format("%.4g", value);
	if (text.find("[eE]")[0] === undefined && text.find("%.")[0] !== undefined) {
		[text] = string.gsub(text, "0+$", "");
		[text] = string.gsub(text, "%.$", "");
	}
	return text;
}

function formatString(text: string): string {
	const flat = cut(oneLine(text), MAX_VALUE);
	if (flat === "" || flat.find('[%s="]')[0] !== undefined) {
		const [escaped] = string.gsub(flat, '"', "'");
		return '"' + escaped + '"';
	}
	return flat;
}

function isArray(value: object): boolean {
	let count = 0;
	for (const [key] of pairs(value)) {
		count += 1;
		if (!typeIs(key, "number")) {
			return false;
		}
	}
	return count > 0 && count === (value as unknown[]).size();
}

function sortedKeys(value: object): string[] {
	const keys: string[] = [];
	for (const [key] of pairs(value)) {
		keys.push(tostring(key));
	}
	table.sort(keys, (a, b) => a < b);
	return keys;
}

function lookup(value: object, key: string): unknown {
	const bag = value as Record<string, unknown>;
	const direct = bag[key];
	if (direct !== undefined) {
		return direct;
	}
	const numeric = tonumber(key);
	return numeric !== undefined ? (value as Record<number, unknown>)[numeric] : undefined;
}

export function formatValue(value: unknown, depth = 0): string {
	if (value === undefined) {
		return "nil";
	}
	if (typeIs(value, "number")) {
		return formatNumber(value);
	}
	if (typeIs(value, "boolean")) {
		return tostring(value);
	}
	if (typeIs(value, "string")) {
		return formatString(value);
	}
	if (typeIs(value, "Instance")) {
		if (value.IsA("Player")) {
			return value.Name + "#" + tostring(value.UserId);
		}
		return formatString(value.Name);
	}
	if (typeIs(value, "Vector3")) {
		return string.format("(%s,%s,%s)", formatNumber(value.X), formatNumber(value.Y), formatNumber(value.Z));
	}
	if (typeIs(value, "table")) {
		const keys = sortedKeys(value);
		if (keys.size() === 0) {
			return "{}";
		}
		if (depth >= 1) {
			return isArray(value) ? `[${keys.size()} items]` : `{${keys.size()} keys}`;
		}
		const parts: string[] = [];
		const array = isArray(value);
		if (array) {
			const list = value as unknown[];
			for (let i = 0; i < math.min(list.size(), MAX_ITEMS); i++) {
				parts.push(formatValue(list[i], depth + 1));
			}
		} else {
			for (let i = 0; i < math.min(keys.size(), MAX_ITEMS); i++) {
				parts.push(keys[i] + "=" + formatValue(lookup(value, keys[i]), depth + 1));
			}
		}
		const extra = keys.size() - parts.size();
		const more = extra > 0 ? ` +${extra}` : "";
		const body = cut(parts.join(array ? ", " : " "), MAX_VALUE);
		return array ? `[${body}${more}]` : `{${body}${more}}`;
	}
	return formatString(tostring(value));
}

export function formatField(key: string, value: unknown): string {
	let name = oneLine(key);
	name = string.lower(string.sub(name, 1, 1)) + string.sub(name, 2);
	// ElapsedMs=12 prints as elapsed=12ms
	if (typeIs(value, "number") && name.size() > 2 && string.sub(name, -2) === "Ms") {
		return string.sub(name, 1, -3) + "=" + formatNumber(value) + "ms";
	}
	return name + "=" + formatValue(value);
}

export function formatFields(params: LogParams): string {
	if (params === undefined || !typeIs(params, "table")) {
		return "";
	}
	const pieces: string[] = [];
	for (const key of sortedKeys(params)) {
		pieces.push(formatField(key, lookup(params, key)));
	}
	return pieces.join(" ");
}

export function formatLine(clock: number, severity: string, scope: unknown, message: unknown, params?: LogParams): string {
	let scopeText = string.lower(oneLine(tostring(scope)));
	if (scopeText.size() < SCOPE_WIDTH) {
		scopeText += string.rep(" ", SCOPE_WIDTH - scopeText.size());
	}
	let messageText = oneLine(tostring(message));
	const fields = formatFields(params);
	if (fields !== "" && messageText.size() < MESSAGE_WIDTH) {
		messageText += string.rep(" ", MESSAGE_WIDTH - messageText.size());
	}
	return string.format(
		"%8.3f  %s  %s  %s%s",
		clock,
		LEVEL_COLUMN[severity] ?? string.lower(severity),
		scopeText,
		messageText,
		fields !== "" ? "  " + fields : "",
	);
}
