import React from "@rbxts/react";
import { AdminConfig, BanEntry, fieldsFor, reasonsFor } from "../../CoreKit/adminFields";
import { compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { Palette } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useStagger } from "../../MotionKit/motion";
import { AudioPlayer, BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";

const HttpService = game.GetService("HttpService");
const UserInputService = game.GetService("UserInputService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const { Badge, Button, Dropdown, EmptyState, Panel, SearchField, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");

const GAP = 14;
const HEADER_H = 92;
const PLAYERS_W = 280;
const DETAIL_W = 340;
const CMD_MIN = 360;
const CONSOLE_W = PLAYERS_W + DETAIL_W + CMD_MIN + GAP * 2;
const RECENT_MIN = 200;
const PLAYER_ROW = 56;
const PLAYER_ROW_STRIDE = PLAYER_ROW + 6;
const COMMAND_ROW = 48;
const COMMAND_ROW_STRIDE = COMMAND_ROW + 6;
const SCROLL_BAR = 4;
const OPS_H = 236;
const OPS_LINE = 24;

const ADMIN_CATS = [
	{ id: "All", label: "ALL" },
	{ id: "Economy", label: "ECON" },
	{ id: "Progress", label: "PROG" },
	{ id: "Items", label: "ITEMS" },
	{ id: "Resets", label: "RESET" },
	{ id: "Troll", label: "TROLL" },
	{ id: "Moderation", label: "MOD" },
	{ id: "LiveOps", label: "LIVE" },
];

interface AdminPlayer {
	UserId: number;
	DisplayName: string;
	Name: string;
	Cash?: number;
	Vault?: number;
	Capacity?: number;
	Cores?: number;
	Rebirths?: number;
	Zone?: number;
	Production?: number;
	Stardust?: number;
	Keys?: number;
	Unlimited?: boolean;
}
interface AdminCommand {
	Id: string;
	Label: string;
	Category?: string;
	Danger?: string;
	/** the server needs an Option for this command (a picked choice or typed text) */
	NeedsOption?: boolean;
}
interface AuditRecord {
	Id: string;
	Command: string;
	ActorName: string;
	TargetName: string;
}
interface SecurityRow {
	UserId: number;
	Name: string;
	Flags: number;
	LastKind: string;
	Score: number;
	Level: string;
}
interface HotFlagRow {
	Name: string;
	On: boolean;
	Description: string;
}
interface AnnouncementRow {
	Text: string;
	From: string;
	At: number;
}
interface EconomySummary {
	Players?: number;
	TotalCash?: unknown;
	RichestCash?: unknown;
	MedianProduction?: number;
	MedianRebirths?: number;
	TotalStardust?: number;
	TotalCores?: number;
	TopActions?: Array<{ Action: string; Count: number }>;
}
interface LookupResult {
	UserId: number;
	Name: string;
	Score: number;
	Level: string;
	Revision?: number;
	Flags?: Array<{ At: number; Kind: string; Detail: string }>;
	Journal?: Array<{ Id: string; At: number; Label?: string; Revision?: number }>;
}
interface AdminState {
	SecurityPlayers?: SecurityRow[];
	HotFlags?: HotFlagRow[];
	Announcements?: AnnouncementRow[];
	Economy?: EconomySummary;
	Access?: boolean;
	SelfUserId?: number;
	Online?: AdminPlayer[];
	Commands?: AdminCommand[];
	Recent?: AuditRecord[];
	Banned?: BanEntry[];
	Role?: string;
	Integrity?: { Healthy?: boolean };
	LastAction?: { Message: string; Ok: boolean };
}
interface AdminResponse {
	ok?: boolean;
	message?: string;
	error?: string;
	Preview?: unknown;
	Lookup?: LookupResult;
}
interface AdminProps {
	state: { Admin?: AdminState };
	config?: AdminConfig;
	dispatch: (action: string, payload?: object, callback?: (response: AdminResponse) => void) => unknown;
	reducedMotion?: boolean;
}

function hayHas(hay: string, needle: string) {
	if (needle.size() === 0) {
		return true;
	}
	// exact substrings (player IDs) still match; fuzzy matching adds typos and initials
	if (hay.lower().find(needle.lower(), 1, true)[0] !== undefined) {
		return true;
	}
	return clientModule<BrowseApi>("BrowseKit").matches(needle, hay);
}

function catAccent(category?: string) {
	if (category === "Economy") return Palette.mint;
	if (category === "Progress") return Palette.cyan;
	if (category === "Items") return Palette.violet;
	if (category === "Resets") return Palette.mango;
	if (category === "Troll") return Palette.pink;
	if (category === "Moderation") return Palette.coral;
	return Palette.steel;
}

function commandNeedsArm(entry?: AdminCommand) {
	if (entry === undefined) return true;
	if (entry.Danger === "quick") return false;
	if (entry.Danger === "arm") return true;
	const category = entry.Category ?? "Economy";
	return category === "Troll" || category === "Resets" || category === "Moderation";
}

function SectionTitle(props: { value: string; accent: Color3; position?: UDim2; layoutOrder?: number }) {
	return (
		<Text
			value={props.value}
			size={10}
			color={props.accent}
			weight={Enum.FontWeight.Heavy}
			fit={false}
			position={props.position ?? UDim2.fromOffset(0, 0)}
			sizeConstraint={new UDim2(1, -8, 0, 13)}
			layoutOrder={props.layoutOrder}
		/>
	);
}

function StatCell(props: { label: string; value: string; accent: Color3 }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={props.accent} Thickness={1} Transparency={0.82} />
			<Text
				value={props.label}
				size={9}
				color={Palette.muted}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(8, 6)}
				sizeConstraint={new UDim2(1, -12, 0, 11)}
			/>
			<Text
				value={props.value}
				size={14}
				color={props.accent}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={7}
				position={UDim2.fromOffset(8, 19)}
				sizeConstraint={new UDim2(1, -12, 0, 18)}
			/>
		</frame>
	);
}

