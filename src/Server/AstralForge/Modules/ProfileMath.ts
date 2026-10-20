import { Dict, truthy } from "../Services/LuaInterop";

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) return hit.value;
	const def = __defs[name];
	if (def === undefined) error(`ProfileMath: unknown module ${tostring(name)}`, 2);
	if (__loading[name]) error(`ProfileMath: cyclic require of member ${name}`, 2);
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) error(value, 0);
	__cache[name] = { value };
	return value;
}

type CopyDictionary = (value: unknown) => unknown;

interface EconomyApi {
	Max(this: void, a: unknown, b: unknown): unknown;
	Production(this: void, profile: unknown): unknown;
	Capacity(this: void, profile: unknown, now: number): unknown;
	ItemEffect(this: void, profile: unknown, kind: string): unknown;
	GetArtifact?(this: void, artifactId: string): Dict | undefined;
}

interface ProgressionGateApi {
	Progress(this: void, profile: unknown, kind: unknown): number;
	Meets(this: void, profile: unknown, requirement: unknown): boolean;
}

__defs["ProfileClampMath"] = () => {
	const DEFAULT_MAX = 1e308;

	function finite(value: unknown): boolean {
		return typeIs(value, "number") && value === value && value !== math.huge && value !== -math.huge;
	}

	function clampScalar(raw: unknown, ceiling: number): number {
		const value = tonumber(raw);
		if (value !== undefined && finite(value)) {
			return math.clamp(value, 0, ceiling);
		}
		return 0;
	}

	function isNegativePersist(persisted: unknown): boolean {
		if (typeIs(persisted, "number")) {
			return persisted < 0;
		}
		if (typeIs(persisted, "string")) {
			return string.sub(persisted, 1, 1) === "-";
		}
		return false;
	}

	const ProfileClampMath = {
		ClampProgressionNumbers(
			this: void,
			profile: unknown,
			persist?: (value: unknown) => unknown,
			maxSafe?: number,
		): boolean {
			if (!typeIs(profile, "table")) {
				return false;
			}
			const bag = profile as Dict;
			const ceiling = tonumber(maxSafe) ?? DEFAULT_MAX;
			let persistFn = persist;
			if (!typeIs(persistFn, "function")) {
				persistFn = (value: unknown) => clampScalar(value, ceiling);
			}

			for (const key of ["Cash", "Vault", "RunCash", "LifetimeCash"]) {
				let persisted = persistFn(bag[key]);
				if (isNegativePersist(persisted)) {
					persisted = 0;
				}
				bag[key] = persisted;
			}
			for (const key of ["Cores", "Stardust", "Rebirths"]) {
				bag[key] = clampScalar(bag[key], ceiling);
			}
			if (typeIs(bag.Stats, "table")) {
				const stats = bag.Stats as Dict;
				if (stats.Collected !== undefined) {
					let persisted = persistFn(stats.Collected);
					if (isNegativePersist(persisted)) {
						persisted = 0;
					}
					stats.Collected = persisted;
				}
				for (const [key, raw] of pairs(stats)) {
					if (key !== "Collected" && typeIs(raw, "number")) {
						stats[key as string] = finite(raw) ? math.clamp(raw, 0, ceiling) : 0;
					}
				}
			}
			if (typeIs(bag.Continuum, "table")) {
				const continuum = bag.Continuum as Dict;
				let persisted = persistFn(continuum.TotalFluxSpent);
				if (isNegativePersist(persisted)) {
					persisted = 0;
				}
				continuum.TotalFluxSpent = persisted;
				for (const key of ["TotalStardustSpent"]) {
					continuum[key] = clampScalar(continuum[key], ceiling);
				}
			}
			return true;
		},
	};

	return table.freeze(ProfileClampMath);
};

__defs["SettingsSeal"] = () => {
	const SettingsSeal = {
		Apply(this: void, profile: Dict) {
			const settings = profile.Settings as Dict;
			settings.SoundEffects = (tonumber(settings.SoundVolume) ?? 0) > 0.001;
			settings.UIEffects = (tonumber(settings.EffectsIntensity) ?? 0) > 0.001;
			settings.ReducedMotion = (tonumber(settings.MotionIntensity) ?? 1) <= 0.03;
		},
	};

	return SettingsSeal;
};

__defs["UnlimitedMoneySeal"] = () => {
	const UnlimitedMoneySeal = {
		Apply(this: void, profile: Dict, maxSafeCurrency: unknown, Economy: EconomyApi) {
			const flags = profile.Flags as Dict;
			if (truthy(flags.UnlimitedMoney)) {
				profile.Cash = maxSafeCurrency;
				profile.RunCash = maxSafeCurrency;
				profile.LifetimeCash = Economy.Max(profile.LifetimeCash, maxSafeCurrency);
			}
		},
	};

	return UnlimitedMoneySeal;
};

__defs["PublicPlayerRecord"] = () => {
	const GeneralBoardValue = __load("GeneralBoardValue") as {
		Of(this: void, profile: Dict, id: string, persist: (value: unknown) => unknown): unknown;
	};

	const PublicPlayerRecord = {
		Build(this: void, player: Player, profile: Dict, viewer: Player, presence: unknown, deps: { Economy: EconomyApi }) {
			const Economy = deps.Economy;
			const liveEntry = (truthy(presence) ? (presence as Dict)[player.UserId] : undefined) as Dict | undefined;
			let artifact: Dict | undefined = undefined;
			const command = profile.Command as Dict | undefined;
			const artifactId =
				truthy(command) && typeIs(command.EquippedArtifact, "string") ? command.EquippedArtifact : "";
			const definition =
				artifactId !== "" && Economy.GetArtifact !== undefined ? Economy.GetArtifact(artifactId) : undefined;
			const ownedArtifact =
				truthy(definition) && typeIs(command!.Artifacts, "table")
					? (command!.Artifacts as Dict)[artifactId]
					: undefined;
			if (truthy(definition) && typeIs(ownedArtifact, "table")) {
				const owned = ownedArtifact as Dict;
				artifact = {
					Id: artifactId,
					Name: tostring(definition.Name),
					Element: tostring(truthy(definition.Element) ? definition.Element : ""),
					Rarity: tostring(truthy(definition.Rarity) ? definition.Rarity : "COMMON"),
					Level: math.max(1, math.floor(tonumber(owned.Level) ?? 1)),
				};
			}
			return {
				UserId: math.floor(player.UserId),
				Name: player.Name,
				DisplayName: player.DisplayName,
				Zone: profile.Zone,
				CurrentZone: profile.CurrentZone,
				Rebirths: profile.Rebirths,
				Production: Economy.Production(profile),
				LifetimeCash: profile.LifetimeCash,
				Stardust: profile.Stardust,
				Cores: profile.Cores,
				DomainRank:
					truthy(profile.Domain) && truthy((profile.Domain as Dict).Rank)
						? (profile.Domain as Dict).Rank
						: 0,
				PlayTime:
					truthy(profile.Stats) && truthy((profile.Stats as Dict).PlayTime)
						? (profile.Stats as Dict).PlayTime
						: 0,
				Boards: {
					Crates: GeneralBoardValue.Of(profile, "Crates", tostring),
					Finds: GeneralBoardValue.Of(profile, "Finds", tostring),
					Ore: GeneralBoardValue.Of(profile, "Ore", tostring),
					Wardens: GeneralBoardValue.Of(profile, "Wardens", tostring),
					Orders: GeneralBoardValue.Of(profile, "Orders", tostring),
					Stars: GeneralBoardValue.Of(profile, "Stars", tostring),
					Cipher: GeneralBoardValue.Of(profile, "Cipher", tostring),
				},
				Shards:
					truthy(profile.Foundry) && truthy((profile.Foundry as Dict).Shards)
						? (profile.Foundry as Dict).Shards
						: 0,
				FoundryPieces:
					truthy(profile.Foundry) && typeIs((profile.Foundry as Dict).Inventory, "table")
						? ((profile.Foundry as Dict).Inventory as defined[]).size()
						: 0,
				Artifact: artifact,
				IsLocal: player === viewer,
				SocialFlags: 0,
				CurrentPage: truthy(liveEntry) ? liveEntry.Page : "Overview",
				PresenceAge: truthy(liveEntry) ? math.max(0, os.time() - (liveEntry.UpdatedAt as number)) : -1,
				AccountAge: player.AccountAge,
				Premium: Enum !== undefined && player.MembershipType === Enum.MembershipType.Premium,
			};
		},
	};

	return PublicPlayerRecord;
};

