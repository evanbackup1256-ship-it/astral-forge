// Ascension: the last reset layer, above Domain. It never caps.
//
//   ascend   : needs a Domain rank that rises with every ascension. Resets the Domain (rank, essence,
//              tree), rebirths, cores and the current run. Research, relics, artifacts, Continuum stay.
//   pays     : Aether, more the further past the requirement you go, and +1 Ascension rank, which is
//              a permanent production multiplier.
//   sigils   : six upgrades bought with Aether, each with no level cap.
//   harmony  : the lowest level among all six sigils. Every sigil acts that many levels higher, so
//              raising all six together beats pumping one.
//
// Pure: OmegaMath is passed in so the server, the client and Lune share one set of numbers.
import { T } from "./Locale";

type Dict = Record<string, unknown>;

interface Omega {
	Persist(this: void, value: unknown): unknown;
	Lt(this: void, a: unknown, b: unknown): boolean;
	Pow(this: void, a: unknown, b: unknown): unknown;
	Add(this: void, a: unknown, b: unknown): unknown;
	Sub(this: void, a: unknown, b: unknown): unknown;
	Mul(this: void, a: unknown, b: unknown): unknown;
	Floor(this: void, a: unknown): unknown;
	ScaledCost(this: void, base: number, growth: number, level: number): unknown;
	ToString(this: void, a: unknown): string;
}

interface Sigil {
	readonly Id: string;
	readonly Name: string;
	readonly Effect: string; // what it multiplies
	readonly Line: string; // one plain sentence for the card
	readonly Per: number; // multiplier per effective level
	readonly BaseCost: number;
	readonly Growth: number;
}

// BestDomainRank and RebirthsSpent keep milestone progress after an ascension resets Domain and rebirths.
interface State {
	Rank: number;
	Aether: unknown;
	TotalAether: unknown;
	Sigils: Record<string, number>;
	LastAscendedAt: number;
	BestDomainRank: number;
	RebirthsSpent: number;
}

const SIGILS: ReadonlyArray<Sigil> = table.freeze([
	table.freeze({ Id: "Sol", Name: "Sol", Effect: "Production", Line: "Multiplies all Flux production.", Per: 1.2, BaseCost: 1, Growth: 1.6 }),
	table.freeze({ Id: "Bastion", Name: "Bastion", Effect: "Capacity", Line: "Multiplies vault capacity.", Per: 1.15, BaseCost: 1, Growth: 1.55 }),
	table.freeze({ Id: "Strike", Name: "Strike", Effect: "Tap", Line: "Multiplies overcharge power.", Per: 1.25, BaseCost: 1, Growth: 1.5 }),
	table.freeze({ Id: "Ember", Name: "Ember", Effect: "Cores", Line: "Multiplies cores from every rebirth.", Per: 1.3, BaseCost: 2, Growth: 1.65 }),
	table.freeze({ Id: "Crown", Name: "Crown", Effect: "Essence", Line: "Multiplies Domain essence from every expansion.", Per: 1.2, BaseCost: 2, Growth: 1.7 }),
	table.freeze({ Id: "Lodestar", Name: "Lodestar", Effect: "Aether", Line: "Multiplies Aether from every ascension.", Per: 1.1, BaseCost: 3, Growth: 1.8 }),
]);
const BY_ID: Record<string, Sigil | undefined> = {};
for (const sigil of SIGILS) {
	BY_ID[sigil.Id] = sigil;
}

const RANK_EXPONENT = 1.5; // production x (1 + rank) ^ 1.5

function whole(value: unknown): number {
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge) {
		return 0;
	}
	return math.max(0, math.floor(n));
}

function sigil(id: string): Sigil | undefined {
	return BY_ID[id];
}

// A clean state from whatever the save holds.
function sanitize(raw: unknown, OmegaMath: Omega): State {
	const source = (typeIs(raw, "table") ? raw : {}) as Dict;
	const sigils: Record<string, number> = {};
	if (typeIs(source.Sigils, "table")) {
		for (const [id, level] of pairs(source.Sigils as Record<string | number, unknown>)) {
			if (typeIs(id, "string") && BY_ID[id] !== undefined) {
				sigils[id] = whole(level);
			}
		}
	}
	const amount = (value: unknown): unknown => {
		const [ok, persisted] = pcall(OmegaMath.Persist, value ?? 0);
		if (!ok || OmegaMath.Lt(persisted, 0)) {
			return 0;
		}
		return persisted;
	};
	const rank = whole(source.Rank);
	// saves that ascended before BestDomainRank existed reached at least the last requirement
	let best = whole(source.BestDomainRank);
	if (rank > 0 && best === 0) {
		best = requiredDomainRank(rank - 1);
	}
	return {
		Rank: rank,
		Aether: amount(source.Aether),
		TotalAether: amount(source.TotalAether),
		Sigils: sigils,
		LastAscendedAt: whole(source.LastAscendedAt),
		BestDomainRank: best,
		RebirthsSpent: whole(source.RebirthsSpent),
	};
}

