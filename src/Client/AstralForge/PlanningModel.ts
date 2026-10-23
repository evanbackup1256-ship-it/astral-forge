import { Dict, OmegaMathApi, OmegaValue, truthy } from "./lua";

interface RankState {
	Rank?: number;
	CanUpgrade?: unknown;
	FluxCost?: unknown;
	StardustCost?: unknown;
	OfflineBonus?: number;
}
interface RankRules {
	MilestoneEvery?: number;
	MilestoneScale?: number;
	MaxRank?: number;
	ProductionScale?: number;
	CapacityScale?: number;
	TapScale?: number;
	OfflineCap?: number;
	OfflinePerRank?: number;
}
interface Job {
	Id: string;
	Name?: unknown;
	Claimed?: unknown;
	Progress?: unknown;
	Target?: unknown;
	[key: string]: unknown;
}
interface Milestone {
	Tier: number;
	Required: number;
	Claimed?: unknown;
	[key: string]: unknown;
}
interface ProtocolDefinition {
	Id: string;
	BaseCost: unknown;
	CostScale: unknown;
	MaxLevel?: number;
	[key: string]: unknown;
}
interface AnomalyState {
	Loadout?: string[];
	Channel?: string;
	LoadoutSlots?: number;
	Protocols?: Record<string, number>;
	Fragments?: unknown;
	Charge?: unknown;
	Target?: unknown;
	Directives?: Job[];
	Milestones?: Milestone[];
	Ready?: unknown;
	Stabilizations?: number;
	[key: string]: unknown;
}
interface Protocol {
	definition: ProtocolDefinition;
	level: number;
	cost: OmegaValue;
	capped: boolean;
	ready: boolean;
}
interface ShiftPlan {
	charge: number;
	jobs: Job[];
	milestones: Milestone[];
	protocols: Protocol[];
	title?: string;
	body?: unknown;
	action?: string;
	payload?: Dict;
}

export = (Math: OmegaMathApi) => {
	const Model = {
		ratio(this: void, value: unknown, target: unknown): number {
			if (!Math.Gt(truthy(target) ? target : 0, 0)) {
				return 0;
			}
			return math.clamp(Math.ToNumber(Math.Div(truthy(value) ? value : 0, target)), 0, 1);
		},

		nextRank(this: void, state: Dict, config: Dict) {
			const rank = (state.Continuum ?? {}) as RankState;
			const rules = (config.Continuum ?? {}) as RankRules;
			const current = rank.Rank ?? 0;
			const interval = math.max(1, rules.MilestoneEvery ?? 25);
			const nextRank = current + 1;
			const milestone = nextRank % interval === 0;
			const multiplier = milestone ? rules.MilestoneScale ?? 1.5 : 1;
			const capped = current >= (rules.MaxRank ?? math.huge);
			return {
				rank: current,
				nextRank,
				capped,
				ready: !capped && rank.CanUpgrade === true,
				flux: Math.Max(0, Math.Sub(rank.FluxCost ?? 0, state.Cash ?? 0)),
				dust: Math.Max(0, Math.Sub(rank.StardustCost ?? 0, state.Stardust ?? 0)),
				fluxProgress: Model.ratio(state.Cash, rank.FluxCost),
				dustProgress: Model.ratio(state.Stardust, rank.StardustCost),
				milestone,
				milestoneRank: (math.floor(current / interval) + 1) * interval,
				production: (rules.ProductionScale ?? 1.16) * multiplier,
				capacity: rules.CapacityScale ?? 1.1,
				tap: rules.TapScale ?? 1.14,
				offline: math.min(rules.OfflineCap ?? 0.45, (rank.OfflineBonus ?? 0) + (rules.OfflinePerRank ?? 0.0025)),
			};
		},

		toggleLoadout(this: void, anomaly: AnomalyState, id: string): LuaTuple<[string[] | undefined, string | undefined]> {
			const result: string[] = [];
			let present = false;
			const current = anomaly.Loadout ?? [anomaly.Channel ?? "Strike"];
			for (const entry of current) {
				if (entry === id) {
					present = true;
				} else {
					result.push(entry);
				}
			}
			if (present) {
				if (result.size() === 0) {
					return $tuple(undefined, "Keep at least one channel equipped.");
				}
			} else {
				if (result.size() >= math.max(1, anomaly.LoadoutSlots ?? 1)) {
					return $tuple(undefined, "Unequip a channel to free a slot.");
				}
				result.push(id);
			}
			return $tuple(result, undefined);
		},

		protocol(this: void, anomaly: AnomalyState, definition: ProtocolDefinition): Protocol {
			const level = (anomaly.Protocols ?? {})[definition.Id] ?? 0;
			const cost = Math.Max(
				1,
				Math.Floor(Math.Add(Math.Mul(definition.BaseCost, Math.Pow(definition.CostScale, level)), 0.5)),
			);
			const capped = level >= (definition.MaxLevel ?? math.huge);
			return {
				definition,
				level,
				cost,
				capped,
				ready: !capped && Math.Gte(anomaly.Fragments ?? 0, cost),
			};
		},

		shift(this: void, state: Dict, config: Dict): ShiftPlan {
			const anomaly = (state.Anomaly ?? {}) as AnomalyState;
			const plan: ShiftPlan = {
				charge: Model.ratio(anomaly.Charge, anomaly.Target),
				jobs: [],
				milestones: [],
				protocols: [],
			};
			for (const job of anomaly.Directives ?? []) {
				if (!truthy(job.Claimed)) {
					plan.jobs.push(job);
				}
			}
			plan.jobs.sort((a, b) => {
				const ra = Model.ratio(a.Progress, a.Target);
				const rb = Model.ratio(b.Progress, b.Target);
				return ra === rb ? a.Id < b.Id : ra > rb;
			});
			for (const milestone of anomaly.Milestones ?? []) {
				if (!truthy(milestone.Claimed)) {
					plan.milestones.push(milestone);
				}
			}
			const anomalies = (config.Anomalies ?? {}) as { Protocols?: ProtocolDefinition[] };
			for (const definition of anomalies.Protocols ?? []) {
				plan.protocols.push(Model.protocol(anomaly, definition));
			}
			plan.protocols.sort((a, b) => {
				if (a.ready !== b.ready) {
					return a.ready;
				}
				if (Math.Compare(a.cost, b.cost) === 0) {
					return a.definition.Id < b.definition.Id;
				}
				return Math.Lt(a.cost, b.cost);
			});
			const firstJob = plan.jobs[0];
			const firstMilestone = plan.milestones[0];
			if (truthy(anomaly.Ready)) {
				plan.title = "Bank your completed shift";
				plan.body = "Charge is full. Collect your shift reward and start the next cycle.";
				plan.action = "StabilizeAnomaly";
			} else if (firstJob && Model.ratio(firstJob.Progress, firstJob.Target) >= 1) {
				plan.title = "Collect a finished directive";
				plan.body = firstJob.Name;
				plan.action = "ClaimAnomalyDirective";
				plan.payload = { Id: firstJob.Id };
			} else if (firstMilestone && (anomaly.Stabilizations ?? 0) >= firstMilestone.Required) {
				plan.title = "Collect your shift milestone";
				plan.body = `Tier ${firstMilestone.Tier} reward is ready.`;
				plan.action = "ClaimAnomalyMilestone";
				plan.payload = { Tier: firstMilestone.Tier };
			} else {
				plan.title = "Build charge with a pulse";
				plan.body = `Charge is ${math.floor(plan.charge * 100)}%. Pulses and game actions advance the current shift.`;
				plan.action = "PulseAnomaly";
			}
			return plan;
		},
	};
	return Model;
};
