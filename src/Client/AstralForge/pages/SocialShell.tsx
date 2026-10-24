// Social pages (Chat, Crew, Guild, Mail) share one shell, laid out after design/27-social:
//   .tabs (Chat / Crew / Guild / Mail, mint accent) right-aligned over the page body
//   .flexr body: the page fills the row; on Chat at desktop widths a 520px .flexc column on the right
//   holds the Crew panel ("3 of 6", status in mint) and the Mail panel ("2 new", Claim / Open in mint)
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import CrewStore = require("../CrewStore");
import { Line, MockPanel, PanelHeading, mockGap, BODY } from "../UiCore/mockKit";
import { MockBtn, MockRow, rowHeight } from "./mockRows";
import { SocialLayout as S } from "./generated/SocialLayout";
import { AvatarRing, GcRow } from "./gcKit";
import { FitPanel, fitPanelHeight } from "./socialKit";
import { PHONE_HEAD_H as PH_HEAD_H, PhoneHead } from "./mockLayout";
import { useHeroShown, useHeroSlot } from "../UiCore/heroSlot";

const Players = game.GetService("Players");

export const SOCIAL_PAGES = ["Chat", "Crew", "Guild", "Mail"];
const TAB_OPTIONS = SOCIAL_PAGES.map((id) => ({ id, label: id }));
/** .flexc style="width:520px" at the 1920 reference; narrower desktops scale it down to 30% */
const SIDE_W = S.Side.w;
const SIDE_MIN = 320;
const WIDE_MIN = 1000;
const PHONE_MAX = 700;
const CREW_SHOWN = 4;
const MAIL_SHOWN = 3;
const HEADING_H = math.ceil(S.Heading.h);

