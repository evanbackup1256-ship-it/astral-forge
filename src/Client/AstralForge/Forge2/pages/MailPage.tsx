// Mail, rebuilt on Forge2: letters from config.Mail matched to the player's Mailbox, gifts to
// collect, read-once, archive after collecting, and the session's recent alerts. Same remotes as
// before (ReadMail, ClaimMail, ClaimAllMail, DeleteMail). Phones show the list or one letter; B
// (or the back button) returns from a letter to the list.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { formatReward, Reward } from "../../CoreKit/format";
import * as NoticeMath from "../../CoreKit/noticeMath";
import { useChangePop, useFlash, useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { Card, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { EmptyState } from "../design/Layers";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { useBack } from "../input/input";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

interface MailDef {
	Id: string;
	Subject?: string;
	Sender?: string;
	Preview?: string;
	Date?: string;
	Body?: string[];
	Attachment?: Reward;
}

interface MailState {
	Id: string;
	Read?: boolean;
	Claimed?: boolean;
}

interface Letter {
	id: string;
	subject: string;
	sender: string;
	preview: string;
	date: string;
	body: string[];
	gift?: Reward;
	read: boolean;
	claimed: boolean;
	alert: boolean;
	tone?: string;
}

type Filter = "All" | "Unread" | "Gifts" | "Collected" | "Alerts";
const FILTERS: Filter[] = ["All", "Unread", "Gifts", "Collected", "Alerts"];

function hasGift(reward: Reward | undefined): boolean {
	return reward !== undefined && next(reward)[0] !== undefined;
}

function alertTone(tone: string): Color3 {
	if (tone === "Warning" || tone === "Error") return Iron.ember();
	if (tone === "Success" || tone === "Special") return Iron.brass();
	return Iron.steel();
}

function lettersFrom(session: PageProps["session"], config: PageProps["config"]): Letter[] {
	const defs = new Map<string, MailDef>();
	for (const [, def] of pairs((config.Mail ?? {}) as Record<string, MailDef>)) {
		defs.set(def.Id, def);
	}
	const box = (session as unknown as { Mailbox?: { Messages?: MailState[] } }).Mailbox;
	const out: Letter[] = [];
	for (const mail of box?.Messages ?? []) {
		const def = defs.get(mail.Id);
		if (def === undefined) continue;
		out.push({
			id: def.Id,
			subject: def.Subject ?? "",
			sender: def.Sender ?? "",
			preview: def.Preview ?? "",
			date: def.Date ?? "",
			body: def.Body ?? [],
			gift: hasGift(def.Attachment) ? def.Attachment : undefined,
			read: mail.Read === true,
			claimed: mail.Claimed === true,
			alert: false,
		});
	}
	return out;
}

function alertLetters(): Letter[] {
	return NoticeMath.Entries().map((entry) => ({
		id: entry.Id,
		subject: entry.Count > 1 ? `${entry.Title}  ×${entry.Count}` : entry.Title,
		sender: "",
		preview: entry.Body,
		date: os.date("%H:%M", entry.At),
		body: [entry.Body !== "" ? entry.Body : entry.Title],
		read: true,
		claimed: false,
		alert: true,
		tone: entry.Tone,
	}));
}

function matches(letter: Letter, query: string): boolean {
	if (query === "") return true;
	const hay = `${letter.subject} ${letter.sender} ${letter.body.join(" ")}`.lower();
	return hay.find(query.lower(), 1, true)[0] !== undefined;
}

function Row(props: { letter: Letter; index: number; selected: boolean; phone: boolean; onPick: () => void }) {
	const letter = props.letter;
	const rise = useStagger(props.index);
	const waiting = letter.gift !== undefined && !letter.claimed;
	const accent = letter.alert ? alertTone(letter.tone ?? "") : waiting ? Iron.brass() : letter.read ? Iron.steel() : Iron.ember();
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 10))}>
				<Card accent={accent} selected={props.selected} pad={gap(props.phone, "m")} spacing={4} seam={waiting} onPress={props.onPick}>
					<Text text={letter.subject} size={Type.body(props.phone)} font={letter.read ? Fonts.bold : Fonts.heavy} order={0} />
					{letter.sender !== "" && <Text text={letter.sender} size={Type.small(props.phone)} color={accent} order={1} />}
					<Text text={letter.date !== "" ? `${letter.date}  ${letter.preview}` : letter.preview} size={Type.small(props.phone)} color={Iron.muted()} order={2} />
				</Card>
			</frame>
		</frame>
	);
}

