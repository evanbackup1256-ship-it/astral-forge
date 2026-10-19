// Purpose: select native persistence or an explicitly allowed unpublished Studio preview.
// Owner: persistence. Dependencies: ServerConfig, PreviewStores, PreviewDataStores.
// Last-reviewed: 2026-10-06.

const DataStoreService = game.GetService("DataStoreService");
const RunService = game.GetService("RunService");
const ServerConfig = require(script.Parent!.Parent!.FindFirstChild("ServerConfig")! as ModuleScript) as {
	AllowStudioMemoryFallback?: boolean;
	[key: string]: unknown;
};
const PreviewStores = require(script.Parent!.FindFirstChild("PreviewStores")! as ModuleScript) as {
	enabled(this: void, isStudio: boolean, gameId: number, allowed: boolean): boolean;
	ordered(this: void, name: string, preview: boolean, factory: (name: string) => OrderedDataStore): unknown;
	Store: unknown;
};
const PreviewDataStores = require(script.Parent!.FindFirstChild("PreviewDataStores")! as ModuleScript) as {
	data(this: void, name: string, preview: boolean, factory: (name: string) => GlobalDataStore): unknown;
	NativeOrPreview: unknown;
};

const preview = PreviewStores.enabled(
	RunService.IsStudio(),
	game.GameId,
	ServerConfig.AllowStudioMemoryFallback === true,
);

function isPreview(): boolean {
	return preview;
}

function data(name: string): unknown {
	return PreviewDataStores.data(name, preview, (storeName: string) => {
		return DataStoreService.GetDataStore(storeName);
	});
}

function ordered(name: string): unknown {
	return PreviewStores.ordered(name, preview, (storeName: string) => {
		return DataStoreService.GetOrderedDataStore(storeName);
	});
}

export = table.freeze({ isPreview, data, ordered });
