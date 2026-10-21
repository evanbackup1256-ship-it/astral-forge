// The local player's PolicyService answer, asked once per session. The server enforces the same
// rules; this only decides what the Shop and the trade buttons offer. Restrictive until it answers.
import React from "@rbxts/react";
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";

const Players = game.GetService("Players");
const PolicyService = game.GetService("PolicyService");

let current: PlayPolicy.PlayPolicy = PlayPolicy.RESTRICTED;
let started = false;
const listeners = new Set<(policy: PlayPolicy.PlayPolicy) => void>();

function ask(attempt: number) {
	const [ok, info] = pcall(() => PolicyService.GetPolicyInfoForPlayerAsync(Players.LocalPlayer!));
	const policy = PlayPolicy.fromPolicyInfo(ok, info);
	if (!policy.Known) {
		if (attempt < 4) {
			task.delay(15 * attempt, () => ask(attempt + 1));
		}
		return;
	}
	current = policy;
	for (const listener of listeners) {
		task.spawn(listener, policy);
	}
}

export function getPlayPolicy(): PlayPolicy.PlayPolicy {
	if (!started) {
		started = true;
		task.spawn(ask, 1);
	}
	return current;
}

export function usePlayPolicy(): PlayPolicy.PlayPolicy {
	const [policy, setPolicy] = React.useState(getPlayPolicy);
	React.useEffect(() => {
		listeners.add(setPolicy);
		if (current !== policy) {
			setPolicy(current);
		}
		return () => {
			listeners.delete(setPolicy);
		};
	}, []);
	return policy;
}
