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
	const target = AstralForge.WaitForChild(kit);
	if (target.IsA("ModuleScript")) {
		const loaded = require(target) as LuaKit | Record<string, unknown>;
		if (typeIs(loaded, "function")) {
			return (loaded as LuaKit)(member);
		} else if (typeIs(loaded, "table") && member in loaded) {
			return (loaded as Record<string, unknown>)[member];
		}
	}
	const child = target.WaitForChild(member);
	if (child.IsA("ModuleScript")) {
		return require(child);
	}
	return child;
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
	// what happened and when, so the screen can say more than "loading": each station's finish time and a
	// short trail of the things that completed (the screen shows the last few)
	const bornAt = os.clock();
	const doneAt: Record<string, number | undefined> = {};
	const trail: { at: number; text: string }[] = [];
	function pushEvent(text: string) {
		trail.push({ at: os.clock() - bornAt, text: text });
		if (trail.size() > 40) {
			trail.remove(0);
		}
		version += 1;
	}
	function stationLabel(key: string): string {
		for (const station of STATIONS) {
			if (station.key === key) {
				return station.label;
			}
		}
		return key;
	}
	function stationFraction(key: string): number {
		let loaded = 0;
		let total = 0;
		for (const [, entry] of pairs(parts[key] ?? {})) {
			loaded += entry.loaded;
			total += entry.total;
		}
		return total > 0 ? loaded / total : 1;
	}
	// the first time a station is whole: stamp it, add it to the trail, and put it in the log with its time
	function checkDone(key: string) {
		if (doneAt[key] !== undefined || stationFraction(key) < 1) {
			return;
		}
		const elapsed = os.clock() - bornAt;
		doneAt[key] = elapsed;
		pushEvent(`${stationLabel(key)} ready`);
		pcall(() => {
			const log = kitMember("CoreKit", "log") as {
				ClientLog: { info(this: void, scope: string, message: string, params?: Record<string, unknown>): void };
			};
			log.ClientLog.info("boot", `${string.lower(stationLabel(key))} ready`, { ElapsedMs: math.floor(elapsed * 1000) });
		});
	}

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
		checkDone(station);
	}
	function finish(station: string, sub: string, item?: string) {
		const entry = parts[station] !== undefined ? parts[station][sub] : undefined;
		if (entry === undefined) {
			part(station, sub, 1, 1, item);
			return;
		}
		entry.loaded = entry.total;
		stamp(station, item);
		if (typeIs(item, "string") && item !== "") {
			pushEvent(item);
		}
		version += 1;
		checkDone(station);
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
	part("code", "tune", 0, 1);
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
		elapsed?: number;
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
					elapsed: doneAt[station.key],
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
		// the last few things that completed, oldest first
		events(this: void, limit: number): { at: number; text: string }[] {
			const out: { at: number; text: string }[] = [];
			for (let i = math.max(0, trail.size() - limit); i < trail.size(); i++) {
				out.push(trail[i]);
			}
			return out;
		},
		// seconds since the ledger was created (the screen's clock)
		age(this: void): number {
			return os.clock() - bornAt;
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
	// the engraved clock and the star-chart paper (tools/assetgen/art, uploaded by upload_art.py)
	const Art = (kitMember("ArtKit", "ArtAssets") as { ART: Record<string, string> }).ART;
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
				elapsed?: number;
			}[];
			overall: number;
			active?: { key: string; verb: string; item?: string };
		};
		version(this: void): number;
		events(this: void, limit: number): { at: number; text: string }[];
		age(this: void): number;
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
		"Ore from the Reaches buys upgrades that never reset.",
		"Strike the Rift Warden together for a share of its Starsteel.",
	];
	const TIPS_EVERY = 8;
	const FADE_IN_SECONDS = 0.4;
	// the outro: the rings swell and fade, a ripple goes out, then the screen dissolves
	const EXIT_SECONDS = 1.15;
	const EXIT_SECONDS_REDUCED = 0.25;
	const STATUS_FADE = 0.2;

	function clamp01(value: number): number {
		return math.clamp(value, 0, 1);
	}
	function smooth(t: number): number {
		const u = clamp01(t);
		return u * u * (3 - 2 * u);
	}
	function easeOut(t: number): number {
		const u = clamp01(t);
		return 1 - (1 - u) ** 3;
	}
	function easeIn(t: number): number {
		const u = clamp01(t);
		return u * u * u;
	}
	// a small overshoot as it settles, for the rete snapping into place
	function easeOutBack(t: number): number {
		const u = clamp01(t);
		const c = 1.4;
		return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2;
	}
	function escapeRich(text: string): string {
		return text.gsub("&", "&amp;")[0].gsub("<", "&lt;")[0].gsub(">", "&gt;")[0];
	}
	// each letter fades in a moment after the one before it (RichText per-letter transparency)
	function cascade(text: string, age: number): string {
		let out = "";
		let index = 0;
		for (const [, code] of utf8.codes(text)) {
			const letter = escapeRich(utf8.char(code));
			const shown = clamp01((age - index * 0.022) / 0.22);
			out += shown >= 0.99 ? letter : `<font transparency="${string.format("%.2f", 1 - shown)}">${letter}</font>`;
			index += 1;
		}
		return out;
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
		// the detail panel (stations, tally, trail) sits under the bar when there is room; keep its height in step
		const detail = height >= 440 ? 12 + 24 + 10 + 18 * 7 + 10 + 42 : 0;
		const wordY = math.max(
			short ? 12 : 16,
			math.floor((height - block - detail - (detail > 0 ? tipH + 40 : 0)) * 0.5) - (short ? 10 : detail > 0 ? 0 : 24),
		);
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
		// the ledger as of a few frames ago: the station rows redraw from this, about eight times a second
		const [view, setView] = React.useState(() => Ledger.read());
		const [shownPercent, setShownPercent] = React.useState(0);
		const [status, setStatus] = React.useBinding("Starting up");
		// 0..1: how far the current status line has faded in
		const [statusIn, setStatusIn] = React.useBinding(1);
		const [tipIn, setTipIn] = React.useBinding(reduced ? 1 : 0);
		// 0 visible .. 1 gone: the fade-in at start and the fade-out at the end
		const [cover, setCover] = React.useBinding(reduced ? 0 : 1);
		// seconds since the screen appeared and since the outro began; every intro/outro motion derives from these
		const [clock, setClock] = React.useBinding(0);
		const [exitClock, setExitClock] = React.useBinding(0);
		// the clock: hands at ten past ten until the loop starts them moving
		const [still] = React.useBinding(0);
		const [hourAngle, setHourAngle] = React.useBinding(305);
		const [minuteAngle, setMinuteAngle] = React.useBinding(60);
		const [secondAngle, setSecondAngle] = React.useBinding(0);
		const [wheelAngle, setWheelAngle] = React.useBinding(0);
		const [pinionAngle, setPinionAngle] = React.useBinding(0);
		const [escapeAngle, setEscapeAngle] = React.useBinding(0);
		const [percentText, setPercentText] = React.useBinding("0%");
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
			let viewAt = 0;
			const connection = RunService.RenderStepped.Connect((dt) => {
				const now = os.clock();
				const data = Ledger.read();
				if (now - viewAt > 0.12) {
					viewAt = now;
					setView(data);
					setShownPercent(math.floor(shownRef.current * 100 + 0.5));
				}
				const done = readyRef.current === true || exiting;
				// the bar only ever moves forward, and only reaches the end when the game is ready
				const target = done ? 1 : math.min(0.99, data.overall);
				const stepped = reduced ? target : shownRef.current + (target - shownRef.current) * (1 - math.exp(-dt * 8));
				shownRef.current = math.max(shownRef.current, stepped);
				setProgress(shownRef.current);
				const text = done
					? "Ready"
					: data.active !== undefined
						? data.active.item !== undefined
							? `${data.active.verb}  ·  ${data.active.item}`
							: data.active.verb
						: "Almost ready";
				if (text !== statusRef.current.text) {
					statusRef.current = { text: text, at: now };
				}
				// the status line types itself in, one letter after another
				const age = now - statusRef.current.at;
				setStatus(reduced || age > 2 ? escapeRich(statusRef.current.text) : cascade(statusRef.current.text, age));
				const t = now - mountedAt.current;
				const x = exiting ? now - exitAt.current : 0;
				setClock(t);
				setExitClock(x);
				setPercentText(done ? "100%" : `${math.floor(shownRef.current * 100)}%`);
				if (!reduced) {
					// a time-lapse: the minute hand sweeps a turn every 2.4 seconds from ten past ten, the hour hand
					// follows at a twelfth of its pace, and on the way out both race
					const sweep = t * 150 + x * x * 900;
					setMinuteAngle(60 + sweep);
					setHourAngle(305 + sweep / 12);
					// the seconds hand ticks twice a second; each tick lands with a small mechanical overshoot
					const ticks = t * 2;
					const whole = math.floor(ticks);
					const landed = whole + easeOutBack(clamp01((ticks - whole) / 0.16));
					setSecondAngle(landed * 30);
					// the movement: the escape wheel steps with the tick, the great wheel turns with the minute hand,
					// and the small wheel it drives turns the other way at 40/24 the speed
					setEscapeAngle(landed * 24);
					setWheelAngle(sweep / 6);
					setPinionAngle((-sweep / 6) * (40 / 24));
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

		// ── the clock ─────────────────────────────────────────────────────────────────────────
		// An engraved skeleton clock (designed art, ArtKit/ArtAssets), one image per part, over a printed star chart.
		// Intro: the paper comes up, the lamplight blooms, the movement and the dial turn into place, the hands sweep
		// in from midnight and settle at ten past ten, the wordmark rises. Loop: a time-lapse sweep, the seconds hand
		// ticking. Outro: the hands race, the clock swells and fades, an engraved ring ripples out, and the screen
		// dissolves into the game.
		const H = viewport.height;
		const W = viewport.width;
		const D = math.floor(math.min(H * (L.short ? 0.44 : 0.5), W * 0.62, 440));
		const centreY = math.floor(H * 0.46);
		const both = React.joinBindings({ t: clock, x: exitClock });
		const phase = (introFrom: number, introSpan: number, outFrom: number, outSpan: number, back = false) =>
			both.map((v) => {
				const raw = clamp01(((v.t as number) - introFrom) / introSpan);
				const shown = reduced ? 1 : back ? easeOutBack(raw) : easeOut(raw);
				const gone = exiting ? easeIn(clamp01(((v.x as number) - outFrom) / outSpan)) : 0;
				return [shown, gone] as [number, number];
			});
		const ring = (
			name: string,
			image: string,
			size: number,
			spin: unknown,
			k: import("@rbxts/react").Binding<[number, number]>,
			turnIn: number,
			grow: number,
			z: number,
			alpha = 1,
			// where the part's axle sits, as a share of the dial's diameter from its centre (the wheels sit off-centre)
			offset: [number, number] = [0, 0],
			tint: Color3 = new Color3(1, 1, 1),
		) =>
			e("imagelabel", {
				Name: name,
				AnchorPoint: new Vector2(0.5, 0.5),
				Position: k.map(([, gone]) => {
					const spread = 1 + gone * grow;
					return new UDim2(0.5, offset[0] * D * spread, 0, centreY + offset[1] * D * spread);
				}),
				Size: k.map(([shown, gone]) => {
					const s = size * (0.86 + 0.14 * math.min(shown, 1.08)) * (1 + gone * grow);
					return UDim2.fromOffset(s, s);
				}),
				Rotation: React.joinBindings({ r: spin as never, k: k as never }).map((v) => (v.r as number) - (1 - math.min((v.k as [number, number])[0], 1)) * turnIn),
				ImageTransparency: k.map(([shown, gone]) => clamp01(1 - math.min(shown, 1) * (1 - gone) * alpha)),
				ImageColor3: tint,
				Image: image,
				BackgroundTransparency: 1,
				ScaleType: Enum.ScaleType.Fit,
				ZIndex: z,
			});

		const backdropIn = phase(0, 0.6, 0.45, 0.65);
		const backdrop = e("imagelabel", {
			Name: "BootBackdrop",
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			Image: Art.BootBackdrop,
			ScaleType: Enum.ScaleType.Crop,
			ImageTransparency: backdropIn.map(([shown, gone]) => clamp01(1 - shown * (1 - gone))),
			ZIndex: 2,
		});
		const glowK = phase(0.15, 0.75, 0.2, 0.6);
		const glow = e("imagelabel", {
			Name: "BootLamp",
			AnchorPoint: new Vector2(0.5, 0.5),
			Position: new UDim2(0.5, 0, 0, centreY),
			Size: glowK.map(([shown, gone]) => UDim2.fromOffset(D * (1.1 + 0.5 * shown + gone * 0.6), D * (1.1 + 0.5 * shown + gone * 0.6))),
			ImageTransparency: glowK.map(([shown, gone]) => clamp01(1 - shown * (1 - gone))),
			Image: Art.BootCoreGlow,
			BackgroundTransparency: 1,
			ZIndex: 3,
		});
		// the clock, back to front: the movement (set back and dimmed so the hands read), the dial, then the hands.
		// The great wheel and the small wheel mesh (centres one pitch apart); the escape wheel sits under XII.
		const movementTint = Color3.fromRGB(150, 140, 126);
		const wheel = ring("BootWheel", Art.ClockWheel, D * 0.42, wheelAngle, phase(0.25, 0.8, 0.1, 0.5), 90, 0.25, 4, 1, [-0.13, 0.1], movementTint);
		const pinion = ring("BootPinion", Art.ClockPinion, D * 0.26, pinionAngle, phase(0.3, 0.8, 0.1, 0.5), -120, 0.25, 4, 1, [0.151, -0.031], movementTint);
		const escapeWheel = ring("BootEscape", Art.ClockEscape, D * 0.2, escapeAngle, phase(0.35, 0.8, 0.1, 0.5), 60, 0.25, 4, 1, [0.02, -0.25], movementTint);
		const dial = ring("BootDial", Art.ClockDial, D, still, phase(0.2, 0.8, 0.05, 0.55), 20, 0.3, 5);
		const hourHand = ring("BootHourHand", Art.ClockHour, D, hourAngle, phase(0.5, 0.75, 0, 0.6, true), 305, 0.3, 6);
		const minuteHand = ring("BootMinuteHand", Art.ClockMinute, D, minuteAngle, phase(0.55, 0.75, 0, 0.6, true), 420, 0.3, 7);
		const secondHand = ring("BootSecondHand", Art.ClockSecond, D, secondAngle, phase(0.62, 0.7, 0, 0.6, true), 180, 0.3, 8);
		const arbor = ring("BootArbor", Art.ClockCap, D * 0.07, still, phase(0.6, 0.5, 0, 0.6), 0, 0.3, 9);
		const shock = e("imagelabel", {
			Name: "BootRipple",
			AnchorPoint: new Vector2(0.5, 0.5),
			Position: new UDim2(0.5, 0, 0, centreY),
			Size: exitClock.map((x) => {
				const k = easeOut(clamp01((x - 0.12) / 0.8));
				return UDim2.fromOffset(D * (0.5 + 2.4 * k), D * (0.5 + 2.4 * k));
			}),
			ImageTransparency: exitClock.map((x) => (exiting && x > 0.12 ? clamp01(0.1 + easeIn(clamp01((x - 0.12) / 0.8)) * 0.9) : 1)),
			Image: Art.BootShockwave,
			BackgroundTransparency: 1,
			ZIndex: 7,
		});

		// the wordmark above the dial; it rises into place, and lifts away on the way out
		const wordK = phase(0.6, 0.7, 0, 0.45);
		const wordTop = math.max(16, centreY - D / 2 - L.wordH - (L.short ? 10 : 26));
		const wordmark = e("imagelabel", {
			Name: "BootWordmark",
			AnchorPoint: new Vector2(0.5, 0),
			Position: wordK.map(([shown, gone]) => new UDim2(0.5, 0, 0, wordTop + (1 - shown) * 14 - gone * 18)),
			Size: UDim2.fromOffset(L.column, L.wordH),
			BackgroundTransparency: 1,
			Image: BrandArt.WORDMARK_ASSET,
			ImageTransparency: wordK.map(([shown, gone]) => clamp01(1 - shown * (1 - gone))),
			ScaleType: Enum.ScaleType.Fit,
			ZIndex: 6,
		});

		// under the dial: the status line types itself in letter by letter, the percent counts beneath it
		const textK = phase(0.9, 0.5, 0, 0.35);
		const statusTop = centreY + D / 2 + (L.short ? 10 : 22);
		const statusRow = e("textlabel", {
			Name: "BootStatus",
			AnchorPoint: new Vector2(0.5, 0),
			Position: new UDim2(0.5, 0, 0, statusTop),
			Size: UDim2.fromOffset(L.column, 22),
			BackgroundTransparency: 1,
			RichText: true,
			Text: status,
			TextColor3: Palette.cream,
			TextTransparency: textK.map(([shown, gone]) => clamp01(1 - shown * (1 - gone))),
			TextSize: L.statusSize,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment: Enum.TextXAlignment.Center,
			ZIndex: 7,
		});
		const percentRow = e("textlabel", {
			Name: "BootPercent",
			AnchorPoint: new Vector2(0.5, 0),
			Position: new UDim2(0.5, 0, 0, statusTop + 26),
			Size: UDim2.fromOffset(L.column, 16),
			BackgroundTransparency: 1,
			Text: percentText,
			TextColor3: Palette.brass,
			TextTransparency: textK.map(([shown, gone]) => clamp01(1 - shown * (1 - gone) * 0.85)),
			TextSize: 12,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment: Enum.TextXAlignment.Center,
			ZIndex: 7,
		});

		const tipText = stalled ? "Still loading. Your save is safe." : (LOADING_TIPS[tipIndex - 1] ?? "");
		const tip = e("textlabel", {
			Name: "BootTip",
			AnchorPoint: new Vector2(0.5, 0),
			Position: new UDim2(0.5, 0, 0, L.tipY),
			Size: UDim2.fromOffset(L.column, L.tipH),
			BackgroundTransparency: 1,
			Text: tipText,
			TextColor3: Palette.muted,
			TextTransparency: React.joinBindings({ k: textK as never, t: tipIn }).map((v) => {
				const [shown, gone] = v.k as [number, number];
				return clamp01(1 - shown * (1 - gone) * (v.t as number));
			}),
			TextSize: L.tipSize,
			TextWrapped: true,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment: Enum.TextXAlignment.Center,
			TextYAlignment: Enum.TextYAlignment.Top,
			ZIndex: 6,
		});

		// the room itself: solid ink until the outro dissolves it
		return e(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.ink,
				BackgroundTransparency: exitClock.map((x) => (exiting ? easeIn(clamp01((x - 0.45) / 0.65)) : 0)),
				BorderSizePixel: 0,
				Active: !exiting,
				ZIndex: 420,
			},
			backdrop,
			glow,
			wheel,
			pinion,
			escapeWheel,
			dial,
			hourHand,
			minuteHand,
			secondHand,
			arbor,
			shock,
			wordmark,
			statusRow,
			percentRow,
			tip,
			_version !== undefined &&
				e("textlabel", {
					Size: UDim2.fromOffset(160, 14),
					Position: new UDim2(1, -16, 1, -14),
					AnchorPoint: new Vector2(1, 1),
					BackgroundTransparency: 1,
					Text: `v${_version}`,
					TextColor3: Palette.line,
					TextTransparency: textK.map(([shown, gone]) => clamp01(1 - shown * (1 - gone))),
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
