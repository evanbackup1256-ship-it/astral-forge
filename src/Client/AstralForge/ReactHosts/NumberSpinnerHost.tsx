import React from "@rbxts/react";
import { compactSpinParts } from "../CoreKit/format";
import { ClientLog } from "../CoreKit/log";
import { useMotionSettings } from "../MotionKit/motion";
import { lighten, Palette } from "../CoreKit/theme";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

const AUTO_WIDTH_PAD = 4;
function estimateLabelWidth(text: string, textSize: number): number {
	return math.max(4, math.ceil(text.size() * textSize * 0.7)) + AUTO_WIDTH_PAD;
}
// Builder Sans digits are even-width, so values roll cleanly without the gappy look of a monospace dot
const SPINNER_FONT = Font.fromEnum(Enum.Font.BuilderSansBold);

function findSpinnerLayout(host: Instance): UIListLayout | undefined {
	for (const child of host.GetChildren()) {
		if (!child.IsA("GuiObject") || child.Name === "NumberSpinnerGuide") {
			continue;
		}
		const layout = child.FindFirstChildOfClass("UIListLayout");
		if (layout !== undefined) {
			return layout;
		}
	}
	return undefined;
}

function hugSpinnerContent(host: Instance): UIListLayout | undefined {
	for (const child of host.GetChildren()) {
		if (!child.IsA("GuiObject") || child.Name === "NumberSpinnerGuide") {
			continue;
		}
		const layout = child.FindFirstChildOfClass("UIListLayout");
		if (layout === undefined) {
			continue;
		}
		if (child.AutomaticSize !== Enum.AutomaticSize.X) {
			child.AutomaticSize = Enum.AutomaticSize.X;
		}
		const hug = new UDim2(0, 0, 1, 0);
		if (child.Size !== hug) {
			child.Size = hug;
		}
		if (!child.ClipsDescendants) {
			child.ClipsDescendants = true;
		}
		return layout;
	}
	return undefined;
}

// The NumberSpinner library object: a table proxying a Frame, not an Instance.
interface Spinner {
	Frame: Frame;
	Layout: UIListLayout;
	Duration: number;
	Decimals: number;
	Prefix: string;
	Suffix: string;
	TextSize: number;
	TextColor3: Color3;
	TextStrokeTransparency: number;
	TextStrokeColor3: Color3;
	FontFace: Font;
	TextXAlignment: Enum.TextXAlignment;
	Commas: boolean;
	ClipsDescendants: boolean;
	Value: number;
	Parent?: Instance;
	Size: UDim2;
	Position: UDim2;
	BackgroundTransparency: number;
	AutomaticSize: Enum.AutomaticSize;
	Destroy(): void;
}
interface SpinnerModule {
	new: (this: void) => Spinner;
	fromGuiObject?: (this: void, guide: GuiObject) => Spinner | undefined;
}

const SPINNER_RS_PATH = "ReplicatedStorage.AstralForge.Shared.NumberSpinner";
let cachedModule: SpinnerModule | undefined;
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

function childNames(parent: Instance): string {
	const names: string[] = [];
	for (const child of parent.GetChildren()) {
		names.push(child.Name);
	}
	return names.size() > 0 ? names.join(", ") : "(none)";
}

function loadModule(): SpinnerModule | undefined {
	if (cachedModule !== undefined) {
		return cachedModule;
	}
	if (loadFailed) {
		return undefined;
	}
	const astral = ReplicatedStorage.FindFirstChild("AstralForge");
	if (astral === undefined) {
		if (!pendingWarned) {
			pendingWarned = true;
			ClientLog.warnEvery("spinner-root", 15, "spinner", `${SPINNER_RS_PATH} is not replicated`);
		}
		return undefined;
	}
	const sharedFolder = astral.FindFirstChild("Shared");
	if (sharedFolder === undefined) {
		if (!pendingWarned) {
			pendingWarned = true;
			ClientLog.warnEvery("spinner-shared", 15, "spinner", `Shared folder missing (have ${childNames(astral)})`);
		}
		return undefined;
	}
	const node = sharedFolder.FindFirstChild("NumberSpinner");
	if (node === undefined) {
		if (!pendingWarned) {
			pendingWarned = true;
			ClientLog.warnEvery("spinner-module", 15, "spinner", `NumberSpinner missing (have ${childNames(sharedFolder)})`);
		}
		return undefined;
	}
	const moduleScript = resolveModuleScript(node);
	if (moduleScript === undefined) {
		ClientLog.warn("spinner", `NumberSpinner is a ${node.ClassName}, not a ModuleScript`);
		loadFailed = true;
		return undefined;
	}
	const [ok, result] = pcall(() => require(moduleScript));
	if (!ok || result === undefined) {
		ClientLog.warn("spinner", `couldn't load NumberSpinner: ${tostring(result)}`);
		loadFailed = true;
		return undefined;
	}
	if (!typeIs((result as { new?: unknown }).new, "function")) {
		ClientLog.warn("spinner", "loaded module has no constructor");
		loadFailed = true;
		return undefined;
	}
	cachedModule = result as SpinnerModule;
	pendingWarned = false;
	return cachedModule;
}

