import EchoMath from "../../../../Shared/AstralForge/Shared/EchoMath";
import { Dict, economyKit, isTable, num, truthy } from "../LuaInterop";

type Bag = ReturnType<typeof EchoMath.ensure>;
type Echo = Bag["Inventory"][string];
type ActResult = LuaTuple<[boolean, string, Dict?]>;
interface EconomyApi {
	DomainTreeBonus(this: void, profile: Dict, kind: string): number;
	Sub(this: void, amount: unknown, cost: number): unknown;
	AsNumber(this: void, amount: unknown): number;
}
interface ProgressionGateApi {
	IsFeatureUnlocked(this: void, profile: Dict, feature: string): boolean;
}

// Recording play and the single action API for every server-side echo operation.
const Economy = economyKit("Economy") as EconomyApi;
const ProgressionGate = economyKit("ProgressionGate") as ProgressionGateApi;

function ensure(profile: Dict): Bag {
	const bag = EchoMath.ensure(profile.ForgeEchoes);
	profile.ForgeEchoes = bag;
	return bag;
}

function Record(profile: Dict, track: string, weight: number): boolean {
	if (!ProgressionGate.IsFeatureUnlocked(profile, "Echoes")) return false;
	const bag = ensure(profile);
	return EchoMath.record(bag, track, weight, Economy.DomainTreeBonus(profile, "EchoCharge")) > 0;
}

function keepInJournal(bag: Bag, echo: Echo) {
	bag.Journal[echo.Trait] = math.max(num(bag.Journal[echo.Trait]) ?? 0, EchoMath.tierIndex(echo.Tier));
}
function newId(bag: Bag): string {
	const id = `E${bag.NextId}`;
	bag.NextId += 1;
	return id;
}
function unslot(bag: Bag, uid: string) {
	for (let slot = 0; slot < 4; slot++) {
		if (bag.Chord[slot] === uid) bag.Chord[slot] = "";
	}
}

function Act(profile: Dict, payload: unknown, random: Random): ActResult {
	if (!ProgressionGate.IsFeatureUnlocked(profile, "Echoes")) {
		return $tuple(false, "Echoes open later in the forge.");
	}
	const bag = ensure(profile);
	const input = isTable(payload) ? payload : {};
	const op = input.Op;
	const rand = () => random.NextNumber();
	if (op === "Strike") {
		if (bag.Draft.Choices.size() > 0) return $tuple(false, "Pick one of the echoes already waiting.");
		if (bag.Charge < EchoMath.CHARGE_TARGET) return $tuple(false, "The charge isn't full yet.");
		bag.Draft = { Choices: EchoMath.strike(bag, rand), Rerolled: false };
		bag.Charge = 0;
		bag.Tracks = { Collect: 0, Surge: 0, Build: 0, Explore: 0 };
		return $tuple(true, "Three echoes answered.", { Choices: bag.Draft.Choices });
	} else if (op === "Reroll") {
		if (bag.Draft.Choices.size() === 0) return $tuple(false, "Strike first.");
		if (bag.Draft.Rerolled) return $tuple(false, "You've already rerolled this strike.");
		if (bag.Resonance < EchoMath.REROLL_RESONANCE) {
			return $tuple(false, `Rerolling takes ${EchoMath.REROLL_RESONANCE} resonance.`);
		}
		bag.Resonance -= EchoMath.REROLL_RESONANCE;
		bag.Draft = { Choices: EchoMath.strike(bag, rand), Rerolled: true };
		return $tuple(true, "Three new echoes.", { Choices: bag.Draft.Choices });
	} else if (op === "Keep") {
		const choice = bag.Draft.Choices[(num(input.Choice) ?? 0) - 1];
		if (choice === undefined) return $tuple(false, "That echo isn't waiting.");
		if (EchoMath.count(bag.Inventory) >= EchoMath.INVENTORY_LIMIT) {
			return $tuple(false, "Your echoes are full. Dismantle or fuse one first.");
		}
		const uid = newId(bag);
		bag.Inventory[uid] = { Trait: choice.Trait, Tier: choice.Tier, Level: 1, Imprints: choice.Imprints ?? [], Locked: false, At: os.time() };
		bag.Captures += 1;
		bag.Draft = { Choices: [], Rerolled: false };
		keepInJournal(bag, bag.Inventory[uid]);
		for (let slot = 0; slot < EchoMath.slots(bag.Captures); slot++) {
			if (bag.Chord[slot] === "") {
				bag.Chord[slot] = uid;
				break;
			}
		}
		return $tuple(true, "Kept.", { Uid: uid });
	} else if (op === "Slot") {
		const slot = num(input.Slot);
		if (slot === undefined || slot !== math.floor(slot) || slot < 1 || slot > EchoMath.slots(bag.Captures)) {
			return $tuple(false, "That slot isn't open yet.");
		}
		const uid = input.Uid;
		if (uid === "" || uid === undefined) {
			bag.Chord[slot - 1] = "";
			return $tuple(true, "Slot cleared.");
		}
		if (!typeIs(uid, "string") || bag.Inventory[uid] === undefined) return $tuple(false, "That echo isn't yours.");
		unslot(bag, uid);
		bag.Chord[slot - 1] = uid;
		return $tuple(true, "In the chord.");
	} else if (op === "Tune") {
		const echo = typeIs(input.Uid, "string") ? bag.Inventory[input.Uid] : undefined;
		if (echo === undefined) return $tuple(false, "That echo isn't yours.");
		const times = math.clamp(math.floor(num(input.Times) ?? 1), 1, 10);
		let tuned = 0;
		let spent = 0;
		for (let i = 0; i < times; i++) {
			if (echo.Level >= EchoMath.MAX_LEVEL) break;
			const cost = EchoMath.tuneCost(echo.Level);
			if ((num(profile.Stardust) ?? 0) < cost) break;
			profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, cost));
			echo.Level += 1;
			tuned += 1;
			spent += cost;
		}
		if (tuned === 0) {
			return $tuple(false, echo.Level >= EchoMath.MAX_LEVEL ? "Already fully tuned." : `Tuning takes ${EchoMath.tuneCost(echo.Level)} Stardust.`);
		}
		return $tuple(true, `Tuned to level ${echo.Level}.`, { Level: echo.Level, Spent: spent });
	} else if (op === "Fuse") {
		const a = input.A;
		const b = input.B;
		if (!typeIs(a, "string") || !typeIs(b, "string")) return $tuple(false, "Pick two of your echoes.");
		const ea = bag.Inventory[a];
		const eb = bag.Inventory[b];
		if (ea === undefined || eb === undefined || a === b) return $tuple(false, "Pick two of your echoes.");
		if (ea.Trait !== eb.Trait || ea.Tier !== eb.Tier) return $tuple(false, "Only two echoes of the same trait and tier fuse.");
		const nextTier = EchoMath.nextTier(ea.Tier);
		if (nextTier === undefined) return $tuple(false, "Perfect echoes can't go higher.");
		if (truthy(ea.Locked) || truthy(eb.Locked)) return $tuple(false, "Unlock them first.");
		const trait = EchoMath.trait(ea.Trait)!;
		ea.Tier = nextTier;
		ea.Level = math.max(ea.Level, eb.Level);
		ea.Imprints = EchoMath.rollImprints(trait, nextTier, rand);
		let wasSlotted = false;
		for (let slot = 0; slot < 4; slot++) {
			if (bag.Chord[slot] === b) wasSlotted = true;
		}
		unslot(bag, b);
		delete bag.Inventory[b];
		keepInJournal(bag, ea);
		return $tuple(true, `Fused into a ${nextTier} echo.`, { Uid: a, Tier: nextTier, FreedSlot: wasSlotted });
	} else if (op === "Lock") {
		const echo = typeIs(input.Uid, "string") ? bag.Inventory[input.Uid] : undefined;
		if (echo === undefined) return $tuple(false, "That echo isn't yours.");
		echo.Locked = !truthy(echo.Locked);
		return $tuple(true, echo.Locked ? "Locked." : "Unlocked.");
	} else if (op === "Dismantle") {
		const uid = input.Uid;
		if (!typeIs(uid, "string")) return $tuple(false, "That echo isn't yours.");
		const echo = bag.Inventory[uid];
		if (echo === undefined) return $tuple(false, "That echo isn't yours.");
		if (truthy(echo.Locked)) return $tuple(false, "It's locked.");
		const gained = EchoMath.dismantleResonance(echo);
		unslot(bag, uid);
		delete bag.Inventory[uid];
		bag.Resonance += gained;
		return $tuple(true, `+${gained} resonance.`, { Resonance: gained });
	}
	return $tuple(false, "Unknown echo action.");
}

