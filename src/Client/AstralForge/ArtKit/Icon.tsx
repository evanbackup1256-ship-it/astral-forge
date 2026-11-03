import React from "@rbxts/react";
import { useExitPresence } from "../MotionKit/motion";
import { Palette, relativeLuminance } from "../CoreKit/theme";
import IconManifest = require("../IconManifest");
import IconParts = require("../IconParts");

function fadeWithPresence(local_: number | React.Binding<number>, presence: React.Binding<number>): React.Binding<number> {
	if (typeIs(local_, "number")) {
		return presence.map((shown) => math.clamp(local_ + (1 - shown), 0, 1));
	}
	return React.joinBindings([local_, presence]).map((values) => math.clamp(values[0] + (1 - values[1]), 0, 1));
}

export const VECTOR_ICON_ATLAS = "rbxassetid://139083324249955";
export const GAME_ICON_ASSET = "rbxassetid://121817586227688";
export const WORDMARK_ASSET = "rbxassetid://86009183337926";
export const COMPACT_MARK_ASSET = "rbxassetid://89091028537454";
export const LOCKUP_ASSET = "rbxassetid://101461082924090";
// the layered badge (tools/assetgen/build_logo_v2.py): empty until the art is uploaded, and the lockup then
// falls back to the single COMPACT_MARK_ASSET image with no moving parts
export const MARK_BASE_ASSET = "rbxassetid://111299914966503";
export const MARK_STAR_ASSET = "rbxassetid://71928764282310";
export const MARK_GLOW_ASSET = "rbxassetid://72727781584028";
export const VECTOR_ICON_CELL = 128;
export const VECTOR_ICON_COLUMNS = 8;
export const VECTOR_ICON_INDEX: Record<string, number> = {
	Brand: 0,
	Flux: 1,
	Core: 2,
	Dust: 3,
	Forge: 4,
	Research: 5,
	Grid: 6,
	World: 7,
	Mission: 8,
	Milestone: 9,
	Leaderboard: 10,
	Crew: 11,
	Guild: 12,
	Wheel: 13,
	Games: 14,
	Credits: 15,
	Gift: 16,
	Guide: 17,
	Settings: 18,
	Close: 19,
	Menu: 20,
	Chevron: 21,
	Back: 22,
	Check: 23,
	StarGrid: 24,
	Command: 25,
	Anomaly: 26,
	Reactor: 27,
	Lab: 28,
	Loadout: 29,
	Artifact: 30,
	Vault: 31,
	Rebirth: 32,
	Hide: 33,
	Lock: 34,
	Story: 35,
	Mail: 36,
	Chat: 37,
	Shop: 38,
	Boost: 39,
	Jackpot: 40,
	Admin: 44,
	Pilot: 45,
	Overview: 46,
	Inventory: 47,
	Continuum: 48,
	Rewards: 49,
	Collect: 50,
	Overcharge: 51,
	Domain: 52,
	Search: 53,
	Pause: 54,
	Play: 55,
	Refresh: 56,
	Send: 57,
	Code: 58,
	Crate: 59,
	Calendar: 60,
	Timer: 61,
	Wave: 62,
	Visit: 63,
};

function vectorIconIndex(kind: unknown): number {
	if (typeIs(kind, "string")) {
		const index = VECTOR_ICON_INDEX[kind] as number | undefined;
		if (index !== undefined) {
			return index;
		}
	}
	return VECTOR_ICON_INDEX.Guide;
}

export function VectorIconFace({
	kind,
	color,
	transparency = 0,
}: {
	kind: unknown;
	color?: Color3;
	transparency?: number | React.Binding<number>;
}) {
	const presence = useExitPresence();
	const faded = React.useMemo(() => fadeWithPresence(transparency, presence), [transparency, presence]);
	const index = vectorIconIndex(kind);
	const column = index % VECTOR_ICON_COLUMNS;
	const row = math.floor(index / VECTOR_ICON_COLUMNS);
	return (
		<imagelabel
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Image={VECTOR_ICON_ATLAS}
			ImageColor3={color}
			ImageTransparency={faded}
			ImageRectOffset={new Vector2(column * VECTOR_ICON_CELL, row * VECTOR_ICON_CELL)}
			ImageRectSize={new Vector2(VECTOR_ICON_CELL, VECTOR_ICON_CELL)}
			ScaleType={Enum.ScaleType.Stretch}
		/>
	);
}

