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
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let RunService: unknown = colon(game).GetService("RunService");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let _format: unknown = kit("CoreKit", "format");
	let clockText: unknown = luaProp(_format, "clockText");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let formatReward: unknown = luaProp(_format, "formatReward");
	let _Icon: unknown = kit("ArtKit", "Icon");
	let Icon: unknown = luaProp(_Icon, "Icon");
	let InteractionFeedback: unknown = luaProp(kit("CoreKit", "interaction"), "InteractionFeedback");
	let _motion: unknown = kit("MotionKit", "motion");
	let useFlash: unknown = luaProp(_motion, "useFlash");
	let useGlowStroke: unknown = luaProp(_motion, "useGlowStroke");
	let useRotation: unknown = luaProp(_motion, "useRotation");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let useWallClock: unknown = luaProp(_motion, "useWallClock");
	let _theme: unknown = kit("CoreKit", "theme");
	let Layout: unknown = luaProp(_theme, "Layout");
	let Palette: unknown = luaProp(_theme, "Palette");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let surfaceGradient: unknown = luaProp(_theme, "surfaceGradient");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let IconTile: unknown = luaProp(_ui, "IconTile");
	let Meter: unknown = luaProp(_ui, "Meter");
	let Panel: unknown = luaProp(_ui, "Panel");
	let Text: unknown = luaProp(_ui, "Text");
	// The spin, in five parts. Angles in degrees, time in seconds.
	//   windup  a short pull back against the spin
	//   launch  ease in up to cruise speed
	//   cruise  constant speed until the server has picked the prize
	//   brake   quartic ease-out onto the prize (+ a little overshoot); it starts at exactly the
	//           cruise speed so there is no hitch, and spends its last second crawling past pegs
	//   settle  the peg catches the overshoot and the wheel rocks back onto the prize
	let WHEEL_OMEGA: unknown = 1440;
	let WHEEL_OMEGA_LOW: unknown = 1080;
	let WHEEL_WINDUP_SECONDS: unknown = 0.3;
	let WHEEL_WINDUP_DEGREES: unknown = 18;
	let WHEEL_LAUNCH_SECONDS: unknown = 0.55;
	let WHEEL_MIN_CRUISE_SECONDS: unknown = 0.45;
	let WHEEL_SETTLE_SECONDS: unknown = 0.45;
	let WHEEL_OVERSHOOT_DEGREES: unknown = 4;
	function sampleSpin(plan?: unknown, elapsed?: unknown): unknown | undefined {
		let omega: unknown = luaProp(plan, "omega");
		if (((elapsed as unknown as number) < (WHEEL_WINDUP_SECONDS as unknown as number))) {
			let u: unknown = ((elapsed as unknown as number) / (WHEEL_WINDUP_SECONDS as unknown as number));
			return $tuple(((luaProp(plan, "base") as unknown as number) - (((WHEEL_WINDUP_DEGREES as unknown as number) * ((math.sin as unknown as (...a: unknown[]) => unknown)(((((u as unknown as number) * (luaProp(math, "pi") as unknown as number)) as unknown as number) / (2 as unknown as number))) as unknown as number)) as unknown as number)), 0);
		}
		let start: unknown = ((luaProp(plan, "base") as unknown as number) - (WHEEL_WINDUP_DEGREES as unknown as number));
		let launched: unknown = ((elapsed as unknown as number) - (WHEEL_WINDUP_SECONDS as unknown as number));
		if (((launched as unknown as number) < (WHEEL_LAUNCH_SECONDS as unknown as number))) {
			let u: unknown = ((launched as unknown as number) / (WHEEL_LAUNCH_SECONDS as unknown as number));
			// speed rises as u^2, so distance is the integral u^3 / 3
			return $tuple(((start as unknown as number) + (((((((((((omega as unknown as number) * (WHEEL_LAUNCH_SECONDS as unknown as number)) as unknown as number) * (u as unknown as number)) as unknown as number) * (u as unknown as number)) as unknown as number) * (u as unknown as number)) as unknown as number) / (3 as unknown as number)) as unknown as number)), ((((omega as unknown as number) * (u as unknown as number)) as unknown as number) * (u as unknown as number)));
		}
		return $tuple(((((start as unknown as number) + (((((omega as unknown as number) * (WHEEL_LAUNCH_SECONDS as unknown as number)) as unknown as number) / (3 as unknown as number)) as unknown as number)) as unknown as number) + (((omega as unknown as number) * ((((launched as unknown as number) - (WHEEL_LAUNCH_SECONDS as unknown as number))) as unknown as number)) as unknown as number)), omega);
		return undefined;
	}
	// brake + settle: where the wheel is `elapsed` seconds after braking began
	function sampleBrake(plan?: unknown, elapsed?: unknown): unknown | undefined {
		if (((elapsed as unknown as number) < (luaProp(plan, "duration") as unknown as number))) {
			let remaining: unknown = ((1 as unknown as number) - (((elapsed as unknown as number) / (luaProp(plan, "duration") as unknown as number)) as unknown as number));
			let r3: unknown = ((((remaining as unknown as number) * (remaining as unknown as number)) as unknown as number) * (remaining as unknown as number));
			return $tuple(((luaProp(plan, "base") as unknown as number) + (((luaProp(plan, "distance") as unknown as number) * ((((1 as unknown as number) - (((r3 as unknown as number) * (remaining as unknown as number)) as unknown as number))) as unknown as number)) as unknown as number)), ((((((4 as unknown as number) * (luaProp(plan, "distance") as unknown as number)) as unknown as number) / (luaProp(plan, "duration") as unknown as number)) as unknown as number) * (r3 as unknown as number)), false);
		}
		let u: unknown = (math.clamp as unknown as (...a: unknown[]) => unknown)((((((elapsed as unknown as number) - (luaProp(plan, "duration") as unknown as number))) as unknown as number) / (WHEEL_SETTLE_SECONDS as unknown as number)), 0, 1);
		// from +overshoot back to the prize, rocking once past it
		let rock: unknown = ((((luaProp(plan, "overshoot") as unknown as number) * ((((1 as unknown as number) - (u as unknown as number))) as unknown as number)) as unknown as number) * ((math.cos as unknown as (...a: unknown[]) => unknown)(((((u as unknown as number) * (luaProp(math, "pi") as unknown as number)) as unknown as number) * (1.5 as unknown as number))) as unknown as number));
		return $tuple(((((((luaProp(plan, "base") as unknown as number) + (luaProp(plan, "distance") as unknown as number)) as unknown as number) - (luaProp(plan, "overshoot") as unknown as number)) as unknown as number) + (rock as unknown as number)), 0, ((u as unknown as number) >= (1 as unknown as number)));
		return undefined;
	}
	function positiveModulo(value?: unknown, modulus?: unknown): unknown | undefined {
		return ((((((((value as unknown as number) % (modulus as unknown as number))) as unknown as number) + (modulus as unknown as number))) as unknown as number) % (modulus as unknown as number));
		return undefined;
	}
	let unresolvedSpin: unknown = undefined;
	function wheelPrizeIndex(rewards?: unknown, index?: unknown, id?: unknown): unknown | undefined {
		if (((((!luaTypeIs(index, "number")) || (((index as unknown as number) % (1 as unknown as number)) !== 0)) || ((index as unknown as number) < (1 as unknown as number))) || ((index as unknown as number) > (len(rewards) as unknown as number)))) {
			return undefined;
		}
		if (((!luaTypeIs(id, "string")) || (luaProp(luaIndex(rewards, index), "Id") !== id))) {
			return undefined;
		}
		return ((index as unknown as number) - (1 as unknown as number));
		return undefined;
	}
	function useWheelController(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let onLand: unknown = luaProp(_param, "onLand");
		let antilag: unknown = luaCall(useAntilag);
		let rewardCount: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(1, len(luaProp(luaProp(config, "Wheel"), "Rewards")));
		let segment: unknown = ((360 as unknown as number) / (rewardCount as unknown as number));
		let receipt: unknown = luaProp(luaProp(state, "Wheel"), "LastReceipt");
		let restoredIndex: unknown = -1;
		if (luaTruthy(receipt)) {
			restoredIndex = (luaCall(wheelPrizeIndex, luaProp(luaProp(config, "Wheel"), "Rewards"), luaProp(receipt, "PrizeIndex"), luaProp(receipt, "PrizeId")) || -1);
		}
		let phase: unknown;
		let setPhase: unknown;
		[phase, setPhase] = reactLoose.useState(((luaTruthy(unresolvedSpin) || ((luaTruthy(receipt) && ((restoredIndex as unknown as number) < (0 as unknown as number))))) ? "error" : (((restoredIndex as unknown as number) >= (0 as unknown as number)) ? "landed" : "idle"))) as LuaTuple<[unknown, unknown]>;
		let winner: unknown;
		let setWinner: unknown;
		[winner, setWinner] = reactLoose.useState(restoredIndex) as LuaTuple<[unknown, unknown]>;
		let failure: unknown;
		let setFailure: unknown;
		[failure, setFailure] = reactLoose.useState((luaTruthy(unresolvedSpin) ? "Confirm your interrupted spin before starting another." : ((luaTruthy(receipt) && ((restoredIndex as unknown as number) < (0 as unknown as number))) ? "Your saved reward does not match this wheel. Refresh before spinning." : undefined))) as LuaTuple<[unknown, unknown]>;
		let launchNonce: unknown;
		let setLaunchNonce: unknown;
		[launchNonce, setLaunchNonce] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let impactNonce: unknown;
		let setImpactNonce: unknown;
		[impactNonce, setImpactNonce] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let restoredRotation: unknown = (((restoredIndex as unknown as number) >= (0 as unknown as number)) ? luaCall(positiveModulo, ((360 as unknown as number) - (((restoredIndex as unknown as number) * (segment as unknown as number)) as unknown as number)), 360) : 0);
		let rotation: unknown;
		let setRotation: unknown;
		[rotation, setRotation] = reactLoose.useBinding(restoredRotation) as LuaTuple<[unknown, unknown]>;
		let pointerKick: unknown;
		let setPointerKick: unknown;
		[pointerKick, setPointerKick] = reactLoose.useBinding(0) as LuaTuple<[unknown, unknown]>;
		let spinEnergy: unknown;
		let setSpinEnergy: unknown;
		[spinEnergy, setSpinEnergy] = reactLoose.useBinding(0) as LuaTuple<[unknown, unknown]>;
		let rotationValue: unknown = reactLoose.useRef(restoredRotation);
		let pointerKickValue: unknown = reactLoose.useRef(0);
		let busy: unknown = reactLoose.useRef(false);
		let mounted: unknown = reactLoose.useRef(true);
		let token: unknown = reactLoose.useRef(0);
		let timeout: unknown = reactLoose.useRef();
		let pendingResult: unknown = reactLoose.useRef();
		let launchFinished: unknown = reactLoose.useRef(false);
		let beginBrakeRef: unknown = reactLoose.useRef(function(this: void): unknown | undefined {
			return undefined;
			return undefined;
		});
		let motor: unknown = reactLoose.useRef({ active: false, mode: "spin", base: 0, omega: WHEEL_OMEGA, startedAt: 0, lastSegment: 0, lastSoundAt: (-(luaProp(math, "huge") as unknown as number)) });
		let omegaRef: unknown = reactLoose.useRef(WHEEL_OMEGA);
		luaSet(omegaRef, "current", (((luaProp(antilag, "tier") as unknown as number) <= (1 as unknown as number)) ? WHEEL_OMEGA_LOW : WHEEL_OMEGA));
		let spinning: unknown = (((phase === "launch") || (phase === "coast")) || (phase === "brake"));
		let audioTicks: unknown = ((!luaTruthy(reducedMotion)) && ((luaProp(antilag, "fxBudget") as unknown as number) > (0.22 as unknown as number)));
		let audioTicksRef: unknown = reactLoose.useRef(audioTicks);
		luaSet(audioTicksRef, "current", audioTicks);
		let completeLanding: unknown = reactLoose.useCallback(function(this: void, result?: unknown, finalRotation?: unknown): unknown | undefined {
			if (((!luaTruthy(luaProp(mounted, "current"))) || (!luaTruthy(luaProp(busy, "current"))))) {
				return undefined;
			}
			let normalized: unknown = luaCall(positiveModulo, finalRotation, 360);
			luaSet(rotationValue, "current", normalized);
			luaSet(pointerKickValue, "current", 0);
			luaCall(setRotation, normalized);
			luaCall(setPointerKick, 0);
			luaCall(setSpinEnergy, 0);
			luaCall(setWinner, luaProp(result, "index"));
			luaCall(setImpactNonce, function(this: void, value?: unknown): unknown | undefined {
				return ((value as unknown as number) + (1 as unknown as number));
				return undefined;
			});
			luaCall(setPhase, "landed");
			luaSet(busy, "current", false);
			luaSet(pendingResult, "current", undefined);
			luaCall(pcall, function(this: void): unknown | undefined {
				luaCall(luaProp(mod("JuiceFx"), "live"), "wheel", undefined);
				return undefined;
			});
			colon(Audio).play("wheelLand");
			luaCall(luaProp(InteractionFeedback, "reward"));
			let _result: unknown = onLand;
			if ((_result !== undefined)) {
				luaCall(_result, luaProp(result, "message"));
			}
			return undefined;
		}, [onLand, setPointerKick, setRotation, setSpinEnergy]);
		let beginBrake: unknown = reactLoose.useCallback(function(this: void, result?: unknown): unknown | undefined {
			if (((!luaTruthy(luaProp(mounted, "current"))) || (!luaTruthy(luaProp(busy, "current"))))) {
				return undefined;
			}
			let wanted: unknown = luaCall(positiveModulo, ((360 as unknown as number) - (((luaProp(result, "index") as unknown as number) * (segment as unknown as number)) as unknown as number)), 360);
			if (luaTruthy(reducedMotion)) {
				colon(Audio).play("wheelBrake");
				luaCall(completeLanding, result, wanted);
				return undefined;
			}
			let now: unknown = (os.clock as unknown as (...a: unknown[]) => unknown)();
			let plan: unknown = luaProp(motor, "current");
			let current: unknown;
			let speed: unknown;
			[current, speed] = luaCall(sampleSpin, plan, ((now as unknown as number) - (luaProp(plan, "startedAt") as unknown as number))) as LuaTuple<[unknown, unknown]>;
			speed = (math.max as unknown as (...a: unknown[]) => unknown)(speed, 360);
			let delta: unknown = luaCall(positiveModulo, ((wanted as unknown as number) - (luaCall(positiveModulo, current, 360) as unknown as number)), 360);
			let overshoot: unknown = (math.min as unknown as (...a: unknown[]) => unknown)(WHEEL_OVERSHOOT_DEGREES, ((segment as unknown as number) * (0.3 as unknown as number)));
			// at least two full turns on the way down (three when the device has room for it)
			let distance: unknown = ((((((((luaProp(antilag, "tier") as unknown as number) <= (1 as unknown as number)) ? 720 : 1080)) as unknown as number) + (delta as unknown as number)) as unknown as number) + (overshoot as unknown as number));
			luaSet(motor, "current", { active: true, mode: "brake", base: current, omega: luaProp(plan, "omega"), distance: distance, overshoot: overshoot, duration: ((((4 as unknown as number) * (distance as unknown as number)) as unknown as number) / (speed as unknown as number)), startedAt: now, lastSegment: (math.floor as unknown as (...a: unknown[]) => unknown)((((((current as unknown as number) + (((segment as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (segment as unknown as number))), lastSoundAt: luaProp(plan, "lastSoundAt"), result: result });
			luaSet(rotationValue, "current", current);
			luaCall(setPhase, "brake");
			colon(Audio).play("wheelBrake");
			return undefined;
		}, [luaProp(antilag, "tier"), completeLanding, reducedMotion, segment]);
		luaSet(beginBrakeRef, "current", beginBrake);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(spinning))) {
				return undefined;
			}
			let connection: unknown = colon(luaProp(RunService, "RenderStepped")).Connect(function(this: void, deltaTime?: unknown): unknown | undefined {
				// the pointer springs back after each peg flicks it
				if (((luaProp(pointerKickValue, "current") as unknown as number) > (0 as unknown as number))) {
					luaSet(pointerKickValue, "current", (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(pointerKickValue, "current") as unknown as number) - (((deltaTime as unknown as number) * (9 as unknown as number)) as unknown as number))));
					luaCall(setPointerKick, luaProp(pointerKickValue, "current"));
				}
				let plan: unknown = luaProp(motor, "current");
				if ((!luaTruthy(luaProp(plan, "active")))) {
					return undefined;
				}
				let now: unknown = (os.clock as unknown as (...a: unknown[]) => unknown)();
				let elapsed: unknown = ((now as unknown as number) - (luaProp(plan, "startedAt") as unknown as number));
				let braking: unknown = (luaProp(plan, "mode") === "brake");
				let value: unknown;
				let speed: unknown;
				let settled: unknown;
				if (luaTruthy(braking)) {
					const [_set1, _set2, _set3] = luaCall(sampleBrake, plan, elapsed) as LuaTuple<[unknown, unknown, unknown]>;
					value = _set1;
					speed = _set2;
					settled = _set3;
				} else {
					const [_set4, _set5] = luaCall(sampleSpin, plan, elapsed) as LuaTuple<[unknown, unknown]>;
					value = _set4;
					speed = _set5;
				}
				luaSet(rotationValue, "current", value);
				luaCall(setRotation, value);
				let energy: unknown = (math.clamp as unknown as (...a: unknown[]) => unknown)(((speed as unknown as number) / (luaProp(plan, "omega") as unknown as number)), 0, 1);
				luaCall(setSpinEnergy, energy);
				// pegs sit on the segment edges; crossing one flicks the pointer and clicks
				let currentSegment: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)((((((value as unknown as number) + (((segment as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (segment as unknown as number)));
				if ((currentSegment !== luaProp(plan, "lastSegment"))) {
					luaSet(plan, "lastSegment", currentSegment);
					// a slow wheel gives the pointer time to swing further
					luaSet(pointerKickValue, "current", (math.max as unknown as (...a: unknown[]) => unknown)(luaProp(pointerKickValue, "current"), ((0.4 as unknown as number) + ((((((1 as unknown as number) - (energy as unknown as number))) as unknown as number) * (0.6 as unknown as number)) as unknown as number))));
					luaCall(setPointerKick, luaProp(pointerKickValue, "current"));
					let interval: unknown = (((energy as unknown as number) > (0.6 as unknown as number)) ? 0.055 : 0);
					if ((luaTruthy(luaProp(audioTicksRef, "current")) && ((((now as unknown as number) - (luaProp(plan, "lastSoundAt") as unknown as number)) as unknown as number) >= (interval as unknown as number)))) {
						luaSet(plan, "lastSoundAt", now);
						colon(Audio).play(((luaTruthy(braking) && ((energy as unknown as number) < (0.25 as unknown as number))) ? "wheelSlow" : "wheelTick"), ((0.86 as unknown as number) + (((energy as unknown as number) * (0.3 as unknown as number)) as unknown as number)));
					}
				}
				if ((!luaTruthy(braking))) {
					let result: unknown = luaProp(pendingResult, "current");
					if (((result !== undefined) && ((elapsed as unknown as number) >= (((((WHEEL_WINDUP_SECONDS as unknown as number) + (WHEEL_LAUNCH_SECONDS as unknown as number)) as unknown as number) + (WHEEL_MIN_CRUISE_SECONDS as unknown as number)) as unknown as number)))) {
						luaCall(luaProp(beginBrakeRef, "current"), result);
					}
					return undefined;
				}
				if (luaTruthy(settled)) {
					luaSet(plan, "active", false);
					luaCall(completeLanding, luaProp(plan, "result"), ((((luaProp(plan, "base") as unknown as number) + (luaProp(plan, "distance") as unknown as number)) as unknown as number) - (luaProp(plan, "overshoot") as unknown as number)));
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				return colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, [completeLanding, segment, setPointerKick, setRotation, setSpinEnergy, spinning]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			return function(this: void): unknown | undefined {
				luaSet(mounted, "current", false);
				luaSet(busy, "current", false);
				luaCall(pcall, function(this: void): unknown | undefined {
					luaCall(luaProp(mod("JuiceFx"), "live"), "wheel", undefined);
					return undefined;
				});
				luaSet(token, "current", ((luaProp(token, "current") as unknown as number) + (1 as unknown as number)));
				luaSet(luaProp(motor, "current"), "active", false);
				luaSet(luaProp(motor, "current"), "onComplete", undefined);
				if ((luaProp(timeout, "current") !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), luaProp(timeout, "current"));
				}
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((luaTruthy(luaProp(busy, "current")) || (!luaTruthy(receipt)))) {
				return;
			}
			if ((luaTruthy(unresolvedSpin) && (luaProp(unresolvedSpin, "ExpectedSpin") === luaProp(receipt, "ExpectedSpin")))) {
				unresolvedSpin = undefined;
			}
			if (luaTruthy(unresolvedSpin)) {
				return;
			}
			let index: unknown = luaCall(wheelPrizeIndex, luaProp(luaProp(config, "Wheel"), "Rewards"), luaProp(receipt, "PrizeIndex"), luaProp(receipt, "PrizeId"));
			if ((index === undefined)) {
				luaCall(setPhase, "error");
				luaCall(setFailure, "Your saved reward does not match this wheel. Refresh before spinning.");
				return;
			}
			let value: unknown = luaCall(positiveModulo, ((360 as unknown as number) - (((index as unknown as number) * (segment as unknown as number)) as unknown as number)), 360);
			luaSet(rotationValue, "current", value);
			luaCall(setRotation, value);
			luaCall(setWinner, index);
			luaCall(setFailure, undefined);
			luaCall(setPhase, "landed");
			return undefined;
		}, [receipt, spinning, luaProp(luaProp(config, "Wheel"), "Rewards"), segment, setRotation]);
		let spin: unknown = function(this: void): unknown | undefined {
			if ((luaTruthy(luaProp(busy, "current")) || (((!luaTruthy(unresolvedSpin)) && (!luaTruthy(luaProp(luaProp(state, "Wheel"), "CanSpin"))))))) {
				return undefined;
			}
			let order: unknown = ((luaTruthy(unresolvedSpin ) ? unresolvedSpin :  { ExpectedSpin: luaProp(luaProp(state, "Wheel"), "Spins") }));
			unresolvedSpin = order;
			luaSet(busy, "current", true);
			let requestToken: unknown = ((luaProp(token, "current") as unknown as number) + (1 as unknown as number));
			luaSet(token, "current", requestToken);
			luaSet(pendingResult, "current", undefined);
			luaSet(launchFinished, "current", false);
			luaSet(pointerKickValue, "current", 0);
			luaCall(setPointerKick, 0);
			luaCall(setWinner, -1);
			luaCall(setFailure, undefined);
			luaCall(setLaunchNonce, function(this: void, value?: unknown): unknown | undefined {
				return ((value as unknown as number) + (1 as unknown as number));
				return undefined;
			});
			colon(Audio).play("wheelStart");
			luaCall(luaProp(InteractionFeedback, "tap"));
			// the spin is pinned to the island until it lands (or 14 s at most)
			luaCall(pcall, function(this: void): unknown | undefined {
				luaCall(luaProp(mod("JuiceFx"), "live"), "wheel", { title: "Wheel spinning", value: "…", icon: "Wheel.6", color: luaProp(Palette, "mango"), ttl: 14, priority: 2 });
				return undefined;
			});
			if (luaTruthy(reducedMotion)) {
				luaSet(launchFinished, "current", true);
				luaSet(luaProp(motor, "current"), "active", false);
				luaCall(setPhase, "coast");
			} else {
				luaSet(motor, "current", { active: true, mode: "spin", base: luaProp(rotationValue, "current"), omega: luaProp(omegaRef, "current"), startedAt: (os.clock as unknown as (...a: unknown[]) => unknown)(), lastSegment: (math.floor as unknown as (...a: unknown[]) => unknown)((((((luaProp(rotationValue, "current") as unknown as number) + (((segment as unknown as number) / (2 as unknown as number)) as unknown as number))) as unknown as number) / (segment as unknown as number))), lastSoundAt: (-(luaProp(math, "huge") as unknown as number)) });
				luaCall(setPhase, "launch");
			}
			if ((luaProp(timeout, "current") !== undefined)) {
				luaCall(pcall, luaProp(task, "cancel"), luaProp(timeout, "current"));
			}
			luaSet(timeout, "current", (task.delay as unknown as (...a: unknown[]) => unknown)(12, function(this: void): unknown | undefined {
				luaSet(timeout, "current", undefined);
				if ((((!luaTruthy(luaProp(mounted, "current"))) || (luaProp(token, "current") !== requestToken)) || (!luaTruthy(luaProp(busy, "current"))))) {
					return undefined;
				}
				luaSet(token, "current", ((luaProp(token, "current") as unknown as number) + (1 as unknown as number)));
				luaSet(busy, "current", false);
				luaSet(pendingResult, "current", undefined);
				luaSet(luaProp(motor, "current"), "active", false);
				luaSet(pointerKickValue, "current", 0);
				luaCall(setPointerKick, 0);
				luaCall(setSpinEnergy, 0);
				luaCall(setPhase, "error");
				luaCall(setFailure, "No result yet. Confirm the previous spin to check its saved reward.");
				colon(Audio).play("requestTimeout");
				return undefined;
			}));
			luaCall(dispatch, "SpinWheel", order, function(this: void, response?: unknown): unknown | undefined {
				if (((luaProp(response, "Uncertain") !== true) && (unresolvedSpin === order))) {
					unresolvedSpin = undefined;
				}
				if (((!luaTruthy(luaProp(mounted, "current"))) || (luaProp(token, "current") !== requestToken))) {
					return undefined;
				}
				if ((luaProp(timeout, "current") !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), luaProp(timeout, "current"));
					luaSet(timeout, "current", undefined);
				}
				if (((!luaTruthy(luaProp(response, "ok"))) || (luaProp(response, "PrizeIndex") === undefined))) {
					luaSet(busy, "current", false);
					luaSet(pendingResult, "current", undefined);
					luaSet(luaProp(motor, "current"), "active", false);
					luaSet(pointerKickValue, "current", 0);
					luaCall(setPointerKick, 0);
					luaCall(setSpinEnergy, 0);
					luaCall(setPhase, "error");
					let _condition: unknown = (luaTruthy(luaProp(response, "Uncertain")) ? "Connection interrupted. Confirm the previous spin before starting another." : luaProp(response, "error"));
					if ((_condition === undefined)) {
						_condition = "The draw could not be completed.";
					}
					luaCall(setFailure, _condition);
					colon(Audio).play("error");
					return undefined;
				}
				let resultIndex: unknown = luaCall(wheelPrizeIndex, luaProp(luaProp(config, "Wheel"), "Rewards"), luaProp(response, "PrizeIndex"), luaProp(response, "PrizeId"));
				if ((resultIndex === undefined)) {
					luaSet(busy, "current", false);
					luaSet(luaProp(motor, "current"), "active", false);
					luaCall(setPhase, "error");
					luaCall(setFailure, "Your reward was saved, but its artwork is unavailable. Reopen the wheel to refresh.");
					return;
				}
				let result: unknown = { index: resultIndex, message: luaProp(response, "message") };
				luaSet(pendingResult, "current", result);
				if (luaTruthy(reducedMotion)) {
					luaCall(luaProp(beginBrakeRef, "current"), result);
				}
				return undefined;
			});
			return undefined;
		};
		return { phase: phase, spinning: spinning, winner: winner, failure: failure, retry: (unresolvedSpin !== undefined), launchNonce: launchNonce, impactNonce: impactNonce, rotation: rotation, pointerKick: pointerKick, spinEnergy: spinEnergy, spin: spin };
		return undefined;
	}
	function PrizeWheelMachine(props?: unknown): unknown | undefined {
		return reactLoose.createElement(mod("PrizeWheel"), props);
		return undefined;
	}
	function WheelConsole(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let controller: unknown = luaProp(_param, "controller");
		let onSpin: unknown = luaProp(_param, "onSpin");
		let height: unknown = luaProp(_param, "height");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let spinClaimHostRef: unknown = luaProp(_param, "spinClaimHostRef");
		let compact: unknown = luaProp(_param, "compact");
		if ((compact === undefined)) {
			compact = false;
		}
		let prize: unknown = (((luaProp(controller, "winner") as unknown as number) >= (0 as unknown as number)) ? luaIndex(luaProp(luaProp(config, "Wheel"), "Rewards"), ((luaProp(controller, "winner") as unknown as number) + (1 as unknown as number))) : undefined);
		let canSpin: unknown = ((luaProp(luaProp(state, "Wheel"), "CanSpin") === true) || luaProp(controller, "retry"));
		let _condition: unknown = luaProp(luaProp(state, "Wheel"), "PityMisses");
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let pityMisses: unknown = _condition;
		let _condition_1: unknown = luaProp(luaProp(state, "Wheel"), "PityAfter");
		if ((_condition_1 === undefined)) {
			_condition_1 = luaProp(luaProp(config, "Wheel"), "PityAfter");
			if ((_condition_1 === undefined)) {
				_condition_1 = 8;
			}
		}
		let pityAfter: unknown = _condition_1;
		let pityArmed: unknown = ((luaProp(luaProp(state, "Wheel"), "PityArmed") === true) || ((((pityMisses as unknown as number) + (1 as unknown as number)) as unknown as number) >= (pityAfter as unknown as number)));
		let pityFill: unknown = (luaTruthy(pityArmed) ? 1 : (math.clamp as unknown as (...a: unknown[]) => unknown)(((pityMisses as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, pityAfter) as unknown as number)), 0, 1));
		let now: unknown = luaCall(useWallClock, (!luaTruthy(canSpin)));
		let cooldown: unknown = colon(now).map(function(this: void, timestamp?: unknown): unknown | undefined {
			return `Ready again in ${luaCall(clockText, (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(luaProp(state, "Wheel"), "ReadyAt") as unknown as number) - (timestamp as unknown as number))))}`;
			return undefined;
		});
		let status: unknown = (luaTruthy(luaProp(controller, "spinning")) ? "Spinning" : ((luaProp(controller, "failure") !== undefined) ? "Spin paused" : ((prize !== undefined) ? "You won" : (luaTruthy(canSpin) ? "Ready to spin" : "Cooling down"))));
		let _result: unknown;
		if ((luaProp(controller, "failure") !== undefined)) {
			_result = (luaTruthy(luaProp(controller, "retry")) ? "Confirm your previous spin" : "Spin unavailable");
		} else {
			let _result_1: unknown = prize;
			if ((_result_1 !== undefined)) {
				_result_1 = luaProp(_result_1, "Name");
			}
			let _condition_2: unknown = _result_1;
			if ((_condition_2 === undefined)) {
				_condition_2 = ((luaTruthy(luaProp(controller, "spinning")) ? "Spinning…" : (luaTruthy(canSpin) ? "Spin ready" : "Next spin soon")));
			}
			_result = _condition_2;
		}
		let title: unknown = _result;
		let _condition_2: unknown = luaProp(controller, "failure");
		if ((_condition_2 === undefined)) {
			let _result_1: unknown = prize;
			if ((_result_1 !== undefined)) {
				_result_1 = luaProp(_result_1, "ShortLabel");
			}
			_condition_2 = _result_1;
			if ((_condition_2 === undefined)) {
				let _result_2: unknown;
				if (luaTruthy(luaProp(controller, "spinning"))) {
					_result_2 = "";
				} else {
					let _result_3: unknown;
					if (luaTruthy(canSpin)) {
						let _condition_3: unknown = luaProp(luaProp(state, "Wheel"), "FreeSpins");
						if ((_condition_3 === undefined)) {
							_condition_3 = 0;
						}
						_result_3 = ((((_condition_3 as unknown as number) > (0 as unknown as number)) ? `${luaCall(compactNumber, luaProp(luaProp(state, "Wheel"), "FreeSpins"))} free spin${((luaProp(luaProp(state, "Wheel"), "FreeSpins") === 1) ? "" : "s")} ready.` : (luaTruthy(pityArmed) ? ((((((luaTruthy(luaProp(config, "ClientPageGuides") ) ?  luaProp(luaProp(config, "ClientPageGuides"), "Wheel") : luaProp(config, "ClientPageGuides"))) && luaProp(luaProp(luaProp(config, "ClientPageGuides"), "Wheel"), "PityArmed"))) || "Guarantee ready: your next spin lands Rare or better.")) : (luaTruthy(compact) ? "Tap once to spin." : ((((((luaTruthy(luaProp(config, "ClientPageGuides") ) ?  luaProp(luaProp(config, "ClientPageGuides"), "Wheel") : luaProp(config, "ClientPageGuides"))) && luaProp(luaProp(luaProp(config, "ClientPageGuides"), "Wheel"), "Ready"))) || "Tap Spin in the middle of the wheel."))))));
					} else {
						_result_3 = cooldown;
					}
					_result_2 = _result_3;
				}
				_condition_2 = _result_2;
			}
		}
		let detail: unknown = _condition_2;
		let _result_1: unknown;
		if ((luaProp(controller, "failure") !== undefined)) {
			_result_1 = luaProp(Palette, "coral");
		} else {
			let _result_2: unknown = prize;
			if ((_result_2 !== undefined)) {
				_result_2 = luaProp(_result_2, "Color");
			}
			let _condition_3: unknown = _result_2;
			if ((_condition_3 === undefined)) {
				_condition_3 = ((luaTruthy(canSpin) ? luaProp(Palette, "mango") : luaProp(Palette, "lineSoft")));
			}
			_result_1 = _condition_3;
		}
		let accent: unknown = _result_1;
		let edge: unknown = (luaTruthy(compact) ? 10 : 14);
		let iconBox: unknown = (luaTruthy(compact) ? 58 : 72);
		let iconInset: unknown = (luaTruthy(compact) ? 7 : 9);
		let prizeIcon: unknown = (luaTruthy(compact) ? 44 : 54);
		let copyX: unknown = (luaTruthy(compact) ? 78 : 98);
		let copyRight: unknown = (luaTruthy(compact) ? 88 : 112);
		let statsTop: unknown = (luaTruthy(compact) ? 176 : 156);
		let statsHeight: unknown = (luaTruthy(compact) ? 42 : 52);
		let buttonHeight: unknown = (luaTruthy(compact) ? 48 : 50);
		let buttonBottom: unknown = (luaTruthy(compact) ? 10 : 14);
		let _exp: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) });
		let _exp_1: unknown = reactLoose.createElement("uigradient", { Color: luaCall(surfaceGradient, luaProp(Palette, "panel"), 0.62), Rotation: 90 });
		let _exp_2: unknown = reactLoose.createElement("uistroke", { Color: accent, Thickness: 1, Transparency: 0.42 });
		let _exp_3: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.46, 0, 0, 3), Position: luaCall(luaProp(UDim2, "fromOffset"), edge, 0), BackgroundColor3: accent, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uigradient", { Transparency: new (NumberSequence as unknown as new (...args: unknown[]) => unknown)([new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(0, 0.06), new (NumberSequenceKeypoint as unknown as new (...args: unknown[]) => unknown)(1, 1)]) }));
		let _exp_4: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), iconBox, iconBox), Position: luaCall(luaProp(UDim2, "fromOffset"), edge, (luaTruthy(compact) ? 12 : 16)), BackgroundColor3: colon(luaCall(darken, accent, 0.76)).Lerp(luaProp(Palette, "panelRaised"), 0.42), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 14) }), reactLoose.createElement("uistroke", { Color: accent, Thickness: ((prize !== undefined) ? 2 : 1), Transparency: ((prize !== undefined) ? 0.08 : 0.46) }), ((prize !== undefined) ? reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), prizeIcon, prizeIcon), Position: luaCall(luaProp(UDim2, "fromOffset"), iconInset, iconInset), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Icon, { kind: luaCall(luaProp(_Icon, "rewardIconKind"), luaProp(prize, "Reward")), color: luaProp(prize, "Color"), accent: luaProp(prize, "Color"), size: prizeIcon, reducedMotion: true, clipSafe: true })) : reactLoose.createElement(Icon, { kind: "Wheel.7", color: luaProp(Palette, "cream"), accent: luaProp(Palette, "mango"), size: (luaTruthy(compact) ? 40 : 48), position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), reducedMotion: reducedMotion, clipSafe: true })));
		let _exp_5: unknown = reactLoose.createElement(Badge, { value: status, accent: accent, filled: ((prize !== undefined) || (luaProp(controller, "failure") !== undefined)), position: luaCall(luaProp(UDim2, "fromOffset"), copyX, (luaTruthy(compact) ? 12 : 16)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(copyRight as unknown as number)), 0, (luaTruthy(compact) ? 22 : 24)) });
		let _attributes: unknown = { value: title, size: (luaTruthy(compact) ? 15 : 18) };
		let _result_2: unknown;
		if ((luaProp(controller, "failure") !== undefined)) {
			_result_2 = luaProp(Palette, "coral");
		} else {
			let _result_3: unknown = prize;
			if ((_result_3 !== undefined)) {
				_result_3 = luaProp(_result_3, "Color");
			}
			let _condition_3: unknown = _result_3;
			if ((_condition_3 === undefined)) {
				_condition_3 = luaProp(Palette, "cream");
			}
			_result_2 = _condition_3;
		}
		luaSet(_attributes, "color", _result_2);
		luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
		luaSet(_attributes, "fit", false);
		luaSet(_attributes, "wrap", true);
		luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), copyX, (luaTruthy(compact) ? 38 : 44)));
		luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(copyRight as unknown as number)), 0, 42));
		let _exp_6: unknown = reactLoose.createElement(Text, _attributes);
		let _exp_7: unknown = reactLoose.createElement(Text, { value: detail, size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), copyX, (luaTruthy(compact) ? 82 : 88)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-(copyRight as unknown as number)), 0, (luaTruthy(compact) ? 84 : 60)) });
		let _exp_8: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 9) });
		let _exp_9: unknown = reactLoose.createElement("uistroke", { Color: luaProp(Palette, "lineSoft"), Thickness: 1, Transparency: 0.64 });
		let _attributes_1: unknown = {};
		let _condition_3: unknown = luaProp(luaProp(state, "Wheel"), "FreeSpins");
		if ((_condition_3 === undefined)) {
			_condition_3 = 0;
		}
		luaSet(_attributes_1, "value", (((_condition_3 as unknown as number) > (0 as unknown as number)) ? "Free spins" : "Total spins"));
		luaSet(_attributes_1, "size", 12);
		luaSet(_attributes_1, "color", luaProp(Palette, "muted"));
		luaSet(_attributes_1, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
		luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 10, 5));
		luaSet(_attributes_1, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 15));
		let _exp_10: unknown = reactLoose.createElement(Text, _attributes_1);
		let _attributes_2: unknown = {};
		let _condition_4: unknown = luaProp(luaProp(state, "Wheel"), "FreeSpins");
		if ((_condition_4 === undefined)) {
			_condition_4 = 0;
		}
		luaSet(_attributes_2, "value", luaCall(compactNumber, (((_condition_4 as unknown as number) > (0 as unknown as number)) ? luaProp(luaProp(state, "Wheel"), "FreeSpins") : luaProp(luaProp(state, "Wheel"), "Spins"))));
		luaSet(_attributes_2, "size", (luaTruthy(compact) ? 14 : 16));
		luaSet(_attributes_2, "color", luaProp(Palette, "cream"));
		luaSet(_attributes_2, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
		luaSet(_attributes_2, "position", luaCall(luaProp(UDim2, "fromOffset"), 10, (luaTruthy(compact) ? 21 : 23)));
		luaSet(_attributes_2, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, (luaTruthy(compact) ? 18 : 22)));
		return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), BackgroundColor3: luaProp(Palette, "ink"), BorderSizePixel: 0, ClipsDescendants: true }, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (((-(edge as unknown as number)) as unknown as number) * (2 as unknown as number)), 0, statsHeight), Position: luaCall(luaProp(UDim2, "fromOffset"), edge, statsTop), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.34, -5, 1, 0), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0 }, _exp_8, _exp_9, _exp_10, reactLoose.createElement(Text, _attributes_2)), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.66, -5, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.34, 5, 0, 0), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 9) }), reactLoose.createElement("uistroke", { Color: (luaTruthy(pityArmed) ? luaProp(Palette, "mango") : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: (luaTruthy(pityArmed) ? 0.28 : 0.64) }), reactLoose.createElement(Text, { value: "Guarantee", size: 12, color: (luaTruthy(pityArmed) ? luaProp(Palette, "mango") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 10, 5), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.65, -10, 0, 15) }), reactLoose.createElement(Text, { value: (luaTruthy(pityArmed) ? "Ready" : `${pityMisses} / ${pityAfter}`), size: 12, color: (luaTruthy(pityArmed) ? luaProp(Palette, "mango") : luaProp(Palette, "creamSoft")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.65, 0, 0, 5), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.35, -10, 0, 15) }), reactLoose.createElement(Meter, { value: pityFill, color: (luaTruthy(pityArmed) ? luaProp(Palette, "mango") : luaProp(Palette, "violet")), reducedMotion: reducedMotion, shimmer: pityArmed, position: luaCall(luaProp(UDim2, "fromOffset"), 10, (luaTruthy(compact) ? 27 : 31)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, (luaTruthy(compact) ? 6 : 7)) }))), reactLoose.createElement("frame", { Name: "WheelSpinClaimActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (((-(edge as unknown as number)) as unknown as number) * (2 as unknown as number)), 0, buttonHeight), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, edge, 1, (-((((buttonHeight as unknown as number) + (buttonBottom as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: spinClaimHostRef }, reactLoose.createElement(Button, { text: (luaTruthy(luaProp(controller, "spinning")) ? "Spinning..." : (luaTruthy(luaProp(controller, "retry")) ? "Confirm previous spin" : (luaTruthy(canSpin) ? ((luaTruthy(pityArmed) ? "Spin, rarity guaranteed" : "Spin prize wheel")) : "Next spin not ready"))), icon: "Wheel.8", onClick: onSpin, color: ((luaTruthy(canSpin) && (!luaTruthy(luaProp(controller, "spinning")))) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: ((luaTruthy(canSpin) && (!luaTruthy(luaProp(controller, "spinning")))) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion, disabled: ((luaTruthy(luaProp(controller, "spinning") ) ? luaProp(controller, "spinning") :  (!luaTruthy(canSpin)))), highlight: ((luaTruthy(canSpin ) ?  (!luaTruthy(luaProp(controller, "spinning"))) : canSpin)) })));
		return undefined;
	}
	let PRIZE_ROW_H: unknown = 84;
	function PrizeCatalogRow(_param?: unknown): unknown | undefined {
		let reward: unknown = luaProp(_param, "reward");
		let weightTotal: unknown = luaProp(_param, "weightTotal");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		let chance: unknown = (((weightTotal as unknown as number) > (0 as unknown as number)) ? (((((luaProp(reward, "Weight") as unknown as number) / (weightTotal as unknown as number))) as unknown as number) * (100 as unknown as number)) : 0);
		let iconKind: unknown = (luaTruthy(luaProp(reward, "Reward")) ? luaCall(luaProp(_Icon, "rewardIconKind"), luaProp(reward, "Reward")) : "Wheel");
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((PRIZE_ROW_H as unknown as number) - (6 as unknown as number))), accent: luaProp(reward, "Color"), background: luaProp(Palette, "panel"), padding: 10, reducedMotion: softMotion, clips: false }, reactLoose.createElement(IconTile, { kind: iconKind, accent: luaProp(reward, "Color"), size: 40, radius: 10, glow: ((luaProp(reward, "Rarity") === "Legendary") || (luaProp(reward, "Rarity") === "Exotic")), filled: true, reducedMotion: softMotion }), reactLoose.createElement(Text, { value: `${luaProp(_param, "index")}. ${((luaTruthy(luaProp(reward, "Name") ) ? luaProp(reward, "Name") :  luaProp(reward, "Id")))}`, size: 14, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 50, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -160, 0, 38) }), reactLoose.createElement(Text, { value: `${luaProp(reward, "Rarity")} · ${(string.format as unknown as (...a: unknown[]) => unknown)("%.1f", chance)}%`, size: 11, color: luaProp(reward, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, position: luaCall(luaProp(UDim2, "fromOffset"), 50, 42), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -160, 0, 18) }), reactLoose.createElement(Badge, { value: ((luaTruthy(luaProp(reward, "ShortLabel") ) ? luaProp(reward, "ShortLabel") :  luaCall(formatReward, luaProp(reward, "Reward")))), accent: luaProp(reward, "Color"), filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -100, 0, 6), size: luaCall(luaProp(UDim2, "fromOffset"), 100, 24) }));
		return undefined;
	}
	function WheelView(props?: unknown): unknown | undefined {
		let _binding: unknown = props;
		let state: unknown = luaProp(_binding, "state");
		let config: unknown = luaProp(_binding, "config");
		let reducedMotion: unknown = luaProp(_binding, "reducedMotion");
		let viewport: unknown = luaCall(useViewport);
		let pageWidth: unknown;
		let setPageWidth: unknown;
		[pageWidth, setPageWidth] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let availableWidth: unknown = ((luaTruthy(pageWidth ) ? pageWidth :  (math.max as unknown as (...a: unknown[]) => unknown)(100, ((luaProp(viewport, "width") as unknown as number) - (280 as unknown as number)))));
		let chrome: unknown = luaCall(chromeFor, viewport);
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let spinClaimHostRef: unknown = reactLoose.useRef(undefined);
		let controller: unknown = luaCall(useWheelController, props);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((((luaProp(luaProp(state, "Wheel"), "CanSpin") !== true) || luaTruthy(luaProp(controller, "spinning"))) || (!luaTruthy(luaProp(UserInputService, "GamepadEnabled"))))) {
				return undefined;
			}
			let host: unknown = luaProp(spinClaimHostRef, "current");
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
		}, [luaProp(luaProp(state, "Wheel"), "CanSpin"), luaProp(controller, "spinning")]);
		let rewards: unknown = luaProp(luaProp(config, "Wheel"), "Rewards");
		let landscape: unknown = ((luaTruthy(luaProp(chrome, "landscape") ) ? luaProp(chrome, "landscape") :  ((((luaProp(viewport, "width") as unknown as number) > (((luaProp(viewport, "height") as unknown as number) * (1.35 as unknown as number)) as unknown as number)) && ((luaProp(viewport, "height") as unknown as number) < (680 as unknown as number))))));
		let shortLandscape: unknown = ((((luaTruthy(landscape ) ?  ((luaProp(viewport, "width") as unknown as number) >= (480 as unknown as number)) : landscape)) && ((luaProp(viewport, "width") as unknown as number) < (900 as unknown as number))) && ((luaProp(viewport, "height") as unknown as number) <= (430 as unknown as number)));
		let split: unknown = ((!luaTruthy(luaProp(chrome, "contentStack"))) && ((availableWidth as unknown as number) >= (760 as unknown as number)));
		let narrowPortrait: unknown = ((!luaTruthy(landscape)) && ((luaProp(viewport, "width") as unknown as number) <= (360 as unknown as number)));
		let widthCap: unknown = (luaTruthy(split) ? ((((((availableWidth as unknown as number) * (0.48 as unknown as number)) as unknown as number) - (((luaProp(Layout, "cardPadding") as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (24 as unknown as number)) : ((((availableWidth as unknown as number) - (((luaProp(Layout, "cardPadding") as unknown as number) * (2 as unknown as number)) as unknown as number)) as unknown as number) - (24 as unknown as number)));
		let heightCap: unknown = (luaTruthy(shortLandscape) ? 240 : (luaTruthy(split) ? 420 : 360));
		let wheelDiameter: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)((luaTruthy(shortLandscape) ? (math.clamp as unknown as (...a: unknown[]) => unknown)((math.min as unknown as (...a: unknown[]) => unknown)(widthCap, heightCap), 190, 220) : (math.clamp as unknown as (...a: unknown[]) => unknown)((math.min as unknown as (...a: unknown[]) => unknown)(widthCap, heightCap), (luaTruthy(luaProp(chrome, "contentStack")) ? 140 : 180), (luaTruthy(split) ? 410 : 340))));
		wheelDiameter = (math.max as unknown as (...a: unknown[]) => unknown)(100, (math.min as unknown as (...a: unknown[]) => unknown)(wheelDiameter, widthCap));
		let headerH: unknown = (luaTruthy(shortLandscape) ? 74 : (luaTruthy(narrowPortrait) ? 100 : 92));
		let consoleH: unknown = ((luaTruthy(shortLandscape) || luaTruthy(luaProp(chrome, "contentStack"))) ? 300 : 280);
		let stageH: unknown = (luaTruthy(split) ? (math.max as unknown as (...a: unknown[]) => unknown)(((wheelDiameter as unknown as number) + (24 as unknown as number)), consoleH) : ((((wheelDiameter as unknown as number) + (40 as unknown as number)) as unknown as number) + (consoleH as unknown as number)));
		let panelH: unknown = ((((headerH as unknown as number) + (stageH as unknown as number)) as unknown as number) + (((luaProp(Layout, "cardPadding") as unknown as number) * (2 as unknown as number)) as unknown as number));
		// The legend shares the page scroll, so the wheel no longer needs to shrink
		// to make an artificial nested prize viewport fit above the fold.
		let headerReveal: unknown = luaCall(useStagger, 0, softMotion);
		let _result: unknown;
		if (((luaProp(controller, "winner") as unknown as number) >= (0 as unknown as number))) {
			let _result_1: unknown = luaIndex(rewards, ((luaProp(controller, "winner") as unknown as number) + (1 as unknown as number)));
			if ((_result_1 !== undefined)) {
				_result_1 = luaProp(_result_1, "Color");
			}
			let _condition: unknown = _result_1;
			if ((_condition === undefined)) {
				_condition = luaProp(Palette, "mango");
			}
			_result = _condition;
		} else {
			_result = luaProp(Palette, "mango");
		}
		let accent: unknown = _result;
		let headline: unknown = "The prize wheel";
		let descriptor: unknown = `${len(rewards)} prizes · free spin every ${luaCall(clockText, luaProp(luaProp(config, "Wheel"), "CooldownSeconds"))}`;
		let containedEffects: unknown = ((((luaTruthy(luaProp(chrome, "portrait") ) ? luaProp(chrome, "portrait") :  shortLandscape)) || ((luaProp(viewport, "width") as unknown as number) <= (420 as unknown as number))) || (((luaTruthy(landscape ) ?  ((luaProp(viewport, "height") as unknown as number) <= (480 as unknown as number)) : landscape))));
		let weightTotal: unknown = 0;
		for (const [_, reward] of pairs((rewards) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			weightTotal = ((weightTotal as unknown as number) + (((luaTruthy(luaProp(reward, "Weight") ) ? luaProp(reward, "Weight") :  0)) as unknown as number));
		}
		let recentSpins: unknown = {};
		for (const [_, entry] of pairs(((((luaTypeIs(luaProp(luaProp(state, "Wheel"), "History"), "table")) ? luaProp(luaProp(state, "Wheel"), "History") : {}))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let name: unknown = luaProp(entry, "PrizeId");
			for (const [index, reward] of pairs((rewards) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(reward, "Id") === luaProp(entry, "PrizeId"))) {
					name = `${index}. ${((luaTruthy(luaProp(reward, "Name") ) ? luaProp(reward, "Name") :  luaProp(reward, "Id")))}`;
				}
			}
			luaTable.insert(recentSpins, `${(os.date as unknown as (...a: unknown[]) => unknown)("%b %d, %H:%M", luaProp(entry, "At"))}   ${name}${(luaTruthy(luaProp(entry, "Pity")) ? "  (guaranteed)" : "")}`);
		}
		// One page scroll owns the complete legend: no clipped nested prize viewport.
		let prizeRows: unknown = { layout: reactLoose.createElement("uilistlayout", { SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }) };
		for (const [index, reward] of pairs((rewards) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(prizeRows, luaProp(reward, "Id"), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -6, 0, ((PRIZE_ROW_H as unknown as number) - (6 as unknown as number))), BackgroundTransparency: 1, LayoutOrder: index }, reactLoose.createElement(PrizeCatalogRow, { reward: reward, index: index, weightTotal: weightTotal, reducedMotion: softMotion })));
		}
		let prizeList: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, prizeRows);
		return reactLoose.createElement("frame", { Name: "WheelPage", Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, [luaProp(luaProp(React, "Change"), "AbsoluteSize") as never]: function(this: void, host?: unknown): unknown | undefined {
			let absoluteX: unknown = luaProp(luaProp(host, "AbsoluteSize"), "X");
			if ((!luaTypeIs(absoluteX, "number")) || ((absoluteX as unknown as number) <= (0 as unknown as number))) {
				return undefined;
			}
			let scale: unknown = (luaTruthy(colon(game.GetService("Workspace")).GetAttribute("AstralForgeVRCanvasWidth")) ? 1 : luaProp(Layout, "chromeScale"));
			if ((!luaTypeIs(scale, "number")) || ((scale as unknown as number) <= (0 as unknown as number))) {
				scale = 1;
			}
			let width: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((absoluteX as unknown as number) / (scale as unknown as number)));
			// Same width again must not schedule another render; a size fight retriggers AbsoluteSize.
			if ((((width as unknown as number) > (0 as unknown as number)) && (width !== pageWidth))) {
				luaCall(setPageWidth, width);
			}
			return undefined;
		} }, reactLoose.createElement(PageScaffold, { gap: (luaTruthy(luaProp(chrome, "contentStack")) ? 14 : 20), tailPad: luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), 40), scrollBarColor: accent, scrollBarThickness: 4, sections: [{ id: "wheel", height: panelH, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: accent, background: luaProp(Palette, "panelRaised"), padding: luaProp(Layout, "cardPadding"), reveal: headerReveal, reducedMotion: softMotion, clips: false }, reactLoose.createElement(Text, { value: "Prize wheel", size: 12, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(shortLandscape) ? 14 : 16)) }), reactLoose.createElement(Text, { value: headline, size: (luaTruthy(shortLandscape) ? 16 : (luaTruthy(luaProp(chrome, "contentStack")) ? 18 : 21)), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, wrap: narrowPortrait, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(shortLandscape) ? 14 : 18)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(narrowPortrait) ? 36 : (luaTruthy(shortLandscape) ? 22 : 28))) }), reactLoose.createElement(Text, { value: descriptor, size: 12, color: luaProp(Palette, "muted"), fit: false, wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(narrowPortrait) ? 57 : (luaTruthy(shortLandscape) ? 36 : 46))), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 30) }), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), wheelDiameter, wheelDiameter), Position: (luaTruthy(split) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, 0, 0, ((headerH as unknown as number) + (((stageH as unknown as number) / (2 as unknown as number)) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0, headerH)), AnchorPoint: (luaTruthy(split) ? new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5) : new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement(PrizeWheelMachine, { rewards: rewards, controller: controller, diameter: wheelDiameter, canSpin: (luaProp(luaProp(state, "Wheel"), "CanSpin") === true), reducedMotion: softMotion, containedEffects: containedEffects })), reactLoose.createElement("frame", { Size: (luaTruthy(split) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.48, -10, 0, consoleH) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, consoleH)), Position: (luaTruthy(split) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.52, 10, 0, ((headerH as unknown as number) + ((((((stageH as unknown as number) - (consoleH as unknown as number))) as unknown as number) / (2 as unknown as number)) as unknown as number))) : luaCall(luaProp(UDim2, "fromOffset"), 0, ((((headerH as unknown as number) + (wheelDiameter as unknown as number)) as unknown as number) + (40 as unknown as number)))), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(WheelConsole, { state: state, config: config, controller: controller, onSpin: luaProp(controller, "spin"), height: consoleH, reducedMotion: softMotion, spinClaimHostRef: spinClaimHostRef, compact: ((luaTruthy(shortLandscape ) ? shortLandscape :  luaProp(chrome, "contentStack"))) }))) }, { id: "recent-spins", height: ((44 as unknown as number) + ((((math.max as unknown as (...a: unknown[]) => unknown)(1, len(recentSpins)) as unknown as number) * (24 as unknown as number)) as unknown as number)), element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panel"), padding: 16, clips: false }, reactLoose.createElement(Text, { value: "Recent spins", size: 14, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }), reactLoose.createElement(Text, { value: ((len(recentSpins) === 0) ? "No spins yet. Your prizes will be listed here." : luaTable.concat(recentSpins, "\n")), size: 13, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (((math.max as unknown as (...a: unknown[]) => unknown)(1, len(recentSpins)) as unknown as number) * (24 as unknown as number))) })) }, { id: "prizes-label", height: 32, element: reactLoose.createElement(Text, { value: "Prizes · standard odds", size: 13, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }) }, { id: "prizes-odds", height: 64, element: reactLoose.createElement(Text, { value: `Numbers match the wheel. Guaranteed spins only land ${luaCall((function(this: void, r?: unknown): unknown | undefined {
			return concat((string.upper as unknown as (...a: unknown[]) => unknown)((string.sub as unknown as (...a: unknown[]) => unknown)(r, 1, 1)), (string.lower as unknown as (...a: unknown[]) => unknown)((string.sub as unknown as (...a: unknown[]) => unknown)(r, 2)));
			return undefined;
		}), ((luaTruthy(luaProp(luaProp(config, "Wheel"), "PityRarity") ) ? luaProp(luaProp(config, "Wheel"), "PityRarity") :  "Rare")))} or better.`, size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, 0) }) }, { id: "prizes", height: ((((PRIZE_ROW_H as unknown as number) * (len(rewards) as unknown as number)) as unknown as number) + (8 as unknown as number)), element: prizeList }] }));
		return undefined;
	}
	return { WheelView: WheelView };
	return undefined;
}
export = __member();
