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

const AstralForge = script.Parent!.Parent!;

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

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit !== undefined) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`PagesSystem: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`PagesSystem: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def) as LuaTuple<[unknown, unknown]>;
	delete __loading[name];
	if (ok !== true) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

__defs["SettingsView"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let MobileControls: unknown = luaProp(kit("UiOverlays", "MobileControls"), "MobileControls");
	let _mobileLayout: unknown = kit("CoreKit", "mobileLayout");
	let fitTouchGridWidth: unknown = luaProp(_mobileLayout, "fitTouchGridWidth");
	let moreDockHeight: unknown = luaProp(_mobileLayout, "moreDockHeight");
	let _motion: unknown = kit("MotionKit", "motion");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let darken: unknown = luaProp(_theme, "darken");
	let Palette: unknown = luaProp(_theme, "Palette");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let Slider: unknown = luaProp(_ui, "Slider");
	let SegmentedTabs: unknown = luaProp(_ui, "SegmentedTabs");
	let Text: unknown = luaProp(_ui, "Text");
	let Schema: unknown = luaCall(luaRequire(colon(colon(colon(ReplicatedStorage).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("SharedData")), "SettingsSchema");
	let Browse: unknown = mod("BrowseKit");
	let ROW_H: unknown = 60;
	let ROW_H_STACK: unknown = 110;
	let NAV_W: unknown = 196;
	let MOBILE_DOCK_DESTINATIONS: unknown = ["Overview", "Workshop", "Inventory", "Research", "Shop", "Settings"];
	function accentOf(section?: unknown): unknown | undefined {
		return (luaIndex(Palette, luaProp(section, "accent")) || luaProp(Palette, "cyan"));
		return undefined;
	}
	let SECTION_BY_ID: unknown = {};
	for (const [_, section] of pairs((luaProp(Schema, "SECTIONS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSetIndex(SECTION_BY_ID, luaProp(section, "id"), section);
	}
	// The forge switch. One spring drives everything, so the track colour, halo, knob stretch and
	// glyph all move together instead of snapping: the knob stretches like jelly mid-travel and
	// settles with a small overshoot, the track fills with the section colour, a dot lights inside
	// the knob when on. Hover brightens the edge; pressing squeezes the knob.
	const _init1 = 58;
	const _init2 = 30;
	const _init3 = 22;
	const _init4 = 4;
	let SWITCH_W: unknown = _init1;
	let SWITCH_H: unknown = _init2;
	let SWITCH_KNOB: unknown = _init3;
	let SWITCH_PAD: unknown = _init4;
	function Switch(_param?: unknown): unknown | undefined {
		let on: unknown = luaProp(_param, "on");
		let accent: unknown = luaProp(_param, "accent");
		let softMotion: unknown = luaProp(_param, "softMotion");
		let amount: unknown = luaCall(useFlipperSpring, (on ? 1 : 0), softMotion, 380, 24);
		let hovered: unknown;
		let setHovered: unknown;
		[hovered, setHovered] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let pressed: unknown;
		let setPressed: unknown;
		[pressed, setPressed] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let hover: unknown = luaCall(useFlipperSpring, (hovered ? 1 : 0), softMotion, 700, 40);
		let press: unknown = luaCall(useFlipperSpring, (pressed ? 1 : 0), softMotion, 1000, 42);
		let anchor: unknown = (luaProp(_param, "anchorPoint") || luaProp(Vector2, "zero"));
		let trackX: unknown = (((luaProp(anchor, "X") as unknown as number) >= (0.5 as unknown as number)) ? 1 : 0);
		let motion: unknown = luaCall(luaProp(React, "joinBindings"), [amount, press]);
		let travel: unknown = ((((SWITCH_W as unknown as number) - (((SWITCH_PAD as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (SWITCH_KNOB as unknown as number));
		function settle(a?: unknown): unknown | undefined {
			return luaCall(luaProp(math, "clamp"), a, 0, 1);
			return undefined;
		}
		return reactLoose.createElement("textbutton", { Size: luaCall(luaProp(UDim2, "fromOffset"), ((SWITCH_W as unknown as number) + (10 as unknown as number)), TapTarget), Position: luaProp(_param, "position"), AnchorPoint: anchor, BackgroundTransparency: 1, AutoButtonColor: false, BorderSizePixel: 0, Text: "", Selectable: true, Event: { Activated: function(): unknown | undefined {
			colon(Audio).play((on ? "toggleOff" : "toggleOn"));
			luaCall(luaProp(_param, "onToggle"));
			return undefined;
		}, MouseEnter: function(): unknown | undefined {
			luaCall(setHovered, true);
			return undefined;
		}, MouseLeave: function(): unknown | undefined {
			luaCall(setHovered, false);
			luaCall(setPressed, false);
			return undefined;
		}, SelectionGained: function(): unknown | undefined {
			luaCall(setHovered, true);
			return undefined;
		}, SelectionLost: function(): unknown | undefined {
			luaCall(setHovered, false);
			return undefined;
		}, MouseButton1Down: function(): unknown | undefined {
			luaCall(setPressed, true);
			return undefined;
		}, MouseButton1Up: function(): unknown | undefined {
			luaCall(setPressed, false);
			return undefined;
		} } }, reactLoose.createElement("frame", { Name: "Halo", Size: luaCall(luaProp(UDim2, "fromOffset"), ((SWITCH_W as unknown as number) + (8 as unknown as number)), ((SWITCH_H as unknown as number) + (8 as unknown as number))), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(trackX, ((trackX === 1) ? 4 : -4), 0.5, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(trackX, 0.5), BackgroundColor3: accent, BackgroundTransparency: colon(amount).map(function(a?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((0.16 as unknown as number) * (luaCall(settle, a) as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })), reactLoose.createElement("frame", { Name: "Track", Size: luaCall(luaProp(UDim2, "fromOffset"), SWITCH_W, SWITCH_H), Position: luaCall(luaProp(UDim2, "fromScale"), trackX, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(trackX, 0.5), BackgroundColor3: colon(amount).map(function(a?: unknown): unknown | undefined {
			return colon(luaProp(Palette, "graphite")).Lerp(accent, luaCall(settle, a));
			return undefined;
		}), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Rotation: 90, Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 0), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 0.18)]) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), Color: colon(amount).map(function(a?: unknown): unknown | undefined {
			return colon(luaProp(Palette, "lineSoft")).Lerp(accent, luaCall(settle, a));
			return undefined;
		}), Transparency: colon(hover).map(function(h?: unknown): unknown | undefined {
			return ((0.4 as unknown as number) - (((0.32 as unknown as number) * (luaCall(luaProp(math, "clamp"), h, 0, 1) as unknown as number)) as unknown as number));
			return undefined;
		}), Thickness: 1 }), reactLoose.createElement("frame", { Name: "Knob", Size: colon(motion).map(function(values?: unknown): unknown | undefined {
			const _init5 = luaIndex(values, 1);
			const _init6 = luaCall(luaProp(math, "clamp"), luaIndex(values, 2), 0, 1);
			let a: unknown = _init5;
			let p: unknown = _init6;
			let stretch: unknown = ((luaCall(luaProp(math, "sin"), ((luaProp(math, "pi") as unknown as number) * (luaCall(settle, a) as unknown as number))) as unknown as number) * (9 as unknown as number));
			return luaCall(luaProp(UDim2, "fromOffset"), ((((SWITCH_KNOB as unknown as number) + (stretch as unknown as number)) as unknown as number) + (((p as unknown as number) * (5 as unknown as number)) as unknown as number)), ((SWITCH_KNOB as unknown as number) - (((p as unknown as number) * (3 as unknown as number)) as unknown as number)));
			return undefined;
		}), Position: colon(amount).map(function(a?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, ((((SWITCH_PAD as unknown as number) + (((SWITCH_KNOB as unknown as number) / (2 as unknown as number)) as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "clamp"), a, -0.08, 1.08) as unknown as number) * (travel as unknown as number)) as unknown as number)), 0.5, 0);
			return undefined;
		}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: colon(amount).map(function(a?: unknown): unknown | undefined {
			return colon(luaProp(Palette, "creamSoft")).Lerp(luaProp(Palette, "cream"), luaCall(settle, a));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 2 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("frame", { Name: "Off", Size: luaCall(luaProp(UDim2, "fromOffset"), 8, 2), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "graphite"), BackgroundTransparency: colon(amount).map(function(a?: unknown): unknown | undefined {
			return ((0.25 as unknown as number) + (((0.75 as unknown as number) * (luaCall(settle, a) as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 3 }), reactLoose.createElement("frame", { Name: "On", Size: colon(amount).map(function(a?: unknown): unknown | undefined {
			let d: unknown = ((4 as unknown as number) + (((4 as unknown as number) * (luaCall(settle, a) as unknown as number)) as unknown as number));
			return luaCall(luaProp(UDim2, "fromOffset"), d, d);
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: accent, BackgroundTransparency: colon(amount).map(function(a?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (luaCall(settle, a) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 3 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })))));
		return undefined;
	}
	// Several fixed options: the shared segmented control, whose highlight slides between choices.
	function Choice(_param?: unknown): unknown | undefined {
		let choices: unknown = luaProp(_param, "choices");
		let value: unknown = luaProp(_param, "value");
		let options: unknown = {};
		let picked: unknown = undefined;
		for (const [index, option] of pairs((choices) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let id: unknown = luaCall(tostring, index);
			luaTable.insert(options, { id: id, label: luaProp(option, "label") });
			if (((luaCall(luaProp(math, "abs"), ((luaProp(option, "value") as unknown as number) - (value as unknown as number))) as unknown as number) < (0.02 as unknown as number))) {
				picked = id;
			}
		}
		return reactLoose.createElement("frame", { Size: luaProp(_param, "size"), Position: luaProp(_param, "position"), AnchorPoint: luaProp(_param, "anchorPoint"), BackgroundTransparency: 1 }, reactLoose.createElement(SegmentedTabs, { options: options, value: picked, accent: luaProp(_param, "accent"), gap: 4, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: luaProp(_param, "softMotion"), onChange: function(id?: unknown): unknown | undefined {
			let option: unknown = luaIndex(choices, (luaCall(tonumber, id) || 0));
			if (((option !== undefined) && (id !== picked))) {
				luaCall(luaProp(_param, "onPick"), luaProp(option, "value"));
			}
			return undefined;
		} }));
		return undefined;
	}
	function SettingRow(_param?: unknown): unknown | undefined {
		let entry: unknown = luaProp(_param, "entry");
		let saved: unknown = luaProp(_param, "value");
		let accent: unknown = luaProp(_param, "accent");
		let stack: unknown = luaProp(_param, "stack");
		let softMotion: unknown = luaProp(_param, "softMotion");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let draft: unknown;
		let setDraft: unknown;
		[draft, setDraft] = reactLoose.useState(saved) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(): unknown | undefined {
			luaCall(setDraft, saved);
			return undefined;
		}, [saved]);
		let commit: unknown = function(value?: unknown): unknown | undefined {
			luaCall(setDraft, value);
			luaCall(dispatch, "SetSetting", { Key: luaProp(entry, "key"), Value: value });
			return undefined;
		};
		let controlW: unknown = ((luaProp(entry, "kind") === "toggle") ? 68 : ((luaProp(entry, "kind") === "choice") ? luaCall(luaProp(math, "min"), 260, ((64 as unknown as number) * (len(((luaProp(entry, "choices") || {}))) as unknown as number))) : 240));
		let textRight: unknown = (stack ? 0 : ((controlW as unknown as number) + (20 as unknown as number)));
		let control: unknown;
		if ((luaProp(entry, "kind") === "toggle")) {
			control = reactLoose.createElement(Switch, { on: ((draft as unknown as number) >= (0.5 as unknown as number)), accent: accent, softMotion: softMotion, position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (2 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.5, 0)), anchorPoint: (stack ? new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0) : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5)), onToggle: function(): unknown | undefined {
				luaCall(commit, (((draft as unknown as number) >= (0.5 as unknown as number)) ? 0 : 1));
				return undefined;
			} });
		} else if ((luaProp(entry, "kind") === "choice")) {
			control = reactLoose.createElement(Choice, { choices: luaProp(entry, "choices"), value: draft, accent: accent, size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), controlW, TapTarget)), position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (2 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.5, 0)), anchorPoint: (stack ? new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0) : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5)), onPick: commit, softMotion: softMotion });
		} else {
			control = reactLoose.createElement("frame", { Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), controlW, 32)), Position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(TapTarget as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.5, 0)), AnchorPoint: (stack ? new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0) : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5)), BackgroundTransparency: 1 }, reactLoose.createElement(Slider, { value: draft, accent: accent, reducedMotion: softMotion, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -52, 1, 0), onChange: setDraft, onCommit: function(value?: unknown): unknown | undefined {
				luaCall(commit, value);
				return undefined;
			} }), reactLoose.createElement(Text, { value: `${luaCall(luaProp(math, "floor"), ((((draft as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)))}%`, size: 13, color: luaProp(Palette, "creamSoft"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -46, 0, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 46, 1, 0) }));
		}
		return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (stack ? ROW_H_STACK : ROW_H)), LayoutOrder: luaProp(_param, "layoutOrder"), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Text, { value: ((luaProp(_param, "tag") !== undefined) ? `${luaProp(entry, "label")}  ·  ${luaProp(_param, "tag")}` : luaProp(entry, "label")), size: 15, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 8 : 11)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(textRight as unknown as number)), 0, 20) }), reactLoose.createElement(Text, { value: luaProp(entry, "help"), size: 12, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 29 : 32)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(textRight as unknown as number)), 0, 16) }), control, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 1), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0), BackgroundColor3: luaProp(Palette, "lineSoft"), BackgroundTransparency: 0.75, BorderSizePixel: 0 }));
		return undefined;
	}
	function SectionButton(_param?: unknown): unknown | undefined {
		let section: unknown = luaProp(_param, "section");
		let active: unknown = luaProp(_param, "active");
		let accent: unknown = luaCall(accentOf, section);
		return reactLoose.createElement("frame", { Size: luaProp(_param, "size"), LayoutOrder: luaProp(_param, "layoutOrder"), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Button, { text: "", size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), color: (active ? luaCall(darken, accent, 0.62) : luaProp(Palette, "panelSoft")), highlight: active, reducedMotion: luaProp(_param, "softMotion"), sound: (active ? false : "tabSwitch"), onClick: function(): unknown | undefined {
			if ((!active)) {
				luaCall(luaProp(_param, "onPick"), luaProp(section, "id"));
			}
			return undefined;
		}, children: reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, ZIndex: 11 }, reactLoose.createElement(Icon, { kind: luaProp(section, "icon"), color: (active ? accent : luaProp(Palette, "muted")), accent: accent, size: 18, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, (luaProp(_param, "compact") ? 10 : 14), 0.5, -9) }), reactLoose.createElement(Text, { value: luaProp(section, "label"), size: 14, color: (active ? luaProp(Palette, "cream") : luaProp(Palette, "creamSoft")), weight: (active ? luaProp(luaProp(Enum, "FontWeight"), "Heavy") : luaProp(luaProp(Enum, "FontWeight"), "Bold")), fit: (luaProp(_param, "compact") === true), minSize: 10, position: luaCall(luaProp(UDim2, "fromOffset"), (luaProp(_param, "compact") ? 34 : 40), 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaProp(_param, "compact") ? -38 : -70), 1, 0), zIndex: 11 }), ((!luaProp(_param, "compact")) && reactLoose.createElement(Text, { value: luaCall(tostring, luaProp(_param, "count")), size: 12, color: luaProp(Palette, "muted"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -36, 0, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 26, 1, 0), zIndex: 11 })))) }));
		return undefined;
	}
	function SettingsView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let stack: unknown = luaProp(chrome, "contentStack");
		let touch: unknown = ((!luaProp(viewport, "desktop")) && luaProp(UserInputService, "TouchEnabled"));
		let mobileHudAvailable: unknown = (touch && luaProp(chrome, "stack"));
		let settings: unknown = (luaProp(state, "Settings") || {});
		let activeSection: unknown;
		let setActiveSection: unknown;
		[activeSection, setActiveSection] = reactLoose.useState("sound") as LuaTuple<[unknown, unknown]>;
		let query: unknown;
		let setQuery: unknown;
		[query, setQuery] = luaCall(luaProp(Browse, "useLinkedQuery"), "Settings") as LuaTuple<[unknown, unknown]>;
		let changedOnly: unknown;
		let setChangedOnly: unknown;
		[changedOnly, setChangedOnly] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let advancedOpen: unknown;
		let setAdvancedOpen: unknown;
		[advancedOpen, setAdvancedOpen] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let mobileEdit: unknown;
		let setMobileEdit: unknown;
		[mobileEdit, setMobileEdit] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let reveal: unknown = luaCall(useStagger, 0, softMotion);
		let sections: unknown = {};
		for (const [_, section] of pairs((luaProp(Schema, "SECTIONS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (((!luaProp(section, "touchOnly")) || mobileHudAvailable)) {
				luaTable.insert(sections, section);
			}
		}
		reactLoose.useEffect(function(): unknown | undefined {
			let sectionInfo: unknown = luaIndex(SECTION_BY_ID, activeSection);
			if (((sectionInfo && luaProp(sectionInfo, "touchOnly")) && (!mobileHudAvailable))) {
				luaCall(setActiveSection, "interface");
			}
			return undefined;
		}, [activeSection, mobileHudAvailable]);
		let section: unknown = (luaIndex(SECTION_BY_ID, activeSection) || luaIndex(SECTION_BY_ID, "interface"));
		let accent: unknown = luaCall(accentOf, section);
		let settingsClaimHostRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!luaProp(UserInputService, "GamepadEnabled"))) {
				return undefined;
			}
			let host: unknown = luaProp(settingsClaimHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let job: unknown = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
				if ((luaProp(host, "Parent") !== undefined)) {
					luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				}
				return undefined;
			});
			return function(): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, [activeSection]);
		let searching: unknown = (!luaCall(luaProp(string, "match"), query, "^%s*$"));
		function isChanged(entry?: unknown): unknown | undefined {
			let current: unknown = luaCall(luaProp(Schema, "value"), settings, luaProp(entry, "key"));
			let defaultValue: unknown = luaProp(entry, "default");
			if (((typeOf(current) === "number") && (typeOf(defaultValue) === "number"))) {
				return ((luaCall(luaProp(math, "abs"), ((current as unknown as number) - (defaultValue as unknown as number))) as unknown as number) > (0.01 as unknown as number));
			}
			return (luaCall(tostring, current) !== luaCall(tostring, defaultValue));
			return undefined;
		}
		let changedEntries: unknown = {};
		for (const [_, entry] of pairs((luaProp(Schema, "ENTRIES")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let home: unknown = luaIndex(SECTION_BY_ID, luaProp(entry, "section"));
			if ((!home)) {
				continue;
			}
			if (((!((luaProp(home, "touchOnly") && (!mobileHudAvailable)))) && luaCall(isChanged, entry))) {
				luaTable.insert(changedEntries, entry);
			}
		}
		let showChanged: unknown = (changedOnly && (!searching));
		let listing: unknown = (searching || showChanged);
		let rows: unknown = {};
		let hiddenAdvanced: unknown = 0;
		for (const [_, entry] of pairs((luaProp(Schema, "ENTRIES")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let home: unknown = luaIndex(SECTION_BY_ID, luaProp(entry, "section"));
			if (((!home) || ((luaProp(home, "touchOnly") && (!mobileHudAvailable))))) {
				continue;
			}
			if (searching) {
				if (luaCall(luaProp(Browse, "matches"), query, luaProp(entry, "label"), luaProp(entry, "help"), luaProp(home, "label"), luaProp(entry, "key"))) {
					luaTable.insert(rows, entry);
				}
			} else if (showChanged) {
				if (luaCall(isChanged, entry)) {
					luaTable.insert(rows, entry);
				}
			} else if ((luaProp(entry, "section") === activeSection)) {
				if ((luaProp(entry, "advanced") && (!luaIndex(advancedOpen, activeSection)))) {
					hiddenAdvanced = ((hiddenAdvanced as unknown as number) + (1 as unknown as number));
				} else {
					luaTable.insert(rows, entry);
				}
			}
		}
		let counts: unknown = {};
		for (const [_, entry] of pairs((luaProp(Schema, "ENTRIES")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(counts, luaProp(entry, "section"), ((((luaIndex(counts, luaProp(entry, "section")) || 0)) as unknown as number) + (1 as unknown as number)));
		}
		let preset: unknown = luaCall(luaProp(Schema, "matchingPreset"), settings);
		let applyPreset: unknown = function(entry?: unknown): unknown | undefined {
			luaCall(dispatch, "SetSetting", { Values: luaProp(entry, "values"), Label: luaProp(entry, "notice") });
			return undefined;
		};
		let resetSection: unknown = function(): unknown | undefined {
			luaCall(dispatch, "SetSetting", { Values: luaCall(luaProp(Schema, "sectionDefaults"), activeSection), Label: `${luaProp(section, "label")} settings reset.` });
			return undefined;
		};
		let quickScale: unknown = luaCall(luaProp(Schema, "value"), settings, "MobileQuickScale");
		let dockScale: unknown = luaCall(luaProp(Schema, "value"), settings, "MobileDockScale");
		let toastScale: unknown = luaCall(luaProp(Schema, "value"), settings, "MobileToastScale");
		let hudSafeTop: unknown = ((((luaProp(viewport, "topInset") as unknown as number) + (luaProp(chrome, "topbarRows") as unknown as number)) as unknown as number) + (12 as unknown as number));
		let densityScale: unknown = ((0.82 as unknown as number) + (((luaCall(luaProp(Schema, "value"), settings, "UiDensity") as unknown as number) * (0.36 as unknown as number)) as unknown as number));
		let hudEdgePad: unknown = luaCall(luaProp(math, "max"), 8, luaCall(luaProp(math, "floor"), ((luaProp(chrome, "pagePadding") as unknown as number) * (densityScale as unknown as number))));
		let dockGap: unknown = (luaProp(chrome, "landscape") ? 3 : ((3 as unknown as number) + (luaCall(luaProp(math, "floor"), ((luaCall(luaProp(Schema, "value"), settings, "MobileButtonSpacing") as unknown as number) * (5 as unknown as number))) as unknown as number)));
		let touchTargetFloor: unknown = (((luaCall(luaProp(Schema, "value"), settings, "LargeTouchTargets") as unknown as number) >= (0.5 as unknown as number)) ? ((TapTarget as unknown as number) + (6 as unknown as number)) : TapTarget);
		let dockCellH: unknown = luaCall(luaProp(math, "max"), touchTargetFloor, luaCall(luaProp(math, "floor"), ((luaProp(chrome, "moreCellH") as unknown as number) * ((((0.88 as unknown as number) + (((dockScale as unknown as number) * (0.16 as unknown as number)) as unknown as number))) as unknown as number))));
		let quickWidth: unknown = luaCall(luaProp(math, "max"), 200, (((((luaProp(viewport, "width") as unknown as number) - (((luaCall(luaProp(math, "max"), hudEdgePad, luaProp(chrome, "sideSafe")) as unknown as number) * (2 as unknown as number)) as unknown as number))) as unknown as number) * ((((0.72 as unknown as number) + (((quickScale as unknown as number) * (0.28 as unknown as number)) as unknown as number))) as unknown as number)));
		let quickHeight: unknown = luaCall(luaProp(math, "max"), ((TapTarget as unknown as number) + (8 as unknown as number)), luaCall(luaProp(math, "floor"), ((luaProp(chrome, "quickBarH") as unknown as number) * ((((0.86 as unknown as number) + (((quickScale as unknown as number) * (0.22 as unknown as number)) as unknown as number))) as unknown as number))));
		let dockWidth: unknown = luaCall(fitTouchGridWidth, luaProp(viewport, "width"), hudEdgePad, luaProp(chrome, "sideSafe"), luaProp(chrome, "moreCols"), dockGap, ((0.72 as unknown as number) + (((dockScale as unknown as number) * (0.28 as unknown as number)) as unknown as number)));
		let dockCount: unknown = 0;
		for (const [_, id] of pairs((MOBILE_DOCK_DESTINATIONS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let unlock: unknown = (luaProp(state, "FeatureUnlocks") && luaIndex(luaProp(state, "FeatureUnlocks"), id));
			if ((!(((unlock !== undefined) && (luaProp(unlock, "Unlocked") === false))))) {
				dockCount = ((dockCount as unknown as number) + (1 as unknown as number));
			}
		}
		let dockHeight: unknown = luaCall(moreDockHeight, true, luaCall(luaProp(math, "max"), 1, dockCount), luaProp(chrome, "moreCols"), dockCellH, dockGap);
		let toastWidth: unknown = ((luaCall(luaProp(math, "min"), 220, luaCall(luaProp(math, "max"), 180, ((luaProp(viewport, "width") as unknown as number) - (48 as unknown as number)))) as unknown as number) * ((((0.8 as unknown as number) + (((toastScale as unknown as number) * (0.2 as unknown as number)) as unknown as number))) as unknown as number));
		let toastHeight: unknown = ((2 as unknown as number) * ((((48 as unknown as number) + (4 as unknown as number))) as unknown as number));
		let mobileSlots: unknown = reactLoose.useMemo(function(): unknown | undefined {
			let slots: unknown = {};
			function slot(id?: unknown, label?: unknown, xKey?: unknown, yKey?: unknown, dx?: unknown, dy?: unknown, width?: unknown, height?: unknown, anchorY?: unknown): unknown | undefined {
				luaTable.insert(slots, { id: id, label: label, xKey: xKey, yKey: yKey, x: (luaIndex(settings, xKey) || dx), y: (luaIndex(settings, yKey) || dy), defaultX: dx, defaultY: dy, width: luaCall(luaProp(math, "floor"), width), height: luaCall(luaProp(math, "floor"), height), anchorY: anchorY, safeTop: hudSafeTop });
				return undefined;
			}
			if (((luaProp(chrome, "quickBarH") as unknown as number) > (0 as unknown as number))) {
				luaCall(slot, "quick", "QUICK ACTIONS", "MobileQuickX", "MobileQuickY", 0.5, 0.70, quickWidth, quickHeight);
			}
			if (((luaProp(chrome, "stack") && ((luaProp(viewport, "height") as unknown as number) >= (480 as unknown as number))) && ((luaProp(chrome, "quickBarH") as unknown as number) > (0 as unknown as number)))) {
				luaCall(slot, "dock", "NAVIGATION", "MobileDockX", "MobileDockY", 0.5, 0.92, dockWidth, dockHeight);
			}
			luaCall(slot, "toasts", "NOTIFICATIONS", "MobileToastX", "MobileToastY", 0.84, 0.27, toastWidth, toastHeight, 0);
			return slots;
			return undefined;
		}, [luaProp(chrome, "quickBarH"), luaProp(chrome, "stack"), dockHeight, dockWidth, hudSafeTop, quickHeight, quickWidth, luaProp(settings, "MobileDockX"), luaProp(settings, "MobileDockY"), luaProp(settings, "MobileQuickX"), luaProp(settings, "MobileQuickY"), luaProp(settings, "MobileToastX"), luaProp(settings, "MobileToastY"), toastHeight, toastWidth, luaProp(viewport, "height")]);
		// Desktop keeps search and the view chips on one row beside each other; phones stack them.
		let searchH: unknown = (stack ? TapTarget : 40);
		let actionsY: unknown = 56;
		let searchY: unknown = (stack ? ((((actionsY as unknown as number) + (40 as unknown as number)) as unknown as number) + (10 as unknown as number)) : 60);
		let chipsX: unknown = (stack ? 0 : 356);
		let chipsY: unknown = (stack ? ((((searchY as unknown as number) + (searchH as unknown as number)) as unknown as number) + (8 as unknown as number)) : ((searchY as unknown as number) + (luaCall(luaProp(math, "floor"), (((((searchH as unknown as number) - (luaProp(Browse, "CHIP_H") as unknown as number))) as unknown as number) / (2 as unknown as number))) as unknown as number)));
		let headerH: unknown = ((((stack ? ((chipsY as unknown as number) + (luaProp(Browse, "CHIP_H") as unknown as number)) : ((searchY as unknown as number) + (luaCall(luaProp(math, "max"), searchH, luaProp(Browse, "CHIP_H")) as unknown as number)))) as unknown as number) + (32 as unknown as number));
		let header: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: accent, background: luaProp(Palette, "panelRaised"), padding: 16, reveal: reveal, reducedMotion: softMotion, clips: false }, reactLoose.createElement(Text, { value: "Settings", size: (stack ? 22 : 26), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 16, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? 0 : -340), 0, 30) }), reactLoose.createElement(Text, { value: `Saved to your profile automatically  ·  v${luaProp(luaProp(state, "Game"), "Version")}`, size: 12, color: luaProp(Palette, "muted"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? 0 : -340), 0, 16) }), reactLoose.createElement("frame", { Name: "SettingsClaimActions", Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) : luaCall(luaProp(UDim2, "fromOffset"), 320, 40)), Position: (stack ? luaCall(luaProp(UDim2, "fromOffset"), 0, actionsY) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -320, 0, 0)), BackgroundTransparency: 1, ClipsDescendants: false, ZIndex: 6, ref: settingsClaimHostRef }, reactLoose.createElement(Button, { text: "REPLAY TOUR", icon: "Guide.1", onClick: function(): unknown | undefined {
			luaCall(dispatch, "ReplayTutorial");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 1, 0), reducedMotion: softMotion }), reactLoose.createElement(Button, { text: "PATCH NOTES", icon: "Gift.14", onClick: function(): unknown | undefined {
			luaCall(dispatch, "OpenRelease");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 0, 0), reducedMotion: softMotion })), reactLoose.createElement(SearchField, { value: query, onChange: setQuery, placeholder: "Search settings", accent: accent, size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, searchH) : luaCall(luaProp(UDim2, "fromOffset"), 340, searchH)), position: luaCall(luaProp(UDim2, "fromOffset"), 0, searchY), reducedMotion: softMotion }), reactLoose.createElement(luaProp(Browse, "ChipRow"), { options: [{ id: "sections", label: "By section", icon: "Settings.2" }, { id: "changed", label: "Changed from default", icon: "Refresh.4" }], value: (changedOnly ? "changed" : "sections"), counts: { changed: len(changedEntries) }, onChange: function(id?: unknown): unknown | undefined {
			if ((id === "changed")) {
				luaCall(setQuery, "");
			}
			colon(Audio).play("tabSwitch");
			luaCall(setChangedOnly, (id === "changed"));
			return undefined;
		}, accent: accent, position: luaCall(luaProp(UDim2, "fromOffset"), chipsX, chipsY), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(chipsX as unknown as number)), 0, luaProp(Browse, "CHIP_H")) }));
		let navButtons: unknown = { layout: reactLoose.createElement("uilistlayout", { FillDirection: (stack ? luaProp(luaProp(Enum, "FillDirection"), "Horizontal") : luaProp(luaProp(Enum, "FillDirection"), "Vertical")), Wraps: stack, Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }) };
		let chipW: unknown = (stack ? luaCall(luaProp(math, "floor"), (((((((((luaProp(viewport, "width") as unknown as number) - (((luaProp(chrome, "pagePadding") as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (24 as unknown as number)) as unknown as number) - (12 as unknown as number))) as unknown as number) / (3 as unknown as number))) : ((NAV_W as unknown as number) - (16 as unknown as number)));
		for (const [index, entry] of pairs((sections) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(navButtons, luaProp(entry, "id"), reactLoose.createElement(SectionButton, { section: entry, active: ((!listing) && (luaProp(entry, "id") === activeSection)), count: (luaIndex(counts, luaProp(entry, "id")) || 0), compact: stack, size: luaCall(luaProp(UDim2, "fromOffset"), chipW, (stack ? TapTarget : 42)), layoutOrder: index, softMotion: softMotion, onPick: function(id?: unknown): unknown | undefined {
				luaCall(setQuery, "");
				luaCall(setChangedOnly, false);
				luaCall(setActiveSection, id);
				return undefined;
			} }));
		}
		let navRows: unknown = (stack ? luaCall(luaProp(math, "ceil"), ((len(sections) as unknown as number) / (3 as unknown as number))) : len(sections));
		let navH: unknown = (stack ? ((((navRows as unknown as number) * ((((TapTarget as unknown as number) + (6 as unknown as number))) as unknown as number)) as unknown as number) + (12 as unknown as number)) : ((((len(sections) as unknown as number) * (48 as unknown as number)) as unknown as number) + (16 as unknown as number)));
		let listChildren: unknown = { layout: reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 0) }) };
		let rowH: unknown = (stack ? ROW_H_STACK : ROW_H);
		let listH: unknown = 0;
		let order: unknown = 0;
		function add(key?: unknown, element?: unknown, height?: unknown): unknown | undefined {
			order = ((order as unknown as number) + (1 as unknown as number));
			luaSetIndex(listChildren, key, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), LayoutOrder: order, BackgroundTransparency: 1 }, element));
			listH = ((listH as unknown as number) + (height as unknown as number));
			return undefined;
		}
		luaCall(add, "title", reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: (searching ? `${len(rows)} result${((len(rows) === 1) ? "" : "s")} for "${query}"` : (showChanged ? `${len(rows)} changed setting${((len(rows) === 1) ? "" : "s")}` : luaProp(section, "label"))), size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -110, 0, 24) }), reactLoose.createElement(Text, { value: (searching ? "From every section." : (showChanged ? "Everything you set differently from the defaults." : luaProp(section, "blurb"))), size: 12, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -110, 0, 16) }), ((((!searching) || showChanged)) && reactLoose.createElement(Button, { text: (showChanged ? "RESET ALL" : "RESET"), icon: "Refresh.5", onClick: (showChanged ? function(): unknown | undefined {
			let values: unknown = {};
			for (const [_, entry] of pairs((changedEntries) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(values, luaProp(entry, "key"), luaProp(entry, "default"));
			}
			luaCall(dispatch, "SetSetting", { Values: values, Label: "Settings back to defaults." });
			return undefined;
		} : resetSection), color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromOffset"), 100, 34), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -100, 0, 4), reducedMotion: softMotion }))), 56);
		if (((!listing) && (activeSection === "display"))) {
			let presetCells: unknown = {};
			for (const [index, entry] of pairs((luaProp(Schema, "PRESETS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(presetCells, luaProp(entry, "id"), reactLoose.createElement(Button, { text: luaCall(luaProp(string, "upper"), luaProp(entry, "label")), onClick: function(): unknown | undefined {
					luaCall(applyPreset, entry);
					return undefined;
				}, color: ((preset === luaProp(entry, "id")) ? accent : luaProp(Palette, "panelSoft")), textColor: ((preset === luaProp(entry, "id")) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), outline: (preset !== luaProp(entry, "id")), highlight: (preset === luaProp(entry, "id")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (len(luaProp(Schema, "PRESETS")) as unknown as number)), -6, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) / (len(luaProp(Schema, "PRESETS")) as unknown as number)), 3, 0, 0), reducedMotion: softMotion }));
			}
			luaCall(add, "presets", reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: ((preset === undefined) ? "PRESET  ·  CUSTOM" : "PRESET"), size: 11, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 38), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 18), BackgroundTransparency: 1 }, presetCells)), 66);
		}
		for (const [index, entry] of pairs((rows) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaCall(add, concat("row_", luaProp(entry, "key")), reactLoose.createElement(SettingRow, { entry: entry, value: luaCall(luaProp(Schema, "value"), settings, luaProp(entry, "key")), accent: (listing ? luaCall(accentOf, luaIndex(SECTION_BY_ID, luaProp(entry, "section"))) : accent), tag: (listing ? luaProp(luaIndex(SECTION_BY_ID, luaProp(entry, "section")), "label") : (luaCall(isChanged, entry) ? "changed" : undefined)), stack: stack, softMotion: softMotion, dispatch: dispatch, layoutOrder: index }), rowH);
		}
		if ((listing && (len(rows) === 0))) {
			luaCall(add, "empty", reactLoose.createElement(Text, { value: (showChanged ? "Everything is on its default." : "Nothing matches. Try a shorter word, like \"music\" or \"text\"."), size: 13, color: luaProp(Palette, "muted"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) }), 40);
		}
		if (((!listing) && ((((hiddenAdvanced as unknown as number) > (0 as unknown as number)) || luaIndex(advancedOpen, activeSection))))) {
			luaCall(add, "advanced", reactLoose.createElement(Button, { text: (luaIndex(advancedOpen, activeSection) ? "HIDE ADVANCED" : `SHOW ${hiddenAdvanced} ADVANCED`), icon: (luaIndex(advancedOpen, activeSection) ? "Hide.1" : "Chevron.3"), onClick: function(): unknown | undefined {
				let nextOpen: unknown = luaCall(luaProp(table, "clone"), advancedOpen);
				luaSetIndex(nextOpen, activeSection, (!luaIndex(advancedOpen, activeSection)));
				luaCall(setAdvancedOpen, nextOpen);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 38), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 12), reducedMotion: softMotion }), 58);
		}
		if ((((!listing) && (activeSection === "mobile")) && mobileHudAvailable)) {
			luaCall(add, "hud", reactLoose.createElement(Button, { text: "MOVE PHONE BUTTONS", icon: "Settings.3", onClick: function(): unknown | undefined {
				luaCall(setMobileEdit, true);
				return undefined;
			}, color: accent, textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 10), reducedMotion: softMotion }), ((TapTarget as unknown as number) + (14 as unknown as number)));
		}
		if ((((!listing) && (activeSection === "interface")) && luaProp(UserInputService, "GamepadEnabled"))) {
			luaCall(add, "controller", reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: "CONTROLLER", size: 11, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 14), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) }), reactLoose.createElement(Text, { value: "LB / RB pages  ·  Y vault  ·  X overcharge  ·  LT / RT amount  ·  B back  ·  Start settings", size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 32), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 34) })), 72);
		}
		let list: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: (listing ? luaProp(Palette, "steel") : accent), background: luaProp(Palette, "panel"), padding: (stack ? 14 : 20), reducedMotion: softMotion, clips: false }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, listChildren));
		let listPanelH: unknown = ((listH as unknown as number) + (((stack ? 28 : 40)) as unknown as number));
		let scaffold: unknown = [{ id: "header", height: headerH, element: header }];
		if (stack) {
			luaTable.insert(scaffold, { id: "sections", height: navH, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, reactLoose.createElement("uipadding", { PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), navButtons) });
			luaTable.insert(scaffold, { id: "list", height: listPanelH, element: list });
		} else {
			let bodyH: unknown = luaCall(luaProp(math, "max"), listPanelH, navH);
			luaTable.insert(scaffold, { id: "body", height: bodyH, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, NAV_W, 0, bodyH), background: luaProp(Palette, "panelRaised"), accent: accent, padding: 8, reducedMotion: softMotion, clips: false }, navButtons), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((NAV_W as unknown as number) + (12 as unknown as number))) as unknown as number)), 0, listPanelH), Position: luaCall(luaProp(UDim2, "fromOffset"), ((NAV_W as unknown as number) + (12 as unknown as number)), 0), BackgroundTransparency: 1 }, list)) });
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(PageScaffold, { gap: 12, tailPad: luaCall(scrollTail, stack, luaProp(chrome, "bottomSafe"), 64), scrollBarColor: accent, scrollBarThickness: 4, sections: scaffold }), (mobileHudAvailable && reactLoose.createElement(MobileControls, { visible: mobileEdit, dispatch: dispatch, reducedMotion: softMotion, onClose: function(): unknown | undefined {
			luaCall(setMobileEdit, false);
			return undefined;
		}, slots: mobileSlots, savedSlots: luaProp((((luaProp(state, "Flags") || {}))), "MobileLayoutSlots"), scales: { quick: quickScale, dock: dockScale, toasts: toastScale }, opacities: { quick: luaCall(luaProp(Schema, "value"), settings, "MobileQuickOpacity"), dock: luaCall(luaProp(Schema, "value"), settings, "MobileDockOpacity"), toasts: luaCall(luaProp(Schema, "value"), settings, "MobileToastOpacity") } })));
		return undefined;
	}
	return { SettingsView: SettingsView };
};

