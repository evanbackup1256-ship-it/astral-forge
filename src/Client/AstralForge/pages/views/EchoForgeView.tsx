// The Echoes page (design/20-journal-entry spread): the loom (charge and the four tracks), the strike
// draft, and every echo you keep in the main column; the chord and the journal in the 460px column on
// the right. Every rule shown here is EchoMath's, so the numbers match the server; every action is
// one EchoAct dispatch. All placement is UIListLayout / UIGridLayout inside the one PageScaffold.
import React from "@rbxts/react";
import { requestConfirm } from "../../UiOverlays/ConfirmDialog";
import { useBackLayer } from "../../CoreKit/backLayer";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { compactNumber } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { usePulse, useViewport } from "../../MotionKit/motion";
import { measureWrappedTextHeight, splitColumns } from "../../UiCore/ui";
import { Bar, BODY, BODY_BOLD, Chip, Glyph, Line, MockPanel, mockGap, PanelHeading, panelPad, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, IconWell, MockBtn, MockRow, panelHeight, RowFace, rowHeight } from "../mockRows";
import { FlexCol, FlexFill, FlexFixed, FlexRow, stackSum } from "../mockLayout";
import { loadPageScaffold, sharedModule } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const PageScaffold = loadPageScaffold();

interface TraitDef {
	Id: string;
	Name: string;
}
interface EchoMathApi {
	TRACKS: ReadonlyArray<string>;
	KINDS: ReadonlyArray<string>;
	TIERS: ReadonlyArray<string>;
	TRAITS: ReadonlyArray<TraitDef>;
	REROLL_RESONANCE: number;
	MAX_LEVEL: number;
	trait(this: void, id: string | undefined): TraitDef | undefined;
	effects(this: void, echo: unknown): Record<string, number>;
	nextTier(this: void, tier: string | undefined): string | undefined;
}
const EchoMath = sharedModule<EchoMathApi>("EchoMath");

interface EchoItem {
	Uid?: string;
	Trait: string;
	Tier: string;
	Level: number;
	Imprints?: string[];
	Locked?: boolean;
	Effects?: Record<string, number>;
	TuneCost?: number;
	Resonance?: number;
}
interface ChordSlot {
	Slot: number;
	Uid?: string;
	Open?: boolean;
	NeedsCaptures?: number;
}
interface EchoBag {
	Version?: number;
	Ready?: boolean;
	Charge?: number;
	ChargeTarget?: number;
	Tracks?: Record<string, number>;
	Dominant?: string;
	Draft?: EchoItem[];
	Rerolled?: boolean;
	Resonance?: number;
	Inventory?: EchoItem[];
	InventoryLimit?: number;
	Chord?: ChordSlot[];
	Bonuses?: Record<string, boolean>;
	Totals?: Record<string, number>;
	Journal?: Record<string, number>;
}
interface EchoProps {
	state: { ForgeEchoes?: EchoBag; Stardust?: number };
	dispatch: (action: string, payload: Record<string, unknown>) => unknown;
	reducedMotion?: boolean;
}
type Section = { id: string; height: number; element: React.Element };

