import Types = require("./Types");
import SaveUtil = require("./SaveUtil");
import deepFreeze = require("./DeepFreeze");
import Signal = require("./Signal");

// Must stay in sync with ServerConfig.SessionLockSeconds.
const SESSION_EXPIRE_TIME = 600;
const AUTOSAVE_INTERVAL = 150;

type DataStoreInterface = Types.DataStoreInterface;
type Migrations = Types.Migrations;
type HookEvent = Types.HookEvent;
type Transform<T> = Types.Transform<T>;
type Result<T, E> = Types.Result<T, E>;

type RobloxAPIError = Types.RobloxAPIError;
type SessionLockedError = Types.SessionLockedError;
type CheckError = Types.CheckError;
type BackwardsCompatibilityError = Types.BackwardsCompatibilityError;
type SchemaError = Types.SchemaError;

type OpenResult<T> = Types.OpenResult<T>;
type WriteResult<T> = Types.WriteResult<T>;
type ReadResult<T> = Types.ReadResult<T>;
type DocumentProps<T> = Types.DocumentProps<T>;

interface KeyData<T> {
	documentServiceSchemaVersion: number;
	sessionLockId: string;
	lockTimestamp: number;
	isLocked: boolean;
	dataSchemaVersion: number;
	lastCompatibleVersion: number;
	data: T;
}

type Hook = () => void;
type HookTable = Record<HookEvent, Hook[]>;



const INTERNAL_SCHEMA_VERSION = 0;

function runHooks(hooks: Hook[]) {
	const failures: string[] = [];
	for (const hook of table.clone(hooks)) {
		const [ok, err] = pcall(hook);
		if (!ok) {
			failures.push(tostring(err));
		}
	}
	if (failures.size() > 0) {
		warn("[Document] hook failure(s): " + failures.join("; "));
	}
}

function getLastCompatibleVersion(migrations: Migrations): number {
	for (let version = migrations.size(); version >= 1; version--) {
		const migration = migrations[version - 1];

		if (!migration.backwardsCompatible) {
			return version;
		}
	}

	return 0;
}

function runMigrations(migrations: Migrations, initialData: unknown, initialVersion: number): unknown {
	let data = initialData;
	let dataVersion = initialVersion;

	migrations.forEach((migration, index) => {
		const i = index + 1;
		const fromVersion = i - 1;
		const targetVersion = i;

		if (fromVersion === dataVersion) {
			data = migration.migrate(data);
			dataVersion = targetVersion;
		}

		if (data === undefined || data === false) {
			warn("Migration did not return a value - did you forget to return one?");
		}
	});

	return data;
}

function isLocked(keyData: KeyData<unknown>): boolean {
	return keyData.isLocked && os.time() - keyData.lockTimestamp < SESSION_EXPIRE_TIME;
}

function checkKeyData(value: unknown): KeyData<unknown> | undefined {
	if (!typeIs(value, "table")) {
		return;
	}
	const v = value as Record<string, unknown>;

	if (v.documentServiceSchemaVersion === undefined || v.documentServiceSchemaVersion === false) {
		return;
	}

	if (v.documentServiceSchemaVersion !== INTERNAL_SCHEMA_VERSION) {
		warn("documentServiceSchemaVersion mutated");
		return;
	}

	if (!typeIs(v.sessionLockId, "string")) {
		warn(".isSessionLocked invalid");
		return;
	}
	if (!typeIs(v.isLocked, "boolean")) {
		warn(".isLocked invalid");
		return;
	}
	if (!typeIs(v.lockTimestamp, "number")) {
		warn(".lockTimestamp invalid");
		return;
	}
	if (!typeIs(v.data, "table")) {
		warn(".data invalid");
		return;
	}
	if (!typeIs(v.lastCompatibleVersion, "number")) {
		warn(".lastCompatibleVersion invalid");
		return;
	}
	if (!typeIs(v.dataSchemaVersion, "number")) {
		warn(".dataSchemaVersion invalid");
		return;
	}

	return value as unknown as KeyData<unknown>;
}

function cleanupHook(hooks: Hook[], hook: Hook) {
	const index = hooks.indexOf(hook);

	if (index === -1) {
		error(`Failed to cleanup "${hook}" hook, not found in the given "${hooks}" hooks event registry!`);
	}

	hooks.remove(index);
}

