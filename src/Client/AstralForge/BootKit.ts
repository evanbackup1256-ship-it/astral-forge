const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`BootKit: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`BootKit: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

type LuaKit = (name: string) => unknown;
type LooseComponent = (props: Record<string, unknown>) => unknown;
type LooseCreate = (type: unknown, props?: { [key: string]: unknown }, ...children: unknown[]) => unknown;

const AstralForge = script.Parent!;

function kitMember(kit: string, member: string): unknown {
	return (require(AstralForge.FindFirstChild(kit)! as ModuleScript) as LuaKit)(member);
}

function loadReact(): typeof import("@rbxts/react") {
	return require(
		game
			.GetService("ReplicatedStorage")
			.WaitForChild("rbxts_include")
			.WaitForChild("node_modules")
			.WaitForChild("@rbxts")
			.WaitForChild("react") as ModuleScript,
	) as typeof import("@rbxts/react");
}

interface AudioPlayer {
	play(cue: string, speedMult?: number): void;
	setScene(scene: string): void;
	isWarm(): boolean;
	whenWarm(callback: () => void): void;
	[key: string]: unknown;
}

__defs["BootLedger"] = () => {
	// What the loading screen reads. Every loader reports here by station with real counts and the
	// name of what it is on right now; the boot screen polls it each frame (no React traffic).
	const STATIONS = [
		{ key: "server", label: "SERVER", verb: "Connecting to the server" },
		{ key: "save", label: "SAVE", verb: "Loading your save" },
		{ key: "art", label: "ART", verb: "Loading art" },
		{ key: "sound", label: "SOUND", verb: "Loading sounds" },
		{ key: "world", label: "WORLD", verb: "Loading the world" },
		{ key: "code", label: "CODE", verb: "Starting the game" },
		{ key: "menus", label: "MENUS", verb: "Setting up menus" },
	];
	const MENU_NAMES: Record<string, string> = {
		shell: "Main menu",
		mail: "Mailbox",
		research: "Research",
		forge: "Forge",
		trade: "Trading",
		boosts: "Boosts",
		settings: "Settings",
		mobile: "Touch controls",
	};
	const MARKS: Record<string, [string, string, string | undefined]> = {
		bridge: ["server", "bridge", "Handshake"],
		remotes: ["server", "remotes", "Remotes"],
		state: ["save", "state", "Save loaded"],
		audio: ["sound", "bank", undefined],
		fonts: ["art", "fonts", "Fonts"],
		modules: ["code", "modules", undefined],
	};
	interface Part {
		loaded: number;
		total: number;
	}
	const parts: Record<string, Record<string, Part>> = {};
	const items: Record<string, string> = {};
	const itemAt: Record<string, number> = {};
	let version = 0;
	let cache: unknown;
	let cacheVersion = -1;

	function stamp(station: string, item: string | undefined) {
		if (typeIs(item, "string") && item !== "") {
			items[station] = item;
			itemAt[station] = os.clock();
		}
	}
	function part(station: string, sub: string, loaded?: number, total?: number, item?: string) {
		let list = parts[station];
		if (list === undefined) {
			list = {};
			parts[station] = list;
		}
		let entry = list[sub];
		if (entry === undefined) {
			entry = { loaded: 0, total: 1 };
			list[sub] = entry;
		}
		const nextTotal = typeIs(total, "number") ? total : entry.total;
		if (nextTotal <= 0) {
			// nothing of this kind to load counts as done
			entry.loaded = 1;
			entry.total = 1;
		} else {
			entry.total = nextTotal;
			entry.loaded = math.clamp(typeIs(loaded, "number") ? loaded : entry.loaded, 0, nextTotal);
		}
		stamp(station, item);
		version += 1;
	}
	function finish(station: string, sub: string, item?: string) {
		const entry = parts[station] !== undefined ? parts[station][sub] : undefined;
		if (entry === undefined) {
			part(station, sub, 1, 1, item);
			return;
		}
		entry.loaded = entry.total;
		stamp(station, item);
		version += 1;
	}
	// every part is known up front, so a station never looks done before its loader reports
	part("server", "bridge", 0, 1);
	part("server", "remotes", 0, 1);
	part("save", "state", 0, 1);
	part("art", "images", 0, 1);
	part("art", "fonts", 0, 1);
	part("sound", "bank", 0, 1);
	part("world", "world", 0, 1);
	part("code", "modules", 0, 1);
	for (const [key] of pairs(MENU_NAMES)) {
		part("menus", key, 0, 1);
	}

	interface StationRow {
		key: string;
		label: string;
		verb: string;
		loaded: number;
		total: number;
		fraction: number;
		done: boolean;
		item?: string;
	}
	interface LedgerView {
		stations: StationRow[];
		overall: number;
		active?: StationRow;
	}

	const Ledger = {
		STATIONS: STATIONS,
		part: part,
		finish: finish,
		// a boot checklist key ("state", "fonts", "shell" ...) completing
		mark(this: void, key: string) {
			if (key === "assets") {
				finish("art", "images");
				finish("world", "world");
				return;
			}
			const entry = MARKS[key];
			if (entry !== undefined) {
				finish(entry[0], entry[1], entry[2]);
			} else if (MENU_NAMES[key] !== undefined) {
				finish("menus", key, MENU_NAMES[key]);
			}
		},
		// { stations = { {key, label, verb, loaded, total, fraction, done, item} }, overall, active }
		read(this: void): LedgerView {
			if (cache !== undefined && cacheVersion === version) {
				return cache as LedgerView;
			}
			const view: LedgerView = { stations: [], overall: 0, active: undefined };
			let sum = 0;
			let newest = -math.huge;
			for (const station of STATIONS) {
				let loaded = 0;
				let total = 0;
				for (const [, entry] of pairs(parts[station.key] ?? {})) {
					loaded += entry.loaded;
					total += entry.total;
				}
				const fraction = total > 0 ? loaded / total : 1;
				const row: StationRow = {
					key: station.key,
					label: station.label,
					verb: station.verb,
					loaded: loaded,
					total: total,
					fraction: fraction,
					done: fraction >= 1,
					item: items[station.key],
				};
				view.stations.push(row);
				sum += fraction;
				// the station working most recently is the one the screen talks about
				if (!row.done && (itemAt[station.key] ?? 0) > newest) {
					newest = itemAt[station.key] ?? 0;
					view.active = row;
				}
			}
			view.overall = sum / STATIONS.size();
			cache = view;
			cacheVersion = version;
			return view;
		},
		version(this: void): number {
			return version;
		},
	};
	return Ledger;
};

