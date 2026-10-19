import React from "@rbxts/react";

const Workspace = game.GetService("Workspace");

export function unixNow(): number {
	return Workspace.GetServerTimeNow();
}

export function useUnixDeadline(deadline: unknown): boolean {
	const [active, setActive] = React.useState(() => typeIs(deadline, "number") && deadline > unixNow());
	React.useEffect(() => {
		if (!typeIs(deadline, "number")) {
			setActive(false);
			return undefined;
		}
		const remaining = deadline - unixNow();
		if (remaining !== remaining || remaining <= 0) {
			setActive(false);
			return undefined;
		}
		setActive(true);
		let alive = true;
		const worker = task.delay(remaining + 0.05, () => {
			if (alive) {
				setActive(false);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [deadline]);
	return active;
}
