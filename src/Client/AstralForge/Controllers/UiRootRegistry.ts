// Tracks the UI root ScreenGuis and tells listeners (the layout guard) when one is added.
import { Controller } from "@flamework/core";
import { ClientLog } from "../CoreKit/log";

export interface UiRootHandle {
	instance: GuiObject;
}

@Controller({ loadOrder: 0 })
export class UiRootRegistry {
	private roots: UiRootHandle[] = [];
	private listeners: Array<(root: UiRootHandle) => unknown> = [];

	add(instance: Instance): UiRootHandle {
		for (const existing of this.roots) {
			if (existing.instance === instance) {
				return existing;
			}
		}
		const handle: UiRootHandle = { instance: instance as GuiObject };
		this.roots.push(handle);
		instance.Destroying.Once(() => {
			const index = this.roots.indexOf(handle);
			if (index !== -1) {
				this.roots.remove(index);
			}
		});
		for (const listener of this.listeners) {
			const [ok, reason] = pcall(listener, handle);
			if (!ok) {
				ClientLog.warn("framework", `ui root listener failed: ${tostring(reason)}`);
			}
		}
		return handle;
	}

	// the layout guard listens for roots through these two
	onComponentAdded(callback: (root: UiRootHandle) => unknown, _id?: string): void {
		this.listeners.push(callback);
	}

	getAllComponents(_id?: string): UiRootHandle[] {
		return [...this.roots];
	}

	primary(): UiRootHandle | undefined {
		for (const root of this.roots) {
			if (root.instance.Parent !== undefined) {
				return root;
			}
		}
		return undefined;
	}
}
