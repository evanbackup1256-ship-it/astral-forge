--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")
local emitImage = require("../../Internal/Helpers/EmitImage")
local emitImgAttrsConverters = require("../../Internal/Helpers/EmitImgAttrsConverters")

local name : "emitImg" = "emitImg"
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
		if printerData.markups.emitImg.value then
			emitImage(
				obj,
				printerData.markups.emitImg.value,
				printerData,
				printerData.markups,
				printerData.markups.emitImg.attributes,
				updater
			)
		end
	end,
	convert = util.stringToNumber,
	attributes = emitImgAttrsConverters,
	valueAttributes = {},
	unrequired = true,
}

return module