const TIER_COLOR: Record<string, Color3> = { Faint: Palette.muted, Clear: Palette.mango, Vivid: Palette.violet, Perfect: Palette.mango };
const TRACK_ART: Record<string, { icon: string; color: Color3; label: string }> = {
	Collect: { icon: "Collect.echoTrack", color: Palette.mint, label: "Collecting" },
	Surge: { icon: "Overcharge.echoTrack", color: Palette.coral, label: "Overcharging" },
	Build: { icon: "Forge.echoTrack", color: Palette.mango, label: "Building" },
	Explore: { icon: "World.echoTrack", color: Palette.violet, label: "Exploring" },
};
// each place a trait appears in has its own art for it
const TRAIT_ICON: Record<string, string> = {
	FurnaceMemory: "Ember",
	DeepReservoir: "Vault",
	StrikeGhost: "Overcharge",
	LuckyAfterimage: "Jackpot",
	ClockworkEcho: "Timer",
	LatticeRecall: "Domain",
	NightShift: "Anomaly",
	VoidPulse: "Continuum",
};
const TRAIT_SUFFIX: Record<string, string> = {
	FurnaceMemory: "Furnace",
	DeepReservoir: "Reservoir",
	StrikeGhost: "Ghost",
	LuckyAfterimage: "Afterimage",
	ClockworkEcho: "Clockwork",
	LatticeRecall: "Lattice",
	NightShift: "Night",
	VoidPulse: "Void",
};
const PLACE_WORD: Record<string, string> = { draft: "Draft", chord: "Chord", vault: "Vault", journal: "Journal" };
function traitIcon(place: string, traitId: string): string {
	const base = TRAIT_ICON[traitId];
	const suffix = TRAIT_SUFFIX[traitId];
	if (base === undefined || suffix === undefined) return place === "chord" ? "Wave.echoChordUnknown" : "Wave.echoUnknown";
	return `${base}.echo${PLACE_WORD[place]}${suffix}`;
}
const KIND_WORDS: Record<string, string> = {
	Production: "production",
	Capacity: "vault capacity",
	Tap: "overcharge power",
	Critical: "critical chance",
	Automation: "auto-collect",
	Offline: "offline earnings",
};
function pct(value: number): string {
	const p = value * 100;
	return p >= 10 ? string.format("+%d%%", math.floor(p + 0.5)) : string.format("+%.1f%%", p);
}
function effectLines(effects: Record<string, number>): string {
	const lines: string[] = [];
	for (const kind of EchoMath.KINDS) {
		const v = effects[kind];
		if (v !== undefined && v > 0) lines.push(`${pct(v)} ${KIND_WORDS[kind]}`);
	}
	return lines.join("  ·  ");
}
function tierColor(tier: string | undefined, fallback: Color3): Color3 {
	return (tier !== undefined ? TIER_COLOR[tier] : undefined) ?? fallback;
}

// ---------- echo card: trait art, name, tier, level, what it does, its actions ----------
const CARD_PAD = 14;
function echoCardHeight(actionsH: number): number {
	return CARD_PAD + 44 + 8 + 34 + 8 + 16 + 8 + actionsH + CARD_PAD;
}
function EchoCard(props: { echo: EchoItem; place: string; index: number; actionsH: number; children?: React.ReactNode }) {
	const { echo } = props;
	const color = tierColor(echo.Tier, Palette.cream);
	const effects = echo.Effects ?? EchoMath.effects(echo);
	const imprints = (echo.Imprints ?? []).map((kind) => KIND_WORDS[kind] ?? kind);
	const name = EchoMath.trait(echo.Trait)?.Name ?? echo.Trait;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.index}>
			<RowFace outline={color} />
			<frame key="Content" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uipadding PaddingTop={new UDim(0, CARD_PAD)} PaddingBottom={new UDim(0, CARD_PAD)} PaddingLeft={new UDim(0, CARD_PAD)} PaddingRight={new UDim(0, CARD_PAD)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<FlexRow height={44} gap={12} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
					<IconWell icon={traitIcon(props.place, echo.Trait)} accent={color} size={44} layoutOrder={0} />
					<FlexFill layoutOrder={1}>
						<FlexCol gap={4}>
							<Line text={name} size={18} font={TITLE_FACE} width={new UDim(1, 0)} height={22} layoutOrder={0} />
							<Line
								text={`${echo.Tier}  ·  Level ${echo.Level}${echo.Locked ? "  ·  Locked" : ""}`}
								size={11}
								font={BODY_BOLD}
								color={color}
								width={new UDim(1, 0)}
								height={16}
								layoutOrder={1}
							/>
						</FlexCol>
					</FlexFill>
				</FlexRow>
				<textlabel
					Size={new UDim2(1, 0, 0, 34)}
					BackgroundTransparency={1}
					Text={effectLines(effects)}
					TextSize={14}
					FontFace={BODY}
					TextColor3={Palette.creamSoft}
					TextWrapped={true}
					TextTruncate={Enum.TextTruncate.AtEnd}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextYAlignment={Enum.TextYAlignment.Top}
					LayoutOrder={1}
				/>
				<Line text={imprints.size() > 0 ? `Imprints: ${imprints.join(", ")}` : ""} size={11} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={16} layoutOrder={2} />
				<FlexRow height={props.actionsH} gap={6} align={Enum.VerticalAlignment.Center} layoutOrder={3}>
					{props.children}
				</FlexRow>
			</frame>
		</frame>
	);
}

