// Shared helpers for the engraved art: a seeded random (the same picture every render), the palette, and a few
// drawing primitives that build SVG strings. The look is an engraved brass instrument / old printed plate:
// thin lines, hatching and stipple for shade, worn metal, no glows.
const PAL = {
	ink: "#0f1016",
	inkSoft: "#191a22",
	iron: "#2b2c36",
	ironLight: "#4a4b57",
	brass: "#b8955a",
	brassLight: "#d9bd86",
	brassDark: "#7a5f34",
	parchment: "#e9dfc8",
	parchmentDim: "#a69c86",
	rust: "#a8513a",
	rustLight: "#c9745a",
	verdigris: "#6f9a8c",
	ember: "#c76a3c",
	emberLight: "#e3a06b",
	voidglass: "#7d6fa8",
	voidLight: "#ab9fd0",
	starsteel: "#8fa7b4",
	steelLight: "#c8d6dd",
};

function rng(seed) {
	let s = seed >>> 0 || 1;
	return () => {
		s ^= s << 13;
		s ^= s >>> 17;
		s ^= s << 5;
		return ((s >>> 0) % 100000) / 100000;
	};
}

function query(name, fallback) {
	const value = new URLSearchParams(location.search).get(name);
	return value === null ? fallback : value;
}

const polar = (cx, cy, r, deg) => {
	const a = ((deg - 90) * Math.PI) / 180;
	return [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
};

function arcPath(cx, cy, r, from, to) {
	const [x1, y1] = polar(cx, cy, r, from);
	const [x2, y2] = polar(cx, cy, r, to);
	const large = to - from > 180 ? 1 : 0;
	return `M ${x1.toFixed(2)} ${y1.toFixed(2)} A ${r} ${r} 0 ${large} 1 ${x2.toFixed(2)} ${y2.toFixed(2)}`;
}

// grain: a fine noise used as a mask, so lines read as printed or worn rather than vector-perfect
function grainDefs(id, amount, seed) {
	return `
	<filter id="${id}" x="0" y="0" width="100%" height="100%">
		<feTurbulence type="fractalNoise" baseFrequency="${amount}" numOctaves="3" seed="${seed}" result="noise"/>
		<feColorMatrix in="noise" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 -1.1 1.32" result="mask"/>
		<feComposite in="SourceGraphic" in2="mask" operator="in"/>
	</filter>`;
}

// diagonal hatching as a pattern; spacing and angle set the tone
function hatchDefs(id, color, spacing, angle, width) {
	return `
	<pattern id="${id}" patternUnits="userSpaceOnUse" width="${spacing}" height="${spacing}" patternTransform="rotate(${angle})">
		<line x1="0" y1="0" x2="0" y2="${spacing}" stroke="${color}" stroke-width="${width}"/>
	</pattern>`;
}

function mount(svg, width, height) {
	document.body.style.margin = "0";
	document.body.style.background = "transparent";
	document.body.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${svg}</svg>`;
}
