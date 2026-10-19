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
		{ key: "server", label: "SERVER", verb: "Reaching the server" },
		{ key: "save", label: "SAVE", verb: "Opening your save" },
		{ key: "art", label: "ART", verb: "Loading art" },
		{ key: "sound", label: "SOUND", verb: "Loading sounds" },
		{ key: "world", label: "WORLD", verb: "Loading the world" },
		{ key: "code", label: "CODE", verb: "Starting the game" },
		{ key: "menus", label: "MENUS", verb: "Building the menus" },
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
	const TextService = game.GetService("TextService");
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
		read(): {
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
		version(): number;
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
	const EXIT_FLASH_SECONDS = 0.26;
	const EXIT_WIPE_SECONDS = 0.5;
	const STALL_SECONDS = 45;
	const TIP_SECONDS = 5.8;
	const EMBER_COUNT = 28;
	const SPARK_COUNT = 16;
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
		"Ctrl+K opens Find from anywhere.",
	];
	const HOT = Color3.fromRGB(255, 150, 60);
	const WHITE_HOT = Color3.fromRGB(255, 244, 222);

	function clamp01(value: number): number {
		return math.clamp(value, 0, 1);
	}
	function easeOut(t: number): number {
		const u = 1 - clamp01(t);
		return 1 - u * u * u;
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
		twoRows: boolean;
		tipTop: number;
		tipHeight: number;
		tipSize: number;
		tipLines: number;
		stationRow: number;
		stationsH: number;
		wordH: number;
		statusH: number;
		wordY: number;
		statusY: number;
		channelY: number;
		itemY: number;
		stationsY: number;
		blockBottom: number;
	}

	// where everything sits for a screen size; the block is centred in the space above the tip
	function layoutFor(width: number, height: number): BootLayout {
		const short = height < 420;
		const column = math.min(620, width * 0.86);
		const twoRows = column < 460;
		const tipLines = short ? 2 : 3;
		const tipSize = short ? 13 : 15;
		const tipHeight = 18 + tipLines * (tipSize + 6) + 10;
		const tipTop = height - tipHeight - (short ? 10 : 28);
		const stationRow = short ? 30 : 36;
		const stationsH = twoRows ? stationRow * 2 + 8 : stationRow;
		const wordH = short ? 32 : 60;
		const gapWord = short ? 14 : 30;
		const statusH = short ? 24 : 32;
		const itemGap = short ? 10 : 22;
		const block = wordH + gapWord + statusH + 6 + 8 + 8 + 16 + itemGap + stationsH;
		let y = math.max(short ? 10 : 24, math.floor((tipTop - block) * 0.5));
		const L: BootLayout = {
			short: short,
			column: column,
			twoRows: twoRows,
			tipTop: tipTop,
			tipHeight: tipHeight,
			tipSize: tipSize,
			tipLines: tipLines,
			stationRow: stationRow,
			stationsH: stationsH,
			wordH: wordH,
			statusH: statusH,
			wordY: 0,
			statusY: 0,
			channelY: 0,
			itemY: 0,
			stationsY: 0,
			blockBottom: 0,
		};
		L.wordY = y;
		y += wordH + gapWord;
		L.statusY = y;
		y += statusH + 6;
		L.channelY = y;
		y += 8 + 8;
		L.itemY = y;
		y += 16 + itemGap;
		L.stationsY = y;
		y += stationsH;
		L.blockBottom = y;
		return L;
	}

	interface WrapItem {
		index: number;
		x: number;
	}
	interface WrapLine {
		width: number;
		items: WrapItem[];
	}
	interface WrapSpot {
		line: number;
		x: number;
	}

	// centred word wrap: widths -> { [index] = { line, x } } with x measured from the centre line
	function wrapWords(
		widths: Record<number, number>,
		maxWidth: number,
		space: number,
	): LuaTuple<[Record<number, WrapSpot>, number]> {
		const lines: WrapLine[] = [];
		let line: WrapLine = { width: 0, items: [] };
		for (const [index, w] of pairs(widths)) {
			let grown = line.items.size() === 0 ? w : line.width + space + w;
			if (line.items.size() > 0 && grown > maxWidth) {
				lines.push(line);
				line = { width: 0, items: [] };
				grown = w;
			}
			line.items.push({ index: index, x: line.items.size() === 0 ? 0 : line.width + space });
			line.width = grown;
		}
		if (line.items.size() > 0) {
			lines.push(line);
		}
		const placed: Record<number, WrapSpot> = {};
		for (const [lineIndex, entry] of ipairs(lines)) {
			for (const item of entry.items) {
				placed[item.index] = { line: lineIndex, x: item.x - entry.width / 2 };
			}
		}
		return $tuple(placed, lines.size());
	}

	interface TipProps {
		text?: string;
		size: number;
		maxWidth: number;
		bornAt: number;
		leaveAt?: number;
		tick: unknown;
		hidden: unknown;
	}

	// a tip that arrives word by word, glowing hot and cooling to cream, and leaves the same way
	function TipText(props: TipProps): unknown {
		const words: string[] = [];
		for (const [word] of (props.text ?? "").gmatch("%S+")) {
			words.push(word as string);
		}
		const size = props.size;
		const widths: Record<number, number> = {};
		for (const [index, word] of ipairs(words)) {
			const [ok, bounds] = pcall(() => {
				return TextService.GetTextSize(word, size, Enum.Font.BuilderSansMedium, new Vector2(4096, 4096));
			});
			widths[index] = ok ? (bounds as Vector2).X + 1 : word.size() * size * 0.52;
		}
		const space = math.max(3, math.floor(size * 0.22));
		const [placed] = wrapWords(widths, props.maxWidth, space);
		const lineHeight = size + 6;
		const bornAt = props.bornAt;
		const leaveAt = props.leaveAt;
		const children: Record<string, unknown> = {};
		for (const [index, word] of ipairs(words)) {
			const spot = placed[index];
			const delay = (index - 1) * 0.04;
			const motion = (props.tick as React.Binding<number>).map(() => {
				const now = os.clock();
				const arrive = easeOut((now - bornAt - delay) / 0.4);
				const leave =
					leaveAt !== undefined ? easeOut((now - leaveAt - (index - 1) * 0.015) / 0.24) : 0;
				const cool = clamp01((now - bornAt - delay - 0.15) / 0.8);
				return { y: (1 - arrive) * 10 - leave * 9, alpha: 1 - arrive + leave, cool: cool };
			});
			children[`w${index}`] = e("textlabel", {
				Size: UDim2.fromOffset(widths[index] + 2, lineHeight),
				Position: motion.map((m) => {
					return new UDim2(0.5, spot.x, 0, (spot.line - 1) * lineHeight + m.y);
				}),
				BackgroundTransparency: 1,
				Text: word,
				TextSize: size,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment: Enum.TextXAlignment.Left,
				TextColor3: motion.map((m) => {
					return HOT.Lerp(Palette.creamSoft, m.cool);
				}),
				TextTransparency: React.joinBindings({
					motion: motion,
					hidden: props.hidden as React.Binding<number>,
				}).map(
					(values) => {
						return clamp01((values.motion as { alpha: number }).alpha + (values.hidden as number));
					},
				),
				ZIndex: 8,
			});
		}
		return e(
			"frame",
			{
				Size: new UDim2(1, 0, 1, 0),
				BackgroundTransparency: 1,
				ZIndex: 8,
			},
			children,
		);
	}

	interface CheckGlyphProps {
		position: UDim2;
		color: Color3;
		scale: unknown;
		transparency?: unknown;
	}

	// the station check (stamped in when a station finishes)
	function CheckGlyph(props: CheckGlyphProps): unknown {
		return e(
			"frame",
			{
				Size: UDim2.fromOffset(12, 12),
				Position: props.position,
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 9,
			},
			e("uiscale", { Scale: props.scale }),
			e(BrandArt.Icon, {
				kind: "Check.1",
				color: props.color,
				size: 12,
				spin: false,
			}),
		);
	}

	interface BootScreenProps {
		ready?: boolean;
		reducedMotion?: boolean;
		startedAt?: number;
		version?: string;
		onExitDone?: (this: void) => void;
	}

	interface Spark {
		born: number;
		vx: number;
		vy: number;
		life: number;
		head: number;
	}

	interface BootView {
		status: string;
		statusPrev: string;
		statusAt: number;
		item: string;
		itemAt: number;
		percent: number;
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
		doneAt: Record<string, number>;
	}

	function BootScreen(_param: BootScreenProps): unknown {
		const viewport = useViewport();
		const L = layoutFor(viewport.width, viewport.height);
		const ready = _param.ready;
		const softMotion = _param.reducedMotion;
		const startedAt = _param.startedAt;
		const _version = _param.version;
		const onExitDone = _param.onExitDone;
		const mountedAt = React.useRef(startedAt ?? os.clock());
		const finished = React.useRef(false);
		const exitClock = React.useRef(0);
		const [exiting, setExiting] = React.useState(false);
		const [gone, setGone] = React.useState(false);
		const [stalled, setStalled] = React.useState(false);
		const [tip, setTip] = React.useState(() => {
			return {
				index: math.random(1, LOADING_TIPS.size()),
				bornAt: os.clock(),
				leaveAt: undefined as number | undefined,
			};
		});
		const [tick, setTick] = React.useBinding(0);
		const [flash, setFlash] = React.useBinding(0);
		const [wipe, setWipe] = React.useBinding(0);
		const [shownProgress, setShownProgress] = React.useBinding(0);
		const shownRef = React.useRef(0);
		const readyRef = React.useRef(ready);
		readyRef.current = ready;
		// what the labels read; filled from the ledger each frame
		const view = React.useRef<BootView>({
			status: "Starting",
			statusPrev: "",
			statusAt: 0,
			item: "",
			itemAt: 0,
			percent: 0,
			stations: Ledger.read().stations,
			doneAt: {},
		});
		const sparks = React.useRef<Spark[] | undefined>(undefined);
		if (sparks.current === undefined) {
			const list: Spark[] = [];
			for (let index = 1; index <= SPARK_COUNT; index++) {
				list[index - 1] = { born: -1, vx: 0, vy: 0, life: 1, head: 0 };
			}
			sparks.current = list;
		}
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
				const rs = game.GetService("RunService");
				if (rs !== undefined && typeIs(rs.IsStudio, "function")) {
					isStudio = rs.IsStudio();
				}
			});
			const preload = task.spawn(() => {
				const [ok, reason] = pcall(() => {
					game.GetService("ContentProvider").PreloadAsync(assetList, (asset, status) => {
						if (status !== Enum.AssetFetchStatus.Success && !isStudio) {
							warn(`[Branding] ${asset} failed to load: ${status.Name}`);
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
		// tips: each one stays TIP_SECONDS, then its words leave before the next arrives
		const advanceTip = React.useCallback(() => {
			setTip((current) => {
				if (current.leaveAt !== undefined) {
					return current;
				}
				return { index: current.index, bornAt: current.bornAt, leaveAt: os.clock() };
			});
		}, []);
		React.useEffect(() => {
			if (tip.leaveAt !== undefined) {
				const token = task.delay(0.32, () => {
					setTip({
						index: (tip.index % LOADING_TIPS.size()) + 1,
						bornAt: os.clock(),
						leaveAt: undefined,
					});
				});
				return () => {
					pcall(task.cancel, token);
				};
			}
			const token = task.delay(TIP_SECONDS, advanceTip);
			return () => {
				pcall(task.cancel, token);
			};
		}, [tip]);
		React.useEffect(() => {
			if (ready === true) {
				return undefined;
			}
			const remaining = math.max(0, STALL_SECONDS - (os.clock() - mountedAt.current));
			const token = task.delay(remaining, () => {
				setStalled(true);
			});
			return () => {
				pcall(task.cancel, token);
			};
		}, [ready]);
		React.useEffect(() => {
			if (ready === true && !exiting && !finished.current) {
				const hold = math.max(0, MIN_BOOT_SECONDS - (os.clock() - mountedAt.current));
				const token = task.delay(hold, () => {
					if (finished.current) {
						return undefined;
					}
					finished.current = true;
					exitClock.current = 0;
					setExiting(true);
					Audio.play("bootReady");
					return undefined;
				});
				return () => {
					pcall(task.cancel, token);
				};
			} else if (!exiting && !finished.current) {
				const timeout = RunService.IsStudio() ? 22 : 36;
				const token = task.delay(timeout, () => {
					if (!finished.current) {
						finished.current = true;
						exitClock.current = 0;
						setExiting(true);
					}
				});
				return () => {
					pcall(task.cancel, token);
				};
			}
			return undefined;
		}, [exiting, ready]);
		// one frame driver: ledger -> labels, the pour, the sparks and the exit
		React.useEffect(() => {
			let spawnCarry = 0;
			let nextSpark = 1;
			const connection = RunService.RenderStepped.Connect((dt) => {
				const now = os.clock();
				const data = Ledger.read();
				const v = view.current;
				const target = readyRef.current === true || exiting ? 1 : math.min(0.99, data.overall);
				const before = shownRef.current;
				shownRef.current += (target - before) * (1 - math.exp(-dt * 6));
				setShownProgress(shownRef.current);
				v.percent = math.floor(shownRef.current * 100 + 0.5);
				v.stations = data.stations;
				const status =
					readyRef.current === true || exiting
						? "Ready"
						: data.active !== undefined
							? data.active.verb
							: "Almost there";
				if (status !== v.status) {
					v.statusPrev = v.status;
					v.status = status;
					v.statusAt = now;
				}
				const item = data.active !== undefined && data.active.item !== undefined ? data.active.item : "";
				if (item !== v.item && now - v.itemAt > 0.11) {
					v.item = item;
					v.itemAt = now;
				}
				for (const station of data.stations) {
					if (station.done && v.doneAt[station.key] === undefined) {
						v.doneAt[station.key] = now;
						if (now - mountedAt.current > 0.4) {
							pcall(() => {
								Audio.play("countTick");
							});
						}
					}
				}
				// sparks thrown back off the head of the pour, more when it surges
				if (softMotion !== true && !exiting) {
					const surge = math.max(0, shownRef.current - before) * 900;
					spawnCarry += dt * (5 + math.min(30, surge));
					while (spawnCarry >= 1) {
						spawnCarry -= 1;
						const spark = sparks.current![nextSpark - 1];
						nextSpark = (nextSpark % SPARK_COUNT) + 1;
						spark.born = now;
						spark.head = shownRef.current;
						spark.vx = -(25 + math.random() * 80);
						spark.vy = -(35 + math.random() * 95);
						spark.life = 0.4 + math.random() * 0.45;
					}
				}
				setTick(now);
				if (exiting) {
					exitClock.current += dt;
					const elapsed = exitClock.current;
					const scale = softMotion === true ? 0.6 : 1;
					setFlash(easeOut(elapsed / (EXIT_FLASH_SECONDS * scale)));
					const w = clamp01((elapsed - EXIT_FLASH_SECONDS * scale) / (EXIT_WIPE_SECONDS * scale));
					setWipe(w * w * (3 - 2 * w));
				}
			});
			return () => {
				connection.Disconnect();
			};
		}, [exiting, softMotion]);
		React.useEffect(() => {
			if (!exiting) {
				return undefined;
			}
			const span = (EXIT_FLASH_SECONDS + EXIT_WIPE_SECONDS) * (softMotion === true ? 0.6 : 1) + 0.05;
			const token = task.delay(span, () => {
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

		// on the way out the pour flashes white-hot, the content dims and rides up with the lifting cover
		const hidden = flash.map((f) => {
			return clamp01((f - 0.4) / 0.6) * 0.55;
		});
		const fadeFrom = (base: number) => {
			return hidden.map((amount) => {
				return clamp01(base + amount);
			});
		};
		const heat = React.joinBindings({ shown: shownProgress, flash: flash });

		// embers rising off the forge floor; more and brighter as it heats up
		const embers: Record<string, unknown> = {};
		for (let index = 1; index <= EMBER_COUNT; index++) {
			const seed = math.abs(math.sin(index * 12.9898) * 43758.5453) % 1;
			const seedB = math.abs(math.sin(index * 78.233) * 12345.678) % 1;
			const speed = (0.05 + seedB * 0.06) * (softMotion === true ? 0.5 : 1);
			const px = 2 + math.floor(seed * 3);
			embers[`e${index}`] = e(
				"frame",
				{
					Size: UDim2.fromOffset(px, px),
					Position: tick.map((now) => {
						const rise = (now * speed + seedB) % 1;
						const sway = math.sin(now * (0.7 + seed) + index) * 0.018;
						return UDim2.fromScale(seed + sway, 1.02 - rise * 1.08);
					}),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3:
						index % 4 === 0 ? WHITE_HOT : index % 2 === 0 ? Palette.mango : Palette.ember,
					BackgroundTransparency: React.joinBindings({
						tick: tick,
						shown: shownProgress,
						hidden: hidden,
					}).map((values) => {
						const rise = ((values.tick as number) * speed + seedB) % 1;
						const edge = rise < 0.1 ? 1 - rise / 0.1 : rise > 0.7 ? (rise - 0.7) / 0.3 : 0;
						return clamp01(
							0.62 - (values.shown as number) * 0.35 + edge * 0.6 + (values.hidden as number),
						);
					}),
					BorderSizePixel: 0,
					ZIndex: 2,
				},
				e("uicorner", { CornerRadius: new UDim(1, 0) }),
			);
		}

		const forgeGlow = e(
			"frame",
			{
				Size: UDim2.fromScale(1, 0.6),
				Position: UDim2.fromScale(0, 1),
				AnchorPoint: new Vector2(0, 1),
				BackgroundColor3: Palette.ember,
				BackgroundTransparency: heat.map((values) => {
					return clamp01(0.62 - (values.shown as number) * 0.3 - (values.flash as number) * 0.25);
				}),
				BorderSizePixel: 0,
				ZIndex: 1,
			},
			e("uigradient", {
				Rotation: -90,
				Color: new ColorSequence(Palette.mango, Palette.ember),
				Transparency: new NumberSequence([
					new NumberSequenceKeypoint(0, 0),
					new NumberSequenceKeypoint(0.35, 0.7),
					new NumberSequenceKeypoint(1, 1),
				]),
			}),
		);

		const column = L.column;
		const at = (y: number, height: number): LuaTuple<[UDim2, UDim2]> => {
			return $tuple(new UDim2(0.5, 0, 0, y), UDim2.fromOffset(column, height));
		};

		// wordmark with a white-hot glint crossing it now and then
		const [wordPos, wordSize] = at(L.wordY, L.wordH);
		const wordmark = e(
			"frame",
			{
				Position: wordPos,
				Size: wordSize,
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				ZIndex: 6,
			},
			e("imagelabel", {
				Name: "BootWordmark",
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				Image: BrandArt.WORDMARK_ASSET,
				ImageTransparency: fadeFrom(0),
				ScaleType: Enum.ScaleType.Fit,
				ZIndex: 6,
			}),
			softMotion !== true &&
				e(
					"imagelabel",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						Image: BrandArt.WORDMARK_ASSET,
						ImageColor3: WHITE_HOT,
						ImageTransparency: fadeFrom(0),
						ScaleType: Enum.ScaleType.Fit,
						ZIndex: 7,
					},
					e("uigradient", {
						Rotation: 20,
						Transparency: new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.42, 1),
							new NumberSequenceKeypoint(0.5, 0.25),
							new NumberSequenceKeypoint(0.58, 1),
							new NumberSequenceKeypoint(1, 1),
						]),
						Offset: tick.map((now) => {
							const cycle = (now - mountedAt.current) % 3.2;
							return new Vector2(-1.2 + clamp01(cycle / 1.1) * 2.4, 0);
						}),
					}),
				),
		);

		// status: what the game is doing (rolls over when it changes) and the percent
		const [statusPos, statusSize] = at(L.statusY, L.statusH);
		const statusSizePx = L.short ? 15 : 19;
		const statusLabel = (prev: boolean) => {
			return e("textlabel", {
				Size: new UDim2(1, -110, 1, 0),
				Position: tick.map((now) => {
					const a = easeOut((now - view.current.statusAt) / 0.32);
					return UDim2.fromOffset(0, prev ? -a * 12 : (1 - a) * 12);
				}),
				BackgroundTransparency: 1,
				Text: tick.map(() => {
					return prev ? view.current.statusPrev : view.current.status;
				}),
				TextColor3: Palette.cream,
				TextTransparency: React.joinBindings({ tick: tick, hidden: hidden }).map((values) => {
					const a = easeOut(((values.tick as number) - view.current.statusAt) / 0.32);
					return clamp01((prev ? a : 1 - a) + (values.hidden as number));
				}),
				TextSize: statusSizePx,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				TextXAlignment: Enum.TextXAlignment.Left,
				TextYAlignment: Enum.TextYAlignment.Bottom,
				ZIndex: 7,
			});
		};
		const statusRow = e(
			"frame",
			{
				Position: statusPos,
				Size: statusSize,
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				ClipsDescendants: true,
				ZIndex: 6,
			},
			statusLabel(false),
			statusLabel(true),
			e("textlabel", {
				Size: new UDim2(0, 110, 1, 0),
				Position: UDim2.fromScale(1, 0),
				AnchorPoint: new Vector2(1, 0),
				BackgroundTransparency: 1,
				Text: tick.map(() => {
					return `${view.current.percent}<font size="${math.floor(statusSizePx * 0.75)}" transparency="0.35">%</font>`;
				}),
				RichText: true,
				TextColor3: heat.map((values) => {
					return Palette.mango.Lerp(WHITE_HOT, values.flash as number);
				}),
				TextTransparency: fadeFrom(0),
				TextSize: L.short ? 22 : 30,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextXAlignment: Enum.TextXAlignment.Right,
				TextYAlignment: Enum.TextYAlignment.Bottom,
				ZIndex: 7,
			}),
		);

		// the pour: molten metal running along a channel, white-hot at its head
		const sparkFrames: Record<string, unknown> = {};
		for (let index = 1; index <= SPARK_COUNT; index++) {
			const sample = (now: number): LuaTuple<[number | undefined, Spark]> => {
				const spark = sparks.current![index - 1];
				const age = now - spark.born;
				if (spark.born < 0 || age > spark.life || age < 0) {
					return $tuple(undefined, spark);
				}
				return $tuple(age, spark);
			};
			sparkFrames[`s${index}`] = e(
				"frame",
				{
					Size: tick.map((now) => {
						const [age, spark] = sample(now);
						const d = age !== undefined ? math.max(1, 3.5 * (1 - age / spark.life)) : 0;
						return UDim2.fromOffset(d, d);
					}),
					Position: tick.map((now) => {
						const [age, spark] = sample(now);
						if (age === undefined) {
							return UDim2.fromScale(0, 0.5);
						}
						return new UDim2(spark.head, spark.vx * age, 0.5, spark.vy * age + 140 * age * age);
					}),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: WHITE_HOT,
					BackgroundTransparency: tick.map((now) => {
						const [age, spark] = sample(now);
						return age !== undefined ? clamp01(age / spark.life) : 1;
					}),
					BorderSizePixel: 0,
					ZIndex: 9,
				},
				e("uicorner", { CornerRadius: new UDim(1, 0) }),
			);
		}
		const [channelPos, channelSize] = at(L.channelY, 8);
		const channel = e(
			"frame",
			{
				Name: "BootPour",
				Position: channelPos,
				Size: channelSize,
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundColor3: Palette.night,
				BackgroundTransparency: fadeFrom(0.1),
				BorderSizePixel: 0,
				ZIndex: 6,
			},
			e("uicorner", { CornerRadius: new UDim(1, 0) }),
			e("uistroke", {
				Color: Palette.line,
				Transparency: fadeFrom(0.35),
				Thickness: 1,
			}),
			e(
				"frame",
				{
					Name: "Metal",
					Size: shownProgress.map((shown) => {
						return UDim2.fromScale(math.max(0.012, shown), 1);
					}),
					BackgroundColor3: Palette.white,
					BackgroundTransparency: fadeFrom(0),
					BorderSizePixel: 0,
					ZIndex: 7,
				},
				e("uicorner", { CornerRadius: new UDim(1, 0) }),
				e("uigradient", {
					Color: flash.map((f) => {
						return new ColorSequence([
							new ColorSequenceKeypoint(0, Palette.ember.Lerp(WHITE_HOT, f)),
							new ColorSequenceKeypoint(0.8, Palette.mango.Lerp(WHITE_HOT, f)),
							new ColorSequenceKeypoint(1, WHITE_HOT),
						]);
					}),
				}),
				e(
					"frame",
					{
						// slag ripples drifting back along the surface
						Size: UDim2.fromScale(1, 1),
						BackgroundColor3: WHITE_HOT,
						BackgroundTransparency: fadeFrom(0),
						BorderSizePixel: 0,
						ZIndex: 8,
					},
					e("uicorner", { CornerRadius: new UDim(1, 0) }),
					e("uigradient", {
						Transparency: new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.2, 0.7),
							new NumberSequenceKeypoint(0.3, 1),
							new NumberSequenceKeypoint(0.55, 0.78),
							new NumberSequenceKeypoint(0.62, 1),
							new NumberSequenceKeypoint(1, 1),
						]),
						Offset: tick.map((now) => {
							return new Vector2(-((now * 0.35) % 1), 0);
						}),
					}),
				),
			),
			e(
				"frame",
				{
					Name: "Head",
					Size: tick.map((now) => {
						const d = 26 + math.sin(now * 7) * 3;
						return UDim2.fromOffset(d, d);
					}),
					Position: shownProgress.map((shown) => {
						return UDim2.fromScale(math.max(0.012, shown), 0.5);
					}),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: Palette.mango,
					BackgroundTransparency: fadeFrom(0.72),
					BorderSizePixel: 0,
					ZIndex: 8,
				},
				e("uicorner", { CornerRadius: new UDim(1, 0) }),
				e(
					"frame",
					{
						Size: UDim2.fromOffset(10, 10),
						Position: UDim2.fromScale(0.5, 0.5),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundColor3: WHITE_HOT,
						BackgroundTransparency: fadeFrom(0),
						BorderSizePixel: 0,
						ZIndex: 9,
					},
					e("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
			),
			sparkFrames,
		);

		// the exact thing loading right now
		const [itemPos, itemSize] = at(L.itemY, 16);
		const itemLine = e("textlabel", {
			Position: itemPos,
			Size: itemSize,
			AnchorPoint: new Vector2(0.5, 0),
			BackgroundTransparency: 1,
			Text: tick.map(() => {
				return view.current.item;
			}),
			TextColor3: Palette.muted,
			TextTransparency: React.joinBindings({ tick: tick, hidden: hidden }).map((values) => {
				return clamp01(
					0.15 + (1 - easeOut(((values.tick as number) - view.current.itemAt) / 0.16)) * 0.6 + (values.hidden as number),
				);
			}),
			TextSize: 13,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment: Enum.TextXAlignment.Left,
			ZIndex: 7,
		});

		// stations: every part of the game, with its real count; a check stamps in when one is done
		const stationNodes: Record<string, unknown> = {};
		const perRow = L.twoRows ? 4 : Ledger.STATIONS.size();
		const cellW = column / perRow;
		for (const [index, station] of ipairs(Ledger.STATIONS)) {
			const key = station.key;
			const row = math.floor((index - 1) / perRow);
			const col = (index - 1) % perRow;
			const readRow = () => {
				for (const entry of view.current.stations) {
					if (entry.key === key) {
						return entry;
					}
				}
				return undefined;
			};
			const stampScale = (now: number) => {
				const doneAt = view.current.doneAt[key];
				if (doneAt === undefined) {
					return 0;
				}
				return easeOut((now - doneAt) / 0.28);
			};
			stationNodes[key] = e(
				"frame",
				{
					Size: UDim2.fromOffset(cellW - 8, L.stationRow),
					Position: UDim2.fromOffset(col * cellW, row * (L.stationRow + 8)),
					BackgroundTransparency: 1,
					ZIndex: 6,
				},
				e(
					"frame",
					{
						Size: new UDim2(1, 0, 0, 2),
						BackgroundColor3: Palette.line,
						BackgroundTransparency: fadeFrom(0.4),
						BorderSizePixel: 0,
						ZIndex: 6,
					},
					e("frame", {
						Size: tick.map(() => {
							const entry = readRow();
							return UDim2.fromScale(entry !== undefined ? entry.fraction : 0, 1);
						}),
						BackgroundColor3: tick.map(() => {
							const entry = readRow();
							return entry !== undefined && entry.done ? Palette.cream : Palette.mango;
						}),
						BackgroundTransparency: fadeFrom(0),
						BorderSizePixel: 0,
						ZIndex: 7,
					}),
				),
				e(CheckGlyph, {
					position: new UDim2(0, 0, 0, 13),
					color: Palette.cream,
					scale: tick.map((now) => {
						const s = stampScale(now);
						return s <= 0 ? 0 : 1 + (1 - s) * 0.6;
					}),
					transparency: fadeFrom(0),
				}),
				e("textlabel", {
					Size: new UDim2(1, -14, 0, 14),
					Position: tick.map((now) => {
						return UDim2.fromOffset(view.current.doneAt[key] !== undefined ? 15 * stampScale(now) : 0, 6);
					}),
					BackgroundTransparency: 1,
					Text: station.label,
					TextColor3: tick.map((now) => {
						const entry = readRow();
						if (entry !== undefined && entry.done) {
							return Palette.cream;
						}
						const active = view.current.status === station.verb;
						return active ? Palette.mango.Lerp(WHITE_HOT, (math.sin(now * 5) + 1) * 0.2) : Palette.muted;
					}),
					TextTransparency: fadeFrom(0),
					TextSize: 11,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
					TextXAlignment: Enum.TextXAlignment.Left,
					ZIndex: 7,
				}),
				!L.short &&
					e("textlabel", {
						Size: new UDim2(1, 0, 0, 12),
						Position: UDim2.fromOffset(0, 21),
						BackgroundTransparency: 1,
						Text: tick.map(() => {
							const entry = readRow();
							if (entry === undefined) {
								return "";
							}
							if (entry.total <= 1 || entry.done) {
								return entry.done ? "done" : "waiting";
							}
							return `${math.floor(entry.loaded)} / ${math.floor(entry.total)}`;
						}),
						TextColor3: Palette.muted,
						TextTransparency: fadeFrom(0.3),
						TextSize: 10,
						FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment: Enum.TextXAlignment.Left,
						ZIndex: 7,
					}),
			);
		}
		const [stationsPos, stationsSize] = at(L.stationsY, L.stationsH);
		const stationsRow = e(
			"frame",
			{
				Position: stationsPos,
				Size: stationsSize,
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				ZIndex: 6,
			},
			stationNodes,
		);

		// the tip: numbered, word by word, with a fuse burning down to the next one; tap for the next
		const tipText = stalled ? "Still loading. Your save is safe." : (LOADING_TIPS[tip.index - 1] ?? "");
		const tipBlock = e(
			"textbutton",
			{
				Position: new UDim2(0.5, 0, 0, L.tipTop),
				Size: UDim2.fromOffset(math.min(column, 560), L.tipHeight),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				Active: !exiting,
				ZIndex: 7,
				Event: { Activated: advanceTip },
			},
			e("textlabel", {
				Size: new UDim2(1, 0, 0, 14),
				BackgroundTransparency: 1,
				Text: stalled ? "TAKING A WHILE" : `TIP ${tip.index} OF ${LOADING_TIPS.size()}`,
				TextColor3: Palette.mango,
				TextTransparency: fadeFrom(0.1),
				TextSize: 11,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 8,
			}),
			e(
				"frame",
				{
					Size: new UDim2(1, 0, 0, L.tipLines * (L.tipSize + 6)),
					Position: UDim2.fromOffset(0, 18),
					BackgroundTransparency: 1,
					ZIndex: 8,
				},
				e(TipText, {
					key: `${tostring(tip.index)}:${tostring(tip.bornAt)}${stalled ? ":stall" : ""}`,
					text: tipText,
					size: L.tipSize,
					maxWidth: math.min(column, 560),
					bornAt: tip.bornAt,
					leaveAt: tip.leaveAt,
					tick: tick,
					hidden: hidden,
				}),
			),
			!stalled &&
				e(
					"frame",
					{
						Size: UDim2.fromOffset(120, 2),
						Position: new UDim2(0.5, 0, 1, -2),
						AnchorPoint: new Vector2(0.5, 1),
						BackgroundColor3: Palette.line,
						BackgroundTransparency: fadeFrom(0.5),
						BorderSizePixel: 0,
						ZIndex: 8,
					},
					e("frame", {
						Size: tick.map((now) => {
							return UDim2.fromScale(1 - clamp01((now - tip.bornAt) / TIP_SECONDS), 1);
						}),
						Position: UDim2.fromScale(0.5, 0),
						AnchorPoint: new Vector2(0.5, 0),
						BackgroundColor3: Palette.mango,
						BackgroundTransparency: fadeFrom(0.1),
						BorderSizePixel: 0,
						ZIndex: 9,
					}),
				),
		);

		// the cover lifts from the bottom up, a glowing seam running along its edge
		const seam = e(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 3),
				Position: wipe.map((w) => {
					return UDim2.fromScale(0, 1 - w);
				}),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: WHITE_HOT,
				BorderSizePixel: 0,
				Visible: wipe.map((w) => {
					return w > 0.001 && w < 0.999;
				}),
				ZIndex: 30,
			},
			e(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 46),
					Position: UDim2.fromScale(0, 0),
					AnchorPoint: new Vector2(0, 1),
					BackgroundColor3: Palette.mango,
					BorderSizePixel: 0,
					ZIndex: 29,
				},
				e("uigradient", {
					Rotation: -90,
					Transparency: new NumberSequence(0.35, 1),
				}),
			),
		);

		return e(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.white,
				BorderSizePixel: 0,
				Active: !exiting && !gone,
				ClipsDescendants: true,
				ZIndex: 420,
				Visible: wipe.map((w) => {
					return w < 0.995;
				}),
			},
			e("uigradient", {
				Rotation: 90,
				Color: new ColorSequence([
					new ColorSequenceKeypoint(0, Palette.void),
					new ColorSequenceKeypoint(0.55, Palette.night),
					new ColorSequenceKeypoint(1, Palette.void),
				]),
				Transparency: wipe.map((w) => {
					if (w <= 0.001) {
						return new NumberSequence(0);
					} else if (w >= 0.999) {
						return new NumberSequence(1);
					}
					const edge = 1 - w;
					return new NumberSequence([
						new NumberSequenceKeypoint(0, 0),
						new NumberSequenceKeypoint(math.max(0.001, edge - 0.002), 0),
						new NumberSequenceKeypoint(math.min(0.999, edge), 1),
						new NumberSequenceKeypoint(1, 1),
					]);
				}),
			}),
			e(
				"frame",
				{
					// everything inside lifts away with the cover
					Size: UDim2.fromScale(1, 1),
					Position: wipe.map((w) => {
						return UDim2.fromScale(0, -w);
					}),
					BackgroundTransparency: 1,
					ZIndex: 2,
				},
				forgeGlow,
				e(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						ZIndex: 2,
					},
					embers,
				),
				wordmark,
				statusRow,
				channel,
				itemLine,
				stationsRow,
				tipBlock,
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
			),
			seam,
		);
	}
	return {
		bootChecklistReady: bootChecklistReady,
		bootProgress: bootProgress,
		BootScreen: BootScreen,
		layoutFor: layoutFor,
		wrapWords: wrapWords,
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
