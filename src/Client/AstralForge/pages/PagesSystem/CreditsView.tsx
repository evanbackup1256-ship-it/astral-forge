// Credits route (design/21-credits): the page body; the roll itself lives in UiCore/CreditsView.
import React from "@rbxts/react";
import { CreditsPage } from "../../UiCore/CreditsView";

export function CreditsView(props: { state: { Game?: { Version?: string } }; reducedMotion?: boolean }) {
	return <CreditsPage version={props.state.Game?.Version} reducedMotion={props.reducedMotion} />;
}
