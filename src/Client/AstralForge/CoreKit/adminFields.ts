export interface Choice {
	id: string;
	label: string;
	icon?: string;
}

export interface CommandFields {
	amountLabel: string;
	optionLabel: string;
	amountChoices: Choice[];
	optionChoices: Choice[];
	defaultAmount: string;
	defaultOption: string;
	usesAmount: boolean;
	usesOption: boolean;
	overridesTarget: boolean;
}

/** The server's description of one command's amount: AdminCommandSchema.describe. */
export interface InputRule {
	Mode?: string;
	UsesAmount?: boolean;
	Minimum?: number;
	Maximum?: number;
	Integer?: boolean;
	Summary?: string;
}

export const ADMIN_REASONS: Choice[] = [
	{ id: "Owner gameplay administration", label: "Owner gameplay administration" },
	{ id: "Balance correction", label: "Balance correction" },
	{ id: "Playtest grant", label: "Playtest grant" },
	{ id: "Troll / joke", label: "Troll / joke" },
	{ id: "Moderation action", label: "Moderation action" },
	{ id: "Player request", label: "Player request" },
	{ id: "Bug recovery", label: "Bug recovery" },
	{ id: "Trade settle recovery", label: "Trade settle recovery" },
	{ id: "Community event", label: "Community event" },
	{ id: "Staff showcase", label: "Staff showcase" },
];

const KICK_REASONS: Choice[] = [
	{ id: "You were kicked from this Astral Forge server by an administrator.", label: "Admin removal" },
	{ id: "You were kicked for exploiting or using unauthorized software.", label: "Exploiting" },
	{ id: "You were kicked for harassment or inappropriate behavior.", label: "Harassment" },
	{ id: "You were kicked for spamming or disrupting other players.", label: "Spamming" },
	{ id: "You were kicked for evading a previous punishment.", label: "Ban evasion" },
	{ id: "You were kicked while this session is under review.", label: "Under review" },
];

const SERVER_BAN_REASONS: Choice[] = [
	{ id: "You are banned from this Astral Forge server.", label: "Server ban" },
	{ id: "You are banned from this server for exploiting or using unauthorized software.", label: "Exploiting" },
	{ id: "You are banned from this server for harassment or inappropriate behavior.", label: "Harassment" },
	{ id: "You are banned from this server for spamming or disrupting other players.", label: "Spamming" },
	{ id: "You are banned from this server for evading a previous punishment.", label: "Ban evasion" },
];

const GLOBAL_BAN_REASONS: Choice[] = [
	{ id: "You are banned from Astral Forge.", label: "Experience ban" },
	{ id: "You are banned from Astral Forge for exploiting or using unauthorized software.", label: "Exploiting" },
	{ id: "You are banned from Astral Forge for harassment or inappropriate behavior.", label: "Harassment" },
	{ id: "You are banned from Astral Forge for spamming or disrupting other players.", label: "Spamming" },
	{ id: "You are banned from Astral Forge for evading a previous punishment.", label: "Ban evasion" },
];

export function reasonsFor(command: string, category?: string): Choice[] {
	if (command === "Kick") {
		return KICK_REASONS;
	}
	if (command === "ServerBan") {
		return SERVER_BAN_REASONS;
	}
	if (command === "GlobalBan") {
		return GLOBAL_BAN_REASONS;
	}
	const preferred =
		category === "Troll" || category === "Effects"
			? "Troll / joke"
			: category === "Moderation"
				? "Moderation action"
				: category === "Resets"
					? "Owner gameplay administration"
					: category === "LiveOps"
						? "Community event"
						: "Playtest grant";
	return [...ADMIN_REASONS.filter((entry) => entry.id === preferred), ...ADMIN_REASONS.filter((entry) => entry.id !== preferred)];
}

