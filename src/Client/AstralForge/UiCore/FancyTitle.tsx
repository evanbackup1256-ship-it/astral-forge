// One title component for headers, section titles, notifications and floating feedback.
//
//   <FancyTitle
//       size={UDim2.new(1, 0, 0, 40)}
//       config={{ text: "Celestial Anvil", size: 30, color: Palette.cream, shadow: true, state: { rarity } }}
//       hover="clickpop"
//       click="smash"
//   />
//
//   // floating feedback that types itself out and fades
//   <FancyTitle config={{ text: "+12.4K flux", size: 20, color: Palette.brass, typewrite: 40 }} exit={{ effect: "fade", after: 1.2 }} />
//
// The text re-renders only when what it shows changes (text, parts, size, colour, state); hover and
// click effects play on the live text. The trove is cleaned on unmount.
import React from "@rbxts/react";
import * as FancyText from "./fancyText";
import { isReducedMotion } from "../MotionPreference";

export interface FancyTitleProps {
	config: FancyText.TitleConfig;
	size?: UDim2;
	position?: UDim2;
	anchorPoint?: Vector2;
	zIndex?: number;
	/** played on the text when the pointer enters */
	hover?: "clickpop" | "smash";
	/** played on press */
	click?: "clickpop" | "smash" | "fade" | "fall";
	/** leave on its own: the effect plays after `after` seconds and the text is cleaned when it ends */
	exit?: { effect: "fade" | "fall"; after: number };
}

function signature(config: FancyText.TitleConfig): string {
	const parts = (config.parts ?? []).map((p) => `${p.text ?? ""}|${p.icon ?? ""}|${(p.tags ?? []).join(",")}`).join(";");
	const state = config.state;
	const stateKey = state !== undefined ? `${state.rarity}|${state.hover}|${state.selected}|${state.active}|${string.format("%.2f", state.progress ?? -1)}` : "";
	return [config.text, parts, config.size, tostring(config.color), stateKey, tostring(config.shadow !== undefined && config.shadow !== false), tostring(config.wave), tostring(config.typewrite), config.align ?? "", (config.effects ?? []).join(","), tostring(config.transparency ?? 0)].join("#");
}

export function FancyTitle(props: FancyTitleProps) {
	const ref = React.useRef<Frame>();
	const trove = React.useRef<FancyText.FancyTrove>();
	const key = signature(props.config);
	const config = React.useRef(props.config);
	config.current = props.config;
	React.useEffect(() => {
		const host = ref.current;
		if (host === undefined) {
			return undefined;
		}
		const made = FancyText.make(host, config.current);
		trove.current = made;
		let exitJob: thread | undefined;
		if (made !== undefined && props.exit !== undefined) {
			const exit = props.exit;
			exitJob = task.delay(exit.after, () => {
				exitJob = undefined;
				if (trove.current === made) {
					made.PlayEffect(exit.effect, undefined, true);
					trove.current = undefined;
				}
			});
		}
		return () => {
			if (exitJob !== undefined) {
				pcall(task.cancel, exitJob);
			}
			if (trove.current === made) {
				trove.current = undefined;
			}
			made?.Clean();
		};
	}, [key]);
	const play = (effect: string | undefined) => {
		if (effect === undefined || isReducedMotion()) {
			return;
		}
		trove.current?.PlayEffect(effect);
	};
	return (
		<frame
			ref={ref}
			Size={props.size ?? UDim2.fromScale(1, 1)}
			Position={props.position}
			AnchorPoint={props.anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
			Active={props.click !== undefined}
			Event={{
				MouseEnter: () => play(props.hover),
				InputBegan: (_, input) => {
					if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
						play(props.click);
					}
				},
			}}
		/>
	);
}
