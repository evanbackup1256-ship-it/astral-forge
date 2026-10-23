// Journal: routed from the side nav and the phone More sheet. The full screen (design/19-journal) ports later;
// until then the route shows a placeholder card.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { PlaceholderPage } from "./routePlaceholder";

interface JournalViewProps {
	navigate?: (page: string) => unknown;
	reducedMotion?: boolean;
}

function JournalView(props: JournalViewProps) {
	return (
		<PlaceholderPage
			id="Journal"
			icon="Journal.1"
			title="Journal"
			body="Milestones and forge records will be listed here."
			accent={Palette.mango}
			navigate={props.navigate}
			reducedMotion={props.reducedMotion}
		/>
	);
}

export = () => ({ JournalView });
