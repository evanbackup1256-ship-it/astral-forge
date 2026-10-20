import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { composePresence, useEntrance, useExitTransition, useFlipperSpring, useStagger, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, Panel, SearchField, Text, useGamepadAutofocus } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const Icon = (loadKit("ArtKit")("Icon") as { Icon: unknown }).Icon;

interface Member {
	UserId?: number;
	DisplayName: string;
	Name: string;
	Role: string;
	Note: string;
}
interface Category {
	Id: string;
	Accent: string;
	Icon: string;
	Label: string;
	Description: string;
	EmptyText: string;
	Members: Member[];
}
interface VisibleEntry {
	category: Category;
	members: Member[];
}
interface Tab {
	id: string;
	label: string;
	count: number;
	accent: string;
}
interface CreditsModelData {
	FetchNames?: boolean;
	Categories: Category[];
	AvatarShape: string;
	CardHoverLift?: boolean;
	EntranceStagger?: boolean;
	StaggerStep?: number;
	CardStyle: string;
	AvatarSize: number;
	ShowAvatars?: boolean;
	ShowRoles?: boolean;
	ShowUsernames?: boolean;
	ShowNotes?: boolean;
	ShowCategoryCounts?: boolean;
	Accent: string;
	DefaultCategory: string;
	CategoryTabs?: boolean;
	Tagline: string;
	DefaultEmptyText: string;
	Acknowledgements: string[];
	Footer: string;
	Eyebrow: string;
	Title: string;
	ShowVersion?: boolean;
}
interface CreditsModelModule {
	normalize(this: void, config: unknown): CreditsModelData;
	tabs(this: void, model: CreditsModelData): Tab[];
	showSearch(this: void, model: CreditsModelData): boolean;
	columns(this: void, model: CreditsModelData, width: number, gap: number): number;
	cardHeight(this: void, model: CreditsModelData): number;
	visible(this: void, model: CreditsModelData, tab: string, query: string): VisibleEntry[];
}

const SharedData = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;
const CreditsModel = SharedData("CreditsModel") as CreditsModelModule;
const MODEL = CreditsModel.normalize(SharedData("CreditsConfig"));

const GRID_GAP = 10;
const SECTION_GAP = 18;
const SECTION_HEADER_H = 46;
const EMPTY_ROW_H = 40;
const TAB_H = 34;
const MAX_STAGGER_INDEX = 14;

function tone(key: string, fallback: Color3): Color3 {
	const color = (Palette as unknown as Record<string, unknown>)[key];
	if (typeIs(color, "Color3")) {
		return color;
	}
	return fallback;
}

const liveNames: Record<number, { display?: unknown; username?: unknown } | undefined> = {};
let liveNamesRequested = false;
function useLiveNames() {
	const [version, setVersion] = React.useState(0);
	React.useEffect(() => {
		if (!MODEL.FetchNames || liveNamesRequested) {
			return undefined;
		}
		liveNamesRequested = true;
		const ids: number[] = [];
		const seen: Record<number, boolean> = {};
		for (const category of MODEL.Categories) {
			for (const member of category.Members) {
				if (member.UserId !== undefined && !seen[member.UserId]) {
					seen[member.UserId] = true;
					ids.push(member.UserId);
				}
			}
		}
		if (ids.size() === 0) {
			return undefined;
		}
		let alive = true;
		task.spawn(() => {
			const [ok, infos] = pcall(() => game.GetService("UserService").GetUserInfosByUserIdsAsync(ids) as unknown);
			if (!ok || !typeIs(infos, "table")) {
				return;
			}
			for (const [, info] of pairs(infos as Record<string, unknown>)) {
				if (typeIs(info, "table")) {
					const record = info as { Id?: number; DisplayName?: unknown; Username?: unknown };
					if (record.Id !== undefined) {
						liveNames[record.Id] = { display: record.DisplayName, username: record.Username };
					}
				}
			}
			if (alive) {
				setVersion((current) => current + 1);
			}
		});
		return () => {
			alive = false;
		};
	}, []);
	return version;
}

interface AvatarProps {
	member: Member;
	size: number;
	accent: Color3;
	lift?: React.Binding<number>;
	position: UDim2;
	anchor: Vector2;
}

