--!strict



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

local LeaderboardCodec = {}

local BUCKET = 1_000_000_000_000

local MAX_EXPONENT = 1_000_000
local MAX_DOUBLE = 1e308

function LeaderboardCodec.Encode(value: any): number
	if OmegaMath.Lte(value, 0) then
		return 0
	end
	local log10 = OmegaMath.Log10(value)
	if type(log10) ~= "number" or log10 ~= log10 or log10 <= 0 then
		local numeric = OmegaMath.ToNumber(value)
		if numeric <= 0 then
			return 0
		end
		log10 = math.log10(numeric)
	end
	local exponent = math.clamp(math.floor(log10), 0, MAX_EXPONENT)
	local significand = 10 ^ (log10 - exponent)
	if significand ~= significand or significand < 1 then
		significand = 1
	elseif significand > 10 then
		significand = 10
	end
	local fraction = math.clamp((significand - 1) / 9, 0, 1)
	return exponent * BUCKET + math.floor(fraction * (BUCKET - 2) + 0.5) + 1
end

function LeaderboardCodec.Decode(score: any): number | string
	local packed = math.max(0, math.floor(tonumber(score) or 0))
	if packed <= 0 then
		return 0
	end
	packed -= 1
	local exponent = math.clamp(math.floor(packed / BUCKET), 0, MAX_EXPONENT)
	local fraction = math.clamp((packed - exponent * BUCKET) / (BUCKET - 2), 0, 1)
	local significand = 1 + fraction * 9
	if exponent >= 15 then
		return string.format("%.12fe%d", significand, exponent)
	end
	return math.clamp(significand * (10 ^ exponent), 0, MAX_DOUBLE)
end

return table.freeze(LeaderboardCodec)
