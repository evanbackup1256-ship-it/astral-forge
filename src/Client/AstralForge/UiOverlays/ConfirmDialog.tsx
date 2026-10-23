import { named } from "../lua";
import { useFocusOrder } from "../CoreKit/focusOrder";
import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, Space, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, Panel, TITLE_FACE, Text, measureWrappedTextHeight, useGamepadAutofocus } from "../UiCore/ui";
import { Glyph, spaced } from "../UiCore/mockKit";

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
	/** requests with the same key collapse into one: a repeat refreshes the queued one */
	key?: string;
	/** old behaviour: drop the open and queued requests (they count as cancelled) */
	replace?: boolean;
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

// Requests queue first in, first out; the next one opens after the previous dialog has closed.
const queue: ConfirmRequest[] = [];

function sameKey(a: ConfirmRequest | undefined, b: ConfirmRequest): boolean {
	return a !== undefined && b.key !== undefined && a.key === b.key;
}

function advance() {
	publish(queue.shift());
}

/**
 * Ask the player to confirm. If a dialog is already open the request waits its turn instead of
 * cancelling it (a crew kick and an echo break landing together both get answered). A request
 * whose `key` matches the open one is dropped; one matching a queued request replaces it in place.
 */
export function requestConfirm(request: ConfirmRequest) {
	if (request.replace === true) {
		const dropped = [current, ...queue];
		queue.clear();
		publish(request);
		for (const old of dropped) {
			if (old !== undefined && old.onCancel !== undefined) {
				old.onCancel();
			}
		}
		return;
	}
	if (sameKey(current, request)) {
		return;
	}
	const index = queue.findIndex((queued) => sameKey(queued, request));
	if (index >= 0) {
		queue[index] = request;
		return;
	}
	if (current === undefined) {
		publish(request);
	} else {
		queue.push(request);
	}
}

