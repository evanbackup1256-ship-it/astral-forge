// Settings service: one way to read and change a player setting on the client.
// The schema (Shared/SettingsSchema) owns keys, kinds, defaults and how a raw value snaps to a
// legal one. Values persist in the save under Settings; a change goes to the server as SetSetting
// (same remote and payload as before) and is applied optimistically to the store right away.
import Schema = require("../../../Shared/AstralForge/Shared/SharedData/SettingsSchema");
import { useClientSelector } from "./clientStore";

type SettingsBag = Record<string, unknown> | undefined;
export type SettingsDispatch = (action: string, payload: Record<string, unknown>) => unknown;

function settingsOf(state: { session?: { Settings?: SettingsBag } }): SettingsBag {
	return state.session?.Settings;
}

// The stored value clamped to 0..1, or the schema default when it was never set.
export function readSetting(settings: SettingsBag, key: string): number {
	return Schema.value(settings, key);
}

export function isOn(settings: SettingsBag, key: string): boolean {
	return readSetting(settings, key) >= 0.5;
}

export function useSettingOn(key: string): boolean {
	return useClientSelector((state) => isOn(settingsOf(state), key));
}

// Snap a value the way the server will (toggles to 0/1, choices to their nearest option).
export function normalizeSetting(key: string, value: number): number {
	return Schema.normalize(key, value);
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
