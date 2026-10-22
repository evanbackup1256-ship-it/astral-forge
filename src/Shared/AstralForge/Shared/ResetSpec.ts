// Rebirth and Ascension reset as data. Each spec lists what a reset writes to the save, in
// order, and which follow-up passes it runs. Both GameService paths apply their spec through
// applyReset, so "what does a rebirth keep?" is answered by reading the table below.
// Save shapes are unchanged: every field written here already existed in the profile.

type Dict = Record<string, unknown>;

export interface ResetContext {
	StartingCash: number;
	LabBaseCells: number;
	// rebirth only: the carry computed by RebirthMath.carry (keepsake machines and cash)
	Carry?: { Cash: unknown; Machines: unknown };
}

// a field is set to a fixed value, a fresh table built per reset, or a value read from the context
export type ResetValue =
	| { Kind: "Value"; Value: unknown }
	| { Kind: "Fresh"; Build: (profile: Dict, context: ResetContext) => unknown }
	| { Kind: "Context"; Read: (context: ResetContext) => unknown };

export type ResetPass = "PruneEquippedMachines" | "DropEquippedMachines" | "StopAutoForge" | "ResetLabRouting";

export interface ResetSpec {
	Name: string;
	Fields: ReadonlyArray<[string, ResetValue]>;
	Passes: ReadonlyArray<ResetPass>;
}

const value = (v: unknown): ResetValue => ({ Kind: "Value", Value: v });
const fresh = (build: (profile: Dict, context: ResetContext) => unknown): ResetValue => ({ Kind: "Fresh", Build: build });
const fromContext = (read: (context: ResetContext) => unknown): ResetValue => ({ Kind: "Context", Read: read });

const wholeCount = (v: unknown) => math.max(0, math.floor(tonumber(v) ?? 0));

export const Rebirth: ResetSpec = {
	Name: "Rebirth",
	Fields: [
		["Cash", fromContext((c) => c.Carry?.Cash)],
		["Vault", value(0)],
		["RunCash", value(0)],
		["Zone", value(1)],
		["CurrentZone", value(1)],
		["Machines", fromContext((c) => c.Carry?.Machines)],
	],
	// equipped relics stay on machines that were carried over
	Passes: ["PruneEquippedMachines"],
};

export const Ascension: ResetSpec = {
	Name: "Ascension",
	Fields: [
		[
			"Domain",
			fresh((profile) => {
				const domain = (typeIs(profile.Domain, "table") ? profile.Domain : {}) as Dict;
				return {
					Rank: 0,
					Essence: 0,
					LastExpandedAt: 0,
					TotalRebirthsSpent: wholeCount(domain.TotalRebirthsSpent),
					TotalCoresSpent: wholeCount(domain.TotalCoresSpent),
					SkillPoints: 0,
					Links: {},
					LatticeClearedAtRank: 0,
				};
			}),
		],
		["Cash", fromContext((c) => c.StartingCash)],
		["Vault", value(0)],
		["Cores", value(0)],
		["Rebirths", value(0)],
		["RunCash", value(0)],
		["Zone", value(1)],
		["CurrentZone", value(1)],
		["Machines", fresh(() => ({ StellarCore: 1 }))],
	],
	Passes: ["StopAutoForge", "DropEquippedMachines", "ResetLabRouting"],
};

function equippedOf(profile: Dict): Dict | undefined {
	const items = profile.Items as Dict | undefined;
	return items !== undefined && typeIs(items, "table") && typeIs(items.Equipped, "table") ? (items.Equipped as Dict) : undefined;
}

const passes: Record<ResetPass, (profile: Dict, context: ResetContext) => void> = {
	PruneEquippedMachines: (profile) => {
		const equipped = equippedOf(profile);
		if (equipped === undefined) return;
		const machines = (typeIs(profile.Machines, "table") ? profile.Machines : {}) as Dict;
		const drop: string[] = [];
		for (const [target] of pairs(equipped)) {
			const [slot, targetId] = tostring(target).match("^(%a+):([%w_]+)$");
			if (slot === "Machine") {
				const level = machines[targetId as string];
				if (!typeIs(level, "number") || level < 1) drop.push(target as string);
			}
		}
		for (const target of drop) equipped[target] = undefined;
	},
	DropEquippedMachines: (profile) => {
		const equipped = equippedOf(profile);
		if (equipped === undefined) return;
		const drop: string[] = [];
		for (const [target] of pairs(equipped)) {
			const [slot] = tostring(target).match("^(%a+):");
			if (slot === "Machine") drop.push(target as string);
		}
		for (const target of drop) equipped[target] = undefined;
	},
	StopAutoForge: (profile) => {
		const autoForge = profile.AutoForge as Dict | undefined;
		if (autoForge !== undefined && typeIs(autoForge, "table")) {
			autoForge.Enabled = false;
			autoForge.MachineId = "StellarCore";
		}
	},
	ResetLabRouting: (profile, context) => {
		const lab = profile.Lab as Dict | undefined;
		if (lab !== undefined && typeIs(lab, "table")) {
			lab.Routing = { Production: context.LabBaseCells, Storage: 0, Tap: 0 };
		}
	},
};

export function resolve(spec: ResetSpec, profile: Dict, context: ResetContext): Map<string, unknown> {
	const out = new Map<string, unknown>();
	for (const [field, rule] of spec.Fields) {
		if (rule.Kind === "Value") out.set(field, rule.Value);
		else if (rule.Kind === "Fresh") out.set(field, rule.Build(profile, context));
		else out.set(field, rule.Read(context));
	}
	return out;
}

// fields are resolved against the profile before any of them is written, then passes run in order
export function applyReset(spec: ResetSpec, profile: Dict, context: ResetContext) {
	const resolved = resolve(spec, profile, context);
	for (const [field] of spec.Fields) profile[field] = resolved.get(field);
	for (const pass of spec.Passes) passes[pass](profile, context);
}

// every field a spec touches, for docs, tests and the admin reset preview
export function fieldsOf(spec: ResetSpec): string[] {
	return spec.Fields.map(([field]) => field);
}
