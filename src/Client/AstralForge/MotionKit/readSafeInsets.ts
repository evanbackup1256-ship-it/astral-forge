interface SafeInsets {
	top: number;
	bottom: number;
	left: number;
	right: number;
}

function readSafeInsets(): SafeInsets {
	let top = 0;
	let bottom = 0;
	let left = 0;
	let right = 0;
	let vpX = 1920;
	let vpY = 1080;
	pcall(() => {
		const cam = game.GetService("Workspace").CurrentCamera;
		if (cam) {
			vpX = cam.ViewportSize.X;
			vpY = cam.ViewportSize.Y;
		}
	});

	const GuiService = game.GetService("GuiService");
	// 1. DeviceSafeInsets: hardware notches, cutouts, dynamic island, home bars
	pcall(() => {
		const safeArea = GuiService.GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets);
		if (safeArea && typeIs(safeArea, "Rect")) {
			left = math.max(0, safeArea.Min.X);
			top = math.max(0, safeArea.Min.Y);
			right = math.max(0, vpX - safeArea.Max.X);
			bottom = math.max(0, vpY - safeArea.Max.Y);
		}
	});

	// 2. GetGuiInset: the CoreGui topbar
	pcall(() => {
		const [topLeft, bottomRight] = GuiService.GetGuiInset();
		if (typeIs(topLeft, "Vector2") && typeIs(bottomRight, "Vector2")) {
			top = math.max(top, topLeft.Y);
			left = math.max(left, topLeft.X);
			bottom = math.max(bottom, bottomRight.Y);
			right = math.max(right, bottomRight.X);
		}
	});

	return {
		top: math.round(top),
		bottom: math.round(bottom),
		left: math.round(left),
		right: math.round(right),
	};
}

export = readSafeInsets;
