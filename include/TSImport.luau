local include = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include")
local runtime = require(include:WaitForChild("RuntimeLib"))

return function(module: ModuleScript): any
	return runtime.import(script, module)
end
