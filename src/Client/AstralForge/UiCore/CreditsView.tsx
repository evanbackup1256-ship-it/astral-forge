import { named } from "../lua";
import { CreditsLayout as C } from "../pages/generated/CreditsLayout";
// Credits: everyone who made the game, read from SharedData#CreditsConfig through CreditsModel.
//
// 21-credits: one brass-ruled Surface that hugs its content. A serif title block, the lead in a
// large round viewport with the rest of the team ringed around it (each viewport holds a
// companion still), name and role only, then a brass hairline and the thank-you line, with the
// acknowledgements in small print. Nothing to tap but Close: B, Esc or a tap outside also close
// it. Motion is unchanged: the panel reveals on usePresence, medallions rise on the shared surface
// stagger and settle on the surface spring.
import { useFocusOrder } from "../CoreKit/focusOrder";
import React from "@rbxts/react";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, scrollTail } from "../CoreKit/theme";
import { useEntrance, useViewport } from "../MotionKit/motion";
import { Line, MockPanel, mockGap, panelPad } from "./mockKit";
import { PHONE_HEAD_H as PH_HEAD_H, PhoneHead } from "../pages/mockLayout";
import { CreditsPhoneLayout as CP } from "../pages/generated/CreditsPhoneLayout";
import { SurfaceMotion, useSurfaceEnter, useSurfaceSpring } from "./surface";
import { measureText } from "./layoutEngine";
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