function sanitizeValue(value: unknown, decimals: number): number {
	if (!typeIs(value, "number") || value !== value || value === math.huge || value === -math.huge) {
		return 0;
	}
	const capped = math.clamp(value, -1e100, 1e100);
	if (decimals <= 0) {
		return math.floor(capped + (capped >= 0 ? 0.5 : -0.5));
	}
	const factor = 10 ** decimals;
	return math.floor(capped * factor + (capped >= 0 ? 0.5 : -0.5)) / factor;
}

interface SpinDisplay {
	value: number;
	suffix: string;
	decimals: number;
	band: string;
}

function spinDisplay(raw: unknown, extraSuffix: string, spacedSuffix: boolean): SpinDisplay {
	const parts = compactSpinParts(raw);
	const lead = spacedSuffix && parts.suffix !== "" ? " " : "";
	return {
		value: parts.value,
		suffix: `${lead}${parts.suffix}${extraSuffix}`,
		decimals: parts.decimals,
		band: parts.suffix,
	};
}

function formatRawLabel(value: unknown, prefix: string, extraSuffix: string, spacedSuffix: boolean): string {
	const display = spinDisplay(value, extraSuffix, spacedSuffix);
	const amount = sanitizeValue(display.value, display.decimals);
	const abs = math.abs(amount);
	const body = string.format(display.decimals <= 0 ? "%.0f" : display.decimals === 1 ? "%.1f" : "%.2f", abs);
	return `${prefix}${amount < 0 ? "-" : ""}${body}${display.suffix}`;
}

interface Chrome {
	duration: number;
	decimals: number;
	prefix: string;
	suffix: string;
	size: number;
	color: Color3;
	align: Enum.TextXAlignment;
}

function applyChrome(spinner: Spinner, opts: Chrome) {
	if (spinner.Duration !== opts.duration) {
		spinner.Duration = opts.duration;
	}
	if (spinner.Decimals !== opts.decimals) {
		spinner.Decimals = opts.decimals;
	}
	spinner.Prefix = opts.prefix;
	spinner.Suffix = opts.suffix;
	spinner.TextSize = opts.size;
	spinner.TextColor3 = opts.color;
	spinner.TextStrokeTransparency = 1;
	spinner.TextStrokeColor3 = Color3.fromRGB(0, 0, 0);
	spinner.FontFace = SPINNER_FONT;
	spinner.TextXAlignment = opts.align;
	spinner.Commas = false;
	spinner.ClipsDescendants = true;
}

// Digit cells follow the spinner font's real advance. Builder Sans Bold digits measure 0.51 em
// ("0" is 7.2px at 14), so a 0.52 em cell sits each digit snugly; the old 10px default cell left
// visible gaps ("1 3.7"). NumberSpinner builds digit frames after Value changes, so every new
// digit is sized as it is added, not only the ones present when Value was set.
function digitCellWidth(spinner: Spinner, scale: number | undefined): number {
	const base = math.max(5, math.ceil(spinner.TextSize * 0.52));
	return math.max(5, math.floor(base * math.clamp(scale ?? 1, 0.65, 1.15) + 0.5));
}

function sizeDigit(child: Instance, width: number) {
	if (child.IsA("Frame") && child.Name === "digit") {
		const nextSize = UDim2.fromOffset(width, child.Size.Y.Offset);
		if (child.Size !== nextSize) {
			child.Size = nextSize;
		}
	}
}

// the spinner is a library object, not an Instance, so its cell width lives here
const digitWidths = setmetatable(new Map<Spinner, number>(), { __mode: "k" });