__defs["CommandView"] = () => {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _AnimatedTitle: unknown = kit("ReactHosts", "AnimatedTitle");
	let AnimatedTitlePreview: unknown = luaProp(_AnimatedTitle, "AnimatedTitlePreview");
	let darkTitlePlate: unknown = luaProp(_AnimatedTitle, "darkTitlePlate");
	let titleFxAccent: unknown = luaProp(_AnimatedTitle, "titleFxAccent");
	let titleTier: unknown = luaProp(_AnimatedTitle, "titleTier");
	let _scrolling: unknown = kit("LayoutKit", "scrolling");
	let AutoGrid: unknown = luaProp(_scrolling, "AutoGrid");
	let VirtualGrid: unknown = luaProp(_scrolling, "VirtualGrid");
	let Browse: unknown = mod("BrowseKit");
	let _format: unknown = kit("CoreKit", "format");
	let clockText: unknown = luaProp(_format, "clockText");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let gteFlux: unknown = luaProp(_format, "gteFlux");
	let formatReward: unknown = luaProp(_format, "formatReward");
	let _motion: unknown = kit("MotionKit", "motion");
	let easeOutCubic: unknown = luaProp(_motion, "easeOutCubic");
	let useBoatTween: unknown = luaProp(_motion, "useBoatTween");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let Layout: unknown = luaProp(_theme, "Layout");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Palette: unknown = luaProp(_theme, "Palette");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let fitPanelHeight: unknown = luaProp(_theme, "fitPanelHeight");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let IconTile: unknown = luaProp(_ui, "IconTile");
	let Meter: unknown = luaProp(_ui, "Meter");
	let meterFill: unknown = luaProp(_ui, "meterFill");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SectionLabel: unknown = luaProp(_ui, "SectionLabel");
	let SegmentedTabs: unknown = luaProp(_ui, "SegmentedTabs");
	let Text: unknown = luaProp(_ui, "Text");
	let _elementFx: unknown = mod("ElementFx");
	let ElementFx: unknown = luaProp(_elementFx, "ElementFx");
	let elementSheet: unknown = luaProp(_elementFx, "sheet");
	function gridPanelHeight(headerH?: unknown, rows?: unknown, cellH?: unknown, gap?: unknown, pad?: unknown): unknown | undefined {
		let safeRows: unknown = luaCall(luaProp(math, "max"), 1, rows);
		let gridH: unknown = ((((safeRows as unknown as number) * (cellH as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "max"), 0, ((safeRows as unknown as number) - (1 as unknown as number))) as unknown as number) * (gap as unknown as number)) as unknown as number));
		return ((((((pad as unknown as number) * (2 as unknown as number)) as unknown as number) + (headerH as unknown as number)) as unknown as number) + (gridH as unknown as number));
		return undefined;
	}
	let TABS: unknown = ["Overview", "Expeditions", "Artifacts", "Season"];
	let TITLE_FX_FALLBACKS: unknown = ["shimmer", "aurora", "pulse", "chrome", "wave", "glow"];
	let TAB_LABEL: unknown = { Overview: "Overview", Expeditions: "Expeditions", Artifacts: "Artifacts", Season: "Rank Track" };
	let TAB_SHORT: unknown = { Overview: "Home", Expeditions: "Trips", Artifacts: "Relics", Season: "Rank" };
	let _newValue: unknown = luaCall(luaProp(table, "create"), len(TABS));
	let _callback: unknown = function(id?: unknown): unknown | undefined {
		return { id: id, label: luaIndex(TAB_LABEL, id) };
		return undefined;
	};
	for (const [_k, _v] of pairs((TABS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), TABS));
	}
	let TAB_OPTIONS: unknown = _newValue;
	let _newValue_1: unknown = luaCall(luaProp(table, "create"), len(TABS));
	let _callback_1: unknown = function(id?: unknown): unknown | undefined {
		return { id: id, label: luaIndex(TAB_SHORT, id) };
		return undefined;
	};
	for (const [_k, _v] of pairs((TABS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSetIndex(_newValue_1, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), TABS));
	}
	let TAB_OPTIONS_SHORT: unknown = _newValue_1;
	let TAB_TIPS: unknown = { Overview: "Commander rank, crew, weekly jobs, titles, and the signal shop.", Expeditions: "Send crews on timed trips for signals and loot.", Artifacts: "Equip and upgrade expedition relics.", Season: "Claim rank track tiers as you earn commander XP." };
	let CREW_ROLES: unknown = ["Pilot", "Engineer", "Navigator"];
	function crewCost(base?: unknown, level?: unknown): unknown | undefined {
		return luaCall(luaProp(math, "floor"), ((base as unknown as number) * (luaCall(luaProp(math, "pow"), level, 1.55) as unknown as number)));
		return undefined;
	}
	function artifactEffect(artifact?: unknown, level?: unknown): unknown | undefined {
		if ((luaProp(artifact, "EffectKind") === "OfflineHours")) {
			return `+${luaCall(luaProp(string, "format"), "%.1f", ((luaProp(artifact, "EffectPerLevel") as unknown as number) * (level as unknown as number)))}h offline`;
		}
		return `+${luaCall(luaProp(string, "format"), "%.0f", ((((luaProp(artifact, "EffectPerLevel") as unknown as number) * (level as unknown as number)) as unknown as number) * (100 as unknown as number)))}% ${luaProp(artifact, "EffectKind")}`;
		return undefined;
	}
	function artifactIcon(id?: unknown): unknown | undefined {
		if ((id === "SolarLens")) {
			return "Forge";
		}
		if ((id === "VaultPrism")) {
			return "Vault";
		}
		if ((id === "PulsarCoil")) {
			return "Overcharge";
		}
		if ((id === "EchoRelay")) {
			return "Visit";
		}
		if ((id === "DroneCrown")) {
			return "Grid";
		}
		if ((id === "CriticalShard")) {
			return "Jackpot";
		}
		if ((id === "CoreStabilizer")) {
			return "Core";
		}
		if ((id === "TimeCompass")) {
			return "Timer";
		}
		if ((id === "MagnetarSeal")) {
			return "Anomaly";
		}
		if ((id === "VoidKey")) {
			return "Lock";
		}
		if ((id === "AuroraMap")) {
			return "World";
		}
		if ((id === "CrownOfHours")) {
			return "Milestone";
		}
		return "Artifact";
		return undefined;
	}
	function TabRail(_param?: unknown): unknown | undefined {
		let active: unknown = luaProp(_param, "active");
		let setActive: unknown = luaProp(_param, "setActive");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let stack: unknown = luaProp(_param, "stack");
		let columns: unknown = luaProp(_param, "columns");
		return reactLoose.createElement(SegmentedTabs, { options: TAB_OPTIONS, value: active, onChange: setActive, accent: luaProp(Palette, "cyan"), columns: (columns || len(TABS)), gap: 4, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion });
		return undefined;
	}
	function TabPane(_param?: unknown): unknown | undefined {
		let tabKey: unknown = luaProp(_param, "tabKey");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let children: unknown = luaProp(_param, "children");
		let enter: unknown = luaCall(useBoatTween, 1, (reducedMotion ? 0.01 : 0.2), reducedMotion, easeOutCubic, 0);
		return reactLoose.createElement("frame", { key: tabKey, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 20 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "panelGap")) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), Position: colon(enter).map(function(a?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, luaCall(luaProp(math, "round"), (((((1 as unknown as number) - (luaCall(luaProp(math, "clamp"), a, 0, 1) as unknown as number))) as unknown as number) * (7 as unknown as number))), 0, 0);
			return undefined;
		}), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "panelGap")) }), children));
		return undefined;
	}
	let CommandTitleCard: unknown = reactLoose.memo(function(props?: unknown): unknown | undefined {
		let accent: unknown = luaCall(titleFxAccent, luaProp(props, "fx"));
		let tierLabel: unknown = luaCall(luaProp(string, "upper"), luaCall(titleTier, luaProp(props, "fx")));
		let fxLabel: unknown = luaCall(luaProp(string, "upper"), (luaCall(luaProp(string, "gsub"), luaProp(props, "fx"), "-", " ")));
		let effectName: unknown = `${tierLabel}  ${fxLabel}`;
		let equip: unknown = reactLoose.useCallback(function(): unknown | undefined {
			return luaCall(luaProp(props, "dispatch"), "EquipTitle", { Id: luaProp(props, "id") });
			return undefined;
		}, [luaProp(props, "dispatch"), luaProp(props, "id")]);
		let actionHeight: unknown = (luaProp(props, "stack") ? TapTarget : 34);
		let actionSize: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -14, 0, actionHeight);
		let actionPosition: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 7, 1, (-((((actionHeight as unknown as number) + (7 as unknown as number))) as unknown as number)));
		let descText: unknown = (luaProp(props, "description") || "Preview this kinetic title crest exactly as it appears in chat and on your commander nameplate.");
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaCall(darkTitlePlate, luaProp(props, "fx")), BackgroundTransparency: (luaProp(props, "equipped") ? 0.06 : 0.28), BorderSizePixel: 0, Active: false, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: (luaProp(props, "equipped") ? accent : (luaProp(props, "unlocked") ? accent : luaProp(Palette, "lineSoft"))), Thickness: (luaProp(props, "equipped") ? 1.8 : 1), Transparency: (luaProp(props, "equipped") ? 0.08 : (luaProp(props, "unlocked") ? 0.48 : 0.58)) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 16), Position: luaCall(luaProp(UDim2, "fromOffset"), 8, 6), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 6, 6), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 2, 0.5, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0.5), Rotation: 45, BackgroundColor3: (luaProp(props, "unlocked") ? accent : luaProp(Palette, "muted")), BorderSizePixel: 0 }), reactLoose.createElement(Text, { value: effectName, size: 9, minSize: 8, color: (luaProp(props, "unlocked") ? accent : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, align: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), position: luaCall(luaProp(UDim2, "fromOffset"), 14, 1), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -68, 0, 14) }), reactLoose.createElement(Text, { value: (luaProp(props, "equipped") ? "ACTIVE" : (luaProp(props, "unlocked") ? "OWNED" : "LOCKED")), size: 8, minSize: 7, color: (luaProp(props, "equipped") ? luaProp(Palette, "mint") : (luaProp(props, "unlocked") ? luaProp(Palette, "creamSoft") : luaProp(Palette, "muted"))), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -52, 0, 1), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 52, 14) })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -14, 0, 36), Position: luaCall(luaProp(UDim2, "fromOffset"), 7, 23), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(AnimatedTitlePreview, { text: luaProp(props, "name"), fx: luaProp(props, "fx"), size: (luaProp(props, "stack") ? 18 : 16), reducedMotion: luaProp(props, "reducedMotion"), preview: (!luaProp(props, "equipped")), transparency: (luaProp(props, "unlocked") ? 0 : 0.42) })), reactLoose.createElement(Text, { value: descText, size: 10, minSize: 9, color: (luaProp(props, "unlocked") ? luaProp(Palette, "creamSoft") : luaProp(Palette, "muted")), wrap: true, fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: luaCall(luaProp(UDim2, "fromOffset"), 9, 62), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -18, 0, 46) }), ((luaProp(props, "unlocked") && (!luaProp(props, "equipped"))) ? reactLoose.createElement(Button, { text: "EQUIP CREST", icon: "Loadout.5", onClick: equip, color: accent, textColor: luaProp(Palette, "ink"), size: actionSize, position: actionPosition, reducedMotion: luaProp(props, "reducedMotion") }) : reactLoose.createElement("frame", { Size: actionSize, Position: actionPosition, BackgroundColor3: luaProp(Palette, "panelSoft"), BorderSizePixel: 0, Active: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "buttonRadius")) }), reactLoose.createElement("uistroke", { Color: (luaProp(props, "equipped") ? accent : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: 0.52 }), reactLoose.createElement(Text, { value: (luaProp(props, "equipped") ? "EQUIPPED" : "LOCKED"), size: 11, minSize: 9, color: (luaProp(props, "equipped") ? accent : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) }))));
		return undefined;
	});
	function CommandViewReady(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let onSectionChange: unknown = luaProp(_param, "onSectionChange");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let overviewReveal: unknown = luaCall(useStagger, 0, softMotion);
		let expeditionsReveal: unknown = luaCall(useStagger, 1, softMotion);
		let opsReveal: unknown = luaCall(useStagger, 2, softMotion);
		let commandSoft: unknown = (((softMotion || (overviewReveal === undefined)) || (expeditionsReveal === undefined)) || (opsReveal === undefined));
		let claimHostRef: unknown = reactLoose.useRef(undefined);
		let contentWidth: unknown;
		let setContentWidth: unknown;
		[contentWidth, setContentWidth] = reactLoose.useState(360) as LuaTuple<[unknown, unknown]>;
		let stack: unknown = (luaProp(chrome, "contentStack") || ((contentWidth as unknown as number) < (760 as unknown as number)));
		let ops: unknown = luaProp(config, "Operations");
		let command: unknown = luaProp(state, "Command");
		let tab: unknown;
		let setTab: unknown;
		[tab, setTab] = reactLoose.useState("Overview") as LuaTuple<[unknown, unknown]>;
		let now: unknown;
		let setNow: unknown;
		[now, setNow] = reactLoose.useState(colon(game.GetService("Workspace")).GetServerTimeNow()) as LuaTuple<[unknown, unknown]>;
		let scrollRef: unknown = reactLoose.useRef();
		reactLoose.useEffect(function(): unknown | undefined {
			let host: unknown = luaProp(scrollRef, "current");
			if ((!host)) {
				return undefined;
			}
			function measure(): unknown | undefined {
				if (((luaProp(luaProp(host, "AbsoluteSize"), "X") as unknown as number) > (0 as unknown as number))) {
					luaCall(setContentWidth, luaProp(luaProp(host, "AbsoluteSize"), "X"));
				}
				return undefined;
			}
			luaCall(measure);
			let connection: unknown = colon(colon(host).GetPropertyChangedSignal("AbsoluteSize")).Connect(measure);
			return function(): unknown | undefined {
				colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			if ((tab !== "Expeditions")) {
				return undefined;
			}
			let alive: unknown = true;
			let worker: unknown = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
				while (alive) {
					luaCall(luaProp(task, "wait"), 1);
					if ((!alive)) {
						break;
					}
					luaCall(setNow, colon(game.GetService("Workspace")).GetServerTimeNow());
				}
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				luaCall(pcall, function(): unknown | undefined {
					luaCall(luaProp(task, "cancel"), worker);
					return undefined;
				});
				return undefined;
			};
			return undefined;
		}, [tab]);
		reactLoose.useEffect(function(): unknown | undefined {
			let frame: unknown = luaProp(scrollRef, "current");
			if (frame) {
				luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0));
			}
			return undefined;
		}, [tab]);
		let expeditionBrowse: unknown = luaCall(luaProp(Browse, "useBrowse"), { id: "Expeditions", items: (luaProp(ops, "Expeditions") || {}), text: function(expedition?: unknown): unknown | undefined {
			return [luaProp(expedition, "Name"), luaCall(formatReward, luaProp(expedition, "Reward")), `level ${luaProp(expedition, "RequiredLevel")}`];
			return undefined;
		}, categories: [{ id: "All", label: "All" }, { id: "Available", label: "Available", test: function(expedition?: unknown): unknown | undefined {
			return ((luaProp(command, "Level") as unknown as number) >= (luaProp(expedition, "RequiredLevel") as unknown as number));
			return undefined;
		} }, { id: "Locked", label: "Locked", test: function(expedition?: unknown): unknown | undefined {
			return ((luaProp(command, "Level") as unknown as number) < (luaProp(expedition, "RequiredLevel") as unknown as number));
			return undefined;
		} }], sorts: [{ id: "Level", label: "By level" }, { id: "Shortest", label: "Shortest trip", compare: function(a?: unknown, b?: unknown): unknown | undefined {
			return ((((luaCall(tonumber, luaProp(a, "Duration")) || 0)) as unknown as number) < (((luaCall(tonumber, luaProp(b, "Duration")) || 0)) as unknown as number));
			return undefined;
		} }, { id: "Relic", label: "Best relic odds", compare: function(a?: unknown, b?: unknown): unknown | undefined {
			return ((((luaCall(tonumber, luaProp(a, "ArtifactChance")) || 0)) as unknown as number) > (((luaCall(tonumber, luaProp(b, "ArtifactChance")) || 0)) as unknown as number));
			return undefined;
		} }] });
		let expeditionList: unknown = luaProp(expeditionBrowse, "results");
		let titlesEnabled: unknown = (luaProp(ops, "TitlesEnabled") !== false);
		let maxed: unknown = ((luaProp(command, "Level") as unknown as number) >= (luaProp(ops, "MaxCommanderLevel") as unknown as number));
		let levelProgress: unknown = (maxed ? 1 : luaCall(meterFill, ((luaProp(command, "XP") as unknown as number) - (luaProp(command, "LevelFloorXP") as unknown as number)), luaCall(luaProp(math, "max"), 1, ((luaProp(command, "NextLevelXP") as unknown as number) - (luaProp(command, "LevelFloorXP") as unknown as number)))));
		let nextClaim: unknown = luaIndex(luaProp(command, "ClaimableCommanderLevels"), 1);
		let active: unknown = luaProp(command, "ActiveExpedition");
		let _result: unknown = active;
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Id");
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = "";
		}
		let activeId: unknown = _condition;
		let _result_1: unknown = active;
		if ((_result_1 !== undefined)) {
			_result_1 = luaProp(_result_1, "EndsAt");
		}
		let _condition_1: unknown = _result_1;
		if ((_condition_1 === undefined)) {
			_condition_1 = 0;
		}
		let activeEnds: unknown = _condition_1;
		let _result_2: unknown = active;
		if ((_result_2 !== undefined)) {
			_result_2 = luaProp(_result_2, "StartedAt");
		}
		let _condition_2: unknown = _result_2;
		if ((_condition_2 === undefined)) {
			_condition_2 = 0;
		}
		let activeStarted: unknown = _condition_2;
		let expeditionReady: unknown = ((activeId !== "") && ((now as unknown as number) >= (activeEnds as unknown as number)));
		let expeditionProgress: unknown = ((activeId === "") ? 0 : luaCall(luaProp(math, "clamp"), (((((now as unknown as number) - (activeStarted as unknown as number))) as unknown as number) / (luaCall(luaProp(math, "max"), 1, ((activeEnds as unknown as number) - (activeStarted as unknown as number))) as unknown as number)), 0, 1));
		let statusLine: unknown = ((activeId === "") ? "Launch an unlocked adventure below." : (expeditionReady ? "Crew is back. Collect their rewards." : `Back in ${luaCall(clockText, luaCall(luaProp(math, "max"), 0, ((activeEnds as unknown as number) - (now as unknown as number))))}`));
		let claimLabel: unknown = ((activeId === "") ? "Choose below" : (expeditionReady ? "COLLECT" : luaCall(clockText, luaCall(luaProp(math, "max"), 0, ((activeEnds as unknown as number) - (now as unknown as number))))));
		let firstReadyWeeklyId: unknown = undefined;
		if ((luaTypeIs(luaProp(command, "Weekly"), "table"))) {
			for (const [_, directive] of pairs((luaProp(command, "Weekly")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((!luaProp(directive, "Claimed")) && ((luaProp(directive, "Progress") as unknown as number) >= (luaProp(directive, "Target") as unknown as number)))) {
					firstReadyWeeklyId = luaProp(directive, "Id");
					break;
				}
			}
		}
		let firstReadySeasonTier: unknown = undefined;
		if (((luaTypeIs(luaProp(ops, "SeasonTiers"), "table")) && (luaTypeIs(luaProp(command, "SeasonClaims"), "table")))) {
			for (const [_, tier] of pairs((luaProp(ops, "SeasonTiers")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let claimed: unknown = (luaIndex(luaProp(command, "SeasonClaims"), luaCall(tostring, luaProp(tier, "Tier"))) === true);
				let unlocked: unknown = ((luaProp(command, "SeasonXP") as unknown as number) >= (luaProp(tier, "RequiredXP") as unknown as number));
				if ((unlocked && (!claimed))) {
					firstReadySeasonTier = luaProp(tier, "Tier");
					break;
				}
			}
		}
		let commandClaimReady: unknown = (((((tab === "Overview") && (((nextClaim !== undefined) || (firstReadyWeeklyId !== undefined))))) || (((tab === "Expeditions") && expeditionReady))) || (((tab === "Season") && (firstReadySeasonTier !== undefined))));
		reactLoose.useEffect(function(): unknown | undefined {
			if (((!commandClaimReady) || (!luaProp(UserInputService, "GamepadEnabled")))) {
				return undefined;
			}
			let host: unknown = luaProp(claimHostRef, "current");
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
		}, [tab, nextClaim, firstReadyWeeklyId, expeditionReady, firstReadySeasonTier, commandClaimReady]);
		let _exp: unknown = luaProp(ops, "Expeditions");
		let _callback_2: unknown = function(item?: unknown): unknown | undefined {
			return (luaProp(item, "Id") === activeId);
			return undefined;
		};
		let _result_3: unknown;
		for (const [_i, _v] of pairs((_exp) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback_2, _v, ((_i as unknown as number) - (1 as unknown as number)), _exp) === true)) {
				_result_3 = _v;
				break;
			}
		}
		let activeConfig: unknown = _result_3;
		let _exp_1: unknown = luaProp(ops, "Artifacts");
		let _newValue_2: unknown = {};
		let _callback_3: unknown = function(artifact?: unknown): unknown | undefined {
			return (luaIndex(luaProp(command, "Artifacts"), luaProp(artifact, "Id")) !== undefined);
			return undefined;
		};
		let _length: unknown = 0;
		for (const [_k, _v] of pairs((_exp_1) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback_3, _v, ((_k as unknown as number) - (1 as unknown as number)), _exp_1) === true)) {
				_length = ((_length as unknown as number) + (1 as unknown as number));
				luaSetIndex(_newValue_2, _length, _v);
			}
		}
		let ownedArtifacts: unknown = len(_newValue_2);
		let _exp_2: unknown = luaProp(ops, "SeasonTiers");
		let _callback_4: unknown = function(tier?: unknown): unknown | undefined {
			return (luaIndex(luaProp(command, "SeasonClaims"), luaCall(tostring, luaProp(tier, "Tier"))) !== true);
			return undefined;
		};
		let _result_4: unknown;
		for (const [_i, _v] of pairs((_exp_2) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback_4, _v, ((_i as unknown as number) - (1 as unknown as number)), _exp_2) === true)) {
				_result_4 = _v;
				break;
			}
		}
		let nextTier: unknown = _result_4;
		let seasonFill: unknown = (nextTier ? luaCall(meterFill, luaProp(command, "SeasonXP"), luaCall(luaProp(math, "max"), 1, luaProp(nextTier, "RequiredXP"))) : 1);
		let seasonStatus: unknown = (nextTier ? (((luaProp(command, "SeasonXP") as unknown as number) >= (luaProp(nextTier, "RequiredXP") as unknown as number)) ? `Gift ${luaProp(nextTier, "Tier")} is ready` : `${luaCall(compactNumber, ((luaProp(nextTier, "RequiredXP") as unknown as number) - (luaProp(command, "SeasonXP") as unknown as number)))} XP to gift ${luaProp(nextTier, "Tier")}`) : "All season gifts claimed");
		let budget: unknown = luaProp(chrome, "contentBudget");
		let panelPad: unknown = 14;
		let gridGap: unknown = 8;
		let heroH: unknown = (stack ? 196 : 168);
		let crewCols: unknown = (stack ? 1 : 3);
		let crewCellH: unknown = 136;
		let crewRows: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "ceil"), ((len(CREW_ROLES) as unknown as number) / (crewCols as unknown as number))));
		let crewH: unknown = luaCall(gridPanelHeight, 54, crewRows, crewCellH, gridGap, panelPad);
		let weeklyItemH: unknown = (stack ? 148 : 92);
		let weeklyStride: unknown = (stack ? 156 : 100);
		let weeklyCount: unknown = luaCall(luaProp(math, "max"), 1, len(luaProp(command, "Weekly")));
		let weeklyH: unknown = ((((((((panelPad as unknown as number) * (2 as unknown as number)) as unknown as number) + (36 as unknown as number)) as unknown as number) + ((((((weeklyCount as unknown as number) - (1 as unknown as number))) as unknown as number) * (weeklyStride as unknown as number)) as unknown as number)) as unknown as number) + (weeklyItemH as unknown as number));
		let titleCols: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "min"), 4, luaCall(luaProp(math, "floor"), (((((((contentWidth as unknown as number) - (((panelPad as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (gridGap as unknown as number))) as unknown as number) / ((((210 as unknown as number) + (gridGap as unknown as number))) as unknown as number)))));
		let titleCellH: unknown = 176;
		let titleRows: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "ceil"), ((luaCall(luaProp(math, "max"), 1, len(luaProp(command, "Titles"))) as unknown as number) / (titleCols as unknown as number))));
		let titlesH: unknown = (titlesEnabled ? luaCall(gridPanelHeight, 52, titleRows, titleCellH, gridGap, panelPad) : 112);
		let shopCols: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "min"), 4, luaCall(luaProp(math, "floor"), (((((((contentWidth as unknown as number) - (((panelPad as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (gridGap as unknown as number))) as unknown as number) / ((((190 as unknown as number) + (gridGap as unknown as number))) as unknown as number)))));
		let shopCellH: unknown = 180;
		let shopRows: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "ceil"), ((luaCall(luaProp(math, "max"), 1, len(luaProp(command, "Shop"))) as unknown as number) / (shopCols as unknown as number))));
		let shopH: unknown = luaCall(gridPanelHeight, 36, shopRows, shopCellH, gridGap, panelPad);
		let masteryCols: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "min"), 3, luaCall(luaProp(math, "floor"), (((((((contentWidth as unknown as number) - (((panelPad as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (gridGap as unknown as number))) as unknown as number) / ((((210 as unknown as number) + (gridGap as unknown as number))) as unknown as number)))));
		let masteryCellH: unknown = 64;
		let masteryRows: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "ceil"), ((luaCall(luaProp(math, "max"), 1, len(luaProp(config, "Machines"))) as unknown as number) / (masteryCols as unknown as number))));
		let masteryH: unknown = luaCall(gridPanelHeight, 36, masteryRows, masteryCellH, gridGap, panelPad);
		let expeditionHeroH: unknown = (stack ? 188 : 140);
		let expeditionRowH: unknown = (stack ? 168 : 132);
		let artifactHeroH: unknown = 110;
		let artifactRowH: unknown = (stack ? 180 : 140);
		let seasonHeroH: unknown = 130;
		let seasonRowH: unknown = (stack ? 148 : 112);
		let heroInfoWidth: unknown = (stack ? -100 : (-((((((114 as unknown as number) + (210 as unknown as number)) as unknown as number) + (14 as unknown as number))) as unknown as number)));
		let tabContent: unknown = 0;
		let listContent: unknown = 0;
		let tabHeroH: unknown = 0;
		if ((tab === "Overview")) {
			tabContent = ((((((((((((heroH as unknown as number) + (crewH as unknown as number)) as unknown as number) + (weeklyH as unknown as number)) as unknown as number) + (titlesH as unknown as number)) as unknown as number) + (shopH as unknown as number)) as unknown as number) + (masteryH as unknown as number)) as unknown as number) + (((luaProp(Layout, "panelGap") as unknown as number) * (5 as unknown as number)) as unknown as number));
		} else if ((tab === "Expeditions")) {
			tabHeroH = expeditionHeroH;
			listContent = ((((len(luaProp(ops, "Expeditions")) as unknown as number) * (expeditionRowH as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "max"), 0, ((len(luaProp(ops, "Expeditions")) as unknown as number) - (1 as unknown as number))) as unknown as number) * (luaProp(Layout, "panelGap") as unknown as number)) as unknown as number));
		} else if ((tab === "Artifacts")) {
			tabHeroH = artifactHeroH;
			listContent = ((((len(luaProp(ops, "Artifacts")) as unknown as number) * (artifactRowH as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "max"), 0, ((len(luaProp(ops, "Artifacts")) as unknown as number) - (1 as unknown as number))) as unknown as number) * (luaProp(Layout, "panelGap") as unknown as number)) as unknown as number));
		} else {
			tabHeroH = seasonHeroH;
			listContent = ((((len(luaProp(ops, "SeasonTiers")) as unknown as number) * (seasonRowH as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "max"), 0, ((len(luaProp(ops, "SeasonTiers")) as unknown as number) - (1 as unknown as number))) as unknown as number) * (luaProp(Layout, "panelGap") as unknown as number)) as unknown as number));
		}
		let headerH: unknown = 56;
		let tabColumns: unknown = luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "min"), len(TABS), luaCall(luaProp(math, "floor"), (((((contentWidth as unknown as number) + (4 as unknown as number))) as unknown as number) / (140 as unknown as number)))));
		let tabRows: unknown = luaCall(luaProp(math, "ceil"), ((len(TABS) as unknown as number) / (tabColumns as unknown as number)));
		let tabsH: unknown = ((((tabRows as unknown as number) * (48 as unknown as number)) as unknown as number) + ((((((tabRows as unknown as number) - (1 as unknown as number))) as unknown as number) * (4 as unknown as number)) as unknown as number));
		let commandTail: unknown = luaCall(scrollTail, stack, luaProp(chrome, "bottomSafe"), (stack ? 72 : 48));
		let useFillList: unknown = (tab !== "Overview");
		let order: unknown = 0;
		let nextOrder: unknown = function(): unknown | undefined {
			order = ((order as unknown as number) + (1 as unknown as number));
			return order;
			return undefined;
		};
		let changeTab: unknown = function(nextTab?: unknown): unknown | undefined {
			if ((nextTab === tab)) {
				return undefined;
			}
			let _result_5: unknown = onSectionChange;
			if ((_result_5 !== undefined)) {
				luaCall(_result_5);
			}
			luaCall(setTab, nextTab);
			return undefined;
		};
		let _exp_3: unknown = reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "panelGap")) });
		let _exp_4: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, reactLoose.createElement(SectionLabel, { value: "COMMAND · SEASON", color: luaProp(Palette, "cyan") }), reactLoose.createElement(Text, { value: (luaProp(ops, "SeasonName") || "Deep Space Command"), size: (stack ? 24 : 28), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 22), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 32) }));
		let _exp_5: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, reactLoose.createElement(TabRail, { active: tab, setActive: changeTab, reducedMotion: (reducedMotion || commandSoft), stack: stack, columns: tabColumns }));
		let _condition_3: unknown = (tab === "Overview");
		if (_condition_3) {
			let _exp_6: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), (stack ? 72 : 96), (stack ? 72 : 96)), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "cyan"), Thickness: 2, Transparency: 0.25 }), reactLoose.createElement(Text, { value: luaCall(luaProp(string, "format"), "%02d", luaProp(command, "Level")), size: (stack ? 28 : 36), color: luaProp(Palette, "cyan"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.7, 0) }), reactLoose.createElement(Text, { value: "LVL", size: 11, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: luaCall(luaProp(UDim2, "fromScale"), 0, 0.68), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.28, 0) }));
			let _attributes: unknown = {};
			let _condition_4: unknown = luaProp(command, "Rank");
			if ((_condition_4 === undefined)) {
				_condition_4 = "Commander";
			}
			luaSet(_attributes, "value", _condition_4);
			luaSet(_attributes, "size", (stack ? 18 : 22));
			luaSet(_attributes, "color", luaProp(Palette, "cream"));
			luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
			luaSet(_attributes, "fit", true);
			luaSet(_attributes, "minSize", 13);
			luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), (stack ? 88 : 114), 4));
			luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, heroInfoWidth, 0, 28));
			let _exp_7: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, heroH), accent: luaProp(Palette, "cyan"), background: luaProp(Palette, "panelRaised"), padding: 16, layoutOrder: luaCall(nextOrder), reducedMotion: softMotion }, _exp_6, reactLoose.createElement(Text, _attributes), reactLoose.createElement(Text, { value: (maxed ? "Top rank" : `${luaCall(compactNumber, luaCall(luaProp(math, "max"), 0, ((luaProp(command, "NextLevelXP") as unknown as number) - (luaProp(command, "XP") as unknown as number))))} XP to next`), size: 12, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), (stack ? 88 : 114), 36), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, heroInfoWidth, 0, 18) }), reactLoose.createElement(Meter, { value: levelProgress, color: luaProp(Palette, "cyan"), reducedMotion: softMotion, position: luaCall(luaProp(UDim2, "fromOffset"), (stack ? 88 : 114), 60), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, heroInfoWidth, 0, 8) }), reactLoose.createElement(Text, { value: `${luaCall(compactNumber, luaProp(command, "Signals"))} signals  ·  ${luaCall(compactNumber, luaProp(command, "ExpeditionsCompleted"))} ${((luaProp(command, "ExpeditionsCompleted") === 1) ? "trip" : "trips")}  ·  ${luaCall(compactNumber, luaProp(command, "StreakShields"))} ${((luaProp(command, "StreakShields") === 1) ? "shield" : "shields")}`, size: 12, color: luaProp(Palette, "creamSoft"), fit: false, wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 90 : 112)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (stack ? 34 : 18)) }), reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 210, 46)), Position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -210, 0, 16)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: ((nextClaim !== undefined) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: ((nextClaim !== undefined) ? `Claim level ${nextClaim}` : "Rank gifts complete"), icon: "Gift.15", onClick: function(): unknown | undefined {
				if ((nextClaim !== undefined)) {
					luaCall(dispatch, "ClaimCommanderReward", { Level: nextClaim });
				}
				return undefined;
			}, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (nextClaim === undefined), reducedMotion: softMotion, highlight: (nextClaim !== undefined) })));
			let _exp_8: unknown = reactLoose.createElement(Text, { value: "Officers", size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24) });
			let _exp_9: unknown = reactLoose.createElement(Text, { value: "Spend signals to train the officers who run your expeditions.", size: 12, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) });
			let _exp_10: unknown = reactLoose.createElement(AutoGrid, { columns: crewCols, cellHeight: crewCellH, rowGap: gridGap, columnGap: gridGap });
			let _newValue_3: unknown = luaCall(luaProp(table, "create"), len(CREW_ROLES));
			let _callback_5: unknown = function(roleId?: unknown, index?: unknown): unknown | undefined {
				let role: unknown = luaIndex(luaProp(ops, "Crew"), roleId);
				if ((!role)) {
					return undefined;
				}
				let _condition_5: unknown = luaIndex(luaProp(command, "Crew"), roleId);
				if ((_condition_5 === undefined)) {
					_condition_5 = 1;
				}
				let level: unknown = _condition_5;
				let cost: unknown = luaCall(crewCost, luaProp(role, "BaseCost"), level);
				let maxRole: unknown = ((level as unknown as number) >= (luaProp(role, "MaxLevel") as unknown as number));
				let can: unknown = ((!maxRole) && ((luaProp(command, "Signals") as unknown as number) >= (cost as unknown as number)));
				return reactLoose.createElement("frame", { key: roleId, BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, LayoutOrder: index }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(role, "Color"), Thickness: 1, Transparency: 0.4 }), reactLoose.createElement(Text, { value: luaProp(role, "Name"), size: 13, color: luaProp(role, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 18) }), reactLoose.createElement(Text, { value: (((luaProp(role, "MaxLevel") as unknown as number) >= (1000000000 as unknown as number)) ? `Lv ${luaCall(compactNumber, level)}` : `Lv ${luaCall(compactNumber, level)} / ${luaCall(compactNumber, luaProp(role, "MaxLevel"))}`), size: 11, color: luaProp(Palette, "creamSoft"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 30), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 16) }), ((luaProp(role, "Description") && reactLoose.createElement(Text, { value: luaProp(role, "Description"), size: 11, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 50), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 30) })) || undefined), reactLoose.createElement(Button, { text: (maxRole ? "MAX" : `Train · ${luaCall(compactNumber, cost)} signals`), onClick: function(): unknown | undefined {
					return luaCall(dispatch, "UpgradeCrew", { Role: roleId });
					return undefined;
				}, color: luaProp(role, "Color"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, (stack ? TapTarget : 36)), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 10, 1, (-(((stack ? ((TapTarget as unknown as number) + (8 as unknown as number)) : 44)) as unknown as number))), disabled: (!can), reducedMotion: softMotion, highlight: can }));
				return undefined;
			};
			for (const [_k, _v] of pairs((CREW_ROLES) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue_3, _k, luaCall(_callback_5, _v, ((_k as unknown as number) - (1 as unknown as number)), CREW_ROLES));
			}
			let _exp_11: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, crewH), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panel"), padding: panelPad, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, _exp_8, _exp_9, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((((crewRows as unknown as number) * (crewCellH as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "max"), 0, ((crewRows as unknown as number) - (1 as unknown as number))) as unknown as number) * (gridGap as unknown as number)) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 54), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, _exp_10, _newValue_3));
			let _exp_12: unknown = reactLoose.createElement(Text, { value: "Weekly jobs", size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24) });
			let _exp_13: unknown = reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(command, "Weekly")), columns: 1, cellHeight: weeklyItemH, gap: ((weeklyStride as unknown as number) - (weeklyItemH as unknown as number)), overscanRows: (softMotion ? 0 : 1), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 36), itemKey: function(index?: unknown): unknown | undefined {
				let directive: unknown = luaIndex(luaProp(command, "Weekly"), ((index as unknown as number) + (1 as unknown as number)));
				return ((directive !== undefined) ? luaProp(directive, "Id") : `weekly-${index}`);
				return undefined;
			}, renderItem: function(index?: unknown): unknown | undefined {
				let directive: unknown = luaIndex(luaProp(command, "Weekly"), ((index as unknown as number) + (1 as unknown as number)));
				if ((directive === undefined)) {
					return undefined;
				}
				let ready: unknown = ((!luaProp(directive, "Claimed")) && ((luaProp(directive, "Progress") as unknown as number) >= (luaProp(directive, "Target") as unknown as number)));
				let rewardLine: unknown = luaCall(formatReward, luaProp(directive, "Reward"));
				let _exp_14: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) });
				let _exp_15: unknown = reactLoose.createElement("uistroke", { Color: (ready ? luaProp(Palette, "green") : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: 0.45 });
				let _exp_16: unknown = reactLoose.createElement(Text, { value: luaProp(directive, "Name"), size: 13, color: (ready ? luaProp(Palette, "green") : luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 12, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -24 : -156), 0, 18) });
				let _attributes_1: unknown = {};
				let _condition_5: unknown = luaProp(directive, "Description");
				if ((_condition_5 === undefined)) {
					_condition_5 = "";
				}
				luaSet(_attributes_1, "value", _condition_5);
				luaSet(_attributes_1, "size", 11);
				luaSet(_attributes_1, "color", luaProp(Palette, "muted"));
				luaSet(_attributes_1, "fit", false);
				luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 12, 28));
				luaSet(_attributes_1, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -24 : -156), 0, 16));
				return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, weeklyItemH), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0 }, _exp_14, _exp_15, _exp_16, reactLoose.createElement(Text, _attributes_1), reactLoose.createElement(Text, { value: ((rewardLine !== "") ? rewardLine : `${luaCall(compactNumber, luaProp(directive, "Progress"))} / ${luaCall(compactNumber, luaProp(directive, "Target"))}`), size: 10, color: luaProp(Palette, "creamSoft"), wrap: true, fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 12, 46), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -24 : -156), 0, 28) }), reactLoose.createElement(Meter, { value: luaCall(meterFill, luaProp(directive, "Progress"), luaProp(directive, "Target"), (luaProp(directive, "Claimed") || ready)), color: luaProp(Palette, "green"), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 12, (stack ? 78 : 76)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -24 : -156), 0, 7) }), (stack ? reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0, TapTarget), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 12, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (((ready && (nextClaim === undefined)) && (luaProp(directive, "Id") === firstReadyWeeklyId)) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: (luaProp(directive, "Claimed") ? "DONE" : (ready ? "CLAIM" : "NOT YET")), onClick: function(): unknown | undefined {
					return luaCall(dispatch, "ClaimWeeklyDirective", { Id: luaProp(directive, "Id") });
					return undefined;
				}, color: luaProp(Palette, "green"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (luaProp(directive, "Claimed") || (!ready)), reducedMotion: reducedMotion, highlight: ready })) : reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: luaCall(luaProp(UDim2, "fromOffset"), 140, 44), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -150, 0.5, -22), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (((ready && (nextClaim === undefined)) && (luaProp(directive, "Id") === firstReadyWeeklyId)) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: (luaProp(directive, "Claimed") ? "DONE" : (ready ? "CLAIM" : "NOT YET")), onClick: function(): unknown | undefined {
					return luaCall(dispatch, "ClaimWeeklyDirective", { Id: luaProp(directive, "Id") });
					return undefined;
				}, color: luaProp(Palette, "green"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (luaProp(directive, "Claimed") || (!ready)), reducedMotion: reducedMotion, highlight: ready }))));
				return undefined;
			} });
			let _exp_14: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, weeklyH), accent: luaProp(Palette, "green"), background: luaProp(Palette, "panel"), padding: 14, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion, clips: false }, _exp_12, _exp_13);
			let _exp_15: unknown = reactLoose.createElement(Text, { value: "Title wardrobe", size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -164, 0, 24) });
			let _result_5: unknown;
			if (titlesEnabled) {
				_result_5 = reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: "Each card shows the title exactly as it will look on you.", size: 11, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) }), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(command, "Titles")), columns: titleCols, cellHeight: titleCellH, gap: gridGap, overscanRows: 1, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 52), itemKey: function(index?: unknown): unknown | undefined {
					let title: unknown = luaIndex(luaProp(command, "Titles"), ((index as unknown as number) + (1 as unknown as number)));
					return ((title !== undefined) ? luaProp(title, "Id") : `title-${index}`);
					return undefined;
				}, renderItem: function(index?: unknown): unknown | undefined {
					let title: unknown = luaIndex(luaProp(command, "Titles"), ((index as unknown as number) + (1 as unknown as number)));
					if ((title === undefined)) {
						return undefined;
					}
					let _condition_5: unknown = luaProp(title, "Fx");
					if ((_condition_5 === undefined)) {
						_condition_5 = luaIndex(TITLE_FX_FALLBACKS, ((((index as unknown as number) % (len(TITLE_FX_FALLBACKS) as unknown as number)) as unknown as number) + (1 as unknown as number)));
					}
					let titleFx: unknown = _condition_5;
					return reactLoose.createElement(CommandTitleCard, { id: luaProp(title, "Id"), name: luaProp(title, "Name"), description: luaProp(title, "Description"), unlocked: luaProp(title, "Unlocked"), equipped: luaProp(title, "Equipped"), fx: titleFx, stack: stack, reducedMotion: reducedMotion, dispatch: dispatch });
					return undefined;
				} }));
			} else {
				let _exp_16: unknown = reactLoose.createElement(Badge, { value: "TEMPORARILY CLOSED", accent: luaProp(Palette, "muted"), size: luaCall(luaProp(UDim2, "fromOffset"), 152, 26), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -152, 0, 0) });
				let _attributes_1: unknown = {};
				let _condition_5: unknown = luaProp(ops, "TitleStatus");
				if ((_condition_5 === undefined)) {
					_condition_5 = "Titles are temporarily unavailable.";
				}
				luaSet(_attributes_1, "value", _condition_5);
				luaSet(_attributes_1, "size", 12);
				luaSet(_attributes_1, "color", luaProp(Palette, "muted"));
				luaSet(_attributes_1, "wrap", true);
				luaSet(_attributes_1, "fit", false);
				luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, 36));
				luaSet(_attributes_1, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 44));
				_result_5 = reactLoose.createElement(React.Fragment, undefined, _exp_16, reactLoose.createElement(Text, _attributes_1));
			}
			_condition_3 = reactLoose.createElement(TabPane, { tabKey: "Overview", reducedMotion: reducedMotion }, _exp_7, _exp_11, _exp_14, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, titlesH), accent: (titlesEnabled ? luaProp(Palette, "violet") : luaProp(Palette, "muted")), background: luaProp(Palette, "panel"), padding: panelPad, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, _exp_15, _result_5), reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, shopH), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panel"), padding: panelPad, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: `Signal shop · ${luaCall(compactNumber, luaProp(command, "Signals"))} ready`, size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24) }), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(command, "Shop")), columns: shopCols, cellHeight: shopCellH, gap: gridGap, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 36), itemKey: function(index?: unknown): unknown | undefined {
				let offer: unknown = luaIndex(luaProp(command, "Shop"), ((index as unknown as number) + (1 as unknown as number)));
				return ((offer !== undefined) ? luaProp(offer, "Id") : `shop-${index}`);
				return undefined;
			}, renderItem: function(index?: unknown): unknown | undefined {
				let offer: unknown = luaIndex(luaProp(command, "Shop"), ((index as unknown as number) + (1 as unknown as number)));
				if ((offer === undefined)) {
					return undefined;
				}
				let can: unknown = ((!luaProp(offer, "Purchased")) && ((luaProp(command, "Signals") as unknown as number) >= (luaProp(offer, "Price") as unknown as number)));
				return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0, Active: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(offer, "Color"), Thickness: 1, Transparency: 0.35 }), reactLoose.createElement(Text, { value: luaProp(offer, "Name"), size: 12, color: luaProp(offer, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 20) }), reactLoose.createElement(Text, { value: luaCall(formatReward, luaProp(offer, "Reward")), size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 40) }), reactLoose.createElement(Button, { text: (luaProp(offer, "Purchased") ? "BOUGHT" : `${luaProp(offer, "Price")} sig`), onClick: function(): unknown | undefined {
					return luaCall(dispatch, "BuySignalOffer", { Id: luaProp(offer, "Id") });
					return undefined;
				}, color: luaProp(offer, "Color"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, (stack ? TapTarget : 40)), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 8, 1, (-(((stack ? ((TapTarget as unknown as number) + (8 as unknown as number)) : 48)) as unknown as number))), disabled: (!can), reducedMotion: reducedMotion, highlight: can }));
				return undefined;
			} })), reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, masteryH), accent: luaProp(Palette, "blue"), background: luaProp(Palette, "panel"), padding: panelPad, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: "Machine mastery", size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24) }), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(config, "Machines")), columns: masteryCols, cellHeight: masteryCellH, gap: gridGap, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 36), itemKey: function(index?: unknown): unknown | undefined {
				let machine: unknown = luaIndex(luaProp(config, "Machines"), ((index as unknown as number) + (1 as unknown as number)));
				return ((machine !== undefined) ? luaProp(machine, "Id") : `machine-${index}`);
				return undefined;
			}, renderItem: function(index?: unknown): unknown | undefined {
				let machine: unknown = luaIndex(luaProp(config, "Machines"), ((index as unknown as number) + (1 as unknown as number)));
				if ((machine === undefined)) {
					return undefined;
				}
				let _condition_5: unknown = luaIndex(luaProp(command, "MachineMastery"), luaProp(machine, "Id"));
				if ((_condition_5 === undefined)) {
					_condition_5 = 0;
				}
				let mastery: unknown = _condition_5;
				let rank: unknown = luaCall(luaProp(math, "floor"), luaCall(luaProp(math, "sqrt"), mastery));
				let nextRank: unknown = luaCall(luaProp(math, "pow"), ((rank as unknown as number) + (1 as unknown as number)), 2);
				let fill: unknown = (((rank as unknown as number) >= (99 as unknown as number)) ? 1 : (((((mastery as unknown as number) - (((rank as unknown as number) * (rank as unknown as number)) as unknown as number))) as unknown as number) / (luaCall(luaProp(math, "max"), 1, ((nextRank as unknown as number) - (((rank as unknown as number) * (rank as unknown as number)) as unknown as number))) as unknown as number)));
				return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0, Active: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement(Text, { value: luaProp(machine, "Name"), size: 12, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 6), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0, 18) }), reactLoose.createElement(Badge, { value: `RANK ${rank}`, accent: luaProp(machine, "Color"), filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -58, 0, 6), size: luaCall(luaProp(UDim2, "fromOffset"), 48, 20) }), reactLoose.createElement(Meter, { value: fill, color: luaProp(machine, "Color"), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 34), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 6) }), reactLoose.createElement(Text, { value: `${luaCall(compactNumber, mastery)} built`, size: 10, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 44), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 14) }));
				return undefined;
			} })));
		}
		let _condition_4: unknown = (tab === "Expeditions");
		if (_condition_4) {
			let _exp_6: unknown = reactLoose.createElement(Text, { value: "Active trip", size: 12, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) });
			let _attributes: unknown = {};
			let _result_5: unknown = activeConfig;
			if ((_result_5 !== undefined)) {
				_result_5 = luaProp(_result_5, "Name");
			}
			let _condition_5: unknown = _result_5;
			if ((_condition_5 === undefined)) {
				_condition_5 = "No trip underway";
			}
			luaSet(_attributes, "value", _condition_5);
			luaSet(_attributes, "size", (stack ? 18 : 22));
			luaSet(_attributes, "color", (expeditionReady ? luaProp(Palette, "green") : luaProp(Palette, "cream")));
			luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
			luaSet(_attributes, "fit", false);
			luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, 22));
			luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? 0 : -230), 0, 28));
			_condition_4 = reactLoose.createElement(TabPane, { tabKey: "Expeditions", reducedMotion: reducedMotion }, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, expeditionHeroH), accent: (expeditionReady ? luaProp(Palette, "green") : luaProp(Palette, "cyan")), background: luaProp(Palette, "panelRaised"), padding: 14, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, _exp_6, reactLoose.createElement(Text, _attributes), reactLoose.createElement(Text, { value: statusLine, size: 12, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 54), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? 0 : -230), 0, 18) }), reactLoose.createElement(Meter, { value: expeditionProgress, color: (expeditionReady ? luaProp(Palette, "green") : luaProp(Palette, "cyan")), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 80), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? 0 : -230), 0, 8) }), reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 210, 48)), Position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -210, 0.5, -24)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (expeditionReady ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: claimLabel, icon: "Gift.16", onClick: function(): unknown | undefined {
				return luaCall(dispatch, "ClaimExpedition");
				return undefined;
			}, color: luaProp(Palette, "green"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (!expeditionReady), reducedMotion: reducedMotion, highlight: expeditionReady }))), reactLoose.createElement(luaProp(Browse, "BrowseBar"), { browse: expeditionBrowse, placeholder: "Search adventures by name or reward", accent: luaProp(Palette, "cyan"), stack: stack, reducedMotion: softMotion, layoutOrder: luaCall(nextOrder), zIndex: 30 }), ((len(expeditionList) === 0) && reactLoose.createElement(luaProp(Browse, "NoResults"), { browse: expeditionBrowse, noun: "adventures", icon: "World.7", accent: luaProp(Palette, "cyan"), reducedMotion: softMotion, layoutOrder: luaCall(nextOrder) })), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(expeditionList), columns: 1, cellHeight: expeditionRowH, gap: luaProp(Layout, "panelGap"), overscanRows: (softMotion ? 0 : 1), layoutOrder: luaCall(nextOrder), itemKey: function(index?: unknown): unknown | undefined {
				let expedition: unknown = luaIndex(expeditionList, ((index as unknown as number) + (1 as unknown as number)));
				return ((expedition !== undefined) ? luaProp(expedition, "Id") : `expedition-${index}`);
				return undefined;
			}, renderItem: function(index?: unknown): unknown | undefined {
				let expedition: unknown = luaIndex(expeditionList, ((index as unknown as number) + (1 as unknown as number)));
				if ((expedition === undefined)) {
					return undefined;
				}
				let locked: unknown = ((luaProp(command, "Level") as unknown as number) < (luaProp(expedition, "RequiredLevel") as unknown as number));
				let busy: unknown = (activeId !== "");
				let can: unknown = ((!locked) && (!busy));
				let _attributes_1: unknown = {};
				let _condition_6: unknown = luaProp(expedition, "ArtifactId");
				if ((_condition_6 === undefined)) {
					_condition_6 = luaProp(expedition, "Id");
				}
				luaSet(_attributes_1, "kind", luaCall(artifactIcon, _condition_6));
				luaSet(_attributes_1, "accent", luaProp(expedition, "Color"));
				luaSet(_attributes_1, "size", 46);
				luaSet(_attributes_1, "radius", 12);
				luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 6 : 18)));
				luaSet(_attributes_1, "reducedMotion", reducedMotion);
				return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, expeditionRowH), accent: luaProp(expedition, "Color"), background: luaProp(Palette, "panel"), padding: 14, interactive: true, highlight: can, reducedMotion: reducedMotion }, reactLoose.createElement(IconTile, _attributes_1), reactLoose.createElement(Text, { value: `Lv ${luaProp(expedition, "RequiredLevel")}  ·  ${luaCall(clockText, luaCall(luaProp(math, "max"), 10, luaCall(luaProp(math, "floor"), ((luaProp(expedition, "Duration") as unknown as number) * (luaCall(luaProp(math, "max"), 0.35, ((1 as unknown as number) - ((((((((luaProp(luaProp(command, "Crew"), "Pilot") || 1)) as unknown as number) - (1 as unknown as number))) as unknown as number) * (0.05 as unknown as number)) as unknown as number))) as unknown as number)))))}`, size: 11, color: luaProp(expedition, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -224), 0, 16) }), reactLoose.createElement(Text, { value: luaProp(expedition, "Name"), size: 17, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -224), 0, 24) }), reactLoose.createElement(Text, { value: `${luaCall(formatReward, luaProp(expedition, "Reward"))}  ·  ${luaCall(luaProp(string, "format"), "%.0f", ((luaProp(expedition, "ArtifactChance") as unknown as number) * (100 as unknown as number)))}% relic`, size: 11, color: luaProp(Palette, "muted"), wrap: true, fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 52), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -224), 0, 28) }), reactLoose.createElement(Button, { text: (locked ? `Need lv ${luaProp(expedition, "RequiredLevel")}` : (busy ? "Crew away" : "LAUNCH")), onClick: function(): unknown | undefined {
					return luaCall(dispatch, "LaunchExpedition", { Id: luaProp(expedition, "Id") });
					return undefined;
				}, color: luaProp(expedition, "Color"), textColor: luaProp(Palette, "ink"), size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 200, 46)), position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -210, 0.5, -23)), disabled: (!can), reducedMotion: reducedMotion, highlight: can }));
				return undefined;
			} }));
		}
		let bodyPane: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, _exp_3, _condition_3, _condition_4, ((tab === "Artifacts") && reactLoose.createElement(TabPane, { tabKey: "Artifacts", reducedMotion: reducedMotion }, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, artifactHeroH), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panelRaised"), padding: 14, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: `Relics  ${ownedArtifacts}/${len(luaProp(ops, "Artifacts"))}`, size: 20, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) }), reactLoose.createElement(Text, { value: "Equip one relic. Duplicates add spark fragments for upgrades.", size: 12, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }), reactLoose.createElement(Meter, { value: ((ownedArtifacts as unknown as number) / (luaCall(luaProp(math, "max"), 1, len(luaProp(ops, "Artifacts"))) as unknown as number)), color: luaProp(Palette, "violet"), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 68), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 8) })), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(ops, "Artifacts")), columns: 1, cellHeight: artifactRowH, gap: luaProp(Layout, "panelGap"), layoutOrder: luaCall(nextOrder), itemKey: function(index?: unknown): unknown | undefined {
			let artifact: unknown = luaIndex(luaProp(ops, "Artifacts"), ((index as unknown as number) + (1 as unknown as number)));
			return ((artifact !== undefined) ? luaProp(artifact, "Id") : `artifact-${index}`);
			return undefined;
		}, renderItem: function(index?: unknown): unknown | undefined {
			let artifact: unknown = luaIndex(luaProp(ops, "Artifacts"), ((index as unknown as number) + (1 as unknown as number)));
			if ((artifact === undefined)) {
				return undefined;
			}
			let owned: unknown = luaIndex(luaProp(command, "Artifacts"), luaProp(artifact, "Id"));
			let equipped: unknown = (luaProp(command, "EquippedArtifact") === luaProp(artifact, "Id"));
			let fragmentCost: unknown = (owned ? ((4 as unknown as number) + (((luaProp(owned, "Level") as unknown as number) * (2 as unknown as number)) as unknown as number)) : 0);
			let dustCost: unknown = (owned ? ((8 as unknown as number) * (luaProp(owned, "Level") as unknown as number)) : 0);
			let canUpgrade: unknown = ((((owned !== undefined) && ((luaProp(owned, "Level") as unknown as number) < (10 as unknown as number))) && ((luaProp(owned, "Fragments") as unknown as number) >= (fragmentCost as unknown as number))) && luaCall(gteFlux, luaProp(state, "Stardust"), dustCost));
			return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, artifactRowH), accent: (owned ? luaProp(artifact, "Color") : luaProp(Palette, "lineSoft")), background: (owned ? luaProp(Palette, "panel") : luaProp(Palette, "panelSoft")), padding: 14, reducedMotion: reducedMotion }, reactLoose.createElement("frame", { Name: "ElementTile", Size: luaCall(luaProp(UDim2, "fromOffset"), 48, 48), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, (stack ? 5 : 17)), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: 0.15, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: (owned ? luaProp((((luaCall(elementSheet, luaProp(artifact, "Element")) || { Color: luaProp(artifact, "Color") }))), "Color") : luaProp(Palette, "lineSoft")), Transparency: (equipped ? 0 : 0.45), Thickness: (equipped ? 2 : 1) }), reactLoose.createElement(ElementFx, { element: luaProp(artifact, "Element"), size: luaCall(luaProp(UDim2, "fromOffset"), 48, 48), position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), still: (!owned), transparency: (owned ? 0 : 0.7), reducedMotion: reducedMotion, reaction: "reveal", reactionKey: ((owned !== undefined) && (owned !== false)) })), reactLoose.createElement(Text, { value: (owned ? `${luaProp(artifact, "Rarity")}  ·  ${luaProp((((luaCall(elementSheet, luaProp(artifact, "Element")) || { Label: "" }))), "Label")}  ·  Lv ${luaProp(owned, "Level")}/10` : luaProp(artifact, "Rarity")), size: 11, color: (owned ? luaProp(artifact, "Color") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -286), 0, 16) }), reactLoose.createElement(Text, { value: (owned ? luaProp(artifact, "Name") : "Mystery relic"), size: 17, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -286), 0, 24) }), reactLoose.createElement(Text, { value: (owned ? `${luaCall(artifactEffect, artifact, luaProp(owned, "Level"))}  ·  ${luaProp(owned, "Fragments")}/${fragmentCost} sparks` : "Finish its expedition to discover it."), size: 11, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 52), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -70 : -286), 0, 18) }), reactLoose.createElement("frame", { Size: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 260, 46)), Position: (stack ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -270, 0.5, -23)), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Button, { text: (equipped ? "IN USE" : "EQUIP"), onClick: function(): unknown | undefined {
				return luaCall(dispatch, "EquipArtifact", { Id: luaProp(artifact, "Id") });
				return undefined;
			}, color: luaProp(artifact, "Color"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 1, 0), disabled: ((!owned) || equipped), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: ((!owned) ? "—" : (((luaProp(owned, "Level") as unknown as number) >= (10 as unknown as number)) ? "MAX" : `${dustCost} dust`)), onClick: function(): unknown | undefined {
				return luaCall(dispatch, "UpgradeArtifact", { Id: luaProp(artifact, "Id") });
				return undefined;
			}, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 0, 0), disabled: (!canUpgrade), reducedMotion: reducedMotion, highlight: canUpgrade })));
			return undefined;
		} }))), ((tab === "Season") && reactLoose.createElement(TabPane, { tabKey: "Season", reducedMotion: reducedMotion }, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, seasonHeroH), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panelRaised"), padding: 14, layoutOrder: luaCall(nextOrder), reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: luaProp(ops, "SeasonName"), size: 22, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) }), reactLoose.createElement(Text, { value: `${luaCall(compactNumber, luaProp(command, "SeasonXP"))} season XP · ${len(luaProp(ops, "SeasonTiers"))} gifts`, size: 12, color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 36), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) }), reactLoose.createElement(Meter, { value: seasonFill, color: luaProp(Palette, "mango"), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 64), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 9) }), reactLoose.createElement(Text, { value: seasonStatus, size: 12, color: luaProp(Palette, "creamSoft"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 82), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) })), reactLoose.createElement(VirtualGrid, { scrollRef: scrollRef, count: len(luaProp(ops, "SeasonTiers")), columns: 1, cellHeight: seasonRowH, gap: luaProp(Layout, "panelGap"), overscanRows: (softMotion ? 0 : 1), layoutOrder: luaCall(nextOrder), itemKey: function(index?: unknown): unknown | undefined {
			let tier: unknown = luaIndex(luaProp(ops, "SeasonTiers"), ((index as unknown as number) + (1 as unknown as number)));
			return ((tier !== undefined) ? luaCall(tostring, luaProp(tier, "Tier")) : `tier-${index}`);
			return undefined;
		}, renderItem: function(index?: unknown): unknown | undefined {
			let tier: unknown = luaIndex(luaProp(ops, "SeasonTiers"), ((index as unknown as number) + (1 as unknown as number)));
			if ((tier === undefined)) {
				return undefined;
			}
			let unlocked: unknown = ((luaProp(command, "SeasonXP") as unknown as number) >= (luaProp(tier, "RequiredXP") as unknown as number));
			let claimed: unknown = (luaIndex(luaProp(command, "SeasonClaims"), luaCall(tostring, luaProp(tier, "Tier"))) === true);
			let major: unknown = (((luaProp(tier, "Tier") as unknown as number) % (5 as unknown as number)) === 0);
			let progressLabel: unknown = (claimed ? "COLLECTED" : (unlocked ? "READY TO OPEN" : `${luaCall(compactNumber, luaCall(luaProp(math, "min"), luaProp(command, "SeasonXP"), luaProp(tier, "RequiredXP")))} / ${luaCall(compactNumber, luaProp(tier, "RequiredXP"))} XP`));
			return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, seasonRowH), accent: (major ? luaProp(Palette, "mango") : (unlocked ? luaProp(Palette, "green") : luaProp(Palette, "lineSoft"))), background: (major ? luaProp(Palette, "panelRaised") : luaProp(Palette, "panel")), padding: 12, reducedMotion: reducedMotion }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 56, 56), BackgroundColor3: (claimed ? luaProp(Palette, "green") : (unlocked ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft"))), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement(Text, { value: luaCall(luaProp(string, "format"), "%02d", luaProp(tier, "Tier")), size: 20, color: ((claimed || unlocked) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) })), reactLoose.createElement(Text, { value: (major ? "Major gift" : "Rank gift"), size: 14, color: (major ? luaProp(Palette, "mango") : luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 72, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? (-((((72 as unknown as number) + (24 as unknown as number))) as unknown as number)) : -250), 0, 20) }), reactLoose.createElement(Text, { value: luaCall(formatReward, luaProp(tier, "Reward")), size: 12, color: luaProp(Palette, "muted"), wrap: true, fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 72, 32), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? (-((((72 as unknown as number) + (24 as unknown as number))) as unknown as number)) : -250), 0, 28) }), reactLoose.createElement(Meter, { value: luaCall(meterFill, luaProp(command, "SeasonXP"), luaProp(tier, "RequiredXP"), (claimed || unlocked)), color: (major ? luaProp(Palette, "mango") : luaProp(Palette, "green")), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 72, (stack ? 64 : 72)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (stack ? -84 : -250), 0, 7) }), (stack ? reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0, TapTarget), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 12, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (((unlocked && (!claimed)) && (luaProp(tier, "Tier") === firstReadySeasonTier)) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: (claimed ? "CLAIMED" : (unlocked ? "OPEN" : "LOCKED")), onClick: function(): unknown | undefined {
				return luaCall(dispatch, "ClaimSeasonTier", { Tier: luaProp(tier, "Tier") });
				return undefined;
			}, color: (major ? luaProp(Palette, "mango") : luaProp(Palette, "green")), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (claimed || (!unlocked)), reducedMotion: reducedMotion, highlight: (unlocked && (!claimed)) })) : reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: progressLabel, size: 11, color: (unlocked ? luaProp(Palette, "green") : luaProp(Palette, "muted")), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 72, 54), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -250, 0, 16) }), reactLoose.createElement("frame", { Name: "CommandClaimActions", Size: luaCall(luaProp(UDim2, "fromOffset"), 150, 44), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -158, 0.5, -22), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (((unlocked && (!claimed)) && (luaProp(tier, "Tier") === firstReadySeasonTier)) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: (claimed ? "CLAIMED" : (unlocked ? "OPEN" : "LOCKED")), onClick: function(): unknown | undefined {
				return luaCall(dispatch, "ClaimSeasonTier", { Tier: luaProp(tier, "Tier") });
				return undefined;
			}, color: (major ? luaProp(Palette, "mango") : luaProp(Palette, "green")), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (claimed || (!unlocked)), reducedMotion: reducedMotion, highlight: (unlocked && (!claimed)) })))));
			return undefined;
		} }))));
		let bodyIntrinsic: unknown = (useFillList ? ((((tabHeroH as unknown as number) + (listContent as unknown as number)) as unknown as number) + (luaProp(Layout, "panelGap") as unknown as number)) : tabContent);
		return reactLoose.createElement(PageScaffold, { hostRef: scrollRef, gap: luaProp(Layout, "panelGap"), tailPad: commandTail, scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: 4, sections: [{ id: "header", height: headerH, element: _exp_4 }, { id: "tabs", height: tabsH, element: _exp_5 }, { id: "body", fill: true, minHeight: 200, height: bodyIntrinsic, element: bodyPane }] });
		return undefined;
	}
	function CommandView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let onSectionChange: unknown = luaProp(_param, "onSectionChange");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let overviewReveal: unknown = luaCall(useStagger, 0, softMotion);
		let expeditionsReveal: unknown = luaCall(useStagger, 1, softMotion);
		let opsReveal: unknown = luaCall(useStagger, 2, softMotion);
		let commandSoft: unknown = (((softMotion || (overviewReveal === undefined)) || (expeditionsReveal === undefined)) || (opsReveal === undefined));
		let claimHostRef: unknown = reactLoose.useRef(undefined);
		let stack: unknown = luaProp(chrome, "contentStack");
		let ops: unknown = luaProp(config, "Operations");
		let command: unknown = luaProp(state, "Command");
		let tab: unknown;
		let setTab: unknown;
		[tab, setTab] = reactLoose.useState("Overview") as LuaTuple<[unknown, unknown]>;
		let now: unknown;
		let setNow: unknown;
		[now, setNow] = reactLoose.useState(colon(game.GetService("Workspace")).GetServerTimeNow()) as LuaTuple<[unknown, unknown]>;
		let scrollRef: unknown = reactLoose.useRef();
		reactLoose.useEffect(function(): unknown | undefined {
			if ((tab !== "Expeditions")) {
				return undefined;
			}
			let alive: unknown = true;
			let worker: unknown = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
				while (alive) {
					luaCall(luaProp(task, "wait"), 1);
					if ((!alive)) {
						break;
					}
					luaCall(setNow, colon(game.GetService("Workspace")).GetServerTimeNow());
				}
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				luaCall(pcall, function(): unknown | undefined {
					luaCall(luaProp(task, "cancel"), worker);
					return undefined;
				});
				return undefined;
			};
			return undefined;
		}, [tab]);
		reactLoose.useEffect(function(): unknown | undefined {
			let frame: unknown = luaProp(scrollRef, "current");
			if (frame) {
				luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0));
			}
			return undefined;
		}, [tab]);
		if (((!ops) || (!command))) {
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, reactLoose.createElement(Text, { value: "Loading your crew…", size: 16, color: luaProp(Palette, "muted"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) }));
		}
		return reactLoose.createElement(CommandViewReady, _param);
		return undefined;
	}
	return { CommandView: CommandView };
};

