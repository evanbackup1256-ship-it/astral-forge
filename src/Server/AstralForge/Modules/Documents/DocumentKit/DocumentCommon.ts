import type DocumentServiceModule = require("../DocumentService");
import type Types = require("../DocumentService/Types");

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const ServerScriptService = game.GetService("ServerScriptService");

type DocumentServiceShape = typeof DocumentServiceModule;

// The kit member lives one level deeper than the old bundled DocumentKit module did,
// so the sibling lookup starts from the Documents folder (the kit's parent).
function requireDocumentService(): DocumentServiceShape {
	const documentsRoot = script.Parent!.Parent!;
	let sibling = documentsRoot.FindFirstChild("DocumentService");
	if (sibling) {
		return require(sibling as ModuleScript) as DocumentServiceShape;
	}

	sibling = documentsRoot.WaitForChild("DocumentService", 5);
	if (sibling) {
		return require(sibling as ModuleScript) as DocumentServiceShape;
	}

	const candidates: Instance[] = [];
	let node: Instance | undefined = script;
	while (node) {
		candidates.push(node.FindFirstChild("Packages")!);
		node = node.Parent;
	}
	const serverAstral = ServerScriptService.FindFirstChild("AstralForge");
	if (serverAstral) {
		candidates.push(serverAstral.FindFirstChild("Packages")!);
	}
	candidates.push(ReplicatedStorage.FindFirstChild("Packages")!);

	for (const [, packages] of pairs(candidates)) {
		if (packages) {
			const module = packages.FindFirstChild("DocumentService");
			if (module) {
				return require(module as ModuleScript) as DocumentServiceShape;
			}
		}
	}

	error(
		"[DocumentCommon] DocumentService module missing. Expected sibling " +
			"ServerScriptService.AstralForge.Modules.Documents.DocumentService " +
			"(vendored under src/server/Modules/Documents/DocumentService). " +
			"Reconnect Rojo serving default.project.json.",
		0,
	);
}

const DocumentService = requireDocumentService();

type StoreProps = Types.StoreProps;

function deepCopy(value: unknown): unknown {
	if (!typeIs(value, "table")) {
		return value;
	}
	const copy = new Map<unknown, unknown>();
	for (const [key, child] of pairs(value)) {
		copy.set(deepCopy(key), deepCopy(child));
	}
	return copy;
}

function isOk(result: unknown): boolean {
	return typeIs(result, "table") && (result as { success?: unknown }).success === true;
}

function reason(result: unknown): string | undefined {
	if (typeIs(result, "table") && (result as { success?: unknown }).success === false) {
		return tostring((result as { reason?: unknown }).reason);
	}
	return undefined;
}

function okData(result: unknown): unknown {
	if (isOk(result)) {
		return (result as { data?: unknown }).data;
	}
	return undefined;
}

function baseStoreProps(props: StoreProps, lockSessions: boolean) {
	return {
		dataStore: props.dataStore,
		check: props.check,
		default: props.default,
		migrations: props.migrations ?? [],
		lockSessions: lockSessions,

		bindToClose: props.bindToClose === undefined ? false : props.bindToClose,
	};
}

function permissiveTableCheck(value: unknown): LuaTuple<[boolean, unknown]> {
	if (!typeIs(value, "table")) {
		return $tuple(false, value);
	}
	return $tuple(true, value);
}

const DocumentCommon = {
	DocumentService,
	DocumentStore: DocumentService.DocumentStore,
	Document: DocumentService.Document,
	SaveUtil: DocumentService.SaveUtil,
	deepCopy,
	isOk,
	reason,
	okData,
	baseStoreProps,
	permissiveTableCheck,
};

export = DocumentCommon;
