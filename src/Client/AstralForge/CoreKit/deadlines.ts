const Workspace = game.GetService("Workspace");

export function unixNow(): number {
	return Workspace.GetServerTimeNow();
}
