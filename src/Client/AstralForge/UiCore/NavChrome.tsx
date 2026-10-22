import { countRedraw, redrawCounterEnabled } from "./devRedrawCounter";
import { sameChromeProps, NAVIGATION_STATE_KEYS } from "./chromeMemo";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import { mergeEvents, useTooltip } from "../Tooltip";
import ReactRoblox from "@rbxts/react-roblox";
import { AppHelpers, MORE_NAV, NAV_GROUPS, PRIMARY_NAV, NavEntry, NavState, navGroupOf } from "../CoreKit/appNav";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../CoreKit/interaction";
import { Layout, Palette, Radius, TapTarget, chromeFor, darken, lighten, moreDockHeight, strokeGradient, surfaceGradient } from "../CoreKit/theme";
import { useFlipperSpring, useViewport } from "../MotionKit/motion";
import { ActiveBoostIcon } from "./TopBarChrome";
import {
	ButtonShimmer,
	CountBadge,
	LooseComponent,
	Text,
	acquireDropdownPortal,
	releaseDropdownPortal,
	resolvePressMotion,
	subscribeInputCancellation,
	useButtonChrome,
} from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

const Icon = (loadKit("ArtKit")("Icon") as { Icon: LooseComponent }).Icon;

interface AudioApi {
	play(cue: string): void;
	captureIntent(): number;
	playIfUnclaimed(marker: number, cue: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;


const SHELL_CHROME = {
	railGutter: 18,
	topbarControl: 48,
	topbarControlGap: 12,
};

const MORE_BTN_W = 172;

type RailEntry = NavEntry & { lockedReason?: unknown; disabledReason?: string };

interface RailButtonProps {
	entry: RailEntry;
	active?: boolean;
	collapsed?: boolean;
	onClick: () => void;
	layoutOrder?: number;
	reducedMotion?: boolean;
	badge?: number;
	rowHeight: number;
	bodySize?: number;
}

function RailButtonImpl(_param: RailButtonProps) {
	const entry = _param.entry;
	const active = _param.active === true;
	const collapsed = _param.collapsed === true;
	const onClick = _param.onClick;
	const layoutOrder = _param.layoutOrder;
	const reducedMotion = _param.reducedMotion === true;
	const badge = _param.badge ?? 0;
	const rowHeight = _param.rowHeight;
	const bodySize = _param.bodySize;
	const viewport = useViewport();
	const touchChrome = viewport.compact || viewport.tight;
	const disabled = entry.disabled === true;
	const [hovered, setHovered] = React.useState(false);
	const [pressed, setPressed] = React.useState(false);
	const hoveredRef = React.useRef(false);
	const emphasis = useFlipperSpring(!disabled && active ? 1 : !disabled && hovered ? 0.4 : 0, reducedMotion, 300, 36);
	const pose = useFlipperSpring(disabled ? 0 : pressed ? -1 : hovered ? 1 : 0, reducedMotion, 1180, 46);
	const iconHover = pose.map((value) => math.clamp(value, 0, 1));
	const press = pose.map((value) => math.clamp(-value, 0, 1));
	const fill = emphasis.map((raw) => (disabled ? Palette.panelRaised : Palette.panel.Lerp(Palette.panelSoft, math.clamp(raw, 0, 1))));
	const fillTransparency = emphasis.map((raw) => {
		const amount = math.clamp(raw, 0, 1);
		return 0.34 - amount * 0.34;
	});
	const strokeTransparency = emphasis.map((raw) => {
		const amount = math.clamp(raw, 0, 1);
		return math.clamp(0.82 - amount * 0.62, 0.18, 0.85);
	});
	const markerSize = emphasis.map((raw) => {
		const amount = math.clamp(raw, 0, 1);
		return new UDim2(0, 3, 1, -18 - math.round((1 - amount) * 16));
	});
	const tileFill = emphasis.map((raw) =>
		disabled ? Palette.panelSoft : Palette.panelRaised.Lerp(darken(entry.accent, 0.52), math.clamp(raw, 0, 1)),
	);
	const ringTransparency = emphasis.map((raw) => math.clamp(1 - math.clamp(raw, 0, 1) * 0.6, 0.4, 1));
	const labelColor = emphasis.map((raw) =>
		disabled ? Palette.muted : Palette.creamSoft.Lerp(Palette.cream, math.clamp(raw, 0, 1)),
	);
	const pressWash = press.map((amount) => (touchChrome ? math.clamp(1 - amount * 0.22, 0.78, 1) : 1));
	const pressMotion = resolvePressMotion("row");
	const rowHover = pressMotion.hover;
	const rowPress = pressMotion.press;
	const rowTilt = pressMotion.tilt;
	const pressScale = pose.map((value) => {
		if (value >= 0) {
			return 1 + math.clamp(value, 0, 1) * rowHover;
		}
		return 1 - math.clamp(-value, 0, 1) * rowPress;
	});
	const tilt = pose.map((value) => math.clamp(value, 0, 1) * rowTilt);
	const iconSize = collapsed ? 34 : 30;
	const iconX = collapsed ? math.floor((Layout.sidebarCollapsedWidth - SHELL_CHROME.railGutter * 2 - 4 - iconSize) / 2) : 12;
	const markHover = () => {
		if (disabled) {
			return;
		}
		if (hoveredRef.current) {
			return;
		}
		hoveredRef.current = true;
		setHovered(true);
		Audio.play(`navHover${entry.id}`);
	};
	const clearHover = () => {
		hoveredRef.current = false;
		setHovered(false);
		setPressed(false);
	};
	React.useEffect(() => {
		return subscribeInputCancellation(() => {
			hoveredRef.current = false;
			setHovered(false);
			setPressed(false);
		});
	}, []);
	// a collapsed rail is icons only: name the page, and say if something is waiting there
	const tip = useTooltip(
		// the page's one-line description moved off the rail row into this tooltip
		collapsed || disabled || entry.eyebrow !== ""
			? {
					title: entry.label,
					body:
						disabled && typeIs(entry.lockedReason, "string")
							? entry.lockedReason
							: entry.eyebrow !== ""
								? entry.eyebrow
								: undefined,
					hint: badge > 0 ? `${badge} waiting` : undefined,
					accent: entry.accent,
				}
			: undefined,
	);
	return h(
		"frame",
		{
			Name: `Nav_${entry.id}`,
			Size: new UDim2(1, 0, 0, rowHeight),
			LayoutOrder: layoutOrder,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: false,
		},
		h(
			"imagebutton",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Active: !disabled,
				Selectable: !disabled,
				Event: mergeEvents(tip, {
					Activated: () => {
						const audioMarker = Audio.captureIntent();
						onClick();
						if (!disabled) {
							Audio.playIfUnclaimed(audioMarker, `navOpen${entry.id}`);
						}
						InteractionFeedback.tap();
					},
					MouseEnter: () => markHover(),
					MouseLeave: () => clearHover(),
					SelectionGained: () => markHover(),
					SelectionLost: () => clearHover(),
					InputBegan: (_b: unknown, input: InputObject) => {
						if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
							setPressed(true);
						}
					},
					InputEnded: () => setPressed(false),
				}),
			},
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					AnchorPoint: new Vector2(0.5, 0.5),
					Position: UDim2.fromScale(0.5, 0.5),
					Rotation: tilt,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				h("uiscale", {
					Scale: pressScale,
				}),
				h(
					"frame",
					{
						Size: new UDim2(1, -4, 1, -2),
						Position: press.map((amount) => new UDim2(0, 2, 0, 1 + math.round(amount * (touchChrome ? 2 : 1)))),
						BackgroundColor3: fill,
						BackgroundTransparency: fillTransparency,
						BorderSizePixel: 0,
						ClipsDescendants: true,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, Radius.lg),
					}),
					h("uigradient", {
						Color: surfaceGradient(Palette.panel, 0.7),
						Rotation: 90,
					}),
					h("uistroke", {
						Color: entry.accent,
						Thickness: 1,
						Transparency: strokeTransparency,
						ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
						LineJoinMode: Enum.LineJoinMode.Round,
					}),
					touchChrome &&
						h(
							"frame",
							{
								Size: UDim2.fromScale(1, 1),
								BackgroundColor3: lighten(entry.accent, 0.35),
								BackgroundTransparency: pressWash,
								BorderSizePixel: 0,
							},
							h("uicorner", {
								CornerRadius: new UDim(0, Radius.lg),
							}),
						),
					h(
						"frame",
						{
							Size: markerSize,
							Position: UDim2.fromScale(0, 0.5),
							AnchorPoint: new Vector2(0, 0.5),
							BackgroundColor3: entry.accent,
							BackgroundTransparency: emphasis.map((amount) => (amount < 0.08 ? 1 : 0.75 - amount * 0.75)),
							BorderSizePixel: 0,
							Visible: emphasis.map((amount) => amount >= 0.08),
						},
						h("uicorner", {
							CornerRadius: new UDim(0, Radius.sm),
						}),
					),
					h(
						"frame",
						{
							Size: UDim2.fromOffset(iconSize, iconSize),
							Position: new UDim2(0, iconX, 0.5, 0),
							AnchorPoint: new Vector2(0, 0.5),
							BackgroundColor3: tileFill,
							BorderSizePixel: 0,
							ClipsDescendants: true,
						},
						h("uicorner", {
							CornerRadius: new UDim(0, Radius.sm),
						}),
						h("uistroke", {
							ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
							LineJoinMode: Enum.LineJoinMode.Round,
							Color: entry.accent,
							Thickness: 1,
							Transparency: ringTransparency,
						}),
						h(Icon, {
							kind: entry.icon,
							color: disabled ? Palette.muted : Palette.creamSoft,
							accent: disabled ? Palette.lineSoft : active ? lighten(entry.accent, 0.42) : Palette.muted,
							size: iconSize,
							spin: !disabled && hovered,
							hoverAmount: iconHover,
							reducedMotion: reducedMotion,
						}),
					),
					!collapsed &&
						h(Text, {
							value: entry.label,
							size: bodySize,
							color: labelColor,
							weight: Enum.FontWeight.SemiBold,
							fit: false,
							position: new UDim2(0, 56, 0.5, -13),
							sizeConstraint: new UDim2(1, -66, 0, 26),
						}),
					badge > 0 &&
						h(CountBadge, {
							count: badge,
							zIndex: 12,
						}),
				),
			),
		),
	);
}

