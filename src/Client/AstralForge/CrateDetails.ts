// !strict
// Purpose: modeled crate armor, fasteners, seals and family-specific hardware.
// Owner: presentation. Dependencies: viewport model and existing skin palette.
// Review: 2026-10-05.

interface LidPiece {
	part: BasePart;
	offset: CFrame;
}

const LEGACY_FAMILY: Record<string, string> = {
	Reactor: "Furnace",
	Solar: "Furnace",
	Molten: "Furnace",
	Glacier: "Lens",
	Prism: "Lens",
	Aurora: "Lens",
	Crystal: "Lens",
	Titan: "Armory",
	Obsidian: "Armory",
	Salvage: "Armory",
	Storm: "Core",
	Lunar: "Glyph",
	DeepSea: "Pressure",
	Chrono: "Glyph",
};

const BODY_MATERIAL: Record<string, Enum.Material> = {
	Armory: Enum.Material.DiamondPlate,
	Furnace: Enum.Material.Basalt,
	Garden: Enum.Material.Glass,
	Pressure: Enum.Material.Metal,
	Glyph: Enum.Material.Slate,
	Pod: Enum.Material.Foil,
	Lens: Enum.Material.Glass,
	Core: Enum.Material.Metal,
	Halo: Enum.Material.Marble,
};

function part(
	model: Model,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material,
): Part {
	const item = new Instance("Part");
	item.Name = name;
	item.Size = size;
	item.CFrame = frame;
	item.Color = color;
	item.Material = material;
	item.Anchored = true;
	item.CanCollide = false;
	item.CanTouch = false;
	item.CanQuery = false;
	item.CastShadow = false;
	item.Parent = model;
	return item;
}

function cylinder(model: Model, name: string, length: number, diameter: number, frame: CFrame, color: Color3, material: Enum.Material): Part {
	const item = part(model, name, new Vector3(length, diameter, diameter), frame, color, material);
	item.Shape = Enum.PartType.Cylinder;
	return item;
}

function family(skinId: string, declared?: string): string {
	if (typeIs(declared, "string") && BODY_MATERIAL[declared] !== undefined) {
		return declared;
	}
	return LEGACY_FAMILY[skinId] ?? "Armory";
}

function bodyMaterial(familyName: string): Enum.Material {
	return BODY_MATERIAL[familyName] ?? Enum.Material.SmoothPlastic;
}