interface CrewMember {
	UserId: number;
	DisplayName?: string;
	Leader?: boolean;
	Zone?: number;
}
interface MailDef {
	Id?: string;
	Subject?: string;
	Sender?: string;
	Attachment?: unknown;
}
interface MailState {
	Id?: string;
	Read?: boolean;
	Claimed?: boolean;
}
type Dispatch = (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;

function CrewCard(props: { reducedMotion?: boolean; navigate: (page: string) => unknown; layoutOrder: number }) {
	const crew = CrewStore.useCrew() as { crew?: { Name?: string; Members?: CrewMember[]; Max?: number } };
	const members = crew.crew?.Members ?? [];
	const shown = math.min(members.size(), CREW_SHOWN);
	const rowH = rowHeight(false, true);
	const rows: React.Element[] = [];
	for (let i = 0; i < shown; i++) {
		const member = members[i];
		const here = Players.GetPlayerByUserId(member.UserId) !== undefined;
		rows.push(
			<GcRow
				key={`m${member.UserId}`}
				title={(member.DisplayName ?? tostring(member.UserId)) + (member.Leader ? " · Leader" : "")}
				sub={here ? (member.Zone !== undefined ? `World ${member.Zone}` : "In this server") : "Not in this server"}
				lead={<AvatarRing name={member.DisplayName ?? tostring(member.UserId)} image={`rbxthumb://type=AvatarHeadShot&id=${member.UserId}&w=48&h=48`} />}
				accent={Palette.mint}
				value={here ? "Online" : "Away"}
				valueColor={here ? Palette.mint : Palette.muted}
				phone={false}
				height={rowH}
				layoutOrder={1 + i}
			/>,
		);
	}
	const emptyH = 36;
	const height = fitPanelHeight(false, HEADING_H, shown === 0 ? [emptyH] : rows.map(() => rowH));
	const note = crew.crew !== undefined ? `${members.size()} of ${crew.crew.Max ?? 6}` : undefined;
	return (
		<FitPanel height={height} phone={false} layoutOrder={props.layoutOrder} name="CrewCard" reducedMotion={props.reducedMotion}>
			<frame Size={new UDim2(1, 0, 0, HEADING_H)} BackgroundTransparency={1} LayoutOrder={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} LayoutOrder={0}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<PanelHeading icon="Crew.1" title={crew.crew?.Name ?? "Crew"} note={note} accent={Palette.mint} phone={false} />
				</frame>
				<MockBtn text="Open" sec={true} sm={true} width={72} onClick={() => props.navigate("Crew")} reducedMotion={props.reducedMotion} layoutOrder={1} />
			</frame>
			{shown === 0 ? (
				<Line text="Not in a crew yet. Open the player list to invite someone." size={13} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={emptyH} layoutOrder={1} />
			) : (
				rows
			)}
		</FitPanel>
	);
}

function MailCard(props: { state: unknown; config: unknown; dispatch: Dispatch; reducedMotion?: boolean; navigate: (page: string) => unknown; layoutOrder: number }) {
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const mailbox = (props.state as { Mailbox?: { Messages?: MailState[]; Unread?: number } } | undefined)?.Mailbox;
	const defs: Record<string, MailDef> = {};
	const cfg = (props.config as { Mail?: MailDef[] } | undefined)?.Mail ?? [];
	for (const [, def] of pairs(cfg)) {
		if (def.Id !== undefined) {
			defs[def.Id] = def;
		}
	}
	// unclaimed gifts first, then unread; otherwise the server's order stands
	const picks: { def: MailDef; mail: MailState; gift: boolean }[] = [];
	for (const [, mail] of pairs(mailbox?.Messages ?? [])) {
		const def = mail.Id !== undefined ? defs[mail.Id] : undefined;
		if (def !== undefined) {
			picks.push({ def, mail, gift: def.Attachment !== undefined && mail.Claimed !== true });
		}
	}
	picks.sort((a, b) => (a.gift !== b.gift ? a.gift : a.mail.Read !== b.mail.Read ? b.mail.Read === true : false));
	const shown = math.min(picks.size(), MAIL_SHOWN);
	const rowH = rowHeight(false, true);
	const rows: React.Element[] = [];
	for (let i = 0; i < shown; i++) {
		const pick = picks[i];
		const id = pick.def.Id!;
		const open = () => {
			if (!pick.gift) {
				props.navigate("Mail");
				return;
			}
			setPending(id);
			props.dispatch("ClaimMail", { Id: id }, () => setPending(undefined));
		};
		rows.push(
			<MockRow
				key={`mail${i}`}
				title={pick.def.Subject ?? "Letter"}
				sub={`from ${pick.def.Sender ?? "Astral Forge"}`}
				icon={pick.gift ? "Gift.1" : "Mail.1"}
				accent={Palette.mint}
				dim={pick.mail.Read === true && !pick.gift}
				phone={false}
				height={rowH}
				layoutOrder={1 + i}
				right={<MockBtn text={pending === id ? "…" : pick.gift ? "Claim" : "Open"} accent={Palette.mint} sec={!pick.gift} sm={true} width={84} disabled={pending === id} onClick={open} reducedMotion={props.reducedMotion} />}
				rightWidth={84}
			/>,
		);
	}
	const unread = mailbox?.Unread ?? 0;
	const emptyH = 22;
	const height = fitPanelHeight(false, HEADING_H, shown === 0 ? [emptyH] : rows.map(() => rowH));
	return (
		<FitPanel height={height} phone={false} layoutOrder={props.layoutOrder} name="MailCard" reducedMotion={props.reducedMotion}>
			<PanelHeading icon="Mail.1" title="Mail" note={unread > 0 ? `${unread} new` : undefined} accent={Palette.mint} phone={false} layoutOrder={0} />
			{shown === 0 ? <Line text="No letters right now." size={13} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={emptyH} layoutOrder={1} /> : rows}
		</FitPanel>
	);
}

export function SocialShell(props: {
	page: string;
	state: unknown;
	config: unknown;
	dispatch: unknown;
	reducedMotion?: boolean;
	navigate: (page: string) => unknown;
	children: React.Element;
}) {
	const ref = React.useRef<Frame>();
	const [size, setSize] = React.useState(new Vector2(1280, 720));
	React.useEffect(() => {
		const host = ref.current;
		if (host === undefined) {
			return undefined;
		}
		const update = () => setSize(host.AbsoluteSize);
		update();
		const conn = host.GetPropertyChangedSignal("AbsoluteSize").Connect(update);
		return () => conn.Disconnect();
	}, []);
	const phone = size.X < PHONE_MAX;
	const gap = phone ? mockGap(phone) : S.Body.gap;
	const wide = props.page === "Chat" && size.X >= WIDE_MIN && size.Y >= 420;
	const sideW = math.clamp(math.floor(size.X * 0.3), SIDE_MIN, SIDE_W);
	const online = game.GetService("Players").GetPlayers().size();
	// desktop: the shell hero's bottom-right .tabs (UiCore/heroSlot); phones: .ph-head
	const onTab = (id: string) => {
		if (id !== props.page) {
			props.navigate(id);
		}
	};
	useHeroSlot(props.page, { tabs: { options: TAB_OPTIONS, value: props.page, onChange: onTab, accent: Palette.mint, width: math.ceil(S.Tabs.w) } });
	const inHero = useHeroShown();
	return (
		<frame ref={ref} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{/* .hero .tabs live in the shell hero (UiCore/heroSlot); phones put them in .ph-head with the online count */}
			{!inHero && (
				<frame key="Tabs" Size={new UDim2(1, 0, 0, PH_HEAD_H)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<PhoneHead line={`${online} online`} options={TAB_OPTIONS} value={props.page} onChange={onTab} accent={Palette.mint} reducedMotion={props.reducedMotion} />
				</frame>
			)}
			<frame key="SocialBody" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame key="SocialPage" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					{props.children}
				</frame>
				{wide && (
					<scrollingframe
						key="SocialSide"
						Size={new UDim2(0, sideW, 1, 0)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						CanvasSize={new UDim2()}
						AutomaticCanvasSize={Enum.AutomaticSize.Y}
						ScrollBarThickness={3}
						ScrollBarImageColor3={Palette.mint}
						ScrollingDirection={Enum.ScrollingDirection.Y}
						LayoutOrder={1}
					>
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<CrewCard reducedMotion={props.reducedMotion} navigate={props.navigate} layoutOrder={0} />
						<MailCard
							state={props.state}
							config={props.config}
							dispatch={props.dispatch as Dispatch}
							reducedMotion={props.reducedMotion}
							navigate={props.navigate}
							layoutOrder={1}
						/>
					</scrollingframe>
				)}
			</frame>
		</frame>
	);
}
