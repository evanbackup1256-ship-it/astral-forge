#!/usr/bin/env node
// Fails when compiled roblox-ts output has a circular top-level TS.import chain.
// roblox-ts aborts at runtime ("Failed to import! Detected a circular dependency chain"),
// so any cycle here crashes the client or server on boot.
const fs = require("fs");
const path = require("path");
const root = path.resolve(process.argv[2] || "out");
const files = [];
(function walk(d) {
	for (const e of fs.readdirSync(d, { withFileTypes: true })) {
		const p = path.join(d, e.name);
		if (e.isDirectory()) walk(p);
		else if (/\.luau?$/.test(e.name)) files.push(p);
	}
})(root);
const modOf = (f) => {
	const noExt = f.replace(/\.luau?$/, "");
	return path.basename(noExt) === "init" ? path.dirname(noExt) : noExt;
};
const known = new Map();
for (const f of files) known.set(modOf(f), f);
const graph = new Map();
const re = /^(?!\s)[^\n]*?TS\.import\(script, (script(?:\.Parent)*)((?:, "[^"]+")*)\)/gm;
for (const f of files) {
	const me = modOf(f);
	const src = fs.readFileSync(f, "utf8");
	const deps = new Set();
	for (const m of src.matchAll(re)) {
		const ups = (m[1].match(/\.Parent/g) || []).length;
		let base = me;
		for (let i = 0; i < ups; i++) base = path.dirname(base);
		const parts = [...m[2].matchAll(/"([^"]+)"/g)].map((x) => x[1]);
		const target = path.join(base, ...parts);
		if (known.has(target)) deps.add(target);
	}
	graph.set(me, deps);
}
const state = new Map();
const stack = [];
const cycles = new Set();
function dfs(n) {
	state.set(n, 1);
	stack.push(n);
	for (const d of graph.get(n) || []) {
		if (state.get(d) === 1) {
			const c = stack.slice(stack.indexOf(d)).map((x) => path.relative(root, x));
			const k = Math.min(...c.map((_, i) => i));
			cycles.add([...c, path.relative(root, d)].join(" => "));
		} else if (!state.get(d)) dfs(d);
	}
	stack.pop();
	state.set(n, 2);
}
for (const n of graph.keys()) if (!state.get(n)) dfs(n);
if (cycles.size) {
	console.error(`circular imports: ${cycles.size}`);
	for (const c of cycles) console.error("  " + c);
	process.exit(1);
}
console.log(`import cycles: none (${graph.size} modules)`);
