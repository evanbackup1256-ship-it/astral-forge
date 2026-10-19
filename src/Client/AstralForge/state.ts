// The session snapshot the server sends. Only fields the client reads by name are typed; the rest
// stay reachable through the index signature until something needs them.

export type Flux = number | string;

export interface Session {
	Revision: number;
	SnapshotId: number;
	Cash?: Flux;
	Vault?: Flux;
	Cores?: number;
	Stardust?: number;
	Rebirths?: number;
	CurrentZone?: number;
	Settings: Record<string, unknown>;
	Flags: SessionFlags;
	Game: { Version: string; [key: string]: unknown };
	Story?: Array<{ Id: string; Read?: boolean; [key: string]: unknown }>;
	Mailbox?: { Messages: Array<{ Id: string; Read?: boolean; [key: string]: unknown }>; Unread: number };
	AutoForge?: { Enabled?: boolean; MachineId?: string; Reserve?: number; [key: string]: unknown };
	Lab?: { Routing: Record<string, number>; AvailableCells: number; TotalCells: number; [key: string]: unknown };
	Anomaly?: {
		Channel?: string;
		Stabilizations: number;
		Directives: Array<{ Id: string; Claimed?: boolean; Progress: number; Target: number; [key: string]: unknown }>;
		Milestones: Array<{ Tier: number; Claimed?: boolean; Required: number; [key: string]: unknown }>;
		[key: string]: unknown;
	};
	Command?: {
		Titles: Array<{ Id: string; Unlocked?: boolean; Equipped?: boolean; [key: string]: unknown }>;
		[key: string]: unknown;
	};
	Visit?: unknown;
	[key: string]: unknown;
}

export interface SessionFlags {
	TutorialStep?: number;
	TutorialDone?: boolean;
	LastSeenVersion?: string;
	[key: string]: unknown;
}
