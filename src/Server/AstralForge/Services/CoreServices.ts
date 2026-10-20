// Converted from CoreServices.luau — the lazy member bundle for the core gameplay services.
import {
	Dict,
	d,
	economyKit,
	LoadService,
	num,
	req,
	SharedFolder,
} from "./LuaInterop";
import ProfileBagMath from "../Modules/ProfileBagMath";
import OpsMath from "../Modules/OpsMath";
import ForgeEchoServiceFactory from "./CoreServiceMembers/ForgeEchoService";
import ProgressionServiceFactory from "./CoreServiceMembers/ProgressionService";
import LabServiceMember from "./CoreServiceMembers/LabService";
import ServerEventServiceFactory from "./CoreServiceMembers/ServerEventService";
import GuildServiceFactory from "./CoreServiceMembers/GuildService";

// The kit bundles and not-yet-converted Luau modules come back as opaque values; the members
// each GameService member actually calls are typed as callable records.
type Fn = (this: void, ...args: unknown[]) => unknown;
type Kit = Record<string, Fn>;
type Profile = Dict;

interface GameConfigShape {
	Game: Dict;
	Anomalies: Dict;
	Lab: Dict;
	Guild: Dict;
	Operations: Dict;
	Items: Dict;
	Economy: Dict;
	Overcharge: Dict;
	Continuum: Dict;
	Domain: Dict;
	Wheel: Dict;
	ForgePath: Dict;
	Social: Dict;
	Boosts: Dict;
	Unlocks: Dict;
	DailyRewards: Dict[];
	TimedRewards: Dict[];
	Achievements: Dict[];
	Story: Dict[];
	Mail: Dict[];
	Machines: Dict;
	Research: Dict;
	MaxZone: number;
	[key: string]: unknown;
}

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`CoreServices: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`CoreServices: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

__defs["ForgeEchoService"] = () => ForgeEchoServiceFactory;
__defs["ProgressionService"] = () => ProgressionServiceFactory;
__defs["LabService"] = LabServiceMember;
__defs["ServerEventService"] = () => ServerEventServiceFactory;
__defs["GuildService"] = () => GuildServiceFactory;