function gridHeight(count: number, columns: number, cellH: number, gap: number): number {
	const rows = math.max(1, math.ceil(count / columns));
	return rows * cellH + (rows - 1) * gap;
}
function CardGrid(props: { columns: number; cellH: number; gap: number; height: number; layoutOrder: number; name: string; children?: React.ReactNode }) {
	return (
		<frame key={props.name} Size={new UDim2(1, 0, 0, props.height)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.layoutOrder}>
			<uigridlayout
				CellSize={new UDim2(1 / props.columns, -math.ceil((props.gap * (props.columns - 1)) / props.columns), 0, props.cellH)}
				CellPadding={UDim2.fromOffset(props.gap, props.gap)}
				FillDirectionMaxCells={props.columns}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{props.children}
		</frame>
	);
}

/** Action button that fills an equal share of its card's action row. */
function ShareBtn(props: { text: string; accent: Color3; sec?: boolean; disabled?: boolean; onClick: () => void; reducedMotion?: boolean; layoutOrder: number; sm?: boolean }) {
	return (
		<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.layoutOrder}>
			<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			<MockBtn text={props.text} accent={props.accent} sec={props.sec} sm={props.sm} fill={true} disabled={props.disabled} onClick={props.onClick} reducedMotion={props.reducedMotion} />
		</frame>
	);
}