const NONE: CommandFields = {
	amountLabel: "",
	optionLabel: "",
	amountChoices: [],
	optionChoices: [],
	defaultAmount: "1",
	defaultOption: "",
	usesAmount: false,
	usesOption: false,
	overridesTarget: false,
};

function pick(id: string, label: string, icon?: string): Choice {
	return icon !== undefined ? { id, label, icon } : { id, label };
}

function amountList(values: string[], suffix: string, icon?: string): Choice[] {
	return values.map((value) => pick(value, `${value} ${suffix}`, icon));
}

function namedAmounts(entries: Array<{ id: string; label: string }>, icon?: string): Choice[] {
	return entries.map((entry) => pick(entry.id, entry.label, icon));
}

const FLUX = namedAmounts(
	[
		{ id: "1000", label: "1,000 Flux" },
		{ id: "10000", label: "10,000 Flux" },
		{ id: "100000", label: "100,000 Flux" },
		{ id: "1000000", label: "1 million Flux" },
		{ id: "1000000000", label: "1 billion Flux" },
		{ id: "1e12", label: "1 trillion Flux" },
		{ id: "1e15", label: "1 quadrillion Flux" },
		{ id: "1e308", label: "MAX Flux" },
	],
	"Flux",
);
const CORES = namedAmounts(
	[
		{ id: "1", label: "1 core" },
		{ id: "10", label: "10 cores" },
		{ id: "25", label: "25 cores" },
		{ id: "100", label: "100 cores" },
		{ id: "1000", label: "1,000 cores" },
		{ id: "10000", label: "10,000 cores" },
	],
	"Core",
);
const DUST = namedAmounts(
	[
		{ id: "100", label: "100 Stardust" },
		{ id: "1000", label: "1,000 Stardust" },
		{ id: "10000", label: "10,000 Stardust" },
		{ id: "100000", label: "100,000 Stardust" },
		{ id: "1000000", label: "1 million Stardust" },
	],
	"Dust",
);
const COUNTS = amountList(["1", "5", "10", "25", "50", "100"], "");
const KEYS = amountList(["1", "5", "10", "25", "50", "100"], "keys", "Crate");
const RELICS = amountList(["1", "2", "3", "5", "10"], "relics", "Inventory");
const XP = namedAmounts(
	[
		{ id: "100", label: "100 XP" },
		{ id: "1000", label: "1,000 XP" },
		{ id: "10000", label: "10,000 XP" },
		{ id: "100000", label: "100,000 XP" },
		{ id: "1000000", label: "1 million XP" },
	],
	"StarGrid",
);
const REBIRTHS = namedAmounts(
	[
		{ id: "1", label: "1 rebirth" },
		{ id: "5", label: "5 rebirths" },
		{ id: "10", label: "10 rebirths" },
		{ id: "25", label: "25 rebirths" },
		{ id: "100", label: "100 rebirths" },
		{ id: "1000", label: "1,000 rebirths" },
	],
	"Rebirth",
);
export const DURATION = namedAmounts(
	[
		{ id: "3", label: "3 seconds" },
		{ id: "6", label: "6 seconds" },
		{ id: "10", label: "10 seconds" },
		{ id: "15", label: "15 seconds" },
		{ id: "20", label: "20 seconds" },
	],
	"Timer",
);
const SERVER_BAN = namedAmounts(
	[
		{ id: "0", label: "This server session" },
		{ id: "600", label: "10 minutes" },
		{ id: "3600", label: "1 hour" },
		{ id: "21600", label: "6 hours" },
		{ id: "86400", label: "24 hours" },
		{ id: "604800", label: "7 days" },
	],
	"Lock",
);
const GLOBAL_BAN = namedAmounts(
	[
		{ id: "86400", label: "1 day" },
		{ id: "259200", label: "3 days" },
		{ id: "604800", label: "7 days" },
		{ id: "1209600", label: "14 days" },
		{ id: "2592000", label: "30 days" },
		{ id: "Permanent", label: "Permanent" },
	],
	"Lock",
);
const HOURS = namedAmounts(
	[
		{ id: "1", label: "1 hour of production" },
		{ id: "2", label: "2 hours" },
		{ id: "6", label: "6 hours" },
		{ id: "12", label: "12 hours" },
		{ id: "24", label: "1 day" },
		{ id: "72", label: "3 days" },
		{ id: "168", label: "1 week" },
	],
	"Timer",
);
const GIFT_AMOUNTS = namedAmounts(
	[
		{ id: "1", label: "1 each" },
		{ id: "5", label: "5 each" },
		{ id: "10", label: "10 each" },
		{ id: "100", label: "100 each" },
		{ id: "1000", label: "1,000 each" },
		{ id: "100000", label: "100,000 each" },
		{ id: "1000000", label: "1 million each" },
	],
	"Gift",
);
const GIFT_CURRENCIES = [
	pick("Flux", "Flux", "Flux"),
	pick("Cores", "Cores", "Core"),
	pick("Stardust", "Stardust", "Dust"),
	pick("FreeSpins", "Free spins", "Wheel"),
];
export const SHOW_EFFECT_CHOICES: Choice[] = [
	pick("Fireworks", "Fireworks"),
	pick("Aurora", "Aurora ribbons"),
	pick("Starfall", "Shooting stars"),
	pick("MatrixRain", "Code rain"),
	pick("Glitch", "Signal glitch"),
	pick("Heartbeat", "Heartbeat vignette"),
	pick("Snowfall", "Snowfall"),
	pick("Letterbox", "Cinematic letterbox"),
	pick("ClearEffects", "Clear every effect"),
];
export const LETTERBOX_CAPTION_CHOICES: Choice[] = [
	pick("ACT ONE", "ACT ONE"),
	pick("MEANWHILE", "MEANWHILE"),
	pick("TO BE CONTINUED", "TO BE CONTINUED"),
	pick("THE FORGE AWAKENS", "THE FORGE AWAKENS"),
	pick("FIVE MINUTES LATER", "FIVE MINUTES LATER"),
];
const KIT_CHOICES = [
	pick("Starter", "Starter kit", "Crate"),
	pick("Builder", "Builder kit", "Crate"),
	pick("Veteran", "Veteran kit", "Crate"),
	pick("Playtest", "Playtest kit", "Crate"),
];
const SPOTLIGHT_CHOICES = [
	pick("PlayerOfTheHour", "Player of the hour"),
	pick("BuilderOfTheDay", "Builder of the day"),
	pick("CommunityHero", "Community hero"),
	pick("GoodSport", "Good sport"),
];
const CLOWNS = [
	pick("CLOWN", "CLOWN"),
	pick("JESTER", "JESTER"),
	pick("HONK", "HONK"),
	pick("GOOFBALL", "GOOFBALL"),
	pick("ADMIN'S FAVORITE", "ADMIN'S FAVORITE"),
];
const FALLBACK_CRATES = [
	pick("ForgeCrate", "Forge Crate", "Crate"),
	pick("CrystalCrate", "Crystal Crate", "Crate"),
	pick("HorizonCrate", "Horizon Crate", "Crate"),
	pick("NebulaCrate", "Nebula Crate", "Crate"),
	pick("OrbitCrate", "Orbit Crate", "Crate"),
	pick("SingularityCrate", "Singularity Crate", "Crate"),
	pick("EchoCrate", "Echo Crate", "Crate"),
];
const FALLBACK_BOOSTS = [
	pick("DomainSurge", "Domain Surge", "Boost"),
	pick("Overdrive", "Overdrive", "Boost"),
	pick("Hyperdrive", "Hyperdrive", "Boost"),
	pick("VaultSurge", "Vault Surge", "Boost"),
];

