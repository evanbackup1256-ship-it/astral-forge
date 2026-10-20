import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";

// Dev-only redraw counter: how many times the shell rendered in the last second.
// Shown only in Studio for players with admin access (state.Admin.Access), so it never runs live.
// Counting is a ref bump during render; the readout updates a binding once a second, so the
// counter itself never causes a re-render.

const RunService = game.GetService("RunService");
const IN_STUDIO = RunService.IsStudio();

const counts = new Map<string, number>();

export function redrawCounterEnabled(state: { Admin?: { Access?: boolean } }): boolean {
	return IN_STUDIO && state.Admin?.Access === true;
}

// call at the top of a component's render; free when disabled
export function countRedraw(name: string, enabled: boolean) {
	if (enabled) {
		counts.set(name, (counts.get(name) ?? 0) + 1);
	}
}

export function RedrawCounterHud(props: { enabled: boolean; position?: UDim2 }) {
	const [label, setLabel] = React.useBinding("");
	React.useEffect(() => {
		if (!props.enabled) {
			return undefined;
		}
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(1);
				const parts: string[] = [];
				for (const [name, n] of counts) {
					parts.push(`${name} ${n}/s`);
				}
				counts.clear();
				parts.sort();
				setLabel(parts.size() > 0 ? `redraws · ${parts.join(" · ")}` : "redraws · idle");
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [props.enabled]);
	if (!props.enabled) {
		return undefined;
	}
	return (
		<textlabel
			key="DevRedrawCounter"
			Size={UDim2.fromOffset(260, 18)}
			Position={props.position ?? new UDim2(0, 8, 1, -26)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.3}
			BorderSizePixel={0}
			Text={label}
			TextColor3={Palette.creamSoft}
			TextSize={11}
			Font={Enum.Font.Code}
			TextXAlignment={Enum.TextXAlignment.Left}
			ZIndex={900}
		/>
	);
}
