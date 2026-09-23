--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local name : "color" = "color"
local type_ : "paired" = "paired"
local module : types.dataModule<typeof(name), typeof(type_)> = {
	type = type_,
	name = name,

	onPrint = function(
		obj : types.hyperTextClassObject,
		printerData : types.printerDataRowEntry<false>,
		spanData : types.onPrintMarkupSpanData,
		updater : {[string] : (dt : number) -> ()}
	)
		printerData.character.TextColor3 = printerData.markups.color.value
	end,
	convert = util.stringToColor3,
	attributes = {},
	valueAttributes = {},
}

return module