function setDigitTracking(spinner: Spinner, scale: number | undefined, gap: number | undefined) {
	const padding = new UDim(0, math.clamp(math.floor(gap ?? 0), -3, 6));
	if (spinner.Layout.Padding !== padding) {
		spinner.Layout.Padding = padding;
	}
	const width = digitCellWidth(spinner, scale);
	const watching = digitWidths.get(spinner) !== undefined;
	digitWidths.set(spinner, width);
	for (const child of spinner.Frame.GetChildren()) {
		sizeDigit(child, width);
	}
	if (!watching) {
		spinner.Frame.ChildAdded.Connect((child) => {
			task.defer(() => {
				const current = digitWidths.get(spinner);
				if (typeIs(current, "number") && child.Parent !== undefined) {
					sizeDigit(child, current);
				}
			});
		});
	}
}

function rollDurationForJump(
	base: number,
	fromRaw: number,
	toRaw: number,
	fromBand: string,
	toBand: string,
	motionScale: number | undefined,
): number {
	const scale = math.clamp(motionScale === undefined ? 1 : motionScale, 0.35, 1.35);
	if (fromBand !== toBand) {
		return 0.04 * scale;
	}
	const jump = math.abs(toRaw - fromRaw);
	const magnitude = math.log10(math.max(1, jump));
	const rel = fromRaw > 0 ? jump / fromRaw : jump;
	if (magnitude >= 6 || rel >= 0.35) {
		return 0.08 * scale;
	}
	if (magnitude >= 4 || rel >= 0.12) {
		return 0.16 * scale;
	}
	const fromParts = compactSpinParts(fromRaw);
	const toParts = compactSpinParts(toRaw);
	const mantJump = math.abs(toParts.value - fromParts.value);
	if (mantJump >= 50) {
		return 0.14 * scale;
	}
	if (mantJump >= 8) {
		return 0.24 * scale;
	}
	return math.clamp(base * 0.62 * scale, 0.26, 0.33);
}

const VELOCITY_TICK_HZ = 5;
const VELOCITY_TICK_DT = 1 / VELOCITY_TICK_HZ;

const velocitySteps = new Set<() => void>();
let velocityStepCount = 0;
let velocityWorker: thread | undefined;

function registerVelocityStep(step: () => void): () => void {
	velocitySteps.add(step);
	velocityStepCount += 1;
	if (velocityWorker === undefined) {
		velocityWorker = task.spawn(() => {
			while (velocityStepCount > 0) {
				task.wait(VELOCITY_TICK_DT);
				for (const each of velocitySteps) {
					pcall(each);
				}
			}
			velocityWorker = undefined;
		});
	}
	return () => {
		if (velocitySteps.has(step)) {
			velocitySteps.delete(step);
			velocityStepCount -= 1;
		}
	};
}

const VELOCITY_ROLL = 0.07;

interface NumberSpinnerProps {
	value: number;
	reducedMotion?: boolean;
	duration?: number;
	prefix?: string;
	extraSuffix?: string;
	spacedSuffix?: boolean;
	decimals?: number;
	velocity?: number;
	size?: number;
	color?: Color3;
	align?: Enum.TextXAlignment;
	position?: UDim2;
	sizeConstraint?: UDim2;
	autoWidth?: boolean;
	digitWidthScale?: number;
	digitGap?: number;
	zIndex?: number;
	layoutOrder?: number;
}

interface Style {
	duration: number;
	prefix: string;
	extraSuffix: string;
	spacedSuffix: boolean;
	size: number;
	color: Color3;
	align: Enum.TextXAlignment;
	digitWidthScale: number;
	digitGap: number;
}

interface QuietChrome {
	size?: number;
	color?: Color3;
	align?: Enum.TextXAlignment;
	prefix?: string;
	suffix?: string;
}

