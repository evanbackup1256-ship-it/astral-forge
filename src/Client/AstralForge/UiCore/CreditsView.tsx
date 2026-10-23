import { named } from "../lua";
// Credits: everyone who made the game, read from SharedData#CreditsConfig through CreditsModel.
//
// A clean, read-only roll. One Surface panel that sizes itself to its content (no empty card
// below a short list): a title block, then every section in order, each with its own accent rule
// and a grid of member cards whose column count comes from the layout engine (cards stretch to
// fill the row instead of leaving holes), then the acknowledgements. Nothing to tap but Close:
// B, Esc or a tap outside also close it. Motion is unchanged: the panel reveals on usePresence,
// cards rise on the shared surface stagger and their plates settle on the surface spring.
import { ModalSelectionScope } from "./overlayCore";
import { useFocusOrder } from "../CoreKit/focusOrder";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, useGamepadAutofocus } from "./ui";
import { Surface, SurfaceSectionLabel, SurfaceMetrics, SurfaceMotion, SurfaceRow, SurfaceText, useSurfaceEnter, useSurfaceSpring } from "./surface";
import { fitColumns, measureText, Space } from "./layoutEngine";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;
interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

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
	DefaultEmptyText: string;
	Acknowledgements: string[];
	Footer: string;
	Title: string;
	Tagline: string;
	ShowVersion?: boolean;
}
interface CreditsModelModule {
	normalize(this: void, config: unknown): CreditsModelData;
	cardHeight(this: void, model: CreditsModelData): number;
	visible(this: void, model: CreditsModelData, tab: string, query: string): VisibleEntry[];
}

const SharedData = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;
const CreditsModel = SharedData("CreditsModel") as CreditsModelModule;
const MODEL = CreditsModel.normalize(SharedData("CreditsConfig"));

const GAP = SurfaceMetrics.gap;
const LABEL_H = 38;
const DESC_H = 18;
const MIN_CARD_W = 248;
const MAX_CARD_W = 380;

