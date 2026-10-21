// Credits: everyone who made the game, read from SharedData#CreditsConfig through CreditsModel.
//
// Built from the shared surfaces (./surface) like Quick Find and tooltips: one base Surface, a
// section rail on wide screens (chips on narrow ones), an inset spotlight for the person you're
// looking at, and member rows that light up on the same spring. B or Esc closes, LB/RB change
// section, and a tap outside the panel closes too.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, SearchField, useGamepadAutofocus } from "./ui";
import {
	IconTile,
	KindChip,
	SectionLabel,
	Surface,
	SurfaceMetrics,
	SurfaceMotion,
	SurfaceRow,
	SurfaceText,
	useSurfaceEnter,
	useSurfaceSpring,
} from "./surface";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");
const TextService = game.GetService("TextService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const IconComponent = (loadKit("ArtKit")("Icon") as { Icon: unknown }).Icon as React.FC<{
	kind: string;
	color: Color3;
	accent: Color3;
	size: number;
	spin: boolean;
}>;

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
	EntranceStagger?: boolean;
	AvatarSize: number;
	ShowAvatars?: boolean;
	ShowRoles?: boolean;
	ShowUsernames?: boolean;
	ShowNotes?: boolean;
	ShowCategoryCounts?: boolean;
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

const GAP = SurfaceMetrics.gap;
const CHIP_ROW_H = TapTarget;
const RAIL_W = 196;

function tone(key: string, fallback: Color3): Color3 {
	const color = (Palette as unknown as Record<string, unknown>)[key];
	return typeIs(color, "Color3") ? color : fallback;
}

function memberKey(category: Category, member: Member): string {
	return category.Id + ":" + member.Name;
}

interface Spot {
	key: string;
	member: Member;
	category: Category;
}

// ── Live names ─────────────────────────────────────────────────────────────────

const liveNames: Record<number, { display?: unknown; username?: unknown } | undefined> = {};
let liveNamesRequested = false;

