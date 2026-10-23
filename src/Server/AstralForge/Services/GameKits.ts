// GameKits: the module and kit bindings GameService reads, resolved once when GameService loads.
// They live here so GameService's top-level locals stay well under Luau's 200-local limit;
// GameService reads them through one namespace import (K.Economy, K.GameConfig, ...).
import { Dict } from "./LuaInterop";
import BazaarModule = require("./Gameplay/Bazaar");
import AnomalyModule = require("./Gameplay/Anomaly");
import ForgeEchoModule = require("./Gameplay/ForgeEcho");
import LabModule = require("./Gameplay/Lab");
import RelicRigModule = require("./Gameplay/RelicRigs");
import ProgressionModule = require("./Gameplay/Progression");

type Fn = (this: void, ...args: unknown[]) => unknown;
type Kit = Record<string, Fn>;

export interface GameConfigShape {
	Game: Dict;
	Items: Dict;
	Economy: Dict;
	Operations: Dict;
	Overcharge: Dict;
	Social: Dict;
	Continuum: Dict;
	Domain: Dict;
	Boosts: Record<string, unknown>;
	Story: Dict[];
	Mail: Dict[];
	[key: string]: unknown;
}

// Every module GameKits loads, so a typo in a kit name fails at compile time (todo500 #25).
type KitModule =
	| "ModuleLog"
	| "ServerConfig"
	| "AscensionMath"
	| "ChatRules"
	| "CrateConfig"
	| "CrateExpansion"
	| "DomainLattice"
	| "GameConfig"
	| "MobileLayoutSlots"
	| "OmegaMath"
	| "RebirthMath"
	| "Specializations"
	| "TradeHistory"
	| "CommandMath"
	| "CrateRollResolver"
	| "DataSanitizeMath"
	| "EconomyMath"
	| "FoundryService"
	| "LeaderboardCodec"
	| "OpsMath"
	| "ProfileBagMath"
	| "ProfileMath"
	| "TradeSuite"
	| "SharedData"
	| "Protocol"
	| "DesktopLayout"
	| "GuildCommunity"
	| "ChatService"
	| "CrewService";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

export const root = script.Parent!.Parent!;
const modules = () => root.WaitForChild("Modules");
const shared = () => ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const mod = <T = Kit>(parent: Instance, name: KitModule): T => require(parent.WaitForChild(name) as ModuleScript) as T;
const member = <T = Kit>(parent: Instance, name: KitModule, memberName: string): T =>
	(require(parent.WaitForChild(name) as ModuleScript) as (this: void, m: string) => unknown)(memberName) as T;

