--!strict

local HttpService = game:GetService("HttpService")

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

-- Colours come from OKLCH, where the hue wheel has even brightness (no glaring yellow or muddy
-- blue), and each of the 360 phases is built once and shared by every glyph, so nothing is
-- allocated per frame and the flow has no visible steps.
local PHASES = 360
local function toGamma(c : number) : number
	c = math.clamp(c, 0, 1)
	return if c <= 0.0031308 then c * 12.92 else 1.055 * c ^ (1 / 2.4) - 0.055
end
local function oklch(L : number, C : number, turns : number) : Color3
	local a, b = C * math.cos(turns * math.pi * 2), C * math.sin(turns * math.pi * 2)
	local l_ = L + 0.3963377774 * a + 0.2158037573 * b
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
	return Color3.new(
		toGamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		toGamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		toGamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
	)
end
local sequences : {[number] : ColorSequence} = {}
local function sequenceAt(t : number) : ColorSequence
	local index = math.floor((t % 1) * PHASES)
	local found = sequences[index]
	if not found then
		local h = index / PHASES
		-- a pale highlight leading, the full colour in the middle, a deeper tone trailing
		found = ColorSequence.new({
			ColorSequenceKeypoint.new(0, oklch(0.92, 0.06, h + 0.06)),
			ColorSequenceKeypoint.new(0.5, oklch(0.82, 0.13, h)),
			ColorSequenceKeypoint.new(1, oklch(0.74, 0.15, h - 0.08)),
		})
		sequences[index] = found
	end
	return found
end

local name : "rainbow" = "rainbow"
local type_ : "paired" = "paired"
local applyToImages : true = true
local module : types.dataModule<typeof(name), typeof(type_), typeof(applyToImages)> = {
	type = type_,
	name = name,
	applyToImages = applyToImages,

	onPrint = function(
		obj : types.hyperTextClassObject,
		printerData : types.printerDataRowEntry,
		spanData : types.onPrintMarkupSpanData,
		updater : {[string] : (dt : number) -> ()}
	)
		if printerData.markups.rainbow.value and obj._markupIndices and obj._contentFolder then
			local updaterId = HttpService:GenerateGUID()

			if not obj._markupIndices["rainbow"] then
				obj._markupIndices["rainbow"] = 0
			end

			local index = obj._markupIndices["rainbow"]
			local grad = printerData.character:FindFirstChildOfClass("UIGradient")
			if not grad then
				grad = Instance.new("UIGradient")
				grad.Rotation = 72
				grad.Parent = printerData.character
			end
			if printerData.character:IsA("TextLabel") then
				printerData.character.TextColor3 = Color3.new(1, 1, 1)
			else
				printerData.character.ImageColor3 = Color3.new(1, 1, 1)
			end

			updater[updaterId] = function(dt : number)
				debug.profilebegin("Rainbow Markup")

				local t = os.clock() * printerData.markups.rainbow.attributes.freq
					- printerData.markups.rainbow.attributes.offset * index
				grad.Color = sequenceAt(t)
				grad.Rotation = 65 + math.sin(t * math.pi * 2) * 25

				debug.profileend()
			end

			obj._contentFolder.Destroying:Once(function()
				updater[updaterId] = nil
			end)

			obj._markupIndices["rainbow"] += 1
		end
	end,
	convert = util.stringToBoolean,
	attributes = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
	},
	valueAttributes = {},
}

return module
