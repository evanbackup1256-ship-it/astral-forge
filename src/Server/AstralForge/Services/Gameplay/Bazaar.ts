import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import ProgressionModule = require("./Progression");
import { Dict, EconomyApi, economyKit, Flux, ModuleLogApi, num, req, truthy } from "../LuaInterop";

interface Offer {
	Id: string;
	Name: string;
	Category: string;
	Reward: Dict & { Essence?: number };
	Discount: number;
	Seconds: number;
	Stock: number;
	Rare?: boolean;
	Procured?: boolean;
}

interface Tier {
	Name: string;
	Bonus: number;
	At: number;
}

interface Receipt {
	Pick: string;
	Quantity: number;
	Left: number;
	Cost: Flux;
	Message: string;
	Bucket: number;
	Rotation: string;
}

interface Bag {
	Bank: { Balance: Flux; Accrued: Flux; Since: number; Term: { Id: string; Principal: Flux; EndsAt: number } };
	Lottery: { PendingPrize: Flux };
	Contracts: {
		Retired?: boolean;
		Day: number;
		Claimed: Record<string, boolean | undefined>;
		Baseline: Record<string, number | undefined>;
	};
	Counters: Record<string, number> & { Deals: number };
	Market: {
		RefundedTicketsAt: number;
		RefundedRolloverAt: number;
		Refunded: Flux;
		Bucket: number;
		Bought: Record<string, number | undefined>;
		Receipts: Record<string, Receipt | undefined>;
		History: Dict[];
		Procure: { Id: string; Since: number; Filled: number };
		Saved: Record<string, boolean | undefined>;
	};
}

interface Order {
	Quantity: number;
	RequestId: string;
	Pick: string;
	Bucket: number;
	Rotation: string;
	UnitPrice: Flux;
}

interface BazaarMathApi {
	MARKET_OFFERS: number;
	CATALOG: Array<{ Id: string; Name: string; Reward: Dict }>;
	LOTTERY_MAX_TICKETS: number;
	BANK: { CapSeconds: number; SavingsRate: number };
	RECEIPT_BUCKETS: number;
	PROCURE_TIER: number;
	PROCURE_BUCKETS: number;
	MARKET_SECONDS: number;
	REPUTATION: Array<{ Name: string }>;
	Ensure: (this: void, bag: unknown) => Bag;
	AccrualHours: (this: void, seconds: number) => number;
	TermById: (this: void, id: string) => { Rate: number; Hours: number } | undefined;
	ContractsFor: (this: void, day: number, userId: number) => Array<{ Id: string; Counter: string; Target: number; Reward: unknown }>;
	Reputation: (this: void, units: number) => LuaTuple<[Tier, number, Tier | undefined]>;
	Offers: (this: void, bucket: number, count: number) => Offer[];
	ProcuredOffer: (this: void, procure: unknown, bucket: number, offers: Offer[]) => Offer | undefined;
	RareOffer: (this: void, bucket: number) => Offer | undefined;
	ReadOrder: (this: void, payload: unknown) => LuaTuple<[Order | undefined, string | undefined]>;
	MarketBucket: (this: void, now: number) => number;
	RegularById: (this: void, id: unknown) => { Id: string; Name: string } | undefined;
	CatalogById: (this: void, id: unknown) => { Name: string } | undefined;
	Merchant: (this: void, bucket: number) => { Name: string; Title: string; Favors: string; Accent: unknown; Line: string };
	Holdings: (this: void, profile: unknown, reward: unknown) => unknown;
	Category: (this: void, reward: unknown) => string;
}

interface BazaarEconomy extends EconomyApi {
	Floor: (this: void, a: unknown) => Flux;
	SteadyProduction: (this: void, profile: unknown) => Flux;
	Gte: (this: void, a: unknown, b: unknown) => boolean;
	Persist: (this: void, a: unknown) => Flux;
}

interface ProgressionApi {
	ApplyReward: (this: void, profile: unknown, reward: unknown, production: Flux) => string;
}

interface BazaarProfile {
	Bazaar: unknown;
	Cash: Flux;
	Domain?: { Essence?: number };
	[key: string]: unknown;
}

interface Rollover {
	SavedAt?: unknown;
	Tickets?: unknown;
	Pot?: unknown;
	Pending?: unknown;
}

interface ConfigSnapshot {
	GetValue(key: string): unknown;
	Refresh(): void;
	UpdateAvailable: RBXScriptSignal;
}