// check() returns (ok, value); only the first value matters, as in the Luau original.
function firstCheck(check: (this: void, value: unknown) => LuaTuple<[boolean, unknown?]>, value: unknown): boolean {
	const [ok] = check(value);
	return ok;
}

class Document<T extends object> {
	_key: string;
	_dataStore: DataStoreInterface;
	_check: DocumentProps<T>["check"];
	_default: T;
	_open: boolean;
	_sessionId: string;
	_preHooks: HookTable;
	_postHooks: HookTable;
	_failHooks: HookTable;
	_actionSignals: {
		Open: Types.Signal<[unknown]>;
		Close: Types.Signal<[unknown]>;
		Update: Types.Signal<[unknown]>;
		Read: Types.Signal<[unknown]>;
		Cache: Types.Signal<[unknown]>;
	};
	_migrations: Migrations;
	_isClosing: boolean;
	_cache: T;
	_lockSessions: boolean;
	_shouldSteal: boolean;
	_autoSaveThread?: thread;
	_onOpenTransform?: Transform<T>;

	constructor(props: DocumentProps<T>) {
		assert(firstCheck(props.check, props.default), "Default must pass type check");
		assert(typeOf(props.default) === "table", "Non-table values are not supported - group your data.");

		SaveUtil.assertStorable(props.default);

		this._key = props.key;
		this._dataStore = props.dataStore;
		this._check = props.check;
		this._default = deepFreeze(props.default);
		this._open = false;
		this._sessionId = SaveUtil.uuid();
		this._preHooks = { Open: [], Close: [], Update: [], Read: [] };
		this._postHooks = { Open: [], Close: [], Update: [], Read: [] };
		this._failHooks = { Open: [], Close: [], Update: [], Read: [] };
		this._actionSignals = {
			Open: Signal.new(),
			Close: Signal.new(),
			Update: Signal.new(),
			Read: Signal.new(),
			Cache: Signal.new(),
		};
		this._migrations = deepFreeze(props.migrations);
		this._isClosing = false;
		this._cache = props.default;
		this._lockSessions = props.lockSessions;
		this._shouldSteal = false;
	}