// display names and usernames change; ask Roblox once per session and redraw when they land
function useLiveNames() {
	const [, setVersion] = React.useState(0);
	React.useEffect(() => {
		if (!MODEL.FetchNames || liveNamesRequested) {
			return undefined;
		}
		liveNamesRequested = true;
		const ids: number[] = [];
		const seen = new Set<number>();
		for (const category of MODEL.Categories) {
			for (const member of category.Members) {
				if (member.UserId !== undefined && !seen.has(member.UserId)) {
					seen.add(member.UserId);
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
					const record = info as {
						Id?: number;
						DisplayName?: unknown;
						Username?: unknown;
					};
					if (record.Id !== undefined) {
						liveNames[record.Id] = {
							display: record.DisplayName,
							username: record.Username,
						};
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
}

function namesOf(member: Member): LuaTuple<[string, string]> {
	const live = member.UserId !== undefined ? liveNames[member.UserId] : undefined;
	const display = live !== undefined && typeIs(live.display, "string") && live.display !== "" ? live.display : member.DisplayName;
	const username = live !== undefined && typeIs(live.username, "string") && live.username !== "" ? live.username : member.Name;
	return $tuple(display, username);
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

// the member's initial, with their headshot loaded over it when they have a UserId
function Avatar(props: {
	member: Member;
	size: number;
	accent: Color3;
	position?: UDim2;
	anchor?: Vector2;
	pop?: React.Binding<number>;
	zIndex: number;
}) {
	const member = props.member;
	const size = props.size;
	const radius = MODEL.AvatarShape === "Circle" ? new UDim(1, 0) : new UDim(0, math.floor(size * 0.22));
	const initial = string.upper((string.match(member.DisplayName, utf8.charpattern)[0] as string | undefined) ?? "?");
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={props.position}
			AnchorPoint={props.anchor}
			BackgroundColor3={darken(props.accent, 0.6)}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			{props.pop !== undefined && <uiscale Scale={props.pop.map((v) => 1 + v * 0.06)} />}
			<uicorner CornerRadius={radius} />
			<uistroke Color={props.accent} Thickness={1.5} Transparency={0.4} />
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text={initial}
				TextColor3={Palette.cream}
				TextSize={math.floor(size * 0.46)}
				FontFace={Font.fromName("BuilderSans", Enum.FontWeight.Heavy)}
				ZIndex={props.zIndex + 1}
			/>
			{member.UserId !== undefined && (
				<imagelabel
					Size={new UDim2(1, -4, 1, -4)}
					Position={UDim2.fromOffset(2, 2)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Image={`rbxthumb://type=AvatarHeadShot&id=${member.UserId}&w=150&h=150`}
					ZIndex={props.zIndex + 2}
				>
					<uicorner CornerRadius={radius} />
				</imagelabel>
			)}
		</frame>
	);
}

// ── Member row ─────────────────────────────────────────────────────────────────

function MemberRow(props: {
	member: Member;
	category: Category;
	accent: Color3;
	height: number;
	order: number;
	delay: number;
	spotted: boolean;
	reducedMotion: boolean;
	onSpot: (spot: Spot) => void;
}) {
	const member = props.member;
	const [hovered, setHovered] = React.useState(false);
	// hover, gamepad selection and the spotlight share one spring, so they never fight
	const lit = useSurfaceSpring(props.spotted ? 1 : hovered ? 0.55 : 0, props.reducedMotion);
	const enter = useSurfaceEnter(props.reducedMotion, props.delay);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	const [display, username] = namesOf(member);
	const avatar = MODEL.ShowAvatars !== false ? math.min(MODEL.AvatarSize, props.height - 12) : 0;
	const textX = avatar > 0 ? 12 + avatar + 12 : 14;
	const spot = () =>
		props.onSpot({
			key: memberKey(props.category, member),
			member,
			category: props.category,
		});
	const second = [MODEL.ShowRoles !== false ? member.Role : "", MODEL.ShowUsernames !== false ? `@${username}` : ""]
		.filter((part) => part !== "")
		.join("  ·  ");
	const showNote = MODEL.ShowNotes !== false && member.Note !== "" && props.height >= 72;
	const top = showNote ? 10 : (props.height - (second !== "" ? 36 : 18)) / 2;
	return (
		<SurfaceRow
			height={props.height}
			order={props.order}
			accent={props.accent}
			lit={lit}
			enter={enter}
			selectable={true}
			zIndex={6}
			events={{
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
				SelectionGained: spot,
				Activated: () => {
					Audio.play("tick");
					spot();
				},
			}}
		>
			{avatar > 0 && (
				<Avatar
					member={member}
					size={avatar}
					accent={props.accent}
					position={new UDim2(0, 12, 0.5, 0)}
					anchor={new Vector2(0, 0.5)}
					zIndex={9}
				/>
			)}
			<SurfaceText
				text={display}
				type="title"
				size={new UDim2(1, -(textX + 10), 0, 18)}
				position={UDim2.fromOffset(textX, top)}
				transparency={fade}
				zIndex={9}
			/>
			{second !== "" && (
				<SurfaceText
					text={second}
					type="small"
					color={Palette.creamSoft}
					size={new UDim2(1, -(textX + 10), 0, 15)}
					position={UDim2.fromOffset(textX, top + 20)}
					transparency={fade}
					zIndex={9}
				/>
			)}
			{showNote && (
				<SurfaceText
					text={member.Note}
					type="small"
					color={Palette.muted}
					wrap={true}
					fit={true}
					size={new UDim2(1, -(textX + 10), 1, -(top + 40))}
					position={UDim2.fromOffset(textX, top + 38)}
					transparency={fade}
					zIndex={9}
				/>
			)}
		</SurfaceRow>
	);
}

// ── Spotlight ──────────────────────────────────────────────────────────────────

const cheers: Record<string, number> = {};

// the person you're looking at, big: avatar, name, role, their note, and a cheer button
function Spotlight(props: { spot: Spot; compact: boolean; reducedMotion: boolean }) {
	const spot = props.spot;
	const member = spot.member;
	const accent = tone(spot.category.Accent, Palette.violet);
	const [display, username] = namesOf(member);
	const [popping, setPopping] = React.useState(false);
	const pop = useSurfaceSpring(popping ? 1 : 0, props.reducedMotion);
	const [count, setCount] = React.useState(cheers[spot.key] ?? 0);
	const enter = useSurfaceEnter(props.reducedMotion, 0.001);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	const cheer = () => {
		const total = (cheers[spot.key] ?? 0) + 1;
		cheers[spot.key] = total;
		setCount(total);
		Audio.play("confirm");
		setPopping(true);
		task.delay(0.14, () => setPopping(false));
	};
	const avatar = props.compact ? 52 : 72;
	const textX = avatar + 16;
	const buttonW = props.compact ? 104 : 124;
	const lineW = new UDim(1, -(textX + (props.compact ? 0 : buttonW + 12)));
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={6}>
			<Avatar member={member} size={avatar} accent={accent} pop={pop} zIndex={7} />
			<SurfaceText
				text={string.upper(spot.category.Label)}
				type="label"
				color={accent}
				size={new UDim2(lineW, new UDim(0, 14))}
				position={UDim2.fromOffset(textX, 0)}
				transparency={fade}
				zIndex={7}
			/>
			<SurfaceText
				text={display}
				type="display"
				size={new UDim2(lineW, new UDim(0, 24))}
				position={UDim2.fromOffset(textX, 16)}
				transparency={fade}
				zIndex={7}
			/>
			<SurfaceText
				text={[MODEL.ShowRoles !== false ? member.Role : "", `@${username}`].filter((part) => part !== "").join("  ·  ")}
				type="small"
				color={Palette.creamSoft}
				size={new UDim2(lineW, new UDim(0, 16))}
				position={UDim2.fromOffset(textX, 42)}
				transparency={fade}
				zIndex={7}
			/>
			{!props.compact && member.Note !== "" && (
				<SurfaceText
					text={member.Note}
					type="body"
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					size={new UDim2(lineW, new UDim(1, -62))}
					position={UDim2.fromOffset(textX, 62)}
					transparency={fade}
					zIndex={7}
				/>
			)}
			<Button
				text={count > 0 ? `CHEER ×${count}` : "CHEER"}
				icon="Wave.3"
				onClick={cheer}
				color={accent}
				textColor={Palette.ink}
				size={UDim2.fromOffset(buttonW, TapTarget)}
				position={props.compact ? new UDim2(1, -buttonW, 1, -TapTarget) : new UDim2(1, -buttonW, 0.5, -TapTarget / 2)}
				tooltip={{ title: "Cheer", body: "Just for fun. Nobody gets pinged." }}
				reducedMotion={props.reducedMotion}
				zIndex={8}
			/>
		</frame>
	);
}

// ── Section pickers ────────────────────────────────────────────────────────────

function SectionPick(props: {
	tab: Tab;
	active: boolean;
	order: number;
	width?: UDim;
	reducedMotion: boolean;
	onPick: (id: string) => void;
}) {
	const accent = tone(props.tab.accent, Palette.mango);
	const [hovered, setHovered] = React.useState(false);
	const lit = useSurfaceSpring(props.active ? 1 : hovered ? 0.55 : 0, props.reducedMotion);
	return (
		<SurfaceRow
			width={props.width}
			order={props.order}
			accent={accent}
			lit={lit}
			selectable={true}
			zIndex={6}
			events={{
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
				Activated: () => props.onPick(props.tab.id),
			}}
		>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={8}>
				<uipadding PaddingLeft={new UDim(0, 14)} PaddingRight={new UDim(0, 10)} />
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					Padding={new UDim(0, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<SurfaceText
					text={props.tab.label}
					type="title"
					color={props.active ? Palette.cream : Palette.creamSoft}
					autoSize={true}
					order={1}
					zIndex={8}
				/>
				{MODEL.ShowCategoryCounts !== false && (
					<KindChip text={tostring(props.tab.count)} accent={props.active ? accent : undefined} order={2} zIndex={8} />
				)}
			</frame>
		</SurfaceRow>
	);
}

function chipWidth(tab: Tab): number {
	let width = tab.label.size() * 8;
	pcall(() => {
		width = TextService.GetTextSize(tab.label, 15, Enum.Font.BuilderSansBold, new Vector2(400, 20)).X;
	});
	return math.ceil(width) + 14 + 10 + (MODEL.ShowCategoryCounts !== false ? 8 + 30 : 0);
}

// ── Overlay ────────────────────────────────────────────────────────────────────

export function CreditsOverlay(props: { version?: string; reducedMotion?: boolean; onClose: () => void }) {
	const reduced = props.reducedMotion === true;
	const [reveal, exiting, beginExit] = usePresence(reduced);
	const [tab, setTab] = React.useState(MODEL.DefaultCategory);
	const [query, setQuery] = React.useState("");
	const [picked, setPicked] = React.useState<Spot | undefined>(undefined);
	useLiveNames();
	const onClose = props.onClose;
	const requestClose = React.useCallback(() => {
		if (exiting) {
			return;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, exiting, onClose]);
	const pickTab = (id: string) => {
		if (id !== tab) {
			Audio.play("tabSwitch");
			setTab(id);
		}
	};

	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const pad = stack ? 12 : SurfaceMetrics.pad + 4;
	const safeSide = math.max(8, viewport.sideInset, chrome.sideSafe);
	const safeTop = math.max(8, viewport.topInset);
	const safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe);
	const width = math.min(940, math.max(260, viewport.width - safeSide * 2 - 12));
	const height = math.min(680, math.max(260, viewport.height - safeTop - safeBottom - 12));
	const centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2);
	const innerW = width - pad * 2;

	const tabs = CreditsModel.tabs(MODEL);
	const showTabs = MODEL.CategoryTabs === true && tabs.size() > 2;
	const showSearch = CreditsModel.showSearch(MODEL);
	// wide: sections in a rail on the left; narrow: a row of section chips above everything
	const rail = showTabs && !stack && innerW >= 720;
	const mainX = rail ? RAIL_W + 16 : 0;
	const mainW = innerW - mainX;
	const headerH = MODEL.Tagline !== "" || (MODEL.ShowVersion === true && props.version !== undefined) ? 70 : 54;
	const chipsH = !rail && showTabs ? CHIP_ROW_H + GAP : 0;
	const searchH = !rail && showSearch ? TapTarget + GAP : 0;
	const compactSpot = stack || mainW < 520;
	const spotH = compactSpot ? 108 : 128;
	const spotTop = headerH + chipsH + searchH;
	const bodyTop = spotTop + spotH + GAP;
	const bodyH = math.max(80, height - pad * 2 - bodyTop);
	const contentW = mainW - 10;
	const columns = CreditsModel.columns(MODEL, contentW, GAP);
	const rowH = math.max(TapTarget, math.min(CreditsModel.cardHeight(MODEL), 96));
	const visible = CreditsModel.visible(MODEL, tab, query);

	// nobody picked yet (or they're filtered away): spotlight the first person on screen
	let spot = picked;
	if (spot !== undefined) {
		const current = spot;
		const still = visible.some((entry) => entry.category.Id === current.category.Id && entry.members.includes(current.member));
		if (!still) {
			spot = undefined;
		}
	}
	if (spot === undefined) {
		for (const entry of visible) {
			const first = entry.members[0];
			if (first !== undefined) {
				spot = {
					key: memberKey(entry.category, first),
					member: first,
					category: entry.category,
				};
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

	// gamepad: the overlay owns focus while open and starts on its first button
	const padFocus = useGamepadAutofocus(true);
	const hostRef = React.useRef<Frame>();
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host: Instance | undefined = hostRef.current ?? padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, []);

	// the list: a label per section, its members in a grid, then the small print
	const body: React.Element[] = [];
	let order = 0;
	let rowIndex = 0;
	const cellW = math.floor((contentW - GAP * (columns - 1)) / columns);
	for (const entry of visible) {
		const accent = tone(entry.category.Accent, Palette.violet);
		order += 1;
		body.push(
			<SectionLabel
				key={`l:${entry.category.Id}`}
				text={string.upper(entry.category.Label)}
				count={MODEL.ShowCategoryCounts !== false ? entry.members.size() : undefined}
				accent={accent}
				order={order}
				height={30}
				zIndex={6}
			/>,
		);
		order += 1;
		if (entry.members.size() === 0) {
			body.push(
				<SurfaceText
					key={`e:${entry.category.Id}`}
					text={entry.category.EmptyText !== "" ? entry.category.EmptyText : MODEL.DefaultEmptyText}
					type="body"
					color={Palette.muted}
					size={new UDim2(1, 0, 0, 36)}
					order={order}
					zIndex={6}
				/>,
			);
			continue;
		}
		const rows = math.ceil(entry.members.size() / columns);
		const cards: React.Element[] = [];
		for (const [i, member] of ipairs(entry.members)) {
			rowIndex += 1;
			const key = memberKey(entry.category, member);
			cards.push(
				<MemberRow
					key={`${tab}|${key}`}
					member={member}
					category={entry.category}
					accent={accent}
					height={rowH}
					order={i}
					delay={MODEL.EntranceStagger !== false ? math.min(rowIndex, SurfaceMotion.staggerRows) * SurfaceMotion.stagger : 0}
					spotted={spot !== undefined && spot.key === key}
					reducedMotion={reduced}
					onSpot={setPicked}
				/>,
			);
		}
		body.push(
			<frame
				key={`g:${entry.category.Id}`}
				Size={new UDim2(1, 0, 0, rows * rowH + (rows - 1) * GAP)}
				LayoutOrder={order}
				BackgroundTransparency={1}
				ZIndex={6}
			>
				<uigridlayout
					CellSize={UDim2.fromOffset(cellW, rowH)}
					CellPadding={UDim2.fromOffset(GAP, GAP)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{cards}
			</frame>,
		);
	}
	if (visible.size() === 0) {
		order += 1;
		body.push(
			<SurfaceText
				key="none"
				text={query !== "" ? `Nobody matches "${query}".` : MODEL.DefaultEmptyText}
				type="body"
				color={Palette.muted}
				align={Enum.TextXAlignment.Center}
				size={new UDim2(1, 0, 0, 40)}
				order={order}
				zIndex={6}
			/>,
		);
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	if (MODEL.Footer !== "") {
		smallPrint.push(MODEL.Footer);
	}
	if (smallPrint.size() > 0) {
		order += 1;
		body.push(
			<frame
				key="smallprint"
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				LayoutOrder={order}
				BackgroundTransparency={1}
				ZIndex={6}
			>
				<uipadding PaddingTop={new UDim(0, 12)} PaddingBottom={new UDim(0, 8)} />
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} />
				{smallPrint.map((line, i) => (
					<SurfaceText
						key={`p${i}`}
						text={line}
						type="small"
						color={Palette.muted}
						wrap={true}
						align={Enum.TextXAlignment.Center}
						size={UDim2.fromScale(1, 0)}
						autoHeight={true}
						order={i}
						zIndex={6}
					/>
				))}
			</frame>,
		);
	}

	const subline = [MODEL.ShowVersion === true && props.version !== undefined ? `VERSION ${props.version}` : "", MODEL.Tagline]
		.filter((part) => part !== "")
		.join("  ·  ");

	return (
		<OverlayPresence amount={reveal}>
			<frame key="CreditsClaimActions" ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={320}>
				{/* tap outside the panel closes */}
				<imagebutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={new Color3(0, 0, 0)}
					BackgroundTransparency={reveal.map((a) => 1 - 0.55 * a)}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Selectable={false}
					ZIndex={320}
					Event={{ Activated: requestClose }}
				/>
				<frame
					Size={UDim2.fromOffset(width, height)}
					Position={reveal.map((a) => UDim2.fromOffset(viewport.width / 2, centerY + revealOffset(a)))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Active={true}
					ZIndex={321}
				>
					<Surface appear={reveal} padding={pad} active={true} zIndex={321}>
						{/* header */}
						<SurfaceText
							text={string.upper(MODEL.Eyebrow)}
							type="label"
							color={Palette.mango}
							size={new UDim2(1, -56, 0, 14)}
							zIndex={322}
						/>
						<SurfaceText
							text={MODEL.Title}
							type="display"
							size={new UDim2(1, -56, 0, 26)}
							position={UDim2.fromOffset(0, 16)}
							zIndex={322}
						/>
						{subline !== "" && (
							<SurfaceText
								text={subline}
								type="small"
								color={Palette.creamSoft}
								size={new UDim2(1, -56, 0, 16)}
								position={UDim2.fromOffset(0, 46)}
								zIndex={322}
							/>
						)}
						<Button
							icon="Close.24"
							onClick={requestClose}
							size={UDim2.fromOffset(TapTarget, TapTarget)}
							position={new UDim2(1, -TapTarget, 0, 0)}
							outline={true}
							reducedMotion={reduced}
							zIndex={323}
						/>
						{/* sections: rail (wide) */}
						{rail && (
							<frame
								Size={new UDim2(0, RAIL_W, 1, -headerH)}
								Position={UDim2.fromOffset(0, headerH)}
								BackgroundTransparency={1}
								ZIndex={322}
							>
								<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, SurfaceMetrics.rowGap)} />
								{tabs.map((entry, i) => (
									<SectionPick key={entry.id} tab={entry} active={entry.id === tab} order={i} reducedMotion={reduced} onPick={pickTab} />
								))}
								{showSearch && (
									<frame
										key="search"
										Size={new UDim2(1, 0, 0, TapTarget + GAP)}
										LayoutOrder={tabs.size() + 1}
										BackgroundTransparency={1}
										ZIndex={322}
									>
										<SearchField
											value={query}
											onChange={setQuery}
											placeholder="Find someone"
											size={new UDim2(1, 0, 0, TapTarget)}
											position={UDim2.fromOffset(0, GAP)}
											reducedMotion={reduced}
											zIndex={323}
										/>
									</frame>
								)}
							</frame>
						)}
						{/* sections: chips (narrow) */}
						{!rail && showTabs && (
							<scrollingframe
								Size={new UDim2(1, 0, 0, CHIP_ROW_H)}
								Position={UDim2.fromOffset(0, headerH)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								CanvasSize={new UDim2()}
								AutomaticCanvasSize={Enum.AutomaticSize.X}
								ScrollingDirection={Enum.ScrollingDirection.X}
								ScrollBarThickness={0}
								ZIndex={322}
							>
								<uilistlayout
									FillDirection={Enum.FillDirection.Horizontal}
									SortOrder={Enum.SortOrder.LayoutOrder}
									Padding={new UDim(0, 6)}
								/>
								{tabs.map((entry, i) => (
									<SectionPick
										key={entry.id}
										tab={entry}
										active={entry.id === tab}
										order={i}
										width={new UDim(0, chipWidth(entry))}
										reducedMotion={reduced}
										onPick={pickTab}
									/>
								))}
							</scrollingframe>
						)}
						{!rail && showSearch && (
							<SearchField
								value={query}
								onChange={setQuery}
								placeholder="Find someone"
								size={new UDim2(1, 0, 0, TapTarget)}
								position={UDim2.fromOffset(0, headerH + chipsH)}
								reducedMotion={reduced}
								zIndex={323}
							/>
						)}
						{/* spotlight */}
						<Surface
							tone="inset"
							size={new UDim2(0, mainW, 0, spotH)}
							position={UDim2.fromOffset(mainX, spotTop)}
							padding={12}
							zIndex={322}
						>
							{spot !== undefined ? (
								<Spotlight key={spot.key} spot={spot} compact={compactSpot} reducedMotion={reduced} />
							) : (
								<IconTile size={44} accent={Palette.muted} position={UDim2.fromScale(0.5, 0.5)} anchor={new Vector2(0.5, 0.5)} zIndex={323}>
									<frame
										Size={UDim2.fromOffset(22, 22)}
										Position={UDim2.fromScale(0.5, 0.5)}
										AnchorPoint={new Vector2(0.5, 0.5)}
										BackgroundTransparency={1}
									>
										{React.createElement(IconComponent, {
											kind: "Search.9",
											color: Palette.muted,
											accent: Palette.muted,
											size: 22,
											spin: false,
										})}
									</frame>
								</IconTile>
							)}
						</Surface>
						{/* everyone */}
						<scrollingframe
							Size={UDim2.fromOffset(mainW, bodyH)}
							Position={UDim2.fromOffset(mainX, bodyTop)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							CanvasSize={new UDim2()}
							AutomaticCanvasSize={Enum.AutomaticSize.Y}
							ScrollingDirection={Enum.ScrollingDirection.Y}
							ScrollBarThickness={3}
							ScrollBarImageColor3={Palette.muted}
							ZIndex={322}
						>
							<frame Size={new UDim2(0, contentW, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} ZIndex={322}>
								<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} />
								{body}
							</frame>
						</scrollingframe>
					</Surface>
				</frame>
			</frame>
		</OverlayPresence>
	);
}
