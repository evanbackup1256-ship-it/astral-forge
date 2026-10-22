// Settings service: one way to read and change a player setting on the client.
// The schema (Shared/SettingsSchema) owns keys, kinds, defaults and how a raw value snaps to a
// legal one. Values persist in the save under Settings; a change goes to the server as SetSetting
// (same remote and payload as before) and is applied optimistically to the store right away.
import Schema = require("../../../Shared/AstralForge/Shared/SharedData/SettingsSchema");
import { getActiveClientStore, useClientSelector } from "./clientStore";

type SettingsBag = Record<string, unknown> | undefined;
export type SettingsDispatch = (action: string, payload: Record<string, unknown>) => unknown;

function settingsOf(state: { session?: { Settings?: SettingsBag } }): SettingsBag {
	return state.session?.Settings;
}

// The stored value clamped to 0..1, or the schema default when it was never set.
export function readSetting(settings: SettingsBag, key: string): number {
	return Schema.value(settings, key);
}

export function getSetting(key: string): number {
	const store = getActiveClientStore();
	return readSetting(store !== undefined ? settingsOf(store.getState()) : undefined, key);
}

export function isOn(settings: SettingsBag, key: string): boolean {
	return readSetting(settings, key) >= 0.5;
}

export function useSetting(key: string): number {
	return useClientSelector((state) => readSetting(settingsOf(state), key));
}

export function useSettingOn(key: string): boolean {
	return useClientSelector((state) => isOn(settingsOf(state), key));
}

// Snap a value the way the server will (toggles to 0/1, choices to their nearest option).
export function normalizeSetting(key: string, value: number): number {
	return Schema.normalize(key, value);
}

export function setSetting(dispatch: SettingsDispatch, key: string, value: number) {
	if (!Schema.accepts(key)) {
		warn(`[settings] unknown setting ${key}`);
		return;
	}
	dispatch("SetSetting", { Key: key, Value: normalizeSetting(key, value) });
}

// Several settings in one request; `label` becomes the notice the server sends back (presets, resets).
export function setSettings(dispatch: SettingsDispatch, values: Record<string, number>, label?: string) {
	const clean: Record<string, number> = {};
	for (const [key, value] of pairs(values)) {
		if (Schema.accepts(key)) {
			clean[key] = normalizeSetting(key, value);
		}
	}
	dispatch("SetSetting", label !== undefined ? { Values: clean, Label: label } : { Values: clean });
}

export function resetSection(dispatch: SettingsDispatch, section: string, label: string) {
	setSettings(dispatch, Schema.sectionDefaults(section), label);
}

// Calls back whenever the setting's effective value changes; returns a disconnect.
export function onSettingChanged(key: string, callback: (value: number) => void): () => void {
	const store = getActiveClientStore();
	if (store === undefined) {
		return () => {};
	}
	let last = readSetting(settingsOf(store.getState()), key);
	const connection = store.changed.connect((next) => {
		const now = readSetting(settingsOf(next), key);
		if (now !== last) {
			last = now;
			callback(now);
		}
	});
	return () => connection.disconnect();
}
