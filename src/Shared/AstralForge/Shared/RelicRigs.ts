// Relic rigs. Two relics socketed at the same time do a little extra, on top of what
// each one already does. The bonus lasts only while every piece of the rig is socketed
// on a machine or research you still own. The first time a rig lights, that fact stays
// in Items.Rigs so the milestone can be paid once even if you take the rig apart.
//
// BALANCE: these bonuses are new. Relic base effects, crate weights, codex bonuses,
// rebirth costs and the economy curve are unchanged.
//   Dock        +1.5% production     (Ion Coupler + Flux Lens)
//   Shelf       +2.5% vault time     (Capacity Coil + Pulse Injector)
//   Night       +2% offline efficiency (Chrono Seal + Stellar Drive)
//   Strike      +3% overcharge       (Coil Brace + Critical Prism)
//   Press       +2.5% production     (Helix Coupler + Loom Spindle)
//   Last Press  +3% production       (Anvil Stamp + Origin Shard)
//   First Fire  +3.5% production     (Halo of the First Forge + Aurora Loom)
//   Nine Suns   +4% production       (Heart of Astraeon + Crown of Nine Suns)
// Dock and First Fire both need the Efficiency socket, so only one is active.
// Shelf and Strike both need the Overcharge socket, so only one is active.
// The other rigs can be socketed together. That caps production from rigs at +13%
// (Press + Last Press + First Fire + Nine Suns). First-light rewards are on each rig.

type Dict = Record<string, unknown>;

interface Member {
	Id: string;
	Slot: string;
	Target?: string;
}

interface Reward {
	Stardust?: number;
	Cores?: number;
	Signals?: number;
	Keys?: Record<string, number>;
}

interface Rig {
	Id: string;
	Name: string;
	Line: string;
	Kind: string;
	Amount: number;
	Percent: number;
	Members: ReadonlyArray<Member>;
	Reward: Reward;
}

interface Socket {
	Id: string;
	Slot: string;
	Target: string;
}

interface Ledger {
	Lit: Record<string, boolean>;
}

const KIND_WORD: Record<string, string> = {
	Production: "production",
	Capacity: "vault time",
	Tap: "overcharge",
	Offline: "offline efficiency",
};

