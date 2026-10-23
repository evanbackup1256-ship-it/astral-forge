// Social pages (Chat, Crew, Guild, Mail) share one shell: a hero row with the four tabs, and on
// wide screens the Chat page gets a right column with your crew and your newest mail.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { kitMember, LuauComponent } from "./luauKits";
import CrewStore = require("../CrewStore");
import { PnSurface } from "../UiCore/mockKit";

const { Button, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

const Players = game.GetService("Players");

export const SOCIAL_PAGES = ["Chat", "Crew", "Guild", "Mail"];
const TAB_OPTIONS = SOCIAL_PAGES.map((id) => ({ id, label: id }));
const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
const SIDE_W = 300;
const WIDE_MIN = 1000;
const GAP = 12;

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

function AvatarRing(props: { userId: number; size: number; position: UDim2; accent: Color3 }) {
	return (
		<imagelabel
			Size={UDim2.fromOffset(props.size, props.size)}
			Position={props.position}
			BackgroundColor3={Palette.raised}
			Image={`rbxthumb://type=AvatarHeadShot&id=${props.userId}&w=48&h=48`}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke Color={props.accent} Thickness={1.5} Transparency={0.2} />
		</imagelabel>
	);
}

function CrewCard(props: { reducedMotion?: boolean; navigate: (page: string) => unknown }) {
	const crew = CrewStore.useCrew() as { crew?: { Name?: string; Members?: CrewMember[] } };
	const members = crew.crew?.Members ?? [];
	const rows: Record<string, React.Element> = {};
	const shown = math.min(members.size(), 4);
	for (let i = 0; i < shown; i++) {
		const member = members[i];
		const here = Players.GetPlayerByUserId(member.UserId) !== undefined;
		rows[`m${member.UserId}`] = (
			<frame Size={new UDim2(1, 0, 0, 36)} Position={UDim2.fromOffset(0, 26 + i * 40)} BackgroundTransparency={1}>
				<AvatarRing userId={member.UserId} size={32} position={UDim2.fromOffset(0, 2)} accent={here ? Palette.mint : Palette.line} />
				<Text
					value={(member.DisplayName ?? tostring(member.UserId)) + (member.Leader ? " · Leader" : "")}
					size={14}
					color={Palette.cream}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(42, 2)}
					sizeConstraint={new UDim2(1, -42, 0, 18)}
				/>
				<Text
					value={here ? (member.Zone !== undefined ? `In world ${member.Zone}` : "In this server") : "Not in this server"}
					size={11}
					color={here ? Palette.mint : Palette.muted}
					weight={Enum.FontWeight.SemiBold}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(42, 20)}
					sizeConstraint={new UDim2(1, -42, 0, 14)}
				/>
			</frame>
		);
	}
	return (
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.mint} background={Palette.panel} padding={14} reducedMotion={props.reducedMotion} clips={true}>
			<Text value={crew.crew?.Name ?? "Crew"} size={13} color={Palette.mint} weight={Enum.FontWeight.SemiBold} fit={true} minSize={10} sizeConstraint={new UDim2(1, -80, 0, 16)} />
			{members.size() === 0 ? (
				<Text
					value="Not in a crew yet. Open the player list to invite someone."
					size={13}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 26)}
					sizeConstraint={new UDim2(1, 0, 0, 36)}
				/>
			) : (
				rows
			)}
			<frame Size={UDim2.fromOffset(72, 28)} Position={new UDim2(1, -72, 0, -6)} BackgroundTransparency={1}>
				<Button text="Open" onClick={() => props.navigate("Crew")} color={Palette.raised} textColor={Palette.cream} size={UDim2.fromScale(1, 1)} reducedMotion={props.reducedMotion} />
			</frame>
		</PnSurface>
	);
}

