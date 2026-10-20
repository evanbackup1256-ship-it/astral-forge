// SharedData: shared config and pure models, one ModuleScript per member, reachable by name:
// SharedData("ShopCatalog") or SharedData.ShopCatalog. Members load lazily on first use, exactly
// like the old bundled kit, so existing Luau callers keep working unchanged.

type Dict = Record<string, unknown>;

const cache = new Map<string, { value: unknown }>();
const loading = new Set<string>();

function load(name: string): unknown {
	const hit = cache.get(name);
	if (hit) {
		return hit.value;
	}
	const member = script.FindFirstChild(name);
	if (member === undefined || !member.IsA("ModuleScript")) {
		error("SharedData: unknown module " + tostring(name), 3);
	}
	if (loading.has(name)) {
		error("SharedData: cyclic require of member " + name, 3);
	}
	loading.add(name);
	const [ok, value] = pcall(require, member);
	loading.delete(name);
	if (!ok) {
		error(value, 0);
	}
	cache.set(name, { value });
	return value;
}

function validateMonetizationIds(): Record<string, string[]> {
	const config = load("MonetizationConfig") as {
		DevProducts: { ProductId: number; Key: string }[];
		GamePasses: { PassId: number; Key: string }[];
	};
	const missing = {
		DevProducts: [] as string[],
		GamePasses: [] as string[],
	};
	// Keep runtime purchase gates unchanged while making every placeholder visible at boot.
	for (const entry of config.DevProducts) {
		if (entry.ProductId <= 0) {
			missing.DevProducts.push(entry.Key);
		}
	}
	for (const entry of config.GamePasses) {
		if (entry.PassId <= 0) {
			missing.GamePasses.push(entry.Key);
		}
	}
	return missing;
}

const members = script
	.GetChildren()
	.filter((child) => child.IsA("ModuleScript"))
	.map((child) => child.Name);
members.sort();
table.freeze(members);

export = setmetatable({} as Dict, {
	__call: (_self: unknown, name: string) => load(name),
	__index: (_self: unknown, name: string) => {
		if (name === "__members") {
			return members;
		} else if (name === "ValidateMonetizationIds") {
			return validateMonetizationIds;
		}
		return load(name);
	},
} as LuaMetatable<Dict>);