const RIGS: ReadonlyArray<Rig> = table.freeze([
	table.freeze({
		Id: "Dock",
		Name: "Dock Rig",
		Line: "Ion Coupler on a machine, Flux Lens on Quantum Efficiency.",
		Kind: "Production",
		Amount: 0.015,
		Percent: 1.5,
		Members: table.freeze([
			table.freeze({ Id: "IonCoupler", Slot: "Machine" }),
			table.freeze({ Id: "FluxLens", Slot: "Research", Target: "Efficiency" }),
		]),
		Reward: table.freeze({ Stardust: 12 }),
	}),
	table.freeze({
		Id: "Shelf",
		Name: "Shelf Rig",
		Line: "Capacity Coil on Dimensional Storage, Pulse Injector on Overcharge Coil.",
		Kind: "Capacity",
		Amount: 0.025,
		Percent: 2.5,
		Members: table.freeze([
			table.freeze({ Id: "CapacityCoil", Slot: "Research", Target: "Storage" }),
			table.freeze({ Id: "PulseInjector", Slot: "Research", Target: "Overcharge" }),
		]),
		Reward: table.freeze({ Stardust: 20 }),
	}),
	table.freeze({
		Id: "Night",
		Name: "Night Rig",
		Line: "Chrono Seal on Offline Production, Stellar Drive on a machine.",
		Kind: "Offline",
		Amount: 0.02,
		Percent: 2,
		Members: table.freeze([
			table.freeze({ Id: "ChronoSeal", Slot: "Research", Target: "Offline" }),
			table.freeze({ Id: "StarDrive", Slot: "Machine" }),
		]),
		Reward: table.freeze({ Stardust: 35 }),
	}),
	table.freeze({
		Id: "Strike",
		Name: "Strike Rig",
		Line: "Coil Brace on Overcharge Coil, Critical Prism on Critical Resonance.",
		Kind: "Tap",
		Amount: 0.03,
		Percent: 3,
		Members: table.freeze([
			table.freeze({ Id: "CoilBrace", Slot: "Research", Target: "Overcharge" }),
			table.freeze({ Id: "CriticalPrism", Slot: "Research", Target: "Critical" }),
		]),
		Reward: table.freeze({ Stardust: 40, Signals: 10 }),
	}),
	table.freeze({
		Id: "Press",
		Name: "Press Rig",
		Line: "Helix Coupler on the Helix Colliders, Loom Spindle on the Astral Loom.",
		Kind: "Production",
		Amount: 0.025,
		Percent: 2.5,
		Members: table.freeze([
			table.freeze({ Id: "HelixCoupler", Slot: "Machine", Target: "HelixColliders" }),
			table.freeze({ Id: "LoomSpindle", Slot: "Machine", Target: "AstralLoom" }),
		]),
		Reward: table.freeze({ Stardust: 80, Keys: table.freeze({ CrystalCrate: 1 }) }),
	}),
	table.freeze({
		Id: "LastPress",
		Name: "Last Press",
		Line: "Anvil Stamp on the Omega Anvil, Origin Shard on the Origin Press.",
		Kind: "Production",
		Amount: 0.03,
		Percent: 3,
		Members: table.freeze([
			table.freeze({ Id: "AnvilStamp", Slot: "Machine", Target: "OmegaAnvil" }),
			table.freeze({ Id: "OriginShard", Slot: "Machine", Target: "OriginPress" }),
		]),
		Reward: table.freeze({ Stardust: 150, Cores: 1 }),
	}),
	table.freeze({
		Id: "FirstFire",
		Name: "First Fire",
		Line: "Halo of the First Forge on a machine, Aurora Loom on Quantum Efficiency.",
		Kind: "Production",
		Amount: 0.035,
		Percent: 3.5,
		Members: table.freeze([
			table.freeze({ Id: "HaloOfFirstForge", Slot: "Machine" }),
			table.freeze({ Id: "AuroraLoom", Slot: "Research", Target: "Efficiency" }),
		]),
		Reward: table.freeze({ Stardust: 300, Keys: table.freeze({ HorizonCrate: 1 }) }),
	}),
	table.freeze({
		Id: "NineSuns",
		Name: "Nine Suns",
		Line: "Heart of Astraeon on a machine, Crown of Nine Suns on a research socket.",
		Kind: "Production",
		Amount: 0.04,
		Percent: 4,
		Members: table.freeze([
			table.freeze({ Id: "HeartOfAstraeon", Slot: "Machine" }),
			table.freeze({ Id: "CrownOfNineSuns", Slot: "Research" }),
		]),
		Reward: table.freeze({ Stardust: 600, Cores: 3 }),
	}),
]);

const byId: Record<string, Rig | undefined> = {};
for (const rig of RIGS) {
	byId[rig.Id] = rig;
}

const COUNT = RIGS.size();

function rig(id: string): Rig | undefined {
	return byId[id];
}

function effectText(entry: { Percent: number; Kind: string }): string {
	const word = KIND_WORD[entry.Kind] ?? entry.Kind;
	const text = tostring(entry.Percent);
	const trimmed = text.gsub("%.0$", "")[0];
	return `+${trimmed}% ${word}`;
}

function ownedLevel(levels: unknown, id: string): number {
	if (!typeIs(levels, "table")) {
		return 0;
	}
	const level = (levels as Dict)[id];
	return typeIs(level, "number") && level === level ? level : 0;
}

// sockets that are actually doing work: the relic is in the inventory, and the
// machine or research it sits on is still at least level 1
function sockets(profile: unknown): Socket[] {
	const found: Socket[] = [];
	if (!typeIs(profile, "table")) {
		return found;
	}
	const bag = profile as Dict;
	const items = bag.Items;
	if (!typeIs(items, "table")) {
		return found;
	}
	const equipped = (items as Dict).Equipped;
	const inventory = (items as Dict).Inventory;
	if (!typeIs(equipped, "table") || !typeIs(inventory, "table")) {
		return found;
	}
	for (const [target, uid] of pairs(equipped as Dict)) {
		if (!typeIs(uid, "string") || !typeIs(target, "string")) {
			continue;
		}
		const instance = (inventory as Dict)[uid];
		if (!typeIs(instance, "table")) {
			continue;
		}
		const definitionId = (instance as Dict).DefinitionId;
		if (!typeIs(definitionId, "string")) {
			continue;
		}
		const [slot, targetId] = target.match("^(%a+):([%w_]+)$");
		if (!typeIs(slot, "string") || !typeIs(targetId, "string")) {
			continue;
		}
		const levels = slot === "Machine" ? bag.Machines : slot === "Research" ? bag.Research : undefined;
		if (ownedLevel(levels, targetId) < 1) {
			continue;
		}
		found.push({ Id: definitionId, Slot: slot, Target: targetId });
	}
	return found;
}

