// What the Control Room sends and what it hears back: the state shape, the one request that runs a command, and
// the hook every tab shares so a command is always sent the same way (fresh nonce, string amount, one at a time).
import React from "@rbxts/react";
import { AdminConfig, BanEntry } from "../../CoreKit/adminFields";
import { AudioPlayer, kitMember } from "../luauKits";
import type { AdminCommand, AdminPlayer } from "./AdminParts";

const HttpService = game.GetService("HttpService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");

export interface AuditRecord {
	Id: string;
	Command: string;
	ActorName: string;
	TargetName: string;
	At?: number;
	Amount?: number;
	Option?: string;
	Reason?: string;
}

export interface SecurityRow {
	UserId: number;
	Name: string;
	Flags: number;
	LastKind: string;
	Score: number;
	Level: string;
}

export interface SecurityFlagRow {
	At: number;
	Name: string;
	Kind: string;
	Detail?: string;
	Response?: string;
}

export interface HotFlagRow {
	Name: string;
	On: boolean;
	Description: string;
}

export interface AnnouncementRow {
	Text: string;
	From: string;
	At: number;
}

export interface EconomySummary {
	Players?: number;
	TotalCash?: unknown;
	RichestCash?: unknown;
	MedianProduction?: number;
	MedianRebirths?: number;
	TotalStardust?: number;
	TotalCores?: number;
	TopActions?: Array<{ Action: string; Count: number }>;
}

export interface TelemetryState {
	UptimeSeconds?: number;
	RemoteAccepted?: number;
	RemoteRejected?: number;
	RemoteRejectRate?: number;
	IntegrityReports?: number;
	SessionsStarted?: number;
	ActiveSessions?: number;
	TopRejections?: Array<{ Reason: string; Count: number }>;
	Timings?: Array<{ Name: string; Count: number; Failures: number; AverageMs: number; MaximumMs: number }>;
	ClientPerformance?: { Samples?: number; AverageFPS?: number; AveragePingMs?: number; AverageP95Ms?: number; AverageJankPct?: number };
}

export interface LookupResult {
	UserId: number;
	Name: string;
	Score: number;
	Level: string;
	Revision?: number;
	Flags?: Array<{ At: number; Kind: string; Detail: string }>;
	Journal?: Array<{ Id: string; At: number; Label?: string; Revision?: number }>;
}

export interface AdminState {
	Access?: boolean;
	Role?: string;
	SelfUserId?: number;
	Online?: AdminPlayer[];
	Commands?: AdminCommand[];
	Recent?: AuditRecord[];
	Banned?: BanEntry[];
	Integrity?: { Healthy?: boolean };
	LastAction?: { Message: string; Ok: boolean };
	Telemetry?: TelemetryState;
	SecurityPlayers?: SecurityRow[];
	SecurityFlags?: SecurityFlagRow[];
	AntiCheatRules?: Array<{ Id: string; Repairs: number }>;
	HotFlags?: HotFlagRow[];
	Announcements?: AnnouncementRow[];
	Economy?: EconomySummary;
}

export interface AdminResponse {
	ok?: boolean;
	message?: string;
	error?: string;
	Preview?: unknown;
	Lookup?: LookupResult;
}

export interface AdminProps {
	state: { Admin?: AdminState };
	config?: AdminConfig;
	dispatch: (action: string, payload?: object, callback?: (response: AdminResponse) => void) => unknown;
	reducedMotion?: boolean;
}

export interface RunRequest {
	command: string;
	targetUserId: number;
	amount: string;
	option: string;
	reason: string;
	dryRun: boolean;
}

export interface Outcome {
	ok: boolean;
	text: string;
	token: number;
	command: string;
	dryRun: boolean;
	preview: string[];
	lookup?: LookupResult;
}

export interface Runner {
	busyId?: string;
	outcome?: Outcome;
	run: (request: RunRequest, done?: (outcome: Outcome) => void) => void;
}

export interface AdminContext {
	admin: AdminState;
	config?: AdminConfig;
	dispatch: AdminProps["dispatch"];
	runner: Runner;
	commands: AdminCommand[];
	online: AdminPlayer[];
	targetId: number;
	setTargetId: (userId: number) => void;
	target?: AdminPlayer;
	width: number;
	wide: boolean;
	reducedMotion: boolean;
	has: (command: string) => boolean;
}

export function useRunner(dispatch: AdminProps["dispatch"], onSuccess?: (command: string) => void): Runner {
	const [busyId, setBusyId] = React.useState<string>();
	const [outcome, setOutcome] = React.useState<Outcome>();
	const busyRef = React.useRef(false);
	const attempt = React.useRef(0);
	const tokens = React.useRef(0);
	const mounted = React.useRef(true);
	const successRef = React.useRef(onSuccess);
	successRef.current = onSuccess;
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
			attempt.current += 1;
		};
	}, []);

	const run = React.useCallback(
		(request: RunRequest, done?: (result: Outcome) => void) => {
			if (busyRef.current) {
				return;
			}
			busyRef.current = true;
			setBusyId(request.command);
			attempt.current += 1;
			const mine = attempt.current;
			Audio.play(request.dryRun ? "click" : "adminExecute");
			const finish = (ok: boolean, text: string, response?: AdminResponse) => {
				if (!mounted.current || attempt.current !== mine) {
					return;
				}
				// a late answer after the timeout must not land on whatever command is running by then
				attempt.current += 1;
				busyRef.current = false;
				setBusyId(undefined);
				tokens.current += 1;
				const preview: string[] = [];
				if (request.dryRun && ok && response !== undefined && typeIs(response.Preview, "table")) {
					for (const line of response.Preview as unknown[]) {
						const text = tostring(line);
						// the save diff also lists tables rebuilt with the same size ("0 entries to 0 entries"): not a change
						const [before, after] = text.match("(%d+) entries to (%d+) entries");
						if (before === undefined || before !== after) {
							preview.push(text);
						}
					}
				}
				const lookup = ok && response !== undefined && typeIs(response.Lookup, "table") ? response.Lookup : undefined;
				const result: Outcome = { ok, text, token: tokens.current, command: request.command, dryRun: request.dryRun, preview, lookup };
				setOutcome(result);
				if (done !== undefined) {
					done(result);
				}
				if (ok && !request.dryRun) {
					if (successRef.current !== undefined) {
						successRef.current(request.command);
					}
					// the audit log and the player stats moved: ask for fresh state shortly after the server settles
					task.delay(0.4, () => {
						if (mounted.current) {
							dispatch("GetAdminState");
						}
					});
				}
			};
			const timeout = task.delay(9, () => finish(false, "The server did not answer. Try again."));
			dispatch(
				"AdminExecute",
				{
					TargetUserId: request.targetUserId,
					Command: request.command,
					Amount: request.amount,
					Option: request.option,
					Reason: request.reason,
					DryRun: request.dryRun,
					Nonce: HttpService.GenerateGUID(false),
				},
				(response) => {
					pcall(task.cancel, timeout);
					const ok = response.ok === true;
					finish(ok, ok ? (response.message ?? "Done.") : (response.error ?? "Failed."), response);
				},
			);
		},
		[dispatch],
	);
	return { busyId, outcome, run };
}