__defs["ReportLedger"] = () => {
	interface SentEntry {
		target: number;
		at: number;
	}
	interface AgainstEntry {
		reporter: number;
		reason: string;
		at: number;
	}
	interface ReportLedger {
		_sent: Record<number, SentEntry[]>;
		_against: Record<number, AgainstEntry[]>;
		canReport(reporter: number, target: number, now: number): LuaTuple<[boolean, string?]>;
		record(reporter: number, target: number, reason: string, now: number): LuaTuple<[number, number]>;
		tally(target: number, now: number): LuaTuple<[number, number]>;
		forgetReporter(reporter: number): void;
	}
	interface ReportLedgerClass {
		__index: unknown;
		REASONS: readonly string[];
		SEVERITY_COLORS: Record<string, number>;
		REPEAT_SECONDS: number;
		WINDOW_SECONDS: number;
		MAX_PER_WINDOW: number;
		isReason(this: void, reason: unknown): boolean;
		"new"(this: void): ReportLedger;
	}

	const ReportLedger: ReportLedgerClass = {
		__index: undefined,
		REASONS: table.freeze([
			"Exploiting",
			"Scamming",
			"Harassment",
			"Trolling",
			"Spam",
			"Inappropriate",
			"Impersonating",
			"Botting",
			"Other",
		]),
		SEVERITY_COLORS: table.freeze({ Minor: 16762880, Serious: 15548997, Urgent: 10038562 }),
		REPEAT_SECONDS: 600,
		WINDOW_SECONDS: 3600,
		MAX_PER_WINDOW: 6,
		isReason(reason: unknown): boolean {
			return typeIs(reason, "string") && REASON_SET[reason] === true;
		},
		new(): ReportLedger {
			return setmetatable(
				{
					_sent: {},
					_against: {},
				} as ReportLedger,
				ReportLedger as unknown as LuaMetatable<ReportLedger>,
			) as ReportLedger;
		},
	};
	ReportLedger.__index = ReportLedger;

	const REASON_SET: Record<string, boolean> = {};
	for (const reason of ReportLedger.REASONS) {
		REASON_SET[reason] = true;
	}

	function prune(list: { at: number }[], now: number, window: number) {
		let write = 0;
		for (const entry of list) {
			if (now - entry.at < window) {
				write += 1;
				list[write - 1] = entry;
			}
		}
		for (let index = list.size(); index >= write + 1; index--) {
			list[index - 1] = undefined!;
		}
	}

	const methods = {
		canReport(
			this: ReportLedger,
			reporter: number,
			target: number,
			now: number,
		): LuaTuple<[boolean, string?]> {
			const sent = this._sent[reporter];
			if (sent === undefined) {
				return $tuple(true, undefined);
			}
			prune(sent, now, ReportLedger.WINDOW_SECONDS);
			for (const entry of sent) {
				if (entry.target === target && now - entry.at < ReportLedger.REPEAT_SECONDS) {
					const minutes = math.max(1, math.ceil((ReportLedger.REPEAT_SECONDS - (now - entry.at)) / 60));
					return $tuple(
						false,
						string.format("You already reported this player. You can report them again in %d min.", minutes),
					);
				}
			}
			if (sent.size() >= ReportLedger.MAX_PER_WINDOW) {
				return $tuple(false, "You've sent a lot of reports this hour. Try again later.");
			}
			return $tuple(true, undefined);
		},

		record(this: ReportLedger, reporter: number, target: number, reason: string, now: number): LuaTuple<[number, number]> {
			let sent = this._sent[reporter];
			if (sent === undefined) {
				sent = [];
				this._sent[reporter] = sent;
			}
			sent.push({ target, at: now });
			let against = this._against[target];
			if (against === undefined) {
				against = [];
				this._against[target] = against;
			}
			against.push({ reporter, reason, at: now });
			return this.tally(target, now);
		},

		tally(this: ReportLedger, target: number, now: number): LuaTuple<[number, number]> {
			const against = this._against[target];
			if (against === undefined) {
				return $tuple(0, 0);
			}
			prune(against, now, ReportLedger.WINDOW_SECONDS);
			const reporters: Record<number, boolean> = {};
			let distinct = 0;
			for (const entry of against) {
				if (reporters[entry.reporter] !== true) {
					reporters[entry.reporter] = true;
					distinct += 1;
				}
			}
			return $tuple(against.size(), distinct);
		},

		forgetReporter(this: ReportLedger, reporter: number) {
			delete this._sent[reporter];
		},
	};

	for (const [name, fn] of pairs(methods)) {
		(ReportLedger.__index as Dict)[name as string] = fn;
	}

	return ReportLedger;
};

