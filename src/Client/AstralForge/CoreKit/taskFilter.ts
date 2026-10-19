export interface FilterableTask {
	Claimed: boolean;
	Progress: number;
	Target: number;
}

export type TaskFilter = "All" | "Ready" | "Active" | "Done";

export function taskMatchesFilter(task: FilterableTask, filter: TaskFilter | string): boolean {
	if (filter === "Ready") {
		return !task.Claimed && task.Progress >= task.Target;
	}
	if (filter === "Active") {
		return !task.Claimed && task.Progress < task.Target;
	}
	if (filter === "Done") {
		return task.Claimed;
	}
	return true;
}

export function taskFilterCounts(tasks: ReadonlyArray<FilterableTask>): Record<TaskFilter, number> {
	let ready = 0;
	let active = 0;
	let done = 0;
	for (const task of tasks) {
		if (task.Claimed) {
			done += 1;
		} else if (task.Progress >= task.Target) {
			ready += 1;
		} else {
			active += 1;
		}
	}
	return { All: tasks.size(), Ready: ready, Active: active, Done: done };
}
