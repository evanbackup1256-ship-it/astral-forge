// PagesStory members are the newest pre-migration views, loaded on demand.
const __defs: Record<string, () => unknown> = {};

function loadPort(name: string): unknown {
	return require(script.Parent!.WaitForChild("ports")!.WaitForChild(name) as ModuleScript);
}

__defs["StoryView"] = () => loadPort("StoryView");
__defs["EchoForgeView"] = () => loadPort("EchoForgeView");
__defs["InventoryView"] = () => loadPort("InventoryView");

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

function __load(name: string): unknown {
	const def = __defs[name];
	if (def === undefined) {
		error(`PagesStory: unknown module ${tostring(name)}`, 2);
	}
	return def();
}

type PagesStoryCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const PagesStory = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => {
			return __load(name);
		},
		__index: (_self: unknown, name: string): unknown => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as LuaMetatable<object>,
) as unknown as PagesStoryCallable;

export = PagesStory;
