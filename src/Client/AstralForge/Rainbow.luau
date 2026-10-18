--!strict
-- Colour that flows, for UIGradients, without rebuilding a ColorSequence every frame.
--
-- The colours are worked out in OKLCH, where equal steps look equal: a plain HSV wheel has a glaring
-- yellow, a muddy blue and a hard magenta seam, and that is what makes a rainbow look cheap. Here
-- lightness and chroma stay even all the way round and each stop is interpolated in OKLab, so the
-- band between two keypoints never goes grey.
--
-- Two ways to animate:
--   * Rotation: put a looping sequence (Rainbow.LOOP, or Rainbow.loop(name)) on a UIGradient under
--     a UIStroke and spin its Rotation with Rainbow.spin. The sequence ends where it starts, so the
--     colours chase round the rim with no seam. One number per frame.
--   * Phase: Rainbow.at(phase) hands back one of PHASES precomputed sequences shifted by `phase`, so
--     a fill can flow sideways. 360 phases is finer than a frame at any speed the game uses, so the
--     flow is continuous rather than stepping, and nothing is allocated per frame.
local Rainbow = {} :: any

local STOPS = 16 -- a ColorSequence takes at most 20 keypoints
local PHASES = 360

local function toLinear(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end
local function toGamma(c: number): number
	c = math.clamp(c, 0, 1)
	return if c <= 0.0031308 then c * 12.92 else 1.055 * c ^ (1 / 2.4) - 0.055
end

-- OKLab (Björn Ottosson) <-> sRGB
local function oklabToColor(L: number, a: number, b: number): Color3
	local l_ = L + 0.3963377774 * a + 0.2158037573 * b
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
	local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	local bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	return Color3.new(toGamma(r), toGamma(g), toGamma(bl))
end
local function colorToOklab(color: Color3): (number, number, number)
	local r, g, b = toLinear(color.R), toLinear(color.G), toLinear(color.B)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

local function oklch(L: number, C: number, hueTurns: number): Color3
	local angle = hueTurns * math.pi * 2
	return oklabToColor(L, C * math.cos(angle), C * math.sin(angle))
end

-- mix two colours in OKLab, so the midpoint keeps its colour instead of going grey
function Rainbow.mix(a: Color3, b: Color3, t: number): Color3
	local L1, a1, b1 = colorToOklab(a)
	local L2, a2, b2 = colorToOklab(b)
	return oklabToColor(L1 + (L2 - L1) * t, a1 + (a2 - a1) * t, b1 + (b2 - b1) * t)
end

-- a palette is a function from position round the loop (0..1) to a colour
type Palette = (number) -> Color3

local function spectrum(L: number, C: number): Palette
	return function(share: number): Color3
		-- a gentle lift through the warm half keeps yellows from sinking to olive
		local lift = 0.035 * math.cos((share - 0.28) * math.pi * 2)
		return oklch(L + lift, C, share + 0.08)
	end
end

-- a closed loop through hand-picked colours, interpolated in OKLab with a smooth ease between them
local function through(colors: { Color3 }): Palette
	local count = #colors
	return function(share: number): Color3
		local position = (share % 1) * count
		local index = math.floor(position)
		local t = position - index
		t = t * t * (3 - 2 * t)
		return Rainbow.mix(colors[index % count + 1], colors[(index + 1) % count + 1], t)
	end
end

local PALETTES: { [string]: Palette } = {
	-- the full wheel at even brightness
	spectrum = spectrum(0.8, 0.13),
	-- the full wheel, quieter, for big fills and text
	soft = spectrum(0.86, 0.08),
	-- cool night sky: teal, blue, violet, rose
	aurora = through({ Color3.fromRGB(94, 234, 212), Color3.fromRGB(96, 165, 250), Color3.fromRGB(167, 139, 250), Color3.fromRGB(244, 143, 177) }),
	-- forge heat: deep red, orange, gold, white-hot
	ember = through({ Color3.fromRGB(220, 72, 54), Color3.fromRGB(250, 140, 50), Color3.fromRGB(255, 205, 96), Color3.fromRGB(255, 240, 200) }),
	-- cold metal: steel, ice, silver
	frost = through({ Color3.fromRGB(148, 178, 214), Color3.fromRGB(196, 232, 255), Color3.fromRGB(232, 236, 246), Color3.fromRGB(170, 200, 236) }),
	-- deep space: indigo, magenta, gold
	nebula = through({ Color3.fromRGB(92, 84, 220), Color3.fromRGB(196, 92, 214), Color3.fromRGB(255, 176, 102), Color3.fromRGB(140, 110, 240) }),
}
Rainbow.PALETTES = table.freeze((function()
	local names = {}
	for name in PALETTES do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end)())

local function build(palette: Palette, phase: number): ColorSequence
	local keys = table.create(STOPS + 1)
	for index = 0, STOPS do
		local share = index / STOPS
		keys[index + 1] = ColorSequenceKeypoint.new(share, palette((share + phase) % 1))
	end
	return ColorSequence.new(keys)
end

-- the old (saturation, value) arguments pick a strength of the full spectrum
local function paletteFor(saturation: number?, value: number?): (string, Palette)
	local s = saturation or 0.62
	local v = value or 1
	local key = string.format("spectrum:%.2f:%.2f", s, v)
	local found = PALETTES[key]
	if found == nil then
		-- HSV saturation 0.62 ~ the default spectrum; lower is calmer, lower value is darker
		found = spectrum(0.58 + 0.28 * v - 0.08 * s, 0.21 * s)
		PALETTES[key] = found
	end
	return key, found
end

local cache: { [string]: { ColorSequence } } = {}
local loops: { [string]: ColorSequence } = {}
-- phases are built the first time they're shown, so nothing hitches when a bar first appears
local function phaseOf(key: string, palette: Palette, phase: number): ColorSequence
	local list = cache[key]
	if list == nil then
		list = table.create(PHASES)
		cache[key] = list
	end
	local index = math.clamp(math.floor((phase % 1) * PHASES) + 1, 1, PHASES)
	local found = list[index]
	if found == nil then
		found = build(palette, (index - 1) / PHASES)
		list[index] = found
	end
	return found
end

-- the whole loop once, ending where it starts (for spinning rims)
function Rainbow.loop(name: string?): ColorSequence
	local key = name or "spectrum"
	local found = loops[key]
	if found == nil then
		found = build(PALETTES[key] or PALETTES.spectrum, 0)
		loops[key] = found
	end
	return found
end

Rainbow.LOOP = Rainbow.loop("spectrum")
Rainbow.SOFT = Rainbow.loop("soft")

-- a palette shifted by `phase` (any number; wraps every 1)
function Rainbow.flow(name: string, phase: number): ColorSequence
	return phaseOf(name, PALETTES[name] or PALETTES.spectrum, phase)

end

-- the full spectrum shifted by `phase`; saturation/value soften or darken it
function Rainbow.at(phase: number, saturation: number?, value: number?): ColorSequence
	local key, palette = paletteFor(saturation, value)
	return phaseOf(key, palette, phase)

end

-- one colour from a palette (for a tint that drifts: text, a dot, a light)
function Rainbow.color(name: string, phase: number): Color3
	return (PALETTES[name] or PALETTES.spectrum)(phase % 1)
end

-- degrees for a rim that turns once every `period` seconds
function Rainbow.spin(seconds: number, period: number?): number
	return (seconds / (period or 3)) * 360 % 360
end

-- 0..1 that eases in and out once per `period`: for glints and sweeps that shouldn't move at a
-- constant robotic speed
function Rainbow.sweep(seconds: number, period: number?): number
	local t = (seconds / (period or 3)) % 1
	return t * t * t * (t * (t * 6 - 15) + 10)
end

return table.freeze(Rainbow)
