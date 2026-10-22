import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, Space, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "../MotionKit/motion";
import { AutoHeightText, Button, OverlayPresence, Panel, Text, measureWrappedTextHeight, useGamepadAutofocus } from "../UiCore/ui";

const ContextActionService = game.GetService("ContextActionService");

/**
 * The one confirm/modal surface. Anything that needs a "really do this?" step asks for it here
 * instead of growing its own tap-twice button. Open/close motion is the shared usePresence
 * spring + revealOffset rise, same as ReleaseNotesModal and every other overlay.
 */
export type ConfirmTone = "danger" | "neutral" | "accent";

export interface ConfirmRequest {
	title: string;
	body?: string;
	confirmText?: string;
	cancelText?: string;
	tone?: ConfirmTone;
	onConfirm: () => void;
	onCancel?: () => void;
}

type Listener = (request: ConfirmRequest | undefined) => void;
let current: ConfirmRequest | undefined;
const listeners = new Set<Listener>();
function publish(request: ConfirmRequest | undefined) {
	current = request;
	for (const listener of listeners) {
		listener(request);
	}
}

/** Ask the player to confirm. A newer request replaces an open one (the old one counts as cancelled). */
export function requestConfirm(request: ConfirmRequest) {
	const previous = current;
	publish(request);
	if (previous !== undefined && previous.onCancel !== undefined) {
		previous.onCancel();
	}
}

function toneColor(tone: ConfirmTone | undefined): Color3 {
	return tone === "danger" ? Palette.coral : tone === "accent" ? Palette.violet : Palette.brass;
}

export interface ConfirmDialogProps extends Omit<ConfirmRequest, "onConfirm" | "onCancel"> {
	reducedMotion?: boolean;
	zIndex?: number;
	/** runs after the close animation with the player's answer */
	onResolve: (confirmed: boolean) => void;
	children?: React.ReactNode;
}