__defs["AdminView"] = () => {
	let HttpService: unknown = colon(game).GetService("HttpService");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _motion: unknown = kit("MotionKit", "motion");
	let useEntrance: unknown = luaProp(_motion, "useEntrance");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let _theme: unknown = kit("CoreKit", "theme");
	let Palette: unknown = luaProp(_theme, "Palette");
	let _adminFields: unknown = kit("CoreKit", "adminFields");
	let fieldsFor: unknown = luaProp(_adminFields, "fieldsFor");
	let reasonsFor: unknown = luaProp(_adminFields, "reasonsFor");
	let compactNumber: unknown = luaProp(kit("CoreKit", "format"), "compactNumber");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let Dropdown: unknown = luaProp(_ui, "Dropdown");
	let EmptyState: unknown = luaProp(_ui, "EmptyState");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let Text: unknown = luaProp(_ui, "Text");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let GAP: unknown = 14;
	let HEADER_H: unknown = 92;
	let PLAYERS_W: unknown = 280;
	let DETAIL_W: unknown = 340;
	let CMD_MIN: unknown = 360;
	let CONSOLE_W: unknown = ((((((PLAYERS_W as unknown as number) + (DETAIL_W as unknown as number)) as unknown as number) + (CMD_MIN as unknown as number)) as unknown as number) + (((GAP as unknown as number) * (2 as unknown as number)) as unknown as number));
	let RECENT_MIN: unknown = 200;
	let PLAYER_ROW: unknown = 56;
	let PLAYER_ROW_STRIDE: unknown = ((PLAYER_ROW as unknown as number) + (6 as unknown as number));
	let COMMAND_ROW: unknown = 48;
	let COMMAND_ROW_STRIDE: unknown = ((COMMAND_ROW as unknown as number) + (6 as unknown as number));
	let SCROLL_BAR: unknown = 4;
	let ADMIN_CATS: unknown = [{ id: "All", label: "ALL" }, { id: "Economy", label: "ECON" }, { id: "Progress", label: "PROG" }, { id: "Items", label: "ITEMS" }, { id: "Resets", label: "RESET" }, { id: "Troll", label: "TROLL" }, { id: "Moderation", label: "MOD" }];
	function hayHas(hay?: unknown, needle?: unknown): unknown | undefined {
		if ((len(needle) === 0)) {
			return true;
		}
		// exact substrings (player IDs) still match; fuzzy matching adds typos and initials
		if (((luaCall(luaProp(string, "find"), luaCall(luaProp(string, "lower"), hay), luaCall(luaProp(string, "lower"), needle), 1, true)) !== undefined)) {
			return true;
		}
		return luaCall(luaProp(mod("BrowseKit"), "matches"), needle, hay);
		return undefined;
	}
	function catAccent(category?: unknown): unknown | undefined {
		if ((category === "Economy")) {
			return luaProp(Palette, "mint");
		}
		if ((category === "Progress")) {
			return luaProp(Palette, "cyan");
		}
		if ((category === "Items")) {
			return luaProp(Palette, "violet");
		}
		if ((category === "Resets")) {
			return luaProp(Palette, "mango");
		}
		if ((category === "Troll")) {
			return luaProp(Palette, "pink");
		}
		if ((category === "Moderation")) {
			return luaProp(Palette, "coral");
		}
		return luaProp(Palette, "steel");
		return undefined;
	}
	function commandNeedsArm(entry?: unknown): unknown | undefined {
		if ((entry === undefined)) {
			return true;
		}
		if ((luaProp(entry, "Danger") === "quick")) {
			return false;
		}
		if ((luaProp(entry, "Danger") === "arm")) {
			return true;
		}
		let category: unknown = (luaProp(entry, "Category") || "Economy");
		return (((category === "Troll") || (category === "Resets")) || (category === "Moderation"));
		return undefined;
	}
	function SectionTitle(_param?: unknown): unknown | undefined {
		return reactLoose.createElement(Text, { value: luaProp(_param, "value"), size: 10, color: luaProp(_param, "accent"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: (luaProp(_param, "position") || luaCall(luaProp(UDim2, "fromOffset"), 0, 0)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 13), layoutOrder: luaProp(_param, "layoutOrder") });
		return undefined;
	}
	function StatCell(_param?: unknown): unknown | undefined {
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement(Text, { value: luaProp(_param, "label"), size: 9, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 6), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 0, 11) }), reactLoose.createElement(Text, { value: luaProp(_param, "value"), size: 14, color: luaProp(_param, "accent"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 7, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 19), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 0, 18) }));
		return undefined;
	}
	function PlayerRow(_param?: unknown): unknown | undefined {
		let player: unknown = luaProp(_param, "player");
		let selected: unknown = luaProp(_param, "selected");
		let you: unknown = luaProp(_param, "you");
		let onClick: unknown = luaProp(_param, "onClick");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let accent: unknown = (selected ? luaProp(Palette, "mint") : luaProp(Palette, "lineSoft"));
		let reveal: unknown = luaCall(useStagger, layoutOrder, reducedMotion);
		return reactLoose.createElement("textbutton", { LayoutOrder: layoutOrder, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, PLAYER_ROW), BackgroundTransparency: colon(reveal).map(function(amount?: unknown): unknown | undefined {
			return ((((selected ? 0 : 0.12)) as unknown as number) + ((((((1 as unknown as number) - (luaCall(luaProp(math, "clamp"), amount, 0, 1) as unknown as number))) as unknown as number) * ((((1 as unknown as number) - (((selected ? 0 : 0.12)) as unknown as number))) as unknown as number)) as unknown as number));
			return undefined;
		}), BackgroundColor3: (selected ? luaProp(Palette, "panelRaised") : luaProp(Palette, "panel")), BorderSizePixel: 0, Text: "", AutoButtonColor: false, Active: true, Selectable: true, Event: { Activated: function(): unknown | undefined {
			colon(Audio).play("playerlistSelect");
			luaCall(onClick);
			return undefined;
		} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: accent, Thickness: 1, Transparency: (selected ? 0.45 : 1) }), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 36, 36), Position: luaCall(luaProp(UDim2, "fromOffset"), 12, 10), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement(Icon, { kind: "Crew.10", color: (selected ? luaProp(Palette, "mint") : luaProp(Palette, "muted")), accent: luaProp(Palette, "mint"), size: 18, spin: false, position: luaCall(luaProp(UDim2, "fromOffset"), 9, 9) })), reactLoose.createElement(Text, { value: (you ? `${luaProp(player, "DisplayName")}  ·  YOU` : luaProp(player, "DisplayName")), size: 13, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 9), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0, 17) }), reactLoose.createElement(Text, { value: `@${luaProp(player, "Name")}  ·  ${luaCall(compactNumber, (luaProp(player, "Cash") || 0))}`, size: 10, color: luaProp(Palette, "cyan"), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -70, 0, 14) }), (selected && reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0.5, -4), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "mint"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }))));
		return undefined;
	}
	function CommandRow(_param?: unknown): unknown | undefined {
		let entry: unknown = luaProp(_param, "entry");
		let selected: unknown = luaProp(_param, "selected");
		let onClick: unknown = luaProp(_param, "onClick");
		let accent: unknown = luaCall(catAccent, luaProp(entry, "Category"));
		let arm: unknown = luaCall(commandNeedsArm, entry);
		return reactLoose.createElement("textbutton", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, ((COMMAND_ROW as unknown as number) - (6 as unknown as number))), BackgroundColor3: (selected ? luaProp(Palette, "panelRaised") : luaProp(Palette, "panel")), BackgroundTransparency: (selected ? 0 : 0.08), BorderSizePixel: 0, Text: "", AutoButtonColor: false, Active: true, Selectable: true, Event: { Activated: function(): unknown | undefined {
			colon(Audio).play("tabSwitch");
			luaCall(onClick);
			return undefined;
		} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 9) }), reactLoose.createElement("uistroke", { Color: (selected ? accent : luaProp(Palette, "line")), Thickness: 1, Transparency: (selected ? 0.3 : 0.78) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 4, 1, -14), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 7), BackgroundColor3: accent, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })), reactLoose.createElement(Text, { value: luaProp(entry, "Label"), size: 12, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 15, 6), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -104, 0, 16) }), reactLoose.createElement(Text, { value: luaCall(luaProp(string, "upper"), (luaProp(entry, "Category") || "ECON")), size: 9, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), fit: false, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -92, 0, 7), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 80, 12) }), reactLoose.createElement(Text, { value: (arm ? "ARM" : "RUN"), size: 8, color: (arm ? luaProp(Palette, "mango") : luaProp(Palette, "mint")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), fit: false, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -92, 0, 21), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 80, 12) }));
		return undefined;
	}
	function AuditLine(_param?: unknown): unknown | undefined {
		let record: unknown = luaProp(_param, "record");
		return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement(Text, { value: luaProp(record, "Command"), size: 10, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 8, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.42, -4, 1, 0) }), reactLoose.createElement(Text, { value: `${luaProp(record, "ActorName")} → ${luaProp(record, "TargetName")}`, size: 9, color: luaProp(Palette, "cyan"), fit: true, minSize: 8, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.42, 4, 0, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.58, -4, 1, 0) }));
		return undefined;
	}
	function AdminViewReady(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let admin: unknown = luaProp(state, "Admin");
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let targetId: unknown;
		let setTargetId: unknown;
		[targetId, setTargetId] = reactLoose.useState(((((admin && luaProp(admin, "SelfUserId"))) || ((((admin && luaProp(admin, "Online")) && luaIndex(luaProp(admin, "Online"), 1)) && luaProp(luaIndex(luaProp(admin, "Online"), 1), "UserId")))) || 0)) as LuaTuple<[unknown, unknown]>;
		let command: unknown;
		let setCommand: unknown;
		[command, setCommand] = reactLoose.useState((((((admin && luaProp(admin, "Commands")) && luaIndex(luaProp(admin, "Commands"), 1)) && luaProp(luaIndex(luaProp(admin, "Commands"), 1), "Id"))) || "GrantFlux")) as LuaTuple<[unknown, unknown]>;
		let category: unknown;
		let setCategory: unknown;
		[category, setCategory] = reactLoose.useState("All") as LuaTuple<[unknown, unknown]>;
		let playerQuery: unknown;
		let setPlayerQuery: unknown;
		[playerQuery, setPlayerQuery] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let commandQuery: unknown;
		let setCommandQuery: unknown;
		[commandQuery, setCommandQuery] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let amount: unknown;
		let setAmount: unknown;
		[amount, setAmount] = reactLoose.useState("1000") as LuaTuple<[unknown, unknown]>;
		let option: unknown;
		let setOption: unknown;
		[option, setOption] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let reason: unknown;
		let setReason: unknown;
		[reason, setReason] = reactLoose.useState(luaProp(luaIndex(luaCall(reasonsFor, "GrantFlux", "Economy"), 1), "id")) as LuaTuple<[unknown, unknown]>;
		let armed: unknown;
		let setArmed: unknown;
		[armed, setArmed] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let busy: unknown;
		let setBusy: unknown;
		[busy, setBusy] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let busyRef: unknown = reactLoose.useRef(false);
		let shakeToken: unknown;
		let setShakeToken: unknown;
		[shakeToken, setShakeToken] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let lastNote: unknown;
		let setLastNote: unknown;
		[lastNote, setLastNote] = reactLoose.useState(((((admin && luaProp(admin, "LastAction")) && luaProp(luaProp(admin, "LastAction"), "Message"))) || "")) as LuaTuple<[unknown, unknown]>;
		let lastOk: unknown;
		let setLastOk: unknown;
		[lastOk, setLastOk] = reactLoose.useState(((((admin && luaProp(admin, "LastAction")) && luaProp(luaProp(admin, "LastAction"), "Ok"))) || true)) as LuaTuple<[unknown, unknown]>;
		let previewLines: unknown;
		let setPreviewLines: unknown;
		[previewLines, setPreviewLines] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let mountedRef: unknown = reactLoose.useRef(true);
		let executeAttempt: unknown = reactLoose.useRef(0);
		let enter: unknown = luaCall(useEntrance, softMotion);
		let toolsReveal: unknown = luaCall(useStagger, 0, softMotion);
		reactLoose.useEffect(function(): unknown | undefined {
			return function(): unknown | undefined {
				luaSet(mountedRef, "current", false);
				luaSet(executeAttempt, "current", ((luaProp(executeAttempt, "current") as unknown as number) + (1 as unknown as number)));
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			if ((((targetId === 0) && admin) && luaProp(admin, "SelfUserId"))) {
				luaCall(setTargetId, luaProp(admin, "SelfUserId"));
			}
			return undefined;
		}, [(admin && luaProp(admin, "SelfUserId")), targetId]);
		reactLoose.useEffect(function(): unknown | undefined {
			let online: unknown = (((admin && luaProp(admin, "Online"))) || {});
			if ((len(online) === 0)) {
				return;
			}
			let found: unknown = false;
			for (const [_, p] of pairs((online) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(p, "UserId") === targetId)) {
					found = true;
					break;
				}
			}
			if ((!found)) {
				luaCall(setTargetId, (((admin && luaProp(admin, "SelfUserId"))) || luaProp(luaIndex(online, 1), "UserId")));
			}
			return undefined;
		}, [(admin && luaProp(admin, "Online")), (admin && luaProp(admin, "SelfUserId")), targetId]);
		reactLoose.useEffect(function(): unknown | undefined {
			let commands: unknown = (((admin && luaProp(admin, "Commands"))) || {});
			if ((len(commands) === 0)) {
				return;
			}
			let found: unknown = false;
			for (const [_, c] of pairs((commands) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(c, "Id") === command)) {
					found = true;
					break;
				}
			}
			if ((!found)) {
				luaCall(setCommand, (luaProp(luaIndex(commands, 1), "Id") || "GrantFlux"));
			}
			return undefined;
		}, [(admin && luaProp(admin, "Commands")), command]);
		reactLoose.useEffect(function(): unknown | undefined {
			luaCall(setArmed, false);
			luaCall(setPreviewLines, {});
			return undefined;
		}, [amount, command, option, reason, targetId]);
		reactLoose.useEffect(function(): unknown | undefined {
			let layout: unknown = luaCall(fieldsFor, command, config, (admin && luaProp(admin, "Banned")));
			let commands: unknown = (((admin && luaProp(admin, "Commands"))) || {});
			let current: unknown = undefined;
			for (const [_, c] of pairs((commands) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(c, "Id") === command)) {
					current = c;
					break;
				}
			}
			let reasonChoices: unknown = luaCall(reasonsFor, command, (current && luaProp(current, "Category")));
			luaCall(setAmount, luaProp(layout, "defaultAmount"));
			luaCall(setOption, luaProp(layout, "defaultOption"));
			luaCall(setReason, ((luaIndex(reasonChoices, 1) && luaProp(luaIndex(reasonChoices, 1), "id")) || "Owner gameplay administration"));
			if ((luaProp(layout, "overridesTarget") && (luaProp(layout, "defaultAmount") !== ""))) {
				let userId: unknown = luaCall(tonumber, luaProp(layout, "defaultAmount"));
				if (userId) {
					luaCall(setTargetId, userId);
				}
			}
			return undefined;
		}, [command]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!((admin && luaProp(admin, "LastAction"))))) {
				return;
			}
			luaCall(setLastNote, luaProp(luaProp(admin, "LastAction"), "Message"));
			luaCall(setLastOk, luaProp(luaProp(admin, "LastAction"), "Ok"));
			return undefined;
		}, [(admin && luaProp(admin, "LastAction"))]);
		let online: unknown = (luaProp(admin, "Online") || {});
		let commands: unknown = (luaProp(admin, "Commands") || {});
		let shownPlayers: unknown = {};
		for (const [_, p] of pairs((online) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (luaCall(hayHas, `${luaProp(p, "DisplayName")} ${luaProp(p, "Name")} ${luaProp(p, "UserId")}`, playerQuery)) {
				luaTable.insert(shownPlayers, p);
			}
		}
		let shownCommands: unknown = {};
		for (const [_, c] of pairs((commands) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let catOk: unknown = ((category === "All") || (((luaProp(c, "Category") || "Economy")) === category));
			if ((catOk && luaCall(hayHas, `${luaProp(c, "Id")} ${luaProp(c, "Label")} ${(luaProp(c, "Category") || "")}`, commandQuery))) {
				luaTable.insert(shownCommands, c);
			}
		}
		let recent: unknown = (luaProp(admin, "Recent") || {});
		let selected: unknown = undefined;
		for (const [_, c] of pairs((commands) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaProp(c, "Id") === command)) {
				selected = c;
				break;
			}
		}
		let selectedPlayer: unknown = undefined;
		for (const [_, p] of pairs((online) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaProp(p, "UserId") === targetId)) {
				selectedPlayer = p;
				break;
			}
		}
		let fields: unknown = luaCall(fieldsFor, command, config, luaProp(admin, "Banned"));
		let needsArm: unknown = luaCall(commandNeedsArm, selected);
		let accent: unknown = luaCall(catAccent, (selected && luaProp(selected, "Category")));
		let integrity: unknown = luaProp(admin, "Integrity");
		let reasonChoices: unknown = luaCall(reasonsFor, command, (selected && luaProp(selected, "Category")));
		let fieldSlots: unknown = ((((((luaProp(fields, "usesAmount") ? 1 : 0)) as unknown as number) + (((luaProp(fields, "usesOption") ? 1 : 0)) as unknown as number)) as unknown as number) + (((needsArm ? 1 : 0)) as unknown as number));
		let send: unknown = function(dryRun?: unknown): unknown | undefined {
			luaSet(busyRef, "current", true);
			luaCall(setBusy, true);
			let attempt: unknown = ((luaProp(executeAttempt, "current") as unknown as number) + (1 as unknown as number));
			luaSet(executeAttempt, "current", attempt);
			colon(Audio).play((dryRun ? "click" : "adminExecute"));
			let sendAmount: unknown = ((amount === "Permanent") ? "1" : (((amount !== "") ? amount : "1")));
			let sendOption: unknown = ((amount === "Permanent") ? "Permanent" : option);
			let sendTarget: unknown = (luaProp(fields, "overridesTarget") ? ((luaCall(tonumber, amount) || targetId)) : targetId);
			luaCall(dispatch, "AdminExecute", { TargetUserId: sendTarget, Command: command, Amount: sendAmount, Option: sendOption, Reason: reason, DryRun: dryRun, Nonce: colon(HttpService).GenerateGUID(false) }, function(response?: unknown): unknown | undefined {
				if (((!luaProp(mountedRef, "current")) || (luaProp(executeAttempt, "current") !== attempt))) {
					return;
				}
				luaSet(busyRef, "current", false);
				luaCall(setBusy, false);
				if ((!dryRun)) {
					luaCall(setArmed, false);
				}
				luaCall(setLastOk, (luaProp(response, "ok") === true));
				luaCall(setLastNote, ((luaProp(response, "ok") === true) ? ((luaProp(response, "message") || "Done.")) : ((luaProp(response, "error") || "Failed."))));
				luaCall(setPreviewLines, (((dryRun && (luaProp(response, "ok") === true)) && (luaTypeIs(luaProp(response, "Preview"), "table"))) ? luaProp(response, "Preview") : {}));
				if ((luaProp(response, "ok") !== true)) {
					luaCall(setShakeToken, function(t?: unknown): unknown | undefined {
						return ((t as unknown as number) + (1 as unknown as number));
						return undefined;
					});
				}
				return undefined;
			});
			return undefined;
		};
		let execute: unknown = function(): unknown | undefined {
			if (luaProp(busyRef, "current")) {
				return;
			}
			if ((needsArm && (!armed))) {
				luaCall(setArmed, true);
				colon(Audio).play("adminArm");
				return;
			}
			luaCall(send, false);
			return undefined;
		};
		let preview: unknown = function(): unknown | undefined {
			if (luaProp(busyRef, "current")) {
				return;
			}
			luaCall(send, true);
			return undefined;
		};
		let runDisabled: unknown = ((busy || ((luaProp(fields, "overridesTarget") ? (len(luaProp(fields, "amountChoices")) === 0) : (targetId === 0)))) || ((needsArm && ((len(reason) as unknown as number) < (3 as unknown as number)))));
		let runLabel: unknown = (busy ? "APPLYING…" : ((needsArm && (!armed)) ? "ARM" : "RUN"));
		let runColor: unknown = (busy ? luaProp(Palette, "panelSoft") : ((needsArm && armed) ? luaProp(Palette, "coral") : (needsArm ? luaProp(Palette, "mango") : luaProp(Palette, "mint"))));
		let FIELD_H: unknown = 50;
		let EXEC_TITLE: unknown = 42;
		let EXEC_BUTTON: unknown = 46;
		let EXEC_NOTE: unknown = ((36 as unknown as number) + (((luaCall(luaProp(math, "min"), len(previewLines), 6) as unknown as number) * (14 as unknown as number)) as unknown as number));
		let executeH: unknown = ((((((((EXEC_TITLE as unknown as number) + (((luaCall(luaProp(math, "max"), 0, fieldSlots) as unknown as number) * (FIELD_H as unknown as number)) as unknown as number)) as unknown as number) + (EXEC_BUTTON as unknown as number)) as unknown as number) + (EXEC_NOTE as unknown as number)) as unknown as number) + (20 as unknown as number));
		let INSPECT_TITLE: unknown = 34;
		let STAT_H: unknown = 40;
		let STAT_GAP: unknown = 8;
		let inspectH: unknown = ((((((INSPECT_TITLE as unknown as number) + (((STAT_H as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (STAT_GAP as unknown as number)) as unknown as number) + (26 as unknown as number));
		let header: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, HEADER_H), accent: luaProp(Palette, "coral"), background: luaProp(Palette, "panel"), padding: 12, layoutOrder: 0, reveal: enter, reducedMotion: softMotion, clips: false }, reactLoose.createElement(Text, { value: "ADMIN", size: 9, color: luaProp(Palette, "coral"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 70, 0, 12) }), reactLoose.createElement(Text, { value: "Owner Console", size: 16, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 13), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -340, 0, 22) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -120, 0, 22), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 36), BackgroundTransparency: 1 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), reactLoose.createElement(Badge, { value: (luaProp(admin, "Role") || "ADMIN"), accent: luaProp(Palette, "coral"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 108, 22) }), reactLoose.createElement(Badge, { value: ((((integrity && luaProp(integrity, "Healthy"))) === false) ? "RESTORED" : "HEALTHY"), accent: ((((integrity && luaProp(integrity, "Healthy"))) === false) ? luaProp(Palette, "mango") : luaProp(Palette, "mint")), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 84, 22) }), ((selectedPlayer && (luaProp(selectedPlayer, "Unlimited") === true)) && reactLoose.createElement(Badge, { value: "UNLIMITED", accent: luaProp(Palette, "violet"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 88, 22) }))), reactLoose.createElement(Button, { text: "REFRESH", onClick: function(): unknown | undefined {
			luaCall(dispatch, "GetAdminState");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "mint"), outline: true, size: luaCall(luaProp(UDim2, "fromOffset"), 104, 32), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -104, 0, 3), reducedMotion: softMotion }));
		let playerSection: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "cyan"), background: luaProp(Palette, "panel"), padding: 12, layoutOrder: 1, clips: false }, reactLoose.createElement(SectionTitle, { value: "PLAYERS", accent: luaProp(Palette, "cyan") }), reactLoose.createElement(SearchField, { value: playerQuery, onChange: setPlayerQuery, accent: luaProp(Palette, "cyan"), placeholder: "Search players…", size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), reducedMotion: softMotion }), luaCall((function(): unknown | undefined {
			let listSize: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -64);
			let listPos: unknown = luaCall(luaProp(UDim2, "fromOffset"), 0, 64);
			if ((len(shownPlayers) === 0)) {
				return reactLoose.createElement("frame", { Size: listSize, Position: listPos, BackgroundTransparency: 1 }, reactLoose.createElement(Text, { value: "No players match.", size: 11, color: luaProp(Palette, "muted") }));
			}
			return reactLoose.createElement(FlatList, { data: shownPlayers, itemHeight: PLAYER_ROW_STRIDE, overscan: (softMotion ? 0 : (luaProp(antilag, "constrained") ? 1 : 2)), canvasTail: 4, Size: listSize, Position: listPos, scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: SCROLL_BAR, keyExtractor: function(player?: unknown): unknown | undefined {
				return luaCall(tostring, luaProp(player, "UserId"));
				return undefined;
			}, renderItem: function(_param?: unknown): unknown | undefined {
				let player: unknown = luaProp(_param, "item");
				let index: unknown = luaProp(_param, "index");
				return reactLoose.createElement(PlayerRow, { player: player, selected: (luaProp(player, "UserId") === targetId), you: (luaProp(player, "UserId") === luaProp(admin, "SelfUserId")), onClick: function(): unknown | undefined {
					luaCall(setTargetId, luaProp(player, "UserId"));
					return undefined;
				}, layoutOrder: ((index as unknown as number) + (1 as unknown as number)), reducedMotion: softMotion });
				return undefined;
			} });
			return undefined;
		})));
		let commandSection: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panel"), padding: 12, layoutOrder: 2, clips: false }, reactLoose.createElement(SectionTitle, { value: "COMMANDS", accent: luaProp(Palette, "violet") }), reactLoose.createElement(SearchField, { value: commandQuery, onChange: setCommandQuery, accent: luaProp(Palette, "violet"), placeholder: "Search commands…", size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), reducedMotion: softMotion }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 30), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 62), BackgroundTransparency: 1, ClipsDescendants: true }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), luaCall((function(): unknown | undefined {
			let pills: unknown = luaCall(luaProp(table, "create"), len(ADMIN_CATS));
			for (const [i, cat] of pairs((ADMIN_CATS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(pills, i, reactLoose.createElement(Button, { key: luaProp(cat, "id"), text: luaProp(cat, "label"), onClick: function(): unknown | undefined {
					luaCall(setCategory, luaProp(cat, "id"));
					return undefined;
				}, color: ((category === luaProp(cat, "id")) ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), textColor: ((category === luaProp(cat, "id")) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), outline: (category !== luaProp(cat, "id")), highlight: (category === luaProp(cat, "id")), size: luaCall(luaProp(UDim2, "fromOffset"), 62, 28), reducedMotion: softMotion }));
			}
			return pills;
			return undefined;
		}))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -100), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 100), BackgroundTransparency: 1 }, (((len(shownCommands) === 0) && reactLoose.createElement(Text, { value: "Nothing matches that filter.", size: 11, color: luaProp(Palette, "muted") })) || reactLoose.createElement(FlatList, { data: shownCommands, itemHeight: COMMAND_ROW_STRIDE, overscan: (softMotion ? 0 : (luaProp(antilag, "constrained") ? 1 : 2)), canvasTail: 4, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: SCROLL_BAR, keyExtractor: function(entry?: unknown): unknown | undefined {
			return luaProp(entry, "Id");
			return undefined;
		}, renderItem: function(_param?: unknown): unknown | undefined {
			let entry: unknown = luaProp(_param, "item");
			let index: unknown = luaProp(_param, "index");
			return reactLoose.createElement(CommandRow, { entry: entry, selected: (luaProp(entry, "Id") === command), onClick: function(): unknown | undefined {
				luaCall(setCommand, luaProp(entry, "Id"));
				return undefined;
			}, layoutOrder: ((index as unknown as number) + (1 as unknown as number)) });
			return undefined;
		} }))));
		let inspectSection: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, inspectH), accent: luaProp(Palette, "mint"), background: luaProp(Palette, "panel"), padding: 12, layoutOrder: 0, clips: false }, reactLoose.createElement(SectionTitle, { value: "TARGET", accent: luaProp(Palette, "mint") }), reactLoose.createElement(Text, { value: (selectedPlayer ? `${luaProp(selectedPlayer, "DisplayName")}  ·  ${luaProp(selectedPlayer, "UserId")}` : "Select a player."), size: 12, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 15), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((((STAT_H as unknown as number) * (2 as unknown as number)) as unknown as number) + (STAT_GAP as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, INSPECT_TITLE), BackgroundTransparency: 1 }, reactLoose.createElement("uigridlayout", { CellSize: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -6, 0, STAT_H), CellPadding: luaCall(luaProp(UDim2, "fromOffset"), STAT_GAP, STAT_GAP), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal") }), reactLoose.createElement(StatCell, { label: "CASH", value: ((selectedPlayer && luaCall(compactNumber, (luaProp(selectedPlayer, "Cash") || 0))) || "--"), accent: luaProp(Palette, "cyan") }), reactLoose.createElement(StatCell, { label: "VAULT", value: ((selectedPlayer && `${luaCall(compactNumber, (luaProp(selectedPlayer, "Vault") || 0))}/${luaCall(compactNumber, (luaProp(selectedPlayer, "Capacity") || 0))}`) || "--"), accent: luaProp(Palette, "mint") }), reactLoose.createElement(StatCell, { label: "CORES", value: ((selectedPlayer && luaCall(compactNumber, (luaProp(selectedPlayer, "Cores") || 0))) || "--"), accent: luaProp(Palette, "violet") }), reactLoose.createElement(StatCell, { label: "REBIRTHS", value: ((selectedPlayer && luaCall(compactNumber, (luaProp(selectedPlayer, "Rebirths") || 0))) || "--"), accent: luaProp(Palette, "pink") }), reactLoose.createElement(StatCell, { label: "WORLD", value: ((selectedPlayer && luaCall(tostring, (luaProp(selectedPlayer, "Zone") || 1))) || "--"), accent: luaProp(Palette, "mango") }), reactLoose.createElement(StatCell, { label: "RATE", value: ((selectedPlayer && `${luaCall(compactNumber, (luaProp(selectedPlayer, "Production") || 0))}/s`) || "--"), accent: luaProp(Palette, "cyan") }), reactLoose.createElement(StatCell, { label: "DUST", value: ((selectedPlayer && luaCall(compactNumber, (luaProp(selectedPlayer, "Stardust") || 0))) || "--"), accent: luaProp(Palette, "steel") }), reactLoose.createElement(StatCell, { label: "KEYS", value: ((selectedPlayer && luaCall(compactNumber, (luaProp(selectedPlayer, "Keys") || 0))) || "--"), accent: luaProp(Palette, "violet") })));
		let executeActionsHostRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!luaProp(UserInputService, "GamepadEnabled"))) {
				return undefined;
			}
			let host: unknown = luaProp(executeActionsHostRef, "current");
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
		}, [command, armed, busy, targetId]);
		let executeDock: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, executeH), accent: (armed ? luaProp(Palette, "coral") : accent), background: luaProp(Palette, "panelRaised"), padding: 12, layoutOrder: 1, highlight: armed, reveal: toolsReveal, reducedMotion: softMotion, clips: false }, reactLoose.createElement(SectionTitle, { value: (needsArm ? "OFF" : "READY"), accent: (armed ? luaProp(Palette, "coral") : accent) }), reactLoose.createElement(Text, { value: (((selected && luaProp(selected, "Label"))) || command), size: 15, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 10, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 15), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, luaCall(luaProp(math, "max"), 0, ((((fieldSlots as unknown as number) * (FIELD_H as unknown as number)) as unknown as number) - (6 as unknown as number)))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, EXEC_TITLE), BackgroundTransparency: 1, ZIndex: 50 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), (luaProp(fields, "usesAmount") && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((FIELD_H as unknown as number) - (6 as unknown as number))), BackgroundTransparency: 1, LayoutOrder: 0, ZIndex: 52 }, reactLoose.createElement(Dropdown, { options: luaProp(fields, "amountChoices"), value: amount, onChange: function(id?: unknown): unknown | undefined {
			luaCall(setAmount, id);
			if (luaProp(fields, "overridesTarget")) {
				let uid: unknown = luaCall(tonumber, id);
				if (uid) {
					luaCall(setTargetId, uid);
				}
			}
			return undefined;
		}, accent: luaProp(Palette, "mango"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion, zIndex: 80 }))), (luaProp(fields, "usesOption") && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((FIELD_H as unknown as number) - (6 as unknown as number))), BackgroundTransparency: 1, LayoutOrder: 1, ZIndex: 51 }, reactLoose.createElement(Dropdown, { options: luaProp(fields, "optionChoices"), value: option, onChange: setOption, accent: luaProp(Palette, "cyan"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion, zIndex: 70 }))), (needsArm && reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((FIELD_H as unknown as number) - (6 as unknown as number))), BackgroundTransparency: 1, LayoutOrder: 2, ZIndex: 50 }, reactLoose.createElement(Dropdown, { options: reasonChoices, value: reason, onChange: setReason, accent: luaProp(Palette, "steel"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion, zIndex: 60 })))), reactLoose.createElement("frame", { Name: "AdminExecuteActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, EXEC_BUTTON), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((EXEC_TITLE as unknown as number) + (((fieldSlots as unknown as number) * (FIELD_H as unknown as number)) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: executeActionsHostRef }, reactLoose.createElement("frame", { Name: "AdminPreviewRun", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.34, -5, 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(Button, { text: "PREVIEW", icon: "Search.8", onClick: preview, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "text"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 48), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 0.5, -24), disabled: runDisabled, reducedMotion: softMotion })), reactLoose.createElement("frame", { Name: "AdminConfirmRun", ClipsDescendants: false, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.66, -5, 1, 0), Position: ((luaCall(luaProp(UDim2, "fromScale"), 0.34, 0) as unknown as number) + (luaCall(luaProp(UDim2, "fromOffset"), 5, 0) as unknown as number)), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Button, { text: runLabel, icon: "Lock.16", onClick: execute, color: runColor, textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 48), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 0.5, -24), disabled: runDisabled, loading: busy, shakeToken: shakeToken, highlight: (armed || (!needsArm)), reducedMotion: softMotion }))), reactLoose.createElement(Text, { value: concat((((lastNote !== "") ? lastNote : ((needsArm ? "Arm first. Dangerous commands need a second tap." : "Preview shows saved changes first. Run applies them.")))), ((((len(previewLines) as unknown as number) > (0 as unknown as number)) ? concat("\n• ", luaTable.concat(previewLines, "\n• ", 1, luaCall(luaProp(math, "min"), len(previewLines), 6))) : ""))), size: 9, color: ((lastNote !== "") ? ((lastOk ? luaProp(Palette, "mint") : luaProp(Palette, "coral"))) : luaProp(Palette, "muted")), wrap: true, fit: false, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (((-(EXEC_NOTE as unknown as number)) as unknown as number) + (4 as unknown as number))), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((EXEC_NOTE as unknown as number) - (4 as unknown as number))) }));
		let recentSection: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "steel"), background: luaProp(Palette, "panel"), padding: 12, layoutOrder: 2, clips: false }, reactLoose.createElement(SectionTitle, { value: "RECENT", accent: luaProp(Palette, "steel") }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -20), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), BackgroundTransparency: 1, ClipsDescendants: true }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 3) }), (((len(recent) === 0) && reactLoose.createElement(Text, { value: "No commands run yet.", size: 11, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 6), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) })) || luaCall((function(): unknown | undefined {
			let rows: unknown = luaCall(luaProp(table, "create"), luaCall(luaProp(math, "min"), 6, len(recent)));
			{
				const _forStart_1 = (1 as unknown as number);
				const _forEnd_1 = (luaCall(luaProp(math, "min"), 6, len(recent)) as unknown as number);
				const _forStep_1 = (1 as unknown as number);
				for (let i = _forStart_1; _forStep_1 >= 0 ? i <= _forEnd_1 : i >= _forEnd_1; i += _forStep_1) {
					luaSetIndex(rows, i, reactLoose.createElement(AuditLine, { key: luaProp(luaIndex(recent, i), "Id"), record: luaIndex(recent, i) }));
				}
			}
			return rows;
			return undefined;
		})))));
		let BODY_H: unknown = ((((((((inspectH as unknown as number) + (GAP as unknown as number)) as unknown as number) + (executeH as unknown as number)) as unknown as number) + (GAP as unknown as number)) as unknown as number) + (RECENT_MIN as unknown as number));
		let consoleBody: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uisizeconstraint", { MinSize: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(CONSOLE_W, BODY_H) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, PLAYERS_W, 1, 0), BackgroundTransparency: 1 }, playerSection), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, DETAIL_W, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(DETAIL_W as unknown as number)), 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, inspectH), BackgroundTransparency: 1 }, inspectSection), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, executeH), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((inspectH as unknown as number) + (GAP as unknown as number))), BackgroundTransparency: 1 }, executeDock), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-((((((inspectH as unknown as number) + (executeH as unknown as number)) as unknown as number) + (((GAP as unknown as number) * (2 as unknown as number)) as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((((inspectH as unknown as number) + (executeH as unknown as number)) as unknown as number) + (((GAP as unknown as number) * (2 as unknown as number)) as unknown as number))), BackgroundTransparency: 1, ClipsDescendants: true }, reactLoose.createElement("uisizeconstraint", { MinSize: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, RECENT_MIN) }), recentSection)), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((PLAYERS_W as unknown as number) + (DETAIL_W as unknown as number)) as unknown as number) + (((GAP as unknown as number) * (2 as unknown as number)) as unknown as number))) as unknown as number)), 1, 0), Position: luaCall(luaProp(UDim2, "fromOffset"), ((PLAYERS_W as unknown as number) + (GAP as unknown as number)), 0), BackgroundTransparency: 1 }, commandSection));
		return reactLoose.createElement(PageScaffold, { gap: GAP, tailPad: 8, scrollBarColor: luaProp(Palette, "steel"), scrollBarThickness: 4, sections: [{ id: "header", height: HEADER_H, element: header }, { id: "console", fill: true, minHeight: BODY_H, element: consoleBody }] });
		return undefined;
	}
	function AdminView(_param?: unknown): unknown | undefined {
		let admin: unknown = luaProp(luaProp(_param, "state"), "Admin");
		if ((!((admin && (luaProp(admin, "Access") === true))))) {
			return reactLoose.createElement(EmptyState, { icon: "Lock.17", title: "Owner tools locked", body: "Only the game owner can open this page.", accent: luaProp(Palette, "coral") });
		}
		return reactLoose.createElement(AdminViewReady, _param);
		return undefined;
	}
	return { AdminView: AdminView };
};