__defs["AnomalyService"] = () => {
	return (loadService: LoadService) => {
		const Workspace = game.GetService("Workspace");

		const Economy = economyKit("Economy") as Kit;
		const AnomalyPulseScore = OpsMath("AnomalyPulseScore") as Kit;
		const AnomalyOpsMath = economyKit("AnomalyOpsMath") as Kit;
		const GameConfig = req<GameConfigShape>(SharedFolder().WaitForChild("GameConfig"));
		const ProgressionService = loadService("ProgressionService") as Kit;

		const AnomalyService: Dict = {};

		function pulseNow(): number {
			return Workspace.GetServerTimeNow();
		}

		function bumpAnomalyStat(profile: Profile, key: string) {
			ProfileBagMath.BumpStat(profile, key, 1);
		}

		const overdrive: { Charge: number; BonusEndsAt: number } = {
			Charge: 0,
			BonusEndsAt: 0,
		};

		function overdriveActive(now: number): boolean {
			return overdrive.BonusEndsAt > now;
		}

		function contributeOverdrive(amount: number, now: number): boolean {
			if (overdriveActive(now)) {
				return false;
			}
			const target = num(GameConfig.Anomalies.OverdriveTarget) ?? 0;
			const before = overdrive.Charge;
			overdrive.Charge = math.min(target, overdrive.Charge + math.max(0, amount));
			if (before < target && overdrive.Charge >= target) {
				overdrive.Charge = 0;
				overdrive.BonusEndsAt = now + (num(GameConfig.Anomalies.OverdriveBonusSeconds) ?? 0);
				return true;
			}
			return false;
		}

		function OverdriveState(now?: number): Dict {
			const timestamp = now ?? pulseNow();
			return {
				Charge: overdrive.Charge,
				Target: GameConfig.Anomalies.OverdriveTarget,
				Active: overdriveActive(timestamp),
				BonusEndsAt: overdrive.BonusEndsAt,
				Multiplier: GameConfig.Anomalies.OverdriveBonusMultiplier,
			};
		}
		AnomalyService.OverdriveState = OverdriveState;

		function OverdriveMultiplier(now?: number): number {
			if (overdriveActive(now ?? pulseNow())) {
				return num(GameConfig.Anomalies.OverdriveBonusMultiplier) ?? 1;
			}
			return 1;
		}
		AnomalyService.OverdriveMultiplier = OverdriveMultiplier;

		function currentCycle(now?: number): LuaTuple<[number, Dict, number]> {
			const timestamp = now ?? pulseNow();
			const cycle = math.floor(timestamp / (num(GameConfig.Anomalies.CycleSeconds) ?? 1));
			const types = GameConfig.Anomalies.Types as Dict[];
			const index = (cycle % types.size()) + 1;
			return $tuple(cycle, types[index - 1], (cycle + 1) * (num(GameConfig.Anomalies.CycleSeconds) ?? 1));
		}

		function findProtocol(protocolId: string): Dict | undefined {
			return AnomalyOpsMath.FindProtocol(GameConfig.Anomalies.Protocols, protocolId) as Dict | undefined;
		}

		function activeDirectives(cycle: number): Dict[] {
			return AnomalyOpsMath.SelectDirectives(
				cycle,
				GameConfig.Anomalies.Directives,
				GameConfig.Anomalies.DirectiveSlots,
			) as Dict[];
		}

		function protocolEffect(profile: Profile, effectKind: string): number {
			const anomaly = profile.Anomaly as Dict | undefined;
			return num(
				AnomalyOpsMath.ProtocolEffect(anomaly?.Protocols, GameConfig.Anomalies.Protocols, effectKind),
			) ?? 0;
		}

		function rewardMultiplier(profile: Profile, anomaly: Dict): number {
			let channelAmount = 0;
			const channelId = (profile.Anomaly as Dict | undefined)?.Channel;
			const channel = typeIs(channelId, "string")
				? (d(GameConfig.Anomalies.Channels)[channelId] as Dict | undefined)
				: undefined;
			if (channel && channel.EffectKind === "Reward") {
				channelAmount = num(channel.EffectAmount) ?? 0;
			}
			return (
				num(
					AnomalyOpsMath.RewardMultiplier(anomaly.RewardMultiplier, protocolEffect(profile, "Reward"), channelAmount),
				) ?? 1
			);
		}

		function coreTierMaximumBonus(profile: Profile): number {
			const tier = (profile.Anomaly as Dict | undefined)?.CoreTier;
			return num(AnomalyOpsMath.CoreTierMaximumBonus(tier, GameConfig.Anomalies.CoreTiers)) ?? 0;
		}

		function Target(profile: Profile): number {
			const anomaly = ProfileBagMath.EnsureAnomaly(profile) as Dict;
			return num(
				AnomalyOpsMath.ChargeTarget(
					GameConfig.Anomalies.BaseTarget,
					GameConfig.Anomalies.TargetPerStabilization,
					GameConfig.Anomalies.MaximumTarget,
					anomaly.Stabilizations,
					coreTierMaximumBonus(profile),
				),
			) ?? 0;
		}
		AnomalyService.Target = Target;

		function Ensure(profile: Profile): boolean {
			const anomaly = ProfileBagMath.EnsureAnomaly(profile) as Dict;
			const [cycle] = currentCycle();
			let changed = false;
			if (anomaly.Cycle !== cycle) {
				anomaly.Cycle = cycle;
				anomaly.LastActionAt = 0;
				changed = true;
			}
			if (anomaly.DirectiveCycle !== cycle) {
				anomaly.DirectiveCycle = cycle;
				anomaly.DirectiveProgress = {};
				anomaly.DirectiveClaims = {};
				changed = true;
			}
			return changed;
		}
		AnomalyService.Ensure = Ensure;

		function Signal(profile: Profile, kind: string, amount?: number) {
			Ensure(profile);
			const [cycle] = currentCycle();
			for (const directive of activeDirectives(cycle)) {
				const definition = directive.Definition as Dict;
				if (definition.Kind === kind) {
					const progress = d(profile.Anomaly).DirectiveProgress as Dict;
					const previous = num(progress[definition.Id as string]) ?? 0;
					if (kind === "Combo") {
						progress[definition.Id as string] = math.min(
							num(directive.Target) ?? 0,
							math.max(previous, amount ?? 0),
						);
					} else {
						progress[definition.Id as string] = math.min(
							num(directive.Target) ?? 0,
							previous + math.max(0, amount ?? 1),
						);
					}
				}
			}
		}
		AnomalyService.Signal = Signal;

		function Progress(profile: Profile, baseAmount: number): LuaTuple<[number, boolean]> {
			Ensure(profile);
			const [, anomaly] = currentCycle();
			d(profile.Anomaly).LastActionAt = pulseNow();

			const target = Target(profile);
			const wasReady = (num(d(profile.Anomaly).Charge) ?? 0) >= target;
			const capture = 1 + protocolEffect(profile, "ChargeGain");
			const amount = math.max(0, baseAmount) * capture * (num(anomaly.ChargeMultiplier) ?? 1);
			d(profile.Anomaly).Charge = math.min(target * 1.5, (num(d(profile.Anomaly).Charge) ?? 0) + amount);
			Signal(profile, "Action", 1);
			return $tuple(amount, !wasReady && (num(d(profile.Anomaly).Charge) ?? 0) >= target);
		}
		AnomalyService.Progress = Progress;

		const PULSE_MIN_INTERVAL = num(GameConfig.Anomalies.PulseCooldownSeconds) ?? 0.25;

		function Pulse(profile: Profile, random: Random): LuaTuple<[boolean, string, Dict | undefined]> {
			Ensure(profile);
			const now = pulseNow();
			const anomalyState = d(profile.Anomaly);
			const lastAction = num(anomalyState.LastActionAt) ?? 0;
			if (now - lastAction < PULSE_MIN_INTERVAL) {
				return $tuple(
					false,
					string.format("Pulse recharging (%.2fs).", PULSE_MIN_INTERVAL - (now - lastAction)),
					undefined,
				);
			}
			anomalyState.LastActionAt = now;

			const accurate = AnomalyPulseScore.IsAccurate(
				now,
				anomalyState.PulseWindowStartedAt,
				GameConfig.Anomalies.PulseWindowSeconds,
				GameConfig.Anomalies.PulseWindowSweetZone,
			) as boolean;
			anomalyState.PulseWindowStartedAt = now;

			anomalyState.Combo = AnomalyPulseScore.NextCombo(
				anomalyState.Combo,
				accurate,
				GameConfig.Anomalies.PulseComboMax,
			);
			if (accurate) {
				anomalyState.BestCombo = AnomalyPulseScore.NextBestCombo(anomalyState.BestCombo, anomalyState.Combo);
			}
			const comboBonus = num(
				AnomalyPulseScore.ComboBonus(anomalyState.Combo, GameConfig.Anomalies.PulseComboBonusPerStack),
			) ?? 1;
			const accuracyBonus = num(
				AnomalyPulseScore.AccuracyBonus(accurate, GameConfig.Anomalies.PulseAccurateBonus),
			) ?? 1;

			const pulsePower = 1 + protocolEffect(profile, "PulsePower");
			const overdriveMultiplier = OverdriveMultiplier(now);
			const [amount, becameReady] = Progress(
				profile,
				random.NextNumber(3.8, 5.4) * pulsePower * comboBonus * accuracyBonus * overdriveMultiplier,
			) as LuaTuple<[number, boolean]>;
			Signal(profile, "Pulse", 1);
			Signal(profile, "Combo", anomalyState.Combo as number);
			bumpAnomalyStat(profile, "AnomalyPulses");
			const overdriveTriggered = contributeOverdrive(
				num(GameConfig.Anomalies.OverdrivePulseContribution) ?? 0,
				now,
			);
			return $tuple(
				true,
				accurate
					? string.format("Perfect pulse. Combo x%d, +%.1f charge.", num(anomalyState.Combo) ?? 0, amount)
					: string.format("Quantum pulse captured %.1f charge.", amount),
				{
					Amount: amount,
					Charge: anomalyState.Charge,
					Ready: (num(anomalyState.Charge) ?? 0) >= Target(profile),
					BecameReady: becameReady,
					Accurate: accurate,
					Combo: anomalyState.Combo,
					PulseWindowStartedAt: anomalyState.PulseWindowStartedAt,
					OverdriveTriggered: overdriveTriggered,
				},
			);
		}
		AnomalyService.Pulse = Pulse;

		function applyCoreXP(profile: Profile, xp: number): number {
			return num(AnomalyOpsMath.ApplyCoreXP(profile.Anomaly, xp, GameConfig.Anomalies.CoreTiers)) ?? 0;
		}

		function Stabilize(profile: Profile): LuaTuple<[boolean, string, Dict | undefined]> {
			Ensure(profile);
			const [, anomaly] = currentCycle();
			const anomalyState = d(profile.Anomaly);
			const target = Target(profile);
			if ((num(anomalyState.Charge) ?? 0) < target) {
				return $tuple(
					false,
					string.format("The anomaly needs %.1f more charge.", target - (num(anomalyState.Charge) ?? 0)),
					undefined,
				);
			}

			const now = pulseNow();
			anomalyState.Charge = math.max(0, (num(anomalyState.Charge) ?? 0) - target);
			anomalyState.Stabilizations = (num(anomalyState.Stabilizations) ?? 0) + 1;
			const discoveries = anomalyState.Discoveries as Dict;
			discoveries[anomaly.Id as string] = (num(discoveries[anomaly.Id as string]) ?? 0) + 1;
			bumpAnomalyStat(profile, "AnomalyStabilizations");
			Signal(profile, "Stabilize", 1);
			const tiersGained = applyCoreXP(profile, num(GameConfig.Anomalies.CoreXPPerStabilization) ?? 0);
			const overdriveTriggered = contributeOverdrive(
				num(GameConfig.Anomalies.OverdriveStabilizeContribution) ?? 0,
				now,
			);

			const level = num(anomalyState.Stabilizations) ?? 0;
			const yield_ = rewardMultiplier(profile, anomaly);
			const fragments = math.max(1, math.floor((4 + level * 0.72) * yield_));
			const reward: Dict = {
				Stardust: math.max(1, math.floor((5 + level * 0.85) * yield_)),
				Signals: math.max(1, math.floor((4 + level * 0.55) * yield_)),
				CommandXP: math.max(10, math.floor((35 + level * 6) * yield_)),
				Cores: level % 5 === 0 ? math.max(1, math.floor(level / 5)) : undefined,
			};
			anomalyState.Fragments =
				math.max(0, math.floor(num(anomalyState.Fragments) ?? 0)) + fragments;
			if (anomalyState.Fragments !== anomalyState.Fragments || anomalyState.Fragments === math.huge) {
				anomalyState.Fragments = 1e308;
			}
			const rewardText = ProgressionService.ApplyReward(profile, reward, Economy.SteadyProduction(profile)) as string;
			let message = string.format("%s stabilized: %d fragments, %s.", anomaly.Name as string, fragments, rewardText);
			if (tiersGained > 0) {
				message = string.format("%s Core Tier %d reached!", message, num(anomalyState.CoreTier) ?? 0);
			}
			return $tuple(true, message, {
				AnomalyId: anomaly.Id,
				AnomalyName: anomaly.Name,
				Fragments: fragments,
				Stabilizations: level,
				Reward: reward,
				CoreTier: anomalyState.CoreTier,
				CoreXP: anomalyState.CoreXP,
				TiersGained: tiersGained,
				OverdriveTriggered: overdriveTriggered,
			});
		}
		AnomalyService.Stabilize = Stabilize;

		function ProtocolCost(protocol: Dict, level: number): number {
			return num(AnomalyOpsMath.ProtocolCost(protocol, level)) ?? 0;
		}
		AnomalyService.ProtocolCost = ProtocolCost;

		function BuyProtocol(profile: Profile, protocolId: string): LuaTuple<[boolean, string, Dict | undefined]> {
			Ensure(profile);
			const protocol = findProtocol(protocolId);
			if (protocol === undefined) {
				return $tuple(false, "That reactor upgrade was not found.", undefined);
			}
			const anomaly = d(profile.Anomaly);
			const protocols = anomaly.Protocols as Dict;
			const level = num(protocols[protocol.Id as string]) ?? 0;
			if (level >= (num(protocol.MaxLevel) ?? 0)) {
				return $tuple(false, "That reactor upgrade is at max level.", undefined);
			}
			const cost = ProtocolCost(protocol, level);
			if ((num(anomaly.Fragments) ?? 0) < cost) {
				return $tuple(false, string.format("Requires %d anomaly fragments.", cost), undefined);
			}
			anomaly.Fragments = (num(anomaly.Fragments) ?? 0) - cost;
			protocols[protocol.Id as string] = level + 1;
			bumpAnomalyStat(profile, "AnomalyProtocols");
			return $tuple(true, string.format("%s advanced to level %d.", protocol.Name as string, level + 1), {
				ProtocolId: protocol.Id,
				ProtocolName: protocol.Name,
				Level: level + 1,
			});
		}
		AnomalyService.BuyProtocol = BuyProtocol;

		function ActivateSurge(profile: Profile): LuaTuple<[boolean, string, Dict | undefined]> {
			Ensure(profile);
			const now = pulseNow();
			const anomaly = d(profile.Anomaly);
			if ((num(anomaly.SurgeEndsAt) ?? 0) > now) {
				return $tuple(false, "Quantum Surge is already active.", undefined);
			}
			const cost = num(GameConfig.Anomalies.SurgeCost) ?? 0;
			if ((num(anomaly.Fragments) ?? 0) < cost) {
				return $tuple(false, string.format("Requires %d anomaly fragments.", cost), undefined);
			}
			anomaly.Fragments = (num(anomaly.Fragments) ?? 0) - cost;
			const duration = (num(GameConfig.Anomalies.SurgeBaseSeconds) ?? 0) + protocolEffect(profile, "SurgeDuration");
			anomaly.SurgeEndsAt = now + duration;
			return $tuple(true, string.format("Surge on for %d seconds.", duration), {
				EndsAt: anomaly.SurgeEndsAt,
				Duration: duration,
			});
		}
		AnomalyService.ActivateSurge = ActivateSurge;

		function SetLoadout(profile: Profile, rawLoadout: unknown): LuaTuple<[boolean, string, Dict | undefined]> {
			if (!typeIs(rawLoadout, "table")) {
				return $tuple(false, "Invalid reactor loadout.", undefined);
			}
			Ensure(profile);
			const slots = num(GameConfig.Anomalies.LoadoutSlots) ?? 0;
			let count = 0;
			for (const [key] of pairs(rawLoadout)) {
				count += 1;
				if (!typeIs(key, "number") || key < 1 || key !== math.floor(key)) {
					return $tuple(false, "Invalid reactor loadout.", undefined);
				}
			}
			if (count > slots) {
				return $tuple(false, string.format("You can only slot %d channels at once.", slots), undefined);
			}
			const seen: Dict = {};
			const resolved: string[] = [];
			const loadoutArray = rawLoadout as unknown[];
			for (let index = 0; index < count; index++) {
				const channelId = loadoutArray[index];
				if (!typeIs(channelId, "string")) {
					return $tuple(false, "Invalid reactor loadout.", undefined);
				}
				const channel = d(GameConfig.Anomalies.Channels)[channelId];
				if (!channel) {
					return $tuple(false, "That channel doesn't exist.", undefined);
				}
				if (seen[channelId]) {
					return $tuple(false, "Each channel can only be slotted once.", undefined);
				}
				seen[channelId] = true;
				resolved.push(channelId);
			}
			const anomaly = d(profile.Anomaly);
			anomaly.Loadout = resolved;
			anomaly.Channel = resolved[0] ?? "Flux";
			const label =
				resolved.size() === 0
					? "cleared"
					: string.format("%d channel%s slotted", resolved.size(), resolved.size() === 1 ? "" : "s");
			return $tuple(true, string.format("Reactor loadout %s.", label), { Loadout: resolved });
		}
		AnomalyService.SetLoadout = SetLoadout;

		function ClaimMilestone(profile: Profile, rawTier: unknown): LuaTuple<[boolean, string, Dict | undefined]> {
			if (!typeIs(rawTier, "number")) {
				return $tuple(false, "Invalid anomaly milestone.", undefined);
			}
			Ensure(profile);
			const tier = math.floor(rawTier);
			const milestone = d(GameConfig.Anomalies.Milestones)[tier] as Dict | undefined;
			if (!milestone || (num(d(profile.Anomaly).Stabilizations) ?? 0) < (num(milestone.Required) ?? 0)) {
				return $tuple(false, "That anomaly milestone is still locked.", undefined);
			}
			const key = tostring(tier);
			const claims = d(profile.Anomaly).MilestoneClaims as Dict;
			if (claims[key]) {
				return $tuple(false, "That anomaly milestone was already claimed.", undefined);
			}
			claims[key] = true;
			const rewardText = ProgressionService.ApplyReward(
				profile,
				milestone.Reward,
				Economy.SteadyProduction(profile),
			) as string;
			return $tuple(true, string.format("Reactor mark %d: %s.", tier, rewardText), {
				Tier: tier,
				Reward: milestone.Reward,
			});
		}
		AnomalyService.ClaimMilestone = ClaimMilestone;

		function ClaimDirective(profile: Profile, directiveId: string): LuaTuple<[boolean, string, Dict | undefined]> {
			Ensure(profile);
			const [cycle] = currentCycle();
			let active: Dict | undefined;
			for (const directive of activeDirectives(cycle)) {
				if (d(directive.Definition).Id === directiveId) {
					active = directive;
					break;
				}
			}
			if (active === undefined) {
				return $tuple(false, "That reactor job isn't active anymore.", undefined);
			}
			const definition = active.Definition as Dict;
			const anomalyState = d(profile.Anomaly);
			const claims = anomalyState.DirectiveClaims as Dict;
			if (claims[definition.Id as string]) {
				return $tuple(false, "You already claimed that job.", undefined);
			}
			const progressTable = anomalyState.DirectiveProgress as Dict;
			const progress = num(progressTable[definition.Id as string]) ?? 0;
			if (progress < (num(active.Target) ?? 0)) {
				return $tuple(false, "That job isn't finished yet.", undefined);
			}
			claims[definition.Id as string] = true;
			anomalyState.Fragments =
				math.max(0, math.floor(num(anomalyState.Fragments) ?? 0)) +
				math.max(0, math.floor(num(definition.Fragments) ?? 0));
			if (anomalyState.Fragments !== anomalyState.Fragments || anomalyState.Fragments === math.huge) {
				anomalyState.Fragments = 1e308;
			}
			bumpAnomalyStat(profile, "AnomalyDirectives");
			const rewardText = ProgressionService.ApplyReward(
				profile,
				definition.Reward,
				Economy.SteadyProduction(profile),
			) as string;
			return $tuple(
				true,
				string.format("%s complete: %d fragments, %s.", definition.Name as string, num(definition.Fragments) ?? 0, rewardText),
				{
					DirectiveId: definition.Id,
					DirectiveName: definition.Name,
					Fragments: definition.Fragments,
				},
			);
		}
		AnomalyService.ClaimDirective = ClaimDirective;

		function State(profile: Profile): Dict {
			Ensure(profile);
			const now = pulseNow();
			const [cycle, anomaly, endsAt] = currentCycle(now) as LuaTuple<[number, Dict, number]>;
			const anomalyState = d(profile.Anomaly);

			const directiveCycleIsCurrent = anomalyState.DirectiveCycle === cycle;
			const directiveProgress = (directiveCycleIsCurrent ? anomalyState.DirectiveProgress : {}) as Dict;
			const directiveClaims = (directiveCycleIsCurrent ? anomalyState.DirectiveClaims : {}) as Dict;
			const protocols: Dict = {};
			let protocolLevels = 0;
			for (const protocol of GameConfig.Anomalies.Protocols as Dict[]) {
				const level = num(d(anomalyState.Protocols)[protocol.Id as string]) ?? 0;
				protocolLevels += level;
				protocols[protocol.Id as string] = level;
			}
			const discoveries = table.clone(anomalyState.Discoveries as Dict);
			const milestones: Dict = {};
			let claimable = 0;
			for (const [tier, milestone] of pairs(GameConfig.Anomalies.Milestones as object)) {
				const milestoneDef = milestone as Dict;
				const claimed = d(anomalyState.MilestoneClaims)[tostring(tier)] === true;
				if (!claimed && (num(anomalyState.Stabilizations) ?? 0) >= (num(milestoneDef.Required) ?? 0)) {
					claimable += 1;
				}
				milestones[tostring(tier)] = {
					Tier: tier,
					Required: milestoneDef.Required,
					Reward: milestoneDef.Reward,
					Claimed: claimed,
				};
			}
			const directives: Dict = {};
			let claimableDirectives = 0;
			for (const [slot, directive] of pairs(activeDirectives(cycle))) {
				const directiveDef = directive as Dict;
				const definition = directiveDef.Definition as Dict;
				const progress = math.min(num(directiveDef.Target) ?? 0, num(directiveProgress[definition.Id as string]) ?? 0);
				const claimed = directiveClaims[definition.Id as string] === true;
				if (!claimed && progress >= (num(directiveDef.Target) ?? 0)) {
					claimableDirectives += 1;
				}
				const reward = table.clone(definition.Reward as Dict);
				reward.Fragments = definition.Fragments;
				directives[tostring(slot)] = {
					Id: definition.Id,
					Name: definition.Name,
					Description: definition.Description,
					Kind: definition.Kind,
					Target: directiveDef.Target,
					Progress: progress,
					Claimed: claimed,
					Reward: reward,
					Color: definition.Color,
				};
			}
			const target = Target(profile);
			const ready = (num(anomalyState.Charge) ?? 0) >= target;
			const surgeActive = (num(anomalyState.SurgeEndsAt) ?? 0) > now;
			const phase = surgeActive ? (ready ? "SurgingReady" : "Surging") : ready ? "Ready" : "Charging";

			const coreTier = math.max(0, math.floor(num(anomalyState.CoreTier) ?? 0));
			const coreXP = math.max(0, num(anomalyState.CoreXP) ?? 0);
			const nextCoreTier = AnomalyOpsMath.NextCoreTier(coreTier, GameConfig.Anomalies.CoreTiers);
			let loadout = (typeIs(anomalyState.Loadout, "table") ? anomalyState.Loadout : []) as string[];
			if (
				loadout.size() === 0 &&
				anomalyState.Channel &&
				d(GameConfig.Anomalies.Channels)[anomalyState.Channel as string]
			) {
				loadout = [anomalyState.Channel as string];
			}

			return {
				Cycle: cycle,
				TypeId: anomaly.Id,
				EndsAt: endsAt,
				Charge: anomalyState.Charge,
				Target: target,
				Ready: ready,
				Phase: phase,
				Fragments: anomalyState.Fragments,
				Stabilizations: anomalyState.Stabilizations,
				SurgeEndsAt: anomalyState.SurgeEndsAt,
				Channel: anomalyState.Channel,
				Loadout: loadout,
				LoadoutSlots: GameConfig.Anomalies.LoadoutSlots,
				Protocols: protocols,
				ProtocolLevels: protocolLevels,
				Discoveries: discoveries,
				Milestones: milestones,
				ClaimableMilestones: claimable,
				Directives: directives,
				ClaimableDirectives: claimableDirectives,
				ChargeMultiplier: (num(anomaly.ChargeMultiplier) ?? 1) * (1 + protocolEffect(profile, "ChargeGain")),
				RewardMultiplier: rewardMultiplier(profile, anomaly),
				PulseWindowStartedAt: anomalyState.PulseWindowStartedAt ?? 0,
				PulseWindowSeconds: GameConfig.Anomalies.PulseWindowSeconds,
				PulseWindowSweetZone: GameConfig.Anomalies.PulseWindowSweetZone,
				Combo: anomalyState.Combo ?? 0,
				BestCombo: anomalyState.BestCombo ?? 0,
				ComboMax: GameConfig.Anomalies.PulseComboMax,
				CoreTier: coreTier,
				CoreXP: coreXP,
				NextCoreTier: nextCoreTier,
				Overdrive: OverdriveState(now),
			};
		}
		AnomalyService.State = State;

		return table.freeze(AnomalyService);
	};
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) __members.push(name);
__members.sort();
table.freeze(__members);

type CoreServicesCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const CoreServices = setmetatable({}, {
	__call: (_self: unknown, name: string): unknown => __load(name),
	__index: (_self: unknown, name: string): unknown => name === "__members" ? __members : __load(name),
} as LuaMetatable<object>) as unknown as CoreServicesCallable;

export = CoreServices;
