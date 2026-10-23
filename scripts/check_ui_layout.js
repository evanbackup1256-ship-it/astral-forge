#!/usr/bin/env node
// Static UI layout checker for the client TSX/TS sources (JSX and React.createElement/h(...) trees).
// Rules:
//   list-child-position   GuiObject sibling of a UIListLayout/UIGridLayout with a literal non-zero Position (the layout ignores it)
//   list-missing-order    SortOrder=LayoutOrder layout whose GuiObject siblings mix explicit LayoutOrder with none
//   scale-in-automatic    child Size uses Scale on an axis the parent sizes with AutomaticSize (resolves to 0 / feedback loop)
//   negative-size         Size with scale 0 and a negative offset on an axis
//   scroll-no-canvas      ScrollingFrame without CanvasSize or AutomaticCanvasSize
//   legacy-import         IconTile imported from UiCore/ui outside the kit (old filled tile; use mockKit Glyph/GlyphSlot/Gem/IconWell)
//   legacy-panel          ui Panel without the brass `rule` (pre-mockup card look; pass rule or use MockPanel)
//   list-child-position-dynamic  computed Position on a list child (also ignored by the layout)
// Usage: node scripts/check_ui_layout.js [--update-baseline] [--all]
// Findings listed in scripts/ui_layout_baseline.json are reported as known and don't fail; new ones exit 1.
const ts = require("typescript");
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const srcDir = path.join(root, "src/Client");
const baselinePath = path.join(__dirname, "ui_layout_baseline.json");
const GUI = new Set(["frame","textlabel","textbutton","textbox","imagelabel","imagebutton","scrollingframe","canvasgroup","viewportframe","videoframe"]);
const LEGACY_ALLOWED = new Set(["UiCore/ui.tsx","UiCore/primitives.tsx","UiCore/mockKit.tsx","UiCore/surface.tsx"]);
const LEGACY_NAMES = new Set(["IconTile"]);

function walkDir(d, out) {
	for (const f of fs.readdirSync(d)) {
		const p = path.join(d, f);
		if (fs.statSync(p).isDirectory()) walkDir(p, out);
		else if (/\.tsx?$/.test(f) && !/\.d\.ts$/.test(f)) out.push(p);
	}
	return out;
}
function propName(n) { return n && (ts.isIdentifier(n) || ts.isStringLiteral(n)) ? n.text : undefined; }
function num(n) {
	if (!n) return undefined;
	if (ts.isNumericLiteral(n)) return Number(n.text);
	if (ts.isPrefixUnaryExpression(n) && n.operator === ts.SyntaxKind.MinusToken && ts.isNumericLiteral(n.operand)) return -Number(n.operand.text);
	if (ts.isParenthesizedExpression(n)) return num(n.expression);
	return undefined; // non-literal
}
// returns {xs, xo, ys, yo} with undefined for unknown parts, or null if not a UDim2 literal
function udim2(e) {
	if (!e) return null;
	while (ts.isParenthesizedExpression(e) || ts.isAsExpression(e)) e = e.expression;
	if (ts.isJsxExpression && ts.isJsxExpression(e)) return udim2(e.expression);
	const call = ts.isCallExpression(e) || ts.isNewExpression(e) ? e : null;
	if (!call) return null;
	const callee = call.expression.getText();
	const a = (call.arguments || []).map(num);
	const nargs = (call.arguments || []).length;
	if (callee === "UDim2.fromOffset") return { xs: 0, xo: nargs > 0 ? a[0] : 0, ys: 0, yo: nargs > 1 ? a[1] : 0 };
	if (callee === "UDim2.fromScale") return { xs: nargs > 0 ? a[0] : 0, xo: 0, ys: nargs > 1 ? a[1] : 0, yo: 0 };
	if (callee === "UDim2" && ts.isNewExpression(call)) {
		if (nargs === 0) return { xs: 0, xo: 0, ys: 0, yo: 0 };
		if (nargs === 4) return { xs: a[0], xo: a[1], ys: a[2], yo: a[3] };
		if (nargs === 2) { // new UDim2(UDim, UDim)
			const ud = (x) => { if (x && ts.isNewExpression(x) && x.expression.getText() === "UDim") { const b = (x.arguments||[]).map(num); return [b[0] ?? 0, b[1] ?? 0]; } return [undefined, undefined]; };
			const [xs, xo] = ud(call.arguments[0]); const [ys, yo] = ud(call.arguments[1]);
			return { xs, xo, ys, yo };
		}
	}
	return null;
}
function autoAxes(e) {
	if (!e) return "";
	const t = e.getText();
	const m = /AutomaticSize\.(XY|X|Y)\b/.exec(t);
	if (!m) return "";
	if (/\?/.test(t)) return "?" + m[1]; // conditional
	return m[1];
}

