const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`TradeSuite: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`TradeSuite: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

type Dict = Record<string, unknown>;

// Luau truthiness: only nil and false are falsy (0 and "" are truthy).
function truthy<T>(value: T): value is Exclude<T, undefined | false> {
	return value !== undefined && (value as unknown) !== false;
}

interface OmegaMathApi {
	Add(this: void, a: unknown, b: unknown): unknown;
	Sub(this: void, a: unknown, b: unknown): unknown;
	Gt(this: void, a: unknown, b: unknown): boolean;
	[key: string]: unknown;
}

interface TradeOfferItem {
	Uid: string;
	DefinitionId: string;
	Name: string;
}

interface TradeOfferBag {
	Cash: number;
	Stardust: number;
	Cores: number;
	Signals: number;
	Essence: number;
	Boosts: Record<string, number>;
	Keys: Record<string, number>;
	ItemIds: string[];
	Items?: TradeOfferItem[];
	[key: string]: unknown;
}

interface TradeSession {
	Id: string;
	Host: number;
	Guest: number;
	Offers: Record<number, TradeOfferBag>;
	Ready: Record<number, boolean>;
	Confirmed: Record<number, boolean>;
	ConfirmEndsAt: number;
	Settling: boolean;
	Status: string;
	ExpiresAt: number;
	LastSay?: Record<number, number>;
	Chat?: Array<{ From: number; Name: string; Text: string; At: number; Phrase: boolean }>;
	Requests?: Record<number, unknown>;
	Away?: Record<number, boolean>;
	RevertFailedAt?: number;
	RevertFailedReason?: string;
	HostCommitted?: boolean;
	GuestCommitted?: boolean;
	[key: string]: unknown;
}

interface TradeInvite {
	From: number;
	ExpiresAt: number;
}

interface TradeOutgoing {
	To: number;
	ToName: string;
	ExpiresAt: number;
}

interface TradeExchangeApi {
	CURRENCIES: string[];
	BOOST_IDS: string[];
	KEY_IDS: string[];
	CopyItemInstance(this: void, instance: unknown): Dict | undefined;
	SnapshotOfferItems(this: void, offer: TradeOfferBag, profile: unknown): Dict;
	ApplyExchange(
		this: void,
		gameConfig: unknown,
		omegaMath: OmegaMathApi,
		profile: Dict,
		give: TradeOfferBag,
		take: TradeOfferBag,
		giveItems: Dict | undefined,
		takeItems: Dict | undefined,
		now: number,
		validateOffer?: (this: void, profile: Dict, offer: TradeOfferBag, at: number) => string | undefined,
	): string | undefined;
	RevertExchange(
		this: void,
		omegaMath: OmegaMathApi,
		profile: Dict,
		give: TradeOfferBag,
		take: TradeOfferBag,
		giveItems: Dict | undefined,
		takeItems: Dict | undefined,
		now: number,
	): void;
}

interface TradeOfferMathApi {
	EmptyOffer(this: void, boostIds: string[], keyIds: string[]): TradeOfferBag;
	CopyOffer(this: void, offer: unknown, currencies: string[], boostIds: string[], keyIds: string[]): TradeOfferBag;
	OfferEmpty(this: void, offer: unknown, currencies: string[], boostIds: string[], keyIds: string[]): boolean;
	BoostTotal(this: void, offer: unknown, boostIds: string[]): number;
	KeyTotal(this: void, offer: unknown, keyIds: string[]): number;
	EnsureLedger(this: void, profile: unknown, now: number): void;
	ItemEquipped(this: void, profile: unknown, uid: string): boolean;
	CountInventory(this: void, profile: unknown): number;
}

interface TradeSettleApi {
	REVERT_ATTEMPTS: number;
	TryBegin(this: void, session: TradeSession | undefined): boolean;
	Fail(this: void, session: TradeSession | undefined, permanent?: boolean, reason?: string): void;
	CancelBlocked(this: void, session: TradeSession | undefined): LuaTuple<[boolean, string | undefined]>;
}

interface TradeChatMathApi {
	CanSend(this: void, lastAt: unknown, now: number, cooldown?: number): boolean;
}

interface TradeRequestMathApi {
	Normalize(this: void, raw: unknown, caps: Record<string, number>, currencies: string[]): Dict;
}

interface TradeGameConfig {
	Items?: {
		Definitions?: Array<{ Id?: string; Name?: string; Rarity?: string }>;
		InventoryLimit: number;
	};
	Trading: {
		PerTrade: Record<string, number>;
		Daily: Record<string, number>;
		DailyTrades: number;
		MaxItems: number;
		SessionSeconds: number;
		InviteSeconds: number;
		ConfirmSeconds: number;
	};
	[key: string]: unknown;
}

interface TradeDeskInstance {
	_sessions: Record<string, TradeSession>;
	_byUser: Record<number, string>;
	_invites: Record<number, TradeInvite>;
	_outgoing: Record<number, TradeOutgoing>;
	_epoch: number;
	_nextId: number;
	ProfileOf?: (this: void, userId: number) => Dict | undefined;

	_bump(this: TradeDeskInstance): void;
	Epoch(this: TradeDeskInstance): number;
	_sessionId(this: TradeDeskInstance): string;
	Unlocked(this: TradeDeskInstance, profile: unknown): boolean;
	Public(this: TradeDeskInstance, session: TradeSession | undefined, userId: number): Dict | undefined;
	_tradeableRelics(this: TradeDeskInstance, userId: number): Dict[];
	Say(
		this: TradeDeskInstance,
		player: Player,
		text: string | undefined,
		phrase: number | undefined,
		now: number,
	): LuaTuple<[boolean, string | undefined, TradeSession | undefined]>;
	Request(this: TradeDeskInstance, player: Player, raw: unknown, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]>;
	SetAway(this: TradeDeskInstance, player: Player, away: boolean): TradeSession | undefined;
	InvitePublic(this: TradeDeskInstance, userId: number): Dict | undefined;
	OutgoingPublic(this: TradeDeskInstance, userId: number): Dict | undefined;
	DailyPublic(this: TradeDeskInstance, profile: Dict, now: number): Dict;
	StatePublic(this: TradeDeskInstance, profile: Dict, player: Player, now: number): Dict;
	Drop(this: TradeDeskInstance, userId: number): number[];
	_validateOffer(this: TradeDeskInstance, profile: Dict, offer: TradeOfferBag, now: number, skipDaily?: boolean): string | undefined;
	Invite(
		this: TradeDeskInstance,
		fromPlayer: Player,
		fromProfile: unknown,
		targetUserId: number,
		now: number,
	): LuaTuple<[boolean, string | undefined]>;
	Respond(
		this: TradeDeskInstance,
		guest: Player,
		guestProfile: unknown,
		accept: boolean,
		now: number,
	): LuaTuple<[boolean, string | undefined, TradeSession | undefined, number | undefined]>;
	UpdateOffer(
		this: TradeDeskInstance,
		player: Player,
		profile: Dict,
		rawOffer: unknown,
		now: number,
	): LuaTuple<[boolean, string | undefined, TradeSession | undefined]>;
	SetReady(
		this: TradeDeskInstance,
		player: Player,
		profile: Dict,
		ready: boolean,
		now: number,
	): LuaTuple<[boolean, string | undefined, TradeSession | undefined]>;
	Confirm(this: TradeDeskInstance, player: Player, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]>;
	TryBeginSettle(this: TradeDeskInstance, session: TradeSession): boolean;
	FailSettle(this: TradeDeskInstance, session: TradeSession, permanent?: boolean, reason?: string): void;
	Cancel(this: TradeDeskInstance, player: Player): LuaTuple<[TradeSession | undefined, number | undefined, string | undefined]>;
	Plan(this: TradeDeskInstance, session: TradeSession, hostProfile: Dict, guestProfile: Dict, now: number): LuaTuple<[Dict | undefined, string | undefined]>;
	ApplyExchange(
		this: TradeDeskInstance,
		profile: Dict,
		give: TradeOfferBag,
		take: TradeOfferBag,
		giveItems: Dict | undefined,
		takeItems: Dict | undefined,
		now: number,
	): string | undefined;
	RevertExchange(
		this: TradeDeskInstance,
		profile: Dict,
		give: TradeOfferBag,
		take: TradeOfferBag,
		giveItems: Dict | undefined,
		takeItems: Dict | undefined,
		now: number,
	): void;
	Close(this: TradeDeskInstance, session: TradeSession | undefined): void;
	SessionFor(this: TradeDeskInstance, userId: number): TradeSession | undefined;
}

__defs["TradeChatMath"] = () => {
	const TradeChatMath = {
		CanSend(this: void, lastAt: number | undefined, now: number, cooldown?: number): boolean {
			if (!typeIs(lastAt, "number") || lastAt !== lastAt) {
				return true;
			}
			return now - lastAt >= (cooldown ?? 0.6);
		},
	};

	return table.freeze(TradeChatMath);
};

