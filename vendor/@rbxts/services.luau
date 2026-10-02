-- @rbxts/services 1.6.0, vendored as one file so it is always a plain ModuleScript. As a directory with an init file
-- plus a generated package.luau it was syncing into Studio as an empty Folder, which broke every roblox-ts import of it.
return setmetatable({}, {
	__index = function(self, serviceName)
		local service = game:GetService(serviceName)
		self[serviceName] = service
		return service
	end,
})
