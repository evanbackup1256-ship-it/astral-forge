// LayoutGuard 2: event-driven layout checker. The heavy lifting is in ../LayoutGuard (pure
// geometry, layout emulation, spatial index, rules, engine); this controller only decides *when*
// to scan, runs the scan as a frame-budgeted coroutine, and routes results to the log, the debug
// overlay, scoped recovery and the diagnostics endpoint.
//
// Modes
//   full  default in Studio (set ReplicatedStorage AstralLayoutGuard = false to silence it).
//   off   default in live servers outside the sample. No connections beyond attribute listeners; zero per-frame cost.
//   full  ReplicatedStorage AstralLayoutGuard / AstralDebugLogs = true, or Workspace LayoutDebug
//         set. All rules, overlay when LayoutDebug, device matrix when LayoutDebug = "matrix" or
//         AstralLayoutGuardMatrix = true.
//   lite  live servers only, for a deterministic sample of players (AstralLayoutGuardSample,
//         default 2%): cheap rules, at most one scan per 30 s, small node cap, errors only.
//
// Scheduling: DescendantAdded/Removing under PlayerGui, root/viewport size and the toggles mark
// the UI dirty; a scan starts after `QUIET` seconds without further changes. While findings wait
// for confirmation a follow-up scan is scheduled; full mode also rescans every SAFETY_RESCAN
// seconds to see property-only changes (tweens settle, text changes). A Heartbeat connection exists
// only while a scan is running.
import { Controller, OnInit, OnStart } from "@flamework/core";
import { ClientLog } from "../CoreKit/log";
import { UiRootRegistry } from "./UiRootRegistry";
import Diagnostics = require("../LayoutDiagnostics");
import { whitespaceContainers, layoutDebugEnabled } from "../UiCore/layoutEngine";
import { capture, Captured, OVERLAY_NAME } from "../LayoutGuard/capture";
import { DEFAULT_OPTIONS, Tracked, Tracker, inSample, parseConfig, runRules } from "../LayoutGuard/engine";
import { GroupedLogger } from "../LayoutGuard/logger";
import { measure, measureStats } from "../LayoutGuard/measure";
import { MATRIX_RULES } from "../LayoutGuard/rules";
import { runMatrix, summarizeMatrix } from "../LayoutGuard/matrix";
import { Overlay } from "../LayoutGuard/overlay";
import { recover, recoveryStats } from "../LayoutGuard/recovery";
import { Report, buildReport, reportText } from "../LayoutGuard/report";
import { autoFitStats } from "./AutoFitController";
import { Finding, Profile, RuleConfig, Snapshot } from "../LayoutGuard/types";

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const Workspace = game.GetService("Workspace");

const IS_STUDIO = RunService.IsStudio();
const QUIET = 0.35;
const CONFIRM_DELAY = 0.5;
const MAX_CONFIRM_RESCANS = 4;
const SAFETY_RESCAN = 5;
const LITE_MIN_INTERVAL = 30;
const BUDGET_FULL = IS_STUDIO ? 0.0015 : 0.0005;
const BUDGET_LITE = 0.00025;
const MAX_NODES_FULL = 6000;
const MAX_NODES_LITE = 1500;
const DEFAULT_SAMPLE = IS_STUDIO ? 0 : 0.02;
const ROOT_ID = "client/framework/init@UiRootComponent";

type Mode = "off" | Profile;

interface UiRootComponent {
	instance: GuiObject;
}
interface ComponentsApi {
	onComponentAdded(callback: (component: UiRootComponent) => unknown, id: string): void;
	getAllComponents(id: string): UiRootComponent[];
}
interface RuntimeApi {
	primary(): UiRootComponent | undefined;
}

const diagnostics = Diagnostics.new(os.clock);
const stats = {
	scans: 0,
	liteScans: 0,
	nodes: 0,
	findings: 0,
	confirmed: 0,
	logged: 0,
	resolved: 0,
	ruleFailures: 0,
	truncated: 0,
	matrixRuns: 0,
	lastScanMs: 0,
	lastScanFrames: 0,
	measureHits: 0,
	measureMisses: 0,
	canvasFixed: 0,
	panelsNudged: 0,
};