__defs["TradeRequestMath"] = () => {
	const TradeRequestMath = {
		Normalize(this: void, raw: unknown, caps: Record<string, number>, currencies: string[]): Dict {
			const request: Dict = { ItemIds: [] as string[] };
			const itemCap = math.min(8, math.max(0, math.floor(tonumber(caps.Items) ?? 0)));
			const seen: Record<string, boolean> = {};
			const itemIds = request.ItemIds as string[];
			const rawBag = raw as Dict;
			if (typeIs(raw, "table") && typeIs(rawBag.ItemIds, "table")) {
				for (const uid of rawBag.ItemIds as unknown[]) {
					if (typeIs(uid, "string") && uid.size() > 0 && uid.size() <= 48 && !seen[uid] && itemIds.size() < itemCap) {
						seen[uid] = true;
						itemIds.push(uid);
					}
				}
			}
			for (const key of currencies) {
				const amount = typeIs(raw, "table") ? tonumber(rawBag[key]) : 0;
				if (typeIs(amount, "number") && amount === amount && amount > 0) {
					request[key] = math.min(math.floor(amount), math.max(0, math.floor(tonumber(caps[key]) ?? 0)));
				}
			}
			return request;
		},
	};

	return table.freeze(TradeRequestMath);
};

__defs["TradeChatFilter"] = () => {
	const TradeChatFilter = {
		Apply(this: void, textService: TextService, raw: unknown, userId: number, context: unknown): LuaTuple<[boolean, string | undefined]> {
			if (!typeIs(raw, "string") || raw.size() === 0) {
				return $tuple(false, undefined);
			}
			const text = string.sub(raw, 1, 140);
			const [ok, filtered] = pcall((): string => {
				const result = textService.FilterStringAsync(text, userId, context as Enum.TextFilterContext);
				return result.GetNonChatStringForBroadcastAsync();
			});
			if (!ok || !typeIs(filtered, "string")) {
				return $tuple(false, undefined);
			}
			return $tuple(true, filtered);
		},
	};

	return table.freeze(TradeChatFilter);
};

