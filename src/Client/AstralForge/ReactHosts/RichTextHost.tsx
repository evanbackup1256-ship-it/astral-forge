import React from "@rbxts/react";
import { ClientLog } from "../CoreKit/log";
import { Palette } from "../CoreKit/theme";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface RichTextInstance {
	Destroy(): void;
	Render(text: string, a: boolean, b: boolean, c: boolean): void;
	onRenderEnded?: { Event: RBXScriptSignal };
}
interface RichTextModule {
	new: (this: void, host: Instance, options: Record<string, unknown>) => RichTextInstance;
}

let cachedModule: RichTextModule | undefined;
let loadFailed = false;
let pendingWarned = false;

function resolveModuleScript(node: Instance): ModuleScript | undefined {
	if (node.IsA("ModuleScript")) {
		return node;
	}
	const initChild = node.FindFirstChild("init");
	if (initChild !== undefined && initChild.IsA("ModuleScript")) {
		return initChild;
	}
	return undefined;
}

function loadRichTextModule(): RichTextModule | undefined {
	if (cachedModule !== undefined) {
		return cachedModule;
	}
	if (loadFailed) {
		return undefined;
	}
	const astral = ReplicatedStorage.FindFirstChild("AstralForge");
	const vendor = astral?.FindFirstChild("Vendor");
	const node = vendor?.FindFirstChild("RichText");
	if (node === undefined) {
		if (!pendingWarned) {
			pendingWarned = true;
			ClientLog.warnEvery(
				"richtext-root",
				15,
				"richtext",
				"ReplicatedStorage.AstralForge.Vendor.RichText is not replicated yet",
			);
		}
		return undefined;
	}
	const moduleScript = resolveModuleScript(node);
	if (moduleScript === undefined) {
		ClientLog.warn("richtext", `RichText is a ${node.ClassName}, not a ModuleScript`);
		loadFailed = true;
		return undefined;
	}
	const [ok, result] = pcall(() => require(moduleScript));
	if (!ok || result === undefined || !typeIs((result as { new?: unknown }).new, "function")) {
		ClientLog.warn("richtext", `couldn't load RichText: ${tostring(result)}`);
		loadFailed = true;
		return undefined;
	}
	cachedModule = result as RichTextModule;
	pendingWarned = false;
	return cachedModule;
}

interface ScriptedTextProps {
	text: string;
	width: number;
	height: number;
	size?: number;
	color?: Color3;
	weight?: Enum.FontWeight;
	italic?: boolean;
	align?: Enum.HorizontalAlignment;
	typewriterInterval?: number;
	typewriterSoundId?: string;
	animation?: string;
	animationDuration?: number;
	effect?: string;
	reducedMotion?: boolean;
	position?: UDim2;
	zIndex?: number;
	layoutOrder?: number;
	renderKey?: unknown;
	onRenderEnded?: () => void;
}

function ScriptedText(props: ScriptedTextProps) {
	const text = props.text;
	const width = props.width;
	const height = props.height;
	const size = props.size ?? 15;
	const color = props.color ?? Palette.creamSoft;
	const weight = props.weight ?? Enum.FontWeight.Medium;
	const italic = props.italic ?? false;
	const align = props.align ?? Enum.HorizontalAlignment.Left;
	const typewriterInterval = props.typewriterInterval ?? 0.015;
	const typewriterSoundId = props.typewriterSoundId;
	const animation = props.animation ?? "None";
	const animationDuration = props.animationDuration ?? 0.125;
	const effect = props.effect ?? "None";
	const reducedMotion = props.reducedMotion ?? false;
	const position = props.position;
	const zIndex = props.zIndex ?? 1;
	const layoutOrder = props.layoutOrder ?? 0;
	const renderKey = props.renderKey;
	const onRenderEnded = props.onRenderEnded;
	const hostRef = React.useRef<Frame>();
	const richRef = React.useRef<RichTextInstance>();
	const fallbackRef = React.useRef<TextLabel>();
	const [live, setLive] = React.useState(false);
	const destroy = React.useCallback(() => {
		const rich = richRef.current;
		richRef.current = undefined;
		if (rich !== undefined) {
			pcall(() => {
				rich.Destroy();
			});
		}
		setLive(false);
	}, []);
	React.useEffect(() => {
		if (reducedMotion || text === "") {
			destroy();
			return undefined;
		}
		let cancelled = false;
		let attempts = 0;
		let retryJob: thread | undefined;
		const tryMount = (): undefined => {
			if (cancelled) {
				return undefined;
			}
			attempts += 1;
			const host = hostRef.current;
			const mod = loadRichTextModule();
			if (host === undefined || mod === undefined) {
				if (attempts < 50) {
					retryJob = task.delay(0.1, tryMount);
				}
				return undefined;
			}
			const fallback = fallbackRef.current;
			if (fallback !== undefined) {
				fallback.Visible = false;
			}
			const rich = mod.new(host, {
				Color: color,
				Size: size,
				XAlign: align,
				YAlign: Enum.VerticalAlignment.Top,
				TypewriterInterval: typewriterInterval,
				TypewriterSoundId: typewriterSoundId,
				Animation: animation,
				AnimationDuration: animationDuration,
				AnimationLoop: false,
				Effect: effect,
				Weight: weight,
				Italic: italic,
				Transparency: 0,
			});
			richRef.current = rich;
			setLive(true);
			if (onRenderEnded !== undefined && rich.onRenderEnded !== undefined) {
				rich.onRenderEnded.Event.Once(() => {
					if (!cancelled) {
						onRenderEnded();
					}
				});
			}
			rich.Render(text, false, true, false);
			return undefined;
		};
		const mountJob = task.defer(tryMount);
		return () => {
			cancelled = true;
			pcall(task.cancel, mountJob);
			if (retryJob !== undefined) {
				pcall(task.cancel, retryJob);
			}
			destroy();
		};
	}, [renderKey, reducedMotion, text, destroy]);
	const showFallback = reducedMotion || !live || text === "";
	return (
		<frame
			Size={UDim2.fromOffset(width, height)}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
			ClipsDescendants={false}
		>
			<frame
				ref={hostRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ZIndex={zIndex + 1}
			/>
			{showFallback && (
				<textlabel
					ref={fallbackRef}
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text={text}
					TextColor3={color}
					TextSize={size}
					FontFace={Font.fromEnum(
						weight === Enum.FontWeight.Heavy
							? Enum.Font.BuilderSansExtraBold
							: weight === Enum.FontWeight.Bold
								? Enum.Font.BuilderSansBold
								: Enum.Font.BuilderSansMedium,
					)}
					TextXAlignment={
						align === Enum.HorizontalAlignment.Center
							? Enum.TextXAlignment.Center
							: align === Enum.HorizontalAlignment.Right
								? Enum.TextXAlignment.Right
								: Enum.TextXAlignment.Left
					}
					TextYAlignment={Enum.TextYAlignment.Top}
					TextWrapped={true}
					LineHeight={1.12}
					ZIndex={zIndex}
				/>
			)}
		</frame>
	);
}

export { ScriptedText };
