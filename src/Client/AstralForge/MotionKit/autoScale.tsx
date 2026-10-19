import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { usesDesktopStructure } from "../CoreKit/interaction";
import { Breakpoints, Layout } from "../CoreKit/theme";
import readSafeInsets = require("./readSafeInsets");

const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

export interface ViewportInfo {
	scale: number;
	width: number;
	height: number;
	topInset: number;
	bottomInset: number;
	sideInset: number;
	screenWidth: number;
	screenHeight: number;
	keyboardOpen: boolean;
	desktop: boolean;
	tenFoot: boolean;
	compact: boolean;
	tight: boolean;
	short: boolean;
}

export const ViewportScaleContext = React.createContext<ViewportInfo | undefined>(undefined);

export function computeViewportScale(screenWidth: number, screenHeight: number): number {
	const width = math.max(1, screenWidth);
	const height = math.max(1, screenHeight);
	const raw = math.min(width / Layout.referenceWidth, height / Layout.referenceHeight);
	return math.clamp(raw, Layout.minScale, Layout.maxScale);
}

export function useViewportScale(): number {
	return React.useContext(ViewportScaleContext)?.scale ?? 1;
}

export { readSafeInsets };

function keyboardTop(screenHeight: number, screenOriginY: number): number {
	if (!UserInputService.TouchEnabled || !UserInputService.OnScreenKeyboardVisible) {
		return screenHeight;
	}
	const position = UserInputService.OnScreenKeyboardPosition;
	const size = UserInputService.OnScreenKeyboardSize;
	const fromPosition = position.Y > screenOriginY ? position.Y - screenOriginY : math.huge;
	const fromSize = size.Y > 0 ? screenHeight - size.Y : math.huge;
	let reportedTop = math.min(fromPosition, fromSize);
	if (reportedTop >= screenHeight || reportedTop === math.huge) {
		reportedTop = screenHeight * 0.55;
	}
	return math.clamp(reportedTop, screenHeight * 0.34, screenHeight);
}

function revealFocusedControl(keyboardTopY?: number) {
	const focused = UserInputService.GetFocusedTextBox();
	if (focused === undefined) {
		return;
	}
	let ancestor = focused.Parent;
	while (ancestor !== undefined) {
		if (ancestor.IsA("ScrollingFrame")) {
			const scroll = ancestor;
			if (scroll.ScrollingEnabled && scroll.ScrollingDirection !== Enum.ScrollingDirection.X) {
				const current = scroll.CanvasPosition;
				const localTop = focused.AbsolutePosition.Y - scroll.AbsolutePosition.Y + current.Y;
				const localBottom = localTop + focused.AbsoluteSize.Y;
				const rawWindow = math.max(1, scroll.AbsoluteWindowSize.Y);
				const occluded = keyboardTopY !== undefined ? math.max(0, scroll.AbsolutePosition.Y + rawWindow - keyboardTopY) : 0;
				const windowHeight = math.max(64, rawWindow - occluded);
				const padding = 12;
				let targetY = current.Y;
				if (localTop < current.Y + padding) {
					targetY = localTop - padding;
				} else if (localBottom > current.Y + windowHeight - padding) {
					targetY = localBottom - windowHeight + padding;
				}
				const maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - rawWindow);
				scroll.CanvasPosition = new Vector2(current.X, math.clamp(targetY, 0, maxY));
			}
		}
		ancestor = ancestor.Parent;
	}
}

const RESIZE_HZ = 30;

interface CoalesceState {
	pending?: Vector2;
	applied: Vector2;
	lastAt: number;
	job?: thread;
	alive: boolean;
}

