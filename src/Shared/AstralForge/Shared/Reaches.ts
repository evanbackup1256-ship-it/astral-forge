// The Reaches: three ore regions, each with seven outcrops that regrow after mining, and the Rift Warden that the
// whole server fights together. This module is the rules only, shared by the server that enforces them, the page
// that shows them, and the tests.

export interface Region {
	Id: string;
	Name: string;
	Ore: string;
	Tagline: string;
	/** rebirths needed before the region's outcrops answer */
	MinRebirths: number;
	/** the ore's glow as an RGB triple */
	Glow: [number, number, number];
}

export const REGIONS: ReadonlyArray<Region> = [
	{
		Id: "Emberreach",
		Name: "Emberreach",
		Ore: "Emberite",
		Tagline: "Cooling lava fields. Emberite grows in the cracks.",
		MinRebirths: 0,
		Glow: [255, 128, 64],
	},
	{
		Id: "Hollows",
		Name: "The Hollows",
		Ore: "Voidglass",
		Tagline: "A sunken glass basin that hums at night.",
		MinRebirths: 1,
		Glow: [150, 104, 255],
	},
	{
		Id: "Spire",
		Name: "Starsteel Spire",
		Ore: "Starsteel",
		Tagline: "Frozen pillars where falling stars cooled into metal.",
		MinRebirths: 3,
		Glow: [140, 220, 255],
	},
];

export const NODES_PER_REGION = 7;

export const WARDEN = {
	/** strikes the Warden can take with nobody else around; each player in the server adds PerPlayerHp */
	BaseHp: 80,
	PerPlayerHp: 45,
	StrikeCooldown: 0.3,
	CritChance: 0.12,
	CritMultiplier: 3,
	RespawnSeconds: 120,
	/** the slam: it winds up for SlamWarning seconds every SlamEvery; a strike during the wind-up gets you stunned */
	SlamEvery: 18,
	SlamWarning: 1.6,
	StunSeconds: 2,
	/** a player needs this many strikes to share the spoils */
	MinStrikes: 3,
};

export function region(id: unknown): Region | undefined {
	for (const entry of REGIONS) {
		if (entry.Id === id) {
			return entry;
		}
	}
	return undefined;
}

export function regionOpen(entry: Region, rebirths: unknown): boolean {
	const count = tonumber(rebirths) ?? 0;
	return count >= entry.MinRebirths;
}

export function nodeId(entry: Region, index: number): string {
	return `${entry.Id}:${index}`;
}

/** "Emberreach:3" -> the region and the outcrop index, or undefined for anything malformed. */
export function parseNodeId(raw: unknown): LuaTuple<[Region | undefined, number]> {
	if (!typeIs(raw, "string") || raw.size() > 32) {
		return $tuple(undefined, 0);
	}
	const [regionId, indexText] = raw.match("^(%a+):(%d+)$");
	const entry = region(regionId);
	const index = tonumber(indexText);
	if (entry === undefined || index === undefined || index < 1 || index > NODES_PER_REGION) {
		return $tuple(undefined, 0);
	}
	return $tuple(entry, index);
}

export function wardenMaxHp(players: number): number {
	return WARDEN.BaseHp + WARDEN.PerPlayerHp * math.max(1, math.floor(players));
}

/** Damage of one strike: 1, raised by Starsteel Edge, tripled on a critical. */
export function strikeDamage(bossBonus: number, critRoll: number): LuaTuple<[number, boolean]> {
	const base = 1 + math.max(0, bossBonus);
	const crit = critRoll < WARDEN.CritChance;
	return $tuple(crit ? base * WARDEN.CritMultiplier : base, crit);
}

export interface Spoils {
	Starsteel: number;
	Stardust: number;
	Top: boolean;
}

/**
 * Who gets what when the Warden falls. Everyone with enough strikes gets a share that grows with the damage
 * they dealt; whoever dealt the most gets a little extra.
 */
export function spoils(damage: Map<number, number>, strikes: Map<number, number>): Map<number, Spoils> {
	let total = 0;
	let topId: number | undefined;
	let topDamage = -1;
	for (const [userId, dealt] of damage) {
		total += dealt;
		if (dealt > topDamage) {
			topDamage = dealt;
			topId = userId;
		}
	}
	const out = new Map<number, Spoils>();
	if (total <= 0) {
		return out;
	}
	for (const [userId, dealt] of damage) {
		if ((strikes.get(userId) ?? 0) < WARDEN.MinStrikes) {
			continue;
		}
		const share = dealt / total;
		const top = userId === topId;
		out.set(userId, {
			Starsteel: math.clamp(2 + math.floor(share * 10 + 0.5), 2, 12) + (top ? 3 : 0),
			Stardust: 25 + math.floor(share * 100 + 0.5),
			Top: top,
		});
	}
	return out;
}