function pack(amountChoices: Choice[], amountLabel: string, optionChoices?: Choice[], optionLabel?: string, overridesTarget = false): CommandFields {
	return {
		amountLabel,
		optionLabel: optionLabel ?? "",
		amountChoices,
		optionChoices: optionChoices ?? [],
		defaultAmount: amountChoices[0]?.id ?? "1",
		defaultOption: optionChoices?.[0]?.id ?? "",
		usesAmount: amountChoices.size() > 0,
		usesOption: (optionChoices?.size() ?? 0) > 0,
		overridesTarget,
	};
}

export interface AdminConfig {
	Items?: {
		Crates?: Array<{ Id: string; Name: string }>;
		Definitions?: Array<{ Id: string; Name: string }>;
	};
	Boosts?: Record<string, { Name: string }>;
	Zones?: Array<{ Id: number | string; Name: string }>;
}

export interface BanEntry {
	UserId: number;
	Name: string;
	Scope: string;
	Until: number;
}

function crateChoices(config?: AdminConfig): Choice[] {
	const crates = config?.Items?.Crates;
	if (crates === undefined || crates.size() === 0) {
		return FALLBACK_CRATES;
	}
	return crates.map((crate) => pick(crate.Id, crate.Name, "Crate"));
}

function boostChoices(config?: AdminConfig): Choice[] {
	const boosts = config?.Boosts;
	if (boosts === undefined) {
		return FALLBACK_BOOSTS;
	}
	const choices = new Array<Choice>();
	for (const [id, boost] of pairs(boosts)) {
		choices.push(pick(id, boost.Name, "Boost"));
	}
	if (choices.size() === 0) {
		return FALLBACK_BOOSTS;
	}
	return choices;
}