// rail buttons only re-render when what they show changes; onClick is rebuilt every render but
// always calls the same stable setPage, so it is left out of the comparison
function sameRailProps(previous: unknown, nextProps: unknown): boolean {
	const before = previous as Record<string, unknown>;
	const after = nextProps as Record<string, unknown>;
	for (const [key, value] of pairs(before)) {
		if (key !== "onClick" && after[key] !== value) {
			return false;
		}
	}
	for (const [key, value] of pairs(after)) {
		if (key !== "onClick" && before[key] !== value) {
			return false;
		}
	}
	return true;
}

export const RailButton = React.memo(RailButtonImpl, sameRailProps);

interface MoreDockButtonProps {
	entry: RailEntry;
	active?: boolean;
	onClick: () => void;
	reducedMotion?: boolean;
	badge?: number;
	layoutOrder?: number;
	fill?: boolean;
}

function MoreDockButtonImpl(_param: MoreDockButtonProps) {
	const entry = _param.entry;
	const active = _param.active === true;
	const onClick = _param.onClick;
	const reducedMotion = _param.reducedMotion === true;
	const badge = _param.badge ?? 0;
	const layoutOrder = _param.layoutOrder;
	const fill = _param.fill === true;
	const disabled = entry.disabled === true;
	const chrome = useButtonChrome(
		onClick,
		reducedMotion,
		disabled,
		"tabSwitch",
		true,
		false,
		resolvePressMotion(
			fill
				? "row"
				: {
						text: entry.label,
						icon: entry.icon,
						size: UDim2.fromOffset(MORE_BTN_W, TapTarget),
					},
		),
	);
	const selection = useFlipperSpring(active && !disabled ? 1 : 0, reducedMotion, 420, 32);
	const radius = 12;
	const iconSize = fill ? 22 : 28;
	const iconX = fill ? 7 : 9;
	const textX = fill ? 38 : 49;
	const fillColor = chrome.hoverAmount.map((amount) =>
		disabled ? Palette.panelRaised : Palette.panel.Lerp(Palette.panelSoft, math.clamp(amount, 0, 1) * 0.6),
	);
	const cardTransparency = React.joinBindings({
		selection: selection,
		hover: chrome.hoverAmount,
	}).map((values) => {
		const raw = values.selection;
		const hovered = values.hover;
		if (fill) {
			return 0;
		}
		const selected = math.clamp(raw, 0, 1);
		const hoverAmount = math.clamp(hovered, 0, 1);
		return math.clamp(1 - selected * 0.94 - hoverAmount * 0.55, 0.06, 1);
	});
	const activeFillTransparency = selection.map((raw) => 1 - math.clamp(raw, 0, 1) * 0.78);
	const strokeTransparency = React.joinBindings({
		selection: selection,
		hover: chrome.hoverAmount,
	}).map((values) => {
		const raw = values.selection;
		const hovered = values.hover;
		const selected = math.clamp(raw, 0, 1);
		if (fill) {
			return math.clamp(0.72 - math.clamp(hovered, 0, 1) * 0.32 - selected * 0.48, 0.18, 0.76);
		}
		return math.clamp(1 - math.clamp(hovered, 0, 1) * 0.55 - selected * 0.82, 0.18, 1);
	});
	const iconPosition = selection.map((raw) => {
		const selected = math.clamp(raw, 0, 1);
		return fill ? new UDim2(0.5, 0, 0, 3 - math.round(selected * 2)) : new UDim2(0, iconX, 0.5, -math.round(selected));
	});
	const iconFill = selection.map((raw) =>
		disabled ? Palette.panelSoft : Palette.panelRaised.Lerp(darken(entry.accent, 0.64), math.clamp(raw, 0, 1)),
	);
	const iconFillTransparency = React.joinBindings({
		selection: selection,
		hover: chrome.hoverAmount,
	}).map((values) => {
		const raw = values.selection;
		const hovered = values.hover;
		if (disabled) {
			return 0.35;
		}
		if (fill) {
			return 0;
		}
		const selected = math.clamp(raw, 0, 1);
		const hoverAmount = math.clamp(hovered, 0, 1);
		return math.clamp(0.62 - hoverAmount * 0.5 - selected * 0.62, 0, 0.62);
	});
	const labelColor = selection.map((raw) =>
		disabled ? Palette.muted : Palette.creamSoft.Lerp(Palette.cream, math.clamp(raw, 0, 1)),
	);
	const underlineSize = selection.map((raw) => new UDim2(0.46 * math.clamp(raw, 0, 1), 0, 0, 2));
	const underlineTransparency = selection.map((raw) => 1 - math.clamp(raw, 0, 1));
	return h(
		"frame",
		{
			Size: fill ? UDim2.fromScale(1, 1) : UDim2.fromOffset(MORE_BTN_W, TapTarget),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: layoutOrder,
			ClipsDescendants: false,
			ZIndex: 56,
		},
		h(
			"imagebutton",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Active: !disabled,
				Selectable: !disabled,
				ZIndex: 57,
				Event: chrome.events,
			},
			h(
				"frame",
				{
					Size: chrome.surfaceSize,
					Position: chrome.offsetY.map((amount) => new UDim2(0.5, 0, 0.5, math.round(amount))),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: chrome.tilt,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				h("uiscale", {
					Scale: chrome.touchScale,
				}),
				h(
					"frame",
					{
						Size: new UDim2(1, -2, 1, -2),
						Position: UDim2.fromOffset(1, 1),
						BackgroundColor3: fillColor,
						BackgroundTransparency: cardTransparency,
						BorderSizePixel: 0,
						ClipsDescendants: false,
						ZIndex: 57,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, radius),
					}),
					h("uigradient", {
						Color: surfaceGradient(Palette.panel, 0.55),
						Rotation: 90,
					}),
					h("uistroke", {
						Color: entry.accent,
						Thickness: 1,
						Transparency: strokeTransparency,
						ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
						LineJoinMode: Enum.LineJoinMode.Round,
					}),
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundColor3: darken(entry.accent, 0.68),
							BackgroundTransparency: activeFillTransparency,
							BorderSizePixel: 0,
							ZIndex: 57,
						},
						h("uicorner", {
							CornerRadius: new UDim(0, radius),
						}),
					),
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ClipsDescendants: true,
							ZIndex: 58,
						},
						h(ButtonShimmer, {
							hoverAmount: chrome.hoverAmount,
							shimmer: chrome.shimmer,
							live: chrome.shimmerLive,
							zIndex: 58,
							radius: radius,
						}),
					),
					h(
						"frame",
						{
							Size: UDim2.fromOffset(iconSize, iconSize),
							Position: iconPosition,
							AnchorPoint: fill ? new Vector2(0.5, 0) : new Vector2(0, 0.5),
							BackgroundColor3: iconFill,
							BackgroundTransparency: iconFillTransparency,
							BorderSizePixel: 0,
							ClipsDescendants: true,
							ZIndex: 59,
						},
						h("uicorner", {
							CornerRadius: new UDim(0, Radius.sm),
						}),
						h(Icon, {
							kind: entry.icon,
							color: disabled ? Palette.muted : Palette.creamSoft,
							accent: disabled ? Palette.lineSoft : entry.accent,
							size: iconSize,
							spin: !disabled && chrome.hovered,
							hoverAmount: chrome.hoverAmount,
							reducedMotion: reducedMotion,
						}),
					),
					h(Text, {
						value: entry.label,
						size: fill ? 11 : 12,
						color: labelColor,
						weight: Enum.FontWeight.Heavy,
						align: fill ? Enum.TextXAlignment.Center : Enum.TextXAlignment.Left,
						fit: true,
						minSize: fill ? 9 : 10,
						position: fill ? UDim2.fromOffset(2, 26) : UDim2.fromOffset(textX, 12),
						sizeConstraint: fill ? new UDim2(1, -4, 0, 16) : new UDim2(1, -(textX + 6), 0, 22),
						zIndex: 59,
					}),
					h(
						"frame",
						{
							Size: underlineSize,
							Position: new UDim2(0.5, 0, 1, -2),
							AnchorPoint: new Vector2(0.5, 1),
							BackgroundColor3: lighten(entry.accent, 0.48),
							BackgroundTransparency: underlineTransparency,
							BorderSizePixel: 0,
							ZIndex: 60,
						},
						h("uicorner", {
							CornerRadius: new UDim(1, 0),
						}),
					),
				),
			),
		),
		badge > 0 &&
			h(CountBadge, {
				count: badge,
				zIndex: 58,
				compact: true,
			}),
		!fill &&
			h("frame", {
				Size: new UDim2(0, 1, 1, -18),
				Position: new UDim2(1, 0, 0.5, 0),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.lineSoft,
				BackgroundTransparency: 0.78,
				BorderSizePixel: 0,
				ZIndex: 56,
			}),
	);
}