__defs["TradeDesk"] = () => {
	const Players = game.GetService("Players");
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");

	const GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as TradeGameConfig;
	const OmegaMath = require(shared.WaitForChild("OmegaMath") as ModuleScript) as OmegaMathApi;
	(require(script.Parent!.WaitForChild("EconomyMath") as ModuleScript) as (this: void, name: string) => unknown)(
		"ProgressionGate",
	);
	const TradeHistory = require(shared.WaitForChild("TradeHistory") as ModuleScript) as {
		public(this: void, trade: unknown): unknown;
	};
	const TradeExchange = __load("TradeExchange") as TradeExchangeApi;
	const TradeOfferMath = __load("TradeOfferMath") as TradeOfferMathApi;
	const TradeSettle = __load("TradeSettle") as TradeSettleApi;
	const TradeChatMath = __load("TradeChatMath") as TradeChatMathApi;
	const TradeRequestMath = __load("TradeRequestMath") as TradeRequestMathApi;

	const CURRENCIES = TradeExchange.CURRENCIES;
	const BOOST_IDS = TradeExchange.BOOST_IDS;
	const KEY_IDS = TradeExchange.KEY_IDS;

	let itemNames: Record<string, string> | undefined = undefined;
	function itemNameFor(definitionId: string): string {
		if (itemNames === undefined) {
			itemNames = {};
			const defs = truthy(GameConfig.Items) ? GameConfig.Items.Definitions : undefined;
			if (typeIs(defs, "table")) {
				for (const definition of defs) {
					if (typeIs(definition, "table") && typeIs(definition.Id, "string")) {
						itemNames[definition.Id] = typeIs(definition.Name, "string") ? definition.Name : definition.Id;
					}
				}
			}
		}
		return itemNames[definitionId] ?? "Relic";
	}

	function emptyOffer(): TradeOfferBag {
		return TradeOfferMath.EmptyOffer(BOOST_IDS, KEY_IDS);
	}

	function copyOffer(offer: unknown): TradeOfferBag {
		return TradeOfferMath.CopyOffer(offer, CURRENCIES, BOOST_IDS, KEY_IDS);
	}

	function stampItems(offer: TradeOfferBag, profile: Dict | undefined): void {
		offer.Items = [];
		const items = truthy(profile) ? (profile.Items as Dict | undefined) : undefined;
		const inventory = truthy(items) ? items.Inventory : undefined;
		if (!typeIs(inventory, "table")) {
			return;
		}
		const itemsList = offer.Items;
		for (const uid of offer.ItemIds) {
			const instance = (inventory as Dict)[uid];
			const instanceBag = instance as Dict | undefined;
			const definitionId =
				typeIs(instanceBag, "table") && typeIs(instanceBag.DefinitionId, "string") ? instanceBag.DefinitionId : "";
			itemsList.push({
				Uid: uid,
				DefinitionId: definitionId,
				Name: itemNameFor(definitionId),
			});
		}
	}

	function offerEmpty(offer: unknown): boolean {
		return TradeOfferMath.OfferEmpty(offer, CURRENCIES, BOOST_IDS, KEY_IDS);
	}

	function ensureLedger(profile: unknown, now: number): void {
		TradeOfferMath.EnsureLedger(profile, now);
	}

	function itemEquipped(profile: unknown, uid: string): boolean {
		return TradeOfferMath.ItemEquipped(profile, uid);
	}

	function countInventory(profile: unknown): number {
		return TradeOfferMath.CountInventory(profile);
	}

	function boostTotal(offer: unknown): number {
		return TradeOfferMath.BoostTotal(offer, BOOST_IDS);
	}

	function keyTotal(offer: unknown): number {
		return TradeOfferMath.KeyTotal(offer, KEY_IDS);
	}

	const TradeDesk = {
		PHRASES: [
			"Deal?", "Can you add a little more?", "That's fair.", "Not for that.",
			"Let me look.", "Ready when you are.", "Thanks for the trade.", "One sec.",
		] as string[],

		new(this: void): TradeDeskInstance {
			return setmetatable(
				{
					_sessions: {},
					_byUser: {},
					_invites: {},
					_outgoing: {},
					_epoch: 0,
					_nextId: 1,
				} as TradeDeskInstance,
				TradeDesk as unknown as LuaMetatable<TradeDeskInstance>,
			);
		},

		_bump(this: TradeDeskInstance): void {
			this._epoch = (this._epoch ?? 0) + 1;
		},

		Epoch(this: TradeDeskInstance): number {
			return this._epoch ?? 0;
		},

		_sessionId(this: TradeDeskInstance): string {
			this._nextId += 1;
			return string.format("td_%d_%d", os.time(), this._nextId);
		},

		Unlocked(this: TradeDeskInstance, _profile: unknown): boolean {
			return true;
		},

		Public(this: TradeDeskInstance, session: TradeSession | undefined, userId: number): Dict | undefined {
			if (!truthy(session)) {
				return undefined;
			}
			const them = session.Host === userId ? session.Guest : session.Host;
			const themPlayer = Players.GetPlayerByUserId(them);
			const partnerName =
				them === -999 ? "Forge Automaton [Practice]" : (themPlayer !== undefined ? themPlayer.DisplayName : "Forge partner");
			return {
				Id: session.Id,
				PartnerUserId: them,
				PartnerName: partnerName,
				You: copyOffer(session.Offers[userId]),
				Them: copyOffer(session.Offers[them]),
				YouReady: session.Ready[userId] === true,
				ThemReady: session.Ready[them] === true,
				YouConfirmed: session.Confirmed[userId] === true,
				ThemConfirmed: session.Confirmed[them] === true,
				ConfirmEndsAt: session.ConfirmEndsAt,
				Status: session.Status,
				ExpiresAt: session.ExpiresAt,
				Chat: table.clone(session.Chat ?? []),
				YourRequest: truthy(session.Requests) ? session.Requests[userId] : undefined,
				TheirRequest: truthy(session.Requests) ? session.Requests[them] : undefined,
				PartnerRelics: this._tradeableRelics(them),
				PartnerAway: (truthy(session.Away) && session.Away[them] === true) as boolean,
			};
		},

		// the relics a player could put on the table (not locked, not equipped), for the partner to browse
		_tradeableRelics(this: TradeDeskInstance, userId: number): Dict[] {
			const profileOf = this.ProfileOf;
			const profile = profileOf !== undefined ? profileOf(userId) : undefined;
			const items = truthy(profile) ? (profile.Items as Dict | undefined) : undefined;
			const inventory = truthy(items) ? items.Inventory : undefined;
			const list: Dict[] = [];
			if (!typeIs(inventory, "table")) {
				return list;
			}
			const rarityOf: Record<string, unknown> = {};
			const defs = truthy(GameConfig.Items) && truthy(GameConfig.Items.Definitions) ? GameConfig.Items.Definitions : [];
			for (const definition of defs) {
				if (typeIs(definition, "table") && truthy(definition.Id)) {
					rarityOf[definition.Id] = definition.Rarity;
				}
			}
			for (const [uid, instance] of pairs(inventory)) {
				const instanceBag = instance as Dict;
				if (typeIs(instance, "table") && instanceBag.Locked !== true && !itemEquipped(profile, uid as string)) {
					list.push({
						Uid: uid,
						DefinitionId: instanceBag.DefinitionId,
						Name: itemNameFor(tostring(truthy(instanceBag.DefinitionId) ? instanceBag.DefinitionId : "")),
						Rarity: rarityOf[instanceBag.DefinitionId as string] ?? "Common",
						Level: tonumber(instanceBag.Level) ?? 1,
					});
				}
				if (list.size() >= 60) {
					break;
				}
			}
			list.sort((a, b) => (a.Uid as string) < (b.Uid as string));
			return list;
		},

		// a line of table talk: `text` arrives already filtered by the caller; `phrase` is an index
		Say(this: TradeDeskInstance, player: Player, text: string | undefined, phrase: number | undefined, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session) || session.ExpiresAt < now) {
				return $tuple(false, "That trade is no longer open.", undefined);
			}
			session.LastSay = session.LastSay ?? {};
			const lastSay = session.LastSay;
			const clock = os.clock();
			if (!TradeChatMath.CanSend(lastSay[player.UserId], clock)) {
				return $tuple(false, "Slow down a little.", undefined);
			}
			let line: string;
			if (typeIs(phrase, "number") && TradeDesk.PHRASES[phrase - 1] !== undefined) {
				line = TradeDesk.PHRASES[phrase - 1];
			} else if (typeIs(text, "string") && text.size() > 0) {
				line = string.sub(text, 1, 140);
			} else {
				return $tuple(false, "Say something first.", undefined);
			}
			lastSay[player.UserId] = clock;
			session.Chat = session.Chat ?? [];
			session.Chat.push({ From: player.UserId, Name: player.DisplayName, Text: line, At: now, Phrase: phrase !== undefined });
			while (session.Chat.size() > 40) {
				session.Chat.shift();
			}
			return $tuple(true, undefined, session);
		},

		// what you'd like from your partner: some of their relics and some amounts; they can add it in one tap
		Request(this: TradeDeskInstance, player: Player, raw: unknown, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session) || session.ExpiresAt < now) {
				return $tuple(false, "That trade is no longer open.", undefined);
			}
			if (session.Settling === true || session.Status === "Settling") {
				return $tuple(false, "That trade is already settling.", undefined);
			}
			const caps = GameConfig.Trading.PerTrade;
			const request = TradeRequestMath.Normalize(raw, caps, CURRENCIES);
			session.Requests = session.Requests ?? {};
			session.Requests[player.UserId] = request;
			return $tuple(true, undefined, session);
		},

		SetAway(this: TradeDeskInstance, player: Player, away: boolean): TradeSession | undefined {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session)) {
				return undefined;
			}
			session.Away = session.Away ?? {};
			session.Away[player.UserId] = away === true;
			return session;
		},

		InvitePublic(this: TradeDeskInstance, userId: number): Dict | undefined {
			const invite = this._invites[userId];
			if (!truthy(invite) || (typeIs(invite.ExpiresAt, "number") && invite.ExpiresAt < os.time())) {
				if (truthy(invite)) {
					delete this._invites[userId];
				}
				return undefined;
			}
			const from = Players.GetPlayerByUserId(invite.From);
			return {
				FromUserId: invite.From,
				FromName: from !== undefined ? from.DisplayName : "A forgemaster",
				ExpiresAt: invite.ExpiresAt,
			};
		},

		OutgoingPublic(this: TradeDeskInstance, userId: number): Dict | undefined {
			const outgoing = this._outgoing[userId];
			if (!truthy(outgoing) || (typeIs(outgoing.ExpiresAt, "number") && outgoing.ExpiresAt < os.time())) {
				if (truthy(outgoing)) {
					delete this._outgoing[userId];
				}
				return undefined;
			}
			return {
				ToUserId: outgoing.To,
				ToName: outgoing.ToName,
				ExpiresAt: outgoing.ExpiresAt,
			};
		},

		DailyPublic(this: TradeDeskInstance, profile: Dict, now: number): Dict {
			ensureLedger(profile, now);
			const trade = profile.Trade as Dict;
			const sent = trade.Sent as Dict;
			return {
				Completed: trade.Completed,
				Limit: GameConfig.Trading.DailyTrades,
				Sent: {
					Cash: sent.Cash ?? 0,
					Stardust: sent.Stardust ?? 0,
					Cores: sent.Cores ?? 0,
					Signals: sent.Signals ?? 0,
					Essence: sent.Essence ?? 0,
					Boost: sent.Boost ?? 0,
					Keys: sent.Keys ?? 0,
					Items: sent.Items ?? 0,
				},
				Caps: GameConfig.Trading.Daily,
				PerTrade: GameConfig.Trading.PerTrade,
			};
		},

		LockedPublic(this: void): Dict {
			return { Unlocked: false, Epoch: 0 };
		},

		StatePublic(this: TradeDeskInstance, profile: Dict, player: Player, now: number): Dict {
			const [ok, result] = pcall((): Dict => ({
				Unlocked: this.Unlocked(profile),
				Epoch: this.Epoch(),
				Session: this.Public(this.SessionFor(player.UserId), player.UserId),
				Invite: this.InvitePublic(player.UserId),
				Outgoing: this.OutgoingPublic(player.UserId),
				Daily: this.DailyPublic(profile, now),
				History: TradeHistory.public((profile as Dict).Trade),
			}));
			if (!ok) {
				pcall(() => {
					const ModuleLog = require(
						shared.WaitForChild("ModuleLog") as ModuleScript,
					) as { Warn(this: void, scope: string, message: string): void };
					ModuleLog.Warn(
						"TradeDesk",
						string.format("StatePublic error for u=%s: %s", tostring(truthy(player) ? player.UserId : undefined), tostring(result)),
					);
				});
				const trade = profile.Trade as Dict | undefined;
				return {
					Unlocked: this.Unlocked(profile),
					Epoch: this.Epoch(),
					Session: undefined,
					Invite: undefined,
					Outgoing: undefined,
					Daily: {
						Completed: truthy(trade) ? trade.Completed ?? 0 : 0,
						Limit: GameConfig.Trading.DailyTrades,
						Sent: { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 },
						Caps: GameConfig.Trading.Daily,
						PerTrade: GameConfig.Trading.PerTrade,
					},
					History: {},
				};
			}
			return result;
		},

		Drop(this: TradeDeskInstance, userId: number): number[] {
			const notify: number[] = [];
			const invite = this._invites[userId];
			if (truthy(invite)) {
				delete this._invites[userId];
				if (truthy(this._outgoing[invite.From])) {
					delete this._outgoing[invite.From];
					notify.push(invite.From);
				}
			}
			const outgoing = this._outgoing[userId];
			if (truthy(outgoing)) {
				delete this._outgoing[userId];
				const targetInvite = this._invites[outgoing.To];
				if (truthy(targetInvite) && targetInvite.From === userId) {
					delete this._invites[outgoing.To];
					notify.push(outgoing.To);
				}
			}
			for (const [target, pending] of pairs(this._invites)) {
				if (pending.From === userId) {
					delete this._invites[target];
					notify.push(target);
				}
			}
			const sessionId = this._byUser[userId];
			if (truthy(sessionId)) {
				const session = this._sessions[sessionId];
				if (truthy(session)) {
					delete this._sessions[sessionId];
					delete this._byUser[session.Host];
					delete this._byUser[session.Guest];
					const other = session.Host === userId ? session.Guest : session.Host;
					notify.push(other);
				}
			}
			delete this._byUser[userId];
			this._bump();
			return notify;
		},

		_validateOffer(this: TradeDeskInstance, profile: Dict, offer: TradeOfferBag, now: number, skipDaily?: boolean): string | undefined {
			ensureLedger(profile, now);
			const caps = GameConfig.Trading.PerTrade;
			const daily = GameConfig.Trading.Daily;
			if (offer.ItemIds.size() > GameConfig.Trading.MaxItems || offer.ItemIds.size() > caps.Items) {
				return "That offer has too many relics.";
			}
			const trade = profile.Trade as Dict;
			const sent = trade.Sent as Dict;
			for (const key of CURRENCIES) {
				if ((offer[key] as number) > caps[key]) {
					return string.format("That %s amount is over the per-trade limit.", key === "Cash" ? "Flux" : key);
				}
				if (skipDaily !== true && ((sent[key] as number | undefined) ?? 0) + (offer[key] as number) > daily[key]) {
					return string.format("Daily %s trade limit reached.", key === "Cash" ? "Flux" : key);
				}
			}
			if (OmegaMath.Gt(offer.Cash, profile.Cash)) {
				return "You do not have that much Flux.";
			}
			if (offer.Stardust > (tonumber(profile.Stardust) ?? 0)) {
				return "You do not have that much Stardust.";
			}
			if (offer.Cores > (tonumber(profile.Cores) ?? 0)) {
				return "You do not have that many Cores.";
			}
			const command = profile.Command as Dict | undefined;
			const signals = truthy(command) ? tonumber(command.Signals) ?? 0 : 0;
			if (offer.Signals > signals) {
				return "You do not have that many Signals.";
			}
			const itemsBag = profile.Items as Dict | undefined;
			const essence = truthy(itemsBag) ? tonumber(itemsBag.Essence) ?? 0 : 0;
			if (offer.Essence > essence) {
				return "You do not have that much Essence.";
			}
			const boostSum = boostTotal(offer);
			if (boostSum > caps.Boost) {
				return "That many boosts is over the per-trade limit.";
			}
			if (skipDaily !== true && ((sent.Boost as number | undefined) ?? 0) + boostSum > daily.Boost) {
				return "Daily boost trade limit reached.";
			}
			const boostInventory = profile.BoostInventory as Dict | undefined;
			for (const id of BOOST_IDS) {
				const owned = truthy(boostInventory) ? tonumber(boostInventory[id]) ?? 0 : 0;
				if (offer.Boosts[id] > owned) {
					return "You do not have that many of that boost.";
				}
			}
			const keySum = keyTotal(offer);
			if (keySum > caps.Keys) {
				return "That many keys is over the per-trade limit.";
			}
			if (skipDaily !== true && ((sent.Keys as number | undefined) ?? 0) + keySum > daily.Keys) {
				return "Daily key trade limit reached.";
			}
			const keysBag = truthy(itemsBag) ? (itemsBag.Keys as Dict | undefined) : undefined;
			for (const id of KEY_IDS) {
				const owned = truthy(keysBag) ? tonumber(keysBag[id]) ?? 0 : 0;
				if (offer.Keys[id] > owned) {
					return "You do not have that many crate keys.";
				}
			}
			if (skipDaily !== true && ((sent.Items as number | undefined) ?? 0) + offer.ItemIds.size() > daily.Items) {
				return "Daily relic trade limit reached.";
			}
			if (!truthy(itemsBag) || !typeIs(itemsBag.Inventory, "table")) {
				if (offer.ItemIds.size() > 0) {
					return "Those relics are not in your inventory.";
				}
				return undefined;
			}
			const inventory = itemsBag.Inventory as Dict;
			for (const uid of offer.ItemIds) {
				const instance = inventory[uid] as Dict | undefined;
				if (!typeIs(instance, "table")) {
					return "A relic in that offer is missing.";
				}
				if (instance.Locked === true) {
					return "Locked relics cannot be traded.";
				}
				if (itemEquipped(profile, uid)) {
					return "Unequip a relic before trading it.";
				}
			}
			return undefined;
		},

		Invite(this: TradeDeskInstance, fromPlayer: Player, fromProfile: unknown, targetUserId: number, now: number): LuaTuple<[boolean, string | undefined]> {
			if (!this.Unlocked(fromProfile)) {
				return $tuple(false, "Trade Floor unlocks after your first rebirth.");
			}
			if (fromPlayer.UserId === targetUserId) {
				return $tuple(false, "You cannot trade with yourself.");
			}
			if (truthy(this._byUser[fromPlayer.UserId])) {
				return $tuple(false, "Finish or cancel your current trade first.");
			}
			if (targetUserId === -999) {
				const session: TradeSession = {
					Id: this._sessionId(),
					Host: fromPlayer.UserId,
					Guest: -999,
					Offers: {
						[fromPlayer.UserId]: emptyOffer(),
						[-999]: emptyOffer(),
					},
					Ready: { [fromPlayer.UserId]: false, [-999]: false },
					Confirmed: { [fromPlayer.UserId]: false, [-999]: false },
					ConfirmEndsAt: 0,
					Settling: false,
					Status: "Open",
					ExpiresAt: now + GameConfig.Trading.SessionSeconds,
				};
				this._sessions[session.Id] = session;
				this._byUser[fromPlayer.UserId] = session.Id;
				this._byUser[-999] = session.Id;
				this._bump();
				return $tuple(true, undefined);
			}
			const target = Players.GetPlayerByUserId(targetUserId);
			if (!truthy(target)) {
				return $tuple(false, "That player is no longer in this server.");
			}
			if (truthy(this._byUser[targetUserId])) {
				return $tuple(false, "They are already in a trade.");
			}
			const pending = this._invites[targetUserId];
			if (truthy(pending) && pending.From !== fromPlayer.UserId && pending.ExpiresAt > now) {
				return $tuple(false, "They already have an open invite.");
			}
			const previous = this._outgoing[fromPlayer.UserId];
			if (truthy(previous) && previous.To !== targetUserId) {
				const previousInvite = this._invites[previous.To];
				if (truthy(previousInvite) && previousInvite.From === fromPlayer.UserId) {
					delete this._invites[previous.To];
				}
			}
			const expiresAt = now + GameConfig.Trading.InviteSeconds;
			this._invites[targetUserId] = {
				From: fromPlayer.UserId,
				ExpiresAt: expiresAt,
			};
			this._outgoing[fromPlayer.UserId] = {
				To: targetUserId,
				ToName: target.DisplayName,
				ExpiresAt: expiresAt,
			};
			this._bump();
			return $tuple(true, undefined);
		},

		Respond(this: TradeDeskInstance, guest: Player, guestProfile: unknown, accept: boolean, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined, number | undefined]> {
			const invite = this._invites[guest.UserId];
			delete this._invites[guest.UserId];
			if (truthy(invite) && truthy(this._outgoing[invite.From]) && this._outgoing[invite.From].To === guest.UserId) {
				delete this._outgoing[invite.From];
			}
			if (!truthy(invite) || invite.ExpiresAt < now) {
				this._bump();
				return $tuple(false, "That invite expired.", undefined, undefined);
			}
			if (!accept) {
				this._bump();
				return $tuple(true, undefined, undefined, invite.From);
			}
			if (!this.Unlocked(guestProfile)) {
				return $tuple(false, "Trade Floor unlocks after your first rebirth.", undefined, invite.From);
			}
			if (truthy(this._byUser[guest.UserId]) || truthy(this._byUser[invite.From])) {
				return $tuple(false, "A trade is already open.", undefined, invite.From);
			}
			const host = Players.GetPlayerByUserId(invite.From);
			if (!truthy(host)) {
				return $tuple(false, "They left the server.", undefined, undefined);
			}
			const session: TradeSession = {
				Id: this._sessionId(),
				Host: invite.From,
				Guest: guest.UserId,
				Offers: {
					[invite.From]: emptyOffer(),
					[guest.UserId]: emptyOffer(),
				},
				Ready: { [invite.From]: false, [guest.UserId]: false },
				Confirmed: { [invite.From]: false, [guest.UserId]: false },
				ConfirmEndsAt: 0,
				Settling: false,
				Status: "Open",
				ExpiresAt: now + GameConfig.Trading.SessionSeconds,
			};
			this._sessions[session.Id] = session;
			this._byUser[invite.From] = session.Id;
			this._byUser[guest.UserId] = session.Id;
			this._bump();
			return $tuple(true, undefined, session, invite.From);
		},

		UpdateOffer(this: TradeDeskInstance, player: Player, profile: Dict, rawOffer: unknown, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session) || session.ExpiresAt < now) {
				return $tuple(false, "That trade is no longer open.", undefined);
			}
			if (session.Settling === true || session.Status === "Settling") {
				return $tuple(false, "That trade is already settling.", undefined);
			}
			if (session.Status === "RevertFailed") {
				return $tuple(false, "This trade hit an error and has to be cancelled.", undefined);
			}
			const offer = copyOffer(rawOffer);
			const reason = this._validateOffer(profile, offer, now, false);
			if (truthy(reason)) {
				return $tuple(false, reason, undefined);
			}
			stampItems(offer, profile);
			session.Offers[player.UserId] = offer;
			session.Ready[session.Host] = false;
			session.Ready[session.Guest] = false;
			session.Confirmed[session.Host] = false;
			session.Confirmed[session.Guest] = false;
			session.ConfirmEndsAt = 0;
			session.Status = "Open";
			return $tuple(true, undefined, session);
		},

		SetReady(this: TradeDeskInstance, player: Player, profile: Dict, ready: boolean, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session) || session.ExpiresAt < now) {
				return $tuple(false, "That trade is no longer open.", undefined);
			}
			if (session.Settling === true || session.Status === "Settling" || session.Status === "RevertFailed") {
				return $tuple(false, "That trade is already settling.", undefined);
			}
			if (ready) {
				const reason = this._validateOffer(profile, session.Offers[player.UserId], now, false);
				if (truthy(reason)) {
					return $tuple(false, reason, undefined);
				}
				if (offerEmpty(session.Offers[session.Host]) && offerEmpty(session.Offers[session.Guest])) {
					return $tuple(false, "Put something on the table first.", undefined);
				}
			}
			session.Ready[player.UserId] = ready === true;
			if (session.Guest === -999 || session.Host === -999) {
				const partnerId = session.Host === player.UserId ? session.Guest : session.Host;
				if (ready && offerEmpty(session.Offers[partnerId])) {
					session.Offers[partnerId].Stardust = 10;
				}
				session.Ready[partnerId] = ready === true;
			}
			session.Confirmed[session.Host] = false;
			session.Confirmed[session.Guest] = false;
			session.ConfirmEndsAt = 0;
			session.Status = "Open";
			return $tuple(true, undefined, session);
		},

		Confirm(this: TradeDeskInstance, player: Player, now: number): LuaTuple<[boolean, string | undefined, TradeSession | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session) || session.ExpiresAt < now) {
				return $tuple(false, "That trade is no longer open.", undefined);
			}
			if (session.Settling === true || session.Status === "Settling" || session.Status === "RevertFailed") {
				return $tuple(false, "That trade is already settling.", undefined);
			}
			if (session.Ready[session.Host] !== true || session.Ready[session.Guest] !== true) {
				return $tuple(false, "Both sides need to ready up first.", undefined);
			}
			if (session.ConfirmEndsAt === 0) {
				session.ConfirmEndsAt = now + GameConfig.Trading.ConfirmSeconds;
				session.Status = "Confirming";
			} else if (now > session.ConfirmEndsAt) {
				session.Confirmed[session.Host] = false;
				session.Confirmed[session.Guest] = false;
				session.ConfirmEndsAt = now + GameConfig.Trading.ConfirmSeconds;
			}
			session.Confirmed[player.UserId] = true;
			if (session.Guest === -999 || session.Host === -999) {
				const partnerId = session.Host === player.UserId ? session.Guest : session.Host;
				session.Confirmed[partnerId] = true;
			}
			return $tuple(true, undefined, session);
		},

		TryBeginSettle(this: TradeDeskInstance, session: TradeSession): boolean {
			return TradeSettle.TryBegin(session);
		},

		FailSettle(this: TradeDeskInstance, session: TradeSession, permanent?: boolean, reason?: string): void {
			TradeSettle.Fail(session, permanent, reason);
		},

		Cancel(this: TradeDeskInstance, player: Player): LuaTuple<[TradeSession | undefined, number | undefined, string | undefined]> {
			const session = this.SessionFor(player.UserId);
			if (!truthy(session)) {
				delete this._invites[player.UserId];
				return $tuple(undefined, undefined, undefined);
			}
			const [blocked, blockReason] = TradeSettle.CancelBlocked(session);
			if (blocked) {
				return $tuple(session, undefined, blockReason);
			}
			const other = session.Host === player.UserId ? session.Guest : session.Host;
			this.Close(session);
			return $tuple(session, other, undefined);
		},

		Plan(this: TradeDeskInstance, session: TradeSession, hostProfile: Dict, guestProfile: Dict, now: number): LuaTuple<[Dict | undefined, string | undefined]> {
			if (session.Confirmed[session.Host] !== true || session.Confirmed[session.Guest] !== true) {
				return $tuple(undefined, "Waiting for both confirmations.");
			}
			if (session.ConfirmEndsAt > 0 && now > session.ConfirmEndsAt) {
				return $tuple(undefined, "The confirm window expired. Ready up again.");
			}
			ensureLedger(hostProfile, now);
			ensureLedger(guestProfile, now);
			const hostTrade = hostProfile.Trade as Dict;
			const guestTrade = guestProfile.Trade as Dict;
			if ((hostTrade.Completed as number) >= GameConfig.Trading.DailyTrades || (guestTrade.Completed as number) >= GameConfig.Trading.DailyTrades) {
				return $tuple(undefined, "A daily trade limit has been reached.");
			}
			const hostOffer = copyOffer(session.Offers[session.Host]);
			const guestOffer = copyOffer(session.Offers[session.Guest]);
			const hostReason = this._validateOffer(hostProfile, hostOffer, now);
			if (truthy(hostReason)) {
				return $tuple(undefined, hostReason);
			}
			const guestReason = this._validateOffer(guestProfile, guestOffer, now);
			if (truthy(guestReason)) {
				return $tuple(undefined, guestReason);
			}
			const hostIncoming = guestOffer.ItemIds.size();
			const guestIncoming = hostOffer.ItemIds.size();
			const hostLimit = GameConfig.Items!.InventoryLimit;
			const guestLimit = GameConfig.Items!.InventoryLimit;
			if (countInventory(hostProfile) - hostOffer.ItemIds.size() + hostIncoming > hostLimit) {
				return $tuple(undefined, "Their inventory cannot hold those relics.");
			}
			if (countInventory(guestProfile) - guestOffer.ItemIds.size() + guestIncoming > guestLimit) {
				return $tuple(undefined, "Your inventory cannot hold those relics.");
			}
			return $tuple(
				{
					HostOffer: hostOffer,
					GuestOffer: guestOffer,
					HostItems: TradeExchange.SnapshotOfferItems(hostOffer, hostProfile),
					GuestItems: TradeExchange.SnapshotOfferItems(guestOffer, guestProfile),
					Now: now,
				},
				undefined,
			);
		},

		ApplyExchange(
			this: TradeDeskInstance,
			profile: Dict,
			give: TradeOfferBag,
			take: TradeOfferBag,
			giveItems: Dict | undefined,
			takeItems: Dict | undefined,
			now: number,
		): string | undefined {
			return TradeExchange.ApplyExchange(GameConfig, OmegaMath, profile, give, take, giveItems, takeItems, now, (p, offer, at) =>
				this._validateOffer(p, offer, at),
			);
		},

		RevertExchange(
			this: TradeDeskInstance,
			profile: Dict,
			give: TradeOfferBag,
			take: TradeOfferBag,
			giveItems: Dict | undefined,
			takeItems: Dict | undefined,
			now: number,
		): void {
			TradeExchange.RevertExchange(OmegaMath, profile, give, take, giveItems, takeItems, now);
		},

		Close(this: TradeDeskInstance, session: TradeSession | undefined): void {
			if (!truthy(session)) {
				return;
			}
			delete this._sessions[session.Id];
			delete this._byUser[session.Host];
			delete this._byUser[session.Guest];
			this._bump();
		},

		SessionFor(this: TradeDeskInstance, userId: number): TradeSession | undefined {
			const id = this._byUser[userId];
			return truthy(id) ? this._sessions[id] : undefined;
		},
	};
	(TradeDesk as { __index?: unknown }).__index = TradeDesk;

	return TradeDesk;
};

