--[=[
	@within EgooE
	@function portal
	@tag widgets
	@param targetInstance Instance -- Where the portal mounts its children
	@param children () -> () -- Children

	The portal widget creates its children inside the specified `targetInstance`.

	```lua
	portal(Lighting, function()
		useInstance(function()
			local blur = Instance.new("BlurEffect")
			blur.Size = size
			return blur
		end)
	end)
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)

return Runtime.widget(function(targetInstance, fn)
	Runtime.useInstance(function()
		return nil, targetInstance
	end)

	Runtime.scope(fn)
end)