export function ConfirmDialog(props: ConfirmDialogProps) {
	const viewport = useViewport();
	const z = props.zIndex ?? 700;
	const accent = toneColor(props.tone);
	const [reveal, exiting, beginExit] = usePresence(props.reducedMotion);
	const settled = React.useRef(false);
	const resolve = React.useCallback(
		(confirmed: boolean) => {
			if (settled.current) {
				return;
			}
			settled.current = true;
			Audio.play(confirmed ? "confirm" : "close");
			beginExit(() => props.onResolve(confirmed));
		},
		[beginExit, props.onResolve],
	);
	const resolveRef = React.useRef(resolve);
	resolveRef.current = resolve;
	React.useEffect(() => {
		Audio.play("modalOpen");
		GamepadNavigationService.BeginOverlayFocus();
		const actionName = "AstralForgeConfirmCancel";
		ContextActionService.BindActionAtPriority(
			actionName,
			(_name, inputState) => {
				if (inputState === Enum.UserInputState.Begin) {
					resolveRef.current(false);
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2400,
			Enum.KeyCode.ButtonB,
		);
		return () => {
			ContextActionService.UnbindAction(actionName);
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);
	const focus = useGamepadAutofocus(true);

	const safeSide = math.max(Space.md, viewport.sideInset);
	const width = math.clamp(viewport.width - safeSide * 2, 240, 420);
	const padding = width < 320 ? Space.lg : Space.xl;
	const inner = width - padding * 2;
	const stackButtons = inner < 300;
	const titleH = math.max(26, measureWrappedTextHeight(props.title, inner, 20, Enum.FontWeight.Bold));
	const bodyH = props.body !== undefined ? measureWrappedTextHeight(props.body, inner, 14) : 0;
	const actionsH = stackButtons ? TapTarget * 2 + Space.sm : TapTarget;
	const bodyGap = props.body !== undefined ? Space.sm : 0;
	const maxH = math.max(200, viewport.height - math.max(Space.lg, viewport.topInset) - math.max(Space.lg, viewport.bottomInset));
	const height = math.min(maxH, padding * 2 + titleH + bodyGap + bodyH + Space.xl + actionsH);
	const confirmText = props.confirmText ?? "Confirm";
	const cancelText = props.cancelText ?? "Cancel";
	const buttonW = stackButtons ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0.5, -Space.sm / 2, 0, TapTarget);

	return (
		<OverlayPresence amount={reveal}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={z} Visible={reveal.map((a) => a > 0.01)}>
				<imagebutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={Palette.void}
					BackgroundTransparency={reveal.map((a) => 1 - a * 0.8)}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Active={true}
					Selectable={false}
					ZIndex={z + 1}
					Event={{ Activated: () => resolve(false) }}
				/>
				<frame
					ref={focus as React.Ref<Frame>}
					Size={UDim2.fromOffset(width, height)}
					Position={reveal.map((a) => new UDim2(0.5, 0, 0.5, revealOffset(a)))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={z + 2}
				>
					<imagebutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} AutoButtonColor={false} Active={true} Selectable={false} ZIndex={z + 2} />
					<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panelRaised} padding={padding} zIndex={z + 3} reveal={reveal} reducedMotion={props.reducedMotion}>
						<AutoHeightText value={props.title} size={20} weight={Enum.FontWeight.Bold} color={Palette.cream} width={inner} zIndex={z + 4} />
						{props.body !== undefined && (
							<frame Size={new UDim2(1, 0, 0, bodyH)} Position={UDim2.fromOffset(0, titleH + bodyGap)} BackgroundTransparency={1} ZIndex={z + 4}>
								<Text value={props.body} size={14} color={Palette.creamSoft} wrap={true} sizeConstraint={UDim2.fromScale(1, 1)} zIndex={z + 4} />
							</frame>
						)}
						{props.children}
						<frame Size={new UDim2(1, 0, 0, actionsH)} Position={new UDim2(0, 0, 1, -actionsH)} BackgroundTransparency={1} ZIndex={z + 5}>
							<Button
								text={cancelText}
								onClick={() => resolve(false)}
								color={Palette.panelSoft}
								textColor={Palette.cream}
								outline={true}
								size={buttonW}
								position={stackButtons ? UDim2.fromOffset(0, TapTarget + Space.sm) : UDim2.fromScale(0, 0)}
								disabled={exiting}
								reducedMotion={props.reducedMotion}
								sound={false}
								zIndex={z + 5}
							/>
							<Button
								text={confirmText}
								onClick={() => resolve(true)}
								color={accent}
								textColor={Palette.ink}
								highlight={true}
								size={buttonW}
								position={stackButtons ? UDim2.fromScale(0, 0) : new UDim2(0.5, Space.sm / 2, 0, 0)}
								disabled={exiting}
								reducedMotion={props.reducedMotion}
								sound={false}
								zIndex={z + 5}
							/>
						</frame>
					</Panel>
				</frame>
			</frame>
		</OverlayPresence>
	);
}

/** Mount once near the app root; renders whatever requestConfirm last asked for. */
export function ConfirmHost(props: { reducedMotion?: boolean }) {
	const [request, setRequest] = React.useState<ConfirmRequest | undefined>(current);
	const [serial, setSerial] = React.useState(0);
	React.useEffect(() => {
		const listener: Listener = (incoming) => {
			setRequest(incoming);
			setSerial((n) => n + 1);
		};
		listeners.add(listener);
		return () => {
			listeners.delete(listener);
		};
	}, []);
	if (request === undefined) {
		return undefined;
	}
	return (
		<ConfirmDialog
			key={`confirm${serial}`}
			title={request.title}
			body={request.body}
			confirmText={request.confirmText}
			cancelText={request.cancelText}
			tone={request.tone}
			reducedMotion={props.reducedMotion}
			onResolve={(confirmed) => {
				if (current === request) {
					publish(undefined);
				}
				if (confirmed) {
					request.onConfirm();
				} else if (request.onCancel !== undefined) {
					request.onCancel();
				}
			}}
		/>
	);
}