__defs["TradeExchange"] = () => {
	const CURRENCIES = ["Cash", "Stardust", "Cores", "Signals", "Essence"];
	const BOOST_IDS = [
		"DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush",
		"Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge",
	];
	const KEY_IDS = ["ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate"];

	function utcDay(now: number): number {
		const date = os.date("!*t", now);
		return date.year * 1000 + date.yday;
	}

	function ensureLedger(profile: Dict, now: number): void {
		if (!typeIs(profile.Trade, "table")) {
			profile.Trade = { Day: -1, Completed: 0, Sent: {} };
		}
		const trade = profile.Trade as Dict;
		const day = utcDay(now);
		if (trade.Day !== day) {
			trade.Day = day;
			trade.Completed = 0;
			trade.Sent = { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 };
		}
		if (!typeIs(trade.Sent, "table")) {
			trade.Sent = { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 };
		}
	}

	function ensureTradeBags(profile: Dict): void {
		profile.Command = typeIs(profile.Command, "table") ? profile.Command : {};
		profile.Items = typeIs(profile.Items, "table") ? profile.Items : { Inventory: {}, Keys: {}, Essence: 0 };
		const items = profile.Items as Dict;
		items.Inventory = typeIs(items.Inventory, "table") ? items.Inventory : {};
		items.Keys = typeIs(items.Keys, "table") ? items.Keys : {};
		profile.BoostInventory = typeIs(profile.BoostInventory, "table") ? profile.BoostInventory : {};
	}

	function countInventory(profile: Dict): number {
		let count = 0;
		const items = profile.Items as Dict | undefined;
		if (truthy(items) && typeIs(items.Inventory, "table")) {
			for (const _ of pairs(items.Inventory as object)) {
				count += 1;
			}
		}
		return count;
	}

	function boostTotal(offer: TradeOfferBag): number {
		let total = 0;
		for (const id of BOOST_IDS) {
			total += offer.Boosts[id];
		}
		return total;
	}

	function keyTotal(offer: TradeOfferBag): number {
		let total = 0;
		for (const id of KEY_IDS) {
			total += offer.Keys[id];
		}
		return total;
	}

	function mintItemUid(profile: Dict): string {
		const items = profile.Items as Dict;
		items.NextId = (tonumber(items.NextId) ?? 0) + 1;
		return string.format("IT%07d", items.NextId as number);
	}

	const TradeExchange = {
		CURRENCIES: CURRENCIES,
		BOOST_IDS: BOOST_IDS,
		KEY_IDS: KEY_IDS,

		CopyItemInstance(this: void, instance: unknown): Dict | undefined {
			if (!typeIs(instance, "table")) {
				return undefined;
			}
			const copy: Dict = {};
			for (const [key, value] of pairs(instance)) {
				if (typeIs(value, "table")) {
					const nested: Dict = {};
					for (const [nestedKey, nestedValue] of pairs(value)) {
						nested[nestedKey as string] = nestedValue;
					}
					copy[key as string] = nested;
				} else {
					copy[key as string] = value;
				}
			}
			return copy;
		},

		SnapshotOfferItems(this: void, offer: TradeOfferBag, profile: Dict | undefined): Dict {
			const payloads: Dict = {};
			const items = truthy(profile) ? (profile.Items as Dict | undefined) : undefined;
			const inventory = truthy(items) ? items.Inventory : undefined;
			if (!typeIs(inventory, "table")) {
				return payloads;
			}
			for (const uid of offer.ItemIds) {
				const instance = (inventory as Dict)[uid];
				if (typeIs(instance, "table")) {
					payloads[uid] = TradeExchange.CopyItemInstance(instance);
				}
			}
			return payloads;
		},

		ApplyExchange(
			this: void,
			gameConfig: TradeGameConfig,
			omegaMath: OmegaMathApi,
			profile: Dict,
			give: TradeOfferBag,
			take: TradeOfferBag,
			giveItems: Dict | undefined,
			takeItems: Dict | undefined,
			now: number,
			validateOffer?: (this: void, profile: Dict, offer: TradeOfferBag, at: number) => string | undefined,
		): string | undefined {
			ensureLedger(profile, now);
			ensureTradeBags(profile);
			if (validateOffer !== undefined) {
				const reason = validateOffer(profile, give, now);
				if (truthy(reason)) {
					return reason;
				}
			}
			let incomingCount = 0;
			if (typeIs(take, "table") && typeIs(take.ItemIds, "table")) {
				incomingCount = (take.ItemIds as unknown[]).size();
			}
			const items = profile.Items as Dict;
			if (countInventory(profile) - give.ItemIds.size() + incomingCount > gameConfig.Items!.InventoryLimit) {
				return "Inventory cannot hold those relics.";
			}

			profile.Cash = omegaMath.Sub(profile.Cash, give.Cash);
			profile.Cash = omegaMath.Add(profile.Cash, take.Cash);
			profile.Stardust = math.max(0, (tonumber(profile.Stardust) ?? 0) - give.Stardust) + take.Stardust;
			profile.Cores = math.max(0, (tonumber(profile.Cores) ?? 0) - give.Cores) + take.Cores;
			const command = profile.Command as Dict;
			command.Signals = math.max(0, (tonumber(command.Signals) ?? 0) - give.Signals) + take.Signals;
			items.Essence = math.max(0, (tonumber(items.Essence) ?? 0) - give.Essence) + take.Essence;

			const boostInventory = profile.BoostInventory as Dict;
			for (const id of BOOST_IDS) {
				const giveAmount = give.Boosts[id];
				const takeAmount = take.Boosts[id];
				if (giveAmount > 0 || takeAmount > 0) {
					boostInventory[id] = math.max(0, (tonumber(boostInventory[id]) ?? 0) - giveAmount) + takeAmount;
				}
			}
			const keys = items.Keys as Dict;
			for (const id of KEY_IDS) {
				const giveAmount = give.Keys[id];
				const takeAmount = take.Keys[id];
				if (giveAmount > 0 || takeAmount > 0) {
					keys[id] = math.max(0, (tonumber(keys[id]) ?? 0) - giveAmount) + takeAmount;
				}
			}
			const inventory = items.Inventory as Dict;
			for (const uid of give.ItemIds) {
				delete inventory[uid];
			}
			if (typeIs(take.ItemIds, "table")) {
				for (const uid of take.ItemIds) {
					const payload = takeItems !== undefined ? (takeItems[uid] as Dict | undefined) : undefined;
					if (payload !== undefined) {
						// Receiver UIDs are per-profile monotonic sequences; re-key incoming
						// items so a sender's UID can never overwrite a different relic here.
						const newUid = mintItemUid(profile);
						payload.NewUid = newUid;
						inventory[newUid] = TradeExchange.CopyItemInstance(payload);
					}
				}
			}

			const sent = (profile.Trade as Dict).Sent as Dict;
			sent.Cash = (sent.Cash as number) + give.Cash;
			sent.Stardust = (sent.Stardust as number) + give.Stardust;
			sent.Cores = (sent.Cores as number) + give.Cores;
			sent.Signals = (sent.Signals as number) + give.Signals;
			sent.Essence = (sent.Essence as number) + give.Essence;
			sent.Boost = (sent.Boost as number) + boostTotal(give);
			sent.Keys = (sent.Keys as number) + keyTotal(give);
			sent.Items = (sent.Items as number) + give.ItemIds.size();
			const trade = profile.Trade as Dict;
			trade.Completed = (trade.Completed as number) + 1;
			return undefined;
		},

		RevertExchange(
			this: void,
			omegaMath: OmegaMathApi,
			profile: Dict,
			give: TradeOfferBag,
			take: TradeOfferBag,
			giveItems: Dict | undefined,
			takeItems: Dict | undefined,
			now: number,
		): void {
			ensureLedger(profile, now);
			ensureTradeBags(profile);

			profile.Cash = omegaMath.Add(profile.Cash, give.Cash);
			profile.Cash = omegaMath.Sub(profile.Cash, take.Cash);
			profile.Stardust = math.max(0, (tonumber(profile.Stardust) ?? 0) + give.Stardust - take.Stardust);
			profile.Cores = math.max(0, (tonumber(profile.Cores) ?? 0) + give.Cores - take.Cores);
			const command = profile.Command as Dict;
			command.Signals = math.max(0, (tonumber(command.Signals) ?? 0) + give.Signals - take.Signals);
			const items = profile.Items as Dict;
			items.Essence = math.max(0, (tonumber(items.Essence) ?? 0) + give.Essence - take.Essence);

			const boostInventory = profile.BoostInventory as Dict;
			for (const id of BOOST_IDS) {
				const giveAmount = give.Boosts[id];
				const takeAmount = take.Boosts[id];
				if (giveAmount > 0 || takeAmount > 0) {
					boostInventory[id] = math.max(0, (tonumber(boostInventory[id]) ?? 0) + giveAmount - takeAmount);
				}
			}
			const keys = items.Keys as Dict;
			for (const id of KEY_IDS) {
				const giveAmount = give.Keys[id];
				const takeAmount = take.Keys[id];
				if (giveAmount > 0 || takeAmount > 0) {
					keys[id] = math.max(0, (tonumber(keys[id]) ?? 0) + giveAmount - takeAmount);
				}
			}
			const inventory = items.Inventory as Dict;
			if (typeIs(take.ItemIds, "table")) {
				for (const uid of take.ItemIds) {
					const payload = takeItems !== undefined ? (takeItems[uid] as Dict | undefined) : undefined;
					const removeUid = (typeIs(payload, "table") && truthy(payload.NewUid) ? payload.NewUid : uid) as string;
					delete inventory[removeUid];
				}
			}
			for (const uid of give.ItemIds) {
				const payload = giveItems !== undefined ? giveItems[uid] : undefined;
				if (payload !== undefined) {
					inventory[uid] = TradeExchange.CopyItemInstance(payload);
				}
			}

			const sent = (profile.Trade as Dict).Sent as Dict;
			sent.Cash = math.max(0, ((sent.Cash as number | undefined) ?? 0) - give.Cash);
			sent.Stardust = math.max(0, ((sent.Stardust as number | undefined) ?? 0) - give.Stardust);
			sent.Cores = math.max(0, ((sent.Cores as number | undefined) ?? 0) - give.Cores);
			sent.Signals = math.max(0, ((sent.Signals as number | undefined) ?? 0) - give.Signals);
			sent.Essence = math.max(0, ((sent.Essence as number | undefined) ?? 0) - give.Essence);
			sent.Boost = math.max(0, ((sent.Boost as number | undefined) ?? 0) - boostTotal(give));
			sent.Keys = math.max(0, ((sent.Keys as number | undefined) ?? 0) - keyTotal(give));
			sent.Items = math.max(0, ((sent.Items as number | undefined) ?? 0) - give.ItemIds.size());
			const trade = profile.Trade as Dict;
			trade.Completed = math.max(0, ((trade.Completed as number | undefined) ?? 0) - 1);
		},
	};

	return table.freeze(TradeExchange);
};

