// Forge Echoes. Playing leaves a trace: collecting, overcharging, building and exploring each
// fill their own track and together fill the charge. A full charge strikes three echoes shaped
// by whatever you did most; keep one. Echoes have a trait (what they do), a tier (Faint, Clear,
// Vivid, Perfect: how strongly) and, from Clear up, imprints (small extra bonuses). Up to four go
// in your chord; a chord of one affinity is in Harmony, a matched pair is in Unison, four
// different affinities make a Spectrum. Tune echoes with Stardust, fuse two of the same trait and
// tier into the next tier, lock the ones you love, dismantle the rest into Resonance (better
// strikes, rerolls). The journal remembers every trait and tier you have kept; a full row of a
// trait is a permanent bonus. Pure: the server's rules and the screen's previews agree.

type Dict = Record<string, unknown>;

interface Effect {
	Kind: string;
	Base: number;
	PerLevel: number;
}

interface Trait {
	Id: string;
	Name: string;
	Affinity: string;
	Line: string;
	Effects: Effect[];
}

interface Echo {
	Trait: string;
	Tier: string;
	Level: number;
	Imprints: string[];
	Locked: boolean;
	At?: number;
}

interface EchoChoice {
	Trait: string;
	Tier: string;
	Level: number;
	Imprints: string[];
	Locked: boolean;
}

interface Bag {
	Version: number;
	Charge: number;
	Tracks: Record<string, number>;
	Resonance: number;
	Captures: number;
	NextId: number;
	Draft: { Choices: EchoChoice[]; Rerolled: boolean };
	Inventory: Record<string, Echo>;
	Chord: string[];
	Journal: Record<string, number>;
	Equipped?: unknown;
}

const TRACKS = table.freeze(["Collect", "Surge", "Build", "Explore"]);
const TRACK_AFFINITY: Record<string, string> = table.freeze({
	Collect: "Industry",
	Surge: "Impulse",
	Build: "Craft",
	Explore: "Void",
});
const CHARGE_TARGET = 100;
const INVENTORY_LIMIT = 24;
const SLOT_CAPTURES = table.freeze([0, 3, 8, 20]);
const MAX_LEVEL = 60;
const TUNE_BASE = 14;
const TUNE_SCALE = 1.16;
const REROLL_RESONANCE = 25;
const HARMONY = 0.15;
const UNISON = 0.1;
const SPECTRUM = 0.2;
const JOURNAL_BONUS = 0.03;
const IMPRINT_SHARE = 0.3;

// two traits per affinity, each its own thing
const TRAITS_RAW = table.freeze([
	table.freeze({
		Id: "FurnaceMemory",
		Name: "Furnace Memory",
		Affinity: "Industry",
		Line: "The forge remembers running hot.",
		Effects: table.freeze([table.freeze({ Kind: "Production", Base: 0.045, PerLevel: 0.009 })]),
	}),
	table.freeze({
		Id: "DeepReservoir",
		Name: "Deep Reservoir",
		Affinity: "Industry",
		Line: "A vault that holds more than it looks.",
		Effects: table.freeze([table.freeze({ Kind: "Capacity", Base: 0.08, PerLevel: 0.014 })]),
	}),
	table.freeze({
		Id: "StrikeGhost",
		Name: "Strike Ghost",
		Affinity: "Impulse",
		Line: "A second hammer lands with yours.",
		Effects: table.freeze([table.freeze({ Kind: "Tap", Base: 0.07, PerLevel: 0.012 })]),
	}),
	table.freeze({
		Id: "LuckyAfterimage",
		Name: "Lucky Afterimage",
		Affinity: "Impulse",
		Line: "Some strikes split clean.",
		Effects: table.freeze([table.freeze({ Kind: "Critical", Base: 0.009, PerLevel: 0.0015 })]),
	}),
	table.freeze({
		Id: "ClockworkEcho",
		Name: "Clockwork Echo",
		Affinity: "Craft",
		Line: "Machines bank on their own.",
		Effects: table.freeze([table.freeze({ Kind: "Automation", Base: 0.018, PerLevel: 0.0025 })]),
	}),
	table.freeze({
		Id: "LatticeRecall",
		Name: "Lattice Recall",
		Affinity: "Craft",
		Line: "Every build makes room for the next.",
		Effects: table.freeze([
			table.freeze({ Kind: "Capacity", Base: 0.04, PerLevel: 0.007 }),
			table.freeze({ Kind: "Production", Base: 0.02, PerLevel: 0.004 }),
		]),
	}),
	table.freeze({
		Id: "NightShift",
		Name: "Night Shift",
		Affinity: "Void",
		Line: "Work carries on while you're away.",
		Effects: table.freeze([table.freeze({ Kind: "Offline", Base: 0.035, PerLevel: 0.006 })]),
	}),
	table.freeze({
		Id: "VoidPulse",
		Name: "Void Pulse",
		Affinity: "Void",
		Line: "Strikes hit harder from nowhere.",
		Effects: table.freeze([
			table.freeze({ Kind: "Tap", Base: 0.035, PerLevel: 0.006 }),
			table.freeze({ Kind: "Critical", Base: 0.005, PerLevel: 0.0008 }),
		]),
	}),
]);

