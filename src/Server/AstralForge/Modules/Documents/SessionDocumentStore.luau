--!strict


local DocumentCommon = require(script.Parent:WaitForChild("DocumentCommon"))
local SessionDocument = require(script.Parent:WaitForChild("SessionDocument"))

export type SessionDocumentStore = {
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