export const MoreDockButton = React.memo(MoreDockButtonImpl, sameRailProps);

interface PopoverAnchor {
	right: number;
	top: number;
}

interface MoreDockPopoverProps {
	entries: NavEntry[];
	page: string;
	setPage: (pageId: string) => void;
	reducedMotion?: boolean;
	state: NavState;
	chatUnread?: number;
	tutorialPage?: string;
	anchor: PopoverAnchor;
	onClose: () => void;
}

export function MoreDockPopover(_param: MoreDockPopoverProps) {
	const entries = _param.entries;
	const page = _param.page;
	const setPage = _param.setPage;
	const reducedMotion = _param.reducedMotion === true;
	const state = _param.state;
	const chatUnread = _param.chatUnread ?? 0;
	const tutorialPage = _param.tutorialPage;
	const anchor = _param.anchor;
	const onClose = _param.onClose;
	const viewport = useViewport();
	const [portalLayer] = React.useState(acquireDropdownPortal);
	React.useEffect(() => {
		return () => releaseDropdownPortal();
	}, []);
	const panelRef = React.useRef<GuiObject>();
	const onCloseRef = React.useRef(onClose);
	onCloseRef.current = onClose;
	useBackLayer(true, () => onCloseRef.current());
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode === Enum.KeyCode.Escape) {
				onCloseRef.current();
				return;
			}
			if (input.UserInputType !== Enum.UserInputType.MouseButton1 && input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			const panel = panelRef.current;
			if (panel === undefined) {
				return;
			}
			const point = new Vector2(input.Position.X, input.Position.Y);
			const origin = panel.AbsolutePosition;
			const extent = panel.AbsoluteSize;
			const inside =
				point.X >= origin.X && point.X <= origin.X + extent.X && point.Y >= origin.Y && point.Y <= origin.Y + extent.Y;
			if (!inside) {
				onCloseRef.current();
			}
		});
		return () => connection.Disconnect();
	}, []);
	const visible = AppHelpers.filterNav(entries, state, tutorialPage);
	const cols = math.min(5, math.max(3, math.ceil(math.sqrt(visible.size()))));
	const cellW = 132;
	const cellH = 68;
	const gap = 8;
	const rows = math.max(1, math.ceil(visible.size() / cols));
	const panelW = cols * cellW + (cols - 1) * gap + 20;
	const panelH = rows * cellH + (rows - 1) * gap + 56;
	const clampedX = math.clamp(anchor.right - panelW, 10, math.max(10, viewport.width - panelW - 10));
	const clampedY = math.min(anchor.top, math.max(10, viewport.height - panelH - 10));
	const reveal = useFlipperSpring(1, reducedMotion, 780, 44);
	const cells = visible.map((entry, index) =>
		h(MoreCell, {
			key: entry.id,
			entry: entry,
			active: page === entry.id,
			onClick: () => {
				setPage(entry.id);
				onClose();
			},
			reducedMotion: reducedMotion,
			badge: AppHelpers.navBadge(entry, state, chatUnread),
			layoutOrder: index,
		}),
	);
	return h(
		React.Fragment,
		undefined,
		ReactRoblox.createPortal(
			h(
				"frame",
				{
					ref: panelRef,
					Size: UDim2.fromOffset(panelW, panelH),
					Position: reveal.map((amount) =>
						UDim2.fromOffset(clampedX, clampedY + math.round((1 - math.clamp(amount, 0, 1)) * 10)),
					),
					BackgroundColor3: Palette.night,
					BackgroundTransparency: reveal.map((amount) => 1 - math.clamp(amount, 0, 1)),
					BorderSizePixel: 0,
					ZIndex: 220,
					ClipsDescendants: true,
					Visible: reveal.map((amount) => amount > 0.01),
				},
				h("uicorner", {
					CornerRadius: new UDim(0, Radius.lg),
				}),
				h("uistroke", {
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
					Color: Palette.lineSoft,
					Thickness: 1,
					Transparency: reveal.map((amount) => math.clamp(1 - amount * 0.18, 0.8, 1)),
				}),
				h(Text, {
					value: "MORE",
					size: 10,
					color: Palette.muted,
					weight: Enum.FontWeight.Heavy,
					position: UDim2.fromOffset(10, 8),
					sizeConstraint: new UDim2(1, -20, 0, 14),
					transparency: reveal.map((amount) => 1 - amount),
				}),
				h(
					"frame",
					{
						Size: new UDim2(1, -20, 1, -34),
						Position: UDim2.fromOffset(10, 30),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 221,
					},
					h("uigridlayout", {
						CellSize: UDim2.fromOffset(cellW, cellH),
						CellPadding: new UDim2(0, gap, 0, gap),
						SortOrder: Enum.SortOrder.LayoutOrder,
						FillDirection: Enum.FillDirection.Horizontal,
						FillDirectionMaxCells: cols,
						HorizontalAlignment: Enum.HorizontalAlignment.Left,
						VerticalAlignment: Enum.VerticalAlignment.Top,
					}),
					cells,
				),
			),
			portalLayer,
		),
	);
}

