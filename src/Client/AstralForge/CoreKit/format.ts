// A flux amount is a plain number until it outgrows a double; then it travels as "1.23e456".
export type Flux = number | string;

const LN10 = math.log(10);

// display names for boosts and crates, read once from the shared config (absent under Lune tests)
let displayNames: Record<string, string> | undefined;
function nameOf(id: unknown): string {
	if (displayNames === undefined) {
		const names: Record<string, string> = {};
		displayNames = names;
		pcall(() => {
			let shared = game.GetService("ReplicatedStorage").FindFirstChild("AstralForge");
			shared = shared && shared.FindFirstChild("Shared");
			const module = shared && shared.FindFirstChild("GameConfig");
			if (module === undefined) {
				return;
			}
			const config = require(module as ModuleScript) as {
				Boosts?: Record<string, unknown>;
				Items?: { Crates?: Record<string, unknown> };
				Crates?: Record<string, unknown>;
			};
			for (const [key, boost] of pairs(config.Boosts ?? {})) {
				const entry = boost as { Id?: string; Name?: unknown };
				if (typeIs(boost, "table") && typeIs(entry.Name, "string")) {
					names[entry.Id ?? (key as string)] = entry.Name;
				}
			}
			const items = config.Items ?? {};
			for (const [, crate] of pairs(items.Crates ?? config.Crates ?? {})) {
				const entry = crate as { Id?: unknown; Name?: unknown };
				if (typeIs(crate, "table") && typeIs(entry.Id, "string") && typeIs(entry.Name, "string")) {
					names[entry.Id] = entry.Name;
				}
			}
		});
	}
	return displayNames[id as string] ?? tostring(id).gsub("(%l)(%u)", "%1 %2")[0];
}

function plural(amount: number, one: string, many: string): string {
	return amount === 1 ? one : many;
}

export interface Reward {
	Cash?: number;
	CashMinutes?: number;
	Stardust?: number;
	Cores?: number;
	Signals?: number;
	CommandXP?: number;
	StreakShield?: number;
	Essence?: number;
	DomainEssence?: number;
	Fragments?: number;
	FreeSpins?: number;
	Keys?: Record<string, number>;
	Boost?: string;
}

export function formatReward(reward: Reward | undefined | false): string {
	if (!reward) {
		return "";
	}
	const parts = new Array<string>();
	if (reward.Cash !== undefined && reward.Cash > 0) {
		parts.push(`${compactNumber(reward.Cash)} flux`);
	}
	if (reward.CashMinutes !== undefined && reward.CashMinutes > 0) {
		parts.push(`${compactNumber(reward.CashMinutes)} min of flux`);
	}
	if (reward.Stardust !== undefined && reward.Stardust > 0) {
		parts.push(`${compactNumber(reward.Stardust)} stardust`);
	}
	if (reward.Cores !== undefined && reward.Cores > 0) {
		parts.push(`${compactNumber(reward.Cores)} ${plural(reward.Cores, "core", "cores")}`);
	}
	if (reward.Signals !== undefined && reward.Signals > 0) {
		parts.push(`${compactNumber(reward.Signals)} signals`);
	}
	if (reward.CommandXP !== undefined && reward.CommandXP > 0) {
		parts.push(`${compactNumber(reward.CommandXP)} command XP`);
	}
	if (reward.StreakShield !== undefined && reward.StreakShield > 0) {
		parts.push(`${reward.StreakShield} ${plural(reward.StreakShield, "streak shield", "streak shields")}`);
	}
	let essenceAmount = 0;
	if (reward.Essence !== undefined && reward.Essence > 0) {
		essenceAmount += reward.Essence;
	}
	if (reward.DomainEssence !== undefined && reward.DomainEssence > 0) {
		essenceAmount += reward.DomainEssence;
	}
	if (essenceAmount > 0) {
		parts.push(`${compactNumber(essenceAmount)} domain essence`);
	}
	if (reward.Fragments !== undefined && reward.Fragments > 0) {
		parts.push(`${compactNumber(reward.Fragments)} fragments`);
	}
	if (reward.FreeSpins !== undefined && reward.FreeSpins > 0) {
		const spinLabel = reward.FreeSpins === 1 ? "free spin" : "free spins";
		parts.push(`${compactNumber(reward.FreeSpins)} ${spinLabel}`);
	}
	if (typeIs(reward.Keys, "table")) {
		for (const [crateId, amount] of pairs(reward.Keys)) {
			if (typeIs(crateId, "string") && typeIs(amount, "number") && amount > 0) {
				parts.push(`${compactNumber(amount)} ${nameOf(crateId)} ${plural(amount, "key", "keys")}`);
			}
		}
	}
	if (reward.Boost !== undefined) {
		parts.push(`${nameOf(reward.Boost)} boost`);
	}
	if (parts.size() === 0) {
		return "";
	}
	let text = "+" + parts[0];
	for (let index = 1; index < parts.size(); index++) {
		text += `, +${parts[index]}`;
	}
	return text;
}

