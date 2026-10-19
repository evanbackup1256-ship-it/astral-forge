import { ClientLog } from "../CoreKit/log";
import * as Soundtrack from "./soundtrack";

const SoundService = game.GetService("SoundService");
const ContentProvider = game.GetService("ContentProvider");

export const MUSIC_ASSET_MANIFEST = Soundtrack.manifest();
export const DECK_NAMES = ["SoundtrackA", "SoundtrackB"];
const POLL_SECONDS = 0.25;
const FADE_STEP_SECONDS = 0.05;
const LOAD_DEADLINE_SECONDS = 12;

interface Deck {
	sound: Sound;
	equalizer: EqualizerSoundEffect;
	trackIndex?: number;
	loadStarted: number;
	loadVersion?: number;
	loadFailed?: boolean;
}

let activeDirector: MusicDirector | undefined;

function makeDeck(name: string, group: SoundGroup): Deck {
	const sound = new Instance("Sound");
	sound.Name = name;
	sound.Looped = true;
	sound.Volume = 0;
	sound.SoundGroup = group;
	sound.Parent = SoundService;
	const compressor = new Instance("CompressorSoundEffect");
	compressor.Name = "BedGlue";
	compressor.Threshold = -18;
	compressor.Ratio = 2;
	compressor.Attack = 0.02;
	compressor.Release = 0.2;
	compressor.Parent = sound;
	const equalizer = new Instance("EqualizerSoundEffect");
	equalizer.Name = "TrackTone";
	equalizer.Parent = sound;
	return { sound, equalizer, trackIndex: undefined, loadStarted: 0 };
}

// Two decks crossfade through a shuffled soundtrack. Deck numbers (`active`) and track numbers are 1-based.
export class MusicDirector {
	group: SoundGroup;
	decks: Deck[];
	active = 1;
	shuffle: Soundtrack.Shuffle;
	trackIndex: number;
	fading = false;
	fadeAlpha = 0;
	loopedOver = false;
	failedAt: Record<number, number | undefined> = {};
	mix = 1;
	duck = 1;
	audible = true;
	started = false;
	disposed = false;
	connections: RBXScriptConnection[] = [];
	retryAt?: number;
	worker?: thread;

	constructor(group: SoundGroup) {
		this.group = group;
		this.decks = [makeDeck(DECK_NAMES[0], group), makeDeck(DECK_NAMES[1], group)];
		this.shuffle = Soundtrack.newShuffle();
		this.trackIndex = this.shuffle.next(undefined, {}, os.clock()) ?? 1;
	}

	private deck(index: number): Deck {
		return this.decks[index - 1];
	}

	isLive(): boolean {
		return this.started && !this.disposed && this.retryAt === undefined && this.audible && this.mix * this.duck > 0.001;
	}

	spare(): number {
		return this.active === 1 ? 2 : 1;
	}

	loadDeck(deckIndex: number, trackIndex: number) {
		const deck = this.deck(deckIndex);
		const track = Soundtrack.track(trackIndex);
		deck.sound.Stop();
		deck.sound.Volume = 0;
		deck.trackIndex = trackIndex;
		deck.loadStarted = os.clock();
		deck.loadVersion = (deck.loadVersion ?? 0) + 1;
		const version = deck.loadVersion;
		deck.loadFailed = false;
		if (deck.sound.SoundId !== track.asset) {
			deck.sound.SoundId = track.asset;
		}
		deck.sound.PlaybackSpeed = 1;
		deck.sound.TimePosition = 0;
		deck.equalizer.LowGain = track.low;
		deck.equalizer.MidGain = track.mid;
		deck.equalizer.HighGain = track.high;
		// Preloading ID strings alone does not initialize a stopped Sound decoder.
		// Warm the actual deck instance, then Resume can start it without resetting
		// a paused song. Old fetch callbacks must not invalidate a replacement track.
		task.spawn(() => {
			const [ok] = pcall(() => {
				ContentProvider.PreloadAsync([deck.sound], (_, status) => {
					if (!this.disposed && deck.loadVersion === version) {
						deck.loadFailed = status !== Enum.AssetFetchStatus.Success;
					}
				});
			});
			if (!ok && !this.disposed && deck.loadVersion === version) {
				deck.loadFailed = true;
			}
		});
	}