function Reader(props: {
	letter: Letter;
	phone: boolean;
	busy: boolean;
	onClaim: () => void;
	onArchive: () => void;
	onBack?: () => void;
}) {
	const letter = props.letter;
	const [claims, setClaims] = React.useState(0);
	const flash = useFlash(claims, false, 0.42);
	const pop = useChangePop(letter.claimed);
	const waiting = letter.gift !== undefined && !letter.claimed;
	return (
		<Panel pad={gap(props.phone, "l")} spacing={gap(props.phone, "m")} seam={waiting} scale={flash.map((v) => 1 + v * 0.015)}>
			{props.onBack !== undefined && <Button text="Back" tone="quiet" width={96} onPress={props.onBack} order={0} />}
			<Title text={letter.subject} size={Type.title(props.phone)} tags={waiting ? ["wave"] : undefined} order={1} />
			{(letter.sender !== "" || letter.date !== "") && (
				<Text text={[letter.sender, letter.date].filter((part) => part !== "").join("  ·  ")} size={Type.small(props.phone)} color={Iron.muted()} order={2} />
			)}
			{letter.body.map((paragraph, i) => (
				<Text key={`p${i}`} text={paragraph} size={Type.body(props.phone)} color={Iron.soft()} font={Fonts.body} multiline order={3 + i} />
			))}
			{letter.gift !== undefined && (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={100}>
					<uiscale Scale={pop} />
					<Panel pad={gap(props.phone, "m")} spacing={gap(props.phone, "s")} color={Iron.sunk()}>
						<Text text={formatReward(letter.gift)} size={Type.body(props.phone)} font={Fonts.heavy} color={letter.claimed ? Iron.muted() : Iron.brass()} multiline order={0} />
						<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
							<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Button
								text={letter.claimed ? "Collected" : "Collect"}
								disabled={letter.claimed}
								busy={props.busy}
								width={props.phone ? 132 : 170}
								order={0}
								onPress={() => {
									setClaims((n) => n + 1);
									props.onClaim();
								}}
							/>
							<Button text="Archive" tone="iron" disabled={!letter.claimed} width={props.phone ? 112 : 140} order={1} onPress={props.onArchive} />
						</frame>
					</Panel>
				</frame>
			)}
			{letter.gift === undefined && !letter.alert && <Button text="Archive" tone="iron" width={140} order={101} onPress={props.onArchive} />}
		</Panel>
	);
}

