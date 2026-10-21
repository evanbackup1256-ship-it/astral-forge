// What a plot is allowed to show. The server writes a short roster onto the plot;
// each client decides which plots to build and how many parts, lights and sparks
// that build gets. This module does not create instances.

export interface MachineMark {
	id: string;
	level: number;
	r: number;
	g: number;
	b: number;
}

export interface SceneryMark {
	shape: "block" | "wedge" | "ring" | "ball";
	x: number;
	y: number;
	z: number;
	sx: number;
	sy: number;
	sz: number;
	yaw: number;
	pitch: number;
}

export interface PlotSpot {
	key: string;
	x: number;
	y: number;
	z: number;
	localPlot: boolean;
}

export interface StageKnobs {
	fx: number;
	density: number;
	glow: number;
	effects: number;
	reducedMotion: boolean;
	hideOtherPlots: boolean;
	constrained: boolean;
}

export interface StageBudget {
	plots: number;
	machines: number;
	detail: 2 | 3;
	scenery: number;
	trim: boolean;
	lights: number;
	particles: number;
	tweens: number;
	spins: number;
	particleRate: number;
	radius: number;
	motionHz: number;
}

export type SceneryKind = "dock" | "crystal" | "foundry" | "rift" | "well";

export const ROSTER_CAP = 12;
export const MACHINE_COLUMNS = 4;
export const MACHINE_SPACING = 12;

export const ATTR = table.freeze({
	zone: "ForgeZone",
	rebirths: "ForgeRebirths",
	domain: "ForgeDomain",
	machines: "ForgeMachines",
	owner: "ForgeOwner",
});

const LEVEL_CAP = 1e15;
const ID_LIMIT = 48;

function unit(value: number): number {
	if (!typeIs(value, "number") || value !== value) {
		return 0;
	}
	return math.clamp(value, 0, 1);
}

function parseLevel(text: string): number | undefined {
	const [plain] = string.match(text, "^(%d+)$");
	if (plain !== undefined) {
		return tonumber(plain);
	}
	const [fraction] = string.match(text, "^(%d+%.%d+)$");
	if (fraction !== undefined) {
		return tonumber(fraction);
	}
	const [mantissa] = string.match(text, "^(%d+%.?%d*)[eE][%+%-]?%d+$");
	if (mantissa !== undefined) {
		return tonumber(text);
	}
	return undefined;
}

function wholeByte(text: string): number | undefined {
	const [ok] = string.match(text, "^(%d+)$");
	if (ok === undefined) {
		return undefined;
	}
	return tonumber(text);
}

function channel(value: number): number {
	if (!typeIs(value, "number") || value !== value) {
		return 200;
	}
	return math.clamp(math.floor(value + 0.5), 0, 255);
}

function cleanMark(mark: MachineMark): MachineMark | undefined {
	if (!typeIs(mark.id, "string") || mark.id.size() < 1 || mark.id.size() > ID_LIMIT) {
		return undefined;
	}
	const [matched] = string.match(mark.id, "^([%w_]+)$");
	if (matched !== mark.id) {
		return undefined;
	}
	if (!typeIs(mark.level, "number") || mark.level !== mark.level || mark.level < 1 || mark.level === math.huge) {
		return undefined;
	}
	return {
		id: mark.id,
		level: math.floor(math.min(mark.level, LEVEL_CAP)),
		r: channel(mark.r),
		g: channel(mark.g),
		b: channel(mark.b),
	};
}

// Highest levels first, then id, so a refresh writes the same string every time.
export function pickRoster(entries: MachineMark[]): MachineMark[] {
	const best = new Map<string, MachineMark>();
	for (const entry of entries) {
		const clean = cleanMark(entry);
		if (clean === undefined) {
			continue;
		}
		const prev = best.get(clean.id);
		if (prev === undefined || clean.level > prev.level) {
			best.set(clean.id, clean);
		}
	}
	const list: MachineMark[] = [];
	for (const [, mark] of best) {
		list.push(mark);
	}
	table.sort(list, (a, b) => (a.level !== b.level ? a.level > b.level : a.id < b.id));
	const capped: MachineMark[] = [];
	const count = math.min(list.size(), ROSTER_CAP);
	for (let index = 0; index < count; index++) {
		capped.push(list[index]);
	}
	return capped;
}

export function encodeRoster(entries: MachineMark[]): string {
	const parts: string[] = [];
	for (const mark of pickRoster(entries)) {
		parts.push(`${mark.id}=${mark.level}=${mark.r},${mark.g},${mark.b}`);
	}
	return parts.join(";");
}

