// The Domain Lattice: a fixed figure of thirteen anchors (the Hearth at the centre, an inner ring
// of six, an outer ring of six) and the thirty links between them. Domain points etch links. An
// anchor's bonus fills with the links that touch it; every closed triangle (a facet) adds
// production on top. Links have to grow out of the Hearth, and the whole lattice can be cleared
// for a full refund once per domain rank. Pure: the server rules and the client both use it.
import { T } from "./Locale";

interface Anchor {
	index: number;
	name: string;
	kind: string;
	ring: number;
	angle: number;
	full: number;
}

interface Edge {
	a: number;
	b: number;
	key: string;
}

const INNER = table.freeze(["Capacity", "Tap", "RebirthYield", "Critical", "EchoCharge", "ContinuumDiscount"]);
const OUTER = table.freeze(["Offline", "Luck", "WorldDiscount", "EssenceGain", "ForgePathXP", "CommandXP"]);
const NAMES: Record<string, string> = table.freeze({
	Production: "Hearth",
	Capacity: "Cistern",
	Tap: "Anvil",
	RebirthYield: "Kiln",
	Critical: "Flint",
	EchoCharge: "Bellows",
	ContinuumDiscount: "Crucible",
	Offline: "Ember Bed",
	Luck: "Lodestone",
	WorldDiscount: "Waystone",
	EssenceGain: "Wellspring",
	ForgePathXP: "Ledger",
	CommandXP: "Banner",
});

// the bonus an anchor gives with every one of its links etched
const FULL: Record<string, number> = table.freeze({
	Production: 0.3,
	Capacity: 0.36,
	Tap: 0.27,
	RebirthYield: 0.25,
	Critical: 0.2,
	EchoCharge: 0.2,
	ContinuumDiscount: 0.15,
	Offline: 0.12,
	Luck: 0.08,
	WorldDiscount: 0.2,
	EssenceGain: 2,
	ForgePathXP: 0.12,
	CommandXP: 0.15,
});

const FACET_PRODUCTION = 0.015;
const HEARTH = 1;

const anchors: Record<number, Anchor> = {};
anchors[1] = { index: 1, name: NAMES.Production, kind: "Production", ring: 0, angle: 0, full: FULL.Production };
for (let i = 0; i < INNER.size(); i++) {
	const kind = INNER[i];
	anchors[2 + i] = {
		index: 2 + i,
		name: NAMES[kind],
		kind,
		ring: 1,
		angle: i * 60 - 90,
		full: FULL[kind],
	};
}
for (let i = 0; i < OUTER.size(); i++) {
	const kind = OUTER[i];
	anchors[8 + i] = {
		index: 8 + i,
		name: NAMES[kind],
		kind,
		ring: 2,
		angle: i * 60 - 60,
		full: FULL[kind],
	};
}

function inner(i: number): number {
	return 1 + ((i - 1) % 6) + 1;
}
function outer(i: number): number {
	return 7 + ((i - 1) % 6) + 1;
}

function makeKey(a: number, b: number): string {
	if (a > b) {
		[a, b] = [b, a];
	}
	return `${a}-${b}`;
}

// every link the figure has, and every triangle three of them close
const edges: Edge[] = [];
const edgeSet: Record<string, boolean> = {};
function edge(a: number, b: number): void {
	const k = makeKey(a, b);
	if (!edgeSet[k]) {
		edgeSet[k] = true;
		edges.push({ a: math.min(a, b), b: math.max(a, b), key: k });
	}
}
for (let i = 1; i <= 6; i++) {
	edge(1, inner(i));
	edge(inner(i), inner(i + 1));
	edge(outer(i), inner(i));
	edge(outer(i), inner(i + 1));
	edge(outer(i), outer(i + 1));
}

const triangles: [number, number, number][] = [];
for (let i = 1; i <= 6; i++) {
	triangles.push([1, inner(i), inner(i + 1)]);
	triangles.push([inner(i), inner(i + 1), outer(i)]);
	triangles.push([outer(i), outer(i + 1), inner(i + 1)]);
}

