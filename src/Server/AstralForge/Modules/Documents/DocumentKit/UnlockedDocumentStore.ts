import DocumentCommon = require("./DocumentCommon");
import type Types = require("../DocumentService/Types");
import OpenDocument = require("./OpenDocument");

interface WrappedStore {
	GetDocument(key: string): LuaTuple<[unknown, boolean]>;
	CloseAllDocuments(): void;
}

class UnlockedDocumentStore {
	_store: WrappedStore;

	constructor(props: Types.StoreProps) {
		this._store = new DocumentCommon.DocumentStore(
			DocumentCommon.baseStoreProps(props, false),
		) as unknown as WrappedStore;
	}

	GetDocument(key: string): LuaTuple<[OpenDocument, boolean]> {
		const [document, created] = this._store.GetDocument(key);
		return $tuple(OpenDocument.wrap(document), created);
	}

	CloseAllDocuments() {
		this._store.CloseAllDocuments();
	}

	Unwrap() {
		return this._store;
	}
}

export = UnlockedDocumentStore;