// prettier-ignore
const NUMBER_SUFFIXES = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion", "Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign", "Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex", "Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx", "Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx", "Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega", "Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless", "Apex", "Horizon", "Zenith", "Nadir", "Helix", "Quasar", "Pulsar", "Nebula", "Singularity", "Eventide", "Eon", "Aeon", "Continuum", "Lattice", "Axiom", "Paragon", "Astral", "Forgepeak"];

function suffixForGroup(group: number): string {
	if (group <= 0) {
		return "";
	}
	const index = math.min(group, NUMBER_SUFFIXES.size()) - 1;
	return NUMBER_SUFFIXES[index];
}

const LAST_NAMED_LOG10 = NUMBER_SUFFIXES.size() * 3;

function roundsToThousand(absolute: number): boolean {
	const decimals = absolute >= 100 ? 0 : absolute >= 10 ? 1 : 2;
	return (tonumber(("%." + decimals + "f").format(absolute)) ?? 0) >= 1000;
}

function formatFromLog10(log10: number, sign = 1): string {
	if (log10 !== log10 || log10 === -math.huge) {
		return "0";
	}
	if (log10 < 3) {
		const numeric = sign * 10 ** math.max(0, log10);
		if (math.abs(numeric) < 999.5) {
			return "%.0f".format(numeric);
		}
	}
	if (log10 >= LAST_NAMED_LOG10) {
		const exponent = math.floor(log10);
		const mantissa = 10 ** (log10 - exponent);
		return "%s%.2fe%d".format(sign < 0 ? "-" : "", mantissa, exponent);
	}
	let group = math.clamp(math.floor(log10 / 3), 1, NUMBER_SUFFIXES.size());
	let scaled = sign * 10 ** (log10 - group * 3);
	if ((math.abs(scaled) >= 1000 || roundsToThousand(math.abs(scaled))) && group < NUMBER_SUFFIXES.size()) {
		group += 1;
		scaled /= 1000;
	}
	let suffix = suffixForGroup(group);
	// past the Latin abbreviations the tiers are whole words; glued to the digits they read as
	// garbled text ("1.01Horizon"), so words get a space while "1.20K" stays tight
	if (suffix.size() >= 5) {
		suffix = " " + suffix;
	}
	const absolute = math.abs(scaled);
	if (absolute >= 100) {
		return "%.0f%s".format(scaled, suffix);
	}
	if (absolute >= 10) {
		let text = "%.1f".format(scaled);
		if (math.abs(tonumber(text) ?? 0) >= 100) {
			text = "%.0f".format(scaled);
		}
		return text + suffix;
	}
	let text = "%.2f".format(scaled);
	if (math.abs(tonumber(text) ?? 0) >= 10) {
		text = "%.1f".format(scaled);
	}
	return text + suffix;
}