__defs["AutoSalvageSnapshot"] = () => {
	interface AutoSalvageBag {
		Enabled?: boolean;
		KeepNew?: boolean;
		Rarities?: unknown;
		[index: string]: unknown;
	}

	const AutoSalvageSnapshot = {
		Normalize(this: void, raw: unknown): AutoSalvageBag {
			if (typeIs(raw, "table")) {
				return raw as AutoSalvageBag;
			}
			return { Enabled: false, KeepNew: true, Rarities: {} };
		},

		Public(this: void, raw: unknown, copyDictionary: CopyDictionary) {
			const autoSalvage = AutoSalvageSnapshot.Normalize(raw);
			return {
				Enabled: autoSalvage.Enabled === true,
				KeepNew: autoSalvage.KeepNew !== false,
				Rarities: copyDictionary(typeIs(autoSalvage.Rarities, "table") ? autoSalvage.Rarities : {}),
			};
		},

		DefaultAutoForge(this: void) {
			return { Enabled: false, MachineId: "StellarCore", Reserve: 0.25, Bought: 0 };
		},

		PublicAutoForge(this: void, raw: unknown, copyDictionary: CopyDictionary) {
			return copyDictionary(typeIs(raw, "table") ? raw : AutoSalvageSnapshot.DefaultAutoForge());
		},
	};

	return AutoSalvageSnapshot;
};

__defs["ItemLoadoutMath"] = () => {
	function rarityRank(rarities: unknown, rarity: unknown): number {
		if (!typeIs(rarities, "table")) {
			return 0;
		}
		const entry = (rarities as Dict)[rarity as string];
		if (typeIs(entry, "table")) {
			return tonumber((entry as Dict).Rank) ?? 0;
		}
		return tonumber(entry) ?? 0;
	}

	const ItemLoadoutMath = {
		IsCompatible(this: void, definition: unknown, target: unknown): boolean {
			if (!typeIs(definition, "table") || !typeIs(target, "table")) {
				return false;
			}
			const def = definition as Dict;
			const tgt = target as Dict;
			if (def.Slot !== tgt.Slot) {
				return false;
			}
			const targets = def.Targets;
			if (!typeIs(targets, "table")) {
				return true;
			}
			for (const [, allowed] of pairs(targets as object)) {
				if (allowed === tgt.TargetId) {
					return true;
				}
			}
			return false;
		},

		CandidatePower(this: void, definition: unknown, level: unknown): number {
			if (!typeIs(definition, "table")) {
				return 0;
			}
			const def = definition as Dict;
			const base = tonumber(def.BaseEffect) ?? 0;
			const growth = tonumber(def.LevelGrowth) ?? 0;
			const safeLevel = math.max(1, math.floor(tonumber(level) ?? 1));
			return base * (1 + growth * math.max(0, safeLevel - 1));
		},

		BuildTargets(
			this: void,
			machinesCatalog: unknown,
			researchCatalog: unknown,
			machineLevels: unknown,
			researchLevels: unknown,
		): Dict[] {
			const targets: Dict[] = [];
			const machines = (typeIs(machineLevels, "table") ? machineLevels : {}) as Dict;
			const research = (typeIs(researchLevels, "table") ? researchLevels : {}) as Dict;
			if (typeIs(machinesCatalog, "table")) {
				for (const [, machine] of pairs(machinesCatalog as object)) {
					const machineBag = machine as Dict;
					if (typeIs(machine, "table") && typeIs(machineBag.Id, "string")) {
						if ((tonumber(machines[machineBag.Id]) ?? 0) >= 1) {
							targets.push({
								Id: `Machine:${machineBag.Id}`,
								Slot: "Machine",
								TargetId: machineBag.Id,
							});
						}
					}
				}
			}
			if (typeIs(researchCatalog, "table")) {
				for (const [, entry] of pairs(researchCatalog as object)) {
					const entryBag = entry as Dict;
					if (typeIs(entry, "table") && typeIs(entryBag.Id, "string")) {
						if ((tonumber(research[entryBag.Id]) ?? 0) >= 1) {
							targets.push({
								Id: `Research:${entryBag.Id}`,
								Slot: "Research",
								TargetId: entryBag.Id,
							});
						}
					}
				}
			}
			return targets;
		},

		PlanEquipBest(
			this: void,
			targets: unknown,
			candidates: unknown,
			rarities: unknown,
			currentEquipped: unknown,
		): LuaTuple<[Record<string, string>, number, number]> {
			const socketList = (typeIs(targets, "table") ? table.clone(targets as defined[]) : []) as Dict[];
			const relicList = (typeIs(candidates, "table") ? table.clone(candidates as defined[]) : []) as Dict[];
			table.sort(relicList, (a, b) => {
				const aPower = tonumber(truthy(a) ? a.Power : undefined) ?? 0;
				const bPower = tonumber(truthy(b) ? b.Power : undefined) ?? 0;
				if (aPower !== bPower) {
					return aPower > bPower;
				}
				const aRank = rarityRank(
					rarities,
					truthy(a) && truthy(a.Definition) ? (a.Definition as Dict).Rarity : undefined,
				);
				const bRank = rarityRank(
					rarities,
					truthy(b) && truthy(b.Definition) ? (b.Definition as Dict).Rarity : undefined,
				);
				if (aRank !== bRank) {
					return aRank > bRank;
				}
				const aLevel = tonumber(truthy(a) && truthy(a.Instance) ? (a.Instance as Dict).Level : undefined) ?? 0;
				const bLevel = tonumber(truthy(b) && truthy(b.Instance) ? (b.Instance as Dict).Level : undefined) ?? 0;
				if (aLevel !== bLevel) {
					return aLevel > bLevel;
				}
				return tostring(truthy(a) ? a.Uid : undefined) < tostring(truthy(b) ? b.Uid : undefined);
			});

			function compatibleCount(target: Dict): number {
				let count = 0;
				for (const candidate of relicList) {
					if (ItemLoadoutMath.IsCompatible(candidate.Definition, target)) {
						count += 1;
					}
				}
				return count;
			}
			table.sort(socketList, (a, b) => {
				const aCount = compatibleCount(a);
				const bCount = compatibleCount(b);
				if (aCount !== bCount) {
					return aCount < bCount;
				}
				return tostring(a.Id) < tostring(b.Id);
			});

			const nextEquipped: Record<string, string> = {};
			const used: Record<string, boolean> = {};
			let equippedCount = 0;
			for (const target of socketList) {
				for (const candidate of relicList) {
					const candUid = candidate.Uid as string;
					if (used[candUid] !== true && ItemLoadoutMath.IsCompatible(candidate.Definition, target)) {
						nextEquipped[target.Id as string] = candUid;
						used[candUid] = true;
						equippedCount += 1;
						break;
					}
				}
			}

			const current = (typeIs(currentEquipped, "table") ? currentEquipped : {}) as Dict;
			let changed = 0;
			for (const [target, uid] of pairs(nextEquipped)) {
				if (current[target as string] !== uid) {
					changed += 1;
				}
			}
			for (const [target] of pairs(current)) {
				if (nextEquipped[target as string] === undefined) {
					changed += 1;
				}
			}
			return $tuple(nextEquipped, equippedCount, changed);
		},

		EffectsPublic(this: void, profile: Dict, Economy: EconomyApi) {
			return {
				Production: Economy.ItemEffect(profile, "Production"),
				Capacity: Economy.ItemEffect(profile, "Capacity"),
				Tap: Economy.ItemEffect(profile, "Tap"),
				Critical: Economy.ItemEffect(profile, "Critical"),
				Automation: Economy.ItemEffect(profile, "Automation"),
				Offline: Economy.ItemEffect(profile, "Offline"),
			};
		},
	};

	return table.freeze(ItemLoadoutMath);
};

