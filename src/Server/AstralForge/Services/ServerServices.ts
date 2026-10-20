// The server service registry: every service is built lazily by name through loadService.
// GameService (the gameplay hub) lives in GameService.ts.
import { LoadService } from "./LuaInterop";
import { createGameService } from "./GameService";

type Factory = () => unknown;

const serviceFactories: Record<string, Factory> = {};
const serviceCache: Record<string, unknown> = {};
const serviceLoaded: Record<string, boolean> = {};
const serviceLoading: Record<string, boolean> = {};
// assigned once below, after every factory is registered
// eslint-disable-next-line prefer-const
let loadService: LoadService = undefined as unknown as LoadService;

const services = script.Parent!;
const req = (name: string) => require(services.WaitForChild(name) as ModuleScript);
const kitMember = (name: string, member: string) => (req(name) as (this: void, member: string) => unknown)(member);
const withLoader = (value: unknown) => (value as (this: void, loader: LoadService) => unknown)(loadService);

serviceFactories["AdminService"] = () => withLoader(req("AdminService"));

serviceFactories["AnomalyService"] = () => withLoader(kitMember("CoreServices", "AnomalyService"));

serviceFactories["BazaarService"] = () => withLoader(req("BazaarService"));
serviceFactories["SpecializationService"] = req("SpecializationService") as Factory;

serviceFactories["AtomicState"] = kitMember("SecurityServices", "AtomicState") as Factory;

serviceFactories["CharacterIntegrity"] = () => withLoader(req("CharacterIntegrity"));

serviceFactories["ConvergenceService"] = req("ConvergenceService") as Factory;

serviceFactories["DataService"] = () => withLoader(req("DataService"));

serviceFactories["ForgeEchoService"] = kitMember("CoreServices", "ForgeEchoService") as Factory;

serviceFactories["ServerEventService"] = kitMember("CoreServices", "ServerEventService") as Factory;

serviceFactories["GameAntiCheat"] = req("GameAntiCheat") as Factory;

serviceFactories["GameService"] = () => createGameService(loadService);

serviceFactories["GuildService"] = kitMember("CoreServices", "GuildService") as Factory;

serviceFactories["LabService"] = kitMember("CoreServices", "LabService") as Factory;

serviceFactories["MatterRuntime"] = req("MatterRuntime") as Factory;

serviceFactories["PlayerAnalytics"] = () => withLoader(req("PlayerAnalytics"));

serviceFactories["PlayerBadges"] = req("PlayerBadges") as Factory;

serviceFactories["ProfileIntegrity"] = kitMember("SecurityServices", "ProfileIntegrity") as Factory;

serviceFactories["ProgressionService"] = kitMember("CoreServices", "ProgressionService") as Factory;

serviceFactories["RemoteFirewall"] = () => withLoader(req("RemoteFirewall"));

serviceFactories["Security"] = kitMember("SecurityServices", "Security") as Factory;

serviceFactories["SessionGate"] = kitMember("SecurityServices", "SessionGate") as Factory;

serviceFactories["ServerTelemetry"] = kitMember("SecurityServices", "ServerTelemetry") as Factory;

serviceFactories["WorldService"] = kitMember("WorldServices", "WorldService") as Factory;

loadService = (name: string): unknown => {
	if (serviceLoaded[name]) {
		return serviceCache[name];
	}
	if (serviceLoading[name]) {
		error("[AF/server] circular service dependency: " + name, 2);
	}
	const factory = serviceFactories[name];
	if (factory === undefined) {
		error("[AF/server] unknown service: " + name, 2);
	}
	serviceLoading[name] = true;
	const [ok, result] = xpcall(factory, debug.traceback as unknown as (err: unknown) => string);
	delete serviceLoading[name];
	if (!ok) {
		error(result, 2);
	}
	serviceCache[name] = result;
	serviceLoaded[name] = true;
	return result;
};

const ServerServices = {};
setmetatable(ServerServices, {
	__index: (target: object, name: unknown) => {
		if (!typeIs(name, "string")) {
			return undefined;
		}
		const service = loadService(name);
		rawset(target, name, service);
		return service;
	},
	__newindex: () => {
		error("[AF/server] service registry is read-only", 2);
	},
	__metatable: "locked",
} as LuaMetatable<object>);

export = ServerServices;