function scaleForDisplay(value: number): { scaled: number; suffix: string } {
	const absolute = math.abs(value);
	if (absolute !== absolute || absolute === 0) {
		return { scaled: 0, suffix: "" };
	}
	if (absolute === math.huge) {
		return { scaled: 1, suffix: "e308+" };
	}
	if (absolute < 1000) {
		return { scaled: value, suffix: "" };
	}
	const log10 = math.log10(absolute);
	if (log10 >= LAST_NAMED_LOG10) {
		return { scaled: 10 ** (log10 - math.floor(log10)), suffix: `e${math.floor(log10)}` };
	}
	let group = math.clamp(math.floor(log10 / 3), 1, NUMBER_SUFFIXES.size());
	let scaled = value / 1000 ** group;
	if ((math.abs(scaled) >= 1000 || roundsToThousand(math.abs(scaled))) && group < NUMBER_SUFFIXES.size()) {
		group += 1;
		scaled /= 1000;
	}
	return { scaled, suffix: suffixForGroup(group) };
}

export function asFlux(value: unknown): number {
	if (typeIs(value, "number")) {
		return value === value ? value : 0;
	}
	const parsed = tonumber(value);
	if (parsed !== undefined && parsed === parsed && parsed !== math.huge && parsed !== -math.huge) {
		return parsed;
	}
	const log = log10Flux(value);
	if (log === -math.huge) {
		return 0;
	}
	if (log >= 308) {
		return 1e308;
	}
	if (log <= -308) {
		return 0;
	}
	return 10 ** log;
}

export function log10Flux(value: unknown): number {
	if (typeIs(value, "number")) {
		if (value !== value || value === 0) {
			return -math.huge;
		}
		if (value < 0) {
			return -math.huge;
		}
		if (value === math.huge) {
			return 1e6;
		}
		return math.log10(value);
	}
	if (!typeIs(value, "string")) {
		return -math.huge;
	}
	const parsed = tonumber(value);
	if (parsed !== undefined && parsed === parsed && parsed !== math.huge && parsed !== -math.huge) {
		return log10Flux(parsed);
	}
	const [mantissaText, exponentText] = value.match("([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)");
	if (mantissaText !== undefined && exponentText !== undefined) {
		const mantissa = tonumber(mantissaText) ?? 1;
		const exponent = tonumber(exponentText) ?? 0;
		if (mantissa <= 0) {
			return -math.huge;
		}
		return math.log(mantissa) / LN10 + exponent;
	}
	if (value.lower() === "inf" || value.lower() === "infinity") {
		return 1e6;
	}
	return -math.huge;
}

function fromLog10(log10: number): Flux {
	if (log10 !== log10 || log10 === -math.huge) {
		return 0;
	}
	if (log10 < 308) {
		const numeric = 10 ** log10;
		if (numeric === numeric && numeric !== math.huge) {
			return numeric;
		}
	}
	const exponent = math.floor(log10);
	const mantissa = 10 ** (log10 - exponent);
	return "%.12fe%d".format(mantissa, exponent);
}

export function compareFlux(left: Flux, right: Flux): -1 | 0 | 1 {
	const a = log10Flux(left);
	const b = log10Flux(right);
	if (a < b) {
		return -1;
	}
	if (a > b) {
		return 1;
	}
	return 0;
}

export function gteFlux(left: Flux, right: Flux): boolean {
	return compareFlux(left, right) >= 0;
}

export function levelCapLabel(maxLevel: number): string {
	if (maxLevel >= 1000000000) {
		return "∞";
	}
	return compactNumber(maxLevel);
}

export function compactNumber(value: unknown): string {
	if (typeIs(value, "string")) {
		const parsed = tonumber(value);
		if (parsed !== undefined && parsed === parsed && parsed !== math.huge && parsed !== -math.huge) {
			return compactNumber(parsed);
		}
		return formatFromLog10(log10Flux(value));
	}
	if (!typeIs(value, "number") || value !== value) {
		return "0";
	}
	if (value === 0) {
		return "0";
	}
	if (math.abs(value) < 999.5 && value !== math.huge && value !== -math.huge) {
		return "%.0f".format(value);
	}
	return formatFromLog10(log10Flux(math.abs(value)), value < 0 ? -1 : 1);
}

export interface SpinParts {
	value: number;
	suffix: string;
	decimals: number;
}