function useCoalescedScreen(initial: () => Vector2): LuaTuple<[Vector2, (size: Vector2) => void]> {
	const [screen, setScreenNow] = React.useState(initial);
	const state = React.useRef<CoalesceState>();
	if (state.current === undefined) {
		state.current = { applied: screen, lastAt: 0, alive: true };
	}
	React.useEffect(() => {
		const current = state.current!;
		current.alive = true;
		return () => {
			current.alive = false;
			if (current.job !== undefined) {
				pcall(task.cancel, current.job);
				current.job = undefined;
			}
		};
	}, []);
	const request = React.useCallback((size: Vector2) => {
		const current = state.current!;
		const rounded = new Vector2(math.round(size.X), math.round(size.Y));
		if (rounded.X <= 0 || rounded.Y <= 0) {
			return;
		}
		current.pending = rounded;
		if (current.job !== undefined) {
			return;
		}
		const wait = math.max(0, 1 / RESIZE_HZ - (os.clock() - current.lastAt));
		current.job = task.delay(wait, () => {
			current.job = undefined;
			if (!current.alive || current.pending === undefined) {
				return;
			}
			const nextSize = current.pending;
			current.pending = undefined;
			current.lastAt = os.clock();
			if (nextSize !== current.applied) {
				current.applied = nextSize;
				setScreenNow(nextSize);
			}
		});
	}, []);
	return $tuple(screen, request);
}

