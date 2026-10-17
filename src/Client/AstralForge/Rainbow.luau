--!strict
-- Rainbow colour for UIGradients without rebuilding a ColorSequence every frame.
--
-- Two ways to animate:
--   * Rotation: put Rainbow.LOOP on a UIGradient under a UIStroke and spin its Rotation. The
--     sequence starts and ends on the same hue, so the colours chase each other round the rim
--     with no seam. One number per frame.
--   * Phase: Rainbow.at(phase) hands back one of PHASES precomputed sequences whose hues are
--     shifted by `phase`, so a fill can flow sideways. Still no allocation per frame.
local Rainbow = {}

local STOPS = 12
local PHASES = 48

local function build(phase: number, saturation: number, value: number): ColorSequence
	local keys = table.create(STOPS + 1)
	for index = 0, STOPS do
		local share = index / STOPS
		keys[index + 1] = ColorSequenceKeypoint.new(share, Color3.fromHSV((share + phase) % 1, saturation, value))
	end
	return ColorSequence.new(keys)
end

-- the whole wheel once, ending where it starts
Rainbow.LOOP = build(0, 0.62, 1)
-- softer, for big fills and text
Rainbow.SOFT = build(0, 0.42, 1)

local cache: { [string]: { ColorSequence } } = {}
local function table_for(saturation: number, value: number): { ColorSequence }
	local key = string.format("%.2f:%.2f", saturation, value)
	local list = cache[key]
	if list == nil then
		list = table.create(PHASES)
		for index = 1, PHASES do
			list[index] = build((index - 1) / PHASES, saturation, value)
		end
		cache[key] = list
	end
	return list
end

-- the rainbow shifted by `phase` (any number; wraps every 1)
function Rainbow.at(phase: number, saturation: number?, value: number?): ColorSequence
	local list = table_for(saturation or 0.62, value or 1)
	local index = math.floor((phase % 1) * PHASES) + 1
	return list[math.clamp(index, 1, PHASES)]
end

-- degrees for a rim that turns once every `period` seconds
function Rainbow.spin(seconds: number, period: number?): number
	return (seconds / (period or 3)) * 360 % 360
end

return table.freeze(Rainbow)
