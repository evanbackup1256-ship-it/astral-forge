// Generic shape and size limits for every remote payload, checked before the per-action
// validators. A request that fails here never reaches a handler.

export interface ShapeLimits {
	MaxDepth: number;
	MaxNodes: number;
	MaxKeysPerTable: number;
	MaxStringLength: number;
	MaxTotalString: number;
}

export const DEFAULT_LIMITS: ShapeLimits = {
	MaxDepth: 6,
	MaxNodes: 400,
	MaxKeysPerTable: 128,
	MaxStringLength: 1024,
	MaxTotalString: 8192,
};

interface Walk {
	nodes: number;
	chars: number;
}

function check(value: unknown, depth: number, limits: ShapeLimits, walk: Walk, seen: Set<object>): string | undefined {
	walk.nodes += 1;
	if (walk.nodes > limits.MaxNodes) {
		return "payload has too many values";
	}
	if (value === undefined || typeIs(value, "boolean")) {
		return undefined;
	}
	if (typeIs(value, "number")) {
		if (value !== value || value === math.huge || value === -math.huge) {
			return "payload has a non-finite number";
		}
		return undefined;
	}
	if (typeIs(value, "string")) {
		if (value.size() > limits.MaxStringLength) {
			return "payload string is too long";
		}
		walk.chars += value.size();
		if (walk.chars > limits.MaxTotalString) {
			return "payload text is too large";
		}
		return undefined;
	}
	if (typeIs(value, "table")) {
		if (depth >= limits.MaxDepth) {
			return "payload is nested too deeply";
		}
		if (seen.has(value)) {
			return "payload has a cycle";
		}
		seen.add(value);
		let keys = 0;
		for (const [key, child] of pairs(value)) {
			keys += 1;
			if (keys > limits.MaxKeysPerTable) {
				return "payload table has too many keys";
			}
			if (typeIs(key, "string")) {
				if (key.size() > 64) {
					return "payload key is too long";
				}
			} else if (!typeIs(key, "number") || key !== key || key === math.huge || key === -math.huge) {
				return "payload has an invalid key";
			}
			const problem = check(child, depth + 1, limits, walk, seen);
			if (problem !== undefined) {
				return problem;
			}
		}
		return undefined;
	}
	// Instances, functions, vectors and anything else have no business in an action payload
	return "payload has an unsupported " + typeOf(value) + " value";
}

/** Returns undefined when the payload fits, otherwise a short reason. */
export function Validate(payload: unknown, limits: ShapeLimits = DEFAULT_LIMITS): string | undefined {
	return check(payload, 0, limits, { nodes: 0, chars: 0 }, new Set());
}

function writePrint(value: unknown, out: string[], depth: number): void {
	if (out.size() > 256) {
		return;
	}
	if (typeIs(value, "table")) {
		if (depth > 4) {
			out.push("{..}");
			return;
		}
		const keys: string[] = [];
		const byText: Record<string, unknown> = {};
		for (const [key, child] of pairs(value)) {
			const text = typeOf(key) + ":" + tostring(key);
			keys.push(text);
			byText[text] = child;
		}
		table.sort(keys);
		out.push("{");
		for (const key of keys) {
			out.push(key, "=");
			writePrint(byText[key], out, depth + 1);
			out.push(",");
		}
		out.push("}");
		return;
	}
	out.push(typeOf(value) + ":" + tostring(value));
}

/** Order-independent text fingerprint of a payload, used to spot a reused TxnId on a different request. */
export function Fingerprint(payload: unknown, ignore?: Record<string, boolean>): string {
	if (ignore !== undefined && typeIs(payload, "table")) {
		const copy: Record<string, unknown> = {};
		for (const [key, child] of pairs(payload)) {
			if (!(typeIs(key, "string") && ignore[key] === true)) {
				copy[key as string] = child;
			}
		}
		payload = copy;
	}
	const out: string[] = [];
	writePrint(payload, out, 0);
	return out.join("");
}