	Open(): OpenResult<T> {
		assert(!this._open, `${this} already open`);
		assert(!this._isClosing, `${this} is closing, cannot open`);

		let lockedByOther = false;
		let incompatibleVersion = false;
		let failedCheck = false;
		let notStorable = false;
		let notStorableErr = "";
		let transformInvalid = false;
		let migrationErrored = false;
		let migrationErr: unknown;

		runHooks(this._preHooks.Open);

		const [updateOk, updatedKeyData] = SaveUtil.updateAsync(
			(abortAttempt, getValue): KeyData<T> | undefined => {
				lockedByOther = false;
				incompatibleVersion = false;
				failedCheck = false;

				let dataToMigrate: unknown;
				let keyData: KeyData<unknown> | undefined;

				if (getValue !== undefined && getValue !== false) {
					keyData = checkKeyData(getValue);

					if (keyData) {
						dataToMigrate = keyData.data;
					} else {
						print("Key non-empty but does not contain valid keyData, using value as data field");
						dataToMigrate = typeOf(getValue) === "table" ? getValue : [getValue];
					}
				} else {
					dataToMigrate = this._default;
				}

				let savedVersion = 0;
				if (dataToMigrate === this._default) {
					savedVersion = this._migrations.size();
				}
				if (keyData) {
					savedVersion = keyData.dataSchemaVersion;
				}

				const [success, migrateResult] = pcall(() => {
					return runMigrations(this._migrations, dataToMigrate, savedVersion);
				});

				if (!success) {
					migrationErrored = true;
					migrationErr = migrateResult;

					return;
				}

				const migratedData = migrateResult;

				if (keyData) {
					if (this._migrations.size() < keyData.lastCompatibleVersion) {
						incompatibleVersion = true;

						return;
					}

					const locked = isLocked(keyData);
					const lockedByUs = locked && keyData.sessionLockId === this._sessionId;

					if (locked && !lockedByUs && !this._shouldSteal) {
						lockedByOther = true;
						abortAttempt(`Session lock held by another session for ${this}.`);

						return;
					}
				}

				const checkOk = firstCheck(this._check, migratedData);

				if (!checkOk) {
					failedCheck = true;

					return;
				}

				let data = migratedData as T;

				if (this._onOpenTransform) {
					data = this._onOpenTransform(data);
				}

				let newDataIsValid = firstCheck(this._check, data);
				newDataIsValid = newDataIsValid && typeOf(data) === "table";

				const [isStorable, err] = pcall(() => {
					SaveUtil.assertStorable(data);
				});

				if (!isStorable) {
					notStorable = true;
					notStorableErr = err as string;

					return;
				}

				if (!newDataIsValid) {
					transformInvalid = true;

					return;
				}

				this._cache = deepFreeze(data);

				return {
					documentServiceSchemaVersion: INTERNAL_SCHEMA_VERSION,
					sessionLockId: this._sessionId,
					lockTimestamp: os.time(),
					isLocked: this._lockSessions,

					dataSchemaVersion: math.max(this._migrations.size(), savedVersion),
					lastCompatibleVersion: getLastCompatibleVersion(this._migrations),
					data: data,
				};
			},
			this._dataStore,
			this._key,
		);

		let failResult: OpenResult<T> | undefined;

		if (!updateOk) {
			failResult = { success: false, reason: "RobloxAPIError" };
		}

		if (lockedByOther) {
			failResult = { success: false, reason: "SessionLockedError" };
		}

		if (failedCheck) {
			failResult = { success: false, reason: "CheckError" };
		}

		if (incompatibleVersion) {
			failResult = { success: false, reason: "BackwardsCompatibilityError" };
		}

		if (failResult) {
			runHooks(this._failHooks.Open);

			this._actionSignals.Open.Fire(failResult);

			return failResult;
		}

		if (transformInvalid) {
			runHooks(this._failHooks.Open);
			error(
				`Could not open Document ${this._key}. Invalid transform function - must return a table that passes the check function.`,
			);
		}

		if (notStorable) {
			runHooks(this._failHooks.Open);
			error(`Could not open Document ${this._key}. Not storable: ${notStorableErr}`);
		}

		if (migrationErrored) {
			runHooks(this._failHooks.Open);
			error(`Could not open Document ${this._key}. Migrations errored: ${migrationErr}`);
		}

		this._open = true;

		this._shouldSteal = false;

		this._autoSaveThread = task.defer(() => {
			while (this._lockSessions && this._open) {
				task.wait(AUTOSAVE_INTERVAL);

				const result = this.Save();

				if (!result.success) {
					warn(`[DocumentService] AutoSave for key ${this._key} failed due to a ${result.reason}`);
				}
			}
		});

		runHooks(this._postHooks.Open);

		const result: OpenResult<T> = {
			success: true,
			data: (updatedKeyData as KeyData<T>).data,
		};

		this._actionSignals.Open.Fire(result);

		return result;
	}

	OpenAndUpdate(transform: Transform<T>): OpenResult<T> {
		assert(!this._open, `${this} already open`);
		assert(!this._isClosing, `${this} is closing, cannot open`);

		runHooks(this._preHooks.Update);

		this._onOpenTransform = transform;

		const result = this.Open();

		this._onOpenTransform = undefined;

		this._actionSignals.Update.Fire(result);

		if (result.success) {
			runHooks(this._postHooks.Update);

			return result;
		} else {
			runHooks(this._failHooks.Update);

			return result;
		}
	}

	Steal() {
		assert(!this._isClosing, "Document is closing");
		assert(this._lockSessions, "Stealing locks is only applicable to session-locked Documents");

		this._shouldSteal = true;
	}

	GetOpenedSignal() {
		return this._actionSignals.Open;
	}

	GetClosedSignal() {
		return this._actionSignals.Close;
	}

	GetUpdatedSignal() {
		return this._actionSignals.Update;
	}

	GetReadSignal() {
		return this._actionSignals.Read;
	}

	GetCacheChangedSignal() {
		return this._actionSignals.Cache;
	}

	IsOpenAvailable(): Result<boolean, RobloxAPIError> {
		assert(!this._isClosing, "Document is closing");

		if (this._open) {
			return { success: true, data: false };
		}

		if (!this._lockSessions) {
			return { success: true, data: true };
		}

		const [success, getValue] = SaveUtil.getAsync(this._dataStore, this._key);

		if (!success) {
			return { success: false, reason: "RobloxAPIError" };
		}

		const keyData = checkKeyData(getValue);

		if (!keyData) {
			return { success: true, data: true };
		}

		const locked = isLocked(keyData);
		const lockedByUs = locked && keyData.sessionLockId === this._sessionId;

		return {
			success: true,
			data: !locked || lockedByUs,
		};
	}

