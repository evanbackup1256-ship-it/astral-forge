--!strict
-- Vendored from the Roblox Creator Store asset 91404002163443 ("Sprite", an AnimationTrack-style
-- spritesheet animator; devforum.roblox.com/t/4538233). Kept as published; local edits are marked.
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection


function Connection.new(Signal, Callback)
	return setmetatable({
		Signal = Signal,
		Callback = Callback
	}, Connection)
end

function Connection.Disconnect(self)
	self.Signal[self] = nil
end


function Signal.new()
	return setmetatable({} :: any, Signal)
end

function Signal.Connect(self, Callback)
	local CN = Connection.new(self, Callback)
	self[CN] = true
	return CN
end

function Signal.Once(self, Callback)
	local CN
	CN = Connection.new(self, function(...)
		CN:Disconnect()
		Callback(...)
	end)
	self[CN] = true
	return CN
end

function Signal.Wait(self)
	local waitingCoroutine = coroutine.running()
	local cn; cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self)
	table.clear(self)
end

function Signal.Fire(self, ...)
	if next(self) then
		for CN in pairs(self) do
			CN.Callback(...)
		end
	end
end


type Connection = {
	Disconnect: (self: any) -> ()
}

export type Signal<T...> = {
	Fire: (self: any, T...) -> (),
	Connect: (self: any, FN: (T...) -> ()) -> Connection,
	Once: (self: any, FN: (T...) -> ()) -> Connection,
	Wait: (self: any) -> T...,
	DisconnectAll: (self: any) -> ()
}


return Signal :: {new: () -> Signal<...any>}