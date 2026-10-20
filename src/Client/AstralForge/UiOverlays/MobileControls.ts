import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { useExitTransition, useFlipperSpring, usePulse, useViewport } from "../MotionKit/motion";
import { EDIT_BOUNDS } from "../CoreKit/mobileLayout";
import { chromeFor, Palette, TapTarget, surfaceGradient } from "../CoreKit/theme";
import { Button, Text } from "../UiCore/ui";
import { asFlux, compactNumber } from "../CoreKit/format";
import { Audio } from "../AudioKit/audio";

const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

// Props stay as loose tables, exactly as the Luau controls built them.
const h = React.createElement as unknown as (component: unknown, props?: unknown, ...children: unknown[]) => React.Element;
const btn = (props: object) => h(Button, props);
const text = (props: object) => h(Text, props);

interface Bounds {
	minX: number;
	maxX: number;
	minY: number;
	maxY: number;
}
interface DragHandle {
	id: string;
	position: Vector2;
	bounds: Bounds;
	snap?: number;
	onMove?: (position: Vector2) => void;
}

const dragHandles = new Map<string, DragHandle>();
let editMode = false;
let dragId: string | undefined;
let dragInput: InputObject | undefined;
let dragOffset = Vector2.zero;
let dragLastCell = Vector2.zero;
let dragChanged: RBXScriptConnection | undefined;
let dragEnded: RBXScriptConnection | undefined;
let dragFocusReleased: RBXScriptConnection | undefined;
let dragMenuOpened: RBXScriptConnection | undefined;

function cancelDrag() {
	dragId = undefined;
	dragInput = undefined;
}
function clampDrag(pos: Vector2, bounds: Bounds): Vector2 {
	return new Vector2(math.clamp(pos.X, bounds.minX, bounds.maxX), math.clamp(pos.Y, bounds.minY, bounds.maxY));
}
function ensureDragging() {
	if (dragChanged !== undefined) {
		return undefined;
	}
	dragChanged = UserInputService.InputChanged.Connect((input) => {
		if (!editMode || dragId === undefined || dragInput === undefined) {
			return undefined;
		}
		if (dragInput.UserInputType === Enum.UserInputType.Touch) {
			if (input !== dragInput) {
				return undefined;
			}
		} else if (dragInput.UserInputType === Enum.UserInputType.MouseButton1) {
			if (input.UserInputType !== Enum.UserInputType.MouseMovement) {
				return undefined;
			}
		} else {
			return undefined;
		}
		const handle = dragHandles.get(dragId);
		if (handle === undefined) {
			return undefined;
		}
		const raw = new Vector2(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y);
		const grid = math.max(1, handle.snap ?? 1);
		const cellX = math.round(raw.X / grid);
		const cellY = math.round(raw.Y / grid);
		const resolvedPosition = clampDrag(new Vector2(cellX * grid, cellY * grid), handle.bounds);
		handle.position = resolvedPosition;
		handle.onMove?.(resolvedPosition);
		if (cellX !== dragLastCell.X || cellY !== dragLastCell.Y) {
			dragLastCell = new Vector2(cellX, cellY);
			Audio.play("dragSnap");
		}
	});
	dragEnded = UserInputService.InputEnded.Connect((input) => {
		if (dragInput === undefined) {
			return undefined;
		}
		const exactTouch = dragInput.UserInputType === Enum.UserInputType.Touch && input === dragInput;
		const mouseRelease =
			dragInput.UserInputType === Enum.UserInputType.MouseButton1 &&
			input.UserInputType === Enum.UserInputType.MouseButton1;
		if (exactTouch || mouseRelease) {
			if (dragId !== undefined) {
				Audio.play("dragDrop");
			}
			cancelDrag();
		}
	});
	dragFocusReleased = UserInputService.WindowFocusReleased.Connect(cancelDrag);
	dragMenuOpened = GuiService.MenuOpened.Connect(cancelDrag);
}

const MobileDragging = {
	setEditMode(on: boolean) {
		editMode = on;
		if (!on) {
			cancelDrag();
		}
		ensureDragging();
	},
	register(handle: DragHandle) {
		ensureDragging();
		dragHandles.set(handle.id, handle);
		return () => {
			dragHandles.delete(handle.id);
			if (dragId === handle.id) {
				cancelDrag();
			}
		};
	},
	beginDrag(id: string, input: InputObject) {
		if (!editMode) {
			return undefined;
		}
		const handle = dragHandles.get(id);
		if (handle === undefined) {
			return undefined;
		}
		Audio.play("dragGrab");
		dragId = id;
		dragInput = input;
		dragOffset = new Vector2(input.Position.X - handle.position.X, input.Position.Y - handle.position.Y);
		const grid = math.max(1, handle.snap ?? 1);
		dragLastCell = new Vector2(math.round(handle.position.X / grid), math.round(handle.position.Y / grid));
	},
	setPosition(id: string, pos: Vector2) {
		const handle = dragHandles.get(id);
		if (handle === undefined) {
			return undefined;
		}
		handle.position = clampDrag(pos, handle.bounds);
		handle.onMove?.(handle.position);
	},
	dispose() {
		dragChanged?.Disconnect();
		dragEnded?.Disconnect();
		dragFocusReleased?.Disconnect();
		dragMenuOpened?.Disconnect();
		dragChanged = undefined;
		dragEnded = undefined;
		dragFocusReleased = undefined;
		dragMenuOpened = undefined;
		dragHandles.clear();
		cancelDrag();
		editMode = false;
	},
};

interface Slot {
	id: string;
	label?: string;
	x: number;
	y: number;
	width?: number;
	height?: number;
	anchorX?: number;
	anchorY?: number;
	safeTop?: number;
	xKey: string;
	yKey: string;
	defaultX: number;
	defaultY: number;
}

function slotPixels(slot: Slot, width: number, height: number): Vector2 {
	const slotW = slot.width ?? 112;
	const slotH = slot.height ?? 62;
	return new Vector2(slot.x * width - slotW * (slot.anchorX ?? 0.5), slot.y * height - slotH * (slot.anchorY ?? 0.5));
}
function slotBounds(slot: Slot, width: number, height: number, sideInset: number, topInset: number, bottomInset: number): Bounds {
	const slotW = slot.width ?? 112;
	const slotH = slot.height ?? 62;
	const minX = math.max(8, sideInset + 8);
	const minY = math.max(48, topInset + 8, slot.safeTop ?? 0);
	return {
		minX,
		maxX: math.max(minX, width - sideInset - slotW - 8),
		minY,
		maxY: math.max(minY, height - bottomInset - slotH - 8),
	};
}
function safeSlotPosition(
	slot: Slot,
	position: Vector2,
	width: number,
	height: number,
	sideInset: number,
	topInset: number,
	bottomInset: number,
): Vector2 {
	const bounds = slotBounds(slot, width, height, sideInset, topInset, bottomInset);
	return new Vector2(math.clamp(position.X, bounds.minX, bounds.maxX), math.clamp(position.Y, bounds.minY, bounds.maxY));
}