function Avatar(param: AvatarProps) {
	const member = param.member;
	const size = param.size;
	const accent = param.accent;
	const lift = param.lift;
	const radius = MODEL.AvatarShape === "Circle" ? new UDim(1, 0) : new UDim(0, math.floor(size * 0.22));
	const initial = string.upper((string.match(member.DisplayName, utf8.charpattern)[0] as string | undefined) ?? "?");
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(size, size),
			Position: param.position,
			AnchorPoint: param.anchor,
			BackgroundColor3: darken(accent, 0.6),
			BorderSizePixel: 0,
			ZIndex: 325,
		},
		(lift !== undefined && h("uiscale", { Scale: lift.map((v) => 1 + v * 0.08) })) || undefined,
		h("uicorner", { CornerRadius: radius }),
		h("uistroke", {
			Color: lift !== undefined ? lift.map((v) => accent.Lerp(lighten(accent, 0.35), v)) : accent,
			Thickness: lift !== undefined ? lift.map((v) => 1.5 + v * 0.8) : 1.5,
			Transparency: lift !== undefined ? lift.map((v) => 0.35 - v * 0.25) : 0.35,
		}),
		h("textlabel", {
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			Text: initial,
			TextColor3: lighten(Palette.cream, 0.12),
			TextSize: math.floor(size * 0.46),
			FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			ZIndex: 326,
		}),
		(member.UserId !== undefined &&
			h(
				"imagelabel",
				{
					Size: new UDim2(1, -4, 1, -4),
					Position: UDim2.fromOffset(2, 2),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					Image: `rbxthumb://type=AvatarHeadShot&id=${member.UserId}&w=150&h=150`,
					ScaleType: Enum.ScaleType.Crop,
					ZIndex: 327,
				},
				h("uicorner", { CornerRadius: radius }),
			)) ||
			undefined,
	);
}

function memberKey(category: Category, member: Member): string {
	return category.Id + ":" + member.Name;
}

interface Spot {
	key: string;
	member: Member;
	category: Category;
}

function MemberCard(param: {
	member: Member;
	category: Category;
	accent: Color3;
	index: number;
	reducedMotion?: boolean;
	spotted: boolean;
	onSpot: (spot: Spot) => void;
}) {
	const member = param.member;
	const accent = param.accent;
	const reducedMotion = param.reducedMotion;
	const live = member.UserId !== undefined ? liveNames[member.UserId] : undefined;
	const displayName =
		live !== undefined && typeIs(live.display, "string") && live.display !== "" ? live.display : member.DisplayName;
	const username = live !== undefined && typeIs(live.username, "string") ? live.username : member.Name;
	const [hovered, setHovered] = React.useState(false);
	const lift = useFlipperSpring(hovered && MODEL.CardHoverLift ? 1 : 0, reducedMotion, 620, 40);
	// the card in the spotlight keeps an accent ring; one spring, so hover and spotlight never fight
	const ring = useFlipperSpring(param.spotted ? 1 : 0, reducedMotion, 560, 38);
	const spot = () => param.onSpot({ key: memberKey(param.category, member), member, category: param.category });
	const arrive = useStagger(math.min(param.index, MAX_STAGGER_INDEX), reducedMotion || !MODEL.EntranceStagger, MODEL.StaggerStep);
	const compact = MODEL.CardStyle === "Compact";
	const avatarSize = compact ? math.min(MODEL.AvatarSize, 48) : MODEL.AvatarSize;
	const textX = MODEL.ShowAvatars ? avatarSize + 24 : 14;
	const lines: Record<string, unknown> = {};
	let y = compact ? 0 : 12;
	const line = (key: string, value: string, size: number, color: Color3, weight: Enum.FontWeight, height: number, wrap: boolean) => {
		lines[key] = h(Text, {
			value: value,
			size: size,
			color: color,
			weight: weight,
			wrap: wrap,
			fit: !wrap,
			minSize: wrap ? undefined : math.max(9, size - 3),
			position: UDim2.fromOffset(textX, y),
			sizeConstraint: new UDim2(1, -(textX + 12), 0, height),
			zIndex: 326,
		});
		y += height;
	};
	if (compact) {
		lines.name = h(Text, {
			value: displayName,
			size: 14,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 10,
			position: new UDim2(0, textX, 0.5, -9),
			sizeConstraint: new UDim2(0.55, -textX, 0, 18),
			zIndex: 326,
		});
		if (MODEL.ShowRoles && member.Role !== "") {
			lines.role = h(Text, {
				value: string.upper(member.Role),
				size: 11,
				color: accent,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Right,
				fit: true,
				minSize: 9,
				position: new UDim2(0.55, 0, 0.5, -8),
				sizeConstraint: new UDim2(0.45, -12, 0, 16),
				zIndex: 326,
			});
		}
	} else {
		line("name", displayName, 15, Palette.cream, Enum.FontWeight.Heavy, 22, false);
		if (MODEL.ShowUsernames && member.UserId !== undefined && username !== displayName) {
			line("username", "@" + username, 11, Palette.muted, Enum.FontWeight.Bold, 16, false);
		}
		if (MODEL.ShowRoles && member.Role !== "") {
			line("role", string.upper(member.Role), 11, accent, Enum.FontWeight.Heavy, 18, false);
		}
		if (MODEL.ShowNotes && member.Note !== "") {
			line("note", member.Note, 12, Palette.creamSoft, Enum.FontWeight.Medium, 34, true);
		}
	}
	return h(
		"frame",
		{ Size: UDim2.fromScale(1, 1), LayoutOrder: param.index, BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 323 },
		h(
			"textbutton",
			{
				Size: UDim2.fromScale(1, 1),
				Text: "",
				AutoButtonColor: false,
				Selectable: true,
				Position: React.joinBindings([lift, arrive]).map((values) =>
					UDim2.fromOffset(0, math.round(-values[0] * 6 + (1 - math.clamp(values[1], 0, 1)) * 14)),
				),
				Rotation: lift.map((v) => v * (param.index % 2 === 0 ? 1.4 : -1.4)),
				BackgroundColor3: Palette.panel,
				BorderSizePixel: 0,
				ZIndex: 324,
				Active: true,
				Event: {
					MouseEnter: () => {
						Audio.play("hover");
						setHovered(true);
						spot();
					},
					MouseLeave: () => setHovered(false),
					SelectionGained: () => {
						setHovered(true);
						spot();
					},
					SelectionLost: () => setHovered(false),
					Activated: () => {
						Audio.play("tabSwitch");
						spot();
					},
				},
			},
			h("uiscale", {
				Scale: React.joinBindings([arrive, lift]).map((values) => {
					const arr = 0.94 + math.clamp(values[0], 0, 1) * 0.06;
					const lft = values[1] * 0.03;
					return arr + lft;
				}),
			}),
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uigradient", { Color: new ColorSequence(Palette.panelRaised, Palette.panel), Rotation: 90 }),
			h("uistroke", {
				Color: React.joinBindings([lift, ring]).map((values) => Palette.panelRaised.Lerp(lighten(accent, 0.4), math.max(values[0], values[1]))),
				Thickness: React.joinBindings([lift, ring]).map((values) => 1 + math.max(values[0], values[1] * 1.2) * 0.75),
				Transparency: React.joinBindings([lift, ring]).map((values) => 0.75 - math.clamp(math.max(values[0], values[1]), 0, 1) * 0.65),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 3),
					Position: UDim2.fromOffset(0, 0),
					BackgroundColor3: accent,
					BackgroundTransparency: compact ? 0.55 : 0.25,
					BorderSizePixel: 0,
					ZIndex: 325,
				},
				h("uicorner", { CornerRadius: new UDim(0, 6) }),
			),
			MODEL.ShowAvatars &&
				h(Avatar, {
					member: member,
					size: avatarSize,
					accent: accent,
					lift: lift,
					position: compact ? new UDim2(0, 10, 0.5, 0) : UDim2.fromOffset(12, 12),
					anchor: compact ? new Vector2(0, 0.5) : Vector2.zero,
				}),
			lines,
		),
	);
}

