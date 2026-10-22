// A companion is one relic you keep with you instead of socketing it. It lives in
// Items.Equipped under its own key, so everything that already refuses to trade,
// salvage or fuse an equipped relic treats the companion the same way for free.
//
// It gives a share of its own effect as a global bonus of the same kind, so a
// levelled, starred favourite stays useful even after the sockets fill up.
// BALANCE: SHARE is a first pass. A socketed relic still pays more than a companion.
import { T } from "./Locale";
import * as RelicModel from "./RelicModel";
import * as RelicEffect from "./RelicEffect";

type Dict = Record<string, unknown>;

const TARGET = "Companion:1";
const SLOT = "Companion";
const SHARE = RelicEffect.COMPANION_SHARE;

type Definition = RelicModel.RelicDefinition;

function uidOf(items: unknown): string | undefined {
	return RelicModel.uidAt(items, TARGET);
}

// the relic instance and its definition, or nothing when the slot is empty or stale
function current(items: unknown): LuaTuple<[Dict | undefined, Definition | undefined]> {
	return RelicModel.at(items, TARGET);
}


// ---- Bonds ----------------------------------------------------------------------------------
// A companion earns bond XP while it rides along. Ranks 3, 6 and 10 are evolutions: the share
// steps up (40 -> 50 -> 60 -> 70%) and the player picks one of two traits. Bond lives on the relic
// instance (Inventory[uid].Bond), so it travels with the relic through trades.
const MAX_RANK = 10;
const EVOLUTIONS = RelicEffect.EVOLUTION_RANKS;
const SUFFIXES = ["", "Bonded", "Kindred", "Soulbound"];
// total XP needed to reach each rank; rank 1 is free. About 2h of play to 3, a few weeks to 10.
const RANK_XP = [0, 200, 600, 1400, 2600, 4400, 7000, 10600, 15400, 21600];
const XP_PER_MINUTE = 6;
const XP_PER_TAP = 0.2;
const XP_PER_CRATE = 4;
const XP_PER_PASS_CAP = 40;

interface Trait {
	Id: string;
	Name: string;
	Text: string;
	Kind: string;
	Amount: number;
}

const TRAITS: Trait[] = [
	{ Id: "Hoarder", Name: "Hoarder", Text: "+5% vault capacity", Kind: "Capacity", Amount: 0.05 },
	{ Id: "Stoker", Name: "Stoker", Text: "+4% production", Kind: "Production", Amount: 0.04 },
	{ Id: "Striker", Name: "Striker", Text: "+6% tap power", Kind: "Tap", Amount: 0.06 },
	{ Id: "Keeper", Name: "Keeper", Text: "+6% offline earnings", Kind: "Offline", Amount: 0.06 },
	{ Id: "Scout", Name: "Scout", Text: "Expeditions return 5% faster", Kind: "ExpeditionSpeed", Amount: 0.05 },
	{ Id: "Lucky", Name: "Lucky", Text: "+3% critical chance", Kind: "Critical", Amount: 0.03 },
];

interface Bond {
	XP: number;
	Rank: number;
	Trait?: string;
	Offer?: string[];
}

function traitOf(id: unknown): Trait | undefined {
	for (const trait of TRAITS) {
		if (trait.Id === id) return trait;
	}
	return undefined;
}

function rankForXP(xp: number): number {
	let rank = 1;
	for (let r = 2; r <= MAX_RANK; r++) {
		if (xp >= RANK_XP[r - 1]) rank = r;
	}
	return rank;
}

function shareFor(rank: number): number {
	return RelicEffect.companionShare(rank);
}

function evolutionStep(rank: number): number {
	return RelicEffect.evolutionsReached(rank);
}

function bondOf(instance: unknown): Bond | undefined {
	const raw = typeIs(instance, "table") ? (instance as Dict).Bond : undefined;
	return typeIs(raw, "table") ? (raw as unknown as Bond) : undefined;
}

