local Connection = require(script:WaitForChild('Connection'))
local Signal = require(script:WaitForChild('Signal'))
local Subject = require(script:WaitForChild('Subject'))

export type Connection = Connection.Connection
export type Signal<T...> = Signal.Signal<T...>
export type ConnectableSignal<T...> = Signal.ConnectableSignal<T...>

return {
    new = Signal.new,
    newSubject = Subject.new,
}
