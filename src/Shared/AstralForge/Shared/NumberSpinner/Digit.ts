const TweenService = game.GetService("TweenService");

type Dict = Record<string, unknown>;

interface SpinnerLike {
	Duration: number;
	TextSize: number;
	TextColor3: Color3;
	FontFace: Font;
	Frame: Instance;
}

interface DigitState {
	Duration: number;
	Value: number;
	Shown: number;
	_from?: number;
	Labels: Record<number, TextLabel>;
	Destroy(this: DigitState): void;
	Update(this: DigitState, kind: unknown, updateValue?: unknown): void;
}

function rollTweenInfo(duration: number): TweenInfo {
	return new TweenInfo(math.max(0.08, duration), Enum.EasingStyle.Quart, Enum.EasingDirection.Out);
}

function digitSize(textSize: number): LuaTuple<[number, number]> {
	const h = math.max(14, math.floor(textSize + 4));

	const w = math.max(5, math.ceil(textSize * 0.52)); // Builder Sans digits are ~0.51 em; a wider cell leaves gaps
	return $tuple(w, h);
}

function newDigit(Spinner: SpinnerLike, LayoutOrder: number, Value: number): Dict {
	let tweenInfo = rollTweenInfo(Spinner.Duration);
	let activeTween: Tween | undefined = undefined;
	let collapsing = false;

	const [w, h] = digitSize(Spinner.TextSize);
	const Frame = new Instance("Frame");
	Frame.Name = "digit";
	Frame.LayoutOrder = LayoutOrder;
	Frame.BackgroundTransparency = 1;
	Frame.Size = new UDim2(0, w, 0, h);
	Frame.ClipsDescendants = true;

	const Canvas = new Instance("Frame");
	Canvas.Name = "canvas";
	Canvas.Size = new UDim2(1, 0, 10, 0);
	Canvas.BackgroundTransparency = 1;
	Canvas.Parent = Frame;

	Canvas.Position = new UDim2(0, 0, -Value, 0);

	const applyChromeSize = () => {
		if (collapsing) {
			return;
		}
		const [dw, dh] = digitSize(Spinner.TextSize);
		Frame.Size = new UDim2(0, dw, 0, dh);
	};

	const digit: DigitState = {
		Duration: Spinner.Duration,
		Value: Value,
		Shown: Value,

		Labels: table.create(10) as unknown as Record<number, TextLabel>,

		Destroy() {
			if (collapsing) {
				return;
			}
			collapsing = true;
			if (activeTween) {
				const previous = activeTween;
				activeTween = undefined;
				previous.Cancel();
				previous.Destroy();
			}

			Frame.Destroy();
			table.clear(digit);
		},

		Update(kind, updateValue) {
			if (kind === "Duration") {
				tweenInfo = rollTweenInfo(updateValue as number);
			} else if (kind === "Value") {
				let target = updateValue;
				if (typeOf(target) !== "number") {
					return;
				}
				target = math.clamp(math.floor(target as number), 0, 9);
				let from: unknown = digit._from;
				if (typeOf(from) !== "number") {
					from = digit.Shown;
				}
				digit.Shown = target as number;
				digit._from = undefined;

				if (activeTween) {
					const previous = activeTween;
					activeTween = undefined;
					previous.Cancel();
					previous.Destroy();
				}

				if (digit.Duration <= 0.12) {
					Canvas.Position = new UDim2(0, 0, -(target as number), 0);
					return;
				}

				if (from === target) {
					Canvas.Position = new UDim2(0, 0, -(target as number), 0);
					return;
				}

				const tween = TweenService.Create(Canvas, tweenInfo, { Position: new UDim2(0, 0, -(target as number), 0) });
				activeTween = tween;
				tween.Completed.Connect(() => {
					if (activeTween !== tween) {
						return;
					}
					activeTween = undefined;
					tween.Destroy();
				});
				tween.Play();
			} else if (kind === "TextSize" || kind === "FontFace") {
				applyChromeSize();
			}
		},
	};

	for (let i = 0; i <= 9; i++) {
		const n = new Instance("TextLabel");
		n.Name = "n_" + i;
		n.BackgroundTransparency = 1;
		n.TextSize = Spinner.TextSize;
		n.TextColor3 = Spinner.TextColor3;
		n.FontFace = Spinner.FontFace;
		n.Text = tostring(i);
		n.TextYAlignment = Enum.TextYAlignment.Center;
		n.TextXAlignment = Enum.TextXAlignment.Center;
		n.TextScaled = false;

		n.TextStrokeTransparency = 1;
		n.TextStrokeColor3 = new Color3(0, 0, 0);
		n.Size = new UDim2(1, 0, 0.1, 0);
		n.Position = new UDim2(0, 0, i * 0.1, 0);
		n.Parent = Canvas;
		digit.Labels[i] = n;
	}

	Frame.Parent = Spinner.Frame;

	const raw = digit as unknown as Dict;
	const label = (index: number) => digit.Labels[index] as unknown as Dict;

	const digitProxy = setmetatable({}, {
		__index: (_: unknown, key: string) => {
			const Direct = raw[key];
			if (Direct !== undefined && Direct !== false) {
				return Direct;
			}

			const [propExistsForLabel] = pcall(() => {
				const _ = label(1)[key];
			});
			if (propExistsForLabel) {
				return label(1)[key];
			}

			return undefined;
		},
		__newindex: (_: unknown, key: string, value: unknown) => {
			const Direct = raw[key];
			if (Direct !== undefined || key === "Duration" || key === "Value" || key === "Shown") {
				if (key === "Value") {
					digit._from = digit.Shown;
				}
				raw[key] = value;
				digit.Update(key, value);
				return;
			}

			const [propExistsForLabel] = pcall(() => {
				const _ = label(1)[key];
			});
			if (propExistsForLabel) {
				for (let i = 0; i <= 9; i++) {
					label(i)[key] = value;
				}
				digit.Update(key, value);
			}
		},
	} as LuaMetatable<object>) as Dict;

	return digitProxy;
}

export = { new: newDigit };
