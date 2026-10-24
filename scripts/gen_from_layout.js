#!/usr/bin/env node
// Mockup geometry -> TS layout constants.
//
//   node scripts/gen_from_layout.js --spec scripts/layout/shop.spec.json [--html design/05-shop/desktop.html | --json shop.layout.json]
//
// --html renders the mockup in headless Chrome at the spec's viewport (default 1920x1080) with
// scripts/layout/extract_layout.browser.js and keeps the JSON next to the spec (<name>.layout.json);
// --json reuses an earlier extraction. The spec names the boxes a screen needs:
//   { "name": "ShopLayout", "out": "src/.../ShopLayout.ts", "origin": ".main .flexr",
//     "nodes": { "Featured": ".flexr .pn:0", "BuyBtn": ".flexr .pn:0 .btn", ... } }
// A selector is a chain of steps, each matched anywhere below the previous one:
//   .a.b  (all classes)   tag   "text" (own text contains)   step:N (Nth match, 0-based)   .. (parent)
// Every box is emitted relative to `origin` in mockup px (1px == 1 offset at the 1920x1080 reference;
// the game's UIScale does the rest), with the paint the kit can draw:
//   fill / gradient (UIGradient Rotation + Color/Transparency sequences), stroke (1px ring shadows and
//   borders -> UIStroke), glow (largest outer blur shadow), radius (UICorner), pad / gap (list layouts),
//   text (size, face: title|body|num, weight, tracking in em, color).
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function arg(name) {
	const i = process.argv.indexOf("--" + name);
	return i > 0 ? process.argv[i + 1] : undefined;
}

const specPath = arg("spec");
if (!specPath) {
	console.error("usage: gen_from_layout.js --spec <spec.json> [--html <mockup.html> | --json <layout.json>]");
	process.exit(2);
}
const spec = JSON.parse(fs.readFileSync(specPath, "utf8"));
const repo = path.resolve(__dirname, "..");
const jsonPath = arg("json") || spec.json || specPath.replace(/\.spec\.json$/, ".layout.json");

