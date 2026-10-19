interface Issue {
	Kind: string;
	Path: string;
	Owner: string;
	Detail: string;
	FirstSeen: number;
	LastSeen: number;
	Samples: number;
}

const CAPACITY = 128;
const MAX_PAIR_CHECKS = 256;

function owner(instance: Instance): string {
	let ancestor: Instance | undefined = instance;
	while (ancestor) {
		const found = ancestor.GetAttribute("LayoutOwner");
		if (typeIs(found, "string") && found !== "") {
			return found;
		}
		ancestor = ancestor.Parent;
	}
	return instance.Parent ? instance.Parent.GetFullName() : instance.Name;
}

function visible(instance: GuiObject): boolean {
	let ancestor: Instance | undefined = instance;
	let left = instance.AbsolutePosition.X;
	let top = instance.AbsolutePosition.Y;
	let right = left + instance.AbsoluteSize.X;
	let bottom = top + instance.AbsoluteSize.Y;
	while (ancestor) {
		if (ancestor.GetAttribute("LayoutGuardIgnore") === true) {
			return false;
		}
		if (ancestor.IsA("GuiObject")) {
			if (!ancestor.Visible) {
				return false;
			}
			if (ancestor.ClipsDescendants) {
				const position = ancestor.AbsolutePosition;
				const size = ancestor.AbsoluteSize;
				left = math.max(left, position.X);
				top = math.max(top, position.Y);
				right = math.min(right, position.X + size.X);
				bottom = math.min(bottom, position.Y + size.Y);
			}
		} else if (ancestor.IsA("LayerCollector") && !ancestor.Enabled) {
			return false;
		}
		ancestor = ancestor.Parent;
	}
	return right > left && bottom > top;
}

function canRecover(instance: Instance, kind: string): boolean {
	// Only the owning component can opt a specific element into recovery.
	return instance.GetAttribute("LayoutGuardRecovery") === kind;
}

function create(clock: () => number) {
	const records: Issue[] = [];
	const keys = new Map<string, Issue>();
	let cursor = 1;
	let total = 0;
	let observations = 0;
	let epoch = 0;
	let checks = 0;
	let deadline = 0;

	const object = {
		record(instance: Instance, kind: string, detail: string): boolean {
			const path = instance.GetFullName();
			const key = kind + ":" + path;
			const now = clock();
			observations += 1;
			const existing = keys.get(key);
			if (existing) {
				existing.LastSeen = now;
				existing.Samples += 1;
				existing.Detail = detail;
				existing.Owner = Diagnostics.owner(instance);
				return false;
			}
			const issue: Issue = {
				Kind: kind,
				Path: path,
				Owner: Diagnostics.owner(instance),
				Detail: detail,
				FirstSeen: now,
				LastSeen: now,
				Samples: 1,
			};
			if (records.size() < CAPACITY) {
				records.push(issue);
			} else {
				const previous = records[cursor - 1];
				keys.delete(previous.Kind + ":" + previous.Path);
				records[cursor - 1] = issue;
				cursor = (cursor % CAPACITY) + 1;
			}
			keys.set(key, issue);
			total += 1;
			return true;
		},

		snapshot() {
			const copy: Issue[] = [];
			for (const issue of records) {
				copy.push(table.clone(issue));
			}
			copy.sort((a, b) => a.LastSeen > b.LastSeen);
			return { Epoch: epoch, Total: total, Issues: copy };
		},
		total(): number {
			return total;
		},
		observations(): number {
			return observations;
		},

		reset() {
			table.clear(records);
			keys.clear();
			cursor = 1;
			epoch += 1;
		},

		beginPairs(endAt: number) {
			checks = 0;
			deadline = endAt;
		},

		pairAllowed(): boolean {
			if (checks >= MAX_PAIR_CHECKS || clock() >= deadline) {
				return false;
			}
			checks += 1;
			return true;
		},

		runWork(worker: thread): boolean {
			while (coroutine.status(worker) !== "dead" && this.pairAllowed()) {
				const [ok, reason] = coroutine.resume(worker);
				if (!ok) {
					error(reason, 0);
				}
			}
			return coroutine.status(worker) === "dead";
		},
	};
	return object;
}

const Diagnostics = table.freeze({ owner, visible, canRecover, new: create });

export = Diagnostics;
