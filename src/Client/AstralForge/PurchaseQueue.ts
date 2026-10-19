// Callback transport with a synchronous latch, stale-response guard and cancellation.

interface Order {
	Id: unknown;
	Amount: unknown;
}

interface PurchaseQueueHandle {
	busy: boolean;
	completed: number;
	total: number;
	status: string;
	generation: number;
	cancel(this: void): void;
	start(this: void, action: unknown, orders: Order[]): boolean;
}

export = (
	dispatch: (action: unknown, payload: unknown, reply: (response: unknown) => void) => void,
	schedule: (seconds: number, callback: () => void) => void,
	changed: () => void,
): PurchaseQueueHandle => {
	const Queue = { busy: false, completed: 0, total: 0, status: "", generation: 0 } as PurchaseQueueHandle;
	Queue.cancel = () => {
		Queue.generation += 1;
		Queue.busy = false;
	};
	Queue.start = (action, orders) => {
		if (Queue.busy || orders.size() === 0) {
			return false;
		}
		Queue.generation += 1;
		const generation = Queue.generation;
		Queue.busy = true;
		Queue.completed = 0;
		Queue.total = orders.size();
		const finish = (message: string) => {
			if (generation !== Queue.generation) {
				return;
			}
			Queue.generation += 1;
			Queue.busy = false;
			Queue.status = message;
			changed();
		};
		// index is 1-based, as in the Luau original
		const nextOrder = (index: number) => {
			if (generation !== Queue.generation) {
				return;
			}
			if (index > orders.size()) {
				finish(`Bought ${Queue.completed} upgrades`);
				return;
			}
			Queue.status = `Buying ${index}/${orders.size()}`;
			changed();
			let replied = false;
			// Timeouts release the local latch; an outstanding server request is never retried.
			schedule(12, () => {
				if (!replied && generation === Queue.generation) {
					replied = true;
					finish(`Paused after ${Queue.completed}; refresh before buying again`);
				}
			});
			const order = orders[index - 1];
			const [ok] = pcall(dispatch, action, { Id: order.Id, Amount: order.Amount }, (response: unknown) => {
				if (replied || generation !== Queue.generation) {
					return;
				}
				replied = true;
				if (!typeIs(response, "table") || (response as { ok?: unknown }).ok !== true) {
					finish(`Stopped after ${Queue.completed}; budget or unlock changed`);
					return;
				}
				Queue.completed += 1;
				schedule(0.12, () => nextOrder(index + 1));
			});
			if (!ok) {
				replied = true;
				finish(`Stopped after ${Queue.completed}; connection interrupted`);
			}
		};
		nextOrder(1);
		return true;
	};
	return Queue;
};
