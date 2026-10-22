// Pure admin policy: role permissions and dry-run diffs. No Roblox services so it runs under Lune tests.
import { T } from "../../../Shared/AstralForge/Shared/Locale";

// Permission matrix. Read a row as "this category or command is open to these roles".
// Owner and Studio Developer bypass the matrix entirely. Order of checks for everyone else:
//   1. COMMAND_DENY  - a listed role can never run that command, even if its category is open;
//   2. COMMAND_ALLOW - a listed role can run that one command outside its categories;
//   3. CATEGORY_ACCESS - a listed role can run every command in that category.
// Developer keeps everything it had: every gameplay and live-ops category, minus the three
// account-wide actions that stay with the Owner.

type Role = "Owner" | "Studio Developer" | "Developer" | "Moderator" | "Support";

const FULL_ACCESS: Record<string, true> = { Owner: true, "Studio Developer": true };

const CATEGORY_ACCESS: Record<string, Role[]> = {
	Economy: ["Developer"],
	Progress: ["Developer"],
	Items: ["Developer"],
	Resets: ["Developer"],
	Troll: ["Developer"],
	LiveOps: ["Developer"],
	Moderation: ["Developer", "Moderator"],
};

const COMMAND_ALLOW: Record<string, Role[]> = {
	InspectMarket: ["Moderator", "Support"],
	ResetTutorial: ["Moderator", "Support"],
	ShowUpdates: ["Moderator", "Support"],
	ResetSettings: ["Support"],
	ResetWheelCooldown: ["Support"],
	ResetDailyClaim: ["Support"],
	CancelMarketRequest: ["Support"],
	Kick: ["Support"],
};

const COMMAND_DENY: Record<string, Role[]> = {
	GlobalBan: ["Developer", "Moderator"],
	Unban: ["Developer"],
	GrantEverything: ["Developer"],
};

const listed = (grid: Record<string, Role[]>, key: string, role: string): boolean => {
	const roles = grid[key];
	return roles !== undefined && roles.includes(role as Role);
};

// Per-role view of the matrix, kept for tools and tests that read AdminPolicy.ROLES.
interface Permission {
	All?: boolean;
	Categories?: Record<string, boolean>;
	Commands?: Record<string, boolean>;
	Deny?: Record<string, boolean>;
}

function buildRoles(): Record<string, Permission> {
	const roles: Record<string, Permission> = {};
	for (const [role] of pairs(FULL_ACCESS)) {
		roles[role] = { All: true };
	}
	const add = (role: string, field: "Categories" | "Commands" | "Deny", key: string) => {
		const entry = roles[role] ?? {};
		roles[role] = entry;
		const bucket = entry[field] ?? {};
		entry[field] = bucket;
		bucket[key] = true;
	};
	for (const [category, list] of pairs(CATEGORY_ACCESS)) for (const role of list) add(role, "Categories", category);
	for (const [command, list] of pairs(COMMAND_ALLOW)) for (const role of list) add(role, "Commands", command);
	for (const [command, list] of pairs(COMMAND_DENY)) for (const role of list) add(role, "Deny", command);
	return roles;
}

const ROLES = table.freeze(buildRoles());

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
			return $tuple(false, T("AdminPolicy.AdministrativeAccessDenied"));
		}
		if (FULL_ACCESS[resolved]) {
			return $tuple(true, undefined);
		}
		const refused = `${resolved} role can't run ${command}.`;
		if (listed(COMMAND_DENY, command, resolved)) {
			return $tuple(false, refused);
		}
		if (listed(COMMAND_ALLOW, command, resolved)) {
			return $tuple(true, undefined);
		}
		const category = definition !== undefined && typeIs(definition.Category, "string") ? definition.Category : "";
		if (listed(CATEGORY_ACCESS, category, resolved)) {
			return $tuple(true, undefined);
		}
		return $tuple(false, refused);
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
				lines.push(`${path}: ${describe(a)} to ${describe(b)}`);
			}
		};
		walk("", before, after, 0);
		return $tuple(lines, total);
	},
};

export = table.freeze(AdminPolicy);
