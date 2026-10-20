// Owns the typed client handlers. Systems register with onConnected (before or after the
// connection exists); each returns a cleanup that runs on disconnect.
import { Controller } from "@flamework/core";
import { ClientLog } from "../CoreKit/log";
import { ClientNetwork, createClientNetwork } from "../ClientNetwork";

type ConnectedListener = (network: ClientNetwork) => (() => void) | void;

@Controller({ loadOrder: 0 })
export class NetworkController {
	private network?: ClientNetwork;
	private listeners: ConnectedListener[] = [];
	private cleanups: Array<() => void> = [];

	/** Called once the bridge folder exists. Creates the handlers and starts every listener. */
	connect(): ClientNetwork {
		if (this.network !== undefined) {
			return this.network;
		}
		const network = createClientNetwork();
		this.network = network;
		for (const listener of this.listeners) {
			this.run(listener, network);
		}
		return network;
	}

	onConnected(listener: ConnectedListener) {
		this.listeners.push(listener);
		if (this.network !== undefined) {
			this.run(listener, this.network);
		}
	}

	get(): ClientNetwork | undefined {
		return this.network;
	}

	disconnect() {
		const cleanups = this.cleanups;
		this.cleanups = [];
		for (const cleanup of cleanups) {
			pcall(cleanup);
		}
	}

	private run(listener: ConnectedListener, network: ClientNetwork) {
		const [ok, result] = pcall(listener, network);
		if (!ok) {
			ClientLog.warn("net", `network listener failed: ${tostring(result)}`);
		} else if (typeIs(result, "function")) {
			this.cleanups.push(result);
		}
	}
}
