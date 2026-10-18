--!strict

local config = require("../Config")
local util = require("../Util")
local types = require("../Types")

local converters : types.animAttrsConverters = {
	dur = {
		convert = function(value : string)
			return util.stringToNumber(value, 0)
		end,
	},
	loop = {
		convert = util.stringToBoolean,
	},
}

local valueAttrsConverters : types.animValueAttrsConverters = {
	slide = {
		dir = {
			convert = function(value)
				return util.stringToSingletonKey(types.literal.verticalDir, value)
			end,
		},
		offset = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = util.stringToNumber,
		},
	},
	bounce = {
		dir = {
			convert = function(value)
				return util.stringToSingletonKey(types.literal.verticalDir, value)
			end,
		},
		offset = {
			convert = util.stringToNumber,
		},
		exp = {
			convert = util.stringToNumber,
		}
	},
	wiggle = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
		amp = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = util.stringToBoolean,
		},
	},
	grow = {
		exp = {
			convert = util.stringToNumber,
		},
		startScale = {
			convert = util.stringToNumber,
		},
	},
	orbit = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
		amp = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = util.stringToBoolean,
		},
	},
	pendulum = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
		amp = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = function(value : string)
				local lower = string.lower(value)
				if lower == "true" then
					return 14
				elseif lower == "false" then
					return 0
				end
				return util.stringToNumber(value)
			end,
		},
	},
	spiral = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
		amp = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = function(value : string)
				local lower = string.lower(value)
				if lower == "true" then
					return 18
				elseif lower == "false" then
					return 0
				end
				return util.stringToNumber(value)
			end,
		},
	},
	pulsewave = {
		freq = {
			convert = util.stringToNumber,
		},
		offset = {
			convert = util.stringToNumber,
		},
		amp = {
			convert = util.stringToNumber,
		},
		rot = {
			convert = function(value : string)
				local lower = string.lower(value)
				if lower == "true" then
					return 8
				elseif lower == "false" then
					return 0
				end
				return util.stringToNumber(value)
			end,
		},
	},
}

return {
	attrsConverters = converters,
	valueAttrsConverters = valueAttrsConverters,
}