// World interaction prompts (ProximityPrompt Style Custom): a 44px brass key cap with a small
// action / object panel beside it. Only prompts the game marks Custom are drawn here; anything
// left on Default keeps the Roblox look.
// Owner: presentation. Dependencies: Shared/ForgeTheme, MotionPreference.
import { isReducedMotion } from "./MotionPreference";

const Players = game.GetService("Players");
const ProximityPromptService = game.GetService("ProximityPromptService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const TweenService = game.GetService("TweenService");

interface ThemeApi {
	Palette: Record<string, Color3>;
}
const ForgeTheme = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("ForgeTheme") as ModuleScript,
) as { newPalette(this: void): ThemeApi["Palette"] };
const Palette = ForgeTheme.newPalette();

const CAP = 44;
const GAP = 8;
const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
const NUMBERS = Font.fromEnum(Enum.Font.GothamBold);
const BODY = Font.fromEnum(Enum.Font.BuilderSans);

function keyLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string {
	if (inputType === Enum.ProximityPromptInputType.Touch) {
		return "TAP";
	}
	if (inputType === Enum.ProximityPromptInputType.Gamepad) {
		const name = prompt.GamepadKeyCode.Name;
		return name.sub(1, 6) === "Button" ? name.sub(7) : name;
	}
	const name = prompt.KeyboardKeyCode.Name;
	return name.size() <= 3 ? name : name.sub(1, 3);
}

function corner(parent: Instance, radius: number) {
	const c = new Instance("UICorner");
	c.CornerRadius = new UDim(0, radius);
	c.Parent = parent;
}

function stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke {
	const s = new Instance("UIStroke");
	s.Color = color;
	s.Thickness = thickness;
	s.Transparency = transparency;
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
	s.Parent = parent;
	return s;
}

