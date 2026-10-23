import { useFocusOrder } from "../CoreKit/focusOrder";
import { ModalSelectionScope } from "./overlayCore";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import { InteractionFeedback } from "../CoreKit/interaction";
import { useClientSelector } from "../CoreKit/clientStore";
import * as ProfileStyle from "../../../Shared/AstralForge/Shared/ProfileStyle";
import { compactNumber } from "../CoreKit/format";
import { getPlayPolicy } from "../CoreKit/playPolicy";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { composePresence, useEntrance, useExitTransition, useFlipperSpring, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, pixelPosition, Text, useGamepadAutofocus, useGuiSize, useTouchTargets } from "./ui";
import { SearchField } from "./surface";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const SocialService = game.GetService("SocialService");
const StarterGui = game.GetService("StarterGui");
const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const Icon = (loadKit("ArtKit")("Icon") as { Icon: unknown }).Icon;

interface Row {
	UserId: number;
	Name?: string;
	DisplayName: string;
	CurrentZone?: unknown;
	Zone?: unknown;
	Rebirths?: unknown;
	Production?: unknown;
	LifetimeCash?: unknown;
	DomainRank?: unknown;
	PlayTime?: unknown;
	AccountAge?: unknown;
	Premium?: boolean;
	IsLocal?: boolean;
	Artifact?: unknown;
}

interface Artifact {
	Name: string;
	Level: unknown;
	Color?: Color3;
	Element?: unknown;
	Rarity?: unknown;
	Effect?: string;
}

interface Option {
	id: string;
	label: string;
	detail?: string;
}

interface PlayerlistModel {
	clean(this: void, rows: unknown, botId?: number): Row[];
	playTime(this: void, seconds: unknown): string;
	accountAge(this: void, days: unknown): string;
	details(this: void, text: string): string;
	view(this: void, rows: Row[], sortId: string, query: string, friendsOnly: boolean, friends: Record<number, boolean>): Row[];
	ranks(this: void, rows: Row[], sortId: string): Record<number, number>;
	artifactOf(this: void, player: Player | undefined, raw: unknown): Artifact | undefined;
	REASONS: Option[];
	SEVERITIES: Option[];
	WHENS: Option[];
	WHERES: Option[];
	SORTS: Option[];
	DETAILS_MAX: number;
	SEARCH_MIN_ROWS: number;
}

const SharedData = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;
const Model = SharedData("PlayerlistModel") as PlayerlistModel;
require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("Protocol") as ModuleScript);
const elementFxModule = require(AstralForge.WaitForChild("ElementFx") as ModuleScript) as {
	ElementFx: unknown;
	sheet: (this: void, element: unknown) => { Color: Color3 } | undefined;
};
const ElementFx = elementFxModule.ElementFx;
const elementSheet = elementFxModule.sheet;

interface CrewStoreModule {
	useCrew(this: void): { crew?: { Members: Array<{ UserId: number }> } };
}

type Dispatch = (action: string, payload: object, callback?: (response: Response) => void) => void;
// header GO HOME shortcut width (shown only while visiting)
const HOME_W = 88;

interface Response {
	ok?: boolean;
	error?: string;
	message?: string;
	Players?: unknown;
}

const TEST_BOT_USER_ID = 771133001;
const ROW_H = 60;
// phones (card narrower than this): one-line rows, so about a third more players fit on screen
const COMPACT_W = 340;
const COMPACT_ROW_H = 44;
const SWIPE_W = 190;
const ROW_GAP = 6;
const FRIEND_TTL = 120;
const REPORT_COOLDOWN = 600;

const friendCache: Record<number, { at: number; value: boolean } | undefined> = {};
const reportedAt: Record<number, number | undefined> = {};

function StatCell(param: { order: number; label: string; value: string; color?: Color3 }) {
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			LayoutOrder: param.order,
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			ZIndex: 625,
		},
		h("uicorner", { CornerRadius: new UDim(0, 10) }),
		h(Text, {
			value: param.label,
			size: 9,
			color: Palette.muted,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 8,
			position: UDim2.fromOffset(8, 4),
			sizeConstraint: new UDim2(1, -12, 0, 13),
			zIndex: 626,
		}),
		h(Text, {
			value: param.value,
			size: 13,
			color: param.color ?? Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(8, 17),
			sizeConstraint: new UDim2(1, -12, 0, 18),
			zIndex: 626,
		}),
	);
}

function Avatar(param: { size: number; accent: Color3; position: UDim2; userId: number; away?: boolean }) {
	const size = param.size;
	const accent = param.accent;
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(size, size),
			Position: param.position,
			AnchorPoint: new Vector2(0, 0.5),
			BackgroundColor3: darken(accent, 0.64),
			BorderSizePixel: 0,
			ZIndex: 624,
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h("uistroke", { Color: accent, Thickness: 1.5, Transparency: 0.25 }),
		h(
			"imagelabel",
			{
				Size: new UDim2(1, -4, 1, -4),
				Position: UDim2.fromOffset(2, 2),
				BackgroundColor3: Palette.panel,
				BorderSizePixel: 0,
				Image: `rbxthumb://type=AvatarHeadShot&id=${param.userId}&w=150&h=150`,
				ScaleType: Enum.ScaleType.Crop,
				ZIndex: 625,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(11, 11),
				Position: new UDim2(1, -1, 1, -1),
				AnchorPoint: new Vector2(1, 1),
				BackgroundColor3: param.away ? Palette.mango : Palette.mint,
				BorderSizePixel: 0,
				ZIndex: 627,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: Palette.ink, Thickness: 2 }),
		),
	);
}

interface ActionButtonProps {
	order: number;
	text: string;
	icon: string;
	onClick?: () => void;
	color: Color3;
	textColor?: Color3;
	outline?: boolean;
	reducedMotion?: boolean;
	disabled?: boolean;
}

function ActionButton(param: ActionButtonProps) {
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			LayoutOrder: param.order,
			BackgroundTransparency: 1,
			ZIndex: 626,
		},
		h(Button, {
			text: param.text,
			icon: param.icon,
			onClick: param.onClick,
			color: param.color,
			textColor: param.textColor ?? Palette.ink,
			outline: param.outline,
			size: UDim2.fromScale(1, 1),
			reducedMotion: param.reducedMotion,
			disabled: param.disabled,
			zIndex: 626,
		}),
	);
}

// Two groups of four: the things people do with each other (message, trade, visit, crew) as full
// buttons, then quieter, shorter buttons for wave, friend, block and report, with room between.
function playerActionLayout(width: number) {
	const [PLAYER_ACTION_GAP, PLAYER_GROUP_GAP, PLAYER_SECONDARY_H] = [10, 14, 40];
	const columns = width < 440 ? 2 : 4;
	const groupRows = math.ceil(4 / columns);
	const primaryHeight = groupRows * TapTarget + (groupRows - 1) * PLAYER_ACTION_GAP;
	const secondaryHeight = groupRows * PLAYER_SECONDARY_H + (groupRows - 1) * PLAYER_ACTION_GAP;
	return {
		columns: columns,
		rows: groupRows * 2,
		gap: PLAYER_ACTION_GAP,
		cellWidth: math.floor((math.max(0, width - 16) - (columns - 1) * PLAYER_ACTION_GAP) / columns),
		primaryHeight: primaryHeight,
		secondaryHeight: secondaryHeight,
		secondaryCellHeight: PLAYER_SECONDARY_H,
		groupGap: PLAYER_GROUP_GAP,
		height: primaryHeight + PLAYER_GROUP_GAP + secondaryHeight,
	};
}

function detailsHeight(row: Row, width: number) {
	if (row.IsLocal) {
		return 8 + 2 * 40 + 6 + 22 + 8;
	}
	return 8 + 2 * 40 + 6 + 22 + playerActionLayout(width).height + 10;
}

interface PlayerRowProps {
	row: Row;
	artifact?: Artifact;
	order: number;
	width: number;
	expanded: boolean;
	friend: boolean;
	blocked: boolean;
	away: boolean;
	reported: boolean;
	reducedMotion?: boolean;
	crewmate: boolean;
	/** place on the server for the selected stat (1 is the top) */
	rank: number;
	sortId: string;
	/** you're on this player's forge right now (button flips to GO HOME and sends LeavePlot) */
	visiting: boolean;
	onToggle: () => void;
	onFriend: () => void;
	onBlock: () => void;
	onMessage: () => void;
	onVisit: () => void;
	onCrew: () => void;
	onWave: () => void;
	onTrade: () => void;
	onReport: () => void;
}