const { PageScaffold } = loadKit("LayoutKit")("pageScaffold") as { PageScaffold: (props: Record<string, unknown>) => React.Element };
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
	// 21-credits at 1920x1080: 230px lead with a 22px name, 150px ring with 17px names and 14px roles
	const nameSize = size >= C.LeadRing.w ? C.LeadName.text.size : size >= C.Ring.w ? C.Name.text.size : props.lead ? 17 : 14;
	const roleSize = size >= C.Ring.w ? C.Role.text.size : 12;
	const nameH = size >= C.LeadRing.w ? C.LeadName.h : size >= C.Ring.w ? C.Name.h : nameSize + 4;
	const roleH = size >= C.Ring.w ? C.Role.h : roleSize + 4;
	const lineGap = C.Cell.gap;
	const role = MODEL.ShowRoles !== false ? props.credit.roles.join(" · ") : "";
	const cell = CompanionSheets.FRAME;
	return (
		<frame
			Size={UDim2.fromOffset(props.width, size + lineGap + nameH + (role !== "" ? lineGap + roleH : 0))}
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
					Thickness={props.lead ? C.LeadRing.stroke.thickness : C.Ring.stroke.thickness}
					Color={C.Ring.stroke.color}
					Transparency={lit.map((v) => 0.55 - v * (0.55 - C.Ring.stroke.transparency))}
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
				Size={new UDim2(1, 0, 0, nameH)}
				Position={UDim2.fromOffset(0, size + lineGap)}
				BackgroundTransparency={1}
				Text={display}
				TextColor3={C.Name.text.color}
				TextTransparency={fade}
				TextSize={nameSize}
				TextScaled={false}
				TextTruncate={Enum.TextTruncate.AtEnd}
				FontFace={SERIF}
				ZIndex={8}
			/>
			{role !== "" && (
				<textlabel
					Size={new UDim2(1, 0, 0, roleH)}
					Position={UDim2.fromOffset(0, size + lineGap + nameH + lineGap)}
					BackgroundTransparency={1}
					Text={role}
					TextColor3={C.Role.text.color}
					TextTransparency={fade}
					TextSize={roleSize}
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
		<frame Size={new UDim2(1, 0, 0, C.Rule.h + 2)} LayoutOrder={props.order} BackgroundTransparency={1} ZIndex={6}>
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

// ── Page ───────────────────────────────────────────────────────────────────────

// 21-credits is a routed page in the hero shell: one .pn.f1 holding the lead row (150 / 230 / 150),
// rows of three 150 rings, the brass rule and the thank-you line, centred in the panel. phone.html:
// .ph-head (title + tagline) over a .pn.f1 with one row of 96 rings.
export function CreditsPage(props: { version?: string; reducedMotion?: boolean; bottomSafe?: number }) {
	const reduced = props.reducedMotion === true;
	useLiveNames();
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const enter = useEntrance(reduced);

	const visible = CreditsModel.visible(MODEL, "All", "");
	const [credits, thanks] = rollOf(visible);
	const leadSize = phone ? CP.Ring.w : C.LeadRing.w;
	const ringSize = phone ? CP.Ring.w : C.Ring.w;
	const cellW = phone ? CP.Cell.w : C.Cell.w;
	const perRow = phone ? 4 : 3;
	const pad = panelPad(phone);
	const panelW = (phone ? CP.Panel.w : C.Panel.w) - pad.x * 2;

	// rows: the lead flanked by the first two names (desktop), then the rest in rows of perRow
	const rows: Credit[][] = [];
	if (credits.size() > 0) {
		let start = 0;
		if (!phone) {
			const first: Credit[] = [];
			if (credits.size() > 1) first.push(credits[1]);
			first.push(credits[0]);
			if (credits.size() > 2) first.push(credits[2]);
			rows.push(first);
			start = 3;
		}
		let row: Credit[] = [];
		for (let i = start; i < credits.size(); i++) {
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
	let contentH = 0;
	let index = 0;
	const listGap = phone ? CP.Panel.gap : C.Panel.gap;
	for (const [r, row] of ipairs(rows)) {
		order += 1;
		const lead = !phone && r === 1;
		// phone.html spaces the four cells around the panel (space-around)
		const gap = phone ? math.max(8, math.floor((panelW - perRow * cellW) / perRow)) : lead ? C.LeadRow.gap : C.Row.gap;
		const fitW = math.floor((panelW - gap * math.max(0, row.size() - 1)) / math.max(1, row.size()));
		const fullH = phone ? CP.Cell.h : lead ? C.LeadRow.h : C.Row.h;
		const rowH = fullH - (MODEL.ShowRoles !== false ? 0 : C.Cell.gap + C.Role.h);
		body.push(
			<frame key={`r${r}`} Size={new UDim2(1, 0, 0, rowH)} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					HorizontalAlignment={Enum.HorizontalAlignment.Center}
					VerticalAlignment={Enum.VerticalAlignment.Bottom}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, gap)}
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
							width={math.max(isLead ? leadSize : ringSize, math.min(isLead ? C.LeadCell.w : cellW, fitW))}
							lead={isLead}
							order={i}
							delay={MODEL.EntranceStagger !== false ? math.min(index, SurfaceMotion.staggerRows) * SurfaceMotion.stagger : 0}
							reducedMotion={reduced}
						/>
					);
				})}
			</frame>,
		);
		contentH += rowH + listGap;
	}
	if (credits.size() === 0) {
		order += 1;
		body.push(<Line key="none" text={MODEL.DefaultEmptyText} size={15} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={40} align={Enum.TextXAlignment.Center} layoutOrder={order} />);
		contentH += 40 + listGap;
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	if (MODEL.Footer !== "") smallPrint.push(MODEL.Footer);
	// .rule + the thanks line (desktop only in phone.html)
	if (!phone && (thanks.size() > 0 || smallPrint.size() > 0)) {
		order += 1;
		body.push(<Hairline key="rule" order={order} width={C.Rule.w} />);
		contentH += C.Rule.h + 2 + listGap;
	}
	if (!phone && thanks.size() > 0) {
		order += 1;
		const line = thanks.join(" ");
		const lines = math.max(1, math.ceil(measureText(line, C.Thanks.text.size, Enum.Font.BuilderSans).X / math.max(1, panelW)));
		body.push(
			<Line key="thanks" text={line} size={C.Thanks.text.size} font={BODY} color={C.Thanks.text.color} width={new UDim(1, 0)} height={C.Thanks.h * lines} align={Enum.TextXAlignment.Center} layoutOrder={order} />,
		);
		contentH += C.Thanks.h * lines + listGap;
	}
	if (!phone && smallPrint.size() > 0) {
		order += 1;
		const lineH = 16;
		body.push(
			<frame key="smallprint" Size={new UDim2(1, 0, 0, smallPrint.size() * (lineH + 4))} LayoutOrder={order} BackgroundTransparency={1} ZIndex={6}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} />
				{smallPrint.map((line, i) => (
					<Line key={`p${i}`} text={line} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={lineH} align={Enum.TextXAlignment.Center} layoutOrder={i} />
				))}
			</frame>,
		);
		contentH += smallPrint.size() * (lineH + 4) + listGap;
	}
	contentH = math.max(0, contentH - listGap);

	React.useEffect(() => {
		ClientLog.debug("nav", "credits opened");
		return () => ClientLog.debug("nav", "credits closed");
	}, []);
	const hostRef = React.useRef<Frame>();
	useFocusOrder(hostRef, { regions: ["CreditsList", "CreditsClaimActions"], first: ["CreditsClaimActions"] }, []);

	// the panel fills the page body (.pn.f1); the roll sits centred in it and scrolls only when it is taller
	const panelMinH = phone ? CP.Panel.h : C.Panel.h;
	const panelH = math.max(panelMinH, contentH + pad.y * 2);
	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (phone) {
		sections.push({ id: "head", height: PH_HEAD_H, element: <PhoneHead line={MODEL.Tagline !== "" ? MODEL.Tagline : undefined} /> });
	}
	sections.push({
		id: "roll",
		height: panelH,
		element: (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.brass} glow={Palette.brass} reveal={enter} reducedMotion={reduced} gap={0} name="Credits">
				<frame {...named("CreditsList")} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={6}>
					<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, listGap)} VerticalAlignment={Enum.VerticalAlignment.Center} />
					{body}
				</frame>
			</MockPanel>
		),
	});
	return (
		<frame key="CreditsClaimActions" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ref={hostRef}>
			<PageScaffold gap={mockGap(phone)} tailPad={scrollTail(phone, props.bottomSafe ?? chrome.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} owner="Credits" />
		</frame>
	);
}