const traitById: Record<string, Trait | undefined> = {};
const TRAITS = TRAITS_RAW as unknown as ReadonlyArray<Trait>;
for (const trait of TRAITS) {
	traitById[trait.Id] = trait;
}

function trait(id: string | undefined): Trait | undefined {
	return id ? traitById[id] : undefined;
}

// old ids that changed: Surge Mnemonic became Void Pulse
const RENAMED: Record<string, string> = table.freeze({ SurgeMnemonic: "VoidPulse" });

const KINDS = table.freeze(["Production", "Capacity", "Tap", "Critical", "Automation", "Offline"]);
const KIND_BASE: Record<string, number> = table.freeze({
	Production: 0.045,
	Capacity: 0.08,
	Tap: 0.07,
	Critical: 0.009,
	Automation: 0.018,
	Offline: 0.035,
});
const KIND_PER_LEVEL: Record<string, number> = table.freeze({
	Production: 0.009,
	Capacity: 0.014,
	Tap: 0.012,
	Critical: 0.0015,
	Automation: 0.0025,
	Offline: 0.006,
});

const TIERS = table.freeze(["Faint", "Clear", "Vivid", "Perfect"]);
const TIER_POWER: Record<string, number> = table.freeze({ Faint: 0.85, Clear: 1, Vivid: 1.2, Perfect: 1.5 });
const TIER_IMPRINTS: Record<string, number> = table.freeze({ Faint: 0, Clear: 1, Vivid: 1, Perfect: 2 });
const TIER_INDEX: Record<string, number> = table.freeze({ Faint: 1, Clear: 2, Vivid: 3, Perfect: 4 });

function tierIndex(tier: string | undefined): number {
	return TIER_INDEX[tier ?? ""] ?? 1;
}

function nextTier(tier: string | undefined): string | undefined {
	return TIERS[tierIndex(tier)];
}

// ------------------------------------------------------------------------------------------------
// the bag
// ------------------------------------------------------------------------------------------------
function int(v: unknown, min = 0): number {
	return math.max(min, math.floor((tonumber(v) ?? 0) as number));
}

function blank(): Bag {
	return {
		Version: 2,
		Charge: 0,
		Tracks: { Collect: 0, Surge: 0, Build: 0, Explore: 0 },
		Resonance: 0,
		Captures: 0,
		NextId: 1,
		Draft: { Choices: [], Rerolled: false },
		Inventory: {},
		Chord: ["", "", "", ""],
		Journal: {},
	};
}

// an old echo (trait, level, strength 0.75..1.5) becomes a new one
function migrateEcho(old: unknown): Echo | undefined {
	const oldDict = old as Dict;
	const traitId = RENAMED[oldDict.TraitId as string] ?? (oldDict.TraitId as string);
	if (traitById[traitId] === undefined) {
		return undefined;
	}
	const strength = tonumber(oldDict.Strength) ?? 1;
	const tier = strength >= 1.25 ? "Vivid" : strength >= 1.08 ? "Clear" : "Faint";
	return {
		Trait: traitId,
		Tier: tier,
		Level: math.clamp(int(oldDict.Level, 1), 1, MAX_LEVEL),
		Imprints: [],
		Locked: false,
		At: int(oldDict.CapturedAt),
	};
}

