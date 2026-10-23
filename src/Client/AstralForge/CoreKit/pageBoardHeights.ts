export const MACHINE = 120;
export const MACHINE_STACK = 188;
// world cards: sized to their content (148/218 left a 22-48 px empty band under every card)
export const WORLD = 132;
export const WORLD_STACK = 182;
export const VISIT = 268;
export const VISIT_STACK = 380;

export function Machine(stack?: boolean): number {
	return stack ? MACHINE_STACK : MACHINE;
}

export function World(stack?: boolean): number {
	return stack ? WORLD_STACK : WORLD;
}

export function Visit(stack?: boolean): number {
	return stack ? VISIT_STACK : VISIT;
}
