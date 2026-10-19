// Tooltips. One bubble for the whole game, drawn on its own top layer so nothing covers it.
//
// Attach content to any GuiObject (Tooltip.attach, or the useTooltip hook; Button takes a
// `tooltip` prop and gives icon-only buttons their name). Content is a string, or
// { title = , body = , hint = , accent = }.
//
// What keeps it out of the way:
//   * it waits before showing (0.5 s), but once one has just been shown, the next comes quickly,
//     so sweeping along a row reads naturally;
//   * it never covers the thing it describes or the pointer: it tries above, below, right and
//     left, takes the first spot that fits the safe area, and slides along the edge if none does;
//   * it sizes to its text (wrapping at a comfortable width, narrower on phones);
//   * it follows its target if that moves or scrolls, and goes the moment the pointer leaves,
//     the target is pressed, the wheel scrolls or the target disappears;
//   * a target that has been explained a few times waits longer before explaining again;
//   * touch shows it on a long press, gamepads when a button stays selected.
import React from "@rbxts/react";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const TweenService = game.GetService("TweenService");

type Content = string | { title?: string; body?: string; hint?: string; accent?: Color3 };

const SHOW_DELAY = 0.5;
const WARM_DELAY = 0.08;
const WARM_WINDOW = 0.6;
const SEEN_SLOWDOWN = 3; // after this many showings a target waits longer
const SLOW_DELAY = 1.1;
const GAP = 8;
const EDGE = 10;
const LONG_PRESS = 0.45;

interface PaletteColors {
	ink?: Color3;
	cream?: Color3;
	creamSoft?: Color3;
	muted?: Color3;
	lineSoft?: Color3;
	[key: string]: Color3 | undefined;
}

let theme: PaletteColors | undefined = undefined;
function palette(): PaletteColors {
	if (theme === undefined) {
		const [ok, kit] = pcall(() => {
			return (require(script.Parent!.FindFirstChild("CoreKit")! as ModuleScript) as (name: string) => { Palette: PaletteColors })("theme");
		});
		theme = ok ? (kit as { Palette: PaletteColors }).Palette : ({} as PaletteColors);
	}
	return theme!;
}

let reducedMotion = false;
let enabled = true;

// names for icon-only buttons, by icon concept
const LABELS: { [key: string]: string } = {
	Close: "Close", Back: "Back", Settings: "Settings", Menu: "Menu", Search: "Search",
	Refresh: "Refresh", Send: "Send", Chat: "Chat", Mail: "Mail", Inventory: "Inventory",
	Shop: "Shop", Play: "Play", Pause: "Pause", Hide: "Hide", Lock: "Locked", Check: "Done",
	Chevron: "More", Visit: "Visit", Wave: "Wave", Gift: "Gift", Leaderboard: "Ranks",
	Guide: "Guide", Credits: "Credits", Crew: "Crew", Guild: "Guild", Admin: "Admin",
	Rewards: "Rewards", Calendar: "Calendar", Code: "Codes", Travel: "Travel", Loadout: "Loadout",
};

// the bubble ------------------------------------------------------------------------------------

let screen: ScreenGui | undefined = undefined;
let bubble: Frame | undefined = undefined;
let titleLabel: TextLabel | undefined = undefined;
let bodyLabel: TextLabel | undefined = undefined;
let hintLabel: TextLabel | undefined = undefined;
let strokeInst: UIStroke | undefined = undefined;
let scaleInst: UIScale | undefined = undefined;
let widthCap: UISizeConstraint | undefined = undefined;

function buildLabel(name: string, order: number, weight: Enum.FontWeight, size: number): TextLabel {
	const text = new Instance("TextLabel");
	text.Name = name;
	text.LayoutOrder = order;
	text.BackgroundTransparency = 1;
	text.AutomaticSize = Enum.AutomaticSize.XY;
	text.Size = UDim2.fromOffset(0, 0);
	text.TextWrapped = true;
	text.RichText = false;
	text.TextXAlignment = Enum.TextXAlignment.Left;
	text.TextYAlignment = Enum.TextYAlignment.Top;
	text.FontFace = new Font("rbxasset://fonts/families/BuilderSans.json", weight);
	text.TextSize = size;
	text.ZIndex = 3;
	const cap = new Instance("UISizeConstraint");
	cap.Name = "Cap";
	cap.MaxSize = new Vector2(280, math.huge);
	cap.Parent = text;
	return text;
}