function attr(name: string): unknown {
	return ReplicatedStorage.GetAttribute(name);
}

function wantedMode(userId: number): Mode {
	if (attr("AstralLayoutGuard") === true || attr("AstralDebugLogs") === true) return "full";
	// Studio: on by default so layout problems show up in Output while playtesting
	if (IS_STUDIO && attr("AstralLayoutGuard") !== false) return "full";
	const debug = Workspace.GetAttribute("LayoutDebug");
	if (debug !== undefined && debug !== false && debug !== "") return "full";
	const sample = attr("AstralLayoutGuardSample");
	const rate = typeIs(sample, "number") ? sample : DEFAULT_SAMPLE;
	return inSample(userId, rate) ? "lite" : "off";
}

const reportListeners: Array<(report: Report) => void> = [];
// the Flamework singleton, for the module-level admin hooks below
let instance: { report(): Report } | undefined;

@Controller({ loadOrder: 2 })
class LayoutGuardController implements OnInit, OnStart {
	components: ComponentsApi;
	runtime: RuntimeApi | undefined;
	target: UiRootComponent | undefined;
	diagnosticEndpoint: BindableFunction | undefined;
	mode: Mode = "off";
	private configs = new Map<string, RuleConfig>();
	private configErrors: string[] = [];
	private tracker = new Tracker(DEFAULT_OPTIONS);
	private logger = new GroupedLogger((level, line) => this.sink(level, line), os.clock());
	private overlay: Overlay | undefined;
	private watch: RBXScriptConnection[] = [];
	private gateConnections: RBXScriptConnection[] = [];
	private generation = 0;
	private scanning = false;
	private rerun = false;
	private confirmRescans = 0;
	private lastScanAt = -math.huge;
	private lastSnap: Snapshot | undefined;
	private lastCapture: Captured | undefined;
	private active: Tracked[] = [];
	private matrix: Finding[] = [];
	private safetyThread: thread | undefined;

	constructor(registry: UiRootRegistry) {
		this.components = registry;
		this.runtime = registry;
		instance = this;
	}

	onInit() {
		this.reloadConfig();
	}

	onStart() {
		this.components.onComponentAdded((component) => {
			this.target = component;
			this.bindRoot(component.instance);
			return this.target;
		}, ROOT_ID);
		const existing = this.components.getAllComponents(ROOT_ID)[0];
		if (existing !== undefined) {
			this.target = existing;
			this.bindRoot(existing.instance);
		}
		const gate = () => this.updateMode();
		for (const name of ["AstralLayoutGuard", "AstralDebugLogs", "AstralLayoutGuardSample", "AstralLayoutGuardMatrix"]) {
			this.gateConnections.push(ReplicatedStorage.GetAttributeChangedSignal(name).Connect(gate));
		}
		this.gateConnections.push(ReplicatedStorage.GetAttributeChangedSignal("LayoutGuardRules").Connect(() => this.reloadConfig()));
		this.gateConnections.push(
			Workspace.GetAttributeChangedSignal("LayoutDebug").Connect(() => {
				this.updateMode();
				if (!layoutDebugEnabled() && Workspace.GetAttribute("LayoutDebug") === undefined) this.overlay?.destroy();
				this.markDirty();
			}),
		);
		this.updateMode();
	}

	private reloadConfig() {
		const spec = attr("LayoutGuardRules");
		const [configs, errors] = parseConfig(typeIs(spec, "string") ? spec : undefined);
		this.configs = configs;
		this.configErrors = errors;
		for (const e of errors) ClientLog.warnEvery("layoutguard-config " + e, 60, "LayoutGuard", `LayoutGuardRules: ${e}`);
		this.markDirty();
	}

	private playerGui(): PlayerGui | undefined {
		const player = Players.LocalPlayer;
		return player !== undefined ? (player.FindFirstChildOfClass("PlayerGui") as PlayerGui | undefined) : undefined;
	}

