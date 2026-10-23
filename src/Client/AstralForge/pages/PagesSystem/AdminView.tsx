import React from "@rbxts/react";
import { AdminConfig, BanEntry, fieldsFor, reasonsFor } from "../../CoreKit/adminFields";
import { compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { Palette } from "../../CoreKit/theme";
import { BODY, BODY_BOLD, BODY_SEMI, Line, NUM, PnSurface, RowSurface, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useStagger, useViewport } from "../../MotionKit/motion";
import { chromeFor } from "../../CoreKit/theme";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { named } from "../luauDeps";
import { AudioPlayer, BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import { Slot } from "../mockLayout";

const HttpService = game.GetService("HttpService");
const UserInputService = game.GetService("UserInputService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const { Badge, Button, Dropdown, EmptyState, SearchField, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");

const GAP = 14;
const HEADER_H = 92;
const PLAYERS_W = 280;
const DETAIL_W = 340;
const CMD_MIN = 360;
const CONSOLE_W = PLAYERS_W + DETAIL_W + CMD_MIN + GAP * 2;
// Recent shows its last 6 runs, sized to fit them (no inner scroller): pad, title, 6 × 24 rows
const RECENT_MIN = 12 * 2 + 16 + 8 + 6 * 24 + 5 * 8;
const PLAYER_ROW = 56;
const PLAYER_ROW_STRIDE = PLAYER_ROW + 6;
const COMMAND_ROW = 48;
const COMMAND_ROW_STRIDE = COMMAND_ROW + 6;
const SCROLL_BAR = 4;
// title, seven 34 px rows on a 3 px gap, panel padding
// design/22: .row height; ops panels are sized for OPS_ROWS rows (lists are capped there, no inner scroller)
const OPS_LINE = 48;
const OPS_GAP = 8;
const OPS_ROWS = 7;
const OPS_H = 12 * 2 + 18 + 8 + OPS_ROWS * OPS_LINE + (OPS_ROWS - 1) * OPS_GAP;
const NARROW_PLAYERS_H = 360;
const NARROW_COMMANDS_H = 440;

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
interface SecurityFlagRow {
	At: number;
	Name: string;
	Kind: string;
	Detail?: string;
	Response?: string;
}
interface AntiCheatRuleRow {
	Id: string;
	Repairs: number;
}
interface AdminState {
	SecurityPlayers?: SecurityRow[];
	SecurityFlags?: SecurityFlagRow[];
	AntiCheatRules?: AntiCheatRuleRow[];
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

/** .pn h3 (design/22): accent glyph dot, Cinzel caps with letter spacing, cream. */
function SectionTitle(props: { value: string; accent: Color3; position?: UDim2; layoutOrder?: number }) {
	return (
		<frame Size={new UDim2(1, -8, 0, 16)} Position={props.position ?? UDim2.fromOffset(0, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={UDim2.fromOffset(6, 6)} Rotation={45} BackgroundColor3={props.accent} BorderSizePixel={0} LayoutOrder={0} />
			<Line text={spaced(string.upper(props.value))} size={12} font={TITLE_FACE} color={Palette.cream} height={16} layoutOrder={1} />
		</frame>
	);
}

function StatCell(props: { label: string; value: string; accent: Color3; layoutOrder?: number }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={props.layoutOrder ?? 0}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={props.accent} Thickness={1} Transparency={0.82} />
			<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 4)} PaddingTop={new UDim(0, 6)} />
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
			<Slot height={11} layoutOrder={0}>
				<Text value={props.label} size={11} color={Palette.muted} weight={Enum.FontWeight.Heavy} fit={false} sizeConstraint={new UDim2(1, 0, 0, 11)} />
			</Slot>
			<Slot height={18} layoutOrder={1}>
				<Text value={props.value} size={14} color={props.accent} weight={Enum.FontWeight.Heavy} fit={true} minSize={7} sizeConstraint={new UDim2(1, 0, 0, 18)} />
			</Slot>
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
			{/* .row: [avatar well | name / handle (fills) | selected dot], one horizontal list */}
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 16)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
			<frame key="Avatar" Size={UDim2.fromOffset(36, 36)} BackgroundColor3={Palette.ink} BorderSizePixel={0} LayoutOrder={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<Icon kind="Crew.10" color={selected ? Palette.mint : Palette.muted} accent={Palette.mint} size={18} spin={false} position={UDim2.fromOffset(9, 9)} />
			</frame>
			<frame key="Copy" Size={new UDim2(0, 0, 0, 33)} BackgroundTransparency={1} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
				<Slot height={17} layoutOrder={0}>
					<Text value={player.DisplayName} size={13} color={you ? Palette.mint : Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 17)} />
				</Slot>
				<Slot height={14} layoutOrder={1}>
					<Text value={`@${player.Name}  ·  ${compactNumber(player.Cash ?? 0)}`} size={11} color={Palette.cyan} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				</Slot>
			</frame>
			<frame key="Dot" Size={UDim2.fromOffset(8, 8)} BackgroundColor3={Palette.mint} BackgroundTransparency={selected ? 0 : 1} BorderSizePixel={0} LayoutOrder={2}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
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
			{/* [category edge bar | label (fills) | arm dot], one horizontal list */}
			<uipadding PaddingRight={new UDim(0, 13)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 11)} />
			<frame key="Edge" Size={new UDim2(0, 4, 1, -14)} BackgroundColor3={accent} BorderSizePixel={0} LayoutOrder={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame key="Label" Size={new UDim2(0, 0, 0, 16)} BackgroundTransparency={1} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<Text value={entry.Label} size={12} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			</frame>
			{/* category reads from the edge bar; dangerous commands get a small lock dot instead of a word */}
			<frame key="Arm" Size={UDim2.fromOffset(6, 6)} BackgroundColor3={Palette.mango} BackgroundTransparency={arm ? 0 : 1} BorderSizePixel={0} LayoutOrder={2}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</textbutton>
	);
}

function AuditLine(props: { record: AuditRecord; layoutOrder?: number }) {
	const record = props.record;
	return (
		<frame Size={new UDim2(1, 0, 0, 24)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={props.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
			<frame Size={new UDim2(0.42, -4, 1, 0)} BackgroundTransparency={1} LayoutOrder={0}>
				<Text value={record.Command} size={11} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={UDim2.fromScale(1, 1)} />
			</frame>
			<frame Size={new UDim2(0.58, -4, 1, 0)} BackgroundTransparency={1} LayoutOrder={1}>
				<Text value={`${record.ActorName} to ${record.TargetName}`} size={11} color={Palette.cyan} fit={true} minSize={11} sizeConstraint={UDim2.fromScale(1, 1)} />
			</frame>
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

/** One ops row: optional kind chip, the name (with an optional second line), the value on the right. */
function OpsLine(props: { left: string; right: string; chip?: string; sub?: string; accent?: Color3; rightColor?: Color3; layoutOrder?: number }) {
	// design/22-admin row: coral kind chip, two-line text, right value (num, accent)
	const chipW = props.chip !== undefined ? math.clamp(props.chip.size() * 6 + 18, 44, 96) : 0;
	return (
		<frame Size={new UDim2(1, 0, 0, OPS_LINE)} BackgroundColor3={Palette.white} BackgroundTransparency={0} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={props.layoutOrder}>
			<RowSurface />
			{/* design/22 .row: [kind chip] [name / sub (fills)] [value], one horizontal list */}
			<frame key="Cells" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
				<uipadding PaddingLeft={new UDim(0, props.chip !== undefined ? 8 : 12)} PaddingRight={new UDim(0, 12)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				{props.chip !== undefined && (
					<frame key="Chip" Size={UDim2.fromOffset(chipW, 22)} BackgroundColor3={Palette.coral} BackgroundTransparency={0.82} BorderSizePixel={0} LayoutOrder={0}>
						<uicorner CornerRadius={new UDim(0, 8)} />
						<uistroke Color={Palette.coral} Transparency={0.45} Thickness={1} />
						<textlabel Text={props.chip} FontFace={BODY_BOLD} TextSize={11} TextColor3={Palette.coral} BackgroundTransparency={1} TextScaled={false} TextTruncate={Enum.TextTruncate.AtEnd} Size={UDim2.fromScale(1, 1)} />
					</frame>
				)}
				<frame key="Copy" Size={new UDim2(0, 0, 0, props.sub !== undefined ? 34 : 16)} BackgroundTransparency={1} LayoutOrder={1}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
					<textlabel
						Text={props.left}
						FontFace={BODY_SEMI}
						TextSize={15}
						TextColor3={props.accent ?? Palette.cream}
						BackgroundTransparency={1}
						TextXAlignment={Enum.TextXAlignment.Left}
						TextTruncate={Enum.TextTruncate.AtEnd}
						Size={new UDim2(1, 0, 0, 16)}
						LayoutOrder={0}
					/>
					{props.sub !== undefined && (
						<textlabel Text={props.sub} FontFace={BODY} TextSize={11} TextColor3={Palette.muted} BackgroundTransparency={1} TextXAlignment={Enum.TextXAlignment.Left} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, 14)} LayoutOrder={1} />
					)}
				</frame>
				<textlabel
					key="Value"
					Text={props.right}
					FontFace={NUM}
					TextSize={14}
					TextColor3={props.rightColor ?? Palette.mango}
					BackgroundTransparency={1}
					TextXAlignment={Enum.TextXAlignment.Right}
					TextTruncate={Enum.TextTruncate.AtEnd}
					Size={new UDim2(0.38, -12, 0, 18)}
					LayoutOrder={2}
				/>
			</frame>
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
	size?: UDim2;
}) {
	const rows = props.children ?? [];
	return (
		<PnSurface size={props.size ?? new UDim2(0.25, -GAP * 0.75, 1, 0)} accent={props.accent} background={Palette.panel} padding={12} layoutOrder={props.layoutOrder} clips={false}>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
			<frame key="Heading" Size={new UDim2(1, 0, 0, 18)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0} ClipsDescendants={false}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<frame Size={new UDim2(0, 0, 0, 16)} BackgroundTransparency={1} LayoutOrder={0}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<SectionTitle value={string.upper(props.title)} accent={Palette.brass} />
				</frame>
				{props.onBack !== undefined && (
					<frame key="Back" Size={UDim2.fromOffset(56, 18)} BackgroundTransparency={1} LayoutOrder={1} ClipsDescendants={false}>
						<Button text="BACK" onClick={props.onBack} color={Palette.panelSoft} textColor={props.accent} outline={true} size={UDim2.fromScale(1, 1)} />
						{/* 44px tap area round the 18px chip; not selectable so the pad lands on the button */}
						<textbutton
							Size={UDim2.fromOffset(64, 44)}
							Position={UDim2.fromScale(0.5, 0.5)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundTransparency={1}
							Text=""
							Selectable={false}
							AutoButtonColor={false}
							ZIndex={8}
							Event={{ Activated: props.onBack }}
						/>
					</frame>
				)}
			</frame>
			{/* rows are capped at MAX_OPS_ROWS and the panel is sized for them: no inner scroller */}
			<frame key="Rows" Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, OPS_GAP)} />
				{rows.size() === 0 ? (
					<Text value={props.empty} size={11} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 18)} />
				) : (
					rows
				)}
			</frame>
		</PnSurface>
	);
}

function AdminViewReady({ state, config, dispatch, reducedMotion }: AdminProps) {
	const admin = state.Admin!;
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	// below the three-column console width (phones, narrow windows) every block gets its own full-width row
	const viewport = useViewport();
	const narrow = chromeFor(viewport).contentStack || viewport.width < CONSOLE_W + 240;
	// phone widths (down to 286px): smaller header badges, two stats per row
	const tight = narrow && viewport.width < 480;

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
	const runLabel = busy ? "APPLYING" : needsArm && !armed ? "ARM" : "RUN";
	const runColor = busy ? Palette.panelSoft : needsArm && armed ? Palette.coral : needsArm ? Palette.mango : Palette.mint;

	const FIELD_H = 50;
	const EXEC_TITLE = 42;
	const EXEC_BUTTON = 46;
	const EXEC_NOTE = 36 + math.min(previewLines.size(), 6) * 14;
	const executeH = EXEC_TITLE + math.max(0, fieldSlots) * FIELD_H + EXEC_BUTTON + EXEC_NOTE + 20;

	const INSPECT_TITLE = 34;
	const STAT_H = 40;
	const STAT_GAP = 8;
	// phones: the eight target stats go two per row (four rows) instead of four per row
	const statCols = tight ? 2 : 4;
	const statRows = math.ceil(8 / statCols);
	const inspectH = INSPECT_TITLE + STAT_H * statRows + STAT_GAP * (statRows - 1) + 26;
	const unhealthy = (integrity && integrity.Healthy) === false;

	const refreshW = tight ? 88 : 104;
	const header = (
		<PnSurface
			size={new UDim2(1, 0, 0, HEADER_H)}
			accent={Palette.brass}
			background={Palette.panel}
			padding={12}
			layoutOrder={0}
			reveal={enter}
			reducedMotion={softMotion}
			clips={false}
		>
			{/* design/22 header: title + badges column (fills) | refresh, one horizontal list */}
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
			<frame key="Titles" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} LayoutOrder={0}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<Line text={spaced("ADMIN")} size={20} font={TITLE_FACE} color={Palette.cream} width={new UDim(1, 0)} height={22} layoutOrder={0} />
					<frame Size={new UDim2(1, 0, 0, 22)} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout
							FillDirection={Enum.FillDirection.Horizontal}
							Padding={new UDim(0, 6)}
							SortOrder={Enum.SortOrder.LayoutOrder}
							VerticalAlignment={Enum.VerticalAlignment.Center}
						/>
						<Badge value={admin.Role ?? "ADMIN"} accent={Palette.coral} filled={true} size={UDim2.fromOffset(tight ? 88 : 108, 22)} />
						<Badge
							value={unhealthy ? "RESTORED" : "HEALTHY"}
							accent={unhealthy ? Palette.mango : Palette.mint}
							filled={true}
							size={UDim2.fromOffset(tight ? 76 : 84, 22)}
						/>
						{selectedPlayer && selectedPlayer.Unlimited === true && (
							<frame Size={UDim2.fromOffset(88, 22)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
								{/* last in the row: on narrow phones it gives up width instead of running past the edge */}
								<uiflexitem FlexMode={Enum.UIFlexMode.Shrink} />
								<Badge value="UNLIMITED" accent={Palette.violet} filled={true} size={UDim2.fromScale(1, 1)} />
							</frame>
						)}
					</frame>
			</frame>
			{/* 44px hit area round the 32px button: the button keeps its look, the frame takes the tap */}
			<frame key="Refresh" Size={UDim2.fromOffset(refreshW, 44)} BackgroundTransparency={1} LayoutOrder={1}>
				<textbutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text=""
					AutoButtonColor={false}
					Selectable={false}
					Event={{ Activated: () => dispatch("GetAdminState") }}
				/>
				<Button
					text="REFRESH"
					onClick={() => {
						dispatch("GetAdminState");
					}}
					color={Palette.panelSoft}
					textColor={Palette.mint}
					outline={true}
					size={UDim2.fromOffset(refreshW, 32)}
					position={UDim2.fromOffset(0, 6)}
					reducedMotion={softMotion}
				/>
			</frame>
		</PnSurface>
	);

	const listSize = UDim2.fromScale(1, 1);
	const playerList =
		shownPlayers.size() === 0 ? (
			<frame Size={listSize} BackgroundTransparency={1}>
				<EmptyState icon="Search" title="No players match" body="" compact={true} />
			</frame>
		) : (
			<FlatList
				data={shownPlayers}
				itemHeight={PLAYER_ROW_STRIDE}
				overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
				canvasTail={4}
				Size={listSize}
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
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={12} layoutOrder={1} clips={false}>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
			<SectionTitle value="Players" accent={Palette.cyan} layoutOrder={0} />
			<Slot height={36} layoutOrder={1}>
				<SearchField value={playerQuery} onChange={setPlayerQuery} accent={Palette.cyan} placeholder="Search players" size={new UDim2(1, 0, 0, 36)} reducedMotion={softMotion} />
			</Slot>
			{/* the list takes the rest of the column (its own virtualised scroller) */}
			<frame key="List" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				{playerList}
			</frame>
		</PnSurface>
	);

	const commandSection = (
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.violet} background={Palette.panel} padding={12} layoutOrder={2} clips={false}>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
			<SectionTitle value="Commands" accent={Palette.violet} layoutOrder={0} />
			<Slot height={36} layoutOrder={1}>
				<SearchField value={commandQuery} onChange={setCommandQuery} accent={Palette.violet} placeholder="Search commands" size={new UDim2(1, 0, 0, 36)} reducedMotion={softMotion} />
			</Slot>
			{/* category tabs per admin mockup: one SegmentedTabs row, 34px tall, 5px between tabs */}
			<Slot height={34} layoutOrder={2}>
				<SegmentedTabs
					options={ADMIN_CATS}
					value={category}
					accent={Palette.violet}
					gap={5}
					size={new UDim2(1, 0, 0, 34)}
					reducedMotion={softMotion}
					onChange={(id: string) => setCategory(id)}
				/>
			</Slot>
			<frame key="List" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} LayoutOrder={3}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				{shownCommands.size() === 0 ? (
					<EmptyState icon="Command" title="No commands" body="" compact={true} />
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
		</PnSurface>
	);

	const inspectSection = (
		<PnSurface size={new UDim2(1, 0, 0, inspectH)} accent={Palette.mint} background={Palette.panel} padding={12} layoutOrder={0} clips={false}>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 1)} />
			<SectionTitle value="Target" accent={Palette.mint} layoutOrder={0} />
			<Slot height={INSPECT_TITLE - 18} layoutOrder={1}>
				<Text
					value={selectedPlayer ? `${selectedPlayer.DisplayName}  ·  ${selectedPlayer.UserId}` : "Select a player."}
					size={12}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
				/>
			</Slot>
			<frame key="Stats" Size={new UDim2(1, 0, 0, STAT_H * statRows + STAT_GAP * (statRows - 1))} BackgroundTransparency={1} LayoutOrder={2}>
				<uigridlayout
					CellSize={new UDim2(1 / statCols, -math.ceil((STAT_GAP * (statCols - 1)) / statCols), 0, STAT_H)}
					CellPadding={UDim2.fromOffset(STAT_GAP, STAT_GAP)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					FillDirection={Enum.FillDirection.Horizontal}
				/>
				<StatCell layoutOrder={1} label="CASH" value={selectedPlayer ? compactNumber(selectedPlayer.Cash ?? 0) : "--"} accent={Palette.cyan} />
				<StatCell layoutOrder={2}
					label="VAULT"
					value={selectedPlayer ? `${compactNumber(selectedPlayer.Vault ?? 0)}/${compactNumber(selectedPlayer.Capacity ?? 0)}` : "--"}
					accent={Palette.mint}
				/>
				<StatCell layoutOrder={3} label="CORES" value={selectedPlayer ? compactNumber(selectedPlayer.Cores ?? 0) : "--"} accent={Palette.violet} />
				<StatCell layoutOrder={4} label="REBIRTHS" value={selectedPlayer ? compactNumber(selectedPlayer.Rebirths ?? 0) : "--"} accent={Palette.pink} />
				<StatCell layoutOrder={5} label="WORLD" value={selectedPlayer ? tostring(selectedPlayer.Zone ?? 1) : "--"} accent={Palette.mango} />
				<StatCell layoutOrder={6} label="RATE" value={selectedPlayer ? `${compactNumber(selectedPlayer.Production ?? 0)}/s` : "--"} accent={Palette.cyan} />
				<StatCell layoutOrder={7} label="DUST" value={selectedPlayer ? compactNumber(selectedPlayer.Stardust ?? 0) : "--"} accent={Palette.steel} />
				<StatCell layoutOrder={8} label="KEYS" value={selectedPlayer ? compactNumber(selectedPlayer.Keys ?? 0) : "--"} accent={Palette.violet} />
			</frame>
		</PnSurface>
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
		<PnSurface
			size={new UDim2(1, 0, 0, executeH)}
			accent={armed ? Palette.coral : Palette.brass}
			background={Palette.panelRaised}
			padding={12}
			layoutOrder={1}
			highlight={armed}
			reveal={toolsReveal}
			reducedMotion={softMotion}
			clips={false}
		>
			{/* title, command, fields, actions, note: one vertical list (gaps match the old 42/50/46 rhythm) */}
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 0)} />
			<SectionTitle value={needsArm ? "OFF" : "READY"} accent={armed ? Palette.coral : accent} layoutOrder={0} />
			<Slot height={EXEC_TITLE - 16} layoutOrder={1}>
				<Text
					value={(selected && selected.Label) ?? command}
					size={15}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					sizeConstraint={new UDim2(1, 0, 0, 20)}
				/>
			</Slot>
			<frame
				key="Fields"
				Size={new UDim2(1, 0, 0, math.max(0, fieldSlots) * FIELD_H)}
				BackgroundTransparency={1}
				ZIndex={50}
				LayoutOrder={2}
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
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				LayoutOrder={3}
				ref={executeActionsHostRef}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<frame key="AdminPreviewRun" Size={new UDim2(0.34, -5, 0, 48)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} LayoutOrder={0}>
					<Button
						text="PREVIEW"
						icon="Search.8"
						onClick={preview}
						color={Palette.panelSoft}
						textColor={Palette.text}
						size={UDim2.fromScale(1, 1)}
						disabled={runDisabled}
						reducedMotion={softMotion}
					/>
				</frame>
				<frame
					key="AdminConfirmRun"
					ClipsDescendants={false}
					Size={new UDim2(0.66, -5, 0, 48)}
					LayoutOrder={1}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<Button
						text={runLabel}
						icon="Lock.16"
						onClick={execute}
						color={runColor}
						textColor={Palette.ink}
						size={UDim2.fromScale(1, 1)}
						disabled={runDisabled}
						loading={busy}
						shakeToken={shakeToken}
						highlight={armed || !needsArm}
						reducedMotion={softMotion}
					/>
				</frame>
			</frame>
			<frame key="Spacer" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} LayoutOrder={4}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			</frame>
			<Slot height={EXEC_NOTE - 4} layoutOrder={5}>
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
				size={11}
				color={optionMissing ? Palette.coral : lastNote !== "" ? (lastOk ? Palette.mint : Palette.coral) : Palette.muted}
				wrap={true}
				fit={true} minSize={11}
				sizeConstraint={new UDim2(1, 0, 0, EXEC_NOTE - 4)}
			/>
			</Slot>
		</PnSurface>
	);

	const auditRows: React.Element[] = [];
	for (let i = 0; i < math.min(6, recent.size()); i++) {
		auditRows.push(<AuditLine key={recent[i].Id} record={recent[i]} layoutOrder={i} />);
	}
	const recentSection = (
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.steel} background={Palette.panel} padding={12} layoutOrder={2} clips={false}>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
			<SectionTitle value="Recent" accent={Palette.steel} layoutOrder={0} />
			<frame key="Rows" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, OPS_GAP)} />
				{recent.size() === 0 ? <EmptyState icon="Command" title="No commands run yet" body="" compact={true} /> : auditRows}
			</frame>
		</PnSurface>
	);

	const MAX_OPS_ROWS = OPS_ROWS;
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
		}		// newest flags fill the rest of the panel, then any rule that has had to repair a save
		const recentFlags = admin.SecurityFlags ?? [];
		for (let i = 0; i < recentFlags.size() && securityRows.size() < MAX_OPS_ROWS; i++) {
			const flag = recentFlags[i];
			securityRows.push(
				<OpsLine key={`sf${i}`} chip={flag.Kind} left={flag.Name} sub={flag.Response} right={clockTime(flag.At)} rightColor={Palette.coral} layoutOrder={100 + i} />,
			);
		}
		const rules = (admin.AntiCheatRules ?? []).filter((rule) => rule.Repairs > 0);
		for (let i = 0; i < rules.size() && securityRows.size() < MAX_OPS_ROWS; i++) {
			securityRows.push(
				<OpsLine key={`ar${rules[i].Id}`} left={`rule ${rules[i].Id}`} right={`${compactNumber(rules[i].Repairs)} fixed`} accent={Palette.steel} rightColor={Palette.muted} layoutOrder={200 + i} />,
			);
		}
	}
	const flagRows = (admin.HotFlags ?? []).filter((_, i) => i < MAX_OPS_ROWS).map((flag, i) => (
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
	const opsPanels = (size: UDim2 | undefined) => [
		<OpsPanel key="ops0" size={size} title={lookup !== undefined ? "LOOKUP" : "SECURITY"} accent={Palette.coral}
				empty="No flagged players."
				layoutOrder={1}
				onBack={lookup !== undefined ? () => setLookup(undefined) : undefined}
			>
				{securityRows}
			</OpsPanel>,
		<OpsPanel key="ops1" size={size} title="Live flags" accent={Palette.mango} empty="No flags." layoutOrder={2}>
				{flagRows}
			</OpsPanel>,
		<OpsPanel key="ops2" size={size} title="Announcements" accent={Palette.violet} empty="Nothing announced yet." layoutOrder={3}>
				{announcementRows}
			</OpsPanel>,
		<OpsPanel key="ops3" size={size} title="Economy" accent={Palette.cyan} empty="No live profiles." layoutOrder={4}>
				{economyRows}
			</OpsPanel>,
	];
	const opsRow = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uisizeconstraint MinSize={new Vector2(CONSOLE_W, OPS_H)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
			{opsPanels(undefined)}
		</frame>
	);

	// pad order: header tools, players, commands, then the inspect -> execute -> recent column, ops last.
	// Narrow mode uses the scaffold section ids, wide mode the named console columns.
	const focusHostRef = React.useRef<Frame>();
	useFocusOrder(
		focusHostRef,
		{
			regions: narrow
				? ["header", "players", "commands", "inspect", "execute", "recent", "ops*"]
				: ["header", "AdminPlayers", "AdminCommands", "AdminInspect", "AdminExecute", "AdminRecent", "ops"],
			first: narrow ? ["players", "commands"] : ["AdminPlayers", "AdminCommands"],
			columns: narrow
				? undefined
				: [
						["AdminPlayers", "AdminCommands"],
						["AdminCommands", "AdminInspect"],
					],
		},
		[narrow],
	);
	const BODY_H = inspectH + GAP + executeH + GAP + RECENT_MIN;
	// design/22 body: players | commands (fills) | inspect / execute / recent column, one horizontal list
	const consoleBody = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<uisizeconstraint MinSize={new Vector2(CONSOLE_W, BODY_H)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
			<frame Size={new UDim2(0, PLAYERS_W, 1, 0)} BackgroundTransparency={1} LayoutOrder={0} {...named("AdminPlayers")}>
				{playerSection}
			</frame>
			<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} LayoutOrder={1} {...named("AdminCommands")}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				{commandSection}
			</frame>
			<frame Size={new UDim2(0, DETAIL_W, 1, 0)} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
				<frame Size={new UDim2(1, 0, 0, inspectH)} BackgroundTransparency={1} LayoutOrder={0} {...named("AdminInspect")}>
					{inspectSection}
				</frame>
				<frame Size={new UDim2(1, 0, 0, executeH)} BackgroundTransparency={1} LayoutOrder={1} {...named("AdminExecute")}>
					{executeDock}
				</frame>
				<frame Size={new UDim2(1, 0, 0, RECENT_MIN)} BackgroundTransparency={1} ClipsDescendants={true} LayoutOrder={2} {...named("AdminRecent")}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					{recentSection}
				</frame>
			</frame>
		</frame>
	);

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ref={focusHostRef}>
		<PageScaffold
			gap={GAP}
			tailPad={8}
			scrollBarColor={Palette.steel}
			scrollBarThickness={4}
			sections={
				narrow
					? [
							{ id: "header", height: HEADER_H, element: header },
							{ id: "players", height: NARROW_PLAYERS_H, element: playerSection },
							{ id: "commands", height: NARROW_COMMANDS_H, element: commandSection },
							{ id: "inspect", height: inspectH, element: inspectSection },
							{ id: "execute", height: executeH, element: executeDock },
							{ id: "recent", height: RECENT_MIN, element: recentSection },
							...opsPanels(UDim2.fromScale(1, 1)).map((panel, i) => ({ id: `ops${i}`, height: OPS_H, element: panel })),
						]
					: [
							{ id: "header", height: HEADER_H, element: header },
							{ id: "console", fill: true, minHeight: BODY_H, element: consoleBody },
							{ id: "ops", height: OPS_H, element: opsRow },
						]
			}
		/>
		</frame>
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