__defs["AnomalyView"] = () => {
	return { AnomalyView: luaProp(mod("PlanningViews"), "ShiftPlan") };
};

__defs["LeaderboardsView"] = () => {
	let _format: unknown = kit("CoreKit", "format");
	let asFlux: unknown = luaProp(_format, "asFlux");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let clockText: unknown = luaProp(_format, "clockText");
	let Palette: unknown = luaProp(kit("CoreKit", "theme"), "Palette");
	let BOARDS: unknown = [{ id: "Flux", label: "Lifetime Flux", short: "FLUX", description: "All the flux you have ever made.", icon: "Flux.16", accent: luaProp(Palette, "cyan") }, { id: "Rebirths", label: "Most Rebirths", short: "REBIRTHS", description: "Pilots who have restarted the forge the most.", icon: "Rebirth.6", accent: luaProp(Palette, "violet") }, { id: "PlayTime", label: "Time Played", short: "PLAYTIME", description: "Total time spent playing.", icon: "Command.4", accent: luaProp(Palette, "mint") }, { id: "Dust", label: "Most Stardust", short: "DUST", description: "Current stardust reserves held by each pilot.", icon: "Dust.10", accent: luaProp(Palette, "mango") }, { id: "Cores", label: "Most Cores", short: "CORES", description: "Current astral cores ready for permanent upgrades.", icon: "Core.7", accent: luaProp(Palette, "violet") }, { id: "Domain", label: "Domain Rank", short: "DOMAIN", description: "The highest Domain rank reached.", icon: "Domain.4", accent: luaProp(Palette, "pink") }, { id: "Worlds", label: "Farthest World", short: "WORLDS", description: "The farthest forge worlds unlocked.", icon: "World.8", accent: luaProp(Palette, "green"), group: "Progression" }, { id: "Crates", label: "Crates Opened", short: "CRATES", description: "Every sealed crate cracked open, any tier, any skin.", icon: "Crate.12", accent: luaProp(Palette, "mango"), group: "Collection" }, { id: "Finds", label: "Items Found", short: "FINDS", description: "Relics, tools and oddities pulled into the vault.", icon: "Artifact.7", accent: luaProp(Palette, "cyan"), group: "Collection" }, { id: "Ore", label: "Ore Mined", short: "ORE", description: "Raw ore hauled out of the deep veins.", icon: "Forge.21", accent: luaProp(Palette, "mango"), group: "Activity" }, { id: "Wardens", label: "Wardens Felled", short: "WARDENS", description: "Vault wardens brought down in combat.", icon: "Milestone.4", accent: luaProp(Palette, "pink"), group: "Activity" }, { id: "Orders", label: "Orders Filled", short: "ORDERS", description: "Contracts and work orders delivered on time.", icon: "Mission.7", accent: luaProp(Palette, "mint"), group: "Activity" }, { id: "Stars", label: "Ore Cuts", short: "CUTS", description: "Completed ore cuts. Includes progress earned before the workshop redesign.", icon: "Dust.11", accent: luaProp(Palette, "violet"), group: "Activity" }, { id: "Cipher", label: "Commissions Finished", short: "COMMISSIONS", description: "Daily forge commissions finished. Previous puzzle completions remain counted.", icon: "Forge.22", accent: luaProp(Palette, "cyan"), group: "Activity" }];
	let BOARD_GROUP: unknown = { Flux: "Economy", Dust: "Economy", Cores: "Economy", Rebirths: "Progression", Domain: "Progression", PlayTime: "Activity" };
	for (const [_, board] of pairs((BOARDS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSet(board, "group", ((luaProp(board, "group") || luaIndex(BOARD_GROUP, luaProp(board, "id"))) || "Progression"));
	}
	let STAT_BOARD_KEYS: unknown = { Crates: "CratesOpened", Finds: "ItemsFound", Ore: "OreMined", Wardens: "WardenDefeats", Orders: "OrdersCompleted" };
	function metaFor(id?: unknown): unknown | undefined {
		let _callback_1: unknown = function(board?: unknown): unknown | undefined {
			return (luaProp(board, "id") === id);
			return undefined;
		};
		let _result: unknown;
		for (const [_i, _v] of pairs((BOARDS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback_1, _v, ((_i as unknown as number) - (1 as unknown as number)), BOARDS) === true)) {
				_result = _v;
				break;
			}
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = luaIndex(BOARDS, 1);
		}
		return _condition;
		return undefined;
	}
	function formatValue(id?: unknown, value?: unknown): unknown | undefined {
		if ((id === "PlayTime")) {
			let _value: unknown = value;
			return luaCall(clockText, ((luaTypeIs(_value, "number")) ? value : luaCall(asFlux, value)));
		}
		if ((id === "Worlds")) {
			return `WORLD ${luaCall(luaProp(math, "max"), 1, luaCall(luaProp(math, "floor"), luaCall(asFlux, value)))}`;
		}
		if ((id === "Domain")) {
			let rank: unknown = luaCall(luaProp(math, "floor"), luaCall(asFlux, value));
			return (((rank as unknown as number) > (0 as unknown as number)) ? `RANK ${rank}` : "UNRANKED");
		}
		return luaCall(compactNumber, value);
		return undefined;
	}
	function scoreCounts(id?: unknown, value?: unknown): unknown | undefined {
		if ((id === "Worlds")) {
			return ((luaCall(asFlux, value) as unknown as number) > (1 as unknown as number));
		}
		return ((luaCall(asFlux, value) as unknown as number) > (0 as unknown as number));
		return undefined;
	}
	function ownValue(state?: unknown, id?: unknown): unknown | undefined {
		if (luaIndex(STAT_BOARD_KEYS, id)) {
			let stats: unknown = luaProp(state, "Stats");
			return luaCall(luaProp(math, "max"), 0, luaCall(luaProp(math, "floor"), (luaCall(tonumber, (stats && luaIndex(stats, luaIndex(STAT_BOARD_KEYS, id)))) || 0)));
		}
		if ((id === "Stars")) {
			let total: unknown = 0;
			let sky: unknown = luaProp(state, "Sky");
			if (((luaTypeIs(sky, "table")) && (luaTypeIs(luaProp(sky, "Plotted"), "table")))) {
				for (const [_, count] of pairs((luaProp(sky, "Plotted")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					total = ((total as unknown as number) + (luaCall(luaProp(math, "max"), 0, luaCall(luaProp(math, "floor"), (luaCall(tonumber, count) || 0))) as unknown as number));
				}
			}
			return total;
		}
		if ((id === "Cipher")) {
			let sky: unknown = luaProp(state, "Sky");
			return luaCall(luaProp(math, "max"), 0, luaCall(luaProp(math, "floor"), (luaCall(tonumber, (((luaTypeIs(sky, "table")) && (luaTypeIs(luaProp(sky, "Cipher"), "table"))) && luaProp(luaProp(sky, "Cipher"), "Solves"))) || 0)));
		}
		if ((id === "Flux")) {
			return luaProp(state, "LifetimeCash");
		}
		if ((id === "Rebirths")) {
			return luaProp(state, "Rebirths");
		}
		if ((id === "PlayTime")) {
			let _result: unknown = luaProp(state, "Stats");
			if ((_result !== undefined)) {
				_result = luaProp(_result, "PlayTime");
			}
			let _condition: unknown = _result;
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		if ((id === "Dust")) {
			return luaProp(state, "Stardust");
		}
		if ((id === "Cores")) {
			return luaProp(state, "Cores");
		}
		if ((id === "Domain")) {
			let _result: unknown = luaProp(state, "Domain");
			if ((_result !== undefined)) {
				_result = luaProp(_result, "Rank");
			}
			let _condition: unknown = _result;
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		return luaProp(state, "Zone");
		return undefined;
	}
	function serverValueFor(summary?: unknown, id?: unknown): unknown | undefined {
		if (((luaIndex(STAT_BOARD_KEYS, id) || (id === "Stars")) || (id === "Cipher"))) {
			let boards: unknown = luaProp(summary, "Boards");
			return ((luaTypeIs(boards, "table")) ? (luaCall(tonumber, luaIndex(boards, id)) || 0) : 0);
		}
		if ((id === "Flux")) {
			let _condition: unknown = luaProp(summary, "LifetimeCash");
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		if ((id === "Rebirths")) {
			return luaProp(summary, "Rebirths");
		}
		if ((id === "PlayTime")) {
			let _condition: unknown = luaProp(summary, "PlayTime");
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		if ((id === "Dust")) {
			let _condition: unknown = luaProp(summary, "Stardust");
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		if ((id === "Cores")) {
			let _condition: unknown = luaProp(summary, "Cores");
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		if ((id === "Domain")) {
			let _condition: unknown = luaProp(summary, "DomainRank");
			if ((_condition === undefined)) {
				_condition = 0;
			}
			return _condition;
		}
		return luaProp(summary, "CurrentZone");
		return undefined;
	}
	function serverEntries(players?: unknown, id?: unknown): unknown | undefined {
		let _array_1: unknown = {};
		let _length_1: unknown = len(_array_1);
		luaTable.move(players, 1, len(players), ((_length_1 as unknown as number) + (1 as unknown as number)), _array_1);
		luaCall(luaProp(table, "sort"), _array_1, function(left?: unknown, right?: unknown): unknown | undefined {
			let compare: unknown = luaCall(luaProp(luaRequire(instChild(instChild(instChild(game.GetService("ReplicatedStorage"), "AstralForge"), "Shared"), "OmegaMath")), "Compare"), (luaCall(serverValueFor, left, id) || 0), (luaCall(serverValueFor, right, id) || 0));
			return ((compare === 0) ? ((luaProp(left, "UserId") as unknown as number) < (luaProp(right, "UserId") as unknown as number)) : ((compare as unknown as number) > (0 as unknown as number)));
			return undefined;
		});
		let _newValue_1: unknown = luaCall(luaProp(table, "create"), len(_array_1));
		let _callback_1: unknown = function(summary?: unknown): unknown | undefined {
			return { UserId: luaProp(summary, "UserId"), Name: luaProp(summary, "DisplayName"), Value: luaCall(serverValueFor, summary, id), Category: id };
			return undefined;
		};
		for (const [_k, _v] of pairs((_array_1) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue_1, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), _array_1));
		}
		return _newValue_1;
		return undefined;
	}
	return { LeaderboardsView: luaCall(mod("RankDashboard"), { boards: BOARDS, metaFor: metaFor, ownValue: ownValue, formatValue: formatValue, serverEntries: serverEntries, scoreCounts: scoreCounts }) };
};


const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type PagesSystemCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const PagesSystem = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => {
			return __load(name);
		},
		__index: (_self: unknown, name: string): unknown => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as LuaMetatable<object>,
) as unknown as PagesSystemCallable;

export = PagesSystem;