__defs["BootScreen"] = () => {
	const React = loadReact();
	const e = React.createElement as unknown as LooseCreate;
	const RunService = game.GetService("RunService");
	const Audio = (kitMember("AudioKit", "audio") as { Audio: AudioPlayer }).Audio;
	const BrandArt = kitMember("ArtKit", "Icon") as {
		Icon: LooseComponent;
		GAME_ICON_ASSET: string;
		WORDMARK_ASSET: string;
		COMPACT_MARK_ASSET: string;
	};
	const useViewport = (kitMember("MotionKit", "motion") as typeof import("./MotionKit/motion")).useViewport;
	const Ledger = __load("BootLedger") as {
		STATIONS: { key: string; label: string; verb: string }[];
		read(this: void): {
			stations: {
				key: string;
				label: string;
				verb: string;
				loaded: number;
				total: number;
				fraction: number;
				done: boolean;
				item?: string;
			}[];
			overall: number;
			active?: { verb: string; item?: string };
		};
		version(this: void): number;
	};
	const _theme = kitMember("CoreKit", "theme") as typeof import("./CoreKit/theme");
	const Palette = _theme.Palette;
	const BOOT_MODULE_TIMEOUT = 9;
	const MIN_BOOT_SECONDS = 2.6;
	const BOOT_MOTION = {
		motionScale: 1,
		viewportScale: 1,
		textScale: 1,
	};
	const STALL_SECONDS = 45;
	const SYSTEMS = [
		"bridge",
		"remotes",
		"state",
		"assets",
		"modules",
		"fonts",
		"audio",
		"shell",
		"mail",
		"research",
		"forge",
		"trade",
		"boosts",
		"settings",
		"mobile",
	];
	const LOADING_TIPS = [
		"Research stays with you when you rebirth.",
		"A full vault stops filling. Collect it often.",
		"Overcharge a machine by tapping it fast.",
		"Boosts stack with research, so start one before a long session.",
		"Rebirth when the Cores on offer would beat what you have now.",
		"The wheel's pity counter guarantees a rare sooner or later.",
		"Auto-Forge keeps buying your best machine while you're away.",
		"Daily shop stock changes at midnight UTC.",
		"Relics can be salvaged for essence if you pull a duplicate.",
		"You can replay the tour from Settings.",
	];
	const TIPS_EVERY = 8;
	const FADE_IN_SECONDS = 0.4;
	const EXIT_SECONDS = 0.5;
	const EXIT_SECONDS_REDUCED = 0.25;
	const STATUS_FADE = 0.2;

	function clamp01(value: number): number {
		return math.clamp(value, 0, 1);
	}
	function smooth(t: number): number {
		const u = clamp01(t);
		return u * u * (3 - 2 * u);
	}
	function progressFor(
		marks: Record<string, unknown>,
		assetsLoaded?: number,
		assetsTotal?: number,
		modulesLoaded?: number,
		modulesTotal?: number,
	): number {
		let complete = 0;
		for (const key of SYSTEMS) {
			if (marks[key] !== undefined && marks[key] !== false) {
				complete += 1;
			}
		}
		let partial = 0;
		if (
			(marks["assets"] === undefined || marks["assets"] === false) &&
			assetsTotal !== undefined &&
			assetsTotal > 0 &&
			assetsLoaded !== undefined
		) {
			partial += math.clamp(assetsLoaded / assetsTotal, 0, 1) * 0.85;
		}
		if (
			(marks["modules"] === undefined || marks["modules"] === false) &&
			modulesTotal !== undefined &&
			modulesTotal > 0 &&
			modulesLoaded !== undefined
		) {
			partial += math.clamp(modulesLoaded / modulesTotal, 0, 1) * 0.85;
		}
		return math.clamp((complete + partial) / SYSTEMS.size(), 0, 1);
	}
	function bootChecklistReady(marks: Record<string, unknown>): boolean {
		for (const key of SYSTEMS) {
			if (marks[key] === undefined || marks[key] === false) {
				return false;
			}
		}
		return true;
	}
	function bootProgress(
		marks: Record<string, unknown>,
		assetsLoaded?: number,
		assetsTotal?: number,
		modulesLoaded?: number,
		modulesTotal?: number,
	): number {
		return progressFor(marks, assetsLoaded, assetsTotal, modulesLoaded, modulesTotal);
	}

	interface BootLayout {
		short: boolean;
		column: number;
		wordH: number;
		wordY: number;
		statusY: number;
		barY: number;
		tipY: number;
		tipH: number;
		tipSize: number;
		statusSize: number;
	}

	// one centred column: wordmark, status + percent, the bar; the tip sits near the bottom
	function layoutFor(width: number, height: number): BootLayout {
		const short = height < 420;
		const column = math.min(440, math.max(200, width - 48));
		const wordH = short ? 40 : 64;
		const statusSize = short ? 14 : 16;
		const tipSize = short ? 13 : 14;
		const tipH = (tipSize + 4) * 2;
		const block = wordH + (short ? 18 : 32) + 20 + 10 + 4;
		const wordY = math.max(short ? 12 : 24, math.floor((height - block) * 0.5) - (short ? 10 : 24));
		const statusY = wordY + wordH + (short ? 18 : 32);
		return {
			short: short,
			column: column,
			wordH: wordH,
			wordY: wordY,
			statusY: statusY,
			barY: statusY + 20 + 10,
			tipY: height - tipH - (short ? 12 : 32),
			tipH: tipH,
			tipSize: tipSize,
			statusSize: statusSize,
		};
	}

	interface BootScreenProps {
		ready?: boolean;
		reducedMotion?: boolean;
		startedAt?: number;
		version?: string;
		onExitDone?: (this: void) => void;
	}

	function BootScreen(_param: BootScreenProps): unknown {
		const viewport = useViewport();
		const L = layoutFor(viewport.width, viewport.height);
		const ready = _param.ready;
		const reduced = _param.reducedMotion === true;
		const startedAt = _param.startedAt;
		const _version = _param.version;
		const onExitDone = _param.onExitDone;
		const mountedAt = React.useRef(startedAt ?? os.clock());
		const finished = React.useRef(false);
		const [exiting, setExiting] = React.useState(false);
		const [gone, setGone] = React.useState(false);
		const [stalled, setStalled] = React.useState(false);
		const [tipIndex, setTipIndex] = React.useState(() => math.random(1, LOADING_TIPS.size()));
		const [tipAt, setTipAt] = React.useState(() => os.clock());
		const [progress, setProgress] = React.useBinding(0);
		const [status, setStatus] = React.useBinding("Starting up");
		// 0..1: how far the current status line has faded in
		const [statusIn, setStatusIn] = React.useBinding(1);
		const [tipIn, setTipIn] = React.useBinding(reduced ? 1 : 0);
		// 0 visible .. 1 gone: the fade-in at start and the fade-out at the end
		const [cover, setCover] = React.useBinding(reduced ? 0 : 1);
		const shownRef = React.useRef(0);
		const statusRef = React.useRef({ text: "Starting up", at: 0 });
		const readyRef = React.useRef(ready);
		readyRef.current = ready;
		const exitAt = React.useRef(0);

		React.useEffect(() => {
			let alive = true;
			Audio.setScene("boot");
			const start = () => {
				if (alive && os.clock() - mountedAt.current <= 0.55) {
					Audio.play("bootStart");
				}
			};
			if (Audio.isWarm()) {
				start();
			} else {
				Audio.whenWarm(start);
			}
			return () => {
				alive = false;
				Audio.setScene("default");
			};
		}, []);
		React.useEffect(() => {
			const assetList = [BrandArt.GAME_ICON_ASSET, BrandArt.WORDMARK_ASSET, BrandArt.COMPACT_MARK_ASSET];
			let isStudio = false;
			pcall(() => {
				isStudio = RunService.IsStudio();
			});
			const preload = task.spawn(() => {
				const [ok, reason] = pcall(() => {
					game.GetService("ContentProvider").PreloadAsync(assetList, (asset, assetStatus) => {
						if (assetStatus !== Enum.AssetFetchStatus.Success && !isStudio) {
							warn(`[Branding] ${asset} failed to load: ${assetStatus.Name}`);
						}
					});
				});
				if (!ok && !isStudio) {
					warn(`[Branding] Preload failed: ${tostring(reason)}`);
				}
			});
			return () => {
				if (coroutine.status(preload) === "suspended") {
					task.cancel(preload);
				}
			};
		}, []);
		// one tip at a time, swapped every TIPS_EVERY seconds
		React.useEffect(() => {
			if (stalled) {
				return undefined;
			}
			const token = task.delay(TIPS_EVERY, () => {
				setTipIndex((index) => (index % LOADING_TIPS.size()) + 1);
				setTipAt(os.clock());
			});
			return () => {
				pcall(task.cancel, token);
			};
		}, [tipIndex, stalled]);
		React.useEffect(() => {
			if (ready === true) {
				return undefined;
			}
			const remaining = math.max(0, STALL_SECONDS - (os.clock() - mountedAt.current));
			const token = task.delay(remaining, () => {
				setStalled(true);
				setTipAt(os.clock());
			});
			return () => {
				pcall(task.cancel, token);
			};
		}, [ready]);
		React.useEffect(() => {
			if (exiting || finished.current) {
				return undefined;
			}
			if (ready === true) {
				const hold = math.max(0, MIN_BOOT_SECONDS - (os.clock() - mountedAt.current));
				const token = task.delay(hold, () => {
					if (finished.current) {
						return;
					}
					finished.current = true;
					exitAt.current = os.clock();
					setExiting(true);
					Audio.play("bootReady");
				});
				return () => {
					pcall(task.cancel, token);
				};
			}
			const timeout = RunService.IsStudio() ? 22 : 36;
			const token = task.delay(timeout, () => {
				if (!finished.current) {
					finished.current = true;
					exitAt.current = os.clock();
					setExiting(true);
				}
			});
			return () => {
				pcall(task.cancel, token);
			};
		}, [exiting, ready]);
		// one frame driver: ledger -> bar + status, and the fades
		React.useEffect(() => {
			const connection = RunService.RenderStepped.Connect((dt) => {
				const now = os.clock();
				const data = Ledger.read();
				const done = readyRef.current === true || exiting;
				// the bar only ever moves forward, and only reaches the end when the game is ready
				const target = done ? 1 : math.min(0.99, data.overall);
				const stepped = reduced ? target : shownRef.current + (target - shownRef.current) * (1 - math.exp(-dt * 8));
				shownRef.current = math.max(shownRef.current, stepped);
				setProgress(shownRef.current);
				const text = done ? "Ready" : data.active !== undefined ? data.active.verb : "Almost ready";
				if (text !== statusRef.current.text) {
					statusRef.current = { text: text, at: now };
					setStatus(text);
				}
				setStatusIn(reduced ? 1 : smooth((now - statusRef.current.at) / STATUS_FADE));
				setTipIn(reduced ? 1 : smooth((now - tipAt) / FADE_IN_SECONDS));
				if (exiting) {
					setCover(smooth((now - exitAt.current) / (reduced ? EXIT_SECONDS_REDUCED : EXIT_SECONDS)));
				} else {
					setCover(reduced ? 0 : 1 - smooth((now - mountedAt.current) / FADE_IN_SECONDS));
				}
			});
			return () => {
				connection.Disconnect();
			};
		}, [exiting, reduced, tipAt]);
		React.useEffect(() => {
			if (!exiting) {
				return undefined;
			}
			const token = task.delay((reduced ? EXIT_SECONDS_REDUCED : EXIT_SECONDS) + 0.05, () => {
				setGone(true);
				onExitDone?.();
			});
			return () => {
				pcall(task.cancel, token);
			};
		}, [exiting, onExitDone]);
		if (gone) {
			return e("frame", {
				Size: UDim2.fromOffset(0, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			});
		}

		const fadeFrom = (base: number) => cover.map((c) => clamp01(base + (1 - base) * c));
		const column = L.column;
		const centred = (y: number, height: number, width?: number) => ({
			Position: new UDim2(0.5, 0, 0, y),
			Size: UDim2.fromOffset(width ?? column, height),
			AnchorPoint: new Vector2(0.5, 0),
		});

		const wordmark = e("imagelabel", {
			Name: "BootWordmark",
			...centred(L.wordY, L.wordH),
			BackgroundTransparency: 1,
			Image: BrandArt.WORDMARK_ASSET,
			ImageTransparency: fadeFrom(0),
			ScaleType: Enum.ScaleType.Fit,
			ZIndex: 6,
		});

		const statusRow = e(
			"frame",
			{ ...centred(L.statusY, 20), BackgroundTransparency: 1, ZIndex: 6 },
			e("textlabel", {
				Name: "BootStatus",
				Size: new UDim2(1, -56, 1, 0),
				BackgroundTransparency: 1,
				Text: status,
				TextColor3: Palette.cream,
				TextTransparency: React.joinBindings({ c: cover, s: statusIn }).map((v) =>
					clamp01(1 - (1 - (v.c as number)) * (v.s as number)),
				),
				TextSize: L.statusSize,
				TextTruncate: Enum.TextTruncate.AtEnd,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Left,
				TextYAlignment: Enum.TextYAlignment.Bottom,
				ZIndex: 7,
			}),
			e("textlabel", {
				Name: "BootPercent",
				Size: new UDim2(0, 56, 1, 0),
				Position: UDim2.fromScale(1, 0),
				AnchorPoint: new Vector2(1, 0),
				BackgroundTransparency: 1,
				Text: progress.map((p) => `${math.floor(p * 100 + 0.5)}%`),
				TextColor3: Palette.muted,
				TextTransparency: fadeFrom(0.3),
				TextSize: L.statusSize,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Right,
				TextYAlignment: Enum.TextYAlignment.Bottom,
				ZIndex: 7,
			}),
		);

		const bar = e(
			"frame",
			{
				Name: "BootProgress",
				...centred(L.barY, 3),
				BackgroundColor3: Palette.line,
				BackgroundTransparency: fadeFrom(0.65),
				BorderSizePixel: 0,
				ZIndex: 6,
			},
			e("uicorner", { CornerRadius: new UDim(1, 0) }),
			e(
				"frame",
				{
					Name: "Fill",
					Size: progress.map((p) => UDim2.fromScale(math.max(0.01, p), 1)),
					BackgroundColor3: Palette.mango,
					BackgroundTransparency: fadeFrom(0),
					BorderSizePixel: 0,
					ZIndex: 7,
				},
				e("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
		);

		const tipText = stalled ? "Still loading. Your save is safe." : (LOADING_TIPS[tipIndex - 1] ?? "");
		const tip = e("textlabel", {
			Name: "BootTip",
			...centred(L.tipY, L.tipH),
			BackgroundTransparency: 1,
			Text: tipText,
			TextColor3: Palette.muted,
			TextTransparency: React.joinBindings({ c: cover, t: tipIn }).map((v) =>
				clamp01(1 - (1 - (v.c as number)) * (v.t as number)),
			),
			TextSize: L.tipSize,
			TextWrapped: true,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment: Enum.TextXAlignment.Center,
			TextYAlignment: Enum.TextYAlignment.Top,
			ZIndex: 6,
		});

		return e(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.white,
				BackgroundTransparency: exiting ? cover : 0,
				BorderSizePixel: 0,
				Active: !exiting,
				ZIndex: 420,
			},
			e("uigradient", {
				Rotation: 90,
				Color: new ColorSequence([
					new ColorSequenceKeypoint(0, Palette.void),
					new ColorSequenceKeypoint(0.55, Palette.night),
					new ColorSequenceKeypoint(1, Palette.void),
				]),
			}),
			wordmark,
			statusRow,
			bar,
			tip,
			_version !== undefined &&
				e("textlabel", {
					Size: UDim2.fromOffset(160, 14),
					Position: new UDim2(1, -16, 1, -14),
					AnchorPoint: new Vector2(1, 1),
					BackgroundTransparency: 1,
					Text: `v${_version}`,
					TextColor3: Palette.line,
					TextTransparency: fadeFrom(0),
					TextSize: 11,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment: Enum.TextXAlignment.Right,
					ZIndex: 6,
				}),
		);
	}
	return {
		bootChecklistReady: bootChecklistReady,
		bootProgress: bootProgress,
		BootScreen: BootScreen,
		layoutFor: layoutFor,
		BOOT_MODULE_TIMEOUT: BOOT_MODULE_TIMEOUT,
		BOOT_MOTION: BOOT_MOTION,
	};
};

__defs["LoadingDots"] = () => {
	const React = loadReact();
	const e = React.createElement as unknown as LooseCreate;
	const Palette = (kitMember("CoreKit", "theme") as typeof import("./CoreKit/theme")).Palette;
	const DOTS = [0, 1, 2, 3];
	const CYCLE = 0.86;
	const COUNT = 4;
	function clamp01(value: number): number {
		return math.clamp(value, 0, 1);
	}
	function pulse(elapsed: number, index: number): number {
		const travel = ((elapsed / CYCLE) % 1) * COUNT;
		const delta = math.abs(travel - index);
		const wrap = math.min(delta, COUNT - delta);
		const falloff = clamp01(1 - wrap);
		return falloff * falloff * (3 - 2 * falloff);
	}
	interface LoadingDotsProps {
		clock?: unknown;
		leaving?: unknown;
		ready?: boolean;
		reducedMotion?: boolean;
		compact?: boolean;
	}
	function LoadingDots(_param: LoadingDotsProps): unknown {
		const clock = _param.clock as React.Binding<number>;
		const leaving = _param.leaving as React.Binding<number> | undefined;
		const ready = _param.ready === true;
		const reducedMotion = _param.reducedMotion === true;
		const compact = _param.compact === true;
		const width = compact ? 92 : 112;
		const height = compact ? 22 : 26;
		const gap = compact ? 18 : 22;
		const size = compact ? 7 : 8;
		const lift = compact ? 5 : 6;
		const center = width / 2;
		const restY = height * 0.55;
		const [idleLeave] = React.useBinding(0);
		const exitBinding = leaving ?? idleLeave;
		const dots: unknown[] = table.create(DOTS.size());
		const dotFor = (index: number) => {
			const x = center + (index - 1.5) * gap;
			const motion = React.joinBindings({
				clock: clock,
				leaving: exitBinding,
			}).map((values) => {
				const elapsed = values.clock as number;
				const exit = values.leaving as number;
				const fade = clamp01(exit);
				if (reducedMotion || ready) {
					return {
						y: restY,
						scale: 0.72,
						alpha: 0.45,
						mix: 0,
						fade: fade,
					};
				}
				const amount = pulse(elapsed, index);
				return {
					y: restY - amount * lift,
					scale: 0.62 + amount * 0.38,
					alpha: 0.28 + amount * 0.72,
					mix: amount,
					fade: fade,
				};
			});
			return e(
				"frame",
				{
					key: `load-dot-${index}`,
					Size: motion.map((value) => {
						return UDim2.fromOffset(size * value.scale, size * value.scale);
					}),
					Position: motion.map((value) => {
						return UDim2.fromOffset(x, value.y);
					}),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: motion.map((value) => {
						return Palette.cream.Lerp(Palette.cyan, value.mix);
					}),
					BackgroundTransparency: motion.map((value) => {
						return clamp01(1 - value.alpha + value.fade);
					}),
					BorderSizePixel: 0,
					ZIndex: 527,
				},
				e("uicorner", {
					CornerRadius: new UDim(1, 0),
				}),
			);
		};
		for (const [k, v] of ipairs(DOTS)) {
			dots[k - 1] = dotFor(v);
		}
		return e(
			"frame",
			{
				Size: UDim2.fromOffset(width, height),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 525,
			},
			dots,
		);
	}
	return {
		LoadingDots: LoadingDots,
	};
};

__defs["SoftShutdownScreen"] = () => {
	const React = loadReact();
	const e = React.createElement as unknown as LooseCreate;
	const WORDMARK_ASSET = (kitMember("ArtKit", "Icon") as { WORDMARK_ASSET: string }).WORDMARK_ASSET;
	const useViewport = (kitMember("MotionKit", "motion") as typeof import("./MotionKit/motion")).useViewport;
	const RunService = game.GetService("RunService");
	const Audio = (kitMember("AudioKit", "audio") as { Audio: AudioPlayer }).Audio;
	const LoadingDots = (__load("LoadingDots") as { LoadingDots: LooseComponent }).LoadingDots;
	const Palette = (kitMember("CoreKit", "theme") as typeof import("./CoreKit/theme")).Palette;
	function phaseName(phase: unknown): string {
		if (phase === "Teleporting") {
			return "Teleporting";
		}
		if (phase === "Waiting") {
			return "Waiting";
		}
		return "Saving";
	}
	function titleFor(phase: string): string {
		if (phase === "Teleporting") {
			return "JOINING NEW SERVER";
		}
		if (phase === "Waiting") {
			return "RECONNECTING";
		}
		return "SAVING YOUR PROGRESS";
	}
	function statusFor(phase: string): string {
		if (phase === "Teleporting") {
			return "Save locked in. Moving you to the fresh server.";
		}
		if (phase === "Waiting") {
			return "Stay here. We'll move you when the new server is ready.";
		}
		return "Don't leave yet. Saving your progress.";
	}
	function cueFor(phase: string): string {
		if (phase === "Teleporting") {
			return "travel";
		}
		if (phase === "Waiting") {
			return "systemAlert";
		}
		return "bootStart";
	}
	interface ShutdownProps {
		state: { phase?: unknown; message?: string };
		reducedMotion?: boolean;
	}
	function SoftShutdownScreen(_param: ShutdownProps): unknown {
		const centerY = useViewport().height < 420 ? 0.32 : 0.44;
		const state = _param.state;
		const reducedMotion = _param.reducedMotion === true;
		const phase = phaseName(state.phase);
		const teleporting = phase === "Teleporting";
		const waiting = phase === "Waiting";
		const [clock, setClock] = React.useBinding(0);
		const spinClock = React.useRef(0);
		const [barPulse, setBarPulse] = React.useBinding(0.35);
		React.useEffect(() => {
			spinClock.current = 0;
			setClock(0);
			if (reducedMotion) {
				setBarPulse(teleporting ? 1 : waiting ? 0.55 : 0.4);
				return undefined;
			}
			const connection = RunService.RenderStepped.Connect((dt) => {
				spinClock.current += dt;
				setClock(spinClock.current);
				const wave = (math.sin(spinClock.current * 2.1) + 1) * 0.5;
				if (teleporting) {
					setBarPulse(0.72 + wave * 0.28);
				} else if (waiting) {
					setBarPulse(0.4 + wave * 0.35);
				} else {
					setBarPulse(0.28 + wave * 0.32);
				}
			});
			return () => {
				return connection.Disconnect();
			};
		}, [phase, reducedMotion, setClock, teleporting, waiting]);
		React.useEffect(() => {
			Audio.setScene("shutdown");
			Audio.play(cueFor(phase));
			return () => {
				return Audio.setScene("default");
			};
		}, [phase]);
		const phaseAccent = teleporting ? Palette.mint : waiting ? Palette.mango : Palette.cyan;
		return e(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Color3.fromRGB(0, 0, 0),
				BackgroundTransparency: 0,
				BorderSizePixel: 0,
				Active: true,
				Selectable: false,
				ZIndex: 900,
				ClipsDescendants: true,
			},
			e(
				"frame",
				{
					Size: UDim2.fromOffset(112, 26),
					Position: new UDim2(0.5, 0, centerY, 0),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 903,
				},
				e(LoadingDots, {
					clock: clock,
					ready: teleporting,
					reducedMotion: reducedMotion,
					compact: false,
				}),
			),
			e("imagelabel", {
				Name: "ShutdownWordmark",
				Size: new UDim2(0.8, 0, 0, 32),
				Position: new UDim2(0.5, 0, centerY, 20),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Image: WORDMARK_ASSET,
				ImageTransparency: 0.08,
				ScaleType: Enum.ScaleType.Fit,
				ZIndex: 904,
			}),
			e("textlabel", {
				Size: new UDim2(0.9, 0, 0, 18),
				Position: new UDim2(0.5, 0, centerY, 52),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Text: titleFor(phase),
				TextColor3: Color3.fromRGB(190, 174, 178),
				TextTransparency: 0.18,
				TextSize: 12,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Center,
				ZIndex: 904,
			}),
			e(
				"frame",
				{
					Size: UDim2.fromOffset(220, 4),
					Position: new UDim2(0.5, 0, centerY, 78),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundColor3: Color3.fromRGB(46, 36, 50),
					BackgroundTransparency: 0.15,
					BorderSizePixel: 0,
					ZIndex: 904,
					ClipsDescendants: true,
				},
				e("uicorner", {
					CornerRadius: new UDim(1, 0),
				}),
				e(
					"frame",
					{
						Size: barPulse.map((amount) => {
							return new UDim2(math.clamp(amount, 0.08, 1), 0, 1, 0);
						}),
						BackgroundColor3: phaseAccent,
						BackgroundTransparency: 0.1,
						BorderSizePixel: 0,
					},
					e("uicorner", {
						CornerRadius: new UDim(1, 0),
					}),
				),
			),
			e("textlabel", {
				Name: "ShutdownStatus",
				Size: new UDim2(0.9, 0, 0, 36),
				Position: new UDim2(0.5, 0, 1, -52),
				AnchorPoint: new Vector2(0.5, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Text: statusFor(phase),
				TextWrapped: true,
				TextColor3: Palette.creamSoft,
				TextTransparency: 0.08,
				TextSize: 12,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Center,
				ZIndex: 904,
			}),
			e("textlabel", {
				Name: "ShutdownMessage",
				Size: new UDim2(0.9, 0, 0, 36),
				Position: new UDim2(0.5, 0, 1, -12),
				AnchorPoint: new Vector2(0.5, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Text: state.message ?? "",
				Visible: state.message !== undefined && state.message !== "",
				TextColor3: Palette.muted,
				TextTransparency: 0.08,
				TextSize: 12,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Center,
				TextTruncate: Enum.TextTruncate.None,
				TextWrapped: true,
				ZIndex: 904,
			}),
		);
	}
	return {
		SoftShutdownScreen: SoftShutdownScreen,
	};
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type BootKitCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const BootKit = setmetatable(
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
) as unknown as BootKitCallable;

export = BootKit;