function isEdge(a: number, b: number): boolean {
	return edgeSet[makeKey(a, b)] === true;
}

// where an anchor sits, in units of the inner ring's radius
function position(index: number): LuaTuple<[number, number]> {
	const anchor = anchors[index];
	if (anchor === undefined || anchor.ring === 0) {
		return $tuple(0, 0);
	}
	const radius = anchor.ring === 1 ? 1 : 1.92;
	const r = math.rad(anchor.angle);
	return $tuple(math.cos(r) * radius, math.sin(r) * radius);
}

const maxDegree: Record<number, number> = {};
for (const e of edges) {
	maxDegree[e.a] = (maxDegree[e.a] ?? 0) + 1;
	maxDegree[e.b] = (maxDegree[e.b] ?? 0) + 1;
}

function maxDegreeFor(index: number): number {
	return maxDegree[index] ?? 0;
}

// links come as a set { ["a-b"] = true }; anything that isn't a real edge is ignored
function count(links: unknown): number {
	let n = 0;
	if (typeIs(links, "table")) {
		for (const [k, v] of pairs(links as Record<string, unknown>)) {
			if (v === true && edgeSet[k as string]) {
				n += 1;
			}
		}
	}
	return n;
}

function degrees(links: unknown): Record<number, number> {
	const degree: Record<number, number> = {};
	if (typeIs(links, "table")) {
		const set = links as Record<string, unknown>;
		for (const e of edges) {
			if (set[e.key] === true) {
				degree[e.a] = (degree[e.a] ?? 0) + 1;
				degree[e.b] = (degree[e.b] ?? 0) + 1;
			}
		}
	}
	return degree;
}

// the next link costs more every six links
function linkCost(etched: number): number {
	return 1 + math.floor(math.max(0, etched) / 6);
}

// points spent on the first n links
function spent(n: number): number {
	let total = 0;
	for (let i = 0; i < n; i++) {
		total += linkCost(i);
	}
	return total;
}

function canEtch(links: unknown, a: unknown, b: unknown, points: number): LuaTuple<[boolean, string | undefined]> {
	if (!typeIs(a, "number") || !typeIs(b, "number") || a !== a || b !== b) {
		return $tuple(false, T("DomainLattice.PickTwoAnchors"));
	}
	const ai = math.floor(a);
	const bi = math.floor(b);
	if (!isEdge(ai, bi)) {
		return $tuple(false, T("DomainLattice.ThoseAnchorsArenTJoined"));
	}
	const set = typeIs(links, "table") ? (links as Record<string, unknown>) : {};
	if (set[makeKey(ai, bi)] === true) {
		return $tuple(false, T("DomainLattice.AlreadyEtched"));
	}
	const degree = degrees(set);
	const touches =
		ai === HEARTH ||
		bi === HEARTH ||
		(degree[ai] ?? 0) > 0 ||
		(degree[bi] ?? 0) > 0;
	if (!touches) {
		return $tuple(false, T("DomainLattice.LinksGrowOutFromThe"));
	}
	const cost = linkCost(count(set));
	if (points < cost) {
		return $tuple(false, cost === 1 ? T("DomainLattice.Need1DomainPoint") : T("DomainLattice.NeedSDomainPoints", cost));
	}
	return $tuple(true, undefined);
}

// the triangles whose three links are all etched
function facets(links: unknown): number[] {
	const closed: number[] = [];
	if (!typeIs(links, "table")) {
		return closed;
	}
	const set = links as Record<string, unknown>;
	for (let index = 0; index < triangles.size(); index++) {
		const t = triangles[index];
		if (
			set[makeKey(t[0], t[1])] === true &&
			set[makeKey(t[1], t[2])] === true &&
			set[makeKey(t[0], t[2])] === true
		) {
			closed.push(index + 1);
		}
	}
	return closed;
}

// what an anchor gives right now
function anchorBonus(index: number, degree?: number): number {
	const anchor = anchors[index];
	if (anchor === undefined) {
		return 0;
	}
	const d = math.clamp(degree ?? 0, 0, maxDegree[index] ?? 1);
	return anchor.full * d / math.max(1, maxDegree[index] ?? 1);
}

