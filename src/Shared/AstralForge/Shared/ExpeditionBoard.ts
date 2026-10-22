// Expeditions v2: the board's save shape and every rule both sides read, so the launch preview on
// the client and the claim on the server always agree. Three slots, one more per ascension up to
// five. Each slot runs one route with a stance and up to three relics as crew.
//
// Choices per launch:
//   Stance  Careful (slower, smaller haul, no risk), Steady, or Daring (faster, bigger haul, a
//           chance of a setback that halves the route reward and finds nothing extra).
//   Crew    every relic has a role from its effect: Haul (production-like, bigger haul), Guard
//           (capacity and offline, cuts setback risk) or Scout (tap and critical, faster, better
//           finds). Each route favours one role; crew in that role count double. Three different
//           roles make a balanced crew, three of one role resonate.
//   Companion  a companion whose role matches the route adds to the haul; the Scout trait still
//           shortens the trip.
// Outcomes at claim: Setback, Clean or Triumph (the crew found extra loot). Clean and Triumph runs
// build a streak that adds to every haul; a setback resets it.
//
// The odds are fixed at launch and stored on the slot (Stance, Yield, Risk, Find), so changing the
// companion mid-run changes nothing. v8 slots without them read as Steady with the old crew odds.
// Crew relics are locked the way the companion is: each one gets an Items.Equipped entry under an
// "Expedition:" key, so the trade, salvage and fusion guards that refuse equipped relics refuse
// them too. The board is the source of truth; relock() rebuilds those entries from it.
//
// Save: Progression.Expeditions = { Slots: { Id, Crew: uid[], StartedAt, EndsAt, Stance?, Yield?,
// Risk?, Find? }[], Streak?, Best? }. Every v2 field is optional and additive.
// Command.ActiveExpedition is the v7 single slot. It migrates into slot 1 on load and is then kept
// as a mirror of slot 1 for older readers; nothing decides anything from it.
import GameConfig = require("./GameConfig");

type Dict = Record<string, unknown>;

const BASE_SLOTS = 3;
const MAX_SLOTS = 5;
const CREW_MAX = 3;
const LOCK_PREFIX = "Expedition:";

type Stance = "Careful" | "Steady" | "Daring";
type Role = "Haul" | "Guard" | "Scout";
type Outcome = "Setback" | "Clean" | "Triumph";

const STANCES: Stance[] = ["Careful", "Steady", "Daring"];
const ROLES: Role[] = ["Haul", "Guard", "Scout"];

interface Slot {
	Id: string;
	Crew: string[];
	StartedAt: number;
	EndsAt: number;
	Stance?: Stance;
	Yield?: number;
	Risk?: number;
	Find?: number;
}

interface Board {
	Slots: Slot[];
	Streak?: number;
	Best?: number;
}

function emptySlot(): Slot {
	return { Id: "", Crew: [], StartedAt: 0, EndsAt: 0 };
}

function isStance(value: unknown): value is Stance {
	return value === "Careful" || value === "Steady" || value === "Daring";
}

function fraction(value: unknown, low: number, high: number): number | undefined {
	return typeIs(value, "number") && value === value ? math.clamp(value, low, high) : undefined;
}

function asTable(value: unknown): Dict | undefined {
	return typeIs(value, "table") ? (value as Dict) : undefined;
}

function whole(value: unknown): number {
	return typeIs(value, "number") && value === value && value > 0 && value < math.huge ? math.floor(value) : 0;
}

function slotCount(profile: unknown): number {
	const ascension = asTable(asTable(profile)?.Ascension);
	return math.min(MAX_SLOTS, BASE_SLOTS + math.min(MAX_SLOTS - BASE_SLOTS, whole(ascension?.Rank)));
}

function lockKey(slot: number, seat: number): string {
	return `${LOCK_PREFIX}S${slot}_${seat}`;
}

function isLockKey(target: unknown): boolean {
	return typeIs(target, "string") && target.sub(1, LOCK_PREFIX.size()) === LOCK_PREFIX;
}

