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

let ContentProvider: unknown = colon(game).GetService("ContentProvider");
let Players: unknown = colon(game).GetService("Players");
let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
let RunService: unknown = colon(game).GetService("RunService");
let StarterPlayer: unknown = colon(game).GetService("StarterPlayer");
let UserInputService: unknown = colon(game).GetService("UserInputService");
let WorkspaceService: unknown = colon(game).GetService("Workspace");
let _interaction: unknown = kit("CoreKit", "interaction");
let setHapticIntensity: unknown = luaProp(_interaction, "setHapticIntensity");
let usesDesktopStructure: unknown = luaProp(_interaction, "usesDesktopStructure");
let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
let _effects: unknown = ui("effects");
let POP_SECONDS: unknown = luaProp(_effects, "POP_SECONDS");
let AutoScale: unknown = luaProp(kit("MotionKit", "autoScale"), "AutoScale");
let _antilag: unknown = kit("MotionKit", "antilag");
let AntilagProvider: unknown = luaProp(_antilag, "AntilagProvider");
let _motion: unknown = kit("MotionKit", "motion");
let MotionSettingsContext: unknown = luaProp(_motion, "MotionSettingsContext");
let _ui: unknown = ui("ui");
let _theme: unknown = kit("CoreKit", "theme");
let Palette: unknown = luaProp(_theme, "Palette");
let applyAccessibilityTheme: unknown = luaProp(_theme, "applyAccessibilityTheme");
let _format: unknown = kit("CoreKit", "format");
let compactNumber: unknown = luaProp(_format, "compactNumber");
let _AdminPrankOverlay: unknown = ui("AdminPrankOverlay");
let AdminPrankOverlay: unknown = luaProp(_AdminPrankOverlay, "AdminPrankOverlay");
let HudPrankStage: unknown = luaProp(_AdminPrankOverlay, "HudPrankStage");
let ActionCopy: unknown = kit("CoreKit", "actionCopy");
let NoticeMath: unknown = kit("CoreKit", "noticeMath");
let SnapshotEnvelopeMath: unknown = kit("CoreKit", "snapshotEnvelopeMath");
let _appNav: unknown = kit("CoreKit", "appNav");
let AppHelpers: unknown = luaProp(_appNav, "AppHelpers");
let NetworkPolicy: unknown = kit("CoreKit", "networkPolicy");
let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
let _session: unknown = kit("CoreKit", "session");
let GRANT_ACTIONS: unknown = luaProp(_session, "GRANT_ACTIONS");
let adopt: unknown = luaProp(_session, "adopt");
let attachGrantFields: unknown = luaProp(_session, "attachGrantFields");
let isAuthed: unknown = luaProp(_session, "isAuthed");
let whenAuthed: unknown = luaProp(_session, "whenAuthed");
let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
let Boot: unknown = kit("BootKit", "BootScreen");
let InteractionFeedback: unknown = luaProp(kit("CoreKit", "interaction"), "InteractionFeedback");
let _scrolling: unknown = kit("LayoutKit", "scrolling");
let setScrollMomentum: unknown = luaProp(_scrolling, "setScrollMomentum");
let setScrollSpeed: unknown = luaProp(_scrolling, "setScrollSpeed");
let _clientStore: unknown = kit("CoreKit", "clientStore");
let ClientActions: unknown = luaProp(_clientStore, "ClientActions");
let useClientDispatch: unknown = luaProp(_clientStore, "useClientDispatch");
let useClientSelector: unknown = luaProp(_clientStore, "useClientSelector");
let preloadMountedGame: unknown = luaProp(kit("ClientRuntime", "assetPreloader"), "preloadMountedGame");
let warmClientModules: unknown = luaProp(kit("ClientRuntime", "assetPreloader"), "warmClientModules");
let useClientIntegrityProbe: unknown = luaProp(kit("ClientRuntime", "clientIntegrity"), "useClientIntegrityProbe");
let friendlyPlayerMessage: unknown = luaProp(ActionCopy, "friendlyPlayerMessage");
let failureTitle: unknown = luaProp(ActionCopy, "failureTitle");
let failureBody: unknown = luaProp(ActionCopy, "failureBody");
let friendlyActionResponse: unknown = luaProp(ActionCopy, "friendlyActionResponse");
let _AppShellChrome: unknown = ui("AppShellChrome");
let Shell: unknown = luaProp(_AppShellChrome, "Shell");
let pausePassivePaints: unknown = luaProp(_AppShellChrome, "pausePassivePaints");
let NOOP: unknown = function(): unknown | undefined {

	return undefined;
};
function MainGame(_param?: unknown): unknown | undefined {
	let remotes: unknown = luaProp(_param, "remotes");
	let config: unknown = luaProp(_param, "config");
	let bootStartedAt: unknown = luaProp(_param, "bootStartedAt");
	let externalBoot: unknown = luaProp(_param, "externalBoot");
	if ((externalBoot === undefined)) {
		externalBoot = false;
	}
	let externalAntilag: unknown = luaProp(_param, "externalAntilag");
	if ((externalAntilag === undefined)) {
		externalAntilag = false;
	}
	let destroyFontSamples: unknown = function(): unknown | undefined {
		return undefined;
		return undefined;
	};
	let onBootStatus: unknown = luaProp(_param, "onBootStatus");
	let domainUi: unknown = luaProp(_param, "domainUi");
	let appAlive: unknown = reactLoose.useRef(true);
	let requestWorkers: unknown = reactLoose.useRef({});
	let requestTimeouts: unknown = reactLoose.useRef({});
	let deferredJobs: unknown = reactLoose.useRef({});
	reactLoose.useEffect(function(): unknown | undefined {
		luaSet(appAlive, "current", true);
		return function(): unknown | undefined {
			luaSet(appAlive, "current", false);
			for (const [worker] of pairs((luaProp(requestWorkers, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaCall(pcall, function(): unknown | undefined {
					return luaCall(luaProp(task, "cancel"), worker);
					return undefined;
				});
			}
			for (const [timeout] of pairs((luaProp(requestTimeouts, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaCall(pcall, function(): unknown | undefined {
					return luaCall(luaProp(task, "cancel"), timeout);
					return undefined;
				});
			}
			for (const [job] of pairs((luaProp(deferredJobs, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaCall(pcall, function(): unknown | undefined {
					return luaCall(luaProp(task, "cancel"), job);
					return undefined;
				});
			}
			luaCall(luaProp(table, "clear"), luaProp(requestWorkers, "current"));
			luaCall(luaProp(table, "clear"), luaProp(requestTimeouts, "current"));
			luaCall(luaProp(table, "clear"), luaProp(deferredJobs, "current"));
			return undefined;
		};
		return undefined;
	}, {});
	let state: unknown = luaCall(useClientSelector, function(client?: unknown): unknown | undefined {
		return luaProp(client, "session");
		return undefined;
	});
	let visit: unknown = luaCall(useClientSelector, function(client?: unknown): unknown | undefined {
		return luaProp(client, "visit");
		return undefined;
	});
	let toastDensity: unknown = (((state && luaProp(state, "Settings")) && luaProp(luaProp(state, "Settings"), "ToastDensity")) || 0.55);
	reactLoose.useEffect(function(): unknown | undefined {
		luaCall(luaProp(mod("JuiceFx"), "setToastDensity"), toastDensity);
		return undefined;
	}, [toastDensity]);
	// tooltips follow the Tooltips switch and calm down with Reduced Motion
	let tooltipsOn: unknown = (!(((state && luaProp(state, "Settings")) && (luaProp(luaProp(state, "Settings"), "Tooltips") === 0))));
	let tooltipsCalm: unknown = ((luaProp(colon(game).GetService("GuiService"), "ReducedMotionEnabled") === true) || ((((state && luaProp(state, "Settings")) && ((((luaCall(tonumber, luaProp(luaProp(state, "Settings"), "MotionIntensity")) || 1)) as unknown as number) < (0.3 as unknown as number)))) === true));
	reactLoose.useEffect(function(): unknown | undefined {
		let Tooltip: unknown = mod("Tooltip");
		luaCall(luaProp(Tooltip, "setEnabled"), tooltipsOn);
		luaCall(luaProp(Tooltip, "setReducedMotion"), tooltipsCalm);
		return undefined;
	}, [tooltipsOn, tooltipsCalm]);
	let _exp: unknown = function(): unknown | undefined {
		let _result: unknown = state;
		if ((_result !== undefined)) {
			_result = luaProp(luaProp(_result, "Settings"), "HighContrast");
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let _exp_1: unknown = ((_condition as unknown as number) >= (0.5 as unknown as number));
		let _result_1: unknown = state;
		if ((_result_1 !== undefined)) {
			_result_1 = luaProp(luaProp(_result_1, "Settings"), "ColorblindMode");
		}
		let _condition_1: unknown = _result_1;
		if ((_condition_1 === undefined)) {
			_condition_1 = 0;
		}
		luaCall(applyAccessibilityTheme, _exp_1, ((_condition_1 as unknown as number) >= (0.5 as unknown as number)));
		return undefined;
	};
	let _result: unknown = state;
	if ((_result !== undefined)) {
		_result = luaProp(luaProp(_result, "Settings"), "ColorblindMode");
	}
	let _result_1: unknown = state;
	if ((_result_1 !== undefined)) {
		_result_1 = luaProp(luaProp(_result_1, "Settings"), "HighContrast");
	}
	reactLoose.useEffect(_exp, [_result, _result_1]);
	let dispatchStore: unknown = luaCall(useClientDispatch);
	let setVisit: unknown = reactLoose.useCallback(function(visitNext?: unknown): unknown | undefined {
		return luaCall(dispatchStore, luaCall(luaProp(ClientActions, "setVisit"), visitNext));
		return undefined;
	}, [dispatchStore]);
	let toastsSuppressed: unknown;
	let setToastsSuppressed: unknown;
	[toastsSuppressed, setToastsSuppressed] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
	let purchasePresentationActive: unknown = reactLoose.useRef(false);
	let setPurchasePresentationActive: unknown = reactLoose.useCallback(function(active?: unknown): unknown | undefined {
		luaSet(purchasePresentationActive, "current", active);
		return undefined;
	}, {});
	let confettiNonce: unknown;
	let setConfettiNonce: unknown;
	[confettiNonce, setConfettiNonce] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
	let celebrationSeed: unknown = reactLoose.useRef(luaCall(luaProp(math, "random"), 1, 100000));
	let bootVisible: unknown;
	let setBootVisible: unknown;
	[bootVisible, setBootVisible] = reactLoose.useState((!externalBoot)) as LuaTuple<[unknown, unknown]>;
	let shellMounted: unknown;
	let setShellMounted: unknown;
	[shellMounted, setShellMounted] = reactLoose.useState((!externalBoot)) as LuaTuple<[unknown, unknown]>;
	let shellMountedRef: unknown = reactLoose.useRef(shellMounted);
	luaSet(shellMountedRef, "current", shellMounted);
	let bootMarks: unknown;
	let setBootMarks: unknown;
	[bootMarks, setBootMarks] = reactLoose.useState({ bridge: true, remotes: ((((luaProp(remotes, "Request") !== undefined) && (luaProp(remotes, "State") !== undefined)) && (luaProp(remotes, "Toast") !== undefined)) && (luaProp(remotes, "Effect") !== undefined)), state: false, audio: false, assets: false, fonts: false, modules: false, shell: false, mail: false, research: false, forge: false, trade: false, boosts: false, settings: false, mobile: false }) as LuaTuple<[unknown, unknown]>;
	let assetProgress: unknown;
	let setAssetProgress: unknown;
	[assetProgress, setAssetProgress] = reactLoose.useState({ loaded: 0, total: 0 }) as LuaTuple<[unknown, unknown]>;
	let moduleProgress: unknown;
	let setModuleProgress: unknown;
	[moduleProgress, setModuleProgress] = reactLoose.useState({ loaded: 0, total: 0 }) as LuaTuple<[unknown, unknown]>;
	let onBootExitDone: unknown = reactLoose.useCallback(function(): unknown | undefined {
		return luaCall(setBootVisible, false);
		return undefined;
	}, {});
	let markBoot: unknown = reactLoose.useCallback(function(key?: unknown): unknown | undefined {
		luaCall(setBootMarks, function(current?: unknown): unknown | undefined {
			let _result_2: unknown;
			if (luaIndex(current, key)) {
				_result_2 = current;
			} else {
				let _object: unknown = luaCall(luaProp(table, "clone"), current);
				luaCall(setmetatable, _object, undefined);
				luaSetIndex(_object, key, true);
				_result_2 = _object;
			}
			return _result_2;
			return undefined;
		});
		return undefined;
	}, {});
	// the loading screen's stations follow the checklist
	reactLoose.useEffect(function(): unknown | undefined {
		let Ledger: unknown = kit("BootKit", "BootLedger");
		for (const [key, value] of pairs((bootMarks) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (value) {
				luaCall(luaProp(Ledger, "mark"), key);
			}
		}
		return undefined;
	}, [bootMarks]);
	let bootReady: unknown = luaCall(luaProp(Boot, "bootChecklistReady"), bootMarks);
	let bootFill: unknown = luaCall(luaProp(Boot, "bootProgress"), bootMarks);
	let bootReducedMotion: unknown = false;
	reactLoose.useEffect(function(): unknown | undefined {
		let assetShare: unknown = (((luaProp(assetProgress, "total") as unknown as number) > (0 as unknown as number)) ? luaCall(luaProp(math, "clamp"), ((luaProp(assetProgress, "loaded") as unknown as number) / (luaProp(assetProgress, "total") as unknown as number)), 0, 1) : (luaProp(bootMarks, "assets") ? 1 : 0));
		let moduleShare: unknown = (((luaProp(moduleProgress, "total") as unknown as number) > (0 as unknown as number)) ? luaCall(luaProp(math, "clamp"), ((luaProp(moduleProgress, "loaded") as unknown as number) / (luaProp(moduleProgress, "total") as unknown as number)), 0, 1) : (luaProp(bootMarks, "modules") ? 1 : 0));
		let _result_3: unknown = onBootStatus;
		if ((_result_3 !== undefined)) {
			luaCall(_result_3, { marks: bootMarks, ready: bootReady, progress: ((((((bootFill as unknown as number) * (0.4 as unknown as number)) as unknown as number) + (((assetShare as unknown as number) * (0.3 as unknown as number)) as unknown as number)) as unknown as number) + (((moduleShare as unknown as number) * (0.3 as unknown as number)) as unknown as number)), reducedMotion: bootReducedMotion, assetsLoaded: luaProp(assetProgress, "loaded"), assetsTotal: luaProp(assetProgress, "total"), modulesLoaded: luaProp(moduleProgress, "loaded"), modulesTotal: luaProp(moduleProgress, "total") });
		}
		return undefined;
	}, [luaProp(assetProgress, "loaded"), luaProp(assetProgress, "total"), bootFill, bootMarks, bootReady, bootReducedMotion, luaProp(moduleProgress, "loaded"), luaProp(moduleProgress, "total"), onBootStatus]);
	let adminPrank: unknown;
	let setAdminPrank: unknown;
	[adminPrank, setAdminPrank] = reactLoose.useState() as LuaTuple<[unknown, unknown]>;
	let pops: unknown;
	let setPops: unknown;
	[pops, setPops] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
	let popId: unknown = reactLoose.useRef(0);
	let comboReadout: unknown;
	let setComboReadout: unknown;
	[comboReadout, setComboReadout] = reactLoose.useState() as LuaTuple<[unknown, unknown]>;
	let lastComboTier: unknown = reactLoose.useRef(0);
	let lastNotice: unknown = reactLoose.useRef({ signature: "", at: 0 });
	let busy: unknown = reactLoose.useRef({});
	let inFlight: unknown = reactLoose.useRef({});
	let inFlightTotal: unknown = reactLoose.useRef(0);
	let requestSequence: unknown = reactLoose.useRef(0);
	let sentAt: unknown = reactLoose.useRef({});
	let sentAtCount: unknown = reactLoose.useRef(0);
	let latestSnapshot: unknown = reactLoose.useRef(-1);
	let latestRevision: unknown = reactLoose.useRef(-1);
	let lastTradeEpoch: unknown = reactLoose.useRef(-1);
	let lastSnapshotPaintAt: unknown = reactLoose.useRef((-(luaProp(math, "huge") as unknown as number)));
	let loggedFirstSnapshot: unknown = reactLoose.useRef(false);
	let streakToastSent: unknown = reactLoose.useRef(false);
	let lastAcceptedSnapshot: unknown = reactLoose.useRef(undefined);
	let pendingPassive: unknown = reactLoose.useRef(undefined);
	let passiveFlushJob: unknown = reactLoose.useRef(undefined);
	let acceptStateRef: unknown = reactLoose.useRef(undefined);
	// the last copy of every section the server sent; pushes leave out unchanged sections (listed in
	// Reused) and they are filled back in from here, keeping the same tables so nothing re-renders for them
	let sectionCache: unknown = reactLoose.useRef({});
	let acceptState: unknown = reactLoose.useCallback(function(rawSnapshot?: unknown): unknown | undefined {
		let _rawSnapshot: unknown = rawSnapshot;
		if ((!((luaTypeIs(_rawSnapshot, "table"))))) {
			colon(ClientLog).warnEvery("state-envelope", 10, "UI", "ignored a bad state packet");
			return false;
		}
		let cache: unknown = luaProp(sectionCache, "current");
		let reused: unknown = luaProp(rawSnapshot, "Reused");
		if ((reused !== undefined)) {
			if ((!luaTypeIs(reused, "table"))) {
				return false;
			}
			for (const [_, key] of pairs((reused) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let kept: unknown = luaIndex(cache, key);
				if (((kept === undefined) && (luaTypeIs(state, "table")))) {
					kept = luaIndex(state, key);
				}
				if ((kept === undefined)) {
					// nothing to fill this from yet; a full snapshot will follow
					if (((luaProp(latestSnapshot, "current") as unknown as number) >= (0 as unknown as number))) {
						colon(ClientLog).warnEvery("state-reused", 10, "UI", "waiting for a full snapshot");
					}
					return false;
				}
				luaSetIndex(rawSnapshot, key, kept);
			}
			luaSet(rawSnapshot, "Reused", undefined);
		}
		for (const [key, value] of pairs((rawSnapshot) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaTypeIs(value, "table"))) {
				luaSetIndex(cache, key, value);
			}
		}
		let candidate: unknown = rawSnapshot;
		if ((!luaCall(luaProp(SnapshotEnvelopeMath, "IsValidEnvelope"), candidate))) {
			colon(ClientLog).warnEvery("state-envelope", 10, "UI", "ignored an incomplete snapshot");
			return false;
		}
		let snapshot: unknown = rawSnapshot;
		if (((luaProp(snapshot, "Revision") as unknown as number) < (luaProp(latestRevision, "current") as unknown as number))) {
			return true;
		}
		if (((luaProp(snapshot, "Revision") === luaProp(latestRevision, "current")) && ((luaProp(snapshot, "SnapshotId") as unknown as number) < (luaProp(latestSnapshot, "current") as unknown as number)))) {
			return true;
		}
		if (((luaProp(snapshot, "Revision") as unknown as number) > (luaProp(latestRevision, "current") as unknown as number))) {
			luaSet(latestSnapshot, "current", luaProp(snapshot, "SnapshotId"));
		} else {
			luaSet(latestSnapshot, "current", luaCall(luaProp(math, "max"), luaProp(latestSnapshot, "current"), luaProp(snapshot, "SnapshotId")));
		}
		let now: unknown = luaCall(luaProp(os, "clock"));
		let revisionChanged: unknown = ((luaProp(snapshot, "Revision") as unknown as number) > (luaProp(latestRevision, "current") as unknown as number));
		let _result_6: unknown = luaProp(snapshot, "Trade");
		if ((_result_6 !== undefined)) {
			_result_6 = luaProp(_result_6, "Epoch");
		}
		let _condition: unknown = _result_6;
		if ((_condition === undefined)) {
			_condition = -1;
		}
		let tradeEpoch: unknown = _condition;
		let tradeHot: unknown = (tradeEpoch !== luaProp(lastTradeEpoch, "current"));
		if (tradeHot) {
			luaSet(lastTradeEpoch, "current", tradeEpoch);
		}
		let passivePaintInterval: unknown = (luaProp(UserInputService, "TouchEnabled") ? 0.7 : 0.45);
		if (((luaProp(pausePassivePaints, "current") && (!revisionChanged)) && (!tradeHot))) {
			return true;
		}
		if ((((((luaProp(latestRevision, "current") as unknown as number) >= (0 as unknown as number)) && (!revisionChanged)) && (!tradeHot)) && ((((now as unknown as number) - (luaProp(lastSnapshotPaintAt, "current") as unknown as number)) as unknown as number) < (passivePaintInterval as unknown as number)))) {
			luaSet(pendingPassive, "current", snapshot);
			if (((luaProp(passiveFlushJob, "current") === undefined) && luaProp(appAlive, "current"))) {
				let job: unknown;
				job = luaCall(luaProp(task, "delay"), luaCall(luaProp(math, "max"), 0.02, ((passivePaintInterval as unknown as number) - ((((now as unknown as number) - (luaProp(lastSnapshotPaintAt, "current") as unknown as number))) as unknown as number))), function(): unknown | undefined {
					luaSet(passiveFlushJob, "current", undefined);
					luaSetIndex(luaProp(deferredJobs, "current"), job, undefined);
					let pending: unknown = luaProp(pendingPassive, "current");
					luaSet(pendingPassive, "current", undefined);
					let accept: unknown = luaProp(acceptStateRef, "current");
					if ((((pending !== undefined) && (accept !== undefined)) && luaProp(appAlive, "current"))) {
						luaCall(accept, pending);
					}
					return undefined;
				});
				luaSet(passiveFlushJob, "current", job);
				luaSetIndex(luaProp(deferredJobs, "current"), job, true);
			}
			return true;
		}
		luaSet(pendingPassive, "current", undefined);
		luaSet(latestRevision, "current", luaCall(luaProp(math, "max"), luaProp(latestRevision, "current"), luaProp(snapshot, "Revision")));
		luaSet(lastSnapshotPaintAt, "current", now);
		luaSet(lastAcceptedSnapshot, "current", snapshot);
		luaCall(dispatchStore, luaCall(luaProp(ClientActions, "setSnapshot"), snapshot));
		if ((!luaProp(loggedFirstSnapshot, "current"))) {
			luaSet(loggedFirstSnapshot, "current", true);
			colon(ClientLog).once("profile-ready", "profile", `loaded world ${luaProp(snapshot, "CurrentZone")}`);
		}
		return true;
		return undefined;
	}, [dispatchStore]);
	luaSet(acceptStateRef, "current", acceptState);
	let _result_5: unknown = state;
	if ((_result_5 !== undefined)) {
		_result_5 = luaProp(luaProp(_result_5, "Settings"), "NotificationDuration");
	}
	let _condition_2: unknown = _result_5;
	if ((_condition_2 === undefined)) {
		_condition_2 = 0.55;
	}
	let notificationDurationRef: unknown = reactLoose.useRef(_condition_2);
	let _result_6: unknown = state;
	if ((_result_6 !== undefined)) {
		_result_6 = luaProp(luaProp(_result_6, "Settings"), "NotificationDuration");
	}
	let _condition_3: unknown = _result_6;
	if ((_condition_3 === undefined)) {
		_condition_3 = 0.55;
	}
	luaSet(notificationDurationRef, "current", _condition_3);
	let addNotice: unknown = reactLoose.useCallback(function(title?: unknown, body?: unknown, tone?: unknown, playSound?: unknown): unknown | undefined {
		if ((tone === undefined)) {
			tone = "Info";
		}
		if ((playSound === undefined)) {
			playSound = true;
		}
		let _condition_4: unknown = luaCall(friendlyPlayerMessage, body);
		if ((_condition_4 === undefined)) {
			_condition_4 = body;
		}
		body = _condition_4;
		let normalizedTitle: unknown = luaCall(luaProp(NoticeMath, "NormalizeTitle"), title);
		let signature: unknown = luaCall(luaProp(NoticeMath, "Signature"), normalizedTitle, body, tone);
		let now: unknown = luaCall(luaProp(os, "clock"));
		if (luaCall(luaProp(NoticeMath, "ShouldDedupe"), luaProp(luaProp(lastNotice, "current"), "signature"), luaProp(luaProp(lastNotice, "current"), "at"), signature, now)) {
			return undefined;
		}
		luaSet(lastNotice, "current", { signature: signature, at: now });
		luaCall(luaProp(NoticeMath, "Record"), normalizedTitle, body, tone);
		if (playSound) {
			colon(Audio).play(((tone === "Special") ? "noticeSpecial" : ((tone === "Success") ? "noticeSuccess" : (((tone === "Warning") || (tone === "Error")) ? "noticeWarning" : "noticeInfo"))));
		}
		// every notice plays in the island (queued until it mounts); there is no other toast surface
		let lifetime: unknown = luaCall(luaProp(NoticeMath, "Lifetime"), luaProp(notificationDurationRef, "current"));
		let Juice: unknown = mod("JuiceFx");
		let color: unknown = ((tone === "Special") ? luaProp(Palette, "violet") : ((tone === "Success") ? luaProp(Palette, "mint") : ((tone === "Warning") ? luaProp(Palette, "mango") : ((tone === "Error") ? luaProp(Palette, "coral") : luaProp(Palette, "cyan")))));
		let icon: unknown = ((tone === "Special") ? "Gift.17" : ((tone === "Success") ? "Check.23" : ((tone === "Warning") ? "Timer.7" : ((tone === "Error") ? "Close.10" : "Wave.14"))));
		let bodyText: unknown = ((luaTypeIs(body, "string")) ? body : luaCall(tostring, (body || "")));
		luaCall(luaProp(Juice, "banner"), normalizedTitle, ((bodyText !== "") ? bodyText : undefined), color, icon, lifetime, tone);
		return undefined;
		return undefined;
	}, {});
	let celebrate: unknown = reactLoose.useCallback(function(): unknown | undefined {
		// the reward itself flies as droplets and sparks (JuiceFx) and is announced by the island;
		// this only warms the screen for a moment
		luaCall(luaProp(mod("JuiceFx"), "flash"), luaProp(Palette, "cream"), 0.14);
		return undefined;
	}, {});
	let clearConfetti: unknown = reactLoose.useCallback(function(expectedSeed?: unknown): unknown | undefined {
		luaCall(setConfettiNonce, function(current?: unknown): unknown | undefined {
			return (((expectedSeed === undefined) || (current === expectedSeed)) ? 0 : current);
			return undefined;
		});
		return undefined;
	}, {});
	let addPop: unknown = reactLoose.useCallback(function(text?: unknown, color?: unknown, critical?: unknown): unknown | undefined {
		let id: unknown = ((luaProp(popId, "current") as unknown as number) + (1 as unknown as number));
		luaSet(popId, "current", id);
		luaCall(setPops, function(current?: unknown): unknown | undefined {
			let updated: unknown = luaCall(luaProp(table, "clone"), current);
			luaSetIndex(updated, ((len(updated) as unknown as number) + (1 as unknown as number)), { id: id, text: text, color: color, critical: critical, offset: luaCall(luaProp(math, "random"), -90, 90) });
			let excess: unknown = ((len(updated) as unknown as number) - (12 as unknown as number));
			if (((excess as unknown as number) > (0 as unknown as number))) {
				luaTable.move(updated, ((excess as unknown as number) + (1 as unknown as number)), len(updated), 1);
				{
					const _forStart_1 = (len(updated) as unknown as number);
					const _forEnd_1 = (((((len(updated) as unknown as number) - (excess as unknown as number)) as unknown as number) + (1 as unknown as number)) as unknown as number);
					const _forStep_1 = (-1 as unknown as number);
					for (let index = _forStart_1; _forStep_1 >= 0 ? index <= _forEnd_1 : index >= _forEnd_1; index += _forStep_1) {
						luaSetIndex(updated, index, undefined);
					}
				}
			}
			return updated;
			return undefined;
		});
		let job: unknown;
		job = luaCall(luaProp(task, "delay"), POP_SECONDS, function(): unknown | undefined {
			let _current: unknown = luaProp(deferredJobs, "current");
			let _job: unknown = job;
			luaSetIndex(_current, _job, undefined);
			if (luaProp(appAlive, "current")) {
				luaCall(setPops, function(current?: unknown): unknown | undefined {
					let kept: unknown = luaCall(luaProp(table, "create"), len(current));
					let removed: unknown = false;
					for (const [_, pop] of pairs((current) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
						if ((luaProp(pop, "id") === id)) {
							removed = true;
						} else {
							luaSetIndex(kept, ((len(kept) as unknown as number) + (1 as unknown as number)), pop);
						}
					}
					return (removed ? kept : current);
					return undefined;
				});
			}
			return undefined;
		});
		let _current: unknown = luaProp(deferredJobs, "current");
		let _job: unknown = job;
		luaSetIndex(_current, _job, true);
		return undefined;
	}, {});
	let applyComboReadout: unknown = reactLoose.useCallback(function(combo?: unknown, comboMultiplier?: unknown, comboMax?: unknown, comboWindow?: unknown): unknown | undefined {
		if (((combo as unknown as number) <= (0 as unknown as number))) {
			return undefined;
		}
		luaCall(luaProp(mod("SessionStats"), "best"), "bestCombo", combo);
		luaCall(luaProp(mod("JuiceFx"), "activity"), "combo", { combo: combo, multiplier: comboMultiplier, max: comboMax, window: comboWindow });
		luaCall(setComboReadout, { combo: combo, comboMultiplier: comboMultiplier, comboMax: comboMax, comboWindow: comboWindow, updatedAt: luaCall(luaProp(os, "clock")) });
		return undefined;
	}, {});
	let _exp_1: unknown = function(response?: unknown, action?: unknown, callback?: unknown): unknown | undefined {
		let juiceBefore: unknown = luaProp(lastAcceptedSnapshot, "current");
		let _action: unknown = action;
		if ((luaIndex(GRANT_ACTIONS, _action) !== undefined)) {
			luaCall(adopt, response);
		}
		let rawError: unknown = luaProp(response, "error");
		response = luaCall(friendlyActionResponse, response);
		if (luaProp(response, "State")) {
			luaCall(acceptState, luaProp(response, "State"));
		}
		if (((action === "LeaveGuild") && luaProp(response, "ok"))) {
			luaCall(dispatchStore, luaCall(luaProp(ClientActions, "patchSession"), { Guild: undefined, GuildBonuses: { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 } }));
		} else if ((luaProp(response, "Guild") !== undefined)) {
			let guild: unknown = luaProp(response, "Guild");
			luaCall(dispatchStore, luaCall(luaProp(ClientActions, "patchSession"), { Guild: ((luaProp(guild, "Id") === "") ? undefined : guild) }));
		}
		let _result_7: unknown = callback;
		if ((_result_7 !== undefined)) {
			luaCall(_result_7, response);
		}
		if ((!luaProp(response, "ok"))) {
			let _condition_4: unknown = luaProp(response, "error");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Try again in a moment.";
			}
			let detail: unknown = _condition_4;
			let _condition_5: unknown = rawError;
			if ((_condition_5 === undefined)) {
				_condition_5 = detail;
			}
			let lowered: unknown = luaCall(luaProp(string, "lower"), _condition_5);
			let expectedBusy: unknown = (((((action === "Overcharge") && ((luaCall(luaProp(string, "find"), lowered, "cooling", 1, true)) !== undefined))) || ((luaCall(luaProp(string, "find"), lowered, "still working", 1, true)) !== undefined)) || ((luaCall(luaProp(string, "find"), lowered, "slow down", 1, true)) !== undefined));
			if ((((!expectedBusy) && (luaProp(response, "State") === undefined)) && luaCall(luaProp(NetworkPolicy, "IsOptimistic"), action))) {
				let accepted: unknown = luaProp(lastAcceptedSnapshot, "current");
				if (((accepted !== undefined) && luaProp(appAlive, "current"))) {
					luaCall(dispatchStore, luaCall(luaProp(ClientActions, "setSnapshot"), accepted));
				}
			}
			if (expectedBusy) {
				return undefined;
			}
			let _exp_2: unknown = action;
			let _condition_6: unknown = rawError;
			if ((_condition_6 === undefined)) {
				_condition_6 = detail;
			}
			colon(ClientLog).warn("action", `${_exp_2} failed — ${_condition_6}`);
			if (colon(AppHelpers).isPassiveRequest(action)) {
				return undefined;
			}
			let gated: unknown = ((luaCall(luaProp(string, "find"), luaCall(luaProp(string, "lower"), detail), "unlock", 1, true)) !== undefined);
			let _exp_3: unknown = luaCall(failureTitle, action, gated);
			let _exp_4: unknown = action;
			let _condition_7: unknown = rawError;
			if ((_condition_7 === undefined)) {
				_condition_7 = detail;
			}
			luaCall(addNotice, _exp_3, luaCall(failureBody, _exp_4, _condition_7), "Warning", false);
			return undefined;
		}
		{
			// game feel: what you gained flies into its counter, what you spent pops in red
			let Juice: unknown = mod("JuiceFx");
			let after: unknown = luaProp(response, "State");
			let bigMoment: unknown = ((((action === "Rebirth") || (action === "DomainExpansion")) || (action === "Ascend")) || (action === "UnlockZone"));
			let rewarding: unknown = (((((((luaCall(luaProp(string, "sub"), action, 1, 5) === "Claim") || (action === "RedeemCode")) || (action === "StabilizeAnomaly")) || (action === "SalvageItem")) || (action === "BulkSalvageItems")) || (action === "SpinWheel")) || bigMoment);
			let spending: unknown = (((luaCall(luaProp(string, "sub"), action, 1, 3) === "Buy") || (luaCall(luaProp(string, "sub"), action, 1, 7) === "Upgrade")) || (action === "DomainLattice"));
			if (((after !== undefined) && ((rewarding || spending)))) {
				let shown: unknown = luaCall(luaProp(Juice, "celebrateGains"), juiceBefore, after, { spend: spending, big: bigMoment, skipVault: true });
				let Stats: unknown = mod("SessionStats");
				if (rewarding) {
					luaCall(luaProp(Stats, "bump"), "claims");
				} else if (spending) {
					luaCall(luaProp(Stats, "bump"), "upgrades");
				}
				if ((rewarding && ((shown as unknown as number) > (0 as unknown as number)))) {
					luaCall(luaProp(Juice, "burst"), undefined, luaProp(Palette, "mango"), (bigMoment ? 1.6 : 1));
				} else if (spending) {
					luaCall(luaProp(Juice, "ring"), undefined, luaProp(Palette, "cyan"));
				}
			}
			if (bigMoment) {
				luaCall(luaProp(Juice, "flash"), luaProp(Palette, "cream"), 0.45);
				if ((action === "Rebirth")) {
					luaCall(luaProp(Juice, "moment"), `REBIRTH ${(luaProp(response, "Rebirths") || "")}!`, "Production multiplier up.", luaProp(Palette, "violet"), "Rebirth.8");
				} else if ((action === "DomainExpansion")) {
					luaCall(luaProp(Juice, "moment"), `DOMAIN ${(luaProp(response, "DomainRank") || "")}!`, "New tree points to spend.", luaProp(Palette, "pink"), "Domain.5");
				} else if ((action === "UnlockZone")) {
					luaCall(luaProp(Juice, "moment"), "NEW WORLD!", luaProp(response, "message"), luaProp(Palette, "cyan"), "World.11");
				}
			}
			if ((((action === "OpenItemCrate") && (luaTypeIs(luaProp(response, "Rolls"), "table"))) && ((len(luaProp(response, "Rolls")) as unknown as number) > (0 as unknown as number)))) {
				luaCall(luaProp(Juice, "burst"), undefined, luaProp(Palette, "violet"), 1.2);
			}
		}
		let machinePurchase: unknown = (action === "BuyMachine");
		let progressionPurchase: unknown = (((((((((action === "BuyResearch") || (action === "BuyGridUpgrade")) || (action === "BuyAnomalyProtocol")) || (action === "UpgradeContinuum")) || (action === "UpgradeArtifact")) || (action === "BuyArtifact")) || (action === "UpgradeCrew")) || (action === "BuyGuildUpgrade")) || (action === "UpgradeItem"));
		let purchase: unknown = (((machinePurchase || progressionPurchase) || (action === "BuySignalOffer")) || (action === "BuyItemOffer"));
		let reward: unknown = (((((((((((((action === "ClaimDaily") || (action === "ClaimTimedReward")) || (action === "ClaimQuest")) || (action === "ClaimAchievement")) || (action === "ClaimLabOrder")) || (action === "ClaimCommanderReward")) || (action === "ClaimWeeklyDirective")) || (action === "ClaimSeasonTier")) || (action === "ClaimExpedition")) || (action === "ClaimConvergenceReward")) || (action === "ClaimAnomalyDirective")) || (action === "ClaimAnomalyMilestone")) || (action === "ClaimForgePathStep"));
		if (purchase) {
			colon(Audio).play((machinePurchase ? "machineInstall" : (((action === "UpgradeArtifact") || (action === "BuyArtifact")) ? "artifactUpgrade" : (progressionPurchase ? "researchUnlock" : "purchase"))));
			if (((action === "BuySignalOffer") || (action === "BuyItemOffer"))) {
				let _condition_4: unknown = luaProp(response, "message");
				if ((_condition_4 === undefined)) {
					_condition_4 = "Purchase complete.";
				}
				luaCall(addNotice, "Bought", _condition_4, "Success");
			} else if (machinePurchase) {
				let _condition_4: unknown = luaProp(response, "message");
				if ((_condition_4 === undefined)) {
					_condition_4 = "Station tuned.";
				}
				luaCall(addNotice, "Upgraded", _condition_4, "Success", false);
			} else if (progressionPurchase) {
				let _condition_4: unknown = luaProp(response, "message");
				if ((_condition_4 === undefined)) {
					_condition_4 = "Level increased.";
				}
				luaCall(addNotice, "Upgraded", _condition_4, "Success", false);
			}
		} else if (reward) {
			let _condition_4: unknown = (action === "ClaimForgePathStep");
			if (_condition_4) {
				let _result_8: unknown = luaProp(response, "State");
				if ((_result_8 !== undefined)) {
					_result_8 = luaProp(_result_8, "ForgePath");
				}
				_condition_4 = (_result_8 !== undefined);
				if (_condition_4) {
					let _exp_2: unknown = luaProp(luaProp(luaProp(response, "State"), "ForgePath"), "ClaimedSteps");
					let _result_9: unknown = 0;
					let _callback: unknown = function(max?: unknown, step?: unknown): unknown | undefined {
						return luaCall(luaProp(math, "max"), max, step);
						return undefined;
					};
					{
						const _forStart_2 = (1 as unknown as number);
						const _forEnd_2 = (len(_exp_2) as unknown as number);
						const _forStep_2 = (1 as unknown as number);
						for (let _i = _forStart_2; _forStep_2 >= 0 ? _i <= _forEnd_2 : _i >= _forEnd_2; _i += _forStep_2) {
							_result_9 = luaCall(_callback, _result_9, luaIndex(_exp_2, _i), ((_i as unknown as number) - (1 as unknown as number)), _exp_2);
						}
					}
					_condition_4 = (((_result_9 as unknown as number) % (5 as unknown as number)) === 0);
				}
			}
			let forgePathMajorStep: unknown = _condition_4;
			if (forgePathMajorStep) {
				colon(Audio).playCelebration(["researchUnlock", "discovery", "reward"], 0.08);
			} else {
				colon(Audio).play(((action === "ClaimDaily") ? "dailyClaim" : ((action === "ClaimTimedReward") ? "timedClaim" : ((action === "ClaimAchievement") ? "achievementClaim" : (((action === "ClaimSeasonTier") || (action === "ClaimConvergenceReward")) ? "seasonClaim" : ((action === "ClaimExpedition") ? "expeditionReturn" : ((action === "ClaimForgePathStep") ? "researchUnlock" : "missionClaim")))))));
			}
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if ((action === "ContributeGuild")) {
			colon(Audio).play("guildDeposit");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Contribution deposited.";
			}
			luaCall(addNotice, "Guild bank", _condition_4, "Success");
		} else if ((action === "CreateGuild")) {
			colon(Audio).play("guildCreate");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Your hall is open.";
			}
			luaCall(addNotice, "Guild chartered", _condition_4, "Special");
		} else if ((action === "JoinGuild")) {
			colon(Audio).play("guildJoin");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "You're in.";
			}
			luaCall(addNotice, "Guild", _condition_4, "Success");
		} else if ((action === "LeaveGuild")) {
			colon(Audio).play("guildLeave");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Left the guild.";
			}
			luaCall(addNotice, "Guild", _condition_4, "Info");
		} else if ((action === "DisbandGuild")) {
			colon(Audio).play("guildLeave");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "The guild is gone.";
			}
			luaCall(addNotice, "Guild disbanded", _condition_4, "Info");
		} else if ((action === "KickGuildMember")) {
			colon(Audio).play("memberRemove");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "They're out of the guild.";
			}
			luaCall(addNotice, "Crew removed", _condition_4, "Info");
		} else if ((action === "SetGuildRole")) {
			colon(Audio).play("roleChange");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Role changed.";
			}
			luaCall(addNotice, "Role updated", _condition_4, "Success");
		} else if ((action === "SalvageItem")) {
			colon(Audio).play("salvage");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Dust recovered.";
			}
			luaCall(addNotice, "Salvaged", _condition_4, "Success");
		} else if ((action === "EchoAct")) {
			// the echoes screen plays its own moments; the reply only needs a sound
			colon(Audio).play((luaProp(response, "Choices") ? "echoCapture" : (luaProp(response, "Level") ? "echoTune" : (luaProp(response, "Resonance") ? "echoDismantle" : (luaProp(response, "Uid") ? "echoClaim" : "echoEquip")))));
		} else if ((action === "LaunchExpedition")) {
			colon(Audio).play("expeditionLaunch");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "They're out.";
			}
			luaCall(addNotice, "Expedition", _condition_4, "Success");
		} else if ((action === "EquipArtifact")) {
			colon(Audio).play("artifactEquip");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Loadout updated.";
			}
			luaCall(addNotice, "Equipped", _condition_4, "Info");
		} else if ((action === "EquipTitle")) {
			colon(Audio).play("badgeEarn");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Title updated.";
			}
			luaCall(addNotice, "Title equipped", _condition_4, "Success", false);
		} else if ((action === "ClaimStoryChapter")) {
			colon(Audio).play("unlock");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if (((action === "ClaimMail") || (action === "ClaimAllMail"))) {
			colon(Audio).play("mailClaim");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if ((action === "RedeemCode")) {
			colon(Audio).play("codeReward");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Reward claimed.";
			}
			luaCall(addNotice, "Code claimed", _condition_4, "Special");
		} else if ((action === "VerifyCreatorFollow")) {
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "";
			}
			let already: unknown = ((luaCall(luaProp(string, "find"), luaCall(luaProp(string, "lower"), _condition_4), "already", 1, true)) !== undefined);
			if ((!already)) {
				colon(Audio).play("codeReward");
				luaCall(luaProp(InteractionFeedback, "reward"));
				luaCall(celebrate);
			}
			let _condition_5: unknown = luaProp(response, "message");
			if ((_condition_5 === undefined)) {
				_condition_5 = "Thanks for following.";
			}
			luaCall(addNotice, "Follow reward", _condition_5, (already ? "Info" : "Special"));
		} else if ((action === "StudioGrantProduct")) {
			colon(Audio).play("purchase");
		} else if ((action === "AdminExecute")) {
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Done.";
			}
			if ((luaProp(response, "DryRun") === true)) {
				luaCall(addNotice, "Preview ready", _condition_4, "Info");
			} else {
				colon(Audio).play("confirm");
				luaCall(addNotice, "Change applied", _condition_4, "Success");
			}
		} else if ((action === "InviteTrade")) {
			colon(Audio).play("invite");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Invite sent.";
			}
			luaCall(addNotice, "Trade invite", _condition_4, "Info");
		} else if ((action === "RespondTrade")) {
			colon(Audio).play("confirm");
		} else if ((action === "ConfirmTrade")) {
			colon(Audio).play("purchase");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Trade finished.";
			}
			luaCall(addNotice, "Trade", _condition_4, "Success");
		} else if ((action === "CancelTrade")) {
			colon(Audio).play("close");
		} else if ((action === "SpinWheel")) {

		} else if ((action === "OpenItemCrate")) {
			let _result_8: unknown = luaProp(response, "Rolls");
			if ((_result_8 !== undefined)) {
				_result_8 = len(_result_8);
			}
			let _condition_4: unknown = _result_8;
			if ((_condition_4 === undefined)) {
				_condition_4 = 0;
			}
			if ((_condition_4 === 0)) {
				luaCall(celebrate);
			}
		} else if ((action === "RouteLabPower")) {
			colon(Audio).play("labRoute");
		} else if ((action === "SetAutoForge")) {
			colon(Audio).play("autoForge");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Auto-forge set.";
			}
			luaCall(addNotice, "Auto-Forge", _condition_4, "Info");
		} else if ((action === "SetAnomalyChannel")) {
			colon(Audio).play("toggleOn");
		} else if ((action === "ActivateAnomalySurge")) {
			colon(Audio).play("reactorSurge");
		} else if ((action === "DeleteMail")) {
			colon(Audio).play("close");
		} else if ((action === "DomainExpansion")) {
			colon(Audio).play("domainImpact");
			let rewardJob: unknown;
			rewardJob = luaCall(luaProp(task, "delay"), 0.2, function(): unknown | undefined {
				luaSetIndex(luaProp(deferredJobs, "current"), rewardJob, undefined);
				if (luaProp(appAlive, "current")) {
					colon(Audio).playCelebration(["domainReward", "discovery"], 0.1);
				}
				return undefined;
			});
			luaSetIndex(luaProp(deferredJobs, "current"), rewardJob, true);
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if ((action === "Rebirth")) {
			// the ceremony owns the rebirth cues and timing; the notice still lands for the log
			luaCall(luaProp(ui("RebirthCeremony"), "play"), { rebirths: luaProp(response, "Rebirths"), before: luaProp(response, "MultiplierBefore"), after: luaProp(response, "MultiplierAfter"), reward: luaProp(response, "Reward"), stardust: luaProp(response, "StardustReward"), grade: luaProp(response, "Grade"), vow: luaProp(response, "Vow"), vowKept: luaProp(response, "VowKept") });
			luaCall(celebrate);
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "The forge starts over, stronger.";
			}
			luaCall(addNotice, "Rebirth done", _condition_4, "Special");
		} else if ((action === "SetSetting")) {
			if (((luaProp(response, "message") !== undefined) && (luaProp(response, "message") !== "Setting updated."))) {
				luaCall(addNotice, "Preset on", luaProp(response, "message"), "Success");
			}
		} else if ((action === "SetMobileLayout")) {

		} else if ((action === "ActivateBoost")) {
			colon(Audio).play("boostActivate");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Timer started.";
			}
			luaCall(addNotice, "Boost on", _condition_4, "Success");
		} else if ((action === "UnlockZone")) {
			colon(Audio).play("zoneUnlock");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "A new world is open.";
			}
			luaCall(addNotice, "World unlocked", _condition_4, "Special", false);
		} else if ((action === "NudgeCrew")) {
			colon(Audio).play("crewNudge");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "They’ll see it.";
			}
			luaCall(addNotice, "Waved", _condition_4, "Info");
		} else if ((action === "VisitPlot")) {
			colon(Audio).play("travel");
			if (luaProp(response, "Visit")) {
				luaCall(setVisit, luaProp(response, "Visit"));
			}
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "You're in their shop.";
			}
			luaCall(addNotice, "Visiting", _condition_4, "Info");
		} else if ((action === "LeavePlot")) {
			colon(Audio).play("close");
			luaCall(setVisit, undefined);
		} else if ((action === "SelectZone")) {
			colon(Audio).play("zoneSelect");
		} else if ((action === "EquipItem")) {
			colon(Audio).play("itemLink");
		} else if ((action === "UnequipItem")) {
			colon(Audio).play("itemUnlink");
		} else if ((action === "EquipBestItems")) {
			colon(Audio).play("itemLink");
			luaCall(luaProp(InteractionFeedback, "tap"));
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Best relics equipped.";
			}
			luaCall(addNotice, "Loadout optimized", _condition_4, "Success", false);
		} else if ((action === "BulkSalvageItems")) {
			colon(Audio).play("salvage");
			luaCall(luaProp(InteractionFeedback, "tap"));
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Relics broken down.";
			}
			luaCall(addNotice, "Salvaged", _condition_4, "Success", false);
		} else if ((action === "ToggleItemLock")) {
			colon(Audio).play("toggleOn");
			let _condition_4: unknown = luaProp(response, "message");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Lock updated.";
			}
			luaCall(addNotice, "Relic", _condition_4, "Info", false);
		} else if ((action === "StabilizeAnomaly")) {
			colon(Audio).play("reactorStabilize");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if ((action === "CompleteTutorial")) {
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(celebrate);
		} else if ((action === "CollectVault")) {
			colon(Audio).play("vaultDeposit");
			luaCall(luaProp(InteractionFeedback, "reward"));
			luaCall(luaProp(InteractionFeedback, "confirm"));
			luaCall(celebrate);
		} else if ((action === "Overcharge")) {
			if (((luaProp(response, "Combo") !== undefined) && (luaProp(response, "ComboMultiplier") !== undefined))) {
				let _exp_2: unknown = luaProp(response, "Combo");
				let _exp_3: unknown = luaProp(response, "ComboMultiplier");
				let _condition_4: unknown = luaProp(response, "ComboMax");
				if ((_condition_4 === undefined)) {
					_condition_4 = 12;
				}
				let _condition_5: unknown = luaProp(response, "ComboWindow");
				if ((_condition_5 === undefined)) {
					_condition_5 = 1.8;
				}
				luaCall(applyComboReadout, _exp_2, _exp_3, _condition_4, _condition_5);
			}
		} else if ((action === "PulseAnomaly")) {
			colon(Audio).play("reactorPulse");
		} else if (((action === "ClaimAnomalyDirective") || (action === "ClaimAnomalyMilestone"))) {
			colon(Audio).play("collect");
			luaCall(luaProp(InteractionFeedback, "reward"));
		} else if ((((((((((((((((((((((((((((((((((((((((((((luaProp(response, "message") !== undefined) && (action !== "Overcharge")) && (action !== "ActivateBoost")) && (action !== "RouteLabPower")) && (action !== "SetTutorialStep")) && (action !== "ReplayTutorial")) && (action !== "DismissRelease")) && (action !== "OpenRelease")) && (action !== "ReadStoryChapter")) && (action !== "ReadMail")) && (action !== "SetSetting")) && (action !== "SetMobileLayout")) && (action !== "ChatOpenWhisper")) && (action !== "ChatGlobal")) && (action !== "VisitPlot")) && (action !== "LeavePlot")) && (action !== "SyncShop")) && (action !== "GetPlayers")) && (action !== "GetLeaderboard")) && (action !== "GetGuildLeaderboard")) && (action !== "GetGuild")) && (action !== "GetGuildChatHistory")) && (action !== "GetGuildAnnouncements")) && (action !== "GetGuildSettings")) && (action !== "GetGuildLogoReview")) && (action !== "SendGuildChat")) && (action !== "CreateGuildAnnouncement")) && (action !== "EditGuildAnnouncement")) && (action !== "PinGuildAnnouncement")) && (action !== "ArchiveGuildAnnouncement")) && (action !== "SetGuildAnnouncementExpiry")) && (action !== "SetGuildSettings")) && (action !== "MuteGuildMember")) && (action !== "UnmuteGuildMember")) && (action !== "BanGuildMember")) && (action !== "UnbanGuildMember")) && (action !== "UploadGuildLogo")) && (action !== "ModerateGuildLogo")) && (action !== "GetTrade")) && (action !== "UpdateTradeOffer")) && (action !== "SetTradeReady")) && (action !== "VerifyCreatorFollow")) && (action !== "RedeemCode"))) {
			luaCall(addNotice, "Done", luaProp(response, "message"), "Info");
		}
		return undefined;
	};
	let applyResponse: unknown = reactLoose.useCallback(_exp_1, [acceptState, addNotice, applyComboReadout, celebrate, dispatchStore, setVisit]);
	let dispatch: unknown;
	dispatch = reactLoose.useCallback(function(action?: unknown, payload?: unknown, callback?: unknown): unknown | undefined {
		if ((payload === undefined)) {
			payload = {};
		}
		let _payload: unknown = payload;
		let value: unknown = ((luaTypeIs(_payload, "table")) ? payload : {});
		let signature: unknown = colon(AppHelpers).actionSignature(action, value);
		let pipelined: unknown = luaCall(luaProp(NetworkPolicy, "IsPipelined"), action);
		let reject: unknown = function(message?: unknown, uncertain?: unknown): unknown | undefined {
			let _result_8: unknown = callback;
			if ((_result_8 !== undefined)) {
				luaCall(_result_8, { ok: false, error: message, Uncertain: (uncertain === true) });
			}
			return undefined;
		};
		if ((!luaProp(appAlive, "current"))) {
			return undefined;
		}
		let _action_1: unknown = action;
		if ((luaIndex(GRANT_ACTIONS, _action_1) !== undefined)) {
			if ((!luaCall(isAuthed))) {
				let settled: unknown = false;
				luaCall(whenAuthed, function(): unknown | undefined {
					if ((settled || (!luaProp(appAlive, "current")))) {
						return undefined;
					}
					settled = true;
					return luaCall(dispatch, action, payload, callback);
					return undefined;
				});
				let authJob: unknown;
				authJob = luaCall(luaProp(task, "delay"), 4, function(): unknown | undefined {
					luaSetIndex(luaProp(deferredJobs, "current"), authJob, undefined);
					if ((settled || (!luaProp(appAlive, "current")))) {
						return undefined;
					}
					settled = true;
					if (luaCall(isAuthed)) {
						luaCall(dispatch, action, payload, callback);
						return undefined;
					}
					luaCall(reject, "Your session is still connecting. Try again in a moment.");
					return undefined;
				});
				return undefined;
			}
			value = luaCall(luaProp(table, "clone"), value);
			luaCall(attachGrantFields, value);
		}
		if (((!pipelined) && (luaIndex(luaProp(busy, "current"), signature) !== undefined))) {
			luaCall(reject, "Already working on that.");
			return undefined;
		}
		let _condition_4: unknown = luaIndex(luaProp(inFlight, "current"), signature);
		if ((_condition_4 === undefined)) {
			_condition_4 = 0;
		}
		let activeRequests: unknown = _condition_4;
		let requestLimit: unknown = luaCall(luaProp(NetworkPolicy, "RequestLimit"), pipelined);
		if (((activeRequests as unknown as number) >= (requestLimit as unknown as number))) {
			luaCall(reject, "Still working on your last tap.");
			return undefined;
		}
		if (((luaProp(inFlightTotal, "current") as unknown as number) >= (luaProp(NetworkPolicy, "MAX_PHYSICAL_REQUESTS") as unknown as number))) {
			luaCall(reject, "The connection is busy. Try again in a moment.");
			return undefined;
		}
		let now: unknown = luaCall(luaProp(os, "clock"));
		let cooldown: unknown = luaCall(luaProp(NetworkPolicy, "Cooldown"), action);
		let previous: unknown = luaIndex(luaProp(sentAt, "current"), signature);
		if (((previous !== undefined) && luaCall(luaProp(NetworkPolicy, "IsCoolingDown"), now, previous, cooldown))) {
			luaCall(reject, "Slow down a sec.");
			return undefined;
		}
		if ((previous === undefined)) {
			luaSet(sentAtCount, "current", ((luaProp(sentAtCount, "current") as unknown as number) + (1 as unknown as number)));
		}
		luaSetIndex(luaProp(sentAt, "current"), signature, now);
		if (((luaProp(sentAtCount, "current") as unknown as number) > (256 as unknown as number))) {
			let remaining: unknown = 0;
			for (const [key, timestamp] of pairs((luaProp(sentAt, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((((now as unknown as number) - (timestamp as unknown as number)) as unknown as number) > (60 as unknown as number))) {
					luaSetIndex(luaProp(sentAt, "current"), key, undefined);
				} else {
					remaining = ((remaining as unknown as number) + (1 as unknown as number));
				}
			}
			if (((remaining as unknown as number) > (384 as unknown as number))) {
				// Evict oldest timestamps first so unrelated action signatures do not
				// lose their cooldowns arbitrarily.
				let entries: unknown = {};
				for (const [key, timestamp] of pairs((luaProp(sentAt, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					luaTable.insert(entries, { key: key, timestamp: timestamp });
				}
				luaCall(luaProp(table, "sort"), entries, function(a?: unknown, b?: unknown): unknown | undefined {
					return ((luaProp(a, "timestamp") as unknown as number) < (luaProp(b, "timestamp") as unknown as number));
					return undefined;
				});
				let target: unknown = ((remaining as unknown as number) - (256 as unknown as number));
				{
					const _forStart_3 = (1 as unknown as number);
					const _forEnd_3 = (target as unknown as number);
					const _forStep_3 = (1 as unknown as number);
					for (let i = _forStart_3; _forStep_3 >= 0 ? i <= _forEnd_3 : i >= _forEnd_3; i += _forStep_3) {
						luaSetIndex(luaProp(sentAt, "current"), luaProp(luaIndex(entries, i), "key"), undefined);
					}
				}
				remaining = ((remaining as unknown as number) - (target as unknown as number));
			}
			luaSet(sentAtCount, "current", remaining);
		}
		if (((action === "CollectVault") || (action === "Overcharge"))) {
			// instant game feel on the press itself, from the state the player is looking at
			let store: unknown = luaCall(luaProp(kit("CoreKit", "clientStore"), "getActiveClientStore"));
			let session: unknown = (store && luaProp(colon(store).getState(), "session"));
			let Juice: unknown = mod("JuiceFx");
			let Stats: unknown = mod("SessionStats");
			if ((((action === "CollectVault") && (session !== undefined)) && ((luaCall(luaProp(_format, "asFlux"), luaProp(session, "Vault")) as unknown as number) > (0 as unknown as number)))) {
				luaCall(luaProp(Stats, "bump"), "collects");
				luaCall(luaProp(Stats, "addFlux"), luaProp(session, "Vault"));
			} else if ((action === "Overcharge")) {
				luaCall(luaProp(Stats, "bump"), "overcharges");
			}
			if ((((session !== undefined) && (action === "CollectVault")) && ((luaCall(luaProp(_format, "asFlux"), luaProp(session, "Vault")) as unknown as number) > (0 as unknown as number)))) {
				luaCall(luaProp(Juice, "number"), `+${luaCall(compactNumber, luaProp(session, "Vault"))} flux`, luaProp(Palette, "cyan"), { icon: "Flux.19", big: true });
				luaCall(luaProp(Juice, "coins"), "FLUX", luaProp(Palette, "cyan"), "Flux", 10);
				luaCall(luaProp(Juice, "burst"), undefined, luaProp(Palette, "cyan"), 1);
			} else if ((((session !== undefined) && (action === "Overcharge")) && (luaProp(session, "TapPower") !== undefined))) {
				luaCall(luaProp(Juice, "number"), `+${luaCall(compactNumber, luaProp(session, "TapPower"))}`, luaProp(Palette, "mango"), { icon: "Flux.20" });
				luaCall(luaProp(Juice, "coins"), "VAULT", luaProp(Palette, "mango"), "Flux", 3);
			}
		} else if ((luaCall(luaProp(string, "sub"), action, 1, 5) === "Claim")) {
			// a claim answers on the press; the amounts fly in when the server confirms
			luaCall(luaProp(mod("JuiceFx"), "burst"), undefined, luaProp(Palette, "mango"), 0.7);
		}
		if (luaCall(luaProp(NetworkPolicy, "IsOptimistic"), action)) {
			luaCall(dispatchStore, luaCall(luaProp(ClientActions, "applyOptimistic"), action, value, luaProp(luaProp(config, "Game"), "Version")));
		}
		if (((action === "Overcharge") || (action === "PulseAnomaly"))) {
			colon(Audio).play("reactorPulse");
		} else if ((action === "CollectVault")) {
			colon(Audio).play("vaultBank");
		}
		let requestToken: unknown = ((luaProp(requestSequence, "current") as unknown as number) + (1 as unknown as number));
		luaSet(requestSequence, "current", requestToken);
		let _current: unknown = luaProp(inFlight, "current");
		let _arg1: unknown = ((activeRequests as unknown as number) + (1 as unknown as number));
		luaSetIndex(_current, signature, _arg1);
		luaSet(inFlightTotal, "current", ((luaProp(inFlightTotal, "current") as unknown as number) + (1 as unknown as number)));
		if ((!pipelined)) {
			luaSetIndex(luaProp(busy, "current"), signature, requestToken);
		}
		let requestTimedOut: unknown = false;
		let requestReleased: unknown = false;
		let releaseRequest: unknown = function(): unknown | undefined {
			if (requestReleased) {
				return undefined;
			}
			requestReleased = true;
			let _condition_6: unknown = luaIndex(luaProp(inFlight, "current"), signature);
			if ((_condition_6 === undefined)) {
				_condition_6 = 1;
			}
			let remaining: unknown = ((_condition_6 as unknown as number) - (1 as unknown as number));
			if (((remaining as unknown as number) > (0 as unknown as number))) {
				luaSetIndex(luaProp(inFlight, "current"), signature, remaining);
			} else {
				luaSetIndex(luaProp(inFlight, "current"), signature, undefined);
			}
			luaSet(inFlightTotal, "current", luaCall(luaProp(math, "max"), 0, ((luaProp(inFlightTotal, "current") as unknown as number) - (1 as unknown as number))));
			return undefined;
		};
		let requestTimeout: unknown;
		let requestWorker: unknown;
		let timeoutSeconds: unknown = luaCall(luaProp(NetworkPolicy, "Timeout"), action);
		requestTimeout = luaCall(luaProp(task, "delay"), timeoutSeconds, function(): unknown | undefined {
			if ((requestTimeout !== undefined)) {
				let _current_1: unknown = luaProp(requestTimeouts, "current");
				let _requestTimeout: unknown = requestTimeout;
				luaSetIndex(_current_1, _requestTimeout, undefined);
			}
			requestTimeout = undefined;
			let ownsControl: unknown = (pipelined || (luaIndex(luaProp(busy, "current"), signature) === requestToken));
			if (((!pipelined) && ownsControl)) {
				luaSetIndex(luaProp(busy, "current"), signature, undefined);
			}
			requestTimedOut = true;
			luaCall(releaseRequest);
			if (((!luaProp(appAlive, "current")) || (!ownsControl))) {
				return undefined;
			}
			if (luaCall(luaProp(NetworkPolicy, "IsOptimistic"), action)) {
				let accepted: unknown = luaProp(lastAcceptedSnapshot, "current");
				if ((accepted !== undefined)) {
					luaCall(dispatchStore, luaCall(luaProp(ClientActions, "setSnapshot"), accepted));
				}
			}
			colon(ClientLog).warnEvery(`timeout:${action}`, 8, "UI", `${action} timed out after ${timeoutSeconds}s`);
			luaCall(addNotice, "Connection hiccup", "That action timed out. You can try it again now.", "Info", false);
			luaCall(reject, "That took too long. Try again.", true);
			return undefined;
		});
		let _current_1: unknown = luaProp(requestTimeouts, "current");
		let _requestTimeout: unknown = requestTimeout;
		luaSetIndex(_current_1, _requestTimeout, true);
		requestWorker = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
			let ok: unknown;
			let raw: unknown;
			[ok, raw] = luaCall(pcall, function(): unknown | undefined {
				return colon(luaProp(remotes, "Request")).InvokeServer(action, value);
				return undefined;
			}) as LuaTuple<[unknown, unknown]>;
			if ((requestWorker !== undefined)) {
				let _current_2: unknown = luaProp(requestWorkers, "current");
				let _requestWorker: unknown = requestWorker;
				luaSetIndex(_current_2, _requestWorker, undefined);
			}
			requestWorker = undefined;
			if ((requestTimeout !== undefined)) {
				luaCall(luaProp(task, "cancel"), requestTimeout);
				let _current_2: unknown = luaProp(requestTimeouts, "current");
				let _requestTimeout_1: unknown = requestTimeout;
				luaSetIndex(_current_2, _requestTimeout_1, undefined);
				requestTimeout = undefined;
			}
			if (((!pipelined) && (luaIndex(luaProp(busy, "current"), signature) === requestToken))) {
				luaSetIndex(luaProp(busy, "current"), signature, undefined);
			}
			luaCall(releaseRequest);
			if ((!luaProp(appAlive, "current"))) {
				return undefined;
			}
			if (requestTimedOut) {
				if ((ok && (luaTypeIs(raw, "table")))) {
					if ((luaIndex(GRANT_ACTIONS, action) !== undefined)) {
						luaCall(adopt, raw);
					}
					if (luaProp(raw, "State")) {
						luaCall(acceptState, luaProp(raw, "State"));
					}
				}
				return undefined;
			}
			let _condition_7: unknown = ((!ok) || (!((luaTypeIs(raw, "table")))));
			if ((!_condition_7)) {
				let _ok: unknown = luaProp(raw, "ok");
				_condition_7 = (!((luaTypeIs(_ok, "boolean"))));
			}
			if (_condition_7) {
				colon(ClientLog).warnEvery(`request:${action}`, 5, "UI", `${action} got no answer`);
				luaCall(addNotice, "Connection hiccup", "That tap didn't go through. Try again.", "Info", false);
				luaCall(reject, "That tap didn't go through. Try again.", true);
				return undefined;
			}
			luaCall(applyResponse, raw, action, callback);
			return undefined;
		});
		let _current_2: unknown = luaProp(requestWorkers, "current");
		let _requestWorker: unknown = requestWorker;
		luaSetIndex(_current_2, _requestWorker, true);
		return undefined;
	}, [acceptState, addNotice, applyResponse, luaProp(luaProp(config, "Game"), "Version"), dispatchStore, remotes]);
	luaCall(useClientIntegrityProbe, dispatch);
	let _exp_2: unknown = function(): unknown | undefined {
		if ((state === undefined)) {
			return undefined;
		}
		if ((luaProp(luaProp(state, "Daily"), "CanClaim") !== true)) {
			luaSet(streakToastSent, "current", false);
			return undefined;
		}
		if (luaProp(streakToastSent, "current")) {
			return undefined;
		}
		if (((luaProp(luaProp(state, "Daily"), "CanClaim") === true) && ((luaProp(luaProp(state, "Daily"), "Streak") as unknown as number) >= (1 as unknown as number)))) {
			luaSet(streakToastSent, "current", true);
			let day: unknown = luaProp(luaProp(state, "Daily"), "Streak");
			luaCall(addNotice, "Daily streak", (((day as unknown as number) > (1 as unknown as number)) ? `Day ${day} is ready to claim in Rewards.` : "Today’s daily is ready in Rewards."), "Special");
		}
		return undefined;
	};
	let _result_8: unknown = state;
	if ((_result_8 !== undefined)) {
		_result_8 = luaProp(luaProp(_result_8, "Daily"), "CanClaim");
	}
	let _result_9: unknown = state;
	if ((_result_9 !== undefined)) {
		_result_9 = luaProp(luaProp(_result_9, "Daily"), "Streak");
	}
	reactLoose.useEffect(_exp_2, [addNotice, _result_8, _result_9]);
	let _exp_3: unknown = function(): unknown | undefined {
		let _snapshotCombo: unknown = state;
		if ((_snapshotCombo !== undefined)) {
			_snapshotCombo = luaProp(_snapshotCombo, "Overcharge");
		}
		let snapshotCombo: unknown = _snapshotCombo;
		if ((((snapshotCombo === undefined) || ((luaProp(snapshotCombo, "Combo") as unknown as number) <= (0 as unknown as number))) || (comboReadout !== undefined))) {
			return undefined;
		}
		luaCall(setComboReadout, { combo: luaProp(snapshotCombo, "Combo"), comboMultiplier: luaProp(snapshotCombo, "ComboMultiplier"), comboMax: luaProp(snapshotCombo, "ComboMax"), comboWindow: luaProp(snapshotCombo, "ComboWindow"), updatedAt: luaCall(luaProp(os, "clock")) });
		return undefined;
	};
	let _result_10: unknown = state;
	if ((_result_10 !== undefined)) {
		_result_10 = luaProp(_result_10, "Overcharge");
	}
	reactLoose.useEffect(_exp_3, [comboReadout, _result_10]);
	reactLoose.useEffect(function(): unknown | undefined {
		let alive: unknown = true;
		let fontWorker: unknown;
		let fontTimeout: unknown;
		let moduleWorker: unknown;
		let stateWorker: unknown;
		let cancelWorker: unknown = function(worker?: unknown): unknown | undefined {
			if ((worker !== undefined)) {
				luaCall(pcall, function(): unknown | undefined {
					return luaCall(luaProp(task, "cancel"), worker);
					return undefined;
				});
			}
			return undefined;
		};
		let stateConnection: unknown = colon(luaProp(luaProp(remotes, "State"), "OnClientEvent")).Connect(function(snapshot?: unknown): unknown | undefined {
			let _condition_4: unknown = (!alive);
			if ((!_condition_4)) {
				let _snapshot: unknown = snapshot;
				_condition_4 = (!((luaTypeIs(_snapshot, "table"))));
			}
			if (_condition_4) {
				return undefined;
			}
			if ((!luaCall(acceptState, snapshot))) {
				return undefined;
			}
			luaCall(markBoot, "bridge");
			luaCall(markBoot, "state");
			return undefined;
		});
		let toastConnection: unknown = colon(luaProp(luaProp(remotes, "Toast"), "OnClientEvent")).Connect(function(payload?: unknown): unknown | undefined {
			let _condition_4: unknown = (!alive);
			if ((!_condition_4)) {
				let _payload: unknown = payload;
				_condition_4 = (!((luaTypeIs(_payload, "table"))));
			}
			if (_condition_4) {
				return undefined;
			}
			let value: unknown = payload;
			let tone: unknown = ((luaProp(value, "Tone")) || "Info");
			let _condition_5: unknown = luaProp(value, "Title");
			if ((_condition_5 === undefined)) {
				_condition_5 = "Update";
			}
			let _exp_4: unknown = luaCall(tostring, _condition_5);
			let _condition_6: unknown = luaProp(value, "Body");
			if ((_condition_6 === undefined)) {
				_condition_6 = "Something changed.";
			}
			luaCall(addNotice, _exp_4, luaCall(tostring, _condition_6), tone);
			return undefined;
		});
		let effectConnection: unknown = colon(luaProp(luaProp(remotes, "Effect"), "OnClientEvent")).Connect(function(payload?: unknown): unknown | undefined {
			let _condition_4: unknown = (!alive);
			if ((!_condition_4)) {
				let _payload: unknown = payload;
				_condition_4 = (!((luaTypeIs(_payload, "table"))));
			}
			if (_condition_4) {
				return undefined;
			}
			let value: unknown = payload;
			let _condition_5: unknown = luaProp(value, "Type");
			if ((_condition_5 === undefined)) {
				_condition_5 = "";
			}
			let kind: unknown = luaCall(tostring, _condition_5);
			let _amount: unknown = luaProp(value, "Amount");
			let amount: unknown = ((luaTypeIs(_amount, "number")) ? luaProp(value, "Amount") : 0);
			if (((kind === "Collect") && ((amount as unknown as number) > (0 as unknown as number)))) {

			} else if (((kind === "Overcharge") && ((amount as unknown as number) > (0 as unknown as number)))) {
				if ((luaProp(value, "Critical") === true)) {
					let Juice: unknown = mod("JuiceFx");
					luaCall(luaProp(Juice, "number"), "CRIT!", luaProp(Palette, "mango"), { big: true });
					luaCall(luaProp(mod("SessionStats"), "bump"), "crits");
					luaCall(luaProp(Juice, "burst"), undefined, luaProp(Palette, "mango"), 0.8);
				}
				let _combo: unknown = luaProp(value, "Combo");
				let combo: unknown = ((luaTypeIs(_combo, "number")) ? luaProp(value, "Combo") : undefined);
				let _comboMultiplier: unknown = luaProp(value, "ComboMultiplier");
				let comboMultiplier: unknown = ((luaTypeIs(_comboMultiplier, "number")) ? luaProp(value, "ComboMultiplier") : undefined);
				if (((combo !== undefined) && (comboMultiplier !== undefined))) {
					let _comboMax: unknown = luaProp(value, "ComboMax");
					let comboMax: unknown = ((luaTypeIs(_comboMax, "number")) ? luaProp(value, "ComboMax") : 12);
					let _comboWindow: unknown = luaProp(value, "ComboWindow");
					luaCall(applyComboReadout, combo, comboMultiplier, comboMax, ((luaTypeIs(_comboWindow, "number")) ? luaProp(value, "ComboWindow") : 1.8));
					if (((combo as unknown as number) <= (1 as unknown as number))) {
						luaSet(lastComboTier, "current", 0);
					}
					let tier: unknown = luaCall(luaProp(math, "floor"), (((((combo as unknown as number) / (luaCall(luaProp(math, "max"), 1, comboMax) as unknown as number))) as unknown as number) * (4 as unknown as number)));
					if ((((tier as unknown as number) > (luaProp(lastComboTier, "current") as unknown as number)) && ((combo as unknown as number) < (comboMax as unknown as number)))) {
						colon(Audio).play("tick");
					} else if ((((combo as unknown as number) >= (comboMax as unknown as number)) && ((luaProp(lastComboTier, "current") as unknown as number) < (4 as unknown as number)))) {
						colon(Audio).play("unlock");
					}
					luaSet(lastComboTier, "current", (((combo as unknown as number) >= (comboMax as unknown as number)) ? 4 : tier));
				}
			} else if ((kind === "Ascension")) {
				colon(Audio).play("discovery");
				luaCall(celebrate);
				if ((luaProp(value, "UserId") === luaProp(luaProp(colon(game).GetService("Players"), "LocalPlayer"), "UserId"))) {
					luaCall(luaProp(mod("JuiceFx"), "moment"), `ASCENSION ${(luaProp(value, "Rank") || "")}!`, "Aether earned. Spend it on sigils.", luaProp(Palette, "mango"), "Rebirth.9");
				}
			} else if (((kind === "FeatureUnlocked") && (!luaProp(purchasePresentationActive, "current")))) {
				colon(Audio).play("unlock");
				luaCall(luaProp(InteractionFeedback, "reward"));
				luaCall(celebrate);
				let featureName: unknown = ((luaProp(value, "Name") || luaProp(value, "Feature")) || luaProp(value, "Id"));
				luaCall(luaProp(mod("JuiceFx"), "moment"), (featureName ? `${luaCall(luaProp(string, "upper"), luaCall(tostring, featureName))} UNLOCKED!` : "NEW FEATURE!"), "Find it in the menu.", luaProp(Palette, "mint"), "Check.24");
			} else if (((kind === "LevelUp") && (!luaProp(purchasePresentationActive, "current")))) {
				luaCall(luaProp(ui("levelMoments"), "pushLevelMoment"), value);
				luaCall(luaProp(InteractionFeedback, "reward"));
				luaCall(celebrate);
			} else if ((kind === "ServerEvent")) {
				luaCall(luaProp(ui("serverEventsUi"), "pushServerEvent"), value);
			} else if ((kind === "LevelReward")) {
				luaCall(luaProp(ui("levelMoments"), "pushLevelMoment"), value);
			} else if ((kind === "AnomalyPulse")) {
				colon(Audio).play("reactor");
			} else if ((kind === "AnomalyReady")) {
				colon(Audio).play("reactorReady");
			} else if ((kind === "AnomalyStabilized")) {
				colon(Audio).play("discovery");
			} else if ((kind === "ItemLinked")) {
				colon(Audio).play("equip");
			} else if ((((((kind === "GuildChat") || (kind === "GuildAnnouncement")) || (kind === "GuildSettings")) || (kind === "GuildLogo")) || (kind === "GuildModeration"))) {
				if ((kind === "GuildAnnouncement")) {
					colon(Audio).play("guildAnnounce");
				} else if ((kind !== "GuildChat")) {
					colon(Audio).play("collect");
				}
			} else if ((kind === "GuildBanned")) {
				luaCall(addNotice, "Guild ban", "You have been removed from this guild.", "Warning");
			} else {
				let _condition_6: unknown = (kind === "VisitUpdate");
				if (_condition_6) {
					let _visit: unknown = luaProp(value, "Visit");
					_condition_6 = (luaTypeIs(_visit, "table"));
				}
				if (_condition_6) {
					luaCall(setVisit, luaProp(value, "Visit"));
				} else if ((kind === "VisitEnded")) {
					luaCall(setVisit, undefined);
				} else if ((kind === "CrewState")) {
					let CrewStore: unknown = mod("CrewStore");
					let wasInCrew: unknown = (luaProp(luaCall(luaProp(CrewStore, "get")), "crew") !== undefined);
					luaCall(luaProp(CrewStore, "set"), { crew: ((luaTypeIs(luaProp(value, "Crew"), "table")) ? luaProp(value, "Crew") : luaProp(CrewStore, "NONE")) });
					if ((((luaProp(value, "Crew") === undefined) && wasInCrew) && (luaTypeIs(luaProp(value, "Reason"), "string")))) {
						luaCall(addNotice, "Crew", luaProp(value, "Reason"), "Info");
					}
				} else if ((kind === "CrewInvite")) {
					let CrewStore: unknown = mod("CrewStore");
					luaCall(luaProp(CrewStore, "set"), { invite: { FromUserId: luaProp(value, "FromUserId"), FromName: luaProp(value, "FromName"), CrewName: luaProp(value, "CrewName"), ExpiresAt: luaProp(value, "ExpiresAt") } });
					colon(Audio).play("invite");
					luaCall(addNotice, "Crew invite", `${luaCall(tostring, (luaProp(value, "FromName") || "Someone"))} invited you to ${luaCall(tostring, (luaProp(value, "CrewName") || "a crew"))}. Open Crew to answer.`, "Special");
				} else if ((kind === "CrewNotice")) {
					luaCall(addNotice, "Crew", luaCall(tostring, (luaProp(value, "Text") || "")), "Info");
				} else if ((kind === "CrewNudge")) {
					colon(Audio).play("crewNudge");
					luaCall(luaProp(InteractionFeedback, "tap"));
					let _condition_7: unknown = luaProp(value, "FromName");
					if ((_condition_7 === undefined)) {
						_condition_7 = "Someone";
					}
					let from_: unknown = luaCall(tostring, _condition_7);
					luaCall(addNotice, "Crew nudge", `${from_} waved at you.`, "Special");
				} else if (((kind === "DomainExpansion") && (luaCall(tonumber, luaProp(value, "UserId")) !== luaProp(luaProp(Players, "LocalPlayer"), "UserId")))) {
					colon(Audio).play("domainImpact");
					let _condition_7: unknown = luaCall(tonumber, luaProp(value, "Rank"));
					if ((_condition_7 === undefined)) {
						_condition_7 = 1;
					}
					luaCall(addNotice, "Domain nearby", `Someone opened Domain ${luaCall(luaProp(math, "floor"), _condition_7)}.`, "Special");
				} else if ((kind === "AdminPrank")) {
					let _condition_7: unknown = luaProp(value, "Kind");
					if ((_condition_7 === undefined)) {
						_condition_7 = "Jumpscare";
					}
					let prankKind: unknown = luaCall(tostring, _condition_7);
					let _condition_8: unknown = luaCall(tonumber, luaProp(value, "Duration"));
					if ((_condition_8 === undefined)) {
						_condition_8 = 6;
					}
					let duration: unknown = luaCall(luaProp(math, "clamp"), _condition_8, 2, 20);
					let _condition_9: unknown = luaProp(value, "Caption");
					if ((_condition_9 === undefined)) {
						_condition_9 = "";
					}
					let caption: unknown = luaCall(tostring, _condition_9);
					luaCall(setAdminPrank, { kind: prankKind, endsAt: ((luaCall(luaProp(os, "clock")) as unknown as number) + (duration as unknown as number)), caption: caption, duration: duration });
					colon(Audio).play("adminExecute");
				}
			}
			return undefined;
		});
		luaCall(markBoot, "remotes");
		colon(Audio).start();
		colon(Audio).whenWarm(function(): unknown | undefined {
			if (alive) {
				luaCall(markBoot, "audio");
			}
			return undefined;
		});
		let fontFaces: unknown = [luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSans")), luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "RobotoMono")), luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "Code")), new (Font as unknown as new (...args: unknown[]) => unknown)("rbxasset://fonts/families/GothamSSm.json")];
		let fontFinished: unknown = false;
		fontWorker = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
			luaCall(pcall, function(): unknown | undefined {
				return colon(ContentProvider).PreloadAsync(fontFaces);
				return undefined;
			});
			if (fontFinished) {
				return undefined;
			}
			fontFinished = true;
			if (alive) {
				luaCall(markBoot, "fonts");
			}
			return undefined;
		});
		fontTimeout = luaCall(luaProp(task, "delay"), 6, function(): unknown | undefined {
			if (fontFinished) {
				return undefined;
			}
			fontFinished = true;
			luaCall(cancelWorker, fontWorker);
			fontWorker = undefined;
			luaCall(destroyFontSamples);
			if (alive) {
				luaCall(markBoot, "fonts");
			}
			return undefined;
		});
		moduleWorker = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
			let deadline: unknown = ((luaCall(luaProp(os, "clock")) as unknown as number) + (luaProp(Boot, "BOOT_MODULE_TIMEOUT") as unknown as number));
			let waitChild: unknown = function(parent?: unknown, name?: unknown, budget?: unknown): unknown | undefined {
				let left: unknown = luaCall(luaProp(math, "max"), 0.05, ((deadline as unknown as number) - (luaCall(luaProp(os, "clock")) as unknown as number)));
				return colon(parent).WaitForChild(name, luaCall(luaProp(math, "min"), budget, left));
				return undefined;
			};
			luaCall(pcall, function(): unknown | undefined {
				let astral: unknown = luaCall(waitChild, ReplicatedStorage, "AstralForge", 4);
				if ((astral !== undefined)) {
					luaCall(waitChild, astral, "Shared", 3);
					let shared: unknown = colon(astral).FindFirstChild("Shared");
					if ((shared !== undefined)) {
						let spinner: unknown = luaCall(waitChild, shared, "NumberSpinner", 3);
						if (((spinner !== undefined) && colon(spinner).IsA("ModuleScript"))) {
							luaCall(pcall, function(): unknown | undefined {
								return luaRequire(spinner);
								return undefined;
							});
						}
					}
					let vendor: unknown = (colon(astral).FindFirstChild("Vendor") || luaCall(waitChild, astral, "Vendor", 2));
					if ((vendor !== undefined)) {
						let vendorSpinner: unknown = colon(vendor).FindFirstChild("NumberSpinner");
						if (((vendorSpinner !== undefined) && colon(vendorSpinner).IsA("ModuleScript"))) {
							luaCall(pcall, function(): unknown | undefined {
								return luaRequire(vendorSpinner);
								return undefined;
							});
						}
					}
				}
				let playerScripts: unknown = (colon(luaProp(Players, "LocalPlayer")).FindFirstChild("PlayerScripts") || colon(luaProp(Players, "LocalPlayer")).WaitForChild("PlayerScripts", luaCall(luaProp(math, "max"), 0.1, ((deadline as unknown as number) - (luaCall(luaProp(os, "clock")) as unknown as number)))));
				if ((playerScripts !== undefined)) {
					luaCall(waitChild, playerScripts, "AstralForge", 3);
				}
				luaCall(pcall, function(): unknown | undefined {
					let starterScripts: unknown = colon(StarterPlayer).FindFirstChild("StarterPlayerScripts");
					if ((starterScripts !== undefined)) {
						colon(starterScripts).FindFirstChild("AstralForge");
					}
					return undefined;
				});
				luaCall(warmClientModules, function(loaded?: unknown, total?: unknown): unknown | undefined {
					if (alive) {
						luaCall(setModuleProgress, { loaded: loaded, total: total });
					}
					return undefined;
				});
				return undefined;
			});
			if (alive) {
				luaCall(markBoot, "modules");
			}
			return undefined;
		});
		stateWorker = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
			let attempt: unknown = 0;
			let lastConnectNotice: unknown = 0;
			while ((alive && ((luaProp(latestSnapshot, "current") as unknown as number) < (0 as unknown as number)))) {
				let bridgeReady: unknown = ((luaProp(remotes, "Bridge") !== undefined) && (colon(luaProp(remotes, "Bridge")).GetAttribute("Ready") === true));
				if (bridgeReady) {
					luaCall(markBoot, "bridge");
				}
				if (bridgeReady) {
					let ok: unknown;
					let raw: unknown;
					[ok, raw] = luaCall(pcall, function(): unknown | undefined {
						return colon(luaProp(remotes, "Request")).InvokeServer("GetState", {});
						return undefined;
					}) as LuaTuple<[unknown, unknown]>;
					if (((alive && ok) && (luaTypeIs(raw, "table")))) {
						let response: unknown = raw;
						if ((luaProp(response, "State") && luaCall(acceptState, luaProp(response, "State")))) {
							luaCall(markBoot, "state");
							break;
						}
					}
				}
				attempt = ((attempt as unknown as number) + (1 as unknown as number));
				if (((alive && ((attempt as unknown as number) >= (20 as unknown as number))) && ((((luaCall(luaProp(os, "clock")) as unknown as number) - (lastConnectNotice as unknown as number)) as unknown as number) > (30 as unknown as number)))) {
					lastConnectNotice = luaCall(luaProp(os, "clock"));
					luaCall(addNotice, "Still connecting", "Your save is taking longer than usual to load. If Astral Forge is open on another device, close it there.", "Info", false);
				}
				luaCall(luaProp(task, "wait"), luaCall(luaProp(math, "min"), ((0.2 as unknown as number) + (((attempt as unknown as number) * (0.08 as unknown as number)) as unknown as number)), 1.5));
			}
			if (((alive && (luaProp(remotes, "Bridge") !== undefined)) && (colon(luaProp(remotes, "Bridge")).GetAttribute("Ready") === true))) {
				luaCall(markBoot, "bridge");
			}
			return undefined;
		});
		return function(): unknown | undefined {
			alive = false;
			fontFinished = true;
			luaCall(cancelWorker, fontWorker);
			luaCall(cancelWorker, fontTimeout);
			luaCall(cancelWorker, moduleWorker);
			luaCall(cancelWorker, stateWorker);
			luaCall(destroyFontSamples);
			colon(stateConnection).Disconnect();
			colon(toastConnection).Disconnect();
			colon(effectConnection).Disconnect();
			return undefined;
		};
		return undefined;
	}, [acceptState, addNotice, addPop, applyComboReadout, celebrate, markBoot, remotes]);
	let stateLoaded: unknown = (state !== undefined);
	reactLoose.useEffect(function(): unknown | undefined {
		if ((!stateLoaded)) {
			return undefined;
		}
		let connection: unknown;
		let token: unknown = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
			luaCall(setShellMounted, true);
			let frames: unknown = 0;
			connection = colon(luaProp(RunService, "Heartbeat")).Connect(function(): unknown | undefined {
				frames = ((frames as unknown as number) + (1 as unknown as number));
				if (((frames as unknown as number) < (2 as unknown as number))) {
					return undefined;
				}
				let _result_11: unknown = connection;
				if ((_result_11 !== undefined)) {
					colon(_result_11).Disconnect();
				}
				connection = undefined;
				luaCall(markBoot, "shell");
				luaCall(markBoot, "mail");
				luaCall(markBoot, "research");
				luaCall(markBoot, "forge");
				luaCall(markBoot, "trade");
				luaCall(markBoot, "boosts");
				luaCall(markBoot, "settings");
				luaCall(markBoot, "mobile");
				return undefined;
			});
			return undefined;
		});
		return function(): unknown | undefined {
			luaCall(luaProp(task, "cancel"), token);
			let _result_11: unknown = connection;
			if ((_result_11 !== undefined)) {
				colon(_result_11).Disconnect();
			}
			return undefined;
		};
		return undefined;
	}, [markBoot, stateLoaded]);
	reactLoose.useEffect(function(): unknown | undefined {
		return luaCall(preloadMountedGame, function(): unknown | undefined {
			return luaCall(markBoot, "assets");
			return undefined;
		}, function(loaded?: unknown, total?: unknown): unknown | undefined {
			return luaCall(setAssetProgress, { loaded: loaded, total: total });
			return undefined;
		}, function(): unknown | undefined {
			return luaProp(shellMountedRef, "current");
			return undefined;
		});
		return undefined;
	}, [markBoot]);
	let _exp_4: unknown = function(): unknown | undefined {
		colon(Audio).start();
		let _object: unknown = {};
		let _left: unknown = "UiVolume";
		let _result_11: unknown = state;
		if ((_result_11 !== undefined)) {
			_result_11 = luaProp(luaProp(_result_11, "Settings"), "UiVolume");
		}
		luaSetIndex(_object, _left, _result_11);
		let _left_1: unknown = "GameplayVolume";
		let _result_12: unknown = state;
		if ((_result_12 !== undefined)) {
			_result_12 = luaProp(luaProp(_result_12, "Settings"), "GameplayVolume");
		}
		luaSetIndex(_object, _left_1, _result_12);
		let _left_2: unknown = "RewardVolume";
		let _result_13: unknown = state;
		if ((_result_13 !== undefined)) {
			_result_13 = luaProp(luaProp(_result_13, "Settings"), "RewardVolume");
		}
		luaSetIndex(_object, _left_2, _result_13);
		let _left_3: unknown = "AmbientVolume";
		let _result_14: unknown = state;
		if ((_result_14 !== undefined)) {
			_result_14 = luaProp(luaProp(_result_14, "Settings"), "AmbientVolume");
		}
		luaSetIndex(_object, _left_3, _result_14);
		let _left_4: unknown = "HoverSounds";
		let _result_15: unknown = state;
		if ((_result_15 !== undefined)) {
			_result_15 = luaProp(luaProp(_result_15, "Settings"), "HoverSounds");
		}
		luaSetIndex(_object, _left_4, _result_15);
		let _left_5: unknown = "NotificationSounds";
		let _result_16: unknown = state;
		if ((_result_16 !== undefined)) {
			_result_16 = luaProp(luaProp(_result_16, "Settings"), "NotificationSounds");
		}
		luaSetIndex(_object, _left_5, _result_16);
		let _left_6: unknown = "PageMusic";
		let _result_17: unknown = state;
		if ((_result_17 !== undefined)) {
			_result_17 = luaProp(luaProp(_result_17, "Settings"), "PageMusic");
		}
		luaSetIndex(_object, _left_6, _result_17);
		let _left_8: unknown = "SoundVariation";
		let _result_19: unknown = state;
		if ((_result_19 !== undefined)) {
			_result_19 = luaProp(luaProp(_result_19, "Settings"), "SoundVariation");
		}
		luaSetIndex(_object, _left_8, _result_19);
		colon(Audio).configurePreferences(_object);
		let _result_21: unknown = state;
		if ((_result_21 !== undefined)) {
			_result_21 = luaProp(luaProp(_result_21, "Settings"), "SoundVolume");
		}
		let _condition_4: unknown = _result_21;
		if ((_condition_4 === undefined)) {
			_condition_4 = 0.75;
		}
		colon(Audio).setVolume(_condition_4);
		let _result_22: unknown = state;
		if ((_result_22 !== undefined)) {
			_result_22 = luaProp(luaProp(_result_22, "Settings"), "MusicVolume");
		}
		let _condition_5: unknown = _result_22;
		if ((_condition_5 === undefined)) {
			_condition_5 = 1;
		}
		colon(Audio).setMusicVolume(_condition_5);
		let _result_23: unknown = state;
		if ((_result_23 !== undefined)) {
			_result_23 = luaProp(luaProp(_result_23, "Settings"), "SfxVolume");
		}
		let _condition_6: unknown = _result_23;
		if ((_condition_6 === undefined)) {
			_condition_6 = 1;
		}
		colon(Audio).setSfxVolume(_condition_6);
		return undefined;
	};
	let _result_11: unknown = state;
	if ((_result_11 !== undefined)) {
		_result_11 = luaProp(luaProp(_result_11, "Settings"), "AmbientVolume");
	}
	let _result_12: unknown = state;
	if ((_result_12 !== undefined)) {
		_result_12 = luaProp(luaProp(_result_12, "Settings"), "GameplayVolume");
	}
	let _result_13: unknown = state;
	if ((_result_13 !== undefined)) {
		_result_13 = luaProp(luaProp(_result_13, "Settings"), "HoverSounds");
	}
	let _result_15: unknown = state;
	if ((_result_15 !== undefined)) {
		_result_15 = luaProp(luaProp(_result_15, "Settings"), "SoundVariation");
	}
	let _result_17: unknown = state;
	if ((_result_17 !== undefined)) {
		_result_17 = luaProp(luaProp(_result_17, "Settings"), "MusicVolume");
	}
	let _result_18: unknown = state;
	if ((_result_18 !== undefined)) {
		_result_18 = luaProp(luaProp(_result_18, "Settings"), "NotificationSounds");
	}
	let _result_19: unknown = state;
	if ((_result_19 !== undefined)) {
		_result_19 = luaProp(luaProp(_result_19, "Settings"), "PageMusic");
	}
	let _result_20: unknown = state;
	if ((_result_20 !== undefined)) {
		_result_20 = luaProp(luaProp(_result_20, "Settings"), "RewardVolume");
	}
	let _result_21: unknown = state;
	if ((_result_21 !== undefined)) {
		_result_21 = luaProp(luaProp(_result_21, "Settings"), "SfxVolume");
	}
	let _result_22: unknown = state;
	if ((_result_22 !== undefined)) {
		_result_22 = luaProp(luaProp(_result_22, "Settings"), "SoundVolume");
	}
	let _result_23: unknown = state;
	if ((_result_23 !== undefined)) {
		_result_23 = luaProp(luaProp(_result_23, "Settings"), "UiVolume");
	}
	reactLoose.useEffect(_exp_4, [_result_11, _result_12, _result_13, _result_15, _result_17, _result_18, _result_19, _result_20, _result_21, _result_22, _result_23]);
	let _exp_5: unknown = function(): unknown | undefined {
		let _result_24: unknown = state;
		if ((_result_24 !== undefined)) {
			_result_24 = luaProp(luaProp(_result_24, "Settings"), "ScrollSpeed");
		}
		let _condition_4: unknown = _result_24;
		if ((_condition_4 === undefined)) {
			_condition_4 = 0.65;
		}
		luaCall(setScrollSpeed, _condition_4);
		let _result_25: unknown = state;
		if ((_result_25 !== undefined)) {
			_result_25 = luaProp(luaProp(_result_25, "Settings"), "ScrollMomentum");
		}
		let _condition_5: unknown = _result_25;
		if ((_condition_5 === undefined)) {
			_condition_5 = 0.75;
		}
		luaCall(setScrollMomentum, _condition_5);
		let _result_26: unknown = state;
		if ((_result_26 !== undefined)) {
			_result_26 = luaProp(luaProp(_result_26, "Settings"), "HapticIntensity");
		}
		let _condition_6: unknown = _result_26;
		if ((_condition_6 === undefined)) {
			_condition_6 = 0.65;
		}
		luaCall(setHapticIntensity, _condition_6);
		return undefined;
	};
	let _result_24: unknown = state;
	if ((_result_24 !== undefined)) {
		_result_24 = luaProp(luaProp(_result_24, "Settings"), "HapticIntensity");
	}
	let _result_25: unknown = state;
	if ((_result_25 !== undefined)) {
		_result_25 = luaProp(luaProp(_result_25, "Settings"), "ScrollMomentum");
	}
	let _result_26: unknown = state;
	if ((_result_26 !== undefined)) {
		_result_26 = luaProp(luaProp(_result_26, "Settings"), "ScrollSpeed");
	}
	reactLoose.useEffect(_exp_5, [_result_24, _result_25, _result_26]);
	let _result_27: unknown = state;
	if ((_result_27 !== undefined)) {
		_result_27 = luaProp(luaProp(_result_27, "Settings"), "MotionIntensity");
	}
	let _condition_4: unknown = _result_27;
	if ((_condition_4 === undefined)) {
		_condition_4 = 1;
	}
	let motionIntensity: unknown = _condition_4;
	let softFeel: unknown = ((luaProp(colon(game).GetService("GuiService"), "ReducedMotionEnabled") === true) || ((motionIntensity as unknown as number) < (0.3 as unknown as number)));
	let _result_28: unknown = state;
	if ((_result_28 !== undefined)) {
		_result_28 = luaProp(luaProp(_result_28, "Settings"), "ViewportSpeed");
	}
	let _condition_5: unknown = _result_28;
	if ((_condition_5 === undefined)) {
		_condition_5 = 1;
	}
	let viewportSpeed: unknown = _condition_5;
	let viewportTick: unknown;
	let setViewportTick: unknown;
	[viewportTick, setViewportTick] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
	reactLoose.useEffect(function(): unknown | undefined {
		let sizeConnection: unknown;
		function attach(): unknown | undefined {
			if ((sizeConnection !== undefined)) {
				colon(sizeConnection).Disconnect();
				sizeConnection = undefined;
			}
			let camera: unknown = luaProp(WorkspaceService, "CurrentCamera");
			if ((camera !== undefined)) {
				sizeConnection = colon(colon(camera).GetPropertyChangedSignal("ViewportSize")).Connect(function(): unknown | undefined {
					luaCall(setViewportTick, function(current?: unknown): unknown | undefined {
						return ((current as unknown as number) + (1 as unknown as number));
						return undefined;
					});
					return undefined;
				});
			}
			return undefined;
		}
		luaCall(attach);
		let cameraConnection: unknown = colon(colon(WorkspaceService).GetPropertyChangedSignal("CurrentCamera")).Connect(function(): unknown | undefined {
			luaCall(attach);
			luaCall(setViewportTick, function(current?: unknown): unknown | undefined {
				return ((current as unknown as number) + (1 as unknown as number));
				return undefined;
			});
			return undefined;
		});
		return function(): unknown | undefined {
			colon(cameraConnection).Disconnect();
			if ((sizeConnection !== undefined)) {
				colon(sizeConnection).Disconnect();
			}
			return undefined;
		};
		return undefined;
	}, {});
	let _result_29: unknown = luaProp(WorkspaceService, "CurrentCamera");
	if ((_result_29 !== undefined)) {
		_result_29 = luaProp(_result_29, "ViewportSize");
	}
	let _condition_6: unknown = _result_29;
	if ((_condition_6 === undefined)) {
		_condition_6 = new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1280, 720);
	}
	let rawViewportSize: unknown = _condition_6;
	let isTouchUiHere: unknown = ((!luaCall(usesDesktopStructure, luaProp(rawViewportSize, "X"), luaProp(rawViewportSize, "Y"))) && luaProp(UserInputService, "TouchEnabled"));
	let _result_30: unknown;
	if (isTouchUiHere) {
		let _result_31: unknown = state;
		if ((_result_31 !== undefined)) {
			_result_31 = luaProp(luaProp(_result_31, "Settings"), "MobileTextScale");
		}
		let _condition_7: unknown = _result_31;
		if ((_condition_7 === undefined)) {
			_condition_7 = 0.5;
		}
		_result_30 = ((0.92 as unknown as number) + (((_condition_7 as unknown as number) * (0.34 as unknown as number)) as unknown as number));
	} else {
		let _result_31: unknown = state;
		if ((_result_31 !== undefined)) {
			_result_31 = luaProp(luaProp(_result_31, "Settings"), "DesktopTextScale");
		}
		let _condition_7: unknown = _result_31;
		if ((_condition_7 === undefined)) {
			_condition_7 = 0.5;
		}
		_result_30 = ((0.96 as unknown as number) + (((_condition_7 as unknown as number) * (0.2 as unknown as number)) as unknown as number));
	}
	let textScale: unknown = _result_30;
	let _exp_6: unknown = function(): unknown | undefined {
		let _object: unknown = { motionScale: motionIntensity, viewportScale: viewportSpeed, textScale: textScale, soft: softFeel, reducedTransparency: (((state !== undefined) && (luaProp(state, "Settings") !== undefined)) && ((((luaCall(tonumber, luaProp(luaProp(state, "Settings"), "ReducedTransparency")) || 0)) as unknown as number) >= (0.5 as unknown as number))) };
		let _left: unknown = "shimmerScale";
		let _result_31: unknown = state;
		if ((_result_31 !== undefined)) {
			_result_31 = luaProp(luaProp(_result_31, "Settings"), "ButtonShimmers");
		}
		let _condition_7: unknown = _result_31;
		if ((_condition_7 === undefined)) {
			_condition_7 = 1;
		}
		let _result_32: unknown;
		if (((_condition_7 as unknown as number) >= (0.5 as unknown as number))) {
			let _result_33: unknown = state;
			if ((_result_33 !== undefined)) {
				_result_33 = luaProp(luaProp(_result_33, "Settings"), "ShimmerIntensity");
			}
			let _condition_8: unknown = _result_33;
			if ((_condition_8 === undefined)) {
				_condition_8 = 0.8;
			}
			_result_32 = _condition_8;
		} else {
			_result_32 = 0;
		}
		luaSetIndex(_object, _left, _result_32);
		let _left_1: unknown = "panelHoverScale";
		let _result_33: unknown = state;
		if ((_result_33 !== undefined)) {
			_result_33 = luaProp(luaProp(_result_33, "Settings"), "PanelHover");
		}
		let _condition_8: unknown = _result_33;
		if ((_condition_8 === undefined)) {
			_condition_8 = 1;
		}
		luaSetIndex(_object, _left_1, (((_condition_8 as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0));
		let _left_2: unknown = "panelEntranceScale";
		let _result_34: unknown = state;
		if ((_result_34 !== undefined)) {
			_result_34 = luaProp(luaProp(_result_34, "Settings"), "PanelEntrances");
		}
		let _condition_9: unknown = _result_34;
		if ((_condition_9 === undefined)) {
			_condition_9 = 1;
		}
		luaSetIndex(_object, _left_2, (((_condition_9 as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0));
		let _left_3: unknown = "titleScale";
		let _result_35: unknown = state;
		if ((_result_35 !== undefined)) {
			_result_35 = luaProp(luaProp(_result_35, "Settings"), "AnimatedTitles");
		}
		let _condition_10: unknown = _result_35;
		if ((_condition_10 === undefined)) {
			_condition_10 = 1;
		}
		luaSetIndex(_object, _left_3, (((_condition_10 as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0));
		let _left_4: unknown = "iconScale";
		let _result_36: unknown = state;
		if ((_result_36 !== undefined)) {
			_result_36 = luaProp(luaProp(_result_36, "Settings"), "IconAnimations");
		}
		let _condition_11: unknown = _result_36;
		if ((_condition_11 === undefined)) {
			_condition_11 = 1;
		}
		luaSetIndex(_object, _left_4, (((_condition_11 as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0));
		let _left_5: unknown = "numberScale";
		let _result_37: unknown = state;
		if ((_result_37 !== undefined)) {
			_result_37 = luaProp(luaProp(_result_37, "Settings"), "NumberAnimations");
		}
		let _condition_12: unknown = _result_37;
		if ((_condition_12 === undefined)) {
			_condition_12 = 1;
		}
		luaSetIndex(_object, _left_5, (((_condition_12 as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0));
		let _left_6: unknown = "boldText";
		let _result_38: unknown = state;
		if ((_result_38 !== undefined)) {
			_result_38 = luaProp(luaProp(_result_38, "Settings"), "BoldText");
		}
		let _condition_13: unknown = _result_38;
		if ((_condition_13 === undefined)) {
			_condition_13 = 0;
		}
		luaSetIndex(_object, _left_6, _condition_13);
		return _object;
		return undefined;
	};
	let _result_31: unknown = state;
	if ((_result_31 !== undefined)) {
		_result_31 = luaProp(luaProp(_result_31, "Settings"), "AnimatedTitles");
	}
	let _result_32: unknown = state;
	if ((_result_32 !== undefined)) {
		_result_32 = luaProp(luaProp(_result_32, "Settings"), "BoldText");
	}
	let _result_33: unknown = state;
	if ((_result_33 !== undefined)) {
		_result_33 = luaProp(luaProp(_result_33, "Settings"), "ButtonShimmers");
	}
	let _result_34: unknown = state;
	if ((_result_34 !== undefined)) {
		_result_34 = luaProp(luaProp(_result_34, "Settings"), "IconAnimations");
	}
	let _result_35: unknown = state;
	if ((_result_35 !== undefined)) {
		_result_35 = luaProp(luaProp(_result_35, "Settings"), "NumberAnimations");
	}
	let _result_36: unknown = state;
	if ((_result_36 !== undefined)) {
		_result_36 = luaProp(luaProp(_result_36, "Settings"), "PanelEntrances");
	}
	let _result_37: unknown = state;
	if ((_result_37 !== undefined)) {
		_result_37 = luaProp(luaProp(_result_37, "Settings"), "PanelHover");
	}
	let _result_38: unknown = state;
	if ((_result_38 !== undefined)) {
		_result_38 = luaProp(luaProp(_result_38, "Settings"), "ShimmerIntensity");
	}
	let _result_39: unknown = state;
	if ((_result_39 !== undefined)) {
		_result_39 = luaProp(luaProp(_result_39, "Settings"), "ReducedTransparency");
	}
	let motionSettings: unknown = reactLoose.useMemo(_exp_6, [motionIntensity, softFeel, _result_31, _result_32, _result_33, _result_34, _result_35, _result_36, _result_37, _result_38, _result_39, textScale, viewportSpeed]);
	let prankReveals: unknown = { FakeRareDrop: "No relic was added; the case is unchanged.", FakeEvent: "No server event started.", JumbleHud: "Your interface is back to normal.", FakeRebirth: "No progress or currency changed.", FakeTrade: "No trade session opened and no items moved.", FakeRob: "No balances changed.", EmptyBagScare: "Your relic inventory was never changed." };
	let clearAdminPrank: unknown = reactLoose.useCallback(function(): unknown | undefined {
		let reveal: unknown = (adminPrank && luaIndex(prankReveals, luaProp(adminPrank, "kind")));
		if (reveal) {
			luaCall(addNotice, "Staff prank", reveal, "Info", false);
		}
		luaCall(setAdminPrank, undefined);
		return undefined;
	}, [addNotice, adminPrank]);
	let _condition_8: unknown = ((state !== undefined) && shellMounted);
	if (_condition_8) {
		let _attributes: unknown = { state: state, config: config, dispatch: dispatch, addNotice: addNotice, celebrate: celebrate, confettiNonce: confettiNonce, clearConfetti: clearConfetti, pops: pops, comboReadout: comboReadout, visit: visit, setVisit: setVisit };
		let _result_39: unknown = domainUi;
		if ((_result_39 !== undefined)) {
			_result_39 = luaProp(_result_39, "open");
		}
		let _condition_9: unknown = _result_39;
		if ((_condition_9 === undefined)) {
			_condition_9 = NOOP;
		}
		luaSet(_attributes, "openDomain", _condition_9);
		let _result_40: unknown = domainUi;
		if ((_result_40 !== undefined)) {
			_result_40 = luaProp(_result_40, "active");
		}
		luaSet(_attributes, "domainOverlayActive", (_result_40 === true));
		luaSet(_attributes, "setToastsSuppressed", setToastsSuppressed);
		luaSet(_attributes, "setPurchasePresentationActive", setPurchasePresentationActive);
		let _exp_7: unknown = reactLoose.createElement(Shell, _attributes);
		_condition_8 = _exp_7;
	}
	let shellContent: unknown = _condition_8;
	let domainContent: unknown = (((state !== undefined) && shellMounted) ? reactLoose.createElement(AutoScale, undefined, ((domainUi !== undefined) ? luaCall(luaProp(domainUi, "render"), state, dispatch, shellContent) : shellContent)) : shellContent);
	let _attributes: unknown = { prank: adminPrank };
	luaSet(_attributes, "reducedMotion", false);
	let _exp_7: unknown = reactLoose.createElement(HudPrankStage, _attributes, domainContent);
	let _condition_9: unknown = (adminPrank !== undefined);
	if (_condition_9) {
		let _attributes_1: unknown = { prank: adminPrank };
		luaSet(_attributes_1, "reducedMotion", false);
		luaSet(_attributes_1, "onClose", clearAdminPrank);
		_condition_9 = reactLoose.createElement(AdminPrankOverlay, _attributes_1);
	}
	let _condition_10: unknown = ((!externalBoot) && bootVisible);
	if (_condition_10) {
		let _attributes_1: unknown = { marks: bootMarks, ready: bootReady, progress: bootFill, version: luaProp(luaProp(config, "Game"), "Version") };
		luaSet(_attributes_1, "reducedMotion", false);
		luaSet(_attributes_1, "startedAt", bootStartedAt);
		luaSet(_attributes_1, "assetsLoaded", luaProp(assetProgress, "loaded"));
		luaSet(_attributes_1, "assetsTotal", luaProp(assetProgress, "total"));
		luaSet(_attributes_1, "modulesLoaded", luaProp(moduleProgress, "loaded"));
		luaSet(_attributes_1, "modulesTotal", luaProp(moduleProgress, "total"));
		luaSet(_attributes_1, "onExitDone", onBootExitDone);
		_condition_10 = reactLoose.createElement(luaProp(MotionSettingsContext, "Provider"), { value: luaProp(Boot, "BOOT_MOTION") }, reactLoose.createElement(luaProp(Boot, "BootScreen"), _attributes_1));
	}
	let content: unknown = reactLoose.createElement(luaProp(MotionSettingsContext, "Provider"), { value: motionSettings }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: 1, BorderSizePixel: 0 }, _exp_7, _condition_9, _condition_10));
	return (externalAntilag ? content : reactLoose.createElement(AntilagProvider, undefined, content));
	return undefined;
}

export { MainGame };
