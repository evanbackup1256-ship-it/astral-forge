// Constellations: every rebirth you've ever done is a Star Point. Points light stars in six
// constellations, one per bonus kind, in order. A finished constellation pays a little extra.
//
// Nothing is granted on rebirth and no counter is saved: points are lifetime rebirths minus
// the cost of the stars already lit, so players who rebirthed before v8 get theirs back
// automatically, and a save can't drift out of step with its ledger.
// BALANCE: first pass. Star costs double so the last star of each takes real time.
import { T } from "./Locale";

type Dict = Record<string, unknown>;

export interface Star {
	readonly Id: string;
	readonly Name: string;
	readonly Cost: number;
}

export interface Constellation {
	readonly Id: string;
	readonly Name: string;
	readonly Kind: string;
	readonly PerStar: number;
	readonly Completion: number;
	readonly Blurb: string;
	readonly Stars: readonly Star[];
}

export interface Bag {
	Lit: Record<string, boolean>;
}

const COSTS = [1, 2, 4, 8, 16];

function stars(prefix: string, names: string[]): Star[] {
	return names.map((name, index) => ({ Id: `${prefix}${index + 1}`, Name: name, Cost: COSTS[index] }));
}

export const CONSTELLATIONS: readonly Constellation[] = [
	{
		Id: "Anvil",
		Name: "The Anvil",
		Kind: "Production",
		PerStar: 0.04,
		Completion: 0.08,
		Blurb: "Every machine runs a little hotter.",
		Stars: stars("Anvil", ["Horn", "Face", "Heel", "Waist", "Hardy"]),
	},
	{
		Id: "Cistern",
		Name: "The Cistern",
		Kind: "Capacity",
		PerStar: 0.05,
		Completion: 0.1,
		Blurb: "The vault holds more before it tops out.",
		Stars: stars("Cistern", ["Rim", "Spout", "Basin", "Seal", "Deep"]),
	},
	{
		Id: "Hammer",
		Name: "The Hammer",
		Kind: "Tap",
		PerStar: 0.05,
		Completion: 0.1,
		Blurb: "Taps land heavier.",
		Stars: stars("Hammer", ["Grip", "Haft", "Cheek", "Peen", "Strike"]),
	},
	{
		Id: "Lantern",
		Name: "The Lantern",
		Kind: "Offline",
		PerStar: 0.04,
		Completion: 0.08,
		Blurb: "The forge earns more while you're away.",
		Stars: stars("Lantern", ["Wick", "Glass", "Hood", "Ring", "Flame"]),
	},
	{
		Id: "Spark",
		Name: "The Spark",
		Kind: "Critical",
		PerStar: 0.005,
		Completion: 0.01,
		Blurb: "Critical taps come up a touch more often.",
		Stars: stars("Spark", ["Flint", "Flash", "Arc", "Flare", "Nova"]),
	},
	{
		Id: "Loom",
		Name: "The Loom",
		Kind: "Automation",
		PerStar: 0.004,
		Completion: 0.008,
		Blurb: "Auto-collect works a little faster.",
		Stars: stars("Loom", ["Warp", "Weft", "Shuttle", "Reed", "Beam"]),
	},
];

const starIndex: Record<string, { Constellation: Constellation; Index: number }> = {};
for (const constellation of CONSTELLATIONS) {
	constellation.Stars.forEach((star, index) => {
		starIndex[star.Id] = { Constellation: constellation, Index: index };
	});
}

export function find(starId: unknown): LuaTuple<[Constellation | undefined, number]> {
	const hit = typeIs(starId, "string") ? starIndex[starId] : undefined;
	return $tuple(hit?.Constellation, hit !== undefined ? hit.Index : -1);
}

function int(value: unknown): number {
	const n = tonumber(value);
	return n !== undefined && n === n && n > 0 && n < math.huge ? math.floor(n) : 0;
}

// lifetime rebirths: the rebirth ledger when there is one, otherwise what the save still shows
export function lifetimeOf(profile: unknown): number {
	if (!typeIs(profile, "table")) {
		return 0;
	}
	const bag = profile as Dict;
	if (typeIs(bag.Rebirth, "table")) {
		return int((bag.Rebirth as Dict).Lifetime);
	}
	const domain = typeIs(bag.Domain, "table") ? (bag.Domain as Dict) : {};
	const ascension = typeIs(bag.Ascension, "table") ? (bag.Ascension as Dict) : {};
	return int(bag.Rebirths) + int(domain.TotalRebirthsSpent) + int(ascension.RebirthsSpent);
}