export function MailPage(props: PageProps) {
	const phone = props.phone;
	const [filter, setFilter] = React.useState<Filter>("All");
	const [query, setQuery] = React.useState("");
	const [pickedId, setPickedId] = React.useState("");
	const [alertRev, setAlertRev] = React.useState(0);
	const mountedRef = React.useRef(true);
	React.useEffect(() => () => {
		mountedRef.current = false;
	}, []);

	const all = lettersFrom(props.session, props.config);
	let unread = 0;
	let gifts = 0;
	for (const letter of all) {
		if (!letter.read) unread += 1;
		if (letter.gift !== undefined && !letter.claimed) gifts += 1;
	}
	const pool = filter === "Alerts" ? alertLetters() : all;
	const rows = pool.filter((letter) => {
		if (filter === "Unread" && letter.read) return false;
		if (filter === "Gifts" && (letter.gift === undefined || letter.claimed)) return false;
		if (filter === "Collected" && !letter.claimed) return false;
		return matches(letter, query);
	});
	const picked = rows.find((letter) => letter.id === pickedId) ?? (phone ? undefined : rows[0]);
	const reading = phone && picked !== undefined;

	// opening an unread letter marks it read on the server, once
	const pickedKey = picked?.id ?? "";
	const pickedRead = picked?.read ?? true;
	React.useEffect(() => {
		if (picked !== undefined && !picked.alert && !picked.read) props.request("ReadMail", { Id: picked.id });
	}, [pickedKey, pickedRead]);
	React.useEffect(() => {
		if (filter === "Alerts") setAlertRev((n) => n + 1);
	}, [filter]);

	useBack(reading, () => setPickedId(""));

	const choose = (id: string) => {
		if (id !== pickedId) Audio.play("mailRead");
		setPickedId(id);
	};
	const claim = (letter: Letter) => {
		Audio.play("mailClaim");
		Burst.gain(formatReward(letter.gift), Iron.brass(), "Gift.12");
		props.request("ClaimMail", { Id: letter.id }, (reply) => {
			if (reply.ok === true) MotionFX.play("success");
		});
	};
	const claimAll = () => {
		Audio.play("mailClaim");
		Burst.spark(Iron.brass(), 1);
		props.request("ClaimAllMail", {}, (reply) => {
			if (reply.ok === true) MotionFX.play("success");
		});
	};
	const archive = (letter: Letter) => {
		props.request("DeleteMail", { Id: letter.id }, (reply) => {
			if (mountedRef.current && reply.ok === true) setPickedId("");
		});
	};

	const space = gap(phone, "l");
	const headline = unread === 0 && gifts === 0 ? "Mail" : gifts > 0 ? `${gifts} gift${gifts === 1 ? "" : "s"} waiting` : `${unread} unread`;

	const header = (
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} seam={gifts > 0} order={0}>
			<Title text={headline} size={Type.title(phone)} tags={gifts > 0 ? ["wave"] : undefined} order={0} />
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{FILTERS.map((id, i) => (
					<Chip key={id} text={id} on={filter === id} order={i} onPress={() => {
						setFilter(id);
						setPickedId("");
					}} />
				))}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<textbox
					Size={new UDim2(phone ? 1 : 0, phone ? 0 : 260, 0, 44)}
					BackgroundColor3={Iron.sunk()}
					BorderSizePixel={0}
					Text={query}
					PlaceholderText="Search"
					PlaceholderColor3={Iron.muted()}
					TextColor3={Iron.text()}
					FontFace={Fonts.bold}
					TextSize={Type.body(phone)}
					TextXAlignment={Enum.TextXAlignment.Left}
					ClearTextOnFocus={false}
					LayoutOrder={0}
					Change={{ Text: (box) => setQuery(box.Text) }}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				</textbox>
				{gifts > 0 && <Button text={`Collect all (${gifts})`} width={phone ? 180 : 200} order={1} onPress={claimAll} />}
			</frame>
		</Panel>
	);

	const emptyTitle = query !== "" ? "No matches" : filter === "Alerts" ? "No alerts yet" : "Nothing here";
	const list = (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
			<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			{rows.size() === 0 ? (
				<EmptyState title={emptyTitle} body={filter === "Alerts" ? "Pop-ups from this session show up here." : undefined} phone={phone} />
			) : (
				rows.map((letter, i) => (
					<Row key={`${alertRev}-${letter.id}`} letter={letter} index={i} selected={picked?.id === letter.id} phone={phone} onPick={() => choose(letter.id)} />
				))
			)}
		</frame>
	);

	const reader =
		picked !== undefined ? (
			<Reader
				key={picked.id}
				letter={picked}
				phone={phone}
				busy={props.busy.ClaimMail === true || props.busy.ClaimAllMail === true}
				onClaim={() => claim(picked)}
				onArchive={() => archive(picked)}
				onBack={phone ? () => setPickedId("") : undefined}
			/>
		) : undefined;

	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 2)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{reading ? (
				reader
			) : phone ? (
				<>
					{header}
					{list}
				</>
			) : (
				<>
					{header}
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<frame Size={new UDim2(0.4, -space / 2, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
							{list}
						</frame>
						<frame Size={new UDim2(0.6, -space / 2, 0, 0)} Position={new UDim2(0.4, space / 2, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
							{reader}
						</frame>
					</frame>
				</>
			)}
		</scrollingframe>
	);
}
