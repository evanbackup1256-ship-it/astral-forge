// Star charts for v8 Constellations. Self-contained: give it the snapshot's Constellations block
// and the page dispatcher. Routing it into Ascension is left to whoever owns the page router.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import * as Constellations from "../../../../Shared/AstralForge/Shared/Constellations";

const { Button, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type ConstellationDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

export interface ConstellationState {
	Points?: number;
	Lifetime?: number;
	Lit?: Record<string, boolean>;
	Paused?: boolean;
}

const PAD = 14;
const HEAD_H = 64;
const CARD_H = 96;
const CARD_H_STACK = 96 + TapTarget + 8;
const GAP = 8;

function pct(value: number): string {
	const scaled = math.floor(value * 1000 + 0.5) / 10;
	return `${scaled}%`;
}

export function constellationsHeight(stack: boolean): number {
	const rows = Constellations.CONSTELLATIONS.size();
	return PAD * 2 + HEAD_H + rows * (stack ? CARD_H_STACK : CARD_H) + (rows - 1) * GAP;
}

export function ConstellationsView(props: {
	state: ConstellationState;
	dispatch: ConstellationDispatch;
	stack: boolean;
	reducedMotion?: boolean;
}) {
	const { state, stack } = props;
	const lit = state.Lit ?? {};
	const points = state.Points ?? 0;
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });

	const light = (starId: string) => {
		if (pending !== undefined) {
			return;
		}
		setPending(starId);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("ConstellationAct", { Op: "Light", Star: starId }, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key: starId, token: current.token + 1 }));
			}
		});
	};

	const cardH = stack ? CARD_H_STACK : CARD_H;
	const cards: Record<string, React.Element> = {};
	Constellations.CONSTELLATIONS.forEach((chart, index) => {
		let count = 0;
		for (const star of chart.Stars) {
			if (lit[star.Id] !== true) {
				break;
			}
			count += 1;
		}
		const done = count === chart.Stars.size();
		const nextStar = done ? undefined : chart.Stars[count];
		const ready = nextStar !== undefined && points >= nextStar.Cost && state.Paused !== true;
		const current = count * chart.PerStar + (done ? chart.Completion : 0);
		const dots = chart.Stars.map((star) => (lit[star.Id] === true ? "●" : "○")).join(" ");
		const accent = done ? Palette.mango : count > 0 ? Palette.mint : Palette.lineSoft;
		cards[chart.Id] = (
			<frame
				Size={new UDim2(1, 0, 0, cardH)}
				Position={UDim2.fromOffset(0, HEAD_H + index * (cardH + GAP))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panelRaised} padding={12} reducedMotion={props.reducedMotion} clips={false}>
					<Text
						value={chart.Name}
						size={16}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={11}
						sizeConstraint={new UDim2(1, stack ? 0 : -170, 0, 22)}
					/>
					<Text
						value={`${dots}   ·   +${pct(current)} ${chart.Kind.lower()}`}
						size={13}
						color={accent}
						weight={Enum.FontWeight.Bold}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(0, 24)}
						sizeConstraint={new UDim2(1, stack ? 0 : -170, 0, 18)}
					/>
					<Text
						value={
							done
								? `${chart.Blurb} Complete.`
								: `${chart.Blurb} Next: ${nextStar!.Name}, +${pct(chart.PerStar)}${
										count === chart.Stars.size() - 1 ? ` and +${pct(chart.Completion)} for finishing` : ""
									}.`
						}
						size={12}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(0, 44)}
						sizeConstraint={new UDim2(1, stack ? 0 : -170, 0, 30)}
					/>
					{!done && (
						<frame
							Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(156, 44)}
							Position={stack ? UDim2.fromOffset(0, CARD_H - 16) : new UDim2(1, -156, 0.5, -22)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
						>
							<Button
								text={`Light · ${nextStar!.Cost} pt${nextStar!.Cost === 1 ? "" : "s"}`}
								onClick={() => light(nextStar!.Id)}
								color={ready ? Palette.mango : Palette.panelSoft}
								textColor={ready ? Palette.ink : Palette.muted}
								size={UDim2.fromScale(1, 1)}
								disabled={!ready}
								highlight={ready}
								loading={pending === nextStar!.Id}
								shakeToken={refused.key === nextStar!.Id ? refused.token : 0}
								reducedMotion={props.reducedMotion}
							/>
						</frame>
					)}
				</Panel>
			</frame>
		);
	});

	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}>
			<Text
				value="CONSTELLATIONS"
				size={11}
				color={Palette.mango}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Text
				value={
					state.Paused === true
						? "The charts are closed for a moment. Lit stars still count."
						: `${points} Star Point${points === 1 ? "" : "s"} to spend. Every rebirth earns one.`
				}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 20)}
				sizeConstraint={new UDim2(1, 0, 0, 22)}
			/>
			{cards}
		</Panel>
	);
}
