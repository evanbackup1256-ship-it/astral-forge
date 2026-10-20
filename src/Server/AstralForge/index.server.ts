// Server entry: Flamework loads every runtime service under Runtime/ and ignites them.
// Construction runs in OnInit (ordered by loadOrder and injected dependencies), the
// runtime starts in OnStart, and ServerLifecycle flips the wire folder to Ready last.
import { Flamework } from "@flamework/core";
// Injected services live outside Runtime/ and are only referenced as constructor types,
// which roblox-ts elides, so load them here before ignite registers the graph.
import "./Services/AdminService";
import "./Services/ConvergenceService";
import "./Services/DataService";
import "./Services/FluxSurgeService";
import "./Services/GameService";
import "./Services/MatterRuntime";
import "./Services/PlayerAnalytics";
import "./Services/PlayerBadges";
import "./Services/ServerTelemetry";
import "./Services/SpecializationService";
import "./Services/WorldService";
import "./Services/Gameplay/GuildService";
import "./Services/Gameplay/ServerEventService";
import "./Services/Security/GameAntiCheat";
import "./Services/Security/RemoteFirewall";
import "./Services/Security/Security";
import "./Services/Security/SessionGate";

const Players = game.GetService("Players");
const TextChatService = game.GetService("TextChatService");

Players.CharacterAutoLoads = false;
pcall(() => {
	(TextChatService as unknown as { ChatVersion: Enum.ChatVersion }).ChatVersion = Enum.ChatVersion.TextChatService;
});
pcall(() => {
	(TextChatService as unknown as { CreateDefaultTextChannels: boolean }).CreateDefaultTextChannels = true;
});

Flamework.addPaths("src/Server/AstralForge/Runtime");
Flamework.ignite();
