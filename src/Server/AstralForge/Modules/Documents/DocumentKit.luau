--!strict
--[=[
	DocumentKit: merged module suite.
	Members (5): SessionDocument, SessionDocumentStore, DocumentCommon, OpenDocument, UnlockedDocumentStore.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("DocumentKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("DocumentKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: SessionDocument   (merged from SessionDocument.luau, 109 lines)
-- ======================================================================
__defs["SessionDocument"] = function()


local DocumentCommon = __load("DocumentCommon")

type SessionDocument = {
	_doc: any,
	GetKey: (self: SessionDocument) -> string,
	IsOpen: (self: SessionDocument) -> boolean,
	IsClosing: (self: SessionDocument) -> boolean,
	Open: (self: SessionDocument) -> any,
	Steal: (self: SessionDocument) -> (),
	Close: (self: SessionDocument) -> any,
	GetCache: (self: SessionDocument) -> any,
	SetCache: (self: SessionDocument, newCache: any) -> any,
	Save: (self: SessionDocument) -> any,
	Update: (self: SessionDocument, transform: any) -> any,
	Erase: (self: SessionDocument) -> any,
	HookBefore: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookAfter: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookFail: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	GetCacheChangedSignal: (self: SessionDocument) -> any,
	GetOpenedSignal: (self: SessionDocument) -> any,
	GetClosedSignal: (self: SessionDocument) -> any,
	Unwrap: (self: SessionDocument) -> any,
}

local SessionDocument = {}
SessionDocument.__index = SessionDocument

function SessionDocument.wrap(document: any): SessionDocument
	return setmetatable({
		_doc = document,
	}, SessionDocument) :: any
end

function SessionDocument:GetKey(): string
	return tostring(self._doc)
end

function SessionDocument:IsOpen(): boolean
	return self._doc:IsOpen()
end

function SessionDocument:IsClosing(): boolean
	return self._doc:IsClosing()
end

function SessionDocument:Open()
	return self._doc:Open()
end

function SessionDocument:Steal()
	self._doc:Steal()
end

function SessionDocument:Close()
	return self._doc:Close()
end

function SessionDocument:GetCache()
	return self._doc:GetCache()
end

function SessionDocument:SetCache(newCache: any)
	return self._doc:SetCache(newCache)
end

function SessionDocument:Save()
	return self._doc:Save()
end

function SessionDocument:Update(transform: any)
	return self._doc:Update(transform)
end

function SessionDocument:Erase()
	return self._doc:Erase()
end

function SessionDocument:HookBefore(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookBefore(event, hook)
end

function SessionDocument:HookAfter(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookAfter(event, hook)
end

function SessionDocument:HookFail(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookFail(event, hook)
end

function SessionDocument:GetCacheChangedSignal()
	return self._doc:GetCacheChangedSignal()
end

function SessionDocument:GetOpenedSignal()
	return self._doc:GetOpenedSignal()
end

function SessionDocument:GetClosedSignal()
	return self._doc:GetClosedSignal()
end

function SessionDocument:Unwrap()
	return self._doc
end

return SessionDocument
end

-- ======================================================================
-- Module: SessionDocumentStore   (merged from SessionDocumentStore.luau, 37 lines)
-- ======================================================================
__defs["SessionDocumentStore"] = function()


local DocumentCommon = __load("DocumentCommon")
local SessionDocument = __load("SessionDocument")

type SessionDocumentStore = {
	_store: any,
	GetDocument: (self: SessionDocumentStore, key: string) -> (SessionDocument.SessionDocument, boolean),
	CloseAllDocuments: (self: SessionDocumentStore) -> (),
	Unwrap: (self: SessionDocumentStore) -> any,
}

local SessionDocumentStore = {}
SessionDocumentStore.__index = SessionDocumentStore

function SessionDocumentStore.new(props: DocumentCommon.StoreProps): SessionDocumentStore
	local store = DocumentCommon.DocumentStore.new(DocumentCommon.baseStoreProps(props, true))
	return setmetatable({
		_store = store,
	}, SessionDocumentStore) :: any
end

function SessionDocumentStore:GetDocument(key: string): (SessionDocument.SessionDocument, boolean)
	local document, created = self._store:GetDocument(key)
	return SessionDocument.wrap(document), created
end

function SessionDocumentStore:CloseAllDocuments()
	self._store:CloseAllDocuments()
end

function SessionDocumentStore:Unwrap()
	return self._store
end

return SessionDocumentStore
end

-- ======================================================================
-- Module: DocumentCommon   (merged from DocumentCommon.luau, 125 lines)
-- ======================================================================
__defs["DocumentCommon"] = function()


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function requireDocumentService()

	local sibling = script.Parent:FindFirstChild("DocumentService")
	if sibling then
		return (require :: any)(sibling)
	end


	sibling = script.Parent:WaitForChild("DocumentService", 5)
	if sibling then
		return (require :: any)(sibling)
	end


	local candidates: { Instance? } = {}
	local node: Instance? = script
	while node do
		table.insert(candidates, node:FindFirstChild("Packages"))
		node = node.Parent
	end
	local serverAstral = ServerScriptService:FindFirstChild("AstralForge")
	if serverAstral then
		table.insert(candidates, serverAstral:FindFirstChild("Packages"))
	end
	table.insert(candidates, ReplicatedStorage:FindFirstChild("Packages"))

	for _, packages in candidates do
		if packages then
			local module = packages:FindFirstChild("DocumentService")
			if module then
				return (require :: any)(module)
			end
		end
	end

	error(
		"[DocumentCommon] DocumentService module missing. Expected sibling "
			.. "ServerScriptService.AstralForge.Modules.Documents.DocumentService "
			.. "(vendored under src/server/Modules/Documents/DocumentService). "
			.. "Reconnect Rojo serving default.project.json.",
		0
	)
end

local DocumentService = requireDocumentService()

type HookEvent = "Open" | "Close" | "Update" | "Read"
type Migrations = {
	{
		backwardsCompatible: boolean,
		migrate: (data: any) -> any,
	}
}

local DocumentCommon = {}

DocumentCommon.DocumentService = DocumentService
DocumentCommon.DocumentStore = DocumentService.DocumentStore
DocumentCommon.Document = DocumentService.Document
DocumentCommon.SaveUtil = DocumentService.SaveUtil

function DocumentCommon.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[DocumentCommon.deepCopy(key)] = DocumentCommon.deepCopy(child)
	end
	return copy
end

function DocumentCommon.isOk(result: any): boolean
	return type(result) == "table" and result.success == true
end

function DocumentCommon.reason(result: any): string?
	if type(result) == "table" and result.success == false then
		return tostring(result.reason)
	end
	return nil
end

function DocumentCommon.okData(result: any): any
	if DocumentCommon.isOk(result) then
		return result.data
	end
	return nil
end

type StoreProps = {
	dataStore: any,
	check: (unknown) -> (boolean, any),
	default: any,
	migrations: Migrations?,
	bindToClose: boolean?,
}


function DocumentCommon.baseStoreProps(props: StoreProps, lockSessions: boolean)
	return {
		dataStore = props.dataStore,
		check = props.check,
		default = props.default,
		migrations = props.migrations or {},
		lockSessions = lockSessions,

		bindToClose = if props.bindToClose == nil then false else props.bindToClose,
	}
end

function DocumentCommon.permissiveTableCheck(value: unknown): (boolean, any)
	if type(value) ~= "table" then
		return false, value
	end
	return true, value
end

return DocumentCommon
end

-- ======================================================================
-- Module: OpenDocument   (merged from OpenDocument.luau, 109 lines)
-- ======================================================================
__defs["OpenDocument"] = function()


local DocumentCommon = __load("DocumentCommon")

type OpenDocument = {
	_doc: any,
	GetKey: (self: OpenDocument) -> string,
	IsOpen: (self: OpenDocument) -> boolean,
	IsClosing: (self: OpenDocument) -> boolean,
	Open: (self: OpenDocument) -> any,
	OpenAndUpdate: (self: OpenDocument, transform: any) -> any,
	Close: (self: OpenDocument) -> any,
	Update: (self: OpenDocument, transform: any) -> any,
	Read: (self: OpenDocument) -> any,
	Erase: (self: OpenDocument) -> any,
	IsOpenAvailable: (self: OpenDocument) -> any,
	HookBefore: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookAfter: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookFail: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	GetOpenedSignal: (self: OpenDocument) -> any,
	GetClosedSignal: (self: OpenDocument) -> any,
	GetUpdatedSignal: (self: OpenDocument) -> any,
	GetReadSignal: (self: OpenDocument) -> any,
	Unwrap: (self: OpenDocument) -> any,
}

local OpenDocument = {}
OpenDocument.__index = OpenDocument

function OpenDocument.wrap(document: any): OpenDocument
	return setmetatable({
		_doc = document,
	}, OpenDocument) :: any
end

function OpenDocument:GetKey(): string
	return tostring(self._doc)
end

function OpenDocument:IsOpen(): boolean
	return self._doc:IsOpen()
end

function OpenDocument:IsClosing(): boolean
	return self._doc:IsClosing()
end

function OpenDocument:Open()
	return self._doc:Open()
end

function OpenDocument:OpenAndUpdate(transform: any)
	return self._doc:OpenAndUpdate(transform)
end

function OpenDocument:Close()
	return self._doc:Close()
end

function OpenDocument:Update(transform: any)
	return self._doc:Update(transform)
end

function OpenDocument:Read()
	return self._doc:Read()
end

function OpenDocument:Erase()
	return self._doc:Erase()
end

function OpenDocument:IsOpenAvailable()
	return self._doc:IsOpenAvailable()
end

function OpenDocument:HookBefore(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookBefore(event, hook)
end

function OpenDocument:HookAfter(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookAfter(event, hook)
end

function OpenDocument:HookFail(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookFail(event, hook)
end

function OpenDocument:GetOpenedSignal()
	return self._doc:GetOpenedSignal()
end

function OpenDocument:GetClosedSignal()
	return self._doc:GetClosedSignal()
end

function OpenDocument:GetUpdatedSignal()
	return self._doc:GetUpdatedSignal()
end

function OpenDocument:GetReadSignal()
	return self._doc:GetReadSignal()
end

function OpenDocument:Unwrap()
	return self._doc
end

return OpenDocument
end

-- ======================================================================
-- Module: UnlockedDocumentStore   (merged from UnlockedDocumentStore.luau, 37 lines)
-- ======================================================================
__defs["UnlockedDocumentStore"] = function()


local DocumentCommon = __load("DocumentCommon")
local OpenDocument = __load("OpenDocument")

type UnlockedDocumentStore = {
	_store: any,
	GetDocument: (self: UnlockedDocumentStore, key: string) -> (OpenDocument.OpenDocument, boolean),
	CloseAllDocuments: (self: UnlockedDocumentStore) -> (),
	Unwrap: (self: UnlockedDocumentStore) -> any,
}

local UnlockedDocumentStore = {}
UnlockedDocumentStore.__index = UnlockedDocumentStore

function UnlockedDocumentStore.new(props: DocumentCommon.StoreProps): UnlockedDocumentStore
	local store = DocumentCommon.DocumentStore.new(DocumentCommon.baseStoreProps(props, false))
	return setmetatable({
		_store = store,
	}, UnlockedDocumentStore) :: any
end

function UnlockedDocumentStore:GetDocument(key: string): (OpenDocument.OpenDocument, boolean)
	local document, created = self._store:GetDocument(key)
	return OpenDocument.wrap(document), created
end

function UnlockedDocumentStore:CloseAllDocuments()
	self._store:CloseAllDocuments()
end

function UnlockedDocumentStore:Unwrap()
	return self._store
end

return UnlockedDocumentStore
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