type Memory = Record<string, { x: number; y: number } | undefined>;
interface MobileLayoutSlotsApi {
	Decode(this: void, raw: string): Record<number, Memory>;
	Encode(this: void, slots: unknown): string;
}

// Layout memory; fractions so a stored layout survives rotation. Seeded from the saved profile string.
const MobileLayoutSlots = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("MobileLayoutSlots") as ModuleScript,
) as MobileLayoutSlotsApi;
const MOBILE_LAYOUT_MEMORY: Record<number, Memory | undefined> = {};
let MOBILE_LAYOUT_SEEDED = false;

type Positions = Record<string, Vector2 | undefined>;

interface MobileControlsProps {
	slots: Slot[];
	dispatch: (action: string, payload?: Record<string, unknown>) => void;
	savedSlots?: unknown;
	reducedMotion?: boolean;
	visible: boolean;
	onClose: () => void;
	scales?: Record<string, number | undefined>;
	opacities?: Record<string, number | undefined>;
}

function MobileControls(props: MobileControlsProps) {
	const slots = props.slots;
	const dispatch = props.dispatch;
	if (!MOBILE_LAYOUT_SEEDED && typeIs(props.savedSlots, "string")) {
		MOBILE_LAYOUT_SEEDED = true;
		for (const [index, memory] of pairs(MobileLayoutSlots.Decode(props.savedSlots))) {
			MOBILE_LAYOUT_MEMORY[index] = memory;
		}
	}
	const reducedMotion = props.reducedMotion;
	const visible = props.visible;
	const onClose = props.onClose;
	const scales = props.scales;
	const opacities = props.opacities;
	const viewport = useViewport();
	const [editing, setEditing] = React.useState(false);
	const [snap, setSnap] = React.useState(true);
	const [snapStep, setSnapStep] = React.useState(16);
	const [fine, setFine] = React.useState(false);
	const [showThirds, setShowThirds] = React.useState(false);
	const [selectedId, setSelectedId] = React.useState<string>();
	const [locked, setLocked] = React.useState<Record<string, boolean | undefined>>({});
	const [history, setHistory] = React.useState<Positions[]>([]);
	const [redo, setRedo] = React.useState<Positions[]>([]);
	const [positions, setPositions] = React.useState<Positions>({});
	const [memoryIndex, setMemoryIndex] = React.useState(1);
	const [memoryRevision, setMemoryRevision] = React.useState(0);
	const [exit, exiting, beginExit] = useExitTransition(reducedMotion, 0.38, visible);
	const requestClose = React.useCallback(() => {
		if (!exiting) {
			beginExit(onClose);
		}
	}, [beginExit, exiting, onClose]);
	const [screen] = React.useState((): Instance => {
		const playerGui = Players.LocalPlayer.WaitForChild("PlayerGui");
		const vrScreen = playerGui.FindFirstChild("AstralForgeVR") as SurfaceGui | undefined;
		if (vrScreen && vrScreen.Enabled) {
			return vrScreen.FindFirstChild("Overlay") as Instance;
		}
		const rootScreen = playerGui.FindFirstChild("AstralForgeStudioUI");
		return rootScreen !== undefined && rootScreen.IsA("ScreenGui") ? rootScreen : playerGui;
	});
	const positionsRef = React.useRef(positions);
	positionsRef.current = positions;
	React.useEffect(() => {
		return () => {
			MobileDragging.dispose();
		};
	}, []);
	React.useEffect(() => {
		if (!visible) {
			return undefined;
		}
		const initialPositions: Positions = {};
		for (const slot of slots) {
			initialPositions[slot.id] = safeSlotPosition(
				slot,
				slotPixels(slot, viewport.width, viewport.height),
				viewport.width,
				viewport.height,
				viewport.sideInset,
				viewport.topInset,
				viewport.bottomInset,
			);
		}
		positionsRef.current = initialPositions;
		setPositions(initialPositions);
	}, [slots, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible]);
	React.useEffect(() => {
		if (!visible) {
			MobileDragging.setEditMode(false);
			setEditing(false);
			return undefined;
		}
		const cleanups: Array<() => void> = [];
		const corrected = table.clone(positionsRef.current);
		setmetatable(corrected, undefined as unknown as LuaMetatable<Positions>);
		let correctedAny = false;
		for (const slot of slots) {
			const bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset);
			const raw = positionsRef.current[slot.id] ?? slotPixels(slot, viewport.width, viewport.height);
			const position = safeSlotPosition(
				slot,
				raw,
				viewport.width,
				viewport.height,
				viewport.sideInset,
				viewport.topInset,
				viewport.bottomInset,
			);
			if (position.X !== raw.X || position.Y !== raw.Y) {
				corrected[slot.id] = position;
				correctedAny = true;
			}
			cleanups.push(
				MobileDragging.register({
					id: slot.id,
					position,
					bounds,
					snap: snap ? snapStep : 1,
					onMove: (nextPosition) =>
						setPositions((current) => {
							const copy = table.clone(current);
							setmetatable(copy, undefined as unknown as LuaMetatable<Positions>);
							copy[slot.id] = nextPosition;
							return copy;
						}),
				}),
			);
		}
		if (correctedAny) {
			positionsRef.current = corrected;
			setPositions(corrected);
		}
		return () => {
			for (const dispose of cleanups) {
				dispose();
			}
		};
	}, [slots, snap, snapStep, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible]);
	React.useEffect(() => {
		MobileDragging.setEditMode(editing && visible);
		return () => MobileDragging.setEditMode(false);
	}, [editing, visible]);
	const pixelsOf = (source: Positions, slot: Slot) => source[slot.id] ?? slotPixels(slot, viewport.width, viewport.height);
	const safe = (slot: Slot, position: Vector2) =>
		safeSlotPosition(slot, position, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset);
	const layoutOverlaps = (source: Positions): boolean => {
		for (let index = 0; index <= slots.size() - 1; index++) {
			const slot = slots[index];
			const pos = pixelsOf(source, slot);
			const width = slot.width ?? 112;
			const height = slot.height ?? 62;
			for (let otherIndex = index + 1; otherIndex < slots.size(); otherIndex++) {
				const other = slots[otherIndex];
				const otherPos = pixelsOf(source, other);
				const otherWidth = other.width ?? 112;
				const otherHeight = other.height ?? 62;
				const separated =
					pos.X + width + 6 <= otherPos.X ||
					otherPos.X + otherWidth + 6 <= pos.X ||
					pos.Y + height + 6 <= otherPos.Y ||
					otherPos.Y + otherHeight + 6 <= pos.Y;
				if (!separated) {
					return true;
				}
			}
		}
		return false;
	};
	const save = (source?: Positions): boolean => {
		if (source === undefined) {
			source = positionsRef.current;
		}
		if (layoutOverlaps(source)) {
			return false;
		}
		const values: Record<string, number> = {};
		for (const slot of slots) {
			const raw = pixelsOf(source, slot);
			const pos = safe(slot, raw);
			const slotW = slot.width ?? 112;
			const slotH = slot.height ?? 62;
			values[slot.xKey] = math.clamp((pos.X + slotW * (slot.anchorX ?? 0.5)) / viewport.width, 0, 1);
			values[slot.yKey] = math.clamp((pos.Y + slotH * (slot.anchorY ?? 0.5)) / viewport.height, 0, 1);
		}
		dispatch("SetMobileLayout", { Values: values });
		return true;
	};
	const finishEditing = () => {
		if (!save()) {
			return false;
		}
		setEditing(false);
		return true;
	};
	const capStack = (source: Positions[], extra: Positions): Positions[] => {
		const nextHist = [...source];
		const copy = table.clone(extra);
		setmetatable(copy, undefined as unknown as LuaMetatable<Positions>);
		nextHist.push(copy);
		if (nextHist.size() <= 12) {
			return nextHist;
		}
		const trimmed: Positions[] = [];
		for (let index = nextHist.size() - 12; index <= nextHist.size() - 1; index++) {
			trimmed.push(nextHist[index]);
		}
		return trimmed;
	};
	const applyPositions = (nextPos: Positions) => {
		positionsRef.current = nextPos;
		setPositions(nextPos);
		for (const slot of slots) {
			const pos = nextPos[slot.id];
			if (pos !== undefined) {
				MobileDragging.setPosition(slot.id, pos);
			}
		}
	};
	const pushHistory = (source: Positions) => {
		setHistory((current) => capStack(current, source));
		setRedo([]);
	};
	const undoLayout = () => {
		if (history.size() === 0) {
			return undefined;
		}
		const prior = history[history.size() - 1];
		if (prior === undefined) {
			return undefined;
		}
		setRedo((current) => capStack(current, positionsRef.current));
		setHistory((current) => current.filter((_, index) => index < current.size() - 1));
		applyPositions(prior);
		Audio.play("close", 0.94);
	};
	const redoLayout = () => {
		if (redo.size() === 0) {
			return undefined;
		}
		const upcoming = redo[redo.size() - 1];
		if (upcoming === undefined) {
			return undefined;
		}
		setHistory((current) => capStack(current, positionsRef.current));
		setRedo((current) => current.filter((_, index) => index < current.size() - 1));
		applyPositions(upcoming);
		Audio.play("open", 1.04);
	};
	const currentId = () => selectedId ?? slots[0]?.id;
	const nudgeSelected = (dx: number, dy: number) => {
		const id = currentId();
		if (id === undefined || locked[id] === true) {
			return undefined;
		}
		const slot = slots.find((entry) => entry.id === id);
		if (slot === undefined) {
			return undefined;
		}
		pushHistory(positionsRef.current);
		const current = pixelsOf(positionsRef.current, slot);
		const step = fine ? 1 : snap ? snapStep : 4;
		const moved = safe(slot, new Vector2(current.X + dx * step, current.Y + dy * step));
		const copy = table.clone(positionsRef.current);
		setmetatable(copy, undefined as unknown as LuaMetatable<Positions>);
		copy[id] = moved;
		applyPositions(copy);
	};
	const alignSelected = (mode: string) => {
		const id = currentId();
		if (id === undefined || locked[id] === true) {
			return undefined;
		}
		const slot = slots.find((entry) => entry.id === id);
		if (slot === undefined) {
			return undefined;
		}
		pushHistory(positionsRef.current);
		const current = pixelsOf(positionsRef.current, slot);
		const slotW = slot.width ?? 112;
		const slotH = slot.height ?? 62;
		const bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset);
		let x = current.X;
		let y = current.Y;
		if (mode === "left") {
			x = bounds.minX;
		}
		if (mode === "right") {
			x = bounds.maxX;
		}
		if (mode === "top") {
			y = bounds.minY;
		}
		if (mode === "bottom") {
			y = bounds.maxY;
		}
		if (mode === "cx") {
			x = math.floor((viewport.width - slotW) / 2);
		}
		if (mode === "cy") {
			y = math.floor((viewport.height - slotH) / 2);
		}
		const copy = table.clone(positionsRef.current);
		setmetatable(copy, undefined as unknown as LuaMetatable<Positions>);
		copy[id] = safe(slot, new Vector2(x, y));
		applyPositions(copy);
	};
	const unstackOverlaps = () => {
		pushHistory(positionsRef.current);
		const nextPos = table.clone(positionsRef.current);
		setmetatable(nextPos, undefined as unknown as LuaMetatable<Positions>);
		for (let index = 0; index <= slots.size() - 1; index++) {
			const slot = slots[index];
			if (locked[slot.id] === true) {
				continue;
			}
			let pos = pixelsOf(nextPos, slot);
			const width = slot.width ?? 112;
			const height = slot.height ?? 62;
			for (let otherIndex = 0; otherIndex <= slots.size() - 1; otherIndex++) {
				if (otherIndex === index) {
					continue;
				}
				const other = slots[otherIndex];
				const otherPos = pixelsOf(nextPos, other);
				const otherW = other.width ?? 112;
				const otherH = other.height ?? 62;
				const separated =
					pos.X + width + 8 <= otherPos.X ||
					otherPos.X + otherW + 8 <= pos.X ||
					pos.Y + height + 8 <= otherPos.Y ||
					otherPos.Y + otherH + 8 <= pos.Y;
				if (separated) {
					continue;
				}
				pos = safe(slot, new Vector2(pos.X, otherPos.Y + otherH + 12));
			}
			nextPos[slot.id] = pos;
		}
		applyPositions(nextPos);
		save(nextPos);
	};
	const bumpSelectedSetting = (kind: string, delta: number) => {
		const id = currentId();
		if (id === undefined) {
			return undefined;
		}
		const key =
			id === "quick"
				? kind === "scale"
					? "MobileQuickScale"
					: "MobileQuickOpacity"
				: id === "dock"
					? kind === "scale"
						? "MobileDockScale"
						: "MobileDockOpacity"
					: kind === "scale"
						? "MobileToastScale"
						: "MobileToastOpacity";
		const current = kind === "scale" ? scales?.[id] ?? 0.5 : opacities?.[id] ?? 0.85;
		dispatch("SetSetting", { Key: key, Value: math.clamp(current + delta, 0, 1) });
	};
	const resetLayout = () => {
		const fresh: Positions = {};
		for (const slot of slots) {
			const resetSlot = table.clone(slot);
			setmetatable(resetSlot, undefined as unknown as LuaMetatable<Slot>);
			resetSlot.x = slot.defaultX;
			resetSlot.y = slot.defaultY;
			fresh[slot.id] = safe(slot, slotPixels(resetSlot, viewport.width, viewport.height));
		}
		if (layoutOverlaps(fresh)) {
			return undefined;
		}
		for (const slot of slots) {
			MobileDragging.setPosition(slot.id, fresh[slot.id]!);
		}
		positionsRef.current = fresh;
		setPositions(fresh);
		save(fresh);
	};
	const PRESETS: Record<string, Record<string, [number, number] | undefined> | undefined> = {
		left: { quick: [0.28, 0.72], toasts: [0.22, 0.24], dock: [0.5, 0.92] },
		right: { quick: [0.72, 0.72], toasts: [0.78, 0.24], dock: [0.5, 0.92] },
		top: { quick: [0.5, 0.22], toasts: [0.82, 0.38], dock: [0.5, 0.92] },
		thumbs: { quick: [0.5, 0.78], toasts: [0.5, 0.18], dock: [0.5, 0.93] },
		tl: { quick: [0.22, 0.22], toasts: [0.78, 0.22], dock: [0.5, 0.92] },
		tr: { quick: [0.78, 0.22], toasts: [0.22, 0.22], dock: [0.5, 0.92] },
		bl: { quick: [0.22, 0.78], toasts: [0.22, 0.24], dock: [0.5, 0.92] },
		br: { quick: [0.78, 0.78], toasts: [0.78, 0.24], dock: [0.5, 0.92] },
	};
	const applyPreset = (side: string) => {
		pushHistory(positionsRef.current);
		Audio.play("filterPick", 1.02);
		const fresh: Positions = {};
		for (const slot of slots) {
			let x = slot.defaultX;
			let y = slot.defaultY;
			const preset = PRESETS[side]?.[slot.id];
			if (preset !== undefined) {
				x = preset[0];
				y = preset[1];
			}
			const moved = table.clone(slot);
			setmetatable(moved, undefined as unknown as LuaMetatable<Slot>);
			moved.x = x;
			moved.y = y;
			fresh[slot.id] = safe(slot, slotPixels(moved, viewport.width, viewport.height));
		}
		if (layoutOverlaps(fresh)) {
			return undefined;
		}
		applyPositions(fresh);
		save(fresh);
		if (side === "left" || side === "bl") {
			dispatch("SetSetting", { Key: "MobileQuickReverse", Value: 1 });
		}
		if (side === "right" || side === "br") {
			dispatch("SetSetting", { Key: "MobileQuickReverse", Value: 0 });
		}
	};
	const slotSize = (slot: Slot): LuaTuple<[number, number]> => $tuple(slot.width ?? 112, slot.height ?? 62);
	const commitLayout = (nextPos: Positions) => {
		applyPositions(nextPos);
		if (!layoutOverlaps(nextPos)) {
			save(nextPos);
		}
	};
	const mirrorLayout = () => {
		pushHistory(positionsRef.current);
		Audio.play("filterPick", 0.94);
		const nextPos = table.clone(positionsRef.current);
		for (const slot of slots) {
			if (locked[slot.id] === true) {
				continue;
			}
			const pos = pixelsOf(nextPos, slot);
			const [width] = slotSize(slot);
			nextPos[slot.id] = safe(slot, new Vector2(viewport.width - pos.X - width, pos.Y));
		}
		commitLayout(nextPos);
	};
	const cycleSelection = () => {
		if (slots.size() === 0) {
			return undefined;
		}
		let nextIndex = 1;
		for (let index = 1; index <= slots.size(); index++) {
			if (slots[index - 1].id === selectedId) {
				nextIndex = (index % slots.size()) + 1;
				break;
			}
		}
		setSelectedId(slots[nextIndex - 1].id);
		Audio.play("filterPick", 1.08);
	};
	const swapSelected = () => {
		if (slots.size() < 2) {
			return undefined;
		}
		let fromIndex = 1;
		for (let index = 1; index <= slots.size(); index++) {
			if (slots[index - 1].id === selectedId) {
				fromIndex = index;
				break;
			}
		}
		const fromSlot = slots[fromIndex - 1];
		let toSlot: Slot | undefined;
		for (let step = 1; step <= slots.size() - 1; step++) {
			const candidate = slots[(fromIndex - 1 + step) % slots.size()];
			if (locked[candidate.id] !== true) {
				toSlot = candidate;
				break;
			}
		}
		if (toSlot === undefined || locked[fromSlot.id] === true) {
			return undefined;
		}
		pushHistory(positionsRef.current);
		const nextPos = table.clone(positionsRef.current);
		const fromPos = pixelsOf(nextPos, fromSlot);
		const toPos = pixelsOf(nextPos, toSlot);
		const [fromW, fromH] = slotSize(fromSlot);
		const [toW, toH] = slotSize(toSlot);
		// Swap centres, not corners, so blocks of different sizes trade places cleanly.
		const fromCentre = fromPos.add(new Vector2(fromW, fromH).div(2));
		const toCentre = toPos.add(new Vector2(toW, toH).div(2));
		nextPos[fromSlot.id] = safe(fromSlot, toCentre.sub(new Vector2(fromW, fromH).div(2)));
		nextPos[toSlot.id] = safe(toSlot, fromCentre.sub(new Vector2(toW, toH).div(2)));
		Audio.play("filterPick", 1.0);
		commitLayout(nextPos);
	};
	const storeMemory = () => {
		const stored: Memory = {};
		for (const slot of slots) {
			const pos = pixelsOf(positionsRef.current, slot);
			stored[slot.id] = { x: pos.X / math.max(1, viewport.width), y: pos.Y / math.max(1, viewport.height) };
		}
		MOBILE_LAYOUT_MEMORY[memoryIndex] = stored;
		setMemoryRevision(memoryRevision + 1);
		dispatch("SetMobileLayout", { Values: {}, Slots: MobileLayoutSlots.Encode(MOBILE_LAYOUT_MEMORY) });
		Audio.play("copyDone");
	};
	const recallMemory = () => {
		const stored = MOBILE_LAYOUT_MEMORY[memoryIndex];
		if (stored === undefined) {
			return undefined;
		}
		pushHistory(positionsRef.current);
		const nextPos = table.clone(positionsRef.current);
		for (const slot of slots) {
			const entry = stored[slot.id];
			if (entry !== undefined && locked[slot.id] !== true) {
				nextPos[slot.id] = safe(slot, new Vector2(entry.x * viewport.width, entry.y * viewport.height));
			}
		}
		Audio.play("filterPick", 0.9);
		commitLayout(nextPos);
	};
	const overlaps = (slot: Slot, pos: Vector2): boolean => {
		const w = slot.width ?? 112;
		const hh = slot.height ?? 62;
		for (const other of slots) {
			if (other.id === slot.id) {
				continue;
			}
			const otherPos = pixelsOf(positions, other);
			const otherW = other.width ?? 112;
			const otherH = other.height ?? 62;
			const separated =
				pos.X + w + 6 <= otherPos.X ||
				otherPos.X + otherW + 6 <= pos.X ||
				pos.Y + hh + 6 <= otherPos.Y ||
				otherPos.Y + otherH + 6 <= pos.Y;
			if (!separated) {
				return true;
			}
		}
		return false;
	};
	const collisionPresent = layoutOverlaps(positions);
	if (!visible) {
		return ReactRoblox.createPortal(
			h("frame", { Size: UDim2.fromOffset(0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 }),
			screen,
		);
	}
	const editorToolbarY = math.max(viewport.width > viewport.height && viewport.height < 500 ? 56 : 8, viewport.topInset + 8);
	const topToolbarBottom = editorToolbarY + TapTarget * 2 + 16 + 8;
	const bottomBarY = math.max(topToolbarBottom, viewport.height - viewport.bottomInset - (TapTarget * 2 + 16));
	const gridMarks = showThirds ? [1 / 3, 0.5, 2 / 3] : [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
	const selectedSlot = slots.find((entry) => entry.id === currentId());
	const selectedPos = selectedSlot !== undefined ? pixelsOf(positions, selectedSlot) : undefined;
	const selectedLocked = selectedSlot !== undefined && locked[selectedSlot.id] === true;
	const gridX =
		editing &&
		gridMarks.map((x) =>
			h("frame", {
				key: `grid-x-${x}`,
				Size: new UDim2(0, 1, 1, 0),
				Position: new UDim2(x, 0, 0, 0),
				BackgroundColor3: x === 0.5 ? Palette.mint : Palette.cyan,
				BackgroundTransparency: x === 0.5 ? 0.72 : 0.9,
				BorderSizePixel: 0,
				ZIndex: 500,
				Active: false,
			}),
		);
	const gridY =
		editing &&
		gridMarks.map((y) =>
			h("frame", {
				key: `grid-y-${y}`,
				Size: new UDim2(1, 0, 0, 1),
				Position: new UDim2(0, 0, y, 0),
				BackgroundColor3: y === 0.5 ? Palette.mint : Palette.cyan,
				BackgroundTransparency: y === 0.5 ? 0.72 : 0.9,
				BorderSizePixel: 0,
				ZIndex: 500,
				Active: false,
			}),
		);
	const blocks =
		editing &&
		slots.map((slot) => {
			const slotW = slot.width ?? 112;
			const slotH = slot.height ?? 62;
			const pos = pixelsOf(positions, slot);
			const collision = overlaps(slot, pos);
			const isLocked = locked[slot.id] === true;
			const accent = collision
				? Palette.coral
				: selectedId === slot.id
					? Palette.mint
					: isLocked
						? Palette.mango
						: EDIT_BOUNDS;
			const pctX = math.floor(((pos.X + slotW * 0.5) / viewport.width) * 100);
			const pctY = math.floor(((pos.Y + slotH * 0.5) / viewport.height) * 100);
			return h(
				"frame",
				{
					key: slot.id,
					Size: UDim2.fromOffset(slotW, slotH),
					Position: UDim2.fromOffset(pos.X, pos.Y),
					BackgroundColor3: Palette.panelRaised,
					BackgroundTransparency: 0.04,
					BorderSizePixel: 0,
					ZIndex: 502,
				},
				h("uicorner", { CornerRadius: new UDim(0, 14) }),
				h("uistroke", {
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
					Color: accent,
					Thickness: collision ? 3 : 2,
					Transparency: 0.08,
				}),
				h(
					"frame",
					{
						Size: UDim2.fromOffset(22, 22),
						Position: UDim2.fromOffset(-7, -7),
						BackgroundColor3: accent,
						BorderSizePixel: 0,
						ZIndex: 505,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					text({
						value: isLocked ? "L" : "+",
						size: 14,
						color: Palette.ink,
						weight: Enum.FontWeight.Heavy,
						align: Enum.TextXAlignment.Center,
						sizeConstraint: UDim2.fromScale(1, 1),
						zIndex: 506,
					}),
				),
				text({
					value: slot.label,
					size: 11,
					color: Palette.cream,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Center,
					position: UDim2.fromOffset(4, 8),
					sizeConstraint: new UDim2(1, -8, 0, 18),
					zIndex: 503,
				}),
				text({
					value: `${pctX}%  ${pctY}%`,
					size: 9,
					color: Palette.creamSoft,
					weight: Enum.FontWeight.Heavy,
					align: Enum.TextXAlignment.Center,
					position: new UDim2(0, 4, 1, -22),
					sizeConstraint: new UDim2(1, -8, 0, 14),
					zIndex: 503,
				}),
				collision &&
					text({
						value: "OVERLAP",
						size: 8,
						color: Palette.coral,
						weight: Enum.FontWeight.Heavy,
						align: Enum.TextXAlignment.Center,
						position: new UDim2(0, 0, 1, -36),
						sizeConstraint: new UDim2(1, 0, 0, 14),
						zIndex: 506,
					}),
				h("imagebutton", {
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					AutoButtonColor: false,
					Selectable: false,
					Active: true,
					ZIndex: 504,
					Event: {
						InputBegan: (_button: unknown, input: InputObject) => {
							if (
								input.UserInputType === Enum.UserInputType.Touch ||
								input.UserInputType === Enum.UserInputType.MouseButton1
							) {
								setSelectedId(slot.id);
								if (!isLocked) {
									MobileDragging.beginDrag(slot.id, input);
								}
							}
						},
					},
				}),
			);
		});
	let tools: unknown = false;
	if (editing) {
		const cell = (size: UDim2, position: UDim2 | undefined, child: unknown) =>
			h("frame", { Size: size, Position: position, BackgroundTransparency: 1 }, child);
		const toolbar = h(
			"frame",
			{
				Size: new UDim2(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
				Position: UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY),
				BackgroundColor3: Palette.panelRaised,
				BackgroundTransparency: 0.02,
				BorderSizePixel: 0,
				ZIndex: 510,
			},
			h("uicorner", { CornerRadius: new UDim(0, 13) }),
			h("uistroke", {
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				LineJoinMode: Enum.LineJoinMode.Round,
				Color: Palette.cyan,
				Thickness: 1,
				Transparency: 0.42,
			}),
			cell(
				new UDim2(0.2, -3, 1, 0),
				undefined,
				btn({
					text: collisionPresent ? "OVERLAP" : "SAVE",
					onClick: collisionPresent ? unstackOverlaps : finishEditing,
					color: collisionPresent ? Palette.coral : EDIT_BOUNDS,
					textColor: Palette.ink,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
				}),
			),
			cell(
				new UDim2(0.2, -3, 1, 0),
				new UDim2(0.2, 1, 0, 0),
				btn({
					text: snap ? `SNAP ${snapStep}` : "FREE",
					onClick: () => {
						if (!snap) {
							setSnap(true);
							setSnapStep(4);
						} else if (snapStep === 4) {
							setSnapStep(8);
						} else if (snapStep === 8) {
							setSnapStep(16);
						} else if (snapStep === 16) {
							setSnapStep(32);
						} else {
							setSnap(false);
							setSnapStep(8);
						}
					},
					color: snap ? Palette.cyan : Palette.panelSoft,
					textColor: snap ? Palette.ink : Palette.creamSoft,
					outline: !snap,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
				}),
			),
			cell(
				new UDim2(0.2, -3, 1, 0),
				new UDim2(0.4, 2, 0, 0),
				btn({
					text: "UNDO",
					onClick: undoLayout,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
				}),
			),
			cell(
				new UDim2(0.2, -3, 1, 0),
				new UDim2(0.6, 3, 0, 0),
				btn({
					text: "REDO",
					onClick: redoLayout,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
				}),
			),
			cell(
				new UDim2(0.2, -3, 1, 0),
				new UDim2(0.8, 4, 0, 0),
				btn({
					text: "DONE",
					onClick: () => {
						if (finishEditing()) {
							requestClose();
						}
					},
					color: Palette.panelSoft,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
					disabled: exiting,
				}),
			),
		);
		const row = (y: number, ...children: unknown[]) =>
			h(
				"frame",
				{
					Size: new UDim2(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
					Position: UDim2.fromOffset(viewport.sideInset + 8, y),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 510,
				},
				...children,
			);
		const plain = (label: string, onClick: () => void, size: UDim2, position?: UDim2) =>
			btn({
				text: label,
				onClick,
				color: Palette.panelSoft,
				textColor: Palette.cream,
				size,
				position,
				reducedMotion,
			});
		const nudgeRow = row(
			editorToolbarY + TapTarget + 8,
			plain("←", () => nudgeSelected(-1, 0), new UDim2(0.16, -3, 1, 0)),
			plain("↑", () => nudgeSelected(0, -1), new UDim2(0.16, -3, 1, 0), new UDim2(0.16, 1, 0, 0)),
			plain("↓", () => nudgeSelected(0, 1), new UDim2(0.16, -3, 1, 0), new UDim2(0.32, 2, 0, 0)),
			plain("→", () => nudgeSelected(1, 0), new UDim2(0.16, -3, 1, 0), new UDim2(0.48, 3, 0, 0)),
			btn({
				text: fine ? "1px" : "STEP",
				onClick: () => setFine(!fine),
				color: fine ? Palette.mint : Palette.panelSoft,
				textColor: fine ? Palette.ink : Palette.cream,
				size: new UDim2(0.18, -3, 1, 0),
				position: new UDim2(0.64, 4, 0, 0),
				reducedMotion,
			}),
			btn({
				text: showThirds ? "1/3" : "10%",
				onClick: () => setShowThirds(!showThirds),
				color: showThirds ? Palette.cyan : Palette.panelSoft,
				textColor: showThirds ? Palette.ink : Palette.cream,
				size: new UDim2(0.18, -3, 1, 0),
				position: new UDim2(0.82, 5, 0, 0),
				reducedMotion,
			}),
		);
		const sixth = new UDim2(1 / 6, -4, 1, 0);
		const alignRow = row(
			bottomBarY,
			plain("L", () => alignSelected("left"), sixth),
			plain("R", () => alignSelected("right"), sixth, new UDim2(1 / 6, 1, 0, 0)),
			plain("T", () => alignSelected("top"), sixth, new UDim2(2 / 6, 2, 0, 0)),
			plain("B", () => alignSelected("bottom"), sixth, new UDim2(3 / 6, 3, 0, 0)),
			plain("CX", () => alignSelected("cx"), sixth, new UDim2(4 / 6, 4, 0, 0)),
			plain("CY", () => alignSelected("cy"), sixth, new UDim2(5 / 6, 5, 0, 0)),
		);
		const settingsRow = row(
			bottomBarY + TapTarget + 6,
			btn({
				text: selectedLocked ? "UNLOCK" : "LOCK",
				onClick: () => {
					if (selectedSlot === undefined) {
						return undefined;
					}
					setLocked((current) => {
						const copy = table.clone(current);
						setmetatable(copy, undefined as unknown as LuaMetatable<Record<string, boolean | undefined>>);
						copy[selectedSlot.id] = !selectedLocked;
						return copy;
					});
				},
				color: selectedLocked ? Palette.mango : Palette.panelSoft,
				textColor: selectedLocked ? Palette.ink : Palette.cream,
				size: new UDim2(0.18, -3, 1, 0),
				reducedMotion,
			}),
			plain("SZ-", () => bumpSelectedSetting("scale", -0.08), new UDim2(0.14, -3, 1, 0), new UDim2(0.18, 1, 0, 0)),
			plain("SZ+", () => bumpSelectedSetting("scale", 0.08), new UDim2(0.14, -3, 1, 0), new UDim2(0.32, 2, 0, 0)),
			plain("FADE-", () => bumpSelectedSetting("opacity", -0.08), new UDim2(0.16, -3, 1, 0), new UDim2(0.46, 3, 0, 0)),
			plain("FADE+", () => bumpSelectedSetting("opacity", 0.08), new UDim2(0.16, -3, 1, 0), new UDim2(0.62, 4, 0, 0)),
			btn({
				text: "CLEAR",
				onClick: unstackOverlaps,
				color: Palette.panelSoft,
				textColor: Palette.cream,
				outline: true,
				size: new UDim2(0.22, -3, 1, 0),
				position: new UDim2(0.78, 5, 0, 0),
				reducedMotion,
			}),
		);
		let status: string;
		if (selectedPos !== undefined) {
			const label = selectedSlot?.label ?? "HUD";
			const selectedScale = scales !== undefined && selectedSlot !== undefined ? scales[selectedSlot.id] : undefined;
			const selectedFade = opacities !== undefined && selectedSlot !== undefined ? opacities[selectedSlot.id] : undefined;
			const xPct = math.floor((selectedPos.X / math.max(1, viewport.width)) * 100 + 0.5);
			const yPct = math.floor((selectedPos.Y / math.max(1, viewport.height)) * 100 + 0.5);
			status = `${label}  ·  X ${xPct}%  Y ${yPct}%  ·  SIZE ${math.floor((selectedScale ?? 0.5) * 100 + 0.5)}  FADE ${math.floor((selectedFade ?? 0.85) * 100 + 0.5)}${selectedLocked ? "  ·  LOCKED" : ""}${collisionPresent ? "  ·  OVERLAP" : ""}`;
		} else {
			status = "DRAG A BLOCK";
		}
		const toolRowY = bottomBarY - TapTarget - 6;
		const memoryFilled = MOBILE_LAYOUT_MEMORY[memoryIndex] !== undefined;
		const memoryRow =
			toolRowY >= topToolbarBottom + 18 &&
			h(
				"frame",
				{
					key: `tools-${memoryRevision}`,
					Size: new UDim2(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
					Position: UDim2.fromOffset(viewport.sideInset + 8, toolRowY),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 510,
				},
				btn({
					text: "NEXT",
					onClick: cycleSelection,
					color: Palette.panelSoft,
					textColor: Palette.cyan,
					outline: true,
					size: new UDim2(0.15, -3, 1, 0),
					reducedMotion,
				}),
				btn({
					text: "SWAP",
					onClick: swapSelected,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					size: new UDim2(0.15, -3, 1, 0),
					position: new UDim2(0.15, 1, 0, 0),
					disabled: selectedLocked,
					reducedMotion,
				}),
				btn({
					text: "MIRROR",
					onClick: mirrorLayout,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					size: new UDim2(0.18, -3, 1, 0),
					position: new UDim2(0.3, 2, 0, 0),
					reducedMotion,
				}),
				btn({
					text: `M${memoryIndex}`,
					onClick: () => {
						setMemoryIndex((memoryIndex % 3) + 1);
					},
					color: memoryFilled ? Palette.violet : Palette.panelSoft,
					textColor: memoryFilled ? Palette.ink : Palette.creamSoft,
					outline: !memoryFilled,
					size: new UDim2(0.12, -3, 1, 0),
					position: new UDim2(0.48, 3, 0, 0),
					reducedMotion,
				}),
				btn({
					text: "STORE",
					onClick: storeMemory,
					color: Palette.panelSoft,
					textColor: Palette.violet,
					outline: true,
					size: new UDim2(0.2, -3, 1, 0),
					position: new UDim2(0.6, 4, 0, 0),
					reducedMotion,
				}),
				btn({
					text: "RECALL",
					onClick: recallMemory,
					color: memoryFilled ? Palette.violet : Palette.panelSoft,
					textColor: memoryFilled ? Palette.ink : Palette.muted,
					size: new UDim2(0.2, -3, 1, 0),
					position: new UDim2(0.8, 5, 0, 0),
					disabled: !memoryFilled,
					reducedMotion,
				}),
			);
		tools = h(
			React.Fragment,
			undefined,
			toolbar,
			nudgeRow,
			alignRow,
			settingsRow,
			memoryRow || undefined,
			text({
				value: status,
				size: 10,
				color: Palette.cyan,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				position: new UDim2(0, viewport.sideInset + 12, 0, editorToolbarY + TapTarget * 2 + 16),
				sizeConstraint: new UDim2(1, -(viewport.sideInset * 2 + 24), 0, 18),
				zIndex: 506,
			}),
		);
	}
	const presetCell = (label: string, side: string, width: number, offset: number, index: number, accent?: Color3) =>
		h(
			"frame",
			{
				Size: new UDim2(width, -4, 1, 0),
				Position: index === 0 ? undefined : new UDim2(width * index, offset, 0, 0),
				BackgroundTransparency: 1,
			},
			btn({
				text: label,
				onClick: () => applyPreset(side),
				color: Palette.panelSoft,
				textColor: accent ?? Palette.creamSoft,
				outline: true,
				size: UDim2.fromScale(1, 1),
				reducedMotion,
			}),
		);
	const menu =
		!editing &&
		h(
			"frame",
			{
				Size: UDim2.fromOffset(math.min(440, viewport.width - viewport.sideInset * 2 - 24), 292),
				Position: new UDim2(0.5, 0, 1, -(304 + viewport.bottomInset)),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundColor3: Palette.panelRaised,
				BackgroundTransparency: 0.04,
				BorderSizePixel: 0,
				ZIndex: 510,
			},
			h("uicorner", { CornerRadius: new UDim(0, 16) }),
			h("uistroke", {
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				LineJoinMode: Enum.LineJoinMode.Round,
				Color: Palette.cyan,
				Thickness: 1,
				Transparency: 0.55,
			}),
			btn({
				text: "EDIT HUD LAYOUT",
				onClick: () => setEditing(true),
				color: EDIT_BOUNDS,
				textColor: Palette.ink,
				size: new UDim2(1, 0, 0, TapTarget),
				reducedMotion,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 40),
					Position: UDim2.fromOffset(0, 56),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				presetCell("LEFT", "left", 0.2, 0, 0),
				presetCell("HOME", "default", 0.2, 1, 1, Palette.cyan),
				presetCell("RIGHT", "right", 0.2, 2, 2),
				presetCell("TOP", "top", 0.2, 3, 3),
				presetCell("THUMB", "thumbs", 0.2, 4, 4),
			),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 40),
					Position: UDim2.fromOffset(0, 104),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				presetCell("TL", "tl", 0.25, 0, 0),
				presetCell("TR", "tr", 0.25, 1, 1),
				presetCell("BL", "bl", 0.25, 2, 2),
				presetCell("BR", "br", 0.25, 3, 3),
			),
			h(
				"frame",
				{
					Size: new UDim2(0.5, -4, 0, TapTarget),
					Position: UDim2.fromOffset(0, 152),
					BackgroundTransparency: 1,
				},
				btn({
					text: "RESET",
					onClick: resetLayout,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
				}),
			),
			h(
				"frame",
				{
					Size: new UDim2(0.5, -4, 0, TapTarget),
					Position: new UDim2(0.5, 4, 0, 152),
					BackgroundTransparency: 1,
				},
				btn({
					text: "CLOSE",
					onClick: requestClose,
					color: Palette.panelSoft,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion,
					disabled: exiting,
				}),
			),
			text({
				value: "Drag the vault, dock and alerts where you want them.",
				size: 10,
				color: Palette.muted,
				wrap: true,
				align: Enum.TextXAlignment.Center,
				fit: false,
				position: UDim2.fromOffset(8, 212),
				sizeConstraint: new UDim2(1, -16, 0, 56),
			}),
		);
	return ReactRoblox.createPortal(
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: exit.map((amount) => 1 - amount * (editing ? 0.62 : 0.88)),
				BorderSizePixel: 0,
				Active: true,
				ZIndex: 500,
				ClipsDescendants: true,
				Visible: exit.map((amount) => amount > 0.01),
			},
			gridX,
			gridY,
			blocks,
			tools,
			menu,
			h("frame", {
				Size: exit.map((amount) => new UDim2(1, 0, 0.5 * (1 - amount), 1)),
				BackgroundColor3: Palette.void,
				BorderSizePixel: 0,
				Active: false,
				ZIndex: 900,
			}),
			h("frame", {
				Size: exit.map((amount) => new UDim2(1, 0, 0.5 * (1 - amount), 1)),
				Position: UDim2.fromScale(0, 1),
				AnchorPoint: new Vector2(0, 1),
				BackgroundColor3: Palette.void,
				BorderSizePixel: 0,
				Active: false,
				ZIndex: 900,
			}),
		),
		screen,
	);
}