	private updateMode() {
		const player = Players.LocalPlayer;
		const wanted = wantedMode(player !== undefined ? player.UserId : 0);
		if (wanted === this.mode) return;
		const previous = this.mode;
		this.mode = wanted;
		this.unwatch();
		if (wanted === "off") {
			this.overlay?.destroy();
			this.overlay = undefined;
			this.tracker.clear();
			this.active = [];
			ClientLog.debug("LayoutGuard", `off (was ${previous})`);
			return;
		}
		this.watchUi();
		ClientLog.debug("LayoutGuard", `${wanted} mode`, { rules: this.enabledRuleCount() });
		this.markDirty();
	}

	private enabledRuleCount(): number {
		let n = 0;
		for (const [, c] of this.configs) if (c.enabled) n += 1;
		return n;
	}

	bindRoot(root: GuiObject | undefined): undefined {
		if (root === undefined) return undefined;
		if (this.mode !== "off") {
			this.unwatch();
			this.watchUi();
		}
		this.ensureEndpoint(root);
		this.markDirty();
		return undefined;
	}

	private ensureEndpoint(root: Instance) {
		if (this.diagnosticEndpoint !== undefined && this.diagnosticEndpoint.Parent !== undefined) return;
		const playerGui = root.FindFirstAncestorOfClass("PlayerGui");
		const endpoint = new Instance("BindableFunction");
		endpoint.Name = "AstralForgeLayoutDiagnostics";
		endpoint.OnInvoke = (command?: unknown) => {
			if (command === "rescan") {
				this.markDirty(0);
				return true;
			}
			const report = this.report();
			if (command === "text") return reportText(report);
			return {
				Diagnostics: diagnostics.snapshot(),
				Stats: table.clone(stats),
				Tracked: this.tracker.size(),
				Mode: this.mode,
				Report: report,
				ConfigErrors: [...this.configErrors],
			};
		};
		// React owns root descendants and removes children created before mounting.
		endpoint.Parent = playerGui ?? root;
		this.diagnosticEndpoint = endpoint;
		root.Destroying.Once(() => {
			if (this.diagnosticEndpoint === endpoint) this.diagnosticEndpoint = undefined;
			endpoint.Destroy();
		});
	}

	private watchUi() {
		const playerGui = this.playerGui();
		if (playerGui === undefined) return;
		const relevant = (inst: Instance) => inst.IsA("GuiObject") || inst.IsA("UIComponent") || inst.IsA("LayerCollector");
		const ours = (inst: Instance) => inst.Name === OVERLAY_NAME || inst.Name === "WhitespaceDebug" || inst.FindFirstAncestor(OVERLAY_NAME) !== undefined;
		this.watch.push(
			playerGui.DescendantAdded.Connect((inst) => {
				if (relevant(inst) && !ours(inst)) this.markDirty();
			}),
		);
		this.watch.push(
			playerGui.DescendantRemoving.Connect((inst) => {
				if (relevant(inst) && !ours(inst)) this.markDirty();
			}),
		);
		const camera = Workspace.CurrentCamera;
		if (camera !== undefined) this.watch.push(camera.GetPropertyChangedSignal("ViewportSize").Connect(() => this.markDirty()));
		const root = this.target?.instance;
		if (root !== undefined) this.watch.push(root.GetPropertyChangedSignal("AbsoluteSize").Connect(() => this.markDirty()));
		if (this.mode === "full") {
			const generation = this.generation;
			this.safetyThread = task.spawn(() => {
				while (this.mode === "full" && generation === this.generation) {
					task.wait(SAFETY_RESCAN);
					if (this.mode === "full" && generation === this.generation && !this.scanning) this.startScan();
				}
			});
		}
	}

	private unwatch() {
		for (const c of this.watch) c.Disconnect();
		this.watch.clear();
		this.generation += 1;
		if (this.safetyThread !== undefined && coroutine.status(this.safetyThread) === "suspended") task.cancel(this.safetyThread);
		this.safetyThread = undefined;
	}

