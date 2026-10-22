// Companion Bonds (v8 #3): the Inventory card for the relic riding in the companion slot. Shows the
// bond bar, the current trait, what the next evolution brings, and the trait choice when one is open.
import React from "@rbxts/react";
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";

const { Button, Meter, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type BondDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

const PAD = 20;

export function companionBondHeight(items: unknown, stack: boolean): number {
	const companion = CompanionRelic.describe(items);
	if (companion === undefined) return 0;
	const choice = companion.Offer !== undefined ? (stack ? TapTarget * 2 + 14 : TapTarget + 8) : 0;
	return PAD * 2 + 22 + 16 + 20 + choice;
}

function pct(value: number): string {
	return `${math.floor(value * 100 + 0.5)}%`;
}

export function CompanionBondCard(props: { items: unknown; dispatch: BondDispatch; stack: boolean; reducedMotion?: boolean }) {
	const companion = CompanionRelic.describe(props.items);
	const [busy, setBusy] = React.useState(false);
	if (companion === undefined) return undefined;
	const title = companion.Suffix !== "" ? `${companion.Name}, ${companion.Suffix}` : companion.Name;
	const atTop = companion.Rank >= CompanionRelic.MAX_RANK;
	let line: string;
	if (companion.Offer !== undefined) {
		line = "Choose a trait";
	} else if (companion.NextEvolution !== undefined) {
		const nextShare = CompanionRelic.shareFor(companion.NextEvolution);
		line = `${companion.Trait !== undefined ? companion.Trait.Text + "   " : ""}→ ${pct(nextShare)}`;
	} else {
		line = companion.Trait !== undefined ? companion.Trait.Text : "Fully bonded.";
	}
	const pick = (trait: string) => {
		if (busy) return;
		setBusy(true);
		props.dispatch("CompanionAct", { Op: "PickTrait", Trait: trait }, () => setBusy(false));
	};
	const offer = companion.Offer;
	const buttonSize = props.stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0.5, -4, 0, TapTarget);
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}>
			<Text value={title} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} fit={true} minSize={11} sizeConstraint={new UDim2(1, -150, 0, 22)} />
			<Text
				value={`${companion.Rank}  ·  ${pct(companion.Share)}`}
				size={15}
				color={Palette.violet}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -150, 0, 0)}
				sizeConstraint={new UDim2(0, 150, 0, 22)}
			/>
			<Meter value={atTop ? 1 : companion.Progress} color={Palette.violet} position={UDim2.fromOffset(0, 30)} size={new UDim2(1, 0, 0, 4)} reducedMotion={props.reducedMotion} />
			<Text value={line} size={12} color={Palette.muted} fit={true} minSize={10} position={UDim2.fromOffset(0, 46)} sizeConstraint={new UDim2(1, 0, 0, 18)} />
			{offer !== undefined && (
				<frame Size={new UDim2(1, 0, 0, props.stack ? TapTarget * 2 + 6 : TapTarget)} Position={UDim2.fromOffset(0, 72)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Button
						text={offer[0].Name}
						onClick={() => pick(offer[0].Id)}
						size={buttonSize}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						outline={true}
						disabled={busy}
						reducedMotion={props.reducedMotion}
					/>
					<Button
						text={offer[1].Name}
						onClick={() => pick(offer[1].Id)}
						size={buttonSize}
						position={props.stack ? UDim2.fromOffset(0, TapTarget + 6) : new UDim2(0.5, 4, 0, 0)}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						outline={true}
						disabled={busy}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			)}
		</Panel>
	);
}
