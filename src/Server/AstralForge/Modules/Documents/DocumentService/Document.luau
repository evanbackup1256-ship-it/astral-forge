--!strict


local Types = require(script.Parent:FindFirstChild("Types"))
local SaveUtil = require(script.Parent:FindFirstChild("SaveUtil"))
local deepFreeze = require(script.Parent:FindFirstChild("DeepFreeze"))
local Signal = require(script.Parent:FindFirstChild("Signal"))

local SESSION_EXPIRE_TIME = 600
local AUTOSAVE_INTERVAL = 150


local Document = {}
Document.__index = Document

type DataStoreInterface = Types.DataStoreInterface

export type Document<T> = typeof(setmetatable(
	{} :: {
		_key: string,
		_dataStore: DataStoreInterface,
		_check: (unknown) -> (boolean, T),
		_default: T,
		_open: boolean,
		_sessionId: string,
		_preHooks: {
			Open: { () -> () },
			Close: { () -> () },
			Read: { () -> () },
			Update: { () -> () },
		},

		_postHooks: {
			Open: { () -> () },
			Close: { () -> () },
			Read: { () -> () },
			Update: { () -> () },
		},
		_failHooks: {
			Open: { () -> () },
			Close: { () -> () },
			Read: { () -> () },
			Update: { () -> () },
		},

		_actionSignals: {
			Open: Signal.Signal<any>,
			Close: Signal.Signal<any>,
			Read: Signal.Signal<any>,
			Update: Signal.Signal<any>,
			Cache: Signal.Signal<any>,
		},
		_migrations: Migrations,
		_cache: T,
		_isClosing: boolean,
		_lockSessions: boolean,
		_autoSaveThread: thread?,
		_shouldSteal: boolean,
		_onOpenTransform: Transform<T>?,
	},
	Document
))

export type Migrations = Types.Migrations

export type HookEvent = Types.HookEvent

export type Transform<T> = Types.Transform<T>

type Result<T, E> = Types.Result<T, E>


type OpenResult<T> = Result<T, RobloxAPIError | BackwardsCompatibilityError | CheckError | SessionLockedError>


type WriteResult<T> = Result<T, RobloxAPIError | SessionLockedError | SchemaError>

type ReadResult<T> = Result<T, RobloxAPIError | SchemaError | CheckError | BackwardsCompatibilityError>

type KeyData<T> = {
	documentServiceSchemaVersion: number,
	sessionLockId: string,
	lockTimestamp: number,
	isLocked: boolean,
	dataSchemaVersion: number,
	lastCompatibleVersion: number,
	data: T,
}

type RobloxAPIError = Types.RobloxAPIError
type SessionLockedError = Types.SessionLockedError
type CheckError = Types.CheckError
type BackwardsCompatibilityError = Types.BackwardsCompatibilityError
type SchemaError = Types.SchemaError

local INTERNAL_SCHEMA_VERSION = 0

local function runHooks(hooks: { () -> () })

	for _, hook in table.clone(hooks) do
		hook()
	end
end


local function getLastCompatibleVersion<T>(migrations: Migrations): number
	for version = #migrations, 1, -1 do
		local migration = migrations[version]

		if not migration.backwardsCompatible then
			return version
		end
	end

	return 0
end

local function runMigrations(migrations: Migrations, initialData: unknown, initialVersion: number): unknown
	local data = initialData
	local dataVersion = initialVersion

	for i, migration in ipairs(migrations) do
		local fromVersion = i - 1
		local targetVersion = i

		if fromVersion == dataVersion then
			data = migration.migrate(data)
			dataVersion = targetVersion
		end

		if not data then
			warn("Migration did not return a value - did you forget to return one?")
		end
	end

	return data
end

local function isLocked(keyData: KeyData<any>): boolean
	return keyData.isLocked and (os.time() - keyData.lockTimestamp < SESSION_EXPIRE_TIME)
end

local function checkKeyData(value: any): KeyData<any>?
	if type(value) ~= "table" then
		return
	end

	if not value.documentServiceSchemaVersion then
		return
	end



	if value.documentServiceSchemaVersion ~= INTERNAL_SCHEMA_VERSION then
		warn("documentServiceSchemaVersion mutated")
		return
	end

	if type(value.sessionLockId) ~= "string" then
		warn(".isSessionLocked invalid")
		return
	end
	if type(value.isLocked) ~= "boolean" then
		warn(".isLocked invalid")
		return
	end
	if type(value.lockTimestamp) ~= "number" then
		warn(".lockTimestamp invalid")
		return
	end
	if type(value.data) ~= "table" then
		warn(".data invalid")
		return
	end
	if type(value.lastCompatibleVersion) ~= "number" then
		warn(".lastCompatibleVersion invalid")
		return
	end
	if type(value.dataSchemaVersion) ~= "number" then
		warn(".dataSchemaVersion invalid")
		return
	end

	return value :: KeyData<any>
