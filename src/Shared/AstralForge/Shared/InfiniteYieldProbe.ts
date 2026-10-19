type Reporter = (actionType: string, penaltyCode: string) => void;
type Reader = (level: number) => unknown;

declare const getfenv: Reader;

const Players = game.GetService("Players");
const Workspace = game.GetService("Workspace");

const NATIVE_GETFENV = getfenv;
const SAMPLE_CALLS = 0x80;
const BASELINE_WINDOWS = 0x7;
const TIMING_RATIO_LIMIT = 0x8;
const REQUIRED_TIMING_WINDOWS = 0x4;
const REQUIRED_MOTION_WINDOWS = 0x2;
const REPORT_COOLDOWN_SECONDS = 0x1f;

function bytes(values: number[]): string {
	return string.char(...values);
}

const ENVIRONMENT_HEADER = bytes([
	69, 78, 86, 73, 82, 79, 78, 77, 69, 78, 84, 95, 72, 79, 79, 75, 95, 86, 73, 79, 76, 65, 84, 73, 79, 78,
]);
const ENVIRONMENT_CODE = bytes([71, 69, 84, 70, 69, 78, 86, 95, 84, 73, 77, 73, 78, 71, 95, 80, 82, 79, 88, 89, 95, 86, 49]);
const MOTION_HEADER = bytes([
	80, 72, 89, 83, 73, 67, 83, 95, 73, 78, 84, 69, 71, 82, 73, 84, 89, 95, 86, 73, 79, 76, 65, 84, 73, 79, 78,
]);
const MOTION_CODE = bytes([
	67, 76, 73, 69, 78, 84, 95, 77, 79, 84, 73, 79, 78, 95, 69, 78, 86, 69, 76, 79, 80, 69, 95, 86, 49,
]);

let running = false;
let generation = 0;
let lastReportAt = -math.huge;

function median(samples: number[]): number {
	samples.sort();
	const middle = math.ceil(samples.size() / 2);
	return (samples[middle - 1] as number | undefined) ?? 0;
}

function benchmarkEnvironment(reader: Reader): number {
	let sink: unknown = undefined;
	const startedAt = os.clock();
	for (let i = 1; i <= SAMPLE_CALLS; i++) {
		sink = reader(0);
	}
	const elapsed = os.clock() - startedAt;
	if (sink === undefined) {
		return math.huge;
	}
	return math.max(elapsed, 1e-7);
}

function calibrate(): number {
	const samples: number[] = table.create(BASELINE_WINDOWS);
	for (let i = 1; i <= BASELINE_WINDOWS; i++) {
		samples.push(benchmarkEnvironment(NATIVE_GETFENV));
		task.wait();
	}
	return median(samples);
}

function collisionBaseline(character: Model): Map<BasePart, boolean> {
	const result = new Map<BasePart, boolean>();
	for (const descendant of character.GetDescendants()) {
		if (descendant.IsA("BasePart") && descendant.CanCollide) {
			result.set(descendant, true);
		}
	}
	return result;
}

function hasHighForceMover(root: BasePart): boolean {
	let hasVelocity = false;
	let hasGyro = false;
	for (const child of root.GetChildren()) {
		if (child.IsA("BodyVelocity")) {
			hasVelocity = child.MaxForce.Magnitude >= 1e8;
		} else if (child.IsA("BodyGyro")) {
			hasGyro = child.MaxTorque.Magnitude >= 1e8;
		}
	}
	return hasVelocity && hasGyro;
}

function motionAnomaly(character: Model, baseline: Map<BasePart, boolean>): boolean {
	const root = character.FindFirstChild("HumanoidRootPart");
	const humanoid = character.FindFirstChildOfClass("Humanoid");
	if (!root || !root.IsA("BasePart") || !humanoid || humanoid.Health <= 0) {
		return false;
	}

	const graceUntil = character.GetAttribute("AF_MovementGraceUntil");
	if (typeIs(graceUntil, "number") && Workspace.GetServerTimeNow() < graceUntil) {
		return false;
	}

	const velocity = root.AssemblyLinearVelocity;
	const impossibleVelocity = velocity.Magnitude > 350;
	const forcedPlatformMotion = humanoid.PlatformStand && velocity.Magnitude > 40;
	const suspiciousMover = hasHighForceMover(root);

	let collisionOverrides = 0;
	for (const [part] of baseline) {
		if (part.Parent !== undefined && !part.CanCollide) {
			collisionOverrides += 1;
			if (collisionOverrides >= 2) {
				break;
			}
		}
	}

	return impossibleVelocity || forcedPlatformMotion || suspiciousMover || collisionOverrides >= 2;
}

function report(reporter: Reporter, actionType: string, penaltyCode: string): void {
	const now = os.clock();
	if (now - lastReportAt < REPORT_COOLDOWN_SECONDS) {
		return;
	}
	lastReportAt = now;
	pcall(reporter, actionType, penaltyCode);
}

function Start(reporter: Reporter): void {
	if (running || !typeIs(reporter, "function")) {
		return;
	}
	running = true;
	generation += 1;
	const workerGeneration = generation;

	task.spawn(() => {
		const baselineTiming = calibrate();
		let timingWindows = 0;
		let motionWindows = 0;
		let observedCharacter: Model | undefined = undefined;
		let baselineCollisions = new Map<BasePart, boolean>();

		while (running && workerGeneration === generation) {
			const currentReader: Reader = getfenv;
			const currentTiming = benchmarkEnvironment(currentReader);
			const timingChanged = currentReader !== NATIVE_GETFENV || currentTiming >= baselineTiming * TIMING_RATIO_LIMIT;
			if (timingChanged) {
				timingWindows += 1;
			} else {
				timingWindows = math.max(0, timingWindows - 1);
			}

			const player = Players.LocalPlayer;
			const character = player ? player.Character : undefined;
			if (character !== observedCharacter) {
				observedCharacter = character;
				baselineCollisions = character ? collisionBaseline(character) : new Map<BasePart, boolean>();
				motionWindows = 0;
			}
			if (character && motionAnomaly(character, baselineCollisions)) {
				motionWindows += 1;
			} else {
				motionWindows = math.max(0, motionWindows - 1);
			}

			if (timingWindows >= REQUIRED_TIMING_WINDOWS) {
				report(reporter, ENVIRONMENT_HEADER, ENVIRONMENT_CODE);
				timingWindows = 0;
			} else if (motionWindows >= REQUIRED_MOTION_WINDOWS) {
				report(reporter, MOTION_HEADER, MOTION_CODE);
				motionWindows = 0;
			}

			task.wait(3);
		}
	});
}

function Stop(): void {
	running = false;
	generation += 1;
}

export = table.freeze({ Start, Stop });
