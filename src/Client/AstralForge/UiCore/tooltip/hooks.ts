// Target side of tooltips: useTooltip(content) returns handlers to merge into an Event table.
import React from "@rbxts/react";
import { useLatest } from "@rbxts/pretty-react-hooks";
import { isTouchOnly } from "../../CoreKit/inputLayer";
import { TooltipContent, readContent } from "./content";
import {
	TooltipTiming,
	beginPress,
	closeTooltip,
	endPress,
	hoverDelay,
	nextTooltipId,
	openTooltip,
	padDelay,
	refreshTooltip,
	registerTooltipAvoid,
	scheduleTooltip,
} from "./intent";

const GuiService = game.GetService("GuiService");

export interface TooltipEvents {
	MouseEnter: (this: void, rbx: GuiObject) => void;
	MouseLeave: (this: void, rbx: GuiObject) => void;
	SelectionGained: (this: void, rbx: GuiObject) => void;
	SelectionLost: (this: void, rbx: GuiObject) => void;
	InputBegan: (this: void, rbx: GuiObject, input: InputObject) => void;
	InputEnded: (this: void, rbx: GuiObject, input: InputObject) => void;
}

/** Handlers for one target. Content may change every render; an open tip follows it. */
export function useTooltip(content: TooltipContent | undefined): TooltipEvents {
	const id = React.useMemo(() => nextTooltipId(), []);
	const latest = useLatest(content);
	React.useEffect(() => refreshTooltip(id, content));
	React.useEffect(() => () => closeTooltip(id), []);
	return React.useMemo<TooltipEvents>(() => {
		const read = () => latest.current;
		const wanted = () => readContent(read()) !== undefined;
		let pressedAt = 0;
		const leave = () => {
			const open = openTooltip();
			if (open === undefined || open.id === id) {
				closeTooltip(id);
			} else {
				// another target's tip is up; just drop our pending open
				closeTooltip(-1);
			}
		};
		return {
			MouseEnter: (rbx) => {
				if (!isTouchOnly() && wanted()) {
					scheduleTooltip(id, rbx, read, hoverDelay(), "keyboard");
				}
			},
			MouseLeave: leave,
			SelectionGained: (rbx) => {
				if (GuiService.SelectedObject === rbx && wanted()) {
					scheduleTooltip(id, rbx, read, padDelay(), "gamepad");
				}
			},
			SelectionLost: leave,
			InputBegan: (rbx, input) => {
				const kind = input.UserInputType;
				if (kind === Enum.UserInputType.Touch) {
					pressedAt = os.clock();
					beginPress(new Vector2(input.Position.X, input.Position.Y));
					if (wanted()) {
						scheduleTooltip(id, rbx, read, TooltipTiming.longPress, "touch");
					}
				} else if (
					kind === Enum.UserInputType.MouseButton1 ||
					kind === Enum.UserInputType.MouseButton2 ||
					kind === Enum.UserInputType.MouseWheel
				) {
					leave();
				}
			},
			InputEnded: (_rbx, input) => {
				if (input.UserInputType !== Enum.UserInputType.Touch) {
					return;
				}
				endPress();
				const open = openTooltip();
				if (open !== undefined && open.id === id && os.clock() - pressedAt >= TooltipTiming.longPress) {
					// a long-press tip stays up long enough to read
					task.delay(TooltipTiming.touchLinger, () => {
						if (openTooltip() === open) {
							closeTooltip(id);
						}
					});
				} else {
					leave();
				}
			},
		};
	}, []);
}

type Handler = (this: void, ...args: unknown[]) => void;

/** Joins two Event tables; when both handle an event, `a` runs first, then `b`. */
export function mergeEvents<A extends object, B extends object>(a: A | undefined, b: B | undefined): A & B {
	const out: Record<string, Handler> = {};
	for (const [key, handler] of pairs((a ?? {}) as Record<string, Handler>)) {
		out[key as string] = handler;
	}
	for (const [key, handler] of pairs((b ?? {}) as Record<string, Handler>)) {
		const first = out[key as string];
		out[key as string] =
			first !== undefined
				? (...args: unknown[]) => {
						first(...args);
						handler(...args);
					}
				: handler;
	}
	return out as unknown as A & B;
}

/** Keep tooltips off a HUD element (top bar, rails, strips) while it is mounted. */
export function useTooltipAvoid(ref: React.RefObject<GuiObject>) {
	React.useEffect(() => {
		const element = ref.current;
		if (element === undefined) {
			return undefined;
		}
		return registerTooltipAvoid(element);
	}, [ref.current]);
}