const ITEM_ICONS: Record<string, string> = {
	IonCoupler: "Command.1",
	FluxLens: "Flux.1",
	CapacityCoil: "Vault.1",
	PulseInjector: "Anomaly.1",
	AutoRelay: "Grid.1",
	ChronoSeal: "Rebirth.1",
	CriticalPrism: "Artifact.1",
	StarDrive: "World.1",
	QuantumCatalyst: "Lab.1",
	VaultHeart: "Core.1",
	SingularityCore: "Brand.1",
	Omniframe: "Loadout.1",
};

export function itemIconKind(definitionId: string, slot?: string): string {
	return (ITEM_ICONS[definitionId] as string | undefined) ?? (slot === "Machine" ? "Forge.item" : "Research.item");
}

interface RewardLike {
	Cores?: number;
	Stardust?: number;
	Boost?: unknown;
	FreeSpins?: unknown;
	Keys?: unknown;
	CashMinutes?: number;
	Signals?: unknown;
	CommandXP?: unknown;
	Essence?: unknown;
}

// Luau truthiness on reward fields (0 counts as present).
const set = (value: unknown) => value !== undefined && value !== false;

export function rewardIconKind(reward: RewardLike): string {
	if (set(reward.Cores)) return "Core.reward";
	if (set(reward.Stardust)) return "Dust.reward";
	if (set(reward.Boost)) return "Boost.reward";
	if (set(reward.FreeSpins)) return "Wheel.reward";
	if (set(reward.Keys)) return "Crate.reward";
	if (set(reward.CashMinutes)) return "Flux.reward";
	if (set(reward.Signals) || set(reward.CommandXP)) return "Command.reward";
	if (set(reward.Essence)) return "Artifact.reward";
	return "Gift.reward";
}

function GlyphFace({
	kind,
	color,
	transparency = 0,
}: {
	kind: unknown;
	color?: Color3;
	transparency?: number | React.Binding<number>;
}) {
	return <VectorIconFace kind={kind} color={color} transparency={transparency} />;
}

function semanticIconColor(kind: unknown): Color3 {
	switch (kind) {
		case "Dust":
		case "Forge":
		case "Milestone":
		case "Wheel":
		case "Gift":
		case "Shop":
		case "Jackpot":
		case "Collect":
		case "Code":
		case "Calendar":
			return Palette.mango;
		case "Core":
		case "Research":
		case "StarGrid":
		case "Anomaly":
		case "Artifact":
		case "Rebirth":
		case "Continuum":
		case "Inventory":
		case "Crate":
			return Palette.violet;
		case "Close":
		case "Hide":
		case "Lock":
		case "Admin":
			return Palette.coral;
		case "Check":
		case "Crew":
		case "Guild":
		case "Games":
		case "Boost":
		case "Play":
		case "Visit":
			return Palette.mint;
		case "Brand":
		case "Mission":
		case "Guide":
		case "Settings":
		case "Credits":
		case "Story":
		case "Lab":
		case "Rewards":
		case "Domain":
		case "Wave":
			return Palette.pink;
		default:
			return Palette.cyan;
	}
}

function coloredFace(kind: unknown, requested: Color3 | undefined): Color3 {
	return requested ?? semanticIconColor(kind);
}