function relicChoices(config?: AdminConfig): Choice[] {
	const definitions = config?.Items?.Definitions;
	if (definitions === undefined || definitions.size() === 0) {
		return [pick("IonCoupler", "Ion Coupler", "Inventory")];
	}
	return definitions.map((definition) => pick(definition.Id, definition.Name, "Inventory"));
}

function zoneChoices(config?: AdminConfig): Choice[] {
	const zones = config?.Zones;
	if (zones === undefined || zones.size() === 0) {
		return namedAmounts(
			[
				{ id: "1", label: "World 1" },
				{ id: "2", label: "World 2" },
				{ id: "3", label: "World 3" },
			],
			"World",
		);
	}
	return zones.map((zone) => pick(tostring(zone.Id), zone.Name, "World"));
}

function banChoices(banned: BanEntry[]): Choice[] {
	return banned.map((entry) => {
		const window = entry.Until < 0 ? "permanent" : entry.Until === 0 ? "this server" : "timed";
		return { id: tostring(entry.UserId), label: `${entry.Name}  ·  ${entry.Scope} ${window}`, icon: "Lock.1" };
	});
}

const GRANT_COUNT_COMMANDS = new Set([
	"GrantDomainEssence",
	"GrantItemEssence",
	"GrantAnomalyFragments",
	"GrantSignals",
	"GrantStreakShields",
	"GrantContinuumRanks",
	"GrantAnomalyCharge",
	"GrantAnomalyStabilizations",
	"GrantFreeSpins",
	"GrantAllCrateKeys",
	"GrantAllBoosts",
	"GrantSkillPoints",
	"GrantEchoCharge",
]);