__defs["ItemSalvage"] = () => {
	const ItemSalvage = {
		Value(this: void, level: unknown, rarityRank: unknown): number {
			const rank = typeIs(rarityRank, "number") ? rarityRank : 1;
			const safeLevel = typeIs(level, "number") ? level : 1;
			return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3;
		},
	};

	return table.freeze(ItemSalvage);
};

__defs["GeneralBoardValue"] = () => {
	const STAT_BOARDS: Record<string, string> = {
		Crates: "CratesOpened",
		Finds: "ItemsFound",
		Ore: "OreMined",
		Wardens: "WardenDefeats",
		Orders: "OrdersCompleted",
	};

	const GeneralBoardValue = {
		Of(this: void, profile: Dict, id: string, persist: (value: unknown) => unknown): unknown {
			if (id === "Flux") {
				return persist(profile.LifetimeCash);
			}
			if (id === "Rebirths") {
				return math.max(0, math.floor(tonumber(profile.Rebirths) ?? 0));
			}
			if (id === "PlayTime") {
				return math.max(
					0,
					math.floor(
						tonumber(truthy(profile.Stats) ? (profile.Stats as Dict).PlayTime : undefined) ?? 0,
					),
				);
			}
			if (id === "Dust") {
				return math.max(0, math.floor(tonumber(profile.Stardust) ?? 0));
			}
			if (id === "Cores") {
				return math.max(0, math.floor(tonumber(profile.Cores) ?? 0));
			}
			if (id === "Domain") {
				return math.max(
					0,
					math.floor(tonumber(truthy(profile.Domain) ? (profile.Domain as Dict).Rank : undefined) ?? 0),
				);
			}
			if (id === "Worlds") {
				return math.max(1, math.floor(tonumber(profile.Zone) ?? 1));
			}
			const statKey = STAT_BOARDS[id];
			if (statKey !== undefined) {
				return math.max(
					0,
					math.floor(
						tonumber(typeIs(profile.Stats, "table") ? (profile.Stats as Dict)[statKey] : undefined) ?? 0,
					),
				);
			}
			const sky = (typeIs(profile.Sky, "table") ? profile.Sky : undefined) as Dict | undefined;
			if (id === "Stars") {
				let total = 0;
				const plotted =
					truthy(sky) && typeIs(sky.Charts, "table") ? (sky.Charts as Dict).Plotted : undefined;
				if (typeIs(plotted, "table")) {
					for (const [, count] of pairs(plotted as object)) {
						total += math.max(0, math.floor(tonumber(count) ?? 0));
					}
				}
				return total;
			}
			if (id === "Cipher") {
				return math.max(
					0,
					math.floor(
						tonumber(
							truthy(sky) && typeIs(sky.Cipher, "table") ? (sky.Cipher as Dict).Solves : undefined,
						) ?? 0,
					),
				);
			}
			return 0;
		},
	};

	return table.freeze(GeneralBoardValue);
};

__defs["UtcClockMath"] = () => {
	const DAY_SECONDS = 86_400;
	const WEEK_SECONDS = DAY_SECONDS * 7;

	const UtcClockMath = {
		DAY_SECONDS,
		WEEK_SECONDS,

		Day(this: void, now: unknown): number {
			const seconds = tonumber(now) ?? 0;
			return math.floor(seconds / UtcClockMath.DAY_SECONDS);
		},

		Week(this: void, now: unknown): number {
			const seconds = tonumber(now) ?? 0;
			return math.floor(seconds / UtcClockMath.WEEK_SECONDS);
		},

		NextMidnight(this: void, now: unknown): number {
			return (UtcClockMath.Day(now) + 1) * UtcClockMath.DAY_SECONDS;
		},

		Remaining(this: void, deadline: unknown, now: unknown): number {
			return math.max(0, (tonumber(deadline) ?? 0) - (tonumber(now) ?? 0));
		},

		IsLive(this: void, deadline: unknown, now: unknown): boolean {
			return UtcClockMath.Remaining(deadline, now) <= 0;
		},
	};

	return table.freeze(UtcClockMath);
};

__defs["StoryMailSnapshot"] = () => {
	const StoryMailSnapshot = {
		BuildStory(this: void, profile: Dict, storyChapters: unknown, ProgressionGate: ProgressionGateApi): Dict {
			const story = profile.Story as Dict;
			const storyState: Dict = {};
			for (const [index, chapter] of pairs(storyChapters as object)) {
				const ch = chapter as Dict;
				storyState[index as string] = {
					Id: ch.Id,
					Unlocked: ProgressionGate.Progress(profile, ch.Kind) >= (ch.Target as number),
					Progress: ProgressionGate.Progress(profile, ch.Kind),
					Target: ch.Target,
					Read: (story.Read as Dict)[ch.Id as string] === true,
					Claimed: (story.Claimed as Dict)[ch.Id as string] === true,
				};
			}
			return storyState;
		},

		BuildMailbox(
			this: void,
			profile: Dict,
			mailMessages: unknown,
			ProgressionGate: ProgressionGateApi,
		): LuaTuple<[Dict[], number]> {
			const mailbox = profile.Mailbox as Dict;
			const mailState: Dict[] = [];
			let unreadMail = 0;
			for (const [, message] of pairs(mailMessages as object)) {
				const msg = message as Dict;
				if (!truthy((mailbox.Deleted as Dict)[msg.Id as string]) && ProgressionGate.Meets(profile, msg.Requirement)) {
					const read = (mailbox.Read as Dict)[msg.Id as string] === true;
					if (!read) {
						unreadMail += 1;
					}
					mailState.push({
						Id: msg.Id,
						Read: read,
						Claimed: (mailbox.Claimed as Dict)[msg.Id as string] === true,
					});
				}
			}
			return $tuple(mailState, unreadMail);
		},

		MailboxPublic(this: void, messages: unknown, unread: number) {
			return {
				Messages: messages,
				Unread: unread,
			};
		},
	};

	return StoryMailSnapshot;
};