function State(profile: Dict) {
	const bag = ensure(profile);
	const slots = EchoMath.slots(bag.Captures);
	const inventory = new Array<Echo & { Uid: string; Effects: Record<string, number>; TuneCost: number; Resonance: number }>();
	for (const [uid, echo] of pairs(bag.Inventory)) {
		inventory.push({ Uid: uid, Trait: echo.Trait, Tier: echo.Tier, Level: echo.Level, Imprints: echo.Imprints, Locked: echo.Locked,
			Effects: EchoMath.effects(echo), TuneCost: EchoMath.tuneCost(echo.Level), Resonance: EchoMath.dismantleResonance(echo) });
	}
	inventory.sort((x, y) => {
		const tx = EchoMath.tierIndex(x.Tier);
		const ty = EchoMath.tierIndex(y.Tier);
		if (tx !== ty) return tx > ty;
		if (x.Level !== y.Level) return x.Level > y.Level;
		return x.Uid < y.Uid;
	});
	const chord = new Array<{ Slot: number; Open: boolean; Uid: string; NeedsCaptures: number }>();
	const chordEchoes = new Array<Echo>();
	for (let slot = 0; slot < 4; slot++) {
		const uid = bag.Chord[slot] ?? "";
		chord.push({ Slot: slot + 1, Open: slot < slots, Uid: uid, NeedsCaptures: EchoMath.SLOT_CAPTURES[slot] });
		if (slot < slots && uid !== "" && bag.Inventory[uid] !== undefined) chordEchoes.push(bag.Inventory[uid]);
	}
	const totals: Record<string, number> = {};
	for (const kind of EchoMath.KINDS) totals[kind] = EchoMath.total(bag, kind);
	const [dominant] = EchoMath.dominant(bag.Tracks);
	return {
		Version: 2, Charge: bag.Charge, ChargeTarget: EchoMath.CHARGE_TARGET, Ready: bag.Charge >= EchoMath.CHARGE_TARGET,
		Tracks: table.clone(bag.Tracks), Dominant: dominant, Resonance: bag.Resonance, Captures: bag.Captures, Slots: slots,
		Draft: bag.Draft.Choices, Rerolled: bag.Draft.Rerolled, Inventory: inventory, InventoryLimit: EchoMath.INVENTORY_LIMIT,
		Chord: chord, Bonuses: EchoMath.chordBonuses(chordEchoes), Totals: totals, Journal: table.clone(bag.Journal), Odds: EchoMath.tierOdds(bag.Resonance),
	};
}

export = table.freeze({ Record, Act, State });
