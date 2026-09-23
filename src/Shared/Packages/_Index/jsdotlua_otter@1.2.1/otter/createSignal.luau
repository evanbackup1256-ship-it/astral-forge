local Signal = require(script.Parent.Parent:WaitForChild('luau-signal'))

export type Signal<T> = Signal.Signal<T>
export type FireSignal<T> = (T) -> ()

local function createSignal<T>(): (Signal.Signal<T>, FireSignal<T>)
	local signal = Signal.new()
	return signal, function(...)
		signal:fire(...)
	end
end

return {
	createSignal = createSignal,
}