__defs["VisitSnapshot"] = () => {
	const VisitSnapshot = {
		Build(this: void, player: Player, profile: Dict, Economy: EconomyApi) {
			const production = Economy.Production(profile);
			const machines: Record<string, number> = {};
			let machineCount = 0;
			for (const [id, level] of pairs(profile.Machines as object)) {
				const amount = math.floor(tonumber(level) ?? 0);
				if (amount > 0) {
					machines[id as string] = amount;
					machineCount += 1;
				}
			}
			return {
				UserId: player.UserId,
				Name: player.Name,
				DisplayName: player.DisplayName,
				Zone: profile.Zone,
				CurrentZone: profile.CurrentZone,
				Rebirths: profile.Rebirths,
				Production: production,
				Cash: profile.Cash,
				Vault: profile.Vault,
				Capacity: Economy.Capacity(profile, os.time()),
				Cores: profile.Cores,
				Stardust: profile.Stardust,
				LifetimeCash: profile.LifetimeCash,
				Machines: machines,
				MachineKinds: machineCount,
				ServerTime: os.time(),
			};
		},

		Resolve(
			this: void,
			hostUserId: number | undefined,
			players: Player[],
			getProfile: (player: Player) => unknown,
			Economy: EconomyApi,
		): unknown {
			if (hostUserId === undefined) {
				return undefined;
			}
			for (const host of players) {
				if (host.UserId === hostUserId) {
					const hostProfile = getProfile(host);
					if (truthy(hostProfile)) {
						return VisitSnapshot.Build(host, hostProfile as Dict, Economy);
					}
				}
			}
			return undefined;
		},
	};

	return VisitSnapshot;
};

__defs["VisitorList"] = () => {
	const VisitorList = {
		Build(this: void, bucket: unknown, isPresent: (visitor: unknown) => boolean): Dict[] {
			const list: Dict[] = [];
			if (!truthy(bucket)) {
				return list;
			}
			for (const [visitor] of pairs(bucket as object)) {
				const bag = visitor as Dict;
				if (isPresent(visitor)) {
					list.push({
						UserId: bag.UserId,
						Name: bag.Name,
						DisplayName: bag.DisplayName,
					});
				}
			}
			table.sort(list, (left, right) => (left.DisplayName as string) < (right.DisplayName as string));
			return list;
		},
	};

	return VisitorList;
};

__defs["RankBracket"] = () => {
	const DEFAULT_BRACKETS = [1, 3, 10, 25];
	const UNRANKED = math.huge;

	const RankBracket = {
		DEFAULT_BRACKETS,
		UNRANKED,

		Of(this: void, rank: number, brackets?: number[], unranked?: number): number {
			const list = brackets ?? RankBracket.DEFAULT_BRACKETS;
			const fallback = unranked !== undefined ? unranked : RankBracket.UNRANKED;
			for (const bracket of list) {
				if (rank <= bracket) {
					return bracket;
				}
			}
			return fallback;
		},

		ShouldAnnounce(this: void, previousRank: number, nextRank: number, brackets?: number[], unranked?: number): boolean {
			const fallback = unranked !== undefined ? unranked : RankBracket.UNRANKED;
			const seeded = previousRank > 0;
			if (!seeded || nextRank >= previousRank) {
				return false;
			}
			const bracket = RankBracket.Of(nextRank, brackets, fallback);
			const previousBracket = RankBracket.Of(previousRank, brackets, fallback);
			return bracket !== fallback && bracket < previousBracket;
		},
	};

	return table.freeze(RankBracket);
};

__defs["Format"] = () => {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const OmegaMath = require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
	) as { Log10(this: void, value: unknown): number };

	const SUFFIXES = [
		"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
		"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
		"Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg",
		"Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion",
		"Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign",
		"Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex",
		"Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx",
		"Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx",
		"Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega",
		"Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless",
		"Apex", "Horizon",
	];

	const LAST_NAMED_LOG10 = SUFFIXES.size() * 3;

	function formatFromLog10(log10: number): string {
		if (log10 !== log10 || log10 <= 0) {
			return "0";
		}
		if (log10 < 3 && 10 ** log10 < 999.5) {
			return string.format("%.0f", 10 ** log10);
		}
		if (log10 >= LAST_NAMED_LOG10) {
			const exponent = math.floor(log10);
			const mantissa = 10 ** (log10 - exponent);
			return string.format("%.2fe%d", mantissa, exponent);
		}
		let group = math.clamp(math.floor(log10 / 3), 1, SUFFIXES.size());
		let scaled = 10 ** (log10 - group * 3);
		const shownPrecision = scaled < 10 ? 2 : scaled < 100 ? 1 : 0;
		const rollsOver = (tonumber(string.format(`%.${tostring(shownPrecision)}f`, scaled)) ?? 0) >= 1000;
		if ((scaled >= 1000 || rollsOver) && group < SUFFIXES.size()) {
			group += 1;
			scaled /= 1000;
		}
		let suffix = SUFFIXES[group - 1];
		// word tiers ("Googol", "Horizon") get a space so "1.01 Horizon" doesn't read as one garbled word
		if (suffix.size() >= 5) {
			suffix = ` ${suffix}`;
		}
		const precision = scaled < 10 ? 2 : scaled < 100 ? 1 : 0;
		let formatted = string.format(`%.${tostring(precision)}f`, scaled);
		formatted = string.gsub(formatted, "(%..-)0+$", "%1")[0];
		formatted = string.gsub(formatted, "%.$", "")[0];
		return `${formatted}${suffix}`;
	}

	function scaleForDisplay(value: number): LuaTuple<[number, string]> {
		const absolute = math.abs(value);
		if (absolute !== absolute || absolute === 0) {
			return $tuple(0, "");
		}
		if (absolute === math.huge || math.log(absolute) / math.log(10) >= LAST_NAMED_LOG10) {
			return $tuple(1, "e308+");
		}
		if (absolute < 1000) {
			return $tuple(value, "");
		}
		let group = math.clamp(math.floor(math.log(absolute) / math.log(1000)), 1, SUFFIXES.size());
		let scaled = value / 1000 ** group;
		if (math.abs(scaled) >= 1000 && group < SUFFIXES.size()) {
			group += 1;
			scaled /= 1000;
		}
		return $tuple(scaled, SUFFIXES[group - 1]);
	}

	const Format = {
		Number(this: void, value: unknown, decimals?: number): string {
			if (typeIs(value, "string") || typeIs(value, "table")) {
				return formatFromLog10(OmegaMath.Log10(value));
			}
			if (!typeIs(value, "number") || value !== value) {
				return "0";
			}
			if (value === math.huge || value === -math.huge) {
				return formatFromLog10(OmegaMath.Log10(value));
			}
			if (math.abs(value) >= 999.5) {
				const text = formatFromLog10(math.log10(math.abs(value)));
				return value < 0 ? `-${text}` : text;
			}
			const [scaled, suffix] = scaleForDisplay(value);
			if (suffix === "") {
				const absolute = math.abs(value);
				let precision = decimals;
				if (precision === undefined) {
					precision = absolute < 10 && absolute % 1 !== 0 ? 1 : 0;
				}
				let formatted = string.format(`%.${tostring(precision)}f`, value);
				formatted = string.gsub(formatted, "(%..-)0+$", "%1")[0];
				formatted = string.gsub(formatted, "%.$", "")[0];
				return formatted;
			}
			const absolute = math.abs(scaled);
			let precision = decimals;
			if (precision === undefined) {
				if (absolute < 10) {
					precision = 2;
				} else if (absolute < 100) {
					precision = 1;
				} else {
					precision = 0;
				}
			}
			let formatted = string.format(`%.${tostring(precision)}f`, scaled);
			formatted = string.gsub(formatted, "(%..-)0+$", "%1")[0];
			formatted = string.gsub(formatted, "%.$", "")[0];
			return `${formatted}${suffix}`;
		},

		Integer(this: void, value: number): string {
			const rounded = math.floor(value + 0.5);
			const text = tostring(rounded);
			const [sign, digits] = text.match("^([%-]?)(%d+)$");
			if (!typeIs(digits, "string")) {
				return text;
			}
			const reversed = digits.reverse().gsub("(%d%d%d)", "%1,")[0];
			const result = reversed.reverse().gsub("^,", "")[0];
			return `${sign ?? ""}${result}`;
		},

		Duration(this: void, seconds: number): string {
			seconds = math.max(0, math.floor(seconds));
			const days = math.floor(seconds / 86400);
			const hours = math.floor((seconds % 86400) / 3600);
			const minutes = math.floor((seconds % 3600) / 60);
			const remaining = seconds % 60;
			if (days > 0) {
				return string.format("%dd %02dh", days, hours);
			} else if (hours > 0) {
				return string.format("%dh %02dm", hours, minutes);
			} else if (minutes > 0) {
				return string.format("%dm %02ds", minutes, remaining);
			}
			return string.format("%ds", remaining);
		},

		Percent(this: void, value: number, decimals?: number): string {
			return string.format(`%.${tostring(decimals ?? 0)}f%%`, value * 100);
		},
	};

	return table.freeze(Format);
};

