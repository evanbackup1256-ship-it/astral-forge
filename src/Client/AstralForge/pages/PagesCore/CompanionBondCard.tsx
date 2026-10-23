// Companion Bonds (v8 #3): the Inventory card for the relic riding in the companion slot. Shows the
// bond bar, the current trait, what the next evolution brings, and the trait choice when one is open.
import React from "@rbxts/react";
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import { Palette } from "../../CoreKit/theme";
import { Bar, MockPanel, PanelHeading } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, rowHeight } from "../mockRows";

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type BondDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

// 14-companions detail panel: heading with rank/share, bar, a .row for the trait line, sec trait buttons
export function companionBondHeight(items: unknown, stack: boolean): number {
	const companion = CompanionRelic.describe(items);
	if (companion === undefined) return 0;
	const g = stack ? 8 : 12;
	const choice = companion.Offer !== undefined ? (stack ? g + 44 * 2 + 8 : g + 44) : 0;
	return panelHeight(stack, headingBlock(stack) + 10 + g + rowHeight(stack) + choice);
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
		line = `${companion.Trait !== undefined ? companion.Trait.Text + "   " : ""}next ${pct(nextShare)}`;
	} else {
		line = companion.Trait !== undefined ? companion.Trait.Text : "Fully bonded.";
	}
	const pick = (trait: string) => {
		if (busy) return;
		setBusy(true);
		props.dispatch("CompanionAct", { Op: "PickTrait", Trait: trait }, () => setBusy(false));
	};
	const offer = companion.Offer;
	const g = props.stack ? 8 : 12;
	const choiceBtn = (i: number) => (
		<MockBtn text={offer![i].Name} sec={true} phone={props.stack} fill={true} disabled={busy} onClick={() => pick(offer![i].Id)} />
	);
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={props.stack} accent={Palette.mango} reducedMotion={props.reducedMotion} name="CompanionBond">
			<PanelHeading icon="Milestone" title={title} note={`Rank ${companion.Rank} · ${pct(companion.Share)}`} accent={Palette.mango} phone={props.stack} layoutOrder={0} />
			<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, 10)} LayoutOrder={1}>
				<Bar fill={atTop ? 1 : companion.Progress} color={Palette.mango} />
			</frame>
			<MockRow phone={props.stack} icon="Info" accent={Palette.mango} title={offer !== undefined ? "Trait" : "Bond"} sub={undefined} value={line} layoutOrder={2} />
			{offer !== undefined ? (
				<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, props.stack ? 44 * 2 + 8 : 44)} LayoutOrder={3}>
					<frame BackgroundTransparency={1} Size={props.stack ? new UDim2(1, 0, 0, 44) : new UDim2(0.5, -g / 2, 0, 44)}>
						{choiceBtn(0)}
					</frame>
					<frame BackgroundTransparency={1} Position={props.stack ? UDim2.fromOffset(0, 52) : new UDim2(0.5, g / 2, 0, 0)} Size={props.stack ? new UDim2(1, 0, 0, 44) : new UDim2(0.5, -g / 2, 0, 44)}>
						{choiceBtn(1)}
					</frame>
				</frame>
			) : undefined}
		</MockPanel>
	);
}
