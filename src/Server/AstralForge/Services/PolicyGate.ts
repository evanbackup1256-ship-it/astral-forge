// Per-player PolicyService answers for paid random items and trading. Looked up once on join and
// cached for the session; a failed lookup restricts the player and is retried a little later.
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";

const Players = game.GetService("Players");
const PolicyService = game.GetService("PolicyService");

const RETRY_AFTER = 30;

interface Entry {
	policy: PlayPolicy.PlayPolicy;
	retryAt?: number;
	pending?: boolean;
}

const entries = new Map<Player, Entry>();

// swapped out by tests; the live server always asks PolicyService
let lookup = (player: Player): unknown => PolicyService.GetPolicyInfoForPlayerAsync(player);

function fetch(player: Player): PlayPolicy.PlayPolicy {
	const [ok, info] = pcall(lookup, player);
	const policy = PlayPolicy.fromPolicyInfo(ok, info);
	if (player.Parent === Players || entries.has(player)) {
		entries.set(player, { policy, retryAt: policy.Known ? undefined : os.clock() + RETRY_AFTER });
	}
	return policy;
}

export function Get(player: Player): PlayPolicy.PlayPolicy {
	const entry = entries.get(player);
	if (entry === undefined) {
		return fetch(player);
	}
	if (entry.retryAt !== undefined && os.clock() >= entry.retryAt && entry.pending !== true) {
		entry.pending = true;
		task.spawn(() => {
			fetch(player);
		});
	}
	return entry.policy;
}

export function OfferBlocked(player: Player, offer: { Kind?: unknown; Currency?: unknown; Price?: unknown } | undefined) {
	return PlayPolicy.isPaidRandomOffer(offer) ? PlayPolicy.offerBlocked(Get(player), offer) : undefined;
}

export function TradeBlocked(player: Player, action: string, payload: unknown): string | undefined {
	if (!PlayPolicy.TRADE_ACTIONS.has(action)) {
		return undefined;
	}
	const own = PlayPolicy.tradeBlocked(Get(player), action);
	if (own !== undefined) {
		return own;
	}
	if (action === "InviteTrade" && typeIs(payload, "table")) {
		const target = Players.GetPlayerByUserId(tonumber((payload as { UserId?: unknown }).UserId) ?? 0);
		if (target !== undefined && PlayPolicy.tradeBlocked(Get(target), action) !== undefined) {
			return PlayPolicy.Copy.TradingPartner;
		}
	}
	return undefined;
}

export function Forget(player: Player) {
	entries.delete(player);
}

export function SetLookupForTests(replacement: (player: Player) => unknown) {
	lookup = replacement;
	entries.clear();
}

let started = false;
export function Start() {
	if (started) {
		return;
	}
	started = true;
	Players.PlayerAdded.Connect((player) => {
		task.spawn(() => {
			fetch(player);
		});
	});
	Players.PlayerRemoving.Connect(Forget);
	for (const player of Players.GetPlayers()) {
		task.spawn(() => {
			fetch(player);
		});
	}
}