// keeps only real stars whose earlier stars are lit too, so a hand-edited save can't skip ahead
export function ensure(raw: unknown): Bag {
	const input = typeIs(raw, "table") && typeIs((raw as Dict).Lit, "table") ? ((raw as Dict).Lit as Dict) : {};
	const lit: Record<string, boolean> = {};
	for (const constellation of CONSTELLATIONS) {
		for (const star of constellation.Stars) {
			if (input[star.Id] !== true) {
				break;
			}
			lit[star.Id] = true;
		}
	}
	if (typeIs(raw, "table")) {
		(raw as Dict).Lit = lit;
		return raw as Bag;
	}
	return { Lit: lit };
}

export function spent(bag: Bag): number {
	let total = 0;
	for (const constellation of CONSTELLATIONS) {
		for (const star of constellation.Stars) {
			if (bag.Lit[star.Id] === true) {
				total += star.Cost;
			}
		}
	}
	return total;
}

export function points(profile: unknown): number {
	const raw = typeIs(profile, "table") ? (profile as Dict).Constellations : undefined;
	return math.max(0, lifetimeOf(profile) - spent(ensure(typeIs(raw, "table") ? raw : undefined)));
}

export function litCount(bag: Bag, constellation: Constellation): number {
	let count = 0;
	for (const star of constellation.Stars) {
		if (bag.Lit[star.Id] === true) {
			count += 1;
		}
	}
	return count;
}

// read-only: never repairs the save, it only ignores what ensure() would drop
export function bonus(profile: unknown, kind: string): number {
	const raw = typeIs(profile, "table") ? (profile as Dict).Constellations : undefined;
	if (!typeIs(raw, "table") || !typeIs((raw as Dict).Lit, "table")) {
		return 0;
	}
	const lit = (raw as Dict).Lit as Dict;
	let total = 0;
	for (const constellation of CONSTELLATIONS) {
		if (constellation.Kind !== kind) {
			continue;
		}
		let count = 0;
		for (const star of constellation.Stars) {
			if (lit[star.Id] !== true) {
				break;
			}
			count += 1;
		}
		total += count * constellation.PerStar + (count === constellation.Stars.size() ? constellation.Completion : 0);
	}
	return total;
}

// lights a star in place; the caller saves. Returns [ok, message]
export function light(profile: Dict, starId: unknown): LuaTuple<[boolean, string]> {
	const [constellation, index] = find(starId);
	if (constellation === undefined) {
		return $tuple(false, T("Constellations.ThatStarIsnTOn"));
	}
	const bag = ensure(profile.Constellations);
	profile.Constellations = bag;
	const star = constellation.Stars[index];
	if (bag.Lit[star.Id] === true) {
		return $tuple(false, T("Constellations.ThatStarIsAlreadyLit"));
	}
	if (index > 0 && bag.Lit[constellation.Stars[index - 1].Id] !== true) {
		return $tuple(false, T("Constellations.LightSFirst", constellation.Stars[index - 1].Name));
	}
	const available = math.max(0, lifetimeOf(profile) - spent(bag));
	if (available < star.Cost) {
		return $tuple(false, T("Constellations.YouNeedDMoreStar", star.Cost - available));
	}
	bag.Lit[star.Id] = true;
	const done = litCount(bag, constellation) === constellation.Stars.size();
	return $tuple(
		true,
		done ? T("Constellations.SIsComplete", constellation.Name) : T("Constellations.SIsLit", star.Name, constellation.Name),
	);
}

// what the client shows; plain data only
export function publicView(profile: unknown): Dict {
	const raw = typeIs(profile, "table") ? (profile as Dict).Constellations : undefined;
	const bag = ensure(typeIs(raw, "table") ? { Lit: (raw as Dict).Lit } : undefined);
	return {
		Points: math.max(0, lifetimeOf(profile) - spent(bag)),
		Lifetime: lifetimeOf(profile),
		Lit: bag.Lit,
	};
}
