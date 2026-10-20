
type Persist = number | string;

type OmegaValue = Persist | { array: number[]; sign?: number };

const MAX_DOUBLE = 1.7976931348623157e+308;
const LOG10_MAX = math.log(MAX_DOUBLE) / math.log(10);
const LN10 = math.log(10);
const HUGE_EXP = 1e18;

function isFinite(n: unknown): n is number {
	return typeIs(n, "number") && n === n && n !== math.huge && n !== -math.huge;
}

const NATIVE_LIMIT = 1e15;
const CANCEL_EPSILON = 5e-15;

function plain(value: unknown): value is number {
	return typeIs(value, "number") && value === value && math.abs(value) < NATIVE_LIMIT;
}

interface Decoded {
	z: boolean;
	s: number;
	e: number;
}

function decode(value: unknown): Decoded {
	if (typeIs(value, "number")) {
		if (value !== value || value === 0) {
			return { z: true, s: 1, e: 0 };
		}
		if (value === math.huge) {
			return { z: false, s: 1, e: HUGE_EXP };
		}
		if (value === -math.huge) {
			return { z: false, s: -1, e: HUGE_EXP };
		}
		return { z: false, s: value < 0 ? -1 : 1, e: math.log(math.abs(value)) / LN10 };
	}
	if (typeIs(value, "string")) {
		const lowered = value.lower();
		if (lowered === "inf" || lowered === "+inf" || lowered === "infinity" || lowered === "+infinity") {
			return { z: false, s: 1, e: HUGE_EXP };
		}
		if (lowered === "-inf" || lowered === "-infinity") {
			return { z: false, s: -1, e: HUGE_EXP };
		}
		if (lowered === "nan" || lowered === "") {
			return { z: true, s: 1, e: 0 };
		}
		const [mantText, expText] = value.match("^([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)");
		if (mantText !== undefined && expText !== undefined) {
			const mant = tonumber(mantText);
			const exp = tonumber(expText);
			if (mant === undefined || exp === undefined || mant !== mant) {
				return { z: true, s: 1, e: 0 };
			}
			if (mant === 0) {
				return { z: true, s: 1, e: 0 };
			}
			return { z: false, s: mant < 0 ? -1 : 1, e: math.log(math.abs(mant)) / LN10 + exp };
		}
		const parsed = tonumber(value);
		if (isFinite(parsed)) {
			return decode(parsed);
		}
		return { z: true, s: 1, e: 0 };
	}
	if (typeIs(value, "table")) {
		const tbl = value as { array?: unknown[]; sign?: number };
		if (typeIs(tbl.array, "table")) {
			const arr = tbl.array as number[];
			const mag = arr[0] as number;
			const layer = (arr[1] as number | undefined) ?? 0;
			const sign = tbl.sign ?? 1;
			if (!typeIs(mag, "number") || mag !== mag) {
				return { z: true, s: 1, e: 0 };
			}
			if (mag === 0 && (layer === 0 || layer === undefined)) {
				return { z: true, s: 1, e: 0 };
			}
			if (layer <= 0) {
				return decode((sign < 0 ? -1 : 1) * mag);
			}
			if (layer === 1) {
				return { z: false, s: sign < 0 ? -1 : 1, e: mag };
			}
			return { z: false, s: sign < 0 ? -1 : 1, e: HUGE_EXP };
		}
	}
	return { z: true, s: 1, e: 0 };
}

function encode(decoded: Decoded): Persist {
	if (decoded.z) {
		return 0;
	}
	const exponent = decoded.e;
	if (exponent !== exponent) {
		return 0;
	}
	if (exponent >= HUGE_EXP || exponent === math.huge) {
		return decoded.s < 0 ? "-inf" : "inf";
	}
	if (exponent >= 15) {
		let exp = math.floor(exponent);
		if (exp !== exp || exp === math.huge) {
			return decoded.s < 0 ? "-inf" : "inf";
		}
		const frac = exponent - exp;
		let mant = 10 ** frac;
		if (mant !== mant || mant === math.huge) {
			mant = 1;
			exp += 1;
		}
		if (mant >= 10) {
			mant /= 10;
			exp += 1;
		}
		const sign = decoded.s < 0 ? "-" : "";
		return "%s%.12fe%d".format(sign, mant, exp);
	}
	if (exponent < -320) {
		return 0;
	}
	const numeric = decoded.s * (10 ** exponent);
	if (isFinite(numeric)) {
		return numeric;
	}
	return decoded.s < 0 ? "-inf" : "inf";
}

