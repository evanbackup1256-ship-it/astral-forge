import React from "@rbxts/react";

// Additive layout helper for the page-layout rebuild: a desktop side column + main column.
// Pages decide when to split (see splitFor); on phones and narrow windows they keep their
// single-column scaffold, so nothing here changes the mobile layout.

const SPLIT_MIN_WIDTH = 1100;
const SPLIT_SIDE_WIDTH = 360;
const SPLIT_GAP = 18;

export interface SplitPlan {
	split: boolean;
	sideWidth: number;
	gap: number;
}

export function splitFor(viewport: { width: number }, stack: boolean, minWidth = SPLIT_MIN_WIDTH): SplitPlan {
	const split = !stack && viewport.width >= minWidth;
	const sideWidth = viewport.width >= 1600 ? 400 : SPLIT_SIDE_WIDTH;
	return { split, sideWidth, gap: SPLIT_GAP };
}

export interface SideStackItem {
	id: string;
	height: number;
	element: React.Element;
}

export function sideStackHeight(items: SideStackItem[], gap: number): number {
	let total = 0;
	items.forEach((item, index) => {
		total += item.height + (index > 0 ? gap : 0);
	});
	return total;
}

// Two columns in one scaffold section. The side column is a SelectionGroup so gamepad
// focus stays with its controls until the player moves right into the main column.
export function SplitColumns(props: {
	plan: SplitPlan;
	side: SideStackItem[];
	main: React.Element;
	name?: string;
}) {
	const { plan, side, main } = props;
	const gap = plan.gap;
	const children: Record<string, React.Element> = {};
	side.forEach((item, index) => {
		children[item.id] = (
			<frame
				LayoutOrder={index}
				Size={new UDim2(1, 0, 0, item.height)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				{item.element}
			</frame>
		);
	});
	return (
		<frame
			key={props.name ?? "Split"}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
		>
			<frame
				key="Side"
				Size={new UDim2(0, plan.sideWidth, 1, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				SelectionGroup={true}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, gap)} />
				{children}
			</frame>
			<frame
				key="Main"
				Size={new UDim2(1, -(plan.sideWidth + gap), 1, 0)}
				Position={UDim2.fromOffset(plan.sideWidth + gap, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				SelectionGroup={true}
			>
				{main}
			</frame>
		</frame>
	);
}

// Folds a page's scaffold sections into one two-column section when the plan splits: every
// section before the last `mainCount` goes to the side column, the rest stack in the main column.
export function splitSections<S extends { id: string; height: number; element: React.Element }>(
	plan: SplitPlan,
	sections: S[],
	name: string,
	mainCount = 1,
): Array<{ id: string; height: number; element: React.Element }> {
	if (!plan.split || sections.size() <= mainCount) {
		return sections;
	}
	const cut = sections.size() - mainCount;
	const side = sections.filter((_, index) => index < cut);
	const mainItems = sections.filter((_, index) => index >= cut);
	const mainH = sideStackHeight(mainItems, plan.gap);
	const main =
		mainItems.size() === 1 ? (
			mainItems[0].element
		) : (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, plan.gap)} />
				{mainItems.map((item, index) => (
					<frame
						key={item.id}
						LayoutOrder={index}
						Size={new UDim2(1, 0, 0, item.height)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
					>
						{item.element}
					</frame>
				))}
			</frame>
		);
	return [
		{
			id: `${name}-split`,
			height: math.max(sideStackHeight(side, plan.gap), mainH),
			element: <SplitColumns plan={plan} side={side} main={main} name={name} />,
		},
	];
}
