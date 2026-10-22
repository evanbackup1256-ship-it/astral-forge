// Forge2: the from-scratch client. Mounted by index.client only when the AstralForgeClient2
// attribute is true on ReplicatedStorage or on the local player; otherwise the old client runs.
import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import { applyVolumes } from "../AudioKit/volumes";
import type { ClientNetwork } from "../ClientNetwork";
import { readSetting } from "../CoreKit/settingsService";
import { applyAccessibilityTheme } from "../CoreKit/theme";
import { usesDesktopStructure } from "../CoreKit/interaction";
import { resolveTextScale } from "../CoreKit/textScale";
import { MotionSettings, MotionSettingsContext } from "../MotionKit/motion";
import { Shell } from "./shell/Shell";
import { ForgeNet } from "./store/net";
import { ForgeStore, StoreContext, useForge } from "./store/store";

const FLAG = "AstralForgeClient2";

export function forge2Enabled(): boolean {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const player = game.GetService("Players").LocalPlayer;
	return ReplicatedStorage.GetAttribute(FLAG) === true || player.GetAttribute(FLAG) === true;
}

export interface Forge2Props {
	network: ClientNetwork;
	bridge: Folder;
	config: Record<string, unknown>;
	version: string;
}

function readPreferredTextSize(): string | undefined {
	const [ok, value] = pcall(() => game.GetService("GuiService").PreferredTextSize.Name);
	return ok && typeIs(value, "string") ? value : undefined;
}

function SettingsBridge(props: { children?: React.ReactNode }) {
	const settings = useForge((s) => s.session?.Settings);
	React.useEffect(() => {
		pcall(() => applyVolumes(Audio, settings));
		applyAccessibilityTheme(readSetting(settings, "HighContrast") >= 0.5, readSetting(settings, "ColorblindMode") >= 0.5);
	}, [settings]);
	// Text size: Settings > Accessibility (desktop) / Phone (touch), lifted by Roblox's own size when followed
	const [robloxText, setRobloxText] = React.useState(() => readPreferredTextSize());
	React.useEffect(() => {
		const [ok, signal] = pcall(() => game.GetService("GuiService").GetPropertyChangedSignal("PreferredTextSize"));
		if (!ok || !typeIs(signal, "RBXScriptSignal")) return undefined;
		const connection = signal.Connect(() => setRobloxText(readPreferredTextSize()));
		return () => connection.Disconnect();
	}, []);
	const view = game.GetService("Workspace").CurrentCamera?.ViewportSize ?? new Vector2(1280, 720);
	const touch = !usesDesktopStructure(view.X, view.Y) && game.GetService("UserInputService").TouchEnabled;
	const textScale = resolveTextScale(touch, readSetting(settings, touch ? "MobileTextScale" : "DesktopTextScale"), readSetting(settings, "FollowRobloxTextSize") >= 0.5, robloxText);
	const motion = React.useMemo<MotionSettings>(() => {
		const on = (key: string) => (readSetting(settings, key) >= 0.5 ? 1 : 0);
		return {
			motionScale: readSetting(settings, "MotionIntensity"),
			viewportScale: readSetting(settings, "ViewportSpeed"),
			textScale,
			soft: false,
			reducedTransparency: on("ReducedTransparency") === 1,
			shimmerScale: on("ButtonShimmers") === 1 ? readSetting(settings, "ShimmerIntensity") : 0,
			panelHoverScale: on("PanelHover"),
			panelEntranceScale: on("PanelEntrances"),
			titleScale: on("AnimatedTitles"),
			iconScale: on("IconAnimations"),
			numberScale: on("NumberAnimations"),
			boldText: readSetting(settings, "BoldText"),
		};
	}, [settings, textScale]);
	return <MotionSettingsContext.Provider value={motion}>{props.children}</MotionSettingsContext.Provider>;
}

export function Forge2App(props: Forge2Props) {
	const store = React.useMemo(() => new ForgeStore("Overview"), []);
	const net = React.useMemo(() => new ForgeNet(store, props.network, props.bridge, props.version), [store]);
	React.useEffect(() => {
		net.start();
		Audio.setScene("default");
		return () => net.stop();
	}, [net]);
	return (
		<StoreContext.Provider value={store}>
			<SettingsBridge>
				<Shell request={net.request} config={props.config} />
			</SettingsBridge>
		</StoreContext.Provider>
	);
}