function build() {
	if (bubble !== undefined && screen !== undefined && screen.Parent !== undefined) {
		return;
	}
	const P = palette();
	const gui = new Instance("ScreenGui");
	gui.Name = "AstralForgeTooltips";
	gui.DisplayOrder = 9000;
	gui.IgnoreGuiInset = true;
	gui.ResetOnSpawn = false;
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	const frame = new Instance("Frame");
	frame.Name = "Bubble";
	frame.AutomaticSize = Enum.AutomaticSize.XY;
	frame.Size = UDim2.fromOffset(0, 0);
	frame.BackgroundColor3 = P.ink ?? Color3.fromRGB(16, 14, 24);
	frame.BackgroundTransparency = 0.06;
	frame.BorderSizePixel = 0;
	frame.Active = false;
	frame.Selectable = false;
	frame.Visible = false;
	frame.Parent = gui;
	const corner = new Instance("UICorner");
	corner.CornerRadius = new UDim(0, 9);
	corner.Parent = frame;
	const line = new Instance("UIStroke");
	line.Thickness = 1;
	line.Transparency = 0.45;
	line.Color = P.lineSoft ?? Color3.fromRGB(90, 84, 120);
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
	line.Parent = frame;
	const pad = new Instance("UIPadding");
	pad.PaddingLeft = new UDim(0, 11);
	pad.PaddingRight = new UDim(0, 11);
	pad.PaddingTop = new UDim(0, 8);
	pad.PaddingBottom = new UDim(0, 9);
	pad.Parent = frame;
	const list = new Instance("UIListLayout");
	list.SortOrder = Enum.SortOrder.LayoutOrder;
	list.Padding = new UDim(0, 3);
	list.Parent = frame;
	const grow = new Instance("UIScale");
	grow.Parent = frame;
	const title = buildLabel("Title", 1, Enum.FontWeight.Bold, 14);
	title.TextColor3 = P.cream ?? Color3.fromRGB(245, 238, 225);
	title.Parent = frame;
	const body = buildLabel("Body", 2, Enum.FontWeight.Regular, 13);
	body.TextColor3 = P.creamSoft ?? Color3.fromRGB(205, 198, 190);
	body.Parent = frame;
	const hint = buildLabel("Hint", 3, Enum.FontWeight.SemiBold, 11);
	hint.TextColor3 = P.muted ?? Color3.fromRGB(150, 145, 160);
	hint.Parent = frame;
	gui.Parent = Players.LocalPlayer!.WaitForChild("PlayerGui");
	screen = gui;
	bubble = frame;
	titleLabel = title;
	bodyLabel = body;
	hintLabel = hint;
	strokeInst = line;
	scaleInst = grow;
	widthCap = title.FindFirstChild("Cap") as UISizeConstraint;
}

// where things are on the tooltip layer (which ignores the top-bar inset)
function screenRect(target: GuiObject): LuaTuple<[Vector2, Vector2]> {
	let position = target.AbsolutePosition;
	const holder = target.FindFirstAncestorWhichIsA("LayerCollector");
	if (holder && holder.IsA("ScreenGui") && !holder.IgnoreGuiInset) {
		position = position.add(GuiService.GetGuiInset()[0]);
	}
	return $tuple(position, target.AbsoluteSize);
}

function viewport(): Vector2 {
	const camera = game.GetService("Workspace").CurrentCamera;
	return camera ? camera.ViewportSize : new Vector2(1280, 720);
}

function overlaps(p: Vector2, s: Vector2, q: Vector2, t: Vector2): boolean {
	return p.X < q.X + t.X && q.X < p.X + s.X && p.Y < q.Y + t.Y && q.Y < p.Y + s.Y;
}