export function PlayerMark({
	userId,
	accent,
	color = Palette.cream,
	size = 28,
	position,
	anchorPoint,
}: {
	userId: number;
	accent?: Color3;
	color?: Color3;
	size?: number;
	position?: UDim2;
	anchorPoint?: Vector2;
}) {
	const seed = math.abs(math.floor(userId));
	const mark = "Pilot.mark";
	if (artFor(mark)[0] !== undefined) {
		return <Icon kind={mark} size={size} position={position} anchorPoint={anchorPoint} />;
	}
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			<frame
				Size={UDim2.fromScale(0.82, 0.82)}
				Position={new UDim2(0.5, seed % 2 === 0 ? 1 : -1, 0.5, 1)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<GlyphFace kind="Pilot" color={color} transparency={0.38} />
			</frame>
			<frame
				Size={UDim2.fromScale(0.82, 0.82)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<GlyphFace kind="Pilot" color={accent} />
			</frame>
		</frame>
	);
}

// Every icon id (a concept, a dot, then its use) has its own art in IconManifest: a body cell and a
// light cell. Icons draw the body cell only and never move. The light cell carries the twinkle
// sparkle that used to animate; frozen, it sits as a stray mark beside the art. Ids that aren't
// drawn yet fall back to their concept's base icon, then to the old vector atlas.
function conceptOf(kind: unknown): string {
	return typeIs(kind, "string") ? ((kind.match("^[^.]+")[0] as string | undefined) ?? kind) : "Guide";
}
export { conceptOf as iconConcept };

type IconEntry = NonNullable<(typeof IconManifest.Icons)[string]>;

function artFor(kind: unknown): LuaTuple<[IconEntry?, string?]> {
	const icons = IconManifest.Icons;
	const entry = icons[kind as string] ?? icons[conceptOf(kind)];
	if (entry === undefined) {
		return $tuple(undefined);
	}
	const sheet = IconManifest.Sheets[entry.b[0]] as string | undefined;
	if (sheet === undefined || sheet === "") {
		return $tuple(undefined);
	}
	return $tuple(entry, sheet);
}

export interface IconProps {
	kind: unknown;
	size?: number;
	position?: UDim2;
	anchorPoint?: Vector2;
	color?: Color3;
	accent?: Color3;
	// icons no longer animate; callers written for the old motion may still pass these
	spin?: boolean;
	hoverAmount?: React.Binding<number>;
}

// ── Composed icons ─────────────────────────────────────────────────────────────
// Once the v2 sheets are uploaded (tools/assetgen/icons_v2.py --activate fills IconParts.Sheets), an
// icon is stacked from a few small parts instead of being one baked sprite:
//   plate   a grayscale sprite multiplied by the accent: dark base, accent rim
//   glyph   the concept's pictogram, or for a generated machine/study its noun (Loom, Lattice ...)
//   pips    tier marks along the foot
//   mark    a small emblem top right: the modifier (Aether, Folded ...), or for a numbered id the
//           id's own emblem, so "Forge.7" and "Forge.8" differ
// Every generated machine and study is noun + modifier + tier + its own hue, so each is unique.
// Control icons (close, back, check ...) are one white sprite tinted with the label beside them.
type PartCell = [sheet: number, x: number, y: number];
const partsLive = IconParts.Sheets[0] !== undefined && IconParts.Sheets[0] !== "";

interface Composed {
	control?: PartCell;
	plate?: PartCell;
	accent?: Color3;
	glyph?: PartCell;
	mark?: PartCell;
	// the emblem is ~44% of the icon: below this drawn size it is a smudge, not a symbol, so it is left out
	markMinSize?: number;
	pips?: PartCell;
}

function textHash(text: string): number {
	let hash = 0;
	for (let i = 1; i <= text.size(); i++) {
		hash = (hash * 31 + string.byte(text, i)[0]) % 100003;
	}
	return hash;
}

// The colour a plate takes. A caller that knows the icon's context (the nav rail passes its page's accent,
// or muted when the page is not the current one) is trusted, so an icon is paired with the colour of
// what it sits in. A hint that is not a plain colour (a binding) or is too dark to read as an accent
// (ink on a button) is ignored and the concept's own colour is used.
function plateAccent(hint: unknown, concept: string): Color3 {
	if (typeOf(hint) === "Color3" && relativeLuminance(hint as Color3) > 0.22) {
		return hint as Color3;
	}
	return semanticIconColor(concept);
}

function composedFor(kind: unknown, hint?: unknown): Composed | undefined {
	if (!partsLive || !typeIs(kind, "string")) {
		return undefined;
	}
	const thing = IconParts.Things[kind];
	if (thing !== undefined) {
		const noun = IconParts.Noun[thing[0]];
		if (noun === undefined) {
			return undefined;
		}
		return {
			plate: IconParts.Plate[thing[4] === 1 ? "round" : "square"],
			accent: Color3.fromHSV(thing[3] / 360, 0.5, 0.95),
			glyph: noun,
			mark: IconParts.Mark[thing[1]],
			markMinSize: 32,
			pips: thing[2] > 1 ? IconParts.Pips[thing[2] - 1] : undefined,
		};
	}
	const concept = conceptOf(kind);
	const control = IconParts.Control[concept];
	if (control !== undefined) {
		return { control };
	}
	const glyph = IconParts.Glyph[concept];
	if (glyph === undefined) {
		return undefined;
	}
	// "Forge.7": the number (or any other tail) picks the emblem
	const tail = kind.sub(concept.size() + 2);
	let mark: PartCell | undefined;
	if (tail !== "") {
		const order = IconParts.MarkOrder;
		const number = tonumber(tail);
		const index = number !== undefined ? (math.floor(number) - 1) % order.size() : textHash(tail) % order.size();
		mark = IconParts.Mark[order[index]];
	}
	return {
		plate: IconParts.Plate[IconParts.Round[concept] === true ? "round" : "square"],
		accent: plateAccent(hint, concept),
		glyph,
		mark,
		markMinSize: 44,
	};
}

function PartImage(props: { cell: PartCell; z: number; tint?: Color3; size?: UDim2; position?: UDim2 }) {
	const cell = IconParts.Cell;
	return (
		<imagelabel
			Size={props.size ?? UDim2.fromScale(1, 1)}
			Position={props.position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Image={IconParts.Sheets[props.cell[0]]}
			ImageColor3={props.tint}
			ImageRectOffset={new Vector2(props.cell[1], props.cell[2])}
			ImageRectSize={new Vector2(cell, cell)}
			ZIndex={props.z}
		/>
	);
}

function ComposedIcon(props: { plan: Composed; size: number; position?: UDim2; anchorPoint?: Vector2; color?: Color3 }) {
	const { plan, size } = props;
	const box = UDim2.fromOffset(size, size);
	if (plan.control !== undefined) {
		return (
			<frame Size={box} Position={props.position} AnchorPoint={props.anchorPoint} BackgroundTransparency={1} BorderSizePixel={0}>
				<PartImage cell={plan.control} z={1} tint={props.color ?? Palette.cream} />
			</frame>
		);
	}
	return (
		<frame Size={box} Position={props.position} AnchorPoint={props.anchorPoint} BackgroundTransparency={1} BorderSizePixel={0}>
			{plan.plate !== undefined && <PartImage cell={plan.plate} z={1} tint={plan.accent} />}
			{plan.glyph !== undefined && <PartImage cell={plan.glyph} z={2} />}
			{plan.pips !== undefined && <PartImage cell={plan.pips} z={3} />}
			{plan.mark !== undefined && size >= (plan.markMinSize ?? 0) && <PartImage cell={plan.mark} z={4} size={UDim2.fromScale(0.44, 0.44)} position={UDim2.fromScale(0.58, 0)} />}
		</frame>
	);
}

export function Icon(props: IconProps) {
	const { kind, size = 28, position, anchorPoint } = props;
	const composed = composedFor(kind, props.accent);
	if (composed !== undefined) {
		return <ComposedIcon plan={composed} size={size} position={position} anchorPoint={anchorPoint} color={props.color} />;
	}
	const [entry, sheet] = artFor(kind);
	if (entry === undefined) {
		// not drawn yet: the old flat glyph
		return (
			<frame Size={UDim2.fromOffset(size, size)} Position={position} AnchorPoint={anchorPoint} BackgroundTransparency={1}>
				<GlyphFace kind={conceptOf(kind)} color={props.color ?? coloredFace(conceptOf(kind), props.accent)} />
			</frame>
		);
	}
	const cell = IconManifest.Cell;
	return (
		<imagelabel
			Size={UDim2.fromOffset(size, size)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Image={sheet}
			ImageRectOffset={new Vector2(entry.b[1], entry.b[2])}
			ImageRectSize={new Vector2(cell, cell)}
		/>
	);
}
