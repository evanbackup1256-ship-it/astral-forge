// Debug overlay, shown only while Workspace.LayoutDebug is true. It draws into its own
// ScreenGui (IgnoreGuiInset, top DisplayOrder) and never parents anything into game UI, so pages
// keep their look. Frames are pooled; a redraw reuses them.
//
//   - boxes: one outlined rect per active finding, coloured by level;
//   - labels: rule + short message at the box corner (de-overlapped greedily);
//   - heatmap: severity density over the screen (heat.ts), toggled by LayoutDebug = "heat"
//     as well as true.
// The existing per-container whitespace overlay in UiCore/layoutEngine keeps drawing its bands;
// the containers it registers are fed to the guard so their EmptyBand/LowFill findings show here.
import * as G from "./geom";
import { heatmap, intensity, ramp } from "./heat";
import { OVERLAY_NAME } from "./capture";
import { Finding, Level } from "./types";

const COLORS: Record<Level, Color3> = {
	info: Color3.fromRGB(80, 170, 255),
	warn: Color3.fromRGB(255, 190, 40),
	error: Color3.fromRGB(255, 60, 70),
};

const MAX_BOXES = 160;
const LABEL_H = 14;

export class Overlay {
	private gui: ScreenGui | undefined;
	private boxes: Frame[] = [];
	private labels: TextLabel[] = [];
	private heat: Frame[] = [];

	constructor(private readonly playerGui: Instance) {}

	private ensure(): ScreenGui {
		if (this.gui !== undefined && this.gui.Parent !== undefined) return this.gui;
		const gui = new Instance("ScreenGui");
		gui.Name = OVERLAY_NAME;
		gui.IgnoreGuiInset = true;
		gui.ScreenInsets = Enum.ScreenInsets.None;
		gui.DisplayOrder = 2147483000;
		gui.ResetOnSpawn = false;
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		gui.SetAttribute("LayoutGuardIgnore", true);
		gui.Parent = this.playerGui;
		this.gui = gui;
		this.boxes = [];
		this.labels = [];
		this.heat = [];
		return gui;
	}

	private box(i: number): Frame {
		let f = this.boxes[i];
		if (f === undefined) {
			f = new Instance("Frame");
			f.Name = "Box";
			f.BackgroundTransparency = 0.88;
			f.BorderSizePixel = 0;
			f.Active = false;
			f.ZIndex = 2;
			const stroke = new Instance("UIStroke");
			stroke.Thickness = 1;
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
			stroke.Parent = f;
			f.Parent = this.ensure();
			this.boxes[i] = f;
		}
		return f;
	}

	private label(i: number): TextLabel {
		let t = this.labels[i];
		if (t === undefined) {
			t = new Instance("TextLabel");
			t.Name = "Label";
			t.BackgroundColor3 = new Color3(0, 0, 0);
			t.BackgroundTransparency = 0.25;
			t.BorderSizePixel = 0;
			t.TextColor3 = new Color3(1, 1, 1);
			t.TextSize = 11;
			t.Font = Enum.Font.Code;
			t.TextXAlignment = Enum.TextXAlignment.Left;
			t.AutomaticSize = Enum.AutomaticSize.X;
			t.Size = UDim2.fromOffset(0, LABEL_H);
			t.ZIndex = 3;
			t.Parent = this.ensure();
			this.labels[i] = t;
		}
		return t;
	}

	private heatCell(i: number): Frame {
		let f = this.heat[i];
		if (f === undefined) {
			f = new Instance("Frame");
			f.Name = "Heat";
			f.BorderSizePixel = 0;
			f.Active = false;
			f.ZIndex = 1;
			f.Parent = this.ensure();
			this.heat[i] = f;
		}
		return f;
	}

	/** Redraws for the given findings. `labelOf` gives the short text per finding. */
	draw(findings: ReadonlyArray<Finding>, width: number, height: number, showHeat: boolean, labelOf: (f: Finding) => string) {
		this.ensure();
		const shown = findings.filter((f) => f.rect !== undefined && G.area(f.rect) > 0);
		shown.sort((a, b) => a.severity > b.severity);
		const count = math.min(shown.size(), MAX_BOXES);
		const placed: G.Rect[] = [];
		let labelCount = 0;
		for (let i = 0; i < count; i++) {
			const f = shown[i];
			const r = f.rect!;
			const box = this.box(i);
			box.Visible = true;
			box.Position = UDim2.fromOffset(r.x0, r.y0);
			box.Size = UDim2.fromOffset(G.width(r), G.height(r));
			box.BackgroundColor3 = COLORS[f.level];
			(box.FindFirstChildOfClass("UIStroke") as UIStroke).Color = COLORS[f.level];
			// label goes above the box, or inside its top edge, wherever it does not collide
			const text = labelOf(f);
			const w = math.min(360, 7 * text.size() + 6);
			const candidates = [G.fromPosSize(r.x0, r.y0 - LABEL_H, w, LABEL_H), G.fromPosSize(r.x0, r.y0, w, LABEL_H), G.fromPosSize(r.x0, r.y1, w, LABEL_H)];
			for (const c of candidates) {
				if (placed.some((p) => G.intersects(p, c))) continue;
				placed.push(c);
				const t = this.label(labelCount);
				labelCount += 1;
				t.Visible = true;
				t.Position = UDim2.fromOffset(c.x0, c.y0);
				t.Text = " " + text + " ";
				t.TextColor3 = COLORS[f.level];
				break;
			}
		}
		for (let i = count; i < this.boxes.size(); i++) this.boxes[i].Visible = false;
		for (let i = labelCount; i < this.labels.size(); i++) this.labels[i].Visible = false;
		let heatCount = 0;
		if (showHeat) {
			const h = heatmap(width, height, shown.map((f) => ({ rect: f.rect!, weight: f.severity })));
			for (let r = 0; r < h.rows; r++) {
				for (let c = 0; c < h.cols; c++) {
					const v = intensity(h, r * h.cols + c);
					if (v < 0.05) continue;
					const [cr, cg, cb] = ramp(v);
					const cell = this.heatCell(heatCount);
					heatCount += 1;
					cell.Visible = true;
					cell.Position = UDim2.fromOffset(c * h.cell, r * h.cell);
					cell.Size = UDim2.fromOffset(h.cell, h.cell);
					cell.BackgroundColor3 = new Color3(cr, cg, cb);
					cell.BackgroundTransparency = 1 - v * 0.45;
				}
			}
		}
		for (let i = heatCount; i < this.heat.size(); i++) this.heat[i].Visible = false;
	}

	destroy() {
		this.gui?.Destroy();
		this.gui = undefined;
		this.boxes = [];
		this.labels = [];
		this.heat = [];
	}
}