	/** Debounced scan request: the scan runs once changes have been quiet for `delay` seconds. */
	markDirty(delay = QUIET) {
		if (this.mode === "off") return;
		this.generation += 1;
		const generation = this.generation;
		this.confirmRescans = 0;
		task.delay(delay, () => {
			if (generation !== this.generation || this.mode === "off") return;
			this.startScan();
		});
	}

	private startScan() {
		if (this.scanning) {
			this.rerun = true;
			return;
		}
		const now = os.clock();
		if (this.mode === "lite" && now - this.lastScanAt < LITE_MIN_INTERVAL) {
			const wait = LITE_MIN_INTERVAL - (now - this.lastScanAt);
			const generation = this.generation;
			task.delay(wait, () => {
				if (generation === this.generation) this.startScan();
			});
			return;
		}
		const playerGui = this.playerGui();
		if (playerGui === undefined) return;
		this.scanning = true;
		this.lastScanAt = now;
		const profile: Profile = this.mode === "lite" ? "lite" : "full";
		const budget = profile === "lite" ? BUDGET_LITE : BUDGET_FULL;
		let deadline = os.clock() + budget;
		let frames = 1;
		let busy = 0;
		const step = () => {
			if (os.clock() >= deadline) {
				busy += os.clock() - (deadline - budget);
				coroutine.yield();
				deadline = os.clock() + budget;
				frames += 1;
			}
		};
		const work = coroutine.create(() => {
			this.scan(playerGui, profile, step);
		});
		const finish = (connection?: RBXScriptConnection) => {
			connection?.Disconnect();
			this.scanning = false;
			stats.lastScanMs = math.floor((busy + (os.clock() - (deadline - budget))) * 100000) / 100;
			stats.lastScanFrames = frames;
			if (this.rerun) {
				this.rerun = false;
				this.markDirty();
			}
		};
		const resume = (): boolean => {
			const [ok, err] = coroutine.resume(work);
			if (!ok) {
				ClientLog.warnEvery("layoutguard-scan", 15, "LayoutGuard", `scan failed: ${tostring(err)}`);
				return true;
			}
			return coroutine.status(work) === "dead";
		};
		if (resume()) {
			finish();
			return;
		}
		const connection = RunService.Heartbeat.Connect(() => {
			if (resume()) finish(connection);
		});
	}