function ensure(bag: unknown): Bag {
	if (!typeIs(bag, "table")) {
		return blank();
	}
	const input = bag as Bag;
	if (input.Version !== 2) {
		// the old echoes: keep every echo, the chord and the resonance; drop the waiting draft
		const fresh = blank();
		fresh.Resonance = int(input.Resonance);
		fresh.Captures = int(input.Captures);
		fresh.Charge = math.clamp((tonumber(input.Charge) ?? 0) as number, 0, CHARGE_TARGET);
		let nextId = 1;
		const remap: Record<string, string> = {};
		const inventoryInput = typeIs(input.Inventory, "table") ? (input.Inventory as Dict) : {};
		for (const [uid, old] of pairs(inventoryInput)) {
			const echo = migrateEcho(old);
			if (echo) {
				const id = "E" + nextId;
				nextId += 1;
				fresh.Inventory[id] = echo;
				remap[uid as string] = id;
				fresh.Journal[echo.Trait] = math.max(fresh.Journal[echo.Trait] ?? 0, tierIndex(echo.Tier));
			}
		}
		fresh.NextId = nextId;
		if (typeIs(input.Equipped, "table")) {
			const equipped = input.Equipped as Dict;
			for (let slot = 0; slot < 3; slot++) {
				const uid = equipped[tostring(slot + 1)];
				if (uid && remap[uid as string]) {
					fresh.Chord[slot] = remap[uid as string];
				}
			}
		}
		return fresh;
	}
	input.Charge = math.clamp((tonumber(input.Charge) ?? 0) as number, 0, CHARGE_TARGET);
	input.Tracks = typeIs(input.Tracks, "table") ? (input.Tracks as Record<string, number>) : { Collect: 0, Surge: 0, Build: 0, Explore: 0 };
	for (const track of TRACKS) {
		input.Tracks[track] = math.max(0, (tonumber(input.Tracks[track]) ?? 0) as number);
	}
	input.Resonance = int(input.Resonance);
	input.Captures = int(input.Captures);
	input.NextId = int(input.NextId, 1);
	input.Draft = typeIs(input.Draft, "table") ? (input.Draft as Bag["Draft"]) : { Choices: [], Rerolled: false };
	input.Draft.Choices = typeIs(input.Draft.Choices, "table") ? (input.Draft.Choices as EchoChoice[]) : [];
	input.Inventory = typeIs(input.Inventory, "table") ? (input.Inventory as Record<string, Echo>) : {};
	for (const [uid, echo] of pairs(input.Inventory as Record<string, unknown>)) {
		if (!typeIs(echo, "table") || traitById[(echo as Echo).Trait] === undefined || TIER_INDEX[(echo as Echo).Tier] === undefined) {
			delete input.Inventory[uid];
		} else {
			const e = echo as Echo;
			e.Level = math.clamp(int(e.Level, 1), 1, MAX_LEVEL);
			e.Imprints = typeIs(e.Imprints, "table") ? (e.Imprints as string[]) : [];
			e.Locked = e.Locked === true;
		}
	}
	input.Chord = typeIs(input.Chord, "table") ? (input.Chord as string[]) : ["", "", "", ""];
	for (let slot = 0; slot < 4; slot++) {
		const uid = input.Chord[slot];
		input.Chord[slot] = typeIs(uid, "string") && input.Inventory[uid] ? uid : "";
	}
	input.Journal = typeIs(input.Journal, "table") ? (input.Journal as Record<string, number>) : {};
	return input;
}

function count(inventory: unknown): number {
	let n = 0;
	const source = typeIs(inventory, "table") ? (inventory as Dict) : {};
	for (const _ of pairs(source)) {
		n += 1;
	}
	return n;
}

function slots(captures: number): number {
	let slots = 1;
	for (let index = 0; index < SLOT_CAPTURES.size(); index++) {
		if (captures >= SLOT_CAPTURES[index]) {
			slots = index + 1;
		}
	}
	return slots;
}

