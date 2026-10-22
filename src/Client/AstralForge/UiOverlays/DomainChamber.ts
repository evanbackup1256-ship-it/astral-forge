// (ZIndex 600+: the main screen sorts globally and the chamber has to sit over the whole shell)
// The Domain, one screen: the lattice on the left, and on the right whatever you're doing with it.
//   mode "lattice": etch links between anchors, read what the lattice gives, clear it once per rank
//   mode "confirm": the expansion rite; hold to expand, with what it costs, keeps and pays
//   mode "result":  a ring of heat leaves the Hearth, the new rank lands and the rewards count in
import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { useViewport } from "../MotionKit/motion";
import { Button } from "../UiCore/ui";
import { Icon } from "../ArtKit/Icon";
import { darken, Palette, Radius, Space, TapTarget } from "../CoreKit/theme";
import { compactNumber } from "../CoreKit/format";
import DomainLattice = require("../../../Shared/AstralForge/Shared/DomainLattice");

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

type Dict = Record<string, unknown>;
// Props stay as loose tables, exactly as the Luau chamber built them.
const h = React.createElement as unknown as (component: unknown, props?: unknown, ...children: unknown[]) => React.Element;

interface DomainConfig {
	SurgeBoostId?: string;
	SkillPointPerRank?: number;
	Expansion?: { FreeSpins?: number };
}
interface GameConfigShape {
	Boosts?: Record<string, { Duration?: unknown } | undefined>;
	Domain: DomainConfig;
}

const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as GameConfigShape;

const WHITE_HOT = Color3.fromRGB(255, 244, 222);
const HOLD_SECONDS = 1.1;
const SCALE = 0.5 / 2.2;
const KIND_COLOR: Record<string, Color3 | undefined> = {
	Production: Palette.mango,
	Capacity: Palette.cyan,
	Tap: Palette.coral,
	RebirthYield: Palette.violet,
	Critical: Palette.pink,
	EchoCharge: Palette.mint,
	ContinuumDiscount: Palette.mango,
	Offline: Palette.cyan,
	Luck: Palette.mint,
	WorldDiscount: Palette.violet,
	EssenceGain: Palette.pink,
	ForgePathXP: Palette.mango,
	CommandXP: Palette.coral,
};
const KIND_ICON: Record<string, string | undefined> = {
	Production: "Flux.23",
	Capacity: "Vault.9",
	Tap: "Overcharge.10",
	RebirthYield: "Rebirth.10",
	Critical: "Jackpot.4",
	EchoCharge: "Wave.17",
	ContinuumDiscount: "Continuum.4",
	Offline: "Timer.9",
	Luck: "Gift.18",
	WorldDiscount: "World.12",
	EssenceGain: "Artifact.9",
	ForgePathXP: "Milestone.7",
	CommandXP: "Command.6",
};
const KEEPS = "Research, relics, Stardust, milestones, your crew and guild";
const RESETS = "Machines, Flux, the vault, worlds, and the rebirths and Cores you spend";

type Links = Record<string, boolean | undefined>;

function easeOut(t: number): number {
	const u = 1 - math.clamp(t, 0, 1);
	return 1 - u * u * u;
}
function asNumber(value: unknown): number {
	const n = tonumber(value);
	return n !== undefined && n === n ? n : 0;
}
function spot(index: number): LuaTuple<[number, number]> {
	const [x, y] = DomainLattice.position(index);
	return $tuple(0.5 + x * SCALE, 0.5 + y * SCALE);
}
function colorOf(index: number): Color3 {
	const anchor = DomainLattice.ANCHORS[index];
	return (anchor && KIND_COLOR[anchor.kind]) || Palette.mango;
}
function splitKey(key: string): LuaTuple<[number, number]> {
	const [a, b] = string.match(key, "^(%d+)%-(%d+)$");
	return $tuple(tonumber(a) as number, tonumber(b) as number);
}
// a line between two points of the square canvas, drawn `p` of the way from the first
function line(x1: number, y1: number, x2: number, y2: number, thickness: number, p: number): LuaTuple<[UDim2, UDim2, number]> {
	const dx = (x2 - x1) * p;
	const dy = (y2 - y1) * p;
	const length = math.sqrt(dx * dx + dy * dy);
	return $tuple(
		new UDim2(length, 0, 0, thickness),
		UDim2.fromScale(x1 + dx / 2, y1 + dy / 2),
		math.deg(math.atan2(y2 - y1, x2 - x1)),
	);
}
function surgeLabel(): string {
	const boost = GameConfig.Boosts && GameConfig.Boosts[GameConfig.Domain.SurgeBoostId ?? "DomainSurge"];
	if (boost === undefined) {
		return "Domain Surge";
	}
	const minutes = math.floor((tonumber(boost.Duration) ?? 1800) / 60 + 0.5);
	return `Domain Surge for ${minutes} min`;
}

// what etching a link would change, for the preview
function etchPreview(links: Links, key: string) {
	const [a, b] = splitKey(key);
	const degree = DomainLattice.degrees(links);
	const lines: Array<{ color: Color3; text: string }> = [];
	for (const index of [a, b]) {
		const anchor = DomainLattice.ANCHORS[index];
		const d = degree[index] ?? 0;
		const gain = DomainLattice.anchorBonus(index, d + 1) - DomainLattice.anchorBonus(index, d);
		lines.push({ color: colorOf(index), text: `${anchor.name}: ${DomainLattice.describe(anchor.kind, gain)}` });
	}
	const after = table.clone(links);
	after[key] = true;
	const closes = DomainLattice.facets(after).size() - DomainLattice.facets(links).size();
	if (closes > 0) {
		lines.push({
			color: Palette.mango,
			text: `Closes ${closes === 1 ? "a facet" : closes + " facets"}: ${DomainLattice.describe("Production", closes * DomainLattice.FACET_PRODUCTION)}`,
		});
	}
	return lines;
}

