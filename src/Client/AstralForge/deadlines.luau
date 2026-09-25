local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Workspace = game:GetService("Workspace")
local function unixNow()
	return Workspace:GetServerTimeNow()
end
local function useUnixDeadline(deadline)
	local active, setActive = React.useState(function()
		return type(deadline) == "number" and deadline > unixNow()
	end)
	React.useEffect(function()
		if type(deadline) ~= "number" then
			setActive(false)
			return nil
		end
		local remaining = deadline - unixNow()
		if remaining ~= remaining or remaining <= 0 then
			setActive(false)
			return nil
		end
		setActive(true)
		local alive = true
		local worker = task.delay(remaining + 0.05, function()
			if alive then
				setActive(false)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { deadline })
	return active
end
return {
	unixNow = unixNow,
	useUnixDeadline = useUnixDeadline,
}
