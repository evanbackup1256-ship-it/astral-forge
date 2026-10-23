// Season: routed from the side nav and the phone More sheet. The full screen (design/16-season) ports later;
// until then the route shows a placeholder card.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { PlaceholderPage } from "./routePlaceholder";

interface SeasonViewProps {
	navigate?: (page: string) => unknown;
	reducedMotion?: boolean;
}

function SeasonView(props: SeasonViewProps) {
	return (
		<PlaceholderPage
			id="Season"
			icon="Season.1"
			title="Season"
			body="The season track opens with the next season."
			accent={Palette.violet}
			navigate={props.navigate}
			reducedMotion={props.reducedMotion}
		/>
	);
}

export = () => ({ SeasonView });
