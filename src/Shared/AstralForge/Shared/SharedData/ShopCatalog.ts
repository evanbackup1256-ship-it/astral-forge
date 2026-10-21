import CrateExpansion = require("../CrateExpansion");

type Dict = Record<string, unknown>;

interface Price {
	Currency: string;
	Amount: number;
}
interface SkinDef {
	Id: string;
	Name: string;
	Tier: string;
	Blurb: string;
	Accent: [number, number, number];
	Glow: [number, number, number];
	Vfx: string;
	Price?: Price;
	Default?: boolean;
	DailyOnly?: boolean;
	/** Earned skins: never sold, owned once the milestone is met (checked on the server). */
	Earn?: { Kind: string; Target: number };
}
interface PoolEntry {
	Id: string;
	Name?: string;
	Kind: string;
	CrateId?: string;
	SkinId?: string;
	BoostId?: string;
	Rarity?: string;
	Amount?: number;
	Minutes?: number;
	Currency?: string;
	Price?: number;
	Stock: number;
	Weight: number;
}
interface Offer extends PoolEntry {
	Slot: number;
	Currency: string;
	Price: number;
	Deal: boolean;
	Name: string;
}

const SLOTS = 6;
const DEAL_DISCOUNT = 0.35;
const DAY_SECONDS = 86400;
const BASE_SKINS = table.freeze([
	{ Id: "Classic", Name: "Forge Iron", Tier: "Common", Blurb: "Riveted iron, warm from the forge.", Accent: [ 255, 184, 52 ], Glow: [ 255, 140, 60 ], Vfx: "embers", Default: true },
	{ Id: "Crystal", Name: "Crystal Prism", Tier: "Rare", Blurb: "Cut quartz panels that split the light.", Accent: [ 120, 220, 255 ], Glow: [ 200, 245, 255 ], Vfx: "shards", Price: { Currency: "Stardust", Amount: 400 } },
	{ Id: "Frost", Name: "Frost Rune", Tier: "Rare", Blurb: "A rune-locked chest that breathes cold.", Accent: [ 170, 225, 255 ], Glow: [ 230, 250, 255 ], Vfx: "frost", Price: { Currency: "Stardust", Amount: 450 } },
	{ Id: "Molten", Name: "Molten Core", Tier: "Epic", Blurb: "Cracked basalt over a river of fire.", Accent: [ 255, 110, 60 ], Glow: [ 255, 190, 90 ], Vfx: "magma", Price: { Currency: "Stardust", Amount: 900 } },
	{ Id: "Nebula", Name: "Nebula Glass", Tier: "Epic", Blurb: "Smoked glass with a small galaxy inside.", Accent: [ 178, 134, 255 ], Glow: [ 250, 140, 220 ], Vfx: "nebula", Price: { Currency: "Cores", Amount: 12 } },
	{ Id: "Void", Name: "Void Reliquary", Tier: "Legendary", Blurb: "Black stone. The lid opens inward.", Accent: [ 130, 90, 220 ], Glow: [ 190, 120, 255 ], Vfx: "void", Price: { Currency: "Cores", Amount: 30 } },
	{ Id: "Gilded", Name: "Gilded Starlight", Tier: "Legendary", Blurb: "Gold leaf and a lid of falling stars.", Accent: [ 255, 214, 120 ], Glow: [ 255, 246, 214 ], Vfx: "stars", Price: { Currency: "Cores", Amount: 40 } },
	{ Id: "Celestial", Name: "Celestial Ark", Tier: "Mythic", Blurb: "Only ever seen in the Daily Shop.", Accent: [ 120, 240, 255 ], Glow: [ 255, 236, 170 ], Vfx: "prism", Price: { Currency: "Cores", Amount: 90 }, DailyOnly: true },
]);

// (Lune guards used to resolve CrateExpansion by relative path; the static import replaces that.)
const SKINS = CrateExpansion.extendSkins(BASE_SKINS as unknown as Parameters<typeof CrateExpansion.extendSkins>[0]) as unknown as ReadonlyArray<SkinDef>;