function cleanSlot(raw: unknown): Slot {
	const bag = asTable(raw);
	if (bag === undefined || !typeIs(bag.Id, "string") || bag.Id === "" || bag.Id.size() > 48) return emptySlot();
	const crew: string[] = [];
	const rawCrew = asTable(bag.Crew);
	if (rawCrew !== undefined) {
		for (const uid of rawCrew as unknown as unknown[]) {
			if (typeIs(uid, "string") && uid !== "" && uid.size() <= 32 && !crew.includes(uid) && crew.size() < CREW_MAX) crew.push(uid);
		}
	}
	const slot: Slot = { Id: bag.Id, Crew: crew, StartedAt: whole(bag.StartedAt), EndsAt: whole(bag.EndsAt) };
	if (isStance(bag.Stance)) slot.Stance = bag.Stance;
	slot.Yield = fraction(bag.Yield, 0.1, 10);
	slot.Risk = fraction(bag.Risk, 0, 0.9);
	slot.Find = fraction(bag.Find, 0, 0.95);
	return slot;
}

function legacySlot(profile: Dict): Slot | undefined {
	const active = asTable(asTable(profile.Command)?.ActiveExpedition);
	if (active === undefined || !typeIs(active.Id, "string") || active.Id === "") return undefined;
	return { Id: active.Id, Crew: [], StartedAt: whole(active.StartedAt), EndsAt: whole(active.EndsAt) };
}

// Mirrors slot 1 into Command.ActiveExpedition for code and clients that still read it.
function mirror(profile: Dict, board: Board): void {
	const command = asTable(profile.Command);
	if (command === undefined) return;
	const first = board.Slots[0];
	command.ActiveExpedition =
		first !== undefined && first.Id !== ""
			? { Id: first.Id, StartedAt: first.StartedAt, EndsAt: first.EndsAt }
			: { Id: "", StartedAt: 0, EndsAt: 0 };
}

// Removes every crew lock and writes them again from the board. A crew uid that no longer exists,
// or that is socketed somewhere else, leaves the crew.
function relock(profile: Dict, board: Board): void {
	const items = asTable(profile.Items);
	const inventory = asTable(items?.Inventory);
	const equipped = asTable(items?.Equipped);
	if (items === undefined || inventory === undefined || equipped === undefined) return;
	const busy = new Set<string>();
	for (const [target, uid] of pairs(equipped)) {
		if (isLockKey(target)) {
			equipped[target as string] = undefined;
		} else if (typeIs(uid, "string")) {
			busy.add(uid);
		}
	}
	board.Slots.forEach((slot, index) => {
		const kept: string[] = [];
		for (const uid of slot.Crew) {
			if (asTable(inventory[uid]) !== undefined && !busy.has(uid)) {
				busy.add(uid);
				kept.push(uid);
				equipped[lockKey(index + 1, kept.size())] = uid;
			}
		}
		slot.Crew = kept;
	});
}

// The board as stored (or migrated from the v7 slot), cleaned, without writing anything back.
// Undefined when the profile has never used the board and has nothing out.
function read(profile: Dict): Board | undefined {
	const progression = asTable(profile.Progression);
	if (progression === undefined) return undefined;
	const stored = asTable(progression.Expeditions);
	const legacy = legacySlot(profile);
	if (stored === undefined && legacy === undefined) return undefined;
	const count = slotCount(profile);
	const rawSlots = asTable(stored?.Slots);
	const slots: Slot[] = [];
	for (let i = 1; i <= count; i++) {
		slots.push(cleanSlot(rawSlots !== undefined ? (rawSlots as unknown as unknown[])[i - 1] : undefined));
	}
	// slots past the current count (a rolled-back ascension) are kept while they are still running
	if (rawSlots !== undefined) {
		for (let i = count + 1; i <= MAX_SLOTS; i++) {
			const extra = cleanSlot((rawSlots as unknown as unknown[])[i - 1]);
			if (extra.Id === "") break;
			slots.push(extra);
		}
	}
	if (stored === undefined && legacy !== undefined) {
		slots[0] = legacy;
	}
	const board: Board = { Slots: slots };
	const streak = whole(stored?.Streak);
	const best = whole(stored?.Best);
	if (streak > 0) board.Streak = streak;
	if (best > 0) board.Best = math.max(best, streak);
	return board;
}