// the best spot for a bubble of `size` beside a target, kept clear of the pointer
function place(
	targetPos: Vector2,
	targetSize: Vector2,
	size: Vector2,
	pointer: Vector2 | undefined,
	prefer: string | undefined,
): LuaTuple<[Vector2, string]> {
	const view = viewport();
	const inset = GuiService.GetGuiInset()[0];
	const top = math.max(EDGE, inset.Y + 4);
	const cx = targetPos.X + targetSize.X / 2 - size.X / 2;
	const cy = targetPos.Y + targetSize.Y / 2 - size.Y / 2;
	const spots: { [side: string]: Vector2 } = {
		above: new Vector2(cx, targetPos.Y - GAP - size.Y),
		below: new Vector2(cx, targetPos.Y + targetSize.Y + GAP),
		right: new Vector2(targetPos.X + targetSize.X + GAP, cy),
		left: new Vector2(targetPos.X - GAP - size.X, cy),
	};
	const order = ["above", "below", "right", "left"];
	if (prefer && spots[prefer]) {
		order.unshift(prefer);
	}
	const fits = (p: Vector2): boolean => {
		return p.X >= EDGE && p.Y >= top && p.X + size.X <= view.X - EDGE && p.Y + size.Y <= view.Y - EDGE;
	};
	const clampPos = (p: Vector2): Vector2 => {
		return new Vector2(
			math.clamp(p.X, EDGE, math.max(EDGE, view.X - EDGE - size.X)),
			math.clamp(p.Y, top, math.max(top, view.Y - EDGE - size.Y)),
		);
	};
	const pointerBox = new Vector2(22, 26);
	for (const side of order) {
		// the centred spot, or one slid along the edge to stay on screen
		const p = spots[side];
		const slid = (side === "above" || side === "below")
			? new Vector2(clampPos(p).X, p.Y)
			: new Vector2(p.X, clampPos(p).Y);
		if (fits(slid) && !(pointer && overlaps(slid, size, pointer.sub(new Vector2(4, 4)), pointerBox))) {
			return $tuple(slid, side);
		}
	}
	return $tuple(clampPos(spots[order[0]]), order[0]);
}

// showing and hiding ----------------------------------------------------------------------------

interface Entry {
	target: GuiObject;
	content: Content;
	seen: number;
}

const entries = new Map<GuiObject, Entry>();
let current: Entry | undefined = undefined;
let side = "above";
let lastHiddenAt = -math.huge;
let pending: thread | undefined = undefined;
let follow: RBXScriptConnection | undefined = undefined;
let fade: Tween | undefined = undefined;

function normalize(content: Content): { title?: string; body?: string; hint?: string; accent?: Color3 } {
	if (typeIs(content, "string")) {
		return { title: content };
	}
	return content;
}

function stopFollow() {
	if (follow) {
		follow.Disconnect();
		follow = undefined;
	}
}

function pointerPosition(): Vector2 | undefined {
	if (UserInputService.MouseEnabled && !UserInputService.TouchEnabled) {
		return UserInputService.GetMouseLocation();
	}
	return undefined;
}

