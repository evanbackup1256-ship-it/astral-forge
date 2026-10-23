// Moved out of GameService (todo500). Behaviour, remote names and payloads are unchanged; GameService delegates here.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import type { StoreRow } from "../../Modules/LeaderboardService";
import type { FriendGraph } from "../../Modules/FriendGraph";
import type { PassDef as PurchasePassDef, ReceiptOutcome as PurchaseReceiptOutcome } from "../../Modules/Purchases";
import * as Deps from "../../Modules/GameServiceDeps";
import { Service } from "@flamework/core";
import { ConvergenceService } from "../ConvergenceService";
import { DataService } from "../DataService";
import { AdminService } from "../AdminService";
import { WorldService } from "../WorldService";
import { Security } from "../Security/Security";
import { SessionGate } from "../Security/SessionGate";
import { GameAntiCheat } from "../Security/GameAntiCheat";
import { PlayerAnalytics } from "../PlayerAnalytics";
import { PlayerBadges } from "../PlayerBadges";
import { SpecializationService } from "../SpecializationService";
// GameService: the gameplay hub (remotes, runtime state, every player action).
import { Dict, isTable, num, truthy } from "../LuaInterop";
import { PayloadEvent, ServerEvents, ServerFunctions } from "../../Runtime/ServerNetwork";
import { FluxSurgeService } from "../FluxSurgeService";
import { GuildService } from "./GuildService";
import { RemoteFirewall } from "../Security/RemoteFirewall";
import * as ActionBuckets from "../Security/ActionBuckets";
import * as PayloadShape from "../Security/PayloadShape";
import { Ledger, Report } from "../Security/SecurityLedger";
import * as TradeEngine from "../../Modules/TradeEngine";
import { Roll as crateRoll, RollRecord as CrateRollRecord } from "../../Modules/CrateRng";
import { Ledgers as EconomyLedgers, Snapshot as walletSnapshot } from "../../Modules/EconomyLedger";
import { ServerEventService } from "./ServerEventService";
import CompanionBonds = require("./CompanionBonds");
import ExpeditionBoardService = require("./ExpeditionBoard");
import ForgeProgramsService = require("./ForgePrograms");
import ForgePrograms = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import ExpeditionBoard = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import * as HotFlags from "../Security/HotFlags";
import * as CommunityRewards from "./CommunityRewards";
import { MatterRuntime } from "../MatterRuntime";
import * as PolicyGate from "../PolicyGate";
import * as WeeklyStores from "../WeeklyStores";
import * as LimitedEvents from "../../../../Shared/AstralForge/Shared/LimitedEvents";
import * as WeeklyBoard from "../../../../Shared/AstralForge/Shared/WeeklyBoard";
import * as PlayPolicy from "../../../../Shared/AstralForge/Shared/PlayPolicy";
import * as Constellations from "../../../../Shared/AstralForge/Shared/Constellations";
import * as RelicEngraving from "../../../../Shared/AstralForge/Shared/RelicEngraving";
import * as RelicRecipes from "../../../../Shared/AstralForge/Shared/RelicRecipes";
import * as RelicModel from "../../../../Shared/AstralForge/Shared/RelicModel";
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import * as SeenHints from "../../../../Shared/AstralForge/Shared/SeenHints";
import * as FirstGoals from "../../../../Shared/AstralForge/Shared/FirstGoals";
import * as NavRoutes from "../../../../Shared/AstralForge/Shared/NavRoutes";
import * as K from "../GameKits";
import * as ResetSpec from "../../../../Shared/AstralForge/Shared/ResetSpec";
import * as TradeDomain from "./TradeDomain";
import * as Snapshot from "./Snapshot";
import * as DomainExpansion from "./DomainExpansion";
import * as Rebirth from "./Rebirth";
import { orElse, orEmpty, Players, ReplicatedStorage, RunService, MarketplaceService, HttpService, ServerStorage, Workspace, liveEvent, limitedEventPublic, communityConfig, NO_PENDING_ACTIONS, emptyBonuses, MAX_SAFE_CURRENCY, AUTO_FORGE_INTERVAL, PROFILE_MAINTENANCE_INTERVAL, GUILD_REFRESH_INTERVAL, GLOBAL_LB_PAGE, boardReader, RANK_PING, GUILD_ACTIVITY_MILESTONE_STEP, applySocialBoost, GENERAL_BOARD_STORE_NAMES, generalBoardValue, anomalyChargeByAction, encodeTelemetry, anomalySignalByAction, featureByAction, enforceUnlimitedMoney, itemById, crateById, itemOfferById, storyById, mailById, utcDay, nextUtcMidnight, offerStockMax, inventoryCount, ensureItemShop, ensureStats, bumpStat, grantLitRigs, ensureActiveBoost, ensureBoostInventory, ensureCommandMastery, copyDictionary, responseError, TXN_PRINT_IGNORE, responseSuccess, publicPlayerRecord, buildVisitSnapshot, extractUserId, PRESENCE_PAGES, studioCheck, StoreAccess, resetContext, getOrderedStore, reportLedger, itemSalvageValue, shopShared, spendShopCurrency, ensureAutoSalvage, progressionNumber, clampProgressionNumbers, OVERCHARGE_COMBO_WINDOW, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS, overchargeComboWindow, overchargeComboMultiplier, FULL_SNAPSHOT_EVERY, sameValue, fingerprint, anomalyCall, rebirthLedger, rebirthRun, softCapCores, stardustBoostPrice, rebirthBase, keepsakeAllowed } from "../GameServiceCore";
import type { Fn, Method, Kit, Svc, Profile, Response, Runtime } from "../GameServiceCore";
import type { GameService } from "../GameService";