__defs["ActionFeatureMaps"] = () => {
	const ANOMALY_CHARGE: Record<string, number> = {
		CollectVault: 8,
		Overcharge: 3,
		BuyMachine: 5,
		BuyResearch: 5,
		BuyGridUpgrade: 6,
		UpgradeContinuum: 18,
		UpgradeArtifact: 6,
		UpgradeCrew: 5,
		UnlockZone: 16,
		Rebirth: 24,
		ClaimQuest: 7,
		ClaimAchievement: 12,
		ClaimDaily: 14,
		ClaimTimedReward: 9,
		SpinWheel: 12,
		ClaimExpedition: 20,
		ClaimCommanderReward: 8,
		ClaimWeeklyDirective: 16,
		ClaimSeasonTier: 12,
		OpenItemCrate: 14,
		UpgradeItem: 7,
		EquipBestItems: 10,
		BulkSalvageItems: 10,
	};

	const ANOMALY_SIGNAL: Record<string, string> = {
		CollectVault: "Collect",
		BuyMachine: "Upgrade",
		BuyResearch: "Upgrade",
		BuyGridUpgrade: "Upgrade",
		UpgradeContinuum: "Upgrade",
		UpgradeItem: "Upgrade",
		EquipBestItems: "Upgrade",
		UpgradeArtifact: "Upgrade",
		UpgradeCrew: "Upgrade",
		ClaimQuest: "Reward",
		ClaimAchievement: "Reward",
		ClaimDaily: "Reward",
		ClaimTimedReward: "Reward",
		ClaimExpedition: "Reward",
		ClaimCommanderReward: "Reward",
		ClaimWeeklyDirective: "Reward",
		ClaimSeasonTier: "Reward",
		ClaimForgePathStep: "Reward",
	};

	const FEATURE: Record<string, string> = {
		VisitPlot: "Crew",
		LeavePlot: "Crew",
		NudgeCrew: "Crew",
		GetCrew: "Crew",
		CrewInvite: "Crew",
		CrewRespond: "Crew",
		CrewLeave: "Crew",
		CrewKick: "Crew",
		CrewRename: "Crew",
		CrewClaim: "Crew",
		BuyResearch: "Research",
		BuyGridUpgrade: "StarGrid",
		UnlockZone: "Worlds",
		SelectZone: "Worlds",
		Rebirth: "Rebirth",
		DomainExpansion: "Domain",
		DomainLattice: "Domain",
		UpgradeContinuum: "Continuum",
		Ascend: "Ascension",
		UpgradeSigil: "Ascension",
		EchoAct: "Echoes",
		RebirthAct: "Rebirth",
		ClaimQuest: "Missions",
		ClaimAchievement: "Milestones",
		SpinWheel: "Wheel",
		ClaimDaily: "Rewards",
		ClaimTimedReward: "Rewards",
		ActivateBoost: "Rewards",
		LaunchExpedition: "Command",
		ClaimExpedition: "Command",
		EquipArtifact: "Command",
		UpgradeArtifact: "Command",
		UpgradeCrew: "Command",
		ClaimCommanderReward: "Command",
		ClaimWeeklyDirective: "Command",
		ClaimSeasonTier: "Command",
		BuySignalOffer: "Command",
		EquipTitle: "Command",
		RedeemCode: "Shop",
		VerifyCreatorFollow: "Shop",
		BuyItemOffer: "Inventory",
		OpenItemCrate: "Inventory",
		BuyDailyOffer: "Shop",
		BuyCrateSkin: "Shop",
		EquipCrateSkin: "Shop",
		FuseRelics: "Inventory",
		EquipItem: "Inventory",
		UnequipItem: "Inventory",
		UpgradeItem: "Inventory",
		SalvageItem: "Inventory",
		BulkSalvageItems: "Inventory",
		EquipBestItems: "Inventory",
		ToggleItemLock: "Inventory",
		SetItemAutoSalvage: "Inventory",
		PulseAnomaly: "Anomaly",
		StabilizeAnomaly: "Anomaly",
		BuyAnomalyProtocol: "Anomaly",
		ActivateAnomalySurge: "Anomaly",
		SetAnomalyChannel: "Anomaly",
		SetAnomalyLoadout: "Anomaly",
		ClaimAnomalyMilestone: "Anomaly",
		ClaimAnomalyDirective: "Anomaly",
		ClaimLabOrder: "Lab",
		RouteLabPower: "Lab",
		ReadStoryChapter: "Story",
		ClaimStoryChapter: "Story",
		ClaimForgePathStep: "ForgePath",
		ReadMail: "Mail",
		ClaimMail: "Mail",
		ClaimAllMail: "Mail",
		DeleteMail: "Mail",
		GetLeaderboard: "Leaderboards",
		ClaimConvergenceReward: "Convergence",
		BazaarPlay: "Bazaar",
		SetMarketFavorite: "Bazaar",
		RequestProcurement: "Bazaar",
		SelectSpecialization: "StarGrid",
	};

	const ActionFeatureMaps = {
		ANOMALY_CHARGE,
		ANOMALY_SIGNAL,
		FEATURE,

		AnomalyCharge(this: void, action: string): number | undefined {
			return ActionFeatureMaps.ANOMALY_CHARGE[action];
		},

		AnomalySignal(this: void, action: string): string | undefined {
			return ActionFeatureMaps.ANOMALY_SIGNAL[action];
		},

		FeatureId(this: void, action: string): string | undefined {
			return ActionFeatureMaps.FEATURE[action];
		},
	};

	return table.freeze(ActionFeatureMaps);
};