function reveal(entry: Entry) {
	if (!enabled || !entry.target.IsDescendantOf(game) || !entry.target.Visible) {
		return;
	}
	build();
	const frame = bubble as Frame;
	const title = titleLabel as TextLabel;
	const body = bodyLabel as TextLabel;
	const hint = hintLabel as TextLabel;
	const data = normalize(entry.content);
	const P = palette();
	const view = viewport();
	const width = math.clamp(math.floor(view.X * 0.7), 160, view.X < 700 ? 230 : 280);
	for (const text of [title, body, hint]) {
		const cap = text.FindFirstChild("Cap") as UISizeConstraint;
		cap.MaxSize = new Vector2(width, math.huge);
	}
	title.Text = data.title || "";
	title.Visible = data.title !== undefined && data.title !== "";
	body.Text = data.body || "";
	body.Visible = data.body !== undefined && data.body !== "";
	hint.Text = data.hint || "";
	hint.Visible = data.hint !== undefined && data.hint !== "";
	if (!title.Visible && !body.Visible) {
		return;
	}
	// a body without a title reads as the main line
	body.TextColor3 = title.Visible ? (P.creamSoft ?? body.TextColor3) : (P.cream ?? body.TextColor3);
	if (strokeInst) {
		strokeInst.Color = data.accent ?? P.lineSoft ?? strokeInst.Color;
	}
	current = entry;
	entry.seen += 1;
	if (fade) {
		fade.Cancel();
	}
	frame.BackgroundTransparency = 0.06;
	title.TextTransparency = 0;
	body.TextTransparency = 0;
	hint.TextTransparency = 0;
	if (strokeInst) {
		strokeInst.Transparency = data.accent ? 0.2 : 0.45;
	}
	frame.Visible = true;
	let first = true;
	let drift = 0;
	stopFollow();
	follow = RunService.RenderStepped.Connect((dt) => {
		const live = current;
		if (live !== entry || !entry.target.IsDescendantOf(game) || !entry.target.Visible) {
			Tooltip.hide();
			return;
		}
		const [targetPos, targetSize] = screenRect(entry.target);
		let spot: Vector2;
		[spot, side] = place(targetPos, targetSize, frame.AbsoluteSize, pointerPosition(), first ? undefined : side);
		// arrive with a short slide away from the target, then sit still
		if (first) {
			drift = reducedMotion ? 0 : 1;
			first = false;
		}
		drift = math.max(0, drift - dt * 9);
		const push = drift * drift * 6;
		const away = side === "above"
			? new Vector2(0, push)
			: side === "below"
				? new Vector2(0, -push)
				: side === "right"
					? new Vector2(-push, 0)
					: new Vector2(push, 0);
		frame.Position = UDim2.fromOffset(math.round(spot.X + away.X), math.round(spot.Y + away.Y));
		if (scaleInst) {
			scaleInst.Scale = 1 - drift * 0.04;
		}
	});
}

function schedule(entry: Entry, delayTime: number) {
	if (pending) {
		pcall(task.cancel, pending);
	}
	pending = task.delay(delayTime, () => {
		pending = undefined;
		if (entries.get(entry.target) === entry) {
			reveal(entry);
		}
	});
}

function delayFor(entry: Entry): number {
	if (os.clock() - lastHiddenAt < WARM_WINDOW) {
		return WARM_DELAY;
	}
	return entry.seen >= SEEN_SLOWDOWN ? SLOW_DELAY : SHOW_DELAY;
}

