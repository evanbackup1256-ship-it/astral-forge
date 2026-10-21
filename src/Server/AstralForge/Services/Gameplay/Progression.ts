// Progression: shared progression rules (stateless functions over a profile).
import EconomyMath from "../../Modules/EconomyMath";
import ProfileMath from "../../Modules/ProfileMath";
import CommandMath from "../../Modules/CommandMath";
import ProfileBagMath from "../../Modules/ProfileBagMath";
import GameConfigModule from "../../../../Shared/AstralForge/Shared/GameConfig";
import SeasonPremium from "../../../../Shared/AstralForge/Shared/SeasonPremium";

type Bag = Record<string, unknown>;
type Reward = {
  Cash?: number;
  CashMinutes?: number;
  Stardust?: number;
  Cores?: number;
  Boost?: string;
  Signals?: number;
  CommandXP?: number;
  StreakShield?: number;
  Essence?: number;
  DomainEssence?: number;
  Fragments?: number;
  FreeSpins?: number;
  Keys?: Record<string, number>;
};
interface Definition {
  Id: string;
  Name: string;
  Description: string;
  Kind: string;
  Target: number;
  Reward: Reward;
}
interface Quest extends Definition {
  Progress: number;
  Claimed: boolean;
}
interface Expedition extends Definition {
  RequiredLevel: number;
  Duration: number;
  ArtifactChance: number;
  ArtifactId: string;
}
interface Artifact extends Definition {
  Rarity: string;
}
interface Title extends Definition {
  Fx: unknown;
}
interface Offer {
  Id: string;
  Name: string;
  Description: string;
  Reward: Reward;
  Price: number;
  Color: Color3;
}
interface Step {
  XPCost: number;
  Reward: Reward;
}
interface ForgePath {
  ClaimedSteps: Record<string, boolean>;
  XP: number;
  XPDay: number;
  XPEarnedToday: number;
}
interface Receipt {
  ExpectedSpin: number;
  PrizeIndex: number;
  PrizeId: string;
  Message: string;
  Pity: boolean;
}
interface Wheel {
  LastSpinAt: number;
  Spins: number;
  PityMisses: number;
  FreeSpins: number;
  LastReceipt?: Receipt;
}
interface Prize {
  Id: string;
  Name: string;
  Rarity: string;
  Reward: Reward;
}
interface PoolEntry {
  Index: number;
  Prize: Prize;
  Weight: number;
}
type Command = ReturnType<typeof CommandMath.Ensure> & {
  Artifacts: Record<string, { Level: number; Fragments: number }>;
};
interface Profile extends Bag {
  Command: Command;
  ForgePath: ForgePath;
  Wheel: Wheel;
  Cash: unknown;
  RunCash: unknown;
  LifetimeCash: unknown;
  Stardust: number;
  Cores: number;
  Anomaly: { Fragments: number };
  Achievements: Record<string, boolean>;
  Quests: { Day: number; Items: Quest[] };
}
interface Config {
  Operations: {
    MaxCommanderLevel: number;
    SeasonId: string;
    WeeklyDirectives: (Definition & { BaseTarget: number })[];
    TitlesEnabled?: boolean;
    TitleStatus?: string;
    Titles: Title[];
    ShopOffers: Offer[];
    Expeditions: Expedition[];
    Artifacts: Artifact[];
    ArtifactShop: Record<
      string,
      { Refill: number; Stardust: number; Fragments: number }
    >;
    Crew: Record<string, { MaxLevel: number; BaseCost: number; Name: string }>;
    SeasonTiers: { RequiredXP: number; Reward: Reward }[];
  };
  Boosts: Record<string, { Name: string }>;
  Achievements: Definition[];
  DailyRewards: Reward[];
  TimedRewards: { Minutes: number; Reward: Reward }[];
  Economy: { ForgePathXP?: { DailySoftCap?: number; SoftCapScale?: number } };
  ForgePath: { Steps: Step[]; StepCount?: number; ChapterMarks: unknown };
  Wheel: {
    CooldownSeconds: number;
    PityAfter: number;
    PityRarity?: string;
    Rewards: Prize[];
  };
}
interface EconomyApi {
  Add(this: void, a: unknown, b: unknown): unknown;
  Sub(this: void, a: unknown, b: unknown): unknown;
  Mul(this: void, a: unknown, b: unknown): unknown;
  Max(this: void, a: unknown, b: unknown): unknown;
  AsNumber(this: void, value: unknown): number;
  Production(this: void, profile: unknown): number;
  SteadyProduction(this: void, profile: unknown): number;
  DomainTreeBonus(this: void, profile: unknown, kind: string): number;
  Gte(this: void, a: unknown, b: unknown): boolean;
  Lt(this: void, a: unknown, b: unknown): boolean;
  GetExpedition(this: void, id: string): Expedition | undefined;
}
interface OpsApi {
  ApplyCommandXP(
    this: void,
    command: unknown,
    amount: number,
    bonus: number,
  ): number;
  FindById<T>(this: void, list: T[], id: string): T | undefined;
  WeeklyValue(this: void, profile: unknown, kind: string): number;
  CommanderReward(this: void, level: number): Reward;
  TitleUnlocked(
    this: void,
    profile: unknown,
    title: Title,
    command: unknown,
    level: number,
    gte: EconomyApi["Gte"],
  ): boolean;
  AdvanceQuestProgress(
    this: void,
    items: Quest[],
    kind: string,
    amount: number,
  ): number;
  CanClaimQuest(this: void, quest: Quest): LuaTuple<[boolean, string]>;
  AchievementProgress(
    this: void,
    profile: unknown,
    kind: string,
    asNumber: EconomyApi["AsNumber"],
  ): number;
}
interface WheelApi {
  Ensure(this: void, wheel: unknown): Wheel;
  ValidExpectedSpin(this: void, spin: unknown): boolean;
  Snapshot(
    this: void,
    now: number,
    wheel: Wheel,
    cooldown: number,
    pity: number,
  ): unknown;
  RARITY_RANK: Record<string, number>;
  BuildPool(
    this: void,
    rewards: Prize[],
    force: boolean,
    floor: number,
  ): LuaTuple<[PoolEntry[], number]>;
  FullPool(this: void, rewards: Prize[]): LuaTuple<[PoolEntry[], number]>;
  PickEntry(
    this: void,
    pool: PoolEntry[],
    total: number,
    roll: number,
  ): PoolEntry | undefined;
  RarityRank(this: void, rarity: string): number;
  NextPityMisses(
    this: void,
    misses: number,
    rank: number,
    floor: number,
  ): number;
  RecordHistory(
    this: void,
    wheel: Wheel,
    id: string,
    at: number,
    pity: boolean,
  ): void;
}
type Result = LuaTuple<[boolean, string]>;

