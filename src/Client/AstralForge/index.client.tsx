// The AstralForge LocalScript. Modules load in the original order, with a frame yielded between the
// heavy kits, so requires stay inline (ES imports would hoist them all to the top).
import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { Dict } from "./lua";

type Loose = (props: Dict) => React.Element | undefined;

const Lighting = game.GetService("Lighting");
const LocalizationService = game.GetService("LocalizationService");
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const StarterGui = game.GetService("StarterGui");
const TextChatService = game.GetService("TextChatService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");
const VRService = game.GetService("VRService");

function child(name: string): ModuleScript {
	return script.FindFirstChild(name) as ModuleScript;
}
function kit<T>(name: string, member: string): T {
	return (require(child(name)) as (member: string) => T)(member);
}
function load<T>(name: string): T {
	return require(child(name)) as T;
}

const MainGame = kit<{ MainGame: Loose }>("UiCore", "MainGame").MainGame;
task.wait();
const _antilag = kit<typeof import("./MotionKit/antilag")>("MotionKit", "antilag");
const AntilagProvider = _antilag.AntilagProvider;
const watchPing = _antilag.watchPing;
interface AudioApi {
	dispose(): void;
	setScene(scene: string): void;
}
const _audio = kit<{ Audio: AudioApi; hookGuiClicks: (this: void, root: Instance) => () => void }>("AudioKit", "audio");
const Audio = _audio.Audio;
const hookGuiClicks = _audio.hookGuiClicks;
task.wait();
const _BootScreen = kit<{ BOOT_MOTION: unknown; BootScreen: Loose }>("BootKit", "BootScreen");
const BOOT_MOTION = _BootScreen.BOOT_MOTION;
const BootScreen = _BootScreen.BootScreen;
const _clientStore = kit<typeof import("./CoreKit/clientStore")>("CoreKit", "clientStore");
const ClientActions = _clientStore.ClientActions;
const ClientStoreProvider = _clientStore.ClientStoreProvider;
const createClientStore = _clientStore.createClientStore;
const destroyClientStore = _clientStore.destroyClientStore;
const useClientDispatch = _clientStore.useClientDispatch;
const useClientSelector = _clientStore.useClientSelector;
task.wait();
const DomainChamber = kit<{ DomainChamber: Loose }>("UiOverlaysTs", "DomainChamber").DomainChamber;
task.wait();
const initializeClientFramework = load<{ initializeClientFramework: (this: void, root: Instance) => void }>(
	"frameworkBridge",
).initializeClientFramework;
const _log = kit<typeof import("./CoreKit/log")>("CoreKit", "log");
const beginClientSession = _log.beginClientSession;
const ClientLog = _log.ClientLog;
const markBootComplete = _log.markBootComplete;
const startPerformanceTelemetry = _log.startPerformanceTelemetry;
const MotionSettingsContext = kit<typeof import("./MotionKit/motion")>("MotionKit", "motion").MotionSettingsContext;
const startEgooeHost = kit<{ startEgooeHost: (this: void, playerGui: PlayerGui) => () => void }>(
	"ReactHosts",
	"egooeHost",
).startEgooeHost;
const installScrollPerformance = kit<{ installScrollPerformance: (this: void) => () => void }>(
	"LayoutKit",
	"scrolling",
).installScrollPerformance;
const configureInputPlatform = kit<typeof import("./CoreKit/inputPlatform")>("CoreKit", "inputPlatform").configureInputPlatform;
const startSession = kit<typeof import("./CoreKit/session")>("CoreKit", "session").startSession;
const SoftShutdownScreen = kit<{ SoftShutdownScreen: Loose }>("BootKit", "SoftShutdownScreen").SoftShutdownScreen;
const Palette = kit<typeof import("./CoreKit/theme")>("CoreKit", "theme").Palette;
const PageErrorBoundary = kit<{ PageErrorBoundary: Loose }>("ReactHosts", "reactHost").PageErrorBoundary;
const PagePending = kit<{ PagePending: Loose }>("ReactHosts", "reactHost").PagePending;

const SCREEN_NAME = "AstralForgeStudioUI";
const REPLICATION_TIMEOUT = 15;
const CHILD_TIMEOUT = 8;
const bootConnections: RBXScriptConnection[] = [];