interface QuickBarState {
	Capacity?: unknown;
	Vault?: unknown;
	Production?: unknown;
}
interface MobileQuickBarProps {
	state: QuickBarState;
	dispatch: (action: string) => void;
	reducedMotion?: boolean;
	height: number;
	bottomOffset: number;
	edgePad: number;
	hudX?: number;
	hudY?: number;
	hudScale?: number;
	hudOpacity?: number;
	buttonSpacing?: number;
	minTop: number;
	reversed?: boolean;
}

function MobileQuickBar(props: MobileQuickBarProps) {
	const state = props.state;
	const dispatch = props.dispatch;
	const reducedMotion = props.reducedMotion;
	const height = props.height;
	const bottomOffset = props.bottomOffset;
	const edgePad = props.edgePad;
	const minTop = props.minTop;
	const reversed = props.reversed ?? false;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const vaultFill =
		asFlux(state.Capacity as number) > 0
			? math.clamp(asFlux(state.Vault as number) / asFlux(state.Capacity as number), 0, 1)
			: 0;
	const vaultReady = asFlux(state.Vault as number) >= 1;
	const fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28);
	const side = math.max(edgePad, chrome.sideSafe);
	const gap = 4 + math.floor(math.clamp(props.buttonSpacing ?? 0.5, 0, 1) * 10);
	const btnH = TapTarget;
	const scale = 0.72 + math.clamp(props.hudScale ?? 0.5, 0, 1) * 0.28;
	const width = math.max(200, (viewport.width - side * 2) * scale);
	const x = math.clamp(props.hudX ?? 0.5, (side + width / 2) / viewport.width, 1 - (side + width / 2) / viewport.width);
	const yFallback = 1 - (bottomOffset - height / 2) / viewport.height;
	const y = math.clamp(
		props.hudY ?? yFallback,
		(math.max(viewport.topInset, minTop) + height / 2 + 8) / viewport.height,
		1 - (viewport.bottomInset + height / 2 + 8) / viewport.height,
	);
	const surfaceTransparency = math.clamp(0.48 - math.clamp(props.hudOpacity ?? 0.85, 0, 1) * 0.48, 0, 0.48);
	const readyPulse = usePulse(vaultReady && vaultFill > 0.8, 2.4);
	const [tapReadyAt, setTapReadyAt] = React.useState(0);
	const [tapLeft, setTapLeft] = React.useState(0);
	React.useEffect(() => {
		if (tapReadyAt <= 0) {
			setTapLeft(0);
			return undefined;
		}
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				const left = math.max(0, tapReadyAt - os.clock());
				if (!alive) {
					break;
				}
				setTapLeft(math.ceil(left * 10) / 10);
				if (!alive || left <= 0) {
					break;
				}
				task.wait(math.max(0.016, left - (math.ceil(left * 10) - 1) / 10));
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [tapReadyAt]);
	const tap = () => {
		if (os.clock() < tapReadyAt) {
			return undefined;
		}
		setTapReadyAt(os.clock() + 0.45);
		setTapLeft(0.45);
		dispatch("Overcharge");
	};
	const bank = () => {
		if (!vaultReady) {
			Audio.play("locked");
			return undefined;
		}
		dispatch("CollectVault");
	};
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(width, height),
			Position: UDim2.fromScale(x, y),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 60,
		},
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.panel,
				BackgroundTransparency: surfaceTransparency,
				BorderSizePixel: 0,
				ZIndex: 61,
			},
			h("uicorner", { CornerRadius: new UDim(0, 16) }),
			h("uigradient", { Color: surfaceGradient(Palette.panel), Rotation: 90 }),
			h("uistroke", {
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				LineJoinMode: Enum.LineJoinMode.Round,
				Color: vaultFill > 0.8 ? Palette.green : Palette.lineSoft,
				Thickness: vaultFill > 0.8 ? 2 : 1,
				Transparency: readyPulse.map((amount) => (vaultFill > 0.8 ? 0.42 - amount * 0.22 : 0.45)),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -16, 0, 3),
					Position: UDim2.fromOffset(8, 1),
					BackgroundColor3: Palette.line,
					BorderSizePixel: 0,
					ZIndex: 62,
					ClipsDescendants: true,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h(
					"frame",
					{
						Size: fillSpring.map((amount) => new UDim2(math.clamp(amount, 0.02, 1), 0, 1, 0)),
						BackgroundColor3: vaultFill > 0.92 ? Palette.mango : Palette.green,
						BorderSizePixel: 0,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
			),
			h(
				"frame",
				{
					Size: new UDim2(1, -16, 0, btnH),
					Position: UDim2.fromOffset(8, height - btnH - 4),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 63,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					Padding: new UDim(0, gap),
					SortOrder: Enum.SortOrder.LayoutOrder,
					VerticalAlignment: Enum.VerticalAlignment.Center,
				}),
				h(
					"frame",
					{
						Size: new UDim2(0.58, -gap / 2, 1, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						LayoutOrder: reversed ? 2 : 1,
					},
					btn({
						text: vaultReady ? `BANK  ${compactNumber(state.Vault)}` : "VAULT EMPTY",
						icon: "Flux.24",
						onClick: bank,
						color: vaultReady ? Palette.green : Palette.panelSoft,
						textColor: vaultReady ? Palette.ink : Palette.muted,
						size: UDim2.fromScale(1, 1),
						reducedMotion,
						disabled: !vaultReady,
						highlight: vaultReady && vaultFill > 0.5,
					}),
				),
				h(
					"frame",
					{
						Size: new UDim2(0.42, -gap / 2, 1, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						LayoutOrder: reversed ? 1 : 2,
					},
					btn({
						text: tapLeft > 0.02 ? string.format("%.1fs", tapLeft) : "TAP",
						icon: "Forge.28",
						onClick: tap,
						color: tapLeft > 0.02 ? Palette.panelSoft : Palette.cyan,
						textColor: tapLeft > 0.02 ? Palette.muted : Palette.ink,
						size: UDim2.fromScale(1, 1),
						reducedMotion,
						disabled: tapLeft > 0.02,
						highlight: tapLeft <= 0.02,
					}),
				),
			),
			chrome.landscape &&
				text({
					value: `${compactNumber(state.Production)}/s`,
					size: 9,
					color: Palette.muted,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Right,
					position: new UDim2(1, -12, 0, 6),
					sizeConstraint: UDim2.fromOffset(80, 12),
					zIndex: 64,
				}),
		),
	);
}

export { MobileControls, MobileQuickBar };
