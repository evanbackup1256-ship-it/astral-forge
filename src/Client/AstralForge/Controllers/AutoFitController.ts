// LayoutGuard adaptive fit driver. Runs client-side for every player (Studio and live servers).
// Logic lives in ../LayoutGuard/fit (optimizer, loop, adapter); this controller decides *when*.
//
// Hosts: page scaffolds tag their ScrollingFrame "AutoFit" (any GuiObject tagged AutoFit opts in);
// ScrollingFrames with a layout inside a tagged host are fitted too, so inner lists adapt as well.
// Triggers (debounced): host window/canvas size (resize, content, locale), camera viewport,
// TopbarInset/safe insets, input kind (touch/gamepad/mouse). A Heartbeat connection exists only
// while the queue has work, and each frame spends at most BUDGET seconds. Idle = no per-frame cost.
// Kill switch: Workspace or LocalPlayer attribute LayoutAutoFit = false restores every value.
import { Controller, OnStart } from "@flamework/core";
import { ClientLog } from "../CoreKit/log";
import { HostRefs, apply, discover, penalty, read, restore } from "../LayoutGuard/fit/adapter";
import { FitLoop, contextKey, deviceClass } from "../LayoutGuard/fit/loop";
import { InputKind, knobsKey } from "../LayoutGuard/fit/optimizer";

const CollectionService = game.GetService("CollectionService");
const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

const TAG = "AutoFit";
const IS_STUDIO = RunService.IsStudio();
const DEBOUNCE = 0.3;
const VERIFY_DELAY = 0.12;
const SELF_CHANGE_GRACE = 0.25;
const BUDGET = 0.0008;
const MAX_NESTED = 8;
const REPORT_EVERY = 10;

interface HostEntry {
	id: string;
	refs: HostRefs | undefined;
	connections: RBXScriptConnection[];
	queued: boolean;
	verifyBefore: number | undefined;
	quietUntil: number;
	token: number;
	nested: boolean;
}

const fitStats = { hosts: 0, scans: 0, applied: 0, kept: 0, rolledBack: 0, reused: 0, lastFrameMs: 0, enabled: true };

export function autoFitStats() {
	return fitStats;
}

function inputKind(): InputKind {
	const t = UserInputService.GetLastInputType();
	if (t === Enum.UserInputType.Touch) return "touch";
	if (t.Name.sub(1, 7) === "Gamepad") return "gamepad";
	if (t === Enum.UserInputType.Keyboard || t.Name.sub(1, 5) === "Mouse") return "mouse";
	return UserInputService.TouchEnabled && !UserInputService.MouseEnabled ? "touch" : "mouse";
}

function uiScaleOf(inst: Instance): number {
	let scale = 1;
	let node: Instance | undefined = inst;
	while (node !== undefined) {
		const s = node.FindFirstChildOfClass("UIScale");
		if (s !== undefined) scale *= s.Scale;
		if (node.IsA("LayerCollector")) break;
		node = node.Parent;
	}
	return scale;
}

@Controller({ loadOrder: 3 })
export class AutoFitController implements OnStart {
	private loop = new FitLoop();
	private hosts = new Map<GuiObject, HostEntry>();
	private queue: GuiObject[] = [];
	private pump: RBXScriptConnection | undefined;
	private globals: RBXScriptConnection[] = [];
	private enabled = false;
	private input: InputKind = "mouse";
	private nextId = 0;
	private lastReport = -math.huge;
	private pendingReport = false;

	onStart() {
		const gate = () => this.updateEnabled();
		Workspace.GetAttributeChangedSignal("LayoutAutoFit").Connect(gate);
		const player = Players.LocalPlayer;
		if (player !== undefined) player.GetAttributeChangedSignal("LayoutAutoFit").Connect(gate);
		this.updateEnabled();
	}

	private wanted(): boolean {
		// off by default: the design layouts render as authored. LayoutAutoFit = true (Workspace or player) opts in.
		if (Workspace.GetAttribute("LayoutAutoFit") === true) return true;
		const player = Players.LocalPlayer;
		return player !== undefined && player.GetAttribute("LayoutAutoFit") === true;
	}

