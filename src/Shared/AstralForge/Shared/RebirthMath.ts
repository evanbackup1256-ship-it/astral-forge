// Rebirth. A run ends when you trade its flux for cores; what you do around that trade is yours
// to shape. Before a run you can swear a vow (finish fast, build lean, never leave the first
// world, overflow the requirement); keep it and the payout grows, and every few kept vows make
// that vow stronger. From the third rebirth you can carry keepsakes: a machine comes with you at a
// share of its level. Milestone rebirths light a star, and each star is a choice between two
// permanent perks. Every run is logged with its time, payout and a grade against your best.
// Pure: the server's rules and the screen's previews agree.

type Dict = Record<string, unknown>;

interface Vow {
	Id: string;
	Name: string;
	Pays: string;
	Multiplier: number;
	Line: string;
	Seconds?: number;
	Machines?: number;
	Ratio?: number;
}

interface Perk {
	Name: string;
	Line: string;
	Step: number;
}

interface RunSnapshot {
	Seconds: number;
	Zone: number;
	MachineKinds: number;
	Ratio: number;
}

interface RunEntry {
	N: number;
	At: number;
	Seconds: number;
	Cores: number;
	Stardust: number;
	Vow: string;
	Kept: boolean;
	Grade: string;
}

interface QuoteResult {
	Cores: number;
	CoreMultiplier: number;
	Stardust: number;
	StardustMultiplier: number;
	Vow: string;
	Kept: boolean;
	Grade: string;
}

interface CarryResult {
	Cash: number;
	Machines: Record<string, number>;
}

interface Bag {
	Version: number;
	Lifetime: number;
	RunStartedAt: number;
	Vow: string;
	VowSince: number;
	Kept: Partial<Record<string, number>>;
	Stars: Partial<Record<string, string>>;
	Keep: string[];
	Runs: RunEntry[];
	BestCores: number;
	FastestSeconds: number;
}

const VERSION = 1;
const LOG_LIMIT = 10;
const VOW_GRACE = 180;
const KEEP_SHARE = 0.2;
const KEEP_CAP = 60;
const KEEP_SLOTS_AT = table.freeze([3, 12, 30]);
const MASTERY_EVERY = 5;
const MASTERY_STEP = 0.05;
const MASTERY_MAX = 5;
const GRADE_BONUS: Record<string, number> = table.freeze({ S: 0.25, A: 0.1, B: 0, C: 0 });

// each vow is checked at the moment you rebirth, against the run it was sworn for
const VOWS: ReadonlyArray<Vow> = table.freeze([
	table.freeze({
		Id: "Swift",
		Name: "Swift",
		Pays: "Cores",
		Multiplier: 1.3,
		Line: "Rebirth within 12 minutes.",
		Seconds: 12 * 60,
	}),
	table.freeze({
		Id: "Lean",
		Name: "Lean",
		Pays: "Cores",
		Multiplier: 1.45,
		Line: "Own at most 3 kinds of machine.",
		Machines: 3,
	}),
	table.freeze({
		Id: "Homebound",
		Name: "Homebound",
		Pays: "Cores",
		Multiplier: 1.6,
		Line: "Never unlock a second world.",
	}),
	table.freeze({
		Id: "Overflow",
		Name: "Overflow",
		Pays: "Stardust",
		Multiplier: 1.5,
		Line: "Bank 8x the Flux a rebirth needs.",
		Ratio: 8,
	}),
]);

const vowById: Record<string, Vow | undefined> = {};
for (const vow of VOWS) {
	vowById[vow.Id] = vow;
}

function vow(id: string | undefined): Vow | undefined {
	return typeIs(id, "string") ? vowById[id] : undefined;
}

const PERKS: Record<string, Perk> = table.freeze({
	HeadStart: table.freeze({ Name: "Head Start", Line: "Stellar Core starts 5 levels higher.", Step: 5 }),
	StartCash: table.freeze({ Name: "Seed Flux", Line: "Start each run with 4x the Flux.", Step: 3 }),
	CoreYield: table.freeze({ Name: "Dense Cores", Line: "+6% cores from every rebirth.", Step: 0.06 }),
	DustYield: table.freeze({ Name: "Star Sift", Line: "+10% Stardust from every rebirth.", Step: 0.1 }),
	VowPower: table.freeze({ Name: "Iron Word", Line: "Kept vows pay 8% more.", Step: 0.08 }),
	KeepShare: table.freeze({ Name: "Long Memory", Line: "Keepsakes keep 5% more of their level.", Step: 0.05 }),
	VaultCarry: table.freeze({ Name: "Ember Purse", Line: "3% of your vault carries into the next run.", Step: 0.03 }),
});