function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, host: Instance): () => void {
	const reduced = isReducedMotion();
	const conns: RBXScriptConnection[] = [];
	const gui = new Instance("BillboardGui");
	gui.Name = "AF_Prompt";
	gui.AlwaysOnTop = true;
	gui.LightInfluence = 0;
	gui.Active = true;
	gui.ResetOnSpawn = false;
	gui.Size = UDim2.fromOffset(300, CAP + 8);
	gui.SizeOffset = new Vector2(0, 0.6);
	gui.Adornee = prompt.Parent as PVInstance | Attachment;

	const row = new Instance("Frame");
	row.Name = "Row";
	row.BackgroundTransparency = 1;
	row.Size = UDim2.fromScale(1, 1);
	row.Parent = gui;
	const scale = new Instance("UIScale");
	scale.Scale = reduced ? 1 : 0.82;
	scale.Parent = row;
	const layout = new Instance("UIListLayout");
	layout.FillDirection = Enum.FillDirection.Horizontal;
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	layout.VerticalAlignment = Enum.VerticalAlignment.Center;
	layout.Padding = new UDim(0, GAP);
	layout.SortOrder = Enum.SortOrder.LayoutOrder;
	layout.Parent = row;

	// key cap: brass face over a deep-brass base, the key letter in ink
	const cap = new Instance("TextButton");
	cap.Name = "KeyCap";
	cap.LayoutOrder = 1;
	cap.Size = UDim2.fromOffset(CAP, CAP);
	cap.AutoButtonColor = false;
	cap.BackgroundColor3 = Palette.brass;
	cap.Text = keyLabel(prompt, inputType);
	cap.FontFace = NUMBERS;
	cap.TextColor3 = Palette.ink;
	cap.TextSize = cap.Text.size() > 1 ? 13 : 20;
	cap.Parent = row;
	corner(cap, 10);
	stroke(cap, Palette.brassDeep, 2, 0);
	const face = new Instance("UIGradient");
	face.Rotation = 90;
	face.Color = new ColorSequence(Palette.brass.Lerp(Palette.cream, 0.25), Palette.brass);
	face.Parent = cap;
	// hold progress fills up from the bottom of the cap
	const fill = new Instance("Frame");
	fill.Name = "Hold";
	fill.AnchorPoint = new Vector2(0, 1);
	fill.Position = UDim2.fromScale(0, 1);
	fill.Size = UDim2.fromScale(1, 0);
	fill.BackgroundColor3 = Palette.cream;
	fill.BackgroundTransparency = 0.55;
	fill.BorderSizePixel = 0;
	fill.ZIndex = 2;
	fill.Parent = cap;
	corner(fill, 10);

	// action / object panel
	const panel = new Instance("Frame");
	panel.Name = "Panel";
	panel.LayoutOrder = 2;
	panel.AutomaticSize = Enum.AutomaticSize.X;
	panel.Size = UDim2.fromOffset(0, CAP);
	panel.BackgroundColor3 = Palette.panel;
	panel.BackgroundTransparency = 0.08;
	panel.Parent = row;
	corner(panel, 12);
	stroke(panel, Palette.line, 1, 0);
	const pad = new Instance("UIPadding");
	pad.PaddingLeft = new UDim(0, 12);
	pad.PaddingRight = new UDim(0, 12);
	pad.Parent = panel;
	const stack = new Instance("UIListLayout");
	stack.FillDirection = Enum.FillDirection.Vertical;
	stack.VerticalAlignment = Enum.VerticalAlignment.Center;
	stack.SortOrder = Enum.SortOrder.LayoutOrder;
	stack.Parent = panel;
	const action = new Instance("TextLabel");
	action.Name = "Action";
	action.LayoutOrder = 1;
	action.BackgroundTransparency = 1;
	action.AutomaticSize = Enum.AutomaticSize.X;
	action.Size = UDim2.fromOffset(0, 20);
	action.FontFace = SERIF;
	action.TextSize = 15;
	action.TextColor3 = Palette.cream;
	action.TextXAlignment = Enum.TextXAlignment.Left;
	action.Parent = panel;
	const detail = new Instance("TextLabel");
	detail.Name = "Object";
	detail.LayoutOrder = 2;
	detail.BackgroundTransparency = 1;
	detail.AutomaticSize = Enum.AutomaticSize.X;
	detail.Size = UDim2.fromOffset(0, 15);
	detail.FontFace = BODY;
	detail.TextSize = 12;
	detail.TextColor3 = Palette.muted;
	detail.TextXAlignment = Enum.TextXAlignment.Left;
	detail.Parent = panel;
	const sync = () => {
		action.Text = prompt.ActionText;
		detail.Text = prompt.ObjectText;
		detail.Visible = prompt.ObjectText !== "";
	};
	sync();
	conns.push(prompt.GetPropertyChangedSignal("ActionText").Connect(sync));
	conns.push(prompt.GetPropertyChangedSignal("ObjectText").Connect(sync));

	const tween = (target: Instance, time: number, goal: Partial<ExtractMembers<Instance, unknown>>, style?: Enum.EasingStyle) => {
		if (reduced) {
			for (const [k, v] of pairs(goal as Record<string, unknown>)) {
				(target as unknown as Record<string, unknown>)[k] = v;
			}
			return;
		}
		TweenService.Create(target, new TweenInfo(time, style ?? Enum.EasingStyle.Back, Enum.EasingDirection.Out), goal as never).Play();
	};
	tween(scale, 0.22, { Scale: 1 } as never);

	// hold: fill rises over HoldDuration; release drains it
	conns.push(
		prompt.PromptButtonHoldBegan.Connect(() => {
			if (prompt.HoldDuration > 0) {
				TweenService.Create(fill, new TweenInfo(prompt.HoldDuration, Enum.EasingStyle.Linear), {
					Size: UDim2.fromScale(1, 1),
				}).Play();
			}
		}),
	);
	conns.push(
		prompt.PromptButtonHoldEnded.Connect(() => {
			TweenService.Create(fill, new TweenInfo(0.15), { Size: UDim2.fromScale(1, 0) }).Play();
		}),
	);
	// press: the cap dips and flashes cream, then springs back
	conns.push(
		prompt.Triggered.Connect(() => {
			cap.BackgroundColor3 = Palette.cream;
			scale.Scale = reduced ? 1 : 0.92;
			tween(scale, 0.25, { Scale: 1 } as never);
			tween(cap, 0.3, { BackgroundColor3: Palette.brass } as never, Enum.EasingStyle.Quad);
		}),
	);
	// touch and mouse: the cap itself is the button
	conns.push(
		cap.InputBegan.Connect((input) => {
			if (
				input.UserInputType === Enum.UserInputType.Touch ||
				input.UserInputType === Enum.UserInputType.MouseButton1
			) {
				prompt.InputHoldBegin();
			}
		}),
	);
	conns.push(
		cap.InputEnded.Connect((input) => {
			if (
				input.UserInputType === Enum.UserInputType.Touch ||
				input.UserInputType === Enum.UserInputType.MouseButton1
			) {
				prompt.InputHoldEnd();
			}
		}),
	);
	gui.Parent = host;
	return () => {
		for (const c of conns) {
			c.Disconnect();
		}
		gui.Destroy();
	};
}

const PromptStyle = {
	attach(this: void): () => void {
		const host = new Instance("Folder");
		host.Name = "AF_Prompts";
		host.Parent = Players.LocalPlayer.WaitForChild("PlayerGui");
		const live = new Map<ProximityPrompt, () => void>();
		const conns: RBXScriptConnection[] = [];
		conns.push(
			ProximityPromptService.PromptShown.Connect((prompt, inputType) => {
				if (prompt.Style !== Enum.ProximityPromptStyle.Custom) {
					return;
				}
				live.get(prompt)?.();
				live.set(prompt, build(prompt, inputType, host));
			}),
		);
		conns.push(
			ProximityPromptService.PromptHidden.Connect((prompt) => {
				const done = live.get(prompt);
				if (done !== undefined) {
					done();
					live.delete(prompt);
				}
			}),
		);
		return () => {
			for (const c of conns) {
				c.Disconnect();
			}
			for (const [, done] of live) {
				done();
			}
			live.clear();
			host.Destroy();
		};
	},
};

export = PromptStyle;