function trackBootConnection(connection: RBXScriptConnection): RBXScriptConnection {
	if (connection === undefined) {
		return connection;
	}
	bootConnections.push(connection);
	return connection;
}
function disconnectBootConnection(connection: RBXScriptConnection | undefined) {
	if (connection === undefined) {
		return undefined;
	}
	const index = bootConnections.indexOf(connection);
	if (index !== -1) {
		bootConnections.remove(index);
	}
	pcall(() => {
		connection.Disconnect();
	});
}
function disconnectBootConnections() {
	for (let index = bootConnections.size() - 1; index >= 0; index--) {
		const connection = bootConnections[index];
		bootConnections.pop();
		if (connection !== undefined) {
			pcall(() => {
				connection.Disconnect();
			});
		}
	}
}

const stopInputPlatform = configureInputPlatform();
task.spawn(() => {
	pcall(() => LocalizationService.GetTranslatorForPlayerAsync(Players.LocalPlayer));
});

interface DomainOverlay {
	mode: string;
	result?: unknown;
}
interface ActionResponse {
	ok?: unknown;
	DomainRank?: unknown;
	DomainEssence?: unknown;
	StardustReward?: unknown;
	OverflowReward?: unknown;
	FreeSpins?: unknown;
	NextRequiredRebirths?: unknown;
	NextRequiredCores?: unknown;
}
type Dispatch = (action: string, payload: Dict, callback: (response: ActionResponse) => void) => void;

function DomainApp(props: Dict) {
	const overlay = useClientSelector((state) => state.domain.overlay) as DomainOverlay | undefined;
	const busy = useClientSelector((state) => state.domain.busy);
	const domainRank = useClientSelector(
		(state) => ((state.session?.Domain as { Rank?: number } | undefined)?.Rank ?? 0) as number,
	);
	const canExpand = useClientSelector(
		(state) => (state.session?.Domain as { CanExpand?: unknown } | undefined)?.CanExpand === true,
	);
	const dispatchStore = useClientDispatch();
	const open = React.useCallback(() => {
		if (busy) {
			return undefined;
		}
		if (domainRank > 0 && !canExpand) {
			dispatchStore(ClientActions.setDomainOverlay({ mode: "tree" }));
		} else {
			dispatchStore(ClientActions.setDomainOverlay({ mode: "confirm" }));
		}
	}, [busy, canExpand, dispatchStore, domainRank]);
	const render = React.useCallback(
		(state: Dict, dispatch: Dispatch, children: React.Element) => {
			const confirm = () => {
				if (busy) {
					return undefined;
				}
				dispatchStore(ClientActions.setDomainBusy(true));
				dispatch("DomainExpansion", {}, (response) => {
					dispatchStore(ClientActions.setDomainBusy(false));
					if (!(response.ok !== undefined && response.ok !== false) || response.DomainRank === undefined) {
						return undefined;
					}
					dispatchStore(
						ClientActions.setDomainOverlay({
							mode: "result",
							result: {
								rank: response.DomainRank,
								essence: response.DomainEssence ?? 0,
								stardust: response.StardustReward ?? 0,
								overflow: response.OverflowReward ?? 0,
								freeSpins: response.FreeSpins ?? 0,
								nextRebirths: response.NextRequiredRebirths ?? 0,
								nextCores: response.NextRequiredCores ?? 0,
							},
						}),
					);
				});
			};
			return (
				<>
					{children}
					{state.Domain !== undefined && overlay !== undefined && (
						<DomainChamber
							mode={overlay.mode === "tree" ? "lattice" : overlay.mode}
							domain={state.Domain}
							rebirths={state.Rebirths}
							cores={state.Cores}
							result={overlay.mode === "result" ? overlay.result : undefined}
							busy={busy}
							dispatch={dispatch}
							reducedMotion={false}
							onConfirm={confirm}
							onMode={(mode: string) => {
								dispatchStore(ClientActions.setDomainOverlay({ mode: mode === "lattice" ? "tree" : mode }));
							}}
							onClose={() => {
								if (busy) {
									return undefined;
								}
								dispatchStore(ClientActions.setDomainOverlay(undefined));
							}}
						/>
					)}
				</>
			);
		},
		[busy, dispatchStore, overlay],
	);
	const domainUi = React.useMemo(() => ({ open, active: overlay !== undefined, render }), [open, overlay, render]);
	const attributes = table.clone(props);
	setmetatable(attributes, undefined as unknown as LuaMetatable<Dict>);
	attributes.domainUi = domainUi;
	return React.createElement(MainGame, attributes);
}
const StableApp = React.memo(DomainApp);