function MailCard(props: { state: unknown; config: unknown; dispatch: Dispatch; reducedMotion?: boolean; navigate: (page: string) => unknown }) {
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const mailbox = (props.state as { Mailbox?: { Messages?: MailState[]; Unread?: number } } | undefined)?.Mailbox;
	const defs: Record<string, MailDef> = {};
	const cfg = (props.config as { Mail?: MailDef[] } | undefined)?.Mail ?? [];
	for (const [, def] of pairs(cfg)) {
		if (def.Id !== undefined) {
			defs[def.Id] = def;
		}
	}
	// unclaimed gifts first, then unread, newest last in the list stays where the server put it
	const picks: { def: MailDef; mail: MailState; gift: boolean }[] = [];
	for (const [, mail] of pairs(mailbox?.Messages ?? [])) {
		const def = mail.Id !== undefined ? defs[mail.Id] : undefined;
		if (def !== undefined) {
			picks.push({ def, mail, gift: def.Attachment !== undefined && mail.Claimed !== true });
		}
	}
	picks.sort((a, b) => (a.gift !== b.gift ? a.gift : a.mail.Read !== b.mail.Read ? b.mail.Read === true : false));
	const rows: Record<string, React.Element> = {};
	const shown = math.min(picks.size(), 3);
	for (let i = 0; i < shown; i++) {
		const pick = picks[i];
		const id = pick.def.Id!;
		rows[`mail${i}`] = (
			<frame Size={new UDim2(1, 0, 0, 40)} Position={UDim2.fromOffset(0, 26 + i * 44)} BackgroundTransparency={1}>
				<Text
					value={pick.def.Subject ?? "Letter"}
					size={14}
					color={pick.mail.Read === true ? Palette.muted : Palette.cream}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 2)}
					sizeConstraint={new UDim2(1, -84, 0, 18)}
				/>
				<Text
					value={pick.def.Sender ?? ""}
					size={11}
					color={Palette.muted}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, 21)}
					sizeConstraint={new UDim2(1, -84, 0, 14)}
				/>
				<frame Size={UDim2.fromOffset(76, 32)} Position={new UDim2(1, -76, 0, 4)} BackgroundTransparency={1}>
					<Button
						text={pick.gift ? "Claim" : "Open"}
						onClick={() => {
							if (!pick.gift) {
								props.navigate("Mail");
								return;
							}
							setPending(id);
							props.dispatch("ClaimMail", { Id: id }, () => setPending(undefined));
						}}
						color={pick.gift ? Palette.mango : Palette.raised}
						textColor={pick.gift ? Palette.ink : Palette.cream}
						size={UDim2.fromScale(1, 1)}
						highlight={pick.gift}
						loading={pending === id}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</frame>
		);
	}
	const unread = mailbox?.Unread ?? 0;
	return (
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={14} reducedMotion={props.reducedMotion} clips={true}>
			<Text value={unread > 0 ? `Mail · ${unread} unread` : "Mail"} size={13} color={Palette.cyan} weight={Enum.FontWeight.SemiBold} fit={true} minSize={10} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			{shown === 0 ? (
				<Text value="No letters right now." size={13} color={Palette.muted} fit={true} minSize={10} position={UDim2.fromOffset(0, 26)} sizeConstraint={new UDim2(1, 0, 0, 18)} />
			) : (
				rows
			)}
		</PnSurface>
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
	const short = size.Y < 460;
	const heroH = short ? 40 : 52;
	const wide = props.page === "Chat" && size.X >= WIDE_MIN && size.Y >= 420;
	const titleW = short || size.X < 640 ? 0 : 150;
	const tabsW = math.min(size.X - titleW - 12, 420);
	return (
		<frame ref={ref} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<frame key="Hero" Size={new UDim2(1, 0, 0, heroH)} BackgroundTransparency={1} BorderSizePixel={0}>
				{titleW > 0 && (
					<textlabel
						Size={new UDim2(0, titleW, 1, 0)}
						BackgroundTransparency={1}
						Text="Social"
						FontFace={SERIF}
						TextSize={26}
						TextColor3={Palette.cream}
						TextXAlignment={Enum.TextXAlignment.Left}
					/>
				)}
				<frame
					Size={new UDim2(0, tabsW, 1, short ? -4 : -10)}
					Position={new UDim2(1, 0, 0.5, 0)}
					AnchorPoint={new Vector2(1, 0.5)}
					BackgroundTransparency={1}
				>
					<SegmentedTabs
						options={TAB_OPTIONS}
						value={props.page}
						onChange={(id: unknown) => {
							if (id !== props.page) {
								props.navigate(id as string);
							}
						}}
						accent={Palette.brass}
						columns={SOCIAL_PAGES.size()}
						gap={6}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</frame>
			<frame
				key="Body"
				Size={new UDim2(1, wide ? -(SIDE_W + GAP) : 0, 1, -(heroH + 8))}
				Position={UDim2.fromOffset(0, heroH + 8)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				{props.children}
			</frame>
			{wide && (
				<frame
					key="Side"
					Size={new UDim2(0, SIDE_W, 1, -(heroH + 8))}
					Position={new UDim2(1, -SIDE_W, 0, heroH + 8)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<frame key="Crew" Size={new UDim2(1, 0, 0.5, -GAP / 2)} BackgroundTransparency={1}>
						<CrewCard reducedMotion={props.reducedMotion} navigate={props.navigate} />
					</frame>
					<frame key="Mail" Size={new UDim2(1, 0, 0.5, -GAP / 2)} Position={new UDim2(0, 0, 0.5, GAP / 2)} BackgroundTransparency={1}>
						<MailCard
							state={props.state}
							config={props.config}
							dispatch={props.dispatch as Dispatch}
							reducedMotion={props.reducedMotion}
							navigate={props.navigate}
						/>
					</frame>
				</frame>
			)}
		</frame>
	);
}
