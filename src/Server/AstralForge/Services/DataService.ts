import {
	d,
	Dict,
	economyKit,
	LoadService,
	ModuleLogApi,
	num,
	req,
	sharedDataKit,
	SharedFolder,
	tradeSuiteKit,
	truthy,
} from "./LuaInterop";
import AscensionMath from "../../../Shared/AstralForge/Shared/AscensionMath";
import BazaarMath from "../Modules/BazaarMath";
import CommandMath from "../Modules/CommandMath";
import DataSanitizeMath from "../Modules/DataSanitizeMath";
import DataTemplate from "../DataTemplate";
import Documents from "../Modules/Documents";
import DomainLattice from "../../../Shared/AstralForge/Shared/DomainLattice";
import EchoMath from "../../../Shared/AstralForge/Shared/EchoMath";
import FoundryService from "../Modules/FoundryService";
import LabOrderMath from "../Modules/LabOrderMath";
import LeaderboardCodec from "../Modules/LeaderboardCodec";
import OmegaMath from "../../../Shared/AstralForge/Shared/OmegaMath";
import OreMath from "../Modules/OreMath";
import ProfileBagMath from "../Modules/ProfileBagMath";
import ProfileVersionGuard from "../Modules/ProfileVersionGuard";
import RebirthMath from "../../../Shared/AstralForge/Shared/RebirthMath";
import ReceiptLedger from "../Modules/ReceiptLedger";
import ServerConfig from "../ServerConfig";
import SessionDocument from "../Modules/Documents/DocumentKit/SessionDocument";
import SessionDocumentStore from "../Modules/Documents/DocumentKit/SessionDocumentStore";
import Specializations from "../../../Shared/AstralForge/Shared/Specializations";
import StoreAccess from "../Modules/StoreAccess";
import TradeHistory from "../../../Shared/AstralForge/Shared/TradeHistory";
import UnlockedDocumentStore from "../Modules/Documents/DocumentKit/UnlockedDocumentStore";
import type Types = require("../Modules/Documents/DocumentService/Types");

interface GameConfigShape {
	Game: { DataVersion: number; LiveOpsManifestVersion: unknown };
	Machines: Dict[];
	Research: Dict[];
	GridUpgrades: Dict[];
	Operations: {
		Artifacts: Dict[];
		Expeditions: Dict[];
		Crew: Record<string, Dict>;
		SeasonId: string;
	};
	Items: {
		Definitions: Dict[];
		Crates: Dict[];
		Rarities: Record<string, unknown>;
		InventoryLimit: number;
		MaxStars?: number;
	};
	Anomalies: {
		Protocols: Dict[];
		Types: Dict[];
		Directives: Dict[];
		Milestones: Record<number, unknown>;
		Channels: Record<string, unknown>;
		LoadoutSlots: number;
	};
	Lab: {
		Orders: Dict[];
		OrderCount: number;
		Power: { BaseCells: number; RebirthsPerCell: number; MaxCells: number };
	};
	Story: Dict[];
	Mail: Dict[];
	Boosts: Record<string, unknown>;
	Social: {
		MaxBoostedFriends: number;
		FriendProductionPerPlayer: number;
		PremiumProductionBonus: number;
	};
	Continuum: { MaxRank: number };
	MaxZone: number;
	ForgePath?: { StepCount?: number; Steps?: unknown[] };
	Ore: Parameters<typeof OreMath.SanitizeBalances>[1];
}

interface Atom {
	Read(): LuaTuple<[Dict, number]>;
	IsBusy(): boolean;
	Transact(
		callback: (this: void, draft: Dict, revision: number) => unknown,
		incrementRevision?: boolean,
	): LuaTuple<[boolean, unknown, number]>;
	Replace(value: unknown, revision?: number): boolean;
}

interface AtomicStateApi {
	new: (this: void, initial: unknown) => Atom;
}

interface ProfileIntegrityApi {
	EnsureEnvelope(this: void, profile: Dict): Dict;
	Seal(this: void, profile: Dict): string;
	Record(this: void, profile: Dict, label: string, revision?: number): unknown;
	VerifyAndRecover(this: void, profile: Dict): LuaTuple<[boolean, string]>;
	Status(
		this: void,
		profile: Dict,
	): {
		Algorithm: unknown;
		Hash: unknown;
		SealedRevision: unknown;
		SealedAt: unknown;
		JournalDepth: number;
	};
}

interface ServerTelemetryApi {
	RecordPlayerJoined(this: void, userId: number): void;
	RecordPlayerLeft(this: void, userId: number): void;
	Observe(this: void, name: string, seconds: number, succeeded: boolean): void;
}

interface OrderedStoreLike {
	SetAsync(key: string, value: unknown): unknown;
}

interface IntegrityStatus {
	Healthy: boolean;
	Message: unknown;
	CheckedAt: number;
}

