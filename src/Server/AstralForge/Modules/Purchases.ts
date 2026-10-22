// Purchases: the one place that decides what a game pass or developer product does to a profile.
//
// Every entry point (ProcessReceipt, PromptGamePassPurchaseFinished, the ownership sync on join
// and the Studio test grant) goes through these functions, so a purchase is applied at most once:
//   - passes are a set keyed by pass Key, so granting twice is a no-op;
//   - products are keyed by Roblox PurchaseId in profile.Receipts (see ReceiptLedger), so a
//     receipt Roblox retries after a failed save is acknowledged without paying out again.
// Save shape is unchanged: profile.OwnedPasses[Key] = true, profile.Receipts[PurchaseId] = unix time.

import ReceiptLedger from "./ReceiptLedger";

type Dict = Record<string, unknown>;

export interface PassDef {
	Key: string;
	Name: string;
	PassId?: number;
	ProductionBonus?: number;
	CapacityBonus?: number;
}

export type PassGrant = { granted: boolean; name: string };

export type ReceiptOutcome =
	| { kind: "duplicate" }
	| { kind: "granted"; rewardText: string };

function bag(profile: Dict, field: "OwnedPasses" | "Receipts"): Dict {
	if (!typeIs(profile[field], "table")) {
		profile[field] = {};
	}
	return profile[field] as Dict;
}

/** Ensures both purchase tables exist on an old or damaged profile. */
export function ensureTables(profile: Dict) {
	bag(profile, "OwnedPasses");
	bag(profile, "Receipts");
}

/** Marks a pass owned. Safe to call any number of times. */
export function grantPass(profile: Dict, pass: PassDef): PassGrant {
	const owned = bag(profile, "OwnedPasses");
	if (owned[pass.Key] === true) {
		return { granted: false, name: pass.Name };
	}
	owned[pass.Key] = true;
	return { granted: true, name: pass.Name };
}

/** Short perk line for a pass, e.g. "+10% production · +25% vault". */
export function passPerks(pass: PassDef): string {
	const parts: string[] = [];
	const production = tonumber(pass.ProductionBonus) ?? 0;
	const capacity = tonumber(pass.CapacityBonus) ?? 0;
	if (production > 0) {
		parts.push(string.format("+%d%% production", math.floor(production * 100 + 0.5)));
	}
	if (capacity > 0) {
		parts.push(string.format("+%d%% vault", math.floor(capacity * 100 + 0.5)));
	}
	return parts.size() > 0 ? parts.join(" · ") : "Pass linked";
}

/**
 * Applies one developer-product receipt. `payout` runs only the first time a PurchaseId is seen.
 * Call inside a profile transaction; the caller still has to save before acknowledging Roblox.
 */
export function applyReceipt(profile: Dict, purchaseId: string, now: number, payout: () => string): ReceiptOutcome {
	const [recorded, duplicate] = ReceiptLedger.Record(profile.Receipts, purchaseId, now);
	profile.Receipts = recorded;
	if (duplicate) {
		return { kind: "duplicate" };
	}
	return { kind: "granted", rewardText: payout() };
}