interface Selection {
	kind: "link" | "anchor";
	id: string | number;
}

interface LatticeProps {
	links: Links;
	tick: React.Binding<number>;
	flare: React.Binding<number>;
	selected?: Selection;
	etchedAt: Record<string, number | undefined>;
	facetAt: Record<number, number | undefined>;
	anchorRefs: Record<number, Instance | undefined>;
	reduced: boolean;
	onLink: (key: string) => void;
	onAnchor: (index: number) => void;
}

function Lattice(props: LatticeProps) {
	const links = props.links;
	const tick = props.tick;
	const selected = props.selected;
	const degree = DomainLattice.degrees(links);
	const facetSet = new Set<number>();
	for (const index of DomainLattice.facets(links)) {
		facetSet.add(index);
	}
	const reached = new Set<number>([DomainLattice.HEARTH]);
	for (const [index, d] of pairs(degree)) {
		if (d > 0) {
			reached.add(index);
		}
	}
	const children: Record<string, unknown> = {};
	// the figure's guide rings, faint like a drafting sheet
	const rings = [1, 1.92];
	for (let ring = 1; ring <= rings.size(); ring++) {
		const radius = rings[ring - 1];
		const s = radius * SCALE * 2;
		children["guide" + ring] = h(
			"frame",
			{
				Size: UDim2.fromScale(s, s),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 602,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: Palette.line, Thickness: 1, Transparency: 0.55 }),
		);
	}
	// the heat ring that leaves the Hearth when a rank lands
	children.flare = h(
		"frame",
		{
			Size: props.flare.map((f) => {
				const s = easeOut(f) * 1.3;
				return UDim2.fromScale(s, s);
			}),
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			Visible: props.flare.map((f) => f > 0.001 && f < 1),
			ZIndex: 609,
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h("uistroke", {
			Color: WHITE_HOT,
			Thickness: props.flare.map((f) => 2 + (1 - f) * 10),
			Transparency: props.flare.map((f) => f),
		}),
	);
	for (const e of DomainLattice.EDGES) {
		const [x1, y1] = spot(e.a);
		const [x2, y2] = spot(e.b);
		const etched = links[e.key] === true;
		const open = !etched && (reached.has(e.a) || reached.has(e.b));
		const picked = selected !== undefined && selected.kind === "link" && selected.id === e.key;
		if (etched) {
			// molten: a glow, a hot core drawing itself in from the Hearth's side, and a beat running outward
			const key = e.key;
			const drawn = (now: number) => {
				const at = props.etchedAt[key];
				return at === undefined ? 1 : easeOut((now - at) / 0.42);
			};
			const [, , rot] = line(x1, y1, x2, y2, 10, 1);
			children["glow" + key] = h(
				"frame",
				{
					Size: tick.map((now) => line(x1, y1, x2, y2, 10, drawn(now))[0]),
					Position: tick.map((now) => line(x1, y1, x2, y2, 10, drawn(now))[1]),
					Rotation: rot,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: Palette.ember,
					BackgroundTransparency: 0.78,
					BorderSizePixel: 0,
					ZIndex: 603,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			);
			children["core" + key] = h(
				"frame",
				{
					Size: tick.map((now) => line(x1, y1, x2, y2, 3, drawn(now))[0]),
					Position: tick.map((now) => line(x1, y1, x2, y2, 3, drawn(now))[1]),
					Rotation: rot,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: Palette.white,
					BorderSizePixel: 0,
					ZIndex: 604,
				},
				h("uigradient", {
					Color: new ColorSequence([
						new ColorSequenceKeypoint(0, Palette.mango),
						new ColorSequenceKeypoint(0.5, WHITE_HOT),
						new ColorSequenceKeypoint(1, Palette.mango),
					]),
					Offset: tick.map((now) => new Vector2(math.sin(now * 1.3 + e.a) * 0.4, 0)),
				}),
			);
			if (!props.reduced) {
				const phase = (e.a * 0.37 + e.b * 0.21) % 1;
				children["beat" + key] = h(
					"frame",
					{
						Size: UDim2.fromOffset(5, 5),
						Position: tick.map((now) => {
							const p = (now * 0.55 + phase) % 1;
							return UDim2.fromScale(x1 + (x2 - x1) * p, y1 + (y2 - y1) * p);
						}),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundColor3: WHITE_HOT,
						BackgroundTransparency: tick.map((now) => (drawn(now) < 1 ? 1 : 0.1)),
						BorderSizePixel: 0,
						ZIndex: 605,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				);
			}
		} else {
			const [size, pos, rot] = line(x1, y1, x2, y2, open ? (picked ? 3 : 2) : 1, 1);
			children["line" + e.key] = h("frame", {
				Size: size,
				Position: pos,
				Rotation: rot,
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: picked ? WHITE_HOT : open ? Palette.mango : Palette.lineSoft,
				BackgroundTransparency: picked
					? 0
					: open
						? tick.map((now) => 0.35 + (math.sin(now * 3 + e.a + e.b) + 1) * 0.2)
						: 0.55,
				BorderSizePixel: 0,
				ZIndex: 603,
			});
			if (open) {
				const [hitSize, hitPos] = line(x1, y1, x2, y2, 22, 0.7);
				children["hit" + e.key] = h("textbutton", {
					Size: hitSize,
					Position: hitPos,
					Rotation: rot,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					Text: "",
					AutoButtonColor: false,
					ZIndex: 606,
					Event: {
						Activated: () => {
							props.onLink(e.key);
						},
					},
				});
			}
		}
	}
	// facets: a lit mark in the middle of every closed triangle
	for (let index = 1; index <= DomainLattice.TRIANGLES.size(); index++) {
		const t = DomainLattice.TRIANGLES[index - 1];
		if (facetSet.has(index)) {
			let cx = 0;
			let cy = 0;
			for (const corner of t) {
				const [x, y] = spot(corner);
				cx += x / 3;
				cy += y / 3;
			}
			children["facet" + index] = h(
				"frame",
				{
					Size: UDim2.fromOffset(16, 16),
					Position: UDim2.fromScale(cx, cy),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					ZIndex: 605,
				},
				h("uiscale", {
					Scale: tick.map((now) => {
						const at = props.facetAt[index];
						const pop = at === undefined ? 0 : 1 - easeOut((now - at) / 0.4);
						return 1 + pop * 1.6 + math.sin(now * 2 + index) * 0.08;
					}),
				}),
				h(Icon, { kind: "StarGrid.6", color: Palette.mango, accent: WHITE_HOT, size: 16, spin: false }),
			);
		}
	}
	// the anchors: a cut stone, filled as its links are etched, with a pip for every link it can take
	for (const [, anchor] of pairs(DomainLattice.ANCHORS)) {
		const index = anchor.index;
		const [x, y] = spot(index);
		const color = KIND_COLOR[anchor.kind] ?? Palette.mango;
		const d = degree[index] ?? 0;
		const maxD = DomainLattice.maxDegree(index);
		const fill = d / math.max(1, maxD);
		const isHearth = index === DomainLattice.HEARTH;
		const stone = isHearth ? 34 : 24;
		const picked = selected !== undefined && selected.kind === "anchor" && selected.id === index;
		const pips: Record<string, unknown> = {};
		for (let pip = 1; pip <= maxD; pip++) {
			const a = math.rad(-90 + ((pip - 1) * 360) / maxD);
			const r = isHearth ? 0.5 : 0.42;
			pips["p" + pip] = h(
				"frame",
				{
					Size: UDim2.fromOffset(4, 4),
					Position: UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: pip <= d ? color : Palette.lineSoft,
					BackgroundTransparency: pip <= d ? 0 : 0.4,
					BorderSizePixel: 0,
					ZIndex: 608,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			);
		}
		children["anchor" + index] = h(
			"textbutton",
			{
				ref: (instance: Instance | undefined) => {
					props.anchorRefs[index] = instance;
				},
				Size: UDim2.fromOffset(isHearth ? 64 : 50, isHearth ? 64 : 50),
				Position: UDim2.fromScale(x, y),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				ZIndex: 607,
				Event: {
					Activated: () => {
						props.onAnchor(index);
					},
				},
			},
			h(
				"frame",
				{
					// a plate that warms with the anchor's links, carrying its bonus's icon
					Size: UDim2.fromOffset(stone + 6, stone + 6),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: darken(color, 0.7 - fill * 0.35),
					BorderSizePixel: 0,
					ZIndex: 608,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uistroke", {
					Color: picked || fill >= 1 ? WHITE_HOT : color,
					Thickness: picked ? 2.5 : 1.5,
					Transparency: d > 0 || isHearth ? 0 : 0.45,
				}),
				h(Icon, {
					kind: KIND_ICON[anchor.kind] ?? "Domain.6",
					color: d > 0 || isHearth ? Palette.cream : Palette.muted,
					accent: color,
					size: stone - 4,
					spin: false,
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
				}),
			),
			h("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 608 }, pips),
			picked &&
				h(
					"frame",
					{
						// a bracket that turns slowly around the picked anchor
						Size: UDim2.fromScale(1.05, 1.05),
						Position: UDim2.fromScale(0.5, 0.5),
						AnchorPoint: new Vector2(0.5, 0.5),
						Rotation: tick.map((now) => (now * 40) % 360),
						BackgroundTransparency: 1,
						ZIndex: 607,
					},
					h("uistroke", { Color: WHITE_HOT, Thickness: 1, Transparency: 0.35 }),
				),
			h("textlabel", {
				Size: UDim2.fromOffset(110, 14),
				Position: new UDim2(0.5, 0, 1, isHearth ? 0 : -2),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				Text: anchor.name,
				TextSize: isHearth ? 13 : 11,
				FontFace: Font.fromEnum(isHearth ? Enum.Font.BuilderSansExtraBold : Enum.Font.BuilderSansBold),
				TextColor3: d > 0 || isHearth ? Palette.cream : Palette.muted,
				ZIndex: 609,
			}),
		);
	}
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			ZIndex: 602,
		},
		h("uiaspectratioconstraint", { AspectRatio: 1 }),
		children,
	);
}

interface RowProps {
	height?: number;
	order?: number;
	label?: string;
	value?: string;
	size?: number;
	labelColor?: Color3;
	valueColor?: Color3;
	fade?: number | React.Binding<number>;
}

function Row(props: RowProps) {
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, props.height ?? 24),
			LayoutOrder: props.order,
			BackgroundTransparency: 1,
			ZIndex: 632,
		},
		h("textlabel", {
			Size: new UDim2(1, -110, 1, 0),
			BackgroundTransparency: 1,
			Text: props.label,
			TextSize: props.size ?? 13,
			TextWrapped: true,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextColor3: props.labelColor ?? Palette.creamSoft,
			TextXAlignment: Enum.TextXAlignment.Left,
			TextTransparency: props.fade ?? 0,
			ZIndex: 633,
		}),
		props.value !== undefined &&
			h("textlabel", {
				Size: new UDim2(0, 110, 1, 0),
				Position: UDim2.fromScale(1, 0),
				AnchorPoint: new Vector2(1, 0),
				BackgroundTransparency: 1,
				Text: props.value,
				TextSize: props.size ?? 13,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				TextColor3: props.valueColor ?? Palette.cream,
				TextXAlignment: Enum.TextXAlignment.Right,
				TextTransparency: props.fade ?? 0,
				ZIndex: 633,
			}),
	);
}

