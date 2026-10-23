// Companions: routed from the side nav and the phone More sheet. The full screen (design/14-companions) ports later;
// until then the route shows a placeholder card.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { PlaceholderPage } from "./routePlaceholder";

interface CompanionsViewProps {
	navigate?: (page: string) => unknown;
	reducedMotion?: boolean;
}

function CompanionsView(props: CompanionsViewProps) {
	return (
		<PlaceholderPage
			id="Companions"
			icon="Companion.1"
			title="Companions"
			body="Companions arrive in a coming update."
			accent={Palette.mint}
			navigate={props.navigate}
			reducedMotion={props.reducedMotion}
		/>
	);
}

export = () => ({ CompanionsView });