function PlayerRow(param: PlayerRowProps) {
	const row = param.row;
	const expanded = param.expanded;
	const rowRef = React.useRef<Frame>();
	const [width, setWidth] = React.useState(param.width);
	React.useEffect(() => {
		const host = rowRef.current;
		if (host === undefined) {
			return;
		}
		const resize = () => {
			if (host.AbsoluteSize.X > 0) {
				setWidth(math.floor(host.AbsoluteSize.X));
			}
		};
		resize();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(resize);
		return () => connection.Disconnect();
	}, []);
	const reducedMotion = param.reducedMotion;
	const friend = param.friend;
	const blocked = param.blocked;
	const away = param.away;
	const reported = param.reported;
	const accent = row.IsLocal ? Palette.mint : friend ? Palette.mango : Palette.cyan;
	// a player's chosen profile accent/frame (defaults leave the card unchanged)
	const style = ProfileStyle.fromPlayer(Players.GetPlayerByUserId(row.UserId));
	const strokeColor = style.accent ?? accent;
	const openAmount = useFlipperSpring(expanded ? 1 : 0, reducedMotion, 560, 44);
	const [hovered, setHovered] = React.useState(false);
	const hover = useFlipperSpring(hovered || expanded ? 1 : 0, reducedMotion, 900, 44);
	const detailsH = detailsHeight(row, width);
	const compact = width < COMPACT_W;
	const rowH = compact ? COMPACT_ROW_H : ROW_H;
	const avatarSize = compact ? 28 : 40;
	// rank column ahead of the avatar; everything after it shifts right by this much
	const rankW = compact ? 22 : 28;
	const topRank = param.rank === 1;
	let statValue = `${compactNumber(row.Production)}/s`;
	if (param.sortId === "Lifetime") {
		statValue = compactNumber(row.LifetimeCash);
	} else if (param.sortId === "Rebirths") {
		statValue = `${compactNumber(row.Rebirths)} RB`;
	} else if (param.sortId === "Played") {
		statValue = Model.playTime(row.PlayTime);
	}
	// phones: swipe a closed row left to show Message and Visit without opening the details
	const canSwipe = compact && !row.IsLocal && !expanded;
	const [swiped, setSwiped] = React.useState(false);
	const swipeAmount = useFlipperSpring(swiped && canSwipe ? 1 : 0, reducedMotion, 700, 40);
	const touchStart = React.useRef<Vector3>();
	// the finger lifting at the end of a swipe also fires Activated; that release is not a tap
	const swipeAt = React.useRef(-math.huge);
	React.useEffect(() => {
		if (!canSwipe && swiped) {
			setSwiped(false);
		}
	}, [canSwipe]);
	// an open swipe closes when you tap anywhere outside this row, with the same tick it opened with
	const rowHitRef = React.useRef<TextButton>();
	React.useEffect(() => {
		if (!swiped) {
			return undefined;
		}
		const connection = game.GetService("UserInputService").InputBegan.Connect((input) => {
			const kind = input.UserInputType;
			if (kind !== Enum.UserInputType.Touch && kind !== Enum.UserInputType.MouseButton1) {
				return;
			}
			const hit = rowHitRef.current;
			if (hit === undefined) {
				return;
			}
			const inset = game.GetService("GuiService").GetGuiInset()[0];
			const at = hit.AbsolutePosition;
			const size = hit.AbsoluteSize;
			const inside = (x: number, y: number) => x >= at.X && x <= at.X + size.X && y >= at.Y && y <= at.Y + size.Y;
			const px = input.Position.X;
			const py = input.Position.Y;
			if (!inside(px, py) && !inside(px - inset.X, py - inset.Y)) {
				InteractionFeedback.tick();
				setSwiped(false);
			}
		});
		return () => connection.Disconnect();
	}, [swiped]);
	const tags: string[] = [];
	if (row.IsLocal) {
		tags.push("YOU");
	}
	if (param.crewmate) {
		tags.push("CREW");
	}
	if (friend) {
		tags.push("FRIEND");
	}
	if (away) {
		tags.push("AFK");
	}
	if (blocked) {
		tags.push("BLOCKED");
	}
	let subtitle = `WORLD ${compactNumber(row.CurrentZone)}  ·  ${compactNumber(row.Rebirths)} REBIRTHS`;
	const artifact = param.artifact;
	const artifactColor =
		artifact !== undefined ? artifact.Color ?? (elementSheet(artifact.Element) ?? { Color: Palette.violet }).Color : undefined;
	if (artifact !== undefined) {
		subtitle = `${string.upper(artifact.Name)} LV${artifact.Level}  ·  ${subtitle}`;
	}
	let actions: React.Element | undefined = undefined;
	if (!row.IsLocal) {
		const actionLayout = playerActionLayout(width);
		const actionGroup = (name: string, top: number, height: number, cellHeight: number, children: object) =>
			h(
				"frame",
				{
					Name: name,
					Size: new UDim2(1, 0, 0, height),
					Position: UDim2.fromOffset(0, top),
					BackgroundTransparency: 1,
					ZIndex: 625,
				},
				h("uigridlayout", {
					CellSize: UDim2.fromOffset(actionLayout.cellWidth, cellHeight),
					FillDirectionMaxCells: actionLayout.columns,
					CellPadding: UDim2.fromOffset(actionLayout.gap, actionLayout.gap),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				children,
			);
		actions = h(
			"frame",
			{
				Name: "PlayerActions",
				Size: new UDim2(1, -16, 0, actionLayout.height),
				Position: UDim2.fromOffset(8, 8 + 2 * 40 + 6 + 22),
				BackgroundTransparency: 1,
				ZIndex: 625,
			},
			actionGroup("Primary", 0, actionLayout.primaryHeight, TapTarget, {
				Message: h(ActionButton, {
					order: 1,
					text: "MESSAGE",
					icon: "Chat.7",
					color: Palette.cyan,
					disabled: blocked,
					onClick: param.onMessage,
					reducedMotion: reducedMotion,
				}),
				Trade: h(ActionButton, {
					order: 2,
					text: "TRADE",
					icon: "Send.6",
					color: Palette.mint,
					// trading is off where PolicyService doesn't allow paid item trading
					disabled: !getPlayPolicy().PaidItemTradingAllowed,
					onClick: param.onTrade,
					reducedMotion: reducedMotion,
				}),
				Visit: h(ActionButton, {
					order: 3,
					text: param.visiting ? "GO HOME" : "VISIT",
					icon: "Visit.6",
					color: param.visiting ? Palette.green : Palette.violet,
					onClick: param.onVisit,
					reducedMotion: reducedMotion,
				}),
				Crew: h(ActionButton, {
					order: 4,
					text: param.crewmate ? "IN CREW" : "CREW",
					icon: "Crew.16",
					color: Palette.green,
					disabled: param.crewmate || blocked,
					onClick: param.onCrew,
					reducedMotion: reducedMotion,
				}),
			}),
			actionGroup(
				"Secondary",
				actionLayout.primaryHeight + actionLayout.groupGap,
				actionLayout.secondaryHeight,
				actionLayout.secondaryCellHeight,
				{
					Wave: h(ActionButton, {
						order: 1,
						text: "WAVE",
						icon: "Wave.16",
						color: Palette.panelSoft,
						textColor: Palette.cream,
						outline: true,
						onClick: param.onWave,
						reducedMotion: reducedMotion,
					}),
					Friend: h(ActionButton, {
						order: 2,
						text: friend ? "UNFRIEND" : "ADD FRIEND",
						icon: "Crew.17",
						color: Palette.panelSoft,
						textColor: Palette.cream,
						outline: true,
						onClick: param.onFriend,
						reducedMotion: reducedMotion,
					}),
					Block: h(ActionButton, {
						order: 3,
						text: blocked ? "UNBLOCK" : "BLOCK",
						icon: "Close.17",
						color: Palette.panelSoft,
						textColor: Palette.creamSoft,
						outline: true,
						onClick: param.onBlock,
						reducedMotion: reducedMotion,
					}),
					Report: h(ActionButton, {
						order: 4,
						text: reported ? "REPORTED" : "REPORT",
						icon: "Admin.2",
						color: Palette.panelSoft,
						textColor: Palette.coral,
						outline: true,
						disabled: reported,
						onClick: param.onReport,
						reducedMotion: reducedMotion,
					}),
				},
			),
		);
	}
	const relics = "NO EQUIPPED ARTIFACT";
	const companionName = Players.GetPlayerByUserId(row.UserId)?.GetAttribute("Companion");
	const companionRank = Players.GetPlayerByUserId(row.UserId)?.GetAttribute("CompanionRank");
	const bondTag = typeIs(companionRank, "number") ? ` (BOND ${companionRank})` : "";
	const companion = typeIs(companionName, "string") && companionName !== "" ? "  ·  WITH " + string.upper(companionName) + bondTag : "";
	return h(
		"frame",
		{
			Name: "PlayerCard",
			ref: rowRef,
			Size: openAmount.map((amount) => new UDim2(1, 0, 0, rowH + math.round(detailsH * math.clamp(amount, 0, 1)))),
			LayoutOrder: param.order,
			BackgroundColor3: hover.map((amount) => Palette.panel.Lerp(darken(accent, 0.7), math.clamp(amount, 0, 1) * 0.8)),
			BorderSizePixel: 0,
			ClipsDescendants: true,
			ZIndex: 620,
		},
		h("uicorner", { CornerRadius: new UDim(0, 14) }),
		h(
			"uistroke",
			{
				// your own row always carries a 1.5px mango rim so you can find yourself at a glance
				Color: row.IsLocal ? Palette.mango : style.frame?.Gradient ? new Color3(1, 1, 1) : strokeColor,
				// compact rows show the frame as a left bar instead, so the thin card keeps a 1px edge
				Thickness: row.IsLocal ? 1.5 : compact ? 1 : (style.frame?.Thickness ?? 1),
				Transparency: row.IsLocal
					? hover.map((amount) => 0.1 - math.clamp(amount, 0, 1) * 0.1)
					: hover.map((amount) => (style.frame !== undefined ? 0.45 : 0.8) - math.clamp(amount, 0, 1) * 0.45),
			},
			!row.IsLocal &&
				style.frame?.Gradient === true &&
				h("uigradient", {
					Color: new ColorSequence([
						new ColorSequenceKeypoint(0, strokeColor),
						new ColorSequenceKeypoint(0.5, Palette.violet),
						new ColorSequenceKeypoint(1, Palette.mango),
					]),
					Rotation: 35,
				}),
		),
		h(
			"textbutton",
			{
				Size: new UDim2(1, 0, 0, rowH),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				ZIndex: 621,
				ref: rowHitRef,
				Event: {
					// a tap on a swiped row just closes the actions
					Activated: () => {
						if (os.clock() - swipeAt.current < 0.5) {
							return;
						}
						if (swiped) {
							InteractionFeedback.tick();
							setSwiped(false);
							return;
						}
						param.onToggle();
					},
					InputBegan: (_: TextButton, input: InputObject) => {
						if (canSwipe && input.UserInputType === Enum.UserInputType.Touch) {
							touchStart.current = input.Position;
						}
					},
					InputChanged: (_: TextButton, input: InputObject) => {
						const start = touchStart.current;
						if (start === undefined || input.UserInputType !== Enum.UserInputType.Touch) {
							return;
						}
						const dx = input.Position.X - start.X;
						if (math.abs(input.Position.Y - start.Y) > 24) {
							touchStart.current = undefined; // the list is scrolling
						} else if (dx < -40) {
							touchStart.current = undefined;
							swipeAt.current = os.clock();
							// the same light tick the other swipe-and-snap controls give when they open
							if (!swiped) InteractionFeedback.tick();
							setSwiped(true);
						} else if (dx > 30) {
							touchStart.current = undefined;
							swipeAt.current = os.clock();
							setSwiped(false);
						}
					},
					InputEnded: (_: TextButton, input: InputObject) => {
						if (input.UserInputType === Enum.UserInputType.Touch) {
							touchStart.current = undefined;
						}
					},
					MouseEnter: () => setHovered(true),
					MouseLeave: () => setHovered(false),
					SelectionGained: () => setHovered(true),
					SelectionLost: () => setHovered(false),
				},
			},
			artifact !== undefined &&
				h(ElementFx, {
					element: artifact.Element,
					size: compact ? UDim2.fromOffset(46, 46) : UDim2.fromOffset(66, 66),
					position: new UDim2(0, (compact ? 24 : 30) + rankW, 0.5, compact ? -2 : -3),
					transparency: 0.2,
					reducedMotion: reducedMotion,
					zIndex: 622,
					// a newly equipped or upgraded artifact pops on the player card
					reaction: "equip",
					reactionKey: `${artifact.Name}:${artifact.Level}`,
				}),
			h(Text, {
				value: `#${param.rank}`,
				size: compact ? 12 : 14,
				color: topRank ? Palette.mango : Palette.muted,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				fit: true,
				minSize: 8,
				position: new UDim2(0, 6, 0.5, -9),
				sizeConstraint: UDim2.fromOffset(rankW, 18),
				zIndex: 623,
			}),
			h(Avatar, {
				userId: row.UserId,
				accent: topRank ? Palette.mango : artifactColor ?? accent,
				size: avatarSize,
				away: away,
				position: new UDim2(0, 10 + rankW, 0.5, 0),
			}),
			compact &&
				style.frame !== undefined &&
				h(
					"frame",
					{
						Size: new UDim2(0, 3, 1, -14),
						Position: UDim2.fromOffset(2, 7),
						BackgroundColor3: style.frame.Gradient ? new Color3(1, 1, 1) : strokeColor,
						BorderSizePixel: 0,
						ZIndex: 624,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					style.frame.Gradient &&
						h("uigradient", {
							Color: new ColorSequence([
								new ColorSequenceKeypoint(0, strokeColor),
								new ColorSequenceKeypoint(0.5, Palette.violet),
								new ColorSequenceKeypoint(1, Palette.mango),
							]),
							Rotation: 90,
						}),
				),
			h(Text, {
				// compact: the first tag (YOU, CREW, FRIEND, AWAY) rides on the name; world and rebirths are in the details
				value: compact && tags.size() > 0 ? `${row.DisplayName} · ${tags[0]}` : row.DisplayName,
				size: compact ? 14 : 15,
				color: style.accent !== undefined ? lighten(style.accent, 0.12) : Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 11,
				position: compact ? UDim2.fromOffset(46 + rankW, 12) : UDim2.fromOffset(60 + rankW, 9),
				sizeConstraint: compact
					? new UDim2(1, -46 - rankW - 96, 0, 20)
					: new UDim2(1, -150 - rankW - (param.crewmate ? 24 : 0), 0, 20),
				zIndex: 623,
			}),
			!compact &&
				param.crewmate &&
				h(Icon, {
					kind: "Crew.18",
					color: Palette.cream,
					accent: Palette.mint,
					size: 16,
					spin: false,
					position: new UDim2(1, -112, 0, 11),
				}),
			!compact &&
			h(Text, {
				value: tags.size() > 0 ? tags.join(" · ") + "  ·  " + subtitle : subtitle,
				size: 10,
				color: away ? Palette.mango : artifactColor !== undefined ? lighten(artifactColor, 0.18) : accent,
				weight: Enum.FontWeight.Bold,
				fit: true,
				minSize: 8,
				position: UDim2.fromOffset(60 + rankW, 32),
				sizeConstraint: new UDim2(1, -150 - rankW, 0, 16),
				zIndex: 623,
			}),
			h(Text, {
				value: statValue,
				size: 13,
				color: topRank ? Palette.mango : Palette.creamSoft,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Right,
				fit: true,
				minSize: 9,
				position: new UDim2(1, -110, 0, compact ? 13 : 12),
				sizeConstraint: UDim2.fromOffset(78, 18),
				zIndex: 623,
			}),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(12, 12),
					Position: new UDim2(1, -18, 0.5, 0),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: openAmount.map((amount) => math.clamp(amount, 0, 1) * 180),
					BackgroundTransparency: 1,
					ZIndex: 623,
				},
				h("frame", {
					Size: UDim2.fromOffset(7, 2),
					Position: new UDim2(0.5, -2, 0.5, 0),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: 45,
					BackgroundColor3: Palette.muted,
					BorderSizePixel: 0,
				}),
				h("frame", {
					Size: UDim2.fromOffset(7, 2),
					Position: new UDim2(0.5, 2, 0.5, 0),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: -45,
					BackgroundColor3: Palette.muted,
					BorderSizePixel: 0,
				}),
			),
		),
		canSwipe &&
			!blocked &&
			h(
				"frame",
				{
					Name: "SwipeActions",
					Size: UDim2.fromOffset(SWIPE_W, rowH - 8),
					Position: swipeAmount.map((amount) => new UDim2(1, math.round(-(SWIPE_W + 6) * math.clamp(amount, 0, 1)) + (1 - math.clamp(amount, 0, 1)) * 6, 0, 4)),
					Visible: swipeAmount.map((amount) => amount > 0.01),
					BackgroundTransparency: 1,
					ZIndex: 630,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					Padding: new UDim(0, 6),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h("frame", { Size: UDim2.fromOffset((SWIPE_W - 6) / 2, rowH - 8), LayoutOrder: 1, BackgroundTransparency: 1 },
					h(ActionButton, { order: 1, text: "MESSAGE", icon: "Chat.7", color: Palette.cyan, onClick: () => { setSwiped(false); param.onMessage(); }, reducedMotion: reducedMotion })),
				h("frame", { Size: UDim2.fromOffset((SWIPE_W - 6) / 2, rowH - 8), LayoutOrder: 2, BackgroundTransparency: 1 },
					h(ActionButton, { order: 2, text: param.visiting ? "GO HOME" : "VISIT", icon: "Visit.6", color: param.visiting ? Palette.green : Palette.violet, onClick: () => { setSwiped(false); param.onVisit(); }, reducedMotion: reducedMotion })),
			),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, detailsH),
				Position: UDim2.fromOffset(0, rowH),
				BackgroundTransparency: 1,
				Visible: openAmount.map((amount) => amount > 0.01),
				ZIndex: 624,
			},
			h(
				"frame",
				{
					Size: new UDim2(1, -16, 0, 2 * 40 + 6),
					Position: UDim2.fromOffset(8, 8),
					BackgroundTransparency: 1,
					ZIndex: 624,
				},
				h("uigridlayout", {
					CellSize: UDim2.fromOffset(math.floor((math.max(0, width - 16) - 12) / 3), 40),
					FillDirectionMaxCells: 3,
					CellPadding: UDim2.fromOffset(6, 6),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(StatCell, {
					order: 1,
					label: "WORLD",
					value: `${compactNumber(row.CurrentZone)} / ${compactNumber(row.Zone)}`,
				}),
				h(StatCell, { order: 2, label: "REBIRTHS", value: compactNumber(row.Rebirths) }),
				h(StatCell, { order: 3, label: "OUTPUT", value: `${compactNumber(row.Production)}/s`, color: Palette.mint }),
				h(StatCell, { order: 4, label: "LIFETIME", value: compactNumber(row.LifetimeCash) }),
				h(StatCell, { order: 5, label: "DOMAIN", value: compactNumber(row.DomainRank), color: Palette.violet }),
				h(StatCell, { order: 6, label: "PLAYED", value: Model.playTime(row.PlayTime) }),
			),
			row.IsLocal &&
				h(Text, {
					value:
						(artifact !== undefined
							? `ARTIFACT  ${artifact.Name} · ${artifact.Rarity} · LV ${artifact.Level}${
									artifact.Effect !== undefined ? "  ·  " + artifact.Effect : ""
								}`
							: "ARTIFACT  none equipped") + companion,
					size: 10,
					color: artifactColor ?? Palette.muted,
					weight: Enum.FontWeight.Heavy,
					fit: true,
					minSize: 8,
					position: UDim2.fromOffset(10, 8 + 2 * 40 + 8),
					sizeConstraint: new UDim2(1, -20, 0, 16),
					zIndex: 625,
				}),
			!row.IsLocal &&
				h(Text, {
					value: `${
						artifact !== undefined
							? string.upper(artifact.Name) + (artifact.Effect !== undefined ? " " + artifact.Effect : "")
							: relics
					}${companion}  ·  ACCOUNT ${Model.accountAge(row.AccountAge)}${row.Premium ? "  ·  PREMIUM" : ""}`,
					size: 10,
					color: artifactColor ?? Palette.muted,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 8,
					position: UDim2.fromOffset(10, 8 + 2 * 40 + 8),
					sizeConstraint: new UDim2(1, -20, 0, 16),
					zIndex: 625,
				}),
			actions,
		),
	);
}

interface ReportSheetProps {
	target: Row;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	width: number;
	maxHeight: number;
	onBlock: () => void;
	onClose: () => void;
}

function ReportSheet(param: ReportSheetProps) {
	const hostRef = React.useRef<Frame>();
	const hostSize = useGuiSize(hostRef);
	const target = param.target;
	const reducedMotion = param.reducedMotion;
	const [reason, setReason] = React.useState<string | undefined>(undefined);
	const [severity, setSeverity] = React.useState("Minor");
	const [when, setWhen] = React.useState("Now");
	const [where, setWhere] = React.useState("World");
	const [details, setDetails] = React.useState("");
	const [alsoBlock, setAlsoBlock] = React.useState(false);
	const [phase, setPhase] = React.useState("form");
	const [errorText, setErrorText] = React.useState<string | undefined>(undefined);
	const enter = useFlipperSpring(1, reducedMotion, 620, 42, 0);
	const alive = React.useRef(true);
	React.useEffect(() => {
		return () => {
			alive.current = false;
		};
	}, []);
	const send = () => {
		if (reason === undefined || phase !== "form") {
			return undefined;
		}
		setPhase("sending");
		setErrorText(undefined);
		Audio.play("dangerPress");
		param.dispatch(
			"ReportPlayer",
			{
				UserId: target.UserId,
				userId: target.UserId,
				Reason: reason,
				Details: Model.details(details),
				Severity: severity,
				When: when,
				Where: where,
			},
			(response) => {
				if (!alive.current) {
					return undefined;
				}
				if (!response.ok) {
					setPhase("form");
					setErrorText(response.error ?? "Couldn't send the report. Try again in a moment.");
					return undefined;
				}
				reportedAt[target.UserId] = os.clock();
				setPhase("sent");
				Audio.play("reportSubmit");
				if (alsoBlock) {
					param.onBlock();
				}
			},
		);
	};
	const reasonCells: Record<string, unknown> = {};
	reasonCells.layout = h("uigridlayout", {
		CellSize: new UDim2(0.5, -4, 0, 64),
		CellPadding: UDim2.fromOffset(8, 8),
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	for (const [order, entry] of ipairs(Model.REASONS)) {
		const picked = reason === entry.id;
		reasonCells[entry.id] = h(
			"frame",
			{
				LayoutOrder: order,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 704,
			},
			h(Button, {
				text: "",
				size: UDim2.fromScale(1, 1),
				color: picked ? darken(Palette.coral, 0.45) : Palette.panelSoft,
				reducedMotion: reducedMotion,
				highlight: picked,
				sound: "tabSwitch",
				disabled: phase !== "form",
				zIndex: 704,
				onClick: () => setReason(entry.id),
				children: h(
					React.Fragment,
					undefined,
					h(Text, {
						value: string.upper(entry.label),
						size: 11,
						color: picked ? Palette.cream : Palette.creamSoft,
						weight: Enum.FontWeight.Heavy,
						fit: true,
						minSize: 9,
						position: UDim2.fromOffset(10, 10),
						sizeConstraint: new UDim2(1, -16, 0, 16),
						zIndex: 710,
					}),
					h(Text, {
						value: entry.detail,
						size: 10,
						color: Palette.muted,
						wrap: true,
						fit: true,
						minSize: 9,
						position: UDim2.fromOffset(10, 29),
						sizeConstraint: new UDim2(1, -16, 0, 28),
						zIndex: 710,
					}),
				),
			}),
		);
	}
	const width = param.width;
	const reasonRows = math.ceil(Model.REASONS.size() / 2);
	const CHIP_ROW = 52;
	const contextH = CHIP_ROW * 3 + 4;
	const chipRow = (label: string, options: Option[], value: string, onPick: (id: string) => void, accent: Color3, order: number) => {
		const cells: Record<string, unknown> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				Padding: new UDim(0, 6),
				VerticalAlignment: Enum.VerticalAlignment.Center,
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		const count = options.size();
		for (const [index, option] of ipairs(options)) {
			const picked = value === option.id;
			cells[option.id] = h(
				"frame",
				{
					LayoutOrder: index,
					Size: new UDim2(1 / count, -math.ceil((6 * (count - 1)) / count), 0, 48),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 705,
				},
				h(Button, {
					text: "",
					size: UDim2.fromScale(1, 1),
					color: picked ? darken(accent, 0.5) : Palette.panelSoft,
					textColor: Palette.creamSoft,
					highlight: picked,
					onClick: () => onPick(option.id),
					sound: "tabSwitch",
					reducedMotion: reducedMotion,
					disabled: phase !== "form",
					zIndex: 705,
					children: h(Text, {
						value: string.upper(option.label),
						size: 11,
						fit: true,
						minSize: 9,
						wrap: true,
						align: Enum.TextXAlignment.Center,
						weight: Enum.FontWeight.Bold,
						position: UDim2.fromOffset(4, 4),
						sizeConstraint: new UDim2(1, -8, 1, -8),
						zIndex: 711,
					}),
				}),
			);
		}
		return h(
			"frame",
			{
				LayoutOrder: order,
				Size: new UDim2(1, 0, 0, CHIP_ROW),
				BackgroundTransparency: 1,
				ZIndex: 704,
			},
			h(Text, {
				value: label,
				size: 10,
				color: Palette.muted,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 8,
				position: UDim2.fromOffset(0, 18),
				sizeConstraint: new UDim2(0, 58, 0, 14),
				zIndex: 705,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -62, 1, 0),
					Position: UDim2.fromOffset(62, 0),
					BackgroundTransparency: 1,
					ZIndex: 704,
				},
				cells,
			),
		);
	};
	const severityAccent = severity === "Urgent" ? Palette.coral : severity === "Serious" ? Palette.mango : Palette.cyan;
	const contextBlock = h(
		"frame",
		{
			Size: new UDim2(1, -28, 0, contextH),
			Position: UDim2.fromOffset(14, 48 + reasonRows * 72),
			BackgroundTransparency: 1,
			ZIndex: 703,
		},
		h("uilistlayout", { Padding: new UDim(0, 2), SortOrder: Enum.SortOrder.LayoutOrder }),
		chipRow("HOW BAD", Model.SEVERITIES, severity, setSeverity, severityAccent, 1),
		chipRow("WHEN", Model.WHENS, when, setWhen, Palette.cyan, 2),
		chipRow("WHERE", Model.WHERES, where, setWhere, Palette.cyan, 3),
	);
	const formH = 48 + reasonRows * 72 + contextH + 8 + 70 + 54 + 64 + (errorText !== undefined ? 18 : 0);
	let body: React.Element;
	if (phase === "sent") {
		body = h(
			"frame",
			{ Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 703 },
			h(
				"frame",
				{
					Size: UDim2.fromOffset(56, 56),
					Position: new UDim2(0.5, 0, 0, 30),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundColor3: darken(Palette.mint, 0.5),
					BorderSizePixel: 0,
					ZIndex: 704,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h(Icon, { kind: "Check.26", color: Palette.cream, accent: Palette.mint, size: 56, spin: false }),
			),
			h(Text, {
				value: "REPORT SENT",
				size: 16,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				position: UDim2.fromOffset(0, 98),
				sizeConstraint: new UDim2(1, 0, 0, 22),
				zIndex: 704,
			}),
			h(Text, {
				value: alsoBlock ? `Thanks. You also blocked ${target.DisplayName}.` : "Report sent.",
				size: 12,
				color: Palette.muted,
				align: Enum.TextXAlignment.Center,
				wrap: true,
				fit: true,
				minSize: 11,
				position: UDim2.fromOffset(10, 124),
				sizeConstraint: new UDim2(1, -20, 0, 34),
				zIndex: 704,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -20, 0, 40),
					Position: new UDim2(0, 10, 1, -50),
					BackgroundTransparency: 1,
					ZIndex: 704,
				},
				h(Button, {
					text: "DONE",
					icon: "Check.27",
					onClick: param.onClose,
					color: Palette.mint,
					textColor: Palette.ink,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
					zIndex: 705,
				}),
			),
		);
	} else {
		body = h(
			React.Fragment,
			undefined,
			h(Text, {
				value: `REPORT ${string.upper(target.DisplayName)}`,
				size: 15,
				color: Palette.coral,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 11,
				position: UDim2.fromOffset(14, 10),
				sizeConstraint: new UDim2(1, -28, 0, 20),
				zIndex: 704,
			}),
			h(Text, {
				value: "What happened?",
				size: 11,
				color: Palette.muted,
				position: UDim2.fromOffset(14, 28),
				sizeConstraint: new UDim2(1, -28, 0, 14),
				zIndex: 704,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -28, 0, reasonRows * 72),
					Position: UDim2.fromOffset(14, 48),
					BackgroundTransparency: 1,
					ZIndex: 703,
				},
				reasonCells,
			),
			contextBlock,
			h(
				"frame",
				{
					Size: new UDim2(1, -28, 0, 62),
					Position: UDim2.fromOffset(14, 48 + reasonRows * 72 + contextH + 4),
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
					ZIndex: 704,
				},
				h("uicorner", { CornerRadius: new UDim(0, 10) }),
				h("uistroke", { Color: Palette.lineSoft, Transparency: 0.5 }),
				h("textbox", {
					Size: new UDim2(1, -16, 1, -18),
					Position: UDim2.fromOffset(8, 4),
					BackgroundTransparency: 1,
					Text: details,
					PlaceholderText: "Details (optional): what did they do, and when?",
					PlaceholderColor3: Palette.muted,
					TextColor3: Palette.cream,
					TextSize: 12,
					FontFace: Font.fromEnum(Enum.Font.BuilderSans),
					TextWrapped: true,
					TextXAlignment: Enum.TextXAlignment.Left,
					TextYAlignment: Enum.TextYAlignment.Top,
					ClearTextOnFocus: false,
					MultiLine: true,
					ZIndex: 705,
					Change: {
						Text: (box: TextBox) => {
							let value = box.Text;
							if (value.size() > Model.DETAILS_MAX) {
								value = value.sub(1, Model.DETAILS_MAX);
								const [, brokenAt] = utf8.len(value);
								if (brokenAt !== undefined) {
									value = value.sub(1, brokenAt - 1);
								}
								box.Text = value;
							}
							setDetails(value);
						},
					},
				}),
				h(Text, {
					value: `${details.size()} / ${Model.DETAILS_MAX}`,
					size: 9,
					color: Palette.muted,
					align: Enum.TextXAlignment.Right,
					position: new UDim2(0, 8, 1, -14),
					sizeConstraint: new UDim2(1, -16, 0, 12),
					zIndex: 705,
				}),
			),
			h(
				"frame",
				{
					Size: new UDim2(1, -28, 0, 48),
					Position: UDim2.fromOffset(14, 48 + reasonRows * 72 + contextH + 78),
					BackgroundTransparency: 1,
					ZIndex: 704,
				},
				h(Button, {
					text: `Also block ${target.DisplayName}: ${alsoBlock ? "ON" : "OFF"}`,
					icon: alsoBlock ? "Check.28" : "Lock.19",
					size: UDim2.fromScale(1, 1),
					color: alsoBlock ? darken(Palette.coral, 0.45) : Palette.panelSoft,
					textColor: Palette.creamSoft,
					highlight: alsoBlock,
					reducedMotion: reducedMotion,
					disabled: phase !== "form",
					sound: alsoBlock ? "toggleOff" : "toggleOn",
					onClick: () => setAlsoBlock(!alsoBlock),
					zIndex: 705,
				}),
			),
			errorText !== undefined &&
				h(Text, {
					value: errorText,
					size: 11,
					color: Palette.coral,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					position: new UDim2(0, 14, 1, -70),
					sizeConstraint: new UDim2(1, -28, 0, 16),
					zIndex: 704,
				}),
			h(
				"frame",
				{
					Size: new UDim2(1, -28, 0, 48),
					Position: new UDim2(0, 14, 1, -58),
					BackgroundTransparency: 1,
					ZIndex: 704,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					Padding: new UDim(0, 8),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(
					"frame",
					{ Size: new UDim2(0.4, -4, 1, 0), LayoutOrder: 1, BackgroundTransparency: 1 },
					h(Button, {
						text: "CANCEL",
						onClick: param.onClose,
						color: Palette.panelSoft,
						textColor: Palette.creamSoft,
						outline: true,
						size: UDim2.fromScale(1, 1),
						reducedMotion: reducedMotion,
						disabled: phase === "sending",
						zIndex: 705,
					}),
				),
				h(
					"frame",
					{ Size: new UDim2(0.6, -4, 1, 0), LayoutOrder: 2, BackgroundTransparency: 1 },
					h(Button, {
						text: phase === "sending" ? "SENDING..." : reason === undefined ? "PICK A REASON" : "SEND REPORT",
						icon: "Admin.3",
						onClick: send,
						color: Palette.coral,
						textColor: Palette.ink,
						size: UDim2.fromScale(1, 1),
						reducedMotion: reducedMotion,
						disabled: reason === undefined || phase === "sending",
						highlight: reason !== undefined,
						zIndex: 705,
					}),
				),
			),
		);
	}
	const sheetH = phase === "sent" ? 230 : formH;
	return h(
		"frame",
		{
			ref: hostRef,
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: enter.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.5),
			BorderSizePixel: 0,
			Active: true,
			ZIndex: 700,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(width, math.min(sheetH, param.maxHeight)),
				Position: React.joinBindings([enter, hostSize] as React.Binding<unknown>[]).map((values) =>
					pixelPosition(values[1] as Vector2, 0.5, 0, 0.5, (1 - math.clamp(values[0] as number, 0, 1)) * 24),
				),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.panelRaised,
				BorderSizePixel: 0,
				ClipsDescendants: true,
				ZIndex: 702,
			},
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uistroke", { Color: Palette.coral, Thickness: 1.25, Transparency: 0.35 }),
			h(
				"scrollingframe",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					CanvasSize: UDim2.fromOffset(0, sheetH),
					ScrollingDirection: Enum.ScrollingDirection.Y,
					ScrollBarThickness: sheetH > param.maxHeight ? 3 : 0,
					VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
					ScrollBarImageColor3: Palette.coral,
					ScrollingEnabled: sheetH > param.maxHeight,
					ZIndex: 702,
				},
				h("frame", { Size: new UDim2(1, 0, 0, sheetH), BackgroundTransparency: 1, ZIndex: 702 }, body),
			),
		),
	);
}