function collect(file) {
	const text = fs.readFileSync(file, "utf8");
	const sf = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, file.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
	const rel = path.relative(path.join(srcDir, "AstralForge"), file).split(path.sep).join("/");
	const findings = [];
	const add = (rule, node, msg) => {
		const { line } = sf.getLineAndCharacterOfPosition(node.getStart());
		findings.push({ rule, file: rel, line: line + 1, msg });
	};
	// local bindings: name -> [{pos, init}] plus `name.key = value` / `name[k] = value` member writes
	const decls = new Map();
	const writes = new Map();
	const assigns = new Map();
	(function scan(n) {
		if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name) && n.initializer) {
			if (!decls.has(n.name.text)) decls.set(n.name.text, []);
			decls.get(n.name.text).push({ pos: n.getStart(), init: n.initializer });
		}
		if (ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.EqualsToken && (ts.isPropertyAccessExpression(n.left) || ts.isElementAccessExpression(n.left)) && ts.isIdentifier(n.left.expression)) {
			const nm = n.left.expression.text;
			if (!writes.has(nm)) writes.set(nm, []);
			writes.get(nm).push({ pos: n.getStart(), init: n.right });
		}
		if (ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.EqualsToken && ts.isIdentifier(n.left)) {
			if (!assigns.has(n.left.text)) assigns.set(n.left.text, []);
			assigns.get(n.left.text).push({ pos: n.getStart(), init: n.right });
		}
		ts.forEachChild(n, scan);
	})(sf);
	function fnOf(n) { while (n && !ts.isFunctionLike(n)) n = n.parent; return n; }
	function resolve(id) {
		const list = (decls.get(id.text) || []).concat(assigns.get(id.text) || []);
		const fn = fnOf(id), at = id.getStart();
		let cands = list.filter((d) => fnOf(d.init) === fn && d.pos < at);
		if (!cands.length) cands = list.filter((d) => d.pos < at);
		const out = cands.map((d) => d.init);
		for (const w of writes.get(id.text) || []) if (w.pos < at && fnOf(w.init) === fn) out.push(w.init);
		return out;
	}
	let depth = 0;
	// element extraction
	function elementOf(n) {
		if (!n) return null;
		while (ts.isParenthesizedExpression(n)) n = n.expression;
		if (ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n)) {
			const open = ts.isJsxElement(n) ? n.openingElement : n;
			const tag = open.tagName.getText();
			const props = {};
			for (const at of open.attributes.properties) if (ts.isJsxAttribute(at)) props[at.name.getText()] = at.initializer && ts.isJsxExpression(at.initializer) ? at.initializer.expression : at.initializer;
			const kids = [];
			if (ts.isJsxElement(n)) for (const c of n.children) pushKids(c, kids);
			return { tag, props, kids, node: n };
		}
		if (ts.isCallExpression(n) && n.arguments.length && (ts.isStringLiteral(n.arguments[0]) || ts.isIdentifier(n.arguments[0]) || ts.isPropertyAccessExpression(n.arguments[0]))) {
			const cal = n.expression.getText();
			if (!/^(h|e|React\.createElement|createElement|el)$/.test(cal)) return null;
			const tag = ts.isStringLiteral(n.arguments[0]) ? n.arguments[0].text : n.arguments[0].getText();
			const props = {};
			const pa = n.arguments[1];
			let pObj = pa;
			if (pa && ts.isIdentifier(pa)) { const r = resolve(pa).filter((x) => ts.isObjectLiteralExpression(x)); if (r.length) pObj = r[r.length - 1]; for (const w of writes.get(pa.text) || []) if (w.pos < n.getStart() && ts.isPropertyAccessExpression(w.init.parent.left)) props[w.init.parent.left.name.text] = w.init; }
			if (pObj && ts.isObjectLiteralExpression(pObj)) for (const p of pObj.properties) { if (ts.isPropertyAssignment(p)) props[propName(p.name)] = p.initializer; else if (ts.isShorthandPropertyAssignment(p)) props[p.name.text] = p.name; }
			if (false) for (const p of pa.properties) { if (ts.isPropertyAssignment(p)) props[propName(p.name)] = p.initializer; else if (ts.isShorthandPropertyAssignment(p)) props[p.name.text] = p.name; }
			const kids = [];
			for (const c of n.arguments.slice(2)) pushKids(c, kids);
			return { tag, props, kids, node: n };
		}
		return null;
	}
	function pushKids(c, kids) {
		if (!c) return;
		if (ts.isJsxText && ts.isJsxText(c)) return;
		if (ts.isJsxExpression(c)) return pushKids(c.expression, kids);
		if (ts.isParenthesizedExpression(c)) return pushKids(c.expression, kids);
		if (ts.isBinaryExpression(c) && (c.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken)) return pushKids(c.right, kids, true);
		if (ts.isConditionalExpression(c)) { pushKids(c.whenTrue, kids); pushKids(c.whenFalse, kids); return; }
		if (ts.isObjectLiteralExpression(c)) { for (const p of c.properties) { if (ts.isPropertyAssignment(p)) pushKids(p.initializer, kids); else if (ts.isSpreadAssignment(p)) pushKids(p.expression, kids); else if (ts.isShorthandPropertyAssignment(p)) pushKids(p.name, kids); } return; }
		if (ts.isArrayLiteralExpression(c)) { for (const p of c.elements) pushKids(p, kids); return; }
		if (ts.isIdentifier(c) && depth < 6) { depth++; for (const r of resolve(c)) pushKids(r, kids); depth--; return; }
		if (ts.isSpreadElement && (ts.isSpreadElement(c) || ts.isSpreadAssignment(c))) return pushKids(c.expression, kids);
		const el = elementOf(c);
		if (el) kids.push(el);
	}
	function check(el) {
		const t = el.tag.toLowerCase();
		if ((el.tag === "Panel" || el.tag === "CorePanel") && !LEGACY_ALLOWED.has(rel) && !("rule" in el.props) && !el.kids.some((k) => k.tag === "BrassRule")) add("legacy-panel", el.node, "Panel without the brass rule (old card look; pass rule or use MockPanel)");
		if (!/^[a-z]/.test(el.tag)) return;
		// negative size
		const sz = udim2(el.props.Size);
		if (sz && ((sz.xs === 0 && sz.xo < 0) || (sz.ys === 0 && sz.yo < 0))) add("negative-size", el.node, `${el.tag} Size ${el.props.Size.getText()}`);
		if (t === "scrollingframe" && !("CanvasSize" in el.props) && !("AutomaticCanvasSize" in el.props)) add("scroll-no-canvas", el.node, "ScrollingFrame has neither CanvasSize nor AutomaticCanvasSize");
		if (t === "scrollingframe") {
			const acs = autoAxes(el.props.AutomaticCanvasSize);
			const csz = udim2(el.props.CanvasSize);
			for (const k of el.kids.filter((k) => GUI.has(k.tag))) {
				const ks = udim2(k.props.Size);
				if (!ks) continue;
				const kAuto = autoAxes(k.props.AutomaticSize);
				// content sized by Scale on the scroll axis is as tall as the window: it never scrolls
				if (acs.includes("Y") && ks.ys > 0 && !kAuto.includes("Y") && !(ks.xo !== undefined && ks.xs === 0 && ks.xo <= 2)) add("scroll-scale-content", k.node, `${k.tag} Size ${k.props.Size.getText()} fills the ScrollingFrame window on Y; AutomaticCanvasSize.Y can't grow`);
				if (acs.includes("X") && !acs.includes("Y") && ks.xs > 0 && !kAuto.includes("X") && !(ks.yo !== undefined && ks.ys === 0 && ks.yo <= 2) && /Direction\.X/.test(el.props.ScrollingDirection ? el.props.ScrollingDirection.getText() : "")) add("scroll-scale-content", k.node, `${k.tag} Size ${k.props.Size.getText()} fills the ScrollingFrame window on X`);
			}
			if (csz && !acs && csz.ys === 0 && csz.yo === 0 && csz.xs === 0 && csz.xo === 0) add("scroll-no-canvas", el.node, "CanvasSize is zero and AutomaticCanvasSize is not set: nothing scrolls");
		}
		const layout = el.kids.find((k) => k.tag === "uilistlayout" || k.tag === "uigridlayout");
		const guiKids = el.kids.filter((k) => GUI.has(k.tag));
		const compKids = el.kids.filter((k) => /^[A-Z]/.test(k.tag) || /\./.test(k.tag));
		if (layout) {
			for (const k of guiKids) {
				const pos = udim2(k.props.Position);
				if (pos && [pos.xs, pos.xo, pos.ys, pos.yo].some((v) => v !== 0)) add("list-child-position", k.node, `${k.tag} under ${layout.tag} sets Position ${k.props.Position.getText()} (ignored by the layout)`);
				else if (!pos && k.props.Position && !/^undefined$/.test(k.props.Position.getText())) add("list-child-position-dynamic", k.node, `${k.tag} under ${layout.tag} sets Position ${k.props.Position.getText().slice(0, 60)} (ignored by the layout)`);
			}
			for (const k of compKids) {
				const pos = udim2(k.props.position);
				if (pos && [pos.xs, pos.xo, pos.ys, pos.yo].some((v) => v !== 0)) add("list-child-position", k.node, `<${k.tag}> under ${layout.tag} passes position ${k.props.position.getText()} (ignored by the layout)`);
				else if (!pos && k.props.position && !/^undefined$/.test(k.props.position.getText())) add("list-child-position-dynamic", k.node, `<${k.tag}> under ${layout.tag} passes position ${k.props.position.getText().slice(0, 60)} (ignored by the layout)`);
			}
			const so = layout.props.SortOrder ? layout.props.SortOrder.getText() : "";
			if (/LayoutOrder/.test(so) && guiKids.length >= 2) {
				const withO = guiKids.filter((k) => "LayoutOrder" in k.props).length;
				if (withO > 0 && withO < guiKids.length) add("list-missing-order", layout.node, `${guiKids.length - withO}/${guiKids.length} siblings lack LayoutOrder`);
			}
		}
		if (!layout) {
			// literal offset-only rects of absolutely placed siblings that intersect
			const rects = [];
			for (const k of el.kids) {
				if (!GUI.has(k.tag) && !/^(Text|Line|Button|Glyph|Chip|Bar)$/.test(k.tag)) continue;
				const sz = udim2(k.props.Size || k.props.size);
				const ps = k.props.Position || k.props.position ? udim2(k.props.Position || k.props.position) : { xs: 0, xo: 0, ys: 0, yo: 0 };
				if (!sz || !ps || k.props.AnchorPoint || k.props.anchor || k.props.Visible) continue;
				const v = [sz.xs, sz.xo, sz.ys, sz.yo, ps.xs, ps.xo, ps.ys, ps.yo];
				if (v.some((x) => x === undefined) || sz.xs !== 0 || sz.ys !== 0 || ps.xs !== 0 || ps.ys !== 0) continue;
				if (sz.xo <= 0 || sz.yo <= 0) continue;
				if ((k.props.BackgroundTransparency === undefined || k.props.BackgroundTransparency.getText() !== "1") && GUI.has(k.tag) && k.tag === "frame") continue; // decorative fills
				rects.push({ k, x0: ps.xo, y0: ps.yo, x1: ps.xo + sz.xo, y1: ps.yo + sz.yo });
			}
			for (let i = 0; i < rects.length; i++) for (let j = i + 1; j < rects.length; j++) {
				const a = rects[i], b = rects[j];
				const w = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0), hh = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0);
				if (w > 2 && hh > 2) add("sibling-overlap", b.k.node, `${b.k.tag} [${b.x0},${b.y0} ${b.x1 - b.x0}x${b.y1 - b.y0}] overlaps ${a.k.tag} at line ${sf.getLineAndCharacterOfPosition(a.k.node.getStart()).line + 1} by ${w}x${hh}px`);
			}
		}
		const ax = autoAxes(el.props.AutomaticSize);
		if (ax && !ax.startsWith("?")) {
			for (const k of guiKids) {
				const ks = udim2(k.props.Size);
				if (!ks) continue;
				if ((ax.includes("X") && ks.xs > 0) || (ax.includes("Y") && ks.ys > 0)) add("scale-in-automatic", k.node, `${k.tag} Size ${k.props.Size.getText()} inside AutomaticSize.${ax} ${el.tag}`);
			}
		}
	}
	const seen = new Set();
	function visit(n) {
		const el = elementOf(n);
		if (el && !seen.has(el.node) && !(el.tag.startsWith("ui") && false)) { seen.add(el.node); check(el); }
		ts.forEachChild(n, visit);
	}
	visit(sf);
	// legacy imports
	if (!LEGACY_ALLOWED.has(rel)) for (const st of sf.statements) {
		if (ts.isImportDeclaration(st) && /UiCore\/ui"$|^"\.\/ui"$/.test(st.moduleSpecifier.getText()) && st.importClause && st.importClause.namedBindings && ts.isNamedImports(st.importClause.namedBindings)) {
			for (const sp of st.importClause.namedBindings.elements) if (LEGACY_NAMES.has((sp.propertyName || sp.name).text)) add("legacy-import", st, `imports ${(sp.propertyName || sp.name).text} from ui (old component; use mockKit)`);
		}
	}
	return findings;
}

const files = walkDir(srcDir, []);
const all = files.flatMap(collect);
const key = (f) => `${f.rule}|${f.file}|${f.msg}`;
const args = process.argv.slice(2);
if (args.includes("--update-baseline")) {
	fs.writeFileSync(baselinePath, JSON.stringify(all.map(key).sort(), null, "\t") + "\n");
	console.log(`baseline written: ${all.length} known findings`);
	process.exit(0);
}
const baseline = new Set(fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, "utf8")) : []);
const fresh = all.filter((f) => !baseline.has(key(f)));
const shown = args.includes("--all") ? all : fresh;
for (const f of shown) console.log(`${f.file}:${f.line}: [${f.rule}] ${f.msg}${baseline.has(key(f)) ? " (baseline)" : ""}`);
const counts = {};
for (const f of all) counts[f.rule] = (counts[f.rule] || 0) + 1;
console.log(`ui layout: ${all.length} findings (${Object.entries(counts).map(([k, v]) => `${k}=${v}`).join(", ") || "none"}), ${fresh.length} new`);
process.exit(fresh.length ? 1 : 0);
