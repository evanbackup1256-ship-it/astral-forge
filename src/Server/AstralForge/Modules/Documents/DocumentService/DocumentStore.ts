import Document = require("./Document");
import Types = require("./Types");
import Util = require("./SaveUtil");
import deepFreeze = require("./DeepFreeze");

const CLOSE_PASS_INTERVAL = 1;

type Migrations = Types.Migrations;
type DataStoreInterface = Types.DataStoreInterface;

type DocumentStoreProps<T> = Types.DocumentStoreProps<T>;

let gameClosing = false;

class DocumentStore<T extends object> {
	_dataStore: DataStoreInterface;
	_check: DocumentStoreProps<T>["check"];
	_default: T;
	_migrations: Migrations;
	_documents: Map<string, Document<T>>;
	_lockSessions: boolean;
	_openingDocuments: number;
	_documentsToClose: number;

	constructor(props: DocumentStoreProps<T>) {
		this._dataStore = props.dataStore;
		this._check = props.check;
		this._default = deepFreeze(props.default);
		this._migrations = deepFreeze(props.migrations ?? []);
		this._documents = setmetatable(new Map<string, Document<T>>(), { __mode: "v" } as LuaMetatable<
			Map<string, Document<T>>
		>);
		this._lockSessions = props.lockSessions;
		this._openingDocuments = 0;
		this._documentsToClose = 0;

		if (props.bindToClose !== false) {
			game.BindToClose(() => {
				gameClosing = true;

				this.CloseAllDocuments();
			});
		}
	}

	GetDocument(key: string): LuaTuple<[Document<T>, boolean]> {
		assert(!gameClosing, "Cannot retrieve document, game closing");

		const existing = this._documents.get(key);
		if (existing) {
			return $tuple(existing, false);
		}

		const document = new Document<T>({
			key: key,
			dataStore: this._dataStore,
			check: this._check,
			default: this._default,
			migrations: this._migrations,
			lockSessions: this._lockSessions,
		});

		document.HookBefore("Open", () => {
			this._openingDocuments += 1;
		});

		document.HookFail("Open", () => {
			this._openingDocuments -= 1;
		});

		document.HookAfter("Open", () => {
			this._openingDocuments -= 1;
			this._documentsToClose += 1;
		});

		document.HookAfter("Close", () => {
			this._documentsToClose -= 1;
		});

		this._documents.set(key, document);

		return $tuple(document, true);
	}

	CloseAllDocuments() {
		const thread = coroutine.running();

		let complete = this._documentsToClose === 0 && this._openingDocuments === 0;

		while (!complete) {
			const budget = Util.getUpdateBudget();
			let documentsToClose = math.min(this._documentsToClose, budget);
			let requestCount = 0;

			for (const [, v] of pairs(this._documents)) {
				if (!v.IsOpen()) {
					continue;
				}

				if (requestCount >= budget) {
					break;
				}

				requestCount += 1;

				task.spawn(() => {
					if (v.IsOpen() && !v.IsClosing()) {
						v.Close();
					}

					if (v.IsClosing()) {
						do {
							task.wait();
						} while (v.IsClosing());
					}

					documentsToClose -= 1;

					if (documentsToClose === 0) {
						if (coroutine.status(thread) !== "suspended") {
							return;
						}

						task.defer(thread);
					}
				});
			}

			if (documentsToClose > 0) {
				coroutine.yield();
			}

			complete = this._documentsToClose === 0 && this._openingDocuments === 0;

			if (!complete) {
				task.wait(CLOSE_PASS_INTERVAL);
			}
		}
	}

	static isDocumentStore(this: void, instance: unknown): boolean {
		return (getmetatable(instance as object) as { __index?: unknown }).__index === DocumentStore;
	}
}

export = DocumentStore;