	IsOpen(): boolean {
		return this._open;
	}

	Close(): WriteResult<T | undefined> {
		assert(this._open, "Document not open");

		runHooks(this._preHooks.Close);

		this._isClosing = true;

		let saveResult: WriteResult<T> | undefined;

		if (this._lockSessions) {
			const [saveOk, saveOutcome] = pcall(() => {
				return this.Save();
			});
			if (!saveOk) {
				this._isClosing = false;
				const failed: WriteResult<T> = { success: false, reason: "RobloxAPIError" };
				runHooks(this._failHooks.Close);
				this._actionSignals.Close.Fire(failed);
				return failed;
			}
			saveResult = saveOutcome as WriteResult<T>;

			if (!saveResult.success) {
				this._isClosing = false;

				runHooks(this._failHooks.Close);
				this._actionSignals.Close.Fire(saveResult);

				return saveResult;
			}
		}

		if (this._autoSaveThread) {
			task.cancel(this._autoSaveThread);
		}

		this._open = false;
		this._isClosing = false;

		runHooks(this._postHooks.Close);

		let result = { success: true } as WriteResult<T | undefined>;

		if (this._lockSessions) {
			result = saveResult!;
		}

		this._actionSignals.Close.Fire(result);

		return result;
	}

	IsClosing(): boolean {
		return this._isClosing;
	}

	SetCache(newCache: T): T {
		assert(this._open, "Document not open");
		assert(this._lockSessions, "Cache is only supported for session locked data");

		this._cache = deepFreeze(newCache);

		this._actionSignals.Cache.Fire(newCache);

		return this._cache;
	}

	GetCache(): T {
		assert(this._open, "Document not open");
		assert(this._lockSessions, "Cache is only supported for session locked data");

		return this._cache;
	}

	Update(transform: Transform<T>): WriteResult<T> {
		assert(this._open, "Document not open");

		runHooks(this._preHooks.Update);

		let lockedByOther = false;
		let transformInvalid = false;
		let notStorable = false;
		let schemaError = false;
		let notStorableErr = "";

		let pendingData: T | undefined;
		if (this._lockSessions) {
			// Keep the live cache unchanged until DataStore confirms the write.
			pendingData = transform(this._cache);
		}

		const [success, updatedKeyData] = SaveUtil.updateAsync(
			(_abortAttempt, value): KeyData<T> | undefined => {
				lockedByOther = false;
				transformInvalid = false;
				notStorable = false;
				notStorableErr = "";

				const keyData = checkKeyData(value);

				if (!keyData) {
					schemaError = true;

					return;
				}

				const locked = isLocked(keyData);
				const lockedByUs = locked && keyData.sessionLockId === this._sessionId;

				if (locked && !lockedByUs) {
					lockedByOther = true;

					return;
				}

				let newData: T | undefined;
				if (this._lockSessions) {
					newData = pendingData;
				} else {
					newData = transform(keyData.data as T);
				}

				let newDataIsValid = firstCheck(this._check, newData);
				newDataIsValid = newDataIsValid && typeOf(newData) === "table";

				const [isStorable, err] = pcall(() => {
					SaveUtil.assertStorable(newData);
				});

				if (!isStorable) {
					notStorable = true;
					notStorableErr = err as string;

					return;
				}

				if (!newDataIsValid) {
					transformInvalid = true;

					return;
				}

				return {
					documentServiceSchemaVersion: INTERNAL_SCHEMA_VERSION,
					sessionLockId: keyData.sessionLockId,
					lockTimestamp: os.time(),

					isLocked: this._isClosing ? false : lockedByUs,
					data: newData as T,
					dataSchemaVersion: keyData.dataSchemaVersion,
					lastCompatibleVersion: keyData.lastCompatibleVersion,
				};
			},
			this._dataStore,
			this._key,
		);

		if (transformInvalid) {
			error("Invalid transform function - must return a table that passes the check function.");
		}

		if (notStorable) {
			error("Not storable: " + notStorableErr);
		}

		let failResult: WriteResult<T> | undefined;

		if (!success) {
			failResult = { success: false, reason: "RobloxAPIError" };
		}

		if (lockedByOther) {
			failResult = { success: false, reason: "SessionLockedError" };
		}

		if (schemaError) {
			failResult = { success: false, reason: "SchemaError" };
		}

		if (failResult) {
			runHooks(this._failHooks.Update);

			this._actionSignals.Update.Fire(failResult);

			return failResult;
		}

		const updatedData: T = (updatedKeyData as KeyData<T>).data;
		if (this._lockSessions && updatedData !== this._cache) {
			// Publish the optimistic cache value only after persistence succeeds.
			this.SetCache(updatedData);
		}

		runHooks(this._postHooks.Update);

		const result: WriteResult<T> = {
			success: true,
			data: updatedData,
		};

		this._actionSignals.Update.Fire(result);

		return result;
	}

