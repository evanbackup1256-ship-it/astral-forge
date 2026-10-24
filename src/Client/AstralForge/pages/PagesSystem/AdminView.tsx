import React from "@rbxts/react";
import { AdminConfig, BanEntry, fieldsFor, reasonsFor } from "../../CoreKit/adminFields";
import { compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { BODY, BODY_BOLD, Chip, Line, MockPanel, PanelHeading, panelPad } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow } from "../mockRows";
import { fitPanelHeight, MockTabs } from "../socialKit";
import { PHONE_HEAD_H as PH_HEAD_H, PhoneHead } from "../mockLayout";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useViewport } from "../../MotionKit/motion";
import { chromeFor } from "../../CoreKit/theme";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { named } from "../luauDeps";
import { AudioPlayer, BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import { FlexCol, FlexFill, FlexFixed, FlexRow } from "../mockLayout";
import { AdminLayout as A } from "../generated/AdminLayout";
import { AdminPhoneLayout as AP } from "../generated/AdminPhoneLayout";

const HttpService = game.GetService("HttpService");
const UserInputService = game.GetService("UserInputService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { Dropdown, EmptyState, SearchField } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");

const SCROLL_BAR = 4;

// design/22 .tabs order
const ADMIN_CATS = [
	{ id: "All", label: "ALL" },
	{ id: "LiveOps", label: "LIVE" },
	{ id: "Moderation", label: "MOD" },
	{ id: "Economy", label: "ECON" },
	{ id: "Items", label: "ITEMS" },
	{ id: "Progress", label: "PROG" },
	{ id: "Resets", label: "RESET" },
	{ id: "Troll", label: "TROLL" },
];
// phone.html .ph-head tabs: MOD (security + hot flags), LIVE (commands, announce, economy)
const PHONE_TABS = [
	{ id: "MOD", label: "MOD" },
	{ id: "LIVE", label: "LIVE" },
];

/** row title: the server label without its "(Option = ...)" hint */
function commandLabel(entry: AdminCommand): string {
	const label = entry.Label ?? entry.Id;
	return label.gsub("%s*%(Option = [^%)]+%)", "")[0];
}

/** row sub (mockup "player, reason"): what the command asks for */
function commandArgs(entry: AdminCommand, config: AdminConfig | undefined, banned: BanEntry[] | undefined): string {
	const fields = fieldsFor(entry.Id, config, banned);
	const parts: string[] = [];
	if (!fields.overridesTarget) parts.push("player");
	if (fields.usesAmount) parts.push(fields.amountLabel !== "" ? fields.amountLabel.lower() : "amount");
	if (fields.usesOption) parts.push(fields.optionLabel !== "" ? fields.optionLabel.lower() : "option");
	else if (entry.NeedsOption === true) {
		const [hint] = (entry.Label ?? "").match("%(Option = ([^%)]+)%)");
		parts.push(typeIs(hint, "string") ? hint.lower() : "option");
	}
	if (commandNeedsArm(entry)) parts.push("reason");
	return parts.join(", ");
}

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








function clockTime(at?: number) {
	return at !== undefined ? os.date("%H:%M", at) : "--:--";
}



function AdminViewReady({ state, config, dispatch, reducedMotion }: AdminProps) {
	const admin = state.Admin!;
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const viewport = useViewport();

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
	// ---------- design/22 structure ----------
	// desktop: full-width category .tabs, then .flexr: left column (security flags; rules | economy; announce)
	// and a 520 right column (commands with search + Run rows; hot flags). phone.html: .ph-head with MOD / LIVE.
	const phone = chromeFor(viewport).contentStack;
	const rowH = phone ? AP.FlagRow.h : A.FlagRow.h;
	const head = headingBlock(phone);
	const pad = panelPad(phone);
	const bodyGap = phone ? AP.Body.gap : A.Body.gap;
	const [phoneTab, setPhoneTab] = React.useState("MOD");
	const [announceText, setAnnounceText] = React.useState("");
	const [announceArmed, setAnnounceArmed] = React.useState(false);
	const [flagArmed, setFlagArmed] = React.useState<string | undefined>(undefined);
	const [runOpen, setRunOpen] = React.useState(false);

	// one-shot global commands (announce, hot flag) outside the arm / preview flow of the command runner
	const sendGlobal = (commandId: string, optionText: string, done?: (ok: boolean) => void) => {
		if (busyRef.current) return;
		busyRef.current = true;
		setBusy(true);
		const attempt = executeAttempt.current + 1;
		executeAttempt.current = attempt;
		Audio.play("adminExecute");
		const reasons = reasonsFor(commandId, "LiveOps");
		dispatch(
			"AdminExecute",
			{
				TargetUserId: admin.SelfUserId ?? targetId,
				Command: commandId,
				Amount: "1",
				Option: optionText,
				Reason: reasons[0] !== undefined ? reasons[0].id : "Owner gameplay administration",
				DryRun: false,
				Nonce: HttpService.GenerateGUID(false),
			},
			(response) => {
				if (!mountedRef.current || executeAttempt.current !== attempt) return;
				busyRef.current = false;
				setBusy(false);
				setLastOk(response.ok === true);
				setLastNote(response.ok === true ? (response.message ?? "Done.") : (response.error ?? "Failed."));
				if (response.ok !== true) setShakeToken((t) => t + 1);
				done?.(response.ok === true);
			},
		);
	};

	// SECURITY FLAGS: newest anti-cheat flags (chip kind, player, response, time)
	const flags = admin.SecurityFlags ?? [];
	const now = os.time();
	const todayCount = flags.filter((flag) => now - flag.At < 86400).size();
	const shownFlags = flags.filter((_, i) => i < 5);
	const securityH = fitPanelHeight(phone, head, (shownFlags.size() === 0 ? [rowH] : shownFlags.map(() => rowH)));
	const securityPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.coral} reveal={enter} reducedMotion={softMotion} name="AdminSecurity">
			<PanelHeading icon="Lock" title="Security flags" note={`${todayCount} today`} accent={Palette.coral} phone={phone} layoutOrder={0} />
			{shownFlags.size() === 0 ? (
				<MockRow phone={phone} icon="Check" title="No flags raised" sub="The anti-cheat has nothing to report." dim={true} height={rowH} layoutOrder={1} />
			) : (
				shownFlags.map((flag, i) => (
					<MockRow
						key={`sf${i}`}
						phone={phone}
						leadWidth={96} lead={<Chip text={flag.Kind} phone={phone} layoutOrder={0} />}
						title={flag.Name}
						sub={flag.Response}
						value={clockTime(flag.At)}
						accent={Palette.coral}
						height={rowH}
						layoutOrder={1 + i}
					/>
				))
			)}
		</MockPanel>
	);

	// ANTI-CHEAT RULES: rules that have had to repair a save
	const rules = (admin.AntiCheatRules ?? []).filter((rule) => rule.Repairs > 0);
	rules.sort((a, b) => a.Repairs > b.Repairs);
	const shownRules = rules.filter((_, i) => i < 3);
	// ECONOMY: the live-profile summary (the mockup's per-hour mint/spend/crate counters are not tracked)
	const economy = admin.Economy;
	const econRows =
		economy === undefined
			? []
			: [
					{ title: "Total Flux", value: compactNumber(economy.TotalCash ?? 0) },
					{ title: "Richest", value: compactNumber(economy.RichestCash ?? 0) },
					{ title: "Median rate", value: `${compactNumber(economy.MedianProduction ?? 0)}/s` },
				];
	const pairRows = math.max(1, shownRules.size(), econRows.size());
	const pairH = fitPanelHeight(phone, head, table.create(pairRows, rowH) as number[]);
	const rulesPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.steel} reducedMotion={softMotion} name="AdminRules">
			<PanelHeading icon="Lock" title="Anti-cheat rules" note={`${rules.size()} active`} accent={Palette.steel} phone={phone} layoutOrder={0} />
			{shownRules.size() === 0 ? (
				<MockRow phone={phone} icon="Check" title="No repairs yet" dim={true} height={rowH} layoutOrder={1} />
			) : (
				shownRules.map((rule, i) => (
					<MockRow key={`r${rule.Id}`} phone={phone} icon="Lock" title={`rule ${rule.Id}`} value={`${compactNumber(rule.Repairs)} fixed`} accent={Palette.steel} height={rowH} layoutOrder={1 + i} />
				))
			)}
		</MockPanel>
	);
	const economyPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.mint} reducedMotion={softMotion} name="AdminEconomy">
			<PanelHeading icon="Gem" title="Economy" note={economy !== undefined ? `${economy.Players ?? 0} live` : undefined} accent={Palette.mint} phone={phone} layoutOrder={0} />
			{econRows.size() === 0 ? (
				<MockRow phone={phone} icon="Gem" title="No live profiles" dim={true} height={rowH} layoutOrder={1} />
			) : (
				econRows.map((row, i) => <MockRow key={row.title} phone={phone} icon="Gem" title={row.title} value={row.value} accent={Palette.mint} height={rowH} layoutOrder={1 + i} />)
			)}
		</MockPanel>
	);

	// ANNOUNCE: one line to every server (Announce, two taps)
	const announceReady = announceText.gsub("%s", "")[0].size() >= 3 && !busy;
	const announceBtnW = phone ? 120 : A.AnnounceBtn.w;
	const announceFieldH = phone ? TapTarget : A.AnnounceBtn.h;
	const announceH = fitPanelHeight(phone, head, [announceFieldH]);
	const announcePanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reducedMotion={softMotion} name="AdminAnnounce">
			<PanelHeading icon="Command" title="Announce" note={`${(admin.Announcements ?? []).size()} sent`} accent={Palette.violet} phone={phone} layoutOrder={0} />
			<FlexRow height={announceFieldH} gap={phone ? 8 : A.AnnounceBtn.x - (A.AnnounceField.x + A.AnnounceField.w)} align={Enum.VerticalAlignment.Center} layoutOrder={1}>
				<FlexFill layoutOrder={0} height={phone ? announceFieldH : A.AnnounceField.h}>
					<SearchField
						value={announceText}
						onChange={(text: string) => {
							setAnnounceText(text);
							setAnnounceArmed(false);
						}}
						debounce={0}
						icon="Command"
						accent={Palette.violet}
						placeholder="Message to every server (140 max)"
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
					/>
				</FlexFill>
				<MockBtn
					text={announceArmed ? "Tap to confirm" : phone ? "Send" : "Send to all servers"}
					icon="Chevron"
					accent={announceArmed ? Palette.coral : undefined}
					width={announceBtnW}
					phone={phone}
					disabled={!announceReady}
					onClick={() => {
						if (!announceArmed) {
							setAnnounceArmed(true);
							Audio.play("adminArm");
							return;
						}
						setAnnounceArmed(false);
						sendGlobal("Announce", announceText, (ok) => ok && setAnnounceText(""));
					}}
					reducedMotion={softMotion}
					layoutOrder={1}
				/>
			</FlexRow>
		</MockPanel>
	);

	// COMMANDS: search, then label / args rows with Run; Run opens the runner (target, fields, preview, run)
	const cmdRowH = phone ? AP.FlagRow.h : A.CmdRow.h;
	const listRows = math.min(4, math.max(1, shownCommands.size()));
	const listH = listRows * cmdRowH + (listRows - 1) * pad.gap;
	const searchH = phone ? TapTarget : A.Search.h;
	const targetChoices = online.map((p) => ({ id: tostring(p.UserId), label: `${p.DisplayName} · @${p.Name}` }));
	const FIELD_H = phone ? TapTarget : 38;
	const runFieldCount = (fields.overridesTarget ? 0 : 1) + fieldSlots;
	const noteText =
		(optionMissing
			? `Fill in ${optionHint} above before you run this.`
			: lastNote !== ""
				? lastNote
				: needsArm
					? "Tap twice to run."
					: "Preview, then run.") + (previewLines.size() > 0 ? "\n• " + shownPreview.join("\n• ") : "") + (lookup !== undefined ? `\n${lookup.Name} · ${lookup.Score} · ${string.upper(lookup.Level)}` : "");
	const noteLines = 1 + math.min(previewLines.size(), 6) + (lookup !== undefined ? 1 : 0);
	const noteH = noteLines * 15 + 4;
	const runH = runOpen ? 22 + runFieldCount * (FIELD_H + pad.gap) + (phone ? TapTarget : 44) + pad.gap + noteH : 0;
	const commandsH = fitPanelHeight(phone, head, [searchH, listH], runOpen ? pad.gap + runH : 0);
	const runArea = runOpen && (
		<frame key="Runner" Size={new UDim2(1, 0, 0, runH)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={50} LayoutOrder={3}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, pad.gap)} />
			<FlexRow height={22} gap={8} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<Line text={(selected && selected.Label) ?? command} size={15} font={BODY_BOLD} color={armed ? Palette.coral : accent} layoutOrder={0} />
				<FlexFill layoutOrder={1} height={22}>
					<Line text={needsArm ? "needs arming" : "quick"} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={22} align={Enum.TextXAlignment.Right} />
				</FlexFill>
			</FlexRow>
			{!fields.overridesTarget && (
				<frame Size={new UDim2(1, 0, 0, FIELD_H)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={54}>
					<Dropdown
						options={targetChoices.size() > 0 ? targetChoices : [{ id: "0", label: "No players online" }]}
						value={tostring(targetId)}
						onChange={(id: string) => setTargetId(tonumber(id) ?? 0)}
						accent={Palette.cyan}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						zIndex={90}
					/>
				</frame>
			)}
			{fields.usesAmount && (
				<frame Size={new UDim2(1, 0, 0, FIELD_H)} BackgroundTransparency={1} LayoutOrder={2} ZIndex={53}>
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
				<frame Size={new UDim2(1, 0, 0, FIELD_H)} BackgroundTransparency={1} LayoutOrder={3} ZIndex={52}>
					<Dropdown options={fields.optionChoices} value={option} onChange={setOption} accent={Palette.cyan} size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} zIndex={70} />
				</frame>
			)}
			{typedOption && (
				<frame Size={new UDim2(1, 0, 0, FIELD_H)} BackgroundTransparency={1} LayoutOrder={3} ZIndex={52}>
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
				<frame Size={new UDim2(1, 0, 0, FIELD_H)} BackgroundTransparency={1} LayoutOrder={4} ZIndex={51}>
					<Dropdown options={reasonChoices} value={reason} onChange={setReason} accent={Palette.steel} size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} zIndex={60} />
				</frame>
			)}
			<frame key="AdminExecuteActions" Size={new UDim2(1, 0, 0, phone ? TapTarget : 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5} ref={executeActionsHostRef}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalFlex={Enum.UIFlexAlignment.Fill} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<MockBtn text="Close" icon="Close.9" sec={true} phone={phone} fill={true} onClick={() => setRunOpen(false)} reducedMotion={softMotion} layoutOrder={0} />
				<MockBtn text="Preview" icon="Search.8" sec={true} phone={phone} fill={true} disabled={runDisabled} onClick={preview} reducedMotion={softMotion} layoutOrder={1} />
				<MockBtn
					text={busy ? "Applying" : needsArm && !armed ? "Arm" : "Run"}
					icon="Lock.16"
					accent={needsArm && armed ? Palette.coral : needsArm ? Palette.mango : undefined}
					phone={phone}
					fill={true}
					disabled={runDisabled}
					onClick={execute}
					reducedMotion={softMotion}
					layoutOrder={2}
				/>
			</frame>
			<Line
				text={noteText}
				size={12}
				font={BODY}
				color={optionMissing ? Palette.coral : lastNote !== "" ? (lastOk ? Palette.mint : Palette.coral) : Palette.muted}
				width={new UDim(1, 0)}
				height={noteH}
				layoutOrder={6}
			/>
		</frame>
	);
	const commandsPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reducedMotion={softMotion} name="AdminCommands">
			<PanelHeading icon="Command" title="Commands" note={`${shownCommands.size()} of ${commands.size()}`} accent={Palette.violet} phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, searchH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<SearchField value={commandQuery} onChange={setCommandQuery} accent={Palette.violet} placeholder="Search commands" size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} />
			</frame>
			<frame key="List" Size={new UDim2(1, 0, 0, listH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				{shownCommands.size() === 0 ? (
					<MockRow phone={phone} icon="Search.8" title="No commands match" dim={true} height={cmdRowH} />
				) : (
					<FlatList
						data={shownCommands}
						itemHeight={cmdRowH + pad.gap}
						overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
						canvasTail={0}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.violet}
						scrollBarThickness={SCROLL_BAR}
						keyExtractor={(entry: AdminCommand) => entry.Id}
						renderItem={({ item: entry, index }: { item: AdminCommand; index: number }) => (
							<MockRow
								phone={phone}
								title={commandLabel(entry)}
								sub={commandArgs(entry, config, admin.Banned)}
								outline={runOpen && entry.Id === command ? catAccent(entry.Category) : undefined}
								height={cmdRowH}
								right={
									<MockBtn
										text="Run"
										sec={true}
										sm={true}
										width={A.CmdRun.w}
										onClick={() => {
											setCommand(entry.Id);
											setRunOpen(true);
										}}
										reducedMotion={softMotion}
									/>
								}
								rightWidth={A.CmdRun.w}
								layoutOrder={index + 1}
							/>
						)}
					/>
				)}
			</frame>
			{runArea}
		</MockPanel>
	);

	// HOT FLAGS: live toggles (ToggleHotFlag "Name=on|off", two taps)
	const hotFlags = admin.HotFlags ?? [];
	const shownHot = hotFlags.filter((_, i) => i < 3);
	const hotH = fitPanelHeight(phone, head, shownHot.size() === 0 ? [rowH] : shownHot.map(() => rowH));
	const hotPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.mango} reducedMotion={softMotion} name="AdminHot">
			<PanelHeading icon="Overcharge.9" title="Hot flags" note={hotFlags.size() > 3 ? `${hotFlags.size()} flags` : undefined} phone={phone} layoutOrder={0} />
			{shownHot.size() === 0 ? (
				<MockRow phone={phone} icon="Overcharge.9" title="No hot flags configured" dim={true} height={rowH} layoutOrder={1} />
			) : (
				shownHot.map((flag, i) => (
					<frame key={flag.Name} Size={new UDim2(1, 0, 0, rowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1 + i}>
						<MockRow
							phone={phone}
							icon="Overcharge.9"
							accent={flag.On ? Palette.coral : Palette.mango}
							title={flag.Name}
							value={flagArmed === flag.Name ? (flag.On ? "turn off?" : "turn on?") : flag.On ? "ON" : "off"}
							valueColor={flag.On ? Palette.coral : Palette.muted}
							outline={flagArmed === flag.Name ? Palette.coral : undefined}
							height={rowH}
						/>
						<textbutton
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							Text=""
							ZIndex={3}
							Event={{
								Activated: () => {
									if (flagArmed !== flag.Name) {
										setFlagArmed(flag.Name);
										Audio.play("adminArm");
										return;
									}
									setFlagArmed(undefined);
									sendGlobal("ToggleHotFlag", `${flag.Name}=${flag.On ? "off" : "on"}`);
								},
							}}
						/>
					</frame>
				))
			)}
		</MockPanel>
	);

	const focusHostRef = React.useRef<Frame>();
	useFocusOrder(
		focusHostRef,
		{
			regions: ["AdminTabs", "AdminCommands", "AdminHot", "AdminSecurity", "AdminAnnounce"],
			first: ["AdminCommands"],
		},
		[phone],
	);

	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (phone) {
		sections.push({
			id: "head",
			height: PH_HEAD_H,
			element: (
				<PhoneHead line={admin.Role ?? "Owner"} options={PHONE_TABS} value={phoneTab} onChange={(id) => setPhoneTab(id)} accent={Palette.coral} reducedMotion={softMotion} />
			),
		});
		if (phoneTab === "MOD") {
			const h = math.max(securityH, hotH);
			sections.push({
				id: "mod",
				height: h,
				element: (
					<FlexRow fillHeight={true} gap={bodyGap} name="AdminMod">
						<FlexFill layoutOrder={0}>{securityPanel}</FlexFill>
						<FlexFill layoutOrder={1}>{hotPanel}</FlexFill>
					</FlexRow>
				),
			});
			sections.push({ id: "rules", height: pairH, element: rulesPanel });
		} else {
			sections.push({ id: "commands", height: commandsH, element: commandsPanel });
			sections.push({ id: "announce", height: announceH, element: announcePanel });
			sections.push({ id: "economy", height: pairH, element: economyPanel });
		}
	} else {
		const tabsH = A.Tabs.h;
		const leftH = securityH + bodyGap + pairH + bodyGap + announceH;
		const rightH = commandsH + bodyGap + hotH;
		const bodyH = math.max(leftH, rightH);
		sections.push({
			id: "tabs",
			height: tabsH,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} {...named("AdminTabs")}>
					<MockTabs
						options={ADMIN_CATS}
						value={category}
						onChange={(id) => setCategory(id)}
						accent={Palette.coral}
						phone={false}
						wide={true}
						tabHeight={A.TabOn.h}
						padX={A.TabOn.pad.left}
						reducedMotion={softMotion}
					/>
				</frame>
			),
		});
		sections.push({
			id: "body",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={A.Body.gap} name="AdminBody">
					<FlexFill layoutOrder={0}>
						<FlexCol fill={true} gap={A.Left.gap}>
							<FlexFixed width={A.Left.w} height={securityH} layoutOrder={0}>
								{securityPanel}
							</FlexFixed>
							<frame Size={new UDim2(1, 0, 0, pairH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
								<FlexRow fillHeight={true} gap={A.Pair.gap}>
									<FlexFill layoutOrder={0}>{rulesPanel}</FlexFill>
									<FlexFill layoutOrder={1}>{economyPanel}</FlexFill>
								</FlexRow>
							</frame>
							<frame Size={new UDim2(1, 0, 0, announceH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
								{announcePanel}
							</frame>
						</FlexCol>
					</FlexFill>
					<FlexFixed width={A.Right.w} layoutOrder={1}>
						<FlexCol fill={true} gap={A.Right.gap}>
							<frame Size={new UDim2(1, 0, 0, commandsH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
								{commandsPanel}
							</frame>
							<frame Size={new UDim2(1, 0, 0, hotH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
								{hotPanel}
							</frame>
						</FlexCol>
					</FlexFixed>
				</FlexRow>
			),
		});
	}

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ref={focusHostRef}>
			<PageScaffold gap={bodyGap} tailPad={8} scrollBarColor={Palette.steel} scrollBarThickness={4} sections={sections} />
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
