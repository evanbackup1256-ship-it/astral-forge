import { named } from "../lua";
// Credits: everyone who made the game, read from SharedData#CreditsConfig through CreditsModel.
//
// 21-credits: one brass-ruled Surface that hugs its content. A serif title block, the lead in a
// large round viewport with the rest of the team ringed around it (each viewport holds a
// companion still), name and role only, then a brass hairline and the thank-you line, with the
// acknowledgements in small print. Nothing to tap but Close: B, Esc or a tap outside also close
// it. Motion is unchanged: the panel reveals on usePresence, medallions rise on the shared surface
// stagger and settle on the surface spring.
import { ModalSelectionScope } from "./overlayCore";
import { useFocusOrder } from "../CoreKit/focusOrder";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, useGamepadAutofocus } from "./ui";
import { Surface, SurfaceMetrics, SurfaceMotion, SurfaceText, useSurfaceEnter, useSurfaceSpring } from "./surface";
import { measureText, Space } from "./layoutEngine";
import { Glow } from "./depth";

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
	Eyebrow?: string;
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

const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
const BODY = Font.fromName("BuilderSans", Enum.FontWeight.Medium);
// companion idle sheets come from Shared/ElementSprites (the one source for them)
interface CompanionSheetsApi {
	FRAME: number;
	sheet(this: void, element?: string): { Image: string } | undefined;
}
const CompanionSheets = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("ElementSprites") as ModuleScript,
) as CompanionSheetsApi;
const STILLS = ["Cinder", "BrassOwl", "Lumen", "Voidmote", "Tidepup", "Frostlet"].map((key) => CompanionSheets.sheet(key)?.Image ?? "");

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

// ── Roll ───────────────────────────────────────────────────────────────────────

interface Credit {
	member: Member;
	roles: string[];
	accent: Color3;
}

// one entry per person: someone listed under several sections keeps every role, in config order
function rollOf(visible: VisibleEntry[]): LuaTuple<[Credit[], string[]]> {
	const credits: Credit[] = [];
	const byName = new Map<string, Credit>();
	const thanks: string[] = [];
	for (const entry of visible) {
		const accent = tone(entry.category.Accent, Palette.brass);
		for (const member of entry.members) {
			// a thanks entry with no account behind it ("You") is the thank-you line, not a person
			if (entry.category.Id === "Thanks" && member.UserId === undefined) {
				if (member.Note !== "") thanks.push(member.Note);
				continue;
			}
			const key = member.UserId !== undefined ? tostring(member.UserId) : member.Name;
			const known = byName.get(key);
			if (known !== undefined) {
				if (member.Role !== "" && !known.roles.includes(member.Role)) known.roles.push(member.Role);
				continue;
			}
			const credit: Credit = { member, roles: member.Role !== "" ? [member.Role] : [], accent };
			byName.set(key, credit);
			credits.push(credit);
		}
	}
	return $tuple(credits, thanks);
}

// ── Medallion ──────────────────────────────────────────────────────────────────

