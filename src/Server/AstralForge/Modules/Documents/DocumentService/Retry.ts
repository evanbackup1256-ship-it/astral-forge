function Retry<A extends unknown[]>(
	maxAttempts: number,
	initialWait: number,
	func: (...args: A) => unknown,
	...args: A
): { success: boolean; returnValues: unknown[] } {
	let result: defined[] = [];

	for (let i = 1; i <= maxAttempts; i++) {
		result = [...pcall(func, ...args)] as defined[];

		if (result[0] === true) {
			break;
		}

		warn(`[DocumentService Retry] Attempt ${i} failed: ${result[1]} ${debug.traceback("\nat", 1)}`);

		if (i < maxAttempts) {
			task.wait(initialWait * 2 ** (i - 1));
		}
	}

	const success = result[0] as boolean;
	result.remove(0);

	return {
		success,
		returnValues: result,
	};
}

export = Retry;
