// The Crew page: everyone on this server (wave, visit their forge), your crew (members, the shared
// daily goal and its rewards, leave/rename/remove), invites, and the forge you're visiting.
import React from "@rbxts/react";
import CrewMath = require("../../../../Shared/AstralForge/Shared/CrewMath");
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import { PlayerMark } from "../../ArtKit/Icon";
import { AppHelpers } from "../../CoreKit/appNav";
import { asFlux, compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { KeyLabel } from "../../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../../CoreKit/interaction";
import * as PageBoardHeights from "../../CoreKit/pageBoardHeights";
import { frameStroke } from "../../CoreKit/profileFrame";
import { chromeFor, darken, lighten, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import CrewStore = require("../../CrewStore");
import Juice = require("../../JuiceFx");
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { NumberSpinnerHost } from "../../ReactHosts/NumberSpinnerHost";
import { Button, EmptyState, Meter, meterFill, Panel, Text } from "../../UiCore/ui";
import { requestConfirm } from "../../UiOverlays/ConfirmDialog";
import { Component, loadBrowse, loadPageScaffold, luauKit, named } from "../luauDeps";
import { STICKY_H, StickyGroup, StickyGroupLabel } from "./StickyGroupLabel";

const Players = game.GetService("Players");
const ContextActionService = game.GetService("ContextActionService");
const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const Browse = loadBrowse();
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;
const PageReadyMath = luauKit<{ SameCrewSnapshot: (left: unknown, right: unknown) => boolean }>("LayoutKit", "pageReadyMath");

// phone height for other players' roster rows: mark, two text lines, then the Wave/Visit row
const CREW_COMPACT_ROW_H = 136;
const GAP = 10;

/** One player on this server, as GetPlayers sends them. */
interface RosterPlayer {
	UserId: number;
	DisplayName: string;
	IsLocal?: boolean;
	CurrentZone?: number;
	CurrentPage?: string;
	Production?: unknown;
	Rebirths?: number;
	PresenceAge?: number;
}
interface CrewMember {
	UserId: number;
	DisplayName: string;
	Leader?: boolean;
	Collects: number;
}
interface CrewTier {
	Target: number;
	Stardust: number;
	Claimed?: boolean;
}
interface Crew {
	Name: string;
	Leader: number;
	Members: CrewMember[];
	Max: number;
	Bonus?: number;
	Pooled: number;
	Tiers: CrewTier[];
	MinContribution: number;
}
interface Invite {
	FromName: string;
	CrewName: string;
	ExpiresAt?: number;
}
/** The forge being visited (VisitPlot). */
interface Visit {
	UserId: number;
	DisplayName: string;
	CurrentZone?: number;
	Rebirths?: number;
	Production?: unknown;
	Cash?: unknown;
	Cores?: unknown;
	Stardust?: unknown;
	Vault?: unknown;
	Capacity?: unknown;
	Machines?: Record<string, number>;
	MachineKinds?: number;
}
interface Reply {
	ok?: boolean;
	error?: string;
	message?: string;
	Uncertain?: boolean;
	Crew?: Crew;
	Invite?: Invite;
	Players?: RosterPlayer[];
	Visit?: Visit;
	State?: { Visit?: Visit };
}
type Dispatch = (action: string, payload?: object, callback?: (response: Reply) => void) => unknown;
interface Props {
	state: { CurrentZone?: number; Visitors?: unknown[] };
	dispatch: Dispatch;
	reducedMotion?: boolean;
	visit?: Visit;
	setVisit: (visit: Visit) => void;
}
interface Section {
	id: string;
	height?: number;
	fill?: boolean;
	minHeight?: number;
	element: React.Element;
}

/** `list` with the items matching `pinned` moved to the front, each half keeping its order. */
function pinFirst<T extends defined>(list: T[], pinned: (item: T) => boolean): T[] {
	const front = list.filter(pinned);
	for (const item of list) if (!pinned(item)) front.push(item);
	return front;
}

// How long since a crewmate last did anything, from the presence age the server already sends.
// Fresh activity needs no note (the line turns mint); older activity says how long they've been quiet.
function presenceNote(age: number | undefined): string {
	if (age === undefined || age < 12) return "";
	if (age < 60) return " · a moment ago";
	if (age < 3600) return ` · quiet for ${math.floor(age / 60)}m`;
	return ` · quiet for ${math.floor(age / 3600)}h`;
}

// quiet = no activity for a minute or more (the line already reads "quiet for Nm")
const isQuiet = (player: RosterPlayer) => (player.PresenceAge ?? 0) >= 60;

/** A whole, non-zero user id from whatever the server sent, or undefined. */
function coerceCrewId(raw: unknown): number | undefined {
	const asNumber = typeIs(raw, "number") ? raw : typeIs(raw, "string") ? tonumber(raw) : undefined;
	if (asNumber === undefined || asNumber !== asNumber) return undefined;
	const id = math.floor(asNumber + (asNumber >= 0 ? 1e-9 : -1e-9));
	return id === 0 ? undefined : id;
}

/** The player's published profile style (ring frame, accent), if they're in this server. */
function profileStyleOf(player: RosterPlayer) {
	return ProfileStyle.fromPlayer(Players.GetPlayerByUserId(player.UserId));
}

// gamepad: while focus is on a crewmate's Wave/Visit buttons, X waves and Y visits, and the two
// buttons show those keys. Elsewhere X/Y pass through to the shell (Overcharge / Vault).
let crewKeyBindings = 0;
function useCrewRowKeys(holder: React.MutableRefObject<Frame | undefined>, onWave: () => void, onVisit: (() => void) | undefined, enabled: boolean): boolean {
	const [focused, setFocused] = React.useState(false);
	const handlers = React.useRef({ onWave, onVisit });
	handlers.current = { onWave, onVisit };
	React.useEffect(() => {
		if (!enabled) {
			setFocused(false);
			return undefined;
		}
		const inside = () => {
			const selected = GuiService.SelectedObject;
			const frame = holder.current;
			return selected !== undefined && frame !== undefined && selected.IsDescendantOf(frame);
		};
		const sync = () => setFocused(UserInputService.GamepadEnabled && inside());
		sync();
		const selection = GuiService.GetPropertyChangedSignal("SelectedObject").Connect(sync);
		crewKeyBindings += 1;
		const name = `AstralForgeCrewRowKeys${crewKeyBindings}`;
		ContextActionService.BindActionAtPriority(
			name,
			(_, inputState, input) => {
				if (inputState !== Enum.UserInputState.Begin || !inside()) return Enum.ContextActionResult.Pass;
				const run = input.KeyCode === Enum.KeyCode.ButtonX ? handlers.current.onWave : handlers.current.onVisit;
				if (run === undefined) return Enum.ContextActionResult.Pass;
				run();
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonX,
			Enum.KeyCode.ButtonY,
		);
		return () => {
			selection.Disconnect();
			ContextActionService.UnbindAction(name);
		};
	}, [enabled]);
	return focused;
}

interface RowProps {
	player: RosterPlayer;
	visiting: boolean;
	visitorsHere: number;
	onVisit: () => void;
	onNudge: () => void;
	waveShake: number;
	reducedMotion?: boolean;
	layoutOrder: number;
	stack: boolean;
}

/** One player on the server: mark, name, world and output, what they're doing, and Wave / Visit. */
function CrewRow({ player, visiting, visitorsHere, onVisit, onNudge, waveShake, reducedMotion, layoutOrder, stack }: RowProps) {
	const isLocal = player.IsLocal === true;
	const reveal = useStagger(math.min(layoutOrder, 8), reducedMotion);
	const keysRef = React.useRef<Frame>();
	const keysFocused = useCrewRowKeys(keysRef, onNudge, visiting ? undefined : onVisit, !isLocal);
	const waveText = keysFocused ? `WAVE · ${KeyLabel(Enum.KeyCode.ButtonX, "X")}` : "WAVE";
	const visitText = keysFocused && !visiting ? `VISIT · ${KeyLabel(Enum.KeyCode.ButtonY, "Y")}` : visiting ? "HERE" : "VISIT";
	const style = profileStyleOf(player);
	const accent = style.accent ?? (isLocal ? Palette.green : Palette.blue);
	// the player's chosen profile frame on their mark ring, same treatment as chat and the Rank rows
	const markRing = frameStroke(style.frame, accent);
	// phones: other players' rows tighten up (smaller mark, lines closer); buttons keep full tap size
	const compactRow = stack && !isLocal;
	const textX = compactRow ? 46 : 58;
	const markSize = compactRow ? 36 : stack ? 48 : 44;
	const rowH = stack ? (isLocal ? 118 : CREW_COMPACT_ROW_H) : 100;
	const lineWidth = new UDim2(1, stack ? -(58 + 16) : -16, 0, 16);
	const fresh = player.PresenceAge !== undefined && player.PresenceAge >= 0 && player.PresenceAge < 12;
	const wave = (size: UDim2, icon: string, hug: boolean) => (
		<Button
			text={waveText}
			icon={icon}
			onClick={onNudge}
			shakeToken={waveShake}
			color={Palette.cyan}
			textColor={Palette.ink}
			size={size}
			hug={hug}
			reducedMotion={reducedMotion}
		/>
	);
	const visitButton = (size: UDim2, icon: string, hug: boolean) => (
		<Button
			text={visitText}
			icon={icon}
			onClick={onVisit}
			color={visiting ? Palette.green : Palette.blue}
			textColor={Palette.ink}
			size={size}
			hug={hug}
			reducedMotion={reducedMotion}
			disabled={visiting}
			highlight={visiting}
		/>
	);
	return (
		<Panel
			size={new UDim2(1, -4, 0, rowH)}
			accent={accent}
			background={visiting ? Palette.panelRaised : Palette.panel}
			padding={stack ? 14 : 12}
			layoutOrder={layoutOrder}
			reveal={reveal}
			interactive={!isLocal}
			highlight={visiting}
			reducedMotion={reducedMotion}
			clips={false}
		>
			<frame
				Size={UDim2.fromOffset(markSize, markSize)}
				Position={UDim2.fromOffset(0, compactRow ? 4 : stack ? 8 : 14)}
				BackgroundColor3={darken(accent, 0.62)}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Color={new ColorSequence(lighten(accent, 0.12), darken(accent, 0.48))} Rotation={120} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={markRing.color}
					Thickness={markRing.thickness}
					Transparency={markRing.framed ? 0 : 0.32}
				>
					{markRing.gradient !== undefined && <uigradient Color={markRing.gradient} Rotation={35} />}
				</uistroke>
				<PlayerMark
					userId={player.UserId}
					color={Palette.ink}
					accent={accent}
					size={compactRow ? 30 : stack ? 42 : 38}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
				/>
			</frame>
			<Text
				value={isLocal ? "YOU" : player.DisplayName}
				size={stack ? 17 : 16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(textX, compactRow ? 0 : 2)}
				sizeConstraint={new UDim2(1, stack ? -(58 + 16) : -280, 0, 22)}
			/>
			<Text
				value={`World ${player.CurrentZone}`}
				size={stack ? 12 : 10}
				color={Palette.muted}
				position={UDim2.fromOffset(textX, compactRow ? 22 : 28)}
				sizeConstraint={UDim2.fromOffset(80, 16)}
			/>
			<Text
				value={`${compactNumber(player.Production)} /s`}
				size={stack ? 12 : 10}
				color={Palette.muted}
				position={UDim2.fromOffset(textX + 86, compactRow ? 22 : 28)}
				sizeConstraint={new UDim2(1, -160, 0, 16)}
			/>
			{!isLocal && (
				<Text
					value={`Browsing ${AppHelpers.pageEntry(player.CurrentPage ?? "Overview").label}${presenceNote(player.PresenceAge)}`}
					size={stack ? 11 : 9}
					color={fresh ? Palette.mint : Palette.muted}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={8}
					position={UDim2.fromOffset(textX, compactRow ? 40 : stack ? 52 : 56)}
					sizeConstraint={lineWidth}
				/>
			)}
			{isLocal ? (
				<Text
					value={visitorsHere > 0 ? `${visitorsHere} visiting your shop` : `${player.Rebirths} resets`}
					size={stack ? 12 : 10}
					color={visitorsHere > 0 ? Palette.mango : accent}
					weight={Enum.FontWeight.Bold}
					position={UDim2.fromOffset(58, stack ? 52 : 56)}
					sizeConstraint={new UDim2(1, stack ? -(58 + 16) : -16, 0, 18)}
				/>
			) : stack ? (
				<frame ref={keysRef} Size={new UDim2(1, 0, 0, TapTarget)} Position={new UDim2(0, 0, 1, -(TapTarget + 2))} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						HorizontalAlignment={Enum.HorizontalAlignment.Left}
						Padding={new UDim(0, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					<frame Size={new UDim2(0.5, -4, 0, TapTarget)} LayoutOrder={1} BackgroundTransparency={1} BorderSizePixel={0}>
						{wave(UDim2.fromScale(1, 1), "Wave.5", false)}
					</frame>
					<frame {...named("CrewVisitConfirm")} Size={new UDim2(0.5, -4, 0, TapTarget)} LayoutOrder={2} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
						{visitButton(UDim2.fromScale(1, 1), "Visit.2", false)}
					</frame>
				</frame>
			) : (
				<frame
					ref={keysRef}
					Size={UDim2.fromOffset(0, TapTarget)}
					AutomaticSize={Enum.AutomaticSize.X}
					AnchorPoint={new Vector2(1, 0.5)}
					Position={new UDim2(1, -6, 0.5, 0)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						HorizontalAlignment={Enum.HorizontalAlignment.Right}
						Padding={new UDim(0, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{wave(UDim2.fromOffset(0, TapTarget), "Wave.6", true)}
					<frame
						{...named("CrewVisitConfirm")}
						Size={UDim2.fromOffset(0, TapTarget)}
						AutomaticSize={Enum.AutomaticSize.X}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
						LayoutOrder={2}
					>
						{visitButton(UDim2.fromOffset(0, TapTarget), "Visit.3", true)}
					</frame>
				</frame>
			)}
		</Panel>
	);
}

/** The forge you're visiting: its owner, live numbers, vault and a few machines, and Leave. */
function VisitPanel({ visit, dispatch, reducedMotion, layoutOrder, stack }: { visit: Visit; dispatch: Dispatch; reducedMotion?: boolean; layoutOrder: number; stack: boolean }) {
	const reveal = useStagger(0, reducedMotion);
	const vaultFill = meterFill(asFlux(visit.Vault), asFlux(visit.Capacity));
	const machineBits: string[] = [];
	for (const [id, level] of pairs(visit.Machines ?? {})) {
		if (machineBits.size() < 4) machineBits.push(`${id} ${level}`);
	}
	const kinds = visit.MachineKinds ?? 0;
	const machineLine =
		machineBits.size() > 0 ? `${kinds} ${kinds === 1 ? "line" : "lines"} · ${machineBits.filter((_, i) => i < 3).join("  ·  ")}` : "No machines built yet";
	const headWidth = new UDim2(1, stack ? 0 : -160, 0, 0);
	const stats = [
		{ label: "Flux/s", value: visit.Production, color: Palette.green },
		{ label: "Balance", value: visit.Cash, color: Palette.cream },
		{ label: "Cores", value: visit.Cores, color: Palette.violet },
		{ label: "Stardust", value: visit.Stardust, color: Palette.cyan },
	];
	return (
		<Panel
			size={new UDim2(1, 0, 0, PageBoardHeights.Visit(stack))}
			accent={Palette.blue}
			background={Palette.panelRaised}
			padding={16}
			layoutOrder={layoutOrder}
			reveal={reveal}
			highlight={true}
			reducedMotion={reducedMotion}
			clips={false}
		>
			<Text value="VISITING" size={10} color={Palette.blue} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(headWidth.X, new UDim(0, 16))} />
			<Text
				value={visit.DisplayName}
				size={22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(0, 20)}
				sizeConstraint={new UDim2(headWidth.X, new UDim(0, 30))}
			/>
			<Text
				value={`World ${visit.CurrentZone}  ·  ${visit.Rebirths} resets  ·  live`}
				size={11}
				color={Palette.creamSoft}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 54)}
				sizeConstraint={new UDim2(headWidth.X, new UDim(0, 18))}
			/>
			<Button
				text="LEAVE"
				icon="Close.3"
				onClick={() => dispatch("LeavePlot")}
				color={Palette.panelSoft}
				textColor={Palette.creamSoft}
				size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(120, 40)}
				position={stack ? new UDim2(0, 0, 1, -(TapTarget + 4)) : new UDim2(1, -120, 0, 12)}
				reducedMotion={reducedMotion}
			/>
			<frame Size={new UDim2(1, 0, 0, stack ? 152 : 72)} Position={UDim2.fromOffset(0, stack ? 76 : 86)} BackgroundTransparency={1} BorderSizePixel={0}>
				{stats.map((stat, index) => (
					<frame
						key={stat.label}
						Size={stack ? new UDim2(0.5, -4, 0, 72) : new UDim2(0.25, -6, 1, 0)}
						Position={
							stack
								? new UDim2(index % 2 === 0 ? 0 : 0.5, index % 2 === 0 ? 0 : 4, 0, index < 2 ? 0 : 80)
								: new UDim2(index * 0.25, index === 0 ? 0 : 2, 0, 0)
						}
						BackgroundColor3={Palette.panel}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(0, 10)} />
						<Text value={stat.label} size={9} color={Palette.muted} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(10, 10)} sizeConstraint={new UDim2(1, -20, 0, 14)} />
						<NumberSpinnerHost
							value={asFlux(stat.value)}
							reducedMotion={reducedMotion}
							duration={0.4}
							size={16}
							color={stat.color}
							position={UDim2.fromOffset(10, 32)}
							sizeConstraint={new UDim2(1, -20, 0, 24)}
						/>
					</frame>
				))}
			</frame>
			<Text
				value={`Vault ${compactNumber(visit.Vault)} / ${compactNumber(visit.Capacity)}`}
				size={10}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, stack ? 238 : 170)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Meter value={vaultFill} color={Palette.blue} reducedMotion={reducedMotion} position={UDim2.fromOffset(0, stack ? 258 : 192)} size={new UDim2(1, 0, 0, 7)} />
			<Text
				value={machineLine}
				size={10}
				color={Palette.creamSoft}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, stack ? 274 : 210)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
		</Panel>
	);
}