export function EchoForgeView(props: EchoProps) {
	const { state, dispatch } = props;
	const reducedMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	// phones in landscape use the wide layout: the stacked one leaves a 360px-tall screen scrolling
	// past one panel at a time
	const stack = chrome.contentStack && !chrome.landscape;
	const phone = stack;
	const echoes: EchoBag = state.ForgeEchoes ?? {};
	const draft = echoes.Draft ?? [];
	const inventory = echoes.Inventory ?? [];

	// a controller lands on Strike the moment the charge is full
	const strikeHost = React.useRef<Frame>();
	React.useEffect(() => {
		if (!(echoes.Ready && UserInputService.GamepadEnabled)) return;
		const job = task.defer(() => {
			const host = strikeHost.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [echoes.Ready]);
	const [armed, setArmed] = React.useState<string | undefined>(undefined);
	const [slotting, setSlotting] = React.useState<string | undefined>(undefined);
	// B backs out of picking a chord slot before it leaves the page
	useBackLayer(slotting !== undefined, () => setSlotting(undefined));
	// explicit pad order: loom (Strike) > draft (Keep) > chord > vault > journal; the chord/journal column links left/right
	const echoHostRef = React.useRef<Frame>();
	useFocusOrder(
		echoHostRef,
		{ regions: ["loom", "draft", "chord", "vault", "journal"], first: ["draft", "EchoClaimActions", "loom"], columns: [["Main", "Side"]] },
		[echoes.Ready, draft.size(), slotting],
	);
	const readyPulse = usePulse(echoes.Ready === true && reducedMotion !== true, 1.6);
	React.useEffect(() => {
		if (armed === undefined) return;
		const lapse = task.delay(4, () => setArmed(undefined));
		return () => {
			pcall(() => task.cancel(lapse));
		};
	}, [armed]);
	// pace: how fast the charge has filled while this page is open, as a rough time to full
	const paceRef = React.useRef<{ at: number; charge: number }>();
	const act = (payload: Record<string, unknown>) => dispatch("EchoAct", payload);

	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const rowH = rowHeight(phone);
	const bH = phone ? TapTarget : 44;
	const plan = splitColumns(stack ? 0 : viewport.width, 460, gap, 1280);
	const sideInner = 460 - pad.x * 2;

	if (echoes.Version !== 2) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<PageScaffold
					gap={gap}
					tailPad={scrollTail(phone, chrome.bottomSafe, 24)}
					scrollBarColor={Palette.mango}
					scrollBarThickness={4}
					owner="EchoForgeView"
					sections={[
						{
							id: "migrating",
							height: panelHeight(phone, head + rowH),
							element: (
								<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion}>
									<PanelHeading icon="Refresh" title="Echoes" phone={phone} layoutOrder={0} />
									<MockRow phone={phone} icon="Timer" title="Your echoes are being carried over to the new forge." sub="Give it a moment." layoutOrder={1} />
								</MockPanel>
							),
						},
					]}
				/>
			</frame>
		);
	}

	// ---------- the loom: charge, tracks, strike ----------
	const nowAt = os.clock();
	const rawCharge = echoes.Charge ?? 0;
	const target = math.max(1, echoes.ChargeTarget ?? 1);
	let paceText = "";
	const first = paceRef.current;
	if (first === undefined || rawCharge < first.charge) {
		paceRef.current = { at: nowAt, charge: rawCharge };
	} else if (echoes.Ready !== true && rawCharge > first.charge && nowAt - first.at >= 10) {
		const seconds = ((target - rawCharge) * (nowAt - first.at)) / (rawCharge - first.charge);
		const minutes = math.max(1, math.ceil(seconds / 60));
		paceText = minutes >= 120 ? " At this pace it'll be a while yet." : ` At this pace, full in about ${minutes} min.`;
	}
	const charge = math.clamp(rawCharge / target, 0, 1);
	let trackTotal = 0;
	for (const track of EchoMath.TRACKS) trackTotal += echoes.Tracks?.[track] ?? 0;
	const TRACK_H = 30;
	const tracksH = stackSum(table.create(EchoMath.TRACKS.size(), TRACK_H), 4);
	const loomText = echoes.Ready
		? "The charge is full. Strike to see what answers."
		: `${math.floor(charge * 100)}% charged.${paceText} Whatever you do most shapes the first echo.`;
	const loomTextH = 40;
	const strikeText = draft.size() > 0 ? "Pick an echo below" : echoes.Ready ? "Strike" : "Charging";
	const strikeW = phone ? 0 : 260;
	const loomBodyH = phone ? tracksH + pad.gap + bH : math.max(tracksH, bH);
	const loomH = panelHeight(phone, head + loomTextH + pad.gap + 10 + pad.gap + loomBodyH);
	const strikeButton = (
		<frame key="EchoClaimActions" ref={strikeHost} Size={phone ? new UDim2(1, 0, 0, bH) : UDim2.fromOffset(strikeW, bH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
			<uiscale Scale={readyPulse.map((p) => 1 + p * 0.03)} />
			<MockBtn
				text={strikeText}
				icon="Overcharge"
				fill={true}
				phone={phone}
				disabled={!echoes.Ready || draft.size() > 0}
				onClick={() => act({ Op: "Strike" })}
				reducedMotion={reducedMotion}
			/>
		</frame>
	);
	const tracks = (
		<FlexCol gap={4} layoutOrder={0}>
			{EchoMath.TRACKS.map((track, index) => {
				const art = TRACK_ART[track];
				const leading = echoes.Dominant === track && trackTotal > 0;
				const share = (echoes.Tracks?.[track] ?? 0) / math.max(1, trackTotal);
				return (
					<FlexRow key={track} height={TRACK_H} gap={8} align={Enum.VerticalAlignment.Center} layoutOrder={index}>
						<Glyph kind={art.icon} size={26} layoutOrder={0} />
						<FlexFixed width={phone ? 140 : 180} height={16} layoutOrder={1}>
							<Line text={art.label + (leading ? "  ·  leading" : "")} size={12} font={BODY_BOLD} color={leading ? art.color : Palette.creamSoft} width={new UDim(1, 0)} height={16} />
						</FlexFixed>
						<FlexFill layoutOrder={2} height={6}>
							<Bar fill={share} color={art.color} thin={true} width={new UDim(1, 0)} />
						</FlexFill>
					</FlexRow>
				);
			})}
		</FlexCol>
	);
	const loomPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="loom">
			<PanelHeading icon="Production" title="The Loom" note={`${math.floor(charge * 100)}%`} phone={phone} layoutOrder={0} />
			<textlabel
				Size={new UDim2(1, 0, 0, loomTextH)}
				BackgroundTransparency={1}
				Text={loomText}
				TextSize={phone ? 13 : 15}
				FontFace={BODY}
				TextColor3={Palette.creamSoft}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				LayoutOrder={1}
			/>
			<Bar fill={charge} color={Palette.mango} layoutOrder={2} />
			{phone ? (
				<FlexCol gap={pad.gap} layoutOrder={3}>
					{tracks}
					{strikeButton}
				</FlexCol>
			) : (
				<FlexRow height={loomBodyH} gap={24} align={Enum.VerticalAlignment.Center} layoutOrder={3}>
					<FlexFill layoutOrder={0}>{tracks}</FlexFill>
					{strikeButton}
				</FlexRow>
			)}
		</MockPanel>
	);

	// ---------- the strike: three echoes, keep one (or reroll once for resonance) ----------
	const draftCols = phone ? 1 : 3;
	const draftCellH = echoCardHeight(bH);
	const draftGridH = gridHeight(draft.size(), draftCols, draftCellH, pad.gap);
	const draftH = panelHeight(phone, head + draftGridH + pad.gap + bH);
	const canReroll = !echoes.Rerolled && (echoes.Resonance ?? 0) >= EchoMath.REROLL_RESONANCE;
	const draftPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} glow={Palette.mango} reducedMotion={reducedMotion} name="draft">
			<PanelHeading icon="Gift" title="What answered" note="Keep one" phone={phone} layoutOrder={0} />
			<CardGrid name="DraftCards" columns={draftCols} cellH={draftCellH} gap={pad.gap} height={draftGridH} layoutOrder={1}>
				{draft.map((choice, index) => (
					<EchoCard key={`c${index}`} echo={choice} place="draft" index={index} actionsH={bH}>
						<ShareBtn
							text="Keep this one"
							accent={tierColor(choice.Tier, Palette.mango)}
							onClick={() => act({ Op: "Keep", Choice: index + 1 })}
							reducedMotion={reducedMotion}
							layoutOrder={0}
						/>
					</EchoCard>
				))}
			</CardGrid>
			<FlexRow height={bH} gap={12} justify={Enum.HorizontalAlignment.Right} layoutOrder={2}>
				<MockBtn
					text={echoes.Rerolled ? "Already rerolled" : `Reroll for ${EchoMath.REROLL_RESONANCE} resonance`}
					icon="Refresh"
					sec={true}
					phone={phone}
					width={phone ? undefined : 280}
					fill={phone}
					disabled={!canReroll}
					onClick={() => act({ Op: "Reroll" })}
					reducedMotion={reducedMotion}
				/>
			</FlexRow>
		</MockPanel>
	);

	// ---------- the chord: four slots, its bonuses and what it adds up to ----------
	const byUid: Record<string, EchoItem> = {};
	for (const echo of inventory) if (echo.Uid !== undefined) byUid[echo.Uid] = echo;
	const chord = echoes.Chord ?? [];
	const slotCols = phone ? 2 : 4;
	const SLOT_H = 96;
	const slotsH = gridHeight(chord.size(), slotCols, SLOT_H, 8);
	const bonusChips: React.Element[] = [];
	for (const [key, label, color] of [
		["Harmony", "HARMONY +15%", Palette.mint],
		["Unison", "UNISON +10%", Palette.mango],
		["Spectrum", "SPECTRUM +20%", Palette.mango],
	] as [string, string, Color3][]) {
		if (echoes.Bonuses?.[key]) bonusChips.push(<Chip key={key} text={label} accent={color} phone={phone} layoutOrder={bonusChips.size()} />);
	}
	const totals: string[] = [];
	for (const kind of EchoMath.KINDS) {
		const v = echoes.Totals?.[kind] ?? 0;
		if (v > 0) totals.push(`${pct(v)} ${KIND_WORDS[kind]}`);
	}
	const chordText =
		totals.size() > 0
			? `The chord adds ${totals.join(", ")}.`
			: "Put echoes in the chord to feel them. Matching affinities add Harmony; a matched pair adds Unison; four different affinities make a Spectrum.";
	const chordWidth = plan.split ? sideInner : math.max(200, viewport.width - 80);
	const chordTextH = math.max(18, math.ceil(measureWrappedTextHeight(chordText, chordWidth, phone ? 12 : 13) * 1.1) + 4);
	const chipsH = bonusChips.size() > 0 ? (phone ? 24 : 28) + pad.gap : 0;
	const chordH = panelHeight(phone, head + slotsH + pad.gap + chipsH + chordTextH);
	const chordPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reducedMotion={reducedMotion} name="chord">
			<PanelHeading icon="StarGrid" title={slotting !== undefined ? "Pick a slot" : "The Chord"} accent={Palette.violet} phone={phone} layoutOrder={0} />
			<CardGrid name="ChordSlots" columns={slotCols} cellH={SLOT_H} gap={8} height={slotsH} layoutOrder={1}>
				{chord.map((slot) => {
					const echo = slot.Uid !== undefined ? byUid[slot.Uid] : undefined;
					const placing = slotting !== undefined && slot.Open === true;
					const color = echo !== undefined ? tierColor(echo.Tier, Palette.line) : placing ? Palette.mango : undefined;
					const label =
						echo !== undefined
							? EchoMath.trait(echo.Trait)?.Name ?? echo.Trait
							: slot.Open
								? placing
									? "Put it here"
									: "Empty"
								: `Opens at ${slot.NeedsCaptures ?? 0} kept`;
					return (
						<textbutton
							key={`s${slot.Slot}`}
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={placing ? darken(Palette.mango, 0.6) : Palette.white}
							BackgroundTransparency={placing ? 0 : 1}
							BorderSizePixel={0}
							AutoButtonColor={false}
							Text=""
							LayoutOrder={slot.Slot}
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
							<RowFace outline={color} strong={placing} />
							<frame key="Content" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
								<uipadding PaddingTop={new UDim(0, 10)} PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} />
								<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
								{echo !== undefined && <Glyph kind={traitIcon("chord", echo.Trait)} size={34} layoutOrder={0} />}
								<Line text={label} size={12} font={BODY_BOLD} color={echo !== undefined ? Palette.cream : Palette.muted} width={new UDim(1, 0)} height={16} layoutOrder={1} />
								{echo !== undefined && (
									<Line text={`${echo.Tier} · L${echo.Level}`} size={11} font={BODY} color={tierColor(echo.Tier, Palette.muted)} width={new UDim(1, 0)} height={14} layoutOrder={2} />
								)}
							</frame>
						</textbutton>
					);
				})}
			</CardGrid>
			{bonusChips.size() > 0 && (
				<FlexRow height={phone ? 24 : 28} gap={6} align={Enum.VerticalAlignment.Center} layoutOrder={2}>
					{bonusChips}
				</FlexRow>
			)}
			<textlabel
				Size={new UDim2(1, 0, 0, chordTextH)}
				BackgroundTransparency={1}
				Text={chordText}
				TextSize={phone ? 12 : 13}
				FontFace={BODY}
				TextColor3={Palette.creamSoft}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				LayoutOrder={3}
			/>
		</MockPanel>
	);

	// ---------- the vault: every echo you keep ----------
	const vaultCols = stack ? 1 : viewport.width >= (plan.split ? 1800 : 1500) ? 3 : 2;
	const ACT_H = 34;
	const vaultCellH = echoCardHeight(ACT_H);
	const vaultGridH = inventory.size() > 0 ? gridHeight(inventory.size(), vaultCols, vaultCellH, pad.gap) : rowH;
	const vaultH = panelHeight(phone, head + vaultGridH);
	const stardust = tonumber(state.Stardust) ?? 0;
	const vaultPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="vault">
			<PanelHeading
				icon="Vault"
				title={`Kept ${inventory.size()}/${echoes.InventoryLimit ?? 0}`}
				note={`${compactNumber(echoes.Resonance ?? 0)} resonance`}
				phone={phone}
				layoutOrder={0}
			/>
			{inventory.size() > 0 ? (
				<CardGrid name="VaultCards" columns={vaultCols} cellH={vaultCellH} gap={pad.gap} height={vaultGridH} layoutOrder={1}>
					{inventory.map((echo, index) => {
						let partner: EchoItem | undefined;
						for (const other of inventory) {
							if (other.Uid !== echo.Uid && other.Trait === echo.Trait && other.Tier === echo.Tier && !other.Locked) partner = other;
						}
						const canFuse = partner !== undefined && !echo.Locked && EchoMath.nextTier(echo.Tier) !== undefined;
						const isArmed = armed === echo.Uid;
						const tuneCost = echo.TuneCost ?? 0;
						return (
							<EchoCard key={`v${echo.Uid ?? index}`} echo={echo} place="vault" index={index} actionsH={ACT_H}>
								<ShareBtn text="Slot" accent={Palette.violet} sm={true} onClick={() => setSlotting(slotting === echo.Uid ? undefined : echo.Uid)} reducedMotion={reducedMotion} layoutOrder={0} />
								<ShareBtn
									text={`Tune · ${compactNumber(tuneCost)}`}
									accent={Palette.mango}
									sm={true}
									disabled={stardust < tuneCost || echo.Level >= EchoMath.MAX_LEVEL}
									onClick={() => act({ Op: "Tune", Uid: echo.Uid })}
									reducedMotion={reducedMotion}
									layoutOrder={1}
								/>
								<ShareBtn
									text="Fuse"
									accent={Palette.mango}
									sm={true}
									disabled={!canFuse}
									onClick={() => act({ Op: "Fuse", A: echo.Uid, B: partner?.Uid })}
									reducedMotion={reducedMotion}
									layoutOrder={2}
								/>
								<ShareBtn text={echo.Locked ? "Unlock" : "Lock"} accent={Palette.mango} sec={true} sm={true} onClick={() => act({ Op: "Lock", Uid: echo.Uid })} reducedMotion={reducedMotion} layoutOrder={3} />
								<ShareBtn
									text={`Break · +${echo.Resonance ?? 0}`}
									accent={Palette.coral}
									sec={!isArmed}
									sm={true}
									disabled={echo.Locked === true}
									onClick={() => {
										const uid = echo.Uid;
										setArmed(uid);
										requestConfirm({
											title: "Break this echo?",
											body: `It's gone for good. You get ${echo.Resonance ?? 0} resonance back.`,
											confirmText: "Break",
											tone: "danger",
											onConfirm: () => {
												setArmed(undefined);
												act({ Op: "Dismantle", Uid: uid });
											},
											onCancel: () => setArmed(undefined),
										});
									}}
									reducedMotion={reducedMotion}
									layoutOrder={4}
								/>
							</EchoCard>
						);
					})}
				</CardGrid>
			) : (
				<MockRow phone={phone} icon="Vault" title="Nothing kept yet" sub="Fill the charge and strike." dim={true} layoutOrder={1} />
			)}
		</MockPanel>
	);

	// ---------- the journal: every trait at every tier ----------
	const tierCount = EchoMath.TIERS.size();
	const journalRows = EchoMath.TRAITS.size();
	const journalH = panelHeight(phone, head + stackSum(table.create(journalRows, rowH), pad.gap));
	const pipW = phone ? 150 : 200;
	const journalPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="journal">
			<PanelHeading icon="Journal" title="Journal" note="Max every tier for a bonus" phone={phone} layoutOrder={0} />
			{EchoMath.TRAITS.map((trait, index) => {
				const reached = echoes.Journal?.[trait.Id] ?? 0;
				const complete = reached >= tierCount;
				return (
					<MockRow
						key={trait.Id}
						phone={phone}
						icon={traitIcon("journal", trait.Id)}
						title={trait.Name}
						sub={complete ? "Complete, +3%" : undefined}
						accent={complete ? Palette.mango : Palette.creamSoft}
						height={rowH}
						rightWidth={pipW}
						right={EchoMath.TIERS.map((tier, t) => (
							<frame
								key={tier}
								Size={UDim2.fromOffset(math.floor((pipW - 8 * (tierCount - 1)) / tierCount), 8)}
								BackgroundColor3={t < reached ? tierColor(tier, Palette.mango) : Palette.lineSoft}
								BackgroundTransparency={t < reached ? 0 : 0.4}
								BorderSizePixel={0}
								LayoutOrder={t}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
							</frame>
						))}
						layoutOrder={1 + index}
					/>
				);
			})}
		</MockPanel>
	);

	const blocks: Section[] = [{ id: "loom", height: loomH, element: loomPanel }];
	if (draft.size() > 0) blocks.push({ id: "draft", height: draftH, element: draftPanel });
	blocks.push({ id: "chord", height: chordH, element: chordPanel });
	blocks.push({ id: "vault", height: vaultH, element: vaultPanel });
	blocks.push({ id: "journal", height: journalH, element: journalPanel });

	let sections: Section[] = blocks;
	if (plan.split) {
		const sideIds = ["chord", "journal"];
		const side = blocks.filter((block) => sideIds.includes(block.id));
		const main = blocks.filter((block) => !sideIds.includes(block.id));
		const mainH = stackSum(main.map((block) => block.height), gap);
		const sideH = stackSum(side.map((block) => block.height), gap);
		const column = (list: Section[], width?: number) => (
			<FlexCol gap={gap} width={width}>
				{list.map((block, index) => (
					<frame key={block.id} Size={new UDim2(1, 0, 0, block.height)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={index}>
						{block.element}
					</frame>
				))}
			</FlexCol>
		);
		sections = [
			{
				id: "EchoesSplit",
				height: math.max(mainH, sideH),
				element: (
					<FlexRow fillHeight={true} gap={gap} name="EchoesSplit">
						<FlexFill layoutOrder={0} name="Main">
							{column(main)}
						</FlexFill>
						<FlexFixed width={460} layoutOrder={1} name="Side">
							{column(side, 460)}
						</FlexFixed>
					</FlexRow>
				),
			},
		];
	}
	return (
		<frame ref={echoHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold gap={gap} tailPad={scrollTail(chrome.stack, chrome.bottomSafe, stack ? 72 : 56)} scrollBarColor={Palette.mango} scrollBarThickness={4} sections={sections} owner="EchoForgeView" />
		</frame>
	);
}
