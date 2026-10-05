--!strict
local EffectMath = {}

function EffectMath.lightningPoint(index: number, time: number, reducedMotion: boolean): number
	if reducedMotion or index == 0 or index == 8 then
		return 0.77
	end
	local pulse = math.floor(time * 6)
	return 0.77 + math.sin(index * 2.8 + pulse * 1.9) * 0.14
end

function EffectMath.lightningSegment(index: number, time: number, width: number, height: number, reducedMotion: boolean)
	local startY = EffectMath.lightningPoint(index - 1, time, reducedMotion)
	local endY = EffectMath.lightningPoint(index, time, reducedMotion)
	local horizontal = math.max(1, width) / 8
	local vertical = (endY - startY) * math.max(1, height)
	return {
		X = (index - 1) / 8,
		Y = startY,
		Length = math.sqrt(horizontal ^ 2 + vertical ^ 2),
		Angle = math.deg(math.atan2(vertical, horizontal)),
	}
end

return EffectMath
