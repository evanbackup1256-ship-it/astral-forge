// The Echoes page: the loom (charge and the four tracks), the strike, the chord, every echo you
// keep, and the journal. Every rule shown here is EchoMath's, so the numbers match the server.
import React from "@rbxts/react";
import EchoMath = require("../../../../Shared/AstralForge/Shared/EchoMath");
import { Icon } from "../../ArtKit/Icon";
import { compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { usePulse, useStagger, useViewport } from "../../MotionKit/motion";
import { requestConfirm } from "../../UiOverlays/ConfirmDialog";
import { Button, EmptyState, Meter, Panel, SectionLabel, Text } from "../../UiCore/ui";
import { Component, loadPageScaffold, luauKit, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;

/** One echo as the server sends it (EchoMath's Echo plus its uid, effects and prices). */
interface KeptEcho {
	Uid: string;
	Trait: string;
	Tier: string;
	Level: number;
	Imprints?: string[];
	Locked?: boolean;
	Effects?: Record<string, number>;
	TuneCost: number;
	Resonance: number;
}
/** One of the three echoes a strike offers. */
interface DraftEcho {
	Trait: string;
	Tier: string;
	Level: number;
	Imprints?: string[];
	Locked?: boolean;
	Effects?: Record<string, number>;
}
interface ChordSlot {
	Slot: number;
	Open: boolean;
	Uid: string;
	NeedsCaptures: number;
}
interface EchoesState {
	Version?: number;
	Charge?: number;
	ChargeTarget?: number;
	Ready?: boolean;
	Tracks?: Record<string, number>;
	Dominant?: string;
	Resonance?: number;
	Draft?: DraftEcho[];
	Rerolled?: boolean;
	Inventory?: KeptEcho[];
	InventoryLimit?: number;
	Chord?: ChordSlot[];
	Bonuses?: Record<string, boolean | undefined>;
	Totals?: Record<string, number | undefined>;
	Journal?: Record<string, number | undefined>;
}
interface Props {
	state: { ForgeEchoes?: EchoesState; Stardust?: number };
	dispatch: (action: string, payload?: object) => unknown;
	reducedMotion?: boolean;
}
interface Section {
	id: string;
	height: number;
	element: React.Element;
}
type Place = "draft" | "chord" | "vault" | "journal";

const TIER_COLOR: Record<string, Color3 | undefined> = { Faint: Palette.muted, Clear: Palette.cyan, Vivid: Palette.violet, Perfect: Palette.mango };
const TRACK_ART: Record<string, { icon: string; color: Color3; label: string }> = {
	Collect: { icon: "Collect.echoTrack", color: Palette.mint, label: "Collecting" },
	Surge: { icon: "Overcharge.echoTrack", color: Palette.coral, label: "Overcharging" },
	Build: { icon: "Forge.echoTrack", color: Palette.mango, label: "Building" },
	Explore: { icon: "World.echoTrack", color: Palette.violet, label: "Exploring" },
};
// each place a trait appears in has its own art for it: "<glyph>.echo<Place><Short>"
const TRAIT_GLYPH: Record<string, [glyph: string, short: string] | undefined> = {
	FurnaceMemory: ["Ember", "Furnace"],
	DeepReservoir: ["Vault", "Reservoir"],
	StrikeGhost: ["Overcharge", "Ghost"],
	LuckyAfterimage: ["Jackpot", "Afterimage"],
	ClockworkEcho: ["Timer", "Clockwork"],
	LatticeRecall: ["Domain", "Lattice"],
	NightShift: ["Anomaly", "Night"],
	VoidPulse: ["Continuum", "Void"],
};
const PLACE_WORD: Record<Place, string> = { draft: "Draft", chord: "Chord", vault: "Vault", journal: "Journal" };
const KIND_WORDS: Record<string, string | undefined> = {
	Production: "production",
	Capacity: "vault capacity",
	Tap: "overcharge power",
	Critical: "critical chance",
	Automation: "auto-collect",
	Offline: "offline earnings",
};
const CHORD_BONUSES: Array<[key: string, label: string, color: Color3]> = [
	["Harmony", "HARMONY +15%", Palette.mint],
	["Unison", "UNISON +10%", Palette.cyan],
	["Spectrum", "SPECTRUM +20%", Palette.mango],
];
const CHORD_HINT =
	"Put echoes in the chord to feel them. Matching affinities add Harmony; a matched pair adds Unison; four different affinities make a Spectrum.";

function traitIcon(place: Place, traitId: string): string | undefined {
	const glyph = TRAIT_GLYPH[traitId];
	return glyph !== undefined ? `${glyph[0]}.echo${PLACE_WORD[place]}${glyph[1]}` : undefined;
}

function pct(value: number): string {
	const p = value * 100;
	return p >= 10 ? string.format("+%d%%", math.floor(p + 0.5)) : string.format("+%.1f%%", p);
}

/** "+12% production  ·  +3.0% critical chance" for every kind with a positive value. */
function effectLines(effects: Record<string, number | undefined> | undefined, separator: string): string {
	const lines: string[] = [];
	for (const kind of EchoMath.KINDS) {
		const v = effects?.[kind] ?? 0;
		if (v > 0) lines.push(`${pct(v)} ${KIND_WORDS[kind]}`);
	}
	return lines.join(separator);
}

function chip(text: string, color: Color3, order: number) {
	return (
		<textlabel
			Size={UDim2.fromOffset(0, 22)}
			AutomaticSize={Enum.AutomaticSize.X}
			LayoutOrder={order}
			BackgroundColor3={darken(color, 0.6)}
			Text={text}
			TextSize={12}
			FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
			TextColor3={color}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uipadding PaddingLeft={new UDim(0, 9)} PaddingRight={new UDim(0, 9)} />
		</textlabel>
	);
}

/** One echo as a card: trait art, name, tier, level, what it does, and what you can do with it. */
function EchoCard(props: { echo: DraftEcho; place: Place; index: number; reducedMotion?: boolean; actions?: React.Element; actionsHeight?: number }) {
	const { echo } = props;
	const trait = EchoMath.trait(echo.Trait);
	const tierColor = TIER_COLOR[echo.Tier] ?? Palette.cream;
	const effects = echo.Effects ?? EchoMath.effects(echo as never);
	const reveal = useStagger(props.index, props.reducedMotion);
	const imprints = echo.Imprints ?? [];
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={tierColor} background={Palette.panel} padding={12} reveal={reveal} reducedMotion={props.reducedMotion}>
			<Icon kind={traitIcon(props.place, echo.Trait) ?? "Wave.echoUnknown"} size={44} position={UDim2.fromOffset(0, 0)} />
			<Text
				value={trait?.Name ?? echo.Trait}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(54, 0)}
				sizeConstraint={new UDim2(1, -54, 0, 20)}
			/>
			<Text
				value={`${string.upper(echo.Tier)}  ·  LEVEL ${echo.Level}${echo.Locked ? "  ·  LOCKED" : ""}`}
				size={11}
				color={tierColor}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(54, 22)}
				sizeConstraint={new UDim2(1, -54, 0, 16)}
			/>
			<Text
				value={effectLines(effects, "  ·  ")}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 52)}
				sizeConstraint={new UDim2(1, 0, 0, 34)}
			/>
			{imprints.size() > 0 && (
				<Text
					value={`Imprints: ${imprints.map((kind) => KIND_WORDS[kind] ?? kind).join(", ")}`}
					size={11}
					color={Palette.muted}
					position={UDim2.fromOffset(0, 86)}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
				/>
			)}
			{props.actions !== undefined && (
				<frame Size={new UDim2(1, 0, 0, props.actionsHeight ?? TapTarget)} Position={UDim2.fromScale(0, 1)} AnchorPoint={new Vector2(0, 1)} BackgroundTransparency={1}>
					{props.actions}
				</frame>
			)}
		</Panel>
	);
}