export function compactSpinParts(value: unknown): SpinParts {
	if (typeIs(value, "string")) {
		const parsed = tonumber(value);
		if (parsed !== undefined && parsed === parsed && parsed !== math.huge) {
			return compactSpinParts(parsed);
		}
		return { value: 1, suffix: compactNumber(value), decimals: 0 };
	}
	if (!typeIs(value, "number") || value !== value) {
		return { value: 0, suffix: "", decimals: 0 };
	}
	const parts = scaleForDisplay(value);
	if (parts.suffix === "") {
		return { value: math.floor(value + (value >= 0 ? 0.5 : -0.5)), suffix: "", decimals: 0 };
	}
	const decimals = math.abs(parts.scaled) >= 100 ? 0 : math.abs(parts.scaled) >= 10 ? 1 : 2;
	const factor = 10 ** decimals;
	const rounded = math.floor(parts.scaled * factor + (parts.scaled >= 0 ? 0.5 : -0.5)) / factor;
	return { value: rounded, suffix: parts.suffix, decimals };
}

export function clockText(seconds: number): string {
	const total = math.max(0, math.floor(seconds));
	const hours = math.floor(total / 3600);
	const minutes = math.floor((total % 3600) / 60);
	const remaining = total % 60;
	return hours > 0 ? "%02d:%02d:%02d".format(hours, minutes, remaining) : "%02d:%02d".format(minutes, remaining);
}

export function scaledCost(base: number, scale: number, level: number): Flux {
	const safeBase = math.max(1e-12, base);
	const safeScale = math.max(1e-12, scale);
	const exponent = math.log(safeBase) + math.max(0, level) * math.log(safeScale);
	if (exponent < math.log(1e308)) {
		return math.floor(math.exp(exponent) + 0.5);
	}
	return fromLog10(exponent / LN10);
}

function geometricSum(base: number, scale: number, level: number, count: number): Flux {
	if (count <= 0) {
		return 0;
	}
	if (count === 1) {
		return scaledCost(base, scale, level);
	}
	const safeBase = math.max(1e-12, base);
	const safeScale = math.max(1e-12, scale);
	if (math.abs(safeScale - 1) < 1e-12) {
		const one = scaledCost(safeBase, safeScale, level);
		const logTotal = log10Flux(one) + math.log(count) / LN10;
		return fromLog10(logTotal);
	}
	const lnScale = math.log(safeScale);
	const nLnScale = count * lnScale;
	const logDiff = nLnScale < math.log(1e300) ? math.log(math.max(1e-12, safeScale ** count - 1)) : nLnScale;
	const logTotal = math.log(safeBase) + math.max(0, level) * lnScale + logDiff - math.log(math.max(1e-12, safeScale - 1));
	if (logTotal < math.log(1e308)) {
		return math.floor(math.exp(logTotal) + 0.5);
	}
	return fromLog10(logTotal / LN10);
}

function maxAffordableLevels(base: number, scale: number, level: number, remaining: number, cash: Flux): number {
	if (remaining <= 0) {
		return 0;
	}
	if (compareFlux(scaledCost(base, scale, level), cash) > 0) {
		return 0;
	}
	let low = 1;
	let high = remaining;
	while (low < high) {
		const mid = low + math.floor((high - low + 1) / 2);
		if (compareFlux(geometricSum(base, scale, level, mid), cash) <= 0) {
			low = mid;
		} else {
			high = mid - 1;
		}
	}
	return low;
}

export function bulkCost(base: number, scale: number, level: number, amount: number, maxLevel: number, cash?: Flux): Flux {
	const remaining = math.max(0, maxLevel - level);
	if (amount === 0) {
		if (cash === undefined) {
			return scaledCost(base, scale, level);
		}
		const count = maxAffordableLevels(base, scale, level, remaining, cash);
		return count <= 0 ? scaledCost(base, scale, level) : geometricSum(base, scale, level, count);
	}
	return geometricSum(base, scale, level, math.min(amount, remaining));
}

export function amountPayload(amount: number): number | "Max" {
	return amount === 0 ? "Max" : amount;
}
