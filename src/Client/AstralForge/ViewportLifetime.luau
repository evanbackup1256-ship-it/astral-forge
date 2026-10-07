--!strict
-- Purpose: Own parked viewport instances and stop stale animation callbacks before scene destruction.
-- Owner: Astral Forge presentation. Dependencies: Roblox Instance events. Last-reviewed: 2026-10-05.
export type Lifetime = { alive: () -> boolean, own: (Instance) -> (), dispose: () -> () }
export type API = { new: (owner: Instance) -> Lifetime }

local function new(owner: Instance): Lifetime
	local closed = false
	local children: { Instance } = {}
	local connection: RBXScriptConnection? = nil
	local function alive(): boolean
		return not closed and owner.Parent ~= nil
	end
	local function dispose(): ()
		if closed then
			return
		end
		closed = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		for _, child in children do
			child:Destroy()
		end
		table.clear(children)
	end
	local function own(child: Instance): ()
		if closed then
			child:Destroy()
		else
			table.insert(children, child)
		end
	end
	connection = owner.Destroying:Connect(dispose)
	local lifetime: Lifetime = { alive = alive, own = own, dispose = dispose }
	return table.freeze(lifetime)
end

local api: API = { new = new }
return table.freeze(api)