interface DataStoreLike {
	GetAsync(key: string): unknown;
}

const StoreAccess = req<{ data: (this: void, name: string) => DataStoreLike }>(
	script.Parent!.Parent!.Parent!.WaitForChild("Modules").WaitForChild("StoreAccess"),
);

const Economy = economyKit("Economy") as BazaarEconomy;
const Math = req<BazaarMathApi>(script.Parent!.Parent!.Parent!.WaitForChild("Modules").WaitForChild("BazaarMath"));
const Log = req<ModuleLogApi>(script.Parent!.Parent!.Parent!.WaitForChild("ModuleLog"));
const Progression = ProgressionModule as unknown as ProgressionApi;
const Service = {} as {
	NeedsRecovery: (this: void, profile: BazaarProfile, userId: number) => boolean;
	Roll: (this: void, profile: BazaarProfile, now: number, userId: number) => LuaTuple<[boolean, string]>;
	Play: (
		this: void,
		profile: BazaarProfile,
		random: unknown,
		payload: unknown,
		now: number,
		userId: number,
	) => LuaTuple<[boolean, string | undefined, Dict?]>;
	Procure: (this: void, profile: BazaarProfile, payload: unknown, now: number) => LuaTuple<[boolean, string]>;
	SetFavorite: (this: void, profile: BazaarProfile, payload: unknown) => LuaTuple<[boolean, string]>;
	State: (this: void, profile: BazaarProfile, now: number, userId: number) => Dict;
};
let rollover: Rollover | undefined;
const offerCounts = new Map<number, number>();
let nextOfferCount = Math.MARKET_OFFERS;

task.defer(() => {
	const store = StoreAccess.data("AstralForgeBazaar");
	for (let attempt = 1; attempt <= 3; attempt++) {
		const [ok, saved] = pcall(() => store.GetAsync("AF_LotteryRollover_v1"));
		if (ok) {
			rollover = typeIs(saved, "table") ? (saved as Rollover) : undefined;
			return;
		}
		Log.Warn("BlackMarket", "Legacy prize recovery failed: " + tostring(saved));
		if (attempt < 3) {
			task.wait(attempt * 2);
		}
	}
});
task.defer(() => {
	let isStudio = false;
	pcall(() => {
		const rs = game.GetService("RunService");
		if (rs && typeIs((rs as unknown as { IsStudio?: unknown }).IsStudio, "function")) {
			isStudio = rs.IsStudio();
		}
	});
	if (isStudio) {
		return;
	}
	const [ok, result] = pcall(() =>
		(game.GetService("ConfigService" as keyof Services) as unknown as { GetConfigAsync(): ConfigSnapshot }).GetConfigAsync(),
	);
	if (!ok) {
		Log.Warn("BlackMarket", "Experience Config unavailable; using catalog defaults: " + tostring(result));
		return;
	}
	const snapshot = result as ConfigSnapshot;
	const read = () => {
		const value = snapshot.GetValue("BlackMarketOfferCount");
		if (value === undefined) {
			nextOfferCount = Math.MARKET_OFFERS;
			return;
		}
		if (
			!typeIs(value, "number") ||
			value !== value ||
			value < 12 ||
			value > Math.CATALOG.size() ||
			value % 1 !== 0
		) {
			Log.Warn("BlackMarket", "BlackMarketOfferCount must be an integer from 12 to " + Math.CATALOG.size());
			return;
		}
		nextOfferCount = value;
	};
	read();
	snapshot.UpdateAvailable.Connect(() => {
		const [refreshed, err] = pcall(() => snapshot.Refresh());
		if (refreshed) {
			read();
		} else {
			Log.Warn("BlackMarket", "Experience Config refresh failed: " + tostring(err));
		}
	});
});
const countFor = (bucket: number): number => {
	if (offerCounts.get(bucket) === undefined) {
		offerCounts.set(bucket, nextOfferCount);
		for (const [key] of offerCounts) {
			if (key < bucket - 1) {
				offerCounts.delete(key);
			}
		}
	}
	return offerCounts.get(bucket)!;
};
const ensure = (profile: BazaarProfile): Bag => {
	profile.Bazaar = Math.Ensure(profile.Bazaar);
	return profile.Bazaar as Bag;
};
const price = (profile: BazaarProfile, offer: Offer): Flux =>
	Economy.Max(1000, Economy.Floor(Economy.Mul(Economy.SteadyProduction(profile), offer.Seconds * (1 - offer.Discount))));
