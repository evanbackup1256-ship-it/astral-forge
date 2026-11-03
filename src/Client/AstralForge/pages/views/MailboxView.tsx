// The Mailbox: letters from the game (patch notes, story letters, gifts) and the recent alerts feed.
// An inbox list on the left with filters and search, the open letter on the right; on phones the reader slides
// over the list. Letters with an attachment carry a parcel to claim; claimed letters can be archived.
import React from "@rbxts/react";
import { initial } from "../../CoreKit/chatText";
import { formatReward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import * as NoticeMath from "../../CoreKit/noticeMath";
import { Icon } from "../../ArtKit/Icon";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useFlash, useFlipperSpring, useStagger, useViewport } from "../../MotionKit/motion";
import { Badge, Button, EmptyState, measureWrappedTextHeight, SearchField, SegmentedTabs, Text } from "../../UiCore/ui";
import { Component, loadAudio, loadBrowse, luauKit, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;
const ScriptedText = luauKit<{ ScriptedText: Component }>("ReactHosts", "RichTextHost").ScriptedText;
const Browse = loadBrowse();

const ROW_H = 84;
const ROW_GAP = 8;
const PARAGRAPH_GAP = 10;
const FILTERS = [
	{ id: "All", label: "All" },
	{ id: "Unread", label: "Unread" },
	{ id: "Gifts", label: "Gifts" },
	{ id: "Collected", label: "Collected" },
	{ id: "Alerts", label: "Alerts" },
];
const ALERT_COLORS: Record<string, string | undefined> = { Success: "mint", Warning: "mango", Error: "coral", Special: "violet" };

interface Letter {
	Id: string;
	Subject: string;
	Sender: string;
	Preview?: string;
	Date?: string;
	Body?: string[];
	Color: Color3;
	Attachment?: Record<string, unknown>;
}
interface MailState {
	Id: string;
	Read?: boolean;
	Claimed?: boolean;
}
interface Row {
	Id: string;
	item: Letter;
	mail: MailState;
}
interface Reply {
	ok?: boolean;
}
interface Props {
	state: { Mailbox?: { Messages?: MailState[] } };
	config: { Mail?: Letter[] };
	dispatch: (action: string, payload?: object, callback?: (response: Reply) => void) => unknown;
	reducedMotion?: boolean;
}

/** The session's recent pop-ups, shown as letters under the Alerts filter. */
function alertRows(query: string): Row[] {
	const rows: Row[] = [];
	for (const entry of NoticeMath.Entries()) {
		const subject = entry.Count > 1 ? `${entry.Title}  ×${entry.Count}` : entry.Title;
		if (query !== "" && !Browse.matches(query, entry.Title, entry.Body)) {
			continue;
		}
		const tone = ALERT_COLORS[entry.Tone] ?? "cyan";
		rows.push({
			Id: entry.Id,
			item: {
				Id: entry.Id,
				Subject: subject !== "" ? subject : "Forge alert",
				Sender: "Forge alerts",
				Preview: entry.Body,
				Date: os.date("%H:%M", entry.At),
				Body: [entry.Body !== "" ? entry.Body : entry.Title],
				Color: (Palette as unknown as Record<string, Color3 | undefined>)[tone] ?? Palette.cyan,
			},
			mail: { Id: entry.Id, Read: true, Claimed: false },
		});
	}
	return rows;
}

function hasGift(item: Letter): boolean {
	return item.Attachment !== undefined && next(item.Attachment)[0] !== undefined;
}

function Avatar(props: { item: Letter; unread: boolean; size: number; position: UDim2 }) {
	return (
		<frame
			Size={UDim2.fromOffset(props.size, props.size)}
			Position={props.position}
			BackgroundColor3={darken(props.item.Color, props.unread ? 0.25 : 0.65)}
			BorderSizePixel={0}
			ZIndex={3}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke Color={props.item.Color} Thickness={1.5} Transparency={props.unread ? 0.05 : 0.55} />
			<Text
				value={initial(props.item.Sender)}
				size={math.floor(props.size * 0.42)}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				align={Enum.TextXAlignment.Center}
				sizeConstraint={UDim2.fromScale(1, 1)}
				zIndex={4}
			/>
		</frame>
	);
}

function MailRow(props: { item: Letter; mail: MailState; active: boolean; softMotion?: boolean; onChoose: (id: string) => void }) {
	const { item, mail } = props;
	const unread = mail.Read !== true;
	const gift = hasGift(item) && mail.Claimed !== true;
	const reveal = useStagger(0, props.softMotion, 0.02, 0.2);
	const [hover, setHover] = React.useState(false);
	const glow = useFlipperSpring(props.active ? 1 : hover ? 0.5 : 0, props.softMotion, 640, 36);
	const chip = (children: React.Element, background: Color3) => (
		<frame Size={UDim2.fromOffset(22, 18)} BackgroundColor3={background} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 6)} />
			{children}
		</frame>
	);
	return (
		<imagebutton
			{...named("MailRow")}
			Size={new UDim2(1, -4, 0, ROW_H)}
			BackgroundColor3={Palette.panelRaised}
			BackgroundTransparency={reveal.map((a) => 1 - a)}
			AutoButtonColor={false}
			BorderSizePixel={0}
			Selectable={true}
			ClipsDescendants={false}
			Event={{
				Activated: () => props.onChoose(item.Id),
				MouseEnter: () => {
					setHover(true);
					Audio.play("hover");
				},
				MouseLeave: () => setHover(false),
				SelectionGained: () => setHover(true),
				SelectionLost: () => setHover(false),
			}}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke
				Color={props.active || unread ? item.Color : Palette.lineSoft}
				Thickness={glow.map((a) => 1 + a)}
				Transparency={glow.map((a) => (unread ? 0.35 - a * 0.3 : 0.7 - a * 0.5))}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={item.Color} BackgroundTransparency={glow.map((a) => 1 - a * 0.1)} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 14)} />
			</frame>
			<Avatar item={item} unread={unread} size={44} position={new UDim2(0, 12, 0.5, -22)} />
			<Text
				value={item.Subject}
				size={15}
				color={Palette.cream}
				weight={unread ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(68, 12)}
				sizeConstraint={new UDim2(1, -150, 0, 20)}
				zIndex={3}
			/>
			<Text value={item.Sender} size={12} color={item.Color} weight={Enum.FontWeight.Bold} fit={true} minSize={9} position={UDim2.fromOffset(68, 33)} sizeConstraint={new UDim2(1, -150, 0, 16)} zIndex={3} />
			<Text value={item.Preview ?? ""} size={12} color={Palette.muted} position={UDim2.fromOffset(68, 52)} sizeConstraint={new UDim2(1, -80, 0, 18)} zIndex={3} />
			<Text
				value={item.Date ?? ""}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -94, 0, 12)}
				sizeConstraint={UDim2.fromOffset(82, 16)}
				zIndex={3}
			/>
			<frame Size={UDim2.fromOffset(70, 20)} Position={new UDim2(1, -82, 0, 32)} BackgroundTransparency={1} ZIndex={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right} Padding={new UDim(0, 4)} />
				{unread && <Badge value="NEW" accent={item.Color} filled={true} size={UDim2.fromOffset(40, 18)} />}
				{gift &&
					chip(
						<Icon kind="Gift.10" color={Palette.ink} accent={Palette.mint} size={14} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />,
						Palette.mint,
					)}
				{!gift &&
					mail.Claimed === true &&
					hasGift(item) &&
					chip(
						<Icon kind="Check.15" color={Palette.mint} accent={Palette.mint} size={14} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />,
						Palette.panelSoft,
					)}
			</frame>
		</imagebutton>
	);
}

