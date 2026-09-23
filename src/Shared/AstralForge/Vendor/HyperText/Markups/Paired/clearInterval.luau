--!strict

local types = require("../../Internal/Types")
local util = require("../../Internal/Util")
local config = require("../../Internal/Config")

local name : "clearInterval" = "clearInterval"
local type_ : "paired" = "paired"
local module : types.dataModule<typeof(name), typeof(type_)> = {
	name = name,
	type = type_,
	
	convert = function(str : string)
		return util.stringToInheritable(str, util.stringToNumber)
	end,
	attributes = {},
	valueAttributes = {},
}

return module