const rolloverAt = (): number | undefined => {
	const at = rollover ? num(rollover.SavedAt) : undefined;
	return at !== undefined && at === at && at > 0 && at < math.huge ? at : undefined;
};
const ticketShare = (userId: number): Flux => {
	if (!rollover || !typeIs(rollover.Tickets, "table")) {
		return 0;
	}
	let total = 0;
	let owned = 0;
	for (const [id, raw] of pairs(rollover.Tickets as Record<string, unknown>)) {
		const owner = num(id);
		const tickets = num(raw);
		if (
			owner !== undefined &&
			owner > 0 &&
			owner < math.huge &&
			owner % 1 === 0 &&
			tickets !== undefined &&
			tickets === tickets &&
			tickets > 0 &&
			tickets <= Math.LOTTERY_MAX_TICKETS &&
			tickets % 1 === 0
		) {
			total += tickets;
			if (owner === userId) {
				owned += tickets;
			}
		}
	}
	if (owned === 0 || total === 0) {
		return 0;
	}
	const pot = Math.Ensure({ Bank: { Balance: rollover.Pot } }).Bank.Balance;
	return Economy.Mul(pot, owned / total);
};
const pendingFor = (pending: Record<string | number, unknown>, userId: number): unknown => {
	const byNumber = pending[userId];
	return byNumber !== undefined && byNumber !== false ? byNumber : pending[tostring(userId)];
};
Service.NeedsRecovery = (profile, userId) => {
	const bag = Math.Ensure(profile.Bazaar);
	if (!bag.Contracts.Retired) {
		return true;
	}
	if (
		Economy.Gt(bag.Bank.Balance, 0) ||
		Economy.Gt(bag.Bank.Accrued, 0) ||
		Economy.Gt(bag.Bank.Term.Principal, 0) ||
		Economy.Gt(bag.Lottery.PendingPrize, 0)
	) {
		return true;
	}
	const savedAt = rolloverAt();
	if (savedAt === undefined) {
		return false;
	}
	if (savedAt > bag.Market.RefundedTicketsAt && Economy.Gt(ticketShare(userId), 0)) {
		return true;
	}
	if (!(rollover && typeIs(rollover.Pending, "table") && savedAt > bag.Market.RefundedRolloverAt)) {
		return false;
	}
	const pending = rollover.Pending as Record<string | number, unknown>;
	return pending[userId] !== undefined || pending[tostring(userId)] !== undefined;
};
Service.Roll = (profile, now, userId) => {
	const bag = ensure(profile);
	const bank = bag.Bank;
	const term = bag.Bank.Term;
	let interest: Flux = 0;
	if (bank.Since > 0 && Economy.Gt(bank.Balance, 0)) {
		const cap = Economy.Max(1000, Economy.Mul(Economy.SteadyProduction(profile), Math.BANK.CapSeconds));
		interest = Economy.Mul(Economy.Min(bank.Balance, cap), Math.BANK.SavingsRate * Math.AccrualHours(now - bank.Since));
	}
	let principal = term.Principal;
	const info = Math.TermById(term.Id);
	if (info && now >= term.EndsAt) {
		principal = Economy.Mul(principal, 1 + info.Rate * info.Hours);
	}
	let refund = Economy.Add(Economy.Add(bank.Balance, bank.Accrued), Economy.Add(interest, principal));
	refund = Economy.Add(refund, bag.Lottery.PendingPrize);
	const savedAt = rolloverAt();
	if (rollover && typeIs(rollover.Pending, "table") && savedAt !== undefined && savedAt > bag.Market.RefundedRolloverAt) {
		const pending = pendingFor(rollover.Pending as Record<string | number, unknown>, userId);
		if (pending !== undefined && pending !== false) {
			refund = Economy.Add(refund, Math.Ensure({ Lottery: { PendingPrize: pending } }).Lottery.PendingPrize);
		}
		bag.Market.RefundedRolloverAt = savedAt;
	}
	if (savedAt !== undefined && savedAt > bag.Market.RefundedTicketsAt) {
		refund = Economy.Add(refund, ticketShare(userId));
		bag.Market.RefundedTicketsAt = savedAt;
	}
	if (Economy.Gt(refund, 0)) {
		const credited = Economy.Add(profile.Cash, refund);
		// Above 1e15 Cash is an Omega value with a 12-digit mantissa, so a refund more than
		// 1e12 times smaller is absorbed without changing it. That is a settled claim, not a
		// balance that can't represent it (that is only the infinite case).
		const absorbed = Economy.Lt(profile.Cash, math.huge) && Economy.Gt(profile.Cash, Economy.Mul(refund, 1e12));
		if (!Economy.Gt(credited, profile.Cash) && !absorbed) {
			return $tuple(false, T("Bazaar.YourBalanceCannotRepresentThe"));
		}
		profile.Cash = credited;
		bag.Market.Refunded = Economy.Persist(Economy.Add(bag.Market.Refunded, refund));
	}
	if (!bag.Contracts.Retired) {
		if (bag.Contracts.Day >= 0) {
			for (const contract of Math.ContractsFor(bag.Contracts.Day, userId)) {
				if (
					!bag.Contracts.Claimed[contract.Id] &&
					bag.Counters[contract.Counter] - (bag.Contracts.Baseline[contract.Counter] ?? 0) >= contract.Target
				) {
					Progression.ApplyReward(profile, contract.Reward, Economy.SteadyProduction(profile));
					bag.Contracts.Claimed[contract.Id] = true;
				}
			}
		}
		bag.Contracts.Retired = true;
	}
	bag.Bank = Math.Ensure(undefined).Bank;
	bag.Lottery.PendingPrize = 0;
	return $tuple(true, T("Bazaar.RetiredBazaarBalancesAndEarned"));
};
const shelf = (bag: Bag, bucket: number): LuaTuple<[Offer[], Tier]> => {
	// Standing earned during a shipment only raises stock from the next shipment, so sold-out shelves stay sold out.
	let opening = bag.Counters.Deals;
	if (bag.Market.Bucket === bucket) {
		for (const [, count] of pairs(bag.Market.Bought)) {
			opening -= count;
		}
	}
	const [tier] = Math.Reputation(math.max(0, opening));
	const offers: Offer[] = [];
	for (const offer of Math.Offers(bucket, countFor(bucket))) {
		offer.Stock += tier.Bonus;
		offers.push(offer);
	}
	const procured = Math.ProcuredOffer(bag.Market.Procure, bucket, offers);
	if (procured) {
		procured.Stock += tier.Bonus;
		offers.push(procured);
	}
	const rare = Math.RareOffer(bucket);
	if (rare) {
		offers.push(rare);
	}
	return $tuple(offers, tier);
};
const shelfOffer = (bag: Bag, bucket: number, id: string): Offer | undefined => {
	const [offers] = shelf(bag, bucket);
	for (const offer of offers) {
		if (offer.Id === id) {
			return offer;
		}
	}
	return undefined;
};
Service.Play = (profile, _random, rawPayload, now, userId) => {
	const [order, validationError] = Math.ReadOrder(rawPayload);
	if (!order) {
		return $tuple(false, validationError);
	}
	const payload = order;
	const bucket = Math.MarketBucket(now);
	const quantity = payload.Quantity;
	const bag = ensure(profile);
	const market = bag.Market;
	const previous = market.Receipts[payload.RequestId];
	if (previous) {
		if (
			previous.Pick !== payload.Pick ||
			previous.Quantity !== quantity ||
			previous.Bucket !== payload.Bucket ||
			previous.Rotation !== payload.Rotation
		) {
			return $tuple(false, T("Bazaar.ThatRequestIDBelongsTo"));
		}
		if (previous.Bucket < bucket - Math.RECEIPT_BUCKETS + 1) {
			return $tuple(false, T("Bazaar.ThatOrderIsOutsideThe"));
		}
		return $tuple(true, previous.Message, {
			Game: "Market",
			Pick: previous.Pick,
			Quantity: previous.Quantity,
			Left: previous.Left,
			Cost: previous.Cost,
			Replayed: true,
		});
	}
	if (payload.Bucket !== bucket) {
		return $tuple(false, T("Bazaar.StockRefreshedReviewTheNew"));
	}
	const rotation = `${bucket}:${countFor(bucket)}`;
	if (payload.Rotation !== rotation) {
		return $tuple(false, T("Bazaar.ThisShipmentChangedRefreshStock"));
	}
	const offer = shelfOffer(bag, bucket, payload.Pick);
	if (!offer) {
		return $tuple(false, T("Bazaar.ThatShipmentIsNotOn"));
	}
	const bought = market.Bucket === bucket ? (market.Bought[offer.Id] ?? 0) : 0;
	if (bought + quantity > offer.Stock) {
		return $tuple(false, T("Bazaar.NotEnoughStockLeftFor"));
	}
	const unitPrice = price(profile, offer);
	if (!Economy.Gte(payload.UnitPrice, unitPrice) || !Economy.Gte(unitPrice, payload.UnitPrice)) {
		return $tuple(false, T("Bazaar.ThePriceChangedWithYour"));
	}
	const rewardEssence = offer.Reward.Essence;
	if (rewardEssence !== undefined) {
		const held = profile.Domain && profile.Domain.Essence !== undefined ? profile.Domain.Essence : 0;
		if (held + rewardEssence * quantity > 1_000_000) {
			return $tuple(false, T("Bazaar.YourEssenceStorageCannotHold"));
		}
	}
	const cost = Economy.Mul(unitPrice, quantity);
	if (!Economy.Gte(profile.Cash, cost)) {
		return $tuple(false, T("Bazaar.NotEnoughFluxForThat"));
	}
	if (market.Bucket !== bucket) {
		market.Bucket = bucket;
		market.Bought = {};
	}
	for (const [id, receipt] of pairs(market.Receipts)) {
		if (receipt.Bucket < bucket - Math.RECEIPT_BUCKETS + 1) {
			market.Receipts[id] = undefined;
		}
	}
	profile.Cash = Economy.Sub(profile.Cash, cost);
	let description: string | undefined;
	for (let i = 1; i <= quantity; i++) {
		description = Progression.ApplyReward(profile, offer.Reward, Economy.SteadyProduction(profile));
	}
	market.Bought[offer.Id] = bought + quantity;
	if (truthy(offer.Procured)) {
		market.Procure.Filled = bucket;
	}
	bag.Counters.Deals = math.min(1e9, bag.Counters.Deals + quantity);
	const message = `${quantity} × ${offer.Name}: ${description} per unit.`;
	market.Receipts[payload.RequestId] = {
		Pick: offer.Id,
		Quantity: quantity,
		Left: offer.Stock - bought - quantity,
		Cost: Economy.Persist(cost),
		Message: message,
		Bucket: bucket,
		Rotation: rotation,
	};
	market.History.unshift({
		RequestId: payload.RequestId,
		Pick: offer.Id,
		Quantity: quantity,
		Cost: Economy.Persist(cost),
		At: now,
	});
	if (market.History.size() > 50) {
		market.History.pop();
	}
	return $tuple(true, message, {
		Game: "Market",
		Pick: offer.Id,
		Quantity: quantity,
		Left: offer.Stock - bought - quantity,
		Cost: Economy.Persist(cost),
	});
};
Service.Procure = (profile, payload, now) => {
	if (!typeIs(payload, "table") || !typeIs((payload as Dict).Id, "string")) {
		return $tuple(false, T("Bazaar.ChooseASupplyToRequest"));
	}
	const id = (payload as Dict).Id as string;
	const bag = ensure(profile);
	const procure = bag.Market.Procure;
	if (id === "") {
		if (procure.Id === "") {
			return $tuple(false, T("Bazaar.ThereIsNoOpenRequest"));
		}
		bag.Market.Procure = { Id: "", Since: 0, Filled: 0 };
		return $tuple(true, T("Bazaar.SupplyRequestCancelled"));
	}
	const entry = Math.RegularById(id);
	if (!entry) {
		return $tuple(false, T("Bazaar.ThatSupplyCannotBeRequested"));
	}
	const [, index] = Math.Reputation(bag.Counters.Deals);
	if (index < Math.PROCURE_TIER) {
		return $tuple(false, T("Bazaar.RequestsOpenAtSStanding", (Math.REPUTATION as unknown as Record<number, { Name: string }>)[Math.PROCURE_TIER].Name));
	}
	// an unfilled request that ran past its window has expired and can be placed again
	const expired = Math.MarketBucket(now) > procure.Since + Math.PROCURE_BUCKETS;
	if (procure.Id === entry.Id && procure.Filled === 0 && !expired) {
		return $tuple(false, T("Bazaar.ThatRequestIsAlreadyOpen"));
	}
	bag.Market.Procure = { Id: entry.Id, Since: Math.MarketBucket(now), Filled: 0 };
	return $tuple(true, T("Bazaar.RequestPlacedSArrivesWith", entry.Name));
};
Service.SetFavorite = (profile, payload) => {
	if (!typeIs(payload, "table") || !Math.CatalogById((payload as Dict).Id) || !typeIs((payload as Dict).Saved, "boolean")) {
		return $tuple(false, T("Bazaar.ChooseAValidSupplyTo"));
	}
	const id = (payload as Dict).Id as string;
	const saved = (payload as Dict).Saved as boolean;
	const bag = ensure(profile);
	bag.Market.Saved[id] = saved ? true : undefined;
	return $tuple(true, saved ? T("Bazaar.SupplySavedForFutureShipments") : T("Bazaar.SupplyRemovedFromSavedItems"));
};
Service.State = (profile, now, userId) => {
	const bag = ensure(profile);
	const bucket = Math.MarketBucket(now);
	const bought: Record<string, number | undefined> = bag.Market.Bucket === bucket ? bag.Market.Bought : {};
	const offers: Dict[] = [];
	const [list, tier] = shelf(bag, bucket);
	const merchant = Math.Merchant(bucket);
	const watched: string[] = [];
	for (const offer of list) {
		const left = math.max(0, offer.Stock - (bought[offer.Id] ?? 0));
		offers.push({
			Id: offer.Id,
			Name: offer.Name,
			Category: offer.Category,
			Reward: offer.Reward,
			Discount: offer.Discount,
			Price: Economy.Persist(price(profile, offer)),
			Left: left,
			Stock: offer.Stock,
			Holdings: Math.Holdings(profile, offer.Reward),
			Rare: offer.Rare === true,
			Procured: offer.Procured === true,
			Featured: !truthy(offer.Rare) && offer.Category === merchant.Favors,
		});
		if (bag.Market.Saved[offer.Id] && left > 0) {
			watched.push(offer.Name);
		}
	}
	const [standing, tierIndex, nextTier] = Math.Reputation(bag.Counters.Deals);
	const catalog: Dict[] = [];
	for (const entry of Math.CATALOG) {
		catalog.push({ Id: entry.Id, Name: entry.Name, Category: Math.Category(entry.Reward) });
	}
	const procure = bag.Market.Procure;
	const procureEntry = Math.RegularById(procure.Id);
	let procureState = "None";
	if (procureEntry) {
		if (procure.Filled > 0 && procure.Filled !== bucket) {
			procureState = "Filled";
		} else if (bucket > procure.Since + Math.PROCURE_BUCKETS) {
			procureState = "Expired";
		} else if (bucket <= procure.Since) {
			procureState = "Pending";
		} else {
			procureState = "Listed";
		}
	}
	const history: Dict[] = [];
	for (const entry of bag.Market.History) {
		const record = table.clone(entry);
		record.Name = Math.CatalogById(entry.Pick)!.Name;
		history.push(record);
	}
	return {
		Market: {
			Offers: offers,
			Bucket: bucket,
			EndsAt: (bucket + 1) * Math.MARKET_SECONDS,
			CatalogSize: Math.CATALOG.size(),
			Refunded: bag.Market.Refunded,
			RecoveryPending: Service.NeedsRecovery(profile, userId),
			Rotation: `${bucket}:${countFor(bucket)}`,
			Saved: table.clone(bag.Market.Saved),
			History: history,
			Merchant: {
				Name: merchant.Name,
				Title: merchant.Title,
				Favors: merchant.Favors,
				Accent: merchant.Accent,
				Line: merchant.Line,
			},
			Reputation: {
				Name: standing.Name,
				Index: tierIndex,
				Units: bag.Counters.Deals,
				Bonus: standing.Bonus,
				ShelfBonus: tier.Bonus,
				Next: nextTier ? nextTier.Name : undefined,
				NextAt: nextTier ? nextTier.At : undefined,
				ProcureTier: (Math.REPUTATION as unknown as Record<number, { Name: string }>)[Math.PROCURE_TIER].Name,
				CanProcure: tierIndex >= Math.PROCURE_TIER,
			},
			Procure: {
				Id: procure.Id,
				Name: procureEntry ? procureEntry.Name : undefined,
				State: procureState,
				Since: procure.Since,
				ExpiresAt: (procure.Since + Math.PROCURE_BUCKETS + 1) * Math.MARKET_SECONDS,
			},
			Catalog: catalog,
			Watched: watched,
		},
	};
};
export = Service;
