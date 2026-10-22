// Purpose: seeded, replayable random numbers for crate rolls.
// Every crate open draws from its own stream built from a 32-bit seed (xoshiro128**), so a roll
// can be replayed exactly from the seed in a log or a test, and the odds can be checked over
// millions of seeds without Roblox's Random. The pick itself still goes through
// CrateRollResolver, so pity and weights behave exactly as before.
// Owner: gameplay. Dependencies: CrateRollResolver.

import CrateRollResolver = require("./CrateRollResolver");

const TWO32 = 4294967296;

// 32-bit multiply that stays exact in a double: split one side into 16-bit halves.
function imul(a: number, b: number): number {
	const al = a % 65536;
	const ah = (a - al) / 65536;
	return (((ah * b) % 65536) * 65536 + al * b) % TWO32;
}

function rotl(x: number, k: number): number {
	return bit32.lrotate(x, k);
}

// splitmix32: spreads one seed into the four state words.
function splitmix(state: number): LuaTuple<[number, number]> {
	const advanced = (state + 0x9e3779b9) % TWO32;
	let z = advanced;
	z = imul(bit32.bxor(z, bit32.rshift(z, 16)), 0x85ebca6b);
	z = imul(bit32.bxor(z, bit32.rshift(z, 13)), 0xc2b2ae35);
	return $tuple(advanced, bit32.bxor(z, bit32.rshift(z, 16)));
}

export class Stream {
	readonly Seed: number;
	Draws = 0;
	private s0: number;
	private s1: number;
	private s2: number;
	private s3: number;

	constructor(seed: number) {
		assert(typeIs(seed, "number") && seed === seed && math.abs(seed) !== math.huge, "CrateRng seed must be a finite number");
		this.Seed = math.floor(seed) % TWO32;
		let state = this.Seed;
		let word: number;
		[state, word] = splitmix(state);
		this.s0 = word;
		[state, word] = splitmix(state);
		this.s1 = word;
		[state, word] = splitmix(state);
		this.s2 = word;
		[state, word] = splitmix(state);
		this.s3 = word;
		if (this.s0 === 0 && this.s1 === 0 && this.s2 === 0 && this.s3 === 0) {
			this.s0 = 1;
		}
	}

	// One raw 32-bit word.
	NextWord(): number {
		this.Draws += 1;
		const result = imul(rotl(imul(this.s1, 5), 7), 9);
		const t = bit32.lshift(this.s1, 9);
		this.s2 = bit32.bxor(this.s2, this.s0);
		this.s3 = bit32.bxor(this.s3, this.s1);
		this.s1 = bit32.bxor(this.s1, this.s2);
		this.s0 = bit32.bxor(this.s0, this.s3);
		this.s2 = bit32.bxor(this.s2, t);
		this.s3 = rotl(this.s3, 11);
		return result;
	}

	// Uniform in [lo, hi). With no bounds, [0, 1).
	NextNumber(lo?: number, hi?: number): number {
		const unit = this.NextWord() / TWO32;
		if (lo === undefined || hi === undefined) {
			return unit;
		}
		return lo + (hi - lo) * unit;
	}

	// Uniform integer in [lo, hi], both ends included, without modulo bias.
	NextInteger(lo: number, hi: number): number {
		const low = math.ceil(math.min(lo, hi));
		const high = math.floor(math.max(lo, hi));
		const span = high - low + 1;
		if (span <= 1) {
			return low;
		}
		const limit = TWO32 - (TWO32 % span);
		let word = this.NextWord();
		while (word >= limit) {
			word = this.NextWord();
		}
		return low + (word % span);
	}
}

// A seed for one open: mixes a server secret, the player, the crate and a per-open counter so
// two opens never share a stream. The secret makes seeds unguessable from outside the server.
export function SeedFor(secret: number, userId: number, crateId: string, counter: number): number {
	let h = (math.floor(secret) % TWO32 + TWO32) % TWO32;
	const text = `${userId}|${crateId}|${counter}`;
	for (const i of $range(1, text.size())) {
		h = imul(bit32.bxor(h, string.byte(text, i)[0]), 0x01000193);
	}
	const [, word] = splitmix(h);
	return word;
}

export interface RollRecord<T> {
	Seed: number;
	Draws: number;
	Rarity: string;
	PityHit: boolean;
	Definition: T | undefined;
}

interface CrateLike {
	PityRarity: string;
	PityAfter: number;
	Weights: Record<string, number>;
}

// Rolls one crate from a seed. Same seed and inputs always give the same record.
export function Roll<T extends defined>(
	seed: number,
	crate: CrateLike,
	pity: number,
	rarities: Record<string, { Rank: number }>,
	definitions: T[],
	rarityOf: (definition: T) => string,
	order: string[],
	minimumInterval: number,
): RollRecord<T> {
	const stream = new Stream(seed);
	const [definition, rarity, pityHit] = CrateRollResolver.roll(
		crate,
		pity,
		rarities,
		definitions,
		rarityOf,
		(lo, hi) => stream.NextNumber(lo, hi),
		(lo, hi) => stream.NextInteger(lo, hi),
		order,
		minimumInterval,
	);
	return { Seed: stream.Seed, Draws: stream.Draws, Rarity: rarity, PityHit: pityHit, Definition: definition };
}