function build(model: Model, body: BasePart, accent: Color3, skinId: string, declared?: string): void {
	const familyName = family(skinId, declared);
	const size = body.Size;
	const metal = accent.Lerp(new Color3(0, 0, 0), 0.72);
	const trim = accent.Lerp(Color3.fromRGB(40, 36, 48), 0.55);
	const bright = accent.Lerp(new Color3(1, 1, 1), 0.3);
	const halfWidth = size.X * 0.5;
	const halfDepth = size.Z * 0.5;
	const front = -halfDepth - 0.025;
	const height = size.Y;

	part(model, "Plinth", new Vector3(size.X + 0.12, 0.08, size.Z + 0.12), new CFrame(0, 0.04, 0), metal, Enum.Material.Metal);
	for (const y of [height * 0.14, height * 0.92]) {
		part(model, "Trim band", new Vector3(size.X + 0.04, 0.05, size.Z + 0.04), new CFrame(0, y, 0), trim, Enum.Material.Metal);
	}
	for (const sx of [-1, 1]) {
		for (const sz of [-1, 1]) {
			part(model, "Corner post", new Vector3(0.1, height * 0.94, 0.1),
				new CFrame(sx * (halfWidth - 0.02), height * 0.5, sz * (halfDepth - 0.02)), metal, Enum.Material.Metal);
		}
		for (const fraction of [0.18, 0.5, 0.82]) {
			const bolt = part(model, "Hex fastener", new Vector3(0.055, 0.055, 0.045),
				new CFrame(sx * (halfWidth - 0.04), height * fraction, front - 0.06), bright, Enum.Material.Metal);
			bolt.Shape = Enum.PartType.Ball;
		}
	}
	part(model, "Seam light", new Vector3(size.X * 0.84, 0.022, 0.02), new CFrame(0, height * 0.97, front - 0.01), accent, Enum.Material.Neon);
	part(model, "Lock plate", new Vector3(0.34, 0.3, 0.05), new CFrame(0, height * 0.72, front - 0.02), metal, Enum.Material.Metal);
	part(model, "Lock status", new Vector3(0.14, 0.04, 0.025), new CFrame(0, height * 0.72, front - 0.05), accent, Enum.Material.Neon);

	if (familyName === "Furnace") {
		for (let index = 1; index <= 3; index++) {
			const coil = cylinder(model, "Cooling pipe", height * 0.65, 0.1,
				new CFrame(halfWidth + 0.08, height * 0.5, (index - 2) * size.Z * 0.25).mul(CFrame.Angles(0, 0, math.pi * 0.5)), bright, Enum.Material.Metal);
			coil.Name = "Cooling pipe";
		}
		for (let index = 1; index <= 4; index++) {
			part(model, "Vent glow", new Vector3(size.X * 0.14, 0.03, 0.02),
				new CFrame(-size.X * 0.24, height * (0.28 + index * 0.08), front - 0.01), accent, Enum.Material.Neon);
		}
	} else if (familyName === "Lens" || familyName === "Garden") {
		for (let index = 1; index <= 3; index++) {
			const crystal = part(model, familyName === "Garden" ? "Leaf pane" : "Cut crystal", new Vector3(0.14, 0.3 + index * 0.07, 0.14),
				new CFrame(halfWidth + 0.07, height * 0.42, (index - 2) * 0.24).mul(CFrame.Angles(0.15 * index, 0.4, 0.2)), accent, Enum.Material.Glass);
			crystal.Transparency = 0.15;
		}
		part(model, "Inner glow", new Vector3(size.X * 0.7, height * 0.5, size.Z * 0.7), new CFrame(0, height * 0.5, 0), accent, Enum.Material.Neon).Transparency = 0.55;
	} else if (familyName === "Pressure") {
		for (const sx of [-1, 1]) {
			cylinder(model, "Ballast tank", size.Z * 0.9, 0.26, new CFrame(sx * (halfWidth + 0.12), height * 0.36, 0).mul(CFrame.Angles(0, math.pi * 0.5, 0)), metal, Enum.Material.Metal);
			cylinder(model, "Tank ring", 0.04, 0.3, new CFrame(sx * (halfWidth + 0.12), height * 0.36, 0).mul(CFrame.Angles(0, math.pi * 0.5, 0)), accent, Enum.Material.Neon);
		}
		const gauge = cylinder(model, "Pressure gauge", 0.04, 0.22, new CFrame(-size.X * 0.26, height * 0.5, front - 0.02).mul(CFrame.Angles(0, math.pi * 0.5, 0)), bright, Enum.Material.Glass);
		gauge.Transparency = 0.2;
	} else if (familyName === "Glyph") {
		for (let index = 1; index <= 5; index++) {
			part(model, "Glyph stroke", new Vector3(0.035, 0.12 + (index % 3) * 0.05, 0.02),
				new CFrame(-size.X * 0.34 + index * 0.1, height * 0.45, front - 0.012).mul(CFrame.Angles(0, 0, (index % 2 - 0.5) * 0.7)), accent, Enum.Material.Neon);
		}
	} else if (familyName === "Pod") {
		for (const sx of [-1, 1]) {
			const fin = part(model, "Stabilizer fin", new Vector3(0.05, height * 0.6, size.Z * 0.6),
				new CFrame(sx * (halfWidth + 0.06), height * 0.42, 0).mul(CFrame.Angles(0, 0, sx * -0.18)), bright, Enum.Material.Foil);
			fin.Name = "Stabilizer fin";
		}
		cylinder(model, "Thruster", 0.16, 0.36, new CFrame(0, -0.02, 0).mul(CFrame.Angles(0, 0, math.pi * 0.5)), metal, Enum.Material.Metal);
	} else if (familyName === "Core") {
		const ring = cylinder(model, "Core ring", 0.05, height * 0.8, new CFrame(0, height * 0.5, front - 0.03).mul(CFrame.Angles(0, math.pi * 0.5, 0)), accent, Enum.Material.Neon);
		ring.Transparency = 0.1;
		cylinder(model, "Core cap", 0.06, height * 0.5, new CFrame(0, height * 0.5, front - 0.05).mul(CFrame.Angles(0, math.pi * 0.5, 0)), metal, Enum.Material.Metal);
	} else if (familyName === "Halo") {
		const halo = cylinder(model, "Halo ring", 0.03, size.X * 1.35, new CFrame(0, height * 0.55, 0).mul(CFrame.Angles(0, 0, math.pi * 0.5)), accent, Enum.Material.Neon);
		halo.Transparency = 0.25;
		for (const sx of [-1, 1]) {
			part(model, "Gilt pillar", new Vector3(0.12, height * 1.02, 0.12), new CFrame(sx * (halfWidth + 0.02), height * 0.5, front + 0.04), bright, Enum.Material.Foil);
		}
	} else {
		for (const sx of [-1, 1]) {
			part(model, "Reinforced foot", new Vector3(0.32, 0.12, size.Z * 1.1), new CFrame(sx * size.X * 0.33, 0.05, 0), metal, Enum.Material.DiamondPlate);
			part(model, "Strap", new Vector3(0.12, height * 0.9, size.Z + 0.06), new CFrame(sx * size.X * 0.26, height * 0.5, 0), trim, Enum.Material.Metal);
		}
	}
}

