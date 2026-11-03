// The owner and staff Control Room. Every command goes through the server's AdminExecute request (nonce, string
// amount, audit reason); this page only decides what to send. Tabs: Console, Show Room, Live Ops, Telemetry, Audit.
import React from "@rbxts/react";
import { fieldsFor, reasonsFor } from "../../CoreKit/adminFields";
import { compactNumber } from "../../CoreKit/format";
import { Palette } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import { AutoPage } from "./AutoPage";
import {
	AdminCommand,
	AdminPlayer,
	catAccent,
	CATEGORY_LABEL,
	Chip,
	COMMAND_ROW,
	CommandRow,
	headshot,
	HoldButton,
	PLAYER_ROW,
	PlayerRow,
	plainLabel,
	Reticle,
	ScanLine,
	SectionTitle,
	Stamp,
	StatTile,
	uptimeText,
	useCountUp,
	useTypewriter,
} from "./AdminParts";
import { AdminContext, AdminProps, LookupResult, useRunner } from "./AdminRunner";
import { AuditTab, Col, Field, GAP, LiveOpsTab, ShowRoomTab, Split, TelemetryTab } from "./AdminTabs";

export type { AdminProps } from "./AdminRunner";

const { Badge, Button, Dropdown, EmptyState, Panel, SearchField, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");

const TABS = [
	{ id: "Console", label: "CONSOLE" },
	{ id: "Show", label: "SHOW ROOM" },
	{ id: "LiveOps", label: "LIVE OPS" },
	{ id: "Telemetry", label: "TELEMETRY" },
	{ id: "Audit", label: "AUDIT" },
];
const CATEGORY_ORDER = ["Economy", "Progress", "Items", "Resets", "Troll", "Effects", "Moderation", "LiveOps"];
// commands that act on the server or the world, not on the player picked in the roster
const NO_TARGET = new Set(["Announce", "ToggleHotFlag", "ServerGift", "ServerShow"]);
const WIDE_AT = 860;
const MAX_RECENT = 6;
const COMMAND_LIST_H = 360;
const PLAYER_LIST_MAX_H = 300;

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

function needsArm(entry?: AdminCommand) {
	if (entry === undefined) return true;
	if (entry.Danger === "quick") return false;
	if (entry.Danger === "arm") return true;
	const category = entry.Category ?? "Economy";
	return category === "Troll" || category === "Resets" || category === "Moderation";
}

function PreviewLines(props: { lines: string[]; reducedMotion: boolean }) {
	const shown: string[] = [];
	for (let i = 0; i < math.min(props.lines.size(), 6); i++) {
		shown.push(props.lines[i]);
	}
	const typed = useTypewriter(shown.join("\n"), props.reducedMotion, 140);
	return (
		<Text
			value={typed}
			size={12}
			color={Palette.cyan}
			wrap={true}
			fit={true}
			minSize={11}
			sizeConstraint={new UDim2(1, 0, 0, 16 * shown.size() + 4)}
			layoutOrder={8}
		/>
	);
}

function AdminViewReady(props: AdminProps & { admin: NonNullable<AdminProps["state"]["Admin"]> }) {
	const { admin, config, dispatch } = props;
	const reduced = props.reducedMotion === true;
	const antilag = useAntilag();
	const enter = useEntrance(reduced);

	const commands = admin.Commands ?? [];
	const online = admin.Online ?? [];
	const [tab, setTab] = React.useState("Console");
	const [width, setWidth] = React.useState(1000);
	const [targetId, setTargetId] = React.useState<number>(admin.SelfUserId ?? online[0]?.UserId ?? 0);
	const [lockToken, setLockToken] = React.useState(0);
	const [command, setCommand] = React.useState<string>(commands.find((entry) => entry.Id === "GrantFlux")?.Id ?? commands[0]?.Id ?? "GrantFlux");
	const [category, setCategory] = React.useState("All");
	const [playerQuery, setPlayerQuery] = React.useState("");
	const [commandQuery, setCommandQuery] = React.useState("");
	const [amount, setAmount] = React.useState("1000");
	const [option, setOption] = React.useState("");
	const [reason, setReason] = React.useState(reasonsFor("GrantFlux", "Economy")[0].id);
	const [previewLines, setPreviewLines] = React.useState<string[]>([]);
	const [recents, setRecents] = React.useState<string[]>([]);
	const [lookup, setLookup] = React.useState<LookupResult>();
	const [stamp, setStamp] = React.useState<{ ok: boolean; text: string; token: number }>();
	const [shakeToken, setShakeToken] = React.useState(0);

	const runner = useRunner(dispatch, (ran) => {
		setRecents((previous) => {
			const ordered = [ran];
			for (const id of previous) {
				if (id !== ran && ordered.size() < MAX_RECENT) ordered.push(id);
			}
			return ordered;
		});
	});

	const selected = commands.find((entry) => entry.Id === command);
	const target = online.find((player) => player.UserId === targetId);
	const fields = fieldsFor(command, config, admin.Banned, selected?.Input);
	const armed = needsArm(selected);
	const accent = catAccent(selected?.Category);
	const noTarget = NO_TARGET.has(command);
	const reasonList = reasonsFor(command, selected?.Category);
	// commands with a typed option (a flag name, a whisper) get a text field; the hint is the "(Option = ...)" part of the label
	const typedOption = selected?.NeedsOption === true && !fields.usesOption;
	const optionHint = (() => {
		const [hint] = (selected?.Label ?? "").match("%(Option = ([^%)]+)%)");
		return typeIs(hint, "string") ? hint : "a value";
	})();
	const optionMissing = selected?.NeedsOption === true && amount !== "Permanent" && option.gsub("%s", "")[0] === "";
	const busy = runner.busyId !== undefined;
	const runDisabled = busy || optionMissing || (fields.overridesTarget ? fields.amountChoices.size() === 0 : !noTarget && target === undefined) || reason.size() < 3;
	const wide = width >= WIDE_AT;

	// keep the selections valid as the server's lists change
	React.useEffect(() => {
		if (online.size() > 0 && !online.some((player) => player.UserId === targetId)) {
			setTargetId(admin.SelfUserId ?? online[0].UserId);
		}
	}, [admin.Online, admin.SelfUserId, targetId]);
	React.useEffect(() => {
		if (commands.size() > 0 && !commands.some((entry) => entry.Id === command)) {
			setCommand(commands[0].Id);
		}
	}, [admin.Commands, command]);
	React.useEffect(() => {
		setPreviewLines([]);
	}, [amount, command, option, reason, targetId]);
	React.useEffect(() => {
		setLockToken((token) => token + 1);
		setLookup(undefined);
	}, [targetId]);
	React.useEffect(() => {
		const layout = fieldsFor(command, config, admin.Banned, selected?.Input);
		setAmount(layout.defaultAmount);
		setOption(layout.defaultOption);
		setReason(reasonsFor(command, selected?.Category)[0]?.id ?? "Owner gameplay administration");
		if (layout.overridesTarget && layout.defaultAmount !== "") {
			const userId = tonumber(layout.defaultAmount);
			if (userId !== undefined) setTargetId(userId);
		}
	}, [command]);

	// the stamp lands when a real command answers, and lifts after a moment
	const outcomeToken = runner.outcome?.token;
	React.useEffect(() => {
		const outcome = runner.outcome;
		if (outcome === undefined || outcome.dryRun) {
			return undefined;
		}
		setStamp({ ok: outcome.ok, text: outcome.ok ? "APPLIED" : "REFUSED", token: outcome.token });
		if (!outcome.ok) {
			setShakeToken((token) => token + 1);
		}
		const lift = task.delay(1.7, () => setStamp(undefined));
		return () => {
			pcall(task.cancel, lift);
		};
	}, [outcomeToken]);

	const send = (dryRun: boolean) => {
		const sendAmount = amount === "Permanent" ? "1" : amount !== "" ? amount : "1";
		const sendOption = amount === "Permanent" ? "Permanent" : option;
		const sendTarget = fields.overridesTarget ? (tonumber(amount) ?? targetId) : noTarget ? 0 : targetId;
		runner.run({ command, targetUserId: sendTarget, amount: sendAmount, option: sendOption, reason, dryRun }, (outcome) => {
			setPreviewLines(outcome.dryRun && outcome.ok ? outcome.preview : []);
			if (outcome.lookup !== undefined) setLookup(outcome.lookup);
		});
	};

	// Studio only: drive the page from ReplicatedStorage attributes (the synthetic mouse is unreliable in a test session)
	const sendRef = React.useRef(send);
	sendRef.current = send;
	React.useEffect(() => {
		if (!game.GetService("RunService").IsStudio()) {
			return undefined;
		}
		const storage = game.GetService("ReplicatedStorage");
		const apply = () => {
			const wantedTab = storage.GetAttribute("AstralDevAdminTab");
			if (typeIs(wantedTab, "string") && TABS.some((entry) => entry.id === wantedTab)) setTab(wantedTab);
			const wantedCommand = storage.GetAttribute("AstralDevAdminCommand");
			if (typeIs(wantedCommand, "string")) setCommand(wantedCommand);
			const wantedTarget = storage.GetAttribute("AstralDevAdminTarget");
			if (typeIs(wantedTarget, "number")) setTargetId(wantedTarget);
			const wantedOption = storage.GetAttribute("AstralDevAdminOption");
			if (typeIs(wantedOption, "string")) setOption(wantedOption);
		};
		apply();
		let lastRun = storage.GetAttribute("AstralDevAdminRun");
		const connections = [
			storage.GetAttributeChangedSignal("AstralDevAdminTab").Connect(apply),
			storage.GetAttributeChangedSignal("AstralDevAdminCommand").Connect(apply),
			storage.GetAttributeChangedSignal("AstralDevAdminTarget").Connect(apply),
			storage.GetAttributeChangedSignal("AstralDevAdminOption").Connect(apply),
			storage.GetAttributeChangedSignal("AstralDevAdminRun").Connect(() => {
				const marker = storage.GetAttribute("AstralDevAdminRun");
				if (marker !== lastRun) {
					lastRun = marker;
					// a marker that starts with "dry" asks for a preview instead of a real run
					const dry = typeIs(marker, "string") && marker.sub(1, 3) === "dry";
					task.defer(() => sendRef.current(dry));
				}
			}),
		];
		return () => {
			for (const connection of connections) connection.Disconnect();
		};
	}, []);

	const ctx: AdminContext = {
		admin,
		config,
		dispatch,
		runner,
		commands,
		online,
		targetId,
		setTargetId,
		target,
		width,
		wide,
		reducedMotion: reduced,
		has: (id) => commands.some((entry) => entry.Id === id),
	};

	// ── masthead ───────────────────────────────────────────────────────────────
	const playersShown = useCountUp(online.size(), reduced);
	const telemetry = admin.Telemetry;
	const ticker = runner.outcome?.text ?? admin.LastAction?.Message ?? "Ready. Pick a target and a command.";
	const tickerOk = runner.outcome?.ok ?? admin.LastAction?.Ok ?? true;
	const typedTicker = useTypewriter(ticker, reduced);
	const unhealthy = admin.Integrity?.Healthy === false;
	const mastheadH = wide ? 156 : 232;
	const masthead = (
		<Panel size={new UDim2(1, 0, 0, mastheadH)} accent={Palette.coral} background={Palette.panelRaised} padding={16} layoutOrder={1} reveal={enter} reducedMotion={reduced} clips={false}>
			<SectionTitle value="ASTRAL FORGE  ·  STAFF" accent={Palette.coral} />
			<Text
				value="Control Room"
				size={24}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(0, 18)}
				sizeConstraint={new UDim2(wide ? 0.5 : 1, 0, 0, 32)}
			/>
			<frame Size={new UDim2(wide ? 0.5 : 1, 0, 0, 24)} Position={UDim2.fromOffset(0, 56)} BackgroundTransparency={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<Badge value={string.upper(admin.Role ?? "ADMIN")} accent={Palette.coral} filled={true} size={UDim2.fromOffset(150, 24)} layoutOrder={1} />
				<Badge value={unhealthy ? "RESTORED SAVE" : "SAVES HEALTHY"} accent={unhealthy ? Palette.mango : Palette.mint} filled={true} size={UDim2.fromOffset(132, 24)} layoutOrder={2} />
			</frame>
			<frame
				Size={wide ? new UDim2(0.5, -16, 0, 74) : new UDim2(1, 0, 0, 74)}
				Position={wide ? new UDim2(0.5, 16, 0, 0) : UDim2.fromOffset(0, 94)}
				BackgroundTransparency={1}
			>
				<uigridlayout CellSize={new UDim2(1 / 3, -9, 1, 0)} CellPadding={UDim2.fromOffset(12, 0)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<StatTile label="ONLINE" value={tostring(math.floor(playersShown + 0.5))} accent={Palette.mint} layoutOrder={1} index={0} reducedMotion={reduced} />
				<StatTile label="LOGGED" value={tostring((admin.Recent ?? []).size())} accent={Palette.cyan} layoutOrder={2} index={1} reducedMotion={reduced} />
				<StatTile label="SERVER UP" value={uptimeText(telemetry?.UptimeSeconds ?? 0)} accent={Palette.violet} layoutOrder={3} index={2} reducedMotion={reduced} />
			</frame>
			<frame Size={new UDim2(1, -112, 0, 22)} Position={new UDim2(0, 0, 1, -30)} BackgroundTransparency={1}>
				<frame Size={UDim2.fromOffset(8, 8)} Position={UDim2.fromOffset(0, 7)} BackgroundColor3={tickerOk ? Palette.mint : Palette.coral} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				<Text
					value={typedTicker}
					size={12}
					color={tickerOk ? Palette.creamSoft : Palette.coral}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(18, 0)}
					sizeConstraint={new UDim2(1, -18, 0, 22)}
				/>
			</frame>
			<Button
				text="REFRESH"
				onClick={() => dispatch("GetAdminState")}
				color={Palette.panelSoft}
				textColor={Palette.mint}
				outline={true}
				size={UDim2.fromOffset(100, 28)}
				position={new UDim2(1, -100, 1, -32)}
				reducedMotion={reduced}
			/>
			<ScanLine accent={Palette.coral} position={new UDim2(0, 0, 1, -2)} />
		</Panel>
	);

	// five tabs fit one row from about 520px up; below that they wrap to two rows and the rail grows to hold them
	const railRows = width >= 520 ? 1 : 2;
	const tabRail = (
		<Panel size={new UDim2(1, 0, 0, railRows === 1 ? 52 : 104)} accent={Palette.cyan} background={Palette.panel} padding={6} layoutOrder={2} reducedMotion={reduced}>
			<SegmentedTabs
				options={TABS}
				value={tab}
				onChange={(id: string) => setTab(id)}
				accent={Palette.coral}
				columns={railRows === 1 ? TABS.size() : 3}
				gap={4}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={reduced}
			/>
		</Panel>
	);

	// ── console: target ────────────────────────────────────────────────────────
	const shownPlayers = online.filter((player) => hayHas(`${player.DisplayName} ${player.Name} ${player.UserId}`, playerQuery));
	const playerListH = math.min(PLAYER_LIST_MAX_H, math.max(shownPlayers.size(), 1) * (PLAYER_ROW + 6));
	const statCell = (label: string, value: string, tone: Color3, order: number) => (
		<StatTile key={label} label={label} value={value} accent={tone} layoutOrder={order} index={order} reducedMotion={reduced} />
	);
	const lookupRows: React.Element[] = [];
	if (lookup !== undefined) {
		lookupRows.push(
			<Text
				key="lookup"
				value={`${lookup.Name}  ·  security ${lookup.Score}  ·  ${string.upper(lookup.Level)}  ·  rev ${lookup.Revision ?? 0}`}
				size={12}
				color={lookup.Level === "kick" ? Palette.coral : lookup.Level === "throttle" ? Palette.mango : Palette.mint}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
				layoutOrder={1}
			/>,
		);
		const flags = lookup.Flags ?? [];
		for (let i = 0; i < math.min(3, flags.size()); i++) {
			lookupRows.push(
				<Text key={`lf${i}`} value={`${flags[i].Kind}  ${flags[i].Detail}`} size={11} color={Palette.muted} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 16)} layoutOrder={2 + i} />,
			);
		}
		lookupRows.push(
			<Text key="lj" value={`${(lookup.Journal ?? []).size()} journal snapshots on file`} size={11} color={Palette.muted} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 16)} layoutOrder={9} />,
		);
	}
	const targetPanel = (
		<Panel size={new UDim2(1, 0, 0, 0)} autoHeight={true} accent={Palette.mint} background={Palette.panel} padding={16} layoutOrder={1} reducedMotion={reduced}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 12)} />
			<SectionTitle value="TARGET" accent={Palette.mint} layoutOrder={1} />
			<frame Size={new UDim2(1, 0, 0, 84)} BackgroundTransparency={1} LayoutOrder={2}>
				<frame Size={UDim2.fromOffset(84, 84)} BackgroundTransparency={1}>
					{target !== undefined && (
						<imagelabel
							AnchorPoint={new Vector2(0.5, 0.5)}
							Position={UDim2.fromScale(0.5, 0.5)}
							Size={UDim2.fromOffset(52, 52)}
							BackgroundColor3={Palette.ink}
							BorderSizePixel={0}
							Image={headshot(target.UserId)}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</imagelabel>
					)}
					{target !== undefined && <Reticle size={52} accent={Palette.mint} token={lockToken} reducedMotion={reduced} />}
				</frame>
				<Text
					value={target !== undefined ? target.DisplayName : "No player selected"}
					size={17}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(96, 14)}
					sizeConstraint={new UDim2(1, -96, 0, 24)}
				/>
				<Text
					value={target !== undefined ? `@${target.Name}  ·  ${target.UserId}` : "Pick someone from the list below."}
					size={12}
					color={Palette.cyan}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(96, 42)}
					sizeConstraint={new UDim2(1, -96, 0, 18)}
				/>
				{target !== undefined && target.Unlimited === true && (
					<frame Size={UDim2.fromOffset(92, 22)} Position={UDim2.fromOffset(96, 62)} BackgroundTransparency={1}>
						<Badge value="UNLIMITED" accent={Palette.violet} filled={true} size={UDim2.fromScale(1, 1)} />
					</frame>
				)}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uigridlayout
					CellSize={new UDim2(0.25, -7, 0, 58)}
					CellPadding={UDim2.fromOffset(8, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					FillDirection={Enum.FillDirection.Horizontal}
				/>
				{statCell("FLUX", target !== undefined ? compactNumber(target.Cash ?? 0) : "--", Palette.cyan, 1)}
				{statCell("VAULT", target !== undefined ? compactNumber(target.Vault ?? 0) : "--", Palette.mint, 2)}
				{statCell("CORES", target !== undefined ? compactNumber(target.Cores ?? 0) : "--", Palette.violet, 3)}
				{statCell("REBIRTH",target !== undefined ? compactNumber(target.Rebirths ?? 0) : "--", Palette.pink, 4)}
				{statCell("WORLD", target !== undefined ? tostring(target.Zone ?? 1) : "--", Palette.mango, 5)}
				{statCell("RATE", target !== undefined ? `${compactNumber(target.Production ?? 0)}/s` : "--", Palette.cyan, 6)}
				{statCell("DUST", target !== undefined ? compactNumber(target.Stardust ?? 0) : "--", Palette.steel, 7)}
				{statCell("KEYS", target !== undefined ? compactNumber(target.Keys ?? 0) : "--", Palette.violet, 8)}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 38)} BackgroundTransparency={1} LayoutOrder={4}>
				<Button
					text={lookup !== undefined ? "LOOK UP AGAIN" : "LOOK UP SECURITY"}
					onClick={() =>
						runner.run(
							{ command: "InspectPlayer", targetUserId: targetId, amount: "1", option: "", reason: "Moderation action", dryRun: false },
							(outcome) => {
								if (outcome.lookup !== undefined) setLookup(outcome.lookup);
							},
						)
					}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					outline={true}
					size={UDim2.fromScale(1, 1)}
					disabled={busy || target === undefined}
					loading={runner.busyId === "InspectPlayer"}
					reducedMotion={reduced}
				/>
			</frame>
			{lookupRows.size() > 0 && (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={5}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 3)} />
					{lookupRows}
				</frame>
			)}
		</Panel>
	);
	const rosterPanel = (
		<Panel size={new UDim2(1, 0, 0, 0)} autoHeight={true} accent={Palette.cyan} background={Palette.panel} padding={16} layoutOrder={2} reducedMotion={reduced}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
			<SectionTitle value={`PLAYERS  ·  ${online.size()} HERE`} accent={Palette.cyan} layoutOrder={1} />
			<frame Size={new UDim2(1, 0, 0, 40)} BackgroundTransparency={1} LayoutOrder={2}>
				<SearchField value={playerQuery} onChange={setPlayerQuery} accent={Palette.cyan} placeholder="Search players…" size={UDim2.fromScale(1, 1)} reducedMotion={reduced} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, playerListH)} BackgroundTransparency={1} LayoutOrder={3}>
				{shownPlayers.size() === 0 ? (
					<EmptyState icon="Search" title="No players match" body="Check the spelling or clear the search." compact={true} />
				) : (
					<FlatList
						data={shownPlayers}
						itemHeight={PLAYER_ROW + 6}
						overscan={reduced ? 0 : antilag.tier <= 1 ? 1 : 2}
						canvasTail={4}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.cyan}
						scrollBarThickness={4}
						keyExtractor={(player: AdminPlayer) => tostring(player.UserId)}
						renderItem={({ item: player, index }: { item: AdminPlayer; index: number }) => (
							<PlayerRow
								player={player}
								selected={player.UserId === targetId}
								you={player.UserId === admin.SelfUserId}
								index={index}
								onClick={() => setTargetId(player.UserId)}
								reducedMotion={reduced}
							/>
						)}
					/>
				)}
			</frame>
		</Panel>
	);

	// ── console: runner and command list ───────────────────────────────────────
	const outcome = runner.outcome;
	const feedback =
		optionMissing && !busy
			? `Fill in ${optionHint} above before you run this.`
			: outcome !== undefined && previewLines.size() === 0
				? outcome.text
				: previewLines.size() > 0
					? "Preview of what would change:"
					: armed
						? "Hold the button to run. Preview first if you are unsure."
						: "Preview, then run.";
	const feedbackColor = optionMissing && !busy ? Palette.coral : outcome !== undefined && previewLines.size() === 0 ? (outcome.ok ? Palette.mint : Palette.coral) : Palette.muted;
	const runnerPanel = (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={accent}
				background={Palette.panelRaised}
				padding={16}
				highlight={outcome !== undefined && outcome.ok && !outcome.dryRun && stamp !== undefined}
				reducedMotion={reduced}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<frame Size={new UDim2(1, 0, 0, 46)} BackgroundTransparency={1} LayoutOrder={1}>
					<Text
						value={plainLabel(selected?.Label ?? command)}
						size={17}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={11}
						sizeConstraint={new UDim2(1, -128, 0, 24)}
					/>
					<Text
						value={`${CATEGORY_LABEL[selected?.Category ?? "Economy"] ?? "OTHER"}  ·  ${command}`}
						size={11}
						color={accent}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, 27)}
						sizeConstraint={new UDim2(1, -128, 0, 16)}
					/>
					<frame Size={UDim2.fromOffset(120, 24)} Position={new UDim2(1, -120, 0, 0)} BackgroundTransparency={1}>
						<Badge value={armed ? "HOLD TO RUN" : "ONE TAP"} accent={armed ? Palette.mango : Palette.mint} filled={true} size={UDim2.fromScale(1, 1)} />
					</frame>
				</frame>
				<Text
					value={selected?.Input?.Summary ?? ""}
					size={12}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={11}
					sizeConstraint={new UDim2(1, 0, 0, 32)}
					layoutOrder={2}
				/>
				<frame Size={new UDim2(1, 0, 0, 30)} BackgroundTransparency={1} LayoutOrder={3}>
					<Text value="TARGET" size={11} color={Palette.muted} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={new UDim2(0, 56, 0, 30)} />
					<Text
						value={noTarget ? "Everyone, or the whole server" : fields.overridesTarget ? "Chosen below" : target !== undefined ? `${target.DisplayName}  ·  @${target.Name}` : "Pick a player on the left"}
						size={13}
						color={noTarget || fields.overridesTarget || target !== undefined ? Palette.cream : Palette.coral}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(62, 0)}
						sizeConstraint={new UDim2(1, -62, 0, 30)}
					/>
				</frame>
				{fields.usesAmount && (
					<Field label={string.upper(fields.amountLabel)} z={52} order={4}>
						<Dropdown
							options={fields.amountChoices}
							value={amount}
							onChange={(id: string) => {
								setAmount(id);
								if (fields.overridesTarget) {
									const userId = tonumber(id);
									if (userId !== undefined) setTargetId(userId);
								}
							}}
							accent={Palette.mango}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={reduced}
							zIndex={80}
						/>
					</Field>
				)}
				{fields.usesOption && (
					<Field label={string.upper(fields.optionLabel)} z={51} order={5}>
						<Dropdown options={fields.optionChoices} value={option} onChange={setOption} accent={Palette.cyan} size={UDim2.fromScale(1, 1)} reducedMotion={reduced} zIndex={70} />
					</Field>
				)}
				{typedOption && (
					<Field label={string.upper(optionHint)} z={51} order={5}>
						<SearchField
							value={option}
							onChange={setOption}
							debounce={0}
							accent={optionMissing ? Palette.coral : Palette.cyan}
							placeholder={`Needed: ${optionHint}`}
							hint={optionMissing ? "Required" : undefined}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={reduced}
						/>
					</Field>
				)}
				{armed && (
					<Field label="LOGGED AS" z={50} order={6}>
						<Dropdown options={reasonList} value={reason} onChange={setReason} accent={Palette.steel} size={UDim2.fromScale(1, 1)} reducedMotion={reduced} zIndex={60} />
					</Field>
				)}
				<frame Size={new UDim2(1, 0, 0, 48)} BackgroundTransparency={1} LayoutOrder={7}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} />
					<Button
						text="PREVIEW"
						icon="Search.8"
						onClick={() => send(true)}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						size={new UDim2(0.34, -5, 0, 48)}
						layoutOrder={1}
						disabled={runDisabled}
						reducedMotion={reduced}
					/>
					{armed ? (
						<HoldButton
							text="HOLD TO RUN"
							color={Palette.coral}
							size={new UDim2(0.66, -5, 0, 48)}
							layoutOrder={2}
							disabled={runDisabled}
							busy={runner.busyId === command}
							shakeToken={shakeToken}
							reducedMotion={reduced}
							onComplete={() => send(false)}
						/>
					) : (
						<Button
							text="RUN"
							onClick={() => send(false)}
							color={Palette.mint}
							textColor={Palette.ink}
							size={new UDim2(0.66, -5, 0, 48)}
							layoutOrder={2}
							disabled={runDisabled}
							loading={runner.busyId === command}
							shakeToken={shakeToken}
							highlight={true}
							reducedMotion={reduced}
						/>
					)}
				</frame>
				<Text value={feedback} size={12} color={feedbackColor} wrap={true} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 34)} layoutOrder={8} />
				{previewLines.size() > 0 && <PreviewLines lines={previewLines} reducedMotion={reduced} />}
			</Panel>
			{stamp !== undefined && <Stamp key={tostring(stamp.token)} ok={stamp.ok} text={stamp.text} position={new UDim2(0.5, 0, 0, 120)} reducedMotion={reduced} />}
		</frame>
	);

	const present: Record<string, number> = {};
	for (const entry of commands) {
		const key = entry.Category ?? "Economy";
		present[key] = (present[key] ?? 0) + 1;
	}
	const categories = CATEGORY_ORDER.filter((id) => present[id] !== undefined);
	const shownCommands = commands.filter((entry) => {
		const categoryOk = category === "All" || (entry.Category ?? "Economy") === category;
		return categoryOk && hayHas(`${entry.Id} ${entry.Label} ${entry.Category ?? ""}`, commandQuery);
	});
	const commandPanel = (
		<Panel size={new UDim2(1, 0, 0, 0)} autoHeight={true} accent={Palette.violet} background={Palette.panel} padding={16} layoutOrder={2} reducedMotion={reduced}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
			<SectionTitle value={`COMMANDS  ·  ${shownCommands.size()} SHOWN`} accent={Palette.violet} layoutOrder={1} />
			{recents.size() > 0 && (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 0)} Wraps={true} VerticalAlignment={Enum.VerticalAlignment.Center} />
					<Text value="RECENT" size={11} color={Palette.muted} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={new UDim2(0, 56, 0, 30)} layoutOrder={0} />
					{recents.map((id, index) => (
						<Chip key={id} label={id} selected={id === command} accent={Palette.violet} onClick={() => setCommand(id)} layoutOrder={index + 1} />
					))}
				</frame>
			)}
			<frame Size={new UDim2(1, 0, 0, 40)} BackgroundTransparency={1} LayoutOrder={3}>
				<SearchField value={commandQuery} onChange={setCommandQuery} accent={Palette.violet} placeholder="Search commands…" size={UDim2.fromScale(1, 1)} reducedMotion={reduced} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 0)} Wraps={true} />
				<Chip label="ALL" count={commands.size()} selected={category === "All"} accent={Palette.violet} onClick={() => setCategory("All")} layoutOrder={0} />
				{categories.map((id, index) => (
					<Chip key={id} label={CATEGORY_LABEL[id] ?? id} count={present[id]} selected={category === id} accent={catAccent(id)} onClick={() => setCategory(id)} layoutOrder={index + 1} />
				))}
			</frame>
			<frame Size={new UDim2(1, 0, 0, COMMAND_LIST_H)} BackgroundTransparency={1} LayoutOrder={5}>
				{shownCommands.size() === 0 ? (
					<EmptyState icon="Command" title="No commands" body="Nothing matches that filter." compact={true} />
				) : (
					<FlatList
						data={shownCommands}
						itemHeight={COMMAND_ROW + 6}
						overscan={reduced ? 0 : antilag.tier <= 1 ? 1 : 2}
						canvasTail={4}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.violet}
						scrollBarThickness={4}
						keyExtractor={(entry: AdminCommand) => entry.Id}
						renderItem={({ item: entry, index }: { item: AdminCommand; index: number }) => (
							<CommandRow entry={entry} selected={entry.Id === command} armed={needsArm(entry)} index={index} onClick={() => setCommand(entry.Id)} reducedMotion={reduced} />
						)}
					/>
				)}
			</frame>
		</Panel>
	);

	const consoleTab = (
		<Split
			wide={wide}
			ratio={0.38}
			order={3}
			left={
				<Col>
					{targetPanel}
					{rosterPanel}
				</Col>
			}
			right={
				<Col>
					{runnerPanel}
					{commandPanel}
				</Col>
			}
		/>
	);

	return (
		<AutoPage accent={Palette.coral}>
			<frame
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Change={{ AbsoluteSize: (frame: Frame) => setWidth(math.floor(frame.AbsoluteSize.X)) }}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
				{masthead}
				{tabRail}
				{tab === "Console" && consoleTab}
				{tab === "Show" && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<ShowRoomTab ctx={ctx} />
					</frame>
				)}
				{tab === "LiveOps" && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<LiveOpsTab ctx={ctx} />
					</frame>
				)}
				{tab === "Telemetry" && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<TelemetryTab ctx={ctx} />
					</frame>
				)}
				{tab === "Audit" && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<AuditTab ctx={ctx} />
					</frame>
				)}
			</frame>
		</AutoPage>
	);
}

export function AdminView(props: AdminProps) {
	const admin = props.state.Admin;
	if (!(admin !== undefined && admin.Access === true)) {
		return <EmptyState icon="Lock.17" title="Owner tools locked" body="Only the game owner can open this page." accent={Palette.coral} />;
	}
	return <AdminViewReady {...props} admin={admin} />;
}
