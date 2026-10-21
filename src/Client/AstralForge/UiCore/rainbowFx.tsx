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
