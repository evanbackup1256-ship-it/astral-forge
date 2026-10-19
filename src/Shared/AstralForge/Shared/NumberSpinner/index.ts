import Digit = require("./Digit");

type Dict = Record<string, unknown>;
type DigitProxy = Dict & { Destroy(): void };
type Slots<T> = Record<number, T | undefined>;

const READ_ONLY: Record<string, boolean> = {
	Frame: true,
	Digits: true,
	CommaLabels: true,
	Text: true,
};
const CUSTOM_PROPS: Record<string, string> = {
	Value: "number",
	Duration: "number",
	Decimals: "number",
	Prefix: "string",
	Suffix: "string",
	Commas: "boolean",
};
const TEXT_TO_LAYOUT = new Map<Enum.TextXAlignment, Enum.HorizontalAlignment>([
	[Enum.TextXAlignment.Center, Enum.HorizontalAlignment.Center],
	[Enum.TextXAlignment.Left, Enum.HorizontalAlignment.Left],
	[Enum.TextXAlignment.Right, Enum.HorizontalAlignment.Right],
]);

const DUMMY_FRAME = new Instance("Frame");
const DUMMY_LABEL = new Instance("TextLabel");
DUMMY_LABEL.TextSize = 16;
DUMMY_LABEL.TextColor3 = Color3.fromRGB(255, 255, 255);

DUMMY_LABEL.FontFace = Font.fromEnum(Enum.Font.GothamBlack);

const MAX_ABS = 1e24;

const isSet = (value: unknown) => value !== undefined && value !== false;
const count = (t: object) => (t as defined[]).size();

function clampNumber(value: unknown): number {
	if (typeOf(value) !== "number" || value !== value) {
		return 0;
	}
	const n = value as number;
	if (n >= math.huge) {
		return MAX_ABS;
	}
	if (n <= -math.huge) {
		return -MAX_ABS;
	}
	return math.clamp(n, -MAX_ABS, MAX_ABS);
}

function wholeDigitString(absValue: number): string {
	let n = math.floor(absValue + 0.5);
	if (n < 0) {
		n = 0;
	}
	if (n < 1e15) {
		return "%.0f".format(n);
	}

	const parts: string[] = table.create(4);
	while (n >= 1) {
		const chunk = math.floor((n % 1e9) + 0.5);
		n = math.floor(n / 1e9);
		if (n >= 1) {
			parts.unshift("%09d".format(chunk));
		} else {
			parts.unshift("%d".format(chunk));
		}
	}
	if (parts.size() === 0) {
		return "0";
	}
	return parts.join("");
}

function fractionalString(absValue: number, decimals: number): string | undefined {
	if (decimals <= 0) {
		return undefined;
	}
	const factor = 10 ** decimals;
	const scaled = math.floor(absValue * factor + 0.5);
	const frac = scaled % factor;
	return ("%0" + decimals + ".0f").format(frac);
}

interface RawSpinner {
	Value: number;
	Duration: number;
	Decimals: number;
	Prefix: string;
	Suffix: string;
	Commas: boolean;
	Digits: { Whole: Slots<DigitProxy>; Decimal: Slots<DigitProxy> };
	CommaLabels: Slots<TextLabel>;
	Frame?: Frame;
	Layout?: UIListLayout;
	PrefixLabel?: TextLabel;
	SuffixLabel?: TextLabel;
	DecimalLabel?: TextLabel;
	NegativeLabel?: TextLabel;
	Destroy(this: Dict): void;
	Update(this: RawSpinner, kind?: unknown, value?: unknown): void;
}

