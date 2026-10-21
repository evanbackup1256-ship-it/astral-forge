// Purpose: the limited-time event calendar. Each event runs for a fixed window, pays its own token
// for normal play (capped per day), and has a small shop. Tokens left over when an event ends are
// turned into Stardust, so nothing earned is simply lost. Add an event by adding a row below.
// Owner: live ops. Dependencies: none.

export interface EventReward {
	Stardust?: number;
	Cores?: number;
	CashMinutes?: number;
	Boost?: string;
	Signals?: number;
	StreakShield?: number;
	FreeSpins?: number;
	Keys?: Record<string, number>;
}

export interface EventShopItem {
	Id: string;
	Name: string;
	Price: number;
	Stock: number;
	Reward: EventReward;
}

export interface LimitedEvent {
	Id: string;
	Name: string;
	Blurb: string;
	Token: string;
	Accent: [number, number, number];
	StartsAt: number;
	EndsAt: number;
	DailyCap: number;
	Earn: Record<string, number>;
	Shop: EventShopItem[];
}

export interface EventBag {
	Id: string;
	Tokens: number;
	Earned: number;
	Day: number;
	DayEarned: number;
	Bought: Record<string, number>;
}

const DAY = 86400;
// one Stardust back for every this many tokens still unspent when an event closes
export const TOKENS_PER_STARDUST = 20;

// the same everyday actions pay every event; the rows differ in what they sell
const EARN: Record<string, number> = table.freeze({
	CollectVault: 1,
	BuyMachine: 2,
	BuyResearch: 2,
	OpenItemCrate: 3,
	ClaimLabOrder: 6,
	ClaimQuest: 8,
	ClaimDaily: 15,
	Rebirth: 40,
});

export const EVENTS: readonly LimitedEvent[] = table.freeze([
	{
		Id: "HollowForge2026",
		Name: "Hollow Forge",
		Blurb: "The furnaces burn low and green for two weeks. Collect embers and trade them at the ember stall.",
		Token: "Embers",
		Accent: [140, 230, 120],
		StartsAt: 1792713600, // 2026-10-23 00:00 UTC
		EndsAt: 1793923200, // 2026-11-06
		DailyCap: 600,
		Earn: EARN,
		Shop: [
			{ Id: "dust", Name: "Ember-cut Stardust", Price: 150, Stock: 10, Reward: { Stardust: 60 } },
			{ Id: "echo", Name: "Echo Crate key", Price: 400, Stock: 6, Reward: { Keys: { EchoCrate: 1 } } },
			{ Id: "overdrive", Name: "Overdrive cell", Price: 250, Stock: 4, Reward: { Boost: "Overdrive" } },
			{ Id: "shield", Name: "Streak shield", Price: 300, Stock: 2, Reward: { StreakShield: 1 } },
			{ Id: "cores", Name: "Green-flame cores", Price: 900, Stock: 3, Reward: { Cores: 4 } },
		],
	},
	{
		Id: "Frostline2026",
		Name: "Frostline",
		Blurb: "A cold front settles over the docks. Pick up frost shards from your work and spend them before the thaw.",
		Token: "Frost shards",
		Accent: [150, 215, 255],
		StartsAt: 1796947200, // 2026-12-11
		EndsAt: 1798761600, // 2027-01-01
		DailyCap: 600,
		Earn: EARN,
		Shop: [
			{ Id: "dust", Name: "Frozen Stardust", Price: 150, Stock: 14, Reward: { Stardust: 60 } },
			{ Id: "nebula", Name: "Nebula Crate key", Price: 350, Stock: 8, Reward: { Keys: { NebulaCrate: 1 } } },
			{ Id: "spins", Name: "Wheel tokens", Price: 200, Stock: 6, Reward: { FreeSpins: 2 } },
			{ Id: "hyperdrive", Name: "Hyperdrive cell", Price: 450, Stock: 3, Reward: { Boost: "Hyperdrive" } },
			{ Id: "cores", Name: "Ice-core bundle", Price: 900, Stock: 4, Reward: { Cores: 4 } },
		],
	},
	{
		Id: "FirstLight2027",
		Name: "First Light",
		Blurb: "Two weeks to start the year strong. Every shift earns sparks for the first-light stall.",
		Token: "Sparks",
		Accent: [255, 214, 120],
		StartsAt: 1799366400, // 2027-01-08
		EndsAt: 1800576000, // 2027-01-22
		DailyCap: 600,
		Earn: EARN,
		Shop: [
			{ Id: "dust", Name: "Sunrise Stardust", Price: 150, Stock: 8, Reward: { Stardust: 60 } },
			{ Id: "horizon", Name: "Horizon Crate key", Price: 500, Stock: 5, Reward: { Keys: { HorizonCrate: 1 } } },
			{ Id: "vault", Name: "Vault surge cell", Price: 250, Stock: 4, Reward: { Boost: "VaultSurge" } },
			{ Id: "signals", Name: "Signal bundle", Price: 200, Stock: 5, Reward: { Signals: 60 } },
			{ Id: "cores", Name: "Dawn cores", Price: 900, Stock: 3, Reward: { Cores: 4 } },
		],
	},
]);

