export const MIN_COLLECTABLE = 0.01;
export const NEAR_FULL = 0.85;
export const FULL = 0.99;

export function isEligible(vaultFlux: unknown): boolean {
	const amount = tonumber(vaultFlux) ?? 0;
	return amount >= MIN_COLLECTABLE;
}

export function isFull(fill: unknown): boolean {
	const ratio = tonumber(fill) ?? 0;
	return ratio >= FULL;
}