export const ModuleLog = mod<{
	Info: (this: void, scope: string, message: string, params?: Dict) => void;
	Warn: (this: void, scope: string, message: string, params?: Dict) => void;
	Error: (this: void, scope: string, message: string, params?: Dict) => void;
	Player: (this: void, player: Player, message: string, params?: Dict) => void;
	Every: (this: void, key: string, seconds: number, scope: string, message: string) => boolean;
	[name: string]: unknown;
}>(root, "ModuleLog");
export const Economy = member(modules(), "EconomyMath", "Economy");
export const FoundryService = mod(modules(), "FoundryService");
export const Format = member(modules(), "ProfileMath", "Format");
export const LeaderboardCodec = mod(modules(), "LeaderboardCodec");
export const ProgressionGate = member(modules(), "EconomyMath", "ProgressionGate");
export const SharedDataSuite = mod<(this: void, name: string) => unknown>(shared(), "SharedData");
export const LevelRewards = SharedDataSuite("LevelRewards") as Kit;
export const AscensionMath = mod(shared(), "AscensionMath");
export const RebirthMath = mod(shared(), "RebirthMath");
export const DomainLattice = mod(shared(), "DomainLattice");
export const OmegaMath = mod(shared(), "OmegaMath");
export const ForgeLevels = SharedDataSuite("ForgeLevels") as Kit;
export const RebirthGate = member(modules(), "EconomyMath", "RebirthGate");
export const TradeDesk = member(modules(), "TradeSuite", "TradeDesk");
export const TradeSettle = member(modules(), "TradeSuite", "TradeSettle");
export const TradeChatFilter = member(modules(), "TradeSuite", "TradeChatFilter");
export const TradeRecovery = member(modules(), "TradeSuite", "TradeRecovery");
export const TradeHistory = mod(shared(), "TradeHistory");
export const ChatRules = mod(shared(), "ChatRules");
export const CrateRoll = member(modules(), "EconomyMath", "CrateRoll");
export const CrateRollResolver = mod(modules(), "CrateRollResolver");
export const CrateConfig = mod<Dict>(shared(), "CrateConfig");
export const ShopGrantEligibility = member(modules(), "ProfileMath", "ShopGrantEligibility");
export const CommandActionValidators = member(modules(), "ProfileMath", "CommandActionValidators");
export const SocialBoost = member(modules(), "ProfileMath", "SocialBoost");
export const ItemSalvage = member(modules(), "ProfileMath", "ItemSalvage");
export const VisitSnapshot = member(modules(), "ProfileMath", "VisitSnapshot");
export const PublicPlayerRecord = member(modules(), "ProfileMath", "PublicPlayerRecord");
export const ReportLedger = member(modules(), "ProfileMath", "ReportLedger");
export const SettingsSeal = member(modules(), "ProfileMath", "SettingsSeal");
export const UnlimitedMoneySeal = member(modules(), "ProfileMath", "UnlimitedMoneySeal");
export const StoryMailSnapshot = member(modules(), "ProfileMath", "StoryMailSnapshot");
export const VisitorList = member(modules(), "ProfileMath", "VisitorList");
export const AutoSalvageSnapshot = member(modules(), "ProfileMath", "AutoSalvageSnapshot");
export const OverchargeCombo = member(modules(), "EconomyMath", "OverchargeCombo");
export const RankBracket = member(modules(), "ProfileMath", "RankBracket");
export const ActionFeatureMaps = member<Dict>(modules(), "ProfileMath", "ActionFeatureMaps");
export const ActionResponse = member(modules(), "ProfileMath", "ActionResponse");
export const GeneralBoardValue = member(modules(), "ProfileMath", "GeneralBoardValue");
export const TelemetryMath = member(modules(), "ProfileMath", "TelemetryMath");
export const UtcClockMath = member(modules(), "ProfileMath", "UtcClockMath");
export const DataSanitizeMath = mod(modules(), "DataSanitizeMath");
export const ProfileBagMath = mod(modules(), "ProfileBagMath");
export const ProfileClampMath = member(modules(), "ProfileMath", "ProfileClampMath");
export const CommandMath = mod(modules(), "CommandMath");
export const ContinuumDomainMath = member(modules(), "EconomyMath", "ContinuumDomainMath");
export const ItemLoadoutMath = member(modules(), "ProfileMath", "ItemLoadoutMath");
export const GuildMath = member(modules(), "OpsMath", "GuildMath");
export const ForgePathClaim = member(modules(), "EconomyMath", "ForgePathClaim");
export const OfflineProjection = member(modules(), "EconomyMath", "OfflineProjection");
export const GameConfig = mod<GameConfigShape>(shared(), "GameConfig");
export const Protocol = mod<{ Actions: Record<string, string>; [key: string]: unknown }>(shared(), "Protocol");
export const MonetizationConfig = SharedDataSuite("MonetizationConfig") as Dict;
export const ZoneUnlock = SharedDataSuite("ZoneUnlock") as Kit;
export const MobileLayoutSlots = mod(shared(), "MobileLayoutSlots");
export const DesktopLayout = mod<{ Normalize: (raw: unknown) => string | undefined }>(shared(), "DesktopLayout");
export const CrateExpansion = mod<Kit>(shared(), "CrateExpansion");
export const ProgressionService = ProgressionModule as unknown as Kit;

export const AnomalyService = AnomalyModule as unknown as Kit;
export const LabService = LabModule as unknown as Kit;
export const RelicRigs = RelicRigModule as unknown as Kit;
export const ForgeEchoService = ForgeEchoModule as unknown as Kit;
export const BazaarService = BazaarModule as unknown as Kit;
export const Specializations = mod<Kit>(shared(), "Specializations");
export const GuildCommunity = mod(script.Parent!, "GuildCommunity");
export const ChatService = mod(script.Parent!, "ChatService");
export const CrewService = mod(script.Parent!, "CrewService");
export const ServerConfig = mod<Dict>(root, "ServerConfig");

