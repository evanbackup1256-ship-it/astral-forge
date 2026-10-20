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

const AstralForge = script.Parent!.Parent!.Parent!;

function kit(name: string, member: string): unknown {
	return luaCall(luaRequire(AstralForge.WaitForChild(name) as ModuleScript), member);
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

function __member(): unknown {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let formatReward: unknown = luaProp(kit("CoreKit", "format"), "formatReward");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let _motion: unknown = kit("MotionKit", "motion");
	let useEntrance: unknown = luaProp(_motion, "useEntrance");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let usePulse: unknown = luaProp(_motion, "usePulse");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Palette: unknown = luaProp(_theme, "Palette");
	let darken: unknown = luaProp(_theme, "darken");
	let Layout: unknown = luaProp(_theme, "Layout");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let Meter: unknown = luaProp(_ui, "Meter");
	let meterFill: unknown = luaProp(_ui, "meterFill");
	let measureWrappedTextHeight: unknown = luaProp(_ui, "measureWrappedTextHeight");
	let Text: unknown = luaProp(_ui, "Text");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let Browse: unknown = mod("BrowseKit");
	let CHAPTER_ROW_H: unknown = 58;
	let CHAPTER_ROW_GAP: unknown = 8;
	let CHAPTER_ROW_STRIDE: unknown = ((CHAPTER_ROW_H as unknown as number) + (CHAPTER_ROW_GAP as unknown as number));
	function illuminate(text?: unknown, accent?: unknown): unknown | undefined {
		let rgb: unknown = `${luaCall(luaProp(math, "floor"), ((luaProp(accent, "R") as unknown as number) * (255 as unknown as number)))},${luaCall(luaProp(math, "floor"), ((luaProp(accent, "G") as unknown as number) * (255 as unknown as number)))},${luaCall(luaProp(math, "floor"), ((luaProp(accent, "B") as unknown as number) * (255 as unknown as number)))}`;
		let result: unknown = text;
		for (const [_, phrase] of pairs((["Bay Seven", "Stellar Core", "ILYRA VALE", "Astral Forge", "Hollow Star", "stars"]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let _result: unknown = result;
			let _arg1: unknown = `<font color="rgb(${rgb})"><b>${phrase}</b></font>`;
			let updated: unknown = luaCall(luaProp(string, "gsub"), _result, phrase, _arg1);
			result = updated;
		}
		return result;
		return undefined;
	}
	function ArchiveMark(_param?: unknown): unknown | undefined {
		let accent: unknown = luaProp(_param, "accent");
		let active: unknown = luaProp(_param, "active");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let beat: unknown = luaProp(_param, "beat");
		let total: unknown = luaProp(_param, "total");
		let compact: unknown = luaProp(_param, "compact");
		let finished: unknown = luaProp(_param, "finished");
		let unlocked: unknown = luaProp(_param, "unlocked");
		let unlockProgress: unknown = luaProp(_param, "unlockProgress");
		if ((unlockProgress === undefined)) {
			unlockProgress = 0;
		}
		let unlockLabel: unknown = luaProp(_param, "unlockLabel");
		let pulse: unknown = luaCall(usePulse, (active && (!reducedMotion)), 1.2);
		let enter: unknown = luaCall(useEntrance, reducedMotion);
		let progress: unknown = (active ? luaCall(meterFill, ((beat as unknown as number) + (1 as unknown as number)), luaCall(luaProp(math, "max"), 1, total)) : (finished ? 1 : luaCall(luaProp(math, "clamp"), unlockProgress, 0, 1)));
		let statusLabel: unknown = (((!active) && finished) ? "REPLAY" : (active ? "OPEN" : (unlocked ? "READY" : "LOCKED")));
		let _result: unknown;
		if (active) {
			_result = `Part ${((beat as unknown as number) + (1 as unknown as number))} / ${luaCall(luaProp(math, "max"), 1, total)}`;
		} else {
			let _result_1: unknown;
			if (finished) {
				_result_1 = "Finished chapter";
			} else {
				let _result_2: unknown;
				if (unlocked) {
					_result_2 = "Ready to read";
				} else {
					let _condition: unknown = unlockLabel;
					if ((_condition === undefined)) {
						_condition = "Bay Seven";
					}
					_result_2 = _condition;
				}
				_result_1 = _result_2;
			}
			_result = _result_1;
		}
		let detail: unknown = _result;
		if (compact) {
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaCall(darken, accent, 0.92), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaCall(darken, accent, 0.86), luaProp(Palette, "void")), Rotation: 90 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -16), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 8), BackgroundColor3: accent, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement(Icon, { kind: "Story.2", color: luaProp(Palette, "cream"), accent: accent, size: 32, position: luaCall(luaProp(UDim2, "fromOffset"), 14, 14), spin: false, reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: statusLabel, size: 11, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 56, 12), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0, 16) }), reactLoose.createElement(Text, { value: detail, size: 13, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 56, 30), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0, 18) }), reactLoose.createElement(Meter, { value: progress, color: accent, reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 14, 54), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -28, 0, 5) }));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaCall(darken, accent, 0.92), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaCall(darken, accent, 0.86), luaProp(Palette, "void")), Rotation: 112 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 0.5, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 2, 0.25, 0), BackgroundColor3: accent, BackgroundTransparency: 0.15, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 84, 84), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0, 28), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0), BackgroundColor3: luaProp(Palette, "panel"), BackgroundTransparency: colon(enter).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uiscale", { Scale: colon(pulse).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) + (((amount as unknown as number) * (0.03 as unknown as number)) as unknown as number));
			return undefined;
		}) }), reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 22) }), reactLoose.createElement("uistroke", { Color: accent, Thickness: 1, Transparency: 0.28 }), reactLoose.createElement(Icon, { kind: "Story.3", color: luaProp(Palette, "cream"), accent: accent, size: 48, position: luaCall(luaProp(UDim2, "fromOffset"), 18, 18), spin: false, reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.86, 0, 0, 64), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.07, 0, 0, 124), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Text, { value: statusLabel, size: 12, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) }), reactLoose.createElement(Text, { value: detail, size: 12, color: luaProp(Palette, "creamSoft"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) }), reactLoose.createElement(Meter, { value: progress, color: accent, reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 46), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 6) })));
		return undefined;
	}
	function ChapterRailRow(_param?: unknown): unknown | undefined {
		let chapter: unknown = luaProp(_param, "chapter");
		let entry: unknown = luaProp(_param, "entry");
		let selected: unknown = luaProp(_param, "selected");
		let onSelect: unknown = luaProp(_param, "onSelect");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let open: unknown = luaProp(chapter, "Unlocked");
		let done: unknown = (luaProp(chapter, "Claimed") || luaProp(chapter, "Read"));
		let label: unknown = ((!open) ? "LOCK" : (done ? "DONE" : "NEW"));
		let accent: unknown = luaProp(entry, "Color");
		return reactLoose.createElement("textbutton", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, CHAPTER_ROW_H), BackgroundColor3: (selected ? luaProp(Palette, "panel") : luaProp(Palette, "ink")), BorderSizePixel: 0, Text: "", AutoButtonColor: false, Active: true, Selectable: true, LayoutOrder: layoutOrder, Event: { Activated: function(): unknown | undefined {
			if (open) {
				luaCall(onSelect);
				colon(Audio).play("storyPage");
			} else {
				colon(Audio).play("locked");
			}
			return undefined;
		}, MouseEnter: function(): unknown | undefined {
			return colon(Audio).play("hover");
			return undefined;
		}, SelectionGained: function(): unknown | undefined {
			return colon(Audio).play("hover");
			return undefined;
		} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: (selected ? accent : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: (selected ? 0.15 : 0.55) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -12), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 6), BackgroundColor3: (open ? accent : luaProp(Palette, "muted")), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement(Text, { value: luaProp(entry, "Chapter"), size: 10, color: (open ? accent : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 12, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -84, 0, 14) }), reactLoose.createElement(Text, { value: luaProp(entry, "Title"), size: 13, color: (open ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 12, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -84, 0, 18) }), ((!open) && reactLoose.createElement(Text, { value: `${luaCall(luaProp(math, "floor"), luaProp(chapter, "Progress"))} / ${luaProp(chapter, "Target")}`, size: 10, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 12, 42), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -84, 0, 12) })), reactLoose.createElement(Badge, { value: label, accent: (open ? ((done ? luaProp(Palette, "mint") : accent)) : luaProp(Palette, "muted")), filled: open, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0.5, -11), size: luaCall(luaProp(UDim2, "fromOffset"), 62, 22) }));
		return undefined;
	}
	function StoryBeat(_param?: unknown): unknown | undefined {
		let text: unknown = luaProp(_param, "text");
		let index: unknown = luaProp(_param, "index");
		let total: unknown = luaProp(_param, "total");
		let color: unknown = luaProp(_param, "color");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let claimed: unknown = luaProp(_param, "claimed");
		let reward: unknown = luaProp(_param, "reward");
		let replay: unknown = luaProp(_param, "replay");
		let onBack: unknown = luaProp(_param, "onBack");
		let onNext: unknown = luaProp(_param, "onNext");
		let onClaim: unknown = luaProp(_param, "onClaim");
		let onClose: unknown = luaProp(_param, "onClose");
		let stack: unknown = luaProp(_param, "stack");
		let condensed: unknown = luaProp(_param, "condensed");
		let softMotion: unknown = reducedMotion;
		let enter: unknown = luaCall(useEntrance, reducedMotion);
		let visible: unknown;
		let setVisible: unknown;
		[visible, setVisible] = reactLoose.useBinding(0) as LuaTuple<[unknown, unknown]>;
		let tuned: unknown = true;
		reactLoose.useEffect(function(): unknown | undefined {
			let alive: unknown = true;
			let revealWorker: unknown;
			luaCall(setVisible, 0);
			colon(Audio).play("storyBeat");
			let stepDiv: unknown = (reducedMotion ? 28 : 72);
			let stepWait: unknown = (reducedMotion ? 0.012 : 0.022);
			revealWorker = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
				let count: unknown = 0;
				let step: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "floor"), ((len(text) as unknown as number) / (stepDiv as unknown as number))));
				while ((alive && ((count as unknown as number) < (len(text) as unknown as number)))) {
					count = luaCall(luaProp(math, "min"), len(text), ((count as unknown as number) + (step as unknown as number)));
					if ((!alive)) {
						break;
					}
					luaCall(setVisible, count);
					luaCall(luaProp(task, "wait"), stepWait);
				}
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				if ((revealWorker !== undefined)) {
					luaCall(pcall, function(): unknown | undefined {
						luaCall(luaProp(task, "cancel"), revealWorker);
						return undefined;
					});
				}
				return undefined;
			};
			return undefined;
		}, [index, reducedMotion, replay, text]);
		let final: unknown = ((index as unknown as number) >= (((total as unknown as number) - (1 as unknown as number)) as unknown as number));
		let action: unknown = (final ? (claimed ? onClose : onClaim) : onNext);
		let actionText: unknown = (final ? (claimed ? "Done" : "Collect reward") : "Continue");
		let actionIcon: unknown = (final ? (claimed ? "Check" : "Gift") : "Chevron");
		let tipText: unknown = (replay ? "Replay: read any part" : `Part ${((index as unknown as number) + (1 as unknown as number))} of ${total}`);
		let decorated: unknown = luaCall(illuminate, text, color);
		let btnH: unknown = (stack ? TapTarget : 48);
		let showTip: unknown = ((!condensed) && (((!stack) || (!tuned))));
		let tipH: unknown = (showTip ? ((stack ? 36 : 32)) : 0);
		let actionsH: unknown = ((stack && (!condensed)) ? ((((btnH as unknown as number) * (2 as unknown as number)) as unknown as number) + (10 as unknown as number)) : btnH);
		let headerH: unknown = (stack ? 28 : 40);
		let bodySize: unknown = (stack ? 17 : 20);
		let lineHeight: unknown = (stack ? 1.36 : 1.42);
		let partFill: unknown = luaCall(meterFill, ((index as unknown as number) + (1 as unknown as number)), total);
		let tipAccent: unknown = (tuned ? luaProp(Palette, "green") : color);
		let bodyGap: unknown = (stack ? 16 : luaProp(Layout, "panelGap"));
		let bodyPadR: unknown = (stack ? 4 : luaProp(Layout, "stackGap"));
		let viewport: unknown = luaCall(useViewport);
		let storyActionsHostRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!luaProp(UserInputService, "GamepadEnabled"))) {
				return undefined;
			}
			let host: unknown = luaProp(storyActionsHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let selectJob: unknown = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
				if ((luaProp(host, "Parent") === undefined)) {
					return;
				}
				luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				return undefined;
			});
			return function(): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), selectJob);
				return undefined;
			};
			return undefined;
		}, [index, tuned, claimed, actionText]);
		let measureWidth: unknown = luaCall(luaProp(math, "max"), 160, ((((luaCall(luaProp(math, "floor"), ((((luaProp(viewport, "width") || 390)) as unknown as number) * (((stack ? 0.92 : 0.55)) as unknown as number))) as unknown as number) - (bodyPadR as unknown as number)) as unknown as number) - (12 as unknown as number)));
		let textH: unknown = luaCall(luaProp(math, "max"), 64, ((luaCall(luaProp(math, "ceil"), ((luaCall(measureWrappedTextHeight, text, measureWidth, bodySize, luaProp(luaProp(Enum, "FontWeight"), "Medium")) as unknown as number) * (lineHeight as unknown as number))) as unknown as number) + (8 as unknown as number)));
		let estimatedBodyH: unknown = ((((((textH as unknown as number) + (((final ? ((56 as unknown as number) + (bodyGap as unknown as number)) : 0)) as unknown as number)) as unknown as number) + (((stack ? 24 : 16)) as unknown as number)) as unknown as number) + (12 as unknown as number));
		let headerElement: unknown = (stack ? reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Meter, { value: partFill, color: color, reducedMotion: reducedMotion, shimmer: final, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 4), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 4) })) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Text, { value: `Part ${((index as unknown as number) + (1 as unknown as number))} of ${total}`, size: 13, color: color, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20), transparency: colon(enter).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		}) }), reactLoose.createElement(Meter, { value: partFill, color: color, reducedMotion: reducedMotion, shimmer: final, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 5) })));
		let bodyElement: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, bodyGap) }), reactLoose.createElement("uipadding", { PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, bodyPadR), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundTransparency: 1, BorderSizePixel: 0, Text: decorated, RichText: true, TextColor3: luaProp(Palette, "cream"), TextSize: bodySize, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), TextWrapped: true, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Top"), LineHeight: lineHeight, MaxVisibleGraphemes: visible, TextTransparency: colon(enter).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		}), TextScaled: false, TextTruncate: luaProp(luaProp(Enum, "TextTruncate"), "None"), LayoutOrder: 0 }), (final && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, 56), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0, LayoutOrder: 1, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: color, Thickness: 1, Transparency: 0.35 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -12), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 6), BackgroundColor3: color, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement(Text, { value: (claimed ? "REWARD CLAIMED" : "REWARD"), size: 11, color: color, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 16, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -28, 0, 16) }), reactLoose.createElement(Text, { value: reward, size: 15, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), wrap: true, fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 16, 26), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -28, 0, 24) }))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (stack ? 24 : 16)), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 2 }));
		let tipElement: unknown = ((!showTip) ? undefined : (stack ? reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panelSoft"), BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: tipAccent, Thickness: 1, Transparency: 0.45 }), reactLoose.createElement(Text, { value: tipText, size: 12, color: (tuned ? luaProp(Palette, "green") : luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), wrap: true, fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) })) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, tipH), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), BackgroundColor3: luaProp(Palette, "panelSoft"), BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement("uistroke", { Color: tipAccent, Thickness: 1, Transparency: 0.4 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), BackgroundTransparency: 1, BorderSizePixel: 0, Text: tipText, TextColor3: (tuned ? luaProp(Palette, "green") : luaProp(Palette, "cream")), TextSize: 12, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center"), TextTruncate: luaProp(luaProp(Enum, "TextTruncate"), "None"), ZIndex: 4 })))));
		let continueSlot: unknown = reactLoose.createElement("frame", { Name: ((final && (!claimed)) ? "StoryClaim" : "StoryContinue"), Size: ((stack && (!condensed)) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, btnH) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -140, 0, btnH)), Position: ((stack && (!condensed)) ? undefined : luaCall(luaProp(UDim2, "fromOffset"), 140, 0)), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 0 }, reactLoose.createElement(Button, { text: actionText, icon: actionIcon, onClick: action, color: ((!tuned) ? color : (final ? color : luaProp(Palette, "mint"))), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, highlight: (((!claimed) || (!tuned)) || replay) }));
		let backSlot: unknown = reactLoose.createElement("frame", { Name: "StoryBack", Size: ((stack && (!condensed)) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, btnH) : luaCall(luaProp(UDim2, "fromOffset"), 128, btnH)), Position: ((stack && (!condensed)) ? undefined : luaCall(luaProp(UDim2, "fromOffset"), 0, 0)), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 1 }, reactLoose.createElement(Button, { text: "Back", icon: "Back.2", onClick: onBack, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: ((index as unknown as number) <= (0 as unknown as number)), reducedMotion: reducedMotion }));
		let actionsElement: unknown = ((stack && (!condensed)) ? reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), continueSlot, backSlot) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, backSlot, continueSlot));
		let sections: unknown = [{ id: "beat-header", height: headerH, element: headerElement }, { id: "beat-body", fill: true, minHeight: 72, height: estimatedBodyH, element: bodyElement }];
		if ((showTip && (tipElement !== undefined))) {
			luaTable.insert(sections, { id: "beat-tip", height: tipH, element: tipElement });
		}
		let actionsGap: unknown = 8;
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-((((actionsH as unknown as number) + (actionsGap as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement(PageScaffold, { gap: (showTip ? ((stack ? 8 : luaProp(Layout, "stackGap"))) : 6), tailPad: 4, scrollBarColor: color, scrollBarThickness: (stack ? 4 : 3), sections: sections })), reactLoose.createElement("frame", { ref: storyActionsHostRef, Name: "StoryBeatActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, actionsH), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(actionsH as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ZIndex: 6 }, actionsElement));
		return undefined;
	}
	function chapterConfig(config?: unknown, id?: unknown): unknown | undefined {
		let _exp: unknown = luaProp(config, "Story");
		let _callback: unknown = function(entry?: unknown): unknown | undefined {
			return (luaProp(entry, "Id") === id);
			return undefined;
		};
		let _result: unknown;
		for (const [_i, _v] of pairs((_exp) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), _exp) === true)) {
				_result = _v;
				break;
			}
		}
		return _result;
		return undefined;
	}
	function pickDefaultChapter(chapters?: unknown): unknown | undefined {
		for (const [_, chapter] of pairs((chapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaProp(chapter, "Unlocked") && (!luaProp(chapter, "Claimed")))) {
				return luaProp(chapter, "Id");
			}
		}
		for (const [_, chapter] of pairs((chapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (luaProp(chapter, "Unlocked")) {
				return luaProp(chapter, "Id");
			}
		}
		let _result: unknown = luaIndex(chapters, 1);
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Id");
		}
		return _result;
		return undefined;
	}
	function StoryView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let stack: unknown = luaProp(chrome, "contentStack");
		let shortLandscape: unknown = (luaProp(chrome, "landscape") && ((luaProp(viewport, "height") as unknown as number) < (500 as unknown as number)));
		let chapters: unknown = (luaProp(state, "Story") || {});
		let selectedId: unknown;
		let setSelectedId: unknown;
		[selectedId, setSelectedId] = reactLoose.useState(function(): unknown | undefined {
			return luaCall(pickDefaultChapter, chapters);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		let started: unknown;
		let setStarted: unknown;
		[started, setStarted] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let beat: unknown;
		let setBeat: unknown;
		[beat, setBeat] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(): unknown | undefined {
			colon(Audio).play("storyOpen");
			colon(ClientLog).debug("nav", "story opened");
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			let _condition: unknown = (selectedId === undefined);
			if ((!_condition)) {
				let _callback: unknown = function(chapter?: unknown): unknown | undefined {
					return (luaProp(chapter, "Id") === selectedId);
					return undefined;
				};
				let _result: unknown;
				for (const [_i, _v] of pairs((chapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), chapters) === true)) {
						_result = _v;
						break;
					}
				}
				_condition = (!_result);
			}
			if (_condition) {
				luaCall(setSelectedId, luaCall(pickDefaultChapter, chapters));
				luaCall(setStarted, false);
				luaCall(setBeat, 0);
			}
			return undefined;
		}, [chapters, selectedId]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (((!started) || (selectedId === undefined))) {
				return undefined;
			}
			colon(ClientLog).debug("story", `${selectedId} beat ${((beat as unknown as number) + (1 as unknown as number))}`);
			return undefined;
		}, [beat, selectedId, started]);
		let _callback: unknown = function(chapter?: unknown): unknown | undefined {
			return (luaProp(chapter, "Id") === selectedId);
			return undefined;
		};
		let _result: unknown;
		for (const [_i, _v] of pairs((chapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), chapters) === true)) {
				_result = _v;
				break;
			}
		}
		let status: unknown = _result;
		let story: unknown = (status ? luaCall(chapterConfig, config, luaProp(status, "Id")) : undefined);
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let intro: unknown = luaCall(useEntrance, softMotion);
		let archivePulse: unknown = luaCall(usePulse, ((!softMotion) && (!started)), 3.4);
		let archiveReveal: unknown = luaCall(useStagger, 0, softMotion);
		let archiveMotionEnabled: unknown = softMotion;
		let chapterBrowse: unknown = luaCall(luaProp(Browse, "useBrowse"), { id: "Story", items: chapters, text: function(chapter?: unknown): unknown | undefined {
			let entry: unknown = luaCall(chapterConfig, config, luaProp(chapter, "Id"));
			return [(entry ? luaProp(entry, "Title") : luaProp(chapter, "Id")), (entry ? luaProp(entry, "Chapter") : undefined), (entry ? luaProp(entry, "Summary") : undefined)];
			return undefined;
		}, categories: [{ id: "All", label: "All" }, { id: "New", label: "New", test: function(chapter?: unknown): unknown | undefined {
			return ((luaProp(chapter, "Unlocked") === true) && (luaProp(chapter, "Read") !== true));
			return undefined;
		} }, { id: "Reward", label: "Reward", test: function(chapter?: unknown): unknown | undefined {
			return (((luaProp(chapter, "Unlocked") === true) && (luaProp(chapter, "Claimed") !== true)) && (luaProp(chapter, "Read") === true));
			return undefined;
		} }, { id: "Read", label: "Read", test: function(chapter?: unknown): unknown | undefined {
			return (luaProp(chapter, "Read") === true);
			return undefined;
		} }, { id: "Locked", label: "Locked", test: function(chapter?: unknown): unknown | undefined {
			return (luaProp(chapter, "Unlocked") !== true);
			return undefined;
		} }] });
		// a deep link from Quick Find opens the best match directly
		reactLoose.useEffect(function(): unknown | undefined {
			if (((luaProp(chapterBrowse, "searching") && luaProp(chapterBrowse, "relevance")) && (luaIndex(luaProp(chapterBrowse, "results"), 1) !== undefined))) {
				let top: unknown = luaIndex(luaProp(chapterBrowse, "results"), 1);
				if ((luaProp(top, "Id") !== selectedId)) {
					luaCall(setSelectedId, luaProp(top, "Id"));
					luaCall(setStarted, false);
					luaCall(setBeat, 0);
				}
			}
			return undefined;
		}, [luaProp(chapterBrowse, "query")]);
		if (((!story) || (!status))) {
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 });
		}
		let finished: unknown = ((luaProp(status, "Read") === true) || (luaProp(status, "Claimed") === true));
		let locked: unknown = (!luaProp(status, "Unlocked"));
		let unlockFill: unknown = luaCall(meterFill, luaProp(status, "Progress"), luaCall(luaProp(math, "max"), 1, luaProp(status, "Target")), luaProp(status, "Unlocked"));
		let unlockLabel: unknown = (locked ? `${luaCall(luaProp(math, "floor"), luaProp(status, "Progress"))} / ${luaProp(status, "Target")}` : luaProp(story, "Chapter"));
		let begin: unknown = function(): unknown | undefined {
			if (locked) {
				return undefined;
			}
			luaCall(setBeat, 0);
			luaCall(setStarted, true);
			colon(Audio).play("storyOpen");
			if ((!luaProp(status, "Read"))) {
				luaCall(dispatch, "ReadStoryChapter", { Id: luaProp(story, "Id") });
			}
			return undefined;
		};
		let closeReplay: unknown = function(): unknown | undefined {
			colon(Audio).play("close");
			luaCall(setStarted, false);
			luaCall(setBeat, 0);
			return undefined;
		};
		let selectChapter: unknown = function(id?: unknown): unknown | undefined {
			colon(Audio).play("page");
			luaCall(setSelectedId, id);
			luaCall(setStarted, false);
			luaCall(setBeat, 0);
			return undefined;
		};
		let advance: unknown = function(): unknown | undefined {
			colon(Audio).play("storyReveal");
			luaCall(setBeat, luaCall(luaProp(math, "min"), ((len(luaProp(story, "Body")) as unknown as number) - (1 as unknown as number)), ((beat as unknown as number) + (1 as unknown as number))));
			return undefined;
		};
		let rewind: unknown = function(): unknown | undefined {
			colon(Audio).play("close");
			luaCall(setBeat, luaCall(luaProp(math, "max"), 0, ((beat as unknown as number) - (1 as unknown as number))));
			return undefined;
		};
		let readingMobile: unknown = (stack && started);
		let markH: unknown = (readingMobile ? 0 : ((stack ? ((luaProp(chrome, "landscape") ? 0 : 68)) : 76)));
		let railGap: unknown = 14;
		let railShare: unknown = 0.26;
		let chapterCount: unknown = len(chapters);
		let unlockedCount: unknown = 0;
		let claimedCount: unknown = 0;
		for (const [_, chapter] of pairs((chapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (luaProp(chapter, "Unlocked")) {
				unlockedCount = ((unlockedCount as unknown as number) + (1 as unknown as number));
			}
			if (luaProp(chapter, "Claimed")) {
				claimedCount = ((claimedCount as unknown as number) + (1 as unknown as number));
			}
		}
		let multi: unknown = ((chapterCount as unknown as number) > (1 as unknown as number));
		let railMarkH: unknown = ((multi && (!stack)) ? 84 : ((stack ? markH : 0)));
		// the mark is ~76px of content; taller only left an empty card
		let readerPad: unknown = (shortLandscape ? 12 : (stack ? ((started ? 12 : 14)) : luaProp(Layout, "contentInset")));
		let _exp: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) });
		let _exp_1: unknown = reactLoose.createElement("uistroke", { Color: luaProp(story, "Color"), Thickness: 1, Transparency: 0.52 });
		let _condition: unknown = (!reducedMotion);
		if (_condition) {
			let _exp_2: unknown = [0, 1, 2];
			let _newValue: unknown = luaCall(luaProp(table, "create"), len(_exp_2));
			let _callback_1: unknown = function(index?: unknown): unknown | undefined {
				return reactLoose.createElement("frame", { key: `archive-orbit-${index}`, Size: colon(archivePulse).map(function(amount?: unknown): unknown | undefined {
					return luaCall(luaProp(UDim2, "fromOffset"), ((((260 as unknown as number) + (((index as unknown as number) * (82 as unknown as number)) as unknown as number)) as unknown as number) + (((amount as unknown as number) * (16 as unknown as number)) as unknown as number)), ((((260 as unknown as number) + (((index as unknown as number) * (82 as unknown as number)) as unknown as number)) as unknown as number) + (((amount as unknown as number) * (16 as unknown as number)) as unknown as number)));
					return undefined;
				}), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, ((50 as unknown as number) - (((index as unknown as number) * (32 as unknown as number)) as unknown as number)), 0, ((-70 as unknown as number) + (((index as unknown as number) * (28 as unknown as number)) as unknown as number))), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, Rotation: ((index as unknown as number) * (17 as unknown as number)), ZIndex: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: ((index === 1) ? luaProp(Palette, "cyan") : luaProp(story, "Color")), Thickness: 1, Transparency: ((0.9 as unknown as number) + (((index as unknown as number) * (0.02 as unknown as number)) as unknown as number)) }));
				return undefined;
			};
			for (const [_k, _v] of pairs((_exp_2) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), _exp_2));
			}
			_condition = _newValue;
		}
		let _condition_1: unknown = ((!readingMobile) && ((markH as unknown as number) > (0 as unknown as number)));
		if (_condition_1) {
			let _exp_2: unknown = (((stack || multi)) && reactLoose.createElement("frame", { Size: (stack ? luaCall(luaProp(UDim2, "fromScale"), 1, 1) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, railMarkH)), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(ArchiveMark, { accent: luaProp(story, "Color"), active: started, reducedMotion: softMotion, beat: beat, total: len(luaProp(story, "Body")), compact: (stack || multi), finished: finished, unlocked: luaProp(status, "Unlocked"), unlockProgress: unlockFill, unlockLabel: unlockLabel })));
			let _condition_2: unknown = ((!stack) && multi);
			if (_condition_2) {
				let railChapters: unknown = {};
				for (const [_, chapter] of pairs((luaProp(chapterBrowse, "results")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					let entry: unknown = luaCall(chapterConfig, config, luaProp(chapter, "Id"));
					if ((entry !== undefined)) {
						luaTable.insert(railChapters, { chapter: chapter, entry: entry });
					}
				}
				let railListTop: unknown = ((railMarkH as unknown as number) + (10 as unknown as number));
				let railHeaderH: unknown = ((((((((20 as unknown as number) + (TapTarget as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) + (luaProp(Browse, "CHIP_H") as unknown as number)) as unknown as number) + (8 as unknown as number));
				_condition_2 = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-(railListTop as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, railListTop), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Text, { value: "CHAPTERS", size: 10, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16), transparency: colon(archiveReveal).map(function(amount?: unknown): unknown | undefined {
					return ((1 as unknown as number) - (amount as unknown as number));
					return undefined;
				}) }), reactLoose.createElement(SearchField, { value: luaProp(chapterBrowse, "query"), onChange: luaProp(chapterBrowse, "setQuery"), placeholder: "Search chapters", accent: luaProp(story, "Color"), reducedMotion: softMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, TapTarget), zIndex: 12 }), reactLoose.createElement(luaProp(Browse, "ChipRow"), { options: luaProp(chapterBrowse, "categories"), value: luaProp(chapterBrowse, "category"), onChange: luaProp(chapterBrowse, "setCategory"), counts: luaProp(chapterBrowse, "counts"), accent: luaProp(story, "Color"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((((20 as unknown as number) + (TapTarget as unknown as number)) as unknown as number) + (8 as unknown as number))), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, luaProp(Browse, "CHIP_H")) }), ((len(railChapters) === 0) && reactLoose.createElement(Text, { value: "No chapters match.", size: 13, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((railHeaderH as unknown as number) + (8 as unknown as number))), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) })), reactLoose.createElement(FlatList, { data: railChapters, itemHeight: CHAPTER_ROW_STRIDE, headerHeight: 0, overscan: (softMotion ? 0 : (luaProp(antilag, "constrained") ? 1 : 2)), canvasTail: 8, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-(railHeaderH as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, railHeaderH), scrollBarColor: luaProp(story, "Color"), scrollBarThickness: 3, keyExtractor: function(item?: unknown): unknown | undefined {
					return luaProp(luaProp(item, "chapter"), "Id");
					return undefined;
				}, renderItem: function(_param_1?: unknown): unknown | undefined {
					let item: unknown = luaProp(_param_1, "item");
					let index: unknown = luaProp(_param_1, "index");
					return reactLoose.createElement(ChapterRailRow, { chapter: luaProp(item, "chapter"), entry: luaProp(item, "entry"), selected: (luaProp(luaProp(item, "chapter"), "Id") === luaProp(status, "Id")), onSelect: function(): unknown | undefined {
						return luaCall(selectChapter, luaProp(luaProp(item, "chapter"), "Id"));
						return undefined;
					}, layoutOrder: index });
					return undefined;
				} }));
			}
			_condition_1 = reactLoose.createElement("frame", { Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, markH) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(railShare, (((-(railGap as unknown as number)) as unknown as number) / (2 as unknown as number)), 1, 0)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, _exp_2, _condition_2, (((!stack) && (!multi)) && reactLoose.createElement(ArchiveMark, { accent: luaProp(story, "Color"), active: started, reducedMotion: softMotion, beat: beat, total: len(luaProp(story, "Body")), compact: false, finished: finished, unlocked: luaProp(status, "Unlocked"), unlockProgress: unlockFill, unlockLabel: unlockLabel })));
		}
		let _exp_2: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) });
		let _exp_3: unknown = reactLoose.createElement("uistroke", { Color: luaProp(Palette, "lineSoft"), Thickness: 1, Transparency: 0.6 });
		let _exp_4: unknown = ((!stack) && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 2, 1, -32), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 16), BackgroundColor3: luaProp(story, "Color"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })));
		let _condition_2: unknown = (((!started) && multi) && stack);
		if (_condition_2) {
			let _attributes: unknown = { inset: 16, gap: 8, tailPad: 4, scrollBarColor: luaProp(story, "Color") };
			let _exp_5: unknown = { id: "archive-head", height: 26, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Badge, { value: "STORY", accent: luaProp(story, "Color"), filled: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 2), size: luaCall(luaProp(UDim2, "fromOffset"), 88, 24) }), reactLoose.createElement(Text, { value: `${claimedCount}/${chapterCount} archived  ·  ${unlockedCount} open`, size: 13, color: luaProp(story, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 100, 0, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -100, 0, 20) })) };
			let _exp_6: unknown = { id: "archive-title", height: 32, element: reactLoose.createElement(Text, { value: "Bay Seven", size: 22, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 32) }) };
			let archiveChapterCount: unknown = 0;
			for (const [_, chapter] of pairs((luaProp(chapterBrowse, "results")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(chapterConfig, config, luaProp(chapter, "Id")) !== undefined)) {
					archiveChapterCount = ((archiveChapterCount as unknown as number) + (1 as unknown as number));
				}
			}
			let _object: unknown = { id: "archive-chapters", fill: true, minHeight: 140, height: luaCall(luaProp(math, "max"), 140, ((((archiveChapterCount as unknown as number) * (CHAPTER_ROW_STRIDE as unknown as number)) as unknown as number) + (8 as unknown as number))) };
			let _left: unknown = "element";
			let _exp_7: unknown = reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) });
			let shownChapters: unknown = luaProp(chapterBrowse, "results");
			let _newValue: unknown = luaCall(luaProp(table, "create"), len(shownChapters));
			let _callback_1: unknown = function(chapter?: unknown, index?: unknown): unknown | undefined {
				let entry: unknown = luaCall(chapterConfig, config, luaProp(chapter, "Id"));
				if ((!entry)) {
					return undefined;
				}
				return reactLoose.createElement(ChapterRailRow, { key: luaProp(chapter, "Id"), chapter: chapter, entry: entry, selected: (luaProp(chapter, "Id") === luaProp(status, "Id")), onSelect: function(): unknown | undefined {
					return luaCall(selectChapter, luaProp(chapter, "Id"));
					return undefined;
				}, layoutOrder: index });
				return undefined;
			};
			for (const [_k, _v] of pairs((shownChapters) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), shownChapters));
			}
			luaSetIndex(_object, _left, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, _exp_7, _newValue, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 8), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 99 })));
			luaSet(_attributes, "sections", [_exp_5, _exp_6, { id: "archive-browse", height: luaCall(luaProp(Browse, "barHeight"), true, true), element: reactLoose.createElement(luaProp(Browse, "BrowseBar"), { browse: chapterBrowse, placeholder: "Search chapters", accent: luaProp(story, "Color"), stack: true, reducedMotion: softMotion, zIndex: 30 }) }, _object, { id: "archive-read", height: TapTarget, element: reactLoose.createElement(Button, { text: (locked ? "Locked" : (finished ? "Open selected" : "Read selected")), icon: "Story.4", onClick: begin, color: (locked ? luaProp(Palette, "panelSoft") : luaProp(story, "Color")), textColor: (locked ? luaProp(Palette, "muted") : luaProp(Palette, "ink")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: locked, reducedMotion: softMotion, highlight: (!locked) }) }]);
			_condition_2 = reactLoose.createElement(PageScaffold, _attributes);
		}
		let _exp_5: unknown = (((!started) && (((!multi) || (!stack)))) && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((readerPad as unknown as number) * (2 as unknown as number))) as unknown as number)), 1, (shortLandscape ? -16 : -36)), Position: colon(intro).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, ((readerPad as unknown as number) + (luaCall(luaProp(math, "floor"), (((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (12 as unknown as number))) as unknown as number)), 0, (shortLandscape ? 8 : 18));
			return undefined;
		}), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Badge, { value: (multi ? "CHAPTER" : "STORY"), accent: luaProp(story, "Color"), filled: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 2), size: luaCall(luaProp(UDim2, "fromOffset"), 110, 26) }), reactLoose.createElement(Text, { value: luaProp(story, "Chapter"), size: 13, color: luaProp(story, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), wrap: true, fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 120, 0, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -120, 0, 20) })), reactLoose.createElement(Text, { value: luaProp(story, "Title"), size: (shortLandscape ? 22 : (stack ? 22 : 34)), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (shortLandscape ? 34 : 40)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (shortLandscape ? -224 : 0), 0, (shortLandscape ? 34 : (stack ? 64 : 78))) }), ((!shortLandscape) && reactLoose.createElement(Text, { value: luaProp(story, "Summary"), size: (stack ? 14 : 16), color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 112 : 128)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (stack ? 96 : 80)) })), ((!shortLandscape) && reactLoose.createElement(Text, { value: (finished ? "Finished. Open it any time to read again." : (locked ? "Keep playing to unlock this chapter." : (multi ? "Pick a chapter, then start reading." : "Short chapters from under Bay Seven."))), size: 13, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 220 : 224)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) })), reactLoose.createElement(Button, { text: (locked ? "Locked" : (finished ? "Replay" : "Start reading")), icon: "Story.5", onClick: begin, color: (locked ? luaProp(Palette, "panelSoft") : luaProp(story, "Color")), textColor: (locked ? luaProp(Palette, "muted") : luaProp(Palette, "ink")), size: (shortLandscape ? luaCall(luaProp(UDim2, "fromOffset"), 210, TapTarget) : (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0, 52))), position: (shortLandscape ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -210, 1, (-(TapTarget as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(((stack ? ((TapTarget as unknown as number) + (4 as unknown as number)) : 56)) as unknown as number)))), disabled: locked, reducedMotion: softMotion, highlight: (!locked) })));
		let _condition_3: unknown = started;
		if (_condition_3) {
			let _attributes: unknown = { key: `${luaProp(story, "Id")}:${beat}:${(finished ? "replay" : "live")}` };
			let body: unknown = luaProp(story, "Body");
			if ((!luaTypeIs(body, "table"))) {
				body = {};
			}
			let _condition_4: unknown = luaIndex(body, ((beat as unknown as number) + (1 as unknown as number)));
			if ((_condition_4 === undefined)) {
				_condition_4 = "";
			}
			luaSet(_attributes, "text", _condition_4);
			luaSet(_attributes, "index", beat);
			luaSet(_attributes, "total", luaCall(luaProp(math, "max"), 1, len(body)));
			luaSet(_attributes, "color", luaProp(story, "Color"));
			luaSet(_attributes, "reducedMotion", softMotion);
			luaSet(_attributes, "claimed", luaProp(status, "Claimed"));
			luaSet(_attributes, "reward", luaCall(formatReward, luaProp(story, "Reward")));
			luaSet(_attributes, "replay", finished);
			luaSet(_attributes, "onBack", rewind);
			luaSet(_attributes, "onNext", advance);
			luaSet(_attributes, "onClaim", function(): unknown | undefined {
				colon(ClientLog).debug("story", `claim ${luaProp(story, "Id")}`);
				luaCall(dispatch, "ClaimStoryChapter", { Id: luaProp(story, "Id") });
				return undefined;
			});
			luaSet(_attributes, "onClose", closeReplay);
			luaSet(_attributes, "stack", stack);
			luaSet(_attributes, "condensed", ((((luaProp(viewport, "height") as unknown as number) < (620 as unknown as number)) || luaProp(viewport, "keyboardOpen")) || luaProp(chrome, "landscape")));
			_condition_3 = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((readerPad as unknown as number) * (2 as unknown as number))) as unknown as number)), 1, (-(((stack ? 20 : 32)) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), readerPad, (stack ? 10 : 16)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement(StoryBeat, _attributes));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, ClipsDescendants: true }, _exp, _exp_1, _condition, _condition_1, reactLoose.createElement("frame", { Size: (readingMobile ? luaCall(luaProp(UDim2, "fromScale"), 1, 1) : ((stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-((((markH as unknown as number) + (6 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) - (railShare as unknown as number)), (((-(railGap as unknown as number)) as unknown as number) / (2 as unknown as number)), 1, 0)))), Position: (readingMobile ? luaCall(luaProp(UDim2, "fromOffset"), 0, 0) : ((stack ? luaCall(luaProp(UDim2, "fromOffset"), 0, ((markH as unknown as number) + (6 as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(railShare, ((railGap as unknown as number) / (2 as unknown as number)), 0, 0)))), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ClipsDescendants: true }, _exp_2, _exp_3, _exp_4, _condition_2, _exp_5, _condition_3));
		return undefined;
	}
	return { StoryView: StoryView };
	return undefined;
}
export = __member();
