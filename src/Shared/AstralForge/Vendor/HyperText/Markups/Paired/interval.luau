--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local name : "interval" = "interval"
local type_ : "paired" = "paired"
local module : types.dataModule<typeof(name), typeof(type_)> = {
	name = name,
	type = type_,
	
	convert = util.stringToNumber,
	attributes = {},
	valueAttributes = {},
}

return module