const GameConfig = GameConfigModule as unknown as Config;
const Economy = EconomyMath("Economy") as EconomyApi;
const Format = ProfileMath("Format") as {
  Number(this: void, value: unknown): string;
};
const ForgePathClaim = EconomyMath("ForgePathClaim") as {
  Ensure(this: void, value: unknown): ForgePath;
  TryClaim(
    this: void,
    value: ForgePath,
    step: unknown,
    steps: Step[],
  ): LuaTuple<[boolean, string | undefined, Step | undefined]>;
};
const WheelMath = EconomyMath("WheelMath") as WheelApi;
const ProgressionOpsMath = EconomyMath("ProgressionOpsMath") as OpsApi;
const UtcClockMath = ProfileMath("UtcClockMath") as {
  Day(this: void, now: number): number;
  Week(this: void, now: number): number;
};
const currentDay = () => UtcClockMath.Day(os.time());
const currentWeek = () => UtcClockMath.Week(os.time());
const copyReward = (reward: Reward) => table.clone(reward);
const commanderLevel = (xp: number) =>
  CommandMath.Level(xp, GameConfig.Operations.MaxCommanderLevel);
function ensureCommand(profile: Profile): Command {
  profile.Command = CommandMath.Ensure(
    profile.Command,
    GameConfig.Operations.SeasonId,
  ) as Command;
  return profile.Command;
}
const bumpStat = (profile: Profile, key: string, amount?: number) =>
  ProfileBagMath.BumpStat(profile, key, amount);
const ensureDaily = (profile: Profile) => ProfileBagMath.EnsureDaily(profile);
const ensureQuests = (profile: Profile) =>
  ProfileBagMath.EnsureQuests(profile) as { Day: number; Items: Quest[] };
const ensureTimedRewardsBag = (profile: Profile) =>
  ProfileBagMath.EnsureTimedRewards(profile);
