--!strict
local Signals = {}
local listeners: { [(any) -> ()]: boolean } = {}
local seen: { [string]: boolean } = {}
local history: { string } = {}
function Signals.subscribe(callback: (any) -> ()): () -> ()
	listeners[callback] = true
	return function()
		listeners[callback] = nil
	end
end
function Signals.confirm(payload: any)
	if type(payload) ~= "table" or type(payload.ProductId) ~= "number" or type(payload.Key) ~= "string" then
		return
	end
	if seen[payload.Key] then
		return
	end
	seen[payload.Key] = true
	table.insert(history, payload.Key)
	if #history > 128 then
		seen[table.remove(history, 1)] = nil
	end
	for callback in table.clone(listeners) do
		callback(payload)
	end
end
return Signals