function NumberSpinnerHost(props: NumberSpinnerProps) {
	const value = props.value;
	const requestedReducedMotion = props.reducedMotion ?? false;
	const duration = props.duration ?? 0.78;
	const prefix = props.prefix ?? "";
	const extraSuffix = props.extraSuffix ?? "";
	const spacedSuffix = props.spacedSuffix ?? false;
	const velocity = props.velocity ?? 0;
	const size = props.size ?? 16;
	const color = props.color ?? Palette.white;
	const align = props.align ?? Enum.TextXAlignment.Left;
	const position = props.position;
	const sizeConstraint = props.sizeConstraint ?? UDim2.fromScale(1, 1);
	const autoWidth = props.autoWidth ?? false;
	const digitWidthScale = props.digitWidthScale ?? 1;
	const digitGap = props.digitGap ?? 0;
	const zIndex = props.zIndex ?? 1;
	const layoutOrder = props.layoutOrder ?? 0;
	const motion = useMotionSettings();
	const numberScale = (motion.numberScale as number | undefined) ?? 1;
	const motionScale = motion.motionScale ?? 1;
	const reducedMotion = requestedReducedMotion || numberScale <= 0.02;
	const hostRef = React.useRef<Frame>();
	const spinnerRef = React.useRef<Spinner>();
	const guideRef = React.useRef<TextLabel>();
	const fallbackRef = React.useRef<TextLabel>();
	const lastRawRef = React.useRef<number | undefined>(undefined);
	const lastBandRef = React.useRef("");
	const lastMantissaRef = React.useRef<number | undefined>(undefined);
	const targetRef = React.useRef(value);
	const velocityRef = React.useRef(velocity);
	const autoWidthRef = React.useRef(autoWidth);
	const styleRef = React.useRef<Style>({
		duration,
		prefix,
		extraSuffix,
		spacedSuffix,
		size,
		color,
		align,
		digitWidthScale,
		digitGap,
	});
	const velocitySnapRef = React.useRef(false);
	const pulseResetRef = React.useRef<thread>();
	const motionScaleRef = React.useRef(motionScale);
	motionScaleRef.current = motionScale;
	const [live, setLive] = React.useState(false);
	const label = formatRawLabel(value, prefix, extraSuffix, spacedSuffix);
	const [contentWidth, setContentWidth] = React.useState(() => estimateLabelWidth(label, size));
	const contentWidthRef = React.useRef(contentWidth);
	const quietChromeRef = React.useRef<QuietChrome>({
		size: undefined,
		color: undefined,
		align: undefined,
		prefix: undefined,
		suffix: undefined,
	});
	targetRef.current = value;
	velocityRef.current = velocity;
	autoWidthRef.current = autoWidth;
	styleRef.current = {
		duration,
		prefix,
		extraSuffix,
		spacedSuffix,
		size,
		color,
		align,
		digitWidthScale,
		digitGap,
	};
	const pulseAccent = React.useCallback((spinner: Spinner, base: Color3) => {
		if (pulseResetRef.current !== undefined) {
			pcall(task.cancel, pulseResetRef.current);
		}
		spinner.TextColor3 = lighten(base, 0.48);
		pulseResetRef.current = task.delay(0.18, () => {
			pulseResetRef.current = undefined;
			if (spinnerRef.current !== spinner) {
				return undefined;
			}
			spinner.TextColor3 = styleRef.current.color;
		});
	}, []);
	const destroySpinner = React.useCallback(() => {
		if (pulseResetRef.current !== undefined) {
			pcall(task.cancel, pulseResetRef.current);
			pulseResetRef.current = undefined;
		}
		const spinner = spinnerRef.current;
		spinnerRef.current = undefined;
		lastRawRef.current = undefined;
		lastMantissaRef.current = undefined;
		lastBandRef.current = "";
		if (spinner !== undefined) {
			const frame = spinner.Frame as unknown;
			const [destroyed] = pcall(() => {
				spinner.Destroy();
			});
			if (!destroyed && typeIs(frame, "Instance")) {
				pcall(() => {
					frame.Destroy();
				});
			}
		}
		const guide = guideRef.current;
		if (guide !== undefined) {
			guide.Destroy();
			guideRef.current = undefined;
		}
		const fallback = fallbackRef.current;
		if (fallback !== undefined) {
			fallback.Visible = true;
			fallback.TextTransparency = 0;
		}
		setLive(false);
	}, []);
	const pushDisplay = React.useCallback(
		(spinner: Spinner, raw: number, roll: number, pulse: boolean) => {
			const style = styleRef.current;
			const display = spinDisplay(raw, style.extraSuffix, style.spacedSuffix);
			const mantissa = sanitizeValue(display.value, display.decimals);
			const prevMantissa = lastMantissaRef.current;
			const bandChanged = lastBandRef.current !== display.band;
			lastRawRef.current = raw;
			if (prevMantissa === mantissa && !bandChanged) {
				const quiet = quietChromeRef.current;
				if (quiet.size !== style.size) {
					spinner.TextSize = style.size;
					quiet.size = style.size;
				}
				if (quiet.color !== style.color) {
					spinner.TextColor3 = style.color;
					quiet.color = style.color;
				}
				if (quiet.align !== style.align) {
					spinner.TextXAlignment = style.align;
					quiet.align = style.align;
				}
				if (quiet.prefix !== style.prefix) {
					spinner.Prefix = style.prefix;
					quiet.prefix = style.prefix;
				}
				if (quiet.suffix !== display.suffix) {
					spinner.Suffix = display.suffix;
					quiet.suffix = display.suffix;
				}
				return undefined;
			}
			applyChrome(spinner, {
				duration: roll,
				decimals: display.decimals,
				prefix: style.prefix,
				suffix: display.suffix,
				size: style.size,
				color: style.color,
				align: style.align,
			});
			lastBandRef.current = display.band;
			quietChromeRef.current.size = style.size;
			quietChromeRef.current.color = style.color;
			quietChromeRef.current.align = style.align;
			quietChromeRef.current.prefix = style.prefix;
			quietChromeRef.current.suffix = display.suffix;
			spinner.Value = mantissa;
			setDigitTracking(spinner, style.digitWidthScale, style.digitGap);
			lastMantissaRef.current = mantissa;
			if (pulse && prevMantissa !== undefined) {
				pulseAccent(spinner, style.color);
			}
		},
		[pulseAccent],
	);
	const ensureSpinner = React.useCallback((): Spinner | undefined => {
		if (reducedMotion) {
			return undefined;
		}
		const existing = spinnerRef.current;
		const existingFrame = existing !== undefined ? (existing.Frame as unknown) : undefined;
		if (typeIs(existingFrame, "Instance") && existingFrame.Parent !== undefined) {
			return existing;
		}
		destroySpinner();
		const host = hostRef.current;
		const mod = loadModule();
		if (host === undefined || mod === undefined) {
			return undefined;
		}
		const fallback = fallbackRef.current;
		if (fallback !== undefined) {
			fallback.Visible = false;
			fallback.TextTransparency = 1;
		}
		for (const child of host.GetChildren()) {
			if (child.Name === "NumberSpinnerGuide" || string.sub(child.Name, 1, 8) === "Spinner_") {
				child.Destroy();
			}
		}
		const style = styleRef.current;
		// The spinner takes over a guide label of its own. It must not be the fallback label:
		// the fallback is hidden once the spinner runs, and anything inside it would vanish too.
		const guide = new Instance("TextLabel");
		guide.Name = "NumberSpinnerGuide";
		guide.BackgroundTransparency = 1;
		guide.BorderSizePixel = 0;
		guide.Size = autoWidthRef.current ? new UDim2(0, 0, 1, 0) : UDim2.fromScale(1, 1);
		guide.AutomaticSize = autoWidthRef.current ? Enum.AutomaticSize.X : Enum.AutomaticSize.None;
		guide.FontFace = SPINNER_FONT;
		guide.TextSize = style.size;
		guide.TextColor3 = style.color;
		guide.TextXAlignment = style.align;
		guide.TextYAlignment = Enum.TextYAlignment.Center;
		guide.TextScaled = false;
		guide.TextStrokeTransparency = 1;
		guide.TextStrokeColor3 = Color3.fromRGB(0, 0, 0);
		guide.Text = "";
		guide.Parent = host;
		guideRef.current = guide;
		let spinner = mod.fromGuiObject !== undefined ? mod.fromGuiObject(guide) : undefined;
		if (spinner === undefined) {
			spinner = mod.new();
			spinner.Parent = host;
			spinner.Size = autoWidthRef.current ? new UDim2(0, 0, 1, 0) : UDim2.fromScale(1, 1);
			spinner.Position = UDim2.fromScale(0, 0);
			spinner.BackgroundTransparency = 1;
			spinner.FontFace = guide.FontFace;
			guide.Visible = false;
		}
		if (autoWidthRef.current) {
			spinner.AutomaticSize = Enum.AutomaticSize.X;
			spinner.Size = new UDim2(0, 0, 1, 0);
			spinner.ClipsDescendants = true;
			hugSpinnerContent(host);
		}
		const initialRaw = targetRef.current;
		const display = spinDisplay(initialRaw, style.extraSuffix, style.spacedSuffix);
		applyChrome(spinner, {
			duration: 0.08,
			decimals: display.decimals,
			prefix: style.prefix,
			suffix: display.suffix,
			size: style.size,
			color: style.color,
			align: style.align,
		});
		const mantissa = sanitizeValue(display.value, display.decimals);
		spinner.Value = mantissa;
		setDigitTracking(spinner, style.digitWidthScale, style.digitGap);
		lastRawRef.current = initialRaw;
		lastBandRef.current = display.band;
		lastMantissaRef.current = mantissa;
		spinnerRef.current = spinner;
		setLive(true);
		return spinner;
	}, [destroySpinner, reducedMotion]);
	React.useEffect(() => {
		if (reducedMotion) {
			destroySpinner();
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
			if (ensureSpinner() === undefined && attempts < 100) {
				retryJob = task.delay(0.1, tryMount);
			}
			return undefined;
		};
		let mountJob: thread | undefined = task.defer(tryMount);
		return () => {
			cancelled = true;
			if (mountJob !== undefined) {
				pcall(task.cancel, mountJob);
			}
			if (retryJob !== undefined) {
				pcall(task.cancel, retryJob);
			}
			mountJob = undefined;
			retryJob = undefined;
			destroySpinner();
		};
	}, [destroySpinner, ensureSpinner, reducedMotion]);
	React.useEffect(() => {
		if (reducedMotion) {
			return undefined;
		}
		const spinner = ensureSpinner();
		if (spinner === undefined) {
			return undefined;
		}
		const style = styleRef.current;
		const previous = lastRawRef.current;
		const producing = velocityRef.current > 0;
		if (producing && previous !== undefined) {
			const jump = math.abs(value - previous);
			if (jump > 0 && jump < math.max(3, velocityRef.current * 0.35)) {
				return undefined;
			}
		}
		const fromBand = previous !== undefined ? spinDisplay(previous, style.extraSuffix, style.spacedSuffix).band : "";
		const toBand = spinDisplay(value, style.extraSuffix, style.spacedSuffix).band;
		const roll =
			previous !== undefined
				? rollDurationForJump(style.duration, previous, value, fromBand, toBand, motionScaleRef.current)
				: 0.08;
		velocitySnapRef.current = false;
		const jump = previous !== undefined ? math.abs(value - previous) : 0;
		const shouldPulse = previous !== undefined && jump >= math.max(18, math.abs(previous) * 0.03 + 1);
		pushDisplay(spinner, value, roll, shouldPulse);
	}, [align, color, duration, ensureSpinner, extraSuffix, prefix, pushDisplay, reducedMotion, size, value]);
	React.useEffect(() => {
		if (!live || reducedMotion || velocity <= 0) {
			return undefined;
		}
		let alive = true;
		let displayRaw = lastRawRef.current ?? targetRef.current;
		let previousAt = os.clock();
		const step = () => {
			if (!alive) {
				return;
			}
			const now = os.clock();
			const dt = math.min(1, now - previousAt);
			previousAt = now;
			const spinner = ensureSpinner();
			if (spinner === undefined) {
				return;
			}
			const server = targetRef.current;
			const rate = math.max(0, velocityRef.current);
			if (server > displayRaw) {
				displayRaw = server;
			}
			displayRaw += rate * dt;
			const ceiling = server + rate * 2;
			if (displayRaw > ceiling) {
				displayRaw = ceiling;
			}
			const style = styleRef.current;
			const compact = spinDisplay(displayRaw, style.extraSuffix, style.spacedSuffix);
			const mantissa = sanitizeValue(compact.value, compact.decimals);
			if (mantissa === lastMantissaRef.current && compact.band === lastBandRef.current) {
				lastRawRef.current = displayRaw;
				return;
			}
			const bandChanged = lastBandRef.current !== compact.band;
			const roll = bandChanged ? 0.03 : VELOCITY_ROLL;
			if (!velocitySnapRef.current || bandChanged) {
				velocitySnapRef.current = true;
			}
			applyChrome(spinner, {
				duration: roll,
				decimals: compact.decimals,
				prefix: style.prefix,
				suffix: compact.suffix,
				size: style.size,
				color: style.color,
				align: style.align,
			});
			spinner.Value = mantissa;
			lastRawRef.current = displayRaw;
			lastBandRef.current = compact.band;
			lastMantissaRef.current = mantissa;
		};
		const unregister = registerVelocityStep(step);
		return () => {
			alive = false;
			unregister();
		};
	}, [ensureSpinner, live, reducedMotion, velocity]);
	React.useEffect(() => {
		if (!autoWidth) {
			return undefined;
		}
		if (reducedMotion || !live) {
			const estimated = estimateLabelWidth(label, size);
			contentWidthRef.current = estimated;
			setContentWidth(estimated);
			return undefined;
		}
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const connections: RBXScriptConnection[] = [];
		let boundLayout: UIListLayout | undefined;
		let layoutConnection: RBXScriptConnection | undefined;
		let settleJob: thread | undefined;
		let cancelled = false;
		const sync = (): undefined => {
			if (cancelled) {
				return undefined;
			}
			const layout = hugSpinnerContent(host) ?? findSpinnerLayout(host);
			if (layout === undefined) {
				return undefined;
			}
			if (boundLayout !== layout) {
				layoutConnection?.Disconnect();
				boundLayout = layout;
				layoutConnection = layout.GetPropertyChangedSignal("AbsoluteContentSize").Connect(sync);
			}
			const measured = math.ceil(layout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD;
			if (measured > AUTO_WIDTH_PAD && measured > contentWidthRef.current) {
				contentWidthRef.current = measured;
				setContentWidth(measured);
			}
			if (settleJob !== undefined) {
				pcall(task.cancel, settleJob);
			}
			settleJob = task.delay(0.24, () => {
				settleJob = undefined;
				if (cancelled || boundLayout === undefined) {
					return undefined;
				}
				const settled = math.ceil(boundLayout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD;
				if (settled > AUTO_WIDTH_PAD && settled !== contentWidthRef.current) {
					contentWidthRef.current = settled;
					setContentWidth(settled);
				}
			});
			return undefined;
		};
		sync();
		connections.push(host.ChildAdded.Connect(sync));
		return () => {
			cancelled = true;
			if (settleJob !== undefined) {
				pcall(task.cancel, settleJob);
			}
			layoutConnection?.Disconnect();
			for (const connection of connections) {
				connection.Disconnect();
			}
		};
	}, [autoWidth, live, reducedMotion, size]);
	React.useEffect(() => {
		if (!autoWidth || (!reducedMotion && live)) {
			return undefined;
		}
		const estimated = estimateLabelWidth(label, size);
		contentWidthRef.current = estimated;
		setContentWidth(estimated);
	}, [autoWidth, label, live, reducedMotion, size]);
	const height = sizeConstraint.Y.Offset > 0 ? sizeConstraint.Y.Offset : size + 8;
	const frameSize = autoWidth ? UDim2.fromOffset(math.max(1, contentWidth), height) : sizeConstraint;
	const hostSize = autoWidth ? new UDim2(0, 0, 1, 0) : UDim2.fromScale(1, 1);
	let fallbackLabel: React.Element | false = false;
	if (reducedMotion || !live) {
		fallbackLabel = autoWidth ? (
			<textlabel
				ref={fallbackRef}
				Size={new UDim2(0, 0, 1, 0)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={label}
				TextColor3={color}
				TextSize={size}
				FontFace={SPINNER_FONT}
				TextXAlignment={align}
				TextYAlignment={Enum.TextYAlignment.Center}
				TextStrokeTransparency={1}
				ZIndex={zIndex}
			/>
		) : (
			<textlabel
				ref={fallbackRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={true}
				Text={label}
				TextColor3={color}
				TextSize={size}
				FontFace={SPINNER_FONT}
				TextXAlignment={align}
				TextYAlignment={Enum.TextYAlignment.Center}
				TextScaled={true}
				TextTruncate={Enum.TextTruncate.AtEnd}
				TextStrokeTransparency={1}
				ZIndex={zIndex}
			>
				<uitextsizeconstraint MinTextSize={math.min(10, math.max(1, size))} MaxTextSize={math.max(size, 1)} />
			</textlabel>
		);
	}
	return (
		<frame
			Size={frameSize}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
		>
			<frame
				ref={hostRef}
				Size={hostSize}
				AutomaticSize={autoWidth ? Enum.AutomaticSize.X : Enum.AutomaticSize.None}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ZIndex={zIndex + 1}
			/>
			{fallbackLabel}
		</frame>
	);
}

export { NumberSpinnerHost };
