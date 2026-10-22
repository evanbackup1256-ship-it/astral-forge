import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, TapTarget, chromeFor } from "../CoreKit/theme";
import { revealOffset, usePresence, useStagger, useViewport } from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { Button, IconTile, OverlayPresence, SegmentedTabs, Text, segmentedHeight, pixelPosition, useGamepadAutofocus, useGuiSize } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

const CATEGORIES = ["Bug", "Suggestion", "Balance", "Performance", "Interface", "Other"];
const CATEGORY_LABELS: Record<string, string> = { Suggestion: "Idea", Performance: "Lag", Interface: "UI" };
const CATEGORY_HINTS: Record<string, string> = {
	Bug: "What did you do, what did you expect, and what happened instead?",
	Suggestion: "What should we add or change, and why would it be fun?",
	Balance: "What feels too strong, too weak, too slow or too fast?",
	Performance: "Where does it lag or stutter? What were you doing at the time?",
	Interface: "Which screen or button is confusing, clipped or hard to reach?",
	Other: "Anything else on your mind. (8+ characters)",
};
const IMPACT_LABELS = ["Minor", "Noticeable", "Annoying", "Major", "Blocking"];

function deviceTag() {
	if (UserInputService.GamepadEnabled && !UserInputService.KeyboardEnabled) {
		return "Console";
	} else if (UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled) {
		return "Touch";
	}
	return "Desktop";
}

type Dispatch = (action: string, payload: object, callback?: (response: FeedbackResponse) => void) => void;
interface FeedbackResponse {
	ok?: boolean;
	error?: string;
	message?: string;
}

interface FeedbackOverlayProps {
	dispatch: Dispatch;
	reducedMotion?: boolean;
	onClose: () => void;
	notify: (title: string, body: string) => void;
	page?: unknown;
}

