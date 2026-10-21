import { T } from "../../../Shared/AstralForge/Shared/Locale";
interface MarketOrder {
	Game: string;
	Pick: string;
	Bucket: number;
	Quantity: number;
	UnitPrice: number | string;
	Currency: string;
	RequestId: string;
	Rotation: string;
}

interface CatalogEntry {
	Id: string;
	Name: string;
	Reward: Record<string, unknown>;
	Seconds: number;
}

function hash01(n: number): number {
	const x = math.sin(n * 12.9898 + 78.233) * 43758.5453;
	return x - math.floor(x);
}

// Luau `if value then` is true for 0 and "". A bare TS test is lowered to `~= 0 and ~= ""`.
function present(value: unknown): boolean {
	return value !== undefined && value !== false;
}

function count(value: unknown, ceiling?: number): number {
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge) {
		return 0;
	}
	return math.clamp(math.floor(n), 0, ceiling ?? 1e9);
}

function persist(value: unknown): number | string {
	const numericMatch = typeIs(value, "string") ? string.match(value, "^[%d%.eE%+]+$")[0] : undefined;
	if (
		typeIs(value, "string") &&
		value.size() <= 40 &&
		(value === "inf" || (numericMatch !== undefined && tonumber(value) !== undefined))
	) {
		return value;
	}
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge || n < 0) {
		return 0;
	}
	return n;
}