export function byId(id: unknown): LimitedEvent | undefined {
	return EVENTS.find((event) => event.Id === id);
}

export function activeAt(now: number): LimitedEvent | undefined {
	return EVENTS.find((event) => now >= event.StartsAt && now < event.EndsAt);
}

export function nextAfter(now: number): LimitedEvent | undefined {
	let best: LimitedEvent | undefined;
	for (const event of EVENTS) {
		if (event.StartsAt > now && (best === undefined || event.StartsAt < best.StartsAt)) {
			best = event;
		}
	}
	return best;
}

function dayOf(now: number): number {
	return math.floor(now / DAY);
}

function count(value: unknown): number {
	const n = tonumber(value) ?? 0;
	return n === n && n > 0 && n < 1e12 ? math.floor(n) : 0;
}

function readBag(raw: unknown): EventBag {
	const bag = (typeIs(raw, "table") ? raw : {}) as Partial<EventBag>;
	const bought: Record<string, number> = {};
	if (typeIs(bag.Bought, "table")) {
		for (const [id, n] of pairs(bag.Bought as Record<string, unknown>)) {
			if (typeIs(id, "string") && count(n) > 0) {
				bought[id] = count(n);
			}
		}
	}
	return {
		Id: typeIs(bag.Id, "string") ? bag.Id : "",
		Tokens: count(bag.Tokens),
		Earned: count(bag.Earned),
		Day: math.floor(tonumber(bag.Day) ?? -1),
		DayEarned: count(bag.DayEarned),
		Bought: bought,
	};
}

// Moves the bag onto the running event (or to an empty bag between events). Returns the Stardust the
// old event's leftover tokens are worth; the caller credits it. `changed` is false when nothing moved.
export function ensure(
	profile: { LimitedEvent?: unknown },
	event: LimitedEvent | undefined,
): LuaTuple<[changed: boolean, refund: number]> {
	const bag = readBag(profile.LimitedEvent);
	const wantId = event !== undefined ? event.Id : "";
	if (bag.Id === wantId) {
		return $tuple(false, 0);
	}
	const refund = bag.Id !== "" ? math.floor(bag.Tokens / TOKENS_PER_STARDUST) : 0;
	profile.LimitedEvent = { Id: wantId, Tokens: 0, Earned: 0, Day: -1, DayEarned: 0, Bought: {} };
	return $tuple(true, refund);
}

// Adds tokens for `amount` worth of actions, up to the event's daily cap. Returns what was added.
export function earn(profile: { LimitedEvent?: unknown }, event: LimitedEvent, points: number, now: number): number {
	const bag = readBag(profile.LimitedEvent);
	if (bag.Id !== event.Id || points <= 0) {
		return 0;
	}
	const today = dayOf(now);
	if (bag.Day !== today) {
		bag.Day = today;
		bag.DayEarned = 0;
	}
	const added = math.min(math.floor(points), math.max(0, event.DailyCap - bag.DayEarned));
	bag.Tokens += added;
	bag.Earned += added;
	bag.DayEarned += added;
	profile.LimitedEvent = bag;
	return added;
}

export function pointsFor(event: LimitedEvent, action: string): number {
	return event.Earn[action] ?? 0;
}

export function shopItem(event: LimitedEvent, id: unknown): EventShopItem | undefined {
	return event.Shop.find((item) => item.Id === id);
}

// Checks and takes payment for one shop item. Returns the item on success or a reason it was refused.
export function buy(
	profile: { LimitedEvent?: unknown },
	event: LimitedEvent,
	itemId: unknown,
): LuaTuple<[item: EventShopItem | undefined, reason: string | undefined]> {
	const item = shopItem(event, itemId);
	if (item === undefined) {
		return $tuple(undefined, "That isn't sold at this stall.");
	}
	const bag = readBag(profile.LimitedEvent);
	if (bag.Id !== event.Id) {
		return $tuple(undefined, "The event stall is still setting up. Try again in a few seconds.");
	}
	const bought = bag.Bought[item.Id] ?? 0;
	if (bought >= item.Stock) {
		return $tuple(undefined, "Sold out for this event.");
	}
	if (bag.Tokens < item.Price) {
		return $tuple(undefined, string.format("You need %d more %s.", item.Price - bag.Tokens, event.Token.lower()));
	}
	bag.Tokens -= item.Price;
	bag.Bought[item.Id] = bought + 1;
	profile.LimitedEvent = bag;
	return $tuple(item, undefined);
}