	Save(): WriteResult<T> {
		assert(this._open, "Document not open");
		assert(this._lockSessions, "Must be session locked to access cache");

		return this.Update((cache) => {
			return cache;
		});
	}

	Erase(): Result<undefined, RobloxAPIError> {
		assert(!this._open, "Cannot erase an open document");

		const success = SaveUtil.removeAsync(this._dataStore, this._key);

		if (!success) {
			return { success: false, reason: "RobloxAPIError" };
		}

		return { success: true } as Result<undefined, RobloxAPIError>;
	}

	Read(): ReadResult<T> {
		runHooks(this._preHooks.Read);

		const [success, getValue] = SaveUtil.getAsync(this._dataStore, this._key);

		if (!success) {
			runHooks(this._failHooks.Read);

			const result: ReadResult<T> = { success: false, reason: "RobloxAPIError" };

			this._actionSignals.Read.Fire(result);

			return result;
		}

		const keyData = checkKeyData(getValue);

		if (!keyData) {
			runHooks(this._failHooks.Read);

			const result: ReadResult<T> = { success: false, reason: "SchemaError" };

			this._actionSignals.Read.Fire(result);

			return result;
		}

		const migratedData = runMigrations(this._migrations, keyData.data, keyData.dataSchemaVersion);

		const checkOk = firstCheck(this._check, migratedData);

		if (!checkOk) {
			runHooks(this._failHooks.Read);

			const result: ReadResult<T> = { success: false, reason: "CheckError" };

			this._actionSignals.Read.Fire(result);

			return result;
		}

		const data = migratedData as T;

		if (this._migrations.size() < keyData.lastCompatibleVersion) {
			runHooks(this._failHooks.Read);

			const result: ReadResult<T> = { success: false, reason: "BackwardsCompatibilityError" };

			this._actionSignals.Read.Fire(result);

			return result;
		}

		runHooks(this._postHooks.Read);

		const result: ReadResult<T> = { success: true, data: data };

		this._actionSignals.Read.Fire(result);

		return result;
	}

	HookBefore(event: HookEvent, hook: Hook): () => void {
		const hooks = this._preHooks[event];
		hooks.push(hook);

		return () => {
			cleanupHook(hooks, hook);
		};
	}

	HookAfter(event: HookEvent, hook: Hook): () => void {
		const hooks = this._postHooks[event];
		hooks.push(hook);

		return () => {
			cleanupHook(hooks, hook);
		};
	}

	HookFail(event: HookEvent, hook: Hook): () => void {
		const hooks = this._failHooks[event];
		hooks.push(hook);

		return () => {
			cleanupHook(hooks, hook);
		};
	}

	OnceBefore(event: HookEvent, hook: Hook) {
		let cleanup: (() => void) | undefined;

		cleanup = this.HookBefore(event, () => {
			cleanup!();
			hook();
		});
	}

	OnceAfter(event: HookEvent, hook: Hook) {
		let cleanup: (() => void) | undefined;

		cleanup = this.HookAfter(event, () => {
			cleanup!();
			hook();
		});
	}

	OnceFail(event: HookEvent, hook: Hook) {
		let cleanup: (() => void) | undefined;

		cleanup = this.HookFail(event, () => {
			cleanup!();
			hook();
		});
	}

	toString() {
		return `Document: ${this._key}`;
	}

	static isDocument(this: void, instance: unknown): boolean {
		return (getmetatable(instance as object) as { __index?: unknown }).__index === Document;
	}
}

export = Document;
