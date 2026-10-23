// Two-column page sections for the Worlds, Ascension and Echoes pages. Builds on the shared
// SplitColumns/StackBlocks helpers and gives every block the same staggered rise PageScaffold
// gives a section (0.055 s apart, 0.45 s, soft back-out, 22 px), so splitting a page into
// columns keeps each section rising in turn. The split itself is one PageScaffold section (index 0),
// which PageScaffold already rises from the moment it mounts; each block subtracts that outer rise,
// so every section rises exactly once on its own staggered curve.
import React from "@rbxts/react";
import { SplitColumns, SplitPlan, StackBlocks, stackHeight } from "../UiCore/ui";

const RunService = game.GetService("RunService");

function easeOutBackSoft(x: number): number {
	const c1 = 1.2;
	const c3 = 2.2;
	return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
}

export function RiseIn(props: { index: number; children?: React.ReactNode }) {
	// net offset in px: this block's own rise minus the enclosing scaffold section's rise
	const [amount, setAmount] = React.useBinding(0);
	const riseRef = React.useRef<Frame>();
	React.useEffect(() => {
		const mounted = os.clock();
		const start = mounted + math.min(props.index, 8) * 0.055;
		riseRef.current?.SetAttribute("LayoutInMotion", true);
		const connection = RunService.RenderStepped.Connect(() => {
			const now = os.clock();
			const t = math.clamp((now - start) / 0.45, 0, 1);
			const outer = math.clamp((now - mounted) / 0.45, 0, 1);
			setAmount(math.round((1 - easeOutBackSoft(t)) * 22) - math.round((1 - easeOutBackSoft(outer)) * 22));
			if (t >= 1) {
				connection.Disconnect();
				riseRef.current?.SetAttribute("LayoutInMotion", undefined);
			}
		});
		return () => {
			if (connection.Connected) connection.Disconnect();
		};
	}, []);
	return (
		<frame
			ref={riseRef}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Position={amount.map((offset) => UDim2.fromOffset(0, offset))}
		>
			{props.children}
		</frame>
	);
}

export interface PageBlock {
	id: string;
	height: number;
	element: React.Element;
}

/** One scaffold section holding two columns of blocks; block order follows `order` so the rise staggers like a single list. */
export function splitSection(name: string, plan: SplitPlan, gap: number, side: PageBlock[], main: PageBlock[], sideOnRight: boolean, order: string[]): PageBlock {
	const risen = (blocks: PageBlock[]) =>
		blocks.map((block) => ({
			id: block.id,
			height: block.height,
			element: <RiseIn index={math.max(0, order.indexOf(block.id))}>{block.element}</RiseIn>,
		}));
	const height = math.max(stackHeight(side.map((b) => b.height), gap), stackHeight(main.map((b) => b.height), gap));
	return {
		id: name,
		height,
		element: (
			<SplitColumns
				name={name}
				height={height}
				plan={plan}
				sideOnRight={sideOnRight}
				side={<StackBlocks gap={gap} blocks={risen(side)} />}
				main={<StackBlocks gap={gap} blocks={risen(main)} />}
			/>
		),
	};
}
