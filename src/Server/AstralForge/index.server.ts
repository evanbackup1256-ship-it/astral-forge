// Server entry: Flamework loads every runtime service under Runtime/ and ignites them.
// Construction runs in OnInit (ordered by loadOrder and injected dependencies), the
// runtime starts in OnStart, and ServerLifecycle flips the wire folder to Ready last.
import { Flamework } from "@flamework/core";

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
