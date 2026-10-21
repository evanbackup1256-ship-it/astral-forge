// Forge Programs (v8 #8): up to five if/then rules that run on the server tick after the first
// ascension. Each rule pairs one action with one of the conditions that makes sense for it, so a
// saved rule is always something the game can carry out. Rules only call the same actions a
// player can press, through the same checks.
//
// Save: AutoForge.Programs = { Rules: { When, Do, Arg?, Enabled }[] }
type Dict = Record<string, unknown>;

const RULE_MAX = 5;

interface ActionDef {
	Id: string;
	Name: string;
	Whens: string[];
	Cooldown: number;
}
interface WhenDef {
	Id: string;
	Name: string;
	Arg?: { Min: number; Max: number; Default: number; Step: number; Label: string };
}

const ACTIONS: ActionDef[] = [
	{ Id: "BuyCheapestMachine", Name: "Buy the cheapest machine level", Whens: ["Affordable"], Cooldown: 4 },
	{ Id: "Rebirth", Name: "Rebirth", Whens: ["RebirthGain"], Cooldown: 60 },
	{ Id: "SalvageCommons", Name: "Salvage Common relics", Whens: ["InventoryOver"], Cooldown: 30 },
	{ Id: "EquipBest", Name: "Equip best relics", Whens: ["AfterRebirth", "Always"], Cooldown: 30 },
];

const WHENS: WhenDef[] = [
	{ Id: "Affordable", Name: "Flux covers the cost" },
	{ Id: "RebirthGain", Name: "Rebirth pays at least", Arg: { Min: 1, Max: 10, Default: 2, Step: 0.5, Label: "x the last run" } },
	{ Id: "InventoryOver", Name: "Commons owned over", Arg: { Min: 10, Max: 500, Default: 50, Step: 10, Label: "relics" } },
	{ Id: "AfterRebirth", Name: "Right after a rebirth" },
	{ Id: "Always", Name: "Every 30 seconds" },
];

interface Rule {
	When: string;
	Do: string;
	Arg?: number;
	Enabled: boolean;
}

function actionOf(id: unknown): ActionDef | undefined {
	for (const action of ACTIONS) if (action.Id === id) return action;
	return undefined;
}

function whenOf(id: unknown): WhenDef | undefined {
	for (const when of WHENS) if (when.Id === id) return when;
	return undefined;
}

// A clean rule, or undefined when the pairing or the number is not one the game allows.
function cleanRule(raw: unknown): Rule | undefined {
	if (!typeIs(raw, "table")) return undefined;
	const bag = raw as Dict;
	const action = actionOf(bag.Do);
	const when = whenOf(bag.When);
	if (action === undefined || when === undefined || !action.Whens.includes(when.Id)) return undefined;
	const rule: Rule = { When: when.Id, Do: action.Id, Enabled: bag.Enabled !== false };
	if (when.Arg !== undefined) {
		const arg = typeIs(bag.Arg, "number") && bag.Arg === bag.Arg ? bag.Arg : when.Arg.Default;
		rule.Arg = math.clamp(math.floor(arg / when.Arg.Step + 0.5) * when.Arg.Step, when.Arg.Min, when.Arg.Max);
	}
	return rule;
}

// Normalizes AutoForge.Programs in place; leaves saves that never used programs alone.
function sanitize(autoForge: unknown): void {
	if (!typeIs(autoForge, "table")) return;
	const bag = autoForge as Dict;
	if (bag.Programs === undefined) return;
	const raw = typeIs(bag.Programs, "table") ? (bag.Programs as Dict).Rules : undefined;
	const rules: Rule[] = [];
	if (typeIs(raw, "table")) {
		for (const entry of raw as unknown[]) {
			const rule = cleanRule(entry);
			if (rule !== undefined && rules.size() < RULE_MAX) rules.push(rule);
		}
	}
	bag.Programs = { Rules: rules };
}

function rulesOf(profile: unknown): Rule[] {
	const autoForge = typeIs(profile, "table") ? (profile as Dict).AutoForge : undefined;
	const programs = typeIs(autoForge, "table") ? (autoForge as Dict).Programs : undefined;
	const rules = typeIs(programs, "table") ? (programs as Dict).Rules : undefined;
	return typeIs(rules, "table") ? (rules as Rule[]) : [];
}

// Programs open after the first ascension.
function unlocked(profile: unknown): boolean {
	const ascension = typeIs(profile, "table") ? (profile as Dict).Ascension : undefined;
	const rank = typeIs(ascension, "table") ? (ascension as Dict).Rank : undefined;
	return typeIs(rank, "number") && rank >= 1;
}

const ForgePrograms = { RULE_MAX, ACTIONS, WHENS, actionOf, whenOf, cleanRule, sanitize, rulesOf, unlocked };
export = table.freeze(ForgePrograms);
