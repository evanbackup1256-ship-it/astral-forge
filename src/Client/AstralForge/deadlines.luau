local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Workspace = game:GetService("Workspace")
local function unixNow()
	return Workspace:GetServerTimeNow()
end
local function useUnixDeadline(deadline)
	local active, setActive = React.useState(function()
		return deadline > unixNow()
	end)
	React.useEffect(function()
		local remaining = deadline - unixNow()
		if remaining <= 0 then
			setActive(false)
			return nil
		end
		setActive(true)
		local expiry = task.delay(remaining + 0.05, function()
			return setActive(false)
		end)
		return function()
			return task.cancel(expiry)
		end
	end, { deadline })
	return active
end
return {
	unixNow = unixNow,
	useUnixDeadline = useUnixDeadline,
}