	private scan(playerGui: PlayerGui, profile: Profile, step: () => void) {
		const wantMatrix = profile === "full" && (Workspace.GetAttribute("LayoutDebug") === "matrix" || attr("AstralLayoutGuardMatrix") === true);
		const cap = capture(playerGui, {
			maxNodes: profile === "lite" ? MAX_NODES_LITE : MAX_NODES_FULL,
			step,
			withVNodes: wantMatrix,
			whitespace: whitespaceContainers(),
		});
		const snap = cap.snap;
		if (cap.truncated) stats.truncated += 1;
		const pathOf = (id: number) => snap.byId.get(id)?.path ?? "?";
		const [findings, run] = runRules(snap, this.configs, profile, measure, step);
		for (const f of run.failures) ClientLog.warnEvery("layoutguard-rule " + f, 60, "LayoutGuard", `rule failed: ${f}`);
		const now = os.clock();
		const tracked = this.tracker.update(findings, snap, now, pathOf);
		this.active = tracked.active;
		this.lastSnap = snap;
		this.lastCapture = cap;
		stats.scans += 1;
		if (profile === "lite") stats.liteScans += 1;
		stats.nodes = snap.nodes.size();
		stats.findings = findings.size();
		stats.confirmed = tracked.active.size();
		stats.resolved += tracked.resolved.size();
		stats.ruleFailures += run.failures.size();
		stats.measureHits = measureStats.hits;
		stats.measureMisses = measureStats.misses;
		// lite mode only speaks up for errors; full mode logs warn+ (engine logMinSeverity)
		const toLog = profile === "lite" ? tracked.toLog.filter((f) => f.level === "error") : tracked.toLog;
		for (const f of toLog) {
			const inst = cap.instances.get(f.node);
			if (inst !== undefined) diagnostics.record(inst, f.rule, f.message);
		}
		stats.logged += this.logger.emit(toLog, pathOf, now);
		if (tracked.resolved.size() > 0 && profile === "full") ClientLog.debug("LayoutGuard", `${tracked.resolved.size()} reported issue(s) resolved`);
		const fixes = recover(snap, tracked.active.map((t) => t.finding), cap.instances);
		stats.canvasFixed = recoveryStats.canvasFixed;
		stats.panelsNudged = recoveryStats.panelsNudged;
		for (const fix of fixes) ClientLog.debug("LayoutGuard", `scoped recovery: ${fix}`);
		if (wantMatrix) {
			const results = runMatrix(
				snap,
				cap.roots,
				(s) => runRules(s, this.configs, "full", measure, step, MATRIX_RULES)[0],
				measure,
				undefined,
				step,
			);
			this.matrix = summarizeMatrix(results);
			stats.matrixRuns += 1;
			this.logger.emit(
				this.matrix.filter((f) => f.severity >= DEFAULT_OPTIONS.logMinSeverity),
				pathOf,
				now,
				"[matrix] ",
			);
		}
		if (profile === "full" && Workspace.GetAttribute("LayoutDebug") !== undefined && Workspace.GetAttribute("LayoutDebug") !== false) {
			this.overlay = this.overlay ?? new Overlay(playerGui);
			const debug = Workspace.GetAttribute("LayoutDebug");
			this.overlay.draw(
				tracked.active.map((t) => t.finding),
				snap.viewport.width,
				snap.viewport.height,
				debug === "heat" || debug === true,
				(f) => `${f.rule} ${f.message}`,
			);
		}
		if (tracked.pending > 0 && this.confirmRescans < MAX_CONFIRM_RESCANS) {
			this.confirmRescans += 1;
			const generation = this.generation;
			task.delay(CONFIRM_DELAY, () => {
				if (generation === this.generation) this.startScan();
			});
		}
		const report = this.report();
		for (const listener of reportListeners) task.spawn(listener, report);
	}

	private sink(level: string, line: string) {
		// Studio prints grouped warn+ lines to Output (each line at most once per 5 min); live servers stay quiet
		if (this.mode === "full" && (level === "error" || (IS_STUDIO && level === "warn"))) ClientLog.warnEvery("layoutguard " + line, 300, "LayoutGuard", line);
		else ClientLog.debug("LayoutGuard", line);
	}

	report(): Report {
		const snap = this.lastSnap;
		const pathOf = (id: number) => snap?.byId.get(id)?.path ?? "?";
		const s: Record<string, number> = {};
		for (const [k, v] of pairs(stats)) s[k as string] = v as number;
		for (const [k, v] of pairs(autoFitStats())) if (typeIs(v, "number")) s[`autoFit.${k}`] = v;
		return buildReport(snap, this.active, this.matrix, this.mode, s, pathOf);
	}

	/** instances behind the last report rows, for admin tooling that wants to select them */
	instanceFor(id: number): GuiObject | undefined {
		return this.lastCapture?.instances.get(id);
	}
}


function layoutGuardStats() {
	return stats;
}

/** Admin panel hook: latest report (undefined before the first scan or while off). */
function layoutGuardReport(): Report | undefined {
	return instance?.report();
}

/** Admin panel hook: called after every scan with the fresh report. Returns a disconnect. */
function onLayoutGuardReport(listener: (report: Report) => void): () => void {
	reportListeners.push(listener);
	return () => {
		const i = reportListeners.indexOf(listener);
		if (i !== -1) reportListeners.remove(i);
	};
}

export = {
	layoutGuardStats,
	layoutGuardDiagnostics: () => diagnostics.snapshot(),
	layoutGuardReport,
	onLayoutGuardReport,
	LayoutGuardController,
};