export = (loadService: LoadService) => {
	const DataStoreService = game.GetService("DataStoreService");
	const RunService = game.GetService("RunService");

	const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));
	const GameConfig = req<GameConfigShape>(SharedFolder().WaitForChild("GameConfig"));
	const Omega = OmegaMath as unknown as { Max(this: void, a: unknown, b: unknown): unknown };
	const WheelMath = economyKit("WheelMath") as { Ensure(this: void, bag: unknown): unknown };
	const ShopCatalog = sharedDataKit("ShopCatalog") as { skin(this: void, id: string): unknown };
	const TradeRecovery = tradeSuiteKit("TradeRecovery") as {
		RecoverFaulted(this: void, profile: Dict, now: number, warn: (this: void, message: string) => void): void;
	};
	const AtomicState = loadService("AtomicState") as AtomicStateApi;
	const ProfileIntegrity = loadService("ProfileIntegrity") as ProfileIntegrityApi;
	const ServerTelemetry = loadService("ServerTelemetry") as ServerTelemetryApi;
	const DocumentCommon = Documents.DocumentCommon;

	const CACHE_SYNC_INTERVAL = 1.5;
	const SHUTDOWN_SAVE_BUDGET = 5; // Leave BindToClose time for the stores' final document cleanup.

	const MAX_PERSISTED_NUMBER = DataSanitizeMath.MAX_PERSISTED_NUMBER;

	const machineById: Record<string, Dict> = {};
	const researchById: Record<string, Dict> = {};
	const gridById: Record<string, Dict> = {};
	const artifactById: Record<string, Dict> = {};
	const expeditionById: Record<string, Dict> = {};
	const itemById: Record<string, Dict> = {};
	const crateById: Record<string, Dict> = {};
	const anomalyProtocolById: Record<string, Dict> = {};
	const anomalyTypeById: Record<string, Dict> = {};
	const anomalyDirectiveById: Record<string, Dict> = {};
	const labOrderById: Record<string, Dict> = {};
	const storyById: Record<string, Dict> = {};
	const mailById: Record<string, Dict> = {};
	for (const item of GameConfig.Machines) {
		machineById[item.Id as string] = item;
	}
	for (const item of GameConfig.Research) {
		researchById[item.Id as string] = item;
	}
	for (const item of GameConfig.GridUpgrades) {
		gridById[item.Id as string] = item;
	}
	for (const item of GameConfig.Operations.Artifacts) {
		artifactById[item.Id as string] = item;
	}
	for (const item of GameConfig.Operations.Expeditions) {
		expeditionById[item.Id as string] = item;
	}
	for (const item of GameConfig.Items.Definitions) {
		itemById[item.Id as string] = item;
	}
	for (const crate of GameConfig.Items.Crates) {
		crateById[crate.Id as string] = crate;
	}
	for (const protocol of GameConfig.Anomalies.Protocols) {
		anomalyProtocolById[protocol.Id as string] = protocol;
	}
	for (const anomaly of GameConfig.Anomalies.Types) {
		anomalyTypeById[anomaly.Id as string] = anomaly;
	}
	for (const directive of GameConfig.Anomalies.Directives) {
		anomalyDirectiveById[directive.Id as string] = directive;
	}
	for (const order of GameConfig.Lab.Orders) {
		labOrderById[order.Id as string] = order;
	}
	for (const chapter of GameConfig.Story) {
		storyById[chapter.Id as string] = chapter;
	}
	for (const message of GameConfig.Mail) {
		mailById[message.Id as string] = message;
	}

	function deepCopy(value: unknown): unknown {
		return DataSanitizeMath.DeepCopy(value);
	}

	function reconcile(target: unknown, template: unknown): unknown {
		return DataSanitizeMath.Reconcile(target, template);
	}

	function nonNegative(value: unknown): number {
		return DataSanitizeMath.NonNegative(value, MAX_PERSISTED_NUMBER);
	}

	function sanitize(profile: Dict): Dict {
		const previousDataVersion = math.floor(nonNegative(profile.DataVersion));
		profile.DataVersion = GameConfig.Game.DataVersion;
		profile.Cores = math.clamp(nonNegative(profile.Cores), 0, 1e14);
		profile.Stardust = math.clamp(nonNegative(profile.Stardust), 0, 1e14);
		profile.Rebirths = math.min(10_000_000, math.floor(nonNegative(profile.Rebirths)));
		profile.Zone = math.max(1, math.floor(nonNegative(profile.Zone)));
		profile.CurrentZone = math.max(1, math.floor(nonNegative(profile.CurrentZone)));
		for (const key of ["Cash", "Vault", "RunCash", "LifetimeCash"]) {
			profile[key] = Omega.Max(profile[key], 0);
		}
		if (typeIs(profile.Receipts, "table")) {
			ReceiptLedger.Prune(profile.Receipts);
		}
		profile.Ore = OreMath.SanitizeBalances(profile.Ore, GameConfig.Ore);
		profile.OreUpgrades = OreMath.SanitizeLevels(profile.OreUpgrades, GameConfig.Ore);
		ProfileBagMath.EnsureDomain(profile);
		const domain = d(profile.Domain);
		domain.SkillPoints = math.floor(nonNegative(domain.SkillPoints));
		domain.Rank = math.floor(nonNegative(domain.Rank));
		domain.Essence = math.min(1_000_000, math.floor(nonNegative(num(domain.Essence) ?? 0)));
		domain.LastExpandedAt = math.floor(nonNegative(domain.LastExpandedAt));
		domain.TotalRebirthsSpent = math.floor(nonNegative(domain.TotalRebirthsSpent));
		domain.TotalCoresSpent = math.floor(nonNegative(domain.TotalCoresSpent));
		// the node tree became the lattice: whatever was spent on nodes comes back as points
		if (typeIs(domain.Nodes, "table")) {
			domain.SkillPoints = (domain.SkillPoints as number) + DomainLattice.oldTreeRefund(domain.Nodes);
			domain.Nodes = undefined;
		}
		const [links, refund] = DomainLattice.sanitize(domain.Links);
		domain.Links = links;
		domain.SkillPoints = (domain.SkillPoints as number) + refund;
		domain.LatticeClearedAtRank = math.floor(nonNegative(domain.LatticeClearedAtRank));
		ProfileBagMath.EnsureContinuum(profile);
		const continuum = d(profile.Continuum);
		continuum.Rank = math.clamp(math.floor(nonNegative(continuum.Rank)), 0, GameConfig.Continuum.MaxRank);
		continuum.TotalFluxSpent = nonNegative(continuum.TotalFluxSpent);
		profile.Ascension = AscensionMath.sanitize(profile.Ascension, OmegaMath);
		continuum.TotalStardustSpent = nonNegative(continuum.TotalStardustSpent);
		// the Star Foundry is always valid after load (first load converts Continuum/Reactor progress)
		FoundryService.Ensure(profile);
		const retired = typeIs(profile.Infinite, "table") ? (profile.Infinite as Dict) : undefined;
		if (retired !== undefined) {
			if (retired.Active === true && typeIs(retired.Legacy, "table")) {
				const legacy = retired.Legacy as Dict;
				profile.Cash = Omega.Max(profile.Cash, nonNegative(legacy.Cash));
				profile.LifetimeCash = Omega.Max(profile.LifetimeCash, nonNegative(legacy.LifetimeCash));
				profile.Cores = math.max(profile.Cores as number, nonNegative(legacy.Cores));
				profile.Stardust = math.max(profile.Stardust as number, nonNegative(legacy.Stardust));
				profile.Rebirths = math.max(profile.Rebirths as number, nonNegative(legacy.Rebirths));
				domain.Rank = math.max(domain.Rank as number, nonNegative(legacy.DomainRank));
				continuum.Rank = math.max(continuum.Rank as number, nonNegative(legacy.ContinuumRank));
				profile.Zone = math.max(nonNegative(profile.Zone), nonNegative(legacy.World), 1);
				profile.CurrentZone = math.clamp(nonNegative(profile.CurrentZone), 1, profile.Zone as number);
			}
			profile.Infinite = undefined;
		}
		if (profile.Dungeons !== undefined) profile.Dungeons = undefined;
		if (profile.Minigames !== undefined) profile.Minigames = undefined;
		if (profile.Encounters !== undefined) profile.Encounters = undefined; // Salvage Runs and Artifact Trials were retired

		domain.Rank = math.floor(nonNegative(domain.Rank));
		continuum.Rank = math.clamp(math.floor(nonNegative(continuum.Rank)), 0, GameConfig.Continuum.MaxRank);
		profile.ForgeEchoes = EchoMath.ensure(profile.ForgeEchoes);
		// the rebirth ledger; a save from before it starts its star count from the rebirths already spent
		profile.Rebirth = RebirthMath.ensure(
			profile.Rebirth,
			os.time(),
			profile.Rebirth === undefined
				? nonNegative(profile.Rebirths) +
						nonNegative(domain.TotalRebirthsSpent) +
						nonNegative(typeIs(profile.Ascension, "table") ? (profile.Ascension as Dict).RebirthsSpent : 0)
				: undefined,
		);
		profile.Zone = math.clamp(math.floor(nonNegative(profile.Zone)), 1, GameConfig.MaxZone);
		profile.CurrentZone = math.clamp(math.floor(nonNegative(profile.CurrentZone)), 1, profile.Zone as number);
		DataSanitizeMath.ClampLevelBag(profile.Machines, machineById, nonNegative);
		profile.AutoForge = DataSanitizeMath.ClampAutoForge(profile.AutoForge, machineById, "StellarCore", nonNegative);
		DataSanitizeMath.ClampLevelBag(profile.Research, researchById, nonNegative);
		DataSanitizeMath.ClampLevelBag(profile.GridUpgrades, gridById, nonNegative);
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId);
		const command = d(profile.Command);
		command.XP = math.floor(nonNegative(command.XP));
		command.Signals = math.floor(nonNegative(command.Signals));
		command.StreakShields = math.floor(nonNegative(command.StreakShields));
		command.ExpeditionsCompleted = math.floor(nonNegative(command.ExpeditionsCompleted));
		command.SeasonXP = math.floor(nonNegative(command.SeasonXP));
		const flags = d(profile.Flags);
		if (flags.InfiniteMoney === true) flags.UnlimitedMoney = true;
		flags.InfiniteMoney = undefined;
		flags.UnlimitedMoney = flags.UnlimitedMoney === true;
		flags.TutorialStep = math.clamp(math.floor(nonNegative(flags.TutorialStep)), 1, 15);
		if (flags.TutorialDone === true) {
			flags.TutorialRewardClaimed = true;
		}
		if (!typeIs(flags.LastSeenVersion, "string")) {
			flags.LastSeenVersion = "";
		}
		if (!typeIs(flags.MobileLayoutSlots, "string") || (flags.MobileLayoutSlots as string).size() > 512) {
			flags.MobileLayoutSlots = "";
		}
		const settings = d(profile.Settings);
		settings.SoundVolume = math.clamp(nonNegative(settings.SoundVolume), 0, 1);
		settings.MusicVolume = math.clamp(nonNegative(settings.MusicVolume !== undefined ? settings.MusicVolume : 1), 0, 1);
		settings.SfxVolume = math.clamp(nonNegative(settings.SfxVolume !== undefined ? settings.SfxVolume : 1), 0, 1);
		settings.EffectsIntensity = math.clamp(nonNegative(settings.EffectsIntensity), 0, 1);
		settings.MotionIntensity = math.clamp(nonNegative(settings.MotionIntensity), 0, 1);
		settings.ViewportSpeed = math.clamp(nonNegative(settings.ViewportSpeed), 0, 1);
		settings.ToastDensity = math.clamp(nonNegative(settings.ToastDensity !== undefined ? settings.ToastDensity : 0.55), 0, 1);
		settings.UiDensity = math.clamp(nonNegative(settings.UiDensity !== undefined ? settings.UiDensity : 0.55), 0, 1);
		const normalizedSettingDefaults: Dict = {
			PerformanceBias: 0.5,
			BackgroundDetail: 0.8,
			ScrollSpeed: 0.65,
			SoundVariation: 0.7,
			ReactorMotion: 0.8,
			OfflineRewardEffects: 1,
			HapticIntensity: 0.65,
			MobileHudScale: 0.5,
			MobileTextScale: 0.5,
			MobileHudOpacity: 0.85,
			MobileQuickScale: 0.5,
			MobileDockScale: 0.5,
			MobileToastScale: 0.5,
			MobileQuickOpacity: 0.9,
			MobileDockOpacity: 0.88,
			MobileToastOpacity: 0.9,
			MobileButtonSpacing: 0.5,
			MobileQuickReverse: 0,
			MobileQuickVisible: 1,
			MobileDockVisible: 1,
			MobileToastVisible: 1,
			MobileQuickX: 0.5,
			MobileQuickY: 0.7,
			MobileDockX: 0.5,
			MobileDockY: 0.92,
			MobileToastX: 0.84,
			MobileToastY: 0.27,
			HighContrast: 0,
			ColorblindMode: 0,
		};
		for (const [key, defaultValue] of pairs(normalizedSettingDefaults)) {
			settings[key] = math.clamp(nonNegative(settings[key] !== undefined ? settings[key] : defaultValue), 0, 1);
		}
		settings.NotifyGuild =
			settings.NotifyGuild === true
				? 1
				: math.clamp(nonNegative(settings.NotifyGuild !== undefined ? settings.NotifyGuild : 0), 0, 1);
		if (!typeIs(profile.LiveOps, "table")) {
			profile.LiveOps = { ManifestVersion: GameConfig.Game.LiveOpsManifestVersion, Convergence: {} };
		}
		const liveOps = d(profile.LiveOps);
		liveOps.ManifestVersion = GameConfig.Game.LiveOpsManifestVersion;
		if (!typeIs(liveOps.Convergence, "table")) liveOps.Convergence = {};
		const convergence = d(liveOps.Convergence);
		convergence.EventId = typeIs(convergence.EventId, "string") ? convergence.EventId : "";
		convergence.Contribution = math.floor(nonNegative(convergence.Contribution));
		convergence.Claimed = typeIs(convergence.Claimed, "table") ? convergence.Claimed : {};
		if (!typeIs(profile.Guild, "table")) {
			profile.Guild = { Id: "", Role: "", JoinedAt: 0, Tag: "" };
		}
		const guild = d(profile.Guild);
		guild.Id = typeIs(guild.Id, "string") ? guild.Id : "";
		guild.Role = typeIs(guild.Role, "string") ? guild.Role : "";
		guild.Tag = typeIs(guild.Tag, "string") ? guild.Tag : "";
		guild.JoinedAt = math.floor(nonNegative(guild.JoinedAt));
		if (!typeIs(profile.GuildBonuses, "table")) {
			profile.GuildBonuses = { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 };
		}
		const guildBonuses = d(profile.GuildBonuses);
		for (const key of ["Production", "Capacity", "Offline", "Automation", "Tap"]) {
			guildBonuses[key] = math.clamp(nonNegative(guildBonuses[key]), 0, 1);
		}
		if (!typeIs(profile.SocialBoost, "table")) {
			profile.SocialBoost = {
				FriendCount: 0,
				FriendLimit: GameConfig.Social.MaxBoostedFriends,
				FriendBonus: 0,
				Premium: false,
				PremiumBonus: 0,
				Multiplier: 1,
			};
		}
		const socialBoost = d(profile.SocialBoost);
		socialBoost.FriendCount = math.clamp(
			math.floor(nonNegative(socialBoost.FriendCount)),
			0,
			GameConfig.Social.MaxBoostedFriends,
		);
		socialBoost.FriendLimit = GameConfig.Social.MaxBoostedFriends;
		socialBoost.FriendBonus = math.clamp(
			nonNegative(socialBoost.FriendBonus),
			0,
			GameConfig.Social.FriendProductionPerPlayer * GameConfig.Social.MaxBoostedFriends,
		);
		socialBoost.Premium = socialBoost.Premium === true;
		socialBoost.PremiumBonus = socialBoost.Premium === true ? GameConfig.Social.PremiumProductionBonus : 0;
		socialBoost.Multiplier = 1 + (socialBoost.FriendBonus as number) + (socialBoost.PremiumBonus as number);
		if (!typeIs(profile.BoostInventory, "table")) {
			profile.BoostInventory = {};
		}
		const boostInventory = d(profile.BoostInventory);
		for (const [boostId] of pairs(boostInventory)) {
			if (!truthy(GameConfig.Boosts[boostId])) {
				boostInventory[boostId] = undefined;
			} else {
				boostInventory[boostId] = math.floor(nonNegative(boostInventory[boostId]));
			}
		}
		for (const [boostId] of pairs(GameConfig.Boosts)) {
			if (boostInventory[boostId] === undefined) {
				boostInventory[boostId] = 0;
			}
		}
		if (!typeIs(profile.ActiveBoost, "table")) {
			profile.ActiveBoost = { Id: "", EndsAt: 0 };
		}
		const activeBoost = d(profile.ActiveBoost);
		if (
			!typeIs(activeBoost.Id, "string") ||
			(activeBoost.Id !== "" && !truthy(GameConfig.Boosts[activeBoost.Id]))
		) {
			activeBoost.Id = "";
			activeBoost.EndsAt = 0;
		} else {
			activeBoost.EndsAt = math.floor(nonNegative(activeBoost.EndsAt));
		}
		if (!typeIs(profile.Trade, "table")) {
			profile.Trade = { Day: -1, Completed: 0, Sent: { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 } };
		}
		const trade = d(profile.Trade);
		if (!typeIs(trade.Sent, "table")) {
			trade.Sent = { Cash: 0, Stardust: 0, Cores: 0, Signals: 0, Essence: 0, Boost: 0, Keys: 0, Items: 0 };
		}
		// Preserve faulted trade journals for recovery; wipe malformed entries.
		if (!typeIs(trade.Journal, "table")) {
			trade.Journal = {};
		}
		if (trade.FaultedJournal !== undefined && !typeIs(trade.FaultedJournal, "table")) {
			trade.FaultedJournal = undefined;
		}
		// completed-trade history: keep only well-formed, bounded entries
		if (trade.History !== undefined) {
			trade.History = TradeHistory.public(trade);
		}
		trade.Day = math.floor(nonNegative(trade.Day));
		trade.Completed = math.floor(nonNegative(trade.Completed));
		if (previousDataVersion < 5) {
			if (settings.SoundEffects === false) {
				settings.SoundVolume = 0;
			}
			if (settings.UIEffects === false) {
				settings.EffectsIntensity = 0;
			}
			if (settings.ReducedMotion === true) {
				settings.MotionIntensity = 0;
			}
		}
		settings.SoundEffects = (settings.SoundVolume as number) > 0.001;
		settings.UIEffects = (settings.EffectsIntensity as number) > 0.001;
		settings.ReducedMotion = (settings.MotionIntensity as number) <= 0.03;
		profile.Bazaar = BazaarMath.Ensure(profile.Bazaar);
		profile.Specialization = Specializations.Sanitize(profile.Specialization);
		if (!typeIs(profile.Wheel, "table")) {
			profile.Wheel = { LastSpinAt: 0, Spins: 0, PityMisses: 0, FreeSpins: 0 };
		}
		const wheel = d(profile.Wheel);
		wheel.LastSpinAt = math.floor(nonNegative(wheel.LastSpinAt));
		wheel.Spins = math.floor(nonNegative(wheel.Spins));
		wheel.PityMisses = math.floor(nonNegative(wheel.PityMisses));
		wheel.FreeSpins = math.floor(nonNegative(wheel.FreeSpins));
		profile.Wheel = WheelMath.Ensure(profile.Wheel);
		ProfileBagMath.EnsureItems(profile);
		const items = d(profile.Items);
		items.NextId = math.max(1, math.floor(nonNegative(items.NextId)));
		items.Essence = math.floor(nonNegative(items.Essence));
		const itemsShop = d(items.Shop);
		itemsShop.Day = math.floor(nonNegative(itemsShop.Day));
		if (!typeIs(itemsShop.Purchased, "table")) {
			itemsShop.Purchased = {};
		}
		if (!typeIs(itemsShop.Stock, "table")) {
			itemsShop.Stock = {};
		}
		const purchasedBag = d(itemsShop.Purchased);
		for (const [offerId, purchased] of pairs(purchasedBag)) {
			if (purchased !== true) {
				purchasedBag[offerId] = undefined;
			}
		}
		const stockBag = d(itemsShop.Stock);
		for (const [offerId, stock] of pairs(stockBag)) {
			if (!typeIs(stock, "number")) {
				stockBag[offerId] = undefined;
			} else {
				stockBag[offerId] = math.floor(nonNegative(stock));
			}
		}
		const itemKeys = d(items.Keys);
		const itemPity = d(items.Pity);
		for (const [crateId] of pairs(crateById)) {
			itemKeys[crateId] = math.floor(nonNegative(itemKeys[crateId]));
			itemPity[crateId] = math.floor(nonNegative(itemPity[crateId]));
		}
		for (const [crateId] of pairs(itemKeys)) {
			if (!truthy(crateById[crateId])) {
				itemKeys[crateId] = undefined;
			}
		}
		for (const [crateId] of pairs(itemPity)) {
			if (!truthy(crateById[crateId])) {
				itemPity[crateId] = undefined;
			}
		}
		const cosmetics = ProfileBagMath.EnsureCosmetics(profile, (id: string) => ShopCatalog.skin(id) !== undefined);
		ProfileBagMath.EnsureDailyShop(profile, undefined, cosmetics.CrateSkins);
		ProfileBagMath.EnsureAutoSalvage(profile);
		const autoSalvage = d(items.AutoSalvage);
		autoSalvage.Enabled = autoSalvage.Enabled === true;
		autoSalvage.KeepNew = autoSalvage.KeepNew !== false;
		autoSalvage.Rarities = typeIs(autoSalvage.Rarities, "table") ? autoSalvage.Rarities : {};
		const autoSalvageRarities = d(autoSalvage.Rarities);
		for (const [rarity] of pairs(autoSalvageRarities)) {
			if (!truthy(GameConfig.Items.Rarities[rarity])) {
				autoSalvageRarities[rarity] = undefined;
			} else {
				autoSalvageRarities[rarity] = autoSalvageRarities[rarity] === true;
			}
		}
		items.Discovered = typeIs(items.Discovered, "table") ? items.Discovered : {};
		const discovered = d(items.Discovered);
		for (const [definitionId] of pairs(discovered)) {
			if (!truthy(itemById[definitionId])) {
				discovered[definitionId] = undefined;
			} else {
				discovered[definitionId] = true;
			}
		}
		const inventory = d(items.Inventory);
		let inventoryCount = 0;
		for (const [uid, instance] of pairs(inventory)) {
			const inst = typeIs(instance, "table") ? (instance as Dict) : undefined;
			const definition = inst !== undefined ? itemById[inst.DefinitionId as string] : undefined;
			if (!typeIs(uid, "string") || definition === undefined || inventoryCount >= GameConfig.Items.InventoryLimit) {
				inventory[uid] = undefined;
			} else {
				inventoryCount += 1;
				discovered[(inst as Dict).DefinitionId as string] = true;
				const item = inst as Dict;
				item.Level = math.clamp(math.floor(nonNegative(item.Level)), 1, definition.MaxLevel as number);
				item.AcquiredAt = math.floor(nonNegative(item.AcquiredAt));
				item.Locked = item.Locked === true;
				const stars = math.clamp(math.floor(nonNegative(item.Stars)), 0, GameConfig.Items.MaxStars ?? 5);
				item.Stars = stars > 0 ? stars : undefined;
			}
		}
		const equippedItems = new Set<string>();
		const equipped = d(items.Equipped);
		for (const [target, uid] of pairs(equipped)) {
			const instance = typeIs(uid, "string") ? inventory[uid] : undefined;
			const definition =
				instance !== undefined && typeIs(instance, "table")
					? itemById[(instance as Dict).DefinitionId as string]
					: undefined;
			let slot: string | undefined;
			let targetId: string | undefined;
			if (typeIs(target, "string")) {
				[slot, targetId] = target.match("^(%a+):([%w_]+)$") as LuaTuple<[string | undefined, string | undefined]>;
			}
			const targetExists =
				(slot === "Machine" && machineById[targetId as string] !== undefined) ||
				(slot === "Research" && researchById[targetId as string] !== undefined);
			const targets = definition !== undefined ? (definition.Targets as unknown[] | undefined) : undefined;
			const targetCompatible =
				definition !== undefined &&
				(!truthy(targets) || (targets as defined[]).indexOf(targetId as defined) !== undefined);
			if (
				definition === undefined ||
				definition.Slot !== slot ||
				!targetExists ||
				!targetCompatible ||
				(typeIs(uid, "string") && equippedItems.has(uid))
			) {
				equipped[target] = undefined;
			} else {
				equippedItems.add(uid as string);
			}
		}
		ProfileBagMath.EnsureAnomaly(profile);
		const anomaly = d(profile.Anomaly);
		if (!typeIs(anomaly.Discoveries, "table")) {
			anomaly.Discoveries = {};
		}
		if (!typeIs(anomaly.MilestoneClaims, "table")) {
			anomaly.MilestoneClaims = {};
		}
		if (!typeIs(anomaly.DirectiveProgress, "table")) {
			anomaly.DirectiveProgress = {};
		}
		if (!typeIs(anomaly.DirectiveClaims, "table")) {
			anomaly.DirectiveClaims = {};
		}
		anomaly.Cycle = math.floor(nonNegative(anomaly.Cycle));
		anomaly.Charge = nonNegative(anomaly.Charge);
		anomaly.Fragments = math.floor(nonNegative(anomaly.Fragments));
		anomaly.Stabilizations = math.floor(nonNegative(anomaly.Stabilizations));
		anomaly.Chain = math.floor(nonNegative(anomaly.Chain));
		anomaly.BestChain = math.floor(nonNegative(anomaly.BestChain));
		anomaly.LastActionAt = math.floor(nonNegative(anomaly.LastActionAt));
		anomaly.SurgeEndsAt = math.floor(nonNegative(anomaly.SurgeEndsAt));
		anomaly.DirectiveCycle = math.floor(nonNegative(anomaly.DirectiveCycle));
		if (!truthy(GameConfig.Anomalies.Channels[anomaly.Channel as string])) {
			anomaly.Channel = "Flux";
		}
		if (!typeIs(anomaly.Loadout, "table")) {
			anomaly.Loadout = {};
		}
		if (
			(anomaly.Loadout as unknown[]).size() === 0 &&
			truthy(GameConfig.Anomalies.Channels[anomaly.Channel as string])
		) {
			anomaly.Loadout = [anomaly.Channel];
		}
		{
			const slots = GameConfig.Anomalies.LoadoutSlots;
			const seen = new Set<string>();
			const sanitizedLoadout: string[] = [];
			for (const channelId of anomaly.Loadout as unknown[]) {
				if (
					typeIs(channelId, "string") &&
					truthy(GameConfig.Anomalies.Channels[channelId]) &&
					!seen.has(channelId) &&
					sanitizedLoadout.size() < slots
				) {
					seen.add(channelId);
					sanitizedLoadout.push(channelId);
				}
			}
			anomaly.Loadout = sanitizedLoadout;
		}
		anomaly.PulseWindowStartedAt = nonNegative(anomaly.PulseWindowStartedAt ?? 0);
		anomaly.Combo = math.floor(nonNegative(anomaly.Combo ?? 0));
		anomaly.BestCombo = math.floor(nonNegative(anomaly.BestCombo ?? 0));
		anomaly.CoreTier = math.floor(nonNegative(anomaly.CoreTier ?? 0));
		anomaly.CoreXP = math.floor(nonNegative(anomaly.CoreXP ?? 0));
		const anomalyProtocols = d(anomaly.Protocols);
		for (const [protocolId, value] of pairs(anomalyProtocols)) {
			const protocol = anomalyProtocolById[protocolId];
			anomalyProtocols[protocolId] =
				protocol !== undefined
					? math.clamp(math.floor(nonNegative(value)), 0, protocol.MaxLevel as number)
					: undefined;
		}
		const anomalyDiscoveries = d(anomaly.Discoveries);
		for (const [anomalyId, value] of pairs(anomalyDiscoveries)) {
			anomalyDiscoveries[anomalyId] =
				anomalyTypeById[anomalyId] !== undefined ? math.floor(nonNegative(value)) : undefined;
		}
		const milestoneClaims = d(anomaly.MilestoneClaims);
		for (const [key, claimed] of pairs(milestoneClaims)) {
			const tier = num(key);
			if (!typeIs(claimed, "boolean") || tier === undefined || !truthy(GameConfig.Anomalies.Milestones[tier])) {
				milestoneClaims[key] = undefined;
			}
		}
		const directiveProgress = d(anomaly.DirectiveProgress);
		for (const [directiveId, value] of pairs(directiveProgress)) {
			directiveProgress[directiveId] =
				anomalyDirectiveById[directiveId] !== undefined ? math.floor(nonNegative(value)) : undefined;
		}
		const directiveClaims = d(anomaly.DirectiveClaims);
		for (const [directiveId, claimed] of pairs(directiveClaims)) {
			if (anomalyDirectiveById[directiveId] === undefined || !typeIs(claimed, "boolean")) {
				directiveClaims[directiveId] = undefined;
			}
		}
		if (!typeIs(profile.Quests, "table")) {
			profile.Quests = { Day: -1, Items: {} };
		}
		const quests = d(profile.Quests);
		if (!typeIs(quests.Items, "table")) {
			quests.Items = {};
		}
		quests.Day = math.floor(nonNegative(quests.Day));
		if (!typeIs(profile.TimedRewards, "table")) {
			profile.TimedRewards = { Day: -1, PlaySeconds: 0, Claimed: {} };
		}
		const timedRewards = d(profile.TimedRewards);
		if (!typeIs(timedRewards.Claimed, "table")) {
			timedRewards.Claimed = {};
		}
		timedRewards.Day = math.floor(nonNegative(timedRewards.Day));
		timedRewards.PlaySeconds = math.floor(nonNegative(timedRewards.PlaySeconds));
		if (!typeIs(profile.ForgePath, "table")) {
			profile.ForgePath = { ClaimedSteps: {}, XP: 0, XPDay: -1, XPEarnedToday: 0 };
		}
		const forgePath = d(profile.ForgePath);
		if (!typeIs(forgePath.ClaimedSteps, "table")) {
			forgePath.ClaimedSteps = {};
		}
		const claimedSteps = d(forgePath.ClaimedSteps);
		const forgePathConfig = GameConfig.ForgePath;
		const forgeStepCount = truthy(forgePathConfig)
			? truthy(forgePathConfig.StepCount)
				? (forgePathConfig.StepCount as number)
				: (forgePathConfig.Steps as unknown[]).size()
			: 0;
		for (const [key, claimed] of pairs(claimedSteps)) {
			const stepIndex = num(key);
			if (
				!typeIs(claimed, "boolean") ||
				claimed !== true ||
				stepIndex === undefined ||
				stepIndex !== math.floor(stepIndex) ||
				stepIndex < 1 ||
				(forgeStepCount > 0 && stepIndex > forgeStepCount)
			) {
				claimedSteps[key] = undefined;
			} else if (typeIs(key, "number")) {
				claimedSteps[key] = undefined;
				claimedSteps[tostring(stepIndex)] = true;
			}
		}
		forgePath.XP = math.floor(nonNegative(forgePath.XP));
		forgePath.XPDay = typeIs(forgePath.XPDay, "number") ? math.floor(forgePath.XPDay) : -1;
		forgePath.XPEarnedToday = math.floor(nonNegative(forgePath.XPEarnedToday));
		if (!typeIs(profile.Progression, "table")) {
			profile.Progression = {
				RewardedLevel: -1,
				HalfwayPaidFor: -1,
				Surge: {
					Multiplier: 1,
					EndsAt: 0,
				},
			};
		} else {
			const progression = d(profile.Progression);
			const rewarded = num(progression.RewardedLevel) ?? -1;
			progression.RewardedLevel = rewarded < 0 ? -1 : math.clamp(math.floor(rewarded), 1, 18);
			const halfway = num(progression.HalfwayPaidFor) ?? -1;
			progression.HalfwayPaidFor = halfway < 0 ? -1 : math.clamp(math.floor(halfway), 1, 18);
			if (!typeIs(progression.Surge, "table")) {
				progression.Surge = { Multiplier: 1, EndsAt: 0 };
			} else {
				const surge = d(progression.Surge);
				surge.Multiplier = math.clamp(num(surge.Multiplier) ?? 1, 1, 1.6);
				surge.EndsAt = math.max(0, math.floor(nonNegative(surge.EndsAt)));
			}
		}
		profile.Lab = LabOrderMath.Ensure(profile.Lab, GameConfig.Lab.Power.BaseCells);
		const lab = profile.Lab as ReturnType<typeof LabOrderMath.Ensure>;
		lab.Day = typeIs(lab.Day, "number") ? math.max(-1, math.floor(lab.Day)) : -1;
		for (const [index, order] of pairs(lab.Orders)) {
			if (
				!typeIs(index, "number") ||
				index !== math.floor(index) ||
				index < 1 ||
				index > GameConfig.Lab.OrderCount ||
				!typeIs(order, "table") ||
				labOrderById[(order as unknown as Dict).Id as string] === undefined
			) {
				lab.Orders[index] = undefined!;
			} else {
				const orderBag = order as { Progress: unknown; Target: unknown; Claimed: unknown };
				orderBag.Progress = nonNegative(num(orderBag.Progress) ?? 0);
				orderBag.Target = math.max(1, nonNegative(num(orderBag.Target) ?? 0));
				orderBag.Claimed = orderBag.Claimed === true;
			}
		}
		const routeTotal = LabOrderMath.TotalCells(
			profile.Rebirths as number,
			GameConfig.Lab.Power.BaseCells,
			GameConfig.Lab.Power.RebirthsPerCell,
			GameConfig.Lab.Power.MaxCells,
		);
		LabOrderMath.NormalizeRouting(lab.Routing, LabOrderMath.CHANNEL_ORDER, routeTotal);
		const story = d(profile.Story);
		for (const collection of [story.Read, story.Claimed]) {
			for (const [id, value] of pairs(collection as Dict)) {
				if (storyById[id] === undefined || !typeIs(value, "boolean")) {
					(collection as Dict)[id] = undefined;
				}
			}
		}
		const mailbox = d(profile.Mailbox);
		for (const collection of [mailbox.Read, mailbox.Claimed, mailbox.Deleted]) {
			for (const [id, value] of pairs(collection as Dict)) {
				if (mailById[id] === undefined || !typeIs(value, "boolean")) {
					(collection as Dict)[id] = undefined;
				}
			}
		}
		const crew = d(command.Crew);
		for (const [role, value] of pairs(crew)) {
			const item = GameConfig.Operations.Crew[role];
			crew[role] =
				item !== undefined
					? math.clamp(math.floor(nonNegative(value)), 1, item.MaxLevel as number)
					: undefined;
		}
		const mastery = d(command.MachineMastery);
		for (const [id, value] of pairs(mastery)) {
			const nextValue = machineById[id] !== undefined ? math.floor(nonNegative(value)) : 0;
			mastery[id] = nextValue > 0 ? nextValue : undefined;
		}
		const artifacts = d(command.Artifacts);
		for (const [id, artifact] of pairs(artifacts)) {
			if (artifactById[id] === undefined || !typeIs(artifact, "table")) {
				artifacts[id] = undefined;
			} else {
				const artifactBag = artifact as Dict;
				artifactBag.Level = math.clamp(math.floor(nonNegative(artifactBag.Level)), 1, 10);
				artifactBag.Fragments = math.floor(nonNegative(artifactBag.Fragments));
			}
		}
		if (artifacts[command.EquippedArtifact as string] === undefined) {
			command.EquippedArtifact = "";
		}
		const active = d(command.ActiveExpedition);
		if (
			!typeIs(active.Id, "string") ||
			(active.Id !== "" && expeditionById[active.Id] === undefined) ||
			!typeIs(active.StartedAt, "number") ||
			!typeIs(active.EndsAt, "number")
		) {
			command.ActiveExpedition = { Id: "", StartedAt: 0, EndsAt: 0 };
		} else {
			active.StartedAt = math.floor(nonNegative(active.StartedAt));
			active.EndsAt = math.max(active.StartedAt as number, math.floor(nonNegative(active.EndsAt)));
		}
		const meta = d(profile.Meta);
		meta.Revision = math.max(0, math.floor(nonNegative(meta.Revision)));
		ProfileIntegrity.EnsureEnvelope(profile);
		DataSanitizeMath.ScrubNonFinite(profile);
		return profile;
	}

	function debugScan(node: unknown, path: string, hits: string[], seen: Set<object>): void {
		if (typeIs(node, "string")) {
			if (utf8.len(node)[0] === undefined) {
				hits.push(`${path} len=${(node as string).size()}`);
			}
			return;
		}
		if (!typeIs(node, "table") || seen.has(node as object)) {
			return;
		}
		seen.add(node as object);
		for (const [k, v] of pairs(node as object)) {
			debugScan(v, `${path}.${tostring(k)}`, hits, seen);
		}
	}

	function migrateLegacyProfile(data: unknown): Dict {
		ProfileVersionGuard.ReadCompatible(data, GameConfig.Game.DataVersion);
		const result = sanitize(reconcile(data, DataTemplate.New()) as Dict);
		const hits: string[] = [];
		debugScan(result, "Data", hits, new Set());
		if (hits.size() > 0) {
			warn(`[MIGRATE-DEBUG] invalid utf8 leaves: ${hits.join(" | ")}`);
		}
		return result;
	}

	const getOrderedStore = StoreAccess.ordered;
	const getDataStore = StoreAccess.data;
	const previewEnabled = StoreAccess.isPreview();

	class DataService {
		_playerStore: SessionDocumentStore;
		_sharedStore: UnlockedDocumentStore;
		_leaderboardStore: OrderedStoreLike;
		_leaderboardStores: Record<string, OrderedStoreLike>;
		_leaderboardMirrors = new Map<number, Dict>();
		_leaderboardPending = new Map<number, Dict>();
		_leaderboardPushBusy = new Map<number, boolean>();
		_leaderboardWorkers = new Map<number, thread>();
		_profiles = new Map<Player, Dict>();
		_documents = new Map<Player, SessionDocument>();
		_dirty = new Map<Player, boolean>();
		_memoryMode = new Map<Player, boolean>();
		_previousLastSeen = new Map<Player, number>();
		_atoms = new Map<Player, Atom>();
		_integrityStatus = new Map<Player, IntegrityStatus>();
		_cacheSyncThreads = new Map<Player, thread>();
		_lastCacheSyncAt = new Map<Player, number>();
		_saveBusy = new Map<Player, boolean>();
		_releasing = new Map<Player, boolean>();
		_broken = new Map<Player, string>();
		_closing = false;
		_autosaveThread: thread | undefined = undefined;
		OnSaveFailed: ((this: void, player: Player, reason: string) => void) | undefined = undefined;

		constructor() {
			if (previewEnabled) {
				ModuleLog.Info("Data", "unpublished Studio preview is using isolated memory stores");
			}

			const dataStore = getDataStore(ServerConfig.DataStoreName);
			const defaultProfile = DataTemplate.New();

			this._playerStore = new SessionDocumentStore({
				dataStore: dataStore as Types.DataStoreInterface,
				check: DocumentCommon.permissiveTableCheck,
				default: defaultProfile,
				migrations: [
					{
						backwardsCompatible: true,
						migrate: migrateLegacyProfile,
					},
				],
				bindToClose: false,
			});

			this._sharedStore = new UnlockedDocumentStore({
				dataStore: getDataStore(ServerConfig.SharedDataStoreName) as Types.DataStoreInterface,
				check: DocumentCommon.permissiveTableCheck,
				default: { Version: 1, Entries: {} },
				migrations: [],
				bindToClose: false,
			});

			this._leaderboardStore = getOrderedStore(ServerConfig.LeaderboardStoreName) as OrderedStoreLike;
			this._leaderboardStores = {
				Flux: this._leaderboardStore,
				Rebirths: getOrderedStore(ServerConfig.RebirthLeaderboardStoreName) as OrderedStoreLike,
				PlayTime: getOrderedStore(ServerConfig.PlayTimeLeaderboardStoreName) as OrderedStoreLike,
				Dust: getOrderedStore(ServerConfig.DustLeaderboardStoreName) as OrderedStoreLike,
				Cores: getOrderedStore(ServerConfig.CoresLeaderboardStoreName) as OrderedStoreLike,
				Domain: getOrderedStore(ServerConfig.DomainLeaderboardStoreName) as OrderedStoreLike,
				Worlds: getOrderedStore(ServerConfig.WorldLeaderboardStoreName) as OrderedStoreLike,
				Crates: getOrderedStore(ServerConfig.CratesLeaderboardStoreName) as OrderedStoreLike,
				Finds: getOrderedStore(ServerConfig.FindsLeaderboardStoreName) as OrderedStoreLike,
				Ore: getOrderedStore(ServerConfig.OreLeaderboardStoreName) as OrderedStoreLike,
				Wardens: getOrderedStore(ServerConfig.WardensLeaderboardStoreName) as OrderedStoreLike,
				Orders: getOrderedStore(ServerConfig.OrdersLeaderboardStoreName) as OrderedStoreLike,
				Stars: getOrderedStore(ServerConfig.StarsLeaderboardStoreName) as OrderedStoreLike,
				Cipher: getOrderedStore(ServerConfig.CipherLeaderboardStoreName) as OrderedStoreLike,
			};
		}

		_key(player: Player): string {
			return string.format("Player_%d", player.UserId);
		}

		_clearPlayer(player: Player) {
			const cacheThread = this._cacheSyncThreads.get(player);
			if (cacheThread !== undefined) task.cancel(cacheThread);
			this._cacheSyncThreads.delete(player);
			this._lastCacheSyncAt.delete(player);
			ServerTelemetry.RecordPlayerLeft(player.UserId);
			this._profiles.delete(player);
			this._documents.delete(player);
			this._atoms.delete(player);
			this._dirty.delete(player);
			this._memoryMode.delete(player);
			this._previousLastSeen.delete(player);
			this._integrityStatus.delete(player);
			this._saveBusy.delete(player);
			this._releasing.delete(player);
			this._broken.delete(player);
		}

		_markProfileBroken(player: Player, reason: string) {
			// A lost session lock makes every further mutation unsafe until the player leaves.
			this._broken.set(player, reason);
			this._releasing.set(player, true);
			const cacheThread = this._cacheSyncThreads.get(player);
			if (cacheThread !== undefined) {
				task.cancel(cacheThread);
				this._cacheSyncThreads.delete(player);
			}
			ModuleLog.Warn("Data", string.format("marking %s profile read-only — %s", player.Name, reason));
			task.defer(() => {
				if (player.Parent !== undefined) {
					player.Kick("Your data session changed servers and was closed safely. Please rejoin.");
				} else {
					this._clearPlayer(player);
				}
			});
		}

		_queueDocumentSync(player: Player) {
			if (this._cacheSyncThreads.get(player) !== undefined) return;
			const elapsed = os.clock() - (this._lastCacheSyncAt.get(player) ?? -math.huge);
			const delaySeconds = math.max(0.05, CACHE_SYNC_INTERVAL - elapsed);
			this._cacheSyncThreads.set(
				player,
				task.delay(delaySeconds, () => {
					this._cacheSyncThreads.delete(player);
					const profile = this._profiles.get(player);
					if (profile === undefined) return;
					const [ok, reason] = pcall(() => {
						const snapshot = sanitize(deepCopy(profile) as Dict);
						ProfileIntegrity.Seal(snapshot);
						this._syncDocumentCache(player, snapshot);
					});
					if (ok) {
						this._lastCacheSyncAt.set(player, os.clock());
					} else {
						ModuleLog.Every(
							"cache-sync:" + tostring(player.UserId),
							5,
							"Data",
							string.format("%s cache sync rejected unsafe profile data — %s", player.Name, tostring(reason)),
						);
					}
				}),
			);
		}

		_syncDocumentCache(player: Player, snapshot: unknown) {
			const document = this._documents.get(player);
			if (document === undefined || !typeIs(snapshot, "table") || this._memoryMode.get(player)) {
				return;
			}
			if (!document.IsOpen() || document.IsClosing()) {
				return;
			}

			document.SetCache(snapshot);
		}

		_pushLeaderboard(player: Player, profile: Dict) {
			if (this._closing) {
				return;
			}
			const userId = player.UserId;
			this._leaderboardPending.set(userId, {
				Flux: profile.LifetimeCash,
				Rebirths: math.max(0, math.floor(num(profile.Rebirths) ?? 0)),
				PlayTime: math.max(0, math.floor(num(typeIs(profile.Stats, "table") ? (profile.Stats as Dict).PlayTime : undefined) ?? 0)),
				Dust: math.max(0, math.floor(num(profile.Stardust) ?? 0)),
				Cores: math.max(0, math.floor(num(profile.Cores) ?? 0)),
				Domain: math.max(0, math.floor(num(typeIs(profile.Domain, "table") ? (profile.Domain as Dict).Rank : undefined) ?? 0)),
				Worlds: math.max(1, math.floor(num(profile.Zone) ?? 1)),
			});
			const stats = (typeIs(profile.Stats, "table") ? profile.Stats : {}) as Dict;
			const stat = (key: string) => math.max(0, math.floor(num(stats[key]) ?? 0));
			const pending = this._leaderboardPending.get(userId) as Dict;
			pending.Crates = stat("CratesOpened");
			pending.Finds = stat("ItemsFound");
			pending.Ore = stat("OreMined");
			pending.Wardens = stat("WardenDefeats");
			pending.Orders = stat("OrdersCompleted");
			const sky = (typeIs(profile.Sky, "table") ? profile.Sky : {}) as Dict;
			const plotted = (
				typeIs(sky.Charts, "table") && typeIs((sky.Charts as Dict).Plotted, "table")
					? (sky.Charts as Dict).Plotted
					: {}
			) as Dict;
			let stars = 0;
			for (const [, count] of pairs(plotted)) {
				stars += math.max(0, math.floor(num(count) ?? 0));
			}
			pending.Stars = stars;
			pending.Cipher = math.max(
				0,
				math.floor(num(typeIs(sky.Cipher, "table") ? (sky.Cipher as Dict).Solves : undefined) ?? 0),
			);
			if (this._leaderboardPushBusy.get(userId)) return;
			this._leaderboardPushBusy.set(userId, true);
			this._leaderboardWorkers.set(
				userId,
				task.defer(() => {
					const mirror = this._leaderboardMirrors.get(userId) ?? {};
					this._leaderboardMirrors.set(userId, mirror);
					const [workerOk, workerErr] = pcall(() => {
						let values: Dict | undefined;
						while ((values = this._leaderboardPending.get(userId)) !== undefined) {
							this._leaderboardPending.delete(userId);
							for (const [id, value] of pairs(values)) {
								const store = this._leaderboardStores[id];
								if (store !== undefined && mirror[id] !== value) {
									const [okWrite, writeErr] = pcall(() =>
										store.SetAsync(tostring(userId), LeaderboardCodec.Encode(value)),
									);
									if (okWrite) {
										mirror[id] = value;
									} else {
										ModuleLog.Every(
											"leaderboard:" + tostring(userId) + ":" + tostring(id),
											30,
											"Data",
											tostring(writeErr),
										);
									}
								}
							}
						}
					});
					this._leaderboardPushBusy.delete(userId);
					this._leaderboardWorkers.delete(userId);
					if (!workerOk) {
						ModuleLog.Warn(
							"Data",
							string.format("leaderboard push crashed for %d — %s", userId, tostring(workerErr)),
						);
					}

					if (this._profiles.get(player) === undefined) {
						this._leaderboardMirrors.delete(userId);
					}
				}),
			);
		}

		GetSharedStore(): UnlockedDocumentStore {
			return this._sharedStore;
		}

		IsClosing(): boolean {
			return this._closing === true;
		}

		Load(player: Player, stealLock?: boolean): LuaTuple<[boolean, string | undefined]> {
			if (this._profiles.get(player) !== undefined) {
				return $tuple(true, undefined);
			}
			if (this._closing) {
				return $tuple(false, "refreshing");
			}
			const loadStartedAt = os.clock();

			const key = this._key(player);
			const now = os.time();
			const [gotDocument, documentOrErr] = pcall(() => this._playerStore.GetDocument(key));
			const document = documentOrErr as SessionDocument;
			if (!gotDocument) {
				const reason = tostring(documentOrErr);
				ModuleLog.Warn("Data", string.format("couldn't reserve %s's save: %s", player.Name, reason));
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
				const [closingAt] = reason.lower().find("closing", 1, true);
				if (this._closing || closingAt !== undefined) {
					return $tuple(false, "refreshing");
				}
				return $tuple(false, "Your save could not be opened safely. Please rejoin in a moment.");
			}

			if (stealLock === true) {
				const [stole, stealErr] = pcall(() => {
					document.Steal();
				});
				if (!stole) {
					ModuleLog.Warn(
						"Data",
						string.format("could not steal %s's session lock — %s", player.Name, tostring(stealErr)),
					);
				}
			}

			const [openCallOk, openResult] = pcall(() => document.Open());
			if (!openCallOk) {
				pcall(() => {
					if (document.IsOpen()) {
						document.Close();
					}
				});
				ModuleLog.Warn("Data", string.format("couldn't open %s's save: %s", player.Name, tostring(openResult)));
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
				const [closingAt] = tostring(openResult).lower().find("closing", 1, true);
				if (this._closing || closingAt !== undefined) {
					return $tuple(false, "refreshing");
				}
				return $tuple(false, "Your save could not be opened safely. Please rejoin in a moment.");
			}

			if (DocumentCommon.isOk(openResult)) {
				const cached = document.GetCache();
				const rejectUnsafeProfile = (reason: string): LuaTuple<[false, string]> => {
					pcall(() => {
						if (document.IsOpen()) document.Close();
					});
					ModuleLog.Error("Data", "profile load rejected", { UserId: player.UserId, Reason: reason });
					ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
					return $tuple(false, "Your save could not be verified safely. Please rejoin or contact support.");
				};

				const [copied, candidate] = pcall(() => deepCopy(cached));
				let integrityOk: boolean | undefined;
				let integrityMessage: string | undefined;
				if (!copied || !typeIs(candidate, "table")) {
					return rejectUnsafeProfile("unreadable profile graph");
				}
				const candidateProfile = candidate as Dict;
				const [versionOk, versionProblem] = pcall(() =>
					ProfileVersionGuard.ReadCompatible(candidateProfile, GameConfig.Game.DataVersion),
				);
				if (!versionOk) {
					return rejectUnsafeProfile(tostring(versionProblem));
				}
				const [verifyCallOk, verified, verifyMessage] = pcall(() =>
					ProfileIntegrity.VerifyAndRecover(candidateProfile),
				);
				if (!verifyCallOk) {
					return rejectUnsafeProfile("unreadable integrity envelope");
				}
				integrityOk = verified === true;
				integrityMessage = verifyMessage;
				const [recoveryHintAt] = tostring(integrityMessage).find("no valid recovery entry", 1, true);
				if (!integrityOk && recoveryHintAt !== undefined) {
					return rejectUnsafeProfile("integrity mismatch without recovery entry");
				}

				const [preparedOk, prepared] = pcall(() => {
					const profile = sanitize(reconcile(candidateProfile, DataTemplate.New()) as Dict);
					ProfileIntegrity.Seal(profile);
					return profile;
				});
				if (!preparedOk) {
					return rejectUnsafeProfile("schema preparation failed: " + tostring(prepared));
				}
				const profile = prepared as Dict;

				// Reconcile any faulted trade journal from a previous interrupted settlement.
				const [recovered, recoveryErr] = pcall(() => {
					TradeRecovery.RecoverFaulted(profile, now, (message: string) => {
						ModuleLog.Warn("Trade", message, { UserId: player.UserId });
					});
				});
				if (!recovered) {
					ModuleLog.Warn(
						"Trade",
						string.format("trade recovery crashed for %s: %s", player.Name, tostring(recoveryErr)),
						{ UserId: player.UserId },
					);
				}

				const metaBag = typeIs(profile.Meta, "table") ? (profile.Meta as Dict) : undefined;
				const previousLastSeen =
					metaBag !== undefined && typeIs(metaBag.LastSeen, "number") ? (metaBag.LastSeen as number) : now;

				const meta = d(profile.Meta);
				meta.SessionJobId = game.JobId;
				meta.LastSeen = now;
				meta.LastSave = now;
				const [cacheReady, cacheProblem] = pcall(() => {
					ProfileIntegrity.Seal(profile);
					document.SetCache(deepCopy(profile));
				});
				if (!cacheReady) {
					pcall(() => {
						if (document.IsOpen()) document.Close();
					});
					ModuleLog.Warn(
						"Data",
						string.format("could not stage %s profile - %s", player.Name, tostring(cacheProblem)),
					);
					ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
					return $tuple(false, "Your save changed while loading. Please rejoin in a moment.");
				}

				this._profiles.set(player, profile);
				this._documents.set(player, document);
				this._atoms.set(player, AtomicState.new(profile));
				this._previousLastSeen.set(player, previousLastSeen);
				this._dirty.set(player, false);
				this._integrityStatus.set(player, {
					Healthy: integrityOk === true,
					Message: integrityMessage,
					CheckedAt: now,
				});
				if (!integrityOk) {
					ModuleLog.Warn("Data", string.format("%s profile integrity: %s", player.Name, integrityMessage));
				}
				ModuleLog.Player(player, "save opened");
				ServerTelemetry.RecordPlayerJoined(player.UserId);
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, true);
				return $tuple(true, undefined);
			}

			const reason = DocumentCommon.reason(openResult) ?? "Unknown";
			if (reason === "SessionLockedError") {
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
				return $tuple(false, "Your data is still active on another server. Please wait a moment and rejoin.");
			}
			if (reason === "BackwardsCompatibilityError") {
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
				return $tuple(false, "You joined an old server that cannot load your save. Please try a newer server.");
			}

			if (RunService.IsStudio() && truthy(ServerConfig.AllowStudioMemoryFallback)) {
				ModuleLog.Info("Data", player.Name + " is using a temporary Studio save");
				const fallback = DataTemplate.New();
				d(fallback.Meta).SessionJobId = game.JobId;
				this._profiles.set(player, fallback);
				this._atoms.set(player, AtomicState.new(fallback));
				const simulatedAway = math.max(120, num(ServerConfig.StudioSimulatedAwaySeconds) ?? 600);
				this._previousLastSeen.set(player, now - simulatedAway);
				this._dirty.set(player, false);
				this._memoryMode.set(player, true);
				ProfileIntegrity.Seal(fallback);
				this._integrityStatus.set(player, {
					Healthy: true,
					Message: "temporary Studio profile",
					CheckedAt: now,
				});
				ServerTelemetry.RecordPlayerJoined(player.UserId);
				ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, true);
				return $tuple(true, undefined);
			}

			ModuleLog.Warn("Data", string.format("could not load %s — %s", player.Name, reason));
			ServerTelemetry.Observe("ProfileLoad", os.clock() - loadStartedAt, false);
			return $tuple(false, "Your save could not be loaded safely. Please rejoin in a moment.");
		}

		Get(player: Player): Dict | undefined {
			return this._profiles.get(player);
		}

		GetRevision(player: Player): number {
			const atom = this._atoms.get(player);
			if (atom === undefined) {
				return 0;
			}
			const [, revision] = atom.Read();
			return revision;
		}

		GetIntegrityStatus(player: Player) {
			const profile = this._profiles.get(player);
			const status = this._integrityStatus.get(player) ?? {
				Healthy: true,
				Message: "pending",
				CheckedAt: 0,
			};
			if (profile === undefined) return status;
			const envelope = ProfileIntegrity.Status(profile);
			return {
				Healthy: status.Healthy,
				Message: status.Message,
				CheckedAt: status.CheckedAt,
				Algorithm: envelope.Algorithm,
				Hash: envelope.Hash,
				SealedRevision: envelope.SealedRevision,
				SealedAt: envelope.SealedAt,
				JournalDepth: envelope.JournalDepth,
			};
		}

		GetPreviousLastSeen(player: Player): number {
			return this._previousLastSeen.get(player) ?? os.time();
		}

		IsBusy(player: Player): boolean {
			const atom = this._atoms.get(player);
			return atom !== undefined && atom.IsBusy();
		}

		AtomicUpdate(
			player: Player,
			callback: (this: void, draft: Dict, revision: number) => unknown,
			incrementRevision?: boolean,
			label?: string,
		): LuaTuple<[boolean, unknown]> {
			let profile = this._profiles.get(player);
			const atom = this._atoms.get(player);
			if (this._releasing.get(player)) {
				return $tuple(false, "Profile session is closing");
			}
			if (profile === undefined || atom === undefined) {
				return $tuple(false, "Profile is not loaded");
			}
			const transactionLabel = label ?? "unnamed";
			const [success, result] = atom.Transact((draft, revision) => {
				if (this._releasing.get(player)) {
					return { ok: false, message: "Profile session is closing" };
				}
				if (draft.Stardust !== undefined && (num(draft.Stardust) ?? 0) > 1e14) {
					draft.Stardust = 1e14;
				}
				if (draft.Cores !== undefined && (num(draft.Cores) ?? 0) > 1e14) {
					draft.Cores = 1e14;
				}
				const callbackResult = callback(draft, revision);
				if (typeIs(callbackResult, "table") && (callbackResult as Dict).ok === false) {
					return callbackResult;
				}
				d(draft.Meta).LastSeen = os.time();

				if (transactionLabel !== "production") {
					sanitize(draft);
					ProfileIntegrity.Record(draft, transactionLabel, revision);
				}
				return callbackResult;
			}, incrementRevision);
			if (!success) {
				ModuleLog.Every(
					"mutation:" + tostring(player.UserId) + ":" + transactionLabel,
					5,
					"Data",
					string.format("%s update '%s' failed — %s", player.Name, label ?? "unnamed", tostring(result)),
				);
				return $tuple(false, result);
			}
			if (typeIs(result, "table") && (result as Dict).ok === false) {
				return $tuple(true, result);
			}
			const [committed] = atom.Read();
			if (committed !== profile) {
				this._profiles.set(player, committed);
				profile = committed;
			}
			this._dirty.set(player, true);
			if (transactionLabel !== "production") this._queueDocumentSync(player);
			return $tuple(true, result);
		}

		Update(
			player: Player,
			callback: (this: void, draft: Dict, revision: number) => unknown,
			incrementRevision?: boolean,
		): LuaTuple<[boolean, unknown]> {
			return this.AtomicUpdate(player, callback, incrementRevision, "legacy");
		}

		MarkDirty(player: Player) {
			const profile = this._profiles.get(player);
			if (profile !== undefined) {
				this._dirty.set(player, true);
				this._queueDocumentSync(player);
			}
		}

		_saveUnlocked(player: Player, releaseSession?: boolean): boolean {
			const saveStartedAt = os.clock();
			const profile = this._profiles.get(player);
			if (profile === undefined) {
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, true);
				return true;
			}
			const cacheThread = this._cacheSyncThreads.get(player);
			if (cacheThread !== undefined) {
				task.cancel(cacheThread);
				this._cacheSyncThreads.delete(player);
			}

			if (this._memoryMode.get(player)) {
				if (releaseSession) {
					this._clearPlayer(player);
				}
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, true);
				return true;
			}

			const document = this._documents.get(player);
			if (document === undefined || !document.IsOpen()) {
				ModuleLog.Warn("Data", string.format("no open document for %s", player.Name));
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false);
				return false;
			}

			const now = os.time();
			const [preparedOk, snapshotOrErr] = pcall(() => {
				const safeSnapshot = sanitize(deepCopy(profile) as Dict);
				d(safeSnapshot.Meta).LastSeen = now;
				d(safeSnapshot.Meta).LastSave = now;
				if (releaseSession) {
					d(safeSnapshot.Meta).SessionJobId = "";
				} else {
					d(safeSnapshot.Meta).SessionJobId = game.JobId;
				}
				ProfileIntegrity.Record(safeSnapshot, releaseSession ? "session-release" : "save", d(safeSnapshot.Meta).Revision as number);
				ProfileIntegrity.Seal(safeSnapshot);
				return safeSnapshot;
			});
			if (!preparedOk) {
				ModuleLog.Warn(
					"Data",
					string.format("save preparation failed for %s — %s", player.Name, tostring(snapshotOrErr)),
				);
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false);
				return false;
			}
			const snapshot = snapshotOrErr as Dict;
			const [cacheOk, cacheError] = pcall(() => document.SetCache(snapshot));
			if (!cacheOk) {
				ModuleLog.Warn(
					"Data",
					string.format("could not stage save for %s - %s", player.Name, tostring(cacheError)),
				);
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false);
				return false;
			}

			let saved = false;
			let lastReason = "Unknown";
			const retryDeadline =
				this._closing && releaseSession === true ? os.clock() + SHUTDOWN_SAVE_BUDGET : math.huge;
			for (const attempt of $range(1, ServerConfig.SaveRetries)) {
				if (os.clock() >= retryDeadline) {
					// Bound shutdown retries so final store cleanup still gets a chance to run.
					lastReason = "ShutdownSaveDeadline";
					break;
				}
				if (releaseSession && !document.IsOpen()) {
					saved = true;
					break;
				}
				const [callOk, result] = pcall(() => {
					if (releaseSession) {
						return document.Close();
					}
					return document.Save();
				});
				if (callOk && DocumentCommon.isOk(result)) {
					saved = true;
					break;
				}
				lastReason = callOk ? DocumentCommon.reason(result) ?? "Unknown" : tostring(result);
				if (lastReason === "SessionLockedError") {
					this._markProfileBroken(player, lastReason);
				}
				ModuleLog.Warn(
					"Data",
					string.format(
						"save attempt %d/%d failed for %s — %s",
						attempt,
						ServerConfig.SaveRetries,
						player.Name,
						lastReason,
					),
				);
				if (lastReason === "SessionLockedError" || (releaseSession && !document.IsOpen())) {
					break;
				}
				if (attempt < ServerConfig.SaveRetries) {
					const retryWait = math.min(attempt, retryDeadline - os.clock());
					if (retryWait > 0) task.wait(retryWait);
				}
			}

			if (!saved && !releaseSession && this.OnSaveFailed !== undefined) {
				pcall(this.OnSaveFailed, player, lastReason);
			}

			if (saved) {
				const current = this._profiles.get(player);
				const currentRevision =
					current !== undefined && truthy(current.Meta) ? num(d(current.Meta).Revision) ?? -1 : -1;
				const snapshotRevision = num(d(snapshot.Meta).Revision) ?? 0;
				if (current === profile && currentRevision === snapshotRevision) {
					d(profile.Meta).LastSave = now;
					d(profile.Meta).LastSeen = now;
					d(profile.Meta).Transactions = deepCopy(d(snapshot.Meta).Transactions);
					d(profile.Meta).Integrity = deepCopy(d(snapshot.Meta).Integrity);
					this._dirty.set(player, false);
				} else {
					this._dirty.set(player, true);
				}
				this._pushLeaderboard(player, current ?? profile);
			}

			if (releaseSession && !saved) {
				this._dirty.set(player, true);
				ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, false);
				return false;
			}

			if (releaseSession) {
				this._clearPlayer(player);
				if (saved) {
					ModuleLog.Player(player, "save released");
				}
			} else if (saved) {
				d(profile.Meta).LastSave = now;
			}
			ServerTelemetry.Observe("ProfileSave", os.clock() - saveStartedAt, saved);
			return saved;
		}

		Save(player: Player, releaseSession?: boolean): boolean {
			if (releaseSession) this._releasing.set(player, true);
			const releaseWait = this._closing && releaseSession === true ? SHUTDOWN_SAVE_BUDGET : 12;
			const deadline = os.clock() + (releaseSession ? releaseWait : 6);
			while (this._saveBusy.get(player) && os.clock() < deadline) task.wait();
			if (this._saveBusy.get(player)) {
				if (releaseSession && this._broken.get(player) === undefined) this._releasing.delete(player);
				ModuleLog.Every(
					"save-busy:" + tostring(player.UserId),
					5,
					"Data",
					player.Name + " save is still in progress",
				);
				return false;
			}
			const atom = this._atoms.get(player);
			while (releaseSession && atom !== undefined && atom.IsBusy() && os.clock() < deadline) task.wait();
			if (releaseSession && atom !== undefined && atom.IsBusy()) {
				if (this._broken.get(player) === undefined) this._releasing.delete(player);
				ModuleLog.Every(
					"release-busy:" + tostring(player.UserId),
					5,
					"Data",
					player.Name + " mutation did not settle before release",
				);
				return false;
			}
			this._saveBusy.set(player, true);
			const [ok, saved] = pcall(() => this._saveUnlocked(player, releaseSession));
			this._saveBusy.delete(player);
			if (!ok) {
				if (releaseSession && this._broken.get(player) === undefined) this._releasing.delete(player);
				ModuleLog.Warn("Data", string.format("save crashed safely for %s - %s", player.Name, tostring(saved)));
				return false;
			}
			if (releaseSession && saved !== true && this._broken.get(player) === undefined) {
				this._releasing.delete(player);
			}
			return saved === true;
		}

		SaveAll(releaseSessions?: boolean): boolean {
			const players: Player[] = [];
			for (const [player] of this._profiles) {
				players.push(player);
			}
			if (players.size() === 0) {
				return true;
			}

			if (releaseSessions) {
				let remaining = players.size();
				for (const player of players) {
					const target = player;
					task.spawn(() => {
						const [ok, err] = pcall(() => {
							this.Save(target, true);
						});
						if (!ok) {
							ModuleLog.Warn(
								"Data",
								string.format("shutdown save failed for %s — %s", target.Name, tostring(err)),
							);
						}
						remaining -= 1;
					});
				}
				// Match each shutdown save's short budget instead of consuming BindToClose here.
				const deadline = os.clock() + SHUTDOWN_SAVE_BUDGET + 1;
				while (remaining > 0 && os.clock() < deadline) {
					task.wait();
				}
				if (remaining > 0) {
					ModuleLog.Warn(
						"Data",
						string.format("shutdown save deadline reached with %d profile(s) still closing", remaining),
					);
					return false;
				}
				return true;
			}
			for (const player of players) {
				this.Save(player, false);
			}
			return true;
		}

		StartAutosave(interval: number) {
			if (this._autosaveThread !== undefined) {
				return;
			}
			this._autosaveThread = task.spawn(() => {
				while (!this._closing) {
					task.wait(interval);
					for (const [player] of this._profiles) {
						if (this._dirty.get(player)) {
							this.Save(player, false);
						}
					}
				}
			});
		}

		Shutdown() {
			this._closing = true;
			if (this._autosaveThread !== undefined) {
				task.cancel(this._autosaveThread);
				this._autosaveThread = undefined;
			}

			for (const [userId, worker] of this._leaderboardWorkers) {
				pcall(task.cancel, worker);
				this._leaderboardWorkers.delete(userId);
				this._leaderboardPushBusy.delete(userId);
				this._leaderboardPending.delete(userId);
			}
			const [saveOk, saveResult] = pcall(() => this.SaveAll(true));
			if (!saveOk || !saveResult) {
				ModuleLog.Warn("Data", string.format("shutdown SaveAll did not complete — %s", tostring(saveResult)));
			}

			// Always close stores, even when the concurrent release-save phase fails or times out.
			pcall(() => {
				this._playerStore.CloseAllDocuments();
			});
			pcall(() => {
				this._sharedStore.CloseAllDocuments();
			});
		}
	}

	return DataService;
};
