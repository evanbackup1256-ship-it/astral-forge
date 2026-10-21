// Expedition Board (v8 #4): the board's save shape and the rules both sides read. Three slots, one
// more per ascension up to five. Each slot runs one expedition with up to three relics as crew.
// Crew relics are locked the way the companion is: each one gets an Items.Equipped entry under an
// "Expedition:" key, so the trade, salvage and fusion guards that refuse equipped relics refuse
// them too. The board is the source of truth; relock() rebuilds those entries from it.
//
// Save: Progression.Expeditions = { Slots: { Id, Crew: uid[], StartedAt, EndsAt }[] }.
// Command.ActiveExpedition is the v7 single slot. It migrates into slot 1 on load and is then kept
// as a mirror of slot 1 for older readers; nothing decides anything from it.
import GameConfig = require("./GameConfig");

type Dict = Record<string, unknown>;

const BASE_SLOTS = 3;
const MAX_SLOTS = 5;
const CREW_MAX = 3;
const LOCK_PREFIX = "Expedition:";

interface Slot {
	Id: string;
	Crew: string[];
	StartedAt: number;
	EndsAt: number;
}

interface Board {
	Slots: Slot[];
}

function emptySlot(): Slot {
	return { Id: "", Crew: [], StartedAt: 0, EndsAt: 0 };
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
	return { Id: bag.Id, Crew: crew, StartedAt: whole(bag.StartedAt), EndsAt: whole(bag.EndsAt) };
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
	return { Slots: slots };
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

// Crew power: rarity rank plus half a point per star, summed over the crew.
function crewPower(crew: CrewMember[]): number {
	let power = 0;
	for (const member of crew) power += rarityRank(member.Rarity) + 0.5 * member.Stars;
	return power;
}

// The odds of the crew bringing back extra loot on top of the route's own reward.
function bonusChance(crew: CrewMember[]): number {
	if (crew.size() === 0) return 0;
	return math.clamp(0.45 + 0.04 * crewPower(crew), 0, 0.95);
}

// Extra loot for a successful crew. Production, Tap and Critical crew dig up cores, Capacity and
// Offline crew bring essence, and any crew adds Stardust scaled by the route length.
function bonusLoot(crew: CrewMember[], durationSeconds: number): { Essence: number; Cores: number; Stardust: number } {
	const minutes = math.max(1, durationSeconds / 60);
	let essence = 0;
	let cores = 0;
	for (const member of crew) {
		const weight = rarityRank(member.Rarity) + 0.5 * member.Stars;
		if (member.EffectKind === "Capacity" || member.EffectKind === "Offline") {
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

const ExpeditionBoard = {
	BASE_SLOTS,
	MAX_SLOTS,
	CREW_MAX,
	LOCK_PREFIX,
	slotCount,
	lockKey,
	isLockKey,
	read,
	ensure,
	relock,
	mirror,
	emptySlot,
	crewPower,
	bonusChance,
	bonusLoot,
};
export = table.freeze(ExpeditionBoard);
