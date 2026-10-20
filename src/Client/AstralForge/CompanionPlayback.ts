const RunService = game.GetService("RunService");
import { isReducedMotion } from "./MotionPreference";
const Workspace = game.GetService("Workspace");

interface Entry {
	Label: ImageLabel;
	Columns: number;
	Count: number;
	Frame: number;
	Rate: number;
	Size: Vector2;
}

const entries: Entry[] = [];
const active: Entry[] = [];
let connection: RBXScriptConnection | undefined;
let cursor = 1;
let clock = 0;
let elapsed = 0;
const MAX_LAYERS = 24;
const SCAN_BATCH = 64;
const SCAN_INTERVAL = 0.15;

function visible(label: ImageLabel): boolean {
	if (label.Parent === undefined || label.ImageTransparency >= 1) {
		return false;
	}
	const position = label.AbsolutePosition;
	const size = label.AbsoluteSize;
	let left = position.X;
	let top = position.Y;
	let right = left + size.X;
	let bottom = top + size.Y;
	if (size.X <= 0 || size.Y <= 0) {
		return false;
	}
	let ancestor: Instance | undefined = label;
	let screen: ScreenGui | undefined;
	while (ancestor) {
		if (ancestor.IsA("GuiObject")) {
			if (!ancestor.Visible) {
				return false;
			}
			if (ancestor.IsA("CanvasGroup") && ancestor.GroupTransparency >= 1) {
				return false;
			}
			if (ancestor.ClipsDescendants) {
				const p = ancestor.AbsolutePosition;
				const s = ancestor.AbsoluteSize;
				left = math.max(left, p.X);
				top = math.max(top, p.Y);
				right = math.min(right, p.X + s.X);
				bottom = math.min(bottom, p.Y + s.Y);
			}
		} else if (ancestor.IsA("LayerCollector")) {
			if (!ancestor.Enabled) {
				return false;
			}
			if (ancestor.IsA("ScreenGui")) {
				screen = ancestor;
			}
		}
		ancestor = ancestor.Parent;
	}
	// World companions have their own distance/frustum owner.
	if (screen === undefined || screen.Parent === undefined || !screen.Parent.IsA("PlayerGui")) {
		return false;
	}
	const camera = Workspace.CurrentCamera;
	if (camera === undefined) {
		return false;
	}
	const viewport = camera.ViewportSize;
	return right > math.max(left, 0) && bottom > math.max(top, 0) && left < viewport.X && top < viewport.Y;
}

function step(dt: number) {
	clock += dt;
	elapsed += dt;
	if (isReducedMotion()) {
		table.clear(active);
		return;
	}
	if (elapsed >= SCAN_INTERVAL) {
		elapsed %= SCAN_INTERVAL;
		for (let index = active.size() - 1; index >= 0; index--) {
			if (!Playback.visible(active[index].Label)) {
				active.remove(index);
			}
		}
		const checked = math.min(entries.size(), SCAN_BATCH);
		for (let i = 1; i <= checked; i++) {
			if (cursor > entries.size()) {
				cursor = 1;
			}
			const entry = entries[cursor - 1];
			cursor += 1;
			if (active.size() < MAX_LAYERS && !active.includes(entry) && Playback.visible(entry.Label)) {
				active.push(entry);
			}
		}
	}
	for (const entry of active) {
		if (Playback.visible(entry.Label)) {
			const frame = math.floor(clock * entry.Rate) % entry.Count;
			if (frame !== entry.Frame) {
				entry.Frame = frame;
				entry.Label.ImageRectOffset = new Vector2(
					(frame % entry.Columns) * entry.Size.X,
					math.floor(frame / entry.Columns) * entry.Size.Y,
				);
			}
		}
	}
}

function register(label: ImageLabel, columns: number, count: number, size: Vector2, rate: number) {
	assert(
		columns > 0 &&
			columns % 1 === 0 &&
			count > 0 &&
			count % 1 === 0 &&
			size.X > 0 &&
			size.Y > 0 &&
			size.X < math.huge &&
			size.Y < math.huge &&
			rate > 0 &&
			rate < math.huge,
		"Invalid companion animation",
	);
	const entry: Entry = { Label: label, Columns: columns, Count: count, Size: size, Rate: rate, Frame: -1 };
	entries.push(entry);
	if (connection === undefined) {
		elapsed = SCAN_INTERVAL;
		connection = RunService.RenderStepped.Connect(step);
	}
	let released = false;
	return {
		setRate: (nextRate: number) => {
			assert(nextRate > 0 && nextRate < math.huge, "Invalid companion animation rate");
			entry.Rate = nextRate;
		},
		release: () => {
			if (released) {
				return;
			}
			released = true;
			const index = entries.indexOf(entry);
			if (index !== -1) {
				entries.remove(index);
			}
			const activeIndex = active.indexOf(entry);
			if (activeIndex !== -1) {
				active.remove(activeIndex);
			}
			if (entries.size() === 0 && connection) {
				connection.Disconnect();
				connection = undefined;
				cursor = 1;
				clock = 0;
				elapsed = 0;
			}
		},
	};
}

function snapshot() {
	return { Registered: entries.size(), Active: active.size(), Limit: MAX_LAYERS, Connected: connection !== undefined };
}

const Playback = { visible, register, snapshot };

export = Playback;
