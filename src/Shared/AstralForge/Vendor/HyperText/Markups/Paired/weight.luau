--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local name : "weight" = "weight"
local type_ : "paired" = "paired"
local module : types.dataModule<typeof(name), typeof(type_)> = {
	name = name,
	type = type_,
	
	convert = util.stringToFontWeight,
	attributes = {},
	valueAttributes = {},
}

return module
