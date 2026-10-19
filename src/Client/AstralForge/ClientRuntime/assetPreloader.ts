import { seedAntilagFromBoot } from "../MotionKit/antilag";
import { FORGE_ASSET_MANIFEST } from "../ArtKit/ForgeAnvil2D";
import { GAME_ICON_ASSET, VECTOR_ICON_ATLAS } from "../ArtKit/Icon";
import { ClientLog } from "../CoreKit/log";

const ContentProvider = game.GetService("ContentProvider");
const Lighting = game.GetService("Lighting");
const MaterialService = game.GetService("MaterialService");
const Players = game.GetService("Players");
const ReplicatedFirst = game.GetService("ReplicatedFirst");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const SoundService = game.GetService("SoundService");
const StarterGui = game.GetService("StarterGui");
const StarterPack = game.GetService("StarterPack");
const StarterPlayer = game.GetService("StarterPlayer");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

interface LedgerApi {
	part(this: void, id: string, label: string, done: number, total: number, detail?: string): void;
}
const Ledger = (require(script.Parent!.Parent!.FindFirstChild("BootKit") as ModuleScript) as (name: string) => LedgerApi)(
	"BootLedger",
);

const PRELOAD_BATCH_SIZE = UserInputService.TouchEnabled ? 16 : 100;
// past this the game opens anyway; whatever is left keeps loading behind it
const PRELOAD_FAIL_OPEN_SECONDS = UserInputService.TouchEnabled ? 24 : 120;
const MAX_STABILITY_SWEEPS = UserInputService.TouchEnabled ? 2 : 4;
const REQUIRED_STABLE_SWEEPS = UserInputService.TouchEnabled ? 1 : 2;
const STABILITY_SWEEP_SECONDS = 0.25;
const FAILURE_RETRY_ROUNDS = 1;
const GOTHAM_FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json";
const STATIC_ASSET_MANIFEST = [
	VECTOR_ICON_ATLAS,
	GAME_ICON_ASSET,
	GOTHAM_FONT_FAMILY,
	"rbxasset://fonts/families/BuilderSans.json",
	"rbxasset://fonts/families/RobotoMono.json",
];

type Item = string | Instance;
type Station = "art" | "world";
interface Tag {
	station: Station;
	label?: string;
}
type Seen = Map<unknown, true>;

// item -> { station, label } for the run in progress (undefined outside a preload)
let tagSink: Map<Item, Tag> | undefined;
const GENERIC_NAMES = new Set([
	"Image",
	"Icon",
	"Asset",
	"ImageLabel",
	"ImageButton",
	"Decal",
	"Texture",
	"Art",
	"Id",
	"Thumbnail",
]);

function prettyName(text: unknown): string | undefined {
	if (!typeIs(text, "string") || text === "" || GENERIC_NAMES.has(text)) {
		return undefined;
	}
	const spaced = string.gsub(string.gsub(text, "(%l)(%u)", "%1 %2")[0], "_", " ")[0];
	return spaced;
}

function tag(item: Item, station: Station, label: string | undefined) {
	if (tagSink !== undefined && !tagSink.has(item)) {
		tagSink.set(item, { station, label });
	}
}

const CONTENT_CLASSES = new Set<string>([
	"ImageLabel",
	"ImageButton",
	"ImageHandleAdornment",
	"Decal",
	"Texture",
	"Animation",
	"AnimationClip",
	"MeshPart",
	"SpecialMesh",
	"UnionOperation",
	"SurfaceAppearance",
	"MaterialVariant",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"VideoFrame",
	"VideoPlayer",
	"Sky",
	"Shirt",
	"Pants",
	"ShirtGraphic",
	"CharacterMesh",
	"Accessory",
	"AccessoryDescription",
	"BodyPartDescription",
	"Tool",
	"HumanoidDescription",
	"WrapLayer",
	"WrapTarget",
]);

function carriesContent(instance: Instance): boolean {
	return CONTENT_CLASSES.has(instance.ClassName);
}

function addContentId(contentId: string, seen: Seen, target: Item[], station: Station | undefined, label: string | undefined) {
	if (contentId !== "") {
		tag(contentId, station ?? "art", label);
	}
	if (contentId === "" || seen.has(contentId)) {
		return undefined;
	}
	seen.set(contentId, true);
	target.push(contentId);
}