__defs["TradeOfferMath"] = () => {
	function utcDay(now: number): number {
		const date = os.date("!*t", now);
		return date.year * 1000 + date.yday;
	}

	const TradeOfferMath = {
		EmptyOffer(this: void, boostIds: string[], keyIds: string[]): TradeOfferBag {
			const boosts: Record<string, number> = {};
			for (const id of boostIds) {
				boosts[id] = 0;
			}
			const keys: Record<string, number> = {};
			for (const id of keyIds) {
				keys[id] = 0;
			}
			return {
				Cash: 0,
				Stardust: 0,
				Cores: 0,
				Signals: 0,
				Essence: 0,
				Boosts: boosts,
				Keys: keys,
				ItemIds: [],
			};
		},

		CopyOffer(this: void, offer: unknown, currencies: string[], boostIds: string[], keyIds: string[]): TradeOfferBag {
			const nextOffer = TradeOfferMath.EmptyOffer(boostIds, keyIds);
			if (!typeIs(offer, "table")) {
				return nextOffer;
			}
			const bag = offer as Dict;
			for (const key of currencies) {
				nextOffer[key] = math.max(0, math.floor(tonumber(bag[key]) ?? 0));
			}
			if (typeIs(bag.Boosts, "table")) {
				const boosts = bag.Boosts as Dict;
				for (const id of boostIds) {
					nextOffer.Boosts[id] = math.max(0, math.floor(tonumber(boosts[id]) ?? 0));
				}
			}
			if (typeIs(bag.Keys, "table")) {
				const keys = bag.Keys as Dict;
				for (const id of keyIds) {
					nextOffer.Keys[id] = math.max(0, math.floor(tonumber(keys[id]) ?? 0));
				}
			}
			if (typeIs(bag.ItemIds, "table")) {
				const seen: Record<string, boolean> = {};
				for (const uid of bag.ItemIds as unknown[]) {
					if (typeIs(uid, "string") && uid !== "" && !seen[uid]) {
						seen[uid] = true;
						nextOffer.ItemIds.push(uid);
					}
				}
			}
			if (typeIs(bag.Items, "table")) {
				const itemsList: TradeOfferItem[] = [];
				for (const row of bag.Items as unknown[]) {
					const rowBag = row as Dict;
					if (typeIs(row, "table") && typeIs(rowBag.Uid, "string")) {
						itemsList.push({
							Uid: rowBag.Uid,
							DefinitionId: typeIs(rowBag.DefinitionId, "string") ? rowBag.DefinitionId : "",
							Name: typeIs(rowBag.Name, "string") ? rowBag.Name : "Relic",
						});
					}
				}
				nextOffer.Items = itemsList;
			}
			return nextOffer;
		},

		OfferEmpty(this: void, offer: unknown, currencies: string[], boostIds: string[], keyIds: string[]): boolean {
			if (!typeIs(offer, "table")) {
				return true;
			}
			const bag = offer as Dict;
			for (const key of currencies) {
				if ((tonumber(bag[key]) ?? 0) > 0) {
					return false;
				}
			}
			const boosts = bag.Boosts;
			if (typeIs(boosts, "table")) {
				const boostsBag = boosts as Dict;
				for (const id of boostIds) {
					if ((tonumber(boostsBag[id]) ?? 0) > 0) {
						return false;
					}
				}
			}
			const keys = bag.Keys;
			if (typeIs(keys, "table")) {
				const keysBag = keys as Dict;
				for (const id of keyIds) {
					if ((tonumber(keysBag[id]) ?? 0) > 0) {
						return false;
					}
				}
			}
			const itemIds = bag.ItemIds;
			return !typeIs(itemIds, "table") || (itemIds as unknown[]).size() === 0;
		},

		BoostTotal(this: void, offer: unknown, boostIds: string[]): number {
			let total = 0;
			const bag = offer as Dict;
			if (!typeIs(offer, "table") || !typeIs(bag.Boosts, "table")) {
				return 0;
			}
			const boosts = bag.Boosts as Dict;
			for (const id of boostIds) {
				total += math.max(0, math.floor(tonumber(boosts[id]) ?? 0));
			}
			return total;
		},

		KeyTotal(this: void, offer: unknown, keyIds: string[]): number {
			let total = 0;
			const bag = offer as Dict;
			if (!typeIs(offer, "table") || !typeIs(bag.Keys, "table")) {
				return 0;
			}
			const keys = bag.Keys as Dict;
			for (const id of keyIds) {
				total += math.max(0, math.floor(tonumber(keys[id]) ?? 0));
			}
			return total;
		},

		EnsureLedger(this: void, profile: unknown, now: number): void {
			if (!typeIs(profile, "table")) {
				return;
			}
			const bag = profile as Dict;
			if (!typeIs(bag.Trade, "table")) {
				bag.Trade = { Day: -1, Completed: 0, Sent: {} };
			}
			const trade = bag.Trade as Dict;
			const day = utcDay(now);
			const emptySent = {
				Cash: 0,
				Stardust: 0,
				Cores: 0,
				Signals: 0,
				Essence: 0,
				Boost: 0,
				Keys: 0,
				Items: 0,
			};
			if (trade.Day !== day) {
				trade.Day = day;
				trade.Completed = 0;
				trade.Sent = emptySent;
			}
			if (!typeIs(trade.Sent, "table")) {
				trade.Sent = emptySent;
			}
		},

		ItemEquipped(this: void, profile: unknown, uid: string): boolean {
			if (!typeIs(uid, "string") || uid === "") {
				return false;
			}
			const bag = profile as Dict;
			const items = bag.Items as Dict | undefined;
			if (!typeIs(profile, "table") || !typeIs(items, "table") || !typeIs(items.Equipped, "table")) {
				return false;
			}
			for (const [, equipped] of pairs(items.Equipped as object)) {
				if (equipped === uid) {
					return true;
				}
			}
			return false;
		},

		CountInventory(this: void, profile: unknown): number {
			let count = 0;
			const bag = profile as Dict;
			const items = truthy(bag) ? (bag.Items as Dict | undefined) : undefined;
			if (typeIs(profile, "table") && truthy(items) && typeIs(items.Inventory, "table")) {
				for (const _ of pairs(items.Inventory as object)) {
					count += 1;
				}
			}
			return count;
		},
	};

	return table.freeze(TradeOfferMath);
};

