// Pure admin policy: role permissions and dry-run diffs. No Roblox services so it runs under Lune tests.

interface Permission {
	Categories?: Record<string, boolean>;
	Commands?: Record<string, boolean>;
	Deny?: Record<string, boolean>;
	All?: boolean;
}

const ALL = "*";

const ROLES: Record<string, Permission> = table.freeze({
	Owner: { All: true },
	"Studio Developer": { All: true },
	Developer: {
		Categories: { Economy: true, Progress: true, Items: true, Resets: true, Troll: true, Moderation: true },
		Deny: { GlobalBan: true, Unban: true, GrantEverything: true },
	},
	Moderator: {
		Categories: { Moderation: true },
		Commands: { InspectMarket: true, ResetTutorial: true, ShowUpdates: true },
		Deny: { GlobalBan: true },
	},
	Support: {
		Commands: {
			InspectMarket: true,
			ResetTutorial: true,
			ResetSettings: true,
			ShowUpdates: true,
			ResetWheelCooldown: true,
			ResetDailyClaim: true,
			CancelMarketRequest: true,
			Kick: true,
		},
	},
});

function describe(value: unknown): string {
	if (value === undefined) {
		return "none";
	} else if (typeIs(value, "number")) {
		if (value !== value) {
			return "NaN";
		}
		if (math.abs(value) >= 1e15) {
			return string.format("%.3e", value);
		}
		if (value === math.floor(value)) {
			return string.format("%d", value);
		}
		return string.format("%.3f", value);
	} else if (typeIs(value, "string")) {
		return value.size() > 24 ? `${string.sub(value, 1, 23)}…` : value;
	} else if (typeIs(value, "table")) {
		let count = 0;
		for (const _ of pairs(value)) {
			count += 1;
		}
		return `${count} entries`;
	}
	return tostring(value);
}

function sortedKeys(left: unknown, right: unknown): defined[] {
	const keys: defined[] = [];
	const seen = new Set<unknown>();
	for (const source of [left, right]) {
		if (typeIs(source, "table")) {
			for (const [key] of pairs(source)) {
				if (!seen.has(key)) {
					seen.add(key);
					keys.push(key as defined);
				}
			}
		}
	}
	keys.sort((a, b) => tostring(a) < tostring(b));
	return keys;
}

const AdminPolicy = {
	ROLES,

	Resolve(this: void, role?: string): string | undefined {
		if (!typeIs(role, "string") || role === "") {
			return undefined;
		}
		if (AdminPolicy.ROLES[role] !== undefined) {
			return role;
		}
		// Unrecognised custom labels get the narrowest staff tier, never full access.
		return "Support";
	},

	Allows(
		this: void,
		role: string | undefined,
		command: string,
		definition?: Record<string, unknown>,
	): LuaTuple<[boolean, string | undefined]> {
		const resolved = AdminPolicy.Resolve(role);
		if (resolved === undefined) {
			return $tuple(false, "Administrative access denied.");
		}
		const policy = AdminPolicy.ROLES[resolved] as Permission & {
			Categories?: Record<string, boolean>;
			Commands?: Record<string, boolean>;
			Deny?: Record<string, boolean>;
		};
		if (policy.All === true) {
			return $tuple(true, undefined);
		}
		if (policy.Deny && policy.Deny[command]) {
			return $tuple(false, `${resolved} role can't run ${command}.`);
		}
		if (policy.Commands && policy.Commands[command]) {
			return $tuple(true, undefined);
		}
		const category = (definition && definition.Category) || "";
		if (policy.Categories && (policy.Categories[category as string] || policy.Categories[ALL])) {
			return $tuple(true, undefined);
		}
		return $tuple(false, `${resolved} role can't run ${command}.`);
	},

	DeepCopy<T>(this: void, value: T, seen?: Map<unknown, unknown>): T {
		if (!typeIs(value, "table")) {
			return value;
		}
		const visited = seen ?? new Map<unknown, unknown>();
		if (visited.has(value)) {
			return visited.get(value) as T;
		}
		const copy: Record<string, unknown> = {};
		visited.set(value, copy);
		for (const [key, child] of pairs(value)) {
			copy[AdminPolicy.DeepCopy(key, visited) as string] = AdminPolicy.DeepCopy(child, visited);
		}
		return copy as T;
	},

	// Returns readable "Path: before → after" lines plus the total number of changed leaves.
	Diff(this: void, before: unknown, after: unknown, limit?: number): LuaTuple<[string[], number]> {
		const maxLines = limit ?? 12;
		const lines: string[] = [];
		let total = 0;
		const walk = (path: string, a: unknown, b: unknown, depth: number): void => {
			if (typeIs(a, "table") && typeIs(b, "table") && depth < 6) {
				const aTable = a as Record<string, unknown>;
				const bTable = b as Record<string, unknown>;
				for (const key of sortedKeys(a, b)) {
					walk(
						path === "" ? tostring(key) : `${path}.${tostring(key)}`,
						aTable[key as string],
						bTable[key as string],
						depth + 1,
					);
				}
				return;
			}
			if (a === b) {
				return;
			}
			if (typeIs(a, "number") && typeIs(b, "number") && a !== a && b !== b) {
				return;
			}
			total += 1;
			if (lines.size() < maxLines) {
				lines.push(`${path}: ${describe(a)} → ${describe(b)}`);
			}
		};
		walk("", before, after, 0);
		return $tuple(lines, total);
	},
};

export = table.freeze(AdminPolicy);