end



function Document.new<T>(props: {
	key: string,
	dataStore: DataStoreInterface,
	check: (unknown) -> (boolean, T),
	default: T,
	migrations: Types.Migrations,
	lockSessions: boolean,
}): Document<T>
	assert(props.check(props.default), "Default must pass type check")
	assert(typeof(props.default) == "table", "Non-table values are not supported - group your data.")

	SaveUtil.assertStorable(props.default)

	local self = setmetatable({
		_key = props.key,
		_dataStore = props.dataStore,
		_check = props.check,
		_default = deepFreeze(props.default),
		_open = false,
		_sessionId = SaveUtil.uuid(),
		_preHooks = {
			Open = {},
			Close = {},
			Update = {},
			Read = {},
		},
		_postHooks = {
			Open = {},
			Close = {},
			Update = {},
			Read = {},
		},
		_failHooks = {
			Open = {},
			Close = {},
			Update = {},
			Read = {},
		},
		_actionSignals = {
			Open = Signal.new(),
			Close = Signal.new(),
			Update = Signal.new(),
			Read = Signal.new(),
			Cache = Signal.new(),
		},
		_migrations = deepFreeze(props.migrations),
		_isClosing = false,
		_cache = props.default,
		_lockSessions = props.lockSessions,
		_shouldSteal = false,
	}, Document)

	return self
end