// day-a batch 38: skins earned from milestones. Kept out of SKINS so the Shop never lists them;
// skin() still finds them so the crate reveal can draw them. Look only, no crate bonuses.
const EARNED_SKINS: ReadonlyArray<SkinDef> = table.freeze([
	{ Id: "Strongbox", Name: "Guild Strongbox", Tier: "Rare", Blurb: "Banded oak with your guild's lock on it.", Accent: [ 96, 200, 130 ], Glow: [ 200, 255, 210 ], Vfx: "stars", Earn: { Kind: "Guild", Target: 1 } },
	{ Id: "TraderCase", Name: "Trader's Case", Tier: "Rare", Blurb: "Scuffed leather, a dozen stamps on the lid.", Accent: [ 255, 196, 120 ], Glow: [ 255, 232, 190 ], Vfx: "shards", Earn: { Kind: "Trades", Target: 10 } },
	{ Id: "RigCrate", Name: "Rig Crate", Tier: "Epic", Blurb: "Wired straight into a relic rig. It hums.", Accent: [ 110, 238, 255 ], Glow: [ 200, 250, 255 ], Vfx: "embers", Earn: { Kind: "Rigs", Target: 5 } },
	{ Id: "SeasonLocker", Name: "Season Locker", Tier: "Epic", Blurb: "Painted over every season. The old colours show at the corners.", Accent: [ 76, 150, 230 ], Glow: [ 180, 220, 255 ], Vfx: "frost", Earn: { Kind: "Seasons", Target: 15 } },
	{ Id: "OldFaithful", Name: "Old Faithful", Tier: "Legendary", Blurb: "Opened so often the hinges are worn smooth.", Accent: [ 214, 132, 92 ], Glow: [ 255, 190, 140 ], Vfx: "magma", Earn: { Kind: "Crates", Target: 500 } },
] as SkinDef[]);

const skinById: Record<string, SkinDef | undefined> = {};
for (const skin of SKINS) {
	skinById[skin.Id] = skin;
}
for (const skin of EARNED_SKINS) {
	skinById[skin.Id] = skin;
}
function skin(id: unknown): SkinDef | undefined {
	return typeIs(id, "string") ? skinById[id] : undefined;
}
const DEFAULT_SKIN = "Classic";
const POOL: ReadonlyArray<PoolEntry> = table.freeze([
	{ Id: "ForgeKeys", Name: "3 Forge Keys", Kind: "Key", CrateId: "ForgeCrate", Amount: 3, Currency: "Stardust", Price: 20, Stock: 2, Weight: 10 },
	{ Id: "CrystalKeys", Name: "2 Crystal Keys", Kind: "Key", CrateId: "CrystalCrate", Amount: 2, Currency: "Stardust", Price: 60, Stock: 2, Weight: 8 },
	{ Id: "NebulaKey", Name: "Nebula Key", Kind: "Key", CrateId: "NebulaCrate", Amount: 1, Currency: "Stardust", Price: 62, Stock: 2, Weight: 7 },
	{ Id: "OrbitKeys", Name: "2 Orbit Keys", Kind: "Key", CrateId: "OrbitCrate", Amount: 2, Currency: "Stardust", Price: 95, Stock: 1, Weight: 6 },
	{ Id: "AetherKey", Name: "Aether Key", Kind: "Key", CrateId: "AetherCrate", Amount: 1, Currency: "Stardust", Price: 52, Stock: 2, Weight: 6 },
	{ Id: "HorizonKey", Name: "Horizon Key", Kind: "Key", CrateId: "HorizonCrate", Amount: 1, Currency: "Stardust", Price: 80, Stock: 1, Weight: 5 },
	{ Id: "SingularityKey", Name: "Singularity Key", Kind: "Key", CrateId: "SingularityCrate", Amount: 1, Currency: "Cores", Price: 3, Stock: 1, Weight: 3 },
	{ Id: "EchoKey", Name: "Echo Key", Kind: "Key", CrateId: "EchoCrate", Amount: 1, Currency: "Cores", Price: 4, Stock: 1, Weight: 3 },
	{ Id: "DriftKey", Name: "Drift Key", Kind: "Key", CrateId: "DriftCrate", Amount: 1, Currency: "Cores", Price: 3, Stock: 1, Weight: 3 },
	{ Id: "EssenceJar", Name: "Essence Jar", Kind: "Essence", Amount: 150, Currency: "Stardust", Price: 40, Stock: 3, Weight: 8 },
	{ Id: "EssenceCask", Name: "Essence Cask", Kind: "Essence", Amount: 600, Currency: "Cores", Price: 3, Stock: 1, Weight: 4 },
	{ Id: "FluxHour", Name: "An Hour of Flux", Kind: "Flux", Minutes: 60, Currency: "Stardust", Price: 30, Stock: 2, Weight: 7 },
	{ Id: "FluxDay", Name: "A Shift of Flux", Kind: "Flux", Minutes: 480, Currency: "Cores", Price: 4, Stock: 1, Weight: 3 },
	{ Id: "Overdrive", Name: "Overdrive Boost", Kind: "Boost", BoostId: "Overdrive", Amount: 1, Currency: "Stardust", Price: 45, Stock: 2, Weight: 5 },
	{ Id: "Hyperdrive", Name: "Hyperdrive Boost", Kind: "Boost", BoostId: "Hyperdrive", Amount: 1, Currency: "Stardust", Price: 70, Stock: 1, Weight: 4 },
	{ Id: "SteadyBurn", Name: "Steady Burn Boost", Kind: "Boost", BoostId: "SteadyBurn", Amount: 1, Currency: "Stardust", Price: 55, Stock: 1, Weight: 4 },
	{ Id: "DomainSurge", Name: "Domain Surge Boost", Kind: "Boost", BoostId: "DomainSurge", Amount: 1, Currency: "Cores", Price: 5, Stock: 1, Weight: 2 },
	{ Id: "EpicCache", Name: "Epic Relic Cache", Kind: "Cache", Rarity: "Epic", Currency: "Stardust", Price: 180, Stock: 1, Weight: 4 },
	{ Id: "LegendaryCache", Name: "Legendary Relic Cache", Kind: "Cache", Rarity: "Legendary", Currency: "Cores", Price: 8, Stock: 1, Weight: 2 },
	{ Id: "MythicCache", Name: "Mythic Relic Cache", Kind: "Cache", Rarity: "Mythic", Currency: "Cores", Price: 25, Stock: 1, Weight: 0.6 },
	{ Id: "SkinCrystal", Kind: "Skin", SkinId: "Crystal", Stock: 1, Weight: 1.2 },
	{ Id: "SkinFrost", Kind: "Skin", SkinId: "Frost", Stock: 1, Weight: 1.2 },
	{ Id: "SkinMolten", Kind: "Skin", SkinId: "Molten", Stock: 1, Weight: 0.9 },
	{ Id: "SkinNebula", Kind: "Skin", SkinId: "Nebula", Stock: 1, Weight: 0.9 },
	{ Id: "SkinVoid", Kind: "Skin", SkinId: "Void", Stock: 1, Weight: 0.5 },
	{ Id: "SkinGilded", Kind: "Skin", SkinId: "Gilded", Stock: 1, Weight: 0.5 },
	{ Id: "SkinCelestial", Kind: "Skin", SkinId: "Celestial", Stock: 1, Weight: 0.25 },
]);