function memberHeld(open: Socket[], member: Member): boolean {
	for (const socket of open) {
		if (socket.Id !== member.Id || socket.Slot !== member.Slot) {
			continue;
		}
		if (member.Target !== undefined && socket.Target !== member.Target) {
			continue;
		}
		return true;
	}
	return false;
}

function holds(open: Socket[], entry: Rig): boolean {
	for (const member of entry.Members) {
		if (!memberHeld(open, member)) {
			return false;
		}
	}
	return entry.Members.size() > 0;
}

function active(profile: unknown): Record<string, boolean> {
	const open = sockets(profile);
	const lit: Record<string, boolean> = {};
	for (const entry of RIGS) {
		if (holds(open, entry)) {
			lit[entry.Id] = true;
		}
	}
	return lit;
}

function bonus(profile: unknown, kind: string): number {
	if (!typeIs(kind, "string")) {
		return 0;
	}
	const lit = active(profile);
	let total = 0;
	for (const entry of RIGS) {
		if (lit[entry.Id] === true && entry.Kind === kind) {
			total += entry.Amount;
		}
	}
	return total;
}

// repairs the ledger in place when the save already has one, so extra keys survive
function ensure(raw: unknown): Ledger {
	const lit: Record<string, boolean> = {};
	const stored = typeIs(raw, "table") ? (raw as Dict).Lit : undefined;
	if (typeIs(stored, "table")) {
		for (const entry of RIGS) {
			if ((stored as Dict)[entry.Id] === true) {
				lit[entry.Id] = true;
			}
		}
	}
	if (typeIs(raw, "table")) {
		(raw as Dict).Lit = lit;
		return raw as Ledger;
	}
	return { Lit: lit };
}

function litCount(raw: unknown): number {
	const ledger = typeIs(raw, "table") ? raw : ensure(raw);
	const lit = typeIs(ledger, "table") ? (ledger as Dict).Lit : undefined;
	if (!typeIs(lit, "table")) {
		return 0;
	}
	let count = 0;
	for (const entry of RIGS) {
		if ((lit as Dict)[entry.Id] === true) {
			count += 1;
		}
	}
	return count;
}

// rigs that are socketed right now and have not been paid yet
function pending(profile: unknown, raw: unknown): Rig[] {
	const ledger = ensure(raw);
	const lit = active(profile);
	const fresh: Rig[] = [];
	for (const entry of RIGS) {
		if (lit[entry.Id] === true && ledger.Lit[entry.Id] !== true) {
			fresh.push(entry);
		}
	}
	return fresh;
}

function view(profile: unknown): {
	Lit: Record<string, boolean>;
	Active: Record<string, boolean>;
	Bonus: Record<string, number>;
} {
	const items = typeIs(profile, "table") ? (profile as Dict).Items : undefined;
	const raw = typeIs(items, "table") ? (items as Dict).Rigs : undefined;
	const ledger = ensure(typeIs(raw, "table") ? raw : undefined);
	// ensure() on a missing bag returns a fresh table; don't write it back here
	const lit: Record<string, boolean> = {};
	for (const entry of RIGS) {
		if (ledger.Lit[entry.Id] === true) {
			lit[entry.Id] = true;
		}
	}
	const on = active(profile);
	const totals: Record<string, number> = { Production: 0, Capacity: 0, Tap: 0, Offline: 0 };
	for (const entry of RIGS) {
		if (on[entry.Id] === true) {
			totals[entry.Kind] = (totals[entry.Kind] ?? 0) + entry.Amount;
		}
	}
	return { Lit: lit, Active: on, Bonus: totals };
}

const RelicRigs = {
	RIGS,
	COUNT,
	KIND_WORD,
	rig,
	effectText,
	sockets,
	active,
	bonus,
	ensure,
	litCount,
	pending,
	view,
};

export = table.freeze(RelicRigs);