interface PlayerRowProps {
	player: AdminPlayer;
	selected: boolean;
	you: boolean;
	onClick: () => void;
	layoutOrder: number;
	reducedMotion?: boolean;
}

function PlayerRow({ player, selected, you, onClick, layoutOrder, reducedMotion }: PlayerRowProps) {
	const accent = selected ? Palette.mint : Palette.lineSoft;
	const reveal = useStagger(layoutOrder, reducedMotion);
	return (
		<textbutton
			LayoutOrder={layoutOrder}
			Size={new UDim2(1, 0, 0, PLAYER_ROW)}
			BackgroundTransparency={reveal.map(
				(amount) => (selected ? 0 : 0.12) + (1 - math.clamp(amount, 0, 1)) * (1 - (selected ? 0 : 0.12)),
			)}
			BackgroundColor3={selected ? Palette.panelRaised : Palette.panel}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play("playerlistSelect");
					onClick();
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={accent} Thickness={1} Transparency={selected ? 0.45 : 1} />
			<frame Size={UDim2.fromOffset(36, 36)} Position={UDim2.fromOffset(12, 10)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<Icon
					kind="Crew.10"
					color={selected ? Palette.mint : Palette.muted}
					accent={Palette.mint}
					size={18}
					spin={false}
					position={UDim2.fromOffset(9, 9)}
				/>
			</frame>
			<Text
				value={player.DisplayName}
				size={13}
				color={you ? Palette.mint : Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(58, 9)}
				sizeConstraint={new UDim2(1, -70, 0, 17)}
			/>
			<Text
				value={`@${player.Name}  ·  ${compactNumber(player.Cash ?? 0)}`}
				size={10}
				color={Palette.cyan}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(58, 28)}
				sizeConstraint={new UDim2(1, -70, 0, 14)}
			/>
			{selected && (
				<frame
					Size={UDim2.fromOffset(8, 8)}
					Position={new UDim2(1, -20, 0.5, -4)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.mint}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
		</textbutton>
	);
}

function CommandRow(props: { entry: AdminCommand; selected: boolean; onClick: () => void; layoutOrder?: number }) {
	const { entry, selected, onClick } = props;
	const accent = catAccent(entry.Category);
	const arm = commandNeedsArm(entry);
	return (
		<textbutton
			Size={new UDim2(1, -4, 0, COMMAND_ROW - 6)}
			BackgroundColor3={selected ? Palette.panelRaised : Palette.panel}
			BackgroundTransparency={selected ? 0 : 0.08}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play("tabSwitch");
					onClick();
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={selected ? accent : Palette.line} Thickness={1} Transparency={selected ? 0.3 : 0.78} />
			<frame Size={new UDim2(0, 4, 1, -14)} Position={UDim2.fromOffset(0, 7)} BackgroundColor3={accent} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<Text
				value={entry.Label}
				size={12}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(15, math.floor((COMMAND_ROW - 22) / 2))}
				sizeConstraint={new UDim2(1, -40, 0, 16)}
			/>
			{/* category reads from the edge bar; dangerous commands get a small lock dot instead of a word */}
			{arm && (
				<frame
					Size={UDim2.fromOffset(6, 6)}
					Position={new UDim2(1, -16, 0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.mango}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
		</textbutton>
	);
}

function AuditLine(props: { record: AuditRecord }) {
	const record = props.record;
	return (
		<frame Size={new UDim2(1, 0, 0, 24)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
			<Text
				value={record.Command}
				size={10}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={8}
				sizeConstraint={new UDim2(0.42, -4, 1, 0)}
			/>
			<Text
				value={`${record.ActorName} → ${record.TargetName}`}
				size={9}
				color={Palette.cyan}
				fit={true}
				minSize={8}
				position={new UDim2(0.42, 4, 0, 0)}
				sizeConstraint={new UDim2(0.58, -4, 1, 0)}
			/>
		</frame>
	);
}

function levelColor(level?: string) {
	if (level === "kick") return Palette.coral;
	if (level === "throttle") return Palette.mango;
	return Palette.muted;
}

function clockTime(at?: number) {
	return at !== undefined ? os.date("%H:%M", at) : "--:--";
}

/** Two-column line in the same shape as AuditLine. */
function OpsLine(props: { left: string; right: string; accent?: Color3; rightColor?: Color3; layoutOrder?: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, OPS_LINE)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={props.layoutOrder}>
			<Text
				value={props.left}
				size={10}
				color={props.accent ?? Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={8}
				sizeConstraint={new UDim2(0.5, -4, 1, 0)}
			/>
			<Text
				value={props.right}
				size={9}
				color={props.rightColor ?? Palette.cyan}
				fit={true}
				minSize={8}
				position={new UDim2(0.5, 4, 0, 0)}
				sizeConstraint={new UDim2(0.5, -4, 1, 0)}
			/>
		</frame>
	);
}

function OpsPanel(props: {
	title: string;
	accent: Color3;
	empty: string;
	layoutOrder: number;
	onBack?: () => void;
	children?: React.Element[];
}) {
	const rows = props.children ?? [];
	return (
		<Panel size={new UDim2(0.25, -GAP * 0.75, 1, 0)} accent={props.accent} background={Palette.panel} padding={12} layoutOrder={props.layoutOrder} clips={false}>
			<SectionTitle value={props.title} accent={props.accent} />
			{props.onBack !== undefined && (
				<Button
					text="BACK"
					onClick={props.onBack}
					color={Palette.panelSoft}
					textColor={props.accent}
					outline={true}
					size={UDim2.fromOffset(56, 18)}
					position={new UDim2(1, -56, 0, -2)}
				/>
			)}
			<frame Size={new UDim2(1, 0, 1, -20)} Position={UDim2.fromOffset(0, 20)} BackgroundTransparency={1} ClipsDescendants={true}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 3)} />
				{rows.size() === 0 ? (
					<Text value={props.empty} size={11} color={Palette.muted} position={UDim2.fromOffset(0, 6)} sizeConstraint={new UDim2(1, 0, 0, 18)} />
				) : (
					rows
				)}
			</frame>
		</Panel>
	);
}

function AdminViewReady({ state, config, dispatch, reducedMotion }: AdminProps) {
	const admin = state.Admin!;
	const antilag = useAntilag();
	const softMotion = reducedMotion;

	const [targetId, setTargetId] = React.useState<number>(
		(admin && admin.SelfUserId) ?? (admin && admin.Online && admin.Online[0] && admin.Online[0].UserId) ?? 0,
	);
	const [command, setCommand] = React.useState<string>(
		(admin && admin.Commands && admin.Commands[0] && admin.Commands[0].Id) ?? "GrantFlux",
	);
	const [category, setCategory] = React.useState("All");
	const [playerQuery, setPlayerQuery] = React.useState("");
	const [commandQuery, setCommandQuery] = React.useState("");
	const [amount, setAmount] = React.useState("1000");
	const [option, setOption] = React.useState("");
	const [reason, setReason] = React.useState(reasonsFor("GrantFlux", "Economy")[0].id);
	const [armed, setArmed] = React.useState(false);
	const [busy, setBusy] = React.useState(false);
	const busyRef = React.useRef(false);
	const [shakeToken, setShakeToken] = React.useState(0);
	const [lastNote, setLastNote] = React.useState((admin && admin.LastAction && admin.LastAction.Message) ?? "");
	const [lastOk, setLastOk] = React.useState<boolean>((admin && admin.LastAction && admin.LastAction.Ok) || true);
	const [previewLines, setPreviewLines] = React.useState<string[]>([]);
	const [lookup, setLookup] = React.useState<LookupResult | undefined>(undefined);
	const mountedRef = React.useRef(true);
	const executeAttempt = React.useRef(0);
	const enter = useEntrance(softMotion);
	const toolsReveal = useStagger(0, softMotion);

	React.useEffect(() => {
		return () => {
			mountedRef.current = false;
			executeAttempt.current += 1;
		};
	}, []);

	React.useEffect(() => {
		if (targetId === 0 && admin && admin.SelfUserId !== undefined) {
			setTargetId(admin.SelfUserId);
		}
	}, [admin && admin.SelfUserId, targetId]);

	React.useEffect(() => {
		const online = (admin && admin.Online) || [];
		if (online.size() === 0) return;
		let found = false;
		for (const p of online) {
			if (p.UserId === targetId) {
				found = true;
				break;
			}
		}
		if (!found) {
			setTargetId((admin && admin.SelfUserId) ?? online[0].UserId);
		}
	}, [admin && admin.Online, admin && admin.SelfUserId, targetId]);

	React.useEffect(() => {
		const commands = (admin && admin.Commands) || [];
		if (commands.size() === 0) return;
		let found = false;
		for (const c of commands) {
			if (c.Id === command) {
				found = true;
				break;
			}
		}
		if (!found) {
			setCommand(commands[0].Id ?? "GrantFlux");
		}
	}, [admin && admin.Commands, command]);

	React.useEffect(() => {
		setArmed(false);
		setPreviewLines([]);
	}, [amount, command, option, reason, targetId]);

	React.useEffect(() => {
		const layout = fieldsFor(command, config, admin && admin.Banned);
		const commands = (admin && admin.Commands) || [];
		let current: AdminCommand | undefined;
		for (const c of commands) {
			if (c.Id === command) {
				current = c;
				break;
			}
		}
		const choices = reasonsFor(command, current && current.Category);
		setAmount(layout.defaultAmount);
		setOption(layout.defaultOption);
		setReason(choices[0] ? choices[0].id : "Owner gameplay administration");
		if (layout.overridesTarget && layout.defaultAmount !== "") {
			const userId = tonumber(layout.defaultAmount);
			if (userId !== undefined) setTargetId(userId);
		}
	}, [command]);

	React.useEffect(() => {
		if (!(admin && admin.LastAction)) return;
		setLastNote(admin.LastAction.Message);
		setLastOk(admin.LastAction.Ok);
	}, [admin && admin.LastAction]);

	const online = admin.Online ?? [];
	const commands = admin.Commands ?? [];
	const shownPlayers = online.filter((p) => hayHas(`${p.DisplayName} ${p.Name} ${p.UserId}`, playerQuery));
	const shownCommands = commands.filter((c) => {
		const catOk = category === "All" || (c.Category ?? "Economy") === category;
		return catOk && hayHas(`${c.Id} ${c.Label} ${c.Category ?? ""}`, commandQuery);
	});
	const recent = admin.Recent ?? [];
	const selected = commands.find((c) => c.Id === command);
	const selectedPlayer = online.find((p) => p.UserId === targetId);
	const fields = fieldsFor(command, config, admin.Banned);
	const needsArm = commandNeedsArm(selected);
	const accent = catAccent(selected && selected.Category);
	const integrity = admin.Integrity;
	const reasonChoices = reasonsFor(command, selected && selected.Category);
	// commands with a free-text option (flag name, journal entry id) get a typed field; the hint comes from the
	// "(Option = ...)" part of the server label
	const typedOption = selected !== undefined && selected.NeedsOption === true && !fields.usesOption;
	const optionHint = (() => {
		const label = selected !== undefined ? selected.Label : "";
		const [hint] = label.match("%(Option = ([^%)]+)%)");
		return typeIs(hint, "string") ? hint : "Option";
	})();
	const optionMissing = selected !== undefined && selected.NeedsOption === true && amount !== "Permanent" && option.gsub("%s", "")[0] === "";
	const fieldSlots = (fields.usesAmount ? 1 : 0) + (fields.usesOption || typedOption ? 1 : 0) + (needsArm ? 1 : 0);

	const send = (dryRun: boolean) => {
		busyRef.current = true;
		setBusy(true);
		const attempt = executeAttempt.current + 1;
		executeAttempt.current = attempt;
		Audio.play(dryRun ? "click" : "adminExecute");
		const sendAmount = amount === "Permanent" ? "1" : amount !== "" ? amount : "1";
		const sendOption = amount === "Permanent" ? "Permanent" : option;
		const sendTarget = fields.overridesTarget ? (tonumber(amount) ?? targetId) : targetId;
		dispatch(
			"AdminExecute",
			{
				TargetUserId: sendTarget,
				Command: command,
				Amount: sendAmount,
				Option: sendOption,
				Reason: reason,
				DryRun: dryRun,
				Nonce: HttpService.GenerateGUID(false),
			},
			(response) => {
				if (!mountedRef.current || executeAttempt.current !== attempt) return;
				busyRef.current = false;
				setBusy(false);
				if (!dryRun) setArmed(false);
				setLastOk(response.ok === true);
				setLastNote(response.ok === true ? (response.message ?? "Done.") : (response.error ?? "Failed."));
				setPreviewLines(dryRun && response.ok === true && typeIs(response.Preview, "table") ? (response.Preview as string[]) : []);
				if (response.ok === true && typeIs(response.Lookup, "table")) setLookup(response.Lookup);
				if (response.ok !== true) {
					setShakeToken((t) => t + 1);
				}
			},
		);
	};

	const execute = () => {
		if (busyRef.current) return;
		if (needsArm && !armed) {
			setArmed(true);
			Audio.play("adminArm");
			return;
		}
		send(false);
	};

	const preview = () => {
		if (busyRef.current) return;
		send(true);
	};

	const runDisabled =
		busy ||
		optionMissing ||
		(fields.overridesTarget ? fields.amountChoices.size() === 0 : targetId === 0) ||
		(needsArm && reason.size() < 3);
	const runLabel = busy ? "APPLYING…" : needsArm && !armed ? "ARM" : "RUN";
	const runColor = busy ? Palette.panelSoft : needsArm && armed ? Palette.coral : needsArm ? Palette.mango : Palette.mint;

	const FIELD_H = 50;
	const EXEC_TITLE = 42;
	const EXEC_BUTTON = 46;
	const EXEC_NOTE = 36 + math.min(previewLines.size(), 6) * 14;
	const executeH = EXEC_TITLE + math.max(0, fieldSlots) * FIELD_H + EXEC_BUTTON + EXEC_NOTE + 20;

	const INSPECT_TITLE = 34;
	const STAT_H = 40;
	const STAT_GAP = 8;
	const inspectH = INSPECT_TITLE + STAT_H * 2 + STAT_GAP + 26;
	const unhealthy = (integrity && integrity.Healthy) === false;

	const header = (
		<Panel
			size={new UDim2(1, 0, 0, HEADER_H)}
			accent={Palette.coral}
			background={Palette.panel}
			padding={12}
			layoutOrder={0}
			reveal={enter}
			reducedMotion={softMotion}
			clips={false}
		>
			<Text
				value="Owner Console"
				size={16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(0, 6)}
				sizeConstraint={new UDim2(1, -340, 0, 22)}
			/>
			<frame Size={new UDim2(1, -120, 0, 22)} Position={UDim2.fromOffset(0, 36)} BackgroundTransparency={1}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					Padding={new UDim(0, 6)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					VerticalAlignment={Enum.VerticalAlignment.Center}
				/>
				<Badge value={admin.Role ?? "ADMIN"} accent={Palette.coral} filled={true} size={UDim2.fromOffset(108, 22)} />
				<Badge
					value={unhealthy ? "RESTORED" : "HEALTHY"}
					accent={unhealthy ? Palette.mango : Palette.mint}
					filled={true}
					size={UDim2.fromOffset(84, 22)}
				/>
				{selectedPlayer && selectedPlayer.Unlimited === true && (
					<Badge value="UNLIMITED" accent={Palette.violet} filled={true} size={UDim2.fromOffset(88, 22)} />
				)}
			</frame>
			<Button
				text="REFRESH"
				onClick={() => {
					dispatch("GetAdminState");
				}}
				color={Palette.panelSoft}
				textColor={Palette.mint}
				outline={true}
				size={UDim2.fromOffset(104, 32)}
				position={new UDim2(1, -104, 0, 3)}
				reducedMotion={softMotion}
			/>
		</Panel>
	);

	const listSize = new UDim2(1, 0, 1, -64);
	const listPos = UDim2.fromOffset(0, 64);
	const playerList =
		shownPlayers.size() === 0 ? (
			<frame Size={listSize} Position={listPos} BackgroundTransparency={1}>
				<Text value="No players match." size={11} color={Palette.muted} />
			</frame>
		) : (
			<FlatList
				data={shownPlayers}
				itemHeight={PLAYER_ROW_STRIDE}
				overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
				canvasTail={4}
				Size={listSize}
				Position={listPos}
				scrollBarColor={Palette.cyan}
				scrollBarThickness={SCROLL_BAR}
				keyExtractor={(player: AdminPlayer) => tostring(player.UserId)}
				renderItem={({ item: player, index }: { item: AdminPlayer; index: number }) => (
					<PlayerRow
						player={player}
						selected={player.UserId === targetId}
						you={player.UserId === admin.SelfUserId}
						onClick={() => setTargetId(player.UserId)}
						layoutOrder={index + 1}
						reducedMotion={softMotion}
					/>
				)}
			/>
		);
	const playerSection = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={12} layoutOrder={1} clips={false}>
			<SectionTitle value="Players" accent={Palette.cyan} />
			<SearchField
				value={playerQuery}
				onChange={setPlayerQuery}
				accent={Palette.cyan}
				placeholder="Search players…"
				size={new UDim2(1, 0, 0, 36)}
				position={UDim2.fromOffset(0, 20)}
				reducedMotion={softMotion}
			/>
			{playerList}
		</Panel>
	);

	const pills = ADMIN_CATS.map((cat) => (
		<Button
			key={cat.id}
			text={cat.label}
			onClick={() => setCategory(cat.id)}
			color={category === cat.id ? Palette.violet : Palette.panelSoft}
			textColor={category === cat.id ? Palette.ink : Palette.creamSoft}
			outline={category !== cat.id}
			highlight={category === cat.id}
			size={UDim2.fromOffset(62, 28)}
			reducedMotion={softMotion}
		/>
	));
	const commandSection = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} background={Palette.panel} padding={12} layoutOrder={2} clips={false}>
			<SectionTitle value="Commands" accent={Palette.violet} />
			<SearchField
				value={commandQuery}
				onChange={setCommandQuery}
				accent={Palette.violet}
				placeholder="Search commands…"
				size={new UDim2(1, 0, 0, 36)}
				position={UDim2.fromOffset(0, 20)}
				reducedMotion={softMotion}
			/>
			<frame Size={new UDim2(1, 0, 0, 30)} Position={UDim2.fromOffset(0, 62)} BackgroundTransparency={1} ClipsDescendants={true}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{pills}
			</frame>
			<frame Size={new UDim2(1, 0, 1, -100)} Position={UDim2.fromOffset(0, 100)} BackgroundTransparency={1}>
				{shownCommands.size() === 0 ? (
					<Text value="Nothing matches that filter." size={11} color={Palette.muted} />
				) : (
					<FlatList
						data={shownCommands}
						itemHeight={COMMAND_ROW_STRIDE}
						overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
						canvasTail={4}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.violet}
						scrollBarThickness={SCROLL_BAR}
						keyExtractor={(entry: AdminCommand) => entry.Id}
						renderItem={({ item: entry, index }: { item: AdminCommand; index: number }) => (
							<CommandRow entry={entry} selected={entry.Id === command} onClick={() => setCommand(entry.Id)} layoutOrder={index + 1} />
						)}
					/>
				)}
			</frame>
		</Panel>
	);

	const inspectSection = (
		<Panel size={new UDim2(1, 0, 0, inspectH)} accent={Palette.mint} background={Palette.panel} padding={12} layoutOrder={0} clips={false}>
			<SectionTitle value="Target" accent={Palette.mint} />
			<Text
				value={selectedPlayer ? `${selectedPlayer.DisplayName}  ·  ${selectedPlayer.UserId}` : "Select a player."}
				size={12}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 15)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<frame Size={new UDim2(1, 0, 0, STAT_H * 2 + STAT_GAP)} Position={UDim2.fromOffset(0, INSPECT_TITLE)} BackgroundTransparency={1}>
				<uigridlayout
					CellSize={new UDim2(0.25, -6, 0, STAT_H)}
					CellPadding={UDim2.fromOffset(STAT_GAP, STAT_GAP)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					FillDirection={Enum.FillDirection.Horizontal}
				/>
				<StatCell label="CASH" value={selectedPlayer ? compactNumber(selectedPlayer.Cash ?? 0) : "--"} accent={Palette.cyan} />
				<StatCell
					label="VAULT"
					value={selectedPlayer ? `${compactNumber(selectedPlayer.Vault ?? 0)}/${compactNumber(selectedPlayer.Capacity ?? 0)}` : "--"}
					accent={Palette.mint}
				/>
				<StatCell label="CORES" value={selectedPlayer ? compactNumber(selectedPlayer.Cores ?? 0) : "--"} accent={Palette.violet} />
				<StatCell label="REBIRTHS" value={selectedPlayer ? compactNumber(selectedPlayer.Rebirths ?? 0) : "--"} accent={Palette.pink} />
				<StatCell label="WORLD" value={selectedPlayer ? tostring(selectedPlayer.Zone ?? 1) : "--"} accent={Palette.mango} />
				<StatCell label="RATE" value={selectedPlayer ? `${compactNumber(selectedPlayer.Production ?? 0)}/s` : "--"} accent={Palette.cyan} />
				<StatCell label="DUST" value={selectedPlayer ? compactNumber(selectedPlayer.Stardust ?? 0) : "--"} accent={Palette.steel} />
				<StatCell label="KEYS" value={selectedPlayer ? compactNumber(selectedPlayer.Keys ?? 0) : "--"} accent={Palette.violet} />
			</frame>
		</Panel>
	);

	const executeActionsHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = executeActionsHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [command, armed, busy, targetId]);

	const shownPreview: string[] = [];
	for (let i = 0; i < math.min(previewLines.size(), 6); i++) {
		shownPreview.push(previewLines[i]);
	}
	const executeDock = (
		<Panel
			size={new UDim2(1, 0, 0, executeH)}
			accent={armed ? Palette.coral : accent}
			background={Palette.panelRaised}
			padding={12}
			layoutOrder={1}
			highlight={armed}
			reveal={toolsReveal}
			reducedMotion={softMotion}
			clips={false}
		>
			<SectionTitle value={needsArm ? "OFF" : "READY"} accent={armed ? Palette.coral : accent} />
			<Text
				value={(selected && selected.Label) ?? command}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 15)}
				sizeConstraint={new UDim2(1, 0, 0, 20)}
			/>
			<frame
				Size={new UDim2(1, 0, 0, math.max(0, fieldSlots * FIELD_H - 6))}
				Position={UDim2.fromOffset(0, EXEC_TITLE)}
				BackgroundTransparency={1}
				ZIndex={50}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
				{fields.usesAmount && (
					<frame Size={new UDim2(1, 0, 0, FIELD_H - 6)} BackgroundTransparency={1} LayoutOrder={0} ZIndex={52}>
						<Dropdown
							options={fields.amountChoices}
							value={amount}
							onChange={(id: string) => {
								setAmount(id);
								if (fields.overridesTarget) {
									const uid = tonumber(id);
									if (uid !== undefined) setTargetId(uid);
								}
							}}
							accent={Palette.mango}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={softMotion}
							zIndex={80}
						/>
					</frame>
				)}
				{fields.usesOption && (
					<frame Size={new UDim2(1, 0, 0, FIELD_H - 6)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={51}>
						<Dropdown
							options={fields.optionChoices}
							value={option}
							onChange={setOption}
							accent={Palette.cyan}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={softMotion}
							zIndex={70}
						/>
					</frame>
				)}
				{typedOption && (
					<frame Size={new UDim2(1, 0, 0, FIELD_H - 6)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={51}>
						<SearchField
							value={option}
							onChange={setOption}
							debounce={0}
							accent={optionMissing ? Palette.coral : Palette.cyan}
							placeholder={`Needed: ${optionHint}`}
							hint={optionMissing ? "Required" : undefined}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={softMotion}
						/>
					</frame>
				)}
				{needsArm && (
					<frame Size={new UDim2(1, 0, 0, FIELD_H - 6)} BackgroundTransparency={1} LayoutOrder={2} ZIndex={50}>
						<Dropdown
							options={reasonChoices}
							value={reason}
							onChange={setReason}
							accent={Palette.steel}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={softMotion}
							zIndex={60}
						/>
					</frame>
				)}
			</frame>
			<frame
				key="AdminExecuteActions"
				Size={new UDim2(1, 0, 0, EXEC_BUTTON)}
				Position={UDim2.fromOffset(0, EXEC_TITLE + fieldSlots * FIELD_H)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ref={executeActionsHostRef}
			>
				<frame key="AdminPreviewRun" Size={new UDim2(0.34, -5, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<Button
						text="PREVIEW"
						icon="Search.8"
						onClick={preview}
						color={Palette.panelSoft}
						textColor={Palette.text}
						size={new UDim2(1, 0, 0, 48)}
						position={new UDim2(0, 0, 0.5, -24)}
						disabled={runDisabled}
						reducedMotion={softMotion}
					/>
				</frame>
				<frame
					key="AdminConfirmRun"
					ClipsDescendants={false}
					Size={new UDim2(0.66, -5, 1, 0)}
					Position={UDim2.fromScale(0.34, 0).add(UDim2.fromOffset(5, 0))}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<Button
						text={runLabel}
						icon="Lock.16"
						onClick={execute}
						color={runColor}
						textColor={Palette.ink}
						size={new UDim2(1, 0, 0, 48)}
						position={new UDim2(0, 0, 0.5, -24)}
						disabled={runDisabled}
						loading={busy}
						shakeToken={shakeToken}
						highlight={armed || !needsArm}
						reducedMotion={softMotion}
					/>
				</frame>
			</frame>
			<Text
				value={
					(optionMissing
						? `Fill in ${optionHint} above before you run this.`
						: lastNote !== ""
						? lastNote
						: needsArm
							? "Tap twice to run."
							: "Preview, then run.") +
					(previewLines.size() > 0 ? "\n• " + shownPreview.join("\n• ") : "")
				}
				size={9}
				color={optionMissing ? Palette.coral : lastNote !== "" ? (lastOk ? Palette.mint : Palette.coral) : Palette.muted}
				wrap={true}
				fit={true} minSize={9}
				position={new UDim2(0, 0, 1, -EXEC_NOTE + 4)}
				sizeConstraint={new UDim2(1, 0, 0, EXEC_NOTE - 4)}
			/>
		</Panel>
	);

	const auditRows: React.Element[] = [];
	for (let i = 0; i < math.min(6, recent.size()); i++) {
		auditRows.push(<AuditLine key={recent[i].Id} record={recent[i]} />);
	}
	const recentSection = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.steel} background={Palette.panel} padding={12} layoutOrder={2} clips={false}>
			<SectionTitle value="Recent" accent={Palette.steel} />
			<frame Size={new UDim2(1, 0, 1, -20)} Position={UDim2.fromOffset(0, 20)} BackgroundTransparency={1} ClipsDescendants={true}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 3)} />
				{recent.size() === 0 ? (
					<Text
						value="No commands run yet."
						size={11}
						color={Palette.muted}
						position={UDim2.fromOffset(0, 6)}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
				) : (
					auditRows
				)}
			</frame>
		</Panel>
	);

	const MAX_OPS_ROWS = 7;
	const securityRows: React.Element[] = [];
	if (lookup !== undefined) {
		securityRows.push(
			<OpsLine key="lookup" left={`${lookup.Name} · ${lookup.Score}`} right={`${string.upper(lookup.Level)} · rev ${lookup.Revision ?? 0}`} accent={Palette.mint} rightColor={levelColor(lookup.Level)} layoutOrder={0} />,
		);
		const flags = lookup.Flags ?? [];
		for (let i = 0; i < math.min(3, flags.size()); i++) {
			securityRows.push(<OpsLine key={`lf${i}`} left={flags[i].Kind} right={`${clockTime(flags[i].At)} ${flags[i].Detail}`} rightColor={Palette.muted} layoutOrder={1 + i} />);
		}
		const journal = lookup.Journal ?? [];
		for (let i = 0; i < math.min(MAX_OPS_ROWS - securityRows.size(), journal.size()); i++) {
			securityRows.push(<OpsLine key={`lj${i}`} left={journal[i].Label ?? "Snapshot"} right={`${clockTime(journal[i].At)} · ${journal[i].Id}`} accent={Palette.steel} rightColor={Palette.muted} layoutOrder={10 + i} />);
		}
	} else {
		const flagged = admin.SecurityPlayers ?? [];
		for (let i = 0; i < math.min(MAX_OPS_ROWS, flagged.size()); i++) {
			const row = flagged[i];
			securityRows.push(
				<OpsLine key={tostring(row.UserId)} left={`${row.Name} · ${row.Score}`} right={`${row.Flags}× ${row.LastKind}`} rightColor={levelColor(row.Level)} layoutOrder={i} />,
			);
		}
	}
	const flagRows = (admin.HotFlags ?? []).map((flag, i) => (
		<OpsLine key={flag.Name} left={flag.Name} right={flag.On ? "ON" : "off"} accent={flag.On ? Palette.coral : Palette.cream} rightColor={flag.On ? Palette.coral : Palette.muted} layoutOrder={i} />
	));
	const announcementRows: React.Element[] = [];
	const announcements = admin.Announcements ?? [];
	for (let i = 0; i < math.min(MAX_OPS_ROWS, announcements.size()); i++) {
		const a = announcements[i];
		announcementRows.push(<OpsLine key={`${a.At}${i}`} left={a.Text} right={`${clockTime(a.At)} ${a.From}`} layoutOrder={i} />);
	}
	const economy = admin.Economy;
	const economyRows: React.Element[] = [];
	if (economy !== undefined) {
		economyRows.push(<OpsLine key="p" left="Players" right={tostring(economy.Players ?? 0)} layoutOrder={0} />);
		economyRows.push(<OpsLine key="c" left="Total Flux" right={compactNumber(economy.TotalCash ?? 0)} layoutOrder={1} />);
		economyRows.push(<OpsLine key="r" left="Richest" right={compactNumber(economy.RichestCash ?? 0)} layoutOrder={2} />);
		economyRows.push(<OpsLine key="m" left="Median rate" right={`${compactNumber(economy.MedianProduction ?? 0)}/s`} layoutOrder={3} />);
		economyRows.push(<OpsLine key="b" left="Median rebirths" right={compactNumber(economy.MedianRebirths ?? 0)} layoutOrder={4} />);
		const top = economy.TopActions ?? [];
		for (let i = 0; i < math.min(2, top.size()); i++) {
			economyRows.push(<OpsLine key={`t${i}`} left={top[i].Action} right={compactNumber(top[i].Count)} accent={Palette.steel} rightColor={Palette.muted} layoutOrder={5 + i} />);
		}
	}
	const opsRow = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uisizeconstraint MinSize={new Vector2(CONSOLE_W, OPS_H)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
			<OpsPanel title={lookup !== undefined ? "LOOKUP" : "SECURITY"} accent={Palette.coral}
				empty="No flagged players."
				layoutOrder={1}
				onBack={lookup !== undefined ? () => setLookup(undefined) : undefined}
			>
				{securityRows}
			</OpsPanel>
			<OpsPanel title="Live flags" accent={Palette.mango} empty="No flags." layoutOrder={2}>
				{flagRows}
			</OpsPanel>
			<OpsPanel title="Announcements" accent={Palette.violet} empty="Nothing announced yet." layoutOrder={3}>
				{announcementRows}
			</OpsPanel>
			<OpsPanel title="Economy" accent={Palette.cyan} empty="No live profiles." layoutOrder={4}>
				{economyRows}
			</OpsPanel>
		</frame>
	);

	const BODY_H = inspectH + GAP + executeH + GAP + RECENT_MIN;
	const consoleBody = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<uisizeconstraint MinSize={new Vector2(CONSOLE_W, BODY_H)} />
			<frame Size={new UDim2(0, PLAYERS_W, 1, 0)} BackgroundTransparency={1}>
				{playerSection}
			</frame>
			<frame Size={new UDim2(0, DETAIL_W, 1, 0)} Position={new UDim2(1, -DETAIL_W, 0, 0)} BackgroundTransparency={1}>
				<frame Size={new UDim2(1, 0, 0, inspectH)} BackgroundTransparency={1}>
					{inspectSection}
				</frame>
				<frame Size={new UDim2(1, 0, 0, executeH)} Position={UDim2.fromOffset(0, inspectH + GAP)} BackgroundTransparency={1}>
					{executeDock}
				</frame>
				<frame
					Size={new UDim2(1, 0, 1, -(inspectH + executeH + GAP * 2))}
					Position={UDim2.fromOffset(0, inspectH + executeH + GAP * 2)}
					BackgroundTransparency={1}
					ClipsDescendants={true}
				>
					<uisizeconstraint MinSize={new Vector2(0, RECENT_MIN)} />
					{recentSection}
				</frame>
			</frame>
			<frame
				Size={new UDim2(1, -(PLAYERS_W + DETAIL_W + GAP * 2), 1, 0)}
				Position={UDim2.fromOffset(PLAYERS_W + GAP, 0)}
				BackgroundTransparency={1}
			>
				{commandSection}
			</frame>
		</frame>
	);

	return (
		<PageScaffold
			gap={GAP}
			tailPad={8}
			scrollBarColor={Palette.steel}
			scrollBarThickness={4}
			sections={[
				{ id: "header", height: HEADER_H, element: header },
				{ id: "console", fill: true, minHeight: BODY_H, element: consoleBody },
				{ id: "ops", height: OPS_H, element: opsRow },
			]}
		/>
	);
}

export function AdminView(props: AdminProps) {
	const admin = props.state.Admin;
	if (!(admin && admin.Access === true)) {
		return (
			<EmptyState icon="Lock.17" title="Owner tools locked" body="Only the game owner can open this page." accent={Palette.coral} />
		);
	}
	return <AdminViewReady {...props} />;
}
