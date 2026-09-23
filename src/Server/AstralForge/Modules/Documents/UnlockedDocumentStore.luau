--!strict


local DocumentCommon = require(script.Parent:WaitForChild("DocumentCommon"))
local OpenDocument = require(script.Parent:WaitForChild("OpenDocument"))

export type UnlockedDocumentStore = {
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