interface PartyArgs {
	crew?: Crew;
	invite?: Invite;
	players: RosterPlayer[];
	dispatch: Dispatch;
	stack: boolean;
	softMotion?: boolean;
	renameDraft: string;
	setRenameDraft: (value: string) => void;
	note: string;
	setNote: (value: string) => void;
	confirmKey?: string;
	setConfirmKey: (value: string | undefined) => void;
}

/** The party block above the server roster: invite card, crew summary, members, goal and actions. */
function crewPartySections(args: PartyArgs): Section[] {
	const { crew, invite, players, dispatch, stack, softMotion, renameDraft, setRenameDraft, setConfirmKey } = args;
	const localId = Players.LocalPlayer.UserId;
	const sections: Section[] = [];
	const run = (action: string, payload?: object) =>
		dispatch(action, payload ?? {}, (response) => {
			if (!typeIs(response, "table")) return;
			if (action === "GetCrew" || response.Crew !== undefined || response.Invite !== undefined) {
				CrewStore.set({ crew: response.Crew ?? CrewStore.NONE });
			}
			args.setNote(response.ok === false ? (response.error ?? "That didn't work.") : (response.message ?? ""));
		});
	const text = (value: string, size: number, color: Color3, height: number, weight?: Enum.FontWeight) => (
		<Text value={value} size={size} color={color} wrap={true} fit={true} minSize={11} weight={weight} sizeConstraint={new UDim2(1, 0, 0, height)} />
	);
	// leaving or removing someone goes through a confirm dialog, so a stray click can't break up a crew
	const confirmed = (key: string, action: string, payload?: object) => {
		const leaving = key === "leave";
		setConfirmKey(key);
		requestConfirm({
			title: leaving ? "Leave your crew?" : "Remove this member?",
			body: leaving ? "You can rejoin later if someone invites you." : "They can be invited back later.",
			confirmText: leaving ? "Leave" : "Remove",
			tone: "danger",
			onConfirm: () => {
				setConfirmKey(undefined);
				run(action, payload);
			},
			onCancel: () => setConfirmKey(undefined),
		});
	};
	const armed = (key: string) => args.confirmKey === key;

	if (invite !== undefined && (invite.ExpiresAt ?? 0) > os.time()) {
		const respond = (accept: boolean) => {
			CrewStore.set({ invite: CrewStore.NONE });
			run("CrewRespond", { Accept: accept });
		};
		sections.push({
			id: "crew-invite",
			height: stack ? 46 + TapTarget * 2 + GAP + 28 : 104,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panelRaised} padding={14} clips={false}>
					{text(`${invite.FromName} invited you to ${invite.CrewName}.`, 17, Palette.cream, 44, Enum.FontWeight.Heavy)}
					<Button
						text="Join crew"
						icon="Crew.5"
						color={Palette.mango}
						textColor={Palette.ink}
						size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(160, TapTarget)}
						position={stack ? UDim2.fromOffset(0, 46) : new UDim2(1, -330 - GAP, 0, 34)}
						reducedMotion={softMotion}
						onClick={() => respond(true)}
					/>
					<Button
						text="Decline"
						color={Palette.panelSoft}
						textColor={Palette.cream}
						outline={true}
						size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(160, TapTarget)}
						position={stack ? UDim2.fromOffset(0, 46 + TapTarget + GAP) : new UDim2(1, -160, 0, 34)}
						reducedMotion={softMotion}
						onClick={() => respond(false)}
					/>
				</Panel>
			),
		});
	}

	const leader = crew !== undefined && crew.Leader === localId;
	if (crew !== undefined) {
		const bonus = math.floor((crew.Bonus ?? 0) * 100 + 0.5);
		sections.push({
			id: "crew-summary",
			height: 96,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.green} background={Palette.panelRaised} padding={14} clips={false}>
					{text(crew.Name, 22, Palette.cream, 30, Enum.FontWeight.Heavy)}
					<Text
						value={`${crew.Members.size()} of ${crew.Max} members · +${bonus}% production while you play together · crew chat is in Chat`}
						size={14}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, 34)}
						sizeConstraint={new UDim2(1, 0, 0, 40)}
					/>
				</Panel>
			),
		});
		// you first, then the leader, then everyone else in server order
		const orderedMembers = pinFirst(
			pinFirst(crew.Members ?? [], (member) => member.Leader === true),
			(member) => member.UserId === localId,
		);
		for (const member of orderedMembers) {
			const you = member.UserId === localId;
			const kickKey = `kick-${member.UserId}`;
			sections.push({
				id: `crew-member-${member.UserId}`,
				height: 56,
				element: (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panel} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(0, 12)} />
						<Text
							value={`${member.DisplayName}${member.Leader ? "  ·  leader" : ""}${you ? "  ·  you" : ""}`}
							size={16}
							color={Palette.cream}
							weight={Enum.FontWeight.Bold}
							position={UDim2.fromOffset(14, 6)}
							sizeConstraint={new UDim2(1, -140, 0, 22)}
						/>
						<Text
							value={`${member.Collects} collect${member.Collects === 1 ? "" : "s"} today`}
							size={13}
							color={Palette.muted}
							position={UDim2.fromOffset(14, 30)}
							sizeConstraint={new UDim2(1, -140, 0, 18)}
						/>
						{!you && (
							<Button
								text="Visit"
								icon="Visit.4"
								color={Palette.blue}
								textColor={Palette.ink}
								size={UDim2.fromOffset(104, 44)}
								position={new UDim2(1, leader ? -236 : -110, 0.5, -22)}
								reducedMotion={softMotion}
								onClick={() => dispatch("VisitPlot", { UserId: member.UserId })}
							/>
						)}
						{leader && !you && (
							<Button
								text="Remove"
								color={armed(kickKey) ? Palette.coral : Palette.panelSoft}
								textColor={armed(kickKey) ? Palette.ink : Palette.cream}
								outline={!armed(kickKey)}
								size={UDim2.fromOffset(112, 44)}
								position={new UDim2(1, -118, 0.5, -22)}
								reducedMotion={softMotion}
								onClick={() => confirmed(kickKey, "CrewKick", { UserId: member.UserId })}
							/>
						)}
					</frame>
				),
			});
		}

		// the daily goal: one meter to the next tier, then a claim button per tier
		const nextTier = crew.Tiers.find((tier) => crew.Pooled < tier.Target);
		const mine = crew.Members.find((member) => member.UserId === localId)?.Collects ?? 0;
		const owed = crew.MinContribution - mine;
		const columns = stack ? 1 : 3;
		const cellW = 1 / columns;
		const goalRows = math.ceil(crew.Tiers.size() / columns);
		sections.push({
			id: "crew-goal",
			height: 68 + goalRows * (TapTarget + GAP) + 28,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.green} background={Palette.panelRaised} padding={14} clips={false}>
					{text(
						nextTier !== undefined
							? `Crew goal: ${crew.Pooled} / ${nextTier.Target} vault collects today`
							: `Every crew goal is done today (${crew.Pooled} collects).`,
						16,
						Palette.cream,
						22,
						Enum.FontWeight.Bold,
					)}
					<Meter
						value={nextTier !== undefined ? math.clamp(crew.Pooled / nextTier.Target, 0, 1) : 1}
						color={Palette.green}
						reducedMotion={softMotion}
						position={UDim2.fromOffset(0, 28)}
						size={new UDim2(1, 0, 0, 8)}
					/>
					<Text
						value={owed > 0 ? `Collect your vault ${owed} more time${owed === 1 ? "" : "s"} to share the rewards.` : "You've pitched in enough to share every reward."}
						size={13}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, 42)}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
					{crew.Tiers.map((tier, i) => {
						const reached = crew.Pooled >= tier.Target;
						const ready = reached && !tier.Claimed && mine >= crew.MinContribution;
						return (
							<Button
								key={`tier-${i + 1}`}
								text={tier.Claimed ? `Claimed · ${tier.Stardust} dust` : reached ? `Claim ${tier.Stardust} dust` : `${tier.Target} collects · ${tier.Stardust} dust`}
								color={ready ? Palette.green : Palette.panelSoft}
								textColor={ready ? Palette.ink : Palette.muted}
								disabled={!ready}
								highlight={ready}
								reducedMotion={softMotion}
								size={new UDim2(cellW, -GAP, 0, TapTarget)}
								position={new UDim2((i % columns) * cellW, 0, 0, 68 + math.floor(i / columns) * (TapTarget + GAP))}
								onClick={() => run("CrewClaim", { Tier: i + 1 })}
							/>
						);
					})}
				</Panel>
			),
		});

		const wide = leader && !stack;
		sections.push({
			id: "crew-actions",
			height: leader && stack ? TapTarget * 2 + GAP : TapTarget,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<Button
						text="Leave crew"
						color={armed("leave") ? Palette.coral : Palette.panelSoft}
						textColor={armed("leave") ? Palette.ink : Palette.cream}
						outline={!armed("leave")}
						size={new UDim2(wide ? 0.3 : 1, -GAP / 2, 0, TapTarget)}
						position={wide ? new UDim2(0.7, GAP / 2, 0, 0) : leader ? UDim2.fromOffset(0, TapTarget + GAP) : new UDim2()}
						reducedMotion={softMotion}
						onClick={() => confirmed("leave", "CrewLeave")}
					/>
					{leader && (
						<textbox
							Size={new UDim2(stack ? 1 : 0.45, -GAP / 2, 0, TapTarget)}
							BackgroundColor3={Palette.panel}
							BorderSizePixel={0}
							Text={renameDraft}
							PlaceholderText="New crew name"
							PlaceholderColor3={Palette.muted}
							TextColor3={Palette.cream}
							TextSize={16}
							ClearTextOnFocus={false}
							FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
							Change={{ Text: (box) => setRenameDraft(box.Text.sub(1, 40)) }}
						>
							<uicorner CornerRadius={new UDim(0, 10)} />
							<uipadding PaddingLeft={new UDim(0, 10)} />
						</textbox>
					)}
					{wide && (
						<Button
							text="Rename"
							color={Palette.green}
							textColor={Palette.ink}
							size={new UDim2(0.25, -GAP, 0, TapTarget)}
							position={new UDim2(0.45, GAP / 2, 0, 0)}
							reducedMotion={softMotion}
							disabled={CrewMath.cleanName(renameDraft) === undefined}
							onClick={() => {
								run("CrewRename", { Name: renameDraft });
								setRenameDraft("");
							}}
						/>
					)}
				</frame>
			),
		});
	}

	// recruiting: anyone here who isn't already in your crew
	const canInvite = crew === undefined || (leader && crew.Members.size() < crew.Max);
	if (canInvite) {
		const members = new Set<number>();
		for (const member of crew?.Members ?? []) members.add(member.UserId);
		const candidates = players.filter((player) => !player.IsLocal && !members.has(player.UserId)).filter((_, i) => i < 8);
		const intro =
			crew !== undefined
				? "Invite more players to your crew."
				: `Start a crew with up to ${CrewMath.MAX_MEMBERS - 1} other players here. Each crewmate adds ${math.floor(CrewMath.BONUS_PER_MEMBER * 100)}% production, and you share a daily goal.`;
		const columns = stack ? 1 : 2;
		const rows = math.ceil(candidates.size() / columns);
		sections.push({
			id: "crew-recruit",
			height: 46 + rows * (TapTarget + GAP) + 26,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.blue} background={Palette.panelRaised} padding={14} clips={false}>
					{text(candidates.size() === 0 ? `${intro} Nobody else is free right now.` : intro, 15, Palette.creamSoft, 40)}
					{candidates.map((player, i) => (
						<Button
							key={`invite-${player.UserId}`}
							text={`Invite ${player.DisplayName}`}
							icon="Crew.6"
							color={Palette.blue}
							textColor={Palette.ink}
							reducedMotion={softMotion}
							size={new UDim2(1 / columns, -GAP, 0, TapTarget)}
							position={new UDim2((i % columns) / columns, 0, 0, 46 + math.floor(i / columns) * (TapTarget + GAP))}
							onClick={() => run("CrewInvite", { UserId: player.UserId })}
						/>
					))}
				</Panel>
			),
		});
	}
	if (args.note !== "") sections.push({ id: "crew-note", height: 40, element: text(args.note, 14, Palette.mango, 36) });
	return sections;
}