	private updateEnabled() {
		const want = this.wanted();
		if (want === this.enabled) return;
		this.enabled = want;
		fitStats.enabled = want;
		if (want) this.start();
		else this.stop();
	}

	private start() {
		this.input = inputKind();
		this.globals.push(CollectionService.GetInstanceAddedSignal(TAG).Connect((inst) => this.track(inst, false)));
		this.globals.push(CollectionService.GetInstanceRemovedSignal(TAG).Connect((inst) => this.untrack(inst as GuiObject)));
		for (const inst of CollectionService.GetTagged(TAG)) this.track(inst, false);
		this.globals.push(
			UserInputService.LastInputTypeChanged.Connect(() => {
				const kind = inputKind();
				if (kind !== this.input) {
					this.input = kind;
					this.dirtyAll();
				}
			}),
		);
		const camera = Workspace.CurrentCamera;
		if (camera !== undefined) this.globals.push(camera.GetPropertyChangedSignal("ViewportSize").Connect(() => this.dirtyAll()));
		const [ok] = pcall(() => {
			this.globals.push(GuiService.GetPropertyChangedSignal("TopbarInset").Connect(() => this.dirtyAll()));
		});
		if (!ok) ClientLog.debug("AutoFit", "TopbarInset signal unavailable");
		ClientLog.debug("AutoFit", "on");
	}

	private stop() {
		for (const c of this.globals) c.Disconnect();
		this.globals.clear();
		for (const [inst] of this.hosts) this.untrack(inst);
		this.queue.clear();
		this.pump?.Disconnect();
		this.pump = undefined;
		this.loop.reset();
		ClientLog.debug("AutoFit", "off (LayoutAutoFit=false); design values restored");
	}

	private track(inst: Instance, nested: boolean) {
		if (!inst.IsA("GuiObject") || this.hosts.has(inst)) return;
		this.nextId += 1;
		const entry: HostEntry = { id: `${inst.Name}#${this.nextId}`, refs: undefined, connections: [], queued: false, verifyBefore: undefined, quietUntil: 0, token: 0, nested };
		this.hosts.set(inst, entry);
		fitStats.hosts = this.hosts.size();
		const dirty = () => {
			if (os.clock() < entry.quietUntil) return;
			this.markDirty(inst);
		};
		if (inst.IsA("ScrollingFrame")) {
			entry.connections.push(inst.GetPropertyChangedSignal("AbsoluteWindowSize").Connect(dirty));
			entry.connections.push(inst.GetPropertyChangedSignal("AbsoluteCanvasSize").Connect(dirty));
		} else {
			entry.connections.push(inst.GetPropertyChangedSignal("AbsoluteSize").Connect(dirty));
		}
		entry.connections.push(
			inst.DescendantAdded.Connect((d) => {
				if (d.IsA("UIGridLayout") || d.IsA("UIListLayout")) {
					entry.refs = undefined;
					dirty();
				}
			}),
		);
		entry.connections.push(inst.AncestryChanged.Connect(() => {
			if (!inst.IsDescendantOf(game)) this.untrack(inst);
		}));
		this.markDirty(inst);
	}

	private untrack(inst: GuiObject) {
		const entry = this.hosts.get(inst);
		if (entry === undefined) return;
		for (const c of entry.connections) c.Disconnect();
		if (entry.refs !== undefined) restore(entry.refs);
		this.loop.forget(entry.id);
		this.hosts.delete(inst);
		fitStats.hosts = this.hosts.size();
	}

	private dirtyAll() {
		for (const [inst] of this.hosts) this.markDirty(inst);
	}

	/** debounced: the host is processed once it has been quiet for DEBOUNCE seconds */
	private markDirty(inst: GuiObject, delay = DEBOUNCE) {
		const entry = this.hosts.get(inst);
		if (entry === undefined || !this.enabled) return;
		entry.token += 1;
		const token = entry.token;
		task.delay(delay, () => {
			if (entry.token !== token || !this.enabled || !this.hosts.has(inst)) return;
			this.enqueue(inst);
		});
	}

	private enqueue(inst: GuiObject) {
		const entry = this.hosts.get(inst);
		if (entry === undefined || entry.queued) return;
		entry.queued = true;
		this.queue.push(inst);
		if (this.pump === undefined) this.pump = RunService.Heartbeat.Connect(() => this.drain());
	}

