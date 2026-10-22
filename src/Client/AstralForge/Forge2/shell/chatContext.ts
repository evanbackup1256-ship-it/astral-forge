// Chat runs at shell level so history and unread counts keep building while the Chat page is
// closed; the Chat page and the nav badges read it from here.
import React from "@rbxts/react";
import type { useGameChat } from "../../ClientRuntime/chat";

export type ShellChat = ReturnType<typeof useGameChat>;

export const ChatContext = React.createContext<ShellChat | undefined>(undefined);

export function useShellChat(): ShellChat | undefined {
	return React.useContext(ChatContext);
}
