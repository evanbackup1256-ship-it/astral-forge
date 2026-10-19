// Client copy of the player's crew and any pending invite. CrewService pushes CrewState /
// CrewInvite effects; UiCore writes them here and the Crew page and chat read them.
import React from "@rbxts/react";

interface CrewState {
	crew?: unknown;
	invite?: unknown;
	[key: string]: unknown;
}

type Listener = (state: CrewState) => void;

let state: CrewState = { crew: undefined, invite: undefined };
const listeners = new Set<Listener>();

// passed in a patch to clear a field (nil cannot be stored in a table)
const NONE: unknown = table.freeze({});

const CrewStore = {
	NONE,

	get(this: void): CrewState {
		return state;
	},

	set(this: void, patch: Record<string, unknown>) {
		const nextState = table.clone(state);
		for (const [key, value] of pairs(patch)) {
			nextState[key] = value === NONE ? undefined : value;
		}
		state = nextState;
		for (const listener of listeners) {
			task.spawn(listener, state);
		}
	},

	subscribe(this: void, listener: Listener): () => void {
		listeners.add(listener);
		return () => {
			listeners.delete(listener);
		};
	},

	useCrew(this: void): CrewState {
		const [current, setCurrent] = React.useState(state);
		React.useEffect(() => {
			setCurrent(state);
			return CrewStore.subscribe(setCurrent);
		}, []);
		return current;
	},
};

export = CrewStore;