const BazaarMath = {
	BANK: table.freeze({
		SavingsRate: 0.03,
		CapSeconds: 7200,
		MaxAccrualHours: 24,
		Terms: table.freeze([
			table.freeze({ Id: "T1", Hours: 1, Rate: 0.04 }),
			table.freeze({ Id: "T6", Hours: 6, Rate: 0.05 }),
			table.freeze({ Id: "T24", Hours: 24, Rate: 0.06 }),
		]),
	}),

	MARKET_SECONDS: 3600,
	MARKET_OFFERS: 24,
	RECEIPT_BUCKETS: 2,

	TermById(this: void, id: unknown): unknown {
		for (const term of BazaarMath.BANK.Terms) {
			if (term.Id === id) {
				return term;
			}
		}
		return undefined;
	},

	AccrualHours(this: void, elapsed: number): number {
		return math.clamp(elapsed / 3600, 0, BazaarMath.BANK.MaxAccrualHours);
	},

	ValidQuote(this: void, value: unknown): boolean {
		if (typeIs(value, "number")) {
			return value === value && value > 0 && value < math.huge;
		}
		if (!typeIs(value, "string") || value.size() > 40) {
			return false;
		}
		const [mantissa, exponent] = string.match(value, "^(%d*%.?%d+)[eE]([%+%-]?%d+)$");
		if (mantissa !== undefined && exponent !== undefined) {
			const m = tonumber(mantissa);
			const e = tonumber(exponent);
			return m !== undefined && m > 0 && m < math.huge && e !== undefined && math.abs(e) < 1e18;
		}
		const [plainMatch] = string.match(value, "^%d*%.?%d+$");
		if (plainMatch === undefined) {
			return false;
		}
		const parsed = tonumber(value);
		return parsed !== undefined && parsed > 0 && parsed < math.huge;
	},

	ReadOrder(this: void, payload: unknown): LuaTuple<[MarketOrder | undefined, string | undefined]> {
		if (!typeIs(payload, "table") || (payload as Record<string, unknown>).Game !== "Market") {
			return $tuple(undefined, T("BazaarMath.OnlyTheBlackMarketIs"));
		}
		const bag = payload as Record<string, unknown>;
		if (!typeIs(bag.Pick, "string") || bag.Pick.size() < 2 || bag.Pick.size() > 24) {
			return $tuple(undefined, T("BazaarMath.ChooseAListedSupply"));
		}
		if (
			!typeIs(bag.Bucket, "number") ||
			bag.Bucket !== bag.Bucket ||
			bag.Bucket < 0 ||
			bag.Bucket > 1e12 ||
			bag.Bucket % 1 !== 0
		) {
			return $tuple(undefined, T("BazaarMath.ReviewTheShipmentBeforeBuying"));
		}
		if (
			!typeIs(bag.Quantity, "number") ||
			bag.Quantity !== bag.Quantity ||
			bag.Quantity % 1 !== 0 ||
			bag.Quantity < 1 ||
			bag.Quantity > 8
		) {
			return $tuple(undefined, T("BazaarMath.ChooseBetween1And8"));
		}
		if (!typeIs(bag.RequestId, "string") || bag.RequestId.size() < 8 || bag.RequestId.size() > 64) {
			return $tuple(undefined, T("BazaarMath.TheOrderNeedsAValid"));
		}
		if (bag.Currency !== "Flux" || !BazaarMath.ValidQuote(bag.UnitPrice)) {
			return $tuple(undefined, T("BazaarMath.ReviewTheOrderSCurrency"));
		}
		if (!typeIs(bag.Rotation, "string") || bag.Rotation.size() < 3 || bag.Rotation.size() > 64) {
			return $tuple(undefined, T("BazaarMath.RefreshTheShipmentBeforeBuying"));
		}
		return $tuple(
			{
				Game: "Market",
				Pick: bag.Pick,
				Bucket: bag.Bucket,
				Quantity: bag.Quantity,
				UnitPrice: bag.UnitPrice as number | string,
				Currency: "Flux",
				RequestId: bag.RequestId,
				Rotation: bag.Rotation,
			},
			undefined,
		);
	},

	CATALOG: table.freeze([
		table.freeze({ Id: "overdrive", Name: "Overdrive Cell", Reward: table.freeze({ Boost: "Overdrive" }), Seconds: 2400 }),
		table.freeze({ Id: "vaultsurge", Name: "Vault Surge Cell", Reward: table.freeze({ Boost: "VaultSurge" }), Seconds: 2400 }),
		table.freeze({ Id: "hyperdrive", Name: "Hyperdrive Cell", Reward: table.freeze({ Boost: "Hyperdrive" }), Seconds: 4200 }),
		table.freeze({ Id: "domainsurge", Name: "Domain Surge Cell", Reward: table.freeze({ Boost: "DomainSurge" }), Seconds: 5400 }),
		table.freeze({ Id: "stardust", Name: "Stardust Pouch", Reward: table.freeze({ Stardust: 40 }), Seconds: 6000 }),
		table.freeze({ Id: "stardustbig", Name: "Stardust Crate", Reward: table.freeze({ Stardust: 150 }), Seconds: 20000 }),
		table.freeze({ Id: "core", Name: "Loose Core", Reward: table.freeze({ Cores: 1 }), Seconds: 9000 }),
		table.freeze({ Id: "spins", Name: "Wheel Tokens", Reward: table.freeze({ FreeSpins: 3 }), Seconds: 3600 }),
		table.freeze({ Id: "keys", Name: "Forge Keys", Reward: table.freeze({ Keys: table.freeze({ ForgeCrate: 3 }) }), Seconds: 3000 }),
		table.freeze({ Id: "essence", Name: "Domain Essence", Reward: table.freeze({ Essence: 6 }), Seconds: 7000 }),
		table.freeze({ Id: "signals", Name: "Signal Burst", Reward: table.freeze({ Signals: 25 }), Seconds: 3200 }),
		table.freeze({ Id: "shield", Name: "Streak Shield", Reward: table.freeze({ StreakShield: 1 }), Seconds: 2800 }),
		table.freeze({ Id: "dustsmall", Name: "Pocket Stardust", Reward: table.freeze({ Stardust: 12 }), Seconds: 1800 }),
		table.freeze({ Id: "dustbulk", Name: "Stardust Shipment", Reward: table.freeze({ Stardust: 300 }), Seconds: 40000 }),
		table.freeze({ Id: "corepair", Name: "Core Pair", Reward: table.freeze({ Cores: 2 }), Seconds: 18000 }),
		table.freeze({ Id: "corecase", Name: "Core Case", Reward: table.freeze({ Cores: 5 }), Seconds: 45000 }),
		table.freeze({ Id: "essencebag", Name: "Essence Satchel", Reward: table.freeze({ Essence: 15 }), Seconds: 17500 }),
		table.freeze({ Id: "essencecase", Name: "Essence Shipment", Reward: table.freeze({ Essence: 40 }), Seconds: 46500 }),
		table.freeze({ Id: "fragmentbag", Name: "Anomaly Fragments", Reward: table.freeze({ Fragments: 5 }), Seconds: 6000 }),
		table.freeze({ Id: "fragmentcase", Name: "Fragment Crate", Reward: table.freeze({ Fragments: 20 }), Seconds: 24000 }),
		table.freeze({ Id: "crystalkeys", Name: "Crystal Keys", Reward: table.freeze({ Keys: table.freeze({ CrystalCrate: 2 }) }), Seconds: 6000 }),
		table.freeze({ Id: "nebulakey", Name: "Nebula Key", Reward: table.freeze({ Keys: table.freeze({ NebulaCrate: 1 }) }), Seconds: 7000 }),
		table.freeze({ Id: "orbitkeys", Name: "Orbit Keys", Reward: table.freeze({ Keys: table.freeze({ OrbitCrate: 2 }) }), Seconds: 9000 }),
		table.freeze({ Id: "aetherkey", Name: "Aether Key", Reward: table.freeze({ Keys: table.freeze({ AetherCrate: 1 }) }), Seconds: 7500 }),
		table.freeze({ Id: "horizonkey", Name: "Horizon Key", Reward: table.freeze({ Keys: table.freeze({ HorizonCrate: 1 }) }), Seconds: 10000 }),
		table.freeze({ Id: "singularitykey", Name: "Singularity Key", Reward: table.freeze({ Keys: table.freeze({ SingularityCrate: 1 }) }), Seconds: 30000 }),
		table.freeze({ Id: "echokey", Name: "Echo Key", Reward: table.freeze({ Keys: table.freeze({ EchoCrate: 1 }) }), Seconds: 35000 }),
		table.freeze({ Id: "driftkey", Name: "Drift Key", Reward: table.freeze({ Keys: table.freeze({ DriftCrate: 1 }) }), Seconds: 30000 }),
		table.freeze({ Id: "signalpack", Name: "Signal Bundle", Reward: table.freeze({ Signals: 75 }), Seconds: 9600 }),
		table.freeze({ Id: "signalcase", Name: "Signal Shipment", Reward: table.freeze({ Signals: 200 }), Seconds: 25600 }),
		table.freeze({ Id: "commandnotes", Name: "Command Field Notes", Reward: table.freeze({ CommandXP: 50 }), Seconds: 6000 }),
		table.freeze({ Id: "commandcharts", Name: "Command Survey Log", Reward: table.freeze({ CommandXP: 150 }), Seconds: 18000 }),
		table.freeze({ Id: "shieldpair", Name: "Spare Streak Shields", Reward: table.freeze({ StreakShield: 2 }), Seconds: 5600 }),
		table.freeze({ Id: "spinsingle", Name: "Wheel Token", Reward: table.freeze({ FreeSpins: 1 }), Seconds: 1200 }),
		table.freeze({ Id: "spincase", Name: "Wheel Token Case", Reward: table.freeze({ FreeSpins: 6 }), Seconds: 7200 }),
		table.freeze({ Id: "forgekit", Name: "Forge Supply Kit", Reward: table.freeze({ Stardust: 20, Keys: table.freeze({ ForgeCrate: 2 }) }), Seconds: 5000 }),
	]),

	Category(this: void, reward: Record<string, unknown>): string {
		if (present(reward.Keys)) {
			return "Keys";
		}
		if (present(reward.Boost)) {
			return "Boosts";
		}
		if (present(reward.Signals) || present(reward.CommandXP) || present(reward.StreakShield)) {
			return "Command";
		}
		if (present(reward.FreeSpins)) {
			return "Tokens";
		}
		return "Resources";
	},

	RARE: table.freeze([
		table.freeze({ Id: "rare_vaultcache", Name: "Sealed Vault Cache", Reward: table.freeze({ Cores: 6, Stardust: 120 }), Seconds: 60000 }),
		table.freeze({ Id: "rare_keyring", Name: "Singularity Key Ring", Reward: table.freeze({ Keys: table.freeze({ SingularityCrate: 2 }) }), Seconds: 52000 }),
		table.freeze({ Id: "rare_ledger", Name: "Quartermaster Ledger", Reward: table.freeze({ CommandXP: 400, Signals: 150 }), Seconds: 40000 }),
		table.freeze({ Id: "rare_essence", Name: "Pressurised Essence", Reward: table.freeze({ Essence: 90 }), Seconds: 90000 }),
		table.freeze({ Id: "rare_tokencrate", Name: "Wheel Token Crate", Reward: table.freeze({ FreeSpins: 12 }), Seconds: 13000 }),
		table.freeze({ Id: "rare_fragments", Name: "Anomaly Strongbox", Reward: table.freeze({ Fragments: 60 }), Seconds: 66000 }),
	]),
	RARE_CHANCE: 0.45,
	RARE_DISCOUNT: 0.15,

	MERCHANTS: table.freeze([
		table.freeze({ Id: "vess", Name: T("BazaarMath.VessCalder"), Title: T("BazaarMath.SalvageBroker"), Favors: "Resources", Accent: table.freeze([214, 160, 96]),
			Line: "Everything on this table came off a wreck. None of it is sentimental." }),
		table.freeze({ Id: "orrin", Name: T("BazaarMath.OrrinHale"), Title: T("BazaarMath.KeyCutter"), Favors: "Keys", Accent: table.freeze([150, 190, 230]),
			Line: "Bring me a lock and I'll tell you what it's hiding. Bring Flux and I'll skip the story." }),
		table.freeze({ Id: "sable", Name: T("BazaarMath.SableRook"), Title: T("BazaarMath.SignalRunner"), Favors: "Command", Accent: table.freeze([176, 140, 220]),
			Line: "Quiet channels usually cost extra. This hour, they don't." }),
		table.freeze({ Id: "tamsin", Name: T("BazaarMath.TamsinFerro"), Title: T("BazaarMath.EngineFixer"), Favors: "Boosts", Accent: table.freeze([230, 120, 90]),
			Line: "Runs hot, runs fast. Don't ask where the cells were before me." }),
		table.freeze({ Id: "pell", Name: T("BazaarMath.PellMorrow"), Title: T("BazaarMath.TokenDealer"), Favors: "Tokens", Accent: table.freeze([225, 140, 180]),
			Line: "Spin it yourself. I only sell the chances." }),
	]),

	REPUTATION: table.freeze([
		table.freeze({ Name: "Stranger", At: 0, Bonus: 0 }),
		table.freeze({ Name: "Regular", At: 10, Bonus: 1 }),
		table.freeze({ Name: "Trusted", At: 40, Bonus: 2 }),
		table.freeze({ Name: "Insider", At: 120, Bonus: 3 }),
	]),
	PROCURE_TIER: 2,
	PROCURE_BUCKETS: 24,
	PROCURE_DISCOUNT: 0.2,
	PROCURE_STOCK: 2,

	Reputation(this: void, units: unknown): LuaTuple<[unknown, number, unknown]> {
		const n = tonumber(units) ?? 0;
		let index = 1;
		for (const [i, tier] of ipairs(BazaarMath.REPUTATION)) {
			if (n >= tier.At) {
				index = i;
			}
		}
		return $tuple(BazaarMath.REPUTATION[index - 1], index, BazaarMath.REPUTATION[index]);
	},

	CatalogById(this: void, id: unknown): unknown {
		for (const entry of BazaarMath.CATALOG) {
			if (entry.Id === id) {
				return entry;
			}
		}
		for (const entry of BazaarMath.RARE) {
			if (entry.Id === id) {
				return entry;
			}
		}
		return undefined;
	},

	RegularById(this: void, id: unknown): unknown {
		for (const entry of BazaarMath.CATALOG) {
			if (entry.Id === id) {
				return entry;
			}
		}
		return undefined;
	},

	Holdings(this: void, profile: unknown, reward: Record<string, unknown>): unknown[] {
		const bag = profile as Record<string, unknown>;
		const rows: defined[] = [];
		const add = (label: string, amount: unknown): void => {
			rows.push({ Label: label, Count: amount ?? 0 });
		};
		const command = bag.Command as Record<string, unknown> | undefined;
		const items = bag.Items as Record<string, unknown> | undefined;
		const keys = items?.Keys as Record<string, unknown> | undefined;
		if (present(reward.Stardust)) {
			add("Stardust", bag.Stardust);
		}
		if (present(reward.Cores)) {
			add("Cores", bag.Cores);
		}
		if (present(reward.Essence)) {
			add("Domain essence", (bag.Domain as Record<string, unknown> | undefined)?.Essence);
		}
		if (present(reward.Fragments)) {
			add("Anomaly fragments", (bag.Anomaly as Record<string, unknown> | undefined)?.Fragments);
		}
		if (present(reward.FreeSpins)) {
			add("Wheel tokens", (bag.Wheel as Record<string, unknown> | undefined)?.FreeSpins);
		}
		if (present(reward.Signals)) {
			add("Signals", command?.Signals);
		}
		if (present(reward.CommandXP)) {
			add("Command XP", command?.XP);
		}
		if (present(reward.StreakShield)) {
			add("Streak shields", command?.StreakShields);
		}
		if (present(reward.Boost)) {
			add("Stored boost cells", (bag.BoostInventory as Record<string, unknown> | undefined)?.[reward.Boost as string]);
		}
		if (present(reward.Keys)) {
			for (const [crate] of pairs(reward.Keys as object)) {
				const [stripped] = string.gsub(crate as string, "Crate$", "");
				add(`${stripped} keys`, keys?.[crate as string]);
			}
		}
		return rows;
	},

	MarketBucket(this: void, now: number): number {
		return math.floor(now / BazaarMath.MARKET_SECONDS);
	},

	Offers(this: void, bucket: number, limit?: number): unknown[] {
		const pool: number[] = [];
		for (const index of $range(1, BazaarMath.CATALOG.size())) {
			pool.push(index);
		}
		for (let i = pool.size(); i >= 2; i--) {
			const j = math.floor(hash01(bucket * 31 + i) * i) + 1;
			const tmp = pool[i - 1];
			pool[i - 1] = pool[j - 1];
			pool[j - 1] = tmp;
		}
		const offers: defined[] = [];
		for (const slot of $range(1, math.min(limit ?? BazaarMath.MARKET_OFFERS, pool.size()))) {
			const entry = BazaarMath.CATALOG[pool[slot - 1] - 1];
			offers.push({
				Id: entry.Id,
				Name: entry.Name,
				Reward: entry.Reward,
				Category: BazaarMath.Category(entry.Reward as Record<string, unknown>),
				Seconds: entry.Seconds,
				Discount: 0.2 + 0.25 * hash01(bucket * 17 + slot),
				Stock: 2 + math.floor(hash01(bucket * 53 + slot) * 7),
			});
		}
		return offers;
	},

	OfferById(this: void, bucket: number, id: unknown, limit?: number): unknown {
		for (const offer of BazaarMath.Offers(bucket, limit) as Record<string, unknown>[]) {
			if (offer.Id === id) {
				return offer;
			}
		}
		return undefined;
	},

	Merchant(this: void, bucket: number): unknown {
		return BazaarMath.MERCHANTS[math.floor(hash01(bucket * 7 + 11) * BazaarMath.MERCHANTS.size())];
	},

	RareOffer(this: void, bucket: number): unknown {
		if (hash01(bucket * 13 + 5) >= BazaarMath.RARE_CHANCE) {
			return undefined;
		}
		const entry = BazaarMath.RARE[math.floor(hash01(bucket * 29 + 3) * BazaarMath.RARE.size())];
		return {
			Id: entry.Id,
			Name: entry.Name,
			Reward: entry.Reward,
			Category: "Rare",
			Seconds: entry.Seconds,
			Discount: BazaarMath.RARE_DISCOUNT,
			Stock: 1,
			Rare: true,
		};
	},

	ProcuredOffer(this: void, procure: unknown, bucket: number, regular: unknown[]): unknown {
		if (!typeIs(procure, "table")) {
			return undefined;
		}
		const bag = procure as { Id?: unknown; Since: number; Filled: number };
		if (!typeIs(bag.Id, "string") || bag.Id === "") {
			return undefined;
		}
		if (bucket <= bag.Since || bucket > bag.Since + BazaarMath.PROCURE_BUCKETS) {
			return undefined;
		}
		if (bag.Filled > 0 && bag.Filled !== bucket) {
			return undefined;
		}
		for (const offer of regular as Record<string, unknown>[]) {
			if (offer.Id === bag.Id) {
				return undefined;
			}
		}
		const entry = BazaarMath.RegularById(bag.Id) as CatalogEntry | undefined;
		if (!entry) {
			return undefined;
		}
		return {
			Id: entry.Id,
			Name: entry.Name,
			Reward: entry.Reward,
			Category: BazaarMath.Category(entry.Reward as Record<string, unknown>),
			Seconds: entry.Seconds,
			Discount: BazaarMath.PROCURE_DISCOUNT,
			Stock: BazaarMath.PROCURE_STOCK,
			Procured: true,
		};
	},

	LOTTERY_SECONDS: 300,
	LOTTERY_RAKE: 0.1,
	LOTTERY_MAX_TICKETS: 20,

	LOTTERY_TICKET_SHARE: 0.01,

	LotteryDraw(this: void, tickets: Record<number, number>, roll: number): number | undefined {
		let total = 0;
		const ids: number[] = [];
		for (const [userId, amount] of pairs(tickets)) {
			if (amount > 0) {
				total += amount;
				ids.push(userId);
			}
		}
		if (total <= 0) {
			return undefined;
		}
		ids.sort((a, b) => a < b);
		let target = math.clamp(roll, 0, 0.9999999) * total;
		for (const userId of ids) {
			target -= tickets[userId];
			if (target < 0) {
				return userId;
			}
		}
		return ids[ids.size() - 1];
	},

	LotteryBucket(this: void, now: number): number {
		return math.floor(now / BazaarMath.LOTTERY_SECONDS);
	},

	CONTRACTS: table.freeze([
		table.freeze({ Id: "deals", Name: "Haggler", Text: "Buy black market deals", Counter: "Deals", Target: 2, Reward: table.freeze({ CashMinutes: 12, Stardust: 8 }) }),
		table.freeze({ Id: "deposits", Name: "Saver", Text: "Make bank deposits", Counter: "Deposits", Target: 2, Reward: table.freeze({ CashMinutes: 6, Stardust: 5 }) }),
		table.freeze({ Id: "tickets", Name: "Gambler", Text: "Buy lottery tickets", Counter: "Tickets", Target: 5, Reward: table.freeze({ CashMinutes: 8, FreeSpins: 1 }) }),
		table.freeze({ Id: "interest", Name: "Collector", Text: "Collect bank interest", Counter: "Interest", Target: 3, Reward: table.freeze({ CashMinutes: 7, Stardust: 6 }) }),
	]),
	CONTRACTS_PER_DAY: 3,
	COUNTERS: table.freeze(["Deals", "Deposits", "Tickets", "Interest"]),

	ContractsFor(this: void, day: number, userId: number): unknown[] {
		const pool: number[] = [];
		for (const index of $range(1, BazaarMath.CONTRACTS.size())) {
			pool.push(index);
		}
		for (let i = pool.size(); i >= 2; i--) {
			const j = math.floor(hash01(day * 19 + userId * 0.37 + i) * i) + 1;
			const tmp = pool[i - 1];
			pool[i - 1] = pool[j - 1];
			pool[j - 1] = tmp;
		}
		const list: defined[] = [];
		for (const slot of $range(1, BazaarMath.CONTRACTS_PER_DAY)) {
			list.push(BazaarMath.CONTRACTS[pool[slot - 1] - 1]);
		}
		return list;
	},

	ContractById(this: void, id: unknown): unknown {
		for (const contract of BazaarMath.CONTRACTS) {
			if (contract.Id === id) {
				return contract;
			}
		}
		return undefined;
	},

	Ensure(this: void, bag: unknown): unknown {
		const source = (typeIs(bag, "table") ? bag : {}) as Record<string, unknown>;
		const bank = (typeIs(source.Bank, "table") ? source.Bank : {}) as Record<string, unknown>;
		const term = (typeIs(bank.Term, "table") ? bank.Term : {}) as Record<string, unknown>;
		const market = (typeIs(source.Market, "table") ? source.Market : {}) as Record<string, unknown>;
		const contracts = (typeIs(source.Contracts, "table") ? source.Contracts : {}) as Record<string, unknown>;
		const counters = (typeIs(source.Counters, "table") ? source.Counters : {}) as Record<string, unknown>;
		const procure = (typeIs(market.Procure, "table") ? market.Procure : {}) as Record<string, unknown>;
		const bought: Record<string, number> = {};
		if (typeIs(market.Bought, "table")) {
			for (const [id, amount] of pairs(market.Bought as object)) {
				if (typeIs(id, "string") && id.size() <= 24) {
					bought[id] = count(amount, 20);
				}
			}
		}
		const baseline: Record<string, number> = {};
		const claimed: Record<string, boolean> = {};
		const saved: Record<string, boolean> = {};
		const history: defined[] = [];
		if (typeIs(market.Saved, "table")) {
			for (const [id, selected] of pairs(market.Saved as object)) {
				if (selected === true && BazaarMath.CatalogById(id) !== undefined) {
					saved[id as string] = true;
				}
			}
		}
		if (typeIs(market.History, "table")) {
			for (const [, entry] of ipairs(market.History as unknown[])) {
				if (history.size() >= 50) {
					break;
				}
				if (
					typeIs(entry, "table") &&
					BazaarMath.CatalogById((entry as Record<string, unknown>).Pick) !== undefined &&
					typeIs((entry as Record<string, unknown>).RequestId, "string") &&
					((entry as Record<string, unknown>).RequestId as string).size() >= 8 &&
					((entry as Record<string, unknown>).RequestId as string).size() <= 64 &&
					count((entry as Record<string, unknown>).Quantity, 8) >= 1
				) {
					const row = entry as Record<string, unknown>;
					history.push({
						RequestId: row.RequestId,
						Pick: row.Pick,
						Quantity: count(row.Quantity, 8),
						Cost: persist(row.Cost),
						At: count(row.At, 1e12),
					});
				}
			}
		}
		const receipts: Record<string, unknown> = {};
		if (typeIs(market.Receipts, "table")) {
			const marketReceipts = market.Receipts as Record<string, unknown>;
			const ids: string[] = [];
			for (const [id, receipt] of pairs(marketReceipts)) {
				if (typeIs(id, "string") && typeIs(receipt, "table")) {
					ids.push(id);
				}
			}
			ids.sort((a, b) => {
				const left = count(
					(marketReceipts[a] as Record<string, unknown>).Bucket ?? market.Bucket,
					1e12,
				);
				const right = count(
					(marketReceipts[b] as Record<string, unknown>).Bucket ?? market.Bucket,
					1e12,
				);
				return left === right ? a < b : left > right;
			});
			let length = 0;
			for (const id of ids) {
				if (length >= BazaarMath.CATALOG.size() * 8 * BazaarMath.RECEIPT_BUCKETS) {
					break;
				}
				const receipt = marketReceipts[id];
				if (
					typeIs(id, "string") &&
					id.size() >= 8 &&
					id.size() <= 64 &&
					typeIs(receipt, "table") &&
					typeIs((receipt as Record<string, unknown>).Pick, "string") &&
					((receipt as Record<string, unknown>).Pick as string).size() <= 24 &&
					typeIs((receipt as Record<string, unknown>).Message, "string") &&
					count((receipt as Record<string, unknown>).Quantity, 8) >= 1
				) {
					const row = receipt as Record<string, unknown>;
					receipts[id] = {
						Pick: row.Pick,
						Quantity: count(row.Quantity, 8),
						Cost: persist(row.Cost),
						Left: count(row.Left, 12),
						Message: string.sub(row.Message as string, 1, 512),
						Bucket: count(row.Bucket ?? market.Bucket, 1e12),
						Rotation: typeIs(row.Rotation, "string")
							? string.sub(row.Rotation as string, 1, 64)
							: "",
					};
					length += 1;
				}
			}
		}
		if (typeIs(contracts.Baseline, "table")) {
			const savedBaseline = contracts.Baseline as Record<string, unknown>;
			for (const name of BazaarMath.COUNTERS) {
				baseline[name] = count(savedBaseline[name]);
			}
		}
		if (typeIs(contracts.Claimed, "table")) {
			for (const [id] of pairs(contracts.Claimed as object)) {
				if (BazaarMath.ContractById(id) !== undefined) {
					claimed[id as string] = true;
				}
			}
		}
		const clean: Record<string, number> = {};
		for (const name of BazaarMath.COUNTERS) {
			clean[name] = count(counters[name]);
		}
		return {
			Bank: {
				Balance: persist(bank.Balance),
				Accrued: persist(bank.Accrued),
				Since: math.floor(tonumber(bank.Since) ?? 0),
				Term: {
					Id: BazaarMath.TermById(term.Id) !== undefined ? term.Id : "",
					Principal: persist(term.Principal),
					EndsAt: math.floor(tonumber(term.EndsAt) ?? 0),
				},
			},
			Market: {
				Bucket: math.floor(tonumber(market.Bucket) ?? -1),
				Bought: bought,
				Refunded: persist(market.Refunded),
				RefundedRolloverAt: count(market.RefundedRolloverAt, 1e12),
				RefundedTicketsAt: count(market.RefundedTicketsAt, 1e12),
				Receipts: receipts,
				Saved: saved,
				History: history,
				Procure: {
					Id:
						typeIs(procure.Id, "string") && BazaarMath.RegularById(procure.Id) !== undefined
							? procure.Id
							: "",
					Since: count(procure.Since, 1e12),
					Filled: count(procure.Filled, 1e12),
				},
			},
			Lottery: {
				PendingPrize: persist(
					typeIs(source.Lottery, "table")
						? (source.Lottery as Record<string, unknown>).PendingPrize
						: 0,
				),
			},
			Contracts: {
				Day: math.floor(tonumber(contracts.Day) ?? -1),
				Baseline: baseline,
				Claimed: claimed,
				Retired: contracts.Retired === true,
			},
			Counters: clean,
		};
	},
};

export = table.freeze(BazaarMath);
