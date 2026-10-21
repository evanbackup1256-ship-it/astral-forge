// Purpose: what PolicyService lets a player do with paid random items and trading, and which
// purchases and trade requests that rules out. Server and client both read it, so the Shop and the
// trade buttons show the same thing the server enforces.
// Owner: gameplay. Dependencies: none.

export interface PlayPolicy {
	// true when the player can't buy a random reward with Robux or with currency Robux can buy
	PaidRandomItemsRestricted: boolean;
	PaidItemTradingAllowed: boolean;
	// false until PolicyService has answered; the restrictive values above stand in until then
	Known: boolean;
}

// Used whenever PolicyService fails or hasn't answered yet: restrict first, relax once we know.
export const RESTRICTED: PlayPolicy = table.freeze({
	PaidRandomItemsRestricted: true,
	PaidItemTradingAllowed: false,
	Known: false,
});

// Stardust and Cores are sold for Robux (MonetizationConfig) and have few other big sources, so a key
// or relic cache bought with them counts as a paid random item. Flux is earned by every machine every
// second; Market shipments priced in Flux stay available.
export const PAID_CURRENCIES: ReadonlySet<string> = new ReadonlySet(["Stardust", "Cores"]);

// Offer kinds whose contents are decided by a roll after purchase.
export const RANDOM_KINDS: ReadonlySet<string> = new ReadonlySet(["Key", "Cache"]);

// Every trade request that moves or stages items. Looking at, cancelling and leaving a trade stay open,
// so a player is never stuck inside one.
export const TRADE_ACTIONS: ReadonlySet<string> = new ReadonlySet([
	"InviteTrade",
	"RespondTrade",
	"UpdateTradeOffer",
	"SetTradeReady",
	"ConfirmTrade",
	"TradeRequest",
]);

export const Copy = table.freeze({
	PaidRandom: "Keys and relic caches can't be bought with Stardust or Cores where you live. Keys you earn still open crates.",
	PaidRandomShort: "Not in your region",
	Trading: "Trading isn't available where you live.",
	TradingShort: "Trading unavailable",
	TradingPartner: "That player can't trade where they live.",
});

export function fromPolicyInfo(ok: boolean, info: unknown): PlayPolicy {
	if (!ok || !typeIs(info, "table")) {
		return RESTRICTED;
	}
	const policy = info as { ArePaidRandomItemsRestricted?: unknown; IsPaidItemTradingAllowed?: unknown };
	return table.freeze({
		// a missing or odd field is read the restrictive way, field by field
		PaidRandomItemsRestricted: policy.ArePaidRandomItemsRestricted !== false,
		PaidItemTradingAllowed: policy.IsPaidItemTradingAllowed === true,
		Known: true,
	});
}

// Free offers (the daily Forge key) cost nothing, so they aren't paid.
export function isPaidRandomOffer(offer: { Kind?: unknown; Currency?: unknown; Price?: unknown } | undefined): boolean {
	if (offer === undefined || (tonumber(offer.Price) ?? 0) <= 0) {
		return false;
	}
	return (
		typeIs(offer.Kind, "string") &&
		RANDOM_KINDS.has(offer.Kind) &&
		typeIs(offer.Currency, "string") &&
		PAID_CURRENCIES.has(offer.Currency)
	);
}

// A Robux product that hands out keys or wheel spins.
export function isPaidRandomProduct(product: { Reward?: unknown } | undefined): boolean {
	if (product === undefined || !typeIs(product.Reward, "table")) {
		return false;
	}
	const reward = product.Reward as { Keys?: unknown; FreeSpins?: unknown };
	if (typeIs(reward.Keys, "table") && next(reward.Keys as object)[0] !== undefined) {
		return true;
	}
	return (tonumber(reward.FreeSpins) ?? 0) > 0;
}

export function offerBlocked(
	policy: PlayPolicy,
	offer: { Kind?: unknown; Currency?: unknown; Price?: unknown } | undefined,
): string | undefined {
	return policy.PaidRandomItemsRestricted && isPaidRandomOffer(offer) ? Copy.PaidRandom : undefined;
}

export function productBlocked(policy: PlayPolicy, product: { Reward?: unknown } | undefined): boolean {
	return policy.PaidRandomItemsRestricted && isPaidRandomProduct(product);
}

export function tradeBlocked(policy: PlayPolicy, action: string): string | undefined {
	return !policy.PaidItemTradingAllowed && TRADE_ACTIONS.has(action) ? Copy.Trading : undefined;
}