// Free functions, matching `function OmegaMath.Add(left, right)`.
// A bare method compiles to `function(self, left, right)`, and every caller
// (including the production loop) uses a dot call, so the last number arrives nil.
const OmegaMath = {
	New(this: void, value: OmegaValue): Persist {
		if (plain(value)) {
			return value === 0 ? 0 : value;
		}
		return encode(decode(value));
	},

	Persist(this: void, value: OmegaValue): Persist {
		if (plain(value)) {
			return value === 0 ? 0 : value;
		}
		return encode(decode(value));
	},

	IsOmega(this: void, _value: OmegaValue): boolean {
		return false;
	},

	Add(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (plain(left) && plain(right)) {
			const sum = left + right;
			if (math.abs(sum) < NATIVE_LIMIT) {
				if (math.abs(sum) < CANCEL_EPSILON * math.max(math.abs(left), math.abs(right))) {
					return 0;
				}
				return sum;
			}
		}
		const a = decode(left);
		const b = decode(right);
		if (a.z) {
			return encode(b);
		}
		if (b.z) {
			return encode(a);
		}
		if (a.s === b.s) {
			const hi = math.max(a.e, b.e);
			const lo = math.min(a.e, b.e);
			let e = hi;
			if (hi - lo <= 18) {
				e = hi + math.log(1 + 10 ** (lo - hi)) / LN10;
			}
			return encode({ z: false, s: a.s, e: e });
		}
		const pos = a.s > 0 ? a : b;
		const neg = a.s > 0 ? b : a;
		if (math.abs(pos.e - neg.e) < 1e-12) {
			return 0;
		}
		if (pos.e > neg.e) {
			let e = pos.e;
			if (pos.e - neg.e <= 18) {
				e = pos.e + math.log(1 - 10 ** (neg.e - pos.e)) / LN10;
			}
			return encode({ z: false, s: 1, e: e });
		}
		let e = neg.e;
		if (neg.e - pos.e <= 18) {
			e = neg.e + math.log(1 - 10 ** (pos.e - neg.e)) / LN10;
		}
		return encode({ z: false, s: -1, e: e });
	},

	Sub(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (plain(left) && plain(right)) {
			return OmegaMath.Add(left, -right);
		}
		const b = decode(right);
		if (b.z) {
			return encode(decode(left));
		}
		return OmegaMath.Add(left, encode({ z: false, s: -b.s, e: b.e }));
	},

	Mul(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (plain(left) && plain(right)) {
			const product = left * right;
			if (math.abs(product) < NATIVE_LIMIT) {
				return product === 0 ? 0 : product;
			}
		}
		const a = decode(left);
		const b = decode(right);
		if (a.z || b.z) {
			return 0;
		}
		return encode({ z: false, s: a.s * b.s, e: a.e + b.e });
	},

	Div(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (plain(left) && plain(right) && right !== 0) {
			const quotient = left / right;
			if (math.abs(quotient) < NATIVE_LIMIT) {
				return quotient === 0 ? 0 : quotient;
			}
		}
		const a = decode(left);
		const b = decode(right);
		if (b.z) {
			if (a.z) {
				return 0;
			}
			return encode({ z: false, s: a.s, e: HUGE_EXP });
		}
		if (a.z) {
			return 0;
		}
		return encode({ z: false, s: a.s * b.s, e: a.e - b.e });
	},

	Pow(this: void, left: OmegaValue, right: OmegaValue): Persist {
		const a0 = decode(left);
		const b = decode(right);
		if (b.z) {
			return 1;
		}
		if (a0.z) {
			return 0;
		}
		const a = a0.s < 0 ? { z: false as const, s: 1, e: a0.e } : a0;
		let exponent: number;
		const roundTrip = b.s < 0 ? -(10 ** b.e) : (10 ** b.e);
		const useDirect = typeIs(right, "number") && isFinite(right);
		if (useDirect) {
			const direct = right as number;
			const rebuilt = roundTrip;
			let drift: number;
			if (rebuilt !== rebuilt || rebuilt === math.huge || rebuilt === -math.huge) {
				drift = math.huge;
			} else {
				drift = math.abs(a.e * (rebuilt - direct));
			}
			exponent = drift > 1e-8 ? direct : rebuilt;
		} else {
			if (b.e >= LOG10_MAX) {
				return encode({ z: false, s: 1, e: HUGE_EXP });
			}
			exponent = roundTrip;
		}
		if (exponent !== exponent || exponent === math.huge || exponent === -math.huge) {
			return encode({ z: false, s: 1, e: HUGE_EXP });
		}
		const powered = a.e * exponent;
		if (powered !== powered || powered >= HUGE_EXP) {
			return encode({ z: false, s: 1, e: HUGE_EXP });
		}
		return encode({ z: false, s: 1, e: powered });
	},

	Max(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (OmegaMath.Compare(left, right) >= 0) {
			return OmegaMath.Persist(left);
		}
		return OmegaMath.Persist(right);
	},

	Min(this: void, left: OmegaValue, right: OmegaValue): Persist {
		if (OmegaMath.Compare(left, right) <= 0) {
			return OmegaMath.Persist(left);
		}
		return OmegaMath.Persist(right);
	},

	Compare(this: void, left: OmegaValue, right: OmegaValue): number {
		if (plain(left) && plain(right)) {
			if (left === right || math.abs(left - right) <= math.max(1, math.abs(left)) * 1e-12) {
				return 0;
			}
			return left > right ? 1 : -1;
		}
		const a = decode(left);
		const b = decode(right);
		if (a.z && b.z) {
			return 0;
		}
		if (a.z) {
			return b.s > 0 ? -1 : 1;
		}
		if (b.z) {
			return a.s > 0 ? 1 : -1;
		}
		if (a.s !== b.s) {
			return a.s > 0 ? 1 : -1;
		}
		if (a.e === b.e || math.abs(a.e - b.e) < 1e-12) {
			return 0;
		}
		if (a.s > 0) {
			return a.e > b.e ? 1 : -1;
		}
		return a.e > b.e ? -1 : 1;
	},

	Lt(this: void, left: OmegaValue, right: OmegaValue): boolean {
		return OmegaMath.Compare(left, right) < 0;
	},

	Lte(this: void, left: OmegaValue, right: OmegaValue): boolean {
		return OmegaMath.Compare(left, right) <= 0;
	},

	Gt(this: void, left: OmegaValue, right: OmegaValue): boolean {
		return OmegaMath.Compare(left, right) > 0;
	},

	Gte(this: void, left: OmegaValue, right: OmegaValue): boolean {
		return OmegaMath.Compare(left, right) >= 0;
	},

	ToNumber(this: void, value: OmegaValue): number {
		if (plain(value)) {
			return value;
		}
		const decoded = decode(value);
		if (decoded.z) {
			return 0;
		}
		if (decoded.e >= LOG10_MAX) {
			return decoded.s < 0 ? -MAX_DOUBLE : MAX_DOUBLE;
		}
		const numeric = decoded.s * (10 ** decoded.e);
		if (isFinite(numeric)) {
			return numeric;
		}
		return decoded.s < 0 ? -MAX_DOUBLE : MAX_DOUBLE;
	},

	Log10(this: void, value: OmegaValue): number {
		const decoded = decode(value);
		if (decoded.z || decoded.s <= 0) {
			return 0;
		}
		return decoded.e;
	},

	Floor(this: void, value: OmegaValue): Persist {
		if (plain(value)) {
			const floored = math.floor(value);
			return floored === 0 ? 0 : floored;
		}
		const decoded = decode(value);
		if (decoded.z) {
			return 0;
		}
		if (decoded.e >= 15) {
			return encode(decoded);
		}
		const floored = math.floor(OmegaMath.ToNumber(value));
		return floored === 0 ? 0 : floored;
	},

	ScaledCost(this: void, baseCost: number, scale: number, level: number): Persist {
		const safeBase = math.max(1e-12, baseCost);
		const safeScale = math.max(1e-12, scale);
		const safeLevel = math.max(0, level);
		return OmegaMath.Floor(OmegaMath.Mul(safeBase, OmegaMath.Pow(safeScale, safeLevel)));
	},

	GeometricSum(this: void, baseCost: number, scale: number, level: number, count: number): Persist {
		const n = math.max(0, math.floor(count));
		if (n <= 0) {
			return 0;
		}
		if (n === 1) {
			return OmegaMath.ScaledCost(baseCost, scale, level);
		}
		const safeBase = math.max(1e-12, baseCost);
		const safeScale = math.max(1e-12, scale);
		const safeLevel = math.max(0, level);
		if (math.abs(safeScale - 1) < 1e-12) {
			return OmegaMath.Floor(OmegaMath.Mul(OmegaMath.ScaledCost(safeBase, safeScale, safeLevel), n));
		}

		const first = OmegaMath.ScaledCost(safeBase, safeScale, safeLevel);
		const ratioPow = OmegaMath.Pow(safeScale, n);
		const numerator = OmegaMath.Sub(ratioPow, 1);
		if (OmegaMath.Lte(numerator, 0)) {
			return first;
		}
		return OmegaMath.Floor(OmegaMath.Div(OmegaMath.Mul(first, numerator), safeScale - 1));
	},

	AffordableCount(this: void, baseCost: number, scale: number, level: number, cash: OmegaValue, maximum: number): LuaTuple<[number, Persist]> {
		let remaining = math.max(0, math.floor(maximum));
		if (remaining <= 0) {
			return $tuple(0, 0);
		}
		const first = OmegaMath.ScaledCost(baseCost, scale, level);
		if (OmegaMath.Gt(first, cash)) {
			return $tuple(0, 0);
		}
		let low = 1;
		let high = remaining;
		while (low < high) {
			const mid = low + math.floor((high - low + 1) / 2);
			if (OmegaMath.Lte(OmegaMath.GeometricSum(baseCost, scale, level, mid), cash)) {
				low = mid;
			} else {
				high = mid - 1;
			}
		}
		return $tuple(low, OmegaMath.GeometricSum(baseCost, scale, level, low));
	},

	BoundedPower(this: void, base: number, exponent: number): Persist {
		return OmegaMath.Pow(math.max(1, base), math.max(0, exponent));
	},

	ToString(this: void, value: OmegaValue): string {
		const persist = encode(decode(value));
		if (typeIs(persist, "number")) {
			return tostring(persist);
		}
		return persist;
	},
};

export = OmegaMath;
