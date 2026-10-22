import React from "@rbxts/react";
import { ClientLog } from "../../CoreKit/log";
import { useStagger } from "../../MotionKit/motion";
import { EmptyState } from "../design/Layers";
import { usePageEntry, useRegion } from "../input/input";
import { labelOf, PageProps, pageFor } from "./routes";

interface BoundaryProps {
	page: string;
	phone: boolean;
	children?: React.ReactNode;
}

interface BoundaryState {
	failed: boolean;
}

// A roblox-ts class only becomes a real React-Lua component through @React.ReactComponent; without it
// the compiled constructor calls a nil super.constructor and every page render throws.
@React.ReactComponent
class PageBoundary extends React.Component<BoundaryProps, BoundaryState> {
	state: BoundaryState = { failed: false };

	static getDerivedStateFromError(this: void): BoundaryState {
		return { failed: true };
	}

	componentDidCatch(err: unknown, info: { componentStack?: unknown }) {
		let message = tostring(err);
		let stack = "";
		if (typeIs(err, "table")) {
			const e = err as { message?: unknown; stack?: unknown };
			if (e.message !== undefined) message = tostring(e.message);
			if (typeIs(e.stack, "string")) stack = e.stack;
		}
		const components = typeIs(info, "table") && typeIs(info.componentStack, "string") ? info.componentStack : "";
		ClientLog.warnEvery(`forge2-page-${this.props.page}`, 5, "React", `Forge2 page ${this.props.page} failed: ${message}\n${stack}${components}`);
	}

	componentDidUpdate(previous: BoundaryProps) {
		if (previous.page !== this.props.page && this.state.failed) this.setState({ failed: false });
	}

	render() {
		if (this.state.failed) {
			return <EmptyState title="This page tripped" body="Switch pages and come back. Your progress is safe." phone={this.props.phone} />;
		}
		return this.props.children as React.Element;
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