/** The attachment at the foot of an open letter: what it holds, and the claim and archive buttons. */
function Parcel(props: {
	item: Letter;
	claimed: boolean;
	stack: boolean;
	height: number;
	softMotion?: boolean;
	claimToken: number;
	onClaim: () => void;
	onArchive: () => void;
}) {
	const { item, claimed, stack } = props;
	const pop = useFlash(props.claimToken, props.softMotion, 0.7);
	const textInset = stack ? -86 : -340;
	return (
		<frame
			{...named("MailClaimActions")}
			Size={new UDim2(1, 0, 0, props.height)}
			Position={new UDim2(0, 0, 1, -props.height)}
			BackgroundColor3={darken(item.Color, claimed ? 0.85 : 0.72)}
			BorderSizePixel={0}
			ClipsDescendants={false}
			ZIndex={6}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={claimed ? Palette.lineSoft : item.Color} Thickness={pop.map((a) => 1.5 + a * 2)} Transparency={claimed ? 0.6 : 0.15} />
			<frame Size={UDim2.fromOffset(48, 48)} Position={UDim2.fromOffset(14, 14)} BackgroundColor3={claimed ? Palette.panelSoft : item.Color} BorderSizePixel={0} ZIndex={7}>
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uiscale Scale={pop.map((a) => 1 + a * 0.3)} />
				<Icon
					kind={claimed ? "Check.16" : "Gift.11"}
					color={claimed ? Palette.mint : Palette.ink}
					accent={item.Color}
					size={28}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
				/>
			</frame>
			<Text
				value={claimed ? "COLLECTED" : "ATTACHED GIFT"}
				size={11}
				color={claimed ? Palette.mint : item.Color}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(74, 16)}
				sizeConstraint={new UDim2(1, textInset, 0, 14)}
				zIndex={7}
			/>
			<Text
				value={formatReward(item.Attachment as never)}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(74, 34)}
				sizeConstraint={new UDim2(1, textInset, 0, 22)}
				zIndex={7}
			/>
			<frame
				Size={stack ? new UDim2(1, -28, 0, TapTarget) : UDim2.fromOffset(310, TapTarget)}
				Position={stack ? new UDim2(0, 14, 1, -(TapTarget + 14)) : new UDim2(1, -324, 0.5, -TapTarget / 2)}
				BackgroundTransparency={1}
				ClipsDescendants={false}
				ZIndex={8}
			>
				<frame {...named("MailClaim")} Size={new UDim2(0.62, -4, 1, 0)} BackgroundTransparency={1} ClipsDescendants={false}>
					<Button
						text={claimed ? "COLLECTED" : "CLAIM GIFT"}
						icon="Gift.12"
						onClick={props.onClaim}
						color={claimed ? Palette.panelSoft : item.Color}
						textColor={claimed ? Palette.muted : Palette.ink}
						size={UDim2.fromScale(1, 1)}
						disabled={claimed}
						highlight={!claimed}
						reducedMotion={props.softMotion}
					/>
				</frame>
				<frame {...named("MailArchive")} Size={new UDim2(0.38, -4, 1, 0)} Position={new UDim2(0.62, 4, 0, 0)} BackgroundTransparency={1}>
					<Button
						text="ARCHIVE"
						icon="Close.4"
						onClick={props.onArchive}
						color={Palette.coral}
						textColor={claimed ? Palette.cream : Palette.muted}
						outline={true}
						size={UDim2.fromScale(1, 1)}
						disabled={!claimed}
						reducedMotion={props.softMotion}
					/>
				</frame>
			</frame>
		</frame>
	);
}

