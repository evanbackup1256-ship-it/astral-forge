// Background client systems that talk to the server: presence heartbeat, performance
// telemetry and the ping probe. Each starts when the network connects and stops on disconnect.
import { Controller, OnInit } from "@flamework/core";
import { startSession } from "../CoreKit/session";
import { startPerformanceTelemetry } from "../CoreKit/log";
import { watchPing } from "../MotionKit/antilag";
import { NetworkController } from "./NetworkController";

@Controller({ loadOrder: 2 })
export class PresenceController implements OnInit {
	constructor(private readonly network: NetworkController) {}
	onInit() {
		this.network.onConnected((network) => startSession({ Request: network.functions.request }) as () => void);
	}
}

@Controller({ loadOrder: 2 })
export class TelemetryController implements OnInit {
	constructor(private readonly network: NetworkController) {}
	onInit() {
		this.network.onConnected((network) => startPerformanceTelemetry(network.functions.request));
	}
}

@Controller({ loadOrder: 2 })
export class PingController implements OnInit {
	constructor(private readonly network: NetworkController) {}
	onInit() {
		this.network.onConnected((network) => watchPing(network.functions.request, "MeasureLatency"));
	}
}
