-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local RunService = TS.import(script, TS.getModule(script, "@rbxts", "services")).RunService
local buffer = {}
local RenderFirstBinding
do
	RenderFirstBinding = setmetatable({}, {
		__tostring = function()
			return "RenderFirstBinding"
		end,
	})
	RenderFirstBinding.__index = RenderFirstBinding
	function RenderFirstBinding.new(...)
		local self = setmetatable({}, RenderFirstBinding)
		return self:constructor(...) or self
	end
	function RenderFirstBinding:constructor(priority, callback)
		self.priority = priority
		self.callback = callback
	end
	function RenderFirstBinding:unbind()
		local _self = self
		local _arg0 = (table.find(buffer, _self) or 0) - 1
		table.remove(buffer, _arg0 + 1)
	end
end
RunService:BindToRenderStep("3A_BindRenderFirstBuffer", Enum.RenderPriority.First.Value, function()
	local _arg0 = function(_param)
		local callback = _param.callback
		return callback()
	end
	for _k, _v in buffer do
		_arg0(_v, _k - 1, buffer)
	end
end)
local function searchBinary(priority)
	if #buffer == 0 then
		return 0
	end
	local up = #buffer - 1
	local low = 0
	while up ~= low do
		local center = math.floor((up + low) / 2)
		if buffer[center + 1].priority < priority then
			low = center
		else
			up = center
		end
	end
	return up
end
local RenderFirst = {}
do
	local _container = RenderFirst
	local function bindAt(priority, callback)
		local binding = RenderFirstBinding.new(priority, callback)
		local ind = searchBinary(priority)
		table.insert(buffer, ind + 1, binding)
		return binding
	end
	_container.bindAt = bindAt
end
return {
	RenderFirst = RenderFirst,
}
