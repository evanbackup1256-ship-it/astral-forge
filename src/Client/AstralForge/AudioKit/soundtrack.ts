export interface Track {
	name: string;
	asset: string;
	gain: number;
	low: number;
	mid: number;
	high: number;
}

// Seven originals (tools/assetgen/soundtrack_gen.py) take turns with eleven calm space beds from the
// library. Off-theme library tracks (Hawaiian synth, action trailers, arcade synthwave, the eerie
// liminal ones) are out: every track here should sit under hours of play.
const TRACKS: Track[] = [
	{ name: "Starlit Anvil", asset: "rbxassetid://83224252725181", gain: 0.95, low: 0, mid: 0, high: 0 },
	{ name: "Space Ambient", asset: "rbxassetid://140533822783920", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Galactic Market", asset: "rbxassetid://85922328966318", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Nebula Market", asset: "rbxassetid://125327402955633", gain: 0.82, low: 0, mid: 0, high: 0 },
	{ name: "Slow Breathing Aurora (Space Ambient)", asset: "rbxassetid://140041908508788", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Return Signal Hopeful Future Ambient Music", asset: "rbxassetid://134433077845062", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Ember Drive", asset: "rbxassetid://132485327755002", gain: 0.85, low: 0, mid: 0, high: 0 },
	{ name: "Cosmic Cafe", asset: "rbxassetid://136898642923218", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Zero Gravity", asset: "rbxassetid://102039057339088", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Quiet Orbit", asset: "rbxassetid://114299463363605", gain: 1.0, low: 0, mid: 0, high: 0 },
	{ name: "Nebula Dream Theta Waves", asset: "rbxassetid://139793680497894", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Deep Space Ocean", asset: "rbxassetid://136827064604146", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Forge Pulse", asset: "rbxassetid://85607718934391", gain: 0.78, low: 0, mid: 0, high: 0 },
	{ name: "Space Station '98", asset: "rbxassetid://128285716110465", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Celestial String Awakening 2", asset: "rbxassetid://101244629093073", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Astral Orbit", asset: "rbxassetid://84797482092417", gain: 0.84, low: 0, mid: 0, high: 0 },
	{ name: "Calm Cinematic Space", asset: "rbxassetid://137911990035159", gain: 0.8, low: 0, mid: 0, high: 0 },
	{ name: "Sanctuary Drift", asset: "rbxassetid://98919050616365", gain: 0.9, low: 0, mid: 0, high: 0 },
];

export const CROSSFADE_SECONDS = 4;
export const BASE_VOLUME = 1;
export const RETRY_SECONDS = 600;

export function tracks(): Track[] {
	return TRACKS;
}

export function count(): number {
	return TRACKS.size();
}

// index is 1-based (track numbers), as the Luau callers use
export function track(index: number): Track {
	return TRACKS[(index - 1) % TRACKS.size()];
}

export function nextIndex(current: number, failedAt: Record<number, number | undefined>, now: number): number | undefined {
	const total = TRACKS.size();
	for (let step = 1; step <= total - 1; step++) {
		const candidate = ((current - 1 + step) % total) + 1;
		const failed = failedAt[candidate];
		if (failed === undefined || now - failed >= RETRY_SECONDS) {
			return candidate;
		}
	}
	return undefined;
}

export interface Shuffle {
	next(current: number | undefined, failedAt: Record<number, number | undefined>, now: number): number | undefined;
}

// Fisher-Yates shuffle bags give every healthy track a turn without repeats.
export function newShuffle(randomInteger?: (this: void, low: number, high: number) => number): Shuffle {
	const random = randomInteger ?? ((low: number, high: number) => math.random(low, high));
	const bag: number[] = [];
	const shuffle: Shuffle = {
		next(current, failedAt, now) {
			if (bag.size() === 0 || (bag.size() === 1 && bag[0] === current)) {
				bag.clear();
				for (let index = 1; index <= TRACKS.size(); index++) {
					bag.push(index);
				}
				for (let index = bag.size(); index >= 2; index--) {
					const other = random(1, index);
					const swap = bag[index - 1];
					bag[index - 1] = bag[other - 1];
					bag[other - 1] = swap;
				}
			}
			const deferred: number[] = [];
			let chosen: number | undefined;
			while (bag.size() > 0) {
				const candidate = bag.pop()!;
				const failed = failedAt[candidate];
				if (candidate === current) {
					deferred.push(candidate);
				} else if (failed === undefined || now - failed >= RETRY_SECONDS) {
					chosen = candidate;
					break;
				}
			}
			// A boundary repeat is deferred to a later draw, not thrown away.
			for (const candidate of deferred) {
				bag.unshift(candidate);
			}
			return chosen;
		},
	};
	return shuffle;
}

export function shouldAdvance(timeLength: number, timePosition: number, playbackSpeed: number): boolean {
	if (timeLength <= CROSSFADE_SECONDS * 2) {
		return false;
	}
	const remaining = (timeLength - timePosition) / math.max(0.05, playbackSpeed);
	return remaining <= CROSSFADE_SECONDS;
}

export function fadeGains(alpha: number): LuaTuple<[number, number]> {
	const t = math.clamp(alpha, 0, 1);
	return $tuple(math.cos(t * math.pi * 0.5), math.sin(t * math.pi * 0.5));
}

export function volume(track: Track, mix: number, duck: number): number {
	return BASE_VOLUME * track.gain * math.clamp(mix, 0, 1) * math.clamp(duck, 0, 1);
}

export function manifest(): string[] {
	const assets: string[] = [];
	for (const entry of TRACKS) {
		assets.push(entry.asset);
	}
	return assets;
}
