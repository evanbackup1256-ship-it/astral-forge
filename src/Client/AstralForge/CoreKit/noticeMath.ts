export function NormalizeTitle(title: unknown): string {
	const text = typeIs(title, "string") ? title : tostring(title);
	if (text === "Boost online") {
		return "Boost on";
	} else if (text === "Rebirth") {
		return "Rebirth done";
	} else if (text === "Order paid") {
		return "Claimed";
	} else if (text === "Studio grant") {
		return "Purchase test";
	}
	return text;
}

export function Signature(title: string, body: unknown, tone: unknown): string {
	return `${title}|${body}|${tone}`;
}

export function ShouldDedupe(lastSignature: string, lastAt: number, signature: string, now: number, window?: number): boolean {
	const gap = typeIs(window, "number") ? window : 0.55;
	return lastSignature === signature && now - lastAt < gap;
}

export function Lifetime(notificationDuration: number): number {
	const duration = tonumber(notificationDuration) ?? 0;
	return 2.8 + duration * 4.4;
}

export function MaxNotices(toastDensity: number): number {
	const density = tonumber(toastDensity) ?? 0;
	return math.clamp(math.floor(2 + density * 3 + 0.5), 2, 5);
}

export interface NoticeEntry {
	Id: string;
	Title: string;
	Body: string;
	Tone: string;
	At: number;
	Count: number;
}

// Recent toasts stay reviewable in the Mail page after they fade.
export const LOG_LIMIT = 40;
const logEntries = new Array<NoticeEntry>();
let logSequence = 0;
const logListeners = new Set<() => void>();

function notifyLog() {
	for (const listener of logListeners) {
		if (typeIs(task, "table")) {
			task.spawn(listener);
		} else {
			pcall(listener);
		}
	}
}

export function Record(title: unknown, body: unknown, tone: unknown, at?: number): NoticeEntry | undefined {
	const heading = (typeIs(title, "string") ? title : tostring(title ?? "")).sub(1, 80);
	const detail = (typeIs(body, "string") ? body : body === undefined ? "" : tostring(body)).sub(1, 400);
	if (heading === "" && detail === "") {
		return undefined;
	}
	const kind = typeIs(tone, "string") ? tone : "Info";
	const stamp = typeIs(at, "number") ? at : os.time();
	const newest = logEntries[0];
	if (newest !== undefined && newest.Title === heading && newest.Body === detail && newest.Tone === kind) {
		newest.Count += 1;
		newest.At = stamp;
		notifyLog();
		return newest;
	}
	logSequence += 1;
	const entry: NoticeEntry = { Id: `alert-${logSequence}`, Title: heading, Body: detail, Tone: kind, At: stamp, Count: 1 };
	logEntries.unshift(entry);
	while (logEntries.size() > LOG_LIMIT) {
		logEntries.pop();
	}
	notifyLog();
	return entry;
}

export function Entries(): NoticeEntry[] {
	return logEntries.map((entry) => table.clone(entry));
}

export function Subscribe(listener: () => void): () => void {
	logListeners.add(listener);
	return () => {
		logListeners.delete(listener);
	};
}

// ── Toast rules ────────────────────────────────────────────────────────────────
// One visible card per lane (the island). A notice stays up at least MIN_ON_SCREEN seconds, and
// long copy earns reading time: about one second per 12 words on top of the player's setting,
// capped at READING_CAP (or the setting, if the player chose longer).
export const MIN_ON_SCREEN = 2.5;
export const WORDS_PER_SECOND = 12;
export const READING_CAP = 6;

export function WordCount(text: unknown): number {
	if (!typeIs(text, "string")) {
		return 0;
	}
	let count = 0;
	for (const [_word] of text.gmatch("%S+")) {
		count += 1;
	}
	return count;
}

export function ReadingHold(lifetime: number, title: unknown, body: unknown): number {
	const words = WordCount(title) + WordCount(body);
	const reading = words / WORDS_PER_SECOND;
	const cap = math.max(READING_CAP, lifetime);
	return math.clamp(lifetime + math.max(0, reading - 1), MIN_ON_SCREEN, cap);
}