	applyVolumes() {
		const activeDeck = this.deck(this.active);
		const spareDeck = this.deck(this.spare());
		if (!this.isLive()) {
			activeDeck.sound.Volume = 0;
			spareDeck.sound.Volume = 0;
			return;
		}
		const activeLevel = Soundtrack.volume(
			Soundtrack.track(activeDeck.trackIndex ?? this.trackIndex),
			this.mix,
			this.duck,
		);
		if (this.fading && spareDeck.trackIndex !== undefined) {
			const [outGain, inGain] = Soundtrack.fadeGains(this.fadeAlpha);
			activeDeck.sound.Volume = activeLevel * outGain;
			spareDeck.sound.Volume = Soundtrack.volume(Soundtrack.track(spareDeck.trackIndex), this.mix, this.duck) * inGain;
		} else {
			activeDeck.sound.Volume = activeLevel;
			spareDeck.sound.Volume = 0;
		}
	}

	refresh() {
		if (this.disposed || !this.started) {
			return;
		}
		this.applyVolumes();
		const activeSound = this.deck(this.active).sound;
		const spareSound = this.deck(this.spare()).sound;
		if (this.isLive()) {
			if (!activeSound.IsPlaying) {
				activeSound.Resume();
			}
			if (this.fading && !spareSound.IsPlaying) {
				spareSound.Resume();
			}
		} else {
			if (activeSound.IsPlaying) {
				activeSound.Pause();
			}
			if (spareSound.IsPlaying) {
				spareSound.Pause();
			}
		}
	}

	start() {
		if (this.started || this.disposed) {
			return;
		}
		if (activeDirector !== undefined && activeDirector !== this && !activeDirector.disposed) {
			activeDirector.dispose();
		}
		activeDirector = this;
		this.started = true;
		this.loadDeck(this.active, this.trackIndex);
		this.decks.forEach((deck, i) => {
			const index = i + 1;
			this.connections.push(
				deck.sound.DidLoop.Connect(() => {
					if (index === this.active && !this.fading) {
						this.loopedOver = true;
					}
				}),
			);
		});
		this.refresh();
		this.worker = task.spawn(() => {
			while (!this.disposed) {
				task.wait(POLL_SECONDS);
				if (this.disposed) {
					break;
				}
				const [ok, problem] = pcall(() => this.step());
				if (!ok && !this.disposed) {
					this.fading = false;
					this.fadeAlpha = 0;
					pcall(() => this.refresh());
					ClientLog.warnEvery("music-step", 30, "Audio", `soundtrack step failed: ${tostring(problem)}`);
				}
			}
		});
	}

	markFailed(trackIndex: number) {
		this.failedAt[trackIndex] = os.clock();
		const name = Soundtrack.track(trackIndex).name;
		ClientLog.warnEvery(`music-load-${name}`, 30, "Audio", `${name} did not load; skipping it for now`);
	}

	skipActive() {
		this.markFailed(this.trackIndex);
		const nextIndex = this.shuffle.next(this.trackIndex, this.failedAt, os.clock());
		if (nextIndex === undefined) {
			this.retryAt = os.clock() + 30;
			this.refresh();
			return;
		}
		this.trackIndex = nextIndex;
		this.loadDeck(this.active, this.trackIndex);
		this.refresh();
	}