function MoreCell(_param: {
	entry: RailEntry;
	active?: boolean;
	onClick: () => void;
	reducedMotion?: boolean;
	badge?: number;
	layoutOrder?: number;
}) {
	const entry = _param.entry;
	const active = _param.active === true;
	const onClick = _param.onClick;
	const reducedMotion = _param.reducedMotion === true;
	const badge = _param.badge ?? 0;
	const layoutOrder = _param.layoutOrder;
	const disabled = entry.disabled === true;
	const chrome = useButtonChrome(
		onClick,
		reducedMotion,
		disabled,
		"tabSwitch",
		true,
		false,
		resolvePressMotion({
			text: entry.label,
			icon: entry.icon,
			size: UDim2.fromScale(1, 1),
		}),
	);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: layoutOrder,
			ZIndex: 93,
		},
		h(
			"imagebutton",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Active: !disabled,
				Selectable: !disabled,
				ZIndex: 94,
				Event: chrome.events,
			},
			h(
				"frame",
				{
					Size: chrome.surfaceSize,
					Position: chrome.offsetY.map((amount) => new UDim2(0.5, 0, 0.5, math.round(amount))),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: chrome.tilt,
					BackgroundColor3: active ? darken(entry.accent, 0.7) : Palette.panelRaised,
					BackgroundTransparency: 0.06,
					BorderSizePixel: 0,
					ZIndex: 95,
					ClipsDescendants: true,
				},
				h("uiscale", {
					Scale: chrome.touchScale,
				}),
				h("uicorner", {
					CornerRadius: new UDim(0, Radius.lg),
				}),
				h("uistroke", {
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
					Color: active ? entry.accent : Palette.lineSoft,
					Thickness: 1,
					Transparency: active ? 0.35 : 0.7,
				}),
				h(ButtonShimmer, {
					hoverAmount: chrome.hoverAmount,
					shimmer: chrome.shimmer,
					live: chrome.shimmerLive,
					zIndex: 95,
					radius: 14,
				}),
				h(
					"frame",
					{
						Size: UDim2.fromOffset(22, 22),
						Position: new UDim2(0.5, 0, 0, 8),
						AnchorPoint: new Vector2(0.5, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 96,
					},
					h(Icon, {
						kind: entry.icon,
						color: disabled ? Palette.muted : Palette.creamSoft,
						accent: disabled ? Palette.lineSoft : entry.accent,
						size: 22,
						spin: false,
						reducedMotion: reducedMotion,
					}),
				),
				h(Text, {
					value: entry.label,
					size: 10,
					color: disabled ? Palette.muted : Palette.creamSoft,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Center,
					fit: true,
					minSize: 8,
					position: UDim2.fromOffset(2, 36),
					sizeConstraint: new UDim2(1, -4, 0, 26),
					zIndex: 96,
				}),
				badge > 0 &&
					h(CountBadge, {
						count: badge,
						zIndex: 97,
						compact: true,
					}),
			),
		),
	);
}