function ensureWheel(profile: Profile): Wheel {
  profile.Wheel = WheelMath.Ensure(profile.Wheel);
  return profile.Wheel;
}
function awardCommandXP(profile: Profile, amount: number) {
  const command = ensureCommand(profile);
  ProgressionOpsMath.ApplyCommandXP(
    command,
    amount,
    Economy.DomainTreeBonus(profile, "CommandXP"),
  );
}
function currentWeeklyValue(profile: Profile, kind: string): number {
  const value = ProgressionOpsMath.WeeklyValue(profile, kind);
  if (!typeIs(value, "number") || value !== value) return 0;
  return math.clamp(value, -1e308, 1e308);
}
function titleUnlocked(profile: Profile, title: Title): boolean {
  const command = ensureCommand(profile);
  return ProgressionOpsMath.TitleUnlocked(
    profile,
    title,
    command,
    commanderLevel(command.XP),
    Economy.Gte,
  );
}
function ensureForgePath(profile: Profile) {
  profile.ForgePath = ForgePathClaim.Ensure(profile.ForgePath);
}
function awardForgePathXP(profile: Profile, amount: number) {
  ensureForgePath(profile);
  let value = math.max(0, math.floor(amount));
  value = math.floor(
    value * (1 + Economy.DomainTreeBonus(profile, "ForgePathXP")),
  );
  const config = GameConfig.Economy.ForgePathXP;
  if (typeIs(config, "table")) {
    const day = currentDay();
    if (profile.ForgePath.XPDay !== day) {
      profile.ForgePath.XPDay = day;
      profile.ForgePath.XPEarnedToday = 0;
    }
    const earned = math.max(
      0,
      math.floor(tonumber(profile.ForgePath.XPEarnedToday) ?? 0),
    );
    const softCap = math.max(
      1,
      math.floor(tonumber(config.DailySoftCap) ?? 12_000),
    );
    if (earned >= softCap)
      value = math.max(
        0,
        math.floor(value * (tonumber(config.SoftCapScale) ?? 0.35)),
      );
    profile.ForgePath.XPEarnedToday = ProfileBagMath.AddFinite(earned, value);
  }
  profile.ForgePath.XP = ProfileBagMath.AddFinite(
    profile.ForgePath.XP,
    value,
  );
}
const ProgressionService = {
  AwardCommandXP: awardCommandXP,
  AwardForgePathXP: awardForgePathXP,
  ApplyReward(
    this: void,
    profile: Profile,
    reward: Reward,
    production?: number,
  ): string {
    const parts: string[] = [];
    for (const currency of ["Stardust", "Cores"] as const) {
      const amount = reward[currency];
      if (typeIs(amount, "number") && amount > 0) {
        const balance = tonumber(profile[currency]) ?? 0;
        const credited = balance + amount;
        // This implementation runs exclusively in Roblox; the original non-Roblox error branch is inapplicable.
        if (credited <= balance || credited >= math.huge || balance >= 1e14)
          profile[currency] = 1e14;
      }
    }
    if (reward.Cash !== undefined && reward.Cash > 0) {
      profile.Cash = Economy.Add(profile.Cash, reward.Cash);
      profile.RunCash = Economy.Add(profile.RunCash, reward.Cash);
      profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward.Cash);
      parts.push(Format.Number(reward.Cash) + " Flux");
    }
    if (reward.CashMinutes !== undefined && reward.CashMinutes > 0) {
      const generated = Economy.Max(
        500,
        Economy.Mul(
          production ?? Economy.SteadyProduction(profile),
          60 * reward.CashMinutes,
        ),
      );
      profile.Cash = Economy.Add(profile.Cash, generated);
      profile.RunCash = Economy.Add(profile.RunCash, generated);
      profile.LifetimeCash = Economy.Add(profile.LifetimeCash, generated);
      parts.push(Format.Number(generated) + " Flux");
    }
    if (reward.Stardust !== undefined && reward.Stardust > 0) {
      profile.Stardust = math.clamp(
        (tonumber(profile.Stardust) ?? 0) + reward.Stardust,
        0,
        1e14,
      );
      parts.push(Format.Number(reward.Stardust) + " Stardust");
    }
    if (reward.Cores !== undefined && reward.Cores > 0) {
      profile.Cores = math.clamp(
        (tonumber(profile.Cores) ?? 0) + reward.Cores,
        0,
        1e14,
      );
      parts.push(Format.Number(reward.Cores) + " cores");
    }
    if (
      reward.Boost !== undefined &&
      GameConfig.Boosts[reward.Boost] !== undefined
    ) {
      const inventory = ProfileBagMath.EnsureBoostInventory(profile);
      inventory[reward.Boost] = (tonumber(inventory[reward.Boost]) ?? 0) + 1;
      parts.push(GameConfig.Boosts[reward.Boost].Name);
    }
    if (reward.Signals !== undefined && reward.Signals > 0) {
      const command = ensureCommand(profile);
      command.Signals = (tonumber(command.Signals) ?? 0) + reward.Signals;
      parts.push(Format.Number(reward.Signals) + " signals");
    }
    if (reward.CommandXP !== undefined && reward.CommandXP > 0) {
      awardCommandXP(profile, reward.CommandXP);
      parts.push(Format.Number(reward.CommandXP) + " command XP");
    }
    if (reward.StreakShield !== undefined && reward.StreakShield > 0) {
      const command = ensureCommand(profile);
      command.StreakShields =
        (tonumber(command.StreakShields) ?? 0) + reward.StreakShield;
      parts.push(Format.Number(reward.StreakShield) + " streak shield");
    }
    if (reward.Essence !== undefined && reward.Essence > 0) {
      const domain = ProfileBagMath.EnsureDomain(profile);
      domain.Essence = math.min(
        1_000_000,
        math.max(0, math.floor(tonumber(domain.Essence) ?? 0)) +
          math.floor(reward.Essence),
      );
      parts.push(Format.Number(reward.Essence) + " domain essence");
    }
    if (reward.DomainEssence !== undefined && reward.DomainEssence > 0) {
      const domain = ProfileBagMath.EnsureDomain(profile);
      domain.Essence = math.min(
        1_000_000,
        math.max(0, math.floor(tonumber(domain.Essence) ?? 0)) +
          math.floor(reward.DomainEssence),
      );
      parts.push(Format.Number(reward.DomainEssence) + " domain essence");
    }
    if (reward.Fragments !== undefined && reward.Fragments > 0) {
      if (!typeIs(profile.Anomaly, "table"))
        profile.Anomaly = { Fragments: 0 };
      profile.Anomaly.Fragments =
        (tonumber(profile.Anomaly.Fragments) ?? 0) +
        math.floor(reward.Fragments);
      parts.push(Format.Number(reward.Fragments) + " fragments");
    }
    if (reward.FreeSpins !== undefined && reward.FreeSpins > 0) {
      const wheel = ensureWheel(profile);
      wheel.FreeSpins =
        (tonumber(wheel.FreeSpins) ?? 0) + math.floor(reward.FreeSpins);
      parts.push(
        Format.Number(reward.FreeSpins) +
          " free spin" +
          (reward.FreeSpins === 1 ? "" : "s"),
      );
    }
    if (typeIs(reward.Keys, "table")) {
      const keys = ProfileBagMath.EnsureItemKeys(profile);
      for (const [crateId, amount] of pairs(reward.Keys)) {
        if (
          typeIs(crateId, "string") &&
          typeIs(amount, "number") &&
          amount > 0
        ) {
          keys[crateId] = (tonumber(keys[crateId]) ?? 0) + math.floor(amount);
          parts.push(Format.Number(amount) + " " + crateId);
        }
      }
    }
    return parts.join(", ");
  },
  EnsureQuests(this: void, profile: Profile, userId: number): boolean {
    const day = currentDay();
    const questsBag = ensureQuests(profile);
    if (questsBag.Day === day && questsBag.Items.size() > 0) return false;
    const production = Economy.Max(4, Economy.Production(profile));
    const scale = 1 + (tonumber(profile.Rebirths) ?? 0) * 0.15;
    const earnTarget = math.floor(
      math.min(
        1e300,
        math.max(
          2_000,
          Economy.AsNumber(Economy.Mul(production, 8 * 60)) * scale,
        ),
      ),
    );
    const tapTarget = math.floor(
      (40 + (tonumber(profile.Rebirths) ?? 0) * 3) * scale,
    );
    const upgradeTarget = math.floor(
      3 + math.min(7, (tonumber(profile.Rebirths) ?? 0) / 2),
    );
    const rotation = (day + userId) % 3;
    profile.Quests = {
      Day: day,
      Items: [
        {
          Id: string.format("earn_%d", day),
          Name: "Shift Quota",
          Description: "Bank Flux from your vault.",
          Kind: "EarnCash",
          Target: earnTarget,
          Progress: 0,
          Reward: { Cash: math.floor(earnTarget * 0.15), Stardust: 5 },
          Claimed: false,
        },
        {
          Id: string.format("tap_%d", day),
          Name: "Hands On",
          Description: "Use manual overcharge.",
          Kind: "Tap",
          Target: tapTarget,
          Progress: 0,
          Reward: { Cash: math.floor(earnTarget * 0.08), Stardust: 4 },
          Claimed: false,
        },
        {
          Id: string.format("upgrade_%d", day),
          Name:
            rotation === 0
              ? "Machinist"
              : rotation === 1
                ? "Research Grant"
                : "Expansion Plan",
          Description:
            rotation === 0
              ? "Upgrade any machines."
              : rotation === 1
                ? "Purchase research levels."
                : "Purchase machines or research.",
          Kind:
            rotation === 0
              ? "BuyMachine"
              : rotation === 1
                ? "BuyResearch"
                : "BuyAny",
          Target: upgradeTarget,
          Progress: 0,
          Reward: { Cash: math.floor(earnTarget * 0.12), Stardust: 6 },
          Claimed: false,
        },
      ],
    };
    return true;
  },
  Progress(this: void, profile: Profile, kind: string, amount: number) {
    ProgressionOpsMath.AdvanceQuestProgress(
      ensureQuests(profile).Items,
      kind,
      amount,
    );
  },
  ClaimQuest(this: void, profile: Profile, questId: string): Result {
    for (const quest of ensureQuests(profile).Items) {
      if (quest.Id === questId) {
        const [ok, reason] = ProgressionOpsMath.CanClaimQuest(quest);
        if (!ok) return $tuple(false, reason);
        quest.Claimed = true;
        return $tuple(
          true,
          ProgressionService.ApplyReward(profile, quest.Reward),
        );
      }
    }
    return $tuple(false, "Mission not found.");
  },
  AchievementProgress(this: void, profile: Profile, kind: string): number {
    return ProgressionOpsMath.AchievementProgress(
      profile,
      kind,
      Economy.AsNumber,
    );
  },
  AchievementStates(this: void, profile: Profile) {
    const claimed = typeIs(profile.Achievements, "table")
      ? profile.Achievements
      : {};
    return GameConfig.Achievements.map((achievement) => ({
      Id: achievement.Id,
      Name: achievement.Name,
      Description: achievement.Description,
      Target: achievement.Target,
      Progress: math.min(
        achievement.Target,
        ProgressionService.AchievementProgress(profile, achievement.Kind),
      ),
      Reward: copyReward(achievement.Reward),
      Claimed: claimed[achievement.Id] === true,
    }));
  },
  ClaimAchievement(
    this: void,
    profile: Profile,
    achievementId: string,
  ): Result {
    for (const achievement of GameConfig.Achievements) {
      if (achievement.Id === achievementId) {
        if (!typeIs(profile.Achievements, "table")) profile.Achievements = {};
        if (profile.Achievements[achievementId])
          return $tuple(false, "That milestone was already claimed.");
        if (
          ProgressionService.AchievementProgress(profile, achievement.Kind) <
          achievement.Target
        )
          return $tuple(false, "That milestone is not complete yet.");
        profile.Achievements[achievementId] = true;
        return $tuple(
          true,
          ProgressionService.ApplyReward(profile, achievement.Reward),
        );
      }
    }
    return $tuple(false, "Milestone not found.");
  },
  DailyState(this: void, profile: Profile) {
    const day = currentDay();
    const daily = ensureDaily(profile);
    const canClaim = daily.LastClaimDay < day;
    const nextStreak =
      daily.LastClaimDay === day - 1
        ? daily.Streak + 1
        : canClaim
          ? 1
          : daily.Streak;
    const rewardIndex =
      ((math.max(1, nextStreak) - 1) % GameConfig.DailyRewards.size()) + 1;
    return {
      CanClaim: canClaim,
      Streak: daily.Streak,
      NextStreak: nextStreak,
      RewardIndex: rewardIndex,
      Rewards: GameConfig.DailyRewards,
    };
  },
  ClaimDaily(this: void, profile: Profile): Result {
    const day = currentDay();
    const daily = ensureDaily(profile);
    if (daily.LastClaimDay >= day)
      return $tuple(false, "Come back tomorrow for the next daily.");
    if (daily.LastClaimDay === day - 1) daily.Streak += 1;
    else if (daily.LastClaimDay < day - 1 && daily.Streak > 0) {
      const command = ensureCommand(profile);
      const shields = math.max(
        0,
        math.floor(tonumber(command.StreakShields) ?? 0),
      );
      if (shields > 0) {
        command.StreakShields = shields - 1;
        daily.Streak += 1;
      } else daily.Streak = 1;
    } else daily.Streak = 1;
    daily.LastClaimDay = day;
    const rewardIndex =
      ((daily.Streak - 1) % GameConfig.DailyRewards.size()) + 1;
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        GameConfig.DailyRewards[rewardIndex - 1],
        Economy.Production(profile),
      ),
    );
  },
  EnsureWeekly(this: void, profile: Profile): boolean {
    const command = ensureCommand(profile);
    const week = currentWeek();
    if (command.Weekly.Week === week) {
      let changed = false;
      for (const directive of GameConfig.Operations.WeeklyDirectives) {
        const existing = command.Weekly.Baseline[directive.Kind];
        if (
          existing === undefined ||
          existing !== existing ||
          existing === math.huge ||
          existing === -math.huge
        ) {
          command.Weekly.Baseline[directive.Kind] = currentWeeklyValue(
            profile,
            directive.Kind,
          );
          changed = true;
        }
      }
      return changed;
    }
    const baseline: Record<string, number> = {};
    for (const directive of GameConfig.Operations.WeeklyDirectives)
      baseline[directive.Kind] = currentWeeklyValue(profile, directive.Kind);
    command.Weekly = { Week: week, Baseline: baseline, Claimed: {} };
    return true;
  },
  WeeklyState(this: void, profile: Profile) {
    const command = ensureCommand(profile);
    const current = command.Weekly;
    const weekMatches = current.Week === currentWeek();
    const baselines = weekMatches ? current.Baseline : {};
    const claimed = weekMatches ? current.Claimed : {};
    const level = commanderLevel(command.XP);
    const scale = 1 + math.floor((level - 1) / 10) * 0.35;
    return GameConfig.Operations.WeeklyDirectives.map((directive) => {
      const target = math.floor(directive.BaseTarget * scale);
      const baseline =
        baselines[directive.Kind] ??
        currentWeeklyValue(profile, directive.Kind);
      return {
        Id: directive.Id,
        Name: directive.Name,
        Description: directive.Description,
        Progress: math.min(
          target,
          math.max(0, currentWeeklyValue(profile, directive.Kind) - baseline),
        ),
        Target: target,
        Reward: copyReward(directive.Reward),
        Claimed: claimed[directive.Id] === true,
      };
    });
  },
  ClaimWeeklyDirective(
    this: void,
    profile: Profile,
    directiveId: string,
  ): Result {
    const command = ensureCommand(profile);
    ProgressionService.EnsureWeekly(profile);
    for (const item of ProgressionService.WeeklyState(profile)) {
      if (item.Id === directiveId) {
        if (item.Claimed)
          return $tuple(false, "That weekly directive was already claimed.");
        if (item.Progress < item.Target)
          return $tuple(false, "That weekly directive is not complete.");
        command.Weekly.Claimed[directiveId] = true;
        bumpStat(profile, "WeeklyClaimed", 1);
        return $tuple(
          true,
          ProgressionService.ApplyReward(
            profile,
            item.Reward,
            Economy.Production(profile),
          ),
        );
      }
    }
    return $tuple(false, "Weekly directive not found.");
  },
  TitleStates(this: void, profile: Profile) {
    if (GameConfig.Operations.TitlesEnabled === false) return [];
    const command = ensureCommand(profile);
    return GameConfig.Operations.Titles.map((title) => ({
      Id: title.Id,
      Name: title.Name,
      Description: title.Description,
      Unlocked: titleUnlocked(profile, title),
      Equipped: command.EquippedTitle === title.Id,
      Fx: title.Fx,
    }));
  },
  EquipTitle(this: void, profile: Profile, titleId: string): Result {
    if (GameConfig.Operations.TitlesEnabled === false)
      return $tuple(
        false,
        GameConfig.Operations.TitleStatus ??
          "Titles are temporarily unavailable.",
      );
    const title = ProgressionOpsMath.FindById(
      GameConfig.Operations.Titles,
      titleId,
    );
    if (title === undefined || !titleUnlocked(profile, title))
      return $tuple(false, "That command title is still locked.");
    ensureCommand(profile).EquippedTitle = titleId;
    return $tuple(true, title.Name + " equipped.");
  },
  EnsureCommandRotations(this: void, profile: Profile): boolean {
    const command = ensureCommand(profile);
    let changed = ProgressionService.EnsureWeekly(profile);
    const day = currentDay();
    if (command.Shop.Day !== day) {
      command.Shop = { Day: day, Purchased: {} };
      changed = true;
    }
    if (command.SeasonId !== GameConfig.Operations.SeasonId) {
      command.SeasonId = GameConfig.Operations.SeasonId;
      command.SeasonXP = 0;
      command.SeasonClaims = {};
      command.PremiumClaims = {};
      changed = true;
    }
    return changed;
  },
  SignalShopState(this: void, profile: Profile) {
    const command = ensureCommand(profile);
    const offers: (Offer & { Purchased: boolean })[] = [];
    const source = GameConfig.Operations.ShopOffers;
    const day = currentDay();
    const purchased = command.Shop.Day === day ? command.Shop.Purchased : {};
    for (let slot = 1; slot <= 4; slot++) {
      const index = ((day + slot - 2) % source.size()) + 1;
      const offer = source[index - 1];
      offers.push({
        Id: offer.Id,
        Name: offer.Name,
        Description: offer.Description,
        Price: offer.Price,
        Reward: copyReward(offer.Reward),
        Color: offer.Color,
        Purchased: purchased[offer.Id] === true,
      });
    }
    return offers;
  },
  BuySignalOffer(this: void, profile: Profile, offerId: string): Result {
    ProgressionService.EnsureCommandRotations(profile);
    for (const offer of ProgressionService.SignalShopState(profile)) {
      if (offer.Id === offerId) {
        if (offer.Purchased)
          return $tuple(
            false,
            "That signal offer was already purchased today.",
          );
        if (profile.Command.Signals < offer.Price)
          return $tuple(false, "You need more command signals.");
        profile.Command.Signals -= offer.Price;
        profile.Command.Shop.Purchased[offerId] = true;
        bumpStat(profile, "ShopPurchases", 1);
        return $tuple(
          true,
          ProgressionService.ApplyReward(
            profile,
            offer.Reward,
            Economy.Production(profile),
          ),
        );
      }
    }
    return $tuple(false, "That signal offer is not in today's rotation.");
  },
  LaunchExpedition(
    this: void,
    profile: Profile,
    expeditionId: string,
  ): Result {
    if (profile.Command.ActiveExpedition.Id !== "")
      return $tuple(false, "Claim or finish the active expedition first.");
    const expedition =
      Economy.GetExpedition(expeditionId) ??
      ProgressionOpsMath.FindById(
        GameConfig.Operations.Expeditions,
        expeditionId,
      );
    if (expedition === undefined)
      return $tuple(false, "Expedition route not found.");
    if (commanderLevel(profile.Command.XP) < expedition.RequiredLevel)
      return $tuple(
        false,
        string.format(
          "Commander level %d is required.",
          expedition.RequiredLevel,
        ),
      );
    const pilotLevel = profile.Command.Crew.Pilot ?? 1;
    const durationScale = math.max(0.35, 1 - (pilotLevel - 1) * 0.05);
    const now = os.time();
    const duration = math.max(
      10,
      math.floor(expedition.Duration * durationScale),
    );
    profile.Command.ActiveExpedition = {
      Id: expedition.Id,
      StartedAt: now,
      EndsAt: now + duration,
    };
    return $tuple(true, expedition.Name + " launched.");
  },
  ClaimExpedition(
    this: void,
    profile: Profile,
    random: Random,
  ): LuaTuple<[boolean, string, string?, boolean?]> {
    const active = profile.Command.ActiveExpedition;
    if (active.Id === "")
      return $tuple(false, "No expedition is currently active.");
    if (os.time() < active.EndsAt)
      return $tuple(false, "That expedition is still underway.");
    const expedition =
      Economy.GetExpedition(active.Id) ??
      ProgressionOpsMath.FindById(
        GameConfig.Operations.Expeditions,
        active.Id,
      );
    if (expedition === undefined) {
      profile.Command.ActiveExpedition = { Id: "", StartedAt: 0, EndsAt: 0 };
      return $tuple(false, "The expedition route could not be recovered.");
    }
    const reward = copyReward(expedition.Reward);
    const engineerLevel = profile.Command.Crew.Engineer ?? 1;
    const yieldScale = 1 + (engineerLevel - 1) * 0.08;
    if (reward.CashMinutes !== undefined) reward.CashMinutes *= yieldScale;
    if (reward.Stardust !== undefined)
      reward.Stardust = math.floor(reward.Stardust * yieldScale);
    if (reward.Signals !== undefined)
      reward.Signals = math.floor(reward.Signals * yieldScale);
    profile.Command.ExpeditionsCompleted += 1;
    bumpStat(profile, "Expeditions", 1);
    profile.Command.ActiveExpedition = { Id: "", StartedAt: 0, EndsAt: 0 };
    let message = ProgressionService.ApplyReward(
      profile,
      reward,
      Economy.Production(profile),
    );
    const navigatorLevel = profile.Command.Crew.Navigator ?? 1;
    const chance = math.min(
      0.95,
      expedition.ArtifactChance + (navigatorLevel - 1) * 0.03,
    );
    const artifactState = profile.Command.Artifacts[expedition.ArtifactId];
    const discovered = artifactState === undefined;
    const [firstArtifact] = next(profile.Command.Artifacts);
    const shouldDiscover =
      (discovered && firstArtifact === undefined) ||
      random.NextNumber() <= chance;
    if (shouldDiscover) {
      if (artifactState !== undefined) {
        artifactState.Fragments +=
          4 + math.floor(expedition.RequiredLevel / 10);
        message += string.format(", %s fragments", expedition.ArtifactId);
      } else {
        profile.Command.Artifacts[expedition.ArtifactId] = {
          Level: 1,
          Fragments: 0,
        };
        bumpStat(profile, "ArtifactsFound", 1);
        message += ", artifact discovered";
      }
      return $tuple(true, message, expedition.ArtifactId, discovered);
    }
    return $tuple(true, message);
  },
  EquipArtifact(this: void, profile: Profile, artifactId: string): Result {
    const artifact = ProgressionOpsMath.FindById(
      GameConfig.Operations.Artifacts,
      artifactId,
    );
    if (
      artifact === undefined ||
      profile.Command.Artifacts[artifactId] === undefined
    )
      return $tuple(false, "That artifact has not been discovered.");
    profile.Command.EquippedArtifact = artifactId;
    return $tuple(true, artifact.Name + " equipped.");
  },
  UpgradeArtifact(this: void, profile: Profile, artifactId: string): Result {
    const artifact = ProgressionOpsMath.FindById(
      GameConfig.Operations.Artifacts,
      artifactId,
    );
    const owned = profile.Command.Artifacts[artifactId];
    if (artifact === undefined || owned === undefined)
      return $tuple(false, "That artifact has not been discovered.");
    if (owned.Level >= 10)
      return $tuple(false, "That artifact is already max level.");
    const fragmentCost = 4 + owned.Level * 2;
    const dustCost = 8 * owned.Level;
    if (
      owned.Fragments < fragmentCost ||
      Economy.Lt(profile.Stardust, dustCost)
    )
      return $tuple(
        false,
        string.format(
          "Requires %d fragments and %d Stardust.",
          fragmentCost,
          dustCost,
        ),
      );
    owned.Fragments -= fragmentCost;
    profile.Stardust = Economy.AsNumber(
      Economy.Sub(profile.Stardust, dustCost),
    );
    owned.Level += 1;
    awardCommandXP(profile, 45 * owned.Level);
    return $tuple(
      true,
      string.format("%s upgraded to level %d.", artifact.Name, owned.Level),
    );
  },
  BuyArtifact(
    this: void,
    profile: Profile,
    artifactId: string,
  ): LuaTuple<[boolean, string, boolean?]> {
    const artifact = ProgressionOpsMath.FindById(
      GameConfig.Operations.Artifacts,
      artifactId,
    );
    const price =
      artifact !== undefined
        ? GameConfig.Operations.ArtifactShop[artifact.Rarity]
        : undefined;
    if (artifact === undefined || price === undefined)
      return $tuple(false, "That artifact is not sold here.");
    const owned = profile.Command.Artifacts[artifactId];
    const cost = owned !== undefined ? price.Refill : price.Stardust;
    if (Economy.Lt(profile.Stardust, cost))
      return $tuple(false, string.format("Requires %d Stardust.", cost));
    profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, cost));
    if (owned !== undefined) {
      owned.Fragments += price.Fragments;
      return $tuple(
        true,
        string.format("+%d %s fragments.", price.Fragments, artifact.Name),
        false,
      );
    }
    profile.Command.Artifacts[artifactId] = { Level: 1, Fragments: 0 };
    bumpStat(profile, "ArtifactsFound", 1);
    return $tuple(true, artifact.Name + " acquired.", true);
  },
  UpgradeCrew(this: void, profile: Profile, roleId: string): Result {
    const role = GameConfig.Operations.Crew[roleId];
    const level = profile.Command.Crew[roleId];
    if (role === undefined || !typeIs(level, "number"))
      return $tuple(false, "Crew role not found.");
    if (level >= role.MaxLevel)
      return $tuple(false, "That crew career is already maxed.");
    const cost = math.floor(role.BaseCost * level ** 1.55);
    if (profile.Command.Signals < cost)
      return $tuple(
        false,
        string.format("Requires %d command signals.", cost),
      );
    profile.Command.Signals -= cost;
    profile.Command.Crew[roleId] += 1;
    awardCommandXP(profile, 60 * level);
    return $tuple(
      true,
      string.format("%s advanced to level %d.", role.Name, level + 1),
    );
  },
  ClaimCommanderReward(
    this: void,
    profile: Profile,
    rawLevel: unknown,
  ): Result {
    if (
      !typeIs(rawLevel, "number") ||
      rawLevel !== rawLevel ||
      math.abs(rawLevel) === math.huge
    )
      return $tuple(false, "Invalid commander level.");
    const level = math.floor(rawLevel);
    if (level < 1 || level > commanderLevel(profile.Command.XP))
      return $tuple(false, "That commander level is not unlocked.");
    const key = tostring(level);
    if (profile.Command.CommanderClaims[key])
      return $tuple(false, "That commander reward was already claimed.");
    profile.Command.CommanderClaims[key] = true;
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        ProgressionOpsMath.CommanderReward(level),
        Economy.Production(profile),
      ),
    );
  },
  ClaimSeasonTier(this: void, profile: Profile, rawTier: unknown): Result {
    if (!typeIs(rawTier, "number"))
      return $tuple(false, "Invalid season tier.");
    ProgressionService.EnsureCommandRotations(profile);
    const tierIndex = math.floor(rawTier);
    const tier = GameConfig.Operations.SeasonTiers[tierIndex - 1];
    if (tier === undefined || profile.Command.SeasonXP < tier.RequiredXP)
      return $tuple(false, "That season tier is still locked.");
    const key = tostring(tierIndex);
    if (profile.Command.SeasonClaims[key])
      return $tuple(false, "That season tier was already claimed.");
    profile.Command.SeasonClaims[key] = true;
    bumpStat(profile, "SeasonTiers", 1);
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        tier.Reward,
        Economy.Production(profile),
      ),
    );
  },
  ClaimSeasonPremium(this: void, profile: Profile, rawTier: unknown): Result {
    if (!typeIs(rawTier, "number"))
      return $tuple(false, "Invalid season tier.");
    ProgressionService.EnsureCommandRotations(profile);
    const owned = profile.OwnedPasses as Record<string, unknown> | undefined;
    if (!typeIs(owned, "table") || owned[SeasonPremium.PassKey] !== true)
      return $tuple(false, "The Season Pass unlocks this reward.");
    const tierIndex = math.floor(rawTier);
    const tier = GameConfig.Operations.SeasonTiers[tierIndex - 1];
    if (tier === undefined || profile.Command.SeasonXP < tier.RequiredXP)
      return $tuple(false, "That season tier is still locked.");
    const key = tostring(tierIndex);
    if (profile.Command.PremiumClaims[key])
      return $tuple(false, "That pass reward was already claimed.");
    profile.Command.PremiumClaims[key] = true;
    bumpStat(profile, "SeasonPremiumTiers", 1);
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        SeasonPremium.Reward(tierIndex) as Reward,
        Economy.Production(profile),
      ),
    );
  },
  TotalForgePathXP(this: void, profile: Profile): number {
    ensureForgePath(profile);
    return profile.ForgePath.XP;
  },
  ClaimForgePathStep(this: void, profile: Profile, rawStep: unknown): Result {
    ensureForgePath(profile);
    const [ok, err, step] = ForgePathClaim.TryClaim(
      profile.ForgePath,
      rawStep,
      GameConfig.ForgePath.Steps,
    );
    if (!ok || step === undefined)
      return $tuple(false, err ?? "Invalid forge path step.");
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        step.Reward,
        Economy.SteadyProduction(profile),
      ),
    );
  },
  ForgePathState(this: void, profile: Profile) {
    ensureForgePath(profile);
    const claimed: number[] = [];
    for (const [key] of pairs(profile.ForgePath.ClaimedSteps)) {
      const index = tonumber(key);
      if (index !== undefined) claimed.push(index);
    }
    return {
      ClaimedSteps: claimed,
      XP: profile.ForgePath.XP,
      StepCount:
        GameConfig.ForgePath.StepCount ?? GameConfig.ForgePath.Steps.size(),
      ChapterMarks: GameConfig.ForgePath.ChapterMarks,
      XPEarnedToday: math.max(
        0,
        math.floor(tonumber(profile.ForgePath.XPEarnedToday) ?? 0),
      ),
    };
  },
  CommandState(this: void, profile: Profile) {
    const command = ensureCommand(profile);
    const level = commanderLevel(command.XP);
    const claimable: number[] = [];
    for (let rewardLevel = 1; rewardLevel <= level; rewardLevel++)
      if (!command.CommanderClaims[tostring(rewardLevel)])
        claimable.push(rewardLevel);
    return {
      XP: command.XP,
      Level: level,
      Rank: CommandMath.Rank(level),
      LevelFloorXP: CommandMath.FloorXP(level),
      NextLevelXP: CommandMath.NextXP(
        level,
        GameConfig.Operations.MaxCommanderLevel,
      ),
      Signals: command.Signals,
      StreakShields: command.StreakShields,
      ExpeditionsCompleted: command.ExpeditionsCompleted,
      ActiveExpedition: command.ActiveExpedition,
      Artifacts: command.Artifacts,
      EquippedArtifact: command.EquippedArtifact,
      Crew: command.Crew,
      CommanderClaims: command.CommanderClaims,
      ClaimableCommanderLevels: claimable,
      SeasonXP: command.SeasonXP,
      SeasonClaims: command.SeasonClaims,
      PremiumClaims: command.PremiumClaims,
      SeasonPassOwned: typeIs(profile.OwnedPasses, "table") && (profile.OwnedPasses as Record<string, unknown>)[SeasonPremium.PassKey] === true,
      Weekly: ProgressionService.WeeklyState(profile),
      Shop: ProgressionService.SignalShopState(profile),
      Titles: ProgressionService.TitleStates(profile),
      MachineMastery: command.MachineMastery,
    };
  },
  WheelState(this: void, profile: Profile) {
    return WheelMath.Snapshot(
      os.time(),
      ensureWheel(profile),
      GameConfig.Wheel.CooldownSeconds,
      GameConfig.Wheel.PityAfter,
    );
  },
  SpinWheel(
    this: void,
    profile: Profile,
    random: Random,
    expectedSpin?: number,
  ): LuaTuple<[boolean, string, number?, string?, boolean?]> {
    const now = os.time();
    const wheel = ensureWheel(profile);
    if (expectedSpin !== undefined) {
      if (!WheelMath.ValidExpectedSpin(expectedSpin))
        return $tuple(false, "Refresh the wheel before spinning.");
      const receipt = wheel.LastReceipt;
      if (receipt !== undefined && receipt.ExpectedSpin === expectedSpin)
        return $tuple(
          true,
          receipt.Message,
          receipt.PrizeIndex,
          receipt.PrizeId,
          receipt.Pity,
        );
      if (expectedSpin !== wheel.Spins)
        return $tuple(
          false,
          "That spin is already resolved. Refresh to see your latest result.",
        );
    }
    if (!WheelMath.ValidExpectedSpin(wheel.Spins))
      return $tuple(false, "Your spin counter needs support review.");
    const sequence = wheel.Spins;
    const freeSpins = wheel.FreeSpins;
    const onCooldown =
      now < wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds;
    if (freeSpins <= 0 && onCooldown)
      return $tuple(false, "Your next free wheel spin is not ready yet.");
    const pityAfter = math.max(
      1,
      math.floor(tonumber(GameConfig.Wheel.PityAfter) ?? 8),
    );
    const pityKey = string.upper(
      tostring(GameConfig.Wheel.PityRarity ?? "RARE"),
    );
    const floorRank = WheelMath.RARITY_RANK[pityKey] ?? 3;
    const forcePity = wheel.PityMisses + 1 >= pityAfter;
    let [pool, totalWeight] = WheelMath.BuildPool(
      GameConfig.Wheel.Rewards,
      forcePity,
      floorRank,
    );
    if (totalWeight <= 0)
      [pool, totalWeight] = WheelMath.FullPool(GameConfig.Wheel.Rewards);
    const roll = random.NextNumber(0, totalWeight);
    const selectedEntry = WheelMath.PickEntry(pool, totalWeight, roll);
    if (selectedEntry === undefined)
      return $tuple(false, "The wheel has no prizes configured.");
    const selectedIndex = selectedEntry.Index;
    const selected = selectedEntry.Prize;
    const selectedRank = WheelMath.RarityRank(selected.Rarity);
    const pityHit = forcePity;
    wheel.PityMisses = WheelMath.NextPityMisses(
      wheel.PityMisses,
      selectedRank,
      floorRank,
    );
    if (freeSpins > 0) wheel.FreeSpins = freeSpins - 1;
    else wheel.LastSpinAt = now;
    wheel.Spins += 1;
    const rewardText = ProgressionService.ApplyReward(
      profile,
      selected.Reward,
      Economy.Production(profile),
    );
    let label = selected.Name + ": " + rewardText;
    if (pityHit) label += " (guaranteed)";
    ensureWheel(profile).LastReceipt = {
      ExpectedSpin: sequence,
      PrizeIndex: selectedIndex,
      PrizeId: selected.Id,
      Message: label,
      Pity: pityHit,
    };
    WheelMath.RecordHistory(
      ensureWheel(profile),
      selected.Id,
      os.time(),
      pityHit,
    );
    return $tuple(true, label, selectedIndex, selected.Id, pityHit);
  },
  EnsureTimedRewards(this: void, profile: Profile): boolean {
    const day = currentDay();
    const timed = ensureTimedRewardsBag(profile);
    if (timed.Day === day) return false;
    profile.TimedRewards = { Day: day, PlaySeconds: 0, Claimed: {} };
    return true;
  },
  TimedRewardState(this: void, profile: Profile) {
    const timed = ensureTimedRewardsBag(profile);
    const dayMatches = timed.Day === currentDay();
    const playSeconds = dayMatches ? timed.PlaySeconds : 0;
    const claimed = dayMatches ? timed.Claimed : {};
    return {
      PlaySeconds: playSeconds,
      Rewards: GameConfig.TimedRewards.map((timedReward, index) => ({
        Index: index + 1,
        Seconds: timedReward.Minutes * 60,
        Reward: copyReward(timedReward.Reward),
        Claimed: claimed[tostring(index + 1)] === true,
      })),
    };
  },
  ClaimTimedReward(this: void, profile: Profile, rawIndex: unknown): Result {
    ProgressionService.EnsureTimedRewards(profile);
    if (!typeIs(rawIndex, "number"))
      return $tuple(false, "That playtime gift does not exist.");
    const index = math.floor(rawIndex);
    const timedReward = GameConfig.TimedRewards[index - 1];
    if (timedReward === undefined)
      return $tuple(false, "That playtime gift does not exist.");
    const timed = ensureTimedRewardsBag(profile);
    const key = tostring(index);
    if (timed.Claimed[key])
      return $tuple(false, "That playtime gift was already claimed today.");
    if (timed.PlaySeconds < timedReward.Minutes * 60)
      return $tuple(false, "Keep playing to unlock that gift.");
    timed.Claimed[key] = true;
    return $tuple(
      true,
      ProgressionService.ApplyReward(
        profile,
        timedReward.Reward,
        Economy.Production(profile),
      ),
    );
  },
};
export = table.freeze(ProgressionService);
