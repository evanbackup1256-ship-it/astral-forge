--!strict
-- Visual effects built on the particle textures every Roblox client ships
-- with (rbxasset://textures/particles/...). Nothing here needs an upload, so
-- the effects look the same in Studio, on desktop, on phones and on console.
--
-- Presets are tuned for the sanctuary's palette and kept cheap: low rates,
-- short lifetimes, and bursts that emit once and clean themselves up.
--
--   Vfx.attach(part, "Embers", { Color = ... })   -- a continuous emitter
--   Vfx.burst(position, "Shatter", { Color = ... }) -- a one-off, auto-cleaned
--   Vfx.beam(a0, a1, "Tether", { Color = ... })    -- a textured beam
--
-- Used by the server (ambient scenery emitters, replicated) and the client
-- (moment-to-moment effects, never replicated).

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Vfx = {}

local TEX = "rbxasset://textures/particles/"
Vfx.Textures = table.freeze({
	Sparkle = TEX .. "sparkles_main.dds",
	Fire = TEX .. "fire_main.dds",
	FireSparks = TEX .. "fire_sparks_main.dds",
	Smoke = TEX .. "smoke_main.dds",
	Glow = TEX .. "forcefield_glow_main.dds",
	Vortex = TEX .. "forcefield_vortex_main.dds",
	Core = TEX .. "explosion01_core_main.dds",
	Implosion = TEX .. "explosion01_implosion_main.dds",
	Shockwave = TEX .. "explosion01_shockwave_main.dds",
	BlastSmoke = TEX .. "explosion01_smoke_main.dds",
})

type Spec = { [string]: any }

local function seq(...: number): NumberSequence
	local values = { ... }
	local points = {}
	for i = 1, #values, 2 do
		table.insert(points, NumberSequenceKeypoint.new(values[i], values[i + 1]))
	end
	return NumberSequence.new(points)
end

local function colors(a: Color3, b: Color3?): ColorSequence
	return if b == nil then ColorSequence.new(a) else ColorSequence.new(a, b)
end

-- Presets. Color/Color2 are filled in per use; everything else is a
-- ParticleEmitter property.
local PRESETS: { [string]: Spec } = {
	-- Ambient, continuous.
	Embers = {
		Texture = Vfx.Textures.FireSparks,
		Size = seq(0, 0.35, 1, 0),
		Transparency = seq(0, 0.1, 0.7, 0.4, 1, 1),
		Lifetime = NumberRange.new(2, 3.6),
		Rate = 5,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(22, 22),
		Acceleration = Vector3.new(0, 1.2, 0),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 1,
	},
	Flame = {
		Texture = Vfx.Textures.Fire,
		Size = seq(0, 1.6, 0.5, 1.2, 1, 0.2),
		Transparency = seq(0, 1, 0.12, 0.25, 0.7, 0.55, 1, 1),
		Lifetime = NumberRange.new(0.7, 1.2),
		Rate = 14,
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-40, 40),
		LightEmission = 0.85,
		LightInfluence = 0,
	},
	Smoke = {
		Texture = Vfx.Textures.Smoke,
		Size = seq(0, 1.5, 1, 5),
		Transparency = seq(0, 1, 0.2, 0.72, 1, 1),
		Lifetime = NumberRange.new(3.5, 5.5),
		Rate = 2.5,
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(18, 18),
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-12, 12),
		Acceleration = Vector3.new(0.6, 0.8, 0),
		LightInfluence = 0.6,
	},
	Motes = {
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0, 0.3, 0.32, 1, 0),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(4, 7),
		Rate = 3,
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.25, 0),
		RotSpeed = NumberRange.new(-30, 30),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Halo = {
		-- A soft glow that sits on the part: one long-lived particle at a time.
		Texture = Vfx.Textures.Glow,
		Size = seq(0, 3.2, 0.5, 3.6, 1, 3.2),
		Transparency = seq(0, 1, 0.25, 0.62, 0.75, 0.62, 1, 1),
		Lifetime = NumberRange.new(2.4, 2.4),
		Rate = 1.1,
		Speed = NumberRange.new(0, 0),
		LockedToPart = true,
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = -0.5,
	},
	Swirl = {
		Texture = Vfx.Textures.Vortex,
		Size = seq(0, 6, 1, 7),
		Transparency = seq(0, 1, 0.3, 0.55, 0.7, 0.55, 1, 1),
		Lifetime = NumberRange.new(2.5, 2.5),
		Rate = 1.2,
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(40, 40),
		LockedToPart = true,
		LightEmission = 1,
		LightInfluence = 0,
	},
	Rising = {
		-- Sparks drifting up a column (waystones, the Warden forming).
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0.45, 1, 0),
		Transparency = seq(0, 0.1, 1, 1),
		Lifetime = NumberRange.new(1.4, 2.4),
		Rate = 10,
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(8, 8),
		LightEmission = 1,
		LightInfluence = 0,
	},

	-- One-off bursts (Emit counts come from the burst call).
	Shatter = {
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0.55, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -24, 0),
		Drag = 2.5,
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Flash = {
		Texture = Vfx.Textures.Core,
		Size = seq(0, 2, 0.3, 6, 1, 7),
		Transparency = seq(0, 0, 0.4, 0.4, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.45),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Implode = {
		Texture = Vfx.Textures.Implosion,
		Size = seq(0, 10, 1, 0.5),
		Transparency = seq(0, 1, 0.3, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.9, 0.9),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Shockwave = {
		-- Lies flat on the ground: the plane is perpendicular to its (upward) velocity.
		Texture = Vfx.Textures.Shockwave,
		Size = seq(0, 2, 1, 30),
		Transparency = seq(0, 0.1, 0.6, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.6, 0.6),
		Speed = NumberRange.new(0.01, 0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Dust = {
		Texture = Vfx.Textures.BlastSmoke,
		Size = seq(0, 3, 1, 9),
		Transparency = seq(0, 0.4, 1, 1),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(80, 10),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		LightInfluence = 0.7,
	},
	Spark = {
		Texture = Vfx.Textures.FireSparks,
		Size = seq(0, 0.4, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 4,
		LightEmission = 1,
		LightInfluence = 0,
	},
}

Vfx.PRESETS = PRESETS

local function apply(emitter: ParticleEmitter, spec: Spec, overrides: Spec?)
	for key, value in spec do
		(emitter :: any)[key] = value
	end
	if overrides ~= nil then
		for key, value in overrides do
			if key == "Color" or key == "Color2" then
				continue
			end
			(emitter :: any)[key] = value
		end
		local color = overrides.Color
		if typeof(color) == "Color3" then
			emitter.Color = colors(color, overrides.Color2)
		elseif typeof(color) == "ColorSequence" then
			emitter.Color = color
		end
	end
end

-- A continuous emitter on a part or attachment.
function Vfx.attach(parent: Instance, preset: string, overrides: Spec?): ParticleEmitter
	local spec = PRESETS[preset]
	assert(spec ~= nil, "unknown vfx preset " .. preset)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Vfx" .. preset
	apply(emitter, spec, overrides)
	emitter.Parent = parent
	return emitter
end

-- A one-off burst at a world position, cleaned up after its longest particle.
function Vfx.burst(position: Vector3, preset: string, count: number, overrides: Spec?, parent: Instance?): ParticleEmitter
	local holder = Instance.new("Part")
	holder.Name = "VfxBurst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = parent or Workspace
	local emitter = Vfx.attach(holder, preset, overrides)
	emitter.Rate = 0
	emitter:Emit(math.max(1, math.floor(count)))
	Debris:AddItem(holder, emitter.Lifetime.Max + 0.5)
	return emitter
end

-- A textured beam between two attachments.
function Vfx.beam(a0: Attachment, a1: Attachment, preset: string, overrides: Spec?): Beam
	local beam = Instance.new("Beam")
	beam.Name = "Vfx" .. preset
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 16
	if preset == "Tether" then
		beam.Texture = Vfx.Textures.Sparkle
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 4
		beam.TextureSpeed = 1.6
		beam.Width0, beam.Width1 = 1.2, 0.4
		beam.Transparency = seq(0, 0.35, 0.5, 0.1, 1, 0.5)
		beam.CurveSize0, beam.CurveSize1 = 4, -4
	elseif preset == "Column" then
		beam.Texture = Vfx.Textures.Glow
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Width0, beam.Width1 = 5, 1.5
		beam.Transparency = seq(0, 0.3, 1, 1)
	else
		error("unknown beam preset " .. preset)
	end
	if overrides ~= nil then
		local color = overrides.Color
		if typeof(color) == "Color3" then
			beam.Color = colors(color, overrides.Color2)
		end
		for key, value in overrides do
			if key ~= "Color" and key ~= "Color2" then
				(beam :: any)[key] = value
			end
		end
	end
	beam.Parent = a0
	return beam
end

return Vfx
