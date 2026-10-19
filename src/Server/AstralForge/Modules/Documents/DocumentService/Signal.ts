// Linked-list signal (GoodSignal style). Kept as raw metatables so the strict
// "not a valid member" guards behave exactly like the original Luau module.

import type Types = require("./Types");

type Signal<T extends unknown[]> = Types.Signal<T>;

type Handler = (...args: unknown[]) => void;

interface ConnectionImpl {
	Connected: boolean;
	_signal: SignalImpl;
	_fn: Handler;
	_next: ConnectionImpl | false;
	Disconnect(): void;
}

interface SignalImpl {
	_handlerListHead: ConnectionImpl | false;
	_proxyHandler?: RBXScriptConnection;
	_yieldedThreads?: Map<thread, true>;
	Fire(...args: unknown[]): void;
	Once(fn: Handler): ConnectionImpl;
	Connect(fn: Handler): ConnectionImpl;
	DisconnectAll(): void;
}

let freeRunnerThread: thread | undefined;

function acquireRunnerThreadAndCallEventHandler(fn: Handler, ...args: unknown[]) {
	const acquiredRunnerThread = freeRunnerThread;
	freeRunnerThread = undefined;
	fn(...args);

	freeRunnerThread = acquiredRunnerThread;
}

function runEventHandlerInFreeThread(fn: Handler, ...args: unknown[]) {
	acquireRunnerThreadAndCallEventHandler(fn, ...args);
	while (true) {
		(acquireRunnerThreadAndCallEventHandler as (...resumed: unknown[]) => void)(
			...(coroutine.yield() as LuaTuple<unknown[]>),
		);
	}
}

const ConnectionClass = {} as Record<string, unknown>;
ConnectionClass.__index = ConnectionClass;

ConnectionClass.Disconnect = function (this: ConnectionImpl) {
	if (!this.Connected) {
		return;
	}
	this.Connected = false;

	if (this._signal._handlerListHead === this) {
		this._signal._handlerListHead = this._next;
	} else {
		let prev: ConnectionImpl | false = this._signal._handlerListHead;
		while (prev && prev._next !== this) {
			prev = prev._next;
		}
		if (prev) {
			prev._next = this._next;
		}
	}
};

ConnectionClass.Destroy = ConnectionClass.Disconnect;

setmetatable(ConnectionClass, {
	__index: (_tb: unknown, key: unknown) => {
		error("Attempt to get Connection::%s (not a valid member)".format(tostring(key)), 2);
	},
	__newindex: (_tb: unknown, key: unknown, _value: unknown) => {
		error("Attempt to set Connection::%s (not a valid member)".format(tostring(key)), 2);
	},
} as LuaMetatable<object>);

const SignalClass = {} as Record<string, unknown>;
SignalClass.__index = SignalClass;

function newSignal<T extends unknown[]>(): Signal<T> {
	const sig = setmetatable(
		{
			_handlerListHead: false,
			_proxyHandler: undefined,
			_yieldedThreads: undefined,
		},
		SignalClass as LuaMetatable<object>,
	);

	return sig as unknown as Signal<T>;
}

function Wrap<T extends unknown[]>(rbxScriptSignal: RBXScriptSignal): Signal<T> {
	assert(
		typeOf(rbxScriptSignal) === "RBXScriptSignal",
		"Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " + typeOf(rbxScriptSignal),
	);

	const signal = newSignal() as unknown as SignalImpl;
	signal._proxyHandler = rbxScriptSignal.Connect((...args: unknown[]) => {
		signal.Fire(...args);
	});

	return signal as unknown as Signal<T>;
}

function Is(obj: unknown): boolean {
	return typeIs(obj, "table") && getmetatable(obj) === SignalClass;
}

SignalClass.Connect = function (this: SignalImpl, fn: Handler) {
	const connection = setmetatable(
		{
			Connected: true,
			_signal: this,
			_fn: fn,
			_next: false,
		},
		ConnectionClass as LuaMetatable<object>,
	) as unknown as ConnectionImpl;

	if (this._handlerListHead) {
		connection._next = this._handlerListHead;
		this._handlerListHead = connection;
	} else {
		this._handlerListHead = connection;
	}

	return connection;
};

SignalClass.ConnectOnce = function (this: SignalImpl, fn: Handler) {
	return this.Once(fn);
};

SignalClass.Once = function (this: SignalImpl, fn: Handler) {
	let connection: ConnectionImpl | undefined;
	let done = false;

	connection = this.Connect((...args: unknown[]) => {
		if (done) {
			return;
		}

		done = true;
		connection!.Disconnect();
		fn(...args);
	});

	return connection;
};

SignalClass.GetConnections = function (this: SignalImpl) {
	const items: ConnectionImpl[] = [];

	let item = this._handlerListHead;
	while (item) {
		items.push(item);
		item = item._next;
	}

	return items;
};

SignalClass.DisconnectAll = function (this: SignalImpl) {
	let item = this._handlerListHead;
	while (item) {
		item.Connected = false;
		item = item._next;
	}
	this._handlerListHead = false;

	const yieldedThreads = rawget(this, "_yieldedThreads") as Map<thread, true> | undefined;
	if (yieldedThreads) {
		for (const [thread] of yieldedThreads) {
			if (coroutine.status(thread) === "suspended") {
				warn(debug.traceback(thread, "signal disconnected; yielded thread cancelled", 2));
				task.cancel(thread);
			}
		}
		table.clear(this._yieldedThreads!);
	}
};

SignalClass.Fire = function (this: SignalImpl, ...args: unknown[]) {
	let item = this._handlerListHead;
	while (item) {
		if (item.Connected) {
			if (!freeRunnerThread) {
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread);
			}
			task.spawn(freeRunnerThread, item._fn, ...args);
		}
		item = item._next;
	}
};

SignalClass.FireDeferred = function (this: SignalImpl, ...args: unknown[]) {
	let item = this._handlerListHead;
	while (item) {
		const conn = item;
		task.defer(
			(...deferredArgs: unknown[]) => {
				if (conn.Connected) {
					conn._fn(...deferredArgs);
				}
			},
			...args,
		);
		item = item._next;
	}
};

SignalClass.Wait = function (this: SignalImpl) {
	let yieldedThreads = rawget(this, "_yieldedThreads") as Map<thread, true> | undefined;
	if (!yieldedThreads) {
		yieldedThreads = new Map();
		rawset(this, "_yieldedThreads", yieldedThreads);
	}

	const thread = coroutine.running();
	yieldedThreads.set(thread, true);

	const threads = yieldedThreads;
	this.Once((...args: unknown[]) => {
		threads.delete(thread);
		task.spawn(thread, ...args);
	});

	return coroutine.yield();
};

SignalClass.Destroy = function (this: SignalImpl) {
	this.DisconnectAll();

	const proxyHandler = rawget(this, "_proxyHandler") as RBXScriptConnection | undefined;
	if (proxyHandler) {
		proxyHandler.Disconnect();
	}
};

setmetatable(SignalClass, {
	__index: (_tb: unknown, key: unknown) => {
		error("Attempt to get Signal::%s (not a valid member)".format(tostring(key)), 2);
	},
	__newindex: (_tb: unknown, key: unknown, _value: unknown) => {
		error("Attempt to set Signal::%s (not a valid member)".format(tostring(key)), 2);
	},
} as LuaMetatable<object>);

const SignalModule = table.freeze({
	new: newSignal,
	Wrap,
	Is,
});

export = SignalModule;