function tone(key: string, fallback: Color3): Color3 {
	const color = (Palette as unknown as Record<string, unknown>)[key];
	return typeIs(color, "Color3") ? color : fallback;
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
			<uistroke Color={props.accent} Thickness={1} Transparency={0.7} />
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

// ── Member card ────────────────────────────────────────────────────────────────

// read-only: the plate settles in on the surface spring once the card has risen
function MemberCard(props: { member: Member; accent: Color3; height: number; order: number; delay: number; reducedMotion: boolean }) {
	const member = props.member;
	const [settled, setSettled] = React.useState(false);
	React.useEffect(() => {
		const job = task.delay(props.delay + SurfaceMotion.stagger * 2, () => setSettled(true));
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	const lit = useSurfaceSpring(settled ? 0.22 : 0, props.reducedMotion);
	const enter = useSurfaceEnter(props.reducedMotion, props.delay);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	const [display, username] = namesOf(member);
	const avatar = MODEL.ShowAvatars !== false ? math.min(MODEL.AvatarSize, props.height - Space.md * 2) : 0;
	const textX = avatar > 0 ? Space.md + avatar + Space.md : Space.lg;
	const second = [MODEL.ShowRoles !== false ? member.Role : "", MODEL.ShowUsernames !== false ? `@${username}` : ""]
		.filter((part) => part !== "")
		.join("  ·  ");
	const showNote = MODEL.ShowNotes !== false && member.Note !== "" && props.height >= 72;
	const blockH = 18 + (second !== "" ? 20 : 0) + (showNote ? 34 : 0);
	const top = math.max(Space.sm, math.floor((props.height - blockH) / 2));
	return (
		<SurfaceRow height={props.height} order={props.order} accent={props.accent} lit={lit} enter={enter} selectable={false} zIndex={6}>
			{avatar > 0 && (
				<Avatar member={member} size={avatar} accent={props.accent} position={new UDim2(0, Space.md, 0.5, 0)} anchor={new Vector2(0, 0.5)} zIndex={9} />
			)}
			<SurfaceText text={display} type="title" size={new UDim2(1, -(textX + Space.md), 0, 18)} position={UDim2.fromOffset(textX, top)} transparency={fade} zIndex={9} />
			{second !== "" && (
				<SurfaceText
					text={second}
					type="small"
					color={Palette.creamSoft}
					size={new UDim2(1, -(textX + Space.md), 0, 15)}
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
					size={new UDim2(1, -(textX + Space.md), 0, 32)}
					position={UDim2.fromOffset(textX, top + (second !== "" ? 40 : 22))}
					transparency={fade}
					zIndex={9}
				/>
			)}
		</SurfaceRow>
	);
}

// ── Overlay ────────────────────────────────────────────────────────────────────

export function CreditsOverlay(props: { version?: string; reducedMotion?: boolean; onClose: () => void }) {
	const reduced = props.reducedMotion === true;
	const [reveal, exiting, beginExit] = usePresence(reduced);
	useLiveNames();
	const onClose = props.onClose;
	const requestClose = React.useCallback(() => {
		if (exiting) {
			return;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, exiting, onClose]);

	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const pad = stack ? Space.md : SurfaceMetrics.pad + Space.xs;
	const safeSide = math.max(Space.sm, viewport.sideInset, chrome.sideSafe);
	const safeTop = math.max(Space.sm, viewport.topInset);
	const safeBottom = math.max(Space.sm, viewport.bottomInset, chrome.bottomSafe);
	const maxW = math.min(1040, viewport.width - safeSide * 2 - Space.md);
	const maxH = math.max(1, math.min(720, viewport.height - safeTop - safeBottom - Space.md));
	const centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2);

	const visible = CreditsModel.visible(MODEL, "All", "");
	let largest = 1;
	for (const entry of visible) largest = math.max(largest, entry.members.size());
	// width follows content: a small team gets a narrower panel instead of a sea of empty cards
	const widest = fitColumns(maxW - pad * 2 - Space.sm, largest, MIN_CARD_W, 3, GAP, MAX_CARD_W);
	const width = math.min(maxW, math.max(math.min(maxW, 420), widest.columns * MAX_CARD_W + (widest.columns - 1) * GAP + pad * 2 + Space.sm));
	const innerW = width - pad * 2;
	const contentW = innerW - Space.sm;
	const rowH = math.max(TapTarget, math.min(CreditsModel.cardHeight(MODEL), 96));

	const subline = [MODEL.ShowVersion === true && props.version !== undefined ? `Version ${props.version}` : "", MODEL.Tagline]
		.filter((part) => part !== "")
		.join("  ·  ");
	const headerH = subline !== "" ? 64 : 46;

	// body: section label, optional description, member grid; measured so the panel can hug it
	const body: React.Element[] = [];
	let order = 0;
	let rowIndex = 0;
	let contentH = 0;
	for (const entry of visible) {
		const accent = tone(entry.category.Accent, Palette.violet);
		order += 1;
		body.push(
			<SurfaceSectionLabel
				key={`l:${entry.category.Id}`}
				text={entry.category.Label}
				count={MODEL.ShowCategoryCounts !== false ? entry.members.size() : undefined}
				accent={accent}
				order={order}
				height={LABEL_H}
				zIndex={6}
			/>,
		);
		contentH += LABEL_H + Space.xs;
		if (entry.category.Description !== "") {
			order += 1;
			const lines = math.max(1, math.ceil(measureText(entry.category.Description, 14, Enum.Font.BuilderSans).X / math.max(1, contentW)));
			body.push(
				<SurfaceText
					key={`d:${entry.category.Id}`}
					text={entry.category.Description}
					type="small"
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={11}
					size={new UDim2(1, 0, 0, DESC_H * lines)}
					order={order}
					zIndex={6}
				/>,
			);
			contentH += DESC_H * lines + Space.xs;
		}
		order += 1;
		if (entry.members.size() === 0) {
			body.push(
				<SurfaceText
					key={`e:${entry.category.Id}`}
					text={entry.category.EmptyText !== "" ? entry.category.EmptyText : MODEL.DefaultEmptyText}
					type="body"
					color={Palette.muted}
					size={new UDim2(1, 0, 0, 32)}
					order={order}
					zIndex={6}
				/>,
			);
			contentH += 32 + Space.xs;
			continue;
		}
		const fit = fitColumns(contentW, entry.members.size(), MIN_CARD_W, 3, GAP, MAX_CARD_W);
		const gridH = fit.rows * rowH + (fit.rows - 1) * GAP;
		const cards: React.Element[] = [];
		for (const [i, member] of ipairs(entry.members)) {
			rowIndex += 1;
			cards.push(
				<MemberCard
					key={`${entry.category.Id}:${member.Name}`}
					member={member}
					accent={accent}
					height={rowH}
					order={i}
					delay={MODEL.EntranceStagger !== false ? math.min(rowIndex, SurfaceMotion.staggerRows) * SurfaceMotion.stagger : 0}
					reducedMotion={reduced}
				/>,
			);
		}
		body.push(
			<frame key={`g:${entry.category.Id}`} Size={new UDim2(1, 0, 0, gridH)} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uigridlayout
					CellSize={UDim2.fromOffset(fit.cell, rowH)}
					CellPadding={UDim2.fromOffset(GAP, GAP)}
					HorizontalAlignment={Enum.HorizontalAlignment.Center}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{cards}
			</frame>,
		);
		// the list layout puts Space.xs after the grid; counting more left an empty band under the roll
		contentH += gridH + Space.xs;
	}
	if (visible.size() === 0) {
		order += 1;
		body.push(
			<SurfaceText
				key="none"
				text={MODEL.DefaultEmptyText}
				type="body"
				color={Palette.muted}
				align={Enum.TextXAlignment.Center}
				size={new UDim2(1, 0, 0, 40)}
				order={order}
				zIndex={6}
			/>,
		);
		contentH += 40;
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	if (MODEL.Footer !== "") {
		smallPrint.push(MODEL.Footer);
	}
	if (smallPrint.size() > 0) {
		order += 1;
		body.push(
			<frame key="smallprint" Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uipadding PaddingTop={new UDim(0, Space.md)} PaddingBottom={new UDim(0, Space.sm)} />
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Space.xs)} />
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
		for (const line of smallPrint) {
			contentH += Space.xs + 16 * math.max(1, math.ceil(measureText(line, 13, Enum.Font.BuilderSans).X / math.max(1, contentW)));
		}
		contentH += Space.xl;
	}
	// the panel hugs its content; only a long roll reaches maxH and scrolls
	const height = math.min(maxH, headerH + contentH + pad * 2 + Space.sm);
	const bodyH = math.max(1, height - pad * 2 - headerH);

	React.useEffect(() => {
		ClientLog.debug("nav", "credits opened");
		return () => ClientLog.debug("nav", "credits closed");
	}, []);
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.Escape && !processed) {
				requestClose();
			}
		});
		return () => connection.Disconnect();
	}, [requestClose]);
	useBackLayer(true, requestClose);

	// gamepad: the overlay owns focus while open; the right stick scrolls the roll, B closes
	const padFocus = useGamepadAutofocus(true, reveal);
	const hostRef = React.useRef<Frame>();
	useFocusOrder(hostRef, { regions: ["CreditsList", "CreditsClaimActions"], first: ["CreditsClaimActions"] }, []);
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

	return (
		<OverlayPresence amount={reveal}>
			<frame key="CreditsClaimActions" ref={hostRef} {...ModalSelectionScope} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={320}>
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
						<SurfaceText text={MODEL.Title} type="display" size={new UDim2(1, -(TapTarget + Space.md), 0, 30)} position={UDim2.fromOffset(0, Space.xs)} zIndex={322} />
						{subline !== "" && (
							<SurfaceText
								text={subline}
								type="small"
								color={Palette.creamSoft}
								size={new UDim2(1, -(TapTarget + Space.md), 0, 16)}
								position={UDim2.fromOffset(0, 38)}
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
						<scrollingframe
							{...named("CreditsList")}
							Size={UDim2.fromOffset(innerW, bodyH)}
							Position={UDim2.fromOffset(0, headerH)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							CanvasSize={new UDim2()}
							AutomaticCanvasSize={Enum.AutomaticSize.Y}
							ScrollingDirection={Enum.ScrollingDirection.Y}
							ScrollBarThickness={3}
							ScrollBarImageColor3={Palette.muted}
							Selectable={UserInputService.GamepadEnabled}
							ZIndex={322}
						>
							<frame Size={new UDim2(0, contentW, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} ZIndex={322}>
								<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Space.xs)} />
								{body}
							</frame>
						</scrollingframe>
					</Surface>
				</frame>
			</frame>
		</OverlayPresence>
	);
}
