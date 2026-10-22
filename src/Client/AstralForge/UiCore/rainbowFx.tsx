// React side of the shared rainbow clock: a UIGradient whose colour follows what the element is
// doing. Drop it inside a frame (fill) or a UIStroke (rim):
//
//   <frame BackgroundColor3={Palette.white}>
//     <RainbowGradient base={rarityColor} state={{ rarity: item.Rarity, hover, selected }} />
//   </frame>
//
//   <uistroke Thickness={1.5} Color={Palette.white}>
//     <RainbowGradient base={accent} style="spin" state={{ active: autoForgeOn }} />
//   </uistroke>
//
//   // a bar that warms as it fills and flows the spectrum once it's full
//   <RainbowGradient base={Palette.brass} state={{ progress: ratio }} />
//
// Nothing per frame happens unless the state asks for movement; hidden or offscreen gradients are
// skipped; reduced motion and Settings > Graphics > Rainbow are applied by Rainbow.configure.
import React from "@rbxts/react";
import Rainbow = require("../Rainbow");

type Options = Parameters<typeof Rainbow.bind>[1];
type State = NonNullable<Options["state"]>;

export interface RainbowGradientProps {
	base: Color3;
	state?: State;
	style?: "flow" | "spin";
	phase?: number;
	/** passed straight to the gradient: e.g. a fill that fades at its ends */
	transparency?: NumberSequence;
	/** sideways flow by default; a vertical strip can turn it */
	rotation?: number;
}

export function RainbowGradient(props: RainbowGradientProps) {
	const ref = React.useRef<UIGradient>();
	const handle = React.useRef<ReturnType<typeof Rainbow.bind>>();
	const state = props.state ?? {};
	React.useEffect(() => {
		const gradient = ref.current;
		if (gradient === undefined) {
			return undefined;
		}
		const bound = Rainbow.bind(gradient, { base: props.base, state, style: props.style, phase: props.phase });
		handle.current = bound;
		return () => {
			handle.current = undefined;
			bound.destroy();
		};
	}, [props.style, props.phase]);
	React.useEffect(() => {
		handle.current?.setState(state);
	}, [state.rarity, state.hover, state.selected, state.progress, state.active]);
	React.useEffect(() => {
		handle.current?.setBase(props.base);
	}, [props.base]);
	return (
		<uigradient
			ref={ref}
			Color={new ColorSequence(props.base)}
			Transparency={props.transparency}
			Rotation={props.style === "spin" ? undefined : props.rotation ?? 0}
		/>
	);
}

export interface RainbowLayersProps {
	base: Color3;
	state?: State;
	radius?: number;
	zIndex?: number;
	/** rim stroke thickness; the rim is the loud layer */
	thickness?: number;
	/** how see-through the inner wash stays (1 = no wash) */
	washTransparency?: number;
}

/**
 * Layered rainbow (uirevamp 01): a soft inner wash that flows sideways and a rim that spins,
 * both bound to the one shared Rainbow clock with offset phases so they never move in lockstep.
 * State decides everything: a resting element with no rarity/hover/selection/progress gets the
 * plain base colour and costs nothing per frame.
 */
function RainbowLayers(props: RainbowLayersProps) {
	const radius = props.radius ?? 14;
	const zIndex = props.zIndex ?? 1;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false} ZIndex={zIndex}>
			<uicorner CornerRadius={new UDim(0, radius)} />
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Color3.fromRGB(255, 255, 255)}
				BackgroundTransparency={props.washTransparency ?? 0.93}
				BorderSizePixel={0}
				Active={false}
				ZIndex={zIndex}
			>
				<uicorner CornerRadius={new UDim(0, radius)} />
				<RainbowGradient base={props.base} state={props.state} phase={0.37} rotation={90} />
			</frame>
			<uistroke Thickness={props.thickness ?? 1.5} Color={Color3.fromRGB(255, 255, 255)} ApplyStrokeMode={Enum.ApplyStrokeMode.Border}>
				<RainbowGradient base={props.base} state={props.state} style="spin" />
			</uistroke>
		</frame>
	);
}