function rankOf(instance: unknown): number {
	const bond = bondOf(instance);
	return bond !== undefined && typeIs(bond.Rank, "number") ? math.clamp(math.floor(bond.Rank), 1, MAX_RANK) : 1;
}

// two traits for an evolution, picked from the uid so a reroll by relogging is impossible
function offerFor(uid: string, rank: number, current?: string): string[] {
	let seed = rank * 131;
	for (let i = 1; i <= uid.size(); i++) seed = (seed * 31 + string.byte(uid, i)[0]) % 1000003;
	const pool: string[] = [];
	for (const trait of TRAITS) {
		if (trait.Id !== current) pool.push(trait.Id);
	}
	const first = seed % pool.size();
	const second = (first + 1 + (math.floor(seed / 7) % (pool.size() - 1))) % pool.size();
	return [pool[first], pool[second]];
}

// clamps a stored bond into shape; an empty bond is dropped so untouched relics save as before
function normalizeBond(instance: Dict): void {
	const bond = bondOf(instance);
	if (bond === undefined) {
		instance.Bond = undefined;
		return;
	}
	const xp = typeIs(bond.XP, "number") && bond.XP === bond.XP ? math.clamp(math.floor(bond.XP), 0, RANK_XP[MAX_RANK - 1]) : 0;
	const rank = rankForXP(xp);
	const trait = traitOf(bond.Trait) !== undefined && evolutionStep(rank) > 0 ? (bond.Trait as string) : undefined;
	let offer: string[] | undefined;
	if (typeIs(bond.Offer, "table") && evolutionStep(rank) > 0) {
		const a = (bond.Offer as unknown[])[0];
		const b = (bond.Offer as unknown[])[1];
		if (traitOf(a) !== undefined && traitOf(b) !== undefined && a !== b) offer = [a as string, b as string];
	}
	if (xp === 0 && trait === undefined && offer === undefined) {
		instance.Bond = undefined;
		return;
	}
	instance.Bond = { XP: xp, Rank: rank, Trait: trait, Offer: offer };
}

function xpFor(minutes: number, taps: number, crates: number): number {
	const raw = minutes * XP_PER_MINUTE + taps * XP_PER_TAP + crates * XP_PER_CRATE;
	return math.clamp(math.floor(raw), 0, XP_PER_PASS_CAP);
}

// adds XP to the current companion. Returns the new rank when it crossed an evolution, 0 for a
// plain gain, or undefined when nothing changed.
function addBondXP(items: unknown, amount: number): number | undefined {
	const uid = uidOf(items);
	const [instance] = current(items);
	if (uid === undefined || instance === undefined || !(amount > 0)) return undefined;
	const bond = bondOf(instance) ?? { XP: 0, Rank: 1 };
	const cap = RANK_XP[MAX_RANK - 1];
	if (bond.XP >= cap) return undefined;
	const before = rankForXP(bond.XP);
	const xp = math.min(cap, math.floor(bond.XP + amount));
	const rank = rankForXP(xp);
	const updated: Bond = { XP: xp, Rank: rank, Trait: bond.Trait, Offer: bond.Offer };
	let evolved = 0;
	if (evolutionStep(rank) > evolutionStep(before)) {
		updated.Offer = offerFor(uid, rank, bond.Trait);
		evolved = rank;
	}
	instance.Bond = updated;
	return evolved;
}

// PickTrait: only while an evolution offer is open, and only one of the two offered
function pickTrait(items: unknown, traitId: unknown): LuaTuple<[boolean, string]> {
	const [instance] = current(items);
	if (instance === undefined) return $tuple(false, T("CompanionBonds.NoCompanion"));
	const bond = bondOf(instance);
	if (bond === undefined || bond.Offer === undefined) return $tuple(false, T("CompanionBonds.NothingToChoose"));
	if (bond.Offer[0] !== traitId && bond.Offer[1] !== traitId) return $tuple(false, T("CompanionBonds.NotOffered"));
	instance.Bond = { XP: bond.XP, Rank: bond.Rank, Trait: traitId as string, Offer: undefined };
	return $tuple(true, (traitOf(traitId) as Trait).Name);
}