/** how many confirms are waiting behind the open one */
export function pendingConfirms(): number {
	return queue.size();
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
	// focus lands when the open motion settles, inside the card's selection group
	const focus = useGamepadAutofocus(true, reveal);
	// pad starts on Cancel (the safe choice, as before); Cancel and Confirm are linked both ways
	useFocusOrder(focus, { regions: ["ConfirmCancel", "ConfirmOk"], first: ["ConfirmCancel"], columns: [["ConfirmCancel", "ConfirmOk"]] }, []);

	const safeSide = math.max(Space.md, viewport.sideInset);
	const width = math.clamp(viewport.width - safeSide * 2, math.min(240, viewport.width - 16), 420);
	const padding = width < 320 ? Space.lg : Space.xl;
	const inner = width - padding * 2;
	const stackButtons = inner < 300;
	const titleH = math.max(22, measureWrappedTextHeight(props.title.upper(), inner - 60, 15, Enum.FontWeight.Heavy));
	// measured at the width the body really wraps at (the 6px scrollbar gutter comes off the frame below)
	const bodyH = props.body !== undefined ? measureWrappedTextHeight(props.body, inner - 6, 14) : 0;
	const actionsH = stackButtons ? TapTarget * 2 + Space.sm : TapTarget;
	const bodyGap = props.body !== undefined ? Space.sm : 0;
	const maxH = math.max(200, viewport.height - math.max(Space.lg, viewport.topInset) - math.max(Space.lg, viewport.bottomInset));
	const height = math.min(maxH, padding * 2 + titleH + bodyGap + bodyH + Space.xl + actionsH);
	// a long body on a short screen (640x286) scrolls above the buttons instead of running under them
	const bodyRoom = math.max(0, math.min(bodyH, height - padding * 2 - titleH - bodyGap - Space.xl - actionsH));
	const confirmText = props.confirmText ?? "Confirm";
	const cancelText = props.cancelText ?? (props.tone === "danger" ? "Keep" : "Cancel");
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
					SelectionGroup={true}
					SelectionBehaviorUp={Enum.SelectionBehavior.Stop}
					SelectionBehaviorDown={Enum.SelectionBehavior.Stop}
					SelectionBehaviorLeft={Enum.SelectionBehavior.Stop}
					SelectionBehaviorRight={Enum.SelectionBehavior.Stop}
					Size={UDim2.fromOffset(width, height)}
					Position={reveal.map((a) => new UDim2(0.5, 0, 0.5, revealOffset(a)))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={z + 2}
				>
					<imagebutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} AutoButtonColor={false} Active={true} Selectable={false} ZIndex={z + 2} />
					<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panel} padding={padding} radius={18} rule={true} zIndex={z + 3} reveal={reveal} reducedMotion={props.reducedMotion}>
						{/* 26-dialogs .pn h3: tone glyph, Cinzel caps title, close X pushed right */}
						<Glyph kind={props.tone === "danger" ? "Warning" : "Info"} size={18} color={accent} position={UDim2.fromOffset(0, 2)} />
						<frame Size={new UDim2(1, -60, 0, titleH)} Position={UDim2.fromOffset(28, 0)} BackgroundTransparency={1} ZIndex={z + 4}>
							<textlabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text={spaced(props.title.upper())} TextSize={15} FontFace={TITLE_FACE} TextColor3={Palette.cream} TextWrapped={true} TextXAlignment={Enum.TextXAlignment.Left} TextYAlignment={Enum.TextYAlignment.Top} ZIndex={z + 4} />
						</frame>
						<textbutton
							Size={UDim2.fromOffset(44, 44)}
							Position={new UDim2(1, 10, 0, -11)}
							AnchorPoint={new Vector2(1, 0)}
							BackgroundTransparency={1}
							Text=""
							AutoButtonColor={false}
							Selectable={false}
							ZIndex={z + 5}
							Event={{ Activated: () => resolve(false) }}
						>
							<Glyph kind="Close" size={18} color={Palette.muted} position={UDim2.fromOffset(13, 13)} />
						</textbutton>
						{props.body !== undefined && (
							<scrollingframe
								Size={new UDim2(1, 0, 0, bodyRoom)}
								Position={UDim2.fromOffset(0, titleH + bodyGap)}
								CanvasSize={UDim2.fromOffset(0, bodyH)}
								ScrollingEnabled={bodyRoom < bodyH}
								ScrollBarThickness={bodyRoom < bodyH ? 3 : 0}
								ScrollBarImageColor3={Palette.muted}
								ScrollingDirection={Enum.ScrollingDirection.Y}
								Selectable={false}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								ZIndex={z + 4}
							>
								<frame Size={new UDim2(1, -6, 0, bodyH)} BackgroundTransparency={1} ZIndex={z + 4}>
									<Text value={props.body} size={14} color={Palette.creamSoft} wrap={true} sizeConstraint={UDim2.fromScale(1, 1)} zIndex={z + 4} />
								</frame>
							</scrollingframe>
						)}
						{props.children}
						<frame Size={new UDim2(1, 0, 0, actionsH)} Position={new UDim2(0, 0, 1, -actionsH)} BackgroundTransparency={1} ZIndex={z + 5}>
							<frame {...named("ConfirmCancel")} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={z + 5}>
							<Button
								text={cancelText}
								onClick={() => resolve(false)}
								color={Color3.fromRGB(58, 46, 62)}
								textColor={Palette.cream}
								size={buttonW}
								position={stackButtons ? UDim2.fromOffset(0, TapTarget + Space.sm) : UDim2.fromScale(0, 0)}
								disabled={exiting}
								reducedMotion={props.reducedMotion}
								sound={false}
								zIndex={z + 5}
							/>
							</frame>
							<frame {...named("ConfirmOk")} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={z + 5}>
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
						</frame>
					</Panel>
				</frame>
			</frame>
		</OverlayPresence>
	);
}

/** Mount once near the app root; shows the queued confirms one at a time. */
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
					advance();
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