	private drain() {
		const started = os.clock();
		while (this.queue.size() > 0 && os.clock() - started < BUDGET) {
			const inst = this.queue.shift()!;
			const entry = this.hosts.get(inst);
			if (entry === undefined) continue;
			entry.queued = false;
			const [ok, err] = pcall(() => this.process(inst, entry));
			if (!ok) ClientLog.debug("AutoFit", `host ${entry.id} failed: ${tostring(err)}`);
		}
		fitStats.lastFrameMs = math.floor((os.clock() - started) * 100000) / 100;
		if (this.queue.size() === 0) {
			this.pump?.Disconnect();
			this.pump = undefined;
		}
	}

	private context(inst: GuiObject) {
		const camera = Workspace.CurrentCamera;
		const vp = camera !== undefined ? camera.ViewportSize : new Vector2(1280, 720);
		const scale = uiScaleOf(inst);
		return { key: contextKey(deviceClass(vp.X, vp.Y, this.input), vp.X, vp.Y, this.input, scale), input: this.input };
	}

	private process(inst: GuiObject, entry: HostEntry) {
		if (!inst.IsA("ScrollingFrame")) {
			// a tagged non-scrolling container: fit the scrolling hosts inside it
			for (const d of inst.GetDescendants()) if (d.IsA("ScrollingFrame") && d.FindFirstChildWhichIsA("UIGridLayout") !== undefined) this.track(d, true);
			return;
		}
		if (entry.refs === undefined) {
			entry.refs = discover(inst);
			if (!entry.nested) {
				let nested = 0;
				for (const d of inst.GetDescendants()) {
					if (nested >= MAX_NESTED) break;
					if (d.IsA("ScrollingFrame") && (d.FindFirstChildOfClass("UIGridLayout") !== undefined || d.FindFirstChildOfClass("UIListLayout") !== undefined)) {
						nested += 1;
						this.track(d, true);
					}
				}
			}
		}
		const refs = entry.refs;
		fitStats.scans += 1;
		if (entry.verifyBefore !== undefined) {
			const before = entry.verifyBefore;
			entry.verifyBefore = undefined;
			const after = penalty(refs, this.input);
			const verdict = this.loop.verify(entry.id, before, after);
			if (verdict === "rollback") {
				const back = this.loop.restore(entry.id);
				entry.quietUntil = os.clock() + SELF_CHANGE_GRACE;
				if (back !== undefined) apply(refs, back, this.input);
				fitStats.rolledBack += 1;
				this.note(`${entry.id}: rolled back a fit that made layout worse (${before} -> ${after})`);
			} else if (verdict === "keep") {
				fitStats.kept += 1;
			}
			return;
		}
		const ctx = this.context(inst);
		const container = read(refs, entry.id, ctx.input, this.loop.applied(entry.id));
		const before = penalty(refs, ctx.input);
		const knobs = this.loop.plan(container, ctx, os.clock());
		if (knobs === undefined) return;
		entry.quietUntil = os.clock() + SELF_CHANGE_GRACE;
		apply(refs, knobs, ctx.input);
		fitStats.applied += 1;
		fitStats.reused = this.loop.stats.reused;
		entry.verifyBefore = before;
		this.markDirty(inst, VERIFY_DELAY);
		this.note(`${entry.id}: ${knobsKey(knobs)} (${ctx.key})`);
	}

	/** Studio: one grouped summary line at most every REPORT_EVERY seconds. Live servers: silent. */
	private note(detail: string) {
		ClientLog.debug("AutoFit", detail);
		if (!IS_STUDIO || this.pendingReport) return;
		const wait = math.max(0, this.lastReport + REPORT_EVERY - os.clock());
		this.pendingReport = true;
		task.delay(wait, () => {
			this.pendingReport = false;
			this.lastReport = os.clock();
			print(`[LayoutGuard] AutoFit: ${fitStats.hosts} hosts, ${fitStats.applied} fits applied, ${fitStats.kept} kept, ${fitStats.rolledBack} rolled back, ${this.loop.memorySize()} remembered (LayoutAutoFit=false turns it off)`);
		});
	}
}
