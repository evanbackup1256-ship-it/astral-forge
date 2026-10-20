import { useClientSelector } from "../CoreKit/clientStore";
import { asFlux } from "../CoreKit/format";

// Chip-level live values (B35). The shell's `state` prop is the store's `client.session` (MainGame
// passes useClientSelector((c) => c.session) straight through), so reading the same field here gives
// the same value on the same store change; only this chip redraws on a cash tick, not the chrome.

type SessionBag = Record<string, unknown> | undefined;

// `key` undefined: not live, returns undefined and never re-renders the caller
export function useLiveSessionValue(key: string | undefined): unknown {
	return useClientSelector((client) => (key !== undefined ? (client.session as SessionBag)?.[key] : undefined));
}

// same formula TopBar used for the island's vaultFull; a boolean, so it only re-renders when it flips
export function vaultFullOf(session: SessionBag): boolean {
	if (session === undefined) return false;
	const capacity = asFlux(session.Capacity);
	return capacity > 0 && asFlux(session.Vault) >= capacity * 0.99;
}

export function useLiveVaultFull(enabled: boolean): boolean | undefined {
	return useClientSelector((client) => (enabled ? vaultFullOf(client.session as SessionBag) : undefined));
}