function Heading(props: { order?: number; text: string; color?: Color3 }) {
	return h("textlabel", {
		Size: new UDim2(1, 0, 0, 20),
		LayoutOrder: props.order,
		BackgroundTransparency: 1,
		Text: props.text,
		TextSize: 13,
		FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
		TextColor3: props.color ?? Palette.mango,
		TextXAlignment: Enum.TextXAlignment.Left,
		ZIndex: 633,
	});
}

interface DomainState {
	Rank?: unknown;
	Links?: unknown;
	SkillPoints?: unknown;
	LatticeClearedAtRank?: unknown;
	ProductionMultiplier?: unknown;
	CanExpand?: unknown;
	RequiredRebirths?: unknown;
	RequiredCores?: unknown;
	EssenceReward?: unknown;
	StardustReward?: unknown;
}
interface LatticeResponse {
	ok?: unknown;
	Links?: unknown;
	SkillPoints?: unknown;
	ClosedFacet?: unknown;
	message?: string;
}
interface DomainResult {
	rank?: number;
	essence?: unknown;
	stardust?: unknown;
	freeSpins?: unknown;
	overflow?: unknown;
	nextRebirths?: unknown;
	nextCores?: unknown;
}
interface ChamberProps {
	domain?: DomainState;
	mode: string;
	reducedMotion?: boolean;
	rebirths?: unknown;
	cores?: unknown;
	result?: DomainResult;
	busy?: boolean;
	dispatch: (action: string, payload: Dict, callback: (response: LatticeResponse) => void) => void;
	onConfirm: () => void;
	onMode: (mode: string) => void;
	onClose: () => void;
}
interface Action {
	text: string;
	primary?: boolean;
	quiet?: boolean;
	hold?: boolean;
	disabled?: boolean;
	onClick?: () => void;
}