// lifetime rebirth counts that light a star, and the pair offered at each (cycling)
const STARS = table.freeze([1, 3, 5, 8, 12, 16, 20, 25, 30, 40, 50, 65, 80, 100]);
const PAIRS: ReadonlyArray<[string, string]> = table.freeze([
	["HeadStart", "StartCash"],
	["CoreYield", "DustYield"],
	["VowPower", "KeepShare"],
	["VaultCarry", "CoreYield"],
	["DustYield", "HeadStart"],
	["StartCash", "VowPower"],
	["KeepShare", "VaultCarry"],
]);

function pairAt(index: number): [string, string] {
	return PAIRS[(index - 1) % PAIRS.size()];
}

function int(value: unknown): number {
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge) {
		return 0;
	}
	return math.max(0, math.floor(n));
}

function num(value: unknown): number {
	const n = tonumber(value);
	if (n === undefined || n !== n) {
		return 0;
	}
	return math.max(0, n);
}

// builds or repairs the ledger; `lifetime` seeds the star count for saves from before the ledger
function ensure(raw: unknown, now: number, lifetime?: number): Bag {
	const input = (typeIs(raw, "table") ? raw : {}) as Dict;
	const bag: Bag = {
		Version: VERSION,
		Lifetime: math.max(int(input.Lifetime), int(lifetime)),
		RunStartedAt: int(input.RunStartedAt) > 0 ? int(input.RunStartedAt) : int(now),
		Vow: "",
		VowSince: 0,
		Kept: {},
		Stars: {},
		Keep: [],
		Runs: [],
		BestCores: 0,
		FastestSeconds: 0,
	};
	if (typeIs(input.Vow, "string") && vowById[input.Vow] !== undefined) {
		bag.Vow = input.Vow;
	}
	bag.VowSince = int(input.VowSince);
	if (typeIs(input.Kept, "table")) {
		const keptInput = input.Kept as Dict;
		for (const [id] of pairs(keptInput)) {
			if (vowById[id as string] === undefined) {
				delete bag.Kept[id];
			} else {
				bag.Kept[id] = int(keptInput[id]);
			}
		}
	}
	if (typeIs(input.Stars, "table")) {
		const starsInput = input.Stars as Dict;
		for (const [key, perk] of pairs(starsInput)) {
			const index = tonumber(key);
			const at = index !== undefined ? STARS[index - 1] : undefined;
			const pair = at !== undefined ? pairAt(index!) : undefined;
			if (pair === undefined || (perk !== pair[0] && perk !== pair[1])) {
				delete bag.Stars[key as string];
			} else {
				bag.Stars[key as string] = perk as string;
			}
		}
	}
	const keep: string[] = [];
	if (typeIs(input.Keep, "table")) {
		for (const id of input.Keep as unknown[]) {
			if (typeIs(id, "string") && keep.size() < KEEP_SLOTS_AT.size()) {
				keep.push(id);
			}
		}
	}
	bag.Keep = keep;
	bag.Runs = (typeIs(input.Runs, "table") ? input.Runs : []) as RunEntry[];
	while (bag.Runs.size() > LOG_LIMIT) {
		bag.Runs.remove(0);
	}
	bag.BestCores = num(input.BestCores);
	bag.FastestSeconds = int(input.FastestSeconds);
	// The Luau original normalised the saved table in place: keep its identity and any extra keys.
	if (typeIs(raw, "table")) {
		for (const [key, value] of pairs(bag as unknown as Dict)) {
			input[key] = value;
		}
		return input as unknown as Bag;
	}
	return bag;
}

// how many keepsake slots a lifetime count opens
function keepSlots(lifetime: number): number {
	let slots = 0;
	for (const at of KEEP_SLOTS_AT) {
		if (lifetime >= at) {
			slots += 1;
		}
	}
	return slots;
}

// stars lit but not yet chosen, in order
function pendingStars(bag: Bag): number[] {
	const list: number[] = [];
	for (let index = 0; index < STARS.size(); index++) {
		const at = STARS[index];
		if (int(bag.Lifetime) >= at && bag.Stars[tostring(index + 1)] === undefined) {
			list.push(index + 1);
		}
	}
	return list;
}

function nextStar(bag: Bag): LuaTuple<[number | undefined, number | undefined]> {
	for (let index = 0; index < STARS.size(); index++) {
		if (int(bag.Lifetime) < STARS[index]) {
			return $tuple(index + 1, STARS[index]);
		}
	}
	return $tuple(undefined, undefined);
}

