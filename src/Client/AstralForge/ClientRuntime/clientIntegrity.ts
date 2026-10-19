import React from "@rbxts/react";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");

const TARGET_SERVICE_NAME = string.char(87, 101, 98, 83, 111, 99, 107, 101, 116, 83, 101, 114, 118, 105, 99, 101);
const PROBE_NAME = string.char(95, 95, 97, 102, 95, 109, 101, 109, 95, 112, 114, 111, 98, 101, 95, 51, 49);
const REPORT_ACTION = string.char(
	82, 101, 112, 111, 114, 116, 67, 108, 105, 101, 110, 116, 73, 110, 116, 101, 103, 114, 105, 116, 121,
);
const ACTION_KEY = string.char(65, 99, 116, 105, 111, 110, 84, 121, 112, 101);
const PENALTY_KEY = string.char(80, 101, 110, 97, 108, 116, 121, 67, 111, 100, 101);
const ACTION_TYPE = string.char(
	77, 69, 77, 79, 82, 89, 95, 73, 78, 84, 69, 71, 82, 73, 84, 89, 95, 86, 73, 79, 76, 65, 84, 73, 79, 78,
);
const PENALTY_CODE = string.char(
	71, 67, 95, 87, 69, 65, 75, 95, 86, 65, 76, 85, 69, 95, 82, 69, 84, 65, 73, 78, 69, 68, 95, 86, 49,
);

type Dispatch = (action: string, payload: Record<string, unknown>) => unknown;
interface ProbeModule {
	Start(callback: (actionType: string, penaltyCode: string) => unknown): void;
	Stop(): void;
}

let running = false;
let generation = 0;
let lastReportAt = -math.huge;
let liveHeartbeat: RBXScriptConnection | undefined;
let liveProbe: Instance | undefined;
let activeWorker: thread | undefined;
let activeProbeModule: ProbeModule | undefined;
let owners = 0;

function disconnectProbe() {
	const connection = liveHeartbeat;
	const probe = liveProbe;
	liveHeartbeat = undefined;
	liveProbe = undefined;
	if (connection !== undefined) {
		connection.Disconnect();
	}
	if (probe !== undefined) {
		pcall(() => {
			probe.Destroy();
		});
	}
}

function releaseSample(connection: RBXScriptConnection | undefined, probe: Instance | undefined) {
	if (connection !== undefined) {
		if (liveHeartbeat === connection) {
			liveHeartbeat = undefined;
		}
		connection.Disconnect();
	}
	if (probe !== undefined) {
		if (liveProbe === probe) {
			liveProbe = undefined;
		}
		pcall(() => {
			probe.Destroy();
		});
	}
}

function waitOneHeartbeat(sessionGeneration: number): boolean {
	const thread = coroutine.running();
	let resumed = false;
	// eslint-disable-next-line prefer-const
	let connection: RBXScriptConnection;
	connection = RunService.Heartbeat.Connect(() => {
		if (liveHeartbeat === connection) {
			liveHeartbeat = undefined;
		}
		connection.Disconnect();
		if (sessionGeneration !== generation || !running) {
			return undefined;
		}
		resumed = true;
		task.defer(thread);
	});
	if (sessionGeneration !== generation || !running) {
		connection.Disconnect();
		return false;
	}
	liveHeartbeat = connection;
	coroutine.yield();
	if (liveHeartbeat === connection) {
		liveHeartbeat = undefined;
		connection.Disconnect();
	}
	return resumed && running && sessionGeneration === generation;
}

function loadInfiniteYieldProbe(): ProbeModule | undefined {
	const [loaded, result] = pcall(() => {
		const astral = ReplicatedStorage.FindFirstChild("AstralForge");
		const shared = astral?.FindFirstChild("Shared");
		if (shared === undefined) {
			return undefined;
		}
		const moduleScript = shared.FindFirstChild("InfiniteYieldProbe");
		if (!moduleScript?.IsA("ModuleScript")) {
			return undefined;
		}
		return require(moduleScript) as ProbeModule;
	});
	return loaded ? (result as ProbeModule | undefined) : undefined;
}

type Sample = "unavailable" | "no_collection" | "retained" | "clear";