function newSpinner(): LuaTuple<[Dict, RawSpinner]> {
	const Spinner: RawSpinner = {
		Value: 0,
		Duration: 0.78,
		Decimals: 2,
		Prefix: "$",
		Suffix: "",
		Commas: false,

		Digits: {
			Whole: table.create(3) as unknown as Slots<DigitProxy>,
			Decimal: table.create(2) as unknown as Slots<DigitProxy>,
		},
		CommaLabels: table.create(2) as unknown as Slots<TextLabel>,

		Frame: undefined,
		Layout: undefined,
		PrefixLabel: undefined,
		SuffixLabel: undefined,
		DecimalLabel: undefined,
		NegativeLabel: undefined,

		Destroy() {
			(this.Frame as Frame).Destroy();
			table.clear(this);
		},

		Update(kind) {
			if (kind === "Prefix") {
				Spinner.PrefixLabel!.Text = Spinner.Prefix;
				return;
			} else if (kind === "Suffix") {
				Spinner.SuffixLabel!.Text = Spinner.Suffix;
				return;
			}

			const AbsValue = math.abs(clampNumber(Spinner.Value));
			const isNegative = Spinner.Value < 0;

			if (Spinner.NegativeLabel) {
				Spinner.NegativeLabel.Visible = isNegative;
			}

			let whole = wholeDigitString(AbsValue);
			const decimal = fractionalString(AbsValue, Spinner.Decimals);
			let numWhole = whole.size();
			if (numWhole < 1) {
				whole = "0";
				numWhole = 1;
			}

			for (let i = 1; i <= numWhole; i++) {
				const digit = Spinner.Digits.Whole[i];
				const digitValue = tonumber(whole.sub(i, i)) ?? 0;

				if (digit) {
					digit.Duration = Spinner.Duration;
					digit.Value = digitValue;
				} else {
					Spinner.Digits.Whole[i] = Digit.new(SpinnerProxy as never, i * 2 - 900, digitValue) as DigitProxy;
				}
			}
			for (let i = numWhole + 1, last = count(Spinner.Digits.Whole); i <= last; i++) {
				const digit = Spinner.Digits.Whole[i];
				if (digit) {
					digit.Destroy();
					Spinner.Digits.Whole[i] = undefined;
				}
			}

			if (Spinner.Commas) {
				let commaIndex = 0;
				for (let fromRight = 3; fromRight <= numWhole - 1; fromRight += 3) {
					const afterDigit = numWhole - fromRight;
					if (afterDigit <= 0) {
						break;
					}
					commaIndex += 1;
					let CommaLabel = Spinner.CommaLabels[commaIndex];
					if (!CommaLabel) {
						CommaLabel = new Instance("TextLabel");
						CommaLabel.Name = "Comma";
						CommaLabel.BackgroundTransparency = 1;
						CommaLabel.Size = new UDim2(0, 0, 1, 0);
						CommaLabel.FontFace = SpinnerProxy.FontFace as Font;
						CommaLabel.TextSize = SpinnerProxy.TextSize as number;
						CommaLabel.TextColor3 = SpinnerProxy.TextColor3 as Color3;
						CommaLabel.Text = ",";
						CommaLabel.TextXAlignment = Enum.TextXAlignment.Center;
						CommaLabel.TextYAlignment = Enum.TextYAlignment.Center;
						CommaLabel.TextStrokeTransparency = 1;
						CommaLabel.TextStrokeColor3 = new Color3(0, 0, 0);
						CommaLabel.AutomaticSize = Enum.AutomaticSize.X;
						CommaLabel.Parent = Spinner.Frame;

						Spinner.CommaLabels[commaIndex] = CommaLabel;
					}

					CommaLabel.LayoutOrder = afterDigit * 2 - 899;
					CommaLabel.Visible = true;
				}

				for (let i = commaIndex + 1, last = count(Spinner.CommaLabels); i <= last; i++) {
					const leftover = Spinner.CommaLabels[i];
					if (leftover) {
						leftover.Destroy();
						Spinner.CommaLabels[i] = undefined;
					}
				}
			} else {
				for (const [i, leftover] of pairs(Spinner.CommaLabels)) {
					leftover.Destroy();
					Spinner.CommaLabels[i] = undefined;
				}
			}

			if (decimal === undefined) {
				if (Spinner.DecimalLabel) {
					Spinner.DecimalLabel.Visible = false;
				}
				for (const [, digit] of ipairs(Spinner.Digits.Decimal as unknown as DigitProxy[])) {
					digit.Destroy();
				}
				table.clear(Spinner.Digits.Decimal);
				return;
			}

			if (Spinner.DecimalLabel) {
				Spinner.DecimalLabel.Visible = true;
			}
			for (let i = 1; i <= decimal.size(); i++) {
				const digit = Spinner.Digits.Decimal[i];
				const digitValue = tonumber(decimal.sub(i, i)) ?? 0;

				if (digit) {
					digit.Duration = Spinner.Duration;
					digit.Value = digitValue;
				} else {
					Spinner.Digits.Decimal[i] = Digit.new(SpinnerProxy as never, i, digitValue) as DigitProxy;
				}
			}
			for (let i = decimal.size() + 1, last = count(Spinner.Digits.Decimal); i <= last; i++) {
				const digit = Spinner.Digits.Decimal[i];
				if (digit) {
					digit.Destroy();
					Spinner.Digits.Decimal[i] = undefined;
				}
			}
		},
	};
	const raw = Spinner as unknown as Dict;

	const SpinnerProxy = setmetatable({}, {
		__index: (_: unknown, key: string) => {
			const Direct = raw[key];
			if (isSet(Direct)) {
				return Direct;
			}

			const [propExistsForFrame] = pcall(() => {
				const _ = (DUMMY_FRAME as unknown as Dict)[key];
			});
			if (propExistsForFrame) {
				return (Spinner.Frame as unknown as Dict)[key];
			}

			const [propExistsForLabel, labelProp] = pcall(() => (DUMMY_LABEL as unknown as Dict)[key]);
			if (propExistsForLabel) {
				const digit = Spinner.Digits.Whole[1];
				if (digit) {
					return digit[key];
				} else {
					return labelProp;
				}
			}

			return undefined;
		},
		__newindex: (_: unknown, key: string, value: unknown) => {
			if (READ_ONLY[key]) {
				warn("Attempted to set read-only value Spinner." + key);
				return;
			}

			const [propExistsForFrame] = pcall(() => {
				const _ = (DUMMY_FRAME as unknown as Dict)[key];
			});
			if (propExistsForFrame) {
				const t = typeOf((DUMMY_FRAME as unknown as Dict)[key]);
				if (t !== "nil" && t !== typeOf(value)) {
					warn("Attempted to set Spinner." + key + " to invalid value (" + tostring(value) + ")");
					return;
				}
				(Spinner.Frame as unknown as Dict)[key] = value;
				return;
			}

			if (key === "TextXAlignment") {
				Spinner.Layout!.HorizontalAlignment = TEXT_TO_LAYOUT.get(value as Enum.TextXAlignment)!;
				return;
			}

			const [propExistsForLabel] = pcall(() => {
				const _ = (DUMMY_LABEL as unknown as Dict)[key];
			});
			if (propExistsForLabel) {
				const propType = typeOf((DUMMY_LABEL as unknown as Dict)[key]);
				if (propType !== "nil" && propType !== typeOf(value)) {
					warn("Attempted to set Spinner." + key + " to invalid value (" + tostring(value) + ")");
					return;
				}
				for (const [, digit] of pairs(Spinner.Digits.Whole)) {
					digit[key] = value;
				}
				for (const [, digit] of pairs(Spinner.Digits.Decimal)) {
					digit[key] = value;
				}
				for (const [, comma] of pairs(Spinner.CommaLabels)) {
					(comma as unknown as Dict)[key] = value;
				}
				(Spinner.PrefixLabel as unknown as Dict)[key] = value;
				(Spinner.SuffixLabel as unknown as Dict)[key] = value;
				(Spinner.DecimalLabel as unknown as Dict)[key] = value;
				(Spinner.NegativeLabel as unknown as Dict)[key] = value;
				return;
			}

			if (isSet(CUSTOM_PROPS[key])) {
				if (typeOf(value) !== CUSTOM_PROPS[key]) {
					warn("Attempted to set Spinner." + key + " to invalid value (" + tostring(value) + ")");
					return;
				}
				if (key === "Value") {
					raw[key] = clampNumber(value);
				} else {
					raw[key] = value;
				}
				Spinner.Update(key, raw[key]);
				return;
			}
		},
	} as LuaMetatable<object>) as Dict;

	return $tuple(SpinnerProxy, Spinner);
}