function EchoForgeView({ state, dispatch, reducedMotion }: Props) {
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	// phones in landscape use the wide layout (cards and chord slots side by side): the stacked
	// one is over 1000px tall and leaves a 360px-tall screen scrolling past one panel at a time
	const stack = chrome.contentStack && !chrome.landscape;
	const echoes = state.ForgeEchoes ?? {};
	const ready = echoes.Ready === true;
	// a controller lands on Strike the moment the charge is full
	const strikeHost = React.useRef<Frame>();
	React.useEffect(() => {
		if (!(ready && UserInputService.GamepadEnabled)) return undefined;
		const job = task.defer(() => {
			const host = strikeHost.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [ready]);
	// the echo whose Break is waiting on the confirm dialog, and the echo being placed in the chord
	const [armed, setArmed] = React.useState<string>();
	const [slotting, setSlotting] = React.useState<string>();
	const readyPulse = usePulse(ready && !softMotion, 1.6);
	React.useEffect(() => {
		if (armed === undefined) return undefined;
		const lapse = task.delay(4, () => setArmed(undefined));
		return () => {
			pcall(task.cancel, lapse);
		};
	}, [armed]);
	// pace: how fast the charge has filled while this page is open, as a rough time to full
	const paceRef = React.useRef<{ at: number; charge: number }>();
	const act = (payload: object) => dispatch("EchoAct", payload);

	if (echoes.Version !== 2) {
		return (
			<Panel size={new UDim2(1, 0, 0, 120)} accent={Palette.cyan} padding={16}>
				<Text
					value="Your echoes are being carried over to the new forge. Give it a moment."
					size={14}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					sizeConstraint={UDim2.fromScale(1, 1)}
				/>
			</Panel>
		);
	}

	const sections: Section[] = [];
	const draft = echoes.Draft ?? [];
	const inventory = echoes.Inventory ?? [];
	const trackCounts = echoes.Tracks ?? {};

	// the loom: charge, tracks, strike
	let trackTotal = 0;
	for (const track of EchoMath.TRACKS) trackTotal += trackCounts[track] ?? 0;
	const tracks = EchoMath.TRACKS.map((track, index) => {
		const art = TRACK_ART[track];
		const leading = echoes.Dominant === track && trackTotal > 0;
		return (
			<frame key={`t${track}`} Size={new UDim2(1, 0, 0, 30)} LayoutOrder={index + 1} BackgroundTransparency={1}>
				<Icon kind={art.icon} size={26} position={UDim2.fromOffset(0, 2)} />
				<Text
					value={`${art.label}${leading ? "  ·  leading" : ""}`}
					size={12}
					color={leading ? art.color : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					position={UDim2.fromOffset(34, 7)}
					sizeConstraint={new UDim2(0.45, -34, 0, 16)}
				/>
				<Meter
					value={(trackCounts[track] ?? 0) / math.max(1, trackTotal)}
					color={art.color}
					size={new UDim2(0.55, -10, 0, 6)}
					position={new UDim2(0.45, 10, 0, 12)}
				/>
			</frame>
		);
	});
	const rawCharge = echoes.Charge ?? 0;
	const target = math.max(1, echoes.ChargeTarget ?? 1);
	const nowAt = os.clock();
	let paceText = "";
	const first = paceRef.current;
	if (first === undefined || rawCharge < first.charge) {
		paceRef.current = { at: nowAt, charge: rawCharge };
	} else if (!ready && rawCharge > first.charge && nowAt - first.at >= 10) {
		const seconds = ((target - rawCharge) * (nowAt - first.at)) / (rawCharge - first.charge);
		const minutes = math.max(1, math.ceil(seconds / 60));
		paceText = minutes >= 120 ? " At this pace it'll be a while yet." : ` At this pace, full in about ${minutes} min.`;
	}
	const charge = rawCharge / target;
	const drafting = draft.size() > 0;
	sections.push({
		id: "loom",
		height: stack ? 316 : 262,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={16} reducedMotion={softMotion}>
				<SectionLabel value="The Loom" color={Palette.cyan} />
				<Text
					value={
						ready
							? "The charge is full. Strike to see what answers."
							: `${math.floor(charge * 100)}% charged.${paceText} Whatever you do most shapes the first echo.`
					}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 28)}
					sizeConstraint={new UDim2(1, 0, 0, 36)}
				/>
				<Meter value={charge} color={ready ? Palette.mango : Palette.cyan} size={new UDim2(1, 0, 0, 10)} position={UDim2.fromOffset(0, 70)} />
				<frame Size={new UDim2(stack ? 1 : 0.6, 0, 0, 4 * 34)} Position={UDim2.fromOffset(0, 92)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{tracks}
				</frame>
				<frame
					{...named("EchoClaimActions")}
					ref={strikeHost}
					ClipsDescendants={false}
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0.36, 0, 0, TapTarget)}
					Position={stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, 0, 0, 100)}
					AnchorPoint={stack ? Vector2.zero : new Vector2(1, 0)}
					BackgroundTransparency={1}
				>
					<uiscale Scale={readyPulse.map((p) => 1 + p * 0.03)} />
					<Button
						text={drafting ? "Pick an echo below" : ready ? "Strike" : "Charging"}
						onClick={() => act({ Op: "Strike" })}
						disabled={!ready || drafting}
						color={Palette.mango}
						textColor={Palette.ink}
						highlight={ready}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
					/>
				</frame>
			</Panel>
		),
	});

	// the strike: three echoes, keep one (or reroll once for resonance)
	if (drafting) {
		const cards = draft.map((choice, i) => {
			const index = i + 1;
			return (
				<frame key={`c${index}`} Size={stack ? new UDim2(1, 0, 0, 170) : new UDim2(1 / 3, -8, 1, 0)} LayoutOrder={index} BackgroundTransparency={1}>
					<EchoCard
						echo={choice}
						place="draft"
						index={index}
						reducedMotion={softMotion}
						actions={
							<Button
								text="Keep this one"
								onClick={() => act({ Op: "Keep", Choice: index })}
								color={TIER_COLOR[choice.Tier] ?? Palette.mango}
								textColor={Palette.ink}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={softMotion}
							/>
						}
					/>
				</frame>
			);
		});
		const cardsH = stack ? 3 * 178 : 178;
		const canReroll = echoes.Rerolled !== true && (echoes.Resonance ?? 0) >= EchoMath.REROLL_RESONANCE;
		sections.push({
			id: "draft",
			height: 32 + cardsH + 8 + TapTarget,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<SectionLabel value="What answered" color={Palette.mango} />
					<frame Size={new UDim2(1, 0, 0, cardsH)} Position={UDim2.fromOffset(0, 32)} BackgroundTransparency={1}>
						<uilistlayout
							FillDirection={stack ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
							Padding={new UDim(0, 8)}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
						{cards}
					</frame>
					<frame Size={UDim2.fromOffset(260, TapTarget)} Position={UDim2.fromScale(1, 1)} AnchorPoint={new Vector2(1, 1)} BackgroundTransparency={1}>
						<Button
							text={echoes.Rerolled === true ? "Already rerolled" : `Reroll for ${EchoMath.REROLL_RESONANCE} resonance`}
							onClick={() => act({ Op: "Reroll" })}
							disabled={!canReroll}
							color={Palette.panelSoft}
							textColor={Palette.cream}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={softMotion}
						/>
					</frame>
				</frame>
			),
		});
	}

	// the chord: four slots, its bonuses and what it all adds up to
	const byUid = new Map<string, KeptEcho>();
	for (const echo of inventory) byUid.set(echo.Uid, echo);
	const slotCell = stack ? new UDim2(0.5, -4, 0, 96) : new UDim2(0.25, -6, 1, 0);
	const slots = (echoes.Chord ?? []).map((slot) => {
		const echo = byUid.get(slot.Uid);
		const placing = slotting !== undefined && slot.Open;
		const tierColor = echo !== undefined ? TIER_COLOR[echo.Tier] : undefined;
		const label =
			echo !== undefined
				? (EchoMath.trait(echo.Trait)?.Name ?? echo.Trait)
				: slot.Open
					? placing
						? "Put it here"
						: "Empty"
					: `Opens at ${slot.NeedsCaptures} kept`;
		return (
			<textbutton
				key={`s${slot.Slot}`}
				Size={slotCell}
				LayoutOrder={slot.Slot}
				BackgroundColor3={placing ? darken(Palette.mango, 0.6) : Palette.panelSoft}
				AutoButtonColor={false}
				Text=""
				Event={{
					Activated: () => {
						if (slotting !== undefined && slot.Open) {
							act({ Op: "Slot", Slot: slot.Slot, Uid: slotting });
							setSlotting(undefined);
						} else if (echo !== undefined) {
							act({ Op: "Slot", Slot: slot.Slot, Uid: "" });
						}
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uistroke
					Color={echo !== undefined ? (tierColor ?? Palette.line) : placing ? Palette.mango : Palette.line}
					Thickness={placing ? 2 : 1}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				/>
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingTop={new UDim(0, 10)} />
				{echo !== undefined && <Icon kind={traitIcon("chord", echo.Trait) ?? "Wave.echoChordUnknown"} size={34} />}
				<Text
					value={label}
					size={12}
					color={echo !== undefined ? Palette.cream : Palette.muted}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, echo !== undefined ? 40 : 8)}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
				/>
				{echo !== undefined && (
					<Text
						value={`${echo.Tier} · L${echo.Level}`}
						size={11}
						color={tierColor ?? Palette.muted}
						position={UDim2.fromOffset(0, 58)}
						sizeConstraint={new UDim2(1, 0, 0, 14)}
					/>
				)}
			</textbutton>
		);
	});
	const bonusChips: React.Element[] = [];
	for (const [key, label, color] of CHORD_BONUSES) {
		if (echoes.Bonuses?.[key] === true) bonusChips.push(chip(label, color, bonusChips.size() + 1));
	}
	const totals = effectLines(echoes.Totals, ", ");
	const slotsH = stack ? 200 : 110;
	sections.push({
		id: "chord",
		height: 32 + slotsH + 8 + 22 + 8 + 36,
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<SectionLabel value={slotting !== undefined ? "Pick a slot" : "The Chord"} color={Palette.violet} />
				<frame Size={new UDim2(1, 0, 0, slotsH)} Position={UDim2.fromOffset(0, 32)} BackgroundTransparency={1}>
					<uigridlayout CellSize={slotCell} CellPadding={UDim2.fromOffset(8, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{slots}
				</frame>
				<frame Size={new UDim2(1, 0, 0, 22)} Position={UDim2.fromOffset(0, 32 + slotsH + 8)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{bonusChips}
				</frame>
				<Text
					value={totals !== "" ? `The chord adds ${totals}.` : CHORD_HINT}
					size={12}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 32 + slotsH + 8 + 26)}
					sizeConstraint={new UDim2(1, 0, 0, 36)}
				/>
			</frame>
		),
	});

	// the vault: every echo you keep
	const columns = stack ? 1 : viewport.width >= 1500 ? 3 : 2;
	const cardH = 186;
	const stardust = tonumber(state.Stardust) ?? 0;
	const vaultCard = (echo: KeptEcho, index: number) => {
		// the last unlocked echo of the same trait and tier is the one a Fuse spends
		let partner: KeptEcho | undefined;
		for (const other of inventory) {
			if (other.Uid !== echo.Uid && other.Trait === echo.Trait && other.Tier === echo.Tier && !other.Locked) partner = other;
		}
		const canFuse = partner !== undefined && !echo.Locked && EchoMath.nextTier(echo.Tier) !== undefined;
		const actions: Array<[text: string, onClick: () => void, color: Color3, disabled: boolean]> = [
			["Slot", () => setSlotting(slotting === echo.Uid ? undefined : echo.Uid), Palette.violet, false],
			[
				`Tune · ${compactNumber(echo.TuneCost)}`,
				() => act({ Op: "Tune", Uid: echo.Uid }),
				Palette.cyan,
				stardust < echo.TuneCost || echo.Level >= EchoMath.MAX_LEVEL,
			],
			["Fuse", () => act({ Op: "Fuse", A: echo.Uid, B: partner?.Uid }), Palette.mango, !canFuse],
			[echo.Locked ? "Unlock" : "Lock", () => act({ Op: "Lock", Uid: echo.Uid }), Palette.panelSoft, false],
			[
				`Break · +${echo.Resonance}`,
				() => {
					setArmed(echo.Uid);
					requestConfirm({
						title: "Break this echo?",
						body: `It's gone for good. You get ${echo.Resonance} resonance back.`,
						confirmText: "Break",
						tone: "danger",
						onConfirm: () => {
							setArmed(undefined);
							act({ Op: "Dismantle", Uid: echo.Uid });
						},
						onCancel: () => setArmed(undefined),
					});
				},
				armed === echo.Uid ? Palette.coral : Palette.panelSoft,
				echo.Locked === true,
			],
		];
		const buttons = actions.map(([text, onClick, color, disabled], a) => (
			<frame key={`a${a + 1}`} Size={new UDim2(1 / actions.size(), -6, 1, 0)} LayoutOrder={a + 1} BackgroundTransparency={1}>
				<Button
					text={text}
					onClick={onClick}
					color={color}
					textColor={color === Palette.panelSoft ? Palette.cream : Palette.ink}
					disabled={disabled}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
				/>
			</frame>
		));
		return (
			<frame key={`v${echo.Uid}`} LayoutOrder={index} Size={new UDim2(1 / columns, (-8 * (columns - 1)) / columns, 0, cardH)} BackgroundTransparency={1}>
				<EchoCard
					echo={echo}
					place="vault"
					index={index}
					reducedMotion={softMotion}
					actionsHeight={34}
					actions={
						<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
							<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
							{buttons}
						</frame>
					}
				/>
			</frame>
		);
	};
	const kept = inventory.size();
	const rows = math.max(1, math.ceil(kept / columns));
	// the vault is windowed against the page scroll a row at a time: a full vault is ~1500 instances
	const vaultRows: Array<{ Id: string; echoes: KeptEcho[]; first: number }> = [];
	for (let r = 0; r * columns < kept; r++) {
		const slice: KeptEcho[] = [];
		for (let c = 0; c < columns && r * columns + c < kept; c++) slice.push(inventory[r * columns + c]);
		vaultRows.push({ Id: `row-${columns}-${r}`, echoes: slice, first: r * columns + 1 });
	}
	sections.push({
		id: "vault",
		// an embedded list is always its full canvas tall: every row plus its 8px gap
		height: 32 + (kept === 0 ? 112 : rows * (cardH + 8)),
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<SectionLabel value={`Kept ${kept}/${echoes.InventoryLimit}, ${compactNumber(echoes.Resonance ?? 0)} resonance`} color={Palette.cyan} />
				<frame Size={new UDim2(1, 0, 1, -32)} Position={UDim2.fromOffset(0, 32)} BackgroundTransparency={1}>
					{kept > 0 ? (
						<FlatList
							data={vaultRows}
							itemHeight={cardH + 8}
							embedded={true}
							canvasTail={0}
							Size={new UDim2(1, 0, 0, rows * (cardH + 8))}
							keyExtractor={(row: { Id: string }) => row.Id}
							renderItem={({ item: row }: { item: (typeof vaultRows)[number] }) => (
								<frame Size={new UDim2(1, 0, 0, cardH)} BackgroundTransparency={1}>
									<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
									{row.echoes.map((echo, c) => vaultCard(echo, row.first + c))}
								</frame>
							)}
						/>
					) : (
						<EmptyState icon="Vault" title="Nothing kept yet" body="Fill the charge and strike." accent={Palette.cyan} compact={true} size={UDim2.fromScale(1, 1)} />
					)}
				</frame>
			</frame>
		),
	});

	// the journal: every trait at every tier
	const tierCount = EchoMath.TIERS.size();
	const journalRows = EchoMath.TRAITS.map((trait, i) => {
		const reached = echoes.Journal?.[trait.Id] ?? 0;
		const complete = reached >= tierCount;
		return (
			<frame key={`j${i + 1}`} Size={new UDim2(1, 0, 0, 30)} LayoutOrder={i + 1} BackgroundTransparency={1}>
				<Icon kind={traitIcon("journal", trait.Id)} size={24} position={UDim2.fromOffset(0, 3)} />
				<Text
					value={`${trait.Name}${complete ? "  ·  complete, +3% for good" : ""}`}
					size={12}
					color={complete ? Palette.mango : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(32, 7)}
					sizeConstraint={new UDim2(0.4, -32, 0, 16)}
				/>
				<frame Size={new UDim2(0.6, 0, 1, 0)} Position={UDim2.fromScale(0.4, 0)} BackgroundTransparency={1}>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						Padding={new UDim(0, 6)}
						SortOrder={Enum.SortOrder.LayoutOrder}
						VerticalAlignment={Enum.VerticalAlignment.Center}
					/>
					{EchoMath.TIERS.map((tier, t) => chip(string.upper(tier), t + 1 <= reached ? (TIER_COLOR[tier] ?? Palette.lineSoft) : Palette.lineSoft, t + 1))}
				</frame>
			</frame>
		);
	});
	sections.push({
		id: "journal",
		height: 32 + EchoMath.TRAITS.size() * 34 + 16,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.lineSoft} background={Palette.panel} padding={14}>
				<SectionLabel value="Journal" color={Palette.mango} />
				<frame Size={new UDim2(1, 0, 1, -30)} Position={UDim2.fromOffset(0, 30)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{journalRows}
				</frame>
			</Panel>
		),
	});

	return (
		<PageScaffold
			gap={stack ? 10 : 14}
			tailPad={scrollTail(chrome.stack, chrome.bottomSafe, stack ? 72 : 56)}
			scrollBarColor={Palette.cyan}
			scrollBarThickness={4}
			sections={sections}
		/>
	);
}

export = { EchoForgeView };
