--!strict

local HttpService = game:GetService("HttpService")

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

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
				local h1 = t % 1
				local h2 = (t + 0.08) % 1
				local h3 = (t + 0.18) % 1
				local c1 = Color3.fromHSV(h1, 0.72, 1)
				local c2 = Color3.fromHSV(h2, 0.38, 1)
				local c3 = Color3.fromHSV(h3, 0.85, 0.98)
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, c2),
					ColorSequenceKeypoint.new(0.48, c1),
					ColorSequenceKeypoint.new(1, c3),
				})
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