function collectStaticContent(seen: Seen, target: Item[]) {
	for (const contentId of STATIC_ASSET_MANIFEST) {
		addContentId(
			contentId,
			seen,
			target,
			"art",
			string.find(contentId, "fonts/", 1, true)[0] !== undefined
				? "Fonts"
				: contentId === GAME_ICON_ASSET
					? "Game icon"
					: "Icons",
		);
	}
	for (const contentId of FORGE_ASSET_MANIFEST as unknown as string[]) {
		addContentId(contentId, seen, target, "art", "Forge");
	}
	for (const player of Players.GetPlayers()) {
		const avatarSizes: Array<[string, number]> = [
			["AvatarHeadShot", 150],
			["AvatarBust", 420],
		];
		for (const [kind, size] of avatarSizes) {
			addContentId(
				`rbxthumb://type=${kind}&id=${player.UserId}&w=${size}&h=${size}`,
				seen,
				target,
				"art",
				`${player.DisplayName}'s avatar`,
			);
		}
	}
}

function isUiElement(instance: Instance): boolean {
	return carriesContent(instance);
}

function labelOf(instance: Instance): string | undefined {
	const own = prettyName(instance.Name);
	if (own !== undefined) {
		return own;
	}
	return instance.Parent ? prettyName(instance.Parent.Name) : undefined;
}

function collectMountedContent(seen: Seen, target: Item[], deepWorld = false) {
	const playerGui = Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
	const roots: Array<Instance | undefined> = [
		ReplicatedFirst,
		ReplicatedStorage,
		StarterGui,
		StarterPack,
		StarterPlayer,
		playerGui,
		SoundService,
		Lighting,
		MaterialService,
	];
	for (const root of roots) {
		if (root === undefined) {
			continue;
		}
		if (!seen.has(root)) {
			seen.set(root, true);
		}
		for (const instance of root.GetDescendants()) {
			if (seen.has(instance) || !isUiElement(instance)) {
				continue;
			}
			seen.set(instance, true);
			const label = labelOf(instance);
			if (instance.IsA("ImageLabel") || instance.IsA("ImageButton")) {
				addContentId(instance.Image, seen, target, "art", label);
			} else {
				tag(instance, "art", label);
				target.push(instance);
			}
		}
	}
	if (!deepWorld) {
		return undefined;
	}
	for (const instance of Workspace.GetDescendants()) {
		if (seen.has(instance) || !carriesContent(instance)) {
			continue;
		}
		seen.set(instance, true);
		tag(instance, "world", labelOf(instance));
		target.push(instance);
	}
}

let harvestVisits = 0;
function harvestContentIds(value: unknown, seen: Seen, target: Item[], depth = 0, label?: string) {
	if (depth > 8 || value === undefined) {
		return undefined;
	}
	harvestVisits += 1;
	if (harvestVisits % 4000 === 0) {
		RunService.Heartbeat.Wait();
	}
	if (typeIs(value, "string")) {
		if (string.find(value, "rbxasset")[0] !== undefined) {
			addContentId(value, seen, target, "art", label);
		}
		return undefined;
	}
	if (!typeIs(value, "table")) {
		return undefined;
	}
	const record = value as Record<string, unknown>;
	const here = typeIs(record.Name, "string")
		? record.Name
		: typeIs(record.DisplayName, "string")
			? record.DisplayName
			: label;
	for (const [key, item] of pairs(record)) {
		if (typeIs(item, "function")) {
			continue;
		}
		harvestContentIds(
			item,
			seen,
			target,
			depth + 1,
			typeIs(item, "table") && typeIs(key, "string") ? prettyName(key) ?? here : here,
		);
	}
}

function collectConfigContent(seen: Seen, target: Item[]) {
	const shared = ReplicatedStorage.FindFirstChild("AstralForge")?.FindFirstChild("Shared");
	const module = shared?.FindFirstChild("GameConfig");
	if (module === undefined || !module.IsA("ModuleScript")) {
		return undefined;
	}
	const [ok, config] = pcall(() => require(module));
	if (!ok) {
		return undefined;
	}
	for (const [key, value] of pairs(config as Record<string, unknown>)) {
		harvestContentIds(value, seen, target, 0, prettyName(tostring(key)));
	}
}

function sampleFrameRate(seconds = 0.55): number {
	const started = os.clock();
	let frames = 0;
	while (os.clock() - started < seconds) {
		RunService.Heartbeat.Wait();
		frames += 1;
	}
	const elapsed = math.max(0.08, os.clock() - started);
	return frames / elapsed;
}