// the total bonus of one kind ("Production", "Capacity", ...) from a set of links
function bonus(links: unknown, kind: string): number {
	if (!typeIs(links, "table")) {
		return 0;
	}
	const degree = degrees(links);
	let total = 0;
	for (const [, anchor] of pairs(anchors)) {
		if (anchor.kind === kind) {
			total += anchorBonus(anchor.index, degree[anchor.index]);
		}
	}
	if (kind === "Production") {
		total += facets(links).size() * FACET_PRODUCTION;
	}
	return total;
}

// how a kind reads on screen ("+12% vault capacity")
const TEXT: Record<string, string> = table.freeze({
	Production: "%s production",
	Capacity: "%s vault capacity",
	Tap: "%s overcharge power",
	RebirthYield: "%s cores from rebirths",
	Critical: "%s critical strike chance",
	EchoCharge: "%s faster Forge Echoes",
	ContinuumDiscount: "%s Star Foundry resonance",
	Offline: "%s offline yield",
	Luck: "%s crate and market luck",
	WorldDiscount: "%s off world unlocks",
	EssenceGain: "%s essence per expansion",
	ForgePathXP: "%s forge path XP",
	CommandXP: "%s command XP",
});

function describe(kind: string, amount: number): string {
	let value: string;
	if (kind === "EssenceGain") {
		value = "+%.1f".format(amount).gsub("%.0$", "")[0];
	} else {
		const pct = amount * 100;
		value = pct >= 10 || pct === math.floor(pct) ? `+%d%%`.format(math.floor(pct + 0.5)) : `+%.1f%%`.format(pct);
	}
	return (TEXT[kind] ?? "%s").format(value);
}

// Keep only real links that still connect back to the Hearth. Returns the clean set and how many
// points the dropped ones are worth.
function sanitize(links: unknown): LuaTuple<[Record<string, boolean>, number]> {
	const before = count(links);
	const clean: Record<string, boolean> = {};
	if (typeIs(links, "table")) {
		const set = links as Record<string, unknown>;
		const reached: Record<number, boolean> = { [HEARTH]: true };
		let grew = true;
		while (grew) {
			grew = false;
			for (const e of edges) {
				if (set[e.key] === true && clean[e.key] === undefined && (reached[e.a] || reached[e.b])) {
					clean[e.key] = true;
					reached[e.a] = true;
					reached[e.b] = true;
					grew = true;
				}
			}
		}
	}
	const after = count(clean);
	return $tuple(clean, spent(before) - spent(after));
}

// the old twenty-node tree, refunded in full when a save first meets the lattice
const OLD_NODE_COST: Record<string, number> = table.freeze({
	FluxVein: 2,
	VaultLattice: 2,
	EmberCore: 2,
	NightHarvest: 2,
	StarWell: 3,
	PrismGate: 3,
	EchoChamber: 3,
	HorizonKey: 3,
	RealityAnchor: 4,
	DomainPulse: 4,
	ContinuumBind: 4,
	OverchargeChannel: 5,
	TideLock: 4,
	VaultHeartNode: 4,
	EmberWell: 4,
	ApexLattice: 6,
	ForgeMnemonic: 3,
	SignalCrown: 4,
	VaultSpire: 5,
	AstralCrown: 7,
});

function oldTreeRefund(nodes: unknown): number {
	let total = 0;
	if (typeIs(nodes, "table")) {
		for (const [id, owned] of pairs(nodes as Record<string, unknown>)) {
			if (owned === true || owned === 1) {
				total += OLD_NODE_COST[id as string] ?? 0;
			}
		}
	}
	return total;
}

const DomainLattice = {
	ANCHORS: anchors,
	EDGES: edges,
	TRIANGLES: triangles,
	FACET_PRODUCTION,
	HEARTH,
	key: makeKey,
	isEdge,
	position,
	maxDegree: maxDegreeFor,
	count,
	degrees,
	linkCost,
	spent,
	canEtch,
	facets,
	anchorBonus,
	bonus,
	describe,
	sanitize,
	oldTreeRefund,
};

export = table.freeze(DomainLattice);
