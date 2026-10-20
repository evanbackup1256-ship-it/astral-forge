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
		error(`OpsMath: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`OpsMath: cyclic require of member ${name}`, 2);
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

__defs["GuildGoalMath"] = () => {
	interface GoalType {
		Id: string;
		Metric: string;
		BaseTarget: number;
		TargetPerMember: number;
		Reward?: unknown;
		Name?: string;
		Description?: string;
	}

	interface GoalConfig {
		DurationSeconds: number;
		MinContributionForReward?: number;
		Types: GoalType[];
	}

	interface GoalState {
		TypeId: string;
		Target: number;
		Progress: number;
		StartedAt: number;
		EndsAt: number;
		Completed: boolean;
		CompletedAt: number;
		Contributors: Record<string, number>;
		Claimed: Record<string, unknown>;
	}

	const MAX_NUMBER = 1e308;

	function finiteNonNegative(value: unknown): number {
		if (!typeIs(value, "number") || value !== value || value === math.huge || value === -math.huge) {
			return 0;
		}
		return math.clamp(value, 0, MAX_NUMBER);
	}

	function goalTarget(baseTarget: number, targetPerMember: number, members: number): number {
		return math.max(1, math.floor(baseTarget + targetPerMember * math.max(0, members - 1) + 0.5));
	}

	function addClamped(current: unknown, amount: number): number {
		return math.min(MAX_NUMBER, finiteNonNegative(current) + amount);
	}

	const GuildGoalMath = {
		GoalTypeById(this: void, types: unknown, typeId: string): GoalType | undefined {
			if (!typeIs(types, "table") || !typeIs(typeId, "string") || typeId === "") {
				return undefined;
			}
			for (const [, entry] of pairs(types)) {
				if (
					typeIs(entry, "table") &&
					(entry as Record<string, unknown>).Id === typeId
				) {
					return entry as GoalType;
				}
			}
			return undefined;
		},

		MemberCount(this: void, guild: unknown): number {
			let count = 0;
			const bag = guild as Record<string, unknown> | undefined;
			if (typeIs(guild, "table") && typeIs(bag!.Members, "table")) {
				for (const _ of pairs(bag!.Members as object)) {
					count += 1;
				}
			}
			return count;
		},

		RollGoal(this: void, guild: unknown, now: number, goalConfig: GoalConfig): GoalState {
			const types = goalConfig.Types;
			const goalBag = (typeIs(guild, "table")
				? (guild as Record<string, unknown>).Goal
				: undefined) as Record<string, unknown> | undefined;
			const previous =
				typeIs(guild, "table") && typeIs(goalBag, "table") ? goalBag!.TypeId : undefined;
			let index = 1;
			const duration = math.max(1, math.floor(tonumber(goalConfig.DurationSeconds) ?? 1));
			const safeNow = math.max(0, math.floor(tonumber(now) ?? 0));
			if (!typeIs(types, "table") || types.size() < 1) {
				return {
					TypeId: "",
					Target: 1,
					Progress: 0,
					StartedAt: safeNow,
					EndsAt: safeNow + duration,
					Completed: false,
					CompletedAt: 0,
					Contributors: {},
					Claimed: {},
				};
			}
			if (previous !== undefined && previous !== false) {
				for (const [position, entry] of ipairs(types)) {
					if (typeIs(entry, "table") && entry.Id === previous) {
						index = (position % types.size()) + 1;
						break;
					}
				}
			} else {
				index = (math.floor(safeNow / duration) % types.size()) + 1;
			}
			const definition = types[index - 1];
			const target = goalTarget(
				tonumber(definition.BaseTarget) ?? 1,
				tonumber(definition.TargetPerMember) ?? 0,
				GuildGoalMath.MemberCount(guild),
			);
			return {
				TypeId: definition.Id,
				Target: target,
				Progress: 0,
				StartedAt: safeNow,
				EndsAt: safeNow + duration,
				Completed: false,
				CompletedAt: 0,
				Contributors: {},
				Claimed: {},
			};
		},

		EnsureGoal(this: void, guild: unknown, now: number, goalConfig: GoalConfig): boolean {
			if (!typeIs(guild, "table")) {
				return false;
			}
			const bag = guild as Record<string, unknown>;
			const safeNow = math.max(0, math.floor(tonumber(now) ?? 0));
			const goal = bag.Goal as Record<string, unknown> | undefined;
			const types = goalConfig !== undefined ? goalConfig.Types : undefined;
			if (
				!typeIs(goal, "table") ||
				GuildGoalMath.GoalTypeById(types, (goal!.TypeId as string) ?? "") === undefined
			) {
				bag.Goal = GuildGoalMath.RollGoal(guild, safeNow, goalConfig);
				return true;
			}
			let changed = false;
			const nextTarget = math.max(1, finiteNonNegative(tonumber(goal!.Target)));
			const nextProgress = finiteNonNegative(tonumber(goal!.Progress));
			const nextEndsAt = finiteNonNegative(tonumber(goal!.EndsAt));
			const nextCompletedAt = finiteNonNegative(tonumber(goal!.CompletedAt));
			const nextCompleted = goal!.Completed === true;
			if (goal!.Target !== nextTarget) {
				goal!.Target = nextTarget;
				changed = true;
			}
			if (goal!.Progress !== nextProgress) {
				goal!.Progress = nextProgress;
				changed = true;
			}
			if (goal!.EndsAt !== nextEndsAt) {
				goal!.EndsAt = nextEndsAt;
				changed = true;
			}
			if (goal!.Completed !== nextCompleted) {
				goal!.Completed = nextCompleted;
				changed = true;
			}
			if (goal!.CompletedAt !== nextCompletedAt) {
				goal!.CompletedAt = nextCompletedAt;
				changed = true;
			}
			if (!typeIs(goal!.Contributors, "table")) {
				goal!.Contributors = {};
				changed = true;
			}
			if (!typeIs(goal!.Claimed, "table")) {
				goal!.Claimed = {};
				changed = true;
			}
			if (safeNow >= (goal!.EndsAt as number)) {
				bag.Goal = GuildGoalMath.RollGoal(guild, safeNow, goalConfig);
				return true;
			}
			return changed;
		},

		AdvanceGoal(
			this: void,
			guild: unknown,
			userKey: string,
			metric: string,
			amount: number,
			now: number,
			goalConfig: GoalConfig,
		): void {
			GuildGoalMath.EnsureGoal(guild, now, goalConfig);
			const goal = (guild as Record<string, unknown>).Goal as Record<string, unknown> | undefined;
			if (!typeIs(goal, "table") || goal!.Completed === true) {
				return;
			}
			const definition = GuildGoalMath.GoalTypeById(goalConfig.Types, goal!.TypeId as string);
			if (!definition || definition.Metric !== metric) {
				return;
			}
			const gain = finiteNonNegative(amount);
			if (gain <= 0) {
				return;
			}
			const contributors = goal!.Contributors as Record<string, number>;
			goal!.Progress = addClamped(goal!.Progress, gain);
			contributors[userKey] = addClamped(contributors[userKey], gain);
			if ((goal!.Progress as number) >= (goal!.Target as number)) {
				goal!.Completed = true;
				goal!.CompletedAt = math.max(0, math.floor(tonumber(now) ?? 0));
			}
		},

		CanClaimGoal(
			this: void,
			goal: unknown,
			userKey: string,
			isMember: boolean,
			minContribution: number,
		): LuaTuple<[boolean, string | undefined]> {
			if (!isMember) {
				return $tuple(false, "You are not in that guild.");
			}
			if (!typeIs(goal, "table")) {
				return $tuple(false, "The guild goal is not finished yet.");
			}
			const goalBag = goal as Record<string, unknown>;
			if (goalBag.Completed !== true) {
				return $tuple(false, "The guild goal is not finished yet.");
			}
			const claimed = typeIs(goalBag.Claimed, "table")
				? (goalBag.Claimed as Record<string, unknown>)
				: undefined;
			if (claimed && claimed[userKey]) {
				return $tuple(false, "You already claimed this goal.");
			}
			const contributors = typeIs(goalBag.Contributors, "table")
				? (goalBag.Contributors as Record<string, unknown>)
				: undefined;
			const contributed = finiteNonNegative(contributors !== undefined ? contributors[userKey] : undefined);
			const min = math.max(0, tonumber(minContribution) ?? 0);
			if (contributed < min) {
				return $tuple(false, "Only members who helped with this goal can claim it.");
			}
			return $tuple(true, undefined);
		},
	};

	return table.freeze(GuildGoalMath);
};

__defs["GuildMath"] = () => {
	interface UpgradeDefinition {
		BaseCost: number;
		CostScale: number;
		EffectPerLevel: number;
		MaxLevel?: number;
		Currency?: string;
		Bonus?: string;
		Tiers?: { Name?: string; Effect?: number; Cost?: number }[];
	}

	interface OmegaMathLike {
		Lt(left: unknown, right: unknown): boolean;
		Add(left: unknown, right: unknown): unknown;
		Sub(left: unknown, right: unknown): unknown;
	}

	const GuildMath = {
		MAX_NUMBER: 1e308,
		BONUS_KEYS: ["Production", "Capacity", "Offline", "Automation", "Tap"],

		FiniteNonNegative(this: void, value: unknown): number {
			if (
				!typeIs(value, "number") ||
				value !== value ||
				value === math.huge ||
				value === -math.huge
			) {
				return 0;
			}
			return math.clamp(value, 0, GuildMath.MAX_NUMBER);
		},

		UpgradeTier(this: void, definition: UpgradeDefinition, level: number): unknown {
			const tiers = definition.Tiers;
			if (!typeIs(tiers, "table")) {
				return undefined;
			}
			if (level < 1 || level > tiers.size()) {
				return undefined;
			}
			return tiers[level - 1];
		},

		UpgradeCost(this: void, definition: UpgradeDefinition, level: number): number {
			const tier = GuildMath.UpgradeTier(definition, level + 1) as { Cost?: unknown } | undefined;
			if (tier && typeIs(tier.Cost, "number")) {
				return math.floor(tier.Cost + 0.5);
			}
			return math.floor(definition.BaseCost * definition.CostScale ** math.max(0, level) + 0.5);
		},

		UpgradeEffect(this: void, definition: UpgradeDefinition, level: number): number {
			const safeLevel = math.max(0, math.floor(level));
			if (safeLevel <= 0) {
				return 0;
			}
			const tiers = definition.Tiers;
			if (!typeIs(tiers, "table")) {
				return safeLevel * definition.EffectPerLevel;
			}
			let total = 0;
			const named = math.min(safeLevel, tiers.size());
			for (const index of $range(1, named)) {
				const tier = tiers[index - 1];
				total +=
					typeIs(tier, "table") && typeIs((tier as { Effect?: unknown }).Effect, "number")
						? ((tier as { Effect?: number }).Effect as number)
						: 0;
			}
			if (safeLevel > named) {
				total += (safeLevel - named) * definition.EffectPerLevel;
			}
			return total;
		},

		EmptyBonuses(this: void): Record<string, number> {
			const result: Record<string, number> = {};
			for (const key of GuildMath.BONUS_KEYS) {
				result[key] = 0;
			}
			return result;
		},

		BonusesFromUpgrades(
			this: void,
			upgrades: Record<string, unknown> | undefined,
			upgradeDefs: Record<string, UpgradeDefinition>,
		): Record<string, number> {
			const result = GuildMath.EmptyBonuses();
			if (!typeIs(upgrades, "table")) {
				return result;
			}
			for (const [id, level] of pairs(upgrades)) {
				const definition = upgradeDefs[id as string];
				if (definition && typeIs(level, "number")) {
					const key = definition.Bonus;
					if (key !== undefined && result[key] !== undefined) {
						result[key] = math.min(1, result[key] + GuildMath.UpgradeEffect(definition, level));
					}
				}
			}
			return result;
		},

		GoalTarget(this: void, baseTarget: number, targetPerMember: number, members: number): number {
			return math.max(
				1,
				math.floor(baseTarget + targetPerMember * math.max(0, members - 1) + 0.5),
			);
		},

		NormalizeContributionAmount(this: void, amount: unknown): LuaTuple<[number | undefined, string | undefined]> {
			if (
				!typeIs(amount, "number") ||
				amount !== amount ||
				amount === math.huge ||
				amount === -math.huge ||
				amount < 1 ||
				amount > GuildMath.MAX_NUMBER
			) {
				return $tuple(undefined, "Pick a positive contribution amount.");
			}
			return $tuple(math.floor(amount), undefined);
		},

		CanAffordBank(this: void, omegaMath: OmegaMathLike, currency: string, bank: unknown, cost: number): boolean {
			if (currency === "Cash") {
				return !omegaMath.Lt(bank ?? 0, cost);
			}
			return (tonumber(bank) ?? 0) >= cost;
		},

		CreditBank(this: void, omegaMath: OmegaMathLike, currency: string, bank: unknown, amount: number): unknown {
			if (currency === "Cash") {
				return omegaMath.Add(bank ?? 0, amount);
			}
			return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(bank) + amount);
		},

		DebitBank(
			this: void,
			omegaMath: OmegaMathLike,
			currency: string,
			bank: unknown,
			cost: number,
		): unknown {
			if (!GuildMath.CanAffordBank(omegaMath, currency, bank, cost)) {
				return undefined;
			}
			if (currency === "Cash") {
				return omegaMath.Sub(bank ?? 0, cost);
			}
			return (tonumber(bank) ?? 0) - cost;
		},

		AddClamped(this: void, current: unknown, amount: number): number {
			return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(current) + amount);
		},

		EmptyHall(this: void, membership: unknown): unknown {
			const bag = membership as Record<string, unknown> | undefined;
			const tag =
				typeIs(membership, "table") && typeIs(bag!.Tag, "string") ? (bag!.Tag as string) : "";
			const guildId = typeIs(membership, "table") && bag!.Id !== undefined ? bag!.Id : "";
			return {
				Id: guildId,
				Name: "Guild Hall",
				Tag: tag,
				Level: 1,
				XP: 0,
				Activity: 0,
				BankCash: 0,
				BankDust: 0,
				Members: {},
				Upgrades: {},
				CreatedAt: 0,
				OwnerUserId: 0,
			};
		},

		SnapshotPublic(this: void, membership: unknown, publicGuild: unknown): unknown {
			const bag = membership as Record<string, unknown> | undefined;
			const guildId = typeIs(membership, "table") && bag!.Id !== undefined ? bag!.Id : "";
			if (guildId === "") {
				return undefined;
			}
			if (publicGuild !== undefined) {
				return publicGuild;
			}
			return GuildMath.EmptyHall(membership);
		},
	};

	return table.freeze(GuildMath);
};

__defs["AdminGrantMath"] = () => {
	const AdminGrantMath = {
		DEFAULT_MAX_GRANT: 1e308,

		Finite(this: void, value: unknown): boolean {
			return (
				typeIs(value, "number") &&
				value === value &&
				value !== math.huge &&
				value !== -math.huge
			);
		},

		BoundedAmount(this: void, raw: unknown, fallback?: number, maxGrant?: number): number | undefined {
			const ceiling = tonumber(maxGrant) ?? AdminGrantMath.DEFAULT_MAX_GRANT;
			let value: unknown = typeIs(raw, "string") ? tonumber(raw) : raw;
			if (value === undefined && fallback !== undefined) {
				value = fallback;
			}
			if (!AdminGrantMath.Finite(value) || (value as number) <= 0) {
				return undefined;
			}
			return math.clamp(value as number, 1, ceiling);
		},

		CleanText(this: void, raw: unknown, maximum: number): string {
			if (!typeIs(raw, "string")) {
				return "";
			}
			const cap = math.max(0, math.floor(tonumber(maximum) ?? 0));
			let value = string.gsub(raw, "[%c]", " ")[0];
			value = string.gsub(value, "^%s+", "")[0];
			value = string.gsub(value, "%s+$", "")[0];
			value = string.sub(value, 1, cap);
			// a byte cap can split a multi-byte character; drop the broken tail
			const [, brokenAt] = utf8.len(value);
			if (brokenAt !== undefined) {
				value = string.sub(value, 1, brokenAt - 1);
			}
			return value;
		},

		CommandDanger(this: void, definition?: Record<string, unknown>): string {
			if (!typeIs(definition, "table")) {
				return "quick";
			}
			if (typeIs(definition.Danger, "string") && definition.Danger !== "") {
				return definition.Danger;
			}
			const category = definition.Category !== undefined ? definition.Category : "Economy";
			if (category === "Troll" || category === "Resets" || category === "Moderation") {
				return "arm";
			}
			return "quick";
		},

		AUDIT_ONLY_REASONS: table.freeze({
			"Owner gameplay administration": true,
			"Balance correction": true,
			"Playtest grant": true,
			"Troll / joke": true,
			"Moderation action": true,
			"Player request": true,
			"Bug recovery": true,
			"Trade settle recovery": true,
		}),

		PlayerFacingReason(
			this: void,
			command: unknown,
			reason: unknown,
			auditOnly?: Record<string, boolean>,
		): string {
			const safeReason = typeIs(reason, "string") ? reason : "";
			const blocked = auditOnly ?? (AdminGrantMath.AUDIT_ONLY_REASONS as Record<string, boolean>);
			if (safeReason !== "" && blocked[safeReason] !== true) {
				return safeReason;
			}
			if (command === "ServerBan") {
				return "You are banned from this Astral Forge server.";
			}
			if (command === "GlobalBan") {
				return "You are banned from Astral Forge.";
			}
			return "You were kicked from this Astral Forge server by an administrator.";
		},

		NextRelicUid(this: void, inventory: unknown, nextId: unknown): LuaTuple<[string | undefined, number]> {
			const bag = (typeIs(inventory, "table") ? inventory : {}) as Record<string, unknown>;
			let cursor = math.max(1, math.floor(tonumber(nextId) ?? 1));
			for (const _ of $range(1, 64)) {
				const uid = string.format("IT%07d", cursor);
				cursor += 1;
				if (bag[uid] === undefined) {
					return $tuple(uid, cursor);
				}
			}
			return $tuple(undefined, cursor);
		},

		BuildRelicInstance(this: void, definitionId: unknown, acquiredAt: unknown): Record<string, unknown> | undefined {
			if (!typeIs(definitionId, "string") || definitionId === "") {
				return undefined;
			}
			return {
				DefinitionId: definitionId,
				Level: 1,
				AcquiredAt: math.max(0, math.floor(tonumber(acquiredAt) ?? 0)),
			};
		},
	};

	return table.freeze(AdminGrantMath);
};

__defs["AnomalyPulseScore"] = () => {
	const AnomalyPulseScore = {
		Elapsed(this: void, now: number, startedAt: number, period: number): number {
			return (now - startedAt) % period;
		},

		Fraction(this: void, now: number, startedAt: number, period: number): number {
			const safePeriod = math.max(0.1, period);
			return AnomalyPulseScore.Elapsed(now, startedAt, safePeriod) / safePeriod;
		},

		IsAccurate(
			this: void,
			now: number,
			startedAt: unknown,
			period: number,
			sweetZoneFraction: number,
		): boolean {
			if (!typeIs(startedAt, "number") || startedAt <= 0) {
				return false;
			}
			const elapsed = AnomalyPulseScore.Elapsed(now, startedAt, period);
			const sweetZone = period * sweetZoneFraction;
			return elapsed >= period - sweetZone;
		},

		NextCombo(this: void, currentCombo: number | undefined, accurate: boolean, comboMax: number): number {
			if (!accurate) {
				return 0;
			}
			return math.min(comboMax, (currentCombo ?? 0) + 1);
		},

		NextBestCombo(this: void, bestCombo: number | undefined, combo: number): number {
			return math.max(bestCombo ?? 0, combo);
		},

		ComboBonus(this: void, combo: number, bonusPerStack: number): number {
			return 1 + math.min(1, combo * bonusPerStack);
		},

		AccuracyBonus(this: void, accurate: boolean, accurateBonus: number): number {
			if (accurate) {
				return 1 + accurateBonus;
			}
			return 1;
		},

		ScoreMultiplier(
			this: void,
			combo: number,
			accurate: boolean,
			bonusPerStack: number,
			accurateBonus: number,
		): number {
			return (
				AnomalyPulseScore.ComboBonus(combo, bonusPerStack) *
				AnomalyPulseScore.AccuracyBonus(accurate, accurateBonus)
			);
		},
	};

	return table.freeze(AnomalyPulseScore);
};

__defs["ConvergenceOpsMath"] = () => {
	interface EventProfile {
		EventId: string;
		Contribution: number;
		Claimed: Record<string, unknown>;
	}

	interface GlobalPhase {
		Target: number;
		Name: string;
		ProductionMultiplier: number;
	}

	const ConvergenceOpsMath = {
		EnsureEventProfile(this: void, profile: unknown, eventId: string): EventProfile {
			const bag = profile as Record<string, unknown>;
			if (!typeIs(bag.LiveOps, "table")) {
				bag.LiveOps = {};
			}
			const liveOps = bag.LiveOps as Record<string, unknown>;
			let current = liveOps.Convergence as EventProfile | undefined;
			if (!typeIs(current, "table") || current!.EventId !== eventId) {
				current = { EventId: eventId, Contribution: 0, Claimed: {} };
				liveOps.Convergence = current;
			}
			current!.Claimed = typeIs(current!.Claimed, "table") ? current!.Claimed : {};
			current!.Contribution = math.max(0, tonumber(current!.Contribution) ?? 0);
			if (!typeIs(current!.EventId, "string")) {
				current!.EventId = eventId;
			}
			return current!;
		},

		ReadEventProfile(this: void, profile: unknown, eventId: string): EventProfile {
			const bag = profile as Record<string, unknown> | undefined;
			const liveOps =
				typeIs(profile, "table") && typeIs(bag!.LiveOps, "table")
					? (bag!.LiveOps as Record<string, unknown>)
					: undefined;
			const current = liveOps !== undefined ? (liveOps.Convergence as EventProfile | undefined) : undefined;
			if (!typeIs(current, "table") || current!.EventId !== eventId) {
				return { EventId: eventId, Contribution: 0, Claimed: {} };
			}
			return {
				EventId: eventId,
				Contribution: math.max(0, tonumber(current!.Contribution) ?? 0),
				Claimed: typeIs(current!.Claimed, "table") ? current!.Claimed : {},
			};
		},

		EnsureRewardBags(this: void, profile: unknown): void {
			const bag = profile as Record<string, unknown>;
			if (!typeIs(bag.Stats, "table")) {
				bag.Stats = {};
			}
			if (!typeIs(bag.Command, "table")) {
				bag.Command = { Signals: 0 };
			}
			if (!typeIs(bag.BoostInventory, "table")) {
				bag.BoostInventory = {};
			}
		},

		ProductionMultiplier(this: void, total: number, phases: GlobalPhase[]): number {
			let multiplier = 1;
			const safeTotal = math.max(0, tonumber(total) ?? 0);
			if (!typeIs(phases, "table")) {
				return multiplier;
			}
			for (const phase of phases) {
				const target = tonumber(phase.Target) ?? 0;
				const mult = tonumber(phase.ProductionMultiplier) ?? 1;
				if (safeTotal >= target) {
					multiplier = mult;
				} else {
					break;
				}
			}
			return multiplier;
		},

		PhaseState(this: void, total: number, phases: GlobalPhase[]): LuaTuple<[number, string, number]> {
			const safeTotal = math.max(0, tonumber(total) ?? 0);
			let phaseIndex = 0;
			let phaseName = "HEATING";
			let nextTarget = 0;
			if (typeIs(phases, "table") && phases[0] !== undefined) {
				nextTarget = tonumber(phases[0].Target) ?? 0;
			}
			if (!typeIs(phases, "table")) {
				return $tuple(phaseIndex, phaseName, nextTarget);
			}
			for (const [index, phase] of ipairs(phases)) {
				const target = tonumber(phase.Target) ?? 0;
				if (safeTotal >= target) {
					phaseIndex = index;
					phaseName = typeIs(phase.Name, "string") ? phase.Name : phaseName;
					const following = phases[index];
					nextTarget = following !== undefined ? tonumber(following.Target) ?? target : target;
				} else {
					nextTarget = target;
					break;
				}
			}
			return $tuple(phaseIndex, phaseName, nextTarget);
		},

		CanClaimTier(
			this: void,
			contribution: number,
			required: number,
			claimed: Record<string, unknown> | undefined,
			tierIndex: number,
		): boolean {
			const key = tostring(tierIndex);
			const already = typeIs(claimed, "table") && claimed![key] === true;
			return (
				!already &&
				math.max(0, tonumber(contribution) ?? 0) >= math.max(0, tonumber(required) ?? 0)
			);
		},

		// Stable shard (1..shards) for a server, so its writes always land on the same counter key.
		ShardFor(this: void, jobId: string, shards: number): number {
			const count = math.max(1, math.floor(shards));
			let hash = 5381;
			for (const index of $range(1, jobId.size())) {
				hash = (hash * 33 + string.byte(jobId, index)[0]) % 2147483647;
			}
			return (hash % count) + 1;
		},

		ShardKey(this: void, eventId: string, shard: number): string {
			return `${eventId}#${tostring(shard)}`;
		},

		// The global total: every shard plus any pre-shard total stored under the bare event id.
		SumShards(this: void, shards: Record<number, unknown>, legacy: unknown): number {
			let total = math.max(0, tonumber(legacy) ?? 0);
			for (const [, value] of pairs(shards)) {
				const amount = tonumber(value);
				if (amount !== undefined && amount === amount && amount > 0 && amount !== math.huge) {
					total += amount;
				}
			}
			return total;
		},
	};

	return table.freeze(ConvergenceOpsMath);
};

