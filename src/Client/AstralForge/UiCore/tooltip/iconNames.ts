// Names for icon-only buttons, by icon concept ("Close.24" -> "Close"). Used as their tooltip.

const ICON_NAMES: { [concept: string]: string } = {
	Close: "Close",
	Back: "Back",
	Settings: "Settings",
	Menu: "Menu",
	Search: "Search",
	Refresh: "Refresh",
	Send: "Send",
	Chat: "Chat",
	Mail: "Mail",
	Inventory: "Inventory",
	Shop: "Shop",
	Play: "Play",
	Pause: "Pause",
	Hide: "Hide",
	Lock: "Locked",
	Check: "Done",
	Chevron: "More",
	Visit: "Visit",
	Wave: "Wave",
	Gift: "Gift",
	Leaderboard: "Ranks",
	Guide: "Guide",
	Credits: "Credits",
	Crew: "Crew",
	Guild: "Guild",
	Admin: "Admin",
	Rewards: "Rewards",
	Calendar: "Calendar",
	Code: "Codes",
	Travel: "Travel",
	Loadout: "Loadout",
};

export function labelFor(icon: string | undefined): string | undefined {
	if (!typeIs(icon, "string")) {
		return undefined;
	}
	const [concept] = icon.match("^[^.]+");
	return ICON_NAMES[(concept as string | undefined) ?? icon];
}

