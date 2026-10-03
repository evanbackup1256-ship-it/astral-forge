--!nocheck
-- The Blender-built boss bodies: skeleton, piece placement, physics chains and animation clips.
-- Written by tools/bossbuild/export_bodies.py. Each boss is its own module (BossBody_<Kind>) because a
-- single module would pass Roblox's script size limit; this loads them on first use, so
-- `BossBodies[kind]` works as it always did. SanctuaryKit requires it when a boss is set to wear its
-- Blender body (SanctuaryConfig.BossBodyStyle).

local loaded = {}

return setmetatable({}, {
	__index = function(_, kind)
		if loaded[kind] == nil then
			local module = script.Parent:FindFirstChild("BossBody_" .. tostring(kind))
			loaded[kind] = if module ~= nil and module:IsA("ModuleScript") then require(module) else false
		end
		return loaded[kind] or nil
	end,
})