function StartupFailure({ message }: { message: string }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BorderSizePixel={0} Active={true} ZIndex={500}>
			<frame
				Size={new UDim2(1, -32, 0, 190)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={Palette.night}
				BorderSizePixel={0}
				ZIndex={501}
			>
				<uisizeconstraint MaxSize={new Vector2(420, 190)} />
				<uicorner CornerRadius={new UDim(0, 18)} />
				<uistroke Color={Palette.coral} Thickness={2} Transparency={0.22} />
				<textlabel
					Size={new UDim2(1, -36, 0, 24)}
					Position={UDim2.fromOffset(18, 20)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text="STARTUP LINK LOST"
					TextColor3={Palette.coral}
					TextSize={16}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
					TextXAlignment={Enum.TextXAlignment.Center}
					ZIndex={502}
				/>
				<textlabel
					Size={new UDim2(1, -42, 0, 70)}
					Position={UDim2.fromOffset(21, 58)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text={message}
					TextColor3={Palette.creamSoft}
					TextSize={12}
					TextWrapped={true}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
					TextXAlignment={Enum.TextXAlignment.Center}
					TextYAlignment={Enum.TextYAlignment.Center}
					ZIndex={502}
				/>
				<textlabel
					Size={new UDim2(1, -36, 0, 20)}
					Position={UDim2.fromOffset(18, 149)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text="REJOIN TO TRY AGAIN"
					TextColor3={Palette.muted}
					TextSize={12}
					FontFace={Font.fromEnum(Enum.Font.RobotoMono)}
					TextXAlignment={Enum.TextXAlignment.Center}
					ZIndex={502}
				/>
			</frame>
		</frame>
	);
}

interface ShutdownState {
	phase: string;
	message: string;
}

function normalizeShutdown(raw: unknown, fallbackRevision: number): { revision: number; state: ShutdownState } | undefined {
	if (!typeIs(raw, "table")) {
		return undefined;
	}
	const payload = raw as { Revision?: unknown; Phase?: unknown; Message?: unknown };
	const revisionRaw = payload.Revision;
	const revision =
		typeIs(revisionRaw, "number") && revisionRaw === revisionRaw ? math.max(0, math.floor(revisionRaw)) : fallbackRevision;
	return {
		revision,
		state: {
			phase: string.sub(tostring(payload.Phase ?? "Saving"), 1, 48),
			message: string.sub(tostring(payload.Message ?? "Saving your progress."), 1, 180),
		},
	};
}

interface Remotes {
	Bridge: Folder;
	Request: RemoteFunction;
	State: RemoteEvent;
	Toast: RemoteEvent;
	Effect: RemoteEvent;
	Shutdown: RemoteEvent;
}
interface Connection {
	remotes: Remotes;
	config: { Game: { Version: string }; [key: string]: unknown };
}
interface BootstrapProps {
	connection?: Connection;
	failure?: string;
	startedAt: number;
	shutdownLayer?: Instance;
}
interface BootStatusFull {
	marks: unknown;
	ready: boolean;
	progress: number;
	reducedMotion: boolean;
	assetsLoaded?: unknown;
	assetsTotal?: unknown;
	modulesLoaded?: unknown;
	modulesTotal?: unknown;
}

function ClientBootstrap(props: BootstrapProps) {
	const { connection, failure, startedAt } = props;
	let shutdownLayer = props.shutdownLayer;
	const vrScreen = Players.LocalPlayer.FindFirstChild("PlayerGui")!.FindFirstChild("AstralForgeVR") as SurfaceGui | undefined;
	if (vrScreen && vrScreen.Enabled) {
		shutdownLayer = vrScreen.FindFirstChild("Overlay");
	}
	const status = useClientSelector((state) => state.boot.status) as unknown as BootStatusFull;
	const bootVisible = useClientSelector((state) => state.boot.visible);
	const dispatchStore = useClientDispatch();
	const [shutdownState, setShutdownState] = React.useState<ShutdownState>();
	const [bridgeFailure, setBridgeFailure] = React.useState<string>();
	const shutdownRevision = React.useRef(0);
	const shutdownActive = React.useRef(false);
	React.useEffect(() => {
		if (connection === undefined) {
			return undefined;
		}
		const syncFailure = () => {
			const problem = connection.remotes.Bridge.GetAttribute("BootFailure");
			if (!typeIs(problem, "string") || problem.size() === 0) {
				return undefined;
			}
			setBridgeFailure(string.sub(problem, 1, 240));
			pcall(() => StarterGui.SetCore("TopbarEnabled", true));
		};
		const changed = trackBootConnection(
			connection.remotes.Bridge.GetAttributeChangedSignal("BootFailure").Connect(syncFailure),
		);
		syncFailure();
		return () => {
			disconnectBootConnection(changed);
		};
	}, [connection]);
	React.useEffect(() => {
		if (connection === undefined) {
			return undefined;
		}
		const accept = (raw: unknown) => {
			const normalized = normalizeShutdown(raw, shutdownRevision.current + 1);
			if (normalized === undefined || normalized.revision <= shutdownRevision.current) {
				return undefined;
			}
			shutdownRevision.current = normalized.revision;
			shutdownActive.current = true;
			setShutdownState(normalized.state);
			pcall(() => StarterGui.SetCore("TopbarEnabled", false));
		};
		const syncBridge = () => {
			if (connection.remotes.Bridge.GetAttribute("ShuttingDown") !== true) {
				return undefined;
			}
			accept({
				Phase: connection.remotes.Bridge.GetAttribute("ShutdownPhase"),
				Message: connection.remotes.Bridge.GetAttribute("ShutdownMessage"),
				Revision: connection.remotes.Bridge.GetAttribute("ShutdownRevision"),
			});
		};
		const eventConnection = trackBootConnection(connection.remotes.Shutdown.OnClientEvent.Connect(accept));
		const attributeConnection = trackBootConnection(
			connection.remotes.Bridge.GetAttributeChangedSignal("ShutdownRevision").Connect(syncBridge),
		);
		syncBridge();
		return () => {
			disconnectBootConnection(eventConnection);
			disconnectBootConnection(attributeConnection);
		};
	}, [connection]);
	const bootVisibleRef = React.useRef(bootVisible);
	bootVisibleRef.current = bootVisible;
	const handleBootStatus = React.useCallback(
		(statusNext: unknown) => {
			if (bootVisibleRef.current) {
				dispatchStore(ClientActions.setBootStatus(statusNext as never));
			}
		},
		[dispatchStore],
	);
	const finishBoot = React.useCallback(() => {
		markBootComplete();
		bootVisibleRef.current = false;
		dispatchStore(ClientActions.setBootVisible(false));
		if (!shutdownActive.current) {
			pcall(() => StarterGui.SetCore("TopbarEnabled", true));
		}
	}, [dispatchStore]);
	const activeFailure = failure ?? bridgeFailure;
	if (activeFailure !== undefined) {
		return <StartupFailure message={activeFailure} />;
	}
	const app =
		connection !== undefined ? (
			<StableApp
				key="app"
				remotes={connection.remotes}
				config={connection.config}
				bootStartedAt={startedAt}
				externalBoot={true}
				externalAntilag={true}
				onBootStatus={handleBootStatus}
			/>
		) : undefined;
	const boot = bootVisible ? (
		<MotionSettingsContext.Provider key="boot" value={BOOT_MOTION as never}>
			<BootScreen
				marks={status.marks}
				ready={status.ready}
				progress={status.progress}
				version={connection?.config.Game.Version ?? "3.5.0 PRE-ALPHA"}
				reducedMotion={status.reducedMotion}
				startedAt={startedAt}
				assetsLoaded={status.assetsLoaded}
				assetsTotal={status.assetsTotal}
				modulesLoaded={status.modulesLoaded}
				modulesTotal={status.modulesTotal}
				onExitDone={finishBoot}
			/>
		</MotionSettingsContext.Provider>
	) : undefined;
	return React.createElement(
		AntilagProvider,
		undefined,
		app,
		boot,
		shutdownState !== undefined &&
			ReactRoblox.createPortal(
				<SoftShutdownScreen state={shutdownState} reducedMotion={status.reducedMotion} />,
				shutdownLayer as Instance,
			),
	);
}

interface VRHost {
	active: boolean;
	container?: Frame;
	dispose: () => void;
}

class ClientRuntime {
	disposers: Array<() => void> = [];
	disposed = false;
	playerGui: PlayerGui;
	screen: ScreenGui;
	shutdownLayer: ScreenGui;
	store: ReturnType<typeof createClientStore>;
	root: ReactRoblox.Root;
	vrHost: VRHost;
	lastElement?: React.Element;

	constructor(playerGui: PlayerGui) {
		this.playerGui = playerGui;
		const staleScreen = playerGui.FindFirstChild(SCREEN_NAME);
		if (staleScreen !== undefined && staleScreen.IsA("ScreenGui")) {
			staleScreen.Destroy();
		}
		const staleFx = playerGui.FindFirstChild("AstralForgeFx");
		if (staleFx !== undefined && staleFx.IsA("ScreenGui")) {
			staleFx.Destroy();
		}
		const staleShutdown = playerGui.FindFirstChild("AstralForgeShutdown");
		if (staleShutdown !== undefined && staleShutdown.IsA("ScreenGui")) {
			staleShutdown.Destroy();
		}
		const stopScrollPerformance = installScrollPerformance();
		const stopEgooe = startEgooeHost(playerGui);
		const shutdownVendor = kit<{ shutdown: (this: void) => void }>("ReactHosts", "vendorHost").shutdown;
		this.disposers.push(() => {
			stopScrollPerformance();
			stopEgooe();
			shutdownVendor();
		});
		const screen = new Instance("ScreenGui");
		screen.Name = SCREEN_NAME;
		screen.ResetOnSpawn = false;
		screen.IgnoreGuiInset = false;
		screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets;
		screen.ClipToDeviceSafeArea = true;
		screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None;
		screen.DisplayOrder = 80;
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		screen.Parent = playerGui;
		this.screen = screen;
		this.disposers.push(hookGuiClicks(playerGui));
		// every button shares the press/hover motion, including hand-built ones outside ui.Button
		this.disposers.push(load<typeof import("./ButtonMotion")>("ButtonMotion").attach(playerGui));
		// equipped artifacts orbit every character so other players can see them in the world
		this.disposers.push(load<typeof import("./ArtifactPresence")>("ArtifactPresence").attach());
		// crewmates get a tag above their heads so you can find them in the world
		this.disposers.push(load<typeof import("./CrewPresence")>("CrewPresence").attach());
		// game-feel layer: same insets as the main screen so effect positions line up with the UI
		const fxLayer = new Instance("ScreenGui");
		fxLayer.Name = "AstralForgeFx";
		fxLayer.ResetOnSpawn = false;
		fxLayer.IgnoreGuiInset = false;
		fxLayer.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets;
		fxLayer.ClipToDeviceSafeArea = true;
		fxLayer.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None;
		fxLayer.DisplayOrder = 200;
		fxLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		fxLayer.Parent = playerGui;
		const fxRoot = ReactRoblox.createRoot(fxLayer);
		fxRoot.render(React.createElement(load<{ Host: Loose }>("JuiceFx").Host));
		this.disposers.push(() => {
			fxRoot.unmount();
			fxLayer.Destroy();
		});
		const shutdownLayer = new Instance("ScreenGui");
		shutdownLayer.Name = "AstralForgeShutdown";
		shutdownLayer.ResetOnSpawn = false;
		shutdownLayer.IgnoreGuiInset = false;
		shutdownLayer.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets;
		shutdownLayer.ClipToDeviceSafeArea = true;
		shutdownLayer.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None;
		shutdownLayer.DisplayOrder = 260;
		shutdownLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		shutdownLayer.Parent = playerGui;
		this.shutdownLayer = shutdownLayer;
		this.store = createClientStore();
		this.root = ReactRoblox.createRoot(screen);
		this.vrHost = load<typeof import("./VRInterface")>("VRInterface").mount(playerGui, screen, (host) => {
			this.vrHost = host;
			if (this.lastElement !== undefined) {
				this.render(this.lastElement);
			}
		});
		this.disposers.push(this.vrHost.dispose);
		initializeClientFramework(screen);
		const destroying = trackBootConnection(screen.Destroying.Connect(() => this.dispose()));
		this.disposers.push(() => {
			disconnectBootConnection(destroying);
		});
		this.disposers.push(() => shutdownLayer.Destroy());
	}

	addDisposer(disposer: () => void) {
		if (this.disposed) {
			disposer();
			return undefined;
		}
		this.disposers.push(disposer);
	}

	render(element: React.Element) {
		if (this.disposed) {
			return undefined;
		}
		this.lastElement = element;
		let tree: React.Element = (
			<React.Suspense fallback={<PagePending />}>
				<PageErrorBoundary>
					<ClientStoreProvider store={this.store}>{element}</ClientStoreProvider>
				</PageErrorBoundary>
			</React.Suspense>
		);
		if (this.vrHost && this.vrHost.active) {
			tree = ReactRoblox.createPortal(
				<MotionSettingsContext.Provider
					value={{ soft: true, motionScale: 0, viewportScale: 1, textScale: 1 } as never}
				>
					{tree}
				</MotionSettingsContext.Provider>,
				this.vrHost.container as Instance,
			);
		}
		this.root.render(tree);
	}

	dispose() {
		if (this.disposed) {
			return undefined;
		}
		this.disposed = true;
		disconnectBootConnections();
		pcall(() => this.root.unmount());
		for (let index = this.disposers.size() - 1; index >= 0; index--) {
			const disposer = this.disposers[index];
			this.disposers.pop();
			pcall(disposer);
		}
		table.clear(this.disposers);
		const purchaseLayer = this.playerGui.FindFirstChild("AstralForgePurchase");
		if (purchaseLayer !== undefined && purchaseLayer.IsA("ScreenGui")) {
			purchaseLayer.Destroy();
		}
		destroyClientStore(this.store);
		Audio.dispose();
		pcall(() => StarterGui.SetCore("TopbarEnabled", true));
	}
}

function configureUiOnlyWorkspace(): () => void {
	if (VRService.VREnabled) {
		return () => {};
	}
	const lighting = Lighting;
	const previous = {
		globalShadows: lighting.GlobalShadows,
		brightness: lighting.Brightness,
		ambient: lighting.Ambient,
		outdoorAmbient: lighting.OutdoorAmbient,
		environmentDiffuse: lighting.EnvironmentDiffuseScale,
		environmentSpecular: lighting.EnvironmentSpecularScale,
		fogEnd: lighting.FogEnd,
		clockTime: lighting.ClockTime,
	};
	const parked = new Instance("Folder");
	parked.Name = "AF_ParkedLighting";
	pcall(() => {
		lighting.GlobalShadows = false;
		lighting.Brightness = 1;
		lighting.Ambient = Color3.fromRGB(26, 18, 30);
		lighting.OutdoorAmbient = Color3.fromRGB(26, 18, 30);
		lighting.EnvironmentDiffuseScale = 0;
		lighting.EnvironmentSpecularScale = 0;
		lighting.FogEnd = 1000000;
		lighting.ClockTime = 0;
	});
	pcall(() => {
		(lighting as unknown as { Technology: Enum.Technology }).Technology = Enum.Technology.Compatibility;
	});
	for (const item of lighting.GetChildren()) {
		if (item.IsA("PostEffect")) {
			item.Enabled = false;
		} else if (item.IsA("Atmosphere") || item.IsA("Sky") || item.IsA("Clouds")) {
			item.Parent = parked;
		}
	}
	const camera = Workspace.CurrentCamera;
	const previousCameraType = camera?.CameraType;
	const previousSubject = camera?.CameraSubject;
	if (camera !== undefined) {
		camera.CameraType = Enum.CameraType.Scriptable;
		camera.CameraSubject = undefined;
	}
	const mutedScripts = new Map<BaseScript, boolean>();
	const muteScripts = (instance: Instance | undefined) => {
		if (instance === undefined) {
			return undefined;
		}
		if (instance.IsA("BaseScript")) {
			mutedScripts.set(instance, instance.Disabled);
			instance.Disabled = true;
		}
		for (const item of instance.GetChildren()) {
			muteScripts(item);
		}
	};
	const playerScripts = Players.LocalPlayer.FindFirstChild("PlayerScripts");
	if (playerScripts !== undefined) {
		muteScripts(playerScripts.FindFirstChild("PlayerModule"));
		muteScripts(playerScripts.FindFirstChild("RbxCharacterSounds"));
	}
	return () => {
		pcall(() => {
			lighting.GlobalShadows = previous.globalShadows;
			lighting.Brightness = previous.brightness;
			lighting.Ambient = previous.ambient;
			lighting.OutdoorAmbient = previous.outdoorAmbient;
			lighting.EnvironmentDiffuseScale = previous.environmentDiffuse;
			lighting.EnvironmentSpecularScale = previous.environmentSpecular;
			lighting.FogEnd = previous.fogEnd;
			lighting.ClockTime = previous.clockTime;
		});
		for (const item of parked.GetChildren()) {
			item.Parent = lighting;
		}
		parked.Destroy();
		for (const [instance, disabled] of mutedScripts) {
			if (instance.Parent) {
				instance.Disabled = disabled;
			}
		}
		if (camera !== undefined) {
			if (previousCameraType !== undefined) {
				camera.CameraType = previousCameraType;
			}
			camera.CameraSubject = previousSubject;
		}
	};
}

function configureRobloxUi(playerGui: PlayerGui): () => void {
	const orientation = playerGui.ScreenOrientation;
	const coreTypes = [
		Enum.CoreGuiType.Backpack,
		Enum.CoreGuiType.Health,
		Enum.CoreGuiType.PlayerList,
		Enum.CoreGuiType.EmotesMenu,
		Enum.CoreGuiType.Chat,
	];
	const coreStates = new Map<Enum.CoreGuiType, boolean>();
	for (const coreType of coreTypes) {
		pcall(() => {
			coreStates.set(coreType, StarterGui.GetCoreGuiEnabled(coreType));
		});
	}
	const chatWindow = TextChatService.FindFirstChildOfClass("ChatWindowConfiguration");
	const chatInput = TextChatService.FindFirstChildOfClass("ChatInputBarConfiguration");
	const bubbles = TextChatService.FindFirstChildOfClass("BubbleChatConfiguration");
	const chatWindowEnabled = chatWindow?.Enabled;
	const chatInputEnabled = chatInput?.Enabled;
	const bubblesEnabled = bubbles?.Enabled;
	const mobileTouch =
		UserInputService.TouchEnabled &&
		(UserInputService.PreferredInput === Enum.PreferredInput.Touch ||
			(!UserInputService.KeyboardEnabled && !UserInputService.MouseEnabled));
	if (mobileTouch) {
		pcall(() => {
			playerGui.ScreenOrientation = Enum.ScreenOrientation.Sensor;
		});
	}
	pcall(() => {
		StarterGui.SetCore("TopbarEnabled", false);
		for (const coreType of coreTypes) {
			StarterGui.SetCoreGuiEnabled(coreType, false);
		}
		if (chatWindow) {
			chatWindow.Enabled = false;
		}
		if (chatInput) {
			chatInput.Enabled = false;
		}
		if (bubbles) {
			bubbles.Enabled = false;
		}
	});
	pcall(() => {
		const gui = StarterGui as unknown as { ClipsDescendantsSupportsRotation: unknown };
		const clipEnum = (Enum as unknown as Record<string, { Enabled?: unknown } | undefined>)
			.ClipsDescendantsSupportsRotation;
		if (clipEnum?.Enabled !== undefined) {
			gui.ClipsDescendantsSupportsRotation = clipEnum.Enabled;
		}
	});
	return () => {
		pcall(() => {
			playerGui.ScreenOrientation = orientation;
		});
		pcall(() => StarterGui.SetCore("TopbarEnabled", true));
		for (const [coreType, enabled] of coreStates) {
			pcall(() => StarterGui.SetCoreGuiEnabled(coreType, enabled));
		}
		if (chatWindow !== undefined && chatWindowEnabled !== undefined) {
			pcall(() => {
				chatWindow.Enabled = chatWindowEnabled;
			});
		}
		if (chatInput !== undefined && chatInputEnabled !== undefined) {
			pcall(() => {
				chatInput.Enabled = chatInputEnabled;
			});
		}
		if (bubbles !== undefined && bubblesEnabled !== undefined) {
			pcall(() => {
				bubbles.Enabled = bubblesEnabled;
			});
		}
	};
}

beginClientSession();
ClientLog.debug("boot", "client started");
const clientStartedAt = os.clock();
function bootLog(stage: string) {
	ClientLog.info("BOOT", stage, { ElapsedMs: math.floor((os.clock() - clientStartedAt) * 1000) });
}
const playerGuiInstance = Players.LocalPlayer.WaitForChild("PlayerGui", REPLICATION_TIMEOUT);
if (playerGuiInstance === undefined || !playerGuiInstance.IsA("PlayerGui")) {
	error("[AF/startup] PlayerGui was unavailable", 0);
}
const playerGui = playerGuiInstance;
bootLog("playerGui acquired");
const runtime = new ClientRuntime(playerGui);
bootLog("runtime created");
const restoreRobloxUi = configureRobloxUi(playerGui);
runtime.addDisposer(restoreRobloxUi);
runtime.addDisposer(stopInputPlatform);
let restoreWorkspace = configureUiOnlyWorkspace();
runtime.addDisposer(() => restoreWorkspace());
const vrModeConnection = VRService.GetPropertyChangedSignal("VREnabled").Connect(() => {
	restoreWorkspace();
	restoreWorkspace = configureUiOnlyWorkspace();
});
runtime.addDisposer(() => vrModeConnection.Disconnect());
Audio.setScene("boot");
runtime.render(<ClientBootstrap startedAt={clientStartedAt} shutdownLayer={runtime.shutdownLayer} />);

const failBootstrap = (message: string): never => {
	ClientLog.warn("Startup", message);
	restoreRobloxUi();
	runtime.render(<ClientBootstrap startedAt={clientStartedAt} failure={message} shutdownLayer={runtime.shutdownLayer} />);
	task.wait();
	error(`[AF/startup] ${message}`, 0);
};
function requiredChild<T extends keyof Instances>(
	parent: Instance,
	name: string,
	className: T,
	timeout: number,
	message: string,
): Instances[T] {
	const found = parent.WaitForChild(name, timeout);
	if (found === undefined || !found.IsA(className)) {
		return failBootstrap(message);
	}
	return found as Instances[T];
}
function loadModule<T>(moduleScript: ModuleScript, label: string): T {
	const [ok, result] = pcall(() => require(moduleScript));
	if (!ok) {
		return failBootstrap(`${label} failed to load: ${tostring(result)}`);
	}
	return result as T;
}

interface Protocol {
	FolderName: string;
	RequestName: string;
	StateName: string;
	ToastName: string;
	EffectName: string;
	ShutdownName: string;
}

const astralRoot = requiredChild(ReplicatedStorage, "AstralForge", "Folder", REPLICATION_TIMEOUT, "AstralForge did not replicate within 15 seconds.");
const sharedRoot = requiredChild(astralRoot, "Shared", "Folder", CHILD_TIMEOUT, "Shared client modules did not replicate within 8 seconds.");
const protocolScript = requiredChild(sharedRoot, "Protocol", "ModuleScript", CHILD_TIMEOUT, "Protocol module is missing or has the wrong class.");
const configScript = requiredChild(sharedRoot, "GameConfig", "ModuleScript", CHILD_TIMEOUT, "GameConfig module is missing or has the wrong class.");
const protocol = loadModule<Protocol>(protocolScript, "Protocol");
const config = loadModule<Connection["config"]>(configScript, "GameConfig");
for (const name of [
	protocol.FolderName,
	protocol.RequestName,
	protocol.StateName,
	protocol.ToastName,
	protocol.EffectName,
	protocol.ShutdownName,
] as unknown[]) {
	if (!typeIs(name, "string") || name.size() < 1 || name.size() > 64) {
		failBootstrap("Protocol contains an invalid bridge name.");
	}
}
pcall(() => {
	const spinner = sharedRoot.FindFirstChild("NumberSpinner");
	if (spinner !== undefined && spinner.IsA("ModuleScript")) {
		require(spinner);
	}
});
pcall(() => {
	const spinner = astralRoot.FindFirstChild("Vendor")?.FindFirstChild("NumberSpinner");
	if (spinner !== undefined && spinner.IsA("ModuleScript")) {
		require(spinner);
	}
});
const bridge = requiredChild(
	ReplicatedStorage,
	protocol.FolderName,
	"Folder",
	REPLICATION_TIMEOUT,
	"Server bridge was not published within 15 seconds. Check the first Server error.",
);
const remotes: Remotes = {
	Bridge: bridge,
	Request: requiredChild(bridge, protocol.RequestName, "RemoteFunction", 5, "Server request remote is missing or has the wrong class."),
	State: requiredChild(bridge, protocol.StateName, "RemoteEvent", 5, "Server state remote is missing or has the wrong class."),
	Toast: requiredChild(bridge, protocol.ToastName, "RemoteEvent", 5, "Server toast remote is missing or has the wrong class."),
	Effect: requiredChild(bridge, protocol.EffectName, "RemoteEvent", 5, "Server effect remote is missing or has the wrong class."),
	Shutdown: requiredChild(bridge, protocol.ShutdownName, "RemoteEvent", 5, "Server shutdown remote is missing or has the wrong class."),
};
const stopPerformanceTelemetry = startPerformanceTelemetry(remotes.Request);
runtime.addDisposer(stopPerformanceTelemetry);
runtime.addDisposer(startSession(remotes) as () => void);
runtime.addDisposer(watchPing(remotes.Request, "MeasureLatency"));
ClientLog.debug("net", `connected to ${config.Game.Version}`);
runtime.render(
	<ClientBootstrap startedAt={clientStartedAt} connection={{ remotes, config }} shutdownLayer={runtime.shutdownLayer} />,
);
ClientLog.once("ui-ready", "ui", `${config.Game.Version} ui is up`);