function preloadMountedGame(
	onComplete: () => void,
	onProgress?: (loaded: number, total: number) => void,
	shellReady?: () => boolean,
): () => void {
	let cancelled = false;
	let bootMarked = false;
	let worker: thread | undefined;
	let watchdog: thread | undefined;
	const markBootReady = () => {
		if (bootMarked) {
			return undefined;
		}
		bootMarked = true;
		onComplete();
	};
	worker = task.defer(() => {
		const startedAt = os.clock();
		const seenInstances: Seen = new Map();
		const seenContentIds: Seen = new Map();
		const queue: Item[] = [];
		const tags = new Map<Item, Tag>();
		tagSink = tags;
		collectStaticContent(seenContentIds, queue);
		collectConfigContent(seenContentIds, queue);
		collectMountedContent(seenInstances, queue, true);
		tagSink = undefined;
		// per-station counts for the loading screen
		const totals = { art: 0, world: 0 };
		const done = { art: 0, world: 0 };
		const stationOf = (item: Item): Station => {
			const entry = tags.get(item);
			return entry !== undefined && entry.station === "world" ? "world" : "art";
		};
		const count = (items: Item[]) => {
			for (const item of items) {
				const station = stationOf(item);
				totals[station] += 1;
			}
			Ledger.part("art", "images", done.art, totals.art);
			Ledger.part("world", "world", done.world, totals.world);
		};
		count(queue);
		const warmupTotal = 0;
		onProgress?.(0, math.max(1, queue.size() + warmupTotal));
		const measured = sampleFrameRate(UserInputService.TouchEnabled ? 0.25 : 0.35);
		seedAntilagFromBoot(measured);
		let loaded = 0;
		let failedBatches = 0;
		let failedAssets = 0;
		let failedContentIds = new Set<string>();
		const drain = (items: Item[]) => {
			for (let offset = 0; offset < items.size() && !cancelled; offset += PRELOAD_BATCH_SIZE) {
				const batch: Item[] = [];
				for (let index = offset; index < math.min(items.size(), offset + PRELOAD_BATCH_SIZE); index++) {
					const item = items[index];
					if (item === undefined) {
						continue;
					}
					if (typeIs(item, "string") || item.Parent !== undefined) {
						batch.push(item);
					}
				}
				const [ok, preloadErr] = pcall(() =>
					ContentProvider.PreloadAsync(batch as Instance[], (contentId, status) => {
						if (status === Enum.AssetFetchStatus.Failure || status === Enum.AssetFetchStatus.TimedOut) {
							failedAssets += 1;
							if (contentId !== "") {
								failedContentIds.add(contentId);
							}
						} else if (status === Enum.AssetFetchStatus.Success && contentId !== "") {
							failedContentIds.delete(contentId);
						}
					}),
				);
				if (cancelled) {
					break;
				}
				if (!ok) {
					failedBatches += 1;
					ClientLog.warnEvery("preload-batch", 10, "Assets", tostring(preloadErr));
				}
				loaded += batch.size();
				const lastLabel: Partial<Record<Station, string>> = {};
				for (const item of batch) {
					const station = stationOf(item);
					done[station] += 1;
					const entry = tags.get(item);
					if (entry !== undefined && entry.label !== undefined) {
						lastLabel[station] = entry.label;
					}
				}
				Ledger.part("art", "images", done.art, totals.art, lastLabel.art);
				Ledger.part("world", "world", done.world, totals.world, lastLabel.world);
				onProgress?.(loaded, math.max(queue.size() + warmupTotal, loaded));
				RunService.Heartbeat.Wait();
			}
		};
		drain(queue);
		while (
			!cancelled &&
			shellReady !== undefined &&
			!shellReady() &&
			os.clock() - startedAt < PRELOAD_FAIL_OPEN_SECONDS
		) {
			RunService.Heartbeat.Wait();
		}
		let stableSweeps = 0;
		for (
			let sweep = 0;
			sweep < MAX_STABILITY_SWEEPS && stableSweeps < REQUIRED_STABLE_SWEEPS && !cancelled;
			sweep++
		) {
			task.wait(STABILITY_SWEEP_SECONDS);
			const late: Item[] = [];
			tagSink = tags;
			collectStaticContent(seenContentIds, late);
			collectMountedContent(seenInstances, late, sweep >= 2);
			tagSink = undefined;
			if (late.size() === 0) {
				stableSweeps += 1;
			} else {
				stableSweeps = 0;
				count(late);
				drain(late);
			}
		}
		for (let round = 0; round < FAILURE_RETRY_ROUNDS && failedContentIds.size() > 0 && !cancelled; round++) {
			const retry: Item[] = [];
			for (const contentId of failedContentIds) {
				retry.push(contentId);
			}
			failedContentIds = new Set();
			drain(retry);
		}
		if (cancelled) {
			return undefined;
		}
		if (failedBatches > 0 || failedAssets > 0) {
			ClientLog.warn("Assets", `${failedAssets} assets and ${failedBatches} batches will stream on demand`);
		}
		markBootReady();
		if (watchdog !== undefined) {
			task.cancel(watchdog);
			watchdog = undefined;
		}
		ClientLog.once(
			"asset-preload-ready",
			"assets",
			`${loaded} assets ready in ${string.format("%.2f", os.clock() - startedAt)}s`,
		);
		worker = undefined;
	});
	watchdog = task.delay(PRELOAD_FAIL_OPEN_SECONDS, () => {
		watchdog = undefined;
		if (!cancelled) {
			ClientLog.warn("Assets", "preload deadline reached; the game opens and the rest keeps loading behind it");
			markBootReady();
		}
	});
	return () => {
		cancelled = true;
		if (worker !== undefined) {
			task.cancel(worker);
		}
		if (watchdog !== undefined) {
			task.cancel(watchdog);
		}
		worker = undefined;
		watchdog = undefined;
	};
}