__defs["RemoteFirewallMath"] = () => {
	const RemoteFirewallMath = {
		MAX_SAFE_USER_ID: 9007199254740991,
		MIN_SAFE_USER_ID: -9007199254740991,

		COOLDOWN_KEY_FIELDS: table.freeze([
			"Id",
			"Key",
			"Index",
			"Code",
			"Channel",
			"Target",
			"Uid",
			"ChoiceId",
			"Slot",
			"Tier",
			"Level",
			"Role",
			"UserId",
			"MachineId",
		]),

		Integer(this: void, value: unknown): boolean {
			return typeIs(value, "number") && value === math.floor(value);
		},

		SafeNumber(this: void, value: unknown): boolean {
			return (
				typeIs(value, "number") &&
				value === value &&
				value !== math.huge &&
				value !== -math.huge &&
				math.abs(value) <= RemoteFirewallMath.MAX_SAFE_USER_ID
			);
		},

		CoerceUserId(this: void, raw: unknown, studio?: boolean): number | undefined {
			let value = raw;
			if (typeIs(value, "string")) {
				const [trimmed] = string.match(value, "^%s*(%-?%d+)%s*$");
				if (trimmed === undefined) {
					return undefined;
				}
				value = tonumber(trimmed);
			}
			if (
				!typeIs(value, "number") ||
				value !== value ||
				value === math.huge ||
				value === -math.huge
			) {
				return undefined;
			}
			const rounded = value >= 0 ? math.floor(value + 0.5) : math.ceil(value - 0.5);
			if (math.abs(value - rounded) > 1e-6) {
				return undefined;
			}
			if (rounded === 0) {
				return undefined;
			}
			if (
				rounded < RemoteFirewallMath.MIN_SAFE_USER_ID ||
				rounded > RemoteFirewallMath.MAX_SAFE_USER_ID
			) {
				return undefined;
			}
			if (studio !== true && rounded < 1) {
				return undefined;
			}
			return rounded;
		},

		ExtractUserId(this: void, payload: unknown): unknown {
			if (payload === undefined) {
				return undefined;
			}
			if (typeIs(payload, "number") || typeIs(payload, "string")) {
				return payload;
			}
			if (!typeIs(payload, "table")) {
				return undefined;
			}
			const bag = payload as Record<string, unknown>;
			let raw = bag.UserId;
			if (raw === undefined) {
				raw = bag.userId;
			}
			if (raw === undefined) {
				raw = bag.Id;
			}
			if (raw === undefined) {
				raw = bag.TargetUserId;
			}
			return raw;
		},

		CooldownKey(this: void, action: string, payload: unknown, fields?: string[]): string {
			if (!typeIs(payload, "table")) {
				return action;
			}
			const bag = payload as Record<string, unknown>;
			const keyFields = fields ?? (RemoteFirewallMath.COOLDOWN_KEY_FIELDS as string[]);
			const parts: string[] = [];
			for (const field of keyFields) {
				const value = bag[field];
				if (value !== undefined) {
					parts.push(`${field}=${tostring(value)}`);
				}
			}
			if (parts.size() === 0) {
				return action;
			}
			return `${action}:${parts.join("|")}`;
		},

		StringField(this: void, payload: Record<string, unknown>, key: string, minimum: number, maximum: number): boolean {
			const value = payload[key];
			return typeIs(value, "string") && value.size() >= minimum && value.size() <= maximum;
		},

		StringArrayField(
			this: void,
			payload: Record<string, unknown>,
			key: string,
			maxEntries: number,
			entryMinLen: number,
			entryMaxLen: number,
		): boolean {
			const value = payload[key];
			if (!typeIs(value, "table")) {
				return false;
			}
			const list = value as Array<unknown>;
			let count = 0;
			for (const [index, entry] of pairs(value)) {
				count += 1;
				if (count > maxEntries) {
					return false;
				}
				if (
					!typeIs(index, "number") ||
					index % 1 !== 0 ||
					index < 1 ||
					index > list.size()
				) {
					return false;
				}
				if (
					!typeIs(entry, "string") ||
					entry.size() < entryMinLen ||
					entry.size() > entryMaxLen
				) {
					return false;
				}
			}
			return count === list.size();
		},

		NumberField(
			this: void,
			payload: Record<string, unknown>,
			key: string,
			minimum: number,
			maximum: number,
			mustBeInteger?: boolean,
		): boolean {
			const value = payload[key];
			return (
				RemoteFirewallMath.SafeNumber(value) &&
				(mustBeInteger !== true || RemoteFirewallMath.Integer(value)) &&
				(value as number) >= minimum &&
				(value as number) <= maximum
			);
		},

		INSPECT_MAX_DEPTH: 3,
		INSPECT_MAX_ENTRIES: 32,
		TRADE_MAX_ENTRIES: 64,
		INSPECT_MAX_STRING: 600,
		INSPECT_MAX_KEY_LEN: 64,
		INSPECT_MAX_INDEX: 10000,

		ValidateTradeOffer(this: void, offer: unknown, maxItems: number): LuaTuple<[boolean, string | undefined]> {
			if (!typeIs(offer, "table")) {
				return $tuple(false, "invalid trade offer");
			}
			const bag = offer as Record<string, unknown>;
			for (const [key, value] of pairs(bag)) {
				if (
					key === "Cash" ||
					key === "Stardust" ||
					key === "Cores" ||
					key === "Signals" ||
					key === "Essence"
				) {
					if (
						!RemoteFirewallMath.NumberField(
							bag,
							key,
							0,
							RemoteFirewallMath.MAX_SAFE_USER_ID,
							true,
						)
					) {
						return $tuple(false, "invalid trade currency");
					}
				} else if (key === "Boosts" || key === "Keys") {
					if (!typeIs(value, "table")) {
						return $tuple(false, "invalid trade consumables");
					}
					const consumables = value as Record<string, unknown>;
					let count = 0;
					for (const [id] of pairs(consumables)) {
						count += 1;
						if (
							!typeIs(id, "string") ||
							!RemoteFirewallMath.NumberField(
								consumables,
								id,
								0,
								RemoteFirewallMath.MAX_SAFE_USER_ID,
								true,
							)
						) {
							return $tuple(false, "invalid trade consumable count");
						}
					}
					if (count > (key === "Boosts" ? 14 : 7)) {
						return $tuple(false, "too many trade consumable types");
					}
				} else if (key === "ItemIds") {
					if (!RemoteFirewallMath.StringArrayField(bag, "ItemIds", maxItems, 1, 48)) {
						return $tuple(false, "invalid trade items");
					}
				} else {
					return $tuple(false, "unexpected trade offer field");
				}
			}
			return $tuple(true, undefined);
		},

		Inspect(
			this: void,
			value: unknown,
			depth?: number,
			seen?: Set<unknown>,
			budget?: { Value: number },
			maxEntries?: number,
		): LuaTuple<[boolean, string | undefined]> {
			const nest = math.max(0, math.floor(tonumber(depth) ?? 0));
			const visited = seen ?? new Set<unknown>();
			const entries = budget ?? { Value: 0 };
			const valueType = typeOf(value);
			if (value === undefined || valueType === "boolean") {
				return $tuple(true, undefined);
			}
			if (valueType === "number") {
				return $tuple(RemoteFirewallMath.SafeNumber(value), "number is outside the safe range");
			}
			if (valueType === "string") {
				return $tuple(
					(value as string).size() <= RemoteFirewallMath.INSPECT_MAX_STRING,
					"string is too long",
				);
			}
			if (valueType !== "table") {
				return $tuple(false, "payload contains an unsupported value");
			}
			if (nest > RemoteFirewallMath.INSPECT_MAX_DEPTH) {
				return $tuple(false, "payload nesting is too deep");
			}
			if (visited.has(value)) {
				return $tuple(false, "payload contains a cycle");
			}
			visited.add(value);
			for (const [key, child] of pairs(value as object)) {
				entries.Value += 1;
				if (entries.Value > (maxEntries ?? RemoteFirewallMath.INSPECT_MAX_ENTRIES)) {
					visited.delete(value);
					return $tuple(false, "payload is too large");
				}
				const keyType = typeOf(key);
				if (keyType !== "string" && keyType !== "number") {
					visited.delete(value);
					return $tuple(false, "payload keys must be strings or numbers");
				}
				if (keyType === "string" && (key as string).size() > RemoteFirewallMath.INSPECT_MAX_KEY_LEN) {
					visited.delete(value);
					return $tuple(false, "payload key is too long");
				}
				if (
					keyType === "number" &&
					(!RemoteFirewallMath.SafeNumber(key) ||
						!RemoteFirewallMath.Integer(key) ||
						math.abs(key as number) > RemoteFirewallMath.INSPECT_MAX_INDEX)
				) {
					visited.delete(value);
					return $tuple(false, "payload index is outside the safe range");
				}
				const [ok, reason] = RemoteFirewallMath.Inspect(child, nest + 1, visited, entries, maxEntries);
				if (!ok) {
					visited.delete(value);
					return $tuple(false, reason);
				}
			}
			visited.delete(value);
			return $tuple(true, undefined);
		},

		SESSION_KEYS: table.freeze({
			Gen: true,
			N: true,
			Auth: true,
			Txn: true,
			TxnId: true,
		}),

		IsSessionOnlyPayload(this: void, payload: unknown, sessionKeys?: Record<string, boolean>): boolean {
			if (!typeIs(payload, "table")) {
				return false;
			}
			const allowed = sessionKeys ?? (RemoteFirewallMath.SESSION_KEYS as Record<string, boolean>);
			for (const [key] of pairs(payload)) {
				if (allowed[key as string] !== true) {
					return false;
				}
			}
			return true;
		},
	};

	return table.freeze(RemoteFirewallMath);
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type OpsMathCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const OpsMath = setmetatable({}, {
	__call: (_self: unknown, name: string): unknown => __load(name),
	__index: (_self: unknown, name: string): unknown => name === "__members" ? __members : __load(name),
} as LuaMetatable<object>) as unknown as OpsMathCallable;

export = OpsMath;