function Document.Open<T>(self: Document<T>): OpenResult<T>
	assert(not self._open, `{self} already open`)
	assert(not self._isClosing, `{self} is closing, cannot open`)


	local lockedByOther: boolean
	local incompatibleVersion: boolean
	local failedCheck: boolean
	local notStorable: boolean
	local notStorableErr: string
	local transformInvalid: boolean
	local migrationErrored: boolean
	local migrationErr: string

	runHooks(self._preHooks.Open)

	local updateOk, updatedKeyData = SaveUtil.updateAsync(function(abortAttempt, getValue): KeyData<T>?

		lockedByOther = false
		incompatibleVersion = false
		failedCheck = false

		local dataToMigrate: unknown
		local keyData: KeyData<unknown>?

		if getValue then
			keyData = checkKeyData(getValue)


			if keyData then
				dataToMigrate = keyData.data
			else
				print("Key non-empty but does not contain valid keyData, using value as data field")
				dataToMigrate = if typeof(getValue) == "table" then getValue else { getValue }
			end
		else
			dataToMigrate = self._default
		end

		local savedVersion = 0
		if dataToMigrate == self._default then
			savedVersion = #self._migrations
		end
		if keyData then
			savedVersion = keyData.dataSchemaVersion
		end

		local success, migrateResult = pcall(function()
			return runMigrations(self._migrations, dataToMigrate, savedVersion)
		end)

		if not success then
			migrationErrored = true
			migrationErr = migrateResult :: any

			return
		end

		local migratedData = migrateResult


		if keyData then

			if #self._migrations < keyData.lastCompatibleVersion then
				incompatibleVersion = true

				return
			end

			local locked = isLocked(keyData)
			local lockedByUs = locked and (keyData.sessionLockId == self._sessionId)

			if locked and not lockedByUs and not self._shouldSteal then
				lockedByOther = true
				abortAttempt(`Session lock held by another session for {self}.`)

				return
			end
		end

		local checkOk = self._check(migratedData)

		if not checkOk then
			failedCheck = true

			return
		end


		local data = migratedData :: T

		if self._onOpenTransform then
			data = self._onOpenTransform(data)
		end

		local newDataIsValid = self._check(data)
		newDataIsValid = newDataIsValid and typeof(data) == "table"

		local isStorable, err = pcall(function()
			SaveUtil.assertStorable(data)
		end)

		if not isStorable then
			notStorable = true
			notStorableErr = err

			return
		end

		if not newDataIsValid then
			transformInvalid = true

			return
		end

		self._cache = deepFreeze(data)

		return {
			documentServiceSchemaVersion = INTERNAL_SCHEMA_VERSION,
			sessionLockId = self._sessionId,
			lockTimestamp = os.time(),
			isLocked = self._lockSessions,

			dataSchemaVersion = math.max(#self._migrations, savedVersion),
			lastCompatibleVersion = getLastCompatibleVersion(self._migrations),
			data = data,
		}
	end, self._dataStore, self._key)

	local failResult: OpenResult<T>?

	if not updateOk then
		failResult = {
			success = false,
			reason = "RobloxAPIError",
		}
	end


	if lockedByOther then
		failResult = {
			success = false,
			reason = "SessionLockedError",
		}
	end


	if failedCheck then
		failResult = {
			success = false,
			reason = "CheckError",
		}
	end


	if incompatibleVersion then
		failResult = {
			success = false,
			reason = "BackwardsCompatibilityError",
		}
	end

	if failResult then
		runHooks(self._failHooks.Open)

		self._actionSignals.Open:Fire(failResult)

		return failResult
	end

	-- These throws happen after the before-open hook incremented the store's
	-- opening count. Skipping the fail hook left that count stuck, so
	-- CloseAllDocuments waited forever.
	if transformInvalid then
		runHooks(self._failHooks.Open)
		error(
			`Could not open Document {self._key}. Invalid transform function - must return a table that passes the check function.`
		)
	end

	if notStorable then
		runHooks(self._failHooks.Open)
		error(`Could not open Document {self._key}. Not storable: {notStorableErr}`)
	end

	if migrationErrored then
		runHooks(self._failHooks.Open)
		error(`Could not open Document {self._key}. Migrations errored: {migrationErr}`)
	end

	self._open = true


	self._shouldSteal = false


	self._autoSaveThread = task.defer(function()
		while self._lockSessions and self._open do
			task.wait(AUTOSAVE_INTERVAL)

			local result = self:Save()

			if not result.success then
				warn(`[DocumentService] AutoSave for key {self._key} failed due to a {result.reason}`)
			end
		end
	end)

	runHooks(self._postHooks.Open)

	local result: OpenResult<T> = {
		success = true,
		data = (updatedKeyData :: KeyData<T>).data,
	}

	self._actionSignals.Open:Fire(result)

	return result
end


function Document.OpenAndUpdate<T>(self: Document<T>, transform: Transform<T>): OpenResult<T>
	assert(not self._open, `{self} already open`)
	assert(not self._isClosing, `{self} is closing, cannot open`)

	runHooks(self._preHooks.Update)

	self._onOpenTransform = transform

	local result = self:Open()

	self._onOpenTransform = nil

	self._actionSignals.Update:Fire(result)

	if result.success then
		runHooks(self._postHooks.Update)

		return result
	else
		runHooks(self._failHooks.Update)

		return result
	end
end


function Document.Steal<T>(self: Document<T>)
	assert(not self._isClosing, "Document is closing")
	assert(self._lockSessions, "Stealing locks is only applicable to session-locked Documents")

	self._shouldSteal = true
end


function Document.GetOpenedSignal<T>(self: Document<T>): Signal.Signal<OpenResult<T>>
	return self._actionSignals.Open
end


function Document.GetClosedSignal<T>(self: Document<T>): Signal.Signal<WriteResult<T?>>
	return self._actionSignals.Close
end


function Document.GetUpdatedSignal<T>(self: Document<T>): Signal.Signal<WriteResult<T>>
	return self._actionSignals.Update
end


function Document.GetReadSignal<T>(self: Document<T>): Signal.Signal<ReadResult<T>>
	return self._actionSignals.Read
end


function Document.GetCacheChangedSignal<T>(self: Document<T>): Signal.Signal<T>
	return self._actionSignals.Cache
end


function Document.IsOpenAvailable<T>(self: Document<T>): Result<boolean, RobloxAPIError>
	assert(not self._isClosing, "Document is closing")

	if self._open then
		return {
			success = true,
			data = false,
		}
	end

	if not self._lockSessions then
		return {
			success = true,
			data = true,
		}
	end

	local success, getValue: any = SaveUtil.getAsync(self._dataStore, self._key)

	if not success then
		return {
			success = false,
			reason = "RobloxAPIError",
		}
	end

	local keyData = checkKeyData(getValue)


	if not keyData then
		return {
			success = true,
			data = true,
		}
	end

	local locked = isLocked(keyData)
	local lockedByUs = locked and (keyData.sessionLockId == self._sessionId)

	return {
		success = true,
		data = (not locked) or lockedByUs,
	}
end


function Document.IsOpen<T>(self: Document<T>): boolean
	return self._open
end


function Document.Close<T>(self: Document<T>): WriteResult<T?>
	assert(self._open, "Document not open")

	runHooks(self._preHooks.Close)


	self._isClosing = true

	local saveResult: WriteResult<T>

	if self._lockSessions then
		local saveOk, saveOutcome = pcall(function()
			return self:Save()
		end)
		if not saveOk then
			-- Save() throws on a non-storable cache. Leaving _isClosing set made
			-- shutdown wait forever, and the caller's retry loop never ran.
			self._isClosing = false
			saveResult = {
				success = false,
				reason = "RobloxAPIError",
			}
			runHooks(self._failHooks.Close)
			self._actionSignals.Close:Fire(saveResult)
			return saveResult
		end
		saveResult = saveOutcome


		if not saveResult.success then
			self._isClosing = false

			runHooks(self._failHooks.Close)
			self._actionSignals.Close:Fire(saveResult)

			return saveResult
		end
	end

	if self._autoSaveThread then
		task.cancel(self._autoSaveThread)
	end

	self._open = false
	self._isClosing = false

	runHooks(self._postHooks.Close)

	local result: WriteResult<T?> = {
		success = true,
	}


	if self._lockSessions then
		result = saveResult
	end

	self._actionSignals.Close:Fire(result)

	return result
end


function Document.IsClosing<T>(self: Document<T>): boolean
	return self._isClosing
end


function Document.SetCache<T>(self: Document<T>, newCache: T): T
	assert(self._open, "Document not open")
	assert(self._lockSessions, "Cache is only supported for session locked data")

	self._cache = deepFreeze(newCache)

	self._actionSignals.Cache:Fire(newCache)

	return self._cache
end


function Document.GetCache<T>(self: Document<T>): T
	assert(self._open, "Document not open")
	assert(self._lockSessions, "Cache is only supported for session locked data")

	return self._cache
end


function Document.Update<T>(self: Document<T>, transform: Transform<T>): WriteResult<T>
	assert(self._open, "Document not open")

	runHooks(self._preHooks.Update)

	local lockedByOther: boolean
	local transformInvalid: boolean
	local notStorable: boolean
	local schemaError: boolean
	local notStorableErr: string


	if self._lockSessions then

		local updatedData = transform(self._cache)
		if updatedData ~= self._cache then
			self:SetCache(updatedData)
		end
	end

	local success, updatedKeyData = SaveUtil.updateAsync(function(_abortAttempt, value: unknown): KeyData<T>?

		lockedByOther = false
		transformInvalid = false
		notStorable = false
		notStorableErr = ""

		local keyData = checkKeyData(value)

		if not keyData then
			schemaError = true

			return
		end


		local locked = isLocked(keyData)
		local lockedByUs = locked and (keyData.sessionLockId == self._sessionId)

		if locked and not lockedByUs then
			lockedByOther = true

			return
		end

		local newData
		if self._lockSessions then
			newData = self._cache
		else
			newData = transform(keyData.data)
		end

		local newDataIsValid = self._check(newData)
		newDataIsValid = newDataIsValid and typeof(newData) == "table"

		local isStorable, err = pcall(function()
			SaveUtil.assertStorable(newData)
		end)

		if not isStorable then
			notStorable = true
			notStorableErr = err

			return
		end

		if not newDataIsValid then
			transformInvalid = true

			return
		end

		return {
			documentServiceSchemaVersion = INTERNAL_SCHEMA_VERSION,
			sessionLockId = keyData.sessionLockId,
			lockTimestamp = os.time(),

			isLocked = if self._isClosing then false else lockedByUs,
			data = newData,
			dataSchemaVersion = keyData.dataSchemaVersion,
			lastCompatibleVersion = keyData.lastCompatibleVersion,
		}
	end, self._dataStore, self._key)


	if transformInvalid then
		error("Invalid transform function - must return a table that passes the check function.")
	end

	if notStorable then
		error("Not storable: " .. notStorableErr)
	end

	local failResult: WriteResult<T>?

	if not success then
		failResult = {
			success = false,
			reason = "RobloxAPIError",
		}
	end

	if lockedByOther then
		failResult = {
			success = false,
			reason = "SessionLockedError",
		}
	end

	if schemaError then
		failResult = {
			success = false,
			reason = "SchemaError",
		}
	end

	if failResult then
		runHooks(self._failHooks.Update)

		self._actionSignals.Update:Fire(failResult)

		return failResult
	end


	local updatedData: T = (updatedKeyData :: KeyData<T>).data

	runHooks(self._postHooks.Update)

	local result: WriteResult<T> = {
		success = true,
		data = updatedData,
	}

	self._actionSignals.Update:Fire(result)

	return result
end


function Document.Save<T>(self: Document<T>): WriteResult<T>
	assert(self._open, "Document not open")
	assert(self._lockSessions, "Must be session locked to access cache")

	return self:Update(function(cache)
		return cache
	end)
end


function Document.Erase<T>(self: Document<T>): Result<nil, RobloxAPIError>
	assert(not self._open, "Cannot erase an open document")

	local success = SaveUtil.removeAsync(self._dataStore, self._key)

	if not success then
		return {
			success = false,
			reason = "RobloxAPIError",
		}
	end

	return {
		success = true,
	}
end


function Document.Read<T>(self: Document<T>): ReadResult<T>
	runHooks(self._preHooks.Read)

	local success, getValue: any = SaveUtil.getAsync(self._dataStore, self._key)

	if not success then
		runHooks(self._failHooks.Read)

		local result: ReadResult<T> = {
			success = false,
			reason = "RobloxAPIError",
		}

		self._actionSignals.Read:Fire(result)

		return result
	end

	local keyData = checkKeyData(getValue)

	if not keyData then
		runHooks(self._failHooks.Read)

		local result: ReadResult<T> = {
			success = false,
			reason = "SchemaError",
		}

		self._actionSignals.Read:Fire(result)

		return result
	end

	local migratedData = runMigrations(self._migrations, keyData.data, keyData.dataSchemaVersion)

	local checkOk = self._check(migratedData)

	if not checkOk then
		runHooks(self._failHooks.Read)

		local result: ReadResult<T> = {
			success = false,
			reason = "CheckError",
		}

		self._actionSignals.Read:Fire(result)

		return result
	end

	local data = migratedData :: T

	if #self._migrations < keyData.lastCompatibleVersion then
		runHooks(self._failHooks.Read)

		local result: ReadResult<T> = {
			success = false,
			reason = "BackwardsCompatibilityError",
		}

		self._actionSignals.Read:Fire(result)

		return result
	end

	runHooks(self._postHooks.Read)

	local result: ReadResult<T> = {
		success = true,
		data = data,
	}

	self._actionSignals.Read:Fire(result)

	return result
end

local function cleanupHook(hooks: { () -> () }, hook: () -> ())
	local index = table.find(hooks, hook)

	if not index then
		error(`Failed to cleanup "{hook}" hook, not found in the given "{hooks}" hooks event registry!`)
	end

	table.remove(hooks, index)
end


function Document.HookBefore<T, S...>(self: Document<T>, event: HookEvent, hook: () -> ()): () -> ()
	local hooks = self._preHooks[event]
	table.insert(hooks, hook)

	return function()
		cleanupHook(hooks, hook)
	end
end


function Document.HookAfter<T>(self: Document<T>, event: HookEvent, hook: () -> ()): () -> ()
	local hooks = self._postHooks[event]
	table.insert(hooks, hook)

	return function()
		cleanupHook(hooks, hook)
	end
end


function Document.HookFail<T>(self: Document<T>, event: HookEvent, hook: () -> ()): () -> ()
	local hooks = self._failHooks[event]
	table.insert(hooks, hook)

	return function()
		cleanupHook(hooks, hook)
	end
end


function Document.OnceBefore<T, S...>(self: Document<T>, event: HookEvent, hook: () -> ())
	local cleanup

	cleanup = Document.HookBefore(self, event, function()
		cleanup()
		hook()
	end)
end


function Document.OnceAfter<T>(self: Document<T>, event: HookEvent, hook: () -> ())
	local cleanup

	cleanup = Document.HookAfter(self, event, function()
		cleanup()
		hook()
	end)
end


function Document.OnceFail<T>(self: Document<T>, event: HookEvent, hook: () -> ())
	local cleanup

	cleanup = Document.HookFail(self, event, function()
		cleanup()
		hook()
	end)
end


function Document.__tostring<T>(self: Document<T>)
	return `Document: {self._key}`
end


function Document.isDocument(instance: any): boolean
	return getmetatable(instance).__index == Document
end

return Document