__defs["ActionResponse"] = () => {
	const ActionResponse = {
		Error(this: void, message: string): { ok: boolean; error: string } {
			return { ok: false, error: message };
		},

		Success(this: void, message: string | undefined, extra: Dict | undefined): Dict {
			const response = extra ?? {};
			response.ok = true;
			response.message = message;
			return response;
		},
	};

	return table.freeze(ActionResponse);
};

__defs["CommandActionValidators"] = () => {
	const READ_ONLY: Record<string, boolean> = {
		GetState: true,
		MeasureLatency: true,
		SubmitFeedback: true,
		ReportPlayer: true,
		GetPlayers: true,
		GetPlayerMirror: true,
		VisitPlot: true,
		LeavePlot: true,
		NudgeCrew: true,
		GetCrew: true,
		CrewInvite: true,
		CrewRespond: true,
		CrewLeave: true,
		CrewKick: true,
		CrewRename: true,
		CrewClaim: true,
		ReportPresence: true,
		GetGuild: true,
		GetGuildChatHistory: true,
		GetGuildAnnouncements: true,
		GetGuildSettings: true,
		GetGuildLogoReview: true,
		GetGuildLeaderboard: true,
		GetLeaderboard: true,
		GetAdminState: true,
		GetTrade: true,
		TradeViewAway: true,
		ChatOpenWhisper: true,
		ChatGlobal: true,
		ReportClientIntegrity: true,
		ReportPerformance: true,
		SetTutorialStep: true,
		ReplayTutorial: true,
	};

	const HIGH_VALUE_GRANT: Record<string, boolean> = {
		SpinWheel: true,
		BazaarPlay: true,
		OpenItemCrate: true,
		CollectVault: true,
		Rebirth: true,
		DomainExpansion: true,
		Ascend: true,
		RedeemCode: true,
		AdminExecute: true,
	};

	const DEFERRED_SNAPSHOT: Record<string, boolean> = {
		Overcharge: true,
		PulseAnomaly: true,
		RouteLabPower: true,
		SetAutoForge: true,
		SetAnomalyChannel: true,
		SetAnomalyLoadout: true,
		SetSetting: true,
		SetMobileLayout: true,
		SetTutorialStep: true,
		ReplayTutorial: true,
		DismissRelease: true,
		OpenRelease: true,
		ReadStoryChapter: true,
		ReadMail: true,
		ReportPresence: true,
		SelectZone: true,
	};

	const CommandActionValidators = {
		READ_ONLY,
		HIGH_VALUE_GRANT,
		DEFERRED_SNAPSHOT,

		IsValidAction(this: void, action: unknown): boolean {
			return typeIs(action, "string") && action.size() > 0;
		},

		IsReadOnly(this: void, action: string): boolean {
			return CommandActionValidators.READ_ONLY[action] === true;
		},

		RequiresHighValueNonce(this: void, action: string): boolean {
			return CommandActionValidators.HIGH_VALUE_GRANT[action] === true;
		},

		IsDeferredSnapshot(this: void, action: string): boolean {
			return CommandActionValidators.DEFERRED_SNAPSHOT[action] === true;
		},
	};

	return table.freeze(CommandActionValidators);
};

__defs["ShopGrantEligibility"] = () => {
	interface OfferLike {
		Id: string;
		Kind?: string;
		Name?: string;
		Currency?: string;
		Price?: number;
		StockMax?: number;
		DailyRefresh?: boolean;
		DailyRestock?: number;
	}

	const ShopGrantEligibility = {
		StockMax(this: void, offer: OfferLike): number {
			const stockMax = offer.StockMax;
			if (typeIs(stockMax, "number") && stockMax > 0) {
				return math.floor(stockMax);
			}
			return 1;
		},

		InventoryCount(this: void, inventory: unknown): number {
			if (!typeIs(inventory, "table")) {
				return 0;
			}
			let count = 0;
			for (const _ of pairs(inventory as object)) {
				count += 1;
			}
			return count;
		},

		RemainingStock(this: void, stockValue: unknown, stockMax: number): number {
			let remaining = stockValue;
			if (!typeIs(remaining, "number")) {
				remaining = stockMax;
			}
			return math.clamp(math.floor(remaining as number), 0, stockMax);
		},

		StudioGrantAllowed(this: void, isStudio: boolean): boolean {
			return isStudio === true;
		},

		ClampWheelGrant(this: void, amount: unknown): number {
			return math.clamp(math.floor(tonumber(amount) ?? 100), 1, 500);
		},

		EvaluateBuy(
			this: void,
			offer: OfferLike,
			remaining: number,
			inventoryCount: number,
			inventoryLimit: number,
			balance: unknown,
			formatShortage: (need: number, currency: string) => string,
		): LuaTuple<[boolean, string?]> {
			if (remaining <= 0) {
				if (offer.DailyRefresh === true) {
					return $tuple(false, "That daily offer is sold out. Come back after refresh.");
				}
				return $tuple(false, "That market offer is sold out.");
			}
			if (offer.Kind === "Item" && inventoryCount >= inventoryLimit) {
				return $tuple(false, "Your item inventory is full. Salvage something first.");
			}
			const price = tonumber(offer.Price) ?? 0;
			const have = typeIs(balance, "number") ? balance : undefined;
			if (have === undefined || have < price) {
				const currency = offer.Currency ?? "Cash";
				return $tuple(false, formatShortage(math.max(0, price - (have ?? 0)), currency));
			}
			if (offer.Kind !== "Key" && offer.Kind !== "Essence" && offer.Kind !== "Item") {
				return $tuple(false, "That market offer is misconfigured.");
			}
			return $tuple(true, undefined);
		},

		EnsureShop(this: void, shop: unknown, offers: OfferLike[], utcDay: number): boolean {
			if (!typeIs(shop, "table")) {
				return false;
			}
			const shopBag = shop as Dict;
			if (!typeIs(shopBag.Stock, "table")) {
				shopBag.Stock = {};
			}
			if (!typeIs(shopBag.Purchased, "table")) {
				shopBag.Purchased = {};
			}
			const stock = shopBag.Stock as Record<string, number>;
			let purchased = shopBag.Purchased as Record<string, boolean>;
			const day = math.floor(utcDay);
			let changed = false;

			for (const offer of offers) {
				const stockMax = ShopGrantEligibility.StockMax(offer);
				const current = stock[offer.Id];
				if (!typeIs(current, "number")) {
					if (purchased[offer.Id] === true) {
						stock[offer.Id] = 0;
					} else {
						stock[offer.Id] = stockMax;
					}
					changed = true;
				} else {
					const clamped = math.clamp(math.floor(current), 0, stockMax);
					if (clamped !== current) {
						stock[offer.Id] = clamped;
						changed = true;
					}
				}
			}

			if (shopBag.Day === day) {
				return changed;
			}

			shopBag.Day = day;
			shopBag.Purchased = {};
			purchased = shopBag.Purchased as Record<string, boolean>;
			for (const offer of offers) {
				const stockMax = ShopGrantEligibility.StockMax(offer);
				if (offer.DailyRefresh === true) {
					stock[offer.Id] = stockMax;
				} else {
					const restock = typeIs(offer.DailyRestock, "number")
						? math.max(0, math.floor(offer.DailyRestock))
						: 0;
					const current = stock[offer.Id] ?? 0;
					stock[offer.Id] = math.min(stockMax, current + restock);
				}
			}
			return true;
		},

		CatalogPublic(this: void, ownedPasses: unknown, copyDictionary: CopyDictionary) {
			return {
				OwnedPasses: copyDictionary(typeIs(ownedPasses, "table") ? ownedPasses : {}),
				CatalogVersion: 1,
			};
		},
	};

	return table.freeze(ShopGrantEligibility);
};

