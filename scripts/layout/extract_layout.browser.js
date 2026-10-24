// Runs inside a mockup page (headless Chrome). Dumps every visible element under the root as JSON:
// rect, radius, fills (solid + gradient layers), border, box-shadow, text runs with font metrics.
// Output lands in a textarea (#__layout) so `chrome --dump-dom` can carry it out.
(function () {
	const ROOT = window.__LAYOUT_ROOT || ".screen";
	const num = (v) => (v === "normal" || v === "" ? 0 : parseFloat(v) || 0);
	function rgba(c) {
		c = c.trim();
		let m = c.match(/^color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)(?: \/ ([\d.]+))?\)/);
		if (m) return [m[1], m[2], m[3]].map((x) => Math.round(Math.min(1, Math.max(0, +x)) * 255)).concat([m[4] === undefined ? 1 : +m[4]]);
		if (c === "transparent") return [0, 0, 0, 0];
		m = c.match(/^rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/);
		if (m) return [Math.round(+m[1]), Math.round(+m[2]), Math.round(+m[3]), m[4] === undefined ? 1 : +m[4]];
		return null;
	}
	function split(s) {
		const o = [];
		let d = 0, b = "";
		for (const ch of s) {
			if (ch === "(") d++;
			if (ch === ")") d--;
			if (ch === "," && d === 0) { o.push(b.trim()); b = ""; } else b += ch;
		}
		if (b.trim()) o.push(b.trim());
		return o;
	}
	function gradient(g) {
		const m = g.match(/^(repeating-)?(linear|radial)-gradient\((.*)\)$/s);
		if (!m) return g.startsWith("url(") ? { kind: "image", url: g.slice(4, -1).replace(/"/g, "") } : null;
		const parts = split(m[3]);
		const out = { kind: (m[1] ? "repeating-" : "") + m[2], stops: [] };
		if (!/^(rgb|#|color|transparent|hsl)/.test(parts[0])) out.shape = parts.shift();
		for (const p of parts) {
			const mm = p.match(/^(.*\)|\S+)\s*(.*)$/);
			out.stops.push({ color: rgba(mm[1]), at: mm[2] || null });
		}
		if (m[2] === "linear") {
			const f = out.shape || "180deg";
			const map = { "to top": 0, "to right": 90, "to bottom": 180, "to left": 270 };
			out.angle = /deg$/.test(f) ? parseFloat(f) : map[f] ?? 180;
		}
		return out;
	}
	function shadows(s) {
		if (s === "none") return [];
		return split(s).map((sh) => {
			const m = sh.match(/^(.*\))\s+(-?[\d.]+)px (-?[\d.]+)px ([\d.]+)px (-?[\d.]+)px( inset)?$/);
			return m ? { color: rgba(m[1]), x: +m[2], y: +m[3], blur: +m[4], spread: +m[5], inset: !!m[6] } : { raw: sh };
		});
	}
	const root = document.querySelector(ROOT);
	const base = root.getBoundingClientRect();
	let nextId = 0;
	function walk(el, parent) {
		const cs = getComputedStyle(el);
		if (cs.display === "none" || cs.visibility === "hidden") return null;
		const r = el.getBoundingClientRect();
		const cls = typeof el.className === "string" ? el.className.trim() : (el.getAttribute("class") || "");
		const node = {
			id: nextId++,
			tag: el.tagName.toLowerCase(),
			cls: cls,
			x: +(r.left - base.left).toFixed(2), y: +(r.top - base.top).toFixed(2),
			w: +r.width.toFixed(2), h: +r.height.toFixed(2),
			radius: num(cs.borderTopLeftRadius),
			opacity: +cs.opacity,
			bg: rgba(cs.backgroundColor),
			layers: cs.backgroundImage === "none" ? [] : split(cs.backgroundImage).map(gradient).filter(Boolean),
			border: num(cs.borderTopWidth) > 0 && cs.borderTopStyle !== "none" ? { w: num(cs.borderTopWidth), color: rgba(cs.borderTopColor), sides: [num(cs.borderTopWidth), num(cs.borderRightWidth), num(cs.borderBottomWidth), num(cs.borderLeftWidth)] } : (num(cs.borderBottomWidth) > 0 ? { w: num(cs.borderBottomWidth), color: rgba(cs.borderBottomColor), sides: [0, 0, num(cs.borderBottomWidth), 0] } : null),
			shadow: shadows(cs.boxShadow),
			pad: [num(cs.paddingTop), num(cs.paddingRight), num(cs.paddingBottom), num(cs.paddingLeft)],
			gap: num(cs.rowGap), colGap: num(cs.columnGap),
			display: cs.display, dir: cs.flexDirection, grid: cs.display === "grid" ? cs.gridTemplateColumns : undefined,
			color: rgba(cs.color),
			font: { family: cs.fontFamily, size: num(cs.fontSize), weight: +cs.fontWeight, tracking: num(cs.letterSpacing), lineHeight: cs.lineHeight, transform: cs.textTransform, decoration: cs.textDecorationLine, align: cs.textAlign },
			src: el.tagName === "IMG" ? el.getAttribute("src") : undefined,
			text: [],
			children: [],
		};
		if (node.tag === "svg") { node.svg = true; return node; }
		for (const n of el.childNodes) {
			if (n.nodeType === 3 && n.textContent.trim()) {
				const rg = document.createRange();
				rg.selectNodeContents(n);
				const rc = rg.getBoundingClientRect();
				let t = n.textContent.replace(/\s+/g, " ").trim();
				if (cs.textTransform === "uppercase") t = t.toUpperCase();
				node.text.push({ value: t, x: +(rc.left - base.left).toFixed(2), y: +(rc.top - base.top).toFixed(2), w: +rc.width.toFixed(2), h: +rc.height.toFixed(2) });
			} else if (n.nodeType === 1) {
				const c = walk(n, node);
				if (c) node.children.push(c);
			}
		}
		for (const pe of ["::before", "::after"]) {
			const p = getComputedStyle(el, pe);
			if (p.content && p.content !== "none" && p.content !== "normal") {
				node[pe === "::before" ? "before" : "after"] = { content: p.content, bg: rgba(p.backgroundColor), layers: p.backgroundImage === "none" ? [] : split(p.backgroundImage).map(gradient).filter(Boolean), w: num(p.width), h: num(p.height), top: p.top, left: p.left, right: p.right, bottom: p.bottom, radius: num(p.borderTopLeftRadius), opacity: +p.opacity };
			}
		}
		return node;
	}
	const tree = walk(root, null);
	const ta = document.createElement("textarea");
	ta.id = "__layout";
	ta.textContent = JSON.stringify({ source: location.pathname, width: base.width, height: base.height, root: tree });
	document.body.appendChild(ta);
})();
