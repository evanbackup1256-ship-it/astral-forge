import React from "@rbxts/react";
import { Flux, asFlux, compactNumber } from "../CoreKit/format";
import { isReducedMotion } from "../MotionPreference";

const RunService = game.GetService("RunService");

// A small "+12.4K" that floats off a currency readout when it jumps.
// Ordinary production ticks (anything under ~2.5 seconds of income) are ignored so it only
// speaks up for real gains: claims, sales, offline rewards. Reduced motion: it fades in place.

interface GainPopProps {
	value: unknown;
	rate?: unknown;
	color: Color3;
	zIndex?: number;
}

const LIFE = 1.1;

export function GainPop(props: GainPopProps) {
	const previous = React.useRef(asFlux(props.value as Flux));
	const [label, setLabel] = React.useState<string | undefined>(undefined);
	const [nonce, setNonce] = React.useState(0);
	const [t, setT] = React.useBinding(LIFE);
	React.useEffect(() => {
		const nextValue = asFlux(props.value as Flux);
		const prev = previous.current;
		previous.current = nextValue;
		const delta = nextValue - prev;
		const rate = math.max(0, asFlux((props.rate ?? 0) as Flux));
		if (delta > 0 && delta === delta && delta > rate * 2.5 && prev > 0) {
			setLabel(`+${compactNumber(delta)}`);
			setNonce((n) => n + 1);
		}
	}, [props.value]);
	React.useEffect(() => {
		if (nonce === 0) {
			return undefined;
		}
		let elapsed = 0;
		setT(0);
		const conn = RunService.RenderStepped.Connect((dt) => {
			elapsed += dt;
			setT(elapsed);
			if (elapsed >= LIFE) {
				conn.Disconnect();
			}
		});
		return () => conn.Disconnect();
	}, [nonce]);
	if (label === undefined) {
		return undefined;
	}
	const still = isReducedMotion();
	return (
		<textlabel
			AnchorPoint={new Vector2(1, 0)}
			Size={UDim2.fromOffset(90, 16)}
			Position={t.map((s) => new UDim2(1, -2, 1, still ? 2 : 2 + math.floor((s / LIFE) * 14)))}
			BackgroundTransparency={1}
			Text={label}
			TextColor3={props.color}
			TextTransparency={t.map((s) => (s < 0.15 ? 1 - s / 0.15 : math.clamp((s - 0.6) / (LIFE - 0.6), 0, 1)))}
			TextStrokeTransparency={t.map((s) => (s < 0.15 ? 1 : 0.7 + math.clamp((s - 0.6) / (LIFE - 0.6), 0, 1) * 0.3))}
			TextSize={13}
			FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
			TextXAlignment={Enum.TextXAlignment.Right}
			ZIndex={props.zIndex ?? 30}
		/>
	);
}
