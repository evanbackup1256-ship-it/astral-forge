// Per-category token buckets for remote actions. Each category has its own burst size and
// refill rate, so a burst of shop clicks can't starve reads and chat spam can't hide behind
// gameplay traffic. Bursts are sized for a client that queued requests during a lag spike
// and then sends them all at once.

export type Category = "Read" | "Purchase" | "Trade" | "Social" | "Claim" | "Admin" | "Gameplay";

export interface BucketRule {
	Burst: number;
	PerSecond: number;
}

export const RULES: Record<Category, BucketRule> = {
	Read: { Burst: 40, PerSecond: 20 },
	Purchase: { Burst: 40, PerSecond: 20 },
	Trade: { Burst: 24, PerSecond: 5 },
	Social: { Burst: 12, PerSecond: 1.5 },
	Claim: { Burst: 24, PerSecond: 6 },
	Admin: { Burst: 8, PerSecond: 1 },
	Gameplay: { Burst: 48, PerSecond: 24 },
};

const EXPLICIT: Record<string, Category> = {
	MeasureLatency: "Read",
	ReportPresence: "Read",
	ReportPerformance: "Read",
	VisitPlot: "Read",
	LeavePlot: "Read",
	OpenItemCrate: "Purchase",
	SpinWheel: "Purchase",
	RedeemCode: "Purchase",
	SyncShop: "Purchase",
	StudioGrantProduct: "Purchase",
	BazaarPlay: "Purchase",
	RequestProcurement: "Purchase",
	FuseRelics: "Purchase",
	UnlockZone: "Purchase",
	AdminExecute: "Admin",
	ModerateGuildLogo: "Admin",
	SubmitFeedback: "Social",
	ReportPlayer: "Social",
	NudgeCrew: "Social",
	ChatOpenWhisper: "Social",
	ChatGlobal: "Social",
	SendGuildChat: "Social",
	TradeChat: "Social",
	CrewInvite: "Social",
	CrewRename: "Social",
	RenameGuild: "Social",
	CreateGuild: "Social",
	CreateGuildAnnouncement: "Social",
	EditGuildAnnouncement: "Social",
	UploadGuildLogo: "Social",
};

export function CategoryOf(action: string): Category {
	const explicit = EXPLICIT[action];
	if (explicit !== undefined) {
		return explicit;
	}
	if (string.sub(action, 1, 3) === "Get") {
		return "Read";
	}
	if (string.find(action, "Trade")[0] !== undefined) {
		return "Trade";
	}
	if (string.sub(action, 1, 3) === "Buy") {
		return "Purchase";
	}
	if (string.sub(action, 1, 5) === "Claim") {
		return "Claim";
	}
	return "Gameplay";
}

interface Bucket {
	tokens: number;
	at: number;
}

export class ActionBuckets {
	private buckets = new Map<Category, Bucket>();

	/** Takes one token from the action's category. `slow` scales refill down (0..1) while throttled. */
	Take(action: string, now: number, slow = 1): LuaTuple<[boolean, Category]> {
		const category = CategoryOf(action);
		const rule = RULES[category];
		let bucket = this.buckets.get(category);
		if (bucket === undefined) {
			bucket = { tokens: rule.Burst, at: now };
			this.buckets.set(category, bucket);
		}
		const elapsed = math.max(0, now - bucket.at);
		bucket.at = now;
		bucket.tokens = math.min(rule.Burst, bucket.tokens + elapsed * rule.PerSecond * slow);
		if (bucket.tokens < 1) {
			return $tuple(false, category);
		}
		bucket.tokens -= 1;
		return $tuple(true, category);
	}

	Tokens(category: Category): number {
		return this.buckets.get(category)?.tokens ?? RULES[category].Burst;
	}
}
