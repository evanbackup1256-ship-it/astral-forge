import { easeOut } from "../CoreKit/easing";
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
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

const HOLD_SECONDS = 1.1;
const LINK_DRAW_SECONDS = 0.42;
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

function etchPreview(links: Links, key: string, rank: number) {
	const [a, b] = splitKey(key);
	const degree = DomainLattice.degrees(links);
	const attune = 1 + math.max(0, rank - 1) * DomainLattice.ATTUNE_STEP;
	const lines: Array<{ color: Color3; text: string }> = [];
	for (const index of [a, b]) {
		const anchor = DomainLattice.ANCHORS[index];
		const d = degree[index] ?? 0;
		const gain = (DomainLattice.anchorBonus(index, d + 1) - DomainLattice.anchorBonus(index, d)) * attune;
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
	selected?: Selection;
	etchedAt: Record<string, number | undefined>;
	anchorRefs: Record<number, Instance | undefined>;
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
	const kindledSet = new Set<number>();
	for (const index of DomainLattice.kindled(links)) {
		kindledSet.add(index);
	}
	const children: Record<string, unknown> = {};
	children.plate = h(
		"frame",
		{
			Size: UDim2.fromScale(0.97, 0.97),
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundColor3: Palette.ink,
			BackgroundTransparency: 0.55,
			BorderSizePixel: 0,
			ZIndex: 601,
		},
		h("uicorner", { CornerRadius: new UDim(0, 16) }),
		h("uistroke", { Color: Palette.line, Thickness: 1, Transparency: 0.4 }),
		h(
			"frame",
			{
				Size: UDim2.fromScale(0.92, 0.92),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 601,
			},
			h("uicorner", { CornerRadius: new UDim(0, 12) }),
			h("uistroke", { Color: Palette.lineSoft, Thickness: 1, Transparency: 0.7 }),
		),
	);
	for (const [cx, cy] of [
		[0.035, 0.035],
		[0.965, 0.035],
		[0.035, 0.965],
		[0.965, 0.965],
	] as Array<[number, number]>) {
		children["rivet" + cx + cy] = h(
			"frame",
			{
				Size: UDim2.fromOffset(5, 5),
				Position: UDim2.fromScale(cx, cy),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: 45,
				BackgroundColor3: Palette.line,
				BackgroundTransparency: 0.35,
				BorderSizePixel: 0,
				ZIndex: 602,
			},
		);
	}
	for (const e of DomainLattice.EDGES) {
		const [x1, y1] = spot(e.a);
		const [x2, y2] = spot(e.b);
		const etched = links[e.key] === true;
		const open = !etched && (reached.has(e.a) || reached.has(e.b));
		const picked = selected !== undefined && selected.kind === "link" && selected.id === e.key;
		if (etched) {
			const key = e.key;
			const drawn = (now: number) => {
				const at = props.etchedAt[key];
				return at === undefined ? 1 : easeOut((now - at) / LINK_DRAW_SECONDS);
			};
			const [, , rot] = line(x1, y1, x2, y2, 3, 1);
			children["etched" + key] = h("frame", {
				Size: tick.map((now) => line(x1, y1, x2, y2, 3, drawn(now))[0]),
				Position: tick.map((now) => line(x1, y1, x2, y2, 3, drawn(now))[1]),
				Rotation: rot,
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.mango,
				BackgroundTransparency: 0.12,
				BorderSizePixel: 0,
				ZIndex: 604,
			});
		} else {
			const [size, pos, rot] = line(x1, y1, x2, y2, open ? (picked ? 3 : 2) : 1, 1);
			children["line" + e.key] = h("frame", {
				Size: size,
				Position: pos,
				Rotation: rot,
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: picked ? Palette.cream : open ? Palette.mango : Palette.lineSoft,
				BackgroundTransparency: picked ? 0 : open ? 0.3 : 0.55,
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
					Size: UDim2.fromOffset(9, 9),
					Position: UDim2.fromScale(cx, cy),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: 45,
					BackgroundColor3: Palette.mango,
					BorderSizePixel: 0,
					ZIndex: 605,
				},
				h("frame", {
					Size: UDim2.fromOffset(4, 4),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: Palette.ink,
					BackgroundTransparency: 0.15,
					BorderSizePixel: 0,
					ZIndex: 605,
				}),
			);
		}
	}
	for (const [, anchor] of pairs(DomainLattice.ANCHORS)) {
		const index = anchor.index;
		const [x, y] = spot(index);
		const color = KIND_COLOR[anchor.kind] ?? Palette.mango;
		const d = degree[index] ?? 0;
		const maxD = DomainLattice.maxDegree(index);
		const fill = d / math.max(1, maxD);
		const isHearth = index === DomainLattice.HEARTH;
		const isKindled = kindledSet.has(index);
		const stone = isHearth ? 36 : 26;
		const picked = selected !== undefined && selected.kind === "anchor" && selected.id === index;
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
					Size: UDim2.fromOffset(stone + 8, stone + 8),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: darken(color, 0.7 - fill * 0.35),
					BorderSizePixel: 0,
					ZIndex: 608,
				},
				h("uicorner", { CornerRadius: new UDim(0, isHearth ? 12 : 9) }),
				h("uistroke", {
					Color: picked || fill >= 1 ? Palette.cream : color,
					Thickness: picked ? 2.5 : 1.5,
					Transparency: d > 0 || isHearth ? 0 : 0.45,
				}),
				h(Icon, {
					kind: KIND_ICON[anchor.kind] ?? "Domain.6",
					color: d > 0 || isHearth ? Palette.cream : Palette.muted,
					accent: color,
					size: stone - 6,
					spin: false,
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
				}),
			),
			isKindled &&
				h("frame", {
					Size: UDim2.fromOffset(7, 7),
					Position: new UDim2(0.5, 0, 0, -4),
					AnchorPoint: new Vector2(0.5, 1),
					Rotation: 45,
					BackgroundColor3: Palette.mango,
					BorderSizePixel: 0,
					ZIndex: 609,
				}),
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
	const [hold, setHold] = React.useBinding(0);
	const [selected, setSelected] = React.useState<Selection | undefined>(undefined);
	const [override, setOverride] = React.useState<{ links: Links; points: number } | undefined>(undefined);
	const [note, setNote] = React.useState<string | undefined>(undefined);
	const etchedAt = React.useRef<Record<string, number | undefined>>({});
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

	React.useEffect(() => {
		const connection = RunService.RenderStepped.Connect(() => {
			const now = os.clock();
			let animateLinks = false;
			for (const [, at] of pairs(etchedAt.current)) {
				if (at !== undefined && now - at < LINK_DRAW_SECONDS) {
					animateLinks = true;
					break;
				}
			}
			if (animateLinks || (mode === "result" && now - resultAt.current < 2)) {
				setTick(now);
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

	const back = () => {
		if (mode === "confirm" && rank >= 1) {
			props.onMode("lattice");
		} else if (mode !== "result") {
			props.onClose();
		}
	};
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode !== Enum.KeyCode.Escape) {
				return;
			}
			back();
		});
		return () => {
			connection.Disconnect();
		};
	}, [mode, rank]);
	useBackLayer(true, back);

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
		props.dispatch("DomainLattice", { Op: "Etch", A: a, B: b }, (response) => {
			requesting.current = false;
			if (!truthyOk(response.ok) || !typeIs(response.Links, "table")) {
				setNote(response.message ?? "That link didn't take.");
				Audio.play("locked");
				return;
			}
			const now = os.clock();
			etchedAt.current[key] = now;
			setTick(now);
			setOverride({ links: response.Links as Links, points: math.floor(asNumber(response.SkillPoints)) });
			setNote(undefined);
			setSelected({ kind: "anchor", id: b });
			Audio.play(truthyOk(response.ClosedFacet) ? "domainImpact" : "domainBind");
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
		const [innerLit, outerLit, turned] = DomainLattice.ringProgress(links);
		heading("The sigil wheel");
		row("Links etched", `${etched} of ${DomainLattice.EDGES.size()}`);
		row("Inner harmonic", innerLit >= 6 ? "+10% production" : `${innerLit} of 6 anchors kindled`, {
			valueColor: innerLit >= 6 ? Palette.mango : undefined,
		});
		row("Outer harmonic", outerLit >= 6 ? "+8% production" : `${outerLit} of 6 anchors kindled`, {
			valueColor: outerLit >= 6 ? Palette.mango : undefined,
		});
		if (turned) {
			row("The wheel turns", "+25% production", { valueColor: Palette.mango });
		}
		if (rank > 1) {
			row("Attunement", `rank ${rank}: +${(rank - 1) * 5}% on every anchor`);
		}
		gap(6);
		if (selected !== undefined && selected.kind === "link" && links[selected.id as string] !== true) {
			const selectedKey = selected.id as string;
			const [a, b] = splitKey(selectedKey);
			heading(`${DomainLattice.ANCHORS[a].name} to ${DomainLattice.ANCHORS[b].name}`);
			for (const preview of etchPreview(links, selectedKey, rank)) {
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
			const attune = 1 + math.max(0, rank - 1) * DomainLattice.ATTUNE_STEP;
			row("Gives now", DomainLattice.describe(anchor.kind, DomainLattice.anchorBonus(anchor.index, d) * attune), {
				valueColor: KIND_COLOR[anchor.kind],
			});
			row("Links", `${d} of ${maxD}`);
			if (d >= maxD && maxD > 0) {
				row("Kindled", "the full ring pays half again", { labelColor: Palette.mango });
			} else {
				row("Kindled ring", DomainLattice.describe(anchor.kind, anchor.full * (1 + DomainLattice.KINDLE_BONUS) * attune), {
					labelColor: Palette.muted,
				});
			}
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
				const total = DomainLattice.bonus(links, anchor.kind, math.max(1, rank));
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
						BackgroundColor3: Palette.mango,
						BorderSizePixel: 0,
						ZIndex: 635,
					},
					h("uicorner", { CornerRadius: new UDim(0, Radius.md) }),
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
					return t < 0 ? 1 : 1 + (1 - easeOut(t)) * 0.05;
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
				TextColor3: Palette.cream,
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
					selected: mode === "lattice" ? selected : undefined,
					etchedAt: etchedAt.current,
					anchorRefs: anchorRefs.current,
					onLink: mode === "lattice" ? onLink : () => {},
					onAnchor: mode === "lattice" ? onAnchor : () => {},
				}),
			),
		),
		panel,
	);
}

function truthyOk(value: unknown): boolean {
	return value !== undefined && value !== false;
}

export { DomainChamber };