__defs["TradeSettle"] = () => {
	const TradeSettle = {
		REVERT_ATTEMPTS: 3,
		ADMIN_NOTE: "Trade settle recovery",
		REASON_GUEST_LEFT: "guest-left-during-settle",
		REASON_GUEST_APPLY: "guest-apply-failed",
		REASON_HOST_REVERT: "host-revert-failed",
		KIND_COMPLETE: "complete",
		KIND_HOST_FAILED: "host-failed",
		KIND_GUEST_LEFT: "guest-left",
		KIND_GUEST_FAILED: "guest-failed",

		TryBegin(this: void, session: TradeSession | undefined): boolean {
			if (!truthy(session)) {
				return false;
			}
			if (session.Settling === true || session.Status === "Settling" || session.Status === "RevertFailed") {
				return false;
			}
			if (session.Confirmed[session.Host] !== true || session.Confirmed[session.Guest] !== true) {
				return false;
			}
			session.Settling = true;
			session.Status = "Settling";
			return true;
		},

		Fail(this: void, session: TradeSession | undefined, permanent?: boolean, reason?: string): void {
			if (!truthy(session)) {
				return;
			}
			session.Settling = false;
			session.Confirmed[session.Host] = false;
			session.Confirmed[session.Guest] = false;
			session.ConfirmEndsAt = 0;
			if (truthy(permanent)) {
				session.Status = "RevertFailed";
				session.RevertFailedAt = os.time();
				session.RevertFailedReason =
					typeIs(reason, "string") && reason !== "" ? reason : TradeSettle.REASON_HOST_REVERT;
			} else {
				session.Status = "Open";
				session.RevertFailedAt = undefined;
				session.RevertFailedReason = undefined;
			}
		},

		CancelBlocked(this: void, session: TradeSession | undefined): LuaTuple<[boolean, string | undefined]> {
			if (!truthy(session)) {
				return $tuple(false, undefined);
			}
			if (session.Settling === true || session.Status === "Settling") {
				return $tuple(true, "That trade is already settling.");
			}
			return $tuple(false, undefined);
		},

		RevertWithRetries(this: void, attempts: number | undefined, tryOnce: () => boolean): boolean {
			const limit = math.max(1, math.floor(tonumber(attempts) ?? TradeSettle.REVERT_ATTEMPTS));
			for (const _ of $range(1, limit)) {
				if (tryOnce()) {
					return true;
				}
			}
			return false;
		},

		GuestLeftMessage(this: void, reverted: boolean): string {
			if (reverted) {
				return "Your partner left before the trade finished. Your items were returned.";
			}
			return "Guest left and host revert failed. Cancel and contact support.";
		},

		GuestApplyMessage(this: void, reverted: boolean, applyError?: string): string {
			if (!reverted) {
				return "Guest side failed and host revert did not commit. Cancel the table and contact support.";
			}
			if (typeIs(applyError, "string") && applyError !== "") {
				return applyError;
			}
			return "Guest side of the trade failed.";
		},

		FormatRevertFailedLog(this: void, sessionId: unknown, hostId: number, guestId: number, reason: string): string {
			return string.format(
				"RevertFailed session=%s host=%d guest=%d reason=%s — cancel table; admin note: %s",
				tostring(sessionId),
				hostId,
				guestId,
				reason,
				TradeSettle.ADMIN_NOTE,
			);
		},

		IsCommitOk(this: void, committed: boolean | undefined, result: unknown): boolean {
			return committed === true && typeIs(result, "table") && (result as Dict).ok === true;
		},

		CommitError(this: void, result: unknown): string | undefined {
			if (typeIs(result, "table") && typeIs((result as Dict).error, "string") && (result as Dict).error !== "") {
				return (result as Dict).error as string;
			}
			return undefined;
		},

		RunHostGuest(this: void, session: TradeSession, hooks: Dict): Dict {
			assert(typeIs(hooks, "table"), "RunHostGuest requires hooks");
			assert(typeIs(hooks.applyHost, "function"), "hooks.applyHost required");
			assert(typeIs(hooks.guestPresent, "function"), "hooks.guestPresent required");
			assert(typeIs(hooks.applyGuest, "function"), "hooks.applyGuest required");
			assert(typeIs(hooks.revertHostOnce, "function"), "hooks.revertHostOnce required");

			const applyHost = hooks.applyHost as () => LuaTuple<[boolean | undefined, unknown]>;
			const guestPresent = hooks.guestPresent as () => boolean;
			const applyGuest = hooks.applyGuest as () => LuaTuple<[boolean | undefined, unknown]>;
			const revertHostOnce = hooks.revertHostOnce as () => boolean;

			// Optional per-profile journal hooks for durable trade settlement.
			const writeHostJournal = hooks.writeHostJournal as ((status: string, reason?: string) => void) | undefined;
			const writeGuestJournal = hooks.writeGuestJournal as ((status: string, reason?: string) => void) | undefined;
			const plan = hooks.plan;
			void plan;

			function safeHostJournal(status: string, reason?: string): void {
				if (!typeIs(writeHostJournal, "function")) {
					return;
				}
				pcall(writeHostJournal, status, reason);
			}
			function safeGuestJournal(status: string, reason?: string): void {
				if (!typeIs(writeGuestJournal, "function")) {
					return;
				}
				pcall(writeGuestJournal, status, reason);
			}

			// Record intent on both profiles before any mutation commits.
			safeHostJournal("pending");
			safeGuestJournal("pending");

			const [hostCommitted, hostResult] = applyHost();
			if (!TradeSettle.IsCommitOk(hostCommitted, hostResult)) {
				safeHostJournal("aborted", TradeSettle.CommitError(hostResult) ?? "host-apply-failed");
				safeGuestJournal("aborted");
				TradeSettle.Fail(session, false);
				return {
					ok: false,
					kind: TradeSettle.KIND_HOST_FAILED,
					message: TradeSettle.CommitError(hostResult) ?? "Host side of the trade failed.",
					permanent: false,
				};
			}

			// Host side is now committed; mark it locked/escrow before attempting guest commit.
			// This in-memory flag and the journal status let recovery know the host side
			// may need to be reverted if the guest side cannot complete.
			session.HostCommitted = true;
			safeHostJournal("locked");

			if (!guestPresent()) {
				safeGuestJournal("aborted", "guest-absent");
				const reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, revertHostOnce);
				if (reverted) {
					safeHostJournal("reverted", TradeSettle.REASON_GUEST_LEFT);
				}
				TradeSettle.Fail(session, !reverted, TradeSettle.REASON_GUEST_LEFT);
				const outcome: Dict = {
					ok: false,
					kind: TradeSettle.KIND_GUEST_LEFT,
					message: TradeSettle.GuestLeftMessage(reverted),
					permanent: !reverted,
					reason: TradeSettle.REASON_GUEST_LEFT,
				};
				if (!reverted) {
					outcome.log = TradeSettle.FormatRevertFailedLog(
						session.Id,
						session.Host,
						session.Guest,
						TradeSettle.REASON_GUEST_LEFT,
					);
					// Never silently fault: stamp a durable faulted journal entry.
					safeHostJournal("faulted", TradeSettle.REASON_GUEST_LEFT);
					safeGuestJournal("faulted", TradeSettle.REASON_GUEST_LEFT);
				}
				return outcome;
			}

			const [guestCommitted, guestResult] = applyGuest();
			if (!TradeSettle.IsCommitOk(guestCommitted, guestResult)) {
				const reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, revertHostOnce);
				if (reverted) {
					safeHostJournal("reverted", TradeSettle.REASON_GUEST_APPLY);
				}
				TradeSettle.Fail(session, !reverted, TradeSettle.REASON_GUEST_APPLY);
				const outcome: Dict = {
					ok: false,
					kind: TradeSettle.KIND_GUEST_FAILED,
					message: TradeSettle.GuestApplyMessage(reverted, TradeSettle.CommitError(guestResult)),
					permanent: !reverted,
					reason: TradeSettle.REASON_GUEST_APPLY,
				};
				if (!reverted) {
					outcome.log = TradeSettle.FormatRevertFailedLog(
						session.Id,
						session.Host,
						session.Guest,
						TradeSettle.REASON_GUEST_APPLY,
					);
					// Never silently fault: stamp a durable faulted journal entry.
					safeHostJournal("faulted", TradeSettle.REASON_GUEST_APPLY);
					safeGuestJournal("faulted", TradeSettle.REASON_GUEST_APPLY);
				}
				return outcome;
			}

			safeHostJournal("settled");
			safeGuestJournal("settled");
			return {
				ok: true,
				kind: TradeSettle.KIND_COMPLETE,
				permanent: false,
			};
		},
	};

	return table.freeze(TradeSettle);
};

