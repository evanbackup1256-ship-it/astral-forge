// Memo comparators for the shell chrome (TopBar, Navigation, MobileTabBar, MobileHeader).
// Every prop except `state` is compared by reference, so no prop can be missed.
// `state` is compared section by section on the top-level keys each component reads,
// directly or through helpers (appNav, BuffStrip, levelRoadmap, serverEventsUi). Pushes keep
// unchanged sections by reference (MainGame fills `Reused` keys from its cache) and send changed
// sections as new tables, so a reference check per key is exact; at worst it redraws, never goes stale.

type Props = Record<string, unknown>;

// AppHelpers.featureUnlocked / navUnlocked / filterNav / navBadge (CoreKit/appNav.ts).
// Cash is not here: in appNav only the upgrade-quote helper reads it, and the chrome never calls that.
export const NAV_STATE_KEYS = [
	"Admin", "Command", "Convergence", "FeatureUnlocks", "Flags", "ForgeEchoes",
	"Items", "Mailbox", "Rebirths", "Story", "Trade", "Zone",
] as const;

// BuffStrip.list (BuffStrip.tsx), used by the TopBar island
const BUFF_STATE_KEYS = [
	"ActiveBoost", "Ascension", "Continuum", "FluxSurge", "GuildBonuses", "Level", "PermanentMultiplier", "ServerEvent",
] as const;

// TopBarChrome.tsx direct reads + featureUnlocked + BuffStrip island + ServerEventChip.
// No Cash/Vault (B35): the FLUX StatChip and the island read Cash, and the island its vault-full flag,
// live from the store (UiCore/liveSession.ts), so cash ticks redraw those chips, not the whole bar.
export const TOPBAR_STATE_KEYS: ReadonlyArray<string> = [
	"Capacity", "Cores", "Production", "ServerEvent", "Settings", "Stardust", "Visitors", "FeatureUnlocks",
	...BUFF_STATE_KEYS,
];

// NavChrome.tsx only reads state through appNav helpers
export const NAVIGATION_STATE_KEYS: ReadonlyArray<string> = [...NAV_STATE_KEYS];

// MobileShell.tsx direct reads + appNav helpers + readLevelState + ServerEvent; shared by tab bar and header.
// No Cash/Vault (B35): the header's FLUX chip reads Cash live; Vault is only read by MobileQuickActions,
// which isn't memoised.
export const MOBILE_STATE_KEYS: ReadonlyArray<string> = [
	"Capacity", "Cores", "Flags", "ServerEvent", "Stardust", "Visitors", "Level",
	...NAV_STATE_KEYS,
];

export function sameChromeProps(stateKeys: ReadonlyArray<string>) {
	return (prevProps: object, nextProps: object): boolean => {
		const prev = prevProps as Props;
		const incoming = nextProps as Props;
		for (const [key, value] of pairs(incoming)) {
			if (key !== "state" && prev[key as string] !== value) return false;
		}
		for (const [key, value] of pairs(prev)) {
			if (key !== "state" && incoming[key as string] !== value) return false;
		}
		const a = prev.state as Props | undefined;
		const b = incoming.state as Props | undefined;
		if (a === b) return true;
		if (a === undefined || b === undefined) return false;
		for (const key of stateKeys) {
			if (a[key] !== b[key]) return false;
		}
		return true;
	};
}
