import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";

interface LuaObj {
	[key: string]: LuaObj;
	(...args: unknown[]): unknown;
}
interface Colon {
	[key: string]: (this: Colon, ...args: unknown[]) => unknown;
}
function colon(value: unknown): Colon {
	return value as Colon;
}
function luaProp(object: unknown, key: string): unknown {
	return (object as LuaObj)[key];
}
function luaIndex(object: unknown, index: unknown): unknown {
	return (object as LuaObj)[index as unknown as string];
}
function luaSet(object: unknown, key: string, value: unknown): void {
	(object as LuaObj)[key] = value as unknown as LuaObj;
}
function luaSetIndex(object: unknown, index: unknown, value: unknown): void {
	(object as LuaObj)[index as unknown as string] = value as unknown as LuaObj;
}
function luaCall(fn: unknown, ...args: unknown[]): unknown {
	return (fn as LuaObj)(...args);
}
function len(value: unknown): number {
	return (value as Array<unknown>).size();
}
function concat(left: unknown, right: unknown): string {
	return `${left}${right}`;
}
function luaTypeIs(value: unknown, typeName: string): boolean {
	return typeIs(value, typeName as never);
}
const reactLoose = React as unknown as Record<string, (...args: unknown[]) => unknown>;
interface LuaTableOps {
	insert: (list: unknown, a?: unknown, b?: unknown) => unknown;
	concat: (list: unknown, sep?: unknown, i?: unknown, j?: unknown) => unknown;
	find: (list: unknown, value: unknown, init?: unknown) => unknown;
	move: (src: unknown, a: unknown, b: unknown, t: unknown, dst?: unknown) => unknown;
	remove: (list: unknown, pos?: unknown) => unknown;
	unpack: (list: unknown, i?: unknown, j?: unknown) => unknown;
}
const luaTable = table as unknown as LuaTableOps;
function luaRequire(moduleScript: unknown): unknown {
	return require(moduleScript as ModuleScript) as unknown;
}
function instChild(parent: Instance, name: string): Instance {
	return (parent as unknown as Record<string, Instance>)[name];
}

const UiCoreFolder = script.Parent!;
const AstralForge = UiCoreFolder.Parent!;

function kit(name: string, member: string): unknown {
	return luaCall(luaRequire(AstralForge.WaitForChild(name) as ModuleScript), member);
}
function ui(name: string): unknown {
	return luaRequire(UiCoreFolder.WaitForChild(name) as ModuleScript);
}
function mod(...names: string[]): unknown {
	let current: Instance = AstralForge;
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}
function modRel(ups: number, ...names: string[]): unknown {
	let current: Instance = script;
	for (let i = 0; i < ups; i++) {
		current = current.Parent!;
	}
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}