__defs["SocialBoost"] = () => {
	interface SocialConfig {
		MaxBoostedFriends: number;
		FriendProductionPerPlayer: number;
		PremiumProductionBonus: number;
	}

	interface SocialBoostState {
		FriendCount: number;
		FriendLimit: number;
		FriendBonus: number;
		Premium: boolean;
		PremiumBonus: number;
		Multiplier: number;
	}

	const SocialBoost = {
		Compute(this: void, friendCount: number, premium: boolean, config: SocialConfig): SocialBoostState {
			const friendLimit = config.MaxBoostedFriends;
			const count = math.clamp(math.floor(friendCount), 0, friendLimit);
			const friendBonus = count * config.FriendProductionPerPlayer;
			const premiumBonus = premium ? config.PremiumProductionBonus : 0;
			return {
				FriendCount: count,
				FriendLimit: friendLimit,
				FriendBonus: friendBonus,
				Premium: premium,
				PremiumBonus: premiumBonus,
				Multiplier: 1 + friendBonus + premiumBonus,
			};
		},

		Changed(this: void, previous: unknown, nextState: SocialBoostState): boolean {
			if (!typeIs(previous, "table")) {
				return true;
			}
			const prev = previous as Dict;
			return (
				prev.FriendCount !== nextState.FriendCount ||
				prev.FriendLimit !== nextState.FriendLimit ||
				prev.FriendBonus !== nextState.FriendBonus ||
				prev.Premium !== nextState.Premium ||
				prev.PremiumBonus !== nextState.PremiumBonus ||
				prev.Multiplier !== nextState.Multiplier
			);
		},

		Apply(this: void, profile: Dict, friendCount: number, premium: boolean, config: SocialConfig): boolean {
			const nextState = SocialBoost.Compute(friendCount, premium, config);
			const changed = SocialBoost.Changed(profile.SocialBoost, nextState);
			profile.SocialBoost = nextState;
			return changed;
		},

		DefaultSnapshot(this: void, maxBoostedFriends: number): SocialBoostState {
			return {
				FriendCount: 0,
				FriendLimit: maxBoostedFriends,
				FriendBonus: 0,
				Premium: false,
				PremiumBonus: 0,
				Multiplier: 1,
			};
		},

		PublicSnapshot(this: void, raw: unknown, maxBoostedFriends: number, copyDictionary: CopyDictionary): unknown {
			return copyDictionary(
				typeIs(raw, "table") ? raw : SocialBoost.DefaultSnapshot(maxBoostedFriends),
			);
		},

		CreatorRewardsPublic(this: void, raw: unknown, creatorName: string) {
			return {
				CreatorFollowClaimed:
					typeIs(raw, "table") && (raw as Dict).CreatorFollowClaimed === true,
				CreatorName: creatorName,
			};
		},
	};

	return table.freeze(SocialBoost);
};

__defs["TelemetryMath"] = () => {
	const TelemetryMath = {
		VERSION: 1,
		BYTES: 30,
		FLOAT_MIN: -3.4e38,
		FLOAT_MAX: 3.4e38,

		Number(this: void, value: unknown, asNumber?: (value: unknown) => number): number {
			const numeric = typeIs(asNumber, "function") ? asNumber(value) : tonumber(value);
			if (
				!typeIs(numeric, "number") ||
				numeric !== numeric ||
				numeric === math.huge ||
				numeric === -math.huge
			) {
				return 0;
			}
			return math.clamp(numeric, TelemetryMath.FLOAT_MIN, TelemetryMath.FLOAT_MAX);
		},

		SettingsFlags(this: void, settings: unknown): number {
			let flags = 0;
			if (!typeIs(settings, "table")) {
				return flags;
			}
			const bag = settings as Dict;
			if (truthy(bag.ReducedMotion)) {
				flags = bit32.bor(flags, 1);
			}
			if (truthy(bag.UIEffects)) {
				flags = bit32.bor(flags, 2);
			}
			if (truthy(bag.SoundEffects)) {
				flags = bit32.bor(flags, 4);
			}
			if (truthy(bag.HideOtherPlots)) {
				flags = bit32.bor(flags, 8);
			}
			return flags;
		},

		Encode(
			this: void,
			revision: unknown,
			settings: unknown,
			cash: unknown,
			vault: unknown,
			production: unknown,
			capacity: unknown,
			cores: unknown,
			stardust: unknown,
			asNumber?: (value: unknown) => number,
		): buffer {
			const packed = buffer.create(TelemetryMath.BYTES);
			buffer.writeu8(packed, 0, TelemetryMath.VERSION);
			buffer.writeu8(packed, 1, TelemetryMath.SettingsFlags(settings));
			const rev = math.floor(math.max(0, tonumber(revision) ?? 0)) % 4_294_967_296;
			buffer.writeu32(packed, 2, rev);
			buffer.writef32(packed, 6, TelemetryMath.Number(cash, asNumber));
			buffer.writef32(packed, 10, TelemetryMath.Number(vault, asNumber));
			buffer.writef32(packed, 14, TelemetryMath.Number(production, asNumber));
			buffer.writef32(packed, 18, TelemetryMath.Number(capacity, asNumber));
			buffer.writef32(packed, 22, TelemetryMath.Number(cores, asNumber));
			buffer.writef32(packed, 26, TelemetryMath.Number(stardust, asNumber));
			return packed;
		},
	};

	return table.freeze(TelemetryMath);
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name as string);
}
table.sort(__members);
table.freeze(__members);

interface CallableBundle {
	(name: string): unknown;
	readonly __members: readonly string[];
	readonly [key: string]: unknown;
}

const __bundle = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string) => __load(name),
		__index: (_self: unknown, name: string) => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as unknown as LuaMetatable<object>,
) as CallableBundle;

export = __bundle;