function pickStar(bag: Bag, index: number, pick: number): LuaTuple<[boolean, string | undefined]> {
	const at = STARS[index - 1];
	if (at === undefined) {
		return $tuple(false, "That star doesn't exist.");
	}
	if (int(bag.Lifetime) < at) {
		return $tuple(false, `That star lights at rebirth ${at}.`);
	}
	if (bag.Stars[tostring(index)] !== undefined) {
		return $tuple(false, "You already chose that star.");
	}
	const pair = pairAt(index);
	const perk = pair[pick - 1];
	if (perk === undefined) {
		return $tuple(false, "Pick one of the two.");
	}
	bag.Stars[tostring(index)] = perk;
	return $tuple(true, PERKS[perk].Name);
}

// summed perks from every chosen star
function effects(bag: unknown): Record<string, number> {
	const out: Record<string, number> = {};
	for (const [kind] of pairs(PERKS)) {
		out[kind] = 0;
	}
	if (typeIs(bag, "table") && typeIs((bag as Bag).Stars, "table")) {
		const stars = (bag as Bag).Stars;
		for (const [, perk] of pairs(stars)) {
			const def = PERKS[perk as string];
			if (def !== undefined) {
				out[perk as string] += def.Step;
			}
		}
	}
	return out;
}

// a vow grows by MASTERY_STEP for every MASTERY_EVERY times it has been kept
function mastery(bag: unknown, id: string): number {
	const kept =
		typeIs(bag, "table") && typeIs((bag as Bag).Kept, "table")
			? int((bag as Bag).Kept[id])
			: 0;
	return math.min(MASTERY_MAX, math.floor(kept / MASTERY_EVERY));
}

function vowMultiplier(bag: unknown, id: string): number {
	const v = vowById[id];
	if (v === undefined) {
		return 1;
	}
	const extra = (v.Multiplier - 1) * (1 + effects(bag).VowPower);
	return 1 + extra + mastery(bag, id) * MASTERY_STEP;
}

// whether the sworn vow holds right now. run = { Seconds, Zone, MachineKinds, Ratio }
function vowHolds(bag: Bag, run: RunSnapshot): LuaTuple<[boolean, string]> {
	const v = vowById[bag.Vow];
	if (v === undefined) {
		return $tuple(false, "");
	}
	if (bag.VowSince > bag.RunStartedAt + VOW_GRACE) {
		return $tuple(false, "Sworn too late in the run.");
	}
	if (v.Id === "Swift") {
		const left = v.Seconds! - int(run.Seconds);
		return $tuple(
			left >= 0,
			left >= 0 ? `${math.floor(left / 60)}:${"%02d".format(left % 60)} left` : "Too slow this time.",
		);
	} else if (v.Id === "Lean") {
		const kinds = int(run.MachineKinds);
		return $tuple(kinds <= v.Machines!, `${kinds} of ${v.Machines!} machine kinds`);
	} else if (v.Id === "Homebound") {
		const zone = int(run.Zone);
		return $tuple(zone <= 1, zone <= 1 ? "Still in the first world." : "You left the first world.");
	} else if (v.Id === "Overflow") {
		const ratio = num(run.Ratio);
		return $tuple(ratio >= v.Ratio!, `${math.floor(ratio * 10) / 10}x of ${v.Ratio!}x`);
	}
	return $tuple(false, "");
}

// a run's grade: S = a new best with a kept vow, A = either one, B = at least half your best
function grade(bag: Bag, cores: number, kept: boolean): string {
	const best = num(bag.BestCores);
	const newBest = cores > best;
	if (newBest && kept) {
		return "S";
	} else if (newBest || kept) {
		return "A";
	} else if (cores >= best * 0.5) {
		return "B";
	}
	return "C";
}

// what a rebirth pays right now. base = { Cores, Stardust } before the ledger; run as in vowHolds
function quote(bag: Bag, base: unknown, run: unknown): QuoteResult {
	const fx = effects(bag);
	const v = vowById[bag.Vow];
	const kept = v !== undefined ? vowHolds(bag, run as RunSnapshot)[0] : false;
	let coreMult = 1 + fx.CoreYield;
	let dustMult = 1 + fx.DustYield;
	if (kept && v !== undefined) {
		if (v.Pays === "Cores") {
			coreMult *= vowMultiplier(bag, v.Id);
		} else {
			dustMult *= vowMultiplier(bag, v.Id);
		}
	}
	const baseDict = base as Dict;
	const cores = math.max(1, math.floor(num(baseDict.Cores) * coreMult));
	const g = grade(bag, cores, kept);
	dustMult *= 1 + GRADE_BONUS[g];
	return {
		Cores: cores,
		CoreMultiplier: coreMult,
		Stardust: math.floor(num(baseDict.Stardust) * dustMult),
		StardustMultiplier: dustMult,
		Vow: v !== undefined ? v.Id : "",
		Kept: kept,
		Grade: g,
	};
}