export function fieldsFor(command: string, config?: AdminConfig, banned?: BanEntry[], rule?: InputRule): CommandFields {
	if (command === "SetFlux" || command === "SetVault") {
		return pack([{ id: "0", label: "Set to zero" }, ...FLUX], "Exact value");
	}
	if (command === "SetContinuumRank" || command === "SetFreeSpins") {
		return pack(amountList(["0", "1", "5", "10", "25", "50", "100"], "value", "Set"), "Exact value");
	}
	if (command === "SetCores" || command === "SetStardust" || command === "SetRebirths") {
		return pack(amountList(["0", "1", "10", "100", "1000", "10000", "1000000"], "value", "Set"), "Exact value");
	}
	if (
		command === "SetDomainEssence" ||
		command === "SetItemEssence" ||
		command === "SetSignals" ||
		command === "SetStreakShields" ||
		command === "SetAnomalyFragments"
	) {
		return pack(amountList(["0", "1", "10", "100", "1000", "10000"], "value", "Set"), "Exact value");
	}
	if (command === "SetSeasonXP") {
		return pack(amountList(["0", "100", "1000", "10000", "100000"], "XP", "Set"), "Exact value");
	}
	if (command === "GrantFlux" || command === "GrantVaultFlux") {
		return pack(FLUX, "How much Flux");
	}
	if (command === "GrantCores") {
		return pack(CORES, "How many cores");
	}
	if (command === "GrantStardust") {
		return pack(DUST, "How much Stardust");
	}
	if (command === "GrantRebirths") {
		return pack(REBIRTHS, "How many rebirths");
	}
	if (GRANT_COUNT_COMMANDS.has(command)) {
		return pack(COUNTS, "How many");
	}
	if (command === "GrantCommandXP" || command === "GrantSeasonXP") {
		return pack(XP, "How much XP");
	}
	if (command === "SetDomainRank") {
		return pack(amountList(["0", "1", "5", "10", "25", "50"], "rank", "Domain"), "Domain rank");
	}
	if (command === "GrantEverything") {
		return pack(
			namedAmounts(
				[
					{ id: "1000", label: "Starter owner bundle" },
					{ id: "1000000", label: "Large owner bundle" },
					{ id: "1e12", label: "Massive owner bundle" },
				],
				"Gift",
			),
			"Bundle size",
		);
	}
	if (command === "GrantCrateKeys" || command === "GrantPity") {
		return pack(KEYS, "How many", crateChoices(config), "Which crate");
	}
	if (command === "GrantBoost") {
		return pack(COUNTS, "How many", boostChoices(config), "Which boost");
	}
	if (command === "GrantRelic") {
		return pack(RELICS, "How many", relicChoices(config), "Which relic");
	}
	if (command === "SetZone") {
		return pack(zoneChoices(config), "Unlock through");
	}
	if (command === "FastForward") {
		return pack(HOURS, "How far ahead");
	}
	if (command === "ApplyKit") {
		return pack([], "", KIT_CHOICES, "Which kit");
	}
	if (command === "Spotlight") {
		return pack([], "", SPOTLIGHT_CHOICES, "Which title");
	}
	if (command === "ServerGift") {
		return pack(GIFT_AMOUNTS, "How much per player", GIFT_CURRENCIES, "Which currency");
	}
	if (command === "ServerShow") {
		return pack(DURATION, "How long", SHOW_EFFECT_CHOICES, "Which effect");
	}
	if (command === "Letterbox") {
		return pack(DURATION, "How long", LETTERBOX_CAPTION_CHOICES, "Caption");
	}
	if (command === "ClearEffects") {
		// a World command takes a duration; clearing has no use for one, so the console sends the minimum
		return { ...NONE, defaultAmount: "3" };
	}
	if (command === "ClownTitle") {
		return pack(DURATION, "How long", CLOWNS, "Splash text");
	}
	if (command === "Kick") {
		return NONE;
	}
	if (command === "ServerBan") {
		return pack(SERVER_BAN, "How long");
	}
	if (command === "GlobalBan") {
		return pack(GLOBAL_BAN, "How long");
	}
	if (command === "Unban") {
		return pack(banChoices(banned ?? []), "Who to unban", undefined, undefined, true);
	}
	// everything else follows the amount rule the server described: timed effects get a duration list
	if (rule !== undefined && rule.UsesAmount === true) {
		return rule.Mode === "duration" ? pack(DURATION, "How long") : pack(COUNTS, "How many");
	}
	return NONE;
}
