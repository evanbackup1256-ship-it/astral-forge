type Dict = Record<string, unknown>;
type Value = number | string;

interface State {
	Focus: string;
	ChangedAt: number;
	Gain: number;
	Cost: number;
}
interface Build {
	Id: string;
	Name: string;
	Description: string;
	Gain: string;
	Cost: string;
}
interface BuildPreview {
	Id: string;
	Name: string;
	Description: string;
	Gain: string;
	Cost: string;
	GainMultiplier: number;
	CostMultiplier: number;
	Production: Value;
	Capacity: Value;
	Tap: Value;
	Offline: number;
}
interface Snapshot {
	Focus: string;
	Name: string;
	Builds: BuildPreview[];
	Foundation: { Name: string; Value: number }[];
	Gain: number;
	Cost: number;
	Cooldown: number;
	ReadyAt: number;
	Production: Value;
	Capacity: Value;
	Tap: Value;
	Offline: number;
}
interface Economy {
	Production(this: void, profile: Dict, now: number): Value;
	Capacity(this: void, profile: Dict, now: number): Value;
	TapPower(this: void, profile: Dict, now: number): Value;
	OfflineEfficiency(this: void, profile: Dict, now: number): number;
	GridEffect(this: void, profile: Dict, id: string): number;
}

const Builds: Build[] = [
	{ Id: "Balanced", Name: "Balanced forge", Description: "Keep your current forge rates. No trade-offs.", Gain: "", Cost: "" },
	{
		Id: "Handcraft",
		Name: "Handcraft",
		Description: "Work the forge actively. Stronger overcharge, less unattended production.",
		Gain: "Tap",
		Cost: "Production",
	},
	{
		Id: "Reserve",
		Name: "Deep reserves",
		Description: "Bank larger batches between collections. Sacrifice some tap strength.",
		Gain: "Capacity",
		Cost: "Tap",
	},
	{
		Id: "NightShift",
		Name: "Night shift",
		Description: "Recover more while away. Trade some tap strength for offline efficiency.",
		Gain: "Offline",
		Cost: "Tap",
	},
];

let gain = 1.3;
let cost = 0.85;
let cooldown = 600;

function Find(id: unknown): Build | undefined {
	for (const build of Builds) {
		if (build.Id === id) {
			return build;
		}
	}
	return undefined;
}

function Sanitize(raw: unknown): State {
	const source = (typeIs(raw, "table") ? raw : {}) as Dict;
	const focus = typeIs(source.Focus, "string") && Find(source.Focus) ? source.Focus : "Balanced";
	const at = source.ChangedAt;
	const savedGain =
		typeIs(source.Gain, "number") && source.Gain === source.Gain ? math.clamp(source.Gain, 1.05, 1.5) : gain;
	const savedCost =
		typeIs(source.Cost, "number") && source.Cost === source.Cost ? math.clamp(source.Cost, 0.5, 0.95) : cost;
	return {
		Focus: focus,
		Gain: savedGain,
		Cost: savedCost,
		ChangedAt: typeIs(at, "number") && at === at && at >= 0 && at < math.huge ? math.floor(at) : 0,
	};
}

function Configure(nextGain: unknown, nextCost: unknown, nextCooldown: unknown): void {
	gain = typeIs(nextGain, "number") && nextGain === nextGain ? math.clamp(nextGain, 1.05, 1.5) : 1.3;
	cost = typeIs(nextCost, "number") && nextCost === nextCost ? math.clamp(nextCost, 0.5, 0.95) : 0.85;
	cooldown =
		typeIs(nextCooldown, "number") && nextCooldown === nextCooldown
			? math.clamp(math.floor(nextCooldown), 60, 3600)
			: 600;
}

function Factor(raw: unknown, kind: string): number {
	const state = Sanitize(raw);
	const build = Find(state.Focus);
	if (build && build.Gain === kind) {
		return state.Gain;
	}
	if (build && build.Cost === kind) {
		return state.Cost;
	}
	return 1;
}

function Policy() {
	return { Gain: gain, Cost: cost, Cooldown: cooldown };
}