export function decodeRoster(text: unknown): MachineMark[] {
	if (!typeIs(text, "string") || text === "") {
		return [];
	}
	const body = text.size() > 4096 ? string.sub(text, 1, 4096) : text;
	const seen = new Set<string>();
	const marks: MachineMark[] = [];
	for (const token of body.split(";")) {
		if (marks.size() >= ROSTER_CAP || token === "") {
			continue;
		}
		const bits = token.split("=");
		if (bits.size() !== 3) {
			continue;
		}
		const level = parseLevel(bits[1]);
		if (level === undefined) {
			continue;
		}
		const colorBits = bits[2].split(",");
		if (colorBits.size() !== 3) {
			continue;
		}
		const r = wholeByte(colorBits[0]);
		const g = wholeByte(colorBits[1]);
		const b = wholeByte(colorBits[2]);
		if (r === undefined || g === undefined || b === undefined) {
			continue;
		}
		const clean = cleanMark({ id: bits[0], level, r, g, b });
		if (clean === undefined || seen.has(clean.id)) {
			continue;
		}
		seen.add(clean.id);
		marks.push(clean);
	}
	return marks;
}

export function raisedLevels(previous: MachineMark[], current: MachineMark[]): string[] {
	const prior = new Map<string, number>();
	for (const mark of previous) {
		prior.set(mark.id, mark.level);
	}
	const raised: string[] = [];
	for (const mark of current) {
		const before = prior.get(mark.id);
		if (before === undefined || mark.level > before) {
			raised.push(mark.id);
		}
	}
	return raised;
}

export function sceneryKind(zoneId: number): SceneryKind {
	const zone = typeIs(zoneId, "number") && zoneId === zoneId ? math.floor(zoneId) : 1;
	if (zone <= 1) {
		return "dock";
	}
	if (zone === 2) {
		return "crystal";
	}
	if (zone === 3) {
		return "foundry";
	}
	if (zone === 4) {
		return "rift";
	}
	return "well";
}

function mark(
	shape: SceneryMark["shape"],
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	yaw = 0,
	pitch = 0,
): SceneryMark {
	return { shape, x, y, z, sx, sy, sz, yaw, pitch };
}

function marksFor(kind: SceneryKind): SceneryMark[] {
	if (kind === "dock") {
		return [
			mark("block", -30, 3.6, -22, 1.4, 3.2, 1.4),
			mark("block", 30, 3.6, -22, 1.4, 3.2, 1.4),
			mark("block", -30, 3.6, 22, 1.4, 3.2, 1.4),
			mark("block", 30, 3.6, 22, 1.4, 3.2, 1.4),
		];
	}
	if (kind === "crystal") {
		const shards: SceneryMark[] = [];
		for (let index = 0; index < 4; index++) {
			const angle = index * math.pi * 0.5 + 0.45;
			shards.push(
				mark(
					"wedge",
					math.cos(angle) * 27,
					5.2,
					math.sin(angle) * 27,
					1.5,
					5 + index * 0.8,
					1.5,
					angle,
					0.35,
				),
			);
		}
		return shards;
	}
	if (kind === "foundry") {
		return [
			mark("ring", 0, 2.4, 23, 0.28, 10, 10),
			mark("block", -12, 3.2, 23, 1.1, 2.2, 1.1),
			mark("block", 12, 3.2, 23, 1.1, 2.2, 1.1),
		];
	}
	if (kind === "rift") {
		return [mark("ring", 0, 3.4, 23, 0.18, 12, 12), mark("ring", 0, 5.6, 23, 0.16, 7, 7, 0.6)];
	}
	return [
		mark("ball", -22, 6.5, 20, 2.2, 2.2, 2.2),
		mark("ball", 0, 8.2, 24, 1.6, 1.6, 1.6),
		mark("ball", 22, 6.2, 20, 2, 2, 2),
	];
}

export function sceneryMarks(zoneId: number, count: number): SceneryMark[] {
	const all = marksFor(sceneryKind(zoneId));
	const n = typeIs(count, "number") && count === count ? math.clamp(math.floor(count), 0, all.size()) : 0;
	const out: SceneryMark[] = [];
	for (let index = 0; index < n; index++) {
		out.push(all[index]);
	}
	return out;
}

