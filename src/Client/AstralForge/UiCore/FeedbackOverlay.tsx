import { useFocusOrder } from "../CoreKit/focusOrder";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, TapTarget, chromeFor } from "../CoreKit/theme";
import { revealOffset, usePresence, useStagger, useViewport } from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { Glyph, Line, spaced } from "./mockKit";
import { Button, OverlayPresence, TITLE_FACE, SegmentedTabs, Text, segmentedHeight, pixelPosition, useGamepadAutofocus, useGuiSize } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

const CATEGORIES = ["Bug", "Balance", "Interface", "Performance", "Suggestion", "Other"];
const CATEGORY_LABELS: Record<string, string> = { Suggestion: "Idea" };
const CATEGORY_HINTS: Record<string, string> = {
	Bug: "What did you do, what did you expect, and what happened instead?",
	Suggestion: "What should we add or change, and why would it be fun?",
	Balance: "What feels too strong, too weak, too slow or too fast?",
	Performance: "Where does it lag or stutter? What were you doing at the time?",
	Interface: "Which screen or button is confusing, clipped or hard to reach?",
	Other: "Anything else on your mind. (8+ characters)",
};
const IMPACT_LABELS = ["Minor", "Noticeable", "Annoying", "Major", "Blocking"];
// one tab per step of the server's 1-5 impact scale
const IMPACT_TABS = [1, 2, 3, 4, 5];
const ACCENT = Palette.brass;

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
	const [impact, setImpact] = React.useState(2);
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
	useStagger(0, softMotion);
	const footerReveal = useStagger(1, softMotion);
	const [motion, closing, beginExit] = usePresence(softMotion);
	const side = chrome.sideSafe + 16;
	const width = math.min(viewport.width - side * 2, compact ? 600 : 700);
	const safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - 16);
	const height = math.min(keyboardCompact ? 210 : wideShort ? 300 : compact ? 456 : 486, safeHeight);
	const contentHeight = math.max(1, height - 28);
	const headerH = keyboardCompact ? 46 : compact ? 30 : 34;
	const categoryTop = headerH + (keyboardCompact ? 0 : 22);
	const categoryColumns = narrow ? 3 : 6;
	const categoryH = keyboardCompact ? 0 : segmentedHeight(CATEGORIES.size(), categoryColumns, viewport, 44, 8);
	const impactTop = categoryTop + categoryH + 8;
	// narrow screens wrap the five impact tabs onto two rows
	const impactColumns = narrow ? 3 : IMPACT_TABS.size();
	const impactTabsH = segmentedHeight(IMPACT_TABS.size(), impactColumns, viewport, 44, 8);
	const impactH = keyboardCompact || sent ? 0 : 22 + impactTabsH;
	const editorTop = keyboardCompact ? categoryTop + 6 : impactTop + impactH + (impactH > 0 ? 8 : 2);
	const footerH = TapTarget + (keyboardCompact ? 4 : 14) + (narrow && !sent ? TapTarget + 6 : 0);
	const editorH = math.max(44, contentHeight - editorTop - footerH - 8);
	// 640x286 landscape (and any other short window) can't fit header, categories, impact, the 44px
	// editor floor and the footer: the card body scrolls instead of clipping the Send button
	const bodyNeededH = editorTop + editorH + 8 + footerH;
	const bodyScrolls = bodyNeededH > contentHeight + 1;
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
	const padFocus = useGamepadAutofocus(true, motion);
	useFocusOrder(
		padFocus,
		{
			regions: ["FeedbackClose", "FeedbackCategories", "FeedbackImpact", "FeedbackBody"],
			first: ["FeedbackCategories", "FeedbackBody"],
		},
		[sent, keyboardCompact, narrow],
	);
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
			CornerRadius: new UDim(0, 18),
		}),
	);
	const _exp_2 = h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.panel,
			BackgroundTransparency: fade,
			BorderSizePixel: 0,
			ZIndex: 472,
			ClipsDescendants: true,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 18),
		}),
		h(
			"frame",
			{ Size: new UDim2(1, -8, 1, -8), Position: UDim2.fromOffset(4, 4), BackgroundTransparency: 1, BorderSizePixel: 0 },
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uistroke", { Color: Palette.brass, Thickness: 1, Transparency: 0.75 }),
		),
		h("uistroke", {
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			LineJoinMode: Enum.LineJoinMode.Round,
			Color: sent ? Palette.mint : Palette.line,
			Thickness: 1,
			Transparency: motion.map((amount) => 0.55 - amount * 0.4),
		}),
	);
	// 23-feedback .pn h3: glyph, Cinzel caps title, close X on the right
	const _exp_3 = !keyboardCompact && h(Glyph, { kind: sent ? "Check" : "Chat", size: 18, color: sent ? Palette.mint : Palette.mango, position: UDim2.fromOffset(0, 2 + math.floor((TapTarget - 22) / 2)) });
	const _exp_4 =
		!sent &&
		!keyboardCompact &&
		h(Line, { text: spaced("TYPE"), size: 12, font: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold), color: Palette.muted, position: UDim2.fromOffset(0, headerH + 2), zIndex: 475 });
	const _exp_5 = h("textlabel", {
		Text: spaced((sent ? "Thank you" : "Feedback").upper()),
		TextSize: 15,
		FontFace: TITLE_FACE,
		TextColor3: Palette.cream,
		TextXAlignment: Enum.TextXAlignment.Left,
		BackgroundTransparency: 1,
		Position: UDim2.fromOffset(keyboardCompact ? 0 : 28, math.floor((TapTarget - 22) / 2)),
		Size: new UDim2(1, -(TapTarget + 40), 0, 22),
		ZIndex: 474,
	});
	const _exp_6 = h(
		"frame",
		{ Name: "FeedbackClose", Size: new UDim2(1, 0, 0, TapTarget), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 474 },
		h(Button, {
		text: "",
		icon: "Close.14",
		onClick: close,
		color: Palette.panel,
		textColor: Palette.muted,
		size: UDim2.fromOffset(TapTarget, TapTarget),
		position: new UDim2(1, -TapTarget, 0, 0),
		reducedMotion: softMotion,
		disabled: sending || closing,
		}),
	);
	let _condition: unknown = !sent && !keyboardCompact;
	if (_condition) {
		const _attributes: Record<string, unknown> = {};
		_attributes.options = CATEGORIES.map((choice) => ({
			id: choice,
			label: CATEGORY_LABELS[choice] ?? choice,
			accent: ACCENT,
		}));
		_attributes.value = category;
		_attributes.onChange = (id: string) => setCategory(id);
		_attributes.accent = ACCENT;
		_attributes.sound = "tabSwitch";
		_attributes.columns = categoryColumns;
		_attributes.gap = 6;
		_attributes.size = UDim2.fromScale(1, 1);
		_attributes.reducedMotion = softMotion;
		_attributes.zIndex = 475;
		_condition = h(
			"frame",
			{
				Name: "FeedbackCategories",
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
		impactRow = h(
			"frame",
			{ Name: "FeedbackImpact", Size: new UDim2(1, 0, 0, impactH), Position: UDim2.fromOffset(0, impactTop), BackgroundTransparency: 1, ZIndex: 474 },
			h(Line, { text: spaced("IMPACT"), size: 12, font: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold), color: Palette.muted, zIndex: 475 }),
			h(
				"frame",
				{ Size: new UDim2(1, 0, 0, impactTabsH), Position: UDim2.fromOffset(0, 22), BackgroundTransparency: 1, ZIndex: 475 },
				h(SegmentedTabs, {
					options: IMPACT_TABS.map((level) => ({ id: tostring(level), label: IMPACT_LABELS[level - 1], accent: ACCENT })),
					value: tostring(impact),
					onChange: (id: string) => setImpact(tonumber(id) ?? 2),
					accent: ACCENT,
					sound: "tabSwitch",
					columns: impactColumns,
					gap: 6,
					size: UDim2.fromScale(1, 1),
					reducedMotion: softMotion,
					zIndex: 476,
				}),
			),
		);
	}
	const deviceChipW = narrow ? width - 32 : 170;
	const deviceChip =
		!sent &&
		h(
			"textbutton",
			{
				Name: "FeedbackDevice",
				Size: UDim2.fromOffset(deviceChipW, TapTarget),
				Position: narrow ? new UDim2(0, 0, 1, -(TapTarget * 2 + 6)) : new UDim2(0, 0, 1, -TapTarget),
				BackgroundColor3: attachDevice ? Palette.mango : Palette.white,
				BackgroundTransparency: attachDevice ? 0.8 : 0.95,
				AutoButtonColor: false,
				BorderSizePixel: 0,
				Text: "",
				ZIndex: 475,
				Event: {
					Activated: () => {
						setAttachDevice(!attachDevice);
						Audio.play(attachDevice ? "toggleOff" : "toggleOn");
					},
				},
			},
			h("uicorner", { CornerRadius: new UDim(0, 8) }),
			h("uistroke", { Color: attachDevice ? Palette.mango : Palette.white, Transparency: attachDevice ? 0.4 : 0.9, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
			h(Text, {
				value: (attachDevice ? "✓  " : "") + "Attach device info",
				size: 12,
				color: attachDevice ? Palette.cream : Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Center,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(8, 14),
				sizeConstraint: new UDim2(1, -16, 0, 16),
				zIndex: 476,
			}),
		);
	const sendW = narrow ? width - 32 : 220;
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
						bodyScrolls ? "scrollingframe" : "frame",
						{
							Name: "FeedbackBody",
							Size: new UDim2(1, -32, 1, -28),
							Position: UDim2.fromOffset(16, 14),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ZIndex: 473,
							...(bodyScrolls
								? {
										CanvasSize: UDim2.fromOffset(0, bodyNeededH),
										ScrollingDirection: Enum.ScrollingDirection.Y,
										ScrollBarThickness: 3,
										ScrollBarImageColor3: ACCENT,
									}
								: {}),
						},
						_exp_3,
						_exp_4,
						_exp_5,
						_exp_6,
						_condition,
						impactRow,
						deviceChip,
						!sent &&
							h(
								"frame",
								{
									Size: new UDim2(1, 0, 0, editorH),
									Position: UDim2.fromOffset(0, editorTop),
									BackgroundColor3: Color3.fromRGB(0, 0, 0),
									BackgroundTransparency: 0.65,
									BorderSizePixel: 0,
									ZIndex: 474,
								},
								h("uicorner", {
									CornerRadius: new UDim(0, 12),
								}),
								h("uistroke", {
									ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
									LineJoinMode: Enum.LineJoinMode.Round,
									Color: Palette.white,
									Thickness: 1,
									Transparency: 0.9,
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
									color: canSend ? ACCENT : Palette.panelSoft,
									textColor: canSend ? Palette.ink : Palette.muted,
									size: UDim2.fromOffset(sendW, TapTarget),
									position: footerReveal.map(
										(amount) => new UDim2(1, -sendW, 1, -TapTarget + math.round((1 - amount) * 10)),
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