let reactModules: unknown = kit("ReactHosts", "reactModules");
let useLatestCallback: unknown = luaProp(reactModules, "useLatestCallback");
let notePage: unknown = luaProp(kit("ReactHosts", "vendorHost"), "notePage");
let ContextActionService: unknown = colon(game).GetService("ContextActionService");
let GuiService: unknown = colon(game).GetService("GuiService");
let Players: unknown = colon(game).GetService("Players");
let UserInputService: unknown = colon(game).GetService("UserInputService");
let _MobileShell: unknown = ui("MobileShell");
let MobileHeader: unknown = luaProp(_MobileShell, "MobileHeader");
let MobileQuickActions: unknown = luaProp(_MobileShell, "MobileQuickActions");
let MobileTabBar: unknown = luaProp(_MobileShell, "MobileTabBar");
let _flexbox: unknown = kit("MotionKit", "flexbox");
let Flex: unknown = luaProp(_flexbox, "Flex");
let FlexItem: unknown = luaProp(_flexbox, "FlexItem");
let _effects: unknown = ui("effects");
let EffectLayer: unknown = luaProp(_effects, "EffectLayer");
let StarField: unknown = luaProp(_effects, "StarField");
let ComboBadge: unknown = luaProp(ui("ComboBadge"), "ComboBadge");
let _antilag: unknown = kit("MotionKit", "antilag");
let AntilagContext: unknown = luaProp(_antilag, "AntilagContext");
let clampAntilagTier: unknown = luaProp(_antilag, "clampAntilagTier");
let setAntilagPreference: unknown = luaProp(_antilag, "setAntilagPreference");
let setAntilagScene: unknown = luaProp(_antilag, "setAntilagScene");
let useAntilag: unknown = luaProp(_antilag, "useAntilag");
let _motion: unknown = kit("MotionKit", "motion");
let beginUiTransition: unknown = luaProp(_motion, "beginUiTransition");
let setClockBudget: unknown = luaProp(_motion, "setClockBudget");
let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
let useDynamicLayoutNumber: unknown = luaProp(kit("MotionKit", "dynamicLayout"), "useDynamicLayoutNumber");
let useViewport: unknown = luaProp(_motion, "useViewport");
let useWallClock: unknown = luaProp(_motion, "useWallClock");
let _ui: unknown = ui("ui");
let Button: unknown = luaProp(_ui, "Button");
let Text: unknown = luaProp(_ui, "Text");
let _theme: unknown = kit("CoreKit", "theme");
let Layout: unknown = luaProp(_theme, "Layout");
let Palette: unknown = luaProp(_theme, "Palette");
let chromeFor: unknown = luaProp(_theme, "chromeFor");
let _format: unknown = kit("CoreKit", "format");
let asFlux: unknown = luaProp(_format, "asFlux");
let compactNumber: unknown = luaProp(_format, "compactNumber");
let gteFlux: unknown = luaProp(_format, "gteFlux");
let CreditsOverlay: unknown = luaProp(ui("CreditsView"), "CreditsOverlay");
let CrateRevealOverlay: unknown = luaProp(ui("CrateRevealOverlay"), "CrateRevealOverlay");
let RebirthCeremonyHost: unknown = luaProp(ui("RebirthCeremony"), "RebirthCeremonyHost");
let PageContent: unknown = luaProp(mod("pages", "PageRouter"), "PageContent");
let PageFrame: unknown = luaProp(kit("ReactHosts", "reactHost"), "PageFrame");
let useGameChat: unknown = luaProp(kit("ClientRuntime", "chat"), "useGameChat");
let _appNav: unknown = kit("CoreKit", "appNav");
let AppHelpers: unknown = luaProp(_appNav, "AppHelpers");
let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
let _TopBarChrome: unknown = ui("TopBarChrome");
let TopBar: unknown = luaProp(_TopBarChrome, "TopBar");
let _ShellFx: unknown = ui("ShellFx");
let TradeReturnPill: unknown = luaProp(_ShellFx, "TradeReturnPill");
let AmbientLayer: unknown = luaProp(_ShellFx, "AmbientLayer");
let _NavChrome: unknown = ui("NavChrome");
let Navigation: unknown = luaProp(_NavChrome, "Navigation");
let _WorkspaceChrome: unknown = ui("WorkspaceChrome");
let Workspace: unknown = luaProp(_WorkspaceChrome, "Workspace");
let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
let _session: unknown = kit("CoreKit", "session");
let setPresencePage: unknown = luaProp(_session, "setPresencePage");
let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
let _onboarding: unknown = ui("onboarding");
let ReleaseNotesModal: unknown = luaProp(_onboarding, "ReleaseNotesModal");
let TutorialOverlay: unknown = luaProp(_onboarding, "TutorialOverlay");
let LevelMomentHost: unknown = luaProp(ui("levelMoments"), "LevelMomentHost");
let ServerEventHost: unknown = luaProp(ui("serverEventsUi"), "ServerEventHost");
let _clientStore: unknown = kit("CoreKit", "clientStore");
let ClientActions: unknown = luaProp(_clientStore, "ClientActions");
let useClientDispatch: unknown = luaProp(_clientStore, "useClientDispatch");
let useClientSelector: unknown = luaProp(_clientStore, "useClientSelector");
let PlayerlistOverlay: unknown = luaProp(ui("PlayerlistOverlay"), "PlayerlistOverlay");
let OfflineRewardsOverlay: unknown = luaProp(ui("OfflineRewardsOverlay"), "OfflineRewardsOverlay");
let FeedbackOverlay: unknown = luaProp(ui("FeedbackOverlay"), "FeedbackOverlay");
let LevelRoadmapHost: unknown = luaProp(ui("levelRoadmap"), "LevelRoadmapHost");
let readLevelState: unknown = luaProp(ui("levelRoadmap"), "readLevelState");
let pausePassivePaints: unknown = { current: false };
let TUTORIAL_STEPS: unknown = luaProp(luaCall(luaRequire(colon(colon(colon(colon(game).GetService("ReplicatedStorage")).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("SharedData")), "TutorialScript"), "STEPS");
let SHELL_CHROME: unknown = { railGutter: 18, topbarControl: 48, topbarControlGap: 12 };
function offlineRewardsProps(state?: unknown, reducedMotion?: unknown, dispatch?: unknown, dismiss?: unknown): unknown | undefined {
	let offline: unknown = ((luaTypeIs(luaProp(state, "Offline"), "table")) ? luaProp(state, "Offline") : {});
	let effects: unknown = luaProp(luaProp(state, "Settings"), "OfflineRewardEffects");
	if ((effects === undefined)) {
		effects = 1;
	}
	return { reward: ((luaProp(offline, "Reward") !== undefined) ? luaProp(offline, "Reward") : 0), seconds: ((luaProp(offline, "Seconds") !== undefined) ? luaProp(offline, "Seconds") : 0), efficiency: ((luaProp(offline, "Efficiency") !== undefined) ? luaProp(offline, "Efficiency") : luaProp(state, "OfflineEfficiency")), capped: (luaProp(offline, "Capped") === true), production: ((luaProp(offline, "Production") !== undefined) ? luaProp(offline, "Production") : luaProp(state, "Production")), awaySeconds: luaProp(offline, "AwaySeconds"), capHours: ((luaProp(offline, "CapHours") !== undefined) ? luaProp(offline, "CapHours") : luaProp(state, "OfflineHours")), vault: ((luaProp(offline, "Vault") !== undefined) ? luaProp(offline, "Vault") : luaProp(state, "Vault")), reducedMotion: reducedMotion, effectsEnabled: ((effects as unknown as number) >= (0.5 as unknown as number)), onCollect: function(): unknown | undefined {
		return luaCall(dispatch, "CollectVault");
		return undefined;
	}, onClose: dismiss };
	return undefined;
}
function AppShell(_param?: unknown): unknown | undefined {
	let state: unknown = luaProp(_param, "state");
	let config: unknown = luaProp(_param, "config");
	let dispatch: unknown = luaProp(_param, "dispatch");
	let addNotice: unknown = luaProp(_param, "addNotice");
	let celebrate: unknown = luaProp(_param, "celebrate");
	let confettiNonce: unknown = luaProp(_param, "confettiNonce");
	let clearConfetti: unknown = luaProp(_param, "clearConfetti");
	let pops: unknown = luaProp(_param, "pops");
	let comboReadout: unknown = luaProp(_param, "comboReadout");
	let visit: unknown = luaProp(_param, "visit");
	let setVisit: unknown = luaProp(_param, "setVisit");
	let openDomain: unknown = luaProp(_param, "openDomain");
	let domainOverlayActive: unknown = luaProp(_param, "domainOverlayActive");
	let setToastsSuppressed: unknown = luaProp(_param, "setToastsSuppressed");
	let setPurchasePresentationActive: unknown = luaProp(_param, "setPurchasePresentationActive");
	let crateReveal: unknown;
	let setCrateReveal: unknown;
	[crateReveal, setCrateReveal] = reactLoose.useState() as LuaTuple<[unknown, unknown]>;
	let pageHostRef: unknown = reactLoose.useRef(undefined);
	let cinematicOpen: unknown = ((crateReveal !== undefined) || domainOverlayActive);
	reactLoose.useEffect(function(): unknown | undefined {
		luaSet(pausePassivePaints, "current", cinematicOpen);
		return function(): unknown | undefined {
			luaSet(pausePassivePaints, "current", false);
			return undefined;
		};
		return undefined;
	}, [cinematicOpen]);
	reactLoose.useEffect(function(): unknown | undefined {
		let _condition: unknown = luaProp(luaProp(state, "Settings"), "PerformanceBias");
		if ((_condition === undefined)) {
			_condition = 0.5;
		}
		luaCall(setAntilagPreference, _condition);
		return undefined;
	}, [luaProp(luaProp(state, "Settings"), "PerformanceBias")]);
	let playerlistOpen: unknown;
	let setPlayerlistOpen: unknown;
	[playerlistOpen, setPlayerlistOpen] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	let feedbackOpen: unknown;
	let setFeedbackOpen: unknown;
	[feedbackOpen, setFeedbackOpen] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	let viewport: unknown = luaCall(useViewport);
	let chrome: unknown = luaCall(chromeFor, viewport);
	let drawerNav: unknown = (luaProp(chrome, "stack") || ((((!luaProp(viewport, "desktop")) && luaProp(UserInputService, "TouchEnabled")) && luaProp(viewport, "compact"))));
	let page: unknown = luaCall(useClientSelector, function(client?: unknown): unknown | undefined {
		return luaProp(luaProp(client, "navigation"), "page");
		return undefined;
	});
	let bootChromeVisible: unknown = luaCall(useClientSelector, function(client?: unknown): unknown | undefined {
		return luaProp(luaProp(client, "boot"), "visible");
		return undefined;
	});
	let dispatchStore: unknown = luaCall(useClientDispatch);
	let setPage: unknown = reactLoose.useCallback(function(pageNext?: unknown): unknown | undefined {
		return luaCall(dispatchStore, luaCall(luaProp(ClientActions, "navigate"), pageNext));
		return undefined;
	}, [dispatchStore]);
	reactLoose.useEffect(function(): unknown | undefined {
		luaCall(setPresencePage, page);
		return undefined;
	}, [page]);
	let railOpen: unknown;
	let setRailOpen: unknown;
	[railOpen, setRailOpen] = reactLoose.useState((!drawerNav)) as LuaTuple<[unknown, unknown]>;
	let previousDrawerNav: unknown = reactLoose.useRef(drawerNav);
	reactLoose.useEffect(function(): unknown | undefined {
		if ((luaProp(previousDrawerNav, "current") === drawerNav)) {
			return undefined;
		}
		luaSet(previousDrawerNav, "current", drawerNav);
		luaCall(setRailOpen, (!drawerNav));
		return undefined;
	}, [drawerNav]);
	let arcadeBusy: unknown;
	let setArcadeBusy: unknown;
	[arcadeBusy, setArcadeBusy] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	let hidden: unknown;
	let setHidden: unknown;
	[hidden, setHidden] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	let buyAmount: unknown;
	let setBuyAmount: unknown;
	[buyAmount, setBuyAmount] = reactLoose.useState(1) as LuaTuple<[unknown, unknown]>;
	let chat: unknown = luaCall(useGameChat, (page === "Chat"), true, dispatch, luaProp(state, "Settings"));
	let offlineReceiptKey: unknown = (((luaProp(state, "Offline") !== undefined) && ((luaProp(luaProp(state, "Offline"), "Seconds") as unknown as number) >= (30 as unknown as number))) ? `${luaCall(luaProp(math, "floor"), luaProp(luaProp(state, "Offline"), "Seconds"))}:${luaCall(compactNumber, luaProp(luaProp(state, "Offline"), "Reward"))}` : "");
	let dismissedOfflineKey: unknown;
	let setDismissedOfflineKey: unknown;
	[dismissedOfflineKey, setDismissedOfflineKey] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
	let offlineDismissed: unknown = ((offlineReceiptKey !== "") && (dismissedOfflineKey === offlineReceiptKey));
	let _binding: unknown = luaCall((function(): unknown | undefined {
		let _condition: unknown = luaProp(luaProp(state, "Settings"), "UiDensity");
		if ((_condition === undefined)) {
			_condition = 0.55;
		}
		let uiDensity: unknown = _condition;
		let densityScale: unknown = ((0.82 as unknown as number) + (((uiDensity as unknown as number) * (0.36 as unknown as number)) as unknown as number));
		let edgePad: unknown = luaCall(luaProp(math, "max"), 8, luaProp(chrome, "sideSafe"), luaCall(luaProp(math, "floor"), ((luaProp(chrome, "pagePadding") as unknown as number) * (densityScale as unknown as number))));
		let topPad: unknown = (luaProp(chrome, "stack") ? 6 : luaProp(Layout, "topbarClearance"));
		let _condition_1: unknown = (luaProp(viewport, "keyboardOpen") && luaProp(chrome, "mobile"));
		if (_condition_1) {
			let _condition_2: unknown = luaProp(luaProp(state, "Settings"), "MobileKeyboardCompact");
			if ((_condition_2 === undefined)) {
				_condition_2 = 1;
			}
			_condition_1 = ((_condition_2 as unknown as number) >= (0.5 as unknown as number));
		}
		let keyboardShellCompact: unknown = _condition_1;
		let _result: unknown;
		if (keyboardShellCompact) {
			_result = 0;
		} else {
			let _result_1: unknown;
			if (luaProp(chrome, "stack")) {
				_result_1 = luaProp(chrome, "topbarRows");
			} else {
				let _condition_2: unknown = luaProp(luaProp(state, "Settings"), "CompactTopBar");
				if ((_condition_2 === undefined)) {
					_condition_2 = 0;
				}
				_result_1 = (((_condition_2 as unknown as number) >= (0.5 as unknown as number)) ? luaCall(luaProp(math, "max"), 52, ((luaProp(chrome, "topbarRows") as unknown as number) - (8 as unknown as number))) : luaProp(chrome, "topbarRows"));
			}
			_result = _result_1;
		}
		let topbarHeight: unknown = _result;
		let moreAtBottom: unknown = luaProp(chrome, "stack");
		let tabBarH: unknown = (keyboardShellCompact ? 0 : luaProp(chrome, "tabBarH"));
		let shellTop: unknown = ((((topPad as unknown as number) + (topbarHeight as unknown as number)) as unknown as number) + (luaProp(chrome, "panelGap") as unknown as number));
		let desktopDockTop: unknown = shellTop;
		let desktopDockHeight: unknown = 0;
		let _condition_2: unknown = luaProp(luaProp(state, "Settings"), "MobileQuickVisible");
		if ((_condition_2 === undefined)) {
			_condition_2 = 1;
		}
		let mobileQuickEnabled: unknown = ((_condition_2 as unknown as number) >= (0.5 as unknown as number));
		let quickActionsVisible: unknown = ((((((mobileQuickEnabled && moreAtBottom) && (page === "Workshop")) && (!luaProp(viewport, "keyboardOpen"))) && (!arcadeBusy)) && (crateReveal === undefined)) && (!railOpen));
		let quickBottomOffset: unknown = ((tabBarH as unknown as number) + (12 as unknown as number));
		let bottomPad: unknown = (keyboardShellCompact ? 4 : (moreAtBottom ? ((quickActionsVisible ? ((((tabBarH as unknown as number) + (76 as unknown as number)) as unknown as number) + (luaProp(chrome, "panelGap") as unknown as number)) : ((tabBarH as unknown as number) + (luaProp(chrome, "panelGap") as unknown as number)))) : luaCall(luaProp(math, "max"), 8, luaCall(luaProp(math, "floor"), ((edgePad as unknown as number) * (0.6 as unknown as number))))));
		return { edgePad: edgePad, topPad: topPad, keyboardShellCompact: keyboardShellCompact, topbarHeight: topbarHeight, moreAtBottom: moreAtBottom, shellTop: shellTop, desktopDockTop: desktopDockTop, desktopDockHeight: desktopDockHeight, tabBarH: tabBarH, quickActionsVisible: quickActionsVisible, quickBottomOffset: quickBottomOffset, bottomPad: bottomPad };
		return undefined;
	}));
	let edgePad: unknown = luaProp(_binding, "edgePad");
	let topPad: unknown = luaProp(_binding, "topPad");
	let keyboardShellCompact: unknown = luaProp(_binding, "keyboardShellCompact");
	let topbarHeight: unknown = luaProp(_binding, "topbarHeight");
	let shellTop: unknown = luaProp(_binding, "shellTop");
	let tabBarH: unknown = luaProp(_binding, "tabBarH");
	let quickActionsVisible: unknown = luaProp(_binding, "quickActionsVisible");
	let quickBottomOffset: unknown = luaProp(_binding, "quickBottomOffset");
	let bottomPad: unknown = luaProp(_binding, "bottomPad");
	let reducedMotion: unknown = false;
	let softMotion: unknown = false;
	let shellTopLive: unknown = luaCall(useDynamicLayoutNumber, shellTop, softMotion);
	let topbarLive: unknown = luaCall(useDynamicLayoutNumber, topbarHeight, softMotion);
	reactLoose.useEffect(function(): unknown | undefined {
		colon(Audio).setView(page, false);
		return undefined;
	}, [page]);
	let _condition: unknown = luaProp(luaProp(state, "Settings"), "EffectsIntensity");
	if ((_condition === undefined)) {
		_condition = 1;
	}
	let effectsScale: unknown = _condition;
	let accent: unknown = colon(AppHelpers).pageAccent(page);
	let _result: unknown = luaProp(state, "ActiveBoost");
	if ((_result !== undefined)) {
		_result = luaProp(_result, "Id");
	}
	let _condition_1: unknown = _result;
	if ((_condition_1 === undefined)) {
		_condition_1 = "";
	}
	let activeBoostId: unknown = _condition_1;
	let _result_1: unknown = luaProp(state, "ActiveBoost");
	if ((_result_1 !== undefined)) {
		_result_1 = luaProp(_result_1, "EndsAt");
	}
	let _condition_2: unknown = _result_1;
	if ((_condition_2 === undefined)) {
		_condition_2 = 0;
	}
	let activeBoostEndsAt: unknown = _condition_2;
	let activeBoostExpired: unknown;
	let setActiveBoostExpired: unknown;
	[activeBoostExpired, setActiveBoostExpired] = reactLoose.useState(((activeBoostEndsAt as unknown as number) <= (colon(game.GetService("Workspace")).GetServerTimeNow() as unknown as number))) as LuaTuple<[unknown, unknown]>;
	reactLoose.useEffect(function(): unknown | undefined {
		let remaining: unknown = ((activeBoostEndsAt as unknown as number) - (colon(game.GetService("Workspace")).GetServerTimeNow() as unknown as number));
		luaCall(setActiveBoostExpired, ((remaining as unknown as number) <= (0 as unknown as number)));
		if (((activeBoostId === "") || ((remaining as unknown as number) <= (0 as unknown as number)))) {
			return undefined;
		}
		let expiry: unknown = luaCall(luaProp(task, "delay"), ((remaining as unknown as number) + (0.05 as unknown as number)), function(): unknown | undefined {
			return luaCall(setActiveBoostExpired, true);
			return undefined;
		});
		return function(): unknown | undefined {
			return luaCall(luaProp(task, "cancel"), expiry);
			return undefined;
		};
		return undefined;
	}, [activeBoostEndsAt, activeBoostId]);
	let _result_2: unknown;
	if (((!activeBoostExpired) && (activeBoostId !== ""))) {
		let _result_3: unknown = luaProp(config, "Boosts");
		if ((_result_3 !== undefined)) {
			_result_3 = luaIndex(_result_3, activeBoostId);
		}
		_result_2 = _result_3;
	} else {
		_result_2 = undefined;
	}
	let activeBoost: unknown = _result_2;
	let wallClock: unknown = luaCall(useWallClock, (activeBoost !== undefined));
	let hideAmount: unknown = luaCall(useFlipperSpring, (hidden ? 1 : 0), softMotion, 620, 42);
	let mobileShell: unknown = luaProp(chrome, "stack");
	let drawerWidth: unknown = luaCall(luaProp(math, "min"), luaProp(Layout, "sidebarWidth"), luaCall(luaProp(math, "max"), 248, ((((luaProp(viewport, "width") as unknown as number) - (((edgePad as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (36 as unknown as number))));
	let railTarget: unknown = (railOpen ? ((drawerNav ? drawerWidth : ((luaProp(viewport, "compact") ? luaProp(Layout, "sidebarCollapsedWidth") : luaProp(Layout, "sidebarWidth"))))) : 0);
	let railWidth: unknown = luaCall(useFlipperSpring, (mobileShell ? 0 : railTarget), softMotion, 900, 46);
	let drawerProgress: unknown = colon(railWidth).map(function(width?: unknown): unknown | undefined {
		return (drawerNav ? luaCall(luaProp(math, "clamp"), ((width as unknown as number) / (luaCall(luaProp(math, "max"), drawerWidth, 1) as unknown as number)), 0, 1) : 0);
		return undefined;
	});
	let drawerScrimTransparency: unknown = colon(drawerProgress).map(function(amount?: unknown): unknown | undefined {
		return ((1 as unknown as number) - (((amount as unknown as number) * (0.58 as unknown as number)) as unknown as number));
		return undefined;
	});
	let drawerScrimVisible: unknown = colon(drawerProgress).map(function(amount?: unknown): unknown | undefined {
		return ((amount as unknown as number) > (0.01 as unknown as number));
		return undefined;
	});
	let drawerPanelVisible: unknown = colon(railWidth).map(function(width?: unknown): unknown | undefined {
		return ((width as unknown as number) > (6 as unknown as number));
		return undefined;
	});
	let dockVisible: unknown = colon(railWidth).map(function(width?: unknown): unknown | undefined {
		return ((!drawerNav) || ((width as unknown as number) <= (4 as unknown as number)));
		return undefined;
	});
	let workspaceOffset: unknown = colon(railWidth).map(function(width?: unknown): unknown | undefined {
		if (drawerNav) {
			return luaCall(luaProp(UDim2, "fromOffset"), 0, 0);
		}
		return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, (((width as unknown as number) > (1 as unknown as number)) ? ((width as unknown as number) + (luaProp(Layout, "panelGap") as unknown as number)) : 0), 0, 0);
		return undefined;
	});
	let workspaceSize: unknown = colon(railWidth).map(function(width?: unknown): unknown | undefined {
		if (drawerNav) {
			return luaCall(luaProp(UDim2, "fromScale"), 1, 1);
		}
		return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(((((width as unknown as number) > (1 as unknown as number)) ? ((width as unknown as number) + (luaProp(Layout, "panelGap") as unknown as number)) : 0)) as unknown as number)), 1, 0);
		return undefined;
	});
	let _condition_3: unknown = luaProp(luaProp(state, "Flags"), "TutorialStep");
	if ((_condition_3 === undefined)) {
		_condition_3 = 1;
	}
	let serverTutorialStep: unknown = luaCall(luaProp(math, "clamp"), luaCall(luaProp(math, "floor"), _condition_3), 1, len(TUTORIAL_STEPS));
	let tutorialStep: unknown;
	let setTutorialStep: unknown;
	[tutorialStep, setTutorialStep] = reactLoose.useState(serverTutorialStep) as LuaTuple<[unknown, unknown]>;
	let tutorialHold: unknown = reactLoose.useRef(0);
	reactLoose.useEffect(function(): unknown | undefined {
		if (((((luaProp(tutorialHold, "current") as unknown as number) > (0 as unknown as number)) && ((serverTutorialStep as unknown as number) < (luaProp(tutorialHold, "current") as unknown as number))) && (!luaProp(luaProp(state, "Flags"), "TutorialDone")))) {
			return undefined;
		}
		luaSet(tutorialHold, "current", 0);
		luaCall(setTutorialStep, serverTutorialStep);
		return undefined;
	}, [serverTutorialStep, luaProp(luaProp(state, "Flags"), "TutorialDone")]);
	let tutorial: unknown = luaIndex(TUTORIAL_STEPS, tutorialStep);
	let tutorialOpen: unknown = ((!luaProp(luaProp(state, "Flags"), "TutorialDone")) && (tutorial !== undefined));
	let releaseClosedLocally: unknown;
	let setReleaseClosedLocally: unknown;
	[releaseClosedLocally, setReleaseClosedLocally] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	reactLoose.useEffect(function(): unknown | undefined {
		if ((luaProp(luaProp(state, "Flags"), "LastSeenVersion") === "")) {
			luaCall(setReleaseClosedLocally, false);
		}
		return undefined;
	}, [luaProp(luaProp(state, "Flags"), "LastSeenVersion")]);
	let showRelease: unknown = ((luaProp(luaProp(state, "Flags"), "TutorialDone") && (luaProp(luaProp(state, "Flags"), "LastSeenVersion") !== luaProp(luaProp(config, "Game"), "Version"))) && (!releaseClosedLocally));
	let _condition_4: unknown = (((offlineReceiptKey !== "") && (!offlineDismissed)) && luaProp(luaProp(state, "Flags"), "TutorialDone"));
	if (_condition_4) {
		let _result_3: unknown = luaProp(state, "Offline");
		if ((_result_3 !== undefined)) {
			_result_3 = luaProp(_result_3, "Reward");
		}
		let _condition_5: unknown = _result_3;
		if ((_condition_5 === undefined)) {
			_condition_5 = 0;
		}
		_condition_4 = luaCall(gteFlux, _condition_5, 0.01);
		if (_condition_4) {
			_condition_4 = ((((((!showRelease) && (page !== "Credits")) && (crateReveal === undefined)) && (!playerlistOpen)) && (!feedbackOpen)) && (!domainOverlayActive));
		}
	}
	let offlineRewardsOpen: unknown = _condition_4;
	let modalOwnsScreen: unknown = ((((tutorialOpen || showRelease) || (page === "Credits")) || (crateReveal !== undefined)) || domainOverlayActive);
	reactLoose.useEffect(function(): unknown | undefined {
		luaCall(setToastsSuppressed, modalOwnsScreen);
		return function(): unknown | undefined {
			return luaCall(setToastsSuppressed, false);
			return undefined;
		};
		return undefined;
	}, [modalOwnsScreen, setToastsSuppressed]);
	luaCall(luaProp(reactModules, "useEventListener"), luaProp(UserInputService, "InputBegan"), function(input?: unknown, processed?: unknown): unknown | undefined {
		if ((colon(UserInputService).GetFocusedTextBox() !== undefined)) {
			return undefined;
		}
		if (processed) {
			return undefined;
		}
		if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "Backquote"))) {
			luaCall(setHidden, function(current?: unknown): unknown | undefined {
				return (!current);
				return undefined;
			});
		}
		return undefined;
	}, { connected: (((!domainOverlayActive) && (!showRelease)) && (!tutorialOpen)) });
	let navigate: unknown = function(pageId?: unknown): unknown | undefined {
		let entry: unknown = colon(AppHelpers).pageEntry(pageId);
		if ((luaProp(entry, "disabled") === true)) {
			colon(Audio).play("locked");
			let _exp: unknown = `${luaProp(entry, "label")} is closed`;
			let _condition_5: unknown = luaProp(entry, "disabledReason");
			if ((_condition_5 === undefined)) {
				_condition_5 = "Closed for now.";
			}
			luaCall(addNotice, _exp, _condition_5, "Info");
			return undefined;
		}
		let _exp: unknown = pageId;
		let _result_3: unknown = tutorial;
		if ((_result_3 !== undefined)) {
			_result_3 = luaProp(_result_3, "page");
		}
		if ((!colon(AppHelpers).navUnlocked(state, _exp, _result_3))) {
			let _lock: unknown = luaProp(state, "FeatureUnlocks");
			if ((_lock !== undefined)) {
				_lock = luaIndex(_lock, pageId);
			}
			let lock: unknown = _lock;
			colon(Audio).play("locked");
			let _result_4: unknown = lock;
			if ((_result_4 !== undefined)) {
				_result_4 = luaProp(_result_4, "Name");
			}
			let _condition_5: unknown = _result_4;
			if ((_condition_5 === undefined)) {
				_condition_5 = pageId;
			}
			let _exp_1: unknown = `${_condition_5} is locked`;
			let _result_5: unknown = lock;
			if ((_result_5 !== undefined)) {
				_result_5 = luaProp(_result_5, "Requirement");
			}
			let _condition_6: unknown = _result_5;
			if ((_condition_6 === undefined)) {
				_condition_6 = "Not unlocked yet.";
			}
			if ((((lock !== undefined) && (luaTypeIs(luaProp(lock, "Requirement"), "string"))) && (luaProp(lock, "Requirement") !== ""))) {
				_exp_1 = `${_condition_5} is locked`;
				let done: unknown = (((luaTypeIs(luaProp(lock, "Progress"), "number")) && (luaTypeIs(luaProp(lock, "Target"), "number"))) ? ` (${luaCall(compactNumber, luaProp(lock, "Progress"))}/${luaCall(compactNumber, luaProp(lock, "Target"))})` : "");
				_condition_6 = `${luaProp(lock, "Requirement")} to open it${done}.`;
			}
			if ((pageId === "Research")) {
				_condition_6 = concat(_condition_6, " Research bonuses stay after rebirth.");
			}
			luaCall(addNotice, _exp_1, _condition_6, "Info");
			return undefined;
		}
		colon(Audio).setView(pageId);
		colon(ClientLog).debug("nav", pageId);
		luaCall(beginUiTransition, 0.1);
		luaCall(setPage, pageId);
		if (drawerNav) {
			luaCall(setRailOpen, false);
		}
		return undefined;
	};
	let navigationStateRef: unknown = reactLoose.useRef(state);
	luaSet(navigationStateRef, "current", state);
	let _result_3: unknown = tutorial;
	if ((_result_3 !== undefined)) {
		_result_3 = luaProp(_result_3, "page");
	}
	let tutorialPageRef: unknown = reactLoose.useRef(_result_3);
	let _result_4: unknown = tutorial;
	if ((_result_4 !== undefined)) {
		_result_4 = luaProp(_result_4, "page");
	}
	luaSet(tutorialPageRef, "current", _result_4);
	let navigateRef: unknown = reactLoose.useRef(navigate);
	luaSet(navigateRef, "current", navigate);
	let navigateStable: unknown = luaCall(useLatestCallback, function(pageId?: unknown): unknown | undefined {
		luaCall(notePage, pageId);
		return luaCall(luaProp(navigateRef, "current"), pageId);
		return undefined;
	});
	let openWorkshop: unknown = reactLoose.useCallback(function(): unknown | undefined {
		return luaCall(luaProp(navigateRef, "current"), "Workshop");
		return undefined;
	}, {});
	let onWheelLand: unknown = reactLoose.useCallback(function(): unknown | undefined {
		return luaCall(celebrate);
		return undefined;
	}, [celebrate]);
	reactLoose.useEffect(function(): unknown | undefined {
		if (((luaProp(luaProp(state, "Flags"), "TutorialDone") || (tutorial === undefined)) || (luaProp(tutorial, "startPage") === undefined))) {
			return undefined;
		}
		luaCall(setHidden, false);
		luaCall(setPage, (colon(AppHelpers).navUnlocked(state, luaProp(tutorial, "startPage"), luaProp(tutorial, "page")) ? luaProp(tutorial, "startPage") : "Overview"));
		return undefined;
	}, [luaProp(luaProp(state, "Flags"), "TutorialDone"), tutorial]);
	reactLoose.useEffect(function(): unknown | undefined {
		let _condition_5: unknown = (page !== "Trade");
		if (_condition_5) {
			let _result_5: unknown = tutorial;
			if ((_result_5 !== undefined)) {
				_result_5 = luaProp(_result_5, "page");
			}
			_condition_5 = (!colon(AppHelpers).navUnlocked(state, page, _result_5));
		}
		if (_condition_5) {
			luaCall(setPage, "Overview");
		}
		return undefined;
	}, [page, luaProp(state, "FeatureUnlocks"), tutorial]);
	let tradeFocusKey: unknown = reactLoose.useRef("");
	let _exp: unknown = function(): unknown | undefined {
		let _sessionId: unknown = luaProp(state, "Trade");
		if ((_sessionId !== undefined)) {
			_sessionId = luaProp(_sessionId, "Session");
			if ((_sessionId !== undefined)) {
				_sessionId = luaProp(_sessionId, "Id");
			}
		}
		let sessionId: unknown = _sessionId;
		let _invite: unknown = luaProp(state, "Trade");
		if ((_invite !== undefined)) {
			_invite = luaProp(_invite, "Invite");
		}
		let invite: unknown = _invite;
		let key: unknown = ((sessionId !== undefined) ? `session:${sessionId}` : ((invite !== undefined) ? `invite:${luaProp(invite, "FromUserId")}:${luaProp(invite, "ExpiresAt")}` : ""));
		if ((key === "")) {
			luaSet(tradeFocusKey, "current", "");
			return undefined;
		}
		let fresh: unknown = (key !== luaProp(tradeFocusKey, "current"));
		if (fresh) {
			luaSet(tradeFocusKey, "current", key);
			colon(Audio).play(((sessionId !== undefined) ? "confirm" : "invite"));
			if ((sessionId !== undefined)) {
				luaCall(setHidden, false);
				luaCall(setPlayerlistOpen, false);
				luaCall(setFeedbackOpen, false);
				if (drawerNav) {
					luaCall(setRailOpen, false);
				}
				luaCall(setPage, "Trade");
			}
		}
		return undefined;
	};
	let _result_5: unknown = luaProp(state, "Trade");
	if ((_result_5 !== undefined)) {
		_result_5 = luaProp(_result_5, "Invite");
		if ((_result_5 !== undefined)) {
			_result_5 = luaProp(_result_5, "ExpiresAt");
		}
	}
	let _result_6: unknown = luaProp(state, "Trade");
	if ((_result_6 !== undefined)) {
		_result_6 = luaProp(_result_6, "Invite");
		if ((_result_6 !== undefined)) {
			_result_6 = luaProp(_result_6, "FromUserId");
		}
	}
	let _result_7: unknown = luaProp(state, "Trade");
	if ((_result_7 !== undefined)) {
		_result_7 = luaProp(_result_7, "Session");
		if ((_result_7 !== undefined)) {
			_result_7 = luaProp(_result_7, "Id");
		}
	}
	reactLoose.useEffect(_exp, [drawerNav, _result_5, _result_6, _result_7]);
	let tradeAwaySent: unknown = reactLoose.useRef(false);
	let _exp_1: unknown = function(): unknown | undefined {
		let _result_8: unknown = luaProp(state, "Trade");
		if ((_result_8 !== undefined)) {
			_result_8 = luaProp(_result_8, "Session");
		}
		let live: unknown = (_result_8 !== undefined);
		if ((!live)) {
			luaSet(tradeAwaySent, "current", false);
			return undefined;
		}
		let away: unknown = (page !== "Trade");
		if ((away === luaProp(tradeAwaySent, "current"))) {
			return undefined;
		}
		luaSet(tradeAwaySent, "current", away);
		luaCall(dispatch, "TradeViewAway", { Away: away });
		return undefined;
	};
	let _result_8: unknown = luaProp(state, "Trade");
	if ((_result_8 !== undefined)) {
		_result_8 = luaProp(_result_8, "Session");
		if ((_result_8 !== undefined)) {
			_result_8 = luaProp(_result_8, "Id");
		}
	}
	reactLoose.useEffect(_exp_1, [dispatch, page, _result_8]);
	reactLoose.useEffect(function(): unknown | undefined {
		let player: unknown = luaProp(Players, "LocalPlayer");
		let unfocusedAt: unknown = (-(luaProp(math, "huge") as unknown as number));
		let focused: unknown = true;
		let mark: unknown = function(away?: unknown): unknown | undefined {
			colon(player).SetAttribute("AF_Away", away);
			colon(player).SetAttribute("AF_AwayAt", (away ? luaCall(luaProp(os, "clock")) : 0));
			return undefined;
		};
		luaCall(mark, false);
		let lost: unknown = colon(luaProp(UserInputService, "WindowFocusReleased")).Connect(function(): unknown | undefined {
			focused = false;
			unfocusedAt = luaCall(luaProp(os, "clock"));
			return undefined;
		});
		let gained: unknown = colon(luaProp(UserInputService, "WindowFocused")).Connect(function(): unknown | undefined {
			focused = true;
			luaCall(mark, false);
			return undefined;
		});
		let menuOpen: unknown = colon(luaProp(GuiService, "MenuOpened")).Connect(function(): unknown | undefined {
			focused = false;
			unfocusedAt = luaCall(luaProp(os, "clock"));
			return undefined;
		});
		let menuClose: unknown = colon(luaProp(GuiService, "MenuClosed")).Connect(function(): unknown | undefined {
			focused = true;
			luaCall(mark, false);
			return undefined;
		});
		let pulse: unknown = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
			while (true) {
				luaCall(luaProp(task, "wait"), 1);
				if (((!focused) && ((((luaCall(luaProp(os, "clock")) as unknown as number) - (unfocusedAt as unknown as number)) as unknown as number) >= (20 as unknown as number)))) {
					luaCall(mark, true);
				}
			}
			return undefined;
		});
		return function(): unknown | undefined {
			colon(lost).Disconnect();
			colon(gained).Disconnect();
			colon(menuOpen).Disconnect();
			colon(menuClose).Disconnect();
			luaCall(luaProp(task, "cancel"), pulse);
			luaCall(mark, false);
			return undefined;
		};
		return undefined;
	}, {});
	reactLoose.useEffect(function(): unknown | undefined {
		luaSet(GuiService, "AutoSelectGuiEnabled", true);
		luaSet(GuiService, "GuiNavigationEnabled", true);
		let BUY_STEPS: unknown = [1, 5, 10, 25, 0];
		let cycleBuy: unknown = function(dir?: unknown): unknown | undefined {
			let index: unknown = ((((luaTable.find(BUY_STEPS, buyAmount) || 0)) as unknown as number) - (1 as unknown as number));
			let at: unknown = (((index as unknown as number) >= (0 as unknown as number)) ? index : 0);
			let stepped: unknown = luaIndex(BUY_STEPS, (((((((((at as unknown as number) + (dir as unknown as number)) as unknown as number) + (len(BUY_STEPS) as unknown as number))) as unknown as number) % (len(BUY_STEPS) as unknown as number)) as unknown as number) + (1 as unknown as number)));
			luaCall(setBuyAmount, stepped);
			colon(Audio).play("tick");
			return undefined;
		};
		let actionName: unknown = "AstralForgeNavigation";
		colon(ContextActionService).BindActionAtPriority(actionName, function(_name?: unknown, inputState?: unknown, input?: unknown): unknown | undefined {
			if ((inputState !== luaProp(luaProp(Enum, "UserInputState"), "Begin"))) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			if ((colon(UserInputService).GetFocusedTextBox() !== undefined)) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			if (arcadeBusy) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			if (((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB")) && (page === "Credits"))) {
				luaCall(luaProp(navigateRef, "current"), "Overview");
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if (((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB")) && playerlistOpen)) {
				luaCall(setPlayerlistOpen, false);
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if (((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB")) && feedbackOpen)) {
				luaCall(setFeedbackOpen, false);
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if (((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB")) && showRelease)) {
				luaCall(dispatch, "DismissRelease");
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if (((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB")) && tutorialOpen)) {
				if (((tutorialStep as unknown as number) > (1 as unknown as number))) {
					luaCall(dispatch, "SetTutorialStep", { Step: ((tutorialStep as unknown as number) - (1 as unknown as number)) });
				}
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((((((((crateReveal !== undefined) || playerlistOpen) || feedbackOpen) || (page === "Credits")) || domainOverlayActive) || showRelease) || tutorialOpen)) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonB"))) {
				if (hidden) {
					luaCall(setHidden, false);
				} else if (railOpen) {
					luaCall(setRailOpen, false);
				} else {
					luaCall(setRailOpen, true);
				}
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonY"))) {
				colon(Audio).play("vaultBank");
				luaCall(dispatch, "CollectVault");
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonX"))) {
				colon(Audio).play("reactorPulse");
				luaCall(dispatch, "Overcharge");
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonSelect"))) {
				luaCall(setHidden, function(current?: unknown): unknown | undefined {
					return (!current);
					return undefined;
				});
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonL2"))) {
				luaCall(cycleBuy, -1);
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonR2"))) {
				luaCall(cycleBuy, 1);
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonStart"))) {
				luaCall(luaProp(navigateRef, "current"), "Settings");
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			let rail: unknown = colon(AppHelpers).visibleNav(luaProp(navigationStateRef, "current"), luaProp(tutorialPageRef, "current"));
			if ((len(rail) === 0)) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			let _callback: unknown = function(entry?: unknown): unknown | undefined {
				return (luaProp(entry, "id") === page);
				return undefined;
			};
			let _result_9: unknown = -1;
			for (const [_i, _v] of pairs((rail) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), rail) === true)) {
					_result_9 = ((_i as unknown as number) - (1 as unknown as number));
					break;
				}
			}
			let index: unknown = luaCall(luaProp(math, "max"), 0, _result_9);
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonL1"))) {
				luaCall(luaProp(navigateRef, "current"), luaProp(luaIndex(rail, (((((((((index as unknown as number) - (1 as unknown as number)) as unknown as number) + (len(rail) as unknown as number))) as unknown as number) % (len(rail) as unknown as number)) as unknown as number) + (1 as unknown as number))), "id"));
			} else if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "ButtonR1"))) {
				luaCall(luaProp(navigateRef, "current"), luaProp(luaIndex(rail, (((((((index as unknown as number) + (1 as unknown as number))) as unknown as number) % (len(rail) as unknown as number)) as unknown as number) + (1 as unknown as number))), "id"));
			} else {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			return undefined;
		}, false, 2200, luaProp(luaProp(Enum, "KeyCode"), "ButtonB"), luaProp(luaProp(Enum, "KeyCode"), "ButtonL1"), luaProp(luaProp(Enum, "KeyCode"), "ButtonR1"), luaProp(luaProp(Enum, "KeyCode"), "ButtonY"), luaProp(luaProp(Enum, "KeyCode"), "ButtonX"), luaProp(luaProp(Enum, "KeyCode"), "ButtonSelect"), luaProp(luaProp(Enum, "KeyCode"), "ButtonL2"), luaProp(luaProp(Enum, "KeyCode"), "ButtonR2"), luaProp(luaProp(Enum, "KeyCode"), "ButtonStart"));
		return function(): unknown | undefined {
			return colon(ContextActionService).UnbindAction(actionName);
			return undefined;
		};
		return undefined;
	}, [arcadeBusy, buyAmount, crateReveal, dispatch, domainOverlayActive, feedbackOpen, hidden, page, playerlistOpen, railOpen, showRelease, tutorialOpen, tutorialStep]);
	// Keyboard: "/" opens chat ready to type, Tab shows or hides the player list. Roblox's own chat
	// bar and player list are turned off, so both keys are free.
	let requestChatFocus: unknown = luaProp(chat, "requestFocus");
	reactLoose.useEffect(function(): unknown | undefined {
		let actionName: unknown = "AstralForgeKeyboard";
		colon(ContextActionService).BindActionAtPriority(actionName, function(_name?: unknown, inputState?: unknown, input?: unknown): unknown | undefined {
			if (((inputState !== luaProp(luaProp(Enum, "UserInputState"), "Begin")) || (colon(UserInputService).GetFocusedTextBox() !== undefined))) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			if (((((crateReveal !== undefined) || tutorialOpen) || showRelease) || domainOverlayActive)) {
				return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "Slash"))) {
				luaCall(setPlayerlistOpen, false);
				luaCall(luaProp(navigateRef, "current"), "Chat");
				if ((requestChatFocus !== undefined)) {
					luaCall(requestChatFocus);
				}
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			if ((luaProp(input, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "Tab"))) {
				luaCall(setPlayerlistOpen, function(current?: unknown): unknown | undefined {
					return (!current);
					return undefined;
				});
				return luaProp(luaProp(Enum, "ContextActionResult"), "Sink");
			}
			return luaProp(luaProp(Enum, "ContextActionResult"), "Pass");
			return undefined;
		}, false, 2100, luaProp(luaProp(Enum, "KeyCode"), "Slash"), luaProp(luaProp(Enum, "KeyCode"), "Tab"));
		return function(): unknown | undefined {
			colon(ContextActionService).UnbindAction(actionName);
			return undefined;
		};
		return undefined;
	}, [crateReveal, domainOverlayActive, requestChatFocus, showRelease, tutorialOpen]);
	let gamepadActive: unknown;
	let setGamepadActive: unknown;
	[gamepadActive, setGamepadActive] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	reactLoose.useEffect(function(): unknown | undefined {
		let isPad: unknown = function(inputType?: unknown): unknown | undefined {
			return ((((inputType === luaProp(luaProp(Enum, "UserInputType"), "Gamepad1")) || (inputType === luaProp(luaProp(Enum, "UserInputType"), "Gamepad2"))) || (inputType === luaProp(luaProp(Enum, "UserInputType"), "Gamepad3"))) || (inputType === luaProp(luaProp(Enum, "UserInputType"), "Gamepad4")));
			return undefined;
		};
		let sync: unknown = function(inputType?: unknown): unknown | undefined {
			return luaCall(setGamepadActive, luaCall(isPad, inputType));
			return undefined;
		};
		luaCall(sync, colon(UserInputService).GetLastInputType());
		let connection: unknown = colon(luaProp(UserInputService, "LastInputTypeChanged")).Connect(sync);
		return function(): unknown | undefined {
			return colon(connection).Disconnect();
			return undefined;
		};
		return undefined;
	}, {});
	let sampledAntilag: unknown = luaCall(useAntilag);
	let _condition_5: unknown = luaProp(luaProp(state, "Settings"), "PerformanceBias");
	if ((_condition_5 === undefined)) {
		_condition_5 = 0.5;
	}
	let performanceBias: unknown = _condition_5;
	let performanceTierCap: unknown = (((performanceBias as unknown as number) >= (0.88 as unknown as number)) ? 1 : (((performanceBias as unknown as number) >= (0.68 as unknown as number)) ? 2 : 3));
	let rootAntilag: unknown = reactLoose.useMemo(function(): unknown | undefined {
		return luaCall(clampAntilagTier, sampledAntilag, performanceTierCap);
		return undefined;
	}, [performanceTierCap, sampledAntilag]);
	let _condition_6: unknown = luaProp(luaProp(state, "Settings"), "BackgroundDetail");
	if ((_condition_6 === undefined)) {
		_condition_6 = 0.8;
	}
	let backgroundDetail: unknown = _condition_6;
	let _condition_7: unknown = luaProp(luaProp(state, "Settings"), "GlowIntensity");
	if ((_condition_7 === undefined)) {
		_condition_7 = 0.75;
	}
	let glowIntensity: unknown = _condition_7;
	let suppressBackground: unknown = (((backgroundDetail as unknown as number) < (0.34 as unknown as number)) || (!luaProp(rootAntilag, "allowAmbient")));
	let _condition_8: unknown = luaProp(luaProp(state, "Settings"), "ParticleDensity");
	if ((_condition_8 === undefined)) {
		_condition_8 = 0.75;
	}
	let renderEffectsScale: unknown = ((((effectsScale as unknown as number) * (_condition_8 as unknown as number)) as unknown as number) * (luaProp(rootAntilag, "fxBudget") as unknown as number));
	let _result_9: unknown;
	if (((len(pops) as unknown as number) > (luaProp(rootAntilag, "maxPops") as unknown as number))) {
		let _newValue: unknown = {};
		let _callback: unknown = function(_?: unknown, index?: unknown): unknown | undefined {
			return ((index as unknown as number) >= (((len(pops) as unknown as number) - (luaProp(rootAntilag, "maxPops") as unknown as number)) as unknown as number));
			return undefined;
		};
		let _length: unknown = 0;
		for (const [_k, _v] of pairs((pops) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), pops) === true)) {
				_length = ((_length as unknown as number) + (1 as unknown as number));
				luaSetIndex(_newValue, _length, _v);
			}
		}
		_result_9 = _newValue;
	} else {
		_result_9 = pops;
	}
	let visiblePops: unknown = _result_9;
	let heavyPage: unknown = (((page === "Worlds") || (page === "Anomaly")) || (page === "StarGrid"));
	let quietPage: unknown = ((((((page === "Story") || (page === "Chat")) || (page === "Mail")) || (page === "Credits")) || (page === "Leaderboards")) || (page === "Admin"));
	let pageAntilag: unknown = reactLoose.useMemo(function(): unknown | undefined {
		let _result_10: unknown;
		if (arcadeBusy) {
			let _object: unknown = luaCall(luaProp(table, "clone"), rootAntilag);
			luaCall(setmetatable, _object, undefined);
			luaSet(_object, "allowConfetti", false);
			luaSet(_object, "maxStars", 0);
			luaSet(_object, "maxClocks", luaCall(luaProp(math, "min"), luaProp(rootAntilag, "maxClocks"), 4));
			_result_10 = _object;
		} else {
			let _result_11: unknown;
			if (heavyPage) {
				let _object: unknown = luaCall(luaProp(table, "clone"), rootAntilag);
				luaCall(setmetatable, _object, undefined);
				luaSet(_object, "maxStars", 0);
				luaSet(_object, "maxClocks", luaCall(luaProp(math, "min"), luaProp(rootAntilag, "maxClocks"), ((page === "Anomaly") ? 8 : 4)));
				_result_11 = _object;
			} else {
				let _result_12: unknown;
				if (quietPage) {
					let _object: unknown = luaCall(luaProp(table, "clone"), rootAntilag);
					luaCall(setmetatable, _object, undefined);
					luaSet(_object, "maxStars", luaCall(luaProp(math, "min"), luaProp(rootAntilag, "maxStars"), 4));
					_result_12 = _object;
				} else {
					_result_12 = rootAntilag;
				}
				_result_11 = _result_12;
			}
			_result_10 = _result_11;
		}
		return _result_10;
		return undefined;
	}, [arcadeBusy, heavyPage, page, quietPage, rootAntilag]);
	reactLoose.useEffect(function(): unknown | undefined {
		let scene: unknown = (cinematicOpen ? "cinematic" : (arcadeBusy ? "arcade" : (heavyPage ? "heavy" : "normal")));
		luaCall(setAntilagScene, scene);
		return function(): unknown | undefined {
			return luaCall(setAntilagScene, "normal");
			return undefined;
		};
		return undefined;
	}, [arcadeBusy, cinematicOpen, heavyPage]);
	reactLoose.useEffect(function(): unknown | undefined {
		luaCall(setClockBudget, luaProp(pageAntilag, "maxClocks"));
		return undefined;
	}, [luaProp(pageAntilag, "maxClocks")]);
	let _exp_2: unknown = reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)([new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Palette, "void")), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, luaProp(Palette, "graphite")), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, luaProp(Palette, "void"))]), Rotation: 112 });
	let _exp_3: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 1), BackgroundColor3: luaProp(Palette, "brass"), BackgroundTransparency: colon(hideAmount).map(function(amount?: unknown): unknown | undefined {
		return luaCall(luaProp(math, "clamp"), ((0.8 as unknown as number) + (amount as unknown as number)), 0, 1);
		return undefined;
	}), BorderSizePixel: 0, ZIndex: 2 });
	let _condition_9: unknown = luaProp(luaProp(state, "Settings"), "BackgroundStars");
	if ((_condition_9 === undefined)) {
		_condition_9 = 1;
	}
	let _condition_10: unknown = ((_condition_9 as unknown as number) >= (0.5 as unknown as number));
	if (_condition_10) {
		_condition_10 = (((backgroundDetail as unknown as number) >= (0.2 as unknown as number)) && reactLoose.createElement(StarField, { accent: accent, reducedMotion: ((((softMotion || heavyPage) || quietPage) || arcadeBusy) || ((backgroundDetail as unknown as number) < (0.58 as unknown as number))) }));
	}
	let _condition_11: unknown = luaProp(luaProp(state, "Settings"), "AmbientGlow");
	if ((_condition_11 === undefined)) {
		_condition_11 = 1;
	}
	let _condition_12: unknown = ((_condition_11 as unknown as number) >= (0.5 as unknown as number));
	if (_condition_12) {
		_condition_12 = ((!suppressBackground) && reactLoose.createElement(AmbientLayer, { accent: accent, reducedMotion: (((softMotion || heavyPage) || quietPage) || arcadeBusy), intensity: glowIntensity }));
	}
	let _condition_13: unknown = luaProp(luaProp(state, "Settings"), "AmbientGlow");
	if ((_condition_13 === undefined)) {
		_condition_13 = 1;
	}
	let _condition_14: unknown = ((_condition_13 as unknown as number) >= (0.5 as unknown as number));
	if (_condition_14) {
		_condition_14 = ((((glowIntensity as unknown as number) > (0.02 as unknown as number)) && ((backgroundDetail as unknown as number) >= (0.45 as unknown as number))) && reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 620, 620), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 170, 1, 90), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: accent, BackgroundTransparency: ((1 as unknown as number) - (((0.035 as unknown as number) * (luaCall(luaProp(math, "clamp"), glowIntensity, 0, 1) as unknown as number)) as unknown as number)), BorderSizePixel: 0, Rotation: -12 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
	}
	let _condition_15: unknown = luaProp(luaProp(state, "Settings"), "AmbientGlow");
	if ((_condition_15 === undefined)) {
		_condition_15 = 1;
	}
	let _condition_16: unknown = ((_condition_15 as unknown as number) >= (0.5 as unknown as number));
	if (_condition_16) {
		_condition_16 = ((((glowIntensity as unknown as number) > (0.02 as unknown as number)) && ((backgroundDetail as unknown as number) >= (0.7 as unknown as number))) && reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 420, 420), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, -170, 0, -130), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "cyan"), BackgroundTransparency: ((1 as unknown as number) - (((0.025 as unknown as number) * (luaCall(luaProp(math, "clamp"), glowIntensity, 0, 1) as unknown as number)) as unknown as number)), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
	}
	let _exp_4: unknown = (((!keyboardShellCompact) && mobileShell) && reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(MobileHeader, { state: state, page: page, accent: accent, width: luaProp(viewport, "width"), topPad: topPad, barHeight: topbarHeight, edgePad: edgePad, reducedMotion: softMotion, openPlayerlist: function(): unknown | undefined {
		luaCall(setFeedbackOpen, false);
		luaCall(setPlayerlistOpen, true);
		return undefined;
	} }), reactLoose.createElement(luaProp(mod("BuffStrip"), "Island"), { state: state, config: config, reducedMotion: softMotion, restHidden: true, maxWidth: ((luaProp(viewport, "width") as unknown as number) - (((edgePad as unknown as number) * (2 as unknown as number)) as unknown as number)), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0, ((((topPad as unknown as number) + (topbarHeight as unknown as number)) as unknown as number) + (6 as unknown as number))), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0) })));
	let _condition_17: unknown = ((!keyboardShellCompact) && (!mobileShell));
	if (_condition_17) {
		let _attributes: unknown = { state: state, page: page, railOpen: railOpen, toggleRail: function(): unknown | undefined {
			luaCall(setRailOpen, (!railOpen));
			return undefined;
		}, hideUI: function(): unknown | undefined {
			return luaCall(setHidden, true);
			return undefined;
		}, tight: luaProp(viewport, "tight"), width: luaProp(viewport, "width"), topPad: topPad, barHeight: topbarHeight, barHeightMotion: topbarLive, edgePad: edgePad, reducedMotion: softMotion };
		let _condition_18: unknown = luaProp(luaProp(config, "Release"), "CountdownAt");
		if ((_condition_18 === undefined)) {
			_condition_18 = 1789272000;
		}
		luaSet(_attributes, "releaseAt", _condition_18);
		luaSet(_attributes, "visit", visit);
		luaSet(_attributes, "config", config);
		luaSet(_attributes, "navigate", setPage);
		luaSet(_attributes, "openPlayerlist", function(): unknown | undefined {
			luaCall(setFeedbackOpen, false);
			luaCall(setPlayerlistOpen, true);
			return undefined;
		});
		luaSet(_attributes, "openFeedback", function(): unknown | undefined {
			luaCall(setPlayerlistOpen, false);
			luaCall(setFeedbackOpen, true);
			return undefined;
		});
		_condition_17 = reactLoose.createElement(TopBar, _attributes);
	}
	let _condition_18: unknown = false;
	let _exp_5: unknown = reactLoose.createElement(React.Fragment, undefined, _condition_10, _condition_12, _condition_14, _condition_16, _exp_4, _condition_17, _condition_18);
	let _exp_6: unknown = reactLoose.createElement("frame", { Size: workspaceSize, Position: workspaceOffset, BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 5 }, reactLoose.createElement(luaProp(AntilagContext, "Provider"), { value: pageAntilag }, reactLoose.createElement(Workspace, { page: page, state: state, dispatch: dispatch, config: config, reducedMotion: reducedMotion }, reactLoose.createElement(PageFrame, { page: page, ref: pageHostRef }, reactLoose.createElement(PageContent, { key: page, page: page, state: state, config: config, dispatch: dispatch, reducedMotion: reducedMotion, domainOverlayActive: domainOverlayActive, openWorkshop: openWorkshop, openDomain: openDomain, buyAmount: buyAmount, setBuyAmount: setBuyAmount, onWheelLand: onWheelLand, wallClock: wallClock, activeBoostExpired: activeBoostExpired, clearConfetti: clearConfetti, chat: chat, visit: visit, setVisit: setVisit, addNotice: addNotice, crateRevealActive: (crateReveal !== undefined), setCrateReveal: setCrateReveal, navigate: navigateStable, setArcadeBusy: setArcadeBusy, setPurchasePresentationActive: setPurchasePresentationActive })))));
	let _exp_7: unknown = (((!mobileShell) && drawerNav) && reactLoose.createElement("imagebutton", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: drawerScrimTransparency, BorderSizePixel: 0, AutoButtonColor: false, Selectable: false, Active: railOpen, Visible: drawerScrimVisible, ZIndex: 28, Event: { Activated: function(): unknown | undefined {
		luaCall(setRailOpen, false);
		colon(Audio).play("close");
		return undefined;
	} } }));
	let _condition_19: unknown = (!mobileShell);
	if (_condition_19) {
		let _attributes: unknown = { page: page, setPage: navigate, collapsed: ((!drawerNav) && luaProp(viewport, "compact")), width: railWidth, fixedWidth: (drawerNav ? drawerWidth : undefined), reducedMotion: softMotion, state: state, chatUnread: luaProp(chat, "unread") };
		let _result_10: unknown = tutorial;
		if ((_result_10 !== undefined)) {
			_result_10 = luaProp(_result_10, "page");
		}
		luaSet(_attributes, "tutorialPage", _result_10);
		luaSet(_attributes, "includeSecondary", true);
		luaSet(_attributes, "fromMore", false);
		luaSet(_attributes, "activeBoost", activeBoost);
		luaSet(_attributes, "activeBoostEndsAt", activeBoostEndsAt);
		luaSet(_attributes, "wallClock", wallClock);
		luaSet(_attributes, "openBoosts", function(): unknown | undefined {
			return luaCall(navigate, "Rewards");
			return undefined;
		});
		_condition_19 = reactLoose.createElement("frame", { Size: (drawerNav ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, drawerWidth, 1, 0) : colon(railWidth).map(function(width?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, luaCall(luaProp(math, "max"), 0, width), 1, 0);
			return undefined;
		})), Position: (drawerNav ? colon(drawerProgress).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, (((-(drawerWidth as unknown as number)) as unknown as number) * ((((1 as unknown as number) - (amount as unknown as number))) as unknown as number)), 0, 0);
			return undefined;
		}) : undefined), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: (drawerNav ? 30 : 10), ClipsDescendants: true, Visible: (drawerNav ? drawerScrimVisible : drawerPanelVisible) }, reactLoose.createElement(Navigation, _attributes));
	}
	let gamepadReserve: unknown = (gamepadActive ? 44 : 0);
	let _exp_8: unknown = reactLoose.createElement("frame", { Size: colon(shellTopLive).map(function(top?: unknown): unknown | undefined {
		return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (((-(edgePad as unknown as number)) as unknown as number) * (2 as unknown as number)), 1, (-((((((top as unknown as number) + (bottomPad as unknown as number)) as unknown as number) + (gamepadReserve as unknown as number))) as unknown as number)));
		return undefined;
	}), Position: colon(shellTopLive).map(function(top?: unknown): unknown | undefined {
		return luaCall(luaProp(UDim2, "fromOffset"), edgePad, top);
		return undefined;
	}), BackgroundTransparency: 1, BorderSizePixel: 0 }, _exp_6, _exp_7, _condition_19);
	let _result_10: unknown = luaProp(state, "Trade");
	if ((_result_10 !== undefined)) {
		_result_10 = luaProp(_result_10, "Session");
	}
	let _condition_20: unknown = (_result_10 !== undefined);
	if (_condition_20) {
		_condition_20 = ((page !== "Trade") && reactLoose.createElement(TradeReturnPill, { stack: luaProp(chrome, "stack"), bottomPad: bottomPad, reducedMotion: softMotion, onReturn: function(): unknown | undefined {
			luaCall(setHidden, false);
			luaCall(setRailOpen, false);
			luaCall(navigate, "Trade");
			return undefined;
		} }));
	}
	let _condition_21: unknown = mobileShell;
	if (_condition_21) {
		let _attributes: unknown = { page: page, setPage: navigate, state: state, chatUnread: luaProp(chat, "unread") };
		let _result_11: unknown = tutorial;
		if ((_result_11 !== undefined)) {
			_result_11 = luaProp(_result_11, "page");
		}
		luaSet(_attributes, "tutorialPage", _result_11);
		luaSet(_attributes, "reducedMotion", reducedMotion);
		luaSet(_attributes, "height", tabBarH);
		luaSet(_attributes, "bottomSafe", luaProp(chrome, "bottomSafe"));
		luaSet(_attributes, "visible", (!keyboardShellCompact));
		luaSet(_attributes, "viewportHeight", luaProp(viewport, "height"));
		luaSet(_attributes, "moreCols", luaProp(chrome, "moreCols"));
		luaSet(_attributes, "moreCellH", luaProp(chrome, "moreCellH"));
		_condition_21 = reactLoose.createElement(MobileTabBar, _attributes);
	}
	let _exp_9: unknown = ((mobileShell && quickActionsVisible) && reactLoose.createElement(MobileQuickActions, { state: state, dispatch: dispatch, reducedMotion: reducedMotion, bottomOffset: quickBottomOffset, edgePad: edgePad }));
	let _exp_10: unknown = ((!hidden) && reactLoose.createElement(ComboBadge, { readout: comboReadout, reducedMotion: reducedMotion, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -18, 0, ((((topPad as unknown as number) + (topbarHeight as unknown as number)) as unknown as number) + (8 as unknown as number))), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0), zIndex: 65 }));
	let _exp_11: unknown = (((renderEffectsScale as unknown as number) > (0.05 as unknown as number)) && reactLoose.createElement(EffectLayer, { pops: visiblePops }));
	let _condition_22: unknown = undefined;
	let _exp_12: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), Position: colon(hideAmount).map(function(amount?: unknown): unknown | undefined {
		let base: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, ((amount as unknown as number) * (1.05 as unknown as number)), 0);
		return base;
		return undefined;
	}), BackgroundTransparency: 1, BorderSizePixel: 0 }, _exp_5, _exp_8, reactLoose.createElement(React.Fragment, undefined, _condition_20, _condition_21, _exp_9, _exp_10, _exp_11, _condition_22), reactLoose.createElement(luaProp(mod("QuickFind"), "QuickFind"), { state: state, dispatch: dispatch, navigate: navigateStable, chatUnread: luaProp(chat, "unread"), reducedMotion: reducedMotion, enabled: ((((!hidden) && (!tutorialOpen)) && (!domainOverlayActive)) && (!showRelease)) }));
	let _exp_13: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 186, 44), Position: colon(hideAmount).map(function(amount?: unknown): unknown | undefined {
		return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, edgePad, 0, ((-64 as unknown as number) + (luaCall(luaProp(math, "floor"), ((amount as unknown as number) * ((((topPad as unknown as number) + (64 as unknown as number))) as unknown as number))) as unknown as number)));
		return undefined;
	}), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 200 }, reactLoose.createElement(Button, { text: "SHOW UI  ( ` )", icon: "Hide.2", onClick: function(): unknown | undefined {
		return luaCall(setHidden, false);
		return undefined;
	}, color: accent, textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion }));
	let ownedMachines: unknown = 0;
	let machineTable: unknown = luaProp(state, "Machines");
	if ((luaTypeIs(machineTable, "table"))) {
		for (const [_, level] of pairs((machineTable) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let amount: unknown = level;
			if ((luaTypeIs(amount, "table"))) {
				amount = ((luaProp(amount, "Level") || luaProp(amount, "level")) || 0);
			}
			if (((luaTypeIs(amount, "number")) && ((amount as unknown as number) > (0 as unknown as number)))) {
				ownedMachines = ((ownedMachines as unknown as number) + (1 as unknown as number));
			}
		}
	}
	let _exp_14: unknown = (((!luaProp(luaProp(state, "Flags"), "TutorialDone")) && (tutorial !== undefined)) && reactLoose.createElement(TutorialOverlay, { copy: tutorial, step: tutorialStep, count: len(TUTORIAL_STEPS), viewportWidth: luaProp(viewport, "width"), viewportHeight: luaProp(viewport, "height"), reducedMotion: reducedMotion, live: { page: page, cash: luaCall(compactNumber, luaProp(state, "Cash")), vault: luaCall(compactNumber, luaProp(state, "Vault")), vaultFlux: luaCall(asFlux, luaProp(state, "Vault")), production: luaCall(compactNumber, luaProp(state, "Production")), ownedMachines: ownedMachines, buyAmount: buyAmount }, ctaLabel: luaProp(tutorial, "ctaLabel"), onCta: ((luaProp(tutorial, "cta") === "collect") ? function(): unknown | undefined {
		return luaCall(dispatch, "CollectVault");
		return undefined;
	} : ((luaProp(tutorial, "cta") === "workshop") ? function(): unknown | undefined {
		return luaCall(navigate, "Workshop");
		return undefined;
	} : ((luaProp(tutorial, "cta") === "research") ? function(): unknown | undefined {
		return luaCall(navigate, "Research");
		return undefined;
	} : undefined))), onBack: function(): unknown | undefined {
		let targetStep: unknown = luaCall(luaProp(math, "max"), 1, ((tutorialStep as unknown as number) - (1 as unknown as number)));
		colon(Audio).play("stepBack");
		luaSet(tutorialHold, "current", targetStep);
		luaCall(setTutorialStep, targetStep);
		luaCall(dispatch, "SetTutorialStep", { Step: targetStep });
		return undefined;
	}, onNext: function(): unknown | undefined {
		if (((tutorialStep as unknown as number) >= (len(TUTORIAL_STEPS) as unknown as number))) {
			luaCall(dispatch, "CompleteTutorial");
		} else {
			let targetStep: unknown = ((tutorialStep as unknown as number) + (1 as unknown as number));
			colon(Audio).play("stepNext");
			luaSet(tutorialHold, "current", targetStep);
			luaCall(setTutorialStep, targetStep);
			luaCall(dispatch, "SetTutorialStep", { Step: targetStep });
		}
		return undefined;
	}, onSkip: function(): unknown | undefined {
		return luaCall(dispatch, "CompleteTutorial");
		return undefined;
	} }));
	let _condition_23: unknown = ((gamepadActive && (!hidden)) && (!tutorialOpen));
	if (_condition_23) {
		let _exp_15: unknown = luaCall(luaProp(kit("CoreKit", "GamepadNavigationService"), "GetHintLabels"));
		let _newValue: unknown = luaCall(luaProp(table, "create"), len(_exp_15));
		let _callback: unknown = function(hint?: unknown, index?: unknown): unknown | undefined {
			return reactLoose.createElement(FlexItem, { key: hint, mode: "grow", minWidth: 88, minHeight: 22, layoutOrder: index }, reactLoose.createElement(Text, { value: hint, size: 11, color: luaProp(Palette, "creamSoft"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: true, minSize: 9, sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) }));
			return undefined;
		};
		for (const [_k, _v] of pairs((_exp_15) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), _exp_15));
		}
		_condition_23 = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (((-(edgePad as unknown as number)) as unknown as number) * (2 as unknown as number)), 0, 36), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, edgePad, 1, (-((((bottomPad as unknown as number) + (36 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 180 }, reactLoose.createElement(Flex, { direction: "row", wrap: true, justify: "space-evenly", align: "center", gap: 10, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), exact: true }, _newValue));
	}
	let _exp_15: unknown = (showRelease && reactLoose.createElement(ReleaseNotesModal, { version: luaProp(luaProp(config, "Game"), "Version"), season: luaProp(luaProp(config, "Release"), "Season"), announcement: luaProp(luaProp(config, "Release"), "Announcement"), notes: luaProp(luaProp(config, "Release"), "Notes"), history: luaProp(luaProp(config, "Release"), "History"), viewportWidth: luaProp(viewport, "width"), viewportHeight: luaProp(viewport, "height"), reducedMotion: reducedMotion, onClose: function(): unknown | undefined {
		luaCall(setReleaseClosedLocally, true);
		luaCall(dispatch, "DismissRelease");
		return undefined;
	}, onOpenMail: function(): unknown | undefined {
		colon(Audio).play("mail");
		luaCall(setReleaseClosedLocally, true);
		luaCall(dispatch, "DismissRelease");
		luaCall(setPage, "Mail");
		return undefined;
	} }));
	let _exp_16: unknown = ((page === "Credits") && reactLoose.createElement(CreditsOverlay, { version: luaProp(luaProp(state, "Game"), "Version"), reducedMotion: reducedMotion, onClose: function(): unknown | undefined {
		return luaCall(navigate, "Overview");
		return undefined;
	} }));
	let _exp_17: unknown = (playerlistOpen && reactLoose.createElement(PlayerlistOverlay, { state: state, dispatch: dispatch, reducedMotion: reducedMotion, onClose: function(): unknown | undefined {
		return luaCall(setPlayerlistOpen, false);
		return undefined;
	}, onMessage: function(userId?: unknown): unknown | undefined {
		luaCall(setPlayerlistOpen, false);
		luaCall(navigate, "Chat");
		luaCall(luaProp(chat, "openWhisper"), userId);
		return undefined;
	}, notify: function(title?: unknown, body?: unknown): unknown | undefined {
		return luaCall(addNotice, title, body, "Info");
		return undefined;
	} }));
	let _exp_18: unknown = (feedbackOpen && reactLoose.createElement(FeedbackOverlay, { dispatch: dispatch, page: ((luaTypeIs(page, "string")) ? page : undefined), reducedMotion: reducedMotion, onClose: function(): unknown | undefined {
		return luaCall(setFeedbackOpen, false);
		return undefined;
	}, notify: function(title?: unknown, body?: unknown): unknown | undefined {
		return luaCall(addNotice, title, body, "Info");
		return undefined;
	} }));
	let _condition_24: unknown = (offlineRewardsOpen && reactLoose.createElement(OfflineRewardsOverlay, luaCall(offlineRewardsProps, state, reducedMotion, dispatch, function(): unknown | undefined {
		return luaCall(setDismissedOfflineKey, offlineReceiptKey);
		return undefined;
	})));
	return reactLoose.createElement(luaProp(AntilagContext, "Provider"), { value: rootAntilag }, reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: hideAmount, BorderSizePixel: 0, ClipsDescendants: true, Visible: (crateReveal === undefined) }, _exp_2, _exp_3, _exp_12, _exp_13, _exp_14, _condition_23, _exp_15, _exp_16, _exp_17, _exp_18, reactLoose.createElement(LevelRoadmapHost, { state: state, config: config, reducedMotion: reducedMotion }), reactLoose.createElement(LevelMomentHost, { state: state }), reactLoose.createElement(ServerEventHost, { state: state, dispatch: dispatch, inTopBar: ((!keyboardShellCompact) && (!mobileShell)) }), _condition_24), ((crateReveal !== undefined) && reactLoose.createElement(CrateRevealOverlay, { session: crateReveal, config: config, skin: (((state !== undefined) && (luaProp(state, "Cosmetics") !== undefined)) ? luaProp(luaProp(state, "Cosmetics"), "CrateSkin") : undefined), reducedMotion: reducedMotion, onClose: function(): unknown | undefined {
		return luaCall(setCrateReveal, undefined);
		return undefined;
	} })), reactLoose.createElement(RebirthCeremonyHost, { reducedMotion: reducedMotion })));
	return undefined;
}
function Shell(props?: unknown): unknown | undefined {
	let _attributes: unknown = luaCall(luaProp(table, "clone"), props);
	luaCall(setmetatable, _attributes, undefined);
	return reactLoose.createElement(AppShell, _attributes);
	return undefined;
}

export { AppShell, Shell, pausePassivePaints };
