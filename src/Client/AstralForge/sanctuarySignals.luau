--!strict
-- A small event bus for the sanctuary.
--
-- Server effects arrive in one place (MainGame's effect listener). Several
-- client systems care about the sanctuary ones -- the world controller that
-- draws them and the HUD that reports them -- so MainGame forwards those here
-- and each system subscribes to what it needs. Client-side events (a waystone
-- opened, a region entered) travel the same way.

local Signals = {}

-- Server effect types MainGame forwards to the bus.
Signals.SERVER_KINDS = table.freeze({
	OreMined = true,
	OreCooldowns = true,
	RiftBossAwake = true,
	RiftBossSlam = true,
	RiftBossSlamLand = true,
	RiftBossStagger = true,
	RiftBossDefeated = true,
	RiftBossFell = true,
	WaystoneArrived = true,
})

local listeners: { [string]: { [(any) -> ()]: boolean } } = {}

function Signals.handles(kind: string): boolean
	return Signals.SERVER_KINDS[kind] == true
end

-- Subscribe; returns a function that unsubscribes.
function Signals.on(kind: string, callback: (any) -> ()): () -> ()
	local bucket = listeners[kind]
	if bucket == nil then
		bucket = {}
		listeners[kind] = bucket
	end
	bucket[callback] = true
	return function()
		local current = listeners[kind]
		if current ~= nil then
			current[callback] = nil
		end
	end
end

function Signals.fire(kind: string, payload: any)
	local bucket = listeners[kind]
	if bucket == nil then
		return
	end
	-- Copy first: a listener may unsubscribe (or subscribe) while we iterate.
	local snapshot = {}
	for callback in bucket do
		table.insert(snapshot, callback)
	end
	for _, callback in snapshot do
		local ok, problem = pcall(callback :: (any) -> any, payload)
		if not ok then
			warn(`[sanctuary] {kind} listener failed: {problem}`)
		end
	end
end

return Signals
