--[=[
	@within EgooE
	@function space
	@tag widgets
	@param size number -- Size in pixels for the blank space

	Inserts blank space of the given pixel size.
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local create = require(script.Parent.Parent.create)

return Runtime.widget(function(size)
	size = size or 8

	local refs = Runtime.useInstance(function(ref)
		return create("Frame", {
			[ref] = "space",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, size, 0, size),
		})
	end)

	Runtime.useEffect(function()
		refs.space.Size = UDim2.new(0, size, 0, size)
	end, size)
end)
