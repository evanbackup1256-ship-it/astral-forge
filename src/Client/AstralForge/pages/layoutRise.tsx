// Two-column page sections for the Worlds, Ascension and Echoes pages. Builds on the shared
// SplitColumns/StackBlocks helpers and gives every block the same staggered rise PageScaffold
// gives a section (0.055 s apart, 0.45 s, soft back-out, 22 px), so splitting a page into
// columns keeps each section rising in turn. The split itself is one PageScaffold section (index 0),
// which PageScaffold already rises from the moment it mounts; each block subtracts that outer rise,
// so every section rises exactly once on its own staggered curve.
import React from "@rbxts/react";
import { SplitColumns, SplitPlan, StackBlocks, stackHeight } from "../UiCore/ui";
import { balanceColumns, ComposeSpec, planComposition, ZoneRect } from "../UiCore/layoutEngine";

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
export function splitSection(name: string, plan: SplitPlan, gap: number, sideIn: PageBlock[], mainIn: PageBlock[], sideOnRight: boolean, order: string[]): PageBlock {
	// side by side, uneven columns trade tail blocks so neither leaves a tall empty gap
	const [side, main] = plan.split ? balanceColumns(sideIn, mainIn, gap) : [sideIn, mainIn];
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

// ---------------------------------------------------------------------------------------------
// ComposedPage: renders a planComposition (UiCore/layoutEngine) as one scaffold section of
// absolutely placed zones. Every zone keeps the shared staggered rise (RiseIn), in reading order:
// hero, primary, secondary, tiles, footer.
// ---------------------------------------------------------------------------------------------
export interface ComposeBlocks {
	hero?: PageBlock[];
	primary: PageBlock[];
	secondary?: PageBlock[];
	tiles?: PageBlock[];
	footer?: PageBlock[];
}
export function composeSection(name: string, estimate: number, gap: number, blocks: ComposeBlocks, options: Omit<ComposeSpec, "hero" | "primary" | "secondary" | "tiles" | "footer">): PageBlock {
	const heights = (list?: PageBlock[]) => (list ?? []).map((block) => block.height);
	// plan against the section's real width (the scaffold reserves the scrollbar and a gutter),
	// not the viewport estimate, so no zone runs under the scrollbar
	return { id: name, height: planComposition(estimate, gap, { ...options, hero: heights(blocks.hero), primary: heights(blocks.primary), secondary: heights(blocks.secondary), tiles: heights(blocks.tiles), footer: heights(blocks.footer) }).height, element: <ComposedZones key={name} name={name} estimate={estimate} gap={gap} blocks={blocks} options={options} /> };
}

function ComposedZones(props: { name: string; estimate: number; gap: number; blocks: ComposeBlocks; options: Omit<ComposeSpec, "hero" | "primary" | "secondary" | "tiles" | "footer"> }) {
	const { gap, blocks, options } = props;
	const hostRef = React.useRef<Frame>();
	const [width, setWidth] = React.useState(props.estimate);
	React.useEffect(() => {
		const host = hostRef.current;
		if (host === undefined) return undefined;
		const sync = () => {
			const measured = math.floor(host.AbsoluteSize.X);
			if (measured > 0) setWidth(measured);
		};
		sync();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
		return () => connection.Disconnect();
	}, []);
	const heights = (list?: PageBlock[]) => (list ?? []).map((block) => block.height);
	const plan = planComposition(width, gap, {
		...options,
		hero: heights(blocks.hero),
		primary: heights(blocks.primary),
		secondary: heights(blocks.secondary),
		tiles: heights(blocks.tiles),
		footer: heights(blocks.footer),
	});
	const lists: Record<ZoneRect["role"], PageBlock[]> = {
		hero: blocks.hero ?? [],
		primary: blocks.primary,
		secondary: blocks.secondary ?? [],
		tiles: blocks.tiles ?? [],
		footer: blocks.footer ?? [],
	};
	const children: Record<string, React.Element> = {};
	plan.rects.forEach((rect, order) => {
		const block = lists[rect.role][rect.index];
		if (block === undefined) return;
		children[`${rect.role}-${block.id}`] = (
			<frame
				Size={UDim2.fromOffset(rect.w, rect.h)}
				Position={UDim2.fromOffset(rect.x, rect.y)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				SelectionGroup={rect.role === "secondary" || rect.role === "primary"}
			>
				<RiseIn index={order}>{block.element}</RiseIn>
			</frame>
		);
	});
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			{children}
		</frame>
	);
}
