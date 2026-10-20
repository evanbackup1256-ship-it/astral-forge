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

const AstralForge = script.Parent!;

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
		error(`UiOverlays: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`UiOverlays: cyclic require of member ${name}`, 2);
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

__defs["DomainChamber"] = () => {
	// (ZIndex 600+: the main screen sorts globally and the chamber has to sit over the whole shell)
	// The Domain, one screen: the lattice on the left, and on the right whatever you're doing with it.
	//   mode "lattice": etch links between anchors, read what the lattice gives, clear it once per rank
	//   mode "confirm": the expansion rite; hold to expand, with what it costs, keeps and pays
	//   mode "result":  a ring of heat leaves the Hearth, the new rank lands and the rewards count in

	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let RunService: unknown = colon(game).GetService("RunService");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let useViewport: unknown = luaProp(kit("MotionKit", "motion"), "useViewport");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let _theme: unknown = kit("CoreKit", "theme");
	let Palette: unknown = luaProp(_theme, "Palette");
	let darken: unknown = luaProp(_theme, "darken");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let compactNumber: unknown = luaProp(kit("CoreKit", "format"), "compactNumber");
	let shared: unknown = colon(colon(ReplicatedStorage).WaitForChild("AstralForge")).WaitForChild("Shared");
	let GameConfig: unknown = luaRequire(colon(shared).WaitForChild("GameConfig"));
	let DomainLattice: unknown = luaRequire(colon(shared).WaitForChild("DomainLattice"));
	let h: unknown = reactLoose.createElement;
	let WHITE_HOT: unknown = luaCall(luaProp(Color3, "fromRGB"), 255, 244, 222);
	let HOLD_SECONDS: unknown = 1.1;
	let SCALE: unknown = ((0.5 as unknown as number) / (2.2 as unknown as number));
	let KIND_COLOR: unknown = { Production: luaProp(Palette, "mango"), Capacity: luaProp(Palette, "cyan"), Tap: luaProp(Palette, "coral"), RebirthYield: luaProp(Palette, "violet"), Critical: luaProp(Palette, "pink"), EchoCharge: luaProp(Palette, "mint"), ContinuumDiscount: luaProp(Palette, "mango"), Offline: luaProp(Palette, "cyan"), Luck: luaProp(Palette, "mint"), WorldDiscount: luaProp(Palette, "violet"), EssenceGain: luaProp(Palette, "pink"), ForgePathXP: luaProp(Palette, "mango"), CommandXP: luaProp(Palette, "coral") };
	let KIND_ICON: unknown = { Production: "Flux.23", Capacity: "Vault.9", Tap: "Overcharge.10", RebirthYield: "Rebirth.10", Critical: "Jackpot.4", EchoCharge: "Wave.17", ContinuumDiscount: "Continuum.4", Offline: "Timer.9", Luck: "Gift.18", WorldDiscount: "World.12", EssenceGain: "Artifact.9", ForgePathXP: "Milestone.7", CommandXP: "Command.6" };
	let KEEPS: unknown = "Research, relics, Stardust, milestones, your crew and guild";
	let RESETS: unknown = "Machines, Flux, the vault, worlds, and the rebirths and Cores you spend";
	function easeOut(t?: unknown): unknown | undefined {
		let u: unknown = ((1 as unknown as number) - (luaCall(luaProp(math, "clamp"), t, 0, 1) as unknown as number));
		return ((1 as unknown as number) - (((((u as unknown as number) * (u as unknown as number)) as unknown as number) * (u as unknown as number)) as unknown as number));
		return undefined;
	}
	function asNumber(value?: unknown): unknown | undefined {
		let n: unknown = luaCall(tonumber, value);
		return (((n !== undefined) && (n === n)) ? n : 0);
		return undefined;
	}
	function spot(index?: unknown): unknown | undefined {
		let x: unknown;
		let y: unknown;
		[x, y] = luaCall(luaProp(DomainLattice, "position"), index) as LuaTuple<[unknown, unknown]>;
		return $tuple(((0.5 as unknown as number) + (((x as unknown as number) * (SCALE as unknown as number)) as unknown as number)), ((0.5 as unknown as number) + (((y as unknown as number) * (SCALE as unknown as number)) as unknown as number)));
		return undefined;
	}
	function colorOf(index?: unknown): unknown | undefined {
		let anchor: unknown = luaIndex(luaProp(DomainLattice, "ANCHORS"), index);
		return (((anchor && luaIndex(KIND_COLOR, luaProp(anchor, "kind")))) || luaProp(Palette, "mango"));
		return undefined;
	}
	function splitKey(key?: unknown): unknown | undefined {
		let a: unknown;
		let b: unknown;
		[a, b] = luaCall(luaProp(string, "match"), key, "^(%d+)%-(%d+)$") as LuaTuple<[unknown, unknown]>;
		return $tuple(luaCall(tonumber, a), luaCall(tonumber, b));
		return undefined;
	}
	// a line between two points of the square canvas, drawn `p` of the way from the first
	function line(x1?: unknown, y1?: unknown, x2?: unknown, y2?: unknown, thickness?: unknown, p?: unknown): unknown | undefined {
		const _init1 = (((((x2 as unknown as number) - (x1 as unknown as number))) as unknown as number) * (p as unknown as number));
		const _init2 = (((((y2 as unknown as number) - (y1 as unknown as number))) as unknown as number) * (p as unknown as number));
		let dx: unknown = _init1;
		let dy: unknown = _init2;
		let length: unknown = luaCall(luaProp(math, "sqrt"), ((((dx as unknown as number) * (dx as unknown as number)) as unknown as number) + (((dy as unknown as number) * (dy as unknown as number)) as unknown as number)));
		return $tuple(new (UDim2 as unknown as new (...args: unknown[]) => unknown)(length, 0, 0, thickness), luaCall(luaProp(UDim2, "fromScale"), ((x1 as unknown as number) + (((dx as unknown as number) / (2 as unknown as number)) as unknown as number)), ((y1 as unknown as number) + (((dy as unknown as number) / (2 as unknown as number)) as unknown as number))), luaCall(luaProp(math, "deg"), luaCall(luaProp(math, "atan2"), ((y2 as unknown as number) - (y1 as unknown as number)), ((x2 as unknown as number) - (x1 as unknown as number)))));
		return undefined;
	}
	function surgeLabel(): unknown | undefined {
		let boost: unknown = (luaProp(GameConfig, "Boosts") && luaIndex(luaProp(GameConfig, "Boosts"), (luaProp(luaProp(GameConfig, "Domain"), "SurgeBoostId") || "DomainSurge")));
		if ((boost === undefined)) {
			return "Domain Surge";
		}
		let minutes: unknown = luaCall(luaProp(math, "floor"), ((((((luaCall(tonumber, luaProp(boost, "Duration")) || 1800)) as unknown as number) / (60 as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
		return `Domain Surge for ${minutes} min`;
		return undefined;
	}
	// what etching a link would change, for the preview
	function etchPreview(links?: unknown, key?: unknown): unknown | undefined {
		let a: unknown;
		let b: unknown;
		[a, b] = luaCall(splitKey, key) as LuaTuple<[unknown, unknown]>;
		let degree: unknown = luaCall(luaProp(DomainLattice, "degrees"), links);
		let lines: unknown = {};
		for (const [_, index] of pairs(([a, b]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let anchor: unknown = luaIndex(luaProp(DomainLattice, "ANCHORS"), index);
			let d: unknown = (luaIndex(degree, index) || 0);
			let gain: unknown = ((luaCall(luaProp(DomainLattice, "anchorBonus"), index, ((d as unknown as number) + (1 as unknown as number))) as unknown as number) - (luaCall(luaProp(DomainLattice, "anchorBonus"), index, d) as unknown as number));
			luaTable.insert(lines, { color: luaCall(colorOf, index), text: `${luaProp(anchor, "name")}: ${luaCall(luaProp(DomainLattice, "describe"), luaProp(anchor, "kind"), gain)}` });
		}
		let after: unknown = luaCall(luaProp(table, "clone"), links);
		luaSetIndex(after, key, true);
		let closes: unknown = ((len(luaCall(luaProp(DomainLattice, "facets"), after)) as unknown as number) - (len(luaCall(luaProp(DomainLattice, "facets"), links)) as unknown as number));
		if (((closes as unknown as number) > (0 as unknown as number))) {
			luaTable.insert(lines, { color: luaProp(Palette, "mango"), text: `Closes ${((closes === 1) ? "a facet" : concat(closes, " facets"))}: ${luaCall(luaProp(DomainLattice, "describe"), "Production", ((closes as unknown as number) * (luaProp(DomainLattice, "FACET_PRODUCTION") as unknown as number)))}` });
		}
		return lines;
		return undefined;
	}
	function Lattice(props?: unknown): unknown | undefined {
		const _init3 = luaProp(props, "links");
		const _init4 = luaProp(props, "tick");
		const _init5 = luaProp(props, "selected");
		let links: unknown = _init3;
		let tick: unknown = _init4;
		let selected: unknown = _init5;
		let degree: unknown = luaCall(luaProp(DomainLattice, "degrees"), links);
		let facetSet: unknown = {};
		for (const [_, index] of pairs((luaCall(luaProp(DomainLattice, "facets"), links)) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(facetSet, index, true);
		}
		let reached: unknown = { [luaProp(DomainLattice, "HEARTH") as never]: true };
		for (const [index, d] of pairs((degree) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (((d as unknown as number) > (0 as unknown as number))) {
				luaSetIndex(reached, index, true);
			}
		}
		let children: unknown = {};
		// the figure's guide rings, faint like a drafting sheet
		for (const [ring, radius] of pairs(([1, 1.92]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let s: unknown = ((((radius as unknown as number) * (SCALE as unknown as number)) as unknown as number) * (2 as unknown as number));
			luaSetIndex(children, concat("guide", ring), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), s, s), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 602 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), luaCall(h, "uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 })));
		}
		// the heat ring that leaves the Hearth when a rank lands
		luaSet(children, "flare", luaCall(h, "frame", { Size: colon(luaProp(props, "flare")).map(function(f?: unknown): unknown | undefined {
			let s: unknown = ((luaCall(easeOut, f) as unknown as number) * (1.3 as unknown as number));
			return luaCall(luaProp(UDim2, "fromScale"), s, s);
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, Visible: colon(luaProp(props, "flare")).map(function(f?: unknown): unknown | undefined {
			return (((f as unknown as number) > (0.001 as unknown as number)) && ((f as unknown as number) < (1 as unknown as number)));
			return undefined;
		}), ZIndex: 609 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), luaCall(h, "uistroke", { Color: WHITE_HOT, Thickness: colon(luaProp(props, "flare")).map(function(f?: unknown): unknown | undefined {
			return ((2 as unknown as number) + ((((((1 as unknown as number) - (f as unknown as number))) as unknown as number) * (10 as unknown as number)) as unknown as number));
			return undefined;
		}), Transparency: colon(luaProp(props, "flare")).map(function(f?: unknown): unknown | undefined {
			return f;
			return undefined;
		}) })));
		for (const [_, e] of pairs((luaProp(DomainLattice, "EDGES")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let x1: unknown;
			let y1: unknown;
			[x1, y1] = luaCall(spot, luaProp(e, "a")) as LuaTuple<[unknown, unknown]>;
			let x2: unknown;
			let y2: unknown;
			[x2, y2] = luaCall(spot, luaProp(e, "b")) as LuaTuple<[unknown, unknown]>;
			let etched: unknown = (luaIndex(links, luaProp(e, "key")) === true);
			let open: unknown = ((!etched) && ((luaIndex(reached, luaProp(e, "a")) || luaIndex(reached, luaProp(e, "b")))));
			let picked: unknown = (((selected !== undefined) && (luaProp(selected, "kind") === "link")) && (luaProp(selected, "id") === luaProp(e, "key")));
			if (etched) {
				// molten: a glow, a hot core drawing itself in from the Hearth's side, and a beat running outward
				let key: unknown = luaProp(e, "key");
				function drawn(now?: unknown): unknown | undefined {
					let at: unknown = luaIndex(luaProp(props, "etchedAt"), key);
					return ((at === undefined) ? 1 : luaCall(easeOut, (((((now as unknown as number) - (at as unknown as number))) as unknown as number) / (0.42 as unknown as number))));
					return undefined;
				}
				let _: unknown;
				let __2: unknown;
				let rot: unknown;
				[_, __2, rot] = luaCall(line, x1, y1, x2, y2, 10, 1) as LuaTuple<[unknown, unknown, unknown]>;
				luaSetIndex(children, concat("glow", key), luaCall(h, "frame", { Size: colon(tick).map(function(now?: unknown): unknown | undefined {
					return (luaCall(line, x1, y1, x2, y2, 10, luaCall(drawn, now)));
					return undefined;
				}), Position: colon(tick).map(function(now?: unknown): unknown | undefined {
					let _: unknown;
					let pos: unknown;
					[_, pos] = luaCall(line, x1, y1, x2, y2, 10, luaCall(drawn, now)) as LuaTuple<[unknown, unknown]>;
					return pos;
					return undefined;
				}), Rotation: rot, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "ember"), BackgroundTransparency: 0.78, BorderSizePixel: 0, ZIndex: 603 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
				luaSetIndex(children, concat("core", key), luaCall(h, "frame", { Size: colon(tick).map(function(now?: unknown): unknown | undefined {
					return (luaCall(line, x1, y1, x2, y2, 3, luaCall(drawn, now)));
					return undefined;
				}), Position: colon(tick).map(function(now?: unknown): unknown | undefined {
					let _: unknown;
					let pos: unknown;
					[_, pos] = luaCall(line, x1, y1, x2, y2, 3, luaCall(drawn, now)) as LuaTuple<[unknown, unknown]>;
					return pos;
					return undefined;
				}), Rotation: rot, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "white"), BorderSizePixel: 0, ZIndex: 604 }, luaCall(h, "uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)([new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Palette, "mango")), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, WHITE_HOT), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, luaProp(Palette, "mango"))]), Offset: colon(tick).map(function(now?: unknown): unknown | undefined {
					return new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((luaCall(luaProp(math, "sin"), ((((now as unknown as number) * (1.3 as unknown as number)) as unknown as number) + (luaProp(e, "a") as unknown as number))) as unknown as number) * (0.4 as unknown as number)), 0);
					return undefined;
				}) })));
				if ((!luaProp(props, "reduced"))) {
					let phase: unknown = (((((((luaProp(e, "a") as unknown as number) * (0.37 as unknown as number)) as unknown as number) + (((luaProp(e, "b") as unknown as number) * (0.21 as unknown as number)) as unknown as number))) as unknown as number) % (1 as unknown as number));
					luaSetIndex(children, concat("beat", key), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 5, 5), Position: colon(tick).map(function(now?: unknown): unknown | undefined {
						let p: unknown = (((((((now as unknown as number) * (0.55 as unknown as number)) as unknown as number) + (phase as unknown as number))) as unknown as number) % (1 as unknown as number));
						return luaCall(luaProp(UDim2, "fromScale"), ((x1 as unknown as number) + ((((((x2 as unknown as number) - (x1 as unknown as number))) as unknown as number) * (p as unknown as number)) as unknown as number)), ((y1 as unknown as number) + ((((((y2 as unknown as number) - (y1 as unknown as number))) as unknown as number) * (p as unknown as number)) as unknown as number)));
						return undefined;
					}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: WHITE_HOT, BackgroundTransparency: colon(tick).map(function(now?: unknown): unknown | undefined {
						return (((luaCall(drawn, now) as unknown as number) < (1 as unknown as number)) ? 1 : 0.1);
						return undefined;
					}), BorderSizePixel: 0, ZIndex: 605 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
				}
			} else {
				let size: unknown;
				let pos: unknown;
				let rot: unknown;
				[size, pos, rot] = luaCall(line, x1, y1, x2, y2, (open ? ((picked ? 3 : 2)) : 1), 1) as LuaTuple<[unknown, unknown, unknown]>;
				luaSetIndex(children, concat("line", luaProp(e, "key")), luaCall(h, "frame", { Size: size, Position: pos, Rotation: rot, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: (picked ? WHITE_HOT : (open ? luaProp(Palette, "mango") : luaProp(Palette, "lineSoft"))), BackgroundTransparency: (picked ? 0 : (open ? colon(tick).map(function(now?: unknown): unknown | undefined {
					return ((0.35 as unknown as number) + ((((((luaCall(luaProp(math, "sin"), ((((((now as unknown as number) * (3 as unknown as number)) as unknown as number) + (luaProp(e, "a") as unknown as number)) as unknown as number) + (luaProp(e, "b") as unknown as number))) as unknown as number) + (1 as unknown as number))) as unknown as number) * (0.2 as unknown as number)) as unknown as number));
					return undefined;
				}) : 0.55)), BorderSizePixel: 0, ZIndex: 603 }));
				if (open) {
					let hitSize: unknown;
					let hitPos: unknown;
					[hitSize, hitPos] = luaCall(line, x1, y1, x2, y2, 22, 0.7) as LuaTuple<[unknown, unknown]>;
					luaSetIndex(children, concat("hit", luaProp(e, "key")), luaCall(h, "textbutton", { Size: hitSize, Position: hitPos, Rotation: rot, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, Text: "", AutoButtonColor: false, ZIndex: 606, Event: { Activated: function(): unknown | undefined {
						luaCall(luaProp(props, "onLink"), luaProp(e, "key"));
						return undefined;
					} } }));
				}
			}
		}
		// facets: a lit mark in the middle of every closed triangle
		for (const [index, t] of pairs((luaProp(DomainLattice, "TRIANGLES")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (luaIndex(facetSet, index)) {
				const _init6 = 0;
				const _init7 = 0;
				let cx: unknown = _init6;
				let cy: unknown = _init7;
				for (const [_, corner] of pairs((t) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					let x: unknown;
					let y: unknown;
					[x, y] = luaCall(spot, corner) as LuaTuple<[unknown, unknown]>;
					cx = ((cx as unknown as number) + (((x as unknown as number) / (3 as unknown as number)) as unknown as number));
					cy = ((cy as unknown as number) + (((y as unknown as number) / (3 as unknown as number)) as unknown as number));
				}
				luaSetIndex(children, concat("facet", index), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 16, 16), Position: luaCall(luaProp(UDim2, "fromScale"), cx, cy), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 605 }, luaCall(h, "uiscale", { Scale: colon(tick).map(function(now?: unknown): unknown | undefined {
					let at: unknown = luaIndex(luaProp(props, "facetAt"), index);
					let pop: unknown = ((at === undefined) ? 0 : ((1 as unknown as number) - (luaCall(easeOut, (((((now as unknown as number) - (at as unknown as number))) as unknown as number) / (0.4 as unknown as number))) as unknown as number)));
					return ((((1 as unknown as number) + (((pop as unknown as number) * (1.6 as unknown as number)) as unknown as number)) as unknown as number) + (((luaCall(luaProp(math, "sin"), ((((now as unknown as number) * (2 as unknown as number)) as unknown as number) + (index as unknown as number))) as unknown as number) * (0.08 as unknown as number)) as unknown as number));
					return undefined;
				}) }), luaCall(h, Icon, { kind: "StarGrid.6", color: luaProp(Palette, "mango"), accent: WHITE_HOT, size: 16, spin: false })));
			}
		}
		// the anchors: a cut stone, filled as its links are etched, with a pip for every link it can take
		for (const [_, anchor] of pairs((luaProp(DomainLattice, "ANCHORS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let index: unknown = luaProp(anchor, "index");
			let x: unknown;
			let y: unknown;
			[x, y] = luaCall(spot, index) as LuaTuple<[unknown, unknown]>;
			let color: unknown = (luaIndex(KIND_COLOR, luaProp(anchor, "kind")) || luaProp(Palette, "mango"));
			let d: unknown = (luaIndex(degree, index) || 0);
			let maxD: unknown = luaCall(luaProp(DomainLattice, "maxDegree"), index);
			let fill: unknown = ((d as unknown as number) / (luaCall(luaProp(math, "max"), 1, maxD) as unknown as number));
			let isHearth: unknown = (index === luaProp(DomainLattice, "HEARTH"));
			let stone: unknown = (isHearth ? 34 : 24);
			let picked: unknown = (((selected !== undefined) && (luaProp(selected, "kind") === "anchor")) && (luaProp(selected, "id") === index));
			let pips: unknown = {};
			{
				const _forStart_1 = (1 as unknown as number);
				const _forEnd_1 = (maxD as unknown as number);
				const _forStep_1 = (1 as unknown as number);
				for (let pip = _forStart_1; _forStep_1 >= 0 ? pip <= _forEnd_1 : pip >= _forEnd_1; pip += _forStep_1) {
					let a: unknown = luaCall(luaProp(math, "rad"), ((-90 as unknown as number) + ((((((((pip as unknown as number) - (1 as unknown as number))) as unknown as number) * (360 as unknown as number)) as unknown as number) / (maxD as unknown as number)) as unknown as number)));
					let r: unknown = (isHearth ? 0.5 : 0.42);
					luaSetIndex(pips, concat("p", pip), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 4, 4), Position: luaCall(luaProp(UDim2, "fromScale"), ((0.5 as unknown as number) + (((luaCall(luaProp(math, "cos"), a) as unknown as number) * (r as unknown as number)) as unknown as number)), ((0.5 as unknown as number) + (((luaCall(luaProp(math, "sin"), a) as unknown as number) * (r as unknown as number)) as unknown as number))), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: (((pip as unknown as number) <= (d as unknown as number)) ? color : luaProp(Palette, "lineSoft")), BackgroundTransparency: (((pip as unknown as number) <= (d as unknown as number)) ? 0 : 0.4), BorderSizePixel: 0, ZIndex: 608 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
				}
			}
			luaSetIndex(children, concat("anchor", index), luaCall(h, "textbutton", { ref: function(instance?: unknown): unknown | undefined {
				luaSetIndex(luaProp(props, "anchorRefs"), index, instance);
				return undefined;
			}, Size: luaCall(luaProp(UDim2, "fromOffset"), (isHearth ? 64 : 50), (isHearth ? 64 : 50)), Position: luaCall(luaProp(UDim2, "fromScale"), x, y), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, Text: "", AutoButtonColor: false, ZIndex: 607, Event: { Activated: function(): unknown | undefined {
				luaCall(luaProp(props, "onAnchor"), index);
				return undefined;
			} } }, luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), ((stone as unknown as number) + (6 as unknown as number)), ((stone as unknown as number) + (6 as unknown as number))), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaCall(darken, color, ((0.7 as unknown as number) - (((fill as unknown as number) * (0.35 as unknown as number)) as unknown as number))), BorderSizePixel: 0, ZIndex: 608 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), luaCall(h, "uistroke", { Color: ((picked || ((fill as unknown as number) >= (1 as unknown as number))) ? WHITE_HOT : color), Thickness: (picked ? 2.5 : 1.5), Transparency: ((((d as unknown as number) > (0 as unknown as number)) || isHearth) ? 0 : 0.45) }), luaCall(h, Icon, { kind: (luaIndex(KIND_ICON, luaProp(anchor, "kind")) || "Domain.6"), color: ((((d as unknown as number) > (0 as unknown as number)) || isHearth) ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), accent: color, size: ((stone as unknown as number) - (4 as unknown as number)), spin: false, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5) })), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, ZIndex: 608 }, pips), (picked && luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1.05, 1.05), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), Rotation: colon(tick).map(function(now?: unknown): unknown | undefined {
				return (((((now as unknown as number) * (40 as unknown as number))) as unknown as number) % (360 as unknown as number));
				return undefined;
			}), BackgroundTransparency: 1, ZIndex: 607 }, luaCall(h, "uistroke", { Color: WHITE_HOT, Thickness: 1, Transparency: 0.35 }))), luaCall(h, "textlabel", { Size: luaCall(luaProp(UDim2, "fromOffset"), 110, 14), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 1, (isHearth ? 0 : -2)), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0), BackgroundTransparency: 1, Text: luaProp(anchor, "name"), TextSize: (isHearth ? 13 : 11), FontFace: luaCall(luaProp(Font, "fromEnum"), (isHearth ? luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold") : luaProp(luaProp(Enum, "Font"), "BuilderSansBold"))), TextColor3: ((((d as unknown as number) > (0 as unknown as number)) || isHearth) ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), ZIndex: 609 })));
		}
		return luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 602 }, luaCall(h, "uiaspectratioconstraint", { AspectRatio: 1 }), children);
		return undefined;
	}
	function Row(props?: unknown): unknown | undefined {
		return luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaProp(props, "height") || 22)), LayoutOrder: luaProp(props, "order"), BackgroundTransparency: 1, ZIndex: 632 }, luaCall(h, "textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -110, 1, 0), BackgroundTransparency: 1, Text: luaProp(props, "label"), TextSize: (luaProp(props, "size") || 13), TextWrapped: true, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), TextColor3: (luaProp(props, "labelColor") || luaProp(Palette, "creamSoft")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), TextTransparency: (luaProp(props, "fade") || 0), ZIndex: 633 }), ((luaProp(props, "value") !== undefined) && luaCall(h, "textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 110, 1, 0), Position: luaCall(luaProp(UDim2, "fromScale"), 1, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0), BackgroundTransparency: 1, Text: luaProp(props, "value"), TextSize: (luaProp(props, "size") || 13), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextColor3: (luaProp(props, "valueColor") || luaProp(Palette, "cream")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), TextTransparency: (luaProp(props, "fade") || 0), ZIndex: 633 })));
		return undefined;
	}
	function Heading(props?: unknown): unknown | undefined {
		return luaCall(h, "textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16), LayoutOrder: luaProp(props, "order"), BackgroundTransparency: 1, Text: luaProp(props, "text"), TextSize: 11, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextColor3: (luaProp(props, "color") || luaProp(Palette, "mango")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), ZIndex: 633 });
		return undefined;
	}
	function DomainChamber(props?: unknown): unknown | undefined {
		let domain: unknown = (luaProp(props, "domain") || {});
		let mode: unknown = luaProp(props, "mode");
		let rank: unknown = luaCall(luaProp(math, "max"), 0, luaCall(luaProp(math, "floor"), luaCall(asNumber, luaProp(domain, "Rank"))));
		if ((((rank as unknown as number) < (1 as unknown as number)) && (mode === "lattice"))) {
			mode = "confirm";
		}
		let viewport: unknown = luaCall(useViewport);
		let stacked: unknown = (((luaProp(viewport, "width") as unknown as number) < (760 as unknown as number)) || ((luaProp(viewport, "width") as unknown as number) < (luaProp(viewport, "height") as unknown as number)));
		let reduced: unknown = (luaProp(props, "reducedMotion") === true);
		let tick: unknown;
		let setTick: unknown;
		[tick, setTick] = reactLoose.useBinding(luaCall(luaProp(os, "clock"))) as LuaTuple<[unknown, unknown]>;
		let flare: unknown;
		let setFlare: unknown;
		[flare, setFlare] = reactLoose.useBinding(0) as LuaTuple<[unknown, unknown]>;
		let hold: unknown;
		let setHold: unknown;
		[hold, setHold] = reactLoose.useBinding(0) as LuaTuple<[unknown, unknown]>;
		let selected: unknown;
		let setSelected: unknown;
		[selected, setSelected] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let override: unknown;
		let setOverride: unknown;
		[override, setOverride] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let note: unknown;
		let setNote: unknown;
		[note, setNote] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let etchedAt: unknown = reactLoose.useRef({});
		let facetAt: unknown = reactLoose.useRef({});
		let anchorRefs: unknown = reactLoose.useRef({});
		let resultAt: unknown = reactLoose.useRef(0);
		let holding: unknown = reactLoose.useRef(undefined);
		let fired: unknown = reactLoose.useRef(false);
		let requesting: unknown = reactLoose.useRef(false);
		reactLoose.useEffect(function(): unknown | undefined {
			luaCall(setOverride, undefined);
			return undefined;
		}, [luaProp(domain, "Links"), luaProp(domain, "SkillPoints")]);
		let links: unknown = (override ? luaProp(override, "links") : (((luaTypeIs(luaProp(domain, "Links"), "table")) ? luaProp(domain, "Links") : {})));
		let points: unknown = (override ? luaProp(override, "points") : luaCall(luaProp(math, "floor"), luaCall(asNumber, luaProp(domain, "SkillPoints"))));
		let etched: unknown = luaCall(luaProp(DomainLattice, "count"), links);
		let nextCost: unknown = luaCall(luaProp(DomainLattice, "linkCost"), etched);
		let canClear: unknown = ((((rank as unknown as number) >= (1 as unknown as number)) && ((etched as unknown as number) > (0 as unknown as number))) && ((luaCall(asNumber, luaProp(domain, "LatticeClearedAtRank")) as unknown as number) < (rank as unknown as number)));
		reactLoose.useEffect(function(): unknown | undefined {
			if ((mode === "result")) {
				luaSet(resultAt, "current", luaCall(luaProp(os, "clock")));
				colon(Audio).play("domainImpact");
			} else if ((mode === "confirm")) {
				colon(Audio).play("open");
			}
			luaSet(fired, "current", false);
			luaSet(holding, "current", undefined);
			luaCall(setHold, 0);
			return undefined;
		}, [mode]);
		// one clock drives everything on screen, plus the hold and the result's flare
		reactLoose.useEffect(function(): unknown | undefined {
			let connection: unknown = colon(luaProp(RunService, "RenderStepped")).Connect(function(): unknown | undefined {
				let now: unknown = luaCall(luaProp(os, "clock"));
				luaCall(setTick, now);
				if ((mode === "result")) {
					luaCall(setFlare, luaCall(luaProp(math, "clamp"), (((((now as unknown as number) - (luaProp(resultAt, "current") as unknown as number))) as unknown as number) / (1.1 as unknown as number)), 0, 1));
				} else {
					luaCall(setFlare, 0);
				}
				let startedAt: unknown = luaProp(holding, "current");
				if (((startedAt !== undefined) && (!luaProp(fired, "current")))) {
					let p: unknown = luaCall(luaProp(math, "clamp"), (((((now as unknown as number) - (startedAt as unknown as number))) as unknown as number) / (HOLD_SECONDS as unknown as number)), 0, 1);
					luaCall(setHold, p);
					if (((p as unknown as number) >= (1 as unknown as number))) {
						luaSet(fired, "current", true);
						luaSet(holding, "current", undefined);
						colon(Audio).play("domainCrack");
						luaCall(luaProp(props, "onConfirm"));
					}
				} else if (((startedAt === undefined) && (!luaProp(fired, "current")))) {
					luaCall(setHold, 0);
				}
				return undefined;
			});
			return function(): unknown | undefined {
				colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, [mode, luaProp(props, "onConfirm")]);
		// a controller lands on the chamber's own buttons whenever the mode changes
		let actionsRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(): unknown | undefined {
			luaCall(luaProp(GamepadNavigationService, "BeginOverlayFocus"));
			return function(): unknown | undefined {
				luaCall(luaProp(GamepadNavigationService, "EndOverlayFocus"));
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!luaProp(UserInputService, "GamepadEnabled"))) {
				return undefined;
			}
			let job: unknown = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
				let host: unknown = luaProp(actionsRef, "current");
				if (((host !== undefined) && (luaProp(host, "Parent") !== undefined))) {
					luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				}
				return undefined;
			});
			return function(): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, [mode]);
		// Escape backs out: the rite returns to the lattice, the lattice closes
		reactLoose.useEffect(function(): unknown | undefined {
			let connection: unknown = colon(luaProp(UserInputService, "InputBegan")).Connect(function(input?: unknown): unknown | undefined {
				if (((luaProp(input, "KeyCode") !== luaProp(luaProp(Enum, "KeyCode"), "Escape")) && (luaProp(input, "KeyCode") !== luaProp(luaProp(Enum, "KeyCode"), "ButtonB")))) {
					return;
				}
				if (((mode === "confirm") && ((rank as unknown as number) >= (1 as unknown as number)))) {
					luaCall(luaProp(props, "onMode"), "lattice");
				} else if ((mode !== "result")) {
					luaCall(luaProp(props, "onClose"));
				}
				return undefined;
			});
			return function(): unknown | undefined {
				colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, [mode, rank]);
		function burstAt(index?: unknown, color?: unknown, scale?: unknown): unknown | undefined {
			if (reduced) {
				return;
			}
			let instance: unknown = luaIndex(luaProp(anchorRefs, "current"), index);
			if (((instance !== undefined) && (luaProp(instance, "Parent") !== undefined))) {
				luaCall(pcall, function(): unknown | undefined {
					luaCall(luaProp(mod("JuiceFx"), "burst"), ((luaProp(instance, "AbsolutePosition") as unknown as number) + (((luaProp(instance, "AbsoluteSize") as unknown as number) / (2 as unknown as number)) as unknown as number)), color, scale);
					return undefined;
				});
			}
			return undefined;
		}
		function etch(key?: unknown): unknown | undefined {
			if (luaProp(requesting, "current")) {
				return;
			}
			let a: unknown;
			let b: unknown;
			[a, b] = luaCall(splitKey, key) as LuaTuple<[unknown, unknown]>;
			let ok: unknown;
			let reason: unknown;
			[ok, reason] = luaCall(luaProp(DomainLattice, "canEtch"), links, a, b, points) as LuaTuple<[unknown, unknown]>;
			if ((!ok)) {
				luaCall(setNote, reason);
				colon(Audio).play("locked");
				return;
			}
			luaSet(requesting, "current", true);
			let before: unknown = luaCall(luaProp(DomainLattice, "facets"), links);
			luaCall(luaProp(props, "dispatch"), "DomainLattice", { Op: "Etch", A: a, B: b }, function(response?: unknown): unknown | undefined {
				luaSet(requesting, "current", false);
				if (((!luaProp(response, "ok")) || (!luaTypeIs(luaProp(response, "Links"), "table")))) {
					luaCall(setNote, (luaProp(response, "message") || "That link didn't take."));
					colon(Audio).play("locked");
					return;
				}
				let now: unknown = luaCall(luaProp(os, "clock"));
				luaSetIndex(luaProp(etchedAt, "current"), key, now);
				let was: unknown = {};
				for (const [_, index] of pairs((before) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					luaSetIndex(was, index, true);
				}
				for (const [_, index] of pairs((luaCall(luaProp(DomainLattice, "facets"), luaProp(response, "Links"))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if ((!luaIndex(was, index))) {
						luaSetIndex(luaProp(facetAt, "current"), index, ((now as unknown as number) + (0.3 as unknown as number)));
					}
				}
				luaCall(setOverride, { links: luaProp(response, "Links"), points: luaCall(luaProp(math, "floor"), luaCall(asNumber, luaProp(response, "SkillPoints"))) });
				luaCall(setNote, undefined);
				luaCall(setSelected, { kind: "anchor", id: b });
				colon(Audio).play((luaProp(response, "ClosedFacet") ? "domainImpact" : "domainBind"));
				luaCall(luaProp(task, "delay"), 0.36, function(): unknown | undefined {
					luaCall(burstAt, b, luaCall(colorOf, b), (luaProp(response, "ClosedFacet") ? 1.2 : 0.8));
					return undefined;
				});
				return undefined;
			});
			return undefined;
		}
		function clear(): unknown | undefined {
			if ((luaProp(requesting, "current") || (!canClear))) {
				return;
			}
			luaSet(requesting, "current", true);
			luaCall(luaProp(props, "dispatch"), "DomainLattice", { Op: "Clear" }, function(response?: unknown): unknown | undefined {
				luaSet(requesting, "current", false);
				if ((luaProp(response, "ok") && (luaTypeIs(luaProp(response, "Links"), "table")))) {
					luaSet(etchedAt, "current", {});
					luaSet(facetAt, "current", {});
					luaCall(setOverride, { links: luaProp(response, "Links"), points: luaCall(luaProp(math, "floor"), luaCall(asNumber, luaProp(response, "SkillPoints"))) });
					luaCall(setSelected, undefined);
					colon(Audio).play("domainReward");
				} else {
					luaCall(setNote, (luaProp(response, "message") || "Couldn't clear the lattice."));
				}
				return undefined;
			});
			return undefined;
		}
		let onLink: unknown = function(key?: unknown): unknown | undefined {
			if ((((selected !== undefined) && (luaProp(selected, "kind") === "link")) && (luaProp(selected, "id") === key))) {
				luaCall(etch, key);
			} else {
				colon(Audio).play("tick");
				luaCall(setNote, undefined);
				luaCall(setSelected, { kind: "link", id: key });
			}
			return undefined;
		};
		let onAnchor: unknown = function(index?: unknown): unknown | undefined {
			colon(Audio).play("tick");
			luaCall(setNote, undefined);
			luaCall(setSelected, { kind: "anchor", id: index });
			return undefined;
		};
		// the side panel
		let rows: unknown = {};
		let order: unknown = 0;
		function add(element?: unknown): unknown | undefined {
			order = ((order as unknown as number) + (1 as unknown as number));
			luaSetIndex(rows, concat("r", order), element);
			return order;
			return undefined;
		}
		function heading(text?: unknown, color?: unknown): unknown | undefined {
			luaCall(add, luaCall(h, Heading, { text: text, color: color, order: ((order as unknown as number) + (1 as unknown as number)) }));
			return undefined;
		}
		function row(label?: unknown, value?: unknown, extra?: unknown): unknown | undefined {
			let r: unknown = (extra || {});
			const _set8 = label;
			const _set9 = value;
			const _set10 = ((order as unknown as number) + (1 as unknown as number));
			luaSet(r, "label", _set8);
			luaSet(r, "value", _set9);
			luaSet(r, "order", _set10);
			luaCall(add, luaCall(h, Row, r));
			return undefined;
		}
		function gap(px?: unknown): unknown | undefined {
			luaCall(add, luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, px), BackgroundTransparency: 1, LayoutOrder: ((order as unknown as number) + (1 as unknown as number)) }));
			return undefined;
		}
		let panelTitle: unknown;
		let panelNumber: unknown;
		let actions: unknown = {};
		if ((mode === "lattice")) {
			const _set11 = "DOMAIN";
			const _set12 = luaCall(tostring, rank);
			panelTitle = _set11;
			panelNumber = _set12;
			luaCall(row, "Production from your domain", `x${luaCall(luaProp(string, "format"), "%.2f", luaCall(asNumber, luaProp(domain, "ProductionMultiplier")))}`, { valueColor: luaProp(Palette, "mango") });
			luaCall(row, "Domain points", luaCall(tostring, points), { valueColor: (((points as unknown as number) > (0 as unknown as number)) ? luaProp(Palette, "mango") : luaProp(Palette, "cream")) });
			luaCall(row, "Next link costs", ((nextCost === 1) ? "1 point" : `${nextCost} points`));
			luaCall(gap, 6);
			if ((((selected !== undefined) && (luaProp(selected, "kind") === "link")) && (luaIndex(links, luaProp(selected, "id")) !== true))) {
				let a: unknown;
				let b: unknown;
				[a, b] = luaCall(splitKey, luaProp(selected, "id")) as LuaTuple<[unknown, unknown]>;
				luaCall(heading, `ETCH ${luaCall(luaProp(string, "upper"), luaProp(luaIndex(luaProp(DomainLattice, "ANCHORS"), a), "name"))} TO ${luaCall(luaProp(string, "upper"), luaProp(luaIndex(luaProp(DomainLattice, "ANCHORS"), b), "name"))}`);
				for (const [_, preview] of pairs((luaCall(etchPreview, links, luaProp(selected, "id"))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					luaCall(row, luaProp(preview, "text"), undefined, { labelColor: luaProp(preview, "color") });
				}
				let ok: unknown;
				let reason: unknown;
				[ok, reason] = luaCall(luaProp(DomainLattice, "canEtch"), links, a, b, points) as LuaTuple<[unknown, unknown]>;
				luaTable.insert(actions, { text: (ok ? (((nextCost === 1) ? "Etch for 1 point" : `Etch for ${nextCost} points`)) : ((reason || "Can't etch"))), primary: true, disabled: (!ok), onClick: function(): unknown | undefined {
					luaCall(etch, luaProp(selected, "id"));
					return undefined;
				} });
			} else if (((selected !== undefined) && (luaProp(selected, "kind") === "anchor"))) {
				let anchor: unknown = luaIndex(luaProp(DomainLattice, "ANCHORS"), luaProp(selected, "id"));
				let d: unknown = (luaIndex(luaCall(luaProp(DomainLattice, "degrees"), links), luaProp(anchor, "index")) || 0);
				let maxD: unknown = luaCall(luaProp(DomainLattice, "maxDegree"), luaProp(anchor, "index"));
				luaCall(heading, luaCall(luaProp(string, "upper"), luaProp(anchor, "name")), luaIndex(KIND_COLOR, luaProp(anchor, "kind")));
				luaCall(row, "Gives now", luaCall(luaProp(DomainLattice, "describe"), luaProp(anchor, "kind"), luaCall(luaProp(DomainLattice, "anchorBonus"), luaProp(anchor, "index"), d)), { valueColor: luaIndex(KIND_COLOR, luaProp(anchor, "kind")) });
				luaCall(row, "Links", `${d} of ${maxD}`);
				luaCall(row, "With every link etched", luaCall(luaProp(DomainLattice, "describe"), luaProp(anchor, "kind"), luaProp(anchor, "full")));
				if ((luaProp(anchor, "index") === luaProp(DomainLattice, "HEARTH"))) {
					luaCall(gap, 4);
					luaCall(row, concat("Every closed triangle in the lattice adds ", concat(luaCall(luaProp(DomainLattice, "describe"), "Production", luaProp(DomainLattice, "FACET_PRODUCTION")), ".")), undefined, { height: 36, size: 12, labelColor: luaProp(Palette, "muted") });
				}
			} else {
				luaCall(heading, "WHAT YOUR LATTICE GIVES");
				let any_: unknown = false;
				for (const [_, anchor] of pairs((luaProp(DomainLattice, "ANCHORS")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					let total: unknown = luaCall(luaProp(DomainLattice, "bonus"), links, luaProp(anchor, "kind"));
					if ((((total as unknown as number) > (0 as unknown as number)) && (((luaProp(anchor, "kind") !== "Production") || (luaProp(anchor, "index") === luaProp(DomainLattice, "HEARTH")))))) {
						any_ = true;
						luaCall(row, luaCall(luaProp(DomainLattice, "describe"), luaProp(anchor, "kind"), total), undefined, { labelColor: luaIndex(KIND_COLOR, luaProp(anchor, "kind")) });
					}
				}
				let facets: unknown = len(luaCall(luaProp(DomainLattice, "facets"), links));
				if (((facets as unknown as number) > (0 as unknown as number))) {
					luaCall(row, `${facets} closed ${((facets === 1) ? "facet" : "facets")}`, undefined, { labelColor: luaProp(Palette, "muted"), size: 12 });
				}
				if ((!any_)) {
					luaCall(row, "Tap a glowing line next to the Hearth to start. Links grow outward from it.", undefined, { height: 40, labelColor: luaProp(Palette, "muted") });
				}
			}
			if ((note !== undefined)) {
				luaCall(gap, 4);
				luaCall(row, note, undefined, { labelColor: luaProp(Palette, "coral"), height: 30, size: 12 });
			}
			if ((luaProp(domain, "CanExpand") === true)) {
				luaTable.insert(actions, { text: `Expand to Domain ${((rank as unknown as number) + (1 as unknown as number))}`, primary: (len(actions) === 0), onClick: function(): unknown | undefined {
					luaCall(luaProp(props, "onMode"), "confirm");
					return undefined;
				} });
			}
			luaTable.insert(actions, { text: (canClear ? `Clear lattice (refunds ${luaCall(luaProp(DomainLattice, "spent"), etched)})` : (((etched as unknown as number) > (0 as unknown as number)) ? "Cleared this rank" : "Clear lattice")), quiet: true, disabled: (!canClear), onClick: clear });
		} else if ((mode === "confirm")) {
			const _set13 = "EXPAND TO DOMAIN";
			const _set14 = luaCall(tostring, ((rank as unknown as number) + (1 as unknown as number)));
			panelTitle = _set13;
			panelNumber = _set14;
			const _init15 = luaCall(asNumber, luaProp(domain, "RequiredRebirths"));
			const _init16 = luaCall(asNumber, luaProp(domain, "RequiredCores"));
			let needR: unknown = _init15;
			let needC: unknown = _init16;
			const _init17 = luaCall(asNumber, luaProp(props, "rebirths"));
			const _init18 = luaCall(asNumber, luaProp(props, "cores"));
			let haveR: unknown = _init17;
			let haveC: unknown = _init18;
			luaCall(heading, "IT TAKES");
			luaCall(row, "Rebirths", `${luaCall(compactNumber, haveR)} / ${luaCall(compactNumber, needR)}`, { valueColor: (((haveR as unknown as number) >= (needR as unknown as number)) ? luaProp(Palette, "mint") : luaProp(Palette, "coral")) });
			luaCall(row, "Cores", `${luaCall(compactNumber, haveC)} / ${luaCall(compactNumber, needC)}`, { valueColor: (((haveC as unknown as number) >= (needC as unknown as number)) ? luaProp(Palette, "mint") : luaProp(Palette, "coral")) });
			luaCall(gap, 6);
			luaCall(heading, "YOU GET");
			luaCall(row, "Domain essence", `+${luaCall(compactNumber, luaCall(asNumber, luaProp(domain, "EssenceReward")))}`, { valueColor: luaProp(Palette, "pink") });
			luaCall(row, "Stardust (more for every extra rebirth)", `+${luaCall(compactNumber, luaCall(asNumber, luaProp(domain, "StardustReward")))}`, { valueColor: luaProp(Palette, "cyan"), size: 12 });
			luaCall(row, "Domain points", `+${(luaProp(luaProp(GameConfig, "Domain"), "SkillPointPerRank") || 2)}`, { valueColor: luaProp(Palette, "mango") });
			luaCall(row, "Wheel spins", `+${(((luaProp(luaProp(GameConfig, "Domain"), "Expansion") && luaProp(luaProp(luaProp(GameConfig, "Domain"), "Expansion"), "FreeSpins"))) || 3)}`);
			luaCall(row, luaCall(surgeLabel), undefined, { labelColor: luaProp(Palette, "mango") });
			luaCall(gap, 6);
			luaCall(row, concat("Keeps: ", concat(KEEPS, ".")), undefined, { height: 34, size: 12, labelColor: luaProp(Palette, "mint") });
			luaCall(row, concat("Resets: ", concat(RESETS, ".")), undefined, { height: 34, size: 12, labelColor: luaProp(Palette, "coral") });
			luaTable.insert(actions, { text: ((luaProp(domain, "CanExpand") === true) ? ((luaProp(props, "busy") ? "Expanding…" : "Hold to expand")) : "Not ready yet"), primary: true, hold: ((luaProp(domain, "CanExpand") === true) && (!luaProp(props, "busy"))), disabled: ((luaProp(domain, "CanExpand") !== true) || luaProp(props, "busy")) });
			if (((rank as unknown as number) >= (1 as unknown as number))) {
				luaTable.insert(actions, { text: "Back to the lattice", quiet: true, onClick: function(): unknown | undefined {
					luaCall(luaProp(props, "onMode"), "lattice");
					return undefined;
				} });
			}
		} else {
			let result: unknown = (luaProp(props, "result") || {});
			const _set19 = "DOMAIN";
			const _set20 = luaCall(tostring, (luaProp(result, "rank") || rank));
			panelTitle = _set19;
			panelNumber = _set20;
			luaCall(heading, "THE EXPANSION PAID");
			let lines: unknown = [["Domain essence", `+${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "essence")))}`, luaProp(Palette, "pink")], ["Stardust", `+${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "stardust")))}`, luaProp(Palette, "cyan")], ["Domain points", `+${(luaProp(luaProp(GameConfig, "Domain"), "SkillPointPerRank") || 2)}`, luaProp(Palette, "mango")], ["Wheel spins", `+${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "freeSpins")))}`, luaProp(Palette, "cream")]];
			for (const [index, item] of pairs((lines) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let delay: unknown = ((0.7 as unknown as number) + (((index as unknown as number) * (0.18 as unknown as number)) as unknown as number));
				luaCall(row, luaIndex(item, 1), luaIndex(item, 2), { valueColor: luaIndex(item, 3), fade: colon(tick).map(function(now?: unknown): unknown | undefined {
					return ((1 as unknown as number) - (luaCall(easeOut, (((((((now as unknown as number) - (luaProp(resultAt, "current") as unknown as number)) as unknown as number) - (delay as unknown as number))) as unknown as number) / (0.3 as unknown as number))) as unknown as number));
					return undefined;
				}) });
			}
			if (((luaCall(asNumber, luaProp(result, "overflow")) as unknown as number) > (0 as unknown as number))) {
				luaCall(row, `${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "overflow")))} of that Stardust came from rebirths past the requirement.`, undefined, { height: 34, size: 12, labelColor: luaProp(Palette, "muted") });
			}
			luaCall(gap, 6);
			luaCall(row, `Next expansion: ${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "nextRebirths")))} rebirths and ${luaCall(compactNumber, luaCall(asNumber, luaProp(result, "nextCores")))} Cores.`, undefined, { height: 34, size: 12, labelColor: luaProp(Palette, "muted") });
			luaTable.insert(actions, { text: "Etch your new points", primary: true, onClick: function(): unknown | undefined {
				luaCall(luaProp(props, "onMode"), "lattice");
				return undefined;
			} });
		}
		let buttons: unknown = {};
		for (const [index, action] of pairs((actions) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let height: unknown = (luaProp(action, "quiet") ? 30 : TapTarget);
			if (luaProp(action, "hold")) {
				luaSetIndex(buttons, concat("a", index), luaCall(h, "textbutton", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), LayoutOrder: index, BackgroundColor3: luaCall(darken, luaProp(Palette, "mango"), 0.55), AutoButtonColor: false, Text: "", ZIndex: 634, Event: { InputBegan: function(_?: unknown, input?: unknown): unknown | undefined {
					if (((luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")) || (luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch")))) {
						luaSet(holding, "current", luaCall(luaProp(os, "clock")));
						colon(Audio).play("domainCharge");
					}
					return undefined;
				}, InputEnded: function(_?: unknown, input?: unknown): unknown | undefined {
					if (((luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")) || (luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch")))) {
						luaSet(holding, "current", undefined);
					}
					return undefined;
				}, Activated: function(_?: unknown, input?: unknown): unknown | undefined {
					// a controller press can't be held, so it confirms straight away
					if (((((input !== undefined) && (luaProp(input, "UserInputType") !== undefined)) && luaCall(luaProp(string, "find"), luaProp(luaProp(input, "UserInputType"), "Name"), "Gamepad", 1, true)) && (!luaProp(fired, "current")))) {
						luaSet(fired, "current", true);
						luaCall(luaProp(props, "onConfirm"));
					}
					return undefined;
				} } }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), luaCall(h, "frame", { Size: colon(hold).map(function(p?: unknown): unknown | undefined {
					return luaCall(luaProp(UDim2, "fromScale"), p, 1);
					return undefined;
				}), BackgroundColor3: luaProp(Palette, "white"), BorderSizePixel: 0, ZIndex: 635 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), luaCall(h, "uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaProp(Palette, "mango"), WHITE_HOT) })), luaCall(h, "textlabel", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, Text: luaProp(action, "text"), TextSize: 15, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextColor3: luaProp(Palette, "cream"), ZIndex: 636 })));
			} else if (luaProp(action, "quiet")) {
				luaSetIndex(buttons, concat("a", index), luaCall(h, "textbutton", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), LayoutOrder: index, BackgroundTransparency: 1, Text: luaProp(action, "text"), TextSize: 12, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextColor3: (luaProp(action, "disabled") ? luaProp(Palette, "lineSoft") : luaProp(Palette, "muted")), AutoButtonColor: false, ZIndex: 634, Event: { Activated: function(): unknown | undefined {
					if (((!luaProp(action, "disabled")) && luaProp(action, "onClick"))) {
						luaCall(luaProp(action, "onClick"));
					}
					return undefined;
				} } }));
			} else {
				luaSetIndex(buttons, concat("a", index), luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), LayoutOrder: index, BackgroundTransparency: 1, ZIndex: 634 }, luaCall(h, Button, { text: luaProp(action, "text"), onClick: luaProp(action, "onClick"), color: (luaProp(action, "primary") ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: (luaProp(action, "primary") ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: luaProp(action, "disabled"), reducedMotion: reduced, highlight: luaProp(action, "primary"), zIndex: 35 })));
			}
		}
		let panelW: unknown = (stacked ? ((luaProp(viewport, "width") as unknown as number) - (24 as unknown as number)) : 360);
		let numberSlam: unknown = ((mode === "result") ? colon(tick).map(function(now?: unknown): unknown | undefined {
			let t: unknown = (((((((now as unknown as number) - (luaProp(resultAt, "current") as unknown as number)) as unknown as number) - (0.35 as unknown as number))) as unknown as number) / (0.32 as unknown as number));
			return (((t as unknown as number) < (0 as unknown as number)) ? 0 : ((1 as unknown as number) + ((((((1 as unknown as number) - (luaCall(easeOut, t) as unknown as number))) as unknown as number) * (1.4 as unknown as number)) as unknown as number)));
			return undefined;
		}) : undefined);
		let panel: unknown = luaCall(h, "frame", { Size: (stacked ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0.48, -12) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, panelW, 1, -48)), Position: (stacked ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 12, 0.52, 0) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0, 24)), AnchorPoint: (stacked ? luaProp(Vector2, "zero") : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0)), BackgroundColor3: luaProp(Palette, "panel"), BackgroundTransparency: 0.08, BorderSizePixel: 0, ZIndex: 630 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) }), luaCall(h, "uistroke", { Color: luaProp(Palette, "lineSoft"), Transparency: 0.25 }), luaCall(h, "uipadding", { PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16), PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 18), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 18) }), luaCall(h, "textbutton", { Size: luaCall(luaProp(UDim2, "fromOffset"), 60, 24), Position: luaCall(luaProp(UDim2, "fromScale"), 1, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0), BackgroundTransparency: 1, Text: "Close", TextSize: 12, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextColor3: luaProp(Palette, "muted"), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), Visible: (mode !== "result"), ZIndex: 634, Event: { Activated: function(): unknown | undefined {
			if ((!luaProp(props, "busy"))) {
				luaCall(luaProp(props, "onClose"));
			}
			return undefined;
		} } }), luaCall(h, "textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -60, 0, 14), BackgroundTransparency: 1, Text: panelTitle, TextSize: 11, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextColor3: luaProp(Palette, "mango"), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), ZIndex: 633 }), luaCall(h, "textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 52), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 14), BackgroundTransparency: 1, Text: panelNumber, TextSize: 50, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextColor3: ((mode === "result") ? WHITE_HOT : luaProp(Palette, "cream")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), TextTransparency: (numberSlam ? colon(numberSlam).map(function(s?: unknown): unknown | undefined {
			return (((s as unknown as number) <= (0 as unknown as number)) ? 1 : 0);
			return undefined;
		}) : 0), ZIndex: 633 }, (numberSlam && luaCall(h, "uiscale", { Scale: colon(numberSlam).map(function(s?: unknown): unknown | undefined {
			return luaCall(luaProp(math, "max"), 0.01, s);
			return undefined;
		}) }))), luaCall(h, "scrollingframe", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-((((78 as unknown as number) + (((len(actions) as unknown as number) * ((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number)) as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 74), BackgroundTransparency: 1, BorderSizePixel: 0, CanvasSize: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(), AutomaticCanvasSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), ScrollBarThickness: 3, ScrollBarImageColor3: luaProp(Palette, "muted"), ZIndex: 632 }, luaCall(h, "uipadding", { PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 4) }), rows), luaCall(h, "frame", { ref: actionsRef, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((len(actions) as unknown as number) * ((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromScale"), 0, 1), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 1), BackgroundTransparency: 1, ZIndex: 633 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Bottom"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), buttons));
		let heat: unknown = luaCall(luaProp(React, "joinBindings"), [hold, flare]);
		return luaCall(h, "frame", { Name: "DomainChamber", Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: 0.04, BorderSizePixel: 0, Active: true, ZIndex: 620 }, luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 0.7), Position: luaCall(luaProp(UDim2, "fromScale"), 0, 1), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 1), BackgroundColor3: luaProp(Palette, "ember"), BackgroundTransparency: colon(heat).map(function(v?: unknown): unknown | undefined {
			let landing: unknown = (((luaIndex(v, 2) as unknown as number) > (0 as unknown as number)) ? ((1 as unknown as number) - (luaIndex(v, 2) as unknown as number)) : 0);
			return luaCall(luaProp(math, "clamp"), ((((0.86 as unknown as number) - (((luaIndex(v, 1) as unknown as number) * (0.4 as unknown as number)) as unknown as number)) as unknown as number) - (((landing as unknown as number) * (0.5 as unknown as number)) as unknown as number)), 0, 1);
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 621 }, luaCall(h, "uigradient", { Rotation: -90, Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 0), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, 0.75), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 1)]) })), luaCall(h, "frame", { Size: (stacked ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0.5, -12) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((panelW as unknown as number) + (72 as unknown as number))) as unknown as number)), 1, -48)), Position: luaCall(luaProp(UDim2, "fromOffset"), (stacked ? 12 : 24), (stacked ? 12 : 24)), BackgroundTransparency: 1, ZIndex: 622 }, luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 622 }, luaCall(h, Lattice, { links: links, tick: tick, flare: flare, selected: ((mode === "lattice") ? selected : undefined), etchedAt: luaProp(etchedAt, "current"), facetAt: luaProp(facetAt, "current"), anchorRefs: luaProp(anchorRefs, "current"), reduced: reduced, onLink: ((mode === "lattice") ? onLink : function(): unknown | undefined {

			return undefined;
		}), onAnchor: ((mode === "lattice") ? onAnchor : function(): unknown | undefined {

			return undefined;
		}) }))), panel);
		return undefined;
	}
	return { DomainChamber: DomainChamber };
};

__defs["purchaseOverlay"] = () => {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let _motion: unknown = kit("MotionKit", "motion");
	let easeOutBack: unknown = luaProp(_motion, "easeOutBack");
	let easeOutCubic: unknown = luaProp(_motion, "easeOutCubic");
	let ScaleFromCenter: unknown = luaProp(_motion, "ScaleFromCenter");
	let useBoatTween: unknown = luaProp(_motion, "useBoatTween");
	let useClock: unknown = luaProp(_motion, "useClock");
	let useExitTransition: unknown = luaProp(_motion, "useExitTransition");
	let useFlash: unknown = luaProp(_motion, "useFlash");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let darken: unknown = luaProp(_theme, "darken");
	let Palette: unknown = luaProp(_theme, "Palette");
	let surfaceGradient: unknown = luaProp(_theme, "surfaceGradient");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let OverlayPresence: unknown = luaProp(_ui, "OverlayPresence");
	let Text: unknown = luaProp(_ui, "Text");
	let PURCHASE_RESULT_HOLD: unknown = 2.2;
	let PURCHASE_RESULT_HOLD_REDUCED: unknown = 1.65;
	let PURCHASE_PENDING_FAILSAFE: unknown = 45;
	let DOT_COLORS: unknown = [luaProp(Palette, "mango"), luaProp(Palette, "cyan"), luaProp(Palette, "mint")];
	function ForgeDot(_param?: unknown): unknown | undefined {
		let index: unknown = luaProp(_param, "index");
		let clock: unknown = luaProp(_param, "clock");
		let morph: unknown = luaProp(_param, "morph");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let color: unknown = luaIndex(DOT_COLORS, ((index as unknown as number) + (1 as unknown as number)));
		let x: unknown = (((((index as unknown as number) - (1 as unknown as number))) as unknown as number) * (26 as unknown as number));
		let position: unknown = colon(luaCall(luaProp(React, "joinBindings"), [clock, morph])).map(function(values?: unknown): unknown | undefined {
			let wave: unknown = (reducedMotion ? 0 : luaCall(luaProp(math, "pow"), (((((luaCall(luaProp(math, "sin"), ((((((luaIndex(values, 1) as unknown as number) * (luaProp(math, "pi") as unknown as number)) as unknown as number) * (2 as unknown as number)) as unknown as number) - (((index as unknown as number) * (0.82 as unknown as number)) as unknown as number))) as unknown as number) + (1 as unknown as number))) as unknown as number) * (0.5 as unknown as number)), 1.6));
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, luaCall(luaProp(math, "round"), ((x as unknown as number) * ((((1 as unknown as number) - (luaIndex(values, 2) as unknown as number))) as unknown as number))), 0.5, luaCall(luaProp(math, "round"), ((9 as unknown as number) - (((wave as unknown as number) * (18 as unknown as number)) as unknown as number))));
			return undefined;
		});
		let scale: unknown = colon(luaCall(luaProp(React, "joinBindings"), [clock, morph])).map(function(values?: unknown): unknown | undefined {
			let pulse: unknown = (reducedMotion ? 1 : ((0.82 as unknown as number) + ((((((luaCall(luaProp(math, "sin"), ((((((luaIndex(values, 1) as unknown as number) * (luaProp(math, "pi") as unknown as number)) as unknown as number) * (2 as unknown as number)) as unknown as number) - (((index as unknown as number) * (0.82 as unknown as number)) as unknown as number))) as unknown as number) + (1 as unknown as number))) as unknown as number) * (0.13 as unknown as number)) as unknown as number)));
			return luaCall(luaProp(math, "max"), 0.05, ((pulse as unknown as number) * ((((1 as unknown as number) - (luaIndex(values, 2) as unknown as number))) as unknown as number)));
			return undefined;
		});
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 14, 14), Position: position, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 414 }, reactLoose.createElement(ScaleFromCenter, { scale: scale, zIndex: 414 }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: color, BackgroundTransparency: colon(morph).map(function(amount?: unknown): unknown | undefined {
			return luaCall(luaProp(math, "clamp"), ((amount as unknown as number) * (1.2 as unknown as number)), 0, 1);
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 414 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "white"), Thickness: 1, Transparency: 0.42 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1.35, 0, 0, 3), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 1, 9), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaCall(darken, color, 0.28), BackgroundTransparency: 0.54, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })))));
		return undefined;
	}
	function ResultGlyph(_param?: unknown): unknown | undefined {
		let phase: unknown = luaProp(_param, "phase");
		let amount: unknown = luaProp(_param, "amount");
		let accent: unknown = luaProp(_param, "accent");
		let kind: unknown = ((phase === "success") ? "Check" : "Close");
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 78, 78), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 415 }, reactLoose.createElement(ScaleFromCenter, { scale: colon(amount).map(function(value?: unknown): unknown | undefined {
			return ((0.24 as unknown as number) + (((value as unknown as number) * (0.76 as unknown as number)) as unknown as number));
			return undefined;
		}), zIndex: 415 }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaCall(darken, accent, 0.78), BackgroundTransparency: colon(amount).map(function(value?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((value as unknown as number) * (0.22 as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 415 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 22) }), reactLoose.createElement("uistroke", { Color: accent, Thickness: 2, Transparency: colon(amount).map(function(value?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((value as unknown as number) * (0.92 as unknown as number)) as unknown as number));
			return undefined;
		}) }), reactLoose.createElement(Icon, { kind: kind, color: luaProp(Palette, "cream"), accent: accent, size: 54, spin: false, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5) }))));
		return undefined;
	}
	function PurchaseOverlay(_param?: unknown): unknown | undefined {
		let phase: unknown = luaProp(_param, "phase");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		let detail: unknown = luaProp(_param, "detail");
		let onDismiss: unknown = luaProp(_param, "onDismiss");
		let visible: unknown = (phase !== "hidden");
		let result: unknown = ((phase === "success") || (phase === "fail"));
		let show: unknown = luaCall(useBoatTween, (visible ? 1 : 0), (visible ? 0.25 : 0.18), softMotion, easeOutCubic, 0);
		let card: unknown = luaCall(useBoatTween, (visible ? 1 : 0), (visible ? 0.34 : 0.15), softMotion, easeOutBack, 0);
		let _binding: unknown = luaCall(useExitTransition, softMotion, 0.32, (phase === "hidden"));
		let exitAmount: unknown = luaIndex(_binding, 1);
		let exiting: unknown = luaIndex(_binding, 2);
		let beginExit: unknown = luaIndex(_binding, 3);
		let morph: unknown = luaCall(useFlipperSpring, (result ? 1 : 0), softMotion, 500, 30);
		let clock: unknown = luaCall(useClock, ((phase === "pending") && (!reducedMotion)), 1.4, 1);
		let viewport: unknown = luaCall(useViewport);
		let nonce: unknown;
		let setNonce: unknown;
		[nonce, setNonce] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let dismissRef: unknown = reactLoose.useRef(onDismiss);
		let dismissStarted: unknown = reactLoose.useRef(false);
		let overlayHostRef: unknown = reactLoose.useRef(undefined);
		luaSet(dismissRef, "current", onDismiss);
		let previousPhase: unknown = reactLoose.useRef("hidden");
		reactLoose.useEffect(function(): unknown | undefined {
			if ((phase === luaProp(previousPhase, "current"))) {
				return undefined;
			}
			luaSet(previousPhase, "current", phase);
			if ((phase === "success")) {
				colon(Audio).play("purchaseResult");
			} else if ((phase === "fail")) {
				colon(Audio).play("error");
			}
			return undefined;
		}, [phase]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (result) {
				luaCall(setNonce, function(value?: unknown): unknown | undefined {
					return ((value as unknown as number) + (1 as unknown as number));
					return undefined;
				});
			}
			return undefined;
		}, [phase, result]);
		let flash: unknown = luaCall(useFlash, nonce, reducedMotion, ((phase === "fail") ? 0.62 : 0.48));
		let dismiss: unknown = reactLoose.useCallback(function(): unknown | undefined {
			if ((((!result) || exiting) || luaProp(dismissStarted, "current"))) {
				return undefined;
			}
			luaSet(dismissStarted, "current", true);
			colon(Audio).play("purchaseExit");
			luaCall(beginExit, function(): unknown | undefined {
				let _result: unknown = luaProp(dismissRef, "current");
				if ((_result !== undefined)) {
					_result = luaCall(_result);
				}
				return _result;
				return undefined;
			});
			return undefined;
		}, [beginExit, exiting, result]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (((phase === "pending") || (phase === "hidden"))) {
				luaSet(dismissStarted, "current", false);
			}
			return undefined;
		}, [phase]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!result)) {
				return undefined;
			}
			let alive: unknown = true;
			let worker: unknown = luaCall(luaProp(task, "delay"), (reducedMotion ? PURCHASE_RESULT_HOLD_REDUCED : PURCHASE_RESULT_HOLD), function(): unknown | undefined {
				if (alive) {
					luaCall(dismiss);
				}
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				luaCall(pcall, luaProp(task, "cancel"), worker);
				return undefined;
			};
			return undefined;
		}, [dismiss, phase, reducedMotion, result]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((phase === "hidden")) {
				luaCall(luaProp(GamepadNavigationService, "EndOverlayFocus"));
				return undefined;
			}
			luaCall(luaProp(GamepadNavigationService, "BeginOverlayFocus"));
			return function(): unknown | undefined {
				luaCall(luaProp(GamepadNavigationService, "EndOverlayFocus"));
				return undefined;
			};
			return undefined;
		}, [phase]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (((!result) || (!luaProp(UserInputService, "GamepadEnabled")))) {
				return undefined;
			}
			let host: unknown = luaProp(overlayHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let alive: unknown = true;
			let selectJob: unknown = luaCall(luaProp(task, "defer"), function(): unknown | undefined {
				if (((!alive) || (luaProp(host, "Parent") === undefined))) {
					return;
				}
				luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				luaCall(pcall, luaProp(task, "cancel"), selectJob);
				return undefined;
			};
			return undefined;
		}, [phase, result]);
		let accent: unknown = ((phase === "fail") ? luaProp(Palette, "coral") : ((phase === "success") ? luaProp(Palette, "mint") : luaProp(Palette, "mango")));
		let title: unknown = ((phase === "pending") ? "BUYING..." : ((phase === "success") ? "BOUGHT" : "COULDN'T BUY"));
		let _result: unknown;
		if ((phase === "pending")) {
			_result = "Waiting on Roblox checkout";
		} else {
			let _result_1: unknown;
			if ((phase === "success")) {
				_result_1 = "It's in your account now";
			} else {
				let _condition: unknown = detail;
				if ((_condition === undefined)) {
					_condition = "You weren't charged";
				}
				_result_1 = _condition;
			}
			_result = _result_1;
		}
		let detailText: unknown = _result;
		let shortLandscape: unknown = (((luaProp(viewport, "height") as unknown as number) < (430 as unknown as number)) && ((luaProp(viewport, "width") as unknown as number) > (((luaProp(viewport, "height") as unknown as number) * (1.14 as unknown as number)) as unknown as number)));
		let sideSafe: unknown = luaCall(luaProp(math, "max"), luaProp(viewport, "sideInset"), 8);
		let topSafe: unknown = luaCall(luaProp(math, "max"), luaProp(viewport, "topInset"), 8);
		let bottomSafe: unknown = luaCall(luaProp(math, "max"), luaProp(viewport, "bottomInset"), 8);
		let safeHeight: unknown = luaCall(luaProp(math, "max"), 184, ((((luaProp(viewport, "height") as unknown as number) - (topSafe as unknown as number)) as unknown as number) - (bottomSafe as unknown as number)));
		let availableWidth: unknown = luaCall(luaProp(math, "max"), 280, ((luaProp(viewport, "width") as unknown as number) - ((((((sideSafe as unknown as number) + (12 as unknown as number))) as unknown as number) * (2 as unknown as number)) as unknown as number)));
		let cardWidth: unknown = luaCall(luaProp(math, "min"), (shortLandscape ? 540 : 430), availableWidth);
		let cardHeight: unknown = (shortLandscape ? luaCall(luaProp(math, "clamp"), ((safeHeight as unknown as number) - (16 as unknown as number)), 184, 218) : luaCall(luaProp(math, "clamp"), ((safeHeight as unknown as number) - (20 as unknown as number)), 232, 272));
		let compactVertical: unknown = ((!shortLandscape) && ((cardHeight as unknown as number) < (260 as unknown as number)));
		let presence: unknown = colon(luaCall(luaProp(React, "joinBindings"), [show, card, exitAmount])).map(function(values?: unknown): unknown | undefined {
			return luaCall(luaProp(math, "min"), luaIndex(values, 1), luaIndex(values, 2), luaIndex(values, 3));
			return undefined;
		});
		let cardTravel: unknown = 22;
		let cardPosition: unknown = colon(presence).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0.5, luaCall(luaProp(math, "floor"), (((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (cardTravel as unknown as number))));
			return undefined;
		});
		let cardScale: unknown = colon(luaCall(luaProp(React, "joinBindings"), [presence, flash])).map(function(values?: unknown): unknown | undefined {
			return ((((0.94 as unknown as number) + (((luaCall(luaProp(math, "clamp"), luaIndex(values, 1), 0, 1) as unknown as number) * (0.06 as unknown as number)) as unknown as number)) as unknown as number) + (((luaIndex(values, 2) as unknown as number) * (0.025 as unknown as number)) as unknown as number));
			return undefined;
		});
		let orbSize: unknown = (shortLandscape ? luaCall(luaProp(math, "min"), 106, ((cardHeight as unknown as number) - (32 as unknown as number))) : (compactVertical ? 104 : 118));
		let orbPosition: unknown = (shortLandscape ? luaCall(luaProp(UDim2, "fromOffset"), 20, luaCall(luaProp(math, "floor"), ((cardHeight as unknown as number) * (0.5 as unknown as number)))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0, 24));
		let orbAnchor: unknown = (shortLandscape ? new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0.5) : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0));
		let copyLeft: unknown = (shortLandscape ? ((orbSize as unknown as number) + (42 as unknown as number)) : 18);
		let copyWidth: unknown = (shortLandscape ? (-((((copyLeft as unknown as number) + (20 as unknown as number))) as unknown as number)) : -36);
		let titleY: unknown = (shortLandscape ? luaCall(luaProp(math, "max"), 28, ((luaCall(luaProp(math, "floor"), ((cardHeight as unknown as number) * (0.5 as unknown as number))) as unknown as number) - (44 as unknown as number))) : ((orbSize as unknown as number) + (((compactVertical ? 32 : 40)) as unknown as number)));
		let detailY: unknown = ((titleY as unknown as number) + (((shortLandscape ? 28 : 24)) as unknown as number));
		let railLeft: unknown = (shortLandscape ? copyLeft : 26);
		let railBottom: unknown = (shortLandscape ? 28 : (compactVertical ? 29 : 38));
		let _exp: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: colon(presence).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((amount as unknown as number) * (0.68 as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 400 });
		let _exp_1: unknown = reactLoose.createElement("imagebutton", { Name: "PurchaseDismissBackdrop", Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, Image: "", AutoButtonColor: false, Active: (visible && (!exiting)), Selectable: false, Modal: visible, ZIndex: 401, Event: { Activated: function(): unknown | undefined {
			if ((result && (!exiting))) {
				luaCall(dismiss);
			}
			return undefined;
		} } });
		let _exp_2: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, 4), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 5), BackgroundColor3: luaProp(Palette, "shadow"), BackgroundTransparency: 0.24, BorderSizePixel: 0, ZIndex: 405 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 22) }));
		let _exp_3: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 22) });
		let _exp_4: unknown = reactLoose.createElement("uigradient", { Color: luaCall(surfaceGradient, luaProp(Palette, "panelRaised"), 0.62), Rotation: 90 });
		let _exp_5: unknown = reactLoose.createElement("uistroke", { Color: accent, Thickness: 2, Transparency: colon(presence).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((amount as unknown as number) * (0.8 as unknown as number)) as unknown as number));
			return undefined;
		}) });
		let _exp_6: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.56, 0, 0, 3), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0), BackgroundColor3: accent, BorderSizePixel: 0, ZIndex: 407 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 1), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, 0), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 1)]) }));
		let _exp_7: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) });
		let _exp_8: unknown = reactLoose.createElement("uistroke", { Color: accent, Thickness: 2, Transparency: 0.5 });
		let _exp_9: unknown = [0, 1, 2];
		let _newValue: unknown = luaCall(luaProp(table, "create"), len(_exp_9));
		let _callback: unknown = function(index?: unknown): unknown | undefined {
			return reactLoose.createElement(ForgeDot, { key: index, index: index, clock: clock, morph: morph, reducedMotion: reducedMotion });
			return undefined;
		};
		for (const [_k, _v] of pairs((_exp_9) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), _exp_9));
		}
		let content: unknown = reactLoose.createElement(OverlayPresence, { amount: presence }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 400, Active: colon(presence).map(function(amount?: unknown): unknown | undefined {
			return (((amount as unknown as number) > (0.02 as unknown as number)) && (!exiting));
			return undefined;
		}), Visible: colon(presence).map(function(amount?: unknown): unknown | undefined {
			return ((amount as unknown as number) > (0.005 as unknown as number));
			return undefined;
		}), ClipsDescendants: false, Event: { InputBegan: function(_frame?: unknown, input?: unknown): unknown | undefined {
			if (((result && (!exiting)) && (((luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")) || (luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch")))))) {
				luaCall(dismiss);
			}
			return undefined;
		} } }, _exp, _exp_1, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), cardWidth, cardHeight), Position: cardPosition, AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 405, ClipsDescendants: false }, reactLoose.createElement(ScaleFromCenter, { scale: cardScale, zIndex: 405 }, _exp_2, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0, ClipsDescendants: true, ZIndex: 406 }, _exp_3, _exp_4, _exp_5, _exp_6, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), orbSize, orbSize), Position: orbPosition, AnchorPoint: orbAnchor, BackgroundColor3: luaCall(darken, accent, 0.86), BackgroundTransparency: 0.18, BorderSizePixel: 0, ZIndex: 410 }, _exp_7, _exp_8, _newValue, ((phase === "success") && reactLoose.createElement(ResultGlyph, { phase: "success", amount: morph, accent: accent })), ((phase === "fail") && reactLoose.createElement(ResultGlyph, { phase: "fail", amount: morph, accent: accent }))), reactLoose.createElement(Text, { value: title, size: (shortLandscape ? 15 : 16), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: (shortLandscape ? luaProp(luaProp(Enum, "TextXAlignment"), "Left") : luaProp(luaProp(Enum, "TextXAlignment"), "Center")), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), copyLeft, titleY), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, copyWidth, 0, 26), zIndex: 410 }), reactLoose.createElement(Text, { value: detailText, size: 11, color: luaProp(Palette, "creamSoft"), align: (shortLandscape ? luaProp(luaProp(Enum, "TextXAlignment"), "Left") : luaProp(luaProp(Enum, "TextXAlignment"), "Center")), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), copyLeft, detailY), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, copyWidth, 0, 28), zIndex: 410 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((railLeft as unknown as number) + (((shortLandscape ? 20 : 26)) as unknown as number))) as unknown as number)), 0, 3), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, railLeft, 1, (-(railBottom as unknown as number))), BackgroundColor3: luaProp(Palette, "lineSoft"), BackgroundTransparency: 0.52, BorderSizePixel: 0, ZIndex: 409, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("frame", { Size: ((phase === "pending") ? colon(clock).map(function(time?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.22, 0, 1, 0);
			return undefined;
		}) : luaCall(luaProp(UDim2, "fromScale"), 1, 1)), Position: ((phase === "pending") ? colon(clock).map(function(time?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)((((((time as unknown as number) * (1.25 as unknown as number))) as unknown as number) % (1 as unknown as number)), 0, 0, 0);
			return undefined;
		}) : luaCall(luaProp(UDim2, "fromScale"), 0, 0)), BackgroundColor3: accent, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaProp(Palette, "white"), accent) }))), (result && reactLoose.createElement("frame", { Name: "PurchaseContinue", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((copyLeft as unknown as number) + (((shortLandscape ? 20 : 26)) as unknown as number))) as unknown as number)), 0, 36), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, copyLeft, 1, -44), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 412 }, reactLoose.createElement(Button, { text: "CONTINUE", onClick: dismiss, color: accent, textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, highlight: true, selectable: true, zIndex: 412 }))))))));
		return reactLoose.createElement("frame", { ref: overlayHostRef, Name: "PurchaseOverlayHost", Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 400 }, content);
		return undefined;
	}
	return { PurchaseOverlay: PurchaseOverlay, PURCHASE_RESULT_HOLD: PURCHASE_RESULT_HOLD, PURCHASE_RESULT_HOLD_REDUCED: PURCHASE_RESULT_HOLD_REDUCED, PURCHASE_PENDING_FAILSAFE: PURCHASE_PENDING_FAILSAFE };
};

__defs["MobileControls"] = () => {
	let GuiService: unknown = colon(game).GetService("GuiService");
	let Players: unknown = colon(game).GetService("Players");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let _motion: unknown = kit("MotionKit", "motion");
	let useExitTransition: unknown = luaProp(_motion, "useExitTransition");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let usePulse: unknown = luaProp(_motion, "usePulse");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let EDIT_BOUNDS: unknown = luaProp(kit("CoreKit", "mobileLayout"), "EDIT_BOUNDS");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Palette: unknown = luaProp(_theme, "Palette");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let surfaceGradient: unknown = luaProp(_theme, "surfaceGradient");
	let _ui: unknown = kit("UiCore", "ui");
	let Button: unknown = luaProp(_ui, "Button");
	let Text: unknown = luaProp(_ui, "Text");
	let _format: unknown = kit("CoreKit", "format");
	let asFlux: unknown = luaProp(_format, "asFlux");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let dragHandles: unknown = {};
	let editMode: unknown = false;
	let dragId: unknown;
	let dragInput: unknown;
	let dragOffset: unknown = luaProp(Vector2, "zero");
	let dragLastCell: unknown = luaProp(Vector2, "zero");
	let dragChanged: unknown;
	let dragEnded: unknown;
	let dragFocusReleased: unknown;
	let dragMenuOpened: unknown;
	function cancelDrag(): unknown | undefined {
		dragId = undefined;
		dragInput = undefined;
		return undefined;
	}
	function clampDrag(pos?: unknown, bounds?: unknown): unknown | undefined {
		return new (Vector2 as unknown as new (...args: unknown[]) => unknown)(luaCall(luaProp(math, "clamp"), luaProp(pos, "X"), luaProp(bounds, "minX"), luaProp(bounds, "maxX")), luaCall(luaProp(math, "clamp"), luaProp(pos, "Y"), luaProp(bounds, "minY"), luaProp(bounds, "maxY")));
		return undefined;
	}
	function ensureDragging(): unknown | undefined {
		if ((dragChanged !== undefined)) {
			return undefined;
		}
		dragChanged = colon(luaProp(UserInputService, "InputChanged")).Connect(function(input?: unknown): unknown | undefined {
			if ((((!editMode) || (dragId === undefined)) || (dragInput === undefined))) {
				return undefined;
			}
			if ((luaProp(dragInput, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch"))) {
				if ((input !== dragInput)) {
					return undefined;
				}
			} else if ((luaProp(dragInput, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1"))) {
				if ((luaProp(input, "UserInputType") !== luaProp(luaProp(Enum, "UserInputType"), "MouseMovement"))) {
					return undefined;
				}
			} else {
				return undefined;
			}
			let _dragId: unknown = dragId;
			let handle: unknown = luaIndex(dragHandles, _dragId);
			if ((handle === undefined)) {
				return undefined;
			}
			let raw: unknown = new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((luaProp(luaProp(input, "Position"), "X") as unknown as number) - (luaProp(dragOffset, "X") as unknown as number)), ((luaProp(luaProp(input, "Position"), "Y") as unknown as number) - (luaProp(dragOffset, "Y") as unknown as number)));
			let _condition: unknown = luaProp(handle, "snap");
			if ((_condition === undefined)) {
				_condition = 1;
			}
			let grid: unknown = luaCall(luaProp(math, "max"), 1, _condition);
			let cellX: unknown = luaCall(luaProp(math, "round"), ((luaProp(raw, "X") as unknown as number) / (grid as unknown as number)));
			let cellY: unknown = luaCall(luaProp(math, "round"), ((luaProp(raw, "Y") as unknown as number) / (grid as unknown as number)));
			let resolvedPosition: unknown = luaCall(clampDrag, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((cellX as unknown as number) * (grid as unknown as number)), ((cellY as unknown as number) * (grid as unknown as number))), luaProp(handle, "bounds"));
			luaSet(handle, "position", resolvedPosition);
			let _result: unknown = luaProp(handle, "onMove");
			if ((_result !== undefined)) {
				luaCall(_result, resolvedPosition);
			}
			if (((cellX !== luaProp(dragLastCell, "X")) || (cellY !== luaProp(dragLastCell, "Y")))) {
				dragLastCell = new (Vector2 as unknown as new (...args: unknown[]) => unknown)(cellX, cellY);
				colon(Audio).play("dragSnap");
			}
			return undefined;
		});
		dragEnded = colon(luaProp(UserInputService, "InputEnded")).Connect(function(input?: unknown): unknown | undefined {
			if ((dragInput === undefined)) {
				return undefined;
			}
			let exactTouch: unknown = ((luaProp(dragInput, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch")) && (input === dragInput));
			let mouseRelease: unknown = ((luaProp(dragInput, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")) && (luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")));
			if ((exactTouch || mouseRelease)) {
				if ((dragId !== undefined)) {
					colon(Audio).play("dragDrop");
				}
				luaCall(cancelDrag);
			}
			return undefined;
		});
		dragFocusReleased = colon(luaProp(UserInputService, "WindowFocusReleased")).Connect(cancelDrag);
		dragMenuOpened = colon(luaProp(GuiService, "MenuOpened")).Connect(cancelDrag);
		return undefined;
	}
	let MobileDragging: unknown = { setEditMode: function(self_?: unknown, on?: unknown): unknown | undefined {
		editMode = on;
		if ((!on)) {
			luaCall(cancelDrag);
		}
		luaCall(ensureDragging);
		return undefined;
	}, register: function(self_?: unknown, handle?: unknown): unknown | undefined {
		luaCall(ensureDragging);
		let _id: unknown = luaProp(handle, "id");
		let _handle: unknown = handle;
		luaSetIndex(dragHandles, _id, _handle);
		return function(): unknown | undefined {
			let _id_1: unknown = luaProp(handle, "id");
			luaSetIndex(dragHandles, _id_1, undefined);
			if ((dragId === luaProp(handle, "id"))) {
				luaCall(cancelDrag);
			}
			return undefined;
		};
		return undefined;
	}, beginDrag: function(self_?: unknown, id?: unknown, input?: unknown): unknown | undefined {
		if ((!editMode)) {
			return undefined;
		}
		let _id: unknown = id;
		let handle: unknown = luaIndex(dragHandles, _id);
		if ((handle === undefined)) {
			return undefined;
		}
		colon(Audio).play("dragGrab");
		dragId = id;
		dragInput = input;
		dragOffset = new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((luaProp(luaProp(input, "Position"), "X") as unknown as number) - (luaProp(luaProp(handle, "position"), "X") as unknown as number)), ((luaProp(luaProp(input, "Position"), "Y") as unknown as number) - (luaProp(luaProp(handle, "position"), "Y") as unknown as number)));
		let _condition: unknown = luaProp(handle, "snap");
		if ((_condition === undefined)) {
			_condition = 1;
		}
		let grid: unknown = luaCall(luaProp(math, "max"), 1, _condition);
		dragLastCell = new (Vector2 as unknown as new (...args: unknown[]) => unknown)(luaCall(luaProp(math, "round"), ((luaProp(luaProp(handle, "position"), "X") as unknown as number) / (grid as unknown as number))), luaCall(luaProp(math, "round"), ((luaProp(luaProp(handle, "position"), "Y") as unknown as number) / (grid as unknown as number))));
		return undefined;
	}, setPosition: function(self_?: unknown, id?: unknown, pos?: unknown): unknown | undefined {
		let _id: unknown = id;
		let handle: unknown = luaIndex(dragHandles, _id);
		if ((handle === undefined)) {
			return undefined;
		}
		luaSet(handle, "position", luaCall(clampDrag, pos, luaProp(handle, "bounds")));
		let _result: unknown = luaProp(handle, "onMove");
		if ((_result !== undefined)) {
			luaCall(_result, luaProp(handle, "position"));
		}
		return undefined;
	}, dispose: function(self_?: unknown): unknown | undefined {
		let _result: unknown = dragChanged;
		if ((_result !== undefined)) {
			colon(_result).Disconnect();
		}
		let _result_1: unknown = dragEnded;
		if ((_result_1 !== undefined)) {
			colon(_result_1).Disconnect();
		}
		let _result_2: unknown = dragFocusReleased;
		if ((_result_2 !== undefined)) {
			colon(_result_2).Disconnect();
		}
		let _result_3: unknown = dragMenuOpened;
		if ((_result_3 !== undefined)) {
			colon(_result_3).Disconnect();
		}
		dragChanged = undefined;
		dragEnded = undefined;
		dragFocusReleased = undefined;
		dragMenuOpened = undefined;
		luaCall(luaProp(table, "clear"), dragHandles);
		luaCall(cancelDrag);
		editMode = false;
		return undefined;
	} };
	function slotPixels(slot?: unknown, width?: unknown, height?: unknown): unknown | undefined {
		let _condition: unknown = luaProp(slot, "width");
		if ((_condition === undefined)) {
			_condition = 112;
		}
		let slotW: unknown = _condition;
		let _condition_1: unknown = luaProp(slot, "height");
		if ((_condition_1 === undefined)) {
			_condition_1 = 62;
		}
		let slotH: unknown = _condition_1;
		let _exp: unknown = ((luaProp(slot, "x") as unknown as number) * (width as unknown as number));
		let _condition_2: unknown = luaProp(slot, "anchorX");
		if ((_condition_2 === undefined)) {
			_condition_2 = 0.5;
		}
		let _exp_1: unknown = ((_exp as unknown as number) - (((slotW as unknown as number) * (_condition_2 as unknown as number)) as unknown as number));
		let _exp_2: unknown = ((luaProp(slot, "y") as unknown as number) * (height as unknown as number));
		let _condition_3: unknown = luaProp(slot, "anchorY");
		if ((_condition_3 === undefined)) {
			_condition_3 = 0.5;
		}
		return new (Vector2 as unknown as new (...args: unknown[]) => unknown)(_exp_1, ((_exp_2 as unknown as number) - (((slotH as unknown as number) * (_condition_3 as unknown as number)) as unknown as number)));
		return undefined;
	}
	function slotBounds(slot?: unknown, width?: unknown, height?: unknown, sideInset?: unknown, topInset?: unknown, bottomInset?: unknown): unknown | undefined {
		let _condition: unknown = luaProp(slot, "width");
		if ((_condition === undefined)) {
			_condition = 112;
		}
		let slotW: unknown = _condition;
		let _condition_1: unknown = luaProp(slot, "height");
		if ((_condition_1 === undefined)) {
			_condition_1 = 62;
		}
		let slotH: unknown = _condition_1;
		let minX: unknown = luaCall(luaProp(math, "max"), 8, ((sideInset as unknown as number) + (8 as unknown as number)));
		let _exp: unknown = ((topInset as unknown as number) + (8 as unknown as number));
		let _condition_2: unknown = luaProp(slot, "safeTop");
		if ((_condition_2 === undefined)) {
			_condition_2 = 0;
		}
		let minY: unknown = luaCall(luaProp(math, "max"), 48, _exp, _condition_2);
		return { minX: minX, maxX: luaCall(luaProp(math, "max"), minX, ((((((width as unknown as number) - (sideInset as unknown as number)) as unknown as number) - (slotW as unknown as number)) as unknown as number) - (8 as unknown as number))), minY: minY, maxY: luaCall(luaProp(math, "max"), minY, ((((((height as unknown as number) - (bottomInset as unknown as number)) as unknown as number) - (slotH as unknown as number)) as unknown as number) - (8 as unknown as number))) };
		return undefined;
	}
	function safeSlotPosition(slot?: unknown, position?: unknown, width?: unknown, height?: unknown, sideInset?: unknown, topInset?: unknown, bottomInset?: unknown): unknown | undefined {
		let bounds: unknown = luaCall(slotBounds, slot, width, height, sideInset, topInset, bottomInset);
		return new (Vector2 as unknown as new (...args: unknown[]) => unknown)(luaCall(luaProp(math, "clamp"), luaProp(position, "X"), luaProp(bounds, "minX"), luaProp(bounds, "maxX")), luaCall(luaProp(math, "clamp"), luaProp(position, "Y"), luaProp(bounds, "minY"), luaProp(bounds, "maxY")));
		return undefined;
	}
	// Layout memory; fractions so a stored layout survives rotation. Seeded from the saved profile string.
	let MobileLayoutSlots: unknown = luaRequire(colon(colon(colon(colon(game).GetService("ReplicatedStorage")).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("MobileLayoutSlots"));
	let MOBILE_LAYOUT_MEMORY: unknown = {};
	let MOBILE_LAYOUT_SEEDED: unknown = false;
	function MobileControls(_param?: unknown): unknown | undefined {
		let slots: unknown = luaProp(_param, "slots");
		let dispatch: unknown = luaProp(_param, "dispatch");
		if (((!MOBILE_LAYOUT_SEEDED) && (luaTypeIs(luaProp(_param, "savedSlots"), "string")))) {
			MOBILE_LAYOUT_SEEDED = true;
			for (const [index, memory] of pairs((luaCall(luaProp(MobileLayoutSlots, "Decode"), luaProp(_param, "savedSlots"))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(MOBILE_LAYOUT_MEMORY, index, memory);
			}
		}
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let visible: unknown = luaProp(_param, "visible");
		let onClose: unknown = luaProp(_param, "onClose");
		let scales: unknown = luaProp(_param, "scales");
		let opacities: unknown = luaProp(_param, "opacities");
		let viewport: unknown = luaCall(useViewport);
		let editing: unknown;
		let setEditing: unknown;
		[editing, setEditing] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let snap: unknown;
		let setSnap: unknown;
		[snap, setSnap] = reactLoose.useState(true) as LuaTuple<[unknown, unknown]>;
		let snapStep: unknown;
		let setSnapStep: unknown;
		[snapStep, setSnapStep] = reactLoose.useState(16) as LuaTuple<[unknown, unknown]>;
		let fine: unknown;
		let setFine: unknown;
		[fine, setFine] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let showThirds: unknown;
		let setShowThirds: unknown;
		[showThirds, setShowThirds] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let selectedId: unknown;
		let setSelectedId: unknown;
		[selectedId, setSelectedId] = reactLoose.useState() as LuaTuple<[unknown, unknown]>;
		let locked: unknown;
		let setLocked: unknown;
		[locked, setLocked] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let history: unknown;
		let setHistory: unknown;
		[history, setHistory] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let redo: unknown;
		let setRedo: unknown;
		[redo, setRedo] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let positions: unknown;
		let setPositions: unknown;
		[positions, setPositions] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let memoryIndex: unknown;
		let setMemoryIndex: unknown;
		[memoryIndex, setMemoryIndex] = reactLoose.useState(1) as LuaTuple<[unknown, unknown]>;
		let memoryRevision: unknown;
		let setMemoryRevision: unknown;
		[memoryRevision, setMemoryRevision] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let _binding: unknown = luaCall(useExitTransition, reducedMotion, 0.38, visible);
		let exit: unknown = luaIndex(_binding, 1);
		let exiting: unknown = luaIndex(_binding, 2);
		let beginExit: unknown = luaIndex(_binding, 3);
		let requestClose: unknown = reactLoose.useCallback(function(): unknown | undefined {
			if ((!exiting)) {
				luaCall(beginExit, onClose);
			}
			return undefined;
		}, [beginExit, exiting, onClose]);
		let screen: unknown = reactLoose.useState(function(): unknown | undefined {
			let playerGui: unknown = colon(luaProp(Players, "LocalPlayer")).WaitForChild("PlayerGui");
			let vrScreen: unknown = colon(playerGui).FindFirstChild("AstralForgeVR");
			if ((vrScreen && luaProp(vrScreen, "Enabled"))) {
				return colon(vrScreen).FindFirstChild("Overlay");
			}
			let rootScreen: unknown = colon(playerGui).FindFirstChild("AstralForgeStudioUI");
			return (((rootScreen !== undefined) && colon(rootScreen).IsA("ScreenGui")) ? rootScreen : playerGui);
			return undefined;
		});
		let positionsRef: unknown = reactLoose.useRef(positions);
		luaSet(positionsRef, "current", positions);
		reactLoose.useEffect(function(): unknown | undefined {
			return function(): unknown | undefined {
				colon(MobileDragging).dispose();
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!visible)) {
				return undefined;
			}
			let initialPositions: unknown = {};
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(initialPositions, luaProp(slot, "id"), luaCall(safeSlotPosition, slot, luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			}
			luaSet(positionsRef, "current", initialPositions);
			luaCall(setPositions, initialPositions);
			return undefined;
		}, [slots, luaProp(viewport, "bottomInset"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "width"), visible]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!visible)) {
				colon(MobileDragging).setEditMode(false);
				luaCall(setEditing, false);
				return undefined;
			}
			let cleanups: unknown = {};
			let _object: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			luaCall(setmetatable, _object, undefined);
			let corrected: unknown = _object;
			let correctedAny: unknown = false;
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let bounds: unknown = luaCall(slotBounds, slot, luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
				let raw: unknown = (luaIndex(luaProp(positionsRef, "current"), luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
				let position: unknown = luaCall(safeSlotPosition, slot, raw, luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
				if (((luaProp(position, "X") !== luaProp(raw, "X")) || (luaProp(position, "Y") !== luaProp(raw, "Y")))) {
					luaSetIndex(corrected, luaProp(slot, "id"), position);
					correctedAny = true;
				}
				let _arg0: unknown = colon(MobileDragging).register({ id: luaProp(slot, "id"), position: position, bounds: bounds, snap: (snap ? snapStep : 1), onMove: function(nextPosition?: unknown): unknown | undefined {
					return luaCall(setPositions, function(current?: unknown): unknown | undefined {
						let _object_1: unknown = luaCall(luaProp(table, "clone"), current);
						luaCall(setmetatable, _object_1, undefined);
						luaSetIndex(_object_1, luaProp(slot, "id"), nextPosition);
						return _object_1;
						return undefined;
					});
					return undefined;
				} });
				luaTable.insert(cleanups, _arg0);
			}
			if (correctedAny) {
				luaSet(positionsRef, "current", corrected);
				luaCall(setPositions, corrected);
			}
			return function(): unknown | undefined {
				for (const [_, dispose] of pairs((cleanups) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					luaCall(dispose);
				}
				return undefined;
			};
			return undefined;
		}, [slots, snap, snapStep, luaProp(viewport, "bottomInset"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "width"), visible]);
		reactLoose.useEffect(function(): unknown | undefined {
			colon(MobileDragging).setEditMode((editing && visible));
			return function(): unknown | undefined {
				return colon(MobileDragging).setEditMode(false);
				return undefined;
			};
			return undefined;
		}, [editing, visible]);
		let layoutOverlaps: unknown = function(source?: unknown): unknown | undefined {
			{
				const _forStart_1 = (0 as unknown as number);
				const _forEnd_1 = (((len(slots) as unknown as number) - (1 as unknown as number)) as unknown as number);
				const _forStep_1 = (1 as unknown as number);
				for (let index = _forStart_1; _forStep_1 >= 0 ? index <= _forEnd_1 : index >= _forEnd_1; index += _forStep_1) {
					let slot: unknown = luaIndex(slots, ((index as unknown as number) + (1 as unknown as number)));
					let pos: unknown = (luaIndex(source, luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
					let _condition: unknown = luaProp(slot, "width");
					if ((_condition === undefined)) {
						_condition = 112;
					}
					let width: unknown = _condition;
					let _condition_1: unknown = luaProp(slot, "height");
					if ((_condition_1 === undefined)) {
						_condition_1 = 62;
					}
					let height: unknown = _condition_1;
					{
								let otherIndex: unknown = ((index as unknown as number) + (1 as unknown as number));
								let _shouldIncrement: unknown = false;
								while (true) {
									if (_shouldIncrement) {
										otherIndex = ((otherIndex as unknown as number) + (1 as unknown as number));
									} else {
										_shouldIncrement = true;
									}
									if ((!(((otherIndex as unknown as number) < (len(slots) as unknown as number))))) {
										break;
									}
									let other: unknown = luaIndex(slots, ((otherIndex as unknown as number) + (1 as unknown as number)));
									let otherPos: unknown = (luaIndex(source, luaProp(other, "id")) || luaCall(slotPixels, other, luaProp(viewport, "width"), luaProp(viewport, "height")));
									let _condition_2: unknown = luaProp(other, "width");
									if ((_condition_2 === undefined)) {
										_condition_2 = 112;
									}
									let otherWidth: unknown = _condition_2;
									let _condition_3: unknown = luaProp(other, "height");
									if ((_condition_3 === undefined)) {
										_condition_3 = 62;
									}
									let otherHeight: unknown = _condition_3;
									let separated: unknown = (((((((((luaProp(pos, "X") as unknown as number) + (width as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "X") as unknown as number)) || ((((((luaProp(otherPos, "X") as unknown as number) + (otherWidth as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(pos, "X") as unknown as number))) || ((((((luaProp(pos, "Y") as unknown as number) + (height as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "Y") as unknown as number))) || ((((((luaProp(otherPos, "Y") as unknown as number) + (otherHeight as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(pos, "Y") as unknown as number)));
									if ((!separated)) {
										return true;
									}
								}
							}
				}
			}
			return false;
			return undefined;
		};
		let save: unknown = function(source?: unknown): unknown | undefined {
			if ((source === undefined)) {
				source = luaProp(positionsRef, "current");
			}
			if (luaCall(layoutOverlaps, source)) {
				return false;
			}
			let values: unknown = {};
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let raw: unknown = (luaIndex(source, luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
				let pos: unknown = luaCall(safeSlotPosition, slot, raw, luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
				let _condition: unknown = luaProp(slot, "width");
				if ((_condition === undefined)) {
					_condition = 112;
				}
				let slotW: unknown = _condition;
				let _condition_1: unknown = luaProp(slot, "height");
				if ((_condition_1 === undefined)) {
					_condition_1 = 62;
				}
				let slotH: unknown = _condition_1;
				let _exp: unknown = luaProp(pos, "X");
				let _condition_2: unknown = luaProp(slot, "anchorX");
				if ((_condition_2 === undefined)) {
					_condition_2 = 0.5;
				}
				luaSetIndex(values, luaProp(slot, "xKey"), luaCall(luaProp(math, "clamp"), (((((_exp as unknown as number) + (((slotW as unknown as number) * (_condition_2 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "width") as unknown as number)), 0, 1));
				let _exp_1: unknown = luaProp(pos, "Y");
				let _condition_3: unknown = luaProp(slot, "anchorY");
				if ((_condition_3 === undefined)) {
					_condition_3 = 0.5;
				}
				luaSetIndex(values, luaProp(slot, "yKey"), luaCall(luaProp(math, "clamp"), (((((_exp_1 as unknown as number) + (((slotH as unknown as number) * (_condition_3 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "height") as unknown as number)), 0, 1));
			}
			luaCall(dispatch, "SetMobileLayout", { Values: values });
			return true;
			return undefined;
		};
		let finishEditing: unknown = function(): unknown | undefined {
			if ((!luaCall(save))) {
				return false;
			}
			luaCall(setEditing, false);
			return true;
			return undefined;
		};
		let capStack: unknown = function(source?: unknown, extra?: unknown): unknown | undefined {
			let _array: unknown = {};
			let _length: unknown = len(_array);
			luaTable.move(source, 1, len(source), ((_length as unknown as number) + (1 as unknown as number)), _array);
			let nextHist: unknown = _array;
			let _object: unknown = luaCall(luaProp(table, "clone"), extra);
			luaCall(setmetatable, _object, undefined);
			luaTable.insert(nextHist, _object);
			if (((len(nextHist) as unknown as number) <= (12 as unknown as number))) {
				return nextHist;
			}
			let trimmed: unknown = {};
			{
				const _forStart_2 = (((len(nextHist) as unknown as number) - (12 as unknown as number)) as unknown as number);
				const _forEnd_2 = (((len(nextHist) as unknown as number) - (1 as unknown as number)) as unknown as number);
				const _forStep_2 = (1 as unknown as number);
				for (let index = _forStart_2; _forStep_2 >= 0 ? index <= _forEnd_2 : index >= _forEnd_2; index += _forStep_2) {
					let _arg0: unknown = luaIndex(nextHist, ((index as unknown as number) + (1 as unknown as number)));
					luaTable.insert(trimmed, _arg0);
				}
			}
			return trimmed;
			return undefined;
		};
		let applyPositions: unknown = function(nextPos?: unknown): unknown | undefined {
			luaSet(positionsRef, "current", nextPos);
			luaCall(setPositions, nextPos);
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let pos: unknown = luaIndex(nextPos, luaProp(slot, "id"));
				if ((pos !== undefined)) {
					colon(MobileDragging).setPosition(luaProp(slot, "id"), pos);
				}
			}
			return undefined;
		};
		let pushHistory: unknown = function(source?: unknown): unknown | undefined {
			luaCall(setHistory, function(current?: unknown): unknown | undefined {
				return luaCall(capStack, current, source);
				return undefined;
			});
			luaCall(setRedo, {});
			return undefined;
		};
		let undoLayout: unknown = function(): unknown | undefined {
			if ((len(history) === 0)) {
				return undefined;
			}
			let prior: unknown = luaIndex(history, len(history));
			if ((prior === undefined)) {
				return undefined;
			}
			luaCall(setRedo, function(current?: unknown): unknown | undefined {
				return luaCall(capStack, current, luaProp(positionsRef, "current"));
				return undefined;
			});
			luaCall(setHistory, function(current?: unknown): unknown | undefined {
				let _newValue: unknown = {};
				let _callback: unknown = function(_?: unknown, index?: unknown): unknown | undefined {
					return ((index as unknown as number) < (((len(current) as unknown as number) - (1 as unknown as number)) as unknown as number));
					return undefined;
				};
				let _length: unknown = 0;
				for (const [_k, _v] of pairs((current) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if ((luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), current) === true)) {
						_length = ((_length as unknown as number) + (1 as unknown as number));
						luaSetIndex(_newValue, _length, _v);
					}
				}
				return _newValue;
				return undefined;
			});
			luaCall(applyPositions, prior);
			colon(Audio).play("close", 0.94);
			return undefined;
		};
		let redoLayout: unknown = function(): unknown | undefined {
			if ((len(redo) === 0)) {
				return undefined;
			}
			let upcoming: unknown = luaIndex(redo, len(redo));
			if ((upcoming === undefined)) {
				return undefined;
			}
			luaCall(setHistory, function(current?: unknown): unknown | undefined {
				return luaCall(capStack, current, luaProp(positionsRef, "current"));
				return undefined;
			});
			luaCall(setRedo, function(current?: unknown): unknown | undefined {
				let _newValue: unknown = {};
				let _callback: unknown = function(_?: unknown, index?: unknown): unknown | undefined {
					return ((index as unknown as number) < (((len(current) as unknown as number) - (1 as unknown as number)) as unknown as number));
					return undefined;
				};
				let _length: unknown = 0;
				for (const [_k, _v] of pairs((current) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if ((luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), current) === true)) {
						_length = ((_length as unknown as number) + (1 as unknown as number));
						luaSetIndex(_newValue, _length, _v);
					}
				}
				return _newValue;
				return undefined;
			});
			luaCall(applyPositions, upcoming);
			colon(Audio).play("open", 1.04);
			return undefined;
		};
		let nudgeSelected: unknown = function(dx?: unknown, dy?: unknown): unknown | undefined {
			let _condition: unknown = selectedId;
			if ((_condition === undefined)) {
				let _result: unknown = luaIndex(slots, 1);
				if ((_result !== undefined)) {
					_result = luaProp(_result, "id");
				}
				_condition = _result;
			}
			let id: unknown = _condition;
			if (((id === undefined) || (luaIndex(locked, id) === true))) {
				return undefined;
			}
			let _callback: unknown = function(entry?: unknown): unknown | undefined {
				return (luaProp(entry, "id") === id);
				return undefined;
			};
			let _result: unknown;
			for (const [_i, _v] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), slots) === true)) {
					_result = _v;
					break;
				}
			}
			let slot: unknown = _result;
			if ((slot === undefined)) {
				return undefined;
			}
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			let current: unknown = (luaIndex(luaProp(positionsRef, "current"), id) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
			let step: unknown = (fine ? 1 : ((snap ? snapStep : 4)));
			let moved: unknown = luaCall(safeSlotPosition, slot, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((luaProp(current, "X") as unknown as number) + (((dx as unknown as number) * (step as unknown as number)) as unknown as number)), ((luaProp(current, "Y") as unknown as number) + (((dy as unknown as number) * (step as unknown as number)) as unknown as number))), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
			let _object: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			luaCall(setmetatable, _object, undefined);
			luaSetIndex(_object, id, moved);
			luaCall(applyPositions, _object);
			return undefined;
		};
		let alignSelected: unknown = function(mode?: unknown): unknown | undefined {
			let _condition: unknown = selectedId;
			if ((_condition === undefined)) {
				let _result: unknown = luaIndex(slots, 1);
				if ((_result !== undefined)) {
					_result = luaProp(_result, "id");
				}
				_condition = _result;
			}
			let id: unknown = _condition;
			if (((id === undefined) || (luaIndex(locked, id) === true))) {
				return undefined;
			}
			let _callback: unknown = function(entry?: unknown): unknown | undefined {
				return (luaProp(entry, "id") === id);
				return undefined;
			};
			let _result: unknown;
			for (const [_i, _v] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), slots) === true)) {
					_result = _v;
					break;
				}
			}
			let slot: unknown = _result;
			if ((slot === undefined)) {
				return undefined;
			}
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			let current: unknown = (luaIndex(luaProp(positionsRef, "current"), id) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
			let _condition_1: unknown = luaProp(slot, "width");
			if ((_condition_1 === undefined)) {
				_condition_1 = 112;
			}
			let slotW: unknown = _condition_1;
			let _condition_2: unknown = luaProp(slot, "height");
			if ((_condition_2 === undefined)) {
				_condition_2 = 62;
			}
			let slotH: unknown = _condition_2;
			let bounds: unknown = luaCall(slotBounds, slot, luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
			let x: unknown = luaProp(current, "X");
			let y: unknown = luaProp(current, "Y");
			if ((mode === "left")) {
				x = luaProp(bounds, "minX");
			}
			if ((mode === "right")) {
				x = luaProp(bounds, "maxX");
			}
			if ((mode === "top")) {
				y = luaProp(bounds, "minY");
			}
			if ((mode === "bottom")) {
				y = luaProp(bounds, "maxY");
			}
			if ((mode === "cx")) {
				x = luaCall(luaProp(math, "floor"), (((((luaProp(viewport, "width") as unknown as number) - (slotW as unknown as number))) as unknown as number) / (2 as unknown as number)));
			}
			if ((mode === "cy")) {
				y = luaCall(luaProp(math, "floor"), (((((luaProp(viewport, "height") as unknown as number) - (slotH as unknown as number))) as unknown as number) / (2 as unknown as number)));
			}
			let _object: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			luaCall(setmetatable, _object, undefined);
			luaSetIndex(_object, id, luaCall(safeSlotPosition, slot, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(x, y), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			luaCall(applyPositions, _object);
			return undefined;
		};
		let unstackOverlaps: unknown = function(): unknown | undefined {
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			let _object: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			luaCall(setmetatable, _object, undefined);
			let nextPos: unknown = _object;
			{
				const _forStart_3 = (0 as unknown as number);
				const _forEnd_3 = (((len(slots) as unknown as number) - (1 as unknown as number)) as unknown as number);
				const _forStep_3 = (1 as unknown as number);
				for (let index = _forStart_3; _forStep_3 >= 0 ? index <= _forEnd_3 : index >= _forEnd_3; index += _forStep_3) {
					let slot: unknown = luaIndex(slots, ((index as unknown as number) + (1 as unknown as number)));
					if ((luaIndex(locked, luaProp(slot, "id")) === true)) {
						continue;
					}
					let pos: unknown = (luaIndex(nextPos, luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
					let _condition: unknown = luaProp(slot, "width");
					if ((_condition === undefined)) {
						_condition = 112;
					}
					let width: unknown = _condition;
					let _condition_1: unknown = luaProp(slot, "height");
					if ((_condition_1 === undefined)) {
						_condition_1 = 62;
					}
					let height: unknown = _condition_1;
					{
						const _forStart_4 = (0 as unknown as number);
						const _forEnd_4 = (((len(slots) as unknown as number) - (1 as unknown as number)) as unknown as number);
						const _forStep_4 = (1 as unknown as number);
						for (let otherIndex = _forStart_4; _forStep_4 >= 0 ? otherIndex <= _forEnd_4 : otherIndex >= _forEnd_4; otherIndex += _forStep_4) {
							if ((otherIndex === index)) {
								continue;
							}
							let other: unknown = luaIndex(slots, ((otherIndex as unknown as number) + (1 as unknown as number)));
							let otherPos: unknown = (luaIndex(nextPos, luaProp(other, "id")) || luaCall(slotPixels, other, luaProp(viewport, "width"), luaProp(viewport, "height")));
							let _condition_2: unknown = luaProp(other, "width");
							if ((_condition_2 === undefined)) {
								_condition_2 = 112;
							}
							let otherW: unknown = _condition_2;
							let _condition_3: unknown = luaProp(other, "height");
							if ((_condition_3 === undefined)) {
								_condition_3 = 62;
							}
							let otherH: unknown = _condition_3;
							let separated: unknown = (((((((((luaProp(pos, "X") as unknown as number) + (width as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "X") as unknown as number)) || ((((((luaProp(otherPos, "X") as unknown as number) + (otherW as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) <= (luaProp(pos, "X") as unknown as number))) || ((((((luaProp(pos, "Y") as unknown as number) + (height as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "Y") as unknown as number))) || ((((((luaProp(otherPos, "Y") as unknown as number) + (otherH as unknown as number)) as unknown as number) + (8 as unknown as number)) as unknown as number) <= (luaProp(pos, "Y") as unknown as number)));
							if (separated) {
								continue;
							}
							pos = luaCall(safeSlotPosition, slot, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(luaProp(pos, "X"), ((((luaProp(otherPos, "Y") as unknown as number) + (otherH as unknown as number)) as unknown as number) + (12 as unknown as number))), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset"));
						}
					}
					luaSetIndex(nextPos, luaProp(slot, "id"), pos);
				}
			}
			luaCall(applyPositions, nextPos);
			luaCall(save, nextPos);
			return undefined;
		};
		let bumpSelectedSetting: unknown = function(kind?: unknown, delta?: unknown): unknown | undefined {
			let _condition: unknown = selectedId;
			if ((_condition === undefined)) {
				let _result: unknown = luaIndex(slots, 1);
				if ((_result !== undefined)) {
					_result = luaProp(_result, "id");
				}
				_condition = _result;
			}
			let id: unknown = _condition;
			if ((id === undefined)) {
				return undefined;
			}
			let key: unknown = ((id === "quick") ? (((kind === "scale") ? "MobileQuickScale" : "MobileQuickOpacity")) : ((id === "dock") ? (((kind === "scale") ? "MobileDockScale" : "MobileDockOpacity")) : (((kind === "scale") ? "MobileToastScale" : "MobileToastOpacity"))));
			let _result: unknown;
			if ((kind === "scale")) {
				let _result_1: unknown = scales;
				if ((_result_1 !== undefined)) {
					_result_1 = luaIndex(_result_1, id);
				}
				let _condition_1: unknown = _result_1;
				if ((_condition_1 === undefined)) {
					_condition_1 = 0.5;
				}
				_result = _condition_1;
			} else {
				let _result_1: unknown = opacities;
				if ((_result_1 !== undefined)) {
					_result_1 = luaIndex(_result_1, id);
				}
				let _condition_1: unknown = _result_1;
				if ((_condition_1 === undefined)) {
					_condition_1 = 0.85;
				}
				_result = _condition_1;
			}
			let current: unknown = _result;
			luaCall(dispatch, "SetSetting", { Key: key, Value: luaCall(luaProp(math, "clamp"), ((current as unknown as number) + (delta as unknown as number)), 0, 1) });
			return undefined;
		};
		let resetLayout: unknown = function(): unknown | undefined {
			let fresh: unknown = {};
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let _object: unknown = luaCall(luaProp(table, "clone"), slot);
				luaCall(setmetatable, _object, undefined);
				luaSet(_object, "x", luaProp(slot, "defaultX"));
				luaSet(_object, "y", luaProp(slot, "defaultY"));
				let resetSlot: unknown = _object;
				luaSetIndex(fresh, luaProp(slot, "id"), luaCall(safeSlotPosition, slot, luaCall(slotPixels, resetSlot, luaProp(viewport, "width"), luaProp(viewport, "height")), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			}
			if (luaCall(layoutOverlaps, fresh)) {
				return undefined;
			}
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				colon(MobileDragging).setPosition(luaProp(slot, "id"), luaIndex(fresh, luaProp(slot, "id")));
			}
			luaSet(positionsRef, "current", fresh);
			luaCall(setPositions, fresh);
			luaCall(save, fresh);
			return undefined;
		};
		let applyPreset: unknown = function(side?: unknown): unknown | undefined {
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			colon(Audio).play("filterPick", 1.02);
			let fresh: unknown = {};
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let x: unknown = luaProp(slot, "defaultX");
				let y: unknown = luaProp(slot, "defaultY");
				if ((side === "left")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.28;
						y = 0.72;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.22;
						y = 0.24;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "right")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.72;
						y = 0.72;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.78;
						y = 0.24;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "top")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.5;
						y = 0.22;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.82;
						y = 0.38;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "thumbs")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.5;
						y = 0.78;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.5;
						y = 0.18;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.93;
					}
				} else if ((side === "tl")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.22;
						y = 0.22;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.78;
						y = 0.22;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "tr")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.78;
						y = 0.22;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.22;
						y = 0.22;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "bl")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.22;
						y = 0.78;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.22;
						y = 0.24;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				} else if ((side === "br")) {
					if ((luaProp(slot, "id") === "quick")) {
						x = 0.78;
						y = 0.78;
					}
					if ((luaProp(slot, "id") === "toasts")) {
						x = 0.78;
						y = 0.24;
					}
					if ((luaProp(slot, "id") === "dock")) {
						x = 0.5;
						y = 0.92;
					}
				}
				let _object: unknown = luaCall(luaProp(table, "clone"), slot);
				luaCall(setmetatable, _object, undefined);
				luaSet(_object, "x", x);
				luaSet(_object, "y", y);
				luaSetIndex(fresh, luaProp(slot, "id"), luaCall(safeSlotPosition, slot, luaCall(slotPixels, _object, luaProp(viewport, "width"), luaProp(viewport, "height")), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			}
			if (luaCall(layoutOverlaps, fresh)) {
				return undefined;
			}
			luaCall(applyPositions, fresh);
			luaCall(save, fresh);
			if (((side === "left") || (side === "bl"))) {
				luaCall(dispatch, "SetSetting", { Key: "MobileQuickReverse", Value: 1 });
			}
			if (((side === "right") || (side === "br"))) {
				luaCall(dispatch, "SetSetting", { Key: "MobileQuickReverse", Value: 0 });
			}
			return undefined;
		};
		let slotSize: unknown = function(slot?: unknown): unknown | undefined {
			return $tuple((luaProp(slot, "width") || 112), (luaProp(slot, "height") || 62));
			return undefined;
		};
		let commitLayout: unknown = function(nextPos?: unknown): unknown | undefined {
			luaCall(applyPositions, nextPos);
			if ((!luaCall(layoutOverlaps, nextPos))) {
				luaCall(save, nextPos);
			}
			return undefined;
		};
		let mirrorLayout: unknown = function(): unknown | undefined {
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			colon(Audio).play("filterPick", 0.94);
			let nextPos: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaIndex(locked, luaProp(slot, "id")) === true)) {
					continue;
				}
				let pos: unknown = (luaIndex(nextPos, luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
				let width: unknown = luaCall(slotSize, slot);
				luaSetIndex(nextPos, luaProp(slot, "id"), luaCall(safeSlotPosition, slot, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((((luaProp(viewport, "width") as unknown as number) - (luaProp(pos, "X") as unknown as number)) as unknown as number) - (width as unknown as number)), luaProp(pos, "Y")), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			}
			luaCall(commitLayout, nextPos);
			return undefined;
		};
		let cycleSelection: unknown = function(): unknown | undefined {
			if ((len(slots) === 0)) {
				return undefined;
			}
			let nextIndex: unknown = 1;
			for (const [index, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(slot, "id") === selectedId)) {
					nextIndex = ((((index as unknown as number) % (len(slots) as unknown as number)) as unknown as number) + (1 as unknown as number));
					break;
				}
			}
			luaCall(setSelectedId, luaProp(luaIndex(slots, nextIndex), "id"));
			colon(Audio).play("filterPick", 1.08);
			return undefined;
		};
		let swapSelected: unknown = function(): unknown | undefined {
			if (((len(slots) as unknown as number) < (2 as unknown as number))) {
				return undefined;
			}
			let fromIndex: unknown = 1;
			for (const [index, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(slot, "id") === selectedId)) {
					fromIndex = index;
					break;
				}
			}
			let fromSlot: unknown = luaIndex(slots, fromIndex);
			let toSlot: unknown = undefined;
			{
				const _forStart_5 = (1 as unknown as number);
				const _forEnd_5 = (((len(slots) as unknown as number) - (1 as unknown as number)) as unknown as number);
				const _forStep_5 = (1 as unknown as number);
				for (let step = _forStart_5; _forStep_5 >= 0 ? step <= _forEnd_5 : step >= _forEnd_5; step += _forStep_5) {
					let candidate: unknown = luaIndex(slots, (((((((((fromIndex as unknown as number) - (1 as unknown as number)) as unknown as number) + (step as unknown as number))) as unknown as number) % (len(slots) as unknown as number)) as unknown as number) + (1 as unknown as number)));
					if ((luaIndex(locked, luaProp(candidate, "id")) !== true)) {
						toSlot = candidate;
						break;
					}
				}
			}
			if (((toSlot === undefined) || (luaIndex(locked, luaProp(fromSlot, "id")) === true))) {
				return undefined;
			}
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			let nextPos: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			let fromPos: unknown = (luaIndex(nextPos, luaProp(fromSlot, "id")) || luaCall(slotPixels, fromSlot, luaProp(viewport, "width"), luaProp(viewport, "height")));
			let toPos: unknown = (luaIndex(nextPos, luaProp(toSlot, "id")) || luaCall(slotPixels, toSlot, luaProp(viewport, "width"), luaProp(viewport, "height")));
			let fromW: unknown;
			let fromH: unknown;
			[fromW, fromH] = luaCall(slotSize, fromSlot) as LuaTuple<[unknown, unknown]>;
			let toW: unknown;
			let toH: unknown;
			[toW, toH] = luaCall(slotSize, toSlot) as LuaTuple<[unknown, unknown]>;
			// Swap centres, not corners, so blocks of different sizes trade places cleanly.
			let fromCentre: unknown = ((fromPos as unknown as number) + (((new (Vector2 as unknown as new (...args: unknown[]) => unknown)(fromW, fromH) as unknown as number) / (2 as unknown as number)) as unknown as number));
			let toCentre: unknown = ((toPos as unknown as number) + (((new (Vector2 as unknown as new (...args: unknown[]) => unknown)(toW, toH) as unknown as number) / (2 as unknown as number)) as unknown as number));
			luaSetIndex(nextPos, luaProp(fromSlot, "id"), luaCall(safeSlotPosition, fromSlot, ((toCentre as unknown as number) - (((new (Vector2 as unknown as new (...args: unknown[]) => unknown)(fromW, fromH) as unknown as number) / (2 as unknown as number)) as unknown as number)), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			luaSetIndex(nextPos, luaProp(toSlot, "id"), luaCall(safeSlotPosition, toSlot, ((fromCentre as unknown as number) - (((new (Vector2 as unknown as new (...args: unknown[]) => unknown)(toW, toH) as unknown as number) / (2 as unknown as number)) as unknown as number)), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
			colon(Audio).play("filterPick", 1.0);
			luaCall(commitLayout, nextPos);
			return undefined;
		};
		let storeMemory: unknown = function(): unknown | undefined {
			let stored: unknown = {};
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let pos: unknown = (luaIndex(luaProp(positionsRef, "current"), luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
				luaSetIndex(stored, luaProp(slot, "id"), { x: ((luaProp(pos, "X") as unknown as number) / (luaCall(luaProp(math, "max"), 1, luaProp(viewport, "width")) as unknown as number)), y: ((luaProp(pos, "Y") as unknown as number) / (luaCall(luaProp(math, "max"), 1, luaProp(viewport, "height")) as unknown as number)) });
			}
			luaSetIndex(MOBILE_LAYOUT_MEMORY, memoryIndex, stored);
			luaCall(setMemoryRevision, ((memoryRevision as unknown as number) + (1 as unknown as number)));
			luaCall(dispatch, "SetMobileLayout", { Values: {}, Slots: luaCall(luaProp(MobileLayoutSlots, "Encode"), MOBILE_LAYOUT_MEMORY) });
			colon(Audio).play("copyDone");
			return undefined;
		};
		let recallMemory: unknown = function(): unknown | undefined {
			let stored: unknown = luaIndex(MOBILE_LAYOUT_MEMORY, memoryIndex);
			if ((stored === undefined)) {
				return undefined;
			}
			luaCall(pushHistory, luaProp(positionsRef, "current"));
			let nextPos: unknown = luaCall(luaProp(table, "clone"), luaProp(positionsRef, "current"));
			for (const [_, slot] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let entry: unknown = luaIndex(stored, luaProp(slot, "id"));
				if (((entry !== undefined) && (luaIndex(locked, luaProp(slot, "id")) !== true))) {
					luaSetIndex(nextPos, luaProp(slot, "id"), luaCall(safeSlotPosition, slot, new (Vector2 as unknown as new (...args: unknown[]) => unknown)(((luaProp(entry, "x") as unknown as number) * (luaProp(viewport, "width") as unknown as number)), ((luaProp(entry, "y") as unknown as number) * (luaProp(viewport, "height") as unknown as number))), luaProp(viewport, "width"), luaProp(viewport, "height"), luaProp(viewport, "sideInset"), luaProp(viewport, "topInset"), luaProp(viewport, "bottomInset")));
				}
			}
			colon(Audio).play("filterPick", 0.9);
			luaCall(commitLayout, nextPos);
			return undefined;
		};
		let overlaps: unknown = function(slot?: unknown, pos?: unknown): unknown | undefined {
			let _condition: unknown = luaProp(slot, "width");
			if ((_condition === undefined)) {
				_condition = 112;
			}
			let w: unknown = _condition;
			let _condition_1: unknown = luaProp(slot, "height");
			if ((_condition_1 === undefined)) {
				_condition_1 = 62;
			}
			let h: unknown = _condition_1;
			for (const [_, other] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(other, "id") === luaProp(slot, "id"))) {
					continue;
				}
				let otherPos: unknown = (luaIndex(positions, luaProp(other, "id")) || luaCall(slotPixels, other, luaProp(viewport, "width"), luaProp(viewport, "height")));
				let _condition_2: unknown = luaProp(other, "width");
				if ((_condition_2 === undefined)) {
					_condition_2 = 112;
				}
				let otherW: unknown = _condition_2;
				let _condition_3: unknown = luaProp(other, "height");
				if ((_condition_3 === undefined)) {
					_condition_3 = 62;
				}
				let otherH: unknown = _condition_3;
				let separated: unknown = (((((((((luaProp(pos, "X") as unknown as number) + (w as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "X") as unknown as number)) || ((((((luaProp(otherPos, "X") as unknown as number) + (otherW as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(pos, "X") as unknown as number))) || ((((((luaProp(pos, "Y") as unknown as number) + (h as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(otherPos, "Y") as unknown as number))) || ((((((luaProp(otherPos, "Y") as unknown as number) + (otherH as unknown as number)) as unknown as number) + (6 as unknown as number)) as unknown as number) <= (luaProp(pos, "Y") as unknown as number)));
				if ((!separated)) {
					return true;
				}
			}
			return false;
			return undefined;
		};
		let collisionPresent: unknown = luaCall(layoutOverlaps, positions);
		if ((!visible)) {
			return luaCall(luaProp(ReactRoblox, "createPortal"), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 }), screen);
		}
		let editorToolbarY: unknown = luaCall(luaProp(math, "max"), ((((luaProp(viewport, "width") as unknown as number) > (luaProp(viewport, "height") as unknown as number)) && ((luaProp(viewport, "height") as unknown as number) < (500 as unknown as number))) ? 56 : 8), ((luaProp(viewport, "topInset") as unknown as number) + (8 as unknown as number)));
		let topToolbarBottom: unknown = ((((((editorToolbarY as unknown as number) + (((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (16 as unknown as number)) as unknown as number) + (8 as unknown as number));
		let bottomBarY: unknown = luaCall(luaProp(math, "max"), topToolbarBottom, ((((luaProp(viewport, "height") as unknown as number) - (luaProp(viewport, "bottomInset") as unknown as number)) as unknown as number) - ((((((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)));
		let gridMarks: unknown = (showThirds ? [((1 as unknown as number) / (3 as unknown as number)), 0.5, ((2 as unknown as number) / (3 as unknown as number))] : [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]);
		let _callback: unknown = function(entry?: unknown): unknown | undefined {
			let _exp: unknown = luaProp(entry, "id");
			let _condition: unknown = selectedId;
			if ((_condition === undefined)) {
				let _result: unknown = luaIndex(slots, 1);
				if ((_result !== undefined)) {
					_result = luaProp(_result, "id");
				}
				_condition = _result;
			}
			return (_exp === _condition);
			return undefined;
		};
		let _result: unknown;
		for (const [_i, _v] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback, _v, ((_i as unknown as number) - (1 as unknown as number)), slots) === true)) {
				_result = _v;
				break;
			}
		}
		let selectedSlot: unknown = _result;
		let selectedPos: unknown = ((selectedSlot !== undefined) ? ((luaIndex(positions, luaProp(selectedSlot, "id")) || luaCall(slotPixels, selectedSlot, luaProp(viewport, "width"), luaProp(viewport, "height")))) : undefined);
		let selectedLocked: unknown = ((selectedSlot !== undefined) && (luaIndex(locked, luaProp(selectedSlot, "id")) === true));
		let _condition: unknown = editing;
		if (_condition) {
			let _newValue: unknown = luaCall(luaProp(table, "create"), len(gridMarks));
			let _callback_1: unknown = function(x?: unknown): unknown | undefined {
				return reactLoose.createElement("frame", { key: `grid-x-${x}`, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 1, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(x, 0, 0, 0), BackgroundColor3: ((x === 0.5) ? luaProp(Palette, "mint") : luaProp(Palette, "cyan")), BackgroundTransparency: ((x === 0.5) ? 0.72 : 0.9), BorderSizePixel: 0, ZIndex: 500, Active: false });
				return undefined;
			};
			for (const [_k, _v] of pairs((gridMarks) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), gridMarks));
			}
			_condition = _newValue;
		}
		let _condition_1: unknown = editing;
		if (_condition_1) {
			let _newValue: unknown = luaCall(luaProp(table, "create"), len(gridMarks));
			let _callback_1: unknown = function(y?: unknown): unknown | undefined {
				return reactLoose.createElement("frame", { key: `grid-y-${y}`, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 1), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, y, 0), BackgroundColor3: ((y === 0.5) ? luaProp(Palette, "mint") : luaProp(Palette, "cyan")), BackgroundTransparency: ((y === 0.5) ? 0.72 : 0.9), BorderSizePixel: 0, ZIndex: 500, Active: false });
				return undefined;
			};
			for (const [_k, _v] of pairs((gridMarks) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), gridMarks));
			}
			_condition_1 = _newValue;
		}
		let _condition_2: unknown = editing;
		if (_condition_2) {
			let _newValue: unknown = luaCall(luaProp(table, "create"), len(slots));
			let _callback_1: unknown = function(slot?: unknown): unknown | undefined {
				let _condition_3: unknown = luaProp(slot, "width");
				if ((_condition_3 === undefined)) {
					_condition_3 = 112;
				}
				let slotW: unknown = _condition_3;
				let _condition_4: unknown = luaProp(slot, "height");
				if ((_condition_4 === undefined)) {
					_condition_4 = 62;
				}
				let slotH: unknown = _condition_4;
				let pos: unknown = (luaIndex(positions, luaProp(slot, "id")) || luaCall(slotPixels, slot, luaProp(viewport, "width"), luaProp(viewport, "height")));
				let collision: unknown = luaCall(overlaps, slot, pos);
				let isLocked: unknown = (luaIndex(locked, luaProp(slot, "id")) === true);
				let accent: unknown = (collision ? luaProp(Palette, "coral") : ((selectedId === luaProp(slot, "id")) ? luaProp(Palette, "mint") : (isLocked ? luaProp(Palette, "mango") : EDIT_BOUNDS)));
				let pctX: unknown = luaCall(luaProp(math, "floor"), ((((((((luaProp(pos, "X") as unknown as number) + (((slotW as unknown as number) * (0.5 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "width") as unknown as number))) as unknown as number) * (100 as unknown as number)));
				let pctY: unknown = luaCall(luaProp(math, "floor"), ((((((((luaProp(pos, "Y") as unknown as number) + (((slotH as unknown as number) * (0.5 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "height") as unknown as number))) as unknown as number) * (100 as unknown as number)));
				return reactLoose.createElement("frame", { key: luaProp(slot, "id"), Size: luaCall(luaProp(UDim2, "fromOffset"), slotW, slotH), Position: luaCall(luaProp(UDim2, "fromOffset"), luaProp(pos, "X"), luaProp(pos, "Y")), BackgroundColor3: luaProp(Palette, "panelRaised"), BackgroundTransparency: 0.04, BorderSizePixel: 0, ZIndex: 502 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: accent, Thickness: (collision ? 3 : 2), Transparency: 0.08 }), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 22, 22), Position: luaCall(luaProp(UDim2, "fromOffset"), -7, -7), BackgroundColor3: accent, BorderSizePixel: 0, ZIndex: 505 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement(Text, { value: (isLocked ? "L" : "+"), size: 14, color: luaProp(Palette, "ink"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1), zIndex: 506 })), reactLoose.createElement(Text, { value: luaProp(slot, "label"), size: 11, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: luaCall(luaProp(UDim2, "fromOffset"), 4, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 18), zIndex: 503 }), reactLoose.createElement(Text, { value: `${pctX}%  ${pctY}%`, size: 9, color: luaProp(Palette, "creamSoft"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 4, 1, -22), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 14), zIndex: 503 }), (collision && reactLoose.createElement(Text, { value: "OVERLAP", size: 8, color: luaProp(Palette, "coral"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -36), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14), zIndex: 506 })), reactLoose.createElement("imagebutton", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, AutoButtonColor: false, Selectable: false, Active: true, ZIndex: 504, Event: { InputBegan: function(_button?: unknown, input?: unknown): unknown | undefined {
					if (((luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "Touch")) || (luaProp(input, "UserInputType") === luaProp(luaProp(Enum, "UserInputType"), "MouseButton1")))) {
						luaCall(setSelectedId, luaProp(slot, "id"));
						if ((!isLocked)) {
							colon(MobileDragging).beginDrag(luaProp(slot, "id"), input);
						}
					}
					return undefined;
				} } }));
				return undefined;
			};
			for (const [_k, _v] of pairs((slots) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), slots));
			}
			_condition_2 = _newValue;
		}
		let _condition_3: unknown = editing;
		if (_condition_3) {
			let _exp: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)), 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), ((luaProp(viewport, "sideInset") as unknown as number) + (8 as unknown as number)), editorToolbarY), BackgroundColor3: luaProp(Palette, "panelRaised"), BackgroundTransparency: 0.02, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 13) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: luaProp(Palette, "cyan"), Thickness: 1, Transparency: 0.42 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: (collisionPresent ? "OVERLAP" : "SAVE"), onClick: (collisionPresent ? unstackOverlaps : finishEditing), color: (collisionPresent ? luaProp(Palette, "coral") : EDIT_BOUNDS), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, 1, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: (snap ? `SNAP ${snapStep}` : "FREE"), onClick: function(): unknown | undefined {
				if ((!snap)) {
					luaCall(setSnap, true);
					luaCall(setSnapStep, 4);
				} else if ((snapStep === 4)) {
					luaCall(setSnapStep, 8);
				} else if ((snapStep === 8)) {
					luaCall(setSnapStep, 16);
				} else if ((snapStep === 16)) {
					luaCall(setSnapStep, 32);
				} else {
					luaCall(setSnap, false);
					luaCall(setSnapStep, 8);
				}
				return undefined;
			}, color: (snap ? luaProp(Palette, "cyan") : luaProp(Palette, "panelSoft")), textColor: (snap ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), outline: (!snap), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.4, 2, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "UNDO", onClick: undoLayout, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.6, 3, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "REDO", onClick: redoLayout, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.8, 4, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "DONE", onClick: function(): unknown | undefined {
				if (luaCall(finishEditing)) {
					luaCall(requestClose);
				}
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, disabled: exiting })));
			let _exp_1: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)), 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), ((luaProp(viewport, "sideInset") as unknown as number) + (8 as unknown as number)), ((((editorToolbarY as unknown as number) + (TapTarget as unknown as number)) as unknown as number) + (8 as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement(Button, { text: "←", onClick: function(): unknown | undefined {
				return luaCall(nudgeSelected, -1, 0);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "↑", onClick: function(): unknown | undefined {
				return luaCall(nudgeSelected, 0, -1);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, 1, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "↓", onClick: function(): unknown | undefined {
				return luaCall(nudgeSelected, 0, 1);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.32, 2, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "→", onClick: function(): unknown | undefined {
				return luaCall(nudgeSelected, 1, 0);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.48, 3, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: (fine ? "1px" : "STEP"), onClick: function(): unknown | undefined {
				return luaCall(setFine, (!fine));
				return undefined;
			}, color: (fine ? luaProp(Palette, "mint") : luaProp(Palette, "panelSoft")), textColor: (fine ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.18, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.64, 4, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: (showThirds ? "1/3" : "10%"), onClick: function(): unknown | undefined {
				return luaCall(setShowThirds, (!showThirds));
				return undefined;
			}, color: (showThirds ? luaProp(Palette, "cyan") : luaProp(Palette, "panelSoft")), textColor: (showThirds ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.18, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.82, 5, 0, 0), reducedMotion: reducedMotion }));
			let _exp_2: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)), 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), ((luaProp(viewport, "sideInset") as unknown as number) + (8 as unknown as number)), bottomBarY), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement(Button, { text: "L", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "left");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "R", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "right");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), 1, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "T", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "top");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((2 as unknown as number) / (6 as unknown as number)), 2, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "B", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "bottom");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((3 as unknown as number) / (6 as unknown as number)), 3, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "CX", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "cx");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((4 as unknown as number) / (6 as unknown as number)), 4, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "CY", onClick: function(): unknown | undefined {
				return luaCall(alignSelected, "cy");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (6 as unknown as number)), -4, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((5 as unknown as number) / (6 as unknown as number)), 5, 0, 0), reducedMotion: reducedMotion }));
			let _exp_3: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)), 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), ((luaProp(viewport, "sideInset") as unknown as number) + (8 as unknown as number)), ((((bottomBarY as unknown as number) + (TapTarget as unknown as number)) as unknown as number) + (6 as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement(Button, { text: (selectedLocked ? "UNLOCK" : "LOCK"), onClick: function(): unknown | undefined {
				if ((selectedSlot === undefined)) {
					return undefined;
				}
				luaCall(setLocked, function(current?: unknown): unknown | undefined {
					let _object: unknown = luaCall(luaProp(table, "clone"), current);
					luaCall(setmetatable, _object, undefined);
					luaSetIndex(_object, luaProp(selectedSlot, "id"), (!selectedLocked));
					return _object;
					return undefined;
				});
				return undefined;
			}, color: (selectedLocked ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: (selectedLocked ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.18, -3, 1, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "SZ-", onClick: function(): unknown | undefined {
				return luaCall(bumpSelectedSetting, "scale", -0.08);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.14, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.18, 1, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "SZ+", onClick: function(): unknown | undefined {
				return luaCall(bumpSelectedSetting, "scale", 0.08);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.14, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.32, 2, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "FADE-", onClick: function(): unknown | undefined {
				return luaCall(bumpSelectedSetting, "opacity", -0.08);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.46, 3, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "FADE+", onClick: function(): unknown | undefined {
				return luaCall(bumpSelectedSetting, "opacity", 0.08);
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.16, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.62, 4, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "CLEAR", onClick: unstackOverlaps, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.22, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.78, 5, 0, 0), reducedMotion: reducedMotion }));
			let _attributes: unknown = {};
			let _result_1: unknown;
			if ((selectedPos !== undefined)) {
				let _result_2: unknown = selectedSlot;
				if ((_result_2 !== undefined)) {
					_result_2 = luaProp(_result_2, "label");
				}
				let _condition_4: unknown = _result_2;
				if ((_condition_4 === undefined)) {
					_condition_4 = "HUD";
				}
				let selectedScale: unknown = (((scales !== undefined) && (selectedSlot !== undefined)) ? luaIndex(scales, luaProp(selectedSlot, "id")) : undefined);
				let selectedFade: unknown = (((opacities !== undefined) && (selectedSlot !== undefined)) ? luaIndex(opacities, luaProp(selectedSlot, "id")) : undefined);
				let xPct: unknown = luaCall(luaProp(math, "floor"), ((((((luaProp(selectedPos, "X") as unknown as number) / (luaCall(luaProp(math, "max"), 1, luaProp(viewport, "width")) as unknown as number)) as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
				let yPct: unknown = luaCall(luaProp(math, "floor"), ((((((luaProp(selectedPos, "Y") as unknown as number) / (luaCall(luaProp(math, "max"), 1, luaProp(viewport, "height")) as unknown as number)) as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
				_result_1 = `${_condition_4}  ·  X ${xPct}%  Y ${yPct}%  ·  SIZE ${luaCall(luaProp(math, "floor"), ((((((selectedScale || 0.5)) as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)))}  FADE ${luaCall(luaProp(math, "floor"), ((((((selectedFade || 0.85)) as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)))}${(selectedLocked ? "  ·  LOCKED" : "")}${(collisionPresent ? "  ·  OVERLAP" : "")}`;
			} else {
				_result_1 = "DRAG A BLOCK";
			}
			luaSet(_attributes, "value", _result_1);
			luaSet(_attributes, "size", 10);
			luaSet(_attributes, "color", luaProp(Palette, "cyan"));
			luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
			luaSet(_attributes, "align", luaProp(luaProp(Enum, "TextXAlignment"), "Center"));
			luaSet(_attributes, "position", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, ((luaProp(viewport, "sideInset") as unknown as number) + (12 as unknown as number)), 0, ((((editorToolbarY as unknown as number) + (((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) + (16 as unknown as number))));
			luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (24 as unknown as number))) as unknown as number)), 0, 18));
			luaSet(_attributes, "zIndex", 506);
			let toolRowY: unknown = ((((bottomBarY as unknown as number) - (TapTarget as unknown as number)) as unknown as number) - (6 as unknown as number));
			let memoryFilled: unknown = (luaIndex(MOBILE_LAYOUT_MEMORY, memoryIndex) !== undefined);
			let _exp_4: unknown = (((toolRowY as unknown as number) >= (((topToolbarBottom as unknown as number) + (18 as unknown as number)) as unknown as number)) && reactLoose.createElement("frame", { key: `tools-${memoryRevision}`, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number) + (16 as unknown as number))) as unknown as number)), 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), ((luaProp(viewport, "sideInset") as unknown as number) + (8 as unknown as number)), toolRowY), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement(Button, { text: "NEXT", onClick: cycleSelection, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cyan"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.15, -3, 1, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "SWAP", onClick: swapSelected, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.15, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.15, 1, 0, 0), disabled: selectedLocked, reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "MIRROR", onClick: mirrorLayout, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.18, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.3, 2, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: `M${memoryIndex}`, onClick: function(): unknown | undefined {
				luaCall(setMemoryIndex, ((((memoryIndex as unknown as number) % (3 as unknown as number)) as unknown as number) + (1 as unknown as number)));
				return undefined;
			}, color: (memoryFilled ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), textColor: (memoryFilled ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), outline: (!memoryFilled), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.12, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.48, 3, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "STORE", onClick: storeMemory, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "violet"), outline: true, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.6, 4, 0, 0), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "RECALL", onClick: recallMemory, color: (memoryFilled ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), textColor: (memoryFilled ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -3, 1, 0), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.8, 5, 0, 0), disabled: (!memoryFilled), reducedMotion: reducedMotion })));
			_condition_3 = reactLoose.createElement(React.Fragment, undefined, _exp, _exp_1, _exp_2, _exp_3, (_exp_4 || undefined), reactLoose.createElement(Text, _attributes));
		}
		return luaCall(luaProp(ReactRoblox, "createPortal"), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: colon(exit).map(function(amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((amount as unknown as number) * (((editing ? 0.62 : 0.88)) as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, Active: true, ZIndex: 500, ClipsDescendants: true, Visible: colon(exit).map(function(amount?: unknown): unknown | undefined {
			return ((amount as unknown as number) > (0.01 as unknown as number));
			return undefined;
		}) }, _condition, _condition_1, _condition_2, _condition_3, ((!editing) && reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), luaCall(luaProp(math, "min"), 440, ((((luaProp(viewport, "width") as unknown as number) - (((luaProp(viewport, "sideInset") as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (24 as unknown as number))), 292), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 1, (-((((304 as unknown as number) + (luaProp(viewport, "bottomInset") as unknown as number))) as unknown as number))), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0), BackgroundColor3: luaProp(Palette, "panelRaised"), BackgroundTransparency: 0.04, BorderSizePixel: 0, ZIndex: 510 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: luaProp(Palette, "cyan"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement(Button, { text: "EDIT HUD LAYOUT", onClick: function(): unknown | undefined {
			return luaCall(setEditing, true);
			return undefined;
		}, color: EDIT_BOUNDS, textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), reducedMotion: reducedMotion }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 56), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -4, 1, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "LEFT", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "left");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, 1, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "HOME", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "default");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cyan"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.4, 2, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "RIGHT", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "right");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.6, 3, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "TOP", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "top");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.8, 4, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "THUMB", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "thumbs");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion }))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 104), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -4, 1, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "TL", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "tl");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, 1, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "TR", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "tr");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 2, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "BL", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "bl");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.75, 3, 0, 0), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "BR", onClick: function(): unknown | undefined {
			return luaCall(applyPreset, "br");
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion }))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, TapTarget), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 152), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "RESET", onClick: resetLayout, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, TapTarget), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 0, 152), BackgroundTransparency: 1 }, reactLoose.createElement(Button, { text: "CLOSE", onClick: requestClose, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, disabled: exiting })), reactLoose.createElement(Text, { value: "Drag the vault, dock and alerts where you want them.", size: 10, color: luaProp(Palette, "muted"), wrap: true, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 212), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 56) }))), reactLoose.createElement("frame", { Size: colon(exit).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, ((0.5 as unknown as number) * ((((1 as unknown as number) - (amount as unknown as number))) as unknown as number)), 1);
			return undefined;
		}), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, Active: false, ZIndex: 900 }), reactLoose.createElement("frame", { Size: colon(exit).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, ((0.5 as unknown as number) * ((((1 as unknown as number) - (amount as unknown as number))) as unknown as number)), 1);
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0, 1), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 1), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, Active: false, ZIndex: 900 })), screen);
		return undefined;
	}
	function MobileQuickBar(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let height: unknown = luaProp(_param, "height");
		let bottomOffset: unknown = luaProp(_param, "bottomOffset");
		let edgePad: unknown = luaProp(_param, "edgePad");
		let hudX: unknown = luaProp(_param, "hudX");
		let hudY: unknown = luaProp(_param, "hudY");
		let hudScale: unknown = luaProp(_param, "hudScale");
		let hudOpacity: unknown = luaProp(_param, "hudOpacity");
		let buttonSpacing: unknown = luaProp(_param, "buttonSpacing");
		let minTop: unknown = luaProp(_param, "minTop");
		let reversed: unknown = luaProp(_param, "reversed");
		if ((reversed === undefined)) {
			reversed = false;
		}
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let vaultFill: unknown = (((luaCall(asFlux, luaProp(state, "Capacity")) as unknown as number) > (0 as unknown as number)) ? luaCall(luaProp(math, "clamp"), ((luaCall(asFlux, luaProp(state, "Vault")) as unknown as number) / (luaCall(asFlux, luaProp(state, "Capacity")) as unknown as number)), 0, 1) : 0);
		let vaultReady: unknown = ((luaCall(asFlux, luaProp(state, "Vault")) as unknown as number) >= (1 as unknown as number));
		let fillSpring: unknown = luaCall(useFlipperSpring, vaultFill, reducedMotion, 280, 28);
		let side: unknown = luaCall(luaProp(math, "max"), edgePad, luaProp(chrome, "sideSafe"));
		let _condition: unknown = buttonSpacing;
		if ((_condition === undefined)) {
			_condition = 0.5;
		}
		let gap: unknown = ((4 as unknown as number) + (luaCall(luaProp(math, "floor"), ((luaCall(luaProp(math, "clamp"), _condition, 0, 1) as unknown as number) * (10 as unknown as number))) as unknown as number));
		let btnH: unknown = TapTarget;
		let _condition_1: unknown = hudScale;
		if ((_condition_1 === undefined)) {
			_condition_1 = 0.5;
		}
		let scale: unknown = ((0.72 as unknown as number) + (((luaCall(luaProp(math, "clamp"), _condition_1, 0, 1) as unknown as number) * (0.28 as unknown as number)) as unknown as number));
		let width: unknown = luaCall(luaProp(math, "max"), 200, (((((luaProp(viewport, "width") as unknown as number) - (((side as unknown as number) * (2 as unknown as number)) as unknown as number))) as unknown as number) * (scale as unknown as number)));
		let _condition_2: unknown = hudX;
		if ((_condition_2 === undefined)) {
			_condition_2 = 0.5;
		}
		let x: unknown = luaCall(luaProp(math, "clamp"), _condition_2, (((((side as unknown as number) + (((width as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "width") as unknown as number)), ((1 as unknown as number) - ((((((side as unknown as number) + (((width as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "width") as unknown as number)) as unknown as number)));
		let yFallback: unknown = ((1 as unknown as number) - ((((((bottomOffset as unknown as number) - (((height as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (luaProp(viewport, "height") as unknown as number)) as unknown as number));
		let _condition_3: unknown = hudY;
		if ((_condition_3 === undefined)) {
			_condition_3 = yFallback;
		}
		let y: unknown = luaCall(luaProp(math, "clamp"), _condition_3, (((((((luaCall(luaProp(math, "max"), luaProp(viewport, "topInset"), minTop) as unknown as number) + (((height as unknown as number) / (2 as unknown as number)) as unknown as number)) as unknown as number) + (8 as unknown as number))) as unknown as number) / (luaProp(viewport, "height") as unknown as number)), ((1 as unknown as number) - ((((((((luaProp(viewport, "bottomInset") as unknown as number) + (((height as unknown as number) / (2 as unknown as number)) as unknown as number)) as unknown as number) + (8 as unknown as number))) as unknown as number) / (luaProp(viewport, "height") as unknown as number)) as unknown as number)));
		let _condition_4: unknown = hudOpacity;
		if ((_condition_4 === undefined)) {
			_condition_4 = 0.85;
		}
		let surfaceTransparency: unknown = luaCall(luaProp(math, "clamp"), ((0.48 as unknown as number) - (((luaCall(luaProp(math, "clamp"), _condition_4, 0, 1) as unknown as number) * (0.48 as unknown as number)) as unknown as number)), 0, 0.48);
		let readyPulse: unknown = luaCall(usePulse, (vaultReady && ((vaultFill as unknown as number) > (0.8 as unknown as number))), 2.4);
		let tapReadyAt: unknown;
		let setTapReadyAt: unknown;
		[tapReadyAt, setTapReadyAt] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let tapLeft: unknown;
		let setTapLeft: unknown;
		[tapLeft, setTapLeft] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(): unknown | undefined {
			if (((tapReadyAt as unknown as number) <= (0 as unknown as number))) {
				luaCall(setTapLeft, 0);
				return undefined;
			}
			let alive: unknown = true;
			let worker: unknown = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
				while (alive) {
					let left: unknown = luaCall(luaProp(math, "max"), 0, ((tapReadyAt as unknown as number) - (luaCall(luaProp(os, "clock")) as unknown as number)));
					if ((!alive)) {
						break;
					}
					luaCall(setTapLeft, ((luaCall(luaProp(math, "ceil"), ((left as unknown as number) * (10 as unknown as number))) as unknown as number) / (10 as unknown as number)));
					if (((!alive) || ((left as unknown as number) <= (0 as unknown as number)))) {
						break;
					}
					luaCall(luaProp(task, "wait"), luaCall(luaProp(math, "max"), 0.016, ((left as unknown as number) - ((((((luaCall(luaProp(math, "ceil"), ((left as unknown as number) * (10 as unknown as number))) as unknown as number) - (1 as unknown as number))) as unknown as number) / (10 as unknown as number)) as unknown as number))));
				}
				return undefined;
			});
			return function(): unknown | undefined {
				alive = false;
				luaCall(pcall, luaProp(task, "cancel"), worker);
				return undefined;
			};
			return undefined;
		}, [tapReadyAt]);
		let tap: unknown = function(): unknown | undefined {
			if (((luaCall(luaProp(os, "clock")) as unknown as number) < (tapReadyAt as unknown as number))) {
				return undefined;
			}
			luaCall(setTapReadyAt, ((luaCall(luaProp(os, "clock")) as unknown as number) + (0.45 as unknown as number)));
			luaCall(setTapLeft, 0.45);
			luaCall(dispatch, "Overcharge");
			return undefined;
		};
		let bank: unknown = function(): unknown | undefined {
			if ((!vaultReady)) {
				colon(Audio).play("locked");
				return undefined;
			}
			luaCall(dispatch, "CollectVault");
			return undefined;
		};
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), width, height), Position: luaCall(luaProp(UDim2, "fromScale"), x, y), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 60 }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panel"), BackgroundTransparency: surfaceTransparency, BorderSizePixel: 0, ZIndex: 61 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16) }), reactLoose.createElement("uigradient", { Color: luaCall(surfaceGradient, luaProp(Palette, "panel")), Rotation: 90 }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: (((vaultFill as unknown as number) > (0.8 as unknown as number)) ? luaProp(Palette, "green") : luaProp(Palette, "lineSoft")), Thickness: (((vaultFill as unknown as number) > (0.8 as unknown as number)) ? 2 : 1), Transparency: colon(readyPulse).map(function(amount?: unknown): unknown | undefined {
			return (((vaultFill as unknown as number) > (0.8 as unknown as number)) ? ((0.42 as unknown as number) - (((amount as unknown as number) * (0.22 as unknown as number)) as unknown as number)) : 0.45);
			return undefined;
		}) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, 3), Position: luaCall(luaProp(UDim2, "fromOffset"), 8, 1), BackgroundColor3: luaProp(Palette, "line"), BorderSizePixel: 0, ZIndex: 62, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("frame", { Size: colon(fillSpring).map(function(amount?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(luaCall(luaProp(math, "clamp"), amount, 0.02, 1), 0, 1, 0);
			return undefined;
		}), BackgroundColor3: (((vaultFill as unknown as number) > (0.92 as unknown as number)) ? luaProp(Palette, "mango") : luaProp(Palette, "green")), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -16, 0, btnH), Position: luaCall(luaProp(UDim2, "fromOffset"), 8, ((((height as unknown as number) - (btnH as unknown as number)) as unknown as number) - (4 as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 63 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, gap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.58, (((-(gap as unknown as number)) as unknown as number) / (2 as unknown as number)), 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: (reversed ? 2 : 1) }, reactLoose.createElement(Button, { text: (vaultReady ? `BANK  ${luaCall(compactNumber, luaProp(state, "Vault"))}` : "VAULT EMPTY"), icon: "Flux.24", onClick: bank, color: (vaultReady ? luaProp(Palette, "green") : luaProp(Palette, "panelSoft")), textColor: (vaultReady ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, disabled: (!vaultReady), highlight: (vaultReady && ((vaultFill as unknown as number) > (0.5 as unknown as number))) })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.42, (((-(gap as unknown as number)) as unknown as number) / (2 as unknown as number)), 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: (reversed ? 1 : 2) }, reactLoose.createElement(Button, { text: (((tapLeft as unknown as number) > (0.02 as unknown as number)) ? luaCall(luaProp(string, "format"), "%.1fs", tapLeft) : "TAP"), icon: "Forge.28", onClick: tap, color: (((tapLeft as unknown as number) > (0.02 as unknown as number)) ? luaProp(Palette, "panelSoft") : luaProp(Palette, "cyan")), textColor: (((tapLeft as unknown as number) > (0.02 as unknown as number)) ? luaProp(Palette, "muted") : luaProp(Palette, "ink")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, disabled: ((tapLeft as unknown as number) > (0.02 as unknown as number)), highlight: ((tapLeft as unknown as number) <= (0.02 as unknown as number)) }))), (luaProp(chrome, "landscape") && reactLoose.createElement(Text, { value: `${luaCall(compactNumber, luaProp(state, "Production"))}/s`, size: 9, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 0, 6), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 80, 12), zIndex: 64 }))));
		return undefined;
	}
	return { MobileControls: MobileControls, MobileQuickBar: MobileQuickBar };
};

__defs["floorFx"] = () => {
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let _motion: unknown = kit("MotionKit", "motion");
	let useClock: unknown = luaProp(_motion, "useClock");
	let useFlash: unknown = luaProp(_motion, "useFlash");
	let Motion: unknown = kit("MotionKit", "motionTokens");
	let Fx: unknown = kit("MotionKit", "vfxMath");
	let _theme: unknown = kit("CoreKit", "theme");
	let Palette: unknown = luaProp(_theme, "Palette");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let surfaceGradient: unknown = luaProp(_theme, "surfaceGradient");
	let Text: unknown = luaProp(kit("UiCore", "ui"), "Text");
	function clamp01(value?: unknown): unknown | undefined {
		return luaCall(luaProp(math, "clamp"), value, 0, 1);
		return undefined;
	}
	let SHOCK_LIFE: unknown = 0.55;
	function ShockRing(_param?: unknown): unknown | undefined {
		let trigger: unknown = luaProp(_param, "trigger");
		let color: unknown = luaProp(_param, "color");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let size: unknown = luaProp(_param, "size");
		if ((size === undefined)) {
			size = 280;
		}
		let clock: unknown = luaCall(useClock, (((trigger as unknown as number) > (0 as unknown as number)) && (!reducedMotion)), 1, 1000, true);
		let rings: unknown = {};
		{
			const _forStart_1 = (0 as unknown as number);
			const _forEnd_1 = (2 as unknown as number);
			const _forStep_1 = (1 as unknown as number);
			for (let ring = _forStart_1; _forStep_1 >= 0 ? ring <= _forEnd_1 : ring >= _forEnd_1; ring += _forStep_1) {
				let delay: unknown = ((ring as unknown as number) * (0.05 as unknown as number));
				luaSetIndex(rings, ((ring as unknown as number) + (1 as unknown as number)), reactLoose.createElement("frame", { key: ring, Size: colon(clock).map(function(seconds?: unknown): unknown | undefined {
					let grow: unknown = luaCall(luaProp(Fx, "ring"), ((seconds as unknown as number) - (delay as unknown as number)), SHOCK_LIFE);
					let d: unknown = ((24 as unknown as number) + (((grow as unknown as number) * ((((((size as unknown as number) * (0.95 as unknown as number)) as unknown as number) + (((ring as unknown as number) * (26 as unknown as number)) as unknown as number))) as unknown as number)) as unknown as number));
					return luaCall(luaProp(UDim2, "fromOffset"), d, d);
					return undefined;
				}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 81 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: ((ring === 1) ? luaProp(Palette, "cream") : luaCall(lighten, color, ((ring === 0) ? 0.25 : 0))), Thickness: ((ring === 0) ? 3 : 2), Transparency: colon(clock).map(function(seconds?: unknown): unknown | undefined {
					let _: unknown;
					let __2: unknown;
					let fade: unknown;
					[_, __2, fade] = luaCall(luaProp(Fx, "ring"), ((seconds as unknown as number) - (delay as unknown as number)), SHOCK_LIFE) as LuaTuple<[unknown, unknown, unknown]>;
					return ((0.05 as unknown as number) + (((fade as unknown as number) * (0.95 as unknown as number)) as unknown as number));
					return undefined;
				}) })));
			}
		}
		return reactLoose.createElement("frame", { key: `shock-${trigger}`, Size: luaCall(luaProp(UDim2, "fromOffset"), size, size), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.54), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 80, Active: false }, reactLoose.createElement("frame", { Size: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			let d: unknown = ((size as unknown as number) * ((((0.16 as unknown as number) + (((0.42 as unknown as number) * (luaCall(luaProp(luaProp(Motion, "EASE"), "decelerate"), luaCall(clamp01, ((seconds as unknown as number) / (0.2 as unknown as number)))) as unknown as number)) as unknown as number))) as unknown as number));
			return luaCall(luaProp(UDim2, "fromOffset"), d, d);
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaCall(lighten, color, 0.55), BackgroundTransparency: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return ((0.3 as unknown as number) + (((0.7 as unknown as number) * (luaCall(luaProp(luaProp(Motion, "EASE"), "accelerate"), luaCall(clamp01, ((seconds as unknown as number) / (0.24 as unknown as number)))) as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 82 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaProp(Palette, "white"), color), Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 0.6), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, 0), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 0.6)]) })), rings);
		return undefined;
	}
	let Spark: unknown;
	function SparkBurst(_param?: unknown): unknown | undefined {
		let sparks: unknown = luaProp(_param, "sparks");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let antilag: unknown = luaCall(useAntilag);
		let max: unknown = luaCall(luaProp(math, "max"), 4, luaCall(luaProp(math, "min"), ((luaProp(antilag, "maxPops") as unknown as number) * (2 as unknown as number)), 28));
		let visible: unknown = sparks;
		if (((len(sparks) as unknown as number) > (max as unknown as number))) {
			visible = {};
			{
				const _forStart_2 = (((((len(sparks) as unknown as number) - (max as unknown as number)) as unknown as number) + (1 as unknown as number)) as unknown as number);
				const _forEnd_2 = (len(sparks) as unknown as number);
				const _forStep_2 = (1 as unknown as number);
				for (let index = _forStart_2; _forStep_2 >= 0 ? index <= _forEnd_2 : index >= _forEnd_2; index += _forStep_2) {
					luaTable.insert(visible, luaIndex(sparks, index));
				}
			}
		}
		let children: unknown = luaCall(luaProp(table, "create"), len(visible));
		for (const [index, spark] of pairs((visible) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(children, index, reactLoose.createElement(Spark, { key: luaProp(spark, "id"), spark: spark, reducedMotion: reducedMotion }));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 90, Active: false, ClipsDescendants: false }, children);
		return undefined;
	}
	let SPARK_LIFE: unknown = 0.72;
	let SPARK_GRAVITY: unknown = 980;
	let SPARK_DRAG: unknown = 2.6;
	function Spark_2(_param?: unknown): unknown | undefined {
		let spark: unknown = luaProp(_param, "spark");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let clock: unknown = luaCall(useClock, true, 1, 1000, true);
		let crumb: unknown = (((luaProp(spark, "kind") === "strike") || (luaProp(spark, "kind") === "perfect")) || (luaProp(spark, "kind") === "bank"));
		let power: unknown = ((luaProp(spark, "kind") === "perfect") ? 1.35 : ((luaProp(spark, "kind") === "bank") ? 1.1 : 0.85));
		let thickness: unknown = ((luaProp(spark, "kind") === "perfect") ? 5 : (crumb ? 4 : 3.2));
		let angle: unknown = (((((-(luaProp(math, "pi") as unknown as number)) as unknown as number) / (2 as unknown as number)) as unknown as number) + ((((((luaCall(luaProp(Fx, "hash"), luaProp(spark, "id"), 1) as unknown as number) - (0.5 as unknown as number))) as unknown as number) * (luaCall(luaProp(math, "rad"), 150) as unknown as number)) as unknown as number));
		let speed: unknown = (((((((260 as unknown as number) + (((luaCall(luaProp(Fx, "hash"), luaProp(spark, "id"), 2) as unknown as number) * (260 as unknown as number)) as unknown as number))) as unknown as number) * (power as unknown as number)) as unknown as number) * (((reducedMotion ? 0.6 : 1)) as unknown as number));
		function velocity(seconds?: unknown): unknown | undefined {
			return luaCall(luaProp(Fx, "velocity"), seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG);
			return undefined;
		}
		return reactLoose.createElement("frame", { Size: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			let vx: unknown;
			let vy: unknown;
			[vx, vy] = luaCall(velocity, seconds) as LuaTuple<[unknown, unknown]>;
			let length: unknown = ((((thickness as unknown as number) * (1.4 as unknown as number)) as unknown as number) * (luaCall(luaProp(Fx, "stretch"), luaCall(luaProp(math, "sqrt"), ((((vx as unknown as number) * (vx as unknown as number)) as unknown as number) + (((vy as unknown as number) * (vy as unknown as number)) as unknown as number)))) as unknown as number));
			return luaCall(luaProp(UDim2, "fromOffset"), length, thickness);
			return undefined;
		}), Position: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			let dx: unknown;
			let dy: unknown;
			[dx, dy] = luaCall(luaProp(Fx, "ballistic"), seconds, angle, speed, SPARK_GRAVITY, SPARK_DRAG) as LuaTuple<[unknown, unknown]>;
			return ((luaCall(luaProp(UDim2, "fromScale"), luaProp(spark, "x"), luaProp(spark, "y")) as unknown as number) + (luaCall(luaProp(UDim2, "fromOffset"), dx, dy) as unknown as number));
			return undefined;
		}), Rotation: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			let vx: unknown;
			let vy: unknown;
			[vx, vy] = luaCall(velocity, seconds) as LuaTuple<[unknown, unknown]>;
			return luaCall(luaProp(math, "deg"), luaCall(luaProp(math, "atan2"), vy, vx));
			return undefined;
		}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return colon(luaProp(spark, "color")).Lerp(luaProp(Palette, "white"), luaCall(luaProp(Fx, "heat"), seconds, 0.16));
			return undefined;
		}), BackgroundTransparency: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return luaCall(luaProp(Fx, "fade"), seconds, SPARK_LIFE, 0.3);
			return undefined;
		}), BorderSizePixel: 0, ZIndex: 91 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 0.85), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.6, 0.15), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 0)]) }));
		return undefined;
	}
	let ClickPop: unknown;
	function ClickPops(_param?: unknown): unknown | undefined {
		let pops: unknown = luaProp(_param, "pops");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let antilag: unknown = luaCall(useAntilag);
		let max: unknown = luaCall(luaProp(math, "max"), 3, luaCall(luaProp(math, "min"), luaProp(antilag, "maxPops"), 10));
		let visible: unknown = pops;
		if (((len(pops) as unknown as number) > (max as unknown as number))) {
			visible = {};
			{
				const _forStart_3 = (((((len(pops) as unknown as number) - (max as unknown as number)) as unknown as number) + (1 as unknown as number)) as unknown as number);
				const _forEnd_3 = (len(pops) as unknown as number);
				const _forStep_3 = (1 as unknown as number);
				for (let index = _forStart_3; _forStep_3 >= 0 ? index <= _forEnd_3 : index >= _forEnd_3; index += _forStep_3) {
					luaTable.insert(visible, luaIndex(pops, index));
				}
			}
		}
		let children: unknown = luaCall(luaProp(table, "create"), len(visible));
		for (const [index, pop] of pairs((visible) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(children, index, reactLoose.createElement(ClickPop, { key: luaProp(pop, "id"), pop: pop, reducedMotion: reducedMotion }));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 96, Active: false, ClipsDescendants: false }, children);
		return undefined;
	}
	let POP_LIFE: unknown = 0.8;
	function ClickPop_2(_param?: unknown): unknown | undefined {
		let pop: unknown = luaProp(_param, "pop");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let clock: unknown = luaCall(useClock, true, 1, 1000, true);
		let size: unknown = (luaProp(pop, "critical") ? 34 : 24);
		let rise: unknown = (luaProp(pop, "critical") ? 118 : 86);
		let drift: unknown = (((((luaCall(luaProp(Fx, "hash"), luaProp(pop, "id"), 3) as unknown as number) - (0.5 as unknown as number))) as unknown as number) * (36 as unknown as number));
		let tilt: unknown = (luaProp(pop, "critical") ? (((((luaCall(luaProp(Fx, "hash"), luaProp(pop, "id"), 4) as unknown as number) - (0.5 as unknown as number))) as unknown as number) * (12 as unknown as number)) : 0);
		let position: unknown = colon(clock).map(function(seconds?: unknown): unknown | undefined {
			let t: unknown = luaCall(luaProp(luaProp(Motion, "EASE"), "decelerate"), luaCall(clamp01, ((seconds as unknown as number) / (POP_LIFE as unknown as number))));
			return ((luaCall(luaProp(UDim2, "fromScale"), luaProp(pop, "x"), luaProp(pop, "y")) as unknown as number) + (luaCall(luaProp(UDim2, "fromOffset"), ((drift as unknown as number) * (t as unknown as number)), (((-(t as unknown as number)) as unknown as number) * (rise as unknown as number))) as unknown as number));
			return undefined;
		});
		let scale: unknown = colon(clock).map(function(seconds?: unknown): unknown | undefined {
			if (reducedMotion) {
				return 1;
			}
			return luaCall(luaProp(Fx, "popScale"), seconds, (luaProp(pop, "critical") ? 0.24 : 0.18), (luaProp(pop, "critical") ? 0.55 : 0.4));
			return undefined;
		});
		let color: unknown = (luaProp(pop, "critical") ? colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return colon(luaProp(pop, "color")).Lerp(luaProp(Palette, "white"), luaCall(luaProp(Fx, "heat"), seconds, 0.14));
			return undefined;
		}) : luaProp(pop, "color"));
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), (luaProp(pop, "critical") ? 168 : 128), 40), Position: position, Rotation: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return ((tilt as unknown as number) * ((((1 as unknown as number) - (luaCall(luaProp(luaProp(Motion, "EASE"), "decelerate"), luaCall(clamp01, ((seconds as unknown as number) / (0.35 as unknown as number)))) as unknown as number))) as unknown as number));
			return undefined;
		}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 97 }, reactLoose.createElement("uiscale", { Scale: scale }), reactLoose.createElement(Text, { value: luaProp(pop, "text"), size: size, color: color, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: false, sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1), transparency: colon(clock).map(function(seconds?: unknown): unknown | undefined {
			return luaCall(luaProp(Fx, "fade"), seconds, POP_LIFE, 0.5);
			return undefined;
		}) }));
		return undefined;
	}
	function ComboBanner(_param?: unknown): unknown | undefined {
		let combo: unknown = luaProp(_param, "combo");
		let heat: unknown = luaProp(_param, "heat");
		let perfect: unknown = luaProp(_param, "perfect");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let pulse: unknown = luaCall(useClock, ((!reducedMotion) && ((combo as unknown as number) > (1 as unknown as number))), 1.05);
		let bump: unknown = luaCall(useFlash, combo, reducedMotion, 0.3);
		let accent: unknown = (perfect ? luaProp(Palette, "mango") : (((heat as unknown as number) > (0.82 as unknown as number)) ? luaProp(Palette, "coral") : luaProp(Palette, "brass")));
		if (((combo as unknown as number) <= (1 as unknown as number))) {
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 });
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 240, 52), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.145), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 70 }, reactLoose.createElement("uiscale", { Scale: colon(luaCall(luaProp(React, "joinBindings"), [pulse, bump])).map(function(values?: unknown): unknown | undefined {
			return ((((1 as unknown as number) + (((luaCall(luaProp(math, "sin"), luaIndex(values, 1)) as unknown as number) * (((perfect ? 0.045 : 0.022)) as unknown as number)) as unknown as number)) as unknown as number) + (((luaIndex(values, 2) as unknown as number) * (0.16 as unknown as number)) as unknown as number));
			return undefined;
		}) }), reactLoose.createElement(Text, { value: (perfect ? "CRIT" : "STREAK"), size: 11, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) }), reactLoose.createElement(Text, { value: `x${combo}`, size: (((combo as unknown as number) >= (10 as unknown as number)) ? 30 : 26), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 14), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 32) }));
		return undefined;
	}
	function HeatHaze(_param?: unknown): unknown | undefined {
		let heat: unknown = luaProp(_param, "heat");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let clock: unknown = luaCall(useClock, ((!reducedMotion) && ((heat as unknown as number) > (0.12 as unknown as number))), 0.22);
		let strength: unknown = luaCall(luaProp(math, "clamp"), heat, 0, 1);
		if (((strength as unknown as number) <= (0.02 as unknown as number))) {
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 });
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 4, Active: false }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1.08, 0, 0.42, 0), Position: colon(clock).map(function(phase?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((-0.04 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (0.02 as unknown as number)) as unknown as number)), 0, ((0.48 as unknown as number) + (((luaCall(luaProp(math, "cos"), ((phase as unknown as number) * (0.7 as unknown as number))) as unknown as number) * (0.012 as unknown as number)) as unknown as number)), 0);
			return undefined;
		}), BackgroundColor3: luaProp(Palette, "ember"), BackgroundTransparency: ((1 as unknown as number) - (((0.07 as unknown as number) * (strength as unknown as number)) as unknown as number)), BorderSizePixel: 0 }, reactLoose.createElement("uigradient", { Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 1), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.5, 0.35), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 1)]), Rotation: 90 })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 420, 420), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.62), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "brass"), BackgroundTransparency: ((1 as unknown as number) - (((0.05 as unknown as number) * (strength as unknown as number)) as unknown as number)), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
		return undefined;
	}
	function FluxRiver(_param?: unknown): unknown | undefined {
		let stations: unknown = luaProp(_param, "stations");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let accent: unknown = luaProp(_param, "accent");
		let clock: unknown = luaCall(useClock, (!reducedMotion), 0.55);
		let _newValue: unknown = luaCall(luaProp(table, "create"), len(stations));
		let _callback: unknown = function(station?: unknown, index?: unknown): unknown | undefined {
			return (luaProp(station, "live") ? reactLoose.createElement("frame", { key: `river-${index}`, Size: luaCall(luaProp(UDim2, "fromOffset"), 3, 3), Position: colon(clock).map(function(phase?: unknown): unknown | undefined {
				let t: unknown = (((((((phase as unknown as number) * (0.35 as unknown as number)) as unknown as number) + (((index as unknown as number) * (0.17 as unknown as number)) as unknown as number))) as unknown as number) % (1 as unknown as number));
				let x: unknown = ((luaProp(station, "x") as unknown as number) + ((((((0.5 as unknown as number) - (luaProp(station, "x") as unknown as number))) as unknown as number) * (t as unknown as number)) as unknown as number));
				let y: unknown = ((((luaProp(station, "y") as unknown as number) + ((((((0.58 as unknown as number) - (luaProp(station, "y") as unknown as number))) as unknown as number) * (t as unknown as number)) as unknown as number)) as unknown as number) - (((luaCall(luaProp(math, "sin"), ((t as unknown as number) * (luaProp(math, "pi") as unknown as number))) as unknown as number) * (0.04 as unknown as number)) as unknown as number));
				return luaCall(luaProp(UDim2, "fromScale"), x, y);
				return undefined;
			}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(station, "color"), BackgroundTransparency: colon(clock).map(function(phase?: unknown): unknown | undefined {
				let t: unknown = (((((((phase as unknown as number) * (0.35 as unknown as number)) as unknown as number) + (((index as unknown as number) * (0.17 as unknown as number)) as unknown as number))) as unknown as number) % (1 as unknown as number));
				return ((0.15 as unknown as number) + ((((((1 as unknown as number) - (luaCall(luaProp(math, "sin"), ((t as unknown as number) * (luaProp(math, "pi") as unknown as number))) as unknown as number))) as unknown as number) * (0.7 as unknown as number)) as unknown as number));
				return undefined;
			}), BorderSizePixel: 0, ZIndex: 7 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })) : undefined);
			return undefined;
		};
		for (const [_k, _v] of pairs((stations) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), stations));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 6, Active: false }, _newValue, reactLoose.createElement("frame", { Size: colon(clock).map(function(phase?: unknown): unknown | undefined {
			return luaCall(luaProp(UDim2, "fromOffset"), ((8 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (3 as unknown as number)) as unknown as number)), ((8 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (3 as unknown as number)) as unknown as number)));
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.58), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: accent, BackgroundTransparency: 0.35, BorderSizePixel: 0, ZIndex: 8 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })));
		return undefined;
	}
	function WorldHaze(_param?: unknown): unknown | undefined {
		let color: unknown = luaProp(_param, "color");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let clock: unknown = luaCall(useClock, (!reducedMotion), 0.07);
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 2, Active: false }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: 0, BorderSizePixel: 0, ZIndex: 1 }, reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)([new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Palette, "void")), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0.42, luaCall(darken, color, 0.82)), new (ColorSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, luaProp(Palette, "ink"))]), Rotation: 118 })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 720, 720), Position: colon(clock).map(function(phase?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, ((90 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (28 as unknown as number)) as unknown as number)), 1, ((50 as unknown as number) + (((luaCall(luaProp(math, "cos"), ((phase as unknown as number) * (0.7 as unknown as number))) as unknown as number) * (20 as unknown as number)) as unknown as number)));
			return undefined;
		}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: color, BackgroundTransparency: 0.9, BorderSizePixel: 0, ZIndex: 2 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 460, 460), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, -90, 0, -70), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "brass"), BackgroundTransparency: 0.93, BorderSizePixel: 0, ZIndex: 2 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 160), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -160), BackgroundColor3: luaProp(Palette, "ink"), BackgroundTransparency: 0.18, BorderSizePixel: 0, ZIndex: 3 }, reactLoose.createElement("uigradient", { Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 1), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 0.12)]), Rotation: 90 })));
		return undefined;
	}
	function CoreAura(_param?: unknown): unknown | undefined {
		let color: unknown = luaProp(_param, "color");
		let heat: unknown = luaProp(_param, "heat");
		let squash: unknown = luaProp(_param, "squash");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let clock: unknown = luaCall(useClock, (!reducedMotion), 0.16);
		let glow: unknown = luaCall(luaProp(math, "clamp"), ((0.16 as unknown as number) + (((heat as unknown as number) * (0.22 as unknown as number)) as unknown as number)), 0.16, 0.4);
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 18, Active: false }, reactLoose.createElement("frame", { Size: colon(clock).map(function(phase?: unknown): unknown | undefined {
			return luaCall(luaProp(UDim2, "fromScale"), ((0.72 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (0.03 as unknown as number)) as unknown as number)), ((0.72 as unknown as number) + (((luaCall(luaProp(math, "sin"), phase) as unknown as number) * (0.03 as unknown as number)) as unknown as number)));
			return undefined;
		}), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.54), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: color, BackgroundTransparency: ((1 as unknown as number) - (glow as unknown as number)), BorderSizePixel: 0, ZIndex: 18 }, reactLoose.createElement("uiscale", { Scale: squash }), reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), Position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.54), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundColor3: luaProp(Palette, "cream"), BackgroundTransparency: 0.88, BorderSizePixel: 0, ZIndex: 19 }, reactLoose.createElement("uiscale", { Scale: squash }), reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Color: luaCall(surfaceGradient, luaCall(lighten, color, 0.2), 0.8), Rotation: 90 })));
		return undefined;
	}
	return { ShockRing: ShockRing, SparkBurst: SparkBurst, ClickPops: ClickPops, ComboBanner: ComboBanner, HeatHaze: HeatHaze, FluxRiver: FluxRiver, WorldHaze: WorldHaze, CoreAura: CoreAura };
};


const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type UiOverlaysCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const UiOverlays = setmetatable(
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
) as unknown as UiOverlaysCallable;

export = UiOverlays;
