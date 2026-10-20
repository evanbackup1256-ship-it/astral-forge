import { Dependency } from "@flamework/core";
import type { EffectFeedController } from "../../Controllers/EffectFeedController";
import React from "@rbxts/react";
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable, luaRequire, instChild, kit, mod, pinFirst } from "./viewRuntime";

/**
 * Profile-style hook for guild member rows. `userKey` is the Members key (stringified UserId).
 * Return an accent Color3 to tint the row; undefined keeps the Leader/Officer/Member colors.
 */
function guildMemberAccent(userKey: unknown): Color3 | undefined {
	const userId = tonumber(userKey);
	if (userId === undefined) {
		return undefined;
	}
	return ProfileStyle.fromPlayer(game.GetService("Players").GetPlayerByUserId(userId)).accent;
}

function __member(): unknown {
	let Players: unknown = colon(game).GetService("Players");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let PlayerMark: unknown = luaProp(kit("ArtKit", "Icon"), "PlayerMark");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _format: unknown = kit("CoreKit", "format");
	let clockText: unknown = luaProp(_format, "clockText");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let formatReward: unknown = luaProp(_format, "formatReward");
	let gteFlux: unknown = luaProp(_format, "gteFlux");
	let _motion: unknown = kit("MotionKit", "motion");
	let useEntrance: unknown = luaProp(_motion, "useEntrance");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let useWallClock: unknown = luaProp(_motion, "useWallClock");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let darken: unknown = luaProp(_theme, "darken");
	let ensureContrast: unknown = luaProp(_theme, "ensureContrast");
	let Layout: unknown = luaProp(_theme, "Layout");
	let Palette: unknown = luaProp(_theme, "Palette");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let EmptyState: unknown = luaProp(_ui, "EmptyState");
	let Meter: unknown = luaProp(_ui, "Meter");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SectionLabel: unknown = luaProp(_ui, "SectionLabel");
	let Text: unknown = luaProp(_ui, "Text");
	let Social: unknown = luaCall(luaRequire(instChild(instChild(instChild(game.GetService("ReplicatedStorage"), "AstralForge"), "Shared"), "SocialProgression")), luaRequire(instChild(instChild(instChild(game.GetService("ReplicatedStorage"), "AstralForge"), "Shared"), "OmegaMath")));
	let createRequest: unknown = mod("ActionRequest");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let Browse: unknown = mod("BrowseKit");
	let ChatText: unknown = kit("CoreKit", "chatText");
	let ROLE_RANK: unknown = { Leader: 0, Officer: 1, Member: 2 };
	let UPGRADE_ACCENTS: unknown = { ProductionBoost: luaProp(Palette, "coral"), VaultBoost: luaProp(Palette, "mango"), OfflineBoost: luaProp(Palette, "cyan"), AutomationBoost: luaProp(Palette, "mint"), TapBoost: luaProp(Palette, "violet") };
	function effectAtLevel(config?: unknown, level?: unknown): unknown | undefined {
		let safe: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, (math.floor as unknown as (...a: unknown[]) => unknown)(level));
		if (((safe as unknown as number) <= (0 as unknown as number))) {
			return 0;
		}
		let tiers: unknown = luaProp(config, "Tiers");
		if (((tiers === undefined) || (len(tiers) === 0))) {
			return ((safe as unknown as number) * (luaProp(config, "EffectPerLevel") as unknown as number));
		}
		let named: unknown = (math.min as unknown as (...a: unknown[]) => unknown)(safe, len(tiers));
		let total: unknown = 0;
		{
					let index: unknown = 0;
					let _shouldIncrement: unknown = false;
					while (true) {
						if (luaTruthy(_shouldIncrement)) {
							index = ((index as unknown as number) + (1 as unknown as number));
						} else {
							_shouldIncrement = true;
						}
						if ((!(((index as unknown as number) < (named as unknown as number))))) {
							break;
						}
						let tier: unknown = luaIndex(tiers, ((index as unknown as number) + (1 as unknown as number)));
						let effect: unknown = ((luaTypeIs(tier, "table")) ? luaProp(tier, "Effect") : undefined);
						total = ((total as unknown as number) + (((luaTypeIs(effect, "number")) ? effect : 0) as unknown as number));
					}
				}
		if (((safe as unknown as number) > (named as unknown as number))) {
			total = ((total as unknown as number) + ((((((safe as unknown as number) - (named as unknown as number))) as unknown as number) * (luaProp(config, "EffectPerLevel") as unknown as number)) as unknown as number));
		}
		return total;
		return undefined;
	}
	function costAtLevel(config?: unknown, level?: unknown): unknown | undefined {
		let tiers: unknown = luaProp(config, "Tiers");
		let nextIndex: unknown = ((level as unknown as number) + (1 as unknown as number));
		if ((((tiers !== undefined) && ((nextIndex as unknown as number) >= (1 as unknown as number))) && ((nextIndex as unknown as number) <= (len(tiers) as unknown as number)))) {
			let tierCost: unknown = luaProp(luaIndex(tiers, nextIndex), "Cost");
			if ((luaTypeIs(tierCost, "number"))) {
				return (math.floor as unknown as (...a: unknown[]) => unknown)(((tierCost as unknown as number) + (0.5 as unknown as number)));
			}
		}
		return (math.floor as unknown as (...a: unknown[]) => unknown)(((((luaProp(config, "BaseCost") as unknown as number) * (((luaProp(config, "CostScale") as unknown as number) ** ((math.max as unknown as (...a: unknown[]) => unknown)(0, level) as unknown as number)) as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
		return undefined;
	}
	function percentText(value?: unknown): unknown | undefined {
		let scaled: unknown = ((value as unknown as number) * (100 as unknown as number));
		if ((((scaled as unknown as number) >= (10 as unknown as number)) || (((scaled as unknown as number) % (1 as unknown as number)) === 0))) {
			return `+${(math.floor as unknown as (...a: unknown[]) => unknown)(((scaled as unknown as number) + (0.5 as unknown as number)))}%`;
		}
		return `+${(string.format as unknown as (...a: unknown[]) => unknown)("%.1f", scaled)}%`;
		return undefined;
	}
	function buildUpgradeRows(config?: unknown, guild?: unknown): unknown | undefined {
		let guildConfig: unknown = luaProp(config, "Guild");
		if ((guildConfig === undefined)) {
			return {};
		}
		let order: unknown = ((luaTruthy(luaProp(guildConfig, "UpgradeOrder") ) ? luaProp(guildConfig, "UpgradeOrder") :  {}));
		let ids: unknown = {};
		for (const [_, id] of pairs((order) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaIndex(luaProp(guildConfig, "Upgrades"), id) !== undefined)) {
				luaTable.insert(ids, id);
			}
		}
		for (const [id] of pairs((luaProp(guildConfig, "Upgrades")) as object)) {
			if ((!((luaTable.find(ids, id) !== undefined)))) {
				luaTable.insert(ids, id);
			}
		}
		let rows: unknown = {};
		for (const [_, id] of pairs((ids) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let upgrade: unknown = luaIndex(luaProp(guildConfig, "Upgrades"), id);
			let _condition: unknown = luaIndex(luaProp(guild, "Upgrades"), id);
			if ((_condition === undefined)) {
				_condition = 0;
			}
			let level: unknown = _condition;
			let maxed: unknown = ((level as unknown as number) >= (luaProp(upgrade, "MaxLevel") as unknown as number));
			let cost: unknown = luaCall(costAtLevel, upgrade, level);
			let bank: unknown = ((luaProp(upgrade, "Currency") === "Cash") ? luaProp(guild, "BankCash") : luaProp(guild, "BankDust"));
			let tiers: unknown = luaProp(upgrade, "Tiers");
			let _result: unknown = tiers;
			if ((_result !== undefined)) {
				_result = len(_result);
			}
			let _condition_1: unknown = _result;
			if ((_condition_1 === undefined)) {
				_condition_1 = 0;
			}
			let tierCount: unknown = _condition_1;
			let _arg0: unknown = { id: id, config: upgrade, level: level, cost: cost, currentEffect: luaCall(effectAtLevel, upgrade, level), nextEffect: luaCall(effectAtLevel, upgrade, ((level as unknown as number) + (1 as unknown as number))), tierName: (((((level as unknown as number) > (0 as unknown as number)) && (tiers !== undefined)) && ((level as unknown as number) <= (tierCount as unknown as number))) ? luaProp(luaIndex(tiers, level), "Name") : (((level as unknown as number) > (0 as unknown as number)) ? "Endless" : "Not installed")), nextTierName: (((tiers !== undefined) && ((level as unknown as number) < (tierCount as unknown as number))) ? luaProp(luaIndex(tiers, ((level as unknown as number) + (1 as unknown as number))), "Name") : undefined), tierIndex: (math.min as unknown as (...a: unknown[]) => unknown)(level, tierCount), tierCount: tierCount, affordable: ((!luaTruthy(maxed)) && luaCall(gteFlux, bank, cost)), maxed: maxed, accent: ((luaTruthy(luaIndex(UPGRADE_ACCENTS, id) ) ? luaIndex(UPGRADE_ACCENTS, id) :  luaProp(Palette, "violet"))) };
			luaTable.insert(rows, _arg0);
		}
		return rows;
		return undefined;
	}
	function goalConfigFor(config?: unknown, typeId?: unknown): unknown | undefined {
		let _result: unknown = luaProp(config, "Guild");
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Goal");
			if ((_result !== undefined)) {
				_result = luaProp(_result, "Types");
			}
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = {};
		}
		for (const [_, entry] of pairs((_condition) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaProp(entry, "Id") === typeId)) {
				return entry;
			}
		}
		return undefined;
		return undefined;
	}
	function goalUnitLabel(metric?: unknown): unknown | undefined {
		if ((metric === "ContributeCash")) {
			return "Flux banked";
		}
		if ((metric === "ContributeDust")) {
			return "dust banked";
		}
		return "upgrades bought";
		return undefined;
	}
	function GuildGoalCardReady(_param?: unknown): unknown | undefined {
		let guild: unknown = luaProp(_param, "guild");
		let config: unknown = luaProp(_param, "config");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let busy: unknown = luaProp(_param, "busy");
		let shakeToken: unknown = luaProp(_param, "shakeToken");
		let goal: unknown = luaProp(guild, "Goal");
		let now: unknown = luaCall(useWallClock, (goal !== undefined));
		let localKey: unknown = tostring(luaProp(luaProp(Players, "LocalPlayer"), "UserId"));
		let definition: unknown = luaCall(goalConfigFor, config, luaProp(goal, "TypeId"));
		let fill: unknown = (math.clamp as unknown as (...a: unknown[]) => unknown)(((luaProp(goal, "Progress") as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, luaProp(goal, "Target")) as unknown as number)), 0, 1);
		let _condition: unknown = luaIndex(luaProp(goal, "Contributors"), localKey);
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let mine: unknown = _condition;
		let _result: unknown = luaProp(config, "Guild");
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Goal");
			if ((_result !== undefined)) {
				_result = luaProp(_result, "MinContributionForReward");
			}
		}
		let _condition_1: unknown = _result;
		if ((_condition_1 === undefined)) {
			_condition_1 = 1;
		}
		let helped: unknown = ((mine as unknown as number) >= (_condition_1 as unknown as number));
		let claimed: unknown = (luaIndex(luaProp(goal, "Claimed"), localKey) === true);
		let canClaim: unknown = (((luaTruthy(luaProp(goal, "Completed") ) ?  helped : luaProp(goal, "Completed"))) && (!luaTruthy(claimed)));
		let accent: unknown = (luaTruthy(luaProp(goal, "Completed")) ? luaProp(Palette, "mint") : luaProp(Palette, "mango"));
		let surface: unknown = luaCall(darken, accent, 0.9);
		let height: unknown = (luaTruthy(stack) ? 234 : 196);
		let claimHostRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((!luaTruthy(canClaim)) || (!luaTruthy(luaProp(UserInputService, "GamepadEnabled"))))) {
				return undefined;
			}
			let host: unknown = luaProp(claimHostRef, "current");
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
		}, [canClaim, luaProp(goal, "TypeId"), luaProp(goal, "Completed")]);
		let _exp: unknown = reactLoose.createElement(Text, { value: (luaTruthy(luaProp(goal, "Completed")) ? "GUILD GOAL • COMPLETE" : "GUILD GOAL"), size: 10, color: luaCall(ensureContrast, surface, accent), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -120, 0, 14) });
		let _attributes: unknown = {};
		let _result_1: unknown = definition;
		if ((_result_1 !== undefined)) {
			_result_1 = luaProp(_result_1, "Name");
		}
		let _condition_2: unknown = _result_1;
		if ((_condition_2 === undefined)) {
			_condition_2 = "Shared objective";
		}
		luaSet(_attributes, "value", _condition_2);
		luaSet(_attributes, "size", (luaTruthy(stack) ? 20 : 25));
		luaSet(_attributes, "color", luaCall(ensureContrast, surface, luaProp(Palette, "cream")));
		luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
		luaSet(_attributes, "fit", true);
		luaSet(_attributes, "minSize", 15);
		luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, 18));
		luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 32));
		let _exp_1: unknown = reactLoose.createElement(Text, _attributes);
		let _attributes_1: unknown = {};
		let _result_2: unknown = definition;
		if ((_result_2 !== undefined)) {
			_result_2 = luaProp(_result_2, "Description");
		}
		let _condition_3: unknown = _result_2;
		if ((_condition_3 === undefined)) {
			_condition_3 = "Work together to finish this goal.";
		}
		luaSet(_attributes_1, "value", _condition_3);
		luaSet(_attributes_1, "size", 11);
		luaSet(_attributes_1, "color", luaCall(ensureContrast, surface, luaProp(Palette, "creamSoft")));
		luaSet(_attributes_1, "wrap", true);
		luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 50 : 52)));
		luaSet(_attributes_1, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 30));
		let _exp_2: unknown = reactLoose.createElement(Text, _attributes_1);
		let _exp_3: unknown = reactLoose.createElement(Text, { value: colon(now).map(function(this: void, timestamp?: unknown): unknown | undefined {
			return (((luaProp(goal, "EndsAt") as unknown as number) > (timestamp as unknown as number)) ? `${luaCall(clockText, (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(goal, "EndsAt") as unknown as number) - (timestamp as unknown as number))))} LEFT` : "WINDOW CLOSED");
			return undefined;
		}), size: 10, color: luaCall(ensureContrast, surface, luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -150, 0, 0), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 150, 16) });
		let _exp_4: unknown = reactLoose.createElement(Meter, { value: fill, color: accent, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 0, (luaTruthy(stack) ? 92 : 94)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 9), reducedMotion: reducedMotion, shimmer: luaProp(goal, "Completed") });
		let _attributes_2: unknown = {};
		let _exp_5: unknown = luaCall(compactNumber, luaProp(goal, "Progress"));
		let _exp_6: unknown = luaCall(compactNumber, luaProp(goal, "Target"));
		let _result_3: unknown = definition;
		if ((_result_3 !== undefined)) {
			_result_3 = luaProp(_result_3, "Metric");
		}
		let _condition_4: unknown = _result_3;
		if ((_condition_4 === undefined)) {
			_condition_4 = "";
		}
		luaSet(_attributes_2, "value", `${_exp_5} / ${_exp_6} ${luaCall(goalUnitLabel, _condition_4)}`);
		luaSet(_attributes_2, "size", 10);
		luaSet(_attributes_2, "color", luaCall(ensureContrast, surface, luaProp(Palette, "creamSoft")));
		luaSet(_attributes_2, "fit", true);
		luaSet(_attributes_2, "minSize", 8);
		luaSet(_attributes_2, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 106 : 108)));
		luaSet(_attributes_2, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16));
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), accent: accent, background: surface, padding: 16, layoutOrder: layoutOrder, highlight: canClaim, reducedMotion: reducedMotion, clips: false }, _exp, _exp_1, _exp_2, _exp_3, _exp_4, reactLoose.createElement(Text, _attributes_2), reactLoose.createElement(Text, { value: (((mine as unknown as number) > (0 as unknown as number)) ? `YOU HELPED WITH ${luaCall(compactNumber, mine)}` : "YOU HAVE NOT HELPED YET"), size: 10, color: luaCall(ensureContrast, surface, (((mine as unknown as number) > (0 as unknown as number)) ? luaProp(Palette, "mint") : luaProp(Palette, "muted"))), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 126 : 128)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -170), 0, 16) }), ((definition !== undefined) && reactLoose.createElement(Text, { value: `REWARD  ${luaCall(formatReward, luaProp(definition, "Reward"))}`, size: 10, color: luaCall(ensureContrast, surface, luaProp(Palette, "muted")), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 146 : 148)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -170), 0, 16) })), reactLoose.createElement("frame", { Name: "GuildClaimActions", Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 46) : luaCall(luaProp(UDim2, "fromOffset"), 160, 46)), Position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -46) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -160, 1, -46)), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: (luaTruthy(canClaim) ? claimHostRef : undefined) }, reactLoose.createElement(Button, { text: (luaTruthy(claimed) ? "CLAIMED" : (luaTruthy(canClaim) ? "CLAIM REWARD" : (luaTruthy(luaProp(goal, "Completed")) ? "NOT ELIGIBLE" : "NOT YET"))), icon: (luaTruthy(claimed) ? "Check.13" : "Gift.9"), onClick: function(this: void): unknown | undefined {
			if ((luaTruthy(canClaim) && (!luaTruthy(busy)))) {
				luaCall(dispatch, "ClaimGuildGoal", {});
			}
			return undefined;
		}, color: (luaTruthy(canClaim) ? luaProp(Palette, "mint") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canClaim) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), disabled: ((!luaTruthy(canClaim)) || busy), loading: ((luaTruthy(canClaim ) ?  busy : canClaim)), shakeToken: (luaTruthy(canClaim) ? shakeToken : 0), highlight: canClaim, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })));
		return undefined;
	}
	function GuildGoalCard(_param?: unknown): unknown | undefined {
		let guild: unknown = luaProp(_param, "guild");
		let config: unknown = luaProp(_param, "config");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let busy: unknown = luaProp(_param, "busy");
		let shakeToken: unknown = luaProp(_param, "shakeToken");
		let goal: unknown = luaProp(guild, "Goal");
		let now: unknown = luaCall(useWallClock, (goal !== undefined));
		let localKey: unknown = tostring(luaProp(luaProp(Players, "LocalPlayer"), "UserId"));
		if ((goal === undefined)) {
			return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 116), accent: luaProp(Palette, "mint"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? 16 : 18), layoutOrder: layoutOrder, reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: "GUILD GOAL", size: 10, color: luaProp(Palette, "mint"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) }), reactLoose.createElement(Text, { value: "The next shared goal is being drawn up.", size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 22), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 34) }));
		}
		return reactLoose.createElement(GuildGoalCardReady, _param);
		return undefined;
	}
	function UpgradeCard(_param?: unknown): unknown | undefined {
		let row: unknown = luaProp(_param, "row");
		let guild: unknown = luaProp(_param, "guild");
		let canBuy: unknown = luaProp(_param, "canBuy");
		let stack: unknown = luaProp(_param, "stack");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let busy: unknown = luaProp(_param, "busy");
		let shakeToken: unknown = luaProp(_param, "shakeToken");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let currencyLabel: unknown = ((luaProp(luaProp(row, "config"), "Currency") === "Cash") ? "flux" : "dust");
		let bank: unknown = ((luaProp(luaProp(row, "config"), "Currency") === "Cash") ? luaProp(guild, "BankCash") : luaProp(guild, "BankDust"));
		let fill: unknown = (luaTruthy(luaProp(row, "maxed")) ? 1 : (math.clamp as unknown as (...a: unknown[]) => unknown)(((bank as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, luaProp(row, "cost")) as unknown as number)), 0, 1));
		let actionable: unknown = (((luaTruthy(canBuy ) ?  luaProp(row, "affordable") : canBuy)) && (!luaTruthy(luaProp(row, "maxed"))));
		let height: unknown = (luaTruthy(stack) ? 180 : 140);
		let _exp: unknown = reactLoose.createElement(Text, { value: luaProp(luaProp(row, "config"), "Name"), size: (luaTruthy(stack) ? 15 : 17), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 12, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -90 : -260), 0, 22) });
		let _exp_1: unknown = reactLoose.createElement(Badge, { value: (((luaProp(row, "tierCount") as unknown as number) > (0 as unknown as number)) ? `TIER ${luaProp(row, "tierIndex")}/${luaProp(row, "tierCount")}` : `LV ${luaCall(compactNumber, luaProp(row, "level"))}`), accent: luaProp(row, "accent"), filled: ((luaProp(row, "level") as unknown as number) > (0 as unknown as number)), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -84 : -254), 0, 0), size: luaCall(luaProp(UDim2, "fromOffset"), 84, 24) });
		let _exp_2: unknown = reactLoose.createElement(Text, { value: luaProp(luaProp(row, "config"), "Description"), size: 10, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -260), 0, 28) });
		let _attributes: unknown = {};
		let _result: unknown;
		if (luaTruthy(luaProp(row, "maxed"))) {
			_result = `${luaCall(percentText, luaProp(row, "currentEffect"))}, fully installed`;
		} else {
			let _exp_3: unknown = luaCall(percentText, luaProp(row, "currentEffect"));
			let _exp_4: unknown = luaCall(percentText, luaProp(row, "nextEffect"));
			let _condition: unknown = luaProp(row, "nextTierName");
			if ((_condition === undefined)) {
				_condition = "the next level";
			}
			_result = `${_exp_3} now  →  ${_exp_4} at ${_condition}`;
		}
		luaSet(_attributes, "value", _result);
		luaSet(_attributes, "size", 11);
		luaSet(_attributes, "color", (luaTruthy(luaProp(row, "maxed")) ? luaProp(Palette, "mint") : luaProp(Palette, "creamSoft")));
		luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Bold"));
		luaSet(_attributes, "fit", true);
		luaSet(_attributes, "minSize", 8);
		luaSet(_attributes, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 58 : 60)));
		luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -260), 0, 18));
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), accent: luaProp(row, "accent"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? 14 : 16), layoutOrder: layoutOrder, interactive: actionable, highlight: actionable, reducedMotion: reducedMotion, clips: false }, _exp, _exp_1, _exp_2, reactLoose.createElement(Text, _attributes), reactLoose.createElement(Meter, { value: fill, color: luaProp(row, "accent"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 82 : 84)), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -260), 0, 6), reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: (luaTruthy(luaProp(row, "maxed")) ? "MAXED" : `BANK ${luaCall(compactNumber, bank)} / ${luaCall(compactNumber, luaProp(row, "cost"))} ${currencyLabel}`), size: 10, color: (luaTruthy(luaProp(row, "affordable")) ? luaProp(Palette, "mint") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 96 : 98)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? 0 : -260), 0, 16) }), reactLoose.createElement(Button, { text: (luaTruthy(luaProp(row, "maxed")) ? "MAXED" : (luaTruthy(luaProp(row, "affordable")) ? `BUY ${luaCall(compactNumber, luaProp(row, "cost"))}` : "NEED MORE")), icon: (luaTruthy(luaProp(row, "maxed")) ? "Check.14" : "Forge.15"), onClick: function(this: void): unknown | undefined {
			if ((luaTruthy(actionable) && (!luaTruthy(busy)))) {
				luaCall(dispatch, "BuyGuildUpgrade", { Id: luaProp(row, "id") });
			}
			return undefined;
		}, color: (luaTruthy(actionable) ? luaProp(row, "accent") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(actionable) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), disabled: ((!luaTruthy(actionable)) || busy), loading: ((luaTruthy(actionable ) ?  busy : actionable)), shakeToken: (luaTruthy(actionable) ? shakeToken : 0), highlight: actionable, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 44) : luaCall(luaProp(UDim2, "fromOffset"), 240, 44)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -44) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -240, 1, -44)), reducedMotion: reducedMotion }));
		return undefined;
	}
	// Phones: the group you're scrolling through (You, Leader, Officers, Members) stays pinned to the
	// top of the member list until the next group pushes it off.
	const STICKY_H = 24;
	function StickyGroupLabel(props: { groups: { top: number; label: string; color: Color3 }[]; height: number }) {
		const hostRef = React.useRef<Frame>();
		const [offset, setOffset] = React.useBinding(0);
		const [current, setCurrent] = React.useState(0);
		const groupsRef = React.useRef(props.groups);
		groupsRef.current = props.groups;
		React.useEffect(() => {
			const host = hostRef.current;
			const container = host?.Parent as GuiObject | undefined;
			const scroller = host?.FindFirstAncestorWhichIsA("ScrollingFrame");
			if (host === undefined || container === undefined || scroller === undefined) {
				return undefined;
			}
			const update = () => {
				const scrolled = scroller.AbsolutePosition.Y - container.AbsolutePosition.Y;
				setOffset(math.clamp(scrolled, 0, math.max(0, props.height - STICKY_H)));
				const groups = groupsRef.current;
				let index = 0;
				for (let i = 0; i < groups.size(); i++) {
					if (groups[i].top <= scrolled + STICKY_H) {
						index = i;
					}
				}
				setCurrent(index);
			};
			update();
			const connection = scroller.GetPropertyChangedSignal("CanvasPosition").Connect(update);
			return () => connection.Disconnect();
		}, [props.height]);
		const group = props.groups[math.min(current, props.groups.size() - 1)];
		return reactLoose.createElement(
			"frame",
			{
				ref: hostRef,
				Size: new UDim2(1, 0, 0, STICKY_H),
				Position: offset.map((y) => UDim2.fromOffset(0, y)),
				BackgroundColor3: luaProp(Palette, "panelRaised") as Color3,
				BackgroundTransparency: 0.08,
				BorderSizePixel: 0,
				ZIndex: 20,
			},
			reactLoose.createElement("uicorner", { CornerRadius: new UDim(0, 6) }),
			reactLoose.createElement(Text as never, {
				value: group !== undefined ? group.label : "",
				size: 11,
				color: group !== undefined ? group.color : luaProp(Palette, "muted"),
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(10, 4),
				sizeConstraint: new UDim2(1, -20, 0, 16),
				zIndex: 21,
			}),
		);
	}
	// shared by MemberRow and the list height, so the section is exactly as tall as its rows
	function memberRowLayout(param: unknown): { manageable: boolean; height: number } {
		const canManage = luaProp(param, "canManage");
		const manageable = luaTruthy(canManage)
			? luaTruthy(luaCall(luaProp(Social, "canManage"), { Role: luaTruthy(luaProp(param, "myRole")) ? luaProp(param, "myRole") : "Leader" }, { Role: luaProp(param, "role") }, "Kick"))
			: false;
		const stack = luaTruthy(luaProp(param, "stack"));
		const height = stack && !manageable ? 60 : stack ? 122 : manageable ? 112 : 84;
		return { manageable, height };
	}
	function MemberRow(_param?: unknown): unknown | undefined {
		let userKey: unknown = luaProp(_param, "userKey");
		let name: unknown = luaProp(_param, "name");
		let role: unknown = luaProp(_param, "role");
		let contributed: unknown = luaProp(_param, "contributed");
		let goalShare: unknown = luaProp(_param, "goalShare");
		let share: unknown = luaProp(_param, "share");
		let isLocal: unknown = luaProp(_param, "isLocal");
		let canManage: unknown = luaProp(_param, "canManage");
		let isLeader: unknown = luaProp(_param, "isLeader");
		let stack: unknown = luaProp(_param, "stack");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let busy: unknown = luaProp(_param, "busy");
		let shakeToken: unknown = luaProp(_param, "shakeToken");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		// Profile-style hook: guildMemberAccent(userKey) may return a Color3; undefined keeps the role colors.
		let accent: unknown = guildMemberAccent(userKey) ?? ((role === "Leader") ? luaProp(Palette, "mango") : ((role === "Officer") ? luaProp(Palette, "cyan") : luaProp(Palette, "steel")));
		let surface: unknown = (luaTruthy(isLocal) ? luaCall(darken, luaProp(Palette, "green"), 0.88) : luaProp(Palette, "panel"));
		let _condition: unknown = tonumber(userKey);
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let userId: unknown = _condition;
		let manageable: unknown = memberRowLayout(_param).manageable;
		let canPromote: unknown = ((((luaTruthy(luaProp(_param, "myRole") ) ? luaProp(_param, "myRole") :  "Leader"))) === "Leader");
		// phones, rows you can't manage: one compact block (name, role on the right, one stats line)
		const compactRow = luaTruthy(stack) && !luaTruthy(manageable);
		let height: unknown = memberRowLayout(_param).height;
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), accent: (luaTruthy(isLocal) ? luaProp(Palette, "green") : accent), background: surface, padding: (luaTruthy(stack) ? 12 : 14), layoutOrder: layoutOrder, reducedMotion: reducedMotion, clips: false }, reactLoose.createElement(PlayerMark, { userId: userId, accent: accent, size: compactRow ? 28 : 34, position: luaCall(luaProp(UDim2, "fromOffset"), 0, compactRow ? 4 : 2) }), reactLoose.createElement(Text, { value: name, size: 14, color: luaCall(ensureContrast, surface, luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 10, position: luaCall(luaProp(UDim2, "fromOffset"), compactRow ? 38 : 44, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, compactRow ? (luaTruthy(isLocal) ? -38 - 118 : -38 - 70) : -44, 0, 20) }), reactLoose.createElement(Badge, { value: (string.upper as unknown as (...a: unknown[]) => unknown)(role), accent: accent, filled: ((role === "Leader") || (role === "Officer")), position: compactRow ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -64, 0, 2) : luaCall(luaProp(UDim2, "fromOffset"), 44, 20), size: luaCall(luaProp(UDim2, "fromOffset"), ((role === "Leader") ? 60 : (((role === "Officer") ? 64 : 58))), 16) }), ((luaTruthy(isLocal ) ?  reactLoose.createElement(Badge, { value: "YOU", accent: luaProp(Palette, "green"), filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, compactRow ? -114 : -48, 0, 2), size: luaCall(luaProp(UDim2, "fromOffset"), 44, compactRow ? 16 : 18) }) : isLocal)), reactLoose.createElement(Text, { value: `${luaCall(compactNumber, contributed)} banked  •  ${(math.floor as unknown as (...a: unknown[]) => unknown)(((((share as unknown as number) * (100 as unknown as number)) as unknown as number) + (0.5 as unknown as number)))}%${compactRow ? "" : " of all deposits"}${compactRow && (goalShare as number) > 0 ? `  •  ${luaCall(compactNumber, goalShare)} to goal` : ""}`, size: 10, color: luaCall(ensureContrast, surface, luaProp(Palette, "muted")), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), compactRow ? 38 : 44, compactRow ? 22 : 38), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -44 : -44), 0, 16) }), ((!compactRow && ((goalShare as unknown as number) > (0 as unknown as number))) && reactLoose.createElement(Text, { value: `${luaCall(compactNumber, goalShare)} toward this goal`, size: 9, color: luaCall(ensureContrast, surface, luaProp(Palette, "mint")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 44, 54), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -44 : -44), 0, 14) })), ((luaTruthy(manageable ) ?  reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Button, { text: ((!luaTruthy(canPromote)) ? "LEADER ONLY" : ((role === "Officer") ? "DEMOTE" : "PROMOTE")), onClick: function(this: void): unknown | undefined {
			if ((!luaTruthy(busy))) {
				luaCall(dispatch, "SetGuildRole", { UserId: userId, Role: ((role === "Officer") ? "Member" : "Officer") });
			}
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "creamSoft"), disabled: ((luaTruthy(busy ) ? busy :  (!luaTruthy(canPromote)))), loading: busy, shakeToken: shakeToken, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 40)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -40)), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: (luaTruthy(luaProp(_param, "confirmKick")) ? "CONFIRM KICK" : "KICK"), onClick: function(this: void): unknown | undefined {
			if ((!luaTruthy(busy))) {
				luaCall(dispatch, "KickGuildMember", { UserId: userId });
			}
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "coral"), disabled: busy, loading: busy, shakeToken: shakeToken, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -4, 0, 40)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 1, -40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 1, -40)), reducedMotion: reducedMotion })) : manageable)));
		return undefined;
	}
	function sanitizeGuildTag(value?: unknown): unknown | undefined {
		return (string.sub as unknown as (...a: unknown[]) => unknown)(((string.gsub as unknown as (...a: unknown[]) => unknown)((string.upper as unknown as (...a: unknown[]) => unknown)(value), "[^A-Z0-9]", "")), 1, 4);
		return undefined;
	}
	function JoinOrCreate(_param?: unknown): unknown | undefined {
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let busy: unknown = luaProp(_param, "busy");
		let shakeToken: unknown = luaProp(_param, "shakeToken");
		let stack: unknown = luaProp(_param, "stack");
		let cash: unknown = luaProp(_param, "cash");
		let name: unknown;
		let setName: unknown;
		[name, setName] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let tag: unknown;
		let setTag: unknown;
		[tag, setTag] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let joinTag: unknown;
		let setJoinTag: unknown;
		[joinTag, setJoinTag] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let nameRef: unknown = reactLoose.useRef(name);
		let tagRef: unknown = reactLoose.useRef(tag);
		let joinRef: unknown = reactLoose.useRef(joinTag);
		let _result: unknown = luaProp(config, "Guild");
		if ((_result !== undefined)) {
			_result = luaProp(_result, "CreateCost");
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = 5000;
		}
		let createCost: unknown = _condition;
		let canAfford: unknown = luaCall(gteFlux, cash, createCost);
		let canCharter: unknown = ((((!luaTruthy(busy)) && ((len(name) as unknown as number) >= (3 as unknown as number))) && ((len(tag) as unknown as number) >= (3 as unknown as number))) && canAfford);
		let canJoin: unknown = ((!luaTruthy(busy)) && ((len(joinTag) as unknown as number) >= (3 as unknown as number)));
		let fieldStyle: unknown = { BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0 };
		let charter: unknown = function(this: void): unknown | undefined {
			let nextName: unknown = ((string.gsub as unknown as (...a: unknown[]) => unknown)(((string.gsub as unknown as (...a: unknown[]) => unknown)(luaProp(nameRef, "current"), "^%s+", "")), "%s+$", ""));
			let nextTag: unknown = luaCall(sanitizeGuildTag, luaProp(tagRef, "current"));
			if ((((luaTruthy(busy) || ((len(nextName) as unknown as number) < (3 as unknown as number))) || ((len(nextTag) as unknown as number) < (3 as unknown as number))) || (!luaTruthy(canAfford)))) {
				return undefined;
			}
			luaCall(dispatch, "CreateGuild", { Name: nextName, Tag: nextTag });
			return undefined;
		};
		let join: unknown = function(this: void): unknown | undefined {
			let nextTag: unknown = luaCall(sanitizeGuildTag, luaProp(joinRef, "current"));
			if ((luaTruthy(busy) || ((len(nextTag) as unknown as number) < (3 as unknown as number)))) {
				return undefined;
			}
			luaCall(dispatch, "JoinGuild", { Tag: nextTag });
			return undefined;
		};
		let _exp: unknown = reactLoose.createElement(Text, { value: "CHARTER A GUILD", size: 10, color: luaProp(Palette, "violet"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) });
		let _exp_1: unknown = reactLoose.createElement(Text, { value: "Start your own hall", size: (luaTruthy(stack) ? 21 : 26), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 16, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 18), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 32) });
		let _exp_2: unknown = reactLoose.createElement(Text, { value: `Costs ${luaCall(compactNumber, createCost)} flux · you have ${luaCall(compactNumber, cash)}. You lead it and share every hall upgrade.`, size: 11, color: (luaTruthy(canAfford) ? luaProp(Palette, "creamSoft") : luaProp(Palette, "coral")), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 52), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 32) });
		let _attributes: unknown = { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 90), PlaceholderText: "Guild name (3-28 characters)", Text: name, ClearTextOnFocus: false, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			let value: unknown = luaCall(luaProp(ChatText, "cutBytes"), luaProp(box, "Text"), 28);
			luaSet(nameRef, "current", value);
			luaCall(setName, value);
			return undefined;
		} }, Event: { Focused: function(this: void): unknown | undefined {
			return colon(Audio).play("inputFocus");
			return undefined;
		} } };
		for (const [_k, _v] of pairs((fieldStyle) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_attributes, _k, _v);
		}
		let _exp_3: unknown = reactLoose.createElement("textbox", _attributes, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }));
		let _attributes_1: unknown = { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 138), PlaceholderText: "Tag (3-4 letters or numbers)", Text: tag, ClearTextOnFocus: false, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			let value: unknown = luaCall(sanitizeGuildTag, luaProp(box, "Text"));
			luaSet(tagRef, "current", value);
			luaCall(setTag, value);
			return undefined;
		} }, Event: { Focused: function(this: void): unknown | undefined {
			return colon(Audio).play("inputFocus");
			return undefined;
		} } };
		for (const [_k, _v] of pairs((fieldStyle) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_attributes_1, _k, _v);
		}
		let _exp_4: unknown = reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 276), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panelRaised"), padding: 18, layoutOrder: 1, reducedMotion: reducedMotion, clips: false }, _exp, _exp_1, _exp_2, _exp_3, reactLoose.createElement("textbox", _attributes_1, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) })), reactLoose.createElement(Button, { text: ((!luaTruthy(canAfford)) ? `NEED ${luaCall(compactNumber, createCost)} FLUX` : "CHARTER GUILD"), icon: "Forge.16", onClick: charter, color: (luaTruthy(canCharter) ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canCharter) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), disabled: (!luaTruthy(canCharter)), loading: ((luaTruthy(canAfford ) ?  busy : canAfford)), shakeToken: (luaTruthy(canAfford) ? shakeToken : 0), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(TapTarget as unknown as number))), reducedMotion: reducedMotion }));
		let _exp_5: unknown = reactLoose.createElement(Text, { value: "JOIN A GUILD", size: 10, color: luaProp(Palette, "mint"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) });
		let _exp_6: unknown = reactLoose.createElement(Text, { value: "Already know a tag? Type it in and jump into the hall.", size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 30) });
		let _attributes_2: unknown = { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 56), PlaceholderText: "Guild tag", Text: joinTag, ClearTextOnFocus: false, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			let value: unknown = luaCall(sanitizeGuildTag, luaProp(box, "Text"));
			luaSet(joinRef, "current", value);
			luaCall(setJoinTag, value);
			return undefined;
		} }, Event: { Focused: function(this: void): unknown | undefined {
			return colon(Audio).play("inputFocus");
			return undefined;
		} } };
		for (const [_k, _v] of pairs((fieldStyle) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_attributes_2, _k, _v);
		}
		return reactLoose.createElement(React.Fragment, undefined, _exp_4, reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 192), accent: luaProp(Palette, "mint"), padding: 18, layoutOrder: 2, reducedMotion: reducedMotion, clips: false }, _exp_5, _exp_6, reactLoose.createElement("textbox", _attributes_2, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) })), reactLoose.createElement(Button, { text: "JOIN GUILD", icon: "Crew.9", onClick: join, color: (luaTruthy(canJoin) ? luaProp(Palette, "mint") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canJoin) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), disabled: (!luaTruthy(canJoin)), loading: ((luaTruthy(canJoin ) ?  busy : canJoin)), shakeToken: (luaTruthy(canJoin) ? shakeToken : 0), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(TapTarget as unknown as number))), reducedMotion: reducedMotion })));
		return undefined;
	}
	function GuildCommunityPanel(_param?: unknown): unknown | undefined {
		let guild: unknown = luaProp(_param, "guild");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let stack: unknown = luaProp(_param, "stack");
		let role: unknown = luaProp(_param, "role");
		let onBack: unknown = luaProp(_param, "onBack");
		let guildConfig: unknown = ((((luaTruthy(luaProp(_param, "config") ) ?  luaProp(luaProp(_param, "config"), "Guild") : luaProp(_param, "config")))) || {});
		let community: unknown = ((luaTruthy(luaProp(guild, "Community") ) ? luaProp(guild, "Community") :  {}));
		let settings: unknown;
		let setSettings: unknown;
		[settings, setSettings] = reactLoose.useState(((luaTruthy(luaProp(community, "Settings") ) ? luaProp(community, "Settings") :  { ChatEnabled: true, AnnouncementsEnabled: true, LogoEnabled: true }))) as LuaTuple<[unknown, unknown]>;
		let messages: unknown;
		let setMessages: unknown;
		[messages, setMessages] = reactLoose.useState(((luaTruthy(luaProp(community, "Chat") ) ? luaProp(community, "Chat") :  {}))) as LuaTuple<[unknown, unknown]>;
		let announcements: unknown;
		let setAnnouncements: unknown;
		[announcements, setAnnouncements] = reactLoose.useState(((luaTruthy(luaProp(community, "Announcements") ) ? luaProp(community, "Announcements") :  {}))) as LuaTuple<[unknown, unknown]>;
		let logos: unknown;
		let setLogos: unknown;
		[logos, setLogos] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let chatDraft: unknown;
		let setChatDraft: unknown;
		[chatDraft, setChatDraft] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let announcementTitle: unknown;
		let setAnnouncementTitle: unknown;
		[announcementTitle, setAnnouncementTitle] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let announcementBody: unknown;
		let setAnnouncementBody: unknown;
		[announcementBody, setAnnouncementBody] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let logoAsset: unknown;
		let setLogoAsset: unknown;
		[logoAsset, setLogoAsset] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let moderationUserId: unknown;
		let setModerationUserId: unknown;
		[moderationUserId, setModerationUserId] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let renameName: unknown;
		let setRenameName: unknown;
		[renameName, setRenameName] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let renameTag: unknown;
		let setRenameTag: unknown;
		[renameTag, setRenameTag] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let chatScroll: unknown = reactLoose.useRef(undefined);
		let localUserId: unknown = luaProp(luaProp(colon(game).GetService("Players"), "LocalPlayer"), "UserId");
		let busy: unknown;
		let setBusy: unknown;
		[busy, setBusy] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let leader: unknown = (role === "Leader");
		let manager: unknown = ((luaTruthy(leader ) ? leader :  (role === "Officer")));
		let requestCommunity: unknown = reactLoose.useCallback(function(this: void): unknown | undefined {
			luaCall(dispatch, "GetGuildChatHistory", { Limit: 50 }, function(this: void, result?: unknown): unknown | undefined {
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(setMessages, ((luaTruthy(luaProp(result, "Messages") ) ? luaProp(result, "Messages") :  {})));
				}
				return undefined;
			});
			luaCall(dispatch, "GetGuildAnnouncements", {}, function(this: void, result?: unknown): unknown | undefined {
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(setAnnouncements, ((luaTruthy(luaProp(result, "Announcements") ) ? luaProp(result, "Announcements") :  {})));
				}
				return undefined;
			});
			luaCall(dispatch, "GetGuildSettings", {}, function(this: void, result?: unknown): unknown | undefined {
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(setSettings, ((luaTruthy(luaProp(result, "Settings") ) ? luaProp(result, "Settings") :  {})));
				}
				return undefined;
			});
			if (luaTruthy(leader)) {
				luaCall(dispatch, "GetGuildLogoReview", {}, function(this: void, result?: unknown): unknown | undefined {
					if (luaTruthy(luaProp(result, "ok"))) {
						luaCall(setLogos, ((luaTruthy(luaProp(result, "Logos") ) ? luaProp(result, "Logos") :  {})));
					}
					return undefined;
				});
			}
			return undefined;
		}, [dispatch, manager, luaProp(guild, "Id")]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(requestCommunity);
			let alive: unknown = true;
			let worker: unknown = (task.spawn as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				while (luaTruthy(alive)) {
					(task.wait as unknown as (...a: unknown[]) => unknown)(8);
					if (alive) {
						luaCall(requestCommunity);
					}
				}
				return undefined;
			});
			let connection: unknown = Dependency<EffectFeedController>().connect(function(this: void, packet?: unknown): unknown | undefined {
				if ((((!luaTruthy(alive)) || (!luaTypeIs(packet, "table"))) || (luaProp(packet, "GuildId") !== luaProp(guild, "Id")))) {
					return;
				}
				if (((luaProp(packet, "Type") === "GuildChat") && (luaTypeIs(luaProp(packet, "Message"), "table")))) {
					luaCall(setMessages, function(this: void, previous?: unknown): unknown | undefined {
						let updated: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(previous);
						for (const [_, existing] of pairs((updated) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
							if ((luaProp(existing, "Id") === luaProp(luaProp(packet, "Message"), "Id"))) {
								return previous;
							}
						}
						luaSetIndex(updated, ((len(updated) as unknown as number) + (1 as unknown as number)), luaProp(packet, "Message"));
						while (((len(updated) as unknown as number) > (50 as unknown as number))) {
							luaTable.remove(updated, 1);
						}
						return updated;
						return undefined;
					});
				} else if ((((((luaProp(packet, "Refresh") === true) || (luaProp(packet, "Type") === "GuildAnnouncement")) || (luaProp(packet, "Type") === "GuildSettings")) || (luaProp(packet, "Type") === "GuildLogo")) || (luaProp(packet, "Type") === "GuildModeration"))) {
					// Refresh: another server changed something too large to relay inline
					luaCall(requestCommunity);
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				alive = false;
				colon(connection).Disconnect();
				luaCall(pcall, luaProp(task, "cancel"), worker);
				return undefined;
			};
			return undefined;
		}, [requestCommunity, luaProp(guild, "Id")]);
		let run: unknown = function(this: void, action?: unknown, payload?: unknown, done?: unknown): unknown | undefined {
			if ((busy !== "")) {
				return;
			}
			luaCall(setBusy, action);
			luaCall(dispatch, action, payload, function(this: void, result?: unknown): unknown | undefined {
				luaCall(setBusy, "");
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(requestCommunity);
				}
				if (luaTruthy(done)) {
					luaCall(done, result);
				}
				return undefined;
			});
			return undefined;
		};
		let fieldStyle: unknown = { BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, ClearTextOnFocus: false, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")) };
		function input(placeholder?: unknown, value?: unknown, onChange?: unknown, height?: unknown, position?: unknown): unknown | undefined {
			return reactLoose.createElement("textbox", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((luaTruthy(height ) ? height :  42))), Position: ((luaTruthy(position ) ? position :  luaCall(luaProp(UDim2, "fromOffset"), 0, 0))), PlaceholderText: placeholder, Text: value, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
				luaCall(onChange, luaCall(luaProp(ChatText, "cutBytes"), luaProp(box, "Text"), 800));
				return undefined;
			} }, BackgroundColor3: luaProp(fieldStyle, "BackgroundColor3"), BorderSizePixel: luaProp(fieldStyle, "BorderSizePixel"), TextColor3: luaProp(fieldStyle, "TextColor3"), PlaceholderColor3: luaProp(fieldStyle, "PlaceholderColor3"), TextSize: luaProp(fieldStyle, "TextSize"), ClearTextOnFocus: false, FontFace: luaProp(fieldStyle, "FontFace") }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }));
			return undefined;
		}
		let ROLE_COLORS: unknown = { Leader: luaProp(Palette, "mango"), Officer: luaProp(Palette, "cyan"), Member: luaProp(Palette, "creamSoft") };
		let chatRows: unknown = {};
		let previousSpeaker: unknown = undefined;
		for (const [index, message] of pairs((messages) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let own: unknown = (luaProp(message, "SpeakerUserId") === localUserId);
			let grouped: unknown = (previousSpeaker === luaProp(message, "SpeakerUserId"));
			previousSpeaker = luaProp(message, "SpeakerUserId");
			let stamp: unknown = ((luaTypeIs(luaProp(message, "PublishedAt"), "number")) ? (os.date as unknown as (...a: unknown[]) => unknown)("%H:%M", luaProp(message, "PublishedAt")) : "");
			let roleColor: unknown = ((luaTruthy(luaIndex(ROLE_COLORS, luaProp(message, "SpeakerRole")) ) ? luaIndex(ROLE_COLORS, luaProp(message, "SpeakerRole")) :  luaProp(Palette, "creamSoft")));
			luaSetIndex(chatRows, ((len(chatRows) as unknown as number) + (1 as unknown as number)), reactLoose.createElement("frame", { key: ((luaTruthy(luaProp(message, "Id") ) ? luaProp(message, "Id") :  tostring(index))), LayoutOrder: index, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundTransparency: 1 }, reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, (luaTruthy(own) ? 40 : 0)), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, (luaTruthy(own) ? 0 : 40)), PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, (luaTruthy(grouped) ? 0 : 4)) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundColor3: (luaTruthy(own) ? luaProp(Palette, "cyan") : luaProp(Palette, "panelSoft")), BackgroundTransparency: (luaTruthy(own) ? 0.82 : 0.35), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) }), ((!luaTruthy(grouped)) && reactLoose.createElement("textlabel", { LayoutOrder: 1, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16), BackgroundTransparency: 1, Text: `${((luaTruthy(luaProp(message, "SpeakerName") ) ? luaProp(message, "SpeakerName") :  tostring(luaProp(message, "SpeakerUserId"))))}${((luaTruthy(luaProp(message, "SpeakerRole")) && (luaProp(message, "SpeakerRole") !== "Member")) ? concat("  ·  ", (string.upper as unknown as (...a: unknown[]) => unknown)(luaProp(message, "SpeakerRole"))) : "")}   ${stamp}`, TextColor3: roleColor, TextSize: 12, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")) })), reactLoose.createElement("textlabel", { LayoutOrder: 2, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundTransparency: 1, Text: tostring(((luaTruthy(luaProp(message, "Message") ) ? luaProp(message, "Message") :  ""))), TextColor3: luaProp(Palette, "cream"), TextSize: 14, TextWrapped: true, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")) }))));
		}
		if ((len(chatRows) === 0)) {
			luaSetIndex(chatRows, 1, reactLoose.createElement(Text, { key: "no-chat", value: "No messages yet. Chat is visible only to this guild's members.", size: 12, color: luaProp(Palette, "muted"), wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 34) }));
		}
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let frame: unknown = luaProp(chatScroll, "current");
			if ((frame === undefined)) {
				return undefined;
			}
			let job: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if (luaTruthy(luaProp(frame, "Parent"))) {
					luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(luaProp(frame, "AbsoluteCanvasSize"), "Y") as unknown as number) - (luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y") as unknown as number)))));
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, [len(messages)]);
		function sendChat(): unknown | undefined {
			if (((chatDraft === "") || (luaProp(settings, "ChatEnabled") === false))) {
				return;
			}
			luaCall(run, "SendGuildChat", { Content: chatDraft }, function(this: void, result?: unknown): unknown | undefined {
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(setChatDraft, "");
				}
				return undefined;
			});
			return undefined;
		}
		let announcementRows: unknown = {};
		for (const [index, item] of pairs((announcements) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let label: unknown = `${(luaTruthy(luaProp(item, "Pinned")) ? "[PINNED] " : "")}${luaProp(item, "Title")}  ·  ${((luaTruthy(luaProp(item, "AuthorName") ) ? luaProp(item, "AuthorName") :  "Guild staff"))}`;
			luaSetIndex(announcementRows, index, reactLoose.createElement(Panel, { key: luaProp(item, "Id"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 116), accent: (((luaTruthy(luaProp(item, "Pinned") ) ?  luaProp(Palette, "mango") : luaProp(item, "Pinned"))) || luaProp(Palette, "cyan")), padding: 12, reducedMotion: reducedMotion }, reactLoose.createElement(Text, { value: label, size: 13, weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 22) }), reactLoose.createElement(Text, { value: luaProp(item, "Body"), size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 52) }), ((luaTruthy(manager ) ?  reactLoose.createElement(Button, { text: (((luaTruthy(luaProp(item, "Pinned") ) ?  "UNPIN" : luaProp(item, "Pinned"))) || "PIN"), onClick: function(this: void): unknown | undefined {
				luaCall(run, "PinGuildAnnouncement", { AnnouncementId: luaProp(item, "Id"), Pinned: (!luaTruthy(luaProp(item, "Pinned"))) });
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 32), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -96, 1, -32), disabled: (busy !== ""), reducedMotion: reducedMotion }) : manager)), ((luaTruthy(manager ) ?  reactLoose.createElement(Button, { text: "ARCHIVE", onClick: function(this: void): unknown | undefined {
				luaCall(run, "ArchiveGuildAnnouncement", { AnnouncementId: luaProp(item, "Id") });
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "coral"), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 32), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -194, 1, -32), disabled: (busy !== ""), reducedMotion: reducedMotion }) : manager)), reactLoose.createElement(Text, { value: ((luaTypeIs(luaProp(item, "PublishedAt"), "number")) ? concat((os.date as unknown as (...a: unknown[]) => unknown)("%b %d · %H:%M", luaProp(item, "PublishedAt")), ((luaTruthy(luaProp(item, "EditedAt")) ? " · edited" : ""))) : ""), size: 10, color: luaProp(Palette, "muted"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -200, 0, 18) })));
		}
		if ((len(announcementRows) === 0)) {
			luaSetIndex(announcementRows, 1, reactLoose.createElement(Text, { key: "no-announcements", value: "Quiet for now. When a leader posts news, it shows up here.", size: 12, color: luaProp(Palette, "muted") }));
		}
		let logoRows: unknown = {};
		for (const [index, logo] of pairs((logos) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(logoRows, index, reactLoose.createElement(Panel, { key: luaProp(logo, "Id"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 84), accent: luaProp(Palette, "violet"), padding: 10 }, reactLoose.createElement("imagelabel", { Size: luaCall(luaProp(UDim2, "fromOffset"), 52, 52), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 0), BackgroundTransparency: 1, Image: ((luaTruthy(luaProp(logo, "URL") ) ? luaProp(logo, "URL") :  "")), ScaleType: luaProp(luaProp(Enum, "ScaleType"), "Fit") }), reactLoose.createElement(Text, { value: `Logo ${(string.sub as unknown as (...a: unknown[]) => unknown)(luaProp(logo, "Id"), 1, 8)} · pending`, size: 12, fit: true, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -220, 0, 22) }), reactLoose.createElement(Button, { text: "APPROVE", onClick: function(this: void): unknown | undefined {
				luaCall(run, "ModerateGuildLogo", { LogoId: luaProp(logo, "Id"), Decision: "approved" });
				return undefined;
			}, color: luaProp(Palette, "mint"), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 34), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -196, 0, 12), disabled: (busy !== ""), reducedMotion: reducedMotion }), reactLoose.createElement(Button, { text: "REJECT", onClick: function(this: void): unknown | undefined {
				luaCall(run, "ModerateGuildLogo", { LogoId: luaProp(logo, "Id"), Decision: "rejected", Reason: "Did not meet guild logo guidelines." });
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "coral"), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 34), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -98, 0, 12), disabled: (busy !== ""), reducedMotion: reducedMotion })));
		}
		let settingsRows: unknown = {};
		if (luaTruthy(leader)) {
			let SETTING_LABELS: unknown = { ChatEnabled: "CHAT", AnnouncementsEnabled: "NEWS", LogoEnabled: "LOGOS", OfficerAnnouncements: "OFFICER NEWS", OfficerModeration: "OFFICER MODS", SlowMode: "SLOW MODE" };
			for (const [index, key] of pairs((["ChatEnabled", "AnnouncementsEnabled", "LogoEnabled", "OfficerAnnouncements", "OfficerModeration", "SlowMode"]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let enabled: unknown = ((key === "SlowMode") ? (luaIndex(settings, key) === true) : (luaIndex(settings, key) !== false));
				luaSetIndex(settingsRows, index, reactLoose.createElement(Button, { key: key, text: `${luaIndex(SETTING_LABELS, key)}  ${(luaTruthy(enabled) ? "ON" : "OFF")}`, onClick: function(this: void): unknown | undefined {
					let updated: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(settings);
					luaSetIndex(updated, key, (!luaTruthy(enabled)));
					luaCall(setSettings, updated);
					luaCall(run, "SetGuildSettings", { Settings: { [key as never]: luaIndex(updated, key) } });
					return undefined;
				}, color: (luaTruthy(enabled) ? luaProp(Palette, "mint") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(enabled) ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), -6, 0, 42), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) % (3 as unknown as number))) as unknown as number) / (3 as unknown as number)), 0, 0, (((math.floor as unknown as (...a: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) / (3 as unknown as number))) as unknown as number) * (48 as unknown as number))), disabled: (busy !== ""), reducedMotion: reducedMotion }));
			}
		}
		let sections: unknown = [{ id: "guild-community-back", height: 48, element: reactLoose.createElement(Button, { text: "‹  GUILD OVERVIEW", onClick: onBack, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 44), reducedMotion: reducedMotion }) }, { id: "guild-community-chat", height: 430, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "cyan"), padding: 14, reducedMotion: reducedMotion, clips: false }, reactLoose.createElement(Text, { value: `GUILD CHANNEL · ${len(messages)} MESSAGE${((len(messages) === 1) ? "" : "S")}${((luaProp(settings, "SlowMode") === true) ? " · SLOW MODE" : "")}`, size: 12, color: luaProp(Palette, "cyan"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }), reactLoose.createElement("scrollingframe", { ref: chatScroll, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 308), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), BackgroundColor3: luaProp(Palette, "void"), BackgroundTransparency: 0.35, BorderSizePixel: 0, CanvasSize: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(), AutomaticCanvasSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), ScrollingDirection: luaProp(luaProp(Enum, "ScrollingDirection"), "Y"), ScrollBarThickness: 3, ScrollBarImageColor3: luaProp(Palette, "cyan") }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), chatRows), reactLoose.createElement("textbox", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -112, 0, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 344), PlaceholderText: ((luaProp(settings, "ChatEnabled") === false) ? "Chat is disabled by the leader" : "Message your guild…  (Enter to send)"), Text: chatDraft, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			luaCall(setChatDraft, luaCall(luaProp(ChatText, "cutBytes"), luaProp(box, "Text"), 400));
			return undefined;
		} }, Event: { FocusLost: function(this: void, _?: unknown, enterPressed?: unknown): unknown | undefined {
			if (luaTruthy(enterPressed)) {
				luaCall(sendChat);
			}
			return undefined;
		} }, BackgroundColor3: luaProp(fieldStyle, "BackgroundColor3"), BorderSizePixel: 0, TextColor3: luaProp(fieldStyle, "TextColor3"), PlaceholderColor3: luaProp(fieldStyle, "PlaceholderColor3"), TextSize: luaProp(fieldStyle, "TextSize"), ClearTextOnFocus: false, TextEditable: (luaProp(settings, "ChatEnabled") !== false), FontFace: luaProp(fieldStyle, "FontFace") }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) })), reactLoose.createElement(Button, { text: "SEND", onClick: sendChat, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 104, 0, 42), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -104, 0, 344), disabled: (((busy !== "") || (luaProp(settings, "ChatEnabled") === false)) || (chatDraft === "")), loading: (busy === "SendGuildChat"), reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: `${len(chatDraft)}/400 · filtered by Roblox · members only`, size: 10, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 390), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) })) }, { id: "guild-community-announcements", height: (math.max as unknown as (...a: unknown[]) => unknown)(168, ((((len(announcementRows) as unknown as number) * (126 as unknown as number)) as unknown as number) + (((((luaTruthy(manager ) ?  164 : manager)) || 64)) as unknown as number))), element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement(SectionLabel, { value: "ANNOUNCEMENTS", color: luaProp(Palette, "mango") }), ((luaTruthy(manager ) ?  reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 154), accent: luaProp(Palette, "mango"), padding: 12, clips: false }, luaCall(input, "Announcement title", announcementTitle, function(this: void, value?: unknown): unknown | undefined {
			luaCall(setAnnouncementTitle, luaCall(luaProp(ChatText, "cutBytes"), value, 120));
			return undefined;
		}, 40, luaCall(luaProp(UDim2, "fromOffset"), 0, 0)), luaCall(input, "Announcement body", announcementBody, setAnnouncementBody, 46, luaCall(luaProp(UDim2, "fromOffset"), 0, 44)), reactLoose.createElement(Button, { text: "PUBLISH", onClick: function(this: void): unknown | undefined {
			luaCall(run, "CreateGuildAnnouncement", { Title: announcementTitle, Body: announcementBody }, function(this: void, result?: unknown): unknown | undefined {
				if (luaTruthy(luaProp(result, "ok"))) {
					luaCall(setAnnouncementTitle, "");
					luaCall(setAnnouncementBody, "");
				}
				return undefined;
			});
			return undefined;
		}, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -36), disabled: ((((busy !== "") || (luaProp(settings, "AnnouncementsEnabled") === false)) || (announcementTitle === "")) || (announcementBody === "")), reducedMotion: reducedMotion }), ((luaProp(settings, "AnnouncementsEnabled") === false) && reactLoose.createElement(Text, { value: "The guild leader turned announcements off.", size: 11, minSize: 9, fit: true, color: luaProp(Palette, "coral"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, -16) }))) : manager)), announcementRows) }];
		if (luaTruthy(manager)) {
			let moderationButtons: unknown = {};
			for (const [index, action] of pairs((["MuteGuildMember", "BanGuildMember", "UnmuteGuildMember", "UnbanGuildMember"]) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let labels: unknown = { MuteGuildMember: "MUTE", BanGuildMember: "BAN", UnmuteGuildMember: "UNMUTE", UnbanGuildMember: "UNBAN" };
				let colors: unknown = { MuteGuildMember: luaProp(Palette, "mango"), BanGuildMember: luaProp(Palette, "coral"), UnmuteGuildMember: luaProp(Palette, "cyan"), UnbanGuildMember: luaProp(Palette, "violet") };
				luaSetIndex(moderationButtons, index, reactLoose.createElement(Button, { key: action, text: luaIndex(labels, action), onClick: function(this: void): unknown | undefined {
					let id: unknown = tonumber(moderationUserId);
					if ((luaTruthy(id) && ((id as unknown as number) > (0 as unknown as number)))) {
						luaCall(run, action, { UserId: (math.floor as unknown as (...a: unknown[]) => unknown)(id) });
					}
					return undefined;
				}, color: luaIndex(colors, action), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -6, 0, 40), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) * (0.25 as unknown as number)), 0, 0, 0), disabled: ((busy !== "") || (tonumber(moderationUserId) === undefined)), reducedMotion: reducedMotion }));
			}
			luaTable.insert(sections, { id: "guild-community-moderation", height: 146, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "coral"), padding: 14, clips: false }, reactLoose.createElement(SectionLabel, { value: "MEMBER MODERATION · USER ID", color: luaProp(Palette, "coral") }), luaCall(input, "Guild member user ID", moderationUserId, function(this: void, value?: unknown): unknown | undefined {
				luaCall(setModerationUserId, (string.sub as unknown as (...a: unknown[]) => unknown)(value, 1, 20));
				return undefined;
			}, 42, luaCall(luaProp(UDim2, "fromOffset"), 0, 28)), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 76), BackgroundTransparency: 1 }, moderationButtons)) });
		}
		if (luaTruthy(leader)) {
			luaTable.insert(sections, { id: "guild-community-settings", height: 160, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), padding: 14 }, reactLoose.createElement(SectionLabel, { value: "GUILD RULES", color: luaProp(Palette, "violet") }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 90), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 26), BackgroundTransparency: 1 }, settingsRows), reactLoose.createElement(Text, { value: "Choose what officers can manage. Slow mode adds 6 seconds between member messages.", size: 11, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 116), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) })) });
			let cooldownDays: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((((tonumber(luaProp(guildConfig, "RenameCooldownSeconds")) || 604800)) as unknown as number) / (86400 as unknown as number)));
			let renameReady: unknown = (((len(renameName) as unknown as number) >= (3 as unknown as number)) || ((len(renameTag) as unknown as number) >= (3 as unknown as number)));
			luaTable.insert(sections, { id: "guild-community-rename", height: 178, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "mango"), padding: 14, clips: false }, reactLoose.createElement(SectionLabel, { value: `RENAME · NOW ${(string.upper as unknown as (...a: unknown[]) => unknown)(tostring(((luaTruthy(luaProp(guild, "Name") ) ? luaProp(guild, "Name") :  ""))))} [${((luaTruthy(luaProp(guild, "Tag") ) ? luaProp(guild, "Tag") :  "?"))}]`, color: luaProp(Palette, "mango") }), reactLoose.createElement("textbox", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.7, -6, 0, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), PlaceholderText: "New guild name (3–28)", Text: renameName, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), Change: { Text: function(this: void, box?: unknown): unknown | undefined {
				luaCall(setRenameName, luaCall(luaProp(ChatText, "cutBytes"), luaProp(box, "Text"), 28));
				return undefined;
			} }, BackgroundColor3: luaProp(fieldStyle, "BackgroundColor3"), BorderSizePixel: 0, TextColor3: luaProp(fieldStyle, "TextColor3"), PlaceholderColor3: luaProp(fieldStyle, "PlaceholderColor3"), TextSize: luaProp(fieldStyle, "TextSize"), ClearTextOnFocus: false, FontFace: luaProp(fieldStyle, "FontFace") }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) })), reactLoose.createElement("textbox", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.3, 0, 0, 42), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.7, 0, 0, 28), PlaceholderText: "TAG", Text: renameTag, Change: { Text: function(this: void, box?: unknown): unknown | undefined {
				luaCall(setRenameTag, (string.upper as unknown as (...a: unknown[]) => unknown)((string.sub as unknown as (...a: unknown[]) => unknown)(((string.gsub as unknown as (...a: unknown[]) => unknown)(luaProp(box, "Text"), "[^%w]", "")), 1, 4)));
				return undefined;
			} }, BackgroundColor3: luaProp(fieldStyle, "BackgroundColor3"), BorderSizePixel: 0, TextColor3: luaProp(fieldStyle, "TextColor3"), PlaceholderColor3: luaProp(fieldStyle, "PlaceholderColor3"), TextSize: luaProp(fieldStyle, "TextSize"), ClearTextOnFocus: false, FontFace: luaProp(fieldStyle, "FontFace") }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) })), reactLoose.createElement(Button, { text: "RENAME GUILD", onClick: function(this: void): unknown | undefined {
				let nextName: unknown = (((len(renameName) as unknown as number) >= (3 as unknown as number)) ? renameName : tostring(((luaTruthy(luaProp(guild, "Name") ) ? luaProp(guild, "Name") :  ""))));
				luaCall(run, "RenameGuild", { Name: nextName, Tag: (((len(renameTag) as unknown as number) >= (3 as unknown as number)) ? renameTag : undefined) }, function(this: void, result?: unknown): unknown | undefined {
					if (luaTruthy(luaProp(result, "ok"))) {
						luaCall(setRenameName, "");
						luaCall(setRenameTag, "");
					}
					return undefined;
				});
				return undefined;
			}, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 78), disabled: ((busy !== "") || (!luaTruthy(renameReady))), loading: (busy === "RenameGuild"), reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: `Costs ${tostring(((luaTruthy(luaProp(guildConfig, "RenameCost") ) ? luaProp(guildConfig, "RenameCost") :  10000)))} flux · once every ${cooldownDays} days · names are filtered`, size: 10, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 124), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) })) });
		}
		if (luaTruthy(manager)) {
			let activeLogo: unknown = luaProp(community, "Logo");
			let logoPreview: unknown = (((luaTruthy(activeLogo ) ?  luaProp(activeLogo, "URL") : activeLogo)) && reactLoose.createElement("imagelabel", { Size: luaCall(luaProp(UDim2, "fromOffset"), 56, 56), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -60, 0, 0), BackgroundTransparency: 1, Image: luaProp(activeLogo, "URL"), ScaleType: luaProp(luaProp(Enum, "ScaleType"), "Fit") }));
			luaTable.insert(sections, { id: "guild-community-logo", height: ((164 as unknown as number) + (((len(logoRows) as unknown as number) * (94 as unknown as number)) as unknown as number)), element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), padding: 14, clips: false }, reactLoose.createElement(SectionLabel, { value: "ROBLOX IMAGE LOGO · REVIEW REQUIRED", color: luaProp(Palette, "violet") }), logoPreview, luaCall(input, "Roblox image asset ID", logoAsset, setLogoAsset, 42, luaCall(luaProp(UDim2, "fromOffset"), 0, 28)), reactLoose.createElement(Button, { text: "SUBMIT FOR REVIEW", onClick: function(this: void): unknown | undefined {
				luaCall(run, "UploadGuildLogo", { URL: logoAsset }, function(this: void, result?: unknown): unknown | undefined {
					if (luaTruthy(luaProp(result, "ok"))) {
						luaCall(setLogoAsset, "");
					}
					return undefined;
				});
				return undefined;
			}, color: luaProp(Palette, "violet"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 38), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 76), disabled: (((busy !== "") || (luaProp(settings, "LogoEnabled") === false)) || (logoAsset === "")), reducedMotion: reducedMotion }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((len(logoRows) as unknown as number) * (90 as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 120), BackgroundTransparency: 1 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), logoRows)) });
		}
		return reactLoose.createElement(PageScaffold, { gap: 10, tailPad: luaCall(scrollTail, stack, 0, 72), scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: 4, sections: sections });
		return undefined;
	}
	function GuildView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let stack: unknown = luaProp(chrome, "contentStack");
		let enter: unknown = luaCall(useEntrance, softMotion);
		let reveal: unknown = luaCall(useStagger, 0, softMotion);
		let bankReveal: unknown = luaCall(useStagger, 1, softMotion);
		let membersReveal: unknown = luaCall(useStagger, 2, softMotion);
		let goalReveal: unknown = luaCall(useStagger, 3, softMotion);
		let _: unknown;
		let refreshRequest: unknown;
		[_, refreshRequest] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let request: unknown = reactLoose.useMemo(function(this: void): unknown | undefined {
			return luaCall(createRequest, dispatch, luaProp(task, "delay"), function(this: void): unknown | undefined {
				luaCall(refreshRequest, function(this: void, v?: unknown): unknown | undefined {
					return ((v as unknown as number) + (1 as unknown as number));
					return undefined;
				});
				return undefined;
			});
			return undefined;
		}, [dispatch]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaSet(request, "alive", true);
			return function(this: void): unknown | undefined {
				luaCall(luaProp(request, "dispose"));
				return undefined;
			};
			return undefined;
		}, [request]);
		let busy: unknown = luaProp(request, "busy");
		let confirmation: unknown = reactLoose.useRef(undefined);
		let pane: unknown;
		let setPane: unknown;
		[pane, setPane] = reactLoose.useState(((luaTruthy(luaProp(_param, "initialTab") ) ? luaProp(_param, "initialTab") :  "Overview"))) as LuaTuple<[unknown, unknown]>;
		let shakeToken: unknown;
		let setShakeToken: unknown;
		[shakeToken, setShakeToken] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let contributeCash: unknown;
		let setContributeCash: unknown;
		[contributeCash, setContributeCash] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let contributeDust: unknown;
		let setContributeDust: unknown;
		[contributeDust, setContributeDust] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		// member search lives above the no-guild early return so hook order never changes
		let memberQuery: unknown;
		let setMemberQuery: unknown;
		[memberQuery, setMemberQuery] = luaCall(luaProp(Browse, "useLinkedQuery"), "GuildMembers") as LuaTuple<[unknown, unknown]>;
		let memberRole: unknown;
		let setMemberRole: unknown;
		[memberRole, setMemberRole] = reactLoose.useState("All") as LuaTuple<[unknown, unknown]>;
		let guild: unknown = luaProp(state, "Guild");
		let localPlayer: unknown = luaProp(Players, "LocalPlayer");
		let localKey: unknown = ((localPlayer !== undefined) ? tostring(luaProp(localPlayer, "UserId")) : "");
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(dispatch, "GetGuild", {});
			return undefined;
		}, [dispatch]);
		let send: unknown = function(this: void, action?: unknown, payload?: unknown, callback?: unknown): unknown | undefined {
			if (luaTruthy(luaProp(request, "busy"))) {
				return false;
			}
			if ((((action === "LeaveGuild") || (action === "DisbandGuild")) || (action === "KickGuildMember"))) {
				let key: unknown = concat(action, concat(":", tostring((((luaTruthy(payload ) ?  luaProp(payload, "UserId") : payload)) || ""))));
				if ((((!luaTruthy(luaProp(confirmation, "current"))) || (luaProp(luaProp(confirmation, "current"), "key") !== key)) || (((os.clock as unknown as (...a: unknown[]) => unknown)() as unknown as number) > (luaProp(luaProp(confirmation, "current"), "untilTime") as unknown as number)))) {
					luaSet(confirmation, "current", { key: key, untilTime: (((os.clock as unknown as (...a: unknown[]) => unknown)() as unknown as number) + (8 as unknown as number)) });
					luaSet(request, "status", "Press the same action again within 8 seconds to confirm. Leaving a guild does not refund contributions.");
					luaCall(refreshRequest, function(this: void, v?: unknown): unknown | undefined {
						return ((v as unknown as number) + (1 as unknown as number));
						return undefined;
					});
					return false;
				}
			}
			luaSet(confirmation, "current", undefined);
			return luaCall(luaProp(request, "run"), action, payload, function(this: void, response?: unknown): unknown | undefined {
				if ((!luaTruthy(luaProp(response, "ok")))) {
					luaCall(setShakeToken, function(this: void, token?: unknown): unknown | undefined {
						return ((token as unknown as number) + (1 as unknown as number));
						return undefined;
					});
				}
				if (luaTruthy(callback)) {
					luaCall(callback, response);
				}
				return undefined;
			});
			return undefined;
		};
		// the result of the last guild action; the panel only exists while there is one to show
		function statusSection(): unknown | undefined {
			if ((luaProp(request, "status") === "")) {
				return undefined;
			}
			return { id: "guild-feedback", height: 72, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), padding: 16, accent: luaProp(Palette, "cyan") }, reactLoose.createElement(Text, { value: luaProp(request, "status"), size: 13, wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) })) };
			return undefined;
		}
		function withStatus(list?: unknown, at?: unknown): unknown | undefined {
			let status: unknown = luaCall(statusSection);
			if (luaTruthy(status)) {
				luaTable.insert(list, at, status);
			}
			return list;
			return undefined;
		}
		if (((guild === undefined) || (luaProp(guild, "Id") === ""))) {
			let guide: unknown = ((luaProp(config, "ClientPageGuides") !== undefined) ? luaProp(luaProp(config, "ClientPageGuides"), "Guild") : undefined);
			let pageGap: unknown = (luaTruthy(stack) ? 12 : luaProp(Layout, "panelGap"));
			let joinBlockH: unknown = ((((276 as unknown as number) + (pageGap as unknown as number)) as unknown as number) + (192 as unknown as number));
			return reactLoose.createElement(PageScaffold, { gap: pageGap, tailPad: luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), 80), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: 4, sections: luaCall(withStatus, [{ id: "empty-hero", height: 128, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? 16 : 20), highlight: true, reveal: enter, reducedMotion: softMotion, clips: false }, reactLoose.createElement(Text, { value: ((((luaTruthy(guide ) ?  luaProp(guide, "EmptyTitle") : guide))) || "No guild yet"), size: 20, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) }), reactLoose.createElement(Text, { value: ((((luaTruthy(guide ) ?  luaProp(guide, "EmptyBody") : guide))) || "Charter one for shared upgrades, or join with a tag."), size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 36) }), reactLoose.createElement(Text, { value: ((((luaTruthy(guide ) ?  luaProp(guide, "Benefits") : guide))) || "Shared production, vault, offline, automation, and tap boosts."), size: 11, color: luaProp(Palette, "violet"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 78), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) })) }, { id: "join", height: joinBlockH, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, pageGap) }), reactLoose.createElement(JoinOrCreate, { config: config, dispatch: send, reducedMotion: softMotion, busy: busy, shakeToken: shakeToken, stack: stack, cash: luaProp(state, "Cash") })) }], 1) });
		}
		if ((pane === "Community")) {
			return reactLoose.createElement(GuildCommunityPanel, { guild: guild, dispatch: dispatch, reducedMotion: softMotion, stack: stack, role: (((luaTruthy(luaIndex(luaProp(guild, "Members"), localKey) ) ?  luaProp(luaIndex(luaProp(guild, "Members"), localKey), "Role") : luaIndex(luaProp(guild, "Members"), localKey))) || "Member"), config: config, onBack: function(this: void): unknown | undefined {
				luaCall(setPane, "Overview");
				return undefined;
			} });
		}
		let members: unknown = {};
		for (const [key, member] of pairs((luaProp(guild, "Members")) as object)) {
			let _arg0: unknown = { key: key, name: luaProp(member, "Name"), role: luaProp(member, "Role"), contributed: luaProp(member, "Contributed") };
			luaTable.insert(members, _arg0);
		}
		(table.sort as unknown as (...a: unknown[]) => unknown)(members, function(this: void, left?: unknown, right?: unknown): unknown | undefined {
			let _condition: unknown = luaIndex(ROLE_RANK, luaProp(left, "role"));
			if ((_condition === undefined)) {
				_condition = 3;
			}
			let leftRank: unknown = _condition;
			let _condition_1: unknown = luaIndex(ROLE_RANK, luaProp(right, "role"));
			if ((_condition_1 === undefined)) {
				_condition_1 = 3;
			}
			let rightRank: unknown = _condition_1;
			if ((leftRank !== rightRank)) {
				return ((leftRank as unknown as number) < (rightRank as unknown as number));
			}
			return ((luaProp(left, "contributed") as unknown as number) > (luaProp(right, "contributed") as unknown as number));
			return undefined;
		});
		let totalContributed: unknown = 0;
		for (const [_, member] of pairs((members) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			totalContributed = ((totalContributed as unknown as number) + (luaProp(member, "contributed") as unknown as number));
		}
		let _result: unknown = luaIndex(luaProp(guild, "Members"), localKey);
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Role");
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = "Member";
		}
		let myRole: unknown = _condition;
		let canManage: unknown = (myRole === "Leader");
		let canBuy: unknown = ((myRole === "Leader") || (myRole === "Officer"));
		let rows: unknown = luaCall(buildUpgradeRows, config, guild);
		let _goalContributors: unknown = luaProp(guild, "Goal");
		if ((_goalContributors !== undefined)) {
			_goalContributors = luaProp(_goalContributors, "Contributors");
		}
		let goalContributors: unknown = _goalContributors;
		let pageGap: unknown = (luaTruthy(stack) ? 12 : luaProp(Layout, "panelGap"));
		let heroHeight: unknown = (luaTruthy(stack) ? 218 : 132);
		let goalHeight: unknown = ((luaProp(guild, "Goal") === undefined) ? 116 : (luaTruthy(stack) ? 234 : 196));
		let bankHeight: unknown = (luaTruthy(stack) ? 310 : 216);
		let upgradeHeight: unknown = (luaTruthy(stack) ? 180 : 140);
		let sectionLabelH: unknown = 34;
		let heroSurface: unknown = luaCall(darken, luaProp(Palette, "violet"), 0.9);
		let _attributes: unknown = {};
		let _exp_2: unknown = luaProp(guild, "Tag");
		let _exp_3: unknown = len(members);
		let _result_1: unknown = luaProp(config, "Guild");
		if ((_result_1 !== undefined)) {
			_result_1 = luaProp(_result_1, "MaxMembers");
		}
		let _condition_1: unknown = _result_1;
		if ((_condition_1 === undefined)) {
			_condition_1 = 20;
		}
		luaSet(_attributes, "value", `[${_exp_2}]  •  ${_exp_3}/${_condition_1} MEMBERS`);
		luaSet(_attributes, "size", 10);
		luaSet(_attributes, "color", luaCall(ensureContrast, heroSurface, luaProp(Palette, "violet")));
		luaSet(_attributes, "weight", luaProp(luaProp(Enum, "FontWeight"), "Heavy"));
		luaSet(_attributes, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -8 : -160), 0, 14));
		let _exp_4: unknown = reactLoose.createElement(Text, _attributes);
		let _exp_5: unknown = reactLoose.createElement(Text, { value: luaProp(guild, "Name"), size: (luaTruthy(stack) ? 24 : 31), color: luaCall(ensureContrast, heroSurface, luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 17, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -8 : -160), 0, 38) });
		let _exp_6: unknown = reactLoose.createElement(Text, { value: `ACTIVITY ${luaCall(compactNumber, luaProp(guild, "Activity"))}  •  YOU ARE ${(string.upper as unknown as (...a: unknown[]) => unknown)(myRole)}`, size: 11, color: luaCall(ensureContrast, heroSurface, luaProp(Palette, "creamSoft")), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 62 : 64)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 18) });
		let _attributes_1: unknown = {};
		let _result_2: unknown = luaProp(state, "GuildBonuses");
		if ((_result_2 !== undefined)) {
			_result_2 = luaProp(_result_2, "Production");
		}
		let _condition_2: unknown = _result_2;
		if ((_condition_2 === undefined)) {
			_condition_2 = 0;
		}
		let _exp_7: unknown = luaCall(percentText, _condition_2);
		let _result_3: unknown = luaProp(state, "GuildBonuses");
		if ((_result_3 !== undefined)) {
			_result_3 = luaProp(_result_3, "Capacity");
		}
		let _condition_3: unknown = _result_3;
		if ((_condition_3 === undefined)) {
			_condition_3 = 0;
		}
		let _exp_8: unknown = luaCall(percentText, _condition_3);
		let _result_4: unknown = luaProp(state, "GuildBonuses");
		if ((_result_4 !== undefined)) {
			_result_4 = luaProp(_result_4, "Offline");
		}
		let _condition_4: unknown = _result_4;
		if ((_condition_4 === undefined)) {
			_condition_4 = 0;
		}
		let _exp_9: unknown = luaCall(percentText, _condition_4);
		let _result_5: unknown = luaProp(state, "GuildBonuses");
		if ((_result_5 !== undefined)) {
			_result_5 = luaProp(_result_5, "Automation");
		}
		let _condition_5: unknown = _result_5;
		if ((_condition_5 === undefined)) {
			_condition_5 = 0;
		}
		let _exp_10: unknown = luaCall(percentText, _condition_5);
		let _result_6: unknown = luaProp(state, "GuildBonuses");
		if ((_result_6 !== undefined)) {
			_result_6 = luaProp(_result_6, "Tap");
		}
		let _condition_6: unknown = _result_6;
		if ((_condition_6 === undefined)) {
			_condition_6 = 0;
		}
		luaSet(_attributes_1, "value", `SHARED BONUSES  ${_exp_7} production  •  ${_exp_8} vault  •  ${_exp_9} offline  •  ${_exp_10} auto  •  ${luaCall(percentText, _condition_6)} tap`);
		luaSet(_attributes_1, "size", 10);
		luaSet(_attributes_1, "color", luaCall(ensureContrast, heroSurface, luaProp(Palette, "mint")));
		luaSet(_attributes_1, "wrap", true);
		luaSet(_attributes_1, "position", luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 86 : 88)));
		luaSet(_attributes_1, "sizeConstraint", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, (luaTruthy(stack) ? 46 : 32)));
		let _exp_11: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), background: heroSurface, padding: (luaTruthy(stack) ? 16 : 20), reveal: (luaTruthy(reducedMotion) ? bankReveal : reveal), highlight: (((!luaTruthy(reducedMotion)) && (membersReveal !== undefined)) && (goalReveal !== undefined)), reducedMotion: softMotion, clips: false }, _exp_4, _exp_5, _exp_6, reactLoose.createElement(Text, _attributes_1), ((luaTruthy(canManage) && (len(members) === 1)) ? reactLoose.createElement(Button, { text: ((luaTruthy(luaProp(confirmation, "current")) && (luaProp(luaProp(confirmation, "current"), "key") === "DisbandGuild:")) ? "CONFIRM DISBAND" : "DISBAND"), onClick: function(this: void): unknown | undefined {
			if ((!luaTruthy(busy))) {
				luaCall(send, "DisbandGuild", {});
			}
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "coral"), disabled: busy, loading: busy, shakeToken: shakeToken, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42) : luaCall(luaProp(UDim2, "fromOffset"), 140, 42)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -42) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -140, 0, 0)), reducedMotion: softMotion }) : reactLoose.createElement(Button, { text: ((luaTruthy(luaProp(confirmation, "current")) && (luaProp(luaProp(confirmation, "current"), "key") === "LeaveGuild:")) ? "CONFIRM LEAVE" : "LEAVE"), onClick: function(this: void): unknown | undefined {
			if ((!luaTruthy(busy))) {
				luaCall(send, "LeaveGuild", {});
			}
			return undefined;
		}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "coral"), disabled: busy, loading: busy, shakeToken: shakeToken, size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42) : luaCall(luaProp(UDim2, "fromOffset"), 140, 42)), position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -42) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -140, 0, 0)), reducedMotion: softMotion })));
		let _exp_12: unknown = reactLoose.createElement(GuildGoalCard, { guild: guild, config: config, layoutOrder: 0, stack: stack, reducedMotion: reducedMotion, dispatch: send, busy: busy, shakeToken: shakeToken });
		let _exp_13: unknown = reactLoose.createElement(Text, { value: "GUILD BANK", size: 10, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 14) });
		let _exp_14: unknown = reactLoose.createElement(Text, { value: `${luaCall(compactNumber, luaProp(guild, "BankCash"))} flux  •  ${luaCall(compactNumber, luaProp(guild, "BankDust"))} dust`, size: (luaTruthy(stack) ? 17 : 20), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 13, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 18), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 26) });
		let _exp_15: unknown = reactLoose.createElement(Text, { value: "Deposits fund every hall upgrade and count toward the guild goal.", size: 10, color: luaProp(Palette, "muted"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 46), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 26) });
		let _exp_16: unknown = reactLoose.createElement("textbox", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -6, 0, 40)), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 76), PlaceholderText: "Flux amount", Text: contributeCash, ClearTextOnFocus: false, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			return luaCall(setContributeCash, luaProp(box, "Text"));
			return undefined;
		} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }));
		let _attributes_2: unknown = { text: "DEPOSIT FLUX", onClick: function(this: void): unknown | undefined {
			let amount: unknown = tonumber(contributeCash);
			if ((((amount !== undefined) && ((amount as unknown as number) >= (1 as unknown as number))) && (!luaTruthy(busy)))) {
				luaCall(send, "ContributeGuild", { Amount: (math.floor as unknown as (...a: unknown[]) => unknown)(amount), Currency: "Cash" });
				luaCall(setContributeCash, "");
			}
			return undefined;
		}, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink") };
		let _condition_7: unknown = busy;
		if ((!luaTruthy(_condition_7))) {
			let _condition_8: unknown = tonumber(contributeCash);
			if ((_condition_8 === undefined)) {
				_condition_8 = 0;
			}
			_condition_7 = ((_condition_8 as unknown as number) < (1 as unknown as number));
		}
		luaSet(_attributes_2, "disabled", _condition_7);
		luaSet(_attributes_2, "size", (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -6, 0, 42)));
		luaSet(_attributes_2, "position", (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 0, 126) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 0, 128)));
		luaSet(_attributes_2, "reducedMotion", reducedMotion);
		let _exp_17: unknown = reactLoose.createElement(Button, _attributes_2);
		let _exp_18: unknown = reactLoose.createElement("textbox", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -6, 0, 40)), Position: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 0, 172) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 6, 0, 76)), PlaceholderText: "Dust amount", Text: contributeDust, ClearTextOnFocus: false, TextColor3: luaProp(Palette, "cream"), PlaceholderColor3: luaProp(Palette, "muted"), TextSize: 14, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			return luaCall(setContributeDust, luaProp(box, "Text"));
			return undefined;
		} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "line"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement("uipadding", { PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }));
		let _attributes_3: unknown = { text: "DEPOSIT DUST", onClick: function(this: void): unknown | undefined {
			let amount: unknown = tonumber(contributeDust);
			if ((((amount !== undefined) && ((amount as unknown as number) >= (1 as unknown as number))) && (!luaTruthy(busy)))) {
				luaCall(send, "ContributeGuild", { Amount: (math.floor as unknown as (...a: unknown[]) => unknown)(amount), Currency: "Dust" });
				luaCall(setContributeDust, "");
			}
			return undefined;
		}, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink") };
		let _condition_8: unknown = busy;
		if ((!luaTruthy(_condition_8))) {
			let _condition_9: unknown = tonumber(contributeDust);
			if ((_condition_9 === undefined)) {
				_condition_9 = 0;
			}
			_condition_8 = ((_condition_9 as unknown as number) < (1 as unknown as number));
		}
		luaSet(_attributes_3, "disabled", _condition_8);
		luaSet(_attributes_3, "size", (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 42) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -6, 0, 42)));
		luaSet(_attributes_3, "position", (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 0, 222) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 6, 0, 128)));
		luaSet(_attributes_3, "reducedMotion", reducedMotion);
		let _exp_19: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? 16 : 18), reducedMotion: reducedMotion, clips: false }, _exp_13, _exp_14, _exp_15, _exp_16, _exp_17, _exp_18, reactLoose.createElement(Button, _attributes_3));
		let _exp_20: unknown = reactLoose.createElement(SectionLabel, { value: "HALL UPGRADES", color: luaProp(Palette, "violet") });
		let upgradeChildren: unknown = {};
		if ((len(rows) === 0)) {
			luaSetIndex(upgradeChildren, 1, reactLoose.createElement(EmptyState, { key: "empty-upgrades", title: "No hall upgrades", body: "Hall upgrades are still loading.", icon: "Forge.17", accent: luaProp(Palette, "violet"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 72), layoutOrder: 1 }));
		} else {
			for (const [index, row] of pairs((rows) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(upgradeChildren, index, reactLoose.createElement(UpgradeCard, { key: luaProp(row, "id"), row: row, guild: guild, canBuy: canBuy, stack: stack, reducedMotion: reducedMotion, dispatch: send, busy: busy, shakeToken: shakeToken, layoutOrder: index }));
			}
		}
		let upgradeBlockH: unknown = ((len(rows) === 0) ? 72 : ((((len(rows) as unknown as number) * (upgradeHeight as unknown as number)) as unknown as number) + ((((math.max as unknown as (...a: unknown[]) => unknown)(0, ((len(rows) as unknown as number) - (1 as unknown as number))) as unknown as number) * (pageGap as unknown as number)) as unknown as number)));
		let upgradeList: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, pageGap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), upgradeChildren);
		let roleCounts: unknown = { All: 0, Leader: 0, Officer: 0, Member: 0 };
		let shownMembers: unknown = {};
		for (const [_, member] of pairs((members) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (luaTruthy(luaCall(luaProp(Browse, "matches"), memberQuery, luaProp(member, "name"), luaProp(member, "role"), luaProp(member, "key")))) {
				luaSet(roleCounts, "All", ((luaProp(roleCounts, "All") as unknown as number) + (1 as unknown as number)));
				luaSetIndex(roleCounts, luaProp(member, "role"), (((((luaTruthy(luaIndex(roleCounts, luaProp(member, "role")) ) ? luaIndex(roleCounts, luaProp(member, "role")) :  0))) as unknown as number) + (1 as unknown as number)));
				if (((memberRole === "All") || (luaProp(member, "role") === memberRole))) {
					luaTable.insert(shownMembers, member);
				}
			}
		}
		// pin yourself above the role-sorted list so you never have to search for your own row
		shownMembers = pinFirst(shownMembers as unknown[], (member) => luaProp(member, "key") === localKey);
		let memberChildren: unknown = {};
		let memberRowsH = 0;
		let memberGapSoFar = 0;
		let lastGroupRole = "";
		const memberGroups: { top: number; label: string; color: Color3 }[] = [];
		const roleTotal = (role: string) => (tonumber(luaIndex(roleCounts, role)) ?? 0) as number;
		const groupLabel = (role: string) =>
			role === "You" ? "YOU" : role === "Leader" ? "LEADER" : role === "Officer" ? `OFFICERS · ${roleTotal("Officer")}` : `MEMBERS · ${roleTotal("Member")}`;
		const groupColor = (role: string) =>
			(role === "You" ? luaProp(Palette, "green") : role === "Leader" ? luaProp(Palette, "mango") : role === "Officer" ? luaProp(Palette, "cyan") : luaProp(Palette, "creamSoft")) as Color3;
		for (const [index, member] of pairs((shownMembers) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let share: unknown = 0;
			if ((goalContributors !== undefined)) {
				share = ((luaTruthy(luaIndex(goalContributors, luaProp(member, "key")) ) ? luaIndex(goalContributors, luaProp(member, "key")) :  0));
			}
			const rowProps: unknown = { key: luaProp(member, "key"), userKey: luaProp(member, "key"), name: luaProp(member, "name"), role: luaProp(member, "role"), contributed: luaProp(member, "contributed"), goalShare: share, share: (((totalContributed as unknown as number) > (0 as unknown as number)) ? ((luaProp(member, "contributed") as unknown as number) / (totalContributed as unknown as number)) : 0), isLocal: (luaProp(member, "key") === localKey), canManage: ((luaTruthy(canBuy ) ?  (luaProp(member, "key") !== localKey) : canBuy)), myRole: myRole, confirmKick: ((luaTruthy(luaProp(confirmation, "current") ) ?  (luaProp(luaProp(confirmation, "current"), "key") === concat("KickGuildMember:", tostring(luaProp(member, "key")))) : luaProp(confirmation, "current"))), isLeader: (luaProp(member, "role") === "Leader"), stack: stack, reducedMotion: reducedMotion, dispatch: send, busy: busy, shakeToken: shakeToken, layoutOrder: index };
			const rowRole = luaProp(member, "key") === localKey ? "You" : tostring(luaProp(member, "role"));
			if (rowRole !== lastGroupRole) {
				lastGroupRole = rowRole;
				memberGroups.push({ top: memberRowsH + memberGapSoFar, label: groupLabel(rowRole), color: groupColor(rowRole) });
			}
			memberRowsH += memberRowLayout(rowProps).height;
			memberGapSoFar += pageGap as unknown as number;
			luaSetIndex(memberChildren, index, reactLoose.createElement(MemberRow, rowProps as never));
		}
		const stickyGroups = luaTruthy(stack) && memberGroups.size() > 1;
		const stickyPad = stickyGroups ? STICKY_H + 6 : 0;
		let memberBlockH: unknown = ((len(shownMembers) === 0) ? 72 : stickyPad + memberRowsH + math.max(0, (len(shownMembers) as unknown as number) - 1) * (pageGap as unknown as number));
		let overscan: unknown = (luaTruthy(softMotion) ? 0 : (luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2));
		let memberSearchH: unknown = (luaTruthy(stack) ? TapTarget : 40);
		let memberFilter: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, reactLoose.createElement(SearchField, { value: memberQuery, onChange: setMemberQuery, placeholder: "Search members", accent: luaProp(Palette, "violet"), reducedMotion: softMotion, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, memberSearchH), zIndex: 20 }), reactLoose.createElement(luaProp(Browse, "ChipRow"), { options: [{ id: "All", label: "Everyone" }, { id: "Leader", label: "Leader" }, { id: "Officer", label: "Officers" }, { id: "Member", label: "Members" }], value: memberRole, onChange: function(this: void, id?: unknown): unknown | undefined {
			luaCall(setMemberRole, id);
			return undefined;
		}, counts: roleCounts, accent: luaProp(Palette, "violet"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((memberSearchH as unknown as number) + (8 as unknown as number))) }));
		let memberList: unknown = ((len(shownMembers) === 0) ? reactLoose.createElement(EmptyState, { title: (((len(members) as unknown as number) > (0 as unknown as number)) ? "No members match" : "No members"), body: (((len(members) as unknown as number) > (0 as unknown as number)) ? "Clear the search or pick Everyone." : "Members show up here."), icon: "Pilot.2", accent: luaProp(Palette, "cyan"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 72) }) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, stickyGroups ? reactLoose.createElement(StickyGroupLabel, { groups: memberGroups.map((g) => ({ top: g.top + stickyPad, label: g.label, color: g.color })), height: memberBlockH as number }) : undefined, reactLoose.createElement("frame", { Size: new UDim2(1, 0, 1, -stickyPad), Position: UDim2.fromOffset(0, stickyPad), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, pageGap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), memberChildren)));
		let hall: unknown = luaCall(luaProp(Social, "hall"), guild);
		let tabs: unknown = {};
		let columns: unknown = (luaTruthy(stack) ? 2 : 5);
		let guildTabs: unknown = ["Overview", "Treasury", "Upgrades", "Members", "Community"];
		for (const [index, id] of pairs((guildTabs) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(tabs, index, reactLoose.createElement(Button, { text: (string.upper as unknown as (...a: unknown[]) => unknown)(id), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (columns as unknown as number)), -6, 0, 48), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) % (columns as unknown as number))) as unknown as number) / (columns as unknown as number)), 0, 0, (((math.floor as unknown as (...a: unknown[]) => unknown)((((((index as unknown as number) - (1 as unknown as number))) as unknown as number) / (columns as unknown as number))) as unknown as number) * (56 as unknown as number))), color: ((pane === id) ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), onClick: function(this: void): unknown | undefined {
				luaCall(setPane, id);
				return undefined;
			}, reducedMotion: softMotion }));
		}
		let navigationHeight: unknown = (((math.ceil as unknown as (...a: unknown[]) => unknown)(((len(guildTabs) as unknown as number) / (columns as unknown as number))) as unknown as number) * (56 as unknown as number));
		let sections: unknown = luaCall(withStatus, [{ id: "hero", height: heroHeight, element: _exp_11 }, { id: "guild-navigation", height: navigationHeight, element: reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, tabs) }], 2);
		function add(id?: unknown, height?: unknown, element?: unknown): unknown | undefined {
			luaTable.insert(sections, { id: id, height: height, element: element });
			return undefined;
		}
		if ((pane === "Overview")) {
			luaCall(add, "hall-progress", (luaTruthy(stack) ? 132 : 112), reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), padding: 16, accent: luaProp(Palette, "mint") }, reactLoose.createElement(Text, { value: `HALL LEVEL ${luaProp(hall, "Level")} · ${luaProp(hall, "Title")}`, size: 19, wrap: true, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 26) }), reactLoose.createElement(Meter, { value: luaProp(hall, "Progress"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 10), color: luaProp(Palette, "mint"), reducedMotion: softMotion }), reactLoose.createElement(Text, { value: `${luaProp(hall, "Remaining")} more upgrade level${((luaProp(hall, "Remaining") === 1) ? "" : "s")} to the next hall level. Every five installed upgrade levels add one.`, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 54), size: 13, color: luaProp(Palette, "creamSoft"), wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? 44 : 24)) })));
			luaCall(add, "goal", goalHeight, _exp_12);
		} else if ((pane === "Treasury")) {
			luaCall(add, "bank", bankHeight, _exp_19);
		} else if ((pane === "Upgrades")) {
			luaCall(add, "upgrades-label", sectionLabelH, _exp_20);
			luaCall(add, "upgrades", upgradeBlockH, upgradeList);
		} else {
			luaCall(add, "role-policy", (luaTruthy(stack) ? 176 : 120), reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), padding: 16, accent: luaProp(Palette, "cyan") }, reactLoose.createElement(Text, { value: "ROLES & SUCCESSION", size: 17, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24) }), reactLoose.createElement(Text, { value: "Leaders manage roles and the hall. Officers handle upgrades and members. Everyone can contribute and claim goal rewards. Leadership passes to an officer, then the earliest member.", position: luaCall(luaProp(UDim2, "fromOffset"), 0, 32), size: 13, color: luaProp(Palette, "creamSoft"), wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? 110 : 52)) })));
			if (((len(members) as unknown as number) > (3 as unknown as number))) {
				luaCall(add, "member-filter", ((((memberSearchH as unknown as number) + (8 as unknown as number)) as unknown as number) + (luaProp(Browse, "CHIP_H") as unknown as number)), memberFilter);
			}
			luaCall(add, "members", memberBlockH, memberList);
		}
		return reactLoose.createElement(PageScaffold, { gap: 12, tailPad: luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), 80), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: 4, sections: sections });
		return undefined;
	}
	return { GuildView: GuildView };
	return undefined;
}
export = __member();
