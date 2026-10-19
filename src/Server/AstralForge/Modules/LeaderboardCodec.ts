// Encode/decode a leaderboard page from ordered data store values.

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const OmegaMath = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
) as {
	Lte(this: void, a: unknown, b: unknown): boolean;
	Log10(this: void, value: unknown): number;
	ToNumber(this: void, value: unknown): number;
	[key: string]: unknown;
};

const BUCKET = 1_000_000_000_000;
const MAX_EXPONENT = 1_000_000;
const MAX_DOUBLE = 1e308;

function Encode(value: unknown): number {
	if (OmegaMath.Lte(value, 0)) {
		return 0;
	}
	let log10 = OmegaMath.Log10(value);
	if (!typeIs(log10, "number") || log10 !== log10 || log10 <= 0) {
		const numeric = OmegaMath.ToNumber(value);
		if (numeric <= 0) {
			return 0;
		}
		log10 = math.log10(numeric);
	}
	const exponent = math.clamp(math.floor(log10), 0, MAX_EXPONENT);
	let significand = 10 ** (log10 - exponent);
	if (significand !== significand || significand < 1) {
		significand = 1;
	} else if (significand > 10) {
		significand = 10;
	}
	const fraction = math.clamp((significand - 1) / 9, 0, 1);
	return exponent * BUCKET + math.floor(fraction * (BUCKET - 2) + 0.5) + 1;
}

function Decode(score: unknown): number | string {
	let packed = math.max(0, math.floor(tonumber(score) ?? 0));
	if (packed <= 0) {
		return 0;
	}
	packed -= 1;
	const exponent = math.clamp(math.floor(packed / BUCKET), 0, MAX_EXPONENT);
	const fraction = math.clamp((packed - exponent * BUCKET) / (BUCKET - 2), 0, 1);
	const significand = 1 + fraction * 9;
	if (exponent >= 15) {
		return "%.12fe%d".format(significand, exponent);
	}
	return math.clamp(significand * 10 ** exponent, 0, MAX_DOUBLE);
}

export = table.freeze({ Encode, Decode });
