// Forge Programs (v8 #8): editing rules (ProgramAct) and deciding which rules are due on a tick.
// Carrying a rule out is GameService's job: it calls the same internal action a button press
// would, through _mutate, so programs can't do anything a player couldn't.
import Programs = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import * as HotFlags from "../Security/HotFlags";
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { Dict, isTable } from "../LuaInterop";

const PAUSE_FLAG = "ForgeProgramsPaused" as const;

type Result = LuaTuple<[boolean, string]>;

function paused(): boolean {
	return HotFlags.Get(PAUSE_FLAG);
}

function ensureRules(profile: Dict): Dict[] {
	const autoForge = profile.AutoForge as Dict;
	Programs.sanitize(autoForge);
	if (autoForge.Programs === undefined) autoForge.Programs = { Rules: [] };
	return (autoForge.Programs as Dict).Rules as Dict[];
}

function indexOf(rules: Dict[], raw: unknown): number | undefined {
	return typeIs(raw, "number") && raw % 1 === 0 && raw >= 1 && raw <= rules.size() ? raw : undefined;
}

function Act(profile: Dict, payload: unknown): Result {
	if (paused()) return $tuple(false, T("ForgePrograms.Paused"));
	if (!Programs.unlocked(profile)) return $tuple(false, T("ForgePrograms.Locked"));
	if (!isTable(profile.AutoForge)) return $tuple(false, T("ForgePrograms.UnknownAction"));
	const bag = isTable(payload) ? (payload as Dict) : undefined;
	const rules = ensureRules(profile);
	if (bag?.Op === "Save") {
		const rule = Programs.cleanRule(bag.Rule);
		if (rule === undefined) return $tuple(false, T("ForgePrograms.BadRule"));
		const index = bag.Index !== undefined ? indexOf(rules, bag.Index) : undefined;
		if (bag.Index !== undefined && index === undefined) return $tuple(false, T("ForgePrograms.NoSuchRule"));
		if (index !== undefined) {
			rules[index - 1] = rule as unknown as Dict;
		} else {
			if (rules.size() >= Programs.RULE_MAX) return $tuple(false, T("ForgePrograms.Full", Programs.RULE_MAX));
			rules.push(rule as unknown as Dict);
		}
		return $tuple(true, T("ForgePrograms.Saved"));
	}
	if (bag?.Op === "Toggle" || bag?.Op === "Delete") {
		const index = indexOf(rules, bag.Index);
		if (index === undefined) return $tuple(false, T("ForgePrograms.NoSuchRule"));
		if (bag.Op === "Delete") {
			rules.remove(index - 1);
			return $tuple(true, T("ForgePrograms.Deleted"));
		}
		const rule = rules[index - 1];
		rule.Enabled = rule.Enabled === false;
		return $tuple(true, rule.Enabled === true ? T("ForgePrograms.On") : T("ForgePrograms.Off"));
	}
	return $tuple(false, T("ForgePrograms.UnknownAction"));
}

interface Facts {
	Now: number;
	Rebirths: number;
	// rebirth quote: whether one is possible, what it pays and what the last run paid
	RebirthReady: boolean;
	RebirthCores: number;
	LastRunCores: number;
	CheapestAffordable?: string;
	CommonCount: number;
}

interface Step {
	Index: number;
	Do: string;
	Arg?: number;
}

// The rules due now, in rule order, with their cooldowns started. A rebirth step ends the list,
// since everything after it should look at the new run.
function Due(profile: Dict, runtime: Dict, facts: Facts): Step[] {
	const steps: Step[] = [];
	if (paused() || !Programs.unlocked(profile)) return steps;
	const rules = Programs.rulesOf(profile);
	if (rules.size() === 0) return steps;
	const cooldowns = (runtime.ProgramCooldowns as Record<string, number> | undefined) ?? {};
	runtime.ProgramCooldowns = cooldowns;
	const seen = runtime.ProgramRebirths as number | undefined;
	runtime.ProgramRebirths = facts.Rebirths;
	const justReborn = seen !== undefined && facts.Rebirths > seen;
	rules.forEach((rule, i) => {
		const index = i + 1;
		const action = Programs.actionOf(rule.Do);
		if (rule.Enabled === false || action === undefined) return;
		const key = `${index}:${rule.Do}`;
		if ((cooldowns[key] ?? 0) > facts.Now) return;
		if (steps.some((step) => step.Do === "Rebirth")) return;
		let due = false;
		if (rule.When === "Affordable") due = facts.CheapestAffordable !== undefined;
		else if (rule.When === "RebirthGain")
			due = facts.RebirthReady && (facts.LastRunCores <= 0 || facts.RebirthCores >= (rule.Arg ?? 2) * facts.LastRunCores);
		else if (rule.When === "InventoryOver") due = facts.CommonCount > (rule.Arg ?? 50);
		else if (rule.When === "AfterRebirth") due = justReborn;
		else if (rule.When === "Always") due = true;
		if (!due) return;
		cooldowns[key] = facts.Now + action.Cooldown;
		steps.push({ Index: index, Do: rule.Do, Arg: rule.Arg });
	});
	return steps;
}

function State(profile: Dict) {
	return { Unlocked: Programs.unlocked(profile), Rules: Programs.rulesOf(profile), Max: Programs.RULE_MAX, Paused: paused() };
}

export = table.freeze({ PAUSE_FLAG, Act, Due, State });