function sampleRetention(sessionGeneration: number): Sample {
	const targetService = game.FindService(TARGET_SERVICE_NAME);
	if (targetService === undefined) {
		task.wait(5);
		return "unavailable";
	}
	const trap = setmetatable<{ Control?: object; Probe?: Instance }>({}, { __mode: "v" });
	let control: object | undefined = {};
	let probe: Instance | undefined = new Instance("Folder");
	probe.Name = PROBE_NAME;
	probe.Archivable = false;
	trap.Control = control;
	trap.Probe = probe;
	liveProbe = probe;
	let heartbeatOk = false;
	const [parented] = pcall(() => {
		if (probe === undefined) {
			return undefined;
		}
		probe.Parent = targetService;
		heartbeatOk = waitOneHeartbeat(sessionGeneration);
		if (!heartbeatOk || liveProbe !== probe) {
			return undefined;
		}
		probe.Parent = undefined;
		probe.Destroy();
		if (liveProbe === probe) {
			liveProbe = undefined;
		}
	});
	if (!heartbeatOk || sessionGeneration !== generation || !running) {
		if (sessionGeneration === generation && liveHeartbeat !== undefined) {
			const connection = liveHeartbeat;
			liveHeartbeat = undefined;
			connection.Disconnect();
		}
		releaseSample(undefined, probe);
		if (running && sessionGeneration === generation) {
			task.wait(5);
		}
		return "unavailable";
	}
	if (!parented && probe !== undefined) {
		if (liveProbe === probe) {
			liveProbe = undefined;
		}
		const doomed = probe;
		pcall(() => {
			doomed.Destroy();
		});
	}
	control = undefined;
	probe = undefined;
	task.wait(5);
	if (!parented) {
		return "unavailable";
	}
	if (trap.Control !== undefined) {
		return "no_collection";
	}
	return trap.Probe !== undefined ? "retained" : "clear";
}

function reportExploitToFirewall(dispatch: Dispatch, actionType: string, penaltyCode: string) {
	const now = os.clock();
	if (now - lastReportAt < 30.5) {
		return undefined;
	}
	lastReportAt = now;
	const payload: Record<string, unknown> = {};
	payload[ACTION_KEY] = actionType;
	payload[PENALTY_KEY] = penaltyCode;
	dispatch(REPORT_ACTION, payload);
}

let dispatchSlot: Dispatch | undefined;

function halt(expectedGeneration?: number) {
	if (expectedGeneration !== undefined && expectedGeneration !== generation) {
		return undefined;
	}
	const worker = activeWorker;
	const probeModule = activeProbeModule;
	activeWorker = undefined;
	activeProbeModule = undefined;
	owners = 0;
	generation += 1;
	running = false;
	disconnectProbe();
	if (worker !== undefined) {
		pcall(() => {
			task.cancel(worker);
		});
	}
	if (probeModule !== undefined && activeProbeModule === undefined) {
		pcall(() => {
			probeModule.Stop();
		});
	}
}

function release(expectedGeneration: number) {
	if (expectedGeneration !== generation) {
		return undefined;
	}
	owners -= 1;
	if (owners > 0) {
		return undefined;
	}
	halt(expectedGeneration);
}

function start(dispatch: Dispatch): () => void {
	dispatchSlot = dispatch;
	if (running) {
		owners += 1;
		const seen = generation;
		return () => {
			release(seen);
		};
	}
	owners = 1;
	generation += 1;
	const workerGeneration = generation;
	running = true;
	const infiniteYieldProbe = loadInfiniteYieldProbe();
	activeProbeModule = infiniteYieldProbe;
	if (infiniteYieldProbe !== undefined) {
		infiniteYieldProbe.Start((actionType, penaltyCode) => {
			const current = dispatchSlot;
			if (current !== undefined) {
				return reportExploitToFirewall(current, actionType, penaltyCode);
			}
			return undefined;
		});
	}
	// eslint-disable-next-line prefer-const
	let worker: thread;
	worker = task.spawn(() => {
		let consecutiveRetentions = 0;
		while (running && workerGeneration === generation) {
			const result = sampleRetention(workerGeneration);
			if (workerGeneration !== generation || !running) {
				break;
			}
			if (result === "retained") {
				consecutiveRetentions += 1;
			} else if (result === "clear" || result === "no_collection") {
				consecutiveRetentions = 0;
			}
			if (consecutiveRetentions >= 3) {
				const current = dispatchSlot;
				if (current !== undefined) {
					reportExploitToFirewall(current, ACTION_TYPE, PENALTY_CODE);
				}
				running = false;
				break;
			}
		}
		if (activeWorker === worker) {
			activeWorker = undefined;
		}
	});
	activeWorker = worker;
	return () => {
		release(workerGeneration);
	};
}

function useClientIntegrityProbe(dispatch: Dispatch | undefined) {
	const dispatchRef = React.useRef(dispatch);
	dispatchRef.current = dispatch;
	React.useEffect(() => {
		return start((action, payload) => {
			const current = dispatchRef.current;
			if (current !== undefined) {
				return current(action, payload);
			}
			return undefined;
		});
	}, []);
}

export { reportExploitToFirewall, useClientIntegrityProbe };