const Tooltip = {
	setReducedMotion(this: void, value: boolean) {
		reducedMotion = value === true;
	},

	setEnabled(this: void, value: boolean) {
		enabled = value !== false;
		if (!enabled) {
			Tooltip.hide();
		}
	},

	labelFor(this: void, icon: string | undefined): string | undefined {
		if (!typeIs(icon, "string")) {
			return undefined;
		}
		const [matched] = icon.match("^[^.]+");
		return LABELS[matched || icon];
	},

	hide(this: void) {
		if (pending) {
			pcall(task.cancel, pending);
			pending = undefined;
		}
		if (current === undefined) {
			return;
		}
		current = undefined;
		lastHiddenAt = os.clock();
		stopFollow();
		const frame = bubble;
		if (frame === undefined) {
			return;
		}
		if (fade) {
			fade.Cancel();
		}
		if (reducedMotion) {
			frame.Visible = false;
			return;
		}
		fade = TweenService.Create(
			frame,
			new TweenInfo(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency: 1 },
		);
		for (const child of frame.GetChildren()) {
			if (child.IsA("TextLabel")) {
				TweenService.Create(child, new TweenInfo(0.1), { TextTransparency: 1 }).Play();
			}
		}
		if (strokeInst) {
			TweenService.Create(strokeInst, new TweenInfo(0.1), { Transparency: 1 }).Play();
		}
		const thisFade = fade as Tween;
		thisFade.Completed.Once((state) => {
			if (state === Enum.PlaybackState.Completed && current === undefined && bubble) {
				bubble.Visible = false;
			}
		});
		thisFade.Play();
	},

	// give `target` a tooltip; returns a function that removes it
	attach(this: void, target: GuiObject, content: Content | undefined): () => void {
		if (content === undefined || content === "") {
			return () => {};
		}
		const entry: Entry = { target, content, seen: 0 };
		entries.set(target, entry);
		const connections: RBXScriptConnection[] = [];
		let pressAt = 0;
		const leave = () => {
			if (pending && entries.get(target) === entry) {
				pcall(task.cancel, pending);
				pending = undefined;
			}
			if (current === entry) {
				Tooltip.hide();
			}
		};
		connections.push(target.MouseEnter.Connect(() => {
			if (UserInputService.TouchEnabled && !UserInputService.MouseEnabled) {
				return;
			}
			schedule(entry, delayFor(entry));
		}));
		connections.push(target.MouseLeave.Connect(leave));
		connections.push(target.SelectionGained.Connect(() => {
			if (GuiService.SelectedObject === target) {
				schedule(entry, os.clock() - lastHiddenAt < WARM_WINDOW ? 0.25 : 0.7);
			}
		}));
		connections.push(target.SelectionLost.Connect(leave));
		connections.push(target.InputBegan.Connect((input) => {
			const kind = input.UserInputType;
			if (kind === Enum.UserInputType.Touch) {
				pressAt = os.clock();
				schedule(entry, LONG_PRESS);
			} else if (kind === Enum.UserInputType.MouseButton1 || kind === Enum.UserInputType.MouseButton2) {
				// pressing means they know what it is; don't pop up over the click
				leave();
			} else if (kind === Enum.UserInputType.MouseWheel) {
				leave();
			}
		}));
		connections.push(target.InputEnded.Connect((input) => {
			if (input.UserInputType === Enum.UserInputType.Touch) {
				if (current === entry && os.clock() - pressAt >= LONG_PRESS) {
					// leave a long-press tip up long enough to read
					task.delay(1.6, () => {
						if (current === entry) {
							Tooltip.hide();
						}
					});
				} else {
					leave();
				}
			}
		}));
		connections.push(target.AncestryChanged.Connect(() => {
			if (!target.IsDescendantOf(game)) {
				leave();
			}
		}));
		return () => {
			for (const connection of connections) {
				connection.Disconnect();
			}
			if (entries.get(target) === entry) {
				entries.delete(target);
			}
			leave();
		};
	},

	// show an attached target's tooltip now (tutorial pointers, gamepad hints); it hides as usual
	showFor(this: void, target: GuiObject) {
		const entry = entries.get(target);
		if (entry) {
			reveal(entry);
		}
	},

	// change what an attached target says (the bubble updates if it is showing)
	update(this: void, target: GuiObject, content: Content | undefined) {
		const entry = entries.get(target);
		if (entry && content !== undefined) {
			entry.content = content;
			if (current === entry) {
				reveal(entry);
			}
		}
	},

	// React: useTooltip(ref, content). Content can change every render; the attachment stays.
	useTooltip(this: void, ref: React.Ref<GuiObject>, content: Content | undefined) {
		const key = !typeIs(content, "string") && content !== undefined
			? `${content.title || ""}\0${content.body || ""}\0${content.hint || ""}`
			: content;
		const has = content !== undefined && content !== "";
		React.useEffect(() => {
			const target = (ref as { current?: GuiObject }).current;
			if (!has || target === undefined) {
				return undefined;
			}
			return Tooltip.attach(target, content!);
		}, [has]);
		React.useEffect(() => {
			const target = (ref as { current?: GuiObject }).current;
			if (has && target !== undefined) {
				Tooltip.update(target, content!);
			}
		}, [key]);
	},

	_place: place,
};

// the scroll wheel anywhere dismisses (the target may be scrolling away under the pointer)
UserInputService.InputChanged.Connect((input) => {
	if (input.UserInputType === Enum.UserInputType.MouseWheel && current !== undefined) {
		Tooltip.hide();
	}
});

export = Tooltip;
