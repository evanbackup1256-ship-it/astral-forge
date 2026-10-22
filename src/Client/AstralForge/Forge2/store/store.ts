// Forge2's one store. Everything the new client shows comes from this single immutable state:
// the server snapshot, the open page, toasts, in-flight actions and the shutdown notice.
// Components read it through useForge(selector); only net.ts and the router write to it.
import React from "@rbxts/react";
import type { Session } from "../../state";

export type Tone = "Info" | "Success" | "Warning" | "Special";

export interface Toast {
	id: number;
	title: string;
	body: string;
	tone: Tone;
	at: number;
}

export interface ForgeState {
	session?: Session;
	revision: number;
	snapshotId: number;
	page: string;
	toasts: ReadonlyArray<Toast>;
	busy: Readonly<Record<string, boolean>>;
	shutdown?: string;
	/** bumps on every server effect push; pages key one-shot visuals off it */
	effectTick: number;
	lastEffect?: Record<string, unknown>;
}

type Listener = (state: ForgeState) => void;

export class ForgeStore {
	private state: ForgeState;
	private listeners = new Set<Listener>();
	private toastId = 0;

	constructor(page = "Overview") {
		this.state = { revision: -1, snapshotId: -1, page, toasts: [], busy: {}, effectTick: 0 };
	}

	get(): ForgeState {
		return this.state;
	}

	update(change: (state: ForgeState) => Partial<ForgeState>) {
		const patch = change(this.state);
		const merged = { ...this.state, ...patch };
		this.state = table.freeze(merged) as ForgeState;
		for (const listener of this.listeners) {
			task.spawn(listener, this.state);
		}
	}

	subscribe(listener: Listener): () => void {
		this.listeners.add(listener);
		return () => this.listeners.delete(listener);
	}

	toast(title: string, body: string, tone: Tone = "Info") {
		this.toastId += 1;
		const entry: Toast = { id: this.toastId, title, body, tone, at: os.clock() };
		this.update((state) => {
			const list = [...state.toasts, entry];
			while (list.size() > 4) list.shift();
			return { toasts: list };
		});
		task.delay(4.5, () => this.update((state) => ({ toasts: state.toasts.filter((t) => t.id !== entry.id) })));
	}
}

export const StoreContext = React.createContext<ForgeStore>(undefined as unknown as ForgeStore);

export function useForgeStore(): ForgeStore {
	return React.useContext(StoreContext);
}

/** Re-renders only when the selected value changes (by ===). */
export function useForge<T>(selector: (state: ForgeState) => T): T {
	const store = useForgeStore();
	const latest = React.useRef(selector);
	latest.current = selector;
	const [value, setValue] = React.useState(() => selector(store.get()));
	React.useEffect(() => {
		setValue(() => latest.current(store.get()));
		return store.subscribe((state) => {
			const picked = latest.current(state);
			setValue((prev) => (prev === picked ? prev : picked));
		});
	}, [store]);
	return value;
}
