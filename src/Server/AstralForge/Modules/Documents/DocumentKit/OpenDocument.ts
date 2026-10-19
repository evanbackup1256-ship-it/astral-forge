import type Types = require("../DocumentService/Types");

type HookEvent = Types.HookEvent;

// Thin wrapper over an unlocked DocumentService Document.
interface WrappedDocument {
	IsOpen(): boolean;
	IsClosing(): boolean;
	Open(): unknown;
	OpenAndUpdate(transform: unknown): unknown;
	Close(): unknown;
	Update(transform: unknown): unknown;
	Read(): unknown;
	Erase(): unknown;
	IsOpenAvailable(): unknown;
	HookBefore(event: HookEvent, hook: () => void): () => void;
	HookAfter(event: HookEvent, hook: () => void): () => void;
	HookFail(event: HookEvent, hook: () => void): () => void;
	GetOpenedSignal(): unknown;
	GetClosedSignal(): unknown;
	GetUpdatedSignal(): unknown;
	GetReadSignal(): unknown;
}

class OpenDocument {
	_doc: WrappedDocument;

	constructor(document: unknown) {
		this._doc = document as WrappedDocument;
	}

	static wrap(this: void, document: unknown): OpenDocument {
		return new OpenDocument(document);
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

	OpenAndUpdate(transform: unknown) {
		return this._doc.OpenAndUpdate(transform);
	}

	Close() {
		return this._doc.Close();
	}

	Update(transform: unknown) {
		return this._doc.Update(transform);
	}

	Read() {
		return this._doc.Read();
	}

	Erase() {
		return this._doc.Erase();
	}

	IsOpenAvailable() {
		return this._doc.IsOpenAvailable();
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

	GetOpenedSignal() {
		return this._doc.GetOpenedSignal();
	}

	GetClosedSignal() {
		return this._doc.GetClosedSignal();
	}

	GetUpdatedSignal() {
		return this._doc.GetUpdatedSignal();
	}

	GetReadSignal() {
		return this._doc.GetReadSignal();
	}

	Unwrap() {
		return this._doc;
	}
}

export = OpenDocument;