interface CategorySectionProps {
	entry: VisibleEntry;
	columns: number;
	cardH: number;
	width: number;
	height: number;
	firstIndex: number;
	layoutOrder: number;
	reducedMotion?: boolean;
	spotKey: string | undefined;
	onSpot: (spot: Spot) => void;
}

function CategorySection(param: CategorySectionProps) {
	const entry = param.entry;
	const category = entry.category;
	const members = entry.members;
	const accent = tone(category.Accent, Palette.violet);
	const columns = param.columns;
	const cardH = param.cardH;
	const width = param.width;
	const cellW = math.floor((width - GRID_GAP * (columns - 1)) / columns);
	const rows = math.ceil(members.size() / columns);
	const cards: Record<string, unknown> = {};
	cards.layout = h("uigridlayout", {
		CellSize: UDim2.fromOffset(cellW, cardH),
		CellPadding: UDim2.fromOffset(GRID_GAP, GRID_GAP),
		SortOrder: Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells: columns,
	});
	for (const [index, member] of ipairs(members)) {
		cards[category.Id + ":" + member.Name + ":" + index] = h(MemberCard, {
			member: member,
			category: category,
			accent: accent,
			index: param.firstIndex + index - 1,
			reducedMotion: param.reducedMotion,
			spotted: param.spotKey === memberKey(category, member),
			onSpot: param.onSpot,
		});
	}
	const count = MODEL.ShowCategoryCounts && members.size() > 0 ? ` · ${members.size()}` : "";
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, param.height),
			LayoutOrder: param.layoutOrder,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 322,
		},
		h(
			"frame",
			{ Size: new UDim2(1, 0, 0, SECTION_HEADER_H - 8), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 323 },
			h(
				"frame",
				{
					Size: new UDim2(0, 4, 1, -6),
					Position: UDim2.fromOffset(0, 3),
					BackgroundColor3: accent,
					BorderSizePixel: 0,
					ZIndex: 323,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(30, 30),
					Position: new UDim2(0, 12, 0.5, 0),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundColor3: darken(accent, 0.62),
					BorderSizePixel: 0,
					ZIndex: 323,
				},
				h("uicorner", { CornerRadius: new UDim(0, 10) }),
				h(Icon, { kind: category.Icon, color: Palette.cream, accent: lighten(accent, 0.2), size: 30 }),
			),
			h(Text, {
				value: string.upper(category.Label) + count,
				size: 14,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 10,
				position: UDim2.fromOffset(52, category.Description !== "" ? 1 : 9),
				sizeConstraint: new UDim2(1, -60, 0, 20),
				zIndex: 323,
			}),
			category.Description !== "" &&
				h(Text, {
					value: category.Description,
					size: 11,
					color: Palette.muted,
					weight: Enum.FontWeight.Medium,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(52, 21),
					sizeConstraint: new UDim2(1, -60, 0, 16),
					zIndex: 323,
				}),
		),
		members.size() === 0
			? h(
					"frame",
					{
						Size: new UDim2(1, 0, 0, EMPTY_ROW_H),
						Position: UDim2.fromOffset(0, SECTION_HEADER_H),
						BackgroundColor3: Palette.panel,
						BackgroundTransparency: 0.4,
						BorderSizePixel: 0,
						ZIndex: 323,
					},
					h("uicorner", { CornerRadius: new UDim(0, 10) }),
					h("uistroke", { Color: Palette.lineSoft, Thickness: 1, Transparency: 0.6 }),
					h(Text, {
						value: category.EmptyText,
						size: 12,
						color: Palette.muted,
						weight: Enum.FontWeight.Medium,
						align: Enum.TextXAlignment.Center,
						fit: true,
						minSize: 9,
						position: UDim2.fromOffset(10, 0),
						sizeConstraint: new UDim2(1, -20, 1, 0),
						zIndex: 324,
					}),
				)
			: h(
					"frame",
					{
						Size: new UDim2(1, 0, 0, rows * (cardH + GRID_GAP) - GRID_GAP),
						Position: UDim2.fromOffset(0, SECTION_HEADER_H),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 323,
					},
					cards,
				),
	);
}

