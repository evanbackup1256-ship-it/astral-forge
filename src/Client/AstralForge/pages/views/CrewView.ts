import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable } from "./viewRuntime";
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

/**
 * Profile-style hook for crew roster rows. `player` is a GetPlayers entry (UserId, DisplayName, IsLocal, ...).
 * Return an accent Color3 to tint the row ring; undefined keeps the default colors.
 */
function crewRowAccent(_player: unknown): Color3 | undefined {
	return undefined;
}

/** Stable: items matching `pinned` move to the front, everything else keeps its order. */
function pinFirst(list: unknown[] | undefined, pinned: (item: unknown) => boolean): unknown[] {
	const front: defined[] = [];
	const rest: defined[] = [];
	for (const item of (list ?? []) as defined[]) {
		(pinned(item) ? front : rest).push(item);
	}
	for (const item of rest) {
		front.push(item);
	}
	return front;
}

function __member(): unknown {
	let Players: unknown = colon(game).GetService("Players");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let PlayerMark: unknown = luaProp(kit("ArtKit", "Icon"), "PlayerMark");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _motion: unknown = kit("MotionKit", "motion");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let EmptyState: unknown = luaProp(_ui, "EmptyState");
	let Meter: unknown = luaProp(_ui, "Meter");
	let meterFill: unknown = luaProp(_ui, "meterFill");
	let Panel: unknown = luaProp(_ui, "Panel");
	let Text: unknown = luaProp(_ui, "Text");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let NumberSpinnerHost: unknown = luaProp(kit("ReactHosts", "NumberSpinnerHost"), "NumberSpinnerHost");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let _theme: unknown = kit("CoreKit", "theme");
	let Palette: unknown = luaProp(_theme, "Palette");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let _format: unknown = kit("CoreKit", "format");
	let asFlux: unknown = luaProp(_format, "asFlux");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let AppHelpers: unknown = luaProp(kit("CoreKit", "appNav"), "AppHelpers");
	let PageReadyMath: unknown = kit("LayoutKit", "pageReadyMath");
	let PageBoardHeights: unknown = kit("CoreKit", "pageBoardHeights");
	let Browse: unknown = mod("BrowseKit");
	function CrewRow(_param?: unknown): unknown | undefined {
		let player: unknown = luaProp(_param, "player");
		let visiting: unknown = luaProp(_param, "visiting");
		let visitorsHere: unknown = luaProp(_param, "visitorsHere");
		let onVisit: unknown = luaProp(_param, "onVisit");
		let onNudge: unknown = luaProp(_param, "onNudge");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let reveal: unknown = luaCall(useStagger, (math.min as unknown as (...a: unknown[]) => unknown)(layoutOrder, 8), softMotion);
		// Profile-style hook: return a Color3 from crewRowAccent to tint this row; undefined keeps green/blue.
		let accent: unknown = crewRowAccent(player) ?? (luaTruthy(luaProp(player, "IsLocal")) ? luaProp(Palette, "green") : luaProp(Palette, "blue"));
		let rowH: unknown = (luaTruthy(stack) ? ((luaTruthy(luaProp(player, "IsLocal")) ? 118 : 158)) : 100);
		let pad: unknown = (luaTruthy(stack) ? 14 : 12);
		let _exp: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 48 : 44), (luaTruthy(stack) ? 48 : 44)), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 8 : 14)), BackgroundColor3: luaCall(darken, accent, 0.62), BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaCall(lighten, accent, 0.12), luaCall(darken, accent, 0.48)), Rotation: 120 }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: accent, Thickness: 1, Transparency: 0.32 }), reactLoose.createElement(PlayerMark, { userId: luaProp(player, "UserId"), color: luaProp(Palette, "ink"), accent: accent, size: (luaTruthy(stack) ? 42 : 38), position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5) }));
		let _exp_1: unknown = reactLoose.createElement(Text, { value: (luaTruthy(luaProp(player, "IsLocal")) ? "YOU" : luaProp(player, "DisplayName")), size: (luaTruthy(stack) ? 17 : 16), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 2), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((58 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -280), 0, 22) });
		let _exp_2: unknown = reactLoose.createElement(Text, { value: `World ${luaProp(player, "CurrentZone")}`, size: (luaTruthy(stack) ? 12 : 10), color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 28), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 80, 16) });
		let _exp_3: unknown = reactLoose.createElement(Text, { value: `${luaCall(compactNumber, luaProp(player, "Production"))} /s`, size: (luaTruthy(stack) ? 12 : 10), color: luaProp(Palette, "muted"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 144, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -160, 0, 16) });
		let _condition: unknown = (!luaTruthy(luaProp(player, "IsLocal")));
		if (luaTruthy(_condition)) {
			let _attributes: unknown = {};
			let _condition_1: unknown = luaProp(player, "CurrentPage");
			if ((_condition_1 === undefined)) {
				_condition_1 = "Overview";
			}
			luaSet(_attributes, "value", `Browsing ${luaProp(colon(AppHelpers).pageEntry(_condition_1), "label")}`);
			luaSet(_attributes, "size", (luaTruthy(stack) ? 11 : 9));
			luaSet(_attributes, "color", ((((luaProp(player, "PresenceAge") !== undefined) && ((luaProp(player, "PresenceAge") as unknown as number) >= (0 as unknown as number))) && ((luaProp(player, "PresenceAge") as unknown as number) < (12 as unknown as number))) ? luaProp(Palette, "mint") : luaProp(Palette, "muted")));
			luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Bold"));
			luaSet(_attributes, "fit", true);
			luaSet(_attributes, "minSize", 8);
			luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), 58, (luaTruthy(stack) ? 52 : 56)));
			luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((58 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -16), 0, 16));
			_condition = reactLoose.createElement(Text, _attributes);
		}
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, rowH), accent: accent, background: (luaTruthy(visiting) ? luaProp(Palette, "panelRaised") : luaProp(Palette, "panel")), padding: pad, layoutOrder: layoutOrder, reveal: reveal, interactive: (!luaTruthy(luaProp(player, "IsLocal"))), highlight: visiting, reducedMotion: softMotion, clips: false }, _exp, _exp_1, _exp_2, _exp_3, _condition, (luaTruthy(luaProp(player, "IsLocal")) ? reactLoose.createElement(Text, { value: (((visitorsHere as unknown as number) > (0 as unknown as number)) ? `${visitorsHere} visiting your shop` : `${luaProp(player, "Rebirths")} resets`), size: (luaTruthy(stack) ? 12 : 10), color: (((visitorsHere as unknown as number) > (0 as unknown as number)) ? luaProp(Palette, "mango") : accent), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, (luaTruthy(stack) ? 52 : 56)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((58 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -16), 0, 18) }) : (luaTruthy(stack) ? reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (2 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Left"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, TapTarget), LayoutOrder: 1, BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Button, { text: "WAVE", icon: "Wave.5", onClick: onNudge, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion })), reactLoose.createElement("frame", { Name: "CrewVisitConfirm", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, TapTarget), LayoutOrder: 2, BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(Button, { text: (luaTruthy(visiting) ? "HERE" : "VISIT"), icon: "Visit.2", onClick: onVisit, color: (luaTruthy(visiting) ? luaProp(Palette, "green") : luaProp(Palette, "blue")), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion, disabled: visiting, highlight: visiting }))) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -6, 0.5, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Right"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Button, { text: "WAVE", icon: "Wave.6", onClick: onNudge, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), hug: true, reducedMotion: softMotion }), reactLoose.createElement("frame", { Name: "CrewVisitConfirm", Size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, LayoutOrder: 2 }, reactLoose.createElement(Button, { text: (luaTruthy(visiting) ? "HERE" : "VISIT"), icon: "Visit.3", onClick: onVisit, color: (luaTruthy(visiting) ? luaProp(Palette, "green") : luaProp(Palette, "blue")), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), hug: true, reducedMotion: softMotion, disabled: visiting, highlight: visiting }))))));
		return undefined;
	}
	function VisitPanel(_param?: unknown): unknown | undefined {
		let visit: unknown = luaProp(_param, "visit");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let reveal: unknown = luaCall(useStagger, 0, softMotion);
		let vaultFill: unknown = luaCall(meterFill, luaCall(asFlux, luaProp(visit, "Vault")), luaCall(asFlux, luaProp(visit, "Capacity")));
		let machineBits: unknown = {};
		for (const [id, level] of pairs((luaProp(visit, "Machines")) as object)) {
			if (((len(machineBits) as unknown as number) < (4 as unknown as number))) {
				let _arg0: unknown = `${id} ${level}`;
				luaTable.insert(machineBits, _arg0);
			}
		}
		let lineWord: unknown = ((luaProp(visit, "MachineKinds") === 1) ? "line" : "lines");
		let machineLine: unknown = (((len(machineBits) as unknown as number) > (0 as unknown as number)) ? `${luaProp(visit, "MachineKinds")} ${lineWord} · ${luaIndex(machineBits, 1)}${((luaIndex(machineBits, 2) !== undefined) ? `  ·  ${luaIndex(machineBits, 2)}` : "")}${((luaIndex(machineBits, 3) !== undefined) ? `  ·  ${luaIndex(machineBits, 3)}` : "")}` : "No machines built yet");
		let _exp: unknown = reactLoose.createElement(Text, { value: "VISITING", size: 10, color: luaProp(Palette, "blue"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -160), 0, 16) });
		let _exp_1: unknown = reactLoose.createElement(Text, { value: luaProp(visit, "DisplayName"), size: 22, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -160), 0, 30) });
		let _exp_2: unknown = reactLoose.createElement(Text, { value: `World ${luaProp(visit, "CurrentZone")}  ·  ${luaProp(visit, "Rebirths")} resets  ·  live`, size: 11, color: luaProp(Palette, "creamSoft"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 54), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -160), 0, 18) });
		let _exp_3: unknown = reactLoose.createElement(Button, { text: "LEAVE", icon: "Close.3", onClick: function(this: void): unknown | undefined {
			return luaCall(dispatch, "LeavePlot");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 120, 40)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (4 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -120, 0, 12)), reducedMotion: softMotion });
		let _exp_4: unknown = [{ label: "FLUX / SEC", value: luaProp(visit, "Production"), color: luaProp(Palette, "green") }, { label: "BALANCE", value: luaProp(visit, "Cash"), color: luaProp(Palette, "cream") }, { label: "CORES", value: luaProp(visit, "Cores"), color: luaProp(Palette, "violet") }, { label: "STARDUST", value: luaProp(visit, "Stardust"), color: luaProp(Palette, "cyan") }];
		let _newValue: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(_exp_4));
		let _callback: unknown = function(this: void, stat?: unknown, index?: unknown): unknown | undefined {
			return reactLoose.createElement("frame", { key: luaProp(stat, "label"), Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 72) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -6, 1, 0)), Position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((((index as unknown as number) % (2 as unknown as number)) === 0) ? 0 : 0.5), ((((index as unknown as number) % (2 as unknown as number)) === 0) ? 0 : 4), 0, (((index as unknown as number) < (2 as unknown as number)) ? 0 : 80)) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((index as unknown as number) * (0.25 as unknown as number)), ((index === 0) ? 0 : 2), 0, 0)), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement(Text, { value: luaProp(stat, "label"), size: 9, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 10), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 14) }), reactLoose.createElement(NumberSpinnerHost, { value: luaCall(asFlux, luaProp(stat, "value")), reducedMotion: softMotion, duration: 0.4, size: 16, color: luaProp(stat, "color"), position: luaCall(luaProp(UDim2, "fromOffset"), 10, 32), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 24) }));
			return undefined;
		};
		for (const [_k, _v] of pairs((_exp_4) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), _exp_4));
		}
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, luaCall(luaProp(PageBoardHeights, "Visit"), stack)), accent: luaProp(Palette, "blue"), background: luaProp(Palette, "panelRaised"), padding: 16, layoutOrder: layoutOrder, reveal: reveal, highlight: true, reducedMotion: softMotion, clips: false }, _exp, _exp_1, _exp_2, _exp_3, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? 152 : 72)), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 76 : 86)), BackgroundTransparency: 1, BorderSizePixel: 0 }, _newValue), reactLoose.createElement(Text, { value: `Vault ${luaCall(compactNumber, luaProp(visit, "Vault"))} / ${luaCall(compactNumber, luaProp(visit, "Capacity"))}`, size: 10, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 238 : 170)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) }), reactLoose.createElement(Meter, { value: vaultFill, color: luaProp(Palette, "blue"), reducedMotion: softMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 258 : 192)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 7) }), reactLoose.createElement(Text, { value: machineLine, size: 10, color: luaProp(Palette, "creamSoft"), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 274 : 210)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) }));
		return undefined;
	}
	function sameCrewSnapshot(left?: unknown, right?: unknown): unknown | undefined {
		return luaCall(luaProp(PageReadyMath, "SameCrewSnapshot"), left, right);
		return undefined;
	}
	let CrewStore: unknown = mod("CrewStore");
	let CrewMath: unknown = luaRequire(colon(colon(colon(colon(game).GetService("ReplicatedStorage")).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("CrewMath"));
	// The party block above the server roster: invite card, crew summary, members, goal and actions.
	function crewPartySections(args?: unknown): unknown | undefined {
		const _init1 = luaProp(args, "crewState");
		const _init2 = luaProp(args, "players");
		const _init3 = luaProp(args, "dispatch");
		const _init4 = luaProp(args, "stack");
		const _init5 = luaProp(args, "softMotion");
		let crewState: unknown = _init1;
		let players: unknown = _init2;
		let dispatch: unknown = _init3;
		let stack: unknown = _init4;
		let softMotion: unknown = _init5;
		const _init6 = luaProp(args, "renameDraft");
		const _init7 = luaProp(args, "setRenameDraft");
		const _init8 = luaProp(args, "note");
		const _init9 = luaProp(args, "setNote");
		let renameDraft: unknown = _init6;
		let setRenameDraft: unknown = _init7;
		let note: unknown = _init8;
		let setNote: unknown = _init9;
		let localId: unknown = luaProp(luaProp(Players, "LocalPlayer"), "UserId");
		const _init10 = luaProp(crewState, "crew");
		const _init11 = luaProp(crewState, "invite");
		let crew: unknown = _init10;
		let invite: unknown = _init11;
		let sections: unknown = {};
		function run(action?: unknown, payload?: unknown): unknown | undefined {
			luaCall(dispatch, action, ((luaTruthy(payload ) ? payload :  {})), function(this: void, response?: unknown): unknown | undefined {
				if ((!luaTypeIs(response, "table"))) {
					return;
				}
				if ((((action === "GetCrew") || (luaProp(response, "Crew") !== undefined)) || (luaProp(response, "Invite") !== undefined))) {
					luaCall(luaProp(CrewStore, "set"), { crew: ((luaTruthy(luaProp(response, "Crew") ) ? luaProp(response, "Crew") :  luaProp(CrewStore, "NONE"))) });
				}
				luaCall(setNote, ((luaProp(response, "ok") === false) ? (((luaTruthy(luaProp(response, "error") ) ? luaProp(response, "error") :  "That didn't work."))) : (((luaTruthy(luaProp(response, "message") ) ? luaProp(response, "message") :  "")))));
				return undefined;
			});
			return undefined;
		}
		function text(value?: unknown, size?: unknown, color?: unknown, height?: unknown, weight?: unknown): unknown | undefined {
			return reactLoose.createElement(Text, { value: value, size: size, color: color, wrap: true, weight: weight, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height) });
			return undefined;
		}
		// leaving or removing someone takes a second tap, so a stray click can't break up a crew
		const _init12 = luaProp(args, "confirmKey");
		const _init13 = luaProp(args, "setConfirmKey");
		let confirmKey: unknown = _init12;
		let setConfirmKey: unknown = _init13;
		function confirmed(key?: unknown, action?: unknown, payload?: unknown): unknown | undefined {
			if ((confirmKey === key)) {
				luaCall(setConfirmKey, undefined);
				luaCall(run, action, payload);
			} else {
				luaCall(setConfirmKey, key);
			}
			return undefined;
		}
		let GAP: unknown = 10;
		if ((luaTruthy(invite) && (((((luaTruthy(luaProp(invite, "ExpiresAt") ) ? luaProp(invite, "ExpiresAt") :  0))) as unknown as number) > ((os.time as unknown as (...a: unknown[]) => unknown)() as unknown as number)))) {
			luaTable.insert(sections, { id: "crew-invite", height: (luaTruthy(stack) ? ((((((46 as unknown as number) + (((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (GAP as unknown as number)) as unknown as number) + (28 as unknown as number)) : 104), element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panelRaised"), padding: 14, clips: false }, luaCall(text, `${luaProp(invite, "FromName")} invited you to ${luaProp(invite, "CrewName")}.`, 17, luaProp(Palette, "cream"), 44, luaProp(luaProp(Enum, "FontWeight"), "Heavy")), reactLoose.createElement(Button, { text: "Join crew", icon: "Crew.5", color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 160, TapTarget)), position: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 0, 46) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, ((-330 as unknown as number) - (GAP as unknown as number)), 0, 34)), reducedMotion: softMotion, onClick: function(this: void): unknown | undefined {
				luaCall(luaProp(CrewStore, "set"), { invite: luaProp(CrewStore, "NONE") });
				luaCall(run, "CrewRespond", { Accept: true });
				return undefined;
			} }), reactLoose.createElement(Button, { text: "Decline", color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 160, TapTarget)), position: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 0, ((((46 as unknown as number) + (TapTarget as unknown as number)) as unknown as number) + (GAP as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -160, 0, 34)), reducedMotion: softMotion, onClick: function(this: void): unknown | undefined {
				luaCall(luaProp(CrewStore, "set"), { invite: luaProp(CrewStore, "NONE") });
				luaCall(run, "CrewRespond", { Accept: false });
				return undefined;
			} })) });
		}
		let leader: unknown = ((crew !== undefined) && (luaProp(crew, "Leader") === localId));
		if (luaTruthy(crew)) {
			let bonus: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)((((((((luaTruthy(luaProp(crew, "Bonus") ) ? luaProp(crew, "Bonus") :  0))) as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
			luaTable.insert(sections, { id: "crew-summary", height: 96, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "green"), background: luaProp(Palette, "panelRaised"), padding: 14, clips: false }, luaCall(text, luaProp(crew, "Name"), 22, luaProp(Palette, "cream"), 30, luaProp(luaProp(Enum, "FontWeight"), "Heavy")), reactLoose.createElement(Text, { value: `${len(luaProp(crew, "Members"))} of ${luaProp(crew, "Max")} members · +${bonus}% production while you play together · crew chat is in Chat`, size: 14, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) })) });
			// you first, then the leader, then everyone else in server order
			const orderedMembers = pinFirst(pinFirst((luaProp(crew, "Members") ?? []) as unknown[], (member) => luaTruthy(luaProp(member, "Leader"))), (member) => luaProp(member, "UserId") === localId);
			for (const [index, member] of pairs(orderedMembers as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaTable.insert(sections, { id: concat("crew-member-", luaProp(member, "UserId")), height: 56, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement(Text, { value: concat(luaProp(member, "DisplayName"), concat(((luaTruthy(luaProp(member, "Leader")) ? "  ·  leader" : "")), (((luaProp(member, "UserId") === localId) ? "  ·  you" : "")))), size: 16, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), position: luaCall(luaProp(UDim2, "fromOffset"), 14, 6), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -140, 0, 22) }), reactLoose.createElement(Text, { value: `${luaProp(member, "Collects")} collect${((luaProp(member, "Collects") === 1) ? "" : "s")} today`, size: 13, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 14, 30), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -140, 0, 18) }), (((luaProp(member, "UserId") !== localId) && reactLoose.createElement(Button, { text: "Visit", icon: "Visit.4", color: luaProp(Palette, "blue"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromOffset"), 104, 44), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(leader) ? -236 : -110), 0.5, -22), reducedMotion: softMotion, onClick: function(this: void): unknown | undefined {
					luaCall(dispatch, "VisitPlot", { UserId: luaProp(member, "UserId") });
					return undefined;
				} })) || undefined), ((((luaTruthy(leader ) ?  (luaProp(member, "UserId") !== localId) : leader)) && reactLoose.createElement(Button, { text: ((confirmKey === concat("kick-", luaProp(member, "UserId"))) ? "Sure?" : "Remove"), color: ((confirmKey === concat("kick-", luaProp(member, "UserId"))) ? luaProp(Palette, "coral") : luaProp(Palette, "panelSoft")), textColor: ((confirmKey === concat("kick-", luaProp(member, "UserId"))) ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), outline: (confirmKey !== concat("kick-", luaProp(member, "UserId"))), size: luaCall(luaProp(UDim2, "fromOffset"), 112, 44), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -118, 0.5, -22), reducedMotion: softMotion, onClick: function(this: void): unknown | undefined {
					luaCall(confirmed, concat("kick-", luaProp(member, "UserId")), "CrewKick", { UserId: luaProp(member, "UserId") });
					return undefined;
				} })) || undefined)) });
			}
			// the daily goal: one meter to the next tier, then a claim button per tier
			let nextTier: unknown = undefined;
			for (const [index, tier] of pairs((luaProp(crew, "Tiers")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((luaProp(crew, "Pooled") as unknown as number) < (luaProp(tier, "Target") as unknown as number))) {
					nextTier = tier;
					break;
				}
			}
			let mine: unknown = 0;
			for (const [_, member] of pairs((luaProp(crew, "Members")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(member, "UserId") === localId)) {
					mine = luaProp(member, "Collects");
				}
			}
			let goalChildren: unknown = [luaCall(text, (luaTruthy(nextTier) ? `Crew goal: ${luaProp(crew, "Pooled")} / ${luaProp(nextTier, "Target")} vault collects today` : `Every crew goal is done today (${luaProp(crew, "Pooled")} collects).`), 16, luaProp(Palette, "cream"), 22, luaProp(luaProp(Enum, "FontWeight"), "Bold")), reactLoose.createElement(Meter, { value: (luaTruthy(nextTier) ? (math.clamp as unknown as (...a: unknown[]) => unknown)(((luaProp(crew, "Pooled") as unknown as number) / (luaProp(nextTier, "Target") as unknown as number)), 0, 1) : 1), color: luaProp(Palette, "green"), reducedMotion: softMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 8) }), reactLoose.createElement(Text, { value: (((mine as unknown as number) < (luaProp(crew, "MinContribution") as unknown as number)) ? `Collect your vault ${((luaProp(crew, "MinContribution") as unknown as number) - (mine as unknown as number))} more time${((((luaProp(crew, "MinContribution") as unknown as number) - (mine as unknown as number)) === 1) ? "" : "s")} to share the rewards.` : "You've pitched in enough to share every reward."), size: 13, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 42), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18) })];
			let columns: unknown = (luaTruthy(stack) ? 1 : 3);
			let cellW: unknown = ((1 as unknown as number) / (columns as unknown as number));
			for (const [index, tier] of pairs((luaProp(crew, "Tiers")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let ready: unknown = ((((luaProp(crew, "Pooled") as unknown as number) >= (luaProp(tier, "Target") as unknown as number)) && (!luaTruthy(luaProp(tier, "Claimed")))) && ((mine as unknown as number) >= (luaProp(crew, "MinContribution") as unknown as number)));
				const _init14 = (((((index as unknown as number) - (1 as unknown as number))) as unknown as number) % (columns as unknown as number));
				const _init15 = (math.floor as unknown as (...a: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) / (columns as unknown as number)));
				let col: unknown = _init14;
				let row: unknown = _init15;
				luaTable.insert(goalChildren, reactLoose.createElement(Button, { text: (luaTruthy(luaProp(tier, "Claimed")) ? `Claimed · ${luaProp(tier, "Stardust")} dust` : (((luaProp(crew, "Pooled") as unknown as number) >= (luaProp(tier, "Target") as unknown as number)) ? `Claim ${luaProp(tier, "Stardust")} dust` : `${luaProp(tier, "Target")} collects · ${luaProp(tier, "Stardust")} dust`)), color: (luaTruthy(ready) ? luaProp(Palette, "green") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(ready) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), disabled: (!luaTruthy(ready)), highlight: ready, reducedMotion: softMotion, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(cellW, (-(GAP as unknown as number)), 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((col as unknown as number) * (cellW as unknown as number)), 0, 0, ((68 as unknown as number) + (((row as unknown as number) * ((((TapTarget as unknown as number) + (GAP as unknown as number))) as unknown as number)) as unknown as number))), onClick: function(this: void): unknown | undefined {
					luaCall(run, "CrewClaim", { Tier: index });
					return undefined;
				} }));
			}
			let goalRows: unknown = (math.ceil as unknown as (...a: unknown[]) => unknown)(((len(luaProp(crew, "Tiers")) as unknown as number) / (columns as unknown as number)));
			luaTable.insert(sections, { id: "crew-goal", height: ((((68 as unknown as number) + (((goalRows as unknown as number) * ((((TapTarget as unknown as number) + (GAP as unknown as number))) as unknown as number)) as unknown as number)) as unknown as number) + (28 as unknown as number)), element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "green"), background: luaProp(Palette, "panelRaised"), padding: 14, clips: false }, luaTable.unpack(goalChildren)) });
			let actions: unknown = [reactLoose.createElement(Button, { text: ((confirmKey === "leave") ? "Tap again to leave" : "Leave crew"), color: ((confirmKey === "leave") ? luaProp(Palette, "coral") : luaProp(Palette, "panelSoft")), textColor: ((confirmKey === "leave") ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), outline: (confirmKey !== "leave"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((luaTruthy(leader) && (!luaTruthy(stack))) ? 0.3 : 1), (((-(GAP as unknown as number)) as unknown as number) / (2 as unknown as number)), 0, TapTarget), position: ((luaTruthy(leader) && (!luaTruthy(stack))) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.7, ((GAP as unknown as number) / (2 as unknown as number)), 0, 0) : (luaTruthy(leader) ? luaCall(luaProp(UDim2, "fromOffset"), 0, ((TapTarget as unknown as number) + (GAP as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)())), reducedMotion: softMotion, onClick: function(this: void): unknown | undefined {
				luaCall(confirmed, "leave", "CrewLeave");
				return undefined;
			} })];
			if (luaTruthy(leader)) {
				luaTable.insert(actions, reactLoose.createElement("textbox", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)((luaTruthy(stack) ? 1 : 0.45), (((-(GAP as unknown as number)) as unknown as number) / (2 as unknown as number)), 0, TapTarget), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0, Text: renameDraft, PlaceholderText: "New crew name", PlaceholderColor3: luaProp(Palette, "muted"), TextColor3: luaProp(Palette, "cream"), TextSize: 16, ClearTextOnFocus: false, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
					luaCall(setRenameDraft, (string.sub as unknown as (...a: unknown[]) => unknown)(luaProp(box, "Text"), 1, 40));
					return undefined;
				} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) })));
				if ((!luaTruthy(stack))) {
					luaTable.insert(actions, reactLoose.createElement(Button, { text: "Rename", color: luaProp(Palette, "green"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, (-(GAP as unknown as number)), 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.45, ((GAP as unknown as number) / (2 as unknown as number)), 0, 0), reducedMotion: softMotion, disabled: (luaCall(luaProp(CrewMath, "cleanName"), renameDraft) === undefined), onClick: function(this: void): unknown | undefined {
						luaCall(run, "CrewRename", { Name: renameDraft });
						luaCall(setRenameDraft, "");
						return undefined;
					} }));
				}
			}
			luaTable.insert(sections, { id: "crew-actions", height: ((luaTruthy(leader) && luaTruthy(stack)) ? ((((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number) + (GAP as unknown as number)) : TapTarget), element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, luaTable.unpack(actions)) });
		}
		// recruiting: anyone here who isn't already in your crew
		let canInvite: unknown = ((crew === undefined) || (((luaTruthy(leader ) ?  ((len(luaProp(crew, "Members")) as unknown as number) < (luaProp(crew, "Max") as unknown as number)) : leader))));
		if (luaTruthy(canInvite)) {
			let candidates: unknown = {};
			let members: unknown = {};
			if (luaTruthy(crew)) {
				for (const [_, member] of pairs((luaProp(crew, "Members")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					luaSetIndex(members, luaProp(member, "UserId"), true);
				}
			}
			for (const [_, player] of pairs((players) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((!luaTruthy(luaProp(player, "IsLocal"))) && (!luaTruthy(luaIndex(members, luaProp(player, "UserId")))))) {
					luaTable.insert(candidates, player);
				}
			}
			let intro: unknown = (luaTruthy(crew) ? "Invite more players to your crew." : `Start a crew with up to ${((luaProp(CrewMath, "MAX_MEMBERS") as unknown as number) - (1 as unknown as number))} other players here. Each crewmate adds ${(math.floor as unknown as (...a: unknown[]) => unknown)(((luaProp(CrewMath, "BONUS_PER_MEMBER") as unknown as number) * (100 as unknown as number)))}% production, and you share a daily goal.`);
			let columns: unknown = (luaTruthy(stack) ? 1 : 2);
			let rows: unknown = (math.ceil as unknown as (...a: unknown[]) => unknown)((((math.min as unknown as (...a: unknown[]) => unknown)(len(candidates), 8) as unknown as number) / (columns as unknown as number)));
			let children: unknown = [luaCall(text, ((len(candidates) === 0) ? concat(intro, " Nobody else is free right now.") : intro), 15, luaProp(Palette, "creamSoft"), 40)];
			{
				const _forStart_1 = (1 as unknown as number);
				const _forEnd_1 = ((math.min as unknown as (...a: unknown[]) => unknown)(len(candidates), 8) as unknown as number);
				const _forStep_1 = (1 as unknown as number);
				for (let index = _forStart_1; _forStep_1 >= 0 ? index <= _forEnd_1 : index >= _forEnd_1; index += _forStep_1) {
					let player: unknown = luaIndex(candidates, index);
					const _init16 = (((((index as unknown as number) - (1 as unknown as number))) as unknown as number) % (columns as unknown as number));
					const _init17 = (math.floor as unknown as (...a: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) / (columns as unknown as number)));
					let col: unknown = _init16;
					let row: unknown = _init17;
					luaTable.insert(children, reactLoose.createElement(Button, { text: `Invite ${luaProp(player, "DisplayName")}`, icon: "Crew.6", color: luaProp(Palette, "blue"), textColor: luaProp(Palette, "ink"), reducedMotion: softMotion, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (columns as unknown as number)), (-(GAP as unknown as number)), 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((col as unknown as number) / (columns as unknown as number)), 0, 0, ((46 as unknown as number) + (((row as unknown as number) * ((((TapTarget as unknown as number) + (GAP as unknown as number))) as unknown as number)) as unknown as number))), onClick: function(this: void): unknown | undefined {
						luaCall(run, "CrewInvite", { UserId: luaProp(player, "UserId") });
						return undefined;
					} }));
				}
			}
			luaTable.insert(sections, { id: "crew-recruit", height: ((((46 as unknown as number) + (((rows as unknown as number) * ((((TapTarget as unknown as number) + (GAP as unknown as number))) as unknown as number)) as unknown as number)) as unknown as number) + (26 as unknown as number)), element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "blue"), background: luaProp(Palette, "panelRaised"), padding: 14, clips: false }, luaTable.unpack(children)) });
		}
		if ((note !== "")) {
			luaTable.insert(sections, { id: "crew-note", height: 40, element: luaCall(text, note, 14, luaProp(Palette, "mango"), 36) });
		}
		return sections;
		return undefined;
	}
	function CrewView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let visit: unknown = luaProp(_param, "visit");
		let setVisit: unknown = luaProp(_param, "setVisit");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let stack: unknown = luaProp(chrome, "contentStack");
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		let players: unknown;
		let setPlayers: unknown;
		[players, setPlayers] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let mountedRef: unknown = reactLoose.useRef(true);
		let visitAttemptRef: unknown = reactLoose.useRef(0);
		let crewHostRef: unknown = reactLoose.useRef(undefined);
		let crewState: unknown = luaCall(luaProp(CrewStore, "useCrew"));
		let renameDraft: unknown;
		let setRenameDraft: unknown;
		[renameDraft, setRenameDraft] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let crewNote: unknown;
		let setCrewNote: unknown;
		[crewNote, setCrewNote] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let confirmKey: unknown;
		let setConfirmKey: unknown;
		[confirmKey, setConfirmKey] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		// an unanswered "tap again" quietly resets
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((confirmKey === undefined)) {
				return undefined;
			}
			let reset: unknown = (task.delay as unknown as (...a: unknown[]) => unknown)(4, function(this: void): unknown | undefined {
				luaCall(setConfirmKey, undefined);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), reset);
				return undefined;
			};
			return undefined;
		}, [confirmKey]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			return function(this: void): unknown | undefined {
				luaSet(mountedRef, "current", false);
				luaSet(visitAttemptRef, "current", ((luaProp(visitAttemptRef, "current") as unknown as number) + (1 as unknown as number)));
				return undefined;
			};
			return undefined;
		}, {});
		// the crew page asks once on open; afterwards CrewState effects keep the store current
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(dispatch, "GetCrew", {}, function(this: void, response?: unknown): unknown | undefined {
				if (((luaTypeIs(response, "table")) && luaTruthy(luaProp(response, "ok")))) {
					luaCall(luaProp(CrewStore, "set"), { crew: ((luaTruthy(luaProp(response, "Crew") ) ? luaProp(response, "Crew") :  luaProp(CrewStore, "NONE"))), invite: ((luaTruthy(luaProp(response, "Invite") ) ? luaProp(response, "Invite") :  luaProp(CrewStore, "NONE"))) });
				}
				return undefined;
			});
			return undefined;
		}, {});
		let refresh: unknown = reactLoose.useCallback(function(this: void): unknown | undefined {
			return luaCall(dispatch, "GetPlayers", {}, function(this: void, response?: unknown): unknown | undefined {
				if (((!luaTruthy(luaProp(mountedRef, "current"))) || (!luaTruthy(luaProp(response, "ok"))))) {
					return undefined;
				}
				let raw: unknown = ((luaTruthy(luaProp(response, "Players") ) ? luaProp(response, "Players") :  {}));
				let cleaned: unknown = {};
				for (const [_, entry] of pairs((raw) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					let _userId: unknown = luaProp(entry, "UserId");
					let id: unknown = ((luaTypeIs(_userId, "number")) ? (math.floor as unknown as (...a: unknown[]) => unknown)(luaProp(entry, "UserId")) : tonumber(tostring(luaProp(entry, "UserId"))));
					if ((((id === undefined) || (id !== id)) || (id === 0))) {
						continue;
					}
					let _object: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(entry);
					setmetatable(_object as object, undefined as unknown as LuaMetatable<object>);
					luaSet(_object, "UserId", id);
					luaTable.insert(cleaned, _object);
				}
				luaCall(setPlayers, function(this: void, current?: unknown): unknown | undefined {
					return (luaTruthy(luaCall(sameCrewSnapshot, current, cleaned)) ? current : cleaned);
					return undefined;
				});
				return undefined;
			});
			return undefined;
		}, [dispatch]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(refresh);
			return undefined;
		}, [refresh]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let joined: unknown = colon(luaProp(Players, "PlayerAdded")).Connect(refresh);
			let left: unknown = colon(luaProp(Players, "PlayerRemoving")).Connect(refresh);
			return function(this: void): unknown | undefined {
				colon(joined).Disconnect();
				colon(left).Disconnect();
				return undefined;
			};
			return undefined;
		}, [refresh]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let alive: unknown = true;
			let worker: unknown = (task.spawn as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				while (luaTruthy(alive)) {
					(task.wait as unknown as (...a: unknown[]) => unknown)(4);
					if ((!alive)) {
						break;
					}
					luaCall(refresh);
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				alive = false;
				luaCall(pcall, function(this: void): unknown | undefined {
					return (task.cancel as unknown as (...a: unknown[]) => unknown)(worker);
					return undefined;
				});
				return undefined;
			};
			return undefined;
		}, [refresh]);
		let crewFocusReady: unknown = ((len(players) as unknown as number) > (0 as unknown as number));
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((!luaTruthy(crewFocusReady)) || (!luaTruthy(luaProp(UserInputService, "GamepadEnabled"))))) {
				return undefined;
			}
			let host: unknown = luaProp(crewHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let selectJob: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if ((luaProp(host, "Parent") === undefined)) {
					return;
				}
				luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), selectJob);
				return undefined;
			};
			return undefined;
		}, [crewFocusReady, len(players)]);
		let _visitUserId: unknown = visit;
		if ((_visitUserId !== undefined)) {
			_visitUserId = luaProp(_visitUserId, "UserId");
		}
		let visitUserId: unknown = _visitUserId;
		let coerceCrewId: unknown = function(this: void, raw?: unknown): unknown | undefined {
			let _raw: unknown = raw;
			let _result: unknown;
			if ((luaTypeIs(_raw, "number"))) {
				_result = raw;
			} else {
				let _raw_1: unknown = raw;
				_result = ((luaTypeIs(_raw_1, "string")) ? tonumber(raw) : undefined);
			}
			let asNumber: unknown = _result;
			if (((asNumber === undefined) || (asNumber !== asNumber))) {
				return undefined;
			}
			let id: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((asNumber as unknown as number) + (((((asNumber as unknown as number) >= (0 as unknown as number)) ? 1e-9 : -1e-9)) as unknown as number)));
			if ((id === 0)) {
				return undefined;
			}
			return id;
			return undefined;
		};
		let startVisit: unknown = function(this: void, userId?: unknown): unknown | undefined {
			let id: unknown = luaCall(coerceCrewId, userId);
			if ((id === undefined)) {
				return undefined;
			}
			let attempt: unknown = ((luaProp(visitAttemptRef, "current") as unknown as number) + (1 as unknown as number));
			luaSet(visitAttemptRef, "current", attempt);
			luaCall(dispatch, "VisitPlot", { UserId: id, userId: id }, function(this: void, response?: unknown): unknown | undefined {
				if (((!luaTruthy(luaProp(mountedRef, "current"))) || (luaProp(visitAttemptRef, "current") !== attempt))) {
					return undefined;
				}
				if ((!luaTruthy(luaProp(response, "ok")))) {
					return undefined;
				}
				if (luaTruthy(luaProp(response, "Visit"))) {
					luaCall(setVisit, luaProp(response, "Visit"));
				} else {
					let _result: unknown = luaProp(response, "State");
					if ((_result !== undefined)) {
						_result = luaProp(_result, "Visit");
					}
					if (luaTruthy(_result)) {
						luaCall(setVisit, luaProp(luaProp(response, "State"), "Visit"));
					}
				}
				return undefined;
			});
			return undefined;
		};
		let nudgeCrew: unknown = function(this: void, userId?: unknown): unknown | undefined {
			let id: unknown = luaCall(coerceCrewId, userId);
			if ((id === undefined)) {
				return undefined;
			}
			luaCall(dispatch, "NudgeCrew", { UserId: id, userId: id });
			return undefined;
		};
		let headerReveal: unknown = luaCall(useStagger, 0, softMotion);
		let crewBrowse: unknown = luaCall(luaProp(Browse, "useBrowse"), { id: "Crew", items: players, text: function(this: void, player?: unknown): unknown | undefined {
			return [luaProp(player, "DisplayName"), luaProp(player, "CurrentPage"), `world ${((luaTruthy(luaProp(player, "CurrentZone") ) ? luaProp(player, "CurrentZone") :  ""))}`];
			return undefined;
		}, categories: [{ id: "All", label: "Everyone" }, { id: "SameWorld", label: "Same world", test: function(this: void, player?: unknown): unknown | undefined {
			return (((!luaTruthy(luaProp(player, "IsLocal"))) && (luaProp(player, "CurrentZone") !== undefined)) && (luaProp(player, "CurrentZone") === luaProp(state, "CurrentZone")));
			return undefined;
		} }, { id: "Others", label: "Not me", test: function(this: void, player?: unknown): unknown | undefined {
			return (!luaTruthy(luaProp(player, "IsLocal")));
			return undefined;
		} }], sorts: [{ id: "Joined", label: "Server order" }, { id: "Production", label: "Top production", compare: function(this: void, a?: unknown, b?: unknown): unknown | undefined {
			return ((((luaCall(asFlux, luaProp(a, "Production")) || 0)) as unknown as number) > (((luaCall(asFlux, luaProp(b, "Production")) || 0)) as unknown as number));
			return undefined;
		} }, { id: "Rebirths", label: "Most rebirths", compare: function(this: void, a?: unknown, b?: unknown): unknown | undefined {
			return ((((tonumber(luaProp(a, "Rebirths")) || 0)) as unknown as number) > (((tonumber(luaProp(b, "Rebirths")) || 0)) as unknown as number));
			return undefined;
		} }, { id: "Name", label: "A to Z", compare: function(this: void, a?: unknown, b?: unknown): unknown | undefined {
			return (((string.lower as unknown as (...a: unknown[]) => unknown)(tostring(luaProp(a, "DisplayName"))) as unknown as number) < ((string.lower as unknown as (...a: unknown[]) => unknown)(tostring(luaProp(b, "DisplayName"))) as unknown as number));
			return undefined;
		} }] });
		let showCrewBar: unknown = ((len(players) as unknown as number) >= (3 as unknown as number));
		let crewBarH: unknown = (luaTruthy(showCrewBar) ? ((luaCall(luaProp(Browse, "barHeight"), stack, true) as unknown as number) + (10 as unknown as number)) : 0);
		let allPlayers: unknown = players;
		players = luaProp(crewBrowse, "results");
		// pin yourself to the top of the roster whatever sort is picked
		players = pinFirst(players as unknown[], (player) => luaTruthy(luaProp(player, "IsLocal")));
		let _result: unknown = luaProp(state, "Visitors");
		if ((_result !== undefined)) {
			_result = len(_result);
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let visitorsHere: unknown = _condition;
		let rowStride: unknown = (luaTruthy(stack) ? 176 : 124);
		let headerH: unknown = ((((luaTruthy(stack) ? 182 : 112)) as unknown as number) + (crewBarH as unknown as number));
		// phone: title, two-line blurb, then a full-width Refresh
		let listGap: unknown = ((visit !== undefined) ? (math.max as unknown as (...a: unknown[]) => unknown)(luaProp(chrome, "panelGap"), 18) : (math.max as unknown as (...a: unknown[]) => unknown)(luaProp(chrome, "panelGap"), 12));
		let visitBlock: unknown = ((visit !== undefined) ? luaCall(luaProp(PageBoardHeights, "Visit"), stack) : 0);
		let crewTail: unknown = luaCall(scrollTail, stack, luaProp(chrome, "bottomSafe"), 48);
		let headerPanel: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "blue"), background: luaProp(Palette, "panelRaised"), padding: luaProp(chrome, "cardPadding"), layoutOrder: 0, reveal: headerReveal, clips: false }, reactLoose.createElement(Text, { value: "CREW ROSTER", size: 10, color: luaProp(Palette, "blue"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -8 : -160), 0, 18) }), reactLoose.createElement(Text, { value: "Crew on this server", size: (luaTruthy(stack) ? 20 : 22), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -8 : -190), 0, 30) }), reactLoose.createElement(Text, { value: (((visitorsHere as unknown as number) > (0 as unknown as number)) ? `${visitorsHere} visiting your forge. Pick someone below to visit or send a wave.` : "Form a crew with players here for a production bonus and a shared daily goal, or visit someone's forge."), size: luaProp(chrome, "labelText"), color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 54), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -8 : -190), 0, 38) }), reactLoose.createElement(Button, { text: (luaTruthy(stack) ? "REFRESH" : "REFRESH CREW"), icon: "Refresh.3", onClick: refresh, sound: "tick", color: luaProp(Palette, "blue"), textColor: luaProp(Palette, "ink"), size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 170, 44)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (crewBarH as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -170, 0, 24)), reducedMotion: softMotion }), ((luaTruthy(showCrewBar ) ?  reactLoose.createElement(luaProp(Browse, "BrowseBar"), { browse: crewBrowse, placeholder: "Search crew by name or activity", accent: luaProp(Palette, "blue"), stack: stack, reducedMotion: softMotion, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((crewBarH as unknown as number) - (10 as unknown as number))) as unknown as number))), zIndex: 30 }) : showCrewBar)));
		let visitPanel: unknown = ((visit !== undefined) && reactLoose.createElement(VisitPanel, { visit: visit, dispatch: dispatch, reducedMotion: softMotion, layoutOrder: 1, stack: stack }));
		let emptyPanel: unknown = ((len(allPlayers) === 0) ? reactLoose.createElement(EmptyState, { icon: "Crew.7", title: "No one else is on shift", body: "Crew shows up here once someone else is online with you.", accent: luaProp(Palette, "blue"), layoutOrder: 2 }) : ((len(players) === 0) ? reactLoose.createElement(luaProp(Browse, "NoResults"), { browse: crewBrowse, noun: "crew", icon: "Crew.8", accent: luaProp(Palette, "blue"), reducedMotion: softMotion, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), layoutOrder: 2 }) : undefined));
		let sections: unknown = [{ id: "header", height: headerH, element: headerPanel }];
		for (const [_, section] of pairs((luaCall(crewPartySections, { crewState: crewState, players: allPlayers, dispatch: dispatch, stack: stack, softMotion: softMotion, renameDraft: renameDraft, setRenameDraft: setRenameDraft, note: crewNote, setNote: setCrewNote, confirmKey: confirmKey, setConfirmKey: setConfirmKey })) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaTable.insert(sections, section);
		}
		if (luaTruthy(visitPanel)) {
			luaTable.insert(sections, { id: "visit", height: luaCall(luaProp(PageBoardHeights, "Visit"), stack), element: visitPanel });
		}
		if (luaTruthy(emptyPanel)) {
			luaTable.insert(sections, { id: "empty", height: 180, element: emptyPanel });
		}
		let virtRoster: unknown = ((len(players) as unknown as number) >= (8 as unknown as number));
		if (luaTruthy(virtRoster)) {
			let rosterCards: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(players));
			for (const [index, player] of pairs((players) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(rosterCards, index, reactLoose.createElement(CrewRow, { key: luaProp(player, "UserId"), player: player, visiting: (visitUserId === luaProp(player, "UserId")), visitorsHere: (luaTruthy(luaProp(player, "IsLocal")) ? visitorsHere : 0), onVisit: function(this: void): unknown | undefined {
					return luaCall(startVisit, luaProp(player, "UserId"));
					return undefined;
				}, onNudge: function(this: void): unknown | undefined {
					return luaCall(nudgeCrew, luaProp(player, "UserId"));
					return undefined;
				}, reducedMotion: reducedMotion, layoutOrder: index, stack: stack }));
			}
			luaTable.insert(sections, { id: "roster", fill: true, minHeight: 120, element: reactLoose.createElement(FlatList, { data: players, itemHeight: rowStride, overscan: (luaTruthy(softMotion) ? 0 : (luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2)), canvasTail: 8, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), scrollBarColor: luaProp(Palette, "blue"), scrollBarThickness: 4, keyExtractor: function(this: void, player?: unknown): unknown | undefined {
				return luaProp(player, "UserId");
				return undefined;
			}, renderItem: function(this: void, _param_1?: unknown): unknown | undefined {
				let index: unknown = luaProp(_param_1, "index");
				return luaIndex(rosterCards, ((index as unknown as number) + (1 as unknown as number)));
				return undefined;
			} }) });
		} else {
			for (const [index, player] of pairs((players) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaTable.insert(sections, { id: concat("crew-", tostring(index)), height: rowStride, element: reactLoose.createElement(CrewRow, { key: luaProp(player, "UserId"), player: player, visiting: (visitUserId === luaProp(player, "UserId")), visitorsHere: (luaTruthy(luaProp(player, "IsLocal")) ? visitorsHere : 0), onVisit: function(this: void): unknown | undefined {
					return luaCall(startVisit, luaProp(player, "UserId"));
					return undefined;
				}, onNudge: function(this: void): unknown | undefined {
					return luaCall(nudgeCrew, luaProp(player, "UserId"));
					return undefined;
				}, reducedMotion: reducedMotion, layoutOrder: ((index as unknown as number) + (3 as unknown as number)), stack: stack }) });
			}
		}
		return reactLoose.createElement("frame", { ref: crewHostRef, Name: "CrewVisitClaim", Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(PageScaffold, { gap: listGap, tailPad: crewTail, scrollBarColor: luaProp(Palette, "blue"), scrollBarThickness: 4, sections: sections }));
		return undefined;
	}
	return { CrewView: CrewView };
	return undefined;
}
export = __member();