interface MoreDockProps {
	page: string;
	setPage: (pageId: string) => void;
	reducedMotion?: boolean;
	state: NavState;
	chatUnread?: number;
	tutorialPage?: string;
	stack?: boolean;
	cols: number;
	cellH: number;
	opacity?: number;
	spacing?: number;
	entries: NavEntry[];
}

export function MoreDock(_param: MoreDockProps) {
	const softMotion = _param.reducedMotion === true;
	const page = _param.page;
	const setPage = _param.setPage;
	const reducedMotion = _param.reducedMotion === true;
	const state = _param.state;
	const chatUnread = _param.chatUnread ?? 0;
	const tutorialPage = _param.tutorialPage;
	const stack = _param.stack === true;
	const cols = _param.cols;
	const cellH = _param.cellH;
	const opacity = _param.opacity ?? 1;
	const spacing = _param.spacing ?? 0.5;
	const entries = _param.entries;
	const viewport = useViewport();
	const more = AppHelpers.filterNav(entries, state, tutorialPage);
	const gridGap = 3 + math.floor(math.clamp(spacing, 0, 1) * 5);
	const height = moreDockHeight(stack, more.size(), cols, cellH, gridGap);
	const [moreMenuOpen, setMoreMenuOpen] = React.useState(false);
	const moreTriggerRef = React.useRef<GuiObject>();
	const [popoverAnchor, setPopoverAnchor] = React.useState<PopoverAnchor>();
	if (stack) {
		const cells = more.map((entry, index) =>
			h(MoreDockButton, {
				key: entry.id,
				entry: entry,
				active: page === entry.id,
				onClick: () => setPage(entry.id),
				reducedMotion: reducedMotion,
				badge: AppHelpers.navBadge(entry, state, chatUnread),
				layoutOrder: index,
				fill: true,
			}),
		);
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, height),
				BackgroundColor3: Palette.night,
				BackgroundTransparency: math.clamp(1 - opacity, 0, 0.48),
				BorderSizePixel: 0,
				ClipsDescendants: false,
				Active: false,
				ZIndex: 55,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.lg),
			}),
			h("uistroke", {
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				LineJoinMode: Enum.LineJoinMode.Round,
				Color: Palette.lineSoft,
				Thickness: 1,
				Transparency: 0.88,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -10, 1, -12),
					Position: UDim2.fromOffset(5, 6),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 56,
				},
				h("uigridlayout", {
					CellSize: new UDim2(1 / cols, -gridGap, 0, cellH),
					CellPadding: new UDim2(0, gridGap, 0, gridGap),
					SortOrder: Enum.SortOrder.LayoutOrder,
					FillDirection: Enum.FillDirection.Horizontal,
					FillDirectionMaxCells: cols,
					HorizontalAlignment: Enum.HorizontalAlignment.Center,
					VerticalAlignment: Enum.VerticalAlignment.Top,
				}),
				cells,
			),
		);
	}
	const visibleCount = math.clamp(math.floor((viewport.width - 32) / (MORE_BTN_W + 4)), 1, 7);
	const needsMore = more.size() > visibleCount;
	const primaryCount = needsMore ? math.max(1, visibleCount - 1) : visibleCount;
	const primary: NavEntry[] = [];
	let overflow: NavEntry[] = [];
	for (const [index, entry] of ipairs(more)) {
		if (index - 1 < primaryCount) {
			primary.push(entry);
		} else {
			overflow.push(entry);
		}
	}
	const activeInOverflow = overflow.find((entry) => entry.id === page);
	if (activeInOverflow !== undefined && primary.size() > 0) {
		const displaced = primary[primary.size() - 1];
		primary[primary.size() - 1] = activeInOverflow;
		overflow = overflow.filter((entry) => entry.id !== activeInOverflow.id);
		if (displaced !== undefined) {
			overflow.unshift(displaced);
		}
	}
	const overflowBadgeTotal = overflow.reduce((sum, entry) => sum + AppHelpers.navBadge(entry, state, chatUnread), 0);
	const moreTriggerActive = moreMenuOpen || activeInOverflow !== undefined;
	const toggleMoreMenu = () => {
		if (!moreMenuOpen) {
			const trigger = moreTriggerRef.current;
			if (trigger !== undefined) {
				const origin = trigger.AbsolutePosition;
				const extent = trigger.AbsoluteSize;
				setPopoverAnchor({
					right: origin.X + extent.X,
					top: origin.Y + extent.Y + 6,
				});
			}
		}
		setMoreMenuOpen((current) => !current);
	};
	const canvasW = math.max(primary.size() * (MORE_BTN_W + 4) - 4, 1);
	const dockW = math.min(viewport.width - 16, primary.size() * (MORE_BTN_W + 4) - 4);
	const primaryCells = primary.map((entry, index) =>
		h(MoreDockButton, {
			key: entry.id,
			entry: entry,
			active: page === entry.id,
			onClick: () => setPage(entry.id),
			reducedMotion: reducedMotion,
			badge: AppHelpers.navBadge(entry, state, chatUnread),
			layoutOrder: index,
		}),
	);
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, height),
			BackgroundColor3: Palette.night,
			BorderSizePixel: 0,
			ClipsDescendants: false,
			Active: false,
			ZIndex: 55,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, Radius.lg),
		}),
		h("uistroke", {
			Color: Palette.lineSoft,
			Thickness: 1,
			Transparency: 0.9,
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			LineJoinMode: Enum.LineJoinMode.Round,
		}),
		h(
			"scrollingframe",
			{
				Size: new UDim2(0, dockW, 1, -8),
				Position: new UDim2(0.5, -math.floor(dockW / 2) - (needsMore ? (MORE_BTN_W + 4) / 2 : 0), 0, 4),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ScrollBarThickness: 0,
				ScrollBarImageColor3: Palette.lineSoft,
				ScrollBarImageTransparency: 0.28,
				ScrollingDirection: Enum.ScrollingDirection.X,
				CanvasSize: new UDim2(0, canvasW, 0, 0),
				AutomaticCanvasSize: Enum.AutomaticSize.None,
				ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
				HorizontalScrollBarInset: Enum.ScrollBarInset.None,
				ScrollingEnabled: true,
				Active: true,
				Selectable: false,
				ClipsDescendants: true,
				ZIndex: 56,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				SortOrder: Enum.SortOrder.LayoutOrder,
				VerticalAlignment: Enum.VerticalAlignment.Center,
				Padding: new UDim(0, 4),
			}),
			primaryCells,
		),
		needsMore &&
			h(
				"frame",
				{
					ref: moreTriggerRef,
					Size: UDim2.fromOffset(MORE_BTN_W, TapTarget),
					Position: new UDim2(1, -(MORE_BTN_W + 6), 0.5, 0),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 57,
				},
				h(MoreDockButton, {
					entry: {
						id: "Overview",
						label: "MORE",
						eyebrow: "",
						icon: "Menu.3",
						accent: Palette.muted,
					},
					active: moreTriggerActive,
					onClick: toggleMoreMenu,
					reducedMotion: reducedMotion,
					badge: overflowBadgeTotal,
					layoutOrder: primary.size(),
				}),
			),
		moreMenuOpen &&
			popoverAnchor !== undefined &&
			h(MoreDockPopover, {
				entries: overflow,
				page: page,
				setPage: (chosen: string) => {
					setPage(chosen);
					setMoreMenuOpen(false);
				},
				reducedMotion: reducedMotion,
				state: state,
				chatUnread: chatUnread,
				tutorialPage: tutorialPage,
				anchor: popoverAnchor,
				onClose: () => setMoreMenuOpen(false),
			}),
	);
}