__defs["TradeRecovery"] = () => {
	const TradeExchange = __load("TradeExchange") as TradeExchangeApi;

	function safeRequireOmegaMath(): OmegaMathApi | undefined {
		const [ok, OmegaMath] = pcall(
			() =>
				require(
					game
						.GetService("ReplicatedStorage")
						.WaitForChild("AstralForge")
						.WaitForChild("Shared")
						.WaitForChild("OmegaMath") as ModuleScript,
				) as OmegaMathApi,
		);
		if (ok) {
			return OmegaMath;
		}
		return undefined;
	}

	function ensureTradeJournal(profile: Dict): void {
		if (!typeIs(profile.Trade, "table")) {
			profile.Trade = { Day: -1, Completed: 0, Sent: {}, Journal: {}, FaultedJournal: undefined };
		}
		const trade = profile.Trade as Dict;
		if (!typeIs(trade.Journal, "table")) {
			trade.Journal = {};
		}
	}

	const TradeRecovery = {
		// Build a serializable record of a faulted trade for later reconciliation.
		MakeFaultedEntry(this: void, session: TradeSession, side: string, plan: unknown, reason: string, now: number): Dict {
			const entry: Dict = {
				SessionId: session.Id,
				Side: side,
				Host: session.Host,
				Guest: session.Guest,
				Status: "faulted",
				Reason: reason,
				At: now,
				HostCommitted: session.HostCommitted === true,
				GuestCommitted: session.GuestCommitted === true,
				HostReverted: false,
				GuestReverted: false,
			};
			if (side === "host" && typeIs(plan, "table")) {
				const planBag = plan as Dict;
				entry.Give = planBag.HostOffer;
				entry.Take = planBag.GuestOffer;
				entry.GiveItems = planBag.HostItems;
				entry.TakeItems = planBag.GuestItems;
			} else if (side === "guest" && typeIs(plan, "table")) {
				const planBag = plan as Dict;
				entry.Give = planBag.GuestOffer;
				entry.Take = planBag.HostOffer;
				entry.GiveItems = planBag.GuestItems;
				entry.TakeItems = planBag.HostItems;
			}
			return entry;
		},

		// Reconcile a faulted trade journal against a freshly loaded profile.
		// Only touches the local profile; each side recovers independently on load.
		RecoverFaulted(this: void, profile: Dict, now: number, log?: (this: void, message: string) => void): void {
			ensureTradeJournal(profile);
			const trade = profile.Trade as Dict;
			const entry = trade.FaultedJournal as Dict | undefined;
			if (!typeIs(entry, "table") || entry.Status !== "faulted") {
				trade.FaultedJournal = undefined;
				return;
			}

			const OmegaMath = safeRequireOmegaMath();
			if (!truthy(OmegaMath)) {
				// OmegaMath is not available outside runtime; leave the entry for manual review.
				return;
			}

			const side = entry.Side;
			const committed = side === "host" && truthy(entry.HostCommitted) ? entry.HostCommitted : entry.GuestCommitted;
			const reverted = side === "host" && truthy(entry.HostReverted) ? entry.HostReverted : entry.GuestReverted;
			if (truthy(committed) && !truthy(reverted) && typeIs(entry.Give, "table") && typeIs(entry.Take, "table")) {
				TradeExchange.RevertExchange(
					OmegaMath,
					profile,
					entry.Give as TradeOfferBag,
					entry.Take as TradeOfferBag,
					entry.GiveItems as Dict | undefined,
					entry.TakeItems as Dict | undefined,
					now,
				);
				if (side === "host") {
					entry.HostReverted = true;
				} else {
					entry.GuestReverted = true;
				}
				entry.RecoveredAt = now;
				entry.Status = "recovered";
				if (typeIs(log, "function")) {
					log(
						string.format(
							"Recovered faulted trade session=%s side=%s host=%d guest=%d reason=%s",
							tostring(entry.SessionId),
							tostring(side),
							tonumber(entry.Host) ?? 0,
							tonumber(entry.Guest) ?? 0,
							tostring(entry.Reason),
						),
					);
				}
			}
			trade.FaultedJournal = undefined;
		},
	};

	return table.freeze(TradeRecovery);
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type TradeSuiteCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const TradeSuite = setmetatable({}, {
	__call: (_self: unknown, name: string): unknown => __load(name),
	__index: (_self: unknown, name: string): unknown => name === "__members" ? __members : __load(name),
} as LuaMetatable<object>) as unknown as TradeSuiteCallable;

export = TradeSuite;