	prepareSpare() {
		const spareIndex = this.spare();
		const spare = this.deck(spareIndex);
		const nextIndex = spare.trackIndex ?? this.shuffle.next(this.trackIndex, this.failedAt, os.clock());
		if (nextIndex === undefined) {
			return;
		}
		if (spare.trackIndex !== nextIndex) {
			this.loadDeck(spareIndex, nextIndex);
			return;
		}
		if (
			!spare.sound.IsLoaded &&
			(spare.loadFailed === true || os.clock() - spare.loadStarted >= LOAD_DEADLINE_SECONDS)
		) {
			this.markFailed(nextIndex);
			spare.trackIndex = undefined;
		}
	}

	step() {
		if (this.retryAt !== undefined) {
			if (os.clock() < this.retryAt) {
				return;
			}
			this.retryAt = undefined;
			this.skipActive();
			return;
		}
		if (!this.isLive() || this.fading) {
			return;
		}
		const deck = this.deck(this.active);
		const sound = deck.sound;
		if (!sound.IsLoaded) {
			if (deck.loadFailed === true || os.clock() - deck.loadStarted >= LOAD_DEADLINE_SECONDS) {
				this.skipActive();
			}
			return;
		}
		if (!sound.IsPlaying) {
			sound.Resume();
		}
		this.prepareSpare();
		const due =
			this.loopedOver || Soundtrack.shouldAdvance(sound.TimeLength, sound.TimePosition, sound.PlaybackSpeed);
		this.loopedOver = false;
		if (due) {
			this.handOver();
		}
	}

	handOver() {
		const spareIndex = this.spare();
		const spare = this.deck(spareIndex);
		const nextIndex = spare.trackIndex;
		if (nextIndex === undefined || !spare.sound.IsLoaded) {
			return;
		}
		this.fading = true;
		this.fadeAlpha = 0;
		spare.sound.TimePosition = 0;
		this.refresh();
		let elapsed = 0;
		while (elapsed < Soundtrack.CROSSFADE_SECONDS) {
			const dt = task.wait(FADE_STEP_SECONDS);
			if (this.disposed) {
				return;
			}
			if (this.isLive()) {
				elapsed += dt;
			}
			this.fadeAlpha = math.clamp(elapsed / Soundtrack.CROSSFADE_SECONDS, 0, 1);
			this.applyVolumes();
		}
		const outgoingDeck = this.deck(this.active);
		const outgoing = outgoingDeck.sound;
		outgoingDeck.trackIndex = undefined;
		outgoing.Stop();
		outgoing.Volume = 0;
		this.active = spareIndex;
		this.trackIndex = nextIndex;
		this.fading = false;
		this.fadeAlpha = 0;
		this.refresh();
		ClientLog.debug("audio", `soundtrack: ${Soundtrack.track(nextIndex).name}`);
	}

	setMix(value: number) {
		if (this.disposed) {
			return;
		}
		const nextMix = math.clamp(value, 0, 1);
		if (math.abs(nextMix - this.mix) <= 0.0005) {
			return;
		}
		this.mix = nextMix;
		this.refresh();
	}

	setDuck(value: number) {
		if (this.disposed) {
			return;
		}
		const nextDuck = math.clamp(value, 0, 1);
		if (math.abs(nextDuck - this.duck) <= 0.0005) {
			return;
		}
		this.duck = nextDuck;
		this.refresh();
	}

	setAudible(audible: unknown) {
		if (this.disposed) {
			return;
		}
		this.audible = audible === true;
		this.refresh();
	}

	resume() {
		this.refresh();
	}

	currentTrack(): string {
		return Soundtrack.track(this.trackIndex).name;
	}

	dispose() {
		if (this.disposed) {
			return;
		}
		this.disposed = true;
		this.started = false;
		if (activeDirector === this) {
			activeDirector = undefined;
		}
		if (this.worker !== undefined) {
			pcall(task.cancel, this.worker);
			this.worker = undefined;
		}
		for (const connection of this.connections) {
			connection.Disconnect();
		}
		this.connections.clear();
		for (const deck of this.decks) {
			pcall(() => {
				deck.sound.Destroy();
			});
		}
	}
}
