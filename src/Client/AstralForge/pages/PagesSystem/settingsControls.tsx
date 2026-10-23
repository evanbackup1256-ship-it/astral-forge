// design/18-settings "Controls" panel (520px, right column on wide desktop). Lists the fixed bindings the
// game actually has; keys can't be rebound, so the mockup's "Reset to default" button is left out.
import React from "@rbxts/react";
import { Palette } from "../../CoreKit/theme";
import { MockPanel, NUM, PanelHeading } from "../../UiCore/mockKit";
import { GcRow } from "../gcKit";

const BINDINGS: Array<{ icon: string; title: string; key: string }> = [
	{ icon: "Crew.12", title: "Player list", key: "Tab" },
	{ icon: "Command.5", title: "Chat", key: "/" },
	{ icon: "Command.4", title: "Back (controller)", key: "B" },
];

export const CONTROLS_W = 520;

export function controlsPanelHeight(): number {
	// .pn padding 18 + h3 + rows (48) with 12px gaps
	return 18 * 2 + 24 + BINDINGS.size() * (48 + 12);
}

export function SettingsControlsPanel(p: { reducedMotion?: boolean }) {
	const rows: Record<string, React.Element> = {};
	BINDINGS.forEach((b, i) => {
		rows[`k${i}`] = <GcRow icon={b.icon} title={b.title} value={b.key} valueColor={Palette.mango} valueFont={NUM} phone={false} layoutOrder={i + 1} />;
	});
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={false} reducedMotion={p.reducedMotion} name="SettingsControls">
			<PanelHeading icon="Command.4" title="Controls" phone={false} layoutOrder={0} />
			{rows}
		</MockPanel>
	);
}