function Select(raw: unknown, id: unknown, now: number): LuaTuple<[State | undefined, string]> {
	if (!typeIs(id, "string") || !Find(id)) {
		return $tuple(undefined, "Choose an available forge specialization.");
	}
	const state = Sanitize(raw);
	if (state.Focus === id) {
		return $tuple(state, "That build is already equipped.");
	}
	if (state.ChangedAt > 0 && now < state.ChangedAt + cooldown) {
		return $tuple(
			undefined,
			"Your forge can be reconfigured in " + math.ceil(state.ChangedAt + cooldown - now) + " seconds.",
		);
	}
	return $tuple(
		{ Focus: id, ChangedAt: now, Gain: gain, Cost: cost },
		"Forge specialization equipped. All purchased bonuses are preserved.",
	);
}

function Snapshot(profile: Dict, economy: Economy, now: number, cache?: Dict, current?: Dict): Snapshot {
	const selected = Sanitize(profile.Specialization);
	const policy = Policy();
	const production = (current ? current.Production : economy.Production(profile, now)) as Value;
	const capacity = (current ? current.Capacity : economy.Capacity(profile, now)) as Value;
	const tap = economy.TapPower(profile, now);
	const offline = economy.OfflineEfficiency(profile, now);
	const levels: string[] = [];
	for (const [id, level] of pairs((profile.GridUpgrades ?? {}) as Dict)) {
		levels.push(id + "=" + tostring(level));
	}
	levels.sort();
	const key = [
		tostring(now),
		tostring(production),
		tostring(capacity),
		tostring(tap),
		tostring(offline),
		selected.Focus,
		tostring(selected.ChangedAt),
		tostring(selected.Gain),
		tostring(selected.Cost),
		tostring(policy.Gain),
		tostring(policy.Cost),
		tostring(policy.Cooldown),
		levels.join(","),
	].join(":");
	if (cache && cache.SpecializationPreviewKey === key && cache.SpecializationPreview !== undefined && cache.SpecializationPreview !== false) {
		return cache.SpecializationPreview as Snapshot;
	}
	const builds: BuildPreview[] = [];
	for (const build of Builds) {
		const preview = table.clone(profile);
		preview.Specialization =
			build.Id === selected.Focus
				? selected
				: { Focus: build.Id, ChangedAt: selected.ChangedAt, Gain: policy.Gain, Cost: policy.Cost };
		const card: BuildPreview = {
			Id: build.Id,
			Name: build.Name,
			Description: build.Description,
			Gain: build.Gain,
			Cost: build.Cost,
			GainMultiplier: Factor(preview.Specialization, build.Gain),
			CostMultiplier: Factor(preview.Specialization, build.Cost),
			Production: economy.Production(preview, now),
			Capacity: economy.Capacity(preview, now),
			Tap: economy.TapPower(preview, now),
			Offline: economy.OfflineEfficiency(preview, now),
		};
		builds.push(card);
	}
	const foundation: { Name: string; Value: number }[] = [];
	for (const item of [
		["GridProduction", "Production"],
		["GridCapacity", "Vault capacity"],
		["GridTap", "Overcharge"],
		["GridCritical", "Critical chance"],
		["GridAutomation", "Auto-collect"],
		["GridOffline", "Offline efficiency"],
	]) {
		const value = economy.GridEffect(profile, item[0]);
		if (value > 0) {
			foundation.push({ Name: item[1], Value: value });
		}
	}
	const build = Find(selected.Focus);
	assert(build, "sanitized specialization must exist");
	const snapshot: Snapshot = {
		Focus: selected.Focus,
		Name: build.Name,
		Builds: builds,
		Foundation: foundation,
		Gain: policy.Gain,
		Cost: policy.Cost,
		Cooldown: policy.Cooldown,
		ReadyAt: selected.ChangedAt > 0 ? selected.ChangedAt + policy.Cooldown : 0,
		Production: production,
		Capacity: capacity,
		Tap: tap,
		Offline: offline,
	};
	if (cache) {
		cache.SpecializationPreviewKey = key;
		cache.SpecializationPreview = snapshot;
	}
	return snapshot;
}

export = table.freeze({ Builds, Find, Sanitize, Configure, Factor, Policy, Select, Snapshot });
