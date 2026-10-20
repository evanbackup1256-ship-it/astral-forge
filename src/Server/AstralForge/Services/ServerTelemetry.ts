// Server-wide counters (remotes, sessions, timings, client performance) for the admin dashboard.
// Members are arrow properties so they can be passed around and called without a receiver.
import { Service } from "@flamework/core";
import { Dict, num } from "./LuaInterop";

interface Timing {
	Count: number;
	Failures: number;
	TotalMs: number;
	MaximumMs: number;
	LastMs: number;
}

let startedAt = os.clock();
let remoteAccepted = 0;
let remoteRejected = 0;
let integrityReports = 0;
let logs = { Info: 0, Warning: 0, Debug: 0 };
const rejectionReasons: Record<string, number> = {};
const timings: Record<string, Timing> = {};
const activeSessions: Record<number, number> = {};
let sessionsStarted = 0;
let sessionsEnded = 0;
let totalSessionSeconds = 0;
let clientQuality = {
	Samples: 0,
	TotalFPS: 0,
	TotalP95Ms: 0,
	TotalPingMs: 0,
	TotalBootMs: 0,
	TotalJank: 0,
	WorstP95Ms: 0,
};

function timingFor(name: string): Timing {
	let timing = timings[name];
	if (timing === undefined) {
		timing = { Count: 0, Failures: 0, TotalMs: 0, MaximumMs: 0, LastMs: 0 };
		timings[name] = timing;
	}
	return timing;
}

@Service({ loadOrder: 0 })
export class ServerTelemetry {
	readonly RecordLog = (level: string): void => {
		if (level === "Info") logs.Info += 1;
		else if (level === "Warning") logs.Warning += 1;
		else if (level === "Debug") logs.Debug += 1;
	};

	readonly RecordRemote = (accepted: boolean, reason?: string): void => {
		if (accepted) {
			remoteAccepted += 1;
			return;
		}
		remoteRejected += 1;
		const key = (reason ?? "unspecified").sub(1, 64);
		rejectionReasons[key] = (rejectionReasons[key] ?? 0) + 1;
	};

	readonly RecordIntegrityReport = (): void => {
		integrityReports += 1;
	};

	readonly RecordPlayerJoined = (userId: number): void => {
		if (activeSessions[userId] !== undefined) return;
		activeSessions[userId] = os.clock();
		sessionsStarted += 1;
	};

	readonly RecordPlayerLeft = (userId: number): void => {
		const joinedAt = activeSessions[userId];
		if (joinedAt === undefined) return;
		delete activeSessions[userId];
		sessionsEnded += 1;
		totalSessionSeconds += math.max(0, os.clock() - joinedAt);
	};

	readonly Observe = (name: string, seconds: number, succeeded: boolean): void => {
		const milliseconds = math.max(0, seconds) * 1000;
		const timing = timingFor(name);
		timing.Count += 1;
		if (!succeeded) timing.Failures += 1;
		timing.TotalMs += milliseconds;
		timing.MaximumMs = math.max(timing.MaximumMs, milliseconds);
		timing.LastMs = milliseconds;
	};

	readonly RecordClientPerformance = (sample: unknown): void => {
		const bag = sample as Dict;
		clientQuality.Samples += 1;
		clientQuality.TotalFPS += math.clamp(num(bag.FPS) ?? 0, 0, 360);
		clientQuality.TotalP95Ms += math.clamp(num(bag.P95Ms) ?? 0, 0, 1000);
		clientQuality.TotalPingMs += math.clamp(num(bag.PingMs) ?? 0, 0, 10000);
		clientQuality.TotalBootMs += math.clamp(num(bag.BootMs) ?? 0, 0, 120000);
		clientQuality.TotalJank += math.clamp(num(bag.JankPct) ?? 0, 0, 1);
		clientQuality.WorstP95Ms = math.max(clientQuality.WorstP95Ms, num(bag.P95Ms) ?? 0);
	};

	readonly Snapshot = (): Dict => {
		const reasonList: { Reason: string; Count: number }[] = [];
		for (const [reason, count] of pairs(rejectionReasons)) {
			reasonList.push({ Reason: reason, Count: count });
		}
		reasonList.sort((left, right) =>
			left.Count === right.Count ? left.Reason < right.Reason : left.Count > right.Count,
		);
		while (reasonList.size() > 6) reasonList.pop();

		const timingList: Dict[] = [];
		for (const [name, timing] of pairs(timings)) {
			timingList.push({
				Name: name,
				Count: timing.Count,
				Failures: timing.Failures,
				AverageMs: timing.Count > 0 ? timing.TotalMs / timing.Count : 0,
				MaximumMs: timing.MaximumMs,
				LastMs: timing.LastMs,
			});
		}
		timingList.sort((left, right) => (left.Name as string) < (right.Name as string));

		const total = remoteAccepted + remoteRejected;
		const samples = clientQuality.Samples;
		return {
			UptimeSeconds: math.max(0, os.clock() - startedAt),
			RemoteAccepted: remoteAccepted,
			RemoteRejected: remoteRejected,
			RemoteRejectRate: total > 0 ? remoteRejected / total : 0,
			IntegrityReports: integrityReports,
			SessionsStarted: sessionsStarted,
			SessionsEnded: sessionsEnded,
			ActiveSessions: sessionsStarted - sessionsEnded,
			AverageSessionSeconds: sessionsEnded > 0 ? totalSessionSeconds / sessionsEnded : 0,
			Logs: table.clone(logs),
			TopRejections: reasonList,
			Timings: timingList,
			ClientPerformance: {
				Samples: samples,
				AverageFPS: samples > 0 ? clientQuality.TotalFPS / samples : 0,
				AverageP95Ms: samples > 0 ? clientQuality.TotalP95Ms / samples : 0,
				AveragePingMs: samples > 0 ? clientQuality.TotalPingMs / samples : 0,
				AverageBootMs: samples > 0 ? clientQuality.TotalBootMs / samples : 0,
				AverageJankPct: samples > 0 ? clientQuality.TotalJank / samples : 0,
				WorstP95Ms: clientQuality.WorstP95Ms,
			},
		};
	};

	readonly ResetForTests = (): void => {
		startedAt = os.clock();
		remoteAccepted = 0;
		remoteRejected = 0;
		integrityReports = 0;
		sessionsStarted = 0;
		sessionsEnded = 0;
		totalSessionSeconds = 0;
		logs = { Info: 0, Warning: 0, Debug: 0 };
		table.clear(rejectionReasons);
		table.clear(timings);
		table.clear(activeSessions);
		clientQuality = {
			Samples: 0,
			TotalFPS: 0,
			TotalP95Ms: 0,
			TotalPingMs: 0,
			TotalBootMs: 0,
			TotalJank: 0,
			WorstP95Ms: 0,
		};
	};
}