const railGroupMemory: Record<string, boolean | undefined> = {};
const NAV_BODY_PAD = 3;

function NavChevron(_param: { openAmount: React.Binding<number>; color: Color3; position?: UDim2 }) {
	const openAmount = _param.openAmount;
	const color = _param.color;
	const bar = (offset: number, rotation: number) =>
		h(
			"frame",
			{
				Size: UDim2.fromOffset(7, 2),
				Position: new UDim2(0.5, offset, 0.5, 0),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: rotation,
				BackgroundColor3: color,
				BorderSizePixel: 0,
			},
			h("uicorner", {
				CornerRadius: new UDim(1, 0),
			}),
		);
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(12, 12),
			Position: _param.position,
			AnchorPoint: new Vector2(0.5, 0.5),
			Rotation: openAmount.map((amount) => -90 + math.clamp(amount, 0, 1) * 90),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
		},
		bar(-2, 45),
		bar(2, -45),
	);
}

interface NavGroupProps {
	label: string;
	entries: NavEntry[];
	headerless?: boolean;
	open?: boolean;
	onToggle: () => void;
	page: string;
	setPage: (pageId: string) => void;
	collapsed?: boolean;
	rowHeight: number;
	gap: number;
	headerHeight?: number;
	bodySize?: number;
	state: NavState;
	chatUnread?: number;
	reducedMotion?: boolean;
	layoutOrder?: number;
}

