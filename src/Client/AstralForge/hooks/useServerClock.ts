import React from "@rbxts/react";

const Workspace = game.GetService("Workspace");

// server time, refreshed every `interval` seconds while `enabled`; the loop stops on unmount or
// when disabled, so a hidden tab costs nothing
export function useServerClock(enabled = true, interval = 1): number {
	const [now, setNow] = React.useState(Workspace.GetServerTimeNow());
	React.useEffect(() => {
		if (!enabled) {
			return undefined;
		}
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(interval);
				if (!alive) {
					break;
				}
				setNow(Workspace.GetServerTimeNow());
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [enabled, interval]);
	return now;
}
