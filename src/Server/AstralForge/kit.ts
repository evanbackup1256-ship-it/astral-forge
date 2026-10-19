// Server-side copy of Client/AstralForge/kit.ts: server modules cannot reach the client tree.
// A kit is a folder of member modules reachable by name: Kit("theme") or Kit.theme.
// Members load lazily on first use, so kits can reference each other without a require
// cycle at startup. Converted code imports members directly; this loader keeps older
// Luau callers (require(script.Parent.CoreKit)("theme")) working unchanged.

export type Kit = ((name: string) => any) & { readonly [name: string]: any; readonly __members: ReadonlyArray<string> };

export function makeKit(root: Instance): Kit {
	const label = root.Name;
	const cache = new Map<string, { value: unknown }>();
	const loading = new Set<string>();

	const load = (name: string): unknown => {
		const hit = cache.get(name);
		if (hit) {
			return hit.value;
		}
		const member = root.FindFirstChild(name);
		if (member === undefined || !member.IsA("ModuleScript")) {
			error(`${label}: unknown module ${tostring(name)}`, 3);
		}
		if (loading.has(name)) {
			error(`${label}: cyclic require of member ${name}`, 3);
		}
		loading.add(name);
		const [ok, value] = pcall(require, member);
		loading.delete(name);
		if (!ok) {
			error(value, 0);
		}
		cache.set(name, { value });
		return value;
	};

	const members = root
		.GetChildren()
		.filter((child) => child.IsA("ModuleScript"))
		.map((child) => child.Name);
	members.sort();
	table.freeze(members);

	return setmetatable({}, {
		__call: (_self: unknown, name: string) => load(name),
		__index: (_self: unknown, name: string) => (name === "__members" ? members : load(name)),
	} as LuaMetatable<object>) as unknown as Kit;
}