function NavGroup(_param: NavGroupProps) {
	const entries = _param.entries;
	const headerless = _param.headerless === true;
	const open = headerless || _param.open === true;
	const collapsed = _param.collapsed === true;
	const rowHeight = _param.rowHeight;
	const gap = _param.gap;
	const headerHeight = headerless ? 0 : (_param.headerHeight ?? 0);
	const page = _param.page;
	const setPage = _param.setPage;
	const state = _param.state;
	const chatUnread = _param.chatUnread ?? 0;
	const reducedMotion = _param.reducedMotion === true;
	const stride = rowHeight + gap;
	const bodyH = math.max(0, entries.size() * stride - gap) + NAV_BODY_PAD * 2;
	const openAmount = useFlipperSpring(open ? 1 : 0, reducedMotion, 560, 46);
	const [hovered, setHovered] = React.useState(false);
	const hover = useFlipperSpring(hovered ? 1 : 0, reducedMotion, 900, 44);
	let activeIndex: number | undefined;
	let badgeTotal = 0;
	for (const [index, entry] of ipairs(entries)) {
		if (entry.id === page) {
			activeIndex = index;
		}
		badgeTotal += AppHelpers.navBadge(entry, state, chatUnread);
	}
	const heldSelection = React.useRef(0);
	if (activeIndex !== undefined) {
		heldSelection.current = (activeIndex - 1) * stride;
	}
	const selectionLead = useFlipperSpring(heldSelection.current, reducedMotion, 720, 48);
	const selectionTrail = useFlipperSpring(heldSelection.current, reducedMotion, 300, 46);
	const selectionSpan = React.joinBindings([selectionLead, selectionTrail]);
	const hasActive = activeIndex !== undefined;
	const selectionAccent = hasActive ? AppHelpers.pageAccent(page) : Palette.muted;
	const labelColor = hover.map((amount) => {
		const base = hasActive ? lighten(selectionAccent, 0.2) : Palette.muted;
		return base.Lerp(Palette.cream, math.clamp(amount, 0, 1) * 0.7);
	});
	const rows: Record<string, unknown> = {};
	rows.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Vertical,
		Padding: new UDim(0, gap),
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	rows.pad = h("uipadding", {
		PaddingTop: new UDim(0, NAV_BODY_PAD),
		PaddingBottom: new UDim(0, NAV_BODY_PAD),
	});
	for (const [index, entry] of ipairs(entries)) {
		rows[entry.id] = h(RailButton, {
			entry: entry,
			active: page === entry.id,
			collapsed: collapsed,
			onClick: () => setPage(entry.id),
			layoutOrder: index,
			reducedMotion: reducedMotion,
			rowHeight: rowHeight,
			bodySize: _param.bodySize,
			badge: AppHelpers.navBadge(entry, state, chatUnread),
		});
	}
	let header: unknown = undefined;
	if (!headerless) {
		const toggle = () => {
			_param.onToggle();
			Audio.play(open ? "close" : "open");
			InteractionFeedback.tap();
		};
		const headerChildren: Record<string, unknown> = {};
		const showBadge = !open && badgeTotal > 0;
		const badgeW = badgeTotal > 99 ? 20 : badgeTotal >= 10 ? 16 : 14;
		const countShift = showBadge && !collapsed ? badgeW + 6 : 0;
		if (collapsed) {
			// the collapsed header is ~38px wide: a short name, with the waiting count folded into it
			// (a separate badge would leave the name no room)
			const SHORT: Record<string, string | undefined> = {
				Home: "HOME",
				Daily: "DAILY",
				Progress: "PROG",
				Social: "SOCIAL",
				System: "SYS",
				More: "MORE",
			};
			const short = SHORT[_param.label] ?? string.upper(string.sub(_param.label, 1, 5));
			const reserve = 0;
			headerChildren.label = h(Text, {
				value: showBadge ? `${short} ${badgeTotal > 99 ? "99+" : tostring(badgeTotal)}` : short,
				size: 9,
				color: showBadge ? Palette.mango : labelColor,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				fit: true,
				minSize: 6,
				position: UDim2.fromOffset(2, 0),
				sizeConstraint: new UDim2(1, -(4 + reserve), 1, -2),
			});
			headerChildren.rule = h("frame", {
				Size: new UDim2(1, -12, 0, 1),
				Position: new UDim2(0, 6, 1, -1),
				BackgroundColor3: hasActive ? selectionAccent : Palette.lineSoft,
				BackgroundTransparency: hasActive ? 0.35 : 0.7,
				BorderSizePixel: 0,
			});
		} else {
			headerChildren.label = h(Text, {
				value: string.upper(_param.label),
				size: 11,
				color: labelColor,
				weight: Enum.FontWeight.Heavy,
				fit: false,
				position: UDim2.fromOffset(26, 0),
				sizeConstraint: new UDim2(1, -70, 1, 0),
			});
			headerChildren.chevron = h(NavChevron, {
				openAmount: openAmount,
				color: hasActive ? selectionAccent : Palette.muted,
				position: new UDim2(0, 12, 0.5, 0),
			});
			headerChildren.count = h(Text, {
				value: tostring(entries.size()),
				size: 10,
				color: Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Right,
				fit: false,
				position: new UDim2(1, -40 - countShift, 0, 0),
				sizeConstraint: new UDim2(0, 32, 1, 0),
			});
			headerChildren.rule = h("frame", {
				Size: new UDim2(1, -16, 0, 1),
				Position: new UDim2(0, 8, 1, -1),
				BackgroundColor3: Palette.lineSoft,
				BackgroundTransparency: hover.map((amount) => 0.72 - math.clamp(amount, 0, 1) * 0.3),
				BorderSizePixel: 0,
			});
		}
		if (showBadge && !collapsed) {
			headerChildren.badge = h(CountBadge, {
				count: badgeTotal,
				zIndex: 12,
				compact: true,
				position: collapsed ? new UDim2(1, -1, 0, 1) : new UDim2(1, -8, 0.5, 0),
				anchorPoint: collapsed ? new Vector2(1, 0) : new Vector2(1, 0.5),
			});
		}
		header = h(
			"textbutton",
			{
				Size: new UDim2(1, 0, 0, headerHeight),
				BackgroundColor3: Palette.panelSoft,
				BackgroundTransparency: hover.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.55),
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Text: "",
				Selectable: true,
				ZIndex: 3,
				Event: {
					Activated: toggle,
					MouseEnter: () => setHovered(true),
					MouseLeave: () => setHovered(false),
					SelectionGained: () => setHovered(true),
					SelectionLost: () => setHovered(false),
				},
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.md),
			}),
			headerChildren,
		);
	}
	const pill =
		hasActive &&
		h(
			"frame",
			{
				Size: selectionSpan.map((values) => {
					const stretch = math.abs(values[0] - values[1]);
					return new UDim2(1, -4, 0, math.max(8, rowHeight - 4) + math.round(stretch));
				}),
				Position: selectionSpan.map((values) =>
					UDim2.fromOffset(2, NAV_BODY_PAD + math.round(math.min(values[0], values[1])) + 2),
				),
				BackgroundColor3: Palette.panelSoft,
				BackgroundTransparency: 0.2,
				BorderSizePixel: 0,
				ZIndex: 1,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.md),
			}),
			h("uigradient", {
				Color: surfaceGradient(Palette.panelSoft, 0.9),
				Rotation: 90,
			}),
			h(
				"uistroke",
				{
					Color: selectionAccent,
					Thickness: 1,
					Transparency: 0.38,
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
				},
				h("uigradient", {
					Rotation: 90,
					Color: strokeGradient(selectionAccent),
				}),
			),
			h(
				"frame",
				{
					Size: new UDim2(0, 3, 1, -14),
					Position: new UDim2(0, 0, 0.5, 0),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundColor3: selectionAccent,
					BorderSizePixel: 0,
				},
				h("uicorner", {
					CornerRadius: new UDim(0, Radius.sm),
				}),
			),
		);
	return h(
		"frame",
		{
			Size: openAmount.map((amount) => new UDim2(1, 0, 0, headerHeight + math.round(bodyH * math.clamp(amount, 0, 1)))),
			LayoutOrder: _param.layoutOrder,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: true,
		},
		header as React.Element,
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, bodyH),
				Position: openAmount.map((amount) =>
					UDim2.fromOffset(0, headerHeight - math.round((1 - math.clamp(amount, 0, 1)) * 8)),
				),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Visible: openAmount.map((amount) => amount > 0.01),
			},
			pill,
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 2,
				},
				rows,
			),
		),
	);
}

interface NavigationProps {
	page: string;
	setPage: (pageId: string) => void;
	collapsed?: boolean;
	width?: React.Binding<number>;
	fixedWidth?: number;
	reducedMotion?: boolean;
	state: NavState;
	chatUnread?: number;
	tutorialPage?: string;
	includeSecondary?: boolean;
	fromMore?: boolean;
	activeBoost?: unknown;
	activeBoostEndsAt?: number;
	wallClock?: React.Binding<number>;
	openBoosts?: () => void;
}