interface PlayerlistState {
	CurrentZone?: unknown;
	Zone?: unknown;
	Rebirths?: unknown;
	SocialBoost?: { FriendCount: number; FriendLimit: number; FriendBonus: number; Premium?: boolean; PremiumBonus: number };
}

interface PlayerlistOverlayProps {
	state: PlayerlistState;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	onClose: () => void;
	onMessage?: (userId: number) => void;
	notify: (title: string, body: string) => void;
}

export function PlayerlistOverlay(param: PlayerlistOverlayProps) {
	const state = param.state;
	const dispatch = param.dispatch;
	const reducedMotion = param.reducedMotion;
	const onClose = param.onClose;
	const onMessage = param.onMessage;
	const notify = param.notify;
	const visitingId = useClientSelector((client) => {
		const visit = client.visit;
		return typeIs(visit, "table") ? (visit as { UserId?: unknown }).UserId : undefined;
	});
	const visitingSomeone = visitingId !== undefined;
	// LeavePlot is quiet in the shell, so toast the server's own reply here
	const goHome = () => {
		dispatch("LeavePlot", {}, (response) => {
			if (!typeIs(response, "table") || !truthyNotify(notify)) {
				return;
			}
			if (response.ok) {
				notify("Home", response.message ?? "Back at your workshop.");
			} else {
				notify("Home", response.error ?? "Couldn't head home. Try again.");
			}
		});
	};
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const localPlayer = Players.LocalPlayer;
	const localRow = React.useMemo(
		() =>
			Model.clean([
				{
					UserId: localPlayer.UserId,
					Name: localPlayer.Name,
					DisplayName: localPlayer.DisplayName,
					CurrentZone: state.CurrentZone,
					Zone: state.Zone,
					Rebirths: state.Rebirths,
					IsLocal: true,
				},
			])[0],
		[state.CurrentZone, state.Zone, state.Rebirths],
	);
	const [rows, setRows] = React.useState<Row[]>(() => [localRow]);
	const [expandedId, setExpandedId] = React.useState<number | undefined>(undefined);
	const [sortId, setSortId] = React.useState("Production");
	const [query, setQuery] = React.useState("");
	const [friendsOnly, setFriendsOnly] = React.useState(false);
	const [friends, setFriends] = React.useState<Record<number, boolean>>({});
	const [blocked, setBlocked] = React.useState<Record<number, boolean>>({});
	const [reportTarget, setReportTarget] = React.useState<Row | undefined>(undefined);
	const [inviteBusy, setInviteBusy] = React.useState(false);
	const [awayTick, setAwayTick] = React.useState(0);
	const alive = React.useRef(true);
	const [exitAmount, exiting, beginExit] = useExitTransition(reducedMotion);
	const enter = useEntrance(reducedMotion);
	React.useEffect(() => {
		alive.current = true;
		Audio.play("playerlistOpen");
		const ticker = task.spawn(() => {
			while (true) {
				task.wait(2);
				setAwayTick((current) => current + 1);
			}
		});
		return () => {
			alive.current = false;
			task.cancel(ticker);
		};
	}, []);

	const refresh = React.useCallback(() => {
		dispatch("GetPlayers", {}, (response) => {
			if (!alive.current || !response.ok) {
				return undefined;
			}
			const cleaned = Model.clean(response.Players ?? {}, TEST_BOT_USER_ID);
			setRows(cleaned.size() > 0 ? cleaned : [localRow]);
		});
	}, [dispatch, localRow]);
	const applyRoster = React.useCallback(() => {
		setRows((current) => {
			const known: Record<number, Row> = {};
			for (const row of current) {
				known[row.UserId] = row;
			}
			const nextRows = [localRow];
			for (const player of Players.GetPlayers()) {
				if (player.UserId !== localRow.UserId && player.UserId !== TEST_BOT_USER_ID) {
					nextRows.push(
						known[player.UserId] ??
							Model.clean([{ UserId: player.UserId, Name: player.Name, DisplayName: player.DisplayName }])[0],
					);
				}
			}
			return nextRows;
		});
	}, [localRow]);
	React.useEffect(() => {
		refresh();
		applyRoster();
		let debounce: thread | undefined;
		const onRoster = () => {
			applyRoster();
			if (debounce !== undefined) {
				task.cancel(debounce);
			}
			debounce = task.delay(0.35, () => {
				debounce = undefined;
				if (alive.current) {
					refresh();
				}
			});
		};
		const joined = Players.PlayerAdded.Connect(onRoster);
		const left = Players.PlayerRemoving.Connect(onRoster);
		const pulse = task.spawn(() => {
			while (alive.current) {
				task.wait(10);
				if (alive.current) {
					refresh();
				}
			}
		});
		return () => {
			joined.Disconnect();
			left.Disconnect();
			if (debounce !== undefined) {
				task.cancel(debounce);
			}
			task.cancel(pulse);
		};
	}, [applyRoster, refresh]);

	const syncSocial = React.useCallback(() => {
		task.spawn(() => {
			const now = os.clock();
			const nextFriends: Record<number, boolean> = {};
			for (const player of Players.GetPlayers()) {
				const userId = player.UserId;
				if (userId === localPlayer.UserId) {
					continue;
				}
				let cached = friendCache[userId];
				if (cached === undefined || now - cached.at > FRIEND_TTL) {
					const [ok, isFriend] = pcall(() =>
						(localPlayer as unknown as { IsFriendsWithAsync(userId: number): boolean }).IsFriendsWithAsync(userId),
					);
					cached = { at: now, value: ok && isFriend === true };
					friendCache[userId] = cached;
				}
				if (cached.value) {
					nextFriends[userId] = true;
				}
			}
			const nextBlocked: Record<number, boolean> = {};
			const [ok, raw] = pcall(() => StarterGui.GetCore("GetBlockedUserIds") as unknown);
			if (ok && typeIs(raw, "table")) {
				for (const [, value] of pairs(raw as Record<string, unknown>)) {
					if (typeIs(value, "number")) {
						nextBlocked[math.floor(value)] = true;
					}
				}
			}
			if (alive.current) {
				setFriends(nextFriends);
				setBlocked(nextBlocked);
			}
		});
	}, []);
	React.useEffect(() => {
		syncSocial();
		let friendship: RBXScriptConnection | undefined;
		pcall(() => {
			const signals = localPlayer as unknown as { FriendStatusChanged: RBXScriptSignal<(other: Player) => void> };
			friendship = signals.FriendStatusChanged.Connect((other) => {
				friendCache[other.UserId] = undefined;
				syncSocial();
			});
		});
		return () => {
			if (friendship !== undefined) {
				friendship.Disconnect();
			}
		};
	}, [rows.size(), syncSocial]);

	const close = React.useCallback(() => {
		if (exiting) {
			return undefined;
		}
		Audio.play("playerlistClose");
		beginExit(onClose);
	}, [beginExit, exiting, onClose]);
	// an open report form backs out first, then the list closes
	const back = () => {
		if (reportTarget !== undefined) {
			setReportTarget(undefined);
		} else {
			close();
		}
	};
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.Escape && !processed) {
				back();
			}
		});
		return () => connection.Disconnect();
	}, [close, reportTarget]);
	useBackLayer(true, back);

	const peerOf = (row: Row) => {
		const player = Players.GetPlayerByUserId(row.UserId);
		if (player === undefined) {
			notify("Player left", "That player is no longer in this server.");
		}
		return player;
	};
	const promptCore = (key: string, row: Row) => {
		const player = peerOf(row);
		if (player === undefined) {
			return undefined;
		}
		const [ok] = pcall(() => {
			StarterGui.SetCore(key as "PromptBlockPlayer", player);
		});
		if (!ok) {
			notify("Roblox menu unavailable", "Wait a moment, then try again.");
			return undefined;
		}
		Audio.play("playerlistAction");
		task.delay(2, () => {
			friendCache[row.UserId] = undefined;
			if (alive.current) {
				syncSocial();
			}
		});
	};
	const invite = () => {
		if (inviteBusy) {
			return undefined;
		}
		setInviteBusy(true);
		Audio.play("invite");
		task.spawn(() => {
			const [canCheck, canInvite] = pcall(() => SocialService.CanSendGameInviteAsync(localPlayer));
			const opened =
				canCheck &&
				canInvite === true &&
				pcall(() => {
					SocialService.PromptGameInvite(localPlayer);
				})[0];
			if (!alive.current) {
				return;
			}
			setInviteBusy(false);
			if (!opened) {
				notify("Invites unavailable", "Roblox could not open the invite panel on this device.");
			}
		});
	};

	const padFocus = useGamepadAutofocus(true, enter);
	const social = state.SocialBoost ?? { FriendCount: 0, FriendLimit: 5, FriendBonus: 0, Premium: false, PremiumBonus: 0 };
	const listParentSize = useGuiSize(padFocus, true);
	const side = math.max(chrome.sideSafe, viewport.sideInset, 8) + 6;
	const top = math.max(viewport.topInset, 36) + 8;
	const bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 8;
	// never wider or taller than the room left between the safe insets (286px phones, 286px-tall landscape)
	const width = math.min(viewport.width - 12, math.max(240, math.min(viewport.height < 500 ? 560 : 620, viewport.width - side * 2)));
	const height = math.max(1, math.min(680, viewport.height - top - bottom));
	const innerW = width - 20;
	const showSearch = rows.size() >= Model.SEARCH_MIN_ROWS;
	const headerH = 58;
	const boostH = 52;
	const controlsTop = headerH + boostH + 14;
	// phones and touch: filter chips and the search box get a full 44px row so the
	// scroller doesn't clip their hit area down to the drawn 28px
	const touchRows = useTouchTargets();
	const ctlH = touchRows ? TapTarget : 30;
	const controlsH = ctlH + (showSearch ? ctlH + 8 : 0);
	const listTop = controlsTop + controlsH + 8;
	// 640x286 landscape: header, boost and controls leave the list almost nothing, so the boost
	// strip and the controls move into a left column and the list runs full height beside them
	const shortRoster = height - listTop - 10 < 96 && innerW >= 360;
	const colW = shortRoster ? math.floor(innerW * 0.45) : innerW;
	const listX = shortRoster ? 10 + colW + 8 : 10;
	const listW = shortRoster ? innerW - colW - 8 : innerW;
	const listY = shortRoster ? headerH + 6 : listTop;
	const listH = shortRoster ? math.max(1, height - listY - 10) : math.max(80, height - listTop - 10);
	// pad: invite, filters, the player rows, then the rest of the sheet (search, home, close)
	useFocusOrder(
		padFocus,
		{
			regions: ["RosterBoost", "RosterFilters", "RosterList", "Roster"],
			first: ["RosterList", "RosterBoost"],
			columns: shortRoster ? [["RosterBoost", "RosterList"], ["RosterFilters", "RosterList"]] : [],
		},
		[shortRoster, showSearch],
	);

	const visible = Model.view(rows, sortId, query, friendsOnly, friends);
	const rankOf = Model.ranks(rows, sortId);
	const crewState = (require(AstralForge.WaitForChild("CrewStore") as ModuleScript) as CrewStoreModule).useCrew();
	const crewmates: Record<number, boolean> = {};
	if (crewState.crew) {
		for (const member of crewState.crew.Members) {
			crewmates[member.UserId] = true;
		}
	}
	const listChildren: Record<string, unknown> = {};
	listChildren.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Vertical,
		SortOrder: Enum.SortOrder.LayoutOrder,
		Padding: new UDim(0, ROW_GAP),
	});
	listChildren.pad = h("uipadding", { PaddingRight: new UDim(0, 6), PaddingBottom: new UDim(0, 6) });
	void awayTick;
	for (const [order, row] of ipairs(visible)) {
		const peer = row.IsLocal ? undefined : Players.GetPlayerByUserId(row.UserId);
		const cooledAt = reportedAt[row.UserId];
		listChildren[tostring(row.UserId)] = h(PlayerRow, {
			row: row,
			artifact: Model.artifactOf(row.IsLocal ? localPlayer : peer, row.Artifact),
			order: order,
			width: listW - 9,
			expanded: expandedId === row.UserId,
			friend: friends[row.UserId] === true,
			blocked: blocked[row.UserId] === true,
			away: peer !== undefined && peer.GetAttribute("AF_Away") === true,
			reported: cooledAt !== undefined && os.clock() - cooledAt < REPORT_COOLDOWN,
			reducedMotion: reducedMotion,
			onToggle: () => {
				Audio.play("playerlistSelect");
				setExpandedId(expandedId === row.UserId ? undefined : row.UserId);
			},
			onFriend: () => {
				promptCore(friends[row.UserId] ? "PromptUnfriend" : "PromptSendFriendRequest", row);
			},
			onBlock: () => {
				promptCore(blocked[row.UserId] ? "PromptUnblockPlayer" : "PromptBlockPlayer", row);
			},
			onMessage: () => {
				if (peerOf(row) === undefined || onMessage === undefined) {
					return undefined;
				}
				Audio.play("playerlistAction");
				onMessage(row.UserId);
			},
			onVisit: () => {
				if (peerOf(row) === undefined) {
					return undefined;
				}
				Audio.play("playerlistAction");
				// already on their forge: the same button takes you back (server LeavePlot)
				if (visitingId === row.UserId) {
					goHome();
				} else {
					dispatch("VisitPlot", { UserId: row.UserId });
				}
				onClose();
			},
			crewmate: crewmates[row.UserId] === true,
			rank: rankOf[row.UserId] ?? order,
			sortId: sortId,
			visiting: visitingId === row.UserId,
			onCrew: () => {
				if (peerOf(row) === undefined) {
					return undefined;
				}
				Audio.play("playerlistAction");
				dispatch("CrewInvite", { UserId: row.UserId }, (response) => {
					if (typeIs(response, "table") && truthyNotify(notify)) {
						notify(
							"Crew",
							response.ok ? response.message ?? "Invite sent." : response.error ?? "Couldn't send that invite.",
						);
					}
				});
			},
			onWave: () => {
				if (peerOf(row) === undefined) {
					return undefined;
				}
				Audio.play("playerlistAction");
				dispatch("NudgeCrew", { UserId: row.UserId });
			},
			onTrade: () => {
				if (peerOf(row) === undefined) {
					return undefined;
				}
				Audio.play("playerlistAction");
				dispatch("InviteTrade", { UserId: row.UserId });
			},
			onReport: () => {
				Audio.play("dangerPress");
				setReportTarget(row);
			},
		});
	}
	if (visible.size() <= 1 && (query !== "" || friendsOnly)) {
		listChildren.empty = h(Text, {
			value: friendsOnly ? "No friends in this server right now." : `Nobody matches "${query}".`,
			size: 12,
			color: Palette.muted,
			align: Enum.TextXAlignment.Center,
			sizeConstraint: new UDim2(1, 0, 0, 36),
			zIndex: 620,
		});
	} else if (rows.size() <= 1) {
		// alone in the server: say so, and what bringing people in is worth
		listChildren.empty = h(Text, {
			value: "Just you in here. Invite friends for a production boost, trades, crews and visits.",
			size: 12,
			color: Palette.muted,
			align: Enum.TextXAlignment.Center,
			wrap: true,
			fit: true,
			minSize: 11,
			layoutOrder: 9999,
			sizeConstraint: new UDim2(1, -24, 0, 54),
			zIndex: 620,
		});
	}

	const chips: Record<string, unknown> = {};
	chips.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		Padding: new UDim(0, 6),
		SortOrder: Enum.SortOrder.LayoutOrder,
		VerticalAlignment: Enum.VerticalAlignment.Center,
	});
	const chip = (key: string, order: number, label: string, active: boolean, accent: Color3, onClick: () => void) => {
		chips[key] = h(
			"textbutton",
			{
				Size: UDim2.fromOffset(math.max(56, label.size() * 7 + 22), touchRows ? TapTarget : 28),
				LayoutOrder: order,
				BackgroundColor3: active ? darken(accent, 0.5) : Palette.panel,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Text: "",
				ZIndex: 616,
				Event: {
					Activated: () => {
						Audio.play("tabSwitch");
						onClick();
					},
				},
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: accent, Transparency: active ? 0.15 : 0.7 }),
			h(Text, {
				value: string.upper(label),
				size: 10,
				color: active ? Palette.cream : Palette.creamSoft,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				fit: true,
				minSize: 8,
				position: UDim2.fromOffset(6, 0),
				sizeConstraint: new UDim2(1, -12, 1, 0),
				zIndex: 617,
			}),
		);
	};
	for (const [order, sort] of ipairs(Model.SORTS)) {
		chip("sort" + sort.id, order, sort.label, sortId === sort.id, Palette.cyan, () => setSortId(sort.id));
	}
	chip("friends", Model.SORTS.size() + 1, "Friends", friendsOnly, Palette.mango, () => setFriendsOnly(!friendsOnly));

	const showAmount = composePresence(enter, exitAmount);
	const friendProgress = math.clamp(social.FriendCount / math.max(1, social.FriendLimit), 0, 1);
	return h(
		OverlayPresence,
		{ amount: showAmount },
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Active: true,
				ZIndex: 600,
				Visible: showAmount.map((amount) => amount > 0.003),
			},
			h("textbutton", {
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: showAmount.map((amount) => 1 - amount * 0.44),
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Text: "",
				Selectable: false,
				ZIndex: 600,
				Event: { Activated: close },
			}),
			h(
				"frame",
				{
					ref: padFocus,
					...ModalSelectionScope,
					Name: "Roster",
					Size: UDim2.fromOffset(width, height),
					Position: React.joinBindings([showAmount, listParentSize] as React.Binding<unknown>[]).map((values) =>
						pixelPosition(values[1] as Vector2, 1, -side + (1 - (values[0] as number)) * 24, 0, top),
					),
					AnchorPoint: new Vector2(1, 0),
					BackgroundColor3: Palette.ink,
					BorderSizePixel: 0,
					Active: true,
					ClipsDescendants: true,
					ZIndex: 610,
				},
				h("uicorner", { CornerRadius: new UDim(0, 14) }),
				h("uistroke", { Color: Palette.cyan, Thickness: 1.25, Transparency: 0.55 }),
				h(Icon, { kind: "Crew.18", color: Palette.cream, accent: Palette.cyan, size: 30, spin: false, position: UDim2.fromOffset(14, 14) }),
				h(Text, {
					value: "Roster",
					size: 20,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: visitingSomeone,
					minSize: 12,
					position: UDim2.fromOffset(54, 9),
					sizeConstraint: new UDim2(1, visitingSomeone ? -(112 + HOME_W + 6) : -112, 0, 24),
					zIndex: 613,
				}),
				h(Text, {
					value: tostring(rows.size()),
					size: 10,
					color: Palette.cyan,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(54, 33),
					sizeConstraint: new UDim2(1, visitingSomeone ? -(112 + HOME_W + 6) : -112, 0, 16),
					zIndex: 613,
				}),
				visitingSomeone
					? h(
							"frame",
							{
								Size: UDim2.fromOffset(HOME_W, TapTarget),
								Position: new UDim2(1, -(TapTarget + 8 + 6 + HOME_W), 0, 7),
								BackgroundTransparency: 1,
								ZIndex: 614,
							},
							h(Button, {
								text: "HOME",
								icon: "Visit.6",
								onClick: () => {
									Audio.play("playerlistAction");
									goHome();
									close();
								},
								color: Palette.green,
								textColor: Palette.ink,
								size: UDim2.fromScale(1, 1),
								reducedMotion: reducedMotion,
								disabled: exiting,
								zIndex: 614,
							}),
						)
					: undefined,
				h(
					"frame",
					{
						Size: UDim2.fromOffset(TapTarget, TapTarget),
						Position: new UDim2(1, -(TapTarget + 8), 0, 7),
						BackgroundTransparency: 1,
						ZIndex: 614,
					},
					h(Button, {
						text: "",
						icon: "Close.19",
						onClick: close,
						color: Palette.panel,
						textColor: Palette.cream,
						outline: true,
						size: UDim2.fromScale(1, 1),
						reducedMotion: reducedMotion,
						disabled: exiting,
						zIndex: 614,
					}),
				),
				h(
					"frame",
					{
						Name: "RosterBoost",
						Size: shortRoster ? UDim2.fromOffset(colW, boostH) : new UDim2(1, -20, 0, boostH),
						Position: UDim2.fromOffset(10, headerH + 6),
						BackgroundColor3: Palette.panelRaised,
						BorderSizePixel: 0,
						ZIndex: 612,
					},
					h("uicorner", { CornerRadius: new UDim(0, 10) }),
					h("uistroke", { Color: Palette.mint, Transparency: 0.55 }),
					h(Text, {
						value: `FRIEND BOOST  ${social.FriendCount}/${social.FriendLimit}  ·  +${math.floor(social.FriendBonus * 100 + 0.5)}%`,
						size: 11,
						color: Palette.mint,
						weight: Enum.FontWeight.Heavy,
						fit: true,
						minSize: 8,
						position: UDim2.fromOffset(10, 8),
						sizeConstraint: new UDim2(0.6, -14, 0, 16),
						zIndex: 613,
					}),
					h(Text, {
						value: social.Premium
							? `PREMIUM +${math.floor(social.PremiumBonus * 100 + 0.5)}%`
							: "Friends boost output",
						size: 10,
						color: social.Premium ? Palette.mango : Palette.muted,
						weight: Enum.FontWeight.Bold,
						fit: true,
						minSize: 8,
						position: UDim2.fromOffset(10, 25),
						sizeConstraint: new UDim2(0.6, -14, 0, 14),
						zIndex: 613,
					}),
					h(
						"frame",
						{
							Size: new UDim2(0.6, -20, 0, 3),
							Position: UDim2.fromOffset(10, 43),
							BackgroundColor3: Palette.lineSoft,
							BorderSizePixel: 0,
							ZIndex: 613,
						},
						h("uicorner", { CornerRadius: new UDim(1, 0) }),
						h(
							"frame",
							{ Size: new UDim2(friendProgress, 0, 1, 0), BackgroundColor3: Palette.mint, BorderSizePixel: 0 },
							h("uicorner", { CornerRadius: new UDim(1, 0) }),
						),
					),
					h(
						"frame",
						{
							Size: new UDim2(0.4, -8, 0, 36),
							Position: new UDim2(0.6, 0, 0.5, -18),
							BackgroundTransparency: 1,
							ZIndex: 614,
						},
						h(Button, {
							text: inviteBusy ? "OPENING" : "INVITE",
							icon: "Crew.19",
							onClick: invite,
							color: Palette.mint,
							textColor: Palette.ink,
							size: UDim2.fromScale(1, 1),
							reducedMotion: reducedMotion,
							disabled: inviteBusy,
							highlight: true,
							zIndex: 614,
						}),
					),
				),
				showSearch &&
					h(SearchField, {
						value: query,
						onChange: setQuery,
						accent: Palette.cyan,
						placeholder: "Find a player",
						position: UDim2.fromOffset(10, controlsTop),
						size: UDim2.fromOffset(colW, ctlH),
						reducedMotion: reducedMotion,
						zIndex: 616,
					}),
				h(
					"scrollingframe",
					{
						Name: "RosterFilters",
						Size: UDim2.fromOffset(colW, ctlH),
						Position: UDim2.fromOffset(10, controlsTop + (showSearch ? ctlH + 8 : 0)),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ScrollBarThickness: 0,
						ScrollingDirection: Enum.ScrollingDirection.X,
						AutomaticCanvasSize: Enum.AutomaticSize.X,
						CanvasSize: new UDim2(),
						ZIndex: 615,
					},
					chips,
				),
				h(
					"scrollingframe",
					{
						Name: "RosterList",
						Size: UDim2.fromOffset(listW, listH),
						Position: UDim2.fromOffset(listX, listY),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						CanvasSize: new UDim2(),
						AutomaticCanvasSize: Enum.AutomaticSize.Y,
						ScrollBarThickness: 3,
						ScrollBarImageColor3: Palette.cyan,
						ScrollBarImageTransparency: 0.3,
						ScrollingDirection: Enum.ScrollingDirection.Y,
						VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
						ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
						ClipsDescendants: true,
						ZIndex: 619,
					},
					listChildren,
				),
				reportTarget !== undefined &&
					h(ReportSheet, {
						target: reportTarget,
						dispatch: dispatch,
						reducedMotion: reducedMotion,
						width: math.min(innerW, 420),
						maxHeight: height - 20,
						onBlock: () => promptCore("PromptBlockPlayer", reportTarget),
						onClose: () => setReportTarget(undefined),
					}),
			),
		),
	);
}

function truthyNotify(notify: unknown) {
	return notify !== undefined && notify !== false;
}