function traitBonus(items: unknown, kind: string): number {
	const [instance] = current(items);
	const trait = traitOf(bondOf(instance)?.Trait);
	return trait !== undefined && trait.Kind === kind ? trait.Amount : 0;
}

// progress inside the current rank, 0..1, and 1 at the top
function rankProgress(instance: unknown): number {
	const bond = bondOf(instance);
	const xp = bond?.XP ?? 0;
	const rank = rankForXP(xp);
	if (rank >= MAX_RANK) return 1;
	const from = RANK_XP[rank - 1];
	const to = RANK_XP[rank];
	return math.clamp((xp - from) / (to - from), 0, 1);
}

function nextEvolution(rank: number): number | undefined {
	for (const at of EVOLUTIONS) {
		if (rank < at) return at;
	}
	return undefined;
}

function effectOf(instance: Dict, definition: Definition): number {
	const level = typeIs(instance.Level, "number") ? math.max(1, instance.Level) : 1;
	return RelicEffect.effectAt(definition, level, instance.Stars, shareFor(rankOf(instance)));
}

function bonus(items: unknown, kind: string): number {
	const [instance, definition] = current(items);
	if (instance === undefined || definition === undefined) {
		return 0;
	}
	const own = definition.EffectKind === kind ? effectOf(instance, definition) : 0;
	return own + traitBonus(items, kind);
}

// what the profile card and HUD show; undefined when nobody is along for the ride
interface Description {
	Uid: string;
	Id: string;
	Name: string;
	Rarity: string;
	Kind: string;
	Bonus: number;
	Rank: number;
	Progress: number;
	Share: number;
	Suffix: string;
	Trait?: Trait;
	Offer?: Trait[];
	NextEvolution?: number;
}

function describe(items: unknown): Description | undefined {
	const [instance, definition] = current(items);
	if (instance === undefined || definition === undefined) {
		return undefined;
	}
	return {
		Uid: uidOf(items) as string,
		Id: definition.Id,
		Name: definition.Name,
		Rarity: definition.Rarity,
		Kind: definition.EffectKind,
		Bonus: effectOf(instance, definition),
		Rank: rankOf(instance),
		Progress: rankProgress(instance),
		Share: shareFor(rankOf(instance)),
		Suffix: SUFFIXES[evolutionStep(rankOf(instance))],
		Trait: traitOf(bondOf(instance)?.Trait),
		Offer: offerTraits(instance),
		NextEvolution: nextEvolution(rankOf(instance)),
	};
}

function offerTraits(instance: unknown): Trait[] | undefined {
	const offer = bondOf(instance)?.Offer;
	if (offer === undefined) return undefined;
	const a = traitOf(offer[0]);
	const b = traitOf(offer[1]);
	return a !== undefined && b !== undefined ? [a, b] : undefined;
}

// drops the key when it points at nothing, so a salvaged or traded relic can't linger
function sanitize(items: unknown): void {
	if (!typeIs(items, "table")) {
		return;
	}
	const inventory = (items as Dict).Inventory;
	if (typeIs(inventory, "table")) {
		for (const [uid, instance] of pairs(inventory as Dict)) {
			if (typeIs(uid, "string") && typeIs(instance, "table") && (instance as Dict).Bond !== undefined) {
				normalizeBond(instance as Dict);
			}
		}
	}
	const equipped = (items as Dict).Equipped;
	if (!typeIs(equipped, "table")) {
		return;
	}
	if ((equipped as Dict)[TARGET] !== undefined && current(items)[0] === undefined) {
		(equipped as Dict)[TARGET] = undefined;
	}
}

const CompanionRelic = {
	TARGET,
	SLOT,
	SHARE,
	MAX_RANK,
	EVOLUTIONS,
	RANK_XP,
	TRAITS,
	uidOf,
	bonus,
	describe,
	sanitize,
	shareFor,
	rankForXP,
	xpFor,
	addBondXP,
	pickTrait,
	traitBonus,
	traitOf,
};
export = table.freeze(CompanionRelic);