function CrewView({ state, dispatch, reducedMotion, visit, setVisit }: Props) {
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const antilag = useAntilag();
	const [allPlayers, setPlayers] = React.useState<RosterPlayer[]>([]);
	const mountedRef = React.useRef(true);
	// bumped per visit request and on unmount, so a late reply for an older one is ignored
	const visitAttemptRef = React.useRef(0);
	const crewHostRef = React.useRef<Frame>();
	const crewState = CrewStore.useCrew();
	const [renameDraft, setRenameDraft] = React.useState("");
	const [crewNote, setCrewNote] = React.useState("");
	const [confirmKey, setConfirmKey] = React.useState<string>();
	// an unanswered confirm quietly resets
	React.useEffect(() => {
		if (confirmKey === undefined) return undefined;
		const reset = task.delay(4, () => setConfirmKey(undefined));
		return () => {
			pcall(task.cancel, reset);
		};
	}, [confirmKey]);
	React.useEffect(
		() => () => {
			mountedRef.current = false;
			visitAttemptRef.current += 1;
		},
		[],
	);
	// the crew page asks once on open; afterwards CrewState effects keep the store current
	React.useEffect(() => {
		dispatch("GetCrew", {}, (response) => {
			if (typeIs(response, "table") && response.ok) {
				CrewStore.set({ crew: response.Crew ?? CrewStore.NONE, invite: response.Invite ?? CrewStore.NONE });
			}
		});
	}, []);
	const refresh = React.useCallback(() => {
		dispatch("GetPlayers", {}, (response) => {
			if (!mountedRef.current || !response.ok) return;
			const cleaned: RosterPlayer[] = [];
			for (const entry of response.Players ?? []) {
				const raw = entry.UserId as unknown;
				const id = typeIs(raw, "number") ? math.floor(raw) : tonumber(tostring(raw));
				if (id === undefined || id !== id || id === 0) continue;
				const copy = table.clone(entry);
				setmetatable(copy as object, undefined as unknown as LuaMetatable<object>);
				copy.UserId = id;
				cleaned.push(copy);
			}
			setPlayers((current) => (PageReadyMath.SameCrewSnapshot(current, cleaned) ? current : cleaned));
		});
	}, [dispatch]);
	React.useEffect(() => refresh(), [refresh]);
	React.useEffect(() => {
		const joined = Players.PlayerAdded.Connect(refresh);
		const left = Players.PlayerRemoving.Connect(refresh);
		return () => {
			joined.Disconnect();
			left.Disconnect();
		};
	}, [refresh]);
	// presence (what everyone is doing) changes without anyone joining, so poll it gently
	React.useEffect(() => {
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(4);
				if (!alive) break;
				refresh();
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [refresh]);
	const crewFocusReady = allPlayers.size() > 0;
	React.useEffect(() => {
		const host = crewHostRef.current;
		if (!crewFocusReady || !UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [crewFocusReady, allPlayers.size()]);

	const startVisit = (userId: unknown) => {
		const id = coerceCrewId(userId);
		if (id === undefined) return;
		visitAttemptRef.current += 1;
		const attempt = visitAttemptRef.current;
		dispatch("VisitPlot", { UserId: id, userId: id }, (response) => {
			if (!mountedRef.current || visitAttemptRef.current !== attempt) return;
			if (!response.ok) {
				if (!response.Uncertain) {
					InteractionFeedback.fail();
					// The server's own "no" (and timeouts) already get a notice from the dispatcher.
					// A local "already working on that" doesn't, so say it here instead of doing nothing.
					if (response.error === "Already working on that.") Juice.status("Still opening the last forge. Hang on.", "error");
				}
				return;
			}
			InteractionFeedback.confirm();
			const landed = response.Visit ?? response.State?.Visit;
			if (landed !== undefined) setVisit(landed);
		});
	};
	const [waveShake, setWaveShake] = React.useState<{ id?: number; n: number }>({ n: 0 });
	const nudgeCrew = (userId: unknown) => {
		const id = coerceCrewId(userId);
		if (id === undefined) return;
		// the wave lands with a confirm buzz once the server says it went through
		dispatch("NudgeCrew", { UserId: id, userId: id }, (response) => {
			if (response.ok) {
				InteractionFeedback.confirm();
			} else if (!response.Uncertain) {
				// refused (cooldown, left the server): shake that row's Wave button, which also knocks
				setWaveShake((current) => ({ id, n: current.n + 1 }));
			}
		});
	};
	const headerReveal = useStagger(0, softMotion);
	const crewBrowse = Browse.useBrowse<RosterPlayer>({
		id: "Crew",
		items: allPlayers,
		text: (player) => [player.DisplayName, player.CurrentPage, `world ${player.CurrentZone ?? ""}`],
		categories: [
			{ id: "All", label: "Everyone" },
			{ id: "SameWorld", label: "Same world", test: (player) => !player.IsLocal && player.CurrentZone !== undefined && player.CurrentZone === state.CurrentZone },
			{ id: "Others", label: "Not me", test: (player) => !player.IsLocal },
		],
		sorts: [
			{ id: "Joined", label: "Server order" },
			{ id: "Production", label: "Top production", compare: (a, b) => (asFlux(a.Production) || 0) > (asFlux(b.Production) || 0) },
			{ id: "Rebirths", label: "Most rebirths", compare: (a, b) => (a.Rebirths ?? 0) > (b.Rebirths ?? 0) },
			{ id: "Name", label: "A to Z", compare: (a, b) => string.lower(tostring(a.DisplayName)) < string.lower(tostring(b.DisplayName)) },
		],
	});
	const showCrewBar = allPlayers.size() >= 3;
	const crewBarH = showCrewBar ? Browse.barHeight(stack, true) + 10 : 0;
	// you on top whatever sort is picked, then active crewmates above quiet ones (the sort holds inside each group)
	const results = crewBrowse.results;
	const players = [
		...results.filter((player) => player.IsLocal),
		...results.filter((player) => !player.IsLocal && !isQuiet(player)),
		...results.filter((player) => !player.IsLocal && isQuiet(player)),
	];
	const visitorsHere = state.Visitors?.size() ?? 0;
	const rowStride = stack ? CREW_COMPACT_ROW_H + 18 : 124;
	const rosterGroups: StickyGroup[] = [];
	players.forEach((player, i) => {
		const label = player.IsLocal ? "YOU" : isQuiet(player) ? "QUIET" : "ACTIVE";
		let group = rosterGroups[rosterGroups.size() - 1];
		if (group === undefined || group.label !== label) {
			group = { top: i * rowStride, label, color: label === "QUIET" ? Palette.muted : label === "YOU" ? Palette.blue : Palette.mint, count: 0 };
			rosterGroups.push(group);
		}
		group.count = (group.count ?? 0) + 1;
	});
	const rosterSticky = rosterGroups.size() > 1;
	const rosterPad = rosterSticky ? STICKY_H + 6 : 0;
	// phone: title, two-line blurb, then a full-width Refresh
	const headerH = (stack ? 182 : 112) + crewBarH;
	const listGap = math.max(chrome.panelGap, visit !== undefined ? 18 : 12);
	const headerPanel = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.blue} background={Palette.panelRaised} padding={chrome.cardPadding} layoutOrder={0} reveal={headerReveal} clips={false}>
			<Text value="Crew roster" size={10} color={Palette.blue} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, stack ? -8 : -160, 0, 18)} />
			<Text
				value="Crew on this server"
				size={stack ? 20 : 22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(0, 20)}
				sizeConstraint={new UDim2(1, stack ? -8 : -190, 0, 30)}
			/>
			<Text
				value={
					visitorsHere > 0
						? `${visitorsHere} visiting your forge. Pick someone below to visit or send a wave.`
						: "Form a crew with players here for a production bonus and a shared daily goal, or visit someone's forge."
				}
				size={chrome.labelText}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(0, 54)}
				sizeConstraint={new UDim2(1, stack ? -8 : -190, 0, 38)}
			/>
			<Button
				text={stack ? "REFRESH" : "REFRESH CREW"}
				icon="Refresh.3"
				onClick={refresh}
				sound="tick"
				color={Palette.blue}
				textColor={Palette.ink}
				size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(170, 44)}
				position={stack ? new UDim2(0, 0, 1, -(TapTarget + crewBarH)) : new UDim2(1, -170, 0, 24)}
				reducedMotion={softMotion}
			/>
			{showCrewBar && (
				<Browse.BrowseBar
					browse={crewBrowse}
					placeholder="Search crew by name or activity"
					accent={Palette.blue}
					stack={stack}
					reducedMotion={softMotion}
					position={new UDim2(0, 0, 1, -(crewBarH - 10))}
					zIndex={30}
				/>
			)}
		</Panel>
	);
	const sections: Section[] = [
		{ id: "header", height: headerH, element: headerPanel },
		...crewPartySections({
			crew: crewState.crew as Crew | undefined,
			invite: crewState.invite as Invite | undefined,
			players: allPlayers,
			dispatch,
			stack,
			softMotion,
			renameDraft,
			setRenameDraft,
			note: crewNote,
			setNote: setCrewNote,
			confirmKey,
			setConfirmKey,
		}),
	];
	if (visit !== undefined) {
		sections.push({
			id: "visit",
			height: PageBoardHeights.Visit(stack),
			element: <VisitPanel visit={visit} dispatch={dispatch} reducedMotion={softMotion} layoutOrder={1} stack={stack} />,
		});
	}
	if (allPlayers.size() === 0) {
		sections.push({
			id: "empty",
			height: 180,
			element: (
				<EmptyState
					icon="Crew.7"
					title="No one else is on shift"
					body="Nobody else is here yet. When someone joins, you can visit their forge or wave from this list."
					accent={Palette.blue}
					layoutOrder={2}
				/>
			),
		});
	} else if (players.size() === 0) {
		sections.push({
			id: "empty",
			height: 180,
			element: <Browse.NoResults browse={crewBrowse} noun="crew" icon="Crew.8" accent={Palette.blue} reducedMotion={softMotion} size={UDim2.fromScale(1, 1)} layoutOrder={2} />,
		});
	}
	const row = (player: RosterPlayer, layoutOrder: number) => (
		<CrewRow
			key={player.UserId}
			player={player}
			waveShake={waveShake.id === player.UserId ? waveShake.n : 0}
			visiting={visit?.UserId === player.UserId}
			visitorsHere={player.IsLocal ? visitorsHere : 0}
			onVisit={() => startVisit(player.UserId)}
			onNudge={() => nudgeCrew(player.UserId)}
			reducedMotion={reducedMotion}
			layoutOrder={layoutOrder}
			stack={stack}
		/>
	);
	if (players.size() >= 8) {
		// a long roster is one virtual list that fills the rest of the page
		sections.push({
			id: "roster",
			fill: true,
			minHeight: 120,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					{rosterSticky && (
						<StickyGroupLabel groups={rosterGroups} height={players.size() * rowStride} inner={true} reducedMotion={softMotion} listId="crew-roster" />
					)}
					<frame Size={new UDim2(1, 0, 1, -rosterPad)} Position={UDim2.fromOffset(0, rosterPad)} BackgroundTransparency={1} BorderSizePixel={0}>
						<FlatList
							data={players}
							itemHeight={rowStride}
							overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
							canvasTail={8}
							Size={UDim2.fromScale(1, 1)}
							scrollBarColor={Palette.blue}
							scrollBarThickness={4}
							keyExtractor={(player: RosterPlayer) => tostring(player.UserId)}
							renderItem={({ item, index }: { item: RosterPlayer; index: number }) => row(item, index + 1)}
						/>
					</frame>
				</frame>
			),
		});
	} else if (rosterSticky) {
		// one section so the group label can ride down the rows it names
		const count = players.size();
		const blockH = rosterPad + count * rowStride + math.max(0, count - 1) * listGap;
		const groups = rosterGroups.map((g) => ({ ...g, top: rosterPad + (g.top / rowStride) * (rowStride + listGap) }));
		sections.push({
			id: "crew-roster",
			height: blockH,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<StickyGroupLabel groups={groups} height={blockH} reducedMotion={softMotion} listId="crew-roster" />
					<frame Size={new UDim2(1, 0, 1, -rosterPad)} Position={UDim2.fromOffset(0, rosterPad)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, listGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{players.map((player, i) => (
							<frame key={`row-${i}`} Size={new UDim2(1, 0, 0, rowStride)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={i}>
								{row(player, i + 3)}
							</frame>
						))}
					</frame>
				</frame>
			),
		});
	} else {
		players.forEach((player, i) => sections.push({ id: `crew-${i + 1}`, height: rowStride, element: row(player, i + 3) }));
	}
	return (
		<frame {...named("CrewVisitClaim")} ref={crewHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<PageScaffold gap={listGap} tailPad={scrollTail(stack, chrome.bottomSafe, 48)} scrollBarColor={Palette.blue} scrollBarThickness={4} sections={sections} />
		</frame>
	);
}

export = { CrewView };