function newNumberSpinner(): Dict {
	const [Spinner, RawSpinner] = newSpinner();

	const Frame = new Instance("Frame");
	Frame.BackgroundTransparency = 1;

	Frame.ClipsDescendants = true;
	Frame.Size = new UDim2(0, 200, 0, 50);
	Frame.Position = new UDim2(0, 0, 0, 0);

	const Layout = new Instance("UIListLayout");
	Layout.SortOrder = Enum.SortOrder.LayoutOrder;
	Layout.FillDirection = Enum.FillDirection.Horizontal;
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center;
	Layout.Padding = new UDim(0, 0);
	Layout.Parent = Frame;

	const styleChromeLabel = (label: TextLabel, text: string, layoutOrder: number) => {
		label.LayoutOrder = layoutOrder;
		label.BackgroundTransparency = 1;
		label.Size = new UDim2(0, 0, 1, 0);
		label.FontFace = Spinner.FontFace as Font;
		label.TextSize = Spinner.TextSize as number;
		label.TextColor3 = Spinner.TextColor3 as Color3;
		label.Text = text;
		label.TextYAlignment = Enum.TextYAlignment.Center;
		label.TextXAlignment = Enum.TextXAlignment.Center;
		label.TextScaled = false;
		label.TextStrokeTransparency = 1;
		label.TextStrokeColor3 = new Color3(0, 0, 0);
		label.AutomaticSize = Enum.AutomaticSize.X;
		label.Parent = Frame;
	};

	const Prefix = new Instance("TextLabel");
	Prefix.Name = "Prefix";
	styleChromeLabel(Prefix, Spinner.Prefix as string, -1000);

	const Suffix = new Instance("TextLabel");
	Suffix.Name = "Suffix";
	styleChromeLabel(Suffix, Spinner.Suffix as string, 1000);

	const Decimal = new Instance("TextLabel");
	Decimal.Name = "Decimal";
	styleChromeLabel(Decimal, ".", 0);

	const Negative = new Instance("TextLabel");
	Negative.Name = "Negative";
	styleChromeLabel(Negative, "-", -999);

	RawSpinner.Frame = Frame;
	RawSpinner.Layout = Layout;
	RawSpinner.PrefixLabel = Prefix;
	RawSpinner.SuffixLabel = Suffix;
	RawSpinner.DecimalLabel = Decimal;
	RawSpinner.NegativeLabel = Negative;

	(Spinner as unknown as { Update(): void }).Update();

	return Spinner;
}