function NavigationImpl(_param: NavigationProps) {
	countRedraw("Navigation", redrawCounterEnabled(_param.state as { Admin?: { Access?: boolean } }));
	const page = _param.page;
	const setPage = _param.setPage;
	const collapsed = _param.collapsed === true;
	const width = _param.width;
	const fixedWidth = _param.fixedWidth;
	const reducedMotion = _param.reducedMotion === true;
	const state = _param.state;
	const chatUnread = _param.chatUnread ?? 0;
	const tutorialPage = _param.tutorialPage;
	const includeSecondary = _param.includeSecondary ?? false;
	const fromMore = _param.fromMore ?? false;
	const activeBoost = _param.activeBoost;
	const activeBoostEndsAt = _param.activeBoostEndsAt ?? 0;
	const wallClock = _param.wallClock;
	const openBoosts = _param.openBoosts;
	const viewport = useViewport();
	const railNavHostRef = React.useRef<GuiObject>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = railNavHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		let alive = true;
		const selectJob = task.defer(() => {
			if (!alive || host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(selectJob));
		};
	}, [page, collapsed]);
	const chrome = chromeFor(viewport);
	const rowHeight = collapsed ? chrome.railCollapsedRow : chrome.railRow;
	const primaryEntries = fromMore ? [] : AppHelpers.filterNav(PRIMARY_NAV, state, tutorialPage);
	const secondaryEntries = fromMore
		? AppHelpers.filterNav(MORE_NAV, state, tutorialPage)
		: includeSecondary
			? AppHelpers.filterNav(MORE_NAV, state, tutorialPage)
			: [];
	const headerHeight = 12;
	const showBoost =
		activeBoost !== undefined && !chrome.mobile && page !== "Rewards" && wallClock !== undefined && openBoosts !== undefined;
	const boostHeight = showBoost ? (collapsed ? 62 : 64) : 0;
	const boostReserve = showBoost ? boostHeight + SHELL_CHROME.railGutter * 2 : 0;
	const railScrollRef = React.useRef<GuiObject>();
	const grouped = includeSecondary && !fromMore;
	const groupHeaderH = collapsed ? 22 : 30;
	const activeGroup = navGroupOf(page);
	const [groupOpen, setGroupOpen] = React.useState<Record<string, boolean | undefined>>(() => ({
		...railGroupMemory,
	}));
	function isGroupOpen(id: string): boolean {
		const remembered = groupOpen[id];
		if (remembered !== undefined) {
			return remembered;
		}
		return id === "Home" || id === activeGroup;
	}
	React.useEffect(() => {
		if (activeGroup === undefined || groupOpen[activeGroup] === true) {
			return undefined;
		}
		railGroupMemory[activeGroup] = true;
		setGroupOpen({ ...railGroupMemory });
		return undefined;
	}, [activeGroup]);
	const toggleGroup = (id: string) => {
		railGroupMemory[id] = !isGroupOpen(id);
		setGroupOpen({ ...railGroupMemory });
	};
	const railChildren: Record<string, unknown> = {};
	let groupOrder = 0;
	function addGroup(id: string, label: string, groupEntries: NavEntry[], headerless: boolean) {
		if (groupEntries.size() === 0) {
			return;
		}
		groupOrder += 1;
		railChildren[id] = h(NavGroup, {
			label: label,
			entries: groupEntries,
			headerless: headerless,
			open: isGroupOpen(id),
			onToggle: () => {
				toggleGroup(id);
			},
			page: page,
			setPage: setPage,
			collapsed: collapsed,
			rowHeight: rowHeight,
			gap: chrome.railGap,
			headerHeight: groupHeaderH,
			bodySize: chrome.bodyText,
			state: state,
			chatUnread: chatUnread,
			reducedMotion: reducedMotion,
			layoutOrder: groupOrder,
		});
	}
	if (grouped) {
		const byId: Record<string, NavEntry | undefined> = {};
		for (const list of [primaryEntries, secondaryEntries]) {
			for (const entry of list) {
				byId[entry.id] = entry;
			}
		}
		const placed: Record<string, boolean | undefined> = {};
		for (const group of NAV_GROUPS) {
			const groupEntries: NavEntry[] = [];
			for (const id of group.routes) {
				const entry = byId[id];
				if (entry !== undefined && placed[id] !== true) {
					placed[id] = true;
					groupEntries.push(entry);
				}
			}
			addGroup(group.key, group.label, groupEntries, false);
		}
		const loose: NavEntry[] = [];
		for (const list of [primaryEntries, secondaryEntries]) {
			for (const entry of list) {
				if (placed[entry.id] !== true) {
					placed[entry.id] = true;
					loose.push(entry);
				}
			}
		}
		addGroup("More", "More", loose, false);
	} else {
		const flat = [...primaryEntries];
		for (const entry of secondaryEntries) {
			flat.push(entry);
		}
		addGroup("All", "", flat, true);
	}
	return h(
		"frame",
		{
			Name: "RailNavClaim",
			ref: railNavHostRef,
			Size:
				fixedWidth !== undefined
					? UDim2.fromScale(1, 1)
					: width !== undefined
						? width.map((value) => new UDim2(0, math.max(0, value), 1, 0))
						: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.night,
			BorderSizePixel: 0,
			ZIndex: 10,
			ClipsDescendants: false,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, Radius.md),
		}),
		h("uigradient", {
			Color: surfaceGradient(Palette.night, 0.5),
			Rotation: 90,
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, -2, 1, -2),
				Position: UDim2.fromOffset(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.md),
			}),
			h(
				"uistroke",
				{
					Color: Palette.lineSoft,
					Thickness: 1,
					Transparency: 0.55,
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
				},
				h("uigradient", {
					Rotation: 90,
					Color: strokeGradient(Palette.lineSoft),
				}),
			),
		),
		h(
			"scrollingframe",
			{
				ref: railScrollRef,
				Size: new UDim2(1, -(SHELL_CHROME.railGutter * 2 + 4), 1, -(headerHeight + SHELL_CHROME.railGutter + boostReserve)),
				Position: UDim2.fromOffset(SHELL_CHROME.railGutter, headerHeight),
				CanvasSize: new UDim2(),
				AutomaticCanvasSize: Enum.AutomaticSize.Y,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ScrollBarThickness: collapsed ? 0 : 3,
				ScrollBarImageColor3: Palette.lineSoft,
				ScrollBarImageTransparency: 0.28,
				ScrollingDirection: Enum.ScrollingDirection.Y,
				ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
				VerticalScrollBarInset: collapsed ? Enum.ScrollBarInset.None : Enum.ScrollBarInset.ScrollBar,
				ClipsDescendants: true,
				Active: true,
				Selectable: false,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, collapsed ? 4 : 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h("uipadding", {
				PaddingBottom: new UDim(0, Layout.stackGap),
			}),
			railChildren,
		),
		showBoost &&
			h(
				"frame",
				{
					Size: new UDim2(1, -(SHELL_CHROME.railGutter * 2), 0, boostHeight),
					Position: new UDim2(0, SHELL_CHROME.railGutter, 1, -(boostHeight + SHELL_CHROME.railGutter)),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 12,
				},
				h(ActiveBoostIcon, {
					boost: activeBoost,
					endsAt: activeBoostEndsAt,
					now: wallClock,
					open: openBoosts,
					reducedMotion: reducedMotion,
					compact: collapsed,
				}),
			),
	);
}

export const Navigation = React.memo(NavigationImpl, sameChromeProps(NAVIGATION_STATE_KEYS));