// what the next run starts with: { Cash, StellarCore, Machines = { [id] = level }, VaultCash }
function carry(
	bag: Bag,
	machines: unknown,
	vault: number,
	startingCash: number,
	allowed: (id: string) => boolean,
): CarryResult {
	const fx = effects(bag);
	const share = KEEP_SHARE + fx.KeepShare;
	const slots = keepSlots(int(bag.Lifetime));
	const kept: Record<string, number> = {};
	let used = 0;
	for (const id of bag.Keep) {
		if (used >= slots) {
			break;
		}
		const level = int(typeIs(machines, "table") ? (machines as Dict)[id] : undefined);
		if (level > 0 && allowed(id) && kept[id] === undefined) {
			kept[id] = math.clamp(math.floor(level * share), 1, KEEP_CAP);
			used += 1;
		}
	}
	const core = 1 + int(fx.HeadStart);
	kept.StellarCore = math.max(kept.StellarCore ?? 0, core);
	return {
		Cash: math.floor(startingCash * (1 + fx.StartCash) + num(vault) * fx.VaultCarry),
		Machines: kept,
	};
}

// closes the run: logs it, counts the kept vow, sets the next vow and keepsakes, starts the clock
function close(
	bag: Bag,
	q: QuoteResult,
	now: number,
	nextVow?: string,
	nextKeep?: string[],
): RunEntry {
	const seconds = math.max(0, int(now) - bag.RunStartedAt);
	const entry: RunEntry = {
		N: int(bag.Lifetime) + 1,
		At: int(now),
		Seconds: seconds,
		Cores: q.Cores,
		Stardust: q.Stardust,
		Vow: q.Vow,
		Kept: q.Kept,
		Grade: q.Grade,
	};
	bag.Runs.push(entry);
	while (bag.Runs.size() > LOG_LIMIT) {
		bag.Runs.remove(0);
	}
	if (q.Kept && q.Vow !== "") {
		bag.Kept[q.Vow] = int(bag.Kept[q.Vow]) + 1;
	}
	bag.BestCores = math.max(bag.BestCores, q.Cores);
	if (bag.FastestSeconds === 0 || seconds < bag.FastestSeconds) {
		bag.FastestSeconds = seconds;
	}
	bag.Lifetime = int(bag.Lifetime) + 1;
	bag.RunStartedAt = int(now);
	bag.Vow = nextVow !== undefined && vowById[nextVow] !== undefined ? nextVow : "";
	bag.VowSince = int(now);
	if (typeIs(nextKeep, "table")) {
		const keep: string[] = [];
		for (const id of nextKeep as unknown[]) {
			if (typeIs(id, "string") && keep.size() < KEEP_SLOTS_AT.size() && !keep.includes(id)) {
				keep.push(id);
			}
		}
		bag.Keep = keep;
	}
	return entry;
}

// swear (or drop, with "") a vow mid-run; swearing only counts in the run's first few minutes
function swear(bag: Bag, id: string, now: number): LuaTuple<[boolean, string | undefined]> {
	if (id === "") {
		bag.Vow = "";
		return $tuple(true, "Vow dropped.");
	}
	const v = vowById[id];
	if (v === undefined) {
		return $tuple(false, "That vow doesn't exist.");
	}
	if (int(now) > bag.RunStartedAt + VOW_GRACE) {
		return $tuple(
			false,
			"Vows are sworn at the start of a run. Choose one for the next run when you rebirth.",
		);
	}
	bag.Vow = id;
	bag.VowSince = int(now);
	return $tuple(true, `Sworn: ${v.Name}.`);
}

function setKeep(bag: Bag, ids: unknown): boolean {
	if (!typeIs(ids, "table")) {
		return false;
	}
	const keep: string[] = [];
	for (const id of ids as unknown[]) {
		if (
			typeIs(id, "string") &&
			id.size() <= 48 &&
			keep.size() < keepSlots(int(bag.Lifetime)) &&
			!keep.includes(id)
		) {
			keep.push(id);
		}
	}
	bag.Keep = keep;
	return true;
}

const RebirthMath = {
	VERSION,
	LOG_LIMIT,
	VOW_GRACE,
	KEEP_SHARE,
	KEEP_CAP,
	KEEP_SLOTS_AT,
	MASTERY_EVERY,
	MASTERY_STEP,
	MASTERY_MAX,
	GRADE_BONUS,
	VOWS,
	vow,
	PERKS,
	STARS,
	PAIRS,
	pair: pairAt,
	ensure,
	keepSlots,
	pendingStars,
	nextStar,
	pickStar,
	effects,
	mastery,
	vowMultiplier,
	vowHolds,
	grade,
	quote,
	carry,
	close,
	swear,
	setKeep,
};

export = table.freeze(RebirthMath);
