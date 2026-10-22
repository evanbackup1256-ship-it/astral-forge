// Boot steps as an explicit dependency graph.
//
// Each step names the steps it needs (`after`). order() returns a run order where every step
// comes after its dependencies; among steps that are ready at the same time the one declared
// first runs first, so the order is stable and readable. Unknown dependencies, duplicate names
// and cycles are errors at boot, not silent reorderings.

export interface BootStep<T = unknown> {
	name: string;
	after: string[];
	run: () => T;
}

export class BootGraph {
	private readonly steps: BootStep[] = [];
	private readonly byName = new Map<string, BootStep>();

	add<T>(name: string, after: string[], run: () => T): this {
		if (this.byName.has(name)) {
			error(`BootGraph: step "${name}" is declared twice`, 2);
		}
		const step: BootStep = { name, after, run };
		this.steps.push(step);
		this.byName.set(name, step);
		return this;
	}

	/** Dependency-respecting order; ties keep declaration order. Errors on unknown deps or cycles. */
	order(): BootStep[] {
		for (const step of this.steps) {
			for (const dependency of step.after) {
				if (!this.byName.has(dependency)) {
					error(`BootGraph: "${step.name}" needs "${dependency}", which is not a step`);
				}
			}
		}
		const done = new Set<string>();
		const ordered: BootStep[] = [];
		while (ordered.size() < this.steps.size()) {
			let progressed = false;
			for (const step of this.steps) {
				if (done.has(step.name)) continue;
				if (step.after.every((dependency) => done.has(dependency))) {
					done.add(step.name);
					ordered.push(step);
					progressed = true;
					break;
				}
			}
			if (!progressed) {
				const stuck = this.steps.filter((step) => !done.has(step.name)).map((step) => step.name);
				error(`BootGraph: cycle among ${stuck.join(", ")}`);
			}
		}
		return ordered;
	}

	names(): string[] {
		return this.order().map((step) => step.name);
	}
}