function extract(htmlPath) {
	const chrome = process.env.CHROME || "google-chrome";
	const [w, h] = spec.viewport || [1920, 1080];
	const src = fs.readFileSync(path.join(__dirname, "layout", "extract_layout.browser.js"), "utf8");
	const html = fs.readFileSync(htmlPath, "utf8");
	const tmp = path.join(path.dirname(htmlPath), "_layout_extract.html");
	const inject = `<script>window.__LAYOUT_ROOT=${JSON.stringify(spec.root || ".screen")};window.addEventListener("load",()=>document.fonts.ready.then(()=>{try{${src}}catch(e){document.title="ERR "+e}}))</script>`;
	fs.writeFileSync(tmp, html.replace("</body>", inject + "</body>"));
	try {
		const dom = execFileSync(chrome, ["--headless=new", "--no-sandbox", "--disable-gpu", "--allow-file-access-from-files", `--window-size=${w},${h}`, "--hide-scrollbars", "--virtual-time-budget=4000", "--dump-dom", "file://" + path.resolve(tmp)], { maxBuffer: 1 << 28, stdio: ["ignore", "pipe", "ignore"] }).toString();
		const at = dom.lastIndexOf('<textarea id="__layout">');
		if (at < 0) throw new Error("extraction failed: " + (dom.match(/<title>([^<]*)/) || [])[1]);
		const body = dom.slice(at + 24, dom.indexOf("</textarea>", at));
		return JSON.parse(body.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&"));
	} finally {
		fs.unlinkSync(tmp);
	}
}

let layout;
if (arg("html")) {
	layout = extract(arg("html"));
	fs.writeFileSync(jsonPath, JSON.stringify(layout));
} else {
	layout = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
}

const parentOf = new Map();
(function index(node) {
	for (const c of node.children) {
		parentOf.set(c, node);
		index(c);
	}
})(layout.root);
function* descendants(node) {
	for (const c of node.children) {
		yield c;
		yield* descendants(c);
	}
}
function matches(node, step) {
	if (step.startsWith('"')) return node.text.some((t) => t.value.toLowerCase().includes(step.slice(1, -1).toLowerCase()));
	const [tag, ...cls] = step.split(".");
	const own = node.cls.split(/\s+/);
	return (tag === "" || node.tag === tag) && cls.every((c) => own.includes(c));
}
function select(root, selector) {
	let cur = root;
	for (const raw of selector.match(/"[^"]*"(:\d+)?|[^\s]+/g)) {
		if (raw === "..") {
			cur = parentOf.get(cur);
			continue;
		}
		const m = raw.match(/^(.*?)(?::(\d+))?$/);
		const hits = [...descendants(cur)].filter((n) => matches(n, m[1]));
		const pick = hits[m[2] === undefined ? 0 : +m[2]];
		if (!pick) throw new Error(`selector "${selector}": no match for step "${raw}"`);
		cur = pick;
	}
	return cur;
}

const r2 = (v) => Math.round(v * 100) / 100;
const c3 = (c) => `Color3.fromRGB(${c[0]}, ${c[1]}, ${c[2]})`;
const tr = (a) => r2(1 - a);
function face(family) {
	const f = family.toLowerCase();
	if (f.startsWith("cinzel")) return "title";
	if (f.startsWith("rajdhani")) return "num";
	return "body";
}
// CSS linear-gradient angle (0 = to top, 180 = to bottom) -> UIGradient.Rotation (0 = left->right, 90 = top->bottom)
function gradient(g) {
	const n = g.stops.length;
	const pos = g.stops.map((s, i) => (s.at && s.at.endsWith("%") ? parseFloat(s.at) / 100 : i === 0 ? 0 : i === n - 1 ? 1 : null));
	for (let i = 1; i < n; i++) if (pos[i] === null) {
		let j = i;
		while (pos[j] === null) j++;
		for (let k = i; k < j; k++) pos[k] = pos[i - 1] + ((pos[j] - pos[i - 1]) * (k - i + 1)) / (j - i + 1);
	}
	const keys = g.stops.map((s, i) => ({ t: r2(pos[i]), c: s.color }));
	return {
		rotation: ((g.angle ?? 180) - 90 + 360) % 360,
		color: `new ColorSequence([${keys.map((k) => `new ColorSequenceKeypoint(${k.t}, ${c3(k.c)})`).join(", ")}])`,
		transparency: `new NumberSequence([${keys.map((k) => `new NumberSequenceKeypoint(${k.t}, ${tr(k.c[3])})`).join(", ")}])`,
		mid: keys[Math.floor(keys.length / 2)].c,
	};
}
function radialGlow(g, node) {
	// "400px 260px at 75% 30%": an ellipse of that size centred at that point, inner stop colour
	const m = (g.shape || "").match(/([\d.]+)px\s+([\d.]+)px\s+at\s+([\d.]+)%\s+([\d.]+)%/);
	if (!m) return undefined;
	const c = g.stops[0].color;
	return { w: +m[1] * 2, h: +m[2] * 2, cx: r2(+m[3] / 100), cy: r2(+m[4] / 100), color: c3(c), transparency: tr(c[3]) };
}

const origin = spec.origin ? select(layout.root, spec.origin) : layout.root;
const lines = [];
lines.push(`// GENERATED by scripts/gen_from_layout.js from ${spec.source || layout.source} (${layout.width}x${layout.height}).`);
lines.push(`// Spec: ${path.relative(repo, path.resolve(specPath)).split(path.sep).join("/")}. Do not edit by hand; edit the spec and regenerate.`);
lines.push(`// Units are mockup px at the 1920x1080 reference; boxes are relative to "${spec.origin || spec.root || ".screen"}".`);
lines.push("");
lines.push(`export const ${spec.name} = {`);
lines.push(`\torigin: { w: ${r2(origin.w)}, h: ${r2(origin.h)} },`);
for (const [key, selector] of Object.entries(spec.nodes)) {
	const n = select(layout.root, selector);
	const f = [];
	f.push(`x: ${r2(n.x - origin.x)}, y: ${r2(n.y - origin.y)}, w: ${r2(n.w)}, h: ${r2(n.h)}`);
	if (n.radius) f.push(`radius: ${r2(n.radius)}`);
	if (n.pad.some((v) => v)) f.push(`pad: { top: ${n.pad[0]}, right: ${n.pad[1]}, bottom: ${n.pad[2]}, left: ${n.pad[3]} }`);
	if (n.display === "flex" || n.display === "grid") f.push(`gap: ${n.gap}${n.colGap !== n.gap ? `, colGap: ${n.colGap}` : ""}`);
	if (n.bg && n.bg[3] > 0) f.push(`fill: { color: ${c3(n.bg)}, transparency: ${tr(n.bg[3])} }`);
	const lin = n.layers.find((l) => l.kind === "linear");
	if (lin) {
		const g = gradient(lin);
		f.push(`gradient: { rotation: ${g.rotation}, color: ${g.color}, transparency: ${g.transparency} }`);
		f.push(`accent: ${c3(g.mid)}`);
	}
	const rad = n.layers.find((l) => l.kind === "radial");
	const rg = rad && radialGlow(rad, n);
	if (rg) f.push(`radialGlow: { w: ${rg.w}, h: ${rg.h}, cx: ${rg.cx}, cy: ${rg.cy}, color: ${rg.color}, transparency: ${rg.transparency} }`);
	// 1px rings (spread-only shadows, borders) become the UIStroke; the inset ring wins, it is the visible edge
	const rings = n.shadow.filter((s) => s.color && !s.blur && s.spread > 0 && !s.x && !s.y);
	const ring = rings.find((s) => s.inset) || rings[0];
	if (n.border && n.border.sides.every((v) => v === n.border.w)) f.push(`stroke: { color: ${c3(n.border.color)}, transparency: ${tr(n.border.color[3])}, thickness: ${n.border.w} }`);
	else if (ring) f.push(`stroke: { color: ${c3(ring.color)}, transparency: ${tr(ring.color[3])}, thickness: ${ring.spread} }`);
	const glow = n.shadow.filter((s) => s.color && !s.inset && s.blur > 0).sort((a, b) => b.blur - a.blur)[0];
	if (glow) f.push(`shadow: { color: ${c3(glow.color)}, transparency: ${tr(glow.color[3])}, y: ${glow.y}, blur: ${glow.blur} }`);
	const t = n.text[0];
	if (t) {
		const fs_ = n.font;
		f.push(`text: { value: ${JSON.stringify(t.value)}, size: ${fs_.size}, face: "${face(fs_.family)}", weight: ${fs_.weight}, tracking: ${r2(fs_.tracking / fs_.size)}, color: ${c3(n.color)}${n.color[3] < 1 ? `, transparency: ${tr(n.color[3])}` : ""}, x: ${r2(t.x - n.x)}, w: ${r2(t.w)}${fs_.decoration !== "none" ? `, decoration: "${fs_.decoration}"` : ""} }`);
	}
	if (n.svg) f.push(`icon: { color: ${c3(n.color)} }`);
	lines.push(`\t${key}: { ${f.join(", ")} },`);
}
lines.push("};");
lines.push("");
const out = path.resolve(repo, spec.out);
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, lines.join("\n"));
console.log(`wrote ${path.relative(repo, out)} (${Object.keys(spec.nodes).length} boxes)`);