export function FeedbackOverlay(_param: FeedbackOverlayProps) {
	const dispatch = _param.dispatch;
	const reducedMotion = _param.reducedMotion;
	const softMotion = reducedMotion;
	const onClose = _param.onClose;
	const notify = _param.notify;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const narrow = viewport.width < 620;
	const compact = chrome.stack || narrow || viewport.height < 560;
	const keyboardCompact = viewport.keyboardOpen || viewport.height < 240;
	const wideShort = !narrow && viewport.height < 560;
	const [category, setCategory] = React.useState("Bug");
	const [impact, setImpact] = React.useState(0);
	const [attachDevice, setAttachDevice] = React.useState(true);
	const [message, setMessage] = React.useState("");
	const [sending, setSending] = React.useState(false);
	const [sent, setSent] = React.useState(false);
	const mountedRef = React.useRef(true);
	React.useEffect(() => {
		Audio.play("modalOpen");
		return () => {
			mountedRef.current = false;
		};
	}, []);
	const headerReveal = useStagger(0, softMotion);
	const footerReveal = useStagger(1, softMotion);
	const [motion, closing, beginExit] = usePresence(softMotion);
	const side = chrome.sideSafe + 16;
	const width = math.min(compact ? viewport.width - side * 2 : 620, 620);
	const safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - 16);
	const height = math.min(keyboardCompact ? 210 : wideShort ? 300 : compact ? 456 : 486, safeHeight);
	const contentHeight = math.max(1, height - 28);
	const headerH = keyboardCompact ? 46 : compact ? 64 : 72;
	const categoryTop = headerH + (keyboardCompact ? 0 : 8);
	const categoryColumns = narrow ? 3 : 6;
	const categoryH = keyboardCompact ? 0 : segmentedHeight(CATEGORIES.size(), categoryColumns, viewport, 44, 8);
	const impactTop = categoryTop + categoryH + 8;
	const impactH = keyboardCompact || sent ? 0 : narrow ? 30 + TapTarget + 4 : 30;
	const editorTop = keyboardCompact ? categoryTop + 6 : impactTop + impactH + (impactH > 0 ? 8 : 2);
	const footerH = TapTarget + (keyboardCompact ? 4 : 14);
	const editorH = math.max(44, contentHeight - editorTop - footerH - 8);
	const [trimmedStep] = string.gsub(message, "^%s+", "");
	const [trimmed] = string.gsub(trimmedStep, "%s+$", "");
	const canSend = !sending && !sent && trimmed.size() >= 8;
	const close = React.useCallback(() => {
		if (closing || sending) {
			return undefined;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, closing, onClose, sending]);
	useBackLayer(true, close);
	React.useEffect(() => {
		if (!sent) {
			return undefined;
		}
		const token = task.delay(2.4, () => {
			if (mountedRef.current && !closing) {
				beginExit(onClose);
			}
		});
		return () => task.cancel(token);
	}, [beginExit, closing, onClose, sent]);
	const submit = React.useCallback(() => {
		if (!canSend) {
			return undefined;
		}
		setSending(true);
		Audio.play("chatSend");
		const camera = game.GetService("Workspace").CurrentCamera;
		const viewSize = camera !== undefined ? camera.ViewportSize : Vector2.zero;
		dispatch(
			"SubmitFeedback",
			{
				Category: category,
				Message: trimmed,
				Impact: impact >= 1 ? impact : undefined,
				Device: attachDevice ? deviceTag() : undefined,
				Screen: attachDevice ? `${math.floor(viewSize.X)}x${math.floor(viewSize.Y)}` : undefined,
				Page:
					attachDevice && typeIs(_param.page, "string")
						? string.sub(_param.page as string, 1, 32)
						: undefined,
			},
			(response) => {
				if (!mountedRef.current) {
					return undefined;
				}
				setSending(false);
				if (!response.ok) {
					notify("Couldn't send feedback", response.error ?? response.message ?? "Give it a moment and try again.");
					Audio.play("noticeError");
					return undefined;
				}
				setSent(true);
				Audio.play("feedbackSubmit");
				notify("Feedback sent", "Thanks for helping make the game better.");
			},
		);
	}, [canSend, category, dispatch, notify, trimmed, impact, attachDevice]);
	const padFocus = useGamepadAutofocus(true);
	const overlayHostRef = React.useRef<GuiObject>();
	const parentSize = useGuiSize(overlayHostRef, true);
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = overlayHostRef.current ?? padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			task.cancel(job);
		};
	}, [sent]);
	const cardPosition = joinTuple(motion, parentSize).map(
		(values) => pixelPosition(values[1] as Vector2, 0.5, 0, 0.5, revealOffset(values[0] as number)),
	);
	const scrimTransparency = motion.map((amount) => 1 - amount * 0.72);
	const fade = motion.map((amount) => 1 - amount);
	const _exp = h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.void,
		BackgroundTransparency: scrimTransparency,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Active: true,
		Selectable: false,
		ZIndex: 470,
	});
	const _exp_1 = h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			Position: UDim2.fromOffset(0, 5),
			BackgroundColor3: Palette.shadow,
			BackgroundTransparency: 0.52,
			BorderSizePixel: 0,
			ZIndex: 471,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 12),
		}),
	);
	const _exp_2 = h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.panelRaised,
			BackgroundTransparency: fade,
			BorderSizePixel: 0,
			ZIndex: 472,
			ClipsDescendants: true,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 12),
		}),
		h("uistroke", {
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			LineJoinMode: Enum.LineJoinMode.Round,
			Color: sent ? Palette.mint : Palette.cyan,
			Thickness: 1,
			Transparency: motion.map((amount) => 0.55 - amount * 0.4),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(64, 2),
				Position: UDim2.fromOffset(20, 0),
				BackgroundColor3: sent ? Palette.mint : Palette.cyan,
				BorderSizePixel: 0,
			},
			h("uicorner", {
				CornerRadius: new UDim(1, 0),
			}),
		),
	);
	const _exp_3 =
		!keyboardCompact &&
		h(IconTile, {
			kind: sent ? "Check" : "Chat",
			accent: sent ? Palette.mint : Palette.cyan,
			size: compact ? 44 : 50,
			radius: 14,
			filled: sent,
			reveal: headerReveal,
			reducedMotion: softMotion,
			glow: sent && !softMotion,
		});
	const _exp_4 =
		!keyboardCompact &&
		h(Text, {
			value: sent ? "Thank you" : "Feedback",
			size: 11,
			color: sent ? Palette.mint : Palette.cyan,
			weight: Enum.FontWeight.Heavy,
			fit: false,
			position: UDim2.fromOffset(compact ? 56 : 62, 0),
			sizeConstraint: new UDim2(1, -116, 0, 16),
			zIndex: 474,
			transparency: headerReveal.map((amount) => 1 - amount),
		});
	const _exp_5 = h(Text, {
		value: sent ? "Got it. Thanks." : keyboardCompact ? "Send feedback" : "What's bugging you?",
		size: keyboardCompact ? 18 : compact ? 18 : 22,
		color: Palette.cream,
		weight: Enum.FontWeight.Heavy,
		fit: true,
		minSize: 15,
		position: UDim2.fromOffset(keyboardCompact ? 0 : compact ? 56 : 62, keyboardCompact ? 3 : 18),
		sizeConstraint: new UDim2(1, keyboardCompact ? -(TapTarget + 10) : -116, 0, 28),
		zIndex: 474,
	});
	const _exp_6 = h(Button, {
		text: "",
		icon: "Close.14",
		onClick: close,
		color: Palette.ink,
		textColor: Palette.coral,
		size: UDim2.fromOffset(TapTarget, TapTarget),
		position: new UDim2(1, -TapTarget, 0, 0),
		reducedMotion: softMotion,
		disabled: sending || closing,
	});
	let _condition: unknown = !sent && !keyboardCompact;
	if (_condition) {
		const _attributes: Record<string, unknown> = {};
		_attributes.options = CATEGORIES.map((choice) => ({
			id: choice,
			label: CATEGORY_LABELS[choice] ?? choice,
			accent: Palette.cyan,
		}));
		_attributes.value = category;
		_attributes.onChange = (id: string) => setCategory(id);
		_attributes.accent = Palette.cyan;
		_attributes.sound = "tabSwitch";
		_attributes.columns = categoryColumns;
		_attributes.gap = 6;
		_attributes.size = UDim2.fromScale(1, 1);
		_attributes.reducedMotion = softMotion;
		_attributes.zIndex = 475;
		_condition = h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, categoryH),
				Position: UDim2.fromOffset(0, categoryTop),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 474,
			},
			h(SegmentedTabs, _attributes),
		);
	}
	let impactRow: unknown = undefined;
	if (impactH > 0) {
		const impactAccent = impact >= 4 ? Palette.coral : impact >= 2 ? Palette.mango : Palette.cyan;
		const pips: Record<string, unknown> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				Padding: new UDim(0, 4),
				VerticalAlignment: Enum.VerticalAlignment.Center,
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		for (let level = 1; level <= 5; level++) {
			const lit = impact >= level;
			pips["pip" + level] = h(
				"textbutton",
				{
					Name: "Impact" + level,
					LayoutOrder: level,
					Size: UDim2.fromOffset(narrow ? math.min(TapTarget, (width - 28 - 16) / 5) : 28, narrow ? TapTarget : 30),
					BackgroundColor3: lit ? impactAccent : Palette.ink,
					BackgroundTransparency: lit ? 0.05 : 0.2,
					BorderSizePixel: 0,
					AutoButtonColor: false,
					Text: "",
					ZIndex: 476,
					Event: {
						Activated: () => {
							setImpact(impact === level ? 0 : level);
							Audio.play(impact === level ? "favoriteOff" : "ratingStar");
						},
					},
				},
				h("uicorner", {
					CornerRadius: new UDim(0, 8),
				}),
				h("uistroke", {
					Color: lit ? impactAccent : Palette.lineSoft,
					Transparency: lit ? 0.2 : 0.55,
				}),
				h(Text, {
					value: tostring(level),
					size: 13,
					color: lit ? Palette.ink : Palette.creamSoft,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Center,
					sizeConstraint: UDim2.fromScale(1, 1),
					zIndex: 477,
				}),
			);
		}
		impactRow = h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, impactH),
				Position: UDim2.fromOffset(0, impactTop),
				BackgroundTransparency: 1,
				ZIndex: 474,
			},
			h(Text, {
				value: impact >= 1 ? `Impact · ${IMPACT_LABELS[impact - 1]}` : "Impact · optional",
				size: 11,
				color: impact >= 1 ? impactAccent : Palette.muted,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(0, 7),
				sizeConstraint: new UDim2(0, narrow ? 120 : 170, 0, 16),
				zIndex: 475,
			}),
			h(
				"frame",
				{
					Size: narrow ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0, 160, 1, 0),
					Position: narrow ? UDim2.fromOffset(0, 30 + 4) : UDim2.fromOffset(170, 0),
					BackgroundTransparency: 1,
					ZIndex: 475,
				},
				pips,
			),
			h(
				"textbutton",
				{
					// 44px tall hit area, centred on the old 30px row
					Size: UDim2.fromOffset(narrow ? 92 : 150, 44),
					Position: new UDim2(1, 0, 0, -7),
					AnchorPoint: new Vector2(1, 0),
					BackgroundTransparency: 1,
					Text: "",
					ZIndex: 475,
					Event: {
						Activated: () => {
							setAttachDevice(!attachDevice);
							Audio.play(attachDevice ? "toggleOff" : "toggleOn");
						},
					},
				},
				h(
					"frame",
					{
						Size: UDim2.fromOffset(16, 16),
						Position: new UDim2(0, 0, 0.5, 0),
						AnchorPoint: new Vector2(0, 0.5),
						BackgroundColor3: attachDevice ? Palette.cyan : Palette.ink,
						BorderSizePixel: 0,
						ZIndex: 476,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, 8),
					}),
					h("uistroke", {
						Color: Palette.cyan,
						Transparency: 0.35,
					}),
				),
				h(Text, {
					value: narrow ? "Device info" : "Attach device info",
					size: 11,
					color: attachDevice ? Palette.creamSoft : Palette.muted,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(22, 7),
					sizeConstraint: new UDim2(1, -22, 0, 16),
					zIndex: 476,
				}),
			),
		);
	}
	return h(
		OverlayPresence,
		{
			amount: motion,
		},
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 470,
				Visible: motion.map((amount) => amount > 0.003),
			},
			_exp,
			h(
				"frame",
				{
					ref: (node: GuiObject | undefined) => {
						padFocus.current = node;
						overlayHostRef.current = node;
					},
					Size: UDim2.fromOffset(width, height),
					Position: cardPosition,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 471,
					Visible: motion.map((amount) => amount > 0.002),
				},
				h(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 471,
					},
					_exp_1,
					_exp_2,
					h(
						"frame",
						{
							Size: new UDim2(1, -32, 1, -28),
							Position: UDim2.fromOffset(16, 14),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ZIndex: 473,
						},
						_exp_3,
						_exp_4,
						_exp_5,
						_exp_6,
						_condition,
						impactRow,
						!sent &&
							h(
								"frame",
								{
									Size: new UDim2(1, 0, 0, editorH),
									Position: UDim2.fromOffset(0, editorTop),
									BackgroundColor3: Palette.ink,
									BackgroundTransparency: 0.08,
									BorderSizePixel: 0,
									ZIndex: 474,
								},
								h("uicorner", {
									CornerRadius: new UDim(0, 12),
								}),
								h("uistroke", {
									ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
									LineJoinMode: Enum.LineJoinMode.Round,
									Color: Palette.lineSoft,
									Thickness: 1,
									Transparency: 0.45,
								}),
								h("textbox", {
									Size: new UDim2(1, -24, 1, -38),
									Position: UDim2.fromOffset(12, 10),
									BackgroundTransparency: 1,
									BorderSizePixel: 0,
									Text: message,
									PlaceholderText: CATEGORY_HINTS[category] ?? "What happened, or what should we add? (8+ characters)",
									PlaceholderColor3: Palette.muted,
									TextColor3: Palette.cream,
									TextSize: 15,
									FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
									TextXAlignment: Enum.TextXAlignment.Left,
									TextYAlignment: Enum.TextYAlignment.Top,
									TextWrapped: true,
									MultiLine: true,
									ClearTextOnFocus: false,
									TextEditable: !sending,
									MaxVisibleGraphemes: 600,
									ZIndex: 475,
									Change: {
										Text: (box: TextBox) => {
											const trimmed = string.sub(box.Text, 1, 600);
											const [, brokenAt] = utf8.len(trimmed);
											return setMessage(brokenAt !== undefined ? string.sub(trimmed, 1, brokenAt - 1) : trimmed);
										},
									},
									Event: {
										Focused: () => Audio.play("inputFocus"),
									},
								}),
								h(Text, {
									value:
										trimmed.size() < 8
											? `${math.max(0, 8 - trimmed.size())} more to send  ·  ${message.size()} / 600`
											: `${message.size()} / 600`,
									size: 11,
									color: trimmed.size() < 8 ? Palette.mango : message.size() >= 580 ? Palette.mango : Palette.muted,
									align: Enum.TextXAlignment.Right,
									fit: false,
									position: new UDim2(0, 12, 1, -26),
									sizeConstraint: new UDim2(1, -24, 0, 16),
									zIndex: 475,
								}),
							),
						sent
							? h(Button, {
									text: "Done",
									icon: "Check.25",
									onClick: close,
									color: Palette.mint,
									textColor: Palette.ink,
									size: new UDim2(1, 0, 0, TapTarget),
									position: footerReveal.map(
										(amount) => new UDim2(0, 0, 1, -TapTarget + math.round((1 - amount) * 10)),
									),
									reducedMotion: softMotion,
									highlight: true,
								})
							: h(Button, {
									text: sending ? "Sending..." : trimmed.size() < 8 ? "Write a little more" : "Send feedback",
									icon: "Send.5",
									onClick: submit,
									color: canSend ? Palette.cyan : Palette.panelSoft,
									textColor: canSend ? Palette.ink : Palette.muted,
									size: new UDim2(1, 0, 0, TapTarget),
									position: footerReveal.map(
										(amount) => new UDim2(0, 0, 1, -TapTarget + math.round((1 - amount) * 10)),
									),
									disabled: !canSend,
									reducedMotion: softMotion,
									highlight: canSend && !softMotion,
								}),
					),
				),
			),
		),
	);
}
