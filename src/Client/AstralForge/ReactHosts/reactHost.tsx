import React from "@rbxts/react";
import * as reactModules from "./reactModules";
import { notePage } from "./vendorHost";
import { ClientLog } from "../CoreKit/log";
import { Palette } from "../CoreKit/theme";

interface PageHost {
	page: string;
	retry: () => void;
}

const PageHostContext = React.createContext<PageHost>({ page: "", retry: () => {} });

function onPageRender(id: string, _phase: unknown, actualDuration: unknown) {
	if (!typeIs(actualDuration, "number") || actualDuration < 20) {
		return undefined;
	}
	ClientLog.warnEvery(`react-slow-${id}`, 10, "React", `${id} commit took ${math.floor(actualDuration)}ms`);
}

class PagePending extends React.PureComponent {
	render() {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BackgroundTransparency={0.15} BorderSizePixel={0}>
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text="Loading"
					TextColor3={Palette.cream}
					TextSize={16}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
					TextXAlignment={Enum.TextXAlignment.Center}
					TextYAlignment={Enum.TextYAlignment.Center}
				/>
			</frame>
		);
	}
}

function CrashNotice(props: { message: string; onRetry?: () => void }) {
	const host = React.useContext(PageHostContext);
	const [transparency, setTransparency] = React.useBinding(1);
	const [pressed, setPressed] = React.useState(false);
	React.useDebugValue(props.message);
	reactModules.useMountEffect(() => {
		setTransparency(0);
	});
	reactModules.useTimeout(
		() => {
			setPressed(false);
		},
		pressed ? 0.45 : undefined,
	);
	const retry = React.useCallback(() => {
		setPressed(true);
		if (props.onRetry !== undefined) {
			props.onRetry();
		} else {
			host.retry();
		}
	}, [host, props.onRetry]);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BackgroundTransparency={0.08} BorderSizePixel={0}>
			<textlabel
				Size={new UDim2(1, -32, 0, 48)}
				Position={new UDim2(0.5, 0, 0.5, -36)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Text="This screen hit an error. You can open it again."
				TextColor3={Palette.cream}
				TextTransparency={transparency}
				TextSize={16}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Center}
				TextYAlignment={Enum.TextYAlignment.Center}
			/>
			<textbutton
				Size={UDim2.fromOffset(140, 36)}
				Position={new UDim2(0.5, 0, 0.5, 28)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={pressed ? Palette.panelSoft : Palette.cyan}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text="TRY AGAIN"
				TextColor3={Palette.ink}
				TextSize={14}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				Event={{ Activated: retry }}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
			</textbutton>
		</frame>
	);
}

interface BoundaryProps {
	page?: string;
	children?: React.ReactNode;
}
interface BoundaryState {
	failed: boolean;
	message: string;
}

class PageErrorBoundary extends React.Component<BoundaryProps, BoundaryState> {
	state: BoundaryState = { failed: false, message: "" };

	static getDerivedStateFromError(err: unknown): BoundaryState {
		return { failed: true, message: tostring(err) };
	}

	componentDidCatch(err: unknown, info: { componentStack?: unknown }) {
		const page = this.props.page ?? "AppShell";
		const stack = typeIs(info, "table") && typeIs(info.componentStack, "string") ? info.componentStack : "";
		ClientLog.warnEvery(`react-page-${page}`, 5, "React", `${page}: ${tostring(err)}${stack}`);
	}

	render() {
		if (this.state.failed) {
			return (
				<CrashNotice
					message={this.state.message}
					onRetry={() => {
						this.setState({ failed: false, message: "" });
					}}
				/>
			);
		}
		return this.props.children as React.Element;
	}
}

interface PageFrameProps {
	page?: string;
	children?: React.ReactNode;
}

const PageFrame = React.memo(
	React.forwardRef((props: PageFrameProps, ref: React.Ref<unknown>) => {
		let page = props.page;
		if (page === undefined) {
			page = "";
		}
		const [retryCount, bumpRetry] = React.useReducer((count: number) => count + 1, 0);
		const seenPage = React.useRef(page);
		const previousPage = reactModules.usePrevious(page);
		React.useDebugValue(previousPage !== undefined && previousPage !== "" ? `${previousPage} -> ${page}` : page);
		React.useLayoutEffect(() => {
			seenPage.current = page!;
			return () => {
				seenPage.current = "";
			};
		}, [page]);
		React.useEffect(() => {
			if (page === "") {
				return undefined;
			}
			notePage(page);
			let pending = true;
			const trailing = task.delay(0.12, () => {
				pending = false;
				notePage(page);
			});
			return () => {
				if (pending) {
					task.cancel(trailing);
				}
			};
		}, [page]);
		React.useImperativeHandle(
			ref,
			() => ({
				retry: bumpRetry,
				page: () => seenPage.current,
			}),
			[bumpRetry],
		);
		const contextValue = React.useMemo(
			() => ({ page: page!, retry: bumpRetry as unknown as () => void }),
			[page, bumpRetry],
		);
		const child = React.useMemo(() => {
			const only = React.Children.only(props.children as React.Element);
			if (!React.isValidElement(only)) {
				return only;
			}
			return React.cloneElement(only as React.Element, { key: `${page}:${retryCount}` } as never);
		}, [props.children, page, retryCount]);
		return (
			<PageHostContext.Provider value={contextValue}>
				<React.Suspense fallback={<PagePending />}>
					<PageErrorBoundary key={`${page}:${retryCount}`} page={page}>
						<React.Profiler id={page !== "" ? page : "Game"} onRender={onPageRender as never}>
							{child as React.Element}
						</React.Profiler>
					</PageErrorBoundary>
				</React.Suspense>
			</PageHostContext.Provider>
		);
	}),
);

export { PageFrame, PageErrorBoundary, PagePending };