function fromGuiObject(GuiObject: unknown): Dict | undefined {
	if (typeOf(GuiObject) !== "Instance") {
		return undefined;
	}
	const gui = GuiObject as Instance;
	if (!gui.IsA("GuiObject")) {
		return undefined;
	}

	const Spinner = newNumberSpinner();

	Spinner.Name = "Spinner_" + gui.Name;
	Spinner.SizeConstraint = gui.SizeConstraint;
	Spinner.Size = gui.Size;
	Spinner.Position = gui.Position;
	Spinner.AnchorPoint = gui.AnchorPoint;
	Spinner.Rotation = gui.Rotation;
	Spinner.LayoutOrder = gui.LayoutOrder;
	Spinner.ZIndex = gui.ZIndex;
	Spinner.Visible = gui.Visible;
	Spinner.BackgroundColor3 = gui.BackgroundColor3;
	Spinner.BorderColor3 = gui.BorderColor3;
	Spinner.BorderSizePixel = gui.BorderSizePixel;
	Spinner.BackgroundTransparency = gui.BackgroundTransparency;

	if (gui.IsA("TextLabel") || gui.IsA("TextButton") || gui.IsA("TextBox")) {
		Spinner.FontFace = gui.FontFace;
		Spinner.TextSize = gui.TextSize;
		Spinner.TextColor3 = gui.TextColor3;
		Spinner.TextTransparency = gui.TextTransparency;

		Spinner.TextStrokeColor3 = new Color3(0, 0, 0);
		Spinner.TextStrokeTransparency = 1;

		(Spinner.Layout as UIListLayout).HorizontalAlignment = TEXT_TO_LAYOUT.get(gui.TextXAlignment)!;
	}

	Spinner.Parent = gui.Parent;

	gui.Visible = false;

	return Spinner;
}

export = { new: newNumberSpinner, fromGuiObject };
