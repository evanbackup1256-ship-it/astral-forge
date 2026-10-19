export type HookEvent = "Open" | "Close" | "Update" | "Read";

export interface Ok<T> {
	success: true;
	data: T;
}

export interface Err<E> {
	success: false;
	reason: E;
}

export type Result<T, E> = Ok<T> | Err<E>;

export type RobloxAPIError = "RobloxAPIError";
export type SessionLockedError = "SessionLockedError";
export type CheckError = "CheckError";
export type BackwardsCompatibilityError = "BackwardsCompatibilityError";
export type SchemaError = "SchemaError";

export interface Migration {
	backwardsCompatible: boolean;
	migrate: (this: void, data: unknown) => unknown;
}

export type Migrations = Migration[];

export type Transform<T> = (this: void, data: T) => T;

export interface DataStoreInterface {
	UpdateAsync(
		key: string,
		transform: (data: unknown, keyInfo: DataStoreKeyInfo) => LuaTuple<[unknown, number[]?, unknown?]> | unknown,
	): LuaTuple<[unknown, DataStoreKeyInfo]>;
	GetAsync(key: string, options: DataStoreGetOptions): LuaTuple<[unknown, DataStoreKeyInfo]>;
	RemoveAsync(key: string): LuaTuple<[unknown, DataStoreKeyInfo]>;
}

export type OpenResult<T> = Result<T, RobloxAPIError | BackwardsCompatibilityError | CheckError | SessionLockedError>;
export type WriteResult<T> = Result<T, RobloxAPIError | SessionLockedError | SchemaError>;
export type ReadResult<T> = Result<T, RobloxAPIError | SchemaError | CheckError | BackwardsCompatibilityError>;

export type CheckFn = (this: void, value: unknown) => LuaTuple<[boolean, unknown?]>;

export interface DocumentProps<T> {
	key: string;
	dataStore: DataStoreInterface;
	check: CheckFn;
	default: T;
	migrations: Migrations;
	lockSessions: boolean;
}

export interface DocumentStoreProps<T> {
	dataStore: DataStoreInterface;
	check: CheckFn;
	default: T;
	migrations?: Migrations;
	lockSessions: boolean;
	bindToClose?: boolean;
}

export interface StoreProps {
	dataStore: DataStoreInterface;
	check: CheckFn;
	default: object;
	migrations?: Migrations;
	bindToClose?: boolean;
}

export interface Connection {
	Disconnect(): void;
	Destroy(): void;
	Connected: boolean;
}

export interface Signal<T extends unknown[] = unknown[]> {
	Fire(...args: T): void;
	FireDeferred(...args: T): void;
	Connect(fn: (...args: T) => void): Connection;
	ConnectOnce(fn: (...args: T) => void): Connection;
	Once(fn: (...args: T) => void): Connection;
	DisconnectAll(): void;
	GetConnections(): Connection[];
	Destroy(): void;
	Wait(): LuaTuple<T>;
}