function TabChip(param: { tab: Tab; active: boolean; order: number; onPick: (id: string) => void; reducedMotion?: boolean }) {
	const tab = param.tab;
	const active = param.active;
	const accent = tone(tab.accent, tone(MODEL.Accent, Palette.violet));
	const [hovered, setHovered] = React.useState(false);
	const selected = useFlipperSpring(active ? 1 : hovered ? 0.35 : 0, param.reducedMotion, 700, 42);
	const label = MODEL.ShowCategoryCounts ? `${tab.label}  ${tab.count}` : tab.label;
	const width = math.max(64, label.size() * 8 + 28);
	return h(
		"textbutton",
		{
			Size: UDim2.fromOffset(width, TAB_H),
			LayoutOrder: param.order,
			BackgroundColor3: selected.map((amount) => Palette.panel.Lerp(darken(accent, 0.5), math.clamp(amount, 0, 1))),
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			ZIndex: 324,
			Event: {
				Activated: () => param.onPick(tab.id),
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
			},
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h("uistroke", {
			Color: accent,
			Thickness: 1,
			Transparency: selected.map((amount) => 0.7 - math.clamp(amount, 0, 1) * 0.5),
		}),
		h(Text, {
			value: string.upper(label),
			size: 11,
			color: active ? Palette.cream : Palette.creamSoft,
			weight: Enum.FontWeight.Heavy,
			align: Enum.TextXAlignment.Center,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(8, 0),
			sizeConstraint: new UDim2(1, -16, 1, 0),
			zIndex: 325,
		}),
	);
}

// wide layouts: the sections as a rail down the left side, one row per tab
function RailItem(param: { tab: Tab; active: boolean; order: number; onPick: (id: string) => void; reducedMotion?: boolean }) {
	const tab = param.tab;
	const accent = tone(tab.accent, tone(MODEL.Accent, Palette.violet));
	const [hovered, setHovered] = React.useState(false);
	const lit = useFlipperSpring(param.active ? 1 : hovered ? 0.35 : 0, param.reducedMotion, 700, 42);
	return h(
		"textbutton",
		{
			Size: new UDim2(1, 0, 0, TapTarget),
			LayoutOrder: param.order,
			BackgroundColor3: darken(accent, 0.55),
			BackgroundTransparency: lit.map((a) => 1 - math.clamp(a, 0, 1) * 0.85),
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			ZIndex: 324,
			Event: {
				Activated: () => param.onPick(tab.id),
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
			},
		},
		h("uicorner", { CornerRadius: new UDim(0, 10) }),
		h(
			"frame",
			{
				Size: lit.map((a) => new UDim2(0, 3, math.clamp(a, 0, 1) * 0.6, 0)),
				Position: new UDim2(0, 2, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: accent,
				BorderSizePixel: 0,
				ZIndex: 325,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		),
		h(Text, {
			value: tab.label,
			size: 13,
			color: param.active ? Palette.cream : Palette.creamSoft,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 10,
			position: new UDim2(0, 14, 0.5, -9),
			sizeConstraint: new UDim2(1, -54, 0, 18),
			zIndex: 325,
		}),
		MODEL.ShowCategoryCounts &&
			h(Text, {
				value: tostring(tab.count),
				size: 12,
				color: accent,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Right,
				fit: false,
				position: new UDim2(1, -40, 0.5, -8),
				sizeConstraint: UDim2.fromOffset(30, 16),
				zIndex: 325,
			}),
	);
}

// a short burst clock: 0 -> 1 over `seconds` each time `token` changes; idle otherwise
function useBurst(token: number, seconds: number, off: boolean): React.Binding<number> {
	const [amount, setAmount] = React.useBinding(1);
	React.useEffect(() => {
		if (token === 0 || off) {
			setAmount(1);
			return undefined;
		}
		const started = os.clock();
		setAmount(0);
		const connection = game.GetService("RunService").RenderStepped.Connect(() => {
			const t = math.clamp((os.clock() - started) / seconds, 0, 1);
			setAmount(t);
			if (t >= 1) {
				connection.Disconnect();
			}
		});
		return () => connection.Disconnect();
	}, [token]);
	return amount;
}

// a new face slides in: keyed on who it is, so each person gets one fresh entrance
function SpotSlide(param: { reducedMotion?: boolean; children?: React.ReactNode }) {
	const swap = useStagger(0, param.reducedMotion, 0, 0.16);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			Position: swap.map((a) => UDim2.fromOffset(math.round((1 - math.clamp(a, 0, 1)) * 10), 0)),
			BackgroundTransparency: 1,
			ZIndex: 324,
		},
		param.children,
	);
}

const SPARKS = 10;
const cheers: Record<string, number> = {};

// the person you're looking at, big: avatar, name, role, their note, and a cheer button
function Spotlight(param: { spot: Spot | undefined; compact: boolean; reducedMotion?: boolean; size: UDim2; position: UDim2 }) {
	const spot = param.spot;
	const [, bump] = React.useState(0);
	const [token, setToken] = React.useState(0);
	const burst = useBurst(token, 0.7, param.reducedMotion === true);
	if (spot === undefined) {
		return undefined;
	}
	const member = spot.member;
	const accent = tone(spot.category.Accent, Palette.violet);
	const live = member.UserId !== undefined ? liveNames[member.UserId] : undefined;
	const displayName = live !== undefined && typeIs(live.display, "string") && live.display !== "" ? live.display : member.DisplayName;
	const username = live !== undefined && typeIs(live.username, "string") ? live.username : member.Name;
	const avatar = param.compact ? 52 : 76;
	const textX = avatar + 18;
	const count = cheers[spot.key] ?? 0;
	const cheer = () => {
		cheers[spot.key] = count + 1;
		Audio.play("confirm");
		setToken((n) => n + 1);
		bump((n) => n + 1);
	};
	const sparks: Record<string, unknown> = {};
	if (param.reducedMotion !== true) {
		for (let i = 0; i < SPARKS; i++) {
			const angle = (i / SPARKS) * math.pi * 2 + (token % 2) * 0.3;
			const reach = avatar * (0.55 + (i % 3) * 0.12);
			const tint = i % 3 === 0 ? Palette.mango : i % 3 === 1 ? accent : Palette.cream;
			sparks["s" + i] = h(
				"frame",
				{
					Size: UDim2.fromOffset(6, 6),
					AnchorPoint: new Vector2(0.5, 0.5),
					Position: burst.map((t) => {
						const out = 1 - (1 - t) * (1 - t);
						return new UDim2(0.5, math.cos(angle) * reach * out, 0.5, math.sin(angle) * reach * out - t * 10);
					}),
					BackgroundColor3: tint,
					BackgroundTransparency: burst.map((t) => (t >= 1 ? 1 : t * t)),
					Rotation: burst.map((t) => t * 160 + i * 20),
					BorderSizePixel: 0,
					ZIndex: 330,
				},
				h("uicorner", { CornerRadius: new UDim(0, 2) }),
			);
		}
	}
	return h(
		"frame",
		{
			Size: param.size,
			Position: param.position,
			BackgroundColor3: darken(accent, 0.78),
			BorderSizePixel: 0,
			ClipsDescendants: false,
			ZIndex: 323,
		},
		h("uicorner", { CornerRadius: new UDim(0, 14) }),
		h("uistroke", { Color: accent, Transparency: 0.55, Thickness: 1 }),
		h("uigradient", { Color: new ColorSequence(Palette.panelRaised, darken(accent, 0.7)), Rotation: 0 }),
		h(
			SpotSlide,
			{ key: spot.key, reducedMotion: param.reducedMotion },
			h(
				"frame",
				{
					Size: UDim2.fromOffset(avatar, avatar),
					Position: new UDim2(0, 12, 0.5, 0),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundTransparency: 1,
					Rotation: burst.map((t) => (t >= 1 ? 0 : math.sin(t * math.pi * 3) * 8 * (1 - t))),
					ZIndex: 325,
				},
				h(Avatar, { member: member, size: avatar, accent: accent, position: UDim2.fromScale(0, 0), anchor: Vector2.zero }),
				sparks,
			),
			h(Text, {
				value: string.upper(member.Role !== "" ? member.Role : spot.category.Label),
				size: 11,
				color: accent,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(textX, param.compact ? 8 : 14),
				sizeConstraint: new UDim2(1, -(textX + (param.compact ? 12 : 150)), 0, 14),
				zIndex: 325,
			}),
			h(Text, {
				value: displayName,
				size: param.compact ? 17 : 22,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 12,
				position: UDim2.fromOffset(textX, param.compact ? 22 : 30),
				sizeConstraint: new UDim2(1, -(textX + (param.compact ? 12 : 150)), 0, param.compact ? 22 : 28),
				zIndex: 325,
			}),
			member.UserId !== undefined &&
				username !== displayName &&
				h(Text, {
					value: "@" + username,
					size: 11,
					color: Palette.muted,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(textX, param.compact ? 44 : 58),
					sizeConstraint: new UDim2(1, -(textX + (param.compact ? 12 : 150)), 0, 14),
					zIndex: 325,
				}),
			!param.compact &&
				member.Note !== "" &&
				h(Text, {
					value: member.Note,
					size: 12,
					color: Palette.creamSoft,
					wrap: true,
					fit: true,
					minSize: 11,
					position: UDim2.fromOffset(textX, 76),
					sizeConstraint: new UDim2(1, -(textX + 150), 0, 34),
					zIndex: 325,
				}),
			h(Button, {
				text: count > 0 ? `CHEER ×${count}` : "CHEER",
				icon: "Wave.3",
				onClick: cheer,
				color: accent,
				textColor: Palette.ink,
				size: UDim2.fromOffset(param.compact ? 104 : 124, param.compact ? 36 : 40),
				position: param.compact ? new UDim2(1, -114, 1, -40) : new UDim2(1, -136, 0.5, -20),
				tooltip: { title: "Cheer", body: "Just for fun. Nobody gets pinged." },
				reducedMotion: param.reducedMotion,
				zIndex: 326,
			}),
		),
	);
}

export function CreditsOverlay(param: { version?: string; reducedMotion?: boolean; onClose: () => void }) {
	const version = param.version;
	const onClose = param.onClose;
	const softMotion = param.reducedMotion;
	const enter = useEntrance(softMotion);
	const [exit, exiting, beginExit] = useExitTransition(softMotion);
	const reveal = composePresence(enter, exit);
	const [tab, setTab] = React.useState(MODEL.DefaultCategory);
	const [query, setQuery] = React.useState("");
	useLiveNames();
	const requestClose = React.useCallback(() => {
		if (exiting) {
			return undefined;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, exiting, onClose]);
	const pickTab = (id: string) => {
		if (id === tab) {
			return undefined;
		}
		Audio.play("tabSwitch");
		setTab(id);
	};
	const [spot, setSpot] = React.useState<Spot | undefined>(undefined);

	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const pad = stack ? 14 : 22;
	const safeSide = math.max(8, viewport.sideInset, chrome.sideSafe);
	const safeTop = math.max(8, viewport.topInset);
	const safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe);
	const width = math.min(940, math.max(260, viewport.width - safeSide * 2 - 12));
	const height = math.min(680, math.max(260, viewport.height - safeTop - safeBottom - 12));
	const centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2);
	const closeSize = math.max(TapTarget - 4, 44);
	const innerW = width - pad * 2;

	const tabs = CreditsModel.tabs(MODEL);
	const showTabs = MODEL.CategoryTabs && tabs.size() > 2;
	const showSearch = CreditsModel.showSearch(MODEL);
	// wide: sections as a rail on the left, spotlight + cards on the right.
	// narrow: tab chips and search on top, a compact spotlight, then the cards.
	const rail = showTabs && !stack && innerW >= 720;
	const railW = rail ? 196 : 0;
	const mainX = rail ? railW + 16 : 0;
	const mainW = innerW - mainX;
	const searchBeside = !rail && showSearch && showTabs && innerW >= 620;
	const headerH = MODEL.Tagline !== "" ? 72 : 58;
	const controlsH = rail ? 0 : (showTabs || showSearch ? TAB_H + 12 : 0) + (showSearch && showTabs && !searchBeside ? TAB_H + 8 : 0);
	const compactSpot = stack || mainW < 520;
	const spotH = compactSpot ? 100 : 124;
	const spotTop = headerH + controlsH;
	const bodyTop = spotTop + spotH + 12;
	const bodyH = math.max(80, height - pad * 2 - bodyTop);

	const scrollBar = 4;
	const contentW = mainW - scrollBar - 8;
	const columns = CreditsModel.columns(MODEL, contentW, GRID_GAP);
	const cardH = CreditsModel.cardHeight(MODEL);
	const visible = CreditsModel.visible(MODEL, tab, query);

	// nobody picked yet (or they're filtered away): spotlight the first person on screen
	let shownSpot = spot;
	if (shownSpot !== undefined) {
		let still = false;
		for (const entry of visible) {
			if (entry.category.Id === shownSpot.category.Id && entry.members.includes(shownSpot.member)) {
				still = true;
			}
		}
		if (!still) {
			shownSpot = undefined;
		}
	}
	if (shownSpot === undefined) {
		for (const entry of visible) {
			const first = entry.members[0];
			if (first !== undefined) {
				shownSpot = { key: memberKey(entry.category, first), member: first, category: entry.category };
				break;
			}
		}
	}
	// LB / RB step through the sections
	const tabRef = React.useRef(tab);
	tabRef.current = tab;
	React.useEffect(() => {
		if (!showTabs) {
			return undefined;
		}
		const connection = UserInputService.InputBegan.Connect((input) => {
			const step = input.KeyCode === Enum.KeyCode.ButtonR1 ? 1 : input.KeyCode === Enum.KeyCode.ButtonL1 ? -1 : 0;
			if (step === 0) {
				return;
			}
			let at = 0;
			for (const [i, entry] of ipairs(tabs)) {
				if (entry.id === tabRef.current) {
					at = i;
				}
			}
			const target = tabs[math.clamp(at + step, 1, tabs.size()) - 1];
			if (target !== undefined && target.id !== tabRef.current) {
				Audio.play("tabSwitch");
				setTab(target.id);
			}
		});
		return () => connection.Disconnect();
	}, [showTabs, tabs.size()]);
	React.useEffect(() => {
		ClientLog.debug("nav", "credits opened");
		return () => ClientLog.debug("nav", "credits closed");
	}, []);
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.ButtonB || (input.KeyCode === Enum.KeyCode.Escape && !processed)) {
				requestClose();
			}
		});
		return () => connection.Disconnect();
	}, [requestClose]);
	const padFocus = useGamepadAutofocus(true);
	const overlayHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host: Instance | undefined = overlayHostRef.current ?? padFocus.current;
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
			pcall(task.cancel, job);
		};
	}, []);

	const sections: Record<string, unknown> = {};
	let cursor = 0;
	let cardIndex = 1;
	for (const [order, entry] of ipairs(visible)) {
		const rows = math.ceil(entry.members.size() / columns);
		const sectionH = SECTION_HEADER_H + (entry.members.size() === 0 ? EMPTY_ROW_H : rows * (cardH + GRID_GAP) - GRID_GAP);
		sections[entry.category.Id] = h(CategorySection, {
			entry: entry,
			columns: columns,
			cardH: cardH,
			width: contentW,
			height: sectionH,
			firstIndex: cardIndex,
			layoutOrder: order,
			reducedMotion: softMotion,
			spotKey: shownSpot?.key,
			onSpot: (picked: Spot) => setSpot(picked),
		});
		cardIndex += entry.members.size();
		cursor += sectionH + SECTION_GAP;
	}
	if (visible.size() === 0) {
		sections.none = h(Text, {
			value: query !== "" ? `Nobody matches "${query}".` : MODEL.DefaultEmptyText,
			size: 13,
			color: Palette.muted,
			align: Enum.TextXAlignment.Center,
			fit: false,
			sizeConstraint: new UDim2(1, 0, 0, 40),
			zIndex: 323,
		});
		cursor += 40 + SECTION_GAP;
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	if (MODEL.Footer !== "") {
		smallPrint.push(MODEL.Footer);
	}
	const footerH = smallPrint.size() * 16 + 8 + closeSize;
	sections.footer = h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, footerH),
			LayoutOrder: visible.size() + 1,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 322,
		},
		h(Text, {
			value: smallPrint.join("\n"),
			size: 10,
			color: Palette.muted,
			wrap: true,
			fit: true, minSize: 9,
			sizeConstraint: new UDim2(1, 0, 0, smallPrint.size() * 16),
			zIndex: 323,
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(0, closeSize),
				AutomaticSize: Enum.AutomaticSize.X,
				AnchorPoint: new Vector2(1, 1),
				Position: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				ZIndex: 323,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				HorizontalAlignment: Enum.HorizontalAlignment.Right,
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h(Button, {
				text: "CLOSE",
				icon: "Close.23",
				onClick: requestClose,
				color: tone(MODEL.Accent, Palette.violet),
				textColor: Palette.ink,
				size: UDim2.fromOffset(0, closeSize),
				hug: true,
				reducedMotion: softMotion,
				disabled: exiting,
				zIndex: 324,
			}),
		),
	);
	cursor += footerH;

	const tabChips: Record<string, unknown> = {};
	if (showTabs) {
		tabChips.layout = h("uilistlayout", {
			FillDirection: rail ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal,
			Padding: new UDim(0, rail ? 4 : 6),
			SortOrder: Enum.SortOrder.LayoutOrder,
			VerticalAlignment: rail ? Enum.VerticalAlignment.Top : Enum.VerticalAlignment.Center,
		});
		for (const [order, entry] of ipairs(tabs)) {
			tabChips[entry.id] = h(rail ? RailItem : TabChip, {
				tab: entry,
				active: entry.id === tab,
				order: order,
				onPick: pickTab,
				reducedMotion: softMotion,
			});
		}
	}
	const searchW = rail ? railW : searchBeside ? 220 : innerW;
	const tabsW = searchBeside ? innerW - searchW - 10 : innerW;
	const accent = tone(MODEL.Accent, Palette.violet);
	const showVersion = MODEL.ShowVersion && version !== undefined;

	return h(
		OverlayPresence,
		{ amount: reveal },
		h(
			"frame",
			{
				Name: "CreditsClaimActions",
				ref: overlayHostRef,
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: reveal.map((amount) => 1 - amount * 0.82),
				BorderSizePixel: 0,
				ClipsDescendants: false,
				Active: true,
				ZIndex: 318,
				Visible: reveal.map((amount) => amount > 0.003),
			},
			h("textbutton", {
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				Selectable: false,
				ZIndex: 319,
				Event: { Activated: requestClose },
			}),
			h(
				"frame",
				{
					ref: padFocus,
					Size: UDim2.fromOffset(width, height),
					Position: reveal.map((amount) => new UDim2(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					Active: true,
					ZIndex: 320,
				},
				h(
					Panel,
					{
						size: UDim2.fromScale(1, 1),
						accent: accent,
						background: Palette.panelRaised,
						padding: pad,
						zIndex: 321,
						clips: false,
						reveal: reveal,
						reducedMotion: softMotion,
						highlight: true,
					},
					h(Text, {
						value: MODEL.Eyebrow,
						size: 10,
						color: accent,
						weight: Enum.FontWeight.Heavy,
						fit: false,
						sizeConstraint: new UDim2(1, -(closeSize + 12), 0, 16),
						zIndex: 322,
					}),
					h(Text, {
						value: MODEL.Title,
						size: stack ? 22 : 28,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						fit: true,
						minSize: 16,
						position: UDim2.fromOffset(0, 16),
						sizeConstraint: new UDim2(1, -(closeSize + 12), 0, 32),
						zIndex: 322,
					}),
					h(Text, {
						value: [showVersion ? `VERSION ${version}` : "", MODEL.Tagline].join(
							showVersion && MODEL.Tagline !== "" ? "  ·  " : "",
						),
						size: 11,
						color: Palette.muted,
						weight: Enum.FontWeight.Bold,
						fit: true,
						minSize: 9,
						position: UDim2.fromOffset(0, 50),
						sizeConstraint: new UDim2(1, -(closeSize + 12), 0, 16),
						zIndex: 322,
					}),
					h(Button, {
						text: "",
						icon: "Close.24",
						onClick: requestClose,
						color: Palette.panelSoft,
						textColor: Palette.cream,
						outline: true,
						size: UDim2.fromOffset(closeSize, closeSize),
						position: new UDim2(1, -closeSize, 0, 0),
						reducedMotion: softMotion,
						disabled: exiting,
						zIndex: 323,
					}),
					showTabs &&
						h(
							"scrollingframe",
							{
								Size: rail
									? UDim2.fromOffset(railW, height - pad * 2 - headerH - (showSearch ? TAB_H + 10 : 0))
									: UDim2.fromOffset(tabsW, TAB_H + 4),
								Position: UDim2.fromOffset(0, headerH + (rail && showSearch ? TAB_H + 10 : 0)),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								ScrollBarThickness: 0,
								ScrollingDirection: rail ? Enum.ScrollingDirection.Y : Enum.ScrollingDirection.X,
								AutomaticCanvasSize: rail ? Enum.AutomaticSize.Y : Enum.AutomaticSize.X,
								CanvasSize: new UDim2(),
								ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
								ZIndex: 323,
							},
							tabChips,
						),
					showSearch &&
						h(SearchField, {
							value: query,
							onChange: setQuery,
							accent: accent,
							placeholder: "Search names or roles",
							position: UDim2.fromOffset(
								searchBeside ? innerW - searchW : 0,
								headerH + (showTabs && !searchBeside && !rail ? TAB_H + 8 : 0),
							),
							size: UDim2.fromOffset(searchW, TAB_H),
							reducedMotion: softMotion,
							zIndex: 324,
						}),
					h(Spotlight, {
						spot: shownSpot,
						compact: compactSpot,
						reducedMotion: softMotion,
						size: UDim2.fromOffset(mainW, spotH),
						position: UDim2.fromOffset(mainX, spotTop),
					}),
					h(
						"scrollingframe",
						{
							Size: UDim2.fromOffset(mainW, bodyH),
							Position: UDim2.fromOffset(mainX, bodyTop),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							CanvasSize: UDim2.fromOffset(0, cursor + 6),
							ScrollBarThickness: scrollBar,
							ScrollBarImageColor3: accent,
							ScrollBarImageTransparency: 0.3,
							ScrollingDirection: Enum.ScrollingDirection.Y,
							VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
							ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
							ClipsDescendants: true,
							ZIndex: 322,
						},
						h("uilistlayout", {
							FillDirection: Enum.FillDirection.Vertical,
							Padding: new UDim(0, SECTION_GAP),
							SortOrder: Enum.SortOrder.LayoutOrder,
						}),
						h("uipadding", { PaddingTop: new UDim(0, 6), PaddingRight: new UDim(0, 8) }),
						h(React.Fragment, { key: tab }, sections),
					),
				),
			),
		),
	);
}