// a round viewport holding a companion still, the name in serif and the role under it
function Medallion(props: {
	credit: Credit;
	still: string;
	size: number;
	width: number;
	lead: boolean;
	order: number;
	delay: number;
	reducedMotion: boolean;
}) {
	const member = props.credit.member;
	const [settled, setSettled] = React.useState(false);
	React.useEffect(() => {
		const job = task.delay(props.delay + SurfaceMotion.stagger * 2, () => setSettled(true));
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	const lit = useSurfaceSpring(settled ? 1 : 0, props.reducedMotion);
	const enter = useSurfaceEnter(props.reducedMotion, props.delay);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	const [display] = namesOf(member);
	const initial = display.sub(1, 1).upper();
	const size = props.size;
	const nameSize = props.lead ? 17 : 14;
	const role = MODEL.ShowRoles !== false ? props.credit.roles.join(" · ") : "";
	const cell = CompanionSheets.FRAME;
	return (
		<frame
			Size={UDim2.fromOffset(props.width, size + 8 + nameSize + 4 + (role !== "" ? 16 : 0))}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			ZIndex={6}
		>
			<frame
				Size={UDim2.fromOffset(size, size)}
				Position={enter.map((a) => new UDim2(0.5, 0, 0, (1 - math.clamp(a, 0, 1)) * 14))}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={darken(Palette.panel, 0.35)}
				BackgroundTransparency={fade}
				BorderSizePixel={0}
				ZIndex={7}
			>
				<uiscale Scale={lit.map((v) => 0.94 + v * 0.06)} />
				<uicorner CornerRadius={new UDim(1, 0)} />
				{props.lead && <Glow color={Palette.brass} radius={size / 2} spread={18} strength={0.88} zIndex={6} />}
				<uistroke
					Color={Palette.brass}
					Thickness={props.lead ? 2 : 1.5}
					Transparency={lit.map((v) => 0.55 - v * 0.35)}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				/>
				<uigradient
					Rotation={90}
					Color={new ColorSequence(lighten3(Palette.panel), darken(Palette.panel, 0.55))}
				/>
				{/* initial sits underneath, so the medallion is never empty while images stream in */}
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text={initial}
					TextColor3={Palette.brass}
					TextTransparency={fade.map((f) => 0.4 + f * 0.6)}
					TextSize={math.floor(size * 0.4)}
					FontFace={SERIF}
					ZIndex={7}
				/>
				<imagelabel
					Size={UDim2.fromScale(0.86, 0.86)}
					Position={UDim2.fromScale(0.5, 0.54)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Image={props.still}
					ImageRectOffset={Vector2.zero}
					ImageRectSize={new Vector2(cell, cell)}
					ImageTransparency={fade}
					ScaleType={Enum.ScaleType.Fit}
					ZIndex={8}
				/>
				{member.UserId !== undefined && (
					<frame
						Size={UDim2.fromOffset(math.floor(size * 0.34), math.floor(size * 0.34))}
						Position={UDim2.fromScale(0.86, 0.86)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={darken(Palette.panel, 0.35)}
						BackgroundTransparency={fade}
						BorderSizePixel={0}
						ZIndex={10}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.brass} Thickness={1} Transparency={fade.map((f) => 0.3 + f * 0.7)} />
						<textlabel
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							Text={initial}
							TextColor3={Palette.cream}
							TextTransparency={fade}
							TextScaled={true}
							FontFace={SERIF}
							ZIndex={10}
						/>
						<imagelabel
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							Image={`rbxthumb://type=AvatarHeadShot&id=${member.UserId}&w=150&h=150`}
							ImageTransparency={fade}
							ZIndex={11}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</imagelabel>
					</frame>
				)}
				<frame
					Size={new UDim2(1, -6, 1, -6)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={9}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={Palette.brass} Thickness={1} Transparency={0.75} />
				</frame>
			</frame>
			<textlabel
				Size={new UDim2(1, 0, 0, nameSize + 4)}
				Position={UDim2.fromOffset(0, size + 8)}
				BackgroundTransparency={1}
				Text={display}
				TextColor3={Palette.cream}
				TextTransparency={fade}
				TextSize={nameSize}
				TextScaled={false}
				TextTruncate={Enum.TextTruncate.AtEnd}
				FontFace={SERIF}
				ZIndex={8}
			/>
			{role !== "" && (
				<textlabel
					Size={new UDim2(1, 0, 0, 16)}
					Position={UDim2.fromOffset(0, size + 8 + nameSize + 4)}
					BackgroundTransparency={1}
					Text={role}
					TextColor3={Palette.muted}
					TextTransparency={fade}
					TextSize={12}
					TextTruncate={Enum.TextTruncate.AtEnd}
					FontFace={BODY}
					ZIndex={8}
				/>
			)}
		</frame>
	);
}

function lighten3(color: Color3): Color3 {
	return color.Lerp(new Color3(1, 1, 1), 0.04);
}

// brass hairline with a small diamond in the middle
function Hairline(props: { order: number; width: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 14)} LayoutOrder={props.order} BackgroundTransparency={1} ZIndex={6}>
			<frame
				Size={UDim2.fromOffset(props.width, 1)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={Palette.brass}
				BorderSizePixel={0}
				ZIndex={6}
			>
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.5, 0.45),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
			<frame
				Size={UDim2.fromOffset(7, 7)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={Palette.panel}
				BorderSizePixel={0}
				ZIndex={7}
			>
				<uistroke Color={Palette.brass} Thickness={1} Transparency={0.2} />
			</frame>
		</frame>
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
	const short = viewport.height < 520;

	const visible = CreditsModel.visible(MODEL, "All", "");
	const [credits, thanks] = rollOf(visible);
	const leadSize = short ? 84 : stack ? 104 : 124;
	const ringSize = short ? 60 : stack ? 68 : 80;
	const cellW = stack ? 120 : 156;
	const perRow = stack ? 3 : 4;

	const width = math.min(maxW, 860);
	const innerW = width - pad * 2;
	const contentW = innerW - Space.sm;

	const eyebrow = [string.upper(MODEL.Title), MODEL.ShowVersion === true && props.version !== undefined ? `V${props.version}` : ""]
		.filter((part) => part !== "")
		.join(" · ");
	const rawHeading = MODEL.Eyebrow !== undefined && MODEL.Eyebrow !== "" ? MODEL.Eyebrow : "Credits";
	const heading = string.upper(string.sub(rawHeading, 1, 1)) + string.lower(string.sub(rawHeading, 2));
	const titleSize = stack ? 26 : 32;
	const headerH = 16 + titleSize + 6 + (MODEL.Tagline !== "" ? 20 : 0) + Space.sm;

	// rows: the lead flanked by the first two names, then the rest in rows of perRow
	const rows: Credit[][] = [];
	if (credits.size() > 0) {
		const lead = credits[0];
		const first: Credit[] = [];
		if (credits.size() > 1) first.push(credits[1]);
		first.push(lead);
		if (credits.size() > 2) first.push(credits[2]);
		rows.push(first);
		let row: Credit[] = [];
		for (let i = 3; i < credits.size(); i++) {
			row.push(credits[i]);
			if (row.size() === perRow) {
				rows.push(row);
				row = [];
			}
		}
		if (row.size() > 0) rows.push(row);
	}

	const body: React.Element[] = [];
	let order = 0;
	let contentH = Space.lg;
	let index = 0;
	const roleH = MODEL.ShowRoles !== false ? 16 : 0;
	for (const [r, row] of ipairs(rows)) {
		order += 1;
		const lead = r === 1;
		const rowH = (lead ? leadSize : ringSize) + 8 + (lead ? 21 : 18) + roleH;
		body.push(
			<frame key={`r${r}`} Size={new UDim2(1, 0, 0, rowH)} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					HorizontalAlignment={Enum.HorizontalAlignment.Center}
					VerticalAlignment={Enum.VerticalAlignment.Bottom}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, stack ? Space.sm : Space.lg)}
				/>
				{row.map((credit, i) => {
					index += 1;
					const isLead = lead && credit === credits[0];
					return (
						<Medallion
							key={credit.member.UserId !== undefined ? tostring(credit.member.UserId) : credit.member.Name}
							credit={credit}
							still={STILLS[(credits.indexOf(credit) + STILLS.size()) % STILLS.size()]}
							size={isLead ? leadSize : ringSize}
							width={math.min(cellW, math.floor((contentW - Space.lg * 2) / math.max(1, row.size())))}
							lead={isLead}
							order={i}
							delay={MODEL.EntranceStagger !== false ? math.min(index, SurfaceMotion.staggerRows) * SurfaceMotion.stagger : 0}
							reducedMotion={reduced}
						/>
					);
				})}
			</frame>,
		);
		contentH += rowH + Space.sm;
	}
	if (credits.size() === 0) {
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
		contentH += 40 + Space.sm;
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	if (MODEL.Footer !== "") {
		smallPrint.push(MODEL.Footer);
	}
	if (thanks.size() > 0 || smallPrint.size() > 0) {
		order += 1;
		body.push(<Hairline key="rule" order={order} width={math.floor(contentW * 0.82)} />);
		contentH += 14 + Space.sm;
	}
	if (thanks.size() > 0) {
		order += 1;
		const line = thanks.join(" ");
		const lines = math.max(1, math.ceil(measureText(line, 14, Enum.Font.BuilderSans).X / math.max(1, contentW)));
		body.push(
			<SurfaceText
				key="thanks"
				text={line}
				type="body"
				color={Palette.creamSoft}
				wrap={true}
				align={Enum.TextXAlignment.Center}
				size={UDim2.fromScale(1, 0)}
				autoHeight={true}
				order={order}
				zIndex={6}
			/>,
		);
		contentH += 20 * lines + Space.sm;
	}
	if (smallPrint.size() > 0) {
		order += 1;
		body.push(
			<frame key="smallprint" Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uipadding PaddingBottom={new UDim(0, Space.sm)} />
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
		contentH += Space.lg;
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
					<Surface appear={reveal} padding={pad} accent={Palette.brass} active={true} zIndex={321}>
						<frame
							Size={new UDim2(1, pad * 2 - 6, 1, pad * 2 - 6)}
							Position={UDim2.fromScale(0.5, 0.5)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundTransparency={1}
							ZIndex={321}
						>
							<uicorner CornerRadius={new UDim(0, SurfaceMetrics.radius - 3)} />
							<uistroke Color={Palette.brass} Thickness={1} Transparency={reveal.map((a) => 1 - 0.25 * a)} />
						</frame>
						<textlabel
							Size={new UDim2(1, -(TapTarget + Space.md), 0, 14)}
							Position={UDim2.fromOffset(0, 2)}
							BackgroundTransparency={1}
							Text={eyebrow}
							TextColor3={Palette.brass}
							TextSize={11}
							TextXAlignment={Enum.TextXAlignment.Left}
							FontFace={Font.fromName("BuilderSans", Enum.FontWeight.Bold)}
							ZIndex={322}
						/>
						<textlabel
							Size={new UDim2(1, -(TapTarget + Space.md), 0, titleSize + 4)}
							Position={UDim2.fromOffset(0, 16)}
							BackgroundTransparency={1}
							Text={heading}
							TextColor3={Palette.cream}
							TextSize={titleSize}
							TextXAlignment={Enum.TextXAlignment.Left}
							FontFace={SERIF}
							ZIndex={322}
						/>
						{MODEL.Tagline !== "" && (
							<SurfaceText
								text={MODEL.Tagline}
								type="small"
								color={Palette.creamSoft}
								size={new UDim2(1, -(TapTarget + Space.md), 0, 16)}
								position={UDim2.fromOffset(0, 16 + titleSize + 8)}
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
							ScrollBarImageColor3={Palette.brass}
							Selectable={UserInputService.GamepadEnabled}
							ZIndex={322}
						>
							<frame Size={new UDim2(0, contentW, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} ZIndex={322}>
								<uipadding PaddingTop={new UDim(0, Space.lg)} />
								<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Space.sm)} />
								{body}
							</frame>
						</scrollingframe>
					</Surface>
				</frame>
			</frame>
		</OverlayPresence>
	);
}
