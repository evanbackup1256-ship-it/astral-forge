import type Types = require("../DocumentService/Types");

type HookEvent = Types.HookEvent;

// Thin wrapper over a session-locked DocumentService Document. The wrapped document is
// typed loosely because the store is created with any table-shaped data.
interface WrappedDocument {
	IsOpen(): boolean;
	IsClosing(): boolean;
	Open(): unknown;
	Steal(): void;
	Close(): unknown;
	GetCache(): unknown;
	SetCache(newCache: unknown): unknown;
	Save(): unknown;
	Update(transform: unknown): unknown;
	Erase(): unknown;
	HookBefore(event: HookEvent, hook: () => void): () => void;
	HookAfter(event: HookEvent, hook: () => void): () => void;
	HookFail(event: HookEvent, hook: () => void): () => void;
	GetCacheChangedSignal(): unknown;
	GetOpenedSignal(): unknown;
	GetClosedSignal(): unknown;
}

class SessionDocument {
	_doc: WrappedDocument;

	constructor(document: unknown) {
		this._doc = document as WrappedDocument;
	}

	static wrap(this: void, document: unknown): SessionDocument {
		return new SessionDocument(document);
	}

	GetKey(): string {
		return tostring(this._doc);
	}

	IsOpen(): boolean {
		return this._doc.IsOpen();
	}

	IsClosing(): boolean {
		return this._doc.IsClosing();
	}

	Open() {
		return this._doc.Open();
	}

	Steal() {
		this._doc.Steal();
	}

	Close() {
		return this._doc.Close();
	}

	GetCache() {
		return this._doc.GetCache();
	}

	SetCache(newCache: unknown) {
		return this._doc.SetCache(newCache);
	}

	Save() {
		return this._doc.Save();
	}

	Update(transform: unknown) {
		return this._doc.Update(transform);
	}

	Erase() {
		return this._doc.Erase();
	}

	HookBefore(event: HookEvent, hook: () => void) {
		return this._doc.HookBefore(event, hook);
	}

	HookAfter(event: HookEvent, hook: () => void) {
		return this._doc.HookAfter(event, hook);
	}

	HookFail(event: HookEvent, hook: () => void) {
		return this._doc.HookFail(event, hook);
	}

	GetCacheChangedSignal() {
		return this._doc.GetCacheChangedSignal();
	}

	GetOpenedSignal() {
		return this._doc.GetOpenedSignal();
	}

	GetClosedSignal() {
		return this._doc.GetClosedSignal();
	}

	Unwrap() {
		return this._doc;
	}
}

export = SessionDocument;