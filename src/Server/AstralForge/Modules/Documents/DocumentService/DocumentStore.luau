--!strict


local Document = require(script.Parent:FindFirstChild("Document"))
local Types = require(script.Parent:FindFirstChild("Types"))
local Util = require(script.Parent:FindFirstChild("SaveUtil"))
local deepFreeze = require(script.Parent:FindFirstChild("DeepFreeze"))

local CLOSE_PASS_INTERVAL = 1


local DocumentStore = {}
DocumentStore.__index = DocumentStore

export type DocumentStoreProps<T> = {
	dataStore: DataStoreInterface,
	check: (unknown) -> (boolean, T),
	default: T & {},
	migrations: Migrations?,
	lockSessions: boolean,
	bindToClose: boolean?,
}

export type DocumentStore<T> = typeof(setmetatable(
	{} :: {
		_dataStore: DataStoreInterface,
		_check: (unknown) -> (boolean, T),
		_default: T & {},
		_migrations: Types.Migrations,
		_documents: typeof(setmetatable({} :: { [string]: Document<T> }, { { __mode = "v" } })),

		_lockSessions: boolean,
		_openingDocuments: number,
		_documentsToClose: number,
	},
	DocumentStore
))

local gameClosing = false

type Document<T> = Document.Document<T>

type Migrations = Types.Migrations

type DataStoreInterface = Types.DataStoreInterface



function DocumentStore.new<T>(props: DocumentStoreProps<T>): DocumentStore<T>
	local self = setmetatable({
		_dataStore = props.dataStore,
		_check = props.check,
		_default = deepFreeze(props.default),
		_migrations = deepFreeze(props.migrations or {}),
		_documents = setmetatable({}, { __mode = "v" }),
		_lockSessions = props.lockSessions,
		_openingDocuments = 0,
		_documentsToClose = 0,
	}, DocumentStore)


	if props.bindToClose ~= false then
		game:BindToClose(function()
			gameClosing = true

			self:CloseAllDocuments()
		end)
	end

	return self
end


function DocumentStore.GetDocument<T>(self: DocumentStore<T>, key: string): (Document<T>, boolean)
	assert(not gameClosing, "Cannot retrieve document, game closing")

	if self._documents[key] then
		return self._documents[key], false
	end

	local document = Document.new({
		key = key,
		dataStore = self._dataStore,
		check = self._check,
		default = self._default,
		migrations = self._migrations,
		lockSessions = self._lockSessions,
	})

	document:HookBefore("Open", function()
		self._openingDocuments += 1
	end)

	document:HookFail("Open", function()
		self._openingDocuments -= 1
	end)

	document:HookAfter("Open", function()
		self._openingDocuments -= 1
		self._documentsToClose += 1
	end)

	document:HookAfter("Close", function()
		self._documentsToClose -= 1
	end)

	self._documents[key] = document

	return document, true
end


function DocumentStore.CloseAllDocuments<T>(self: DocumentStore<T>)
	local thread = coroutine.running()

	local complete = self._documentsToClose == 0 and self._openingDocuments == 0


	while not complete do

		local budget = Util.getUpdateBudget()
		local documentsToClose = math.min(self._documentsToClose, budget)
		local requestCount = 0

		for _, v: Document<T> in pairs(self._documents) do
			if not v:IsOpen() then
				continue
			end

			if requestCount >= budget then
				break
			end

			requestCount += 1

			task.spawn(function()
				if v:IsOpen() and not v:IsClosing() then
					v:Close()
				end

				if v:IsClosing() then
					repeat
						task.wait()
					until not v:IsClosing()
				end


				documentsToClose -= 1

				if documentsToClose == 0 then
					if coroutine.status(thread) ~= "suspended" then
						return
					end

					task.defer(thread)
				end
			end)
		end


		if documentsToClose > 0 then
			coroutine.yield()
		end

		complete = self._documentsToClose == 0 and self._openingDocuments == 0

		if not complete then
			task.wait(CLOSE_PASS_INTERVAL)
		end
	end
end


function DocumentStore.isDocumentStore(instance: any): boolean
	return getmetatable(instance).__index == DocumentStore
end

return DocumentStore