export function AutoScale(props: { children?: React.ReactNode }) {
	const safeHostRef = React.useRef<Frame>();
	const [screen, setScreen] = useCoalescedScreen(() => {
		const rect = GuiService.GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets);
		return rect.Max.sub(rect.Min);
	});
	const [insets, setInsets] = React.useState(() => readSafeInsets());
	const [, setEnvironmentRevision] = React.useState(0);

	React.useEffect(() => {
		const host = safeHostRef.current;
		if (!host) {
			return undefined;
		}
		const sync = () => {
			const size = host.AbsoluteSize;
			if (size.X > 0 && size.Y > 0) {
				setScreen(size);
			}
		};
		sync();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
		return () => connection.Disconnect();
	}, []);

	React.useEffect(() => {
		let sizeConnection: RBXScriptConnection | undefined;
		let alive = true;
		const pending = new Array<thread>();
		const resettle = () => {
			for (const item of pending) {
				task.cancel(item);
			}
			pending.clear();
			for (const delay of [0, 0.12, 0.3]) {
				pending.push(
					task.delay(delay, () => {
						if (!alive) {
							return;
						}
						setInsets(readSafeInsets());
					}),
				);
			}
		};
		const hostSize = (camera: Camera) => {
			const host = safeHostRef.current;
			return host && host.AbsoluteSize.X > 0 ? host.AbsoluteSize : camera.ViewportSize;
		};
		const attach = () => {
			sizeConnection?.Disconnect();
			const camera = Workspace.CurrentCamera;
			if (!camera) {
				return;
			}
			setScreen(hostSize(camera));
			resettle();
			sizeConnection = camera.GetPropertyChangedSignal("ViewportSize").Connect(() => {
				setScreen(hostSize(camera));
				resettle();
			});
		};
		attach();
		const cameraConnection = Workspace.GetPropertyChangedSignal("CurrentCamera").Connect(attach);
		return () => {
			alive = false;
			for (const item of pending) {
				task.cancel(item);
			}
			sizeConnection?.Disconnect();
			cameraConnection.Disconnect();
		};
	}, []);

	React.useEffect(() => {
		const sync = () => setInsets(readSafeInsets());
		sync();
		const connection = GuiService.GetPropertyChangedSignal("TopbarInset").Connect(sync);
		return () => connection.Disconnect();
	}, []);

	React.useEffect(() => {
		let queued = false;
		let alive = true;
		const sync = () => {
			if (queued) {
				return;
			}
			queued = true;
			task.defer(() => {
				if (!alive) {
					return;
				}
				queued = false;
				setEnvironmentRevision((revision) => revision + 1);
				setInsets(readSafeInsets());
			});
		};
		const connections = [
			UserInputService.GetPropertyChangedSignal("PreferredInput").Connect(sync),
			UserInputService.GetPropertyChangedSignal("KeyboardEnabled").Connect(sync),
			UserInputService.GetPropertyChangedSignal("MouseEnabled").Connect(sync),
			UserInputService.GetPropertyChangedSignal("TouchEnabled").Connect(sync),
			UserInputService.GetPropertyChangedSignal("GamepadEnabled").Connect(sync),
			UserInputService.GetPropertyChangedSignal("OnScreenKeyboardVisible").Connect(sync),
			UserInputService.GetPropertyChangedSignal("OnScreenKeyboardPosition").Connect(sync),
			UserInputService.GetPropertyChangedSignal("OnScreenKeyboardSize").Connect(sync),
		];
		return () => {
			alive = false;
			for (const connection of connections) {
				connection.Disconnect();
			}
		};
	}, []);

	const vrWidth = Workspace.GetAttribute("AstralForgeVRCanvasWidth") as number | undefined;
	const vrHeight = Workspace.GetAttribute("AstralForgeVRCanvasHeight") as number | undefined;
	const vr = vrWidth !== undefined;
	const screenWidth = math.max(1, vrWidth ?? screen.X);
	const screenHeight = math.max(1, vrHeight ?? screen.Y);
	const safeOriginY = safeHostRef.current ? safeHostRef.current.AbsolutePosition.Y : 0;
	const keyboardOpen = UserInputService.TouchEnabled && UserInputService.OnScreenKeyboardVisible;
	const usableScreenHeight = keyboardTop(screenHeight, safeOriginY);
	const chromeScale = vr ? 1 : Layout.chromeScale;
	const tvSafe =
		!vr && GuiService.IsTenFootInterface()
			? GamepadNavigationService.GetTVSafeInsets(new Vector2(screenWidth, screenHeight))
			: { top: 0, bottom: 0, left: 0, right: 0 };
	const hostWidth = math.round(math.min(Layout.maxShellWidth, math.max(1, screenWidth - tvSafe.left - tvSafe.right)));
	const hostHeight = math.round(math.max(1, usableScreenHeight - tvSafe.top - tvSafe.bottom));
	const layoutWidth = math.max(1, math.floor(hostWidth / chromeScale));
	const layoutHeight = math.max(1, math.floor(hostHeight / chromeScale));
	const desktop = usesDesktopStructure(screenWidth, screenHeight);
	const preferred = UserInputService.PreferredInput;
	const preferredPad = preferred === Enum.PreferredInput.Gamepad || preferred === Enum.PreferredInput.MicroGamepad;
	const consoleLike = UserInputService.GamepadEnabled && !UserInputService.MouseEnabled && !UserInputService.TouchEnabled;
	const tenFoot =
		desktop &&
		screenWidth >= 1280 &&
		screenHeight >= 720 &&
		(preferredPad || consoleLike || (UserInputService.GamepadEnabled && GuiService.ViewportDisplaySize === Enum.DisplaySize.Large));
	const scale = computeViewportScale(layoutWidth, layoutHeight);
	const scaledInset = vr ? 0 : math.max(0, math.ceil(insets.top / chromeScale));
	const bottomInset = keyboardOpen || vr ? 0 : math.max(0, math.ceil(insets.bottom / chromeScale));
	const sideInset = vr ? 0 : math.max(0, math.ceil(math.max(insets.left, insets.right) / chromeScale));
	const compact = layoutWidth < Breakpoints.compact;
	const tight = layoutWidth < Breakpoints.tight;
	const short = math.min(layoutHeight, screenHeight) < Breakpoints.short;
	const info = React.useMemo<ViewportInfo>(
		() => ({
			scale,
			width: layoutWidth,
			height: layoutHeight,
			topInset: scaledInset,
			bottomInset,
			sideInset,
			screenWidth,
			screenHeight,
			keyboardOpen,
			desktop,
			tenFoot,
			compact,
			tight,
			short,
		}),
		[bottomInset, compact, desktop, keyboardOpen, layoutHeight, layoutWidth, scale, scaledInset, screenHeight, screenWidth, short, sideInset, tenFoot, tight],
	);

	React.useEffect(() => {
		if (!keyboardOpen) {
			return undefined;
		}
		const attempts = [0.05, 0.16, 0.34].map((delay) => task.delay(delay, () => revealFocusedControl(safeOriginY + usableScreenHeight)));
		return () => {
			for (const attempt of attempts) {
				task.cancel(attempt);
			}
		};
	}, [keyboardOpen, layoutHeight, usableScreenHeight]);

	return (
		<frame ref={safeHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
			<frame
				Size={UDim2.fromOffset(layoutWidth, layoutHeight)}
				Position={new UDim2(0.5, 0, 0, tvSafe.top)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uiscale Scale={chromeScale} />
				<ViewportScaleContext.Provider value={info}>{props.children}</ViewportScaleContext.Provider>
			</frame>
		</frame>
	);
}