const MODULE_FRAME_BUDGET = UserInputService.TouchEnabled ? 0.006 : 0.008;

function collectModuleScripts(root: Instance | undefined, seen: Set<Instance>, list: ModuleScript[]) {
	if (root === undefined || seen.has(root)) {
		return undefined;
	}
	seen.add(root);
	if (root.IsA("ModuleScript")) {
		list.push(root);
	}
	for (const descendant of root.GetDescendants()) {
		if (descendant.IsA("ModuleScript") && !seen.has(descendant)) {
			seen.add(descendant);
			list.push(descendant);
		}
	}
}

function skipWarmModule(moduleScript: ModuleScript): boolean {
	const name = moduleScript.Name;
	if (name === "TestBootstrap" || string.sub(name, -5) === ".spec" || string.sub(name, -5) === ".test") {
		return true;
	}
	const fullName = moduleScript.GetFullName();
	if (string.find(fullName, "FlameworkRuntime", 1, true)[0] !== undefined) {
		return true;
	}
	if (string.find(fullName, "node_modules", 1, true)[0] !== undefined) {
		return true;
	}
	if (string.find(fullName, ".tests", 1, true)[0] !== undefined) {
		return true;
	}
	return false;
}

function warmClientModules(onProgress?: (loaded: number, total: number) => void): LuaTuple<[number, number]> {
	const seen = new Set<Instance>();
	const modules: ModuleScript[] = [];
	collectModuleScripts(ReplicatedStorage.FindFirstChild("AstralForge"), seen, modules);
	const playerScripts = Players.LocalPlayer && Players.LocalPlayer.FindFirstChild("PlayerScripts");
	if (playerScripts !== undefined) {
		collectModuleScripts(playerScripts.FindFirstChild("AstralForge"), seen, modules);
	}
	let total = modules.size();
	let loaded = 0;
	let lastReport = 0;
	if (onProgress !== undefined) {
		onProgress(0, math.max(total, 1));
	}
	const members: Array<{ suite: unknown; name: string }> = [];
	const queueMembers = (suite: Record<string, unknown>) => {
		const [ok, names] = pcall(() => suite.__members);
		if (!ok || !typeIs(names, "table")) {
			return undefined;
		}
		const list = names as string[];
		for (const name of list) {
			members.push({ suite, name });
		}
		total += list.size();
	};
	let index = 1;
	let memberIndex = 1;
	while (index <= modules.size() || memberIndex <= members.size()) {
		const sliceStarted = os.clock();
		while (index <= modules.size() && os.clock() - sliceStarted < MODULE_FRAME_BUDGET) {
			const moduleScript = modules[index - 1];
			index += 1;
			if (moduleScript.Parent !== undefined && !skipWarmModule(moduleScript)) {
				Ledger.part("code", "modules", loaded, total, prettyName(moduleScript.Name));
				const [ok, moduleResult] = pcall(require, moduleScript);
				if (ok && typeIs(moduleResult, "table")) {
					queueMembers(moduleResult as Record<string, unknown>);
				}
			}
			loaded += 1;
		}
		while (index > modules.size() && memberIndex <= members.size() && os.clock() - sliceStarted < MODULE_FRAME_BUDGET) {
			const entry = members[memberIndex - 1];
			memberIndex += 1;
			pcall(entry.suite as (name: string) => unknown, entry.name);
			loaded += 1;
			Ledger.part("code", "modules", loaded, total, prettyName(entry.name));
		}
		const now = os.clock();
		if (onProgress !== undefined && (loaded >= total || now - lastReport >= 0.12)) {
			lastReport = now;
			onProgress(loaded, total);
		}
		RunService.Heartbeat.Wait();
	}
	ClientLog.once("module-warm-ready", "modules", `${modules.size()} modules and ${members.size()} suite members warm`);
	return $tuple(loaded, total);
}

export { preloadMountedGame, warmClientModules };
