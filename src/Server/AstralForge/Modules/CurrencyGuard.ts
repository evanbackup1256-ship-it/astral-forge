// CurrencyGuard: no profile update may leave a wallet balance below zero (audit follow-up).
// sanitize used to clamp a negative balance back to 0 after the fact, which turned an overdraft
// into a discount (and the hot production/overcharge paths skip sanitize altogether). Now every
// AtomicUpdate reads the wallet before its callback and refuses the whole transaction when a
// balance it lowered ends up negative or non-finite. A balance that was already bad on load is
// not a reason to block unrelated updates; sanitize repairs it as before.
import { Currencies } from "./EconomyLedger";

type Dict = Record<string, unknown>;

export interface SignMath {
	Lt(this: void, left: never, right: never): boolean;
}

function read(profile: Dict, path: string): unknown {
	let node: unknown = profile;
	for (const part of path.split(".")) {
		if (!typeIs(node, "table")) return undefined;
		node = (node as Dict)[part];
	}
	return node;
}

function bad(value: unknown, omega: SignMath): boolean {
	if (value === undefined) return false;
	if (typeIs(value, "number")) return value !== value || value < 0 || value === -math.huge;
	if (typeIs(value, "string")) {
		const [ok, negative] = pcall(() => omega.Lt(value as never, 0 as never));
		return !ok || negative === true;
	}
	return false;
}

/** The wallet values before an update (paths as in EconomyLedger.Currencies). */
export function Read(profile: Dict): Record<string, unknown> {
	const wallet: Record<string, unknown> = {};
	for (const path of Currencies) wallet[path] = read(profile, path);
	return wallet;
}

/** The first currency the update overdrew, or undefined when the wallet is fine. */
export function Overdrawn(before: Record<string, unknown>, profile: Dict, omega: SignMath): string | undefined {
	for (const path of Currencies) {
		const now = read(profile, path);
		if (now === before[path]) continue;
		if (bad(now, omega) && !bad(before[path], omega)) return path;
	}
	return undefined;
}
