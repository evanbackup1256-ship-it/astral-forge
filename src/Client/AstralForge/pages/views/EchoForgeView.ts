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

function __member(): unknown {
	// The Echoes page: the loom (charge and the four tracks), the strike, the chord, every echo you
	// keep, and the journal. Every rule shown here is EchoMath's, so the numbers match the server.

	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let _motion: unknown = kit("MotionKit", "motion");
	let usePulse: unknown = luaProp(_motion, "usePulse");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let darken: unknown = luaProp(_theme, "darken");
	let Palette: unknown = luaProp(_theme, "Palette");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let compactNumber: unknown = luaProp(kit("CoreKit", "format"), "compactNumber");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let Meter: unknown = luaProp(_ui, "Meter");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SectionLabel: unknown = luaProp(_ui, "SectionLabel");
	let Text: unknown = luaProp(_ui, "Text");
	let EchoMath: unknown = luaRequire(colon(colon(colon(ReplicatedStorage).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("EchoMath"));
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let h: unknown = reactLoose.createElement;
	let TIER_COLOR: unknown = { Faint: luaProp(Palette, "muted"), Clear: luaProp(Palette, "cyan"), Vivid: luaProp(Palette, "violet"), Perfect: luaProp(Palette, "mango") };
	let TRACK_ART: unknown = { Collect: { icon: "Collect.echoTrack", color: luaProp(Palette, "mint"), label: "Collecting" }, Surge: { icon: "Overcharge.echoTrack", color: luaProp(Palette, "coral"), label: "Overcharging" }, Build: { icon: "Forge.echoTrack", color: luaProp(Palette, "mango"), label: "Building" }, Explore: { icon: "World.echoTrack", color: luaProp(Palette, "violet"), label: "Exploring" } };
	// each place a trait appears in has its own art for it
	let TRAIT_ART: unknown = { draft: { FurnaceMemory: { icon: "Ember.echoDraftFurnace" }, DeepReservoir: { icon: "Vault.echoDraftReservoir" }, StrikeGhost: { icon: "Overcharge.echoDraftGhost" }, LuckyAfterimage: { icon: "Jackpot.echoDraftAfterimage" }, ClockworkEcho: { icon: "Timer.echoDraftClockwork" }, LatticeRecall: { icon: "Domain.echoDraftLattice" }, NightShift: { icon: "Anomaly.echoDraftNight" }, VoidPulse: { icon: "Continuum.echoDraftVoid" } }, chord: { FurnaceMemory: { icon: "Ember.echoChordFurnace" }, DeepReservoir: { icon: "Vault.echoChordReservoir" }, StrikeGhost: { icon: "Overcharge.echoChordGhost" }, LuckyAfterimage: { icon: "Jackpot.echoChordAfterimage" }, ClockworkEcho: { icon: "Timer.echoChordClockwork" }, LatticeRecall: { icon: "Domain.echoChordLattice" }, NightShift: { icon: "Anomaly.echoChordNight" }, VoidPulse: { icon: "Continuum.echoChordVoid" } }, vault: { FurnaceMemory: { icon: "Ember.echoVaultFurnace" }, DeepReservoir: { icon: "Vault.echoVaultReservoir" }, StrikeGhost: { icon: "Overcharge.echoVaultGhost" }, LuckyAfterimage: { icon: "Jackpot.echoVaultAfterimage" }, ClockworkEcho: { icon: "Timer.echoVaultClockwork" }, LatticeRecall: { icon: "Domain.echoVaultLattice" }, NightShift: { icon: "Anomaly.echoVaultNight" }, VoidPulse: { icon: "Continuum.echoVaultVoid" } }, journal: { FurnaceMemory: { icon: "Ember.echoJournalFurnace" }, DeepReservoir: { icon: "Vault.echoJournalReservoir" }, StrikeGhost: { icon: "Overcharge.echoJournalGhost" }, LuckyAfterimage: { icon: "Jackpot.echoJournalAfterimage" }, ClockworkEcho: { icon: "Timer.echoJournalClockwork" }, LatticeRecall: { icon: "Domain.echoJournalLattice" }, NightShift: { icon: "Anomaly.echoJournalNight" }, VoidPulse: { icon: "Continuum.echoJournalVoid" } } };
	function traitIcon(place?: unknown, traitId?: unknown): unknown | undefined {
		let art: unknown = ((luaTruthy(luaIndex(TRAIT_ART, place) ) ?  luaIndex(luaIndex(TRAIT_ART, place), traitId) : luaIndex(TRAIT_ART, place)));
		return (luaTruthy(art) ? luaProp(art, "icon") : undefined);
		return undefined;
	}
	let KIND_WORDS: unknown = { Production: "production", Capacity: "vault capacity", Tap: "overcharge power", Critical: "critical chance", Automation: "auto-collect", Offline: "offline earnings" };
	function pct(value?: unknown): unknown | undefined {
		let p: unknown = ((value as unknown as number) * (100 as unknown as number));
		return (((p as unknown as number) >= (10 as unknown as number)) ? (string.format as unknown as (...a: unknown[]) => unknown)("+%d%%", (math.floor as unknown as (...a: unknown[]) => unknown)(((p as unknown as number) + (0.5 as unknown as number)))) : (string.format as unknown as (...a: unknown[]) => unknown)("+%.1f%%", p));
		return undefined;
	}
	function effectLines(effects?: unknown): unknown | undefined {
		let lines: unknown = {};
		for (const [_, kind] of pairs((luaProp(EchoMath, "KINDS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let v: unknown = luaIndex(effects, kind);
			if ((luaTruthy(v) && ((v as unknown as number) > (0 as unknown as number)))) {
				luaTable.insert(lines, `${luaCall(pct, v)} ${luaIndex(KIND_WORDS, kind)}`);
			}
		}
		return luaTable.concat(lines, "  ·  ");
		return undefined;
	}
	function chip(text?: unknown, color?: unknown, order?: unknown): unknown | undefined {
		return luaCall(h, "textlabel", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, 22), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), LayoutOrder: order, BackgroundColor3: luaCall(darken, color, 0.6), Text: text, TextSize: 12, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextColor3: color }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), luaCall(h, "uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 9), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 9) }));
		return undefined;
	}
	// one echo as a card: trait art, name, tier, level, what it does, and what you can do with it
	function EchoCard(props?: unknown): unknown | undefined {
		let echo: unknown = luaProp(props, "echo");
		let trait: unknown = luaCall(luaProp(EchoMath, "trait"), luaProp(echo, "Trait"));
		let tierColor: unknown = ((luaTruthy(luaIndex(TIER_COLOR, luaProp(echo, "Tier")) ) ? luaIndex(TIER_COLOR, luaProp(echo, "Tier")) :  luaProp(Palette, "cream")));
		let effects: unknown = ((luaTruthy(luaProp(echo, "Effects") ) ? luaProp(echo, "Effects") :  luaCall(luaProp(EchoMath, "effects"), echo)));
		let reveal: unknown = luaCall(useStagger, ((luaTruthy(luaProp(props, "index") ) ? luaProp(props, "index") :  0)), luaProp(props, "reducedMotion"));
		return luaCall(h, Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: tierColor, background: luaProp(Palette, "panel"), padding: 12, reveal: reveal, reducedMotion: luaProp(props, "reducedMotion") }, luaCall(h, Icon, { kind: (luaCall(traitIcon, luaProp(props, "place"), luaProp(echo, "Trait")) || "Wave.echoUnknown"), size: 44, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 0) }), luaCall(h, Text, { value: (((luaTruthy(trait ) ?  luaProp(trait, "Name") : trait)) || luaProp(echo, "Trait")), size: 15, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), 54, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -54, 0, 20) }), luaCall(h, Text, { value: `${(string.upper as unknown as (...a: unknown[]) => unknown)(luaProp(echo, "Tier"))}  ·  LEVEL ${luaProp(echo, "Level")}${(luaTruthy(luaProp(echo, "Locked")) ? "  ·  LOCKED" : "")}`, size: 11, color: tierColor, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 54, 22), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -54, 0, 16) }), luaCall(h, Text, { value: luaCall(effectLines, effects), size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 52), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 34) }), (((len((((luaTruthy(luaProp(echo, "Imprints") ) ? luaProp(echo, "Imprints") :  {})))) as unknown as number) > (0 as unknown as number)) && luaCall(h, Text, { value: concat("Imprints: ", luaTable.concat(luaCall((function(this: void): unknown | undefined {
			let words: unknown = {};
			for (const [_, kind] of pairs((luaProp(echo, "Imprints")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaTable.insert(words, ((luaTruthy(luaIndex(KIND_WORDS, kind) ) ? luaIndex(KIND_WORDS, kind) :  kind)));
			}
			return words;
			return undefined;
		})), ", ")), size: 11, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 86), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) })), ((luaTruthy(luaProp(props, "actions") ) ?  luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((luaTruthy(luaProp(props, "actionsHeight") ) ? luaProp(props, "actionsHeight") :  TapTarget))), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 1), BackgroundTransparency: 1 }, luaProp(props, "actions")) : luaProp(props, "actions"))));
		return undefined;
	}
	function EchoForgeView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let stack: unknown = luaProp(chrome, "contentStack");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let echoes: unknown = ((luaTruthy(luaProp(state, "ForgeEchoes") ) ? luaProp(state, "ForgeEchoes") :  {}));
		// a controller lands on Strike the moment the charge is full
		let strikeHost: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!((luaTruthy(luaProp(echoes, "Ready")) && luaTruthy(luaProp(UserInputService, "GamepadEnabled")))))) {
				return undefined;
			}
			let job: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if (((luaProp(strikeHost, "current") !== undefined) && (luaProp(luaProp(strikeHost, "current"), "Parent") !== undefined))) {
					luaCall(luaProp(GamepadNavigationService, "FocusClaim"), luaProp(strikeHost, "current"));
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, [luaProp(echoes, "Ready")]);
		let armed: unknown;
		let setArmed: unknown;
		[armed, setArmed] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let slotting: unknown;
		let setSlotting: unknown;
		[slotting, setSlotting] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let readyPulse: unknown = luaCall(usePulse, ((luaProp(echoes, "Ready") === true) && (!luaTruthy(softMotion))), 1.6);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((armed === undefined)) {
				return undefined;
			}
			let lapse: unknown = (task.delay as unknown as (...a: unknown[]) => unknown)(4, function(this: void): unknown | undefined {
				luaCall(setArmed, undefined);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), lapse);
				return undefined;
			};
			return undefined;
		}, [armed]);
		function act(payload?: unknown): unknown | undefined {
			luaCall(dispatch, "EchoAct", payload);
			return undefined;
		}
		if ((luaProp(echoes, "Version") !== 2)) {
			return luaCall(h, Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 120), accent: luaProp(Palette, "cyan"), padding: 16 }, luaCall(h, Text, { value: "Your echoes are being carried over to the new forge. Give it a moment.", size: 14, color: luaProp(Palette, "creamSoft"), wrap: true, sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1) }));
		}
		let sections: unknown = {};
		let gap: unknown = (luaTruthy(stack) ? 10 : 14);
		// the loom: charge, tracks, strike
		let tracks: unknown = {};
		let trackTotal: unknown = 0;
		for (const [_, track] of pairs((luaProp(EchoMath, "TRACKS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			trackTotal = ((trackTotal as unknown as number) + (((luaTruthy(luaIndex(luaProp(echoes, "Tracks"), track) ) ? luaIndex(luaProp(echoes, "Tracks"), track) :  0)) as unknown as number));
		}
		for (const [index, track] of pairs((luaProp(EchoMath, "TRACKS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let art: unknown = luaIndex(TRACK_ART, track);
			let share: unknown = (((((luaTruthy(luaIndex(luaProp(echoes, "Tracks"), track) ) ? luaIndex(luaProp(echoes, "Tracks"), track) :  0))) as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, trackTotal) as unknown as number));
			luaSetIndex(tracks, concat("t", track), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 30), LayoutOrder: index, BackgroundTransparency: 1 }, luaCall(h, Icon, { kind: luaProp(art, "icon"), size: 26, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 2) }), luaCall(h, Text, { value: concat(luaProp(art, "label"), ((((luaProp(echoes, "Dominant") === track) && ((trackTotal as unknown as number) > (0 as unknown as number))) ? "  ·  leading" : ""))), size: 12, color: (((luaProp(echoes, "Dominant") === track) && ((trackTotal as unknown as number) > (0 as unknown as number))) ? luaProp(art, "color") : luaProp(Palette, "creamSoft")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), position: luaCall(luaProp(UDim2, "fromOffset"), 34, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.45, -34, 0, 16) }), luaCall(h, Meter, { value: share, color: luaProp(art, "color"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.55, -10, 0, 6), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.45, 10, 0, 12) })));
		}
		let charge: unknown = ((luaProp(echoes, "Charge") as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, luaProp(echoes, "ChargeTarget")) as unknown as number));
		luaTable.insert(sections, { id: "loom", height: (luaTruthy(stack) ? 300 : 236), element: luaCall(h, Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "cyan"), background: luaProp(Palette, "panel"), padding: 16, reducedMotion: softMotion }, luaCall(h, SectionLabel, { value: "THE LOOM", color: luaProp(Palette, "cyan") }), luaCall(h, Text, { value: (luaTruthy(luaProp(echoes, "Ready")) ? "The charge is full. Strike to see what answers." : `${(math.floor as unknown as (...a: unknown[]) => unknown)(((charge as unknown as number) * (100 as unknown as number)))}% charged. Play leaves a trace: whatever you do most shapes the first echo.`), size: 13, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36) }), luaCall(h, Meter, { value: charge, color: (luaTruthy(luaProp(echoes, "Ready")) ? luaProp(Palette, "mango") : luaProp(Palette, "cyan")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 10), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 70) }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)((luaTruthy(stack) ? 1 : 0.6), 0, 0, ((4 as unknown as number) * (34 as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 92), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 4), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), tracks), luaCall(h, "frame", { Name: "EchoClaimActions", ref: strikeHost, ClipsDescendants: false, Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.36, 0, 0, TapTarget)), Position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(TapTarget as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 100)), AnchorPoint: (luaTruthy(stack) ? luaProp(Vector2, "zero") : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0)), BackgroundTransparency: 1 }, luaCall(h, "uiscale", { Scale: colon(readyPulse).map(function(this: void, p?: unknown): unknown | undefined {
			return ((1 as unknown as number) + (((p as unknown as number) * (0.03 as unknown as number)) as unknown as number));
			return undefined;
		}) }), luaCall(h, Button, { text: (((len((((luaTruthy(luaProp(echoes, "Draft") ) ? luaProp(echoes, "Draft") :  {})))) as unknown as number) > (0 as unknown as number)) ? "Pick an echo below" : (luaTruthy(luaProp(echoes, "Ready")) ? "Strike" : "Charging")), onClick: function(this: void): unknown | undefined {
			luaCall(act, { Op: "Strike" });
			return undefined;
		}, disabled: ((!luaTruthy(luaProp(echoes, "Ready"))) || ((len((((luaTruthy(luaProp(echoes, "Draft") ) ? luaProp(echoes, "Draft") :  {})))) as unknown as number) > (0 as unknown as number))), color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), highlight: luaProp(echoes, "Ready"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion }))) });
		// the strike: three echoes, keep one (or reroll once for resonance)
		if (((len((((luaTruthy(luaProp(echoes, "Draft") ) ? luaProp(echoes, "Draft") :  {})))) as unknown as number) > (0 as unknown as number))) {
			let cards: unknown = {};
			for (const [index, choice] of pairs((luaProp(echoes, "Draft")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(cards, concat("c", index), luaCall(h, "frame", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 170) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), -8, 1, 0)), LayoutOrder: index, BackgroundTransparency: 1 }, luaCall(h, EchoCard, { echo: choice, place: "draft", index: index, reducedMotion: softMotion, actions: luaCall(h, Button, { text: "Keep this one", onClick: function(this: void): unknown | undefined {
					luaCall(act, { Op: "Keep", Choice: index });
					return undefined;
				}, color: ((luaTruthy(luaIndex(TIER_COLOR, luaProp(choice, "Tier")) ) ? luaIndex(TIER_COLOR, luaProp(choice, "Tier")) :  luaProp(Palette, "mango"))), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion }) })));
			}
			let cardsH: unknown = (luaTruthy(stack) ? ((3 as unknown as number) * (178 as unknown as number)) : 178);
			luaTable.insert(sections, { id: "draft", height: ((((((32 as unknown as number) + (cardsH as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) + (TapTarget as unknown as number)), element: luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, luaCall(h, SectionLabel, { value: "WHAT ANSWERED", color: luaProp(Palette, "mango") }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, cardsH), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 32), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: (luaTruthy(stack) ? luaProp(luaProp(Enum, "FillDirection"), "Vertical") : luaProp(luaProp(Enum, "FillDirection"), "Horizontal")), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), cards), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 260, 0, TapTarget), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 1), BackgroundTransparency: 1 }, luaCall(h, Button, { text: (luaTruthy(luaProp(echoes, "Rerolled")) ? "Already rerolled" : `Reroll for ${luaProp(EchoMath, "REROLL_RESONANCE")} resonance`), onClick: function(this: void): unknown | undefined {
				luaCall(act, { Op: "Reroll" });
				return undefined;
			}, disabled: ((luaTruthy(luaProp(echoes, "Rerolled") ) ? luaProp(echoes, "Rerolled") :  ((luaProp(echoes, "Resonance") as unknown as number) < (luaProp(EchoMath, "REROLL_RESONANCE") as unknown as number)))), color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion }))) });
		}
		// the chord: four slots, its bonuses and what it all adds up to
		let byUid: unknown = {};
		for (const [_, echo] of pairs((luaProp(echoes, "Inventory")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(byUid, luaProp(echo, "Uid"), echo);
		}
		let slots: unknown = {};
		for (const [_, slot] of pairs((luaProp(echoes, "Chord")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let echo: unknown = luaIndex(byUid, luaProp(slot, "Uid"));
			let placing: unknown = ((slotting !== undefined) && luaProp(slot, "Open"));
			luaSetIndex(slots, concat("s", luaProp(slot, "Slot")), luaCall(h, "textbutton", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 96) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -6, 1, 0)), LayoutOrder: luaProp(slot, "Slot"), BackgroundColor3: (luaTruthy(placing) ? luaCall(darken, luaProp(Palette, "mango"), 0.6) : luaProp(Palette, "panelSoft")), AutoButtonColor: false, Text: "", Event: { Activated: function(this: void): unknown | undefined {
				if (((slotting !== undefined) && luaTruthy(luaProp(slot, "Open")))) {
					luaCall(act, { Op: "Slot", Slot: luaProp(slot, "Slot"), Uid: slotting });
					luaCall(setSlotting, undefined);
				} else if ((echo !== undefined)) {
					luaCall(act, { Op: "Slot", Slot: luaProp(slot, "Slot"), Uid: "" });
				}
				return undefined;
			} } }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), luaCall(h, "uistroke", { Color: (luaTruthy(echo) ? (((luaTruthy(luaIndex(TIER_COLOR, luaProp(echo, "Tier")) ) ? luaIndex(TIER_COLOR, luaProp(echo, "Tier")) :  luaProp(Palette, "line")))) : (luaTruthy(placing) ? luaProp(Palette, "mango") : luaProp(Palette, "line"))), Thickness: (luaTruthy(placing) ? 2 : 1) }), luaCall(h, "uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), (luaTruthy(echo) ? luaCall(h, Icon, { kind: (luaCall(traitIcon, "chord", luaProp(echo, "Trait")) || "Wave.echoChordUnknown"), size: 34 }) : undefined), luaCall(h, Text, { value: (luaTruthy(echo) ? luaProp(luaCall(luaProp(EchoMath, "trait"), luaProp(echo, "Trait")), "Name") : (luaTruthy(luaProp(slot, "Open")) ? ((luaTruthy(placing) ? "Put it here" : "Empty")) : `Opens at ${luaProp(slot, "NeedsCaptures")} kept`)), size: 12, color: (luaTruthy(echo) ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(echo) ? 40 : 8)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) }), ((luaTruthy(echo ) ?  luaCall(h, Text, { value: `${luaProp(echo, "Tier")} · L${luaProp(echo, "Level")}`, size: 11, color: ((luaTruthy(luaIndex(TIER_COLOR, luaProp(echo, "Tier")) ) ? luaIndex(TIER_COLOR, luaProp(echo, "Tier")) :  luaProp(Palette, "muted"))), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 58), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) }) : echo))));
		}
		let bonusChips: unknown = {};
		let order: unknown = 0;
		for (const [_, entry] of pairs(([["Harmony", "HARMONY +15%", luaProp(Palette, "mint")], ["Unison", "UNISON +10%", luaProp(Palette, "cyan")], ["Spectrum", "SPECTRUM +20%", luaProp(Palette, "mango")]]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaTruthy(luaProp(echoes, "Bonuses")) && luaTruthy(luaIndex(luaProp(echoes, "Bonuses"), luaIndex(entry, 1))))) {
				order = ((order as unknown as number) + (1 as unknown as number));
				luaSetIndex(bonusChips, concat("b", order), luaCall(chip, luaIndex(entry, 2), luaIndex(entry, 3), order));
			}
		}
		let totals: unknown = {};
		for (const [_, kind] of pairs((luaProp(EchoMath, "KINDS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let v: unknown = (((luaTruthy(luaProp(echoes, "Totals") ) ?  luaIndex(luaProp(echoes, "Totals"), kind) : luaProp(echoes, "Totals"))) || 0);
			if (((v as unknown as number) > (0 as unknown as number))) {
				luaTable.insert(totals, `${luaCall(pct, v)} ${luaIndex(KIND_WORDS, kind)}`);
			}
		}
		let slotsH: unknown = (luaTruthy(stack) ? 200 : 110);
		luaTable.insert(sections, { id: "chord", height: ((((((((((32 as unknown as number) + (slotsH as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) + (22 as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) + (36 as unknown as number)), element: luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, luaCall(h, SectionLabel, { value: (luaTruthy(slotting) ? "THE CHORD · PICK A SLOT" : "THE CHORD"), color: luaProp(Palette, "violet") }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, slotsH), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 32), BackgroundTransparency: 1 }, luaCall(h, "uigridlayout", { CellSize: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 96) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -6, 1, 0)), CellPadding: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), slots), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 22), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((((32 as unknown as number) + (slotsH as unknown as number)) as unknown as number) + (8 as unknown as number))), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), bonusChips), luaCall(h, Text, { value: (((len(totals) as unknown as number) > (0 as unknown as number)) ? concat("The chord adds ", concat(luaTable.concat(totals, ", "), ".")) : "Put echoes in the chord to feel them. Matching affinities add Harmony; a matched pair adds Unison; four different affinities make a Spectrum."), size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((((((32 as unknown as number) + (slotsH as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) + (26 as unknown as number))), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36) })) });
		// the vault: every echo you keep
		let columns: unknown = (luaTruthy(stack) ? 1 : (((luaProp(viewport, "width") as unknown as number) >= (1500 as unknown as number)) ? 3 : 2));
		let cardH: unknown = 186;
		let vault: unknown = {};
		for (const [index, echo] of pairs((luaProp(echoes, "Inventory")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let partner: unknown = undefined;
			for (const [_, other] of pairs((luaProp(echoes, "Inventory")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((((luaProp(other, "Uid") !== luaProp(echo, "Uid")) && (luaProp(other, "Trait") === luaProp(echo, "Trait"))) && (luaProp(other, "Tier") === luaProp(echo, "Tier"))) && (!luaTruthy(luaProp(other, "Locked"))))) {
					partner = other;
				}
			}
			let canFuse: unknown = (((partner !== undefined) && (!luaTruthy(luaProp(echo, "Locked")))) && (luaCall(luaProp(EchoMath, "nextTier"), luaProp(echo, "Tier")) !== undefined));
			let isArmed: unknown = (armed === luaProp(echo, "Uid"));
			let actionList: unknown = [["Slot", function(this: void): unknown | undefined {
				luaCall(setSlotting, ((slotting === luaProp(echo, "Uid")) ? undefined : luaProp(echo, "Uid")));
				return undefined;
			}, luaProp(Palette, "violet"), false], [`Tune · ${luaCall(compactNumber, luaProp(echo, "TuneCost"))}`, function(this: void): unknown | undefined {
				luaCall(act, { Op: "Tune", Uid: luaProp(echo, "Uid") });
				return undefined;
			}, luaProp(Palette, "cyan"), (((((tonumber(luaProp(state, "Stardust")) || 0)) as unknown as number) < (luaProp(echo, "TuneCost") as unknown as number)) || ((luaProp(echo, "Level") as unknown as number) >= (luaProp(EchoMath, "MAX_LEVEL") as unknown as number)))], ["Fuse", function(this: void): unknown | undefined {
				luaCall(act, { Op: "Fuse", A: luaProp(echo, "Uid"), B: luaProp(partner, "Uid") });
				return undefined;
			}, luaProp(Palette, "mango"), (!luaTruthy(canFuse))], [(luaTruthy(luaProp(echo, "Locked")) ? "Unlock" : "Lock"), function(this: void): unknown | undefined {
				luaCall(act, { Op: "Lock", Uid: luaProp(echo, "Uid") });
				return undefined;
			}, luaProp(Palette, "panelSoft"), false], [(luaTruthy(isArmed) ? "Sure?" : `Break · +${luaProp(echo, "Resonance")}`), function(this: void): unknown | undefined {
				if (luaTruthy(isArmed)) {
					luaCall(setArmed, undefined);
					luaCall(act, { Op: "Dismantle", Uid: luaProp(echo, "Uid") });
				} else {
					luaCall(setArmed, luaProp(echo, "Uid"));
				}
				return undefined;
			}, (luaTruthy(isArmed) ? luaProp(Palette, "coral") : luaProp(Palette, "panelSoft")), luaProp(echo, "Locked")]];
			let buttons: unknown = {};
			for (const [i, a] of pairs((actionList) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(buttons, concat("a", i), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (len(actionList) as unknown as number)), -6, 1, 0), LayoutOrder: i, BackgroundTransparency: 1 }, luaCall(h, Button, { text: luaIndex(a, 1), onClick: luaIndex(a, 2), color: luaIndex(a, 3), textColor: ((luaIndex(a, 3) === luaProp(Palette, "panelSoft")) ? luaProp(Palette, "cream") : luaProp(Palette, "ink")), disabled: luaIndex(a, 4), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion })));
			}
			luaSetIndex(vault, concat("v", luaProp(echo, "Uid")), luaCall(h, "frame", { LayoutOrder: index, BackgroundTransparency: 1 }, luaCall(h, EchoCard, { echo: echo, place: "vault", index: index, reducedMotion: softMotion, actionsHeight: 34, actions: luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), buttons) })));
		}
		let rows: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(1, (math.ceil as unknown as (...a: unknown[]) => unknown)(((len(luaProp(echoes, "Inventory")) as unknown as number) / (columns as unknown as number))));
		luaTable.insert(sections, { id: "vault", height: ((32 as unknown as number) + ((((len(luaProp(echoes, "Inventory")) === 0) ? 80 : ((((rows as unknown as number) * (cardH as unknown as number)) as unknown as number) + ((((((rows as unknown as number) - (1 as unknown as number))) as unknown as number) * (8 as unknown as number)) as unknown as number)))) as unknown as number)), element: luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, luaCall(h, SectionLabel, { value: `KEPT · ${len(luaProp(echoes, "Inventory"))}/${luaProp(echoes, "InventoryLimit")}  ·  ${luaCall(compactNumber, luaProp(echoes, "Resonance"))} RESONANCE`, color: luaProp(Palette, "cyan") }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -32), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 32), BackgroundTransparency: 1 }, (((len(luaProp(echoes, "Inventory")) as unknown as number) > (0 as unknown as number)) && luaCall(h, "uigridlayout", { CellSize: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (columns as unknown as number)), ((((-8 as unknown as number) * ((((columns as unknown as number) - (1 as unknown as number))) as unknown as number)) as unknown as number) / (columns as unknown as number)), 0, cardH), CellPadding: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") })), (((len(luaProp(echoes, "Inventory")) as unknown as number) > (0 as unknown as number)) ? vault : luaCall(h, Text, { value: "Nothing kept yet. Fill the charge and strike.", size: 13, color: luaProp(Palette, "muted"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) })))) });
		// the journal: every trait at every tier
		let journalRows: unknown = {};
		for (const [index, trait] of pairs((luaProp(EchoMath, "TRAITS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let reached: unknown = (((luaTruthy(luaProp(echoes, "Journal") ) ?  luaIndex(luaProp(echoes, "Journal"), luaProp(trait, "Id")) : luaProp(echoes, "Journal"))) || 0);
			let pips: unknown = {};
			for (const [t, tier] of pairs((luaProp(EchoMath, "TIERS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(pips, concat("p", t), luaCall(chip, (string.upper as unknown as (...a: unknown[]) => unknown)(tier), (((t as unknown as number) <= (reached as unknown as number)) ? luaIndex(TIER_COLOR, tier) : luaProp(Palette, "lineSoft")), t));
			}
			luaSetIndex(journalRows, concat("j", index), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 30), LayoutOrder: index, BackgroundTransparency: 1 }, luaCall(h, Icon, { kind: luaCall(traitIcon, "journal", luaProp(trait, "Id")), size: 24, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 3) }), luaCall(h, Text, { value: concat(luaProp(trait, "Name"), ((((reached as unknown as number) >= (len(luaProp(EchoMath, "TIERS")) as unknown as number)) ? "  ·  complete, +3% for good" : ""))), size: 12, color: (((reached as unknown as number) >= (len(luaProp(EchoMath, "TIERS")) as unknown as number)) ? luaProp(Palette, "mango") : luaProp(Palette, "creamSoft")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 32, 7), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.4, -32, 0, 16) }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.6, 0, 1, 0), Position: luaCall(luaProp(UDim2, "fromScale"), 0.4, 0), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), pips)));
		}
		luaTable.insert(sections, { id: "journal", height: ((((32 as unknown as number) + (((len(luaProp(EchoMath, "TRAITS")) as unknown as number) * (34 as unknown as number)) as unknown as number)) as unknown as number) + (16 as unknown as number)), element: luaCall(h, Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "lineSoft"), background: luaProp(Palette, "panel"), padding: 14 }, luaCall(h, SectionLabel, { value: "JOURNAL · ALL TIERS OF A TRAIT = PERMANENT BONUS", color: luaProp(Palette, "mango") }), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -30), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 30), BackgroundTransparency: 1 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 4), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), journalRows)) });
		return reactLoose.createElement(PageScaffold, { gap: gap, tailPad: luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), (luaTruthy(stack) ? 72 : 56)), scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: 4, sections: sections });
		return undefined;
	}
	return { EchoForgeView: EchoForgeView };
	return undefined;
}
export = __member();
