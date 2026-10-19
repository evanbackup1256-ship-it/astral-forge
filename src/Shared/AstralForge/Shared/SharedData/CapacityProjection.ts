interface Omega {
	Mul(this: void, a: unknown, b: unknown): unknown;
	Max(this: void, a: unknown, b: unknown): unknown;
	Div(this: void, a: unknown, b: unknown): unknown;
	Floor(this: void, a: unknown): unknown;
	ToNumber(this: void, a: unknown): number;
}

interface SteadyParts {
	EfficiencyLevel: number;
	ZoneMultiplier: number;
	PermanentMultiplier: unknown;
	Additives: number[];
	SocialMultiplier: number;
	MasteryMultiplier: number;
	ContinuumProduction: unknown;
}

interface CapacitySecondsParts {
	BaseSeconds: number;
	SecondsPerLevel: number;
	StorageLevel: number;
	Additives: number[];
	DomainRank: number;
	CapacityPerRank: number;
	BoostCapacityMultiplier: number;
	MaxSeconds: number;
	DomainTreeCapacity: number;
}

function SteadyMultiplier(omegaMath: Omega, parts: SteadyParts): unknown {
	let multiplier = omegaMath.Mul(1 + parts.EfficiencyLevel * 0.15, parts.ZoneMultiplier);
	multiplier = omegaMath.Mul(multiplier, parts.PermanentMultiplier);
	for (const additive of parts.Additives) {
		multiplier = omegaMath.Mul(multiplier, 1 + additive);
	}
	multiplier = omegaMath.Mul(multiplier, math.max(1, parts.SocialMultiplier));
	multiplier = omegaMath.Mul(multiplier, parts.MasteryMultiplier);
	multiplier = omegaMath.Mul(multiplier, parts.ContinuumProduction);
	return multiplier;
}

function SteadyProduction(omegaMath: Omega, rawProduction: unknown, parts: SteadyParts): unknown {
	return omegaMath.Mul(rawProduction, SteadyMultiplier(omegaMath, parts));
}

function Seconds(parts: CapacitySecondsParts): number {
	let seconds = parts.BaseSeconds * parts.SecondsPerLevel ** parts.StorageLevel;
	for (const additive of parts.Additives) {
		seconds *= 1 + additive;
	}
	seconds *= 1 + parts.DomainRank * parts.CapacityPerRank;
	seconds *= parts.BoostCapacityMultiplier;
	seconds = math.clamp(seconds, 1, parts.MaxSeconds);
	seconds *= 1 + parts.DomainTreeCapacity;
	return seconds;
}

function Vault(
	omegaMath: Omega,
	baseCapacity: number,
	steadyProduction: unknown,
	seconds: number,
	continuumCapacity: unknown,
): unknown {
	return omegaMath.Floor(
		omegaMath.Max(baseCapacity, omegaMath.Mul(omegaMath.Mul(steadyProduction, seconds), continuumCapacity)),
	);
}

function CapacitySeconds(
	omegaMath: Omega,
	capacity: unknown,
	steadyProduction: unknown,
	lte: (a: unknown, b: unknown) => boolean,
): number {
	if (lte(steadyProduction, 0)) {
		return 0;
	}
	return omegaMath.ToNumber(omegaMath.Div(capacity, steadyProduction));
}

export = table.freeze({ SteadyMultiplier, SteadyProduction, Seconds, Vault, CapacitySeconds });
