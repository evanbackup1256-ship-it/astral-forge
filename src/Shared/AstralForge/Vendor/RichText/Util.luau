--!strict

local TextService = game:GetService("TextService")

local types = require(script.Parent:WaitForChild("Types"))

local util = {}

util.getWidthOfChildren = function(instance : GuiObject) : number
	local width = 0
	
	for _, v in pairs(instance:GetChildren()) do
		if v:IsA("GuiObject") then
			width += v.AbsoluteSize.X
		end
	end
	
	return width
end

util.updateProperties = function(
	base : types.properties,
	new : types.properties
) : types.properties
	local previous : {[string] : any} = {}

	-- converting to indexable
	base = base :: {[string] : any}
	new = new :: {[string] : any}

	for k, value in pairs(new) do
		previous[k] = base[k]
		base[k] = value
	end

	return previous :: types.properties
end

local MAX_RETRIES = 5
-- caching result from GetTextBoundsAsync to avoid possible failures
local textBoundsCache : {
	[any] : {
		[number] : {
			string : string,
			font : string,
			size : number,
			weight : Enum.FontWeight,
			style : Enum.FontStyle,
			textBounds : Vector2
		}
	}	
} = {}
util.fetchTextBounds = function(cacheKey : any, str : string, properties : types.properties, proportionalSize : number?) : Vector2
	local styleEnum = properties.Italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal
	
	if textBoundsCache[cacheKey] then
		for _, v in ipairs(textBoundsCache[cacheKey]) do
			if v.string == str then
				if v.font == properties.Font then
					if v.size == (proportionalSize or properties.Size) then
						if v.weight == properties.Weight then
							if v.style == styleEnum then
								return v.textBounds
							end
						end
					end
				end
			end
		end
	end
	
	local params = Instance.new("GetTextBoundsParams")
	params.Text = str
	params.Font = Font.new(properties.Font, properties.Weight, styleEnum)
	params.Size = proportionalSize or properties.Size

	local retries = 0
	
	local function fetch() : Vector2
		local success, textBounds = pcall(function()			
			return TextService:GetTextBoundsAsync(params)
		end)
		if success then
			if not textBoundsCache[cacheKey] then
				textBoundsCache[cacheKey] = {}
			end
			
			table.insert(textBoundsCache[cacheKey], {
				string = str,
				font = properties.Font,
				size =  proportionalSize or properties.Size,
				weight = properties.Weight,
				style = styleEnum,
				textBounds = textBounds
			})
			
			return textBounds
		else			
			if retries < MAX_RETRIES then
				retries += 1
				
				return fetch()
			else
				warn("Failed to fetch text bounds: " .. tostring(textBounds))
				
				return Vector2.zero
			end
		end
	end

	return fetch()
end
util.removeTextBoundsCache = function(cacheKey : any)
	textBoundsCache[cacheKey] = nil
end

util.stringToBoolean = function(str : string) : boolean
	str = string.lower(str)
	
	if str == "true" or str == "false" then
		return str == "true"
	end
	
	error(str .. " is not a valid boolean", 0)
end

util.stringToNumber = function(str : string) : number
	if tonumber(str) then
		return tonumber(str) :: number
	end

	error(str .. " is not a valid number", 0)
end

util.stringToColor3 = function(str : string) : Color3
	local r, g, b = string.match(str, "^(%d+),(%d+),(%d+)$")
	
	r, g, b =
		r and util.stringToNumber(r),
		g and util.stringToNumber(g),
		b and util.stringToNumber(b)
	
	if r and g and b then
		return Color3.fromRGB(r, g, b)
	else
		error(str .. " is not a valid format of r,g,b or color shortcut", 0)
	end
end

util.stringToFontWeight = function(str : string) : Enum.FontWeight
	return Enum.FontWeight[str]
end

return util
