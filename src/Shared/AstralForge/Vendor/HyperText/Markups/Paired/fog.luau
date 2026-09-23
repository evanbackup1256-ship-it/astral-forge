--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")
local emitImage = require("../../Internal/Helpers/EmitImage")
local emitImgAttrsConverters = require("../../Internal/Helpers/EmitImgAttrsConverters")

local name : "fog" = "fog"
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
		if printerData.markups.fog.value then
			emitImage(
				obj,
				config.FOG_IMG_ID,
				printerData,
				printerData.markups,
				printerData.markups.fog.attributes,
				updater
			)
		end
	end,
	convert = util.stringToBoolean,
	attributes = emitImgAttrsConverters,
	valueAttributes = {},
}

return module
