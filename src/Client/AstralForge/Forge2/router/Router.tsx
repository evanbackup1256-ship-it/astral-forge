import React from "@rbxts/react";
import { useStagger } from "../../MotionKit/motion";
import { EmptyState } from "../design/Layers";
import { usePageEntry, useRegion } from "../input/input";
import { labelOf, PageProps, pageFor } from "./routes";

interface BoundaryProps {
	page: string;
	phone: boolean;
	children?: React.ReactNode;
}

class PageBoundary extends React.Component<BoundaryProps, { failed: boolean }> {
	constructor(props: BoundaryProps) {
		super(props);
		this.state = { failed: false };
	}
	static getDerivedStateFromError(): { failed: boolean } {
		return { failed: true };
	}
	componentDidUpdate(previous: BoundaryProps) {
		if (previous.page !== this.props.page && this.state.failed) this.setState({ failed: false });
	}
	render() {
		if (this.state.failed) {
			return <EmptyState title="This page tripped" body="Switch pages and come back. Your progress is safe." phone={this.props.phone} />;
		}
		return this.props.children;
	}
}

function PageFrame(props: { page: string; inner: PageProps }) {
	// each page arrives with the same rise + fade the old shell used, keyed so it replays per page
	const enter = useStagger(0, false, 0, 0.2);
	const Page = pageFor(props.page);
	return (
		<frame Size={UDim2.fromScale(1, 1)} Position={enter.map((p) => UDim2.fromOffset(0, (1 - p) * 14))} BackgroundTransparency={1}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uiscale Scale={enter.map((p) => 0.985 + p * 0.015)} />
				{Page !== undefined ? (
					<Page {...props.inner} />
				) : (
					<scrollingframe Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} CanvasSize={new UDim2()} ScrollBarThickness={0}>
						<uipadding PaddingTop={new UDim(0, 24)} PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
						<EmptyState
							title={labelOf(props.page)}
							body="This page is still being rebuilt for the new forge."
							phone={props.inner.phone}
							action={{ text: "Back to the forge", onPress: () => props.inner.navigate("Overview") }}
						/>
					</scrollingframe>
				)}
			</frame>
		</frame>
	);
}

/** Mounts exactly one page and registers it as the gamepad "page" region. */
export function Router(props: { page: string; inner: PageProps; size: UDim2; position: UDim2 }) {
	const region = useRegion("page");
	usePageEntry(props.page);
	return (
		<frame ref={region} Size={props.size} Position={props.position} BackgroundTransparency={1} ClipsDescendants>
			<PageBoundary page={props.page} phone={props.inner.phone}>
				<PageFrame key={props.page} page={props.page} inner={props.inner} />
			</PageBoundary>
		</frame>
	);
}
