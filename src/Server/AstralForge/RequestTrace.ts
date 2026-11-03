// Every client request goes through one callback in GameService. Wrapping it here gives the server a
// complete picture of its traffic without touching the dozens of actions behind it:
//
//   - a counter and a timing per action (server.request.<Action>), plus totals and a failure count
//   - a line for every rejected request (debug: recorded in the black box, printed when debug is on)
//   - a warning for a slow request (> 150 ms, at most one line per action per 20 s) and a louder one for
//     a very slow request (> 600 ms)
//   - an error with the trace when an action throws, and the request still gets an answer
//
// The chatty background reports are counted and timed but never logged line by line.
import * as LogBook from "../../Shared/AstralForge/Shared/LogBook";
import ModuleLog = require("./ModuleLog");

const QUIET: Record<string, boolean | undefined> = {
	ReportPerformance: true,
	ReportPresence: true,
	MeasureLatency: true,
	ReportClientIntegrity: true,
	GetState: true,
};
const SLOW_SECONDS = 0.15;
const VERY_SLOW_SECONDS = 0.6;

function failed(result: unknown): string | undefined {
	if (typeIs(result, "table")) {
		const reply = result as { ok?: unknown; error?: unknown };
		if (reply.ok === false) {
			return typeIs(reply.error, "string") ? reply.error : "rejected";
		}
	}
	return undefined;
}

export function traceRequests<F extends (player: Player, action: string, payload?: unknown) => unknown>(handler: F): F {
	const traced = (player: Player, action: string, payload?: unknown): unknown => {
		const started = os.clock();
		const [ok, result] = pcall(() => handler(player, action, payload));
		const elapsed = os.clock() - started;
		const key = `server.request.${action}`;
		LogBook.count("server.request.total");
		LogBook.count(key);
		LogBook.timing(key, elapsed);
		LogBook.timing("server.request.all", elapsed);
		if (!ok) {
			LogBook.count("server.request.threw");
			ModuleLog.Error("REQUEST", `${action} threw`, {
				Player: player,
				ElapsedMs: math.floor(elapsed * 1000),
				Error: tostring(result),
			});
			return { ok: false, error: "Something went wrong on the server. Try again." };
		}
		const reason = failed(result);
		if (reason !== undefined) {
			LogBook.count("server.request.rejected");
			if (QUIET[action] !== true) {
				ModuleLog.Debug("REQUEST", `${action} rejected`, { Player: player, Reason: reason, ElapsedMs: math.floor(elapsed * 1000) });
			}
		} else if (QUIET[action] !== true) {
			ModuleLog.Trace("REQUEST", `${action} ok`, { Player: player, ElapsedMs: math.floor(elapsed * 1000) });
		}
		if (elapsed >= VERY_SLOW_SECONDS) {
			ModuleLog.Warn("REQUEST", `${action} was very slow`, { Player: player, ElapsedMs: math.floor(elapsed * 1000) });
		} else if (elapsed >= SLOW_SECONDS && QUIET[action] !== true) {
			ModuleLog.Slow(`slow:${action}`, 20, "REQUEST", `${action} was slow`, { Player: player, ElapsedMs: math.floor(elapsed * 1000) });
		}
		return result;
	};
	return traced as unknown as F;
}