// Local to the pad center. Y is the pad top; the client lifts parts by their own height.
export function machineOffset(index: number): { x: number; y: number; z: number } {
	const slot = math.max(0, math.floor(index));
	const col = slot % MACHINE_COLUMNS;
	const row = math.floor(slot / MACHINE_COLUMNS);
	return {
		x: (col - 1.5) * MACHINE_SPACING,
		y: 2,
		z: -8 + row * MACHINE_SPACING,
	};
}

export function machineScale(level: number): number {
	const safe = typeIs(level, "number") && level === level ? math.clamp(level, 0, LEVEL_CAP) : 0;
	return math.clamp(2.4 + math.log10(safe + 1) * 0.55, 2.4, 5.2);
}

export function pillarHeight(rank: number): number {
	if (!typeIs(rank, "number") || rank !== rank || rank <= 0 || rank === math.huge) {
		return 0;
	}
	return math.clamp(6 + math.floor(rank) * 1.25, 6, 28);
}

export function stageBudget(knobs: StageKnobs): StageBudget {
	const fx = unit(knobs.fx);
	const density = unit(knobs.density);
	const glow = unit(knobs.glow);
	const effects = unit(knobs.effects);
	const tight = knobs.constrained === true || fx < 0.25;
	const quiet = knobs.reducedMotion === true;
	const plots = knobs.hideOtherPlots === true ? 1 : tight ? 2 : 3;
	const machines = quiet ? (tight ? 4 : 6) : tight ? 6 : 12;
	const detail: 2 | 3 = !quiet && fx >= 0.35 && effects >= 0.4 ? 3 : 2;
	const scenery = quiet ? 0 : math.clamp(math.floor(effects * (tight ? 2 : 4) + 0.5), 0, 4);
	const trim = !quiet && !tight && effects >= 0.35;
	const lights =
		glow < 0.08 || effects < 0.15
			? 0
			: math.clamp(math.floor(glow * effects * (tight ? 3 : 8) + 0.5), 0, tight ? 2 : 6);
	const particles =
		quiet || density < 0.05 || effects < 0.2 ? 0 : math.clamp(math.floor(density * (tight ? 1 : 3) + 0.5), 1, tight ? 1 : 3);
	const tweens = quiet ? 0 : tight ? 2 : 6;
	const spins = quiet ? 0 : tight ? 3 : 8;
	const particleRate =
		particles === 0 ? 0 : math.clamp(math.floor(2 + density * effects * (tight ? 4 : 8) + 0.5), 2, tight ? 6 : 12);
	return {
		plots,
		machines,
		detail,
		scenery,
		trim,
		lights,
		particles,
		tweens,
		spins,
		particleRate,
		radius: tight ? 110 : 170,
		motionHz: tight ? 12 : 20,
	};
}

export function budgetKey(budget: StageBudget): string {
	return `${budget.plots}/${budget.machines}/${budget.detail}/${budget.scenery}/${budget.trim ? 1 : 0}/${budget.lights}/${budget.particles}/${budget.tweens}/${budget.spins}`;
}

// The local plot is always kept. Other plots have to sit inside the radius, nearest first.
export function streamPlots(
	spots: PlotSpot[],
	originX: number,
	originY: number,
	originZ: number,
	radius: number,
	limit: number,
	localOnly: boolean,
): string[] {
	const cap = typeIs(limit, "number") && limit === limit ? math.max(0, math.floor(limit)) : 0;
	if (cap === 0) {
		return [];
	}
	const chosen: string[] = [];
	let localKey: string | undefined;
	for (const spot of spots) {
		if (spot.localPlot) {
			localKey = spot.key;
			break;
		}
	}
	if (localKey !== undefined) {
		chosen.push(localKey);
	}
	if (localOnly || chosen.size() >= cap) {
		return chosen;
	}
	const reach = typeIs(radius, "number") && radius === radius ? radius : 0;
	const radius2 = reach * reach;
	const rest: Array<{ key: string; d: number }> = [];
	for (const spot of spots) {
		if (spot.key === localKey) {
			continue;
		}
		const dx = spot.x - originX;
		const dy = spot.y - originY;
		const dz = spot.z - originZ;
		const distance = dx * dx + dy * dy + dz * dz;
		if (distance === distance && distance <= radius2) {
			rest.push({ key: spot.key, d: distance });
		}
	}
	table.sort(rest, (a, b) => (a.d !== b.d ? a.d < b.d : a.key < b.key));
	for (const item of rest) {
		if (chosen.size() >= cap) {
			break;
		}
		chosen.push(item.key);
	}
	return chosen;
}
