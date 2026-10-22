// Optimistic edits: what the client assumes a request will do to the session before the server's
// next snapshot confirms it. One handler per action name; a handler returns the same session
// object when the request would change nothing, so selectors downstream stay quiet.
import * as SeenHints from "../../../../Shared/AstralForge/Shared/SeenHints";
import { Session } from "../../state";

export type Payload = Record<string, unknown>;
type Handler = (session: Session, payload: Payload, gameVersion?: string) => Session;

const withFlags = (session: Session, flags: Partial<Session["Flags"]>): Session => ({
	...session,
	Flags: { ...session.Flags, ...flags },
});

const HANDLERS: Record<string, Handler> = {
	SetSetting: (session, payload) => {
		const settings = { ...session.Settings };
		const batch = payload.Values;
		if (typeIs(batch, "table")) {
			for (const [key, value] of pairs(batch as Record<string, unknown>)) {
				if (typeIs(value, "number")) {
					settings[key] = math.clamp(value, 0, 1);
				}
			}
			return { ...session, Settings: settings };
		}
		if (typeIs(payload.Key, "string") && typeIs(payload.Value, "number")) {
			settings[payload.Key] = payload.Value;
			return { ...session, Settings: settings };
		}
		return session;
	},

	SetMobileLayout: (session, payload) => {
		if (typeIs(payload.Desktop, "string")) {
			return withFlags(session, { DesktopLayout: payload.Desktop });
		}
		if (typeIs(payload.Pins, "table")) {
			return withFlags(session, { MobileTabPins: payload.Pins });
		}
		if (typeIs(payload.Values, "table")) {
			return { ...session, Settings: { ...session.Settings, ...(payload.Values as Record<string, unknown>) } };
		}
		return session;
	},

	MarkHintSeen: (session, payload) => {
		if (!typeIs(payload.Id, "string")) {
			return session;
		}
		const seen = SeenHints.normalizeSeenHints(session.Flags?.SeenHints);
		if (SeenHints.isHintId(payload.Id) && !seen.includes(payload.Id)) {
			seen.push(payload.Id);
		}
		return withFlags(session, { SeenHints: seen });
	},

	SetTutorialStep: (session, payload) =>
		typeIs(payload.Step, "number") ? withFlags(session, { TutorialStep: math.max(1, math.floor(payload.Step)) }) : session,
	ReplayTutorial: (session) => withFlags(session, { TutorialDone: false, TutorialStep: 1 }),
	CompleteTutorial: (session) => withFlags(session, { TutorialDone: true }),
	DismissRelease: (session, _payload, gameVersion) => withFlags(session, { LastSeenVersion: gameVersion ?? session.Game.Version }),
	OpenRelease: (session) => withFlags(session, { LastSeenVersion: "" }),

	ReadStoryChapter: (session, payload) => {
		if (!typeIs(payload.Id, "string") || session.Story === undefined) {
			return session;
		}
		return { ...session, Story: session.Story.map((chapter) => (chapter.Id === payload.Id ? { ...chapter, Read: true } : chapter)) };
	},

	ReadMail: (session, payload) => {
		if (!typeIs(payload.Id, "string") || session.Mailbox === undefined) {
			return session;
		}
		let newlyRead = false;
		const messages = session.Mailbox.Messages.map((message) => {
			if (message.Id !== payload.Id || message.Read) {
				return message;
			}
			newlyRead = true;
			return { ...message, Read: true };
		});
		return { ...session, Mailbox: { Messages: messages, Unread: math.max(0, session.Mailbox.Unread - (newlyRead ? 1 : 0)) } };
	},

	SetAutoForge: (session, payload) => {
		if (
			session.AutoForge === undefined ||
			!typeIs(payload.Enabled, "boolean") ||
			!typeIs(payload.MachineId, "string") ||
			!typeIs(payload.Reserve, "number")
		) {
			return session;
		}
		return {
			...session,
			AutoForge: { ...session.AutoForge, Enabled: payload.Enabled, MachineId: payload.MachineId, Reserve: payload.Reserve },
		};
	},

	RouteLabPower: (session, payload) => {
		const lab = session.Lab;
		if (lab === undefined || !typeIs(payload.Channel, "string") || !typeIs(payload.Delta, "number")) {
			return session;
		}
		const routing = { ...lab.Routing };
		const current = routing[payload.Channel] ?? 0;
		const wanted = math.floor(payload.Delta);
		const actual = wanted > 0 ? math.min(wanted, lab.AvailableCells) : -math.min(-wanted, current);
		routing[payload.Channel] = math.max(0, current + actual);
		return {
			...session,
			Lab: { ...lab, Routing: routing, AvailableCells: math.clamp(lab.AvailableCells - actual, 0, lab.TotalCells) },
		};
	},

	SetAnomalyChannel: (session, payload) =>
		session.Anomaly !== undefined && typeIs(payload.Id, "string") ? { ...session, Anomaly: { ...session.Anomaly, Channel: payload.Id } } : session,

	ClaimAnomalyDirective: (session, payload) => {
		const anomaly = session.Anomaly;
		if (anomaly === undefined || !typeIs(payload.Id, "string")) {
			return session;
		}
		let changed = false;
		const directives = anomaly.Directives.map((directive) => {
			if (directive.Id !== payload.Id || directive.Claimed || directive.Progress < directive.Target) {
				return directive;
			}
			changed = true;
			return { ...directive, Claimed: true };
		});
		return changed ? { ...session, Anomaly: { ...anomaly, Directives: directives } } : session;
	},

	ClaimAnomalyMilestone: (session, payload) => {
		const anomaly = session.Anomaly;
		if (anomaly === undefined || !typeIs(payload.Tier, "number")) {
			return session;
		}
		let changed = false;
		const milestones = anomaly.Milestones.map((milestone) => {
			if (milestone.Tier !== payload.Tier || milestone.Claimed || anomaly.Stabilizations < milestone.Required) {
				return milestone;
			}
			changed = true;
			return { ...milestone, Claimed: true };
		});
		return changed ? { ...session, Anomaly: { ...anomaly, Milestones: milestones } } : session;
	},

	CollectVault: (session) => ({ ...session, Vault: 0 }),

	SelectZone: (session, payload) =>
		typeIs(payload.Id, "number") ? { ...session, CurrentZone: math.max(1, math.floor(payload.Id)) } : session,

	EquipTitle: (session, payload) => {
		const command = session.Command;
		if (!typeIs(payload.Id, "string") || command === undefined) {
			return session;
		}
		const selected = command.Titles.find((title) => title.Id === payload.Id);
		if (selected === undefined || !selected.Unlocked || selected.Equipped) {
			return session;
		}
		return { ...session, Command: { ...command, Titles: command.Titles.map((title) => ({ ...title, Equipped: title.Id === payload.Id })) } };
	},
};

export function applyOptimistic(session: Session | undefined, action: string, payload: Payload, gameVersion?: string): Session | undefined {
	if (session === undefined) {
		return undefined;
	}
	const handler = HANDLERS[action];
	return handler !== undefined ? handler(session, payload, gameVersion) : session;
}

export function hasOptimisticHandler(action: string): boolean {
	return HANDLERS[action] !== undefined;
}