export function syncLeaderstats(svc: GameService, player: Player, profile: unknown) {
		if (player.Parent !== Players || !isTable(profile)) {
			return;
		}
		const leaderstats = player.FindFirstChild("leaderstats");
		if (leaderstats) {
			const flux = leaderstats.FindFirstChild("Flux");
			const cores = leaderstats.FindFirstChild("Cores");
			const rebirths = leaderstats.FindFirstChild("Rebirths");
			if (flux && flux.IsA("NumberValue")) {
				flux.Value = math.floor(progressionNumber(profile.Cash));
			}
			if (cores && cores.IsA("NumberValue")) {
				cores.Value = math.floor(progressionNumber(profile.Cores));
			}
			if (rebirths && rebirths.IsA("NumberValue")) {
				rebirths.Value = math.floor(progressionNumber(profile.Rebirths));
			}
		}
		player.SetAttribute(
			"ProductionPerSecond",
			progressionNumber(
				K.Economy.Mul(
					K.Economy.Production(profile),
					(svc._convergence.Multiplier() as number) *
						(svc._events.ProductionMultiplier() as number) *
						(svc._crews.Multiplier(player) as number),
				),
			),
		);
		player.SetAttribute("CurrentZone", profile.CurrentZone as AttributeValue);
		if (K.GameConfig.Operations.TitlesEnabled === false) {
			player.SetAttribute("EquippedTitle", undefined);
			player.SetAttribute("EquippedTitleName", undefined);
			player.SetAttribute("EquippedTitleFx", undefined);
		} else {
			let titleId = "Cadet";
			const commandState = profile.Command as Dict | undefined;
			if (truthy(commandState) && typeIs(commandState.EquippedTitle, "string") && commandState.EquippedTitle !== "") {
				titleId = commandState.EquippedTitle;
			}
			let titleName: unknown = "Forge Cadet";
			let titleFx = "";
			for (const [, title] of pairs(K.GameConfig.Operations.Titles as Dict[])) {
				if (title.Id === titleId) {
					titleName = title.Name;
					titleFx = typeIs(title.Fx, "string") ? title.Fx : "";
					break;
				}
			}
			player.SetAttribute("EquippedTitle", titleId);
			player.SetAttribute("EquippedTitleName", titleName as AttributeValue);
			player.SetAttribute("EquippedTitleFx", titleFx);
		}
		// profile style is public too: nameplates, the player list and chat tint by it
		const profileStyle = ProfileStyle.read(profile.Cosmetics);
		player.SetAttribute("ProfileAccent", profileStyle.Accent);
		player.SetAttribute("ProfileFrame", profileStyle.Frame);
		// the equipped artifact is public: every client reads these for the overhead aura, the
		// player list and chat, so it has to be visible to the whole server, not just its owner
		const command = profile.Command as Dict | undefined;
		const artifactId =
			truthy(command) && typeIs(command.EquippedArtifact, "string") && truthy(command.EquippedArtifact) ? command.EquippedArtifact : "";
		const artifactFound = artifactId !== "" ? K.Economy.GetArtifact(artifactId) : undefined;
		const artifact = truthy(artifactFound) ? (artifactFound as Dict) : undefined;
		const artifacts = command ? command.Artifacts : undefined;
		const ownedFound = artifact && isTable(artifacts) ? artifacts[artifactId] : undefined;
		const owned = truthy(ownedFound) ? ownedFound : undefined;
		if (artifact && isTable(owned)) {
			const level = math.max(1, math.floor(num(owned.Level) ?? 1));
			const power = (num(artifact.EffectPerLevel) ?? 0) * level;
			const effectText =
				artifact.EffectKind === "OfflineHours"
					? "+%.1fh offline".format(power)
					: "+%.0f%% %s".format(power * 100, tostring(artifact.EffectKind).lower());
			player.SetAttribute("EquippedArtifactName", tostring(artifact.Name));
			player.SetAttribute("EquippedArtifactElement", tostring(orElse(artifact.Element, () => "")));
			player.SetAttribute("EquippedArtifactRarity", tostring(orElse(artifact.Rarity, () => "COMMON")));
			player.SetAttribute("EquippedArtifactLevel", level);
			player.SetAttribute("EquippedArtifactColor", typeIs(artifact.Color, "Color3") ? artifact.Color : Color3.fromRGB(170, 139, 255));
			player.SetAttribute("EquippedArtifactEffect", effectText);
			player.SetAttribute("EquippedArtifact", artifactId);
		} else if (player.GetAttribute("EquippedArtifact") !== undefined) {
			for (const key of [
				"EquippedArtifact",
				"EquippedArtifactName",
				"EquippedArtifactElement",
				"EquippedArtifactRarity",
				"EquippedArtifactLevel",
				"EquippedArtifactColor",
				"EquippedArtifactEffect",
			]) {
				player.SetAttribute(key, undefined);
			}
		}
		// the companion is public too, so the player list can show who brought what
		const companion = CompanionRelic.describe(profile.Items);
		const companionName = companion !== undefined ? companion.Name : undefined;
		if (player.GetAttribute("Companion") !== companionName) {
			player.SetAttribute("Companion", companionName);
		}
		const companionRank = companion !== undefined && companion.Rank > 1 ? companion.Rank : undefined;
		if (player.GetAttribute("CompanionRank") !== companionRank) {
			player.SetAttribute("CompanionRank", companionRank);
		}
}