// Domain rank needed for the (n+1)th ascension. Rises forever.
function requiredDomainRank(rank: number): number {
	const n = math.max(0, math.floor(rank));
	return math.floor(25 + 15 * n + 2 * n ** 1.6);
}

function harmony(state: State): number {
	let lowest = math.huge;
	for (const s of SIGILS) {
		lowest = math.min(lowest, state.Sigils[s.Id] ?? 0);
	}
	return lowest === math.huge ? 0 : lowest;
}

// The level a sigil acts at: its own level plus harmony (zero when unbought: harmony lifts only
// sigils you have started).
function effectiveLevel(state: State, id: string): number {
	const level = state.Sigils[id] ?? 0;
	if (level <= 0) {
		return 0;
	}
	return level + harmony(state);
}

function sigilMultiplier(state: State, id: string, OmegaMath: Omega): unknown {
	const s = BY_ID[id];
	if (s === undefined) {
		return 1;
	}
	return OmegaMath.Pow(s.Per, effectiveLevel(state, id));
}

function sigilCost(id: string, level: number, OmegaMath: Omega): unknown {
	const s = BY_ID[id];
	assert(s, "unknown sigil " + tostring(id));
	// + level keeps cheap early levels strictly rising (ScaledCost floors 1.0 and 1.6 to the same 1)
	const n = math.max(0, math.floor(level));
	return OmegaMath.Add(OmegaMath.ScaledCost(s.BaseCost, s.Growth, n), n);
}

// Multiplier for one effect kind: Production also gets the Ascension rank.
function effect(state: State, kind: string, OmegaMath: Omega): unknown {
	let total: unknown = 1;
	for (const s of SIGILS) {
		if (s.Effect === kind) {
			total = OmegaMath.Mul(total, sigilMultiplier(state, s.Id, OmegaMath));
		}
	}
	if (kind === "Production" && state.Rank > 0) {
		total = OmegaMath.Mul(total, OmegaMath.Pow(1 + state.Rank, RANK_EXPONENT));
	}
	return total;
}

// Aether for ascending at `domainRank` with `rank` ascensions done. Going past the requirement pays
// more; Lodestar multiplies it. Nil when the requirement isn't met.
function aetherGain(state: State, domainRank: number, OmegaMath: Omega): unknown {
	const required = requiredDomainRank(state.Rank);
	const reached = math.max(0, math.floor(domainRank));
	if (reached < required) {
		return undefined;
	}
	let base = math.floor((reached / required) ** 1.5 * (3 + state.Rank));
	// Extreme ranks can push the plain-number base to inf/NaN before OmegaMath takes over; cap it (todo500 #78).
	if (base !== base || base > 1e300) {
		base = 1e300;
	}
	return OmegaMath.Floor(OmegaMath.Mul(math.max(1, base), effect(state, "Aether", OmegaMath)));
}

// Buy one level of a sigil; returns (newState, cost) or (nil, reason).
function buy(state: State, id: string, OmegaMath: Omega): LuaTuple<[State | undefined, unknown]> {
	const s = BY_ID[id];
	if (s === undefined) {
		return $tuple(undefined, T("AscensionMath.ThatSigilDoesnTExist"));
	}
	const level = state.Sigils[id] ?? 0;
	const cost = sigilCost(id, level, OmegaMath);
	if (OmegaMath.Lt(state.Aether, cost)) {
		return $tuple(undefined, T("AscensionMath.YouNeedSMoreAether", OmegaMath.ToString(OmegaMath.Sub(cost, state.Aether))));
	}
	const nextState = table.clone(state);
	nextState.Sigils = table.clone(state.Sigils);
	nextState.Sigils[id] = level + 1;
	nextState.Aether = OmegaMath.Sub(state.Aether, cost);
	return $tuple(nextState, cost);
}

// The ascension itself (state side only; the caller resets the rest of the profile).
function ascend(
	state: State,
	domainRank: number,
	now: number,
	OmegaMath: Omega,
	rebirths?: number,
): LuaTuple<[State | undefined, unknown]> {
	const gain = aetherGain(state, domainRank, OmegaMath);
	if (gain === undefined) {
		return $tuple(undefined, T("AscensionMath.ReachDomainRankSTo", requiredDomainRank(state.Rank)));
	}
	return $tuple(
		{
			Rank: state.Rank + 1,
			Aether: OmegaMath.Add(state.Aether, gain),
			TotalAether: OmegaMath.Add(state.TotalAether, gain),
			Sigils: table.clone(state.Sigils),
			LastAscendedAt: math.max(0, math.floor(now)),
			BestDomainRank: math.max(state.BestDomainRank ?? 0, math.floor(domainRank)),
			RebirthsSpent: (state.RebirthsSpent ?? 0) + whole(rebirths),
		},
		gain,
	);
}

export = table.freeze({
	SIGILS,
	RANK_EXPONENT,
	sigil,
	sanitize,
	requiredDomainRank,
	harmony,
	effectiveLevel,
	sigilMultiplier,
	sigilCost,
	effect,
	aetherGain,
	buy,
	ascend,
});
