--!strict
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared")
	local Specializations = require(Shared:WaitForChild("Specializations"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	task.defer(function()
		local ok, snapshot = pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
		if not ok then ModuleLog.Warn("Specializations", "Live build tuning unavailable; using documented defaults."); return end
		local function apply()
			Specializations.Configure(snapshot:GetValue("SpecializationGain"), snapshot:GetValue("SpecializationTradeoff"), snapshot:GetValue("SpecializationRespecSeconds"))
		end
		apply()
		snapshot.UpdateAvailable:Connect(function()
			local refreshed, message = pcall(function() snapshot:Refresh(); apply() end)
			if not refreshed then ModuleLog.Warn("Specializations", "Live build refresh failed: " .. tostring(message)) end
		end)
	end)
	return Specializations
end