// ------------------------------------------------------------------------------------------------
// recording and striking
// ------------------------------------------------------------------------------------------------
// returns how much charge it added; `boost` is the Domain lattice's faster-echo bonus
function record(bag: Bag, track: string, weight: number, boost?: number): number {
	if (TRACK_AFFINITY[track] === undefined || bag.Draft.Choices.size() > 0) {
		return 0;
	}
	const w = math.clamp((tonumber(weight) ?? 0) as number, 0, 14) * (1 + math.max(0, boost ?? 0));
	if (w <= 0) {
		return 0;
	}
	bag.Tracks[track] = math.min(1e9, (bag.Tracks[track] ?? 0) + w);
	const before = bag.Charge;
	bag.Charge = math.min(CHARGE_TARGET, bag.Charge + w);
	return bag.Charge - before;
}

function dominant(tracks: unknown): LuaTuple<[string, string]> {
	let best = "Collect";
	let bestValue = -1;
	for (const track of TRACKS) {
		const v = (tonumber((tracks as Record<string, unknown>)[track]) ?? 0) as number;
		if (v > bestValue) {
			best = track;
			bestValue = v;
		}
	}
	return $tuple(best, TRACK_AFFINITY[best]);
}

// tier odds: resonance nudges them up (capped)
function tierOdds(resonance: number): Record<string, number> {
	const lift = math.min(0.12, math.sqrt(math.max(0, resonance)) * 0.004);
	return {
		Faint: math.max(0.2, 0.5 - lift * 2),
		Clear: 0.32,
		Vivid: 0.14 + lift,
		Perfect: 0.04 + lift,
	};
}

function rollTier(resonance: number, roll: number): string {
	const odds = tierOdds(resonance);
	const total = odds.Faint + odds.Clear + odds.Vivid + odds.Perfect;
	let at = roll * total;
	for (const tier of TIERS) {
		at -= odds[tier];
		if (at < 0) {
			return tier;
		}
	}
	return "Faint";
}

// imprints: small extra effects of a different kind than the trait's own
function rollImprints(trait: Trait, tier: string, rand: () => number): string[] {
	const imprints: string[] = [];
	const own: Record<string, boolean> = {};
	for (const e of trait.Effects) {
		own[e.Kind] = true;
	}
	const options: string[] = [];
	for (const kind of KINDS) {
		if (!own[kind]) {
			options.push(kind);
		}
	}
	const count = TIER_IMPRINTS[tier] ?? 0;
	for (let i = 0; i < count; i++) {
		if (options.size() === 0) {
			break;
		}
		const pick = math.clamp(math.floor(rand() * options.size()), 0, options.size() - 1);
		imprints.push(options[pick]);
		options.remove(pick);
	}
	return imprints;
}

// three echoes for a full charge: the first always from your dominant affinity
function strike(bag: Bag, rand: () => number): EchoChoice[] {
	const [, affinity] = dominant(bag.Tracks);
	const preferred: Trait[] = [];
	const pool: Trait[] = [];
	for (const t of TRAITS) {
		pool.push(t);
		if (t.Affinity === affinity) {
			preferred.push(t);
		}
	}
	const picked: Trait[] = [];
	const used: Record<string, boolean> = {};
	const first = preferred[math.clamp(math.floor(rand() * preferred.size()), 0, preferred.size() - 1)];
	picked.push(first);
	used[first.Id] = true;
	while (picked.size() < 3) {
		const t = pool[math.clamp(math.floor(rand() * pool.size()), 0, pool.size() - 1)];
		if (!used[t.Id]) {
			used[t.Id] = true;
			picked.push(t);
		}
	}
	const choices: EchoChoice[] = [];
	for (const t of picked) {
		const tier = rollTier(bag.Resonance, rand());
		choices.push({
			Trait: t.Id,
			Tier: tier,
			Level: 1,
			Imprints: rollImprints(t, tier, rand),
			Locked: false,
		});
	}
	return choices;
}

// ------------------------------------------------------------------------------------------------
// what an echo does
// ------------------------------------------------------------------------------------------------
function effects(echo: Echo): Record<string, number> {
	const out: Record<string, number> = {};
	const t = traitById[echo.Trait];
	if (t === undefined) {
		return out;
	}
	const level = math.clamp(int(echo.Level, 1), 1, MAX_LEVEL);
	const power = TIER_POWER[echo.Tier] ?? 1;
	for (const e of t.Effects) {
		out[e.Kind] = (out[e.Kind] ?? 0) + (e.Base + e.PerLevel * (level - 1)) * power;
	}
	for (const kind of echo.Imprints ?? []) {
		if (KIND_BASE[kind] !== undefined) {
			out[kind] = (out[kind] ?? 0) + (KIND_BASE[kind] + KIND_PER_LEVEL[kind] * (level - 1)) * IMPRINT_SHARE;
		}
	}
	return out;
}