// Normalizes the board in place and returns it. With create unset it never makes a board for a
// profile that has nothing out, so untouched saves stay as they were.
function ensure(profile: Dict, create?: boolean): Board | undefined {
	const progression = asTable(profile.Progression);
	if (progression === undefined) return undefined;
	let board = read(profile);
	if (board === undefined) {
		if (create !== true) {
			// still drop crew locks a hand-edited save might hold
			const equipped = asTable(asTable(profile.Items)?.Equipped);
			if (equipped !== undefined) {
				for (const [target] of pairs(equipped)) {
					if (isLockKey(target)) equipped[target as string] = undefined;
				}
			}
			return undefined;
		}
		const slots: Slot[] = [];
		for (let i = 1; i <= slotCount(profile); i++) slots.push(emptySlot());
		board = { Slots: slots };
	}
	progression.Expeditions = board;
	relock(profile, board);
	mirror(profile, board);
	return board;
}

function rarityRank(rarity: unknown): number {
	const rarities = (GameConfig as unknown as { Items: { Rarities: Record<string, { Rank: number } | undefined> } }).Items.Rarities;
	return typeIs(rarity, "string") ? (rarities[rarity]?.Rank ?? 1) : 1;
}

interface CrewMember {
	Rarity: string;
	EffectKind: string;
	Stars: number;
}

const ROLE_OF: Record<string, Role | undefined> = {
	Production: "Haul",
	Automation: "Haul",
	GridProduction: "Haul",
	GridAutomation: "Haul",
	Reward: "Haul",
	ChargeGain: "Haul",
	Capacity: "Guard",
	GridCapacity: "Guard",
	Offline: "Guard",
	GridOffline: "Guard",
	OfflineHours: "Guard",
	Tap: "Scout",
	GridTap: "Scout",
	Critical: "Scout",
	GridCritical: "Scout",
	PulsePower: "Scout",
	SurgeDuration: "Scout",
};

function roleOf(effectKind: unknown): Role {
	return (typeIs(effectKind, "string") ? ROLE_OF[effectKind] : undefined) ?? "Haul";
}

// The role a route favours: fixed per route id, so it never changes between visits.
function routeRole(routeId: string): Role {
	let hash = 0;
	for (let i = 1; i <= routeId.size(); i++) hash = (hash * 31 + (string.byte(routeId, i)[0] as number)) % 1000003;
	return ROLES[hash % ROLES.size()];
}

function memberWeight(member: CrewMember): number {
	return rarityRank(member.Rarity) + 0.5 * member.Stars;
}

// Crew power: rarity rank plus half a point per star, summed over the crew.
function crewPower(crew: CrewMember[]): number {
	let power = 0;
	for (const member of crew) power += memberWeight(member);
	return power;
}

// v8 crew odds, kept for slots launched before v2 and as the Steady baseline.
function bonusChance(crew: CrewMember[]): number {
	if (crew.size() === 0) return 0;
	return math.clamp(0.45 + 0.04 * crewPower(crew), 0, 0.95);
}

// Extra loot for a Triumph. Haul and Scout crew dig up cores, Guard crew bring essence, and any
// crew adds Stardust scaled by the route length.
function bonusLoot(crew: CrewMember[], durationSeconds: number): { Essence: number; Cores: number; Stardust: number } {
	const minutes = math.max(1, durationSeconds / 60);
	let essence = 0;
	let cores = 0;
	for (const member of crew) {
		const weight = memberWeight(member);
		if (roleOf(member.EffectKind) === "Guard") {
			essence += weight * 2;
		} else {
			cores += weight * 0.5;
		}
	}
	const scale = math.sqrt(minutes);
	return {
		Essence: math.floor(essence * scale),
		Cores: math.floor(cores * scale),
		Stardust: math.floor(crewPower(crew) * scale * 0.25),
	};
}

interface StanceRule {
	Time: number;
	Yield: number;
	Risk: number;
	Find: number;
}

const STANCE_RULES: Record<Stance, StanceRule> = {
	Careful: { Time: 1.25, Yield: 0.85, Risk: 0, Find: -0.15 },
	Steady: { Time: 1, Yield: 1, Risk: 0, Find: 0 },
	Daring: { Time: 0.8, Yield: 1.6, Risk: 0.35, Find: 0.12 },
};

const STREAK_STEP = 0.03;
const STREAK_CAP = 10;

type Synergy = "Favoured" | "Balanced" | "Resonant" | "Companion" | "Streak";

