// Every saved sound setting the mixer reads, with the default it falls back to before the first
// snapshot. The values live in the player's save under Settings (sent with SetSetting), so they
// persist across sessions with no client-side storage.

export interface AudioMixerApi {
	configurePreferences(this: unknown, settings: Record<string, unknown>): void;
	setVolume(this: unknown, value: number): void;
	setMusicVolume(this: unknown, value: number): void;
	setSfxVolume(this: unknown, value: number): void;
}

// [save key, default]. Bus gains are under the mixer's control; these are the player's sliders.
export const VOLUME_SETTINGS = {
	SoundVolume: 0.75,
	MusicVolume: 1,
	SfxVolume: 1,
	UiVolume: 0.9,
	GameplayVolume: 1,
	RewardVolume: 1,
	AmbientVolume: 0.75,
	HoverSounds: 1,
	NotificationSounds: 1,
	PageMusic: 1,
	SoundVariation: 0.7,
} as const;

export type VolumeKey = keyof typeof VOLUME_SETTINGS;
export const VOLUME_KEYS: ReadonlyArray<VolumeKey> = [
	"SoundVolume", "MusicVolume", "SfxVolume", "UiVolume", "GameplayVolume", "RewardVolume",
	"AmbientVolume", "HoverSounds", "NotificationSounds", "PageMusic", "SoundVariation",
];

export type Volumes = { [K in VolumeKey]: number };

export function readVolumes(settings: Record<string, unknown> | undefined): Volumes {
	const out = {} as Record<VolumeKey, number>;
	for (const key of VOLUME_KEYS) {
		const raw = settings?.[key];
		out[key] = typeIs(raw, "number") && raw === raw ? math.clamp(raw, 0, 1) : VOLUME_SETTINGS[key];
	}
	return out;
}

// A string that changes exactly when one of the sound settings changes; use it as an effect key.
export function volumesKey(settings: Record<string, unknown> | undefined): string {
	const volumes = readVolumes(settings);
	return VOLUME_KEYS.map((key) => tostring(volumes[key])).join("|");
}

export function applyVolumes(mixer: AudioMixerApi, settings: Record<string, unknown> | undefined) {
	const volumes = readVolumes(settings);
	mixer.configurePreferences({
		UiVolume: volumes.UiVolume,
		GameplayVolume: volumes.GameplayVolume,
		RewardVolume: volumes.RewardVolume,
		AmbientVolume: volumes.AmbientVolume,
		HoverSounds: volumes.HoverSounds,
		NotificationSounds: volumes.NotificationSounds,
		PageMusic: volumes.PageMusic,
		SoundVariation: volumes.SoundVariation,
	});
	mixer.setVolume(volumes.SoundVolume);
	mixer.setMusicVolume(volumes.MusicVolume);
	mixer.setSfxVolume(volumes.SfxVolume);
}