// the chord's bonuses: Harmony (2+ echoes, one affinity), Unison (a pair of one trait), Spectrum (4 affinities)
function chordBonuses(echoes: Echo[]): { Harmony: boolean; Unison: boolean; Spectrum: boolean } {
	const affinities: Record<string, number> = {};
	const traits: Record<string, number> = {};
	let n = 0;
	for (const echo of echoes) {
		const t = traitById[echo.Trait];
		if (t) {
			n += 1;
			affinities[t.Affinity] = (affinities[t.Affinity] ?? 0) + 1;
			traits[echo.Trait] = (traits[echo.Trait] ?? 0) + 1;
		}
	}
	let affinityCount = 0;
	for (const _ of pairs(affinities)) {
		affinityCount += 1;
	}
	let unison = false;
	for (const [, c] of pairs(traits)) {
		if (c >= 2) {
			unison = true;
		}
	}
	return {
		Harmony: n >= 2 && affinityCount === 1,
		Unison: unison,
		Spectrum: n >= 4 && affinityCount === 4,
	};
}

function chordMultiplier(bonuses: { Harmony: boolean; Unison: boolean; Spectrum: boolean }): number {
	return (
		1 +
		(bonuses.Harmony ? HARMONY : 0) +
		(bonuses.Unison ? UNISON : 0) +
		(bonuses.Spectrum ? SPECTRUM : 0)
	);
}

// a journal row is complete when every tier of that trait has been kept
function journalBonus(journal: unknown, kind: string): number {
	let total = 0;
	for (const t of TRAITS) {
		const level = (tonumber((journal as Record<string, unknown>)[t.Id]) ?? 0) as number;
		if (level >= TIERS.size()) {
			for (const e of t.Effects) {
				if (e.Kind === kind) {
					total += JOURNAL_BONUS;
				}
			}
		}
	}
	return total;
}

// the whole bonus of one kind: the chord's echoes, its bonuses, and the journal
function total(bag: unknown, kind: string): number {
	if (!typeIs(bag, "table") || (bag as Bag).Version !== 2) {
		return 0;
	}
	const b = bag as Bag;
	const slotCount = slots(int(b.Captures));
	const chord: Echo[] = [];
	for (let slot = 0; slot < slotCount; slot++) {
		const uid = b.Chord[slot];
		const echo = uid && uid !== "" ? b.Inventory[uid] : undefined;
		if (echo) {
			chord.push(echo);
		}
	}
	let sum = 0;
	for (const echo of chord) {
		sum += effects(echo)[kind] ?? 0;
	}
	return sum * chordMultiplier(chordBonuses(chord)) + journalBonus(b.Journal, kind);
}

function tuneCost(level: number): number {
	return math.floor(TUNE_BASE * TUNE_SCALE ** (math.max(1, level) - 1) + 0.5);
}

function dismantleResonance(echo: Echo): number {
	return 5 + int(echo.Level, 1) * 4 + (tierIndex(echo.Tier) - 1) * 10;
}

const EchoMath = {
	TRACKS,
	TRACK_AFFINITY,
	CHARGE_TARGET,
	INVENTORY_LIMIT,
	SLOT_CAPTURES,
	MAX_LEVEL,
	TUNE_BASE,
	TUNE_SCALE,
	REROLL_RESONANCE,
	HARMONY,
	UNISON,
	SPECTRUM,
	JOURNAL_BONUS,
	IMPRINT_SHARE,
	TRAITS,
	trait,
	RENAMED,
	KINDS,
	TIERS,
	TIER_POWER,
	TIER_IMPRINTS,
	tierIndex,
	nextTier,
	blank,
	ensure,
	count,
	slots,
	record,
	dominant,
	tierOdds,
	rollTier,
	rollImprints,
	strike,
	effects,
	chordBonuses,
	chordMultiplier,
	journalBonus,
	total,
	tuneCost,
	dismantleResonance,
};

export = table.freeze(EchoMath);
