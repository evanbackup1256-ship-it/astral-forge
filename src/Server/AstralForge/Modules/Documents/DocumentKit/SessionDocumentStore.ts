import DocumentCommon = require("./DocumentCommon");
import type Types = require("../DocumentService/Types");
import SessionDocument = require("./SessionDocument");

interface WrappedStore {
	GetDocument(key: string): LuaTuple<[unknown, boolean]>;
	CloseAllDocuments(): void;
}

class SessionDocumentStore {
	_store: WrappedStore;

	constructor(props: Types.StoreProps) {
		this._store = new DocumentCommon.DocumentStore(
			DocumentCommon.baseStoreProps(props, true),
		) as unknown as WrappedStore;
	}

	GetDocument(key: string): LuaTuple<[SessionDocument, boolean]> {
		const [document, created] = this._store.GetDocument(key);
		return $tuple(SessionDocument.wrap(document), created);
	}

	CloseAllDocuments() {
		this._store.CloseAllDocuments();
	}

	Unwrap() {
		return this._store;
	}
}

export = SessionDocumentStore;