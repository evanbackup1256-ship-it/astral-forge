// Re-broadcasts the server's effect pushes locally so views can subscribe at any time, even
// before the network is connected (chat, guild chat).
import { Controller, OnInit } from "@flamework/core";
import { NetworkController } from "./NetworkController";

@Controller({ loadOrder: 1 })
export class EffectFeedController implements OnInit {
	private readonly feed = new Instance("BindableEvent");

	constructor(private readonly network: NetworkController) {}

	onInit() {
		this.network.onConnected((network) => {
			const connection = network.events.effect.connect((payload) => this.feed.Fire(payload));
			return () => connection.Disconnect();
		});
	}

	/** Same shape as a remote's OnClientEvent connection. */
	connect(callback: (payload: unknown) => void): RBXScriptConnection {
		return this.feed.Event.Connect(callback);
	}
}