function DomainChamber(props: ChamberProps) {
	const domain = props.domain ?? {};
	let mode = props.mode;
	const rank = math.max(0, math.floor(asNumber(domain.Rank)));
	if (rank < 1 && mode === "lattice") {
		mode = "confirm";
	}
	const viewport = useViewport();
	const stacked = viewport.width < 760 || viewport.width < viewport.height;
	const reduced = props.reducedMotion === true;
	const [tick, setTick] = React.useBinding(os.clock());
	const [flare, setFlare] = React.useBinding(0);
	const [hold, setHold] = React.useBinding(0);
	const [selected, setSelected] = React.useState<Selection | undefined>(undefined);
	const [override, setOverride] = React.useState<{ links: Links; points: number } | undefined>(undefined);
	const [note, setNote] = React.useState<string | undefined>(undefined);
	const etchedAt = React.useRef<Record<string, number | undefined>>({});
	const facetAt = React.useRef<Record<number, number | undefined>>({});
	const anchorRefs = React.useRef<Record<number, Instance | undefined>>({});
	const resultAt = React.useRef(0);
	const holding = React.useRef<number | undefined>(undefined);
	const fired = React.useRef(false);
	const requesting = React.useRef(false);

	React.useEffect(() => {
		setOverride(undefined);
	}, [domain.Links, domain.SkillPoints]);
	const links: Links = override ? override.links : typeIs(domain.Links, "table") ? (domain.Links as Links) : {};
	const points = override ? override.points : math.floor(asNumber(domain.SkillPoints));
	const etched = DomainLattice.count(links);
	const nextCost = DomainLattice.linkCost(etched);
	const canClear = rank >= 1 && etched > 0 && asNumber(domain.LatticeClearedAtRank) < rank;

	React.useEffect(() => {
		if (mode === "result") {
			resultAt.current = os.clock();
			Audio.play("domainImpact");
		} else if (mode === "confirm") {
			Audio.play("open");
		}
		fired.current = false;
		holding.current = undefined;
		setHold(0);
	}, [mode]);

	// one clock drives everything on screen, plus the hold and the result's flare
	React.useEffect(() => {
		const connection = RunService.RenderStepped.Connect(() => {
			const now = os.clock();
			setTick(now);
			if (mode === "result") {
				setFlare(math.clamp((now - resultAt.current) / 1.1, 0, 1));
			} else {
				setFlare(0);
			}
			const startedAt = holding.current;
			if (startedAt !== undefined && !fired.current) {
				const p = math.clamp((now - startedAt) / HOLD_SECONDS, 0, 1);
				setHold(p);
				if (p >= 1) {
					fired.current = true;
					holding.current = undefined;
					Audio.play("domainCrack");
					props.onConfirm();
				}
			} else if (startedAt === undefined && !fired.current) {
				setHold(0);
			}
		});
		return () => {
			connection.Disconnect();
		};
	}, [mode, props.onConfirm]);

	// a controller lands on the chamber's own buttons whenever the mode changes
	const actionsRef = React.useRef<Frame>();
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const job = task.defer(() => {
			const host = actionsRef.current;
			if (host !== undefined && host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [mode]);

	// Escape backs out: the rite returns to the lattice, the lattice closes
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode !== Enum.KeyCode.Escape && input.KeyCode !== Enum.KeyCode.ButtonB) {
				return;
			}
			if (mode === "confirm" && rank >= 1) {
				props.onMode("lattice");
			} else if (mode !== "result") {
				props.onClose();
			}
		});
		return () => {
			connection.Disconnect();
		};
	}, [mode, rank]);

	const burstAt = (index: number, color: Color3, scale: number) => {
		if (reduced) {
			return;
		}
		const instance = anchorRefs.current[index] as GuiObject | undefined;
		if (instance !== undefined && instance.Parent !== undefined) {
			pcall(() => {
				const Juice = require(script.Parent!.Parent!.FindFirstChild("JuiceFx") as ModuleScript) as {
					burst(this: void, at: Vector2, color: Color3, scale: number): void;
				};
				Juice.burst(instance.AbsolutePosition.add(instance.AbsoluteSize.div(2)), color, scale);
			});
		}
	};

	const etch = (key: string) => {
		if (requesting.current) {
			return;
		}
		const [a, b] = splitKey(key);
		const [ok, reason] = DomainLattice.canEtch(links, a, b, points);
		if (!ok) {
			setNote(reason);
			Audio.play("locked");
			return;
		}
		requesting.current = true;
		const before = DomainLattice.facets(links);
		props.dispatch("DomainLattice", { Op: "Etch", A: a, B: b }, (response) => {
			requesting.current = false;
			if (!truthyOk(response.ok) || !typeIs(response.Links, "table")) {
				setNote(response.message ?? "That link didn't take.");
				Audio.play("locked");
				return;
			}
			const now = os.clock();
			etchedAt.current[key] = now;
			const was = new Set<number>();
			for (const index of before) {
				was.add(index);
			}
			for (const index of DomainLattice.facets(response.Links)) {
				if (!was.has(index)) {
					facetAt.current[index] = now + 0.3;
				}
			}
			setOverride({ links: response.Links as Links, points: math.floor(asNumber(response.SkillPoints)) });
			setNote(undefined);
			setSelected({ kind: "anchor", id: b });
			Audio.play(truthyOk(response.ClosedFacet) ? "domainImpact" : "domainBind");
			task.delay(0.36, () => {
				burstAt(b, colorOf(b), truthyOk(response.ClosedFacet) ? 1.2 : 0.8);
			});
		});
	};
	const clear = () => {
		if (requesting.current || !canClear) {
			return;
		}
		requesting.current = true;
		props.dispatch("DomainLattice", { Op: "Clear" }, (response) => {
			requesting.current = false;
			if (truthyOk(response.ok) && typeIs(response.Links, "table")) {
				etchedAt.current = {};
				facetAt.current = {};
				setOverride({ links: response.Links as Links, points: math.floor(asNumber(response.SkillPoints)) });
				setSelected(undefined);
				Audio.play("domainReward");
			} else {
				setNote(response.message ?? "Couldn't clear the lattice.");
			}
		});
	};
	const onLink = (key: string) => {
		if (selected !== undefined && selected.kind === "link" && selected.id === key) {
			etch(key);
		} else {
			Audio.play("tick");
			setNote(undefined);
			setSelected({ kind: "link", id: key });
		}
	};
	const onAnchor = (index: number) => {
		Audio.play("tick");
		setNote(undefined);
		setSelected({ kind: "anchor", id: index });
	};

	// the side panel
	const rows: Record<string, unknown> = {};
	let order = 0;
	const add = (element: unknown) => {
		order += 1;
		rows["r" + order] = element;
		return order;
	};
	const heading = (text: string, color?: Color3) => {
		add(h(Heading, { text, color, order: order + 1 }));
	};
	const row = (label: string, value: string | undefined, extra?: RowProps) => {
		const r: RowProps = extra ?? {};
		r.label = label;
		r.value = value;
		r.order = order + 1;
		add(h(Row, r));
	};
	const gap = (px: number) => {
		add(h("frame", { Size: new UDim2(1, 0, 0, px), BackgroundTransparency: 1, LayoutOrder: order + 1 }));
	};

	let panelTitle: string;
	let panelNumber: string;
	const actions: Action[] = [];
	if (mode === "lattice") {
		panelTitle = "Domain";
		panelNumber = tostring(rank);
		row("Production from your domain", `x${string.format("%.2f", asNumber(domain.ProductionMultiplier))}`, {
			valueColor: Palette.mango,
		});
		row("Domain points", tostring(points), { valueColor: points > 0 ? Palette.mango : Palette.cream });
		row("Next link costs", nextCost === 1 ? "1 point" : `${nextCost} points`);
		gap(6);
		if (selected !== undefined && selected.kind === "link" && links[selected.id as string] !== true) {
			const selectedKey = selected.id as string;
			const [a, b] = splitKey(selectedKey);
			heading(`${DomainLattice.ANCHORS[a].name} to ${DomainLattice.ANCHORS[b].name}`);
			for (const preview of etchPreview(links, selectedKey)) {
				row(preview.text, undefined, { labelColor: preview.color });
			}
			const [ok, reason] = DomainLattice.canEtch(links, a, b, points);
			actions.push({
				text: ok ? (nextCost === 1 ? "Etch for 1 point" : `Etch for ${nextCost} points`) : reason ?? "Can't etch",
				primary: true,
				disabled: !ok,
				onClick: () => {
					etch(selectedKey);
				},
			});
		} else if (selected !== undefined && selected.kind === "anchor") {
			const anchor = DomainLattice.ANCHORS[selected.id as number];
			const d = DomainLattice.degrees(links)[anchor.index] ?? 0;
			const maxD = DomainLattice.maxDegree(anchor.index);
			heading(anchor.name, KIND_COLOR[anchor.kind]);
			row("Gives now", DomainLattice.describe(anchor.kind, DomainLattice.anchorBonus(anchor.index, d)), {
				valueColor: KIND_COLOR[anchor.kind],
			});
			row("Links", `${d} of ${maxD}`);
			row("With every link etched", DomainLattice.describe(anchor.kind, anchor.full));
			if (anchor.index === DomainLattice.HEARTH) {
				gap(4);
				row(
					"Every closed triangle in the lattice adds " +
						DomainLattice.describe("Production", DomainLattice.FACET_PRODUCTION) +
						".",
					undefined,
					{ height: 36, size: 12, labelColor: Palette.muted },
				);
			}
		} else {
			heading("Lattice bonuses");
			let anyBonus = false;
			for (const [, anchor] of pairs(DomainLattice.ANCHORS)) {
				const total = DomainLattice.bonus(links, anchor.kind);
				if (total > 0 && (anchor.kind !== "Production" || anchor.index === DomainLattice.HEARTH)) {
					anyBonus = true;
					row(DomainLattice.describe(anchor.kind, total), undefined, { labelColor: KIND_COLOR[anchor.kind] });
				}
			}
			const facets = DomainLattice.facets(links).size();
			if (facets > 0) {
				row(`${facets} closed ${facets === 1 ? "facet" : "facets"}`, undefined, { labelColor: Palette.muted, size: 12 });
			}
			if (!anyBonus) {
				row("Tap a glowing line next to the Hearth to start. Links grow outward from it.", undefined, {
					height: 40,
					labelColor: Palette.muted,
				});
			}
		}
		if (note !== undefined) {
			gap(4);
			row(note, undefined, { labelColor: Palette.coral, height: 30, size: 12 });
		}
		if (domain.CanExpand === true) {
			actions.push({
				text: `Expand to Domain ${rank + 1}`,
				primary: actions.size() === 0,
				onClick: () => {
					props.onMode("confirm");
				},
			});
		}
		actions.push({
			text: canClear
				? `Clear lattice (refunds ${DomainLattice.spent(etched)})`
				: etched > 0
					? "Cleared this rank"
					: "Clear lattice",
			quiet: true,
			disabled: !canClear,
			onClick: clear,
		});
	} else if (mode === "confirm") {
		panelTitle = "Expand to domain";
		panelNumber = tostring(rank + 1);
		const needR = asNumber(domain.RequiredRebirths);
		const needC = asNumber(domain.RequiredCores);
		const haveR = asNumber(props.rebirths);
		const haveC = asNumber(props.cores);
		heading("You need");
		row("Rebirths", `${compactNumber(haveR)} / ${compactNumber(needR)}`, {
			valueColor: haveR >= needR ? Palette.mint : Palette.coral,
		});
		row("Cores", `${compactNumber(haveC)} / ${compactNumber(needC)}`, {
			valueColor: haveC >= needC ? Palette.mint : Palette.coral,
		});
		gap(6);
		heading("You get");
		row("Domain essence", `+${compactNumber(asNumber(domain.EssenceReward))}`, { valueColor: Palette.pink });
		row("Stardust", `+${compactNumber(asNumber(domain.StardustReward))}`, {
			valueColor: Palette.cyan,
			size: 12,
		});
		row("Domain points", `+${GameConfig.Domain.SkillPointPerRank ?? 2}`, { valueColor: Palette.mango });
		row("Wheel spins", `+${GameConfig.Domain.Expansion?.FreeSpins ?? 3}`);
		row(surgeLabel(), undefined, { labelColor: Palette.mango });
		gap(6);
		row("Keeps: " + KEEPS + ".", undefined, { height: 34, size: 12, labelColor: Palette.mint });
		row("Resets: " + RESETS + ".", undefined, { height: 34, size: 12, labelColor: Palette.coral });
		actions.push({
			text: domain.CanExpand === true ? (props.busy ? "Expanding…" : "Hold to expand") : "Not ready yet",
			primary: true,
			hold: domain.CanExpand === true && !props.busy,
			disabled: domain.CanExpand !== true || props.busy === true,
		});
		if (rank >= 1) {
			actions.push({
				text: "Back to the lattice",
				quiet: true,
				onClick: () => {
					props.onMode("lattice");
				},
			});
		}
	} else {
		const result = props.result ?? {};
		panelTitle = "Domain";
		panelNumber = tostring(result.rank ?? rank);
		heading("Rewards");
		const lines: Array<[string, string, Color3]> = [
			["Domain essence", `+${compactNumber(asNumber(result.essence))}`, Palette.pink],
			["Stardust", `+${compactNumber(asNumber(result.stardust))}`, Palette.cyan],
			["Domain points", `+${GameConfig.Domain.SkillPointPerRank ?? 2}`, Palette.mango],
			["Wheel spins", `+${compactNumber(asNumber(result.freeSpins))}`, Palette.cream],
		];
		for (let index = 1; index <= lines.size(); index++) {
			const item = lines[index - 1];
			const delay = 0.7 + index * 0.18;
			row(item[0], item[1], {
				valueColor: item[2],
				fade: tick.map((now) => 1 - easeOut((now - resultAt.current - delay) / 0.3)),
			});
		}
		if (asNumber(result.overflow) > 0) {
			row(
				`${compactNumber(asNumber(result.overflow))} of that Stardust came from rebirths past the requirement.`,
				undefined,
				{ height: 34, size: 12, labelColor: Palette.muted },
			);
		}
		gap(6);
		row(
			`Next expansion: ${compactNumber(asNumber(result.nextRebirths))} rebirths and ${compactNumber(asNumber(result.nextCores))} Cores.`,
			undefined,
			{ height: 34, size: 12, labelColor: Palette.muted },
		);
		actions.push({
			text: "Etch your new points",
			primary: true,
			onClick: () => {
				props.onMode("lattice");
			},
		});
	}

	const buttons: Record<string, unknown> = {};
	for (let index = 1; index <= actions.size(); index++) {
		const action = actions[index - 1];
		const height = action.quiet ? 30 : TapTarget;
		if (action.hold) {
			buttons["a" + index] = h(
				"textbutton",
				{
					Size: new UDim2(1, 0, 0, TapTarget),
					LayoutOrder: index,
					BackgroundColor3: darken(Palette.mango, 0.55),
					AutoButtonColor: false,
					Text: "",
					ZIndex: 634,
					Event: {
						InputBegan: (_: unknown, input: InputObject) => {
							if (
								input.UserInputType === Enum.UserInputType.MouseButton1 ||
								input.UserInputType === Enum.UserInputType.Touch
							) {
								holding.current = os.clock();
								Audio.play("domainCharge");
							}
						},
						InputEnded: (_: unknown, input: InputObject) => {
							if (
								input.UserInputType === Enum.UserInputType.MouseButton1 ||
								input.UserInputType === Enum.UserInputType.Touch
							) {
								holding.current = undefined;
							}
						},
						Activated: (_: unknown, input: InputObject | undefined) => {
							// a controller press can't be held, so it confirms straight away
							if (
								input !== undefined &&
								input.UserInputType !== undefined &&
								string.find(input.UserInputType.Name, "Gamepad", 1, true)[0] !== undefined &&
								!fired.current
							) {
								fired.current = true;
								props.onConfirm();
							}
						},
					},
				},
				h("uicorner", { CornerRadius: new UDim(0, Radius.md) }),
				h(
					"frame",
					{
						Size: hold.map((p) => UDim2.fromScale(p, 1)),
						BackgroundColor3: Palette.white,
						BorderSizePixel: 0,
						ZIndex: 635,
					},
					h("uicorner", { CornerRadius: new UDim(0, Radius.md) }),
					h("uigradient", { Color: new ColorSequence(Palette.mango, WHITE_HOT) }),
				),
				h("textlabel", {
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					Text: action.text,
					TextSize: 15,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
					TextColor3: Palette.cream,
					ZIndex: 636,
				}),
			);
		} else if (action.quiet) {
			buttons["a" + index] = h("textbutton", {
				Size: new UDim2(1, 0, 0, height),
				LayoutOrder: index,
				BackgroundTransparency: 1,
				Text: action.text,
				TextSize: 12,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				TextColor3: action.disabled ? Palette.lineSoft : Palette.muted,
				AutoButtonColor: false,
				ZIndex: 634,
				Event: {
					Activated: () => {
						if (!action.disabled && action.onClick) {
							action.onClick();
						}
					},
				},
			});
		} else {
			buttons["a" + index] = h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, height),
					LayoutOrder: index,
					BackgroundTransparency: 1,
					ZIndex: 634,
				},
				h(Button, {
					text: action.text,
					onClick: action.onClick,
					color: action.primary ? Palette.mango : Palette.panelSoft,
					textColor: action.primary ? Palette.ink : Palette.cream,
					size: UDim2.fromScale(1, 1),
					disabled: action.disabled,
					reducedMotion: reduced,
					highlight: action.primary,
					zIndex: 35,
				}),
			);
		}
	}

	const panelW = stacked ? viewport.width - 24 : 380;
	const panelPad = stacked ? Space.lg : Space.xl;
	const HEADER_H = stacked ? 78 : 86;
	const numberSlam =
		mode === "result"
			? tick.map((now) => {
					const t = (now - resultAt.current - 0.35) / 0.32;
					return t < 0 ? 0 : 1 + (1 - easeOut(t)) * 1.4;
				})
			: undefined;
	const panel = h(
		"frame",
		{
			Size: stacked ? new UDim2(1, -24, 0.48, -12) : new UDim2(0, panelW, 1, -48),
			Position: stacked ? new UDim2(0, 12, 0.52, 0) : new UDim2(1, -24, 0, 24),
			AnchorPoint: stacked ? Vector2.zero : new Vector2(1, 0),
			BackgroundColor3: Palette.panel,
			BackgroundTransparency: 0.08,
			BorderSizePixel: 0,
			ZIndex: 630,
		},
		h("uicorner", { CornerRadius: new UDim(0, stacked ? Radius.lg : Radius.sheet) }),
		h("uistroke", { Color: Palette.lineSoft, Transparency: 0.25 }),
		h("uipadding", {
			PaddingTop: new UDim(0, panelPad),
			PaddingBottom: new UDim(0, panelPad),
			PaddingLeft: new UDim(0, panelPad),
			PaddingRight: new UDim(0, panelPad),
		}),
		mode !== "result" &&
			h(Button, {
				text: "",
				icon: "Close.14",
				onClick: () => {
					if (!props.busy) {
						props.onClose();
					}
				},
				color: Palette.ink,
				textColor: Palette.coral,
				size: UDim2.fromOffset(TapTarget, TapTarget),
				position: new UDim2(1, -TapTarget, 0, -4),
				zIndex: 634,
			}),
		h("textlabel", {
			Size: new UDim2(1, -(TapTarget + Space.md), 0, 16),
			BackgroundTransparency: 1,
			Text: panelTitle,
			TextSize: 13,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			TextColor3: Palette.mango,
			TextXAlignment: Enum.TextXAlignment.Left,
			ZIndex: 633,
		}),
		h(
			"textlabel",
			{
				Size: new UDim2(1, 0, 0, 52),
				Position: UDim2.fromOffset(0, 18),
				BackgroundTransparency: 1,
				Text: panelNumber,
				TextSize: 50,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextColor3: mode === "result" ? WHITE_HOT : Palette.cream,
				TextXAlignment: Enum.TextXAlignment.Left,
				TextTransparency: numberSlam ? numberSlam.map((s) => (s <= 0 ? 1 : 0)) : 0,
				ZIndex: 633,
			},
			numberSlam && h("uiscale", { Scale: numberSlam.map((s) => math.max(0.01, s)) }),
		),
		h(
			"scrollingframe",
			{
				Size: new UDim2(1, 0, 1, -(HEADER_H + Space.md + actions.size() * (TapTarget + Space.sm))),
				Position: UDim2.fromOffset(0, HEADER_H),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				CanvasSize: new UDim2(),
				AutomaticCanvasSize: Enum.AutomaticSize.Y,
				ScrollBarThickness: 3,
				ScrollBarImageColor3: Palette.muted,
				ZIndex: 632,
			},
			h("uipadding", { PaddingRight: new UDim(0, 12) }),
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				SortOrder: Enum.SortOrder.LayoutOrder,
				Padding: new UDim(0, Space.sm),
			}),
			rows,
		),
		h(
			"frame",
			{
				ref: actionsRef,
				Size: new UDim2(1, 0, 0, actions.size() * (TapTarget + Space.sm)),
				Position: UDim2.fromScale(0, 1),
				AnchorPoint: new Vector2(0, 1),
				BackgroundTransparency: 1,
				ZIndex: 633,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				VerticalAlignment: Enum.VerticalAlignment.Bottom,
				SortOrder: Enum.SortOrder.LayoutOrder,
				Padding: new UDim(0, Space.sm),
			}),
			buttons,
		),
	);

	const heat = React.joinBindings([hold, flare]);
	return h(
		"frame",
		{
			Name: "DomainChamber",
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: 0.04,
			BorderSizePixel: 0,
			Active: true,
			ZIndex: 620,
		},
		h(
			"frame",
			{
				// the forge floor glows with the hold and the landing
				Size: UDim2.fromScale(1, 0.7),
				Position: UDim2.fromScale(0, 1),
				AnchorPoint: new Vector2(0, 1),
				BackgroundColor3: Palette.ember,
				BackgroundTransparency: heat.map((v) => {
					const values = v as unknown as number[];
					const landing = values[1] > 0 ? 1 - values[1] : 0;
					return math.clamp(0.86 - values[0] * 0.4 - landing * 0.5, 0, 1);
				}),
				BorderSizePixel: 0,
				ZIndex: 621,
			},
			h("uigradient", {
				Rotation: -90,
				Transparency: new NumberSequence([
					new NumberSequenceKeypoint(0, 0),
					new NumberSequenceKeypoint(0.5, 0.75),
					new NumberSequenceKeypoint(1, 1),
				]),
			}),
		),
		h(
			"frame",
			{
				Size: stacked ? new UDim2(1, -24, 0.5, -12) : new UDim2(1, -(panelW + 72), 1, -48),
				Position: UDim2.fromOffset(stacked ? 12 : 24, stacked ? 12 : 24),
				BackgroundTransparency: 1,
				ZIndex: 622,
			},
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					ZIndex: 622,
				},
				h(Lattice, {
					links,
					tick,
					flare,
					selected: mode === "lattice" ? selected : undefined,
					etchedAt: etchedAt.current,
					facetAt: facetAt.current,
					anchorRefs: anchorRefs.current,
					reduced,
					onLink: mode === "lattice" ? onLink : () => {},
					onAnchor: mode === "lattice" ? onAnchor : () => {},
				}),
			),
		),
		panel,
	);
}

// Luau truthiness for reply fields (only nil and false are falsy)
function truthyOk(value: unknown): boolean {
	return value !== undefined && value !== false;
}

export { DomainChamber };
