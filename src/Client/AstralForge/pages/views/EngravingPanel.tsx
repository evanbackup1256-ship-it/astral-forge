// Engraving block for one relic (v8). Self-contained so the Inventory inspect panel can drop it
// in once the restyle settles: pass the relic instance, its definition and the wallet.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import * as RelicEngraving from "../../../../Shared/AstralForge/Shared/RelicEngraving";

const { Button, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type EngravingDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

const LINE_H = 40;
const LINE_GAP = 6;
const HEAD_H = 22;
const FOOT_H = 18;

export function engravingPanelHeight(): number {
	const lines = RelicEngraving.UNLOCK_LEVELS.size();
	return HEAD_H + lines * LINE_H + (lines - 1) * LINE_GAP + FOOT_H + 6;
}

interface Instance {
	Level?: number;
	Engraving?: RelicEngraving.Engraving;
}

export function EngravingPanel(props: {
	uid: string;
	instance: Instance;
	definition: RelicEngraving.CostDefinition;
	essence: number;
	starsteel: number;
	paused?: boolean;
	dispatch: EngravingDispatch;
	reducedMotion?: boolean;
}) {
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const engraving = props.instance.Engraving;
	const lines = engraving?.Lines ?? [];
	const slots = RelicEngraving.slotsAt(props.instance.Level);
	const price = RelicEngraving.cost(props.definition, engraving);
	const affordable = props.essence >= price.Essence && props.starsteel >= price.Starsteel && props.paused !== true;

	const send = (op: "Roll" | "Lock", line: number) => {
		const key = `${op}${line}`;
		if (pending !== undefined) {
			return;
		}
		setPending(key);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("EngraveRelic", { Uid: props.uid, Op: op, Line: line }, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key, token: current.token + 1 }));
			}
		});
	};

	const rows: Record<string, React.Element> = {};
	RelicEngraving.UNLOCK_LEVELS.forEach((level, index) => {
		const number = index + 1;
		const line = lines[index];
		const open = number <= slots;
		const fresh = open && line === undefined && index === lines.size();
		const locked = line?.Locked === true;
		const label =
			line !== undefined
				? RelicEngraving.describe(line)
				: open
					? fresh
						? "Empty line"
						: "Fill the line above first"
					: `Opens at level ${level}`;
		rows[`Line${number}`] = (
			<frame
				Size={new UDim2(1, 0, 0, LINE_H)}
				Position={UDim2.fromOffset(0, HEAD_H + index * (LINE_H + LINE_GAP))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Text
					value={label}
					size={13}
					color={line !== undefined ? (locked ? Palette.mango : Palette.cream) : Palette.muted}
					weight={line !== undefined ? Enum.FontWeight.Bold : Enum.FontWeight.Regular}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, 10)}
					sizeConstraint={new UDim2(1, -196, 0, 20)}
				/>
				{line !== undefined && (
					<frame Size={UDim2.fromOffset(84, TapTarget)} Position={new UDim2(1, -190, 0.5, -TapTarget / 2)} BackgroundTransparency={1}>
						<Button
							text={locked ? "Unlock" : "Lock"}
							onClick={() => send("Lock", number)}
							color={Palette.panelSoft}
							textColor={locked ? Palette.mango : Palette.cream}
							size={UDim2.fromScale(1, 1)}
							loading={pending === `Lock${number}`}
							shakeToken={refused.key === `Lock${number}` ? refused.token : 0}
							reducedMotion={props.reducedMotion}
						/>
					</frame>
				)}
				{(fresh || (line !== undefined && !locked)) && (
					<frame Size={UDim2.fromOffset(100, TapTarget)} Position={new UDim2(1, -100, 0.5, -TapTarget / 2)} BackgroundTransparency={1}>
						<Button
							text={line !== undefined ? "Reroll" : "Engrave"}
							onClick={() => send("Roll", number)}
							color={affordable ? Palette.mango : Palette.panelSoft}
							textColor={affordable ? Palette.ink : Palette.muted}
							size={UDim2.fromScale(1, 1)}
							disabled={!affordable}
							highlight={affordable}
							loading={pending === `Roll${number}`}
							shakeToken={refused.key === `Roll${number}` ? refused.token : 0}
							reducedMotion={props.reducedMotion}
						/>
					</frame>
				)}
			</frame>
		);
	});

	const footY = HEAD_H + RelicEngraving.UNLOCK_LEVELS.size() * (LINE_H + LINE_GAP);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Text value="ENGRAVING" size={11} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			{rows}
			<Text
				value={
					props.paused === true
						? "The engraver is away for a moment. Engraved lines still count."
						: `Next roll: ${price.Essence} Essence and ${price.Starsteel} Starsteel. Lines pay while the relic is socketed or your companion.`
				}
				size={11}
				color={Palette.muted}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, footY)}
				sizeConstraint={new UDim2(1, 0, 0, FOOT_H)}
			/>
		</frame>
	);
}