function generator(seed: number): () => number {
	let state = math.floor(seed) % 4294967296;
	if (state === 0) {
		state = 2463534242;
	}
	return () => {
		state = bit32.bxor(state, bit32.lshift(state, 13));
		state = bit32.bxor(state, bit32.rshift(state, 17));
		state = bit32.bxor(state, bit32.lshift(state, 5));
		return state / 4294967296;
	};
}

function day(now: number): number {
	return math.floor(now / DAY_SECONDS);
}

function secondsLeft(now: number): number {
	return DAY_SECONDS - (now % DAY_SECONDS);
}

function basePrice(entry: PoolEntry): LuaTuple<[string, number]> {
	if (entry.Kind === "Skin") {
		const s = skinById[entry.SkinId!]!;
		return $tuple(s.Price!.Currency, s.Price!.Amount);
	}
	return $tuple(entry.Currency!, entry.Price!);
}

function roll(userId: number, dayIndex: number, ownedSkins?: unknown): Offer[] {
	const random = generator(
		((math.abs(math.floor(userId)) % 1000003) * 7919 + math.floor(dayIndex) * 104729) % 4294967296,
	);
	for (let i = 1; i <= 4; i++) {
		random();
	}
	const remaining: PoolEntry[] = [];
	for (const entry of POOL) {
		const owned =
			entry.Kind === "Skin" && typeIs(ownedSkins, "table") && (ownedSkins as Dict)[entry.SkinId!] === true;
		if (!owned) {
			remaining.push(entry);
		}
	}
	const offers: Offer[] = [];
	while (offers.size() < SLOTS && remaining.size() > 0) {
		let total = 0;
		for (const entry of remaining) {
			total += entry.Weight;
		}
		let pick = random() * total;
		let chosen = remaining.size() - 1;
		for (let index = 0; index < remaining.size(); index++) {
			pick -= remaining[index].Weight;
			if (pick <= 0) {
				chosen = index;
				break;
			}
		}
		const entry = remaining.remove(chosen)!;
		const slot = offers.size() + 1;
		let [currency, price] = basePrice(entry);
		const deal = slot === 1;
		if (deal) {
			price = math.max(1, math.floor(price * (1 - DEAL_DISCOUNT) + 0.5));
		}
		const offer = table.clone(entry) as Offer;
		offer.Slot = slot;
		offer.Currency = currency;
		offer.Price = price;
		offer.Deal = deal;
		offer.Name = entry.Name ?? (entry.Kind === "Skin" ? skinById[entry.SkinId!]!.Name + " Skin" : undefined) ?? entry.Id;
		offers.push(offer);
	}
	return offers;
}

function remainingStock(offer: { Slot: number; Stock?: number }, bought: unknown): number {
	const used = typeIs(bought, "table") ? (tonumber((bought as Dict)[tostring(offer.Slot)]) ?? 0) : 0;
	return math.max(0, (offer.Stock ?? 1) - math.max(0, math.floor(used)));
}

export = table.freeze({
	SLOTS,
	DEAL_DISCOUNT,
	DAY_SECONDS,
	SKINS,
	EARNED_SKINS,
	skin,
	DEFAULT_SKIN,
	POOL,
	day,
	secondsLeft,
	roll,
	remaining: remainingStock,
});
