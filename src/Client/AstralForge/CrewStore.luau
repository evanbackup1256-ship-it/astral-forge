--!nonstrict
-- Client copy of the player's crew and any pending invite. CrewService pushes CrewState /
-- CrewInvite effects; UiCore writes them here and the Crew page and chat read them.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)

local CrewStore = {}

local state = { crew = nil, invite = nil }
local listeners = {}

function CrewStore.get()
	return state
end

function CrewStore.set(patch)
	local nextState = table.clone(state)
	for key, value in patch do
		nextState[key] = if value == CrewStore.NONE then nil else value
	end
	state = nextState
	for listener in listeners do
		task.spawn(listener, state)
	end
end

-- passed in a patch to clear a field (nil cannot be stored in a table)
CrewStore.NONE = newproxy(false)

function CrewStore.subscribe(listener)
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

function CrewStore.useCrew()
	local current, setCurrent = React.useState(state)
	React.useEffect(function()
		setCurrent(state)
		return CrewStore.subscribe(setCurrent)
	end, {})
	return current
end

return CrewStore