function buildLid(model: Model, lid: BasePart, accent: Color3, skinId: string, declared?: string): LidPiece[] {
	const familyName = family(skinId, declared);
	const size = lid.Size;
	const metal = accent.Lerp(new Color3(0, 0, 0), 0.7);
	const bright = accent.Lerp(new Color3(1, 1, 1), 0.35);
	const pieces: LidPiece[] = [];
	const add = (name: string, partSize: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape?: Enum.PartType) => {
		const item = part(model, name, partSize, lid.CFrame.mul(offset), color, material);
		if (shape) {
			item.Shape = shape;
		}
		pieces.push({ part: item, offset: offset });
		return item;
	};
	add("Lid rim", new Vector3(size.X + 0.05, 0.05, size.Z + 0.05), new CFrame(0, -size.Y * 0.5 + 0.03, 0), metal, Enum.Material.Metal);
	add("Lid ridge", new Vector3(size.X * 0.9, 0.06, 0.12), new CFrame(0, size.Y * 0.5 + 0.02, 0), bright, Enum.Material.Metal);
	add("Lid seam", new Vector3(size.X * 0.7, 0.02, 0.02), new CFrame(0, size.Y * 0.5 + 0.055, 0), accent, Enum.Material.Neon);
	add("Latch", new Vector3(0.2, 0.18, 0.05), new CFrame(0, -size.Y * 0.2, -size.Z * 0.5 - 0.03), metal, Enum.Material.Metal);
	if (familyName === "Halo" || familyName === "Core") {
		add("Crown gem", new Vector3(0.18, 0.18, 0.18), new CFrame(0, size.Y * 0.5 + 0.13, 0).mul(CFrame.Angles(math.pi * 0.25, 0, math.pi * 0.25)), accent, Enum.Material.Neon);
	} else if (familyName === "Lens" || familyName === "Garden") {
		const dome = add("Glass dome", new Vector3(size.X * 0.5, size.X * 0.5, size.X * 0.5), new CFrame(0, size.Y * 0.5, 0), accent, Enum.Material.Glass, Enum.PartType.Ball);
		dome.Transparency = 0.45;
	} else if (familyName === "Furnace") {
		add("Chimney", new Vector3(0.12, 0.16, 0.16), new CFrame(size.X * 0.3, size.Y * 0.5 + 0.08, 0).mul(CFrame.Angles(0, 0, math.pi * 0.5)), metal, Enum.Material.Metal, Enum.PartType.Cylinder);
	} else if (familyName === "Pod" || familyName === "Pressure") {
		for (const sx of [-1, 1]) {
			add("Valve", new Vector3(0.06, 0.12, 0.12), new CFrame(sx * size.X * 0.32, size.Y * 0.5 + 0.03, 0).mul(CFrame.Angles(0, 0, math.pi * 0.5)), bright, Enum.Material.Metal, Enum.PartType.Cylinder);
		}
	}
	return pieces;
}

const Details = table.freeze({ family, bodyMaterial, build, buildLid });
namespace Details {
	export interface LidPiece {
		part: BasePart;
		offset: CFrame;
	}
}
export = Details;
