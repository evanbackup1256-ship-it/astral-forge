// The mixer's SoundGroup tree. Everything hangs under ForgeMaster in SoundService:
//   ForgeMaster ── ForgeSfx (EQ + glue compressor) ── ForgeUI ── ForgeAmbient ── ForgeMusic
// ensureBus reuses a group that survived a restart and always resets its volume, so a hot reload
// can't leave a bus at a stale level.
const SoundService = game.GetService("SoundService");

export type BusName = "ForgeMaster" | "ForgeSfx" | "ForgeUI" | "ForgeAmbient" | "ForgeMusic";

export function ensureBus(name: BusName, parent: Instance, volume: number): SoundGroup {
	let bus = parent.FindFirstChild(name) as SoundGroup | undefined;
	if (bus === undefined || !bus.IsA("SoundGroup")) {
		bus = new Instance("SoundGroup");
		bus.Name = name;
		bus.Volume = volume;
		bus.Parent = parent;
	}
	bus.Volume = volume;
	return bus;
}

export function ensureEffect<T extends keyof CreatableInstances>(
	bus: SoundGroup,
	className: T,
	name: string,
	configure: (effect: CreatableInstances[T]) => void,
): CreatableInstances[T] {
	const existing = bus.FindFirstChild(name);
	if (existing !== undefined && existing.IsA(className)) {
		return existing as CreatableInstances[T];
	}
	const effect = new Instance(className);
	effect.Name = name;
	configure(effect);
	effect.Parent = bus;
	return effect;
}

export interface BusSet {
	master: SoundGroup;
	sfx: SoundGroup;
	ui: SoundGroup;
	ambient: SoundGroup;
	music: SoundGroup;
}

export function ensureBuses(levels: { master: number; sfx: number; ui: number; ambient: number }): BusSet {
	const master = ensureBus("ForgeMaster", SoundService, levels.master);
	return {
		master,
		sfx: ensureBus("ForgeSfx", master, levels.sfx),
		ui: ensureBus("ForgeUI", master, levels.ui),
		ambient: ensureBus("ForgeAmbient", master, levels.ambient),
		music: ensureBus("ForgeMusic", master, 1),
	};
}
