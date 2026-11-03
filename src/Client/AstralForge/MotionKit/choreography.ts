// Choreography: the part of the motion system that lets UI animations know about each other.
//
//   claims    A floating element (the trade-return pill, a toast, a dock) claims space along an edge
//             while it is on screen. Whatever lays itself out around that edge reads the total with
//             useReserved and glides on the layout spring: the page makes room instead of being covered,
//             and glides back when the claim ends. Claims add up, so two floaters stack.
//   avoid     A floating element registers its frame as an obstacle; tooltips (and anything else that
//             positions itself) ask visibleObstacles() and pick a spot that does not cover one.
//   focus     (focus.ts) a foreground move takes the stage; ambient motion waits its turn.
import React from "@rbxts/react";
import { LAYOUT_DAMPING, LAYOUT_STIFFNESS } from "./dynamicLayout";
import { useFlipperSpring } from "./motion";

export type Edge = "top" | "bottom";

interface Claim {
	edge: Edge;
	size: number;
}

const claims = new Map<string, Claim>();
const listeners = new Set<() => void>();

function notify() {
	for (const listener of listeners) {
		listener();
	}
}

function reservedOn(edge: Edge): number {
	let total = 0;
	for (const [, claim] of claims) {
		if (claim.edge === edge) {
			total += claim.size;
		}
	}
	return total;
}

/** Claim `size` px along an edge for as long as the caller is mounted (and `active`). */
export function useClaim(id: string, edge: Edge, size: number, active = true): void {
	React.useEffect(() => {
		if (!active || size <= 0) {
			return undefined;
		}
		claims.set(id, { edge, size });
		notify();
		return () => {
			claims.delete(id);
			notify();
		};
	}, [id, edge, size, active]);
}

/**
 * The px currently claimed along an edge, eased on the layout spring, and whether it is still moving
 * (tag the frame that resizes with it LayoutInMotion while it is, so the layout guard waits).
 */
export function useReserved(edge: Edge): { amount: React.Binding<number>; moving: boolean } {
	const [goal, setGoal] = React.useState(reservedOn(edge));
	const [moving, setMoving] = React.useState(false);
	React.useEffect(() => {
		let timer: thread | undefined;
		const stopTimer = () => {
			if (timer !== undefined) {
				pcall(task.cancel, timer);
				timer = undefined;
			}
		};
		const listener = () => {
			setGoal(reservedOn(edge));
			setMoving(true);
			stopTimer();
			timer = task.delay(0.7, () => {
				timer = undefined;
				setMoving(false);
			});
		};
		listeners.add(listener);
		// a claim made by a child's effect (which runs first) is already in the store: pick it up quietly
		setGoal(reservedOn(edge));
		return () => {
			listeners.delete(listener);
			stopTimer();
		};
	}, [edge]);
	return { amount: useFlipperSpring(goal, false, LAYOUT_STIFFNESS, LAYOUT_DAMPING), moving };
}

const obstacles = new Set<GuiObject>();

/** Register a frame as something other floating UI should keep clear of while it is mounted. */
export function useObstacle(ref: React.RefObject<GuiObject>, active = true): void {
	React.useEffect(() => {
		const host = ref.current;
		if (!active || host === undefined) {
			return undefined;
		}
		obstacles.add(host);
		return () => {
			obstacles.delete(host);
		};
	}, [active]);
}

/** The registered obstacles that are on screen right now. */
export function visibleObstacles(): GuiObject[] {
	const out: GuiObject[] = [];
	for (const obstacle of obstacles) {
		if (obstacle.Parent !== undefined && obstacle.Visible && obstacle.AbsoluteSize.X > 0) {
			out.push(obstacle);
		}
	}
	return out;
}
