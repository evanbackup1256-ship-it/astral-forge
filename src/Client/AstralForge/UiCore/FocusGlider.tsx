// One focus ring for the whole game (gamepad and keyboard). Instead of every control fading its own
// ring in and out, a single ring follows GuiService.SelectedObject and springs from the old control
// to the new one, so you can see where focus went. It hugs the control's own corner radius, snaps in
// when focus first appears, fades when it leaves, and only ticks while something is selected.
import React from "@rbxts/react";
import { Layout, Palette } from "../CoreKit/theme";
import { subscribeContinuous } from "../MotionKit/motion";
import { hiddenSelectionImage } from "./ui";

const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");

// the ring sits this far outside the control
const RING_GAP = 3;
const RING_THICKNESS = 2.5;
// position/size spring: ~6.5 Hz with a touch of overshoot, so a long jump lands with a small settle
const FREQUENCY = 6.5;
const DAMPING_RATIO = 0.82;
const FADE_PER_SECOND = 9;

interface Axis {
	x: number;
	v: number;
}

/** One semi-implicit spring step toward `target`. */
function stepAxis(axis: Axis, target: number, dt: number) {
	const omega = 2 * math.pi * FREQUENCY;
	axis.v += (omega * omega * (target - axis.x) - 2 * DAMPING_RATIO * omega * axis.v) * dt;
	axis.x += axis.v * dt;
}

/** The control's own corner, so the ring follows its shape (kit Buttons round their surface child). */
function cornerOf(target: GuiObject): UDim {
	const corner = target.FindFirstChildOfClass("UICorner") ?? target.FindFirstChildWhichIsA("UICorner", true);
	return corner !== undefined ? corner.CornerRadius : new UDim(0, Layout.buttonRadius);
}

/** False when the control or anything above it is hidden: a selection can outlive the UI being put away. */
function onScreen(target: GuiObject): boolean {
	let node: Instance | undefined = target;
	while (node !== undefined) {
		if (node.IsA("GuiObject")) {
			if (!node.Visible) return false;
		} else if (node.IsA("LayerCollector")) {
			return node.Enabled;
		}
		node = node.Parent;
	}
	return false;
}

export function FocusGlider({ reducedMotion }: { reducedMotion?: boolean }) {
	const hostRef = React.useRef<Frame>();
	const [rect, setRect] = React.useBinding([0, 0, 0, 0] as [number, number, number, number]);
	const [alpha, setAlpha] = React.useBinding(0);
	const [corner, setCorner] = React.useState(new UDim(0, Layout.buttonRadius));
	const reducedRef = React.useRef(reducedMotion === true);
	reducedRef.current = reducedMotion === true;

	// controls draw no selection box of their own: the glider is the one focus mark
	React.useEffect(() => {
		const playerGui = Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
		if (playerGui === undefined) return undefined;
		const before = playerGui.SelectionImageObject;
		playerGui.SelectionImageObject = hiddenSelectionImage();
		return () => {
			if (playerGui.SelectionImageObject === hiddenSelectionImage()) playerGui.SelectionImageObject = before;
		};
	}, []);

	React.useEffect(() => {
		const axes: Axis[] = [
			{ x: 0, v: 0 },
			{ x: 0, v: 0 },
			{ x: 0, v: 0 },
			{ x: 0, v: 0 },
		];
		let shown = 0;
		let lastTarget: GuiObject | undefined;
		let release: (() => void) | undefined;
		const tick = (dt: number) => {
			const host = hostRef.current;
			const target = GuiService.SelectedObject;
			const live = target !== undefined && host !== undefined && target.IsDescendantOf(game) && onScreen(target);
			if (live) {
				const origin = host.AbsolutePosition;
				const at = target.AbsolutePosition;
				const size = target.AbsoluteSize;
				const goal = [at.X - origin.X - RING_GAP, at.Y - origin.Y - RING_GAP, size.X + RING_GAP * 2, size.Y + RING_GAP * 2];
				// focus appearing from nothing (or reduced motion) lands in place; moving between controls glides
				const snap = shown <= 0.01 || reducedRef.current;
				for (let i = 0; i < 4; i++) {
					if (snap) {
						axes[i].x = goal[i];
						axes[i].v = 0;
					} else {
						stepAxis(axes[i], goal[i], math.min(dt, 1 / 30));
					}
				}
				if (target !== lastTarget) {
					lastTarget = target;
					setCorner(cornerOf(target));
				}
				shown = math.min(1, shown + dt * FADE_PER_SECOND);
			} else {
				shown = math.max(0, shown - dt * FADE_PER_SECOND);
			}
			setRect([axes[0].x, axes[1].x, math.max(0, axes[2].x), math.max(0, axes[3].x)]);
			setAlpha(shown);
			// nothing selected and fully faded: stop ticking until focus comes back
			if (target === undefined && shown <= 0 && release !== undefined) {
				release();
				release = undefined;
			}
		};
		const wake = () => {
			if (release === undefined && GuiService.SelectedObject !== undefined) release = subscribeContinuous(tick);
		};
		wake();
		const selection = GuiService.GetPropertyChangedSignal("SelectedObject").Connect(wake);
		return () => {
			selection.Disconnect();
			release?.();
		};
	}, []);

	return (
		<frame {...{ Name: "FocusGlider" }} ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false} ZIndex={9000}>
			<frame
				Position={rect.map(([x, y]) => UDim2.fromOffset(math.round(x), math.round(y)))}
				Size={rect.map(([, , w, h]) => UDim2.fromOffset(math.round(w), math.round(h)))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Active={false}
				Visible={alpha.map((a) => a > 0.01)}
				ZIndex={9000}
			>
				<uicorner CornerRadius={new UDim(corner.Scale, corner.Offset + RING_GAP)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={Palette.cream}
					Thickness={RING_THICKNESS}
					Transparency={alpha.map((a) => 1 - a * 0.95)}
				/>
			</frame>
		</frame>
	);
}