interface BodyRow {
	Id: string;
	Text: string;
	Index: number;
	Height: number;
}

function MailboxView(props: Props) {
	const { state, config, dispatch } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const stack = chrome.contentStack;
	const mobileRoute = chrome.mobile || viewport.width < 760;
	const overscan = softMotion ? 0 : antilag.constrained ? 1 : 2;
	const mountedRef = React.useRef(true);
	const mailActionsHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		mountedRef.current = true;
		return () => {
			mountedRef.current = false;
		};
	}, []);
	const [filter, setFilter] = React.useState("All");
	const [query, setQuery] = Browse.useLinkedQuery("Mail");
	const [claimToken, setClaimToken] = React.useState(0);
	// the alerts feed changes outside React; bumping this redraws the Alerts list
	const [, setAlertRevision] = React.useState(0);
	React.useEffect(
		() =>
			NoticeMath.Subscribe(() => {
				if (mountedRef.current) setAlertRevision((n) => n + 1);
			}),
		[],
	);

	// the inbox: every letter the player has, counted, then filtered and searched
	const defs = new Map<string, Letter>();
	for (const def of config.Mail ?? []) defs.set(def.Id, def);
	let rows: Row[] = [];
	let unread = 0;
	let gifts = 0;
	for (const mail of state.Mailbox?.Messages ?? []) {
		const item = defs.get(mail.Id);
		if (item === undefined) continue;
		const gift = hasGift(item) && mail.Claimed !== true;
		if (mail.Read !== true) unread += 1;
		if (gift) gifts += 1;
		let keep =
			filter === "All" || (filter === "Unread" && mail.Read !== true) || (filter === "Gifts" && gift) || (filter === "Collected" && mail.Claimed === true);
		if (keep && query !== "") keep = Browse.matches(query, item.Subject, item.Sender, item.Body?.join(" "));
		if (keep) rows.push({ Id: item.Id, item, mail });
	}
	if (filter === "Alerts") rows = alertRows(query);

	const [selectedId, setSelectedId] = React.useState(mobileRoute ? "" : (rows[0]?.Id ?? ""));
	let selected = rows.find((row) => row.Id === selectedId);
	if (selected === undefined && !mobileRoute) selected = rows[0];
	const showReader = mobileRoute && selected !== undefined;
	const slide = useFlipperSpring(showReader ? 1 : 0, softMotion, 700, 40);
	const selectedKey = selected?.Id ?? "";
	const selectedRead = selected?.mail.Read === true;
	React.useEffect(() => {
		if (selected !== undefined && selected.mail.Read !== true) dispatch("ReadMail", { Id: selected.Id });
	}, [selectedKey, selectedRead]);
	// on a gamepad, focus moves to the letter's claim buttons when one opens
	React.useEffect(() => {
		const host = mailActionsHostRef.current;
		if (selected === undefined || !UserInputService.GamepadEnabled || host === undefined) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [selectedKey, selected?.mail.Claimed === true]);
	const choose = (id: string) => {
		if (id !== selectedId) {
			Audio.play("mailRead");
			setSelectedId(id);
		}
	};
	const claimAll = () => {
		Audio.play("mailClaim");
		setClaimToken((n) => n + 1);
		dispatch("ClaimAllMail", {});
	};

	const headerH = stack ? 118 : 64;
	const header = (
		<frame Size={new UDim2(1, 0, 0, headerH)} BackgroundColor3={Palette.panel} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={Palette.lineSoft} Transparency={0.5} />
			<frame Size={UDim2.fromOffset(40, 40)} Position={UDim2.fromOffset(12, 12)} BackgroundColor3={darken(Palette.cyan, 0.6)} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 12)} />
				<Icon kind="Mail.2" color={Palette.cream} accent={Palette.cyan} size={24} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />
			</frame>
			<Text value="Mailbox" size={11} color={Palette.cyan} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(62, 12)} sizeConstraint={new UDim2(0, 160, 0, 14)} />
			<Text
				value={unread === 0 && gifts === 0 ? "All caught up" : `${unread} unread · ${gifts} gift${gifts === 1 ? "" : "s"} waiting`}
				size={16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(62, 28)}
				sizeConstraint={new UDim2(stack ? 1 : 0, stack ? -(62 + 150) : 260, 0, 22)}
			/>
			{gifts > 0 && (
				<Button
					text={`CLAIM ALL (${gifts})`}
					icon="Gift.13"
					onClick={claimAll}
					color={Palette.mint}
					textColor={Palette.ink}
					size={UDim2.fromOffset(140, TapTarget - 4)}
					position={new UDim2(1, -152, 0, 10)}
					highlight={true}
					reducedMotion={softMotion}
				/>
			)}
			<frame
				Size={stack ? new UDim2(1, -24, 0, TapTarget + 8) : new UDim2(1, -(380 + (gifts > 0 ? 164 : 12)), 0, 40)}
				Position={stack ? UDim2.fromOffset(12, headerH - TapTarget - 18) : UDim2.fromOffset(372, 12)}
				BackgroundTransparency={1}
			>
				<SegmentedTabs
					options={FILTERS}
					value={filter}
					onChange={(id: string) => {
						setFilter(id);
						setSelectedId("");
					}}
					accent={Palette.cyan}
					columns={FILTERS.size()}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
				/>
			</frame>
		</frame>
	);

	const searchH = stack ? TapTarget : 40;
	const emptyTitle =
		query !== "" ? `No letters match "${query}"` : filter === "All" ? "Your tray is empty" : filter === "Alerts" ? "No recent alerts" : `Nothing in ${string.lower(filter)}`;
	const emptyBody =
		query !== ""
			? "Try the sender's name or one word from the subject."
			: filter === "Alerts"
				? "Pop-ups from this session are kept here so you can read them again."
				: "Patch notes, letters and gifts land here.";
	const list =
		rows.size() === 0 ? (
			<frame Size={new UDim2(1, 0, 1, -(searchH + 12))} Position={UDim2.fromOffset(0, searchH + 12)} BackgroundTransparency={1}>
				<EmptyState icon={query !== "" ? "Search.6" : "Mail.3"} title={emptyTitle} body={emptyBody} accent={Palette.cyan} size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} />
			</frame>
		) : (
			<FlatList
				data={rows}
				itemHeight={ROW_H + ROW_GAP}
				overscan={overscan}
				canvasTail={6}
				Size={new UDim2(1, -12, 1, -(searchH + 18))}
				Position={UDim2.fromOffset(6, searchH + 12)}
				scrollBarColor={Palette.cyan}
				scrollBarThickness={3}
				keyExtractor={(row: Row) => row.Id}
				renderItem={({ item: row }: { item: Row }) => (
					<MailRow item={row.item} mail={row.mail} active={row.Id === selectedKey} softMotion={softMotion} onChoose={choose} />
				)}
			/>
		);

	let reader: React.Element | undefined;
	if (selected !== undefined) {
		const item = selected.item;
		const readerW = mobileRoute ? viewport.width - 24 : viewport.width * 0.6;
		const textW = math.max(60, readerW - 64);
		const bodySize = stack ? 16 : 15;
		// every paragraph steps by the tallest one: each box is the stride less the gap between them
		const bodyRows: BodyRow[] = [];
		let tallest = 18;
		(item.Body ?? []).forEach((paragraph, index) => {
			const height = math.max(20, measureWrappedTextHeight(paragraph, textW, bodySize, Enum.FontWeight.Regular) + 6);
			tallest = math.max(tallest, height);
			bodyRows.push({ Id: `${item.Id}:${index + 1}`, Text: paragraph, Index: index, Height: height });
		});
		const stride = tallest + PARAGRAPH_GAP;
		const gift = hasGift(item);
		const claimed = selected.mail.Claimed === true;
		const parcelH = !gift ? 0 : stack ? 138 : 78;
		const letterTop = stack ? 74 : 92;
		const headLeft = mobileRoute ? 64 : 84;
		const headRight = mobileRoute ? -76 : -104;
		reader = (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={lighten(Palette.panel, 0.02)} BorderSizePixel={0} ClipsDescendants={true}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={item.Color} Transparency={0.5} />
				<frame {...named("LetterHead")} Size={new UDim2(1, 0, 0, letterTop)} BackgroundColor3={darken(item.Color, 0.8)} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 14)} />
					{mobileRoute ? (
						<Button
							text=""
							icon="Back.1"
							onClick={() => setSelectedId("")}
							color={Palette.panelSoft}
							textColor={item.Color}
							outline={true}
							size={UDim2.fromOffset(TapTarget, TapTarget)}
							position={new UDim2(0, 10, 0.5, -TapTarget / 2)}
							reducedMotion={softMotion}
						/>
					) : (
						<Avatar item={item} unread={true} size={52} position={new UDim2(0, 18, 0.5, -26)} />
					)}
					<Text
						value={item.Subject}
						size={stack ? 18 : 22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={12}
						position={UDim2.fromOffset(headLeft, stack ? 12 : 20)}
						sizeConstraint={new UDim2(1, headRight, 0, stack ? 24 : 30)}
					/>
					<Text
						value={`From ${item.Sender}${item.Date !== undefined && item.Date !== "" ? `  ·  ${item.Date}` : ""}`}
						size={12}
						color={item.Color}
						weight={Enum.FontWeight.Bold}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(headLeft, stack ? 40 : 54)}
						sizeConstraint={new UDim2(1, headRight, 0, 18)}
					/>
				</frame>
				<FlatList
					key={item.Id}
					data={bodyRows}
					itemHeight={stride}
					overscan={overscan}
					canvasTail={8}
					Size={new UDim2(1, -40, 1, -(letterTop + parcelH + 24))}
					Position={UDim2.fromOffset(20, letterTop + 10)}
					scrollBarColor={item.Color}
					scrollBarThickness={3}
					keyExtractor={(row: BodyRow) => row.Id}
					renderItem={({ item: row }: { item: BodyRow }) =>
						// the first paragraph types itself in; the rest are plain
						row.Index === 0 ? (
							<ScriptedText
								key={row.Id}
								text={row.Text}
								width={textW}
								height={row.Height}
								size={bodySize}
								color={Palette.cream}
								weight={Enum.FontWeight.SemiBold}
								typewriterInterval={0.01}
								reducedMotion={softMotion}
							/>
						) : (
							<Text
								key={row.Id}
								value={row.Text}
								size={bodySize}
								color={Palette.creamSoft}
								wrap={true}
								fit={true}
								minSize={11}
								sizeConstraint={new UDim2(1, -8, 0, stride - PARAGRAPH_GAP)}
							/>
						)
					}
				/>
				{gift && (
					<frame ref={mailActionsHostRef} Size={new UDim2(1, -20, 0, parcelH)} Position={new UDim2(0, 10, 1, -(parcelH + 10))} BackgroundTransparency={1} ClipsDescendants={false}>
						<Parcel
							item={item}
							claimed={claimed}
							stack={stack}
							height={parcelH}
							softMotion={softMotion}
							claimToken={claimToken}
							onClaim={() => {
								Audio.play("mailClaim");
								setClaimToken((n) => n + 1);
								dispatch("ClaimMail", { Id: item.Id });
							}}
							onArchive={() =>
								dispatch("DeleteMail", { Id: item.Id }, (response) => {
									if (mountedRef.current && response.ok === true) setSelectedId("");
								})
							}
						/>
					</frame>
				)}
			</frame>
		);
	} else if (!mobileRoute) {
		reader = <EmptyState icon="Mail.4" title="Pick a letter" body="Choose a message on the left to read it." accent={Palette.cyan} size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} />;
	}

	const bodyTop = headerH + 10;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={true}>
			{header}
			<frame Size={new UDim2(1, 0, 1, -bodyTop)} Position={UDim2.fromOffset(0, bodyTop)} BackgroundTransparency={1} ClipsDescendants={true}>
				<frame
					{...named("Inbox")}
					Size={mobileRoute ? UDim2.fromScale(1, 1) : new UDim2(0.38, -6, 1, 0)}
					Position={mobileRoute ? slide.map((a) => UDim2.fromScale(-math.clamp(a, 0, 1), 0)) : undefined}
					Visible={mobileRoute ? slide.map((a) => a < 0.99) : true}
					BackgroundColor3={Palette.panel}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 14)} />
					<SearchField
						value={query}
						onChange={(text: string) => {
							setQuery(text);
							setSelectedId("");
						}}
						placeholder="Search letters"
						accent={Palette.cyan}
						reducedMotion={softMotion}
						position={UDim2.fromOffset(6, 6)}
						size={new UDim2(1, -12, 0, searchH)}
						zIndex={6}
					/>
					{list}
				</frame>
				{reader !== undefined && (
					<frame
						{...named("Reader")}
						Size={mobileRoute ? UDim2.fromScale(1, 1) : new UDim2(0.62, -6, 1, 0)}
						Position={mobileRoute ? slide.map((a) => UDim2.fromScale(1 - math.clamp(a, 0, 1), 0)) : new UDim2(0.38, 6, 0, 0)}
						Visible={mobileRoute ? slide.map((a) => a > 0.01) : true}
						BackgroundTransparency={1}
					>
						{reader}
					</frame>
				)}
			</frame>
		</frame>
	);
}

export = { MailboxView };