interface Forecast {
	Stance: Stance;
	Role: Role;
	/** multiplier on the launched duration */
	Time: number;
	/** multiplier on the route reward for a Clean or Triumph run */
	Yield: number;
	/** chance of a Setback */
	Risk: number;
	/** chance of a Triumph (extra crew loot); 0 with no crew */
	Find: number;
	Synergies: Synergy[];
}

// Everything a launch promises, from the inputs both sides know. companionKind is the companion's
// EffectKind (undefined without one); streak is the board streak at launch.
function forecast(routeId: string, stanceRaw: unknown, crew: CrewMember[], companionKind: string | undefined, streak: number): Forecast {
	const stance: Stance = isStance(stanceRaw) ? stanceRaw : "Steady";
	const rule = STANCE_RULES[stance];
	const role = routeRole(routeId);
	const synergies: Synergy[] = [];
	const power: Record<Role, number> = { Haul: 0, Guard: 0, Scout: 0 };
	const roles = new Set<Role>();
	let favoured = false;
	for (const member of crew) {
		const memberRole = roleOf(member.EffectKind);
		roles.add(memberRole);
		const match = memberRole === role;
		if (match) favoured = true;
		power[memberRole] += memberWeight(member) * (match ? 2 : 1);
	}
	if (favoured) synergies.push("Favoured");
	let yieldMul = rule.Yield * (1 + 0.025 * power.Haul);
	let time = rule.Time * math.max(0.6, 1 - 0.02 * power.Scout);
	let risk = rule.Risk * math.max(0.2, 1 - 0.07 * power.Guard);
	let find = crew.size() > 0 ? 0.3 + 0.035 * crewPower(crew) + 0.01 * power.Scout + rule.Find : 0;
	if (crew.size() === 3 && roles.size() === 3) {
		synergies.push("Balanced");
		yieldMul *= 1.1;
		find += 0.08;
	} else if (crew.size() === 3 && roles.size() === 1) {
		synergies.push("Resonant");
		if (roles.has("Haul")) yieldMul *= 1.2;
		else if (roles.has("Guard")) risk *= 0.5;
		else time *= 0.85;
	}
	if (companionKind !== undefined && roleOf(companionKind) === role) {
		synergies.push("Companion");
		yieldMul *= 1.1;
	}
	const steps = math.min(STREAK_CAP, math.max(0, math.floor(streak)));
	if (steps > 0) {
		synergies.push("Streak");
		yieldMul *= 1 + STREAK_STEP * steps;
	}
	return {
		Stance: stance,
		Role: role,
		Time: math.clamp(time, 0.35, 2),
		Yield: math.clamp(yieldMul, 0.1, 10),
		Risk: math.clamp(risk, 0, 0.9),
		Find: crew.size() > 0 ? math.clamp(find, 0.05, 0.95) : 0,
		Synergies: synergies,
	};
}

// The odds a running slot was launched with. v8 slots (no Stance) read as Steady with the old odds.
function slotOdds(slot: Slot, crew: CrewMember[]): { Stance: Stance; Yield: number; Risk: number; Find: number } {
	if (slot.Stance === undefined) {
		return { Stance: "Steady", Yield: 1, Risk: 0, Find: bonusChance(crew) };
	}
	return { Stance: slot.Stance, Yield: slot.Yield ?? 1, Risk: slot.Risk ?? 0, Find: crew.size() > 0 ? (slot.Find ?? 0) : 0 };
}

// One roll decides the outcome: under Risk is a Setback, the next Find of the range is a Triumph.
function outcomeFor(roll: number, risk: number, find: number): Outcome {
	if (roll < risk) return "Setback";
	if (find > 0 && roll < risk + (1 - risk) * find) return "Triumph";
	return "Clean";
}

const ExpeditionBoard = {
	BASE_SLOTS,
	MAX_SLOTS,
	CREW_MAX,
	LOCK_PREFIX,
	STANCES,
	ROLES,
	STANCE_RULES,
	STREAK_STEP,
	STREAK_CAP,
	slotCount,
	lockKey,
	isLockKey,
	read,
	ensure,
	relock,
	mirror,
	emptySlot,
	isStance,
	roleOf,
	routeRole,
	crewPower,
	bonusChance,
	bonusLoot,
	forecast,
	slotOdds,
	outcomeFor,
};
export = table.freeze(ExpeditionBoard);
